Add-Type -AssemblyName System.Drawing
$logo = [System.Drawing.Bitmap]::FromFile((Resolve-Path "assets\images\entry_logo.png").Path)

function Resize-Image($srcBmp, $targetPath, $w, $h) {
    $dest = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($srcBmp, 0, 0, $w, $h)
    $g.Dispose()
    $dest.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $dest.Dispose()
    Write-Host "Saved: $targetPath ($w x $h)"
}

Resize-Image $logo "android\app\src\main\res\mipmap-mdpi\ic_launcher.png" 48 48
Resize-Image $logo "android\app\src\main\res\mipmap-mdpi\launcher_icon.png" 48 48

Resize-Image $logo "android\app\src\main\res\mipmap-hdpi\ic_launcher.png" 72 72
Resize-Image $logo "android\app\src\main\res\mipmap-hdpi\launcher_icon.png" 72 72

Resize-Image $logo "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" 96 96
Resize-Image $logo "android\app\src\main\res\mipmap-xhdpi\launcher_icon.png" 96 96

Resize-Image $logo "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" 144 144
Resize-Image $logo "android\app\src\main\res\mipmap-xxhdpi\launcher_icon.png" 144 144

Resize-Image $logo "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" 192 192
Resize-Image $logo "android\app\src\main\res\mipmap-xxxhdpi\launcher_icon.png" 192 192

Resize-Image $logo "android\app\src\main\res\drawable-mdpi\ic_launcher_foreground.png" 108 108
Resize-Image $logo "android\app\src\main\res\drawable-hdpi\ic_launcher_foreground.png" 162 162
Resize-Image $logo "android\app\src\main\res\drawable-xhdpi\ic_launcher_foreground.png" 216 216
Resize-Image $logo "android\app\src\main\res\drawable-xxhdpi\ic_launcher_foreground.png" 324 324
Resize-Image $logo "android\app\src\main\res\drawable-xxxhdpi\ic_launcher_foreground.png" 432 432

Resize-Image $logo "web\favicon.png" 32 32
Resize-Image $logo "web\icons\Icon-192.png" 192 192
Resize-Image $logo "web\icons\Icon-512.png" 512 512
Resize-Image $logo "web\icons\Icon-maskable-192.png" 192 192
Resize-Image $logo "web\icons\Icon-maskable-512.png" 512 512

$logo.Dispose()
Write-Host "All icons generated successfully!"
