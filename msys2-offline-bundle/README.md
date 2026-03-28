# Windows Shell 环境离线配置方案

适用于无法使用 WSL 的 Windows 环境（如虚拟机），支持**完全离线安装**，提供接近原生 Linux 的 shell 体验。

## 📦 包含内容

### 1. `download-resources.ps1` - 外网下载脚本
在**有外网**的环境运行，下载所有离线资源：
- MSYS2 安装包
- MSYS2 软件包（zsh, git, bat, fd, ripgrep, fzf, zoxide, eza 等）
- Oh My Zsh 及插件
- Starship prompt
- Nerd Font 字体（可选）

### 2. `offline-install-msys2.ps1` - 离线安装脚本
在**离线环境**运行，安装 MSYS2：
- 安装 MSYS2 UCRT64
- 从本地安装软件包
- 复制工具和配置脚本

### 3. `offline-setup-zsh.sh` - 离线配置脚本
在**离线的 MSYS2** 中运行，配置完整开发环境：
- Zsh + Oh My Zsh
- zsh-autosuggestions（命令自动建议）
- zsh-syntax-highlighting（语法高亮）
- starship（现代 Prompt）
- 完整的别名和快捷键配置

## 🚀 使用方法

### 完整流程（推荐）

#### 第一步：在外网环境下载资源

在有外网的 Windows 机器上，以**管理员身份**打开 PowerShell：

```powershell
# 设置执行策略（如需要）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行下载脚本
.\download-resources.ps1

# 或指定输出路径
.\download-resources.ps1 -OutputPath "D:\offline-resources"
```

下载完成后，会生成以下结构：
```
offline-resources/
  ├── msys2-x86_64-latest.exe    # MSYS2 安装包
  ├── packages/                  # 软件包
  ├── tools/                     # 工具和插件
  │   ├── oh-my-zsh/
  │   ├── zsh-autosuggestions/
  │   ├── zsh-syntax-highlighting/
  │   ├── starship.exe
  │   └── JetBrainsMono-Nerd-Font.zip
  ├── scripts/                   # 安装脚本
  │   ├── offline-install-msys2.ps1
  │   └── offline-setup-zsh.sh
  └── manifest.json              # 资源清单
```

#### 第二步：拷贝到离线环境

将整个 `offline-resources` 文件夹拷贝到离线的 Windows 环境。

#### 第三步：离线安装 MSYS2

在离线环境，以**管理员身份**打开 PowerShell：

```powershell
# 运行安装脚本
.\offline-resources\scripts\offline-install-msys2.ps1

# 或指定资源路径和安装路径
.\offline-resources\scripts\offline-install-msys2.ps1 `
    -ResourcesPath ".\offline-resources" `
    -InstallPath "C:\msys64"
```

#### 第四步：配置 Shell 环境

1. 启动 **MSYS2 UCRT64**（开始菜单或 `C:\msys64\msys2.exe`）
2. 运行配置脚本：

```bash
bash ~/scripts/offline-setup-zsh.sh
```

3. 重启终端

---

### 快速开始（如果已有 MSYS2）

如果离线环境已经有 MSYS2，只需：

1. 将 `offline-resources\tools` 和 `offline-resources\scripts` 复制到 `C:\msys64\home\你的用户名\`
2. 在 MSYS2 中运行：

```bash
bash ~/scripts/offline-setup-zsh.sh
```

## ⚙️ Windows Terminal 配置（可选但推荐）

在 Windows Terminal 设置中添加新 Profile：

```json
{
  "name": "MSYS2 UCRT64",
  "commandline": "C:/msys64/msys2_shell.cmd -ucrt64 -defterm -no-start -c zsh",
  "startingDirectory": "C:/msys64/home/YOUR_USERNAME",
  "icon": "C:/msys64/msys2.ico",
  "font": {
    "face": "JetBrains Mono Nerd Font",
    "size": 11
  },
  "colorScheme": "Tokyo Night"
}
```

### 安装 Nerd Font（重要）

为了正确显示图标和符号，需要安装 Nerd Font：

**离线环境**：
- 从 `offline-resources\tools\JetBrainsMono-Nerd-Font.zip` 解压
- 右键安装字体文件（或全选后右键安装）

**在线环境**：
- [JetBrains Mono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip)
- [FiraCode Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip)

## 📋 已配置的快捷命令

| 命令 | 功能 |
|------|------|
| `z <dir>` | 智能跳转目录 |
| `Ctrl+R` | 搜索历史命令 |
| `Ctrl+T` | 搜索文件 |
| `Alt+C` | 跳转目录 |
| `ll` | 详细文件列表（带图标和 Git 状态） |
| `lt` | 树形文件列表 |
| `cat` | bat（语法高亮） |
| `find` | fd（更快的查找） |
| `grep` | ripgrep（更快且高亮） |
| `reload` | 重新加载 .zshrc |
| `c` | 快速跳转到 C 盘 |
| `d` | 快速跳转到 D 盘 |

## 🔧 配置文件

- Shell 配置: `~/.zshrc`
- Prompt 配置: `~/.config/starship.toml`
- Oh My Zsh: `~/.oh-my-zsh/`

## ❓ 常见问题

### Q: 下载资源脚本失败
A:
- 检查网络连接
- 如果在中国大陆，编辑 `config.conf` 使用国内镜像：
  ```ini
  msys2_mirror = https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib
  github_mirror = https://ghproxy.com/https://github.com
  ```
- 或命令行指定镜像：`.\download-resources.ps1 -Msys2Mirror "https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib"`
- 可以手动下载 MSYS2 和工具，放到对应目录

### Q: 离线安装软件包失败
A: 
- 确保 `offline-resources\packages` 目录有 `.pkg.tar.zst` 文件
- 如果包不完整，可以在 MSYS2 中单独安装缺失的包
- 部分包可能不在离线资源中，但核心功能不受影响

### Q: 图标显示为方框
A: 
- **必须**安装 Nerd Font（JetBrains Mono 或 Fira Code）
- 在 Windows Terminal 和 VS Code 中都设置该字体
- 如果仍然有问题，检查 starship 配置

### Q: zsh 没有自动启动
A: 
- 手动运行: `source ~/.zshrc`
- 或直接运行: `zsh`
- 检查 `~/.bashrc` 中是否有自动启动配置

### Q: 某些工具（如 eza）没有安装
A: 
- 部分工具可能不在 MSYS2 官方源中
- 脚本会尝试安装替代品（如 exa 代替 eza）
- 如果都没有，会回退到基础命令（如 ls）

### Q: 可以在有网络的环境使用在线脚本吗？
A: 
- 可以，但离线脚本更可靠
- 如果网络稳定，也可以使用 `setup-shell.sh`（在线版本）
- 离线脚本不需要任何网络连接

## 📝 自定义

### 配置文件

编辑 `config.conf` 自定义下载选项：

```ini
# 基础配置
arch = x86_64
output = .\offline-resources

# 镜像源（国内用户建议修改）
msys2_mirror = https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib
github_mirror = https://ghproxy.com/https://github.com

# 软件包列表
packages = git curl wget vim nano zsh tar unzip man-db bat fd ripgrep fzf zoxide
ucrt64_packages = eza

# 可选项
download_font = true
```

**镜像源选项：**
- **MSYS2 镜像**：
  - 官方：`https://repo.msys2.org/distrib`
  - 清华：`https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib`
  - 中科大：`https://mirrors.ustc.edu.cn/msys2/distrib`

- **GitHub 镜像**（国内加速）：
  - 官方：`https://github.com`
  - GitHub Proxy：`https://ghproxy.com/https://github.com`
  - FastGit：`https://hub.fastgit.xyz`

**优先级：** 命令行参数 > 配置文件 > 默认值

### 添加更多插件

```bash
# 在 ~/.zshrc 的 plugins 数组中添加
plugins=(
    git
    z
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    docker          # Docker 补全
    npm             # NPM 补全
    sudo            # 双击 ESC 自动加 sudo
    copypath        # 复制当前路径
    copyfile        # 复制文件内容
)
```

### 自定义 Starship

编辑 `~/.config/starship.toml`，参考 [Starship 配置文档](https://starship.rs/config/)

### 添加更多软件包

如果需要其他工具，在有外网的环境：

```powershell
# 下载额外的软件包到离线资源目录
# 然后在离线环境手动安装
```

在 MSYS2 中：

```bash
# 手动安装本地包
pacman -U /path/to/package.pkg.tar.zst
```

## 🗂️ 文件清单

### 在线脚本（已弃用，仅作参考）
- ~~`install-msys2.ps1`~~ - 在线安装脚本
- ~~`setup-shell.sh`~~ - 在线配置脚本

### 离线脚本（推荐）
- `download-resources.ps1` - 外网下载资源
- `offline-install-msys2.ps1` - 离线安装 MSYS2
- `offline-setup-zsh.sh` - 离线配置 Zsh
- `README.md` - 本文档

## 🔄 卸载

```powershell
# 直接删除 MSYS2 目录
Remove-Item -Path C:\msys64 -Recurse -Force
```

卸载后，Windows Terminal 配置文件不会自动删除，需要手动清理。

## 📚 相关资源

- [MSYS2 官网](https://www.msys2.org/)
- [MSYS2 软件包搜索](https://packages.msys2.org/)
- [Oh My Zsh](https://ohmyz.sh/)
- [Starship](https://starship.rs/)
- [Windows Terminal](https://github.com/microsoft/terminal)
- [Nerd Fonts](https://www.nerdfonts.com/)

## 📄 许可

这些脚本仅供个人使用，遵循相关软件的开源协议。

---

**享受你的现代 Shell 体验！**

如有问题，请检查：
1. 是否以管理员权限运行 PowerShell 脚本
2. 是否安装了 Nerd Font 字体
3. 离线资源是否完整下载
