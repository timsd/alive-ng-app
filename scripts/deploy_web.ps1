# ALIVE NG Web App Build Script
# Firebase Hosting has been disabled. Coolify deploys the root Dockerfile.

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

# Configure Environment
Write-Host "Configuring web environment..." -ForegroundColor Cyan
dart scripts/configure_web.dart
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to configure web environment." -ForegroundColor Red
    exit 1
}
Write-Host "Environment configured." -ForegroundColor Green

# Build web app
Write-Host "Building web app..." -ForegroundColor Cyan
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build web app." -ForegroundColor Red
    exit 1
}
Write-Host "Web app built successfully." -ForegroundColor Green

Write-Host ""
Write-Host "===================================" -ForegroundColor Green
Write-Host "   Web Build Completed Successfully   " -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host ""
Write-Host "Coolify should deploy from the root Dockerfile on port 80." -ForegroundColor Cyan
Write-Host ""
