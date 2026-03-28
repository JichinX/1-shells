# JetBrains 离线资源一键下载

在有网络的机器上运行，下载 JetBrains 远程开发所需的全部离线资源，传输到内网服务器后一键部署。

## 背景

JetBrains 远程开发采用 Client-Server 架构：

```
┌─────────────────┐         SSH          ┌──────────────────┐
│  本地机器        │ ◄─────────────────► │   远程服务器      │
│                 │                      │                  │
│ JetBrains       │   远程开发连接        │   Backend IDE    │
│ Gateway/Client  │ ───────────────────► │ (IntelliJ IDEA,  │
│                 │                      │  PyCharm 等)     │
└─────────────────┘                      └──────────────────┘
```

### 需要的组件

1. **Backend IDE**（服务器端）
   - 运行在远程服务器上的完整 IDE
   - 如 IntelliJ IDEA、PyCharm、WebStorm 等

2. **JetBrains Client**（客户端）
   - 运行在本地的轻量级客户端
   - 通过 SSH 连接到远程 Backend

3. **JetBrains Runtime (JBR)**
   - JetBrains 定制的 Java 运行时环境

4. **PGP KEYS**
   - 用于验证下载文件的签名

## 功能

- 自动获取最新稳定版 IDE
- 支持多个产品同时下载（IntelliJ IDEA、PyCharm、WebStorm 等）
- 支持多平台 Client（Linux、Windows、macOS）
- 自动生成服务器端部署脚本
- 支持配置文件，灵活定制

## 快速使用

```bash
# 下载 IntelliJ IDEA Ultimate（默认）
./download.sh

# 下载多个产品
./download.sh -p IU,PCP,WS

# 指定版本和架构
./download.sh -p IU -v 2024.1 -a arm64

# 使用配置文件
./download.sh --config config.conf

# 使用代理
./download.sh --proxy http://127.0.0.1:7890
```

## 服务器端部署

### 1. 上传到服务器

```bash
# 将下载的资源包传到内网服务器
scp -r jetbrains-offline-bundle user@server:/opt/
```

### 2. 安装 Backend IDE

```bash
cd /opt/jetbrains-offline-bundle

# 自动部署
sudo ./deploy-server.sh --product IU --user developer

# 或手动解压
mkdir -p ~/.cache/JetBrains/RemoteDev/dist/
tar -xzf backends/IU-2024.1-linux-x64.tar.gz -C ~/.cache/JetBrains/RemoteDev/dist/
```

### 3. 启动 Backend

```bash
# 方式一：通过 remote-dev-server.sh
~/.cache/JetBrains/RemoteDev/dist/IU-2024.1/bin/remote-dev-server.sh run /path/to/project --ssh-link-host $(hostname)

# 方式二：生成连接链接
~/.cache/JetBrains/RemoteDev/dist/IU-2024.1/bin/remote-dev-server.sh run /path/to/project \
  --ssh-link-host your-server.com \
  --ssh-link-user developer \
  --ssh-link-port 22
```

启动后会生成连接链接，复制到本地浏览器打开即可连接。

## 客户端配置（离线环境）

### 方式一：使用内网 Web 服务器

1. 部署内网 Web 服务器（nginx/apache）

```nginx
server {
    listen 80;
    server_name internal-server;

    location /jetbrains/ {
        alias /opt/jetbrains-offline-bundle/;
    }
}
```

2. 配置 JetBrains Gateway

```bash
# Linux
mkdir -p ~/.config/JetBrains/RemoteDev/
echo "http://internal-server/jetbrains/clients/" > ~/.config/JetBrains/RemoteDev/clientDownloadUrl
echo "http://internal-server/jetbrains/jbr/" > ~/.config/JetBrains/RemoteDev/jreDownloadUrl
echo "http://internal-server/jetbrains/keys/KEYS" > ~/.config/JetBrains/RemoteDev/pgpPublicKeyUrl

# macOS
mkdir -p ~/Library/Application\ Support/JetBrains/RemoteDev/
echo "http://internal-server/jetbrains/clients/" > ~/Library/Application\ Support/JetBrains/RemoteDev/clientDownloadUrl
echo "http://internal-server/jetbrains/jbr/" > ~/Library/Application\ Support/JetBrains/RemoteDev/jreDownloadUrl
echo "http://internal-server/jetbrains/keys/KEYS" > ~/Library/Application\ Support/JetBrains/RemoteDev/pgpPublicKeyUrl
```

### 方式二：手动安装 Client

将 `clients/` 目录中对应平台的 Client 解压到本地：

**Linux:**
```bash
mkdir -p ~/.cache/JetBrains/RemoteDev/clients/
tar -xzf clients/gateway-client-linux-x64.tar.gz -C ~/.cache/JetBrains/RemoteDev/clients/
```

**macOS:**
```bash
mkdir -p ~/Library/Caches/JetBrains/RemoteDev/clients/
tar -xzf clients/gateway-client-mac-x64.tar.gz -C ~/Library/Caches/JetBrains/RemoteDev/clients/
```

**Windows:**
```powershell
mkdir %LOCALAPPDATA%\JetBrains\RemoteDev\clients\
# 解压 clients/gateway-client-windows-x64.zip
```

## 配置文件

编辑 `config.conf` 自定义下载选项：

```ini
# 服务器架构
arch = x64

# 要下载的产品（逗号分隔）
products = IU,PCP,WS

# IDE 版本（留空则使用最新稳定版）
ide_version =

# 客户端平台
client_platforms = linux-x64,windows-x64,mac-x64,mac-arm64

# 是否下载 JBR 和 KEYS
download_jbr = true
download_keys = true
```

## 产品代码

| 代码 | 产品名称 |
|------|---------|
| IU   | IntelliJ IDEA Ultimate |
| IC   | IntelliJ IDEA Community |
| PCP  | PyCharm Professional |
| PCC  | PyCharm Community |
| WS   | WebStorm |
| GO   | GoLand |
| CL   | CLion |
| PS   | PhpStorm |
| RD   | Rider |
| DB   | DataGrip |

## 系统要求

### 服务器端（Linux）

- **操作系统**：Linux x64 或 arm64（Ubuntu 18.04+, CentOS 7+, Debian 10+）
- **Java**：17 或更高版本
- **必需依赖**：
  ```bash
  # Ubuntu/Debian
  sudo apt install openjdk-17-jdk libxext6 libxrender1 libxtst6 libxi6 libfreetype6 procps

  # CentOS/RHEL
  sudo yum install java-17-openjdk libXext libXrender libXtst libXi freetype procps
  ```

- **磁盘空间**：每个 Backend IDE 约 1-2 GB
- **内存**：建议 4 GB 以上

### 客户端

- **JetBrains Gateway**：223.7571.203 或更高版本
- **或**：安装了 Gateway 插件的 JetBrains IDE（2022.3+）

## 故障排除

### Backend 启动失败

```bash
# 检查 Java 版本
java -version  # 需要 17+

# 检查图形库依赖
ldconfig -p | grep -E "libxext|libxrender|libxtst|libxi"

# 查看 Backend 日志
tail -f ~/.cache/JetBrains/RemoteDev/dist/*/logs/idea.log
```

### Client 下载失败

确保 Gateway 配置的 URL 可访问：

```bash
curl -I http://internal-server/jetbrains/clients/
```

### SSH 连接失败

```bash
# 测试 SSH 连接
ssh user@server

# 检查 Backend 进程
ps aux | grep idea

# 检查端口监听
netstat -tlnp | grep 5990  # 默认 CWM 端口
```

### 权限问题

```bash
# 修复 Backend 目录权限
chown -R $USER:$USER ~/.cache/JetBrains/RemoteDev/

# 确保 remote-dev-server.sh 可执行
chmod +x ~/.cache/JetBrains/RemoteDev/dist/*/bin/remote-dev-server.sh
```

## 参考资料

- [JetBrains Remote Development](https://www.jetbrains.com/help/idea/remote-development-a.html)
- [Fully Offline Mode](https://www.jetbrains.com/help/idea/fully-offline-mode.html)
- [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)
