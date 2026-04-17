#!/usr/bin/env bash
# Go：官方预编译包安装 / 升级（用户态目录，无需 sudo）
# 用法: install（默认）| version | uninstall
set -euo pipefail

die() { echo "错误: $*" >&2; exit 1; }

GO_INSTALL_ROOT="${GO_INSTALL_ROOT:-${HOME}/opt/go}"

_nlt_go_platform() {
  local os arch
  os="$(uname -s 2>/dev/null || true)"
  arch="$(uname -m 2>/dev/null || true)"
  case "${os}:${arch}" in
    Linux:x86_64) printf '%s\n' linux-amd64 ;;
    Linux:aarch64) printf '%s\n' linux-arm64 ;;
    Darwin:arm64) printf '%s\n' darwin-arm64 ;;
    Darwin:x86_64) printf '%s\n' darwin-amd64 ;;
    *) die "不支持的系统: ${os} ${arch}" ;;
  esac
}

_nlt_go_latest_version() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  local line
  line="$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1 | tr -d '\r')"
  [[ -n "$line" ]] || die "无法从 go.dev 读取版本"
  printf '%s\n' "$line"
}

do_install() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  local plat ver parent tmp url
  plat="$(_nlt_go_platform)"
  if [[ -n "${GO_VERSION:-}" ]]; then
    ver="${GO_VERSION}"
  else
    ver="$(_nlt_go_latest_version)"
  fi
  [[ "$ver" == go* ]] || ver="go${ver#go}"
  url="https://go.dev/dl/${ver}.${plat}.tar.gz"
  parent="$(dirname "${GO_INSTALL_ROOT}")"
  mkdir -p "${parent}"
  tmp="$(mktemp)"
  echo "下载: ${url}" >&2
  curl -fL --progress-bar "${url}" -o "${tmp}"
  rm -rf "${GO_INSTALL_ROOT}"
  tar -C "${parent}" -xzf "${tmp}"
  rm -f "${tmp}"
  echo "已安装 Go ${ver} 到 ${GO_INSTALL_ROOT}" >&2
  echo "请将下列行加入 shell 配置（若尚未配置）：" >&2
  echo "  export PATH=\"${GO_INSTALL_ROOT}/bin:\${PATH}\"" >&2
}

do_version() {
  if [[ -x "${GO_INSTALL_ROOT}/bin/go" ]]; then
    "${GO_INSTALL_ROOT}/bin/go" version
  else
    command -v go >/dev/null 2>&1 && go version || die "未找到 go（${GO_INSTALL_ROOT}/bin/go 不存在且 PATH 中无 go）"
  fi
}

do_uninstall() {
  [[ -d "${GO_INSTALL_ROOT}" ]] || { echo "目录不存在，跳过: ${GO_INSTALL_ROOT}" >&2; return 0; }
  rm -rf "${GO_INSTALL_ROOT}"
  echo "已删除: ${GO_INSTALL_ROOT}" >&2
}

cmd="${1:-install}"
case "$cmd" in
  install | update | upgrade) do_install ;;
  version) do_version ;;
  uninstall | remove) do_uninstall ;;
  -h | --help | help)
    cat <<'EOF'
用法: go/setup.sh [install|version|uninstall]

  install / update   从 go.dev 下载官方包到 GO_INSTALL_ROOT（默认 ~/opt/go）
  version            打印已安装的 go version
  uninstall          删除 GO_INSTALL_ROOT

环境变量:
  GO_INSTALL_ROOT   安装目录（GOROOT）
  GO_VERSION        强制版本，如 go1.22.4；不设则使用 go.dev 最新稳定版
EOF
    ;;
  *) die "未知子命令: $cmd（试试 install / version / uninstall）" ;;
esac
