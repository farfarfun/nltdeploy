#!/usr/bin/env bash
# Rust：通过 rustup 安装或升级 stable 工具链
# 用法: install（默认）| update | uninstall
set -euo pipefail

die() { echo "错误: $*" >&2; exit 1; }

do_install() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  echo "执行 rustup 安装（stable）…" >&2
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  echo "完成后请将 cargo 的 bin 加入 PATH（rustup 提示中通常含 ~/.cargo/bin）。" >&2
}

do_update() {
  if command -v rustup >/dev/null 2>&1; then
    rustup self update || true
    rustup update stable
  else
    echo "未找到 rustup，改为执行 install …" >&2
    do_install
  fi
}

do_uninstall() {
  if [[ -x "${HOME}/.cargo/bin/rustup" ]]; then
    rustup self uninstall -y || true
  else
    echo "未找到 ~/.cargo/bin/rustup，请手动删除 ~/.rustup 与 ~/.cargo（若存在）。" >&2
  fi
}

cmd="${1:-install}"
case "$cmd" in
  install) do_install ;;
  update | upgrade) do_update ;;
  uninstall | remove) do_uninstall ;;
  -h | --help | help)
    cat <<'EOF'
用法: rust/setup.sh [install|update|uninstall]

  install     运行官方 rustup 脚本，默认 stable、非交互（-y）
  update      rustup self update && rustup update stable；若无 rustup 则同 install
  uninstall   rustup self uninstall -y

可选环境变量:
  RUSTUP_HOME / CARGO_HOME  见 rustup 文档
EOF
    ;;
  *) die "未知子命令: $cmd" ;;
esac
