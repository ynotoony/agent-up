#!/bin/sh
# Input: ticket-audit.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由引擎
#        在分派前准备（REPO/TARGET、EVIDENCE/EVIDENCE_REL、EVIDENCE_TRACKED/
#        EVIDENCE_COMMIT/EVIDENCE_BLOB/WORKTREE_BLOB、TICKET_ID、R_* 字段、POLICY_*、
#        ALLOW_AFTER 与 p_pass/p_fail/p_unknown/field_line/_is_sha/jget/jlen/load_ids/_id_in 等）。
# Output: 单一谓词判定——经 p_pass/p_fail/p_unknown 输出 PASS/FAIL/UNKNOWN 行并计数；
#         只判定，不打印证据位置/操作面/汇总/判定行，不设置退出码。
# Pos: 证据审计引擎谓词分片 P10（验收结果完备）；注册表行＝audit-predicates.rules，interface
#      函数名＝check_p10。新增一条谓词＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

check_p10() {
# ---- P10 验收结果完备 ----

_p10_reason=''
case $R_VERDICT in
  PASS|PASS_WITH_NOTES|FAIL) ;;
  *) _p10_reason="verdict 非受控三值（实际: ${R_VERDICT:-缺失}；自由文本结论不作证据）" ;;
esac
if [ -z "$_p10_reason" ]; then
  _alen=$(jlen "$EVIDENCE" acceptance) || _alen=''
  case $_alen in
    ''|0|*[!0-9]*) _p10_reason='acceptance 缺失、非数组或空数组' ;;
  esac
fi
if [ -z "$_p10_reason" ]; then
  [ "$R_VERDICT" = 'FAIL' ] && _p10_reason='verdict=FAIL：审查结论未通过，不构成可放行证据'
fi
if [ -z "$_p10_reason" ]; then
  _ai=0
  while [ "$_ai" -lt "$_alen" ]; do
    _ac=$(jget "$EVIDENCE" "acceptance.$_ai.ac_id") || _ac=''
    _ar=$(jget "$EVIDENCE" "acceptance.$_ai.result") || _ar=''
    if [ -z "$_ac" ]; then
      _p10_reason="acceptance[$_ai].ac_id 缺失或为空"
      break
    fi
    case $_ar in
      pass|fail|unknown) ;;
      *) _p10_reason="acceptance[$_ai]（${_ac}）result 非受控三值（实际: ${_ar:-缺失}）"; break ;;
    esac
    if [ "$R_VERDICT" = 'PASS' ] && [ "$_ar" != 'pass' ]; then
      _p10_reason="verdict=PASS 但 acceptance[$_ai]（${_ac}）result=$_ar"
      break
    fi
    _ai=$((_ai + 1))
  done
fi
if [ -z "$_p10_reason" ]; then
  p_pass P10 acceptance-results-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" acceptance) — verdict=$R_VERDICT 且 $_alen 条验收结果齐备"
else
  p_fail P10 acceptance-results-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" acceptance) — $_p10_reason"
fi
}
