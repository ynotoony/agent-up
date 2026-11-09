#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P05（diff 指纹绑定）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p05。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p05() {
# ---- P05 diff 指纹绑定 ----

if ! _is_sha "$R_BASE" || ! _is_sha "$R_HEAD" \
  || ! git -C "$REPO" cat-file -e "$R_BASE^{commit}" 2>/dev/null \
  || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_unknown P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — base/head 不可解析，diff 指纹无从重算"
elif ! _is_sha "$R_DIFF"; then
  p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 非 40 位小写十六进制: ${R_DIFF:-缺失}"
else
  _actual=$(git -C "$REPO" diff --no-color --no-ext-diff --no-textconv --binary "$R_BASE" "$R_HEAD" 2>/dev/null | git -C "$REPO" hash-object --stdin 2>/dev/null) || _actual=''
  _empty_diff=$(git -C "$REPO" hash-object --stdin </dev/null 2>/dev/null) || _empty_diff=''
  if [ "$R_BASE" = "$R_HEAD" ]; then
    p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — base_sha 与 head_sha 相同（零实现 diff，证据未绑定任何实现变更）"
  elif [ -n "$_actual" ] && [ -n "$_empty_diff" ] && [ "$_actual" = "$_empty_diff" ]; then
    p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — base..head 无差异（空 diff，diff_sha 未绑定任何实现变更）"
  elif [ -n "$_actual" ] && [ "$_actual" = "$R_DIFF" ]; then
    p_pass P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 等于 base..head 重算指纹"
  else
    p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 与 base..head 重算指纹不符（声明: ${R_DIFF}，实测: ${_actual:-重算失败}）"
  fi
fi
}
