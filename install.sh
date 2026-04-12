#!/usr/bin/env bash
# 一键安装 / 更新 / 卸载 nltdeploy 到 ~/.local/nltdeploy（可通过 NLTDEPLOY_ROOT 覆盖）。
# 用法见下方 usage；无参数且为交互式终端时，会先选择「安装」「更新」或「卸载」，不直接写盘。
# 管道非 TTY 时必须显式传入子命令，例如: curl … | bash -s -- install
set -euo pipefail

NLTDEPLOY_ROOT="${NLTDEPLOY_ROOT:-${HOME}/.local/nltdeploy}"
NLTDEPLOY_GITHUB_REPO="${NLTDEPLOY_GITHUB_REPO:-https://github.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_GITEE_REPO="${NLTDEPLOY_GITEE_REPO:-https://gitee.com/farfarfun/nltdeploy.git}"
NLTDEPLOY_SRC_DIR="${NLTDEPLOY_SRC_DIR:-${NLTDEPLOY_ROOT}/src/nltdeploy}"

die() { echo "错误: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
用法: install.sh [install|update|uninstall]

  install / update   同步 libexec 与 bin；若 scripts 所在目录为 git 仓库则先 git pull --ff-only（可跳过）
  uninstall / remove 删除 NLTDEPLOY_ROOT，并从 shell 配置中移除本安装器写入的 PATH 片段

无参数:
  交互式终端下会先询问「安装」「更新」或「卸载」（有 gum 则用 gum）。
  非交互（管道、无 TTY）或无参数且 NONINTERACTIVE=1 时必须写明子命令，例如:
    curl -LsSf …/install.sh | bash -s -- install

环境变量:
  NLTDEPLOY_ROOT              安装根目录（默认 ~/.local/nltdeploy）
  NLTDEPLOY_SKIP_GIT_PULL     设为 1 时不执行 git pull（仍同步文件）
  NLTDEPLOY_SKIP_PROFILE_HINT 设为 1 时不写入 PATH、不打印 PATH 说明（适合 CI）
  NLTDEPLOY_UNINSTALL_YES     设为 1 时非 TTY 也可执行 uninstall（确认删除）
  NLTDEPLOY_GITHUB_REPO / NLTDEPLOY_GITEE_REPO / NLTDEPLOY_SRC_DIR  见 README
  NLTDEPLOY_GIT_CLONE_REF   管道安装时 git clone 的分支或 tag（可选）。raw 用 …/master/… 而仓库默认分支是 main 时，可设为 master 与脚本版本一致；不设则克隆远程默认分支。
EOF
}

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

# 浅克隆；若设置了 NLTDEPLOY_GIT_CLONE_REF 则固定该分支/tag（与 raw 脚本 URL 中的 ref 对齐）。
_nlt_git_clone_shallow() {
  local url="$1" dest="$2"
  if [[ -n "${NLTDEPLOY_GIT_CLONE_REF:-}" ]]; then
    git clone --depth 1 --branch "${NLTDEPLOY_GIT_CLONE_REF}" "${url}" "${dest}"
  else
    git clone --depth 1 "${url}" "${dest}"
  fi
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
    if ! _nlt_git_clone_shallow "${NLTDEPLOY_GITHUB_REPO}" "${repo}"; then
      echo "GitHub 不可用，正在从 Gitee 克隆 farfarfun/nltdeploy …" >&2
      _nlt_git_clone_shallow "${NLTDEPLOY_GITEE_REPO}" "${repo}" || die "GitHub 与 Gitee 克隆均失败，请检查网络与代理"
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

# 规范路径，便于去重与写入 rc
_nlt_canonical_bin_dir() {
  (cd "${NLTDEPLOY_ROOT}/bin" && pwd -P)
}

_nlt_rc_has_managed_block() {
  local f="$1"
  [[ -f "$f" ]] && grep -Fq -e '--- nltdeploy PATH' "$f"
}

_nlt_rc_path_mentions_bin() {
  local f="$1" bin="$2"
  [[ -f "$f" ]] && grep -qF "${bin}" "$f"
}

_nlt_append_nlt_path_block() {
  local rc="$1"
  local bin="$2"
  local line marker_top marker_bot
  line="export PATH=\"${bin}:\${PATH}\""
  marker_top='# --- nltdeploy PATH (github.com/farfarfun/nltdeploy install.sh) ---'
  marker_bot='# --- end nltdeploy PATH ---'

  if _nlt_rc_has_managed_block "$rc"; then
    echo "PATH 已配置（存在 nltdeploy 标记块）: ${rc}" >&2
    return 0
  fi
  if _nlt_rc_path_mentions_bin "$rc" "$bin"; then
    echo "跳过写入 ${rc}：文件中已出现 ${bin}（请确认 PATH 已包含 nltdeploy bin）" >&2
    return 0
  fi

  {
    echo ""
    echo "${marker_top}"
    echo "${line}"
    echo "${marker_bot}"
  } >>"$rc"
  echo "已追加 PATH 到: ${rc}" >&2
}

_nlt_collect_profile_targets() {
  local -a out=()
  local p t

  add_unique() {
    p="$1"
    [[ -z "$p" ]] && return
    for t in "${out[@]:-}"; do
      [[ "$t" == "$p" ]] && return
    done
    out+=("$p")
  }

  if [[ -f "${HOME}/.zshrc" ]] || [[ "${SHELL:-}" == *zsh* ]]; then
    add_unique "${HOME}/.zshrc"
  fi
  if [[ -f "${HOME}/.bashrc" ]] || [[ "${SHELL:-}" == *bash* ]]; then
    add_unique "${HOME}/.bashrc"
  fi
  if [[ "${SHELL:-}" == *bash* ]] && [[ ! -f "${HOME}/.bashrc" ]] && [[ -f "${HOME}/.bash_profile" ]]; then
    add_unique "${HOME}/.bash_profile"
  fi
  if [[ ${#out[@]} -eq 0 ]]; then
    add_unique "${HOME}/.zshrc"
  fi

  for t in "${out[@]}"; do
    printf '%s\n' "$t"
  done
}

_nlt_install_path_to_profiles() {
  local bin
  bin="$(_nlt_canonical_bin_dir)" || die "无法解析 ${NLTDEPLOY_ROOT}/bin 为绝对路径"
  local rc
  while IFS= read -r rc; do
    [[ -n "$rc" ]] || continue
    touch "$rc" 2>/dev/null || {
      echo "无法写入 ${rc}，跳过。" >&2
      continue
    }
    _nlt_append_nlt_path_block "$rc" "$bin"
  done < <(_nlt_collect_profile_targets)
}

_remove_managed_path_block_from_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  grep -Fq -e '--- nltdeploy PATH' "$f" || return 0
  local start end tmp
  start="$(grep -nF '# --- nltdeploy PATH (github.com/farfarfun/nltdeploy install.sh) ---' "$f" | head -1 | cut -d: -f1)"
  end="$(grep -nF '# --- end nltdeploy PATH ---' "$f" | head -1 | cut -d: -f1)"
  [[ -n "$start" && -n "$end" && "$end" -ge "$start" ]] || return 0
  tmp="$(mktemp)"
  awk -v s="$start" -v e="$end" 'NR < s || NR > e' "$f" >"$tmp" && mv "$tmp" "$f"
  echo "已从 ${f} 移除 nltdeploy PATH 片段" >&2
}

_pick_cmd_interactive() {
  if command -v gum >/dev/null 2>&1; then
    local p
    p="$(gum choose --header "nltdeploy" "安装" "更新" "卸载" "退出")" || exit 0
    case "$p" in
      安装) echo "install" ;;
      更新) echo "update" ;;
      卸载) echo "uninstall" ;;
      *) exit 0 ;;
    esac
  else
    echo "请选择:" >&2
    echo "  1) 安装   2) 更新   3) 卸载   4) 退出" >&2
    read -r -p "输入 1-4: " sel
    case "$sel" in
      1) echo "install" ;;
      2) echo "update" ;;
      3) echo "uninstall" ;;
      *) exit 0 ;;
    esac
  fi
}

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

# 从候选路径中选第一个存在的文件复制到 dest 并 chmod 0755（兼容 _lib→lib、扁平 scripts 与 tools/services 分层）。
_nlt_cp_first() {
  local dest="$1"
  shift
  local f
  for f in "$@"; do
    if [[ -f "$f" ]]; then
      cp -f "$f" "$dest"
      chmod 0755 "$dest"
      return 0
    fi
  done
  die "找不到源文件，已尝试: $*"
}

do_install_or_update() {
  local SCRIPTS LIBEXEC
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
    "${LIBEXEC}/paperclip" "${LIBEXEC}/code-server" "${LIBEXEC}/new-api" \
    "${LIBEXEC}/services" \
    "${LIBEXEC}/lib"

  _nlt_cp_first "${LIBEXEC}/lib/nlt-common.sh" \
    "${SCRIPTS}/lib/nlt-common.sh" \
    "${SCRIPTS}/_lib/nlt-common.sh"

  _nlt_cp_first "${LIBEXEC}/pip-sources/setup.sh" \
    "${SCRIPTS}/tools/pip-sources/setup.sh" \
    "${SCRIPTS}/pip-sources/setup.sh"

  _nlt_cp_first "${LIBEXEC}/python-env/setup.sh" \
    "${SCRIPTS}/tools/python-env/setup.sh" \
    "${SCRIPTS}/python-env/setup.sh"

  _nlt_cp_first "${LIBEXEC}/airflow/setup.sh" \
    "${SCRIPTS}/services/airflow/setup.sh" \
    "${SCRIPTS}/airflow/setup.sh"

  _nlt_cp_first "${LIBEXEC}/celery/setup.sh" \
    "${SCRIPTS}/services/celery/setup.sh" \
    "${SCRIPTS}/celery/setup.sh" \
    "${SCRIPTS}/celery/celery-setup.sh"

  _nlt_cp_first "${LIBEXEC}/utils/setup.sh" \
    "${SCRIPTS}/tools/utils/setup.sh" \
    "${SCRIPTS}/utils/setup.sh" \
    "${SCRIPTS}/utils/utils-setup.sh"

  _nlt_cp_first "${LIBEXEC}/github-net/setup.sh" \
    "${SCRIPTS}/tools/github-net/setup.sh" \
    "${SCRIPTS}/github-net/setup.sh"

  _nlt_cp_first "${LIBEXEC}/paperclip/setup.sh" \
    "${SCRIPTS}/services/paperclip/setup.sh" \
    "${SCRIPTS}/paperclip/setup.sh" \
    "${SCRIPTS}/paperclip/paperclip-setup.sh"

  _nlt_cp_first "${LIBEXEC}/code-server/setup.sh" \
    "${SCRIPTS}/services/code-server/setup.sh" \
    "${SCRIPTS}/code-server/setup.sh" \
    "${SCRIPTS}/code-server/code-server-setup.sh"

  _nlt_cp_first "${LIBEXEC}/new-api/setup.sh" \
    "${SCRIPTS}/services/new-api/setup.sh" \
    "${SCRIPTS}/new-api/setup.sh" \
    "${SCRIPTS}/new-api/new-api-setup.sh"

  _nlt_cp_first "${LIBEXEC}/services/nlt-services.sh" \
    "${SCRIPTS}/services/nlt-services.sh" \
    "${SCRIPTS}/services/services.sh" \
    "${SCRIPTS}/10-services/services.sh"

  _emit_wrapper nlt-pip-sources pip-sources/setup.sh
  _emit_wrapper nlt-python-env python-env/setup.sh
  _emit_wrapper nlt-utils utils/setup.sh
  _emit_wrapper nlt-github-net github-net/setup.sh
  _emit_wrapper nlt-services services/nlt-services.sh

  _emit_wrapper nlt-airflow-install airflow/setup.sh install
  _emit_wrapper nlt-airflow airflow/setup.sh
  _emit_wrapper nlt-service-airflow airflow/setup.sh

  _emit_wrapper nlt-celery-install celery/setup.sh install
  _emit_wrapper nlt-celery-update celery/setup.sh update
  _emit_wrapper nlt-service-celery celery/setup.sh

  _emit_wrapper nlt-paperclip-install paperclip/setup.sh install
  _emit_wrapper nlt-paperclip paperclip/setup.sh
  _emit_wrapper nlt-service-paperclip paperclip/setup.sh

  _emit_wrapper nlt-code-server-install code-server/setup.sh install
  _emit_wrapper nlt-code-server code-server/setup.sh
  _emit_wrapper nlt-service-code-server code-server/setup.sh

  _emit_wrapper nlt-new-api-install new-api/setup.sh install
  _emit_wrapper nlt-new-api new-api/setup.sh
  _emit_wrapper nlt-service-new-api new-api/setup.sh

  if [[ "${NLTDEPLOY_SKIP_PROFILE_HINT:-}" != "1" ]]; then
    echo ""
    echo "已安装到: ${NLTDEPLOY_ROOT}"
    _nlt_install_path_to_profiles
    echo ""
    echo "新开终端或执行: source ~/.zshrc   或   source ~/.bashrc"
    echo "若不想自动写入 shell 配置，可设置 NLTDEPLOY_SKIP_PROFILE_HINT=1"
  fi
}

do_uninstall() {
  local root hp ap rc
  if [[ ! -d "${NLTDEPLOY_ROOT}" ]]; then
    echo "未找到安装目录，跳过: ${NLTDEPLOY_ROOT}" >&2
    exit 0
  fi

  root="$(cd "${NLTDEPLOY_ROOT}" && pwd -P)"
  hp="$(cd "$HOME" && pwd -P)"
  [[ "$root" == "/" ]] && die "拒绝删除根目录"
  [[ "$root" == "$hp" ]] && die "拒绝删除 \$HOME"

  if [[ "${NLTDEPLOY_UNINSTALL_YES:-}" != "1" ]]; then
    if [[ -t 0 ]]; then
      if command -v gum >/dev/null 2>&1; then
        gum confirm "将删除整个 ${NLTDEPLOY_ROOT}（含 bin、libexec、克隆仓库），并从 shell 配置中移除 nltdeploy PATH 片段。确认？" || exit 0
      else
        read -r -p "确认删除 ${NLTDEPLOY_ROOT}？[y/N] " ap
        [[ "$ap" == "y" || "$ap" == "Y" ]] || exit 0
      fi
    else
      die "非交互卸载请设置 NLTDEPLOY_UNINSTALL_YES=1"
    fi
  fi

  while IFS= read -r rc; do
    [[ -n "$rc" ]] || continue
    _remove_managed_path_block_from_file "$rc"
  done < <(_nlt_collect_profile_targets)

  echo "正在删除: ${NLTDEPLOY_ROOT}" >&2
  rm -rf "${NLTDEPLOY_ROOT}"
  echo "已卸载 nltdeploy。" >&2
}

# ---- 入口 ----
_CMD=""
if [[ $# -eq 0 ]]; then
  if [[ ! -t 0 ]] || [[ "${NONINTERACTIVE:-}" == "1" ]]; then
    usage >&2
    die "请指定子命令 install（或 update）或 uninstall。管道示例: curl …/install.sh | bash -s -- install"
  fi
  _CMD="$(_pick_cmd_interactive)"
else
  _CMD="$1"
  shift
fi

case "${_CMD}" in
  install | update)
    do_install_or_update
    ;;
  uninstall | remove)
    do_uninstall
    ;;
  help | -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    die "未知命令: ${_CMD}"
    ;;
esac
