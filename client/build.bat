@echo off
REM Buzz APK 打包器 - 双击我
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0build.ps1"
echo.
echo 按任意键关闭窗口...
pause >nul
