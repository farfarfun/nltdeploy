#!/usr/bin/env bash
# 一键安装 / 更新 nltdeploy 到 ~/.local/nltdeploy（可通过 NLTDEPLOY_ROOT 覆盖）。
# 用法: ./install.sh [install|update]   （install 与 update 等价：拉取上游后同步 libexec 与 bin）
# 本地执行：使用与 install.sh 同目录的 scripts/；若为 git 仓库则自动 git pull。
# curl …/install.sh | bash [ -s -- update ]：克隆到 NLTDEPLOY_SRC_DIR，每次执行会 pull 再同步。
set -euo pipefail

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
NLTDEPLOY_GITHUB_REPO="${NLTDEPLOY_GITHUB_REPO:-https://github.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_GITEE_REPO="${NLTDEPLOY_GITEE_REPO:-https://gitee.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_SRC_DIR="${NLTDEPLOY_SRC_DIR:-${NLTDEPLOY_ROOT}/src/nltdeploy}"

die() { echo "错误: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: install.sh [install|update]

  install   安装或刷新 ~/.local/nltdeploy 下的 libexec 与 bin（默认）
  update    与 install 相同：若 scripts 所在目录为 git 仓库，先 git pull --ff-only 再同步

环境变量:
  NLTDEPLOY_ROOT          安装根目录（默认 ~/.local/nltdeploy）
  NLTDEPLOY_SKIP_GIT_PULL 设为 1 时不执行 git pull（仍会做文件同步）
  NLTDEPLOY_SKIP_PROFILE_HINT 设为 1 时不打印 PATH 提示
  NLTDEPLOY_GITHUB_REPO / NLTDEPLOY_GITEE_REPO / NLTDEPLOY_SRC_DIR  见 README
EOF
}

# 解析子命令（管道执行时通常无参数，视为 install）
_CMD="${1:-install}"
case "${_CMD}" in
  install | update) ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    die "未知命令: ${_CMD}"
    ;;
esac

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

# 将仓库克隆到 NLTDEPLOY_SRC_DIR（若尚不存在）；打印 scripts 目录绝对路径（其它信息走 stderr）。
_ensure_clone_for_scripts() {
  command -v git >/dev/null 2>&1 || die "通过管道安装需要 git。请安装 git 或在克隆后的仓库根目录执行 ./install.sh"
  mkdir -p "${NLTDEPLOY_ROOT}" "${NLTDEPLOY_ROOT}/src"
  local repo="${NLTDEPLOY_SRC_DIR}"
  if [[ -d "${repo}/.git" ]]; then
    :
  elif [[ -e "${repo}" ]]; then
    die "路径已存在但不是 git 仓库，请删除或移走后重试: ${repo}"
  else
    echo "正在从 GitHub 克隆 farfarfun/nltdeploy …" >&2
    if ! git clone --depth 1 "${NLTDEPLOY_GITHUB_REPO}" "${repo}"; then
      echo "GitHub 不可用，正在从 Gitee 克隆 farfarfun/nltdeploy …" >&2
      git clone --depth 1 "${NLTDEPLOY_GITEE_REPO}" "${repo}" || die "GitHub 与 Gitee 克隆均失败，请检查网络与代理"
    fi
  fi
  [[ -d "${repo}/scripts" ]] || die "克隆完成但未找到 scripts 目录: ${repo}"
  echo "${repo}/scripts"
}

# scripts 的父目录若为 git 仓库，则拉取最新（可跳过）。
_sync_git_upstream_for_scripts() {
  local scripts_dir="$1"
  local root
  root="$(cd "$(dirname "$scripts_dir")" && pwd)"
  [[ -d "${root}/.git" ]] || return 0
  [[ "${NLTDEPLOY_SKIP_GIT_PULL:-}" == "1" ]] && return 0
  command -v git >/dev/null 2>&1 || die "发现 git 仓库但未安装 git，无法更新: ${root}"
  echo "正在拉取最新脚本: ${root}" >&2
  git -C "${root}" pull --ff-only || die "git pull 失败: ${root}"
}

SCRIPTS=""
if SCRIPTS="$(_resolve_scripts_from_install_sh)"; then
  :
else
  SCRIPTS="$(_ensure_clone_for_scripts)"
fi
[[ -d "$SCRIPTS" ]] || die "找不到 scripts 目录: ${SCRIPTS}"

_sync_git_upstream_for_scripts "$SCRIPTS"

LIBEXEC="${NLTDEPLOY_ROOT}/libexec/nltdeploy"
mkdir -p "${NLTDEPLOY_ROOT}/bin" "${LIBEXEC}" \
  "${NLTDEPLOY_ROOT}/share/nltdeploy" "${NLTDEPLOY_ROOT}/etc/nltdeploy"
mkdir -p "${LIBEXEC}/pip-sources" "${LIBEXEC}/python-env" \
  "${LIBEXEC}/airflow" "${LIBEXEC}/celery" "${LIBEXEC}/utils" "${LIBEXEC}/github-net" \
  "${LIBEXEC}/paperclip" "${LIBEXEC}/code-server" \
  "${LIBEXEC}/_lib"

cp -f "${SCRIPTS}/_lib/nlt-common.sh" "${LIBEXEC}/_lib/nlt-common.sh"
chmod 0755 "${LIBEXEC}/_lib/nlt-common.sh"

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

cp -f "${SCRIPTS}/07-paperclip/paperclip-setup.sh" "${LIBEXEC}/paperclip/paperclip-setup.sh"
chmod 0755 "${LIBEXEC}/paperclip/paperclip-setup.sh"

cp -f "${SCRIPTS}/08-code-server/code-server-setup.sh" "${LIBEXEC}/code-server/code-server-setup.sh"
chmod 0755 "${LIBEXEC}/code-server/code-server-setup.sh"

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
_emit_wrapper nlt-service-airflow-update airflow/deploy.sh update

_emit_wrapper nlt-celery-install celery/celery-setup.sh install
_emit_wrapper nlt-celery-update celery/celery-setup.sh update

_emit_wrapper nlt-service-celery-worker-start celery/celery-setup.sh start-worker
_emit_wrapper nlt-service-celery-beat-start celery/celery-setup.sh start-beat
_emit_wrapper nlt-service-celery-flower-start celery/celery-setup.sh start-flower
_emit_wrapper nlt-service-celery-stop celery/celery-setup.sh stop
_emit_wrapper nlt-service-celery-restart celery/celery-setup.sh restart
_emit_wrapper nlt-service-celery-status celery/celery-setup.sh status

_emit_wrapper nlt-paperclip-install paperclip/paperclip-setup.sh install
_emit_wrapper nlt-paperclip paperclip/paperclip-setup.sh

_emit_wrapper nlt-service-paperclip-start paperclip/paperclip-setup.sh start
_emit_wrapper nlt-service-paperclip-stop paperclip/paperclip-setup.sh stop
_emit_wrapper nlt-service-paperclip-restart paperclip/paperclip-setup.sh restart
_emit_wrapper nlt-service-paperclip-status paperclip/paperclip-setup.sh status
_emit_wrapper nlt-service-paperclip-update paperclip/paperclip-setup.sh update

_emit_wrapper nlt-code-server-install code-server/code-server-setup.sh install
_emit_wrapper nlt-code-server code-server/code-server-setup.sh

_emit_wrapper nlt-service-code-server-start code-server/code-server-setup.sh start
_emit_wrapper nlt-service-code-server-stop code-server/code-server-setup.sh stop
_emit_wrapper nlt-service-code-server-restart code-server/code-server-setup.sh restart
_emit_wrapper nlt-service-code-server-status code-server/code-server-setup.sh status
_emit_wrapper nlt-service-code-server-update code-server/code-server-setup.sh update

if [[ "${NLTDEPLOY_SKIP_PROFILE_HINT:-}" != "1" ]]; then
  echo ""
  echo "已安装到: ${NLTDEPLOY_ROOT}"
  echo "请将下列行加入 ~/.bashrc / ~/.zshrc（或当前 shell 配置）："
  echo "  export PATH=\"${NLTDEPLOY_ROOT}/bin:\${PATH}\""
  echo "若不想看见本提示，可设置 NLTDEPLOY_SKIP_PROFILE_HINT=1"
fi
