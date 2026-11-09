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
# 零写入；票 198 七维 Profile reason 存储合同——合同单源 schema profile_reason 恰七键
# D/B/I/U/S/M/O＋协议 §2.2 存储合同与 verification reason 分立两正例、malformed 形态
# 读取面四负例指名键（缺键/未知键/空白值/非对象）、存量票无 reason 读取兼容正例、
# 新 task open 缺/invalid 拒零写入两负例＋valid 正开落地正例，夹具全 mktemp）；
# 状态跃迁门禁——take blocked_by 完整性门（missing/未 done blocker 拒绝零写入指名
# blocker id 与状态、全 done 正例领取、flip 零误伤对照）＋actual_time 收口 done 条件化
# （非 done 翻转无 actual_time 成功、done 缺 actual_time 拒绝、request 豁免维持）；
# 票 230 dispatch 节开票门——新 task 必备三阶段派发合同数据节（缺节/缺阶段对象/缺键/越键/
# 空白值五形态拒开零写入且报文指名 dispatch 路径）＋存量无节票 flip 读取面兼容正例
# （开票校验与读取校验分层，存量零回扫；tix_body 正例形态带全节、tix_body_at 保留无节
# 存量形态供 flip 兼容面）；票 268 新 task 开票门必备 user_stories（用户故事：数组至少
# 一条，条目格式 US<n>: 作为<角色>，我要<功能>，以便<收益>；缺项/空数组/不合格式拒开零
# 写入，合规条目放行；读取面不要求该字段，存量票零回扫）
# ============================================================

tix_body() {
  # $1=本体落盘路径 $2=票 id：最小过 schema 的 task 票本体（含理由两字段，票 79 正例形态；
  # 含七维 profile_reason 正例形态——新 task 开票门必备，恰七键逐键非空；
  # 含 dispatch 三阶段正例形态——票 230 开票门必备，键集与 contract_fields 恰等逐键非空，
  # TICKET_ID 随 $2 同步供 sed 派生夹具一致改写；
  # 含 user_stories 正例形态——票 268 开票门必备，至少一条合规用户故事；
  # 字段各占一行便于负例 sed 逐字段破坏；无 actual_time——供 flip 硬拦负例使用）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "profile_reason": {"D": "fixture D 维 reason", "B": "fixture B 维 reason", "I": "fixture I 维 reason", "U": "fixture U 维不适用 reason", "S": "fixture S 维不适用 reason", "M": "fixture M 维不适用 reason", "O": "fixture O 维不适用 reason"},
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（正例，非空）",
  "priority_reason": "fixture 优先级理由（正例，非空）",
  "user_stories": ["US1: 作为夹具维护者，我要开票正例携带合规用户故事，以便开票门正例有载体"],
  "dispatch": {
    "implementation": {"REPOSITORY_PATH": "fixture repo root", "TASK_DESCRIPTION": "fixture task", "GOAL": "fixture goal", "SCOPE_TREE": "fixture scope tree", "OUT_OF_SCOPE": "fixture out of scope", "CONTEXT_EVIDENCE": "fixture context", "CONSTRAINTS": "fixture constraints", "FORBIDDEN_CHANGES": "fixture forbidden", "ACCEPTANCE_CRITERIA": "fixture acceptance", "VERIFICATION_COMMANDS": "fixture verification", "DEPENDENCIES_BLOCKERS": "fixture deps", "RISKS": "fixture risks", "BUDGET_CHECKPOINTS": "80 calls", "ESTIMATED_TIME": "0.5d", "ACTUAL_TIME": "", "TICKET_ID": "$2"},
    "review": {"REVIEW_SCOPE": "fixture review scope", "IMPLEMENTATION_SUMMARY": "", "ACCEPTANCE_CRITERIA": "fixture acceptance", "DIFF_LOCATION": "fixture worktree", "REVIEW_DIMENSIONS": "fixture dimensions", "TICKET_ID": "$2"},
    "commit": {"REVIEW_PASS_CHECKPOINT": "", "FILE_WHITELIST": "fixture whitelist", "COMMIT_MESSAGE": "fixture message", "RECORD_FLIP_AUTHORIZATION": "fixture authorization", "SCOPE_CHECK_COMMAND": "fixture command", "TICKET_ID": "$2"}
  }
}
EOF
}

tix_body_at() {
  # $1=本体落盘路径 $2=票 id：tix_body 同款＋actual_time 字段（票 100 flip 收口硬拦的
  # 正例形态——flip 目标本体须带非空 actual_time 方可通过）；无 dispatch 节＝存量票
  # 形态（票 230 起兼任存量无节票读取面兼容正例载体——flip 读取面不要求 dispatch）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "profile_reason": {"D": "fixture D 维 reason", "B": "fixture B 维 reason", "I": "fixture I 维 reason", "U": "fixture U 维不适用 reason", "S": "fixture S 维不适用 reason", "M": "fixture M 维不适用 reason", "O": "fixture O 维不适用 reason"},
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
  # $1=夹具项目根（生成项目语境：rules/implementation/scripts/ 落位脚本件＋
  # rules/implementation/references/schemas/ 落位安装闭包数据件，facts/requirements/tickets
  # 三载体就绪＋facts/project 账本就绪——票 113 波④夹具翻值 rules/facts 新形态；
  # 票 79 起另落位 schema 权威与被 open 票的本体文件；票 269 起闭包数据件按安装布局
  # 邻接 references/ 落位，不落包工作树副本）
  F=$1
  rm -rf "$F"
  mkdir -p "$F/rules/implementation/scripts" "$F/rules/implementation/references/schemas" "$F/facts/requirements/tickets" "$F/facts/project"
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/record-store.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/generate-dir-readmes.sh" "$SCRIPT_DIR/dir-readme.rules" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/ticket-audit.sh" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/ledger-row-families.sh" "$F/rules/implementation/scripts/"
  # 票 289 分片化：门禁函数库＋审计谓词注册表与分片（同目录定位，夹具须一并落位）
  cp "$SCRIPT_DIR/ticket-gates.sh"   "$SCRIPT_DIR/audit-predicates.rules"   "$SCRIPT_DIR/audit-p01-receipt-parseable.sh"   "$SCRIPT_DIR/audit-p02-evidence-committed.sh"   "$SCRIPT_DIR/audit-p03-base-sha-present.sh"   "$SCRIPT_DIR/audit-p04-review-boundary-clean.sh"   "$SCRIPT_DIR/audit-p05-diff-sha-bound.sh"   "$SCRIPT_DIR/audit-p06-reviewer-identity-present.sh"   "$SCRIPT_DIR/audit-p07-reviewer-identity-corroborated.sh"   "$SCRIPT_DIR/audit-p08-reviewer-distinct-from-implementer.sh"   "$SCRIPT_DIR/audit-p09-reviewed-at-valid.sh"   "$SCRIPT_DIR/audit-p10-acceptance-results-present.sh"   "$SCRIPT_DIR/audit-p11-policy-applicable.sh" "$F/rules/implementation/scripts/"
  test_copy_closure "$SCRIPT_DIR" "$F/rules/implementation/scripts" generate-progress.sh generate-dir-readmes.sh json-validator.py common-helpers.sh ledger-append.sh
  SCHEMA_SRC="${SCRIPT_DIR}/../references/schemas/ticket-record.schema.json"
  [ -f "$SCHEMA_SRC" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（ticket-ops open 本体校验的 schema 权威）\n' "$SCHEMA_SRC" >&2; exit 2; }
  cp "$SCHEMA_SRC" "$F/rules/implementation/references/schemas/ticket-record.schema.json"
  # 票 269：安装闭包数据件同落位（open 只认脚本邻接 references/，不读包工作树副本）
  DISPATCH_SCHEMA_SRC="${SCRIPT_DIR}/../references/schemas/dispatch-contract.schema.json"
  [ -f "$DISPATCH_SCHEMA_SRC" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（安装闭包数据件）\n' "$DISPATCH_SCHEMA_SRC" >&2; exit 2; }
  cp "$DISPATCH_SCHEMA_SRC" "$F/rules/implementation/references/schemas/dispatch-contract.schema.json"
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
  # $1=操作前 README 快照 $2=操作后 README 路径 $3=暂存目录：票表生成块重算比对（票 277）——
  # open 不再手工追加行：断言新行入块且恰 1 行、既有两行原文保留、块外文本逐字节不变。
  sed -n '1,/^| /p' "$1" | sed '$d' > "$3/open-outside-before.md"
  sed '/^<!-- tickets-readme: generated from=/,/^<!-- \/tickets-readme -->$/d' "$2" > "$3/open-outside-after.md"
  # shellcheck disable=SC2016  # 反引号是 README 表格字面串的一部分（非命令替换）
  tix_rb_row30='| `30-gamma-third.json` |'
  # shellcheck disable=SC2016  # 同上：反引号是字面串的一部分
  tix_rb_row10='| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |'
  # shellcheck disable=SC2016  # 同上：反引号是字面串的一部分
  tix_rb_row20='| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |'
  if cmp -s "$3/open-outside-before.md" "$3/open-outside-after.md" \
    && [ "$(grep -c -F -- "$tix_rb_row30" "$2")" = '1' ] \
    && grep -q -F -- "$tix_rb_row10" "$2" \
    && grep -q -F -- "$tix_rb_row20" "$2"; then
    ok 'open 后票表生成块重算：新行入块恰 1 行、既有行原文保留、块外逐字节不变'
  else
    bad 'open 后票表生成块重算：新行入块恰 1 行、既有行原文保留、块外逐字节不变' '块外/行内容不符'
  fi
}

tix_audit_commit() {
  # $1=夹具根 $2=作者邮箱 $3=UTC 时间 $4=提交信息：全量暂存并固定身份/日期提交
  git -C "$1" add -A
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=$2 GIT_AUTHOR_DATE=$3 \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=$2 GIT_COMMITTER_DATE=$3 \
    git -C "$1" -c commit.gpgsign=false commit -qm "$4"
}

tix_audit_write_receipt() {
  # $1=夹具根 $2=base $3=head：审查收据经 receipt 落位（固定时间戳保持断言稳定）
  receipt "$1/facts/requirements/tickets/42-audit-gate.review-evidence.json" "$1" "$2" "$3" 42-audit-gate \
    --created-at '2026-10-03T08:00:00Z' --reviewed-at '2026-10-02T10:00:00Z'
}

tix_audit_fixture() {
  # $1=夹具根 [$2=证据形态 committed|uncommitted|none|stale]
  # 时序：C0 票务面提交（含 42-audit-gate 本体 actual_time）→ C1 策略 → C2 产品提交 →
  # C3 审查收据提交（stale 追加 C4 产品改动，令 diff 在审查后变化）
  _taf_mode=${2:-committed}
  tix_build_fixture "$1"
  tix_body_at "$1/facts/requirements/tickets/42-audit-gate.json" 42-audit-gate
  # 票 237 收尾断言：可选注入 dispatch.commit.REVIEW_PASS_CHECKPOINT（须在 C0 之内落盘，
  # 否则后置改票面本身即构成 P04 审查后改动，无法单独观测允许集形态）
  if [ -n "${TIX237_CP:-}" ]; then
    python3 - "$1/facts/requirements/tickets/42-audit-gate.json" "$TIX237_CP" <<'PYCP'
import json, sys
path, cp = sys.argv[1:3]
with open(path, encoding='utf-8') as fh:
    body = json.load(fh)
body.setdefault('dispatch', {}).setdefault('commit', {})['REVIEW_PASS_CHECKPOINT'] = cp
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(body, fh, ensure_ascii=False, indent=2)
    fh.write('\n')
PYCP
  fi
  sed -e '/"id": "20-beta-second"/ s/$/,/' \
    -e 's/^  \]$/    {"id": "42-audit-gate", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-01T10:00"}\
  ]/' "$1/facts/requirements/tickets/index.json" > "$1/facts/requirements/tickets/index.tmp" \
    && mv "$1/facts/requirements/tickets/index.tmp" "$1/facts/requirements/tickets/index.json"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| `42-audit-gate.json` | 任务票 42；`in_progress`（2026-10-01 开票） | Audit gate fixture |\n' \
    >> "$1/facts/requirements/tickets/README.md"
  git -C "$1" init -q
  tix_audit_commit "$1" 'impl@example.com' '2026-10-01T00:00:00Z' 'ticket records'
  _taf_base=$(git -C "$1" rev-parse HEAD)
  printf '{"schema_version":1,"policy_id":"ticket-ops-audit","effective_from":"2026-01-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["impl@example.com"]}\n' \
    "$_taf_base" > "$1/facts/requirements/audit-policy.json"
  tix_audit_commit "$1" 'impl@example.com' '2026-10-01T00:00:00Z' 'audit policy'
  _taf_product_base=$(git -C "$1" rev-parse HEAD)
  printf 'product\n' > "$1/product.txt"
  tix_audit_commit "$1" 'impl@example.com' '2026-10-02T00:00:00Z' 'product change'
  _taf_head=$(git -C "$1" rev-parse HEAD)
  if [ "$_taf_mode" != 'none' ]; then
    tix_audit_write_receipt "$1" "$_taf_product_base" "$_taf_head"
    if [ "$_taf_mode" = 'committed' ] || [ "$_taf_mode" = 'stale' ]; then
      tix_audit_commit "$1" 'reviewer@example.com' '2026-10-03T00:00:00Z' 'review evidence'
    fi
    if [ "$_taf_mode" = 'stale' ]; then
      printf 'late\n' >> "$1/product.txt"
      tix_audit_commit "$1" 'impl@example.com' '2026-10-04T00:00:00Z' 'late product change'
    fi
    # 票 237 收尾断言：审查后可选后置写面（product＝产品改动；checkpoint＝票面声明的
    # Review Checkpoint 文件），用于观测允许集是否只认规范形态
    case ${TIX237_LATE:-} in
      product)
        printf 'late\n' >> "$1/product.txt"
        tix_audit_commit "$1" 'impl@example.com' '2026-10-04T00:00:00Z' 'late product change'
        ;;
      checkpoint)
        printf 'review checkpoint\n' > "$1/facts/requirements/tickets/42-audit-gate-review-checkpoint.md"
        tix_audit_commit "$1" 'reviewer@example.com' '2026-10-04T00:00:00Z' 'review checkpoint'
        ;;
    esac
  fi
}

tix_expected_progress() {  # 独立重建：三票投影全文（generated_at 行规范化；按 id 升序；头部两路径＝生成器
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
    printf '# 票据索引（fixture）\n\n'
    printf '<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->\n'
    printf '| 名字 | 状态 | 说明 |\n| --- | --- | --- |\n'
    # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
    printf '| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |\n'
    printf '%s\n' "$7"
    printf '%s\n' "$6"
    printf '<!-- /tickets-readme -->\n'
  } > "$F/exp.readme.md"
  assert_eq 'issues-README 票表生成块全文件逐一相等（索引派生重算，块外逐字节不动）' "$F/facts/requirements/tickets/README.md" "$F/exp.readme.md"

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

# ============================================================
# 票 243 夹具：票务状态单写与崩溃恢复（AC1～AC6）
# 实现必须提供的可注入契约（测试据此注入崩溃，不依赖实现内部行号）：
#   1. 故障注入环境变量 TICKET_OPS_FAULT=<point>，point ∈
#      after-index-write | after-ledger-write | after-projection-write。
#      语义：该写点完整落盘后立即 exit 70，并向 stderr 打印
#      `ticket-ops: FAULT injected: <point>`；其后写点一律不执行。
#      未设或空串＝正常路径（零行为差异）；未知值＝exit 2 零写入。
#   2. 并发冲突：状态写入互斥串行；无法串行时失败方 exit 非 0，报文含「冲突」或「conflict」。
#   3. 幂等：同一操作（同 id 同目标状态）重跑收敛，不重复落账本行、不重复插 README 行。
# 契约检测失败时测试退回「临时副本写点桩替换」（只在 mktemp 副本上插 exit 70，产品文件零改动）。
# ============================================================

tix243_fresh_fixture() {
  # $1=夹具根：空索引 {"issues":[]}＋无数据行 README＋无账本文件（新项目首开现场，AC1 载体）
  tix_build_fixture "$1"
  printf '{\n  "issues": []\n}\n' > "$1/facts/requirements/tickets/index.json"
  cat > "$1/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
EOF
  rm -f "$1/facts/project/changes.jsonl"
}

tix243_json_ok() {
  # $1=文件：JSON 可解析即 0（索引合法性断言用）
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$1" >/dev/null 2>&1
}

tix243_count() {
  # $1=文件 $2=固定串：命中行数（零命中输出 0）
  grep -c -F -- "$2" "$1" 2>/dev/null | tr -d ' '
}

tix243_fault_marker() {
  # $1=注入点：该写点的行内标记片段（契约缺席时的兜底桩替换定位）
  # shellcheck disable=SC2016  # case/for 分支里的注入桩原文含 ${...} 字样（单引号防展开），非缺陷
  case $1 in
    after-index-write) printf '%s' 'mv "${tmp_idx}" "${index_file}"' ;;
    after-ledger-write) printf '%s' '账本落行未过' ;;
    after-projection-write) printf '%s' '投影再生失败' ;;
    *) return 1 ;;
  esac
}

tix243_inject() {
  # $1=脚本副本 $2=标记片段 $3=第几次命中：命中处下一行插入 exit 70 桩；命中不足即 1
  [ -n "${2:-}" ] || return 1
  tix243_mark=$2
  tix243_nth=${3:-1}
  TIX243_MARK=$tix243_mark TIX243_NTH=$tix243_nth awk '
    { print }
    index($0, ENVIRON["TIX243_MARK"]) > 0 {
      hit++
      if (hit == ENVIRON["TIX243_NTH"] + 0) print "  exit 70"
    }
  ' "$1" > "$1.tix243fault" || { rm -f "$1.tix243fault"; return 1; }
  if [ "$(tix243_count "$1.tix243fault" '  exit 70')" = '1' ]; then
    mv "$1.tix243fault" "$1"
    return 0
  fi
  rm -f "$1.tix243fault"
  return 1
}

tix243_reason() {
  # $1=日志：取首条含 FAIL 的行作失败详情（无则回退前两行折行），避免详情只留定位噪声
  tix243_line=$(grep -F 'FAIL' "$1" 2>/dev/null | head -n 1) || tix243_line=''
  [ -n "$tix243_line" ] || tix243_line=$(head -n 2 "$1" 2>/dev/null | tr '\n' '|')
  printf '%s' "$tix243_line"
}

tix246_lock_dir() {
  # $1=夹具根：经共享库解析锁目录（只读探针；产品脚本不复制锁实现，测试也不按实现猜路径）
  tix246_probe="$D/.probe-lock.sh"
  cat > "$tix246_probe" <<'PROBE'
#!/bin/sh
set -eu
COMMON_HELPERS_DIR="$1/rules/implementation/scripts"
. "$1/rules/implementation/scripts/common-helpers.sh"
record_lock_init "$1"
printf '%s\n' "$RECORD_LOCK_DIR"
PROBE
  sh "$tix246_probe" "$1"
  rm -f "$tix246_probe"
}

tix243_converged() {
  # $1=夹具根：收敛判定（输出空串＝收敛；否则输出未收敛面清单，AC3 重跑断言用）
  tix243_cv=''
  tix243_json_ok "$1/facts/requirements/tickets/index.json" || tix243_cv="$tix243_cv index非JSON"
  [ "$(tix243_count "$1/facts/requirements/tickets/index.json" '"id": "30-gamma-third"')" = '1' ] || \
    tix243_cv="$tix243_cv 索引条目数≠1"
  [ "$(tix243_count "$1/facts/requirements/tickets/README.md" '30-gamma-third.json')" = '1' ] || \
    tix243_cv="$tix243_cv README行数≠1"
  if [ -f "$1/facts/requirements/tickets/progress-current.md" ]; then
    [ "$(tix243_count "$1/facts/requirements/tickets/progress-current.md" '| 30-gamma-third |')" = '1' ] || \
      tix243_cv="$tix243_cv 投影行数≠1"
    sh "$1/rules/implementation/scripts/generate-progress.sh" --check "$1" >/dev/null 2>&1 || \
      tix243_cv="$tix243_cv 投影--check失败"
  else
    tix243_cv="$tix243_cv 投影缺失"
  fi
  [ "$(tix243_count "$1/facts/project/changes.jsonl" '票243 崩溃收敛')" = '1' ] || \
    tix243_cv="$tix243_cv 账本行数≠1"
  printf '%s' "$tix243_cv"
}

# 票 291 拆分标记：票 243 锁/并发/故障注入/恢复用例（AC1 空索引首开 等）已迁至
# suite-ticket-ops-locks.sh；--suite ticket-ops-locks 入口可达。
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
  ROW30='| `30-gamma-third.json` | 任务票 30；`ready`（'"$TODAY"' 开票） | fixture ticket 30-gamma-third |'
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
  ROW30B='| `30-gamma-third.json` | 任务票 30；`in_progress`（'"$TODAY"' 开票） | fixture ticket 30-gamma-third |'
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
    ok '负例 N1 重复 id open（目标状态非 ready）→ exit 1 零写入（冲突不可静默覆盖）'
  else
    bad '负例 N1 重复 id open（目标状态非 ready）→ exit 1 零写入（冲突不可静默覆盖）' "exit/状态不符"
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

  # ---- 票 277 断言：README 票表生成块合同——人工编辑路径关闭（缺行/重复/漂移由索引派生
  # 重算自愈），收口链不回归。逐例独立夹具：四载体指纹与块内行内容断言。
  # N-rd1：README 手删该票行（缺锚）→ flip 照旧 exit 0，生成块自愈补回该行且状态＝索引值
  tix_build_fixture "$D/fixrd1"
  Frd1=$D/fixrd1
  tix_body_at "$Frd1/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  sed '/任务票 20；/d' "$Frd1/facts/requirements/tickets/README.md" > "$Frd1/rd.tmp" && mv "$Frd1/rd.tmp" "$Frd1/facts/requirements/tickets/README.md"
  sh "$Frd1/rules/implementation/scripts/ticket-ops.sh" "$Frd1" flip --id 20-beta-second --status review_ready --ledger-line "$LED_FLIP" >"$D/rd1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(tix_readme_token "$Frd1/facts/requirements/tickets/README.md" 20)" = 'review_ready' ] \
    && [ "$(grep -c -F -- '任务票 20；' "$Frd1/facts/requirements/tickets/README.md")" = '1' ]; then
    ok 'N-rd1 README 手删该票行（缺锚）→ flip exit 0 且生成块自愈补回、状态＝索引值（人工编辑路径关闭）'
  else
    bad 'N-rd1 README 手删该票行（缺锚）→ flip exit 0 且生成块自愈补回、状态＝索引值（人工编辑路径关闭）' "exit=$rc token=$(tix_readme_token "$Frd1/facts/requirements/tickets/README.md" 20) $(head -n 2 "$D/rd1.log" | tr '\n' '|')"
  fi

  # N-rd2：README 该票行重复（重锚）→ take 照旧 exit 0，生成块按索引归一为恰 1 行
  tix_build_fixture "$D/fixrd2"
  Frd2=$D/fixrd2
  tix_body_at "$Frd2/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  awk '{ print } /任务票 20；/ { print }' "$Frd2/facts/requirements/tickets/README.md" > "$Frd2/rd.tmp" && mv "$Frd2/rd.tmp" "$Frd2/facts/requirements/tickets/README.md"
  sh "$Frd2/rules/implementation/scripts/ticket-ops.sh" "$Frd2" take --id 20-beta-second --status in_progress --ledger-line "$LED_TAKE" >"$D/rd2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(grep -c -F -- '任务票 20；' "$Frd2/facts/requirements/tickets/README.md")" = '1' ] \
    && [ "$(tix_readme_token "$Frd2/facts/requirements/tickets/README.md" 20)" = 'in_progress' ]; then
    ok 'N-rd2 README 该票行重复（重锚）→ take exit 0 且生成块归一为 1 行、状态＝索引值（重复行被收敛）'
  else
    bad 'N-rd2 README 该票行重复（重锚）→ take exit 0 且生成块归一为 1 行、状态＝索引值（重复行被收敛）' "exit=$rc 行=$(grep -c -F -- '任务票 20；' "$Frd2/facts/requirements/tickets/README.md") $(head -n 2 "$D/rd2.log" | tr '\n' '|')"
  fi

  # N-rd3：README 残留漂移行（索引无该票）且旋即 open 同 id → exit 0，生成块以索引为准归一
  tix_build_fixture "$D/fixrd3"
  Frd3=$D/fixrd3
  tix_body "$Frd3/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  cat >> "$Frd3/facts/requirements/tickets/README.md" <<'EOF'
| `30-gamma-third.json` | 任务票 30；`blocked`（2026-09-19 开票） | drifted stale row |
EOF
  sh "$Frd3/rules/implementation/scripts/ticket-ops.sh" "$Frd3" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/rd3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '"id": "30-gamma-third", "status": "ready"' "$Frd3/facts/requirements/tickets/index.json" \
    && [ "$(grep -c -F -- '任务票 30；' "$Frd3/facts/requirements/tickets/README.md")" = '1' ] \
    && [ "$(tix_readme_token "$Frd3/facts/requirements/tickets/README.md" 30)" = 'ready' ]; then
    ok 'N-rd3 README 残留漂移行（索引无该票）→ open exit 0 且生成块以索引为准归一为 1 行'
  else
    bad 'N-rd3 README 残留漂移行（索引无该票）→ open exit 0 且生成块以索引为准归一为 1 行' "exit=$rc 行=$(grep -c -F -- '任务票 30；' "$Frd3/facts/requirements/tickets/README.md") token=$(tix_readme_token "$Frd3/facts/requirements/tickets/README.md" 30) $(head -n 2 "$D/rd3.log" | tr '\n' '|')"
  fi

  # N-rd4：README 整表缺失（无表无块）→ open exit 0，README 零写入（生成器 SKIP 不改写），
  # 索引与账本照常落地——无票表可派生的 README 不阻断开票链
  tix_build_fixture "$D/fixrd4"
  Frd4=$D/fixrd4
  tix_body "$Frd4/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  sed '/^|/d' "$Frd4/facts/requirements/tickets/README.md" > "$Frd4/rd.tmp" && mv "$Frd4/rd.tmp" "$Frd4/facts/requirements/tickets/README.md"
  Srd4=$(cksum "$Frd4/facts/requirements/tickets/README.md")
  sh "$Frd4/rules/implementation/scripts/ticket-ops.sh" "$Frd4" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/rd4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '"id": "30-gamma-third"' "$Frd4/facts/requirements/tickets/index.json" \
    && [ "$Srd4" = "$(cksum "$Frd4/facts/requirements/tickets/README.md")" ] \
    && grep -q 'SKIP' "$D/rd4.log"; then
    ok 'N-rd4 README 整表缺失 → open exit 0（生成器 SKIP 零改写），索引与账本照常落地'
  else
    bad 'N-rd4 README 整表缺失 → open exit 0（生成器 SKIP 零改写），索引与账本照常落地' "exit=$rc $(head -n 3 "$D/rd4.log" | tr '\n' '|')"
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
    bad '负例 N-100e ledger 账本行键序违规 → exit 1 零写入（形状校验先于写入，票 100）' "exit=$rc 行数 ${n_before}→${n_after} $(head -n 2 "$D/lg1.log" | tr '\n' '|')"
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
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/record-store.sh" "$SCRIPT_DIR/generate-progress.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/ledger-row-families.sh" "$D/fix-l/rules/implementation/scripts/"
  cp "$SCRIPT_DIR/ticket-gates.sh" "$D/fix-l/rules/implementation/scripts/"
  test_copy_closure "$SCRIPT_DIR" "$D/fix-l/rules/implementation/scripts" generate-progress.sh json-validator.py common-helpers.sh ledger-append.sh
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

  # ---- 票 193 断言：统一账本行合同（references/schemas/ledger-row.schema.json 单源）----
  # AC1：合同文件为行型真相源——内部一致（example 键序＝keys 逐字、五/七/九键行族键数
  # 在场），合同正例行族 example 经 ticket-ops ledger 全数收录（合同↔校验同源实证），
  # 三方消费者同源且各有其合法面：ticket-ops.sh／lane-commit.sh 头注指名包内合同
  # （包内面），模板属安装面、不得留包内悬空路径，改以目标项目
  # `rules/implementation/scripts/ledger-append.sh` 的行族校验为生效面并以键序串与
  # 合同 keys 逐字承接（模板指名包内 schema 即判红）。AC2：未知键／键序破坏／值域
  # 越界负例 fail-closed 零写入且报文指名行形态（行族键集／具体键／值域）。夹具全
  # mktemp，ledger 无票入口不触票务面；合同文件为套件依赖（缺失 exit 2，同 ticket-record
  # schema 先例）。
  LR_SCHEMA="${SCRIPT_DIR}/../references/schemas/ledger-row.schema.json"
  [ -f "$LR_SCHEMA" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（账本行行型合同，票 193）\n' "$LR_SCHEMA" >&2; exit 2; }
  mkdir -p "$D/lr"
  if python3 - "$LR_SCHEMA" "$D/lr" >"$D/lr-parse.log" 2>&1 <<'PYTHON'
import json, os, sys
schema = json.load(open(sys.argv[1], encoding='utf-8'))
out = sys.argv[2]
rows = {r['id']: r for r in schema['rows']}
for rid, r in rows.items():
    assert list(r['example'].keys()) == r['keys'], f"{rid}: example 键序漂移"
assert rows['changes_five_key']['key_count'] == 5
assert rows['micro_seven_key']['key_count'] == 7
assert rows['changes_lesson_nine_key']['key_count'] == 9
for rid in ('changes_five_key', 'changes_lesson_six_key', 'changes_replan_eight_key', 'changes_lesson_nine_key'):
    with open(os.path.join(out, rid + '.json'), 'w', encoding='utf-8') as f:
        json.dump(rows[rid]['example'], f, ensure_ascii=False)
with open(os.path.join(out, 'changes-order.txt'), 'w', encoding='utf-8') as f:
    f.write(','.join(rows['changes_five_key']['keys']))
with open(os.path.join(out, 'micro-order.txt'), 'w', encoding='utf-8') as f:
    f.write(','.join(rows['micro_seven_key']['keys']))
PYTHON
  then
    ok '正例 合同内部一致（example 键序＝keys 逐字；五/七/九键行族键数在场，票 193 AC1）'
  else
    bad '正例 合同内部一致（example 键序＝keys 逐字；五/七/九键行族键数在场，票 193 AC1）' "$(head -n 3 "$D/lr-parse.log" | tr '\n' '|')"
  fi

  uc_build_ticket_ops_fixture "$D/lrpos"
  for lr_row in changes_five_key changes_lesson_six_key changes_replan_eight_key changes_lesson_nine_key; do
    sh "$SCRIPT_DIR/ticket-ops.sh" "$D/lrpos" ledger --ledger-line "$(cat "$D/lr/$lr_row.json")" >"$D/lrpos.log" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && tail -n 1 "$D/lrpos/facts/project/changes.jsonl" | grep -qF "$(cat "$D/lr/$lr_row.json")"; then
      ok "正例 合同行族 ${lr_row} example 经 ticket-ops 收录（合同↔校验同源，票 193 AC1）"
    else
      bad "正例 合同行族 ${lr_row} example 经 ticket-ops 收录（合同↔校验同源，票 193 AC1）" "exit=$rc $(tail -n 1 "$D/lrpos.log" | head -c 120)"
    fi
  done

  LR_TMPL="${SCRIPT_DIR}/../references/templates/discipline.md.tmpl"
  if grep -qF 'references/schemas/ledger-row.schema.json' "$SCRIPT_DIR/ticket-ops.sh" \
    && grep -qF 'references/schemas/ledger-row.schema.json' "$SCRIPT_DIR/lane-commit.sh" \
    && grep -qF 'rules/implementation/scripts/ledger-append.sh' "$LR_TMPL"; then
    ok '三方消费者同源（两脚本头注指名合同；模板以 ledger-append 行族校验为生效面，票 193 AC1）'
  else
    bad '三方消费者同源（两脚本头注指名合同；模板以 ledger-append 行族校验为生效面，票 193 AC1）' '至少一方缺合同指针'
  fi
  if grep -qF 'references/schemas/ledger-row.schema.json' "$LR_TMPL"; then
    bad '模板不指名包内合同路径（安装面零悬空指针，键序串承接合同，票 193 AC1）' '模板含 references/schemas/ledger-row.schema.json'
  else
    ok '模板不指名包内合同路径（安装面零悬空指针，键序串承接合同，票 193 AC1）'
  fi
  if grep -qF "$(cat "$D/lr/changes-order.txt")" "$LR_TMPL" \
    && grep -qF "$(cat "$D/lr/micro-order.txt")" "$LR_TMPL"; then
    ok '模板承载注记键序串与合同 keys 逐字一致（changes 五键序＋micro 七键序，票 193 AC1）'
  else
    bad '模板承载注记键序串与合同 keys 逐字一致（changes 五键序＋micro 七键序，票 193 AC1）' '模板键序串漂移'
  fi

  # AC2 负例（独立空账本夹具；各行族负例 fail-closed 零写入且报文指名行形态）
  uc_build_ticket_ops_fixture "$D/lrneg"
  lr_n0=$(wc -l < "$D/lrneg/facts/project/changes.jsonl" | tr -d ' ')
  lr_neg() {
    # $1=负例名 $2=行 $3=报文必含字面片段（grep -F）
    sh "$SCRIPT_DIR/ticket-ops.sh" "$D/lrneg" ledger --ledger-line "$2" >"$D/lrneg.log" 2>&1
    rc=$?
    lr_n1=$(wc -l < "$D/lrneg/facts/project/changes.jsonl" | tr -d ' ')
    if [ "$rc" -eq 1 ] && [ "$lr_n1" -eq "$lr_n0" ] && grep -qF -- "$3" "$D/lrneg.log"; then
      ok "负例 ${1} → exit 1 零写入且报文指名行形态（票 193 AC2）"
    else
      bad "负例 ${1} → exit 1 零写入且报文指名行形态（票 193 AC2）" "exit=$rc 行数=${lr_n1}/${lr_n0} $(head -n 2 "$D/lrneg.log" | tr '\n' '|')"
    fi
  }
  lr_neg '193a 五键族未知键' \
    '{"date": "2026-10-21", "kind": "scope", "scope": "s", "decision": "d", "evidence_ref": "e", "unknown_key": "x"}' \
    '账本行含未知键'
  lr_neg '193a2 五键族未知键指名键名' \
    '{"date": "2026-10-21", "kind": "scope", "scope": "s", "decision": "d", "evidence_ref": "e", "unknown_key": "x"}' \
    'unknown_key'
  lr_neg '193b lesson 六键族未知键' \
    '{"date": "2026-10-21", "kind": "lesson", "scope": "s", "decision": "d", "evidence_ref": "e", "promoted_to": "rules", "unknown_key": "x"}' \
    'unknown_key'
  lr_neg '193c 五键族键序破坏（kind/date 换位）' \
    '{"kind": "scope", "date": "2026-10-21", "scope": "s", "decision": "d", "evidence_ref": "e"}' \
    '账本行不合键序或形状'
  lr_neg '193d 五键族值域越界（date 非 YYYY-MM-DD 形状）' \
    '{"date": "2026/10/21", "kind": "scope", "scope": "s", "decision": "d", "evidence_ref": "e"}' \
    '账本行不合键序或形状'
  lr_neg '193e replan 八键族值域越界（布尔位字串）' \
    '{"date": "2026-10-21", "kind": "replan", "scope": "s", "decision": "d", "evidence_ref": "e", "replan_original": "true", "replan_replacement": false, "replan_undone": true}' \
    '布尔字面量'
  lr_neg '193f micro 七键行误入 changes 账本（跨账本键集拒绝）' \
    '{"date": "2026-10-21", "lane": "micro", "whitelist": "a.txt", "gates": "PASS", "verify": 1, "commit": "abc1234", "actual": ""}' \
    'lane,whitelist,gates,verify,commit,actual'

  # ---- 票 207 断言：禁新建 request——kind=request 与 REQ-* id 格式拒绝且零写入 ----
  # 独立夹具 fix207（三负例）：N-207a kind=request 但 id 为 task 格式拒开 exit 1 零写入且
  # 报明退役；N-207b REQ-* id 拒开 exit 1 零写入且报明退役；N-207c kind=request＋REQ-* id
  # 拒开（两拒绝面均命中）；正例 P207 存量 request 读取校验通过（读取面兼容）
  tix_build_fixture "$D/fix207"
  F207=$D/fix207
  TIX207="$F207/rules/implementation/scripts/ticket-ops.sh"

  # N-207a: kind=request 但 id 为 task 格式拒开（json-validator.py --new-ticket kind 门拦截）
  BODY207_BAD_KIND="$F207/facts/requirements/tickets/40-bad-request.json"
  cat > "$BODY207_BAD_KIND" <<'EOF'
{
  "id": "40-bad-request",
  "kind": "request",
  "title": "fixture request（kind 退役但 id 合 task 口径）",
  "created_at": "2026-10-23"
}
EOF
  LED207_RK='{"date": "2026-10-23", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 207 kind=request", "evidence_ref": "facts/requirements/tickets/40-bad-request.json"}'
  S207=$(tix_state "$F207")
  sh "$TIX207" "$F207" open --id 40-bad-request --complexity C1 --title 'Request fixture' --ledger-line "$LED207_RK" >"$D/v207a.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S207" = "$(tix_state "$F207")" ] && grep -q '退役' "$D/v207a.log" && grep -q 'kind=request' "$D/v207a.log"; then
    ok '负例 N-207a kind=request（task id 格式） → exit 1 零写入且报明退役（2026-10-23）'
  else
    bad '负例 N-207a kind=request（task id 格式） → exit 1 零写入且报明退役（2026-10-23）' "exit=$rc $(head -n 2 "$D/v207a.log" | tr '\n' '|')"
  fi

  # N-207b: REQ-* id 拒开（ticket-ops.sh open REQ- 专门门拦截）
  BODY207_BAD_ID="$F207/facts/requirements/tickets/REQ-20261023-002.json"
  tix_body "$BODY207_BAD_ID" REQ-20261023-002
  LED207_RI='{"date": "2026-10-23", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 207 REQ-* id", "evidence_ref": "facts/requirements/tickets/REQ-20261023-002.json"}'
  sh "$TIX207" "$F207" open --id REQ-20261023-002 --complexity C1 --title 'REQ id fixture' --ledger-line "$LED207_RI" >"$D/v207b.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S207" = "$(tix_state "$F207")" ] && grep -q '退役' "$D/v207b.log" && grep -q 'REQ-\*' "$D/v207b.log"; then
    ok '负例 N-207b REQ-* id → exit 1 零写入且报明退役（2026-10-23）'
  else
    bad '负例 N-207b REQ-* id → exit 1 零写入且报明退役（2026-10-23）' "exit=$rc $(head -n 2 "$D/v207b.log" | tr '\n' '|')"
  fi

  # N-207c: kind=request + REQ-* id（两拒绝面均命中，id 门先拦）
  BODY207_BOTH="$F207/facts/requirements/tickets/REQ-20261023-003.json"
  cat > "$BODY207_BOTH" <<'EOF'
{
  "id": "REQ-20261023-003",
  "kind": "request",
  "title": "fixture request（两退役面均命中）",
  "created_at": "2026-10-23"
}
EOF
  LED207_BOTH='{"date": "2026-10-23", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 207 both", "evidence_ref": "facts/requirements/tickets/REQ-20261023-003.json"}'
  sh "$TIX207" "$F207" open --id REQ-20261023-003 --complexity C1 --title 'Both fixture' --ledger-line "$LED207_BOTH" >"$D/v207c.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S207" = "$(tix_state "$F207")" ] && grep -q '退役' "$D/v207c.log"; then
    ok '负例 N-207c kind=request＋REQ-* id → exit 1 零写入且报明退役（两拒绝面均命中）'
  else
    bad '负例 N-207c kind=request＋REQ-* id → exit 1 零写入且报明退役（两拒绝面均命中）' "exit=$rc $(head -n 2 "$D/v207c.log" | tr '\n' '|')"
  fi

  # P207：存量 request 读取校验通过（读取面兼容，不传 --new-ticket）
  VAL207="$F207/rules/implementation/scripts/json-validator.py"
  SCHEMA207="$F207/rules/implementation/references/schemas/ticket-record.schema.json"
  python3 "$VAL207" ticket "$SCHEMA207" "$BODY207_BOTH" >"$D/v207d.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 P207 存量 request 读取校验通过（kind=request / REQ-* id 读取面兼容，不传 --new-ticket）'
  else
    bad '正例 P207 存量 request 读取校验通过（kind=request / REQ-* id 读取面兼容，不传 --new-ticket）' "exit=$rc $(head -n 2 "$D/v207d.log" | tr '\n' '|')"
  fi

  # ---- 票 152 断言：open 本体 schema 全量校验（type/pattern/enum/oneOf/
  # additionalProperties/条件 required）----
  # 独立夹具 fix152（免受前段状态影响）：最小 task 本体照（tix_body 形态）重建后逐字段
  # 破坏，各负例 exit 1、零写入（tix_state 指纹）且报文指名字段路径；正例 task
  # 本体照旧 exit 0 全链落地（合法面零回归；request 侧正例自票 207 起改读取面兼容形态，
  # 见 P152r）；oneOf 零命中（verification 非 string 非
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
  # 且报文指名 oneOf（verification 的 oneOf 两分支＝string｜array，数字两不命中）。
  # 票 280：原夹具以「追加第二个 verification 键」制造数字形态，构成重复键（严格读取
  # 会先报重复键而非 oneOf）；改为原位替换既有 verification 值，保持本负例的 oneOf 单义。
  sed -e 's/"id": "30-gamma-third"/"id": "50-epsilon-fifth"/' \
      -e 's/"verification": \[.*\]/"verification": 42/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v152o.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q 'oneOf' "$D/v152o.log"; then
    ok '负例 N-152oneof verification oneOf 零命中（数字形态）→ exit 1 零写入（票 152 AC1）'
  else
    bad '负例 N-152oneof verification oneOf 零命中（数字形态）→ exit 1 零写入（票 152 AC1）' "exit=$rc $(head -n 2 "$D/v152o.log" | tr '\n' '|')"
  fi

  # N-280dup：票本体含重复键（严格读取门）→ exit 1 零写入且报文指名重复键
  # （票 280：validate_ticket 改走 _strict_load；旧实现在 json.load 下后者覆盖不报错）
  sed -e 's/"id": "30-gamma-third"/"id": "50-epsilon-fifth"/' \
      -e 's/"priority_reason": "fixture 优先级理由（正例，非空）"/"priority_reason": "fixture 优先级理由（正例，非空）", "priority_reason": "重复键"/' "$TIX152_OK_BODY" > "$F152/facts/requirements/tickets/50-epsilon-fifth.json"
  sh "$TIX152" "$F152" open --id 50-epsilon-fifth --complexity C1 --title e --ledger-line "$TIX152_LEDGER" >"$D/v280dup.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S152" = "$(tix_state "$F152")" ] && grep -q '重复键' "$D/v280dup.log"; then
    ok '负例 N-280dup 票本体重复键经严格读取判非法 → exit 1 零写入（票 280）'
  else
    bad '负例 N-280dup 票本体重复键经严格读取判非法 → exit 1 零写入（票 280）' "exit=$rc $(head -n 2 "$D/v280dup.log" | tr '\n' '|')"
  fi

  # 正例 P152r：request 本体已退役，测试转为存量 request 读取校验通过（票 207）
  cat > "$F152/facts/requirements/tickets/REQ-20260919-001.json" <<'EOF'
{
  "id": "REQ-20260919-001",
  "kind": "request",
  "title": "存量 request（读取面兼容）",
  "created_at": "2026-09-19"
}
EOF
  VAL152="$F152/rules/implementation/scripts/json-validator.py"
  SCHEMA152="$F152/rules/implementation/references/schemas/ticket-record.schema.json"
  python3 "$VAL152" ticket "$SCHEMA152" "$F152/facts/requirements/tickets/REQ-20260919-001.json" >"$D/v152r.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 P152r 存量 request 读取校验通过（kind=request 读取面兼容，票 207 后测试改写）'
  else
    bad '正例 P152r 存量 request 读取校验通过（kind=request 读取面兼容，票 207 后测试改写）' "exit=$rc $(head -n 2 "$D/v152r.log" | tr '\n' '|')"
  fi

  # ---- 七维 Profile reason 存储合同断言（协议 §2.2＋schema profile_reason 属性单源，
  # 与 verification reason 语义分立）----
  # 独立夹具 fix198（免受前段状态影响）。AC1：形态/值域单源定义——schema profile_reason
  # 属性恰七键 D/B/I/U/S/M/O、值非空字符串、禁额外键，协议 §2.2 同面承载且两处互指；
  # malformed 形态读取面即拒且报文指名键；分立＝与 record_only.reason 两字段互不混用
  # （协议分立声明在场断言）。AC2：新 task 开票（--new-ticket 链路）缺/invalid 拒且零
  # 写入、valid 正开落地；存量票无 reason 读取兼容（缺省校验零命中——开票校验与读取
  # 校验分层）。夹具全 mktemp。
  SCHEMA198="$SCRIPT_DIR/../references/schemas/ticket-record.schema.json"
  PROF198="$SCRIPT_DIR/../references/protocol/complexity-profile.md"
  tix_build_fixture "$D/fix198"
  F198=$D/fix198
  PR198="$F198/facts/requirements/tickets/70-omega-reason.json"
  TIX198="$F198/rules/implementation/scripts/ticket-ops.sh"

  # 合同单源：schema profile_reason 恰七键（required＝D/B/I/U/S/M/O、additionalProperties
  # 禁额外键、逐键非空字符串）
  if python3 - "$SCHEMA198" <<'PYTHON'
import json, sys
schema = json.load(open(sys.argv[1], encoding='utf-8'))
pr = schema['properties']['profile_reason']
assert pr['type'] == 'object' and pr['additionalProperties'] is False
assert pr['required'] == ['D', 'B', 'I', 'U', 'S', 'M', 'O']
assert sorted(pr['properties']) == sorted(pr['required'])
for rules in pr['properties'].values():
    assert rules['type'] == 'string' and rules['minLength'] == 1 and 'pattern' in rules
PYTHON
  then
    ok '正例 合同单源 schema profile_reason 恰七键 D/B/I/U/S/M/O 禁额外键逐键非空（AC1）'
  else
    bad '正例 合同单源 schema profile_reason 恰七键 D/B/I/U/S/M/O 禁额外键逐键非空（AC1）' 'schema profile_reason 形状漂移'
  fi
  if grep -q '七维 reason 存储合同' "$PROF198" && grep -q 'profile_reason' "$PROF198" && grep -q 'record_only.reason' "$PROF198"; then
    ok '正例 协议 §2.2 存储合同与 verification reason 分立声明在场（两处单源互指，AC1）'
  else
    bad '正例 协议 §2.2 存储合同与 verification reason 分立声明在场（两处单源互指，AC1）' '协议缺存储合同节或分立声明'
  fi

  # 正例：七键齐逐键非空，读取面校验通过（tix_body 正例形态含 profile_reason）
  tix_body "$PR198" 70-omega-reason
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCHEMA198" "$PR198" >/dev/null 2>&1; then
    ok '正例 profile_reason 七键齐逐键非空 读取面校验通过（AC1 合法形态）'
  else
    bad '正例 profile_reason 七键齐逐键非空 读取面校验通过（AC1 合法形态）' 'exit 非 0'
  fi

  # AC1 负例：malformed 形态读取面即拒且报文指名键（缺键/未知键/空白值/非对象）
  pr198_variant() {
    # $1=variant $2=out：自 tix_body 正例基体派生各形态
    tix_body "$2.base" 70-omega-reason
    python3 - "$2.base" "$2" "$1" <<'PYTHON'
import json, sys
body = json.load(open(sys.argv[1], encoding='utf-8'))
mode = sys.argv[3]
pr = body['profile_reason']
if mode == 'missing-key':
    del pr['S']
elif mode == 'unknown-key':
    pr['X'] = 'fixture 未知维度'
elif mode == 'blank-value':
    pr['B'] = '   '
elif mode == 'not-object':
    body['profile_reason'] = 'D:七维散文误置（reason 不是对象）'
elif mode == 'absent':
    del body['profile_reason']
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    json.dump(body, f)
PYTHON
  }
  pr198_neg() {
    # $1=负例名 $2=variant $3=报文必含片段：读取面（缺省校验）拒且指名
    pr198_variant "$2" "$D/pr198-$2.json"
    python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCHEMA198" "$D/pr198-$2.json" >"$D/pr198-$2.log" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -qF -- "$3" "$D/pr198-$2.log"; then
      ok "负例 AC1 ${1} 读取面拒且报文指名键"
    else
      bad "负例 AC1 ${1} 读取面拒且报文指名键" "exit=$rc $(grep profile_reason "$D/pr198-$2.log" | head -n 1)"
    fi
  }
  pr198_neg '缺维度键（S）' missing-key 'profile_reason 缺维度键: S'
  pr198_neg '未知维度键（X）' unknown-key 'profile_reason 含未知维度键'
  pr198_neg '空白值（B）' blank-value 'profile_reason.B 必须是非空字符串'
  pr198_neg '非对象形态' not-object 'profile_reason 必须是对象'

  # AC2 存量兼容：无 profile_reason 本体缺省校验（读取路径）通过——开票校验与读取校验分层
  pr198_variant absent "$D/pr198-absent.json"
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCHEMA198" "$D/pr198-absent.json" >/dev/null 2>&1; then
    ok '正例 存量票无 profile_reason 读取面零命中照常通过（AC2 兼容分层）'
  else
    bad '正例 存量票无 profile_reason 读取面零命中照常通过（AC2 兼容分层）' 'exit 非 0'
  fi

  # AC2 开票门（ticket-ops open → validator --new-ticket 链路）：缺/invalid 拒且零写入
  mv "$D/pr198-absent.json" "$PR198"
  S198=$(tix_state "$F198")
  sh "$TIX198" "$F198" open --id 70-omega-reason --complexity C1 --title 'Omega fixture ticket' --ledger-line "$LED_OPEN" >"$D/pr198-open-absent.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S198" = "$(tix_state "$F198")" ] && grep -q 'profile_reason' "$D/pr198-open-absent.log"; then
    ok '负例 AC2 新 task 缺 profile_reason open → exit 1 零写入且报文指名（开票门 fail-closed）'
  else
    bad '负例 AC2 新 task 缺 profile_reason open → exit 1 零写入且报文指名（开票门 fail-closed）' "exit=$rc $(head -n 2 "$D/pr198-open-absent.log" | tr '\n' '|')"
  fi

  pr198_variant missing-key "$PR198"
  sh "$TIX198" "$F198" open --id 70-omega-reason --complexity C1 --title 'Omega fixture ticket' --ledger-line "$LED_OPEN" >"$D/pr198-open-missing.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S198" = "$(tix_state "$F198")" ] && grep -q 'profile_reason 缺维度键: S' "$D/pr198-open-missing.log"; then
    ok '负例 AC2 新 task profile_reason 缺维度键 open → exit 1 零写入且报文指名键'
  else
    bad '负例 AC2 新 task profile_reason 缺维度键 open → exit 1 零写入且报文指名键' "exit=$rc $(head -n 2 "$D/pr198-open-missing.log" | tr '\n' '|')"
  fi

  # AC2 正例：valid 正开落地（索引落条目）
  tix_body "$PR198" 70-omega-reason
  sh "$TIX198" "$F198" open --id 70-omega-reason --complexity C1 --title 'Omega fixture ticket' --ledger-line "$LED_OPEN" >"$D/pr198-open-ok.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "70-omega-reason"' "$F198/facts/requirements/tickets/index.json"; then
    ok '正例 AC2 新 task profile_reason 七键齐 open → exit 0 且索引落条目（valid 正开落地）'
  else
    bad '正例 AC2 新 task profile_reason 七键齐 open → exit 0 且索引落条目（valid 正开落地）' "exit=$rc $(head -n 2 "$D/pr198-open-ok.log" | tr '\n' '|')"
  fi

  # ---- 状态跃迁门禁断言（take blocked_by 完整性门＋actual_time 收口 done 条件化）----
  # 独立夹具 fix199（免受前段状态影响）。AC1：take 对 missing／未 done blocker 均拒绝——
  # exit 1、四载体指纹零写入且无投影、报文指名 blocker id（missing 报索引零命中；pending
  # 报其索引 status）；blocker 全 done 正例成功领取且索引单写；对照证明 flip 不做
  # blocked_by 门（零误伤）。AC2：task 仅 flip 至 done 强制 actual_time——非 done 翻转无
  # actual_time 照旧成功、done 缺 actual_time 仍 fail-closed 零写入指名缺项、request 翻转
  # 豁免维持。夹具全 mktemp。
  tix_build_fixture "$D/fix199"
  F199=$D/fix199
  # 索引整体重建（合法 JSON，一条目一行排版保持——被依赖票状态供 blocked_by 完整性门
  # 读取面 python 解析；10=done 正例 blocker、20=ready 负例 blocker）
  cat > "$F199/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},
    {"id": "20-beta-second", "status": "ready", "complexity": "C2", "blocked_by": [], "updated_at": "2026-09-19T11:00"},
    {"id": "30-dep-ghost", "status": "ready", "complexity": "C1", "blocked_by": ["99-ghost-none"], "updated_at": "2026-10-20T10:00"},
    {"id": "31-dep-pending", "status": "ready", "complexity": "C1", "blocked_by": ["20-beta-second"], "updated_at": "2026-10-20T10:01"},
    {"id": "32-dep-ok", "status": "ready", "complexity": "C1", "blocked_by": ["10-alpha-first"], "updated_at": "2026-10-20T10:02"},
    {"id": "41-req-gate", "status": "ready", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-20T10:03"}
  ]
}
EOF
  # shellcheck disable=SC2129  # 连续追加同一 README 夹具（逐行带 SC2016 豁免，分组改写降低可读性）
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`30-dep-ghost.json\` | 任务票 30；\`ready\`（2026-10-20 开票） | DEP ghost fixture |\n' >> "$F199/facts/requirements/tickets/README.md"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`31-dep-pending.json\` | 任务票 31；\`ready\`（2026-10-20 开票） | DEP pending fixture |\n' >> "$F199/facts/requirements/tickets/README.md"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`32-dep-ok.json\` | 任务票 32；\`ready\`（2026-10-20 开票） | DEP ok fixture |\n' >> "$F199/facts/requirements/tickets/README.md"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| \`41-req-gate.json\` | 任务票 41；\`ready\`（2026-10-20 开票） | REQ gate fixture |\n' >> "$F199/facts/requirements/tickets/README.md"
  tix_body "$F199/facts/requirements/tickets/30-dep-ghost.json" 30-dep-ghost
  sed 's/"blocked_by": \[\]/"blocked_by": ["99-ghost-none"]/' "$F199/facts/requirements/tickets/30-dep-ghost.json" > "$F199/b199a.tmp" && mv "$F199/b199a.tmp" "$F199/facts/requirements/tickets/30-dep-ghost.json"
  tix_body "$F199/facts/requirements/tickets/31-dep-pending.json" 31-dep-pending
  sed 's/"blocked_by": \[\]/"blocked_by": ["20-beta-second"]/' "$F199/facts/requirements/tickets/31-dep-pending.json" > "$F199/b199b.tmp" && mv "$F199/b199b.tmp" "$F199/facts/requirements/tickets/31-dep-pending.json"
  tix_body "$F199/facts/requirements/tickets/32-dep-ok.json" 32-dep-ok
  sed 's/"blocked_by": \[\]/"blocked_by": ["10-alpha-first"]/' "$F199/facts/requirements/tickets/32-dep-ok.json" > "$F199/b199c.tmp" && mv "$F199/b199c.tmp" "$F199/facts/requirements/tickets/32-dep-ok.json"
  cat > "$F199/facts/requirements/tickets/41-req-gate.json" <<'EOF'
{
  "id": "41-req-gate",
  "kind": "request",
  "title": "fixture request（actual_time 豁免维持）",
  "created_at": "2026-10-20"
}
EOF
  LED199='{"date": "2026-10-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 199", "evidence_ref": "facts/requirements/tickets/README.md"}'

  S199=$(tix_state "$F199")
  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" take --id 30-dep-ghost --status in_progress --ledger-line "$LED199" >"$D/g199a.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S199" = "$(tix_state "$F199")" ] && [ ! -f "$F199/facts/requirements/tickets/progress-current.md" ] && grep -q '99-ghost-none' "$D/g199a.log" && grep -q '不存在' "$D/g199a.log"; then
    ok '负例 N-199a take missing blocker → exit 1 零写入且报文指名 blocker id（blocked_by 完整性门）'
  else
    bad '负例 N-199a take missing blocker → exit 1 零写入且报文指名 blocker id（blocked_by 完整性门）' "exit=$rc $(head -n 2 "$D/g199a.log" | tr '\n' '|')"
  fi

  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" take --id 31-dep-pending --status in_progress --ledger-line "$LED199" >"$D/g199b.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S199" = "$(tix_state "$F199")" ] && [ ! -f "$F199/facts/requirements/tickets/progress-current.md" ] && grep -q '20-beta-second' "$D/g199b.log" && grep -q 'status=ready' "$D/g199b.log"; then
    ok '负例 N-199b take 未 done blocker → exit 1 零写入且报文指名 blocker id 与其状态（blocked_by 完整性门）'
  else
    bad '负例 N-199b take 未 done blocker → exit 1 零写入且报文指名 blocker id 与其状态（blocked_by 完整性门）' "exit=$rc $(head -n 2 "$D/g199b.log" | tr '\n' '|')"
  fi

  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" take --id 32-dep-ok --status in_progress --ledger-line "$LED199" >"$D/g199c.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "32-dep-ok", "status": "in_progress"' "$F199/facts/requirements/tickets/index.json"; then
    ok '正例 P-199c blocker 全 done take → exit 0 且索引单写（blocked_by 完整性门零误伤）'
  else
    bad '正例 P-199c blocker 全 done take → exit 0 且索引单写（blocked_by 完整性门零误伤）' "exit=$rc $(head -n 2 "$D/g199c.log" | tr '\n' '|')"
  fi

  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" flip --id 31-dep-pending --status in_progress --ledger-line "$LED199" >"$D/g199d.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "31-dep-pending", "status": "in_progress"' "$F199/facts/requirements/tickets/index.json"; then
    ok '正例 P-199d 带未 done blocker 的票 flip → exit 0 且索引单写（门仅限 take 零误伤；非 done 翻转无 actual_time 照旧成功）'
  else
    bad '正例 P-199d 带未 done blocker 的票 flip → exit 0 且索引单写（门仅限 take 零误伤；非 done 翻转无 actual_time 照旧成功）' "exit=$rc $(head -n 2 "$D/g199d.log" | tr '\n' '|')"
  fi

  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" flip --id 30-dep-ghost --status review_ready --ledger-line "$LED199" >"$D/g199e.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "30-dep-ghost", "status": "review_ready"' "$F199/facts/requirements/tickets/index.json"; then
    ok '正例 P-199e task flip 至非 done 无 actual_time → exit 0 且索引单写（actual_time 仅 done 强制）'
  else
    bad '正例 P-199e task flip 至非 done 无 actual_time → exit 0 且索引单写（actual_time 仅 done 强制）' "exit=$rc $(head -n 2 "$D/g199e.log" | tr '\n' '|')"
  fi

  SNF199=$(tix_state "$F199")
  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" flip --id 32-dep-ok --status 'done' --ledger-line "$LED199" >"$D/g199f.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SNF199" = "$(tix_state "$F199")" ] && [ "$(tix_index_status "$F199/facts/requirements/tickets/index.json" 32-dep-ok)" = 'in_progress' ] && grep -q 'actual_time' "$D/g199f.log" && grep -q '32-dep-ok' "$D/g199f.log"; then
    ok '负例 N-199f task flip 至 done 缺 actual_time → exit 1 零写入且指名票 id 与缺项（done 收口 fail-closed）'
  else
    bad '负例 N-199f task flip 至 done 缺 actual_time → exit 1 零写入且指名票 id 与缺项（done 收口 fail-closed）' "exit=$rc $(head -n 2 "$D/g199f.log" | tr '\n' '|')"
  fi

  sh "$F199/rules/implementation/scripts/ticket-ops.sh" "$F199" flip --id 41-req-gate --status in_progress --ledger-line "$LED199" >"$D/g199g.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "41-req-gate", "status": "in_progress"' "$F199/facts/requirements/tickets/index.json"; then
    ok '正例 P-199g request 票 flip 至非 done 无 actual_time → exit 0 且索引单写（request 豁免维持）'
  else
    bad '正例 P-199g request 票 flip 至非 done 无 actual_time → exit 0 且索引单写（request 豁免维持）' "exit=$rc $(head -n 2 "$D/g199g.log" | tr '\n' '|')"
  fi

  # ---- 票 228 F1/F2：flip-index 索引单写代理（唯一写入方收敛面）----
  # 正例：显式 --updated-at 落索引且投影再生（票 277 起 README 票表生成块随之派生、账本/
  # 票本体零接触）；负例：缺 --status／--updated-at、status 越状态机、updated_at
  # 非 ISO、携带 --ledger-line、锚点零命中——均 fail-closed 零写入。
  tix_build_fixture "$D/fix228"
  F228="$D/fix228"
  cp "$F228/facts/requirements/tickets/README.md" "$D/fi228.readme.before"
  cp "$F228/facts/project/changes.jsonl" "$D/fi228.ledger.before"
  sh "$F228/rules/implementation/scripts/ticket-ops.sh" "$F228" flip-index --id 20-beta-second --status review_pass --updated-at '2026-10-26T08:30' >"$D/fi228.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '"id": "20-beta-second", "status": "review_pass", "complexity": "C2", "blocked_by": \[\], "updated_at": "2026-10-26T08:30"' "$F228/facts/requirements/tickets/index.json" \
    && grep -q '| 20-beta-second | review_pass |  | 2026-10-26T08:30 |' "$F228/facts/requirements/tickets/progress-current.md" \
    && [ "$(tix_readme_token "$F228/facts/requirements/tickets/README.md" 20)" = 'review_pass' ] \
    && cmp -s "$D/fi228.ledger.before" "$F228/facts/project/changes.jsonl" \
    && grep -q '票表生成块' "$D/fi228.log"; then
    ok '正例 P-228a flip-index 显式 status/updated_at → exit 0 索引单写＋投影再生＋票表生成块派生且账本零变化（票 228 F1/F2；票 277）'
  else
    bad '正例 P-228a flip-index 显式 status/updated_at → exit 0 索引单写＋投影再生＋票表生成块派生且账本零变化（票 228 F1/F2；票 277）' "exit=$rc token=$(tix_readme_token "$F228/facts/requirements/tickets/README.md" 20) $(tail -n 2 "$D/fi228.log" | tr '\n' '|')"
  fi
  # 索引其余字段（complexity/blocked_by）与另一条目零变化已由上断言整行 grep 覆盖；
  # 此处补第二锚点行保真（10-alpha-first 行逐字节不动）。
  if grep -q '"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": \[\], "updated_at": "2026-09-19T10:00"' "$F228/facts/requirements/tickets/index.json"; then
    ok '正例 P-228b flip-index 单写后其余条目行逐字节保留（一条目一行单点替换）'
  else
    bad '正例 P-228b flip-index 单写后其余条目行逐字节保留（一条目一行单点替换）' '10-alpha-first 行漂移'
  fi

  tix_build_fixture "$D/fix228n"
  FN228="$D/fix228n"
  SN228=$(tix_state "$FN228")
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 20-beta-second >"$D/fi228n1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '缺少 --status' "$D/fi228n1.log"; then
    ok '负例 N-228a flip-index 缺 --status → exit 1 零写入（fail-closed）'
  else
    bad '负例 N-228a flip-index 缺 --status → exit 1 零写入（fail-closed）' "exit=$rc $(head -n 2 "$D/fi228n1.log" | tr '\n' '|')"
  fi
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 20-beta-second --status review_pass >"$D/fi228n2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '缺少 --updated-at' "$D/fi228n2.log"; then
    ok '负例 N-228b flip-index 缺 --updated-at → exit 1 零写入（fail-closed）'
  else
    bad '负例 N-228b flip-index 缺 --updated-at → exit 1 零写入（fail-closed）' "exit=$rc $(head -n 2 "$D/fi228n2.log" | tr '\n' '|')"
  fi
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 20-beta-second --status shipped --updated-at '2026-10-26T08:30' >"$D/fi228n3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '不合状态机取值' "$D/fi228n3.log"; then
    ok '负例 N-228c flip-index status 越状态机 → exit 1 零写入（fail-closed）'
  else
    bad '负例 N-228c flip-index status 越状态机 → exit 1 零写入（fail-closed）' "exit=$rc $(head -n 2 "$D/fi228n3.log" | tr '\n' '|')"
  fi
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 20-beta-second --status 'done' --updated-at '2026-10-26 08:30' >"$D/fi228n4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '不合 ISO 8601 口径' "$D/fi228n4.log"; then
    ok '负例 N-228d flip-index updated_at 非 ISO 8601 → exit 1 零写入（fail-closed）'
  else
    bad '负例 N-228d flip-index updated_at 非 ISO 8601 → exit 1 零写入（fail-closed）' "exit=$rc $(head -n 2 "$D/fi228n4.log" | tr '\n' '|')"
  fi
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 20-beta-second --status 'done' --updated-at '2026-10-26T08:30' --ledger-line '{"date": "2026-10-26", "kind": "scope", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$D/fi228n5.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '不得携带 --ledger-line' "$D/fi228n5.log"; then
    ok '负例 N-228e flip-index 携带 --ledger-line → exit 2 零写入（索引单写代理不落账本行，票 228 F1/F2）'
  else
    bad '负例 N-228e flip-index 携带 --ledger-line → exit 2 零写入（索引单写代理不落账本行，票 228 F1/F2）' "exit=$rc $(head -n 2 "$D/fi228n5.log" | tr '\n' '|')"
  fi
  sh "$FN228/rules/implementation/scripts/ticket-ops.sh" "$FN228" flip-index --id 99-ghost-none --status 'done' --updated-at '2026-10-26T08:30' >"$D/fi228n6.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN228" = "$(tix_state "$FN228")" ] && grep -q '锚点命中 0 行' "$D/fi228n6.log"; then
    ok '负例 N-228f flip-index 锚点零命中 → exit 1 零写入（fail-closed）'
  else
    bad '负例 N-228f flip-index 锚点零命中 → exit 1 零写入（fail-closed）' "exit=$rc $(head -n 2 "$D/fi228n6.log" | tr '\n' '|')"
  fi

  # ---- 派发合同门分层（AC6 改判：开票不校验 dispatch 节；完整性门归派发阶段）----
  # 原「dispatch 节开票门」五例随本票改判，改判理由逐条：
  #   缺 dispatch 节 → open 走 AC6（开票不预填未来证据），原 exit 1 期望改为 exit 0；
  #   缺阶段对象 → 阶段对象改可选（派发可逐阶段填），open 不再拒；改由 contract-build 守；
  #   越键 → 开票门删除后 open 不拒；改由 contract-build 阶段键集恰等门守（越键 exit 1）；
  #   空白值 → schema 值约束改形状（字符串），非空白完整性移派发时点；改由 contract-build 守；
  #   缺键 → 开票不拒：json-validator 只执行顶层 required，不递归 stage 的 required（实测），
  #          schema 对本阶段只保留形状约束；缺键由派发阶段 contract-build 拒绝（json get 零命中）。
  # 该 block 同时守住「派发阶段生成合同」：contract-build 对无节/缺阶段/越键/缺键/必填键空白
  # exit 1 零 stdout，对收口事实（ACTUAL_TIME/实施摘要/审查指针）留空按其标注渲染。
  dc243_variant() {
    # $1=variant $2=out：自 tix_body 正例基体派生各形态（python3 json 改写）
    tix_body "$2.base" 80-dispatch-gate
    python3 - "$2.base" "$2" "$1" <<'PYTHON'
import json, sys
body = json.load(open(sys.argv[1], encoding='utf-8'))
mode = sys.argv[3]
dp = body.get('dispatch')
if mode == 'absent':
    body.pop('dispatch', None)
elif mode == 'missing-stage':
    del dp['commit']
elif mode == 'missing-key':
    del dp['implementation']['GOAL']
elif mode == 'extra-key':
    dp['review']['EXTRA_KEY'] = 'fixture 越键'
elif mode == 'blank-value':
    dp['review']['TICKET_ID'] = '   '
elif mode == 'blank-future':
    dp['implementation']['ACTUAL_TIME'] = ''
    dp['review']['IMPLEMENTATION_SUMMARY'] = 'pending'
    dp['commit']['REVIEW_PASS_CHECKPOINT'] = 'pending'
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
PYTHON
  }
  dc243_open_ok() {
    # $1=例名 $2=variant：独立夹具 open 必 exit 0 且索引落 ready 条目
    FG243=$D/fix243gate-$2
    tix_build_fixture "$FG243"
    dc243_variant "$2" "$D/gate-$2.json"
    mv "$D/gate-$2.json" "$FG243/facts/requirements/tickets/80-dispatch-gate.json"
    sh "$FG243/rules/implementation/scripts/ticket-ops.sh" "$FG243" open --id 80-dispatch-gate --complexity C1 --title 'Dispatch fixture ticket' --ledger-line "$LED_OPEN" >"$D/gate-$2.log" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -q '"id": "80-dispatch-gate", "status": "ready"' "$FG243/facts/requirements/tickets/index.json"; then
      ok "正例 AC6 开票不校验 dispatch（${1}）→ exit 0 且索引落 ready"
    else
      bad "正例 AC6 开票不校验 dispatch（${1}）→ exit 0 且索引落 ready" "exit=$rc $(head -n 2 "$D/gate-$2.log" | tr '\n' '|')"
    fi
  }
  dc243_open_ok '缺 dispatch 节' absent
  dc243_open_ok '缺 commit 阶段对象' missing-stage
  dc243_open_ok '越键（review.EXTRA_KEY）' extra-key
  dc243_open_ok '收口事实留空（ACTUAL_TIME/实施摘要/审查指针）' blank-future
  dc243_open_ok '空白值（review.TICKET_ID）' blank-value
  dc243_open_ok '缺键（implementation.GOAL，嵌套 required 归派发阶段）' missing-key
  # 派发阶段完整性门（contract-build 渲染面；票 243 起开票不预填，合同在派发时点生成）
  dc243_build_gate() {
    # $1=例名 $2=variant $3=stage $4=期望 exit $5=输出必含片段（空＝不查）
    FG243B=$D/fix243build-$2
    tix_build_fixture "$FG243B"
    dc243_variant "$2" "$D/build-$2.json"
    mv "$D/build-$2.json" "$FG243B/facts/requirements/tickets/80-dispatch-gate.json"
    sh "$SCRIPT_DIR/contract-build.sh" "$3" 80 "$FG243B" >"$D/build-$2-$3.log" 2>&1
    rc=$?
    dc243_hit=''
    if [ -n "$5" ]; then
      grep -qF -- "$5" "$D/build-$2-$3.log" && dc243_hit='yes'
    else
      dc243_hit='yes'
    fi
    if [ "$rc" -eq "$4" ] && [ -n "$dc243_hit" ]; then
      ok "派发阶段门 ${1}（contract-build $3 → exit $4）"
    else
      bad "派发阶段门 ${1}（contract-build $3 → exit $4）" "exit=$rc $(head -n 2 "$D/build-$2-$3.log" | tr '\n' '|')"
    fi
  }
  dc243_build_gate '越键（review.EXTRA_KEY）不可渲染' extra-key review 1 '键集'
  dc243_build_gate '无节票不可渲染' absent implementation 1 'dispatch.implementation'
  dc243_build_gate '缺阶段对象即拒' missing-stage commit 1 'dispatch.commit'
  dc243_build_gate '必填键空白即拒' blank-value review 1 'TICKET_ID'
  dc243_build_gate '缺键（implementation.GOAL）不可渲染' missing-key implementation 1 '键集与 contract_fields 不恰等'
  dc243_build_gate '收口事实留空按标注渲染' blank-future implementation 0 '（收口时按实际写入）'
  # 读取面兼容正例：存量无节票（tix_body_at 形态）flip 照旧——开票校验与读取校验分层
  tix_build_fixture "$D/fix230"
  F230=$D/fix230
  TIX230="$F230/rules/implementation/scripts/ticket-ops.sh"
  tix_body_at "$F230/facts/requirements/tickets/20-beta-second.json" 20-beta-second
  sh "$TIX230" "$F230" flip --id 20-beta-second --status in_progress --ledger-line "$LED_FLIP" >"$D/dc230-flip.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "20-beta-second", "status": "in_progress"' "$F230/facts/requirements/tickets/index.json"; then
    ok '正例 存量无节票 flip → exit 0 且索引单写（读取面不要求 dispatch，存量零回扫）'
  else
    bad '正例 存量无节票 flip → exit 0 且索引单写（读取面不要求 dispatch，存量零回扫）' "exit=$rc $(head -n 2 "$D/dc230-flip.log" | tr '\n' '|')"
  fi

  # ---- 票 237：close/flip/flip-index 三入口 done 证据门（同一判定，不留自报旁路）----
  # 负例：无已提交证据 → 三入口均 exit 1 decision-required 且零写入（审计 P01 短路）。
  LED237='{"date": "2026-10-04", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture audit gate", "evidence_ref": "facts/requirements/tickets/42-audit-gate.json"}'
  tix_audit_fixture "$D/a237n" none
  FA237N=$D/a237n
  S237N=$(tix_state "$FA237N")
  sh "$FA237N/rules/implementation/scripts/ticket-ops.sh" "$FA237N" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237n-close.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237N" = "$(tix_state "$FA237N")" ] \
    && grep -q 'decision-required' "$D/a237n-close.log" \
    && grep -q 'FAIL P01 receipt-parseable:' "$D/a237n-close.log"; then
    ok '负例 N-237a close 无证据 → exit 1 decision-required 且零写入（P01 短路）'
  else
    bad '负例 N-237a close 无证据 → exit 1 decision-required 且零写入（P01 短路）' "exit=$rc $(head -n 2 "$D/a237n-close.log" | tr '\n' '|')"
  fi
  sh "$FA237N/rules/implementation/scripts/ticket-ops.sh" "$FA237N" flip --id 42-audit-gate --status 'done' --ledger-line "$LED237" >"$D/a237n-flip.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237N" = "$(tix_state "$FA237N")" ] \
    && grep -q 'decision-required' "$D/a237n-flip.log" \
    && grep -q 'FAIL P01 receipt-parseable:' "$D/a237n-flip.log"; then
    ok '负例 N-237b flip 至 done 无证据 → exit 1 decision-required 且零写入（与 close 同判）'
  else
    bad '负例 N-237b flip 至 done 无证据 → exit 1 decision-required 且零写入（与 close 同判）' "exit=$rc $(head -n 2 "$D/a237n-flip.log" | tr '\n' '|')"
  fi
  sh "$FA237N/rules/implementation/scripts/ticket-ops.sh" "$FA237N" flip-index --id 42-audit-gate --status 'done' --updated-at '2026-10-04T10:00' >"$D/a237n-fi.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237N" = "$(tix_state "$FA237N")" ] \
    && grep -q 'decision-required' "$D/a237n-fi.log" \
    && grep -q 'FAIL P01 receipt-parseable:' "$D/a237n-fi.log"; then
    ok '负例 N-237c flip-index 至 done 无证据 → exit 1 decision-required 且零写入（三入口同判）'
  else
    bad '负例 N-237c flip-index 至 done 无证据 → exit 1 decision-required 且零写入（三入口同判）' "exit=$rc $(head -n 2 "$D/a237n-fi.log" | tr '\n' '|')"
  fi

  # 负例 AC1：审查后产品 diff 变化（证据仍已提交）→ P04 拒，close 零写入。
  tix_audit_fixture "$D/a237s" stale
  FA237S=$D/a237s
  S237S=$(tix_state "$FA237S")
  sh "$FA237S/rules/implementation/scripts/ticket-ops.sh" "$FA237S" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237s.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237S" = "$(tix_state "$FA237S")" ] \
    && grep -q 'decision-required' "$D/a237s.log" \
    && grep -q 'FAIL P04 review-boundary-clean:' "$D/a237s.log"; then
    ok '负例 N-237d 审查后 diff 变化 → exit 1 decision-required 且零写入（P04）'
  else
    bad '负例 N-237d 审查后 diff 变化 → exit 1 decision-required 且零写入（P04）' "exit=$rc $(head -n 2 "$D/a237s.log" | tr '\n' '|')"
  fi

  # 负例 AC1：证据未提交（工作树在、HEAD 未跟踪）→ P02 拒，flip 零写入。
  tix_audit_fixture "$D/a237u" uncommitted
  FA237U=$D/a237u
  S237U=$(tix_state "$FA237U")
  sh "$FA237U/rules/implementation/scripts/ticket-ops.sh" "$FA237U" flip --id 42-audit-gate --status 'done' --ledger-line "$LED237" >"$D/a237u.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237U" = "$(tix_state "$FA237U")" ] \
    && grep -q 'decision-required' "$D/a237u.log" \
    && grep -q 'FAIL P02 evidence-committed:' "$D/a237u.log"; then
    ok '负例 N-237e 证据未提交 → exit 1 decision-required 且零写入（P02）'
  else
    bad '负例 N-237e 证据未提交 → exit 1 decision-required 且零写入（P02）' "exit=$rc $(head -n 2 "$D/a237u.log" | tr '\n' '|')"
  fi

  # 正例：已提交且绑定 diff 的证据 → 三入口逐一放行，索引落 done。
  tix_audit_fixture "$D/a237c" committed
  FA237C=$D/a237c
  sh "$FA237C/rules/implementation/scripts/ticket-ops.sh" "$FA237C" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237c-close.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "42-audit-gate", "status": "done"' "$FA237C/facts/requirements/tickets/index.json" \
    && grep -q '证据门: close 放行' "$D/a237c-close.log" \
    && grep -q '目录 README 收口预检通过' "$D/a237c-close.log" \
    && [ "$(tix_readme_token "$FA237C/facts/requirements/tickets/README.md" 42)" = 'done' ]; then
    ok '正例 P-237a close＋conformant 证据 → exit 0 索引/README 落 done 且证据门放行'
  else
    bad '正例 P-237a close＋conformant 证据 → exit 0 索引/README 落 done 且证据门放行' "exit=$rc $(head -n 2 "$D/a237c-close.log" | tr '\n' '|')"
  fi
  sh "$FA237C/rules/implementation/scripts/ticket-ops.sh" "$FA237C" flip --id 42-audit-gate --status 'done' --ledger-line "$LED237" >"$D/a237c-flip.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '证据门: flip 放行' "$D/a237c-flip.log"; then
    ok '正例 P-237b flip 至 done＋同一证据 → exit 0 且证据门放行（与 close 同判）'
  else
    bad '正例 P-237b flip 至 done＋同一证据 → exit 0 且证据门放行（与 close 同判）' "exit=$rc $(head -n 2 "$D/a237c-flip.log" | tr '\n' '|')"
  fi
  sh "$FA237C/rules/implementation/scripts/ticket-ops.sh" "$FA237C" flip-index --id 42-audit-gate --status 'done' --updated-at '2026-10-04T10:00' >"$D/a237c-fi.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "42-audit-gate", "status": "done", "complexity": "C1", "blocked_by": \[\], "updated_at": "2026-10-04T10:00"' "$FA237C/facts/requirements/tickets/index.json" \
    && grep -q '证据门: flip-index 放行' "$D/a237c-fi.log"; then
    ok '正例 P-237c flip-index 至 done＋同一证据 → exit 0 索引单写且证据门放行'
  else
    bad '正例 P-237c flip-index 至 done＋同一证据 → exit 0 索引单写且证据门放行' "exit=$rc $(head -n 2 "$D/a237c-fi.log" | tr '\n' '|')"
  fi

  # ---- 票 237 收尾：允许集形态约束（dispatch.commit.REVIEW_PASS_CHECKPOINT 只认本票
  # 规范路径 facts/requirements/tickets/<票 id>-review-checkpoint.md）----
  # 负例 N-237g：票面声明 a.txt（产品文件）＋审查后产品改动 → 形态不符、不纳入允许集，
  # P04 仍判审查后改动 → exit 1 零写入。
  TIX237_CP='a.txt'
  TIX237_LATE=product
  tix_audit_fixture "$D/a237g" committed
  unset TIX237_CP TIX237_LATE
  FA237G=$D/a237g
  S237G=$(tix_state "$FA237G")
  sh "$FA237G/rules/implementation/scripts/ticket-ops.sh" "$FA237G" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237g.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237G" = "$(tix_state "$FA237G")" ] \
    && grep -q 'REVIEW_PASS_CHECKPOINT 形态不符，不纳入允许集: a.txt' "$D/a237g.log" \
    && grep -q 'FAIL P04 review-boundary-clean:' "$D/a237g.log"; then
    ok '负例 N-237g 票面声明 a.txt → 形态不符不纳入允许集，审查后产品改动仍被 P04 拒（exit 1 零写入）'
  else
    bad '负例 N-237g 票面声明 a.txt → 形态不符不纳入允许集，审查后产品改动仍被 P04 拒（exit 1 零写入）' "exit=$rc $(head -n 2 "$D/a237g.log" | tr '\n' '|')"
  fi

  # 正例 P-237d：票面声明规范 Review Checkpoint 路径＋审查后仅写该文件 → 允许集生效放行。
  TIX237_CP='facts/requirements/tickets/42-audit-gate-review-checkpoint.md'
  TIX237_LATE=checkpoint
  tix_audit_fixture "$D/a237h" committed
  unset TIX237_CP TIX237_LATE
  FA237H=$D/a237h
  sh "$FA237H/rules/implementation/scripts/ticket-ops.sh" "$FA237H" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237h.log" 2>&1
  rc=$?
  if require_out 'suite-ticket-ops 目标输出在场' "$D/a237h.log" \
    && [ "$rc" -eq 0 ] \
    && grep -q '证据门: close 放行' "$D/a237h.log" \
    && ! grep -q '形态不符' "$D/a237h.log"; then
    ok '正例 P-237d 票面声明规范 Review Checkpoint＋审查后仅写该文件 → 允许集生效，close exit 0 放行'
  else
    bad '正例 P-237d 票面声明规范 Review Checkpoint＋审查后仅写该文件 → 允许集生效，close exit 0 放行' "exit=$rc $(head -n 2 "$D/a237h.log" | tr '\n' '|')"
  fi

  # 负例 N-237h：同前缀异形路径（.md.bak）＋审查后产品改动 → 形态不符、P04 拒。
  TIX237_CP='facts/requirements/tickets/42-audit-gate-review-checkpoint.md.bak'
  TIX237_LATE=product
  tix_audit_fixture "$D/a237i" committed
  unset TIX237_CP TIX237_LATE
  FA237I=$D/a237i
  S237I=$(tix_state "$FA237I")
  sh "$FA237I/rules/implementation/scripts/ticket-ops.sh" "$FA237I" close --id 42-audit-gate --ledger-line "$LED237" >"$D/a237i.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237I" = "$(tix_state "$FA237I")" ] \
    && grep -q 'REVIEW_PASS_CHECKPOINT 形态不符，不纳入允许集: facts/requirements/tickets/42-audit-gate-review-checkpoint.md.bak' "$D/a237i.log" \
    && grep -q 'FAIL P04 review-boundary-clean:' "$D/a237i.log"; then
    ok '负例 N-237h 同前缀异形 .md.bak → 形态不符不纳入允许集，审查后产品改动仍被 P04 拒（exit 1 零写入）'
  else
    bad '负例 N-237h 同前缀异形 .md.bak → 形态不符不纳入允许集，审查后产品改动仍被 P04 拒（exit 1 零写入）' "exit=$rc $(head -n 2 "$D/a237i.log" | tr '\n' '|')"
  fi

  # 负例：flip-index done 双证缺一（有证据但缺 actual_time）→ actual_time 先拒。
  tix_audit_fixture "$D/a237t" committed
  FA237T=$D/a237t
  tix_body "$FA237T/facts/requirements/tickets/42-audit-gate.json" 42-audit-gate
  S237T=$(tix_state "$FA237T")
  sh "$FA237T/rules/implementation/scripts/ticket-ops.sh" "$FA237T" flip-index --id 42-audit-gate --status 'done' --updated-at '2026-10-04T10:00' >"$D/a237t.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S237T" = "$(tix_state "$FA237T")" ] \
    && grep -q 'actual_time' "$D/a237t.log"; then
    ok '负例 N-237f flip-index done 有证据但缺 actual_time → exit 1 零写入（双证缺一即拒）'
  else
    bad '负例 N-237f flip-index done 有证据但缺 actual_time → exit 1 零写入（双证缺一即拒）' "exit=$rc $(head -n 2 "$D/a237t.log" | tr '\n' '|')"
  fi

  # ---- 目录 README 收口门禁：close／flip 至 done 在取锁与写入前跑
  #      --check --blocks-only ＋ --freshness 两检，不调用 --sync ----
  # 负例：生成块结构漂移（缺 ## 读取禁忌）→ 结构 --check 阻断并指名 file:line。
  tix_audit_fixture "$D/dr-gate" committed
  FDG=$D/dr-gate
  mkdir -p "$FDG/docs"
  cat > "$FDG/docs/README.md" <<'EOF'
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
  sh "$FDG/rules/implementation/scripts/ticket-ops.sh" "$FDG" close --id 42-audit-gate --ledger-line "$LED237" >"$D/dr-gate.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'docs/README\.md:[0-9][0-9]*: 缺少段：## 读取禁忌' "$D/dr-gate.log" \
    && grep -q '目录 README 结构校验未过' "$D/dr-gate.log" \
    && grep -q -- '--migrate-dry-run' "$D/dr-gate.log"; then
    ok 'AC1 目录 README 结构漂移 → close 阻断 exit 1 指名 docs/README.md:行 与断言并给迁移预演'
  else
    bad 'AC1 目录 README 结构漂移 → close 阻断 exit 1 指名 docs/README.md:行 与断言并给迁移预演' "exit=$rc $(grep -n 'docs/README.md\|目录 README' "$D/dr-gate.log" | head -n 3 | tr '\n' '|')"
  fi

  # 负例：新增子目录未入生成块表 → 新鲜度检出漂移，exit 1 指名缺失行；
  # 收口链不调用 --sync，docs/README.md 与四载体零写入。
  tix_audit_fixture "$D/dr-fresh" committed
  FDR=$D/dr-fresh
  mkdir -p "$FDR/docs/child"
  printf '# child\n\n子目录职责句。\n' > "$FDR/docs/child/README.md"
  cat > "$FDR/docs/README.md" <<'EOF'
# docs

文档目录职责句。

## 权威
- 现行：`docs/child/README.md`

## 读取禁忌
- 不把本文件当白名单。

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
| `docs/child/` | 子目录职责句。 | — |
<!-- /dir-readme -->
EOF
  mkdir -p "$FDR/docs/newdir"
  printf '# newdir\n\n新增子目录职责句。\n' > "$FDR/docs/newdir/README.md"
  _drf_readme_before=$(cksum < "$FDR/docs/README.md")
  SDRF=$(tix_state "$FDR")
  sh "$FDR/rules/implementation/scripts/ticket-ops.sh" "$FDR" close --id 42-audit-gate --ledger-line "$LED237" >"$D/dr-fresh.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SDRF" = "$(tix_state "$FDR")" ] \
    && [ "$_drf_readme_before" = "$(cksum < "$FDR/docs/README.md")" ] \
    && grep -qE '^docs/README\.md:[0-9]+: 缺失行: .*docs/newdir/' "$D/dr-fresh.log" \
    && grep -q '生成块漂移' "$D/dr-fresh.log" \
    && grep -qF -- '--sync' "$D/dr-fresh.log"; then
    ok 'AC1 新增子目录未入表 → close exit 1 指名缺失行，README 与四载体零改写（不静默 --sync）'
  else
    bad 'AC1 新增子目录未入表 → close exit 1 指名缺失行，README 与四载体零改写（不静默 --sync）' "exit=$rc $(grep -n 'docs/README.md\|生成块' "$D/dr-fresh.log" | head -n 3 | tr '\n' '|')"
  fi

  # 负例：生成器缺失 → 预检 fail-closed（取锁与写入前），四载体零写入。
  tix_audit_fixture "$D/dr-nogen" committed
  FDNG=$D/dr-nogen
  rm -f "$FDNG/rules/implementation/scripts/generate-dir-readmes.sh"
  SDRNG=$(tix_state "$FDNG")
  sh "$FDNG/rules/implementation/scripts/ticket-ops.sh" "$FDNG" close --id 42-audit-gate --ledger-line "$LED237" >"$D/dr-nogen.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SDRNG" = "$(tix_state "$FDNG")" ] \
    && grep -q 'generate-dir-readmes.sh 不可用' "$D/dr-nogen.log"; then
    ok 'AC1 目录 README 生成器缺失 → close 预检 fail-closed exit 1 且四载体零写入'
  else
    bad 'AC1 目录 README 生成器缺失 → close 预检 fail-closed exit 1 且四载体零写入' "exit=$rc $(head -n 2 "$D/dr-nogen.log" | tr '\n' '|')"
  fi

  # ---- 票 268：新 task 票必备 user_stories（用户故事）开票门＋示例/模板同口径 ----
  # AC1/AC2：ticket-ops open（validator --new-ticket 链路）缺项／空数组／条目格式不符，
  # 一律 exit 1、四载体指纹零写入且报文指名 user_stories；合规条目放行落索引。
  # AC3：schema 属性、示例、issues-README 票模板与 assessment/AGENTS 路由句同口径
  # （套件机械核对单源；条目 pattern 与校验器现场执行同源）。
  F268="$D/fix268"
  tix_build_fixture "$F268"
  TIX268="$F268/rules/implementation/scripts/ticket-ops.sh"
  BODY268="$F268/facts/requirements/tickets/60-us-fixture.json"
  LED268='{"date": "2026-11-04", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture 268 user_stories", "evidence_ref": "facts/requirements/tickets/60-us-fixture.json"}'
  tix_body "$BODY268" 60-us-fixture
  sh "$TIX268" "$F268" open --id 60-us-fixture --complexity C1 --title 'US fixture ticket' --ledger-line "$LED268" >"$D/us268-pos.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "60-us-fixture"' "$F268/facts/requirements/tickets/index.json"; then
    ok '正例 268 user_stories 合规条目 open → exit 0 且索引落条目（AC2 合规放行）'
  else
    bad '正例 268 user_stories 合规条目 open → exit 0 且索引落条目（AC2 合规放行）' "exit=$rc $(head -n 2 "$D/us268-pos.log" | tr '\n' '|')"
  fi

  us268_case() {
    # $1=用例名 $2=派生模式 $3=报文必含片段：自 tix_body 正例基体派生负例本体
    USID="61-us-$2"
    python3 - "$BODY268" "$F268/facts/requirements/tickets/$USID.json" "$2" "$USID" <<'PYTHON'
import json, sys
base, out, mode, tid = sys.argv[1:5]
body = json.load(open(base, encoding='utf-8'))
body['id'] = tid
if mode == 'missing':
    body.pop('user_stories', None)
elif mode == 'empty':
    body['user_stories'] = []
elif mode == 'format':
    body['user_stories'] = ['作为需求提出者，我要没有 US 序号的用户故事，以便被拒收']
elif mode == 'not-array':
    body['user_stories'] = 'US1: 作为需求提出者，我要字符串形态，以便被拒收'
with open(out, 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
PYTHON
    S0=$(tix_state "$F268")
    LEDCASE="{\"date\": \"2026-11-04\", \"kind\": \"scope\", \"scope\": \"facts/requirements/tickets\", \"decision\": \"fixture 268 $2\", \"evidence_ref\": \"facts/requirements/tickets/$USID.json\"}"
    sh "$TIX268" "$F268" open --id "$USID" --complexity C1 --title 'US fixture ticket' --ledger-line "$LEDCASE" >"$D/us268-$2.log" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && [ "$S0" = "$(tix_state "$F268")" ] && grep -qF -- 'user_stories' "$D/us268-$2.log" && grep -qF -- "$3" "$D/us268-$2.log"; then
      ok "负例 268 $1 open → exit 1 零写入且报文指名 user_stories（AC1/AC2）"
    else
      bad "负例 268 $1 open → exit 1 零写入且报文指名 user_stories（AC1/AC2）" "exit=$rc $(head -n 2 "$D/us268-$2.log" | tr '\n' '|')"
    fi
  }
  us268_case 缺项 missing '新 task 票必须提供 user_stories'
  us268_case 空数组 empty 'user_stories 不能为空数组'
  us268_case 条目格式不符 format 'user_stories[0] 不合格式'
  us268_case 非数组形态 not-array 'user_stories 必须是数组'

  # 正例：存量票无 user_stories 读取面不要求（tix_body_at 保留无该字段的存量形态）
  tix_body_at "$D/us268-legacy.json" 62-us-legacy
  if python3 "$SCRIPT_DIR/json-validator.py" ticket "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$D/us268-legacy.json" >/dev/null 2>&1; then
    ok '正例 存量票无 user_stories 读取面不要求（开票校验与读取校验分层，AC1 向前生效）'
  else
    bad '正例 存量票无 user_stories 读取面不要求（开票校验与读取校验分层，AC1 向前生效）' 'exit 非 0'
  fi

  # AC3：schema 属性／示例／票模板／assessment、AGENTS 路由句同口径（单源机械核对）
  SCHEMA268="$SCRIPT_DIR/../references/schemas/ticket-record.schema.json"
  EXAMPLE268="$SCRIPT_DIR/../references/schemas/ticket-record.example.json"
  TMPL268="$SCRIPT_DIR/../references/templates"
  if python3 - "$SCHEMA268" "$EXAMPLE268" "$TMPL268" <<'PYTHON'
import json, re, sys
schema_path, example_path, tmpl_dir = sys.argv[1:4]
us = json.load(open(schema_path, encoding='utf-8'))['properties']['user_stories']
assert us['type'] == 'array' and us['minItems'] == 1
assert us['items']['type'] == 'string'
assert us['items']['pattern'] == r'^US[0-9]+: 作为.+，我要.+，以便.+$'
assert '至少一条' in us['description'] and 'US<n>' in us['description'] and '开票' in us['description']
stories = json.load(open(example_path, encoding='utf-8'))['user_stories']
rx = re.compile(us['items']['pattern'])
assert isinstance(stories, list) and stories
assert all(isinstance(s, str) and rx.search(s) for s in stories)
readme = open(tmpl_dir + '/issues-README.md.tmpl', encoding='utf-8').read()
assert 'user_stories' in readme and 'US<n>: 作为<角色>，我要<功能>，以便<收益>' in readme
assessment = open(tmpl_dir + '/assessment.md.tmpl', encoding='utf-8').read()
agents = open(tmpl_dir + '/AGENTS.md.tmpl', encoding='utf-8').read()
assert 'user_stories' in assessment and 'user_stories' in agents
assert 'US<n>: 作为<角色>，我要<功能>，以便<收益>' in assessment
assert 'US<n>: 作为<角色>，我要<功能>，以便<收益>' in agents
PYTHON
  then
    ok '正例 AC3 user_stories 口径单源：schema 属性/示例/票模板/assessment/AGENTS 同口径（套件可核）'
  else
    bad '正例 AC3 user_stories 口径单源：schema 属性/示例/票模板/assessment/AGENTS 同口径（套件可核）' '口径漂移或单源缺失'
  fi

  suite_summary 'ticket-ops'
}
