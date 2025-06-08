require('dotenv').config();
const express = require('express');
const patreon = require('patreon');
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// ⚙️ Configuration from environment variables with fallbacks
const CLIENT_ID = process.env.PATREON_CLIENT_ID || process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.PATREON_CLIENT_SECRET || process.env.CLIENT_SECRET;
const REDIRECT_URI = process.env.PATREON_REDIRECT_URI || process.env.REDIRECT_URI || 'http://localhost:3000/oauth/callback';
const PORT = process.env.PORT || 3000;

// Validate required environment variables
if (!CLIENT_ID) {
    console.error('❌ Missing PATREON_CLIENT_ID environment variable');
    console.error('Set it with: export PATREON_CLIENT_ID=your_client_id');
    process.exit(1);
}

if (!CLIENT_SECRET) {
    console.error('❌ Missing PATREON_CLIENT_SECRET environment variable');
    console.error('Set it with: export PATREON_CLIENT_SECRET=your_client_secret');
    process.exit(1);
}

console.log('🔧 Configuration:');
console.log(`   CLIENT_ID: ${CLIENT_ID ? '✓ Set' : '❌ Missing'}`);
console.log(`   CLIENT_SECRET: ${CLIENT_SECRET ? '✓ Set' : '❌ Missing'}`);
console.log(`   REDIRECT_URI: ${REDIRECT_URI}`);
console.log(`   PORT: ${PORT}`);

const patreonOAuth = patreon.oauth;

let userTokens = {}; // In production, use proper session management

// Serve the main page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Step 1: Redirect to Patreon for authentication
app.get('/auth/patreon', (req, res) => {
    const authUrl = `https://www.patreon.com/oauth2/authorize?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&scope=identity campaigns campaigns.posts`;
    console.log('Redirecting to:', authUrl);
    res.redirect(authUrl);
});

// Step 2: Handle the callback from Patreon
app.get('/oauth/callback', async (req, res) => {
    const { code, error } = req.query;
    
    if (error) {
        console.error('OAuth error:', error);
        return res.redirect('/?error=oauth_failed');
    }
    
    if (!code) {
        console.error('No code received');
        return res.redirect('/?error=no_code');
    }
    
    try {
        console.log('Received auth code:', code);
        
        // Exchange code for tokens
        const oauthClient = patreonOAuth(CLIENT_ID, CLIENT_SECRET);
        const tokens = await oauthClient.getTokens(code, REDIRECT_URI);
        
        console.log('Received tokens:', {
            access_token: tokens.access_token ? '✓ Present' : '✗ Missing',
            refresh_token: tokens.refresh_token ? '✓ Present' : '✗ Missing'
        });

        // Store tokens (in production, use proper session management)
        userTokens.access_token = tokens.access_token;
        userTokens.refresh_token = tokens.refresh_token;
        
        res.redirect('/?authenticated=true');
    } catch (error) {
        console.error('Token exchange error:', error);
        res.redirect('/?error=token_exchange_failed');
    }
});

// Step 3: Extract post data
app.post('/api/extract-post', async (req, res) => {
    const { postUrl } = req.body;
    
    if (!userTokens.access_token) {
        return res.status(401).json({ error: 'Not authenticated. Please connect with Patreon first.' });
    }
    
    try {
        console.log('Extracting data from:', postUrl);
        
        // Extract post ID from URL - handle both formats:
        // https://www.patreon.com/posts/title-name-123456
        // https://www.patreon.com/posts/123456
        let postIdMatch = postUrl.match(/posts\/.*-(\d+)$/);
        if (!postIdMatch) {
            // Try the simpler format without title
            postIdMatch = postUrl.match(/posts\/(\d+)$/);
        }
        if (!postIdMatch) {
            return res.status(400).json({ error: 'Could not extract post ID from URL. Please use a valid Patreon post URL.' });
        }
        
        const postId = postIdMatch[1];
        console.log('Post ID:', postId);
        
        // Get basic post data
        const postApiUrl = `https://www.patreon.com/api/oauth2/v2/posts/${postId}?fields[post]=title,content,published_at`;
        console.log('Calling post API URL:', postApiUrl);
        
        const postResponse = await fetch(postApiUrl, {
            headers: {
                'Authorization': `Bearer ${userTokens.access_token}`,
                'User-Agent': 'CommentFeeder - Comment Extractor'
            }
        });
        
        if (!postResponse.ok) {
            const errorText = await postResponse.text();
            console.log('Post API Error:', errorText);
            
            // Provide specific user-friendly error messages
            if (postResponse.status === 403) {
                throw new Error('You can only extract comments from posts you created on your own Patreon account. This post belongs to a different creator.');
            } else if (postResponse.status === 404) {
                throw new Error('Post not found. Please check the URL and make sure the post exists and is published.');
            } else if (postResponse.status === 401) {
                throw new Error('Authentication expired. Please refresh the page and connect with Patreon again.');
            } else {
                throw new Error(`Unable to access post (Error ${postResponse.status}). You can only extract comments from your own Patreon posts.`);
            }
        }
        
        const postData = await postResponse.json();
        console.log('Post data received');
        
        // Try different comment endpoints
        let commentsData = null;
        const commentEndpoints = [
            `https://www.patreon.com/api/oauth2/v2/posts/${postId}/comments`,
            `https://api.patreon.com/posts/${postId}/comments`,
        ];
        
        for (const endpoint of commentEndpoints) {
            try {
                console.log('Trying comments endpoint:', endpoint);
                
                const commentsResponse = await fetch(endpoint, {
                    headers: {
                        'Authorization': `Bearer ${userTokens.access_token}`,
                        'User-Agent': 'CommentFeeder - Comment Extractor'
                    }
                });
                
                console.log('Comments response status:', commentsResponse.status);
                
                if (commentsResponse.ok) {
                    commentsData = await commentsResponse.json();
                    console.log('✅ SUCCESS! Got comments from:', endpoint);
                    break;
                } else {
                    const errorText = await commentsResponse.text();
                    console.log(`❌ ${endpoint} failed:`, commentsResponse.status, errorText.substring(0, 100));
                }
            } catch (error) {
                console.log(`❌ ${endpoint} error:`, error.message);
            }
        }
        
        // Build the result
        const result = {
            post: {
                id: postId,
                title: postData.data?.attributes?.title || 'Unknown Title',
                content: postData.data?.attributes?.content || 'No content',
                publishedAt: postData.data?.attributes?.published_at || 'Unknown',
                url: postUrl
            },
            comments: [],
            totalComments: 0,
            totalLikes: 0,
            extractedAt: new Date().toISOString()
        };
        
        // Helper function to process individual comments
        function processComment(comment, includedData, isReply = false) {
            let username = 'Unknown User';
            let profileImage = null;
            
            // Extract username and image from relationships/included data
            if (includedData) {
                const userId = comment.relationships?.commenter?.data?.id;
                if (userId) {
                    const user = includedData.find(item => item.type === 'user' && item.id === userId);
                    if (user && user.attributes) {
                        username = user.attributes.full_name || user.attributes.name || 'Unknown User';
                        profileImage = user.attributes.image_url || user.attributes.thumb_url || null;
                    }
                }
            }
            
            // Extract comment content
            const content = comment.attributes?.body || 
                           comment.attributes?.content || 
                           comment.attributes?.text || 
                           '';
            
            // Extract creation date
            const createdAt = comment.attributes?.created ||
                             comment.attributes?.created_at || 
                             'Unknown';
            
            // Extract likes/votes
            const likes = comment.attributes?.vote_sum ||
                         comment.attributes?.like_count || 
                         0;
            
            return {
                id: comment.id,
                username: username,
                content: content,
                createdAt: createdAt,
                likes: likes,
                profileImage: profileImage,
                isReply: isReply
            };
        }

        // Process comments if we found any
        if (commentsData && commentsData.data) {
            console.log('Processing comments data...');
            console.log('Total comments in API response:', commentsData.data.length);
            
            commentsData.data.forEach((comment, index) => {
                const processedComment = processComment(comment, commentsData.included, false);
                result.comments.push(processedComment);
            });
            
            result.totalComments = result.comments.length;
            
            // Try to get post like count from included data
            if (commentsData.included) {
                const postFromIncluded = commentsData.included.find(item => item.type === 'post' && item.id === postId);
                if (postFromIncluded && postFromIncluded.attributes) {
                    result.totalLikes = postFromIncluded.attributes.like_count || 0;
                    console.log('Found post like count from comments data:', result.totalLikes);
                }
            }
        } else {
            // Add info message if no comments found
            result.comments.push({
                id: 'no_comments',
                username: 'System',
                content: 'No comments found on this post.',
                createdAt: new Date().toISOString(),
                likes: 0,
                profileImage: null,
                isReply: false
            });
            result.totalComments = 0;
        }

        console.log('Extraction complete:', {
            commentsFound: result.comments.length,
            postTitle: result.post.title
        });
        
        res.json(result);
        
    } catch (error) {
        console.error('Extraction error:', error);
        console.error('Error message being sent to frontend:', error.message);
        
        res.status(500).json({ 
            error: error.message, // Send the actual error message, not generic text
            details: error.message,
            postUrl: req.body.postUrl
        });
    }
});

// Get current user info
app.get('/api/user-info', async (req, res) => {
    if (!userTokens.access_token) {
        return res.status(401).json({ error: 'Not authenticated' });
    }
    
    try {
        const identityResponse = await fetch('https://www.patreon.com/api/oauth2/v2/identity?fields[user]=full_name', {
            headers: {
                'Authorization': `Bearer ${userTokens.access_token}`,
                'User-Agent': 'CommentFeeder - User Info'
            }
        });
        
        if (identityResponse.ok) {
            const identityData = await identityResponse.json();
            res.json({
                username: identityData.data?.attributes?.full_name || 'Unknown User',
                authenticated: true
            });
        } else {
            res.status(500).json({ error: 'Failed to get user info' });
        }
    } catch (error) {
        console.error('User info error:', error);
        res.status(500).json({ error: 'Failed to get user info' });
    }
});

// Health check
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        authenticated: !!userTokens.access_token,
        timestamp: new Date().toISOString()
    });
});

app.listen(PORT, () => {
    console.log(`🚀 Server running at http://localhost:${PORT}`);
    console.log(`📝 Environment variables configured correctly`);
    console.log(`🔗 OAuth redirect URI: ${REDIRECT_URI}`);
});