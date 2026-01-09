# fundeploy

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)

fundeploy 是一个快速部署环境的脚本工具集，旨在简化开发、测试和生产环境的部署流程。它提供了一系列自动化脚本和工具，帮助开发者快速搭建和配置各种运行环境。

## ✨ 特性

- 🚀 **快速部署**: 一键部署开发、测试、生产环境
- 🔧 **多环境支持**: 支持多种操作系统和云平台
- 📦 **依赖管理**: 自动安装和配置项目依赖
- 🐳 **容器化支持**: 集成 Docker 和 Kubernetes 部署方案
- 🔐 **安全配置**: 内置安全最佳实践和配置模板
- 📋 **配置管理**: 统一管理不同环境的配置文件
- 🤖 **自动化流程**: 支持 CI/CD 集成和自动化部署
- 🎯 **灵活扩展**: 易于定制和扩展的脚本架构
- ⏬ **多种安装方式**: 支持全局安装（通过 curl）或 pip 安装，无需预装 Python

## 📋 系统要求

- Python 3.9 或更高版本
- Bash/Zsh（Unix-like 系统）
- 根据部署目标可能需要：
  - Docker
  - Kubernetes
  - Git
  - 特定云平台 CLI 工具

## 🚀 安装

fundeploy 支持多种安装方式，您可以选择全局安装或通过 pip 安装。

### 全局安装（推荐）

使用独立安装脚本进行全局安装，无需预先安装 Python 或 pip：

```bash
# macOS 和 Linux
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/install.sh | sh
```

```bash
# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/farfarfun/fundeploy/master/install.ps1 | iex"
```

### 通过 pip 安装

如果您已经有 Python 环境，可以直接使用 pip 安装：

```bash
pip install fundeploy
```

### 从源码安装

```bash
git clone https://github.com/farfarfun/fundeploy.git
cd fundeploy
pip install .
```

## 📖 使用指南

### Python 环境快速设置

fundeploy 提供了便捷的脚本来使用 uv 快速创建 Python 环境，并统一安装到 `~/opt/` 目录：

```bash
# Linux/macOS - 安装 Python 3.12
./scripts/setup_python_env.sh 3.12

# Windows PowerShell - 安装 Python 3.12
.\scripts\setup_python_env.ps1 -PythonVersion 3.12

# 激活环境（Linux/macOS）
source ~/opt/py312/bin/activate

# 激活环境（Windows）
~\opt\py312\Scripts\Activate.ps1
```

Python 环境按版本号安装在 `~/opt/` 目录下：
- Python 3.12 → `~/opt/py312`
- Python 3.11 → `~/opt/py311`
- Python 3.10 → `~/opt/py310`

详细说明请参见 [scripts/README.md](scripts/README.md)

### 基本命令

```bash
# 初始化部署环境
fundeploy init

# 部署到开发环境
fundeploy deploy --env dev

# 部署到生产环境
fundeploy deploy --env prod

# 查看部署状态
fundeploy status

# 回滚到上一个版本
fundeploy rollback
```

### 环境配置

创建配置文件 `deploy.yaml`：

```yaml
# 部署配置示例
project_name: my-project
environments:
  dev:
    type: local
    python_version: "3.9"
    install_requirements: true
    
  test:
    type: docker
    image: python:3.9-slim
    registry: docker.io
    
  prod:
    type: kubernetes
    cluster: production-cluster
    namespace: default
    replicas: 3

# 依赖配置
dependencies:
  - python-packages:
      - flask
      - gunicorn
  - system-packages:
      - nginx
      - redis

# 环境变量
env_vars:
  DATABASE_URL: "${DB_URL}"
  API_KEY: "${API_KEY}"
```

### Docker 部署

```bash
# 构建 Docker 镜像
fundeploy docker build

# 推送到镜像仓库
fundeploy docker push

# 运行容器
fundeploy docker run --env dev

# 停止容器
fundeploy docker stop
```

### Kubernetes 部署

```bash
# 应用 Kubernetes 配置
fundeploy k8s apply

# 查看部署状态
fundeploy k8s status

# 扩缩容
fundeploy k8s scale --replicas 5

# 查看日志
fundeploy k8s logs
```

### 高级功能

#### 1. 多环境配置管理

```bash
# 设置环境变量
fundeploy config set --env prod DATABASE_URL "postgresql://..."

# 查看配置
fundeploy config get --env prod

# 导入配置文件
fundeploy config import config.env
```

#### 2. 脚本钩子

在 `deploy.yaml` 中配置部署钩子：

```yaml
hooks:
  pre_deploy:
    - "npm run build"
    - "pytest tests/"
  post_deploy:
    - "fundeploy notify --message 'Deployment completed'"
  pre_rollback:
    - "fundeploy backup create"
```

#### 3. 自定义部署脚本

```python
# custom_deploy.py
from fundeploy import Deployer

class MyDeployer(Deployer):
    def pre_deploy(self):
        # 部署前的自定义逻辑
        self.run_tests()
        self.backup_database()
    
    def deploy(self):
        # 自定义部署逻辑
        self.install_dependencies()
        self.migrate_database()
        self.restart_services()
    
    def post_deploy(self):
        # 部署后的自定义逻辑
        self.health_check()
        self.send_notification()

# 使用自定义部署器
deployer = MyDeployer(config_file="deploy.yaml")
deployer.run(environment="prod")
```

#### 4. CI/CD 集成

GitHub Actions 示例：

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Install fundeploy
        run: pip install fundeploy
      
      - name: Deploy to production
        run: fundeploy deploy --env prod
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
```

## 📁 项目结构

```
fundeploy/
├── src/
│   └── fundeploy/
│       ├── core/          # 核心部署逻辑
│       ├── deployers/     # 各种部署器实现
│       ├── config/        # 配置管理
│       ├── hooks/         # 钩子系统
│       └── utils/         # 工具函数
├── scripts/               # 部署和环境设置脚本
│   ├── setup_python_env.sh      # Python 环境设置脚本 (Linux/macOS)
│   ├── setup_python_env.ps1     # Python 环境设置脚本 (Windows)
│   └── README.md                # 脚本使用说明
├── templates/             # 配置模板
├── examples/              # 使用示例
├── tests/                 # 测试文件
├── deploy.yaml            # 部署配置
└── README.md             # 项目文档
```

## 🔧 支持的部署目标

### 操作系统
- ✅ Linux (Ubuntu, CentOS, Debian)
- ✅ macOS
- ✅ Windows (WSL)

### 云平台
- ✅ AWS (EC2, ECS, Lambda)
- ✅ Google Cloud Platform
- ✅ Azure
- ✅ 阿里云
- ✅ 腾讯云
- ✅ Heroku
- ✅ DigitalOcean

### 容器平台
- ✅ Docker
- ✅ Kubernetes
- ✅ Docker Swarm
- ✅ OpenShift

## 🤝 贡献指南

我们欢迎任何形式的贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 开发环境设置

```bash
# 克隆仓库
git clone https://github.com/farfarfun/fundeploy.git
cd fundeploy

# 安装开发依赖
pip install -e ".[dev]"

# 运行测试
pytest tests/

# 代码格式化
ruff format .
ruff check . --fix
```

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🔗 相关链接

- [GitHub 仓库](https://github.com/farfarfun/fundeploy)
- [PyPI 页面](https://pypi.org/project/fundeploy/)
- [问题反馈](https://github.com/farfarfun/fundeploy/issues)
- [变更日志](CHANGELOG.md)

## 🌟 相关项目

fundeploy 是 farfarfun 工具生态系统的一部分，您可能还对以下项目感兴趣：

- **[funbuild](https://github.com/farfarfun/funbuild)** - Python 项目构建和管理工具
- **[fundrive](https://github.com/farfarfun/fundrive)** - 统一的云存储操作接口
- **[fundata](https://github.com/farfarfun/fundata)** - 数据处理工具包

## 👥 维护者

- **farfarfun** - [farfarfun@qq.com](mailto:farfarfun@qq.com)

## 🙏 致谢

感谢所有为 fundeploy 项目做出贡献的开发者和用户！

---

如果您觉得 fundeploy 对您有帮助，请给我们一个 ⭐️！
