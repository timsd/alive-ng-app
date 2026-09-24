param(
    [string]$SourceBase = "assets/bible_bundles",
    [string]$DestBase = "assets/bible",
    [string]$ArchiveBase = "bible_bundles_archive_to_delete"
)

$bundles = @(
    @{ Lang = "en"; Version = "ASV"; Zip = "assets/bible_bundles/en/ASV.zip" },
    @{ Lang = "en"; Version = "KJV"; Zip = "assets/bible_bundles/en/KJV.zip" },
    @{ Lang = "en"; Version = "NASB"; Zip = "assets/bible_bundles/en/NASB.zip" },
    @{ Lang = "en"; Version = "NIV"; Zip = "assets/bible_bundles/en/NIV.zip" },
    @{ Lang = "en"; Version = "NKJV"; Zip = "assets/bible_bundles/en/NKJV.zip" },
    @{ Lang = "ha"; Version = "HAU"; Zip = "assets/bible_bundles/ha/HAU.zip" },
    @{ Lang = "ig"; Version = "IGBOB"; Zip = "assets/bible_bundles/ig/IGBOB.zip" },
    @{ Lang = "yo"; Version = "BM"; Zip = "assets/bible_bundles/yo/BM.zip" }
)

Write-Host "Starting extraction of Bible bundles..."

foreach ($b in $bundles) {
    $zipPath = $b.Zip
    $targetDir = Join-Path $DestBase "$($b.Lang)/$($b.Version)"
    
    if (Test-Path $zipPath) {
        Write-Host "Extracting $zipPath -> $targetDir"
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
        
        # Check if archive extracted into a subfolder or root
        $extractedItems = Get-ChildItem -Path $targetDir
        Write-Host "Extracted $($extractedItems.Count) items for $($b.Version)"
    } else {
        Write-Warning "Zip not found: $zipPath"
    }
}

Write-Host "Moving zip bundles to $ArchiveBase for later deletion..."
if (-not (Test-Path $ArchiveBase)) {
    New-Item -ItemType Directory -Path $ArchiveBase -Force | Out-Null
}

Copy-Item -Path "assets/bible_bundles/*" -Destination $ArchiveBase -Recurse -Force
Write-Host "All bundles backed up to $ArchiveBase."

# Remove original zip bundles folder to save assets bundle space
Remove-Item -Path "assets/bible_bundles" -Recurse -Force
Write-Host "Removed assets/bible_bundles folder from assets."
Write-Host "Done!"
