# MSYS2 一键安装脚本
# 以管理员身份运行 PowerShell 执行此脚本
# 使用方法: .\install-msys2.ps1

param(
    [string]$InstallPath = "C:\msys64"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSYS2 一键安装脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] 请以管理员身份运行此脚本" -ForegroundColor Red
    exit 1
}

# 检查是否已安装
if (Test-Path $InstallPath) {
    Write-Host "[*] 检测到 MSYS2 已安装在 $InstallPath" -ForegroundColor Yellow
    $continue = Read-Host "是否重新安装？(y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "[*] 跳过安装" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "[*] 移除旧版本..." -ForegroundColor Yellow
    Remove-Item -Path $InstallPath -Recurse -Force
}

# 下载 MSYS2
$msys2Url = "https://repo.msys2.org/distrib/msys2-x86_64-latest.exe"
$msys2Installer = "$env:TEMP\msys2-installer.exe"

Write-Host "[1/4] 下载 MSYS2 安装包..." -ForegroundColor Green
try {
    # 使用 .NET WebClient 以获得更好的下载体验
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($msys2Url, $msys2Installer)
    Write-Host "    -> 下载完成" -ForegroundColor Gray
} catch {
    Write-Host "[!] 下载失败: $_" -ForegroundColor Red
    exit 1
}

# 安装 MSYS2
Write-Host "[2/4] 安装 MSYS2 到 $InstallPath ..." -ForegroundColor Green
try {
    Start-Process -FilePath $msys2Installer -ArgumentList "install --root $InstallPath --confirm-command" -Wait -NoNewWindow
    Write-Host "    -> 安装完成" -ForegroundColor Gray
} catch {
    Write-Host "[!] 安装失败: $_" -ForegroundColor Red
    Remove-Item $msys2Installer -Force -ErrorAction SilentlyContinue
    exit 1
}

# 清理安装包
Remove-Item $msys2Installer -Force -ErrorAction SilentlyContinue

# 首次更新 MSYS2 系统
Write-Host "[3/4] 首次系统更新（这可能需要几分钟）..." -ForegroundColor Green
$updateCmd = @'
pacman -Syu --noconfirm
'@

try {
    # 第一次更新（更新核心包）
    Start-Process -FilePath "$InstallPath\msys2_shell.cmd" `
        -ArgumentList "-ucrt64", "-defterm", "-no-start", "-c", "pacman -Syu --noconfirm --ask=20" `
        -Wait -NoNewWindow
    
    # 第二次更新（更新其他包）
    Start-Process -FilePath "$InstallPath\msys2_shell.cmd" `
        -ArgumentList "-ucrt64", "-defterm", "-no-start", "-c", "pacman -Su --noconfirm" `
        -Wait -NoNewWindow
    
    Write-Host "    -> 系统更新完成" -ForegroundColor Gray
} catch {
    Write-Host "[!] 系统更新可能未完全成功，但可以继续" -ForegroundColor Yellow
}

# 复制配置脚本到 MSYS2
Write-Host "[4/4] 复制配置脚本..." -ForegroundColor Green
$configScript = "$PSScriptRoot\setup-shell.sh"
if (Test-Path $configScript) {
    Copy-Item -Path $configScript -Destination "$InstallPath\home\$env:USERNAME\setup-shell.sh" -Force
    Write-Host "    -> 配置脚本已复制到 MSYS2 用户目录" -ForegroundColor Gray
} else {
    Write-Host "    -> 未找到配置脚本 setup-shell.sh，请手动复制" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步操作：" -ForegroundColor Cyan
Write-Host "  1. 启动 MSYS2 UCRT64（开始菜单或 $InstallPath\msys2.exe）" -ForegroundColor White
Write-Host "  2. 运行配置脚本: bash ~/setup-shell.sh" -ForegroundColor White
Write-Host "  3. 重启终端" -ForegroundColor White
Write-Host ""
Write-Host "可选：配置 Windows Terminal" -ForegroundColor Cyan
Write-Host "  将 MSYS2 UCRT64 添加到 Windows Terminal 以获得更好体验" -ForegroundColor White
Write-Host ""
