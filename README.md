# nltdeploy

用于在本机快速准备开发环境的 Bash 脚本集合：pip 镜像、Python/uv 虚拟环境、Airflow 3、Celery、[Paperclip](https://github.com/paperclipai/paperclip)（AI 编排，源码安装）、[code-server](https://github.com/coder/code-server)（浏览器内 VS Code，官方 standalone 包）、[new-api](https://github.com/QuantumNous/new-api)（LLM 网关，GitHub Release 预编译二进制）、常用 CLI（如 gum）、以及 GitHub 克隆网络修复。各脚本尽量自包含，可单独 `curl … | bash` 使用；内容已同步到 [Gitee 同名仓库](https://gitee.com/farfarfun/nltdeploy)，国内网络可改用下方 Gitee 的 raw 地址。

## 项目概述

- **pip-sources**：测速并写入 pip 配置，保留已有认证源等。
- **python-env**：用 [uv](https://github.com/astral-sh/uv) 建虚拟环境并安装常用基础包。
- **airflow**：本机 **Apache Airflow 3.x**（安装、启停、DAG 脚手架、用户与 HTTP 触发等）；依赖 gum，脚本内会按 README 同款方式拉取安装。
- **celery**：Celery 安装与 worker/beat/flower 启停、状态；默认 `~/opt/celery`。
- **utils**：安装 **gum**（`~/opt/gum`）与可选 shell 别名（`ll` / `la` / `lla`）。
- **github-net**：诊断并修复「网页能开但 `git clone` 失败」的常见 HTTPS/SSH 问题。
- **paperclip**：从 **GitHub 克隆** [paperclipai/paperclip](https://github.com/paperclipai/paperclip) 源码、`pnpm install`，并以 **`pnpm paperclipai run`** 启停；默认安装根 `~/opt/paperclip`，**默认工作区** **`~/opt/paperclip/workspace`**（环境变量 **`PAPERCLIP_WORKSPACE`**，可改）。`start` 会在实例就绪后尽量把上游 **`~/.paperclip/instances/<id>/workspaces`** 符号链接到该目录（若该 `workspaces` 已非空则跳过）。数据目录另见上游 `~/.paperclip/…`。无实例配置时 **`start` 会先非交互执行 `onboard --yes`**（依赖 `script(1)`）；也可手动 **`nlt-paperclip onboard`**（或 `NONINTERACTIVE=1 nlt-paperclip onboard`）。
- **code-server**：从 **GitHub Releases** 下载官方 **standalone** 压缩包并解压到 `~/opt/code-server`；`nohup` 后台运行，默认绑定 `127.0.0.1:8080`；无需本机 Node.js。
- **new-api**：从 **GitHub Releases** 下载 [QuantumNous/new-api](https://github.com/QuantumNous/new-api) 的预编译二进制到 `~/opt/new-api/bin`；数据目录默认 `~/opt/new-api/data`（SQLite 等），默认 **HTTP 端口 3000**；解析版本时会跳过无附件的 nightly，fallback `v0.12.6`。
- **services**（`nlt-services.sh`）：**`nlt-services`** 总入口——**`status`** 汇总各常驻服务 PID/端口/HTTP 探测；**`install`** 先选 **安装 / 卸载** 再选模块（或 `install add|remove <模块>`）；卸载不含 celery、utils（上游无 uninstall）。

仓库内脚本按 **`scripts/tools/`**（工具 / 环境）与 **`scripts/services/`**（常驻服务 + 聚合入口）分层存放，详见下文「目录结构」。

Python 包元数据见根目录 [`pyproject.toml`](pyproject.toml)（MIT）。命令行入口名在元数据中列为 `nltdeploy`，与 `src/` 下模块布局仍在演进；Shell 脚本是当前主力的使用方式。

## 推荐：一键安装到 ~/.local/nltdeploy

将仓库内脚本同步到 `~/.local/nltdeploy/libexec/nltdeploy/`，并在 `~/.local/nltdeploy/bin/` 生成以 **`nlt-`** 开头的命令（实现与规格见 [`docs/superpowers/specs/2026-04-11-nltdeploy-local-install-design.md`](docs/superpowers/specs/2026-04-11-nltdeploy-local-install-design.md)）。

**克隆仓库后本地安装 / 更新：**

```bash
chmod +x install.sh
./install.sh                    # 交互：先选「安装」「更新」或「卸载」（有 gum 则用 gum）
./install.sh install            # 非交互 / 脚本：同步 libexec 与 bin（旁侧为 git 时先 pull）
./install.sh update             # 与 install 等价
./install.sh uninstall          # 删除 NLTDEPLOY_ROOT 并移除 rc 中的 PATH 片段（需确认；非 TTY 设 NLTDEPLOY_UNINSTALL_YES=1）
```

**远程一行（管道无 TTY，必须显式子命令）：**

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/install.sh | bash -s -- install
# 国内（Gitee raw，脚本内容与 GitHub 相同）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/install.sh | bash -s -- install
# 与 install 等价
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/install.sh | bash -s -- update
```

（GitHub raw 使用 **`HEAD`** 指向仓库默认分支最新提交；在部分网络环境下，路径中写 **`master`** 可能短期命中过期缓存，导致与已克隆仓库不一致。）

管道执行时 **仅下载 `install.sh`**，脚本会在本机 **`git clone` 完整仓库** 到 **`${NLTDEPLOY_ROOT}/src/nltdeploy`**（默认即 `~/.local/nltdeploy/src/nltdeploy`），再从中同步 `scripts/` 到 `libexec`。克隆顺序：**优先 GitHub** `farfarfun/nltdeploy`，失败则 **Gitee** 同名仓库。需要已安装 **`git`**。

**每次执行**（`install` 与 `update` 相同）：只要 `scripts/` 所在仓库根目录存在 **`.git`**，会先执行 **`git pull --ff-only`**，再覆盖复制到 `libexec` 并重新生成 `bin` 包装。若不想访问远端（离线重装），可设置 **`NLTDEPLOY_SKIP_GIT_PULL=1`**。

可选覆盖克隆地址（fork 或镜像）：

- **`NLTDEPLOY_GITHUB_REPO`**：默认 `https://github.com/farfarfun/nltdeploy.git`
- **`NLTDEPLOY_GITEE_REPO`**：默认 `https://gitee.com/farfarfun/nltdeploy.git`
- **`NLTDEPLOY_SRC_DIR`**：克隆目标目录（默认 `${NLTDEPLOY_ROOT}/src/nltdeploy`）

**配置 PATH：** `install.sh` 结束时会向 **`~/.zshrc` / `~/.bashrc`**（按当前 `SHELL` 与已有文件选择，bash 且无 `.bashrc` 时可能写入 **`~/.bash_profile`**）**自动追加**一段带标记的 `export PATH="…/bin:${PATH}"`。**写入前会校验**：若该文件里已有 nltdeploy 标记块，或正文中已出现同一 bin 目录路径，则**跳过**，避免重复。安装脚本还会把 **`bin` 加入当前 install 进程**的 `PATH`；若检测到**由 zsh 启动**且为**交互 TTY**，默认会 **`exec zsh -l`**，相当于重新进入登录 zsh 并加载 `~/.zshrc`（`exit` 可回到上一层 shell）。不需要该行为时设 **`NLTDEPLOY_AUTO_EXEC_ZSH_AFTER_INSTALL=0`**，再手动 `source ~/.zshrc` 即可。

若需自行配置，等价写法为：

```bash
export PATH="$HOME/.local/nltdeploy/bin:$PATH"
```

可选环境变量：

- **`NLTDEPLOY_ROOT`**：安装根目录（默认 `~/.local/nltdeploy`）。
- **`NLTDEPLOY_SKIP_PROFILE_HINT=1`**：不自动写入 shell 配置、不打印 PATH 说明、也不做安装结束后的 `exec zsh`（适合 CI；`tests/install_smoke.sh` 已默认设置）。
- **`NLTDEPLOY_AUTO_EXEC_ZSH_AFTER_INSTALL=0`**：关闭安装结束时的 `exec zsh -l`（仍会把 `bin` 加入当前 install 进程的 `PATH`，并提示手动 `source`）。
- **`NLTDEPLOY_UNINSTALL_YES=1`**：`install.sh uninstall` 在非 TTY 下跳过确认（与删除 `NLTDEPLOY_ROOT` 配合使用）。
- **`NLTDEPLOY_SKIP_GIT_PULL=1`**：不执行 `git pull`，仍按当前工作区/已克隆内容同步 `libexec` 与 `bin`。
- **`NLTDEPLOY_GIT_CLONE_REF`**：（可选）管道安装时 `git clone` 使用的分支或 tag。若 raw 地址使用 **`master`** 而仓库默认分支是 **`main`**，请同时设 `NLTDEPLOY_GIT_CLONE_REF=master`，或改用 raw 的 **`HEAD`**（与默认分支一致）。`install.sh` 内复制路径已对旧版 `scripts/_lib`、扁平目录与 `tools/` / `services/` 布局做兼容。
- **`NLTDEPLOY_GITHUB_REPO` / `NLTDEPLOY_GITEE_REPO` / `NLTDEPLOY_SRC_DIR`**：管道安装时的克隆源与目录（见上节）。

本地验证安装逻辑：

```bash
bash tests/install_smoke.sh
```

### 命令对照表（安装后的 `bin` 与 `scripts/`）

| 安装后的命令 | 对应原 scripts 用法 |
|-------------|---------------------|
| `nlt-pip-sources` | `scripts/tools/pip-sources/setup.sh`（无参时 gum 选 install/update/reinstall/uninstall） |
| `nlt-python-env` | `scripts/tools/python-env/setup.sh`（无参时 gum 选子命令；见脚本头） |
| `nlt-airflow` | `scripts/services/airflow/setup.sh` 全量子命令；`install` 首次/升级安装；`start` / `stop` / `status` / `update` 等；无参为 gum 菜单 |
| `nlt-celery` | `scripts/services/celery/setup.sh` 全量子命令；`install` / `update`；`start-worker` / `stop` / `status` 等；无参为菜单 |
| `nlt-utils`（可接子参数，如 `gum`、`all`） | `scripts/tools/utils/setup.sh` … |
| `nlt-github-net` | `scripts/tools/github-net/setup.sh`（无参 gum；可 `install` / `update` / `reinstall` / `uninstall`） |
| `nlt-port-kill` | `scripts/tools/port-kill/setup.sh`（`kill` / `list`；可 `source … --lib` 调用 `nlt_kill_port`；无参 gum；`NONINTERACTIVE=1` 跳过确认） |
| `nlt-services` | `scripts/services/nlt-services.sh`（无参 gum；`status`；`install` 先选安装或卸载；非交互：`install add <模块>` / `install remove <模块>`；`status --no-http`） |
| `nlt-paperclip` | `scripts/services/paperclip/setup.sh` 全量子命令；`install` / `onboard` / `start` 等；无参为 gum 菜单 |
| `nlt-code-server` | `scripts/services/code-server/setup.sh` 全量子命令；`install`（下载解压官方包）等；无参为 gum 菜单 |
| `nlt-new-api` | `scripts/services/new-api/setup.sh` 全量子命令；`install` / `update` 下载 Release 二进制；无参为 gum 菜单 |

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
├── scripts/
│   ├── lib/
│   │   └── nlt-common.sh               # _nlt_ensure_gum 等公共片段（各 setup 脚本 source）
│   ├── tools/                          # 工具 / 环境类（非长期服务进程）
│   │   ├── pip-sources/
│   │   │   ├── setup.sh
│   │   │   └── README.md
│   │   ├── python-env/
│   │   │   ├── setup.sh
│   │   │   └── README.md
│   │   ├── utils/
│   │   │   └── setup.sh                # gum / 别名 / all
│   │   ├── github-net/
│   │   │   └── setup.sh                # Git 连通性诊断与修复
│   │   └── port-kill/
│   │       └── setup.sh                # 按端口查杀进程（可 source 复用）
│   └── services/                       # 常驻服务与聚合入口
│       ├── nlt-services.sh             # nlt-services：status + install 聚合入口
│       ├── airflow/
│       │   └── setup.sh                # Airflow 3 本机 setup（见脚本头注释与用法）
│       ├── celery/
│       │   └── setup.sh
│       ├── paperclip/
│       │   └── setup.sh                # Paperclip 源码克隆与 pnpm 服务启停
│       ├── code-server/
│       │   └── setup.sh                # code-server 官方包下载与启停
│       └── new-api/
│           └── setup.sh                # new-api Release 二进制与启停
```

**`scripts/tools/`** 放 pip、Python 环境、gum/别名、GitHub 网络、端口查杀等 **工具向** 脚本；**`scripts/services/`** 放 Airflow、Celery、Paperclip、code-server、new-api 等 **服务向** 脚本及 **`nlt-services.sh`** 聚合入口。建议先跑 tools 再按需装 services；除 pip-sources / python-env 外可按需独立执行。

## 快速开始

### 1. 配置 pip 源（建议最先执行）

```bash
cd scripts/tools/pip-sources
./setup.sh
```

远程一行（交互）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/pip-sources/setup.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/pip-sources/setup.sh | bash
```

非交互：

```bash
NONINTERACTIVE=1 curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/pip-sources/setup.sh | bash
# 国内（Gitee）
NONINTERACTIVE=1 curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/pip-sources/setup.sh | bash
```

### 2. 创建 Python 环境（uv）

```bash
cd scripts/tools/python-env
./setup.sh
```

远程一行：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/python-env/setup.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/python-env/setup.sh | bash
```

指定版本、额外包（跳过部分交互）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/python-env/setup.sh | bash -s -- -v 3.12 -p requests -p flask
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/python-env/setup.sh | bash -s -- -v 3.12 -p requests -p flask
```

### 3. 常用 CLI（gum，Airflow/GitHub 脚本会用到）

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/utils/setup.sh | bash -s -- gum
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/utils/setup.sh | bash -s -- all
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/utils/setup.sh | bash -s -- gum
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/utils/setup.sh | bash -s -- all
```

### 4. Apache Airflow 3.x（本机）

```bash
cd scripts/services/airflow
chmod +x setup.sh
./setup.sh              # 无参数时进入 gum 菜单；子命令见脚本头部注释
```

远程一行（仅示例，按需加子命令）：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/services/airflow/setup.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/services/airflow/setup.sh | bash
```

默认约定：`AIRFLOW_HOME=~/opt/airflow`，Web 端口等与脚本内 `DEFAULT_*` 一致；更多环境变量与 `http-trigger` 说明见 **`scripts/services/airflow/setup.sh` 文件头注释**。

### 5. Celery（本机）

```bash
cd scripts/services/celery
chmod +x setup.sh
./setup.sh
```

默认 `CELERY_HOME=~/opt/celery`，Broker 等可通过环境变量覆盖，详见脚本头部。

### 6. 修复 GitHub 克隆网络

```bash
cd scripts/tools/github-net
chmod +x setup.sh
./setup.sh
```

或：

```bash
curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD/scripts/tools/github-net/setup.sh | bash
# 国内（Gitee）
curl -LsSf https://gitee.com/farfarfun/nltdeploy/raw/master/scripts/tools/github-net/setup.sh | bash
```

（建议本机已具备 `gum` 或先执行 **utils**。）

## 脚本说明摘要

| 目录 | 入口文件 | 作用 |
|------|-----------|------|
| `tools/pip-sources` | `setup.sh` | 镜像测速、写入 pip 配置、备份 |
| `tools/python-env` | `setup.sh` | uv、多版本 Python venv、基础包 |
| `tools/utils` | `setup.sh` | gum 与 shell 便利项 |
| `tools/github-net` | `setup.sh` | GitHub 克隆通道诊断与修复 |
| `services/airflow` | `setup.sh` | Airflow 3 安装与日常运维封装 |
| `services/celery` | `setup.sh` | Celery 安装与进程管理 |
| `services/paperclip` | `setup.sh` | 克隆 [paperclipai/paperclip](https://github.com/paperclipai/paperclip)、pnpm 安装与启停 |
| `services/code-server` | `setup.sh` | 下载 [coder/code-server](https://github.com/coder/code-server) standalone 包并启停 |
| `services/new-api` | `setup.sh` | 下载 [QuantumNous/new-api](https://github.com/QuantumNous/new-api) Release 二进制并启停 |
| `services/`（根） | `nlt-services.sh` | **`nlt-services`**：`status`；`install` 安装/卸载分流与各 `nlt-*` 对接 |

子目录中的详细说明：

- [pip 源配置](scripts/tools/pip-sources/README.md)
- [Python 环境创建](scripts/tools/python-env/README.md)

## 使用建议

1. 首次：**pip-sources** → **python-env**；若要用 Airflow / GitHub 诊断交互界面，可先 **utils**（装 gum）。
2. 网络或镜像变化时可重跑 **pip-sources**。
3. **airflow** 仅面向 Airflow **3.x**，与 2.x 不混用。

## 通过 curl 执行时的公共约定

- **`NONINTERACTIVE=1`**：两个主 deploy 脚本均支持，用于无 TTY 时跳过确认（见各脚本说明）。
- **Fork 或自建 raw 地址**：部分脚本（如 pip-sources、python-env、airflow）会读取 **`NLTDEPLOY_RAW_BASE`**（若未设置则回退到 **`nltdeploy_RAW_BASE`**），默认 `https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD`，用于拉取同仓库下的 `scripts/tools/utils/setup.sh` 等。国内可设为 Gitee：`export NLTDEPLOY_RAW_BASE=https://gitee.com/farfarfun/nltdeploy/raw/master`。Fork 后可 `export NLTDEPLOY_RAW_BASE=https://raw.githubusercontent.com/<org>/<repo>/<branch>`。仍支持仅设置 `nltdeploy_RAW_BASE` 的旧写法。

## 环境变量（跨脚本常见）

- **`NONINTERACTIVE=1`**：非交互。
- **`NLTDEPLOY_RAW_BASE`**：覆盖拉取本仓库 raw 脚本的根 URL（优先于 `nltdeploy_RAW_BASE`）。见上一节「通过 curl 执行时的公共约定」。
- **`utils`** 另有 `GUM_HOME`、`GUM_TAG`、`GUM_USE_BREW`、`SKIP_GUM_SHELL_PROFILE`、`SKIP_UTILS_SHELL_ALIASES` 等，见 `scripts/tools/utils/setup.sh` 头部。

各专项脚本（Airflow、Celery、GitHub、Paperclip、code-server、new-api）的专有变量以各自文件头注释为准。

## 前置要求

- **网络**：测速、装包、拉取安装脚本均需联网。
- **系统**：macOS、Linux（Windows 建议 WSL）。
- **Shell**：Bash 3.2+；**`curl`** 通常必需。
- **`python-env`** 会在需要时安装 **uv**，无需事先安装。
- **Paperclip**：需要 **Node.js 20+**；脚本会尝试用 **corepack** 准备 **pnpm 9+**（见 `scripts/services/paperclip/setup.sh`）。
- **code-server**：需要 **`curl`** 与 **`tar`**；安装与运行 **不依赖** 本机 Node（见 `scripts/services/code-server/setup.sh`）。
- **new-api**：需要 **`curl`**；自动选版依赖 **`python3`**（若无则使用脚本内 fallback 版本号）。详见 `scripts/services/new-api/setup.sh` 与 [官方文档](https://docs.newapi.pro/)。

## 故障排除

### 脚本没有执行权限

```bash
chmod +x install.sh
chmod +x scripts/tools/pip-sources/setup.sh
chmod +x scripts/tools/python-env/setup.sh
chmod +x scripts/services/airflow/setup.sh
chmod +x scripts/services/celery/setup.sh
chmod +x scripts/tools/utils/setup.sh
chmod +x scripts/tools/github-net/setup.sh
chmod +x scripts/services/paperclip/setup.sh
chmod +x scripts/services/code-server/setup.sh
chmod +x scripts/services/new-api/setup.sh
chmod +x scripts/services/nlt-services.sh
```

### 网络与代理

检查防火墙与代理；企业网络可优先跑 **github-net** 或 **pip-sources** 选对镜像。

### 分脚本详细排错

- [pip 源脚本说明 / 故障排除](scripts/tools/pip-sources/README.md)
- [Python 环境脚本说明 / 故障排除](scripts/tools/python-env/README.md)

### 本地检验「管道执行」

不经过 GitHub 时可把脚本通过 stdin 交给 bash，便于本地改完再测：

```bash
bash < scripts/tools/pip-sources/setup.sh
bash < scripts/tools/python-env/setup.sh
```

## 命名规范

- **`scripts/tools/`**：工具与环境类脚本；**`scripts/services/`**：常驻服务与 **`nlt-services.sh`** 聚合入口。
- 各子模块目录使用 **语义化英文名**（如 `pip-sources`、`airflow`），主入口统一为 **`setup.sh`**（`services` 根下的聚合脚本为 **`nlt-services.sh`**，安装后由 `nlt-services` 调用）。

## 相关链接

- [uv](https://github.com/astral-sh/uv)
- [Python venv](https://docs.python.org/3/tutorial/venv.html)
- [pip 配置](https://pip.pypa.io/en/stable/topics/configuration/)
- [Apache Airflow 文档](https://airflow.apache.org/docs/apache-airflow/stable/)
- [Celery 文档](https://docs.celeryq.dev/)

## 许可证

[MIT License](LICENSE)

Copyright (c) 2026 farfarfun
