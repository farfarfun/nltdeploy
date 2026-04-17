#!/usr/bin/env bash
# Node.js：官方预编译 tarball，安装到用户目录（无需 brew）
# 用法: install（默认）| version | uninstall
set -euo pipefail

die() { echo "错误: $*" >&2; exit 1; }

NODE_VERSION="${NODE_VERSION:-22.14.0}"
NODE_INSTALL_ROOT="${NODE_INSTALL_ROOT:-${HOME}/opt/node}"

_nlt_node_platform() {
  local os arch
  os="$(uname -s 2>/dev/null || true)"
  arch="$(uname -m 2>/dev/null || true)"
  case "${os}:${arch}" in
    Linux:x86_64) printf '%s\n' linux-x64 ;;
    Linux:aarch64) printf '%s\n' linux-arm64 ;;
    Darwin:arm64) printf '%s\n' darwin-arm64 ;;
    Darwin:x86_64) printf '%s\n' darwin-x64 ;;
    *) die "不支持的系统: ${os} ${arch}" ;;
  esac
}

do_install() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  local plat base name url tmp
  plat="$(_nlt_node_platform)"
  base="https://nodejs.org/dist/v${NODE_VERSION}"
  name="node-v${NODE_VERSION}-${plat}"
  url="${base}/${name}.tar.xz"
  tmp="$(mktemp)"
  mkdir -p "$(dirname "${NODE_INSTALL_ROOT}")"
  echo "下载: ${url}" >&2
  curl -fL --progress-bar "${url}" -o "${tmp}"
  rm -rf "${NODE_INSTALL_ROOT}"
  mkdir -p "${NODE_INSTALL_ROOT}"
  tar -C "${NODE_INSTALL_ROOT}" --strip-components=1 -xJf "${tmp}"
  rm -f "${tmp}"
  echo "已安装 Node v${NODE_VERSION} 到 ${NODE_INSTALL_ROOT}" >&2
  echo "请配置 PATH：" >&2
  echo "  export PATH=\"${NODE_INSTALL_ROOT}/bin:\${PATH}\"" >&2
}

do_version() {
  if [[ -x "${NODE_INSTALL_ROOT}/bin/node" ]]; then
    "${NODE_INSTALL_ROOT}/bin/node" -v
  else
    command -v node >/dev/null 2>&1 && node -v || die "未找到 node"
  fi
}

do_uninstall() {
  [[ -d "${NODE_INSTALL_ROOT}" ]] || { echo "目录不存在，跳过: ${NODE_INSTALL_ROOT}" >&2; return 0; }
  rm -rf "${NODE_INSTALL_ROOT}"
  echo "已删除: ${NODE_INSTALL_ROOT}" >&2
}

cmd="${1:-install}"
case "$cmd" in
  install | update | upgrade) do_install ;;
  version) do_version ;;
  uninstall | remove) do_uninstall ;;
  -h | --help | help)
    cat <<'EOF'
用法: nodejs/setup.sh [install|version|uninstall]

  install / update   下载 nodejs.org 官方包到 NODE_INSTALL_ROOT（默认 ~/opt/node）
  version            打印 node 版本
  uninstall          删除 NODE_INSTALL_ROOT

环境变量:
  NODE_VERSION         版本号，默认 22.14.0
  NODE_INSTALL_ROOT    安装根目录（含 bin/node）
EOF
    ;;
  *) die "未知子命令: $cmd" ;;
esac
