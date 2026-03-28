# 离线资源下载脚本（改进版）
# 在有外网的环境运行，自动安装 MSYS2 并下载所有离线资源
# 使用方法:
#   .\download-resources.ps1
#   .\download-resources.ps1 -OutputPath ".\offline-resources"
#   .\download-resources.ps1 -ConfigFile ".\config.conf"

param(
    [string]$OutputPath,
    [string]$Msys2InstallPath = "C:\msys64-temp",
    [string]$ConfigFile,
    [string]$Msys2Mirror,
    [string]$GitHubMirror
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSYS2 离线资源下载脚本（改进版）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 加载配置文件
# ============================================

# 默认配置
$Config = @{
    OutputPath = ".\offline-resources"
    Msys2Mirror = "https://repo.msys2.org/distrib"
    GitHubMirror = "https://github.com"
    Packages = @("git", "curl", "wget", "vim", "nano", "zsh", "tar", "unzip", "man-db", "bat", "fd", "ripgrep", "fzf", "zoxide")
    UCRT64Packages = @("eza")
    DownloadFont = $true
}

# 配置文件路径（自动检测）
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot "config.conf"
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
                "msys2_mirror" { 
                    if (-not $Msys2Mirror) { $Config.Msys2Mirror = $value }
                }
                "github_mirror" { 
                    if (-not $GitHubMirror) { $Config.GitHubMirror = $value }
                }
                "packages" {
                    $Config.Packages = $value -split '\s+'
                }
                "ucrt64_packages" {
                    $Config.UCRT64Packages = $value -split '\s+'
                }
                "download_font" {
                    $Config.DownloadFont = ($value -eq 'true')
                }
            }
        }
    }
}

# 加载配置（优先级：命令行参数 > 配置文件 > 默认值）
Load-Config -ConfigPath $ConfigFile

# 命令行参数覆盖配置文件
if ($OutputPath) { $Config.OutputPath = $OutputPath }
if ($Msys2Mirror) { $Config.Msys2Mirror = $Msys2Mirror }
if ($GitHubMirror) { $Config.GitHubMirror = $GitHubMirror }

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] 请以管理员身份运行此脚本" -ForegroundColor Red
    exit 1
}

# 创建输出目录
$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config.OutputPath)
$packagesPath = Join-Path $OutputPath "packages"
$toolsPath = Join-Path $OutputPath "tools"
$scriptsPath = Join-Path $OutputPath "scripts"

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
New-Item -ItemType Directory -Force -Path $packagesPath | Out-Null
New-Item -ItemType Directory -Force -Path $toolsPath | Out-Null
New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

Write-Host "[*] 输出目录: $OutputPath" -ForegroundColor Gray
Write-Host "[*] MSYS2 镜像: $($Config.Msys2Mirror)" -ForegroundColor Gray
Write-Host "[*] GitHub 镜像: $($Config.GitHubMirror)" -ForegroundColor Gray
Write-Host ""

# ============================================
# Step 1: 下载 MSYS2 安装包
# ============================================
Write-Host "[1/7] 下载 MSYS2 安装包..." -ForegroundColor Green

$msys2Url = "$($Config.Msys2Mirror)/msys2-x86_64-latest.exe"
$msys2Exe = "msys2-x86_64-latest.exe"
$msys2Dest = Join-Path $OutputPath $msys2Exe

if (Test-Path $msys2Dest) {
    Write-Host "    -> 已存在，跳过" -ForegroundColor Yellow
} else {
    try {
        Write-Host "    -> 下载 $msys2Url" -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($msys2Url, $msys2Dest)
        Write-Host "    -> 完成" -ForegroundColor Gray
    } catch {
        Write-Host "[!] 下载失败: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================================
# Step 2: 临时安装 MSYS2
# ============================================
Write-Host "[2/7] 临时安装 MSYS2（用于下载软件包）..." -ForegroundColor Green

if (Test-Path $Msys2InstallPath) {
    Write-Host "    -> 检测到已存在，重新安装" -ForegroundColor Yellow
    Remove-Item -Path $Msys2InstallPath -Recurse -Force
}

try {
    Start-Process -FilePath $msys2Dest `
        -ArgumentList "install --root $Msys2InstallPath --confirm-command" `
        -Wait -NoNewWindow
    Write-Host "    -> 临时安装完成" -ForegroundColor Gray
} catch {
    Write-Host "[!] 安装失败: $_" -ForegroundColor Red
    exit 1
}

# ============================================
# Step 3: 首次更新 MSYS2
# ============================================
Write-Host "[3/7] 更新 MSYS2 系统..." -ForegroundColor Green

try {
    # 第一次更新
    Start-Process -FilePath "$Msys2InstallPath\msys2_shell.cmd" `
        -ArgumentList "-ucrt64", "-defterm", "-no-start", "-c", "pacman -Syu --noconfirm --ask=20" `
        -Wait -NoNewWindow
    
    # 第二次更新
    Start-Process -FilePath "$Msys2InstallPath\msys2_shell.cmd" `
        -ArgumentList "-ucrt64", "-defterm", "-no-start", "-c", "pacman -Su --noconfirm" `
        -Wait -NoNewWindow
    
    Write-Host "    -> 系统更新完成" -ForegroundColor Gray
} catch {
    Write-Host "    -> 更新可能未完全成功，继续..." -ForegroundColor Yellow
}

# ============================================
# Step 4: 下载软件包
# ============================================
Write-Host "[4/7] 下载所有需要的软件包..." -ForegroundColor Green

# 创建下载脚本
$packagesList = $Config.Packages -join " "
$ucrt64List = ($Config.UCRT64Packages | ForEach-Object { "mingw-w64-ucrt-x86_64-$_" }) -join " "

$downloadScript = @"
#!/bin/bash
# 批量下载软件包

# 更新软件源
pacman -Sy

# 定义需要的包
PACKAGES=(
    $packagesList
    libpcre libpcre2 ncurses readline gdbm
)

UCRT64_PACKAGES=(
    $ucrt64List
)

echo "下载 MSYS2 包..."
for pkg in "\${PACKAGES[@]}"; do
    echo "  -> \$pkg"
    pacman -Sw --noconfirm --needed "\$pkg" 2>/dev/null || true
done

echo "下载 UCRT64 包..."
for pkg in "\${UCRT64_PACKAGES[@]}"; do
    echo "  -> \$pkg"
    pacman -Sw --noconfirm --needed "\$pkg" 2>/dev/null || true
done

echo "下载完成！"
"@

$scriptPath = Join-Path $Msys2InstallPath "download-pkgs.sh"
$downloadScript | Out-File -FilePath $scriptPath -Encoding ASCII -NoNewline

# 在 MSYS2 中运行下载脚本
try {
    Start-Process -FilePath "$Msys2InstallPath\msys2_shell.cmd" `
        -ArgumentList "-ucrt64", "-defterm", "-no-start", "-c", "bash /download-pkgs.sh" `
        -Wait -NoNewWindow
    
    Write-Host "    -> 软件包下载完成" -ForegroundColor Gray
} catch {
    Write-Host "    -> 部分包可能下载失败，继续..." -ForegroundColor Yellow
}

# ============================================
# Step 5: 复制软件包到输出目录
# ============================================
Write-Host "[5/7] 复制软件包..." -ForegroundColor Green

$cacheDir = "$Msys2InstallPath\var\cache\pacman\pkg"
$pkgFiles = Get-ChildItem -Path $cacheDir -Filter "*.pkg.tar.*"

if ($pkgFiles.Count -gt 0) {
    $pkgFiles | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $packagesPath -Force
    }
    Write-Host "    -> 已复制 $($pkgFiles.Count) 个软件包" -ForegroundColor Gray
} else {
    Write-Host "    -> 未找到软件包文件" -ForegroundColor Yellow
}

# ============================================
# Step 6: 下载工具和插件
# ============================================
Write-Host "[6/7] 下载工具和插件..." -ForegroundColor Green

$webClient = New-Object System.Net.WebClient

# Oh My Zsh
Write-Host "    -> Oh My Zsh" -ForegroundColor Gray
$ohmyzshUrl = "$($Config.GitHubMirror)/ohmyzsh/ohmyzsh/archive/refs/heads/master.zip"
$ohmyzshZip = Join-Path $toolsPath "oh-my-zsh.zip"
try {
    $webClient.DownloadFile($ohmyzshUrl, $ohmyzshZip)
} catch {
    Write-Host "       失败: $_" -ForegroundColor Yellow
}

# zsh-autosuggestions
Write-Host "    -> zsh-autosuggestions" -ForegroundColor Gray
$autosuggestUrl = "$($Config.GitHubMirror)/zsh-users/zsh-autosuggestions/archive/refs/heads/master.zip"
$autosuggestZip = Join-Path $toolsPath "zsh-autosuggestions.zip"
try {
    $webClient.DownloadFile($autosuggestUrl, $autosuggestZip)
} catch {
    Write-Host "       失败: $_" -ForegroundColor Yellow
}

# zsh-syntax-highlighting
Write-Host "    -> zsh-syntax-highlighting" -ForegroundColor Gray
$syntaxUrl = "$($Config.GitHubMirror)/zsh-users/zsh-syntax-highlighting/archive/refs/heads/master.zip"
$syntaxZip = Join-Path $toolsPath "zsh-syntax-highlighting.zip"
try {
    $webClient.DownloadFile($syntaxUrl, $syntaxZip)
} catch {
    Write-Host "       失败: $_" -ForegroundColor Yellow
}

# Starship
Write-Host "    -> Starship" -ForegroundColor Gray
$starshipUrl = "$($Config.GitHubMirror)/starship/starship/releases/latest/download/starship-x86_64-pc-windows-msvc.zip"
$starshipZip = Join-Path $toolsPath "starship.zip"
try {
    $webClient.DownloadFile($starshipUrl, $starshipZip)
    
    # 解压到临时目录
    $tempDir = Join-Path $env:TEMP "starship-temp"
    Expand-Archive -Path $starshipZip -DestinationPath $tempDir -Force
    
    # 移动 exe 到工具目录
    Move-Item -Path "$tempDir\starship.exe" -Destination $toolsPath -Force
    Remove-Item -Path $starshipZip -Force
    Remove-Item -Path $tempDir -Recurse -Force
} catch {
    Write-Host "       失败: $_" -ForegroundColor Yellow
}

# Nerd Font（可选）
if ($Config.DownloadFont) {
    Write-Host "    -> JetBrains Mono Nerd Font" -ForegroundColor Gray
    $fontUrl = "$($Config.GitHubMirror)/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $fontZip = Join-Path $toolsPath "JetBrainsMono-Nerd-Font.zip"
    try {
        $webClient.DownloadFile($fontUrl, $fontZip)
    } catch {
        Write-Host "       失败: $_" -ForegroundColor Yellow
    }
}

Write-Host "    -> 工具下载完成" -ForegroundColor Gray

# ============================================
# Step 7: 复制安装脚本并清理
# ============================================
Write-Host "[7/7] 复制安装脚本..." -ForegroundColor Green

# 复制脚本
$scripts = @(
    "offline-install-msys2.ps1",
    "offline-setup-zsh.sh"
)

foreach ($script in $scripts) {
    $src = Join-Path $PSScriptRoot $script
    $dst = Join-Path $scriptsPath $script
    
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "    -> $script" -ForegroundColor Gray
    }
}

# 创建资源清单
$manifest = @{
    created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    msys2_installer = $msys2Exe
    packages_count = (Get-ChildItem $packagesPath -Filter "*.pkg.tar.*").Count
    tools = @(
        "oh-my-zsh.zip",
        "zsh-autosuggestions.zip",
        "zsh-syntax-highlighting.zip",
        "starship.exe",
        "JetBrainsMono-Nerd-Font.zip"
    )
}

$manifest | ConvertTo-Json | Out-File (Join-Path $OutputPath "manifest.json") -Encoding UTF8

# 清理临时 MSYS2
Write-Host ""
Write-Host "[*] 清理临时文件..." -ForegroundColor Yellow
if (Test-Path $Msys2InstallPath) {
    Remove-Item -Path $Msys2InstallPath -Recurse -Force
}

# ============================================
# 完成
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  下载完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "离线资源已保存到: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# 统计信息
$pkgCount = (Get-ChildItem $packagesPath -Filter "*.pkg.tar.*").Count
$toolCount = (Get-ChildItem $toolsPath -File).Count
$totalSize = (Get-ChildItem $OutputPath -Recurse | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "资源统计:" -ForegroundColor Cyan
Write-Host "  • 软件包: $pkgCount 个" -ForegroundColor White
Write-Host "  • 工具: $toolCount 个" -ForegroundColor White
Write-Host "  • 总大小: $totalSizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "文件结构:" -ForegroundColor Cyan
Write-Host "  ├── msys2-x86_64-latest.exe" -ForegroundColor White
Write-Host "  ├── packages/    ($pkgCount 个软件包)" -ForegroundColor White
Write-Host "  ├── tools/       (工具和插件)" -ForegroundColor White
Write-Host "  ├── scripts/     (安装脚本)" -ForegroundColor White
Write-Host "  └── manifest.json" -ForegroundColor White
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 将 '$(Split-Path $OutputPath -Leaf)' 文件夹拷贝到离线环境" -ForegroundColor White
Write-Host "  2. 在离线环境运行: .\scripts\offline-install-msys2.ps1" -ForegroundColor White
Write-Host "  3. 在 MSYS2 中运行: bash ~/scripts/offline-setup-zsh.sh" -ForegroundColor White
Write-Host ""
