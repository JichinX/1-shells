# Linux 离线开发环境一键安装

快速在离线 Linux 环境中安装 Python 和 Node.js 开发环境。

## 包含内容

- **pyenv** - Python 版本管理器
- **fnm** - Node.js 版本管理器（Fast Node Manager）
- **Python** - 预下载的 Python 版本（3.12.0, 3.11.8）
- **Node.js** - 预下载的 Node.js 版本（v20.11.0, v18.19.0）

## 使用步骤

### 第一步：在有网环境下载

```bash
# 1. 给脚本执行权限
chmod +x download.sh

# 2. 运行下载脚本
./download.sh

# 3. 等待下载完成
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

# 2. 给脚本执行权限
chmod +x install.sh

# 3. 运行安装脚本
./install.sh

# 4. 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc
```

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

## 自定义版本

### 修改下载版本

编辑 `download.sh` 文件顶部的版本配置：

```bash
PYTHON_VERSIONS=("3.12.0" "3.11.8" "3.10.13")
NODE_VERSIONS=("20.11.0" "18.19.0" "16.20.2")
```

### 修改安装版本

编辑 `install.sh` 文件顶部的版本配置：

```bash
PYTHON_VERSION="3.12.0"
NODE_VERSION="20.11.0"
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

## 文件说明

```
.
├── download.sh          # 下载脚本（有网环境运行）
├── install.sh           # 安装脚本（离线环境运行）
├── README.md            # 本说明文档
└── offline-packages/    # 下载的离线包目录
    ├── pyenv-offline.tar.gz
    ├── Python-3.12.0.tgz
    ├── Python-3.11.8.tgz
    ├── fnm-linux.zip
    ├── node-v20.11.0-linux-x64.tar.gz
    ├── node-v18.19.0-linux-x64.tar.gz
    └── versions.txt
```

## 许可证

MIT License

## 相关链接

- [pyenv 官方文档](https://github.com/pyenv/pyenv)
- [fnm 官方文档](https://github.com/Schniz/fnm)
- [Python 官方下载](https://www.python.org/downloads/)
- [Node.js 官方下载](https://nodejs.org/en/download/)
