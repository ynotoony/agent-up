#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与行式门禁清单文件
#        （whitelist: 逗号分隔仓库根相对路径；verify: 逐行验证命令，可多行；
#         allow-output: 逗号分隔的允许输出目录，缺省为空；
#         record-only: 纯记录例外理由，必须同时带唯一的 verify: N/A）。
# Output: 实际改动对白名单的逐项 PASS/FAIL 行、verify 命令逐条退出码记录、
#         越界写入的异常路径与前后状态差异，以及结尾汇总行；
#         exit 0 全部通过、1 有未过项、2 用法或环境错误。
# Pos: 分级交付道快道门禁核对器（REQ-20260904-011；票 26；行为基线 = rules/project.md
#      模板 §12.5 道脚本承载注记；票 245 增验证执行边界——每条 verify 前后各取一次
#      完整工作区快照（跟踪文件内容与可执行位、未跟踪与忽略文件、目录、符号链接目标、
#      索引与 HEAD），allow-output 目录内的未跟踪产物是唯一放行面，其余变化一律 FAIL
#      且不自动删除、不回滚）。POSIX sh、零外部依赖（POSIX 工具与 Git 只读子命令，
#      内容哈希经 git hash-object，快照临时件落 $TMPDIR）。

# 用法、门禁清单行格式、执行边界与输出格式见同目录 README.md。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'check-gates: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'

usage() {
  cat <<'USAGE'
用法: sh check-gates.sh [repo-root] <gates-file>
参数:
  repo-root   仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  gates-file  行式门禁清单文件，行格式（均以行首列为准）:
                whitelist: <逗号分隔的仓库根相对路径>
                verify: <验证命令>（一行一条，可多行；普通快道至少一条）
                allow-output: <逗号分隔的仓库根相对输出目录>（可选，缺省为空）
                record-only: <纯记录理由>（仅纯记录例外；须同时有 verify: N/A）
                # 注释（行首 #）与空行忽略；其余行判格式错误。
  -h / --help 打印本用法。
验证命令执行边界: 每条 verify 执行前后各取一次完整工作区快照（跟踪文件内容与
可执行位、未跟踪与忽略文件、目录、符号链接目标、索引与 HEAD）；allow-output
目录内的未跟踪产物视为合法输出，其余变化一律 FAIL。越界改动不自动删除、不回滚。
退出码: 0 全部通过；1 有未过项（越界改动、verify 失败或 verify 越界写工作区）；2 用法或环境错误。
USAGE
}

case $# in
  2)
    repo_root=$1
    gates_file=$2
    ;;
  1)
    case $1 in
      -h|--help) usage; exit 0 ;;
    esac
    # 仓库根推导统一经 resolve_repo_root（票 227 F4：--git 口径＝当前目录所在仓库顶层）
    repo_root=$(resolve_repo_root --git) || die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
    gates_file=$1
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"
[ -r "${gates_file}" ] || die2 "门禁清单不可读: ${gates_file}"
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${repo_root}"

# ---- 解析门禁清单 ----

wl_seen=0
whitelist=''
verifies=''
record_only_seen=0
record_only=''
allow_seen=0
allow_output=''

while IFS= read -r line || [ -n "${line}" ]; do
  case ${line} in
    ''|'#'*) continue ;;
    *:*)
      key=${line%%:*}
      val=${line#*:}
      val=$(printf '%s' "${val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      case ${key} in
        whitelist)
          wl_seen=1
          rest=${val}
          while [ -n "${rest}" ]; do
            entry=${rest%%,*}
            case ${rest} in
              *,*) rest=${rest#*,} ;;
              *) rest='' ;;
            esac
            entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${entry}" ] || die2 'whitelist 含空条目'
            whitelist="${whitelist}${entry}${NL}"
          done
          ;;
        verify)
          [ -n "${val}" ] || die2 'verify 行缺少命令'
          verifies="${verifies}${val}${NL}"
          ;;
        allow-output)
          [ "${allow_seen}" -eq 0 ] || die2 'allow-output 行重复'
          allow_seen=1
          rest=${val}
          while [ -n "${rest}" ]; do
            entry=${rest%%,*}
            case ${rest} in
              *,*) rest=${rest#*,} ;;
              *) rest='' ;;
            esac
            entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            while [ "${entry#./}" != "${entry}" ]; do entry=${entry#./}; done
            while [ "${entry%/}" != "${entry}" ]; do entry=${entry%/}; done
            case ${entry} in
              ''|.|..) die2 "allow-output 路径形态非法: ${entry}" ;;
              /*) die2 "allow-output 不得为绝对路径: ${entry}" ;;
              ../*|*/..|*/../*) die2 "allow-output 不得含 .. 路径段: ${entry}" ;;
              .git|.git/*) die2 "allow-output 不得指向 .git: ${entry}" ;;
              *"	"*) die2 "allow-output 路径含制表符: ${entry}" ;;
            esac
            allow_output="${allow_output}${entry}${NL}"
          done
          ;;
        record-only)
          [ "${record_only_seen}" -eq 0 ] || die2 'record-only 行重复'
          [ -n "${val}" ] || die2 'record-only 行缺少理由'
          record_only_seen=1
          record_only=${val}
          ;;
        *)
          die2 "无法识别的门禁清单行: ${line}"
          ;;
      esac
      ;;
    *)
      die2 "无法识别的门禁清单行: ${line}"
      ;;
  esac
done < "${gates_file}"

[ "${wl_seen}" -eq 1 ] || die2 '门禁清单缺少 whitelist 行'

# 普通快道必须有真实验证；纯记录例外必须显式声明理由并使用唯一 N/A 哨兵。
n_verify_lines=0
n_real_verify=0
n_na_verify=0
verify_rest=${verifies}
while [ -n "${verify_rest}" ]; do
  case ${verify_rest} in
    *"${NL}"*)
      vcmd=${verify_rest%%"${NL}"*}
      verify_rest=${verify_rest#*"${NL}"}
      ;;
    *)
      vcmd=${verify_rest}
      verify_rest=''
      ;;
  esac
  n_verify_lines=$((n_verify_lines + 1))
  if [ "${vcmd}" = 'N/A' ]; then
    n_na_verify=$((n_na_verify + 1))
  else
    n_real_verify=$((n_real_verify + 1))
  fi
done
if [ "${record_only_seen}" -eq 1 ]; then
  [ "${n_real_verify}" -eq 0 ] || die2 'record-only 不能同时携带真实 verify 命令'
  [ "${n_na_verify}" -eq 1 ] && [ "${n_verify_lines}" -eq 1 ] || die2 'record-only 必须携带唯一 verify: N/A'
else
  [ "${n_real_verify}" -gt 0 ] || die2 '普通快道至少需要一条 verify；纯记录请显式声明 record-only: <理由> 与 verify: N/A'
  [ "${n_na_verify}" -eq 0 ] || die2 'verify: N/A 仅允许与 record-only 一起使用'
fi

# ---- 路径判定与快照工具 ----

# $1=仓库根相对路径；在 allow-output 目录内返回 0（供白名单核对与快照过滤共用）
cg_path_allowed() {
  _cp=$1
  _cr=${allow_output}
  while [ -n "${_cr}" ]; do
    _cd=${_cr%%"${NL}"*}
    case ${_cr} in
      *"${NL}"*) _cr=${_cr#*"${NL}"} ;;
      *) _cr='' ;;
    esac
    [ -n "${_cd}" ] || continue
    if [ "${_cp}" = "${_cd}" ]; then
      return 0
    fi
    case ${_cp} in
      "${_cd}"/*) return 0 ;;
    esac
  done
  return 1
}

# 过滤器：丢弃 allow-output 目录内的条目（快照两侧同样过滤，故其变化不可见）
# shellcheck disable=SC2329  # cg_filter 由主件条件调用（单文件视野误报）
cg_filter() {
  awk -v af="${work_dir}/allow.txt" '
    BEGIN { while ((getline d < af) > 0) { if (d != "") { n++; A[n] = d } } }
    {
      p = $0
      for (i = 1; i <= n; i++) {
        d = A[i]
        if (p == d || substr(p, 1, length(d) + 1) == d "/") next
      }
      print
    }
  '
}

cg_write_allow() {
  : > "${work_dir}/allow.txt"
  _rest=${allow_output}
  while [ -n "${_rest}" ]; do
    _d=${_rest%%"${NL}"*}
    case ${_rest} in
      *"${NL}"*) _rest=${_rest#*"${NL}"} ;;
      *) _rest='' ;;
    esac
    if [ -n "${_d}" ]; then
      printf '%s\n' "${_d}" >> "${work_dir}/allow.txt"
    fi
  done
}

# allow-output 只放行未跟踪产物：目录内含已跟踪文件即配置错误（fail-closed）
cg_validate_allow() {
  [ -s "${work_dir}/allow.txt" ] || return 0
  git -C "${repo_root}" ls-files -z | tr '\0' '\n' > "${work_dir}/tracked.txt" || die2 'git ls-files 执行失败'
  while IFS= read -r _d; do
    [ -n "${_d}" ] || continue
    if _d=${_d} awk 'BEGIN { d = ENVIRON["_d"] } index($0, d "/") == 1 || $0 == d { found = 1; exit } END { exit !found }' "${work_dir}/tracked.txt"; then
      die2 "allow-output 目录含已跟踪文件，拒绝配置（输出白名单只允许未跟踪产物）: ${_d}"
    fi
  done < "${work_dir}/allow.txt"
}

# ---- 工作区快照子系统（票 294：独立为同目录 workspace-snapshot.sh）----
_cg_snap_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1090,SC1091  # 快照模块路径由脚本目录推导（动态源，静态视野不可跟随）
. "$_cg_snap_self_dir/workspace-snapshot.sh"
# ---- 临时工作区与 allow-output 预检（快照与白名单核对的前置） ----

work_dir=''
work_keep=0
# shellcheck disable=SC2329  # cleanup_work 由 trap 回调（shellcheck 单文件视野误报）
cleanup_work() {
  if [ -n "${work_dir}" ] && [ -d "${work_dir}" ] && [ "${work_keep}" -eq 0 ]; then
    rm -rf "${work_dir}"
  fi
  return 0
}
trap cleanup_work EXIT HUP INT TERM

if [ -n "${allow_output}" ] || [ "${n_real_verify}" -gt 0 ]; then
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/check-gates.XXXXXX") || die2 '快照临时目录创建失败'
  cg_write_allow
  cg_validate_allow
fi

# ---- 改动集 ⊆ 白名单 ----

status_out=$(git -c core.quotePath=false -C "${repo_root}" status --porcelain -uall) || die2 'git status 执行失败'

failures=0
n_files=0
seen=${NL}

check_path() {
  # $1=仓库根相对路径；依赖全局 whitelist/seen/failures/n_files/allow_output
  _p=$1
  case ${_p} in
    *' '*) die2 "路径含空白，拒绝解析（git status 行）: ${_p}" ;;
    '"'*) die2 "路径含转义引用，拒绝解析（git status 行）: ${_p}" ;;
  esac
  needle="${NL}${_p}${NL}"
  case ${seen} in
    *"${needle}"*) return 0 ;;
  esac
  seen="${seen}${_p}${NL}"
  n_files=$((n_files + 1))
  if cg_path_allowed "${_p}"; then
    printf 'PASS: 改动 %s（在允许输出目录内）\n' "${_p}"
    return 0
  fi
  case "${NL}${whitelist}" in
    *"${needle}"*)
      printf 'PASS: 改动 %s（在白名单内）\n' "${_p}"
      ;;
    *)
      printf 'FAIL: 改动 %s（不在白名单内）\n' "${_p}"
      failures=$((failures + 1))
      ;;
  esac
}

IFS=${NL}
for sline in ${status_out}; do
  case ${sline} in
    ??' '*) path=${sline#?? } ;;
    *) die2 "无法解析的 git status 行: ${sline}" ;;
  esac
  case ${path} in
    *' -> '*)
      p_old=${path%%' -> '*}
      p_new=${path#*' -> '}
      check_path "${p_old}"
      check_path "${p_new}"
      ;;
    *)
      check_path "${path}"
      ;;
  esac
done

# ---- 重跑 verify：逐条前后快照，越界写工作区即失败并停止 ----

n_verify=0
verify_stopped=0
if [ "${n_real_verify}" -gt 0 ]; then
  cg_snapshot "${work_dir}/before.txt"
  for vcmd in ${verifies}; do
    [ "${vcmd}" = 'N/A' ] && continue
    n_verify=$((n_verify + 1))
    if [ "${verify_stopped}" -eq 1 ]; then
      printf 'SKIP: verify[%d] 未执行（前序验证越界改动工作区，就地停止） %s\n' "${n_verify}" "${vcmd}"
      continue
    fi
    vrc=0
    vout=$(cd "${repo_root}" && sh -c "${vcmd}" 2>&1) || vrc=$?
    if [ "${vrc}" -eq 0 ]; then
      printf 'PASS: verify[%d] exit=0 %s\n' "${n_verify}" "${vcmd}"
    else
      printf 'FAIL: verify[%d] exit=%d %s\n' "${n_verify}" "${vrc}" "${vcmd}"
      failures=$((failures + 1))
      if [ -n "${vout}" ]; then
        printf '%s\n' "${vout}" | sed 's/^/  /'
      fi
    fi
    cg_snapshot "${work_dir}/after.txt"
    if cmp -s "${work_dir}/before.txt" "${work_dir}/after.txt"; then
      cp "${work_dir}/after.txt" "${work_dir}/before.txt"
    else
      cg_report "${n_verify}" "${vcmd}" "${work_dir}/before.txt" "${work_dir}/after.txt"
      failures=$((failures + 1))
      verify_stopped=1
      work_keep=1
    fi
  done
fi

# ---- 汇总 ----

if [ "${failures}" -eq 0 ]; then
  if [ "${record_only_seen}" -eq 1 ]; then
    printf 'check-gates: PASS（纯记录例外：%s；改动 %d 项全部在白名单内，verify N/A）\n' "${record_only}" "${n_files}"
  else
    printf 'check-gates: PASS（改动 %d 项全部在白名单内，verify %d 条全部通过）\n' "${n_files}" "${n_verify}"
  fi
  exit 0
fi
printf 'check-gates: FAIL（%d 项未通过）\n' "${failures}"
exit 1
