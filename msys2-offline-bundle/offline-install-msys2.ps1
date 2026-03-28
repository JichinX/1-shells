# 离线环境 MSYS2 安装脚本
# 在离线环境中运行，从本地资源安装 MSYS2
# 使用方法: .\offline-install-msys2.ps1 -ResourcesPath ".\offline-resources"

param(
    [string]$ResourcesPath = ".\offline-resources",
    [string]$InstallPath = "C:\msys64"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  离线环境 MSYS2 安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 转换为绝对路径
$ResourcesPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ResourcesPath)
$packagesPath = Join-Path $ResourcesPath "packages"
$toolsPath = Join-Path $ResourcesPath "tools"
$scriptsPath = Join-Path $ResourcesPath "scripts"

Write-Host "[*] 离线资源路径: $ResourcesPath" -ForegroundColor Gray
Write-Host "[*] 安装路径: $InstallPath" -ForegroundColor Gray
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] 请以管理员身份运行此脚本" -ForegroundColor Red
    exit 1
}

# 检查资源文件
if (-not (Test-Path $ResourcesPath)) {
    Write-Host "[!] 找不到离线资源目录: $ResourcesPath" -ForegroundColor Red
    exit 1
}

$msys2Installer = Join-Path $ResourcesPath "msys2-x86_64-latest.exe"
if (-not (Test-Path $msys2Installer)) {
    Write-Host "[!] 找不到 MSYS2 安装包: $msys2Installer" -ForegroundColor Red
    exit 1
}

# 检查是否已安装
if (Test-Path $InstallPath) {
    Write-Host "[!] 检测到 MSYS2 已安装在 $InstallPath" -ForegroundColor Yellow
    $continue = Read-Host "是否重新安装？(y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "[*] 跳过安装" -ForegroundColor Yellow
        
        # 仍然复制工具和脚本
        Copy-ToolsAndScripts
        exit 0
    }
    Write-Host "[*] 移除旧版本..." -ForegroundColor Yellow
    Remove-Item -Path $InstallPath -Recurse -Force
}

# ============================================
# Step 1: 安装 MSYS2
# ============================================
Write-Host "`n[1/3] 安装 MSYS2..." -ForegroundColor Green

try {
    Start-Process -FilePath $msys2Installer `
        -ArgumentList "install --root $InstallPath --confirm-command" `
        -Wait -NoNewWindow
    Write-Host "    -> MSYS2 安装完成" -ForegroundColor Gray
} catch {
    Write-Host "[!] 安装失败: $_" -ForegroundColor Red
    exit 1
}

# ============================================
# Step 2: 安装软件包
# ============================================
Write-Host "`n[2/3] 安装离线软件包..." -ForegroundColor Green

# 检查软件包
if (-not (Test-Path $packagesPath)) {
    Write-Host "    -> 未找到软件包目录，跳过" -ForegroundColor Yellow
} else {
    $pkgFiles = Get-ChildItem -Path $packagesPath -Filter "*.pkg.tar.zst" -Recurse
    
    if ($pkgFiles.Count -eq 0) {
        Write-Host "    -> 未找到软件包文件，跳过" -ForegroundColor Yellow
    } else {
        Write-Host "    -> 找到 $($pkgFiles.Count) 个软件包" -ForegroundColor Gray
        
        # 复制软件包到 MSYS2 缓存目录
        $cacheDir = "$InstallPath\var\cache\pacman\pkg"
        New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
        
        foreach ($pkg in $pkgFiles) {
            Copy-Item -Path $pkg.FullName -Destination $cacheDir -Force
        }
        
        Write-Host "    -> 软件包已复制到缓存目录" -ForegroundColor Gray
        
        # 使用 pacman 从本地缓存安装
        Write-Host "    -> 安装软件包（这可能需要几分钟）..." -ForegroundColor Gray
        
        $installCmd = @'
pacman -U --noconfirm /var/cache/pacman/pkg/*.pkg.tar.zst
'@
        
        try {
            # 先同步软件源（使用 bash -lc 确保环境正确）
            Start-Process -FilePath "$InstallPath\msys2_shell.cmd" `
                -ArgumentList "-ucrt64", "-defterm", "-no-start", "-here", "-c", "bash -lc 'pacman -Sy --noconfirm'" `
                -Wait -NoNewWindow
            
            # 再安装软件包（使用 bash 展开通配符）
            Start-Process -FilePath "$InstallPath\msys2_shell.cmd" `
                -ArgumentList "-ucrt64", "-defterm", "-no-start", "-here", "-c", "bash -lc 'pacman -U --noconfirm /var/cache/pacman/pkg/*.pkg.tar.{zst,xz}'" `
                -Wait -NoNewWindow
            
            Write-Host "    -> 软件包安装完成" -ForegroundColor Gray
        } catch {
            Write-Host "    -> 部分软件包可能安装失败，但可以继续" -ForegroundColor Yellow
            Write-Host "    -> 错误: $_" -ForegroundColor Gray
        }
    }
}

# ============================================
# Step 3: 复制工具和脚本
# ============================================

function Copy-ToolsAndScripts {
    Write-Host "`n[3/3] 复制工具和配置脚本..." -ForegroundColor Green
    
    # 复制工具到 MSYS2 用户目录
    $userHome = "$InstallPath\home\$env:USERNAME"
    New-Item -ItemType Directory -Force -Path $userHome | Out-Null
    
    # 复制工具目录
    if (Test-Path $toolsPath) {
        Copy-Item -Path $toolsPath -Destination "$userHome\offline-tools" -Recurse -Force
        Write-Host "    -> 工具已复制到 ~/offline-tools/" -ForegroundColor Gray
    }
    
    # 复制脚本
    if (Test-Path $scriptsPath) {
        Copy-Item -Path $scriptsPath -Destination "$userHome\scripts" -Recurse -Force
        Write-Host "    -> 脚本已复制到 ~/scripts/" -ForegroundColor Gray
    }
    
    # 如果工具目录在 scripts 同级，也复制一份到用户目录
    $toolsDest = "$userHome\offline-tools"
    if (-not (Test-Path $toolsDest)) {
        Copy-Item -Path $toolsPath -Destination $toolsDest -Recurse -Force
    }
}

Copy-ToolsAndScripts

# ============================================
# 完成
# ============================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "已安装到: $InstallPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步操作：" -ForegroundColor Cyan
Write-Host "  1. 启动 MSYS2 UCRT64（开始菜单或 $InstallPath\msys2.exe）" -ForegroundColor White
Write-Host "  2. 运行配置脚本: bash ~/scripts/offline-setup-zsh.sh" -ForegroundColor White
Write-Host "  3. 重启终端" -ForegroundColor White
Write-Host ""
Write-Host "已复制的资源：" -ForegroundColor Cyan
Write-Host "  • 工具和插件: ~/offline-tools/" -ForegroundColor White
Write-Host "  • 配置脚本: ~/scripts/" -ForegroundColor White
Write-Host ""

# 可选：配置 Windows Terminal
Write-Host "可选 - 配置 Windows Terminal：" -ForegroundColor Yellow
Write-Host "  将 MSYS2 UCRT64 添加到 Windows Terminal 以获得更好体验" -ForegroundColor White
Write-Host ""
