#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  if [ "${1:-}" = '--audit-recheck' ]; then
    TICKET_REPAIR_AUDIT_RECHECK=1 sh "$TESTS_DIR/test-runner.sh" --suite ticket-repair
    exit $?
  fi
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-repair "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用

# ============================================================
# suite: ticket-repair（ticket-run repair 四类纠偏动作与 contract-build 定位回归）
# 夹具：mktemp 临时仓（票本体＋索引＋README＋账本＋delivery.rules main-only＋
#       dispatch 三阶段合同），站经 ticket-run repair 自身的补建路径创建。
# 覆盖：
#   AC1 补站＋重建派生投影可重复执行；两次 repair 后 HEAD 不变、状态载体 cksum
#       不变、投影 cksum 不变、intent 不再追加。
#   AC2 缺 Review：有实现提交无收据 → pending-review（exit 0，零收据生成）；
#       索引 review_pass 无收据 → decision-required（exit 1）；无站 done 票且
#       主仓无收据 → decision-required（不判 converged）；无站＋main 直提仍
#       检出并 decision-required；输出永不出现 PASS/verdict/conformant。
#   AC3 main 直提：检测 1 件、给 cherry-pick 迁移建议、明确拒绝 rebase/amend/
#       force-push；main 与票分支 OID 前后不变，无 rebase 现场、无新提交。
#   AC4 票目录同时有 <NN>-<slug>.json 与 <id>.review-evidence.json 时，
#       contract-build review、ticket-run contract review、verify-dispatch review
#       均 exit 0 且渲染票本体；同 NN 两件真实本体仍 exit 非 0 并逐件指名；
#       commit 阶段不渲染合同（无 commit 临时件）。
#   AC5 镜像 cmp（仓侧镜像在场时断言零差异；复制落位语境 SKIP）。
#   --audit-recheck（TICKET_REPAIR_AUDIT_RECHECK=1）：带已提交审查收据的夹具
#       repair 前后各跑一次 ticket-audit analyze，两次均 conformant、十一谓词
#       PASS 行数与输出逐字一致、HEAD 不变。
# 所有夹具在 mktemp 目录内构建并 trap 清理，被测仓库只读零改动。
# ============================================================

trp_git_commit() {
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm "$2"
}

trp_build_fixture() {
  R=$1
  status=${2:-in_progress}
  mkdir -p "$R/rules/implementation/scripts" "$R/rules/implementation/references/schemas" \
    "$R/rules/implementation/references/prompts" "$R/facts/requirements/tickets" "$R/facts/project"
  for f in ticket-run.sh contract-build.sh check-dispatch-contract.sh worktree-add.sh dp-load-rules.sh \
    generate-progress.sh ticket-audit.sh common-helpers.sh json-validator.py record-store.sh \
    workspace-snapshot.sh evidence-gate.sh record-lock.sh ledger-row-families.sh run-record-cmds.sh dispatch-contract-modes.sh module-map-fingerprint.sh artifacts-fix.sh \
    audit-predicates.rules audit-p01-receipt-parseable.sh audit-p02-evidence-committed.sh audit-p03-base-sha-present.sh audit-p04-review-boundary-clean.sh audit-p05-diff-sha-bound.sh audit-p06-reviewer-identity-present.sh audit-p07-reviewer-identity-corroborated.sh audit-p08-reviewer-distinct-from-implementer.sh audit-p09-reviewed-at-valid.sh audit-p10-acceptance-results-present.sh audit-p11-policy-applicable.sh; do
    cp "$SCRIPT_DIR/$f" "$R/rules/implementation/scripts/$f"
  done
  test_copy_closure "$SCRIPT_DIR" "$R/rules/implementation/scripts" generate-progress.sh json-validator.py
  cp "$PKG_ROOT/references/schemas/dispatch-contract.schema.json" "$R/rules/implementation/references/schemas/"
  for f in implementation-prompt.md review-prompt.md commit-prompt.md; do
    cp "$PKG_ROOT/references/prompts/$f" "$R/rules/implementation/references/prompts/"
  done
  cat > "$R/delivery.rules" <<'EOF'
# ==== main-only：worktree 排除清单（worktree-add.sh 读）====

dp_mainonly agent-up/scripts/export-payload.sh
EOF
  printf 'implemented\n' > "$R/product.txt"
  cat > "$R/facts/requirements/tickets/index.json" <<EOF
{
  "issues": [
    {"id": "90-repair-fixture", "status": "${status}", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-28T10:00"}
  ]
}
EOF
  cat > "$R/facts/requirements/tickets/README.md" <<EOF
| \`90-repair-fixture.json\` | 任务票 90；\`${status}\` | fixture |
EOF
  printf '%s\n' '{"date":"2026-10-28","kind":"change","scope":"90","decision":"fixture seed","evidence_ref":"facts/requirements/tickets/90-repair-fixture.json"}' > "$R/facts/project/changes.jsonl"
  python3 - "$R" <<'PY'
import json, sys
root = sys.argv[1]
impl_keys = ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']
review_keys = ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']
commit_keys = ['REVIEW_PASS_CHECKPOINT', 'FILE_WHITELIST', 'COMMIT_MESSAGE', 'RECORD_FLIP_AUTHORIZATION', 'SCOPE_CHECK_COMMAND', 'TICKET_ID']
ticket = {
    'id': '90-repair-fixture', 'kind': 'task', 'title': 'ticket-repair fixture', 'created_at': '2026-10-28',
    'blocked_by': [],
    'actual_time': '1h（fixture 净工时占位）',
    'dispatch': {
        'implementation': {key: 'fixture implementation ' + key for key in impl_keys},
        'review': {key: 'fixture review ' + key for key in review_keys},
        'commit': {key: 'fixture commit ' + key for key in commit_keys},
    },
}
ticket['dispatch']['implementation']['TICKET_ID'] = '90-repair-fixture'
ticket['dispatch']['review']['TICKET_ID'] = '90-repair-fixture'
ticket['dispatch']['commit']['TICKET_ID'] = '90-repair-fixture'
with open(root + '/facts/requirements/tickets/90-repair-fixture.json', 'w', encoding='utf-8') as handle:
    json.dump(ticket, handle, ensure_ascii=False, indent=2)
    handle.write('\n')
PY
  git_repo "$R"
  trp_git_commit "$R" init
  sh "$R/rules/implementation/scripts/generate-progress.sh" "$R" >/dev/null 2>&1 || return 1
}

trp_run() {
  _r=$1
  shift
  (cd "$_r" && TMPDIR="$D/tmp" sh "$_r/rules/implementation/scripts/ticket-run.sh" "$@")
}

trp_set_status() {
  python3 - "$1/facts/requirements/tickets/index.json" "$2" <<'PY'
import re, sys
path, status = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as handle:
    lines = handle.readlines()
out = []
for line in lines:
    if '"90-repair-fixture"' in line:
        line = re.sub(r'"status": "[^"]*"', '"status": "%s"' % status, line, count=1)
    out.append(line)
with open(path, 'w', encoding='utf-8') as handle:
    handle.writelines(out)
PY
}

trp_carrier_sum() {
  for _c in facts/requirements/tickets/index.json facts/requirements/tickets/README.md \
    facts/project/changes.jsonl facts/requirements/tickets/90-repair-fixture.json; do
    if [ -f "$1/$_c" ]; then
      printf '%s ' "$_c"
      cksum < "$1/$_c"
    else
      printf '%s ABSENT\n' "$_c"
    fi
  done
}

trp_audit_receipt() {
  # $1=站根 $2=base $3=head：审查收据经 receipt 落位
  receipt "$1/facts/requirements/tickets/90-repair-fixture.review-evidence.json" "$1" "$2" "$3" 90-repair-fixture
}

trp_audit_run() {
  # $1=夹具主仓 $2=站根；打印审计输出到 $3
  (cd "$1" && sh "$1/rules/implementation/scripts/ticket-audit.sh" 90 --repo "$2" --operation analyze) > "$3" 2>&1
}

suite_ticket_repair() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='ticket-repair'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/trepair
  mkdir -p "$D/tmp"

  # ================= AC1 / AC2：补站＋投影幂等、缺 Review 两分支 =================
  MAIN=$D/main
  trp_build_fixture "$MAIN" in_progress
  WT=$(realpath "$D")/main-wt/wt90
  rm -f "$MAIN/facts/requirements/tickets/progress-current.md"

  carriers_before=$(trp_carrier_sum "$MAIN")
  head_before=$(git -C "$MAIN" rev-parse HEAD)

  trp_run "$MAIN" 90 repair "$MAIN" > "$D/r1.out" 2> "$D/r1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: repair: 站: rebuilt$' "$D/r1.out" \
    && grep -q '^ticket-run: repair: 派生投影: rebuilt$' "$D/r1.out" \
    && grep -q '^ticket-run: repair: 结果: repaired$' "$D/r1.out" \
    && [ -d "$WT" ] \
    && [ "$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)" = 'ticket/90-repair-fixture' ] \
    && sh "$MAIN/rules/implementation/scripts/generate-progress.sh" --check "$MAIN" >/dev/null 2>&1; then
    ok 'AC1a 缺站＋投影缺失：repair 补建站并重建投影（repaired，站分支正确、投影 --check 一致）'
  else
    bad 'AC1a 缺站＋投影缺失：repair 补建站并重建投影（repaired，站分支正确、投影 --check 一致）' \
      "exit=$rc $(tail -n 4 "$D/r1.err" | tr '\n' '|')"
  fi

  carriers_after=$(trp_carrier_sum "$MAIN")
  progress_sum=$(cksum < "$MAIN/facts/requirements/tickets/progress-current.md")
  intent_lines=$(wc -l < "$MAIN/.git/ticket-run/90.intent" | tr -d ' ')
  head_after=$(git -C "$MAIN" rev-parse HEAD)

  trp_run "$MAIN" 90 repair "$MAIN" > "$D/r2.out" 2> "$D/r2.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: repair: 站: ok$' "$D/r2.out" \
    && grep -q '^ticket-run: repair: 派生投影: ok$' "$D/r2.out" \
    && grep -q '^ticket-run: repair: 结果: converged$' "$D/r2.out" \
    && [ "$(git -C "$MAIN" rev-parse HEAD)" = "$head_before" ] \
    && [ "$head_after" = "$head_before" ] \
    && [ "$(trp_carrier_sum "$MAIN")" = "$carriers_before" ] \
    && [ "$(trp_carrier_sum "$MAIN")" = "$carriers_after" ] \
    && [ "$(cksum < "$MAIN/facts/requirements/tickets/progress-current.md")" = "$progress_sum" ] \
    && [ "$(wc -l < "$MAIN/.git/ticket-run/90.intent" | tr -d ' ')" -eq "$intent_lines" ]; then
    ok 'AC1b 第二次 repair 收敛：零新提交、四状态载体 cksum 不变、投影不变、intent 不追加'
  else
    bad 'AC1b 第二次 repair 收敛：零新提交、四状态载体 cksum 不变、投影不变、intent 不追加' \
      "exit=$rc head=$(git -C "$MAIN" rev-parse --short HEAD) $(tail -n 3 "$D/r2.err" | tr '\n' '|')"
  fi

  printf 'implemented v2\n' >> "$WT/product.txt"
  trp_git_commit "$WT" 'product implementation'
  impl_head=$(git -C "$WT" rev-parse HEAD)
  carriers_pre_review=$(trp_carrier_sum "$MAIN")

  trp_run "$MAIN" 90 repair "$MAIN" > "$D/r3.out" 2> "$D/r3.err"
  rc=$?
  if require_out 'suite-ticket-repair 目标输出在场' "$D/r3.out" \
    && [ "$rc" -eq 0 ] && grep -q '^ticket-run: repair: Review: missing$' "$D/r3.out" \
    && grep -q '^ticket-run: repair: 结果: pending-review$' "$D/r3.out" \
    && grep -q 'contract review' "$D/r3.out" \
    && [ ! -e "$WT/facts/requirements/tickets/90-repair-fixture.review-evidence.json" ] \
    && [ "$(git -C "$WT" rev-parse HEAD)" = "$impl_head" ] \
    && [ "$(trp_carrier_sum "$MAIN")" = "$carriers_pre_review" ] \
    && ! grep -Eq 'PASS|verdict|conformant' "$D/r3.out"; then
    ok 'AC2a 有实现提交无 Review：repair → pending-review（exit 0，零收据生成，索引/README/账本/票本体不变）'
  else
    bad 'AC2a 有实现提交无 Review：repair → pending-review（exit 0，零收据生成，索引/README/账本/票本体不变）' \
      "exit=$rc $(tail -n 3 "$D/r3.err" | tr '\n' '|')"
  fi

  trp_set_status "$MAIN" review_pass
  trp_run "$MAIN" 90 repair "$MAIN" > "$D/r4.out" 2> "$D/r4.err"
  rc=$?
  if require_out 'suite-ticket-repair 目标输出在场' "$D/r4.out" \
    && [ "$rc" -eq 1 ] && grep -q '^ticket-run: repair: 结果: decision-required$' "$D/r4.out" \
    && grep -Eq 'review[-_]pass' "$D/r4.out" \
    && grep -q '90-repair-fixture.review-evidence.json' "$D/r4.out" \
    && [ ! -e "$WT/facts/requirements/tickets/90-repair-fixture.review-evidence.json" ] \
    && ! grep -Eq 'PASS|verdict|conformant' "$D/r4.out"; then
    ok 'AC2b 索引 review_pass 但无收据：repair → decision-required（exit 1，不伪造结论、不补收据）'
  else
    bad 'AC2b 索引 review_pass 但无收据：repair → decision-required（exit 1，不伪造结论、不补收据）' \
      "exit=$rc out=$(head -n 8 "$D/r4.out" | tr '\n' '|') err=$(tail -n 3 "$D/r4.err" | tr '\n' '|')"
  fi

  # AC2c：无站 done 票＋主仓无收据 → decision-required，绝不 converged
  NS=$D/no-station
  trp_build_fixture "$NS" 'done'
  NSW=$(realpath "$D")/no-station-wt/wt90
  trp_run "$NS" 90 repair "$NS" > "$D/r5.out" 2> "$D/r5.err"
  rc=$?
  if require_out 'suite-ticket-repair 目标输出在场' "$D/r5.out" \
    && [ "$rc" -eq 1 ] \
    && grep -q '^ticket-run: repair: Review: blocked$' "$D/r5.out" \
    && grep -q '^ticket-run: repair: main 直提: 0 件$' "$D/r5.out" \
    && grep -q '^ticket-run: repair: 结果: decision-required$' "$D/r5.out" \
    && ! grep -q '结果: converged' "$D/r5.out" \
    && [ ! -e "$NSW" ] \
    && [ ! -e "$NS/facts/requirements/tickets/90-repair-fixture.review-evidence.json" ]; then
    ok 'AC2c 无站 done 票＋主仓无收据：repair → decision-required（Review blocked，不判 converged，不建站不补收据）'
  else
    bad 'AC2c 无站 done 票＋主仓无收据：repair → decision-required（Review blocked，不判 converged，不建站不补收据）' \
      "exit=$rc out=$(head -n 9 "$D/r5.out" | tr '\n' '|') err=$(tail -n 3 "$D/r5.err" | tr '\n' '|')"
  fi

  # AC2d：无站＋main 直提 → 仍须检出并 decision-required（不依赖站或工作树）
  NSD=$D/no-station-direct
  trp_build_fixture "$NSD" 'done'
  git -C "$NSD" branch ticket/90-repair-fixture
  printf 'direct main product\n' >> "$NSD/product.txt"
  trp_git_commit "$NSD" 'direct main product commit'
  nsd_main=$(git -C "$NSD" rev-parse refs/heads/main)
  trp_run "$NSD" 90 repair "$NSD" > "$D/r6.out" 2> "$D/r6.err"
  rc=$?
  if require_out 'suite-ticket-repair 目标输出在场' "$D/r6.out" \
    && [ "$rc" -eq 1 ] \
    && grep -q '^ticket-run: repair: main 直提: 1 件' "$D/r6.out" \
    && grep -q '^ticket-run: repair: 迁移建议: .*cherry-pick' "$D/r6.out" \
    && grep -q '拒绝执行 rebase/amend/force-push' "$D/r6.out" \
    && grep -q '^ticket-run: repair: 结果: decision-required$' "$D/r6.out" \
    && ! grep -q '结果: converged' "$D/r6.out" \
    && [ "$(git -C "$NSD" rev-parse refs/heads/main)" = "$nsd_main" ] \
    && [ ! -e "$(realpath "$D")/no-station-direct-wt/wt90" ]; then
    ok 'AC2d 无站＋main 直提：repair 检出 1 件并给迁移建议 → decision-required（main OID 不变、不建站）'
  else
    bad 'AC2d 无站＋main 直提：repair 检出 1 件并给迁移建议 → decision-required（main OID 不变、不建站）' \
      "exit=$rc out=$(head -n 10 "$D/r6.out" | tr '\n' '|') err=$(tail -n 3 "$D/r6.err" | tr '\n' '|')"
  fi
  # ================= AC3：main 直提检测＋拒绝历史改写 =================
  MD=$D/main-direct
  trp_build_fixture "$MD" in_progress
  trp_run "$MD" 90 repair "$MD" > "$D/m0.out" 2> "$D/m0.err" || true
  MDWT=$(realpath "$D")/main-direct-wt/wt90
  printf 'direct to main\n' >> "$MD/product.txt"
  git -C "$MD" add product.txt
  git -C "$MD" -c user.email=fixture@example.com -c user.name=fixture commit -qm 'direct main product commit'
  main_head_before=$(git -C "$MD" rev-parse refs/heads/main)
  branch_head_before=$(git -C "$MD" rev-parse refs/heads/ticket/90-repair-fixture)

  trp_run "$MD" 90 repair "$MD" > "$D/m1.out" 2> "$D/m1.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^ticket-run: repair: main 直提: 1 件' "$D/m1.out" \
    && grep -q '^ticket-run: repair: 迁移建议: .*cherry-pick' "$D/m1.out" \
    && grep -q '拒绝执行 rebase/amend/force-push' "$D/m1.out" \
    && grep -q '^ticket-run: repair: 结果: decision-required$' "$D/m1.out" \
    && [ "$(git -C "$MD" rev-parse refs/heads/main)" = "$main_head_before" ] \
    && [ "$(git -C "$MD" rev-parse refs/heads/ticket/90-repair-fixture)" = "$branch_head_before" ] \
    && [ ! -e "$MD/.git/rebase-merge" ] && [ ! -e "$MD/.git/rebase-apply" ]; then
    ok 'AC3 main 直提：repair 检出 1 件并给 cherry-pick 建议，明确拒绝历史改写（main/票分支 OID 不变、无 rebase 现场）'
  else
    bad 'AC3 main 直提：repair 检出 1 件并给 cherry-pick 建议，明确拒绝历史改写（main/票分支 OID 不变、无 rebase 现场）' \
      "exit=$rc $(tail -n 4 "$D/m1.err" | tr '\n' '|')"
  fi
  if [ "$(git -C "$MDWT" rev-list --count HEAD)" -eq 1 ]; then
    ok 'AC3b 迁移建议只打印不执行：票分支未新增 cherry-pick 提交'
  else
    bad 'AC3b 迁移建议只打印不执行：票分支未新增 cherry-pick 提交' \
      "票分支提交数 $(git -C "$MDWT" rev-list --count HEAD)"
  fi

  # ================= AC4：收据在场时定位票本体；同 NN 两本体仍 fail-closed =================
  LD=$D/locator
  trp_build_fixture "$LD" in_progress
  trp_run "$LD" 90 repair "$LD" > "$D/l0.out" 2> "$D/l0.err" || true
  printf '{"note":"derived review receipt placeholder"}\n' \
    > "$LD/facts/requirements/tickets/90-repair-fixture.review-evidence.json"

  sh "$LD/rules/implementation/scripts/contract-build.sh" review 90 "$LD" > "$D/l1.out" 2> "$D/l1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^{{TICKET_ID}}$' "$D/l1.out" \
    && grep -qx '90-repair-fixture' "$D/l1.out" \
    && [ "$(grep -c '^{{[A-Z_]*}}$' "$D/l1.out")" -eq 6 ]; then
    ok 'AC4a 收据在场时 contract-build review 仍定位票本体（exit 0、6 字段块、TICKET_ID=票本体）'
  else
    bad 'AC4a 收据在场时 contract-build review 仍定位票本体（exit 0、6 字段块、TICKET_ID=票本体）' \
      "exit=$rc $(head -n 2 "$D/l1.err" | tr '\n' '|')"
  fi

  trp_run "$LD" 90 contract review "$LD" > "$D/l2.out" 2> "$D/l2.err"
  rc=$?
  l2_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/l2.out")
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/l2.out" | tr -d ' ')" -eq 2 ] \
    && [ -f "$l2_contract" ] && grep -qx '90-repair-fixture' "$l2_contract"; then
    ok 'AC4b 收据在场时 ticket-run contract review exit 0 且渲染对象是票本体'
  else
    bad 'AC4b 收据在场时 ticket-run contract review exit 0 且渲染对象是票本体' \
      "exit=$rc $(tail -n 2 "$D/l2.err" | tr '\n' '|')"
  fi

  trp_run "$LD" 90 verify-dispatch review "$LD" > "$D/l3.out" 2> "$D/l3.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: verify-dispatch: PASS review' "$D/l3.out"; then
    ok 'AC4c 收据在场时 ticket-run verify-dispatch review exit 0（重渲染与票面一致）'
  else
    bad 'AC4c 收据在场时 ticket-run verify-dispatch review exit 0（重渲染与票面一致）' \
      "exit=$rc $(tail -n 3 "$D/l3.err" | tr '\n' '|')"
  fi

  printf '{"id":"90-other-body","kind":"task","title":"same NN second body"}\n' \
    > "$LD/facts/requirements/tickets/90-other-body.json"
  sh "$LD/rules/implementation/scripts/contract-build.sh" review 90 "$LD" > "$D/l4.out" 2> "$D/l4.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/l4.out" ] && grep -q '2 件票本体' "$D/l4.err" \
    && grep -q '90-repair-fixture.json' "$D/l4.err" && grep -q '90-other-body.json' "$D/l4.err"; then
    ok 'AC4d 同 NN 两件真实票本体：contract-build fail-closed（exit 1、零 stdout、逐件指名）'
  else
    bad 'AC4d 同 NN 两件真实票本体：contract-build fail-closed（exit 1、零 stdout、逐件指名）' \
      "exit=$rc $(head -n 2 "$D/l4.err" | tr '\n' '|')"
  fi

  trp_run "$LD" 90 contract review "$LD" > "$D/l5.out" 2> "$D/l5.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/l5.out" ] && grep -q '2 件票本体' "$D/l5.err" \
    && grep -q '90-repair-fixture.json' "$D/l5.err" && grep -q '90-other-body.json' "$D/l5.err"; then
    ok 'AC4e 同 NN 两件真实票本体：ticket-run contract review fail-closed（exit 1、零 stdout、逐件指名）'
  else
    bad 'AC4e 同 NN 两件真实票本体：ticket-run contract review fail-closed（exit 1、零 stdout、逐件指名）' \
      "exit=$rc $(head -n 3 "$D/l5.err" | tr '\n' '|')"
  fi
  rm -f "$LD/facts/requirements/tickets/90-other-body.json"

  trp_run "$LD" 90 commit "$LD" > "$D/l6.out" 2> "$D/l6.err"
  rc=$?
  commit_tmp=$(find "$D/tmp" -maxdepth 1 -name 'ticket-run-90-commit.*' | wc -l | tr -d ' ')
  if [ "$rc" -eq 1 ] && grep -q 'Review pass 文件不存在' "$D/l6.err" \
    && [ "$commit_tmp" -eq 0 ] && [ ! -s "$D/l6.out" ]; then
    ok 'AC5b commit 阶段行为不变：不渲染合同（无 commit 临时件）、缺 Review pass 即零提交 fail-closed'
  else
    bad 'AC5b commit 阶段行为不变：不渲染合同（无 commit 临时件）、缺 Review pass 即零提交 fail-closed' \
      "exit=$rc tmp=$commit_tmp $(tail -n 2 "$D/l6.err" | tr '\n' '|')"
  fi

  # ================= AC5a：镜像 cmp（复制落位语境 SKIP） =================
  mirror="$PKG_ROOT/../rules/implementation/scripts/contract-build.sh"
  if [ -f "$mirror" ]; then
    if cmp -s "$SCRIPT_DIR/contract-build.sh" "$mirror"; then
      ok 'AC5a 包侧 contract-build.sh 与仓侧镜像 cmp 零差异'
    else
      bad 'AC5a 包侧 contract-build.sh 与仓侧镜像 cmp 零差异' '镜像漂移'
    fi
  else
    printf 'SKIP  [%s] AC5a 仓侧镜像不在场（复制落位语境），由合同 cmp 命令覆盖\n' "$CUR_SUITE"
  fi

  # ================= AC5c：ticket-run 镜像 cmp（复制落位语境 SKIP） =================
  mirror_tr="$PKG_ROOT/../rules/implementation/scripts/ticket-run.sh"
  if [ -f "$mirror_tr" ]; then
    if cmp -s "$SCRIPT_DIR/ticket-run.sh" "$mirror_tr"; then
      ok 'AC5c 包侧 ticket-run.sh 与仓侧镜像 cmp 零差异'
    else
      bad 'AC5c 包侧 ticket-run.sh 与仓侧镜像 cmp 零差异' '镜像漂移'
    fi
  else
    printf 'SKIP  [%s] AC5c 仓侧镜像不在场（复制落位语境），由合同 cmp 命令覆盖\n' "$CUR_SUITE"
  fi

  # ================= --audit-recheck：repair 前后审计逐谓词一致 =================
  if [ "${TICKET_REPAIR_AUDIT_RECHECK:-0}" -eq 1 ]; then
    AD=$D/audit
    trp_build_fixture "$AD" in_progress
    ADWT=$(realpath "$D")/audit-wt/wt90
    ad_base=$(git -C "$AD" rev-parse HEAD)
    trp_run "$AD" 90 repair "$AD" > "$D/a0.out" 2> "$D/a0.err" || true
    printf '{"schema_version":1,"policy_id":"repair-fixture","effective_from":"2026-01-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["fixture@example.com"]}\n' \
      "$ad_base" > "$ADWT/facts/requirements/audit-policy.json"
    git -C "$ADWT" add facts/requirements/audit-policy.json
    git -C "$ADWT" -c user.email=reviewer@example.com -c user.name=reviewer commit -qm 'audit policy'
    printf 'implemented v2\n' >> "$ADWT/product.txt"
    trp_git_commit "$ADWT" 'product implementation'
    ad_head=$(git -C "$ADWT" rev-parse HEAD)
    trp_audit_receipt "$ADWT" "$ad_base" "$ad_head"
    git -C "$ADWT" add facts/requirements/tickets/90-repair-fixture.review-evidence.json
    git -C "$ADWT" -c user.email=reviewer@example.com -c user.name=reviewer commit -qm 'review evidence'
    ad_evidence_head=$(git -C "$ADWT" rev-parse HEAD)

    trp_audit_run "$AD" "$ADWT" "$D/a1.out"
    rc_before=$?
    trp_run "$AD" 90 repair "$AD" > "$D/a2.out" 2> "$D/a2.err"
    rc_repair=$?
    trp_audit_run "$AD" "$ADWT" "$D/a3.out"
    rc_after=$?
    if [ "$rc_before" -eq 0 ] && [ "$rc_repair" -eq 0 ] && [ "$rc_after" -eq 0 ] \
      && [ "$(grep -c '^PASS ' "$D/a1.out")" -eq 11 ] \
      && [ "$(grep -c '^PASS ' "$D/a3.out")" -eq 11 ] \
      && cmp -s "$D/a1.out" "$D/a3.out" \
      && [ "$(git -C "$ADWT" rev-parse HEAD)" = "$ad_evidence_head" ] \
      && grep -q '^ticket-run: repair: 结果: converged$' "$D/a2.out"; then
      ok 'Audit 复跑：repair 前后 ticket-audit analyze 均 exit 0、十一谓词 PASS、逐字一致、HEAD 不变'
    else
      bad 'Audit 复跑：repair 前后 ticket-audit analyze 均 exit 0、十一谓词 PASS、逐字一致、HEAD 不变' \
        "audit=$rc_before/$rc_after repair=$rc_repair pass=$(grep -c '^PASS ' "$D/a3.out") $(tail -n 3 "$D/a3.out" | tr '\n' '|')"
    fi
  fi

  suite_summary 'ticket-repair'
}
