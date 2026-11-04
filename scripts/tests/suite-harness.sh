#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite harness "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: harness（票 258 harness 硬化回归）
# 覆盖四条新负例，全部常驻（不靠 /tmp 手工验）：
#   1. per-suite 超时 → 记 FAIL 行、后续套件照跑、整轮 exit 1（AC1）；
#   2. 套件内 exit 2 → 不终止 harness，仍有后续套件输出与汇总行（AC2）；
#   3. 收到 TERM/INT → 清理临时目录后 exit 130（AC3）；
#   4. 断言数跌破下限 → FAIL 且 exit 1（AC5）；
#   5. --suite fast 子集非空且 ⊆ all（AC4 的静态面）。
# 做法：在 mktemp 里合成一个「同款 runner＋全桩套件」的最小 harness，只让被验套件
# 换成超时/exit 的探针——夹具与真实仓库零写入，且不依赖真套件的耗时。
# ============================================================

_h_build() {
  # $1=合成 harness 根：复制同款 runner/helpers，按 ALL_SUITES 生成桩套件
  _hb_root=$1
  mkdir -p "$_hb_root/tests"
  cp "$TESTS_DIR/test-runner.sh" "$_hb_root/tests/test-runner.sh"
  cp "$TESTS_DIR/test-helpers.sh" "$_hb_root/tests/test-helpers.sh"
  for _hb_n in $ALL_SUITES; do
    _hb_fn="suite_$(printf '%s' "$_hb_n" | tr '-' '_')"
    cat >"$_hb_root/tests/suite-$_hb_n.sh" <<EOF
#!/bin/sh
$_hb_fn() {
  CUR_SUITE='$_hb_n'
  SUITE_FAILS=0
  SUITE_START=\$TOTAL
  ok '桩套件 $_hb_n'
  suite_summary '$_hb_n'
}
EOF
  done
  # --suite all 末尾的注入自检在合成 harness 里不许递归，换成本地桩
  cat >>"$_hb_root/tests/suite-adversarial.sh" <<'EOF'
self_check_injection() {
  CUR_SUITE='self-check'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  ok '桩自检'
  suite_summary 'self-check'
}
EOF
}

_h_run_all() {
  # $1=合成 harness 根 $2=日志 $3=可选单套件超时；环境变量只作用于本次 sh 调用
  # （POSIX 下 VAR=val 前置函数调用会泄漏到后续调用，故显式分支）
  _hr_timeout=${3:-}
  if [ -n "$_hr_timeout" ]; then
    TEST_ASSERTION_FLOOR=0 TEST_SUITE_TIMEOUT="$_hr_timeout" \
      sh "$1/tests/test-runner.sh" --suite all --script-dir "$SCRIPT_DIR" --pkg-root "$PKG_ROOT" \
      >"$2" 2>&1
  else
    TEST_ASSERTION_FLOOR=0 \
      sh "$1/tests/test-runner.sh" --suite all --script-dir "$SCRIPT_DIR" --pkg-root "$PKG_ROOT" \
      >"$2" 2>&1
  fi
}

_h_signal_case() {
  # $1=信号名 $2=期望退出码：中断后须 exit 约定码且临时目录已清
  # 后台任务在 POSIX 下继承 SIGINT=ignore，runner 的 trap 将失效；故经 python3 把
  # INT 处置重置为 SIG_DFL 后再 exec（python3 已是 harness 声明的环境依赖）。
  _hs_sig=$1
  _hs_want=$2
  _hs_log="$T/h-signal-$_hs_sig.log"
  python3 -c 'import signal,os,sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' \
    sh "$_h_sig_root/tests/test-runner.sh" --suite all --script-dir "$SCRIPT_DIR" --pkg-root "$PKG_ROOT" \
    >"$_hs_log" 2>&1 &
  _hs_pid=$!
  _hs_i=0
  while [ "$_hs_i" -lt 100 ]; do
    grep -q 'tmp=' "$_hs_log" 2>/dev/null && break
    sleep 0.1
    _hs_i=$((_hs_i + 1))
  done
  _hs_tmp=$(sed -n 's/.*tmp=\([^ ]*\).*/\1/p' "$_hs_log" | head -1)
  kill -"$_hs_sig" "$_hs_pid" 2>/dev/null
  wait "$_hs_pid"
  _hs_rc=$?
  if [ "$_hs_rc" -eq "$_hs_want" ]; then
    ok "中断负例（${_hs_sig}）：收到信号后 exit ${_hs_want}"
  else
    bad "中断负例（${_hs_sig}）：收到信号后 exit ${_hs_want}" "实际 exit $_hs_rc"
  fi
  if grep -q "中断（${_hs_sig}）" "$_hs_log"; then
    ok "中断负例（${_hs_sig}）：输出中断行并声明已清理"
  else
    bad "中断负例（${_hs_sig}）：输出中断行并声明已清理" "$(tail -2 "$_hs_log" 2>/dev/null | tr '\n' '|')"
  fi
  if [ -n "$_hs_tmp" ] && [ ! -d "$_hs_tmp" ]; then
    ok "中断负例（${_hs_sig}）：临时目录已删除（${_hs_tmp}）"
  else
    bad "中断负例（${_hs_sig}）：临时目录已删除" "tmp=${_hs_tmp:-<未捕获>}"
  fi
}

suite_harness() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='harness'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL

  # ---- 负例 1：per-suite 超时（AC1）----
  _h_root="$T/h-timeout"
  _h_build "$_h_root"
  cat >"$_h_root/tests/suite-progress.sh" <<'EOF'
#!/bin/sh
suite_progress() {
  CUR_SUITE='progress'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  ok '超时前断言'
  sleep 5
  ok '超时后不该到达'
  suite_summary 'progress'
}
EOF
  _h_run_all "$_h_root" "$T/h-timeout.log" 1
  _h_rc=$?
  if [ "$_h_rc" -eq 1 ]; then
    ok '超时负例：整轮 exit 1（不静默当通过）'
  else
    bad '超时负例：整轮 exit 1（不静默当通过）' "实际 exit $_h_rc"
  fi
  if grep -q '^FAIL  \[progress\] 套件超时' "$T/h-timeout.log"; then
    ok '超时负例：记 FAIL 行并指名超时上限'
  else
    bad '超时负例：记 FAIL 行并指名超时上限' "$(grep '^FAIL' "$T/h-timeout.log" 2>/dev/null | head -2 | tr '\n' '|')"
  fi
  if grep -q '^PASS  \[check-artifacts\] 桩套件 check-artifacts' "$T/h-timeout.log"; then
    ok '超时负例：后续套件照跑（check-artifacts 在 progress 之后）'
  else
    bad '超时负例：后续套件照跑（check-artifacts 在 progress 之后）' '后续套件未见输出'
  fi
  if grep -q '^test-record-layer: FAIL（共' "$T/h-timeout.log"; then
    ok '超时负例：仍有整轮汇总行'
  else
    bad '超时负例：仍有整轮汇总行' "$(tail -2 "$T/h-timeout.log" 2>/dev/null | tr '\n' '|')"
  fi

  # ---- 负例 2：套件内 exit 2（AC2）----
  _h_root="$T/h-exit"
  _h_build "$_h_root"
  cat >"$_h_root/tests/suite-ticket-ops.sh" <<'EOF'
#!/bin/sh
suite_ticket_ops() {
  CUR_SUITE='ticket-ops'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  ok 'exit 前断言'
  exit 2
}
EOF
  _h_run_all "$_h_root" "$T/h-exit.log"
  _h_rc=$?
  if [ "$_h_rc" -eq 1 ]; then
    ok 'exit 负例：整轮 exit 1（套件退出不算通过）'
  else
    bad 'exit 负例：整轮 exit 1（套件退出不算通过）' "实际 exit $_h_rc"
  fi
  if grep -q '^FAIL  \[ticket-ops\] 套件提前退出（exit 2）' "$T/h-exit.log"; then
    ok 'exit 负例：记 FAIL 行并指名退出码'
  else
    bad 'exit 负例：记 FAIL 行并指名退出码' "$(grep '^FAIL' "$T/h-exit.log" 2>/dev/null | head -2 | tr '\n' '|')"
  fi
  if grep -q '^PASS  \[json-engine\] 桩套件 json-engine' "$T/h-exit.log"; then
    ok 'exit 负例：后续套件照跑（json-engine 在 ticket-ops 之后）'
  else
    bad 'exit 负例：后续套件照跑（json-engine 在 ticket-ops 之后）' '后续套件未见输出'
  fi
  if grep -q '^PASS  \[ticket-ops\] exit 前断言' "$T/h-exit.log" &&
    grep -q '^test-record-layer: \[ticket-ops\] 断言 1/2 通过（1 失败；套件未产出汇总行）' "$T/h-exit.log"; then
    ok 'exit 负例：父进程按日志补出该套件汇总行（退出前断言不丢）'
  else
    bad 'exit 负例：父进程按日志补出该套件汇总行（退出前断言不丢）' \
      "$(grep '^test-record-layer: \[ticket-ops\]' "$T/h-exit.log" 2>/dev/null | tr '\n' '|')"
  fi
  if grep -q '^test-record-layer: FAIL（共' "$T/h-exit.log"; then
    ok 'exit 负例：仍有整轮汇总行'
  else
    bad 'exit 负例：仍有整轮汇总行' "$(tail -2 "$T/h-exit.log" 2>/dev/null | tr '\n' '|')"
  fi

  # ---- 负例 3：INT/TERM（AC3）----
  _h_sig_root="$T/h-signal"
  _h_build "$_h_sig_root"
  cat >"$_h_sig_root/tests/suite-progress.sh" <<'EOF'
#!/bin/sh
suite_progress() {
  CUR_SUITE='progress'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  ok '挂起前断言'
  sleep 5
  suite_summary 'progress'
}
EOF
  _h_signal_case TERM 130
  _h_signal_case INT 130

  # ---- 负例 4：断言数跌破下限（AC5）----
  TEST_ASSERTION_FLOOR=999999 \
    sh "$TESTS_DIR/test-runner.sh" --suite docs-generation >"$T/h-floor.log" 2>&1
  _h_rc=$?
  if [ "$_h_rc" -eq 1 ]; then
    ok '下限负例：断言数低于下限即 exit 1'
  else
    bad '下限负例：断言数低于下限即 exit 1' "实际 exit $_h_rc"
  fi
  if grep -q '^FAIL  \[floor\] 断言数下限' "$T/h-floor.log"; then
    ok '下限负例：记 FAIL 行并指名实测与下限'
  else
    bad '下限负例：记 FAIL 行并指名实测与下限' "$(tail -2 "$T/h-floor.log" 2>/dev/null | tr '\n' '|')"
  fi

  # ---- fast 子集（AC4 静态面）----
  _h_bad=''
  for _h_n in $FAST_SUITES; do
    suite_listed "$_h_n" || _h_bad="$_h_bad 越集:$_h_n"
  done
  if [ -n "$FAST_SUITES" ] && [ -z "$_h_bad" ]; then
    ok "fast 子集非空且 ⊆ all（$(printf '%s\n' "$FAST_SUITES" | wc -l | tr -d ' ') 名）"
  else
    bad 'fast 子集非空且 ⊆ all' "fast=${FAST_SUITES:-<空>}${_h_bad}"
  fi
  if [ "$FAST_SUITES" != "$ALL_SUITES" ]; then
    ok 'fast 子集是对 all 的真子集（不是全量别名）'
  else
    bad 'fast 子集是对 all 的真子集（不是全量别名）' 'fast 与 all 相同'
  fi
  if grep -q '^ASSERTION_FLOOR=1100$' "$TESTS_DIR/test-runner.sh"; then
    ok '断言下限缺省固定为 1100（票 257 收口基线）'
  else
    bad '断言下限缺省固定为 1100（票 257 收口基线）' '未找到 ASSERTION_FLOOR=1100'
  fi

  suite_summary 'harness'
}
