# Ubuntu/Debian 离线包管理工具

用于在 macOS/Linux 上下载 Ubuntu 软件包，然后在离线 Ubuntu 环境安装。

## 特点

- ✅ **跨平台下载** - 可在 macOS/Linux 上运行，无需 Ubuntu 系统
- ✅ **镜像源支持** - 支持配置国内镜像源加速下载
- ✅ **多版本支持** - 支持 Ubuntu 22.04/20.04/18.04 等版本
- ✅ **多架构支持** - 支持 amd64/arm64/armhf 架构
- ✅ **离线安装** - 打包后传输到离线环境一键安装

## 使用场景

- 离线服务器安装软件
- 内网环境部署
- 批量安装相同软件包
- 在 macOS 上准备 Ubuntu 离线包

## 快速开始

### 1. 在 macOS/Linux 上下载软件包

```bash
# 方式 1: 使用配置文件
vim packages.conf
bash download-packages.sh

# 方式 2: 使用命令行参数
bash download-packages.sh -v 22.04 -a amd64

# 方式 3: 指定版本号
bash download-packages.sh --version 20.04

# 方式 4: 自动检测（如果在 Ubuntu 上运行）
bash download-packages.sh --version auto
```

### 命令行选项

```bash
bash download-packages.sh [选项]

选项:
  -c, --config FILE      配置文件路径（默认: packages.conf）
  -v, --version VERSION  Ubuntu 版本号或代号（如: 22.04 或 jammy）
  -a, --arch ARCH        架构（如: amd64, arm64）
  -m, --mirror URL       镜像源地址
  -h, --help             显示帮助信息

示例:
  bash download-packages.sh -v 22.04              # Ubuntu 22.04
  bash download-packages.sh -v jammy -a arm64     # Ubuntu 22.04 ARM64
  bash download-packages.sh -v 20.04 -m https://mirrors.tuna.tsinghua.edu.cn/ubuntu
```

### 2. 传输到离线 Ubuntu 环境

```bash
# 传输打包文件
scp ubuntu-offline-packages.tar.gz user@offline-server:~
```

### 3. 在离线 Ubuntu 环境安装

```bash
# 解压
tar -xzf ubuntu-offline-packages.tar.gz

# 安装
cd ubuntu-packages
sudo dpkg -i *.deb
```

## 配置文件说明

`packages.conf` 配置文件：

```ini
# ---- 基础配置 ----

# 下载目录
download_dir = ubuntu-packages

# 打包文件名
archive_file = ubuntu-offline-packages.tar.gz

# Ubuntu 版本和架构
# 版本：jammy (22.04), focal (20.04), bionic (18.04)
ubuntu_version = jammy

# 架构：amd64, arm64, armhf
architecture = amd64

# Ubuntu 镜像源
# 官方：http://archive.ubuntu.com/ubuntu
# 阿里云：http://mirrors.aliyun.com/ubuntu
# 清华：https://mirrors.tuna.tsinghua.edu.cn/ubuntu
mirror = http://mirrors.aliyun.com/ubuntu

# ---- 软件包列表 ----

# 直接指定包名（空格分隔）
packages = unzip zip curl wget git vim htop tree

# ---- 打包选项 ----

# 是否自动打包
auto_package = true

# 是否在打包后删除源文件
clean_after_package = false
```

## 工作原理

### 下载脚本（在 macOS/Linux 运行）

1. 从镜像源下载 `Packages.gz` 索引文件
2. 解析索引文件，查找指定包的下载路径
3. 使用 wget/curl 下载 .deb 包
4. 打包所有文件

### 安装（在 Ubuntu 运行）

```bash
# 简单安装
sudo dpkg -i *.deb

# 如果有依赖问题，修复
sudo apt-get install -f
```

## 注意事项

### ⚠️ 重要限制

1. **不自动下载依赖**
   - 此脚本只下载指定的包，不会自动下载依赖
   - 如果目标系统缺少依赖，安装时会报错
   - 需要手动在配置文件中列出所有需要的包

2. **版本匹配**
   - 下载的包版本与配置的 Ubuntu 版本对应
   - 确保目标系统版本与下载时配置的版本一致

3. **架构兼容**
   - 确保下载的架构与目标系统架构一致
   - amd64 (x86_64) / arm64 / armhf

### 如何确定需要的包？

**方法 1：在 Ubuntu 系统上查询**

```bash
# 查看包的依赖
apt-cache depends <包名>

# 查看依赖的依赖
apt-cache depends --recurse <包名>
```

**方法 2：在线查询**

- [Ubuntu Packages](https://packages.ubuntu.com/)
- 搜索包名，查看依赖关系

**方法 3：试错法**

1. 先下载主包
2. 在离线环境安装，查看报错信息
3. 补充下载缺失的依赖包

## 示例

### 下载基础工具

```ini
# packages.conf
ubuntu_version = jammy
architecture = amd64
packages = unzip zip curl wget git vim
```

```bash
bash download-packages.sh
```

### 下载开发工具

```ini
# packages.conf
ubuntu_version = jammy
architecture = amd64
packages = build-essential gcc g++ make cmake pkg-config
```

### 使用清华镜像源

```ini
mirror = https://mirrors.tuna.tsinghua.edu.cn/ubuntu
```

## 常见问题

### Q: 为什么不自动下载依赖？

A: 因为在 macOS 上无法运行 `apt` 工具来准确解析依赖关系。手动指定包列表可以确保精确控制下载内容。

### Q: 安装时提示依赖问题怎么办？

A: 
```bash
# 查看缺失的依赖
sudo dpkg -i *.deb

# 记录缺失的包名，在有网环境重新下载
# 然后再次安装
```

### Q: 如何查看可用的包？

A: 
- 访问 [Ubuntu Packages](https://packages.ubuntu.com/)
- 或在 Ubuntu 系统上使用 `apt search <关键词>`

### Q: 支持哪些 Ubuntu 版本？

A: 
- jammy (22.04 LTS)
- focal (20.04 LTS)
- bionic (18.04 LTS)
- 其他版本需要配置对应的代号

## 文件说明

```
ubuntu-offline-packages/
├── download-packages.sh    # 下载脚本（macOS/Linux）
├── packages.conf           # 配置文件
└── README.md              # 本文档
```

## 相关链接

- [Ubuntu Packages](https://packages.ubuntu.com/) - 在线查询包信息
- [Ubuntu 镜像列表](https://launchpad.net/ubuntu/+mirrors) - 全球镜像站
- [Debian Packages](https://www.debian.org/distrib/packages) - Debian 包查询
