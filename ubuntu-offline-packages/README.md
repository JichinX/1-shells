# Ubuntu/Debian 离线包管理工具

用于在有网环境下载 Ubuntu/Debian 软件包及其依赖，然后在离线环境安装。

## 使用场景

- 离线服务器安装软件
- 内网环境部署
- 批量安装相同软件包
- 系统迁移和备份

## 快速开始

### 1. 在有网环境下载软件包

```bash
# 编辑配置文件，指定需要下载的软件包
vim packages.conf

# 运行下载脚本（需要在 Ubuntu/Debian 系统上运行）
bash download-packages.sh
```

### 2. 传输到离线环境

```bash
# 传输打包文件
scp ubuntu-offline-packages.tar.gz user@offline-server:~
```

### 3. 在离线环境安装

```bash
# 解压
tar -xzf ubuntu-offline-packages.tar.gz

# 安装
cd ubuntu-packages
sudo bash install-packages.sh
```

## 配置文件说明

`packages.conf` 配置文件支持以下选项：

### 基础配置

```ini
# 下载目录
download_dir = ubuntu-packages

# 打包文件名
archive_file = ubuntu-offline-packages.tar.gz

# Ubuntu 版本代号（可选）
# jammy (22.04), focal (20.04), bionic (18.04)
ubuntu_codename = 
```

### 软件包列表

```ini
# 基础工具
basic_packages = unzip zip curl wget git vim htop tree

# 开发工具
dev_packages = build-essential cmake pkg-config autoconf automake

# 网络工具
network_packages = net-tools iputils-ping openssh-client

# Python 开发
python_packages = python3 python3-pip python3-venv python3-dev

# Node.js（建议使用 fnm/nvm 管理）
nodejs_packages = nodejs npm
```

### 下载选项

```ini
# 是否下载依赖包（强烈推荐 true）
download_dependencies = true

# 是否下载推荐包
download_recommends = false

# 是否下载建议包
download_suggests = false
```

## 文件说明

```
ubuntu-offline-packages/
├── download-packages.sh    # 下载脚本（在有网环境运行）
├── install-packages.sh     # 安装脚本（在离线环境运行）
├── packages.conf           # 配置文件
└── README.md              # 本文档
```

## 工作原理

### 下载脚本

1. 解析配置文件，获取软件包列表
2. 更新 apt 包列表
3. 对每个软件包：
   - 使用 `apt-cache depends` 获取依赖
   - 使用 `apt-get download` 下载 .deb 包
4. 生成包列表文件
5. 打包所有文件

### 安装脚本

1. 检查运行环境
2. 使用 `dpkg -i` 安装所有 .deb 包
3. 使用 `apt-get install -f` 修复依赖
4. 使用 `dpkg --configure -a` 配置包
5. 验证安装结果

## 常见问题

### Q: 为什么需要在 Ubuntu/Debian 系统上下载？

A: 因为需要使用 `apt` 工具来获取正确的包版本和依赖关系。不同 Ubuntu 版本的包版本可能不同。

### Q: 如何确定需要哪些包？

A: 
1. 使用 `apt-cache depends <包名>` 查看依赖
2. 使用 `apt-cache rdepends <包名>` 查看反向依赖
3. 在配置文件中设置 `download_dependencies = true`

### Q: 安装时提示依赖问题怎么办？

A: 
```bash
# 修复依赖
sudo apt-get install -f

# 或手动安装缺失的依赖
sudo dpkg -i <依赖包.deb>
```

### Q: 如何查看已下载的包？

A: 
```bash
# 查看包列表
cat ubuntu-packages/package-list.txt

# 查看 .deb 文件
ls ubuntu-packages/*.deb
```

### Q: 如何只下载特定包而不包含依赖？

A: 在配置文件中设置：
```ini
download_dependencies = false
```

## 示例

### 下载基础工具

```ini
# packages.conf
basic_packages = unzip zip curl wget git vim htop tree
download_dependencies = true
```

```bash
bash download-packages.sh
```

### 下载开发环境

```ini
# packages.conf
dev_packages = build-essential cmake pkg-config
python_packages = python3 python3-pip python3-venv python3-dev
download_dependencies = true
```

```bash
bash download-packages.sh
```

## 注意事项

1. **版本匹配**：下载的包版本需要与目标系统版本匹配
2. **架构兼容**：确保架构一致（amd64/arm64）
3. **依赖完整**：建议开启 `download_dependencies = true`
4. **权限要求**：安装需要 sudo 权限

## 相关链接

- [Ubuntu Packages](https://packages.ubuntu.com/)
- [Debian Packages](https://www.debian.org/distrib/packages)
- [APT Howto](https://wiki.debian.org/Apt)
