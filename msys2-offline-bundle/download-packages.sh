#!/bin/bash
# MSYS2 软件包离线下载脚本（辅助工具）
#
# 【用途】在已有 MSYS2 的环境中单独下载软件包
# 【适用场景】补充下载缺失的包、更新包列表
#
# 注意：这是辅助脚本，通常不需要使用
# 完整的离线方案请使用 download-resources.ps1
#
# 使用方法:
#   bash download-packages.sh
#   bash download-packages.sh /path/to/config.conf
#
# 详细工作流程请参考: WORKFLOW.md

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置文件路径（默认在同目录下）
CONFIG_FILE="${1:-$SCRIPT_DIR/config.conf}"

echo "========================================"
echo "  MSYS2 软件包离线下载脚本"
echo "========================================"
echo ""

# 确保在 MSYS2 环境
if [[ ! -f /etc/msystem ]]; then
    echo "[!] 此脚本必须在 MSYS2 UCRT64 环境中运行"
    exit 1
fi

# ============================================
# 配置文件解析函数
# ============================================
parse_config() {
    local config_file="$1"
    
    # 默认值
    PACKAGES=(
        zsh git curl wget vim nano tar zip unzip man-db
        bat fd ripgrep fzf zoxide
        libpcre libpcre2 ncurses readline gdbm
    )
    UCRT64_PACKAGES=(eza)
    
    # 如果配置文件不存在，使用默认值
    if [[ ! -f "$config_file" ]]; then
        echo "[*] 未找到配置文件: $config_file"
        echo "[*] 使用默认包列表"
        return
    fi
    
    echo "[*] 加载配置文件: $config_file"
    
    # 读取配置文件
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过注释和空行
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # 解析 key = value
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # 移除行内注释
            value="${value%%#*}"
            value="${value%"${value##*[![:space:]]}"}"  # trim right
            value="${value#"${value%%[![:space:]]*}"}"  # trim left
            
            case "$key" in
                packages)
                    # 读取包列表（支持空格或逗号分隔）
                    if [[ -n "$value" ]]; then
                        # 将逗号替换为空格，统一格式
                        value="${value//,/ }"
                        IFS=' ' read -ra PACKAGES <<< "$value"
                        echo "    -> 已加载 MSYS2 包列表: ${#PACKAGES[@]} 个"
                    fi
                    ;;
                ucrt64_packages)
                    # 读取 UCRT64 包列表
                    if [[ -n "$value" ]]; then
                        # 将逗号替换为空格，统一格式
                        value="${value//,/ }"
                        IFS=' ' read -ra UCRT64_PACKAGES <<< "$value"
                        echo "    -> 已加载 UCRT64 包列表: ${#UCRT64_PACKAGES[@]} 个"
                    fi
                    ;;
            esac
        fi
    done < "$config_file"
    
    # 确保 zsh 及其依赖包始终包含在内
    local required_deps=(libpcre libpcre2 ncurses readline gdbm)
    for dep in "${required_deps[@]}"; do
        if [[ ! " ${PACKAGES[*]} " =~ " ${dep} " ]]; then
            PACKAGES+=("$dep")
        fi
    done
    
    # 确保 zsh 在列表中
    if [[ ! " ${PACKAGES[*]} " =~ " zsh " ]]; then
        PACKAGES=(zsh "${PACKAGES[@]}")
    fi
}

# 加载配置
parse_config "$CONFIG_FILE"

# 更新软件源
echo ""
echo "[1/3] 更新软件源..."
pacman -Sy

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
