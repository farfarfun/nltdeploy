#!/usr/bin/env bash
# Paperclip（https://github.com/paperclipai/paperclip）本机服务：从 GitHub 克隆源码 + pnpm 安装 + 启停。
# 默认数据见上游文档：~/.paperclip/instances/default/（可用 PAPERCLIP_HOME 覆盖）。
#
# 依赖：git、Node.js 20+、pnpm 9+（无 pnpm 时尝试 corepack enable）
#
# 用法：
#   ./setup.sh              # gum 菜单
#   ./setup.sh install      # 克隆/拉取源码并 pnpm install
#   ./setup.sh update       # git pull + pnpm install
#   ./setup.sh start        # 后台启动（pnpm paperclipai run）；无配置时会先非交互生成默认配置
#   ./setup.sh onboard      # 上游首次配置（NONINTERACTIVE=1 时加 --yes）
#   ./setup.sh stop / restart / status
#
# 环境变量：
#   PAPERCLIP_SERVICE_HOME   本脚本管理根目录（默认 ~/opt/paperclip）
#   PAPERCLIP_REPO_URL       上游 Git（默认 https://github.com/paperclipai/paperclip.git）
#   PAPERCLIP_GIT_BRANCH     克隆分支（默认 main）
#   PAPERCLIP_PORT           监听与健康检查端口（默认 8804；启动时 export PORT 同值）
#   PAPERCLIP_HOME           上游数据根（默认 ~/.paperclip），与官方 CLI 一致
#   PAPERCLIP_INSTANCE_ID    实例 id（默认 default）
#   NONINTERACTIVE=1         跳过 gum 确认；onboard 子命令使用 --yes
#   PAPERCLIP_UNINSTALL_YES=1  非 TTY 卸载确认

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../lib/nlt-common.sh" ]]; then
  # shellcheck source=../lib/nlt-common.sh
  source "${SCRIPT_DIR}/../lib/nlt-common.sh"
elif [[ -f "${SCRIPT_DIR}/../../lib/nlt-common.sh" ]]; then
  # shellcheck source=../../lib/nlt-common.sh
  source "${SCRIPT_DIR}/../../lib/nlt-common.sh"
else
  echo "错误: 找不到 lib/nlt-common.sh（已检查 ${SCRIPT_DIR}/../lib 与 ${SCRIPT_DIR}/../../lib）" >&2
  exit 1
fi

PAPERCLIP_SERVICE_HOME="${PAPERCLIP_SERVICE_HOME:-${HOME}/opt/paperclip}"
PAPERCLIP_REPO_URL="${PAPERCLIP_REPO_URL:-https://github.com/paperclipai/paperclip.git}"
PAPERCLIP_GIT_BRANCH="${PAPERCLIP_GIT_BRANCH:-main}"
PAPERCLIP_PORT="${PAPERCLIP_PORT:-8804}"

PAPERCLIP_SRC="${PAPERCLIP_SRC:-${PAPERCLIP_SERVICE_HOME}/src/paperclip}"
PAPERCLIP_RUN_DIR="${PAPERCLIP_SERVICE_HOME}/run"
PAPERCLIP_LOG_DIR="${PAPERCLIP_SERVICE_HOME}/log"
PID_FILE="${PAPERCLIP_RUN_DIR}/paperclip.pid"
LOG_FILE="${PAPERCLIP_LOG_DIR}/paperclip.run.log"

usage() {
  cat <<USAGE
用法: ./setup.sh [command [args...]]

  无参数：gum 菜单。

命令:
  install     克隆 ${PAPERCLIP_REPO_URL} 到 ${PAPERCLIP_SRC}（已存在则 fetch 后 checkout 分支）并执行 pnpm install
  update      git pull 后 pnpm install
  start       后台启动: cd 源码目录 && pnpm paperclipai run（日志 ${LOG_FILE}）；若无实例配置则先 onboard --yes
  onboard     首次配置（交互）；NONINTERACTIVE=1 时执行 onboard --yes
  stop        停止进程
  restart     stop 后 start
  status      PID 与 HTTP 健康检查 http://127.0.0.1:${PAPERCLIP_PORT}/api/health
  uninstall   停止进程并删除 ${PAPERCLIP_SERVICE_HOME}（不可逆，有确认）

说明: 上游在无 ~/.paperclip/.../config.json 且非 TTY 时不会自动 onboard；start 会尝试用 script(1)+onboard --yes 生成配置。
      若仍失败，请在终端执行: cd ${PAPERCLIP_SRC} && pnpm paperclipai onboard
USAGE
}

paperclip_instance_config_json() {
  local root="${PAPERCLIP_HOME:-${HOME}/.paperclip}"
  local id="${PAPERCLIP_INSTANCE_ID:-default}"
  echo "${root}/instances/${id}/config.json"
}

# 无配置时：在伪终端下执行 onboard --yes；若上游在 onboard 结束后仍常驻监听，在检测到 config 出现后结束该进程
ensure_paperclip_instance_config() {
  local cfg
  cfg="$(paperclip_instance_config_json)"
  if [[ -f "$cfg" ]]; then
    return 0
  fi
  command -v script >/dev/null 2>&1 || die "缺少 script(1)，无法在无 TTY 下生成配置。请在本机终端执行: cd ${PAPERCLIP_SRC} && pnpm paperclipai onboard"

  echo "==> 未找到实例配置: ${cfg}" >&2
  echo "==> 正在非交互生成默认配置（pnpm paperclipai onboard --yes）…" >&2

  local op_log
  op_log="$(mktemp "${TMPDIR:-/tmp}/nlt-paperclip-onboard.XXXXXX")"
  (
    cd "${PAPERCLIP_SRC}" || exit 1
    if script -qec "exit 0" /dev/null 2>/dev/null; then
      exec script -qec "cd \"${PAPERCLIP_SRC}\" && pnpm paperclipai onboard --yes" /dev/null
    else
      exec script -q /dev/null bash -c "cd \"${PAPERCLIP_SRC}\" && pnpm paperclipai onboard --yes"
    fi
  ) >>"${op_log}" 2>&1 &
  local opid=$!
  local waited=0
  while (( waited < 180 )); do
    if [[ -f "$cfg" ]]; then
      kill "$opid" 2>/dev/null || true
      wait "$opid" 2>/dev/null || true
      cat "${op_log}" >>"${LOG_FILE}"
      rm -f "${op_log}"
      echo "==> 已生成配置: ${cfg}" >&2
      return 0
    fi
    if ! kill -0 "$opid" 2>/dev/null; then
      wait "$opid" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  kill "$opid" 2>/dev/null || true
  wait "$opid" 2>/dev/null || true
  cat "${op_log}" >>"${LOG_FILE}"
  rm -f "${op_log}"

  if [[ -f "$cfg" ]]; then
    echo "==> 已生成配置: ${cfg}" >&2
    return 0
  fi
  die "仍未生成 ${cfg}。请在**交互终端**执行: cd ${PAPERCLIP_SRC} && pnpm paperclipai onboard   然后重试: $0 start"
}

ensure_dirs() {
  mkdir -p "${PAPERCLIP_RUN_DIR}" "${PAPERCLIP_LOG_DIR}"
}

die() { echo "错误: $*" >&2; exit 1; }

process_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

read_pid() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo ""
    return
  fi
  tr -d '[:space:]' <"$PID_FILE" || true
}

require_git() {
  command -v git >/dev/null 2>&1 || die "需要 git"
}

require_node() {
  command -v node >/dev/null 2>&1 || die "需要 Node.js 20+（https://nodejs.org/）"
  local major
  major="$(node -p 'parseInt(process.versions.node.split(".")[0], 10)')"
  if (( major < 20 )); then
    die "需要 Node.js 20+，当前: $(node --version)"
  fi
}

ensure_pnpm() {
  if command -v pnpm >/dev/null 2>&1; then
    return 0
  fi
  if command -v corepack >/dev/null 2>&1; then
    echo "启用 corepack 并准备 pnpm …" >&2
    corepack enable
    corepack prepare pnpm@9.15.0 --activate
  fi
  command -v pnpm >/dev/null 2>&1 || die "需要 pnpm 9+（可: corepack enable && corepack prepare pnpm@9 --activate）"
}

clone_or_update_source() {
  require_git
  local parent
  parent="$(dirname "$PAPERCLIP_SRC")"
  mkdir -p "$parent"
  if [[ ! -d "${PAPERCLIP_SRC}/.git" ]]; then
    if [[ -e "$PAPERCLIP_SRC" ]]; then
      die "路径已存在且非 git 仓库: ${PAPERCLIP_SRC}"
    fi
    echo "==> git clone ${PAPERCLIP_REPO_URL} -> ${PAPERCLIP_SRC}（分支 ${PAPERCLIP_GIT_BRANCH}）" >&2
    if ! git clone --depth 1 --branch "${PAPERCLIP_GIT_BRANCH}" "${PAPERCLIP_REPO_URL}" "${PAPERCLIP_SRC}"; then
      git clone "${PAPERCLIP_REPO_URL}" "${PAPERCLIP_SRC}"
      git -C "${PAPERCLIP_SRC}" checkout "${PAPERCLIP_GIT_BRANCH}"
    fi
  else
    echo "==> 更新源码: ${PAPERCLIP_SRC}" >&2
    git -C "${PAPERCLIP_SRC}" fetch origin "${PAPERCLIP_GIT_BRANCH}" 2>/dev/null || git -C "${PAPERCLIP_SRC}" fetch origin
    git -C "${PAPERCLIP_SRC}" checkout "${PAPERCLIP_GIT_BRANCH}" 2>/dev/null || true
    git -C "${PAPERCLIP_SRC}" pull --ff-only origin "${PAPERCLIP_GIT_BRANCH}" 2>/dev/null \
      || git -C "${PAPERCLIP_SRC}" pull --ff-only || true
  fi
  [[ -f "${PAPERCLIP_SRC}/package.json" ]] || die "克隆后未找到 package.json: ${PAPERCLIP_SRC}"
}

cmd_install() {
  require_node
  ensure_pnpm
  ensure_dirs
  clone_or_update_source
  echo "==> pnpm install（${PAPERCLIP_SRC}）…" >&2
  (cd "${PAPERCLIP_SRC}" && pnpm install)
  echo "安装完成。执行: $0 start（或 PAPERCLIP_SERVICE_HOME=… $0 start）"
}

cmd_update() {
  require_node
  ensure_pnpm
  [[ -d "${PAPERCLIP_SRC}/.git" ]] || die "未找到源码目录，请先 install"
  require_git
  echo "==> git pull …" >&2
  git -C "${PAPERCLIP_SRC}" pull --ff-only || git -C "${PAPERCLIP_SRC}" pull
  echo "==> pnpm install …" >&2
  (cd "${PAPERCLIP_SRC}" && pnpm install)
  echo "更新完成。"
}

cmd_onboard() {
  require_node
  ensure_pnpm
  [[ -d "${PAPERCLIP_SRC}" && -f "${PAPERCLIP_SRC}/package.json" ]] || die "未安装源码，请先: $0 install"
  pushd "${PAPERCLIP_SRC}" >/dev/null
  if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    pnpm paperclipai onboard --yes "$@"
  else
    pnpm paperclipai onboard "$@"
  fi
  popd >/dev/null
}

cmd_start() {
  require_node
  ensure_pnpm
  [[ -d "${PAPERCLIP_SRC}" && -f "${PAPERCLIP_SRC}/package.json" ]] || die "未安装源码，请先: $0 install"
  ensure_dirs
  ensure_paperclip_instance_config
  local existing
  existing="$(read_pid)"
  if [[ -n "$existing" ]] && process_alive "$existing"; then
    echo "Paperclip 已在运行（PID ${existing}）。如需重启: $0 restart" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
  echo "==> 启动 Paperclip（pnpm paperclipai run），日志: ${LOG_FILE}" >&2
  echo "    默认 UI/API: http://127.0.0.1:${PAPERCLIP_PORT}" >&2
  pushd "${PAPERCLIP_SRC}" >/dev/null
  export PORT="${PAPERCLIP_PORT}"
  nohup pnpm paperclipai run >>"${LOG_FILE}" 2>&1 &
  local cpid=$!
  echo "$cpid" >"$PID_FILE"
  popd >/dev/null
  sleep 1
  existing="$(read_pid)"
  if [[ -n "$existing" ]] && process_alive "$existing"; then
    echo "已启动 PID ${existing}"
  else
    echo "警告: 未能确认进程存活，请查看日志: tail -50 ${LOG_FILE}" >&2
  fi
}

cmd_stop() {
  local pid
  pid="$(read_pid)"
  if [[ -z "$pid" ]]; then
    echo "未找到 PID 文件，视为未启动。" >&2
    rm -f "$PID_FILE"
    return 0
  fi
  if ! process_alive "$pid"; then
    echo "PID ${pid} 不存在，清理 PID 文件。"
    rm -f "$PID_FILE"
    return 0
  fi
  if [[ "${NONINTERACTIVE:-}" != "1" ]] && [[ -t 0 ]]; then
    gum confirm "停止 Paperclip（PID ${pid}）？" || exit 0
  fi
  kill -TERM "$pid" 2>/dev/null || true
  local w=0
  while process_alive "$pid" && (( w < 30 )); do
    sleep 1
    w=$((w + 1))
  done
  if process_alive "$pid"; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  echo "已停止。"
}

cmd_restart() {
  cmd_stop || true
  cmd_start
}

cmd_status() {
  local pid
  pid="$(read_pid)"
  echo "PAPERCLIP_SRC=${PAPERCLIP_SRC}"
  echo "PAPERCLIP_SERVICE_HOME=${PAPERCLIP_SERVICE_HOME}"
  if [[ -n "$pid" ]] && process_alive "$pid"; then
    echo "状态: 运行中 PID ${pid}"
  else
    echo "状态: 未运行"
    rm -f "$PID_FILE"
  fi
  if command -v curl >/dev/null 2>&1; then
    echo ""
    echo "==> GET http://127.0.0.1:${PAPERCLIP_PORT}/api/health"
    curl -sS -m 3 "http://127.0.0.1:${PAPERCLIP_PORT}/api/health" || echo "（无法连接，可能未启动或端口不同）"
    echo ""
  fi
}

cmd_uninstall() {
  cmd_stop || true
  echo "将删除目录: ${PAPERCLIP_SERVICE_HOME}" >&2
  if [[ -t 0 ]]; then
    gum confirm "确认永久删除上述目录（不含 ~/.paperclip 数据，仅服务安装根）？" || exit 0
  else
    [[ "${PAPERCLIP_UNINSTALL_YES:-}" == "1" ]] || die "非交互卸载请设置 PAPERCLIP_UNINSTALL_YES=1"
  fi
  local hp ap
  hp="$(cd "$HOME" && pwd -P)"
  ap="$(cd "${PAPERCLIP_SERVICE_HOME}" 2>/dev/null && pwd -P)" || ap="${PAPERCLIP_SERVICE_HOME}"
  if [[ "$ap" == "/" || "$ap" == "$hp" ]]; then
    die "拒绝删除根目录或 \$HOME"
  fi
  rm -rf "${PAPERCLIP_SERVICE_HOME}"
  echo "已删除 ${PAPERCLIP_SERVICE_HOME}（上游数据目录 ~/.paperclip 需自行清理）"
}

dispatch() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    install) cmd_install ;;
    update) cmd_update ;;
    onboard) cmd_onboard "$@" ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) cmd_status ;;
    uninstall) cmd_uninstall ;;
    help | -h | --help) usage ;;
    *)
      echo "未知命令: ${cmd}" >&2
      usage >&2
      exit 2
      ;;
  esac
}

interactive_main() {
  gum style --bold --foreground 212 "Paperclip 本地服务（源码: paperclipai/paperclip）"
  gum style "PAPERCLIP_SRC=${PAPERCLIP_SRC}"
  echo ""
  set +e
  while true; do
    local pick
    pick="$(gum choose --header "选择操作（取消退出）" \
      "install" "update" "onboard" "start" "stop" "restart" "status" "uninstall" "help" "quit")" || break
    [[ -z "$pick" ]] && break
    case "$pick" in
      quit) break ;;
      help) usage; continue ;;
    esac
    ( dispatch "$pick" )
    echo ""
  done
  set -e
}

main() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      help | -h | --help)
        dispatch "$@"
        return 0
        ;;
    esac
  fi
  _nlt_ensure_gum || exit 1
  if [[ $# -eq 0 ]]; then
    interactive_main
    return 0
  fi
  dispatch "$@"
}

main "$@"
