# fundeploy - 快速部署环境脚本

一个用于快速部署Python和Node.js开发环境的脚本工具集。

## 项目简介

fundeploy提供了一套标准化的环境部署脚本，帮助开发者快速搭建Python和Node.js开发环境。支持多种Linux发行版，具有完善的日志输出和错误处理机制。

## 功能特性

- ✅ **Python环境部署**：自动安装Python3、pip、虚拟环境
- ✅ **Node.js环境部署**：支持多版本Node.js安装，支持nvm管理
- ✅ **依赖管理**：自动安装项目依赖包
- ✅ **多系统支持**：支持Ubuntu/Debian、CentOS/RHEL等主流Linux发行版
- ✅ **标准化日志**：彩色日志输出，便于追踪部署过程
- ✅ **灵活配置**：支持命令行参数和环境变量配置

## 快速开始

### Python环境部署

```bash
# 基础安装
./deploy_python.sh

# 创建虚拟环境
./deploy_python.sh --venv venv

# 创建虚拟环境并安装依赖
./deploy_python.sh --venv venv --requirements requirements.txt

# 查看帮助
./deploy_python.sh --help
```

### Node.js环境部署

```bash
# 基础安装（默认Node.js 18）
./deploy_nodejs.sh

# 指定版本安装
./deploy_nodejs.sh --version 20

# 使用nvm安装
./deploy_nodejs.sh --nvm --version 18

# 安装全局工具包（yarn, pm2）
./deploy_nodejs.sh --globals

# 安装项目依赖
./deploy_nodejs.sh --deps

# 完整部署
./deploy_nodejs.sh --version 18 --globals --deps

# 查看帮助
./deploy_nodejs.sh --help
```

## 部署规范

### Python部署规范

1. **Python版本**：默认安装Python 3.x最新稳定版
2. **包管理器**：使用pip进行包管理
3. **虚拟环境**：推荐使用venv创建项目独立环境
4. **依赖管理**：使用requirements.txt文件管理项目依赖
5. **目录结构**：
   ```
   project/
   ├── venv/              # 虚拟环境目录
   ├── requirements.txt   # 依赖清单
   ├── src/              # 源代码目录
   └── tests/            # 测试目录
   ```

### Node.js部署规范

1. **Node.js版本**：默认使用LTS版本（当前为18.x）
2. **包管理器**：支持npm和yarn
3. **进程管理**：推荐使用pm2进行生产环境进程管理
4. **依赖管理**：使用package.json管理项目依赖
5. **全局工具**：
   - `yarn`：快速的包管理器
   - `pm2`：生产环境进程管理工具
6. **目录结构**：
   ```
   project/
   ├── node_modules/     # 依赖包目录
   ├── package.json      # 项目配置
   ├── src/             # 源代码目录
   └── dist/            # 构建输出目录
   ```

## 脚本说明

### deploy_python.sh

Python环境部署脚本，主要功能：

- 自动检测并安装Python3
- 升级pip到最新版本
- 创建Python虚拟环境
- 安装requirements.txt中的依赖包

**参数说明**：
- `--venv <path>`：创建虚拟环境（默认：venv）
- `--requirements <file>`：安装依赖包（默认：requirements.txt）
- `-h, --help`：显示帮助信息

### deploy_nodejs.sh

Node.js环境部署脚本，主要功能：

- 自动检测并安装Node.js
- 支持指定版本安装
- 支持nvm版本管理
- 配置npm镜像源
- 安装常用全局包（yarn、pm2）
- 安装项目依赖

**参数说明**：
- `--version <version>`：指定Node.js版本（默认：18）
- `--nvm`：使用nvm安装Node.js
- `--globals`：安装常用全局包（yarn, pm2）
- `--deps`：安装项目依赖（从package.json）
- `-h, --help`：显示帮助信息

**环境变量**：
- `NODE_VERSION`：指定Node.js版本（默认：18）

## 使用场景

### 场景1：新服务器Python环境初始化

```bash
# 在新服务器上快速部署Python环境
./deploy_python.sh --venv myproject_env --requirements requirements.txt

# 激活虚拟环境
source myproject_env/bin/activate

# 运行应用
python app.py
```

### 场景2：Node.js项目快速部署

```bash
# 部署Node.js环境并安装依赖
./deploy_nodejs.sh --version 18 --globals --deps

# 使用pm2启动应用
pm2 start app.js --name myapp
```

### 场景3：使用nvm管理多版本Node.js

```bash
# 使用nvm安装Node.js 20
./deploy_nodejs.sh --nvm --version 20

# 切换版本
nvm use 18
```

## 系统要求

- **操作系统**：
  - Ubuntu 18.04+
  - Debian 10+
  - CentOS 7+
  - RHEL 7+
  - 其他Linux发行版（使用--nvm参数）

- **权限要求**：需要sudo权限进行系统级软件安装

- **网络要求**：需要互联网连接以下载软件包

## 故障排除

### Python相关

**问题**：pip安装包时出现权限错误
```bash
# 解决方案：使用虚拟环境
./deploy_python.sh --venv venv
source venv/bin/activate
pip install <package>
```

**问题**：Python版本过低
```bash
# 手动指定Python3
python3 --version
python3 -m pip install --upgrade pip
```

### Node.js相关

**问题**：npm安装速度慢
```bash
# 设置国内镜像源
npm config set registry https://registry.npmmirror.com
```

**问题**：全局包安装权限错误
```bash
# 使用nvm管理Node.js，避免权限问题
./deploy_nodejs.sh --nvm --version 18
```

**问题**：特定版本Node.js不可用
```bash
# 使用nvm安装特定版本
./deploy_nodejs.sh --nvm --version 20.10.0
```

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目。

### 开发规范

1. 脚本应使用bash编写
2. 包含详细的注释和日志输出
3. 错误处理要完善，使用`set -e`
4. 提供帮助信息（--help）
5. 支持参数化配置

## 许可证

MIT License

## 作者

farfarfun

## 更新日志

### v1.0.0 (2026-01-09)

- ✨ 初始版本发布
- ✨ 支持Python环境部署
- ✨ 支持Node.js环境部署
- ✨ 支持多种Linux发行版
- ✨ 完善的日志和错误处理

## 相关链接

- [Python官方文档](https://docs.python.org/)
- [Node.js官方文档](https://nodejs.org/)
- [nvm项目](https://github.com/nvm-sh/nvm)
- [pm2文档](https://pm2.keymetrics.io/)
