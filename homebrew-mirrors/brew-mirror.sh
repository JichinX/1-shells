#!/usr/bin/env bash
# ============================================================
# Homebrew 国内镜像源一键替换脚本
# 参考: https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
# 支持: USTC / 清华(TUNA) / 阿里云 / 腾讯云
# 兼容: Intel & Apple Silicon Mac, bash 3.2+
# ============================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ---------- 镜像源配置（bash 3.2 兼容：用函数替代关联数组） ----------
# 返回格式: api_domain|bottle_domain|brew_git|core_git|cask_git

_get_mirror_ustc() {
    echo "https://mirrors.ustc.edu.cn/homebrew-bottles/api|https://mirrors.ustc.edu.cn/homebrew-bottles|https://mirrors.ustc.edu.cn/brew.git|https://mirrors.ustc.edu.cn/homebrew-core.git|https://mirrors.ustc.edu.cn/homebrew-cask.git"
}
_get_mirror_tuna() {
    echo "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api|https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles|https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git|https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git|https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git"
}
_get_mirror_aliyun() {
    echo "https://mirrors.aliyun.com/homebrew/homebrew-bottles/api|https://mirrors.aliyun.com/homebrew/homebrew-bottles|https://mirrors.aliyun.com/homebrew/brew.git|https://mirrors.aliyun.com/homebrew/homebrew-core.git|https://mirrors.aliyun.com/homebrew/homebrew-cask.git"
}
_get_mirror_tencent() {
    echo "https://mirrors.cloud.tencent.com/homebrew-bottles/api|https://mirrors.cloud.tencent.com/homebrew-bottles|https://mirrors.cloud.tencent.com/homebrew/brew.git|https://mirrors.cloud.tencent.com/homebrew/homebrew-core.git|https://mirrors.cloud.tencent.com/homebrew/homebrew-cask.git"
}

get_mirror_config() {
    case "$1" in
        1) _get_mirror_ustc ;;
        2) _get_mirror_tuna ;;
        3) _get_mirror_aliyun ;;
        4) _get_mirror_tencent ;;
        *) echo "" ;;
    esac
}

get_mirror_name() {
    case "$1" in
        1) echo "USTC (中科大)" ;;
        2) echo "TUNA (清华大学)" ;;
        3) echo "ALIYUN (阿里云)" ;;
        4) echo "TENCENT (腾讯云)" ;;
        *) echo "unknown" ;;
    esac
}

get_mirror_desc() {
    case "$1" in
        1) echo "老牌镜像, 稳定可靠, 教育网速度快" ;;
        2) echo "更新及时, 社区活跃, 教育网速度快" ;;
        3) echo "商业镜像, 大带宽, 电信联通速度快" ;;
        4) echo "商业镜像, 多线 BGP, 南方用户友好" ;;
        *) echo "" ;;
    esac
}

# ---------- Shell 配置文件 ----------
SHELL_CONFIG_FILE=""

detect_shell_config() {
    local shell_name
    shell_name="$(basename "${SHELL}")"

    case "${shell_name}" in
        zsh)  SHELL_CONFIG_FILE="${HOME}/.zshrc" ;;
        bash)
            if [[ -f "${HOME}/.bash_profile" ]]; then
                SHELL_CONFIG_FILE="${HOME}/.bash_profile"
            else
                SHELL_CONFIG_FILE="${HOME}/.bashrc"
            fi
            ;;
        fish) SHELL_CONFIG_FILE="${HOME}/.config/fish/config.fish" ;;
        *)    SHELL_CONFIG_FILE="${HOME}/.profile" ;;
    esac
}

# ---------- 辅助函数 ----------
print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Homebrew 国内镜像源一键替换工具 v2.0       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

confirm() {
    local prompt="$1"
    local answer
    echo -ne "${YELLOW}${prompt} (y/N): ${NC}"
    read -r answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

# ---------- 环境检查 ----------
check_prerequisites() {
    info "检查运行环境..."

    if [[ "$(uname)" != "Darwin" ]]; then
        error "本脚本仅支持 macOS 系统"
        exit 1
    fi
    success "操作系统: macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"

    if ! command -v brew &>/dev/null; then
        error "未检测到 Homebrew，请先安装: https://brew.sh"
        exit 1
    fi
    success "Homebrew 已安装: $(brew --prefix)"

    local arch
    arch="$(uname -m)"
    if [[ "${arch}" == "arm64" ]]; then
        success "芯片架构: Apple Silicon (arm64)"
    else
        success "芯片架构: Intel (x86_64)"
    fi

    # 检测 Homebrew 版本
    local brew_version
    brew_version="$(brew --version | head -1 | grep -oE '[0-9]+\.[0-9]+')" || true
    if [[ -n "${brew_version}" ]]; then
        info "Homebrew 版本: ${brew_version}"
    fi

    echo ""
}

# ---------- 备份当前配置 ----------
backup_config() {
    local backup_dir="${HOME}/.homebrew-mirror-backup"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    info "备份当前配置..."

    mkdir -p "${backup_dir}"

    if [[ -f "${SHELL_CONFIG_FILE}" ]]; then
        cp "${SHELL_CONFIG_FILE}" "${backup_dir}/shell_config_${timestamp}.bak"
        success "Shell 配置已备份"
    fi

    # 备份 brew git remote
    local brew_repo
    brew_repo="$(brew --repository)"
    local current_remote
    current_remote="$(git -C "${brew_repo}" remote get-url origin 2>/dev/null || echo '')"
    if [[ -n "${current_remote}" ]]; then
        echo "${current_remote}" > "${backup_dir}/brew_remote_${timestamp}.bak"
        success "brew remote 已备份"
    fi

    # 备份 tap 信息
    for tap_name in homebrew/core homebrew/cask; do
        local tap_repo="${brew_repo}/Library/Taps/homebrew/${tap_name}"
        if [[ -d "${tap_repo}" ]]; then
            local tap_remote
            tap_remote="$(git -C "${tap_repo}" remote get-url origin 2>/dev/null || echo '')"
            if [[ -n "${tap_remote}" ]]; then
                local safe_name
                safe_name="$(echo "${tap_name}" | tr '/' '_')"
                echo "${tap_remote}" > "${backup_dir}/tap_${safe_name}_${timestamp}.bak"
                success "${tap_name} remote 已备份"
            fi
        fi
    done

    # 备份当前环境变量
    {
        echo "HOMEBREW_API_DOMAIN=${HOMEBREW_API_DOMAIN:-}"
        echo "HOMEBREW_BOTTLE_DOMAIN=${HOMEBREW_BOTTLE_DOMAIN:-}"
        echo "HOMEBREW_BREW_GIT_REMOTE=${HOMEBREW_BREW_GIT_REMOTE:-}"
        echo "HOMEBREW_CORE_GIT_REMOTE=${HOMEBREW_CORE_GIT_REMOTE:-}"
        echo "HOMEBREW_INSTALL_FROM_API=${HOMEBREW_INSTALL_FROM_API:-}"
    } > "${backup_dir}/env_vars_${timestamp}.bak"
    success "环境变量已备份"

    echo ""
}

# ---------- 获取当前镜像信息 ----------
get_current_mirror() {
    echo -e "${BOLD}当前配置:${NC}"
    echo "─────────────────────────────────────────"

    # git remote 信息
    local brew_repo
    brew_repo="$(brew --repository)"
    local brew_remote
    brew_remote="$(git -C "${brew_repo}" remote get-url origin 2>/dev/null || echo '未设置')"
    echo -e "  brew origin:             ${CYAN}${brew_remote}${NC}"

    for tap_name in homebrew/core homebrew/cask; do
        local tap_repo="${brew_repo}/Library/Taps/homebrew/${tap_name}"
        if [[ -d "${tap_repo}" ]]; then
            local tap_remote
            tap_remote="$(git -C "${tap_repo}" remote get-url origin 2>/dev/null || echo '未设置')"
            echo -e "  ${tap_name}:            ${CYAN}${tap_remote}${NC}"
        else
            echo -e "  ${tap_name}:            ${YELLOW}未安装 (API 模式)${NC}"
        fi
    done

    # 环境变量
    echo ""
    echo -e "  HOMEBREW_API_DOMAIN:        ${CYAN}${HOMEBREW_API_DOMAIN:-未设置}${NC}"
    echo -e "  HOMEBREW_BOTTLE_DOMAIN:     ${CYAN}${HOMEBREW_BOTTLE_DOMAIN:-未设置}${NC}"
    echo -e "  HOMEBREW_BREW_GIT_REMOTE:   ${CYAN}${HOMEBREW_BREW_GIT_REMOTE:-未设置}${NC}"
    echo -e "  HOMEBREW_CORE_GIT_REMOTE:   ${CYAN}${HOMEBREW_CORE_GIT_REMOTE:-未设置}${NC}"
    echo -e "  HOMEBREW_INSTALL_FROM_API:  ${CYAN}${HOMEBREW_INSTALL_FROM_API:-未设置}${NC}"
    echo ""
}

# ---------- 显示镜像源选择菜单 ----------
select_mirror() {
    echo -e "${BOLD}请选择镜像源:${NC}"
    echo "─────────────────────────────────────────"
    local i=1
    while [ ${i} -le 4 ]; do
        local name desc
        name="$(get_mirror_name ${i})"
        desc="$(get_mirror_desc ${i})"
        echo -e "  ${GREEN}${i}) ${name}${NC}  —  ${desc}"
        i=$((i + 1))
    done
    echo -e "  ${RED}0) 恢复官方源${NC}"
    echo ""
    echo -ne "${BOLD}请输入选项 [0-4]: ${NC}"
}

# ---------- 解析配置 ----------
parse_config() {
    local config_str="$1"
    MIRROR_API_DOMAIN="$(echo "${config_str}" | cut -d'|' -f1)"
    MIRROR_BOTTLE_DOMAIN="$(echo "${config_str}" | cut -d'|' -f2)"
    MIRROR_BREW_GIT="$(echo "${config_str}" | cut -d'|' -f3)"
    MIRROR_CORE_GIT="$(echo "${config_str}" | cut -d'|' -f4)"
    MIRROR_CASK_GIT="$(echo "${config_str}" | cut -d'|' -f5)"
}

# ---------- 设置镜像源 ----------
apply_mirror() {
    local mirror_idx="$1"
    local mirror_name
    mirror_name="$(get_mirror_name ${mirror_idx})"

    info "正在切换到 ${mirror_name} 镜像源..."

    # 解析配置
    local config_str
    config_str="$(get_mirror_config ${mirror_idx})"
    parse_config "${config_str}"

    # 1. 写入 shell 环境变量
    update_shell_env

    # 2. 设置 brew tap remote（官方推荐方式）
    update_taps "${MIRROR_CORE_GIT}" "${MIRROR_CASK_GIT}"

    # 3. 设置 brew 自身 remote
    update_brew_remote "${MIRROR_BREW_GIT}"

    # 4. 使环境变量在当前会话生效
    export HOMEBREW_API_DOMAIN="${MIRROR_API_DOMAIN}"
    export HOMEBREW_BOTTLE_DOMAIN="${MIRROR_BOTTLE_DOMAIN}"
    export HOMEBREW_BREW_GIT_REMOTE="${MIRROR_BREW_GIT}"
    export HOMEBREW_CORE_GIT_REMOTE="${MIRROR_CORE_GIT}"
    export HOMEBREW_INSTALL_FROM_API=1

    echo ""
    success "已切换到 ${mirror_name} 镜像源!"
    info "请执行以下命令使配置生效:"
    echo -e "  ${CYAN}source ${SHELL_CONFIG_FILE}${NC}"
    echo ""
}

# ---------- 更新 Shell 环境变量 ----------
# 需要: MIRROR_API_DOMAIN, MIRROR_BOTTLE_DOMAIN, MIRROR_BREW_GIT, MIRROR_CORE_GIT (已由 parse_config 设置)

update_shell_env() {
    info "更新 shell 配置文件: ${SHELL_CONFIG_FILE}"

    if [[ "${SHELL_CONFIG_FILE}" == *fish* ]]; then
        _update_shell_env_fish
        return
    fi

    # 移除旧配置
    if [[ -f "${SHELL_CONFIG_FILE}" ]]; then
        sed -i '' '/^export HOMEBREW_API_DOMAIN=/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^export HOMEBREW_BOTTLE_DOMAIN=/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^export HOMEBREW_BREW_GIT_REMOTE=/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^export HOMEBREW_CORE_GIT_REMOTE=/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^export HOMEBREW_INSTALL_FROM_API=/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^# >>> Homebrew Mirror >>>/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^# <<< Homebrew Mirror <<</d' "${SHELL_CONFIG_FILE}"
    fi

    # 追加新配置
    cat >> "${SHELL_CONFIG_FILE}" << EOF

# >>> Homebrew Mirror >>>
export HOMEBREW_API_DOMAIN="${MIRROR_API_DOMAIN}"
export HOMEBREW_BOTTLE_DOMAIN="${MIRROR_BOTTLE_DOMAIN}"
export HOMEBREW_BREW_GIT_REMOTE="${MIRROR_BREW_GIT}"
export HOMEBREW_CORE_GIT_REMOTE="${MIRROR_CORE_GIT}"
export HOMEBREW_INSTALL_FROM_API=1
# <<< Homebrew Mirror <<<
EOF

    success "环境变量已写入 ${SHELL_CONFIG_FILE}"
}

_update_shell_env_fish() {
    if [[ -f "${SHELL_CONFIG_FILE}" ]]; then
        sed -i '' '/set -gx HOMEBREW_API_DOMAIN/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/set -gx HOMEBREW_BOTTLE_DOMAIN/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/set -gx HOMEBREW_BREW_GIT_REMOTE/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/set -gx HOMEBREW_CORE_GIT_REMOTE/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/set -gx HOMEBREW_INSTALL_FROM_API/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^# >>> Homebrew Mirror >>>/d' "${SHELL_CONFIG_FILE}"
        sed -i '' '/^# <<< Homebrew Mirror <<</d' "${SHELL_CONFIG_FILE}"
    fi

    mkdir -p "$(dirname "${SHELL_CONFIG_FILE}")"

    cat >> "${SHELL_CONFIG_FILE}" << EOF

# >>> Homebrew Mirror >>>
set -gx HOMEBREW_API_DOMAIN "${MIRROR_API_DOMAIN}"
set -gx HOMEBREW_BOTTLE_DOMAIN "${MIRROR_BOTTLE_DOMAIN}"
set -gx HOMEBREW_BREW_GIT_REMOTE "${MIRROR_BREW_GIT}"
set -gx HOMEBREW_CORE_GIT_REMOTE "${MIRROR_CORE_GIT}"
set -gx HOMEBREW_INSTALL_FROM_API 1
# <<< Homebrew Mirror <<<
EOF

    success "环境变量已写入 ${SHELL_CONFIG_FILE} (fish)"
}

# ---------- 设置 brew 自身 remote ----------
update_brew_remote() {
    local brew_remote="$1"
    local brew_repo
    brew_repo="$(brew --repository)"

    git -C "${brew_repo}" remote set-url origin "${brew_remote}" 2>/dev/null && \
        success "brew remote → ${brew_remote}" || \
        warn "无法更新 brew remote (可忽略)"
}

# ---------- 设置 tap remote (官方推荐 brew tap --custom-remote) ----------
update_taps() {
    local core_git="$1"
    local cask_git="$2"

    # homebrew-core
    brew tap --custom-remote homebrew/core "${core_git}" 2>/dev/null && \
        success "homebrew/core → ${core_git}" || \
        warn "无法设置 homebrew/core tap (brew >= 4.0 使用 API 模式可忽略)"

    # homebrew-cask (macOS only)
    if [[ "$(uname)" == "Darwin" ]]; then
        brew tap --custom-remote homebrew/cask "${cask_git}" 2>/dev/null && \
            success "homebrew/cask → ${cask_git}" || \
            warn "无法设置 homebrew/cask tap (可忽略)"
    fi
}

# ---------- 恢复官方源 ----------
restore_official() {
    info "正在恢复 Homebrew 官方源..."

    local official_brew="https://github.com/Homebrew/brew"
    local official_core="https://github.com/Homebrew/homebrew-core"
    local official_cask="https://github.com/Homebrew/homebrew-cask"

    # 1. 清除 shell 环境变量
    clear_shell_env

    # 2. 恢复 brew remote
    update_brew_remote "${official_brew}"

    # 3. 恢复 tap remote
    brew tap --custom-remote homebrew/core "${official_core}" 2>/dev/null || true
    brew tap --custom-remote homebrew/cask "${official_cask}" 2>/dev/null || true

    # 4. unset 当前会话
    unset HOMEBREW_API_DOMAIN
    unset HOMEBREW_BOTTLE_DOMAIN
    unset HOMEBREW_BREW_GIT_REMOTE
    unset HOMEBREW_CORE_GIT_REMOTE
    unset HOMEBREW_INSTALL_FROM_API

    echo ""
    success "已恢复 Homebrew 官方源!"
    info "建议执行: ${CYAN}brew update${NC}"
    info "然后执行: ${CYAN}source ${SHELL_CONFIG_FILE}${NC}"
    echo ""
}

# ---------- 清除 shell 环境变量 ----------
clear_shell_env() {
    if [[ "${SHELL_CONFIG_FILE}" == *fish* ]]; then
        if [[ -f "${SHELL_CONFIG_FILE}" ]]; then
            sed -i '' '/set -gx HOMEBREW_API_DOMAIN/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/set -gx HOMEBREW_BOTTLE_DOMAIN/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/set -gx HOMEBREW_BREW_GIT_REMOTE/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/set -gx HOMEBREW_CORE_GIT_REMOTE/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/set -gx HOMEBREW_INSTALL_FROM_API/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^# >>> Homebrew Mirror >>>/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^# <<< Homebrew Mirror <<</d' "${SHELL_CONFIG_FILE}"
        fi
    else
        if [[ -f "${SHELL_CONFIG_FILE}" ]]; then
            sed -i '' '/^export HOMEBREW_API_DOMAIN=/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^export HOMEBREW_BOTTLE_DOMAIN=/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^export HOMEBREW_BREW_GIT_REMOTE=/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^export HOMEBREW_CORE_GIT_REMOTE=/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^export HOMEBREW_INSTALL_FROM_API=/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^# >>> Homebrew Mirror >>>/d' "${SHELL_CONFIG_FILE}"
            sed -i '' '/^# <<< Homebrew Mirror <<</d' "${SHELL_CONFIG_FILE}"
        fi
    fi
    success "已清除 shell 配置中的镜像环境变量"
}

# ---------- 从备份恢复 ----------
restore_from_backup() {
    local backup_dir="${HOME}/.homebrew-mirror-backup"

    if [[ ! -d "${backup_dir}" ]] || [[ -z "$(ls -A "${backup_dir}" 2>/dev/null)" ]]; then
        error "未找到备份文件 (${backup_dir})"
        return 1
    fi

    info "找到以下备份:"
    echo "─────────────────────────────────────────"

    # 收集备份文件
    local backup_files=""
    for f in "${backup_dir}"/*.bak; do
        if [[ -f "${f}" ]]; then
            backup_files="${backup_files} ${f}"
        fi
    done

    local count=0
    for f in ${backup_files}; do
        count=$((count + 1))
        echo -e "  ${GREEN}${count})${NC} $(basename "${f}")"
    done
    echo ""

    if [[ ${count} -eq 0 ]]; then
        error "备份目录中没有找到备份文件"
        return 1
    fi

    echo -ne "${BOLD}请选择要恢复的备份 [1-${count}]: ${NC}"
    local choice
    read -r choice

    if ! [[ "${choice}" =~ ^[0-9]+$ ]] || [ "${choice}" -lt 1 ] || [ "${choice}" -gt "${count}" ]; then
        error "无效选择"
        return 1
    fi

    # 取第 N 个文件
    local selected=""
    local n=0
    for f in ${backup_files}; do
        n=$((n + 1))
        if [ "${n}" -eq "${choice}" ]; then
            selected="${f}"
            break
        fi
    done

    if [[ -z "${selected}" ]]; then
        error "选择失败"
        return 1
    fi

    local filename
    filename="$(basename "${selected}")"

    info "正在从 ${filename} 恢复..."

    if [[ "${filename}" == shell_config_* ]]; then
        cp "${selected}" "${SHELL_CONFIG_FILE}"
        success "Shell 配置已恢复"
    elif [[ "${filename}" == brew_remote_* ]]; then
        local remote_url
        remote_url="$(cat "${selected}")"
        local brew_repo
        brew_repo="$(brew --repository)"
        git -C "${brew_repo}" remote set-url origin "${remote_url}" 2>/dev/null
        success "brew remote 已恢复: ${remote_url}"
    elif [[ "${filename}" == tap_homebrew_core_* ]]; then
        local remote_url
        remote_url="$(cat "${selected}")"
        brew tap --custom-remote homebrew/core "${remote_url}" 2>/dev/null || true
        success "homebrew/core 已恢复: ${remote_url}"
    elif [[ "${filename}" == tap_homebrew_cask_* ]]; then
        local remote_url
        remote_url="$(cat "${selected}")"
        brew tap --custom-remote homebrew/cask "${remote_url}" 2>/dev/null || true
        success "homebrew/cask 已恢复: ${remote_url}"
    fi

    echo ""
    success "恢复完成!"
    info "请执行: ${CYAN}source ${SHELL_CONFIG_FILE}${NC}"
    echo ""
}

# ---------- 测试镜像源速度 ----------
test_speed() {
    echo -e "${BOLD}测试镜像源连通性...${NC}"
    echo "─────────────────────────────────────────"

    local i=1
    while [ ${i} -le 4 ]; do
        local config_str api_domain mirror_name
        config_str="$(get_mirror_config ${i})"
        api_domain="$(echo "${config_str}" | cut -d'|' -f1)"
        mirror_name="$(get_mirror_name ${i})"

        local result status_code time_sec

        result="$(curl -o /dev/null -s -L -w "%{http_code} %{time_total}" \
            --connect-timeout 5 --max-time 10 "${api_domain}" 2>/dev/null)" || result="000 0.000"

        status_code="${result%% *}"
        time_sec="${result##* }"

        local time_ms
        time_ms="$(awk "BEGIN {printf \"%.0f\", ${time_sec} * 1000}")"

        if [[ "${status_code}" =~ ^[23] ]]; then
            echo -e "  ${GREEN}OK${NC} ${mirror_name} — ${time_ms}ms"
        else
            echo -e "  ${RED}FAIL${NC} ${mirror_name} — 不可用 (HTTP ${status_code})"
        fi

        i=$((i + 1))
    done
    echo ""
}

# ---------- 主菜单 ----------
show_menu() {
    echo -e "${BOLD}请选择操作:${NC}"
    echo "─────────────────────────────────────────"
    echo -e "  ${GREEN}1)${NC} 切换镜像源"
    echo -e "  ${GREEN}2)${NC} 恢复官方源"
    echo -e "  ${GREEN}3)${NC} 查看当前配置"
    echo -e "  ${GREEN}4)${NC} 测试镜像速度"
    echo -e "  ${GREEN}5)${NC} 从备份恢复"
    echo -e "  ${RED}0)${NC} 退出"
    echo ""
    echo -ne "${BOLD}请输入选项 [0-5]: ${NC}"
}

# ---------- 主流程 ----------
main() {
    print_banner
    check_prerequisites

    detect_shell_config
    info "Shell: ${SHELL} → 配置文件: ${SHELL_CONFIG_FILE}"
    echo ""

    while true; do
        show_menu
        local choice
        read -r choice

        case "${choice}" in
            1)
                get_current_mirror
                select_mirror
                read -r mirror_choice

                case "${mirror_choice}" in
                    1|2|3|4)
                        local mirror_name
                        mirror_name="$(get_mirror_name ${mirror_choice})"
                        confirm "确认切换到 ${mirror_name}?" && {
                            backup_config
                            apply_mirror "${mirror_choice}"
                        }
                        ;;
                    0)
                        confirm "确认恢复 Homebrew 官方源?" && {
                            backup_config
                            restore_official
                        }
                        ;;
                    *)
                        error "无效选项"
                        ;;
                esac
                ;;
            2)
                confirm "确认恢复 Homebrew 官方源?" && {
                    backup_config
                    restore_official
                }
                ;;
            3)
                get_current_mirror
                ;;
            4)
                test_speed
                ;;
            5)
                restore_from_backup || true
                ;;
            0)
                echo -e "${CYAN}再见!${NC}"
                exit 0
                ;;
            *)
                error "无效选项, 请重新选择"
                ;;
        esac
    done
}

main "$@"
