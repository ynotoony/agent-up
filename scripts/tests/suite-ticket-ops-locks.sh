#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite NAME "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: ticket-ops-locks（票 291 自 suite-ticket-ops 拆出的锁与恢复能力面）：
# 票 243 状态单写与崩溃恢复 AC1～AC6＋票 246 记录层锁（并发 open/take 串行、陈旧锁诊断
# 与显式夺锁、存活持有者有界等待、令牌拦写、继承嵌套、主检/worktree 同一锁目录）＋
# 票 261 空锁目录拒绝＋锁原语单点与镜像一致＋故障注入收敛/边界/去重＋投影篡改重建。
# 夹具全 mktemp；被测脚本一律在夹具副本执行，仓库 facts/ 零写入。

suite_ticket_ops_locks() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='ticket-ops-locks'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/tixlocks
  mkdir -p "$D"
  LED_OPEN='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  # ============================================================
  # 票 243：票务状态单写与崩溃恢复（AC1～AC6）
  # 契约单源见本文件「票 243 夹具」节头注（TICKET_OPS_FAULT 三注入点／并发冲突报文／幂等重跑）。
  # 夹具全 mktemp；被测脚本一律在夹具副本上执行，仓库 facts/ 零写入。
  # ============================================================
  TIX243_CONC_ROUNDS=${TIX243_CONC_ROUNDS:-8}

  # ---- AC1：空索引 {"issues":[]} 可开第一张票，索引/README/投影一致 ----
  F243A1=$D/fix243a1
  tix243_fresh_fixture "$F243A1"
  tix_body "$F243A1/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  sh "$F243A1/rules/implementation/scripts/ticket-ops.sh" "$F243A1" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/ac1-open.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'AC1 空索引首开 → open exit 0'
  else
    bad 'AC1 空索引首开 → open exit 0' "exit=$rc $(tix243_reason "$D/ac1-open.log")"
  fi
  if tix243_json_ok "$F243A1/facts/requirements/tickets/index.json" && \
     [ "$(tix243_count "$F243A1/facts/requirements/tickets/index.json" '"id": "30-gamma-third"')" = '1' ]; then
    ok 'AC1 首开后索引为合法 JSON 且该票恰一条目'
  else
    bad 'AC1 首开后索引为合法 JSON 且该票恰一条目' "条目数=$(tix243_count "$F243A1/facts/requirements/tickets/index.json" '"id": "30-gamma-third"') 索引=$(tr '\n' '|' < "$F243A1/facts/requirements/tickets/index.json" | cut -c 1-120)"
  fi
  if [ "$(tix243_count "$F243A1/facts/requirements/tickets/README.md" '30-gamma-third.json')" = '1' ] && \
     [ -f "$F243A1/facts/requirements/tickets/progress-current.md" ] && \
     [ "$(tix243_count "$F243A1/facts/requirements/tickets/progress-current.md" '| 30-gamma-third |')" = '1' ] && \
     sh "$F243A1/rules/implementation/scripts/generate-progress.sh" --check "$F243A1" >/dev/null 2>&1; then
    ok 'AC1 首开后 README 行与投影一致（生成器 --check exit 0）'
  else
    bad 'AC1 首开后 README 行与投影一致（生成器 --check exit 0）' "README行=$(tix243_count "$F243A1/facts/requirements/tickets/README.md" '30-gamma-third.json') 投影行=$(tix243_count "${F243A1}/facts/requirements/tickets/progress-current.md" '| 30-gamma-third |')"
  fi

  # ---- AC2：两个并发 open 不丢更新；失败方得明确冲突；索引保持合法 JSON ----
  tix243_lost=0
  tix243_invalid=0
  tix243_no_conflict=0
  tix243_round=1
  while [ "$tix243_round" -le "$TIX243_CONC_ROUNDS" ]; do
    F243C="$D/fix243conc$tix243_round"
    tix_build_fixture "$F243C"
    tix_body "$F243C/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
    tix_body "$F243C/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
    SK243C="$F243C/rules/implementation/scripts/ticket-ops.sh"
    ( sh "$SK243C" "$F243C" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/ac2-$tix243_round-a.log" 2>&1 ) &
    tix243_p1=$!
    ( sh "$SK243C" "$F243C" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line "$LED_OPEN" >"$D/ac2-$tix243_round-b.log" 2>&1 ) &
    tix243_p2=$!
    wait "$tix243_p1"
    tix243_r1=$?
    wait "$tix243_p2"
    tix243_r2=$?
    tix243_json_ok "$F243C/facts/requirements/tickets/index.json" || tix243_invalid=$((tix243_invalid + 1))
    tix243_n30=$(tix243_count "$F243C/facts/requirements/tickets/index.json" '"id": "30-gamma-third"')
    tix243_n40=$(tix243_count "$F243C/facts/requirements/tickets/index.json" '"id": "40-delta-fourth"')
    if [ "$tix243_r1" -eq 0 ] && [ "$tix243_r2" -eq 0 ]; then
      if [ "$tix243_n30" = '0' ] || [ "$tix243_n40" = '0' ]; then
        tix243_lost=$((tix243_lost + 1))
      fi
    elif require_out "AC2 并发 $TIX243_CONC_ROUNDS 轮零丢更新（双方 exit 0 时两条目并存）" "$D/ac2-$tix243_round-a.log" "$D/ac2-$tix243_round-b.log" && ! grep -qi '冲突\|conflict' "$D/ac2-$tix243_round-a.log" "$D/ac2-$tix243_round-b.log"; then
      tix243_no_conflict=$((tix243_no_conflict + 1))
    fi
    tix243_round=$((tix243_round + 1))
  done
  if [ "$tix243_lost" -eq 0 ]; then
    ok "AC2 并发 $TIX243_CONC_ROUNDS 轮零丢更新（双方 exit 0 时两条目并存）"
  else
    bad "AC2 并发 $TIX243_CONC_ROUNDS 轮零丢更新（双方 exit 0 时两条目并存）" "丢更新轮数=$tix243_lost/${TIX243_CONC_ROUNDS}（双方均 exit 0 但索引缺条目＝读-改-写窗口未串行）"
  fi
  if [ "$tix243_invalid" -eq 0 ]; then
    ok 'AC2 并发后索引恒为合法 JSON'
  else
    bad 'AC2 并发后索引恒为合法 JSON' "非法轮数=$tix243_invalid/$TIX243_CONC_ROUNDS"
  fi
  if [ "$tix243_no_conflict" -eq 0 ]; then
    ok 'AC2 失败方报文含冲突标记（或双方均成功且未被吞掉）'
  else
    bad 'AC2 失败方报文含冲突标记（或双方均成功且未被吞掉）' "静默失败轮数=$tix243_no_conflict/$TIX243_CONC_ROUNDS"
  fi

  # ---- AC2take（票 246 AC2）：两进程并行 take 两张不同票 → 双方 exit 0、两条目均为
  #      in_progress、各自持有 updated_at、索引仍为合法 JSON（锁覆盖读-改-写，无覆盖写） ----
  F246TK=$D/fix246take
  tix_build_fixture "$F246TK"
  tix_body "$F246TK/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  tix_body "$F246TK/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  SK246TK="$F246TK/rules/implementation/scripts/ticket-ops.sh"
  sh "$SK246TK" "$F246TK" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line '{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 并行 take 前置开票 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}' >"$D/ac2take-open30.log" 2>&1
  sh "$SK246TK" "$F246TK" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line '{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 并行 take 前置开票 40", "evidence_ref": "facts/requirements/tickets/40-delta-fourth.json"}' >"$D/ac2take-open40.log" 2>&1
  ( sh "$SK246TK" "$F246TK" take --id 30-gamma-third --status in_progress --ledger-line '{"date": "2026-09-21", "kind": "change", "scope": "facts/requirements/tickets", "decision": "票246 并行 take 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}' >"$D/ac2take-a.log" 2>&1 ) &
  tix246_tk_p1=$!
  ( sh "$SK246TK" "$F246TK" take --id 40-delta-fourth --status in_progress --ledger-line '{"date": "2026-09-21", "kind": "change", "scope": "facts/requirements/tickets", "decision": "票246 并行 take 40", "evidence_ref": "facts/requirements/tickets/40-delta-fourth.json"}' >"$D/ac2take-b.log" 2>&1 ) &
  tix246_tk_p2=$!
  wait "$tix246_tk_p1"
  tix246_tk_r1=$?
  wait "$tix246_tk_p2"
  tix246_tk_r2=$?
  IDX246TK="$F246TK/facts/requirements/tickets/index.json"
  if [ "$tix246_tk_r1" -eq 0 ] && [ "$tix246_tk_r2" -eq 0 ] && \
     tix243_json_ok "$IDX246TK" && \
     grep -q '"id": "30-gamma-third", "status": "in_progress"' "$IDX246TK" && \
     grep -q '"id": "40-delta-fourth", "status": "in_progress"' "$IDX246TK"; then
    ok 'AC2 两进程并行 take 两张不同票 → 双方 exit 0、两条目均 in_progress、索引合法 JSON'
  else
    bad 'AC2 两进程并行 take 两张不同票 → 双方 exit 0、两条目均 in_progress、索引合法 JSON' "rc=$tix246_tk_r1/$tix246_tk_r2 索引=$(tr '\n' '|' < "$IDX246TK" 2>/dev/null | cut -c 1-160) A=$(tix243_reason "$D/ac2take-a.log") B=$(tix243_reason "$D/ac2take-b.log")"
  fi
  tix246_tk_u30=$(grep '"id": "30-gamma-third"' "$IDX246TK" 2>/dev/null | grep -o '"updated_at": "[^"]*"' | head -n 1)
  tix246_tk_u40=$(grep '"id": "40-delta-fourth"' "$IDX246TK" 2>/dev/null | grep -o '"updated_at": "[^"]*"' | head -n 1)
  if [ -n "$tix246_tk_u30" ] && [ -n "$tix246_tk_u40" ]; then
    ok "AC2 并行 take 后两条目各自持有 updated_at（30=${tix246_tk_u30} 40=${tix246_tk_u40}）"
  else
    bad 'AC2 并行 take 后两条目各自持有 updated_at' "30=${tix246_tk_u30:-缺失} 40=${tix246_tk_u40:-缺失}"
  fi

  # ---- AC2b：陈旧锁默认只诊断不夺锁；显式参数才夺锁（票 246 AC4）----
  # 构造陈旧锁（pid 999999 不存在）后：
  #   ① 默认 TICKET_OPS_LOCK_TIMEOUT=1 → exit 1，报文含锁路径/持有者 pid/「仅诊断」WARNING，
  #      四载体零写入，锁目录原样保留（未被自动夺）；
  #   ② RECORD_LOCK_BREAK_STALE=1 重跑 → exit 0，索引落条目；
  #   ③ 再造陈旧锁，--break-stale-lock CLI 形态开另一票 → exit 0。
  F246S=$D/fix246stale
  tix243_fresh_fixture "$F246S"
  tix_body "$F246S/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  tix_body "$F246S/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  S246S="$F246S/rules/implementation/scripts/ticket-ops.sh"
  LED246S30='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 陈旧锁显式夺锁 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  LED246S40='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 陈旧锁显式夺锁 40", "evidence_ref": "facts/requirements/tickets/40-delta-fourth.json"}'
  tix246_lockdir_s=$(tix246_lock_dir "$F246S")
  rm -rf "${tix246_lockdir_s}"
  mkdir -p "${tix246_lockdir_s}"
  printf '%s\n' 999999 > "${tix246_lockdir_s}/pid"
  printf '%s\n' '999999:0:stale' > "${tix246_lockdir_s}/token"
  tix246_before=$(tix_state "$F246S")
  TICKET_OPS_LOCK_TIMEOUT=1 sh "$S246S" "$F246S" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED246S30" >"$D/ac2b-default.log" 2>&1
  tix246_rc=$?
  tix246_after=$(tix_state "$F246S")
  if [ "$tix246_rc" -eq 1 ] && [ "$tix246_before" = "$tix246_after" ] && \
     grep -q '并发冲突' "$D/ac2b-default.log" && \
     grep -qF "${tix246_lockdir_s}" "$D/ac2b-default.log" && \
     grep -qF 'pid 999999' "$D/ac2b-default.log" && \
     grep -q '仅诊断' "$D/ac2b-default.log" && \
     [ -d "${tix246_lockdir_s}" ] && \
     [ "$(sed -n '1p' "${tix246_lockdir_s}/token" 2>/dev/null)" = '999999:0:stale' ]; then
    ok 'AC4 陈旧锁默认只诊断不夺：超时 exit 1 且报文含锁路径/持有者 pid/仅诊断 WARNING，四载体零写入、锁原样'
  else
    bad 'AC4 陈旧锁默认只诊断不夺：超时 exit 1 且报文含锁路径/持有者 pid/仅诊断 WARNING，四载体零写入、锁原样' "exit=$tix246_rc 锁在=$([ -d "${tix246_lockdir_s}" ] && echo yes || echo no) $(tix243_reason "$D/ac2b-default.log" | cut -c 1-160)"
  fi
  TICKET_OPS_LOCK_TIMEOUT=1 RECORD_LOCK_BREAK_STALE=1 sh "$S246S" "$F246S" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED246S30" >"$D/ac2b-break.log" 2>&1
  tix246_rc=$?
  if [ "$tix246_rc" -eq 0 ] && grep -q '显式夺锁' "$D/ac2b-break.log" && \
     [ "$(tix243_count "$F246S/facts/requirements/tickets/index.json" '"id": "30-gamma-third"')" = '1' ] && \
     [ ! -d "${tix246_lockdir_s}" ]; then
    ok 'AC4 RECORD_LOCK_BREAK_STALE=1 显式夺锁后恢复：exit 0 且索引落条目、锁目录释放'
  else
    bad 'AC4 RECORD_LOCK_BREAK_STALE=1 显式夺锁后恢复：exit 0 且索引落条目、锁目录释放' "exit=$tix246_rc 索引30=$(tix243_count "$F246S/facts/requirements/tickets/index.json" '"id": "30-gamma-third"') 锁在=$([ -d "${tix246_lockdir_s}" ] && echo yes || echo no) $(tix243_reason "$D/ac2b-break.log" | cut -c 1-160)"
  fi
  mkdir -p "${tix246_lockdir_s}"
  printf '%s\n' 999999 > "${tix246_lockdir_s}/pid"
  printf '%s\n' '999999:0:stale2' > "${tix246_lockdir_s}/token"
  TICKET_OPS_LOCK_TIMEOUT=1 sh "$S246S" "$F246S" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line "$LED246S40" --break-stale-lock >"$D/ac2b-cli.log" 2>&1
  tix246_rc=$?
  if [ "$tix246_rc" -eq 0 ] && grep -q '显式夺锁' "$D/ac2b-cli.log" && \
     [ "$(tix243_count "$F246S/facts/requirements/tickets/index.json" '"id": "40-delta-fourth"')" = '1' ] && \
     [ ! -d "${tix246_lockdir_s}" ]; then
    ok 'AC4 --break-stale-lock CLI 等价显式夺锁：exit 0 且索引落条目、锁目录释放'
  else
    bad 'AC4 --break-stale-lock CLI 等价显式夺锁：exit 0 且索引落条目、锁目录释放' "exit=$tix246_rc 索引40=$(tix243_count "$F246S/facts/requirements/tickets/index.json" '"id": "40-delta-fourth"') 锁在=$([ -d "${tix246_lockdir_s}" ] && echo yes || echo no) $(tix243_reason "$D/ac2b-cli.log" | cut -c 1-160)"
  fi

  # ---- AC2c＋AC3(246)：锁被存活持有者占用（锁龄再老）→ 拒绝夺锁、有界等待后超时 ----
  # pid 指向真实存活的 sleep 进程、mtime 极旧（2020）；TICKET_OPS_LOCK_STALE=60 ＋
  # TICKET_OPS_LOCK_TIMEOUT=1：必须数秒内 exit 1，报文含「并发冲突」、锁目录路径与持有者 pid；
  # 四载体零写入；锁不得被搬走（无嵌套 .lock、无 steal 旁路残留），令牌原样。
  F246W=$D/fix246livelock
  tix243_fresh_fixture "$F246W"
  tix_body "$F246W/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  LED246W='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 存活持有者超时", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  tix246_lockdir_w=$(tix246_lock_dir "$F246W")
  rm -rf "${tix246_lockdir_w}"
  mkdir -p "${tix246_lockdir_w}"
  sleep 30 &
  tix246_sleeper=$!
  printf '%s\n' "${tix246_sleeper}" > "${tix246_lockdir_w}/pid"
  printf '%s\n' "${tix246_sleeper}:0:live" > "${tix246_lockdir_w}/token"
  touch -t 202001010000 "${tix246_lockdir_w}" "${tix246_lockdir_w}/pid" "${tix246_lockdir_w}/token"
  S246W="$F246W/rules/implementation/scripts/ticket-ops.sh"
  tix246_w_before=$(tix_state "$F246W")
  tix246_w_start=$(date +%s)
  TICKET_OPS_LOCK_STALE=60 TICKET_OPS_LOCK_TIMEOUT=1 sh "$S246W" "$F246W" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED246W" >"$D/ac2c.log" 2>&1
  tix246_w_rc=$?
  tix246_w_elapsed=$(( $(date +%s) - tix246_w_start ))
  if [ "$tix246_w_rc" -eq 1 ] && [ "$tix246_w_elapsed" -le 5 ] && \
     [ "$tix246_w_before" = "$(tix_state "$F246W")" ] && \
     grep -q '并发冲突' "$D/ac2c.log" && \
     grep -qF "${tix246_lockdir_w}" "$D/ac2c.log" && \
     grep -qF "pid ${tix246_sleeper}" "$D/ac2c.log"; then
    ok "AC2c/AC3 锁被占用有界等待 ${tix246_w_elapsed}s 超时 exit 1：报文含锁路径与持有者 pid，四载体零写入"
  else
    bad "AC2c/AC3 锁被占用有界等待超时 exit 1：报文含锁路径与持有者 pid，四载体零写入" "exit=$tix246_w_rc 耗时=${tix246_w_elapsed}s pid=${tix246_sleeper} $(tix243_reason "$D/ac2c.log" | cut -c 1-160)"
  fi
  kill "${tix246_sleeper}" 2>/dev/null || true
  wait "${tix246_sleeper}" 2>/dev/null || true
  tix246_w_nested=$(find "${tix246_lockdir_w}" -mindepth 1 -maxdepth 1 -name '*.lock' 2>/dev/null | wc -l | tr -d ' ')
  tix246_w_sidecar=$(find "$(dirname -- "${tix246_lockdir_w}")" -maxdepth 1 -name "$(basename -- "${tix246_lockdir_w}").steal.*" 2>/dev/null | wc -l | tr -d ' ')
  if [ -d "${tix246_lockdir_w}" ] && [ "$tix246_w_nested" = '0' ] && [ "$tix246_w_sidecar" = '0' ] && \
     [ "$(sed -n '1p' "${tix246_lockdir_w}/token" 2>/dev/null)" = "${tix246_sleeper}:0:live" ]; then
    ok 'AC2c 存活持有者的锁未被搬走（令牌原样、无嵌套 .lock、无 steal 旁路残留）'
  else
    bad 'AC2c 存活持有者的锁未被搬走（令牌原样、无嵌套 .lock、无 steal 旁路残留）' "lock目录=$([ -d "${tix246_lockdir_w}" ] && echo yes || echo no) 嵌套=${tix246_w_nested} 旁路=${tix246_w_sidecar} 令牌=$(sed -n '1p' "${tix246_lockdir_w}/token" 2>/dev/null)"
  fi
  rm -rf "${tix246_lockdir_w}"

  # ---- AC4：夺锁后原持有者的下一次写入被令牌拦下（票 246 AC4 后半）----
  # 首进程持锁（RECORD_LOCK_TEST_HOLD_MS 放大窗口），测试把锁内 pid 改写为 999999 模拟
  # 持有者已死；第二进程 --break-stale-lock 夺锁并落 40；首进程恢复后写点断言令牌不符，
  # 必须 exit 1 且四载体零写入（索引/README/账本均无 30）。
  F246T=$D/fix246token
  tix243_fresh_fixture "$F246T"
  tix_body "$F246T/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  tix_body "$F246T/facts/requirements/tickets/40-delta-fourth.json" 40-delta-fourth
  S246T="$F246T/rules/implementation/scripts/ticket-ops.sh"
  LED246T30='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 令牌拦写 30", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  LED246T40='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 令牌拦写 40", "evidence_ref": "facts/requirements/tickets/40-delta-fourth.json"}'
  tix246_lockdir_t=$(tix246_lock_dir "$F246T")
  RECORD_LOCK_TEST_HOLD_MS=2000 sh "$S246T" "$F246T" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED246T30" >"$D/ac4-hold.log" 2>&1 &
  tix246_hp=$!
  tix246_i=0
  while [ ! -s "${tix246_lockdir_t}/token" ] && [ "$tix246_i" -lt 100 ]; do
    sleep 0.05
    tix246_i=$((tix246_i + 1))
  done
  printf '%s\n' 999999 > "${tix246_lockdir_t}/pid"
  TICKET_OPS_LOCK_TIMEOUT=5 RECORD_LOCK_BREAK_STALE=1 sh "$S246T" "$F246T" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line "$LED246T40" >"$D/ac4-steal.log" 2>&1
  tix246_rs=$?
  wait "$tix246_hp"
  tix246_rh=$?
  tix246_ledger_lines=$(wc -l < "$F246T/facts/project/changes.jsonl" | tr -d ' ')
  if [ "$tix246_rs" -eq 0 ] && [ "$tix246_rh" -eq 1 ] && \
     grep -q '写锁归属已失效' "$D/ac4-hold.log" && \
     [ "$(tix243_count "$F246T/facts/requirements/tickets/index.json" '"id": "30-gamma-third"')" = '0' ] && \
     [ "$(tix243_count "$F246T/facts/requirements/tickets/index.json" '"id": "40-delta-fourth"')" = '1' ] && \
     [ "$(tix243_count "$F246T/facts/requirements/tickets/README.md" '30-gamma-third.json')" = '0' ] && \
     [ "$(tix243_count "$F246T/facts/requirements/tickets/README.md" '40-delta-fourth.json')" = '1' ] && \
     [ "$tix246_ledger_lines" = '1' ] && \
     [ "$(tix243_count "$F246T/facts/project/changes.jsonl" '票246 令牌拦写 30')" = '0' ]; then
    ok 'AC4 夺锁后原持有者写点被令牌拦下（exit 1、报文指名归属失效、索引/README/账本零写入 30）'
  else
    bad 'AC4 夺锁后原持有者写点被令牌拦下（exit 1、报文指名归属失效、索引/README/账本零写入 30）' "夺锁方rc=$tix246_rs 原持有者rc=$tix246_rh 索引30=$(tix243_count "$F246T/facts/requirements/tickets/index.json" '"id": "30-gamma-third"') 账本行数=$tix246_ledger_lines $(tix243_reason "$D/ac4-hold.log" | cut -c 1-140)"
  fi

  # ---- AC5：ticket-ops 持锁嵌套调用 ledger-append 不重复取锁（继承标记）----
  # TICKET_OPS_LOCK_TIMEOUT=1：若嵌套调用自行取锁会等 1s 后失败；exit 0 即证继承生效。
  F246N=$D/fix246nested
  tix243_fresh_fixture "$F246N"
  tix_body "$F246N/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  LED246N='{"date": "2026-09-21", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票246 嵌套继承落行", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
  S246N="$F246N/rules/implementation/scripts/ticket-ops.sh"
  tix246_lockdir_n=$(tix246_lock_dir "$F246N")
  TICKET_OPS_LOCK_TIMEOUT=1 RECORD_LOCK_TEST_HOLD_MS=300 sh "$S246N" "$F246N" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED246N" >"$D/ac5-nested.log" 2>&1
  tix246_rn=$?
  F246N2=$D/fix246nested-solo
  rm -rf "$F246N2"
  mkdir -p "$F246N2"
  sh "$SCRIPT_DIR/ledger-append.sh" "$F246N2" --ledger-line "$LED246N" >"$D/ac5-solo.log" 2>&1
  tix246_rn2=$?
  tix246_n_lines=$(wc -l < "$F246N/facts/project/changes.jsonl" 2>/dev/null | tr -d ' ')
  if [ "$tix246_rn" -eq 0 ] && [ "$tix246_rn2" -eq 0 ] && [ "$tix246_n_lines" = '1' ] && \
     cmp -s "$F246N/facts/project/changes.jsonl" "$F246N2/facts/project/changes.jsonl" && \
     [ ! -d "${tix246_lockdir_n}" ] && \
     [ "$(find "$(dirname -- "${tix246_lockdir_n}")" -maxdepth 1 -name "$(basename -- "${tix246_lockdir_n}").steal.*" 2>/dev/null | wc -l | tr -d ' ')" = '0' ]; then
    ok 'AC5 嵌套调用继承锁：open exit 0、账本恰 1 行且与独立 ledger-append 落行逐字节相等、锁已释放'
  else
    bad 'AC5 嵌套调用继承锁：open exit 0、账本恰 1 行且与独立 ledger-append 落行逐字节相等、锁已释放' "open rc=$tix246_rn solo rc=$tix246_rn2 账本行数=${tix246_n_lines:-none} 锁在=$([ -d "${tix246_lockdir_n}" ] && echo yes || echo no) $(tix243_reason "$D/ac5-nested.log" | cut -c 1-140)"
  fi

  # ---- AC6：主检与 worktree 解析同一锁目录；持锁不污染 git status ----
  # 探针 source 共享库（不经产品脚本猜路径），分别在主检与 linked worktree 取锁并打印锁目录，
  # 两者 cd -P 归一后字符串相等；持锁期间 git status --short 为空（锁在 .git 内，不入跟踪面）。
  F246G=$D/fix246git
  F246G_WT=$D/fix246git-wt
  rm -rf "$F246G" "$F246G_WT"
  mkdir -p "$F246G"
  git_repo "$F246G"
  git -C "$F246G" -c user.email=fixture@example.com -c user.name=fixture commit -q --allow-empty -m init
  git -C "$F246G" worktree add -q --detach "$F246G_WT" HEAD
  cat > "$D/probe-lock-git.sh" <<'PROBE'
#!/bin/sh
set -eu
COMMON_HELPERS_DIR=$(dirname -- "$1")
export COMMON_HELPERS_DIR
. "$1"
record_lock_init "$2"
record_lock_acquire
trap 'record_lock_release' EXIT
printf '%s\n' "$RECORD_LOCK_DIR"
git -C "$2" status --short > "$3"
PROBE
  tix246_g_main=$(sh "$D/probe-lock-git.sh" "$SCRIPT_DIR/common-helpers.sh" "$F246G" "$D/ac6-status-main.txt")
  tix246_g_wt=$(sh "$D/probe-lock-git.sh" "$SCRIPT_DIR/common-helpers.sh" "$F246G_WT" "$D/ac6-status-wt.txt")
  if [ -n "$tix246_g_main" ] && [ "$tix246_g_main" = "$tix246_g_wt" ]; then
    ok "AC6 主检与 worktree 锁目录同一物理路径（${tix246_g_main}）"
  else
    bad 'AC6 主检与 worktree 锁目录同一物理路径' "main=${tix246_g_main:-空} wt=${tix246_g_wt:-空}"
  fi
  if [ -z "$(cat "$D/ac6-status-main.txt" 2>/dev/null)" ] && [ -z "$(cat "$D/ac6-status-wt.txt" 2>/dev/null)" ]; then
    ok 'AC6 持锁期间主检与 worktree 的 git status --short 均为空（锁不污染白名单门禁）'
  else
    bad 'AC6 持锁期间主检与 worktree 的 git status --short 均为空（锁不污染白名单门禁）' "main=$(tr '\n' '|' < "$D/ac6-status-main.txt" 2>/dev/null) wt=$(tr '\n' '|' < "$D/ac6-status-wt.txt" 2>/dev/null)"
  fi

  # ---- AC1(261)：空 RECORD_LOCK_DIR 取锁即拒 exit 1，且当前目录零残留（不得落 .steal.PID）----
  # 子 shell 在独立空目录内显式 RECORD_LOCK_DIR='' 调 acquire：守卫须在任何 mkdir/mv/rm 前
  # exit 1；ls -a 除 . 与 .. 外零条目（无锁目录、无 .steal.* 旁路）。
  F261L=$D/fix261-lockguard
  rm -rf "$F261L"
  mkdir -p "$F261L"
  ( cd "$F261L" && RECORD_LOCK_DIR='' COMMON_HELPERS_DIR="$SCRIPT_DIR" sh -c '. "$1"; record_lock_acquire' sh "$SCRIPT_DIR/common-helpers.sh" ) >"$D/ac1-261-lockguard.log" 2>&1
  tix261_lg_rc=$?
  tix261_lg_entries=0
  tix261_lg_steal=0
  for tix261_lg_e in "$F261L"/* "$F261L"/.*; do
    [ -e "$tix261_lg_e" ] || [ -L "$tix261_lg_e" ] || continue
    tix261_lg_base=${tix261_lg_e##*/}
    case $tix261_lg_base in
      .|..) continue ;;
      .steal.*) tix261_lg_steal=$((tix261_lg_steal + 1)) ;;
    esac
    tix261_lg_entries=$((tix261_lg_entries + 1))
  done
  if [ "$tix261_lg_rc" -eq 1 ] && [ "$tix261_lg_entries" = '0' ] && [ "$tix261_lg_steal" = '0' ] && \
     grep -q '写锁目录未初始化' "$D/ac1-261-lockguard.log"; then
    ok 'AC1 空 RECORD_LOCK_DIR 取锁即拒 exit 1 且 CWD 零残留（无 .steal.*、无锁目录）'
  else
    bad 'AC1 空 RECORD_LOCK_DIR 取锁即拒 exit 1 且 CWD 零残留（无 .steal.*、无锁目录）' "exit=$tix261_lg_rc 条目=$tix261_lg_entries steal=$tix261_lg_steal $(tix243_reason "$D/ac1-261-lockguard.log" | cut -c 1-160)"
  fi
  rm -rf "$F261L"

  # ---- AC8：锁原语单点实现（两脚本无锁实现字样）＋三镜像件逐字节一致 ----
  tix246_impl=''
  # shellcheck disable=SC2016  # case/for 分支里的注入桩原文含 ${...} 字样（单引号防展开），非缺陷
  for tix246_tok in 'agent-up-record' '.steal.' 'mkdir "${RECORD_LOCK_DIR}"' 'record_lock_new_token' 'rev-parse --git-common-dir'; do
    if grep -qF -- "$tix246_tok" "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/ledger-append.sh"; then
      tix246_impl="$tix246_impl [$tix246_tok]"
    fi
  done
  if grep -qE '^record_lock_[a-z_]+\(\)' "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/ledger-append.sh"; then
    tix246_impl="$tix246_impl [重复定义 record_lock_*]"
  fi
  if [ "$(grep -c '^record_lock_acquire() {' "$SCRIPT_DIR/record-lock.sh")" = '1' ] && [ "$(grep -c '^record_lock_acquire() {' "$SCRIPT_DIR/common-helpers.sh")" = '0' ] && [ -z "$tix246_impl" ]; then
    ok 'AC8 锁原语唯一定义在 record-lock.sh（common-helpers 转发），ticket-ops/ledger-append 无锁目录拼接、取锁、陈旧判定与夺锁实现'
  else
    bad 'AC8 锁原语唯一定义在 record-lock.sh（common-helpers 转发），ticket-ops/ledger-append 无锁目录拼接、取锁、陈旧判定与夺锁实现' "命中=${tix246_impl:-无} acquire定义数=$(grep -c '^record_lock_acquire() {' "$SCRIPT_DIR/common-helpers.sh")"
  fi
  tix246_mirror_dir="$SCRIPT_DIR/../../rules/implementation/scripts"
  if [ -f "$tix246_mirror_dir/common-helpers.sh" ]; then
    if cmp -s "$SCRIPT_DIR/common-helpers.sh" "$tix246_mirror_dir/common-helpers.sh" && \
       cmp -s "$SCRIPT_DIR/ticket-ops.sh" "$tix246_mirror_dir/ticket-ops.sh" && \
       cmp -s "$SCRIPT_DIR/ledger-append.sh" "$tix246_mirror_dir/ledger-append.sh"; then
      ok 'AC8 rules/implementation/scripts/ 三镜像件与源件逐字节一致'
    else
      bad 'AC8 rules/implementation/scripts/ 三镜像件与源件逐字节一致' 'cmp 不一致（先同步镜像件）'
    fi
  else
    ok 'AC8 非源布局（镜像目录不在场）——镜像一致性由包检检查 13 承载'
  fi

  # ---- AC3：索引写后／账本写后／投影写后分别注入失败，重跑同一命令收敛 ----
  # 注入优先走实现契约 TICKET_OPS_FAULT（探针：expect exit 70 ＋ FAULT injected 报文）；
  # 契约缺席时退回临时副本写点桩替换（只在 mktemp 副本上插 exit 70，产品文件零改动）。
  tix243_contract_hits=0
  for tix243_point in after-index-write after-ledger-write after-projection-write; do
    F243K="$D/fix243-$tix243_point"
    tix_build_fixture "$F243K"
    tix_body "$F243K/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
    SK243K="$F243K/rules/implementation/scripts/ticket-ops.sh"
    LED243K='{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "票243 崩溃收敛", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}'
    tix243_mech=''
    TICKET_OPS_FAULT=$tix243_point sh "$SK243K" "$F243K" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED243K" >"$D/ac3-$tix243_point-probe.log" 2>&1
    rc=$?
    if [ "$rc" -eq 70 ] && grep -qF "FAULT injected: $tix243_point" "$D/ac3-$tix243_point-probe.log"; then
      tix243_mech='contract'
      tix243_contract_hits=$((tix243_contract_hits + 1))
    fi
    # 探针可能已在正常路径写完全部面（契约缺席时），统一重建现场再注入
    tix_build_fixture "$F243K"
    tix_body "$F243K/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
    SK243K="$F243K/rules/implementation/scripts/ticket-ops.sh"
    if [ -z "$tix243_mech" ]; then
      cp "$SK243K" "$D/ac3-$tix243_point.orig"
      if tix243_inject "$SK243K" "$(tix243_fault_marker "$tix243_point")" 1; then
        tix243_mech='patch'
      fi
    fi
    if [ -z "$tix243_mech" ]; then
      bad "AC3 $tix243_point 崩溃可注入（契约或写点桩）" "探针 exit=${rc}（TICKET_OPS_FAULT 未生效），且写点标记零命中——崩溃路径不可测"
      continue
    fi
    if [ "$tix243_mech" = 'contract' ]; then
      TICKET_OPS_FAULT=$tix243_point sh "$SK243K" "$F243K" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED243K" >"$D/ac3-$tix243_point-crash.log" 2>&1
      rc=$?
    else
      sh "$SK243K" "$F243K" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED243K" >"$D/ac3-$tix243_point-crash.log" 2>&1
      rc=$?
      cp "$D/ac3-$tix243_point.orig" "$SK243K"
    fi
    if [ "$rc" -eq 70 ]; then
      ok "AC3 $tix243_point 崩溃已注入（机制=${tix243_mech}）"
    else
      bad "AC3 $tix243_point 崩溃已注入（机制=${tix243_mech}）" "exit=$rc $(tix243_reason "$D/ac3-$tix243_point-crash.log")"
    fi
    sh "$SK243K" "$F243K" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED243K" >"$D/ac3-$tix243_point-retry.log" 2>&1
    rc=$?
    tix243_cv=$(tix243_converged "$F243K")
    if [ "$rc" -eq 0 ] && [ -z "$tix243_cv" ]; then
      ok "AC3 $tix243_point 崩溃后重跑同一命令收敛（索引/README/投影/账本一致且无重复行）"
    else
      bad "AC3 $tix243_point 崩溃后重跑同一命令收敛（索引/README/投影/账本一致且无重复行）" "重跑 exit=$rc 未收敛面=${tix243_cv:-（无）} 报文=$(tix243_reason "$D/ac3-$tix243_point-retry.log")"
    fi
  done
  if [ "$tix243_contract_hits" -eq 3 ]; then
    ok 'AC3 实现提供 TICKET_OPS_FAULT 三注入点契约（测试不依赖内部写点桩）'
  else
    bad 'AC3 实现提供 TICKET_OPS_FAULT 三注入点契约（测试不依赖内部写点桩）' "契约命中 $tix243_contract_hits/3；未命中点须靠临时副本写点桩，属实现缺口"
  fi

  # ---- AC3b：故障注入契约边界——未知值 exit 2 且零写入（评审固化）----
  F243N=$D/fix243faultbad
  tix_build_fixture "$F243N"
  tix_body "$F243N/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  S243N="$F243N/rules/implementation/scripts/ticket-ops.sh"
  S243N_BEFORE=$(tix_state "$F243N")
  TICKET_OPS_FAULT=bogus sh "$S243N" "$F243N" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/ac3b.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ "$S243N_BEFORE" = "$(tix_state "$F243N")" ] && [ ! -f "$F243N/facts/requirements/tickets/progress-current.md" ]; then
    ok 'AC3b 未知 TICKET_OPS_FAULT 值 → exit 2 零写入'
  else
    bad 'AC3b 未知 TICKET_OPS_FAULT 值 → exit 2 零写入' "exit=$rc $(tix243_reason "$D/ac3b.log" | cut -c 1-110)"
  fi

  # ---- AC3c：账本去重边界（评审整改）——只对状态操作判重，且按 JSON 对象相等；
  #      `ledger` 无票入口保持只追加不判重（静默跳过会吞事实）。----
  F243L=$D/fix243ledger
  tix_build_fixture "$F243L"
  tix_body "$F243L/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  S243L="$F243L/rules/implementation/scripts/ticket-ops.sh"
  LED_AB='{"date": "2026-09-20", "kind": "scope", "scope": "s", "decision": "a b", "evidence_ref": "y"}'
  LED_NO_SPACE='{"date": "2026-09-20", "kind": "scope", "scope": "s", "decision": "ab", "evidence_ref": "y"}'
  sh "$S243L" "$F243L" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_AB" >"$D/ac3c-open.log" 2>&1
  rc1=$?
  sh "$S243L" "$F243L" take --id 30-gamma-third --status in_progress --ledger-line "$LED_NO_SPACE" >"$D/ac3c-take.log" 2>&1
  rc2=$?
  if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && \
     [ "$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "a b"')" = '1' ] && \
     [ "$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "ab"')" = '1' ]; then
    ok 'AC3c 内部空白不同的两行不误判重复（decision "a b" 与 "ab" 各一行）'
  else
    bad 'AC3c 内部空白不同的两行不误判重复（decision "a b" 与 "ab" 各一行）' "rc=${rc1}/${rc2} a_b=$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "a b"') ab=$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "ab"')"
  fi
  sh "$S243L" "$F243L" take --id 30-gamma-third --status in_progress --ledger-line "$LED_NO_SPACE" >"$D/ac3c-take2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "ab"')" = '1' ]; then
    ok 'AC3c 同一状态操作重跑不重复落账本行（幂等，行数不变）'
  else
    bad 'AC3c 同一状态操作重跑不重复落账本行（幂等，行数不变）' "exit=$rc ab=$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "ab"')"
  fi
  LED_NOTICKET='{"date": "2026-09-20", "kind": "scope", "scope": "s", "decision": "no-ticket", "evidence_ref": "y"}'
  sh "$S243L" "$F243L" ledger --ledger-line "$LED_NOTICKET" >/dev/null 2>&1
  sh "$S243L" "$F243L" ledger --ledger-line "$LED_NOTICKET" >/dev/null 2>&1
  if [ "$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "no-ticket"')" = '2' ]; then
    ok 'AC3c ledger 无票入口保持只追加不判重（同文两次＝两行）'
  else
    bad 'AC3c ledger 无票入口保持只追加不判重（同文两次＝两行）' "行数=$(tix243_count "$F243L/facts/project/changes.jsonl" '"decision": "no-ticket"')"
  fi

  # ---- AC4：投影删除/篡改由生成器重建，手改不成为真相源 ----
  F243P=$D/fix243proj
  tix_build_fixture "$F243P"
  GP243="$F243P/rules/implementation/scripts/generate-progress.sh"
  PP243="$F243P/facts/requirements/tickets/progress-current.md"
  rm -f "$PP243"
  sh "$GP243" "$F243P" >"$D/ac4-rebuild.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$PP243" ]; then
    ok 'AC4 投影删除 → 生成器重建 exit 0 且落盘'
  else
    bad 'AC4 投影删除 → 生成器重建 exit 0 且落盘' "exit=$rc $(head -n 1 "$D/ac4-rebuild.log")"
  fi
  sh "$GP243" --check "$F243P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'AC4 重建后 --check 一致'
  else
    bad 'AC4 重建后 --check 一致' "exit=$rc"
  fi
  printf 'HAND EDIT 手工改投影\n' >> "$PP243"
  sh "$GP243" --check "$F243P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok 'AC4 手工改投影被检出 → --check exit 1'
  else
    bad 'AC4 手工改投影被检出 → --check exit 1' "exit=${rc}（手改未被识别）"
  fi
  sh "$GP243" "$F243P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$(tix243_count "$PP243" 'HAND EDIT')" = '0' ]; then
    ok 'AC4 再生成覆盖手改内容（手改不成为真相源）'
  else
    bad 'AC4 再生成覆盖手改内容（手改不成为真相源）' "exit=$rc 残留手改行=$(tix243_count "$PP243" 'HAND EDIT')"
  fi

  # ---- AC5：测试与登记面在册（真正包检留自检步，命令见票面 verification[1]）----
  if [ -f "$TESTS_DIR/suite-ticket-ops.sh" ] && grep -q 'AC1 空索引首开' "$TESTS_DIR/suite-ticket-ops.sh"; then
    ok 'AC5 票 243 用例在册于 suite-ticket-ops.sh（--suite ticket-ops 入口可达）'
  else
    bad 'AC5 票 243 用例在册于 suite-ticket-ops.sh（--suite ticket-ops 入口可达）' "文件或自登记标记缺失: $TESTS_DIR/suite-ticket-ops.sh"
  fi
  if [ -f "$SCRIPT_DIR/check-package.sh" ] && grep -q 'ticket-ops' "$TESTS_DIR/test-runner.sh"; then
    ok 'AC5 包检入口与 runner 派发表在册'
  else
    bad 'AC5 包检入口与 runner 派发表在册' "check-package.sh=${SCRIPT_DIR}/check-package.sh"
  fi

  # ---- AC6：开票不预填 ACTUAL_TIME、Review 结论或 Commit pass 指针 ----
  F243Q=$D/fix243ac6
  tix_build_fixture "$F243Q"
  tix_body "$F243Q/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  python3 - "$F243Q/facts/requirements/tickets/30-gamma-third.json" <<'PYTHON'
import json, sys
path = sys.argv[1]
body = json.load(open(path, encoding='utf-8'))
body.pop('dispatch', None)
with open(path, 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
PYTHON
  sh "$F243Q/rules/implementation/scripts/ticket-ops.sh" "$F243Q" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line '{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open ac6a", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}' >"$D/ac6a.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'AC6 无 dispatch 节开票 exit 0（不要求开票时预填派发合同）'
  else
    bad 'AC6 无 dispatch 节开票 exit 0（不要求开票时预填派发合同）' "exit=$rc $(tix243_reason "$D/ac6a.log")——当前实现要求开票即预填三阶段合同（含 ACTUAL_TIME/Review 结论/Commit pass 指针），与 AC6 相反"
  fi
  tix_build_fixture "$F243Q"
  tix_body "$F243Q/facts/requirements/tickets/30-gamma-third.json" 30-gamma-third
  python3 - "$F243Q/facts/requirements/tickets/30-gamma-third.json" <<'PYTHON'
import json, sys
path = sys.argv[1]
body = json.load(open(path, encoding='utf-8'))
dp = body['dispatch']
dp['implementation']['ACTUAL_TIME'] = ''
dp['implementation']['ESTIMATED_TIME'] = ''
dp['review']['IMPLEMENTATION_SUMMARY'] = 'pending'
dp['commit']['REVIEW_PASS_CHECKPOINT'] = 'pending'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(body, f, ensure_ascii=False)
PYTHON
  sh "$F243Q/rules/implementation/scripts/ticket-ops.sh" "$F243Q" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line '{"date": "2026-09-20", "kind": "scope", "scope": "facts/requirements/tickets", "decision": "fixture open ac6b", "evidence_ref": "facts/requirements/tickets/30-gamma-third.json"}' >"$D/ac6b.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'AC6 未来证据留空/pending 时开票 exit 0（ACTUAL_TIME、Review 结论、Commit pass 指针均不预填）'
  else
    bad 'AC6 未来证据留空/pending 时开票 exit 0（ACTUAL_TIME、Review 结论、Commit pass 指针均不预填）' "exit=$rc $(tix243_reason "$D/ac6b.log")"
  fi

  suite_summary 'ticket-ops-locks'
}
