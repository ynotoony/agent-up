#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-run "$@"
  exit $?
fi
# shellcheck disable=SC2034  # 计数器由 sourced 的 test-helpers.sh 使用

# suite: ticket-run——三阶段真实夹具、Review 结论位 fail-closed（含证据行不得翻案）、
#        两段提交与编排器原子层边界；可恢复协调器五子命令、intent 重跑收敛、残留
#        intent 的前置复核与 next 退出码（decision-required＝exit 1）；记录收口段单一锁窗口
#        （票 271：flip-index 继承标记＋checkpoint.commit 同锁同令牌＋段末释放）。

tr_git_commit() {
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm "$2"
}

tr_build_fixture() {
  R=$1
  status=${2:-in_progress}
  mkdir -p "$R/rules/implementation/scripts" "$R/rules/implementation/references/schemas" \
    "$R/rules/implementation/references/prompts" "$R/facts/requirements/tickets" "$R/facts/project"
  for f in ticket-run.sh contract-build.sh check-dispatch-contract.sh worktree-add.sh dp-load-rules.sh \
    check-gates.sh ticket-ops.sh generate-progress.sh generate-dir-readmes.sh dir-readme.rules ledger-append.sh record-store.sh common-helpers.sh json-validator.py ticket-audit.sh; do
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
  printf 'implemented\n' > "$R/product.txt"
  cat > "$R/facts/requirements/tickets/index.json" <<EOF
{
  "issues": [
    {"id": "90-run-fixture", "status": "${status}", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-28T10:00"}
  ]
}
EOF
  # 票表生成块形态（票 277 起 README 票表由索引派生）：take/flip 走「索引改→生成器重算」
  # 真实路径；块外标题与空行保持不动。
  cat > "$R/facts/requirements/tickets/README.md" <<EOF
# 票据索引（fixture）

## 目录清单

<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->
| 名字 | 地位 | 功能 |
| --- | --- | --- |
| \`90-run-fixture.json\` | 任务票 90；\`${status}\` | fixture |
<!-- /tickets-readme -->
EOF
  printf '%s\n' '{"date":"2026-10-28","kind":"change","scope":"90","decision":"fixture seed","evidence_ref":"facts/requirements/tickets/90-run-fixture.json"}' > "$R/facts/project/changes.jsonl"
  python3 - "$R" <<'PY'
import json, sys
root = sys.argv[1]
impl_keys = ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']
review_keys = ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']
ticket = {
    'id': '90-run-fixture', 'kind': 'task', 'title': 'ticket-run fixture', 'created_at': '2026-10-28',
    'blocked_by': [],
    'actual_time': '1h（fixture 净工时占位）',
    'dispatch': {
        'implementation': {key: 'fixture implementation ' + key for key in impl_keys},
        'review': {key: 'fixture review ' + key for key in review_keys},
        'commit': {
            'REVIEW_PASS_CHECKPOINT': 'facts/requirements/tickets/90-run-fixture-review-checkpoint.md',
            'FILE_WHITELIST': 'product.txt,facts/requirements/tickets/90-run-fixture-review-checkpoint.md,facts/requirements/tickets/90-run-fixture.review-evidence.json',
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
  git_repo "$R"
  tr_git_commit "$R" init
}

tr_audit_receipt() {
  # $1=仓库根（worktree）$2=base $3=head：审查收据经 receipt 落位（reviewer 身份）
  receipt "$1/facts/requirements/tickets/90-run-fixture.review-evidence.json" "$1" "$2" "$3" 90-run-fixture
}

tr_run() {
  run_in_fixture "$MAIN" env TMPDIR="$D/tmp" sh "$MAIN/rules/implementation/scripts/ticket-run.sh" "$@"
}

tr_carrier_rels='facts/requirements/tickets/index.json facts/requirements/tickets/README.md facts/project/changes.jsonl facts/requirements/tickets/progress-current.md'

tr_snapshot_carriers() {
  # $1=主检出根 $2=站根 $3=快照目录：主检出与站内各四载体一份（不在场记 .absent）
  _snap=$3
  mkdir -p "$_snap" || return 1
  _ci=0
  for _crel in $tr_carrier_rels; do
    _ci=$((_ci + 1))
    for _ctag in main wt; do
      if [ "$_ctag" = 'main' ]; then _croot=$1; else _croot=$2; fi
      if [ -f "$_croot/$_crel" ]; then
        cp "$_croot/$_crel" "$_snap/${_ci}-${_ctag}" || return 1
      else
        : > "$_snap/${_ci}-${_ctag}.absent" || return 1
      fi
    done
  done
}

tr_carriers_unchanged() {
  # $1=主检出根 $2=站根 $3=快照目录；逐载体 cmp，存在性亦须一致
  _snap=$3
  _ci=0
  for _crel in $tr_carrier_rels; do
    _ci=$((_ci + 1))
    for _ctag in main wt; do
      if [ "$_ctag" = 'main' ]; then _croot=$1; else _croot=$2; fi
      _cexp="$_snap/${_ci}-${_ctag}"
      if [ -f "$_cexp" ]; then
        if [ ! -f "$_croot/$_crel" ] || ! cmp -s "$_cexp" "$_croot/$_crel"; then
          printf '载体被改写: %s/%s\n' "$_ctag" "$_crel" >&2
          return 1
        fi
      elif [ -e "$_croot/$_crel" ]; then
        printf '载体被新建: %s/%s\n' "$_ctag" "$_crel" >&2
        return 1
      fi
    done
  done
}

tr_intent_state() {
  # $1=仓库根 $2=步骤；打印 intent 中该步骤最后一条状态
  awk -F "$(printf '\t')" -v step="$2" '$1 == step { state = $2 } END { print state }' \
    "$1/.git/ticket-run/90.intent" 2>/dev/null
}

suite_ticket_run() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='ticket-run'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
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
  tr_base=$(git -C "$WT" rev-parse HEAD)
  printf 'implemented v2\n' >> "$WT/product.txt"
  git -C "$WT" add product.txt
  git -C "$WT" -c user.email=fixture@example.com -c user.name=fixture commit -qm 'product implementation'
  tr_head=$(git -C "$WT" rev-parse HEAD)
  tr_excl=$(git -C "$WT" rev-parse --git-path info/exclude)
  case $tr_excl in /*) ;; *) tr_excl="$WT/$tr_excl" ;; esac
  mkdir -p "$(dirname "$tr_excl")"
  printf '%s\n' 'facts/requirements/audit-policy.json' >> "$tr_excl"
  printf '{"schema_version":1,"policy_id":"ticket-run-fixture","effective_from":"2026-01-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["fixture@example.com"]}\n' \
    "$tr_base" > "$WT/facts/requirements/audit-policy.json"
  tr_audit_receipt "$WT" "$tr_base" "$tr_head"
  git -C "$WT" config user.email reviewer@example.com
  git -C "$WT" config user.name reviewer
  # ---- 票 271 插桩：记录收口段单一锁窗口探针（不改产品行为，只观测）----
  # ticket-ops.sh 包装器记录 flip-index 收到的继承标记与父锁；python3 垫片在票本体
  # checkpoint.commit 的内联写入点记录当时锁目录与令牌仍归父进程（同锁同令牌）。
  ac3=$D/ac3
  mkdir -p "$ac3/bin" "$ac3/probe"
  cp "$MAIN/rules/implementation/scripts/ticket-ops.sh" "$MAIN/rules/implementation/scripts/ticket-ops-real.sh"
  cat > "$MAIN/rules/implementation/scripts/ticket-ops.sh" <<'WRAP'
#!/bin/sh
_p=${TR271_PROBE:-}
if [ -n "$_p" ]; then
  printf '%s\n' "${RECORD_LOCK_INHERITED:-0}" > "$_p/flip-inherited"
  printf '%s\n' "${RECORD_LOCK_DIR:-}" > "$_p/flip-lock-dir"
  printf '%s\n' "${RECORD_LOCK_TOKEN:-}" > "$_p/flip-token"
  if [ -n "${RECORD_LOCK_DIR:-}" ] && [ -d "${RECORD_LOCK_DIR}" ]; then printf 'held\n' > "$_p/flip-lock-held"; fi
  printf '%s\n' "$*" >> "$_p/flip-calls"
fi
exec sh "$(dirname "$0")/ticket-ops-real.sh" "$@"
WRAP
  ac3_real_py=$(command -v python3)
  cat > "$ac3/bin/python3" <<'PYS'
#!/bin/sh
if [ -n "${TR271_PROBE:-}" ] && [ "${1:-}" = '-' ]; then
  _p=$TR271_PROBE
  _want=$(sed -n '1p' "$_p/flip-token" 2>/dev/null) || _want=''
  _dir=$(sed -n '1p' "$_p/flip-lock-dir" 2>/dev/null) || _dir=''
  _live=$(sed -n '1p' "$_dir/token" 2>/dev/null) || _live=''
  if [ -n "$_dir" ] && [ -d "$_dir" ] && [ "$_live" = "$_want" ]; then
    printf 'held\n' > "$_p/commit-lock-held"
  else
    printf 'dir=%s live=%s want=%s\n' "$_dir" "$_live" "$_want" > "$_p/commit-lock-miss"
  fi
fi
exec "$TR271_REAL_PY" "$@"
PYS
  chmod +x "$ac3/bin/python3"
  ( cd "$MAIN" && TMPDIR="$D/tmp" TR271_PROBE="$ac3/probe" TR271_REAL_PY="$ac3_real_py" \
      PATH="$ac3/bin:$PATH" sh "$MAIN/rules/implementation/scripts/ticket-run.sh" 90 commit "$MAIN" ) \
    > "$D/commit.out" 2> "$D/commit.err"
  rc=$?
  cp "$MAIN/rules/implementation/scripts/ticket-ops-real.sh" "$MAIN/rules/implementation/scripts/ticket-ops.sh"
  rm -f "$MAIN/rules/implementation/scripts/ticket-ops-real.sh"
  if [ "$rc" -eq 0 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 4 ] \
    && grep -q '"id": "90-run-fixture", "status": "done"' "$WT/facts/requirements/tickets/index.json" \
    && grep -q '| 90-run-fixture | done |' "$WT/facts/requirements/tickets/progress-current.md" \
    && grep -q 'ticket-run: 产品提交:' "$D/commit.out" && grep -q 'ticket-run: 记录提交:' "$D/commit.out"; then
    ok 'P3 commit 经 Review pass＋check-gates 自动完成产品/记录两段提交与索引投影'
  else
    bad 'P3 commit 经 Review pass＋check-gates 自动完成产品/记录两段提交与索引投影' "exit=$rc $(tail -n 5 "$D/commit.err" | tr '\n' '|')"
  fi

  commit_cp_commit=$(python3 "$MAIN/rules/implementation/scripts/json-validator.py" json get \
    "$WT/facts/requirements/tickets/90-run-fixture.json" checkpoint.commit.commit 2>/dev/null || true)
  commit_cp_at=$(python3 "$MAIN/rules/implementation/scripts/json-validator.py" json get \
    "$WT/facts/requirements/tickets/90-run-fixture.json" checkpoint.commit.committed_at 2>/dev/null || true)
  product_head=$(git -C "$WT" rev-parse HEAD~1)
  if [ -n "$commit_cp_commit" ] && [ "$commit_cp_commit" = "$product_head" ] && [ -n "$commit_cp_at" ] \
    && git -C "$WT" show --name-only --format= HEAD | grep -qx 'facts/requirements/tickets/90-run-fixture.json'; then
    ok 'P3b commit 收尾在票本体写入 checkpoint.commit（键在位、非空、绑定产品提交并随记录提交入库）'
  else
    bad 'P3b commit 收尾在票本体写入 checkpoint.commit（键在位、非空、绑定产品提交并随记录提交入库）' \
      "commit=${commit_cp_commit:-<空>} committed_at=${commit_cp_at:-<空>} product=${product_head}"
  fi

  # ---- AC3（票 271）：记录收口段的 flip-index 与 checkpoint.commit 处于同一锁窗口 ----
  # 三证据：①flip-index 收到 RECORD_LOCK_INHERITED=1（不自行取锁）；②flip-index 执行时父锁
  # 已在场（锁目录存在）；③checkpoint.commit 内联写入时同一锁目录的令牌仍等于 flip 时令牌
  # （窗口未被拆成两段）；段末按所有权释放（锁目录不残留）。
  ac3_inherited=$(sed -n '1p' "$ac3/probe/flip-inherited" 2>/dev/null)
  ac3_lockdir=$(sed -n '1p' "$ac3/probe/flip-lock-dir" 2>/dev/null)
  ac3_probe_state="inherited=$ac3_inherited flip锁=$([ -f "$ac3/probe/flip-lock-held" ] && echo yes || echo no) commit锁=$([ -f "$ac3/probe/commit-lock-held" ] && echo yes || echo no)"
  if [ -f "$ac3/probe/flip-lock-dir" ] && [ -f "$ac3/probe/flip-token" ] \
    && [ "$ac3_inherited" = '1' ] \
    && [ -f "$ac3/probe/flip-lock-held" ] \
    && [ -f "$ac3/probe/commit-lock-held" ] && [ ! -f "$ac3/probe/commit-lock-miss" ] \
    && grep -q 'flip-index' "$ac3/probe/flip-calls" \
    && [ -n "$ac3_lockdir" ] && [ ! -d "$ac3_lockdir" ]; then
    ok 'AC3 ticket-run 记录收口段单一锁窗口：flip-index 以继承标记接管父锁、checkpoint.commit 同锁同令牌写入、段末释放'
  else
    bad 'AC3 ticket-run 记录收口段单一锁窗口：flip-index 以继承标记接管父锁、checkpoint.commit 同锁同令牌写入、段末释放' \
      "$ac3_probe_state 锁残留=$([ -n "$ac3_lockdir" ] && [ -d "$ac3_lockdir" ] && echo yes || echo no) miss=$(sed -n '1p' "$ac3/probe/commit-lock-miss" 2>/dev/null) calls=$(sed -n '1p' "$ac3/probe/flip-calls" 2>/dev/null)"
  fi

  if require_out 'suite-ticket-run 目标输出在场' "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md" \
    && [ "$(git -C "$WT" log -1 --format=%s HEAD~1)" = 'test: ticket-run fixture' ] \
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

  # 票表生成块随记录提交入库后，旧审查证据的 head..target 会包含记录面变更（README），
  # flip 至 done 的审计边界即不干净。按 P3 同法先造一条产品实现提交、把审查证据重绑到
  # 当前历史，再走存量结论格式的二次收口；断言不放宽（仍要求 exit 0、产品提交行与两段
  # 提交计数——比原来多出的 1 次提交即本条重绑用的人工实现提交）。
  printf 'legacy re-review\n' >> "$WT/product.txt"
  git -C "$WT" add product.txt
  git -C "$WT" -c user.email=fixture@example.com -c user.name=fixture commit -qm 'product implementation legacy redo'
  tr_p6_base=$(git -C "$WT" rev-parse HEAD~1)
  tr_p6_head=$(git -C "$WT" rev-parse HEAD)
  tr_audit_receipt "$WT" "$tr_p6_base" "$tr_p6_head"
  git -C "$WT" config user.email reviewer@example.com
  git -C "$WT" config user.name reviewer
  printf -- '- 评审结论：**pass**（2026-10-29，存量格式兼容夹具）\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  tr_run 90 commit "$MAIN" > "$D/commit-legacy.out" 2> "$D/commit-legacy.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(git -C "$WT" rev-list --count HEAD)" -eq 7 ] \
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

  # ---- 可恢复协调器（票 235）：五子命令、intent 重跑收敛、收据字段合同 ----
  tr_run_in() {
    # $1=夹具仓库根；其余参数透传 ticket-run.sh
    _r=$1
    shift
    run_in_fixture "$_r" env TMPDIR="$D/tmp" sh "$_r/rules/implementation/scripts/ticket-run.sh" "$@"
  }
  tr_receipt() {
    # $1=输出文件 $2=verdict $3=可选：删除键名／EXTRA／NOTES_NUMBER／AC_EXTRA／SCHEMA_STR
    python3 - "$1" "$2" "${3:-}" <<'PY'
import json, sys
out, verdict, mode = sys.argv[1], sys.argv[2], sys.argv[3]
receipt = {
    'schema_version': 1, 'receipt_kind': 'review', 'ticket_id': '90-run-fixture',
    'created_at': '2026-10-30T10:00:00Z', 'actor': 'review-agent',
    'base_sha': 'a' * 40, 'head_sha': 'b' * 40, 'diff_sha': 'c' * 40,
    'reviewer_identity': 'reviewer:fixture', 'reviewed_at': '2026-10-30T10:10:00Z',
    'verdict': verdict, 'acceptance': [{'ac_id': 'AC1', 'result': 'pass'}],
}
if mode == 'EXTRA':
    receipt['verdict'] = 'PASS'
    receipt['surprise'] = 'x'
elif mode == 'NOTES_NUMBER':
    receipt['notes'] = 123
elif mode == 'AC_EXTRA':
    receipt['acceptance'][0]['extra'] = 'x'
elif mode == 'SCHEMA_STR':
    receipt['schema_version'] = '1'
elif mode:
    receipt.pop(mode, None)
with open(out, 'w', encoding='utf-8') as handle:
    json.dump(receipt, handle, ensure_ascii=False, indent=2)
    handle.write('\n')
PY
  }

  CONV=$D/conv
  tr_build_fixture "$CONV" ready
  CWT=$(realpath "$D")/conv-wt/wt90

  tr_run_in "$CONV" 90 next > "$D/c-next1.out" 2> "$D/c-next1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: 下一步: start$' "$D/c-next1.out" \
    && [ -z "$(git -C "$CONV" status --porcelain)" ] && [ ! -e "$CONV/.git/ticket-run" ]; then
    ok 'C1 next 在 ready 票上只读推导 start（零写入、不落 intent）'
  else
    bad 'C1 next 在 ready 票上只读推导 start（零写入、不落 intent）' "exit=$rc $(tail -n 3 "$D/c-next1.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 start > "$D/c-start1.out" 2> "$D/c-start1.err"
  rc=$?
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if [ "$rc" -eq 0 ] && [ -d "$CWT" ] \
    && [ "$(git -C "$CWT" rev-parse --abbrev-ref HEAD 2>/dev/null)" = 'ticket/90-run-fixture' ] \
    && grep -q '"status": "in_progress"' "$CONV/facts/requirements/tickets/index.json" \
    && grep -q '`in_progress`' "$CONV/facts/requirements/tickets/README.md" \
    && [ "$(wc -l < "$CONV/facts/project/changes.jsonl" | tr -d ' ')" -eq 2 ]; then
    ok 'C2 start 建站＋领取：站分支正确、索引/README/账本一致（ready→in_progress）'
  else
    bad 'C2 start 建站＋领取：站分支正确、索引/README/账本一致（ready→in_progress）' "exit=$rc $(tail -n 3 "$D/c-start1.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 start > "$D/c-start2.out" 2> "$D/c-start2.err"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(wc -l < "$CONV/facts/project/changes.jsonl" | tr -d ' ')" -eq 2 ] \
    && [ "$(git -C "$CONV" worktree list | wc -l | tr -d ' ')" -eq 2 ] \
    && grep -q "^ticket-run: 站路径: ${CWT}$" "$D/c-start2.out"; then
    ok 'C3 start 重跑幂等：不重复落账本、不重建站，路径不变'
  else
    bad 'C3 start 重跑幂等：不重复落账本、不重建站，路径不变' "exit=$rc changes=$(wc -l < "$CONV/facts/project/changes.jsonl" | tr -d ' ') $(tail -n 3 "$D/c-start2.err" | tr '\n' '|')"
  fi

  # D5：四载体快照前移到 next/contract/record 全序列之前，主检出与站内各一份。
  CARRIERS=$D/conv-carriers
  tr_snapshot_carriers "$CONV" "$CWT" "$CARRIERS"

  # D1a：站路径存在但栅栏未生效——不得把「路径存在」当建站完成
  _intent_before=$(wc -l < "$CONV/.git/ticket-run/90.intent" | tr -d ' ')
  git -C "$CWT" config --unset core.sparseCheckout || true
  git -C "$CWT" config --worktree --unset core.sparseCheckout || true
  tr_run_in "$CONV" 90 start > "$D/d1-fence.out" 2> "$D/d1-fence.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/d1-fence.err" \
    && grep -q '栅栏未生效' "$D/d1-fence.err" \
    && [ "$(wc -l < "$CONV/.git/ticket-run/90.intent" | tr -d ' ')" -eq "$_intent_before" ] \
    && tr_carriers_unchanged "$CONV" "$CWT" "$CARRIERS"; then
    ok 'D1a start 重跑遇 core.sparseCheckout 缺失 → decision-required 且不写 intent 与载体'
  else
    bad 'D1a start 重跑遇 core.sparseCheckout 缺失 → decision-required 且不写 intent 与载体' "exit=$rc $(tail -n 2 "$D/d1-fence.err" | tr '\n' '|')"
  fi
  git -C "$CWT" config core.sparseCheckout true
  git -C "$CWT" config --worktree core.sparseCheckout true

  # D1b：建站后崩溃（intent 停在 worktree started）→ 重跑 start 须补记 done
  D1B=$D/d1b
  tr_build_fixture "$D1B" ready
  tr_run_in "$D1B" 90 start > /dev/null 2>&1
  awk -F "$(printf '\t')" '!($1 == "worktree" && $2 == "done")' \
    "$D1B/.git/ticket-run/90.intent" > "$D/d1b-intent.tmp"
  mv "$D/d1b-intent.tmp" "$D1B/.git/ticket-run/90.intent"
  _d1b_before=$(tr_intent_state "$D1B" worktree)
  tr_run_in "$D1B" 90 start > "$D/d1b-start.out" 2> "$D/d1b-start.err"
  rc=$?
  tr_run_in "$D1B" 90 next > "$D/d1b-next.out" 2> "$D/d1b-next.err"
  rc2=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/d1b-next.out" \
    && [ "$_d1b_before" = 'started' ] && [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] \
    && [ "$(tr_intent_state "$D1B" worktree)" = 'done' ] \
    && ! grep -q '恢复: 上次 worktree' "$D/d1b-next.out"; then
    ok 'D1b 建站后崩溃 → 重跑 start 补记 worktree done 且 next 不再报恢复'
  else
    bad 'D1b 建站后崩溃 → 重跑 start 补记 worktree done 且 next 不再报恢复' "before=${_d1b_before} after=$(tr_intent_state "$D1B" worktree) exit=$rc/$rc2 $(tail -n 2 "$D/d1b-start.err" | tr '\n' '|')"
  fi

  # D1c：建站后 sparse 设置前崩溃——站内 0 文件、status 有 D 删除记录，
  # 不得因 sparseCheckout=true 与 main-only 不在场就判栅栏完整。
  D1C=$D/d1c
  tr_build_fixture "$D1C" ready
  C1WT=$(realpath "$D")/d1c-wt/wt90
  mkdir -p "$(dirname "$C1WT")"
  git -C "$D1C" worktree add -q -b ticket/90-run-fixture "$C1WT"
  git -C "$C1WT" config core.sparseCheckout true
  _c1gd=$(git -C "$C1WT" rev-parse --absolute-git-dir)
  mkdir -p "$_c1gd/info"
  printf '/*\n!agent-up/scripts/export-payload.sh\n' > "$_c1gd/info/sparse-checkout"
  git -C "$C1WT" ls-files | while IFS= read -r _c1p; do rm -f "$C1WT/$_c1p"; done
  _c1_del=$(git -C "$C1WT" status --porcelain | grep -c '^ D ' || true)
  tr_run_in "$D1C" 90 start > "$D/d1c-start.out" 2> "$D/d1c-start.err"
  rc=$?
  if [ "$_c1_del" -ge 1 ] && [ "$rc" -eq 1 ] \
    && grep -q 'decision-required' "$D/d1c-start.err" \
    && grep -q '站内工作树不完整' "$D/d1c-start.err" \
    && grep -q '"status": "ready"' "$D1C/facts/requirements/tickets/index.json" \
    && [ ! -e "$D1C/.git/ticket-run/90.intent" ]; then
    ok 'D1c start 遇站内 0 文件（status 有 D 删除记录）→ decision-required 且零写入'
  else
    bad 'D1c start 遇站内 0 文件（status 有 D 删除记录）→ decision-required 且零写入' "del=$_c1_del exit=$rc $(tail -n 2 "$D/d1c-start.err" | tr '\n' '|')"
  fi

  # D1d：sparse 配置只有 /*、无 main-only ! 排除规则——即使站内文件齐全也不得放行。
  D1D=$D/d1d
  tr_build_fixture "$D1D" ready
  C2WT=$(realpath "$D")/d1d-wt/wt90
  mkdir -p "$(dirname "$C2WT")"
  git -C "$D1D" worktree add -q -b ticket/90-run-fixture "$C2WT"
  git -C "$C2WT" config core.sparseCheckout true
  _c2gd=$(git -C "$C2WT" rev-parse --absolute-git-dir)
  mkdir -p "$_c2gd/info"
  printf '/*\n' > "$_c2gd/info/sparse-checkout"
  _c2_clean=$(git -C "$C2WT" status --porcelain)
  tr_run_in "$D1D" 90 start > "$D/d1d-start.out" 2> "$D/d1d-start.err"
  rc=$?
  if [ -z "$_c2_clean" ] && [ "$rc" -eq 1 ] \
    && grep -q 'decision-required' "$D/d1d-start.err" \
    && grep -q '缺 main-only 排除规则' "$D/d1d-start.err" \
    && grep -q '"status": "ready"' "$D1D/facts/requirements/tickets/index.json" \
    && [ ! -e "$D1D/.git/ticket-run/90.intent" ]; then
    ok 'D1d start 遇 sparse 配置只有 /* 无 ! 排除规则 → decision-required 且零写入'
  else
    bad 'D1d start 遇 sparse 配置只有 /* 无 ! 排除规则 → decision-required 且零写入' "clean=${_c2_clean:-yes} exit=$rc $(tail -n 2 "$D/d1d-start.err" | tr '\n' '|')"
  fi

  # D1e：新建主路径同一判定——建站原子层返回 0 但栅栏未生效，也不得领取。
  D1E=$D/d1e
  tr_build_fixture "$D1E" ready
  cat > "$D1E/rules/implementation/scripts/worktree-add.sh" <<'EOS'
#!/bin/sh
# 模拟建站后 sparse 设置前崩溃：只创建 --no-checkout 空站即返回 0。
git worktree add --no-checkout -b "$2" -- "$1"
EOS
  tr_run_in "$D1E" 90 start > "$D/d1e-start.out" 2> "$D/d1e-start.err"
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'decision-required' "$D/d1e-start.err" \
    && grep -q '栅栏未生效' "$D/d1e-start.err" \
    && grep -q '"status": "ready"' "$D1E/facts/requirements/tickets/index.json" \
    && [ "$(tr_intent_state "$D1E" worktree)" = 'started' ]; then
    ok 'D1e start 新建站后栅栏未生效 → decision-required 且不领取'
  else
    bad 'D1e start 新建站后栅栏未生效 → decision-required 且不领取' "exit=$rc state=$(tr_intent_state "$D1E" worktree) $(tail -n 2 "$D/d1e-start.err" | tr '\n' '|')"
  fi

  # D1f：--no-checkout + sparse set 后、read-tree 前返回 0——真实空索引窗口
  #（status 为 `D ` 暂存删除、ls-files 为空），必须判「索引为空」而非「有删除」。
  D1F=$D/d1f
  tr_build_fixture "$D1F" ready
  cat > "$D1F/rules/implementation/scripts/worktree-add.sh" <<'EOS'
#!/bin/sh
# mock：worktree add --no-checkout + sparse set 后返回 0，跳过 read-tree（空索引窗口）
git worktree add --no-checkout -b "$2" -- "$1" || exit 1
printf '/*\n!agent-up/scripts/export-payload.sh\n' | git -C "$1" sparse-checkout set --stdin || exit 1
exit 0
EOS
  FWT=$(realpath "$D")/d1f-wt/wt90
  tr_run_in "$D1F" 90 start > "$D/d1f-start.out" 2> "$D/d1f-start.err"
  rc=$?
  _f1_files=$(git -C "$FWT" ls-files 2>/dev/null)
  _f1_d=$(git -C "$FWT" status --porcelain 2>/dev/null | grep -cE '^(D | D|DD)' || true)
  if require_out 'suite-ticket-run 目标输出在场' "$D/d1f-start.err" \
    && [ "$rc" -eq 1 ] && [ -z "$_f1_files" ] && [ "$_f1_d" -ge 1 ] \
    && grep -q 'decision-required' "$D/d1f-start.err" \
    && grep -q '站索引为空' "$D/d1f-start.err" \
    && ! grep -q '站内工作树不完整' "$D/d1f-start.err" \
    && grep -q '"status": "ready"' "$D1F/facts/requirements/tickets/index.json" \
    && [ "$(tr_intent_state "$D1F" worktree)" = 'started' ] \
    && [ "$(wc -l < "$D1F/facts/project/changes.jsonl" | tr -d ' ')" -eq 1 ]; then
    ok 'D1f start 遇空索引站（D 暂存删除＋ls-files 空）→ 指名未物化且不领取'
  else
    bad 'D1f start 遇空索引站（D 暂存删除＋ls-files 空）→ 指名未物化且不领取' "files=$(printf '%s' "$_f1_files" | wc -l | tr -d ' ') del=$_f1_d exit=$rc $(tail -n 2 "$D/d1f-start.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 next > "$D/c-next2.out" 2> "$D/c-next2.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: 下一步: contract implementation$' "$D/c-next2.out"; then
    ok 'C4 next 在站就绪的 in_progress 票上推导 contract implementation'
  else
    bad 'C4 next 在站就绪的 in_progress 票上推导 contract implementation' "exit=$rc $(cat "$D/c-next2.out" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 contract implementation > "$D/c-impl.out" 2> "$D/c-impl.err"
  rc=$?
  c_impl_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/c-impl.out")
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/c-impl.out" | tr -d ' ')" -eq 2 ] \
    && [ -f "$c_impl_contract" ] \
    && sh "$CONV/rules/implementation/scripts/check-dispatch-contract.sh" --check "$c_impl_contract" >/dev/null 2>&1; then
    ok 'C5 contract implementation 恰两行且合同过 check-dispatch-contract 自校验'
  else
    bad 'C5 contract implementation 恰两行且合同过 check-dispatch-contract 自校验' "exit=$rc $(tail -n 3 "$D/c-impl.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 implementation > "$D/c-legacy.out" 2> "$D/c-legacy.err"
  rc=$?
  c_legacy_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/c-legacy.out")
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/c-legacy.out" | tr -d ' ')" -eq 2 ] \
    && cmp -s "$c_impl_contract" "$c_legacy_contract"; then
    ok 'C6 legacy implementation 行为兼容：两行输出且合同与 contract implementation 逐字一致'
  else
    bad 'C6 legacy implementation 行为兼容：两行输出且合同与 contract implementation 逐字一致' "exit=$rc $(tail -n 3 "$D/c-legacy.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 contract review > "$D/c-review.out" 2> "$D/c-review.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/c-review.out" | tr -d ' ')" -eq 2 ] \
    && sh "$CONV/rules/implementation/scripts/check-dispatch-contract.sh" --check \
      "$(sed -n 's/^ticket-run: 合同文件: //p' "$D/c-review.out")" >/dev/null 2>&1; then
    ok 'C7 contract review 恰两行且合同过自校验'
  else
    bad 'C7 contract review 恰两行且合同过自校验' "exit=$rc $(tail -n 3 "$D/c-review.err" | tr '\n' '|')"
  fi

  if tr_carriers_unchanged "$CONV" "$CWT" "$CARRIERS"; then
    ok 'C7b next/contract implementation/review 全程主检出＋站内四载体逐字不变'
  else
    bad 'C7b next/contract implementation/review 全程主检出＋站内四载体逐字不变' '载体被改写'
  fi

  FAULT=$D/fault
  tr_build_fixture "$FAULT" ready
  FWT=$(realpath "$D")/fault-wt/wt90
  (cd "$FAULT" && TMPDIR="$D/tmp" TICKET_OPS_FAULT=after-index-write \
    sh "$FAULT/rules/implementation/scripts/ticket-run.sh" 90 start) > "$D/c-fault1.out" 2> "$D/c-fault1.err"
  rc=$?
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if [ "$rc" -eq 1 ] && [ -d "$FWT" ] \
    && grep -q '"status": "in_progress"' "$FAULT/facts/requirements/tickets/index.json" \
    && grep -q '`ready`' "$FAULT/facts/requirements/tickets/README.md" \
    && [ "$(wc -l < "$FAULT/facts/project/changes.jsonl" | tr -d ' ')" -eq 1 ]; then
    ok 'C8 start 在索引落盘后崩溃 → exit 1，账本/README 未写且站已建'
  else
    bad 'C8 start 在索引落盘后崩溃 → exit 1，账本/README 未写且站已建' "exit=$rc $(tail -n 3 "$D/c-fault1.err" | tr '\n' '|')"
  fi

  tr_run_in "$FAULT" 90 next > "$D/c-fault-next.out" 2> "$D/c-fault-next.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: 下一步: start$' "$D/c-fault-next.out" \
    && grep -q '^ticket-run: 恢复: 上次 take 步骤未完成' "$D/c-fault-next.out"; then
    ok 'C8b next 识别未完成 intent：先重跑 start 收敛并报告恢复步骤'
  else
    bad 'C8b next 识别未完成 intent：先重跑 start 收敛并报告恢复步骤' "exit=$rc $(cat "$D/c-fault-next.out" | tr '\n' '|')"
  fi

  tr_run_in "$FAULT" 90 start > "$D/c-fault2.out" 2> "$D/c-fault2.err"
  rc=$?
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if [ "$rc" -eq 0 ] \
    && [ "$(wc -l < "$FAULT/facts/project/changes.jsonl" | tr -d ' ')" -eq 2 ] \
    && grep -q '`in_progress`' "$FAULT/facts/requirements/tickets/README.md" \
    && grep -q '"status": "in_progress"' "$FAULT/facts/requirements/tickets/index.json"; then
    ok 'C8c 重跑 start 收敛：账本补齐、README 状态列与索引一致'
  else
    bad 'C8c 重跑 start 收敛：账本补齐、README 状态列与索引一致' "exit=$rc $(tail -n 3 "$D/c-fault2.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt.json" PASS
  tr_run_in "$CONV" 90 record "$D/c-receipt.json" > "$D/c-record1.out" 2> "$D/c-record1.err"
  rc=$?
  c_evidence="$CWT/facts/requirements/tickets/90-run-fixture.review-evidence.json"
  if [ "$rc" -eq 0 ] && [ -f "$c_evidence" ] && grep -q '"verdict": "PASS"' "$c_evidence"; then
    ok 'C9 record 校验合法 review 收据并落位到站内 review-evidence 路径'
  else
    bad 'C9 record 校验合法 review 收据并落位到站内 review-evidence 路径' "exit=$rc $(tail -n 3 "$D/c-record1.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 record "$D/c-receipt.json" > "$D/c-record2.out" 2> "$D/c-record2.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '已收敛' "$D/c-record2.out"; then
    ok 'C9b record 同内容重跑收敛（不重写证据）'
  else
    bad 'C9b record 同内容重跑收敛（不重写证据）' "exit=$rc $(tail -n 3 "$D/c-record2.err" | tr '\n' '|')"
  fi

  # D2：模拟 record 落位后、done 前崩溃——恢复判定须看收据实态，收敛分支须补记 done
  awk -F "$(printf '\t')" '!($1 == "record" && $2 == "done")' \
    "$CONV/.git/ticket-run/90.intent" > "$D/d2-intent.tmp"
  mv "$D/d2-intent.tmp" "$CONV/.git/ticket-run/90.intent"
  tr_run_in "$CONV" 90 next > "$D/d2-next.out" 2> "$D/d2-next.err"
  rc=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/d2-next.out" && [ "$rc" -eq 0 ] && ! grep -q '恢复: 上次 record' "$D/d2-next.out"; then
    ok 'D2a record 落位后崩溃 → next 按收据实态判已完成，不报 record 恢复'
  else
    bad 'D2a record 落位后崩溃 → next 按收据实态判已完成，不报 record 恢复' "exit=$rc $(cat "$D/d2-next.out" | tr '\n' '|')"
  fi
  tr_run_in "$CONV" 90 record "$D/c-receipt.json" > "$D/d2-record.out" 2> "$D/d2-record.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '已收敛' "$D/d2-record.out" \
    && [ "$(tr_intent_state "$CONV" record)" = 'done' ]; then
    ok 'D2b record 收敛分支补记 intent done（重跑后不留 started）'
  else
    bad 'D2b record 收敛分支补记 intent done（重跑后不留 started）' "exit=$rc state=$(tr_intent_state "$CONV" record) $(tail -n 2 "$D/d2-record.err" | tr '\n' '|')"
  fi

  # N2：源收据被清理后，next 仍按目标证据实态判 record 已完成（不永久报未完成）
  awk -F "$(printf '\t')" '!($1 == "record" && $2 == "done")' \
    "$CONV/.git/ticket-run/90.intent" > "$D/n2-intent.tmp"
  mv "$D/n2-intent.tmp" "$CONV/.git/ticket-run/90.intent"
  rm -f "$D/c-receipt.json"
  tr_run_in "$CONV" 90 next > "$D/n2-next.out" 2> "$D/n2-next.err"
  rc=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/n2-next.out" && [ "$rc" -eq 0 ] && ! grep -q '恢复: 上次 record' "$D/n2-next.out"; then
    ok 'D2c 源收据被清理 → next 按目标证据＋intent kind 判 record 已完成'
  else
    bad 'D2c 源收据被清理 → next 按目标证据＋intent kind 判 record 已完成' "exit=$rc $(cat "$D/n2-next.out" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-fail.json" FAIL
  tr_run_in "$CONV" 90 record "$D/c-receipt-fail.json" > "$D/c-record3.out" 2> "$D/c-record3.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/c-record3.err" \
    && grep -q '"verdict": "PASS"' "$c_evidence"; then
    ok 'C9c record 不同内容 → decision-required 且原证据不被覆盖'
  else
    bad 'C9c record 不同内容 → decision-required 且原证据不被覆盖' "exit=$rc $(tail -n 2 "$D/c-record3.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-badverdict.json" 'PASS: 全部通过'
  tr_run_in "$CONV" 90 record "$D/c-receipt-badverdict.json" > "$D/c-record4.out" 2> "$D/c-record4.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'verdict 越枚举' "$D/c-record4.err"; then
    ok 'C9d record 拒绝越枚举 verdict（PASS: 全部通过）并指名字段'
  else
    bad 'C9d record 拒绝越枚举 verdict（PASS: 全部通过）并指名字段' "exit=$rc $(tail -n 2 "$D/c-record4.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-noactor.json" PASS actor
  tr_run_in "$CONV" 90 record "$D/c-receipt-noactor.json" > "$D/c-record5.out" 2> "$D/c-record5.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '缺必备字段: actor' "$D/c-record5.err"; then
    ok 'C9e record 拒绝缺必备字段（actor）并指名'
  else
    bad 'C9e record 拒绝缺必备字段（actor）并指名' "exit=$rc $(tail -n 2 "$D/c-record5.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-extra.json" PASS EXTRA
  tr_run_in "$CONV" 90 record "$D/c-receipt-extra.json" > "$D/c-record6.out" 2> "$D/c-record6.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'schema 未定义的顶层字段' "$D/c-record6.err"; then
    ok 'C9f record 拒绝 schema 未定义的顶层字段'
  else
    bad 'C9f record 拒绝 schema 未定义的顶层字段' "exit=$rc $(tail -n 2 "$D/c-record6.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-notesnum.json" PASS NOTES_NUMBER
  tr_run_in "$CONV" 90 record "$D/c-receipt-notesnum.json" > "$D/c-record7.out" 2> "$D/c-record7.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'notes 须为字符串' "$D/c-record7.err"; then
    ok 'D4a record 拒绝 notes 数值（schema type: string）并指名字段'
  else
    bad 'D4a record 拒绝 notes 数值（schema type: string）并指名字段' "exit=$rc $(tail -n 2 "$D/c-record7.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-acextra.json" PASS AC_EXTRA
  tr_run_in "$CONV" 90 record "$D/c-receipt-acextra.json" > "$D/c-record8.out" 2> "$D/c-record8.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -qF 'acceptance[0] 含 schema 未定义的键' "$D/c-record8.err"; then
    ok 'D4b record 拒绝 acceptance 项 schema 未定义的键（additionalProperties: false）'
  else
    bad 'D4b record 拒绝 acceptance 项 schema 未定义的键（additionalProperties: false）' "exit=$rc $(tail -n 2 "$D/c-record8.err" | tr '\n' '|')"
  fi

  tr_receipt "$D/c-receipt-schemastr.json" PASS SCHEMA_STR
  tr_run_in "$CONV" 90 record "$D/c-receipt-schemastr.json" > "$D/c-record9.out" 2> "$D/c-record9.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'schema_version 须为数值' "$D/c-record9.err"; then
    ok 'D4c record 拒绝 schema_version 字符串（schema type: number, const 1）'
  else
    bad 'D4c record 拒绝 schema_version 字符串（schema type: number, const 1）' "exit=$rc $(tail -n 2 "$D/c-record9.err" | tr '\n' '|')"
  fi

  if python3 - "$SCRIPT_DIR/ticket-run.sh" "$PKG_ROOT/references/schemas/receipt.schema.json" <<'PY'
import json, re, sys

script_path, schema_path = sys.argv[1], sys.argv[2]
src = open(script_path, encoding='utf-8').read()
try:
    schema = json.load(open(schema_path, encoding='utf-8'))
except (OSError, ValueError) as exc:
    print('schema 读取失败: %s' % exc, file=sys.stderr)
    sys.exit(1)


def shell_list(name):
    match = re.search(r"^%s='([^']*)'$" % name, src, re.M)
    return None if match is None else match.group(1).split()


def kind_map():
    block = re.search(r'^receipt_kind_requires\(\) \{\n(.*?)^\}', src, re.M | re.S)
    if block is None:
        return None
    return {k: v.split() for k, v in
            re.findall(r"^\s+(\w+)\) printf '%s' '([^']*)' ;;", block.group(1), re.M)}


errors = []
props = shell_list('receipt_props')
required = shell_list('receipt_required_top')
shas = shell_list('receipt_sha_fields')
kinds = kind_map()
if props is None or required is None or shas is None or kinds is None:
    print('未能解析 ticket-run.sh 的收据字段常量', file=sys.stderr)
    sys.exit(1)

schema_props = schema.get('properties', {})
if set(props) != set(schema_props):
    errors.append('顶层字段集不一致: 脚本多 %s / schema 多 %s' % (
        sorted(set(props) - set(schema_props)), sorted(set(schema_props) - set(props))))
if set(required) != set(schema.get('required', [])):
    errors.append('必备字段集不一致: %s vs %s' % (required, schema.get('required')))
schema_shas = sorted(k for k, v in schema_props.items() if v.get('pattern') == '^[0-9a-f]{40}$')
if sorted(shas) != schema_shas:
    errors.append('sha 字段集不一致: %s vs %s' % (sorted(shas), schema_shas))
schema_kinds = {}
for clause in schema.get('allOf', []):
    kind = clause.get('if', {}).get('properties', {}).get('receipt_kind', {}).get('const')
    if kind:
        schema_kinds[kind] = set(clause.get('then', {}).get('required', []))
if set(kinds) != set(schema_kinds):
    errors.append('收据种类集不一致: %s vs %s' % (sorted(kinds), sorted(schema_kinds)))
for kind in sorted(set(kinds) & set(schema_kinds)):
    if set(kinds[kind]) != schema_kinds[kind]:
        errors.append('%s 条件必备字段不一致: %s vs %s' % (
            kind, sorted(kinds[kind]), sorted(schema_kinds[kind])))
item_match = re.search(r'for _k in (ac_id[^\n;]*); do', src)
item_props = set(schema_props.get('acceptance', {}).get('items', {}).get('properties', {}))
if item_match is None:
    errors.append('未找到 acceptance 项键集循环')
elif set(item_match.group(1).split()) != item_props:
    errors.append('acceptance 项键集不一致: %s vs %s' % (
        sorted(set(item_match.group(1).split())), sorted(item_props)))
if schema.get('additionalProperties') is not False:
    errors.append('schema 顶层 additionalProperties 未声明 false')
if schema_props.get('acceptance', {}).get('items', {}).get('additionalProperties') is not False:
    errors.append('schema acceptance.items additionalProperties 未声明 false')
if schema_props.get('schema_version', {}).get('const') != 1:
    errors.append('schema schema_version const 不是 1')
if errors:
    for err in errors:
        print('单源核对失败: ' + err, file=sys.stderr)
    sys.exit(1)
print('receipt.schema.json 单源核对: PASS（顶层 %d 键／必备 %d／sha %d／kind 条件 %d／acceptance 项 %d 键）' % (
    len(schema_props), len(required), len(shas), len(kinds), len(item_props)))
PY
  then
    ok 'D4d ticket-run 收据常量与 receipt.schema.json 逐项单源一致'
  else
    bad 'D4d ticket-run 收据常量与 receipt.schema.json 逐项单源一致' '常量与 schema 漂移'
  fi

  if tr_carriers_unchanged "$CONV" "$CWT" "$CARRIERS"; then
    ok 'C9g record 全序列后主检出＋站内四载体逐字不变（只搬收据）'
  else
    bad 'C9g record 全序列后主检出＋站内四载体逐字不变（只搬收据）' '载体被改写'
  fi

  # D5 自检：比对器必须抓住「contract 写主索引」与「record 写站内 README/账本」三类变异
  PM=$D/probe-main
  PW=$D/probe-wt
  PSNAP=$D/probe-snap
  mkdir -p "$PM" "$PW"
  for _crel in $tr_carrier_rels; do
    mkdir -p "$PM/$(dirname "$_crel")" "$PW/$(dirname "$_crel")"
    [ -f "$CONV/$_crel" ] && cp "$CONV/$_crel" "$PM/$_crel"
    [ -f "$CWT/$_crel" ] && cp "$CWT/$_crel" "$PW/$_crel"
  done
  tr_snapshot_carriers "$PM" "$PW" "$PSNAP"
  _probe_missed=0
  printf 'mutation\n' >> "$PM/facts/requirements/tickets/index.json"
  tr_carriers_unchanged "$PM" "$PW" "$PSNAP" 2>/dev/null && _probe_missed=$((_probe_missed + 1))
  cp "$PSNAP/1-main" "$PM/facts/requirements/tickets/index.json"
  printf 'mutation\n' >> "$PW/facts/project/changes.jsonl"
  tr_carriers_unchanged "$PM" "$PW" "$PSNAP" 2>/dev/null && _probe_missed=$((_probe_missed + 1))
  cp "$PSNAP/3-wt" "$PW/facts/project/changes.jsonl"
  printf 'mutation\n' >> "$PW/facts/requirements/tickets/README.md"
  tr_carriers_unchanged "$PM" "$PW" "$PSNAP" 2>/dev/null && _probe_missed=$((_probe_missed + 1))
  if [ "$_probe_missed" -eq 0 ]; then
    ok 'D5 自检：主索引/站内 README/站内账本任一被改，四载体比对均判失败'
  else
    bad 'D5 自检：主索引/站内 README/站内账本任一被改，四载体比对均判失败' "漏检 ${_probe_missed} 处"
  fi

  tr_run_in "$CONV" 90 verify-dispatch implementation "$c_impl_contract" > "$D/c-vd1.out" 2> "$D/c-vd1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS implementation' "$D/c-vd1.out"; then
    ok 'C10 verify-dispatch 合同文件与票面重渲染逐字一致时 PASS'
  else
    bad 'C10 verify-dispatch 合同文件与票面重渲染逐字一致时 PASS' "exit=$rc $(tail -n 2 "$D/c-vd1.err" | tr '\n' '|')"
  fi

  tr_run_in "$CONV" 90 verify-dispatch implementation "$D/c-missing-contract.json" > "$D/c-vd2.out" 2> "$D/c-vd2.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '合同文件不存在' "$D/c-vd2.err"; then
    ok 'C10b verify-dispatch 合同文件缺失 → exit 1 指名路径'
  else
    bad 'C10b verify-dispatch 合同文件缺失 → exit 1 指名路径' "exit=$rc $(tail -n 2 "$D/c-vd2.err" | tr '\n' '|')"
  fi

  cp "$c_impl_contract" "$D/c-drift-contract.json"
  printf 'drift\n' >> "$D/c-drift-contract.json"
  tr_run_in "$CONV" 90 verify-dispatch implementation "$D/c-drift-contract.json" > "$D/c-vd3.out" 2> "$D/c-vd3.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '漂移' "$D/c-vd3.err"; then
    ok 'C10c verify-dispatch 合同漂移 → exit 1 指名重渲染不一致'
  else
    bad 'C10c verify-dispatch 合同漂移 → exit 1 指名重渲染不一致' "exit=$rc $(tail -n 2 "$D/c-vd3.err" | tr '\n' '|')"
  fi

  VD=$D/vd
  tr_build_fixture "$VD" ready
  python3 - "$VD" <<'PY'
import json, sys
path = sys.argv[1] + '/facts/requirements/tickets/90-run-fixture.json'
with open(path, encoding='utf-8') as handle:
    ticket = json.load(handle)
ticket['dispatch'].pop('review', None)
with open(path, 'w', encoding='utf-8') as handle:
    json.dump(ticket, handle, ensure_ascii=False, indent=2)
    handle.write('\n')
PY
  tr_git_commit "$VD" drop-review-dispatch
  tr_run_in "$VD" 90 verify-dispatch review > "$D/c-vd4.out" 2> "$D/c-vd4.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'dispatch.review' "$D/c-vd4.err"; then
    ok 'C10d verify-dispatch 票面缺 dispatch.review 阶段对象 → exit 1 指名'
  else
    bad 'C10d verify-dispatch 票面缺 dispatch.review 阶段对象 → exit 1 指名' "exit=$rc $(tail -n 2 "$D/c-vd4.err" | tr '\n' '|')"
  fi

  DEC=$D/dec
  tr_build_fixture "$DEC" ready
  mkdir -p "$D/dec-wt/wt90"
  tr_run_in "$DEC" 90 start > "$D/c-dec.out" 2> "$D/c-dec.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/c-dec.err" \
    && grep -q '"status": "ready"' "$DEC/facts/requirements/tickets/index.json" \
    && [ "$(wc -l < "$DEC/facts/project/changes.jsonl" | tr -d ' ')" -eq 1 ] \
    && [ ! -e "$D/dec-wt/wt90/.git" ]; then
    ok 'C11 start 遇普通目录占位 → decision-required 零写入且不覆盖既有目录'
  else
    bad 'C11 start 遇普通目录占位 → decision-required 零写入且不覆盖既有目录' "exit=$rc $(tail -n 2 "$D/c-dec.err" | tr '\n' '|')"
  fi

  tr_run_in "$DEC" 90 next > "$D/c-dec-next.out" 2> "$D/c-dec-next.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^ticket-run: 下一步: decision-required$' "$D/c-dec-next.out"; then
    ok 'C11b next 对无法判定的站路径返回 decision-required 且 exit 1'
  else
    bad 'C11b next 对无法判定的站路径返回 decision-required 且 exit 1' "exit=$rc $(cat "$D/c-dec-next.out" | tr '\n' '|')"
  fi

  # D6：残留 take intent ＋ 索引已非可领取状态——恢复提示须先核 start 前置，
  # 不得提示「重跑 start」（start 会因前置拒绝、intent 永不清除＝永不收敛）。
  tr_pending_take() {
    # $1=夹具根：写一条 take started 残留 intent（路径＝<root>/.git/ticket-run/90.intent）
    mkdir -p "$1/.git/ticket-run" || return 1
    printf 'take\tstarted\t2026-10-28T10:00:00Z\n' > "$1/.git/ticket-run/90.intent"
  }
  D6A=$D/d6a
  tr_build_fixture "$D6A" 'done'
  tr_pending_take "$D6A"
  tr_run_in "$D6A" 90 next > "$D/d6a-next.out" 2> "$D/d6a-next.err"
  rc=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/d6a-next.out" \
    && [ "$rc" -eq 1 ] \
    && grep -q '^ticket-run: 下一步: decision-required$' "$D/d6a-next.out" \
    && ! grep -q '^ticket-run: 下一步: start$' "$D/d6a-next.out" \
    && grep -q 'next --clear-intent' "$D/d6a-next.out"; then
    ok 'D6a 残留 take intent＋索引 done → next 判 decision-required 并给登记清除路径'
  else
    bad 'D6a 残留 take intent＋索引 done → next 判 decision-required 并给登记清除路径' "exit=$rc $(cat "$D/d6a-next.out" | tr '\n' '|')"
  fi

  tr_run_in "$D6A" 90 next --clear-intent > "$D/d6a-clear.out" 2> "$D/d6a-clear.err"
  rc=$?
  tr_run_in "$D6A" 90 next > "$D/d6a-after.out" 2> "$D/d6a-after.err"
  rc2=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/d6a-after.out" \
    && [ "$rc" -eq 0 ] && [ ! -e "$D6A/.git/ticket-run/90.intent" ] \
    && grep -q '将清除' "$D/d6a-clear.out" && grep -q 'take' "$D/d6a-clear.out" \
    && [ "$rc2" -eq 0 ] && grep -q '^ticket-run: 下一步: done$' "$D/d6a-after.out" \
    && ! grep -q '^ticket-run: 恢复:' "$D/d6a-after.out"; then
    ok 'D6b next --clear-intent 先打印原内容再清残留：intent 已删且下一步回到 done'
  else
    bad 'D6b next --clear-intent 先打印原内容再清残留：intent 已删且下一步回到 done' "exit=$rc/$rc2 $(cat "$D/d6a-clear.out" "$D/d6a-after.out" | tr '\n' '|')"
  fi

  D6C=$D/d6c
  tr_build_fixture "$D6C" review_pass
  (cd "$D6C" && git worktree add -q -b ticket/90-run-fixture "$D/d6c-wt/wt90" HEAD)
  tr_pending_take "$D6C"
  tr_run_in "$D6C" 90 next > "$D/d6c-next.out" 2> "$D/d6c-next.err"
  rc=$?
  if require_out 'suite-ticket-run 目标输出在场' "$D/d6c-next.out" \
    && [ "$rc" -eq 1 ] \
    && grep -q '^ticket-run: 下一步: decision-required$' "$D/d6c-next.out" \
    && ! grep -qE '^ticket-run: 下一步: (start|commit)$' "$D/d6c-next.out"; then
    ok 'D6c 残留 take intent＋索引 review_pass（站已就位）→ next 判 decision-required（不提示 start/commit）'
  else
    bad 'D6c 残留 take intent＋索引 review_pass（站已就位）→ next 判 decision-required（不提示 start/commit）' "exit=$rc $(cat "$D/d6c-next.out" | tr '\n' '|')"
  fi

  # D6d/D6e：残留仍可收敛的正例侧（索引 ready）——next 必须给出 start；
  # --clear-intent 必须拒绝并保留 intent（不得删掉唯一恢复信号）。
  D6D=$D/d6d
  tr_build_fixture "$D6D" ready
  tr_pending_take "$D6D"
  tr_run_in "$D6D" 90 next > "$D/d6d-next.out" 2> "$D/d6d-next.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^ticket-run: 下一步: start$' "$D/d6d-next.out"; then
    ok 'D6d 残留 take intent＋索引 ready（可领取）→ next 给出 start（正例侧）'
  else
    bad 'D6d 残留 take intent＋索引 ready（可领取）→ next 给出 start（正例侧）' "exit=$rc $(cat "$D/d6d-next.out" | tr '\n' '|')"
  fi

  tr_run_in "$D6D" 90 next --clear-intent > "$D/d6d-clear.out" 2> "$D/d6d-clear.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ -f "$D6D/.git/ticket-run/90.intent" ] \
    && grep -q '仍可收敛' "$D/d6d-clear.err" && grep -q '重跑 start' "$D/d6d-clear.err"; then
    ok 'D6e 残留仍可收敛时 --clear-intent → exit 1、指名重跑 start 且 intent 仍在'
  else
    bad 'D6e 残留仍可收敛时 --clear-intent → exit 1、指名重跑 start 且 intent 仍在' "exit=$rc kept=$([ -f "$D6D/.git/ticket-run/90.intent" ] && echo yes || echo no) $(cat "$D/d6d-clear.err" | tr '\n' '|')"
  fi

  # D3：本地日期与 UTC 日期跨日时重跑 start——账本日期须与 ticket-ops 的 updated_at 同源
  case $(date -u '+%H') in
    1[0-9]|2[0-3]) _tz_skew='Etc/GMT-14' ;;
    *) _tz_skew='Etc/GMT+12' ;;
  esac
  _local_date=$(TZ="$_tz_skew" date '+%F')
  _utc_date=$(TZ="$_tz_skew" date -u '+%F')
  D3=$D/d3
  tr_build_fixture "$D3" ready
  (cd "$D3" && TZ="$_tz_skew" TMPDIR="$D/tmp" \
    sh "$D3/rules/implementation/scripts/ticket-run.sh" 90 start) > "$D/d3-start1.out" 2> "$D/d3-start1.err"
  rc=$?
  (cd "$D3" && TZ="$_tz_skew" TMPDIR="$D/tmp" \
    sh "$D3/rules/implementation/scripts/ticket-run.sh" 90 start) > "$D/d3-start2.out" 2> "$D/d3-start2.err"
  rc2=$?
  _ledger_date=$(sed -n 's/^{"date":"\([^"]*\)".*"decision":"ticket-run start.*/\1/p' "$D3/facts/project/changes.jsonl")
  _index_ua=$(sed -n 's/.*"updated_at": "\([^"]*\)".*/\1/p' "$D3/facts/requirements/tickets/index.json")
  if [ "$_local_date" != "$_utc_date" ] && [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] \
    && [ "$(wc -l < "$D3/facts/project/changes.jsonl" | tr -d ' ')" -eq 2 ] \
    && [ "$_ledger_date" = "$_local_date" ] \
    && [ "${_index_ua%%T*}" = "$_local_date" ]; then
    ok 'D3 本地/UTC 跨日重跑 start：账本仍一行且日期与索引 updated_at 同源'
  else
    bad 'D3 本地/UTC 跨日重跑 start：账本仍一行且日期与索引 updated_at 同源' "TZ=$_tz_skew local=$_local_date utc=$_utc_date ledger=$_ledger_date index=$_index_ua rows=$(wc -l < "$D3/facts/project/changes.jsonl" | tr -d ' ') exit=$rc/$rc2"
  fi

  # D7：票定位器须按票本体 id 口径（<NN>-<slug>，slug 仅 [a-z0-9-]，文件名无点号）筛出
  #     票本体，不被同目录派生件（独立审查收据 <id>.review-evidence.json 等）算成第二件票。
  D7=$D/d7
  tr_build_fixture "$D7" in_progress
  printf '{"schema_version":1,"receipt_kind":"review","ticket_id":"90-run-fixture"}\n' \
    > "$D7/facts/requirements/tickets/90-run-fixture.review-evidence.json"
  tr_run_in "$D7" 90 next > "$D/d7-next.out" 2> "$D/d7-next.err"
  rc=$?
  # 定位到本体才会取到索引条目（ready/in_progress）→ start；若误取收据，ticket_id 变成
  # 90-run-fixture.review-evidence，索引无条目只会给 open。
  if require_out --allow-empty 'suite-ticket-run 目标输出在场' "$D/d7-next.err" \
    && [ "$rc" -eq 0 ] && ! grep -q '须恰一命中' "$D/d7-next.err" \
    && grep -q '^ticket-run: 下一步: start$' "$D/d7-next.out"; then
    ok 'D7a 票本体旁有 <id>.review-evidence.json 时 next 仍定位票本体（不因多命中 FAIL）'
  else
    bad 'D7a 票本体旁有 <id>.review-evidence.json 时 next 仍定位票本体（不因多命中 FAIL）' "exit=$rc $(cat "$D/d7-next.out" "$D/d7-next.err" | tr '\n' '|')"
  fi

  D7B=$D/d7b
  tr_build_fixture "$D7B" in_progress
  printf '{"schema_version":1,"receipt_kind":"review","ticket_id":"91-orphan"}\n' \
    > "$D7B/facts/requirements/tickets/91-orphan.review-evidence.json"
  tr_run_in "$D7B" 77 next > "$D/d7b-none.out" 2> "$D/d7b-none.err"
  rc=$?
  tr_run_in "$D7B" 91 next > "$D/d7b-orphan.out" 2> "$D/d7b-orphan.err"
  rc2=$?
  if [ "$rc" -eq 1 ] && grep -q '票号段 77 无命中' "$D/d7b-none.err" \
    && [ "$rc2" -eq 1 ] && grep -q '票号段 91 无命中' "$D/d7b-orphan.err" \
    && [ ! -s "$D/d7b-none.out" ] && [ ! -s "$D/d7b-orphan.out" ]; then
    ok 'D7b 负例：NN 零命中与「仅有审查收据无票本体」均非零退出并报无命中'
  else
    bad 'D7b 负例：NN 零命中与「仅有审查收据无票本体」均非零退出并报无命中' "exit=$rc/$rc2 $(cat "$D/d7b-none.err" "$D/d7b-orphan.err" | tr '\n' '|')"
  fi

  cp "$D7B/facts/requirements/tickets/90-run-fixture.json" \
    "$D7B/facts/requirements/tickets/90-second-slug.json"
  tr_run_in "$D7B" 90 next > "$D/d7b-two.out" 2> "$D/d7b-two.err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '票号段 90 定位命中 2 件票本体，须恰一命中' "$D/d7b-two.err" \
    && [ ! -s "$D/d7b-two.out" ]; then
    ok 'D7c 负例：同 NN 两件真实票本体仍 fail-closed 指名「命中 2 件」'
  else
    bad 'D7c 负例：同 NN 两件真实票本体仍 fail-closed 指名「命中 2 件」' "exit=$rc $(cat "$D/d7b-two.err" | tr '\n' '|')"
  fi

  (cd "$CONV" && sh "$CONV/rules/implementation/scripts/ticket-run.sh" -h) > "$D/c-help.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'next ' "$D/c-help.out" && grep -q 'start ' "$D/c-help.out" \
    && grep -q 'contract <stage>' "$D/c-help.out" && grep -q 'record <receipt-file>' "$D/c-help.out" \
    && grep -q 'verify-dispatch <stage>' "$D/c-help.out"; then
    ok 'C12 -h 用法列出五子命令（next/start/contract/record/verify-dispatch）'
  else
    bad 'C12 -h 用法列出五子命令（next/start/contract/record/verify-dispatch）' "exit=$rc"
  fi

  if grep -q '^pm_script scripts/ticket-run.sh' "$PKG_ROOT/scripts/package-manifest.rules" \
    && grep -q 'pm_script scripts/ticket-run.sh.*next.*verify-dispatch' "$PKG_ROOT/scripts/package-manifest.rules"; then
    ok 'C13 包清单 ticket-run 描述登记可恢复协调器五子命令'
  else
    bad 'C13 包清单 ticket-run 描述登记可恢复协调器五子命令' 'package-manifest.rules 未登记'
  fi

  if sed -n '/^## ticket-run.sh/,/^## /p' "$PKG_ROOT/scripts/README.md" | grep -q 'next' \
    && sed -n '/^## ticket-run.sh/,/^## /p' "$PKG_ROOT/scripts/README.md" | grep -q 'verify-dispatch'; then
    ok 'C14 脚本 README 专节登记五子命令与恢复语义'
  else
    bad 'C14 脚本 README 专节登记五子命令与恢复语义' 'README 专节未登记'
  fi

  # shellcheck disable=SC2016  # grep 模式刻意匹配 shell 源码字面量，不能在测试层展开
  if require_out 'suite-ticket-run 目标输出在场' "$SCRIPT_DIR/ticket-run.sh" "$SCRIPT_DIR/workflow-executor.sh" \
    && ! grep -Eq '(^|[[:space:]])agent\(' "$SCRIPT_DIR/ticket-run.sh" \
    && ! grep -q 'workflow index-status' "$SCRIPT_DIR/workflow-executor.sh" \
    && ! grep -q 'get_current_status\|update_status' "$SCRIPT_DIR/workflow-executor.sh" \
    && grep -q 'sh "$_ds_ticket_ops" "$_ds_repo_root" flip-index' "$SCRIPT_DIR/workflow-executor.sh"; then
    ok 'AC2a ticket-run 不 spawn 子 agent；workflow-executor 无索引直写且改调 flip-index'
  else
    bad 'AC2a ticket-run 不 spawn 子 agent；workflow-executor 无索引直写且改调 flip-index' '静态边界不符'
  fi

  CHAIN="$PKG_ROOT/.."'/.zcode/workflows/ticket-chain.dwf.ts'
  if require_out 'suite-ticket-run 目标输出在场' "$CHAIN" \
    && ! grep -q 'rows=\[x for x in d.get' "$CHAIN" \
    && grep -q '"rules/implementation/scripts/json-validator.py", "json", "pick"' "$CHAIN"; then
    ok 'AC2b ticket-chain 无内嵌索引解析，状态读取经唯一 JSON 引擎'
  else
    bad 'AC2b ticket-chain 无内嵌索引解析，状态读取经唯一 JSON 引擎' '静态边界不符'
  fi

  suite_summary 'ticket-run'
}
