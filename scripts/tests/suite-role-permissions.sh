#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite role-permissions "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: role-permissions（票 252 场景沉淀：门禁角色归属与新建文件豁免）
# 覆盖：只改 dispatch.implementation/dispatch.review 的 ready 票体 → exit 0
# （旧实现按缩进把 dispatch 子键误判为 checkpoint 子键）；checkpoint 跨角色、
# 只读字段删除行（title/id）、status 无 checkpoint.commit 三类既有拒绝路径逐件
# exit 1 且报文不变；批内一件新建票文件＋一件 checkpoint 跨角色修改的混合 diff
# 仍 exit 1（新建豁免只作用于该文件自身），单独一件新建票文件 exit 0。
# 夹具＝仓侧 tests/fixtures/role-permissions/*.patch（逐 patch 经 stdin 送入被测
# 脚本，断言退出码与报文；单新建件场景在 mktemp 内现场构造，不入仓）；被测脚本与
# 夹具均按包根上溯定位，消费项目语境缺件显式 SKIP；被测对象只读零改动。
# ============================================================

suite_role_permissions() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='role-permissions'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/rperm
  mkdir -p "$D"
  RP_SCRIPT="$PKG_ROOT/../rules/implementation/scripts/check-role-permissions.sh"
  RP_FIX="$PKG_ROOT/../tests/fixtures/role-permissions"

  if [ ! -f "$RP_SCRIPT" ]; then
    printf 'SKIP  [role-permissions] 仓侧 check-role-permissions.sh 不在场（消费项目语境）——套件跳过，覆盖归源仓\n'
    suite_summary 'role-permissions'
    return 0
  fi
  if [ ! -d "$RP_FIX" ]; then
    printf 'SKIP  [role-permissions] 夹具目录不在场: %s——套件跳过，覆盖归源仓\n' "$RP_FIX"
    suite_summary 'role-permissions'
    return 0
  fi

  # 单新建件夹具：新建票文件内含 dispatch 三阶段（若无新建豁免本身会判跨角色），
  # 单独送入须 exit 0——证明豁免作用于新建文件自身而非整批早退。
  cat > "$D/new-only.patch" <<'EOF'
diff --git a/facts/requirements/tickets/256-role-permission-new-ticket.json b/facts/requirements/tickets/256-role-permission-new-ticket.json
new file mode 100644
index 0000000..4444444
--- /dev/null
+++ b/facts/requirements/tickets/256-role-permission-new-ticket.json
@@ -0,0 +1,16 @@
+{
+  "id": "256-role-permission-new-ticket",
+  "kind": "task",
+  "title": "新建票（单独一件新建文件的豁免面）",
+  "status": "ready",
+  "dispatch": {
+    "implementation": {
+      "GOAL": "新建票的派发目标"
+    },
+    "review": {
+      "REVIEW_SCOPE": "新建票的审查范围"
+    },
+    "commit": {
+      "COMMIT_MESSAGE": "feat: 新建票"
+    }
+  }
+}
EOF

  while IFS='|' read -r _rp_name _rp_want_rc _rp_want_msg; do
    [ -n "$_rp_name" ] || continue
    sh "$RP_SCRIPT" < "$RP_FIX/$_rp_name" > "$D/out.txt" 2>&1
    _rp_rc=$?
    _rp_label="夹具 $_rp_name → exit $_rp_want_rc"
    [ -n "$_rp_want_msg" ] && _rp_label="${_rp_label}（报文含「${_rp_want_msg}」）"
    if [ "$_rp_rc" -eq "$_rp_want_rc" ] \
      && { [ -z "$_rp_want_msg" ] || grep -Fq "$_rp_want_msg" "$D/out.txt"; }; then
      ok "${_rp_label}"
    else
      bad "${_rp_label}" "实际 exit=${_rp_rc} 输出=$(tr '\n' '|' < "$D/out.txt")"
    fi
  done <<'CASES'
valid-implementation-diff.patch|0|
valid-review-diff.patch|0|
valid-commit-diff.patch|0|
valid-backfill-add-id-title.patch|0|
invalid-impl-change-review-field.patch|1|checkpoint.implementation 和 checkpoint.review 同时改动（跨角色违规）
invalid-backfill-with-cross-role-fields.patch|1|checkpoint.implementation 和 checkpoint.review 同时改动（跨角色违规）
invalid-change-title.patch|1|title 是只读字段
invalid-backfill-reposition-existing-title.patch|1|title 是只读字段
invalid-backfill-rewrite-existing-id.patch|1|id 是只读字段
invalid-non-commit-change-status.patch|1|status 改动但无 checkpoint.commit
invalid-backfill-with-status-escalation.patch|1|status 改动但无 checkpoint.commit
valid-dispatch-only-rewrite.patch|0|
valid-dispatch-default-context.patch|0|
invalid-mixed-batch-new-and-cross-role.patch|1|checkpoint.implementation 和 checkpoint.review 同时改动（跨角色违规）
CASES

  sh "$RP_SCRIPT" < "$D/new-only.patch" > "$D/new.out" 2>&1
  _rp_rc=$?
  if [ "$_rp_rc" -eq 0 ]; then
    ok '单独一件新建票文件 → exit 0（新建豁免只作用于该文件自身）'
  else
    bad '单独一件新建票文件 → exit 0（新建豁免只作用于该文件自身）' "实际 exit=$_rp_rc 输出=$(tr '\n' '|' < "$D/new.out")"
  fi

  suite_summary 'role-permissions'
}
