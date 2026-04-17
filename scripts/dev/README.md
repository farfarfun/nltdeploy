# 开发工具统一入口（`scripts/dev`）

本目录是 **nltdeploy 推荐的开发环境入口**：pip / Python（uv）与多语言工具链的安装、升级说明与脚本集中在此，避免在对外文档中把 `nlt-pip-sources`、`nlt-python-env` 作为主叙事路径（二者仍会通过 `install.sh` 生成兼容命令，详见下文迁移）。

## 推荐用法（已安装到 PATH）

一键安装仓库脚本后，优先使用：

```bash
nlt-dev              # 有 gum 时弹出菜单；否则打印用法
nlt-dev pip          # 委派到 pip 源 / 镜像配置（原 pip-sources）
nlt-dev python       # 委派到 uv + Python 虚拟环境（原 python-env）
nlt-dev go           # 官方 tarball 安装到 GO_INSTALL_ROOT（默认 ~/opt/go）
nlt-dev rust         # rustup 非交互安装 / 升级 stable
nlt-dev nodejs       # Node.js 官方预编译包到 NODE_INSTALL_ROOT（默认 ~/opt/node）
nlt-dev pnpm         # 在已有 Node 前提下用 corepack 启用 pnpm（可改 PNPM_USE_NPM_GLOBAL）
```

各子目录 `*/setup.sh` 也可单独执行（与仓库内其它 `setup.sh` 约定一致）。

## 环境变量速查

| 变量 | 用途 | 默认 |
|------|------|------|
| `GO_INSTALL_ROOT` | Go 解压目标（GOROOT） | `~/opt/go` |
| `GO_VERSION` | 强制版本，如 `go1.22.4`；不设则从 go.dev 读取 | 自动 |
| `RUSTUP_HOME` / `CARGO_HOME` | rustup 数据目录 | rustup 默认 |
| `NODE_VERSION` | Node 版本号，如 `22.14.0` | `22.14.0` |
| `NODE_INSTALL_ROOT` | Node 安装根（内含 `bin/node`） | `~/opt/node` |
| `PNPM_USE_NPM_GLOBAL` | 设为 `1` 时用 `npm install -g pnpm` 代替 corepack | 未设 |

## 迁移说明（董事会 / 文档作者）

- **以前**：文档主路径常写「先装 `nlt-pip-sources` 再装 `nlt-python-env`」。
- **现在**：对外叙事改为「使用 **`nlt-dev`** 选择 pip / python，或运行 `nlt-dev pip` / `nlt-dev python`」；行为与原先两个命令一致（同一套 `libexec` 脚本）。
- **兼容**：`install.sh` 仍会安装 `nlt-pip-sources` 与 `nlt-python-env`，旧脚本与 CI 无需立即修改；新内容请以 `nlt-dev` 为准。

## 相关文档

- [pip-sources 说明](../tools/pip-sources/README.md)
- [python-env 说明](../tools/python-env/README.md)
