# Buzz —— 一键震动同账号设备

同一账号登录的多台安卓设备，可以互相发送/接收震动信号。
支持自定义震动节奏，接收方即使息屏也能收到（前台服务保活）。

## 技术栈

- **服务端**：PHP 8.2 + Workerman 4.x + MySQL（宝塔 Supervisor 守护）
- **客户端**：Flutter (Android)

## 目录结构

```
├── server/     PHP 服务端（部署到你的 CentOS 云服务器）
└── client/     Flutter Android 客户端（在 Windows 编译）
```

## 快速开始

### 1. 部署服务端

看 [server/README.md](server/README.md)。要点：
- 宝塔已装 PHP 8.2 + MySQL，需要再装 **Supervisor 管理器**
- PHP 8.2 需要**解除禁用函数**（`pcntl_*` `posix_*` `proc_open`）
- 数据库 `zhendong` 已建好
- 上传 `server/` 到 `/www/wwwroot/buzz/`
- `composer install --no-dev -o`
- Supervisor 添加守护进程启动
- 放行端口 **7777**（WS）+ **7778**（HTTP）
- 浏览器访问 `http://129.211.29.13:7778/health` 验证

### 2. 编译客户端

看 [client/README.md](client/README.md)。要点：
- Windows 装 Flutter SDK + JDK 17 + Android 命令行工具（**不装 Android Studio**）
- VS Code + Flutter 插件
- 手机开 USB 调试
- `cd client && flutter create . --project-name buzz --org com.example --platforms=android`
- `flutter pub get`
- `flutter run` 上手机看效果，或 `flutter build apk --release` 打安装包

### 3. 使用

1. 打开 APP → 注册一个账号（比如 `test / 1234`）
2. 首次会弹窗申请通知权限和电池优化白名单，**都要允许**
3. 在另一台手机装同样的 APP，用**同一账号**登录
4. 两台手机会在设备列表里看到对方
5. 点大按钮"震一下" → 另一台立刻震动
6. 接收方震动后，发送方会看到"XX 已收到"

## 架构

```
                        云服务器 (129.211.29.13)
                     ┌──────────────────────────┐
┌──────────┐  HTTP   │   PHP + Workerman        │  HTTP  ┌──────────┐
│ Android  │  :7778  │   ├─ HTTP  API (登录/注册)│  :7778 │ Android  │
│    A     │────────>│   └─ WebSocket (转发)    │<───────│    B     │
│ (发送方) │  WS     │              │           │  WS    │ (接收方) │
│          │  :7777  │           MySQL          │  :7777 │          │
│          │<========│                          │========│          │
└──────────┘         └──────────────────────────┘        └──────────┘
```

- 账号系统：用户名 + 密码，bcrypt 哈希，MySQL 存储
- 长连接：WebSocket，30s 心跳，掉线指数退避重连（2s→30s）
- 保活：前台服务常驻 + WakeLock + 电池优化白名单
- 震动：pattern 数组（毫秒交替停顿/震动），支持自定义强度

## 端口

| 端口 | 协议 | 用途 |
|------|------|------|
| 7777 | ws:// | WebSocket 长连接 |
| 7778 | http:// | 注册 / 登录 / 健康检查 |

## 后续可选升级

- **HTTPS/WSS**：申请域名 + Let's Encrypt 证书，改 `AppConfig.useTls = true`；服务端加 Nginx 反代到 443/8443
- **推送兜底**：APP 完全被杀（不是息屏）时收不到。可以接入极光/个推做兜底
- **iOS 客户端**：Flutter 代码复用度 90%+，需 macOS 打包 + 苹果开发者账号
- **消息记录**：现在是即时转发，未离线保存。想要历史记录需要给 server 加消息表
