#!/bin/bash
# Ubuntu/Debian 离线包下载脚本（带依赖解析）
# 用途：在 macOS/Linux 上下载 Ubuntu 软件包及其所有依赖
# 运行环境：macOS 或 Linux，需要 wget 或 curl

set -e

# 清理函数
cleanup() {
    cleanup_processed_packages
}

# 注册清理函数
trap cleanup EXIT

# ============================================
# macOS 特殊处理：防止生成 ._ 文件
# ============================================
export COPYFILE_DISABLE=1

# ============================================
# 配置文件解析函数
# ============================================

# 默认配置
Config_DownloadDir="ubuntu-packages"
Config_ArchiveFile="ubuntu-offline-packages.tar.gz"
Config_UbuntuVersion="noble"
Config_Architecture="amd64"
Config_Mirror="http://mirrors.aliyun.com/ubuntu"
Config_Packages=()
Config_AutoPackage=true
Config_CleanAfterPackage=false
Config_ResolveDeps=true
Config_ExcludeEssential=true

# 解析配置文件
parse_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "[*] 未找到配置文件: $config_file"
        echo "[*] 使用默认配置"
        return
    fi
    
    echo "[*] 加载配置文件: $config_file"
    
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
            value="${value%"${value##*[![:space:]]}"}"
            value="${value#"${value%%[![:space:]]*}"}"
            
            case "$key" in
                download_dir)
                    Config_DownloadDir="$value"
                    ;;
                archive_file)
                    Config_ArchiveFile="$value"
                    ;;
                ubuntu_version)
                    Config_UbuntuVersion="$value"
                    ;;
                architecture)
                    Config_Architecture="$value"
                    ;;
                mirror)
                    Config_Mirror="$value"
                    ;;
                packages)
                    IFS=' ' read -ra Config_Packages <<< "$value"
                    echo "    -> 软件包: ${Config_Packages[*]}"
                    ;;
                auto_package)
                    Config_AutoPackage="$value"
                    ;;
                clean_after_package)
                    Config_CleanAfterPackage="$value"
                    ;;
                resolve_deps)
                    Config_ResolveDeps="$value"
                    ;;
                exclude_essential)
                    Config_ExcludeEssential="$value"
                    ;;
            esac
        fi
    done < "$config_file"
}

# ============================================
# 下载工具
# ============================================

# 下载文件（支持 wget 和 curl）
download_file() {
    local url="$1"
    local output="$2"
    
    if command -v wget &> /dev/null; then
        wget -q -O "$output" "$url"
    elif command -v curl &> /dev/null; then
        curl -sL -o "$output" "$url"
    else
        echo "错误: 需要 wget 或 curl"
        exit 1
    fi
}

# ============================================
# Ubuntu 版本号处理
# ============================================

# 版本号转代号
version_to_codename() {
    local version="$1"
    
    # 如果已经是代号（全小写字母），直接返回
    if [[ "$version" =~ ^[a-z]+$ ]]; then
        echo "$version"
        return 0
    fi
    
    # 版本号转代号
    case "$version" in
        24.04) echo "noble" ;;
        23.10) echo "mantic" ;;
        23.04) echo "lunar" ;;
        22.10) echo "kinetic" ;;
        22.04) echo "jammy" ;;
        21.10) echo "impish" ;;
        21.04) echo "hirsute" ;;
        20.10) echo "groovy" ;;
        20.04) echo "focal" ;;
        19.10) echo "eoan" ;;
        19.04) echo "disco" ;;
        18.10) echo "cosmic" ;;
        18.04) echo "bionic" ;;
        17.10) echo "artful" ;;
        17.04) echo "zesty" ;;
        16.10) echo "yakkety" ;;
        16.04) echo "xenial" ;;
        *)
            echo "错误: 未知的 Ubuntu 版本: $version" >&2
            echo "支持的版本: 24.04, 22.04, 20.04, 18.04, 16.04 等" >&2
            return 1
            ;;
    esac
}

# ============================================
# 包索引管理
# ============================================

# 下载并解析包索引
download_package_index() {
    local component="$1"  # main, restricted, universe, multiverse
    local index_file="$Config_DownloadDir/.Packages-${component}"
    local index_url="$Config_Mirror/dists/$Config_UbuntuVersion/$component/binary-$Config_Architecture/Packages.gz"
    
    echo "  下载 $component 包索引..."
    
    # 下载索引文件
    if ! download_file "$index_url" "${index_file}.gz" 2>/dev/null; then
        echo "    警告: 无法下载 $component 索引，跳过"
        return 1
    fi
    
    # 解压
    if command -v gunzip &> /dev/null; then
        gunzip -f "${index_file}.gz" 2>/dev/null || true
    elif command -v gzip &> /dev/null; then
        gzip -df "${index_file}.gz" 2>/dev/null || true
    else
        echo "    错误: 需要 gunzip 或 gzip"
        return 1
    fi
    
    echo "    ✓ $component 索引下载完成"
    return 0
}

# 从索引中查找包的完整信息
get_package_info() {
    local package="$1"
    local index_file
    
    for component in main restricted universe multiverse; do
        index_file="$Config_DownloadDir/.Packages-${component}"
        
        if [[ -f "$index_file" ]]; then
            # 使用 awk 提取包信息块
            awk -v pkg="$package" '
                /^Package: / { 
                    if ($2 == pkg) { 
                        found=1; 
                        block=""; 
                    } 
                }
                found { 
                    if (/^$/) { 
                        print block; 
                        exit; 
                    }
                    block = block $0 "\n";
                }
            ' "$index_file"
        fi
    done
}

# 获取包的文件名
get_package_filename() {
    local package="$1"
    local info=$(get_package_info "$package")
    echo "$info" | grep "^Filename:" | awk '{print $2}'
}

# 获取包的依赖列表
get_package_depends() {
    local package="$1"
    local info=$(get_package_info "$package")
    
    # 提取 Depends 和 Pre-Depends
    local depends=$(echo "$info" | grep -E "^(Pre-)?Depends:" | sed 's/^(Pre-)?Depends: //')
    
    # 解析依赖
    # 格式: pkg1, pkg2 (>= 1.0), pkg3 | pkg4
    echo "$depends" | tr ',' '\n' | while read -r dep; do
        # 移除版本约束 (括号内的内容)
        dep=$(echo "$dep" | sed 's/([^)]*)//g')
        
        # 处理或关系 (pkg1 | pkg2)，只取第一个
        dep=$(echo "$dep" | sed 's/|.*//g')
        
        # 移除架构限定 (如 :any, :amd64)
        dep=$(echo "$dep" | sed 's/:any//g' | sed 's/:amd64//g' | sed 's/:arm64//g')
        
        # 去除空格
        dep=$(echo "$dep" | tr -d ' ')
        
        # 过滤空行
        [[ -n "$dep" ]] && echo "$dep"
    done | sort -u
}

# ============================================
# 依赖解析
# ============================================

# 基础系统包（通常已安装，不需要下载）
ESSENTIAL_PACKAGES=(
    libc6 libc-bin libgcc-s1 libstdc++6
    base-files base-passwd bash coreutils dash
    debianutils diffutils dpkg e2fsprogs
    findutils grep gzip hostname init
    login mount ncurses-base ncurses-bin
    perl-base sed sysvinit-utils tar util-linux
    zlib1g apt debconf libapt-pkg6.0
    libgnutls30 libnettle8 libhogweed6
    libpcre3 libselinux1 libsystemd0
    libudev1 libuuid1 libzstd1
    adduser apt-utils bsdutils
    ca-certificates curl wget
)

# 检查是否是基础包
is_essential_package() {
    local package="$1"
    
    for essential in "${ESSENTIAL_PACKAGES[@]}"; do
        [[ "$package" == "$essential" ]] && return 0
    done
    
    return 1
}

# 已处理的包文件（兼容旧版 bash）
PROCESSED_PACKAGES_FILE=""

# 初始化已处理包列表
init_processed_packages() {
    PROCESSED_PACKAGES_FILE=$(mktemp)
}

# 清理临时文件
cleanup_processed_packages() {
    [[ -f "$PROCESSED_PACKAGES_FILE" ]] && rm -f "$PROCESSED_PACKAGES_FILE"
}

# 检查包是否已处理
is_package_processed() {
    local package="$1"
    grep -q "^${package}$" "$PROCESSED_PACKAGES_FILE" 2>/dev/null
}

# 标记包为已处理
mark_package_processed() {
    local package="$1"
    echo "$package" >> "$PROCESSED_PACKAGES_FILE"
}

# 递归获取所有依赖
resolve_dependencies() {
    local package="$1"
    local depth="${2:-0}"
    local indent=$(printf '%*s' $((depth * 2)) '')
    
    # 检查是否已处理
    if is_package_processed "$package"; then
        return 0
    fi
    
    # 标记为已处理
    mark_package_processed "$package"
    
    # 获取依赖
    local deps=$(get_package_depends "$package")
    
    if [[ -n "$deps" ]]; then
        echo "${indent}├─ $package 的依赖:" >&2
        
        for dep in $deps; do
            # 跳过基础包
            if $Config_ExcludeEssential && is_essential_package "$dep"; then
                echo "${indent}│  └─ $dep (基础包，跳过)" >&2
                continue
            fi
            
            # 检查包是否存在
            local filename=$(get_package_filename "$dep")
            if [[ -z "$filename" ]]; then
                echo "${indent}│  └─ $dep (未找到，可能是虚拟包)" >&2
                continue
            fi
            
            echo "${indent}│  └─ $dep" >&2
            
            # 递归处理依赖
            resolve_dependencies "$dep" $((depth + 1))
        done
    fi
}

# 获取所有需要下载的包（包括依赖）
get_all_packages_with_deps() {
    local packages=("$@")
    
    echo "[*] 解析依赖关系..."
    echo ""
    
    # 初始化
    init_processed_packages
    
    # 处理每个请求的包
    for package in "${packages[@]}"; do
        echo "解析: $package"
        resolve_dependencies "$package"
        echo ""
    done
    
    # 返回所有包
    cat "$PROCESSED_PACKAGES_FILE" | sort -u
}

# ============================================
# 下载包
# ============================================

download_package() {
    local package="$1"
    local found=false
    
    echo "  下载 $package..."
    
    # 获取文件名
    local filename=$(get_package_filename "$package")
    
    if [[ -z "$filename" ]]; then
        echo "    ✗ 未找到包 $package"
        return 1
    fi
    
    # 提取文件名
    local deb_name=$(basename "$filename")
    
    # 检查是否已下载
    if [[ -f "$Config_DownloadDir/$deb_name" ]]; then
        echo "    ✓ 已存在，跳过"
        return 0
    fi
    
    # 下载
    local deb_url="$Config_Mirror/$filename"
    echo "    URL: $deb_url"
    
    if download_file "$deb_url" "$Config_DownloadDir/$deb_name"; then
        echo "    ✓ 下载完成"
        return 0
    else
        echo "    ✗ 下载失败"
        return 1
    fi
}

# ============================================
# 主脚本
# ============================================

# 显示帮助信息
show_help() {
    cat <<EOF
用法: $0 [选项]

选项:
  -c, --config FILE      配置文件路径（默认: packages.conf）
  -v, --version VERSION  Ubuntu 版本号或代号（如: 22.04 或 jammy）
  -a, --arch ARCH        架构（如: amd64, arm64）
  -m, --mirror URL       镜像源地址
  --no-deps              不解析依赖关系
  --include-essential    包含基础系统包
  -h, --help             显示帮助信息

示例:
  $0                              # 使用默认配置
  $0 -v 22.04                     # 指定 Ubuntu 22.04
  $0 -v jammy -a arm64            # Ubuntu 22.04 ARM64
  $0 -c custom.conf               # 使用自定义配置文件
  $0 --no-deps                    # 不解析依赖

支持的 Ubuntu 版本:
  24.04 (noble), 22.04 (jammy), 20.04 (focal), 18.04 (bionic)
EOF
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置文件路径
CONFIG_FILE="$SCRIPT_DIR/packages.conf"

# 命令行参数
CMD_UBUNTU_VERSION=""
CMD_ARCHITECTURE=""
CMD_MIRROR=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -v|--version)
            CMD_UBUNTU_VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            CMD_ARCHITECTURE="$2"
            shift 2
            ;;
        -m|--mirror)
            CMD_MIRROR="$2"
            shift 2
            ;;
        --no-deps)
            Config_ResolveDeps=false
            shift
            ;;
        --include-essential)
            Config_ExcludeEssential=false
            shift
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

echo "=========================================="
echo "  Ubuntu/Debian 离线包下载脚本"
echo "  （带依赖解析）"
echo "=========================================="

# 加载配置
parse_config "$CONFIG_FILE"

# 命令行参数覆盖配置文件
[[ -n "$CMD_UBUNTU_VERSION" ]] && Config_UbuntuVersion="$CMD_UBUNTU_VERSION"
[[ -n "$CMD_ARCHITECTURE" ]] && Config_Architecture="$CMD_ARCHITECTURE"
[[ -n "$CMD_MIRROR" ]] && Config_Mirror="$CMD_MIRROR"

# 版本号转代号
echo "[*] 处理 Ubuntu 版本: $Config_UbuntuVersion"
if CODENAME=$(version_to_codename "$Config_UbuntuVersion"); then
    Config_UbuntuVersion="$CODENAME"
    echo "    代号: $Config_UbuntuVersion"
else
    exit 1
fi

# 创建下载目录
mkdir -p "$Config_DownloadDir"

echo ""
echo "配置信息:"
echo "  Ubuntu 版本: $Config_UbuntuVersion"
echo "  架构: $Config_Architecture"
echo "  镜像源: $Config_Mirror"
echo "  软件包数量: ${#Config_Packages[@]}"
echo "  解析依赖: $Config_ResolveDeps"
echo "  排除基础包: $Config_ExcludeEssential"
echo ""

# 检查下载工具
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    echo "错误: 需要 wget 或 curl"
    echo ""
    echo "安装方法："
    echo "  macOS: brew install wget 或 brew install curl"
    echo "  Ubuntu: sudo apt install wget 或 sudo apt install curl"
    exit 1
fi

# 下载包索引
echo "[1/3] 下载包索引..."
echo ""

COMPONENTS=("main" "restricted" "universe" "multiverse")
DOWNLOADED_INDEX=0

for component in "${COMPONENTS[@]}"; do
    if download_package_index "$component"; then
        ((DOWNLOADED_INDEX++))
    fi
done

if [[ $DOWNLOADED_INDEX -eq 0 ]]; then
    echo ""
    echo "错误: 无法下载任何包索引"
    echo "请检查网络连接和镜像源配置"
    exit 1
fi

echo ""

# 解析依赖
if $Config_ResolveDeps; then
    echo "[2/3] 解析依赖关系..."
    echo ""
    
    ALL_PACKAGES=$(get_all_packages_with_deps "${Config_Packages[@]}")
    
    # 转换为数组
    read -ra ALL_PACKAGES_ARRAY <<< "$ALL_PACKAGES"
    
    echo ""
    echo "依赖解析完成:"
    echo "  请求包: ${#Config_Packages[@]} 个"
    echo "  总计包: ${#ALL_PACKAGES_ARRAY[@]} 个（含依赖）"
    echo ""
else
    ALL_PACKAGES_ARRAY=("${Config_Packages[@]}")
fi

# 下载包
echo "[3/3] 下载软件包..."
echo ""

# 统计变量
DOWNLOADED=0
FAILED=0
SKIPPED=0

# 下载所有包
for package in "${ALL_PACKAGES_ARRAY[@]}"; do
    if download_package "$package"; then
        ((DOWNLOADED++))
    else
        ((FAILED++))
    fi
done

# 清理索引文件
rm -f "$Config_DownloadDir"/.Packages-* 2>/dev/null || true

# 创建包列表文件
cat > "$Config_DownloadDir/package-list.txt" <<EOF
配置文件: $CONFIG_FILE
Ubuntu 版本: $Config_UbuntuVersion
架构: $Config_Architecture
镜像源: $Config_Mirror
下载时间: $(date '+%Y-%m-%d %H:%M:%S')
成功下载: $DOWNLOADED
下载失败: $FAILED

请求的软件包:
$(echo "${Config_Packages[@]}" | tr ' ' '\n' | sort)

所有软件包（含依赖）:
$(echo "${ALL_PACKAGES_ARRAY[@]}" | tr ' ' '\n' | sort)
EOF

# 创建依赖关系图
cat > "$Config_DownloadDir/dependency-graph.txt" <<EOF
# 依赖关系图
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

请求的包:
EOF

for package in "${Config_Packages[@]}"; do
    echo "  - $package" >> "$Config_DownloadDir/dependency-graph.txt"
done

# 检查是否需要打包
NEED_PACKAGE=false
if $Config_AutoPackage; then
    if [ ! -f "$Config_ArchiveFile" ]; then
        NEED_PACKAGE=true
    elif [ "$DOWNLOADED" -gt 0 ]; then
        NEED_PACKAGE=true
    fi
fi

# 打包
if [ "$NEED_PACKAGE" = true ]; then
    echo ""
    echo "[*] 打包文件..."
    
    # 复制安装脚本和配置文件
    cp "$SCRIPT_DIR/install-packages.sh" "$Config_DownloadDir/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$Config_DownloadDir/" 2>/dev/null || true
    cp "$CONFIG_FILE" "$Config_DownloadDir/" 2>/dev/null || true
    
    # 清理 macOS 隐藏文件
    find "$Config_DownloadDir" -name '.DS_Store' -type f -delete 2>/dev/null || true
    find "$Config_DownloadDir" -name '._*' -type f -delete 2>/dev/null || true
    
    # 使用 dot_clean 合并资源分支
    if command -v dot_clean &> /dev/null; then
        dot_clean -m "$Config_DownloadDir" 2>/dev/null || true
    fi
    
    # 打包
    tar -czf "$Config_ArchiveFile" \
        --no-xattrs \
        --exclude='.DS_Store' \
        --exclude='._*' \
        "$Config_DownloadDir"
    
    echo "✓ 打包完成: $Config_ArchiveFile"
    
    # 清理源文件
    if $Config_CleanAfterPackage; then
        echo "[*] 清理源文件..."
        rm -rf "$Config_DownloadDir"
    fi
fi

echo ""
echo "=========================================="
echo "  下载完成！"
echo "=========================================="
echo ""
echo "统计信息:"
echo "  • 成功下载: $DOWNLOADED 个包"
echo "  • 下载失败: $FAILED 个包"
echo ""
echo "下载目录: $Config_DownloadDir/"
if $Config_AutoPackage; then
    echo "打包文件: $Config_ArchiveFile"
fi
echo ""
echo "下一步："
if $Config_AutoPackage; then
    echo "1. 将 $Config_ArchiveFile 传输到离线环境"
    echo "2. 解压: tar -xzf $Config_ArchiveFile"
else
    echo "1. 将 $Config_DownloadDir 目录传输到离线环境"
fi
echo "3. 安装: cd $Config_DownloadDir && sudo dpkg -i *.deb"
echo ""
