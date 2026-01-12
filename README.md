# Fundeploy - Python 环境自动化部署工具

这是一个 Python 环境自动化部署工具集，提供完整的 Python 开发环境自动化配置方案。

## 项目概述

本项目提供了一套完整的 Python 开发环境自动化配置方案，帮助开发者快速搭建和配置 Python 开发环境。

### 主要功能

- ✅ **自动创建 Python 虚拟环境**：支持 Python 3.8-3.14 多个版本
- ✅ **自动安装基础包**：预装常用开发工具包
- ✅ **智能 pip 源配置**：自动检测并配置最快的 pip 镜像源
- ✅ **网络连通性检测**：自动测试各镜像源的可用性和下载速度
- ✅ **交互式操作**：友好的交互界面，支持非交互模式
- ✅ **自动备份配置**：配置前自动备份现有配置
- ✅ **保留现有配置**：自动读取并保留本地已有的 pip 源配置（包括带认证的源）

## 目录结构

```
fundeploy/
├── README.md                                    # 项目主说明文档
├── test-curl-mode.sh                           # curl 模式测试脚本
└── scripts/
    ├── 01-configure-pip-sources/               # pip 源配置脚本
    │   ├── deploy.sh                           # 主脚本
    │   └── readme.md                           # 详细说明文档
    └── 02-create-python-env/                   # Python 环境创建脚本
        ├── deploy.sh                           # 主脚本
        └── readme.md                           # 详细说明文档
```

## 快速开始

### 1. 配置 pip 源（推荐先执行）

```bash
# 进入脚本目录
cd scripts/01-configure-pip-sources

# 运行脚本
./deploy.sh

# 或通过 curl 执行
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/01-configure-pip-sources/deploy.sh | bash
```

### 2. 创建 Python 环境

```bash
# 进入脚本目录
cd scripts/02-create-python-env

# 运行脚本
./deploy.sh

# 或通过 curl 执行
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/02-create-python-env/deploy.sh | bash
```

## 脚本说明

### 1. configure-pip-sources - pip 源自动配置

**位置**：`scripts/01-configure-pip-sources/deploy.sh`

**功能**：自动检测网络连通性并配置常用的 pip 镜像源。

**主要特性**：
- 自动检测所有预定义的 pip 镜像源
- 测试每个源的响应延迟和实际下载速度
- 按下载速度自动排序，最快的源作为主源
- 自动读取并保留本地已有的 pip 源配置
- 支持带认证信息的源

**详细文档**：[查看完整说明](scripts/01-configure-pip-sources/readme.md)

**快速使用**：
```bash
cd scripts/01-configure-pip-sources
./deploy.sh
```

### 2. create-python-env - Python 环境创建

**位置**：`scripts/02-create-python-env/deploy.sh`

**功能**：使用 `uv` 创建 Python 虚拟环境并安装基础包。

**主要特性**：
- 支持 Python 3.8-3.14 多个版本
- 自动安装 uv（如果未安装）
- 交互式版本选择界面
- 自动安装基础包：`pip`、`funutil`、`funbuild`、`funinstall`、`funsecret`
- 支持安装额外的 Python 包

**详细文档**：[查看完整说明](scripts/02-create-python-env/readme.md)

**快速使用**：
```bash
cd scripts/02-create-python-env
./deploy.sh
```

## 使用建议

### 推荐的使用流程

1. **首次使用**：
   ```bash
   # 1. 先配置 pip 源（提高后续安装速度）
   cd scripts/01-configure-pip-sources
   ./deploy.sh
   
   # 2. 创建 Python 环境
   cd ../02-create-python-env
   ./deploy.sh
   ```

2. **后续使用**：
   - 如果网络环境变化，可以重新运行 `01-configure-pip-sources/deploy.sh` 更新 pip 源配置
   - 如果需要创建新的 Python 版本环境，直接运行 `02-create-python-env/deploy.sh`

### 两个脚本的关系

- **`01-configure-pip-sources`** 用于配置 pip 镜像源，提高包下载速度
- **`02-create-python-env`** 用于创建 Python 虚拟环境并安装包
- **建议先运行 `01-configure-pip-sources`**，这样在创建环境时安装包会更快

## 通过 curl 执行

### 配置 pip 源

```bash
# 正常执行（支持交互）
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/01-configure-pip-sources/deploy.sh | bash

# 非交互模式
NONINTERACTIVE=1 curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/01-configure-pip-sources/deploy.sh | bash
```

### 创建 Python 环境

```bash
# 正常执行（支持交互）
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/02-create-python-env/deploy.sh | bash

# 指定版本（跳过交互）
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/02-create-python-env/deploy.sh | bash -s -- -v 3.12

# 指定版本并安装额外的包
curl -LsSf https://raw.githubusercontent.com/farfarfun/fundeploy/master/scripts/02-create-python-env/deploy.sh | bash -s -- -v 3.12 -p requests -p flask
```

## 环境变量

两个脚本都支持以下环境变量：

- `NONINTERACTIVE=1`：强制非交互模式，自动使用默认值，不进行交互

## 前置要求

### 网络连接

所有脚本都需要网络连接：
- `01-configure-pip-sources`：需要访问各个 pip 镜像源进行测试
- `02-create-python-env`：需要从 PyPI 下载和安装包，以及可能需要下载 uv 安装程序

### 系统要求

- **操作系统**：macOS、Linux（Windows 需要 WSL 或 Git Bash）
- **Shell**：Bash 3.2+（macOS 默认 bash 3.x 也支持）
- **工具**：`curl`（通常系统自带）

**注意**：`uv` 会在 `02-create-python-env` 脚本运行时自动检测并安装，无需手动安装。

## 故障排除

### 通用问题

#### 问题：脚本执行权限不足

**解决方案**：
```bash
chmod +x scripts/01-configure-pip-sources/deploy.sh
chmod +x scripts/02-create-python-env/deploy.sh
```

#### 问题：网络连接问题

**解决方案**：
1. 检查网络连接
2. 检查防火墙设置
3. 如果使用代理，确保代理配置正确

### pip 源配置问题

详细故障排除请参考：[pip 源配置脚本说明](scripts/01-configure-pip-sources/readme.md#故障排除)

### Python 环境创建问题

详细故障排除请参考：[Python 环境创建脚本说明](scripts/02-create-python-env/readme.md#故障排除)

## 项目结构说明

### 脚本组织

脚本按照功能模块组织在不同的目录中：

- **`01-configure-pip-sources`**：pip 源配置相关脚本
- **`02-create-python-env`**：Python 环境创建相关脚本

每个目录包含：
- `deploy.sh`：主执行脚本
- `readme.md`：详细的说明文档

### 命名规范

- 目录使用数字前缀（`01-`、`02-`）表示执行顺序
- 主脚本统一命名为 `deploy.sh`
- 说明文档统一命名为 `readme.md`

## 开发说明

### 本地测试

在本地开发时，可以使用以下方法测试脚本：

```bash
# 测试 pip 源配置脚本
cd scripts/01-configure-pip-sources
./deploy.sh

# 测试 Python 环境创建脚本
cd ../02-create-python-env
./deploy.sh
```

### 测试 curl 执行方式

可以使用项目根目录的 `test-curl-mode.sh` 脚本测试 curl 执行方式：

```bash
# 测试 pip 源配置脚本
cat scripts/01-configure-pip-sources/deploy.sh | bash

# 测试 Python 环境创建脚本
cat scripts/02-create-python-env/deploy.sh | bash
```

## 相关链接

- [pip 源配置脚本详细说明](scripts/01-configure-pip-sources/readme.md)
- [Python 环境创建脚本详细说明](scripts/02-create-python-env/readme.md)
- [uv 官方文档](https://github.com/astral-sh/uv)
- [Python 虚拟环境文档](https://docs.python.org/3/tutorial/venv.html)
- [pip 配置文档](https://pip.pypa.io/en/stable/topics/configuration/)

## 许可证

本脚本遵循项目许可证。
