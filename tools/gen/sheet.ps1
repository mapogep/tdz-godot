param([string]$Dir, [string]$Name, [string]$Out)
Add-Type -AssemblyName System.Drawing
$bmp = New-Object Drawing.Bitmap 1024, 1024
$g = [Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White)
$font = New-Object Drawing.Font "Arial", 28, ([Drawing.FontStyle]::Bold)
for ($i = 0; $i -lt 4; $i++) {
    $p = Join-Path $Dir ("{0}_{1}.png" -f $Name, $i)
    if (-not (Test-Path $p)) { continue }
    $im = [Drawing.Image]::FromFile($p)
    $x = ($i % 2) * 512; $y = [Math]::Floor($i / 2) * 512
    $g.DrawImage($im, $x, $y, 512, 512)
    $g.DrawString("$i", $font, [Drawing.Brushes]::Red, $x + 8, $y + 6)
    $im.Dispose()
}
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Jpeg)
