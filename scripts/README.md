# 脚本说明

此目录包含用于快速部署 Python 环境的脚本。

## setup_python_env.sh / setup_python_env.ps1

使用 uv 创建 Python 虚拟环境并安装在 `~/opt/` 目录下。

### 功能特性

- 🚀 自动安装指定版本的 Python
- 📦 使用 uv 进行快速安装和环境管理
- 🗂️ 统一安装到 `~/opt/` 目录，易于管理
- ✅ 自动检测并安装 uv（如果未安装）
- 🔄 支持环境重建（检测到已存在的环境会提示）
- 🛠️ 自动升级 pip 和基础工具

### 目录结构

Python 环境按版本安装在以下位置：

- Python 3.12 → `~/opt/py312`
- Python 3.11 → `~/opt/py311`
- Python 3.10 → `~/opt/py310`
- Python 3.9 → `~/opt/py39`

### 使用方法

#### Linux / macOS

```bash
# 安装 Python 3.12
./scripts/setup_python_env.sh 3.12

# 安装 Python 3.11
./scripts/setup_python_env.sh 3.11

# 激活环境
source ~/opt/py312/bin/activate

# 或直接使用
~/opt/py312/bin/python
~/opt/py312/bin/pip install requests
```

#### Windows (PowerShell)

```powershell
# 安装 Python 3.12
.\scripts\setup_python_env.ps1 -PythonVersion 3.12

# 安装 Python 3.11
.\scripts\setup_python_env.ps1 -PythonVersion 3.11

# 激活环境
~\opt\py312\Scripts\Activate.ps1

# 或直接使用
~\opt\py312\Scripts\python.exe
~\opt\py312\Scripts\pip.exe install requests
```

### 便捷别名

为了方便使用，可以在 shell 配置文件中添加别名：

#### Bash/Zsh (~/.bashrc 或 ~/.zshrc)

```bash
# Python 环境快速激活
alias py312='source ~/opt/py312/bin/activate'
alias py311='source ~/opt/py311/bin/activate'
alias py310='source ~/opt/py310/bin/activate'
```

#### PowerShell ($PROFILE)

```powershell
# Python 环境快速激活
function Activate-Py312 { & "$env:USERPROFILE\opt\py312\Scripts\Activate.ps1" }
function Activate-Py311 { & "$env:USERPROFILE\opt\py311\Scripts\Activate.ps1" }
function Activate-Py310 { & "$env:USERPROFILE\opt\py310\Scripts\Activate.ps1" }
```

### 常见问题

**Q: 脚本会自动安装 uv 吗？**  
A: 是的，如果检测到系统中没有安装 uv，脚本会自动下载并安装。

**Q: 我可以安装多个 Python 版本吗？**  
A: 可以，每个版本都安装在独立的目录中，互不干扰。

**Q: 如何删除某个 Python 环境？**  
A: 直接删除对应的目录即可，例如：`rm -rf ~/opt/py312`

**Q: 可以自定义安装路径吗？**  
A: 目前脚本默认安装到 `~/opt/` 目录，如需自定义可以修改脚本中的 `OPT_DIR` 变量。

### 依赖要求

- Linux/macOS: Bash, curl
- Windows: PowerShell 5.1+
- 网络连接（用于下载 Python 和 uv）

### 相关链接

- [uv 文档](https://docs.astral.sh/uv/)
- [Python 官方网站](https://www.python.org/)
