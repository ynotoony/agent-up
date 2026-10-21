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
# CRITERIA），漂移负例在包副本上改模板，被测对象只读）
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

  suite_summary 'dispatch-contract'
}
