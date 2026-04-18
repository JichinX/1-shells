# Ubuntu 最小安装 - 基础开发环境依赖包清单

> 为最小化安装的 Ubuntu 系统补充开发/编译所需的依赖包

## 快速安装

### 在线环境（有网络）

```bash
# 最小化安装（仅核心编译工具）
sudo apt update && sudo apt install -y build-essential

# 基础开发环境（推荐）
sudo apt update && sudo apt install -y \
  build-essential git vim curl wget ca-certificates \
  unzip zip p7zip-full xz-utils htop tree lsof

# 完整开发环境（包含 Python 编译依赖）
sudo apt update && sudo apt install -y \
  build-essential git vim curl wget ca-certificates \
  unzip zip p7zip-full xz-utils htop tree lsof strace ltrace \
  libssl-dev zlib1g-dev libffi-dev libsqlite3-dev \
  libreadline-dev libbz2-dev libncurses-dev liblzma-dev \
  pkg-config autoconf automake libtool
```

### 离线环境（推荐：使用 apt-offline）

**方法 1: 在线 Ubuntu 系统下载，离线 Ubuntu 系统安装**

```bash
# 步骤 1: 在有网络的 Ubuntu 系统上下载
cd ubuntu-offline-packages

# 安装 apt-offline（仅下载机器需要）
sudo apt install -y apt-offline

# 下载所有层级的包及依赖（自动包含 apt-offline 本身）
bash apt-offline-download.sh

# 或只下载指定层级
bash apt-offline-download.sh -l 1 -l 2  # 只下载第 1、2 层

# 步骤 2: 传输到离线环境
scp -r ubuntu-base-dev-deps-offline user@offline-server:/tmp/

# 步骤 3: 在离线环境安装（无需预装 apt-offline）
cd /tmp/ubuntu-base-dev-deps-offline
sudo ./install.sh
```

**重要说明**：
- 离线包会自动包含 apt-offline 及其依赖
- 目标机器**无需预装** apt-offline
- 安装脚本会自动检测：如果有 apt-offline 则用它安装，否则用 dpkg

**方法 2: 非 Ubuntu 系统下载（macOS/Windows）**

```bash
# 步骤 1: 在有网络的环境下载
cd ubuntu-offline-packages

# 使用依赖解析脚本（自动下载所有依赖）
bash download-packages-with-deps.sh -c ubuntu-base-dev-deps.conf

# 步骤 2: 传输到离线环境
scp ubuntu-base-dev-deps.tar.gz user@offline-server:/tmp/

# 步骤 3: 在离线环境安装
cd /tmp
tar -xzf ubuntu-base-dev-deps.tar.gz
cd ubuntu-base-dev-deps
sudo dpkg -i *.deb
# 如果有依赖问题，运行：
sudo apt-get install -f -y
```

---

## 依赖包分层说明

### 第一层：核心编译工具（必需）

| 包名 | 说明 | 必要性 |
|------|------|--------|
| `build-essential` | 编译工具链元包 | **必需** |

**包含内容**：
- `gcc` - GNU C 编译器
- `g++` - GNU C++ 编译器
- `make` - 构建工具
- `dpkg-dev` - Debian 包开发工具
- `libc6-dev` - C 标准库头文件

**用途**：编译 C/C++ 程序、构建大多数开源软件的基础

---

### 第二层：基础开发工具（强烈推荐）

| 包名 | 说明 | 必要性 |
|------|------|--------|
| `git` | 分布式版本控制 | **必需** |
| `vim` | 经典文本编辑器 | 推荐 |
| `curl` | 数据传输工具 | **必需** |
| `wget` | 文件下载工具 | 推荐 |
| `ca-certificates` | SSL 证书（HTTPS 必需） | **必需** |
| `unzip` | ZIP 解压 | 推荐 |
| `zip` | ZIP 压缩 | 推荐 |
| `p7zip-full` | 7z 格式支持 | 可选 |
| `xz-utils` | xz 压缩工具 | 推荐 |

**用途**：
- 代码版本管理
- 文件下载和传输
- 压缩包处理

---

### 第三层：系统工具（推荐）

| 包名 | 说明 | 必要性 |
|------|------|--------|
| `htop` | 进程监控（比 top 更友好） | 推荐 |
| `tree` | 目录树显示 | 推荐 |
| `lsof` | 列出打开的文件 | 推荐 |
| `strace` | 系统调用跟踪 | 调试用 |
| `ltrace` | 库调用跟踪 | 调试用 |

**用途**：系统监控、调试、问题排查

---

### 第四层：Python 编译依赖

#### 必需依赖

| 包名 | 说明 | 影响 |
|------|------|------|
| `libssl-dev` | SSL/TLS 支持 | pip 无法使用 HTTPS |
| `zlib1g-dev` | 压缩支持 | gzip 模块不可用 |
| `libffi-dev` | FFI 支持 | ctypes 模块不可用 |
| `libsqlite3-dev` | SQLite 支持 | sqlite3 模块不可用 |

#### 推荐依赖

| 包名 | 说明 | 影响 |
|------|------|------|
| `libreadline-dev` | readline 支持 | Python 交互式 shell 无历史记录 |
| `libbz2-dev` | bz2 压缩支持 | bz2 模块不可用 |
| `libncurses5-dev` | ncurses 支持 | curses 模块不可用 |
| `libncursesw5-dev` | ncurses 宽字符 | 宽字符支持 |
| `liblzma-dev` | xz 压缩支持 | lzma 模块不可用 |

#### 可选依赖

| 包名 | 说明 | 影响 |
|------|------|------|
| `tk-dev` | Tkinter GUI | tkinter 模块不可用 |
| `libxml2-dev` | XML 处理 | xml.etree 性能下降 |
| `libxslt1-dev` | XSLT 处理 | lxml 库需要 |
| `libgdbm-dev` | GDBM 数据库 | dbm.gnu 模块不可用 |
| `uuid-dev` | UUID 支持 | uuid 模块需要 |

---

### 第五层：Node.js 开发依赖

| 包名 | 说明 | 必要性 |
|------|------|--------|
| `python3` | Node.js 编译需要 | 从源码编译时必需 |
| `g++` | C++ 编译器 | 从源码编译时必需 |
| `make` | 构建工具 | 从源码编译时必需 |

**注意**：如果使用 fnm/nvm 安装预编译版本，这些依赖不是必需的。

---

### 第六层：其他常用开发工具

| 包名 | 说明 | 必要性 |
|------|------|--------|
| `pkg-config` | 编译配置工具 | 很多库依赖 |
| `autoconf` | 自动配置脚本 | 构建旧项目需要 |
| `automake` | 自动生成 Makefile | 构建旧项目需要 |
| `libtool` | 通用库支持脚本 | 构建库文件需要 |

---

### 第七层：常用开发库（按需选择）

#### 数据库开发库

| 包名 | 说明 |
|------|------|
| `libmysqlclient-dev` | MySQL 客户端开发库 |
| `libpq-dev` | PostgreSQL 客户端开发库 |

#### 图形/图像处理库

| 包名 | 说明 |
|------|------|
| `libpng-dev` | PNG 图像库 |
| `libjpeg-dev` | JPEG 图像库 |
| `libfreetype6-dev` | 字体渲染库 |

---

## 不同场景的依赖组合

### 场景 1：最小化编译环境

```bash
# 仅安装核心编译工具
sudo apt install -y build-essential
```

**适用**：只需要编译简单 C/C++ 程序

---

### 场景 2：基础开发环境

```bash
sudo apt install -y \
  build-essential git vim curl wget ca-certificates \
  unzip zip xz-utils htop tree
```

**适用**：日常开发、脚本编写、代码管理

---

### 场景 3：Python 开发环境

```bash
sudo apt install -y \
  build-essential git curl wget ca-certificates \
  libssl-dev zlib1g-dev libffi-dev libsqlite3-dev \
  libreadline-dev libbz2-dev libncurses5-dev libncursesw5-dev liblzma-dev
```

**适用**：使用 pyenv 编译安装 Python

---

### 场景 4：完整开发环境

```bash
sudo apt install -y \
  build-essential git vim curl wget ca-certificates \
  unzip zip p7zip-full xz-utils htop tree lsof strace ltrace \
  libssl-dev zlib1g-dev libffi-dev libsqlite3-dev \
  libreadline-dev libbz2-dev libncurses5-dev libncursesw5-dev liblzma-dev \
  pkg-config autoconf automake libtool
```

**适用**：全栈开发、多种语言环境

---

## 验证安装

```bash
# 验证编译工具
gcc --version
g++ --version
make --version

# 验证 Python 编译依赖
python3 -c "import ssl; print('SSL OK')"
python3 -c "import zlib; print('zlib OK')"
python3 -c "import ctypes; print('ctypes OK')"
python3 -c "import sqlite3; print('sqlite3 OK')"

# 验证其他工具
git --version
curl --version
```

---

## 常见问题

### Q: 为什么最小安装缺少这些包？

A: 最小化安装只包含系统运行所需的基本组件，不包含开发工具。这可以减少磁盘占用和安全风险。

### Q: 能否只安装部分依赖？

A: 可以。根据实际需要选择安装。例如，如果不编译 Python，可以跳过 Python 编译依赖。

### Q: 如何查看已安装的包？

```bash
# 查看某个包是否安装
dpkg -l | grep build-essential

# 查看某个包包含的文件
dpkg -L build-essential
```

### Q: 如何清理不需要的依赖？

```bash
# 清理不再需要的依赖
sudo apt autoremove

# 清理下载缓存
sudo apt clean
```

---

## 相关链接

- [Ubuntu 官方文档](https://help.ubuntu.com/)
- [build-essential 包说明](https://packages.ubuntu.com/build-essential)
- [Python 编译依赖](https://devguide.python.org/setup/#build-dependencies)
