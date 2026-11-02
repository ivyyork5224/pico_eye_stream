@echo off
rem Double-click for the first-time setup: gets adb, checks Steam/VRCFT/.NET, firewall, headset, module, shortcut.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_everything.ps1"
echo.
pause
