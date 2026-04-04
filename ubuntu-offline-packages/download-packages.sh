#!/bin/bash
# Ubuntu/Debian 离线包下载脚本
# 用途：在 macOS/Linux 上下载 Ubuntu 软件包
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
Config_DownloadDir="ubuntu-packages"
Config_ArchiveFile="ubuntu-offline-packages.tar.gz"
Config_UbuntuVersion="jammy"
Config_Architecture="amd64"
Config_Mirror="http://mirrors.aliyun.com/ubuntu"
Config_Packages=()
Config_AutoPackage=true
Config_CleanAfterPackage=false

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

# 从索引中查找包信息
find_package_in_index() {
    local package="$1"
    local component="$2"
    local index_file="$Config_DownloadDir/.Packages-${component}"
    
    if [[ ! -f "$index_file" ]]; then
        return 1
    fi
    
    # 在索引中查找包
    # 格式：
    # Package: unzip
    # Filename: pool/main/u/unzip/unzip_6.0-26ubuntu3_amd64.deb
    
    grep -A 20 "^Package: ${package}$" "$index_file" 2>/dev/null | grep "^Filename:" | head -1 | awk '{print $2}'
}

# ============================================
# 下载包
# ============================================

download_package() {
    local package="$1"
    local found=false
    
    echo "  查找 $package..."
    
    # 在各个组件中查找包
    for component in main restricted universe multiverse; do
        local filename=$(find_package_in_index "$package" "$component")
        
        if [[ -n "$filename" ]]; then
            echo "    找到: $filename (在 $component 中)"
            
            # 提取文件名
            local deb_name=$(basename "$filename")
            
            # 检查是否已下载
            if [[ -f "$Config_DownloadDir/$deb_name" ]]; then
                echo "    ✓ 已存在，跳过"
                found=true
                break
            fi
            
            # 下载
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

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置文件路径（默认在同目录下）
CONFIG_FILE="${1:-$SCRIPT_DIR/packages.conf}"

# 如果第一个参数是 -c 或 --config，则读取第二个参数作为配置文件
if [[ "$1" == "-c" || "$1" == "--config" ]]; then
    CONFIG_FILE="$2"
fi

echo "=========================================="
echo "  Ubuntu/Debian 离线包下载脚本"
echo "=========================================="

# 加载配置
parse_config "$CONFIG_FILE"

# 创建下载目录
mkdir -p "$Config_DownloadDir"

echo ""
echo "配置信息:"
echo "  Ubuntu 版本: $Config_UbuntuVersion"
echo "  架构: $Config_Architecture"
echo "  镜像源: $Config_Mirror"
echo "  软件包数量: ${#Config_Packages[@]}"
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
    echo ""
    echo "错误: 无法下载任何包索引"
    echo "请检查网络连接和镜像源配置"
    exit 1
fi

echo ""
echo "[2/2] 下载软件包..."
echo ""

# 统计变量
DOWNLOADED=0
FAILED=0
SKIPPED=0

# 下载所有包
for package in "${Config_Packages[@]}"; do
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

软件包列表:
$(echo "${Config_Packages[@]}" | tr ' ' '\n' | sort)
EOF

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
