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
# missing-data 负例真走失败路径，包副本删依赖由安装预检与 check-package 双层指名；
# 票 230 派发合同链随票修——ticket-ops 门控扩六件（contract-build.sh＋
# check-dispatch-contract.sh 脚本件＋dispatch-contract.schema.json＋三模板数据件），
# P1/P2 金样 15→21 件（脚本 13→15＋数据 2→6），R1 闭包断言扩渲染器面，
# open 夹具票本体补 dispatch 节（开票门强制）；目录 README 收口生成器与范围规则表
# 随两门控各登记一件：脚本 21→26、合计 27→32（票 266））
# ============================================================

inst_build_pkg() {
  # $1=夹具包根：install.sh＋install-policy.rules＋快道/票务两门控全部登记源（脚本件）
  # ＋references/ 数据件源（ticket-record.schema.json／complexity-profile.md，ip_data
  # 行的解析基準＝脚本目录上一级，夹具布局与包内 agent-up/ 前缀剥离后同构）
  P=$1
  rm -rf "$P"; mkdir -p "$P/scripts" "$P/references/schemas" "$P/references/protocol" "$P/references/prompts"
  cp "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/install-policy.rules" "$P/scripts/"
  for f in check-gates.sh lane-commit.sh worktree-add.sh upgrade-check.sh generate-progress.sh generate-dir-readmes.sh dir-readme.rules ticket-ops.sh ledger-append.sh checkpoint-write.sh run-record.sh ticket-grade.sh absorption-trigger.sh health-summary.sh common-helpers.sh json-validator.py dp-load-rules.sh rules-lexer.sh artifacts-index.sh json-line.sh contract-build.sh check-dispatch-contract.sh ticket-run.sh project-dashboard.html ticket-audit.sh merge-ticket.sh record-store.sh ticket-gates.sh audit-predicates.rules audit-p01-receipt-parseable.sh audit-p02-evidence-committed.sh audit-p03-base-sha-present.sh audit-p04-review-boundary-clean.sh audit-p05-diff-sha-bound.sh audit-p06-reviewer-identity-present.sh audit-p07-reviewer-identity-corroborated.sh audit-p08-reviewer-distinct-from-implementer.sh audit-p09-reviewed-at-valid.sh audit-p10-acceptance-results-present.sh audit-p11-policy-applicable.sh progress-readme.sh jv_contract.py jv_grade.py jv_json_ops.py jv_run.py jv_ticket.py jv_ticket_check.py jv_workflow.py dir_readmes_brief.py dir_readmes_check.py dir_readmes_migrate.py dir_readmes_model.py dir_readmes_sync.py record-commit.sh evidence-rebind.sh ticket-split.sh; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
      printf 'test-record-layer: 夹具依赖缺失: %s/%s（安装闭包登记源）\n' "$SCRIPT_DIR" "$f" >&2
      exit 2
    fi
    cp "$SCRIPT_DIR/$f" "$P/scripts/$f"
  done
  for f in references/schemas/ticket-record.schema.json references/protocol/complexity-profile.md references/schemas/dispatch-contract.schema.json references/prompts/implementation-prompt.md references/prompts/review-prompt.md references/prompts/commit-prompt.md; do
    if [ ! -f "$SCRIPT_DIR/../$f" ]; then
      printf 'test-record-layer: 夹具依赖缺失: %s/../%s（安装闭包 ip_data 数据件源）\n' "$SCRIPT_DIR" "$f" >&2
      exit 2
    fi
    cp "$SCRIPT_DIR/../$f" "$P/$f"
  done
}

inst_build_seed() {
  # $1=目标根：按模板生成 Seed 治理面（八件套＋四份角色合同＋tickets 目录），不安装脚本。
  # 供票 244 AC3/AC4 夹具；check-artifacts 的登记与实际文件一一对应由模板决定。
  SD=$1
  rm -rf "$SD"
  mkdir -p "$SD/rules/implementation/roles" "$SD/facts/project" "$SD/facts/requirements/tickets"
  INST_TPL="$SCRIPT_DIR/../references/templates"
  cp "$INST_TPL/AGENTS.md.tmpl" "$SD/AGENTS.md"
  cp "$INST_TPL/core.md.tmpl" "$SD/rules/core.md"
  cp "$INST_TPL/assessment.md.tmpl" "$SD/rules/assessment.md"
  cp "$INST_TPL/discipline.md.tmpl" "$SD/rules/implementation/discipline.md"
  cp "$INST_TPL/project.md.tmpl" "$SD/rules/project.md"
  for _sr in implementation review commit triage; do
    cp "$INST_TPL/agents-$_sr.md.tmpl" "$SD/rules/implementation/roles/$_sr.md"
  done
  cp "$INST_TPL/artifacts-yaml.tmpl" "$SD/facts/project/artifacts.yaml"
  : > "$SD/rules/README.md"
  : > "$SD/facts/README.md"
  printf '# 任务票索引（fixture）\n' > "$SD/facts/requirements/tickets/README.md"
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

dp_build_fixture_min() {
  # $1=夹具仓根 $2=delivery.rules 文件：最小 git 夹具仓（已安装 worktree-add 解析链
  # 运行语境；keep.txt＝非 main-only 件，栅栏化创建后必须在 worktree 在场）
  rm -rf "$1"
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email fixture@t
  git -C "$1" config user.name fixture
  mkdir -p "$1/fenced"
  echo x > "$1/fenced/deep.sh"
  echo keep > "$1/keep.txt"
  cp "$2" "$1/delivery.rules"
  git -C "$1" add -A
  git -C "$1" commit -qm init
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

  # 正例 P1：合法表双门控安装 → exit 0 目标恰落 34 件（脚本 28＋数据 6；stdout 摘要行计数）
  # ticket-run 编排闭包在 ticket-ops 单门控补四依赖；双门控仅 ticket-run 为新增唯一文件。
  # 票 234 证据审计引擎随 ticket-ops 门控新增一件：脚本 19→20、合计 25→26；
  # 票 237 合并站入包与 fast-lane 审计依赖新增两件：脚本 20→21、合计 26→27；
  # 票 266 目录 README 生成器与范围规则表两门控各登记：脚本 21→24、合计 27→30；
  # 票 286 共享解析件两门控各登记：脚本 24→26、合计 30→32；
  # 票 288 记录提交 plumbing 收敛两门控各登记：脚本 26→28、合计 32→34。
  # 票 289 内联检查面注册表化：门禁函数库＋审计谓词注册表与十一件分片两门控各登记
  # 十三件：脚本 28→41、合计 34→47。
  # 票 290 生成器多模式拆分：json-validator 七族模块 7 件＋dir-readmes 五模块 5 件＋
  # progress-readme.sh 1 件，两门控各登记（闭包同落位）：脚本 41→54、合计 47→60。
  # 票 293 拆票批量入口随 ticket-ops 门控新增一件：脚本 54→55、合计 60→61。
  inst_build_pkg "$D/pkg1"; mkdir -p "$D/proj1"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p1.out" 2>&1
  rc=$?
  p1_n=$(grep -c '^install: OK:' "$D/p1.out")
  if [ "$rc" -eq 0 ] && [ "$p1_n" -eq 61 ] && grep -q '^install: DONE: 复制 61 件（脚本 55＋数据 6）、幂等跳过 0 件' "$D/p1.out" \
    && [ -f "$D/proj1/rules/implementation/scripts/check-gates.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/ticket-ops.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/ledger-append.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/contract-build.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/ticket-run.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/generate-dir-readmes.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/dir-readme.rules" ]; then
    ok '正例 P1 合法表双门控安装 → exit 0 复制 61 件（脚本 55＋数据 6）落位'
  else
    bad '正例 P1 合法表双门控安装 → exit 0 复制 61 件（脚本 55＋数据 6）落位' "exit=$rc ok_lines=$p1_n"
  fi

  # 正例 P1b（票 244 AC1）：安装后每个可执行脚本 --help 冒烟运行 exit 0
  # 共享库两件（common-helpers/dp-load-rules）不是可执行入口，按设计无 --help。
  p1b_bad=''
  for _hf in $(LC_ALL=C find "$D/proj1/rules/implementation/scripts" -name '*.sh' | LC_ALL=C sort); do
    _hb=${_hf##*/}
    case $_hb in common-helpers.sh|dp-load-rules.sh) continue ;; esac
    sh "$_hf" --help >/dev/null 2>&1 || p1b_bad="$p1b_bad $_hb"
  done
  if [ -z "$p1b_bad" ]; then
    ok '正例 P1b 安装后全部可执行脚本 --help 冒烟 exit 0（票 244 AC1）'
  else
    bad '正例 P1b 安装后全部可执行脚本 --help 冒烟 exit 0（票 244 AC1）' "未过:$p1b_bad"
  fi

  # 正例 P2：幂等重跑 → 逐件 SKIP exit 0 零新写入（文件集与首跑逐一相等）
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.before"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p2.out" 2>&1
  rc=$?
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.after"
  if [ "$rc" -eq 0 ] && grep -q '^install: DONE: 复制 0 件（脚本 0＋数据 0）、幂等跳过 61 件' "$D/p2.out" \
    && cmp -s "$D/p2.tree.before" "$D/p2.tree.after"; then
    ok '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 61 件（文件集零变化）'
  else
    bad '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 61 件（文件集零变化）' "exit=$rc"
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

  # 闭包正例 R1：--ticket-ops 安装 → 入口/validator/helpers/账本写入方脚本件与
  # schema/profile 数据件全部落位（数据件与包基线 cmp 字节一致）。
  inst_build_pkg "$D/pkgr"; mkdir -p "$D/projr"
  ( cd "$D" && sh "$INST" --target "$D/projr" --ticket-ops ) >"$D/r1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ -f "$D/projr/rules/implementation/scripts/ticket-grade.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/ticket-ops.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/ledger-append.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/json-validator.py" ] \
    && [ -f "$D/projr/rules/implementation/scripts/common-helpers.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/contract-build.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/check-dispatch-contract.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/ticket-run.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/worktree-add.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/dp-load-rules.sh" ] \
    && [ -f "$D/projr/rules/implementation/scripts/check-gates.sh" ] \
    && cmp -s "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" "$D/projr/rules/implementation/references/schemas/ticket-record.schema.json" \
    && cmp -s "$SCRIPT_DIR/../references/protocol/complexity-profile.md" "$D/projr/rules/implementation/references/protocol/complexity-profile.md" \
    && cmp -s "$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json" "$D/projr/rules/implementation/references/schemas/dispatch-contract.schema.json" \
    && cmp -s "$SCRIPT_DIR/../references/prompts/implementation-prompt.md" "$D/projr/rules/implementation/references/prompts/implementation-prompt.md" \
    && cmp -s "$SCRIPT_DIR/../references/prompts/review-prompt.md" "$D/projr/rules/implementation/references/prompts/review-prompt.md" \
    && cmp -s "$SCRIPT_DIR/../references/prompts/commit-prompt.md" "$D/projr/rules/implementation/references/prompts/commit-prompt.md"; then
    ok '闭包正例 R1 minimal target 安装 → exit 0 且入口/validator/helpers/账本写入方/渲染器/校验器脚本件与 schema/profile/dispatch schema/三模板数据件全落位（数据件与包基线字节一致，票 228 单写方＋票 230 渲染闭包）'
  else
    bad '闭包正例 R1 minimal target 安装 → exit 0 且入口/validator/helpers/账本写入方/渲染器/校验器脚本件与 schema/profile/dispatch schema/三模板数据件全落位（数据件与包基线字节一致，票 228 单写方＋票 230 渲染闭包）' "exit=$rc out=$(tail -n 1 "$D/r1.out")"
  fi

  # 闭包正例 R2：已安装 ticket-grade 真实执行 → exit 0 出定级建议（同目录 validator
  # 定位与邻接 references/ profile 路径在安装布局生效）。
  # 票 268：向前生效开票门夹具适配——R3 由本件派生 50-open-fixture 后 open，新开 task
  # 本体须带 user_stories（仅加字段，不动任何断言逻辑与既有断言强度）。
  mkdir -p "$D/tix"
  cat > "$D/tix/40-grade-fixture.json" <<'EOF'
{
  "id": "40-grade-fixture",
  "kind": "task",
  "title": "fixture 记录类票（install 套件 grade 运行正例）",
  "created_at": "2026-10-21",
  "complexity": "C0",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "profile_reason": {"D": "fixture D 维 reason", "B": "fixture B 维 reason", "I": "fixture I 维 reason", "U": "fixture U 维不适用 reason", "S": "fixture S 维不适用 reason", "M": "fixture M 维不适用 reason", "O": "fixture O 维不适用 reason"},
  "blocked_by": [],
  "scope": ["facts/requirements/tickets/"],
  "verification": [{"name": "fixture", "check": "true", "expect_exit": 0}],
  "complexity_reason": "fixture 定级理由（非空）",
  "priority_reason": "fixture 优先级理由（非空）",
  "user_stories": ["US1: 作为夹具维护者，我要安装正例开票携带用户故事，以便开票门正例有载体"],
  "dispatch": {
    "implementation": {"REPOSITORY_PATH": "fixture repo root", "TASK_DESCRIPTION": "fixture task", "GOAL": "fixture goal", "SCOPE_TREE": "fixture scope", "OUT_OF_SCOPE": "fixture oos", "CONTEXT_EVIDENCE": "fixture context", "CONSTRAINTS": "fixture constraints", "FORBIDDEN_CHANGES": "fixture forbidden", "ACCEPTANCE_CRITERIA": "fixture acceptance", "VERIFICATION_COMMANDS": "fixture verification", "DEPENDENCIES_BLOCKERS": "fixture deps", "RISKS": "fixture risks", "BUDGET_CHECKPOINTS": "80 calls", "ESTIMATED_TIME": "0.5d", "ACTUAL_TIME": "by coordinator", "TICKET_ID": "40-grade-fixture"},
    "review": {"REVIEW_SCOPE": "fixture review scope", "IMPLEMENTATION_SUMMARY": "fixture summary", "ACCEPTANCE_CRITERIA": "fixture acceptance", "DIFF_LOCATION": "fixture worktree", "REVIEW_DIMENSIONS": "fixture dimensions", "TICKET_ID": "40-grade-fixture"},
    "commit": {"REVIEW_PASS_CHECKPOINT": "fixture checkpoint", "FILE_WHITELIST": "fixture whitelist", "COMMIT_MESSAGE": "fixture message", "RECORD_FLIP_AUTHORIZATION": "fixture authorization", "SCOPE_CHECK_COMMAND": "fixture command", "TICKET_ID": "40-grade-fixture"}
  }
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
    pkg_copy "$SCRIPT_DIR/.." "$D/pkgc$ii_i"
    rm "$D/pkgc$ii_i/$ii_dep"
    sh "$D/pkgc$ii_i/scripts/check-package.sh" >"$D/pkgc$ii_i.out" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -qF "$ii_dep" "$D/pkgc$ii_i.out"; then
      ok "$ii_desc"
    else
      bad "$ii_desc" "exit=$rc"
    fi
  done

  # 闭包正例 R4～R6（共享解析器安装语境）：--fast-lane 安装 → dp-load-rules.sh 与
  # worktree-add.sh 同落位且字节一致；已安装 worktree-add 真实加载已安装解析器完成
  # delivery.rules 解析链（缺配置拒跑＋合法四节栅栏化创建真跑两形态）。
  inst_build_pkg "$D/pkgdp"; mkdir -p "$D/projdp"
  ( cd "$D" && sh "$INST" --target "$D/projdp" --fast-lane --ticket-ops ) >"$D/r4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ -f "$D/projdp/rules/implementation/scripts/dp-load-rules.sh" ] \
    && [ -f "$D/projdp/rules/implementation/scripts/worktree-add.sh" ] \
    && cmp -s "$SCRIPT_DIR/dp-load-rules.sh" "$D/projdp/rules/implementation/scripts/dp-load-rules.sh"; then
    ok '闭包正例 R4 --fast-lane 安装 → dp-load-rules.sh 落位且与包基线字节一致（解析器入安装闭包）'
  else
    bad '闭包正例 R4 --fast-lane 安装 → dp-load-rules.sh 落位且与包基线字节一致（解析器入安装闭包）' "exit=$rc out=$(tail -n 1 "$D/r4.out")"
  fi

  dp_wt_rules_tmp=$(mktemp "${TMPDIR:-/tmp}/dpinstall.XXXXXX")
  # 已安装 worktree-add：payload-only rules（未声明 main-only 节）→ 解析通过后拒跑
  # exit 2 指名未声明（解析器加载＋解析链在安装布局全链生效，最短越解析点路径）
  printf '# ==== payload：导出形态（export-payload.sh 读）====\ndp_payload_root pr\ndp_payload_remote r\ndp_payload_target b\ndp_payload_local_ref l\n' > "$dp_wt_rules_tmp"
  dp_build_fixture_min "$D/fx.instw" "$dp_wt_rules_tmp"
  ( cd "$D/fx.instw" && sh "$D/projdp/rules/implementation/scripts/worktree-add.sh" ../wt.inst ticket/94-probe ) > "$D/r5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '未声明 main-only 节' "$D/r5.out"; then
    ok '闭包正例 R5 已安装 worktree-add 真实执行 → 解析通过（payload-only 越解析点）后未声明 main-only 节拒跑 exit 2 指名'
  else
    bad '闭包正例 R5 已安装 worktree-add 真实执行 → 解析通过（payload-only 越解析点）后未声明 main-only 节拒跑 exit 2 指名' "exit=$rc $(tail -n 2 "$D/r5.out" | LC_ALL=C tr '\n' '|')"
  fi

  # 已安装 worktree-add：合法四节 rules → 栅栏化创建 exit 0 且 main-only 路径物理不在场
  printf '# ==== payload：导出形态（export-payload.sh 读）====\ndp_payload_root pr\ndp_payload_remote r\ndp_payload_target b\ndp_payload_local_ref l\n\n# ==== main-only：worktree 排除清单（worktree-add.sh 读）====\ndp_mainonly fenced/deep.sh\n' > "$dp_wt_rules_tmp"
  dp_build_fixture_min "$D/fx.instw2" "$dp_wt_rules_tmp"
  ( cd "$D/fx.instw2" && sh "$D/projdp/rules/implementation/scripts/worktree-add.sh" ../wt.inst2 ticket/95-probe ) > "$D/r6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -e "$D/wt.inst2/fenced" ] && [ -f "$D/wt.inst2/keep.txt" ]; then
    ok '闭包正例 R6 已安装 worktree-add 合法四节 rules → 栅栏化创建 exit 0 且 main-only 路径物理不在场（安装布局解析链全链生效）'
  else
    bad '闭包正例 R6 已安装 worktree-add 合法四节 rules → 栅栏化创建 exit 0 且 main-only 路径物理不在场（安装布局解析链全链生效）' "exit=$rc $(tail -n 2 "$D/r6.out" | LC_ALL=C tr '\n' '|')"
  fi
  rm -f "$dp_wt_rules_tmp"

  # ---- 票 244 安装后运行时完整性：AC4（Seed 对账）／AC3（升级对账）／AC2（安装布局 seal） ----
  inst_build_seed "$D/seed4"
  sh "$SCRIPT_DIR/check-artifacts.sh" "$D/seed4" >"$D/r7.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'check-artifacts: PASS' "$D/r7.out"; then
    ok '闭包正例 R7 全新 Seed 治理面 → check-artifacts PASS（登记与实际一一对应，票 244 AC4）'
  else
    bad '闭包正例 R7 全新 Seed 治理面 → check-artifacts PASS（登记与实际一一对应，票 244 AC4）' "exit=$rc $(tail -n 1 "$D/r7.out")"
  fi

  ( cd "$D" && sh "$INST" --target "$D/seed4" --ticket-ops ) >"$D/r8inst.out" 2>&1
  : > "$D/seed4/rules/implementation/scripts/README.md"
  sh "$SCRIPT_DIR/upgrade-check.sh" "$SCRIPT_DIR/.." "$D/seed4" >"$D/r8.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '自动检查面无差距' "$D/r8.out"; then
    ok '闭包正例 R8 安装 ticket-ops 的 Seed 项目 → upgrade-check exit 0（ip_data 数据件与规则块全集同步，票 244 AC3）'
  else
    bad '闭包正例 R8 安装 ticket-ops 的 Seed 项目 → upgrade-check exit 0（ip_data 数据件与规则块全集同步，票 244 AC3）' "exit=$rc $(grep -E '落后|漂移|冲突|结构无效' "$D/r8.out" | head -n 2 | tr '\n' '|')"
  fi

  printf '{"issues": [{"id": "10-alpha-seed", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-30T10:00"}]}\n' > "$D/seed4/facts/requirements/tickets/index.json"
  rm -rf "$D/seed4/.git"
  git -C "$D/seed4" init -q
  git -C "$D/seed4" -c user.email=fixture@t -c user.name=fixture add -A
  git -C "$D/seed4" -c user.email=fixture@t -c user.name=fixture commit -qm init
  sh "$D/seed4/rules/implementation/scripts/run-record.sh" "$D/seed4" new --ticket 10-alpha-seed >"$D/r9.out" 2>&1
  rc=$?
  r9_file=$(LC_ALL=C find "$D/seed4/facts/requirements/runs" -name '*.json' 2>/dev/null | head -n 1)
  if [ "$rc" -eq 0 ] && [ -n "$r9_file" ]; then
    python3 - "$r9_file" <<'PYS'
import json, sys
p = sys.argv[1]
with open(p, encoding='utf-8') as f:
    d = json.load(f)
d['scope'] = ['fixture-scope']
d['last_verified'] = {'command': 'sh run-record.sh seal', 'result': 'pass', 'at': '2026-10-30'}
d['next_step'] = 'seal fixture'
d['usage'] = {'tokens_total': 1, 'requests': 1, 'duration_seconds': 1, 'source': 'executor', 'at': d['updated_at']}
with open(p, 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
PYS
    sh "$D/seed4/rules/implementation/scripts/run-record.sh" "$D/seed4" seal --file "$r9_file" >"$D/r9seal.out" 2>&1
    rc=$?
  fi
  if [ "$rc" -eq 0 ] && grep -q 'seal 通过' "$D/r9seal.out" 2>/dev/null; then
    ok '闭包正例 R9 安装布局 run-record new＋seal → exit 0（引擎同目录定位，不依赖 agent-up/，票 244 AC2）'
  else
    bad '闭包正例 R9 安装布局 run-record new＋seal → exit 0（引擎同目录定位，不依赖 agent-up/，票 244 AC2）' "exit=$rc $(tail -n 1 "$D/r9seal.out" 2>/dev/null)"
  fi

  suite_summary 'install'
}
