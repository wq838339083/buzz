# Buzz Android APK 一键打包脚本
# 用法：右键 → 用 PowerShell 运行，或在 PowerShell 里执行 .\build.ps1

$ErrorActionPreference = 'Stop'

$Script:StartTime = Get-Date
$Script:ProjectDir = $PSScriptRoot
Set-Location $Script:ProjectDir

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  [!] $msg" -ForegroundColor Yellow
}

function Write-Err($msg) {
    Write-Host "  [X] $msg" -ForegroundColor Red
}

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# ---- 1. 环境检查 ----
Write-Step "1/5 环境检查"

if (-not (Test-Command 'flutter')) {
    Write-Err "找不到 flutter 命令。请先按 client/README.md 装好 Flutter SDK 并加入 PATH。"
    exit 1
}
Write-Ok "flutter 已安装"

if (-not (Test-Command 'adb')) {
    Write-Warn "adb 未在 PATH 里（不影响打包，但影响 flutter run 上手机调试）"
} else {
    Write-Ok "adb 已安装"
}

Write-Host "  Flutter 版本："
flutter --version | Select-Object -First 3 | ForEach-Object { Write-Host "    $_" }

# ---- 2. 项目脚手架（首次运行才会补齐 gradle 等文件）----
Write-Step "2/5 项目脚手架"

$needsInit = -not (Test-Path (Join-Path $ProjectDir 'android\build.gradle.kts')) `
             -and -not (Test-Path (Join-Path $ProjectDir 'android\build.gradle'))

if ($needsInit) {
    Write-Host "  首次构建，运行 flutter create 补齐脚手架..."
    flutter create . --project-name buzz --org com.example --platforms=android
    if ($LASTEXITCODE -ne 0) {
        Write-Err "flutter create 失败"
        exit 1
    }
    Write-Ok "脚手架已生成"
} else {
    Write-Ok "脚手架已存在，跳过"
}

# ---- 3. 拉取依赖 ----
Write-Step "3/5 拉取依赖 (flutter pub get)"

flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Err "flutter pub get 失败"
    exit 1
}
Write-Ok "依赖已安装"

# ---- 4. 打包 APK ----
Write-Step "4/5 编译 Release APK（首次约需 5-10 分钟）"

flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Err "flutter build apk 失败"
    Write-Host ""
    Write-Host "常见原因："
    Write-Host "  - Gradle 首次下载慢：等一等，或用手机热点走梯子"
    Write-Host "  - Android licenses 未同意：执行 flutter doctor --android-licenses 全按 y"
    Write-Host "  - JAVA_HOME 未设置或指向错版本：需要 JDK 17"
    exit 1
}

# ---- 5. 收集产物 ----
Write-Step "5/5 收集产物"

$src = Join-Path $ProjectDir 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $src)) {
    Write-Err "找不到产物：$src"
    exit 1
}

$distDir = Join-Path $ProjectDir 'dist'
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$dstNamed = Join-Path $distDir "buzz_$stamp.apk"
$dstLatest = Join-Path $distDir 'buzz_latest.apk'

Copy-Item $src $dstNamed -Force
Copy-Item $src $dstLatest -Force

$sizeMB = [math]::Round((Get-Item $dstNamed).Length / 1MB, 2)

$elapsed = (Get-Date) - $Script:StartTime
$mins = [math]::Floor($elapsed.TotalMinutes)
$secs = [math]::Floor($elapsed.TotalSeconds - $mins * 60)

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " 打包成功！耗时 ${mins}m ${secs}s" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host " 产物 (${sizeMB} MB)："
Write-Host "   $dstNamed"
Write-Host "   $dstLatest"
Write-Host ""
Write-Host " 安装方式："
Write-Host "   A. 手机 USB 连电脑，执行： adb install -r `"$dstLatest`""
Write-Host "   B. 把 APK 发到手机（微信/QQ/邮箱），点击安装"
Write-Host ""

# 自动打开产物所在文件夹（可选）
try { Start-Process explorer.exe $distDir } catch {}
