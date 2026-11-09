#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite lane-commit-record "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: lane-commit-record（票 291 自 suite-lane-commit 拆出的记录提交能力面）：
# 票 247 记录提交前缀门（--record-commit 单点入口）——中间插入报首行号、部分暂存拒绝、
# 混提/产品路径拒绝、同锁并发串行、check-append-only 同源与 README 登记断言。

suite_lane_commit_record() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='lane-commit-record'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/lcr
  mkdir -p "$D"
  LC="$SCRIPT_DIR/lane-commit.sh"

  # ---- 票 247 断言：记录提交前缀门（--record-commit 单点入口）----
  # AC1 中间插入拒绝并报首行号；AC2 部分暂存拒绝零提交；AC3 尾部追加仅提交记录路径、
  # 混提/产品路径拒绝；AC4 同锁并发提交最终前缀成立（含陈旧快照拒绝负例）；AC5 成功后
  # check-append-only 同源通过；AC6 README 登记入口与失败语义。
  # 评审修复（D1–D5）：D1 断言对象＝私有索引写出的树（窗口内共享索引被并发暂存不卷入、
  # 并发暂存保留现场）；D2 文件集核对前移到 write-tree 后、commit 前；D3 并发同步点＝
  # RECORD_COMMIT_TEST_MARKER 标记文件（HOLD 仅放大窗口，非同步手段）；D4 未改动记录
  # 路径显式列为已排除；D5 工作树缺失记录路径指名拒绝。
  rc_fixture() {
    # $1=夹具仓根：只追加账本三行基线＋未改动记录文件＋产品文件 a.txt（干净工作区）
    R=$1
    rm -rf "$R"
    mkdir -p "$R/facts/project"
    printf 'l1\nl2\nl3\n' > "$R/facts/project/changes.jsonl"
    printf 'o1\n' > "$R/facts/project/other.jsonl"
    printf 'product\n' > "$R/a.txt"
    git_repo "$R"
    lc_git_commit "$R"
  }

  rc_expect() {
    # $1=实际文件 $2=printf %b 口径期望内容：逐字节比较
    printf '%b' "$2" > "$D/rc-expect.txt"
    cmp -s "$1" "$D/rc-expect.txt"
  }

  rc_count() { git -C "$1" rev-list --count HEAD; }

  rc_head_files() { git -C "$1" diff-tree --root --no-commit-id --name-only -r HEAD; }

  rc_lock_absent() { [ ! -e "$1/.git/agent-up-record.lock" ]; }

  rc_readme_documented() {
    # $1=README 路径：入口用法、失败零提交、首个违规行号三要素须在场
    grep -Fq -- '--record-commit' "$1" \
      && grep -Fq '零提交' "$1" \
      && grep -Fq '首个违规行号' "$1"
  }

  # AC1＋AC3 正例：合法尾部追加 → exit 0、提交文件集恰为账本、锁无残留。
  rc_fixture "$D/rc-ac1"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac1/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac1" 'chore: rc247 尾部追加' facts/project/changes.jsonl >"$D/rc-ac1-p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac1")" = 'facts/project/changes.jsonl' ] \
    && rc_lock_absent "$D/rc-ac1" \
    && grep -q 'lane-commit: 记录提交门: 同锁串行（锁目录 ' "$D/rc-ac1-p.out"; then
    ok '正例 247-P1 账本尾部追加 → exit 0、提交文件集恰为记录路径、锁无残留（票 247 AC3）'
  else
    bad '正例 247-P1 账本尾部追加 → exit 0、提交文件集恰为记录路径、锁无残留（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac1-p.out" | tr '\n' '|')"
  fi

  # AC1 负例：HEAD→待提交中间插入 → exit 1 报首个违规行号（待提交版行号），零提交、
  # 工作区内容零回滚改写。
  rc_fixture "$D/rc-ac1n"
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac1n/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac1n")
  sh "$LC" --record-commit "$D/rc-ac1n" 'chore: rc247 中间插入' facts/project/changes.jsonl >"$D/rc-ac1n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'HEAD 旧内容非待提交版本前缀' "$D/rc-ac1n.out" \
    && grep -Fq '首个违规行号 2（待提交版行号）' "$D/rc-ac1n.out" \
    && [ "$(rc_count "$D/rc-ac1n")" -eq "$rc_n0" ] \
    && rc_expect "$D/rc-ac1n/facts/project/changes.jsonl" 'l1\nINSERT\nl2\nl3\n'; then
    ok '负例 247-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写（票 247 AC1）'
  else
    bad '负例 247-N1 账本中间插入 → exit 1 报首个违规行号 2、零提交、工作区零改写（票 247 AC1）' "exit=$rc $(tail -n 3 "$D/rc-ac1n.out" | tr '\n' '|')"
  fi

  # AC1 负例二（D1）：调用前另一会话已把中间插入版放进共享索引（工作区同版本，故不触发
  # 部分暂存预检）→ 私有索引仍按工作区内容断言并拒绝，零提交。
  rc_fixture "$D/rc-ac1n2"
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac1n2/facts/project/changes.jsonl"
  git -C "$D/rc-ac1n2" add facts/project/changes.jsonl
  rc_n0=$(rc_count "$D/rc-ac1n2")
  sh "$LC" --record-commit "$D/rc-ac1n2" 'chore: rc247 共享索引中间插入' facts/project/changes.jsonl >"$D/rc-ac1n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq 'HEAD 旧内容非待提交版本前缀' "$D/rc-ac1n2.out" \
    && grep -Fq '首个违规行号 2（待提交版行号）' "$D/rc-ac1n2.out" \
    && [ "$(rc_count "$D/rc-ac1n2")" -eq "$rc_n0" ]; then
    ok '负例 247-N1b 共享索引含中间插入版 → 私有索引断言拒绝、exit 1、零提交（票 247 D1）'
  else
    bad '负例 247-N1b 共享索引含中间插入版 → 私有索引断言拒绝、exit 1、零提交（票 247 D1）' "exit=$rc $(tail -n 3 "$D/rc-ac1n2.out" | tr '\n' '|')"
  fi

  # AC2 正例：仅工作区改动（未暂存）→ 入口自行暂存后提交成功。
  rc_fixture "$D/rc-ac2p"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac2p/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac2p" 'chore: rc247 未暂存改动' facts/project/changes.jsonl >"$D/rc-ac2p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(rc_count "$D/rc-ac2p")" -eq 2 ]; then
    ok '正例 247-P2 仅工作区改动 → exit 0 入口自行暂存并提交（票 247 AC2 对照）'
  else
    bad '正例 247-P2 仅工作区改动 → exit 0 入口自行暂存并提交（票 247 AC2 对照）' "exit=$rc $(tail -n 3 "$D/rc-ac2p.out" | tr '\n' '|')"
  fi

  # AC2 负例：暂存 l1..l4 后工作区再追加 l5（部分暂存）→ exit 1 报首个差异行、零提交。
  rc_fixture "$D/rc-ac2n"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac2n/facts/project/changes.jsonl"
  git -C "$D/rc-ac2n" add facts/project/changes.jsonl
  printf 'l1\nl2\nl3\nl4\nl5\n' > "$D/rc-ac2n/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac2n")
  sh "$LC" --record-commit "$D/rc-ac2n" 'chore: rc247 部分暂存' facts/project/changes.jsonl >"$D/rc-ac2n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '部分暂存，首个差异行 5' "$D/rc-ac2n.out" \
    && [ "$(rc_count "$D/rc-ac2n")" -eq "$rc_n0" ]; then
    ok '负例 247-N2 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交（票 247 AC2）'
  else
    bad '负例 247-N2 暂存与工作区不一致 → exit 1 报首个差异行 5、零提交（票 247 AC2）' "exit=$rc $(tail -n 3 "$D/rc-ac2n.out" | tr '\n' '|')"
  fi

  # AC3 正例：产品改动未暂存＋账本尾部追加 → 提交仅账本，产品仍留工作区未提交。
  rc_fixture "$D/rc-ac3p"
  printf 'product-changed\n' > "$D/rc-ac3p/a.txt"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3p/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3p" 'chore: rc247 只提交记录' facts/project/changes.jsonl >"$D/rc-ac3p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3p")" = 'facts/project/changes.jsonl' ] \
    && [ "$(git -C "$D/rc-ac3p" diff --name-only)" = 'a.txt' ]; then
    ok '正例 247-P3 产品改动未暂存 → 提交文件集恰为账本、产品文件不入提交（票 247 AC3）'
  else
    bad '正例 247-P3 产品改动未暂存 → 提交文件集恰为账本、产品文件不入提交（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac3p.out" | tr '\n' '|')"
  fi

  # AC3 正例二（D1）：A 持锁窗口内另一会话把中间插入版写到工作区并 git add（同时暂存
  # 产品文件）→ A 只提交自己私有索引快照的尾部追加版，共享索引的并发暂存保留现场。
  rc_fixture "$D/rc-ac3p2"
  rm -f "$D/rc-ac3p2.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac3p2/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac3p2.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac3p2" 'chore: rc247 隔离' facts/project/changes.jsonl >"$D/rc-ac3p2.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac3p2.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac3p2.marker" ]; then rc_marker=1; fi
  printf 'l1\nINSERT\nl2\nl3\n' > "$D/rc-ac3p2/facts/project/changes.jsonl"
  git -C "$D/rc-ac3p2" add facts/project/changes.jsonl
  printf 'product-staged\n' > "$D/rc-ac3p2/a.txt"
  git -C "$D/rc-ac3p2" add a.txt
  wait "$rc_a_pid"
  rc=$?
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac3p2.expected"
  if [ "$rc_marker" -eq 1 ] && [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3p2")" = 'facts/project/changes.jsonl' ] \
    && git -C "$D/rc-ac3p2" show HEAD:facts/project/changes.jsonl | cmp -s - "$D/rc-ac3p2.expected" \
    && [ "$(git -C "$D/rc-ac3p2" diff --cached --name-only | paste -sd, -)" = 'a.txt,facts/project/changes.jsonl' ]; then
    ok '正例 247-P3c 窗口内共享索引被并发暂存 → 提交仅含 A 的私有快照，并发暂存保留（票 247 D1）'
  else
    bad '正例 247-P3c 窗口内共享索引被并发暂存 → 提交仅含 A 的私有快照，并发暂存保留（票 247 D1）' "marker=$rc_marker exit=$rc head_files=$(rc_head_files "$D/rc-ac3p2" | paste -sd, -) staged=$(git -C "$D/rc-ac3p2" diff --cached --name-only | paste -sd, -) $(tail -n 2 "$D/rc-ac3p2.out" | tr '\n' '|')"
  fi

  # AC3 负例一：产品路径作为记录路径参数 → 记录面白名单拒绝、零提交。
  rc_fixture "$D/rc-ac3n1"
  printf 'product-changed\n' > "$D/rc-ac3n1/a.txt"
  rc_n0=$(rc_count "$D/rc-ac3n1")
  sh "$LC" --record-commit "$D/rc-ac3n1" 'chore: rc247 产品路径' a.txt >"$D/rc-ac3n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '不在 facts/ 记录面内' "$D/rc-ac3n1.out" \
    && [ "$(rc_count "$D/rc-ac3n1")" -eq "$rc_n0" ]; then
    ok '负例 247-N3a 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交（票 247 AC3）'
  else
    bad '负例 247-N3a 产品路径作记录路径 → exit 1 记录面白名单拒绝、零提交（票 247 AC3）' "exit=$rc $(tail -n 3 "$D/rc-ac3n1.out" | tr '\n' '|')"
  fi

  # AC3 负例二（D1 语义更新）：产品文件已暂存＋账本尾部追加 → 记录提交只含记录路径，
  # 产品暂存不卷入提交、保留现场（不回滚、不静默提交）。
  rc_fixture "$D/rc-ac3n2"
  printf 'product-staged\n' > "$D/rc-ac3n2/a.txt"
  git -C "$D/rc-ac3n2" add a.txt
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3n2/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3n2" 'chore: rc247 混提' facts/project/changes.jsonl >"$D/rc-ac3n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(rc_head_files "$D/rc-ac3n2")" = 'facts/project/changes.jsonl' ] \
    && [ "$(git -C "$D/rc-ac3n2" diff --cached --name-only)" = 'a.txt' ]; then
    ok '负例 247-N3b 产品已暂存＋记录追加 → 提交仅记录路径、产品暂存保留现场（票 247 D1）'
  else
    bad '负例 247-N3b 产品已暂存＋记录追加 → 提交仅记录路径、产品暂存保留现场（票 247 D1）' "exit=$rc $(tail -n 3 "$D/rc-ac3n2.out" | tr '\n' '|')"
  fi

  # AC3 负例三：记录路径含 `..` 归一化段（facts/../a.txt 指向产品文件）→ 文本层边界拒绝、
  # 零提交（记录提交入口复用票 144 路径边界，产品文件无法借归一化混入私有索引）。
  rc_fixture "$D/rc-ac3n3"
  printf 'product-staged\n' > "$D/rc-ac3n3/a.txt"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3n3/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac3n3")
  sh "$LC" --record-commit "$D/rc-ac3n3" 'chore: rc247 归一化混提' \
    facts/project/changes.jsonl facts/../a.txt >"$D/rc-ac3n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '不得含 .. 或 ./ 路径段' "$D/rc-ac3n3.out" \
    && [ "$(rc_count "$D/rc-ac3n3")" -eq "$rc_n0" ]; then
    ok '负例 247-N3c 记录路径含 .. 归一化段 → 边界拒绝、零提交（票 144 口径）'
  else
    bad '负例 247-N3c 记录路径含 .. 归一化段 → 边界拒绝、零提交（票 144 口径）' "exit=$rc $(tail -n 3 "$D/rc-ac3n3.out" | tr '\n' '|')"
  fi

  # AC4 正例：A 在提交窗口持锁（私有索引快照完成后写标记并 HOLD 放大窗口，B 以标记
  # 为同步事件），B 并发追加 → B 等锁、两条记录提交串行、B 父提交＝A、最终前缀成立。
  rc_fixture "$D/rc-ac4p"
  rm -f "$D/rc-ac4p.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac4p/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac4p.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac4p" 'chore: rc247 A' facts/project/changes.jsonl >"$D/rc-ac4p-a.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac4p.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac4p.marker" ]; then rc_marker=1; fi
  printf 'l1\nl2\nl3\na4\nb4\n' > "$D/rc-ac4p/facts/project/changes.jsonl"
  rc_b_start=$(date +%s)
  sh "$LC" --record-commit "$D/rc-ac4p" 'chore: rc247 B' facts/project/changes.jsonl >"$D/rc-ac4p-b.out" 2>&1
  rc_b=$?
  rc_b_elapsed=$(( $(date +%s) - rc_b_start ))
  wait "$rc_a_pid"
  rc_a=$?
  rc_a_cid=$(sed -n 's/^lane-commit: 记录提交 \([0-9a-f]\{7,\}\)$/\1/p' "$D/rc-ac4p-a.out" | tail -n 1)
  rc_b_cid=$(git -C "$D/rc-ac4p" rev-parse HEAD)
  if [ "$rc_marker" -eq 1 ] && [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 0 ] \
    && [ "$(rc_count "$D/rc-ac4p")" -eq 3 ] \
    && [ -n "$rc_a_cid" ] \
    && [ "$(git -C "$D/rc-ac4p" rev-parse HEAD^)" = "$rc_a_cid" ] \
    && [ "$rc_b_elapsed" -ge 1 ] \
    && rc_expect "$D/rc-ac4p/facts/project/changes.jsonl" 'l1\nl2\nl3\na4\nb4\n'; then
    ok "正例 247-P4 A 持锁提交期间 B 并发追加 → 串行提交（标记同步，B 等待 ${rc_b_elapsed}s，父提交＝A）、最终前缀成立（票 247 AC4）"
  else
    bad '正例 247-P4 A 持锁提交期间 B 并发追加 → 串行提交、最终前缀成立（票 247 AC4）' "marker=$rc_marker a=$rc_a b=$rc_b b_cid=$rc_b_cid a_cid=$rc_a_cid b_wait=${rc_b_elapsed}s $(tail -n 2 "$D/rc-ac4p-b.out" | tr '\n' '|')"
  fi

  # AC3 正例三（D4）：未改动的记录路径显式列为已排除，不计入提交文件集。
  rc_fixture "$D/rc-ac3p3"
  printf 'l1\nl2\nl3\nl4\n' > "$D/rc-ac3p3/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac3p3" 'chore: rc247 排除未改动' \
    facts/project/changes.jsonl facts/project/other.jsonl >"$D/rc-ac3p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -Fq '记录路径无改动，已排除: facts/project/other.jsonl' "$D/rc-ac3p3.out" \
    && [ "$(rc_head_files "$D/rc-ac3p3")" = 'facts/project/changes.jsonl' ]; then
    ok '正例 247-P4b 未改动记录路径 → 显式列为已排除，提交文件集仅实际改动路径（票 247 D4）'
  else
    bad '正例 247-P4b 未改动记录路径 → 显式列为已排除，提交文件集仅实际改动路径（票 247 D4）' "exit=$rc $(tail -n 3 "$D/rc-ac3p3.out" | tr '\n' '|')"
  fi

  # AC4 负例：B 的待提交版本取自 A 提交前 HEAD（l1..l3,b4），A 提交 a4 后才落地 → 前缀
  # 门拒绝并报首个违规行号 4，零提交。同步点同样用标记文件（B 在标记后立即并发起跑）。
  rc_fixture "$D/rc-ac4n"
  rm -f "$D/rc-ac4n.marker"
  printf 'l1\nl2\nl3\na4\n' > "$D/rc-ac4n/facts/project/changes.jsonl"
  RECORD_COMMIT_TEST_MARKER="$D/rc-ac4n.marker" RECORD_COMMIT_TEST_HOLD_MS=2000 \
    sh "$LC" --record-commit "$D/rc-ac4n" 'chore: rc247 A' facts/project/changes.jsonl >"$D/rc-ac4n-a.out" 2>&1 &
  rc_a_pid=$!
  rc_i=0
  while [ ! -e "$D/rc-ac4n.marker" ] && [ "$rc_i" -lt 200 ]; do
    sleep 0.05
    rc_i=$((rc_i + 1))
  done
  rc_marker=0
  if [ -e "$D/rc-ac4n.marker" ]; then rc_marker=1; fi
  printf 'l1\nl2\nl3\nb4\n' > "$D/rc-ac4n.stale"
  cp "$D/rc-ac4n.stale" "$D/rc-ac4n/facts/project/changes.jsonl"
  sh "$LC" --record-commit "$D/rc-ac4n" 'chore: rc247 B 陈旧快照' facts/project/changes.jsonl >"$D/rc-ac4n-b.out" 2>&1 &
  rc_b_pid=$!
  wait "$rc_a_pid"
  rc_a=$?
  wait "$rc_b_pid"
  rc_b=$?
  rc_n0=$(rc_count "$D/rc-ac4n")
  if [ "$rc_marker" -eq 1 ] && [ "$rc_a" -eq 0 ] && [ "$rc_b" -eq 1 ] \
    && grep -Fq '首个违规行号 4（待提交版行号）' "$D/rc-ac4n-b.out" \
    && [ "$(rc_count "$D/rc-ac4n")" -eq "$rc_n0" ]; then
    ok '负例 247-N4 A 提交后落地陈旧快照 → exit 1 报首个违规行号 4、零提交（票 247 AC4）'
  else
    bad '负例 247-N4 A 提交后落地陈旧快照 → exit 1 报首个违规行号 4、零提交（票 247 AC4）' "marker=$rc_marker a=$rc_a b=$rc_b $(tail -n 3 "$D/rc-ac4n-b.out" | tr '\n' '|')"
  fi

  # AC5 正例：记录提交成功后 check-append-only 同源通过。
  sh "$SCRIPT_DIR/check-append-only.sh" "$D/rc-ac3p" >"$D/rc-ac5p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -Fq 'check-append-only: PASS' "$D/rc-ac5p.out"; then
    ok '正例 247-P5 记录提交成功后 check-append-only → exit 0 PASS（票 247 AC5）'
  else
    bad '正例 247-P5 记录提交成功后 check-append-only → exit 0 PASS（票 247 AC5）' "exit=$rc $(tail -n 3 "$D/rc-ac5p.out" | tr '\n' '|')"
  fi

  # AC5 负例：被前缀门拒绝的中间插入现场，check-append-only 同口径 exit 1 指名行号。
  sh "$SCRIPT_DIR/check-append-only.sh" "$D/rc-ac1n" >"$D/rc-ac5n.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '中间插入' "$D/rc-ac5n.out" \
    && grep -Fq '首个违规行号 2（新文件行号）' "$D/rc-ac5n.out"; then
    ok '负例 247-N5 前缀门拒绝现场 check-append-only → exit 1 同口径指名首个违规行号（票 247 AC5）'
  else
    bad '负例 247-N5 前缀门拒绝现场 check-append-only → exit 1 同口径指名首个违规行号（票 247 AC5）' "exit=$rc $(tail -n 3 "$D/rc-ac5n.out" | tr '\n' '|')"
  fi

  # AC5 负例二（D5）：记录路径在工作树被删除 → 入口边界指名「工作树不存在」，零提交。
  rc_fixture "$D/rc-ac5n2"
  rm -f "$D/rc-ac5n2/facts/project/changes.jsonl"
  rc_n0=$(rc_count "$D/rc-ac5n2")
  sh "$LC" --record-commit "$D/rc-ac5n2" 'chore: rc247 缺失路径' facts/project/changes.jsonl >"$D/rc-ac5n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -Fq '记录路径在工作树不存在: facts/project/changes.jsonl' "$D/rc-ac5n2.out" \
    && [ "$(rc_count "$D/rc-ac5n2")" -eq "$rc_n0" ]; then
    ok '负例 247-N5b 记录路径在工作树被删除 → exit 1 指名不存在、零提交（票 247 D5）'
  else
    bad '负例 247-N5b 记录路径在工作树被删除 → exit 1 指名不存在、零提交（票 247 D5）' "exit=$rc $(tail -n 3 "$D/rc-ac5n2.out" | tr '\n' '|')"
  fi

  # AC6：README 须说明入口用法、失败零提交与首个违规行号；删去入口行的副本必须不命中
  # （证明断言非空转）。
  rc_readme="$SCRIPT_DIR/README.md"
  if rc_readme_documented "$rc_readme"; then
    ok '正例 247-P6 scripts/README 登记记录提交入口与失败语义（入口/零提交/首个违规行号，票 247 AC6）'
  else
    bad '正例 247-P6 scripts/README 登记记录提交入口与失败语义（入口/零提交/首个违规行号，票 247 AC6）' "$(grep -c -- '--record-commit' "$rc_readme" 2>/dev/null) 处入口行"
  fi
  grep -v -- '--record-commit' "$rc_readme" > "$D/rc-readme-minus.md"
  if rc_readme_documented "$D/rc-readme-minus.md"; then
    bad '负例 247-N6 删去入口行的 README 副本不满足登记断言（证明断言非空转，票 247 AC6）' '副本仍命中'
  else
    ok '负例 247-N6 删去入口行的 README 副本不满足登记断言（证明断言非空转，票 247 AC6）'
  fi

  suite_summary 'lane-commit-record'
}
