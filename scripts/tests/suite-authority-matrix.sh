#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite authority-matrix "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


authority_matrix_check() {
  awk -F'|' -v template_root="$PKG_ROOT/references/templates" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function fail(message) { print "authority-matrix: FAIL: " message > "/dev/stderr"; failed = 1 }
    BEGIN {
      expected_topic["AW-01"] = "user-decision-runtime-facts"
      expected_topic["AW-02"] = "ticket-index-progress"
      expected_topic["AW-03"] = "task-intake-boundary-retired"
      expected_topic["AW-04"] = "review-checkpoint"
      expected_topic["AW-05"] = "commit-authorization"
      expected_topic["AW-06"] = "ticket-body-checkpoints"
    }
    /^\| AW-[0-9][0-9] \|/ {
      if (NF != 8) { fail("matrix row must have six cells: " $0); next }
      id = trim($2); topic = trim($3); authority = trim($4)
      writer = trim($5); resolution = trim($6); consumers = trim($7)
      rows++
      if (!(id in expected_topic) || topic != expected_topic[id]) fail("unknown or mismatched topic: " topic)
      if (authority == "" || writer == "" || resolution == "" || consumers == "") fail("incomplete authority/writer/resolution row: " topic)
      if (topic in topic_seen) {
        if (topic_authority[topic] != authority) fail("duplicate-authority topic: " topic)
        else if (topic_writer[topic] != writer) fail("conflicting-writer topic: " topic)
        else fail("duplicate topic row: " topic)
      } else {
        topic_seen[topic] = 1
        topic_authority[topic] = authority
        topic_writer[topic] = writer
      }
      if (id in id_seen) fail("duplicate matrix id: " id)
      id_seen[id] = 1
      n = split(consumers, names, /;/)
      for (i = 1; i <= n; i++) {
        name = trim(names[i])
        if (name !~ /^[A-Za-z0-9-]+\.md\.tmpl$/) fail("invalid template consumer for " topic ": " name)
        expected_ref[name, id] = 1
        template_seen[name] = 1
      }
    }
    END {
      if (rows != 6) fail("expected six authority topics; found " rows)
      for (id in expected_topic) if (!(expected_topic[id] in topic_seen)) fail("missing topic: " expected_topic[id])
      for (file in template_seen) {
        path = template_root "/" file
        while ((getline line < path) > 0) {
          rest = line
          while (match(rest, /AW-[0-9][0-9]/)) {
            ref = substr(rest, RSTART, RLENGTH)
            if (!(ref in expected_topic)) fail("unknown template reference " ref " in " file)
            else if (!expected_ref[file, ref]) fail("undeclared template reference " ref " in " file)
            actual_ref[file, ref] = 1
            rest = substr(rest, RSTART + RLENGTH)
          }
        }
        close(path)
      }
      for (pair in expected_ref) {
        split(pair, parts, SUBSEP)
        if (!actual_ref[parts[1], parts[2]]) fail("missing template reference " parts[2] " in " parts[1])
      }
      if (!failed) print "authority-matrix: PASS: six topics and template references agree"
      exit failed ? 1 : 0
    }
  ' "$1"
}

suite_authority_matrix() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='authority-matrix'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/authority-matrix
  mkdir -p "$D"
  MATRIX="$PKG_ROOT/references/protocol/read-policy.md"

  if authority_matrix_check "$MATRIX" >"$D/valid.out" 2>&1; then
    ok 'unique-authority 正例：六组 authority/writer/resolution 与模板引用逐项一致'
  else
    bad 'unique-authority 正例：六组 authority/writer/resolution 与模板引用逐项一致' "$(cat "$D/valid.out")"
  fi

  # 目标类正例：用户决策定义目标状态；生成输入仅在用户未明确决定处降级到既有事实取信，
  # 且用户已明确决定不被旧事实或模板静默覆盖（票 214 两套顺序拆分）。
  if grep -q '用户决策定义目标状态' "$MATRIX" &&
    grep -q '既有事实 > 模板 > 自动推断' "$MATRIX" &&
    grep -q '不因旧事实或模板静默改写' "$MATRIX"; then
    ok 'target-precedence 正例：用户决策定义目标，用户已明确决定不被旧事实或模板静默覆盖'
  else
    bad 'target-precedence 正例：用户决策定义目标，用户已明确决定不被旧事实或模板静默覆盖' 'read-policy.md 缺目标类拆分表述（目标定义句/降级阶梯/静默覆盖禁令）'
  fi

  # 状态类正例：运行事实以实际文件、测试与 Git 观察为准（当前状态权威），AW-01 行
  # 目标/状态两半句在场；用户意图不得把运行事实写成已完成状态（票 214）。
  aw01_row=$(grep '^| AW-01 |' "$MATRIX")
  if printf '%s\n' "$aw01_row" | grep -q '用户决定以用户原始决定为权威' &&
    printf '%s\n' "$aw01_row" | grep -q '运行事实以实际文件、测试与 Git 观察为准' &&
    grep -q '实际文件、测试与 Git 观察定义当前状态' "$MATRIX"; then
    ok 'state-facts 正例：AW-01 用户决定＝目标权威、运行事实＝当前状态权威两分在场'
  else
    bad 'state-facts 正例：AW-01 用户决定＝目标权威、运行事实＝当前状态权威两分在场' 'read-policy.md 缺状态类拆分表述或 AW-01 行目标/状态两半句缺失'
  fi

  cp "$MATRIX" "$D/duplicate-authority.md"
  grep '^| AW-01 |' "$MATRIX" | sed 's/用户决定以用户原始决定为权威/重复来源为权威/' >> "$D/duplicate-authority.md"
  if authority_matrix_check "$D/duplicate-authority.md" >"$D/duplicate.out" 2>&1; then
    bad 'duplicate-authority 负例：必须拒绝并指名冲突主题' '变异矩阵意外通过'
  elif grep -q 'duplicate-authority topic: user-decision-runtime-facts' "$D/duplicate.out"; then
    ok 'duplicate-authority 负例：拒绝并指名 user-decision-runtime-facts'
  else
    bad 'duplicate-authority 负例：必须拒绝并指名冲突主题' "$(cat "$D/duplicate.out")"
  fi

  cp "$MATRIX" "$D/conflicting-writer.md"
  grep '^| AW-01 |' "$MATRIX" | sed 's/用户作决定；Triage 记录决定；产生运行证据的阶段角色记录其实际观察/其他角色写入该主题/' >> "$D/conflicting-writer.md"
  if authority_matrix_check "$D/conflicting-writer.md" >"$D/writer.out" 2>&1; then
    bad 'conflicting-writer 负例：必须拒绝并指名冲突主题' '变异矩阵意外通过'
  elif grep -q 'conflicting-writer topic: user-decision-runtime-facts' "$D/writer.out"; then
    ok 'conflicting-writer 负例：拒绝并指名 user-decision-runtime-facts'
  else
    bad 'conflicting-writer 负例：必须拒绝并指名冲突主题' "$(cat "$D/writer.out")"
  fi

  suite_summary 'authority-matrix'
}
