#!/bin/bash
# 离线环境 ZSH 配置脚本
#
# 【流程位置】离线路线 - 步骤 3/3（在 MSYS2 UCRT64 中运行）
# 【前置步骤】offline-install-msys2.ps1（在离线环境运行）
#
# 功能：配置完整的 Zsh 开发环境（Oh My Zsh + 插件 + Starship）
# 产出：现代化的 Shell 环境（无需网络连接）
#
# 在 MSYS2 UCRT64 终端中运行: bash ~/scripts/offline-setup-zsh.sh
#
# 详细工作流程请参考: WORKFLOW.md

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  离线环境 ZSH 配置${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检测当前环境
if [[ ! -f /etc/msystem ]]; then
    echo -e "${RED}[!] 此脚本必须在 MSYS2 环境中运行${NC}"
    exit 1
fi

# 资源路径
TOOLS_DIR="$HOME/offline-tools"
SCRIPTS_DIR="$HOME/scripts"

if [[ ! -d "$TOOLS_DIR" ]]; then
    echo -e "${RED}[!] 找不到离线工具目录: $TOOLS_DIR${NC}"
    echo -e "${YELLOW}    请确保 offline-install-msys2.ps1 脚本已正确运行${NC}"
    exit 1
fi

echo -e "${GREEN}[*] 离线资源路径: $TOOLS_DIR${NC}"
echo ""

# ============================================
# Step 1: 安装 Oh My Zsh
# ============================================
echo -e "${GREEN}[1/5] 安装 Oh My Zsh...${NC}"

OHMYZSH_DEST="$HOME/.oh-my-zsh"

if [[ -d "$OHMYZSH_DEST" ]]; then
    echo -e "${YELLOW}    -> Oh My Zsh 已安装，跳过${NC}"
else
    # 尝试从 zip 文件安装
    OHMYZSH_ZIP="$TOOLS_DIR/oh-my-zsh.zip"
    OHMYZSH_DIR="$TOOLS_DIR/oh-my-zsh"
    
    if [[ -f "$OHMYZSH_ZIP" ]]; then
        echo -e "${GREEN}    -> 从 zip 文件安装${NC}"
        # 解压到临时目录
        TEMP_DIR=$(mktemp -d)
        unzip -q "$OHMYZSH_ZIP" -d "$TEMP_DIR"
        
        # 找到解压后的目录（通常是 ohmyzsh-master）
        EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "ohmyzsh*" | head -1)
        
        if [[ -d "$EXTRACTED_DIR" ]]; then
            mv "$EXTRACTED_DIR" "$OHMYZSH_DEST"
            echo -e "${GREEN}    -> Oh My Zsh 安装完成${NC}"
        else
            echo -e "${RED}    -> zip 文件结构不正确${NC}"
        fi
        
        rm -rf "$TEMP_DIR"
    elif [[ -d "$OHMYZSH_DIR" ]]; then
        cp -r "$OHMYZSH_DIR" "$OHMYZSH_DEST"
        echo -e "${GREEN}    -> Oh My Zsh 安装完成${NC}"
    else
        echo -e "${RED}    -> 找不到 Oh My Zsh 源文件${NC}"
        echo -e "${YELLOW}    -> 请确保 oh-my-zsh.zip 或 oh-my-zsh 目录存在${NC}"
        exit 1
    fi
fi

# ============================================
# Step 2: 安装 Zsh 插件
# ============================================
echo -e "${GREEN}[2/5] 安装 Zsh 插件...${NC}"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    echo -e "${YELLOW}    -> zsh-autosuggestions 已安装${NC}"
else
    AUTOSUGGEST_ZIP="$TOOLS_DIR/zsh-autosuggestions.zip"
    AUTOSUGGEST_DIR="$TOOLS_DIR/zsh-autosuggestions"
    
    if [[ -f "$AUTOSUGGEST_ZIP" ]]; then
        echo -e "${GREEN}    -> 从 zip 安装 zsh-autosuggestions${NC}"
        TEMP_DIR=$(mktemp -d)
        unzip -q "$AUTOSUGGEST_ZIP" -d "$TEMP_DIR"
        EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "zsh-autosuggestions*" | head -1)
        
        if [[ -d "$EXTRACTED_DIR" ]]; then
            mv "$EXTRACTED_DIR" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
            echo -e "${GREEN}    -> zsh-autosuggestions 安装完成${NC}"
        fi
        
        rm -rf "$TEMP_DIR"
    elif [[ -d "$AUTOSUGGEST_DIR" ]]; then
        cp -r "$AUTOSUGGEST_DIR" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        echo -e "${GREEN}    -> zsh-autosuggestions 安装完成${NC}"
    else
        echo -e "${RED}    -> 找不到 zsh-autosuggestions${NC}"
    fi
fi

# zsh-syntax-highlighting
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    echo -e "${YELLOW}    -> zsh-syntax-highlighting 已安装${NC}"
else
    SYNTAX_ZIP="$TOOLS_DIR/zsh-syntax-highlighting.zip"
    SYNTAX_DIR="$TOOLS_DIR/zsh-syntax-highlighting"
    
    if [[ -f "$SYNTAX_ZIP" ]]; then
        echo -e "${GREEN}    -> 从 zip 安装 zsh-syntax-highlighting${NC}"
        TEMP_DIR=$(mktemp -d)
        unzip -q "$SYNTAX_ZIP" -d "$TEMP_DIR"
        EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "zsh-syntax-highlighting*" | head -1)
        
        if [[ -d "$EXTRACTED_DIR" ]]; then
            mv "$EXTRACTED_DIR" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
            echo -e "${GREEN}    -> zsh-syntax-highlighting 安装完成${NC}"
        fi
        
        rm -rf "$TEMP_DIR"
    elif [[ -d "$SYNTAX_DIR" ]]; then
        cp -r "$SYNTAX_DIR" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        echo -e "${GREEN}    -> zsh-syntax-highlighting 安装完成${NC}"
    else
        echo -e "${RED}    -> 找不到 zsh-syntax-highlighting${NC}"
    fi
fi

# ============================================
# Step 3: 安装 Starship
# ============================================
echo -e "${GREEN}[3/5] 安装 Starship...${NC}"

STARSHIP_DEST="/usr/bin/starship.exe"

if [[ -f "$STARSHIP_DEST" ]]; then
    echo -e "${YELLOW}    -> Starship 已安装${NC}"
else
    STARSHIP_EXE="$TOOLS_DIR/starship.exe"
    STARSHIP_ZIP="$TOOLS_DIR/starship.zip"
    
    if [[ -f "$STARSHIP_EXE" ]]; then
        cp "$STARSHIP_EXE" "$STARSHIP_DEST"
        chmod +x "$STARSHIP_DEST"
        echo -e "${GREEN}    -> Starship 安装完成${NC}"
    elif [[ -f "$STARSHIP_ZIP" ]]; then
        echo -e "${GREEN}    -> 从 zip 安装 Starship${NC}"
        TEMP_DIR=$(mktemp -d)
        unzip -q "$STARSHIP_ZIP" -d "$TEMP_DIR"
        
        if [[ -f "$TEMP_DIR/starship.exe" ]]; then
            mv "$TEMP_DIR/starship.exe" "$STARSHIP_DEST"
            chmod +x "$STARSHIP_DEST"
            echo -e "${GREEN}    -> Starship 安装完成${NC}"
        fi
        
        rm -rf "$TEMP_DIR"
    else
        echo -e "${YELLOW}    -> 找不到 Starship，将使用基础 prompt${NC}"
    fi
fi

# ============================================
# Step 4: 配置 .zshrc
# ============================================
echo -e "${GREEN}[4/5] 配置 .zshrc...${NC}"

# 备份现有配置
if [[ -f "$HOME/.zshrc" ]]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}    -> 已备份现有 .zshrc${NC}"
fi

# 生成 .zshrc
cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# Oh My Zsh 配置
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"  # 使用 starship，主题设为空也可以

# 插件配置
plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
)

source $ZSH/oh-my-zsh.sh

# ============================================
# 用户自定义配置
# ============================================

# 语言设置
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Starship Prompt（如果已安装）
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide（智能目录跳转）
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# FZF 配置
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
  --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
  --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
'

# 如果有 fzf 的 key-bindings 和 completion
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
fi
if [[ -f /usr/share/fzf/completion.zsh ]]; then
    source /usr/share/fzf/completion.zsh
fi

# 现代 CLI 工具别名
# bat (cat 替代)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# eza/exa (ls 替代)
if command -v eza &>/dev/null; then
    alias ls='eza --icons --git'
    alias ll='eza -lah --icons --git'
    alias la='eza -a --icons --git'
    alias lt='eza --tree --level=2 --icons --git'
elif command -v exa &>/dev/null; then
    alias ls='exa --icons --git'
    alias ll='exa -lah --icons --git'
    alias la='exa -a --icons --git'
    alias lt='exa --tree --level=2 --icons --git'
fi

# fd (find 替代)
if command -v fd &>/dev/null; then
    alias find='fd'
fi

# ripgrep (grep 替代)
if command -v rg &>/dev/null; then
    alias grep='rg'
fi

# 常用别名
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias h='history'
alias j='jobs'

# Git 别名
alias gs='git status'
alias gp='git push'
alias gl='git pull'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate -10'

# 快速编辑配置
alias zshconfig='vim ~/.zshrc'
alias reload='source ~/.zshrc && echo "✓ Zsh 配置已重新加载"'

# Windows 路径快速跳转
alias c='cd /c/'
alias d='cd /d/'
alias home='cd ~'

# 欢迎信息
clear
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║   Welcome to MSYS2 UCRT64 Environment                         ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  快捷命令:"
echo "    z <dir>     - 智能跳转目录 (zoxide)"
echo "    Ctrl+R      - 历史命令搜索 (fzf)"
echo "    Ctrl+T      - 文件搜索 (fzf)"
echo "    Alt+C       - 目录跳转 (fzf)"
echo "    ll          - 详细文件列表"
echo "    lt          - 树形文件列表"
echo ""
echo "  配置文件: ~/.zshrc"
echo "  重新加载: reload"
echo ""
ZSHRC_EOF

echo -e "${GREEN}    -> .zshrc 配置完成${NC}"

# ============================================
# Step 5: 配置 Starship
# ============================================
echo -e "${GREEN}[5/5] 配置 Starship Prompt...${NC}"

if command -v starship &>/dev/null; then
    mkdir -p "$HOME/.config"
    
    cat > "$HOME/.config/starship.toml" << 'STARSHIP_EOF'
# Starship 配置 - 简洁现代风格

format = """
[](bold green)$directory[](green)
$character"""

add_newline = true

[directory]
style = "bold cyan"
read_only = " 🔒"
truncation_length = 3
truncate_to_repo = true

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"
vicmd_symbol = "[V](bold blue)"

[git_branch]
symbol = " "
style = "bold purple"
format = "[$symbol$branch]($style) "

[git_status]
style = "bold yellow"
format = '([\[$all_status$ahead_behind\]]($style) )'
conflicted = "="
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
untracked = "?"
stashed = "$"
modified = "!"
staged = "+"
renamed = "»"
deleted = "✖"

[nodejs]
symbol = " "
style = "bold green"
format = "[$symbol($version)]($style) "

[python]
symbol = " "
style = "bold yellow"
format = "[${symbol}${pyenv_prefix}(${version})]($style) "

[rust]
symbol = " "
style = "bold red"
format = "[$symbol($version)]($style) "

[golang]
symbol = " "
style = "bold cyan"
format = "[$symbol($version)]($style) "

[package]
symbol = " "
style = "bold 208"
format = "[$symbol$version]($style) "

[cmd_duration]
min_time = 500
format = "took [$duration](bold yellow)"

[line_break]
disabled = false

STARSHIP_EOF

    echo -e "${GREEN}    -> Starship 配置完成${NC}"
else
    echo -e "${YELLOW}    -> Starship 未安装，跳过配置${NC}"
fi

# ============================================
# 设置 Zsh 为默认 Shell
# ============================================
echo -e "${GREEN}[*] 设置 Zsh 为默认 Shell...${NC}"

# MSYS2 方式：修改 ~/.bashrc 自动启动 zsh
if ! grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "# Auto launch zsh" >> "$HOME/.bashrc"
    echo "if command -v zsh &>/dev/null && [[ -z \"\$ZSH_VERSION\" ]]; then" >> "$HOME/.bashrc"
    echo "    exec zsh" >> "$HOME/.bashrc"
    echo "fi" >> "$HOME/.bashrc"
    echo -e "${GREEN}    -> 配置完成，下次启动将自动进入 zsh${NC}"
else
    echo -e "${YELLOW}    -> 已配置自动启动 zsh${NC}"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}已安装的组件:${NC}"
echo "  • zsh + oh-my-zsh"
echo "  • zsh-autosuggestions (命令建议)"
echo "  • zsh-syntax-highlighting (语法高亮)"

if command -v starship &>/dev/null; then
    echo "  • starship (现代 Prompt)"
fi

if command -v zoxide &>/dev/null; then
    echo "  • zoxide (智能目录跳转)"
fi

if command -v fzf &>/dev/null; then
    echo "  • fzf (模糊搜索)"
fi

if command -v bat &>/dev/null; then
    echo "  • bat (cat 替代)"
fi

if command -v fd &>/dev/null; then
    echo "  • fd (find 替代)"
fi

if command -v rg &>/dev/null; then
    echo "  • ripgrep (grep 替代)"
fi

if command -v eza &>/dev/null; then
    echo "  • eza (ls 替代)"
elif command -v exa &>/dev/null; then
    echo "  • exa (ls 替代)"
fi

echo ""
echo -e "${CYAN}下一步:${NC}"
echo "  1. 重启终端，或运行: source ~/.zshrc"
echo "  2. 开始使用！尝试输入: ll 或 z <目录名>"
echo ""
echo -e "${CYAN}快捷键:${NC}"
echo "  • Ctrl+R    - 搜索历史命令"
echo "  • Ctrl+T    - 搜索文件"
echo "  • Alt+C     - 跳转目录"
echo "  • Tab       - 自动补全"
echo ""
echo -e "${YELLOW}提示: 配置文件位于 ~/.zshrc 和 ~/.config/starship.toml${NC}"
echo ""
