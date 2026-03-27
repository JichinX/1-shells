# Homebrew 国内镜像源一键替换工具

一键切换 Homebrew 到国内镜像源，加速 `brew install` 下载速度。

## 支持的镜像源

| 镜像源 | 说明 | 适用网络 |
|--------|------|----------|
| **中科大 (USTC)** | 老牌镜像，稳定可靠 | 教育网优先 |
| **清华大学 (TUNA)** | 更新及时，社区活跃 | 教育网优先 |
| **阿里云 (ALIYUN)** | 大带宽，低延迟 | 电信联通优先 |
| **腾讯云 (TENCENT)** | 多线 BGP，延迟低 | 南方用户优先 |

## 功能特性

- 支持 4 个主流国内镜像源一键切换
- 自动检测 Shell 类型（zsh / bash / fish）
- 兼容 Apple Silicon (M1/M2/M3) 和 Intel Mac
- 兼容 Homebrew 4.0+（API 模式）和旧版本（Tap 模式）
- 自动备份当前配置，支持从备份恢复
- 镜像源连通性速度测试
- 一键恢复官方源

## 快速使用

```bash
# 下载并运行
git clone https://github.com/yourname/homebrew-mirrors.git
cd homebrew-mirrors
./brew-mirror.sh
```

## 使用示例

### 一键切换镜像源

运行脚本后按照交互菜单操作：

```
╔══════════════════════════════════════════════╗
║   Homebrew 国内镜像源一键替换工具 v1.0       ║
╚══════════════════════════════════════════════╝

[INFO] 检查运行环境...
[OK] 操作系统: macOS 14.0
[OK] Homebrew 已安装: /opt/homebrew
[OK] 芯片架构: Apple Silicon (arm64)

[INFO] Shell: /bin/zsh → 配置文件: /Users/you/.zshrc

请选择操作:
─────────────────────────────────────────
  1) 切换镜像源
  2) 恢复官方源
  3) 查看当前配置
  4) 测试镜像速度
  5) 从备份恢复
  0) 退出

请输入选项 [0-5]:
```

### 测试速度后选择最优镜像

输入 `4` 进入速度测试，然后根据延迟选择最快的镜像源。

### 恢复官方源

输入 `2` 或在切换镜像时选择 `0`，即可恢复到 Homebrew 官方源。

## 脚本做了什么

切换镜像源时，脚本会修改以下内容：

1. **Shell 环境变量** — 在 `~/.zshrc`（或对应的 shell 配置文件）中写入：
   - `HOMEBREW_API_DOMAIN` — formulae JSON API 镜像
   - `HOMEBREW_BOTTLE_DOMAIN` — 预编译二进制包镜像

2. **Git Remote**（旧版本 Homebrew）— 将 brew 和 homebrew-core 的 remote URL 改为镜像地址

## 手动配置参考

如果你不想用脚本，也可以手动配置。以 USTC 为例，在 `~/.zshrc` 中添加：

```bash
# Homebrew Mirror
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
```

然后执行 `source ~/.zshrc` 生效。

> **注意**: Homebrew 4.0+ 默认使用 API 模式，不再需要 homebrew-core tap。如果遇到问题，可以尝试 `brew tap --force homebrew/core` 切回 tap 模式。

## 备份与恢复

所有配置修改前会自动备份到 `~/.homebrew-mirror-backup/`，可以通过脚本菜单中的 "从备份恢复" 功能还原。

## 许可证

MIT License
