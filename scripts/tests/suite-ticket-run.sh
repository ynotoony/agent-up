#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-run "$@"
  exit $?
fi
# shellcheck disable=SC2034  # 计数器由 sourced 的 test-helpers.sh 使用

# suite: ticket-run——三阶段真实夹具、Review 结论位 fail-closed（含证据行不得翻案）、
#        两段提交与编排器原子层边界。

tr_git_commit() {
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm "$2"
}

tr_build_fixture() {
  R=$1
  mkdir -p "$R/rules/implementation/scripts" "$R/rules/implementation/references/schemas" \
    "$R/rules/implementation/references/prompts" "$R/facts/requirements/tickets" "$R/facts/project"
  for f in ticket-run.sh contract-build.sh check-dispatch-contract.sh worktree-add.sh dp-load-rules.sh \
    check-gates.sh ticket-ops.sh generate-progress.sh ledger-append.sh common-helpers.sh json-validator.py; do
    cp "$SCRIPT_DIR/$f" "$R/rules/implementation/scripts/$f"
  done
  cp "$PKG_ROOT/references/schemas/dispatch-contract.schema.json" "$R/rules/implementation/references/schemas/"
  for f in implementation-prompt.md review-prompt.md commit-prompt.md; do
    cp "$PKG_ROOT/references/prompts/$f" "$R/rules/implementation/references/prompts/"
  done
  cat > "$R/delivery.rules" <<'EOF'
# ==== main-only：worktree 排除清单（worktree-add.sh 读）====

dp_mainonly agent-up/scripts/export-payload.sh
EOF
  printf 'seed\n' > "$R/product.txt"
  cat > "$R/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "90-run-fixture", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-28T10:00"}
  ]
}
EOF
  cat > "$R/facts/requirements/tickets/README.md" <<'EOF'
| `90-run-fixture.json` | 任务票 90；`in_progress` | fixture |
EOF
  printf '%s\n' '{"date":"2026-10-28","kind":"change","scope":"90","decision":"fixture seed","evidence_ref":"facts/requirements/tickets/90-run-fixture.json"}' > "$R/facts/project/changes.jsonl"
  python3 - "$R" <<'PY'
import json, sys
root = sys.argv[1]
impl_keys = ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']
review_keys = ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']
ticket = {
    'id': '90-run-fixture', 'kind': 'task', 'title': 'ticket-run fixture', 'created_at': '2026-10-28',
    'dispatch': {
        'implementation': {key: 'fixture implementation ' + key for key in impl_keys},
        'review': {key: 'fixture review ' + key for key in review_keys},
        'commit': {
            'REVIEW_PASS_CHECKPOINT': 'facts/requirements/tickets/90-run-fixture-review-checkpoint.md',
            'FILE_WHITELIST': 'product.txt,facts/requirements/tickets/90-run-fixture-review-checkpoint.md',
            'COMMIT_MESSAGE': 'test: ticket-run fixture',
            'RECORD_FLIP_AUTHORIZATION': 'flips: facts/requirements/tickets/index.json:index:90-run-fixture:done:2026-10-28T12:00',
            'SCOPE_CHECK_COMMAND': 'test -f product.txt',
            'TICKET_ID': '90-run-fixture',
        },
    },
}
ticket['dispatch']['implementation']['TICKET_ID'] = '90-run-fixture'
ticket['dispatch']['review']['TICKET_ID'] = '90-run-fixture'
with open(root + '/facts/requirements/tickets/90-run-fixture.json', 'w', encoding='utf-8') as handle:
    json.dump(ticket, handle, ensure_ascii=False, indent=2)
    handle.write('\n')
PY
  git -C "$R" init -q
  tr_git_commit "$R" init
}

tr_run() {
  (cd "$MAIN" && TMPDIR="$D/tmp" sh "$MAIN/rules/implementation/scripts/ticket-run.sh" "$@")
}

suite_ticket_run() {
  # shellcheck disable=SC2034
  CUR_SUITE='ticket-run'
  # shellcheck disable=SC2034
  SUITE_FAILS=0
  # shellcheck disable=SC2034
  SUITE_START=$TOTAL
  D=$T/trun
  MAIN=$D/main
  mkdir -p "$D/tmp"
  tr_build_fixture "$MAIN"
  WT=$(realpath "$D")/main-wt/wt90

  tr_run 90 implementation "$MAIN" > "$D/impl.out" 2> "$D/impl.err"
  rc=$?
  impl_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/impl.out")
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/impl.out" | tr -d ' ')" -eq 2 ] \
    && grep -q "^ticket-run: 站路径: ${WT}$" "$D/impl.out" \
    && [ -d "$WT" ] && [ -f "$impl_contract" ] \
    && sh "$MAIN/rules/implementation/scripts/check-dispatch-contract.sh" --check "$impl_contract" >/dev/null 2>&1; then
    ok 'P1 implementation 建站并恰输出站路径＋合同文件，合同过自查'
  else
    bad 'P1 implementation 建站并恰输出站路径＋合同文件，合同过自查' "exit=$rc $(tail -n 3 "$D/impl.err" | tr '\n' '|')"
  fi

  tr_run 90 review "$MAIN" > "$D/review.out" 2> "$D/review.err"
  rc=$?
  review_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/review.out")
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/review.out" | tr -d ' ')" -eq 2 ] \
    && grep -q "^ticket-run: 站路径: ${WT}$" "$D/review.out" \
    && sh "$MAIN/rules/implementation/scripts/check-dispatch-contract.sh" --check "$review_contract" >/dev/null 2>&1; then
    ok 'P2 review 复用既有站并产出可派发合同'
  else
    bad 'P2 review 复用既有站并产出可派发合同' "exit=$rc $(tail -n 3 "$D/review.err" | tr '\n' '|')"
  fi

  printf 'implemented\n' > "$WT/product.txt"
  tr_run 90 commit "$MAIN" > "$D/commit-missing.out" 2> "$D/commit-missing.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q 'Review pass 文件不存在' "$D/commit-missing.err"; then
    ok 'N1 commit 缺 Review pass 文件 → 零提交 fail-closed'
  else
    bad 'N1 commit 缺 Review pass 文件 → 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-missing.err" | tr '\n' '|')"
  fi

  printf 'Verdict: **FAIL**\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-fail.out" 2> "$D/commit-fail.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q '最终 Review 结论不是 PASS' "$D/commit-fail.err"; then
    ok 'N2 commit 最终 Verdict=FAIL → 零提交 fail-closed'
  else
    bad 'N2 commit 最终 Verdict=FAIL → 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-fail.err" | tr '\n' '|')"
  fi

  printf 'fail\nPASS: AC1 全项通过\nPASS: 包检 PASS\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-firstfail.out" 2> "$D/commit-firstfail.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q '最终 Review 结论不是 PASS' "$D/commit-firstfail.err"; then
    ok 'N4 首行 fail＋后续 PASS 证据行 → 零提交 fail-closed'
  else
    bad 'N4 首行 fail＋后续 PASS 证据行 → 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-firstfail.err" | tr '\n' '|')"
  fi

  printf 'Verdict: FAIL\nPASS: AC1 全项通过\npass\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-labelfail.out" 2> "$D/commit-labelfail.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q '最终 Review 结论不是 PASS' "$D/commit-labelfail.err"; then
    ok 'N5 Verdict: FAIL＋后续 PASS 证据行 → 零提交 fail-closed'
  else
    bad 'N5 Verdict: FAIL＋后续 PASS 证据行 → 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-labelfail.err" | tr '\n' '|')"
  fi

  printf '## Review 检查记录\n\n审查已完成，逐项证据见下。\nPASS: AC1 通过\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-noverdict.out" 2> "$D/commit-noverdict.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q 'Review 结论位无法确定' "$D/commit-noverdict.err"; then
    ok 'N6 结论位无明确结论（仅证据行）→ 零提交 fail-closed'
  else
    bad 'N6 结论位无明确结论（仅证据行）→ 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-noverdict.err" | tr '\n' '|')"
  fi

  printf 'PASS: AC1 全项通过\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-evidenceonly.out" 2> "$D/commit-evidenceonly.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 1 ] \
    && grep -q 'Review 结论位无法确定' "$D/commit-evidenceonly.err"; then
    ok 'N7 仅 PASS: 证据行（无标题无结论）→ 零提交 fail-closed'
  else
    bad 'N7 仅 PASS: 证据行（无标题无结论）→ 零提交 fail-closed' "exit=$rc $(tail -n 3 "$D/commit-evidenceonly.err" | tr '\n' '|')"
  fi

  printf 'Verdict: **PASS**\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit.out" 2> "$D/commit.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 3 ] \
    && grep -q '"id": "90-run-fixture", "status": "done"' "$WT/facts/requirements/tickets/index.json" \
    && grep -q '| 90-run-fixture | done |' "$WT/facts/requirements/tickets/progress-current.md" \
    && grep -q 'ticket-run: 产品提交:' "$D/commit.out" && grep -q 'ticket-run: 记录提交:' "$D/commit.out"; then
    ok 'P3 commit 经 Review pass＋check-gates 自动完成产品/记录两段提交与索引投影'
  else
    bad 'P3 commit 经 Review pass＋check-gates 自动完成产品/记录两段提交与索引投影' "exit=$rc $(tail -n 5 "$D/commit.err" | tr '\n' '|')"
  fi

  if [ "$(git -C "$WT" log -1 --format=%s HEAD~1)" = 'test: ticket-run fixture' ] \
    && [ "$(git -C "$WT" show --name-only --format= HEAD~1 | grep -c '90-run-fixture-review-checkpoint.md')" -eq 1 ] \
    && ! grep -q 'User Review Checkpoint' "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"; then
    ok 'P4 产品提交收编既有独立 Review 文件且不伪造 User Review Checkpoint'
  else
    bad 'P4 产品提交收编既有独立 Review 文件且不伪造 User Review Checkpoint' '提交面或 checkpoint 内容不符'
  fi

  commit_temp=$(find "$D/tmp" -maxdepth 1 -name 'ticket-run-90-commit.*' | wc -l | tr -d ' ')
  if [ "$commit_temp" -eq 0 ]; then
    ok 'P5 commit 阶段不渲染合同文件，临时目录无 commit 孤儿'
  else
    bad 'P5 commit 阶段不渲染合同文件，临时目录无 commit 孤儿' "commit 临时文件 ${commit_temp} 件"
  fi

  printf -- '- 评审结论：**pass**（2026-10-29，存量格式兼容夹具）\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-legacy.out" 2> "$D/commit-legacy.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 5 ] \
    && grep -q 'ticket-run: 产品提交:' "$D/commit-legacy.out"; then
    ok 'P6 存量格式「- 评审结论：**pass**（注记）」被采信并完成两段提交'
  else
    bad 'P6 存量格式「- 评审结论：**pass**（注记）」被采信并完成两段提交' "exit=$rc $(tail -n 3 "$D/commit-legacy.err" | tr '\n' '|')"
  fi

  tr_run 90 bogus "$MAIN" > "$D/bogus.out" 2> "$D/bogus.err"
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$D/bogus.out" ]; then
    ok 'N3 非法 stage → exit 2 零 stdout'
  else
    bad 'N3 非法 stage → exit 2 零 stdout' "exit=$rc"
  fi

  # shellcheck disable=SC2016  # grep 模式刻意匹配 shell 源码字面量，不能在测试层展开
  if ! grep -Eq '(^|[[:space:]])agent\(' "$SCRIPT_DIR/ticket-run.sh" \
    && ! grep -q 'workflow index-status' "$SCRIPT_DIR/workflow-executor.sh" \
    && ! grep -q 'get_current_status\|update_status' "$SCRIPT_DIR/workflow-executor.sh" \
    && grep -q 'sh "$_ds_ticket_ops" "$_ds_repo_root" flip-index' "$SCRIPT_DIR/workflow-executor.sh"; then
    ok 'AC2a ticket-run 不 spawn 子 agent；workflow-executor 无索引直写且改调 flip-index'
  else
    bad 'AC2a ticket-run 不 spawn 子 agent；workflow-executor 无索引直写且改调 flip-index' '静态边界不符'
  fi

  CHAIN="$PKG_ROOT/.."'/.zcode/workflows/ticket-chain.dwf.ts'
  if ! grep -q 'rows=\[x for x in d.get' "$CHAIN" \
    && grep -q '"rules/implementation/scripts/json-validator.py", "json", "pick"' "$CHAIN"; then
    ok 'AC2b ticket-chain 无内嵌索引解析，状态读取经唯一 JSON 引擎'
  else
    bad 'AC2b ticket-chain 无内嵌索引解析，状态读取经唯一 JSON 引擎' '静态边界不符'
  fi

  suite_summary 'ticket-run'
}
