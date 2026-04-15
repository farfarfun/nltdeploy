# WAR-24 GitHub 友好下载工具 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加可复用的 GitHub 下载加速能力（环境变量驱动的 URL 改写 + `nlt-download curl` 包装），默认不改变现有行为。

**Architecture:** 在 `scripts/lib/` 新增可 source 的 URL 解析模块；新增 `scripts/tools/download/` 域提供 CLI 与 README；`install.sh` 注册 `nlt-download` 并同步 libexec。

**Tech stack:** Bash 3.2+、`curl`、现有 `nlt-common.sh` / `_nlt_ensure_gum` 约定（交互路径若需要 gum 则遵循域规范）。

---

### Task 1: 库模块 `nlt-github-download.sh`

**Files:**

- Create: `scripts/lib/nlt-github-download.sh`
- Modify（可选）: `scripts/lib/nlt-common.sh`（若团队希望默认加载库，则末尾 `source`；否则跳过并在 README 说明）

- [ ] **Step 1:** 实现 `_nlt_is_github_download_host` / `_nlt_github_download_resolve_url`（名称可微调），覆盖 `github.com`、`raw.githubusercontent.com`、`api.github.com`。
- [ ] **Step 2:** 实现 `NLTDEPLOY_GITHUB_DOWNLOAD_MODE`、`NLTDEPLOY_GITHUB_RAW_MIRROR_BASE`、`NLTDEPLOY_GITHUB_HUB_PROXY_PREFIX` 的优先级与 stderr 诊断输出。
- [ ] **Step 3:** 边界：非 HTTPS、空 URL、未知主机 → 原样返回；禁止双写前缀。

### Task 2: CLI 域 `scripts/tools/download/setup.sh`

**Files:**

- Create: `scripts/tools/download/setup.sh`
- Create: `scripts/tools/download/README.md`

- [ ] **Step 1:** `source` 公共库路径解析（与 `github-net` 相同的两级 `../lib` / `../../lib` 回退）。
- [ ] **Step 2:** 实现 `cmd_curl`：从 `"$@"` 中定位 URL token，改写后 `exec curl`；保留 `curl` 退出码。
- [ ] **Step 3:** 实现 `cmd_resolve_url`（打印单行结果）。
- [ ] **Step 4:** 实现工具域必选子命令 `install|update|reinstall|uninstall`（与规范一致；若无副作用则文档化 noop 行为）。
- [ ] **Step 5:** 无参 / `help`：`_nlt_ensure_gum` 后 gum 菜单或打印 usage（遵循 `NONINTERACTIVE=1`）。

### Task 3: 安装器与 libexec 同步

**Files:**

- Modify: `install.sh`（`_emit_wrapper nlt-download`、`mkdir` libexec 子目录、`_nlt_cp_first` 复制 `download/setup.sh` 与 `nlt-github-download.sh`）

- [ ] **Step 1:** 对齐现有 `port-kill` / `github-net` 的复制与 wrapper 模式。
- [ ] **Step 2:** 本地执行 `./install.sh install`（或仓库根直跑）验证 `bin/nlt-download` 存在且可 `--help`。

### Task 4: 文档与轻量自测

**Files:**

- Modify: `README.md`（工具表增加 `download` 一行）
- Create或修改: `scripts/tools/download/selftest.sh`（可选，由 `NONINTERACTIVE=1 ./setup.sh install` 或独立入口触发固定用例）

- [ ] **Step 1:** README 中给出国内 raw 与 hub 前缀示例（**占位域名**或公开已知镜像示例需注明「用户自担风险/可用性」）。
- [ ] **Step 2:** 至少 3 个 `resolve-url` 用例在自测中覆盖：关闭模式、hub 前缀模式、非 GitHub 直通。

### Task 5: 交付

- [ ] **Step 1:** `shellcheck` 或仓库既有静态检查（若有）对新增文件清零关键告警。
- [ ] **Step 2:** Git 提交信息末尾追加 `Co-Authored-By: Paperclip <noreply@paperclip.ing>`。
- [ ] **Step 3:** 在父工单 [WAR-24](/WAR/issues/WAR-24) 评论中简述实现要点并链接本计划文件（仓库路径即可）。
