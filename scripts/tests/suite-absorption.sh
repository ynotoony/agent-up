#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite absorption "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: absorption-trigger（票 135 块级核对三断言——3 连高 PROMOTE/2 连低 FORBID/
# 混合不触发/数据不足 NOTE/空账本零输出；夹具＝最小账本九键 lesson 行）
# ============================================================

at_build_fixture() {
  # $1=夹具目录：repo/facts/project/changes.jsonl（脚本缺省根推导 ../..）
  rm -rf "$1"
  mkdir -p "$1/repo/facts/project" "$1/repo/rules/implementation/scripts"
  cp "$SCRIPT_DIR/absorption-trigger.sh" "$1/repo/rules/implementation/scripts/"
}

at_run() {
  # $1=夹具目录；脚本落位形态缺省根推导（rules/implementation/scripts/../.. = repo）
  ( cd "$1/repo" && sh rules/implementation/scripts/absorption-trigger.sh )
}

suite_absorption() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='absorption'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/at
  mkdir -p "$D"

  # 正例 P1：3 连高 → PROMOTE 候选行（含 scope 与分数序列）
  at_build_fixture "$D/p1"
  printf '{"date": "2026-10-10", "kind": "lesson", "scope": "t1", "decision": "a", "evidence_ref": "x", "promoted_to": "none", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n{"date": "2026-10-10", "kind": "lesson", "scope": "t1", "decision": "b", "evidence_ref": "x", "promoted_to": "none", "score_contract": 85, "score_predicate": 100, "score_rework": 0}\n{"date": "2026-10-10", "kind": "lesson", "scope": "t1", "decision": "c", "evidence_ref": "x", "promoted_to": "none", "score_contract": 95, "score_predicate": 100, "score_rework": 0}\n' > "$D/p1/repo/facts/project/changes.jsonl"
  at_run "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PROMOTE 候选: scope=t1' "$D/p1.out" && grep -q '90,85,95' "$D/p1.out"; then
    ok '正例 P1 3 连高 → PROMOTE 候选行含 scope 与分数序列'
  else
    bad '正例 P1 3 连高 → PROMOTE 候选行含 scope 与分数序列' "exit=$rc $(head -c 150 "$D/p1.out")"
  fi

  # 正例 P2：2 连低 → FORBID 候选行
  at_build_fixture "$D/p2"
  printf '{"date": "2026-10-10", "kind": "lesson", "scope": "t2", "decision": "a", "evidence_ref": "x", "promoted_to": "none", "score_contract": 30, "score_predicate": 50, "score_rework": 3}\n{"date": "2026-10-10", "kind": "lesson", "scope": "t2", "decision": "b", "evidence_ref": "x", "promoted_to": "none", "score_contract": 20, "score_predicate": 50, "score_rework": 2}\n' > "$D/p2/repo/facts/project/changes.jsonl"
  at_run "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'FORBID 候选: scope=t2' "$D/p2.out" && grep -q '30,20' "$D/p2.out"; then
    ok '正例 P2 2 连低 → FORBID 候选行含 scope 与分数序列'
  else
    bad '正例 P2 2 连低 → FORBID 候选行含 scope 与分数序列' "exit=$rc $(head -c 150 "$D/p2.out")"
  fi

  # 正例 P3：混合序列（高低高）→ 零提示零 NOTE
  at_build_fixture "$D/p3"
  printf '{"date": "2026-10-10", "kind": "lesson", "scope": "t3", "decision": "a", "evidence_ref": "x", "promoted_to": "none", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n{"date": "2026-10-10", "kind": "lesson", "scope": "t3", "decision": "b", "evidence_ref": "x", "promoted_to": "none", "score_contract": 50, "score_predicate": 100, "score_rework": 1}\n{"date": "2026-10-10", "kind": "lesson", "scope": "t3", "decision": "c", "evidence_ref": "x", "promoted_to": "none", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n' > "$D/p3/repo/facts/project/changes.jsonl"
  at_run "$D/p3" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/p3.out" ]; then
    ok '正例 P3 混合序列 → 零提示零 NOTE（不触发）'
  else
    bad '正例 P3 混合序列 → 零提示零 NOTE（不触发）' "exit=$rc $(head -c 150 "$D/p3.out")"
  fi

  # 正例 P4：数据不足（1 条）→ NOTE
  at_build_fixture "$D/p4"
  printf '{"date": "2026-10-10", "kind": "lesson", "scope": "t4", "decision": "a", "evidence_ref": "x", "promoted_to": "none", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n' > "$D/p4/repo/facts/project/changes.jsonl"
  at_run "$D/p4" > "$D/p4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'NOTE: 带分数 lesson 行共 1 条' "$D/p4.out"; then
    ok '正例 P4 数据不足 → NOTE 行'
  else
    bad '正例 P4 数据不足 → NOTE 行' "exit=$rc $(head -c 150 "$D/p4.out")"
  fi

  # 正例 P5：空账本 → 零输出
  at_build_fixture "$D/p5"
  : > "$D/p5/repo/facts/project/changes.jsonl"
  at_run "$D/p5" > "$D/p5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/p5.out" ]; then
    ok '正例 P5 空账本 → 零输出'
  else
    bad '正例 P5 空账本 → 零输出' "exit=$rc $(head -c 150 "$D/p5.out")"
  fi

  suite_summary 'absorption'
}
