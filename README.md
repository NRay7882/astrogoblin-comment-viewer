# Astrogoblin Comment Viewer

> **The site [astrogoblincommentviewer.com](https://astrogoblincommentviewer.com) will be shut down on Saturday, June 6th, 2026.** The code is being made available here for anyone who wants to use it.

A Patreon comment viewer with a Star Wars-style holographic projection display, originally built for the [Astrogoblin](https://www.patreon.com/c/Astrogoblin) community. Patreon creators can authenticate with their account, paste a post URL, and view comments rendered in a 3D holoprojection effect.

Built with Node 26.8.1 & npm 11.19.0

## Features

- OAuth2 authentication with Patreon's API
- Extract comments from any post on your own Patreon page
- Star Wars-inspired holographic comment display
- Displays commenter usernames, profile images, timestamps, and like counts
- Session-based token management

## Quick Start (Setup Scripts)

Setup scripts are included that will check your environment, install Node.js via nvm if needed, create a `.env` template, and run `npm install`.

**macOS / Linux:**
```bash
./setup.sh
```

**Windows (PowerShell):**
```powershell
.\setup.ps1
```

After setup completes, add your Patreon API credentials to `.env` (see [Patreon API Setup](#patreon-api-setup) below), then run `npm start`.

---

## Manual Setup

If you prefer to set things up yourself, follow the steps below for your platform.

### 1. Install nvm (Node Version Manager)

nvm lets you install and switch between Node.js versions without affecting system-level installs.

**macOS / Linux:**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```
Close and reopen your terminal after installing, then verify:
```bash
nvm --version
```

**Windows:**

nvm-windows is a separate project from nvm and requires a manual download:

1. Go to [nvm-windows releases](https://github.com/coreybutler/nvm-windows/releases)
2. Download and run `nvm-setup.exe`
3. Close and reopen PowerShell after installing, then verify:
```powershell
nvm version
```

### 2. Install Node.js

Once nvm is installed, install and activate a Node.js version (26.8.1 was used):

```bash
nvm install 26.8.1
nvm use 26.8.1
```

Verify both Node.js and npm are available:
```bash
node --version
npm --version
```

### 3. Clone and install dependencies

```bash
git clone https://github.com/NRay7882/astrogoblin-comment-viewer.git
cd astrogoblin-comment-viewer
npm install
```

### 4. Configure environment variables

Create a `.env` file in the project root:

```env
PATREON_CLIENT_ID=your_client_id_here
PATREON_CLIENT_SECRET=your_client_secret_here
PATREON_REDIRECT_URI=http://localhost:3000/oauth/callback
NODE_ENV=dev
```

See [Environment Configuration](#environment-configuration) below for details on each variable.

### 5. Start the server

```bash
npm start
```

Open `http://localhost:3000` in your browser.

---


## Patreon API Setup
 
1. Go to [Patreon's Developer Portal](https://www.patreon.com/portal/registration/register-clients) and create a new API client (or use an existing one).
2. Note your **Client ID** and **Client Secret**, you'll need both for the `.env` file.
3. Under your client's settings, add a **Redirect URI**:
   - For local development: `http://localhost:3000/oauth/callback`
   - For production hosting: `https://yourdomain.com/oauth/callback`
4. Make sure the following OAuth scopes are available for your client: `identity`, `campaigns`, `campaigns.posts`
> **Important:** The Patreon API only allows creators to access comments on their **own** posts. You cannot extract comments from another creator's posts.
 
> **Tip:** Consider creating **two separate API clients** in the Patreon Developer Portal - one for local development and one for your hosted environment. Each client gets its own Client ID, Client Secret, and redirect URI, so your local client can permanently use `http://localhost:3000/oauth/callback` while your production client uses `https://yourdomain.com/oauth/callback`. That way you only need to swap `PATREON_CLIENT_ID` and `PATREON_CLIENT_SECRET` in your `.env` when switching between local testing and production - no need to touch `PATREON_REDIRECT_URI` or update redirect URIs in the developer portal each time.
 
## Environment Configuration
 
| Variable | Description |
|---|---|
| `PATREON_CLIENT_ID` | Your Patreon API client ID |
| `PATREON_CLIENT_SECRET` | Your Patreon API client secret |
| `PATREON_REDIRECT_URI` | Must match **exactly** what's configured in the Patreon Developer Portal. Use `http://localhost:3000/oauth/callback` for local development, or your production URL for hosting (e.g. `https://yourdomain.com/oauth/callback`). |
| `NODE_ENV` | Set to `dev` for local development, `production` for hosted deployments. When set to `production`, the server enforces canonical domain redirects. |
 
> **Redirect URI mismatch is the most common issue.** The value in your `.env` file must be an exact character-for-character match with what you entered in the Patreon Developer Portal, including the protocol (`http` vs `https`) and any trailing slashes. If you switch between local testing and production hosting, you need to update both the `.env` file and the Patreon Developer Portal redirect URI list.
 
## Debugging Tips
 
- The server logs OAuth flow details, API calls, and comment processing to the console. Watch the terminal output for `✓`/`❌` indicators during authentication and comment extraction.
- If you get a `401` error after authenticating, your session may have expired - refresh the page and re-authenticate.
- If you get a `403` when extracting comments, you're likely trying to access a post that doesn't belong to your Patreon account.
- The server accepts post URLs in both formats: `https://www.patreon.com/posts/title-name-123456` and `https://www.patreon.com/posts/123456`

## Hosting / Production Deployment
 
This project is designed to run on any Node.js hosting platform. Below are notes if you're deploying to [Render](https://render.com/) or similar services:
 
1. Set `NODE_ENV=production` in your hosting platform's environment variables.
2. Set `PATREON_REDIRECT_URI` to your production callback URL (e.g. `https://yourdomain.com/oauth/callback`).
3. Update the Patreon Developer Portal to include your production redirect URI.
4. The server listens on the `PORT` environment variable (most hosting platforms set this automatically).
5. In production mode, requests to `www.yourdomain.com` are redirected (301) to the non-www canonical domain. If your domain differs, update the hostname check in `server.js` (line 363).

### Render-Specific Notes
 
- Create a new **Web Service** and connect your GitHub repository.
- Set the **Build Command** to `npm install` and the **Start Command** to `npm start`.
- Add all `.env` variables under **Environment** in the Render dashboard.
- Render provides automatic HTTPS - use `https://` in your redirect URI.

## Project Structure
 
```
├── server.js          # Express server: OAuth flow, Patreon API integration, comment extraction
├── public/            # Static frontend assets
│   └── index.html     # Main page with holographic comment display
├── setup.sh           # macOS/Linux setup script
├── setup.ps1          # Windows PowerShell setup script
├── package.json       # Dependencies and scripts
├── .env               # Environment variables (not committed to git)
└── .gitignore
```
 
## Dependencies
 
- **express** - Web server and routing
- **patreon** - Official Patreon OAuth client
- **cors** - Cross-origin resource sharing middleware
- **dotenv** - Environment variable loading from `.env` files

## License
 
ISC