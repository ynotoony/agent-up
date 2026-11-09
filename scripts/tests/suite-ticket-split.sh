#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-split "$@"
  exit $?
fi
# Input: 同目录 ticket-split.sh 与其安装闭包运行依赖（ticket-ops／record-commit／record-store／
#        ledger-append／generate-progress／common-helpers／ticket-gates／json-validator.py）与
#        ticket-record schema；夹具在 mktemp 临时目录内 git init（记录面种子＋Git 基线提交）。
# Output: 逐项 PASS/FAIL 行与计数汇总；夹具全部 mktemp 并 trap 清理，真实仓库零写入。
# Pos: 拆票批量入口回归（票 293 D1）：批量正例（一次开票 N 张＋一次记录提交、提交文件集
#      恰为记录面路径、派生字段来自票本体）＋幂等重跑（零新提交、零重复账本行、投影时间戳
#      归一）＋部分失败负例（零提交并指名失败票、已成功开票的写入保留）＋提交失败负例
#      （零提交、工作区保留可重试）＋批量表格式 fail-closed 负例；单票 open 行为不变由
#      ticket-ops 套件常驻覆盖（本件不复制其断言）。
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

suite_ticket_split() {
  CUR_SUITE='ticket-split'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/tsplit
  mkdir -p "$D"
  TS="$SCRIPT_DIR/ticket-split.sh"
  SCHEMAS="$SCRIPT_DIR/../references/schemas"
  [ -r "$TS" ] || { bad 'ticket-split.sh 在场' "缺件: $TS"; suite_summary 'ticket-split'; return 0; }
  [ -r "$SCHEMAS/ticket-record.schema.json" ] || {
    bad 'ticket-record.schema.json 在场（open 本体校验权威）' "缺件: $SCHEMAS/ticket-record.schema.json"
    suite_summary 'ticket-split'
    return 0
  }
  TS_SRCS='ticket-split.sh ticket-ops.sh record-commit.sh record-store.sh ledger-append.sh ledger-row-families.sh common-helpers.sh evidence-gate.sh record-lock.sh ticket-gates.sh'

  ts_body() {
    # $1=落盘路径 $2=票 id $3=complexity [$4=bad-profile：缺 profile_reason 的负例形态]
    if [ "${4:-}" = 'bad-profile' ]; then
      cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "$3",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（非空）",
  "priority_reason": "fixture 优先级理由（非空）",
  "user_stories": ["US1: 作为夹具维护者，我要批量开票正例，以便开票门有载体"]
}
EOF
    else
      cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "$3",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "profile_reason": {"D": "fixture D 维 reason", "B": "fixture B 维 reason", "I": "fixture I 维 reason", "U": "fixture U 维不适用 reason", "S": "fixture S 维不适用 reason", "M": "fixture M 维不适用 reason", "O": "fixture O 维不适用 reason"},
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（非空）",
  "priority_reason": "fixture 优先级理由（非空）",
  "user_stories": ["US1: 作为夹具维护者，我要批量开票正例，以便开票门有载体"],
  "dispatch": {
    "implementation": {"REPOSITORY_PATH": "fixture repo root", "TASK_DESCRIPTION": "fixture task", "GOAL": "fixture goal", "SCOPE_TREE": "fixture scope tree", "OUT_OF_SCOPE": "fixture out of scope", "CONTEXT_EVIDENCE": "fixture context", "CONSTRAINTS": "fixture constraints", "FORBIDDEN_CHANGES": "fixture forbidden", "ACCEPTANCE_CRITERIA": "fixture acceptance", "VERIFICATION_COMMANDS": "fixture verification", "DEPENDENCIES_BLOCKERS": "fixture deps", "RISKS": "fixture risks", "BUDGET_CHECKPOINTS": "80 calls", "ESTIMATED_TIME": "0.5d", "ACTUAL_TIME": "", "TICKET_ID": "$2"},
    "review": {"REVIEW_SCOPE": "fixture review scope", "IMPLEMENTATION_SUMMARY": "", "ACCEPTANCE_CRITERIA": "fixture acceptance", "DIFF_LOCATION": "fixture worktree", "REVIEW_DIMENSIONS": "fixture dimensions", "TICKET_ID": "$2"},
    "commit": {"REVIEW_PASS_CHECKPOINT": "", "FILE_WHITELIST": "fixture whitelist", "COMMIT_MESSAGE": "fixture message", "RECORD_FLIP_AUTHORIZATION": "fixture authorization", "SCOPE_CHECK_COMMAND": "fixture command", "TICKET_ID": "$2"}
  }
}
EOF
    fi
  }

  ts_seed() {
    # $1=夹具根：脚本闭包＋schema＋记录面种子（索引/票表 README/账本）＋Git 基线提交
    _ts_f=$1
    rm -rf "$_ts_f"
    mkdir -p "$_ts_f/rules/implementation/scripts" "$_ts_f/rules/implementation/references/schemas" "$_ts_f/facts/requirements/tickets" "$_ts_f/facts/project"
    for _ts_s in $TS_SRCS; do
      cp "$SCRIPT_DIR/$_ts_s" "$_ts_f/rules/implementation/scripts/" || return 1
    done
    # 拆分引擎按运行闭包整组复制（generate-progress→progress-readme.sh；json-validator→
    # jv_* 七模块；闭包登记单源＝test-helpers.sh test_runtime_closure，随生成器拆分自动随动）
    test_copy_closure "$SCRIPT_DIR" "$_ts_f/rules/implementation/scripts" generate-progress.sh json-validator.py common-helpers.sh ledger-append.sh || return 1
    cp "$SCHEMAS/ticket-record.schema.json" "$_ts_f/rules/implementation/references/schemas/" || return 1
    cat > "$_ts_f/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"}
  ]
}
EOF
    cat > "$_ts_f/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |
EOF
    cat > "$_ts_f/facts/project/changes.jsonl" <<'EOF'
{"date": "2026-09-19", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture seed", "evidence_ref": "facts/requirements/tickets/index.json"}
EOF
    git_repo "$_ts_f" || return 1
    git -C "$_ts_f" config user.email fixture@example.com
    git -C "$_ts_f" config user.name fixture
    git -C "$_ts_f" add -A || return 1
    git -C "$_ts_f" -c commit.gpgsign=false commit -qm seed || return 1
    return 0
  }

  ts_commit_count() { git -C "$1" rev-list --count HEAD; }
  ts_head_files() {
    git -C "$1" -c core.quotePath=false diff-tree --root --no-commit-id --name-only -r HEAD | LC_ALL=C sort
  }
  ts_state() {
    # 记录面四载体指纹（负例零写入断言用；progress 缺席记为占位）
    {
      cksum "$1/facts/requirements/tickets/index.json" "$1/facts/requirements/tickets/README.md" "$1/facts/project/changes.jsonl"
      if [ -f "$1/facts/requirements/tickets/progress-current.md" ]; then
        cksum "$1/facts/requirements/tickets/progress-current.md"
      else
        printf 'no-projection\n'
      fi
    } | cksum
  }
  ts_batch() {
    # $1=输出文件 $2=id1 $3=id2 [$4=id3]：每行「<id> <账本行 JSON>」
    _tb_out=$1
    shift
    : > "$_tb_out"
    for _ts_id in "$@"; do
      printf '%s {"date": "2026-11-09", "kind": "scope", "scope": "%s", "decision": "fixture batch open %s", "evidence_ref": "facts/requirements/tickets/%s.json"}\n' \
        "$_ts_id" "$_ts_id" "$_ts_id" "$_ts_id" >> "$_tb_out"
    done
  }
  ts_run() {
    # $1=夹具根 $2=批表 $3=输出日志；回显退出码
    _ts_rc=0
    sh "$1/rules/implementation/scripts/ticket-split.sh" "$1" --batch "$2" > "$3" 2>&1 || _ts_rc=$?
    printf '%s' "$_ts_rc"
  }

  # ---- P1：批量正例（两张票一次开票＋一次记录提交，提交文件集恰为记录面）----
  ts_seed "$D/p1" && {
    ts_body "$D/p1/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third C1
    ts_body "$D/p1/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth C2
    ts_batch "$D/p1.batch" 30-gamma-third 40-delta-fourth
    _p1_n0=$(ts_commit_count "$D/p1")
    _p1_rc=$(ts_run "$D/p1" "$D/p1.batch" "$D/p1.out")
    _p1_n1=$(ts_commit_count "$D/p1")
    _p1_files=$(ts_head_files "$D/p1")
    _p1_want=$(printf '%s\n' \
      facts/project/changes.jsonl \
      facts/requirements/tickets/30-gamma-third.json \
      facts/requirements/tickets/40-delta-fourth.json \
      facts/requirements/tickets/README.md \
      facts/requirements/tickets/index.json \
      facts/requirements/tickets/progress-current.md | LC_ALL=C sort)
    if [ "$_p1_rc" -eq 0 ] && [ "$_p1_n1" -eq $((_p1_n0 + 1)) ] && [ "$_p1_files" = "$_p1_want" ]; then
      ok '正例 P1 批量开票两张＋一次记录提交（exit 0、恰一个提交、提交文件集恰为记录面路径）'
    else
      bad '正例 P1 批量开票两张＋一次记录提交（exit 0、恰一个提交、提交文件集恰为记录面路径）' \
        "rc=$_p1_rc commits=${_p1_n0}→$_p1_n1 files=[$(printf '%s' "$_p1_files" | tr '\n' ',')]"
    fi
    _p1_subj=$(git -C "$D/p1" log -1 --format=%s)
    if printf '%s\n' "$_p1_subj" | LC_ALL=C grep -Eq '^chore\(records\): [0-9]{4}-[0-9]{2}-[0-9]{2} 拆票批量开票（票 30-gamma-third/40-delta-fourth）$'; then
      ok '正例 P1 提交说明按记录面规范生成（chore(records): <date> 拆票批量开票（票 <ids>））'
    else
      bad '正例 P1 提交说明按记录面规范生成（chore(records): <date> 拆票批量开票（票 <ids>））' "subject=$_p1_subj"
    fi
    if [ "$(sed -n '1p' "$D/p1/facts/project/changes.jsonl" | wc -l | tr -d ' ')" = '1' ] \
      && [ "$(tail -n 2 "$D/p1/facts/project/changes.jsonl" | grep -c '30-gamma-third|40-delta-fourth')" = '0' ] \
      && tail -n 2 "$D/p1/facts/project/changes.jsonl" | grep -q 'fixture batch open 30-gamma-third' \
      && tail -n 2 "$D/p1/facts/project/changes.jsonl" | grep -q 'fixture batch open 40-delta-fourth'; then
      ok '正例 P1 两张票的账本行各追加一次（键序/行原文与批表一致）'
    else
      bad '正例 P1 两张票的账本行各追加一次（键序/行原文与批表一致）' "ledger=$(cat "$D/p1/facts/project/changes.jsonl")"
    fi
    if grep -qF '"id": "30-gamma-third", "status": "ready"' "$D/p1/facts/requirements/tickets/index.json" \
      && grep -qF '"id": "40-delta-fourth", "status": "ready", "complexity": "C2"' "$D/p1/facts/requirements/tickets/index.json"; then
      ok '正例 P1 索引落两条 ready 条目且 complexity 自票本体派生（40→C2）'
    else
      bad '正例 P1 索引落两条 ready 条目且 complexity 自票本体派生（40→C2）' "index=$(cat "$D/p1/facts/requirements/tickets/index.json")"
    fi
    if grep -qF '30-gamma-third.json' "$D/p1/facts/requirements/tickets/README.md" \
      && grep -qF '40-delta-fourth.json' "$D/p1/facts/requirements/tickets/README.md"; then
      ok '正例 P1 票表生成块重算含两张新票'
    else
      bad '正例 P1 票表生成块重算含两张新票' '读 README 缺票行'
    fi
    if [ -f "$D/p1/facts/requirements/tickets/progress-current.md" ] \
      && grep -qF '30-gamma-third' "$D/p1/facts/requirements/tickets/progress-current.md" \
      && grep -qF '40-delta-fourth' "$D/p1/facts/requirements/tickets/progress-current.md"; then
      ok '正例 P1 现役状态投影再生含两张新票'
    else
      bad '正例 P1 现役状态投影再生含两张新票' '投影缺件或缺票行'
    fi
    if [ ! -e "$D/p1/.git/agent-up-record.lock" ]; then
      ok '正例 P1 记录层写锁无残留'
    else
      bad '正例 P1 记录层写锁无残留' '锁目录残留'
    fi

    # ---- P2：幂等重跑（零新提交、零重复账本行、投影时间戳归一、工作区干净）----
    _p2_led=$(wc -l < "$D/p1/facts/project/changes.jsonl" | tr -d ' ')
    _p2_rc=$(ts_run "$D/p1" "$D/p1.batch" "$D/p1.out2")
    _p2_n=$(ts_commit_count "$D/p1")
    _p2_led2=$(wc -l < "$D/p1/facts/project/changes.jsonl" | tr -d ' ')
    if [ "$_p2_rc" -eq 0 ] && [ "$_p2_n" -eq "$_p1_n1" ] && [ "$_p2_led2" = "$_p2_led" ] \
      && grep -q '无提交可创建' "$D/p1.out2"; then
      ok '正例 P2 幂等重跑（exit 0、零新提交、零重复账本行、显式零空提交）'
    else
      bad '正例 P2 幂等重跑（exit 0、零新提交、零重复账本行、显式零空提交）' \
        "rc=$_p2_rc commits=${_p1_n1}→$_p2_n ledger=${_p2_led}→$_p2_led2"
    fi
    if [ -z "$(git -C "$D/p1" status --porcelain)" ]; then
      ok '正例 P2 幂等重跑后工作区干净（投影 generated_at 差异已归一，零空提交）'
    else
      bad '正例 P2 幂等重跑后工作区干净（投影 generated_at 差异已归一，零空提交）' \
        "status=$(git -C "$D/p1" status --porcelain | tr '\n' ',')"
    fi
  }

  # ---- P3：提交失败负例（预暂存过期索引 → 部分暂存拒绝；零提交、工作区保留可重试）----
  ts_seed "$D/p3" && {
    ts_body "$D/p3/facts/requirements/tickets/80-theta-eighth.json" 80-theta-eighth C1
    ts_body "$D/p3/facts/requirements/tickets/90-iota-ninth.json" 90-iota-ninth C1
    ts_batch "$D/p3.batch" 80-theta-eighth 90-iota-ninth
    # 合法 JSON 改值后暂存：open 会重写索引，使暂存版与工作区不一致（部分暂存）
    sed 's/2026-09-19T10:00/2026-09-19T10:01/' "$D/p3/facts/requirements/tickets/index.json" > "$D/p3/idx.tmp" \
      && mv "$D/p3/idx.tmp" "$D/p3/facts/requirements/tickets/index.json"
    git -C "$D/p3" add facts/requirements/tickets/index.json
    _p3_n0=$(ts_commit_count "$D/p3")
    _p3_rc=$(ts_run "$D/p3" "$D/p3.batch" "$D/p3.out")
    _p3_n1=$(ts_commit_count "$D/p3")
    if [ "$_p3_rc" -ne 0 ] && [ "$_p3_n1" -eq "$_p3_n0" ] \
      && grep -q '记录提交未创建' "$D/p3.out"; then
      ok '负例 P3 提交失败（部分暂存）→ exit 非零、零提交、如实报告记录提交未创建'
    else
      bad '负例 P3 提交失败（部分暂存）→ exit 非零、零提交、如实报告记录提交未创建' \
        "rc=$_p3_rc commits=${_p3_n0}→$_p3_n1 tail=$(tail -n 2 "$D/p3.out" | tr '\n' '|')"
    fi
    if grep -qF '"id": "80-theta-eighth"' "$D/p3/facts/requirements/tickets/index.json" \
      && grep -qF '"id": "90-iota-ninth"' "$D/p3/facts/requirements/tickets/index.json"; then
      ok '负例 P3 工作区保留（开票写入未回滚，可修好后重跑收敛）'
    else
      bad '负例 P3 工作区保留（开票写入未回滚，可修好后重跑收敛）' '索引缺新票条目'
    fi
  }

  # ---- P4：部分失败负例（第二张本体不合 schema → 零提交并指名失败票）----
  ts_seed "$D/p4" && {
    ts_body "$D/p4/facts/requirements/tickets/60-zeta-sixth.json" 60-zeta-sixth C1
    ts_body "$D/p4/facts/requirements/tickets/70-eta-seventh.json" 70-eta-seventh C1 bad-profile
    ts_batch "$D/p4.batch" 60-zeta-sixth 70-eta-seventh
    _p4_n0=$(ts_commit_count "$D/p4")
    _p4_rc=$(ts_run "$D/p4" "$D/p4.batch" "$D/p4.out")
    _p4_n1=$(ts_commit_count "$D/p4")
    if [ "$_p4_rc" -ne 0 ] && [ "$_p4_n1" -eq "$_p4_n0" ] \
      && grep -q '失败票: 70-eta-seventh' "$D/p4.out" \
      && ! grep -q '^ticket-split: 记录提交门:' "$D/p4.out"; then
      ok '负例 P4 部分失败（第二张 open 失败）→ exit 非零、零提交、指名失败票、未进入提交段'
    else
      bad '负例 P4 部分失败（第二张 open 失败）→ exit 非零、零提交、指名失败票、未进入提交段' \
        "rc=$_p4_rc commits=${_p4_n0}→$_p4_n1 tail=$(tail -n 3 "$D/p4.out" | tr '\n' '|')"
    fi
    if grep -qF '"id": "60-zeta-sixth"' "$D/p4/facts/requirements/tickets/index.json" \
      && ! grep -qF '"id": "70-eta-seventh"' "$D/p4/facts/requirements/tickets/index.json"; then
      ok '负例 P4 已成功开票的第一张写入保留、失败票零落索引（重跑幂等收敛语义）'
    else
      bad '负例 P4 已成功开票的第一张写入保留、失败票零落索引（重跑幂等收敛语义）' '索引状态不符'
    fi
  }

  # ---- P5：批量表格式与用法 fail-closed 负例（零写入／零提交）----
  ts_seed "$D/p5" && {
    _p5_n0=$(ts_commit_count "$D/p5")
    _p5_st=$(ts_state "$D/p5")
    printf '30-x\n' > "$D/p5-bad1.txt"
    printf '3-bad {"date": "2026-11-09", "kind": "scope", "scope": "3-bad", "decision": "x", "evidence_ref": "y"}\n' > "$D/p5-bad2.txt"
    printf '30-a {"date": "2026-11-09", "kind": "scope", "scope": "30-a", "decision": "x", "evidence_ref": "y"}\n30-a {"date": "2026-11-09", "kind": "scope", "scope": "30-a", "decision": "z", "evidence_ref": "y"}\n' > "$D/p5-bad3.txt"
    printf '30-a {"date": "2026-11-09", "kind": "scope", "scope": "30-a", "decision": "x", "evidence_ref": "y"}\n30-b {"date": "2026-11-09", "kind": "scope", "scope": "30-b", "decision": "z", "evidence_ref": "y"}\n' > "$D/p5-bad4.txt"
    printf '# 仅注释与空行\n\n' > "$D/p5-bad5.txt"
    _p5_ok=1
    _p5_seen=''
    for _p5_c in 1 2 3 4 5; do
      _p5_rc=$(ts_run "$D/p5" "$D/p5-bad$_p5_c.txt" "$D/p5-bad$_p5_c.out")
      _p5_seen="$_p5_seen $_p5_rc"
      if [ "$_p5_rc" -ne 1 ]; then
        _p5_ok=0
      fi
    done
    if [ "$_p5_ok" -eq 1 ] \
      && [ "$(ts_commit_count "$D/p5")" -eq "$_p5_n0" ] \
      && [ "$(ts_state "$D/p5")" = "$_p5_st" ]; then
      ok '负例 P5 批表格式五形态（缺账本行／id 形态／批内重复／批内 NN 撞号／零有效行）→ 均 exit 1 零写入零提交'
    else
      bad '负例 P5 批表格式五形态（缺账本行／id 形态／批内重复／批内 NN 撞号／零有效行）→ 均 exit 1 零写入零提交' \
        "rcs=$_p5_seen commits=${_p5_n0}→$(ts_commit_count "$D/p5")"
    fi
    _p5_missing_rc=$(ts_run "$D/p5" "$D/p5-nonexistent.txt" "$D/p5-miss.out")
    _p5_nobatch_rc=0
    sh "$D/p5/rules/implementation/scripts/ticket-split.sh" "$D/p5" > "$D/p5-nobatch.out" 2>&1 || _p5_nobatch_rc=$?
    _p5_help_rc=0
    sh "$D/p5/rules/implementation/scripts/ticket-split.sh" --help > "$D/p5-help.out" 2>&1 || _p5_help_rc=$?
    if [ "$_p5_missing_rc" -eq 2 ] && [ "$_p5_nobatch_rc" -eq 2 ] && [ "$_p5_help_rc" -eq 0 ] \
      && grep -q '用法: sh ticket-split.sh' "$D/p5-help.out"; then
      ok '负例 P5 用法面（批表缺失 exit 2／缺 --batch exit 2／--help exit 0 且打印用法）'
    else
      bad '负例 P5 用法面（批表缺失 exit 2／缺 --batch exit 2／--help exit 0 且打印用法）' \
        "missing=$_p5_missing_rc nobatch=$_p5_nobatch_rc help=$_p5_help_rc"
    fi
  }

  suite_summary 'ticket-split'
}
