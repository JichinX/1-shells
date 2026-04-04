#!/bin/bash
# Ubuntu/Debian 离线包下载脚本
# 用途：在有网的 Ubuntu/Debian 系统上下载软件包及其依赖
# 运行环境：Ubuntu/Debian 系统，需要 apt-get

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
Config_UbuntuCodename=""
Config_BasicPackages=()
Config_DevPackages=()
Config_NetworkPackages=()
Config_PythonPackages=()
Config_NodejsPackages=()
Config_DownloadDependencies=true
Config_DownloadRecommends=false
Config_DownloadSuggests=false
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
                ubuntu_codename)
                    Config_UbuntuCodename="$value"
                    ;;
                basic_packages)
                    IFS=' ' read -ra Config_BasicPackages <<< "$value"
                    echo "    -> 基础工具包: ${Config_BasicPackages[*]}"
                    ;;
                dev_packages)
                    IFS=' ' read -ra Config_DevPackages <<< "$value"
                    echo "    -> 开发工具包: ${Config_DevPackages[*]}"
                    ;;
                network_packages)
                    IFS=' ' read -ra Config_NetworkPackages <<< "$value"
                    echo "    -> 网络工具包: ${Config_NetworkPackages[*]}"
                    ;;
                python_packages)
                    IFS=' ' read -ra Config_PythonPackages <<< "$value"
                    echo "    -> Python 包: ${Config_PythonPackages[*]}"
                    ;;
                nodejs_packages)
                    IFS=' ' read -ra Config_NodejsPackages <<< "$value"
                    echo "    -> Node.js 包: ${Config_NodejsPackages[*]}"
                    ;;
                download_dependencies)
                    Config_DownloadDependencies="$value"
                    ;;
                download_recommends)
                    Config_DownloadRecommends="$value"
                    ;;
                download_suggests)
                    Config_DownloadSuggests="$value"
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
# 检查运行环境
# ============================================

check_environment() {
    # 检查是否是 Debian/Ubuntu 系统
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/lsb-release ]]; then
        echo "错误: 此脚本需要在 Debian/Ubuntu 系统上运行"
        echo "当前系统不支持 apt 包管理器"
        exit 1
    fi
    
    # 检查 apt-get
    if ! command -v apt-get &> /dev/null; then
        echo "错误: 未找到 apt-get 命令"
        exit 1
    fi
    
    # 检查是否需要 sudo
    if [[ $EUID -ne 0 ]]; then
        echo "提示: 需要 sudo 权限来更新包列表"
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# ============================================
# 下载包及其依赖
# ============================================

# 下载单个包
download_package() {
    local package="$1"
    local downloaded=0
    
    echo "  处理: $package"
    
    # 检查包是否已下载
    if ls "$Config_DownloadDir"/${package}_*.deb 1> /dev/null 2>&1; then
        echo "    ✓ 已存在，跳过"
        return 0
    fi
    
    # 下载包
    if $Config_DownloadDependencies; then
        # 获取依赖列表
        local deps=""
        
        # 获取 Depends
        deps=$(apt-cache depends "$package" 2>/dev/null | grep "Depends:" | awk '{print $2}' | sort -u) || true
        
        # 获取 Recommends
        if $Config_DownloadRecommends; then
            local recs=$(apt-cache depends "$package" 2>/dev/null | grep "Recommends:" | awk '{print $2}' | sort -u) || true
            deps="$deps $recs"
        fi
        
        # 获取 Suggests
        if $Config_DownloadSuggests; then
            local sugs=$(apt-cache depends "$package" 2>/dev/null | grep "Suggests:" | awk '{print $2}' | sort -u) || true
            deps="$deps $sugs"
        fi
        
        # 下载依赖
        for dep in $deps; do
            # 跳过虚拟包和已下载的包
            if ls "$Config_DownloadDir"/${dep}_*.deb 1> /dev/null 2>&1; then
                continue
            fi
            
            # 下载依赖包
            echo "    下载依赖: $dep"
            if apt-get download "$dep" -o Dir::Cache::archives="$Config_DownloadDir" 2>/dev/null; then
                ((downloaded++)) || true
            fi
        done
    fi
    
    # 下载主包
    echo "    下载主包: $package"
    if apt-get download "$package" -o Dir::Cache::archives="$Config_DownloadDir" 2>/dev/null; then
        ((downloaded++)) || true
    fi
    
    if [[ $downloaded -gt 0 ]]; then
        echo "    ✓ 下载完成 ($downloaded 个文件)"
    else
        echo "    ✗ 下载失败"
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

# 检查运行环境
check_environment

# 加载配置
parse_config "$CONFIG_FILE"

# 创建下载目录
mkdir -p "$Config_DownloadDir"

# 更新包列表
echo ""
echo "[*] 更新包列表..."
$SUDO apt-get update -qq

# 统计变量
DOWNLOADED=0
SKIPPED=0
TOTAL_PACKAGES=0

# 合并所有包列表
ALL_PACKAGES=()
ALL_PACKAGES+=("${Config_BasicPackages[@]}")
ALL_PACKAGES+=("${Config_DevPackages[@]}")
ALL_PACKAGES+=("${Config_NetworkPackages[@]}")
ALL_PACKAGES+=("${Config_PythonPackages[@]}")
ALL_PACKAGES+=("${Config_NodejsPackages[@]}")

# 去重
IFS=' ' read -ra UNIQUE_PACKAGES <<< "$(echo "${ALL_PACKAGES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

TOTAL_PACKAGES=${#UNIQUE_PACKAGES[@]}

echo ""
echo "[*] 准备下载 $TOTAL_PACKAGES 个软件包"
echo ""

# 下载所有包
CURRENT=0
for package in "${UNIQUE_PACKAGES[@]}"; do
    ((CURRENT++))
    echo "[$CURRENT/$TOTAL_PACKAGES] $package"
    download_package "$package"
done

# 创建包列表文件
echo ""
echo "[*] 生成包列表文件..."
cat > "$Config_DownloadDir/package-list.txt" <<EOF
配置文件: $CONFIG_FILE
Ubuntu 版本: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/debian_version)
下载时间: $(date '+%Y-%m-%d %H:%M:%S')
软件包数量: $TOTAL_PACKAGES

软件包列表:
$(echo "${UNIQUE_PACKAGES[@]}" | tr ' ' '\n' | sort)
EOF

# 统计下载的文件
DOWNLOADED=$(ls -1 "$Config_DownloadDir"/*.deb 2>/dev/null | wc -l | tr -d ' ')

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
echo "  • 软件包: $TOTAL_PACKAGES 个"
echo "  • .deb 文件: $DOWNLOADED 个"
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
echo "3. 安装: cd $Config_DownloadDir && sudo bash install-packages.sh"
echo ""
