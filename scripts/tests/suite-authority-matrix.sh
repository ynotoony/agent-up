#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite authority-matrix "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


authority_matrix_check() {
  # $1=矩阵文件 $2=（可选）模板根：缺省取包内 templates（负例夹具用临时副本根）
  awk -F'|' -v template_root="${2:-$PKG_ROOT/references/templates}" '
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
        template_seen[name] = 1
      }
    }
    END {
      if (rows != 6) fail("expected six authority topics; found " rows)
      for (id in expected_topic) if (!(expected_topic[id] in topic_seen)) fail("missing topic: " expected_topic[id])
      # 安装面收敛后 authority/writer 事实的唯一承载点＝生成物 rules/project.md §12.5 写入所有权
      # 矩阵；声明为消费者的模板须指向该矩阵（每件至少一处），且不得再引用未安装的
      # read-policy.md 或其 AW-0x 编号（悬空指针防复发，与 governance-size 套件同口径）。
      for (file in template_seen) {
        path = template_root "/" file
        ptr = 0
        while ((getline line < path) > 0) {
          if (index(line, "§12.5") > 0) ptr++
          if (line ~ /AW-0[0-9]/ || index(line, "read-policy") > 0) fail("dangling manual pointer in " file ": " line)
        }
        close(path)
        if (ptr == 0) fail("missing §12.5 authority pointer in " file)
      }
      if (!failed) print "authority-matrix: PASS: six topics and §12.5 pointers agree"
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
    ok 'unique-authority 正例：六组 authority/writer/resolution 与消费者模板 §12.5 指针一致'
  else
    bad 'unique-authority 正例：六组 authority/writer/resolution 与消费者模板 §12.5 指针一致' "$(cat "$D/valid.out")"
  fi

  # 负例：消费者模板删去 §12.5 指针 → 必须 fail 并指名缺指针件
  cp -R "$PKG_ROOT/references/templates" "$D/tpl-no125"
  grep -v '§12.5' "$D/tpl-no125/agents-triage.md.tmpl" > "$D/no125.tmp" \
    && mv "$D/no125.tmp" "$D/tpl-no125/agents-triage.md.tmpl"
  if authority_matrix_check "$MATRIX" "$D/tpl-no125" >"$D/no125.out" 2>&1; then
    bad 'negative-no-pointer 负例：消费者模板缺 §12.5 指针 → 必须拒绝' '变异模板意外通过'
  elif grep -q 'missing §12.5 authority pointer in agents-triage.md.tmpl' "$D/no125.out"; then
    ok 'negative-no-pointer 负例：消费者模板缺 §12.5 指针 → 拒绝并指名模板'
  else
    bad 'negative-no-pointer 负例：消费者模板缺 §12.5 指针 → 必须拒绝' "$(head -n 2 "$D/no125.out" | tr '\n' '|')"
  fi
  # 负例：消费者模板回填未安装手册指针 → 必须 fail 并指名悬空指针
  cp -R "$PKG_ROOT/references/templates" "$D/tpl-dangling"
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  printf '\n- 悬空指针夹具：见 `references/protocol/read-policy.md` §2.3.1 AW-04。\n' >> "$D/tpl-dangling/agents-review.md.tmpl"
  if authority_matrix_check "$MATRIX" "$D/tpl-dangling" >"$D/dang.out" 2>&1; then
    bad 'negative-dangling 负例：模板回填 read-policy 指针 → 必须拒绝' '变异模板意外通过'
  elif grep -q 'dangling manual pointer in agents-review.md.tmpl' "$D/dang.out"; then
    ok 'negative-dangling 负例：模板回填 read-policy 指针 → 拒绝并指名悬空行'
  else
    bad 'negative-dangling 负例：模板回填 read-policy 指针 → 必须拒绝' "$(head -n 2 "$D/dang.out" | tr '\n' '|')"
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
