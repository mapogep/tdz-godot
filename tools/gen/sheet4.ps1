param([string]$Prefix, [string]$Out)
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 1024, 1024
$g = [Drawing.Graphics]::FromImage($bmp)
$font = New-Object Drawing.Font "Arial", 20, ([Drawing.FontStyle]::Bold)
$names = @("front(-Z)", "side(+X)", "back(+Z)", "top")
for ($i = 0; $i -lt 4; $i++) {
    $p = "{0}_{1}.png" -f $Prefix, $i
    if (-not (Test-Path $p)) { continue }
    $im = [Drawing.Image]::FromFile($p)
    $x = ($i % 2) * 512; $y = [Math]::Floor($i / 2) * 512
    $g.DrawImage($im, $x, $y, 512, 512)
    $g.DrawString($names[$i], $font, [Drawing.Brushes]::Yellow, $x + 6, $y + 4)
    $im.Dispose()
}
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Jpeg)
