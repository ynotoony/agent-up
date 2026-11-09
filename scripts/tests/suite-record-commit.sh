#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite record-commit "$@"
  exit $?
fi
# Input: 同目录 record-commit.sh、common-helpers.sh；夹具在 mktemp 临时目录内 git init
#        （只追加账本基线＋产品文件＋未改动记录文件），全部经独立入口调用。
# Output: 逐项 PASS/FAIL 行与计数汇总；夹具全部 mktemp 并 trap 清理，真实仓库零写入。
# Pos: 记录提交单点入口回归（票 288）：独立调用正例（尾部追加、提交文件集恰为记录路径、
#      输出前缀可指定）＋负例（中间插入零提交报行号、产品路径/部分暂存/缺失路径拒绝）＋
#      成功后 check-append-only 同源通过；证明迁出后独立入口仍可单点行使（AC1）。
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

suite_record_commit() {
  CUR_SUITE='record-commit'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/rcu
  mkdir -p "$D"
  RCU="$SCRIPT_DIR/record-commit.sh"
  [ -r "$RCU" ] || { bad 'record-commit.sh 在场' "缺件: $RCU"; suite_summary 'record-commit'; return 0; }

  rcu_fixture() {
    # $1=夹具仓根：只追加账本三行基线＋未改动记录文件＋产品文件 a.txt（干净工作区）
    R=$1
    rm -rf "$R"
    mkdir -p "$R/facts/project"
    printf 'l1\nl2\nl3\n' > "$R/facts/project/changes.jsonl"
    printf 'o1\n' > "$R/facts/project/other.jsonl"
    printf 'product\n' > "$R/a.txt"
    git_repo "$R"
    git -C "$R" -c user.email=fixture@example.com -c user.name=fixture add -A
    git -C "$R" -c user.email=fixture@example.com -c user.name=fixture commit -qm seed
  }
  rcu_count() { git -C "$1" rev-list --count HEAD; }
  rcu_head_files() { git -C "$1" diff-tree --root --no-commit-id --name-only -r HEAD; }

  # P1：独立调用（无 lane-commit 参与）尾部追加 → exit 0，输出前缀 record-commit，提交文件集恰为账本。
  rcu_fixture "$D/p1"
  printf 'l1\nl2\nl3\nl4\n' > "$D/p1/facts/project/changes.jsonl"
  sh "$RCU" "$D/p1" 'chore: rcu 尾部追加' facts/project/changes.jsonl > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rcu_head_files "$D/p1")" = 'facts/project/changes.jsonl' ] \
    && grep -q '^record-commit: 记录提交门: 同锁串行（锁目录 ' "$D/p1.out" \
    && grep -q '^record-commit: 记录提交 [0-9a-f]\{7,\}$' "$D/p1.out" \
    && grep -q '^record-commit: 记录文件: facts/project/changes.jsonl$' "$D/p1.out" \
    && [ ! -e "$D/p1/.git/agent-up-record.lock" ]; then
    ok '正例 RCU-P1 独立入口尾部追加 → exit 0、输出前缀 record-commit、提交文件集恰为记录路径、锁无残留'
  else
    bad '正例 RCU-P1 独立入口尾部追加 → exit 0、输出前缀 record-commit、提交文件集恰为记录路径、锁无残留' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # P2：--name lane-commit 保留 lane-commit 兼容输出行（迁出前后逐字一致的接缝）。
  rcu_fixture "$D/p2"
  printf 'l1\nl2\nl3\nl4\n' > "$D/p2/facts/project/changes.jsonl"
  sh "$RCU" --name lane-commit "$D/p2" 'chore: rcu 前缀' facts/project/changes.jsonl > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '^lane-commit: 记录提交门: 同锁串行（锁目录 ' "$D/p2.out" \
    && grep -q '^lane-commit: 记录提交 [0-9a-f]\{7,\}$' "$D/p2.out" \
    && grep -q '^lane-commit: 记录文件: facts/project/changes.jsonl$' "$D/p2.out"; then
    ok '正例 RCU-P2 --name 指定前缀 → 输出行前缀随迁出前 lane-commit 口径（输出语义不变）'
  else
    bad '正例 RCU-P2 --name 指定前缀 → 输出行前缀随迁出前 lane-commit 口径（输出语义不变）' "exit=$rc $(tail -n 3 "$D/p2.out" | tr '\n' '|')"
  fi

  # N1：HEAD→待提交中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写。
  rcu_fixture "$D/n1"
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/n1/facts/project/changes.jsonl"
  n1_before=$(rcu_count "$D/n1")
  sh "$RCU" "$D/n1" 'chore: rcu 中间插入' facts/project/changes.jsonl > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'HEAD 旧内容非待提交版本前缀' "$D/n1.out" \
    && grep -Fq '首个违规行号 2（待提交版行号）' "$D/n1.out" \
    && [ "$(rcu_count "$D/n1")" -eq "$n1_before" ] \
    && [ "$(cat "$D/n1/facts/project/changes.jsonl")" = 'l1
INSERT
l2
l3' ]; then
    ok '负例 RCU-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写'
  else
    bad '负例 RCU-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写' "exit=$rc $(tail -n 3 "$D/n1.out" | tr '\n' '|')"
  fi

  # N2：产品路径作为记录路径 → 记录面白名单拒绝、零提交。
  rcu_fixture "$D/n2"
  printf 'changed\n' > "$D/n2/a.txt"
  n2_before=$(rcu_count "$D/n2")
  sh "$RCU" "$D/n2" 'chore: rcu 产品路径' a.txt > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '不在 facts/ 记录面内' "$D/n2.out" \
    && [ "$(rcu_count "$D/n2")" -eq "$n2_before" ]; then
    ok '负例 RCU-N2 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交'
  else
    bad '负例 RCU-N2 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交' "exit=$rc $(tail -n 3 "$D/n2.out" | tr '\n' '|')"
  fi

  # N3：暂存 l1..l4 后工作区再追加 l5（部分暂存）→ exit 1 报首个差异行 5、零提交。
  rcu_fixture "$D/n3"
  printf 'l1\nl2\nl3\nl4\n' > "$D/n3/facts/project/changes.jsonl"
  git -C "$D/n3" add facts/project/changes.jsonl
  printf 'l1\nl2\nl3\nl4\nl5\n' > "$D/n3/facts/project/changes.jsonl"
  n3_before=$(rcu_count "$D/n3")
  sh "$RCU" "$D/n3" 'chore: rcu 部分暂存' facts/project/changes.jsonl > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '部分暂存，首个差异行 5' "$D/n3.out" \
    && [ "$(rcu_count "$D/n3")" -eq "$n3_before" ]; then
    ok '负例 RCU-N3 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交'
  else
    bad '负例 RCU-N3 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交' "exit=$rc $(tail -n 3 "$D/n3.out" | tr '\n' '|')"
  fi

  # N4：记录路径在工作树被删除 → exit 1 指名不存在、零提交。
  rcu_fixture "$D/n4"
  rm -f "$D/n4/facts/project/changes.jsonl"
  n4_before=$(rcu_count "$D/n4")
  sh "$RCU" "$D/n4" 'chore: rcu 缺失路径' facts/project/changes.jsonl > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '记录路径在工作树不存在: facts/project/changes.jsonl' "$D/n4.out" \
    && [ "$(rcu_count "$D/n4")" -eq "$n4_before" ]; then
    ok '负例 RCU-N4 记录路径缺失 → exit 1 指名不存在、零提交'
  else
    bad '负例 RCU-N4 记录路径缺失 → exit 1 指名不存在、零提交' "exit=$rc $(tail -n 3 "$D/n4.out" | tr '\n' '|')"
  fi

  # P3：成功后 check-append-only 同源通过（记录提交语义与只追加守卫一致）。
  sh "$SCRIPT_DIR/check-append-only.sh" "$D/p1" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -Fq 'check-append-only: PASS' "$D/p3.out"; then
    ok '正例 RCU-P3 记录提交成功后 check-append-only → exit 0 PASS（与只追加守卫同源）'
  else
    bad '正例 RCU-P3 记录提交成功后 check-append-only → exit 0 PASS（与只追加守卫同源）' "exit=$rc $(tail -n 3 "$D/p3.out" | tr '\n' '|')"
  fi

  suite_summary 'record-commit'
}
