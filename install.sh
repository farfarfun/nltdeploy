#!/usr/bin/env bash
# 一键安装 nltdeploy 命令到 ~/.local/nltdeploy（可通过 NLTDEPLOY_ROOT 覆盖）。
# 本地执行 install.sh：使用同目录下 scripts/。
# curl …/install.sh | bash：在 NLTDEPLOY_ROOT 下 git clone（优先 GitHub，失败则 Gitee；同组织 farfarfun 同名 nltdeploy）。
set -euo pipefail

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
NLTDEPLOY_GITHUB_REPO="${NLTDEPLOY_GITHUB_REPO:-https://github.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_GITEE_REPO="${NLTDEPLOY_GITEE_REPO:-https://gitee.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_SRC_DIR="${NLTDEPLOY_SRC_DIR:-${NLTDEPLOY_ROOT}/src/nltdeploy}"

die() { echo "错误: $*" >&2; exit 1; }

# 若从仓库根执行（install.sh 为普通文件且旁侧有 scripts/），返回该 scripts 绝对路径；否则返回非 0。
_resolve_scripts_from_install_sh() {
  local _src="${BASH_SOURCE[0]-}" _dir
  if [[ -n "$_src" && "$_src" != "-" && -f "$_src" ]]; then
    _dir="$(cd "$(dirname "$_src")" && pwd)" || return 1
    if [[ -d "${_dir}/scripts" ]]; then
      echo "${_dir}/scripts"
      return 0
    fi
  fi
  return 1
}

# 将仓库克隆到 NLTDEPLOY_SRC_DIR，打印 scripts 目录绝对路径（其它信息走 stderr）。
_clone_repo_for_scripts() {
  command -v git >/dev/null 2>&1 || die "通过管道安装需要 git。请安装 git 或在克隆后的仓库根目录执行 ./install.sh"
  mkdir -p "${NLTDEPLOY_ROOT}" "${NLTDEPLOY_ROOT}/src"
  local repo="${NLTDEPLOY_SRC_DIR}"
  if [[ -d "${repo}/.git" ]]; then
    echo "更新本地仓库: ${repo}" >&2
    git -C "${repo}" pull --ff-only || die "git pull 失败，请检查 ${repo}"
  else
    if [[ -e "${repo}" ]]; then
      die "路径已存在但不是 git 仓库，请删除或移走后重试: ${repo}"
    fi
    echo "正在从 GitHub 克隆 farfarfun/nltdeploy …" >&2
    if ! git clone --depth 1 "${NLTDEPLOY_GITHUB_REPO}" "${repo}"; then
      echo "GitHub 不可用，正在从 Gitee 克隆 farfarfun/nltdeploy …" >&2
      git clone --depth 1 "${NLTDEPLOY_GITEE_REPO}" "${repo}" || die "GitHub 与 Gitee 克隆均失败，请检查网络与代理"
    fi
  fi
  [[ -d "${repo}/scripts" ]] || die "克隆完成但未找到 scripts 目录: ${repo}"
  echo "${repo}/scripts"
}

SCRIPTS=""
if SCRIPTS="$(_resolve_scripts_from_install_sh)"; then
  :
else
  SCRIPTS="$(_clone_repo_for_scripts)"
fi
[[ -d "$SCRIPTS" ]] || die "找不到 scripts 目录: ${SCRIPTS}"

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
