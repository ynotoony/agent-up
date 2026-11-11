#!/bin/sh
# Input: 主仓根目录、票分支名（ticket/ 前缀）、票 id 三参数；可选 --flip（合并成功后
#        同锁内调 ticket-ops flip 至 done 并落账本行＝合并与收尾原子化）；可选
#        --authorize-rebind <授权依据>（main 已前进需 rebase 后重绑审查证据时的显式授权；
#        未给即 fail-closed，不 rebase 不合并、不静默改写证据）；主仓须干净，各票票务写入
#        由调用方按票独立落账；合并前另取票分支绑定 worktree 作审查证据审计目标
#        （ticket-audit.sh <NN> --repo <worktree> --operation merge）。
# Output: 单票合并收口逐步输出——证据门三值结论、实际合并模式（fast-forward
#         或 no-ff）、合并提交哈希（审计要点四）、强制清场（worktree remove --force＋branch -d；
#         站内残渣视为可弃，失败即报错非静默）
#         --flip 时合并成功后在同一把合并锁内调 ticket-ops flip --status done（索引→
#         README→账本→投影），成功后才清场；翻转失败如实报错并非零退出且不清场（保留
#         现场供修复/重跑，不静默）；合并锁＝记录层写锁（record_lock_*，与票务写入同一把，
#         拿不到锁即 fail-closed 停止，不并发写）。
#         或冲突停等报告（冲突文件清单＋abort 清现场确认）；退出码 0 成功（已清场）/
#         1 fail-closed（含 --flip 翻转失败）／2 用法环境错误／3 真冲突停等（含 rebase
#         冲突，已清现场，worktree 保留）。
# Pos: 合并站独立脚本（票 93；车道＝全道，lane-commit.sh 同款脚本化收尾解耦）：
#      ff 失败自动降级 --no-ff，仍冲突则 git merge --abort 清现场（审计要点二，禁悬挂
#      merge-in-progress）；成功路径无条件强制清场（站内残渣视为可弃）；主仓不干净即拒绝；
#      本脚本由调用方 chain 翻转前查 index 现值（审计要点三，票 93 四要点分工）；
#      票 237 起合并前置证据门：只认 ticket-audit --operation merge conformant，未提交/
#      diff 失配/unknown 一律拒绝（缺证据即 decision-required，不采信自报 PASS）；
#      审计目标＝票分支绑定 worktree（主检出 HEAD 是 main，证据在票分支 HEAD 上）。
#      ff 断言语义不波及 export-payload.sh（那边保留自有 ff 断言）。POSIX sh、
#      set -eu fail-closed、零外部依赖（git＋POSIX 工具）；已知限制：worktree 路径含
#      空白不受理（家族先例 S4 同款口径）。行为语义变化经 Review 门禁。
#      票 285：合并与收尾原子化——合并前若 main 已前进（非票分支祖先）则在源站自动
#      rebase 到最新 main 以保证快进（rebase 冲突 abort 后 exit 3）；票 288 起重绑审查
#      证据须显式授权（--authorize-rebind <授权依据>），未授权即 fail-closed；授权后由
#      独立入口 evidence-rebind.sh 完成重绑（按证据 head 之后提交数定位 rebase 后新产品
#      提交，改写 base_sha/head_sha/diff_sha 并同步 cp md，以 reviewer_identity 身份提交
#      「审查证据复绑至 rebase 后 HEAD」，并向 changes.jsonl 追加复绑记录）——本件只编排，
#      不再兼任审查证据写入方；重绑失败 fail-closed（不合并、如实报错、保留现场）。
#      --flip 在同一把合并锁内完成翻转，消除「合并成功→翻转」空窗。
#      票 237 补正：actual_time 预检读被合并票分支 tip（主检出仅回退）；证据允许集与
#      done 门同源（含票面声明的规范 Review Checkpoint md，判定在 common-helpers）。
#      记录面允许集（C0 修复）：P04 允许集除索引/投影/票面 cp md 外，另纳入
#      facts/project/changes.jsonl、facts/requirements/tickets/README.md 与本票票体
#      facts/requirements/tickets/<id>.json——前两者是随每次票务操作必然变动的记录面
#      派生件（账本行追加、README 状态列同步），后者承载 commit 阶段写的
#      checkpoint.commit；均不是被审阅的实现面；主线在分支期间落记录面提交不应被
#      P04 判成「审阅边界被污染」。

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
用法: sh merge-ticket.sh [--flip] [--authorize-rebind <授权依据>] <repo-root> <branch> <ticket-id>
参数:
  --flip      合并成功后在同一把合并锁内调 ticket-ops flip --status done 并落账本行
              （合并与收尾原子化；翻转失败如实报错 exit 1 且不清场）。
  --authorize-rebind <授权依据>
              main 已前进（票分支未含最新 main）需 rebase 后重绑审查证据时的显式授权
              （授权原文或可检索引用）；缺省即 fail-closed（不 rebase、不合并、不静默
              改写证据）。重绑写入方＝独立入口 evidence-rebind.sh（账本留痕）。
  repo-root   主仓根目录（当前分支须 main；合并目标＝当前分支）。
  branch      票分支名，须 ticket/ 前缀。
  ticket-id   票 id（用于核对分支绑定并生成合并提交说明）。
  -h / --help 打印本用法。
行为:
  ⓪合并锁：取记录层写锁（record_lock_*，与票务写入同一把；TICKET_OPS_LOCK_TIMEOUT 有界
  等待，拿不到即「并发冲突」exit 1，零合并）——合并/翻转/记录整段串行；
  ①票分支绑定 worktree 上核审查证据：调 ticket-audit.sh --operation merge，只认
  conformant；证据缺失/未提交/diff 失配/unknown → 拒绝合并（exit 1，decision-required）
  且保留 worktree/分支；②主仓不干净即拒绝，不代为提交共享票务记录；③合并前若 main
  已前进（非票分支祖先）→ 须 --authorize-rebind 显式授权，未授权即 exit 1 fail-closed
  （未 rebase 未合并）；授权后在源站自动 rebase 到最新 main（冲突 abort 后 exit 3），
  并由 evidence-rebind.sh 重绑审查证据（账本留痕）；④git merge --ff-only 失败自动降级 --no-ff；⑤仍失败且存在冲突现场 →
  git merge --abort 清现场后 exit 3 停等（worktree 保留）；⑥--flip 时在同一把锁内调
  ticket-ops flip --status done（失败 exit 1 且不清场）；⑦成功（任一方式）→ 无条件删
  worktree 与分支；⑧输出实际合并模式与合并提交哈希。
退出码: 0 成功（已清场）；1 fail-closed（含证据门拒绝与 --flip 翻转失败）；
        2 用法或环境错误；3 真冲突停等（含 rebase 冲突，已清现场）。
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

# 协作脚本定位（同目录优先、PATH 回退；落位脚本不要求可执行位，恒经 sh 调用，故手动
# 迭代 PATH 而不用 command -v）。命中打印路径，缺失 return 1。票 288：ticket-ops／
# ticket-audit／evidence-rebind 三处定位统一经本函数，零重复副本。
locate_tool() {
  _lt_name=$1
  if [ -f "${script_dir}/${_lt_name}" ] && [ -r "${script_dir}/${_lt_name}" ]; then
    printf '%s\n' "${script_dir}/${_lt_name}"
    return 0
  fi
  _lt_rest=${PATH:-}
  while [ -n "${_lt_rest}" ]; do
    _lt_dir=${_lt_rest%%:*}
    case ${_lt_rest} in
      *:*) _lt_rest=${_lt_rest#*:} ;;
      *) _lt_rest='' ;;
    esac
    [ -n "${_lt_dir}" ] || continue
    if [ -f "${_lt_dir}/${_lt_name}" ] && [ -r "${_lt_dir}/${_lt_name}" ]; then
      printf '%s\n' "${_lt_dir}/${_lt_name}"
      return 0
    fi
  done
  return 1
}

[ $# -eq 1 ] && case $1 in -h|--help) usage; exit 0 ;; esac
# 票 285：--flip 可出现在任意位置（首个非选项参数起为三位置参）；缺省行为不变（只合并）。
# 票 288：--authorize-rebind <授权依据> 为审查证据重绑的显式授权参数（main 已前进时必需；
# 未授权即 fail-closed，不静默改写审查证据）。
do_flip=0
rebind_authorization=''
_p1='' _p2='' _p3='' _pn=0
while [ $# -gt 0 ]; do
  case $1 in
    --flip) do_flip=1; shift ;;
    --authorize-rebind)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      rebind_authorization=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      _pn=$((_pn + 1))
      case ${_pn} in
        1) _p1=$1 ;;
        2) _p2=$1 ;;
        3) _p3=$1 ;;
        *) usage >&2; exit 2 ;;
      esac
      shift
      ;;
  esac
done
[ "${_pn}" -eq 3 ] || { usage >&2; exit 2; }
repo_root=${_p1}
branch=${_p2}
ticket_id=${_p3}

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

# ---- 合并锁（票 285）：合并/翻转/记录整段串行；拿不到锁即 fail-closed 停止 ----
# 锁＝记录层写锁（common-helpers record_lock_*，与 ticket-ops/ledger-append 同一把）：
# 合并期间不会有票务记录写入插队；有界等待（TICKET_OPS_LOCK_TIMEOUT，缺省 20s）后以
# 「并发冲突」exit 1 停止，零合并。失败路径由 EXIT 陷阱按所有权释放。
record_lock_init "${repo_root}"
trap 'record_lock_release' EXIT HUP INT TERM
record_lock_acquire
printf 'merge-ticket: 合并锁: 已取得记录层写锁（%s）——合并/翻转/记录整段串行\n' "${RECORD_LOCK_DIR}"

# --flip 时同锁内调票务收口：ticket-ops 同目录优先／PATH 回退（缺失即预检停止，未产生写入）
ticket_ops=''
if [ "${do_flip}" -eq 1 ]; then
  ticket_ops=$(locate_tool ticket-ops.sh) || \
    die1 "票务运维脚本 ticket-ops.sh 不可用（同目录与 PATH 均未找到）——--flip 收尾停止；未产生任何写入"
fi


# ---- 证据门（票 237：只认 ticket-audit --operation merge conformant）----
# 审计目标＝票分支绑定 worktree：主检出 HEAD 是 main，审查收据与产品提交在票分支
# HEAD 上；在 worktree 上跑只读审计才能核到「已提交、绑定 diff」的证据。无绑定
# worktree 即无法核验 → 拒绝（decision-required），不退回 main 估计。

audit_cmd=$(locate_tool ticket-audit.sh) || \
  die1 "证据审计引擎 ticket-audit.sh 不可用（同目录与 PATH 均未找到），拒绝合并（decision-required；未产生任何写入）"

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
# 本票票体＝commit 阶段 checkpoint.commit 的记录面承载（与 done 门允许集同源）。
_gate_ticket_rel="facts/requirements/tickets/${ticket_id}.json"
audit_rc=0
if [ -n "${_audit_cp}" ]; then
  sh "${audit_cmd}" "${nn}" --repo "${wt}" --operation merge \
    --allow-after 'facts/requirements/tickets/index.json' \
    --allow-after 'facts/requirements/tickets/progress-current.md' \
    --allow-after 'facts/project/changes.jsonl' \
    --allow-after 'facts/requirements/tickets/README.md' \
    --allow-after "${_gate_ticket_rel}" \
    --allow-after "${_audit_cp}" || audit_rc=$?
else
  sh "${audit_cmd}" "${nn}" --repo "${wt}" --operation merge \
    --allow-after 'facts/requirements/tickets/index.json' \
    --allow-after 'facts/requirements/tickets/progress-current.md' \
    --allow-after 'facts/project/changes.jsonl' \
    --allow-after 'facts/requirements/tickets/README.md' \
    --allow-after "${_gate_ticket_rel}" || audit_rc=$?
fi
case ${audit_rc} in
  0) printf 'merge-ticket: 证据门: ticket-audit --operation merge 允许（conformant）\n' ;;
  2) die2 "证据审计引擎用法/环境错误（exit 2），拒绝合并；未产生任何写入" ;;
  *) die1 "decision-required: 票 ${ticket_id} 的审查证据未判 conformant（ticket-audit --operation merge exit ${audit_rc}）——证据缺失/未提交/diff 失配/身份或策略不可核验一律拒绝合并；worktree 与分支保留" ;;
esac

# ---- 合并前 rebase 到最新 main（票 285：保证快进；票 288：证据重绑须显式授权）----
# main 已是票分支祖先＝可直接 ff；否则先把票分支 rebase 到 main，再按「证据 head 之后的
# 提交数」定位 rebase 后的新产品提交，改写审查证据 base_sha/head_sha/diff_sha 并同步 cp md
# 描述，以 reviewer_identity 身份在合并前提交——使 --flip 的 P04/P05 在并行收口（main
# 已前进）场景仍 conformant。rebase 冲突或重绑失败一律 fail-closed：清现场/停止，不合并，
# 如实报错保留 worktree 与分支。
_ev_rel="facts/requirements/tickets/${ticket_id}.review-evidence.json"
_cp_rel="facts/requirements/tickets/${ticket_id}-review-checkpoint.md"
if git -C "${repo_root}" merge-base --is-ancestor main "${branch}" >/dev/null 2>&1; then
  printf 'merge-ticket: 合并前 rebase: main 已是票分支祖先，无需 rebase（可直接快进）\n'
else
  _ev_file="${wt}/${_ev_rel}"
  [ -f "${_ev_file}" ] || die1 "审查证据文件缺失，无法在 rebase 后重绑（未 rebase、未合并；worktree 与分支保留）: ${_ev_rel}"
  _ev_base=$(python3 "${json_engine}" json get "${_ev_file}" base_sha 2>/dev/null) || _ev_base=''
  _ev_head=$(python3 "${json_engine}" json get "${_ev_file}" head_sha 2>/dev/null) || _ev_head=''
  _ev_diff=$(python3 "${json_engine}" json get "${_ev_file}" diff_sha 2>/dev/null) || _ev_diff=''
  for _ev_v in "${_ev_base}" "${_ev_head}" "${_ev_diff}"; do
    printf '%s' "${_ev_v}" | grep -Eq '^[0-9a-f]{40}$' || \
      die1 "审查证据 base/head/diff 形态不合（须 40 位小写十六进制），无法在 rebase 后重绑（未 rebase、未合并）: ${_ev_rel}"
  done
  _ev_reviewer=$(python3 "${json_engine}" json get "${_ev_file}" reviewer_identity 2>/dev/null) || _ev_reviewer=''
  [ -n "${_ev_reviewer}" ] || die1 "审查证据缺 reviewer_identity，无法以审查者身份提交重绑（未 rebase、未合并）: ${_ev_rel}"
  # 票 288：重绑须显式授权（--authorize-rebind <授权依据>）；未授权即 fail-closed，不 rebase、
  # 不合并、不静默改写审查证据——证据写入方独立为 evidence-rebind.sh，本件只编排。
  [ -n "${rebind_authorization}" ] || \
    die1 "decision-required: main 已前进（票分支未含最新 main），需 rebase 后重绑审查证据，但未显式授权（缺 --authorize-rebind <授权依据>）——fail-closed：未 rebase、未合并；worktree 与分支保留"
  evidence_rebind=$(locate_tool evidence-rebind.sh) || \
    die1 "审查证据重绑实现 evidence-rebind.sh 不可用（同目录与 PATH 均未找到）——未 rebase、未合并；worktree 与分支保留"
  _after_n=$(git -C "${wt}" rev-list --count "${_ev_head}..${tip}")
  _rebase_base=$(git -C "${repo_root}" rev-parse main)
  printf 'merge-ticket: 合并前 rebase: 票分支尚未包含最新 main，rebase 到 main 以保证快进\n'
  rc_rb=0
  out_rb=$(git -C "${wt}" rebase main 2>&1) || rc_rb=$?
  if [ "${rc_rb}" -ne 0 ]; then
    git -C "${wt}" rebase --abort >/dev/null 2>&1 || true
    printf 'merge-ticket: FAIL: rebase 到 main 遇冲突，已 rebase --abort 清现场（worktree 与分支保留）：\n%s\n' "${out_rb}" >&2
    exit 3
  fi
  tip=$(git -C "${repo_root}" rev-parse "refs/heads/${branch}")
  if [ "${_after_n}" -eq 0 ]; then
    _new_head=${tip}
  else
    _new_head=$(git -C "${wt}" rev-parse "${tip}~${_after_n}" 2>/dev/null) || _new_head=''
  fi
  printf '%s' "${_new_head}" | grep -Eq '^[0-9a-f]{40}$' || \
    die1 "rebase 后新产品提交定位失败（未合并；worktree 与分支保留，分支已 rebase，可重跑）: ${branch}"
  _new_diff=$(git -C "${wt}" diff --binary "${_rebase_base}" "${_new_head}" | git -C "${wt}" hash-object --stdin) || _new_diff=''
  printf '%s' "${_new_diff}" | grep -Eq '^[0-9a-f]{40}$' || \
    die1 "rebase 后 diff 指纹重算失败（未合并；worktree 与分支保留）: ${branch}"
  # 票 288：重绑改写与以 reviewer 身份的提交归 evidence-rebind.sh；继承本进程合并锁
  # （同锁窗口内改证据/落账本/提交），失败 fail-closed 不合并、保留 worktree 与分支。
  _er_rc=0
  RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
    sh "${evidence_rebind}" --authorize "${rebind_authorization}" "${wt}" "${ticket_id}" \
      "${_rebase_base}" "${_new_head}" || _er_rc=$?
  [ "${_er_rc}" -eq 0 ] || \
    die1 "审查证据重绑失败（evidence-rebind exit ${_er_rc}；未合并；worktree 与分支保留）: ${_ev_rel}"
  tip=$(git -C "${repo_root}" rev-parse "refs/heads/${branch}")
  printf 'merge-ticket: 证据重绑: base %s → head %s（diff %s；以 %s 身份提交于合并前）\n' \
    "${_rebase_base}" "${_new_head}" "${_new_diff}" "${_ev_reviewer}"
  printf 'merge-ticket: rebase 完成: %s（票分支已对齐最新 main，审查证据已重绑）\n' "${tip}"
fi
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

# ---- --flip：同锁内收尾（票 285：合并与翻转原子化，消除空窗） ----
# 合并成功后立即在同一把锁内调 ticket-ops flip --status done（索引→README→账本→投影）；
# 翻转失败＝合并已成功但收尾未完成：如实报错并非零退出，不清场（worktree/分支保留，
# 修复证据或记录面后重跑同一命令即收敛）。
if [ "${do_flip}" -eq 1 ]; then
  _flip_date=$(date +%F)
  _flip_line=$(printf '{"date":"%s","kind":"change","scope":"%s","decision":"merge-ticket --flip：票 %s 合并收口（done）","evidence_ref":"facts/requirements/tickets/%s.json"}' "${_flip_date}" "${nn}" "${ticket_id}" "${ticket_id}")
  _flip_rc=0
  RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
    sh "${ticket_ops}" "${repo_root}" flip --id "${ticket_id}" --status 'done' --ledger-line "${_flip_line}" || _flip_rc=$?
  if [ "${_flip_rc}" -ne 0 ]; then
    printf 'merge-ticket: FAIL: 合并已成功（提交 %s），但收尾翻转失败（ticket-ops flip exit %s）——未清场：worktree 与分支保留；索引/README/账本/投影状态以 ticket-ops 输出为准（如实报告，不静默）\n' "${mhash}" "${_flip_rc}" >&2
    exit 1
  fi
  printf 'merge-ticket: 翻转: 票据 %s → done（ticket-ops flip 同锁内完成索引/README/账本/投影）\n' "${ticket_id}"
fi


# ---- 成功路径强制清场：无条件删 worktree 与分支（站内残渣视为可弃；失败即非零退出） ----

wt=$(wt_of_branch "${repo_root}" "${branch}")
if [ -n "${wt}" ] && [ -d "${wt}" ]; then
  git -C "${repo_root}" worktree remove --force "${wt}" >/dev/null 2>&1 \
    || die1 "worktree 强制移除失败（人工核对后处理）：${wt}——合并已成功提交 ${mhash}"
  printf 'merge-ticket: 清场: worktree 已移除 %s\n' "${wt}"
else
  printf 'merge-ticket: 清场: 未发现绑定 worktree，跳过移除\n'
fi
git -C "${repo_root}" branch -d "${branch}" >/dev/null \
  || die1 "分支删除失败: ${branch}——合并已成功提交 ${mhash}，人工核对分支状态"
printf 'merge-ticket: 清场: 分支已删除 %s\n' "${branch}"
if [ "${do_flip}" -eq 1 ]; then
  printf 'merge-ticket: PASS（模式 %s，提交 %s，已翻转 done，worktree 与分支已清）\n' "${mode}" "${mhash}"
else
  printf 'merge-ticket: PASS（模式 %s，提交 %s，worktree 与分支已清）\n' "${mode}" "${mhash}"
fi
