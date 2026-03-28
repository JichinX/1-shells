# VSCode 离线 + Python + FastAPI 开发扩展推荐

## 🎯 核心扩展（必需）

### 远程开发
- **ms-vscode-remote.remote-ssh** - SSH 远程连接（核心）
- **ms-vscode-remote.remote-ssh-edit** - SSH 配置编辑

### Python 开发
- **ms-python.python** - Python 语言支持（核心）
- **ms-python.vscode-pylance** - 类型检查和智能提示
- **ms-python.black-formatter** - Black 代码格式化

## 🔧 强烈推荐

### 代码质量
- **ms-python.pylint** - Pylint 代码检查（可选）
- **charliermarsh.ruff** - Ruff 快速 Linter（替代 flake8/isort）

### 数据库工具
- **alexcvzz.vscode-sqlite** - SQLite 数据库查看器
- **ckolkman.vscode-postgres** - PostgreSQL 支持

### FastAPI 增强
- **ritwickdey.liveserver** - 本地服务器（测试 API）
- **formulahendry.code-runner** - 快速运行代码片段

### 配置文件
- **tamasfe.even-better-toml** - TOML 语法高亮（pyproject.toml）
- **redhat.vscode-yaml** - YAML 支持（配置文件）

## 🤖 AI 辅助（可选）

### 内网 AI 网关方案

#### 方案 1：GitHub Copilot + 内网代理
```json
{
  "github.copilot.advanced": {
    "debug.overrideProxy": "http://your-ai-gateway:8080"
  }
}
```
扩展：`github.copilot`

#### 方案 2：国产 AI 编码助手
- **codegee-x.codegee-x** - CodeGeeX（清华开源）
- **alibaba-cloud.tongyi-lingma** - 通义灵码（阿里）
- **baiducomate.baiducomate** - 文心快码（百度）

根据你的 AI 网关选择对应的扩展。

## 📦 离线安装方法

### 方法 1：使用扩展列表文件

创建 `extensions.txt`：
```
ms-vscode-remote.remote-ssh
ms-python.python
ms-python.vscode-pylance
ms-python.black-formatter
charliermarsh.ruff
alexcvzz.vscode-sqlite
tamasfe.even-better-toml
```

批量下载：
```bash
# 在有网络的机器上
cat extensions.txt | xargs -I {} code --download-extension {}

# 或使用脚本
for ext in $(cat extensions.txt); do
  code --download-extension "$ext"
done
```

生成的 `.vsix` 文件在：
- Windows: `%USERPROFILE%\.vscode\extensions\`
- macOS/Linux: `~/.vscode/extensions/`

### 方法 2：在线下载 VSIX

访问：https://marketplace.visualstudio.com/

搜索扩展名，点击 "Download" 下载 `.vsix` 文件。

### 方法 3：使用本仓库的扩展下载功能

```bash
# 编辑 config.conf，添加扩展列表
extensions << EOF
ms-vscode-remote.remote-ssh
ms-python.python
ms-python.vscode-pylance
EOF

# 运行下载脚本
./download.sh
```

### 离线安装扩展

```bash
# 方法 1：VSCode 命令
code --install-extension ms-python.python-2024.0.1.vsix

# 方法 2：手动放置
cp *.vsix ~/.vscode/extensions/
# 重启 VSCode
```

## 🔧 完整扩展配置

编辑 `config.conf` 的扩展列表：

```ini
extensions << EOF
# 远程开发
ms-vscode-remote.remote-ssh
ms-vscode-remote.remote-ssh-edit

# Python 核心
ms-python.python
ms-python.vscode-pylance
ms-python.black-formatter
charliermarsh.ruff

# 数据库
alexcvzz.vscode-sqlite

# 配置文件
tamasfe.even-better-toml
redhat.vscode-yaml

# 通用工具
formulahendry.code-runner
ritwickdey.liveserver
EOF
```

## 📝 快速安装脚本

创建 `install-extensions.sh`：

```bash
#!/bin/bash
# 离线批量安装 VSCode 扩展

EXT_DIR="./extensions"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "错误：找不到扩展目录 $EXT_DIR"
  exit 1
fi

echo "开始安装扩展..."
for vsix in "$EXT_DIR"/*.vsix; do
  if [[ -f "$vsix" ]]; then
    echo "安装: $(basename "$vsix")"
    code --install-extension "$vsix" --force
  fi
done

echo "✅ 扩展安装完成！"
echo "请重启 VSCode 生效。"
```

使用：
```bash
chmod +x install-extensions.sh
./install-extensions.sh
```

## 🚀 推荐工作区配置

创建 `.vscode/settings.json`（项目级配置）：

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.terminal.activateEnvironment": true,
  
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": "explicit"
  },
  
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

创建 `.vscode/launch.json`（调试配置）：

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "main:app",
        "--reload",
        "--host", "0.0.0.0",
        "--port", "8000"
      ],
      "jinja": true,
      "autoStartBrowser": false
    },
    {
      "name": "Pytest",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["-v", "--tb=short"],
      "console": "integratedTerminal"
    }
  ]
}
```

## ⚠️ 注意事项

1. **版本兼容性**：下载扩展时注意 VSCode 版本要求
2. **扩展依赖**：某些扩展有依赖关系，需要一起安装
3. **更新策略**：离线环境建议关闭自动更新
4. **权限问题**：在服务器上安装扩展可能需要 sudo 权限

## 📊 扩展大小参考

| 扩展 | 大小（约） | 必需性 |
|------|-----------|--------|
| ms-python.python | 50 MB | ★★★★★ |
| ms-python.vscode-pylance | 100 MB | ★★★★☆ |
| ms-vscode-remote.remote-ssh | 5 MB | ★★★★★ |
| charliermarsh.ruff | 10 MB | ★★★★☆ |
| alexcvzz.vscode-sqlite | 3 MB | ★★★☆☆ |

总计约：170-200 MB

---

更新时间：2026-03-28
VSCode 版本：≥ 1.79.0
