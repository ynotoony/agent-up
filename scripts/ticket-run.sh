#!/bin/sh
# Input: <NN> <command> [args]——command ∈ next|start|contract|record|verify-dispatch
#        （可恢复协调器五子命令），或 legacy implementation|review|commit。NN 定位唯一
#        任务票；repo-root 缺省按脚本落位推导。contract 收 implementation|review；
#        record 收收据 JSON 文件；verify-dispatch 收 implementation|review|commit
#        与可选合同文件；next 另收 --clear-intent（显式清除残留 intent）。
# Output: 五子命令各自只做一步、只经已登记幂等工具产生副作用，并在有副作用动作前写
#         intent（<git-common-dir>/ticket-run/<NN>.intent，逐步 started/done），故同一
#         命令失败后重跑即收敛；无法判定的状态返回 decision-required 而非猜测：
#         next      只读推导下一步，恰打印「ticket-run: 下一步: <token>」与原因行；
#                   intent 显示上次未完成步骤时另打一行恢复提示。恢复提示先对照该命令
#                   的索引前置（start 只接受 ready|in_progress），前置不满足即
#                   decision-required 并给出登记清除路径 next --clear-intent，不得提示
#                   重跑一条会被前置拒绝的命令；decision-required 时 exit 1（与「有下
#                   一步」的 exit 0 可凭退出码区分）。next --clear-intent 只清已判不可
#                   收敛的残留：删除前打印原内容；残留仍可收敛时拒绝并 exit 1。
#         start     建站（worktree-add，两参旧接口）→ 领取（ticket-ops take）；站已在位
#                   且分支正确即跳过建站，索引已是 in_progress 即走 ticket-ops 幂等重放；
#                   输出站路径、票状态与下一步。
#         contract  渲染 implementation|review 合同，stdout 恰两行机器契约（站路径＋
#                   合同文件），不写任何状态载体。
#         record    收据按 receipt.schema.json 字段合同校验后幂等落位到站内证据路径；
#                   同内容重跑收敛，不同内容返回 decision-required（证据不可静默覆盖）。
#         verify-dispatch  重渲染票面 dispatch.<stage> 并与给定合同文件逐字比对；
#                   缺阶段对象/缺键/空白值、合同文件缺失、合同漂移三类拒绝。
#         legacy implementation|review  渲染合同；implementation 缺站时经 worktree-add
#                   合同入口创建（旧语义原样保留）。legacy commit 行为不变。
# Pos: 主 agent 唯一编排入口（可恢复协调器）；只组合 contract-build/worktree-add/
#      ticket-ops 原子层，不读取或改写票状态逻辑，不直接写 index/README/账本/投影；
#      状态写入唯一经 ticket-ops（票 243 核心）。intent 日志只落 Git 公共目录，不进
#      版本控制面；next --clear-intent 是残留 intent 的唯一登记清除路径（只清已判不可
#      收敛的残留，删除前打印原内容；仍可收敛时拒绝；不碰任何状态载体）。POSIX sh；
#      JSON 读取仅经 json-validator.py。commit 不生成 User Review Checkpoint，不伪造
#      用户裁决；record 只搬已产出的收据，不生成 verdict。

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
用法: sh ticket-run.sh <NN> <command> [args] [repo-root]
      sh ticket-run.sh <NN> implementation|review|commit [repo-root]   （legacy 三阶段）
参数:
  NN           票号段（^[0-9]{2,}$），定位 facts/requirements/tickets/<NN>-<slug>.json
  repo-root    主仓库根目录；缺省按脚本落位推导
命令（可恢复协调器；每命令只做一步，失败后重跑同一命令收敛）:
  next [--clear-intent]       只读推导下一步，打印「ticket-run: 下一步: <token>」与原因；
                              无副作用、零写入；decision-required 时 exit 1，与「有下一步」
                              的 exit 0 可凭退出码区分。token ∈ open|start|
                              contract implementation|contract review|commit|record|done|
                              decision-required。恢复提示先核该命令的索引前置（start 只
                              接受 ready|in_progress），前置不满足即 decision-required 并
                              打印登记清除路径。--clear-intent 仅清除已判不可收敛的残留：
                              先打印将被删除的原内容再删日志；残留仍可收敛时拒绝清除并
                              exit 1，指名须重跑的子命令（只删该日志，不碰状态载体）。
  start                       建站（worktree-add 两参接口）→ 领取（ticket-ops take）。
                              站已在位且分支为 ticket/<id> 时跳过建站；索引已 in_progress
                              时经 ticket-ops 幂等重放补齐 README/账本/投影。
                              输出站路径、票状态与下一步。
  contract <stage>            渲染 stage 合同（implementation|review），stdout 恰两行：
                                ticket-run: 站路径: <绝对 worktree 路径>
                                ticket-run: 合同文件: <绝对合同文件路径>
                              合同文件留 $TMPDIR；要求站已存在。
  record <receipt-file>       收据按 receipt.schema.json 字段合同校验后落位到站内证据路径
                              （review→facts/requirements/tickets/<id>.review-evidence.json；
                              其余→facts/requirements/runs/<id>.<kind>.receipt.json）。
                              同内容重跑收敛；不同内容返回 decision-required，不覆盖证据。
  verify-dispatch <stage> [合同文件]
                              重渲染票面 dispatch.<stage> 并与合同文件逐字比对；无合同文件
                              时只核键集恰等与自校验。拒绝：缺阶段对象/缺键/空白值、
                              合同文件缺失、合同漂移。
  implementation|review       legacy 语义：渲染合同；implementation 缺站时自动建站（两行输出）。
  commit                      legacy 语义不变：Review 结论位＋check-gates 后产品/记录两段提交。
退出码: 0 完成（next＝有下一步）；1 fail-closed（含 next 的 decision-required、
        合同/Review/门禁/收据未过）；2 用法或环境错误（参数、仓库根、原子层缺失）。
        逐子命令退出码表见同目录 README.md。
-h / --help  打印本用法
USAGE
}

# ---- 参数解析（五子命令与 legacy 三阶段共用 <NN> 首参）----

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
[ $# -ge 2 ] || { usage >&2; exit 2; }
nn=$1
cmd=$2
shift 2
stage=''
receipt_file=''
contract_arg=''
repo_root=''
clear_intent=0
case $cmd in
  next)
    while [ $# -gt 0 ]; do
      case $1 in
        --clear-intent) clear_intent=1 ;;
        *)
          [ -z "$repo_root" ] || { usage >&2; die2 'next 至多接受一个 [repo-root]'; }
          repo_root=$1
          ;;
      esac
      shift
    done
    ;;
  start)
    [ $# -le 1 ] || { usage >&2; die2 "${cmd} 至多接受 [repo-root]"; }
    repo_root=${1:-}
    ;;
  contract)
    [ $# -ge 1 ] && [ $# -le 2 ] || { usage >&2; die2 'contract 需要 <implementation|review> [repo-root]'; }
    stage=$1
    shift
    repo_root=${1:-}
    case $stage in
      implementation|review) ;;
      *) die2 "contract 的 stage 须为 implementation|review: ${stage}" ;;
    esac
    ;;
  record)
    [ $# -ge 1 ] && [ $# -le 2 ] || { usage >&2; die2 'record 需要 <receipt-file> [repo-root]'; }
    receipt_file=$1
    shift
    repo_root=${1:-}
    ;;
  verify-dispatch)
    [ $# -ge 1 ] && [ $# -le 3 ] || { usage >&2; die2 'verify-dispatch 需要 <stage> [合同文件] [repo-root]'; }
    stage=$1
    shift
    case $stage in
      implementation|review|commit) ;;
      *) die2 "verify-dispatch 的 stage 须为 implementation|review|commit: ${stage}" ;;
    esac
    if [ $# -ge 2 ]; then
      contract_arg=$1
      repo_root=$2
    elif [ $# -eq 1 ]; then
      if [ -d "$1" ]; then repo_root=$1; else contract_arg=$1; fi
    fi
    ;;
  implementation|review|commit)
    [ $# -le 1 ] || { usage >&2; die2 'legacy 三阶段至多接受 [repo-root]'; }
    stage=$cmd
    repo_root=${1:-}
    ;;
  *)
    die2 "命令须为 next|start|contract|record|verify-dispatch 或 legacy implementation|review|commit: ${cmd}"
    ;;
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

# ---- 协调器共享辅助（只读状态推导＋intent 操作记录）----

index_file="${repo_root}/facts/requirements/tickets/index.json"

index_status() {
  # 打印索引中该票的 status；索引缺失或该票无条目返回非 0（调用方按空串处理）
  [ -f "$index_file" ] || return 3
  python3 "$_engine" json pick "$index_file" issues id "$ticket_id" status 2>/dev/null
}

index_updated_at() {
  [ -f "$index_file" ] || return 3
  python3 "$_engine" json pick "$index_file" issues id "$ticket_id" updated_at 2>/dev/null
}

worktree_path_valid() {
  [ -d "$worktree" ] && [ ! -L "$worktree" ] && \
    git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1
}

worktree_branch() {
  git -C "$worktree" rev-parse --abbrev-ref HEAD 2>/dev/null
}

# intent 操作记录：有副作用动作前先落一行 started，完成后落 done；重跑据此报告未完成
# 步骤（恢复依据）。文件在 Git 公共目录，主检与全部 worktree 共享且不进版本控制面。
intent_file=''
intent_path() {
  _common=$(cd "$repo_root" && git rev-parse --git-common-dir 2>/dev/null) || return 1
  case $_common in
    /*) ;;
    *) _common="${repo_root}/${_common}" ;;
  esac
  _common=$(CDPATH='' cd -- "$_common" && pwd -P) || return 1
  printf '%s/ticket-run/%s.intent' "$_common" "$nn"
}

intent_ensure() {
  [ -n "$intent_file" ] || intent_file=$(intent_path) || \
    die2 "intent 操作记录路径不可解析（仓库不是 Git 工作区）: ${repo_root}"
}

intent_record() {
  # $1=步骤 $2=started|done $3=可选载荷（record 记收据绝对路径，供恢复判定核对真实状态）
  # $4=可选附带载荷（record 记 receipt_kind；源收据被清理时供实态判定）
  intent_ensure
  _idir=$(dirname "$intent_file")
  [ -d "$_idir" ] || mkdir -p "$_idir" || die2 "intent 目录创建失败: ${_idir}"
  _iline="${1}${TAB}${2}${TAB}$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [ $# -ge 3 ] && [ -n "${3:-}" ]; then _iline="${_iline}${TAB}${3}"; fi
  if [ $# -ge 4 ] && [ -n "${4:-}" ]; then _iline="${_iline}${TAB}${4}"; fi
  printf '%s\n' "$_iline" >> "$intent_file" || die2 "intent 写入失败: ${intent_file}"
}

intent_last_started_field() {
  # $1=步骤 $2=列号（4 起为载荷）；打印该步骤最后一条 started 的该列，无则非 0
  intent_ensure
  [ -f "$intent_file" ] || return 1
  awk -F "$TAB" -v step="$1" -v col="$2" '$1 == step && $2 == "started" { v = $col } END { if (v == "") exit 1; print v }' "$intent_file"
}

intent_last_state() {
  # $1=步骤；打印该步骤最后一条状态，无记录返回非 0
  intent_ensure
  [ -f "$intent_file" ] || return 1
  awk -F "$TAB" -v step="$1" '$1 == step { state = $2 } END { if (state == "") exit 1; print state }' "$intent_file"
}

intent_last_started_payload() {
  # $1=步骤；打印该步骤最后一条 started 的第 4 列载荷，无则非 0
  intent_ensure
  [ -f "$intent_file" ] || return 1
  awk -F "$TAB" -v step="$1" '$1 == step && $2 == "started" { v = $4 } END { if (v == "") exit 1; print v }' "$intent_file"
}

record_effect_applied() {
  # 幂等实态判定：目标证据已在场，且源收据仍在场时内容逐字相同＝该步效果已落地。
  # 源收据被清理时退化为「intent 记的 kind 对应目标证据存在」——落位即效果成立；
  # 内容不可再比对属已知限制（证据不可覆盖语义保证目标不会被后续改写）。
  # 供 pending_intent_step 在崩溃于 mv 与 done 之间时判 record 是否仍算「未完成」。
  _rf=$(intent_last_started_payload record 2>/dev/null) || _rf=''
  _rk=$(intent_last_started_field record 5 2>/dev/null) || _rk=''
  worktree_path_valid || return 1
  if [ -n "$_rf" ] && [ -f "$_rf" ]; then
    _rk=$(receipt_get "$_rf" receipt_kind 2>/dev/null) || return 1
  fi
  case $_rk in
    review) _rel="facts/requirements/tickets/${ticket_id}.review-evidence.json" ;;
    dispatch|implementation|commit) _rel="facts/requirements/runs/${ticket_id}.${_rk}.receipt.json" ;;
    *) return 1 ;;
  esac
  _rt="${worktree}/${_rel}"
  [ -f "$_rt" ] || return 1
  if [ -n "$_rf" ] && [ -f "$_rf" ]; then
    cmp -s "$_rf" "$_rt" || return 1
  fi
  return 0
}

pending_intent_step() {
  # 打印最后一个「已开始未完成」的步骤；无则非 0。record 步另核真实状态：
  # 目标证据已在场（源收据在场时另比内容）即视为已完成，不因日志末态误报。
  _pending=''
  for _step in worktree take record; do
    if [ "$(intent_last_state "$_step" 2>/dev/null)" = 'started' ]; then
      if [ "$_step" = 'record' ] && record_effect_applied; then
        continue
      fi
      _pending=$_step
    fi
  done
  [ -n "$_pending" ] || return 1
  printf '%s' "$_pending"
}

NEXT_STEP=''
NEXT_REASON=''
compute_next() {
  _status=$(index_status) || _status=''
  if [ -z "$_status" ]; then
    if [ -e "$worktree" ]; then
      NEXT_STEP='decision-required'
      NEXT_REASON="索引无该票条目但站路径已存在（状态不一致，须人工裁决）: ${worktree}"
    else
      NEXT_STEP='open'
      NEXT_REASON='索引无该票条目：先经 ticket-ops open 开票'
    fi
    return 0
  fi
  if [ -e "$worktree" ] && ! worktree_path_valid; then
    NEXT_STEP='decision-required'
    NEXT_REASON="站路径存在但不是有效 Git worktree（须人工裁决）: ${worktree}"
    return 0
  fi
  if worktree_path_valid && [ "$(worktree_branch)" != "ticket/${ticket_id}" ]; then
    NEXT_STEP='decision-required'
    NEXT_REASON="站分支不是 ticket/${ticket_id}（实际 $(worktree_branch)），须人工裁决"
    return 0
  fi
  case $_status in
    ready)
      NEXT_STEP='start'
      NEXT_REASON='票已就绪：建站并领取（start 幂等，重跑收敛）'
      ;;
    in_progress)
      if worktree_path_valid; then
        NEXT_STEP='contract implementation'
        NEXT_REASON='票已领取且站就绪：渲染实现阶段合同'
      else
        NEXT_STEP='start'
        NEXT_REASON='票已领取但站缺失：重跑 start 补建站（幂等）'
      fi
      ;;
    review_ready)
      if worktree_path_valid; then
        NEXT_STEP='contract review'
        NEXT_REASON='票待审查：渲染审查阶段合同'
      else
        NEXT_STEP='decision-required'
        NEXT_REASON='票待审查但站缺失（审查须在站内进行），须人工裁决'
      fi
      ;;
    review_pass)
      if worktree_path_valid; then
        NEXT_STEP='commit'
        NEXT_REASON='Review 结论已 pass：进入 commit 门禁'
      else
        NEXT_STEP='decision-required'
        NEXT_REASON='票 review_pass 但站缺失，须人工裁决'
      fi
      ;;
    review_fail)
      if worktree_path_valid; then
        NEXT_STEP='contract implementation'
        NEXT_REASON='审查未过：返工实现'
      else
        NEXT_STEP='decision-required'
        NEXT_REASON='票 review_fail 但站缺失，须人工裁决'
      fi
      ;;
    blocked)
      NEXT_STEP='decision-required'
      NEXT_REASON='票处于 blocked：须人工裁决解阻'
      ;;
    done|superseded)
      NEXT_STEP='done'
      NEXT_REASON="票处于终态 ${_status}：无下一步"
      ;;
    *)
      NEXT_STEP='decision-required'
      NEXT_REASON="索引状态不在状态机取值内: ${_status}"
      ;;
  esac
}

# ---- next：推导下一步（不落 intent；--clear-intent 仅清已判不可收敛的残留日志）----

conveyor_next() {
  compute_next
  _pending=$(pending_intent_step 2>/dev/null) || _pending=''
  _pending_nonconvergent=0
  if [ -n "$_pending" ]; then
    # 恢复提示须先对照该命令的状态前置：start 只接受 ready|in_progress。前置不满足时
    # 提示重跑会立刻被拒且 intent 永不清除（永不收敛），故归 decision-required 并给
    # 登记清除路径；review_ready/review_pass/blocked 等非可领取状态同口径。
    case $_pending in
      worktree|take)
        case ${_status:-} in
          ready|in_progress)
            if [ "$NEXT_STEP" != 'decision-required' ]; then
              NEXT_STEP='start'
              NEXT_REASON="上次 ${_pending} 步骤未完成：先重跑 start 收敛（幂等补齐）"
            fi
            ;;
          *)
            NEXT_STEP='decision-required'
            NEXT_REASON="上次 ${_pending} 步骤未完成，但索引状态 ${_status:-未知} 不满足 start 前置（只接受 ready|in_progress）——须人工裁决，清除路径见下行"
            _pending_nonconvergent=1
            ;;
        esac
        ;;
      record)
        if worktree_path_valid; then
          if [ "$NEXT_STEP" != 'decision-required' ]; then
            NEXT_STEP='record'
            NEXT_REASON='上次 record 步骤未完成：重跑 record 收敛（同内容不重写）'
          fi
        else
          NEXT_STEP='decision-required'
          NEXT_REASON="上次 record 步骤未完成但站缺失（record 要求站已存在）——须人工裁决，清除路径见下行"
          _pending_nonconvergent=1
        fi
        ;;
    esac
  fi

  if [ "$clear_intent" -eq 1 ]; then
    # 清除只对「已判不可收敛」的残留开放：仍可收敛的残留是唯一恢复信号，删掉会掩盖
    # start/record 本应做的幂等补齐（如索引已 in_progress 但账本缺 take 行）。
    intent_ensure
    if [ -z "$_pending" ]; then
      printf 'ticket-run: intent: 无残留操作记录（%s）\n' "$intent_file"
    elif [ "$_pending_nonconvergent" -eq 0 ]; then
      case $_pending in
        worktree|take) _retry='start' ;;
        record) _retry='record' ;;
        *) _retry=$_pending ;;
      esac
      die1 "残留 intent 仍可收敛，拒绝清除——请重跑 ${_retry}（intent 保留: ${intent_file}）"
    else
      printf 'ticket-run: intent: 将清除 %s，原内容：\n' "$intent_file"
      sed 's/^/ticket-run: intent:   /' "$intent_file"
      rm -f "$intent_file" || die1 "intent 清除失败: ${intent_file}"
      printf 'ticket-run: intent: 已清除残留操作记录\n'
      compute_next
      _pending=''
    fi
  fi

  printf 'ticket-run: 下一步: %s\n' "$NEXT_STEP"
  printf 'ticket-run: 原因: %s\n' "$NEXT_REASON"
  if [ -n "$_pending" ]; then
    printf 'ticket-run: 恢复: 上次 %s 步骤未完成，重跑收敛\n' "$_pending"
    if [ "$NEXT_STEP" = 'decision-required' ]; then
      printf 'ticket-run: 清除: 核对索引后执行 sh ticket-run.sh %s next --clear-intent（登记于用法与同目录 README.md）\n' "$nn"
    fi
  fi
  if [ "$NEXT_STEP" = 'decision-required' ]; then
    exit 1
  fi
  exit 0
}

# ---- start：建站 → 领取（各步幂等工具，intent 先行）----

worktree_fence_intact() {
  # 站完整性核验（skip 与新建主路径共用）：栅栏配置与 delivery.rules main-only 清单同源。
  # 返回 0=完整；2=解析器缺失/解析破坏；3=main-only 节未声明；4=sparseCheckout 未设；
  # 5=main-only 路径仍在场（栅栏未生效）；6=索引非空但工作树有删除记录（不完整）；
  # 7=sparse 配置缺 main-only 排除规则；8=索引为空（未物化）。
  _fence_path=''
  _parser="${script_dir}/dp-load-rules.sh"
  [ -r "$_parser" ] || return 2
  # shellcheck source=agent-up/scripts/dp-load-rules.sh  # 动态同目录加载
  # shellcheck disable=SC1091  # 共享解析器由运行时同目录定位，单文件分析无法跟随动态路径
  . "$_parser"
  [ "${DP_PARSER_VERSION:-0}" -ge 2 ] || return 2
  dp_load_rules "$repo_root" ticket-run || return 2
  [ "${DP_MAINONLY_DECLARED:-0}" -eq 1 ] || return 3
  [ "$(git -C "$worktree" config --get core.sparseCheckout 2>/dev/null)" = 'true' ] || return 4
  # 物化硬断言：--no-checkout 后 read-tree 前被杀会留下空索引（ls-files 为空），
  # 此时 sparse 配置可能看似完整，必须单独判「未物化」而不是「有删除」。
  _fence_files=$(git -C "$worktree" ls-files 2>/dev/null) || return 2
  _fence_status=$(git -C "$worktree" status --porcelain 2>/dev/null) || return 2
  # 去除状态覆盖暂存删除 `D `、未暂存删除 ` D` 与双删 `DD`（后者即空索引窗口）。
  if printf '%s\n' "$_fence_status" | grep -qE '^(D | D|DD)'; then
    [ -n "$_fence_files" ] || return 8
    return 6
  fi
  [ -n "$_fence_files" ] || return 8
  _fence_gitdir=$(git -C "$worktree" rev-parse --absolute-git-dir 2>/dev/null) || return 2
  _fence_sparse="${_fence_gitdir}/info/sparse-checkout"
  [ -r "$_fence_sparse" ] || return 7
  _fence_ifs=$IFS
  IFS=$NL
  for _fence_path in $DP_MAINONLY; do
    [ -n "$_fence_path" ] || continue
    if [ -e "$worktree/$_fence_path" ]; then
      IFS=$_fence_ifs
      return 5
    fi
    if ! grep -F -q -x -- "!${_fence_path}" "$_fence_sparse"; then
      IFS=$_fence_ifs
      return 7
    fi
  done
  IFS=$_fence_ifs
  return 0
}

worktree_fence_require() {
  # 核验并 fail-closed：任何不完整都 decision-required（die1 退出，调用方零后续写入）。
  _fence_rc=0
  worktree_fence_intact || _fence_rc=$?
  case $_fence_rc in
    0) ;;
    2) die1 "decision-required: 站无法核验 worktree 栅栏（dp-load-rules.sh 缺失/版本漂移/delivery.rules 解析破坏）——须人工裁决: ${worktree}" ;;
    3) die1 'decision-required: delivery.rules 未声明 main-only 节（栅栏未知，无法判定站完整性）——须人工裁决' ;;
    4) die1 "decision-required: 站栅栏未生效（core.sparseCheckout 未设）——须按 worktree-add.sh 重建站后重跑: ${worktree}" ;;
    5) die1 "decision-required: 站栅栏未生效（main-only 路径仍在场: ${_fence_path}）——须按 worktree-add.sh 重建站后重跑: ${worktree}" ;;
    6) die1 "decision-required: 站内工作树不完整（索引有条目但存在删除记录）——须先恢复站内文件或提交删除后重跑（勿直接重建站）: ${worktree}" ;;
    7) die1 "decision-required: 站 sparse 配置缺 main-only 排除规则（${_fence_path}）——须按 worktree-add.sh 重建站后重跑: ${worktree}" ;;
    8) die1 "decision-required: 站索引为空（--no-checkout 后 read-tree 未物化）——须按 worktree-add.sh 删除并重建站后重跑: ${worktree}" ;;
    *) die1 "decision-required: 站栅栏核验失败（内部错误 ${_fence_rc}）——须人工裁决: ${worktree}" ;;
  esac
}

conveyor_start() {
  _status=$(index_status) || _status=''
  [ -n "$_status" ] || die1 "start 前置未满足：索引无该票条目（先 open）: ${ticket_id}"
  case $_status in
    ready|in_progress) ;;
    blocked) die1 'decision-required: 票处于 blocked——须人工裁决解阻后再 start' ;;
    *) die1 "decision-required: start 只接受 ready|in_progress，实际 ${_status}" ;;
  esac

  if [ -e "$worktree" ]; then
    worktree_path_valid || \
      die1 "decision-required: 站路径存在但不是有效 Git worktree: ${worktree}"
    [ "$(worktree_branch)" = "ticket/${ticket_id}" ] || \
      die1 "decision-required: 站分支不是 ticket/${ticket_id}: $(worktree_branch)"
    worktree=$(CDPATH='' cd -- "$worktree" && pwd -P) || die2 'worktree 物理路径不可解析'
    worktree_fence_require
    intent_record worktree "done"
  else
    worktree_add="${script_dir}/worktree-add.sh"
    [ -r "$worktree_add" ] || die2 "建站原子层缺失: ${worktree_add}"
    intent_record worktree started
    mkdir -p "$(dirname "$worktree")" || die1 "站容器目录创建失败: $(dirname "$worktree")"
    (cd "$repo_root" && sh "$worktree_add" "$worktree" "ticket/${ticket_id}" >&2) || \
      die1 "worktree 创建失败（intent 已记 started）——重跑 start 收敛: ${worktree}"
    worktree_path_valid || die1 "建站后站路径不是有效 Git worktree: ${worktree}"
    worktree=$(CDPATH='' cd -- "$worktree" && pwd -P) || die2 'worktree 物理路径不可解析'
    # 新建主路径与 skip 分支同一判定：建站返回 0 不等于栅栏已生效。
    worktree_fence_require
    intent_record worktree "done"
  fi

  # 领取账本行：日期与 ticket-ops 的 updated_at 同源（本地 date +%F），否则本地
  # 00:00–07:59 领取时 UTC 日期落后一天，重跑会因日期不同落第二条账本行。
  # 索引已 in_progress（重放）时取索引 updated_at 的日期，跨午夜重跑仍是同一行。
  _ledger_date=$(date '+%F')
  if [ "$_status" = 'in_progress' ]; then
    _updated=$(index_updated_at) || _updated=''
    case $_updated in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) _ledger_date=${_updated%%T*} ;;
    esac
  fi
  ledger_line=$(printf '{"date":"%s","kind":"change","scope":"%s","decision":"ticket-run start：领取 %s（in_progress）","evidence_ref":"facts/requirements/tickets/%s.json"}' \
    "$_ledger_date" "$nn" "$ticket_id" "$ticket_id")
  ticket_ops="${script_dir}/ticket-ops.sh"
  [ -r "$ticket_ops" ] || die2 "票务状态写入原子层缺失（状态写入唯一核心）: ${ticket_ops}"
  intent_record take started
  sh "$ticket_ops" "$repo_root" take --id "$ticket_id" --status in_progress \
    --ledger-line "$ledger_line" >&2 || \
    die1 "领取未完成（intent 已记 started，已写部分如实报告）——重跑 start 收敛"
  intent_record take "done"

  printf 'ticket-run: 站路径: %s\n' "$worktree"
  printf 'ticket-run: 票状态: in_progress\n'
  printf 'ticket-run: 下一步: contract implementation\n'
  exit 0
}

# ---- contract：渲染合同（纯函数，站必须在位）----

conveyor_contract() {
  worktree_path_valid || die1 "站不存在或不是有效 Git worktree（先 start）: ${worktree}"
  contract_file=$(mktemp "${TMPDIR:-/tmp}/ticket-run-${nn}-${stage}.XXXXXX") || die2 '合同临时文件创建失败'
  if ! sh "$contract_build" "$stage" "$nn" "$repo_root" > "$contract_file"; then
    rm -f "$contract_file"
    die1 '阶段合同渲染失败（contract-build fail-closed，未产出站路径或执行提交）'
  fi
  printf 'ticket-run: 站路径: %s\n' "$(CDPATH='' cd -- "$worktree" && pwd -P)"
  printf 'ticket-run: 合同文件: %s\n' "$contract_file"
  exit 0
}

# ---- record：收据字段合同校验＋幂等落位 ----
# 字段合同镜像 agent-up/references/schemas/receipt.schema.json（套件逐项核对常量与
# schema 一致）；运行时不依赖 schema 文件，安装闭包零新增数据件。

receipt_props='schema_version receipt_kind ticket_id created_at actor base_sha head_sha diff_sha commit_sha target_stage implementer_identity reviewer_identity reviewed_at verdict acceptance commit_message notes'
receipt_required_top='schema_version receipt_kind ticket_id created_at actor'
receipt_sha_fields='base_sha head_sha diff_sha commit_sha'

receipt_fail() { die1 "收据校验未过（receipt.schema.json 字段合同）: $1"; }

receipt_get() { python3 "$_engine" json get "$1" "$2" 2>/dev/null; }
receipt_has() { python3 "$_engine" json get "$1" "$2" >/dev/null 2>&1; }
receipt_type() { python3 "$_engine" json type "$1" "$2" 2>/dev/null; }

receipt_kind_requires() {
  case $1 in
    dispatch) printf '%s' 'base_sha target_stage' ;;
    implementation) printf '%s' 'base_sha head_sha implementer_identity commit_sha' ;;
    review) printf '%s' 'base_sha head_sha diff_sha reviewer_identity reviewed_at verdict acceptance' ;;
    commit) printf '%s' 'base_sha commit_sha commit_message' ;;
  esac
}

receipt_pattern_ok() {
  printf '%s' "$1" | LC_ALL=C grep -Eq "$2"
}

receipt_validate() {
  _source=$1
  [ -f "$_source" ] || receipt_fail "收据文件不存在: ${_source}"
  [ -r "$_source" ] || receipt_fail "收据文件不可读: ${_source}"
  python3 "$_engine" json fields "$_source" actor >/dev/null 2>&1 || \
    receipt_fail "收据不可解析或顶层不是对象: ${_source}"

  _total=$(python3 "$_engine" json len "$_source" '') || receipt_fail "收据不可解析: ${_source}"
  _known=0
  for _key in $receipt_props; do
    if receipt_has "$_source" "$_key"; then _known=$((_known + 1)); fi
  done
  [ "$_total" -eq "$_known" ] || \
    receipt_fail "含 schema 未定义的顶层字段（实际 ${_total} 键，已登记 ${_known} 键）"

  for _key in $receipt_required_top; do
    _value=$(receipt_get "$_source" "$_key") || receipt_fail "缺必备字段: ${_key}"
    [ -n "$_value" ] || receipt_fail "必备字段为空: ${_key}"
  done

  [ "$(receipt_type "$_source" schema_version)" = 'number' ] || \
    receipt_fail "schema_version 须为数值 1（schema type: number, const 1）"
  [ "$(receipt_get "$_source" schema_version)" = '1' ] || \
    receipt_fail "schema_version 须为 1: $(receipt_get "$_source" schema_version)"
  for _key in receipt_kind ticket_id created_at actor commit_message implementer_identity reviewer_identity notes; do
    if receipt_has "$_source" "$_key"; then
      [ "$(receipt_type "$_source" "$_key")" = 'string' ] || \
        receipt_fail "${_key} 须为字符串（schema type: string）: $(receipt_get "$_source" "$_key")"
    fi
  done
  _kind=$(receipt_get "$_source" receipt_kind)
  case $_kind in
    dispatch|implementation|review|commit) ;;
    *) receipt_fail "receipt_kind 越枚举: ${_kind}" ;;
  esac
  _tid=$(receipt_get "$_source" ticket_id)
  receipt_pattern_ok "$_tid" '^[0-9][0-9]*-[a-z0-9-]+$' || \
    receipt_fail "ticket_id 不合 <NN>-<slug> 形态: ${_tid}"
  [ "$_tid" = "$ticket_id" ] || receipt_fail "ticket_id 与票文件不符: ${_tid} ≠ ${ticket_id}"
  _created=$(receipt_get "$_source" created_at)
  receipt_pattern_ok "$_created" '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$' || \
    receipt_fail "created_at 须为 UTC ISO 8601 秒粒度: ${_created}"

  for _key in $(receipt_kind_requires "$_kind"); do
    _value=$(receipt_get "$_source" "$_key") || receipt_fail "${_kind} 收据缺条件必备字段: ${_key}"
    [ -n "$_value" ] || receipt_fail "${_kind} 收据条件必备字段为空: ${_key}"
  done

  for _key in $receipt_sha_fields; do
    if receipt_has "$_source" "$_key"; then
      _value=$(receipt_get "$_source" "$_key")
      receipt_pattern_ok "$_value" '^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]*$' || \
        receipt_fail "${_key} 须为小写十六进制 sha: ${_value}"
      [ "${#_value}" -eq 40 ] || receipt_fail "${_key} 须为 40 位 sha: ${_value}"
    fi
  done

  if receipt_has "$_source" reviewed_at; then
    _value=$(receipt_get "$_source" reviewed_at)
    receipt_pattern_ok "$_value" '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$' || \
      receipt_fail "reviewed_at 须为 UTC ISO 8601 秒粒度: ${_value}"
  fi
  if receipt_has "$_source" verdict; then
    _value=$(receipt_get "$_source" verdict)
    case $_value in
      PASS|PASS_WITH_NOTES|FAIL) ;;
      *) receipt_fail "verdict 越枚举（PASS|PASS_WITH_NOTES|FAIL）: ${_value}" ;;
    esac
  fi
  if receipt_has "$_source" target_stage; then
    _value=$(receipt_get "$_source" target_stage)
    case $_value in
      implementation|review|commit) ;;
      *) receipt_fail "target_stage 越枚举（implementation|review|commit）: ${_value}" ;;
    esac
  fi
  if receipt_has "$_source" acceptance; then
    _n=$(python3 "$_engine" json len "$_source" acceptance) || \
      receipt_fail 'acceptance 须为数组'
    [ "$_n" -ge 1 ] || receipt_fail 'acceptance 不得为空'
    _i=0
    while [ "$_i" -lt "$_n" ]; do
      _item_keys=$(python3 "$_engine" json len "$_source" "acceptance.$_i") || \
        receipt_fail "acceptance[${_i}] 须为对象"
      _item_known=0
      for _k in ac_id result evidence; do
        if receipt_has "$_source" "acceptance.$_i.$_k"; then _item_known=$((_item_known + 1)); fi
      done
      [ "$_item_keys" -eq "$_item_known" ] || \
        receipt_fail "acceptance[${_i}] 含 schema 未定义的键（实际 ${_item_keys} 键，已登记 ${_item_known} 键）"
      _ac=$(receipt_get "$_source" "acceptance.$_i.ac_id") || \
        receipt_fail "acceptance[${_i}] 缺 ac_id"
      [ -n "$_ac" ] || receipt_fail "acceptance[${_i}].ac_id 不得为空"
      _res=$(receipt_get "$_source" "acceptance.$_i.result") || \
        receipt_fail "acceptance[${_i}] 缺 result"
      case $_res in
        pass|fail|unknown) ;;
        *) receipt_fail "acceptance[${_i}].result 越枚举（pass|fail|unknown）: ${_res}" ;;
      esac
      if receipt_has "$_source" "acceptance.$_i.evidence"; then
        [ "$(receipt_type "$_source" "acceptance.$_i.evidence")" = 'string' ] || \
          receipt_fail "acceptance[${_i}].evidence 须为字符串（schema type: string）"
      fi
      _i=$((_i + 1))
    done
  fi
}

conveyor_record() {
  worktree_path_valid || die1 "站不存在或不是有效 Git worktree（先 start）: ${worktree}"
  _worktree=$(CDPATH='' cd -- "$worktree" && pwd -P) || die2 'worktree 物理路径不可解析'
  receipt_validate "$receipt_file"
  _kind=$(receipt_get "$receipt_file" receipt_kind)
  case $_kind in
    review) _target_rel="facts/requirements/tickets/${ticket_id}.review-evidence.json" ;;
    *) _target_rel="facts/requirements/runs/${ticket_id}.${_kind}.receipt.json" ;;
  esac
  _receipt_abs=$(CDPATH='' cd -- "$(dirname -- "$receipt_file")" && pwd -P)/$(basename -- "$receipt_file") || \
    die2 "收据物理路径不可解析: ${receipt_file}"
  _target="${_worktree}/${_target_rel}"
  if [ -f "$_target" ]; then
    if cmp -s "$_receipt_abs" "$_target"; then
      intent_record record "done"
      printf 'ticket-run: 收据: %s（已收敛：内容一致，未重写）\n' "$_target"
      exit 0
    fi
    die1 "decision-required: 收据已在场且内容不同——证据不可静默覆盖: ${_target_rel}"
  fi
  intent_record record started "$_receipt_abs" "$_kind"
  mkdir -p "$(dirname "$_target")" || die1 "收据目录创建失败: $(dirname "$_target")"
  _tmp="${_target}.ticket-run.tmp"
  cp "$_receipt_abs" "$_tmp" || { rm -f "$_tmp"; die1 "收据暂存失败: ${_tmp}"; }
  mv "$_tmp" "$_target" || { rm -f "$_tmp"; die1 "收据落位失败: ${_target}"; }
  intent_record record "done"
  printf 'ticket-run: 收据校验: PASS（receipt.schema.json 字段合同：%s）\n' "$_kind"
  printf 'ticket-run: 收据: %s\n' "$_target"
  exit 0
}

# ---- verify-dispatch：重渲染比对，三类拒绝 ----

conveyor_verify_dispatch() {
  _rendered=$(mktemp "${TMPDIR:-/tmp}/ticket-run-vd-${nn}-${stage}.XXXXXX") || die2 '合同暂存文件创建失败'
  _verr="${_rendered}.err"
  if ! sh "$contract_build" "$stage" "$nn" "$repo_root" > "$_rendered" 2> "$_verr"; then
    cat "$_verr" >&2
    rm -f "$_rendered" "$_verr"
    die1 "dispatch.${stage} 校验未过（票面缺阶段对象/缺键/空白值，contract-build fail-closed）"
  fi
  rm -f "$_verr"
  if [ -n "$contract_arg" ]; then
    [ -f "$contract_arg" ] || { rm -f "$_rendered"; die1 "合同文件不存在: ${contract_arg}"; }
    [ -r "$contract_arg" ] || { rm -f "$_rendered"; die1 "合同文件不可读: ${contract_arg}"; }
    if ! cmp -s "$_rendered" "$contract_arg"; then
      rm -f "$_rendered"
      die1 "合同文件与票面 dispatch.${stage} 漂移（重渲染逐字不一致）: ${contract_arg}"
    fi
  fi
  rm -f "$_rendered"
  printf 'ticket-run: verify-dispatch: PASS %s（键集恰等＋合同自校验通过）\n' "$stage"
  exit 0
}

case $cmd in
  next) conveyor_next ;;
  start) conveyor_start ;;
  contract) conveyor_contract ;;
  record) conveyor_record ;;
  verify-dispatch) conveyor_verify_dispatch ;;
esac

# ---- legacy 三阶段（行为与原实现一致）----

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
