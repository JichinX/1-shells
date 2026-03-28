#!/bin/bash
# ==============================================================================
# VSCode 离线环境快速设置脚本
# 用途：自动配置 VSCode 离线开发环境
# 场景：离线 + Python + FastAPI + SQLAlchemy
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   VSCode 离线开发环境快速配置                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 检测操作系统
# ============================================
detect_os() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "windows"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

OS=$(detect_os)
echo -e "${GREEN}[INFO]${NC} 检测到系统: $OS"

# ============================================
# 获取 VSCode 用户配置目录
# ============================================
get_vscode_config_dir() {
    case "$OS" in
        windows)
            echo "$APPDATA/Code/User"
            ;;
        macos)
            echo "$HOME/Library/Application Support/Code/User"
            ;;
        linux)
            echo "$HOME/.config/Code/User"
            ;;
    esac
}

CONFIG_DIR=$(get_vscode_config_dir)
SETTINGS_FILE="$CONFIG_DIR/settings.json"

echo -e "${GREEN}[INFO]${NC} VSCode 配置目录: $CONFIG_DIR"

# ============================================
# 检查 VSCode 是否安装
# ============================================
if [[ ! -d "$CONFIG_DIR" ]]; then
    echo -e "${RED}[ERROR]${NC} 未找到 VSCode 配置目录"
    echo -e "${YELLOW}[提示]${NC} 请先安装并运行一次 VSCode"
    exit 1
fi

# ============================================
# 备份现有配置
# ============================================
backup_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        BACKUP_FILE="$SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$SETTINGS_FILE" "$BACKUP_FILE"
        echo -e "${GREEN}[OK]${NC} 已备份配置到: $(basename "$BACKUP_FILE")"
    fi
}

# ============================================
# 合并配置（保留用户设置）
# ============================================
merge_settings() {
    local new_settings='{
  "remote.SSH.localServerDownload": "always",
  "remote.SSH.useExecServer": true,
  "remote.SSH.connectTimeout": 60,
  "remote.SSH.showLoginTerminal": true,
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.languageServer": "Pylance",
  "python.analysis.typeCheckingMode": "basic",
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.formatOnSave": true
  },
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.testing.pytestEnabled": true,
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "editor.fontSize": 14,
  "editor.tabSize": 4,
  "editor.rulers": [88, 120],
  "git.autofetch": false,
  "extensions.autoUpdate": false,
  "update.mode": "none"
}'
    
    if [[ -f "$SETTINGS_FILE" ]]; then
        # 使用 jq 合并 JSON（如果可用）
        if command -v jq &>/dev/null; then
            jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$new_settings") > "${SETTINGS_FILE}.tmp"
            mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            echo -e "${GREEN}[OK]${NC} 配置已合并"
        else
            echo -e "${YELLOW}[WARN]${NC} 未安装 jq，将覆盖配置"
            echo "$new_settings" > "$SETTINGS_FILE"
        fi
    else
        echo "$new_settings" > "$SETTINGS_FILE"
        echo -e "${GREEN}[OK]${NC} 配置已创建"
    fi
}

# ============================================
# 创建工作区配置模板
# ============================================
create_workspace_config() {
    local workspace="$1"
    local vscode_dir="$workspace/.vscode"
    
    mkdir -p "$vscode_dir"
    
    # settings.json
    cat > "$vscode_dir/settings.json" << 'EOF'
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.terminal.activateEnvironment": true,
  "editor.formatOnSave": true,
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
EOF
    
    # launch.json
    cat > "$vscode_dir/launch.json" << 'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "main:app",
        "--reload",
        "--host", "0.0.0.0",
        "--port", "8000"
      ],
      "jinja": true
    },
    {
      "name": "Pytest",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["-v", "--tb=short"]
    }
  ]
}
EOF
    
    # extensions.json
    cat > "$vscode_dir/extensions.json" << 'EOF'
{
  "recommendations": [
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.black-formatter",
    "charliermarsh.ruff",
    "alexcvzz.vscode-sqlite",
    "tamasfe.even-better-toml"
  ]
}
EOF
    
    echo -e "${GREEN}[OK]${NC} 工作区配置已创建: $vscode_dir"
}

# ============================================
# 主菜单
# ============================================
show_menu() {
    echo ""
    echo -e "${CYAN}请选择操作：${NC}"
    echo "  1. 配置全局 VSCode 设置"
    echo "  2. 为当前目录创建工作区配置"
    echo "  3. 全部配置（推荐）"
    echo "  4. 查看推荐扩展列表"
    echo "  0. 退出"
    echo ""
    read -p "输入选项 [0-4]: " choice
    
    case $choice in
        1)
            backup_settings
            merge_settings
            echo -e "${GREEN}✅ 全局配置完成！${NC}"
            ;;
        2)
            create_workspace_config "$(pwd)"
            echo -e "${GREEN}✅ 工作区配置完成！${NC}"
            ;;
        3)
            backup_settings
            merge_settings
            create_workspace_config "$(pwd)"
            echo -e "${GREEN}✅ 全部配置完成！${NC}"
            echo -e "${YELLOW}请重启 VSCode 生效${NC}"
            ;;
        4)
            echo ""
            echo -e "${CYAN}推荐扩展列表：${NC}"
            echo "  • ms-python.python"
            echo "  • ms-python.vscode-pylance"
            echo "  • ms-python.black-formatter"
            echo "  • charliermarsh.ruff"
            echo "  • alexcvzz.vscode-sqlite"
            echo "  • tamasfe.even-better-toml"
            echo ""
            echo -e "${YELLOW}查看完整列表: recommended-extensions.md${NC}"
            ;;
        0)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            show_menu
            ;;
    esac
}

# ============================================
# 执行
# ============================================
show_menu
