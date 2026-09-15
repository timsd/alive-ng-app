Add-Type -AssemblyName System.Drawing
$src = "store_assets/app_icon_512.png"
$sizes = @{
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" = 48
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" = 72
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" = 96
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" = 144
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
    "web/icons/Icon-192.png" = 192
    "web/icons/Icon-512.png" = 512
    "web/icons/Icon-maskable-192.png" = 192
    "web/icons/Icon-maskable-512.png" = 512
    "web/favicon.png" = 32
}

$resolvedSrc = (Resolve-Path $src).Path
$img = [System.Drawing.Image]::FromFile($resolvedSrc)

foreach ($entry in $sizes.GetEnumerator()) {
    $path = $entry.Key
    $s = $entry.Value
    $destDir = Split-Path $path -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $s, $s)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Generated $path ($s x $s)"
}
$img.Dispose()
Write-Host "All icons generated successfully!"
