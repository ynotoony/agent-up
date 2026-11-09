#!/bin/sh
# Input: 调用方（common-helpers.sh 或同一读者）已定义的 _script_name 报文辅助；参数为
#        票 id、JSON 引擎路径、票体来源（路径或 '-'）。
# Output: review_checkpoint_allow_after：Review Checkpoint 规范路径的允许集形态判定
#        （唯一实现，ticket-ops 证据门与 merge-ticket 合并门共用）。
# Pos: 证据门策略模块（票 294：从 common-helpers.sh 分出域策略）；通用错误报文与锁原语
#      不在此件。
# shellcheck disable=SC2154  # 跨件共享状态（调用方报文辅助），单文件视野误报

# review_checkpoint_allow_after <票 id> <JSON 引擎> <票体来源>
# 证据门允许集里 Review Checkpoint 路径的唯一判定实现：<票体来源> 为票体文件路径或
# '-'（读 stdin）。票面 dispatch.commit.REVIEW_PASS_CHECKPOINT 恰为本票规范路径
# facts/requirements/tickets/<id>-review-checkpoint.md 时打印该路径；未声明或形态
# 不符打印空（形态不符附告警）。ticket-ops 证据门与 merge-ticket 合并门共用本函数，
# 禁止各写一份——两处口径必须同源，否则 done 能过而 merge 恒拒。
review_checkpoint_allow_after() {
  _rca_id=$1
  _rca_engine=$2
  _rca_src=$3
  [ -f "$_rca_engine" ] || return 0
  _rca_val=$(python3 "$_rca_engine" json get "$_rca_src" 'dispatch.commit.REVIEW_PASS_CHECKPOINT' 2>/dev/null) || _rca_val=''
  case $_rca_val in
    '') ;;
    "facts/requirements/tickets/${_rca_id}-review-checkpoint.md") printf '%s\n' "$_rca_val" ;;
    *) printf '%s: 证据门: REVIEW_PASS_CHECKPOINT 形态不符，不纳入允许集: %s\n' "$(_script_name)" "$_rca_val" >&2 ;;
  esac
  return 0
}
