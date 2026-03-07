# ALIVE NG Web App Deployment Script
# This script builds and deploys the Flutter web app to Firebase Hosting

# Stop on any error
$ErrorActionPreference = "Stop"

# Display banner
Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "   ALIVE NG Web App Deployment   " -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
Write-Host "Checking Flutter installation..." -ForegroundColor Cyan
try {
    flutter --version | Out-Null
    Write-Host "Flutter is installed." -ForegroundColor Green
} catch {
    Write-Host "Flutter is not installed or not in PATH. Please install Flutter first." -ForegroundColor Red
    exit 1
}

# Check if Firebase CLI is installed
Write-Host "Checking Firebase CLI installation..." -ForegroundColor Cyan
try {
    firebase --version | Out-Null
    Write-Host "Firebase CLI is installed." -ForegroundColor Green
} catch {
    Write-Host "Firebase CLI is not installed or not in PATH. Please install Firebase CLI first." -ForegroundColor Red
    Write-Host "Run: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to clean project." -ForegroundColor Red
    exit 1
}
Write-Host "Clean completed." -ForegroundColor Green

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to get dependencies." -ForegroundColor Red
    exit 1
}
Write-Host "Dependencies updated." -ForegroundColor Green

# Build web app
Write-Host "Building web app..." -ForegroundColor Cyan
flutter build web --release --web-renderer canvaskit
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build web app." -ForegroundColor Red
    exit 1
}
Write-Host "Web app built successfully." -ForegroundColor Green

# Deploy to Firebase Hosting
Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to deploy to Firebase Hosting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "   Deployment Completed Successfully   " -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your app is now live at: https://app.alivenigeria.org" -ForegroundColor Cyan
Write-Host ""