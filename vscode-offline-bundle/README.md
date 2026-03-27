# VSCode 离线资源一键下载

在有网络的机器上运行，下载 VSCode 远程开发所需的全部离线资源，传输到内网服务器后一键部署。

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

```bash
# 1. 将 vscode-offline-bundle 目录传到服务器
scp -r vscode-offline-bundle user@server:/opt/

# 2. 在服务器上运行部署脚本
cd /opt/vscode-offline-bundle
chmod +x deploy-server.sh
sudo ./deploy-server.sh --install-extensions
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
