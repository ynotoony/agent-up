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
# 仓外哨兵与仓库工作树指纹负例前后全等（AC3），symlink 在场语境合法相对路径全链零回归）
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
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/generate-progress.sh" "$R/rules/implementation/scripts/"
  printf '{"date": "2026-09-28", "lane": "micro", "whitelist": "seed.txt", "gates": "PASS", "verify": 1, "commit": "seed", "actual": ""}\n' > "$R/facts/project/micro.jsonl"
  printf 'seed\n' > "$R/a.txt"
  git -C "$R" init -q
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
  # 票 108）——checkpoint 承载形态断言的命名先例＝facts/requirements/tickets/<id>-review-checkpoint.md
  mkdir -p "$1/facts/requirements/tickets"
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
  "created_at": "2026-09-29"
}
EOF
  cat > "$1/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `33-lc-ticket.json` | 任务票 33；`in_progress`（2026-09-29 开票） | LC json fixture |
EOF
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

  # ---- 票 144 断言：写入面路径边界（whitelist/flips/ticket 须仓库根内普通相对文件）----
  # 边界矩阵：../ 向上跳段／绝对路径／symlink 指向仓外（realpath containment，macOS
  # /tmp → /private/tmp 规格化歧义同口径拦出）／仓内 symlink 自身——均写入前 exit 1；
  # flips 目标与 ticket 票文件走同款 lc_in_repo 校验各一负例；负例统一零提交零写入零
  # 仓外副作用（夹具外哨兵文件内容＋仓库工作树结构/内容指纹前后不变）；末位合法回归
  # 正例（symlink 在场语境合法相对路径照旧收口，AC 零回归）。
  lc_build_fixture "$D/bm"
  printf 'outside-sentinel\n' > "$D/bm-outside-sentinel.txt"
  ln -s "$D/bm-outside-sentinel.txt" "$D/bm/outside-link.txt"
  ln -s 'a.txt' "$D/bm/inside-link.txt"
  lc_git_commit "$D/bm"
  printf 'change\n' > "$D/bm/a.txt"
  bm_n0=$(git -C "$D/bm" rev-list --count HEAD)
  bm_ls0=$(cd "$D/bm" && find . -name .git -prune -o -print | LC_ALL=C sort | cksum)
  bm_ck0=$(cd "$D/bm" && find . -name .git -prune -o -type f -print | LC_ALL=C sort | xargs cksum | cksum)
  bm_sent0=$(cksum "$D/bm-outside-sentinel.txt")

  {
    printf 'lane: micro\n'
    printf 'whitelist: ../bm-outside-sentinel.txt\n'
    printf 'message: escape dotdot\n'
    printf 'verify: true\n'
  } > "$D/bm-a.contract"
  sh "$LC" "$D/bm" "$D/bm-a.contract" >"$D/bm-a.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得含 .. 或 ./ 路径段' "$D/bm-a.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144a whitelist 含 ..（../ 向上跳段）→ exit 1 报文本层违规且零提交（票 144）'
  else
    bad '负例 N-144a whitelist 含 ..（../ 向上跳段）→ exit 1 报文本层违规且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-a.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: /tmp/lc144-nonexistent-outside\n'
    printf 'message: escape absolute\n'
    printf 'verify: true\n'
  } > "$D/bm-b.contract"
  sh "$LC" "$D/bm" "$D/bm-b.contract" >"$D/bm-b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得为绝对路径' "$D/bm-b.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144b whitelist 绝对路径 → exit 1 报文本层违规且零提交（票 144）'
  else
    bad '负例 N-144b whitelist 绝对路径 → exit 1 报文本层违规且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-b.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: outside-link.txt\n'
    printf 'message: escape symlink\n'
    printf 'verify: true\n'
  } > "$D/bm-c.contract"
  sh "$LC" "$D/bm" "$D/bm-c.contract" >"$D/bm-c.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '越出仓库根（realpath containment 失败）' "$D/bm-c.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144c whitelist symlink 指向仓外 → exit 1 realpath containment 拦出且零提交（票 144）'
  else
    bad '负例 N-144c whitelist symlink 指向仓外 → exit 1 realpath containment 拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-c.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: inside-link.txt\n'
    printf 'message: inside symlink\n'
    printf 'verify: true\n'
  } > "$D/bm-d.contract"
  sh "$LC" "$D/bm" "$D/bm-d.contract" >"$D/bm-d.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得为 symlink' "$D/bm-d.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144d whitelist 仓内 symlink 自身 → exit 1 形态层拦出且零提交（票 144：仅普通文件）'
  else
    bad '负例 N-144d whitelist 仓内 symlink 自身 → exit 1 形态层拦出且零提交（票 144：仅普通文件）' "exit=$rc $(tail -n 2 "$D/bm-d.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt\n'
    printf 'message: flips escape\n'
    printf 'verify: true\n'
    printf 'flips: outside-link.txt:note:hello\n'
  } > "$D/bm-e.contract"
  sh "$LC" "$D/bm" "$D/bm-e.contract" >"$D/bm-e.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'flips 目标路径边界校验未通过' "$D/bm-e.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144e flips 目标 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）'
  else
    bad '负例 N-144e flips 目标 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-e.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: user-review\n'
    printf 'ticket: outside-link.txt\n'
    printf 'whitelist: a.txt\n'
    printf 'message: ticket escape\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-10-15T12:00\n'
  } > "$D/bm-f.contract"
  sh "$LC" "$D/bm" "$D/bm-f.contract" >"$D/bm-f.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'ticket 票文件 越出仓库根' "$D/bm-f.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144f ticket 票文件 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）'
  else
    bad '负例 N-144f ticket 票文件 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-f.out" | tr '\n' '|')"
  fi

  # 负例副作用核验（票 144 AC3）：全部负例后——仓外哨兵文件内容不变、仓库工作树
  # 结构（文件名集）与内容（逐文件 cksum 链）指纹均与负例前基线全等。
  if [ "$(cksum "$D/bm-outside-sentinel.txt")" = "$bm_sent0" ] \
    && [ "$(cd "$D/bm" && find . -name .git -prune -o -print | LC_ALL=C sort | cksum)" = "$bm_ls0" ] \
    && [ "$(cd "$D/bm" && find . -name .git -prune -o -type f -print | LC_ALL=C sort | xargs cksum | cksum)" = "$bm_ck0" ]; then
    ok '负例副作用核验 仓外哨兵内容＋仓库工作树结构/内容指纹负例前后全等（票 144 AC3 零仓外副作用）'
  else
    bad '负例副作用核验 仓外哨兵内容＋仓库工作树结构/内容指纹负例前后全等（票 144 AC3 零仓外副作用）' '哨兵 cksum 或仓库指纹漂移'
  fi

  # 正例 P-144：合法仓内相对路径零回归——symlink 在场语境（同夹具）micro 合同照旧
  # 两段式收口 exit 0 且微账本落行（AC：合法目标行为不变）。负例段 lc_git_commit 已把
  # a.txt 既有改动入库，此处再造已跟踪文件改动供产品提交承载。
  printf 'change-144\n' > "$D/bm/a.txt"
  lc_contract "$D/bm-p.contract" '30m（票 144 合法回归占位）'
  sh "$LC" "$D/bm" "$D/bm-p.contract" >"$D/bm-p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"actual": "30m（票 144 合法回归占位）"' "$D/bm/facts/project/micro.jsonl" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$((bm_n0 + 2))" ]; then
    ok '正例 P-144 symlink 在场语境合法相对路径 micro 全链 → exit 0 两段提交＋微账本落行（票 144 零回归）'
  else
    bad '正例 P-144 symlink 在场语境合法相对路径 micro 全链 → exit 0 两段提交＋微账本落行（票 144 零回归）' "exit=$rc $(tail -n 3 "$D/bm-p.out" | tr '\n' '|')"
  fi

  # ---- 票 108 断言：user-review 道 .json 票体全链 ----
  # 正例 P-json：.json 票 user-review 全链收口（索引翻转 done＋issues-README 行翻转＋
  # checkpoint 落独立 facts/requirements/tickets/33-lc-ticket-review-checkpoint.md＋正文
  # Status 回写跳过说明行＋投影再生）→ exit 0；JSON 票体逐字节零追加（前后 cksum）；
  # 记录提交落地（checkpoint md 入第二段提交）。预期值独立重建。
  lc_build_fixture "$D/pj"
  lc_json_docs "$D/pj"
  lc_git_commit "$D/pj"
  printf 'change-json\n' > "$D/pj/a.txt"
  pj_ck0=$(cksum "$D/pj/facts/requirements/tickets/33-lc-ticket.json")
  pj_n0=$(git -C "$D/pj" rev-list --count HEAD)
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
    printf 'message: fixture json ur commit\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK（fixture json 全链裁决）\n'
    printf 'verdict_at: 2026-09-30T12:00\n'
    printf 'flips: facts/requirements/tickets/index.json:index:33-lc-ticket:done:2026-09-30T12:00\n'
    # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
    printf 'flips: facts/requirements/tickets/README.md:任务票 33；`in_progress`:| `33-lc-ticket.json` | 任务票 33；`done`（2026-09-29 开票） | LC json fixture |\n'
  } > "$D/pj.contract"
  sh "$LC" "$D/pj" "$D/pj.contract" >"$D/pj.out" 2>&1
  rc=$?
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  if [ "$rc" -eq 0 ] \
    && grep -q '"id": "33-lc-ticket", "status": "done"' "$D/pj/facts/requirements/tickets/index.json" \
    && grep -q '任务票 33；`done`' "$D/pj/facts/requirements/tickets/README.md" \
    && grep -q '| 33-lc-ticket | done |' "$D/pj/facts/requirements/tickets/progress-current.md" \
    && grep -q '跳过正文 Status 回写' "$D/pj.out"; then
    ok '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转＋README 替换＋投影落行＋回写跳过说明行（票 108）'
  else
    bad '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转＋README 替换＋投影落行＋回写跳过说明行（票 108）' "exit=$rc $(tail -n 3 "$D/pj.out" | tr '\n' '|')"
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
  printf 'change-json2\n' > "$D/pj/a.txt"
  {
    printf 'lane: user-review\n'
    printf 'ticket: facts/requirements/tickets/33-lc-ticket.json\n'
    printf 'whitelist: a.txt\n'
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
    && [ "$(git -C "$D/pj" rev-list --count HEAD)" -eq "$((pj_n0 + 4))" ]; then
    ok '正例 P-json 二次收口 checkpoint md 已存在 → 追加记录块（标题恰 1 个、记录块 2 个）且票体仍零追加（票 108）'
  else
    bad '正例 P-json 二次收口 checkpoint md 已存在 → 追加记录块（标题恰 1 个、记录块 2 个）且票体仍零追加（票 108）' "exit=$rc $(tail -n 3 "$D/pj2.out" | tr '\n' '|')"
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
