# 快速开始指南

## 最简使用流程

### 1️⃣ 有网环境（下载）

```bash
cd /path/to/basic-linux-offline
./download.sh
```

等待下载完成，会生成：
- `offline-packages/` 目录（包含所有安装包）
- `linux-offline-dev-tools.tar.gz`（打包文件）

### 2️⃣ 传输到离线环境

```bash
# 方式1: SCP
scp linux-offline-dev-tools.tar.gz user@offline-server:/tmp/

# 方式2: U盘拷贝
cp linux-offline-dev-tools.tar.gz /media/usb/
```

### 3️⃣ 离线环境（安装）

```bash
# 解压
cd /tmp
tar -xzf linux-offline-dev-tools.tar.gz

# 安装
./install.sh

# 重新加载配置
source ~/.bashrc
```

### 4️⃣ 验证

```bash
python --version   # Python 3.12.0
node --version     # v20.11.0
```

## 完整示例

### 场景：在公司内网服务器安装开发环境

```bash
# 步骤1: 在有网的开发机上下载
laptop$ cd ~/projects/basic-linux-offline
laptop$ ./download.sh
laptop$ ls -lh offline-packages/
# 输出:
# pyenv-offline.tar.gz
# Python-3.12.0.tgz
# Python-3.11.8.tgz
# fnm-linux.zip
# node-v20.11.0-linux-x64.tar.gz
# node-v18.19.0-linux-x64.tar.gz

# 步骤2: 传输到内网服务器
laptop$ scp linux-offline-dev-tools.tar.gz dev@internal-server:/tmp/

# 步骤3: 在内网服务器上安装
internal-server$ cd /tmp
internal-server$ tar -xzf linux-offline-dev-tools.tar.gz
internal-server$ ./install.sh
# 安装过程输出...
# [1/4] 安装 pyenv...
# [2/4] 安装 Python 3.12.0...
# [3/4] 安装 fnm...
# [4/4] 安装 Node.js v20.11.0...

internal-server$ source ~/.bashrc

# 步骤4: 验证
internal-server$ python --version
Python 3.12.0
internal-server$ node --version
v20.11.0
internal-server$ pyenv versions
  system
* 3.12.0 (set by /home/dev/.pyenv/version)
internal-server$ fnm list
* v20.11.0
  system
```

## 常见问题快速解决

### Q: Python 编译失败？
```bash
# 安装编译依赖
sudo apt install -y build-essential zlib1g-dev libssl-dev
# 或
sudo yum groupinstall -y "Development Tools"
```

### Q: 找不到 python/node 命令？
```bash
# 重新加载配置
source ~/.bashrc

# 或手动设置
export PATH="$HOME/.pyenv/bin:$HOME/.local/bin:$PATH"
```

### Q: 想安装其他版本？
```bash
# 编辑 download.sh，修改版本号
PYTHON_VERSIONS=("3.12.0" "3.11.8" "3.10.13")
NODE_VERSIONS=("20.11.0" "18.19.0" "16.20.2")

# 重新下载
./download.sh
```

## 目录结构

```
basic-linux-offline/
├── download.sh          # 下载脚本
├── install.sh           # 安装脚本
├── README.md            # 详细文档
├── QUICKSTART.md        # 本文件
└── offline-packages/    # 下载的包（运行 download.sh 后生成）
    ├── pyenv-offline.tar.gz
    ├── Python-*.tgz
    ├── fnm-linux.zip
    └── node-*.tar.gz
```

## 下一步

安装完成后，你可以：

1. **切换 Python 版本**
   ```bash
   pyenv install 3.11.8
   pyenv global 3.11.8
   ```

2. **切换 Node.js 版本**
   ```bash
   fnm install 18
   fnm use 18
   ```

3. **创建虚拟环境**
   ```bash
   # Python
   python -m venv myproject
   source myproject/bin/activate
   
   # Node.js
   npm init -y
   ```

## 需要帮助？

查看详细文档：`cat README.md`
