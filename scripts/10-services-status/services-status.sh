#!/usr/bin/env bash
# 汇总 nltdeploy 管理的常驻服务：进程（PID）、默认端口、HTTP 探测（可选）。
# 与各域脚本使用相同默认路径与环境变量名；若启动服务时改过环境变量，查看本脚本前请 export 相同变量。
#
# 用法:
#   nlt-services-status           # 默认尝试 HTTP 探测（需 curl）
#   nlt-services-status --no-http # 仅 PID / 端口信息
#   nlt-services-status help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_lib/nlt-common.sh
source "${SCRIPT_DIR}/../_lib/nlt-common.sh"

DO_HTTP=1
for a in "$@"; do
  case "$a" in
    -h | --help | help)
      cat <<'EOF'
用法: nlt-services-status [--no-http]

  汇总 Airflow、Celery、Paperclip、code-server、new-api 的运行情况（PID、端口、URL）。
  --no-http   跳过 curl 探测（更快、无网络栈依赖）。

说明:
  - 端口列为「默认或当前环境变量」；Airflow 实际端口以 airflow.cfg 为准时可能不同。
  - pip-sources / python-env / utils / github-net 为工具脚本，无统一守护进程，不列入下表。
EOF
      exit 0
      ;;
    --no-http) DO_HTTP=0 ;;
    *)
      echo "未知参数: $a（使用 help 查看用法）" >&2
      exit 2
      ;;
  esac
done

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

# --- Airflow（与 scripts/03-airflow/deploy.sh 一致）---
AIRFLOW_HOME="${AIRFLOW_HOME:-${HOME}/opt/airflow}"
AIRFLOW_PID_FILE="${AIRFLOW_HOME}/run/standalone.pid"
DEFAULT_AIRFLOW_PORT="8806"
AIRFLOW_PORT="${AIRFLOW__WEBSERVER__WEB_SERVER_PORT:-$DEFAULT_AIRFLOW_PORT}"
airflow_pid="$(read_pid_file "$AIRFLOW_PID_FILE")"

# --- Celery ---
CELERY_HOME="${CELERY_HOME:-${HOME}/opt/celery}"
CELERY_RUN="${CELERY_HOME}/run"
FLOWER_PORT="${FLOWER_PORT:-8806}"
FLOWER_ADDRESS="${FLOWER_ADDRESS:-0.0.0.0}"
pid_cel_w="$(read_pid_file "${CELERY_RUN}/worker.pid")"
pid_cel_b="$(read_pid_file "${CELERY_RUN}/beat.pid")"
pid_cel_f="$(read_pid_file "${CELERY_RUN}/flower.pid")"

# --- Paperclip ---
PAPERCLIP_SERVICE_HOME="${PAPERCLIP_SERVICE_HOME:-${HOME}/opt/paperclip}"
PAPERCLIP_PORT="${PAPERCLIP_PORT:-3100}"
pid_pc="$(read_pid_file "${PAPERCLIP_SERVICE_HOME}/run/paperclip.pid")"

# --- code-server ---
CODE_SERVER_SERVICE_HOME="${CODE_SERVER_SERVICE_HOME:-${HOME}/opt/code-server}"
CODE_SERVER_BIND="${CODE_SERVER_BIND:-127.0.0.1:8080}"
CODE_SERVER_PORT="${CODE_SERVER_PORT:-${CODE_SERVER_BIND##*:}}"
pid_cs="$(read_pid_file "${CODE_SERVER_SERVICE_HOME}/run/code-server.pid")"

# --- new-api ---
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
