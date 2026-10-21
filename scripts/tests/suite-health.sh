#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite health "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: health（票 139 仪表盘四分区——打分趋势/候选调用/报警计数/对账降级；
# 夹具＝最小仓＋九键 lesson 行＋同目录 absorption/check-stale-claims 单件）
# ============================================================

hs_build_fixture() {
  # $1=夹具目录：repo/facts/project/changes.jsonl ＋ rules/implementation/scripts/ 三件单件
  rm -rf "$1"
  mkdir -p "$1/repo/facts/project" "$1/repo/rules/implementation/scripts"
  cp "$SCRIPT_DIR/health-summary.sh" "$SCRIPT_DIR/absorption-trigger.sh" "$SCRIPT_DIR/check-stale-claims.sh" "$SCRIPT_DIR/dp-load-rules.sh" "$1/repo/rules/implementation/scripts/"
}

hs_run() {
  ( cd "$1/repo" && sh rules/implementation/scripts/health-summary.sh ${2:+$2} )
}

suite_health() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='health'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/hs
  mkdir -p "$D"

  # 正例 P1：有打分＋有候选＋无报警 → 四分区齐全、打分区含分数序列
  hs_build_fixture "$D/p1"
  printf '{"date": "2026-10-11", "kind": "lesson", "scope": "t1", "decision": "a", "evidence_ref": "x", "promoted_to": "none", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n{"date": "2026-10-11", "kind": "lesson", "scope": "t1", "decision": "b", "evidence_ref": "x", "promoted_to": "none", "score_contract": 88, "score_predicate": 100, "score_rework": 0}\n{"date": "2026-10-11", "kind": "lesson", "scope": "t1", "decision": "c", "evidence_ref": "x", "promoted_to": "none", "score_contract": 85, "score_predicate": 100, "score_rework": 0}\n' > "$D/p1/repo/facts/project/changes.jsonl"
  hs_run "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '=== 打分 ===' "$D/p1.out" \
    && grep -q 't1: 最近分数' "$D/p1.out" \
    && grep -q 'PROMOTE 候选: scope=t1' "$D/p1.out" \
    && grep -q '=== 总结 ===' "$D/p1.out"; then
    ok '正例 P1 四分区齐全（打分序列＋PROMOTE 候选）'
  else
    bad '正例 P1 四分区齐全（打分序列＋PROMOTE 候选）' "exit=$rc $(head -c 150 "$D/p1.out")"
  fi

  # 正例 P2：空账本 → 各区显示（无）
  hs_build_fixture "$D/p2"
  : > "$D/p2/repo/facts/project/changes.jsonl"
  hs_run "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '（无打分记录' "$D/p2.out"; then
    ok '正例 P2 空账本 → 打分区（无）不虚构'
  else
    bad '正例 P2 空账本 → 各区（无）不虚构' "exit=$rc $(head -c 150 "$D/p2.out")"
  fi

  # 负例 N10：有 STALE（账本行缺文件指针沉淀被删形态）→ 报警区出 STALE 计数
  hs_build_fixture "$D/n10"
  printf '{"date": "2026-10-11", "kind": "lesson", "scope": "x", "decision": "沉淀到 rules/gone.md", "evidence_ref": "x", "promoted_to": "rules", "score_contract": 50, "score_predicate": 50, "score_rework": 1}\n' > "$D/n10/repo/facts/project/changes.jsonl"
  hs_run "$D/n10" > "$D/n10.out" 2>&1
  rc=$?
  if grep -q '易腐断言过期' "$D/n10.out" && grep -q 'rules/gone.md' "$D/n10.out"; then
    ok '负例 N10 S8 STALE → 报警区出计数与指针'
  else
    bad '负例 N10 S8 STALE → 报警区出计数与指针' "exit=$rc $(head -c 150 "$D/n10.out")"
  fi

  # 正例 P5：零写入复核（夹具跑前后 find 全等）
  _hs_before=$(cd "$D/p1/repo" && find . | LC_ALL=C sort)
  hs_run "$D/p1" > /dev/null 2>&1
  _hs_after=$(cd "$D/p1/repo" && find . | LC_ALL=C sort)
  if [ "$_hs_before" = "$_hs_after" ]; then
    ok '正例 P5 零写入复核（夹具前后 find 全等）'
  else
    bad '正例 P5 零写入复核（夹具前后 find 全等）'
  fi

  # 票 150 错误传播：负例 N11——delivery.rules 解析破坏（scanner gate exit 2）→
  # 报警区出"扫描器报错"行、总结行报视图不完整、exit 1，不把失败伪装成（无 STALE 报警）。
  hs_build_fixture "$D/n11"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_bogus x\n' > "$D/n11/repo/delivery.rules"
  : > "$D/n11/repo/facts/project/changes.jsonl"
  hs_run "$D/n11" > "$D/n11.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '易腐断言扫描器报错（check-stale-claims gate exit 2' "$D/n11.out" \
    && grep -q 'delivery.rules 解析破坏' "$D/n11.out" \
    && grep -q '报警缺失≠健康' "$D/n11.out" \
    && ! grep -q '（无 STALE 报警）' "$D/n11.out"; then
    ok '负例 N11 delivery.rules 解析破坏 → 扫描器报错向上传播 exit 1 不伪装健康（票 150）'
  else
    bad '负例 N11 delivery.rules 解析破坏 → 扫描器报错向上传播 exit 1 不伪装健康（票 150）' "exit=$rc $(head -c 150 "$D/n11.out")"
  fi

  # 票 150 正例 P6——清洁仓对照（AC2）：最小完整仓（合法索引＋投影再生＋空账本），
  # 扫描器 gate exit 0 → 报警区（无 STALE 报警）、exit 0，不因错误传播改造误报。
  hs_build_fixture "$D/p6"
  mkdir -p "$D/p6/repo/facts/requirements/tickets"
  : > "$D/p6/repo/facts/project/changes.jsonl"
  cat > "$D/p6/repo/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "01-fixture-clean", "status": "done", "complexity": "C0", "blocked_by": [], "updated_at": "2026-10-15T10:00"}
  ]
}
EOF
  mkdir -p "$D/p6/repo/agent-up/scripts"
  cp "$SCRIPT_DIR/json-helpers.sh" "$D/p6/repo/agent-up/scripts/"
  cp "$SCRIPT_DIR/generate-progress.sh" "$D/p6/repo/rules/implementation/scripts/"
  sh "$D/p6/repo/rules/implementation/scripts/generate-progress.sh" "$D/p6/repo" >/dev/null 2>&1
  hs_run "$D/p6" > "$D/p6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '（无 STALE 报警）' "$D/p6.out" && ! grep -q '扫描器报错' "$D/p6.out"; then
    ok '正例 P6 清洁仓（合法索引＋投影再生）→ 无报警 exit 0 不误报（票 150 AC2）'
  else
    bad '正例 P6 清洁仓（合法索引＋投影再生）→ 无报警 exit 0 不误报（票 150 AC2）' "exit=$rc $(head -c 150 "$D/p6.out")"
  fi

  suite_summary 'health'
}
