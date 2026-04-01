# PowerShell 模块离线下载脚本
#
# 【流程位置】离线路线 - 步骤 1/2（在有外网的环境运行）
# 【下一步骤】offline-install-modules.ps1（在离线环境运行）
#
# 功能：下载 PowerShell 模块及其依赖到本地
# 产出：offline-modules/ 目录（包含模块文件和安装脚本）
#
# 使用方法:
#   .\download-modules.ps1
#   .\download-modules.ps1 -OutputPath ".\offline-modules"
#   .\download-modules.ps1 -ConfigFile ".\modules.conf"
#
# 详细工作流程请参考: README.md

param(
    [string]$OutputPath,
    [string]$ConfigFile,
    [string]$Repository = "PSGallery"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PowerShell 模块离线下载" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 加载配置文件
# ============================================

# 默认配置
$Config = @{
    OutputPath = ".\offline-modules"
    PowerShellVersion = "5.1"
    Repository = "PSGallery"
    TrustRepository = $true
    BasicModules = @("PSReadLine", "posh-git", "Terminal-Icons")
    DevModules = @("Pester", "PSScriptAnalyzer", "platyPS")
    CloudModules = @()
    UtilityModules = @("ImportExcel", "Pscx")
    IncludeDependencies = $true
    AllowPrerelease = $false
    VersionPolicy = "latest"
    SpecificVersions = @{}
    GenerateManifest = $true
    GenerateInstallScript = $true
    VerifySignature = $false
}

# 配置文件路径（自动检测）
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot "modules.conf"
}

# 加载配置文件
function Load-Config {
    param($ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[*] 未找到配置文件，使用默认配置" -ForegroundColor Yellow
        return
    }
    
    Write-Host "[*] 加载配置文件: $ConfigPath" -ForegroundColor Gray
    
    Get-Content $ConfigPath | ForEach-Object {
        $line = $_.Trim()
        
        # 跳过注释和空行
        if ($line -match '^#' -or $line -match '^$') {
            return
        }
        
        # 解析 key = value
        if ($line -match '^(\w+)\s*=\s*(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # 移除行内注释
            if ($value -match '^([^\#]+)\s*\#') {
                $value = $matches[1].Trim()
            }
            
            # 根据键名设置配置
            switch ($key) {
                "output" { 
                    if (-not $OutputPath) { $Config.OutputPath = $value }
                }
                "powershell_version" { 
                    $Config.PowerShellVersion = $value 
                }
                "repository" { 
                    if (-not $Repository) { $Config.Repository = $value }
                }
                "trust_repository" {
                    $Config.TrustRepository = ($value -eq 'true')
                }
                "basic_modules" {
                    $Config.BasicModules = $value -split '[\s,]+'
                }
                "dev_modules" {
                    $Config.DevModules = $value -split '[\s,]+'
                }
                "cloud_modules" {
                    $Config.CloudModules = $value -split '[\s,]+'
                }
                "utility_modules" {
                    $Config.UtilityModules = $value -split '[\s,]+'
                }
                "include_dependencies" {
                    $Config.IncludeDependencies = ($value -eq 'true')
                }
                "allow_prerelease" {
                    $Config.AllowPrerelease = ($value -eq 'true')
                }
                "version_policy" {
                    $Config.VersionPolicy = $value
                }
                "generate_manifest" {
                    $Config.GenerateManifest = ($value -eq 'true')
                }
                "generate_install_script" {
                    $Config.GenerateInstallScript = ($value -eq 'true')
                }
                # 处理特定版本配置
                { $_ -match '^(.+)_version$' } {
                    $moduleName = $matches[1]
                    $Config.SpecificVersions[$moduleName] = $value
                }
            }
        }
    }
}

# 加载配置
Load-Config -ConfigPath $ConfigFile

# 命令行参数覆盖
if ($OutputPath) { $Config.OutputPath = $OutputPath }
if ($Repository -ne "PSGallery") { $Config.Repository = $Repository }

Write-Host "[*] 输出目录: $($Config.OutputPath)" -ForegroundColor Gray
Write-Host "[*] 模块源: $($Config.Repository)" -ForegroundColor Gray
Write-Host ""

# ============================================
# 检查 PowerShellGet
# ============================================

Write-Host "[1/5] 检查 PowerShellGet..." -ForegroundColor Green

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[!] 需要 PowerShell 5.1 或更高版本" -ForegroundColor Red
    exit 1
}

# 检查 PowerShellGet 模块
if (-not (Get-Module -ListAvailable -Name PowerShellGet)) {
    Write-Host "[!] PowerShellGet 模块未安装" -ForegroundColor Red
    Write-Host "    请先安装 PowerShellGet: Install-Module -Name PowerShellGet -Force" -ForegroundColor Yellow
    exit 1
}

Write-Host "    -> PowerShellGet 已安装" -ForegroundColor Gray

# ============================================
# 注册模块源
# ============================================

Write-Host "`n[2/5] 配置模块源..." -ForegroundColor Green

# 检查并注册 PSGallery
$repo = Get-PSRepository -Name $Config.Repository -ErrorAction SilentlyContinue
if (-not $repo) {
    if ($Config.Repository -eq "PSGallery") {
        Write-Host "    -> 注册 PSGallery..." -ForegroundColor Gray
        Register-PSRepository -Default -ErrorAction SilentlyContinue
    } else {
        Write-Host "[!] 找不到模块源: $($Config.Repository)" -ForegroundColor Red
        exit 1
    }
}

if ($Config.TrustRepository) {
    Set-PSRepository -Name $Config.Repository -InstallationPolicy Trusted
    Write-Host "    -> 已信任模块源: $($Config.Repository)" -ForegroundColor Gray
}

# ============================================
# 准备输出目录
# ============================================

Write-Host "`n[3/5] 准备输出目录..." -ForegroundColor Green

$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config.OutputPath)
$modulesPath = Join-Path $OutputPath "modules"
$scriptsPath = Join-Path $OutputPath "scripts"

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
New-Item -ItemType Directory -Force -Path $modulesPath | Out-Null
New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

Write-Host "    -> 输出目录: $OutputPath" -ForegroundColor Gray

# ============================================
# 下载模块
# ============================================

Write-Host "`n[4/5] 下载模块..." -ForegroundColor Green

# 合并所有模块列表
$allModules = @()
$allModules += $Config.BasicModules
$allModules += $Config.DevModules
$allModules += $Config.CloudModules
$allModules += $Config.UtilityModules

# 移除空值和重复项
$allModules = $allModules | Where-Object { $_ } | Select-Object -Unique

# 确保 PowerShellGet 和 PackageManagement 始终包含
@("PowerShellGet", "PackageManagement") | ForEach-Object {
    if ($allModules -notcontains $_) {
        $allModules = @($_) + $allModules
    }
}

Write-Host "    -> 共需下载 $($allModules.Count) 个模块" -ForegroundColor Gray
Write-Host ""

$downloadedModules = @()
$failedModules = @()

foreach ($moduleName in $allModules) {
    Write-Host "    -> $moduleName" -ForegroundColor Gray -NoNewline
    
    try {
        # 确定版本
        $version = $null
        if ($Config.VersionPolicy -eq "specific" -and $Config.SpecificVersions.ContainsKey($moduleName)) {
            $version = $Config.SpecificVersions[$moduleName]
        }
        
        # 下载模块
        $saveParams = @{
            Name = $moduleName
            Path = $modulesPath
            Repository = $Config.Repository
            Force = $true
        }
        
        if ($version) {
            $saveParams.RequiredVersion = $version
        }
        
        if ($Config.AllowPrerelease) {
            $saveParams.AllowPrerelease = $true
        }
        
        # Save-Module 默认会包含依赖
        if (-not $Config.IncludeDependencies) {
            # 注意：PowerShellGet 1.x 不支持排除依赖
            # 如果需要排除依赖，需要手动处理
        }
        
        Save-Module @saveParams
        
        Write-Host " ✓" -ForegroundColor Green
        $downloadedModules += $moduleName
    } catch {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "       错误: $($_.Exception.Message)" -ForegroundColor DarkGray
        $failedModules += $moduleName
    }
}

Write-Host ""
Write-Host "    -> 成功: $($downloadedModules.Count) 个" -ForegroundColor Green
if ($failedModules.Count -gt 0) {
    Write-Host "    -> 失败: $($failedModules.Count) 个" -ForegroundColor Yellow
    Write-Host "       $($failedModules -join ', ')" -ForegroundColor DarkGray
}

# ============================================
# 生成安装脚本和清单
# ============================================

Write-Host "`n[5/5] 生成安装脚本和清单..." -ForegroundColor Green

# 复制安装脚本
if ($Config.GenerateInstallScript) {
    $installScript = Join-Path $PSScriptRoot "offline-install-modules.ps1"
    if (Test-Path $installScript) {
        Copy-Item -Path $installScript -Destination $scriptsPath -Force
        Write-Host "    -> 已复制安装脚本" -ForegroundColor Gray
    }
}

# 生成模块清单
if ($Config.GenerateManifest) {
    $manifest = @{
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        powershell_version = $Config.PowerShellVersion
        repository = $Config.Repository
        modules_downloaded = $downloadedModules
        modules_failed = $failedModules
        total_modules = (Get-ChildItem $modulesPath -Directory).Count
    }
    
    $manifest | ConvertTo-Json | Out-File (Join-Path $OutputPath "manifest.json") -Encoding UTF8
    Write-Host "    -> 已生成模块清单" -ForegroundColor Gray
}

# ============================================
# 完成
# ============================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  下载完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 统计信息
$moduleCount = (Get-ChildItem $modulesPath -Directory).Count
$totalSize = (Get-ChildItem $OutputPath -Recurse | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "离线模块已保存到: $OutputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "资源统计:" -ForegroundColor Cyan
Write-Host "  • 模块数量: $moduleCount 个" -ForegroundColor White
Write-Host "  • 总大小: $totalSizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "文件结构:" -ForegroundColor Cyan
Write-Host "  ├── modules/     (模块文件)" -ForegroundColor White
Write-Host "  ├── scripts/     (安装脚本)" -ForegroundColor White
Write-Host "  └── manifest.json" -ForegroundColor White
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 将 '$(Split-Path $OutputPath -Leaf)' 文件夹拷贝到离线环境" -ForegroundColor White
Write-Host "  2. 在离线环境运行: .\scripts\offline-install-modules.ps1" -ForegroundColor White
Write-Host ""
