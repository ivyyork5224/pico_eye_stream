# Installs (or removes) the "Pico Neo 3 Pro Eye" module for VRCFaceTracking 6 (Steam).
# Close VRCFaceTracking first.
#   powershell -ExecutionPolicy Bypass -File install_vrcft_module.ps1            install / update
#   powershell -ExecutionPolicy Bypass -File install_vrcft_module.ps1 -Remove    remove

param([switch]$Remove)

$guid = 'b7c3e1a2-5f4d-4e8a-9c61-0e3f7a9d2b54'
$dst = Join-Path $env:APPDATA "VRCFaceTracking\CustomLibs\$guid"
$dll = Join-Path $PSScriptRoot 'vrcft\dist\PicoNeo3EyeModule.dll'

if (Get-Process VRCFaceTracking -ErrorAction SilentlyContinue) {
    Write-Host "Close VRCFaceTracking first, then run this again." -ForegroundColor Yellow
    exit 1
}

if ($Remove) {
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force; Write-Host "Removed the Pico Neo 3 Pro Eye module." }
    else { Write-Host "The module isn't installed." }
    exit 0
}

if (-not (Test-Path $dll)) { Write-Host "Missing $dll" -ForegroundColor Red; exit 1 }

New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item $dll $dst -Force
$json = @"
{
  "ModuleId": "$guid",
  "LastUpdated": "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
  "Version": "0.2.0",
  "IsLocal": true,
  "Downloads": 0,
  "Ratings": 0,
  "Rating": 0.0,
  "AuthorName": "local",
  "ModuleName": "Pico Neo 3 Pro Eye",
  "ModuleDescription": "Eye tracking from a Pico Neo 3 Pro Eye via the eyestream sender on the headset (UDP 7777).",
  "UsageInstructions": "Start eyestream on the headset (Start Eye Tracking.cmd), then start VRCFT.",
  "DownloadUrl": "file:///$($PSScriptRoot -replace '\\','/')/INSTALL.md",
  "ModulePageUrl": "file:///$($PSScriptRoot -replace '\\','/')/INSTALL.md",
  "DllFileName": "PicoNeo3EyeModule.dll",
  "FileHash": null
}
"@
[IO.File]::WriteAllText((Join-Path $dst 'module.json'), $json, (New-Object Text.UTF8Encoding $false))

# Gaze smoothing settings, read when VRCFT starts. Kept on update so your tuning stays.
$settings = Join-Path $dst 'settings.txt'
if (-not (Test-Path $settings)) {
    @"
# Pico Neo 3 eye module settings. Restart VRCFaceTracking after changing them.
# gaze_smoothing: lower = steadier when looking at one spot, but slower to settle (0.1 to 10; 0 = off)
# gaze_speed: higher = less delay when the eyes move quickly, but a little more jitter (0 to 10)
gaze_smoothing = 1.0
gaze_speed = 3.0
"@ | Set-Content -Encoding ascii $settings
}
Write-Host "Installed the Pico Neo 3 Pro Eye module into $dst" -ForegroundColor Green

# Other eye modules grab VRCFT's eye slot first; warn about the ones we know of
$others = Get-ChildItem (Join-Path $env:APPDATA 'VRCFaceTracking\CustomLibs') -Recurse -Filter *.dll -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'ETVR|Baballonia|Pico4|PicoStreaming' }
if ($others) {
    Write-Host "`nOther eye-capable modules are installed; VRCFT gives the eyes to whichever loads first:" -ForegroundColor Yellow
    $others | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host "Remove or disable them in VRCFT's Module Registry if the eyes don't move."
}
