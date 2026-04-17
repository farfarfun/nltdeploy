#!/usr/bin/env bash
# uv（Astral）：官方安装脚本安装 / 升级；与 nlt-dev / python-env 叙事一致
# 用法: install（默认）| update | version | uninstall
# 官方文档: https://docs.astral.sh/uv/getting-started/installation/
set -euo pipefail

die() { echo "错误: $*" >&2; exit 1; }

UV_INSTALL_URL="${UV_INSTALL_URL:-https://astral.sh/uv/install.sh}"

do_install() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  echo "执行 Astral 官方 uv 安装脚本: ${UV_INSTALL_URL}" >&2
  # 安装器识别 UV_INSTALL_DIR、INSTALLER_NO_MODIFY_PATH 等；见上游 install.sh 注释
  curl -LsSf "${UV_INSTALL_URL}" | sh
  echo "安装完成。若 shell 中仍找不到 uv，请将安装器提示的 bin 目录加入 PATH（常见为 ~/.local/bin 或 ~/.cargo/bin）。" >&2
}

do_update() {
  if command -v uv >/dev/null 2>&1; then
    echo "执行 uv self update …" >&2
    uv self update
  else
    echo "未在 PATH 中找到 uv，改为执行官方安装脚本 …" >&2
    do_install
  fi
}

do_version() {
  command -v uv >/dev/null 2>&1 || die "未找到 uv（可先 nlt-dev uv install）"
  uv --version
}

do_uninstall() {
  command -v uv >/dev/null 2>&1 || { echo "未找到 uv，跳过卸载。" >&2; return 0; }
  echo "执行 uv self uninstall（非交互确认）…" >&2
  if printf 'y\n' | uv self uninstall; then
    echo "已执行 uv self uninstall。" >&2
  else
    die "uv self uninstall 失败，请查阅 uv 文档手动移除"
  fi
}

cmd="${1:-install}"
case "$cmd" in
  install) do_install ;;
  update | upgrade) do_update ;;
  version) do_version ;;
  uninstall | remove) do_uninstall ;;
  -h | --help | help)
    cat <<'EOF'
用法: uv/setup.sh [install|update|version|uninstall]

  install（默认）  curl 管道执行 Astral 官方 install.sh
  update / upgrade  若 PATH 中已有 uv：uv self update；否则同 install
  version           uv --version
  uninstall         管道确认后执行 uv self uninstall

环境变量（与上游安装器一致，常用）:
  UV_INSTALL_DIR           指定安装目录（默认由官方脚本决定，多为 ~/.local/bin）
  INSTALLER_NO_MODIFY_PATH 设为 1 时不改 shell 配置，仅安装二进制
  UV_INSTALL_URL           覆盖安装脚本 URL（默认 https://astral.sh/uv/install.sh）

与 python-env 的关系:
  python-env 在创建虚拟环境前也会按需自动安装 uv；若希望**先单独装好/升级 uv**，
  请使用 nlt-dev uv（本脚本），对外文档请以 nlt-dev 为唯一主入口。
EOF
    ;;
  *) die "未知子命令: $cmd（见 uv/setup.sh --help）" ;;
esac
