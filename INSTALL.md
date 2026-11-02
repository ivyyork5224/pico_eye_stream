# Pico Neo 3 Pro Eye eye tracking for VRChat: install guide

Gets the Pico Neo 3 Pro Eye's built-in Tobii eye tracking into VRChat through **VRCFaceTracking**.
It **keeps working while the headset streams PC VR**. No root and no headset app are needed. A small
program runs on the headset over adb and sends the data to the PC over Wi-Fi.

```
headset: eyestream --Wi-Fi UDP 7777--> PC: VRCFaceTracking ("Pico Neo 3 Pro Eye" module) --> VRChat
```

**What you get:** gaze (where you look) and blinks/winks, at about 90 Hz.
**What you don't get:** half-closed eyelids or squints, because Pico only reports eyes as open or
closed (blinks are smoothed so they don't snap), and separate gaze for each eye (both eyes use the
combined gaze).

---

## What you need

### Hardware
- Pico **Neo 3 Pro Eye** (the "Eye" model; tested on system 5.11.3, Android 10), with **eye tracking switched on** in its settings
- Windows 10/11 PC on the **same network** as the headset (PC wired, headset on Wi-Fi of the same router is fine)
- A USB-C **data** cable (some cables only charge)

### Software: required

| Software | Where | Notes |
|---|---|---|
| **Android SDK Platform-Tools** (adb) | https://developer.android.com/tools/releases/platform-tools | Unzip to `C:\platform-tools`. Talks to the headset. |
| **VRCFaceTracking 6** | Steam (search "VRCFaceTracking") | **Steam version only.** The Microsoft Store version (5.x) crashes on this module. |
| **.NET 10 Desktop Runtime** | https://dotnet.microsoft.com/download/dotnet/10.0 | Only if VRCFT won't start; it needs this runtime. |
| **SteamVR** | Steam | |
| **PC streaming for the headset**, one of: | | PC and headset versions must match. |
| • **PICO Business Streaming** | Pico enterprise downloads | Tested: PC 2.0.0 with headset app 2.0.0 (Wi-Fi). |
| • **PICO Link** | Pico enterprise downloads | DisplayPort cable mode. Tested pair: PC 1.2.9.1 with headset 1.2.9. |
| **VRChat** + an avatar with VRCFT eye parameters | Steam | |
| **Windows PowerShell 5.1** | Built into Windows | Runs the `.cmd` launchers. Nothing to install. |

On the headset nothing gets installed from a store. The two small programs (`eyestream`, `eyecam`) are
copied over adb by the start script.

### Software: optional

| Software | Needed for |
|---|---|
| **Baballonia** (Steam) or **EyeTrackVR** app | The experimental camera route (smooth eyelids from camera images), see below |
| **Python 3** | `pc\pico_eye_receiver.py`: live readout / CSV logging / raw OSC without VRCFT |

### Software: only to rebuild from source

| Software | Needed for |
|---|---|
| **Android NDK r27c** (https://developer.android.com/ndk/downloads) | `headset\eyestream.c`, `headset\eyecam.c` |
| **.NET 10 SDK** (https://dotnet.microsoft.com/download/dotnet/10.0) | `vrcft\PicoNeo3EyeModule.cs` |
| `third_party\stb_image_write.h` | Included (public domain JPEG encoder used by eyecam) |

### Files from this folder
`pico_eye_stream\`: keep it together. The launchers find everything relative to themselves.

---

## Quick setup (recommended)

1. Extract the zip somewhere permanent, for example `C:\pico_eye_stream`, and keep the folder together.
2. Double-click **`Set Up Everything.cmd`** and follow what it says. It:
   - downloads adb (Android platform-tools) from Google into this folder
   - checks for Steam, SteamVR and VRCFaceTracking, and opens Steam's install page for any that are missing
   - installs the .NET 10 runtime if it's missing
   - adds the Windows Firewall rule (click **Yes** when Windows asks for admin permission)
   - walks you through developer mode, USB debugging and the first USB connection on the headset
   - installs the VRCFT module and puts a **Pico Eye Tracking** shortcut on the desktop

   If it stops at a step (for example "install VRCFaceTracking in Steam"), do that step and run it
   again. Finished steps are skipped.
3. Run the headset's **eye tracking calibration** yourself (in the headset's Settings). It's per
   person, so anyone else who uses the headset should run it too.
4. Go to **Part 2: every session**.

You still need to set up your PC streaming (Business Streaming or PICO Link) yourself.

The steps below are the same setup done by hand, if you'd rather do that or the script gets stuck.

## Part 1: one-time setup (by hand)

### 0. Unpack the folder

1. Before extracting the zip, right-click it → **Properties** → tick **Unblock** (if shown) → OK.
   Otherwise Windows may warn about the `.cmd` files every time.
2. Extract it somewhere permanent, for example `C:\pico_eye_stream`. Keep the folder together.

### 1. Android platform-tools (adb) on the PC

1. Download **SDK Platform-Tools for Windows** from Google:
   https://developer.android.com/tools/releases/platform-tools
2. Unzip it so you have `C:\platform-tools\adb.exe`.
   (A `platform-tools` folder inside this project folder works too, as does adb on your PATH.)

### 2. Developer mode on the headset

1. On the headset: **Settings → General → About**, then click **Software Version** about 7 times until developer mode turns on.
2. **Settings → Developer**: turn on **USB debugging**.
3. Run the headset's **eye tracking calibration** (Settings → eye tracking / "Eye Calibration").
   Without it the data comes back invalid.

### 3. First USB connection

1. Plug the headset into the PC with the data cable.
2. In the headset, accept **"Allow USB debugging?"** and tick **Always allow from this computer**.
3. Check it on the PC:
   ```
   C:\platform-tools\adb.exe devices
   ```
   You should see a line ending in `device`. If it says `unauthorized`, accept the prompt in the headset.

### 4. Windows Firewall rule for VRCFT

VRCFT's module process has to receive UDP from the headset. Open **PowerShell as Administrator** and run:
```
New-NetFirewallRule -DisplayName "VRCFT Pico Neo 3 eye (UDP 7777)" -Direction Inbound -Program "C:\Program Files (x86)\Steam\steamapps\common\VRCFaceTracking\VRCFaceTracking.ModuleProcess.exe" -Protocol UDP -LocalPort 7777 -Profile Private -Action Allow
```
(Change the path if Steam is installed elsewhere.) Your network must be set to **Private** in Windows.

### 5. Install the VRCFT module

1. **Close VRCFaceTracking.**
2. Double-click **`Install VRCFT Module.cmd`**.
3. If it lists other eye modules (ETVR, Baballonia, Pico 4...), remove or disable them in VRCFT's
   **Module Registry**. VRCFT gives the eyes to whichever eye module loads first.

### 6. Optional: desktop shortcut and voice output

- Make a shortcut on your desktop to **`Start Eye Tracking.cmd`**.
- The start script speaks its result on the default audio output. To send it to a specific device (for
  example your headphones), put part of that device's name in `voice_device.txt`, such as `Stealth 600`.
  Delete the file to use the default.

---

## Part 2: every session

1. Turn on the headset.
   **If it was rebooted, plug in USB first**, because adb over Wi-Fi switches off on every reboot.
2. Double-click **`Start Eye Tracking.cmd`**.
   - It finds the headset, switches adb to Wi-Fi, reads the headset's current IP, and starts the sender.
   - It **speaks** the result (handy with the headset on). "You can unplug the USB cable" means it's running.
3. Start your PC streaming (Business Streaming / PICO Link) and **VRCFaceTracking from Steam**.
4. Start VRChat. Use an avatar with eye tracking (VRCFT parameters) and check in a mirror.

The sender keeps running until the headset turns off. It pauses while the headset sleeps and resumes when it wakes.
To stop it early, run **`Stop Eye Tracking.cmd`**.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "ADB was not found" | Install platform-tools (Part 1, step 1). |
| "Headset not found" / "Can't reach the headset over Wi-Fi" | Plug in USB and run Start again. Check the "Allow USB debugging" prompt in the headset. |
| "The headset is asking for permission" | Put the headset on and accept **Allow USB debugging**, then run Start again. |
| Windows sees the headset only as an audio device, no adb | USB debugging is off, or the cable/DP mode is blocking it. Use a plain USB-C data cable without the DP cable. |
| VRCFT shows the module but the eyes don't move | Firewall rule missing (Part 1, step 4). Or another eye module grabbed the eye slot: check VRCFT's **Output** page for `Tracking initialized via ...`. |
| Eyes jittery, or lag behind quick glances | Edit `settings.txt` in VRCFT's module folder (`%AppData%\VRCFaceTracking\CustomLibs\<module id>\`), then restart VRCFT. Still jittery: lower `gaze_speed` (e.g. 1.5). Laggy on quick glances: raise it (e.g. 5). VRCFT's Output page shows the values in use. |
| Eyes move the wrong way | Report it (see below); the axes are set in `vrcft/PicoNeo3EyeModule.cs`. |
| Cameras show "no answer" / sender log says `no new frames` while the headset is awake | Pico's eye service got stuck. Reboot the headset, plug in USB, run Start again. |
| Works, then stops after the headset was off your face | Normal: it resumes within about 5 s of the headset waking. |
| VRCFT crashes on its module page | You're running the **Microsoft Store** VRCFT 5.x. Use the Steam version. |
| PC streaming can't find the headset | Disable extra network adapters (VPNs like Hamachi, second NICs) in `ncpa.cpl`. |

To check things by hand:
```
C:\platform-tools\adb.exe shell "tail -3 /data/local/tmp/eyestream.log"
```
`90 pkt/s, 2600 valid` per 30 s means it's tracking. `0 valid` means the headset isn't on your face.

### Reporting back (testers)

If something doesn't work, send these to whoever gave you this folder:

1. What you did and what happened (or a photo of the Start window).
2. The headset log:
   ```
   C:\platform-tools\adb.exe shell "cat /data/local/tmp/eyestream.log"
   ```
3. VRCFaceTracking's **Output** page (copy all), especially the lines with `Tracking initialized` and `Pico`.
4. Headset system version (Settings → General → About) and your streaming app and version.

---

## Optional: camera route with Baballonia (experimental)

`Start Eye Tracking + Cameras.cmd` also streams the headset's **infrared eye camera images** (about 77 fps)
so image-based trackers like **Baballonia** or **EyeTrackVR** can estimate smooth eyelids:

- Left eye `http://<headset-ip>:8080/`, right eye `http://<headset-ip>:8081/`
  (**`Show Eye Camera Addresses.cmd`** shows them with Copy buttons and updates Baballonia's saved addresses)
- In Baballonia: OSC send port **8888**, receive **8889**; VRCFT module mode **Both**; Native VRC Eye Tracking **off**; run its eye calibration.
- In VRCFT, only the **Baballonia** module may claim the eyes. Remove the Pico Neo 3 and ETVR modules.

Caveats: Baballonia's models are trained on DIY eye cameras, and results on the Pico's through-the-lens
images were weak in testing. The images come from Pico's debug image dump, which writes to the headset's
storage (each frame is deleted within milliseconds). Run it only when you use it.

---

## Uninstall

- `powershell -ExecutionPolicy Bypass -File install_vrcft_module.ps1 -Remove` (with VRCFT closed)
- Run `Stop Eye Tracking.cmd`. A headset reboot also clears everything (the programs stay in `/data/local/tmp`):
  ```
  C:\platform-tools\adb.exe shell rm /data/local/tmp/eyestream /data/local/tmp/eyecam /data/local/tmp/eyeprobe
  ```
- Remove the firewall rule: `Remove-NetFirewallRule -DisplayName "VRCFT Pico Neo 3 eye (UDP 7777)"` (admin)

---

## Building from source

Only needed if you change the code. Prebuilt files ship in `headset\` and `vrcft\dist\`.

- **Headset programs** (Android NDK r27c):
  ```
  <ndk>\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android29-clang.cmd -O2 -o headset\eyestream headset\eyestream.c -ldl
  <ndk>\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android29-clang.cmd -O2 -o headset\eyecam headset\eyecam.c -lm
  ```
  After rebuilding, delete the old copy on the headset (`adb shell rm /data/local/tmp/eyestream`) so the start script pushes the new one.
- **VRCFT module** (.NET 10 SDK, VRCFT from Steam installed):
  ```
  dotnet build vrcft\PicoNeo3EyeModule.csproj -c Release -o vrcft\dist
  ```
  Then run `Install VRCFT Module.cmd`.

How it works and the reverse-engineered data layout are in [README.md](README.md).
