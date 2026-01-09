# fundeploy

[![License](https://img.shields.io/github/license/farfarfun/fundeploy)](https://github.com/farfarfun/fundeploy/blob/master/LICENSE)
[![Python Version](https://img.shields.io/badge/python-3.7+-blue.svg)](https://www.python.org/downloads/)
[![GitHub Stars](https://img.shields.io/github/stars/farfarfun/fundeploy?style=social)](https://github.com/farfarfun/fundeploy)

> 部署工具包 - 提供快速环境部署和配置管理的脚本工具

`fundeploy` 是一个轻量级的部署工具包，旨在简化开发环境、服务器环境和应用程序的快速部署流程。通过提供一系列预配置的部署脚本和自动化工具，帮助开发者快速搭建和管理各种运行环境。

## ✨ 特性

- 🚀 **快速部署** - 一键部署常用的开发和生产环境
- ⚙️ **自动化配置** - 自动化环境配置和依赖安装
- 🔧 **灵活定制** - 支持自定义部署脚本和配置
- 📦 **多环境支持** - 支持 Docker、虚拟机、云服务器等多种部署环境
- 🛡️ **安全可靠** - 内置安全检查和回滚机制
- 📝 **脚本管理** - 统一管理和维护部署脚本

## 📦 安装

### 使用 pip 安装

```bash
pip install fundeploy
```

### 从源码安装

```bash
git clone https://github.com/farfarfun/fundeploy.git
cd fundeploy
pip install -e .
```

## 🚀 快速开始

### 基本使用

```python
from fundeploy import Deploy

# 创建部署实例
deploy = Deploy()

# 部署环境
deploy.setup_environment()
```

### 使用部署脚本

```bash
# 部署开发环境
fundeploy deploy --env development

# 部署生产环境
fundeploy deploy --env production

# 查看可用的部署模板
fundeploy list-templates
```

## 📖 使用示例

### 示例 1: 部署 Python 开发环境

```python
from fundeploy import PythonEnv

# 配置 Python 环境
env = PythonEnv(version="3.9")
env.setup()
env.install_dependencies("requirements.txt")
```

### 示例 2: Docker 容器部署

```python
from fundeploy import DockerDeploy

# 部署 Docker 容器
docker = DockerDeploy()
docker.build_image("myapp:latest")
docker.run_container(port=8080)
```

### 示例 3: 服务器配置管理

```python
from fundeploy import ServerConfig

# 配置服务器环境
config = ServerConfig(host="192.168.1.100")
config.setup_nginx()
config.setup_ssl()
config.deploy_app("/path/to/app")
```

## 📚 主要功能

### 环境部署

- Python/Node.js/Java 等开发环境快速部署
- 数据库环境配置（MySQL、PostgreSQL、MongoDB 等）
- 缓存服务部署（Redis、Memcached 等）
- Web 服务器配置（Nginx、Apache 等）

### 容器化部署

- Docker 环境搭建
- Docker Compose 编排
- Kubernetes 集群部署
- 容器镜像管理

### 云服务部署

- 阿里云/腾讯云/AWS 等云平台支持
- 自动化实例创建和配置
- 负载均衡配置
- 自动扩容机制

### 配置管理

- 环境变量管理
- 配置文件模板
- 密钥管理
- 版本控制

## 🔧 配置说明

创建配置文件 `fundeploy.yaml`:

```yaml
# 部署配置
deployment:
  environment: production
  provider: docker
  
# 应用配置
application:
  name: myapp
  version: 1.0.0
  port: 8080
  
# 服务配置
services:
  - name: nginx
    version: latest
  - name: redis
    version: 6.2
```

## 🤝 贡献

欢迎贡献代码、报告问题或提出新功能建议！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🔗 相关项目

farfarfun 系列工具包：

- [fundrive](https://github.com/farfarfun/fundrive) - 云存储驱动工具包
- [fundata](https://github.com/farfarfun/fundata) - 数据处理工具包
- [funbuild](https://github.com/farfarfun/funbuild) - 构建和部署工具包
- [funnotice](https://github.com/farfarfun/funnotice) - 通知服务工具包

## 📮 联系方式

- 项目主页: https://github.com/farfarfun/fundeploy
- 问题反馈: https://github.com/farfarfun/fundeploy/issues

## 🌟 Star History

如果这个项目对你有帮助，请给我们一个 ⭐️ Star！

---

**注意**: 本项目目前处于早期开发阶段，API 可能会发生变化。欢迎提供反馈和建议！
