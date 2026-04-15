# nlt-download（GitHub 友好下载）

## 作用

对 **GitHub 族 HTTPS URL**（`github.com` / `raw.githubusercontent.com` / `api.github.com`）在调用 `curl` 前做 **可选** URL 改写；其它 URL 原样透传。与 **`scripts/lib/nlt-github-download.sh`** 同源：服务脚本应 **`source` 该库并调用 `_nlt_github_download_curl`**，或直接使用 **`nlt-download curl …`**。

## 环境变量

| 变量 | 说明 |
|------|------|
| `NLTDEPLOY_GITHUB_HUB_PROXY_PREFIX` | 非空时优先：将完整原始 URL 拼在该前缀之后（类 ghproxy）。 |
| `NLTDEPLOY_GITHUB_DOWNLOAD_MODE` | `off`（默认）\| `mirror_raw` \| `hub_proxy` |
| `NLTDEPLOY_GITHUB_RAW_MIRROR_BASE` | `mirror_raw` 下替换 `raw.githubusercontent.com` 的前缀 |

未设置时行为与直连 `curl` 一致。

## 用法

```bash
# 已安装 nltdeploy（PATH 含 ~/.local/nltdeploy/bin）
nlt-download curl -fsSL "https://api.github.com/repos/OWNER/REPO/releases/latest"

# 仅看改写结果
nlt-download resolve-url "https://raw.githubusercontent.com/foo/bar/HEAD/file.txt"
```

## 自测

```bash
NONINTERACTIVE=1 ./setup.sh install   # 会跑 selftest.sh
```

## 设计文档

仓库内：`docs/superpowers/specs/2026-04-15-war-24-github-download-tool-design.md`
