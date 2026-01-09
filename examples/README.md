# 示例文件说明

本目录包含fundeploy项目的示例配置文件。

## 文件说明

### requirements.txt

Python项目依赖示例文件，包含常用的Python包：

- Web框架：Flask、Django
- 数据处理：pandas、numpy
- 数据库：SQLAlchemy、pymongo
- HTTP请求：requests
- 测试工具：pytest
- 代码质量：black、flake8、mypy
- 其他工具：python-dotenv、pydantic

### package.json

Node.js项目配置示例文件，包含：

- 项目基本信息
- 常用脚本命令
- 依赖包配置
- 引擎版本要求

## 使用方法

### Python项目

```bash
# 复制示例文件到项目根目录
cp examples/requirements.txt /path/to/your/project/

# 使用部署脚本
cd /path/to/your/project
/path/to/fundeploy/deploy_python.sh --venv venv --requirements requirements.txt
```

### Node.js项目

```bash
# 复制示例文件到项目根目录
cp examples/package.json /path/to/your/project/

# 使用部署脚本
cd /path/to/your/project
/path/to/fundeploy/deploy_nodejs.sh --deps
```

## 自定义

您可以根据项目实际需求修改这些示例文件：

- 添加或删除依赖包
- 调整版本号
- 修改脚本命令
- 更新项目信息
