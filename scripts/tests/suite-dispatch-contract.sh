#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite dispatch-contract "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: dispatch-contract（派发合同校验器双模式正负例：--check 按类型必备字段
# 完整性三型正例＋缺失字段/类型推断负例；--check-template 零漂移正例＋双向漂移
# 负例；已登记成员缺失被包闭合检查指名负例。夹具全 mktemp 自建不入仓——正反例
# 合同以 wt 源分支两夹具为场景蓝本（implementation 全字段／缺 ACCEPTANCE_
# CRITERIA），漂移负例在包副本上改模板，被测对象只读）；
# 票 230 contract-build 渲染器正负例——键集单源守卫（ticket-record.schema.json
# dispatch 三阶段 required 集＝contract_fields 三阶段，两 schema 漂移即红）、
# 三阶段渲染正例（票 dispatch 节全键→stdout {{KEY}} 行块，产物再过校验器＝自校验
# 闭环）＋五负例（无节存量票／缺必备键／空白值／stage 非法／NN 零命中，均零 stdout）
# 票 238 能力收窄——--check-dispatch 派发前置校验（linked worktree + in_progress
# 放行；主检出／非 in_progress／未领取票 exit 1；非 Git 目录／相对路径／非树根／
# 合同缺字段 exit 2）＋五宿主 execute 行 git_write_enforcement 登记面（受控词表、
# host/runner 机制 token、policy/pending 实现模板降级义务；合成夹具证强制分支非空转）
# 票 253 步数预算——--check-step-budget 四类缺失 fail-closed（缺步数上限／缺到线
# 收尾表述／上限为空／上限非数字各自 exit 1 并指名；四类齐备 exit 0；缺文件 exit 2）。
# ============================================================

# 生成 implementation 型全 16 必备字段合同（占位符逐字段一行块，形态与合同实例一致）
dcon_impl_contract() {
  cat <<'EOF'
Repository / Absolute Path:
{{REPOSITORY_PATH}}

Task:
{{TASK_DESCRIPTION}}

Goal:
{{GOAL}}

Scope:
{{SCOPE_TREE}}

Out of Scope:
{{OUT_OF_SCOPE}}

Context / Evidence:
{{CONTEXT_EVIDENCE}}

Constraints:
{{CONSTRAINTS}}

Forbidden Changes:
{{FORBIDDEN_CHANGES}}

Acceptance Criteria / Definition of Done:
{{ACCEPTANCE_CRITERIA}}

Verification:
{{VERIFICATION_COMMANDS}}

Output Contract:
报告不超过 60 行

Dependencies / Blockers:
{{DEPENDENCIES_BLOCKERS}}

Risks:
{{RISKS}}

Budget / Checkpoints:
{{BUDGET_CHECKPOINTS}}

Estimated Time:
{{ESTIMATED_TIME}}

Actual Time:
{{ACTUAL_TIME}}

Ticket ID:
{{TICKET_ID}}
EOF
}

# 生成 review 型 6 必备字段合同
dcon_review_contract() {
  cat <<'EOF'
Review Scope:
{{REVIEW_SCOPE}}

Implementation Summary:
{{IMPLEMENTATION_SUMMARY}}

Acceptance Criteria:
{{ACCEPTANCE_CRITERIA}}

Diff Location:
{{DIFF_LOCATION}}

Review Dimensions:
{{REVIEW_DIMENSIONS}}

Ticket ID:
{{TICKET_ID}}
EOF
}

# 生成 commit 型 6 必备字段合同
dcon_commit_contract() {
  cat <<'EOF'
Review Pass Checkpoint:
{{REVIEW_PASS_CHECKPOINT}}

File Whitelist:
{{FILE_WHITELIST}}

Commit Message:
{{COMMIT_MESSAGE}}

Record Flip Authorization:
{{RECORD_FLIP_AUTHORIZATION}}

Scope Check Command:
{{SCOPE_CHECK_COMMAND}}

Ticket ID:
{{TICKET_ID}}
EOF
}

# 漂移负例夹具：包副本（scripts/check-dispatch-contract.sh＋references/ 两目录），
# $2=漂移方向（schema-only：模板副本删 {{RISKS}}；template-only：模板副本加 {{EXTRA_PLACEHOLDER}}）
dcon_build_drift_pkg() {
  _dp="$1"
  _dir="$2"
  mkdir -p "$_dp/scripts" "$_dp/references/schemas" "$_dp/references/prompts"
  cp "$SCRIPT_DIR/check-dispatch-contract.sh" "$_dp/scripts/check-dispatch-contract.sh"
  cp "$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json" "$_dp/references/schemas/dispatch-contract.schema.json"
  cp "$SCRIPT_DIR/../references/prompts/implementation-prompt.md" "$SCRIPT_DIR/../references/prompts/review-prompt.md" "$SCRIPT_DIR/../references/prompts/commit-prompt.md" "$_dp/references/prompts/"
  if [ "$_dir" = "schema-only" ]; then
    grep -v '{{RISKS}}' "$_dp/references/prompts/implementation-prompt.md" > "$_dp/prompts.tmp" && mv "$_dp/prompts.tmp" "$_dp/references/prompts/implementation-prompt.md"
  elif [ "$_dir" = "template-only" ]; then
    printf '\nExtra:\n{{EXTRA_PLACEHOLDER}}\n' >> "$_dp/references/prompts/review-prompt.md"
  fi
}

# AC2 断言：单宿主 execute 行的 git_write_enforcement 登记面。返回 0 通过并打印
# "<host>=<值>"；返回 1 失败并打印指名原因。判据：execute 行须含受控等级值
# （host-enforced/runner-enforced/policy-only/unavailable/pending）；host/runner 级
# 须带实施机制 token；policy-only/pending/unavailable 级须实现模板保留
# git_write_enforcement 与降级原因的记录义务（软约束不得静默）。
dcon_git_write_check() {
  _gw_host="$1"
  _gw_file="$2"
  _gw_impl="$3"

  _gw_line=$(LC_ALL=C awk -F'|' '
    $0 ~ /^\| execute \|/ {
      cell = $4
      gsub(/^[ \t]+/, "", cell)
      gsub(/[ \t]+$/, "", cell)
      print cell
      exit
    }
  ' "$_gw_file")

  if [ -z "$_gw_line" ]; then
    printf '%s 缺 execute 行\n' "$_gw_host"
    return 1
  fi

  _gw_val=$(printf '%s\n' "$_gw_line" | sed -n 's/.*git_write_enforcement: \([a-z][a-z-]*\).*/\1/p')
  if [ -z "$_gw_val" ]; then
    printf '%s execute 行缺 git_write_enforcement 声明\n' "$_gw_host"
    return 1
  fi

  case "$_gw_val" in
    host-enforced|runner-enforced)
      if ! printf '%s\n' "$_gw_line" | LC_ALL=C grep -qE 'permissions\.deny|hooks|sandbox_mode|seccomp|独立(系统)?用户|进程级'; then
        printf '%s git_write_enforcement: %s 缺实施机制 token\n' "$_gw_host" "$_gw_val"
        return 1
      fi
      ;;
    policy-only|pending|unavailable)
      if ! require_out "$_gw_host 实现模板在场" "$_gw_impl"; then
        return 1
      fi
      if ! grep -q 'git_write_enforcement' "$_gw_impl"; then
        printf '%s 为 %s，但实现模板缺 git_write_enforcement 降级记录义务\n' "$_gw_host" "$_gw_val"
        return 1
      fi
      if ! grep -q '降级' "$_gw_impl"; then
        printf '%s 为 %s，但实现模板缺降级原因记录义务\n' "$_gw_host" "$_gw_val"
        return 1
      fi
      ;;
    *)
      printf '%s git_write_enforcement 值越词表: %s\n' "$_gw_host" "$_gw_val"
      return 1
      ;;
  esac

  printf '%s=%s' "$_gw_host" "$_gw_val"
  return 0
}

# 派发前置校验合同夹具：{{REPOSITORY_PATH}} 与 {{TICKET_ID}} 各带实值行（合同形态
# 与 contract-build.sh 渲染序一致：占位符行＋实值行，字段间空行分隔）。
dcon_dispatch_contract() {
  printf '{{REPOSITORY_PATH}}\n%s\n\n{{TICKET_ID}}\n%s\n' "$1" "$2"
}

# 步数预算合同夹具（票 253）：{{BUDGET_CHECKPOINTS}} 实值含「步数上限：<数字>」与
# 到线即收尾／另起交接摘要表述，四类缺失负例由该正例派生。
dcon_budget_contract() {
  cat <<'EOF'
{{BUDGET_CHECKPOINTS}}
单任务步数上限：80；到线即收尾并报告未完成项；另起须带交接摘要（已完成项、未完成项、下一步，不重述全文）

{{TICKET_ID}}
80-sb-fixture
EOF
}

suite_dispatch_contract() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='dispatch-contract'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/dcon
  mkdir -p "$D"
  DC="$SCRIPT_DIR/check-dispatch-contract.sh"

  # 正例 P1：implementation 型全 16 必备字段 → exit 0 且类型推断与 PASS 行在场
  dcon_impl_contract > "$D/pos-impl.txt"
  sh "$DC" --check "$D/pos-impl.txt" > "$D/pos-impl.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '检测到合同类型: implementation' "$D/pos-impl.out" \
    && grep -q 'PASS: 合同文件字段完整（类型: implementation）' "$D/pos-impl.out"; then
    ok '正例 P1 --check implementation 全 16 必备字段合同 → exit 0'
  else
    bad '正例 P1 --check implementation 全 16 必备字段合同 → exit 0' "exit=$rc $(tail -n 3 "$D/pos-impl.out" | tr '\n' '|')"
  fi

  # 正例 P2：review 型 6 必备字段 → exit 0（类型 review）
  dcon_review_contract > "$D/pos-review.txt"
  sh "$DC" --check "$D/pos-review.txt" > "$D/pos-review.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS: 合同文件字段完整（类型: review）' "$D/pos-review.out"; then
    ok '正例 P2 --check review 6 必备字段合同 → exit 0'
  else
    bad '正例 P2 --check review 6 必备字段合同 → exit 0' "exit=$rc $(tail -n 3 "$D/pos-review.out" | tr '\n' '|')"
  fi

  # 正例 P3：commit 型 6 必备字段 → exit 0（类型 commit）
  dcon_commit_contract > "$D/pos-commit.txt"
  sh "$DC" --check "$D/pos-commit.txt" > "$D/pos-commit.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS: 合同文件字段完整（类型: commit）' "$D/pos-commit.out"; then
    ok '正例 P3 --check commit 6 必备字段合同 → exit 0'
  else
    bad '正例 P3 --check commit 6 必备字段合同 → exit 0' "exit=$rc $(tail -n 3 "$D/pos-commit.out" | tr '\n' '|')"
  fi

  # 负例 N1：implementation 型缺 ACCEPTANCE_CRITERIA → exit 1 且 FAIL 块逐名报出
  grep -v '{{ACCEPTANCE_CRITERIA}}' "$D/pos-impl.txt" > "$D/neg-missing.txt"
  sh "$DC" --check "$D/neg-missing.txt" > "$D/neg-missing.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 合同文件缺失字段：' "$D/neg-missing.out" \
    && grep -qx 'ACCEPTANCE_CRITERIA' "$D/neg-missing.out"; then
    ok '负例 N1 缺 ACCEPTANCE_CRITERIA → exit 1 且逐名报出'
  else
    bad '负例 N1 缺 ACCEPTANCE_CRITERIA → exit 1 且逐名报出' "exit=$rc $(tail -n 3 "$D/neg-missing.out" | tr '\n' '|')"
  fi

  # 负例 N2：无特征字段 → exit 1 且报无法推断合同类型
  printf 'no placeholders here\n' > "$D/neg-unknown.txt"
  sh "$DC" --check "$D/neg-unknown.txt" > "$D/neg-unknown.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '无法推断合同类型' "$D/neg-unknown.out"; then
    ok '负例 N2 无特征字段 → exit 1 无法推断合同类型'
  else
    bad '负例 N2 无特征字段 → exit 1 无法推断合同类型' "exit=$rc $(tail -n 3 "$D/neg-unknown.out" | tr '\n' '|')"
  fi

  # 正例 P4：--check-template 对包内三份 prompt 模板零漂移 → exit 0
  sh "$DC" --check-template > "$D/pos-drift.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS: 模板/schema 零差集' "$D/pos-drift.out"; then
    ok '正例 P4 --check-template 包内三模板零漂移 → exit 0'
  else
    bad '正例 P4 --check-template 包内三模板零漂移 → exit 0' "exit=$rc $(tail -n 5 "$D/pos-drift.out" | tr '\n' '|')"
  fi

  # 负例 N3：schema 有模板无（副本模板删 {{RISKS}}）→ exit 1 指名方向与字段
  dcon_build_drift_pkg "$D/drift-so" "schema-only"
  sh "$D/drift-so/scripts/check-dispatch-contract.sh" --check-template > "$D/neg-so.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: schema 有但模板无：' "$D/neg-so.out" \
    && grep -qx 'RISKS' "$D/neg-so.out"; then
    ok '负例 N3 模板删 {{RISKS}} → exit 1 指名 schema 有模板无'
  else
    bad '负例 N3 模板删 {{RISKS}} → exit 1 指名 schema 有模板无' "exit=$rc $(tail -n 3 "$D/neg-so.out" | tr '\n' '|')"
  fi

  # 负例 N4：模板有 schema 无（副本模板加 {{EXTRA_PLACEHOLDER}}）→ exit 1 指名方向与字段
  dcon_build_drift_pkg "$D/drift-to" "template-only"
  sh "$D/drift-to/scripts/check-dispatch-contract.sh" --check-template > "$D/neg-to.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 模板有但 schema 无：' "$D/neg-to.out" \
    && grep -qx 'EXTRA_PLACEHOLDER' "$D/neg-to.out"; then
    ok '负例 N4 模板加未登记占位符 → exit 1 指名模板有 schema 无'
  else
    bad '负例 N4 模板加未登记占位符 → exit 1 指名模板有 schema 无' "exit=$rc $(tail -n 3 "$D/neg-to.out" | tr '\n' '|')"
  fi

  # 负例 N5：包副本删已登记 schema 件 → 包闭合检查 exit 1 指名缺失件
  cp -R "$PKG_ROOT" "$D/pkgcopy-schema"
  rm -f "$D/pkgcopy-schema/references/schemas/dispatch-contract.schema.json"
  sh "$D/pkgcopy-schema/scripts/check-package.sh" "$D/pkgcopy-schema" > "$D/neg-pkg-schema.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 1 必需入口存在' "$D/neg-pkg-schema.out" \
    && grep -q 'references/schemas/dispatch-contract.schema.json' "$D/neg-pkg-schema.out"; then
    ok '负例 N5 包副本删 schema 登记件 → check-package exit 1 指名'
  else
    bad '负例 N5 包副本删 schema 登记件 → check-package exit 1 指名' "exit=$rc $(tail -n 3 "$D/neg-pkg-schema.out" | tr '\n' '|')"
  fi

  # 负例 N6：包副本删已登记校验器 → 包闭合检查 exit 1 指名缺失件
  cp -R "$PKG_ROOT" "$D/pkgcopy-script"
  rm -f "$D/pkgcopy-script/scripts/check-dispatch-contract.sh"
  sh "$D/pkgcopy-script/scripts/check-package.sh" "$D/pkgcopy-script" > "$D/neg-pkg-script.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 8 脚本必需件存在' "$D/neg-pkg-script.out" \
    && grep -q 'scripts/check-dispatch-contract.sh' "$D/neg-pkg-script.out"; then
    ok '负例 N6 包副本删校验器登记件 → check-package exit 1 指名'
  else
    bad '负例 N6 包副本删校验器登记件 → check-package exit 1 指名' "exit=$rc $(tail -n 3 "$D/neg-pkg-script.out" | tr '\n' '|')"
  fi

  # ---- contract-build.sh 渲染器正负例（票 230：票 dispatch 节→stdout 派发合同）----
  # 键集单源守卫：ticket-record.schema.json dispatch 三阶段 required 集＝
  # dispatch-contract.schema.json contract_fields 三阶段（存储合同镜像投影，两处漂移即红，
  # 与 open 门及渲染读取面同源）；渲染正例三阶段：fixture 票全键 → exit 0 且 stdout 含
  # 该阶段全 {{KEY}} 行块，产物再过 check-dispatch-contract --check exit 0（自校验闭环）；
  # 负例：无节存量票／缺必备键／空白值／stage 非法／NN 零命中均失败且零 stdout
  # （fail-closed：半份合同不出门）。夹具全 mktemp。
  CB="$SCRIPT_DIR/contract-build.sh"
  DCS_SCHEMA="$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json"
  TRS_SCHEMA="$SCRIPT_DIR/../references/schemas/ticket-record.schema.json"
  python3 - "$TRS_SCHEMA" "$DCS_SCHEMA" <<'PYTHON'
import json, sys
trs = json.load(open(sys.argv[1], encoding='utf-8'))
dcs = json.load(open(sys.argv[2], encoding='utf-8'))['contract_fields']
okv = all(
    sorted(trs['properties']['dispatch']['properties'][st]['required']) == sorted(dcs[st])
    for st in ('implementation', 'review', 'commit')
)
sys.exit(0 if okv else 1)
PYTHON
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 键集单源 ticket-record dispatch 三阶段 required 集与 contract_fields 三阶段逐一相等'
  else
    bad '正例 键集单源 ticket-record dispatch 三阶段 required 集与 contract_fields 三阶段逐一相等' '两 schema 键集漂移'
  fi
  # 渲染夹具：fixture 仓根（facts/requirements/tickets 两票：80 全节／81 无节存量形态）
  mkdir -p "$D/cbfix/facts/requirements/tickets"
  python3 - "$D/cbfix/facts/requirements/tickets/80-cb-fixture.json" <<'PYTHON'
import json, sys
def stage(keys, tag):
    return {k: 'fixture %s %s' % (tag, k) for k in keys}
body = {
    'id': '80-cb-fixture', 'kind': 'task', 'title': 'cb fixture', 'created_at': '2026-10-26',
    'dispatch': {
        'implementation': stage(['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID'], 'impl'),
        'review': stage(['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID'], 'review'),
        'commit': stage(['REVIEW_PASS_CHECKPOINT', 'FILE_WHITELIST', 'COMMIT_MESSAGE', 'RECORD_FLIP_AUTHORIZATION', 'SCOPE_CHECK_COMMAND', 'TICKET_ID'], 'commit'),
    },
}
json.dump(body, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
PYTHON
  printf '{"id": "81-cb-legacy", "kind": "task", "title": "legacy no-dispatch", "created_at": "2026-10-26"}\n' > "$D/cbfix/facts/requirements/tickets/81-cb-legacy.json"
  sh "$CB" implementation 80 "$D/cbfix" > "$D/cb-impl.out" 2> "$D/cb-impl.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(grep -c '^{{[A-Z_]*}}$' "$D/cb-impl.out")" -eq 16 ] && grep -q '^{{REPOSITORY_PATH}}$' "$D/cb-impl.out" && grep -q '^{{TICKET_ID}}$' "$D/cb-impl.out"; then
    ok '正例 implementation 渲染 → exit 0 且 stdout 含全 16 {{KEY}} 行块'
  else
    bad '正例 implementation 渲染 → exit 0 且 stdout 含全 16 {{KEY}} 行块' "exit=$rc blocks=$(grep -c '^{{' "$D/cb-impl.out")"
  fi
  sh "$DC" --check "$D/cb-impl.out" > "$D/cb-impl-check.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 implementation 产物再过 check-dispatch-contract --check → exit 0（自校验闭环）'
  else
    bad '正例 implementation 产物再过 check-dispatch-contract --check → exit 0（自校验闭环）' "$(head -n 2 "$D/cb-impl-check.out" | tr '\n' '|')"
  fi
  sh "$CB" review 80 "$D/cbfix" > "$D/cb-review.out" 2> "$D/cb-review.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(grep -c '^{{[A-Z_]*}}$' "$D/cb-review.out")" -eq 6 ] && grep -q '^{{REVIEW_SCOPE}}$' "$D/cb-review.out"; then
    ok '正例 review 渲染 → exit 0 且 stdout 含全 6 {{KEY}} 行块'
  else
    bad '正例 review 渲染 → exit 0 且 stdout 含全 6 {{KEY}} 行块' "exit=$rc blocks=$(grep -c '^{{' "$D/cb-review.out")"
  fi
  sh "$CB" commit 80 "$D/cbfix" > "$D/cb-commit.out" 2> "$D/cb-commit.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(grep -c '^{{[A-Z_]*}}$' "$D/cb-commit.out")" -eq 6 ] && grep -q '^{{FILE_WHITELIST}}$' "$D/cb-commit.out"; then
    ok '正例 commit 渲染 → exit 0 且 stdout 含全 6 {{KEY}} 行块'
  else
    bad '正例 commit 渲染 → exit 0 且 stdout 含全 6 {{KEY}} 行块' "exit=$rc blocks=$(grep -c '^{{' "$D/cb-commit.out")"
  fi
  sh "$DC" --check "$D/cb-review.out" > /dev/null 2>&1; _rc_r=$?
  sh "$DC" --check "$D/cb-commit.out" > /dev/null 2>&1; _rc_c=$?
  if [ "$_rc_r" -eq 0 ] && [ "$_rc_c" -eq 0 ]; then
    ok '正例 review/commit 产物再过校验器均 exit 0（三阶段自校验闭环）'
  else
    bad '正例 review/commit 产物再过校验器均 exit 0（三阶段自校验闭环）' "review=$_rc_r commit=$_rc_c"
  fi
  # 负例：无节存量票 → exit 1 零 stdout 且报文指名（存量不迁移）
  sh "$CB" implementation 81 "$D/cbfix" > "$D/cb-n1.out" 2> "$D/cb-n1.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/cb-n1.out" ] && grep -q 'dispatch.implementation' "$D/cb-n1.err"; then
    ok '负例 无节存量票渲染 → exit 1 零 stdout 且报文指名 dispatch（存量不迁移）'
  else
    bad '负例 无节存量票渲染 → exit 1 零 stdout 且报文指名 dispatch（存量不迁移）' "exit=$rc out=$(wc -c < "$D/cb-n1.out")B"
  fi
  # 负例：缺必备键 → exit 1 零 stdout
  python3 - "$D/cbfix/facts/requirements/tickets/82-cb-misskey.json" <<'PYTHON'
import json, sys
body = {
    'id': '82-cb-misskey', 'kind': 'task', 'title': 'misskey', 'created_at': '2026-10-26',
    'dispatch': {
        'implementation': {k: 'fixture impl ' + k for k in ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']},
        'review': {k: 'fixture review ' + k for k in ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']},
        'commit': {k: 'fixture commit ' + k for k in ['REVIEW_PASS_CHECKPOINT', 'FILE_WHITELIST', 'COMMIT_MESSAGE', 'RECORD_FLIP_AUTHORIZATION', 'SCOPE_CHECK_COMMAND', 'TICKET_ID']},
    },
}
json.dump(body, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
PYTHON
  sh "$CB" implementation 82 "$D/cbfix" > "$D/cb-n2.out" 2> "$D/cb-n2.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/cb-n2.out" ] && grep -q 'GOAL' "$D/cb-n2.err"; then
    ok '负例 缺必备键（GOAL）渲染 → exit 1 零 stdout 且报文指名键'
  else
    bad '负例 缺必备键（GOAL）渲染 → exit 1 零 stdout 且报文指名键' "exit=$rc out=$(wc -c < "$D/cb-n2.out")B"
  fi
  # 负例：空白值 → exit 1 零 stdout
  python3 - "$D/cbfix/facts/requirements/tickets/83-cb-blank.json" <<'PYTHON'
import json, sys
body = {
    'id': '83-cb-blank', 'kind': 'task', 'title': 'blank', 'created_at': '2026-10-26',
    'dispatch': {
        'implementation': {k: 'fixture impl ' + k for k in ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE', 'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA', 'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS', 'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']},
        'review': {k: 'fixture review ' + k for k in ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA', 'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']},
        'commit': {k: 'fixture commit ' + k for k in ['REVIEW_PASS_CHECKPOINT', 'FILE_WHITELIST', 'COMMIT_MESSAGE', 'RECORD_FLIP_AUTHORIZATION', 'SCOPE_CHECK_COMMAND', 'TICKET_ID']},
    },
}
body['dispatch']['review']['TICKET_ID'] = '   '
json.dump(body, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
PYTHON
  sh "$CB" review 83 "$D/cbfix" > "$D/cb-n3.out" 2> "$D/cb-n3.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/cb-n3.out" ] && grep -q '非空白字符串' "$D/cb-n3.err"; then
    ok '负例 空白值（review.TICKET_ID）渲染 → exit 1 零 stdout 且报文指名'
  else
    bad '负例 空白值（review.TICKET_ID）渲染 → exit 1 零 stdout 且报文指名' "exit=$rc out=$(wc -c < "$D/cb-n3.out")B"
  fi
  # 负例：stage 非法 → exit 2 零 stdout
  sh "$CB" bogus 80 "$D/cbfix" > "$D/cb-n4.out" 2> /dev/null
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$D/cb-n4.out" ]; then
    ok '负例 stage 非法渲染 → exit 2 零 stdout（用法错误面）'
  else
    bad '负例 stage 非法渲染 → exit 2 零 stdout（用法错误面）' "exit=$rc"
  fi
  # 负例：NN 段零命中 → exit 1 零 stdout
  sh "$CB" implementation 99 "$D/cbfix" > "$D/cb-n5.out" 2> /dev/null
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/cb-n5.out" ]; then
    ok '负例 NN 段零命中渲染 → exit 1 零 stdout（票定位 fail-closed）'
  else
    bad '负例 NN 段零命中渲染 → exit 1 零 stdout（票定位 fail-closed）' "exit=$rc"
  fi

  # ---- AC2：git 写强制等级登记面（五宿主 execute 行 + 实现模板降级义务）----
  # 生产登记面：五宿主逐一过 dcon_git_write_check（受控词表；host/runner 须带机制，
  # policy/pending/unavailable 须实现模板保留降级记录义务）。合成夹具另证 host-enforced
  # 分支非空转：带机制 token 通过、无机制与越词表值指名失败。
  GW_IMPL="$PKG_ROOT/references/templates/agents-implementation.md.tmpl"
  _gw_n=0
  _gw_fail=''
  _gw_seen=''
  for _gw_h in zcode claude-code codex pi dsh; do
    if _gw_msg=$(dcon_git_write_check "$_gw_h" "$PKG_ROOT/references/adapters/$_gw_h.md" "$GW_IMPL"); then
      _gw_n=$((_gw_n + 1))
      _gw_seen="$_gw_seen $_gw_msg"
    else
      _gw_fail="$_gw_fail; $_gw_msg"
    fi
  done
  if [ "$_gw_n" -eq 5 ] && [ -z "$_gw_fail" ]; then
    ok "正例 AC2 五宿主 execute 行 git_write_enforcement 登记合规（${_gw_seen}）"
  else
    bad '正例 AC2 五宿主 execute 行 git_write_enforcement 登记合规' "通过=$_gw_n/5 失败=$_gw_fail"
  fi
  cat > "$D/gw-host-forced.md" <<'EOF'
| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| execute | shell | 可变更工作区状态的命令；git_write_enforcement: host-enforced（permissions.deny 拒绝 .git 写） |
EOF
  if _gw_msg=$(dcon_git_write_check synth-forced "$D/gw-host-forced.md" "$GW_IMPL"); then
    ok '正例 AC2 合成 host-enforced 带机制 token → 扫描通过（强制分支非空转）'
  else
    bad '正例 AC2 合成 host-enforced 带机制 token → 扫描通过（强制分支非空转）' "$_gw_msg"
  fi
  printf '| execute | shell | 可变更工作区状态的命令；git_write_enforcement: host-enforced（自称强制） |\n' > "$D/gw-host-bare.md"
  if _gw_msg=$(dcon_git_write_check synth-bare "$D/gw-host-bare.md" "$GW_IMPL"); then
    bad '负例 AC2 合成 host-enforced 无机制 token → 指名失败' "意外通过：$_gw_msg"
  else
    case "$_gw_msg" in
      *缺实施机制*) ok '负例 AC2 合成 host-enforced 无机制 token → 指名失败' ;;
      *) bad '负例 AC2 合成 host-enforced 无机制 token → 指名失败' "$_gw_msg" ;;
    esac
  fi
  printf '| execute | shell | 可变更工作区状态的命令；git_write_enforcement: sandboxed（越词表） |\n' > "$D/gw-host-vocab.md"
  if _gw_msg=$(dcon_git_write_check synth-vocab "$D/gw-host-vocab.md" "$GW_IMPL"); then
    bad '负例 AC2 合成越词表等级值 → 指名失败' "意外通过：$_gw_msg"
  else
    case "$_gw_msg" in
      *越词表*) ok '负例 AC2 合成越词表等级值 → 指名失败' ;;
      *) bad '负例 AC2 合成越词表等级值 → 指名失败' "$_gw_msg" ;;
    esac
  fi
  mkdir -p "$D/gwimpl"
  grep -v 'git_write_enforcement' "$GW_IMPL" > "$D/gwimpl/agents-implementation.md.tmpl"
  if _gw_msg=$(dcon_git_write_check zcode "$PKG_ROOT/references/adapters/zcode.md" "$D/gwimpl/agents-implementation.md.tmpl"); then
    bad '负例 AC2 实现模板删 git_write_enforcement → 指名失败' "意外通过：$_gw_msg"
  else
    case "$_gw_msg" in
      *git_write_enforcement*) ok '负例 AC2 实现模板删 git_write_enforcement → 指名失败' ;;
      *) bad '负例 AC2 实现模板删 git_write_enforcement → 指名失败' "$_gw_msg" ;;
    esac
  fi

  # ---- AC4：--check-dispatch 派发前置校验（linked worktree + in_progress）----
  # 夹具＝临时主仓＋linked worktree＋主仓索引两票（in_progress / ready）。正例放行；
  # 主检出路径、非 in_progress、未领取票 exit 1；非 Git 目录、相对路径、非树根、
  # 合同缺字段 exit 2。
  GW="$D/gw"
  mkdir -p "$GW/main/facts/requirements/tickets"
  git -C "$GW/main" -c init.defaultBranch=main init -q
  git -C "$GW/main" -c user.email=fixture@example.com -c user.name=fixture commit -q --allow-empty -m init
  git -C "$GW/main" worktree add -q "$GW/wt" -b gw-branch
  python3 - "$GW/main/facts/requirements/tickets/index.json" <<'PY'
import json, sys
issues = [
    {"id": "80-gw-fixture", "status": "in_progress", "complexity": "C0", "blocked_by": [], "updated_at": "2026-11-02T00:00"},
    {"id": "81-gw-ready", "status": "ready", "complexity": "C0", "blocked_by": [], "updated_at": "2026-11-02T00:00"},
]
json.dump({"issues": issues}, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
PY
  dcon_dispatch_contract "$GW/wt" "80-gw-fixture" > "$D/gwd-ok.txt"
  sh "$DC" --check-dispatch "$D/gwd-ok.txt" > "$D/gwd-ok.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS: 派发前置校验（linked worktree + in_progress: 80-gw-fixture）' "$D/gwd-ok.out"; then
    ok '正例 AC4 linked worktree + in_progress 票 → exit 0'
  else
    bad '正例 AC4 linked worktree + in_progress 票 → exit 0' "exit=$rc $(tail -n 3 "$D/gwd-ok.out" | tr '\n' '|')"
  fi
  dcon_dispatch_contract "$GW/main" "80-gw-fixture" > "$D/gwd-main.txt"
  sh "$DC" --check-dispatch "$D/gwd-main.txt" > "$D/gwd-main.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '主检出' "$D/gwd-main.out"; then
    ok '负例 AC4 主检出路径 → exit 1 并指名主检出'
  else
    bad '负例 AC4 主检出路径 → exit 1 并指名主检出' "exit=$rc $(tail -n 2 "$D/gwd-main.out" | tr '\n' '|')"
  fi
  dcon_dispatch_contract "$GW/wt" "81-gw-ready" > "$D/gwd-ready.txt"
  sh "$DC" --check-dispatch "$D/gwd-ready.txt" > "$D/gwd-ready.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'status=ready' "$D/gwd-ready.out" && grep -q 'in_progress' "$D/gwd-ready.out"; then
    ok '负例 AC4 票 status=ready → exit 1 并指名状态与 in_progress 要求'
  else
    bad '负例 AC4 票 status=ready → exit 1 并指名状态与 in_progress 要求' "exit=$rc $(tail -n 2 "$D/gwd-ready.out" | tr '\n' '|')"
  fi
  dcon_dispatch_contract "$GW/wt" "89-gw-none" > "$D/gwd-none.txt"
  sh "$DC" --check-dispatch "$D/gwd-none.txt" > "$D/gwd-none.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '未领取' "$D/gwd-none.out"; then
    ok '负例 AC4 未领取票（索引无条目）→ exit 1 并指名未领取'
  else
    bad '负例 AC4 未领取票（索引无条目）→ exit 1 并指名未领取' "exit=$rc $(tail -n 2 "$D/gwd-none.out" | tr '\n' '|')"
  fi
  mkdir -p "$GW/plain"
  dcon_dispatch_contract "$GW/plain" "80-gw-fixture" > "$D/gwd-nogit.txt"
  sh "$DC" --check-dispatch "$D/gwd-nogit.txt" > "$D/gwd-nogit.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '不是 Git 工作树' "$D/gwd-nogit.out"; then
    ok '负例 AC4 非 Git 目录 → exit 2 并指名不是 Git 工作树'
  else
    bad '负例 AC4 非 Git 目录 → exit 2 并指名不是 Git 工作树' "exit=$rc $(tail -n 2 "$D/gwd-nogit.out" | tr '\n' '|')"
  fi
  dcon_dispatch_contract "relative/wt" "80-gw-fixture" > "$D/gwd-rel.txt"
  sh "$DC" --check-dispatch "$D/gwd-rel.txt" > "$D/gwd-rel.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '绝对路径' "$D/gwd-rel.out"; then
    ok '负例 AC4 REPOSITORY_PATH 相对路径 → exit 2'
  else
    bad '负例 AC4 REPOSITORY_PATH 相对路径 → exit 2' "exit=$rc $(tail -n 2 "$D/gwd-rel.out" | tr '\n' '|')"
  fi
  mkdir -p "$GW/wt/sub"
  dcon_dispatch_contract "$GW/wt/sub" "80-gw-fixture" > "$D/gwd-sub.txt"
  sh "$DC" --check-dispatch "$D/gwd-sub.txt" > "$D/gwd-sub.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '工作树根' "$D/gwd-sub.out"; then
    ok '负例 AC4 REPOSITORY_PATH 为工作树子目录 → exit 2'
  else
    bad '负例 AC4 REPOSITORY_PATH 为工作树子目录 → exit 2' "exit=$rc $(tail -n 2 "$D/gwd-sub.out" | tr '\n' '|')"
  fi
  dcon_commit_contract > "$D/gwd-missrepo.txt"
  sh "$DC" --check-dispatch "$D/gwd-missrepo.txt" > "$D/gwd-missrepo.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'REPOSITORY_PATH' "$D/gwd-missrepo.out"; then
    ok '负例 AC4 合同缺 REPOSITORY_PATH → exit 2'
  else
    bad '负例 AC4 合同缺 REPOSITORY_PATH → exit 2' "exit=$rc $(tail -n 2 "$D/gwd-missrepo.out" | tr '\n' '|')"
  fi

  # ---- 票 253：--check-step-budget（步数上限＋到线收尾；四类缺失 fail-closed）----
  # 正例＝四类齐备 exit 0；负例四类各自 exit 1 并指名：缺步数上限／缺到线收尾表述／
  # 上限为空／上限非数字；缺文件 exit 2（环境错误面）。
  SB="$D/sb"
  mkdir -p "$SB"
  dcon_budget_contract > "$SB/pos.txt"
  sh "$DC" --check-step-budget "$SB/pos.txt" > "$SB/pos.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'PASS: 步数预算与到线收尾完整（步数上限 80）' "$SB/pos.out"; then
    ok '正例 --check-step-budget 步数上限＋到线收尾齐备 → exit 0'
  else
    bad '正例 --check-step-budget 步数上限＋到线收尾齐备 → exit 0' "exit=$rc $(tail -n 2 "$SB/pos.out" | tr '\n' '|')"
  fi
  grep -v '步数上限' "$SB/pos.txt" > "$SB/neg-budget.txt"
  sh "$DC" --check-step-budget "$SB/neg-budget.txt" > "$SB/neg-budget.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '缺步数上限' "$SB/neg-budget.out"; then
    ok '负例 --check-step-budget 缺步数上限 → exit 1 并指名缺步数上限'
  else
    bad '负例 --check-step-budget 缺步数上限 → exit 1 并指名缺步数上限' "exit=$rc $(tail -n 2 "$SB/neg-budget.out" | tr '\n' '|')"
  fi
  sed 's/到线即收尾[^；]*；//' "$SB/pos.txt" > "$SB/neg-wrapup.txt"
  sh "$DC" --check-step-budget "$SB/neg-wrapup.txt" > "$SB/neg-wrapup.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '缺到线收尾表述' "$SB/neg-wrapup.out"; then
    ok '负例 --check-step-budget 缺到线收尾表述 → exit 1 并指名缺到线收尾表述'
  else
    bad '负例 --check-step-budget 缺到线收尾表述 → exit 1 并指名缺到线收尾表述' "exit=$rc $(tail -n 2 "$SB/neg-wrapup.out" | tr '\n' '|')"
  fi
  sed 's/步数上限：80/步数上限：/' "$SB/pos.txt" > "$SB/neg-empty.txt"
  sh "$DC" --check-step-budget "$SB/neg-empty.txt" > "$SB/neg-empty.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '步数上限为空' "$SB/neg-empty.out"; then
    ok '负例 --check-step-budget 上限为空 → exit 1 并指名步数上限为空'
  else
    bad '负例 --check-step-budget 上限为空 → exit 1 并指名步数上限为空' "exit=$rc $(tail -n 2 "$SB/neg-empty.out" | tr '\n' '|')"
  fi
  sed 's/步数上限：80/步数上限：八十/' "$SB/pos.txt" > "$SB/neg-nan.txt"
  sh "$DC" --check-step-budget "$SB/neg-nan.txt" > "$SB/neg-nan.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '步数上限非数字' "$SB/neg-nan.out"; then
    ok '负例 --check-step-budget 上限非数字 → exit 1 并指名步数上限非数字'
  else
    bad '负例 --check-step-budget 上限非数字 → exit 1 并指名步数上限非数字' "exit=$rc $(tail -n 2 "$SB/neg-nan.out" | tr '\n' '|')"
  fi
  sh "$DC" --check-step-budget "$SB/missing.txt" > "$SB/missing.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '合同文件不存在' "$SB/missing.out"; then
    ok '负例 --check-step-budget 合同文件不存在 → exit 2（环境错误面）'
  else
    bad '负例 --check-step-budget 合同文件不存在 → exit 2（环境错误面）' "exit=$rc $(tail -n 2 "$SB/missing.out" | tr '\n' '|')"
  fi

  suite_summary 'dispatch-contract'
}
