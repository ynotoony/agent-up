#!/bin/sh
# Input: 仓库根目录（唯一参数）。守卫对象（票 58）：
#        docs/changes.jsonl 与 docs/agent/micro.jsonl——只追加账本（Record 类，一行一事实，
#        懒创建）：工作树内容相对 HEAD 旧 blob 必须为尾部追加（旧 blob 内容为新内容前缀），
#        中间插入/改写历史行/截断/删除即违规，FAIL 指名文件与首个违规行号（新文件行号）；
#        docs/progress.md（未迁移仓稳态）与 docs/archive/progress.md（票 87 迁移后继）
#        ——冻结历史档案（指针注记后零写入，development-process §11）：任何 diff 即
#        违规；迁移窗口（HEAD 尚无后继路径）以后继工作树内容与 HEAD 旧路径逐字节
#        一致为承继通过。文件不存在跳过（懒创建语义）；无 Git 基线（无 HEAD）输出
#        WARN 退出 0（票 49 先例：不硬猜基线）。
# Output: 逐文件 OK/SKIP/FAIL 行与结尾汇总：exit 0 全部通过（含跳过与 WARN）；exit 1
#         存在违规；exit 2 用法或环境错误（口径同 ticket-ops.sh：0 完成 / 1 fail-closed /
#         2 用法环境）。
# Pos: Record 只追加守卫（票 58；承接票 54 候选 C3「Record 行级保护」口径）：可作 verify
#      命令加入门禁清单。POSIX sh、零外部依赖（仅 POSIX 标准工具与 Git 只读子命令：
#      rev-parse/cat-file/show——不含任何 Git 写操作）。核对基线＝工作树 vs HEAD
#      （git diff 同口径；未跟踪且 HEAD 无同名的新文件按懒创建全追加语义放行）。

# 用法、守卫口径与维护规则见同目录 README.md 专节。

set -eu

usage() {
  cat <<'USAGE'
用法: sh check-append-only.sh <repo-root>
参数:
  repo-root  仓库根目录。
守卫对象:
  docs/changes.jsonl、docs/agent/micro.jsonl  只追加账本：HEAD 旧 blob 须为新内容前缀
                                              （尾部追加合法）；中间插入/改写历史行/
                                              截断/删除即 FAIL（指名文件与首个违规行号）。
  docs/progress.md（迁移后继 docs/archive/progress.md，票 87）
                                              冻结历史档案：任何 diff 即 FAIL；
                                              迁移窗口按 HEAD 旧路径承继基线核对。
  文件不存在跳过（懒创建语义）；无 Git 基线（无 HEAD）WARN 退出 0（票 49 先例）。
退出码: 0 通过（含跳过与 WARN）；1 存在违规；2 用法或环境错误。
USAGE
}

die2() {
  printf 'check-append-only: %s\n' "$1" >&2
  exit 2
}

fail1() {
  printf 'check-append-only: FAIL: %s\n' "$1"
  violations=$((violations + 1))
}

[ $# -eq 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
esac
repo_root=$1
[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${repo_root}"
if ! git -C "${repo_root}" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  printf 'check-append-only: WARN: 无 Git 基线（无 HEAD），只追加与冻结核对跳过（票 49 先例：不硬猜基线）\n'
  exit 0
fi

t_dir=${TMPDIR:-/tmp}
tmp_old=$(mktemp "${t_dir%/}/appendold.XXXXXX")
tmp_new=$(mktemp "${t_dir%/}/appendnew.XXXXXX")
cleanup() { rm -f "${tmp_old}" "${tmp_new}"; }
trap cleanup EXIT HUP INT TERM

violations=0

# 首个违规行号定位：旧 blob 行与新文件行逐一相等比对，输出首个不等的新文件行号；
# 新文件行数少于旧 blob（截断）时输出缺失位置；无行级差异时无输出（差异仅在尾行
# 悬挂换行等字节级情形，由调用方字节计数表述）。恒 exit 0（行号经 stdout 传递，
# 避免 set -e 下命令替换非零退出歧义）。
first_bad_line() {
  # $1=旧 blob 文件 $2=新文件
  LC_ALL=C awk '
    NR == FNR { old[FNR] = $0; on = FNR; next }
    FNR <= on && $0 != old[FNR] { print FNR; found = 1; exit }
    END { if (!found && FNR < on) print FNR + 1 }
  ' "$1" "$2"
}

check_append_file() {
  # $1=仓库根相对路径（只追加账本语义）
  _f=$1
  _old_here=0
  if git -C "${repo_root}" cat-file -e "HEAD:${_f}" 2>/dev/null; then
    git -C "${repo_root}" show "HEAD:${_f}" > "${tmp_old}"
    _old_here=1
  else
    : > "${tmp_old}"
  fi
  if [ ! -f "${repo_root}/${_f}" ]; then
    if [ "${_old_here}" -eq 1 ]; then
      fail1 "${_f} 在 HEAD 存在但工作树缺失（只追加账本不得删除历史）"
    else
      printf 'check-append-only: SKIP: %s（不存在，懒创建语义）\n' "${_f}"
    fi
    return 0
  fi
  if [ "${_old_here}" -eq 0 ]; then
    printf 'check-append-only: OK: %s（工作树新建，全部行为追加，懒创建语义）\n' "${_f}"
    return 0
  fi
  cp "${repo_root}/${_f}" "${tmp_new}"
  _old_size=$(wc -c < "${tmp_old}" | tr -d ' ')
  _new_size=$(wc -c < "${tmp_new}" | tr -d ' ')
  _old_lines=$(wc -l < "${tmp_old}" | tr -d ' ')
  if [ "${_new_size}" -lt "${_old_size}" ]; then
    _bad=$(first_bad_line "${tmp_old}" "${tmp_new}")
    if [ -n "${_bad}" ]; then
      fail1 "${_f} 内容相对 HEAD 截断/改写（旧 blob ${_old_size} 字节 → 新 ${_new_size} 字节），首个违规行号 ${_bad}（新文件行号）"
    else
      fail1 "${_f} 内容相对 HEAD 截断（旧 blob ${_old_size} 字节 → 新 ${_new_size} 字节，差异在尾行悬挂换行等字节级情形，历史行 ${_old_lines} 行不完整）"
    fi
    return 0
  fi
  if head -c "${_old_size}" "${tmp_new}" | cmp -s - "${tmp_old}"; then
    _new_lines=$(wc -l < "${tmp_new}" | tr -d ' ')
    printf 'check-append-only: OK: %s（尾部追加 %d 行，历史前缀核对通过）\n' "${_f}" "$((_new_lines - _old_lines))"
    return 0
  fi
  _bad=$(first_bad_line "${tmp_old}" "${tmp_new}")
  fail1 "${_f} 历史行被改写或中间插入（HEAD 旧 blob 非新内容前缀），首个违规行号 ${_bad:-?}（新文件行号）"
}

check_frozen_file() {
  # $1=仓库根相对路径（冻结语义：任何 diff 即违规）
  # $2=可选迁移后继路径（票 87：冻结件自 docs/ 根迁 docs/archive/；缺省无后继语义）
  #    ——后继两侧皆缺 → 静默（家族缺席由 $1 的 SKIP 行承载）；
  #      后继基线＝HEAD:$2；HEAD 无 $2 时退 HEAD:$1（迁移窗口承继基线）；
  #      $1 在 HEAD 有而工作树缺 → 后继存在且承继核对通过视为已迁移（OK），否则按删除违规。
  _f=$1
  _suc=${2:-}
  _old_here=0
  if git -C "${repo_root}" cat-file -e "HEAD:${_f}" 2>/dev/null; then
    git -C "${repo_root}" show "HEAD:${_f}" > "${tmp_old}"
    _old_here=1
  else
    : > "${tmp_old}"
  fi
  if [ ! -f "${repo_root}/${_f}" ]; then
    if [ "${_old_here}" -eq 1 ]; then
      _mig_ok=0
      if [ -n "${_suc}" ] && [ -f "${repo_root}/${_suc}" ]; then
        if git -C "${repo_root}" cat-file -e "HEAD:${_suc}" 2>/dev/null; then
          git -C "${repo_root}" show "HEAD:${_suc}" > "${tmp_new}"
          if cmp -s "${tmp_new}" "${repo_root}/${_suc}"; then
            _mig_ok=1
          fi
        elif cmp -s "${tmp_old}" "${repo_root}/${_suc}"; then
          _mig_ok=1
        fi
      fi
      if [ "${_mig_ok}" -eq 1 ]; then
        printf 'check-append-only: OK: %s（已迁移至 %s，内容承继核对通过，票 87）\n' "${_f}" "${_suc}"
      else
        fail1 "${_f} 冻结历史档案在 HEAD 存在但工作树缺失（冻结档案零写入，不得删除）"
      fi
    else
      printf 'check-append-only: SKIP: %s（不存在）\n' "${_f}"
    fi
  elif [ "${_old_here}" -eq 0 ]; then
    fail1 "${_f} 冻结历史档案相对 HEAD 出现新内容（冻结档案零写入）"
  elif cmp -s "${tmp_old}" "${repo_root}/${_f}"; then
    printf 'check-append-only: OK: %s（与 HEAD 一致，零 diff）\n' "${_f}"
  else
    fail1 "${_f} 冻结历史档案出现 diff（冻结档案零写入，development-process §11）"
  fi
  [ -n "${_suc}" ] || return 0
  _suc_wt=0
  if [ -f "${repo_root}/${_suc}" ]; then
    _suc_wt=1
  fi
  _suc_head=0
  if git -C "${repo_root}" cat-file -e "HEAD:${_suc}" 2>/dev/null; then
    _suc_head=1
  fi
  if [ "${_suc_wt}" -eq 0 ] && [ "${_suc_head}" -eq 0 ]; then
    return 0
  fi
  if [ "${_suc_head}" -eq 1 ]; then
    git -C "${repo_root}" show "HEAD:${_suc}" > "${tmp_new}"
    if [ "${_suc_wt}" -eq 0 ]; then
      fail1 "${_suc} 冻结历史档案在 HEAD 存在但工作树缺失（冻结档案零写入，不得删除）"
      return 0
    fi
    if cmp -s "${tmp_new}" "${repo_root}/${_suc}"; then
      printf 'check-append-only: OK: %s（与 HEAD 一致，零 diff）\n' "${_suc}"
    else
      fail1 "${_suc} 冻结历史档案出现 diff（冻结档案零写入，development-process §11）"
    fi
    return 0
  fi
  if [ "${_suc_wt}" -eq 1 ] && [ "${_old_here}" -eq 1 ] && cmp -s "${tmp_old}" "${repo_root}/${_suc}"; then
    printf 'check-append-only: OK: %s（迁移承继：与 HEAD %s 逐字节一致，票 87）\n' "${_suc}" "${_f}"
  else
    fail1 "${_suc} 冻结历史档案相对 HEAD 出现新内容（冻结档案零写入）"
  fi
  return 0
}

check_append_file 'docs/changes.jsonl'
check_append_file 'docs/agent/micro.jsonl'
check_frozen_file 'docs/progress.md' 'docs/archive/progress.md'

if [ "${violations}" -gt 0 ]; then
  printf 'check-append-only: FAIL（%d 个文件违规）\n' "${violations}"
  exit 1
fi
printf 'check-append-only: PASS\n'
