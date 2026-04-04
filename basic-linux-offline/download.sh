#!/bin/bash
# 一键下载脚本 - 在有网环境运行
# 用途：下载 pyenv、fnm、Python、Node.js 离线安装包
# 优化：文件已存在则跳过下载

set -e

# 配置
PYTHON_VERSIONS=("3.12.0" "3.11.8")
NODE_VERSIONS=("20.11.0" "18.19.0")
DOWNLOAD_DIR="offline-packages"
ARCHIVE_FILE="linux-offline-dev-tools.tar.gz"

echo "=========================================="
echo "  Linux 离线开发环境 - 下载脚本"
echo "=========================================="

# 创建下载目录
mkdir -p $DOWNLOAD_DIR
cd $DOWNLOAD_DIR

# 统计变量
DOWNLOADED=0
SKIPPED=0

# 1. 下载 pyenv
echo ""
echo "[1/4] 下载 pyenv..."
if [ ! -f "pyenv-offline.tar.gz" ]; then
    echo "  下载中..."
    git clone --depth 1 https://github.com/pyenv/pyenv.git pyenv-offline
    tar -czf pyenv-offline.tar.gz pyenv-offline
    rm -rf pyenv-offline
    echo "  ✓ pyenv 下载完成"
    ((DOWNLOADED++))
else
    echo "  ✓ pyenv 已存在，跳过"
    ((SKIPPED++))
fi

# 2. 下载 Python 源码包
echo ""
echo "[2/4] 下载 Python 源码包..."
for version in "${PYTHON_VERSIONS[@]}"; do
    filename="Python-$version.tgz"
    if [ ! -f "$filename" ]; then
        echo "  下载 Python $version..."
        wget -q https://www.python.org/ftp/python/$version/$filename
        echo "  ✓ Python $version 下载完成"
        ((DOWNLOADED++))
    else
        echo "  ✓ Python $version 已存在，跳过"
        ((SKIPPED++))
    fi
done

# 3. 下载 fnm
echo ""
echo "[3/4] 下载 fnm..."
if [ ! -f "fnm-linux.zip" ]; then
    echo "  下载中..."
    wget -q https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip
    echo "  ✓ fnm 下载完成"
    ((DOWNLOADED++))
else
    echo "  ✓ fnm 已存在，跳过"
    ((SKIPPED++))
fi

# 4. 下载 Node.js 二进制包
echo ""
echo "[4/4] 下载 Node.js 二进制包..."
for version in "${NODE_VERSIONS[@]}"; do
    filename="node-v$version-linux-x64.tar.gz"
    if [ ! -f "$filename" ]; then
        echo "  下载 Node.js v$version..."
        wget -q https://nodejs.org/dist/v$version/$filename
        echo "  ✓ Node.js v$version 下载完成"
        ((DOWNLOADED++))
    else
        echo "  ✓ Node.js v$version 已存在，跳过"
        ((SKIPPED++))
    fi
done

# 创建版本信息文件
cd ..
cat > $DOWNLOAD_DIR/versions.txt <<EOF
Python Versions: ${PYTHON_VERSIONS[*]}
Node.js Versions: ${NODE_VERSIONS[*]}
Download Date: $(date '+%Y-%m-%d %H:%M:%S')
Files Downloaded: $DOWNLOADED
Files Skipped: $SKIPPED
EOF

# 检查是否需要重新打包
NEED_PACKAGE=false
if [ ! -f "$ARCHIVE_FILE" ]; then
    NEED_PACKAGE=true
    echo ""
    echo "打包文件不存在，需要打包"
elif [ "$DOWNLOADED" -gt 0 ]; then
    NEED_PACKAGE=true
    echo ""
    echo "有新下载的文件，需要重新打包"
else
    echo ""
    echo "所有文件已存在且未更新，跳过打包"
fi

# 打包所有文件
if [ "$NEED_PACKAGE" = true ]; then
    echo ""
    echo "打包所有文件..."
    tar -czf $ARCHIVE_FILE $DOWNLOAD_DIR
    echo "✓ 打包完成"
fi

echo ""
echo "=========================================="
echo "  下载完成！"
echo "=========================================="
echo ""
echo "统计信息:"
echo "  • 新下载: $DOWNLOADED 个文件"
echo "  • 已跳过: $SKIPPED 个文件"
echo ""
echo "下载目录: $DOWNLOAD_DIR/"
echo "打包文件: $ARCHIVE_FILE"
echo ""
echo "文件列表:"
ls -lh $DOWNLOAD_DIR/
echo ""
echo "下一步："
echo "1. 将 $ARCHIVE_FILE 传输到离线环境"
echo "2. 解压: tar -xzf $ARCHIVE_FILE"
echo "3. 运行: cd offline-packages && bash ../install.sh"
echo ""
