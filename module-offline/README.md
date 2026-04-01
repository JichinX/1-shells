# PowerShell 模块离线安装方案

在离线环境中安装 PowerShell 模块，适用于内网开发环境、虚拟机等无法访问外网的场景。

## 🚀 快速开始

### 离线路线（推荐）

**两步完成离线安装**：

```
┌─────────────────────────────────────────────┐
│ 1️⃣ 外网环境 → 下载模块                       │
│    .\download-modules.ps1                   │
└─────────────────────────────────────────────┘
                    ↓ 拷贝到离线环境
┌─────────────────────────────────────────────┐
│ 2️⃣ 离线环境 → 安装模块                       │
│    .\offline-install-modules.ps1            │
└─────────────────────────────────────────────┘
```

## 📦 包含内容

### 配置文件
- `modules.conf` - 模块配置文件（模块列表、版本策略等）

### 离线脚本

| 脚本 | 运行环境 | 用途 |
|------|---------|------|
| `download-modules.ps1` | Windows (有外网) | 下载模块到本地 |
| `offline-install-modules.ps1` | Windows (离线) | 从本地安装模块 |

## 📋 使用方法

### 步骤 1: 在有外网的环境下载模块

**位置**: 有外网的 Windows 机器

**操作**:
```powershell
# 以管理员身份打开 PowerShell
cd module-offline

# 方式 1: 使用配置文件（推荐）
# 先编辑 modules.conf 配置模块列表
.\download-modules.ps1

# 方式 2: 指定输出目录
.\download-modules.ps1 -OutputPath "D:\offline-modules"

# 方式 3: 指定模块源
.\download-modules.ps1 -Repository PSGallery
```

**产出**:
```
offline-modules/
  ├── modules/                  # 模块文件
  │   ├── PowerShellGet/
  │   ├── PackageManagement/
  │   ├── PSReadLine/
  │   ├── posh-git/
  │   └── ...
  ├── scripts/                  # 安装脚本
  │   └── offline-install-modules.ps1
  └── manifest.json             # 模块清单
```

**预计时间**: 5-15 分钟（取决于模块数量和网络速度）

### 步骤 2: 拷贝到离线环境

**操作**:
1. 将整个 `offline-modules` 文件夹拷贝到离线的 Windows 环境
2. 可以使用 U 盘、网络共享、或其他传输方式

### 步骤 3: 在离线环境安装模块

**位置**: 离线的 Windows 机器

**操作**:
```powershell
# 以管理员身份打开 PowerShell
cd offline-modules\scripts

# 安装到当前用户（推荐）
.\offline-install-modules.ps1

# 安装到所有用户（需要管理员权限）
.\offline-install-modules.ps1 -Scope AllUsers

# 指定资源路径
.\offline-install-modules.ps1 -ResourcesPath ".."
```

**产出**:
- 模块安装到 `$env:PSModulePath`
- 可以直接使用 `Import-Module` 导入模块

**预计时间**: 1-5 分钟

## ⚙️ 配置文件

编辑 `modules.conf` 自定义模块列表：

```ini
# 基础工具模块
basic_modules = PSReadLine, posh-git, Terminal-Icons

# 开发工具模块
dev_modules = Pester, PSScriptAnalyzer, platyPS

# 云服务模块
cloud_modules = AWS.Tools.Common

# 其他常用模块
utility_modules = ImportExcel, Pscx

# 下载选项
include_dependencies = true
allow_prerelease = false
version_policy = latest
```

### 模块分类

**基础工具模块** (`basic_modules`):
- `PSReadLine` - 命令行增强（语法高亮、历史搜索）
- `posh-git` - Git 状态集成
- `Terminal-Icons` - 文件图标显示

**开发工具模块** (`dev_modules`):
- `Pester` - 单元测试框架
- `PSScriptAnalyzer` - 代码分析工具
- `platyPS` - 文档生成工具

**云服务模块** (`cloud_modules`):
- `AWS.Tools.Common` - AWS 工具集
- `Az` - Azure 工具集（较大，建议单独下载）

**其他常用模块** (`utility_modules`):
- `ImportExcel` - Excel 文件操作
- `Pscx` - PowerShell 社区扩展

### 版本策略

```ini
# 下载最新版本（默认）
version_policy = latest

# 指定特定版本
version_policy = specific
PSReadLine_version = 2.2.6
Pester_version = 5.4.0
```

### 配置优先级

**命令行参数 > 配置文件 > 默认值**

## 📝 常用模块使用示例

### PSReadLine（命令行增强）

```powershell
# 自动加载，无需手动导入
# 查看配置
Get-PSReadLineOption

# 设置历史搜索
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
```

### posh-git（Git 集成）

```powershell
# 导入模块
Import-Module posh-git

# 查看 Git 状态（在 Git 仓库中）
# 会自动在提示符中显示分支和状态
```

### Pester（单元测试）

```powershell
# 导入模块
Import-Module Pester

# 运行测试
Invoke-Pester

# 生成测试报告
Invoke-Pester -OutputFile report.xml -OutputFormat NUnitXml
```

### ImportExcel（Excel 操作）

```powershell
# 导入模块
Import-Module ImportExcel

# 导出数据到 Excel
Get-Process | Export-Excel -Path processes.xlsx

# 从 Excel 导入数据
$data = Import-Excel -Path data.xlsx
```

## ❓ 常见问题

### Q: 下载模块失败

A:
- 检查网络连接
- 确认 PowerShellGet 已安装：
  ```powershell
  Get-Module -Name PowerShellGet -ListAvailable
  ```
- 如果未安装，先安装 PowerShellGet：
  ```powershell
  Install-Module -Name PowerShellGet -Force
  ```

### Q: 安装模块时提示权限不足

A:
- 安装到 `AllUsers` 需要管理员权限
- 使用 `-Scope CurrentUser` 安装到当前用户目录
- 或以管理员身份运行 PowerShell

### Q: 模块安装后无法导入

A:
- 检查模块是否在 `$env:PSModulePath` 中：
  ```powershell
  $env:PSModulePath -split ';'
  ```
- 重启 PowerShell 会话
- 手动导入模块：
  ```powershell
  Import-Module -Name <模块名> -Verbose
  ```

### Q: 如何查看已安装的模块

A:
```powershell
# 查看所有已安装模块
Get-Module -ListAvailable

# 查看特定模块
Get-Module -Name PSReadLine -ListAvailable

# 查看模块详细信息
Get-Module -Name PSReadLine -ListAvailable | Format-List *
```

### Q: 如何更新模块

A:
1. 在有外网的环境重新下载模块
2. 在离线环境重新运行安装脚本（会覆盖旧版本）

### Q: 如何卸载模块

A:
```powershell
# 卸载模块
Uninstall-Module -Name <模块名>

# 或手动删除模块目录
$modulePath = (Get-Module -Name <模块名> -ListAvailable).ModuleBase
Remove-Item -Path $modulePath -Recurse -Force
```

## 🔧 高级用法

### 批量下载特定版本

编辑 `modules.conf`：
```ini
version_policy = specific
PSReadLine_version = 2.2.6
Pester_version = 5.4.0
posh-git_version = 1.1.0
```

### 下载预发布版本

```ini
allow_prerelease = true
```

### 使用私有模块源

```ini
repository = MyPrivateRepository
```

然后在 PowerShell 中注册私有源：
```powershell
Register-PSRepository -Name MyPrivateRepository `
    -SourceLocation "https://my-nuget-server.com/nuget" `
    -InstallationPolicy Trusted
```

## 📚 相关资源

- [PowerShell Gallery](https://www.powershellgallery.com/) - 官方模块仓库
- [PowerShellGet 文档](https://docs.microsoft.com/powershell/module/powershellget/)
- [PSReadLine 文档](https://docs.microsoft.com/powershell/module/psreadline/)
- [Pester 文档](https://pester.dev/)

## 📄 许可

这些脚本仅供个人使用，遵循相关模块的开源协议。

---

**享受你的 PowerShell 开发体验！**

如有问题，请检查：
1. 是否以管理员权限运行 PowerShell（安装到 AllUsers 时）
2. PowerShellGet 模块是否已安装
3. 离线资源是否完整下载
