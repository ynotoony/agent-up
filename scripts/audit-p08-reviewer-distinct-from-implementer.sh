#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P08（审查者非实现者）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p08。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p08() {
# ---- P08 审查者非实现者（自签拒绝）----

_impl_heads=''
if _is_sha "$R_HEAD" && git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  _impl_heads=$(_commit_email "$R_HEAD")
fi
if [ -z "$R_REVIEWER" ]; then
  p_unknown P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失，自签判定无从进行"
elif [ -z "$_impl_heads" ] && [ "$POLICY_STATE" != 'known' ]; then
  p_unknown P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 实现者身份不可得（head 无 author email 且无策略），自签判定无从进行"
else
  _impl_set=$_impl_heads
  if [ "$POLICY_STATE" = 'known' ] && [ -n "$POLICY_IMPL" ]; then
    _impl_set="$_impl_heads
$POLICY_IMPL"
  fi
  if _id_in "$R_REVIEWER" "$_impl_set"; then
    p_fail P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 审查者与实现者身份相同（自签不作独立审查证据）"
  else
    p_pass P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 审查者不在实现者身份集内"
  fi
fi
}
