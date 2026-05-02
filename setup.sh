#!/bin/bash

# Astrogoblin Comment Viewer - macOS/Linux Setup Script
# Run: chmod +x setup.sh && ./setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Required Node.js version
REQUIRED_NODE_MAJOR=18
RECOMMENDED_NODE_VERSION="22"

errors=()
warnings=()

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  Astrogoblin Comment Viewer Setup${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# =============================================================================
# NVM / NODE.JS CHECKS
# =============================================================================

echo -e "${YELLOW}Checking Node.js requirements...${NC}"
echo ""

# Check for nvm
NVM_FOUND=false
if [ -d "$HOME/.nvm" ]; then
    # Source nvm if not already loaded
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if command -v nvm &> /dev/null; then
    NVM_FOUND=true
    echo -e "${GREEN}✓ nvm installed${NC}"
else
    echo -e "${YELLOW}⚠ nvm not found - installing...${NC}"
    if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash > /dev/null 2>&1; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        if command -v nvm &> /dev/null; then
            NVM_FOUND=true
            echo -e "${GREEN}✓ nvm installed successfully${NC}"
        else
            echo -e "${RED}✗ nvm installed but failed to load${NC}"
            errors+=("nvm was installed but could not be loaded. Close and reopen your terminal, then run this script again.")
        fi
    else
        echo -e "${RED}✗ Failed to install nvm${NC}"
        errors+=("nvm installation failed. Install manually: https://github.com/nvm-sh/nvm#installing-and-updating")
    fi
fi

# Check for Node.js
NODE_FOUND=false
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)

    if [ "$NODE_MAJOR" -ge "$REQUIRED_NODE_MAJOR" ]; then
        NODE_FOUND=true
        echo -e "${GREEN}✓ Node.js v${NODE_VERSION} (v${REQUIRED_NODE_MAJOR}+ required)${NC}"
    else
        echo -e "${YELLOW}⚠ Node.js v${NODE_VERSION} found but v${REQUIRED_NODE_MAJOR}+ required${NC}"
    fi
fi

# Install Node.js via nvm if needed
if [ "$NODE_FOUND" = false ] && [ "$NVM_FOUND" = true ]; then
    echo -e "${YELLOW}  Installing Node.js v${RECOMMENDED_NODE_VERSION} via nvm...${NC}"
    if nvm install "$RECOMMENDED_NODE_VERSION" > /dev/null 2>&1; then
        nvm use "$RECOMMENDED_NODE_VERSION" > /dev/null 2>&1
        NODE_VERSION=$(node --version | sed 's/v//')
        NODE_FOUND=true
        echo -e "${GREEN}✓ Node.js v${NODE_VERSION} installed via nvm${NC}"
    else
        echo -e "${RED}✗ Failed to install Node.js via nvm${NC}"
        errors+=("Could not install Node.js via nvm. Try manually: nvm install ${RECOMMENDED_NODE_VERSION}")
    fi
elif [ "$NODE_FOUND" = false ]; then
    errors+=("Node.js v${REQUIRED_NODE_MAJOR}+ is required but not installed, and nvm is not available to install it.")
fi

# Check for npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ npm v${NPM_VERSION}${NC}"
else
    if [ "$NODE_FOUND" = true ]; then
        errors+=("npm not found despite Node.js being installed. Reinstall Node.js.")
    fi
fi

echo ""

# =============================================================================
# STOP IF CRITICAL ERRORS
# =============================================================================

if [ ${#errors[@]} -gt 0 ]; then
    echo -e "${RED}==========================================${NC}"
    echo -e "${RED}  Setup cannot continue - errors found${NC}"
    echo -e "${RED}==========================================${NC}"
    echo ""
    for err in "${errors[@]}"; do
        echo -e "  ${RED}✗ $err${NC}"
    done
    echo ""
    exit 1
fi

if [ ${#warnings[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warnings:${NC}"
    for warn in "${warnings[@]}"; do
        echo -e "  ${YELLOW}⚠ $warn${NC}"
    done
    echo ""
fi

# =============================================================================
# ENVIRONMENT FILE
# =============================================================================

echo -e "${YELLOW}Checking configuration...${NC}"
echo ""

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env from .env.example${NC}"
        echo -e "${YELLOW}  ⚠ You must add your Patreon Client ID and Secret to .env before running${NC}"
    else
        # Create a template .env
        cat > .env << 'EOF'
PATREON_CLIENT_ID=your_client_id_here
PATREON_CLIENT_SECRET=your_client_secret_here
PATREON_REDIRECT_URI=http://localhost:3000/oauth/callback
NODE_ENV=dev
EOF
        echo -e "${GREEN}✓ Created .env template${NC}"
        echo -e "${YELLOW}  ⚠ You must add your Patreon Client ID and Secret to .env before running${NC}"
    fi
else
    echo -e "${GREEN}✓ .env file exists${NC}"

    # Check if placeholder values are still present
    if grep -q "your_client_id_here" .env 2>/dev/null; then
        warnings+=("PATREON_CLIENT_ID is still set to the placeholder value in .env - update it before running.")
        echo -e "${YELLOW}  ⚠ PATREON_CLIENT_ID needs to be configured in .env${NC}"
    fi
fi

echo ""

# =============================================================================
# INSTALL DEPENDENCIES
# =============================================================================

echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
echo ""

if [ -f "package.json" ]; then
    npm install
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${RED}✗ npm install failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ package.json not found - are you in the project root?${NC}"
    exit 1
fi

echo ""

# =============================================================================
# SUCCESS
# =============================================================================

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${CYAN}Quick Start:${NC}"
echo "  1. Make sure your Patreon API credentials are set in .env"
echo ""
echo "  2. Start the server:"
echo -e "     ${YELLOW}npm start${NC}"
echo ""
echo "  3. Open in your browser:"
echo -e "     ${YELLOW}http://localhost:3000${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo "  Edit .env to configure:"
echo "    PATREON_CLIENT_ID       Your Patreon API client ID"
echo "    PATREON_CLIENT_SECRET   Your Patreon API client secret"
echo "    PATREON_REDIRECT_URI    OAuth callback URL (default: http://localhost:3000/oauth/callback)"
echo "    NODE_ENV                Set to 'production' for hosted deployments"
echo ""