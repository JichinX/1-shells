# 离线资源下载脚本
# 在有外网的环境运行，下载所有需要的离线资源
# 使用方法:
#   .\download-resources.ps1
#   .\download-resources.ps1 -OutputPath ".\offline-resources"
#   .\download-resources.ps1 -ConfigFile ".\config.conf"

param(
    [string]$ConfigFile = "",
    [string]$OutputPath = "",
    [string]$Msys2Mirror = "",
    [string]$GitHubMirror = ""
)

$ErrorActionPreference = "Stop"

# ============================================
# 配置默认值
# ============================================
$Config = @{
    Arch = "x86_64"
    Output = ".\offline-resources"
    Msys2Mirror = "https://repo.msys2.org/distrib"
    GitHubMirror = "https://github.com"
    Packages = "git curl wget vim nano zsh tar unzip man-db bat fd ripgrep fzf zoxide"
    Ucrt64Packages = "eza"
    DownloadOhmyzsh = "true"
    ZshPlugins = "zsh-autosuggestions, zsh-syntax-highlighting"
    DownloadStarship = "true"
    DownloadFont = "true"
}

# ============================================
# 读取配置文件
# ============================================
function Load-Config {
    param($ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[!] 配置文件不存在: $ConfigPath" -ForegroundColor Yellow
        return
    }

    Write-Host "[*] 加载配置文件: $ConfigPath" -ForegroundColor Gray

    Get-Content $ConfigPath | ForEach-Object {
        $line = $_.Trim()

        # 跳过空行和注释
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            return
        }

        # 解析 key = value
        if ($line -match "^([a-z_]+)\s*=\s*(.+)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # 移除行内注释
            if ($value -match "^([^#]+)#") {
                $value = $matches[1].Trim()
            }

            switch ($key) {
                "arch"                      { $Config.Arch = $value }
                "output"                    { $Config.Output = $value }
                "msys2_mirror"              { $Config.Msys2Mirror = $value }
                "github_mirror"             { $Config.GitHubMirror = $value }
                "packages"                  { $Config.Packages = $value }
                "ucrt64_packages"           { $Config.Ucrt64Packages = $value }
                "download_ohmyzsh"          { $Config.DownloadOhmyzsh = $value }
                "zsh_plugins"               { $Config.ZshPlugins = $value }
                "download_starship"         { $Config.DownloadStarship = $value }
                "download_font"             { $Config.DownloadFont = $value }
            }
        }
    }

    Write-Host "[*] 配置加载完成" -ForegroundColor Gray
}

# 查找默认配置文件
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $defaultConfig = Join-Path $PSScriptRoot "config.conf"
    if (Test-Path $defaultConfig) {
        $ConfigFile = $defaultConfig
    }
}

# 加载配置文件
if (-not [string]::IsNullOrWhiteSpace($ConfigFile)) {
    Load-Config -ConfigPath $ConfigFile
}

# 命令行参数覆盖配置文件（优先级最高）
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $Config.Output = $OutputPath
}
if (-not [string]::IsNullOrWhiteSpace($Msys2Mirror)) {
    $Config.Msys2Mirror = $Msys2Mirror
}
if (-not [string]::IsNullOrWhiteSpace($GitHubMirror)) {
    $Config.GitHubMirror = $GitHubMirror
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MSYS2 离线资源下载脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[*] 配置信息:" -ForegroundColor Cyan
Write-Host "    输出目录:   $($Config.Output)" -ForegroundColor Gray
Write-Host "    MSYS2 镜像: $($Config.Msys2Mirror)" -ForegroundColor Gray
Write-Host "    GitHub 镜像: $($Config.GitHubMirror)" -ForegroundColor Gray
Write-Host ""

# 创建输出目录
$finalOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config.Output)
$packagesPath = Join-Path $finalOutput "packages"
$toolsPath = Join-Path $finalOutput "tools"
$scriptsPath = Join-Path $finalOutput "scripts"

New-Item -ItemType Directory -Force -Path $finalOutput | Out-Null
New-Item -ItemType Directory -Force -Path $packagesPath | Out-Null
New-Item -ItemType Directory -Force -Path $toolsPath | Out-Null
New-Item -ItemType Directory -Force -Path $scriptsPath | Out-Null

Write-Host "[*] 输出目录: $finalOutput" -ForegroundColor Gray

# ============================================
# 1. 下载 MSYS2 安装包
# ============================================
Write-Host "`n[1/6] 下载 MSYS2 安装包..." -ForegroundColor Green

$msys2Exe = "msys2-$($Config.Arch)-latest.exe"
$msys2Url = "$($Config.Msys2Mirror)/$msys2Exe"
$msys2Dest = Join-Path $finalOutput $msys2Exe

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
# 2. 下载 MSYS2 软件包
# ============================================
Write-Host "`n[2/6] 下载 MSYS2 软件包..." -ForegroundColor Green

# 需要下载的包列表（从配置文件读取）
if ($Config.Packages -and $Config.Packages.Count -gt 0) {
    $packages = $Config.Packages
} else {
    $packages = @(
        # 基础工具
        "git",
        "curl",
        "wget",
        "vim",
        "nano",
        "zsh",
        "tar",
        "unzip",
        "man-db",
        
        # 现代 CLI 工具
        "bat",
        "fd",
        "ripgrep",
        "fzf",
        "zoxide"
    )
}

# UCRT64 特定包（从配置文件读取）
if ($Config.Ucrt64Packages -and $Config.Ucrt64Packages.Count -gt 0) {
    $ucrt64Packages = $Config.Ucrt64Packages
} else {
    $ucrt64Packages = @("eza")
}

# 数据库 URL
$msys2RepoUrl = "https://repo.msys2.org/msys/x86_64"
$ucrt64RepoUrl = "https://repo.msys2.org/mingw/ucrt64"

# 下载函数
function Download-Package {
    param($PackageName, $RepoUrl, $OutputDir)
    
    Write-Host "    -> 正在下载: $PackageName" -ForegroundColor Gray -NoNewline
    
    # 获取包数据库
    $dbFile = "$RepoUrl/$PackageName.files.tar.zst"
    $pkgFile = "$RepoUrl/$PackageName-*.pkg.tar.zst"
    
    # 简化：直接下载最新版本的包
    # 实际上需要解析数据库，这里用简化版本
    try {
        # 获取包列表
        $listing = (Invoke-WebRequest -Uri "$RepoUrl/" -UseBasicParsing).Links | 
                   Where-Object { $_.href -match "^$PackageName-[0-9]" }
        
        if ($listing) {
            $latestPkg = $listing | Sort-Object -Property href -Descending | Select-Object -First 1
            $pkgUrl = "$RepoUrl/$($latestPkg.href)"
            $pkgDest = Join-Path $OutputDir $latestPkg.href
            
            if (-not (Test-Path $pkgDest)) {
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($pkgUrl, $pkgDest)
                Write-Host " ✓" -ForegroundColor Green
            } else {
                Write-Host " (已存在)" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "       错误: $_" -ForegroundColor Red
    }
}

# 下载 MSYS2 包
foreach ($pkg in $packages) {
    Download-Package -PackageName $pkg -RepoUrl $msys2RepoUrl -OutputDir $packagesPath
}

# 下载 UCRT64 包
$ucrt64PkgPath = Join-Path $packagesPath "ucrt64"
New-Item -ItemType Directory -Force -Path $ucrt64PkgPath | Out-Null

foreach ($pkg in $ucrt64Packages) {
    $fullPkgName = "mingw-w64-ucrt-x86_64-$pkg"
    Download-Package -PackageName $fullPkgName -RepoUrl $ucrt64RepoUrl -OutputDir $ucrt64PkgPath
}

Write-Host "    -> 软件包下载完成" -ForegroundColor Gray

# ============================================
# 3. 下载 Oh My Zsh
# ============================================
Write-Host "`n[3/6] 下载 Oh My Zsh..." -ForegroundColor Green

$ohmyzshPath = Join-Path $toolsPath "oh-my-zsh"
$ohmyzshUrl = "$($Config.GitHubMirror)/ohmyzsh/ohmyzsh/archive/refs/heads/master.zip"

if (Test-Path $ohmyzshPath) {
    Write-Host "    -> 已存在，跳过" -ForegroundColor Yellow
} else {
    try {
        $tempZip = Join-Path $env:TEMP "ohmyzsh.zip"
        Write-Host "    -> 下载 $ohmyzshUrl" -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($ohmyzshUrl, $tempZip)
        
        Expand-Archive -Path $tempZip -DestinationPath $toolsPath -Force
        Rename-Item -Path (Join-Path $toolsPath "ohmyzsh-master") -NewName "oh-my-zsh" -Force
        
        Remove-Item $tempZip -Force
        Write-Host "    -> 完成" -ForegroundColor Gray
    } catch {
        Write-Host "[!] 下载失败: $_" -ForegroundColor Red
    }
}

# 下载 zsh 插件
Write-Host "    -> 下载 zsh-autosuggestions" -ForegroundColor Gray
$autosuggestUrl = "$($Config.GitHubMirror)/zsh-users/zsh-autosuggestions/archive/refs/heads/master.zip"
$autosuggestPath = Join-Path $toolsPath "zsh-autosuggestions"

if (-not (Test-Path $autosuggestPath)) {
    try {
        $tempZip = Join-Path $env:TEMP "zsh-autosuggestions.zip"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($autosuggestUrl, $tempZip)
        
        Expand-Archive -Path $tempZip -DestinationPath $toolsPath -Force
        Rename-Item -Path (Join-Path $toolsPath "zsh-autosuggestions-master") -NewName "zsh-autosuggestions" -Force
        
        Remove-Item $tempZip -Force
    } catch {
        Write-Host "    -> 失败: $_" -ForegroundColor Red
    }
}

Write-Host "    -> 下载 zsh-syntax-highlighting" -ForegroundColor Gray
$syntaxHighlightUrl = "$($Config.GitHubMirror)/zsh-users/zsh-syntax-highlighting/archive/refs/heads/master.zip"
$syntaxHighlightPath = Join-Path $toolsPath "zsh-syntax-highlighting"

if (-not (Test-Path $syntaxHighlightPath)) {
    try {
        $tempZip = Join-Path $env:TEMP "zsh-syntax-highlighting.zip"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($syntaxHighlightUrl, $tempZip)
        
        Expand-Archive -Path $tempZip -DestinationPath $toolsPath -Force
        Rename-Item -Path (Join-Path $toolsPath "zsh-syntax-highlighting-master") -NewName "zsh-syntax-highlighting" -Force
        
        Remove-Item $tempZip -Force
    } catch {
        Write-Host "    -> 失败: $_" -ForegroundColor Red
    }
}

# ============================================
# 4. 下载 Starship
# ============================================
Write-Host "`n[4/6] 下载 Starship..." -ForegroundColor Green

$starshipUrl = "$($Config.GitHubMirror)/starship/starship/releases/latest/download/starship-x86_64-pc-windows-msvc.zip"
$starshipPath = Join-Path $toolsPath "starship.exe"

if (Test-Path $starshipPath) {
    Write-Host "    -> 已存在，跳过" -ForegroundColor Yellow
} else {
    try {
        $tempZip = Join-Path $env:TEMP "starship.zip"
        Write-Host "    -> 下载 $starshipUrl" -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($starshipUrl, $tempZip)
        
        Expand-Archive -Path $tempZip -DestinationPath $toolsPath -Force
        Remove-Item $tempZip -Force
        Write-Host "    -> 完成" -ForegroundColor Gray
    } catch {
        Write-Host "[!] 下载失败: $_" -ForegroundColor Red
    }
}

# ============================================
# 5. 下载 Nerd Font（可选）
# ============================================
Write-Host "`n[5/6] 下载 Nerd Font（可选）..." -ForegroundColor Green

if ($Config.DownloadFont -eq $false) {
    Write-Host "    -> 已禁用字体下载，跳过" -ForegroundColor Yellow
} else {
    $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $fontPath = Join-Path $toolsPath "JetBrainsMono-Nerd-Font.zip"
    
    if (Test-Path $fontPath) {
        Write-Host "    -> 已存在，跳过" -ForegroundColor Yellow
    } else {
        try {
            Write-Host "    -> 下载 JetBrains Mono Nerd Font" -ForegroundColor Gray
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($fontUrl, $fontPath)
            Write-Host "    -> 完成" -ForegroundColor Gray
        } catch {
            Write-Host "[!] 下载失败: $_" -ForegroundColor Yellow
            Write-Host "    字体是可选的，可以跳过" -ForegroundColor Yellow
        }
    }
}

# ============================================
# 6. 复制安装脚本
# ============================================
Write-Host "`n[6/6] 复制安装脚本..." -ForegroundColor Green

# 复制离线安装脚本
$scripts = @(
    "offline-install-msys2.ps1",
    "offline-setup-zsh.sh"
)

foreach ($script in $scripts) {
    $src = Join-Path $PSScriptRoot $script
    $dst = Join-Path $scriptsPath $script
    
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "    -> 已复制: $script" -ForegroundColor Gray
    } else {
        Write-Host "    -> 未找到: $script" -ForegroundColor Yellow
    }
}

# 创建资源清单
Write-Host "`n[*] 创建资源清单..." -ForegroundColor Green

$manifest = @{
    created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    msys2_installer = $msys2Exe
    packages_count = (Get-ChildItem $packagesPath -Filter "*.pkg.tar.zst" -Recurse).Count
    tools = @(
        "oh-my-zsh",
        "zsh-autosuggestions",
        "zsh-syntax-highlighting",
        "starship.exe"
    )
}

$manifest | ConvertTo-Json | Out-File (Join-Path $finalOutput "manifest.json") -Encoding UTF8

# ============================================
# 完成
# ============================================
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  下载完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "离线资源已保存到: $finalOutput" -ForegroundColor Cyan
Write-Host ""
Write-Host "文件结构:" -ForegroundColor Cyan
Write-Host "  ├── msys2-x86_64-latest.exe    (MSYS2 安装包)" -ForegroundColor White
Write-Host "  ├── packages/                  (软件包)" -ForegroundColor White
Write-Host "  ├── tools/                     (工具和插件)" -ForegroundColor White
Write-Host "  ├── scripts/                   (安装脚本)" -ForegroundColor White
Write-Host "  └── manifest.json              (资源清单)" -ForegroundColor White
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 将整个 '$(Split-Path $finalOutput -Leaf)' 文件夹拷贝到离线环境" -ForegroundColor White
Write-Host "  2. 在离线环境运行: .\scripts\offline-install-msys2.ps1" -ForegroundColor White
Write-Host "  3. 在 MSYS2 中运行: bash ~/scripts/offline-setup-zsh.sh" -ForegroundColor White
Write-Host ""

# 计算总大小
$totalSize = (Get-ChildItem $finalOutput -Recurse | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "总大小: $totalSizeMB MB" -ForegroundColor Yellow
Write-Host ""
