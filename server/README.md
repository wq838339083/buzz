# Buzz 服务端部署（宝塔 + PHP + Workerman）

技术栈：**PHP 8.2 + Workerman 4.x + MySQL**，纯 PHP 常驻内存进程，用宝塔 Supervisor 守护。

## 一、宝塔准备

### 1. 装 Supervisor 管理器

宝塔面板 → 软件商店 → 搜索安装 **Supervisor管理器**。

### 2. PHP 扩展 + 解除禁用函数（**关键步骤**）

宝塔面板 → 软件商店 → PHP 8.2 → 设置：

**安装扩展**（"安装扩展"标签页）：
- `event`（**强烈推荐**，事件循环性能好；没有也能跑）
- `pcntl`
- `posix`

**移除禁用函数**（"禁用函数"标签页）——如果下列在里面，全部选中删除：
- `pcntl_fork` `pcntl_signal` `pcntl_alarm` `pcntl_wait`
- `pcntl_signal_dispatch` `pcntl_waitpid`
- `posix_getpid` `posix_kill`
- `proc_open`

不解除，Workerman 起不来。

### 3. 数据库

已经建好了：
- 库名：`zhendong`
- 用户：`zhendong`
- 密码：`XzAsxPmdKPiT32MX`

表会在首次启动时自动创建，无需手动导入 SQL。

### 4. 放行两个端口

**两个端口都要放行**：
- `7777`（WebSocket 长连接）
- `7778`（HTTP 登录接口）

**两处**都要放行：
1. 宝塔面板 → 安全 → 添加 7777、7778（TCP）
2. 腾讯云控制台 → 云服务器 → 这台机器 → 安全组 → 入站规则 → 添加 TCP 7777、7778，源 `0.0.0.0/0`

## 二、上传代码

用宝塔文件管理器，把本地 `g:\手机震动\server\` 里的**所有文件**上传到 `/www/wwwroot/buzz/`（新建这个目录）。

上传后结构：
```
/www/wwwroot/buzz/
├── composer.json
├── config.php
├── start.php
├── README.md
└── src/
    ├── Auth.php
    ├── Db.php
    └── Server.php
```

## 三、安装 Composer 依赖

宝塔面板 → 终端（或 SSH），执行：

```bash
cd /www/wwwroot/buzz
composer -V
```

**如果找不到 composer 命令**，装一下（走阿里云镜像）：

```bash
php -r "copy('https://mirrors.aliyun.com/composer/composer.phar', 'composer.phar');"
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer
composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
```

**装依赖**：

```bash
cd /www/wwwroot/buzz
composer install --no-dev -o
```

装完会多出一个 `vendor/` 目录。

## 四、命令行先跑一次

**先手动跑一次**，确认能起来（Ctrl+C 停止）：

```bash
cd /www/wwwroot/buzz
php start.php start
```

期待输出：
```
Workerman[start.php] start in DEBUG mode
Workerman version:4.x.x          PHP version:8.2.x
tcp     www    buzz-ws     websocket://0.0.0.0:7777   1  [OK]
tcp     www    buzz-http   http://0.0.0.0:7778        1  [OK]
Press Ctrl+C to stop. Start success.
[Buzz] WebSocket listening on 0.0.0.0:7777
[Buzz] HTTP listening on 0.0.0.0:7778
```

**没跑起来常见原因**：
- `pcntl_*` 未定义 → 回到第一步解除禁用函数
- `Class 'Workerman\Worker' not found` → composer install 没成功
- `PDO connect failed` → 数据库账号密码不对，检查 `config.php`

看到 `Start success` 后按 Ctrl+C 停掉。

## 五、Supervisor 守护

宝塔 → Supervisor管理器 → 添加守护进程：

- **名称**：`buzz`
- **启动用户**：`www`
- **运行目录**：`/www/wwwroot/buzz`
- **启动命令**：`/www/server/php/82/bin/php start.php start`
  - PHP 路径按实际填。宝塔终端执行 `ls /www/server/php/` 看有哪些版本目录（一般是 `82` 或 `82.x.x`）
- **进程数量**：`1`（必须是 1）
- 保存后点"启动"

看日志确认有 `Start success`。

## 六、验证

浏览器打开：
```
http://129.211.29.13:7778/health
```

应返回：
```json
{"ok":true,"ts":...,"online":0}
```

打不开就检查：
1. Supervisor 里进程状态是不是 RUNNING
2. 7778 端口两处（宝塔 + 腾讯云安全组）都放行了
3. 服务器上执行 `curl http://127.0.0.1:7778/health` 能否返回

## 七、测试账号

浏览器 F12 → 控制台粘贴：

```js
fetch('http://129.211.29.13:7778/api/register', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({username: 'test', password: '1234'})
}).then(r => r.json()).then(console.log)
```

应返回：`{ok: true, token: "...", userId: 1, username: "test"}`

## 端口速查

| 端口 | 协议 | 用途 |
|------|------|------|
| 7777 | ws://  | WebSocket 长连接、震动指令转发 |
| 7778 | http:// | 注册、登录、健康检查 |

## 数据备份

只需备份 MySQL 数据库 `zhendong` 即可。宝塔的数据库定时备份就够了。

## 常用运维

- **修改代码后重启**：Supervisor 管理器里 `buzz` 点"重启"
- **看实时日志**：Supervisor 管理器里 `buzz` → 日志
- **手动重启（终端）**：
  ```bash
  cd /www/wwwroot/buzz && php start.php restart
  ```
- **停止**：`php start.php stop`
- **状态**：`php start.php status`
