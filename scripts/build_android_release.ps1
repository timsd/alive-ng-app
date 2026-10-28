param (
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"

Write-Host "Syncing Coolify production environment and compiling $Target..." -ForegroundColor Cyan
node scripts/build_android_release.mjs $Target
