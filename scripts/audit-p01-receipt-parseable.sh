#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P01（收据可解析）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p01。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p01() {
# ---- P01 收据可解析 ----

if [ -z "$EVIDENCE_REL" ]; then
  p_fail P01 receipt-parseable "$EVIDENCE:1 — 证据文件不在仓库内（无法绑定 Git 事实）"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
elif [ ! -f "$EVIDENCE" ]; then
  p_fail P01 receipt-parseable "$EVIDENCE_REL:1 — 证据文件缺失"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
elif ! json_readable "$EVIDENCE"; then
  p_fail P01 receipt-parseable "$EVIDENCE_REL:1 — 证据不可解析为 JSON"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
else
  R_SCHEMA=$(jget "$EVIDENCE" schema_version) || R_SCHEMA=''
  R_KIND=$(jget "$EVIDENCE" receipt_kind) || R_KIND=''
  R_TICKET=$(jget "$EVIDENCE" ticket_id) || R_TICKET=''
  if [ "$R_SCHEMA" != '1' ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" schema_version) — schema_version 非 1（实际: ${R_SCHEMA:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  elif [ "$R_KIND" != 'review' ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" receipt_kind) — receipt_kind 非 review（实际: ${R_KIND:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  elif [ "$R_TICKET" != "$TICKET_ID" ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" ticket_id) — ticket_id 与票文件不一致（票: ${TICKET_ID}，收据: ${R_TICKET:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  else
    p_pass P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" receipt_kind) — review 收据可解析且 ticket_id 匹配"
  fi
fi
}
