#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-ops "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: ticket-ops（票 41/47 场景沉淀：生成项目语境全链＋fail-closed 负例；票 113 波④
# 夹具树翻 rules/facts 新形态——本体与索引落 facts/requirements/tickets/、账本落
# facts/project/changes.jsonl、脚本落位 rules/implementation/scripts/，金样预期串独立重建；
# 票 191 README 状态列同步合同——状态迁移正例逐链断言 README token↔索引 status 跨载体相等
# ＋状态列规范化前后逐字节相等，负例缺锚/重锚/锚点已在（open 拒开）/缺表锚均 fail-closed
# 零写入）
# ============================================================

tix_body() {
  # $1=本体落盘路径 $2=票 id：最小过 schema 的 task 票本体（含理由两字段，票 79 正例形态；
  # 字段各占一行便于负例 sed 逐字段破坏；无 actual_time——供 flip 硬拦负例使用）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（正例，非空）",
  "priority_reason": "fixture 优先级理由（正例，非空）"
}
EOF
}

tix_body_at() {
  # $1=本体落盘路径 $2=票 id：tix_body 同款＋actual_time 字段（票 100 flip 收口硬拦的
  # 正例形态——flip 目标本体须带非空 actual_time）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（正例，非空）",
  "priority_reason": "fixture 优先级理由（正例，非空）",
  "actual_time": "2h（fixture 净工时占位：会话段累计减中断段）"
}
EOF
}

tix_build_fixture() {
  # $1=夹具项目根（生成项目语境：rules/implementation/scripts/ 落位两件，facts/requirements/tickets
  # 三载体就绪＋facts/project 账本就绪——票 113 波④夹具翻值 rules/facts 新形态；
  # 票 79 起另落位 schema 权威与被 open 票的本体文件）
  F=$1
  rm -rf "$F"
  mkdir -p "$F/rules/implementation/scripts" "$F/facts/requirements/tickets" "$F/facts/project" "$F/agent-up/scripts"
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$F/rules/implementation/scripts/"
  cp "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$F/agent-up/scripts/"
  SCHEMA_SRC="${SCRIPT_DIR}/../references/schemas/ticket-record.schema.json"
  [ -f "$SCHEMA_SRC" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（ticket-ops open 本体校验的 schema 权威）\n' "$SCHEMA_SRC" >&2; exit 2; }
  mkdir -p "$F/agent-up/references/schemas"
  cp "$SCHEMA_SRC" "$F/agent-up/references/schemas/ticket-record.schema.json"
  cat > "$F/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},
    {"id": "20-beta-second", "status": "ready", "complexity": "C2", "blocked_by": [], "updated_at": "2026-09-19T11:00"}
  ]
}
EOF
  cat > "$F/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |
| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |
EOF
  cat > "$F/facts/project/changes.jsonl" <<'EOF'
{"date": "2026-09-19", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture seed", "evidence_ref": "facts/requirements/tickets/index.json"}
EOF
}

tix_state() {
  # 夹具四载体状态指纹（负例零写入断言用）
  {
    cksum "$1/facts/requirements/tickets/index.json" "$1/facts/requirements/tickets/README.md" "$1/facts/project/changes.jsonl"
    if [ -f "$1/facts/requirements/tickets/progress-current.md" ]; then cksum "$1/facts/requirements/tickets/progress-current.md"; else printf 'no-projection\n'; fi
  } | cksum
}

tix_readme_token() {
  # $1=README 路径 $2=NN：`任务票 <NN>；` 锚点后首个闭合反引号状态 token 提取
  # shellcheck disable=SC2016  # sed 模式反引号字面量（状态 token 定界，刻意单引号）
  sed -n 's/.*任务票 '"$2"'；`\([a-z_]*\)`.*/\1/p' "$1"
}

tix_index_status() {
  # $1=索引路径 $2=id：条目行 status 值提取（一条目一行排版）
  sed -n 's/.*"id": "'"$2"'", "status": "\([a-z_]*\)".*/\1/p' "$1"
}

tix_assert_status_sync() {
  # $1=夹具根 $2=id $3=NN：README 状态 token 与索引 status 相等（跨载体一致，票 191 AC1 口径）
  its=$(tix_index_status "$1/facts/requirements/tickets/index.json" "$2")
  rts=$(tix_readme_token "$1/facts/requirements/tickets/README.md" "$3")
  if [ -n "$its" ] && [ "$its" = "$rts" ]; then
    ok "README 状态 token 与索引状态相等（跨载体一致：${2} → ${its}）"
  else
    bad "README 状态 token 与索引状态相等（跨载体一致：${2}）" "索引=${its} README=${rts}"
  fi
}

tix_norm_readme() {
  # $1=README 路径：状态 token 规范化（`<token>` → `STATUS`）后 stdout，其余字节不动——
  # 规范化前后逐字节 cmp 相等即证明状态列之外零变化（独立于金样全文件相等的字节比对口径）
  # shellcheck disable=SC2016  # sed 模式反引号字面量（状态 token 定界，刻意单引号）
  sed 's/；`[a-z_]*`（/；`STATUS`（/' "$1"
}

tix_assert_readme_only_status() {
  # $1=操作前 README 快照 $2=操作后 README 路径 $3=暂存目录 $4=断言名：规范化后逐字节
  # cmp——除状态 token 外全部字节未变（票 191 AC1 字节比对，非出现性 grep；规范化产物落
  # 暂存目录，不污染夹具。适用于 take/flip 原位单 token 替换语义）
  tix_norm_readme "$1" > "$3/norm-before.md"
  tix_norm_readme "$2" > "$3/norm-after.md"
  assert_eq "${4}（状态列规范化后逐字节相等，票 191 AC1）" "$3/norm-after.md" "$3/norm-before.md"
}

tix_assert_readme_append_only() {
  # $1=操作前 README 快照 $2=操作后 README 路径 $3=暂存目录：open 追加语义字节比对——
  # 行数恰 +1 且追加之前的全部既有行逐字节相等（既有行/非状态列零变化，票 191 AC1）
  n=$(wc -l < "$1" | tr -d ' ')
  m=$(wc -l < "$2" | tr -d ' ')
  if [ "$m" -eq $((n + 1)) ]; then
    ok 'open 后 README 行数恰 +1（追加语义，不重写既有行）'
  else
    bad 'open 后 README 行数恰 +1（追加语义，不重写既有行）' "实际 $n → $m"
  fi
  head -n "$n" "$2" > "$3/prefix.md"
  assert_eq 'open 追加之前的既有行逐字节相等（票 191 AC1 字节比对）' "$3/prefix.md" "$1"
}

tix_expected_progress() {
  # 独立重建：三票投影全文（generated_at 行规范化；按 id 升序；头部两路径＝生成器
  # 常量区新形态 issues_index_rel ＋ gen_script_rel 推导，票 113 波④）
  cat <<'EOF'
<!-- generated_from: facts/requirements/tickets/index.json + rules/implementation/scripts/generate-progress.sh -->
<!-- generated_at: NORMALIZED -->
<!-- coverage: facts/requirements/tickets/index.json 登记的全部票，每票一行，按 id 升序 -->
<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 facts/requirements/tickets/index.json 不一致时以索引为准 -->

# 现役状态投影（Derived）

| id | status | checkpoint_ref | updated_at |
| --- | --- | --- | --- |
EOF
  printf '%s\n' \
    '| 10-alpha-first | done |  | 2026-09-19T10:00 |' \
    "| 20-beta-second | $1 |  | $2 |" \
    "| 30-gamma-third | $3 |  | $4 |" | LC_ALL=C sort
}

tix_expect_full() {
  # $1=夹具根 $2=repo30状态 $3=repo30时间 $4=repo20状态 $5=repo20时间 $6=README行30 $7=README行20 $8=账本行数
  F=$1
  {
    printf '{\n  "issues": [\n'
    printf '    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},\n'
    printf '    {"id": "20-beta-second", "status": "%s", "complexity": "C2", "blocked_by": [], "updated_at": "%s"},\n' "$4" "$5"
    printf '    {"id": "30-gamma-third", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "%s"}\n' "$2" "$3"
    printf '  ]\n}\n'
  } > "$F/exp.index.json"
  assert_eq '索引全文件逐一相等（一条目一行，id 锚点单写）' "$F/facts/requirements/tickets/index.json" "$F/exp.index.json"

  {
    printf '# 票据索引（fixture）\n\n| 名字 | 状态 | 说明 |\n| --- | --- | --- |\n'
    # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
    printf '| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |\n'
    printf '%s\n' "$7"
    printf '%s\n' "$6"
  } > "$F/exp.readme.md"
  assert_eq 'issues-README 全文件逐一相等（状态 token 单替换，其余文本不动）' "$F/facts/requirements/tickets/README.md" "$F/exp.readme.md"

  tix_expected_progress "$4" "$5" "$2" "$3" > "$F/exp.progress.md"
  tix_norm_progress "$F/facts/requirements/tickets/progress-current.md" > "$F/act.progress.md"
  assert_eq '投影全文件逐一相等（generated_at 规范化后 cmp，票 35 三路径口径）' "$F/act.progress.md" "$F/exp.progress.md"

  n=$(wc -l < "$F/facts/project/changes.jsonl" | tr -d ' ')
  if [ "$n" -eq "$8" ]; then
    ok "账本行数＝$8（一行一事实，追加不重写）"
  else
    bad "账本行数＝$8（一行一事实，追加不重写）" "实际 $n"
  fi
}

suite_ticket_ops() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='ticket-ops'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/tix
  mkdir -p "$D"
  tix_build_fixture "$D/fix"
  F=$D/fix
  # 票 79：被 open 票的本体文件落位（正例 30 全链＋负例 N1 的 10／N3 的 40，
  # 保证各负例仍命中原语义路径而非被本体缺失提前拦截）；
  # 票 100：flip 目标本体（20-beta-second）落位含 actual_time 的正例形态——flip 收口
  # 硬拦生效后，flip 正例链须本体带非空 actual_time 方可通过。
  tix_body "$F/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  tix_body "$F/facts/requirements/tickets/10-alpha-first.json" 10-alpha-first
  tix_body "$F/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  tix_body_at "$F/facts/requirements/tickets/20-beta-second.json" 20-beta-second

  # 票 183：新 task 的 verification 门禁必须由 ticket-ops open 入口执行，存量形态只在读取面兼容。
  F183="$D/fix183"
  tix_build_fixture "$F183"
  F="$D/fix"
  TIX183="$F183/facts/requirements/tickets/30-gamma-third.json"
  for legacy_shape in legacy-string legacy-array; do
    tix_body "$TIX183" 30-gamma-third
    python3 - "$TIX183" "$legacy_shape" <<'PYTHON'
import json, sys
path, shape = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    body = json.load(f)
body['verification'] = 'legacy prose' if shape == 'legacy-string' else ['legacy predicate']
with open(path, 'w', encoding='utf-8') as f:
    json.dump(body, f)
PYTHON
    if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$TIX183" >/dev/null 2>&1; then
      ok "正例 183-legacy-$legacy_shape 存量 verification 读取兼容"
    else
      bad "正例 183-legacy-$legacy_shape 存量 verification 读取兼容"
    fi
  done
  for new_shape in missing legacy-string legacy-array mixed-array; do
    tix_body "$TIX183" 30-gamma-third
    python3 - "$TIX183" "$new_shape" <<'PYTHON'
import json, sys
path, shape = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    body = json.load(f)
if shape == 'missing':
    body.pop('verification')
elif shape == 'legacy-string':
    body['verification'] = 'legacy prose'
elif shape == 'legacy-array':
    body['verification'] = ['legacy predicate']
else:
    body['verification'] = [body['verification'][0], 'legacy predicate']
with open(path, 'w', encoding='utf-8') as f:
    json.dump(body, f)
PYTHON
    TIX183_BEFORE=$(tix_state "$F183")
    sh "$F183/rules/implementation/scripts/ticket-ops.sh" "$F183" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line '{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open 183", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}' >"$D/open-183-$new_shape.log" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && [ "$TIX183_BEFORE" = "$(tix_state "$F183")" ]; then
      ok "负例 183-open-$new_shape ticket-ops 拒绝新 task verification 形态且零写入"
    else
      bad "负例 183-open-$new_shape ticket-ops 拒绝新 task verification 形态且零写入" "exit=$rc $(head -n 2 "$D/open-183-$new_shape.log" | tr '\n' '|')"
    fi
  done

  LED_OPEN='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  LED_TAKE='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture take 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  LED_FLIP='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture flip 20", "evidence_ref": "facts/requirements/tickets/20-beta-second.json"}'

  # ---- 正例全链：open → take → flip（生成项目语境：脚本落位 rules/implementation/scripts/，
  # repo-root 传参指明项目根＝$F）----
  # 票 191 AC1：每步操作前快照 README，操作后断言（a）README 状态 token＝索引 status（跨载体
  # 一致）（b）状态列规范化后前后逐字节相等——状态列之外零变化，字节比对独立于下方金样全文件相等
  cp "$F/facts/requirements/tickets/README.md" "$D/rd-before-open.md"
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/open.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'open exit 0（生成项目语境，repo-root 显式传参）'
  else
    bad 'open exit 0（生成项目语境，repo-root 显式传参）' "exit=$rc $(head -n 2 "$D/open.log" | tr '\n' '|')"
  fi

  UA30=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/facts/requirements/tickets/index.json" | tail -n 1)
  case $UA30 in
    ????-??-??T??:??) ;;
    *) bad 'open 后索引条目 updated_at 形状（YYYY-MM-DDTHH:MM）' "实际: $UA30" ;;
  esac
  TODAY=$(sed -n 's/.*（\(20[0-9-]*\) 开票）.*/\1/p' "$F/facts/requirements/tickets/README.md" | tail -n 1)
  case $TODAY in
    20??-??-??) ;;
    *) bad 'open 后 README 行开票日期形状' "实际: $TODAY" ;;
  esac
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  ROW30='| `30-gamma-third.json` | 任务票 30；`ready`（'"$TODAY"' 开票） | Gamma fixture ticket |'
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  tix_expect_full "$F" 'ready' "$UA30" 'ready' '2026-09-19T11:00' "$ROW30" '| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |' 2
  tix_assert_status_sync "$F" 30-gamma-third 30
  tix_assert_readme_append_only "$D/rd-before-open.md" "$F/facts/requirements/tickets/README.md" "$D"

  cp "$F/facts/requirements/tickets/README.md" "$D/rd-before-take.md"
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" take --id 30-gamma-third --status in_progress --ledger-line "$LED_TAKE" >"$D/take.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'take exit 0（领取语义 status=in_progress）'
  else
    bad 'take exit 0（领取语义 status=in_progress）' "exit=$rc $(head -n 2 "$D/take.log" | tr '\n' '|')"
  fi
  UA30B=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/facts/requirements/tickets/index.json" | tail -n 1)
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  ROW30B='| `30-gamma-third.json` | 任务票 30；`in_progress`（'"$TODAY"' 开票） | Gamma fixture ticket |'
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  tix_expect_full "$F" 'in_progress' "$UA30B" 'ready' '2026-09-19T11:00' "$ROW30B" '| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |' 3
  tix_assert_status_sync "$F" 30-gamma-third 30
  tix_assert_readme_only_status "$D/rd-before-take.md" "$F/facts/requirements/tickets/README.md" "$D" 'take 前后 README 状态列之外零变化'

  cp "$F/facts/requirements/tickets/README.md" "$D/rd-before-flip.md"
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 20-beta-second --status review_ready --ledger-line "$LED_FLIP" >"$D/flip.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'flip exit 0（状态机任意合法值翻转）'
  else
    bad 'flip exit 0（状态机任意合法值翻转）' "exit=$rc $(head -n 2 "$D/flip.log" | tr '\n' '|')"
  fi
  UA20=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/facts/requirements/tickets/index.json" | sed -n '2p')
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  ROW20B='| `20-beta-second.json` | 任务票 20；`review_ready`（2026-09-19 开票） | Beta fixture ticket |'
  tix_expect_full "$F" 'in_progress' "$UA30B" 'review_ready' "$UA20" "$ROW30B" "$ROW20B" 4
  tix_assert_status_sync "$F" 20-beta-second 20
  tix_assert_readme_only_status "$D/rd-before-flip.md" "$F/facts/requirements/tickets/README.md" "$D" 'flip 前后 README 状态列之外零变化'

  sh "$F/rules/implementation/scripts/generate-progress.sh" --check "$F" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '收尾投影 --check exit 0（全链后一致性核对）'
  else
    bad '收尾投影 --check exit 0（全链后一致性核对）' "exit=$rc"
  fi

  # ---- 负例（fail-closed 零写入；N5 用独立夹具）----
  S0=$(tix_state "$F")
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 10-alpha-first --complexity C1 --title dup --ledger-line "$LED_OPEN" >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ]; then
    ok '负例 N1 重复 id open → exit 1 零写入（open 非幂等）'
  else
    bad '负例 N1 重复 id open → exit 1 零写入（open 非幂等）' "exit/状态不符"
  fi
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 99-ghost-none --status 'done' --ledger-line "$LED_FLIP" >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ]; then
    ok '负例 N2 未知 id flip → exit 1 零写入'
  else
    bad '负例 N2 未知 id flip → exit 1 零写入' "exit/状态不符"
  fi
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 40-delta-fourth --complexity C0 --title d --ledger-line '{"kind": "scope", "date": "2026-09-20", "scope": "x", "decision": "bad-order", "evidence_ref": "y"}' >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ]; then
    ok '负例 N3 账本键序违规 → exit 1 零写入'
  else
    bad '负例 N3 账本键序违规 → exit 1 零写入' "exit/状态不符"
  fi
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" take --id 20-beta-second --status ready --ledger-line "$LED_FLIP" >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ]; then
    ok '负例 N4 take 非 in_progress → exit 1 零写入'
  else
    bad '负例 N4 take 非 in_progress → exit 1 零写入' "exit/状态不符"
  fi
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 20-beta-second --status bogus_status --ledger-line "$LED_FLIP" >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ]; then
    ok '负例 N6 非法状态值 → exit 1 零写入'
  else
    bad '负例 N6 非法状态值 → exit 1 零写入' "exit/状态不符"
  fi

  # ---- 票 191 断言：README 状态列同步合同——锚点缺失/重复 fail-closed 零写入，open 追加
  # 语义要求锚点零命中（已存在即拒，不制造重复锚点）。负例逐例独立夹具：tix_state 四载体
  # 指纹（含投影缺席）零写入＋exit 1＋报文指名锚点；正例控制证明零命中路径不受新预检影响。
  # N-rd1：README 缺该票行（缺锚）→ flip 恰 1 行预检停止
  tix_build_fixture "$D/fixrd1"
  Frd1=$D/fixrd1
  tix_body_at "$Frd1/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  sed '/任务票 20；/d' "$Frd1/facts/requirements/tickets/README.md" > "$Frd1/rd.tmp" && mv "$Frd1/rd.tmp" "$Frd1/facts/requirements/tickets/README.md"
  Srd1=$(tix_state "$Frd1")
  sh "$Frd1/rules/implementation/scripts/ticket-ops.sh" "$Frd1" flip --id 20-beta-second --status review_ready --ledger-line "$LED_FLIP" >"$D/rd1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$Srd1" = "$(tix_state "$Frd1")" ] && [ ! -f "$Frd1/facts/requirements/tickets/progress-current.md" ] && grep -q '任务票 20' "$D/rd1.log"; then
    ok '负例 N-rd1 README 缺该票行（缺锚）flip → exit 1 零写入且报文指名锚点（票 191 AC2）'
  else
    bad '负例 N-rd1 README 缺该票行（缺锚）flip → exit 1 零写入且报文指名锚点（票 191 AC2）' "exit=$rc $(head -n 2 "$D/rd1.log" | tr '\n' '|')"
  fi

  # N-rd2：README 该票行重复（重锚）→ take 恰 1 行预检停止（锚点不唯一不猜测更新对象）
  tix_build_fixture "$D/fixrd2"
  Frd2=$D/fixrd2
  tix_body_at "$Frd2/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  awk '{ print } /任务票 20；/ { print }' "$Frd2/facts/requirements/tickets/README.md" > "$Frd2/rd.tmp" && mv "$Frd2/rd.tmp" "$Frd2/facts/requirements/tickets/README.md"
  Srd2=$(tix_state "$Frd2")
  sh "$Frd2/rules/implementation/scripts/ticket-ops.sh" "$Frd2" take --id 20-beta-second --status in_progress --ledger-line "$LED_TAKE" >"$D/rd2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$Srd2" = "$(tix_state "$Frd2")" ] && [ ! -f "$Frd2/facts/requirements/tickets/progress-current.md" ] && grep -q '命中 2 行' "$D/rd2.log"; then
    ok '负例 N-rd2 README 该票行重复（重锚）take → exit 1 零写入且报明命中行数（票 191 AC2）'
  else
    bad '负例 N-rd2 README 该票行重复（重锚）take → exit 1 零写入且报明命中行数（票 191 AC2）' "exit=$rc $(head -n 2 "$D/rd2.log" | tr '\n' '|')"
  fi

  # N-rd3：open 追加语义锚点已在场（索引↔README 漂移）→ 拒开零写入（照追加将制造重复锚点，
  # 该票 take/flip 恰 1 行预检永不过）
  tix_build_fixture "$D/fixrd3"
  Frd3=$D/fixrd3
  tix_body "$Frd3/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  cat >> "$Frd3/facts/requirements/tickets/README.md" <<'EOF'
| `30-gamma-third.json` | 任务票 30；`ready`（2026-09-19 开票） | drifted stale row |
EOF
  Srd3=$(tix_state "$Frd3")
  sh "$Frd3/rules/implementation/scripts/ticket-ops.sh" "$Frd3" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/rd3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$Srd3" = "$(tix_state "$Frd3")" ] && [ ! -f "$Frd3/facts/requirements/tickets/progress-current.md" ] && grep -q '锚点行已存在' "$D/rd3.log"; then
    ok '负例 N-rd3 README 锚点已存在时 open → exit 1 零写入（追加语义要求零命中，票 191 AC2）'
  else
    bad '负例 N-rd3 README 锚点已存在时 open → exit 1 零写入（追加语义要求零命中，票 191 AC2）' "exit=$rc $(head -n 2 "$D/rd3.log" | tr '\n' '|')"
  fi
  # 正例控制：删除漂移行后同 id open 照旧 exit 0 且索引落条目（零命中路径不受新预检影响）
  sed '/任务票 30；/d' "$Frd3/facts/requirements/tickets/README.md" > "$Frd3/rd.tmp" && mv "$Frd3/rd.tmp" "$Frd3/facts/requirements/tickets/README.md"
  sh "$Frd3/rules/implementation/scripts/ticket-ops.sh" "$Frd3" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/rd3p.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "30-gamma-third"' "$Frd3/facts/requirements/tickets/index.json"; then
    ok '正例 锚点零命中后同 id open → exit 0 且索引落条目（新锚点预检零误伤，票 191）'
  else
    bad '正例 锚点零命中后同 id open → exit 0 且索引落条目（新锚点预检零误伤，票 191）' "exit=$rc $(head -n 2 "$D/rd3p.log" | tr '\n' '|')"
  fi

  # N-rd4：open 缺表锚（README 目录清单表行零命中）→ 表行预检停止零写入（追加无处可附）
  tix_build_fixture "$D/fixrd4"
  Frd4=$D/fixrd4
  tix_body "$Frd4/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  sed '/^| `/d' "$Frd4/facts/requirements/tickets/README.md" > "$Frd4/rd.tmp" && mv "$Frd4/rd.tmp" "$Frd4/facts/requirements/tickets/README.md"
  Srd4=$(tix_state "$Frd4")
  sh "$Frd4/rules/implementation/scripts/ticket-ops.sh" "$Frd4" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/rd4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$Srd4" = "$(tix_state "$Frd4")" ] && [ ! -f "$Frd4/facts/requirements/tickets/progress-current.md" ] && grep -q '目录清单表行' "$D/rd4.log"; then
    ok '负例 N-rd4 README 目录清单表行零命中（缺表锚）open → exit 1 零写入（票 191 AC2）'
  else
    bad '负例 N-rd4 README 目录清单表行零命中（缺表锚）open → exit 1 零写入（票 191 AC2）' "exit=$rc $(head -n 2 "$D/rd4.log" | tr '\n' '|')"
  fi

  # N5：索引一条目一行排版破坏（条目缺 updated_at）→ 预检停止，零写入且无投影
  tix_build_fixture "$D/fix5"
  F5=$D/fix5
  tix_body "$F5/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  sed 's/"updated_at": "2026-09-19T10:00"/"note": "排版破坏"/' "$F5/facts/requirements/tickets/index.json" > "$F5/idx.tmp" && mv "$F5/idx.tmp" "$F5/facts/requirements/tickets/index.json"
  S5=$(tix_state "$F5")
  sh "$F5/rules/implementation/scripts/ticket-ops.sh" "$F5" open --id 40-delta-fourth --complexity C0 --title d --ledger-line "$LED_OPEN" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S5" = "$(tix_state "$F5")" ] && [ ! -f "$F5/facts/requirements/tickets/progress-current.md" ]; then
    ok '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）'
  else
    bad '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）' "exit=$rc"
  fi

  # N7/N8/正例：独立夹具（tix_build_fixture 会重赋 F，勿依赖前段 F 指向）——
  # 同 NN 异 slug 撞号拒开（票 77，账本 renumber-70-72 缺口）＋畸形 id 一并拒＋新 NN 正开零回归
  tix_build_fixture "$D/fix7"
  F7=$D/fix7
  S7=$(tix_state "$F7")
  # 票 79 起本体校验前置：gamma-clone 本体先落位（tix_body 正例形态含理由两字段），流程方能到达 NN 段查重
  tix_body "$F7/facts/requirements/tickets/20-gamma-clone.json" 20-gamma-clone
  sh "$F7/rules/implementation/scripts/ticket-ops.sh" "$F7" open --id 20-gamma-clone --complexity C1 --title d --ledger-line "$LED_OPEN" >"$D/nn7.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S7" = "$(tix_state "$F7")" ] && grep -q '20-beta-second' "$D/nn7.log"; then
    ok '负例 N7 同 NN 异 slug open → exit 1 零写入且报明已占完整 id（票 77 NN 唯一性）'
  else
    bad '负例 N7 同 NN 异 slug open → exit 1 零写入且报明已占完整 id（票 77 NN 唯一性）' "exit=$rc $(head -n 2 "$D/nn7.log" | tr '\n' '|')"
  fi

  # N8：畸形 id（NN 段不合 ^[0-9]{2,}-）→ 一并拒，零写入（NN 段提取与 id 正则一致，防绕过段查重）
  sh "$F7/rules/implementation/scripts/ticket-ops.sh" "$F7" open --id 7-short-nn --complexity C1 --title d --ledger-line "$LED_OPEN" >/dev/null 2>&1
  if [ "$?" -eq 1 ] && [ "$S7" = "$(tix_state "$F7")" ]; then
    ok '负例 N8 畸形 id（个位 NN 段）open → exit 1 零写入（id 口径门先拦）'
  else
    bad '负例 N8 畸形 id（个位 NN 段）open → exit 1 零写入（id 口径门先拦）' "exit/状态不符"
  fi

  # 正例：同夹具换新 NN 新 slug 正常开票照旧（open 成功路径零回归；票 79 起本体先落位——
  # tix_body 正例形态含理由两字段，过本体校验后走完全链）
  tix_body "$F7/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  sh "$F7/rules/implementation/scripts/ticket-ops.sh" "$F7" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line "$LED_OPEN" >"$D/nn-pos.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "40-delta-fourth"' "$F7/facts/requirements/tickets/index.json"; then
    ok '正例 新 NN 新 slug open → exit 0 且索引落条目（正常开票零回归，票 77 后）'
  else
    bad '正例 新 NN 新 slug open → exit 0 且索引落条目（正常开票零回归，票 77 后）' "exit=$rc $(head -n 2 "$D/nn-pos.log" | tr '\n' '|')"
  fi

  # ---- 票 79 断言：open 本体 schema 校验＋理由非空（拒缺理由＋放过正常）----
  # 放过正常＝本套件正例全链 open（本体含理由两字段）照旧 exit 0 并全链落地；
  # 拒缺理由三负例（N-r1 缺 complexity_reason／N-r2 priority_reason 空值／N-r3 缺本体）
  # 均 exit 1、零写入，且报文指名缺失项。
  # 票 100：fix7 内 20-beta-second 是后续对照组 flip 目标，本体补落 actual_time 正例形态
  # （flip 收口硬拦生效后，flip 目标本体须带非空 actual_time 方可通过；本体不入 tix_state
  # 指纹，前段零写入断言不受影响）。
  tix_body_at "$F/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  tix_body "$F/facts/requirements/tickets/50-epsilon-fifth.json" 50-epsilon-fifth
  sed '/"complexity_reason"/d' "$F/facts/requirements/tickets/50-epsilon-fifth.json" > "$D/b1.tmp" && mv "$D/b1.tmp" "$F/facts/requirements/tickets/50-epsilon-fifth.json"
  S79=$(tix_state "$F")
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 50-epsilon-fifth --complexity C1 --title eps --ledger-line "$LED_OPEN" >"$D/nr1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q 'complexity_reason' "$D/nr1.log"; then
    ok '负例 N-r1 本体缺 complexity_reason → exit 1 零写入且报文指名字段（票 79）'
  else
    bad '负例 N-r1 本体缺 complexity_reason → exit 1 零写入且报文指名字段（票 79）' "exit=$rc $(head -n 2 "$D/nr1.log" | tr '\n' '|')"
  fi

  tix_body "$F/facts/requirements/tickets/51-zeta-sixth.json" 51-zeta-sixth
  sed 's/"priority_reason": "fixture 优先级理由（正例，非空）"/"priority_reason": ""/' "$F/facts/requirements/tickets/51-zeta-sixth.json" > "$D/b2.tmp" && mv "$D/b2.tmp" "$F/facts/requirements/tickets/51-zeta-sixth.json"
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 51-zeta-sixth --complexity C1 --title zeta --ledger-line "$LED_OPEN" >"$D/nr2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q 'priority_reason' "$D/nr2.log"; then
    ok '负例 N-r2 本体 priority_reason 空值 → exit 1 零写入且报文指名字段（票 79）'
  else
    bad '负例 N-r2 本体 priority_reason 空值 → exit 1 零写入且报文指名字段（票 79）' "exit=$rc $(head -n 2 "$D/nr2.log" | tr '\n' '|')"
  fi

  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 60-eta-seventh --complexity C1 --title eta --ledger-line "$LED_OPEN" >"$D/nr3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q '新票本体不存在' "$D/nr3.log"; then
    ok '负例 N-r3 本体文件缺失 → exit 1 零写入（先落位本体再开票，票 79）'
  else
    bad '负例 N-r3 本体文件缺失 → exit 1 零写入（先落位本体再开票，票 79）' "exit=$rc $(head -n 2 "$D/nr3.log" | tr '\n' '|')"
  fi

  # ---- 票 81 断言：账本行型扩展（lesson/replan 条件键＋promoted_to 枚举）----
  # 正例四：lesson（promoted_to=sop）open 收录、replan（三键齐）open 收录、
  # lesson（promoted_to=none 枚举边界）take 收录、对照组既有五键 kind=change 行 flip
  # 照旧（向后兼容：链脚本生成面零回归）；负例四各自 exit 1 零写入且报明原因。
  tix_body "$F/facts/requirements/tickets/61-iota-eighth.json" 61-iota-eighth
  LED_LESSON='{"date": "2026-09-24", "kind": "lesson", "scope": "facts/requirements/tickets", "decision": "fixture lesson 61", "evidence_ref": "facts/requirements/tickets/61-iota-eighth.json", "promoted_to": "sop"}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 61-iota-eighth --complexity C1 --title iota --ledger-line "$LED_LESSON" >"$D/ls1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$F/facts/project/changes.jsonl")" = "$LED_LESSON" ]; then
    ok '正例 lesson 行 open → exit 0 且账本收录（promoted_to=sop，票 81 行型）'
  else
    bad '正例 lesson 行 open → exit 0 且账本收录（promoted_to=sop，票 81 行型）' "exit=$rc $(head -n 2 "$D/ls1.log" | tr '\n' '|')"
  fi

  tix_body "$F/facts/requirements/tickets/62-kappa-ninth.json" 62-kappa-ninth
  LED_REPLAN='{"date": "2026-09-24", "kind": "replan", "scope": "facts/requirements/tickets", "decision": "fixture replan 62", "evidence_ref": "facts/requirements/tickets/62-kappa-ninth.json", "replan_original": true, "replan_replacement": false, "replan_undone": true}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" open --id 62-kappa-ninth --complexity C1 --title kappa --ledger-line "$LED_REPLAN" >"$D/ls2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$F/facts/project/changes.jsonl")" = "$LED_REPLAN" ]; then
    ok '正例 replan 行 open → exit 0 且账本收录（三条件键齐，票 81 行型）'
  else
    bad '正例 replan 行 open → exit 0 且账本收录（三条件键齐，票 81 行型）' "exit=$rc $(head -n 2 "$D/ls2.log" | tr '\n' '|')"
  fi

  LED_LESSON_NONE='{"date": "2026-09-24", "kind": "lesson", "scope": "facts/requirements/tickets", "decision": "fixture lesson none 61", "evidence_ref": "facts/requirements/tickets/61-iota-eighth.json", "promoted_to": "none"}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" take --id 61-iota-eighth --status in_progress --ledger-line "$LED_LESSON_NONE" >"$D/ls3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$F/facts/project/changes.jsonl")" = "$LED_LESSON_NONE" ]; then
    ok '正例 lesson 行 take → exit 0 且账本收录（promoted_to=none 枚举边界亦合法，票 81）'
  else
    bad '正例 lesson 行 take → exit 0 且账本收录（promoted_to=none 枚举边界亦合法，票 81）' "exit=$rc $(head -n 2 "$D/ls3.log" | tr '\n' '|')"
  fi

  LED_CHANGE='{"date": "2026-09-24", "kind": "change", "scope": "facts/requirements/tickets", "decision": "fixture flip 20 change-row", "evidence_ref": "facts/requirements/tickets/20-beta-second.json"}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 20-beta-second --status review_pass --ledger-line "$LED_CHANGE" >"$D/ls4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$F/facts/project/changes.jsonl")" = "$LED_CHANGE" ]; then
    ok '对照组 既有五键 kind=change 行 flip → exit 0（向后兼容：链脚本生成面零回归，票 81）'
  else
    bad '对照组 既有五键 kind=change 行 flip → exit 0（向后兼容：链脚本生成面零回归，票 81）' "exit=$rc $(head -n 2 "$D/ls4.log" | tr '\n' '|')"
  fi

  S81=$(tix_state "$F")
  # 票 100：61/62 本体补落 actual_time 正例形态（N-81 组 flip 目标须过收口硬拦，
  # 否则负例被 actual_time 缺项提前拦截、命不中行型断言语义路径）
  tix_body_at "$F/facts/requirements/tickets/61-iota-eighth.json" 61-iota-eighth
  tix_body_at "$F/facts/requirements/tickets/62-kappa-ninth.json" 62-kappa-ninth
  LED_LESSON_MISSING='{"date": "2026-09-24", "kind": "lesson", "scope": "facts/requirements/tickets", "decision": "fixture lesson missing", "evidence_ref": "facts/requirements/tickets/61-iota-eighth.json"}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 61-iota-eighth --status in_progress --ledger-line "$LED_LESSON_MISSING" >"$D/ln1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S81" = "$(tix_state "$F")" ] && grep -q 'promoted_to' "$D/ln1.log"; then
    ok '负例 N-81a lesson 缺 promoted_to → exit 1 零写入且报文指名（票 81）'
  else
    bad '负例 N-81a lesson 缺 promoted_to → exit 1 零写入且报文指名（票 81）' "exit=$rc $(head -n 2 "$D/ln1.log" | tr '\n' '|')"
  fi

  LED_LESSON_BAD='{"date": "2026-09-24", "kind": "lesson", "scope": "facts/requirements/tickets", "decision": "fixture lesson bad-enum", "evidence_ref": "facts/requirements/tickets/61-iota-eighth.json", "promoted_to": "refactor"}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 61-iota-eighth --status in_progress --ledger-line "$LED_LESSON_BAD" >"$D/ln2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S81" = "$(tix_state "$F")" ] && grep -q '越枚举' "$D/ln2.log"; then
    ok '负例 N-81b promoted_to=refactor 越枚举 → exit 1 零写入且报明枚举（票 81 不静默收编）'
  else
    bad '负例 N-81b promoted_to=refactor 越枚举 → exit 1 零写入且报明枚举（票 81 不静默收编）' "exit=$rc $(head -n 2 "$D/ln2.log" | tr '\n' '|')"
  fi

  LED_REPLAN_MISSING='{"date": "2026-09-24", "kind": "replan", "scope": "facts/requirements/tickets", "decision": "fixture replan missing", "evidence_ref": "facts/requirements/tickets/62-kappa-ninth.json", "replan_original": true, "replan_replacement": false}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 62-kappa-ninth --status in_progress --ledger-line "$LED_REPLAN_MISSING" >"$D/ln3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S81" = "$(tix_state "$F")" ] && grep -q 'replan_undone' "$D/ln3.log"; then
    ok '负例 N-81c replan 缺 replan_undone → exit 1 零写入且报文指名（票 81）'
  else
    bad '负例 N-81c replan 缺 replan_undone → exit 1 零写入且报文指名（票 81）' "exit=$rc $(head -n 2 "$D/ln3.log" | tr '\n' '|')"
  fi

  LED_REPLAN_ORDER='{"date": "2026-09-24", "kind": "replan", "scope": "facts/requirements/tickets", "decision": "fixture replan bad-order", "evidence_ref": "facts/requirements/tickets/62-kappa-ninth.json", "replan_replacement": false, "replan_original": true, "replan_undone": true}'
  sh "$F/rules/implementation/scripts/ticket-ops.sh" "$F" flip --id 62-kappa-ninth --status in_progress --ledger-line "$LED_REPLAN_ORDER" >"$D/ln4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S81" = "$(tix_state "$F")" ] && grep -q '账本行不合键序或形状' "$D/ln4.log"; then
    ok '负例 N-81d replan 条件键序破坏 → exit 1 零写入（条件键序稳定不放宽，票 81）'
  else
    bad '负例 N-81d replan 条件键序破坏 → exit 1 零写入（条件键序稳定不放宽，票 81）' "exit=$rc $(head -n 2 "$D/ln4.log" | tr '\n' '|')"
  fi

  # ---- 票 100 断言：flip actual_time 收口硬拦＋ledger 无票账本行入口 ----
  # 独立夹具（索引两票：31-at-clip 任务票＋32-at-req 请求票），逐负例重建本体：
  # N-100a actual_time 空值／N-100b 字段缺失／N-100c 本体文件缺失均 exit 1 零写入且
  # 报文指名票 id 与 actual_time；N-100d request 本体 flip 照旧 exit 0（不校验）；
  # N-100e/f/g ledger 无票入口键序违规零写入／合法行收录／缺省根语境。
  tix_build_fixture "$D/fix100"
  F100=$D/fix100
  # 索引补两条目（一条目一行排版保持——文本级插入，条目行含同行 status/updated_at）
  sed 's/^  ]$/    {"id": "31-at-clip", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-29T10:00"},\
    {"id": "32-at-req", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-29T10:01"}\
  ]/' "$F100/facts/requirements/tickets/index.json" > "$F100/idx100.tmp" && mv "$F100/idx100.tmp" "$F100/facts/requirements/tickets/index.json"
  # issues-README 补两状态行（flip 预检要求锚点恰 1 行）
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`31-at-clip.json\` | 任务票 31；\`in_progress\`（2026-09-29 开票） | AT clip fixture |\n' >> "$F100/facts/requirements/tickets/README.md"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`32-at-req.json\` | 任务票 32；\`in_progress\`（2026-09-29 开票） | AT req fixture |\n' >> "$F100/facts/requirements/tickets/README.md"
  LED_AT='{"date": "2026-09-29", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture at 100", "evidence_ref": "facts/requirements/tickets/31-at-clip.json"}'

  tix_body_at "$F100/facts/requirements/tickets/31-at-clip.json" 31-at-clip
  sed 's/"actual_time": "2h（fixture 净工时占位：会话段累计减中断段）"/"actual_time": ""/' "$F100/facts/requirements/tickets/31-at-clip.json" > "$F100/at1.tmp" && mv "$F100/at1.tmp" "$F100/facts/requirements/tickets/31-at-clip.json"
  S100=$(tix_state "$F100")
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" flip --id 31-at-clip --status 'done' --ledger-line "$LED_AT" >"$D/at1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S100" = "$(tix_state "$F100")" ] && grep -q 'actual_time' "$D/at1.log" && grep -q '31-at-clip' "$D/at1.log"; then
    ok '负例 N-100a flip 本体 actual_time 空值 → exit 1 零写入且指名票 id 与缺项（票 100 fail-closed）'
  else
    bad '负例 N-100a flip 本体 actual_time 空值 → exit 1 零写入且指名票 id 与缺项（票 100 fail-closed）' "exit=$rc $(head -n 2 "$D/at1.log" | tr '\n' '|')"
  fi

  # N-100b：字段缺失（tix_body 正例形态无 actual_time）
  tix_body "$F100/facts/requirements/tickets/31-at-clip.json" 31-at-clip
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" flip --id 31-at-clip --status 'done' --ledger-line "$LED_AT" >"$D/at2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S100" = "$(tix_state "$F100")" ] && grep -q 'actual_time' "$D/at2.log" && grep -q '31-at-clip' "$D/at2.log"; then
    ok '负例 N-100b flip 本体缺 actual_time 字段 → exit 1 零写入且指名票 id 与缺项（票 100）'
  else
    bad '负例 N-100b flip 本体缺 actual_time 字段 → exit 1 零写入且指名票 id 与缺项（票 100）' "exit=$rc $(head -n 2 "$D/at2.log" | tr '\n' '|')"
  fi

  # N-100c：本体文件缺失
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" flip --id 31-at-clip --status 'done' --ledger-line "$LED_AT" >"$D/at3.log" 2>&1
  rc=$?
  rm -f "$F100/facts/requirements/tickets/31-at-clip.json"
  if [ "$rc" -eq 1 ] && [ "$S100" = "$(tix_state "$F100")" ] && grep -q 'actual_time' "$D/at3.log" && grep -q '31-at-clip' "$D/at3.log"; then
    ok '负例 N-100c flip 本体文件缺失 → exit 1 零写入且指名票 id 与缺项（票 100）'
  else
    bad '负例 N-100c flip 本体文件缺失 → exit 1 零写入且指名票 id 与缺项（票 100）' "exit=$rc $(head -n 2 "$D/at3.log" | tr '\n' '|')"
  fi

  # N-100d：request 票不校验——request 本体 flip 照旧 exit 0 且索引单写
  cat > "$F100/facts/requirements/tickets/32-at-req.json" <<'EOF'
{
  "id": "32-at-req",
  "kind": "request",
  "title": "fixture request（不校验 actual_time）",
  "created_at": "2026-09-29"
}
EOF
  LED_AT_REQ='{"date": "2026-09-29", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture at req 100", "evidence_ref": "facts/requirements/tickets/32-at-req.json"}'
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" flip --id 32-at-req --status 'done' --ledger-line "$LED_AT_REQ" >"$D/at4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "32-at-req", "status": "done"' "$F100/facts/requirements/tickets/index.json"; then
    ok '正例 N-100d request 票 flip → exit 0 且索引单写（request 不校验 actual_time，票 100）'
  else
    bad '正例 N-100d request 票 flip → exit 0 且索引单写（request 不校验 actual_time，票 100）' "exit=$rc $(head -n 2 "$D/at4.log" | tr '\n' '|')"
  fi

  # N-100e：ledger 账本行键序违规 → exit 1 零写入（形状校验先于写入，同 --ledger-line 口径）
  LED_LEDGER_OK='{"date": "2026-09-29", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture ledger 100", "evidence_ref": "facts/requirements/tickets/README.md"}'
  LED_LEDGER_BAD='{"kind": "scope", "date": "2026-09-29", "scope": "x", "decision": "bad-order", "evidence_ref": "y"}'
  n_before=$(wc -l < "$F100/facts/project/changes.jsonl" | tr -d ' ')
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" ledger --ledger-line "$LED_LEDGER_BAD" >"$D/lg1.log" 2>&1
  rc=$?
  n_after=$(wc -l < "$F100/facts/project/changes.jsonl" | tr -d ' ')
  if [ "$rc" -eq 1 ] && [ "$n_after" -eq "$n_before" ] && grep -q '键序' "$D/lg1.log"; then
    ok '负例 N-100e ledger 账本行键序违规 → exit 1 零写入（形状校验先于写入，票 100）'
  else
    bad '负例 N-100e ledger 账本行键序违规 → exit 1 零写入（形状校验先于写入，票 100）' "exit=$rc 行数 $n_before→$n_after $(head -n 2 "$D/lg1.log" | tr '\n' '|')"
  fi

  # 正例 N-100f：ledger 合法行 → exit 0 账本收录且无索引/README/投影写入
  rm -f "$F100/facts/requirements/tickets/progress-current.md"
  sh "$F100/rules/implementation/scripts/ticket-ops.sh" "$F100" ledger --ledger-line "$LED_LEDGER_OK" >"$D/lg2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$F100/facts/project/changes.jsonl")" = "$LED_LEDGER_OK" ] && [ ! -f "$F100/facts/requirements/tickets/progress-current.md" ]; then
    ok '正例 N-100f ledger 合法行 → exit 0 账本收录（无票面写入无投影再生，票 100）'
  else
    bad '正例 N-100f ledger 合法行 → exit 0 账本收录（无票面写入无投影再生，票 100）' "exit=$rc $(head -n 2 "$D/lg2.log" | tr '\n' '|')"
  fi

  # 正例 N-100g：ledger 缺省根语境（生成项目落位形态：rules/implementation/scripts/ 落位，
  # 缺省根＝脚本所在目录上三级，即仓根——账本落 facts/project/changes.jsonl，
  # 按引擎缺省根推导现值重述，票 158 修复）同款工作
  mkdir -p "$D/fix-l/rules/implementation/scripts" "$D/fix-l/facts/project"
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$D/fix-l/rules/implementation/scripts/"
  : > "$D/fix-l/facts/project/changes.jsonl"
  ( cd "$D/fix-l" && sh rules/implementation/scripts/ticket-ops.sh ledger --ledger-line "$LED_LEDGER_OK" ) >"$D/lg3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tail -n 1 "$D/fix-l/facts/project/changes.jsonl")" = "$LED_LEDGER_OK" ]; then
    ok '正例 N-100g ledger 缺省根语境（rules/implementation/scripts/ 落位形态）→ exit 0 账本收录（票 100）'
  else
    bad '正例 N-100g ledger 缺省根语境（rules/implementation/scripts/ 落位形态）→ exit 0 账本收录（票 100）' "exit=$rc $(head -n 2 "$D/lg3.log" | tr '\n' '|')"
  fi

  # 票 133 lesson 分数键五例——九键全过/六键兼容/非整数拒/超界拒/键序错拒
  to_ledger() {
    # $1=夹具仓根 $2=ledger-line（合法或非法形状，被测脚本自判）
    sh "$SCRIPT_DIR/ticket-ops.sh" "$1" ledger --ledger-line "$2" > "$1.log" 2>&1
  }
  uc_build_ticket_ops_fixture() {
    rm -rf "$1"
    mkdir -p "$1/facts/project"
    : > "$1/facts/project/changes.jsonl"
  }
  uc_build_ticket_ops_fixture "$D/ls1"
  to_ledger "$D/ls1" '{"date": "2026-10-10", "kind": "lesson", "scope": "s", "decision": "nine-key", "evidence_ref": "x", "promoted_to": "rules", "score_contract": 90, "score_predicate": 100, "score_rework": 0}'
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"score_contract": 90' "$D/ls1/facts/project/changes.jsonl"; then
    ok '正例 lesson 九键（三分数键 0-100 整数）→ exit 0 账本收录（票 133）'
  else
    bad '正例 lesson 九键（三分数键 0-100 整数）→ exit 0 账本收录（票 133）' "exit=$rc $(tail -n 1 "$D/ls1.log" | head -c 120)"
  fi

  uc_build_ticket_ops_fixture "$D/ls2"
  to_ledger "$D/ls2" '{"date": "2026-10-10", "kind": "lesson", "scope": "s", "decision": "six-key", "evidence_ref": "x", "promoted_to": "none"}'
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$D/ls2/facts/project/changes.jsonl")" -eq 1 ]; then
    ok '正例 lesson 六键（不带分数）向后兼容 → exit 0 账本收录（票 133）'
  else
    bad '正例 lesson 六键（不带分数）向后兼容 → exit 0 账本收录（票 133）' "exit=$rc $(tail -n 1 "$D/ls2.log" | head -c 120)"
  fi

  uc_build_ticket_ops_fixture "$D/ls3"
  to_ledger "$D/ls3" '{"date": "2026-10-10", "kind": "lesson", "scope": "s", "decision": "non-integer", "evidence_ref": "x", "promoted_to": "rules", "score_contract": 90.5, "score_predicate": 100, "score_rework": 0}'
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'lesson 行分数键须为' "$D/ls3.log" && [ ! -s "$D/ls3/facts/project/changes.jsonl" ]; then
    ok '负例 lesson 分数非整数（90.5）→ exit 1 指名行型规则零写入（票 133）'
  else
    bad '负例 lesson 分数非整数（90.5）→ exit 1 指名行型规则零写入（票 133）' "exit=$rc $(tail -n 1 "$D/ls3.log" | head -c 120)"
  fi

  uc_build_ticket_ops_fixture "$D/ls4"
  to_ledger "$D/ls4" '{"date": "2026-10-10", "kind": "lesson", "scope": "s", "decision": "over-range", "evidence_ref": "x", "promoted_to": "rules", "score_contract": 101, "score_predicate": 100, "score_rework": 0}'
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'lesson 行分数键须为' "$D/ls4.log"; then
    ok '负例 lesson 分数超界（101）→ exit 1 指名值域（票 133）'
  else
    bad '负例 lesson 分数超界（101）→ exit 1 指名值域（票 133）' "exit=$rc $(tail -n 1 "$D/ls4.log" | head -c 120)"
  fi

  uc_build_ticket_ops_fixture "$D/ls5"
  to_ledger "$D/ls5" '{"date": "2026-10-10", "kind": "lesson", "scope": "s", "decision": "wrong-order", "evidence_ref": "x", "promoted_to": "rules", "score_predicate": 100, "score_contract": 90, "score_rework": 0}'
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'lesson 行分数键须为' "$D/ls5.log"; then
    ok '负例 lesson 分数键序错（predicate 在前）→ exit 1 指名固定键序（票 133）'
  else
    bad '负例 lesson 分数键序错（predicate 在前）→ exit 1 指名固定键序（票 133）' "exit=$rc $(tail -n 1 "$D/ls5.log" | head -c 120)"
  fi

  # ---- 票 152 断言：open 本体 schema 全量校验（type/pattern/enum/oneOf/
  # additionalProperties/条件 required）----
  # 独立夹具 fix152（免受前段状态影响）：最小 task 本体照（tix_body 形态）重建后逐字段
  # 破坏，各负例 exit 1、零写入（tix_state 指纹）且报文指名字段路径；正例 task/request
  # 本体照旧 exit 0 全链落地（合法面零回归）；oneOf 零命中（verification 非 string 非
  # array）一并拒。风险注记（票 152 risks）：python3 依赖已由套件环境门承载（缺 python3
  # exit 2）；存量 JSON 兼容性＝校验只 open 时点生效、存量票零回扫（open 后本体不再校验，
  # 夹具 30 票 open 通过后前段断言照旧）。
  tix_build_fixture "$D/fix152"
  F152=$D/fix152
  TIX152="$F152/rules/implementation/scripts/ticket-ops.sh"
  TIX152_OK_BODY="$F152/facts/requirements/tickets/30-gamma-third.json"
  tix_body "$TIX152_OK_BODY" 30-gamma-third
  TIX152_LEDGER='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 152", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'

  # 正例 P152：最小 task 本体原样 open → exit 0 且索引落条目（全量校验合法面零回归）
  sh "$TIX152" "$F152" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$TIX152_LEDGER" >"$D/v152p.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "30-gamma-third"' "$F152/facts/requirements/tickets/index.json"; then
    ok '正例 P152 最小 task 本体 open → exit 0 且索引落条目（schema 全量校验合法面零回归，票 152）'
  else
    bad '正例 P152 最小 task 本体 open → exit 0 且索引落条目（schema 全量校验合法面零回归，票 152）' "exit=$rc $(head -n 2 "$D/v152p.log" | tr '\n' '|')"
  fi

  S152=$(tix_state "$F152")

  # N-152id：本体 id 不合 schema pattern（大写）→ exit 1 零写入且报文指名 id（本体 id
  # 与 --id 不一致断言亦并列报出——id pattern 门与一致性门同作用）
  sed 's/"id": "30-gamma-third"/"id": "50-Epsilon-Fifth"/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152id.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q '50-Epsilon-Fifth' "$D/v152id.log"; then
    ok '负例 N-152id 本体 id 越 pattern（大写）→ exit 1 零写入且报文指名（票 152 AC1）'
  else
    bad '负例 N-152id 本体 id 越 pattern（大写）→ exit 1 零写入且报文指名（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152id.log" | tr '\n' '|')"
  fi

  # N-152c：complexity 越枚举 → exit 1 零写入且报文指名枚举
  sed 's/"complexity": "C1"/"complexity": "C9"/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152c.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q "'C9'" "$D/v152c.log"; then
    ok '负例 N-152c 本体 complexity 越枚举（C9）→ exit 1 零写入且报文指名（票 152 AC1）'
  else
    bad '负例 N-152c 本体 complexity 越枚举（C9）→ exit 1 零写入且报文指名（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152c.log" | tr '\n' '|')"
  fi

  # N-152p：profile 越七维 pattern（维值 C9）→ exit 1 零写入且报文指名 profile
  sed 's/D:Required/D:C9/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152p2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q 'profile' "$D/v152p2.log"; then
    ok '负例 N-152p 本体 profile 越七维 pattern → exit 1 零写入且报文指名（票 152 AC1）'
  else
    bad '负例 N-152p 本体 profile 越七维 pattern → exit 1 零写入且报文指名（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152p2.log" | tr '\n' '|')"
  fi

  # N-152b：blocked_by 含不合 id pattern 条目 → exit 1 零写入且报文指名路径 blocked_by[0]
  sed 's/"blocked_by": \[\]/"blocked_by": ["Bad-Ref"]/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152b.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q 'blocked_by\[0\]' "$D/v152b.log"; then
    ok '负例 N-152b blocked_by 条目越 pattern → exit 1 零写入且报文指名路径（票 152 AC1）'
  else
    bad '负例 N-152b blocked_by 条目越 pattern → exit 1 零写入且报文指名路径（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152b.log" | tr '\n' '|')"
  fi

  # N-152extra：additionalProperties（本体加 schema 未定义字段）→ exit 1 零写入且报文指名字段
  sed 's/"priority_reason"/"extra_field": "额外字段", "priority_reason"/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152x.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q 'extra_field' "$D/v152x.log"; then
    ok '负例 N-152extra 本体含未定义字段 → exit 1 零写入且报文指名（票 152 AC1 additionalProperties）'
  else
    bad '负例 N-152extra 本体含未定义字段 → exit 1 零写入且报文指名（票 152 AC1 additionalProperties）' "exit=$rc $(head -n 2 "$D/v152x.log" | tr '\n' '|')"
  fi

  # N-152task：task 票缺条件 required（profile 字段删除）→ exit 1 零写入且报文指名 task profile
  sed -e 's/"id": "30-gamma-third"/"id": "50-epsilon-fifth"/' -e '/"profile"/d' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152t.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q '要求字段: profile' "$D/v152t.log"; then
    ok '负例 N-152task task 缺条件 required profile → exit 1 零写入且报文指名（票 152 AC1）'
  else
    bad '负例 N-152task task 缺条件 required profile → exit 1 零写入且报文指名（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152t.log" | tr '\n' '|')"
  fi

  # N-152oneof：oneOf 零命中（verification 为数字，非 string 非 array）→ exit 1 零写入
  # 且报文指名 oneOf（verification 的 oneOf 两分支＝string｜array，数字两不命中）
  sed -e 's/"id": "30-gamma-third"/"id": "50-epsilon-fifth"/' -e 's/"priority_reason": "fixture 优先级理由（正例，非空）"/"priority_reason": "fixture 优先级理由（正例，非空）", "verification": 42/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152o.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q 'oneOf' "$D/v152o.log"; then
    ok '负例 N-152oneof verification oneOf 零命中（数字形态）→ exit 1 零写入（票 152 AC1）'
  else
    bad '负例 N-152oneof verification oneOf 零命中（数字形态）→ exit 1 零写入（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152o.log" | tr '\n' '|')"
  fi

  # 正例 P152r：request 本体（无 task 条件字段）open 照旧 exit 0（kind 分支合法面零回归）
  cat > "$F152/facts/requirements/tickets/51-zeta-sixth.json" <<'EOF'
{
  "id": "51-zeta-sixth",
  "kind": "request",
  "title": "fixture request（schema 全量校验正例）",
  "created_at": "2026-09-19"
}
EOF
  sh "$TIX152" "$F152" open --id 51-zeta-sixth --complexity C1 --title z --ledger-line "$TIX152_LEDGER" >"$D/v152r.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "51-zeta-sixth"' "$F152/facts/requirements/tickets/index.json"; then
    ok '正例 P152r request 本体 open → exit 0 且索引落条目（kind 分支合法面零回归，票 152 AC2）'
  else
    bad '正例 P152r request 本体 open → exit 0 且索引落条目（kind 分支合法面零回归，票 152 AC2）' "exit=$rc $(head -n 2 "$D/v152r.log" | tr '\n' '|')"
  fi

  suite_summary 'ticket-ops'
}
