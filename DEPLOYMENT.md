# fundeploy 部署规范文档

## 概述

本文档详细说明fundeploy项目的部署规范，包括Python和Node.js环境的标准化部署流程。

## Python环境部署规范

### 1. 版本管理

- **Python版本**：使用Python 3.8+版本
- **推荐版本**：Python 3.10或3.11（最新稳定版）
- **版本检查**：`python3 --version`

### 2. 包管理

#### 2.1 pip配置

```bash
# 升级pip
python3 -m pip install --upgrade pip

# 配置pip源（可选，国内镜像）
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

#### 2.2 依赖管理

- 使用`requirements.txt`管理依赖
- 版本锁定：推荐指定具体版本号
- 分类管理：可使用多个requirements文件
  - `requirements.txt`：生产环境依赖
  - `requirements-dev.txt`：开发环境依赖
  - `requirements-test.txt`：测试环境依赖

### 3. 虚拟环境

#### 3.1 创建虚拟环境

```bash
# 使用venv（推荐）
python3 -m venv venv

# 使用virtualenv
virtualenv venv
```

#### 3.2 虚拟环境目录命名规范

- 标准命名：`venv`、`.venv`、`env`
- 添加到`.gitignore`：虚拟环境不应提交到版本控制

#### 3.3 激活虚拟环境

```bash
# Linux/Mac
source venv/bin/activate

# Windows
venv\Scripts\activate
```

### 4. 项目目录结构

```
project/
├── venv/                  # 虚拟环境（不提交）
├── src/                   # 源代码
│   ├── __init__.py
│   ├── main.py
│   └── utils/
├── tests/                 # 测试代码
│   ├── __init__.py
│   └── test_main.py
├── docs/                  # 文档
├── requirements.txt       # 生产依赖
├── requirements-dev.txt   # 开发依赖
├── .gitignore
├── .env.example          # 环境变量示例
├── README.md
└── setup.py              # 打包配置（可选）
```

### 5. 环境变量管理

- 使用`.env`文件管理环境变量
- 使用`python-dotenv`库加载环境变量
- `.env`文件不提交，提供`.env.example`模板

### 6. 代码质量工具

```bash
# 代码格式化
black src/

# 代码检查
flake8 src/

# 类型检查
mypy src/

# 测试
pytest
```

## Node.js环境部署规范

### 1. 版本管理

- **Node.js版本**：使用LTS版本
- **当前推荐**：Node.js 18.x或20.x
- **版本管理工具**：nvm（推荐）

#### 1.1 使用nvm管理版本

```bash
# 安装特定版本
nvm install 18

# 使用特定版本
nvm use 18

# 设置默认版本
nvm alias default 18

# 查看已安装版本
nvm list
```

### 2. 包管理

#### 2.1 npm配置

```bash
# 升级npm
npm install -g npm@latest

# 配置镜像源（可选）
npm config set registry https://registry.npmmirror.com
```

#### 2.2 yarn配置（推荐）

```bash
# 安装yarn
npm install -g yarn

# 配置镜像源
yarn config set registry https://registry.npmmirror.com
```

### 3. 依赖管理

#### 3.1 package.json规范

```json
{
  "name": "project-name",
  "version": "1.0.0",
  "description": "项目描述",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest",
    "lint": "eslint .",
    "build": "webpack"
  },
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=9.0.0"
  }
}
```

#### 3.2 依赖分类

- `dependencies`：生产环境依赖
- `devDependencies`：开发环境依赖
- `peerDependencies`：对等依赖（库开发）

#### 3.3 版本锁定

- 使用`package-lock.json`（npm）或`yarn.lock`（yarn）
- 锁定文件应提交到版本控制

### 4. 项目目录结构

```
project/
├── node_modules/         # 依赖包（不提交）
├── src/                  # 源代码
│   ├── index.js
│   ├── routes/
│   ├── controllers/
│   └── utils/
├── dist/                 # 构建输出（不提交）
├── tests/                # 测试代码
├── public/               # 静态资源
├── config/               # 配置文件
├── package.json
├── package-lock.json
├── .gitignore
├── .env.example
├── .eslintrc.js
├── .prettierrc
└── README.md
```

### 5. 全局工具推荐

```bash
# 进程管理
npm install -g pm2

# 开发工具
npm install -g nodemon

# 包管理
npm install -g yarn

# 代码质量
npm install -g eslint
```

### 6. 进程管理（生产环境）

#### 6.1 使用PM2

```bash
# 启动应用
pm2 start index.js --name myapp

# 查看状态
pm2 status

# 查看日志
pm2 logs myapp

# 重启应用
pm2 restart myapp

# 停止应用
pm2 stop myapp

# 开机自启动
pm2 startup
pm2 save
```

#### 6.2 PM2配置文件

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'myapp',
    script: './index.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

### 7. 环境变量管理

- 使用`.env`文件管理环境变量
- 使用`dotenv`包加载环境变量
- `.env`文件不提交，提供`.env.example`模板

### 8. 代码质量工具

```bash
# ESLint检查
eslint .

# Prettier格式化
prettier --write .

# 测试
npm test
```

## 通用部署规范

### 1. 版本控制

- 使用Git进行版本控制
- 遵循语义化版本（SemVer）
- 编写规范的commit信息

### 2. 环境区分

- 开发环境（development）
- 测试环境（testing）
- 预发布环境（staging）
- 生产环境（production）

### 3. 安全规范

- 不提交敏感信息（密码、密钥）
- 使用环境变量管理配置
- 定期更新依赖包
- 及时修复安全漏洞

### 4. 日志规范

- 使用结构化日志
- 区分日志级别（DEBUG, INFO, WARN, ERROR）
- 日志文件轮转

### 5. 监控和告警

- 应用性能监控（APM）
- 错误追踪
- 资源使用监控
- 设置告警阈值

## 部署检查清单

### Python项目

- [ ] Python版本符合要求
- [ ] 创建并激活虚拟环境
- [ ] 安装所有依赖包
- [ ] 配置环境变量
- [ ] 运行测试通过
- [ ] 代码质量检查通过

### Node.js项目

- [ ] Node.js版本符合要求
- [ ] 安装所有依赖包
- [ ] 配置环境变量
- [ ] 运行测试通过
- [ ] 代码质量检查通过
- [ ] 配置进程管理（生产环境）

## 故障处理流程

1. **问题识别**：查看日志、错误信息
2. **问题定位**：复现问题、检查配置
3. **问题修复**：修改代码、更新配置
4. **测试验证**：本地测试、环境测试
5. **部署上线**：灰度发布、全量发布
6. **监控观察**：观察指标、收集反馈

## 参考资料

- [Python官方文档](https://docs.python.org/)
- [Node.js官方文档](https://nodejs.org/)
- [The Twelve-Factor App](https://12factor.net/)
- [Semantic Versioning](https://semver.org/)
