#!/usr/bin/env bash
# ==============================================================================
# JetBrains 离线资源一键下载脚本
#
# 功能：在有网络的机器上运行，下载所有离线部署 JetBrains 远程开发所需的资源
# 用法：./download.sh [选项]
#
# 输出结构：
#   jetbrains-offline-bundle/
#   ├── backends/                  Backend IDE 离线包
#   ├── clients/                   JetBrains Client（各平台）
#   ├── jbr/                       JetBrains Runtime
#   ├── keys/                      PGP KEYS 文件
#   ├── products.json              产品信息文件
#   ├── deploy-server.sh           服务器端部署脚本
#   └── README.md                  使用说明
#
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ======================== 默认配置 ========================
ARCH="x64"
OUTPUT_DIR="./jetbrains-offline-bundle"
PRODUCTS="IU"
IDE_VERSION=""
INCLUDE_EAP=false
CLIENT_PLATFORMS="linux-x64,windows-x64,mac-x64,mac-arm64"
DOWNLOAD_CLIENT=true
DOWNLOAD_JBR=true
DOWNLOAD_KEYS=true
GENERATE_DEPLOY_SCRIPT=true
PROXY=""

# JetBrains 官方下载地址
JETBRAINS_DOWNLOAD_BASE="https://download.jetbrains.com"
CLIENT_DOWNLOADER_URL="https://data.services.jetbrains.com/products/download?code=JCD&platform=linux_x86-64"

# ======================== 配置文件解析 ========================
CONFIG_FILE=""

load_config() {
    local conf="$1"
    [[ ! -f "$conf" ]] && return 1

    log_info "加载配置: ${conf}"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" =~ ^[a-z_]+[[:space:]]*= ]]; then
            local key
            key=$(echo "$line" | sed 's/[[:space:]]*=.*//' | tr -d '[:space:]')
            local val
            val=$(echo "$line" | sed 's/[^=]*=[[:space:]]*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            case "$key" in
                arch)                      [[ -n "$val" ]] && ARCH="$val" ;;
                output)                    [[ -n "$val" ]] && OUTPUT_DIR="$val" ;;
                products)                  [[ -n "$val" ]] && PRODUCTS="$val" ;;
                ide_version)               [[ -n "$val" ]] && IDE_VERSION="$val" ;;
                include_eap)               INCLUDE_EAP=$(to_bool "$val") ;;
                client_platforms)          [[ -n "$val" ]] && CLIENT_PLATFORMS="$val" ;;
                download_client)           DOWNLOAD_CLIENT=$(to_bool "$val") ;;
                download_jbr)              DOWNLOAD_JBR=$(to_bool "$val") ;;
                download_keys)             DOWNLOAD_KEYS=$(to_bool "$val") ;;
                generate_deploy_script)    GENERATE_DEPLOY_SCRIPT=$(to_bool "$val") ;;
                proxy)                     PROXY="$val" ;;
            esac
        fi
    done < "$conf"

    log_info "✓ 配置加载完成"
}

to_bool() {
    local v
    v=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$v" in
        true|yes|1|on) echo "true" ;;
        false|no|0|off) echo "false" ;;
        *) echo "$1" ;;
    esac
}

find_default_config() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    for f in "$script_dir/config.conf" "./config.conf"; do
        if [[ -f "$f" ]]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}

# ======================== 工具函数 ========================
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${CYAN}  $1${NC}\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

download_file() {
    local url="$1" output="$2" retries=3 retry=0
    local opts=(-fSL --connect-timeout 30 --max-time 1800)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    while [ $retry -lt $retries ]; do
        log_info "下载: $(basename "$output")"
        if curl "${opts[@]}" -o "$output" "$url"; then
            log_info "  ✓ $(du -h "$output" | cut -f1)"
            return 0
        fi
        retry=$((retry + 1))
        log_warn "  ✗ 重试 ${retry}/${retries}..."
        sleep 5
    done
    log_error "下载失败: $url"
    return 1
}

check_deps() {
    log_step "检查依赖"
    for cmd in curl tar; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "缺少 $cmd，请先安装"
            exit 1
        fi
    done
    log_info "✓ 依赖就绪"
}

# ======================== 获取最新版本信息 ========================
get_latest_version() {
    local product="$1"
    local opts=(-s --connect-timeout 15)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    local releases_url="https://data.services.jetbrains.com/products/releases?code=${product}&latest=true&type=release"

    if [[ "$INCLUDE_EAP" == true ]]; then
        releases_url="https://data.services.jetbrains.com/products/releases?code=${product}&latest=true"
    fi

    local response
    response=$(curl "${opts[@]}" "$releases_url" 2>/dev/null || echo "{}")

    local version
    version=$(echo "$response" | grep -oP '"version"\s*:\s*"\K[^"]+' | head -1)

    if [[ -z "$version" ]]; then
        log_warn "无法获取 ${product} 最新版本，使用默认版本"
        echo "2024.1"
    else
        echo "$version"
    fi
}

# ======================== 下载 Backend IDE ========================
download_backends() {
    log_step "下载 Backend IDE"

    local backend_dir="$OUTPUT_DIR/backends"
    mkdir -p "$backend_dir"

    IFS=',' read -ra product_array <<< "$PRODUCTS"
    local server_arch="linux-${ARCH}"

    for product in "${product_array[@]}"; do
        product=$(echo "$product" | xargs)
        [[ -z "$product" ]] && continue

        local version="$IDE_VERSION"
        if [[ -z "$version" ]]; then
            version=$(get_latest_version "$product")
            log_info "${product} 最新版本: ${version}"
        fi

        # 构建下载 URL
        local product_name
        case "$product" in
            IU)  product_name="idea/ideaIU" ;;
            IC)  product_name="idea/ideaIC" ;;
            PCP) product_name="python/pycharm-professional" ;;
            PCC) product_name="python/pycharm-community" ;;
            WS)  product_name="webstorm/WebStorm" ;;
            GO)  product_name="goland/goland" ;;
            CL)  product_name="cpp/CLion" ;;
            PS)  product_name="phpstorm/PhpStorm" ;;
            RD)  product_name="rider/JetBrains.Rider" ;;
            DB)  product_name="datagrip/datagrip" ;;
            *)   log_warn "未知产品代码: ${product}"; continue ;;
        esac

        local tar_file="${backend_dir}/${product}-${version}-${server_arch}.tar.gz"
        local download_url="${JETBRAINS_DOWNLOAD_BASE}/${product_name}-${version}.tar.gz"

        if [[ -f "$tar_file" ]]; then
            log_info "${product}-${version} 已存在，跳过"
        else
            if download_file "$download_url" "$tar_file"; then
                log_info "✓ ${product}-${version} 下载完成"
            else
                log_warn "✗ ${product}-${version} 下载失败，跳过"
                rm -f "$tar_file"
            fi
        fi
    done
}

# ======================== 下载 JetBrains Client ========================
download_clients() {
    [[ "$DOWNLOAD_CLIENT" != true ]] && return 0
    log_step "下载 JetBrains Client"

    local client_dir="$OUTPUT_DIR/clients"
    mkdir -p "$client_dir"

    IFS=',' read -ra platform_array <<< "$CLIENT_PLATFORMS"

    for platform in "${platform_array[@]}"; do
        platform=$(echo "$platform" | xargs)
        [[ -z "$platform" ]] && continue

        local ext="tar.gz"
        [[ "$platform" == windows-* ]] && ext="zip"

        local client_file="${client_dir}/gateway-client-${platform}.${ext}"

        # 使用 Client Downloader 的 API
        local download_url="https://data.services.jetbrains.com/products/download?code=GCL&platform=${platform}"

        if [[ -f "$client_file" ]]; then
            log_info "Client ${platform} 已存在，跳过"
        else
            if download_file "$download_url" "$client_file"; then
                log_info "✓ Client ${platform} 下载完成"
            else
                log_warn "✗ Client ${platform} 下载失败，跳过"
                rm -f "$client_file"
            fi
        fi
    done
}

# ======================== 下载 JBR ========================
download_jbr() {
    [[ "$DOWNLOAD_JBR" != true ]] && return 0
    log_step "下载 JetBrains Runtime (JBR)"

    local jbr_dir="$OUTPUT_DIR/jbr"
    mkdir -p "$jbr_dir"

    # JBR 下载地址需要从 JetBrains 获取最新版本
    # 简化处理：下载几个常用的 JBR 版本
    local jbr_versions=(
        "jbr_jcef-17.0.10-linux-x64-b1207.4"
        "jbr_jcef-17.0.10-linux-aarch64-b1207.4"
        "jbr_jcef-17.0.10-windows-x64-b1207.4"
        "jbr_jcef-17.0.10-osx-x64-b1207.4"
        "jbr_jcef-17.0.10-osx-aarch64-b1207.4"
    )

    for jbr in "${jbr_versions[@]}"; do
        local tar_file="${jbr_dir}/${jbr}.tar.gz"
        local download_url="https://cache-redirector.jetbrains.com/intellij-jbr/${jbr}.tar.gz"

        if [[ -f "$tar_file" ]]; then
            log_info "${jbr} 已存在，跳过"
        else
            if download_file "$download_url" "$tar_file"; then
                log_info "✓ ${jbr} 下载完成"
            else
                log_warn "✗ ${jbr} 下载失败，跳过"
                rm -f "$tar_file"
            fi
        fi
    done
}

# ======================== 下载 KEYS ========================
download_keys() {
    [[ "$DOWNLOAD_KEYS" != true ]] && return 0
    log_step "下载 PGP KEYS"

    local keys_dir="$OUTPUT_DIR/keys"
    mkdir -p "$keys_dir"

    local keys_file="${keys_dir}/KEYS"
    local download_url="https://raw.githubusercontent.com/JetBrains/intellij-community/master/KEYS"

    if [[ -f "$keys_file" ]]; then
        log_info "KEYS 已存在，跳过"
    else
        if download_file "$download_url" "$keys_file"; then
            log_info "✓ KEYS 下载完成"
        else
            log_warn "✗ KEYS 下载失败，跳过"
            rm -f "$keys_file"
        fi
    fi
}

# ======================== 生成 products.json ========================
generate_products_json() {
    log_step "生成 products.json"

    local products_json="$OUTPUT_DIR/products.json"
    local timestamp
    timestamp=$(date -Iseconds)

    # 收集已下载的 backends
    local backends_array="[]"
    local backends_list=""
    for tar_file in "$OUTPUT_DIR/backends"/*.tar.gz; do
        [[ -f "$tar_file" ]] || continue
        local basename
        basename=$(basename "$tar_file")
        backends_list="${backends_list}\"${basename}\","
    done
    [[ -n "$backends_list" ]] && backends_array="[$(echo "$backends_list" | sed 's/,$//')]"

    # 收集已下载的 clients
    local clients_array="[]"
    local clients_list=""
    for client_file in "$OUTPUT_DIR/clients"/*; do
        [[ -f "$client_file" ]] || continue
        local basename
        basename=$(basename "$client_file")
        clients_list="${clients_list}\"${basename}\","
    done
    [[ -n "$clients_list" ]] && clients_array="[$(echo "$clients_list" | sed 's/,$//')]"

    cat > "$products_json" << EOF
{
    "created_at": "${timestamp}",
    "ide_version": "${IDE_VERSION:-latest}",
    "products": "${PRODUCTS}",
    "arch": "${ARCH}",
    "backends": ${backends_array},
    "clients": ${clients_array}
}
EOF

    log_info "✓ products.json 已生成"
}

# ======================== 生成部署脚本 ========================
generate_deploy_script() {
    [[ "$GENERATE_DEPLOY_SCRIPT" != true ]] && return 0
    log_step "生成服务器端部署脚本"

    local deploy_script="$OUTPUT_DIR/deploy-server.sh"

    cat > "$deploy_script" << 'DEPLOY_EOF'
#!/usr/bin/env bash
# ==============================================================================
# JetBrains Backend IDE 服务器端离线部署脚本
#
# 用法: sudo ./deploy-server.sh [--product <产品代码>] [--user <用户名>]
#
# 示例:
#   sudo ./deploy-server.sh --product IU --user developer
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${CYAN}  $1${NC}\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_USER=""
TARGET_PRODUCT=""

# 产品名称映射
declare -A PRODUCT_NAMES=(
    [IU]="IntelliJ IDEA Ultimate"
    [IC]="IntelliJ IDEA Community"
    [PCP]="PyCharm Professional"
    [PCC]="PyCharm Community"
    [WS]="WebStorm"
    [GO]="GoLand"
    [CL]="CLion"
    [PS]="PhpStorm"
    [RD]="Rider"
    [DB]="DataGrip"
)

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --product) TARGET_PRODUCT="$2"; shift 2 ;;
        --user) TARGET_USER="$2"; shift 2 ;;
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

# 检查权限
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "需要 root 权限，请使用 sudo"
    exit 1
fi

# 获取目标用户
if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER="${SUDO_USER:-$USER}"
fi

get_home() {
    eval echo "~$TARGET_USER"
}

# 检查依赖
check_deps() {
    log_step "检查系统依赖"

    local deps=(curl tar ps)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    # 检查 Java
    if ! command -v java &>/dev/null; then
        log_warn "未检测到 Java，JetBrains IDE 需要 Java 17+"
        log_info "请先安装: sudo apt install openjdk-17-jdk"
    else
        local java_version
        java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$java_version" -lt 17 ]]; then
            log_warn "Java 版本过低 (${java_version})，需要 Java 17+"
        else
            log_info "✓ Java 版本: $(java -version 2>&1 | head -1)"
        fi
    fi

    # 检查图形库依赖
    local lib_deps=(libxext libxrender libxtst libxi freetype)
    for lib in "${lib_deps[@]}"; do
        if ! ldconfig -p 2>/dev/null | grep -q "$lib"; then
            log_warn "缺少图形库: ${lib}"
            log_info "请安装: sudo apt install libxext6 libxrender1 libxtst6 libxi6 libfreetype6"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        exit 1
    fi

    log_info "✓ 依赖检查完成"
}

# 列出可用的 Backend
list_available_backends() {
    log_step "可用的 Backend IDE"

    local backends_dir="$SCRIPT_DIR/backends"
    if [[ ! -d "$backends_dir" ]]; then
        log_error "未找到 backends 目录"
        exit 1
    fi

    local count=0
    for tar_file in "$backends_dir"/*.tar.gz; do
        [[ -f "$tar_file" ]] || continue
        count=$((count + 1))
        local basename
        basename=$(basename "$tar_file")
        local product
        product=$(echo "$basename" | cut -d'-' -f1)
        local version
        version=$(echo "$basename" | cut -d'-' -f2)
        local product_name="${PRODUCT_NAMES[$product]:-$product}"
        echo -e "  ${GREEN}${count})${NC} ${product_name} (${product}) - ${version}"
    done

    if [[ $count -eq 0 ]]; then
        log_error "没有找到可用的 Backend IDE"
        exit 1
    fi
}

# 部署 Backend
deploy_backend() {
    local product="$1"
    local home
    home=$(get_home)
    local remote_dev_dir="$home/.cache/JetBrains/RemoteDev/dist"
    local backends_dir="$SCRIPT_DIR/backends"

    log_step "部署 Backend: ${PRODUCT_NAMES[$product]:-$product}"

    # 查找对应的 tar 文件
    local tar_file=""
    for f in "$backends_dir"/${product}-*.tar.gz; do
        if [[ -f "$f" ]]; then
            tar_file="$f"
            break
        fi
    done

    if [[ -z "$tar_file" ]]; then
        log_error "未找到产品 ${product} 的安装包"
        exit 1
    fi

    local basename
    basename=$(basename "$tar_file" .tar.gz)
    local install_dir="$remote_dev_dir/$basename"

    mkdir -p "$remote_dev_dir"

    if [[ -d "$install_dir" ]]; then
        log_warn "已存在: $install_dir"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "跳过部署"
            return 0
        fi
        rm -rf "$install_dir"
    fi

    log_info "解压到: $install_dir"
    mkdir -p "$install_dir"
    tar -xzf "$tar_file" -C "$install_dir" --strip-components=1

    # 设置权限
    chown -R "$TARGET_USER:$TARGET_USER" "$install_dir"

    log_info "✓ Backend 部署完成: $install_dir"

    # 生成启动命令示例
    local bin_dir="$install_dir/bin"
    local remote_dev_script="$bin_dir/remote-dev-server.sh"

    if [[ -f "$remote_dev_script" ]]; then
        chmod +x "$remote_dev_script"
        echo ""
        log_info "启动 Backend 示例:"
        echo -e "  ${CYAN}$remote_dev_script run /path/to/project --ssh-link-host \$(hostname)${NC}"
        echo ""
    fi
}

# 主流程
main() {
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  JetBrains Backend 离线部署工具      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

    check_deps

    if [[ -n "$TARGET_PRODUCT" ]]; then
        deploy_backend "$TARGET_PRODUCT"
    else
        list_available_backends
        echo ""
        read -p "请输入要部署的产品代码 (如 IU, PCP, WS): " TARGET_PRODUCT
        [[ -z "$TARGET_PRODUCT" ]] && { log_error "未输入产品代码"; exit 1; }
        deploy_backend "$TARGET_PRODUCT"
    fi

    echo ""
    log_info "部署完成！"
    echo ""
    log_info "下一步:"
    echo "  1. 在本地安装 JetBrains Gateway"
    echo "  2. 配置 Gateway 使用离线资源（参考 README.md）"
    echo "  3. 通过 SSH 连接到此服务器进行远程开发"
    echo ""
}

main "$@"
DEPLOY_EOF

    chmod +x "$deploy_script"
    log_info "✓ deploy-server.sh 已生成"
}

# ======================== 生成 README ========================
generate_readme() {
    log_step "生成 README"

    local readme="$OUTPUT_DIR/README.md"

    cat > "$readme" << 'README_EOF'
# JetBrains 离线资源包

本目录包含在离线环境下部署 JetBrains 远程开发所需的所有组件。

## 目录结构

```
jetbrains-offline-bundle/
├── backends/              Backend IDE 安装包
├── clients/               JetBrains Client（各平台）
├── jbr/                   JetBrains Runtime
├── keys/                  PGP KEYS 文件
├── products.json          产品信息
├── deploy-server.sh       服务器端部署脚本
└── README.md              本文档
```

## 服务器端部署

### 1. 上传到服务器

将整个 `jetbrains-offline-bundle` 目录上传到服务器：

```bash
scp -r jetbrains-offline-bundle user@server:/opt/
```

### 2. 安装 Backend IDE

```bash
cd /opt/jetbrains-offline-bundle
sudo ./deploy-server.sh --product IU --user developer
```

### 3. 手动安装 Backend（可选）

如果部署脚本不可用，可以手动安装：

```bash
# 创建目录
mkdir -p ~/.cache/JetBrains/RemoteDev/dist/

# 解压 Backend
tar -xzf backends/IU-2024.1-linux-x64.tar.gz -C ~/.cache/JetBrains/RemoteDev/dist/

# 启动 Backend
~/.cache/JetBrains/RemoteDev/dist/IU-2024.1/bin/remote-dev-server.sh run /path/to/project --ssh-link-host $(hostname)
```

## 客户端配置（JetBrains Gateway）

### 方式一：使用本地 Web 服务器

1. 在内网部署一个 Web 服务器（如 nginx）
2. 将 `clients/`、`jbr/`、`keys/` 目录放到 Web 服务器上
3. 配置 Gateway 指向内网地址：

```bash
# Linux
mkdir -p ~/.config/JetBrains/RemoteDev/
echo "http://internal-server/clients/" > ~/.config/JetBrains/RemoteDev/clientDownloadUrl
echo "http://internal-server/jbr/" > ~/.config/JetBrains/RemoteDev/jreDownloadUrl
echo "http://internal-server/keys/KEYS" > ~/.config/JetBrains/RemoteDev/pgpPublicKeyUrl

# macOS
mkdir -p ~/Library/Application\ Support/JetBrains/RemoteDev/
echo "http://internal-server/clients/" > ~/Library/Application\ Support/JetBrains/RemoteDev/clientDownloadUrl
echo "http://internal-server/jbr/" > ~/Library/Application\ Support/JetBrains/RemoteDev/jreDownloadUrl
echo "http://internal-server/keys/KEYS" > ~/Library/Application\ Support/JetBrains/RemoteDev/pgpPublicKeyUrl
```

### 方式二：手动安装 Client

将 `clients/` 目录中对应平台的 Client 包解压到本地：

- **Linux**: `~/.cache/JetBrains/RemoteDev/clients/`
- **macOS**: `~/Library/Caches/JetBrains/RemoteDev/clients/`
- **Windows**: `%LOCALAPPDATA%\JetBrains\RemoteDev\clients\`

## 系统要求

### 服务器端（Linux）

- 操作系统：Linux x64 或 arm64
- Java：17 或更高版本
- 依赖：
  ```bash
  sudo apt install openjdk-17-jdk libxext6 libxrender1 libxtst6 libxi6 libfreetype6 procps
  ```

### 客户端

- JetBrains Gateway 223.7571.203 或更高版本
- 或安装了 Gateway 插件的 JetBrains IDE

## 产品代码

| 代码 | 产品名称 |
|------|---------|
| IU   | IntelliJ IDEA Ultimate |
| IC   | IntelliJ IDEA Community |
| PCP  | PyCharm Professional |
| PCC  | PyCharm Community |
| WS   | WebStorm |
| GO   | GoLand |
| CL   | CLion |
| PS   | PhpStorm |
| RD   | Rider |
| DB   | DataGrip |

## 故障排除

### Backend 启动失败

检查 Java 版本和图形库依赖：

```bash
java -version
ldconfig -p | grep -E "libxext|libxrender|libxtst"
```

### Client 下载失败

确保 Gateway 配置的 URL 可访问：

```bash
curl http://internal-server/clients/
```

### 连接失败

确保 SSH 连接正常，且 Backend 已启动：

```bash
# 在服务器上检查 Backend 进程
ps aux | grep idea

# 测试 SSH 连接
ssh user@server
```

## 参考资料

- [JetBrains Remote Development](https://www.jetbrains.com/help/idea/remote-development-a.html)
- [Fully Offline Mode](https://www.jetbrains.com/help/idea/fully-offline-mode.html)
README_EOF

    log_info "✓ README.md 已生成"
}

# ======================== 用法帮助 ========================
show_help() {
    cat << 'HELP'
用法: ./download.sh [选项]

在有网络的机器上运行，下载 JetBrains 远程开发所需的全部离线资源。

选项:
  --config <file>               配置文件路径 (默认: 同目录下 config.conf)
  -a, --arch <x64|arm64>        服务器架构 (默认: x64)
  -o, --output <dir>            输出目录 (默认: ./jetbrains-offline-bundle)
  -p, --products <codes>        产品代码，逗号分隔 (默认: IU)
  -v, --version <ver>           指定 IDE 版本 (如 2024.1)
  --include-eap                 包含 EAP 版本
  --client-platforms <list>     客户端平台，逗号分隔
  --no-client                   不下载 JetBrains Client
  --no-jbr                      不下载 JetBrains Runtime
  --no-keys                     不下载 KEYS 文件
  --proxy <url>                 HTTP 代理
  -h, --help                    显示帮助

产品代码:
  IU  - IntelliJ IDEA Ultimate
  IC  - IntelliJ IDEA Community
  PCP - PyCharm Professional
  PCC - PyCharm Community
  WS  - WebStorm
  GO  - GoLand
  CL  - CLion
  PS  - PhpStorm
  RD  - Rider
  DB  - DataGrip

示例:
  # 下载 IntelliJ IDEA 和 PyCharm（默认版本）
  ./download.sh -p IU,PCP

  # 指定版本和架构
  ./download.sh -p IU -v 2024.1 -a arm64

  # 使用配置文件
  ./download.sh --config config.conf

  # 使用代理
  ./download.sh --proxy http://127.0.0.1:7890

下载完成后，将整个输出目录传输到内网服务器，然后运行:
  cd jetbrains-offline-bundle
  sudo ./deploy-server.sh --product IU
HELP
}

# ======================== 参数解析 ========================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--arch)              ARCH="$2"; shift 2 ;;
            -o|--output)            OUTPUT_DIR="$2"; shift 2 ;;
            -p|--products)          PRODUCTS="$2"; shift 2 ;;
            -v|--version)           IDE_VERSION="$2"; shift 2 ;;
            --config)               CONFIG_FILE="$2"; shift 2 ;;
            --include-eap)          INCLUDE_EAP=true; shift ;;
            --client-platforms)     CLIENT_PLATFORMS="$2"; shift 2 ;;
            --no-client)            DOWNLOAD_CLIENT=false; shift ;;
            --no-jbr)               DOWNLOAD_JBR=false; shift ;;
            --no-keys)              DOWNLOAD_KEYS=false; shift ;;
            --proxy)                PROXY="$2"; shift 2 ;;
            -h|--help)              show_help; exit 0 ;;
            *) log_error "未知参数: $1"; show_help; exit 1 ;;
        esac
    done
}

# ======================== 主流程 ========================
main() {
    parse_args "$@"

    # 加载配置文件
    if [[ -n "$CONFIG_FILE" ]]; then
        load_config "$CONFIG_FILE" || { log_error "无法加载配置文件: $CONFIG_FILE"; exit 1; }
    else
        local default_conf
        default_conf=$(find_default_config) && load_config "$default_conf"
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    JetBrains 离线资源 一键下载工具              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  产品: ${GREEN}${PRODUCTS}${NC}"
    echo -e "  版本: ${GREEN}${IDE_VERSION:-latest}${NC}"
    echo -e "  架构: ${GREEN}${ARCH}${NC}"
    echo -e "  输出: ${GREEN}${OUTPUT_DIR}${NC}"
    echo ""

    check_deps

    mkdir -p "$OUTPUT_DIR"/{backends,clients,jbr,keys}

    download_backends
    download_clients
    download_jbr
    download_keys
    generate_products_json
    generate_deploy_script
    generate_readme

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ 全部下载完成！${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
    local size
    size=$(du -sh "$OUTPUT_DIR" | cut -f1)
    local backends
    backends=$(ls "$OUTPUT_DIR/backends"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  📁 输出目录: ${CYAN}$(cd "$OUTPUT_DIR" && pwd)${NC}"
    echo -e "  📦 总大小:   ${CYAN}${size}${NC}"
    echo -e "  💻 Backends: ${CYAN}${backends}${NC}"
    echo ""
    echo -e "  ${YELLOW}下一步:${NC}"
    echo -e "    1. 将 ${CYAN}${OUTPUT_DIR}${NC} 整个目录传到内网服务器"
    echo -e "    2. 在服务器上运行: ${CYAN}sudo ./deploy-server.sh --product IU${NC}"
    echo -e "    3. 配置客户端 Gateway 使用离线资源（参考 README.md）"
    echo ""
}

main "$@"
