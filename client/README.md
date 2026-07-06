# Buzz Android 客户端（Flutter，Windows 无需 Android Studio）

一份操作手册。全程只用 **VS Code + 命令行**。

---

## 一、环境准备（一次性，约 30 分钟）

### 1. 装 Git

下载：https://git-scm.com/download/win  一路默认下一步。

### 2. 装 Flutter SDK

1. 下载 Flutter SDK（选 Stable 版 zip）：https://docs.flutter.dev/get-started/install/windows
2. 解压到 `C:\src\flutter`（**注意**：路径不能有中文、不能有空格，不要放 `Program Files`）
3. 把 Flutter 加入 PATH：
   - Win + R → 输入 `sysdm.cpl` → 高级 → 环境变量
   - 在"用户变量"里找到 `Path` → 编辑 → 新建 → 填 `C:\src\flutter\bin`
   - 全部确定后 **重新打开** PowerShell / CMD 才能生效

### 3. 装 Java (JDK 17)

Flutter 需要 JDK。装 [Microsoft OpenJDK 17](https://learn.microsoft.com/en-us/java/openjdk/download)（.msi 版，会自动配好 PATH）。

验证：新开 PowerShell 执行 `java -version`，看到 17.x 即可。

### 4. 装 Android 命令行工具（**不装 Android Studio**）

1. 下载 Command line tools only：https://developer.android.com/studio 页面往下拉，找到 "Command line tools only" 下的 Windows 那行 zip
2. 解压后你会得到一个 `cmdline-tools` 文件夹，里面有 `bin/` `lib/` 等
3. 创建目录：`C:\Android\cmdline-tools\latest\`
4. 把上面解压出的 `cmdline-tools` 里的**内容**（不是文件夹本身）放进 `latest\` 里。最终结构：
   ```
   C:\Android\cmdline-tools\latest\bin\sdkmanager.bat
   C:\Android\cmdline-tools\latest\lib\...
   ```
5. 设置环境变量：
   - 新建用户变量 `ANDROID_HOME` = `C:\Android`
   - 编辑 `Path` 加两行：
     - `C:\Android\cmdline-tools\latest\bin`
     - `C:\Android\platform-tools`
6. **重新打开** PowerShell，安装 SDK 组件：
   ```powershell
   sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   sdkmanager --licenses
   ```
   `--licenses` 会问你一堆 y/n，全部按 `y` 回车。

### 5. 验证 Flutter 环境

```powershell
flutter doctor --android-licenses
flutter doctor
```

看到大致这样即可（Android Studio 那行是 X 不影响）：
```
[✓] Flutter
[✓] Windows Version
[✓] Android toolchain
[!] Android Studio (not installed)   ← 忽略
[✓] VS Code
[✓] Connected device
```

如果 `Android toolchain` 报错，运行它提示的命令；一般就是 licenses 没同意干净。

### 6. 装 VS Code + 插件

- VS Code：https://code.visualstudio.com/
- 装扩展：`Flutter`（作者 Dart Code），会自动带上 `Dart`

### 7. 手机开发者模式

1. 手机 → 设置 → 关于手机 → 连点 7 次"版本号"
2. 返回上一级 → 开发者选项 → 打开"USB 调试"
3. 用数据线连电脑，手机上弹出授权对话框，勾选"始终允许"→ 确定
4. 电脑 PowerShell 执行 `adb devices`，能看到你的手机就 OK

---

## 二、初始化项目（一次性）

这一步只需做**一次**。

```powershell
cd G:\手机震动\client
flutter create . --project-name buzz --org com.example --platforms=android
```

`flutter create .` 会在当前目录**补齐**脚手架文件（gradle、mipmap 图标等），已经存在的文件（我们写的 `pubspec.yaml`、`lib/`、`AndroidManifest.xml`、`MainActivity.kt`）不会被覆盖。

然后拉取依赖：
```powershell
flutter pub get
```

## 三、开发运行

**每次开发**：手机连电脑 + USB 调试打开，然后：

```powershell
cd G:\手机震动\client
flutter run
```

会自动编译并安装到手机，热重载改 dart 代码按 `r`，热重启按 `R`。

## 四、打包安装包（给其他手机装）

```powershell
flutter build apk --release
```

产物在 `build\app\outputs\flutter-apk\app-release.apk`，直接发给其他手机装即可。

如果想分架构做小包（可选）：
```powershell
flutter build apk --release --split-per-abi
```

---

## 五、后台保活设置（重要！）

装到手机上以后，**必须**手动做这两件事，否则息屏一会儿 APP 就被系统杀了：

1. **加入电池优化白名单**：APP 首次启动会弹窗提示，选"允许"。也可以：
   设置 → 应用 → Buzz → 电池 → 无限制 / 不受限制
2. **允许自启动 / 后台运行**（各家 ROM 不一样）：
   - 小米：设置 → 应用管理 → Buzz → 自启动（打开）、省电策略 → 无限制
   - 华为：设置 → 应用 → 启动管理 → Buzz → 手动管理 → 全部打开
   - OPPO/vivo：类似路径，找"自启动"和"后台耗电"
   - 原生 Android/Pixel：不需要额外设置

## 六、常见问题

**Q：`flutter run` 报 `No connected devices`**
A：`adb devices` 看下是否连上；手机 USB 模式选"文件传输"（不是"仅充电"）。

**Q：编译报 gradle 下载慢/失败**
A：编辑 `android/build.gradle.kts` 或 `android/settings.gradle.kts`，把 `google()`/`mavenCentral()` 前加一个阿里云镜像。或者用手机热点开个梯子。

**Q：APP 息屏 5-10 分钟后收不到震动**
A：前台服务通知栏应该常驻，如果没了，多半是被系统杀了。检查上面第五步的"电池优化"和"自启动"。

**Q：连不上服务器**
A：先浏览器打开 `http://129.211.29.13:7777/health` 看服务器是否在线；再检查手机是否能访问该 IP（用手机浏览器打开同一个 URL）。

---

## 项目结构

```
client/
├── pubspec.yaml              # 依赖声明
├── lib/
│   ├── main.dart             # 入口
│   ├── config.dart           # 服务器地址配置
│   ├── api.dart              # HTTP 登录/注册
│   ├── storage.dart          # 本地存储 (token/device_id/patterns)
│   ├── ws_service.dart       # WebSocket 长连接 + 心跳 + 重连
│   ├── vibrator_service.dart # 震动封装
│   ├── keepalive.dart        # 前台服务保活
│   ├── login_page.dart       # 登录/注册页
│   ├── home_page.dart        # 主页（发送/接收/设备列表）
│   └── pattern_editor.dart   # 自定义震动样式编辑器
└── android/
    └── app/src/main/
        ├── AndroidManifest.xml
        └── kotlin/com/example/buzz/MainActivity.kt
```
