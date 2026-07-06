# GitHub Actions 云端打包 APK

**本地零依赖**（甚至可以不装 Git）。把代码传到 GitHub，服务器自动打包成 APK，从 Release 里下载安装。

## 一、创建仓库

1. 登录 GitHub → 右上角 `+` → `New repository`
2. 仓库名：`buzz`（随便起，但下面示例都用这个名）
3. 可见性：**Private**（私有，只有你能看）或 Public 都行
4. **不要**勾选 `Add a README file`、`.gitignore`、`license`——保持空仓库
5. 点 `Create repository`

创建后你会看到一个空仓库页面，先别关，等下要用。

## 二、把项目文件上传

### 方式 A：网页上传（不用装任何东西）

1. 在空仓库页面，点中间的链接 `uploading an existing file`
2. **打开本地 `g:\手机震动\` 文件夹**
3. 选中里面的 **除 `.gitignore` 之外**的所有可见文件和文件夹，加上 `.gitignore` 一起拖进浏览器上传窗口
   - 需要上传：`README.md`, `GITHUB_ACTIONS.md`, `.gitignore`, `.github/`, `server/`, `client/`
   - **注意**：`.github` 是隐藏文件夹，Windows 默认可能看不到 → 资源管理器 → 查看 → 勾选"隐藏的项目"
4. 等所有文件上传完（下方进度条走完）
5. 底部输入 commit 信息：`initial commit`
6. 点 `Commit changes`

**如果拖不动整个文件夹**（GitHub 网页限制）：可以先只拖 `client/` 和 `.github/` 两个目录进去。这是打包必需的。

### 方式 B：用 Git 命令行（推荐，长期方便）

装 Git for Windows：https://git-scm.com/download/win

装完打开 PowerShell 执行（把 `你的用户名` 换成 GitHub 用户名）：

```powershell
cd G:\手机震动
git init
git branch -M main
git add .
git commit -m "initial commit"
git remote add origin https://github.com/你的用户名/buzz.git
git push -u origin main
```

第一次 push 会弹网页让你登录 GitHub，跟着提示走即可。以后改代码只需：
```powershell
git add .
git commit -m "改了xxx"
git push
```

## 三、看 Actions 自动打包

1. 上传/推送后，切到仓库的 **`Actions`** 标签页
2. 会看到 `Build Android APK` 这个 workflow 在跑（黄色圈圈）
3. 点进去可以看实时日志
4. **首次约需 5-10 分钟**（下 Flutter SDK 和 Gradle），之后 3-5 分钟

绿色对勾就是成功了。

## 四、下载 APK 装到手机

### 位置 1：Releases（推荐，手机浏览器可直接下）

- 仓库首页右边 → `Releases` → 最新版本 → 下载 `buzz_latest.apk`
- **手机浏览器打开你的仓库 → Releases → 下载安装**（不用电脑）

### 位置 2：Actions artifact（临时构建）

- Actions → 点某次成功的运行 → 下面 `Artifacts` 区域 → `buzz-apk`
- 会下载一个 zip，解压里面就是 APK

## 五、后续改代码

**用 Git 的话**：改完 → `git add . && git commit -m "..." && git push` → 自动打包 → Release 里拿新 APK

**用网页的话**：GitHub 网页进入 `client/lib/xxx.dart` → 点铅笔图标编辑 → `Commit changes` → 自动打包

**手动触发打包**（不改代码也想重新打）：
- Actions → 左侧 `Build Android APK` → 右边 `Run workflow` → `Run workflow` 按钮

## 六、常见问题

**Q：Actions 失败，第一次就红叉了**
A：点进日志看具体哪一步出错。90% 的可能是：
- `flutter create` 时报冲突 → 通常我们的配置能处理，如果不行发给我看日志

**Q：仓库设为 Public 有风险吗**
A：代码里唯一的敏感信息是服务器 IP `129.211.29.13`——这本来就是公网 IP。数据库密码在 `server/config.php` 里也会公开。**如果介意，把仓库设 Private**（GitHub 免费账号私有仓库也能用 Actions，每月 2000 分钟免费额度，我们用不到零头）。

**Q：不想让服务器密码进仓库**
A：`server/config.php` 加进 `.gitignore`，本地保留、别上传。或者把仓库设 Private。

**Q：Actions 每月免费额度用完了**
A：Private 仓库每月 2000 分钟，我们每次打包 ~5 分钟，够跑 400 次。用得完再说。

**Q：能不能只让签过名的 Release APK 让特定人看**
A：Private 仓库 → 设置里加 Collaborators。或者用 GitHub Releases 里的 "Pre-release" 标记。

## 打包流程图

```
本地改代码                    GitHub                                  你手机
   │                            │                                     │
   │ git push / 网页编辑         │                                     │
   ├───────────────────────────>│                                     │
   │                            │ ┌─ Actions 触发                     │
   │                            │ ├─ 装 JDK 17 + Flutter              │
   │                            │ ├─ flutter create . (如需)           │
   │                            │ ├─ flutter pub get                  │
   │                            │ ├─ flutter build apk --release      │
   │                            │ └─ 上传到 Release                   │
   │                            │                                     │
   │                            │      https://.../releases/latest    │
   │                            │<────────────────────────────────────┤
   │                            │        buzz_latest.apk              │
   │                            │─────────────────────────────────────>
   │                                                          浏览器下载
```
