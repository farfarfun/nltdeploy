# nltdeploy 本地安装与 `nlt-*` 命令 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提供仓库根目录一键 `install.sh`，将 `scripts/` 中的实现同步到 `~/.local/nltdeploy/libexec/nltdeploy/`，并在 `bin/` 生成符合规格的 `nlt-*` / `nlt-service-*` 薄包装；文档与 `NLTDEPLOY_RAW_BASE` 兼容变量同步更新。

**Architecture:** 以 **`scripts/` 为单一源码真相**（不在首版重复维护第二套脚本正文）。安装时按固定映射表 **复制** 到 `libexec`（避免符号链接在打包/部分文件系统上的问题）。`bin` 下全部为两行级薄包装：`NLTDEPLOY_ROOT` + `exec` 到 libexec 目标并附加固定子命令参数。Airflow/Celery 继续沿用现有 `deploy.sh` / `celery-setup.sh` 的子命令接口。

**Tech stack:** Bash 3.2+、`cp`/`mkdir`、`bash -n` 校验；可选 `curl` 用于远程安装入口（文档）。

---

## 文件结构（本计划将创建或修改）

| 路径 | 职责 |
|------|------|
| `install.sh`（仓库根，新建） | 创建 `NLTDEPLOY_ROOT` 目录树；复制 `scripts/*` → `libexec/nltdeploy/...`；生成全部 `bin` 薄包装；打印 `PATH` 提示。 |
| `scripts/01-configure-pip-sources/deploy.sh`（改） | `_nltdeploy_RAW_BASE` 同时识别 `NLTDEPLOY_RAW_BASE` 与 `nltdeploy_RAW_BASE`。 |
| `scripts/02-create-python-env/deploy.sh`（改） | 同上。 |
| `scripts/03-airflow/deploy.sh`（改） | 同上。 |
| `README.md`（改） | 推荐安装方式、`nlt-*` 与旧 `scripts/` 对照表、`PATH` 与 `NLTDEPLOY_ROOT`、远程 `curl install.sh`。 |
| `tests/install_smoke.sh`（新建） | 将 `NLTDEPLOY_ROOT` 指向临时目录并运行 `install.sh`，断言关键 `bin` 与 libexec 文件存在且 `bash -n` 通过。 |
| `docs/superpowers/specs/2026-04-11-nltdeploy-local-install-design.md` | 只读对照，不修改除非规格勘误。 |

**刻意延后（可选后续 PR）：** 将 `src/fundeploy` 重命名为 `nltdeploy` 并修正 `pyproject.toml` 的 `[project.scripts]` 与 import，使 PyPI/editable 安装与 `nlt-*` 文档一致。本计划 **不** 将其列为阻塞项。

---

### Task 1: `install.sh` 骨架与目录复制映射

**Files:**
- Create: `install.sh`
- Test: `bash -n install.sh`（手工）

- [ ] **Step 1: 编写 `install.sh` 头部与根目录解析**

在仓库根创建 `install.sh`（`chmod +x`）：

```bash
#!/usr/bin/env bash
# 一键安装 nltdeploy 命令到 ~/.local/nltdeploy（可通过 NLTDEPLOY_ROOT 覆盖）。
set -euo pipefail

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
# 安装源：install.sh 所在目录为仓库根（或解压包根）。
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SOURCE_ROOT}/scripts"

die() { echo "错误: $*" >&2; exit 1; }
[[ -d "$SCRIPTS" ]] || die "找不到 ${SCRIPTS}（请在仓库根或完整发布包内运行 install.sh）"
```

- [ ] **Step 2: 创建目标目录并复制 libexec 映射**

在 `install.sh` 中追加（保持 `set -euo pipefail`）：

```bash
LIBEXEC="${NLTDEPLOY_ROOT}/libexec/nltdeploy"
mkdir -p "${NLTDEPLOY_ROOT}/bin" "${LIBEXEC}" \
  "${NLTDEPLOY_ROOT}/share/nltdeploy" "${NLTDEPLOY_ROOT}/etc/nltdeploy"

install -m 0755 -d "${LIBEXEC}/pip-sources" "${LIBEXEC}/python-env" \
  "${LIBEXEC}/airflow" "${LIBEXEC}/celery" "${LIBEXEC}/utils" "${LIBEXEC}/github-net"

cp -f "${SCRIPTS}/01-configure-pip-sources/deploy.sh" "${LIBEXEC}/pip-sources/deploy.sh"
chmod 0755 "${LIBEXEC}/pip-sources/deploy.sh"

cp -f "${SCRIPTS}/02-create-python-env/deploy.sh" "${LIBEXEC}/python-env/deploy.sh"
chmod 0755 "${LIBEXEC}/python-env/deploy.sh"

cp -f "${SCRIPTS}/03-airflow/deploy.sh" "${LIBEXEC}/airflow/deploy.sh"
chmod 0755 "${LIBEXEC}/airflow/deploy.sh"

cp -f "${SCRIPTS}/04-celery/celery-setup.sh" "${LIBEXEC}/celery/celery-setup.sh"
chmod 0755 "${LIBEXEC}/celery/celery-setup.sh"

cp -f "${SCRIPTS}/05-utils/utils-setup.sh" "${LIBEXEC}/utils/utils-setup.sh"
chmod 0755 "${LIBEXEC}/utils/utils-setup.sh"

cp -f "${SCRIPTS}/06-github/deploy.sh" "${LIBEXEC}/github-net/deploy.sh"
chmod 0755 "${LIBEXEC}/github-net/deploy.sh"
```

- [ ] **Step 3: 校验语法**

Run: `bash -n install.sh`  
Expected: 无输出，退出码 0。

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh skeleton and libexec copy mapping"
```

---

### Task 2: 生成 `bin` 薄包装（函数 + 全量命令表）

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: 在 `install.sh` 末尾之前加入 `_emit_wrapper`**

```bash
# 用法: _emit_wrapper <bin相对名> <libexec 内脚本相对路径> [传递给脚本的固定前缀参数...]
_emit_wrapper() {
  local name="$1"
  shift
  local rel="$1"
  shift
  local bin_path="${NLTDEPLOY_ROOT}/bin/${name}"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n' 'NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"'
    if [[ $# -gt 0 ]]; then
      printf 'exec "${NLTDEPLOY_ROOT}/libexec/nltdeploy/%s"' "$rel"
      local a
      for a in "$@"; do
        printf ' %q' "$a"
      done
      printf ' "$@"\n'
    else
      printf 'exec "${NLTDEPLOY_ROOT}/libexec/nltdeploy/%s" "$@"\n' "$rel"
    fi
  } > "${bin_path}"
  chmod 0755 "${bin_path}"
}
```

说明：`%q` 需 Bash 3.2+；固定前缀参数经 `printf %q` 转义，避免空格问题。

- [ ] **Step 2: 写入全部包装调用表**

在 `install.sh` 复制块之后、`_emit_wrapper` 定义之后，执行：

```bash
_emit_wrapper nlt-pip-sources pip-sources/deploy.sh
_emit_wrapper nlt-python-env python-env/deploy.sh
_emit_wrapper nlt-utils utils/utils-setup.sh
_emit_wrapper nlt-github-net github-net/deploy.sh

_emit_wrapper nlt-airflow-install airflow/deploy.sh install
_emit_wrapper nlt-airflow airflow/deploy.sh
_emit_wrapper nlt-service-airflow airflow/deploy.sh

_emit_wrapper nlt-celery-install celery/celery-setup.sh install
_emit_wrapper nlt-service-celery celery/celery-setup.sh
```

- [ ] **Step 3: 安装结束提示 PATH（不默认写 profile）**

```bash
echo ""
echo "已安装到: ${NLTDEPLOY_ROOT}"
echo "请将下列行加入 ~/.bashrc / ~/.zshrc（或当前 shell 配置）："
echo "  export PATH=\"${NLTDEPLOY_ROOT}/bin:\${PATH}\""
if [[ "${NLTDEPLOY_SKIP_PROFILE_HINT:-}" != "1" ]]; then
  echo "若不想看见本提示，可设置 NLTDEPLOY_SKIP_PROFILE_HINT=1"
fi
```

- [ ] **Step 4: `bash -n install.sh`**

Expected: 退出码 0。

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: generate nlt-* and nlt-service-* bin wrappers in install.sh"
```

---

### Task 3: `NLTDEPLOY_RAW_BASE` 与旧变量兼容

**Files:**
- Modify: `scripts/01-configure-pip-sources/deploy.sh`
- Modify: `scripts/02-create-python-env/deploy.sh`
- Modify: `scripts/03-airflow/deploy.sh`

- [ ] **Step 1: 统一 raw base 一行替换**

在上述每个文件中，将：

```bash
_nltdeploy_RAW_BASE="${nltdeploy_RAW_BASE:-https://raw.githubusercontent.com/farfarfun/nltdeploy/master}"
```

替换为：

```bash
_nltdeploy_RAW_BASE="${NLTDEPLOY_RAW_BASE:-${nltdeploy_RAW_BASE:-https://raw.githubusercontent.com/farfarfun/nltdeploy/master}}"
```

（若该行略有不同，以等价语义替换：优先 `NLTDEPLOY_RAW_BASE`，其次 `nltdeploy_RAW_BASE`，最后默认 URL。）

- [ ] **Step 2: 对三个文件分别执行 `bash -n`**

Run:

```bash
bash -n scripts/01-configure-pip-sources/deploy.sh
bash -n scripts/02-create-python-env/deploy.sh
bash -n scripts/03-airflow/deploy.sh
```

Expected: 均为退出码 0。

- [ ] **Step 3: Commit**

```bash
git add scripts/01-configure-pip-sources/deploy.sh \
  scripts/02-create-python-env/deploy.sh \
  scripts/03-airflow/deploy.sh
git commit -m "feat: honor NLTDEPLOY_RAW_BASE with fallback to nltdeploy_RAW_BASE"
```

---

### Task 4: 冒烟测试 `tests/install_smoke.sh`

**Files:**
- Create: `tests/install_smoke.sh`

- [ ] **Step 1: 编写测试脚本**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export NLTDEPLOY_ROOT="${TMP}/nd"
bash "${ROOT}/install.sh"
for f in \
  nlt-pip-sources nlt-python-env nlt-utils nlt-github-net \
  nlt-airflow-install nlt-airflow nlt-service-airflow \
  nlt-celery-install nlt-service-celery
do
  [[ -x "${NLTDEPLOY_ROOT}/bin/${f}" ]] || { echo "missing: bin/${f}" >&2; exit 1; }
  bash -n "${NLTDEPLOY_ROOT}/bin/${f}" || exit 1
done
bash -n "${NLTDEPLOY_ROOT}/libexec/nltdeploy/airflow/deploy.sh" || exit 1
echo "install_smoke OK"
```

- [ ] **Step 2: 运行测试**

Run: `bash tests/install_smoke.sh`  
Expected: 输出 `install_smoke OK`，退出码 0。

- [ ] **Step 3: Commit**

```bash
chmod +x tests/install_smoke.sh
git add tests/install_smoke.sh
git commit -m "test: add install smoke test for bin wrappers and libexec"
```

---

### Task 5: README 迁移与远程安装说明

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 在「快速开始」之前增加「推荐：一键安装到 ~/.local/nltdeploy」小节**

内容要点（需写成完整 Markdown 段落，勿留占位符）：

- clone 后：`chmod +x install.sh && ./install.sh`
- 远程：`curl -LsSf https://raw.githubusercontent.com/farfarfun/nltdeploy/master/install.sh | bash`（及 Gitee 镜像等价行）
- `export PATH="$HOME/.local/nltdeploy/bin:$PATH"`
- `NLTDEPLOY_ROOT` 可覆盖安装目录；`NLTDEPLOY_SKIP_PROFILE_HINT=1` 隐藏 PATH 提示

- [ ] **Step 2: 增加「命令对照表」**

表格列：`新命令（bin）` | `原 scripts 路径与用法` | 备注。

须包含本计划中 `_emit_wrapper` 列出的全部 `nlt-*` / `nlt-service-*` 名称。

- [ ] **Step 3: 在「环境变量」相关小节补充 `NLTDEPLOY_RAW_BASE`**

说明与 `nltdeploy_RAW_BASE` 的优先级（新变量优先）。

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document local install, nlt-* mapping, and NLTDEPLOY_RAW_BASE"
```

---

## 规格自检（计划 ↔ 规格）

| 规格章节 | 对应任务 |
|----------|----------|
| 一键安装 + `bin` 仅 `nlt-*` | Task 1–2 |
| `libexec` 实现分离 | Task 1 |
| `nlt-service-<域>` 单入口透传子命令 | Task 2（Airflow/Celery 等） |
| `nlt-airflow-install` 非 service | Task 2 |
| `NLTDEPLOY_ROOT` 可覆盖 | Task 1–2 薄包装 |
| `NONINTERACTIVE` 保留 | 无需改脚本（沿用现有） |
| `NLTDEPLOY_RAW_BASE` | Task 3 |
| 不默认写 profile | Task 2 PATH 提示 + `NLTDEPLOY_SKIP_PROFILE_HINT` |
| 验收：安装后可调用 | Task 4 |

**占位符扫描：** 本计划正文无 TBD/TODO；README 步骤要求写「完整段落」而非占位。

**一致性：** `_emit_wrapper` 生成的 `exec` 行与规格中命令名一致；`nlt-airflow` 作为 `airflow/deploy.sh` 的全量子命令入口，满足规格未列出的 DAG/用户管理等能力不丢失。

---

## Execution handoff

**计划已保存至：** `docs/superpowers/plans/2026-04-11-nltdeploy-local-install.md`

**两种执行方式：**

1. **Subagent-Driven（推荐）** — 每个 Task 派生子代理，任务间人工快速过一遍。  
2. **Inline Execution** — 本会话按 Task 顺序实现，配合 `executing-plans` 的检查点。

你希望采用哪一种？
