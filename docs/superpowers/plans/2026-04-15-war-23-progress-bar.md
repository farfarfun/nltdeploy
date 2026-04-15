# WAR-23 进度条库实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `scripts/lib/nlt-progress.sh` 实现可 source 的彩色进度条与下载场景辅助函数，满足 macOS/Linux、百分比、已用/剩余时间、速率与字节显示；并入 `install.sh` 同步规则，并补充测试与文档。

**Architecture:** 纯 Bash + `awk` 做浮点；TTY 检测 `[ -t 1 ]`；条形使用 Unicode 块字符或 ASCII `#` 填充；时间用 `date +%s`。下载场景通过轮询输出文件字节数配合已知 `Content-Length` 刷新进度。

**Tech stack:** Bash 3.2+、`awk`、`date`、可选 `curl`（仅示例与测试）。

---

## 文件结构

| 路径 | 职责 |
|------|------|
| `scripts/lib/nlt-progress.sh`（新建） | 进度条渲染、人类可读字节、下载监视入口 |
| `install.sh`（改） | `_nlt_cp_first` 增加 `nlt-progress.sh` → `${LIBEXEC}/lib/` |
| `tests/progress_smoke.sh`（新建） | `bash -n` + 非 TTY 下调用一次 render 不报错 |
| `README.md`（改） | 简短说明如何 `source` 与在下载脚本中使用 |
| `docs/superpowers/specs/2026-04-15-war-23-progress-bar-design.md` | 只读对照 |

---

### Task 1: 新建 `nlt-progress.sh` 核心与防重复 source

**Files:**
- Create: `scripts/lib/nlt-progress.sh`
- Test: `bash -n scripts/lib/nlt-progress.sh`

- [ ] **Step 1: 文件头与 guard**

```bash
#!/usr/bin/env bash
# nlt-progress：可复用终端进度条（macOS + Linux）。由其他脚本 source。
[[ -n "${_NLT_PROGRESS_LOADED:-}" ]] && return 0
_NLT_PROGRESS_LOADED=1
```

- [ ] **Step 2: 实现 `_nlt_file_size`（mac + linux）**

```bash
_nlt_file_size() {
  local f="$1"
  [[ -f "$f" ]] || { echo 0; return 0; }
  if stat -f%z "$f" >/dev/null 2>&1; then
    stat -f%z "$f"
  else
    stat -c%s "$f" 2>/dev/null || echo 0
  fi
}
```

- [ ] **Step 3: 实现 `nlt_pb_human_bytes`**

使用 `awk` 将字节转为 KiB/MiB/GiB（1024 底），保留一位小数。

- [ ] **Step 4: 实现 `nlt_pb_render`**

参数建议：`current_bytes total_bytes label start_epoch`（`total_bytes` 为 0 表示未知，仅显示已传与已用时间，百分比与 ETA 显示 `—` 或省略）。

条形宽度由 `COLUMNS` 或 `tput cols` 或默认 80 推导；留边给文字。颜色：条形用 `\033[38;5;39m`…`\033[38;5;45m` 分段，或单色加粗；重置 `\033[0m`。

输出末尾 `\r` 不换行；完成时由调用方调用 `nlt_pb_done` 打印换行。

- [ ] **Step 5: `nlt_pb_done`**

```bash
nlt_pb_done() {
  [[ -t 1 ]] && printf '\n' || true
}
```

- [ ] **Step 6: `bash -n`**

```bash
bash -n scripts/lib/nlt-progress.sh
```

Expected: 无输出，退出码 0。

- [ ] **Step 7: Commit**

```bash
git add scripts/lib/nlt-progress.sh
git commit -m "feat(lib): add nlt-progress.sh progress bar helpers

Co-Authored-By: Paperclip <noreply@paperclip.ing>"
```

---

### Task 2: 下载监视辅助 `nlt_pb_curl_to_file`

**Files:**
- Modify: `scripts/lib/nlt-progress.sh`
- Test: `tests/progress_smoke.sh`（扩）

- [ ] **Step 1: 实现函数签名**

`nlt_pb_curl_to_file(url, dest, [optional_total])`：

1. 若未传 `total`，先用 `curl -sI -L` 解析 `Content-Length`（失败则 total=0）。
2. `start=$(date +%s)`，后台 `curl -fL -o "$dest" "$url"` 并保存 PID。
3. `while kill -0 $curl_pid`：`_nlt_file_size "$dest"` → `nlt_pb_render`；`sleep 0.25`。
4. `wait` curl；最后一帧 `nlt_pb_render` 100%；`nlt_pb_done`。
5. curl 非 0 则返回非 0。

- [ ] **Step 2: 非 TTY 分支**

若 `[ ! -t 1 ]`，跳过条形，仅每 N 秒 `echo` 一行简要进度（或完全静默），避免 CI 日志刷屏。

- [ ] **Step 3: Commit**

```bash
git add scripts/lib/nlt-progress.sh
git commit -m "feat(lib): curl download helper with progress polling

Co-Authored-By: Paperclip <noreply@paperclip.ing>"
```

---

### Task 3: `install.sh` 同步 `nlt-progress.sh`

**Files:**
- Modify: `install.sh`（`_nlt_cp_first` 块，紧跟 `nlt-common.sh` 之后）

- [ ] **Step 1: 增加复制**

```bash
  _nlt_cp_first "${LIBEXEC}/lib/nlt-progress.sh" \
    "${SCRIPTS}/lib/nlt-progress.sh"
```

- [ ] **Step 2: 运行 `bash -n install.sh`**

Expected: 退出码 0。

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "chore(install): ship nlt-progress.sh to libexec

Co-Authored-By: Paperclip <noreply@paperclip.ing>"
```

---

### Task 4: 测试 `tests/progress_smoke.sh`

**Files:**
- Create: `tests/progress_smoke.sh`

- [ ] **Step 1: 内容**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "${ROOT}/scripts/lib/nlt-progress.sh"
# shellcheck source=../scripts/lib/nlt-progress.sh
source "${ROOT}/scripts/lib/nlt-progress.sh"
export NONINTERACTIVE=1
# 非 TTY：确保不崩溃
nlt_pb_render 50 100 "smoke" "$(date +%s)" 2>/dev/null || true
echo "progress_smoke ok"
```

- [ ] **Step 2: `chmod +x` 并执行**

```bash
chmod +x tests/progress_smoke.sh
./tests/progress_smoke.sh
```

Expected: 打印 `progress_smoke ok`。

- [ ] **Step 3: Commit**

```bash
git add tests/progress_smoke.sh
git commit -m "test: add progress_smoke for nlt-progress

Co-Authored-By: Paperclip <noreply@paperclip.ing>"
```

---

### Task 5: README 片段

**Files:**
- Modify: `README.md`（在「目录结构」或 lib 说明附近增加一小节「进度条库」）

- [ ] **Step 1:** 说明 `source ~/.local/nltdeploy/libexec/nltdeploy/lib/nlt-progress.sh`（或开发时仓库 `scripts/lib/`），并指向设计文档。

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: document nlt-progress library usage

Co-Authored-By: Paperclip <noreply@paperclip.ing>"
```

---

## Self-review（规划者自检）

1. **Spec coverage：** 工单 7 条需求均映射到设计 §2 与 Task 1–2（彩色、百分比、时间、速率/大小、多平台）。  
2. **Placeholder scan：** 无 TBD。  
3. **一致性：** 函数命名以 `nlt_pb_` 为前缀，与仓库 `nlt_*` 风格一致。

---

## 执行交接

本计划保存于 `docs/superpowers/plans/2026-04-15-war-23-progress-bar.md`。请在父工单 [WAR-23](/WAR/issues/WAR-23) 下按任务顺序实现；完成后由 Planning Orchestrator 或 QA 做验收闭环。
