#!/bin/sh
# Input: 主仓根目录、票分支名（ticket/ 前缀）、票 id 三参数；主仓须干净，各票票务
#        写入由调用方按票独立落账；合并前另取票分支绑定 worktree 作审查证据审计目标
#        （ticket-audit.sh <NN> --repo <worktree> --operation merge）。
# Output: 单票合并收口逐步输出——证据门三值结论、实际合并模式（fast-forward
#         或 no-ff）、合并提交哈希（审计要点四）、清场（worktree remove＋branch -d）
#         或冲突停等报告（冲突文件清单＋abort 清现场确认）；退出码 0 成功（已清场）/
#         1 fail-closed／2 用法环境错误／3 真冲突停等（已 abort 清现场，worktree 保留）。
# Pos: 合并站独立脚本（票 93；车道＝全道，lane-commit.sh 同款脚本化收尾解耦）：
#      ff 失败自动降级 --no-ff，仍冲突则 git merge --abort 清现场（审计要点二，禁悬挂
#      merge-in-progress）；成功路径无条件清场；主仓不干净即拒绝；下一行是票 93 历史注记。
#      本脚本——由调用方 chain 翻转前查 index 现值（审计要点三，票 93 四要点分工）；
#      票 237 起合并前置证据门：只认 ticket-audit --operation merge conformant，未提交/
#      diff 失配/unknown 一律拒绝（缺证据即 decision-required，不采信自报 PASS）；
#      审计目标＝票分支绑定 worktree（主检出 HEAD 是 main，证据在票分支 HEAD 上）。
#      ff 断言语义不波及 export-payload.sh（那边保留自有 ff 断言）。POSIX sh、
#      set -eu fail-closed、零外部依赖（git＋POSIX 工具）；已知限制：worktree 路径含
#      空白不受理（家族先例 S4 同款口径）。行为语义变化经 Review 门禁。
#      票 237 补正：actual_time 预检读被合并票分支 tip（主检出仅回退）；证据允许集与
#      done 门同源（含票面声明的规范 Review Checkpoint md，判定在 common-helpers）。
#      记录面允许集（C0 修复）：P04 允许集除索引/投影/票面 cp md 外，另纳入
#      facts/project/changes.jsonl 与 facts/requirements/tickets/README.md——两者是随
#      每次票务操作必然变动的记录面派生件（账本行追加、README 状态列同步），不是被
#      审阅的实现面；主线在分支期间落记录面提交不应被 P04 判成「审阅边界被污染」。

# 用法见同目录 README.md「merge-ticket.sh」节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || {
  printf 'merge-ticket: 脚本目录不可解析\n' >&2
  exit 2
}
_helper_script="${script_dir}/common-helpers.sh"
[ -f "${_helper_script}" ] || {
  printf 'merge-ticket: 共享库缺失（同目录定位）: %s\n' "${_helper_script}" >&2
  exit 2
}
# shellcheck source=agent-up/scripts/common-helpers.sh
. "${_helper_script}"

usage() {
  cat <<'USAGE'
用法: sh merge-ticket.sh <repo-root> <branch> <ticket-id>
参数:
  repo-root   主仓根目录（当前分支须 main；合并目标＝当前分支）。
  branch      票分支名，须 ticket/ 前缀。
  ticket-id   票 id（用于核对分支绑定并生成合并提交说明）。
  -h / --help 打印本用法。
行为:
  ①票分支绑定 worktree 上核审查证据：调 ticket-audit.sh --operation merge，只认
  conformant；证据缺失/未提交/diff 失配/unknown → 拒绝合并（exit 1，decision-required）
  且保留 worktree/分支；②主仓不干净即拒绝，不代为提交共享票务记录；③git merge --ff-only
  失败自动降级 --no-ff；④仍失败且存在冲突现场 → git merge --abort 清现场后 exit 3 停等
  （worktree 保留）；⑤成功（任一方式）→ 无条件删 worktree 与分支；⑥输出实际合并模式
  与合并提交哈希。
退出码: 0 成功（已清场）；1 fail-closed（含证据门拒绝）；2 用法或环境错误；
        3 真冲突停等（已清现场）。
USAGE
}

# 审计要点二承载：冲突现场清除守卫——仅当 MERGE_HEAD 存在才 abort，abort 后断言无残留
clear_merge_state() {
  # $1=repo-root；输出冲突文件清单（abort 前取），返回 0=已清、1=无现场可清
  _mh=$(git -C "$1" rev-parse -q --verify MERGE_HEAD 2>/dev/null || true)
  [ -n "${_mh}" ] || return 1
  _conflicted=$(git -C "$1" diff --name-only --diff-filter=U 2>/dev/null | paste -sd, -) || true
  git -C "$1" merge --abort >/dev/null 2>&1 || true
  _mh2=$(git -C "$1" rev-parse -q --verify MERGE_HEAD 2>/dev/null || true)
  [ -z "${_mh2}" ] || die1 'git merge --abort 后 MERGE_HEAD 仍残留——现场未清净，人工处理后再跑'
  CONFLICTED=${_conflicted}
  return 0
}

# 分支绑定 worktree 路径（git worktree list --porcelain 解析；含空白路径不受理——
# porcelain 引号转义形态本脚本不解，命中即当无绑定处理，后续分支删除会如实失败）
wt_of_branch() {
  # $1=repo-root $2=branch；输出 worktree 路径或空串
  _wl=$(git -C "$1" worktree list --porcelain 2>/dev/null) || true
  [ -n "${_wl}" ] || return 0
  printf '%s\n' "${_wl}" | WTBR="refs/heads/$2" awk '
    $1 == "worktree" { wt = $2 }
    $1 == "branch" && $2 == ENVIRON["WTBR"] { print wt; exit }
  '
}

[ $# -eq 1 ] && case $1 in -h|--help) usage; exit 0 ;; esac
[ $# -eq 3 ] || { usage >&2; exit 2; }
repo_root=$1
branch=$2
ticket_id=$3

[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${repo_root}"
[ -n "${ticket_id}" ] || die2 'ticket-id 为空'
printf '%s' "${ticket_id}" | grep -Eq '^[0-9]{2,}-[a-z0-9]+([a-z0-9-]*[a-z0-9])?$' || die2 "ticket-id 不合规范（须为 <NN>-<slug>，拒绝路径或空段）: ${ticket_id}"
printf '%s' "${branch}" | grep -Eq '^ticket/[0-9]{2,}-[a-z0-9]+([a-z0-9-]*[a-z0-9])?$' || die2 "分支名不合 ticket/<NN>-<slug> 形态: ${branch}"
[ "${branch#ticket/}" = "${ticket_id}" ] || die2 "分支票号与 ticket-id 不匹配: ${branch} ≠ ticket/${ticket_id}"

# 合并前先完成 task 票 actual_time 收口预检。ticket-ops.sh 仍保留最终 flip 门禁；
# 这里提前阻断，避免先合并、后翻转失败再留下已清理的现场。
# 票 237 补正：actual_time 按 lane-commit 口径在工作区填写并随票分支提交，主检出恒缺
# 该字段——票体优先读被合并票分支 tip，分支 tip 无该票体时才回退主检出文件；分支值
# 一旦读到即不覆盖，否则合法路径会被「actual_time 缺失」永久堵死。

ticket_rel="facts/requirements/tickets/${ticket_id}.json"
ticket_file="${repo_root}/${ticket_rel}"
if git -C "${repo_root}" cat-file -e "${branch}:${ticket_rel}" 2>/dev/null; then
  ticket_origin="${branch}:${ticket_rel}"
  ticket_body=$(git -C "${repo_root}" show "${branch}:${ticket_rel}") \
    || die1 "票本体不可读（票分支 tip），拒绝合并：${ticket_origin}"
else
  ticket_origin="${ticket_file}（主检出回退：票分支 tip 无票体）"
  [ -r "${ticket_file}" ] || die1 "票本体不可读，拒绝合并：${ticket_file}（票分支 tip 无票体，主检出回退亦缺失）"
  ticket_body=$(cat "${ticket_file}") || die1 "票本体不可读，拒绝合并：${ticket_file}"
fi
command -v python3 >/dev/null 2>&1 || die1 'python3 不可用，拒绝合并（actual_time 前置门禁）'
python3 - "${ticket_id}" "${ticket_origin}" "${ticket_body}" <<'PYEOF'
import json
import sys

ticket_id, origin, body_text = sys.argv[1:]
try:
    body = json.loads(body_text)
except (OSError, ValueError) as exc:
    sys.stderr.write(f"merge-ticket: FAIL: 票 {ticket_id} 本体不是合法 JSON（来源 {origin}），拒绝合并：{exc}\n")
    raise SystemExit(1)
if not isinstance(body, dict):
    sys.stderr.write(f"merge-ticket: FAIL: 票 {ticket_id} 顶层不是 object（来源 {origin}），拒绝合并\n")
    raise SystemExit(1)
if body.get("kind") == "task":
    value = body.get("actual_time")
    if not isinstance(value, str) or not value.strip():
        sys.stderr.write(f"merge-ticket: FAIL: 票 {ticket_id} task actual_time 缺失或为空（来源 {origin}），拒绝合并（保留 worktree 与分支）\n")
        raise SystemExit(1)
PYEOF

# ---- 预检（fail-closed，先于任何写入） ----

cur_branch=$(git -C "${repo_root}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
[ "${cur_branch}" = 'main' ] || die1 "当前分支非 main（本脚本只做票分支→main 合并，合并目标＝当前分支）: ${cur_branch:-DETACHED}"

mh_entry=$(git -C "${repo_root}" rev-parse -q --verify MERGE_HEAD 2>/dev/null || true)
[ -z "${mh_entry}" ] || die1 '检测到悬挂合并现场（MERGE_HEAD 非空）——先处理上次合并（git merge --abort 或完成提交），本脚本不接手脏现场'

tip=$(git -C "${repo_root}" rev-parse --verify --quiet "refs/heads/${branch}" 2>/dev/null || true)
[ -n "${tip}" ] || die1 "分支不存在: ${branch}"

head0=$(git -C "${repo_root}" rev-parse --verify HEAD 2>/dev/null || true)
[ -n "${head0}" ] || die1 '当前分支无 HEAD（空仓库）——无从合并'

# ---- 合并前置检查：票务记录须按票独立提交，主仓不干净即拒绝 ----

st_dirty=$(git -C "${repo_root}" status --porcelain -uall)
[ -z "${st_dirty}" ] || die1 "主仓存在未提交改动，拒绝合并并保留 worktree/分支：${st_dirty}（票务记录须先按票独立提交）"

# ---- 证据门（票 237：只认 ticket-audit --operation merge conformant）----
# 审计目标＝票分支绑定 worktree：主检出 HEAD 是 main，审查收据与产品提交在票分支
# HEAD 上；在 worktree 上跑只读审计才能核到「已提交、绑定 diff」的证据。无绑定
# worktree 即无法核验 → 拒绝（decision-required），不退回 main 估计。

audit_cmd=''
if [ -f "${script_dir}/ticket-audit.sh" ] && [ -r "${script_dir}/ticket-audit.sh" ]; then
  audit_cmd="${script_dir}/ticket-audit.sh"
else
  _arest=${PATH:-}
  while [ -n "${_arest}" ]; do
    _adir=${_arest%%:*}
    case ${_arest} in
      *:*) _arest=${_arest#*:} ;;
      *) _arest='' ;;
    esac
    [ -n "${_adir}" ] || continue
    if [ -f "${_adir}/ticket-audit.sh" ] && [ -r "${_adir}/ticket-audit.sh" ]; then
      audit_cmd="${_adir}/ticket-audit.sh"
      break
    fi
  done
fi
[ -n "${audit_cmd}" ] || die1 "证据审计引擎 ticket-audit.sh 不可用（同目录与 PATH 均未找到），拒绝合并（decision-required；未产生任何写入）"

json_engine="${script_dir}/json-validator.py"
if [ ! -f "${json_engine}" ]; then
  json_engine="$(dirname -- "${audit_cmd}")/json-validator.py"
fi
# 允许集与 done 门同源：Review Checkpoint 判定走 common-helpers 唯一实现，票体来源
# 同 actual_time 预检（票分支 tip）。
_audit_cp=$(printf '%s\n' "${ticket_body}" | review_checkpoint_allow_after "${ticket_id}" "${json_engine}" -)

wt=$(wt_of_branch "${repo_root}" "${branch}")
[ -n "${wt}" ] && [ -d "${wt}" ] || die1 "分支 ${branch} 无绑定 worktree，无法在票分支 HEAD 上核审查证据，拒绝合并（decision-required；worktree 与分支保留）"

nn=${ticket_id%%-*}
audit_rc=0
if [ -n "${_audit_cp}" ]; then
  sh "${audit_cmd}" "${nn}" --repo "${wt}" --operation merge \
    --allow-after 'facts/requirements/tickets/index.json' \
    --allow-after 'facts/requirements/tickets/progress-current.md' \
    --allow-after 'facts/project/changes.jsonl' \
    --allow-after 'facts/requirements/tickets/README.md' \
    --allow-after "${_audit_cp}" || audit_rc=$?
else
  sh "${audit_cmd}" "${nn}" --repo "${wt}" --operation merge \
    --allow-after 'facts/requirements/tickets/index.json' \
    --allow-after 'facts/requirements/tickets/progress-current.md' \
    --allow-after 'facts/project/changes.jsonl' \
    --allow-after 'facts/requirements/tickets/README.md' || audit_rc=$?
fi
case ${audit_rc} in
  0) printf 'merge-ticket: 证据门: ticket-audit --operation merge 允许（conformant）\n' ;;
  2) die2 "证据审计引擎用法/环境错误（exit 2），拒绝合并；未产生任何写入" ;;
  *) die1 "decision-required: 票 ${ticket_id} 的审查证据未判 conformant（ticket-audit --operation merge exit ${audit_rc}）——证据缺失/未提交/diff 失配/身份或策略不可核验一律拒绝合并；worktree 与分支保留" ;;
esac

# ---- 合并：ff → 降级 --no-ff → 冲突 abort 停等 ----

rc_ff=0
out_ff=$(git -C "${repo_root}" merge --ff-only --no-edit "${branch}" 2>&1) || rc_ff=$?

mode=''
mhash=''
if [ "${rc_ff}" -eq 0 ]; then
  mode='fast-forward'
else
  rc_nf=0
  out_nf=$(git -C "${repo_root}" merge --no-ff --no-edit -m "chore(governance): 票 ${ticket_id} 合并收口（merge-ticket.sh --no-ff 降级，ff 不可快进）" "${branch}" 2>&1) || rc_nf=$?
  if [ "${rc_nf}" -eq 0 ]; then
    mode='no-ff'
  else
    if clear_merge_state "${repo_root}"; then
      printf 'merge-ticket: FAIL: 真冲突停等：ff 与 --no-ff 均失败，冲突文件 [%s]；已 git merge --abort 清现场（无 MERGE_HEAD 残留）；worktree 保留待人工解决后重跑（审计要点二）\n' "${CONFLICTED}" >&2
      exit 3
    fi
    printf 'merge-ticket: FAIL: ff 与 --no-ff 均失败且无冲突现场（非冲突性拒绝）\n[ff] %s\n[--no-ff] %s\n' "${out_ff}" "${out_nf}" >&2
    exit 1
  fi
fi
mhash=$(git -C "${repo_root}" rev-parse HEAD)

# ---- 输出（审计要点四：实际合并模式＋合并提交哈希） ----

printf 'merge-ticket: 合并成功\n'
printf '模式: %s\n' "${mode}"
printf '合并提交: %s\n' "${mhash}"

# ---- 成功路径清场：无条件删 worktree 与分支（不管哪种方式成功） ----

wt=$(wt_of_branch "${repo_root}" "${branch}")
if [ -n "${wt}" ] && [ -d "${wt}" ]; then
  git -C "${repo_root}" worktree remove "${wt}" >/dev/null 2>&1 \
    || die1 "worktree 移除失败（工作区含未提交改动？人工核对后处理，防误删）：${wt}——合并已成功提交 ${mhash}"
  printf 'merge-ticket: 清场: worktree 已移除 %s\n' "${wt}"
else
  printf 'merge-ticket: 清场: 未发现绑定 worktree，跳过移除\n'
fi
git -C "${repo_root}" branch -d "${branch}" >/dev/null \
  || die1 "分支删除失败: ${branch}——合并已成功提交 ${mhash}，人工核对分支状态"
printf 'merge-ticket: 清场: 分支已删除 %s\n' "${branch}"
printf 'merge-ticket: PASS（模式 %s，提交 %s，worktree 与分支已清）\n' "${mode}" "${mhash}"
