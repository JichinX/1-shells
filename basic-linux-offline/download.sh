#!/bin/bash
# 一键下载脚本 - 在有网环境运行
# 用途：下载 pyenv、fnm、Python、Node.js 离线安装包
# 优化：文件已存在则跳过下载，支持配置文件

set -e

# ============================================
# 配置文件解析函数
# ============================================

# 默认配置
Config_DownloadDir="offline-packages"
Config_ArchiveFile="linux-offline-dev-tools.tar.gz"
Config_PythonVersions=("3.12.0" "3.11.8")
Config_PythonMirror="https://www.python.org/ftp/python"
Config_NodeVersions=("20.11.0" "18.19.0")
Config_NodeMirror="https://nodejs.org/dist"
Config_NodeArch="linux-x64"
Config_PyenvRepo="https://github.com/pyenv/pyenv.git"
Config_PyenvShallowClone=true
Config_FnmUrl="https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip"
Config_DownloadPython=true
Config_DownloadNodejs=true
Config_DownloadPyenv=true
Config_DownloadFnm=true
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
            value="${value%"${value##*[![:space:]]}"}"  # trim right
            value="${value#"${value%%[![:space:]]*}"}"  # trim left
            
            case "$key" in
                download_dir)
                    Config_DownloadDir="$value"
                    ;;
                archive_file)
                    Config_ArchiveFile="$value"
                    ;;
                python_versions)
                    IFS=' ' read -ra Config_PythonVersions <<< "$value"
                    echo "    -> Python 版本: ${Config_PythonVersions[*]}"
                    ;;
                python_mirror)
                    Config_PythonMirror="$value"
                    ;;
                node_versions)
                    IFS=' ' read -ra Config_NodeVersions <<< "$value"
                    echo "    -> Node.js 版本: ${Config_NodeVersions[*]}"
                    ;;
                node_mirror)
                    Config_NodeMirror="$value"
                    ;;
                node_arch)
                    Config_NodeArch="$value"
                    ;;
                pyenv_repo)
                    Config_PyenvRepo="$value"
                    ;;
                pyenv_shallow_clone)
                    Config_PyenvShallowClone="$value"
                    ;;
                fnm_url)
                    Config_FnmUrl="$value"
                    ;;
                download_python)
                    Config_DownloadPython="$value"
                    ;;
                download_nodejs)
                    Config_DownloadNodejs="$value"
                    ;;
                download_pyenv)
                    Config_DownloadPyenv="$value"
                    ;;
                download_fnm)
                    Config_DownloadFnm="$value"
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
# 主脚本
# ============================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置文件路径（默认在同目录下）
CONFIG_FILE="${1:-$SCRIPT_DIR/versions.conf}"

# 如果第一个参数是 -c 或 --config，则读取第二个参数作为配置文件
if [[ "$1" == "-c" || "$1" == "--config" ]]; then
    CONFIG_FILE="$2"
fi

echo "=========================================="
echo "  Linux 离线开发环境 - 下载脚本"
echo "=========================================="

# 加载配置
parse_config "$CONFIG_FILE"

# 创建下载目录
mkdir -p "$Config_DownloadDir"
cd "$Config_DownloadDir"

# 统计变量
DOWNLOADED=0
SKIPPED=0
TOTAL_STEPS=0

# 计算总步骤数
$Config_DownloadPyenv && ((TOTAL_STEPS++))
$Config_DownloadPython && ((TOTAL_STEPS++))
$Config_DownloadFnm && ((TOTAL_STEPS++))
$Config_DownloadNodejs && ((TOTAL_STEPS++))

CURRENT_STEP=0

# 1. 下载 pyenv
if $Config_DownloadPyenv; then
    ((CURRENT_STEP++))
    echo ""
    echo "[$CURRENT_STEP/$TOTAL_STEPS] 下载 pyenv..."
    
    if [ ! -f "pyenv-offline.tar.gz" ]; then
        echo "  下载中..."
        if $Config_PyenvShallowClone; then
            git clone --depth 1 "$Config_PyenvRepo" pyenv-offline
        else
            git clone "$Config_PyenvRepo" pyenv-offline
        fi
        tar -czf pyenv-offline.tar.gz pyenv-offline
        rm -rf pyenv-offline
        echo "  ✓ pyenv 下载完成"
        ((DOWNLOADED++))
    else
        echo "  ✓ pyenv 已存在，跳过"
        ((SKIPPED++))
    fi
fi

# 2. 下载 Python 源码包
if $Config_DownloadPython && [ ${#Config_PythonVersions[@]} -gt 0 ]; then
    ((CURRENT_STEP++))
    echo ""
    echo "[$CURRENT_STEP/$TOTAL_STEPS] 下载 Python 源码包..."
    
    for version in "${Config_PythonVersions[@]}"; do
        filename="Python-$version.tgz"
        if [ ! -f "$filename" ]; then
            echo "  下载 Python $version..."
            wget -q "$Config_PythonMirror/$version/$filename"
            echo "  ✓ Python $version 下载完成"
            ((DOWNLOADED++))
        else
            echo "  ✓ Python $version 已存在，跳过"
            ((SKIPPED++))
        fi
    done
fi

# 3. 下载 fnm
if $Config_DownloadFnm; then
    ((CURRENT_STEP++))
    echo ""
    echo "[$CURRENT_STEP/$TOTAL_STEPS] 下载 fnm..."
    
    if [ ! -f "fnm-linux.zip" ]; then
        echo "  下载中..."
        wget -q "$Config_FnmUrl"
        echo "  ✓ fnm 下载完成"
        ((DOWNLOADED++))
    else
        echo "  ✓ fnm 已存在，跳过"
        ((SKIPPED++))
    fi
fi

# 4. 下载 Node.js 二进制包
if $Config_DownloadNodejs && [ ${#Config_NodeVersions[@]} -gt 0 ]; then
    ((CURRENT_STEP++))
    echo ""
    echo "[$CURRENT_STEP/$TOTAL_STEPS] 下载 Node.js 二进制包..."
    
    for version in "${Config_NodeVersions[@]}"; do
        filename="node-v$version-$Config_NodeArch.tar.gz"
        if [ ! -f "$filename" ]; then
            echo "  下载 Node.js v$version..."
            wget -q "$Config_NodeMirror/v$version/$filename"
            echo "  ✓ Node.js v$version 下载完成"
            ((DOWNLOADED++))
        else
            echo "  ✓ Node.js v$version 已存在，跳过"
            ((SKIPPED++))
        fi
    done
fi

# 创建版本信息文件
cd ..
cat > "$Config_DownloadDir/versions.txt" <<EOF
配置文件: $CONFIG_FILE
Python Versions: ${Config_PythonVersions[*]}
Node.js Versions: ${Config_NodeVersions[*]}
Download Date: $(date '+%Y-%m-%d %H:%M:%S')
Files Downloaded: $DOWNLOADED
Files Skipped: $SKIPPED
EOF

# 检查是否需要打包
NEED_PACKAGE=false
if $Config_AutoPackage; then
    if [ ! -f "$Config_ArchiveFile" ]; then
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
fi

# 打包所有文件
if [ "$NEED_PACKAGE" = true ]; then
    echo ""
    echo "打包所有文件..."
    tar -czf "$Config_ArchiveFile" "$Config_DownloadDir"
    echo "✓ 打包完成"
    
    # 清理源文件
    if $Config_CleanAfterPackage; then
        echo "清理源文件..."
        rm -rf "$Config_DownloadDir"
    fi
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
echo "下载目录: $Config_DownloadDir/"
if $Config_AutoPackage; then
    echo "打包文件: $Config_ArchiveFile"
fi
echo ""
echo "文件列表:"
ls -lh "$Config_DownloadDir/"
echo ""
echo "下一步："
if $Config_AutoPackage; then
    echo "1. 将 $Config_ArchiveFile 传输到离线环境"
    echo "2. 解压: tar -xzf $Config_ArchiveFile"
else
    echo "1. 将 $Config_DownloadDir 目录传输到离线环境"
fi
echo "3. 运行: cd $Config_DownloadDir && bash ../install.sh"
echo ""
