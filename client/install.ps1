# 把 dist/buzz_latest.apk 装到 USB 连接的手机上
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "找不到 adb 命令。请把 Android platform-tools 目录加入 PATH。" -ForegroundColor Red
    exit 1
}

$apk = Join-Path $PSScriptRoot 'dist\buzz_latest.apk'
if (-not (Test-Path $apk)) {
    Write-Host "找不到 APK：$apk" -ForegroundColor Red
    Write-Host "先运行 build.ps1 打包。" -ForegroundColor Yellow
    exit 1
}

Write-Host "检查已连接设备..." -ForegroundColor Cyan
$devices = (& adb devices) -split "`r?`n" |
    Where-Object { $_ -match '\tdevice$' }

if (-not $devices) {
    Write-Host "没有检测到已授权的手机。请检查：" -ForegroundColor Red
    Write-Host "  - USB 数据线连好（不是仅充电线）"
    Write-Host "  - 手机开启了 USB 调试"
    Write-Host "  - 手机上弹出的授权对话框点了'允许'"
    Write-Host ""
    & adb devices
    exit 1
}

Write-Host "找到设备：" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "安装中..." -ForegroundColor Cyan
& adb install -r $apk

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "安装成功！在手机上找到 Buzz 图标打开即可。" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "安装失败。如果是'签名不一致'，先在手机上卸载旧版再试。" -ForegroundColor Red
}
