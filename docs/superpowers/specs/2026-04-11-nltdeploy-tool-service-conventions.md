# nltdeploy：工具与服务命令规范

**日期：** 2026-04-11  
**状态：** 规范（后续改造与新增模块的实施依据）  
**关联：** [本地安装与 `nlt-*` 命名](2026-04-11-nltdeploy-local-install-design.md)

---

## 1. 术语

| 术语 | 含义 |
|------|------|
| **工具（Tool）** | 不长期以守护进程形式对外提供服务的组件：如 pip 源配置、Python 环境脚手架、gum 本体安装、GitHub 网络诊断等。可多次执行、无统一「进程 PID」概念。 |
| **服务（Service）** | 安装后通常以进程形式运行、需要生命周期管理（启停、状态）的组件：如 Airflow、Celery（worker/beat/flower）等。可有数据目录、日志、端口。 |

同一业务域可以 **同时** 暴露工具子命令与服务子命令（例如 Airflow：`install` 属安装类，`start` 属服务类），在 **一个 libexec 主入口脚本** 内用子命令分发（推荐），而不是拆成多个互不关联的脚本。

---

## 2. 子命令分层：必选与扩展

### 2.1 服务（Service）— 必选子命令

每个服务域的主入口 **必须** 实现下列子命令（名称固定为英文小写，与 `nlt-*` 包装传入的第一个参数一致）：

| 子命令 | 职责 |
|--------|------|
| `install` | 首次或干净环境下的安装：目录、依赖、数据库迁移（若适用）等。 |
| `update` | 在保留数据与配置的前提下升级运行时/依赖；不得默认抹掉用户数据。 |
| `start` | 启动服务（或该域定义的主进程）；需幂等或可检测「已在运行」。 |
| `stop` | 停止服务。 |
| `restart` | 等价于 `stop` 再 `start`（可实现为函数组合）。 |

**必选之外**：可继续增加域专属子命令（如 `status`、`dag-scaffold`、`http-trigger` 等），须在 README 与该域脚本头部的 `usage` 中列出。

### 2.2 工具（Tool）— 必选子命令

每个工具域的主入口 **必须** 实现：

| 子命令 | 职责 |
|--------|------|
| `install` | 安装或应用配置到本机约定路径。 |
| `update` | 在保留用户可配置部分的前提下更新组件版本或配置逻辑。 |
| `reinstall` | 强制按「安装流程」重做一遍（可清理可再生的缓存/中间产物；破坏性操作须在交互或 `NONINTERACTIVE` 规则下确认）。 |
| `uninstall` | 移除本工具安装的内容；不可逆步骤须符合下文确认策略。 |

工具 **无** 强制的 `start`/`stop`（除非该工具本身也是长期进程，此时应归类为服务或拆出服务子域）。

---

## 3. 命令行形态：交互与直执行

### 3.1 统一规则

- **无参数**（或仅 `--help` / `help`）：进入 **gum 驱动的交互**（菜单或分步引导），展示可选子命令。
- **第一个参数为已知子命令**（如 `install`、`update`、`start`、`stop`、`restart`、`status`、`uninstall` 等）：**跳过 gum 主菜单**，直接执行对应逻辑；后续参数原样传递给该子命令处理函数。
- **`NONINTERACTIVE=1`**：禁止阻塞式交互；缺参时的默认行为由各域文档写明（例如失败退出或使用安全默认值）。

### 3.2 与 `bin` 命名的关系（不破坏现有安装）

- **推荐**：每个域一个 **总控入口**（如 `nlt-airflow` → `airflow/deploy.sh "$@"`），所有子命令通过参数触发直执行或 gum 菜单。
- **服务族命名**：每个长期运行域对应 **一个** **`nlt-service-<域>`**，透传子命令（如 `nlt-service-airflow start`），**不再**为每个动词单独生成 `nlt-service-<域>-<动词>` 文件。
- **新增服务/工具**：优先 **总控** `nlt-<域>` 与 **`nlt-service-<域>`**（二者可指向同一 libexec 脚本）；安装类入口仍可用 `nlt-<域>-install`。

---

## 4. gum 使用规范

### 4.1 不单独做「是否已安装 gum」的预校验分支

- **禁止** 先写一段「检测 gum → 若不存在则打印错误退出」再让用户手动安装。
- **必须** 在需要 gum **之前** 调用统一的 **`_nlt_ensure_gum`**（名称可一致化；实现见下条），由该函数负责保证 `gum` 可用。

### 4.2 `_nlt_ensure_gum` 行为约定

1. **若已可用**：`command -v gum` 成功，或约定路径下已有可执行文件（与现有 `~/opt/gum/bin` 策略一致），则 **立即返回 0**，不得重复下载或重复安装。
2. **若不可用**：调用与本仓库一致的 gum 安装方式（例如通过 `NLTDEPLOY_RAW_BASE` / `nltdeploy_RAW_BASE` 拉取 `utils-setup.sh` 并执行 `bash -s -- gum`，或 libexec 内已复制的 `utils-setup.sh`），执行后再次保证 `PATH` 含 gum。
3. **gum 安装过程本身** 不使用 gum 做交互（与用户要求「gum 安装除外」一致）；该过程可使用 `NONINTERACTIVE`、环境变量或自带的最小提示。

### 4.3 交互范围

- **除 gum 安装路径外**，凡面向用户的 **选择、确认、表单、列表菜单** 应优先使用 **gum**（`gum choose` / `gum confirm` / `gum input` 等）。
- 当用户已通过 **子命令参数** 指明动作时，对应路径上 **不得** 再弹出 gum 菜单选择「你要做什么」；仍可在 **破坏性操作** 上使用 `gum confirm`，除非 `NONINTERACTIVE=1`（此时按各域写明的策略跳过或失败）。

---

## 5. 实现结构建议（libexec / scripts）

- 每个域一个主脚本（如 `airflow/deploy.sh`），内部结构建议为：
  - `usage` / `help`
  - `_nlt_ensure_gum`（或 `source` 公共片段）
  - `cmd_install` / `cmd_update` / `cmd_start` …
  - `main "$@"`：`case`/`if` 分发子命令
- **公共逻辑**：`_nlt_ensure_gum` 已落在仓库 **`scripts/_lib/nlt-common.sh`**（安装后同步到 `libexec/nltdeploy/_lib/`），各域脚本 `source` 该文件；统一样式输出仍可按域保留（如 `gum style`）。

---

## 6. 验收清单（新增或重构某一域时）

- [ ] 服务：已实现 `install` / `update` / `start` / `stop` / `restart`；文档列出扩展子命令。  
- [ ] 工具：已实现 `install` / `update` / `reinstall` / `uninstall`。  
- [ ] 无参数走 gum 交互；带首参子命令时直执行，不经过主菜单。  
- [ ] 需要 gum 前调用 `_nlt_ensure_gum`，且 gum 已安装时 O(1) 跳过。  
- [ ] `NONINTERACTIVE=1` 行为在脚本头注释中说明。  
- [ ] `install.sh` 与 README 中的 `nlt-*` / `nlt-service-*` 对照表已更新（若新增包装）。

---

## 7. 与现状的差异（迁移说明）

已实现（持续迭代中）：Airflow 增加 **`update`** 并统一 **`_nlt_ensure_gum`**；Celery 增加 **`update`**、无参 **gum** 菜单及 **`NONINTERACTIVE`** 下的 restart 行为；pip / Python 环境 / GitHub 网络工具补齐 **install / update / reinstall / uninstall** 形态与无参 gum 入口（`05-utils` 仍以安装 gum 为主，未强制四字命令）。若某域仍有 read 交互，可逐步改为 gum。

---

## 8. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-04-11 | 首版：工具/服务必选子命令、gum 策略、参数直执行与 bin 命名关系。 |
| 2026-04-11 | 补充：`scripts/_lib/nlt-common.sh`；Airflow/Celery/GitHub/pip/Python-env 按规范首轮改造说明。 |
