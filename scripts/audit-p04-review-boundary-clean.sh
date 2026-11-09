#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P04（审阅边界干净）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p04。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p04() {
# ---- P04 审阅边界干净 ----

if ! _is_sha "$R_HEAD" || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_fail P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head_sha 不可解析: ${R_HEAD:-缺失}"
elif ! git -C "$REPO" merge-base --is-ancestor "$R_HEAD" "$TARGET" 2>/dev/null; then
  p_fail P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head_sha 非 target 祖先（证据所绑产品提交不在此历史）"
else
  _changed=$(git -C "$REPO" diff --name-only "$R_HEAD" "$TARGET" 2>/dev/null) || _changed='@@DIFF-FAILED@@'
  _extra=''
  _old_ifs=$IFS
  IFS='
'
  for _path in $_changed; do
    [ "$_path" = "$EVIDENCE_REL" ] && continue
    _allowed=0
    for _ap in $ALLOW_AFTER; do
      [ "$_path" = "$_ap" ] && { _allowed=1; break; }
    done
    [ "$_allowed" -eq 1 ] || { _extra=$_path; break; }
  done
  IFS=$_old_ifs
  if [ -n "$_extra" ]; then
    p_fail P04 review-boundary-clean "$_extra:1 — head 之后出现证据文件与显式允许集以外的改动（审阅边界被污染）"
  else
    p_pass P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head 之后仅证据文件与显式允许集文件提交（边界干净）"
  fi
fi
}
