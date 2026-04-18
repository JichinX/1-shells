# Claude Code 离线安装包下载工具

用于在离线环境中下载 Claude Code 二进制文件的脚本工具。

## 功能特性

- 自动检测系统平台（Linux/macOS）和架构（x64/arm64）
- 支持 musl libc 环境（Alpine Linux 等）
- 自动获取最新版本
- SHA256 校验和验证
- 支持 curl 和 wget 两种下载工具
- 可选 jq 依赖（无 jq 时使用纯 bash 解析）

## 支持的平台

| 平台 | 架构 | 标识符 |
|------|------|--------|
| Linux | x64 | `linux-x64` |
| Linux | arm64 | `linux-arm64` |
| Linux (musl) | x64 | `linux-x64-musl` |
| Linux (musl) | arm64 | `linux-arm64-musl` |
| macOS | x64 | `darwin-x64` |
| macOS | arm64 (M1/M2) | `darwin-arm64` |

## 使用方法

### 自动检测平台

```bash
./download-claude.sh
```

脚本会自动检测当前系统平台和架构，下载对应的二进制文件。

### 指定平台

```bash
# 下载 Linux x64 版本
./download-claude.sh linux-x64

# 下载 macOS arm64 版本
./download-claude.sh darwin-arm64

# 下载 Alpine Linux (musl) 版本
./download-claude.sh linux-x64-musl
```

### 指定输出目录

```bash
./download-claude.sh linux-x64 ./output
```

## 依赖要求

**必需**：
- `curl` 或 `wget`（二选一）

**可选**：
- `jq` - 用于解析 JSON（无此工具时使用内置 bash 解析）

安装 jq：
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

## 安装下载的二进制文件

下载完成后，手动安装：

```bash
# 创建目录
mkdir -p ~/.local/bin

# 移动并重命名
mv claude-<version>-<platform> ~/.local/bin/claude

# 验证安装
claude --version
```

确保 `~/.local/bin` 在 PATH 中：
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 离线环境部署

### 步骤 1：在线环境下载

在有网络的环境中运行脚本：

```bash
./download-claude.sh linux-x64 ./offline-bundle
```

### 步骤 2：传输到离线环境

将下载的二进制文件传输到目标机器：

```bash
# 使用 scp
scp offline-bundle/claude-* user@offline-host:~/

# 或使用 USB 存储设备
```

### 步骤 3：离线环境安装

```bash
mkdir -p ~/.local/bin
mv claude-* ~/.local/bin/claude
chmod +x ~/.local/bin/claude
claude --version
```

## 安全说明

- 脚本会验证 SHA256 校验和，确保下载文件的完整性
- 二进制文件来自官方发布源：`https://downloads.claude.ai/claude-code-releases`

## 故障排除

### 平台不支持

如果看到 "Platform not found" 错误：

1. 检查平台标识符是否正确
2. 安装 `jq` 查看可用平台列表
3. 访问官方发布页面确认支持的平台

### 校验和验证失败

可能是网络问题导致文件损坏，请重新下载。

### 权限问题

确保脚本有执行权限：
```bash
chmod +x download-claude.sh
```

## 相关链接

- [Claude Code 官方文档](https://docs.anthropic.com/claude-code)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
