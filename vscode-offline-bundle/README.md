# VSCode 离线资源一键下载

在有网络的机器上运行，下载 VSCode 远程开发所需的全部离线资源，传输到内网服务器后一键部署。

## 🚀 快速开始

### 场景：离线 + Python + FastAPI + 内网 AI 网关

#### 1️⃣ 自动配置（推荐）

```bash
# 运行快速配置脚本
chmod +x setup-vscode.sh
./setup-vscode.sh

# 选择 "3. 全部配置"
```

#### 2️⃣ 手动配置

**客户端配置（必需）**：
```json
// Windows: %APPDATA%\Code\User\settings.json
// macOS/Linux: ~/.config/Code/User/settings.json
{
  "remote.SSH.localServerDownload": "always",
  "remote.SSH.useExecServer": true,
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  }
}
```

**完整配置**：
- 📄 `recommended-settings.json` - 完整配置文件
- 📦 `recommended-extensions.md` - 扩展推荐列表
- 🔧 `setup-vscode.sh` - 快速配置脚本

## 功能

- 自动检测本地 VSCode 版本，或手动指定版本 / Commit ID
- 下载 VSCode Server 离线包（支持 x64 / arm64）
- 批量下载 VSCode 扩展（.vsix）
- 下载 code-server / openvscode-server（可选）
- 自动生成服务器端部署脚本
- 支持配置文件，灵活定制

## 快速使用

```bash
# 自动检测本地 VSCode 版本，下载全部资源
./download.sh

# 指定版本和架构
./download.sh -v 1.98.2 -a arm64

# 使用配置文件
./download.sh --config config.conf

# 使用代理
./download.sh --proxy http://127.0.0.1:7890
```

## 服务器端部署

### 步骤 1：配置客户端（关键！）

**⚠️ 重要**：VSCode ≥ 1.79.0 版本需要配置客户端，否则会提示 `localServerDownload failed`。

在你的 **本地 VSCode 客户端**添加配置：

- **Windows**: `%APPDATA%\Code\User\settings.json`
- **macOS/Linux**: `~/.config/Code/User/settings.json`

添加：
```json
{
  "remote.SSH.localServerDownload": "always"
}
```

这会阻止远程端自动 wget，使用你部署好的离线包。

### 步骤 2：传输和部署

```bash
# 1. 将 vscode-offline-bundle 目录传到服务器
scp -r vscode-offline-bundle user@server:/opt/

# 2. 在服务器上运行部署脚本
cd /opt/vscode-offline-bundle
chmod +x deploy-server.sh
sudo ./deploy-server.sh --install-extensions
```

### 步骤 3：验证部署

在服务器上检查：

```bash
# 检查目录结构
ls -la ~/.vscode-server/cli/servers/Stable-*/

# 检查标记文件
ls -la ~/.vscode-server/vscode-cli-*.done

# 验证 commit ID（应该和本地 VSCode 一致）
cat /opt/vscode-offline-bundle/vscode-server/commit-id.txt
```

## 配置文件

编辑同目录下的 `config.conf` 自定义下载选项：

```ini
arch = x64
output = ./vscode-offline-bundle

# 扩展列表
extensions << EOF
ms-python.python
dbaeumer.vscode-eslint
EOF
```

详见 `config.conf` 中的注释。

## 故障排查

### ❌ 错误：localServerDownload failed

**原因**：客户端没有配置 `remote.SSH.localServerDownload: "always"`

**解决**：见上方"步骤 1：配置客户端"

### ❌ 错误：仍然在下载/0 字节文件

**原因**：
1. 客户端配置未生效（重启 VSCode）
2. 远程端有缓存

**解决**：
```bash
# 1. 重启 VSCode 客户端

# 2. 在服务器清空缓存
rm -rf ~/.vscode-server/*

# 3. 重新部署
cd /opt/vscode-offline-bundle
sudo ./deploy-server.sh
```

### ❌ 错误：版本不匹配

**检查**：
```bash
# 本地 VSCode：Help → About → 查看 Commit

# 服务器检查：
cat /opt/vscode-offline-bundle/vscode-server/commit-id.txt
```

**解决**：重新下载对应版本的离线包

### ❌ 错误：权限不足

**解决**：
```bash
chmod -R u+rwx ~/.vscode-server
```
