#!/usr/bin/env bash
# nltdeploy 公共片段：由各域 setup 脚本 source（路径：与脚本同树上一级 lib/）。
# 规范见 docs/superpowers/specs/2026-04-11-nltdeploy-tool-service-conventions.md
[[ -n "${_NLT_COMMON_LOADED:-}" ]] && return 0
_NLT_COMMON_LOADED=1

_nltdeploy_raw_base() {
  printf '%s\n' "${NLTDEPLOY_RAW_BASE:-${nltdeploy_RAW_BASE:-https://raw.githubusercontent.com/farfarfun/nltdeploy/HEAD}}"
}

_nlt_gum_utils_setup_url() {
  printf '%s\n' "$(_nltdeploy_raw_base)/scripts/utils/setup.sh"
}

# 已安装 gum 则立即返回；否则拉取 scripts/utils/setup.sh 安装（不单独做「仅检测并报错」）。
_nlt_ensure_gum() {
  export PATH="${HOME}/opt/gum/bin:${PATH}"
  command -v gum >/dev/null 2>&1 && return 0

  if [[ -x "${HOME}/opt/gum/bin/gum" ]]; then
    export PATH="${HOME}/opt/gum/bin:${PATH}"
    command -v gum >/dev/null 2>&1 && return 0
  fi

  command -v curl >/dev/null 2>&1 || {
    echo "错误: 需要 curl 以安装 gum。" >&2
    return 1
  }

  local _url
  _url="$(_nlt_gum_utils_setup_url)"
  echo "未检测到 gum，执行: curl -LsSf ${_url} | bash -s -- gum" >&2
  curl -LsSf "${_url}" | bash -s -- gum || {
    echo "错误: gum 安装失败（网络或 NLTDEPLOY_RAW_BASE / nltdeploy_RAW_BASE）。" >&2
    return 1
  }

  export PATH="${HOME}/opt/gum/bin:${PATH}"
  command -v gum >/dev/null 2>&1 || {
    echo "错误: gum 仍未可用（预期 ~/opt/gum/bin）。" >&2
    return 1
  }
  return 0
}
