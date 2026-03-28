# 1-shells

一键脚本集合，用于快速部署和配置常用开发环境。

## 脚本列表

| 脚本 | 说明 |
|------|------|
| [homebrew-mirrors](./homebrew-mirrors/) | Homebrew 国内镜像源一键替换，支持 USTC / TUNA / 阿里云 / 腾讯云 |
| [vscode-offline-bundle](./vscode-offline-bundle/) | VSCode 离线资源一键下载，含 Server、扩展、code-server、openvscode-server |
| [jetbrains-offline-bundle](./jetbrains-offline-bundle/) | JetBrains 离线资源一键下载，支持 IntelliJ IDEA、PyCharm、WebStorm 等 |

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

详见各脚本目录下的 README。
