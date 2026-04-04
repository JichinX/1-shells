#!/bin/bash
# 一键安装脚本 - 在离线环境运行
# 用途：安装 pyenv、fnm、Python、Node.js

set -e

# 默认配置
OFFLINE_DIR="offline-packages"
CONFIG_FILE="versions.conf"
PYTHON_VERSIONS=""
NODE_VERSIONS=""

# 解析配置文件
parse_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "警告: 配置文件 $config_file 不存在，使用默认版本"
        PYTHON_VERSIONS="3.12.0"
        NODE_VERSIONS="20.11.0"
        return
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过空行和注释
        [ -z "$line" ] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 解析 key = value
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # 去除尾部注释
            value="${value%%#*}"
            # 去除首尾空格
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            
            case "$key" in
                python_versions)
                    PYTHON_VERSIONS="$value"
                    ;;
                node_versions)
                    NODE_VERSIONS="$value"
                    ;;
            esac
        fi
    done < "$config_file"
    
    # 如果配置文件中没有版本，使用默认值
    [ -z "$PYTHON_VERSIONS" ] && PYTHON_VERSIONS="3.12.0"
    [ -z "$NODE_VERSIONS" ] && NODE_VERSIONS="20.11.0"
}

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

# 解析配置文件
parse_config "$CONFIG_FILE"

echo "配置信息:"
echo "  Python 版本: $PYTHON_VERSIONS"
echo "  Node.js 版本: $NODE_VERSIONS"
echo ""

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
echo "[2/4] 安装 Python..."

# 创建缓存目录
mkdir -p ~/.pyenv/cache

# 获取第一个版本作为默认版本
DEFAULT_PYTHON_VERSION=$(echo $PYTHON_VERSIONS | awk '{print $1}')

# 安装所有配置的 Python 版本
for PYTHON_VERSION in $PYTHON_VERSIONS; do
    echo "  处理 Python $PYTHON_VERSION..."
    
    # 复制 Python 源码包到缓存
    if [ -f "Python-$PYTHON_VERSION.tgz" ]; then
        cp Python-$PYTHON_VERSION.tgz ~/.pyenv/cache/
        
        # 检查是否已安装
        if pyenv versions | grep -q "$PYTHON_VERSION"; then
            echo "    Python $PYTHON_VERSION 已安装"
        else
            echo "    正在安装 Python $PYTHON_VERSION（可能需要几分钟）..."
            pyenv install $PYTHON_VERSION
            echo "    ✓ Python $PYTHON_VERSION 安装完成"
        fi
    else
        echo "    警告: 找不到 Python-$PYTHON_VERSION.tgz"
    fi
done

# 设置默认版本
if [ -n "$DEFAULT_PYTHON_VERSION" ]; then
    pyenv global $DEFAULT_PYTHON_VERSION
    echo "  ✓ 默认 Python 版本设置为 $DEFAULT_PYTHON_VERSION"
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
echo "[4/4] 安装 Node.js..."

# 创建 fnm 版本目录
mkdir -p ~/.fnm/node-versions

# 获取第一个版本作为默认版本
DEFAULT_NODE_VERSION=$(echo $NODE_VERSIONS | awk '{print $1}')

# 安装所有配置的 Node.js 版本
for NODE_VERSION in $NODE_VERSIONS; do
    echo "  处理 Node.js v$NODE_VERSION..."
    
    # 解压 Node.js
    if [ -f "node-v$NODE_VERSION-linux-x64.tar.gz" ]; then
        if [ -d ~/.fnm/node-versions/v$NODE_VERSION ]; then
            echo "    Node.js v$NODE_VERSION 已存在"
        else
            tar -xzf node-v$NODE_VERSION-linux-x64.tar.gz
            mv node-v$NODE_VERSION-linux-x64 ~/.fnm/node-versions/v$NODE_VERSION
            echo "    ✓ Node.js v$NODE_VERSION 解压完成"
        fi
        
        # 使用 fnm 安装
        fnm install v$NODE_VERSION
        echo "    ✓ Node.js v$NODE_VERSION 安装完成"
    else
        echo "    警告: 找不到 node-v$NODE_VERSION-linux-x64.tar.gz"
    fi
done

# 设置默认版本
if [ -n "$DEFAULT_NODE_VERSION" ]; then
    fnm use v$DEFAULT_NODE_VERSION
    fnm default v$DEFAULT_NODE_VERSION
    echo "  ✓ 默认 Node.js 版本设置为 v$DEFAULT_NODE_VERSION"
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
echo "   pyenv versions          # 查看已安装版本"
echo "   pyenv global 3.11.15    # 切换默认版本"
echo ""
echo "4. 切换 Node.js 版本:"
echo "   fnm list                # 查看已安装版本"
echo "   fnm use 24.14.1         # 切换版本"
echo "   fnm default 24.14.1     # 设置默认版本"
echo ""
