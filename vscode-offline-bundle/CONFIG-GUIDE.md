# VSCode 配置分离说明

## 📋 配置分类

VSCode Remote-SSH 开发模式涉及两个配置环境：

### 1️⃣ **客户端配置**（本地电脑）

**配置文件位置**：
- **Windows**: `%APPDATA%\Code\User\settings.json`
- **macOS**: `~/Library/Application Support/Code/User/settings.json`
- **Linux**: `~/.config/Code/User/settings.json`

**配置内容**：
- ✅ 远程连接设置（SSH、下载策略）
- ✅ 编辑器外观和主题
- ✅ 全局性能设置
- ✅ 扩展自动更新策略

**配置文件**：`client-settings.json`

### 2️⃣ **服务端配置**（远程服务器）

**配置文件位置**：
- **工作区级**（推荐）：`项目根目录/.vscode/settings.json`
- **用户级**：`~/.vscode-server/data/Machine/settings.json`

**配置内容**：
- ✅ Python 解释器路径
- ✅ 语言服务器设置
- ✅ 代码格式化和 Linting
- ✅ 工作区特定配置

**配置文件**：`server-settings.json`

---

## 🚀 快速配置

### 步骤 1：配置客户端

```bash
# 方式 1：复制配置文件
cp client-settings.json ~/.config/Code/User/settings.json

# 方式 2：手动添加关键配置
# 编辑 settings.json，添加：
{
  "remote.SSH.localServerDownload": "always",
  "remote.SSH.useExecServer": true
}
```

### 步骤 2：配置服务端

#### 方式 1：工作区配置（推荐）

```bash
# 在项目根目录创建 .vscode 目录
mkdir -p .vscode

# 复制服务端配置
cp server-settings.json .vscode/settings.json
```

#### 方式 2：用户级配置

```bash
# 在远程服务器上
mkdir -p ~/.vscode-server/data/Machine

# 复制配置
cp server-settings.json ~/.vscode-server/data/Machine/settings.json
```

---

## 📊 配置对比表

| 配置项 | 客户端 | 服务端 | 作用 |
|--------|--------|--------|------|
| `remote.SSH.localServerDownload` | ✅ | ❌ | 阻止远程 wget |
| `remote.SSH.useExecServer` | ✅ | ❌ | 支持断线重连 |
| `python.defaultInterpreterPath` | ❌ | ✅ | Python 解释器路径 |
| `python.languageServer` | ❌ | ✅ | 语言服务器 |
| `[python].editor.formatOnSave` | ❌ | ✅ | 代码格式化 |
| `editor.fontSize` | ✅ | ❌ | 字体大小 |
| `workbench.colorTheme` | ✅ | ❌ | 主题 |

---

## 🔧 配置优先级

VSCode 配置的优先级（从高到低）：

1. **工作区配置**：`.vscode/settings.json`
2. **远程用户配置**：`~/.vscode-server/data/Machine/settings.json`
3. **本地用户配置**：`~/.config/Code/User/settings.json`
4. **默认配置**

**注意**：
- 客户端配置 → 影响所有远程连接
- 服务端配置 → 仅影响当前项目/服务器
- 工作区配置 → 团队共享，推荐提交到 Git

---

## 📝 使用建议

### 推荐方案：分离配置

```bash
# 客户端（本地）
~/.config/Code/User/settings.json
└─ remote.SSH.localServerDownload: "always"  # 关键配置
└─ remote.SSH.useExecServer: true
└─ 编辑器外观设置

# 服务端（远程，工作区级）
项目/.vscode/settings.json
└─ python.defaultInterpreterPath
└─ python.languageServer: "Pylance"
└─ 代码格式化和 Linting
```

### 团队协作

**提交到 Git**：
```
项目/
├── .vscode/
│   ├── settings.json       # 服务端配置（提交）
│   ├── launch.json         # 调试配置（提交）
│   └── extensions.json     # 扩展推荐（提交）
├── .gitignore
└── README.md
```

**不提交**：
- 客户端配置（个人偏好）
- `~/.vscode-server/` 目录

---

## 🚨 常见问题

### Q: 配置放在客户端还是服务端？

**A:**
- **客户端**：远程连接、外观、全局性能
- **服务端**：Python 环境、代码风格、项目特定配置

### Q: 工作区配置和用户配置冲突怎么办？

**A:** 工作区配置优先级更高，会覆盖用户配置。

### Q: 如何验证配置生效？

**A:**
```bash
# 客户端：在本地打开 VSCode 设置查看
# 服务端：连接远程后，在远程终端运行
code --list-extensions --show-versions
```

### Q: 配置没生效怎么办？

**A:**
1. 重启 VSCode
2. 检查 JSON 语法是否正确
3. 确认配置文件位置正确
4. 查看输出面板（View → Output → Remote-SSH）

---

## 📦 完整配置示例

### 客户端最小配置

```json
{
  "remote.SSH.localServerDownload": "always",
  "remote.SSH.useExecServer": true,
  "remote.SSH.connectTimeout": 60
}
```

### 服务端最小配置

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.languageServer": "Pylance",
  "[python]": {
    "editor.formatOnSave": true
  }
}
```

---

## 🔄 自动化配置

使用 `setup-vscode.sh` 脚本：

```bash
./setup-vscode.sh

# 选项 1: 配置客户端全局设置
# 选项 2: 创建服务端工作区配置
# 选项 3: 全部配置（推荐）
```

---

更新时间：2026-03-28
