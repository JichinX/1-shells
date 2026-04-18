#!/bin/bash
# apt-offline 离线包下载脚本
# 用途：在 Ubuntu 系统上下载离线软件包及所有依赖
# 运行环境：Ubuntu/Debian，需要 apt-offline

set -e

# ============================================
# 配置
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="ubuntu-base-dev-deps-offline"

# ============================================
# 软件包列表
# ============================================

# 需要离线安装的开发包
DEV_PACKAGES=(
    # 第一层：核心编译工具
    "build-essential"
    
    # 第二层：基础开发工具
    "git" "vim" "curl" "wget" "ca-certificates"
    "unzip" "zip" "p7zip-full" "xz-utils"
    
    # 第三层：系统工具
    "htop" "tree" "lsof" "strace" "ltrace"
    
    # 第四层：Python 编译依赖
    "libssl-dev" "zlib1g-dev" "libffi-dev" "libsqlite3-dev"
    "libreadline-dev" "libbz2-dev" "libncurses-dev" "liblzma-dev"
    
    # 第五层：其他开发工具
    "pkg-config" "autoconf" "automake" "libtool"
)

# apt-offline 及其依赖（用于离线安装）
APT_OFFLINE_PACKAGES="apt-offline"

# ============================================
# 帮助信息
# ============================================

show_help() {
    cat <<EOF
用法: $0 [选项]

选项:
  -o, --output DIR       输出目录 (默认: ubuntu-base-dev-deps-offline)
  -h, --help             显示帮助信息

示例:
  $0                              # 下载到默认目录
  $0 -o /tmp/offline-pkgs        # 下载到指定目录

工作原理:
  1. 在有网络的 Ubuntu 上运行此脚本
  2. 脚本会下载 apt-offline .deb 包 + 所有开发包 bundle
  3. 生成文件:
     - bootstrap-debs/: apt-offline 及其依赖的 .deb 文件
     - dev-bundle.zip: 所有开发包（用 apt-offline 安装）
  4. 在离线机器上运行 install.sh 即可

注意:
  此脚本需要在 Ubuntu/Debian 系统上运行
  需要先安装 apt-offline: sudo apt install apt-offline
EOF
}

# ============================================
# 解析命令行参数
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "错误: 未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================
# 检查系统
# ============================================

echo "=========================================="
echo "  apt-offline 离线包下载脚本"
echo "=========================================="
echo ""

if [[ ! -f /etc/debian_version ]]; then
    echo "错误: 此脚本需要在 Ubuntu/Debian 系统上运行"
    echo "当前系统: $(uname -s)"
    exit 1
fi

if [[ -f /etc/lsb-release ]]; then
    source /etc/lsb-release
    echo "系统: $DISTRIB_ID $DISTRIB_RELEASE ($DISTRIB_CODENAME)"
else
    DISTRIB_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
fi

ARCH=$(dpkg --print-architecture)
echo "架构: $ARCH"
echo ""

# 检查 apt-offline
if ! command -v apt-offline &> /dev/null; then
    echo "错误: 需要 apt-offline"
    echo ""
    echo "安装方法:"
    echo "  sudo apt update && sudo apt install -y apt-offline"
    exit 1
fi

echo "✓ apt-offline 已安装"
echo ""

# 更新 apt 缓存（确保包信息最新）
echo "[*] 更新 apt 缓存..."
apt-get update -qq
echo "✓ apt 缓存已更新"
echo ""

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 确保 apt-offline 缓存目录存在
APT_OFFLINE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/apt-offline"
mkdir -p "$APT_OFFLINE_CACHE"
echo "缓存目录: $APT_OFFLINE_CACHE"

# ============================================
# 步骤 1: 下载 apt-offline bootstrap 包（直接下载 .deb）
# ============================================

echo "[1/4] 下载 apt-offline bootstrap 包..."

BOOTSTRAP_DEBS="$OUTPUT_DIR/bootstrap-debs"
mkdir -p "$BOOTSTRAP_DEBS"

# 获取 apt-offline 及其所有依赖
cd "$BOOTSTRAP_DEBS"
APT_OFFLINE_DEPS=$(apt-cache depends --recurse --no-replaces --no-suggests --no-conflicts --no-breaks --no-enhances "$APT_OFFLINE_PACKAGES" 2>/dev/null | grep "Depends:" | awk '{print $2}' | sort -u)

# 去重并添加主包
ALL_BOOTSTRAP_PKGS=("$APT_OFFLINE_PACKAGES")
for pkg in $APT_OFFLINE_DEPS; do
    # 过滤掉虚拟包
    if apt-cache show "$pkg" &>/dev/null; then
        ALL_BOOTSTRAP_PKGS+=("$pkg")
    fi
done

# 去重
UNIQUE_PKGS=$(printf '%s\n' "${ALL_BOOTSTRAP_PKGS[@]}" | sort -u)

BOOTSTRAP_COUNT=0
for pkg in $UNIQUE_PKGS; do
    if apt-get download "$pkg" 2>/dev/null; then
        ((BOOTSTRAP_COUNT++))
    fi
done

cd "$OUTPUT_DIR"

echo "✓ Bootstrap 包: $BOOTSTRAP_COUNT 个 deb"
echo ""

# ============================================
# 步骤 2: 生成开发包签名
# ============================================

echo "[2/3] 生成开发包签名..."

DEV_SIG="$OUTPUT_DIR/dev.sig"
apt-offline set "$DEV_SIG" \
    --update \
    --packages "${DEV_PACKAGES[@]}"

echo "✓ 开发包签名: $DEV_SIG"
echo ""

# ============================================
# 步骤 3: 下载开发包
# ============================================

echo "[3/3] 下载开发包..."
DEV_BUNDLE="$OUTPUT_DIR/dev-bundle.zip"

apt-offline get "$DEV_SIG" \
    --bundle "$DEV_BUNDLE" \
    --threads 4

DEV_SIZE=$(du -h "$DEV_BUNDLE" | cut -f1)
echo "✓ 开发包: $DEV_BUNDLE ($DEV_SIZE)"
echo ""

# ============================================
# 创建安装脚本
# ============================================

echo "[*] 创建安装脚本..."

cat > "$OUTPUT_DIR/install.sh" <<'INSTALL_SCRIPT'
#!/bin/bash
# Ubuntu 基础开发环境离线安装脚本
# 
# 安装流程:
#   1. 用 dpkg 安装 apt-offline（少量包）
#   2. 用 apt-offline 安装所有开发包（自动处理依赖）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "=========================================="
echo "  Ubuntu 基础开发环境离线安装"
echo "=========================================="
echo ""

# 检查系统
if [[ ! -f /etc/debian_version ]]; then
    log_error "此脚本需要在 Ubuntu/Debian 系统上运行"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# 阶段 1: 安装 apt-offline
# ============================================

echo ""
echo "=========================================="
echo "  阶段 1/2: 安装 apt-offline"
echo "=========================================="
echo ""

BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap-debs"

if [[ ! -d "$BOOTSTRAP_DIR" ]] || [[ $(find "$BOOTSTRAP_DIR" -name "*.deb" 2>/dev/null | wc -l) -eq 0 ]]; then
    log_error "找不到 apt-offline 启动包 (bootstrap-debs/)"
    exit 1
fi

# 检查是否已安装 apt-offline
if command -v apt-offline &> /dev/null; then
    log_info "apt-offline 已安装"
else
    log_info "正在安装 apt-offline..."
    
    # 递归查找所有 deb 文件并安装（apt-offline 的 deb 可能在子目录中）
    find "$BOOTSTRAP_DIR" -name "*.deb" | while read deb; do
        dpkg -i "$deb" 2>/dev/null || true
    done
    
    # 修复依赖
    apt-get install -f -y 2>/dev/null || true
    
    if command -v apt-offline &> /dev/null; then
        log_info "apt-offline 安装成功"
    else
        log_error "apt-offline 安装失败"
        exit 1
    fi
fi

# ============================================
# 阶段 2: 使用 apt-offline 安装开发包
# ============================================

echo ""
echo "=========================================="
echo "  阶段 2/2: 安装开发包"
echo "=========================================="
echo ""

DEV_BUNDLE=$(ls "$SCRIPT_DIR"/dev-bundle*.zip 2>/dev/null | head -1)

if [[ -z "$DEV_BUNDLE" ]]; then
    DEV_BUNDLE=$(ls "$SCRIPT_DIR"/*.zip 2>/dev/null | grep -v bootstrap | head -1)
fi

if [[ -z "$DEV_BUNDLE" ]]; then
    log_error "找不到开发包文件 (dev-bundle.zip)"
    exit 1
fi

log_info "使用 apt-offline 安装开发包..."
log_info "包文件: $(basename $DEV_BUNDLE)"
echo ""

sudo apt-offline install --bundle "$DEV_BUNDLE"

# ============================================
# 完成
# ============================================

echo ""
echo "=========================================="
echo "  安装完成！"
echo "=========================================="
echo ""

# 验证安装
echo "验证安装:"
echo ""

PASS=0
FAIL=0

check_cmd() {
    local cmd=$1
    local desc=${2:-$cmd}
    if command -v $cmd &> /dev/null; then
        log_info "$desc: $($cmd --version 2>&1 | head -1)"
        ((PASS++))
    else
        log_error "$desc: 未安装"
        ((FAIL++))
    fi
}

check_cmd gcc "GCC 编译器"
check_cmd g++ "G++ 编译器"
check_cmd make "Make 构建工具"
check_cmd git "Git 版本控制"
check_cmd python3 "Python 3"

echo ""
echo "Python 模块检查:"
for mod in ssl zlib ctypes sqlite3; do
    if python3 -c "import $mod" 2>/dev/null; then
        log_info "$mod 模块"
    else
        log_warn "$mod 模块不可用"
    fi
done

echo ""
echo "统计: $PASS 通过, $FAIL 失败"
echo ""
echo "如需修复依赖问题，请运行:"
echo "  sudo apt-get install -f -y"
INSTALL_SCRIPT

chmod +x "$OUTPUT_DIR/install.sh"

# ============================================
# 创建 README
# ============================================

cat > "$OUTPUT_DIR/README.md" <<EOF
# Ubuntu 基础开发环境离线包

## 信息

- 系统版本: ${DISTRIB_RELEASE:-unknown} (${DISTRIB_CODENAME})
- 架构: $ARCH
- 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

## 包含内容

### 开发包 ($${#DEV_PACKAGES[@]} 个)

$(printf '- %s\n' "${DEV_PACKAGES[@]}")

## 文件说明

| 文件 | 说明 |
|------|------|
| \`bootstrap-debs/\` | apt-offline 及其依赖的 .deb 文件 |
| \`dev-bundle.zip\` | 所有开发包（包含完整依赖） |
| \`install.sh\` | 一键安装脚本 |

## 安装方法

### 一键安装（推荐）

\`\`\`bash
sudo ./install.sh
\`\`\`

### 手动分步安装

**步骤 1: 安装 apt-offline**

\`\`\`bash
cd bootstrap-debs
sudo dpkg -i *.deb
sudo apt-get install -f -y
\`\`\`

**步骤 2: 安装开发包**

\`\`\`bash
cd ..
sudo apt-offline install --bundle dev-bundle.zip
\`\`\`

## 工作原理

1. **bootstrap-debs/**: 包含 apt-offline 及其依赖（约 10-20 个包）
   - 用 \`apt-get download\` 直接下载，用 \`dpkg -i\` 安装
   
2. **dev-bundle.zip**: 包含所有开发包及其依赖（可能上百个包）
   - 用 \`apt-offline install\` 安装，自动处理依赖关系

这种两阶段设计确保离线机器无需预装任何特殊工具。

## 验证安装

\`\`\`bash
gcc --version
g++ --version
make --version
git --version
python3 -c "import ssl; print('SSL OK')"
\`\`\`
EOF

# ============================================
# 完成
# ============================================

echo "=========================================="
echo "  下载完成！"
echo "=========================================="
echo ""
echo "输出目录: $OUTPUT_DIR/"
echo ""
echo "文件清单:"
ls -lh "$OUTPUT_DIR"/{*.zip,*.sig,install.sh,README.md} 2>/dev/null
echo ""
echo "子目录:"
ls -ld "$OUTPUT_DIR"/bootstrap-debs 2>/dev/null
echo ""
echo "下一步:"
echo "1. 将 $OUTPUT_DIR 目录传输到离线 Ubuntu 系统"
echo "2. 运行: cd $OUTPUT_DIR && sudo ./install.sh"
echo ""
