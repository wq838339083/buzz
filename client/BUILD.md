# Buzz Android APK 一键打包

## 前置条件（一次性）

按 [README.md](README.md) 第一节走完 **环境准备**，最后 `flutter doctor` 里 Android toolchain 打勾即可。

## 打包

**方式 1：双击 `build.bat`**

在文件资源管理器里进入 `g:\手机震动\client\`，双击 `build.bat`，看着日志跑完就行。

**方式 2：PowerShell 命令**

```powershell
cd G:\手机震动\client
.\build.ps1
```

首次编译约 **5-10 分钟**（要下载 Gradle 依赖），之后增量编译大概 30 秒。

## 产物

打包成功后：
- `dist\buzz_YYYYMMDD_HHMM.apk` —— 带时间戳的历史版本
- `dist\buzz_latest.apk` —— 始终指向最新一次打包

脚本会自动打开 `dist` 文件夹。

## 装到手机

### 方式 A：USB 装（推荐调试用）

手机连电脑（USB 调试打开、授权），然后：

**双击 `install.bat`**，或：

```powershell
.\install.ps1
```

会自动 `adb install -r dist\buzz_latest.apk` 到手机。

### 方式 B：无线装

把 `dist\buzz_latest.apk` 通过微信/QQ/邮箱/网盘发到手机，点击安装。

第一次可能提示"未知来源应用"，去设置里允许即可。

## 手机上首次运行

装好后打开 Buzz，会连续弹几个权限对话框，**全部允许**：

1. **通知权限**：前台服务需要
2. **忽略电池优化**：**必选允许**，否则息屏几分钟就断线
3. **各家 ROM 的自启动/后台运行**（小米/华为等），到设置里手动开：
   - 小米：设置 → 应用管理 → Buzz → 自启动（打开）、省电策略 → 无限制
   - 华为：设置 → 应用 → 启动管理 → Buzz → 手动管理 → 全部打开
   - OPPO/vivo：找"自启动"和"后台耗电管理"，允许后台运行

## 常见问题

**Q：`build.bat` 一闪而过或报错**
A：直接双击有时看不到错误。改用 PowerShell：`Win + X` → PowerShell（管理员）→ `cd G:\手机震动\client` → `.\build.ps1`，能看完整报错。

**Q：Gradle 下载超时**
A：首次要下 Android Gradle Plugin (~200MB) 和依赖。等或者用代理。也可以改 `android/build.gradle.kts` 加阿里云镜像（首次生成后再改）。

**Q：`Android licenses not accepted`**
A：命令行执行：
```powershell
flutter doctor --android-licenses
```
一路按 `y`。

**Q：安装到手机提示"签名不一致"或"应用未安装"**
A：手机上先卸载旧版 Buzz 再装。Debug 和 Release 签名不同，也可能是不同电脑打的包签名不同。

**Q：想给多台手机装，需要每台都编译一次吗**
A：不用。`dist\buzz_latest.apk` 就是通用包，转发给别人装即可。

**Q：修改了服务器地址（config.dart），需要重新打包吗**
A：是的。改任何 Dart 代码都要重新 `build.bat`。
