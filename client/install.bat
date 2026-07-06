@echo off
REM 装 APK 到 USB 连接的手机
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
echo.
pause
