# Generation helpers for the SwarmUI server (see GENERATION_GUIDE.md).
# Strictly one request at a time. Network is slow and may drop: every call is retried.
# Usage:  . .\tools\gen\swarm.ps1 ; then call New-Refs / New-Model3D

$Base = "http://93.170.220.177:7801"
$NegBase = "text, letters, numbers, watermark, logo, multiple objects, cropped, cut off, blurry, lowres, frame, border, dark background, dramatic lighting, floor, ground shadow"

function Invoke-Retry([scriptblock]$Action, [int]$Tries = 8) {
    for ($i = 1; $i -le $Tries; $i++) {
        try { return & $Action }
        catch {
            if ($i -eq $Tries) { throw }
            Write-Host ("  retry {0}: {1}" -f $i, $_.Exception.Message)
            Start-Sleep -Seconds ([Math]::Min(30, 4 * $i))
        }
    }
}

function New-SwarmSession {
    $r = Invoke-Retry { Invoke-RestMethod "$Base/API/GetNewSession" -Method Post -Body "{}" -ContentType "application/json" -TimeoutSec 60 }
    return $r.session_id
}

function Save-SwarmImage([string]$Ref, [string]$Out) {
    if ($Ref.StartsWith("data:")) {
        $b64 = $Ref.Substring($Ref.IndexOf(",") + 1)
        [IO.File]::WriteAllBytes($Out, [Convert]::FromBase64String($b64))
        return
    }
    $url = "$Base/" + ($Ref -replace ' ', '%20')
    Invoke-Retry { Invoke-WebRequest $url -OutFile $Out -UseBasicParsing -TimeoutSec 300 } | Out-Null
}

# 4 SDXL reference variants -> $OutDir\<Name>_0..3.png
function New-Refs([string]$Name, [string]$Prompt, [string]$Neg, [int]$Seed, [string]$OutDir) {
    $sid = New-SwarmSession
    $body = [ordered]@{
        session_id = $sid; images = 4; model = "sd_xl_base_1.0.safetensors"; width = 1024; height = 1024
        steps = 32; cfgscale = 7; seed = $Seed; sampler = "dpmpp_2m"; scheduler = "karras"
        prompt = $Prompt; negativeprompt = "$NegBase, $Neg"
    } | ConvertTo-Json
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $r = Invoke-Retry { Invoke-RestMethod "$Base/API/GenerateText2Image" -Method Post -Body $bytes -ContentType "application/json" -TimeoutSec 1200 } 3
    if ($r.error) { throw "swarm error: $($r.error)" }
    $i = 0
    foreach ($p in $r.images) {
        Save-SwarmImage $p (Join-Path $OutDir ("{0}_{1}.png" -f $Name, $i))
        $i++
    }
}

$GraphTemplate = @'
{
 "1": {"class_type": "LoadImage", "inputs": {"image": "__IMAGE__"}},
 "2": {"class_type": "SwarmRemBg", "inputs": {"images": ["1", 0]}},
 "3": {"class_type": "InvertMask", "inputs": {"mask": ["2", 1]}},
 "10": {"class_type": "Hy3DModelLoader", "inputs": {"model": "hunyuan3d-dit-v2-mini-turbo-fp16.safetensors", "attention_mode": "sdpa", "cublas_ops": false}},
 "11": {"class_type": "Hy3DGenerateMesh", "inputs": {"pipeline": ["10", 0], "image": ["1", 0], "mask": ["3", 0], "guidance_scale": 5.0, "steps": 5, "seed": __SEED__, "scheduler": "ConsistencyFlowMatchEulerDiscreteScheduler", "force_offload": true}},
 "12": {"class_type": "Hy3DVAEDecode", "inputs": {"vae": ["10", 1], "latents": ["11", 0], "box_v": 1.01, "octree_resolution": 384, "num_chunks": 8000, "mc_level": 0.0, "mc_algo": "mc", "enable_flash_vdm": true, "force_offload": true}},
 "13": {"class_type": "Hy3DPostprocessMesh", "inputs": {"trimesh": ["12", 0], "remove_floaters": true, "remove_degenerate_faces": true, "reduce_faces": true, "max_facenum": __FACES__, "smooth_normals": false}},
 "20": {"class_type": "SolidMask", "inputs": {"value": 0.8, "width": 1024, "height": 1024}},
 "21": {"class_type": "MaskToImage", "inputs": {"mask": ["20", 0]}},
 "22": {"class_type": "ImageScale", "inputs": {"image": ["1", 0], "upscale_method": "lanczos", "width": 1024, "height": 1024, "crop": "center"}},
 "23": {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["21", 0], "source": ["22", 0], "x": 0, "y": 0, "resize_source": false, "mask": ["3", 0]}},
 "24": {"class_type": "DownloadAndLoadHy3DDelightModel", "inputs": {"model": "hunyuan3d-delight-v2-0"}},
 "25": {"class_type": "Hy3DDelightImage", "inputs": {"delight_pipe": ["24", 0], "image": ["23", 0], "steps": 50, "width": __VIEW__, "height": __VIEW__, "cfg_image": 1.0, "seed": 42}},
 "30": {"class_type": "Hy3DMeshUVWrap", "inputs": {"trimesh": ["13", 0]}},
 "31": {"class_type": "Hy3DCameraConfig", "inputs": {"camera_azimuths": "0, 90, 180, 270, 0, 180", "camera_elevations": "0, 0, 0, 0, 90, -90", "view_weights": "1, 0.3, 0.7, 0.3, 0.3, 0.05", "camera_distance": 1.45, "ortho_scale": 1.2}},
 "32": {"class_type": "Hy3DRenderMultiView", "inputs": {"trimesh": ["30", 0], "render_size": 1024, "texture_size": 2048, "camera_config": ["31", 0], "normal_space": "world"}},
 "40": {"class_type": "DownloadAndLoadHy3DPaintModel", "inputs": {"model": "hunyuan3d-paint-v2-0-turbo"}},
 "41": {"class_type": "Hy3DSampleMultiView", "inputs": {"pipeline": ["40", 0], "ref_image": ["25", 0], "normal_maps": ["32", 0], "position_maps": ["32", 1], "view_size": __VIEW__, "steps": 10, "seed": 42, "camera_config": ["31", 0], "denoise_strength": 1.0}},
 "42": {"class_type": "ImageScale", "inputs": {"image": ["41", 0], "upscale_method": "lanczos", "width": 2048, "height": 2048, "crop": "disabled"}},
 "50": {"class_type": "Hy3DBakeFromMultiview", "inputs": {"images": ["42", 0], "renderer": ["32", 2], "camera_config": ["31", 0]}},
 "51": {"class_type": "Hy3DMeshVerticeInpaintTexture", "inputs": {"texture": ["50", 0], "mask": ["50", 1], "renderer": ["50", 2]}},
 "52": {"class_type": "CV2InpaintTexture", "inputs": {"texture": ["51", 0], "mask": ["51", 1], "inpaint_radius": 3, "inpaint_method": "ns"}},
 "53": {"class_type": "Hy3DApplyTexture", "inputs": {"texture": ["52", 0], "renderer": ["51", 2]}},
 "90": {"class_type": "Hy3DExportMesh", "inputs": {"trimesh": ["53", 0], "filename_prefix": "3D/__NAME__", "file_format": "glb", "save_file": true}}
}
'@

# Reference image -> textured GLB (Hunyuan3D-2 mini turbo) -> $OutGlb
function New-Model3D([string]$Name, [string]$ImagePath, [int]$Faces, [int]$View, [string]$OutGlb, [int]$Seed = 42) {
    $up = Invoke-Retry {
        $o = & curl.exe -s -S --max-time 300 -F "image=@$ImagePath" -F "overwrite=true" "$Base/ComfyBackendDirect/upload/image"
        if ($LASTEXITCODE -ne 0) { throw "upload failed ($LASTEXITCODE)" }
        $o | ConvertFrom-Json
    }
    $graph = $GraphTemplate.Replace("__IMAGE__", $up.name).Replace("__SEED__", "$Seed").Replace("__FACES__", "$Faces").Replace("__VIEW__", "$View").Replace("__NAME__", $Name)
    $cid = [guid]::NewGuid().ToString()
    $body = '{"prompt": ' + $graph + ', "client_id": "' + $cid + '"}'
    $r = Invoke-Retry { Invoke-RestMethod "$Base/ComfyBackendDirect/prompt" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -TimeoutSec 120 } 3
    $promptId = $r.prompt_id
    Write-Host "  prompt $promptId"
    $t0 = Get-Date
    while ($true) {
        Start-Sleep -Seconds 5
        $h = $null
        try { $h = Invoke-RestMethod "$Base/ComfyBackendDirect/history/$promptId" -TimeoutSec 60 } catch { continue }
        $entry = $h.$promptId
        if ($null -eq $entry) {
            if (((Get-Date) - $t0).TotalMinutes -gt 25) { throw "timeout waiting for $promptId" }
            continue
        }
        if ($entry.status.status_str -eq "error") { throw "comfy error: $($entry.status | ConvertTo-Json -Depth 6 -Compress)" }
        $file = $entry.outputs.'90'.'3d'[0]
        if ($null -eq $file) { throw "no 3d output: $($entry.outputs | ConvertTo-Json -Depth 6 -Compress)" }
        $url = "$Base/ComfyBackendDirect/view?filename=" + [Uri]::EscapeDataString($file.filename) + "&subfolder=" + [Uri]::EscapeDataString($file.subfolder) + "&type=output"
        Invoke-Retry { Invoke-WebRequest $url -OutFile $OutGlb -UseBasicParsing -TimeoutSec 600 } | Out-Null
        Write-Host ("  done in {0:N0} s -> {1} ({2:N1} MB)" -f ((Get-Date) - $t0).TotalSeconds, $OutGlb, ((Get-Item $OutGlb).Length / 1MB))
        return
    }
}
