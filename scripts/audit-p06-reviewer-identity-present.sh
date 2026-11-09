#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P06（审查者字段在场）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p06。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p06() {
# ---- P06 审查者字段在场 ----

case $R_REVIEWER in
  '') p_fail P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失或为空" ;;
  *[[:space:]]*) p_fail P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 含空白字符" ;;
  *) p_pass P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 非空无空白" ;;
esac
}
