#!/bin/sh
# Input: <NN> <implementation|review|commit> [repo-root]。NN 定位唯一任务票；repo-root
#        缺省按脚本落位推导。implementation/review 从票 dispatch 节渲染阶段合同；
#        commit 读取同票 dispatch.commit 六字段作为自动收尾合同（不渲染合同文件）。
# Output: implementation/review stdout 两行机器契约——`ticket-run: 站路径: <abs>` 与
#         `ticket-run: 合同文件: <abs>`，合同文件留 $TMPDIR 供主 agent 派发；implementation
#         缺站时经 worktree-add.sh 创建。commit 先核 Review 结论位，再经 check-gates.sh
#         核对白名单与范围命令，创建产品提交；RECORD_FLIP_AUTHORIZATION 明列索引翻转时
#         经 ticket-ops.sh flip-index 执行并创建纯记录提交。全程不 spawn 子 agent。
# Pos: 主 agent 三阶段唯一编排入口；只组合 contract-build/worktree-add/check-gates/
#      ticket-ops 原子层，不读取或改写票状态逻辑。POSIX sh；JSON 仅经 json-validator.py。
#      commit 不生成 User Review Checkpoint，不伪造用户裁决；Review pass 文件是提交硬前置。

set -eu
set -f

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 动态同目录加载
  # shellcheck disable=SC1091  # 共享库由运行时同目录定位，单文件分析无法跟随动态路径
  . "$_helper_script"
else
  printf 'ticket-run: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh ticket-run.sh <NN> <stage> [repo-root]
参数:
  NN           票号段（^[0-9]{2,}$），定位 facts/requirements/tickets/<NN>-<slug>.json
  stage        implementation | review | commit
  repo-root    主仓库根目录；缺省按脚本落位推导
输出:
  implementation/review：stdout 恰两行机器契约——
    ticket-run: 站路径: <绝对 worktree 路径>
    ticket-run: 合同文件: <绝对合同文件路径>
  主 agent 读取这两行后自行派发；脚本不 spawn 子 agent。implementation 缺站时经
  worktree-add.sh 创建；review 要求站已存在。合同文件保留在 $TMPDIR。
commit 自动合同（票 dispatch.commit）:
  REVIEW_PASS_CHECKPOINT   worktree 相对或站内绝对路径；结论只认「结论位」，须为下列之一：
                           (a) 首个非空行的整行记号 PASS / PASS_WITH_NOTES / FAIL
                               （大小写不敏感；仅可带尾随 ASCII 标点、空白或 Markdown
                               强调修饰 `*`、`_`、反引号、双引号）；
                           (b) 全文件唯一一行的显式标签 `Verdict: <结论>` /
                               `Review Verdict: <结论>` / `评审结论：<结论>`（半角或
                               全角冒号均可，值须以结论词开头，其后可跟标点或注记）。
                           其余行（尤其 `PASS:` 开头的证据行、正文里的 pass）一律不算
                           结论；无合法结论、结论多义或首行与标签冲突即 fail-closed 零提交。
  FILE_WHITELIST          逗号或换行分隔的仓库根相对文件清单
  COMMIT_MESSAGE          产品提交信息
  RECORD_FLIP_AUTHORIZATION
                           none，或逐行 flips: facts/requirements/tickets/index.json:index:<id>:<status>:<updated_at>
  SCOPE_CHECK_COMMAND     一行一条验证命令，经 check-gates.sh 重跑
  TICKET_ID              必须与票文件 id 一致
  commit 先创建白名单产品提交，再执行明列索引翻转并创建纯记录提交；无翻转则不建第二提交。
  commit 阶段不渲染阶段合同文件，不在 $TMPDIR 留产物。
退出码: 0 完成；1 fail-closed（合同、Review pass、门禁、白名单或提交未过）；
        2 用法或环境错误（参数、仓库根、原子层缺失）。
-h / --help  打印本用法
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
[ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
nn=$1
stage=$2
repo_root=${3:-}
case $stage in
  implementation|review|commit) ;;
  *) die2 "stage 须为 implementation|review|commit: ${stage}" ;;
esac
printf '%s' "$nn" | LC_ALL=C grep -Eq '^[0-9]{2,}$' || die2 "NN 不合口径: ${nn}"

if [ -n "$repo_root" ]; then
  _rr=$(resolve_repo_root "$repo_root") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "$_rr" ] || die2 '仓库根不可用，请显式传 repo-root'
repo_root=$_rr
[ -d "$repo_root" ] || die2 "仓库根不存在: ${repo_root}"
repo_root=$(CDPATH='' cd -- "$repo_root" && pwd -P) || die2 '仓库根物理路径不可解析'
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || die2 '脚本目录不可解析'

_engine="${repo_root}/agent-up/scripts/json-validator.py"
[ -f "$_engine" ] || _engine="${script_dir}/json-validator.py"
[ -f "$_engine" ] || die2 "唯一 JSON 引擎缺失: ${repo_root}/agent-up/scripts/json-validator.py 与 ${script_dir}/json-validator.py"
contract_build="${script_dir}/contract-build.sh"
[ -r "$contract_build" ] || die2 "原子层缺失: ${contract_build}"

issues_dir="${repo_root}/facts/requirements/tickets"
[ -d "$issues_dir" ] || die1 "票目录不存在: ${issues_dir}"
set +f
set -- "${issues_dir}/${nn}"-*.json
[ $# -eq 1 ] || die1 "票号段 ${nn} 定位命中 $# 件，须恰一命中"
ticket_file=$1
set -f
[ -f "$ticket_file" ] || die1 "票号段 ${nn} 无命中: ${issues_dir}/${nn}-*.json"
ticket_id=$(basename "$ticket_file" .json)

repo_parent=$(CDPATH='' cd -- "$repo_root/.." && pwd -P) || die2 '仓库根父目录不可解析'
repo_name=$(basename "$repo_root")
worktree="${repo_parent}/${repo_name}-wt/wt${nn}"

if [ "$stage" != commit ]; then
  contract_file=$(mktemp "${TMPDIR:-/tmp}/ticket-run-${nn}-${stage}.XXXXXX") || die2 '合同临时文件创建失败'
  if ! sh "$contract_build" "$stage" "$nn" "$repo_root" > "$contract_file"; then
    rm -f "$contract_file"
    die1 '阶段合同渲染失败（contract-build fail-closed，未产出站路径或执行提交）'
  fi
  if [ "$stage" = implementation ] && [ ! -d "$worktree" ]; then
    worktree_add="${script_dir}/worktree-add.sh"
    [ -r "$worktree_add" ] || die2 "建站原子层缺失: ${worktree_add}"
    (cd "$repo_root" && sh "$worktree_add" "$contract_file" >&2) || die1 "worktree 创建失败: ${worktree}"
  fi
  [ -d "$worktree" ] || die1 "worktree 不存在: ${worktree}"
  git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1 || die1 "站路径不是有效 Git worktree: ${worktree}"
  printf 'ticket-run: 站路径: %s\n' "$worktree"
  printf 'ticket-run: 合同文件: %s\n' "$contract_file"
  exit 0
fi

# ---- commit：读取 dispatch.commit 六字段并在任何写入前完成全部预检 ----

dispatch_get() {
  python3 "$_engine" json get "$ticket_file" "dispatch.commit.$1" || die1 "dispatch.commit 缺字段: $1"
}

review_checkpoint=$(dispatch_get REVIEW_PASS_CHECKPOINT)
file_whitelist=$(dispatch_get FILE_WHITELIST)
commit_message=$(dispatch_get COMMIT_MESSAGE)
record_authorization=$(dispatch_get RECORD_FLIP_AUTHORIZATION)
scope_check=$(dispatch_get SCOPE_CHECK_COMMAND)
dispatch_ticket_id=$(dispatch_get TICKET_ID)
[ "$dispatch_ticket_id" = "$ticket_id" ] || die1 "dispatch.commit.TICKET_ID 与票文件不符: ${dispatch_ticket_id} ≠ ${ticket_id}"

[ -d "$worktree" ] || die1 "commit 站不存在: ${worktree}"
git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1 || die1 "commit 站不是有效 Git worktree: ${worktree}"
worktree=$(CDPATH='' cd -- "$worktree" && pwd -P) || die2 'worktree 物理路径不可解析'

case $review_checkpoint in
  /*) checkpoint_abs=$review_checkpoint ;;
  ..|../*|*/..|*/../*|./*|*.|*/./*) die1 "REVIEW_PASS_CHECKPOINT 含非法路径段: ${review_checkpoint}" ;;
  *) checkpoint_abs="${worktree}/${review_checkpoint}" ;;
esac
[ -f "$checkpoint_abs" ] || die1 "Review pass 文件不存在: ${review_checkpoint}"
[ ! -L "$checkpoint_abs" ] || die1 "Review pass 文件不得为 symlink: ${review_checkpoint}"
checkpoint_real=$(realpath "$checkpoint_abs" 2>/dev/null) || die1 'Review pass 文件 realpath 解析失败'
case $checkpoint_real in
  "$worktree"/*) ;;
  *) die1 "Review pass 文件越出 worktree: ${review_checkpoint}" ;;
esac
# 结论位判定：整行记号（首个非空行）或全文件唯一一行 `Verdict:` / `评审结论` 标签；
# `PASS:` 开头的证据行一律不算结论。
verdict=$(awk '
function token_whole(s) {
  if (s ~ /^pass_with_notes[[:punct:][:space:]]*$/) return "PASS_WITH_NOTES"
  if (s ~ /^pass[[:punct:][:space:]]*$/) return "PASS"
  if (s ~ /^fail[[:punct:][:space:]]*$/) return "FAIL"
  return ""
}
function token_label(s) {
  if (s ~ /^pass_with_notes([^a-z0-9_]|$)/) return "PASS_WITH_NOTES"
  if (s ~ /^pass([^a-z0-9_]|$)/) return "PASS"
  if (s ~ /^fail([^a-z0-9_]|$)/) return "FAIL"
  return ""
}
{
  line = $0
  gsub(/[*`"]/, "", line)
  gsub(/：/, ":", line)
  sub(/^[ \t]+/, "", line)
  sub(/[ \t]+$/, "", line)
  sub(/^([-+>][ \t]+)+/, "", line)
  sub(/^_+/, "", line)
  sub(/_+$/, "", line)
  low = tolower(line)
  if (!seen && line != "") { first = low; seen = 1 }
  if (low ~ /^(verdict|review verdict|评审结论)[ \t]*:/) {
    value = low
    sub(/^(verdict|review verdict|评审结论)[ \t]*:[ \t]*/, "", value)
    labels++
    mark = token_label(value)
    if (labels == 1) { label_mark = mark } else if (mark != label_mark) { conflict = 1 }
  }
}
END {
  fl = seen ? token_whole(first) : ""
  if (labels > 1 || conflict) { print "AMBIGUOUS"; exit }
  if (labels == 1) {
    if (label_mark == "" || (fl != "" && fl != label_mark)) { print "AMBIGUOUS"; exit }
    print label_mark; exit
  }
  if (fl == "") { print "UNKNOWN"; exit }
  print fl
}' "$checkpoint_abs") || die1 "Review pass 结论位解析失败: ${review_checkpoint}"
case $verdict in
  PASS|PASS_WITH_NOTES) ;;
  FAIL) die1 "最终 Review 结论不是 PASS/PASS_WITH_NOTES: FAIL（${review_checkpoint}）" ;;
  *) die1 "Review 结论位无法确定（只认首行或全文件唯一 Verdict: 行，证据行不作数）: ${review_checkpoint}" ;;
esac

# 归一化白名单：一行一文件；路径边界先于 check-gates 与 git add。
whitelist_paths=$(printf '%s\n' "$file_whitelist" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF')
[ -n "$whitelist_paths" ] || die1 'FILE_WHITELIST 为空'
worktree_real=$(realpath "$worktree" 2>/dev/null) || die2 'worktree realpath 解析失败'
IFS=$NL
for path in $whitelist_paths; do
  case $path in
    /*|..|../*|*/..|*/../*|./*|*.|*/./*|*"${TAB}"*) die1 "白名单路径形态非法: ${path}" ;;
  esac
  [ -f "${worktree}/${path}" ] || die1 "白名单文件不存在: ${path}"
  [ ! -L "${worktree}/${path}" ] || die1 "白名单文件不得为 symlink: ${path}"
  path_real=$(realpath "${worktree}/${path}" 2>/dev/null) || die1 "白名单文件 realpath 解析失败: ${path}"
  case $path_real in
    "$worktree_real"/*) ;;
    *) die1 "白名单文件越出 worktree: ${path}" ;;
  esac
done

# 记录授权预检：只接受 none 或索引专用 flips；写入一律委托 ticket-ops。
record_flips=''
case $record_authorization in
  none|N/A) record_authorization='' ;;
esac
if [ -n "$record_authorization" ]; then
  ticket_ops="${script_dir}/ticket-ops.sh"
  [ -r "$ticket_ops" ] || die2 "索引翻转原子层缺失: ${ticket_ops}"
  [ -f "${worktree}/facts/requirements/tickets/index.json" ] || die1 '记录翻转目标 index.json 不存在'
  for line in $record_authorization; do
    case $line in
      'flips: facts/requirements/tickets/index.json:index:'*) ;;
      *) die1 "RECORD_FLIP_AUTHORIZATION 只接受 none 或索引专用 flips 行: ${line}" ;;
    esac
    rest=${line#flips: facts/requirements/tickets/index.json:index:}
    flip_id=${rest%%:*}
    rest2=${rest#*:}
    case $rest2 in
      "$rest") die1 "索引翻转缺 status/updated_at: ${line}" ;;
    esac
    flip_status=${rest2%%:*}
    flip_updated=${rest2#*:}
    case $flip_updated in
      "$rest2"|*:'') die1 "索引翻转缺 updated_at: ${line}" ;;
    esac
    [ "$flip_id" = "$ticket_id" ] || die1 "索引翻转 id 与票不符: ${flip_id} ≠ ${ticket_id}"
    printf '%s' "$flip_status" | grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || die1 "索引翻转 status 非法: ${flip_status}"
    printf '%s' "$flip_updated" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' || die1 "索引翻转 updated_at 非法: ${flip_updated}"
    record_flips="${record_flips}${line}${NL}"
  done
fi

check_gates="${script_dir}/check-gates.sh"
[ -r "$check_gates" ] || die2 "门禁原子层缺失: ${check_gates}"
gate_file=$(mktemp "${TMPDIR:-/tmp}/ticket-run-gates.XXXXXX") || die2 '门禁临时文件创建失败'
cleanup() {
  rm -f "$gate_file"
}
trap cleanup EXIT HUP INT TERM
{
  for path in $whitelist_paths; do
    printf 'whitelist: %s\n' "$path"
  done
  printf '%s\n' "$scope_check" | while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    printf 'verify: %s\n' "$line"
  done
} > "$gate_file"
sh "$check_gates" "$worktree" "$gate_file" || die1 'commit 范围或验证门禁未过，零提交零记录写入'

# ---- 产品提交：只暂存白名单，防御性核对暂存面不越界 ----

for path in $whitelist_paths; do
  git -C "$worktree" add -- "$path" || die1 "git add 失败: ${path}"
done
staged=$(git -c core.quotePath=false -C "$worktree" diff --cached --name-only)
[ -n "$staged" ] || die1 '白名单内无实际改动，不创建空提交'
for path in $staged; do
  needle="${NL}${path}${NL}"
  case "${NL}${whitelist_paths}${NL}" in
    *"$needle"*) ;;
    *) die1 "暂存内容越出白名单: ${path}" ;;
  esac
done
git -C "$worktree" commit -m "$commit_message" || die1 '产品提交创建失败'
product_commit=$(git -C "$worktree" rev-parse HEAD)
printf 'ticket-run: 产品提交: %s\n' "$product_commit"

# ---- 纯记录提交：索引与投影只经 ticket-ops 生成后收编 ----

if [ -n "$record_flips" ]; then
  for line in $record_flips; do
    rest=${line#flips: facts/requirements/tickets/index.json:index:}
    flip_id=${rest%%:*}
    rest2=${rest#*:}
    flip_status=${rest2%%:*}
    flip_updated=${rest2#*:}
    sh "$ticket_ops" "$worktree" flip-index --id "$flip_id" --status "$flip_status" --updated-at "$flip_updated" || \
      die1 "索引翻转代理失败——产品提交 ${product_commit} 已创建、记录提交未创建"
  done
  git -C "$worktree" add -- facts/requirements/tickets/index.json facts/requirements/tickets/progress-current.md || die1 '记录文件暂存失败'
  git -C "$worktree" commit -m "chore(ticket): 记录翻转 — ${commit_message}" || die1 '纯记录提交创建失败'
  record_commit=$(git -C "$worktree" rev-parse HEAD)
  printf 'ticket-run: 记录提交: %s\n' "$record_commit"
fi
printf 'ticket-run: PASS（commit 完成；Review pass 已核对，产品提交与授权记录翻转分离）\n'
