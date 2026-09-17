#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与行式门禁清单文件
#        （whitelist: 逗号分隔仓库根相对路径；verify: 逐行验证命令，可多行）。
# Output: 实际改动对白名单的逐项 PASS/FAIL 行、verify 命令逐条退出码记录与结尾汇总行；
#         exit 0 全部通过、1 有未过项、2 用法或环境错误。
# Pos: 分级交付道快道门禁核对器（REQ-20260904-011 / 票 26；行为基线 = development-process
#      模板 §12.5 道脚本承载注记）；POSIX sh、零外部依赖、严格只读（除打印外无写操作，
#      Git 仅使用只读子命令，无临时文件）。

# 用法、门禁清单行格式与输出格式见同目录 README.md。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

NL='
'

usage() {
  cat <<'USAGE'
用法: sh check-gates.sh [repo-root] <gates-file>
参数:
  repo-root   仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  gates-file  行式门禁清单文件，行格式（均以行首列为准）:
                whitelist: <逗号分隔的仓库根相对路径>
                verify: <验证命令>（一行一条，可多行）
                # 注释（行首 #）与空行忽略；其余行判格式错误。
  -h / --help 打印本用法。
退出码: 0 全部通过；1 有未过项（越界改动或 verify 失败）；2 用法或环境错误。
USAGE
}

die2() {
  printf 'check-gates: %s\n' "$1" >&2
  exit 2
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
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
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

# ---- 改动集 ⊆ 白名单 ----

status_out=$(git -c core.quotePath=false -C "${repo_root}" status --porcelain -uall) || die2 'git status 执行失败'

failures=0
n_files=0
seen=${NL}

check_path() {
  # $1=仓库根相对路径；依赖全局 whitelist/seen/failures/n_files
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

# ---- 重跑 verify 并记录退出码 ----

n_verify=0
for vcmd in ${verifies}; do
  n_verify=$((n_verify + 1))
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
done

# ---- 汇总 ----

if [ "${failures}" -eq 0 ]; then
  printf 'check-gates: PASS（改动 %d 项全部在白名单内，verify %d 条全部通过）\n' "${n_files}" "${n_verify}"
  exit 0
fi
printf 'check-gates: FAIL（%d 项未通过）\n' "${failures}"
exit 1
