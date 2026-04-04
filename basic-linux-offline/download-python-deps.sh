#!/bin/bash
# Python 编译依赖下载脚本
# 用途：在 macOS/Linux 上下载 Python 编译所需的 Ubuntu 依赖包
# 运行环境：macOS 或 Linux，需要 wget 或 curl

set -e

# ============================================
# macOS 特殊处理：防止生成 ._ 文件
# ============================================
export COPYFILE_DISABLE=1

# ============================================
# 配置文件解析函数
# ============================================

# 默认配置
Config_UbuntuVersion="jammy"
Config_Architecture="amd64"
Config_Mirror="http://mirrors.aliyun.com/ubuntu"
Config_BuildTools=""
Config_EssentialDeps=""
Config_RecommendedDeps=""
Config_OptionalDeps=""
Config_DownloadDir="python-build-deps"
Config_ArchiveFile="python-build-deps.tar.gz"

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
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            value="${value%%#*}"
            value="${value%"${value##*[![:space:]]}"}"
            value="${value#"${value%%[![:space:]]*}"}"
            
            case "$key" in
                ubuntu_version)
                    Config_UbuntuVersion="$value"
                    ;;
                architecture)
                    Config_Architecture="$value"
                    ;;
                mirror)
                    Config_Mirror="$value"
                    ;;
                build_tools)
                    Config_BuildTools="$value"
                    ;;
                essential_deps)
                    Config_EssentialDeps="$value"
                    ;;
                recommended_deps)
                    Config_RecommendedDeps="$value"
                    ;;
                optional_deps)
                    Config_OptionalDeps="$value"
                    ;;
                download_dir)
                    Config_DownloadDir="$value"
                    ;;
                archive_file)
                    Config_ArchiveFile="$value"
                    ;;
            esac
        fi
    done < "$config_file"
}

# ============================================
# Ubuntu 版本号处理
# ============================================

version_to_codename() {
    local version="$1"
    
    if [[ "$version" =~ ^[a-z]+$ ]]; then
        echo "$version"
        return 0
    fi
    
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
            return 1
            ;;
    esac
}

# ============================================
# 下载工具
# ============================================

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
# 包索引管理
# ============================================

download_package_index() {
    local component="$1"
    local index_file="$Config_DownloadDir/.Packages-${component}"
    local index_url="$Config_Mirror/dists/$Config_UbuntuVersion/$component/binary-$Config_Architecture/Packages.gz"
    
    echo "  下载 $component 包索引..."
    
    if ! download_file "$index_url" "${index_file}.gz" 2>/dev/null; then
        echo "    警告: 无法下载 $component 索引，跳过"
        return 1
    fi
    
    if command -v gunzip &> /dev/null; then
        gunzip -f "${index_file}.gz" 2>/dev/null || true
    elif command -v gzip &> /dev/null; then
        gzip -df "${index_file}.gz" 2>/dev/null || true
    fi
    
    echo "    ✓ $component 索引下载完成"
    return 0
}

find_package_in_index() {
    local package="$1"
    local component="$2"
    local index_file="$Config_DownloadDir/.Packages-${component}"
    
    if [[ ! -f "$index_file" ]]; then
        return 1
    fi
    
    grep -A 20 "^Package: ${package}$" "$index_file" 2>/dev/null | grep "^Filename:" | head -1 | awk '{print $2}'
}

# ============================================
# 下载包
# ============================================

download_package() {
    local package="$1"
    local found=false
    
    echo "  查找 $package..."
    
    for component in main restricted universe multiverse; do
        local filename=$(find_package_in_index "$package" "$component")
        
        if [[ -n "$filename" ]]; then
            echo "    找到: $filename (在 $component 中)"
            
            local deb_name=$(basename "$filename")
            
            if [[ -f "$Config_DownloadDir/$deb_name" ]]; then
                echo "    ✓ 已存在，跳过"
                found=true
                break
            fi
            
            local deb_url="$Config_Mirror/$filename"
            echo "    下载: $deb_url"
            
            if download_file "$deb_url" "$Config_DownloadDir/$deb_name"; then
                echo "    ✓ 下载完成"
                found=true
                break
            else
                echo "    ✗ 下载失败"
            fi
        fi
    done
    
    if [[ "$found" = false ]]; then
        echo "    ✗ 未找到包 $package"
        return 1
    fi
    
    return 0
}

# ============================================
# 主脚本
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/python-build-deps.conf"

echo "=========================================="
echo "  Python 编译依赖下载脚本"
echo "=========================================="

# 加载配置
parse_config "$CONFIG_FILE"

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

# 合并所有依赖
ALL_DEPS="$Config_BuildTools $Config_EssentialDeps $Config_RecommendedDeps $Config_OptionalDeps"
IFS=' ' read -ra PACKAGES <<< "$ALL_DEPS"

echo ""
echo "配置信息:"
echo "  Ubuntu 版本: $Config_UbuntuVersion"
echo "  架构: $Config_Architecture"
echo "  镜像源: $Config_Mirror"
echo "  依赖包数量: ${#PACKAGES[@]}"
echo ""

# 检查下载工具
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    echo "错误: 需要 wget 或 curl"
    exit 1
fi

# 下载包索引
echo "[1/2] 下载包索引..."
echo ""

COMPONENTS=("main" "restricted" "universe" "multiverse")
DOWNLOADED_INDEX=0

for component in "${COMPONENTS[@]}"; do
    if download_package_index "$component"; then
        ((DOWNLOADED_INDEX++))
    fi
done

if [[ $DOWNLOADED_INDEX -eq 0 ]]; then
    echo "错误: 无法下载任何包索引"
    exit 1
fi

echo ""
echo "[2/2] 下载依赖包..."
echo ""

# 统计变量
DOWNLOADED=0
FAILED=0

# 下载所有包
for package in "${PACKAGES[@]}"; do
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

依赖包列表:
$(echo "${PACKAGES[@]}" | tr ' ' '\n' | sort)
EOF

# 打包
echo ""
echo "[*] 打包文件..."

# 清理 macOS 隐藏文件
find "$Config_DownloadDir" -name '.DS_Store' -type f -delete 2>/dev/null || true
find "$Config_DownloadDir" -name '._*' -type f -delete 2>/dev/null || true

if command -v dot_clean &> /dev/null; then
    dot_clean -m "$Config_DownloadDir" 2>/dev/null || true
fi

tar -czf "$Config_ArchiveFile" \
    --no-xattrs \
    --exclude='.DS_Store' \
    --exclude='._*' \
    "$Config_DownloadDir"

echo "✓ 打包完成: $Config_ArchiveFile"

echo ""
echo "=========================================="
echo "  下载完成！"
echo "=========================================="
echo ""
echo "统计信息:"
echo "  • 成功下载: $DOWNLOADED 个包"
echo "  • 下载失败: $FAILED 个包"
echo ""
echo "打包文件: $Config_ArchiveFile"
echo ""
echo "下一步："
echo "1. 将 $Config_ArchiveFile 传输到离线 Ubuntu 环境"
echo "2. 解压: tar -xzf $Config_ArchiveFile"
echo "3. 安装: cd $Config_DownloadDir && sudo dpkg -i *.deb"
echo "4. 然后运行 Python 安装脚本"
echo ""
