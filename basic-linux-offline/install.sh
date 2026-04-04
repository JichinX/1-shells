#!/bin/bash
# 一键安装脚本 - 在离线环境运行
# 用途：安装 pyenv、fnm、Python、Node.js

set -e

# 配置
PYTHON_VERSION="3.12.0"
NODE_VERSION="20.11.0"
OFFLINE_DIR="offline-packages"

echo "=========================================="
echo "  Linux 离线开发环境 - 安装脚本"
echo "=========================================="
echo ""

# 检查离线包目录
if [ ! -d "$OFFLINE_DIR" ]; then
    echo "错误: 找不到 $OFFLINE_DIR 目录"
    echo "请先解压 linux-offline-dev-tools.tar.gz"
    exit 1
fi

cd $OFFLINE_DIR

# 检测当前 shell
SHELL_NAME=$(basename $SHELL)
if [ "$SHELL_NAME" = "bash" ]; then
    RC_FILE="$HOME/.bashrc"
elif [ "$SHELL_NAME" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
else
    echo "警告: 未识别的 shell: $SHELL_NAME, 使用 .bashrc"
    RC_FILE="$HOME/.bashrc"
fi

echo "检测到 Shell: $SHELL_NAME"
echo "配置文件: $RC_FILE"
echo ""

# ============================================
# 1. 安装 pyenv
# ============================================
echo "[1/4] 安装 pyenv..."

if [ -d "$HOME/.pyenv" ]; then
    echo "  pyenv 已存在，跳过安装"
else
    tar -xzf pyenv-offline.tar.gz
    mv pyenv-offline ~/.pyenv
    
    # 配置环境变量
    if ! grep -q 'PYENV_ROOT' $RC_FILE; then
        echo "" >> $RC_FILE
        echo "# pyenv" >> $RC_FILE
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> $RC_FILE
        echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> $RC_FILE
        echo 'eval "$(pyenv init -)"' >> $RC_FILE
    fi
    
    # 立即生效
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    echo "  ✓ pyenv 安装完成"
fi

# ============================================
# 2. 安装 Python
# ============================================
echo ""
echo "[2/4] 安装 Python $PYTHON_VERSION..."

# 创建缓存目录
mkdir -p ~/.pyenv/cache

# 复制 Python 源码包到缓存
if [ -f "Python-$PYTHON_VERSION.tgz" ]; then
    cp Python-$PYTHON_VERSION.tgz ~/.pyenv/cache/
    
    # 检查是否已安装
    if pyenv versions | grep -q "$PYTHON_VERSION"; then
        echo "  Python $PYTHON_VERSION 已安装"
    else
        echo "  正在安装 Python $PYTHON_VERSION（可能需要几分钟）..."
        pyenv install $PYTHON_VERSION
        pyenv global $PYTHON_VERSION
        echo "  ✓ Python $PYTHON_VERSION 安装完成"
    fi
else
    echo "  警告: 找不到 Python-$PYTHON_VERSION.tgz"
fi

# ============================================
# 3. 安装 fnm
# ============================================
echo ""
echo "[3/4] 安装 fnm..."

if command -v fnm &> /dev/null; then
    echo "  fnm 已安装，跳过"
else
    unzip -q -o fnm-linux.zip
    chmod +x fnm
    
    # 安装到用户目录
    mkdir -p ~/.local/bin
    mv fnm ~/.local/bin/
    
    # 配置环境变量
    if ! grep -q 'fnm' $RC_FILE; then
        echo "" >> $RC_FILE
        echo "# fnm" >> $RC_FILE
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> $RC_FILE
        echo 'eval "$(fnm env --shell bash)"' >> $RC_FILE
    fi
    
    # 立即生效
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(fnm env --shell bash)"
    
    echo "  ✓ fnm 安装完成"
fi

# ============================================
# 4. 安装 Node.js
# ============================================
echo ""
echo "[4/4] 安装 Node.js v$NODE_VERSION..."

# 创建 fnm 版本目录
mkdir -p ~/.fnm/node-versions

# 解压 Node.js
if [ -f "node-v$NODE_VERSION-linux-x64.tar.gz" ]; then
    if [ -d ~/.fnm/node-versions/v$NODE_VERSION ]; then
        echo "  Node.js v$NODE_VERSION 已存在"
    else
        tar -xzf node-v$NODE_VERSION-linux-x64.tar.gz
        mv node-v$NODE_VERSION-linux-x64 ~/.fnm/node-versions/v$NODE_VERSION
        echo "  ✓ Node.js 解压完成"
    fi
    
    # 使用 fnm 安装
    fnm install v$NODE_VERSION
    fnm use v$NODE_VERSION
    fnm default v$NODE_VERSION
    
    echo "  ✓ Node.js v$NODE_VERSION 安装完成"
else
    echo "  警告: 找不到 node-v$NODE_VERSION-linux-x64.tar.gz"
fi

# ============================================
# 验证安装
# ============================================
echo ""
echo "=========================================="
echo "  安装完成！正在验证..."
echo "=========================================="
echo ""

echo "Python 环境:"
echo "  版本: $(python --version 2>&1)"
echo "  路径: $(which python)"
echo ""

echo "Node.js 环境:"
echo "  版本: $(node --version)"
echo "  路径: $(which node)"
echo "  npm: $(npm --version)"
echo ""

echo "pyenv 版本:"
pyenv versions
echo ""

echo "fnm 版本:"
fnm list
echo ""

echo "=========================================="
echo "  后续步骤"
echo "=========================================="
echo ""
echo "1. 重新加载配置:"
echo "   source $RC_FILE"
echo ""
echo "2. 验证安装:"
echo "   python --version"
echo "   node --version"
echo ""
echo "3. 切换 Python 版本:"
echo "   pyenv install 3.11.8"
echo "   pyenv global 3.11.8"
echo ""
echo "4. 切换 Node.js 版本:"
echo "   fnm install 18"
echo "   fnm use 18"
echo ""
