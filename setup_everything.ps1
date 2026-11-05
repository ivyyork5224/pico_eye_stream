# First-time setup for Pico Neo 3 Pro Eye eye tracking. Run it again any time; finished steps are skipped.
#   powershell -ExecutionPolicy Bypass -File setup_everything.ps1
# Steps: adb (downloaded from Google), Steam + SteamVR + VRCFaceTracking, .NET 10 runtime,
# firewall rule (asks for admin once), headset connection, VRCFT module, desktop shortcut.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot 'find_adb.ps1')

$VrcftAppId = '3329480'
$SteamVrAppId = '250820'
$RuleName = 'VRCFT Pico Neo 3 eye (UDP 7777)'

function Step($n, $text) { Write-Host "`n[$n/7] $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "  OK  $text" -ForegroundColor Green }
function Todo($text) { Write-Host "  >>  $text" -ForegroundColor Yellow }
function Fail($text) {
    Write-Host "`n  $text" -ForegroundColor Red
    Write-Host "  Then run this setup again; finished steps are skipped." -ForegroundColor Red
    exit 1
}
function WaitEnter($text) { Write-Host "  $text" -ForegroundColor Yellow; [void](Read-Host "  Press Enter when done") }

# Steam library folders (Steam can install games on several drives)
function Get-SteamLibraries {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return @() }
    $steam = $steam -replace '/', '\'
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $libs += $m.Groups[1].Value -replace '\\\\', '\'
        }
    }
    return $libs | Select-Object -Unique
}

function Get-SteamApp($appId) {
    foreach ($lib in Get-SteamLibraries) {
        # [IO.Path] rather than Join-Path: a library on an unplugged drive must not stop the search
        $acf = [IO.Path]::Combine($lib, "steamapps\appmanifest_$appId.acf")
        if (Test-Path $acf) {
            $dir = [regex]::Match([IO.File]::ReadAllText($acf), '"installdir"\s+"([^"]+)"').Groups[1].Value
            $path = [IO.Path]::Combine($lib, "steamapps\common\$dir")
            if (Test-Path $path) { return $path }
        }
    }
    return $null
}

Write-Host "Pico Neo 3 Pro Eye eye tracking: first-time setup" -ForegroundColor White
Write-Host "This checks each part and fixes what it can. Keep this window open."

# Files from a downloaded zip are marked as "from the internet"; clear that so Windows doesn't warn
Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

# --- 1. adb ---------------------------------------------------------------------------
Step 1 "Android tools (adb), to talk to the headset"
$adb = Find-Adb
if ($adb) { Ok "adb found: $adb" }
else {
    Write-Host "  Downloading Android platform-tools from Google..."
    $zip = Join-Path $env:TEMP 'platform-tools-latest-windows.zip'
    try {
        Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $PSScriptRoot -Force   # makes .\platform-tools\adb.exe
        Remove-Item $zip -Force
    } catch { Fail "Download failed ($($_.Exception.Message)). Check the internet connection." }
    $adb = Find-Adb
    if (-not $adb) { Fail "adb still not found after the download." }
    Ok "adb installed: $adb"
}

# --- 2. Steam, SteamVR, VRCFaceTracking ----------------------------------------------
Step 2 "Steam, SteamVR and VRCFaceTracking"
if (-not (Get-SteamLibraries)) {
    Start-Process 'https://store.steampowered.com/about/'
    Fail "Steam isn't installed. The Steam download page has opened: install Steam and sign in."
}
Ok "Steam found"
$missing = $false
if (Get-SteamApp $SteamVrAppId) { Ok "SteamVR found" }
else { Todo "SteamVR isn't installed. Steam is opening its install page."; Start-Process "steam://install/$SteamVrAppId"; $missing = $true }
$vrcft = Get-SteamApp $VrcftAppId
if ($vrcft) { Ok "VRCFaceTracking found: $vrcft" }
else { Todo "VRCFaceTracking isn't installed. Steam is opening its install page."; Start-Process "steam://install/$VrcftAppId"; $missing = $true }
if ($missing) { Fail "Click Install in Steam and wait until the download finishes." }

# --- 3. .NET 10 runtime (VRCFaceTracking needs it) -------------------------------------
Step 3 ".NET 10 runtime, needed by VRCFaceTracking"
$netDir = Join-Path $env:ProgramFiles 'dotnet\shared\Microsoft.NETCore.App'
if (Get-ChildItem $netDir -Directory -Filter '10.*' -ErrorAction SilentlyContinue) { Ok ".NET 10 runtime found" }
else {
    $installed = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Installing it with winget (Windows may ask for permission)..."
        & winget install --id Microsoft.DotNet.Runtime.10 --exact --silent --accept-source-agreements --accept-package-agreements
        $installed = [bool](Get-ChildItem $netDir -Directory -Filter '10.*' -ErrorAction SilentlyContinue)
    }
    if ($installed) { Ok ".NET 10 runtime installed" }
    else {
        Start-Process 'https://dotnet.microsoft.com/download/dotnet/10.0'
        Fail "Install the .NET 10 Runtime (x64) from the page that just opened (the '.NET Runtime' one is enough)."
    }
}

# --- 4. Firewall --------------------------------------------------------------------
Step 4 "Windows Firewall: let the headset's data in"
$moduleExe = Join-Path $vrcft 'VRCFaceTracking.ModuleProcess.exe'
if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) { Ok "Firewall rule already there" }
else {
    Write-Host "  Adding a firewall rule. Windows will ask for admin permission: click Yes."
    # checked again as admin, in case reading the rules above was refused
    $cmd = "if (-not (Get-NetFirewallRule -DisplayName '$RuleName' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName '$RuleName' -Direction Inbound -Program '$moduleExe' -Protocol UDP -LocalPort 7777 -Profile Private,Domain -Action Allow }"
    try { Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', $cmd }
    catch { Fail "The firewall rule needs admin permission (you clicked No)." }
    if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) { Ok "Firewall rule added" }
    else { Fail "The firewall rule wasn't added." }
}
# only the connection to the router matters (VPNs and second adapters are often Public)
$public = Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Where-Object { $_.NetworkCategory -eq 'Public' -and $_.IPv4Connectivity -eq 'Internet' }
if ($public) {
    Todo "Your network '$($public[0].Name)' is set to Public, which blocks the headset."
    Todo "Change it: Windows Settings > Network & Internet > your connection > Network profile: Private."
}

# --- 5. Headset -------------------------------------------------------------------------
Step 5 "Headset connection over USB"
& $adb start-server | Out-Null
# checks every 2 s by itself, so accepting the prompt in the headset is enough; help is printed once per state
$shown = ''
while ($true) {
    $lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' -and $_ -notmatch ':' }
    if ($lines -match '\sdevice$') { Ok "Headset connected"; break }
    if ($lines -match '\sunauthorized$') {
        if ($shown -ne 'unauthorized') {
            Write-Host "  Put the headset on: accept 'Allow USB debugging?' and tick 'Always allow from this computer'." -ForegroundColor Yellow
            Write-Host "  Waiting for the headset..."
            $shown = 'unauthorized'
        }
    } elseif ($shown -ne 'missing') {
        Write-Host "  The headset isn't connected yet. On the headset:" -ForegroundColor Yellow
        Write-Host "    1. Settings > General > About: click 'Software Version' about 7 times (turns on developer mode)."
        Write-Host "    2. Settings > Developer: turn on 'USB debugging'."
        Write-Host "    3. Plug it into this PC with a USB-C data cable (some cables only charge)."
        Write-Host "    4. In the headset, accept 'Allow USB debugging?' and tick 'Always allow'."
        Write-Host "  Waiting for the headset (this checks by itself)..."
        $shown = 'missing'
    }
    Start-Sleep 2
}
Write-Host "  Also run the headset's eye tracking calibration (in its Settings) if you haven't yet." -ForegroundColor Yellow
Write-Host "  Calibration is per person: anyone else using the headset should run it for themselves." -ForegroundColor Yellow

# --- 6. VRCFT module --------------------------------------------------------------------
Step 6 "VRCFaceTracking module"
while (Get-Process VRCFaceTracking -ErrorAction SilentlyContinue) {
    WaitEnter "VRCFaceTracking is open. Close it first."
}
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install_vrcft_module.ps1')
if ($LASTEXITCODE -ne 0) { Fail "Installing the module failed (see above)." }

# --- 7. Desktop shortcut -------------------------------------------------------------
Step 7 "Desktop shortcut"
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Pico Eye Tracking.lnk'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = Join-Path $PSScriptRoot 'Start Eye Tracking.cmd'
$s.WorkingDirectory = $PSScriptRoot
$s.Save()
Ok "'Pico Eye Tracking' is on your desktop"

Write-Host "`nSetup is done." -ForegroundColor Green
Write-Host "Every time you play: turn on the headset, double-click 'Pico Eye Tracking' on the desktop,"
Write-Host "then start your PC streaming, VRCFaceTracking (from Steam) and VRChat."
Write-Host "If it says it can't reach the headset (can happen after a headset reboot), plug in USB and run it again."
$go = Read-Host "`nStart eye tracking now? (Y/n)"
if ($go -notmatch '^[nN]') { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start_eyestream.ps1') }
