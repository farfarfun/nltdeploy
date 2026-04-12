#!/usr/bin/env bash
# new-api（https://github.com/QuantumNous/new-api）本机服务：从 GitHub Releases 下载预编译二进制。
#
# 依赖：curl；可选 python3（用于在「latest 无资源包」时挑选最近一条带二进制附件的 Release）。
#
# 用法：
#   ./setup.sh              # gum 菜单
#   ./setup.sh install      # 下载二进制到 ${NEW_API_SERVICE_HOME}/bin/new-api
#   ./setup.sh update       # 重新下载（同 install）
#   ./setup.sh start        # 后台启动（工作目录为数据目录，默认端口 3000）
#   ./setup.sh stop | restart | status | uninstall
#
# 环境变量：
#   NEW_API_SERVICE_HOME   安装根（默认 ~/opt/new-api），内含 bin/new-api、data/（SQLite 等工作目录）
#   NEW_API_DATA_DIR       运行时的 cwd（默认 ${NEW_API_SERVICE_HOME}/data），库文件等写在此目录
#   NEW_API_PORT / PORT    监听端口（启动时 export PORT；默认 3000，与上游一致）
#   NEW_API_VERSION        强制版本，如 0.12.6 或 v0.12.6（不设则从 Releases 解析）
#   NEW_API_GITHUB_REPO    owner/repo（默认 QuantumNous/new-api）
#   NONINTERACTIVE=1
#   NEW_API_UNINSTALL_YES=1   非 TTY 卸载确认

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 仓库内为 scripts/.../<域>/；install 同步后为 libexec/nltdeploy/<域>/（与 lib/ 同级）→ 先试 ../lib 再 ../../lib
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

NEW_API_GITHUB_REPO="${NEW_API_GITHUB_REPO:-QuantumNous/new-api}"
NEW_API_SERVICE_HOME="${NEW_API_SERVICE_HOME:-${HOME}/opt/new-api}"
NEW_API_DATA_DIR="${NEW_API_DATA_DIR:-${NEW_API_SERVICE_HOME}/data}"
NEW_API_PORT="${NEW_API_PORT:-3000}"

NEW_API_RUN_DIR="${NEW_API_SERVICE_HOME}/run"
NEW_API_LOG_DIR="${NEW_API_SERVICE_HOME}/log"
PID_FILE="${NEW_API_RUN_DIR}/new-api.pid"
LOG_FILE="${NEW_API_LOG_DIR}/new-api.log"
NEW_API_BIN="${NEW_API_SERVICE_HOME}/bin/new-api"

# 无 python3 或 API 失败时的回退 tag（须对应 Release 上存在各平台二进制）
NEW_API_FALLBACK_TAG="${NEW_API_FALLBACK_TAG:-v0.12.6}"

usage() {
  cat <<USAGE
用法: ./setup.sh [command]

  无参数：gum 菜单。

命令:
  install / update   从 GitHub Releases 下载预编译二进制到 ${NEW_API_BIN}
  start              后台启动（cwd ${NEW_API_DATA_DIR}，PORT=${NEW_API_PORT}，日志 ${LOG_FILE}）
  stop / restart / status
  uninstall          停止并删除 ${NEW_API_SERVICE_HOME}

上游: https://github.com/QuantumNous/new-api
文档: https://docs.newapi.pro/
USAGE
}

ensure_dirs() {
  mkdir -p "${NEW_API_RUN_DIR}" "${NEW_API_LOG_DIR}" "${NEW_API_DATA_DIR}"
}

die() { echo "错误: $*" >&2; exit 1; }

process_alive() {
  kill -0 "$1" 2>/dev/null
}

read_pid() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo ""
    return
  fi
  tr -d '[:space:]' <"$PID_FILE" || true
}

require_curl() {
  command -v curl >/dev/null 2>&1 || die "需要 curl"
}

# 输出平台键：linux-amd64 | linux-arm64 | darwin
_detect_platform_kind() {
  local os arch
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) die "不支持的操作系统: $(uname -s)" ;;
  esac
  if [[ "$os" == "darwin" ]]; then
    echo "darwin"
    return
  fi
  case "$(uname -m)" in
    x86_64 | amd64) echo "linux-amd64" ;;
    aarch64 | arm64) echo "linux-arm64" ;;
    *) die "不支持的架构: $(uname -m)" ;;
  esac
}

# 根据 release tag（如 v0.12.6）与平台得到 GitHub 上的资源文件名
_asset_name_for_tag() {
  local tag="$1"
  local kind ver
  kind="$(_detect_platform_kind)"
  ver="${tag#v}"
  case "$kind" in
    linux-amd64) echo "new-api-v${ver}" ;;
    linux-arm64) echo "new-api-arm64-v${ver}" ;;
    darwin) echo "new-api-macos-v${ver}" ;;
    *) die "内部错误: kind=${kind}" ;;
  esac
}

# 从 API JSON 中选出第一个包含当前平台二进制的 release tag；失败打印空
_pick_tag_from_releases_json() {
  local json="$1"
  command -v python3 >/dev/null 2>&1 || return 1
  local kind
  kind="$(_detect_platform_kind)"
  NEW_API_PLATFORM_KIND="$kind" python3 -c '
import json, os, sys
releases = json.loads(sys.stdin.read())
kind = os.environ.get("NEW_API_PLATFORM_KIND", "")

def want_name(tag: str) -> str:
    ver = tag[1:] if tag.startswith("v") else tag
    if kind == "linux-amd64":
        return f"new-api-v{ver}"
    if kind == "linux-arm64":
        return f"new-api-arm64-v{ver}"
    if kind == "darwin":
        return f"new-api-macos-v{ver}"
    raise SystemExit(1)

for r in releases:
    if r.get("draft"):
        continue
    tag = r.get("tag_name") or ""
    if not tag:
        continue
    names = {a.get("name") for a in (r.get("assets") or []) if a.get("name")}
    if not names:
        continue
    try:
        w = want_name(tag)
    except SystemExit:
        continue
    if w in names:
        print(tag)
        sys.exit(0)
sys.exit(1)
' <<<"$json"
}

_normalize_version_to_tag() {
  local v="${1:-}"
  v="${v#v}"
  [[ -n "$v" ]] || return 1
  echo "v${v}"
}

_resolve_tag() {
  if [[ -n "${NEW_API_VERSION:-}" ]]; then
    _normalize_version_to_tag "${NEW_API_VERSION}" || die "无效 NEW_API_VERSION: ${NEW_API_VERSION}"
    return
  fi
  require_curl
  local json picked
  json="$(curl -fsSL "https://api.github.com/repos/${NEW_API_GITHUB_REPO}/releases?per_page=40")" || json=""
  if [[ -n "$json" ]]; then
    picked="$(_pick_tag_from_releases_json "$json" || true)"
    if [[ -n "$picked" ]]; then
      echo "$picked"
      return
    fi
  fi
  echo "${NEW_API_FALLBACK_TAG}"
}

_download_install() {
  require_curl
  local tag asset url tmp
  tag="$(_resolve_tag)"
  asset="$(_asset_name_for_tag "$tag")"
  url="https://github.com/${NEW_API_GITHUB_REPO}/releases/download/${tag}/${asset}"
  echo "==> 下载 new-api ${tag} → ${NEW_API_BIN}" >&2
  echo "    ${url}" >&2
  tmp="$(mktemp)"
  trap 'rm -f "${tmp}"' RETURN
  curl -fsSL "$url" -o "${tmp}"
  mkdir -p "${NEW_API_SERVICE_HOME}/bin"
  install -m 0755 "${tmp}" "${NEW_API_BIN}"
  [[ -x "${NEW_API_BIN}" ]] || die "安装后二进制不可执行: ${NEW_API_BIN}"
  echo "已安装 ${NEW_API_BIN}（${tag} / ${asset}）"
}

cmd_install() {
  ensure_dirs
  _download_install
}

cmd_update() {
  ensure_dirs
  echo "==> 更新 new-api（重新下载）…" >&2
  _download_install
}

cmd_start() {
  [[ -x "${NEW_API_BIN}" ]] || die "未安装，请先: $0 install"
  ensure_dirs
  local existing
  existing="$(read_pid)"
  if [[ -n "$existing" ]] && process_alive "$existing"; then
    echo "new-api 已在运行（PID ${existing}）。重启请: $0 restart" >&2
    exit 1
  fi
  rm -f "$PID_FILE"
  echo "==> 启动 new-api，PORT=${NEW_API_PORT}，cwd ${NEW_API_DATA_DIR}，日志 ${LOG_FILE}" >&2
  pushd "${NEW_API_DATA_DIR}" >/dev/null
  # 上游 main 优先读环境变量 PORT
  nohup env PORT="${NEW_API_PORT}" "${NEW_API_BIN}" >>"${LOG_FILE}" 2>&1 &
  local cpid=$!
  echo "$cpid" >"$PID_FILE"
  popd >/dev/null
  sleep 1
  existing="$(read_pid)"
  if [[ -n "$existing" ]] && process_alive "$existing"; then
    echo "已启动 PID ${existing}（默认 http://127.0.0.1:${NEW_API_PORT}/ ）"
  else
    echo "警告: 进程可能已退出，请查看: tail -80 ${LOG_FILE}" >&2
  fi
}

cmd_stop() {
  local pid
  pid="$(read_pid)"
  if [[ -z "$pid" ]]; then
    echo "未找到 PID，视为未运行。" >&2
    rm -f "$PID_FILE"
    return 0
  fi
  if ! process_alive "$pid"; then
    rm -f "$PID_FILE"
    return 0
  fi
  if [[ "${NONINTERACTIVE:-}" != "1" ]] && [[ -t 0 ]]; then
    gum confirm "停止 new-api（PID ${pid}）？" || exit 0
  fi
  kill -TERM "$pid" 2>/dev/null || true
  local w=0
  while process_alive "$pid" && (( w < 20 )); do
    sleep 1
    w=$((w + 1))
  done
  process_alive "$pid" && kill -KILL "$pid" 2>/dev/null || true
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
  echo "NEW_API_SERVICE_HOME=${NEW_API_SERVICE_HOME}"
  echo "NEW_API_DATA_DIR=${NEW_API_DATA_DIR}"
  echo "NEW_API_PORT=${NEW_API_PORT}"
  if [[ -n "$pid" ]] && process_alive "$pid"; then
    echo "状态: 运行中 PID ${pid}"
  else
    echo "状态: 未运行"
    rm -f "$PID_FILE"
  fi
  if [[ -x "${NEW_API_BIN}" ]]; then
    echo "二进制: $("${NEW_API_BIN}" --version 2>/dev/null | head -1 || echo ok)"
  fi
  if command -v curl >/dev/null 2>&1; then
    echo ""
    echo "==> 探测 http://127.0.0.1:${NEW_API_PORT}/"
    curl -sS -m 3 -o /dev/null -w "HTTP %{http_code}\n" "http://127.0.0.1:${NEW_API_PORT}/" || echo "（无法连接）"
  fi
}

cmd_uninstall() {
  cmd_stop || true
  echo "将删除: ${NEW_API_SERVICE_HOME}" >&2
  if [[ -t 0 ]]; then
    gum confirm "确认删除？" || exit 0
  else
    [[ "${NEW_API_UNINSTALL_YES:-}" == "1" ]] || die "非交互请设 NEW_API_UNINSTALL_YES=1"
  fi
  local hp ap
  hp="$(cd "$HOME" && pwd -P)"
  ap="$(cd "${NEW_API_SERVICE_HOME}" 2>/dev/null && pwd -P)" || ap="${NEW_API_SERVICE_HOME}"
  if [[ "$ap" == "/" || "$ap" == "$hp" ]]; then
    die "拒绝删除根目录或 \$HOME"
  fi
  rm -rf "${NEW_API_SERVICE_HOME}"
  echo "已删除。"
}

dispatch() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    install) cmd_install ;;
    update) cmd_update ;;
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
  gum style --bold --foreground 212 "new-api 本地服务（QuantumNous/new-api）"
  gum style "安装目录: ${NEW_API_SERVICE_HOME}"
  gum style "数据目录: ${NEW_API_DATA_DIR}  端口: ${NEW_API_PORT}"
  echo ""
  set +e
  while true; do
    local pick
    pick="$(gum choose --header "选择操作" \
      "install" "update" "start" "stop" "restart" "status" "uninstall" "help" "quit")" || break
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
