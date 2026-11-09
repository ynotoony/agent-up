#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite lane-commit "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）




# ============================================================
# suite: lane-commit（票 100 场景沉淀：微账本 actual 键——合同 actual 行落第七键、
# 不带 actual 行的既有六键行向后兼容（actual 落空串）；两段式全链经 git 夹具承载；
# 票 108 增补：.json 票体 user-review 全链正负例——t_stem 剥 .json、checkpoint 落独立
# md（创建＋已存在追加两形态）、正文 Status 回写跳过、JSON 票体零追加、flips id 不符
# fail-closed；票 144 增补：写入面路径边界——whitelist/flips/ticket 的 ..、绝对路径、
# symlink 指向仓外（realpath containment）、仓内 symlink 自身四类负例写入前 exit 1，
# 仓外哨兵与仓库工作树指纹负例前后全等（AC3），symlink 在场语境合法相对路径全链零回归；
# 票 228 增补：索引翻转改调同目录 ticket-ops.sh flip-index 代理（写入方收敛）——P-json
# 全链断言护航代理路径（索引单写＋投影再生经 ticket-ops 承载），代理不在场收尾预检
# 停止零提交零写入负例；票 229 增补：micro/user-review 通用 flips 直写索引及仓内
# 父目录 symlink 索引别名均预检拒绝）；票 247 增补：记录提交前缀门 `--record-commit`
# 单点入口——同锁串行（共享 246 锁）、中间插入/部分暂存/混提 fail-closed 零提交、
# 尾部追加提交文件集恰为记录路径、成功后 check-append-only 同源通过、README 登记）
# ============================================================

lc_git_commit() {
  # $1=夹具仓根：全量暂存并提交（本地身份经 -c 内联，零全局污染）
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm fixture
}

lc_build_fixture() {
  # $1=夹具仓根：git 仓＋lane-commit/check-gates 落位 rules/implementation/scripts/
  # ＋微账本基线行＋白名单文件（票 113 波④：微账本 facts/project/micro.jsonl，道脚本
  # 三件落位 rules/implementation/scripts/ 同目录定位语义）
  R=$1
  rm -rf "$R"
  mkdir -p "$R/rules/implementation/scripts" "$R/facts/project"
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/generate-dir-readmes.sh" "$SCRIPT_DIR/dir-readme.rules" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/checkpoint-write.sh" "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/record-store.sh" "$SCRIPT_DIR/ticket-audit.sh" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/workspace-snapshot.sh" "$SCRIPT_DIR/ledger-row-families.sh" "$R/rules/implementation/scripts/"
  # 分片化后同目录闭包：门禁函数库＋审计谓词注册表与分片
  cp "$SCRIPT_DIR/ticket-gates.sh" "$SCRIPT_DIR/audit-predicates.rules" "$SCRIPT_DIR/audit-p01-receipt-parseable.sh" "$SCRIPT_DIR/audit-p02-evidence-committed.sh" "$SCRIPT_DIR/audit-p03-base-sha-present.sh" "$SCRIPT_DIR/audit-p04-review-boundary-clean.sh" "$SCRIPT_DIR/audit-p05-diff-sha-bound.sh" "$SCRIPT_DIR/audit-p06-reviewer-identity-present.sh" "$SCRIPT_DIR/audit-p07-reviewer-identity-corroborated.sh" "$SCRIPT_DIR/audit-p08-reviewer-distinct-from-implementer.sh" "$SCRIPT_DIR/audit-p09-reviewed-at-valid.sh" "$SCRIPT_DIR/audit-p10-acceptance-results-present.sh" "$SCRIPT_DIR/audit-p11-policy-applicable.sh" "$R/rules/implementation/scripts/"
  test_copy_closure "$SCRIPT_DIR" "$R/rules/implementation/scripts" generate-progress.sh generate-dir-readmes.sh json-validator.py common-helpers.sh check-gates.sh ledger-append.sh
  printf '{"date": "2026-09-28", "lane": "micro", "whitelist": "seed.txt", "gates": "PASS", "verify": 1, "commit": "seed", "actual": ""}\n' > "$R/facts/project/micro.jsonl"
  printf 'seed\n' > "$R/a.txt"
  git_repo "$R"
  lc_git_commit "$R"
  printf 'change\n' > "$R/a.txt"
}

lc_contract() {
  # $1=合同文件路径 $2=actual 行内容（空串＝不带 actual 行，向后兼容形态）
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt\n'
    printf 'message: fixture micro commit\n'
    printf 'verify: true\n'
    if [ -n "$2" ]; then
      printf 'actual: %s\n' "$2"
    fi
  } > "$1"
}

lc_json_docs() {
  # $1=夹具仓根：.json 票全链三载体（最小 JSON 票体＋索引一条目一行＋issues-README 状态行；
  # 票 108）＋票 237 证据门夹具（task actual_time＋审计策略——策略 baseline 取当前 seed
  # 提交，供 done 证据门在 lane-commit 全链正例中判 conformant）
  mkdir -p "$1/facts/requirements/tickets"
  _lcd_seed=$(git -C "$1" rev-parse HEAD)
  cat > "$1/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "33-lc-ticket", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-29T10:00"}
  ]
}
EOF
  cat > "$1/facts/requirements/tickets/33-lc-ticket.json" <<'EOF'
{
  "id": "33-lc-ticket",
  "kind": "task",
  "title": "fixture json ticket",
  "created_at": "2026-09-29",
  "actual_time": "1h（fixture 净工时占位）"
}
EOF
  printf '{"schema_version":1,"policy_id":"lane-fixture","effective_from":"2026-01-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["fixture@example.com"]}\n' \
    "$_lcd_seed" > "$1/facts/requirements/audit-policy.json"
  cat > "$1/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `33-lc-ticket.json` | 任务票 33；`in_progress`（2026-09-29 开票） | LC json fixture |
EOF
}

lc_audit_receipt() {
  # $1=夹具根 $2=base $3=head：审查收据经 harness 世界构建动词 receipt 落位（世界构建缝隙票）
  receipt "$1/facts/requirements/tickets/33-lc-ticket.review-evidence.json" "$1" "$2" "$3" 33-lc-ticket --ac-evidence 'a.txt:1'
}

tix_lc_status() {
  # $1=夹具根：33-lc-ticket 索引状态提取（一条目一行）
  sed -n 's/.*"id": "33-lc-ticket", "status": "\([a-z_]*\)".*/\1/p' "$1/facts/requirements/tickets/index.json"
}

lc_impl_commit() {
  # $1=夹具根 $2=提交信息：以实现者身份提交工作树（产品提交，供审查证据绑定 head）
  git -C "$1" add -A
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.com \
    GIT_AUTHOR_DATE="$(date -u +%Y-%m-%dT00:00:00Z)" \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.com \
    GIT_COMMITTER_DATE="$(date -u +%Y-%m-%dT00:00:00Z)" \
    git -C "$1" -c commit.gpgsign=false commit -qm "$2"
}

suite_lane_commit() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='lane-commit'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/lc
  mkdir -p "$D"
  LC="$SCRIPT_DIR/lane-commit.sh"

  # check-gates 直接入口和 verify-contract 执行器空验证闸门（票 183）。
  lc_build_fixture "$D/gates-direct"
  cat > "$D/gates-empty.gates" <<'EOF'
whitelist: a.txt
EOF
  sh "$SCRIPT_DIR/check-gates.sh" "$D/gates-direct" "$D/gates-empty.gates" >"$D/gates-empty.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '至少需要一条 verify' "$D/gates-empty.out"; then
    ok '负例 183-G check-gates 普通快道缺 verify → exit 2'
  else
    bad '负例 183-G check-gates 普通快道缺 verify → exit 2' "exit=$rc $(tail -n 2 "$D/gates-empty.out" | tr '\n' '|')"
  fi
  cat > "$D/gates-record.gates" <<'EOF'
whitelist: a.txt
record-only: 更新纯记录索引
verify: N/A
EOF
  sh "$SCRIPT_DIR/check-gates.sh" "$D/gates-direct" "$D/gates-record.gates" >"$D/gates-record.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '纯记录例外' "$D/gates-record.out"; then
    ok '正例 183-H check-gates record-only + N/A → exit 0'
  else
    bad '正例 183-H check-gates record-only + N/A → exit 0' "exit=$rc $(tail -n 2 "$D/gates-record.out" | tr '\n' '|')"
  fi
  cat > "$D/gates-unmarked-na.gates" <<'EOF'
whitelist: a.txt
verify: N/A
EOF
  sh "$SCRIPT_DIR/check-gates.sh" "$D/gates-direct" "$D/gates-unmarked-na.gates" >"$D/gates-unmarked-na.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'N/A' "$D/gates-unmarked-na.out"; then
    ok '负例 183-H2 verify N/A 缺 record-only → exit 2'
  else
    bad '负例 183-H2 verify N/A 缺 record-only → exit 2' "exit=$rc $(tail -n 2 "$D/gates-unmarked-na.out" | tr '\n' '|')"
  fi
  lc_build_fixture "$D/gate-na-argument"
  printf 'N/A\n' > "$D/gate-na-argument/README.md"
  cat > "$D/gate-na-argument.gates" <<'EOF'
whitelist: a.txt,README.md
verify: grep -q N/A README.md
EOF
  sh "$SCRIPT_DIR/check-gates.sh" "$D/gate-na-argument" "$D/gate-na-argument.gates" >"$D/gate-na-argument.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -Fq 'PASS: verify[1] exit=0 grep -q N/A README.md' "$D/gate-na-argument.out"; then
    ok '正例 183-H3 普通 verify 命令参数含 N/A → 完整命令执行通过'
  else
    bad '正例 183-H3 普通 verify 命令参数含 N/A → 完整命令执行通过' "exit=$rc $(tail -n 3 "$D/gate-na-argument.out" | tr '\n' '|')"
  fi

  mkdir -p "$D/verify-contract"
  cat > "$D/verify-contract/empty.json" <<'EOF'
{"verification": []}
EOF
  sh "$SCRIPT_DIR/verify-contract.sh" "$D/verify-contract/empty.json" >"$D/verify-contract/empty.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '禁止空 verification' "$D/verify-contract/empty.out"; then
    ok '负例 183-I verify-contract 普通任务空数组 → exit 1'
  else
    bad '负例 183-I verify-contract 普通任务空数组 → exit 1' "exit=$rc $(tail -n 2 "$D/verify-contract/empty.out" | tr '\n' '|')"
  fi
  cat > "$D/verify-contract/record.json" <<'EOF'
{"record_only":{"reason":"登记事实"},"verification":"N/A"}
EOF
  sh "$SCRIPT_DIR/verify-contract.sh" "$D/verify-contract/record.json" >"$D/verify-contract/record.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '纯记录例外' "$D/verify-contract/record.out"; then
    ok '正例 183-J verify-contract 显式纯记录例外 → exit 0'
  else
    bad '正例 183-J verify-contract 显式纯记录例外 → exit 0' "exit=$rc $(tail -n 2 "$D/verify-contract/record.out" | tr '\n' '|')"
  fi
  cat > "$D/verify-contract/legacy-array.json" <<'EOF'
{"verification":["旧式散文谓词"]}
EOF
  sh "$SCRIPT_DIR/verify-contract.sh" "$D/verify-contract/legacy-array.json" >"$D/verify-contract/legacy-array.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '字符串数组是散文谓词' "$D/verify-contract/legacy-array.out"; then
    ok '负例 183-N verify-contract 识别 legacy 字符串数组并拒绝执行'
  else
    bad '负例 183-N verify-contract 识别 legacy 字符串数组并拒绝执行' "exit=$rc $(tail -n 2 "$D/verify-contract/legacy-array.out" | tr '\n' '|')"
  fi
  cat > "$D/verify-contract/unsupported-check-any.json" <<'EOF'
{"verification":[{"name":"x","check_any":[{"command":"true","description":"unsupported"}],"expect":"ok"}]}
EOF
  sh "$SCRIPT_DIR/verify-contract.sh" "$D/verify-contract/unsupported-check-any.json" >"$D/verify-contract/unsupported-check-any.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '未知字段' "$D/verify-contract/unsupported-check-any.out"; then
    ok '负例 183-Q verify-contract 拒绝未实现的 check_any'
  else
    bad '负例 183-Q verify-contract 拒绝未实现的 check_any' "exit=$rc $(tail -n 2 "$D/verify-contract/unsupported-check-any.out" | tr '\n' '|')"
  fi
  cat > "$D/verify-contract/bad-record-only.json" <<'EOF'
{"record_only":{"reason":"登记事实","extra":"bad"},"verification":"N/A"}
EOF
  sh "$SCRIPT_DIR/verify-contract.sh" "$D/verify-contract/bad-record-only.json" >"$D/verify-contract/bad-record-only.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'record_only 必须恰为' "$D/verify-contract/bad-record-only.out"; then
    ok '负例 183-O verify-contract record_only 未知字段 → FAIL'
  else
    bad '负例 183-O verify-contract record_only 未知字段 → FAIL' "exit=$rc $(tail -n 2 "$D/verify-contract/bad-record-only.out" | tr '\n' '|')"
  fi

  # 票 183：普通快道缺验证必须失败；纯记录例外必须显式 record-only + N/A；
  # N/A 不得与真实命令混用。三例均在产品提交前拒绝/通过，锁住空验证不再静默 PASS。
  lc_build_fixture "$D/gate-empty"
  {
    printf 'lane: micro\nwhitelist: a.txt\nmessage: missing verify\n'
  } > "$D/gate-empty.contract"
  sh "$LC" "$D/gate-empty" "$D/gate-empty.contract" >"$D/gate-empty.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '至少需要一条 verify' "$D/gate-empty.out" && [ "$(git -C "$D/gate-empty" rev-list --count HEAD)" -eq 1 ]; then
    ok '负例 183-A 普通快道缺 verify → exit 1 且零提交'
  else
    bad '负例 183-A 普通快道缺 verify → exit 1 且零提交' "exit=$rc $(tail -n 2 "$D/gate-empty.out" | tr '\n' '|')"
  fi

  # 票 183：validator 对象谓词的 scope 等数、expect/expect_exit 互斥和混合数组。
  VTEST="$D/validator"
  mkdir -p "$VTEST"
  cat > "$VTEST/base.json" <<'EOF'
{"id":"99-validator","kind":"task","title":"validator","created_at":"2026-10-20","complexity":"C1","profile":"D:Required,B:N/A,I:N/A,U:N/A,S:N/A,M:N/A,O:N/A","blocked_by":[],"complexity_reason":"x","priority_reason":"x","scope":["a","b"],"verification":[{"name":"a","check":"true","expect":"ok"},{"name":"b","check":"true","expect_exit":0}]}
EOF
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/base.json" >/dev/null 2>&1; then
    ok '正例 183-D validator 对象谓词 expect/expect_exit 二选一且 scope 等数 → PASS'
  else
    bad '正例 183-D validator 对象谓词 expect/expect_exit 二选一且 scope 等数 → PASS'
  fi
  sed 's/"scope":\["a","b"\]/"scope":["a"]/' "$VTEST/base.json" > "$VTEST/mismatch.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/mismatch.json" >/dev/null 2>&1; then
    ok '正例 183-K 默认校验不追溯拒绝既有票 Scope 数量差异'
  else
    bad '正例 183-K 默认校验不追溯拒绝既有票 Scope 数量差异'
  fi
  sed 's/"verification":\[{"name":"a","check":"true","expect":"ok"},{"name":"b","check":"true","expect_exit":0}\]/"verification":["legacy predicate"]/' "$VTEST/base.json" > "$VTEST/legacy-ticket.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/legacy-ticket.json" >/dev/null 2>&1; then
    ok '正例 183-P 存量 legacy 字符串 verification 仍可读取'
  else
    bad '正例 183-P 存量 legacy 字符串 verification 仍可读取'
  fi
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/mismatch.json" --new-ticket >/dev/null 2>&1; then
    bad '负例 183-E validator scope/verification 数量不一致 → FAIL'
  else
    ok '负例 183-E validator scope/verification 数量不一致 → FAIL'
  fi
  sed 's/"expect_exit":0/"expect":"ok","expect_exit":0/' "$VTEST/base.json" > "$VTEST/both.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/both.json" >/dev/null 2>&1; then
    bad '负例 183-F validator expect 与 expect_exit 同时存在 → FAIL'
  else
    ok '负例 183-F validator expect 与 expect_exit 同时存在 → FAIL'
  fi
  sed 's/"check":"true"/"check_any":[{"command":"true","description":"unsupported"}]/' "$VTEST/base.json" > "$VTEST/check-any.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/check-any.json" >/dev/null 2>&1; then
    bad '负例 183-L schema/validator 拒绝未实现的 check_any'
  else
    ok '负例 183-L schema/validator 拒绝未实现的 check_any'
  fi
  python3 - "$VTEST/base.json" "$VTEST/missing-verification.json" "$VTEST/legacy-string.json" "$VTEST/legacy-array-new.json" "$VTEST/bad-scope-item.json" "$VTEST/blank-scope-item.json" "$VTEST/null-record-only.json" "$VTEST/blank-legacy-array.json" <<'PYTHON'
import json, sys
base = json.load(open(sys.argv[1], encoding='utf-8'))
missing = dict(base)
missing.pop('verification')
legacy = dict(base)
legacy['verification'] = 'legacy prose'
legacy_array = dict(base)
legacy_array['verification'] = ['legacy prose']
bad_scope = dict(base)
bad_scope['scope'] = [123, 'b']
blank_scope = dict(base)
blank_scope['scope'] = [' \t ', 'b']
null_record = dict(base)
null_record['record_only'] = None
blank_legacy_array = dict(base)
blank_legacy_array['verification'] = [' \t ']
for path, value in zip(sys.argv[2:], (missing, legacy, legacy_array, bad_scope, blank_scope, null_record, blank_legacy_array)):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(value, f)
PYTHON
  for case in missing-verification legacy-string legacy-array-new bad-scope-item blank-scope-item null-record-only; do
    if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/$case.json" --new-ticket >/dev/null 2>&1; then
      bad "负例 183-T-$case 新 task 票校验拒绝缺失或错误形态"
    else
      ok "负例 183-T-$case 新 task 票校验拒绝缺失或错误形态"
    fi
  done
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/blank-legacy-array.json" >/dev/null 2>&1; then
    bad '负例 183-T-blank-legacy-array schema/runtime 均拒绝纯空白存量谓词'
  else
    ok '负例 183-T-blank-legacy-array schema/runtime 均拒绝纯空白存量谓词'
  fi
  if python3 - "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" <<'PYTHON'
import json, sys
schema = json.load(open(sys.argv[1], encoding='utf-8'))
props = schema['properties']
verification = props['verification']['oneOf']
legacy = next(s for s in verification if s.get('type') == 'array' and s['items'].get('type') == 'string')
structured = next(s for s in verification if s.get('type') == 'array' and s['items'].get('type') == 'object')
fields = structured['items']['properties']
blank_pattern = r'[^\t\n\v\f\r \u001c-\u001f\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]'
checks = [
    props['scope']['items'].get('pattern') == blank_pattern,
    legacy['items'].get('pattern') == blank_pattern,
    all(fields[name].get('pattern') == blank_pattern for name in ('name', 'check', 'expect')),
    props['record_only']['properties']['reason'].get('pattern') == blank_pattern,
]
if all(checks):
    raise SystemExit(0)
raise SystemExit(1)
PYTHON
  then
    ok '正例 183-U schema Draft-07 空白字段约束与 runtime 覆盖一致'
  else
    bad '正例 183-U schema Draft-07 空白字段约束与 runtime 覆盖一致'
  fi
  python3 - "$VTEST/base.json" "$VTEST/blank-name.json" "$VTEST/blank-check.json" "$VTEST/blank-expect.json" "$VTEST/blank-record-only.json" "$VTEST/blank-expect-ecma.json" "$VTEST/blank-expect-python.json" <<'PYTHON'
import json, sys
base = json.load(open(sys.argv[1], encoding='utf-8'))
cases = []
for key, value in (('name', '   '), ('check', ' \t '), ('expect', '\n')):
    item = dict(base)
    item['verification'][0][key] = value
    cases.append(item)
record_only = dict(base)
record_only['record_only'] = {'reason': '   '}
record_only['verification'] = 'N/A'
cases.append(record_only)
for char in ('\ufeff', '\u0085', '\u001c'):
    item = dict(base)
    item['verification'][0]['expect'] = char
    cases.append(item)
for path, value in zip(sys.argv[2:], cases):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(value, f)
PYTHON
  for case in blank-name blank-check blank-expect blank-record-only blank-expect-ecma blank-expect-python; do
    if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/$case.json" --new-ticket >/dev/null 2>&1; then
      bad "负例 183-U-$case 拒绝纯空白验收字段"
    else
      ok "负例 183-U-$case 拒绝纯空白验收字段"
    fi
  done
  # 票 268：kind=task 新票必备 user_stories（用户故事）——validator --new-ticket
  # 正负例；读取面（不传 --new-ticket）不要求该字段（存量兼容分层）；schema 单源
  # 数组 minItems=1 且条目 pattern 锁定「US<n>: 作为…，我要…，以便…」。
  US268="$VTEST/us268"
  mkdir -p "$US268"
  cat > "$US268/base.json" <<'EOF'
{"id":"99-us","kind":"task","title":"us","created_at":"2026-11-04","complexity":"C1","profile":"D:Required,B:N/A,I:N/A,U:N/A,S:N/A,M:N/A,O:N/A","profile_reason":{"D":"d","B":"b","I":"i","U":"u","S":"s","M":"m","O":"o"},"blocked_by":[],"complexity_reason":"x","priority_reason":"x","scope":["a"],"verification":[{"name":"a","check":"true","expect_exit":0}],"user_stories":["US1: 作为需求提出者，我要新卡写清用户故事，以便实施围绕用户价值"]}
EOF
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$US268/base.json" --new-ticket >/dev/null 2>&1; then
    ok '正例 268 validator 新 task user_stories 合规条目 --new-ticket → PASS'
  else
    bad '正例 268 validator 新 task user_stories 合规条目 --new-ticket → PASS'
  fi
  python3 - "$US268" <<'PYTHON'
import json, os, sys
d = sys.argv[1]
base = json.load(open(os.path.join(d, 'base.json'), encoding='utf-8'))
cases = {}
missing = dict(base); missing.pop('user_stories'); cases['missing'] = missing
empty = dict(base); empty['user_stories'] = []; cases['empty'] = empty
malformed = dict(base); malformed['user_stories'] = ['用户需要用户故事']; cases['malformed'] = malformed
not_array = dict(base); not_array['user_stories'] = 'US1: 作为需求提出者，我要字符串，以便拒收'; cases['not-array'] = not_array
for name, value in cases.items():
    with open(os.path.join(d, name + '.json'), 'w', encoding='utf-8') as f:
        json.dump(value, f, ensure_ascii=False)
PYTHON
  for case in missing empty malformed not-array; do
    if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$US268/$case.json" --new-ticket >/dev/null 2>&1; then
      bad "负例 268 validator 新 task user_stories $case → FAIL"
    else
      ok "负例 268 validator 新 task user_stories $case → FAIL"
    fi
  done
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$US268/missing.json" >/dev/null 2>&1; then
    ok '正例 268 存量票无 user_stories 读取面不要求（开票/读取校验分层）'
  else
    bad '正例 268 存量票无 user_stories 读取面不要求（开票/读取校验分层）'
  fi
  if python3 - "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" <<'PYTHON'
import json, sys
us = json.load(open(sys.argv[1], encoding='utf-8'))['properties']['user_stories']
assert us['type'] == 'array' and us['minItems'] == 1
assert us['items']['type'] == 'string'
assert us['items']['pattern'] == r'^US[0-9]+: 作为.+，我要.+，以便.+$'
PYTHON
  then
    ok '正例 268 schema user_stories 数组至少一条＋条目 pattern 单源锁定'
  else
    bad '正例 268 schema user_stories 数组至少一条＋条目 pattern 单源锁定'
  fi

  sed 's/"verification":\[/"record_only":{"reason":"record","unexpected":true},"verification":\[/' "$VTEST/base.json" > "$VTEST/bad-record-only.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/bad-record-only.json" >/dev/null 2>&1; then
    bad '负例 183-M record_only 含未知字段 → FAIL'
  else
    ok '负例 183-M record_only 含未知字段 → FAIL'
  fi
  python3 - "$VTEST/base.json" "$VTEST/record-only-with-real-verification.json" "$VTEST/na-without-record-only.json" <<'PYTHON'
import json, sys
base = json.load(open(sys.argv[1], encoding='utf-8'))
with_real = dict(base)
with_real['record_only'] = {'reason': '登记事实'}
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    json.dump(with_real, f)
without_record = dict(base)
without_record['verification'] = 'N/A'
with open(sys.argv[3], 'w', encoding='utf-8') as f:
    json.dump(without_record, f)
PYTHON
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/record-only-with-real-verification.json" >/dev/null 2>&1; then
    bad '负例 183-R record_only + 真实 verification → FAIL'
  else
    ok '负例 183-R record_only + 真实 verification → FAIL'
  fi
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$VTEST/na-without-record-only.json" >/dev/null 2>&1; then
    bad '负例 183-S verification N/A 缺 record_only → FAIL'
  else
    ok '负例 183-S verification N/A 缺 record_only → FAIL'
  fi

  lc_build_fixture "$D/gate-record"
  {
    printf 'lane: micro\nwhitelist: a.txt\nmessage: record-only\nrecord-only: 仅登记事实\nverify: N/A\n'
  } > "$D/gate-record.contract"
  sh "$LC" "$D/gate-record" "$D/gate-record.contract" >"$D/gate-record.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '纯记录例外' "$D/gate-record.out"; then
    ok '正例 183-B record-only + verify N/A → exit 0 且显式记录例外'
  else
    bad '正例 183-B record-only + verify N/A → exit 0 且显式记录例外' "exit=$rc $(tail -n 3 "$D/gate-record.out" | tr '\n' '|')"
  fi

  lc_build_fixture "$D/gate-mixed"
  {
    printf 'lane: micro\nwhitelist: a.txt\nmessage: mixed verify\nrecord-only: 不能混用\nverify: true\nverify: N/A\n'
  } > "$D/gate-mixed.contract"
  sh "$LC" "$D/gate-mixed" "$D/gate-mixed.contract" >"$D/gate-mixed.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不能同时携带真实 verify' "$D/gate-mixed.out" && [ "$(git -C "$D/gate-mixed" rev-list --count HEAD)" -eq 1 ]; then
    ok '负例 183-C record-only 混用真实 verify → exit 1 且零提交'
  else
    bad '负例 183-C record-only 混用真实 verify → exit 1 且零提交' "exit=$rc $(tail -n 2 "$D/gate-mixed.out" | tr '\n' '|')"
  fi

  # 正例 P1：合同带 actual 行 → exit 0 且微账本第七键 actual 落值（票 100 决策 3）
  lc_build_fixture "$D/p1"
  lc_contract "$D/p1.contract" '45m（fixture 净工时占位）'
  sh "$LC" "$D/p1" "$D/p1.contract" >"$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"actual": "45m（fixture 净工时占位）"' "$D/p1/facts/project/micro.jsonl"; then
    ok '正例 P1 micro 合同带 actual 行 → exit 0 且微账本 actual 键落值（票 100）'
  else
    bad '正例 P1 micro 合同带 actual 行 → exit 0 且微账本 actual 键落值（票 100）' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P2：合同不带 actual 行 → exit 0 且 actual 落空串（既有六键行向后兼容，键序不变）
  lc_build_fixture "$D/p2"
  lc_contract "$D/p2.contract" ''
  sh "$LC" "$D/p2" "$D/p2.contract" >"$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"commit": "[0-9a-f]\{7,\}", "actual": ""}' "$D/p2/facts/project/micro.jsonl"; then
    ok '正例 P2 micro 合同不带 actual 行 → exit 0 且 actual 落空串（既有六键行向后兼容，票 100）'
  else
    bad '正例 P2 micro 合同不带 actual 行 → exit 0 且 actual 落空串（既有六键行向后兼容，票 100）' "exit=$rc $(tail -n 3 "$D/p2.out" | tr '\n' '|')"
  fi

  # 负例 N1：actual 行重复 → exit 1 零提交零写入（合同格式错误）
  lc_build_fixture "$D/n1"
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt\n'
    printf 'message: dup actual\n'
    printf 'verify: true\n'
    printf 'actual: 1h\n'
    printf 'actual: 2h\n'
  } > "$D/n1.contract"
  sh "$LC" "$D/n1" "$D/n1.contract" >"$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'actual 行重复' "$D/n1.out" && [ "$(git -C "$D/n1" rev-list --count HEAD)" -eq 1 ]; then
    ok '负例 N1 actual 行重复 → exit 1 零提交零写入（合同格式错误）'
  else
    bad '负例 N1 actual 行重复 → exit 1 零提交零写入（合同格式错误）' "exit=$rc $(tail -n 2 "$D/n1.out" | tr '\n' '|')"
  fi

  # 负例 N2：user-review 道携带 actual 行 → exit 1（user-review 用时落票本体 actual_time）
  lc_build_fixture "$D/n2"
  mkdir -p "$D/n2/facts/requirements/tickets"
  printf '{"id": "33-lc-ticket", "status": "in_progress"}\n' > "$D/n2/facts/requirements/tickets/index.json"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '# 票\n\n**Status:** `in_progress`\n' > "$D/n2/facts/requirements/tickets/33-lc-ticket.md"
  lc_git_commit "$D/n2"
  printf 'change2\n' > "$D/n2/a.txt"
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.md\n'
    printf 'whitelist: a.txt\n'
    printf 'message: ur with actual\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-09-29T12:00\n'
    printf 'actual: 1h\n'
  } > "$D/n2.contract"
  sh "$LC" "$D/n2" "$D/n2.contract" >"$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'user-review 道不得携带 actual 行' "$D/n2.out"; then
    ok '负例 N2 user-review 道携带 actual 行 → exit 1（用时落票本体 actual_time，票 100）'
  else
    bad '负例 N2 user-review 道携带 actual 行 → exit 1（用时落票本体 actual_time，票 100）' "exit=$rc $(tail -n 2 "$D/n2.out" | tr '\n' '|')"
  fi

  # 负例 N3：actual 行含制表符 → exit 1（JSON 行安全）
  lc_build_fixture "$D/n3"
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt\n'
    printf 'message: tab in actual\n'
    printf 'verify: true\n'
    printf 'actual: 1h\tbad\n'
  } > "$D/n3.contract"
  sh "$LC" "$D/n3" "$D/n3.contract" >"$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'actual 行不得含制表符' "$D/n3.out"; then
    ok '负例 N3 actual 行含制表符 → exit 1（JSON 行安全）'
  else
    bad '负例 N3 actual 行含制表符 → exit 1（JSON 行安全）' "exit=$rc $(tail -n 2 "$D/n3.out" | tr '\n' '|')"
  fi

  # ---- 票 282：微道白名单条目计数按换行条目（含空格路径不被误拒）----
  # 正例：3 条目其中一条含空格——按词计数会数成 4 词误拒；按换行条目计数应放行。
  lc_build_fixture "$D/sp"
  printf 'b\n' > "$D/sp/b.txt"
  printf 'c\n' > "$D/sp/c d.txt"
  lc_git_commit "$D/sp"
  sp_n0=$(git -C "$D/sp" rev-list --count HEAD)
  printf 'change-sp-a\n' >> "$D/sp/a.txt"
  printf 'change-sp-b\n' >> "$D/sp/b.txt"
  # 空格路径条目保持未改动：本票回归点是「条目计数不按词数误拒」（旧 wc -w 会数成 4 而拒）；
  # 若空格路径本身进入改动集，git status 的引号行会被 check-gates 拒（独立限制，见 README 专节）。
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt,b.txt,c d.txt\n'
    printf 'message: fixture micro space path\n'
    printf 'verify: true\n'
  } > "$D/sp.contract"
  sh "$LC" "$D/sp" "$D/sp.contract" >"$D/sp.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(git -C "$D/sp" rev-list --count HEAD)" -eq "$((sp_n0 + 2))" ]; then
    ok '正例 P-282 微道 3 条目含空格路径（条目未改动）→ exit 0 两段式收口（条目按换行计，不按词计数，票 282）'
  else
    bad '正例 P-282 微道 3 条目含空格路径（条目未改动）→ exit 0 两段式收口（条目按换行计，不按词计数，票 282）' "exit=$rc $(tail -n 2 "$D/sp.out" | tr '\n' '|')"
  fi

  # 负例：4 条目（含一条空格路径）→ 条目数 4 > 3 拒收，报文指名条目数且不落任何提交。
  lc_build_fixture "$D/sp4"
  printf 'b\n' > "$D/sp4/b.txt"
  printf 'c\n' > "$D/sp4/c d.txt"
  printf 'd\n' > "$D/sp4/e.txt"
  lc_git_commit "$D/sp4"
  sp4_n0=$(git -C "$D/sp4" rev-list --count HEAD)
  printf 'chg-a\n' >> "$D/sp4/a.txt"
  printf 'chg-b\n' >> "$D/sp4/b.txt"
  printf 'chg-c\n' >> "$D/sp4/c d.txt"
  printf 'chg-e\n' >> "$D/sp4/e.txt"
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt,b.txt,c d.txt,e.txt\n'
    printf 'message: fixture micro four entries\n'
    printf 'verify: true\n'
  } > "$D/sp4.contract"
  sh "$LC" "$D/sp4" "$D/sp4.contract" >"$D/sp4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '白名单条目 4 个' "$D/sp4.out" \
    && [ "$(git -C "$D/sp4" rev-list --count HEAD)" -eq "$sp4_n0" ]; then
    ok '负例 N-282 微道 4 条目（含空格路径）→ exit 1 指名条目数且零提交（条数按换行计，仍 fail-closed）'
  else
    bad '负例 N-282 微道 4 条目（含空格路径）→ exit 1 指名条目数且零提交（条数按换行计，仍 fail-closed）' "exit=$rc $(tail -n 2 "$D/sp4.out" | tr '\n' '|')"
  fi

  # ---- 票 282 F1：通用 flip（非索引文件）落盘值必须等于合同 value ----
  # 回归钉死「f_rest 被误清空 → 替换值恒空」的静默数据清空：锚点行须原样被 value 取代。
  lc_build_fixture "$D/gf"
  mkdir -p "$D/gf/facts/notes"
  printf 'OLD-MARK\nother\n' > "$D/gf/facts/notes/n.md"
  lc_git_commit "$D/gf"
  printf 'change-gf\n' >> "$D/gf/a.txt"
  gf_n0=$(git -C "$D/gf" rev-list --count HEAD)
  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt,facts/notes/n.md\n'
    printf 'message: fixture generic flip value\n'
    printf 'verify: true\n'
    printf 'flips: facts/notes/n.md:OLD-MARK:NEW-MARK\n'
  } > "$D/gf.contract"
  sh "$LC" "$D/gf" "$D/gf.contract" >"$D/gf.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(git -C "$D/gf" rev-list --count HEAD)" -eq "$((gf_n0 + 2))" ] \
    && [ "$(sed -n '1p' "$D/gf/facts/notes/n.md")" = 'NEW-MARK' ] \
    && ! grep -q 'OLD-MARK' "$D/gf/facts/notes/n.md" \
    && [ "$(git -C "$D/gf" show HEAD:facts/notes/n.md | sed -n '1p')" = 'NEW-MARK' ] \
    && [ "$(git -C "$D/gf" show HEAD~1:facts/notes/n.md | sed -n '1p')" = 'OLD-MARK' ]; then
    ok '正例 P-282-F1 通用 flip 落盘值＝合同 value（工作树与记录提交为 NEW-MARK，产品提交仍为 OLD-MARK：翻转属记录面后置写）'
  else
    bad '正例 P-282-F1 通用 flip 落盘值＝合同 value（工作树与记录提交为 NEW-MARK，产品提交仍为 OLD-MARK：翻转属记录面后置写）' \
      "exit=$rc 行1=[$(sed -n '1p' "$D/gf/facts/notes/n.md" 2>/dev/null)] 提交=$(git -C "$D/gf" rev-list --count HEAD 2>/dev/null)/$((gf_n0 + 2)) $(tail -n 2 "$D/gf.out" | tr '\n' '|')"
  fi

  # ---- 票 108 断言：user-review 道 .json 票体全链 ----
  # 正例 P-json：.json 票 user-review 全链收口（索引翻转 done＋README 票表生成块随索引派生＋
  # checkpoint 落独立 facts/requirements/tickets/33-lc-ticket-review-checkpoint.md＋正文
  # Status 回写跳过说明行＋投影再生）→ exit 0；JSON 票体逐字节零追加（前后 cksum）；
  # 记录提交落地（checkpoint md 入第二段提交）。预期值独立重建。
  lc_build_fixture "$D/pj"
  lc_json_docs "$D/pj"
  lc_git_commit "$D/pj"
  pj_base=$(git -C "$D/pj" rev-parse HEAD)
  printf 'change-json\n' > "$D/pj/a.txt"
  lc_impl_commit "$D/pj" 'fixture json implementation change'
  pj_impl=$(git -C "$D/pj" rev-parse HEAD)
  lc_audit_receipt "$D/pj" "$pj_base" "$pj_impl"
  git -C "$D/pj" config user.email reviewer@example.com
  git -C "$D/pj" config user.name reviewer
  pj_ck0=$(cksum "$D/pj/facts/requirements/tickets/33-lc-ticket.json")
  pj_n0=$(git -C "$D/pj" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: facts/requirements/tickets/33-lc-ticket.review-evidence.json\n'
    printf 'message: fixture json ur commit\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（fixture json 全链裁决）\n'
    printf 'verdict_at: 2026-09-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-09-30T12:00\n'
    # README 票表为索引派生生成块（票 277 起）：不再注入通用行翻转，状态随 flip-index 重算
  } > "$D/pj.contract"
  sh "$LC" "$D/pj" "$D/pj.contract" >"$D/pj.out" 2>&1
  rc=$?
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  if [ "$rc" -eq 0 ] \
    && grep -q '"id": "33-lc-ticket", "status": "done"' "$D/pj/facts/requirements/tickets/index.json" \
    && grep -q '任务票 33；`done`' "$D/pj/facts/requirements/tickets/README.md" \
    && grep -q '| 33-lc-ticket | done |' "$D/pj/facts/requirements/tickets/progress-current.md" \
    && grep -q '索引翻转已代理' "$D/pj.out" \
    && grep -q 'ticket-ops: 证据门: flip-index 放行' "$D/pj.out" \
    && grep -q 'ticket-ops: PASS（flip-index 完成' "$D/pj.out" \
    && grep -q '目录 README 收口预检通过' "$D/pj.out" \
    && grep -q '跳过正文 Status 回写' "$D/pj.out"; then
    ok '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转（经 ticket-ops flip-index 代理，票 228）＋证据门 conformant＋README 票表生成块派生＋投影落行＋回写跳过说明行（票 108/237）'
  else
    bad '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转（经 ticket-ops flip-index 代理，票 228）＋证据门 conformant＋README 票表生成块派生＋投影落行＋回写跳过说明行（票 108/237）' "exit=$rc $(tail -n 3 "$D/pj.out" | tr '\n' '|')"
  fi

  if grep -q '^# 票 33-lc-ticket User Review Checkpoint（用户即 Review 道）$' "$D/pj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md" \
    && grep -q '^## User Review Checkpoint' "$D/pj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md" \
    && grep -q -- '- 裁决原文：OK（fixture json 全链裁决）' "$D/pj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md" \
    && [ "$(cksum "$D/pj/facts/requirements/tickets/33-lc-ticket.json")" = "$pj_ck0" ]; then
    ok '正例 P-json checkpoint 落独立 md（一级标题＋记录块）且 JSON 票体逐字节零追加（票 108）'
  else
    bad '正例 P-json checkpoint 落独立 md（一级标题＋记录块）且 JSON 票体逐字节零追加（票 108）' 'checkpoint md 形态或票体 cksum 不符'
  fi

  if [ "$(git -C "$D/pj" rev-list --count HEAD)" -eq "$((pj_n0 + 2))" ] \
    && [ "$(git -C "$D/pj" show --name-only --format= HEAD | grep -c 'facts/requirements/tickets/33-lc-ticket-review-checkpoint.md')" -eq 1 ]; then
    ok '正例 P-json 记录提交落地（第二段提交含独立 checkpoint md）'
  else
    bad '正例 P-json 记录提交落地（第二段提交含独立 checkpoint md）' "提交数=$(git -C "$D/pj" rev-list --count HEAD)（基线 ${pj_n0}）"
  fi

  # P-json 二次收口：checkpoint md 已存在 → 追加记录块（一级标题不重复），票体仍零追加。
  pj_base2=$(git -C "$D/pj" rev-parse HEAD)
  printf 'change-json2\n' > "$D/pj/a.txt"
  lc_impl_commit "$D/pj" 'fixture json implementation change 2'
  pj_impl2=$(git -C "$D/pj" rev-parse HEAD)
  lc_audit_receipt "$D/pj" "$pj_base2" "$pj_impl2"
  pj2_n0=$(git -C "$D/pj" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: facts/requirements/tickets/33-lc-ticket.review-evidence.json\n'
    printf 'message: fixture json ur commit 2\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（fixture json 二次裁决）\n'
    printf 'verdict_at: 2026-09-30T13:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-09-30T12:00\n'
  } > "$D/pj2.contract"
  sh "$LC" "$D/pj" "$D/pj2.contract" >"$D/pj2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(grep -c '^# 票 33-lc-ticket User Review Checkpoint' "$D/pj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md")" -eq 1 ] \
    && [ "$(grep -c '^## User Review Checkpoint' "$D/pj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md")" -eq 2 ] \
    && [ "$(cksum "$D/pj/facts/requirements/tickets/33-lc-ticket.json")" = "$pj_ck0" ] \
    && [ "$(git -C "$D/pj" rev-list --count HEAD)" -eq "$((pj2_n0 + 2))" ]; then
    ok '正例 P-json 二次收口 checkpoint md 已存在 → 追加记录块（标题恰 1 个、记录块 2 个）且票体仍零追加（票 108）'
  else
    bad '正例 P-json 二次收口 checkpoint md 已存在 → 追加记录块（标题恰 1 个、记录块 2 个）且票体仍零追加（票 108）' "exit=$rc $(tail -n 3 "$D/pj2.out" | tr '\n' '|')"
  fi

  # 负例：done 翻转遇目录 README 生成块结构漂移 → 收口 --check 阻断，产品提交已创建、
  # 记录提交未创建、代理 fail-closed exit 1。docs/ 须在基线提交内，避免审计判审查后改动。
  lc_build_fixture "$D/drg"
  lc_json_docs "$D/drg"
  mkdir -p "$D/drg/docs"
  cat > "$D/drg/docs/README.md" <<'EOF'
# docs

文档目录职责句。

## 权威
- 现行：无

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
<!-- /dir-readme -->
EOF
  lc_git_commit "$D/drg"
  drg_base=$(git -C "$D/drg" rev-parse HEAD)
  printf 'change-drg\n' > "$D/drg/a.txt"
  lc_impl_commit "$D/drg" 'fixture dir readme drift'
  drg_impl=$(git -C "$D/drg" rev-parse HEAD)
  lc_audit_receipt "$D/drg" "$drg_base" "$drg_impl"
  git -C "$D/drg" config user.email reviewer@example.com
  git -C "$D/drg" config user.name reviewer
  drg_n0=$(git -C "$D/drg" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: facts/requirements/tickets/33-lc-ticket.review-evidence.json\n'
    printf 'message: fixture dir readme drift\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（dir readme drift）\n'
    printf 'verdict_at: 2026-09-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-09-30T12:00\n'
  } > "$D/drg.contract"
  sh "$LC" "$D/drg" "$D/drg.contract" >"$D/drg.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'docs/README\.md:[0-9][0-9]*: 缺少段：## 读取禁忌' "$D/drg.out" \
    && grep -q '目录 README 结构校验未过' "$D/drg.out" \
    && grep -q '索引翻转代理未过' "$D/drg.out" \
    && [ "$(git -C "$D/drg" rev-list --count HEAD)" -eq "$((drg_n0 + 1))" ]; then
    ok 'AC1 快道 done 翻转遇目录 README 漂移 → exit 1 指名 file:line 且记录提交未创建'
  else
    bad 'AC1 快道 done 翻转遇目录 README 漂移 → exit 1 指名 file:line 且记录提交未创建' "exit=$rc commits=$(git -C "$D/drg" rev-list --count HEAD)/预期$((drg_n0 + 1)) $(tail -n 3 "$D/drg.out" | tr '\n' '|')"
  fi

  # ---- 票 237：lane-commit done 翻转前核审计结论（非 conformant 不得收尾）----
  # 负例：证据缺失 → flip-index 证据门 P01 拒，产品提交已创建、记录提交未创建、索引未 done。
  lc_build_fixture "$D/na1"
  lc_json_docs "$D/na1"
  lc_git_commit "$D/na1"
  printf 'change-audit\n' > "$D/na1/a.txt"
  lc_impl_commit "$D/na1" 'fixture audit negative change'
  printf 'lane-product\n' >> "$D/na1/a.txt"
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
    printf 'message: fixture audit missing evidence\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（fixture audit 负例裁决）\n'
    printf 'verdict_at: 2026-10-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-10-30T12:00\n'
  } > "$D/na1.contract"
  na1_n0=$(git -C "$D/na1" rev-list --count HEAD)
  sh "$LC" "$D/na1" "$D/na1.contract" >"$D/na1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'decision-required' "$D/na1.out" \
    && grep -q 'FAIL P01 receipt-parseable:' "$D/na1.out" \
    && grep -q '记录提交未创建' "$D/na1.out" \
    && [ "$(git -C "$D/na1" rev-list --count HEAD)" -eq "$((na1_n0 + 1))" ] \
    && [ "$(tix_lc_status "$D/na1")" = 'in_progress' ]; then
    ok '负例 N-237g lane-commit done 翻转缺证据 → exit 1 decision-required（产品提交已建、记录提交未建、索引未 done）'
  else
    bad '负例 N-237g lane-commit done 翻转缺证据 → exit 1 decision-required（产品提交已建、记录提交未建、索引未 done）' "exit=$rc $(tail -n 3 "$D/na1.out" | tr '\n' '|')"
  fi

  # 负例：有 conformant 证据但票本体缺 actual_time → actual_time 前置门先拒。
  lc_build_fixture "$D/na3"
  lc_json_docs "$D/na3"
  python3 - "$D/na3/facts/requirements/tickets/33-lc-ticket.json" <<'PY'
import json, sys
path = sys.argv[1]
body = json.load(open(path, encoding='utf-8'))
body.pop('actual_time', None)
with open(path, 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
PY
  lc_git_commit "$D/na3"
  na3_base=$(git -C "$D/na3" rev-parse HEAD)
  printf 'change-audit3\n' > "$D/na3/a.txt"
  lc_impl_commit "$D/na3" 'fixture audit no actual_time'
  na3_impl=$(git -C "$D/na3" rev-parse HEAD)
  lc_audit_receipt "$D/na3" "$na3_base" "$na3_impl"
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: facts/requirements/tickets/33-lc-ticket.review-evidence.json\n'
    printf 'message: fixture audit no actual_time\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（fixture audit actual_time 负例）\n'
    printf 'verdict_at: 2026-10-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-10-30T12:00\n'
  } > "$D/na3.contract"
  sh "$LC" "$D/na3" "$D/na3.contract" >"$D/na3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'actual_time' "$D/na3.out" \
    && [ "$(tix_lc_status "$D/na3")" = 'in_progress' ]; then
    ok '负例 N-237i lane-commit done 翻转缺 actual_time → exit 1（actual_time 前置门，票据未 done）'
  else
    bad '负例 N-237i lane-commit done 翻转缺 actual_time → exit 1（actual_time 前置门，票据未 done）' "exit=$rc $(tail -n 3 "$D/na3.out" | tr '\n' '|')"
  fi

  # 负例 N-json：flips id 与 .json 票文件不符 → exit 1 零提交零写入（id 校验语义对
  # .json 票保持，票 108）；JSON 票体零追加同证，独立 checkpoint md 不落盘。
  lc_build_fixture "$D/nj"
  lc_json_docs "$D/nj"
  lc_git_commit "$D/nj"
  printf 'change-json\n' > "$D/nj/a.txt"
  nj_ck=$(cksum "$D/nj/facts/requirements/tickets/33-lc-ticket.json")
  nj_n0=$(git -C "$D/nj" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
    printf 'message: fixture json id mismatch\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-09-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:34-wrong-id:done:2026-09-30T12:00\n'
  } > "$D/nj.contract"
  sh "$LC" "$D/nj" "$D/nj.contract" >"$D/nj.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '索引条目 id 与 ticket 票文件不符' "$D/nj.out" \
    && [ "$(git -C "$D/nj" rev-list --count HEAD)" -eq "$nj_n0" ] \
    && [ "$(cksum "$D/nj/facts/requirements/tickets/33-lc-ticket.json")" = "$nj_ck" ] \
    && [ ! -f "$D/nj/facts/requirements/tickets/33-lc-ticket-review-checkpoint.md" ]; then
    ok '负例 N-json flips id 与 .json 票文件不符 → exit 1 零提交零写入且票体零追加（票 108 fail-closed）'
  else
    bad '负例 N-json flips id 与 .json 票文件不符 → exit 1 零提交零写入且票体零追加（票 108 fail-closed）' "exit=$rc $(tail -n 2 "$D/nj.out" | tr '\n' '|')"
  fi

  # ---- 票 228 断言：索引翻转代理定位 fail-closed（写入方收敛面）----
  # ticket-ops.sh 不在场（同目录与 PATH 均无）→ 代理定位预检停止：产品提交零创建，
  # 索引零写入（index.json 唯一写入方缺失即不收口——票 228 F1/F2）。
  lc_build_fixture "$D/n228"
  lc_json_docs "$D/n228"
  # 代理缺席语境：lane-commit 以运行副本承载（同目录定位基准＝副本所在目录）——落位
  # 夹具私有 bin（lane-commit＋依赖件，唯缺 ticket-ops.sh；PATH 亦无同名件），使代理
  # 定位同目录与 PATH 双缺，收尾预检必须 fail-closed 停止。
  mkdir -p "$D/n228-bin"
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/workspace-snapshot.sh" "$D/n228-bin/"
  test_copy_closure "$SCRIPT_DIR" "$D/n228-bin" generate-progress.sh json-validator.py common-helpers.sh check-gates.sh
  lc_git_commit "$D/n228"
  printf 'change-n228\n' > "$D/n228/a.txt"
  n228_n0=$(git -C "$D/n228" rev-list --count HEAD)
  n228_idx0=$(cksum "$D/n228/facts/requirements/tickets/index.json")
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
    printf 'message: fixture proxy missing\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-10-26T08:30\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-10-26T08:30\n'
  } > "$D/n228.contract"
  sh "$D/n228-bin/lane-commit.sh" "$D/n228" "$D/n228.contract" >"$D/n228.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '票务代理 ticket-ops.sh 不可用' "$D/n228.out" \
    && [ "$(git -C "$D/n228" rev-list --count HEAD)" -eq "$n228_n0" ] \
    && [ "$(cksum "$D/n228/facts/requirements/tickets/index.json")" = "$n228_idx0" ]; then
    ok '负例 N-228 票务代理 ticket-ops.sh 不在场 → exit 1 收尾预检停止零提交零写入（票 228 F1/F2 唯一写入方 fail-closed）'
  else
    bad '负例 N-228 票务代理 ticket-ops.sh 不在场 → exit 1 收尾预检停止零提交零写入（票 228 F1/F2 唯一写入方 fail-closed）' "exit=$rc $(tail -n 2 "$D/n228.out" | tr '\n' '|')"
  fi

  # 通用 flips 不得直写 index.json；两条道均须在预检停止且索引零改动。
  lc_build_fixture "$D/n229mi"
  lc_json_docs "$D/n229mi"
  lc_git_commit "$D/n229mi"
  printf 'change-229mi\n' > "$D/n229mi/a.txt"
  n229mi_n0=$(git -C "$D/n229mi" rev-list --count HEAD)
  n229mi_idx0=$(cksum "$D/n229mi/facts/requirements/tickets/index.json")
  lc_contract "$D/n229mi.contract" ''
  printf 'flips: facts/requirements/tickets/index.json:in_progress:done\n' >> "$D/n229mi.contract"
  sh "$LC" "$D/n229mi" "$D/n229mi.contract" >"$D/n229mi.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '通用 flips 不得直写索引文件' "$D/n229mi.out" \
    && [ "$(git -C "$D/n229mi" rev-list --count HEAD)" -eq "$n229mi_n0" ] \
    && [ "$(cksum "$D/n229mi/facts/requirements/tickets/index.json")" = "$n229mi_idx0" ]; then
    ok '负例 N-229mi micro 通用 flips 直写索引 → exit 1 零提交且索引零改动'
  else
    bad '负例 N-229mi micro 通用 flips 直写索引 → exit 1 零提交且索引零改动' "exit=$rc $(tail -n 2 "$D/n229mi.out" | tr '\n' '|')"
  fi

  lc_build_fixture "$D/n229ui"
  lc_json_docs "$D/n229ui"
  lc_git_commit "$D/n229ui"
  printf 'change-229ui\n' > "$D/n229ui/a.txt"
  n229ui_n0=$(git -C "$D/n229ui" rev-list --count HEAD)
  n229ui_idx0=$(cksum "$D/n229ui/facts/requirements/tickets/index.json")
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
    printf 'message: generic index flip\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-10-28T10:00\n'
    printf 'flips: facts/requirements/tickets/index.json:in_progress:done\n'
  } > "$D/n229ui.contract"
  sh "$LC" "$D/n229ui" "$D/n229ui.contract" >"$D/n229ui.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '通用 flips 不得直写索引文件' "$D/n229ui.out" \
    && [ "$(git -C "$D/n229ui" rev-list --count HEAD)" -eq "$n229ui_n0" ] \
    && [ "$(cksum "$D/n229ui/facts/requirements/tickets/index.json")" = "$n229ui_idx0" ]; then
    ok '负例 N-229ui user-review 通用 flips 直写索引 → exit 1 零提交且索引零改动'
  else
    bad '负例 N-229ui user-review 通用 flips 直写索引 → exit 1 零提交且索引零改动' "exit=$rc $(tail -n 2 "$D/n229ui.out" | tr '\n' '|')"
  fi

  # 仓内父目录 symlink 别名与真实索引 realpath 相同，同样须拒绝通用 flips。
  lc_build_fixture "$D/n229ia"
  lc_json_docs "$D/n229ia"
  ln -s tickets "$D/n229ia/facts/requirements/tickets-alias"
  lc_git_commit "$D/n229ia"
  printf 'change-229ia\n' > "$D/n229ia/a.txt"
  n229ia_n0=$(git -C "$D/n229ia" rev-list --count HEAD)
  n229ia_idx0=$(cksum "$D/n229ia/facts/requirements/tickets/index.json")
  lc_contract "$D/n229ia.contract" ''
  printf 'flips: facts/requirements/tickets-alias/index.json:in_progress:done\n' >> "$D/n229ia.contract"
  sh "$LC" "$D/n229ia" "$D/n229ia.contract" >"$D/n229ia.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '通用 flips 不得直写索引文件' "$D/n229ia.out" \
    && [ "$(git -C "$D/n229ia" rev-list --count HEAD)" -eq "$n229ia_n0" ] \
    && [ "$(cksum "$D/n229ia/facts/requirements/tickets/index.json")" = "$n229ia_idx0" ]; then
    ok '负例 N-229ia 仓内父目录 symlink 索引别名 → exit 1 零提交且真实索引零改动'
  else
    bad '负例 N-229ia 仓内父目录 symlink 索引别名 → exit 1 零提交且真实索引零改动' "exit=$rc $(tail -n 2 "$D/n229ia.out" | tr '\n' '|')"
  fi

  # ---- 票 229 断言：记录写入职责拆分（checkpoint-write.sh／ledger-append.sh 代理化）----
  # lane-commit 零 checkpoint/账本写入面：user-review 道经 checkpoint-write.sh 落记录块，
  # micro 道经 ledger-append.sh --micro 落微账本；两代理缺失即收尾预检停止（先于产品提交，
  # 零提交零写入）。微账本行族与 --check 零写入由原子层自身契约承载。
  lc_build_fixture "$D/p229m"
  lc_contract "$D/p229m.contract" '20m（票 229 微账本代理占位）'
  sh "$LC" "$D/p229m" "$D/p229m.contract" >"$D/p229m.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '^lane-commit: 记录写入代理定位: .*ledger-append.sh' "$D/p229m.out" \
    && grep -q '^ledger-append: 微账本落行: facts/project/micro.jsonl' "$D/p229m.out" \
    && grep -q '"actual": "20m（票 229 微账本代理占位）"' "$D/p229m/facts/project/micro.jsonl"; then
    ok '正例 P-229m micro 道经 ledger-append.sh --micro 落微账本且代理定位行与落行行在场（票 229 写入方拆分）'
  else
    bad '正例 P-229m micro 道经 ledger-append.sh --micro 落微账本且代理定位行与落行行在场（票 229 写入方拆分）' "exit=$rc $(tail -n 3 "$D/p229m.out" | tr '\n' '|')"
  fi

  lc_build_fixture "$D/p229u"
  mkdir -p "$D/p229u/facts/requirements/tickets"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '# 票\n\n**Status:** `in_progress`\n' > "$D/p229u/facts/requirements/tickets/33-lc-ticket.md"
  lc_git_commit "$D/p229u"
  printf 'change-229u\n' > "$D/p229u/a.txt"
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.md\n'
    printf 'whitelist: a.txt\n'
    printf 'message: checkpoint proxy\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（票 229 代理裁决）\n'
    printf 'verdict_at: 2026-10-28T10:00\n'
  } > "$D/p229u.contract"
  sh "$LC" "$D/p229u" "$D/p229u.contract" >"$D/p229u.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '^lane-commit: 记录写入代理定位: .*checkpoint-write.sh' "$D/p229u.out" \
    && grep -q '^checkpoint-write: 目标文件: facts/requirements/tickets/33-lc-ticket.md' "$D/p229u.out" \
    && grep -q -- '- 裁决原文：OK（票 229 代理裁决）' "$D/p229u/facts/requirements/tickets/33-lc-ticket.md"; then
    ok '正例 P-229u user-review 道经 checkpoint-write.sh 落记录块且目标文件契约行在场（票 229 写入方拆分）'
  else
    bad '正例 P-229u user-review 道经 checkpoint-write.sh 落记录块且目标文件契约行在场（票 229 写入方拆分）' "exit=$rc $(tail -n 3 "$D/p229u.out" | tr '\n' '|')"
  fi

  # 负例 N-229a：checkpoint-write.sh 不在场 → 收尾预检停止，exit 1 零提交零写入
  lc_build_fixture "$D/n229a"
  mkdir -p "$D/n229a-bin"
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/workspace-snapshot.sh" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$D/n229a-bin/"
  mkdir -p "$D/n229a/facts/requirements/tickets"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '# 票\n\n**Status:** `in_progress`\n' > "$D/n229a/facts/requirements/tickets/33-lc-ticket.md"
  lc_git_commit "$D/n229a"
  printf 'change-n229a\n' > "$D/n229a/a.txt"
  n229a_n0=$(git -C "$D/n229a" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.md\n'
    printf 'whitelist: a.txt\n'
    printf 'message: checkpoint proxy missing\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-10-28T10:00\n'
  } > "$D/n229a.contract"
  sh "$D/n229a-bin/lane-commit.sh" "$D/n229a" "$D/n229a.contract" >"$D/n229a.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '记录写入代理 checkpoint-write.sh 不可用' "$D/n229a.out" \
    && [ "$(git -C "$D/n229a" rev-list --count HEAD)" -eq "$n229a_n0" ]; then
    ok '负例 N-229a checkpoint-write.sh 不在场 → exit 1 收尾预检停止零提交零写入（票 229）'
  else
    bad '负例 N-229a checkpoint-write.sh 不在场 → exit 1 收尾预检停止零提交零写入（票 229）' "exit=$rc $(tail -n 2 "$D/n229a.out" | tr '\n' '|')"
  fi

  # 负例 N-229b：ledger-append.sh 不在场 → 收尾预检停止，exit 1 零提交且微账本零写入
  lc_build_fixture "$D/n229b"
  mkdir -p "$D/n229b-bin"
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/workspace-snapshot.sh" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$D/n229b-bin/"
  lc_git_commit "$D/n229b"
  printf 'change-n229b\n' > "$D/n229b/a.txt"
  n229b_n0=$(git -C "$D/n229b" rev-list --count HEAD)
  n229b_ck0=$(cksum "$D/n229b/facts/project/micro.jsonl")
  lc_contract "$D/n229b.contract" ''
  sh "$D/n229b-bin/lane-commit.sh" "$D/n229b" "$D/n229b.contract" >"$D/n229b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '记录写入代理 ledger-append.sh 不可用' "$D/n229b.out" \
    && [ "$(git -C "$D/n229b" rev-list --count HEAD)" -eq "$n229b_n0" ] \
    && [ "$(cksum "$D/n229b/facts/project/micro.jsonl")" = "$n229b_ck0" ]; then
    ok '负例 N-229b ledger-append.sh 不在场 → exit 1 收尾预检停止零提交且微账本零写入（票 229）'
  else
    bad '负例 N-229b ledger-append.sh 不在场 → exit 1 收尾预检停止零提交且微账本零写入（票 229）' "exit=$rc $(tail -n 2 "$D/n229b.out" | tr '\n' '|')"
  fi

  # 原子层契约直测（ledger-append --micro）：--check 零写入、负例字段越界 fail-closed。
  lc_build_fixture "$D/la229"
  lc_git_commit "$D/la229"
  la229_ck0=$(cksum "$D/la229/facts/project/micro.jsonl")
  sh "$SCRIPT_DIR/ledger-append.sh" "$D/la229" --micro --date 2026-10-28 --whitelist a.txt \
    --verify 1 --commit abcdef12 --check >"$D/la229.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'CHECK: PASS — 微账本行字段与行形校验通过（零写入）' "$D/la229.out" \
    && [ "$(cksum "$D/la229/facts/project/micro.jsonl")" = "$la229_ck0" ]; then
    ok '正例 L-229a ledger-append --micro --check → exit 0 且微账本零写入（票 229 原子层契约）'
  else
    bad '正例 L-229a ledger-append --micro --check → exit 0 且微账本零写入（票 229 原子层契约）' "exit=$rc $(tail -n 2 "$D/la229.out" | tr '\n' '|')"
  fi
  sh "$SCRIPT_DIR/ledger-append.sh" "$D/la229" --micro --date 2026-10-28 --whitelist a.txt \
    --verify 1 --commit not-a-sha >"$D/la229b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不合产品提交 ID 口径' "$D/la229b.out" \
    && [ "$(cksum "$D/la229/facts/project/micro.jsonl")" = "$la229_ck0" ]; then
    ok '负例 L-229b ledger-append --micro --commit 非 sha → exit 1 零写入（票 229 原子层契约）'
  else
    bad '负例 L-229b ledger-append --micro --commit 非 sha → exit 1 零写入（票 229 原子层契约）' "exit=$rc $(tail -n 2 "$D/la229b.out" | tr '\n' '|')"
  fi
  sh "$SCRIPT_DIR/ledger-append.sh" "$D/la229" --micro --date 2026-10-28 --whitelist a.txt \
    --verify 1 --commit abcdef12 --ledger-line '{}' >"$D/la229c.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '互斥' "$D/la229c.out"; then
    ok '负例 L-229c ledger-append --micro 与 --ledger-line 混用 → exit 2（票 229 原子层契约）'
  else
    bad '负例 L-229c ledger-append --micro 与 --ledger-line 混用 → exit 2（票 229 原子层契约）' "exit=$rc $(tail -n 2 "$D/la229c.out" | tr '\n' '|')"
  fi

  # ---- 票 193 断言：微账本行合同（references/schemas/ledger-row.schema.json 单源）----
  # AC1/AC2 lane-commit 写入面：micro 道机写落行与合同 micro_seven_key 行族逐键对齐
  # （键序/枚举/值域经合同文件机核）；既有六键行（无 actual 键）向后兼容——旧行逐字节
  # 保留、新行恒七键。行型合同文件为套件依赖（缺失 exit 2）。
  LR_SCHEMA="${SCRIPT_DIR}/../references/schemas/ledger-row.schema.json"
  [ -f "$LR_SCHEMA" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（微账本行行型合同，票 193）\n' "$LR_SCHEMA" >&2; exit 2; }

  lc_build_fixture "$D/lr7"
  lc_contract "$D/lr7.contract" '25m（票 193 微账本合同占位）'
  sh "$LC" "$D/lr7" "$D/lr7.contract" >"$D/lr7.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    if python3 - "$LR_SCHEMA" "$D/lr7/facts/project/micro.jsonl" >"$D/lr7-check.log" 2>&1 <<'PYTHON'
import json, re, sys
schema = json.load(open(sys.argv[1], encoding='utf-8'))
rows = {r['id']: r for r in schema['rows']}
keys = rows['micro_seven_key']['keys']
last = open(sys.argv[2], encoding='utf-8').read().rstrip('\n').split('\n')[-1]
obj = json.loads(last)
assert list(obj.keys()) == keys, f"键序漂移: {list(obj.keys())} != {keys}"
assert obj['lane'] == 'micro', obj['lane']
assert obj['gates'] == 'PASS', obj['gates']
assert isinstance(obj['verify'], int) and obj['verify'] >= 1, obj['verify']
assert re.fullmatch(r'[0-9a-f]{7,}', obj['commit']), obj['commit']
assert re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', obj['date']), obj['date']
assert obj['actual'] == '25m（票 193 微账本合同占位）', obj['actual']
PYTHON
    then
      ok '正例 micro 落行与合同 micro_seven_key 行族逐键对齐（键序/枚举/值域，票 193 AC1＋AC2 写入面）'
    else
      bad '正例 micro 落行与合同 micro_seven_key 行族逐键对齐（键序/枚举/值域，票 193 AC1＋AC2 写入面）' "$(head -n 3 "$D/lr7-check.log" | tr '\n' '|')"
    fi
  else
    bad '正例 micro 落行与合同 micro_seven_key 行族逐键对齐（键序/枚举/值域，票 193 AC1＋AC2 写入面）' "exit=$rc $(tail -n 3 "$D/lr7.out" | tr '\n' '|')"
  fi

  # 既有六键行（无 actual 键）向后兼容：夹具微账本改置六键 legacy 行，全链收口后旧行
  # 逐字节保留（只追加不重写）且新行落七键（actual 键在场）。
  lc_build_fixture "$D/lr6"
  LR6_LEGACY='{"date": "2026-09-27", "lane": "micro", "whitelist": "seed.txt", "gates": "PASS", "verify": 2, "commit": "legacy6"}'
  printf '%s\n' "$LR6_LEGACY" > "$D/lr6/facts/project/micro.jsonl"
  lc_git_commit "$D/lr6"
  printf 'change-lr6\n' > "$D/lr6/a.txt"
  lc_contract "$D/lr6.contract" ''
  sh "$LC" "$D/lr6" "$D/lr6.contract" >"$D/lr6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(head -n 1 "$D/lr6/facts/project/micro.jsonl")" = "$LR6_LEGACY" ] \
    && grep -q '"commit": "[0-9a-f]\{7,\}", "actual": ""}' "$D/lr6/facts/project/micro.jsonl"; then
    ok '正例 既有六键行向后兼容：旧行逐字节保留且新行恒七键（票 193 兼容约束）'
  else
    bad '正例 既有六键行向后兼容：旧行逐字节保留且新行恒七键（票 193 兼容约束）' "exit=$rc $(tail -n 3 "$D/lr6.out" | tr '\n' '|')"
  fi

  suite_summary 'lane-commit'
}
