# 1-shells

一键脚本集合，用于快速部署和配置常用开发环境。

## 脚本列表

| 脚本 | 说明 |
|------|------|
| [homebrew-mirrors](./homebrew-mirrors/) | Homebrew 国内镜像源一键替换，支持 USTC / TUNA / 阿里云 / 腾讯云 |
| [vscode-offline-bundle](./vscode-offline-bundle/) | VSCode 离线资源一键下载，含 Server、扩展、code-server、openvscode-server |
| [jetbrains-offline-bundle](./jetbrains-offline-bundle/) | JetBrains 离线资源一键下载，支持 IntelliJ IDEA、PyCharm、WebStorm 等 |
| [msys2-offline-bundle](./msys2-offline-bundle/) | MSYS2 离线环境一键配置，含 Zsh、Oh My Zsh、Starship、现代 CLI 工具 |
| [offline-claude](./offline-claude/) | Claude Code 离线安装包下载工具，支持 Linux/macOS 多平台 |
| [basic-linux-offline](./basic-linux-offline/) | Python/Node.js 离线安装包，用于离线 Linux 环境快速部署 |
| [ubuntu-offline-packages](./ubuntu-offline-packages/) | Ubuntu 离线包下载工具，支持基础开发依赖、编译工具链等 |
| [module-offline](./module-offline/) | PowerShell 模块离线包，用于 Windows 离线环境模块安装 |

## 快速使用

### Homebrew 镜像源

```bash
curl -fsSL https://raw.githubusercontent.com/JichinX/1-shells/main/homebrew-mirrors/brew-mirror.sh | bash
```

或克隆后运行：

```bash
git clone https://github.com/JichinX/1-shells.git
cd 1-shells/homebrew-mirrors
./brew-mirror.sh
```

### VSCode 离线资源

```bash
git clone https://github.com/JichinX/1-shells.git
cd 1-shells/vscode-offline-bundle
./download.sh
```

下载完成后将输出目录传到内网服务器，运行部署脚本：

```bash
sudo ./deploy-server.sh --install-extensions
```

### JetBrains 离线资源

```bash
git clone https://github.com/JichinX/1-shells.git
cd 1-shells/jetbrains-offline-bundle
./download.sh -p IU,PCP,WS  # 下载 IntelliJ IDEA、PyCharm、WebStorm
```

下载完成后将输出目录传到内网服务器，运行部署脚本：

```bash
sudo ./deploy-server.sh --product IU --user developer
```

### MSYS2 离线环境

Windows 环境离线配置，提供接近原生 Linux 的 shell 体验：

```powershell
# 在有外网的 Windows 机器上，下载资源
.\download-resources.ps1 -OutputPath ".\offline-resources"

# 拷贝到离线环境后安装
.\offline-resources\scripts\offline-install-msys2.ps1

# 在 MSYS2 中配置 Zsh 环境
bash ~/scripts/offline-setup-zsh.sh
```

### Claude Code 离线安装

```bash
git clone https://github.com/JichinX/1-shells.git
cd 1-shells/offline-claude

# 自动检测平台下载
./download-claude.sh

# 或指定平台
./download-claude.sh linux-x64 ./output
```

详见各脚本目录下的 README。
