#!/usr/bin/env bash
# pnpm：优先 corepack；可回退到 npm 全局安装
# 用法: install（默认）| version
set -euo pipefail

die() { echo "错误: $*" >&2; exit 1; }

NODE_INSTALL_ROOT="${NODE_INSTALL_ROOT:-${HOME}/opt/node}"
NPM_GLOBAL_ROOT="${NPM_GLOBAL_ROOT:-${HOME}/opt/npm}"

_nlt_prepend_node_path() {
  if [[ -x "${NODE_INSTALL_ROOT}/bin/node" ]]; then
    export PATH="${NODE_INSTALL_ROOT}/bin:${PATH}"
  fi
}

do_install() {
  _nlt_prepend_node_path
  command -v node >/dev/null 2>&1 || die "需要 node（可先 nlt-dev nodejs install，或自行安装 Node 16.17+）"
  if [[ "${PNPM_USE_NPM_GLOBAL:-}" == "1" ]]; then
    mkdir -p "${NPM_GLOBAL_ROOT}/bin"
    export npm_config_prefix="${NPM_GLOBAL_ROOT}"
    echo "使用 npm 全局安装 pnpm 到 ${NPM_GLOBAL_ROOT} …" >&2
    command -v npm >/dev/null 2>&1 || die "需要 npm"
    npm install -g pnpm
    echo "请将 PATH 加入: ${NPM_GLOBAL_ROOT}/bin" >&2
    return 0
  fi
  node -e 'const p=process.version.slice(1).split(".").map(Number);process.exit(p[0]>16||(p[0]===16&&p[1]>=17)?0:1)' 2>/dev/null \
    || die "corepack 需要 Node 16.17+；当前版本过低或无法解析"
  echo "启用 corepack 并激活 pnpm …" >&2
  corepack enable
  corepack prepare pnpm@latest --activate
  command -v pnpm >/dev/null 2>&1 || die "pnpm 仍未在 PATH 中（尝试重新打开终端或检查 corepack 输出）"
  echo "pnpm 已就绪: $(command -v pnpm)" >&2
}

do_version() {
  _nlt_prepend_node_path
  command -v pnpm >/dev/null 2>&1 && pnpm -v || die "未找到 pnpm"
}

cmd="${1:-install}"
case "$cmd" in
  install | update | upgrade) do_install ;;
  version) do_version ;;
  -h | --help | help)
    cat <<'EOF'
用法: pnpm/setup.sh [install|version]

  install / update   corepack prepare pnpm@latest --activate
  version            pnpm -v

若 corepack 不可用，可设置:
  PNPM_USE_NPM_GLOBAL=1   使用 npm install -g pnpm，前缀 NPM_GLOBAL_ROOT（默认 ~/opt/npm）

安装 Node 见: nlt-dev nodejs install（默认 ~/opt/node）
EOF
    ;;
  *) die "未知子命令: $cmd" ;;
esac
