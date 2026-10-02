# Queue runner. Stage "refs": 4 SDXL variants per asset (skip existing).
# Stage "models": reference chosen in picks.json ({name: index}) -> GLB into assets/source (skip existing).
#   powershell -File tools\gen\run.ps1 -Stage refs -Out <dir> [-Only a,b]
#   powershell -File tools\gen\run.ps1 -Stage models -Out <dir>
param([string]$Stage = "refs", [string]$Out = "", [string[]]$Only = @())
$ErrorActionPreference = "Stop"
$Only = @($Only | ForEach-Object { $_ -split "," } | Where-Object { $_ -ne "" })
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot "swarm.ps1")
if ($Out -eq "") { $Out = Join-Path $Root "assets\source\refs" }
New-Item -ItemType Directory -Force $Out | Out-Null
$SrcDir = Join-Path $Root "assets\source"
$assets = Get-Content (Join-Path $PSScriptRoot "assets.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$picks = @{}
$pf = Join-Path $PSScriptRoot "picks.json"
if (Test-Path $pf) { (Get-Content $pf -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $picks[$_.Name] = $_.Value } }

foreach ($a in $assets) {
    if ($Only.Count -gt 0 -and -not ($Only -contains $a.name)) { continue }
    try {
        if ($Stage -eq "refs") {
            if (Test-Path (Join-Path $Out ("{0}_3.png" -f $a.name))) { Write-Host "skip $($a.name)"; continue }
            Write-Host ("[{0:HH:mm:ss}] refs {1}" -f (Get-Date), $a.name)
            New-Refs $a.name $a.prompt $a.neg $a.seed $Out
        } else {
            if (-not $picks.ContainsKey($a.name)) { continue }
            $glb = Join-Path $SrcDir ("{0}.glb" -f $a.name)
            if (Test-Path $glb) { Write-Host "skip $($a.name)"; continue }
            $img = Join-Path $Out ("{0}_{1}.png" -f $a.name, $picks[$a.name])
            Write-Host ("[{0:HH:mm:ss}] 3d {1} <- {2} (faces {3}, view {4})" -f (Get-Date), $a.name, $img, $a.faces, $a.view)
            New-Model3D $a.name $img ([int]$a.faces) ([int]$a.view) $glb
        }
    } catch {
        Write-Host ("FAILED {0}: {1}" -f $a.name, $_.Exception.Message)
    }
}
Write-Host ("[{0:HH:mm:ss}] stage {1} finished" -f (Get-Date), $Stage)
