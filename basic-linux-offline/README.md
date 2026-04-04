# Linux 离线开发环境一键安装

快速在离线 Linux 环境中安装 Python 和 Node.js 开发环境。

## 📦 包含内容

- **pyenv** - Python 版本管理器
- **fnm** - Node.js 版本管理器（Fast Node Manager）
- **Python** - 预下载的 Python 版本（可配置）
- **Node.js** - 预下载的 Node.js 版本（可配置）

## 🚀 快速开始

### 第一步：在有网环境下载

```bash
# 1. 给脚本执行权限
chmod +x download.sh

# 2. 运行下载脚本（使用默认配置）
./download.sh

# 3. 或使用自定义配置文件
./download.sh -c /path/to/custom.conf

# 4. 等待下载完成
# 会生成 offline-packages/ 目录和 linux-offline-dev-tools.tar.gz
```

### 第二步：传输到离线环境

```bash
# 将打包文件传输到离线 Linux 服务器
scp linux-offline-dev-tools.tar.gz user@offline-server:/tmp/
```

### 第三步：在离线环境安装

```bash
# 1. 解压
cd /tmp
tar -xzf linux-offline-dev-tools.tar.gz

# 2. 进入目录
cd offline-packages

# 3. 运行安装脚本
bash install.sh

# 4. 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc
```

## ⚙️ 配置文件

编辑 `versions.conf` 自定义下载选项：

```ini
# Python 版本列表
python_versions = 3.12.0 3.11.8 3.10.13

# Node.js 版本列表
node_versions = 20.11.0 18.19.0 16.20.2

# 使用国内镜像加速
node_mirror = https://npmmirror.com/mirrors/node

# 选择性下载
download_python = true
download_nodejs = true
download_pyenv = true
download_fnm = true
```

### 配置选项说明

**基础配置**：
- `download_dir` - 下载目录
- `archive_file` - 打包文件名

**Python 配置**：
- `python_versions` - Python 版本列表（空格分隔）
- `python_mirror` - Python 源码下载源

**Node.js 配置**：
- `node_versions` - Node.js 版本列表（空格分隔）
- `node_mirror` - Node.js 二进制包下载源
- `node_arch` - 架构（linux-x64 / linux-arm64）

**下载选项**：
- `download_python` - 是否下载 Python
- `download_nodejs` - 是否下载 Node.js
- `download_pyenv` - 是否下载 pyenv
- `download_fnm` - 是否下载 fnm

**打包选项**：
- `auto_package` - 是否自动打包
- `clean_after_package` - 打包后是否删除源文件

### 使用自定义配置

```bash
# 方式 1：使用默认配置文件（versions.conf）
./download.sh

# 方式 2：指定配置文件
./download.sh -c /path/to/custom.conf
./download.sh --config /path/to/custom.conf
```

## 🎯 特性

### 智能下载

- ✅ 自动跳过已存在的文件
- ✅ 只在有新文件时才重新打包
- ✅ 下载统计和状态提示
- ✅ 支持断点续传（手动重新运行即可）

### 完整打包

打包文件包含所有需要的文件：
```
linux-offline-dev-tools.tar.gz
  └── offline-packages/
      ├── install.sh          # 安装脚本
      ├── README.md           # 使用文档
      ├── QUICKSTART.md       # 快速开始
      ├── versions.conf       # 配置文件
      ├── versions.txt        # 版本信息
      ├── pyenv-offline.tar.gz
      ├── Python-*.tgz
      ├── fnm-linux.zip
      └── node-v*-linux-x64.tar.gz
```

解压后即可使用，无需额外文件！

## 验证安装

```bash
# 检查 Python
python --version
pyenv versions

# 检查 Node.js
node --version
fnm list
```

## 版本管理

### Python 版本切换

```bash
# 安装其他版本（需要提前下载对应的源码包）
pyenv install 3.11.8

# 设置全局版本
pyenv global 3.11.8

# 设置当前目录版本
pyenv local 3.12.0
```

### Node.js 版本切换

```bash
# 安装其他版本（需要提前下载对应的二进制包）
fnm install 18

# 切换版本
fnm use 18

# 设置默认版本
fnm default 18
```

## 系统要求

### 支持的操作系统
- Ubuntu 20.04+
- Debian 10+
- CentOS 7+
- RHEL 7+

### 硬件要求
- 内存：至少 2GB
- 磁盘空间：至少 2GB 可用空间

### 依赖工具

离线环境需要预先安装以下基础工具：

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y build-essential zlib1g-dev libssl-dev libffi-dev \
    libbz2-dev libreadline-dev libsqlite3-dev liblzma-dev
```

**CentOS/RHEL:**
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y zlib-devel openssl-devel libffi-devel \
    bzip2-devel readline-devel sqlite-devel xz-devel
```

如果离线环境缺少这些依赖，需要在有网环境提前下载对应的 RPM/DEB 包。

## 故障排除

### Python 编译失败

**问题:** 安装 Python 时编译失败

**解决:**
1. 检查是否安装了编译依赖（见上方系统要求）
2. 查看详细错误信息：`pyenv install -v 3.12.0`

### fnm 找不到 Node.js

**问题:** `fnm install` 提示找不到版本

**解决:**
1. 确认已将 Node.js 二进制包解压到 `~/.fnm/node-versions/v20.11.0`
2. 手动指定路径：
   ```bash
   fnm install /path/to/node-v20.11.0-linux-x64
   ```

### 环境变量不生效

**问题:** `python` 或 `node` 命令找不到

**解决:**
1. 确认已执行 `source ~/.bashrc`
2. 检查配置文件：
   ```bash
   cat ~/.bashrc | grep pyenv
   cat ~/.bashrc | grep fnm
   ```
3. 手动添加环境变量：
   ```bash
   export PYENV_ROOT="$HOME/.pyenv"
   export PATH="$PYENV_ROOT/bin:$PATH"
   eval "$(pyenv init -)"
   export PATH="$HOME/.local/bin:$PATH"
   eval "$(fnm env --shell bash)"
   ```

### 下载失败

**问题:** 下载文件失败，无错误信息

**解决:**
1. 检查网络连接
2. 检查 URL 是否正确（查看 versions.conf 中的镜像源配置）
3. 使用国内镜像加速：
   ```ini
   node_mirror = https://npmmirror.com/mirrors/node
   ```
4. 手动下载失败的文件，放到 `offline-packages/` 目录
5. 重新运行脚本（会自动跳过已存在的文件）

## 📝 文件说明

```
.
├── download.sh          # 下载脚本（有网环境运行）
├── install.sh           # 安装脚本（离线环境运行）
├── versions.conf        # 配置文件（版本、镜像源等）
├── README.md            # 本说明文档
├── QUICKSTART.md        # 快速开始指南
└── offline-packages/    # 下载的离线包目录
    ├── install.sh       # 安装脚本（打包时自动复制）
    ├── README.md        # 使用文档（打包时自动复制）
    ├── QUICKSTART.md    # 快速开始（打包时自动复制）
    ├── versions.conf    # 配置文件（打包时自动复制）
    ├── versions.txt     # 版本信息
    ├── pyenv-offline.tar.gz
    ├── Python-*.tgz
    ├── fnm-linux.zip
    └── node-v*-linux-x64.tar.gz
```

## 🔄 更新日志

### 2026-04-04

**新增功能**：
- ✅ 支持配置文件（versions.conf）
- ✅ 支持命令行参数指定配置文件
- ✅ 智能跳过已存在的文件
- ✅ 智能判断是否需要重新打包
- ✅ 打包时包含安装脚本和文档

**改进**：
- ✅ 下载统计和状态提示
- ✅ 支持国内镜像加速
- ✅ 选择性下载（Python、Node.js、pyenv、fnm）
- ✅ 解压后即可使用，无需额外文件

## 许可证

MIT License

## 相关链接

- [pyenv 官方文档](https://github.com/pyenv/pyenv)
- [fnm 官方文档](https://github.com/Schniz/fnm)
- [Python 官方下载](https://www.python.org/downloads/)
- [Node.js 官方下载](https://nodejs.org/en/download/)
- [npmmirror 镜像站](https://npmmirror.com/)
