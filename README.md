# fundeploy - 快速部署环境的脚本

<p align="center">
  <strong>一个标准化的环境快速部署工具集</strong>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#支持环境">支持环境</a> •
  <a href="#部署规范">部署规范</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#使用场景">使用场景</a>
</p>

---

## 📖 项目简介

fundeploy 是一个专为开发者设计的环境快速部署工具集，旨在提供标准化、自动化的开发环境搭建方案。通过预定义的部署脚本和配置规范，帮助团队快速、一致地搭建 Python、Node.js 等开发环境。

### 设计理念

- **标准化**：统一的环境配置和部署流程
- **自动化**：减少手动操作，提高部署效率
- **可移植**：支持多种 Linux 发行版
- **易维护**：清晰的日志输出和错误处理机制

## ✨ 功能特性

### 核心功能

- 🐍 **Python 环境部署**
  - 自动安装 Python3 及相关工具
  - 虚拟环境管理（venv）
  - pip 包管理器配置
  - 依赖包自动安装

- 🟢 **Node.js 环境部署**
  - 多版本 Node.js 支持
  - nvm 版本管理器集成
  - npm/yarn 包管理器
  - 全局工具包安装（pm2、nodemon等）

- 🔧 **通用功能**
  - 智能环境检测
  - 彩色日志输出
  - 错误自动处理
  - 参数化配置
  - 多系统兼容

### 支持的操作系统

| 操作系统 | 版本要求 | 支持状态 |
|---------|---------|---------|
| Ubuntu | 18.04+ | ✅ 完全支持 |
| Debian | 10+ | ✅ 完全支持 |
| CentOS | 7+ | ✅ 完全支持 |
| RHEL | 7+ | ✅ 完全支持 |
| 其他 Linux | - | ⚠️ 部分支持（使用 nvm） |

## 🎯 支持环境

### Python 环境

- **Python 版本**：3.8 / 3.9 / 3.10 / 3.11 / 3.12
- **包管理**：pip、venv
- **虚拟环境**：支持独立虚拟环境创建
- **依赖管理**：requirements.txt

### Node.js 环境

- **Node.js 版本**：14.x / 16.x / 18.x (LTS) / 20.x (LTS)
- **包管理**：npm、yarn
- **版本管理**：nvm
- **进程管理**：pm2
- **依赖管理**：package.json

## 📋 部署规范

### Python 部署标准

#### 1. 版本要求
- **推荐版本**：Python 3.10 或 3.11
- **最低版本**：Python 3.8
- **验证命令**：`python3 --version`

#### 2. 目录结构规范
```
project/
├── venv/                  # 虚拟环境目录（不提交到版本控制）
├── src/                   # 源代码目录
│   ├── __init__.py
│   ├── main.py
│   └── modules/
├── tests/                 # 测试代码
│   ├── __init__.py
│   └── test_*.py
├── docs/                  # 项目文档
├── requirements.txt       # 生产环境依赖
├── requirements-dev.txt   # 开发环境依赖（可选）
├── .env.example          # 环境变量示例
├── .gitignore
└── README.md
```

#### 3. 依赖管理规范
- 使用 `requirements.txt` 管理依赖
- 版本号应明确指定（推荐使用 `==` 固定版本）
- 区分生产环境和开发环境依赖
- 定期更新依赖包并测试兼容性

#### 4. 虚拟环境规范
- 每个项目独立创建虚拟环境
- 虚拟环境目录命名：`venv`、`.venv` 或 `env`
- 虚拟环境不提交到版本控制系统
- 在 `.gitignore` 中排除虚拟环境目录

#### 5. 包管理配置
```bash
# pip 镜像源配置（可选，提高下载速度）
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn
```

### Node.js 部署标准

#### 1. 版本要求
- **推荐版本**：Node.js 18.x LTS 或 20.x LTS
- **最低版本**：Node.js 14.x
- **验证命令**：`node --version`

#### 2. 目录结构规范
```
project/
├── node_modules/         # 依赖包目录（不提交到版本控制）
├── src/                  # 源代码目录
│   ├── index.js
│   ├── routes/
│   ├── controllers/
│   ├── models/
│   └── utils/
├── dist/                 # 构建输出目录（不提交）
├── tests/                # 测试代码
├── public/               # 静态资源
├── config/               # 配置文件
├── package.json          # 项目配置
├── package-lock.json     # 依赖锁定文件（提交）
├── .env.example         # 环境变量示例
├── .gitignore
├── .eslintrc.js         # ESLint 配置
├── .prettierrc          # Prettier 配置
└── README.md
```

#### 3. package.json 规范
```json
{
  "name": "project-name",
  "version": "1.0.0",
  "description": "项目描述",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "lint": "eslint src/",
    "format": "prettier --write src/",
    "build": "webpack --mode production"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  },
  "keywords": [],
  "author": "",
  "license": "MIT"
}
```

#### 4. 依赖管理规范
- 区分 `dependencies` 和 `devDependencies`
- 提交 `package-lock.json` 或 `yarn.lock`
- 使用语义化版本号
- 定期审查和更新依赖

#### 5. 全局工具推荐
```bash
# 进程管理器（生产环境）
npm install -g pm2

# 开发工具
npm install -g nodemon

# 包管理器
npm install -g yarn

# 代码质量工具
npm install -g eslint prettier
```

### 通用部署规范

#### 1. 环境变量管理
- 使用 `.env` 文件管理环境变量
- 不提交 `.env` 文件到版本控制
- 提供 `.env.example` 作为模板
- 敏感信息不能硬编码在代码中

**Python 示例**：
```python
# 使用 python-dotenv
from dotenv import load_dotenv
import os

load_dotenv()
DATABASE_URL = os.getenv('DATABASE_URL')
```

**Node.js 示例**：
```javascript
// 使用 dotenv
require('dotenv').config();
const databaseUrl = process.env.DATABASE_URL;
```

#### 2. .gitignore 规范
```gitignore
# Python
__pycache__/
*.py[cod]
venv/
env/
.env

# Node.js
node_modules/
dist/
.env

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db
```

#### 3. 日志规范
- 使用结构化日志格式
- 区分日志级别：DEBUG、INFO、WARN、ERROR
- 日志文件应定期轮转
- 生产环境避免输出敏感信息

#### 4. 安全规范
- 定期更新依赖包
- 使用安全扫描工具检查漏洞
- 不在代码中存储密码、密钥等敏感信息
- 使用环境变量或密钥管理服务
- 限制文件和目录权限

## 🚀 快速开始

### Python 环境部署

#### 基础部署流程

```bash
# 1. 检查 Python 版本
python3 --version

# 2. 安装 Python（如果未安装）
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# CentOS/RHEL
sudo yum install -y python3 python3-pip

# 3. 创建项目目录
mkdir my-python-project
cd my-python-project

# 4. 创建虚拟环境
python3 -m venv venv

# 5. 激活虚拟环境
source venv/bin/activate  # Linux/Mac

# 6. 升级 pip
pip install --upgrade pip

# 7. 创建 requirements.txt
cat > requirements.txt << EOF
flask==3.0.0
requests==2.31.0
python-dotenv==1.0.0
EOF

# 8. 安装依赖
pip install -r requirements.txt

# 9. 验证安装
pip list
```

#### 快速命令（使用部署脚本）

```bash
# 完整部署（待实现）
./deploy_python.sh --venv venv --requirements requirements.txt
```

### Node.js 环境部署

#### 基础部署流程

```bash
# 1. 使用 nvm 安装 Node.js（推荐）
# 安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc

# 2. 安装 Node.js LTS 版本
nvm install 18
nvm use 18
nvm alias default 18

# 3. 验证安装
node --version
npm --version

# 4. 升级 npm
npm install -g npm@latest

# 5. 安装全局工具
npm install -g yarn pm2 nodemon

# 6. 创建项目
mkdir my-node-project
cd my-node-project
npm init -y

# 7. 安装项目依赖
npm install express dotenv
npm install -D nodemon eslint

# 8. 验证安装
npm list
```

#### 快速命令（使用部署脚本）

```bash
# 完整部署（待实现）
./deploy_nodejs.sh --version 18 --globals --deps
```

## 💡 使用场景

### 场景 1：新服务器初始化

```bash
# 场景：在全新的 Ubuntu 服务器上部署 Python Web 应用

# 1. 更新系统
sudo apt-get update && sudo apt-get upgrade -y

# 2. 部署 Python 环境
# （使用 fundeploy 脚本，待实现）

# 3. 克隆项目
git clone https://github.com/username/project.git
cd project

# 4. 激活虚拟环境并安装依赖
source venv/bin/activate
pip install -r requirements.txt

# 5. 配置环境变量
cp .env.example .env
nano .env  # 编辑环境变量

# 6. 运行应用
python app.py
```

### 场景 2：多版本环境管理

```bash
# 场景：需要在同一服务器上运行不同版本的 Node.js 项目

# 使用 nvm 管理多个 Node.js 版本
nvm install 16
nvm install 18
nvm install 20

# 项目 A（需要 Node.js 16）
cd /path/to/project-a
nvm use 16
npm install
pm2 start app.js --name project-a

# 项目 B（需要 Node.js 20）
cd /path/to/project-b
nvm use 20
npm install
pm2 start app.js --name project-b

# 查看运行状态
pm2 status
```

### 场景 3：团队开发环境统一

```bash
# 场景：确保团队所有成员使用相同的开发环境

# 1. 在项目中添加环境要求文档
# Python: requirements.txt + .python-version
echo "3.11" > .python-version

# Node.js: package.json 中指定引擎版本
# {
#   "engines": {
#     "node": "18.x",
#     "npm": ">=9.0.0"
#   }
# }

# 2. 提供部署脚本
# 团队成员只需执行：
./deploy_python.sh --venv venv --requirements requirements.txt
# 或
./deploy_nodejs.sh --version 18 --deps

# 3. 使用 Docker 进一步标准化（可选）
```

### 场景 4：CI/CD 集成

```bash
# 场景：在 CI/CD 流程中自动部署环境

# GitHub Actions 示例（Python）
# .github/workflows/deploy.yml
# steps:
#   - name: Deploy Python Environment
#     run: |
#       ./deploy_python.sh --venv venv --requirements requirements.txt
#       source venv/bin/activate
#       pytest

# GitLab CI 示例（Node.js）
# .gitlab-ci.yml
# deploy:
#   script:
#     - ./deploy_nodejs.sh --version 18 --deps
#     - npm test
#     - npm run build
```

## 🔧 常见问题

### Python 常见问题

#### Q1: pip 安装包时出现权限错误

```bash
# 问题
ERROR: Could not install packages due to an OSError: [Errno 13] Permission denied

# 解决方案 1：使用虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate
pip install <package>

# 解决方案 2：使用 --user 参数
pip install --user <package>

# ❌ 不推荐使用 sudo pip
```

#### Q2: 虚拟环境激活后命令未找到

```bash
# 问题
source venv/bin/activate
(venv) $ python: command not found

# 解决方案：检查虚拟环境创建是否成功
python3 -m venv venv --clear  # 重新创建
source venv/bin/activate
which python  # 验证 Python 路径
```

#### Q3: requirements.txt 依赖冲突

```bash
# 问题
ERROR: pip's dependency resolver does not currently take into account...

# 解决方案：使用 pip-tools
pip install pip-tools
pip-compile requirements.in  # 生成 requirements.txt
pip-sync requirements.txt     # 安装依赖
```

### Node.js 常见问题

#### Q1: npm install 速度慢

```bash
# 解决方案 1：使用国内镜像
npm config set registry https://registry.npmmirror.com

# 解决方案 2：使用 yarn（通常更快）
npm install -g yarn
yarn install

# 解决方案 3：使用 pnpm
npm install -g pnpm
pnpm install
```

#### Q2: 全局包安装权限错误

```bash
# 问题
EACCES: permission denied

# 解决方案 1：使用 nvm（推荐）
# nvm 安装的 Node.js 不需要 sudo

# 解决方案 2：修改 npm 全局目录
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# ❌ 不推荐使用 sudo npm install -g
```

#### Q3: Node.js 版本不匹配

```bash
# 问题
This project requires Node.js version 18.x

# 解决方案：使用 nvm 切换版本
nvm install 18
nvm use 18
nvm alias default 18

# 自动切换：在项目根目录创建 .nvmrc
echo "18" > .nvmrc
nvm use  # 自动读取 .nvmrc
```

## 📚 最佳实践

### 开发环境隔离

- 每个项目使用独立的虚拟环境（Python）或 nvm 环境（Node.js）
- 不同项目避免共享全局依赖
- 使用 Docker 容器进一步隔离环境

### 依赖版本管理

- 明确指定依赖版本号，避免使用 `*` 或 `latest`
- 定期更新依赖并测试兼容性
- 使用依赖锁定文件（`package-lock.json`、`yarn.lock`）

### 环境变量管理

- 使用 `.env` 文件管理环境变量
- `.env` 文件不提交到版本控制
- 提供 `.env.example` 作为模板
- 生产环境使用密钥管理服务

### 代码质量

- 使用 linter 和 formatter（ESLint、Prettier、Black、Flake8）
- 配置 pre-commit 钩子自动检查
- 编写单元测试和集成测试
- 使用 CI/CD 自动化测试流程

### 文档规范

- 在 README 中说明环境要求
- 提供详细的安装和部署步骤
- 记录常见问题和解决方案
- 保持文档与代码同步更新

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目！

### 如何贡献

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 开发规范

- 脚本使用 Bash 编写
- 包含详细的注释和日志输出
- 完善的错误处理机制（使用 `set -e`）
- 提供帮助信息（`--help` 参数）
- 支持参数化配置
- 遵循 Shell 脚本最佳实践

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 👨‍💻 作者

**farfarfun**

## 🔗 相关资源

### 官方文档
- [Python 官方文档](https://docs.python.org/)
- [Node.js 官方文档](https://nodejs.org/)
- [npm 文档](https://docs.npmjs.com/)
- [nvm 项目](https://github.com/nvm-sh/nvm)

### 工具文档
- [pip 用户指南](https://pip.pypa.io/en/stable/user_guide/)
- [venv 文档](https://docs.python.org/3/library/venv.html)
- [pm2 文档](https://pm2.keymetrics.io/)
- [yarn 文档](https://yarnpkg.com/)

### 最佳实践
- [The Twelve-Factor App](https://12factor.net/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)

## 📊 项目状态

![Status](https://img.shields.io/badge/status-active-success.svg)
![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/farfarfun">farfarfun</a>
</p>
