#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P03（base 可溯）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p03。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p03() {
# ---- P03 base 可溯 ----

if ! _is_sha "$R_BASE"; then
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 非 40 位小写十六进制: ${R_BASE:-缺失}"
elif ! git -C "$REPO" cat-file -e "$R_BASE^{commit}" 2>/dev/null; then
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 不可解析: $R_BASE"
elif ! _is_sha "$R_HEAD" || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_unknown P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — head_sha 不可解析，base 祖先关系无从判断"
elif git -C "$REPO" merge-base --is-ancestor "$R_BASE" "$R_HEAD" 2>/dev/null; then
  p_pass P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base 可解析且为 head 祖先"
else
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 非 head 祖先: $R_BASE"
fi
}
