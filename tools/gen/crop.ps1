param([string]$In, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Out, [double]$Fill = 0.88)
# Crop one object from a reference and center it on a 1024x1024 canvas filled with the reference background colour.
Add-Type -AssemblyName System.Drawing
$src = New-Object Drawing.Bitmap $In
$bg = $src.GetPixel(4, 4)
$bmp = New-Object Drawing.Bitmap 1024, 1024
$g = [Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear($bg)
$k = [Math]::Min(1024 * $Fill / $W, 1024 * $Fill / $H)
$dw = [int]($W * $k); $dh = [int]($H * $k)
$dst = New-Object Drawing.Rectangle ([int]((1024 - $dw) / 2)), ([int]((1024 - $dh) / 2)), $dw, $dh
$g.DrawImage($src, $dst, (New-Object Drawing.Rectangle $X, $Y, $W, $H), [Drawing.GraphicsUnit]::Pixel)
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png)
$src.Dispose()
