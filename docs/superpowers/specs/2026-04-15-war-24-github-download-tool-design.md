# WAR-24：GitHub 友好下载工具 — 设计说明

**日期：** 2026-04-15  
**状态：** 已定稿（供实现）  
**关联工单：** [WAR-24](/WAR/issues/WAR-24)（Paperclip）  
**关联计划：** [`docs/superpowers/plans/2026-04-15-war-24-github-download-tool.md`](../plans/2026-04-15-war-24-github-download-tool.md)

---

## 1. 背景与目标

仓库内多处使用 `curl` 直链 `github.com`、`raw.githubusercontent.com`、`api.github.com` 等。在受限网络下需要 **可配置的镜像 / 代理策略**，且可被 **脚本 source** 与 **命令行** 两种方式复用。

**成功标准：**

- 提供稳定 CLI：`nlt-download curl …`（透传剩余参数给 `curl`），对 **识别为 GitHub 族** 的 URL 在调用前做 **可选** 的 URL 变换。
- 提供 Bash 库函数 **`_nlt_github_download_resolve_url`** / **`_nlt_github_download_curl`**（**`new-api`、`code-server`、`utils`（gum）、`nlt-common`（拉 gum 安装脚本）、`nlt-progress`（GitHub 资源下载）** 等已统一接入，不再保留平行的「裸 `curl` 直链 GitHub」实现路径）。
- **默认行为与当前一致**（不设环境变量时不改写 URL），避免破坏现有用户。
- 标准 `curl` 代理环境变量（`HTTPS_PROXY` / `ALL_PROXY` 等）继续生效，不在此工具内重复发明代理协议栈。

---

## 2. 方案对比（已选）

| 方案 | 优点 | 缺点 |
|------|------|------|
| A. 仅文档要求用户自行 export 代理 | 零代码 | 无统一 raw 镜像、Release 资产路径难记 |
| B. 独立 `nlt-download` + 可 source 的 lib | 边界清晰、可测、可渐进替换各脚本内联 `curl` | 需维护白名单与文档 |
| C. 在每一处 `curl` 硬编码镜像 | 直观 | 重复、易漂移、难全局切换 |

**选择 B**：与现有 `scripts/lib/nlt-common.sh`、`nlt-*` 安装模式一致，长期可让各域脚本调用同一入口。

---

## 3. 行为规格

### 3.1 识别的 URL 形态（主机级白名单）

仅对下列 **主机**（大小写不敏感）考虑改写，其它 URL **原样**：

- `github.com`（含 `https://github.com/owner/repo/releases/download/...`）
- `raw.githubusercontent.com`
- `api.github.com`（若用户显式启用镜像策略）

### 3.2 环境变量（提议名称，实现以代码为准）

| 变量 | 含义 |
|------|------|
| `NLTDEPLOY_GITHUB_DOWNLOAD_MODE` | `off`（默认）\|`mirror_raw`\|`hub_proxy` 等；扩展时保持向后兼容。 |
| `NLTDEPLOY_GITHUB_RAW_MIRROR_BASE` | 例如 Gitee raw 或企业镜像的 **前缀**（不含路径时由实现拼接规则文档化）。 |
| `NLTDEPLOY_GITHUB_HUB_PROXY_PREFIX` | 兼容类 ghproxy 的 **完整前缀**（如 `https://mirror.example/https://`），实现将 **原始完整 URL** 拼在其后。 |

**约束：**

- 多种策略同时设置时，**优先级**在 README 写明；建议：`hub_proxy_prefix` > `mirror_raw` > `off`。
- 任何改写必须 **日志可见**（stderr 一行：原始 URL → 实际 URL），便于排障。
- 不得对非 HTTPS 或未知主机做隐式改写。

### 3.3 CLI 形态

- 新增域：`scripts/tools/download/setup.sh`，`install.sh` 增加 `nlt-download` 包装与 `libexec/.../download/` 同步规则（与现有 tools 一致）。
- 子命令（工具域必选之外）：
  - `curl`：解析第一个 URL 参数（在参数列表中扫描以 `http://` 或 `https://` 开头的 token），改写后 `exec curl` 原参数列。
  - `resolve-url`（可选）：仅打印改写后的 URL，供调试与非 bash 调用方。
- 工具域必选子命令：`install` / `update` / `reinstall` / `uninstall` 可与 `github-net` 类似：无持久安装物时可退化为说明性 noop 或「已随 nltdeploy 分发」提示，但须在 README 写清。

### 3.4 库形态

- 新文件建议：`scripts/lib/nlt-github-download.sh`（由需要者 `source`，避免无限膨胀 `nlt-common.sh`）；`nlt-common.sh` **可选** 一行 source 该文件以便单点入口（若实现选择不自动 source，则文档说明由调用方 source）。

---

## 4. 测试与文档

- **Shell 级**：对若干固定输入 URL + 固定环境组合，断言 `resolve-url` 输出（可用小型 bash 测试段或 `bats`，若仓库尚无测试框架则以可维护的 `if … then die` 自测脚本放在 `download` 域内并由 `NONINTERACTIVE=1` 触发）。
- **README**：`README.md` 服务列表增加一行；`scripts/tools/download/README.md` 描述变量与示例。

---

## 5. 非目标（本迭代明确不做）

- 不自动探测「哪个镜像最快」、不做周期性健康检查服务。
- 不替代 `git clone`（仍由 `install.sh` 与 `github-net` 等既有路径负责）。

## 6. 仓库内迁移策略（董事会补充）

凡 **本仓库内** 面向 **GitHub 资源（Release 资产、GitHub API、raw 等）** 的 **文件/JSON 下载**，须经 **`_nlt_github_download_curl`**（或等价的 `nlt-download curl`）路径，**不保留**并行的「脚本内手写直连 GitHub 的 `curl`」下载逻辑。  
**例外**：面向 **非 GitHub 主机**（如 PyPI、astral.sh、本机 `127.0.0.1` 健康检查）的 `curl` 不变；面向用户的 **管道/bootstrap 文档** 仍可展示裸 `curl`（用户尚未安装 nltdeploy 时）。

---

## 7. 历史记录

- 2026-04-15：初版规格。
- 2026-04-15：按董事会评论增加 §6（强制迁移 GitHub 下载实现路径）。
