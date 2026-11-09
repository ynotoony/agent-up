#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P07（审查者身份可佐证）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p07。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p07() {
# ---- P07 审查者身份可佐证 ----

if [ -z "$R_REVIEWER" ]; then
  p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失，身份无从佐证"
elif [ "$EVIDENCE_TRACKED" -ne 1 ] || [ -z "$EVIDENCE_COMMIT" ]; then
  p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 证据未提交，收据 author 身份无从读取"
else
  _ev_email=$(_commit_email "$EVIDENCE_COMMIT")
  if [ -z "$_ev_email" ]; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 证据提交无 author email，身份无从佐证"
  elif [ "$(_lc "$R_REVIEWER")" != "$(_lc "$_ev_email")" ]; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 与证据提交 author（${_ev_email}）不一致，无法佐证"
  elif [ "$POLICY_STATE" = 'known' ] && ! _id_in "$R_REVIEWER" "$POLICY_TRUSTED"; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 身份不在策略 trusted_reviewers 名单，不宣称独立审查"
  else
    p_pass P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 与证据提交 author 一致$([ "$POLICY_STATE" = 'known' ] && printf '且属可信审查者名单')"
  fi
fi
}
