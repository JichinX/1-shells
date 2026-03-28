#!/bin/bash
# 在有外网的 MSYS2 UCRT64 环境中运行
# 下载所有需要的软件包到缓存目录（不安装）
# 使用方法: bash download-packages.sh

set -e

echo "========================================"
echo "  MSYS2 软件包离线下载脚本"
echo "========================================"
echo ""

# 确保在 MSYS2 环境
if [[ ! -f /etc/msystem ]]; then
    echo "[!] 此脚本必须在 MSYS2 UCRT64 环境中运行"
    exit 1
fi

# 更新软件源
echo "[1/3] 更新软件源..."
pacman -Sy

# 定义需要的包列表
PACKAGES=(
    # Shell 和基础工具
    zsh
    git
    curl
    wget
    vim
    nano
    tar
    unzip
    man-db
    man-pages-posix
    
    # 现代 CLI 工具
    bat
    fd
    ripgrep
    fzf
    zoxide
    
    # zsh 可能的依赖
    libpcre
    libpcre2
    ncurses
    readline
    gdbm
)

# UCRT64 特定的包
UCRT64_PACKAGES=(
    eza
)

echo "[2/3] 下载软件包（不安装）..."
echo ""

# 下载 MSYS2 核心包
echo "    -> 下载 MSYS2 核心包..."
for pkg in "${PACKAGES[@]}"; do
    echo -n "       $pkg ... "
    if pacman -Sw --noconfirm --needed "$pkg" 2>/dev/null; then
        echo "✓"
    else
        echo "✗ (可能已存在或不可用)"
    fi
done

echo ""
echo "    -> 下载 UCRT64 特定包..."
for pkg in "${UCRT64_PACKAGES[@]}"; do
    fullpkg="mingw-w64-ucrt-x86_64-$pkg"
    echo -n "       $fullpkg ... "
    if pacman -Sw --noconfirm --needed "$fullpkg" 2>/dev/null; then
        echo "✓"
    else
        echo "✗ (可能已存在或不可用)"
    fi
done

echo ""
echo "[3/3] 复制缓存到导出目录..."

# 创建导出目录
EXPORT_DIR="$HOME/offline-packages"
mkdir -p "$EXPORT_DIR"

# 复制所有缓存的包
CACHE_DIR="/var/cache/pacman/pkg"
PACKAGE_COUNT=$(find "$CACHE_DIR" -name "*.pkg.tar.zst" -o -name "*.pkg.tar.xz" | wc -l)

echo "    -> 找到 $PACKAGE_COUNT 个软件包"

# 清空旧的导出目录
rm -rf "$EXPORT_DIR"/*

# 复制所有包
cp "$CACHE_DIR"/*.pkg.tar.* "$EXPORT_DIR/" 2>/dev/null || true

# 统计
COPIED_COUNT=$(find "$EXPORT_DIR" -name "*.pkg.tar.*" | wc -l)
echo "    -> 已复制 $COPIED_COUNT 个包到: $EXPORT_DIR"

# 计算大小
TOTAL_SIZE=$(du -sh "$EXPORT_DIR" | cut -f1)
echo "    -> 总大小: $TOTAL_SIZE"

echo ""
echo "========================================"
echo "  下载完成！"
echo "========================================"
echo ""
echo "包已保存到: $EXPORT_DIR"
echo ""
echo "下一步："
echo "  1. 将此目录打包: tar -czf offline-packages.tar.gz offline-packages/"
echo "  2. 或直接复制整个目录到离线环境"
echo "  3. 在离线 MSYS2 中运行: sudo pacman -U /path/to/offline-packages/*.pkg.tar.*"
echo ""
