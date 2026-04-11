#!/usr/bin/env bash
# 一键安装 nltdeploy 命令到 ~/.local/nltdeploy（可通过 NLTDEPLOY_ROOT 覆盖）。
set -euo pipefail

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
# 安装源：install.sh 所在目录为仓库根（或解压包根）。
SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="${SOURCE_ROOT}/scripts"

die() { echo "错误: $*" >&2; exit 1; }
[[ -d "$SCRIPTS" ]] || die "找不到 ${SCRIPTS}（请在仓库根或完整发布包内运行 install.sh）"

LIBEXEC="${NLTDEPLOY_ROOT}/libexec/nltdeploy"
mkdir -p "${NLTDEPLOY_ROOT}/bin" "${LIBEXEC}" \
  "${NLTDEPLOY_ROOT}/share/nltdeploy" "${NLTDEPLOY_ROOT}/etc/nltdeploy"
mkdir -p "${LIBEXEC}/pip-sources" "${LIBEXEC}/python-env" \
  "${LIBEXEC}/airflow" "${LIBEXEC}/celery" "${LIBEXEC}/utils" "${LIBEXEC}/github-net"

cp -f "${SCRIPTS}/01-configure-pip-sources/deploy.sh" "${LIBEXEC}/pip-sources/deploy.sh"
chmod 0755 "${LIBEXEC}/pip-sources/deploy.sh"

cp -f "${SCRIPTS}/02-create-python-env/deploy.sh" "${LIBEXEC}/python-env/deploy.sh"
chmod 0755 "${LIBEXEC}/python-env/deploy.sh"

cp -f "${SCRIPTS}/03-airflow/deploy.sh" "${LIBEXEC}/airflow/deploy.sh"
chmod 0755 "${LIBEXEC}/airflow/deploy.sh"

cp -f "${SCRIPTS}/04-celery/celery-setup.sh" "${LIBEXEC}/celery/celery-setup.sh"
chmod 0755 "${LIBEXEC}/celery/celery-setup.sh"

cp -f "${SCRIPTS}/05-utils/utils-setup.sh" "${LIBEXEC}/utils/utils-setup.sh"
chmod 0755 "${LIBEXEC}/utils/utils-setup.sh"

cp -f "${SCRIPTS}/06-github/deploy.sh" "${LIBEXEC}/github-net/deploy.sh"
chmod 0755 "${LIBEXEC}/github-net/deploy.sh"

# 用法: _emit_wrapper <bin 名> <libexec 内脚本相对路径> [传递给脚本的固定前缀参数...]
_emit_wrapper() {
  local name="$1"
  shift
  local rel="$1"
  shift
  local bin_path="${NLTDEPLOY_ROOT}/bin/${name}"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n' 'NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"'
    if [[ $# -gt 0 ]]; then
      printf 'exec "${NLTDEPLOY_ROOT}/libexec/nltdeploy/%s"' "$rel"
      local a
      for a in "$@"; do
        printf ' %q' "$a"
      done
      printf ' "$@"\n'
    else
      printf 'exec "${NLTDEPLOY_ROOT}/libexec/nltdeploy/%s" "$@"\n' "$rel"
    fi
  } > "${bin_path}"
  chmod 0755 "${bin_path}"
}

_emit_wrapper nlt-pip-sources pip-sources/deploy.sh
_emit_wrapper nlt-python-env python-env/deploy.sh
_emit_wrapper nlt-utils utils/utils-setup.sh
_emit_wrapper nlt-github-net github-net/deploy.sh

_emit_wrapper nlt-airflow-install airflow/deploy.sh install
_emit_wrapper nlt-airflow airflow/deploy.sh

_emit_wrapper nlt-service-airflow-start airflow/deploy.sh start
_emit_wrapper nlt-service-airflow-stop airflow/deploy.sh stop
_emit_wrapper nlt-service-airflow-restart airflow/deploy.sh restart
_emit_wrapper nlt-service-airflow-status airflow/deploy.sh status

_emit_wrapper nlt-celery-install celery/celery-setup.sh install

_emit_wrapper nlt-service-celery-worker-start celery/celery-setup.sh start-worker
_emit_wrapper nlt-service-celery-beat-start celery/celery-setup.sh start-beat
_emit_wrapper nlt-service-celery-flower-start celery/celery-setup.sh start-flower
_emit_wrapper nlt-service-celery-stop celery/celery-setup.sh stop
_emit_wrapper nlt-service-celery-restart celery/celery-setup.sh restart
_emit_wrapper nlt-service-celery-status celery/celery-setup.sh status

if [[ "${NLTDEPLOY_SKIP_PROFILE_HINT:-}" != "1" ]]; then
  echo ""
  echo "已安装到: ${NLTDEPLOY_ROOT}"
  echo "请将下列行加入 ~/.bashrc / ~/.zshrc（或当前 shell 配置）："
  echo "  export PATH=\"${NLTDEPLOY_ROOT}/bin:\${PATH}\""
  echo "若不想看见本提示，可设置 NLTDEPLOY_SKIP_PROFILE_HINT=1"
fi
