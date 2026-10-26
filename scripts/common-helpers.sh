#!/bin/sh
# Common helper functions for Agent Up scripts
# Provides: die1, die2, warn, resolve_repo_root
# Usage: source this file at the top of your script after set -eu

# Extract script name from $0 for error messages
_script_name() {
  basename "$0" | sed 's/\.sh$//'
}

# Exit 1 with FAIL prefix (validation/logical errors)
die1() {
  printf '%s: FAIL: %s\n' "$(_script_name)" "$1" >&2
  exit 1
}

# Exit 2 with plain prefix (usage/environment errors)
die2() {
  printf '%s: %s\n' "$(_script_name)" "$1" >&2
  exit 2
}

# Warning message (non-fatal)
warn() {
  printf '%s: WARNING: %s\n' "$(_script_name)" "$1" >&2
}

# resolve_repo_root [--git|--marker|--layout] [override]
# 仓库根推导唯一实现（票 227 F4：三套根推导约定统一改调本函数）。
# 模式:
#   (缺省)     落位分派推导：override（第一非模式参数，存在即规范化为物理绝对路径）>
#              $0 落位推导——*/rules/implementation/scripts/ 上三级、
#              */agent-up/scripts/ 上两级、其余落位兜底上两级（generate-progress
#              票 206 口径）。输出物理绝对路径；推导失败 return 1。
#   --layout   同缺省的落位分派，但仅认两规范落位（agent-up/scripts/ 与
#              rules/implementation/scripts/），其余落位 return 1（check-stale-claims
#              fail-closed 口径：非规范落位不静默错根）。
#   --git      override > git rev-parse --show-toplevel（以当前目录所在仓库为准；
#              check-gates/lane-commit/generate-module-map/worktree-add 口径）。
#   --marker   override > 自 $0 目录逐级向上（至多 4 级）找 facts/project/changes.jsonl
#              标记（absorption-trigger/health-summary 口径；找不到 return 1）。
# 输出: 推导根路径打印到 stdout；失败 return 非 0 且不输出。调用方负责失败报文。
resolve_repo_root() {
  _rr_mode='' _rr_override=''
  for _rr_arg in "$@"; do
    case $_rr_arg in
      --git|--marker|--layout) _rr_mode=$_rr_arg ;;
      '') : ;;
      *) _rr_override=$_rr_arg ;;
    esac
  done
  if [ -n "$_rr_override" ]; then
    (CDPATH='' cd -- "$_rr_override" 2>/dev/null && pwd -P)
    return
  fi
  case $_rr_mode in
    --git)
      git rev-parse --show-toplevel 2>/dev/null
      return
      ;;
    --marker)
      _rr_dir=$(dirname -- "$0")
      _rr_i=0
      while [ "$_rr_i" -lt 4 ]; do
        _rr_dir=$(CDPATH='' cd -- "$_rr_dir/.." 2>/dev/null && pwd -P) || return 1
        if [ -f "${_rr_dir}/facts/project/changes.jsonl" ]; then
          printf '%s\n' "$_rr_dir"
          return 0
        fi
        _rr_i=$((_rr_i + 1))
      done
      return 1
      ;;
    *)
      _rr_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || return 1
      case $_rr_dir in
        */rules/implementation/scripts) _rr_root=${_rr_dir%/*/*/*} ;;
        */agent-up/scripts) _rr_root=${_rr_dir%/*/*} ;;
        *)
          if [ "$_rr_mode" = '--layout' ]; then
            return 1
          fi
          _rr_root=${_rr_dir%/*/*}
          ;;
      esac
      printf '%s\n' "$_rr_root"
      ;;
  esac
}
