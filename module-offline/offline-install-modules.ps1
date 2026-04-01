# PowerShell 模块离线安装脚本
#
# 【流程位置】离线路线 - 步骤 2/2（在离线环境运行）
# 【前置步骤】download-modules.ps1（在有外网的环境运行）
#
# 功能：从本地文件安装 PowerShell 模块
# 产出：模块安装到 $env:PSModulePath
#
# 使用方法: .\offline-install-modules.ps1 -ResourcesPath ".\offline-modules"
#
# 详细工作流程请参考: README.md

param(
    [string]$ResourcesPath = ".\offline-modules",
    [string]$Scope = "CurrentUser"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PowerShell 模块离线安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 转换为绝对路径
$ResourcesPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ResourcesPath)
$modulesPath = Join-Path $ResourcesPath "modules"
$manifestPath = Join-Path $ResourcesPath "manifest.json"

Write-Host "[*] 离线资源路径: $ResourcesPath" -ForegroundColor Gray
Write-Host "[*] 安装范围: $Scope" -ForegroundColor Gray
Write-Host ""

# ============================================
# 检查资源文件
# ============================================

Write-Host "[1/4] 检查资源文件..." -ForegroundColor Green

if (-not (Test-Path $ResourcesPath)) {
    Write-Host "[!] 找不到离线资源目录: $ResourcesPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $modulesPath)) {
    Write-Host "[!] 找不到模块目录: $modulesPath" -ForegroundColor Red
    exit 1
}

# 加载清单（如果存在）
$manifest = $null
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        Write-Host "    -> 找到模块清单" -ForegroundColor Gray
        Write-Host "    -> 创建时间: $($manifest.created)" -ForegroundColor Gray
        Write-Host "    -> 模块数量: $($manifest.total_modules)" -ForegroundColor Gray
    } catch {
        Write-Host "    -> 清单文件格式错误，继续..." -ForegroundColor Yellow
    }
}

# ============================================
# 准备安装环境
# ============================================

Write-Host "`n[2/4] 准备安装环境..." -ForegroundColor Green

# 检查安装范围
if ($Scope -eq "AllUsers") {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "[!] 安装到 AllUsers 需要管理员权限" -ForegroundColor Red
        Write-Host "    请以管理员身份运行 PowerShell" -ForegroundColor Yellow
        exit 1
    }
}

# 获取模块安装路径
$modulePaths = $env:PSModulePath -split ';'
if ($Scope -eq "CurrentUser") {
    $installPath = $modulePaths | Where-Object { $_ -match "Documents" } | Select-Object -First 1
    if (-not $installPath) {
        # 创建用户模块路径
        $installPath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
        New-Item -ItemType Directory -Force -Path $installPath | Out-Null
    }
} else {
    $installPath = $modulePaths | Where-Object { $_ -match "Program Files" } | Select-Object -First 1
}

Write-Host "    -> 安装路径: $installPath" -ForegroundColor Gray

# ============================================
# 安装模块
# ============================================

Write-Host "`n[3/4] 安装模块..." -ForegroundColor Green

# 获取所有模块目录
$moduleDirs = Get-ChildItem -Path $modulesPath -Directory

if ($moduleDirs.Count -eq 0) {
    Write-Host "    -> 未找到模块文件" -ForegroundColor Yellow
    exit 0
}

Write-Host "    -> 找到 $($moduleDirs.Count) 个模块" -ForegroundColor Gray
Write-Host ""

$installedModules = @()
$skippedModules = @()
$failedModules = @()

foreach ($moduleDir in $moduleDirs) {
    $moduleName = $moduleDir.Name
    Write-Host "    -> $moduleName" -ForegroundColor Gray -NoNewline
    
    try {
        # 检查模块是否已安装
        $existingModule = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue
        
        if ($existingModule) {
            Write-Host " (已安装)" -ForegroundColor Yellow
            $skippedModules += $moduleName
            continue
        }
        
        # 复制模块到安装路径
        $destPath = Join-Path $installPath $moduleName
        
        # 如果目标路径已存在，先删除
        if (Test-Path $destPath) {
            Remove-Item -Path $destPath -Recurse -Force
        }
        
        # 复制模块
        Copy-Item -Path $moduleDir.FullName -Destination $destPath -Recurse -Force
        
        Write-Host " ✓" -ForegroundColor Green
        $installedModules += $moduleName
    } catch {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "       错误: $($_.Exception.Message)" -ForegroundColor DarkGray
        $failedModules += $moduleName
    }
}

Write-Host ""
Write-Host "    -> 已安装: $($installedModules.Count) 个" -ForegroundColor Green
Write-Host "    -> 已跳过: $($skippedModules.Count) 个" -ForegroundColor Yellow
if ($failedModules.Count -gt 0) {
    Write-Host "    -> 失败: $($failedModules.Count) 个" -ForegroundColor Red
    Write-Host "       $($failedModules -join ', ')" -ForegroundColor DarkGray
}

# ============================================
# 验证安装
# ============================================

Write-Host "`n[4/4] 验证安装..." -ForegroundColor Green

$verifiedCount = 0
foreach ($moduleName in $installedModules) {
    $module = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue
    if ($module) {
        $verifiedCount++
    }
}

Write-Host "    -> 验证通过: $verifiedCount 个模块" -ForegroundColor Gray

# ============================================
# 完成
# ============================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "已安装到: $installPath" -ForegroundColor Cyan
Write-Host ""

if ($installedModules.Count -gt 0) {
    Write-Host "新安装的模块:" -ForegroundColor Cyan
    $installedModules | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor White
    }
    Write-Host ""
}

if ($skippedModules.Count -gt 0) {
    Write-Host "已存在的模块（跳过）:" -ForegroundColor Yellow
    $skippedModules | ForEach-Object {
        Write-Host "  • $_" -ForegroundColor DarkGray
    }
    Write-Host ""
}

Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 重启 PowerShell 或运行: `$env:PSModulePath" -ForegroundColor White
Write-Host "  2. 查看已安装模块: Get-Module -ListAvailable" -ForegroundColor White
Write-Host "  3. 导入模块: Import-Module -Name <模块名>" -ForegroundColor White
Write-Host ""

# 显示常用模块的使用提示
Write-Host "常用模块使用提示:" -ForegroundColor Cyan
Write-Host "  • PSReadLine: 自动加载，提供命令行增强" -ForegroundColor White
Write-Host "  • posh-git: Import-Module posh-git" -ForegroundColor White
Write-Host "  • Pester: Invoke-Pester" -ForegroundColor White
Write-Host "  • ImportExcel: Import-Excel <文件路径>" -ForegroundColor White
Write-Host ""
