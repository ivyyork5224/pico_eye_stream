# Pico Neo 3 Pro Eye → PC eye tracking (VRCFaceTracking)

**Setting this up? Follow [INSTALL.md](INSTALL.md).** This file explains how it works.
MIT licensed, see [LICENSE](LICENSE). Not affiliated with Pico or Tobii.

```
headset: eyestream (background, ~90 Hz) --Wi-Fi UDP 7777--> PC: VRCFT module "Pico Neo 3 Pro Eye" --> VRChat
```

It works **while the headset is streaming PC VR**; it was tested with PICO Business Streaming 2.0.0 in front.
`eyestream` runs as a plain adb shell program. It talks to Pico's eye tracking system service
(`pxreyetrackingservice`) through the public library `libeyetrackingclient.pxr.so`. No APK, no root.

The optional camera route (`eyecam`, for Baballonia / EyeTrackVR) reads the infrared eye images from Pico's
debug image dump (`debug.pxr.et.tobii.dumpimg`, 416×200 8-bit, both eyes side by side). It deletes each dump file
immediately, serves each eye as MJPEG on ports 8080 / 8081, and switches the dump off on exit.

## Files

| path | what |
|---|---|
| `INSTALL.md`, `install_guide.html` | install guide (same content; the HTML is the web page version) |
| `Start Eye Tracking.cmd` | start gaze tracking (runs `start_eyestream.ps1`) |
| `Start Eye Tracking + Cameras.cmd` | also start the eye camera streams |
| `Stop Eye Tracking.cmd` | stop both |
| `Show Eye Camera Addresses.cmd` | camera URLs with Copy buttons (`show_eye_addresses.ps1`) |
| `Install VRCFT Module.cmd` | install / update the VRCFT module (`install_vrcft_module.ps1`) |
| `find_adb.ps1` | finds adb.exe for the scripts |
| `voice_device.txt` | optional: part of an audio device name for the spoken messages (e.g. `Stealth 600`) |
| `headset/eyestream`, `headset/eyestream.c` | gaze sender for the headset (prebuilt arm64 + source) |
| `headset/eyecam`, `headset/eyecam.c` | eye camera MJPEG server for the headset (prebuilt + source) |
| `vrcft/dist/PicoNeo3EyeModule.dll`, `vrcft/*.cs*` | VRCFT 6 module (prebuilt + source) |
| `pc/pico_eye_receiver.py` | standalone receiver: live readout, CSV logging, raw VRChat OSC (don't run with VRCFT; both use UDP 7777) |
| `probe/eyeprobe.c` | raw dump tool used to map the data layout |
| `third_party/stb_image_write.h` | public-domain JPEG encoder used by eyecam |

## Packet format (UDP 7777, ASCII)

`PEYE,seq,time_s,ok,comb_status,l_status,r_status,gx,gy,gz,px,py,pz,l_open,r_open`
The gaze direction `g*` and origin `p*` are in Unity axes (+x right, +y up, +z forward). Openness is 0 or 1.

## Data layout (`GetEyeTrackingData_2_0`, 0xC8 bytes)

C API in `libeyetrackingclient.pxr.so`: `CreateClient()`, `StartEyeTracking(c)`, `StopEyeTracking(c)`,
`GetEyeTrackingData_2_0(c, long, int, out*)`. It returns 0 ok, -1 not connected, -2 shared memory failed, -3 no data,
and -7 from Start while the headset sleeps.

| offset | field |
|---|---|
| 0x00 / 0x04 / 0x08 | left / right / combined status bitmasks (0x34 / 0x34 / 0x43 when tracking) |
| 0x24 | combined gaze origin xyz (m) |
| 0x48 | combined gaze direction xyz, unit, **x right, y up, -z forward** |
| 0x54 / 0x58 | left / right openness (only 0 or 1) |
| 0x64 / 0x70 | left / right position guide xy |
| 0x7c | foveated gaze direction xyz |
| 0x8c | convergence distance |
| 0xa8 | int64 timestamp |
| 0xb0 / 0xb8 | left / right pupil position xy (camera image) |

No separate left/right gaze has been found. The module uses the combined gaze for both eyes.

**Eyelids:** openness is strictly 0 or 1. A slow-close test showed it stays 1 until the lid covers the pupil, and no
other field drifts as the lid lowers, so squints and half-closed lids can't be tracked from this data. The module
debounces each eye (2 frames) and eases between states (~25 ms closing, ~45 ms opening) so blinks don't snap or flicker.

## Known issue

If the sender is restarted while an old copy is still stopping, Pico's eye service can get stuck (it reports
"started" but gives no new frames). `start_eyestream.ps1` waits for old copies to exit to avoid this. If it still
happens, reboot the headset.
