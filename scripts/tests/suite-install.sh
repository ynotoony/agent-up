#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite install "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: install（票 145 场景沉淀：install.sh 非执行式规则表解析正负例——合法表
# 安装全链＋幂等跳过＋规则表缺失/损坏 fail-closed＋恶意输入四形态 rc=2 零写入；
# 本票新增安装后运行时依赖闭包：minimal target fixture 真实执行已安装
# ticket-grade/ticket-ops 并读取已安装 schema/profile，missing-validator 与
# missing-data 负例真走失败路径，包副本删依赖由安装预检与 check-package 双层指名）
# ============================================================

inst_build_pkg() {
  # $1=夹具包根：install.sh＋install-policy.rules＋快道/票务两门控全部登记源（脚本件）
  # ＋references/ 数据件源（ticket-record.schema.json／complexity-profile.md，ip_data
  # 行的解析基準＝脚本目录上一级，夹具布局与包内 agent-up/ 前缀剥离后同构）
  P=$1
  rm -rf "$P"; mkdir -p "$P/scripts" "$P/references/schemas" "$P/references/protocol"
  cp "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/install-policy.rules" "$P/scripts/"
  for f in check-gates.sh lane-commit.sh worktree-add.sh upgrade-check.sh generate-progress.sh ticket-ops.sh run-record.sh ticket-grade.sh absorption-trigger.sh health-summary.sh common-helpers.sh json-helpers.sh json-validator.py; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
      printf 'test-record-layer: 夹具依赖缺失: %s/%s（安装闭包登记源）\n' "$SCRIPT_DIR" "$f" >&2
      exit 2
    fi
    cp "$SCRIPT_DIR/$f" "$P/scripts/$f"
  done
  for f in references/schemas/ticket-record.schema.json references/protocol/complexity-profile.md; do
    if [ ! -f "$SCRIPT_DIR/../$f" ]; then
      printf 'test-record-layer: 夹具依赖缺失: %s/../%s（安装闭包 ip_data 数据件源）\n' "$SCRIPT_DIR" "$f" >&2
      exit 2
    fi
    cp "$SCRIPT_DIR/../$f" "$P/$f"
  done
}

inst_build_target_tree() {
  # $1=目标项目根：minimal 治理树三载体（open 公共段预检与投影再生的落地面；
  # 形态与 ticket-ops 套件夹具同构，预期值独立重建）
  F=$1
  mkdir -p "$F/facts/requirements/tickets" "$F/facts/project"
  cat > "$F/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-seed", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-21T10:00"}
  ]
}
EOF
  cat > "$F/facts/requirements/tickets/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `10-alpha-seed.json` | 任务票 10；`done`（2026-10-21 开票） | Alpha seed |
EOF
  printf '%s\n' '{"date": "2026-10-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture seed", "evidence_ref": "facts/requirements/tickets/index.json"}' > "$F/facts/project/changes.jsonl"
}

suite_install() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='install'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/inst
  mkdir -p "$D"
  INST="$SCRIPT_DIR/install.sh"

  # 栅栏环境跳过（R-DP-036：worktree-add.sh 按 delivery.rules dp_mainonly 排除 main-only 件，
  # install.sh 在 worktree 内物理不在场；口径同 check-package 检查 8/9 的 worktree SKIP）：
  # 被测件不在场则整套显式 SKIP 不计数——覆盖面归主检出全量，不宣称不存在的验证。
  if [ ! -f "$INST" ]; then
    printf 'SKIP  [install] 被测件 install.sh 不在场（worktree 栅栏排除 main-only 件）——整套跳过，覆盖归主检出\n'
    suite_summary 'install'
    return 0
  fi

  # 正例 P1：合法表双门控安装 → exit 0 目标恰落 15 件（脚本 13＋数据 2；stdout 摘要行计数）
  # install.sh 的 R-DP-036 worktree 自拒按调用 cwd 判定（非 Git 语境放行）：夹具安装
  # 从 harness 的 mktemp 非 Git 目录调用，避免 harness 在 worktree 内跑时栅栏误拦夹具。
  inst_build_pkg "$D/pkg1"; mkdir -p "$D/proj1"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p1.out" 2>&1
  rc=$?
  p1_n=$(grep -c '^install: OK:' "$D/p1.out")
  if [ "$rc" -eq 0 ] && [ "$p1_n" -eq 15 ] && grep -q '^install: DONE: 复制 15 件（脚本 13＋数据 2）、幂等跳过 0 件' "$D/p1.out" \
    && [ -f "$D/proj1/rules/implementation/scripts/check-gates.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/ticket-ops.sh" ]; then
    ok '正例 P1 合法表双门控安装 → exit 0 复制 15 件（脚本 13＋数据 2）落位'
  else
    bad '正例 P1 合法表双门控安装 → exit 0 复制 15 件（脚本 13＋数据 2）落位' "exit=$rc ok_lines=$p1_n"
  fi

  # 正例 P2：幂等重跑 → 逐件 SKIP exit 0 零新写入（文件集与首跑逐一相等）
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.before"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p2.out" 2>&1
  rc=$?
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.after"
  if [ "$rc" -eq 0 ] && grep -q '^install: DONE: 复制 0 件（脚本 0＋数据 0）、幂等跳过 15 件' "$D/p2.out" \
    && cmp -s "$D/p2.tree.before" "$D/p2.tree.after"; then
    ok '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 15 件（文件集零变化）'
  else
    bad '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 15 件（文件集零变化）' "exit=$rc"
  fi

  # 负例 N1：规则表缺失 → exit 2 零写入
  inst_build_pkg "$D/pkg2"; rm -f "$D/pkg2/scripts/install-policy.rules"; mkdir -p "$D/proj2"
  sh "$D/pkg2/scripts/install.sh" --target "$D/proj2" --fast-lane >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -d "$D/proj2/rules" ]; then
    ok '负例 N1 规则表缺失 → exit 2 零写入'
  else
    bad '负例 N1 规则表缺失 → exit 2 零写入' "exit=$rc"
  fi

  # 负例 N2：结构破坏（ip_file 参数数不合预期）→ exit 2 零写入（既有口径回归钉死）
  inst_build_pkg "$D/pkg3"
  printf "ip_file agent-up/scripts/check-gates.sh Conditional\n" >> "$D/pkg3/scripts/install-policy.rules"
  mkdir -p "$D/proj3"
  sh "$D/pkg3/scripts/install.sh" --target "$D/proj3" --fast-lane >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -d "$D/proj3/rules" ]; then
    ok '负例 N2 ip_file 参数数不足 → exit 2 零写入（结构校验 fail-closed）'
  else
    bad '负例 N2 ip_file 参数数不足 → exit 2 零写入（结构校验 fail-closed）' "exit=$rc"
  fi

  # 票 145 恶意输入负例 N3～N6：规则表注入恶意行 → 非执行式解析期 exit 2 零写入，
  # 探针文件断言承载零执行；目标仓 canary 文件断言零非预期写入。
  for ii_i in 1 2 3 4; do
    inst_build_pkg "$D/pkgm$ii_i"
    mkdir -p "$D/projm$ii_i"; printf 'canary\n' > "$D/projm$ii_i/canary"
    printf "ip_gate fast-lane --fast-lane 'fixture gate'\nip_file agent-up/scripts/check-gates.sh Conditional fast-lane 'fixture file'\n" > "$D/pkgm$ii_i/scripts/install-policy.rules"
    case $ii_i in
      1) printf "ip_file 'x\$(touch /tmp/tri145i1)x' Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N3 规则表命令替换注入（引号内美元括号）→ exit 2 零写入'; ii_probe=/tmp/tri145i1 ;;
      2) printf "ip_file 'x\`touch /tmp/tri145i2\`x' Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N4 规则表反引号注入 → exit 2 零写入'; ii_probe=/tmp/tri145i2 ;;
      3) printf "ip_file agent-up/scripts/check-gates.sh > /tmp/tri145i3 Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N5 规则表引号外重定向注入 → exit 2 零写入'; ii_probe=/tmp/tri145i3 ;;
      4) printf "evil_cmd 'rm' '-rf' '/' 'x' 'y'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N6 规则表未知指令注入 → exit 2 零写入'; ii_probe='' ;;
    esac
    sh "$D/pkgm$ii_i/scripts/install.sh" --target "$D/projm$ii_i" --fast-lane >/dev/null 2>"$D/pkgm$ii_i/err"
    rc=$?
    if [ "$rc" -eq 2 ] && [ ! -d "$D/projm$ii_i/rules" ] && [ "$(cat "$D/projm$ii_i/canary")" = 'canary' ] \
      && { [ -z "$ii_probe" ] || [ ! -e "$ii_probe" ]; } \
      && grep -q '非执行式解析不合预期' "$D/pkgm$ii_i/err"; then
      ok "$ii_desc"
    else
      bad "$ii_desc" "exit=$rc stderr=$(head -n 1 "$D/pkgm$ii_i/err")"
    fi
  done
  rm -f /tmp/tri145i1 /tmp/tri145i2 /tmp/tri145i3

  # ============================================================
  # 安装后运行时依赖闭包（minimal target fixture）：真实包件安装到干净临时目标后真实
  # 执行已安装 ticket-grade／ticket-ops 并读取已安装 schema/profile；missing-validator
  # 与 missing-data 负例真走失败路径（运行时消费点与安装预检两层）；包副本删任一依赖
  # 由 check-package 明确失败指名缺失路径（包闭合负例）。
  # ============================================================

  # 闭包正例 R1：--ticket-ops 安装 → 入口/validator/helpers 脚本件与 schema/profile
  # 数据件全部落位（数据件与包基线 cmp 字节一致）。
  inst_build_pkg "$D/pkgr"; mkdir -p "$D/projr"
  ( cd "$D" && sh "$INST" --target "$D/projr" --ticket-ops ) >"$D/r1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ -f "$D/projr/rules/implementation/scripts/ticket-grade.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/ticket-ops.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/json-validator.py" ] \
    && [ -f "$D/projr/rules/implementation/scripts/common-helpers.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/json-helpers.sh" ] \
    && cmp -s "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$D/projr/rules/implementation/references/schemas/ticket-record.schema.json" \
    && cmp -s "$SCRIPT_DIR/../references/protocol/complexity-profile.md" "$D/projr/rules/implementation/references/protocol/complexity-profile.md"; then
    ok '闭包正例 R1 minimal target 安装 → exit 0 且入口/validator/helpers 脚本件与 schema/profile 数据件全落位（数据件与包基线字节一致）'
  else
    bad '闭包正例 R1 minimal target 安装 → exit 0 且入口/validator/helpers 脚本件与 schema/profile 数据件全落位（数据件与包基线字节一致）' "exit=$rc out=$(tail -n 1 "$D/r1.out")"
  fi

  # 闭包正例 R2：已安装 ticket-grade 真实执行 → exit 0 出定级建议（同目录 validator
  # 定位与邻接 references/ profile 路径在安装布局生效）。
  mkdir -p "$D/tix"
  cat > "$D/tix/40-grade-fixture.json" <<'EOF'
{
  "id": "40-grade-fixture",
  "kind": "task",
  "title": "fixture 记录类票（install 套件 grade 运行正例）",
  "created_at": "2026-10-21",
  "complexity": "C0",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（非空）",
  "priority_reason": "fixture 优先级理由（非空）"
}
EOF
  ( cd "$D/projr" && sh "$D/projr/rules/implementation/scripts/ticket-grade.sh" "$D/tix/40-grade-fixture.json" ) >"$D/r2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '=== 票 40-grade-fixture ===' "$D/r2.out" && grep -q 'C0' "$D/r2.out"; then
    ok '闭包正例 R2 已安装 ticket-grade 真实执行 → exit 0 出定级建议表（安装布局 validator/profile 定位生效）'
  else
    bad '闭包正例 R2 已安装 ticket-grade 真实执行 → exit 0 出定级建议表（安装布局 validator/profile 定位生效）' "exit=$rc out=$(tail -n 1 "$D/r2.out")"
  fi

  # 闭包正例 R3：已安装 ticket-ops open 真实执行 → exit 0 索引落条目且投影再生
  # （安装布局 schema/validator 定位与同目录 generate-progress 依赖链全链生效）。
  inst_build_pkg "$D/pkgt"; mkdir -p "$D/projt"
  ( cd "$D" && sh "$INST" --target "$D/projt" --ticket-ops ) >/dev/null 2>&1
  inst_build_target_tree "$D/projt"
  sed 's/40-grade-fixture/50-open-fixture/g' "$D/tix/40-grade-fixture.json" > "$D/projt/facts/requirements/tickets/50-open-fixture.json"
  ( cd "$D/projt" && sh "$D/projt/rules/implementation/scripts/ticket-ops.sh" "$D/projt" open --id 50-open-fixture --complexity C1 --title 'fixture open 票' --ledger-line '{"date": "2026-10-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open", "evidence_ref": "facts/requirements/tickets/50-open-fixture.json"}' ) >"$D/r3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "50-open-fixture"' "$D/projt/facts/requirements/tickets/index.json" \
    && [ -f "$D/projt/facts/requirements/tickets/progress-current.md" ] \
    && grep -q '| 50-open-fixture | ready |' "$D/projt/facts/requirements/tickets/progress-current.md"; then
    ok '闭包正例 R3 已安装 ticket-ops open 真实执行 → exit 0 索引落条目且投影再生（安装布局 schema/validator/generate-progress 依赖链生效）'
  else
    bad '闭包正例 R3 已安装 ticket-ops open 真实执行 → exit 0 索引落条目且投影再生（安装布局 schema/validator/generate-progress 依赖链生效）' "exit=$rc out=$(tail -n 1 "$D/r3.out")"
  fi

  # 闭包负例 N7（missing-validator，运行时）：已安装树删 validator → ticket-grade 与
  # ticket-ops open 都明确失败且报文指名 json-validator.py（假 PASS 在此失败）。
  inst_build_pkg "$D/pkgn1"; mkdir -p "$D/projn1"
  ( cd "$D" && sh "$INST" --target "$D/projn1" --ticket-ops ) >/dev/null 2>&1
  inst_build_target_tree "$D/projn1"
  sed 's/40-grade-fixture/60-neg-fixture/g' "$D/tix/40-grade-fixture.json" > "$D/projn1/facts/requirements/tickets/60-neg-fixture.json"
  rm "$D/projn1/rules/implementation/scripts/json-validator.py"
  ( cd "$D/projn1" && sh "$D/projn1/rules/implementation/scripts/ticket-grade.sh" "$D/projn1/facts/requirements/tickets/60-neg-fixture.json" ) >"$D/n7a.out" 2>&1
  n7a=$?
  ( cd "$D/projn1" && sh "$D/projn1/rules/implementation/scripts/ticket-ops.sh" "$D/projn1" open --id 60-neg-fixture --complexity C0 --title 'fixture 负例' --ledger-line '{"date": "2026-10-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture neg", "evidence_ref": "facts/requirements/tickets/60-neg-fixture.json"}' ) >"$D/n7b.out" 2>&1
  n7b=$?
  if [ "$n7a" -ne 0 ] && grep -q 'json-validator.py' "$D/n7a.out" \
    && [ "$n7b" -ne 0 ] && grep -q 'json-validator.py' "$D/n7b.out" \
    && [ ! -f "$D/projn1/facts/requirements/tickets/progress-current.md" ]; then
    ok '闭包负例 N7 missing-validator（运行时）→ ticket-grade 与 ticket-ops open 均失败且指名 json-validator.py、零写入'
  else
    bad '闭包负例 N7 missing-validator（运行时）→ ticket-grade 与 ticket-ops open 均失败且指名 json-validator.py、零写入' "grade=$n7a open=$n7b"
  fi

  # 闭包负例 N8（missing-data，运行时）：已安装树删 schema → ticket-ops open 明确
  # 失败且报文指名 ticket-record.schema.json（假 PASS 在此失败）。
  inst_build_pkg "$D/pkgn2"; mkdir -p "$D/projn2"
  ( cd "$D" && sh "$INST" --target "$D/projn2" --ticket-ops ) >/dev/null 2>&1
  inst_build_target_tree "$D/projn2"
  sed 's/40-grade-fixture/70-neg-fixture/g' "$D/tix/40-grade-fixture.json" > "$D/projn2/facts/requirements/tickets/70-neg-fixture.json"
  rm "$D/projn2/rules/implementation/references/schemas/ticket-record.schema.json"
  ( cd "$D/projn2" && sh "$D/projn2/rules/implementation/scripts/ticket-ops.sh" "$D/projn2" open --id 70-neg-fixture --complexity C0 --title 'fixture 负例' --ledger-line '{"date": "2026-10-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture neg", "evidence_ref": "facts/requirements/tickets/70-neg-fixture.json"}' ) >"$D/n8.out" 2>&1
  n8=$?
  if [ "$n8" -ne 0 ] && grep -q 'ticket-record.schema.json' "$D/n8.out" \
    && [ ! -f "$D/projn2/facts/requirements/tickets/progress-current.md" ]; then
    ok '闭包负例 N8 missing-data（运行时）→ ticket-ops open 失败且指名 ticket-record.schema.json、零写入'
  else
    bad '闭包负例 N8 missing-data（运行时）→ ticket-ops open 失败且指名 ticket-record.schema.json、零写入' "exit=$n8"
  fi

  # 闭包负例 N9（missing-validator，安装预检）：包副本删 validator → install exit 1
  # 指名复制源缺失与路径、零写入。
  inst_build_pkg "$D/pkgv"; rm "$D/pkgv/scripts/json-validator.py"; mkdir -p "$D/projv"
  ( cd "$D" && sh "$D/pkgv/scripts/install.sh" --target "$D/projv" --ticket-ops ) >/dev/null 2>"$D/pkgv/err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '复制源缺失' "$D/pkgv/err" && grep -q 'json-validator.py' "$D/pkgv/err" \
    && [ ! -d "$D/projv/rules" ]; then
    ok '闭包负例 N9 missing-validator（安装预检）→ install exit 1 指名 json-validator.py、零写入'
  else
    bad '闭包负例 N9 missing-validator（安装预检）→ install exit 1 指名 json-validator.py、零写入' "exit=$rc err=$(head -n 1 "$D/pkgv/err")"
  fi

  # 闭包负例 N10（missing-data，安装预检）：包副本删 schema 与 profile → install
  # exit 1 指名复制源缺失与两数据件路径、零写入。
  inst_build_pkg "$D/pkgd"
  rm "$D/pkgd/references/schemas/ticket-record.schema.json" "$D/pkgd/references/protocol/complexity-profile.md"
  mkdir -p "$D/projd"
  ( cd "$D" && sh "$D/pkgd/scripts/install.sh" --target "$D/projd" --ticket-ops ) >/dev/null 2>"$D/pkgd/err"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '复制源缺失' "$D/pkgd/err" \
    && grep -q 'ticket-record.schema.json' "$D/pkgd/err" && grep -q 'complexity-profile.md' "$D/pkgd/err" \
    && [ ! -d "$D/projd/rules" ]; then
    ok '闭包负例 N10 missing-data（安装预检）→ install exit 1 指名 schema 与 profile 缺失路径、零写入'
  else
    bad '闭包负例 N10 missing-data（安装预检）→ install exit 1 指名 schema 与 profile 缺失路径、零写入' "exit=$rc err=$(head -n 1 "$D/pkgd/err")"
  fi

  # 闭包负例 N11～N13（包闭合）：包副本删 validator／schema／profile → check-package
  # exit 1 指名缺失路径（安装成员闭合的包侧核对面）。
  for ii_i in 1 2 3; do
    case $ii_i in
      1) ii_dep='scripts/json-validator.py'; ii_desc='闭包负例 N11 包副本删 json-validator.py → check-package exit 1 指名缺失路径' ;;
      2) ii_dep='references/schemas/ticket-record.schema.json'; ii_desc='闭包负例 N12 包副本删 ticket-record.schema.json → check-package exit 1 指名缺失路径' ;;
      3) ii_dep='references/protocol/complexity-profile.md'; ii_desc='闭包负例 N13 包副本删 complexity-profile.md → check-package exit 1 指名缺失路径' ;;
    esac
    rm -rf "$D/pkgc$ii_i"
    cp -R "$SCRIPT_DIR/.." "$D/pkgc$ii_i"
    rm "$D/pkgc$ii_i/$ii_dep"
    sh "$D/pkgc$ii_i/scripts/check-package.sh" >"$D/pkgc$ii_i.out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -qF "$ii_dep" "$D/pkgc$ii_i.out"; then
      ok "$ii_desc"
    else
      bad "$ii_desc" "exit=$rc"
    fi
  done

  suite_summary 'install'
}
