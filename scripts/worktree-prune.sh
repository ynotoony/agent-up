#!/bin/sh
# Input: 仓库根（缺省＝当前目录所在 Git 仓库；可用 --repo-root 覆盖）与参数：--apply（执行删除）、
#        --force（一并处理有改动/未合并的站）、--repo-root <dir>、-h/--help。
# Output: 工作树生命周期报告——三类判定（可清＝非主检出＋工作区干净＋分支已并入 main 或票
#         status=done；跳过＝有未提交改动；保留＝分支未合并且票未 done）逐项列出路径/分支/体积，
#         并给可清项数与合计回收体积；dry-run 缺省零删除，--apply 才执行 worktree remove --force
#         与 branch -d（未合并且 --force 时 -D）；失败逐项报错并非零退出；不写账本。
# Pos: 工作树清理独立命令（票 279；清理不依赖合并路径，手动调用）。判据单源：dry-run 与
#      --apply 共用同一分类结果；幂等可重复执行。与 merge-ticket.sh 分工：合并负责强制清场
#      自己的站，本命令负责事后清扫全部残留；不接会话开始与 pre-push（用户 2026-11-06 明确）。
#      POSIX sh、只读 git 查询（--apply 才写）、零网络依赖。
set -eu

prog=worktree-prune
do_apply=0
do_force=0
repo_root=''
t_dir=$(printenv TMPDIR 2>/dev/null || true)
[ -n "$t_dir" ] || t_dir=/tmp

usage() {
  cat <<USAGE
用法: sh worktree-prune.sh [--apply] [--force] [--repo-root <dir>]
参数:
  --apply          执行删除（缺省 dry-run 零删除）
  --force          一并处理「有未提交改动」与「分支未合并/票未 done」的站（worktree remove --force＋branch -D）
  --repo-root <dir> 仓库根目录（缺省＝当前目录所在 Git 仓库的主检出根）
  -h / --help      打印本用法
判据: 非主检出 ＋ 工作区干净（git status --porcelain 为空）＋（分支已并入 main 或索引中该票 status=done）
退出码: 0 成功（含无候选）；1 删除失败；2 用法或环境错误
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    --apply) do_apply=1; shift ;;
    --force) do_force=1; shift ;;
    --repo-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; repo_root=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%s: 未知参数: %s
' "$prog" "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$repo_root" ]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf '%s: 错误：当前目录不在 Git 仓库内（或用 --repo-root 指定）
' "$prog" >&2
    exit 2
  }
fi
[ -d "$repo_root" ] || { printf '%s: 错误：仓库根不存在: %s
' "$prog" "$repo_root" >&2; exit 2; }
git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || {
  printf '%s: 错误：不是 Git 仓库: %s
' "$prog" "$repo_root" >&2
  exit 2
}
main_wt=$(git -C "$repo_root" worktree list --porcelain | awk 'NR == 1 && $1 == "worktree" { print $2; exit }')
[ -n "$main_wt" ] || { printf '%s: 错误：无法识别主检出
' "$prog" >&2; exit 2; }
index_json="$repo_root/facts/requirements/tickets/index.json"

tmpdir=$(mktemp -d "$t_dir/wtprune.XXXXXX") || exit 2
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
prune_list="$tmpdir/prune"
skip_list="$tmpdir/skip"
keep_list="$tmpdir/keep"
: > "$prune_list"
: > "$skip_list"
: > "$keep_list"

ticket_done() {
  _td_nn=$(printf '%s' "$1" | sed -n 's|^refs/heads/ticket/\([0-9][0-9]*\)-.*|\1|p')
  [ -n "$_td_nn" ] || return 1
  [ -f "$index_json" ] || return 1
  LC_ALL=C awk -v id="$_td_nn-" '
    index($0, "\"id\": \"" id) && index($0, "\"status\": \"done\"") { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$index_json" >/dev/null 2>&1
}

wt_rows="$tmpdir/rows"
git -C "$repo_root" worktree list --porcelain | LC_ALL=C awk '
  $1 == "worktree" { if (p != "") print p "	" (b == "" ? "-" : b) "	" d; p = $2; b = ""; d = 0; next }
  $1 == "branch" { b = $2 }
  $1 == "detached" { d = 1 }
  END { if (p != "") print p "	" (b == "" ? "-" : b) "	" d }
' > "$wt_rows"

total=0
while IFS="$(printf '	')" read -r wt_path wt_branch wt_detached; do
  [ -n "$wt_path" ] || continue
  case $wt_branch in '-') wt_branch='' ;; esac
  wt_branch_field=$wt_branch
  [ -n "$wt_branch_field" ] || wt_branch_field='-'
  [ -n "$wt_detached" ] || wt_detached=0
  [ "$wt_path" = "$main_wt" ] && continue
  total=$((total + 1))
  if [ ! -d "$wt_path" ]; then
    printf '%s	%s	0	missing
' "$wt_path" "$wt_branch_field" >> "$keep_list"
    continue
  fi
  wt_kb=$(du -sk "$wt_path" 2>/dev/null | awk '{ print $1 + 0 }')
  [ -n "$wt_kb" ] || wt_kb=0
  if [ "$wt_detached" -eq 1 ] || [ -z "$wt_branch" ]; then
    printf '%s	%s	%s	detached
' "$wt_path" "$wt_branch_field" "$wt_kb" >> "$keep_list"
    continue
  fi
  if [ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]; then
    printf '%s	%s	%s	dirty
' "$wt_path" "$wt_branch_field" "$wt_kb" >> "$skip_list"
    continue
  fi
  if git -C "$repo_root" merge-base --is-ancestor "$wt_branch" main >/dev/null 2>&1     || ticket_done "$wt_branch"; then
    printf '%s	%s	%s	merged
' "$wt_path" "$wt_branch_field" "$wt_kb" >> "$prune_list"
  else
    printf '%s	%s	%s	unmerged
' "$wt_path" "$wt_branch_field" "$wt_kb" >> "$keep_list"
  fi
done < "$wt_rows"

fmt_size() {
  LC_ALL=C awk -v kb="$1" 'BEGIN { if (kb + 0 >= 1024) printf "%.1f MB", (kb + 0) / 1024; else printf "%d KB", kb + 0 }'
}
list_count() { LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$1"; }
list_kb() { LC_ALL=C awk -F'	' 'NF { n += $3 } END { print n + 0 }' "$1"; }
print_list() {
  while IFS="$(printf '	')" read -r _p _b _k _why; do
    [ -n "$_p" ] || continue
    [ "$_b" = '-' ] && _b=''
    if [ -n "$_b" ]; then
      printf '  - %s（分支 %s，约 %s）
' "$_p" "$_b" "$(fmt_size "$_k")"
    else
      printf '  - %s（无绑定分支，约 %s）
' "$_p" "$(fmt_size "$_k")"
    fi
  done < "$1"
}

prune_n=$(list_count "$prune_list")
skip_n=$(list_count "$skip_list")
keep_n=$(list_count "$keep_list")
prune_kb=$(list_kb "$prune_list")
skip_kb=$(list_kb "$skip_list")
keep_kb=$(list_kb "$keep_list")
select_n=$prune_n
select_kb=$prune_kb
if [ "$do_force" -eq 1 ]; then
  select_n=$((prune_n + skip_n + keep_n))
  select_kb=$((prune_kb + skip_kb + keep_kb))
fi

printf '%s: 主检出: %s
' "$prog" "$main_wt"
printf '%s: 工作树: 共 %d 个（主检出 1，非主检出 %d）
' "$prog" "$((total + 1))" "$total"
printf '%s: 可清 %d 个（约 %s）
' "$prog" "$prune_n" "$(fmt_size "$prune_kb")"
print_list "$prune_list"
printf '%s: 跳过 %d 个（工作区有未提交改动；--force 才处理；约 %s）
' "$prog" "$skip_n" "$(fmt_size "$skip_kb")"
print_list "$skip_list"
printf '%s: 保留 %d 个（分支未并入 main 且票未 done；--force 才处理；约 %s）
' "$prog" "$keep_n" "$(fmt_size "$keep_kb")"
print_list "$keep_list"
if [ "$do_force" -eq 1 ]; then
  printf '%s: 处理范围: --force（可清＋跳过＋保留一并处理：%d 个，约 %s）
' "$prog" "$select_n" "$(fmt_size "$select_kb")"
fi
if [ "$do_apply" -eq 1 ]; then
  _scope_text='执行删除'
else
  _scope_text='dry-run，未删除任何内容'
fi
printf '%s: 合计回收约 %s（%s）
' "$prog" "$(fmt_size "$select_kb")" "$_scope_text"

[ "$do_apply" -eq 1 ] || exit 0

applied=0
applied_kb=0
failed=0
apply_one() {
  _a_p=$1
  _a_b=$2
  _a_k=$3
  # worktree list 的 branch 为完整 ref；git branch -d/-D 只接受短名
  [ "$_a_b" = '-' ] && _a_b=''
  _a_b=$(printf '%s' "$_a_b" | sed 's|^refs/heads/||')
  if ! git -C "$repo_root" worktree remove --force "$_a_p" >/dev/null 2>&1; then
    printf '%s: 错误：worktree 强制移除失败: %s
' "$prog" "$_a_p" >&2
    failed=$((failed + 1))
    return 0
  fi
  if [ -n "$_a_b" ]; then
    if git -C "$repo_root" merge-base --is-ancestor "$_a_b" main >/dev/null 2>&1; then
      if ! git -C "$repo_root" branch -d "$_a_b" >/dev/null 2>&1; then
        printf '%s: 错误：分支删除失败（-d）: %s
' "$prog" "$_a_b" >&2
        failed=$((failed + 1))
        return 0
      fi
    else
      if ! git -C "$repo_root" branch -D "$_a_b" >/dev/null 2>&1; then
        printf '%s: 错误：分支删除失败（-D）: %s
' "$prog" "$_a_b" >&2
        failed=$((failed + 1))
        return 0
      fi
    fi
  fi
  applied=$((applied + 1))
  applied_kb=$((applied_kb + _a_k))
  _a_b_disp=$_a_b
  [ -n "$_a_b_disp" ] || _a_b_disp='无'
  printf '%s: 已删除: %s（分支 %s）
' "$prog" "$_a_p" "$_a_b_disp"
}
while IFS="$(printf '	')" read -r _p _b _k _why; do
  [ -n "$_p" ] || continue
  apply_one "$_p" "$_b" "$_k"
done < "$prune_list"
if [ "$do_force" -eq 1 ]; then
  while IFS="$(printf '	')" read -r _p _b _k _why; do
    [ -n "$_p" ] || continue
    apply_one "$_p" "$_b" "$_k"
  done < "$skip_list"
  while IFS="$(printf '	')" read -r _p _b _k _why; do
    [ -n "$_p" ] || continue
    apply_one "$_p" "$_b" "$_k"
  done < "$keep_list"
fi
if [ "$failed" -gt 0 ]; then
  printf '%s: FAIL：%d 项删除失败（已删除 %d 个，回收约 %s）
' "$prog" "$failed" "$applied" "$(fmt_size "$applied_kb")" >&2
  exit 1
fi
printf '%s: 完成：删除 %d 个，回收约 %s
' "$prog" "$applied" "$(fmt_size "$applied_kb")"
exit 0
