#!/usr/bin/env bash
# ==============================================================================
# VSCode 离线资源一键下载脚本
#
# 功能：在有网络的机器上运行，下载所有离线部署 VSCode 远程开发所需的资源
# 用法：./download.sh [选项]
#   --config <file>               使用配置文件 (默认: 同目录下 config.conf)
#   -a, --arch <x64|arm64>        服务器架构 (默认: x64)
#   -o, --output <dir>            输出目录 (默认: ./vscode-offline-bundle)
#   -v, --version <ver>           指定 VSCode 版本 (如 1.98.2)，不指定则自动检测
#   -c, --commit <id>             直接指定 Commit ID (优先级最高)
#   -e, --extensions <list>       额外扩展，逗号分隔 (如 "ms-python.python,ms-vscode.go")
#   --no-code-server              不下载 code-server
#   --no-openvscode-server        不下载 openvscode-server
#   --no-server                   不下载 VSCode Server (仅下载扩展)
#   --proxy <url>                 设置 HTTP 代理 (如 http://127.0.0.1:7890)
#   -h, --help                    显示帮助
#
# 配置文件优先级：CLI 参数 > 配置文件 > 内置默认值
#
# 输出结构：
#   vscode-offline-bundle/
#   ├── vscode-server/             VSCode Server 离线包
#   ├── extensions/                VSCode 扩展 (.vsix)
#   ├── code-server/               code-server 离线包 (可选)
#   ├── openvscode-server/         openvscode-server 离线包 (可选)
#   └── deploy-server.sh           服务器端部署脚本 (自动生成)
#
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ======================== 默认配置 ========================
ARCH="x64"
OUTPUT_DIR="./vscode-offline-bundle"
VSCODE_VERSION=""
COMMIT_ID=""
EXTRA_EXTENSIONS=""
DOWNLOAD_CODE_SERVER=true
DOWNLOAD_OPENVSCODE_SERVER=true
DOWNLOAD_VSCODE_SERVER=true
PROXY=""
CODE_SERVER_VERSION=""
OPENVSCODE_SERVER_VERSION=""

UPDATE_BASE="https://update.code.visualstudio.com"
DOWNLOAD_BASE="https://vscode.download.prss.microsoft.com/dbazure/download/stable"

# 默认扩展列表 (会被配置文件覆盖)
DEFAULT_EXTENSIONS=()

# ======================== 配置文件解析 ========================
CONFIG_FILE=""

load_config() {
    local conf="$1"
    [[ ! -f "$conf" ]] && return 1

    log_info "加载配置: ${conf}"

    local in_extensions=false
    local ext_lines=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 去除首尾空白
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 跳过空行和注释
        [[ -z "$line" || "$line" == \#* ]] && continue

        # heredoc 模式：收集扩展列表
        if $in_extensions; then
            if [[ "$line" == "EOF" ]]; then
                in_extensions=false
                continue
            fi
            ext_lines="${ext_lines}${line}"$'\n'
            continue
        fi

        # 检测 heredoc 开始
        if [[ "$line" == extensions*"<< EOF" ]]; then
            in_extensions=true
            continue
        fi

        # 解析 key = value
        if [[ "$line" =~ ^[a-z_]+[[:space:]]*= ]]; then
            local key
            key=$(echo "$line" | sed 's/[[:space:]]*=.*//' | tr -d '[:space:]')
            local val
            val=$(echo "$line" | sed 's/[^=]*=[[:space:]]*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            case "$key" in
                arch)                      [[ -n "$val" ]] && ARCH="$val" ;;
                output)                    [[ -n "$val" ]] && OUTPUT_DIR="$val" ;;
                vscode_version)            [[ -n "$val" ]] && VSCODE_VERSION="$val" ;;
                commit_id)                 [[ -n "$val" ]] && COMMIT_ID="$val" ;;
                code_server_version)       [[ -n "$val" ]] && CODE_SERVER_VERSION="$val" ;;
                openvscode_server_version) [[ -n "$val" ]] && OPENVSCODE_SERVER_VERSION="$val" ;;
                download_vscode_server)    DOWNLOAD_VSCODE_SERVER=$(to_bool "$val") ;;
                download_code_server)      DOWNLOAD_CODE_SERVER=$(to_bool "$val") ;;
                download_openvscode_server) DOWNLOAD_OPENVSCODE_SERVER=$(to_bool "$val") ;;
                proxy)                     PROXY="$val" ;;
            esac
        fi
    done < "$conf"

    # 处理收集到的扩展列表
    if [[ -n "$ext_lines" ]]; then
        while IFS= read -r ext; do
            ext=$(echo "$ext" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$ext" && "$ext" != \#* ]] && DEFAULT_EXTENSIONS+=("$ext")
        done <<< "$ext_lines"
    fi

    log_info "✓ 配置加载完成"
}

# 字符串转布尔值
to_bool() {
    local v
    v=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$v" in
        true|yes|1|on) echo "true" ;;
        false|no|0|off) echo "false" ;;
        *) echo "$1" ;;
    esac
}

# 查找默认配置文件
find_default_config() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    # 按优先级查找
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
    local opts=(-fSL --connect-timeout 30 --max-time 600)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    while [ $retry -lt $retries ]; do
        log_info "下载: $(basename "$output")"
        if curl "${opts[@]}" -o "$output" "$url"; then
            log_info "  ✓ $(du -h "$output" | cut -f1)"
            return 0
        fi
        retry=$((retry + 1))
        log_warn "  ✗ 重试 ${retry}/${retries}..."
        sleep 3
    done
    log_error "下载失败: $url"
    return 1
}

check_deps() {
    log_step "检查依赖"
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "缺少 $cmd，请先安装: brew install $cmd"
            exit 1
        fi
    done
    log_info "✓ 依赖就绪"
}

# ======================== 检测 VSCode ========================
detect_vscode() {
    log_step "检测本地 VSCode"

    [[ -n "$COMMIT_ID" ]] && { log_info "使用指定 Commit: ${COMMIT_ID:0:12}..."; return 0; }

    if [[ -n "$VSCODE_VERSION" ]]; then
        log_info "查询版本 ${VSCODE_VERSION} 对应的 Commit ID..."
        local opts=(-s --connect-timeout 15)
        [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")
        COMMIT_ID=$(curl "${opts[@]}" "https://update.code.visualstudio.com/api/releases/stable/${VSCODE_VERSION}" 2>/dev/null | jq -r '.commit // empty')
        [[ -z "$COMMIT_ID" ]] && { log_error "无法获取 Commit ID"; exit 1; }
        log_info "✓ ${VSCODE_VERSION} → ${COMMIT_ID:0:12}..."
        return 0
    fi

    # macOS 自动检测
    local pjson="/Applications/Visual Studio Code.app/Contents/Resources/app/product.json"
    if [[ -f "$pjson" ]]; then
        VSCODE_VERSION=$(jq -r '.version' "$pjson")
        COMMIT_ID=$(jq -r '.commit' "$pjson")
        log_info "✓ VSCode ${VSCODE_VERSION} → ${COMMIT_ID:0:12}..."
        return 0
    fi

    # 尝试 code --version
    local cv; cv=$(code --version 2>/dev/null || true)
    if [[ -n "$cv" ]]; then
        VSCODE_VERSION=$(echo "$cv" | head -1 | awk '{print $2}')
        COMMIT_ID=$(echo "$cv" | head -1 | awk '{print $3}')
        [[ -n "$COMMIT_ID" ]] && { log_info "✓ VSCode ${VSCODE_VERSION} → ${COMMIT_ID:0:12}..."; return 0; }
    fi

    log_error "无法检测 VSCode，请用 --version 或 --commit 指定"
    exit 1
}

# ======================== 下载 VSCode Server ========================
download_vscode_server() {
    [[ "$DOWNLOAD_VSCODE_SERVER" != true ]] && return 0
    log_step "下载 VSCode Server (${COMMIT_ID:0:12}...)"

    local dir="$OUTPUT_DIR/vscode-server"; mkdir -p "$dir"
    local asuf="x64"; [[ "$ARCH" == "arm64" ]] && asuf="arm64"

    # Server 包
    local sf="$dir/vscode-server-linux-${asuf}.tar.gz"
    if [[ ! -f "$sf" ]]; then
        download_file "${UPDATE_BASE}/commit:${COMMIT_ID}/server-linux-${asuf}/stable" "$sf" || \
            download_file "${DOWNLOAD_BASE}/${COMMIT_ID}/vscode-server-linux-${asuf}.tar.gz" "$sf"
    else
        log_info "Server 包已存在，跳过"
    fi

    # CLI 包
    local cf="$dir/vscode-cli-linux-${asuf}.tar.gz"
    if [[ ! -f "$cf" ]]; then
        download_file "${UPDATE_BASE}/commit:${COMMIT_ID}/cli-alpine-${asuf}/stable" "$cf" || \
            download_file "${DOWNLOAD_BASE}/${COMMIT_ID}/vscode_cli_alpine_${asuf}_cli.tar.gz" "$cf"
    else
        log_info "CLI 包已存在，跳过"
    fi

    echo "$COMMIT_ID" > "$dir/commit-id.txt"
    echo "$VSCODE_VERSION" > "$dir/vscode-version.txt"
}

# ======================== 下载扩展 ========================
# 扩展版本缓存文件 (兼容 bash 3.x)
EXT_CACHE_FILE=""

ext_cache_init() {
    EXT_CACHE_FILE=$(mktemp /tmp/vscode-ext-cache.XXXXXX)
    trap "rm -f '$EXT_CACHE_FILE'" EXIT
}

ext_cache_get() {
    local ext="$1"
    [[ -f "$EXT_CACHE_FILE" ]] && grep "^${ext}=" "$EXT_CACHE_FILE" 2>/dev/null | cut -d= -f2
}

ext_cache_set() {
    local ext="$1" ver="$2"
    echo "${ext}=${ver}" >> "$EXT_CACHE_FILE"
}

get_ext_version() {
    local ext="$1"
    # 命中缓存
    local cached; cached=$(ext_cache_get "$ext")
    [[ -n "$cached" ]] && echo "$cached" && return 0

    local opts=(-s --connect-timeout 30 --max-time 60 --retry 2 --retry-delay 3)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    local response
    response=$(curl "${opts[@]}" -X POST \
        "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=6.1-preview.1" \
        -d "{\"filters\":[{\"criteria\":[{\"filterType\":7,\"value\":\"${ext}\"}],\"pageSize\":1}],\"flags\":914}" \
        2>/dev/null) || response=""

    local ver
    ver=$(echo "$response" | jq -r '.results[0].extensions[0].versions[0].version // empty' 2>/dev/null)

    if [[ -z "$ver" ]]; then
        return 1
    fi

    ext_cache_set "$ext" "$ver"
    echo "$ver"
}

download_ext() {
    local ext="$1"
    local dir="$OUTPUT_DIR/extensions"
    mkdir -p "$dir"

    local ver
    ver=$(get_ext_version "$ext") || {
        log_warn "跳过 ${ext}：无法获取版本 (网络超时?)"
        return 1
    }

    local safe="${ext//./-}"
    local file="${dir}/${safe}-${ver}.vsix"
    if [[ -f "$file" ]]; then
        log_info "已存在: ${ext}@${ver}"
        return 0
    fi

    local pub="${ext%%.*}"
    local name="${ext#*.}"
    # 方案1: 直接下载 VSIX
    local url="https://${pub}.gallery.vsassets.io/_apis/public/gallery/publisher/${pub}/extension/${name}/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
    if ! download_file "$url" "$file"; then
        # 方案2: 通过 marketplace API URL (带版本号)
        url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${pub}/vsextensions/${name}/${ver}/vspackage"
        download_file "$url" "$file"
    fi
}

download_extensions() {
    log_step "下载 VSCode 扩展"

    local all=("${DEFAULT_EXTENSIONS[@]}")
    if [[ -n "$EXTRA_EXTENSIONS" ]]; then
        IFS=',' read -ra extra <<< "$EXTRA_EXTENSIONS"
        for e in "${extra[@]}"; do e=$(echo "$e" | xargs); [[ -n "$e" ]] && all+=("$e"); done
    fi

    local ok=0 fail=0
    log_info "共 ${#all[@]} 个扩展"
    for ext in "${all[@]}"; do
        if download_ext "$ext"; then ok=$((ok+1)); else fail=$((fail+1)); fi
    done
    echo ""; log_info "扩展: ✓ ${ok} 成功 / ✗ ${fail} 失败"
}

# ======================== 下载 code-server ========================
download_code_server() {
    [[ "$DOWNLOAD_CODE_SERVER" != true ]] && return 0
    log_step "下载 code-server"

    local dir="$OUTPUT_DIR/code-server"; mkdir -p "$dir"
    local opts=(-s --connect-timeout 15)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    local ver="$CODE_SERVER_VERSION"
    local api_url="https://api.github.com/repos/coder/code-server/releases/latest"

    # 如果指定了版本，查询该版本的 release 信息
    if [[ -n "$ver" ]]; then
        api_url="https://api.github.com/repos/coder/code-server/releases/tags/v${ver}"
        log_info "指定版本: ${ver}"
    fi

    local info; info=$(curl "${opts[@]}" "$api_url" 2>/dev/null || echo "")
    [[ -z "$info" ]] && { log_warn "无法获取版本信息，跳过"; return 0; }

    # 未指定版本时，从 API 获取最新版本
    if [[ -z "$CODE_SERVER_VERSION" ]]; then
        ver=$(echo "$info" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')
    fi
    [[ -z "$ver" ]] && { log_warn "解析版本失败，跳过"; return 0; }
    ver=$(echo "$ver" | sed 's/^v//')  # 确保去掉 v 前缀
    log_info "版本: ${ver}"

    local ca="amd64"; [[ "$ARCH" == "arm64" ]] && ca="arm64"
    local f="$dir/code-server-${ver}-linux-${ca}.tar.gz"
    [[ -f "$f" ]] && { log_info "已存在，跳过"; return 0; }

    download_file "https://github.com/coder/code-server/releases/download/v${ver}/code-server-${ver}-linux-${ca}.tar.gz" "$f"
    echo "$ver" > "$dir/version.txt"
}

# ======================== 下载 openvscode-server ========================
download_openvscode_server() {
    [[ "$DOWNLOAD_OPENVSCODE_SERVER" != true ]] && return 0
    log_step "下载 openvscode-server"

    local dir="$OUTPUT_DIR/openvscode-server"; mkdir -p "$dir"
    local opts=(-s --connect-timeout 15)
    [[ -n "$PROXY" ]] && opts+=(--proxy "$PROXY")

    local ver="$OPENVSCODE_SERVER_VERSION"
    local api_url="https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest"

    if [[ -n "$ver" ]]; then
        api_url="https://api.github.com/repos/gitpod-io/openvscode-server/releases/tags/openvscode-server-v${ver}"
        log_info "指定版本: ${ver}"
    fi

    local info; info=$(curl "${opts[@]}" "$api_url" 2>/dev/null || echo "")
    [[ -z "$info" ]] && { log_warn "无法获取版本信息，跳过"; return 0; }

    if [[ -z "$OPENVSCODE_SERVER_VERSION" ]]; then
        ver=$(echo "$info" | jq -r '.tag_name' 2>/dev/null | sed 's/^openvscode-server-//')
    fi
    [[ -z "$ver" ]] && { log_warn "解析版本失败，跳过"; return 0; }
    ver=$(echo "$ver" | sed 's/^openvscode-server-//')  # 确保去掉前缀
    log_info "版本: ${ver}"

    local ap="x64"; [[ "$ARCH" == "arm64" ]] && ap="arm64"
    local url
    url=$(echo "$info" | jq -r --arg a "$ap" '.assets[] | select(.name | test("linux-" + $a + "\\.tar\\.gz$")) | .browser_download_url' 2>/dev/null | head -1)
    [[ -z "$url" ]] && { log_warn "未找到匹配包，跳过"; return 0; }

    local f="$dir/openvscode-server-${ver}-linux-${ap}.tar.gz"
    [[ -f "$f" ]] && { log_info "已存在，跳过"; return 0; }
    download_file "$url" "$f"
    echo "$ver" > "$dir/version.txt"
}

# ======================== 生成部署脚本 ========================
generate_deploy_script() {
    log_step "生成服务器端部署脚本"

    cat > "$OUTPUT_DIR/deploy-server.sh" << 'EOF'
#!/usr/bin/env bash
# VSCode Server 服务器端离线部署脚本
# 用法: ./deploy-server.sh [--install-extensions] [--user <user>]
set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${CYAN}  $1${NC}\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_EXT=false; TARGET_USER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-extensions) INSTALL_EXT=true; shift ;;
        --user) TARGET_USER="$2"; shift 2 ;;
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

[[ "$(id -u)" -ne 0 && -n "$TARGET_USER" ]] && { log_error "需 root 权限"; exit 1; }

get_home() { [[ -n "$TARGET_USER" ]] && eval echo "~$TARGET_USER" || echo "$HOME"; }

# ---- 部署 VSCode Server ----
deploy_server() {
    log_step "部署 VSCode Server"
    local sd="$SCRIPT_DIR/vscode-server"
    [[ ! -d "$sd" ]] && { log_warn "未找到 vscode-server 目录"; return 0; }

    local commit; commit=$(cat "$sd/commit-id.txt" 2>/dev/null)
    [[ -z "$commit" ]] && { log_error "无法读取 commit-id"; return 1; }

    local home; home=$(get_home)
    local vd="$home/.vscode-server"
    local arch="x64"; [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]] && arch="arm64"

    log_info "Commit: ${commit:0:12}...  Home: $home"

    local st="$sd/vscode-server-linux-${arch}.tar.gz"
    if [[ -f "$st" ]]; then
        log_info "解压 Server..."
        # 新版目录
        mkdir -p "$vd/cli/servers/Stable-${commit}/server"
        tar -xzf "$st" --strip-components=1 -C "$vd/cli/servers/Stable-${commit}/server"
        # 兼容旧版
        mkdir -p "$vd/bin/${commit}"
        tar -xzf "$st" --strip-components=1 -C "$vd/bin/${commit}"
        touch "$vd/bin/${commit}/0"
        log_info "✓ Server 完成"
    else
        log_error "未找到: $st"; return 1
    fi

    local ct="$sd/vscode-cli-linux-${arch}.tar.gz"
    if [[ -f "$ct" ]]; then
        log_info "部署 CLI..."
        cp "$ct" "$vd/vscode-cli-${commit}.tar.gz"
        touch "$vd/vscode-cli-${commit}.tar.gz.done"
        log_info "✓ CLI 完成"
    fi

    echo "[\"Stable-${commit}\"]" > "$vd/cli/lru.json" 2>/dev/null || true
    rm -f "$vd/bin/${commit}"/vscode-remote-lock.* 2>/dev/null || true
    [[ -n "$TARGET_USER" ]] && chown -R "$TARGET_USER:$TARGET_USER" "$vd"

    local ver; ver=$(cat "$sd/vscode-version.txt" 2>/dev/null || echo "?")
    log_info "✅ VSCode Server v${ver} 部署完成！"
    log_info "在 VSCode 设置: \"remote.SSH.localServerDownload\": \"always\""
}

# ---- 安装扩展 ----
install_extensions() {
    log_step "安装扩展"
    local ed="$SCRIPT_DIR/extensions"
    local vsix_files=("$ed"/*.vsix)
    [[ "${#vsix_files[@]}" -eq 0 || ! -f "${vsix_files[0]}" ]] && { log_warn "无 .vsix 文件"; return 0; }

    local home; home=$(get_home)
    local commit; commit=$(cat "$SCRIPT_DIR/vscode-server/commit-id.txt" 2>/dev/null || echo "")
    local code_bin=""
    [[ -n "$commit" ]] && {
        for p in "$home/.vscode-server/cli/servers/Stable-${commit}/server/bin/code-server" \
                 "$home/.vscode-server/bin/${commit}/bin/code-server"; do
            [[ -x "$p" ]] && { code_bin="$p"; break; }
        done
    }

    local ok=0 fail=0
    for vsix in "$ed"/*.vsix; do
        [[ -f "$vsix" ]] || continue
        if [[ -n "$code_bin" ]]; then
            if "$code_bin" --install-extension "$vsix" --force 2>/dev/null; then
                log_info "✓ $(basename "$vsix")"; ok=$((ok+1))
            else
                log_warn "✗ $(basename "$vsix")"; fail=$((fail+1))
            fi
        else
            log_warn "需手动安装: $(basename "$vsix")"; fail=$((fail+1))
        fi
    done
    log_info "扩展: ✓ ${ok} / ✗ ${fail}"
}

# ---- 部署 code-server ----
deploy_code_server() {
    local cd="$SCRIPT_DIR/code-server"
    [[ ! -d "$cd" ]] && return 0
    log_step "部署 code-server"
    local t=$(ls "$cd"/code-server-*.tar.gz 2>/dev/null | head -1)
    [[ -z "$t" ]] && { log_warn "无安装包"; return 0; }
    local d="/opt/code-server"
    mkdir -p "$d" && tar -xzf "$t" -C "$d" --strip-components=1
    ln -sf "$d/bin/code-server" /usr/local/bin/code-server 2>/dev/null || true
    log_info "✅ code-server → ${d}"
    log_info "启动: code-server --auth password --bind-addr 0.0.0.0:8080"
}

# ---- 部署 openvscode-server ----
deploy_openvscode() {
    local od="$SCRIPT_DIR/openvscode-server"
    [[ ! -d "$od" ]] && return 0
    log_step "部署 openvscode-server"
    local t=$(ls "$od"/openvscode-server-*.tar.gz 2>/dev/null | head -1)
    [[ -z "$t" ]] && { log_warn "无安装包"; return 0; }
    local d="/opt/openvscode-server"
    mkdir -p "$d" && tar -xzf "$t" -C "$d" --strip-components=1
    ln -sf "$d/bin/openvscode-server" /usr/local/bin/openvscode-server 2>/dev/null || true
    log_info "✅ openvscode-server → ${d}"
    log_info "启动: openvscode-server --port 8080 --connection-token my-secret"
}

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  VSCode 离线资源 服务器端部署工具     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
deploy_server
deploy_code_server
deploy_openvscode
[[ "$INSTALL_EXT" == true ]] && install_extensions
echo -e "\n${GREEN}🎉 全部部署完成！${NC}"
EOF

    chmod +x "$OUTPUT_DIR/deploy-server.sh"
    log_info "✓ deploy-server.sh 已生成"
}

# ======================== 生成 bundle 信息 ========================
generate_bundle_info() {
    log_step "生成打包信息"

    local total_size
    total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)

    cat > "$OUTPUT_DIR/bundle-info.json" << EOF
{
    "created_at": "$(date -Iseconds)",
    "vscode_version": "${VSCODE_VERSION}",
    "commit_id": "${COMMIT_ID}",
    "server_arch": "${ARCH}",
    "total_size": "${total_size}",
    "files": {
        "vscode_server": $(ls "$OUTPUT_DIR/vscode-server/"*.tar.gz 2>/dev/null | wc -l | tr -d ' '),
        "extensions": $(ls "$OUTPUT_DIR/extensions/"*.vsix 2>/dev/null | wc -l | tr -d ' ')
    }
}
EOF

    log_info "✓ bundle-info.json 已生成"
}

# ======================== 用法帮助 ========================
show_help() {
    cat << 'HELP'
用法: ./download.sh [选项]

在有网络的机器上运行，下载 VSCode 远程开发所需的全部离线资源。

选项:
  --config <file>               配置文件路径 (默认: 同目录下 config.conf)
  -a, --arch <x64|arm64>        服务器架构 (默认: x64)
  -o, --output <dir>            输出目录 (默认: ./vscode-offline-bundle)
  -v, --version <ver>           指定 VSCode 版本 (如 1.98.2)
  -c, --commit <id>             直接指定 Commit ID (优先级最高)
  -e, --extensions <list>       额外扩展，逗号分隔
  --no-code-server              不下载 code-server
  --no-openvscode-server        不下载 openvscode-server
  --no-server                   不下载 VSCode Server
  --proxy <url>                 HTTP 代理
  -h, --help                    显示帮助

优先级: CLI 参数 > 配置文件 > 内置默认值

示例:
  # 自动检测本地 VSCode 版本，下载全部资源
  ./download.sh

  # 使用配置文件
  ./download.sh --config config.conf

  # 指定版本 + 架构
  ./download.sh -v 1.98.2 -a arm64

  # 仅下载 VSCode Server + 扩展
  ./download.sh --no-code-server --no-openvscode-server

  # 添加额外扩展
  ./download.sh -e "ms-vscode.go,golang.go"

  # 使用代理
  ./download.sh --proxy http://127.0.0.1:7890

下载完成后，将整个输出目录传输到内网服务器，然后运行:
  cd vscode-offline-bundle
  chmod +x deploy-server.sh
  sudo ./deploy-server.sh --install-extensions
HELP
}

# ======================== 参数解析 ========================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--arch)       ARCH="$2"; shift 2 ;;
            -o|--output)     OUTPUT_DIR="$2"; shift 2 ;;
            -v|--version)    VSCODE_VERSION="$2"; shift 2 ;;
            -c|--commit)     COMMIT_ID="$2"; shift 2 ;;
            --config)       CONFIG_FILE="$2"; shift 2 ;;
            -e|--extensions) EXTRA_EXTENSIONS="$2"; shift 2 ;;
            --no-code-server)       DOWNLOAD_CODE_SERVER=false; shift ;;
            --no-openvscode-server) DOWNLOAD_OPENVSCODE_SERVER=false; shift ;;
            --no-server)            DOWNLOAD_VSCODE_SERVER=false; shift ;;
            --proxy)        PROXY="$2"; shift 2 ;;
            -h|--help)      show_help; exit 0 ;;
            *) log_error "未知参数: $1"; show_help; exit 1 ;;
        esac
    done
}

# ======================== 主流程 ========================
main() {
    parse_args "$@"

    # 加载配置文件 (CLI 参数优先级更高，所以先加载配置，CLI 参数会覆盖)
    if [[ -n "$CONFIG_FILE" ]]; then
        load_config "$CONFIG_FILE" || { log_error "无法加载配置文件: $CONFIG_FILE"; exit 1; }
    else
        local default_conf
        default_conf=$(find_default_config) && load_config "$default_conf"
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    VSCode 离线资源 一键下载工具                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    check_deps
    detect_vscode
    ext_cache_init

    mkdir -p "$OUTPUT_DIR"/{vscode-server,extensions,code-server,openvscode-server}

    download_vscode_server
    download_extensions
    download_code_server
    download_openvscode_server
    generate_deploy_script
    generate_bundle_info

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ 全部下载完成！${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""
    local size; size=$(du -sh "$OUTPUT_DIR" | cut -f1)
    local exts; exts=$(ls "$OUTPUT_DIR/extensions/"*.vsix 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  📁 输出目录: ${CYAN}$(cd "$OUTPUT_DIR" && pwd)${NC}"
    echo -e "  📦 总大小:   ${CYAN}${size}${NC}"
    echo -e "  🔌 扩展数量: ${CYAN}${exts}${NC}"
    echo -e "  🏷️  VSCode:   ${CYAN}${VSCODE_VERSION} (${COMMIT_ID:0:12}...)${NC}"
    echo ""
    echo -e "  ${YELLOW}下一步:${NC}"
    echo -e "    1. 将 ${CYAN}${OUTPUT_DIR}${NC} 整个目录传到内网服务器"
    echo -e "    2. 在服务器上运行: ${CYAN}sudo ./deploy-server.sh --install-extensions${NC}"
    echo ""
}

main "$@"
