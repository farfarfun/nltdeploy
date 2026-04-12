#!/usr/bin/env bash
# nlt-services：服务总览（原 nlt-services-status）与各模块安装入口聚合。
#
# 用法:
#   nlt-services                    # gum：status / install / help / quit
#   nlt-services status [--no-http]
#   nlt-services install [名称]     # 无参 gum；名称见下方
#   nlt-services help
#
# install 名称: airflow, celery, paperclip, code-server, new-api,
#              pip-sources, python-env, utils, github-net
#
# NONINTERACTIVE=1 且无参数时打印 help 并退出（不进入 gum）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib/nlt-common.sh
source "${SCRIPT_DIR}/../_lib/nlt-common.sh"

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
NLT_BIN="${NLTDEPLOY_ROOT}/bin"

die() { echo "错误: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: nlt-services [command [args...]]

  无参数：gum 菜单（status / install / help / quit）。

命令:
  status [--no-http]    汇总 Airflow、Celery、Paperclip、code-server、new-api（PID、端口、可选 HTTP 探测）
  install [名称]        调用对应 nlt-* 安装或交互入口；无参时 gum 选择。
                        名称: airflow, celery, paperclip, code-server, new-api,
                              pip-sources, python-env, utils, github-net
  help / -h / --help    本说明

说明:
  - status 与各域默认路径、环境变量一致，详见各服务脚本头部。
  - pip-sources / python-env / utils / github-net 无统一守护进程，status 中仅文末提示。
EOF
}

usage_status() {
  cat <<'EOF'
用法: nlt-services status [--no-http]

  --no-http   跳过 curl 探测。
EOF
}

# ---- status 实现（DO_HTTP 由 cmd_status 设置）----
DO_HTTP=1

read_pid_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo ""; return; }
  tr -d '[:space:]' <"$f" || true
}

proc_alive() {
  [[ -n "${1:-}" ]] && kill -0 "$1" 2>/dev/null
}

status_word() {
  if proc_alive "$1"; then
    echo "运行中"
  else
    echo "未运行"
  fi
}

http_probe() {
  local url="$1"
  if [[ "$DO_HTTP" != "1" ]]; then
    echo "（已跳过）"
    return
  fi
  command -v curl >/dev/null 2>&1 || { echo "（无 curl）"; return; }
  local code
  code="$(curl -sS -m 2 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ -n "$code" ]]; then
    echo "HTTP ${code}"
  else
    echo "（无响应）"
  fi
}

section() {
  echo ""
  echo "── $* ──"
}

cmd_status() {
  DO_HTTP=1
  local a
  for a in "$@"; do
    case "$a" in
      -h | --help | help)
        usage_status
        exit 0
        ;;
      --no-http) DO_HTTP=0 ;;
      *)
        echo "未知参数: $a（nlt-services status --help）" >&2
        exit 2
        ;;
    esac
  done

  AIRFLOW_HOME="${AIRFLOW_HOME:-${HOME}/opt/airflow}"
  AIRFLOW_PID_FILE="${AIRFLOW_HOME}/run/standalone.pid"
  DEFAULT_AIRFLOW_PORT="8806"
  AIRFLOW_PORT="${AIRFLOW__WEBSERVER__WEB_SERVER_PORT:-$DEFAULT_AIRFLOW_PORT}"
  airflow_pid="$(read_pid_file "$AIRFLOW_PID_FILE")"

  CELERY_HOME="${CELERY_HOME:-${HOME}/opt/celery}"
  CELERY_RUN="${CELERY_HOME}/run"
  FLOWER_PORT="${FLOWER_PORT:-8806}"
  FLOWER_ADDRESS="${FLOWER_ADDRESS:-0.0.0.0}"
  pid_cel_w="$(read_pid_file "${CELERY_RUN}/worker.pid")"
  pid_cel_b="$(read_pid_file "${CELERY_RUN}/beat.pid")"
  pid_cel_f="$(read_pid_file "${CELERY_RUN}/flower.pid")"

  PAPERCLIP_SERVICE_HOME="${PAPERCLIP_SERVICE_HOME:-${HOME}/opt/paperclip}"
  PAPERCLIP_PORT="${PAPERCLIP_PORT:-3100}"
  pid_pc="$(read_pid_file "${PAPERCLIP_SERVICE_HOME}/run/paperclip.pid")"

  CODE_SERVER_SERVICE_HOME="${CODE_SERVER_SERVICE_HOME:-${HOME}/opt/code-server}"
  CODE_SERVER_BIND="${CODE_SERVER_BIND:-127.0.0.1:8080}"
  CODE_SERVER_PORT="${CODE_SERVER_PORT:-${CODE_SERVER_BIND##*:}}"
  pid_cs="$(read_pid_file "${CODE_SERVER_SERVICE_HOME}/run/code-server.pid")"

  NEW_API_SERVICE_HOME="${NEW_API_SERVICE_HOME:-${HOME}/opt/new-api}"
  NEW_API_PORT="${NEW_API_PORT:-3000}"
  pid_na="$(read_pid_file "${NEW_API_SERVICE_HOME}/run/new-api.pid")"

  echo "nltdeploy 服务概览（PID / 端口 / 地址）"
  echo "时间: $(date '+%Y-%m-%d %H:%M:%S %z')"

  section "Airflow 3（standalone）"
  echo "  名称:     Airflow standalone"
  echo "  安装:     ${AIRFLOW_HOME}"
  echo "  PID 文件: ${AIRFLOW_PID_FILE}"
  echo "  进程:     $(status_word "$airflow_pid")  ${airflow_pid:--}"
  echo "  端口:     ${AIRFLOW_PORT}（环境变量 AIRFLOW__WEBSERVER__WEB_SERVER_PORT）"
  echo "  地址:     http://127.0.0.1:${AIRFLOW_PORT}/"
  echo "  探测:     $(http_probe "http://127.0.0.1:${AIRFLOW_PORT}/")"
  echo "  详情:     nlt-airflow status"

  section "Celery（worker / beat / flower）"
  echo "  名称:     Celery"
  echo "  安装:     ${CELERY_HOME}"
  echo "  提示:     Flower 默认端口与 Airflow Web 相同（8806）；并行部署时请设置 FLOWER_PORT"
  echo "  worker:   $(status_word "$pid_cel_w")  PID ${pid_cel_w:--}"
  echo "  beat:     $(status_word "$pid_cel_b")  PID ${pid_cel_b:--}"
  echo "  flower:   $(status_word "$pid_cel_f")  PID ${pid_cel_f:--}  端口 ${FLOWER_PORT}  监听 ${FLOWER_ADDRESS}"
  if [[ "$FLOWER_ADDRESS" == "0.0.0.0" ]]; then
    echo "  Flower URL: http://127.0.0.1:${FLOWER_PORT}/"
    echo "  探测:       $(http_probe "http://127.0.0.1:${FLOWER_PORT}/")"
  else
    echo "  Flower URL: http://${FLOWER_ADDRESS}:${FLOWER_PORT}/"
    echo "  探测:       $(http_probe "http://${FLOWER_ADDRESS}:${FLOWER_PORT}/")"
  fi
  echo "  详情:       nlt-service-celery-status"

  section "Paperclip"
  echo "  名称:     Paperclip"
  echo "  安装:     ${PAPERCLIP_SERVICE_HOME}"
  echo "  进程:     $(status_word "$pid_pc")  ${pid_pc:--}"
  echo "  端口:     ${PAPERCLIP_PORT}（PAPERCLIP_PORT）"
  echo "  健康检查: http://127.0.0.1:${PAPERCLIP_PORT}/api/health"
  echo "  探测:     $(http_probe "http://127.0.0.1:${PAPERCLIP_PORT}/api/health")"
  echo "  详情:     nlt-paperclip status"

  section "code-server"
  echo "  名称:     code-server"
  echo "  安装:     ${CODE_SERVER_SERVICE_HOME}"
  echo "  进程:     $(status_word "$pid_cs")  ${pid_cs:--}"
  echo "  绑定:     ${CODE_SERVER_BIND}（CODE_SERVER_BIND）"
  echo "  探测 URL: http://127.0.0.1:${CODE_SERVER_PORT}/"
  echo "  探测:     $(http_probe "http://127.0.0.1:${CODE_SERVER_PORT}/")"
  echo "  详情:     nlt-code-server status"

  section "new-api"
  echo "  名称:     new-api（QuantumNous/new-api）"
  echo "  安装:     ${NEW_API_SERVICE_HOME}"
  echo "  进程:     $(status_word "$pid_na")  ${pid_na:--}"
  echo "  端口:     ${NEW_API_PORT}（NEW_API_PORT / PORT）"
  echo "  地址:     http://127.0.0.1:${NEW_API_PORT}/"
  echo "  探测:     $(http_probe "http://127.0.0.1:${NEW_API_PORT}/")"
  echo "  详情:     nlt-new-api status"

  section "工具（无统一守护进程）"
  echo "  nlt-pip-sources / nlt-python-env / nlt-utils / nlt-github-net"
  echo "  请使用各命令的 install、status（若有）等子命令单独查看。"

  echo ""
}

cmd_install() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
      die "NONINTERACTIVE=1 时请指定目标，例如: nlt-services install airflow"
    fi
    _nlt_ensure_gum || exit 1
    name="$(gum choose --header "选择安装 / 初始化入口" \
      "airflow" \
      "celery" \
      "paperclip" \
      "code-server" \
      "new-api" \
      "pip-sources" \
      "python-env" \
      "utils" \
      "github-net" \
      "cancel")" || return 0
    [[ -z "$name" || "$name" == "cancel" ]] && return 0
  fi

  [[ -d "$NLT_BIN" ]] || die "未找到 ${NLT_BIN}，请先执行 install.sh"

  case "$name" in
    airflow) exec "${NLT_BIN}/nlt-airflow-install" ;;
    celery) exec "${NLT_BIN}/nlt-celery-install" ;;
    paperclip) exec "${NLT_BIN}/nlt-paperclip-install" ;;
    code-server) exec "${NLT_BIN}/nlt-code-server-install" ;;
    new-api) exec "${NLT_BIN}/nlt-new-api-install" ;;
    pip-sources) exec "${NLT_BIN}/nlt-pip-sources" ;;
    python-env) exec "${NLT_BIN}/nlt-python-env" ;;
    utils) exec "${NLT_BIN}/nlt-utils" ;;
    github-net) exec "${NLT_BIN}/nlt-github-net" ;;
    *)
      die "未知 install 目标: ${name}（见 nlt-services help）"
      ;;
  esac
}

interactive_main() {
  _nlt_ensure_gum || exit 1
  set +e
  while true; do
    local pick
    pick="$(gum choose --header "nlt-services" \
      "status" "install" "help" "quit")" || break
    [[ -z "$pick" ]] && break
    case "$pick" in
      quit) break ;;
      help) usage; echo "" ;;
      status) cmd_status ;;
      install) cmd_install ;;
    esac
    echo ""
  done
  set -e
}

main() {
  if [[ $# -eq 0 ]]; then
    if [[ "${NONINTERACTIVE:-}" == "1" ]]; then
      usage >&2
      exit 1
    fi
    interactive_main
    return 0
  fi

  case "$1" in
    status)
      shift
      cmd_status "$@"
      ;;
    install)
      shift
      cmd_install "$@"
      ;;
    help | -h | --help)
      usage
      ;;
    *)
      echo "未知命令: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
