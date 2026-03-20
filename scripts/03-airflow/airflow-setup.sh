#!/usr/bin/env bash
# 本机 Apache Airflow 3.x：安装、启停、DAG 脚手架与常用 CLI 封装（仅 3.x，不兼容 2.x）。
# 与脚本所在仓库/业务无关，可置于任意目录单独使用。
# 默认将 AIRFLOW_HOME 设为 ~/opt/airflow/（见 resolve_airflow_home）；也可用 AIRFLOW_LOCAL_USE_REPO_HOME 使用脚本旁 .airflow-local。
# install 会安装核心 + apache-airflow-providers-fab（FAB），并执行 airflow fab-db migrate。
#
# 用法：
#   chmod +x airflow-local.sh
#   ./airflow-local.sh              # 无参数：菜单选择或输入命令名
#   ./airflow-local.sh install
#   ./airflow-local.sh start
#   ./airflow-local.sh status
#   ./airflow-local.sh dag-scaffold
#   ./airflow-local.sh dags-list
#   ./airflow-local.sh trigger example_minimal
#   ./airflow-local.sh users-create              # 交互式（或传参同 airflow users create）
#   ./airflow-local.sh users-list                # 列举用户（同 airflow users list）
#   ./airflow-local.sh users-reset-password      # 重置密码（同 airflow users reset-password）
#   ./airflow-local.sh http-trigger <dag_id> [payload.json]   # HTTP 触发 DAG（见下「HTTP 触发」）
#   ./airflow-local.sh stop
#
# HTTP 触发 DAG（Airflow 3 稳定 API，供其它系统调用；详见官方 Public API）：
#   文档: https://airflow.apache.org/docs/apache-airflow/stable/security/api.html
#        https://airflow.apache.org/docs/apache-airflow/stable/stable-rest-api-ref.html
#   1) 取 JWT:  POST {BASE}/auth/token  Content-Type: application/json
#              body: {"username":"...","password":"..."}
#              响应: {"access_token":"..."}
#   2) 触发运行: POST {BASE}/api/v2/dags/{dag_id}/dagRuns  Authorization: Bearer <token>
#              body 示例: {"conf":{"argv":["--date","2025-01-01"],"script":"/path/to/job.py"}}
#   本脚本封装: 设置 AIRFLOW_API_USERNAME / AIRFLOW_API_PASSWORD，可选 AIRFLOW_API_BASE（默认 http://127.0.0.1:8080）
#              执行 http-trigger；payload.json 缺省则用 {"conf":{}}。
#
# 环境变量：
#   AIRFLOW_HOME              覆盖 Airflow 家目录（未设置且未启用「同目录 home」时默认 ~/opt/airflow）
#   AIRFLOW_VENV              虚拟环境路径（默认 ${AIRFLOW_HOME}/venv）
#   AIRFLOW_VERSION           Airflow 版本（默认与下方 DEFAULT_AIRFLOW_VERSION 一致）
#   AIRFLOW_LOCAL_USE_REPO_HOME=1  使用脚本所在目录下的 .airflow-local 作为默认 AIRFLOW_HOME
#
# Airflow 3 默认 SimpleAuthManager，不会注册 airflow users。本脚本在 venv 内已安装 FAB 提供方时，
# 会自动 export AIRFLOW__CORE__AUTH_MANAGER=FabAuthManager（可被你在环境中显式覆盖）。
#   AIRFLOW_ADMIN_USER        与下面两项同时设置时，install 会尝试 airflow users create（需 FAB 包与配置）
#   AIRFLOW_ADMIN_PASSWORD
#   AIRFLOW_ADMIN_EMAIL
#   AIRFLOW_API_BASE          http-trigger 用，API 根 URL（默认 http://127.0.0.1:8080）
#   AIRFLOW_API_USERNAME      http-trigger 用，与 AIRFLOW_API_PASSWORD 一起换 JWT
#   AIRFLOW_API_PASSWORD
#
# 官方文档：https://airflow.apache.org/docs/apache-airflow/stable/

set -euo pipefail

DEFAULT_AIRFLOW_VERSION="3.1.8"
AIRFLOW_VERSION="${AIRFLOW_VERSION:-$DEFAULT_AIRFLOW_VERSION}"

# Airflow 3：users / roles 等 CLI 仅在 FabAuthManager 下注册（需已安装 apache-airflow-providers-fab）
FAB_AUTH_MANAGER_CLASS="airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
用法: ./airflow-local.sh [command [args...]]
  不传参数时进入菜单交互：输入序号或命令名（提示符 airflow-local> ）。

命令:
  install          创建 venv；用官方 constraints 安装 Airflow 核心 + FAB 提供方；db migrate + fab-db migrate
  start            后台启动 airflow standalone（写入 run/standalone.pid）
  stop             停止 standalone 进程组
  restart          stop 后 start
  status           显示 PID 与进程状态；尝试 airflow jobs check
  dag-scaffold     在 dags/ 下生成 example_minimal DAG（已存在则跳过）
  dags-list        airflow dags list
  trigger <id>     airflow dags trigger（dag_id 后参数原样透传，如 --conf '{"a":1}'）
  http-trigger     用 HTTP+JWT 触发 DAG：需 AIRFLOW_API_*；见脚本头部「HTTP 触发」
  task-test <...>  透传参数到 airflow tasks test（见官方文档）
  users-create     创建登录用户：无参数=交互问答；有参数=透传 airflow users create（需 FAB）
  users-list       列举用户（airflow users list；需 FAB + FabAuthManager，脚本在已装 fab 的 venv 内会自动设置）
  users-reset-password  重置用户密码：无参数=交互；有参数=透传 airflow users reset-password
  help             显示本说明

交互模式: 显示数字菜单；0=帮助 q=退出 ?=帮助；10/11/12/13 见菜单；13=http-trigger（需先 export AIRFLOW_API_USERNAME 与 PASSWORD）。
  8、9 可带参数: 8 <dag_id>  或  9 <dag_id> <task_id> <logical_date> …

环境变量见脚本头部注释。
USAGE
}

resolve_airflow_home() {
  if [[ -n "${AIRFLOW_HOME:-}" ]]; then
    printf '%s' "$AIRFLOW_HOME"
    return
  fi
  if [[ "${AIRFLOW_LOCAL_USE_REPO_HOME:-0}" == "1" ]]; then
    printf '%s' "${SCRIPT_DIR}/.airflow-local"
    return
  fi
  printf '%s' "${HOME}/opt/airflow"
}

export AIRFLOW_HOME="$(resolve_airflow_home)"
AIRFLOW_VENV="${AIRFLOW_VENV:-${AIRFLOW_HOME}/venv}"
RUN_DIR="${AIRFLOW_HOME}/run"
LOG_DIR="${AIRFLOW_HOME}/logs"
DAG_DIR="${AIRFLOW_HOME}/dags"
PID_FILE="${RUN_DIR}/standalone.pid"

ensure_dirs() {
  mkdir -p "$RUN_DIR" "$LOG_DIR" "$DAG_DIR"
}

require_python() {
  if ! command -v python3 &>/dev/null; then
    echo "未找到 python3，请先安装 Python 3.10+（Airflow 3.1+ 要求 3.10–3.13）。" >&2
    exit 1
  fi
  local major minor
  major="$(python3 -c 'import sys; print(sys.version_info[0])')"
  minor="$(python3 -c 'import sys; print(sys.version_info[1])')"
  if (( major < 3 || (major == 3 && minor < 10) )); then
    echo "当前 Python 版本为 ${major}.${minor}，需要 >= 3.10（参见官方 Prerequisites）。" >&2
    exit 1
  fi
  echo "使用 Python: $(python3 --version)"
}

constraint_url() {
  local py_minor
  py_minor="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  printf 'https://raw.githubusercontent.com/apache/airflow/constraints-%s/constraints-%s.txt' \
    "$AIRFLOW_VERSION" "$py_minor"
}

activate_venv() {
  # shellcheck source=/dev/null
  source "${AIRFLOW_VENV}/bin/activate"
  export AIRFLOW_HOME
  # 已装 FAB 提供方时切换为 FabAuthManager，否则 airflow users 在 Airflow 3 中不会出现
  if [[ -x "${AIRFLOW_VENV}/bin/python" ]] &&
    "${AIRFLOW_VENV}/bin/python" -c "import airflow.providers.fab" 2>/dev/null; then
    export AIRFLOW__CORE__AUTH_MANAGER="${AIRFLOW__CORE__AUTH_MANAGER:-$FAB_AUTH_MANAGER_CLASS}"
  fi
}

require_venv_airflow() {
  if [[ ! -x "${AIRFLOW_VENV}/bin/airflow" ]]; then
    echo "未找到 ${AIRFLOW_VENV}/bin/airflow，请先运行: $0 install" >&2
    exit 1
  fi
}

# airflow users 需：apache-airflow-providers-fab + FabAuthManager（Airflow 3 默认 SimpleAuthManager）
require_airflow_users_cli() {
  activate_venv
  if ! "${AIRFLOW_VENV}/bin/pip" show apache-airflow-providers-fab &>/dev/null; then
    echo "未安装 apache-airflow-providers-fab。" >&2
    echo "  venv: ${AIRFLOW_VENV}" >&2
    echo "请运行: $0 install" >&2
    exit 1
  fi
  if ! airflow users list --help &>/dev/null; then
    echo "FAB 已安装，但「airflow users」仍不可用。" >&2
    echo "  AIRFLOW_HOME=${AIRFLOW_HOME}" >&2
    echo "  AIRFLOW__CORE__AUTH_MANAGER=${AIRFLOW__CORE__AUTH_MANAGER:-（未设置，脚本会在激活 venv 且已装 fab 时设为 FabAuthManager）}" >&2
    echo "请自检: airflow users list --help" >&2
    exit 1
  fi
}

cmd_install() {
  require_python
  ensure_dirs
  echo "AIRFLOW_HOME=${AIRFLOW_HOME}"
  echo "AIRFLOW_VENV=${AIRFLOW_VENV}"
  if [[ ! -d "$AIRFLOW_VENV" ]]; then
    echo "==> 创建虚拟环境..."
    python3 -m venv "$AIRFLOW_VENV"
  fi
  activate_venv
  local curl_url
  curl_url="$(constraint_url)"
  echo "==> 升级 pip..."
  pip install --upgrade pip
  echo "==> 安装 Airflow 核心 + FAB（apache-airflow + apache-airflow-providers-fab，同一 constraints）..."
  pip install \
    "apache-airflow==${AIRFLOW_VERSION}" \
    "apache-airflow-providers-fab" \
    --constraint "${curl_url}"
  # 安装 FAB 后需再次激活环境变量（含 AIRFLOW__CORE__AUTH_MANAGER），否则 db migrate / users 仍按默认 SimpleAuthManager
  activate_venv
  echo "==> 数据库迁移（Airflow 核心）..."
  airflow db migrate
  echo "==> FAB 元数据迁移（用户/角色表，供 users-list / users-create）..."
  if airflow fab-db migrate; then
    :
  else
    echo "警告: airflow fab-db migrate 未成功，用户相关命令可能异常；请查看上方报错。" >&2
  fi
  if [[ -n "${AIRFLOW_ADMIN_USER:-}" && -n "${AIRFLOW_ADMIN_PASSWORD:-}" && -n "${AIRFLOW_ADMIN_EMAIL:-}" ]]; then
    echo "==> 创建管理员用户（需 FAB 与 auth 配置；失败可改用 standalone 打印的账号）..."
    airflow users create \
      --username "$AIRFLOW_ADMIN_USER" \
      --firstname Admin \
      --lastname User \
      --role Admin \
      --email "$AIRFLOW_ADMIN_EMAIL" \
      --password "$AIRFLOW_ADMIN_PASSWORD" || {
      echo "警告: airflow users create 失败。可依赖 standalone 首次启动时在终端打印的账号。" >&2
    }
  fi
  echo "安装完成。下一步: $0 start"
}

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

cmd_start() {
  require_venv_airflow
  ensure_dirs
  local existing
  existing="$(read_pid)"
  if [[ -n "$existing" ]] && process_alive "$existing"; then
    echo "standalone 已在运行（PID ${existing}）。如需重启请执行: $0 restart" >&2
    exit 1
  fi
  activate_venv
  local log_file="${LOG_DIR}/standalone.out.log"
  echo "==> 启动 airflow standalone（日志: ${log_file}）..."
  # nohup 保留 $! 为 airflow 主进程；stop 时按进程组发送信号以清理子进程
  nohup airflow standalone >>"$log_file" 2>&1 &
  local pid=$!
  echo "$pid" >"$PID_FILE"
  echo "已写入 PID ${pid} -> ${PID_FILE}"
  echo "UI 默认 http://localhost:8080 （见 airflow.cfg）；standalone 首次运行可能在日志中打印管理员账号。"
}

cmd_stop() {
  local pid
  pid="$(read_pid)"
  if [[ -z "$pid" ]]; then
    echo "未找到 PID 文件（${PID_FILE}），视为未启动。" >&2
    rm -f "$PID_FILE"
    return 0
  fi
  if ! process_alive "$pid"; then
    echo "PID ${pid} 不存在，清理 PID 文件。"
    rm -f "$PID_FILE"
    return 0
  fi
  local pgid
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
  echo "==> 停止 standalone（PID ${pid}, PGID ${pgid:-n/a}）..."
  if [[ -n "$pgid" ]] && [[ "$pgid" =~ ^[0-9]+$ ]]; then
    kill -TERM "-${pgid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  else
    kill -TERM "$pid" 2>/dev/null || true
  fi
  local waited=0
  while process_alive "$pid" && (( waited < 30 )); do
    sleep 1
    waited=$((waited + 1))
  done
  if process_alive "$pid"; then
    echo "优雅停止超时，发送 KILL..."
    if [[ -n "$pgid" ]] && [[ "$pgid" =~ ^[0-9]+$ ]]; then
      kill -KILL "-${pgid}" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    else
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
  echo "已停止。"
}

cmd_restart() {
  cmd_stop || true
  cmd_start
}

cmd_status() {
  require_venv_airflow
  local pid
  pid="$(read_pid)"
  if [[ -z "$pid" ]]; then
    echo "PID 文件: 无"
  else
    if process_alive "$pid"; then
      echo "PID 文件: ${pid}（运行中）"
    else
      echo "PID 文件: ${pid}（进程不存在，可删除 ${PID_FILE} 后重新 start）"
    fi
  fi
  activate_venv
  if airflow jobs check --job-type SchedulerJob --local &>/dev/null; then
    echo "airflow jobs check (--job-type SchedulerJob --local): 通过"
  elif airflow jobs check &>/dev/null; then
    echo "airflow jobs check: 通过"
  else
    echo "airflow jobs check: 不可用或未就绪（standalone 启动后稍等再试）"
  fi
}

cmd_dag_scaffold() {
  ensure_dirs
  local target="${DAG_DIR}/example_minimal.py"
  if [[ -f "$target" ]]; then
    echo "已存在 ${target}，跳过。"
    return 0
  fi
  cat >"$target" <<'PY'
"""Minimal example DAG (Airflow 3.x). Generated by airflow-local.sh."""
from datetime import datetime

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

with DAG(
    dag_id="example_minimal",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["example"],
) as dag:
    BashOperator(
        task_id="hello",
        bash_command="echo 'hello from example_minimal'",
    )
PY
  echo "已写入 ${target}"
}

cmd_dags_list() {
  require_venv_airflow
  activate_venv
  airflow dags list
}

cmd_trigger() {
  require_venv_airflow
  local dag_id="${1:-}"
  if [[ -z "$dag_id" ]]; then
    echo "用法: $0 trigger <dag_id> [传给 airflow dags trigger 的其它参数…]" >&2
    echo "示例: $0 trigger my_dag --conf '{\"k\":1}'" >&2
    exit 2
  fi
  shift
  activate_venv
  airflow dags trigger "$dag_id" "$@"
}

cmd_task_test() {
  require_venv_airflow
  if [[ $# -lt 1 ]]; then
    echo "用法: $0 task-test <dag_id> <task_id> <logical_date> [其他 airflow tasks test 参数]" >&2
    echo "示例: $0 task-test example_minimal hello 2024-01-01" >&2
    exit 2
  fi
  activate_venv
  airflow tasks test "$@"
}

cmd_users_create() {
  require_venv_airflow
  activate_venv
  require_airflow_users_cli
  if [[ $# -gt 0 ]]; then
    airflow users create "$@"
    return
  fi
  echo "==> 创建用户（需启用 Flask AppBuilder 认证管理器；否则命令会失败，见官方 Quick Start 说明）"
  local u p p2 e fn ln role
  read -r -e -p "用户名 username [admin]: " u || return 1
  u="${u:-admin}"
  read -r -s -p "密码 password: " p || return 1
  echo ""
  read -r -s -p "确认密码: " p2 || return 1
  echo ""
  if [[ "$p" != "$p2" ]]; then
    echo "两次密码不一致。" >&2
    exit 1
  fi
  read -r -e -p "邮箱 email: " e || return 1
  if [[ -z "${e//[$' \t']/}" ]]; then
    echo "邮箱不能为空。" >&2
    exit 1
  fi
  read -r -e -p "名 firstname [Admin]: " fn || return 1
  fn="${fn:-Admin}"
  read -r -e -p "姓 lastname [User]: " ln || return 1
  ln="${ln:-User}"
  read -r -e -p "角色 role [Admin]（如 Admin / User / Op / Viewer）: " role || return 1
  role="${role:-Admin}"
  airflow users create \
    --username "$u" \
    --firstname "$fn" \
    --lastname "$ln" \
    --role "$role" \
    --email "$e" \
    --password "$p"
}

cmd_users_list() {
  require_venv_airflow
  activate_venv
  require_airflow_users_cli
  airflow users list "$@"
}

cmd_users_reset_password() {
  require_venv_airflow
  activate_venv
  require_airflow_users_cli
  if [[ $# -gt 0 ]]; then
    airflow users reset-password "$@"
    return
  fi
  echo "==> 重置用户密码（airflow users reset-password）"
  local u p p2
  read -r -e -p "用户名 username [admin]: " u || return 1
  u="${u:-admin}"
  read -r -s -p "新密码: " p || return 1
  echo ""
  read -r -s -p "确认新密码: " p2 || return 1
  echo ""
  if [[ "$p" != "$p2" ]]; then
    echo "两次密码不一致。" >&2
    exit 1
  fi
  airflow users reset-password --username "$u" --password "$p"
}

cmd_http_trigger() {
  command -v curl &>/dev/null || {
    echo "http-trigger 需要系统命令 curl。" >&2
    exit 1
  }
  command -v python3 &>/dev/null || {
    echo "http-trigger 需要 python3（解析 JSON / 编码 URL）。" >&2
    exit 1
  }
  local base="${AIRFLOW_API_BASE:-http://127.0.0.1:8080}"
  base="${base%/}"
  local dag_id="${1:-}"
  local payload_path="${2:-}"
  if [[ -z "$dag_id" ]]; then
    echo "用法: $0 http-trigger <dag_id> [payload.json]" >&2
    echo "环境变量: AIRFLOW_API_USERNAME, AIRFLOW_API_PASSWORD（必填）" >&2
    echo "          AIRFLOW_API_BASE（可选，当前: ${base}）" >&2
    echo "payload.json 缺省则发送 {\"conf\":{}}；conf 内放本次作业参数即可。" >&2
    exit 2
  fi
  if [[ -z "${AIRFLOW_API_USERNAME:-}" || -z "${AIRFLOW_API_PASSWORD:-}" ]]; then
    echo "请设置 AIRFLOW_API_USERNAME 与 AIRFLOW_API_PASSWORD。" >&2
    exit 1
  fi
  local creds_json resp token payload enc_dag
  creds_json="$(
    AIRFLOW_API_USERNAME="$AIRFLOW_API_USERNAME" AIRFLOW_API_PASSWORD="$AIRFLOW_API_PASSWORD" \
      python3 -c 'import json, os; print(json.dumps({"username": os.environ["AIRFLOW_API_USERNAME"], "password": os.environ["AIRFLOW_API_PASSWORD"]}))'
  )"
  if ! resp="$(curl -sS -X POST "${base}/auth/token" -H "Content-Type: application/json" -d "$creds_json")"; then
    echo "请求 ${base}/auth/token 失败。" >&2
    exit 1
  fi
  if ! token="$(printf '%s' "$resp" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"; then
    echo "解析 access_token 失败，响应: $resp" >&2
    exit 1
  fi
  if [[ -n "$payload_path" ]]; then
    if [[ ! -f "$payload_path" ]]; then
      echo "找不到 payload 文件: $payload_path" >&2
      exit 1
    fi
    payload="$(cat "$payload_path")"
  else
    payload='{"conf":{}}'
  fi
  enc_dag="$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$dag_id")"
  echo "==> POST ${base}/api/v2/dags/${dag_id}/dagRuns"
  curl -sS -X POST "${base}/api/v2/dags/${enc_dag}/dagRuns" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$payload"
  echo ""
}

dispatch() {
  local cmd="$1"
  shift || true
  case "$cmd" in
    install) cmd_install ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) cmd_status ;;
    dag-scaffold) cmd_dag_scaffold ;;
    dags-list) cmd_dags_list ;;
    trigger) cmd_trigger "$@" ;;
    task-test) cmd_task_test "$@" ;;
    users-create) cmd_users_create "$@" ;;
    users-list) cmd_users_list "$@" ;;
    users-reset-password) cmd_users_reset_password "$@" ;;
    http-trigger) cmd_http_trigger "$@" ;;
    help|-h|--help) usage ;;
    *)
      echo "未知命令: ${cmd}" >&2
      usage >&2
      exit 2
      ;;
  esac
}

print_interactive_menu() {
  cat <<'MENU'

-------- Airflow 本地菜单（输入序号或命令名）--------
  1 install       2 start         3 stop          4 restart
  5 status        6 dag-scaffold  7 dags-list     8 trigger
  9 task-test     10 users-create  11 users-list
  12 users-reset-password           13 http-trigger
  0 完整帮助      q 退出
  同序带参: 8 <dag_id> …   9 …   13 <dag_id> [payload.json] 需 export AIRFLOW_API_USERNAME/PASSWORD
------------------------------------------------------
MENU
}

interactive_main() {
  echo "--- Airflow 本地交互模式 ---"
  echo "AIRFLOW_HOME=${AIRFLOW_HOME}"
  echo ""
  local line
  set +e
  while true; do
    print_interactive_menu
    if ! IFS= read -r -e -p "airflow-local> " line; then
      printf '\n'
      break
    fi
    [[ -z "${line//[$' \t']/}" ]] && continue
    local args
    read -ra args <<<"$line"
    local icmd="${args[0]}"

    # 数字序号（菜单）
    if [[ "$icmd" =~ ^[0-9]+$ ]]; then
      case "$icmd" in
        0) usage; continue ;;
        10) ( dispatch users-create ); continue ;;
        11) ( dispatch users-list "${args[@]:1}" ); continue ;;
        12) ( dispatch users-reset-password "${args[@]:1}" ); continue ;;
        13)
          if [[ -z "${AIRFLOW_API_USERNAME:-}" || -z "${AIRFLOW_API_PASSWORD:-}" ]]; then
            echo "菜单 13 需先: export AIRFLOW_API_USERNAME=… AIRFLOW_API_PASSWORD=…" >&2
            continue
          fi
          if (( ${#args[@]} >= 2 )); then
            ( dispatch http-trigger "${args[1]}" "${args[2]:-}" )
          else
            local hid=""
            if ! IFS= read -r -e -p "  dag_id: " hid; then
              printf '\n'
              break
            fi
            [[ -n "${hid//[$' \t']/}" ]] && ( dispatch http-trigger "$hid" ) || echo "已跳过"
          fi
          continue ;;
        1) ( dispatch install ); continue ;;
        2) ( dispatch start ); continue ;;
        3) ( dispatch stop ); continue ;;
        4) ( dispatch restart ); continue ;;
        5) ( dispatch status ); continue ;;
        6) ( dispatch dag-scaffold ); continue ;;
        7) ( dispatch dags-list ); continue ;;
        8)
          if (( ${#args[@]} >= 2 )); then
            ( dispatch trigger "${args[1]}" "${args[@]:2}" )
          else
            local tid=""
            if ! IFS= read -r -e -p "  dag_id: " tid; then
              printf '\n'
              break
            fi
            [[ -n "${tid//[$' \t']/}" ]] && ( dispatch trigger "$tid" ) || echo "已跳过（未输入 dag_id）"
          fi
          continue ;;
        9)
          if (( ${#args[@]} >= 2 )); then
            local rest9=()
            local j
            for ((j = 1; j < ${#args[@]}; j++)); do
              rest9+=("${args[j]}")
            done
            ( dispatch task-test "${rest9[@]}" )
          else
            local tline=""
            if ! IFS= read -r -e -p "  task-test 参数（dag_id task_id logical_date …）: " tline; then
              printf '\n'
              break
            fi
            local ta=()
            read -ra ta <<<"$tline"
            ( dispatch task-test "${ta[@]}" )
          fi
          continue ;;
        *)
          echo "无效序号（1–9、10–13 或 0）。输入 0 查看帮助。" >&2
          continue ;;
      esac
    fi

    case "$icmd" in
      quit|exit|q) break ;;
      '?'|help|-h|--help) usage; continue ;;
    esac
    local rest=()
    local i
    for ((i = 1; i < ${#args[@]}; i++)); do
      rest+=("${args[i]}")
    done
    # 子 shell：子命令里的 exit 不会结束交互会话
    ( dispatch "$icmd" "${rest[@]}" )
  done
  set -e
}

main() {
  if [[ $# -eq 0 ]]; then
    interactive_main
    return 0
  fi
  dispatch "$@"
}

main "$@"
