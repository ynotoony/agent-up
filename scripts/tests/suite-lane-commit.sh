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
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/generate-dir-readmes.sh" "$SCRIPT_DIR/dir-readme.rules" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/checkpoint-write.sh" "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/ticket-audit.sh" "$R/rules/implementation/scripts/"
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
  # $1=夹具根 $2=base $3=head：按重算 diff 指纹写审查收据（33-lc-ticket，作者身份由
  # 后续提交固定为 reviewer@example.com）
  python3 - "$1/facts/requirements/tickets/33-lc-ticket.review-evidence.json" "$2" "$3" "$1" <<'PY'
import json, subprocess, sys, datetime
path, base, head, repo = sys.argv[1:5]
diff = subprocess.run(
    ['git', '-C', repo, 'diff', '--no-color', '--no-ext-diff', '--no-textconv',
     '--binary', base, head], check=True, stdout=subprocess.PIPE).stdout
diff_sha = subprocess.run(
    ['git', '-C', repo, 'hash-object', '--stdin'], input=diff, check=True,
    stdout=subprocess.PIPE).stdout.decode().strip()
now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
receipt = {
    'schema_version': 1,
    'receipt_kind': 'review',
    'ticket_id': '33-lc-ticket',
    'created_at': now,
    'actor': 'reviewer',
    'base_sha': base,
    'head_sha': head,
    'diff_sha': diff_sha,
    'reviewer_identity': 'reviewer@example.com',
    'reviewed_at': now,
    'verdict': 'PASS',
    'acceptance': [{'ac_id': 'AC1', 'result': 'pass', 'evidence': 'a.txt:1'}],
}
with open(path, 'w') as fh:
    fh.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
PY
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
    && grep -q '索引翻转已代理' "$D/pj.out" \
    && grep -q 'ticket-ops: 证据门: flip-index 放行' "$D/pj.out" \
    && grep -q 'ticket-ops: PASS（flip-index 完成' "$D/pj.out" \
    && grep -q '目录 README 收口预检通过' "$D/pj.out" \
    && grep -q '跳过正文 Status 回写' "$D/pj.out"; then
    ok '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转（经 ticket-ops flip-index 代理，票 228）＋证据门 conformant＋README 替换＋投影落行＋回写跳过说明行（票 108/237）'
  else
    bad '正例 P-json .json 票 user-review 全链 → exit 0 且索引翻转（经 ticket-ops flip-index 代理，票 228）＋证据门 conformant＋README 替换＋投影落行＋回写跳过说明行（票 108/237）' "exit=$rc $(tail -n 3 "$D/pj.out" | tr '\n' '|')"
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
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$D/n228-bin/"
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
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/common-helpers.sh" "$D/n229a-bin/"
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
  cp "$SCRIPT_DIR/lane-commit.sh" "$SCRIPT_DIR/check-gates.sh" "$SCRIPT_DIR/common-helpers.sh" "$D/n229b-bin/"
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

  # ---- 票 247 断言：记录提交前缀门（--record-commit 单点入口）----
  # AC1 中间插入拒绝并报首行号；AC2 部分暂存拒绝零提交；AC3 尾部追加仅提交记录路径、
  # 混提/产品路径拒绝；AC4 同锁并发提交最终前缀成立（含陈旧快照拒绝负例）；AC5 成功后
  # check-append-only 同源通过；AC6 README 登记入口与失败语义。
  # 评审修复（D1–D5）：D1 断言对象＝私有索引写出的树（窗口内共享索引被并发暂存不卷入、
  # 并发暂存保留现场）；D2 文件集核对前移到 write-tree 后、commit 前；D3 并发同步点＝
  # RECORD_COMMIT_TEST_MARKER 标记文件（HOLD 仅放大窗口，非同步手段）；D4 未改动记录
  # 路径显式列为已排除；D5 工作树缺失记录路径指名拒绝。
  rc_fixture() {
    # $1=夹具仓根：只追加账本三行基线＋未改动记录文件＋产品文件 a.txt（干净工作区）
    R=$1
    rm -rf "$R"
    mkdir -p "$R/facts/project"
    printf 'l1\nl2\nl3\n' > "$R/facts/project/changes.jsonl"
    printf 'o1\n' > "$R/facts/project/other.jsonl"
    printf 'product\n' > "$R/a.txt"
    git -C "$R" init -q
    lc_git_commit "$R"
  }

  rc_expect() {
    # $1=实际文件 $2=printf %b 口径期望内容：逐字节比较
    printf '%b' "$2" > "$D/rc-expect.txt"
    cmp -s "$1" "$D/rc-expect.txt"
  }

  rc_count() { git -C "$1" rev-list --count HEAD; }

  rc_head_files() { git -C "$1" diff-tree --root --no-commit-id --name-only -r HEAD; }

  rc_lock_absent() { [ ! -e "$1/.git/agent-up-record.lock" ]; }

  rc_readme_documented() {
    # $1=README 路径：入口用法、失败零提交、首个违规行号三要素须在场
    grep -Fq -- '--record-commit' "$1" \
      && grep -Fq '零提交' "$1" \
      && grep -Fq '首个违规行号' "$1"
  }

  # AC1＋AC3 正例：合法尾部追加 → exit 0、提交文件集恰为账本、锁无残留。
  rc_fixture "$D/rc-ac1"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac1/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac1" 'chore: rc247 尾部追加' facts/project/changes.jsonl >"$D/rc-ac1-p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac1")" = 'facts/project/changes.jsonl' ] \
    && rc_lock_absent "$D/rc-ac1" \
    && grep -q 'lane-commit: 记录提交门: 同锁串行（锁目录 ' "$D/rc-ac1-p.out"; then
    ok '正例 247-P1 账本尾部追加 → exit 0、提交文件集恰为记录路径、锁无残留（票 247 AC3）'
  else
    bad '正例 247-P1 账本尾部追加 → exit 0、提交文件集恰为记录路径、锁无残留（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac1-p.out" | tr '\n' '|')"
  fi

  # AC1 负例：HEAD→待提交中间插入 → exit 1 报首个违规行号（待提交版行号），零提交、
  # 工作区内容零回滚改写。
  rc_fixture "$D/rc-ac1n"
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac1n/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac1n")
  sh "$LC" --record-commit "$D/rc-ac1n" 'chore: rc247 中间插入' facts/project/changes.jsonl >"$D/rc-ac1n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'HEAD 旧内容非待提交版本前缀' "$D/rc-ac1n.out" \
    && grep -Fq '首个违规行号 2（待提交版行号）' "$D/rc-ac1n.out" \
    && [ "$(rc_count "$D/rc-ac1n")" -eq "$rc_n0" ] \
    && rc_expect "$D/rc-ac1n/facts/project/changes.jsonl" 'l1\nINSERT\nl2\nl3\n'; then
    ok '负例 247-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写（票 247 AC1）'
  else
    bad '负例 247-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写（票 247 AC1）' "exit=$rc $(tail -n 3 "$D/rc-ac1n.out" | tr '\n' '|')"
  fi

  # AC1 负例二（D1）：调用前另一会话已把中间插入版放进共享索引（工作区同版本，故不触发
  # 部分暂存预检）→ 私有索引仍按工作区内容断言并拒绝，零提交。
  rc_fixture "$D/rc-ac1n2"
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac1n2/facts/project/changes.jsonl"
  git -C "$D/rc-ac1n2" add facts/project/changes.jsonl
  rc_n0=$(rc_count "$D/rc-ac1n2")
  sh "$LC" --record-commit "$D/rc-ac1n2" 'chore: rc247 共享索引中间插入' facts/project/changes.jsonl >"$D/rc-ac1n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'HEAD 旧内容非待提交版本前缀' "$D/rc-ac1n2.out" \
    && grep -Fq '首个违规行号 2（待提交版行号）' "$D/rc-ac1n2.out" \
    && [ "$(rc_count "$D/rc-ac1n2")" -eq "$rc_n0" ]; then
    ok '负例 247-N1b 共享索引含中间插入版 → 私有索引断言拒绝、exit 1、零提交（票 247 D1）'
  else
    bad '负例 247-N1b 共享索引含中间插入版 → 私有索引断言拒绝、exit 1、零提交（票 247 D1）' "exit=$rc $(tail -n 3 "$D/rc-ac1n2.out" | tr '\n' '|')"
  fi

  # AC2 正例：仅工作区改动（未暂存）→ 入口自行暂存后提交成功。
  rc_fixture "$D/rc-ac2p"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac2p/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac2p" 'chore: rc247 未暂存改动' facts/project/changes.jsonl >"$D/rc-ac2p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(rc_count "$D/rc-ac2p")" -eq 2 ]; then
    ok '正例 247-P2 仅工作区改动 → exit 0 入口自行暂存并提交（票 247 AC2 对照）'
  else
    bad '正例 247-P2 仅工作区改动 → exit 0 入口自行暂存并提交（票 247 AC2 对照）' "exit=$rc $(tail -n 3 "$D/rc-ac2p.out" | tr '\n' '|')"
  fi

  # AC2 负例：暂存 l1..l4 后工作区再追加 l5（部分暂存）→ exit 1 报首个差异行、零提交。
  rc_fixture "$D/rc-ac2n"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac2n/facts/project/changes.jsonl"
  git -C "$D/rc-ac2n" add facts/project/changes.jsonl
  printf 'l1\nl2\nl3\nl4\nl5\n' > "$D/rc-ac2n/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac2n")
  sh "$LC" --record-commit "$D/rc-ac2n" 'chore: rc247 部分暂存' facts/project/changes.jsonl >"$D/rc-ac2n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '部分暂存，首个差异行 5' "$D/rc-ac2n.out" \
    && [ "$(rc_count "$D/rc-ac2n")" -eq "$rc_n0" ]; then
    ok '负例 247-N2 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交（票 247 AC2）'
  else
    bad '负例 247-N2 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交（票 247 AC2）' "exit=$rc $(tail -n 3 "$D/rc-ac2n.out" | tr '\n' '|')"
  fi

  # AC3 正例：产品改动未暂存＋账本尾部追加 → 提交仅账本，产品仍留工作区未提交。
  rc_fixture "$D/rc-ac3p"
  printf 'product-changed\n' > "$D/rc-ac3p/a.txt"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3p/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3p" 'chore: rc247 只提交记录' facts/project/changes.jsonl >"$D/rc-ac3p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3p")" = 'facts/project/changes.jsonl' ] \
    && [ "$(git -C "$D/rc-ac3p" diff --name-only)" = 'a.txt' ]; then
    ok '正例 247-P3 产品改动未暂存 → 提交文件集恰为账本、产品文件不入提交（票 247 AC3）'
  else
    bad '正例 247-P3 产品改动未暂存 → 提交文件集恰为账本、产品文件不入提交（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac3p.out" | tr '\n' '|')"
  fi

  # AC3 正例二（D1）：A 持锁窗口内另一会话把中间插入版写到工作区并 git add（同时暂存
  # 产品文件）→ A 只提交自己私有索引快照的尾部追加版，共享索引的并发暂存保留现场。
  rc_fixture "$D/rc-ac3p2"
  rm -f "$D/rc-ac3p2.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac3p2/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac3p2.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac3p2" 'chore: rc247 隔离' facts/project/changes.jsonl >"$D/rc-ac3p2.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac3p2.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac3p2.marker" ]; then rc_marker=1; fi
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac3p2/facts/project/changes.jsonl"
  git -C "$D/rc-ac3p2" add facts/project/changes.jsonl
  printf 'product-staged\n' > "$D/rc-ac3p2/a.txt"
  git -C "$D/rc-ac3p2" add a.txt
  wait "$rc_a_pid"
  rc=$?
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac3p2.expected"
  if [ "$rc_marker" -eq 1 ] && [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3p2")" = 'facts/project/changes.jsonl' ] \
    && git -C "$D/rc-ac3p2" show HEAD:facts/project/changes.jsonl | cmp -s - "$D/rc-ac3p2.expected" \
    && [ "$(git -C "$D/rc-ac3p2" diff --cached --name-only | paste -sd, -)" = 'a.txt,facts/project/changes.jsonl' ]; then
    ok '正例 247-P3c 窗口内共享索引被并发暂存 → 提交仅含 A 的私有快照，并发暂存保留（票 247 D1）'
  else
    bad '正例 247-P3c 窗口内共享索引被并发暂存 → 提交仅含 A 的私有快照，并发暂存保留（票 247 D1）' "marker=$rc_marker exit=$rc head_files=$(rc_head_files "$D/rc-ac3p2" | paste -sd, -) staged=$(git -C "$D/rc-ac3p2" diff --cached --name-only | paste -sd, -) $(tail -n 2 "$D/rc-ac3p2.out" | tr '\n' '|')"
  fi

  # AC3 负例一：产品路径作为记录路径参数 → 记录面白名单拒绝、零提交。
  rc_fixture "$D/rc-ac3n1"
  printf 'product-changed\n' > "$D/rc-ac3n1/a.txt"
  rc_n0=$(rc_count "$D/rc-ac3n1")
  sh "$LC" --record-commit "$D/rc-ac3n1" 'chore: rc247 产品路径' a.txt >"$D/rc-ac3n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '不在 facts/ 记录面内' "$D/rc-ac3n1.out" \
    && [ "$(rc_count "$D/rc-ac3n1")" -eq "$rc_n0" ]; then
    ok '负例 247-N3a 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交（票 247 AC3）'
  else
    bad '负例 247-N3a 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac3n1.out" | tr '\n' '|')"
  fi

  # AC3 负例二（D1 语义更新）：产品文件已暂存＋账本尾部追加 → 记录提交只含记录路径，
  # 产品暂存不卷入提交、保留现场（不回滚、不静默提交）。
  rc_fixture "$D/rc-ac3n2"
  printf 'product-staged\n' > "$D/rc-ac3n2/a.txt"
  git -C "$D/rc-ac3n2" add a.txt
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3n2/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3n2" 'chore: rc247 混提' facts/project/changes.jsonl >"$D/rc-ac3n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3n2")" = 'facts/project/changes.jsonl' ] \
    && [ "$(git -C "$D/rc-ac3n2" diff --cached --name-only)" = 'a.txt' ]; then
    ok '负例 247-N3b 产品已暂存＋记录追加 → 提交仅记录路径、产品暂存保留现场（票 247 D1）'
  else
    bad '负例 247-N3b 产品已暂存＋记录追加 → 提交仅记录路径、产品暂存保留现场（票 247 D1）' "exit=$rc $(tail -n 3 "$D/rc-ac3n2.out" | tr '\n' '|')"
  fi

  # AC3 负例三：记录路径含 `..` 归一化段（facts/../a.txt 指向产品文件）→ 文本层边界拒绝、
  # 零提交（记录提交入口复用票 144 路径边界，产品文件无法借归一化混入私有索引）。
  rc_fixture "$D/rc-ac3n3"
  printf 'product-staged\n' > "$D/rc-ac3n3/a.txt"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3n3/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac3n3")
  sh "$LC" --record-commit "$D/rc-ac3n3" 'chore: rc247 归一化混提' \
    facts/project/changes.jsonl facts/../a.txt >"$D/rc-ac3n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '不得含 .. 或 ./ 路径段' "$D/rc-ac3n3.out" \
    && [ "$(rc_count "$D/rc-ac3n3")" -eq "$rc_n0" ]; then
    ok '负例 247-N3c 记录路径含 .. 归一化段 → 边界拒绝、零提交（票 144 口径）'
  else
    bad '负例 247-N3c 记录路径含 .. 归一化段 → 边界拒绝、零提交（票 144 口径）' "exit=$rc $(tail -n 3 "$D/rc-ac3n3.out" | tr '\n' '|')"
  fi

  # AC4 正例：A 在提交窗口持锁（私有索引快照完成后写标记并 HOLD 放大窗口，B 以标记
  # 为同步事件），B 并发追加 → B 等锁、两条记录提交串行、B 父提交＝A、最终前缀成立。
  rc_fixture "$D/rc-ac4p"
  rm -f "$D/rc-ac4p.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac4p/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac4p.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac4p" 'chore: rc247 A' facts/project/changes.jsonl >"$D/rc-ac4p-a.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac4p.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac4p.marker" ]; then rc_marker=1; fi
  printf 'l1\nl2\nl3\na4\nb4\n' > "$D/rc-ac4p/facts/project/changes.jsonl"
  rc_b_start=$(date +%s)
  sh "$LC" --record-commit "$D/rc-ac4p" 'chore: rc247 B' facts/project/changes.jsonl >"$D/rc-ac4p-b.out" 2>&1
  rc_b=$?
  rc_b_elapsed=$(( $(date +%s) - rc_b_start ))
  wait "$rc_a_pid"
  rc_a=$?
  rc_a_cid=$(sed -n 's/^lane-commit: 记录提交 \([0-9a-f]\{7,\}\)$/\1/p' "$D/rc-ac4p-a.out" | tail -n 1)
  rc_b_cid=$(git -C "$D/rc-ac4p" rev-parse HEAD)
  if [ "$rc_marker" -eq 1 ] && [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 0 ] \
    && [ "$(rc_count "$D/rc-ac4p")" -eq 3 ] \
    && [ -n "$rc_a_cid" ] \
    && [ "$(git -C "$D/rc-ac4p" rev-parse HEAD^)" = "$rc_a_cid" ] \
    && [ "$rc_b_elapsed" -ge 1 ] \
    && rc_expect "$D/rc-ac4p/facts/project/changes.jsonl" 'l1\nl2\nl3\na4\nb4\n'; then
    ok "正例 247-P4 A 持锁提交期间 B 并发追加 → 串行提交（标记同步，B 等待 ${rc_b_elapsed}s，父提交＝A）、最终前缀成立（票 247 AC4）"
  else
    bad '正例 247-P4 A 持锁提交期间 B 并发追加 → 串行提交、最终前缀成立（票 247 AC4）' "marker=$rc_marker a=$rc_a b=$rc_b b_cid=$rc_b_cid a_cid=$rc_a_cid b_wait=${rc_b_elapsed}s $(tail -n 2 "$D/rc-ac4p-b.out" | tr '\n' '|')"
  fi

  # AC3 正例三（D4）：未改动的记录路径显式列为已排除，不计入提交文件集。
  rc_fixture "$D/rc-ac3p3"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3p3/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3p3" 'chore: rc247 排除未改动' \
    facts/project/changes.jsonl facts/project/other.jsonl >"$D/rc-ac3p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -Fq '记录路径无改动，已排除: facts/project/other.jsonl' "$D/rc-ac3p3.out" \
    && [ "$(rc_head_files "$D/rc-ac3p3")" = 'facts/project/changes.jsonl' ]; then
    ok '正例 247-P4b 未改动记录路径 → 显式列为已排除，提交文件集仅实际改动路径（票 247 D4）'
  else
    bad '正例 247-P4b 未改动记录路径 → 显式列为已排除，提交文件集仅实际改动路径（票 247 D4）' "exit=$rc $(tail -n 3 "$D/rc-ac3p3.out" | tr '\n' '|')"
  fi

  # AC4 负例：B 的待提交版本取自 A 提交前 HEAD（l1..l3,b4），A 提交 a4 后才落地 → 前缀
  # 门拒绝并报首个违规行号 4，零提交。同步点同样用标记文件（B 在标记后立即并发起跑）。
  rc_fixture "$D/rc-ac4n"
  rm -f "$D/rc-ac4n.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac4n/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac4n.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac4n" 'chore: rc247 A' facts/project/changes.jsonl >"$D/rc-ac4n-a.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac4n.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac4n.marker" ]; then rc_marker=1; fi
  printf 'l1\nl2\nl3\nb4\n' > "$D/rc-ac4n.stale"
  cp "$D/rc-ac4n.stale" "$D/rc-ac4n/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac4n" 'chore: rc247 B 陈旧快照' facts/project/changes.jsonl >"$D/rc-ac4n-b.out" 2>&1 &
  rc_b_pid=$!
  wait "$rc_a_pid"
  rc_a=$?
  wait "$rc_b_pid"
  rc_b=$?
  rc_n0=$(rc_count "$D/rc-ac4n")
  if [ "$rc_marker" -eq 1 ] && [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 1 ] \
    && grep -Fq '首个违规行号 4（待提交版行号）' "$D/rc-ac4n-b.out" \
    && [ "$(rc_count "$D/rc-ac4n")" -eq "$rc_n0" ]; then
    ok '负例 247-N4 A 提交后落地陈旧快照 → exit 1 报首个违规行号 4、零提交（票 247 AC4）'
  else
    bad '负例 247-N4 A 提交后落地陈旧快照 → exit 1 报首个违规行号 4、零提交（票 247 AC4）' "marker=$rc_marker a=$rc_a b=$rc_b $(tail -n 3 "$D/rc-ac4n-b.out" | tr '\n' '|')"
  fi

  # AC5 正例：记录提交成功后 check-append-only 同源通过。
  sh "$SCRIPT_DIR/check-append-only.sh" "$D/rc-ac3p" >"$D/rc-ac5p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -Fq 'check-append-only: PASS' "$D/rc-ac5p.out"; then
    ok '正例 247-P5 记录提交成功后 check-append-only → exit 0 PASS（票 247 AC5）'
  else
    bad '正例 247-P5 记录提交成功后 check-append-only → exit 0 PASS（票 247 AC5）' "exit=$rc $(tail -n 3 "$D/rc-ac5p.out" | tr '\n' '|')"
  fi

  # AC5 负例：被前缀门拒绝的中间插入现场，check-append-only 同口径 exit 1 指名行号。
  sh "$SCRIPT_DIR/check-append-only.sh" "$D/rc-ac1n" >"$D/rc-ac5n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '中间插入' "$D/rc-ac5n.out" \
    && grep -Fq '首个违规行号 2（新文件行号）' "$D/rc-ac5n.out"; then
    ok '负例 247-N5 前缀门拒绝现场 check-append-only → exit 1 同口径指名首个违规行号（票 247 AC5）'
  else
    bad '负例 247-N5 前缀门拒绝现场 check-append-only → exit 1 同口径指名首个违规行号（票 247 AC5）' "exit=$rc $(tail -n 3 "$D/rc-ac5n.out" | tr '\n' '|')"
  fi

  # AC5 负例二（D5）：记录路径在工作树被删除 → 入口边界指名「工作树不存在」，零提交。
  rc_fixture "$D/rc-ac5n2"
  rm -f "$D/rc-ac5n2/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac5n2")
  sh "$LC" --record-commit "$D/rc-ac5n2" 'chore: rc247 缺失路径' facts/project/changes.jsonl >"$D/rc-ac5n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '记录路径在工作树不存在: facts/project/changes.jsonl' "$D/rc-ac5n2.out" \
    && [ "$(rc_count "$D/rc-ac5n2")" -eq "$rc_n0" ]; then
    ok '负例 247-N5b 记录路径在工作树被删除 → exit 1 指名不存在、零提交（票 247 D5）'
  else
    bad '负例 247-N5b 记录路径在工作树被删除 → exit 1 指名不存在、零提交（票 247 D5）' "exit=$rc $(tail -n 3 "$D/rc-ac5n2.out" | tr '\n' '|')"
  fi

  # AC6：README 须说明入口用法、失败零提交与首个违规行号；删去入口行的副本必须不命中
  # （证明断言非空转）。
  rc_readme="$SCRIPT_DIR/README.md"
  if rc_readme_documented "$rc_readme"; then
    ok '正例 247-P6 scripts/README 登记记录提交入口与失败语义（入口/零提交/首个违规行号，票 247 AC6）'
  else
    bad '正例 247-P6 scripts/README 登记记录提交入口与失败语义（入口/零提交/首个违规行号，票 247 AC6）' "$(grep -c -- '--record-commit' "$rc_readme" 2>/dev/null) 处入口行"
  fi
  grep -v -- '--record-commit' "$rc_readme" > "$D/rc-readme-minus.md"
  if rc_readme_documented "$D/rc-readme-minus.md"; then
    bad '负例 247-N6 删去入口行的 README 副本不满足登记断言（证明断言非空转，票 247 AC6）' '副本仍命中'
  else
    ok '负例 247-N6 删去入口行的 README 副本不满足登记断言（证明断言非空转，票 247 AC6）'
  fi

  suite_summary 'lane-commit'
}
