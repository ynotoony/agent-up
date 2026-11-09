#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P09（审查时间有效）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p09。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p09() {
# ---- P09 审查时间有效 ----

case $R_REVIEWED_AT in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) _ra_ok=1 ;;
  *) _ra_ok=0 ;;
esac
if [ "$_ra_ok" -eq 0 ]; then
  p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at 非 UTC ISO 8601 秒粒度: ${R_REVIEWED_AT:-缺失}"
else
  _ra_date=$(printf '%s' "$R_REVIEWED_AT" | cut -c1-10)
  _head_date=''
  if _is_sha "$R_HEAD" && git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
    _head_date=$(_commit_date "$R_HEAD")
  fi
  _ev_date=''
  if [ "$EVIDENCE_TRACKED" -eq 1 ] && [ -n "$EVIDENCE_COMMIT" ]; then
    _ev_date=$(_commit_date "$EVIDENCE_COMMIT")
  fi
  if [ -z "$_head_date" ]; then
    p_unknown P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — head 提交日期不可取，时间边界无从判断"
  elif [ -z "$_ev_date" ]; then
    p_unknown P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — 证据未提交，reviewed_at 上界无从判断"
  elif _date_lt "$_ra_date" "$_head_date"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at（${_ra_date}）早于 head 提交日（${_head_date}）"
  elif _date_lt "$_ev_date" "$_ra_date"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at（${_ra_date}）晚于证据提交日（${_ev_date}）"
  elif [ "$POLICY_STATE" = 'known' ] && _date_lt "$_ra_date" "$POLICY_EFFECTIVE"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — 旧 PASS：reviewed_at（${_ra_date}）早于策略生效日（${POLICY_EFFECTIVE}）"
  else
    p_pass P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at 落在 head 提交日与证据提交日之间$([ "$POLICY_STATE" = 'known' ] && printf '且不早于策略生效日')"
  fi
fi
}
