# nltdeploy

用于在本机快速准备开发环境的 Bash 脚本集合：pip 镜像、Python/uv 虚拟环境、Airflow 3、Celery、常用 CLI（如 gum）、以及 GitHub 克隆网络修复。各脚本尽量自包含，可单独 `curl … | bash` 使用；内容已同步到 [Gitee 同名仓库](https://gitee.com/farfarfun/nltdeploy)，国内网络可改用下方 Gitee 的 raw 地址。

## 项目概述

- **01-configure-pip-sources**：测速并写入 pip 配置，保留已有认证源等。
- **02-create-python-env**：用 [uv](https://github.com/astral-sh/uv) 建虚拟环境并安装常用基础包。
- **03-airflow**：本机 **Apache Airflow 3.x**（安装、启停、DAG 脚手架、用户与 HTTP 触发等）；依赖 gum，脚本内会按 README 同款方式拉取安装。
- **04-celery**：Celery 安装与 worker/beat/flower 启停、状态；默认 `~/opt/celery`。
- **05-utils**：安装 **gum**（`~/opt/gum`）与可选 shell 别名（`ll` / `la` / `lla`）。
- **06-github**：诊断并修复「网页能开但 `git clone` 失败」的常见 HTTPS/SSH 问题。

Python 包元数据见根目录 [`pyproject.toml`](pyproject.toml)（MIT）。命令行入口名在元数据中列为 `nltdeploy`，与 `src/` 下模块布局仍在演进；Shell 脚本是当前主力的使用方式。

## 推荐：一键安装到 ~/.local/nltdeploy

将仓库内脚本同步到 `~/.local/nltdeploy/libexec/nltdeploy/`，并在 `~/.local/nltdeploy/bin/` 生成以 `nlt-` / `nlt-service-` 开头的命令（实现与规格见 [`docs/superpowers/specs/2026-04-11-nltdeploy-local-install-design.md`](docs/superpowers/specs/2026-04-11-nltdeploy-local-install-design.md)）。

**克隆仓库后本地安装 / 更新：**

```bash
chmod +x install.sh
./install.sh              # 默认：若当前目录为 git 仓库，先 git pull --ff-only，再同步 libexec 与 bin
./install.sh update       # 与上一行等价（显式更新）
```

**远程一行：**

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/install.sh | bash
# 国内（Gitee raw，脚本内容与 GitHub 相同）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/install.sh | bash
# 显式传入 update（与无参行为相同：拉取后再同步）
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/install.sh | bash -s -- update
```

管道执行时 **仅下载 `install.sh`**，脚本会在本机 **`git clone` 完整仓库** 到 **`${NLTDEPLOY_ROOT}/src/nltdeploy`**（默认即 `~/.local/nltdeploy/src/nltdeploy`），再从中同步 `scripts/` 到 `libexec`。克隆顺序：**优先 GitHub** `farfarfun/nltdeploy`，失败则 **Gitee** 同名仓库。需要已安装 **`git`**。

**每次执行**（`install` 与 `update` 相同）：只要 `scripts/` 所在仓库根目录存在 **`.git`**，会先执行 **`git pull --ff-only`**，再覆盖复制到 `libexec` 并重新生成 `bin` 包装。若不想访问远端（离线重装），可设置 **`NLTDEPLOY_SKIP_GIT_PULL=1`**。

可选覆盖克隆地址（fork 或镜像）：

- **`NLTDEPLOY_GITHUB_REPO`**：默认 `https://github.com/farfarfun/nltdeploy.git`
- **`NLTDEPLOY_GITEE_REPO`**：默认 `https://gitee.com/farfarfun/nltdeploy.git`
- **`NLTDEPLOY_SRC_DIR`**：克隆目标目录（默认 `${NLTDEPLOY_ROOT}/src/nltdeploy`）

**配置 PATH：**

```bash
export PATH="$HOME/.local/nltdeploy/bin:$PATH"
```

可选环境变量：

- **`NLTDEPLOY_ROOT`**：安装根目录（默认 `~/.local/nltdeploy`）。
- **`NLTDEPLOY_SKIP_PROFILE_HINT=1`**：安装结束时不打印 PATH 提示（适合 CI）。
- **`NLTDEPLOY_SKIP_GIT_PULL=1`**：不执行 `git pull`，仍按当前工作区/已克隆内容同步 `libexec` 与 `bin`。
- **`NLTDEPLOY_GITHUB_REPO` / `NLTDEPLOY_GITEE_REPO` / `NLTDEPLOY_SRC_DIR`**：管道安装时的克隆源与目录（见上节）。

本地验证安装逻辑：

```bash
bash tests/install_smoke.sh
```

### 命令对照表（安装后的 `bin` 与 `scripts/`）

| 安装后的命令 | 对应原 scripts 用法 |
|-------------|---------------------|
| `nlt-pip-sources` | `scripts/01-configure-pip-sources/deploy.sh` |
| `nlt-python-env` | `scripts/02-create-python-env/deploy.sh` |
| `nlt-airflow-install` | `scripts/03-airflow/deploy.sh` install |
| `nlt-airflow`（可接任意子命令；无参为 gum 菜单） | `scripts/03-airflow/deploy.sh` … |
| `nlt-service-airflow-start` / `stop` / `restart` / `status` | 同上 `deploy.sh` 的 start / stop / restart / status |
| `nlt-celery-install` | `scripts/04-celery/celery-setup.sh` install |
| `nlt-service-celery-worker-start` | `celery-setup.sh` start-worker |
| `nlt-service-celery-beat-start` | `celery-setup.sh` start-beat |
| `nlt-service-celery-flower-start` | `celery-setup.sh` start-flower |
| `nlt-service-celery-stop` | `celery-setup.sh` stop |
| `nlt-service-celery-restart` | `celery-setup.sh` restart |
| `nlt-service-celery-status` | `celery-setup.sh` status |
| `nlt-utils`（可接子参数，如 `gum`、`all`） | `scripts/05-utils/utils-setup.sh` … |
| `nlt-github-net` | `scripts/06-github/deploy.sh` |

## 目录结构

```
nltdeploy/
├── LICENSE
├── README.md
├── install.sh                          # 一键安装 nlt-* 到 ~/.local/nltdeploy
├── pyproject.toml
├── examples/
│   └── python_env_examples.md          # 与 uv/Python 环境相关的用法示例（偏命令行工具向）
├── tests/
│   └── install_smoke.sh                # 安装与 bin 包装冒烟测试
└── scripts/
    ├── 01-configure-pip-sources/
    │   ├── deploy.sh
    │   └── README.md
    ├── 02-create-python-env/
    │   ├── deploy.sh
    │   └── README.md
    ├── 03-airflow/
    │   └── deploy.sh                   # Airflow 3 本机 setup（见脚本头注释与用法）
    ├── 04-celery/
    │   └── celery-setup.sh
    ├── 05-utils/
    │   └── utils-setup.sh              # gum / 别名 / all
    └── 06-github/
        └── deploy.sh                   # Git 连通性诊断与修复
```

带序号的前缀表示 **推荐的大致顺序**（先配 pip 与 Python，再按需装 Airflow/Celery 等）；`04`–`06` 可按需独立执行。

## 快速开始

### 1. 配置 pip 源（建议最先执行）

```bash
cd scripts/01-configure-pip-sources
./deploy.sh
```

远程一行（交互）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/01-configure-pip-sources/deploy.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/01-configure-pip-sources/deploy.sh | bash
```

非交互：

```bash
NONINTERACTIVE=1 curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/01-configure-pip-sources/deploy.sh | bash
# 国内（Gitee）
NONINTERACTIVE=1 curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/01-configure-pip-sources/deploy.sh | bash
```

### 2. 创建 Python 环境（uv）

```bash
cd scripts/02-create-python-env
./deploy.sh
```

远程一行：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/02-create-python-env/deploy.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/02-create-python-env/deploy.sh | bash
```

指定版本、额外包（跳过部分交互）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/02-create-python-env/deploy.sh | bash -s -- -v 3.12 -p requests -p flask
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/02-create-python-env/deploy.sh | bash -s -- -v 3.12 -p requests -p flask
```

### 3. 常用 CLI（gum，Airflow/GitHub 脚本会用到）

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/05-utils/utils-setup.sh | bash -s -- gum
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/05-utils/utils-setup.sh | bash -s -- all
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/05-utils/utils-setup.sh | bash -s -- gum
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/05-utils/utils-setup.sh | bash -s -- all
```

### 4. Apache Airflow 3.x（本机）

```bash
cd scripts/03-airflow
chmod +x deploy.sh
./deploy.sh              # 无参数时进入 gum 菜单；子命令见脚本头部注释
```

远程一行（仅示例，按需加子命令）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/03-airflow/deploy.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/03-airflow/deploy.sh | bash
```

默认约定：`AIRFLOW_HOME=~/opt/airflow`，Web 端口等与脚本内 `DEFAULT_*` 一致；更多环境变量与 `http-trigger` 说明见 **`scripts/03-airflow/deploy.sh` 文件头注释**。

### 5. Celery（本机）

```bash
cd scripts/04-celery
chmod +x celery-setup.sh
./celery-setup.sh
```

默认 `CELERY_HOME=~/opt/celery`，Broker 等可通过环境变量覆盖，详见脚本头部。

### 6. 修复 GitHub 克隆网络

```bash
cd scripts/06-github
chmod +x deploy.sh
./deploy.sh
```

或：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/scripts/06-github/deploy.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/06-github/deploy.sh | bash
```

（建议本机已具备 `gum` 或先执行 `05-utils`。）

## 脚本说明摘要

| 目录 | 入口文件 | 作用 |
|------|-----------|------|
| `01-configure-pip-sources` | `deploy.sh` | 镜像测速、写入 pip 配置、备份 |
| `02-create-python-env` | `deploy.sh` | uv、多版本 Python venv、基础包 |
| `03-airflow` | `deploy.sh` | Airflow 3 安装与日常运维封装 |
| `04-celery` | `celery-setup.sh` | Celery 安装与进程管理 |
| `05-utils` | `utils-setup.sh` | gum 与 shell 便利项 |
| `06-github` | `deploy.sh` | GitHub 克隆通道诊断与修复 |

子目录中的详细说明：

- [pip 源配置](scripts/01-configure-pip-sources/README.md)
- [Python 环境创建](scripts/02-create-python-env/README.md)

## 使用建议

1. 首次：**01** → **02**；若要用 Airflow/ GitHub 诊断交互界面，可先 **05**（装 gum）。
2. 网络或镜像变化时可重跑 **01**。
3. **03** 仅面向 Airflow **3.x**，与 2.x 不混用。

## 通过 curl 执行时的公共约定

- **`NONINTERACTIVE=1`**：两个主 deploy 脚本均支持，用于无 TTY 时跳过确认（见各脚本说明）。
- **Fork 或自建 raw 地址**：部分脚本（如 `01`、`02`、`03-airflow`）会读取 **`NLTDEPLOY_RAW_BASE`**（若未设置则回退到 **`nltdeploy_RAW_BASE`**），默认 `https://raw.githubusercontent.com/farfarfun/nltdeploy/master`，用于拉取同仓库下的 `utils-setup.sh` 等。国内可设为 Gitee：`export NLTDEPLOY_RAW_BASE=https://gitee.com/farfarfun/nltdeploy/raw/master`。Fork 后可 `export NLTDEPLOY_RAW_BASE=https://raw.githubusercontent.com/<org>/<repo>/<branch>`。仍支持仅设置 `nltdeploy_RAW_BASE` 的旧写法。

## 环境变量（跨脚本常见）

- **`NONINTERACTIVE=1`**：非交互。
- **`NLTDEPLOY_RAW_BASE`**：覆盖拉取本仓库 raw 脚本的根 URL（优先于 `nltdeploy_RAW_BASE`）。见上一节「通过 curl 执行时的公共约定」。
- **`05-utils`** 另有 `GUM_HOME`、`GUM_TAG`、`GUM_USE_BREW`、`SKIP_GUM_SHELL_PROFILE`、`SKIP_UTILS_SHELL_ALIASES` 等，见 `utils-setup.sh` 头部。

各专项脚本（Airflow、Celery、GitHub）的专有变量以各自文件头注释为准。

## 前置要求

- **网络**：测速、装包、拉取安装脚本均需联网。
- **系统**：macOS、Linux（Windows 建议 WSL）。
- **Shell**：Bash 3.2+；**`curl`** 通常必需。
- **`02-create-python-env`** 会在需要时安装 **uv**，无需事先安装。

## 故障排除

### 脚本没有执行权限

```bash
chmod +x install.sh
chmod +x scripts/01-configure-pip-sources/deploy.sh
chmod +x scripts/02-create-python-env/deploy.sh
chmod +x scripts/03-airflow/deploy.sh
chmod +x scripts/04-celery/celery-setup.sh
chmod +x scripts/05-utils/utils-setup.sh
chmod +x scripts/06-github/deploy.sh
```

### 网络与代理

检查防火墙与代理；企业网络可优先跑 **06-github** 或 **01** 选对镜像。

### 分脚本详细排错

- [pip 源脚本说明 / 故障排除](scripts/01-configure-pip-sources/README.md)
- [Python 环境脚本说明 / 故障排除](scripts/02-create-python-env/README.md)

### 本地检验「管道执行」

不经过 GitHub 时可把脚本通过 stdin 交给 bash，便于本地改完再测：

```bash
bash < scripts/01-configure-pip-sources/deploy.sh
bash < scripts/02-create-python-env/deploy.sh
```

## 命名规范

- 目录使用 **`01-`…`06-`** 表示推荐顺序或模块划分。
- 多数模块主入口为 **`deploy.sh`**；Celery 使用 **`celery-setup.sh`** 以区别于服务名。

## 相关链接

- [uv](https://github.com/astral-sh/uv)
- [Python venv](https://docs.python.org/3/tutorial/venv.html)
- [pip 配置](https://pip.pypa.io/en/stable/topics/configuration/)
- [Apache Airflow 文档](https://airflow.apache.org/docs/apache-airflow/stable/)
- [Celery 文档](https://docs.celeryq.dev/)

## 许可证

[MIT License](LICENSE)

Copyright (c) 2026 farfarfun
