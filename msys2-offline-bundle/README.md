# Windows Shell 环境离线配置方案

适用于无法使用 WSL 的 Windows 环境（如虚拟机），支持**完全离线安装**，提供接近原生 Linux 的 shell 体验。

## 🚀 快速开始

### 离线路线（推荐）

**三步完成离线安装**：

```
┌─────────────────────────────────────────────┐
│ 1️⃣ 外网环境 → 下载资源                       │
│    .\download-resources.ps1                 │
└─────────────────────────────────────────────┘
                    ↓ 拷贝到离线环境
┌─────────────────────────────────────────────┐
│ 2️⃣ 离线环境 → 安装 MSYS2                    │
│    .\offline-install-msys2.ps1              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3️⃣ MSYS2 → 配置 Zsh                        │
│    bash ~/scripts/offline-setup-zsh.sh      │
└─────────────────────────────────────────────┘
```

**📖 详细步骤请参考**: [WORKFLOW.md](./WORKFLOW.md)

### 在线路线（备用）

如果有稳定的网络连接：
1. `.\install-msys2.ps1` - 在线安装 MSYS2
2. `bash setup-shell.sh` - 在线配置 Zsh

---

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

## 🆕 最新更新

### 2026-03-28 重要更新

✅ **工作流程文档**
- 新增 [WORKFLOW.md](./WORKFLOW.md) 详细说明脚本使用流程
- 所有脚本头部添加流程位置说明
- 明确区分离线路线和在线路线

✅ **配置文件支持**

✅ **配置文件支持（完整）**
- 所有脚本支持从 `config.conf` 读取配置
- 支持自定义镜像源（MSYS2 和 GitHub）
- 支持自定义软件包列表
- 配置优先级：命令行参数 > 配置文件 > 默认值

✅ **PowerShell 5.1 兼容性**
- 修复 `&&` 语法错误（PowerShell 5.1 不支持）
- 改用独立的 `Start-Process` 调用
- 修复 pacman 命令环境加载问题
- 完全兼容 Windows 10 默认 PowerShell 版本

✅ **插件安装增强**
- 支持从 zip 文件安装 Oh My Zsh 和插件
- 支持配置动态下载任意 Zsh 插件
- 改进错误提示和安装日志

✅ **新增辅助脚本**
- `download-packages.sh` - 在 MSYS2 环境中下载软件包
- 支持导出到 `~/offline-packages` 目录

✅ **故障排查文档**
- README 添加详细的 zsh 故障排查步骤
- 包含诊断和 3 种解决方法

### 使用建议

1. **首次使用**：编辑 `config.conf` 配置镜像源（国内用户）
2. **PowerShell 版本**：脚本已兼容 5.1+，无需升级 PowerShell
3. **插件格式**：推荐使用 zip 格式（体积更小，传输更快）

---

## 🚀 使用方法

### 完整流程（推荐）

#### 第一步：在外网环境下载资源

在有外网的 Windows 机器上，以**管理员身份**打开 PowerShell：

```powershell
# 设置执行策略（如需要）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 方式 1: 使用配置文件（推荐）
# 先编辑 config.conf 配置镜像源和软件包列表
.\download-resources.ps1

# 方式 2: 命令行参数
.\download-resources.ps1 -OutputPath "D:\offline-resources"

# 方式 3: 使用国内镜像源
.\download-resources.ps1 `
    -Msys2Mirror "https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib" `
    -GitHubMirror "https://ghproxy.com/https://github.com"
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

### Q: zsh 未正确安装
A:
**症状**：运行 `zsh` 提示命令未找到，或 zsh 无法启动

**检查步骤**：
1. 检查离线资源是否包含 zsh 包：
   ```powershell
   # 在 Windows PowerShell 中
   dir offline-resources\packages\*zsh*
   ```
   应该能看到类似 `zsh-5.9-1-x86_64.pkg.tar.zst` 的文件

2. 检查 MSYS2 中是否安装了 zsh：
   ```bash
   # 在 MSYS2 UCRT64 中
   pacman -Qs zsh
   ```
   如果没有输出，说明 zsh 未安装

3. 查看 MSYS2 软件包缓存：
   ```bash
   ls /var/cache/pacman/pkg/ | grep zsh
   ```

**解决方法**：

**方法 1：手动安装 zsh 包**
```bash
# 在 MSYS2 UCRT64 中
cd ~/offline-tools/packages/  # 或离线资源所在位置
pacman -U zsh-*.pkg.tar.zst
```

**方法 2：重新运行安装脚本**
```powershell
# 在 Windows PowerShell（管理员）中
cd offline-resources\scripts
.\offline-install-msys2.ps1 -ResourcesPath ".."
```

**方法 3：检查依赖包**
zsh 依赖以下包，确保它们也被下载和安装：
- `libpcre` 和 `libpcre2`
- `ncurses`
- `readline`
- `gdbm`

```bash
# 检查依赖是否安装
pacman -Qs "libpcre|ncurses|readline|gdbm"
```

**预防措施**：
- 使用最新版本的 `download-resources.ps1`（已修复 bash 数组语法错误）
- 确保 `config.conf` 中 `packages` 列表包含 zsh 及其依赖
- 下载完成后，检查 `offline-resources/packages/` 是否有 20+ 个包文件

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

### Q: 插件安装失败（zip 文件）
A:
- 确保 zip 文件完整（未损坏）
- 检查 zip 文件是否在 `~/offline-tools/` 目录
- 支持的 zip 文件：
  - `oh-my-zsh.zip`
  - `zsh-autosuggestions.zip`
  - `zsh-syntax-highlighting.zip`
  - `starship.zip`
- 如果 zip 安装失败，脚本会尝试从目录安装

### Q: PowerShell 脚本报错 "&& 附近有语法错误"
A:
- **已修复**：最新版本已兼容 PowerShell 5.1
- 如果仍有问题，请确认使用的是最新版本
- 或升级到 PowerShell 7.x（可选）

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

#### 方法 1：使用 download-packages.sh（推荐）

在**有外网的 MSYS2 UCRT64** 环境中运行：

```bash
# 在 MSYS2 UCRT64 终端中
cd /path/to/msys2-offline-bundle
bash download-packages.sh

# 软件包会下载到 ~/offline-packages/
# 然后可以打包传输到离线环境
tar -czf offline-packages.tar.gz ~/offline-packages/
```

#### 方法 2：手动下载

在 MSYS2 中：

```bash
# 下载单个包（不安装）
pacman -Sw --noconfirm 包名

# 查看缓存位置
ls /var/cache/pacman/pkg/

# 手动安装本地包
pacman -U /path/to/package.pkg.tar.zst
```

## 🗂️ 文件清单

### 配置文件
- `config.conf` - 下载配置文件（镜像源、软件包列表等）
- `WORKFLOW.md` - **工作流程文档（推荐先阅读）**

### 离线路线（推荐）

| 脚本 | 运行环境 | 流程位置 |
|------|---------|---------|
| `download-resources.ps1` | Windows (有外网) | 步骤 1/3 |
| `offline-install-msys2.ps1` | Windows (离线) | 步骤 2/3 |
| `offline-setup-zsh.sh` | MSYS2 UCRT64 | 步骤 3/3 |

### 在线路线（备用）

| 脚本 | 运行环境 | 流程位置 |
|------|---------|---------|
| `install-msys2.ps1` | Windows (有外网) | 步骤 1/2 |
| `setup-shell.sh` | MSYS2 UCRT64 | 步骤 2/2 |

### 辅助工具

| 脚本 | 运行环境 | 用途 |
|------|---------|------|
| `download-packages.sh` | MSYS2 UCRT64 (有外网) | 单独下载软件包（通常不需要） |

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
