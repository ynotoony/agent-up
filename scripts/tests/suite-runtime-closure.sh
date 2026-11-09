#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite runtime-closure "$@"
  exit $?
fi

# ============================================================
# suite: runtime-closure（票 269 运行时依赖定位只认安装闭包）
# 场景：六运行脚本（ticket-ops/contract-build/ledger-append/ticket-run/run-record/
# test-checkpoint-recovery）运行时依赖只认安装闭包——脚本同目录 json-validator.py 与
# 脚本邻接 ../references/ 下的 schema/规则数据件；删除全部 repo_root/agent-up 工作树
# 回退；闭包缺失即 fail-closed 零写入，报文指名缺失件绝对路径与升级/修补入口。
# 断言面：静态负向扫描（六脚本运行时拼接零工作树回退）＋安装布局闭包正例（open／
# 渲染／账本预检／引擎门／stats）＋本地闭包与包工作树副本内容不同时以本地为准（工作
# 树副本坏件不被读取；本地缺件不回退）＋五入口闭包缺失 fail-closed（exit 非 0、报文
# 含缺失绝对路径与升级/修补入口、索引/README/账本/投影 cksum 前后一致）＋
# test-checkpoint-recovery 邻接 references/ 缺失 fail-closed。夹具全 mktemp。
# ============================================================

RC_SCRIPTS='ticket-ops.sh contract-build.sh ledger-append.sh ticket-run.sh run-record.sh test-checkpoint-recovery.sh'

# 安装布局夹具：脚本件落 rules/implementation/scripts/、闭包数据件落
# rules/implementation/references/（与安装器落位同构），并初始化 Git（run-record 前置）。
rc_build_repo() {
  RC_REPO=$1
  rm -rf "$RC_REPO"
  mkdir -p "$RC_REPO/rules/implementation/scripts" \
    "$RC_REPO/rules/implementation/references/schemas" \
    "$RC_REPO/rules/implementation/references/prompts" \
    "$RC_REPO/facts/requirements/tickets" "$RC_REPO/facts/project" \
    "$RC_REPO/facts/requirements/runs" || return 1
  for rc_f in ticket-ops.sh ledger-append.sh record-store.sh generate-progress.sh generate-dir-readmes.sh \
              dir-readme.rules common-helpers.sh json-validator.py ticket-audit.sh \
              contract-build.sh check-dispatch-contract.sh ticket-run.sh worktree-add.sh \
              dp-load-rules.sh check-gates.sh run-record.sh test-checkpoint-recovery.sh \
              workflow-executor.sh ticket-gates.sh audit-predicates.rules audit-p01-receipt-parseable.sh audit-p02-evidence-committed.sh audit-p03-base-sha-present.sh audit-p04-review-boundary-clean.sh audit-p05-diff-sha-bound.sh audit-p06-reviewer-identity-present.sh audit-p07-reviewer-identity-corroborated.sh audit-p08-reviewer-distinct-from-implementer.sh audit-p09-reviewed-at-valid.sh audit-p10-acceptance-results-present.sh audit-p11-policy-applicable.sh; do
    cp "$SCRIPT_DIR/$rc_f" "$RC_REPO/rules/implementation/scripts/$rc_f" || return 1
  done
  cp "$PKG_ROOT/references/schemas/ticket-record.schema.json" \
     "$PKG_ROOT/references/schemas/dispatch-contract.schema.json" \
     "$RC_REPO/rules/implementation/references/schemas/" || return 1
  for rc_p in implementation-prompt.md review-prompt.md commit-prompt.md; do
    cp "$PKG_ROOT/references/prompts/$rc_p" "$RC_REPO/rules/implementation/references/prompts/$rc_p" || return 1
  done
  cat > "$RC_REPO/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},
    {"id": "20-beta-second", "status": "ready", "complexity": "C2", "blocked_by": [], "updated_at": "2026-09-19T11:00"}
  ]
}
EOF
  cat > "$RC_REPO/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |
| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |
EOF
  printf '%s\n' '{"date": "2026-09-19", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture seed", "evidence_ref": "facts/requirements/tickets/index.json"}' > "$RC_REPO/facts/project/changes.jsonl" || return 1
  git_repo "$RC_REPO" && \
    git -C "$RC_REPO" -c user.email=fixture@t -c user.name=fixture add -A && \
    git -C "$RC_REPO" -c user.email=fixture@t -c user.name=fixture commit -qm 'runtime-closure fixture seed' || return 1
  return 0
}

# 票本体（open 本体 schema 合法形态；profile_reason 七键齐备；票 268 起新 task 开票门
# 必备 user_stories——夹具适配只加字段，不动任何断言逻辑与既有断言强度）
rc_write_body() {
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "profile_reason": {"D": "rc D reason", "B": "rc B reason", "I": "rc I reason", "U": "rc U reason", "S": "rc S reason", "M": "rc M reason", "O": "rc O reason"},
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "rc fixture complexity reason",
  "priority_reason": "rc fixture priority reason",
  "user_stories": ["US1: 作为夹具维护者，我要安装闭包正例开票携带用户故事，以便开票门正例有载体"],
  "actual_time": "1h（fixture 净工时占位）"
}
EOF
}

# dispatch 节夹具票：字段清单自重渲染权威 schema 现场提取（与 contract-build 同源）
rc_write_dispatch_ticket() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

ticket_path, schema_path = sys.argv[1], sys.argv[2]
with open(schema_path, encoding='utf-8') as fh:
    schema = json.load(fh)
keys = schema['contract_fields']['implementation']
ticket = {
    'id': '269-rc-contract',
    'kind': 'task',
    'title': 'runtime-closure contract fixture',
    'created_at': '2026-11-04',
    'dispatch': {'implementation': {key: 'fixture ' + key for key in keys}},
}
with open(ticket_path, 'w', encoding='utf-8') as fh:
    json.dump(ticket, fh, ensure_ascii=False, indent=2)
PY
}

# 四载体零写入指纹（索引/README/账本/投影四件；投影缺位记 no-projection）
rc_state() {
  {
    cksum "$1/facts/requirements/tickets/index.json" \
          "$1/facts/requirements/tickets/README.md" \
          "$1/facts/project/changes.jsonl" 2>/dev/null
    if [ -f "$1/facts/requirements/tickets/progress-current.md" ]; then
      cksum "$1/facts/requirements/tickets/progress-current.md"
    else
      printf 'no-projection\n'
    fi
  } | cksum
}

# 负例断言防真空：日志须在场且非空，再逐项 grep 绝对路径与升级/修补入口
rc_assert_fail_closed() {
  # $1=标签 $2=日志 $3=缺失件绝对路径
  if [ -s "$2" ] && grep -qF -- "$3" "$2" && grep -qF 'upgrade.md' "$2"; then
    ok "$1"
  else
    bad "$1" "日志缺缺失绝对路径（$3）或升级/修补入口: $(tail -n 2 "$2" 2>/dev/null | tr '\n' '|')"
  fi
}

suite_runtime_closure() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='runtime-closure'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  RC_D=$T/rc
  mkdir -p "$RC_D" || exit 2
  # 路径规范化：引擎定位走 pwd（逻辑路径），邻接 references/ 闭合根走 pwd -P（物理
  # 路径）；断言期望值按同一口径构造，避免 /var 与 /private/var、双斜杠差异误判
  RC_D=$(CDPATH='' cd -- "$RC_D" && pwd) || exit 2
  RC_P=$(CDPATH='' cd -- "$T" && pwd -P) || exit 2

  # ---- AC1 静态负向扫描：六脚本运行时拼接零 repo_root/agent-up 工作树回退 ----
  : > "$RC_D/static.hits"
  for rc_pat in 'repo_root}/agent-up' 'repo_root/agent-up' \
                'agent-up/scripts/json-validator.py' \
                'agent-up/references/schemas/ticket-record.schema.json' \
                'agent-up/references/schemas/dispatch-contract.schema.json'; do
    # shellcheck disable=SC2086  # 六脚本名清单按空白分词为多文件参数（刻意为 grep 提供六个文件）
    LC_ALL=C grep -F -n -- "$rc_pat" "$SCRIPT_DIR"/$RC_SCRIPTS >>"$RC_D/static.hits" 2>/dev/null || true
  done
  if [ -s "$RC_D/static.hits" ]; then
    bad 'AC1 六脚本运行时拼接零 repo_root/agent-up 工作树回退（静态负向扫描）' "$(head -n 5 "$RC_D/static.hits" | tr '\n' '|')"
  else
    ok 'AC1 六脚本运行时拼接零 repo_root/agent-up 工作树回退（静态负向扫描）'
  fi

  # ---- P1 本地闭包与包工作树副本内容不同时以本地为准（工作树副本坏件不被读取）----
  rc_build_repo "$RC_D/p1" || { bad '夹具 P1 构建' 'rc_build_repo 失败'; exit 1; }
  mkdir -p "$RC_D/p1/agent-up/scripts" "$RC_D/p1/agent-up/references/schemas"
  printf 'BROKEN worktree copy: must not be read\n' > "$RC_D/p1/agent-up/references/schemas/ticket-record.schema.json"
  printf 'BROKEN worktree copy: must not be read\n' > "$RC_D/p1/agent-up/scripts/json-validator.py"
  rc_write_body "$RC_D/p1/facts/requirements/tickets/30-rc-fixture.json" 30-rc-fixture
  RC_LEDGER='{"date": "2026-11-04", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "rc fixture", "evidence_ref": "facts/requirements/tickets/30-rc-fixture.json"}'
  sh "$RC_D/p1/rules/implementation/scripts/ticket-ops.sh" "$RC_D/p1" open --id 30-rc-fixture --complexity C1 --title 'RC fixture' --ledger-line "$RC_LEDGER" >"$RC_D/p1.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 0 ] && grep -q '"id": "30-rc-fixture"' "$RC_D/p1/facts/requirements/tickets/index.json" \
    && ! grep -q 'BROKEN worktree copy' "$RC_D/p1.log"; then
    ok '正例 P1 本地安装闭包与包工作树副本内容不同 → 以本地为准（工作树副本坏件不被读取，open exit 0）'
  else
    bad '正例 P1 本地安装闭包与包工作树副本内容不同 → 以本地为准（工作树副本坏件不被读取，open exit 0）' "exit=$RC_RC $(tail -n 2 "$RC_D/p1.log" | tr '\n' '|')"
  fi

  # ---- P2 contract-build 安装闭包渲染正例 ----
  rc_write_dispatch_ticket "$RC_D/p1/facts/requirements/tickets/269-rc-contract.json" "$RC_D/p1/rules/implementation/references/schemas/dispatch-contract.schema.json"
  sh "$RC_D/p1/rules/implementation/scripts/contract-build.sh" implementation 269 "$RC_D/p1" >"$RC_D/cb.out" 2>"$RC_D/cb.err"
  RC_RC=$?
  RC_NKEYS=$(grep -c '^{{[A-Z_]*}}$' "$RC_D/cb.out" 2>/dev/null || true)
  if [ "$RC_RC" -eq 0 ] && [ "$RC_NKEYS" = '16' ] && grep -q '{{TICKET_ID}}' "$RC_D/cb.out"; then
    ok '正例 P2 contract-build 安装布局邻接闭包渲染 → exit 0 且 16 字段占位齐备（无工作树回退）'
  else
    bad '正例 P2 contract-build 安装布局邻接闭包渲染 → exit 0 且 16 字段占位齐备（无工作树回退）' "exit=$RC_RC keys=$RC_NKEYS $(tail -n 2 "$RC_D/cb.err" | tr '\n' '|')"
  fi

  # ---- P3 ledger-append 安装闭包引擎门正例（--check 零写入）----
  RC_LBEFORE=$(cksum "$RC_D/p1/facts/project/changes.jsonl")
  sh "$RC_D/p1/rules/implementation/scripts/ledger-append.sh" "$RC_D/p1" --check --ledger-line '{"date": "2026-11-04", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$RC_D/la.log" 2>&1
  RC_RC=$?
  RC_LAFTER=$(cksum "$RC_D/p1/facts/project/changes.jsonl")
  if [ "$RC_RC" -eq 0 ] && [ "$RC_LBEFORE" = "$RC_LAFTER" ] && grep -q 'CHECK: PASS' "$RC_D/la.log"; then
    ok '正例 P3 ledger-append 安装闭包引擎门 → --check exit 0 且账本逐字节零变化'
  else
    bad '正例 P3 ledger-append 安装闭包引擎门 → --check exit 0 且账本逐字节零变化' "exit=$RC_RC $(tail -n 1 "$RC_D/la.log")"
  fi

  # ---- P4 ticket-run 安装闭包引擎解析正例（进入票定位而非闭包缺失）----
  sh "$RC_D/p1/rules/implementation/scripts/ticket-run.sh" 99 next "$RC_D/p1" >"$RC_D/tr.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 1 ] && grep -q '票号段 99 无命中' "$RC_D/tr.log" && ! grep -q '唯一 JSON 引擎缺失' "$RC_D/tr.log"; then
    ok '正例 P4 ticket-run 安装闭包引擎解析 → 进入票定位（引擎缺失报文零命中，不读工作树回退）'
  else
    bad '正例 P4 ticket-run 安装闭包引擎解析 → 进入票定位（引擎缺失报文零命中，不读工作树回退）' "exit=$RC_RC $(tail -n 2 "$RC_D/tr.log" | tr '\n' '|')"
  fi

  # ---- P5 run-record stats 安装闭包引擎正例 ----
  sh "$RC_D/p1/rules/implementation/scripts/run-record.sh" "$RC_D/p1" stats >"$RC_D/rr.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 0 ] && grep -q 'stats: 无运行记录' "$RC_D/rr.log"; then
    ok '正例 P5 run-record stats 安装闭包引擎 → exit 0 且不依赖包工作树副本'
  else
    bad '正例 P5 run-record stats 安装闭包引擎 → exit 0 且不依赖包工作树副本' "exit=$RC_RC $(tail -n 2 "$RC_D/rr.log" | tr '\n' '|')"
  fi

  # ---- N1 ticket-ops 引擎闭包缺失 → fail-closed 零写入 ----
  rc_build_repo "$RC_D/n1" || { bad '夹具 N1 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n1/rules/implementation/scripts/json-validator.py"
  rc_write_body "$RC_D/n1/facts/requirements/tickets/30-rc-fixture.json" 30-rc-fixture
  RC_S1=$(rc_state "$RC_D/n1")
  sh "$RC_D/n1/rules/implementation/scripts/ticket-ops.sh" "$RC_D/n1" open --id 30-rc-fixture --complexity C1 --title 'RC neg' --ledger-line "$RC_LEDGER" >"$RC_D/n1.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 1 ] && [ "$RC_S1" = "$(rc_state "$RC_D/n1")" ]; then
    rc_assert_fail_closed '负例 N1 ticket-ops 引擎闭包缺失 → exit 1 零写入且报文含缺失绝对路径与升级/修补入口' "$RC_D/n1.log" "$RC_D/n1/rules/implementation/scripts/json-validator.py"
  else
    bad '负例 N1 ticket-ops 引擎闭包缺失 → exit 1 零写入且报文含缺失绝对路径与升级/修补入口' "exit=$RC_RC 四载体指纹变化或 exit 非 1"
  fi

  # ---- N2 ticket-ops 本地 schema 缺失、包工作树副本在场 → 不回退，fail-closed 零写入 ----
  rc_build_repo "$RC_D/n2" || { bad '夹具 N2 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n2/rules/implementation/references/schemas/ticket-record.schema.json"
  mkdir -p "$RC_D/n2/agent-up/scripts" "$RC_D/n2/agent-up/references/schemas"
  cp "$PKG_ROOT/references/schemas/ticket-record.schema.json" "$RC_D/n2/agent-up/references/schemas/ticket-record.schema.json"
  cp "$SCRIPT_DIR/json-validator.py" "$RC_D/n2/agent-up/scripts/json-validator.py"
  rc_write_body "$RC_D/n2/facts/requirements/tickets/30-rc-fixture.json" 30-rc-fixture
  RC_S2=$(rc_state "$RC_D/n2")
  sh "$RC_D/n2/rules/implementation/scripts/ticket-ops.sh" "$RC_D/n2" open --id 30-rc-fixture --complexity C1 --title 'RC neg' --ledger-line "$RC_LEDGER" >"$RC_D/n2.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 1 ] && [ "$RC_S2" = "$(rc_state "$RC_D/n2")" ] && ! grep -q '30-rc-fixture' "$RC_D/n2/facts/requirements/tickets/index.json"; then
    rc_assert_fail_closed '负例 N2 ticket-ops 本地 schema 缺失且包工作树副本在场 → 不回退，fail-closed 零写入（报文指本地缺失绝对路径）' "$RC_D/n2.log" "$RC_P/rc/n2/rules/implementation/references/schemas/ticket-record.schema.json"
  else
    bad '负例 N2 ticket-ops 本地 schema 缺失且包工作树副本在场 → 不回退，fail-closed 零写入（报文指本地缺失绝对路径）' "exit=$RC_RC 四载体指纹变化或 exit 非 1"
  fi

  # ---- N3 contract-build 键集权威闭包缺失 → exit 2 零 stdout ----
  rc_build_repo "$RC_D/n3" || { bad '夹具 N3 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n3/rules/implementation/references/schemas/dispatch-contract.schema.json"
  rc_write_dispatch_ticket "$RC_D/n3/facts/requirements/tickets/269-rc-contract.json" "$PKG_ROOT/references/schemas/dispatch-contract.schema.json"
  sh "$RC_D/n3/rules/implementation/scripts/contract-build.sh" implementation 269 "$RC_D/n3" >"$RC_D/n3.out" 2>"$RC_D/n3.log"
  RC_RC=$?
  if [ "$RC_RC" -eq 2 ] && [ ! -s "$RC_D/n3.out" ]; then
    rc_assert_fail_closed '负例 N3 contract-build 键集权威闭包缺失 → exit 2 零 stdout 且报文含缺失绝对路径与升级/修补入口' "$RC_D/n3.log" "$RC_P/rc/n3/rules/implementation/references/schemas/dispatch-contract.schema.json"
  else
    bad '负例 N3 contract-build 键集权威闭包缺失 → exit 2 零 stdout 且报文含缺失绝对路径与升级/修补入口' "exit=$RC_RC stdout=$(wc -c < "$RC_D/n3.out" | tr -d ' ') 字节"
  fi

  # ---- N4 ledger-append 引擎闭包缺失 → exit 1 零写入 ----
  rc_build_repo "$RC_D/n4" || { bad '夹具 N4 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n4/rules/implementation/scripts/json-validator.py"
  RC_LS4=$(cksum "$RC_D/n4/facts/project/changes.jsonl")
  sh "$RC_D/n4/rules/implementation/scripts/ledger-append.sh" "$RC_D/n4" --ledger-line '{"date": "2026-11-04", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$RC_D/n4.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 1 ] && [ "$RC_LS4" = "$(cksum "$RC_D/n4/facts/project/changes.jsonl")" ]; then
    rc_assert_fail_closed '负例 N4 ledger-append 引擎闭包缺失 → exit 1 零写入且报文含缺失绝对路径与升级/修补入口' "$RC_D/n4.log" "$RC_D/n4/rules/implementation/scripts/json-validator.py"
  else
    bad '负例 N4 ledger-append 引擎闭包缺失 → exit 1 零写入且报文含缺失绝对路径与升级/修补入口' "exit=$RC_RC 账本字节或 exit 不符"
  fi

  # ---- N5 ticket-run 引擎闭包缺失 → exit 2 fail-closed ----
  rc_build_repo "$RC_D/n5" || { bad '夹具 N5 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n5/rules/implementation/scripts/json-validator.py"
  RC_S5=$(rc_state "$RC_D/n5")
  sh "$RC_D/n5/rules/implementation/scripts/ticket-run.sh" 20 next "$RC_D/n5" >"$RC_D/n5.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 2 ] && [ "$RC_S5" = "$(rc_state "$RC_D/n5")" ]; then
    rc_assert_fail_closed '负例 N5 ticket-run 引擎闭包缺失 → exit 2 零写入且报文含缺失绝对路径与升级/修补入口' "$RC_D/n5.log" "$RC_P/rc/n5/rules/implementation/scripts/json-validator.py"
  else
    bad '负例 N5 ticket-run 引擎闭包缺失 → exit 2 零写入且报文含缺失绝对路径与升级/修补入口' "exit=$RC_RC 四载体指纹变化或 exit 非 2"
  fi

  # ---- N6 run-record seal 引擎闭包缺失 → exit 2 且 record 零改写 ----
  rc_build_repo "$RC_D/n6" || { bad '夹具 N6 构建' 'rc_build_repo 失败'; exit 1; }
  rm "$RC_D/n6/rules/implementation/scripts/json-validator.py"
  printf '{"seed": "runtime-closure seal fixture"}\n' > "$RC_D/n6/record.json"
  RC_RS6=$(cksum "$RC_D/n6/record.json")
  sh "$RC_D/n6/rules/implementation/scripts/run-record.sh" "$RC_D/n6" seal --file "$RC_D/n6/record.json" >"$RC_D/n6.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 2 ] && [ "$RC_RS6" = "$(cksum "$RC_D/n6/record.json")" ]; then
    rc_assert_fail_closed '负例 N6 run-record seal 引擎闭包缺失 → exit 2 且 record 零改写（报文含缺失绝对路径与升级/修补入口）' "$RC_D/n6.log" "$RC_D/n6/rules/implementation/scripts/json-validator.py"
  else
    bad '负例 N6 run-record seal 引擎闭包缺失 → exit 2 且 record 零改写（报文含缺失绝对路径与升级/修补入口）' "exit=$RC_RC record 字节或 exit 不符"
  fi

  # ---- N7 test-checkpoint-recovery 邻接 references/ 缺失 → fail-closed ----
  RC_N7="$RC_D/n7"
  mkdir -p "$RC_N7/scripts"
  for rc_f in test-checkpoint-recovery.sh workflow-executor.sh json-validator.py common-helpers.sh; do
    cp "$SCRIPT_DIR/$rc_f" "$RC_N7/scripts/$rc_f" || exit 2
  done
  sh "$RC_N7/scripts/test-checkpoint-recovery.sh" >"$RC_D/n7.log" 2>&1
  RC_RC=$?
  if [ "$RC_RC" -eq 1 ] && [ -s "$RC_D/n7.log" ]; then
    rc_assert_fail_closed '负例 N7 test-checkpoint-recovery 邻接 references/ 缺失 → exit 1 且报文含缺失绝对路径与升级/修补入口' "$RC_D/n7.log" "$RC_N7/scripts/../references/schemas"
  else
    bad '负例 N7 test-checkpoint-recovery 邻接 references/ 缺失 → exit 1 且报文含缺失绝对路径与升级/修补入口' "exit=$RC_RC $(tail -n 2 "$RC_D/n7.log" | tr '\n' '|')"
  fi

  suite_summary 'runtime-closure'
}
