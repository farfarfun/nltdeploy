# 开发工具统一入口（`scripts/dev`）

本目录是 **nltdeploy 推荐的开发环境入口**：pip、**uv 本体**、Python（基于 uv 的虚拟环境）与多语言工具链的安装、升级说明与脚本集中在此，避免在对外文档中把 `nlt-pip-sources`、`nlt-python-env` 作为主叙事路径（二者仍会通过 `install.sh` 生成兼容命令，详见下文迁移）。

**推荐顺序（叙事）**：`nlt-dev pip`（镜像）→ **`nlt-dev uv`**（安装/升级 Astral **uv**）→ `nlt-dev python`（用 uv 建 venv）。仅建环境、不关心单独升级 uv 时，可直接 `nlt-dev python`（内部仍会按需自动安装 uv）。

## 推荐用法（已安装到 PATH）

一键安装仓库脚本后，优先使用：

```bash
nlt-dev              # 有 gum 时弹出菜单；否则打印用法
nlt-dev pip          # 委派到 pip 源 / 镜像配置（原 pip-sources）
nlt-dev uv           # 安装：官方 install.sh；升级：`nlt-dev uv update`（`uv self update`）
nlt-dev python       # 委派到 uv + Python 虚拟环境（原 python-env）
nlt-dev go           # 官方 tarball 安装到 GO_INSTALL_ROOT（默认 ~/opt/go）
nlt-dev rust         # rustup 非交互安装 / 升级 stable
nlt-dev nodejs       # Node.js 官方预编译包到 NODE_INSTALL_ROOT（默认 ~/opt/node）
nlt-dev pnpm         # 在已有 Node 前提下用 corepack 启用 pnpm（可改 PNPM_USE_NPM_GLOBAL）
```

各子目录 `*/setup.sh` 也可单独执行（与仓库内其它 `setup.sh` 约定一致）。

## uv（Astral）

- **脚本入口**：`scripts/dev/uv/setup.sh`（安装后等价于 `nlt-dev uv …`，**不**再增加单独的 `nlt-uv` 对外命令，避免零散别名）。
- **安装**：`nlt-dev uv` 或 `nlt-dev uv install` — 管道执行官方 `https://astral.sh/uv/install.sh`（可用 `UV_INSTALL_URL` 覆盖镜像/内网副本地址）。
- **升级**：`nlt-dev uv update` — 若 PATH 中已有 `uv`，执行 **`uv self update`**；否则再次走官方安装脚本。
- **与 python-env**：`python-env/setup.sh` 在创建环境前仍会 **按需自动** `curl … | sh` 安装 uv；若希望文档与操作路径统一，董事会对外材料请写「通过 **`nlt-dev uv`** 显式安装/升级」，再写 `nlt-dev python`。

## 环境变量速查

| 变量 | 用途 | 默认 |
|------|------|------|
| `UV_INSTALL_DIR` | 官方安装器：二进制安装目录 | 由官方脚本决定（常见 `~/.local/bin`） |
| `INSTALLER_NO_MODIFY_PATH` | 设为 `1` 时安装器不自动改 shell 配置 | 未设 |
| `UV_INSTALL_URL` | 覆盖 uv 安装脚本 URL | `https://astral.sh/uv/install.sh` |
| `GO_INSTALL_ROOT` | Go 解压目标（GOROOT） | `~/opt/go` |
| `GO_VERSION` | 强制版本，如 `go1.22.4`；不设则从 go.dev 读取 | 自动 |
| `RUSTUP_HOME` / `CARGO_HOME` | rustup 数据目录 | rustup 默认 |
| `NODE_VERSION` | Node 版本号，如 `22.14.0` | `22.14.0` |
| `NODE_INSTALL_ROOT` | Node 安装根（内含 `bin/node`） | `~/opt/node` |
| `PNPM_USE_NPM_GLOBAL` | 设为 `1` 时用 `npm install -g pnpm` 代替 corepack | 未设 |

## 迁移说明（董事会 / 文档作者）

- **以前**：文档主路径常写「先装 `nlt-pip-sources` 再装 `nlt-python-env`」。
- **现在**：对外叙事改为「使用 **`nlt-dev`**：`pip` →（建议）**`uv`** → `python`」，或按需只跑其中几步；行为与原先 pip-sources / python-env 一致（同一套 `libexec` 脚本）。
- **兼容**：`install.sh` 仍会安装 `nlt-pip-sources` 与 `nlt-python-env`，旧脚本与 CI 无需立即修改；新内容请以 `nlt-dev` 为准。

## 相关文档

- [pip-sources 说明](../tools/pip-sources/README.md)
- [python-env 说明](../tools/python-env/README.md)
