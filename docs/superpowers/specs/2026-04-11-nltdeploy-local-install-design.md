# nltdeploy：本地安装布局与命令规范（设计规格）

**日期：** 2026-04-11  
**状态：** 已确认（用户书面确认）  
**范围：** 一键安装到 `~/.local/nltdeploy`，`bin` 下暴露统一前缀命令；服务生命周期与工具/配置类命令的命名分界。

**工具/服务子命令、gum 交互与必选动词：** 见 [工具与服务命令规范](2026-04-11-nltdeploy-tool-service-conventions.md)。

---

## 1. 目标与成功标准

- **一键安装**：单入口脚本（可 `curl | bash`，也可 clone 后本地执行）完成目录创建、文件同步、`bin` 下命令就绪，并提示配置 `PATH`。
- **统一安装根**：运行时工具箱根目录为 **`~/.local/nltdeploy`**（可通过环境变量覆盖，见第 6 节）。
- **PATH 仅暴露 `nlt-*`**：用户可执行文件全部以 `nlt-` 开头；其中 **服务启停类** 以 **`nlt-service-`** 开头。
- **实现与入口分离**：真实逻辑放在 **`libexec/nltdeploy/`**，`bin` 仅为薄包装，便于升级与测试。

成功标准：安装后在不进入仓库目录的情况下，仅依赖 `PATH` 即可调用文档中列出的命令；现有 `scripts/` 行为可通过迁移表逐项对齐或显式废弃。

---

## 2. 架构决策摘要

| 决策 | 选择 | 说明 |
|------|------|------|
| 主形态 | **A：Bash 小命令为主** | 与当前仓库以 shell 为主力一致；Python 包不作为终端主入口（可后续作为可选依赖，本规格不强制）。 |
| 命令前缀 | **`nlt-`** | 所有 `bin` 内可执行文件名均以此开头。 |
| 服务类前缀 | **`nlt-service-`** | 长期运行服务的 start/stop/restart/status 等归属此族。 |
| Airflow「首次安装」 | **`nlt-airflow-install`（非 service）** | 与「装环境」一致归为工具/安装类；装好后日常运维用 `nlt-service-airflow-*`。 |
| 数据与运行时目录 | **默认保持现有 `~/opt/...` 约定** | 与 README 及现有脚本一致，降低迁移成本；若设置 `AIRFLOW_HOME` / `CELERY_HOME` 等，仍以用户环境为准。后续可在实现阶段增加可选「统一到 `~/.local/nltdeploy/var`」的迁移助手，**不作为本规格 v1 默认行为**。 |

---

## 3. 目录布局

```
~/.local/nltdeploy/
├── bin/                          # 唯一加入 PATH 的目录（用户可见命令）
├── libexec/nltdeploy/            # 实现脚本与内部模块（不在 PATH）
├── share/nltdeploy/              # 静态资源（模板、片段等，可选）
└── etc/nltdeploy/                # 用户级配置覆盖（可选）
```

- **`bin/`**：仅包含名称以 `nlt-` 开头的文件（含 `nlt-service-*`）。
- **`libexec/nltdeploy/`**：可按域分子目录（例如 `pip/`、`python-env/`、`airflow/`、`celery/`），具体结构由实现计划定义；规格要求 **不将 `libexec` 加入 PATH**。

---

## 4. 命名规范

### 4.1 总则

- 小写，词段之间 **单连字符 `-`**。
- 每个 `bin` 文件名：**必须以 `nlt-` 开头**。

### 4.2 非服务（工具、环境、一次性配置、首次安装）

- 模式：`nlt-<领域>-<动作>`（动作可省略若唯一明确）。
- 与现有脚本模块的 **目标映射**（实现时可微调动词，但需在 README 迁移表中列出）：

| 现有入口 | 目标命令（示例） |
|----------|------------------|
| `01-configure-pip-sources/deploy.sh` | `nlt-pip-sources` |
| `02-create-python-env/deploy.sh` | `nlt-python-env` |
| `05-utils/utils-setup.sh` | `nlt-utils` 或拆分为 `nlt-utils-gum` 等 |
| `06-github/deploy.sh` | `nlt-github-net` |
| Airflow 首次安装/升级（原 `03-airflow/deploy.sh` 中非启停部分） | `nlt-airflow-install` |

### 4.3 服务（进程生命周期）

- 模式：`nlt-service-<服务或角色>-<动作>`。
- 动作建议统一为：`start` | `stop` | `restart` | `status`（若某服务需要额外动作，在实现计划中单独列出）。
- 示例：
  - `nlt-service-airflow-start` / `stop` / `restart` / `status`
  - `nlt-service-celery-worker-start` / `stop` / …（beat、flower 等同理，用不同 `<服务或角色>` 段区分）

---

## 5. 薄包装与环境变量

### 5.1 薄包装行为

每个 `bin` 下命令：

1. 若未设置，则默认 `NLTDEPLOY_ROOT="$HOME/.local/nltdeploy"`。
2. `exec "$NLTDEPLOY_ROOT/libexec/nltdeploy/…" "$@"`（具体相对路径由实现定义）。

### 5.2 与现有脚本兼容的环境变量

- 保留 **`NONINTERACTIVE=1`** 语义（各实现脚本继续支持）。
- **`nltdeploy_RAW_BASE`**：保留支持；规格推荐在文档与实现中增加 **`NLTDEPLOY_RAW_BASE`** 作为等价或优先别名，并在 README 中说明迁移（旧名可 deprecate 一至两个版本周期，由实现计划定）。

---

## 6. 一键安装脚本（入口）

- **职责**：创建 `~/.local/nltdeploy` 下目录结构；将 `libexec/nltdeploy` 内容从发布包或 git 检出位置同步到目标根；生成或更新 `bin` 下全部薄包装；可选：检测并打印 `PATH` 配置提示。
- **`install.sh [install|update]`**：`install`（默认）与 **`update` 等价**——在同步 `libexec` 与 `bin` 之前，若 `scripts/` 所在目录为 **git 仓库**，则执行 **`git pull --ff-only`**；可用 **`NLTDEPLOY_SKIP_GIT_PULL=1`** 跳过拉取（仅同步本地已有文件）。
- **`curl …/install.sh | bash`**：无法解析到与 `install.sh` 同目录的 `scripts/` 时，在 **`${NLTDEPLOY_ROOT}/src/nltdeploy`**（可用 `NLTDEPLOY_SRC_DIR` 覆盖）执行 **`git clone`**：**优先 GitHub** `farfarfun/nltdeploy`，失败则 **Gitee** 同名；已存在 `.git` 时同样先 **`git pull --ff-only`** 再同步。需本机已安装 **`git`**。克隆 URL 可通过 `NLTDEPLOY_GITHUB_REPO` / `NLTDEPLOY_GITEE_REPO` 覆盖（fork/镜像）。管道可传参：`bash -s -- update`。
- **不要求**：默认修改用户 shell 配置文件（可交互询问或文档说明手动 `export PATH`）。安装结束打印 PATH 提示的行为可通过 **`NLTDEPLOY_SKIP_PROFILE_HINT=1`** 关闭（与当前 `install.sh` 一致）。若将来增加「自动写入 profile」，再引入单独开关（例如 `NLTDEPLOY_SKIP_PROFILE=1`）关闭该行为。

---

## 7. 与 Python 包（`pyproject.toml`）的关系

- 当前仓库存在 **包目录名与入口模块名不一致**（`fundeploy` vs `nltdeploy`）等技术债；**本规格 v1 以 shell 安装路径为准**。
- 实现阶段建议：**要么**将 Python 包与 `nlt-*` 命令对齐并修复入口，**要么**在 v1 中明确「CLI 以 `nlt-*` 为主、PyPI 包为可选」，避免两套并列入口未文档化。

---

## 8. 测试与验收（规格层）

- 安装脚本在 **macOS 与 Linux**（含无 TTY 的 `NONINTERACTIVE`）下可完成安装。
- 抽样验收：`nlt-pip-sources`、`nlt-python-env`、`nlt-airflow-install`、`nlt-service-airflow-status`（在未安装服务时可有明确退出码与提示）等按迁移表可调用。

---

## 9. 后续工作（流程）

1. 用户审阅本规格文件定稿。
2. 使用 **writing-plans** 技能生成实现计划（分阶段：目录与安装脚本、`libexec` 迁移、`bin` 生成、文档与兼容变量、Python 包对齐可选任务）。

---

## 规格自检记录

- **占位符**：无 TBD；数据目录默认策略已写死为保留 `~/opt` 与既有 env。
- **一致性**：服务类仅 `nlt-service-*`；Airflow 安装单独 `nlt-airflow-install`，与上文表格一致。
- **范围**：本文件仅定义布局与命名；不展开具体 systemd/launchd 或进程管理实现细节（归入实现计划）。
