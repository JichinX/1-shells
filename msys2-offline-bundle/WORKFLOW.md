# MSYS2 离线安装工作流程

本文档说明如何使用脚本进行 MSYS2 离线安装和配置。

## 🎯 快速选择

### 离线路线（推荐）
适用于**完全离线**的 Windows 环境（虚拟机、内网等）

**✅ 优势**：
- 无需任何网络连接
- 安装速度快（本地资源）
- 可重复部署

**📍 使用场景**：
- 虚拟机环境（无法使用 WSL）
- 内网开发环境
- 需要批量部署多台机器

### 在线路线（备用）
适用于**有稳定外网**的 Windows 环境

**⚠️ 要求**：
- 稳定的网络连接
- 能访问 GitHub 和 MSYS2 官方源
- 建议使用国内镜像加速

---

## 📦 离线路线（推荐）

### 完整流程

```
┌─────────────────────────────────────────────────────────┐
│  步骤 1: 外网环境 - 下载离线资源                          │
│  运行: download-resources.ps1                           │
│  产出: offline-resources/ 目录                          │
└─────────────────────────────────────────────────────────┘
                          ↓ 拷贝到离线环境
┌─────────────────────────────────────────────────────────┐
│  步骤 2: 离线环境 - 安装 MSYS2                           │
│  运行: offline-install-msys2.ps1                        │
│  产出: C:\msys64\ (MSYS2 环境)                          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  步骤 3: MSYS2 环境 - 配置 Zsh                          │
│  运行: bash ~/scripts/offline-setup-zsh.sh             │
│  产出: 完整的 Zsh + Oh My Zsh + Starship 环境           │
└─────────────────────────────────────────────────────────┘
```

### 详细步骤

#### 步骤 1: 在有外网的环境下载资源

**位置**: 有外网的 Windows 机器

**操作**:
```powershell
# 以管理员身份打开 PowerShell
cd msys2-offline-bundle

# 方式 1: 使用配置文件（推荐）
# 先编辑 config.conf 配置镜像源和软件包
.\download-resources.ps1

# 方式 2: 使用国内镜像
.\download-resources.ps1 `
    -Msys2Mirror "https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib" `
    -GitHubMirror "https://ghproxy.com/https://github.com"
```

**产出**:
```
offline-resources/
  ├── msys2-x86_64-latest.exe    # MSYS2 安装包
  ├── packages/                  # 软件包（zsh, git, bat 等）
  ├── tools/                     # 工具和插件
  │   ├── oh-my-zsh.zip
  │   ├── zsh-autosuggestions.zip
  │   ├── zsh-syntax-highlighting.zip
  │   ├── starship.exe
  │   └── JetBrainsMono-Nerd-Font.zip
  ├── scripts/                   # 安装脚本
  │   ├── offline-install-msys2.ps1
  │   └── offline-setup-zsh.sh
  └── manifest.json              # 资源清单
```

**预计时间**: 10-30 分钟（取决于网络速度）

#### 步骤 2: 拷贝到离线环境

**操作**:
1. 将整个 `offline-resources` 文件夹拷贝到离线的 Windows 环境
2. 可以使用 U 盘、网络共享、或其他传输方式

#### 步骤 3: 在离线环境安装 MSYS2

**位置**: 离线的 Windows 机器

**操作**:
```powershell
# 以管理员身份打开 PowerShell
cd offline-resources\scripts

# 运行安装脚本
.\offline-install-msys2.ps1

# 或指定自定义路径
.\offline-install-msys2.ps1 `
    -ResourcesPath ".." `
    -InstallPath "C:\msys64"
```

**产出**:
- MSYS2 安装到 `C:\msys64\`
- 软件包已安装（zsh, git, bat, fd, ripgrep, fzf 等）
- 工具和脚本复制到 `~/offline-tools/` 和 `~/scripts/`

**预计时间**: 5-15 分钟

#### 步骤 4: 配置 Zsh 环境

**位置**: MSYS2 UCRT64 终端

**操作**:
```bash
# 启动 MSYS2 UCRT64
# 开始菜单 → MSYS2 UCRT64

# 运行配置脚本
bash ~/scripts/offline-setup-zsh.sh

# 重启终端
```

**产出**:
- ✅ Zsh 设置为默认 Shell
- ✅ Oh My Zsh + 插件（自动建议、语法高亮）
- ✅ Starship 现代提示符
- ✅ 丰富的别名和快捷键

**预计时间**: 1-3 分钟

---

## 🌐 在线路线（备用）

### 使用场景

- 有稳定的外网连接
- 首次尝试 MSYS2
- 单次部署，不需要重复

### 步骤

#### 步骤 1: 在线安装 MSYS2

```powershell
# 以管理员身份运行 PowerShell
.\install-msys2.ps1
```

#### 步骤 2: 在线配置 Zsh

```bash
# 在 MSYS2 UCRT64 中运行
bash setup-shell.sh
```

---

## 📋 脚本说明

### 离线脚本（推荐）

| 脚本 | 运行环境 | 用途 | 流程位置 |
|------|---------|------|---------|
| `download-resources.ps1` | Windows (有外网) | 下载所有离线资源 | 步骤 1 |
| `offline-install-msys2.ps1` | Windows (离线) | 安装 MSYS2 和软件包 | 步骤 2 |
| `offline-setup-zsh.sh` | MSYS2 UCRT64 | 配置 Zsh 环境 | 步骤 3 |

### 在线脚本（备用）

| 脚本 | 运行环境 | 用途 | 流程位置 |
|------|---------|------|---------|
| `install-msys2.ps1` | Windows (有外网) | 在线安装 MSYS2 | 备用步骤 1 |
| `setup-shell.sh` | MSYS2 UCRT64 | 在线配置 Zsh | 备用步骤 2 |

### 辅助脚本

| 脚本 | 运行环境 | 用途 |
|------|---------|------|
| `download-packages.sh` | MSYS2 UCRT64 (有外网) | 单独下载软件包 |
| `config.conf` | - | 配置文件（镜像源、软件包列表） |

---

## ⚙️ 配置文件

编辑 `config.conf` 自定义下载选项：

```ini
# 镜像源（国内用户建议修改）
msys2_mirror = https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib
github_mirror = https://ghproxy.com/https://github.com

# 软件包列表
packages = git curl wget vim nano zsh tar zip unzip man-db bat fd ripgrep fzf zoxide
ucrt64_packages = eza

# 工具配置
download_ohmyzsh = true
zsh_plugins = zsh-autosuggestions, zsh-syntax-highlighting
download_starship = true
download_font = true
```

**配置优先级**: 命令行参数 > 配置文件 > 默认值

---

## 🔍 故障排查

### 下载资源失败

**症状**: `download-resources.ps1` 报错网络超时

**解决**:
1. 检查网络连接
2. 使用国内镜像源：
   ```ini
   msys2_mirror = https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib
   github_mirror = https://ghproxy.com/https://github.com
   ```
3. 手动下载资源放到对应目录

### 离线安装失败

**症状**: `offline-install-msys2.ps1` 报错找不到资源

**解决**:
1. 检查 `offline-resources` 目录结构是否完整
2. 确认 `packages/` 目录有 `.pkg.tar.zst` 文件
3. 确认 `scripts/` 目录有后续需要的脚本

### Zsh 未正确安装

**症状**: 运行 `zsh` 提示命令未找到

**解决**:
1. 检查离线资源是否包含 zsh 包：
   ```powershell
   dir offline-resources\packages\*zsh*
   ```
2. 查看 MSYS2 中是否安装了 zsh：
   ```bash
   pacman -Qs zsh
   ```
3. 手动安装 zsh 包：
   ```bash
   pacman -U ~/offline-tools/packages/zsh-*.pkg.tar.zst
   ```

详细故障排查请参考 [README.md](./README.md) 的常见问题部分。

---

## 📚 相关文档

- [README.md](./README.md) - 完整使用文档
- [config.conf](./config.conf) - 配置文件示例

---

## 📝 版本历史

- 2026-03-28: 整理脚本流程，创建工作流程文档
- 2026-03-28: 修复 zsh 安装失败问题
- 2026-03-28: 完善配置文件支持
