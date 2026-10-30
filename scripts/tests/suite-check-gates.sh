#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite check-gates "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: check-gates（票 245 场景沉淀：验证命令执行边界）
# 覆盖：verify 前后完整快照（跟踪文件内容、未跟踪/忽略文件、目录、符号链接、
# 索引与 HEAD）——新建未跟踪文件、删除跟踪文件、修改索引、创建符号链接、
# 改写已修改文件（status 行不变）五类越界均 exit 1 并指名路径；allow-output
# 目录内产物放行且原工作区只保留合同白名单内改动；allow-output 含跟踪文件
# 拒绝配置 exit 2；record-only 既有语义不变。夹具全部 mktemp，仓库零写入。
# ============================================================

cg_git() {
  # $1=夹具仓根；其余为 git 子命令（本地身份经 -c 内联，零全局污染）
  _cg_repo=$1
  shift
  git -C "$_cg_repo" -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false "$@"
}

cg_make_repo() {
  # $1=夹具仓根：一个跟踪文件 a.txt 的初始提交＋工作区已修改态（合同白名单内改动）
  _cg_r=$1
  rm -rf "$_cg_r"
  mkdir -p "$_cg_r"
  git -C "$_cg_r" init -q
  printf 'seed\n' > "$_cg_r/a.txt"
  cg_git "$_cg_r" add a.txt
  cg_git "$_cg_r" commit -qm fixture
  printf 'change\n' > "$_cg_r/a.txt"
}

cg_run_gate() {
  # $1=输出文件 $2=夹具仓根 $3=门禁清单
  sh "$SCRIPT_DIR/check-gates.sh" "$2" "$3" > "$1" 2>&1
}

suite_check_gates() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='check-gates'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/cg
  mkdir -p "$D"
  CG="$SCRIPT_DIR/check-gates.sh"
  [ -r "$CG" ] || { bad 'check-gates.sh 在场' "缺件: $CG"; suite_summary 'check-gates'; return 0; }

  # 正例 P1：合法只读验证 → exit 0，既有 PASS 行与汇总行格式保持。
  cg_make_repo "$D/p1"
  cat > "$D/p1.gates" <<'EOF'
whitelist: a.txt
verify: test -f a.txt
EOF
  cg_run_gate "$D/p1.out" "$D/p1" "$D/p1.gates"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -Fq 'PASS: 改动 a.txt（在白名单内）' "$D/p1.out" \
    && grep -Fq 'PASS: verify[1] exit=0 test -f a.txt' "$D/p1.out" \
    && grep -Fq 'check-gates: PASS（改动 1 项全部在白名单内，verify 1 条全部通过）' "$D/p1.out"; then
    ok '正例 P1 合法验证 → exit 0 且既有 PASS/汇总行格式保持'
  else
    bad '正例 P1 合法验证 → exit 0 且既有 PASS/汇总行格式保持' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # 负例 N1：验证命令新建未跟踪文件 → exit 1、指名文件、保持现场、后续命令不执行。
  cg_make_repo "$D/n1"
  cat > "$D/n1.gates" <<'EOF'
whitelist: a.txt
verify: printf injected > injected.txt
verify: printf second > second.txt
EOF
  cg_run_gate "$D/n1.out" "$D/n1" "$D/n1.gates"
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'FAIL: verify[1] 越界改动工作区 1 项（新增 1／删除 0／变更 0）' "$D/n1.out" \
    && grep -Fq '  失败命令: printf injected > injected.txt' "$D/n1.out" \
    && grep -Fq '    + injected.txt' "$D/n1.out" \
    && grep -Fq '  前后状态差异（前 -／后 +）:' "$D/n1.out" \
    && grep -Fq 'SKIP: verify[2] 未执行（前序验证越界改动工作区，就地停止） printf second > second.txt' "$D/n1.out" \
    && [ -f "$D/n1/injected.txt" ] && [ ! -e "$D/n1/second.txt" ]; then
    ok '负例 N1 新建未跟踪文件 → exit 1 指名文件、保持现场、后续验证不执行'
  else
    bad '负例 N1 新建未跟踪文件 → exit 1 指名文件、保持现场、后续验证不执行' "exit=$rc $(grep -E 'FAIL|SKIP|injected' "$D/n1.out" | head -n 3 | tr '\n' '|')"
  fi

  # 负例 N2：验证命令删除跟踪文件 → exit 1 且按删除类指名。
  cg_make_repo "$D/n2"
  cat > "$D/n2.gates" <<'EOF'
whitelist: a.txt
verify: rm a.txt
EOF
  cg_run_gate "$D/n2.out" "$D/n2" "$D/n2.gates"
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'FAIL: verify[1] 越界改动工作区 1 项（新增 0／删除 1／变更 0）' "$D/n2.out" \
    && grep -Fq '  异常路径（删除 1 项）:' "$D/n2.out" \
    && grep -Fq '    - a.txt' "$D/n2.out"; then
    ok '负例 N2 删除跟踪文件 → exit 1 且指名 a.txt'
  else
    bad '负例 N2 删除跟踪文件 → exit 1 且指名 a.txt' "exit=$rc $(tail -n 3 "$D/n2.out" | tr '\n' '|')"
  fi

  # 负例 N3：验证命令修改索引（git add）→ exit 1（工作区行未变，索引行变化）。
  cg_make_repo "$D/n3"
  cat > "$D/n3.gates" <<'EOF'
whitelist: a.txt
verify: git add a.txt
EOF
  cg_run_gate "$D/n3.out" "$D/n3" "$D/n3.gates"
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '  异常路径（变更 1 项）:' "$D/n3.out" \
    && grep -Eq '^    - a\.txt	I	100644 [0-9a-f]+ 0$' "$D/n3.out" \
    && grep -Eq '^    \+ a\.txt	I	100644 [0-9a-f]+ 0$' "$D/n3.out"; then
    ok '负例 N3 修改索引（git add）→ exit 1 且指名索引条目前后状态'
  else
    bad '负例 N3 修改索引（git add）→ exit 1 且指名索引条目前后状态' "exit=$rc $(tail -n 5 "$D/n3.out" | tr '\n' '|')"
  fi

  # 负例 N4：验证命令创建符号链接 → exit 1 且指名链接路径。
  cg_make_repo "$D/n4"
  cat > "$D/n4.gates" <<'EOF'
whitelist: a.txt
verify: ln -s a.txt link
EOF
  cg_run_gate "$D/n4.out" "$D/n4" "$D/n4.gates"
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '  异常路径（新增 1 项）:' "$D/n4.out" \
    && grep -Fq '    + link' "$D/n4.out" \
    && grep -Fq 'link	L	symlink:' "$D/n4.out"; then
    ok '负例 N4 创建符号链接 → exit 1 且指名 link（符号链接目标哈希）'
  else
    bad '负例 N4 创建符号链接 → exit 1 且指名 link（符号链接目标哈希）' "exit=$rc $(tail -n 4 "$D/n4.out" | tr '\n' '|')"
  fi

  # 负例 N5：改写「已被修改」的跟踪文件——git status 行前后不变，仍须经内容哈希检出。
  cg_make_repo "$D/n5"
  status_before=$(git -C "$D/n5" status --porcelain -uall)
  cat > "$D/n5.gates" <<'EOF'
whitelist: a.txt
verify: printf more >> a.txt
EOF
  cg_run_gate "$D/n5.out" "$D/n5" "$D/n5.gates"
  rc=$?
  status_after=$(git -C "$D/n5" status --porcelain -uall)
  if [ "$rc" -eq 1 ] && [ "$status_before" = "$status_after" ] \
    && grep -Fq '  异常路径（变更 1 项）:' "$D/n5.out" \
    && grep -Eq '^    - a\.txt	F	644:[0-9a-f]+$' "$D/n5.out" \
    && grep -Eq '^    \+ a\.txt	F	644:[0-9a-f]+$' "$D/n5.out"; then
    ok '负例 N5 改写已修改文件（status 行不变）→ exit 1 经内容哈希检出'
  else
    bad '负例 N5 改写已修改文件（status 行不变）→ exit 1 经内容哈希检出' "exit=$rc status='$status_after' $(tail -n 3 "$D/n5.out" | tr '\n' '|')"
  fi

  # 正例 P2：allow-output 目录内产出合法 → exit 0，原工作区只保留合同白名单内改动。
  cg_make_repo "$D/p2"
  cat > "$D/p2.gates" <<'EOF'
whitelist: a.txt
allow-output: build
verify: mkdir -p build && printf artifact > build/out.txt
EOF
  cg_run_gate "$D/p2.out" "$D/p2" "$D/p2.gates"
  rc=$?
  status_p2=$(git -C "$D/p2" status --porcelain -uall)
  if [ "$rc" -eq 0 ] \
    && grep -Fq 'PASS: verify[1] exit=0 mkdir -p build && printf artifact > build/out.txt' "$D/p2.out" \
    && grep -Fq 'check-gates: PASS（改动 1 项全部在白名单内，verify 1 条全部通过）' "$D/p2.out" \
    && [ -f "$D/p2/build/out.txt" ] \
    && [ "$status_p2" = ' M a.txt
?? build/out.txt' ]; then
    ok '正例 P2 allow-output 内产出 → exit 0 且工作区只留白名单改动与允许输出'
  else
    bad '正例 P2 allow-output 内产出 → exit 0 且工作区只留白名单改动与允许输出' "exit=$rc status='$status_p2' $(tail -n 2 "$D/p2.out" | tr '\n' '|')"
  fi

  # 正例 P3：allow-output 内既有未跟踪产物在下次门禁中被视为合法输出，不要求进白名单。
  cg_run_gate "$D/p2b.out" "$D/p2" "$D/p2.gates"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -Fq 'PASS: 改动 build/out.txt（在允许输出目录内）' "$D/p2b.out" \
    && grep -Fq 'check-gates: PASS（改动 2 项全部在白名单内，verify 1 条全部通过）' "$D/p2b.out"; then
    ok '正例 P3 allow-output 既有产物复跑 → exit 0 且按允许输出放行'
  else
    bad '正例 P3 allow-output 既有产物复跑 → exit 0 且按允许输出放行' "exit=$rc $(tail -n 2 "$D/p2b.out" | tr '\n' '|')"
  fi

  # 负例 N6：allow-output 目录含跟踪文件 → 配置错误 exit 2（白名单只放行未跟踪产物）。
  cg_make_repo "$D/n6"
  mkdir -p "$D/n6/out"
  printf 'tracked\n' > "$D/n6/out/tracked.txt"
  cg_git "$D/n6" add out/tracked.txt
  cg_git "$D/n6" commit -qm tracked-output
  printf 'change\n' > "$D/n6/a.txt"
  cat > "$D/n6.gates" <<'EOF'
whitelist: a.txt
allow-output: out
verify: true
EOF
  cg_run_gate "$D/n6.out" "$D/n6" "$D/n6.gates"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -Fq 'allow-output 目录含已跟踪文件，拒绝配置（输出白名单只允许未跟踪产物）: out' "$D/n6.out"; then
    ok '负例 N6 allow-output 含跟踪文件 → exit 2 拒绝配置'
  else
    bad '负例 N6 allow-output 含跟踪文件 → exit 2 拒绝配置' "exit=$rc $(tail -n 2 "$D/n6.out" | tr '\n' '|')"
  fi

  # 负例 N7：allow-output 路径含 .. → exit 2 fail-closed。
  cg_make_repo "$D/n7"
  cat > "$D/n7.gates" <<'EOF'
whitelist: a.txt
allow-output: ../escaped
verify: true
EOF
  cg_run_gate "$D/n7.out" "$D/n7" "$D/n7.gates"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -Fq 'allow-output 不得含 .. 路径段: ../escaped' "$D/n7.out"; then
    ok '负例 N7 allow-output 路径含 .. → exit 2 fail-closed'
  else
    bad '负例 N7 allow-output 路径含 .. → exit 2 fail-closed' "exit=$rc $(tail -n 2 "$D/n7.out" | tr '\n' '|')"
  fi

  # 正例 P4：record-only + verify N/A 既有语义不变（不触发快照）。
  cg_make_repo "$D/p4"
  cat > "$D/p4.gates" <<'EOF'
whitelist: a.txt
record-only: 纯记录索引更新
verify: N/A
EOF
  cg_run_gate "$D/p4.out" "$D/p4" "$D/p4.gates"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -Fq 'check-gates: PASS（纯记录例外：纯记录索引更新；改动 1 项全部在白名单内，verify N/A）' "$D/p4.out"; then
    ok '正例 P4 record-only + verify N/A 语义不变'
  else
    bad '正例 P4 record-only + verify N/A 语义不变' "exit=$rc $(tail -n 2 "$D/p4.out" | tr '\n' '|')"
  fi

  suite_summary 'check-gates'
}
