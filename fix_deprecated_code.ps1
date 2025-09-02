# Simple PowerShell script to fix deprecated withOpacity usage

$ProjectPath = "C:\Users\DELL\Music\Alive\alive-ng-app\alive_flutter_app"
Set-Location $ProjectPath

Write-Host "Starting deprecated code fixing process..."
Write-Host "Project Path: $ProjectPath"

# Find all Dart files in the lib directory
$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

Write-Host "Found $($dartFiles.Count) Dart files to process..."

$totalFilesFixed = 0
$totalReplacements = 0

foreach ($file in $dartFiles) {
    try {
        $content = Get-Content $file.FullName -Raw
        
        if ([string]::IsNullOrEmpty($content)) {
            continue
        }
        
        # Count occurrences before replacement
        $beforeCount = ([regex]::Matches($content, '\.withOpacity\(')).Count
        
        if ($beforeCount -eq 0) {
            continue
        }
        
        # Replace .withOpacity(value) with .withValues(alpha: value)
        $newContent = $content -replace '\.withOpacity\(([^)]+)\)', '.withValues(alpha: $1)'
        
        # Count occurrences after replacement
        $afterCount = ([regex]::Matches($newContent, '\.withOpacity\(')).Count
        $replacements = $beforeCount - $afterCount
        
        if ($replacements -gt 0) {
            Set-Content -Path $file.FullName -Value $newContent
            Write-Host "Fixed $replacements occurrences in: $($file.Name)"
            $totalFilesFixed++
            $totalReplacements += $replacements
        }
    }
    catch {
        Write-Host "Error processing file $($file.Name): $($_.Exception.Message)"
    }
}

Write-Host "Files processed: $($dartFiles.Count)"
Write-Host "Files fixed: $totalFilesFixed"
Write-Host "Total replacements: $totalReplacements"

if ($totalReplacements -gt 0) {
    Write-Host "Running dart format..."
    try {
        & dart format lib/
        Write-Host "Code formatting completed"
    }
    catch {
        Write-Host "Could not run dart format"
    }
    
    Write-Host "Deprecated code fixing completed!"
} else {
     Write-Host "No deprecated withOpacity usage found."
}

Write-Host "Process finished."