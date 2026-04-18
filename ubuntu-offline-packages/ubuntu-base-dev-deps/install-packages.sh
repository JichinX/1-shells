#!/bin/bash
# Ubuntu/Debian 离线包安装脚本
# 用途：在离线的 Ubuntu/Debian 系统上安装下载的软件包
# 运行环境：Ubuntu/Debian 系统，需要 dpkg

set -e

# ============================================
# 配置
# ============================================

PACKAGES_DIR="ubuntu-packages"
CONFIG_FILE="packages.conf"

# ============================================
# 检查运行环境
# ============================================

check_environment() {
    # 检查是否是 Debian/Ubuntu 系统
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/lsb-release ]]; then
        echo "错误: 此脚本需要在 Debian/Ubuntu 系统上运行"
        echo "当前系统不支持 dpkg 包管理器"
        exit 1
    fi
    
    # 检查 dpkg
    if ! command -v dpkg &> /dev/null; then
        echo "错误: 未找到 dpkg 命令"
        exit 1
    fi
    
    # 检查是否需要 sudo
    if [[ $EUID -ne 0 ]]; then
        echo "提示: 需要 sudo 权限来安装软件包"
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# ============================================
# 主脚本
# ============================================

echo "=========================================="
echo "  Ubuntu/Debian 离线包安装脚本"
echo "=========================================="
echo ""

# 检查运行环境
check_environment

# 检查离线包目录
if [ ! -d "$PACKAGES_DIR" ]; then
    echo "错误: 找不到 $PACKAGES_DIR 目录"
    echo "请先解压 ubuntu-offline-packages.tar.gz"
    exit 1
fi

cd "$PACKAGES_DIR"

# 检查是否有 .deb 文件
DEB_COUNT=$(ls -1 *.deb 2>/dev/null | wc -l | tr -d ' ')
if [ "$DEB_COUNT" -eq 0 ]; then
    echo "错误: 未找到 .deb 文件"
    exit 1
fi

echo "发现 $DEB_COUNT 个 .deb 文件"
echo ""

# 显示包列表
if [ -f "package-list.txt" ]; then
    echo "包列表信息:"
    head -n 5 package-list.txt
    echo ""
fi

# ============================================
# 安装软件包
# ============================================

echo "[*] 开始安装软件包..."
echo ""

# 方法 1: 使用 dpkg 安装所有 .deb 文件
# 这种方法可能会因为依赖顺序问题失败，但会标记所有包
echo "步骤 1/3: 安装所有 .deb 包..."
$SUDO dpkg -i *.deb 2>/dev/null || true

# 方法 2: 修复可能的依赖问题
echo ""
echo "步骤 2/3: 修复依赖关系..."
if command -v apt-get &> /dev/null; then
    # 如果有 apt-get，尝试修复依赖
    $SUDO apt-get install -f -y 2>/dev/null || true
fi

# 方法 3: 再次尝试安装未配置的包
echo ""
echo "步骤 3/3: 配置所有包..."
$SUDO dpkg --configure -a 2>/dev/null || true

# ============================================
# 验证安装
# ============================================

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""

# 从配置文件读取包列表并验证
if [ -f "$CONFIG_FILE" ]; then
    echo "验证安装的软件包:"
    echo ""
    
    # 读取配置文件中的包列表
    while IFS= read -r line; do
        # 跳过注释和空行
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # 解析包列表
        if [[ "$line" =~ ^[a-z_]+_packages[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            packages="${BASH_REMATCH[1]}"
            packages="${packages%%#*}"
            packages="${packages%"${packages##*[![:space:]]}"}"
            packages="${packages#"${packages%%[![:space:]]*}"}"
            
            for pkg in $packages; do
                if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                    version=$(dpkg -l "$pkg" 2>/dev/null | awk '{print $3}')
                    echo "  ✓ $pkg ($version)"
                else
                    echo "  ✗ $pkg (未安装)"
                fi
            done
        fi
    done < "$CONFIG_FILE"
fi

echo ""
echo "后续步骤:"
echo "1. 查看已安装的包: dpkg -l | grep <包名>"
echo "2. 查看包详情: apt show <包名>"
echo "3. 如有依赖问题: sudo apt-get install -f"
echo ""
