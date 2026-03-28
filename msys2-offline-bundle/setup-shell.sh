#!/bin/bash
# MSYS2 Shell 环境一键配置脚本
# 在 MSYS2 UCRT64 终端中运行: bash setup-shell.sh
# 或直接: curl -fsSL https://your-url/setup-shell.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  MSYS2 Shell 环境一键配置${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检测当前环境
if [[ ! -f /etc/msystem ]]; then
    echo -e "${RED}[!] 此脚本必须在 MSYS2 环境中运行${NC}"
    exit 1
fi

# 检测 UCRT64 环境
if [[ "$(cat /etc/msystem 2>/dev/null)" != "UCRT64" ]]; then
    echo -e "${YELLOW}[!] 建议在 UCRT64 环境中运行以获得最佳兼容性${NC}"
    echo -e "${YELLOW}    当前环境: $(cat /etc/msystem 2>/dev/null || echo '未知')${NC}"
    read -p "    是否继续？ (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================
# Step 1: 安装核心工具
# ============================================
echo -e "${GREEN}[1/6] 安装核心工具...${NC}"

# 基础工具
pacman -S --noconfirm --needed \
    git curl wget vim nano \
    zsh \
    tar unzip \
    man-db man-pages-posix

# 现代 CLI 工具（MSYS2 软件源中可用的）
echo -e "${GREEN}    -> 安装现代 CLI 工具...${NC}"
pacman -S --noconfirm --needed \
    bat \
    fd \
    ripgrep \
    fzf \
    zoxide

# eza (ls 替代) - 可能需要从源安装或使用预编译版本
# MSYS2 的 eza 在 mingw-w64-ucrt-x86_64-eza 包中
if pacman -Si mingw-w64-ucrt-x86_64-eza &>/dev/null; then
    pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-eza
    EZA_CMD="eza"
else
    echo -e "${YELLOW}    -> eza 包不可用，将使用 exa 或 ls 作为替代${NC}"
    # 尝试安装 exa 或使用别名
    if pacman -Si mingw-w64-ucrt-x86_64-exa &>/dev/null; then
        pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-exa
        EZA_CMD="exa"
    else
        EZA_CMD="ls"
    fi
fi

# starship prompt
if pacman -Si starship &>/dev/null; then
    pacman -S --noconfirm --needed starship
else
    echo -e "${YELLOW}    -> 从 GitHub 下载 starship...${NC}"
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

echo -e "${GREEN}    -> 核心工具安装完成${NC}"

# ============================================
# Step 2: 安装 Oh My Zsh
# ============================================
echo -e "${GREEN}[2/6] 安装 Oh My Zsh...${NC}"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo -e "${YELLOW}    -> Oh My Zsh 已安装，跳过${NC}"
else
    # 非交互式安装
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    echo -e "${GREEN}    -> Oh My Zsh 安装完成${NC}"
fi

# ============================================
# Step 3: 安装 Zsh 插件
# ============================================
echo -e "${GREEN}[3/6] 安装 Zsh 插件...${NC}"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    echo -e "${YELLOW}    -> zsh-autosuggestions 已安装${NC}"
else
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    echo -e "${GREEN}    -> zsh-autosuggestions 安装完成${NC}"
fi

# zsh-syntax-highlighting
if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    echo -e "${YELLOW}    -> zsh-syntax-highlighting 已安装${NC}"
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    echo -e "${GREEN}    -> zsh-syntax-highlighting 安装完成${NC}"
fi

# z (内置，但确保启用)
echo -e "${GREEN}    -> 将启用 z 插件${NC}"

# ============================================
# Step 4: 配置 .zshrc
# ============================================
echo -e "${GREEN}[4/6] 配置 .zshrc...${NC}"

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

# Starship Prompt
eval "$(starship init zsh)"

# Zoxide（智能目录跳转）
eval "$(zoxide init zsh)"

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
echo -e "${GREEN}[5/6] 配置 Starship Prompt...${NC}"

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

# ============================================
# Step 6: 设置 Zsh 为默认 Shell
# ============================================
echo -e "${GREEN}[6/6] 设置 Zsh 为默认 Shell...${NC}"

# MSYS2 中通过修改 /etc/passwd 或设置环境变量
if command -v chsh &>/dev/null; then
    if [[ "$SHELL" != *"zsh"* ]]; then
        echo -e "${YELLOW}    -> 请手动运行以下命令设置默认 shell:${NC}"
        echo -e "${YELLOW}       chsh -s \$(which zsh)${NC}"
    else
        echo -e "${GREEN}    -> Zsh 已是默认 shell${NC}"
    fi
else
    # MSYS2 方式：修改 ~/.bashrc 自动启动 zsh
    if ! grep -q "exec zsh" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "${YELLOW}    -> 将在 .bashrc 中添加自动启动 zsh${NC}"
        echo "" >> "$HOME/.bashrc"
        echo "# Auto launch zsh" >> "$HOME/.bashrc"
        echo "if command -v zsh &>/dev/null && [[ -z \"\$ZSH_VERSION\" ]]; then" >> "$HOME/.bashrc"
        echo "    exec zsh" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
    fi
    echo -e "${GREEN}    -> 配置完成，下次启动将自动进入 zsh${NC}"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}已安装的工具:${NC}"
echo "  • zsh + oh-my-zsh"
echo "  • zsh-autosuggestions (命令建议)"
echo "  • zsh-syntax-highlighting (语法高亮)"
echo "  • starship (现代 Prompt)"
echo "  • bat (cat 替代)"
echo "  • fd (find 替代)"
echo "  • ripgrep (grep 替代)"
echo "  • fzf (模糊搜索)"
echo "  • zoxide (智能目录跳转)"

if [[ "$EZA_CMD" != "ls" ]]; then
    echo "  • $EZA_CMD (ls 替代)"
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
