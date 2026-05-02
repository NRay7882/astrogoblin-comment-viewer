# Astrogoblin Comment Viewer - Windows Setup Script
# Run: .\setup.ps1

$ErrorActionPreference = "Stop"

# Required Node.js version
$RequiredNodeMajor = 18
$RecommendedNodeVersion = "22"

$script:errors = @()
$script:warnings = @()

function Test-Command($command) {
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

function Write-Check($message, $success) {
    if ($success) {
        Write-Host "[OK] $message" -ForegroundColor Green
    } else {
        Write-Host "[X] $message" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Astrogoblin Comment Viewer Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# NVM / NODE.JS CHECKS
# =============================================================================

Write-Host "Checking Node.js requirements..." -ForegroundColor Yellow
Write-Host ""

# Check for nvm-windows
$nvmInstalled = Test-Command "nvm"

if (-not $nvmInstalled) {
    Write-Host "[!] nvm for Windows not found" -ForegroundColor Yellow
    Write-Host "    nvm-windows must be installed manually." -ForegroundColor Yellow
    Write-Host "    Download from: https://github.com/coreybutler/nvm-windows/releases" -ForegroundColor Cyan
    Write-Host "    After installing, close and reopen PowerShell, then run this script again." -ForegroundColor Yellow
    Write-Host ""
    $script:warnings += "nvm-windows is not installed. Download it from https://github.com/coreybutler/nvm-windows/releases"
} else {
    Write-Check "nvm for Windows installed" $true
}

# Check for Node.js
$nodeInstalled = Test-Command "node"
$nodeOk = $false

if ($nodeInstalled) {
    $nodeVersionRaw = (node --version) -replace "v", ""
    $nodeMajor = [int]($nodeVersionRaw.Split(".")[0])

    if ($nodeMajor -ge $RequiredNodeMajor) {
        $nodeOk = $true
        Write-Check "Node.js v$nodeVersionRaw (v$RequiredNodeMajor+ required)" $true
    } else {
        Write-Host "[!] Node.js v$nodeVersionRaw found but v$RequiredNodeMajor+ required" -ForegroundColor Yellow
    }
}

# Install Node.js via nvm if needed
if (-not $nodeOk -and $nvmInstalled) {
    Write-Host "  Installing Node.js v$RecommendedNodeVersion via nvm..." -ForegroundColor Yellow
    try {
        $ErrorActionPreference = "Continue"
        nvm install $RecommendedNodeVersion 2>&1 | Out-Null
        nvm use $RecommendedNodeVersion 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"

        # Refresh PATH to pick up the nvm-managed node
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'Machine')

        if (Test-Command "node") {
            $nodeVersionRaw = (node --version) -replace "v", ""
            $nodeOk = $true
            Write-Check "Node.js v$nodeVersionRaw installed via nvm" $true
        } else {
            Write-Host "[!] Node.js was installed but is not on PATH." -ForegroundColor Yellow
            Write-Host "    Close and reopen PowerShell, then run this script again." -ForegroundColor Yellow
            $script:errors += "Node.js was installed via nvm but could not be found on PATH. Reopen PowerShell and try again."
        }
    } catch {
        Write-Host "[X] Failed to install Node.js via nvm" -ForegroundColor Red
        $script:errors += "Could not install Node.js via nvm. Try manually: nvm install $RecommendedNodeVersion && nvm use $RecommendedNodeVersion"
    }
} elseif (-not $nodeOk) {
    $script:errors += "Node.js v$RequiredNodeMajor+ is required but not installed, and nvm is not available to install it."
}

# Check for npm
$npmInstalled = Test-Command "npm"
if ($npmInstalled) {
    $npmVersion = npm --version
    Write-Check "npm v$npmVersion" $true
} elseif ($nodeOk) {
    $script:errors += "npm not found despite Node.js being installed. Reinstall Node.js."
}

Write-Host ""

# =============================================================================
# STOP IF CRITICAL ERRORS
# =============================================================================

if ($script:errors.Count -gt 0) {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "  Setup cannot continue - errors found" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
    foreach ($err in $script:errors) {
        Write-Host "  [X] $err" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

if ($script:warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($warn in $script:warnings) {
        Write-Host "  [!] $warn" -ForegroundColor Yellow
    }
    Write-Host ""
}

# =============================================================================
# ENVIRONMENT FILE
# =============================================================================

Write-Host "Checking configuration..." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "[OK] Created .env from .env.example" -ForegroundColor Green
        Write-Host "  [!] You must add your Patreon Client ID and Secret to .env before running" -ForegroundColor Yellow
    } else {
        # Create a template .env
        @"
PATREON_CLIENT_ID=your_client_id_here
PATREON_CLIENT_SECRET=your_client_secret_here
PATREON_REDIRECT_URI=http://localhost:3000/oauth/callback
NODE_ENV=dev
"@ | Set-Content -Path ".env" -Encoding UTF8
        Write-Host "[OK] Created .env template" -ForegroundColor Green
        Write-Host "  [!] You must add your Patreon Client ID and Secret to .env before running" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] .env file exists" -ForegroundColor Green

    # Check if placeholder values are still present
    $envContent = Get-Content ".env" -Raw
    if ($envContent -match "your_client_id_here") {
        $script:warnings += "PATREON_CLIENT_ID is still set to the placeholder value in .env - update it before running."
        Write-Host "  [!] PATREON_CLIENT_ID needs to be configured in .env" -ForegroundColor Yellow
    }
}

Write-Host ""

# =============================================================================
# INSTALL DEPENDENCIES
# =============================================================================

Write-Host "Installing Node.js dependencies..." -ForegroundColor Yellow
Write-Host ""

if (Test-Path "package.json") {
    $ErrorActionPreference = "Continue"
    npm install 2>&1 | Write-Host
    $npmExitCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($npmExitCode -eq 0) {
        Write-Host ""
        Write-Host "[OK] Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "[X] npm install failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[X] package.json not found - are you in the project root?" -ForegroundColor Red
    exit 1
}

Write-Host ""

# =============================================================================
# SUCCESS
# =============================================================================

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  1. Make sure your Patreon API credentials are set in .env" -ForegroundColor White
Write-Host ""
Write-Host "  2. Start the server:" -ForegroundColor White
Write-Host "     npm start" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. Open in your browser:" -ForegroundColor White
Write-Host "     http://localhost:3000" -ForegroundColor Yellow
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Edit .env to configure:" -ForegroundColor White
Write-Host "    PATREON_CLIENT_ID       Your Patreon API client ID" -ForegroundColor Gray
Write-Host "    PATREON_CLIENT_SECRET   Your Patreon API client secret" -ForegroundColor Gray
Write-Host "    PATREON_REDIRECT_URI    OAuth callback URL (default: http://localhost:3000/oauth/callback)" -ForegroundColor Gray
Write-Host "    NODE_ENV                Set to 'production' for hosted deployments" -ForegroundColor Gray
Write-Host ""