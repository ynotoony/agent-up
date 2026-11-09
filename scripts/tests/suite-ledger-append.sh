#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ledger-append "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）



# ============================================================
# suite: ledger-append（票 228 F7 场景沉淀：changes.jsonl 唯一写入方正负例——五键行
# 追加／--check 零写入预检／lesson 六键九键／replan 八键／账本懒创建／紧凑 JSON／
# 缺省根两布局推导；负例零写入——缺 --ledger-line、裸换行制表符、未知键、lesson 缺
# promoted_to、promoted_to 越枚举、replan 非布尔、残缺 JSON（唯一引擎解析门）、未知
# 参数 exit 2、仓根不存在 exit 2；锁断言——独立调用遇存活持有者超时零写入、pid 缺失
# 且锁龄超阈值默认只诊断不夺锁）
# ============================================================

la_build_fixture() {
  # $1=夹具仓根：rules/implementation/scripts/ 落位三件（写入方＋共享库＋唯一引擎），
  # facts/project/ 账本就绪（种子一行五键）
  F=$1
  rm -rf "$F"
  mkdir -p "$F/rules/implementation/scripts" "$F/facts/project"
  cp "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/record-store.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/ledger-row-families.sh" "$F/rules/implementation/scripts/"
  test_copy_closure "$SCRIPT_DIR" "$F/rules/implementation/scripts" json-validator.py common-helpers.sh ledger-append.sh
  printf '%s\n' '{"date": "2026-10-26", "kind": "scope", "scope": "facts/project", "decision": "fixture seed", "evidence_ref": "facts/project/changes.jsonl"}' > "$F/facts/project/changes.jsonl"
}

la_state() {
  # 账本状态指纹（负例零写入断言用）
  if [ -f "$1/facts/project/changes.jsonl" ]; then
    cksum "$1/facts/project/changes.jsonl"
  else
    printf 'no-ledger\n'
  fi
}

la_lock_dir() {
  # $1=夹具根：经共享库只读探针解析锁目录（与产品实现同一推导，测试不按实现猜路径）
  la_probe="$D/.la-lock-probe.sh"
  cat > "$la_probe" <<'PROBE'
#!/bin/sh
set -eu
COMMON_HELPERS_DIR="$1/rules/implementation/scripts"
. "$1/rules/implementation/scripts/common-helpers.sh"
record_lock_init "$1"
printf '%s\n' "$RECORD_LOCK_DIR"
PROBE
  sh "$la_probe" "$1"
  rm -f "$la_probe"
}

suite_ledger_append() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='ledger-append'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/la
  mkdir -p "$D"

  la_build_fixture "$D/p1"
  FP1="$D/p1"
  sh "$FP1/rules/implementation/scripts/ledger-append.sh" "$FP1" --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "facts/project", "decision": "append one", "evidence_ref": "e1"}' >"$D/p1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(tail -n 1 "$FP1/facts/project/changes.jsonl")" = '{"date": "2026-10-26", "kind": "change", "scope": "facts/project", "decision": "append one", "evidence_ref": "e1"}' ] \
    && [ "$(wc -l < "$FP1/facts/project/changes.jsonl" | tr -d ' ')" -eq 2 ] \
    && grep -q 'ledger-append: 账本落行' "$D/p1.log"; then
    ok '正例 P1 五键行显式根追加 → exit 0 恰落一行且报文落行（票 228 F7）'
  else
    bad '正例 P1 五键行显式根追加 → exit 0 恰落一行且报文落行（票 228 F7）' "exit=$rc $(tail -n 1 "$D/p1.log")"
  fi

  # --check 零写入预检（ticket-ops 写前预检经此模式承载的合同面）
  la_build_fixture "$D/p2"
  FP2="$D/p2"
  LA2_BEFORE=$(la_state "$FP2")
  sh "$FP2/rules/implementation/scripts/ledger-append.sh" "$FP2" --check --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$D/p2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$LA2_BEFORE" = "$(la_state "$FP2")" ] && grep -q 'CHECK: PASS' "$D/p2.log"; then
    ok '正例 P2 --check 合法行 → exit 0 校验通过且账本逐字节零变化（零写入预检）'
  else
    bad '正例 P2 --check 合法行 → exit 0 校验通过且账本逐字节零变化（零写入预检）' "exit=$rc $(tail -n 1 "$D/p2.log")"
  fi

  la_build_fixture "$D/p3"
  FP3="$D/p3"
  sh "$FP3/rules/implementation/scripts/ledger-append.sh" "$FP3" --ledger-line '{"date": "2026-10-26", "kind": "lesson", "scope": "s", "decision": "six-key", "evidence_ref": "e", "promoted_to": "sop"}' >"$D/p3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"promoted_to": "sop"' "$FP3/facts/project/changes.jsonl"; then
    ok '正例 P3 lesson 六键（promoted_to=sop）→ exit 0 账本收录（票 81 行型）'
  else
    bad '正例 P3 lesson 六键（promoted_to=sop）→ exit 0 账本收录（票 81 行型）' "exit=$rc $(tail -n 1 "$D/p3.log")"
  fi

  la_build_fixture "$D/p4"
  FP4="$D/p4"
  sh "$FP4/rules/implementation/scripts/ledger-append.sh" "$FP4" --ledger-line '{"date": "2026-10-26", "kind": "lesson", "scope": "s", "decision": "nine-key", "evidence_ref": "e", "promoted_to": "rules", "score_contract": 90, "score_predicate": 100, "score_rework": -1}' >"$D/p4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"score_rework": -1' "$FP4/facts/project/changes.jsonl"; then
    ok '正例 P4 lesson 九键（三分数键含 -1=N/A）→ exit 0 账本收录（票 133 行型）'
  else
    bad '正例 P4 lesson 九键（三分数键含 -1=N/A）→ exit 0 账本收录（票 133 行型）' "exit=$rc $(tail -n 1 "$D/p4.log")"
  fi

  la_build_fixture "$D/p5"
  FP5="$D/p5"
  sh "$FP5/rules/implementation/scripts/ledger-append.sh" "$FP5" --ledger-line '{"date": "2026-10-26", "kind": "replan", "scope": "s", "decision": "eight-key", "evidence_ref": "e", "replan_original": true, "replan_replacement": false, "replan_undone": false}' >"$D/p5.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"replan_undone": false' "$FP5/facts/project/changes.jsonl"; then
    ok '正例 P5 replan 八键（三布尔条件键）→ exit 0 账本收录（票 81 行型）'
  else
    bad '正例 P5 replan 八键（三布尔条件键）→ exit 0 账本收录（票 81 行型）' "exit=$rc $(tail -n 1 "$D/p5.log")"
  fi

  # 账本懒创建（文件缺失 → 连同父目录创建并落行）
  la_build_fixture "$D/p6"
  FP6="$D/p6"
  rm -f "$FP6/facts/project/changes.jsonl"
  sh "$FP6/rules/implementation/scripts/ledger-append.sh" "$FP6" --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "lazy", "evidence_ref": "e"}' >"$D/p6.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$FP6/facts/project/changes.jsonl" ] && grep -q '"decision": "lazy"' "$FP6/facts/project/changes.jsonl"; then
    ok '正例 P6 账本缺失 → 懒创建并落首行（文件本体懒创建，父目录随 mkdir -p）'
  else
    bad '正例 P6 账本缺失 → 懒创建并落首行（文件本体懒创建，父目录随 mkdir -p）' "exit=$rc $(tail -n 1 "$D/p6.log")"
  fi

  # 紧凑 JSON（无空格）与缺省根推导（rules 布局落位，无参裸跑＝显式传参语义对齐）
  la_build_fixture "$D/p7"
  FP7="$D/p7"
  ( cd "$FP7" && sh rules/implementation/scripts/ledger-append.sh --ledger-line '{"date":"2026-10-26","kind":"change","scope":"s","decision":"compact","evidence_ref":"e"}' ) >"$D/p7.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"decision":"compact"' "$FP7/facts/project/changes.jsonl"; then
    ok '正例 P7 紧凑 JSON＋缺省根推导（rules 布局裸跑）→ exit 0 账本收录'
  else
    bad '正例 P7 紧凑 JSON＋缺省根推导（rules 布局裸跑）→ exit 0 账本收录' "exit=$rc $(tail -n 1 "$D/p7.log")"
  fi

  # agent-up/scripts 布局缺省根推导（两布局落位分派，票 227 F4 口径）
  la_build_fixture "$D/p8"
  FP8="$D/p8"
  mkdir -p "$FP8/agent-up/scripts"
  cp "$SCRIPT_DIR/ledger-append.sh" "$SCRIPT_DIR/record-store.sh" "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/json-validator.py" "$SCRIPT_DIR/evidence-gate.sh" "$SCRIPT_DIR/record-lock.sh" "$SCRIPT_DIR/ledger-row-families.sh" "$FP8/agent-up/scripts/"
  test_copy_closure "$SCRIPT_DIR" "$FP8/agent-up/scripts" json-validator.py common-helpers.sh ledger-append.sh
  rm -rf "$FP8/rules"
  ( cd "$FP8" && sh agent-up/scripts/ledger-append.sh --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "pkg-layout", "evidence_ref": "e"}' ) >"$D/p8.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"decision": "pkg-layout"' "$FP8/facts/project/changes.jsonl"; then
    ok '正例 P8 缺省根推导（agent-up/scripts 布局裸跑）→ exit 0 账本收录'
  else
    bad '正例 P8 缺省根推导（agent-up/scripts 布局裸跑）→ exit 0 账本收录' "exit=$rc $(tail -n 1 "$D/p8.log")"
  fi

  # ---- 负例（均 fail-closed 零写入）----
  la_build_fixture "$D/n1"
  FN1="$D/n1"
  SN1=$(la_state "$FN1")
  sh "$FN1/rules/implementation/scripts/ledger-append.sh" "$FN1" >"$D/n1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN1" = "$(la_state "$FN1")" ] && grep -q '缺少 --ledger-line' "$D/n1.log"; then
    ok '负例 N1 缺 --ledger-line → exit 1 零写入'
  else
    bad '负例 N1 缺 --ledger-line → exit 1 零写入' "exit=$rc $(tail -n 1 "$D/n1.log")"
  fi

  la_build_fixture "$D/n2"
  FN2="$D/n2"
  SN2=$(la_state "$FN2")
  printf '{"date": "2026-10-26", "kind": "change", "scope": "s",\n"decision": "d", "evidence_ref": "e"}\n' > "$D/n2-line.json"
  sh "$FN2/rules/implementation/scripts/ledger-append.sh" "$FN2" --ledger-line "$(cat "$D/n2-line.json")" >"$D/n2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN2" = "$(la_state "$FN2")" ] && grep -q '裸换行或制表符' "$D/n2.log"; then
    ok '负例 N2 账本行含裸换行 → exit 1 零写入（一行一事实）'
  else
    bad '负例 N2 账本行含裸换行 → exit 1 零写入（一行一事实）' "exit=$rc $(tail -n 1 "$D/n2.log")"
  fi

  la_build_fixture "$D/n3"
  FN3="$D/n3"
  SN3=$(la_state "$FN3")
  sh "$FN3/rules/implementation/scripts/ledger-append.sh" "$FN3" --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e", "extra": "x"}' >"$D/n3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN3" = "$(la_state "$FN3")" ] && grep -q '未知键' "$D/n3.log" && grep -q 'extra' "$D/n3.log"; then
    ok '负例 N3 未知键 → exit 1 零写入且指名键名（不静默收编）'
  else
    bad '负例 N3 未知键 → exit 1 零写入且指名键名（不静默收编）' "exit=$rc $(tail -n 1 "$D/n3.log")"
  fi

  la_build_fixture "$D/n4"
  FN4="$D/n4"
  SN4=$(la_state "$FN4")
  sh "$FN4/rules/implementation/scripts/ledger-append.sh" "$FN4" --ledger-line '{"date": "2026-10-26", "kind": "lesson", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$D/n4.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN4" = "$(la_state "$FN4")" ] && grep -q '缺第六键 promoted_to' "$D/n4.log"; then
    ok '负例 N4 lesson 缺 promoted_to → exit 1 零写入且指名行型报因（票 81）'
  else
    bad '负例 N4 lesson 缺 promoted_to → exit 1 零写入且指名行型报因（票 81）' "exit=$rc $(tail -n 1 "$D/n4.log")"
  fi

  la_build_fixture "$D/n5"
  FN5="$D/n5"
  SN5=$(la_state "$FN5")
  sh "$FN5/rules/implementation/scripts/ledger-append.sh" "$FN5" --ledger-line '{"date": "2026-10-26", "kind": "lesson", "scope": "s", "decision": "d", "evidence_ref": "e", "promoted_to": "someday"}' >"$D/n5.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN5" = "$(la_state "$FN5")" ] && grep -q '越枚举' "$D/n5.log" && grep -q 'someday' "$D/n5.log"; then
    ok '负例 N5 promoted_to 越枚举 → exit 1 零写入且指名值（票 81）'
  else
    bad '负例 N5 promoted_to 越枚举 → exit 1 零写入且指名值（票 81）' "exit=$rc $(tail -n 1 "$D/n5.log")"
  fi

  la_build_fixture "$D/n6"
  FN6="$D/n6"
  SN6=$(la_state "$FN6")
  sh "$FN6/rules/implementation/scripts/ledger-append.sh" "$FN6" --ledger-line '{"date": "2026-10-26", "kind": "replan", "scope": "s", "decision": "d", "evidence_ref": "e", "replan_original": "yes", "replan_replacement": false, "replan_undone": false}' >"$D/n6.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN6" = "$(la_state "$FN6")" ] && grep -q '须为布尔字面量' "$D/n6.log"; then
    ok '负例 N6 replan 条件键非布尔 → exit 1 零写入（票 81）'
  else
    bad '负例 N6 replan 条件键非布尔 → exit 1 零写入（票 81）' "exit=$rc $(tail -n 1 "$D/n6.log")"
  fi

  # 唯一 JSON 引擎缺席：行族链在前的合法面恒过解析门，行族链外残缺 JSON 由形状链先收口；
  # 引擎门可达面＝引擎件缺失——fail-closed 指名双布局定位均未命中，零写入（票 227 口径）
  la_build_fixture "$D/n7"
  FN7="$D/n7"
  SN7=$(la_state "$FN7")
  rm -f "$FN7/rules/implementation/scripts/json-validator.py"
  sh "$FN7/rules/implementation/scripts/ledger-append.sh" "$FN7" --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$D/n7.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$SN7" = "$(la_state "$FN7")" ] && grep -q 'json-validator.py 不存在' "$D/n7.log"; then
    ok '负例 N7 唯一 JSON 引擎缺席 → exit 1 零写入且指名引擎双布局定位均未命中（票 227 口径）'
  else
    bad '负例 N7 唯一 JSON 引擎缺席 → exit 1 零写入且指名引擎双布局定位均未命中（票 227 口径）' "exit=$rc $(tail -n 1 "$D/n7.log")"
  fi

  la_build_fixture "$D/n8"
  FN8="$D/n8"
  sh "$FN8/rules/implementation/scripts/ledger-append.sh" "$FN8" --bogus-flag >"$D/n8.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '未知参数' "$D/n8.log"; then
    ok '负例 N8 未知参数 → exit 2（用法错误）'
  else
    bad '负例 N8 未知参数 → exit 2（用法错误）' "exit=$rc $(tail -n 1 "$D/n8.log")"
  fi

  la_build_fixture "$D/n9"
  FN9="$D/n9"
  sh "$FN9/rules/implementation/scripts/ledger-append.sh" /tmp/definitely-not-a-repo-228 --ledger-line '{"date": "2026-10-26", "kind": "change", "scope": "s", "decision": "d", "evidence_ref": "e"}' >"$D/n9.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '仓库根不可用' "$D/n9.log"; then
    ok '负例 N9 仓根不存在 → exit 2（fail-closed 指名）'
  else
    bad '负例 N9 仓根不存在 → exit 2（fail-closed 指名）' "exit=$rc $(tail -n 1 "$D/n9.log")"
  fi

  # ---- 票 246 AC1：20 进程并行独立调用 ledger-append（不经 ticket-ops）零丢行 ----
  la_build_fixture "$D/c1"
  FC1="$D/c1"
  SFC1="$FC1/rules/implementation/scripts/ledger-append.sh"
  : > "$D/c1.expected"
  la_i=1
  while [ "$la_i" -le 20 ]; do
    printf '%s\n' "{\"date\": \"2026-10-30\", \"kind\": \"change\", \"scope\": \"facts/project\", \"decision\": \"并发行 $la_i\", \"evidence_ref\": \"c1-$la_i\"}" >> "$D/c1.expected"
    la_i=$((la_i + 1))
  done
  la_pids=''
  la_i=1
  while [ "$la_i" -le 20 ]; do
    ( sh "$SFC1" "$FC1" --ledger-line "{\"date\": \"2026-10-30\", \"kind\": \"change\", \"scope\": \"facts/project\", \"decision\": \"并发行 $la_i\", \"evidence_ref\": \"c1-$la_i\"}" >"$D/c1-$la_i.log" 2>&1 ) &
    la_pids="$la_pids $!"
    la_i=$((la_i + 1))
  done
  la_fail=0
  for la_p in $la_pids; do
    wait "$la_p" || la_fail=$((la_fail + 1))
  done
  la_lines=$(wc -l < "$FC1/facts/project/changes.jsonl" | tr -d ' ')
  tail -n +2 "$FC1/facts/project/changes.jsonl" | LC_ALL=C sort > "$D/c1.actual"
  LC_ALL=C sort "$D/c1.expected" > "$D/c1.expected.sorted"
  if [ "$la_fail" -eq 0 ] && [ "$la_lines" = '21' ] && cmp -s "$D/c1.actual" "$D/c1.expected.sorted"; then
    ok 'AC1 20 进程并行独立调用 ledger-append → 相对起点恰增 20 行、每行与输入逐字对应、无丢失'
  else
    bad 'AC1 20 进程并行独立调用 ledger-append → 相对起点恰增 20 行、每行与输入逐字对应、无丢失' "失败进程=${la_fail}/20 总行数=${la_lines}（期望 21） diff=$(diff "$D/c1.expected.sorted" "$D/c1.actual" 2>/dev/null | head -n 4 | tr '\n' '|')"
  fi

  # ---- 票 246 AC7：并发后历史行逐字不变、仅尾部增长；check-append-only 通过 ----
  la_build_fixture "$D/c7"
  FC7="$D/c7"
  SFC7="$FC7/rules/implementation/scripts/ledger-append.sh"
  git_repo "$FC7"
  git -C "$FC7" add -A
  git -C "$FC7" -c user.email=fixture@example.com -c user.name=fixture commit -q -m seed
  cp "$FC7/facts/project/changes.jsonl" "$D/c7.seed"
  la_pids=''
  la_i=1
  while [ "$la_i" -le 10 ]; do
    ( sh "$SFC7" "$FC7" --ledger-line "{\"date\": \"2026-10-30\", \"kind\": \"change\", \"scope\": \"facts/project\", \"decision\": \"历史行不变 $la_i\", \"evidence_ref\": \"c7-$la_i\"}" >"$D/c7-$la_i.log" 2>&1 ) &
    la_pids="$la_pids $!"
    la_i=$((la_i + 1))
  done
  la_fail=0
  for la_p in $la_pids; do
    wait "$la_p" || la_fail=$((la_fail + 1))
  done
  head -n "$(wc -l < "$D/c7.seed" | tr -d ' ')" "$FC7/facts/project/changes.jsonl" > "$D/c7.head"
  sh "$SCRIPT_DIR/check-append-only.sh" "$FC7" >"$D/c7.guard.log" 2>&1
  la_guard=$?
  if [ "$la_fail" -eq 0 ] && cmp -s "$D/c7.head" "$D/c7.seed" && [ "$la_guard" -eq 0 ] && \
     [ "$(wc -l < "$FC7/facts/project/changes.jsonl" | tr -d ' ')" = '11' ]; then
    ok 'AC7 并发追加后历史行逐字不变、仅尾部增长，check-append-only 通过'
  else
    bad 'AC7 并发追加后历史行逐字不变、仅尾部增长，check-append-only 通过' "失败进程=${la_fail}/10 行数=$(wc -l < "$FC7/facts/project/changes.jsonl" | tr -d ' ') guard_exit=$la_guard $(tail -n 2 "$D/c7.guard.log" | tr '\n' '|')"
  fi

  # ---- AC5（锁）：独立调用 ledger-append（非 --check）遇存活持有者的锁 → 有界等待超时零写入 ----
  # 预置存活 pid 的锁目录（锁龄刻意造旧也不得夺）；TICKET_OPS_LOCK_TIMEOUT=1 下必须 exit 1、
  # 账本 cksum 不变、报文含锁目录路径与持有者 pid，锁目录与令牌原样。
  la_build_fixture "$D/locklive"
  FPL=$D/locklive
  git_repo "$FPL"
  SPL="$FPL/rules/implementation/scripts/ledger-append.sh"
  la_lockdir_live=$(la_lock_dir "$FPL")
  rm -rf "${la_lockdir_live}"
  mkdir -p "${la_lockdir_live}"
  la_live_pid=$$
  printf '%s\n' "${la_live_pid}" > "${la_lockdir_live}/pid"
  printf '%s\n' "${la_live_pid}:0:live" > "${la_lockdir_live}/token"
  la_live_before=$(la_state "$FPL")
  TICKET_OPS_LOCK_TIMEOUT=1 sh "$SPL" "$FPL" --ledger-line '{"date": "2026-10-30", "kind": "change", "scope": "facts/project", "decision": "锁存活持有者超时", "evidence_ref": "lock-live"}' >"$D/locklive.log" 2>&1
  la_live_rc=$?
  la_live_after=$(la_state "$FPL")
  if [ "${la_live_rc}" -eq 1 ] && [ "${la_live_before}" = "${la_live_after}" ] && \
     grep -q '并发冲突' "$D/locklive.log" && \
     grep -qF "${la_lockdir_live}" "$D/locklive.log" && \
     grep -qF "持有者 pid ${la_live_pid}" "$D/locklive.log" && \
     [ -d "${la_lockdir_live}" ] && \
     [ "$(sed -n '1p' "${la_lockdir_live}/token" 2>/dev/null)" = "${la_live_pid}:0:live" ]; then
    ok 'AC5 独立调用 ledger-append 遇存活持有者的锁 → 有界等待超时 exit 1、账本零写入、报文含锁路径与持有者 pid'
  else
    bad 'AC5 独立调用 ledger-append 遇存活持有者的锁 → 有界等待超时 exit 1、账本零写入、报文含锁路径与持有者 pid' "exit=${la_live_rc} 账本变=$( [ "${la_live_before}" = "${la_live_after}" ] && echo no || echo yes ) 锁在=$( [ -d "${la_lockdir_live}" ] && echo yes || echo no ) 令牌=$(sed -n '1p' "${la_lockdir_live}/token" 2>/dev/null) $(head -n 2 "$D/locklive.log" | tr '\n' '|' | cut -c 1-200)"
  fi
  rm -rf "${la_lockdir_live}"

  # ---- AC4 补（锁）：pid 缺失＋锁龄超阈值 → 默认只诊断不夺锁，超时零写入 ----
  # 锁目录只写 token 不写 pid，mtime 造到 2020；TICKET_OPS_LOCK_STALE=60 ＋ TIMEOUT=1 下
  # 必须 exit 1、账本不变、报文含锁路径与「陈旧写锁…仅诊断」，锁目录与令牌原样（未被夺）。
  la_build_fixture "$D/lockstale"
  FPS=$D/lockstale
  git_repo "$FPS"
  SPS="$FPS/rules/implementation/scripts/ledger-append.sh"
  la_lockdir_stale=$(la_lock_dir "$FPS")
  rm -rf "${la_lockdir_stale}"
  mkdir -p "${la_lockdir_stale}"
  printf '%s\n' '0:0:stale' > "${la_lockdir_stale}/token"
  touch -t 202001010000 "${la_lockdir_stale}" "${la_lockdir_stale}/token"
  la_stale_before=$(la_state "$FPS")
  TICKET_OPS_LOCK_STALE=60 TICKET_OPS_LOCK_TIMEOUT=1 sh "$SPS" "$FPS" --ledger-line '{"date": "2026-10-30", "kind": "change", "scope": "facts/project", "decision": "陈旧锁只诊断", "evidence_ref": "lock-stale"}' >"$D/lockstale.log" 2>&1
  la_stale_rc=$?
  la_stale_after=$(la_state "$FPS")
  la_stale_sidecar=$(find "$(dirname -- "${la_lockdir_stale}")" -maxdepth 1 -name "$(basename -- "${la_lockdir_stale}").steal.*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${la_stale_rc}" -eq 1 ] && [ "${la_stale_before}" = "${la_stale_after}" ] && \
     grep -q '陈旧写锁' "$D/lockstale.log" && \
     grep -q '仅诊断' "$D/lockstale.log" && \
     grep -qF "${la_lockdir_stale}" "$D/lockstale.log" && \
     [ -d "${la_lockdir_stale}" ] && [ "${la_stale_sidecar}" = '0' ] && \
     [ "$(sed -n '1p' "${la_lockdir_stale}/token" 2>/dev/null)" = '0:0:stale' ]; then
    ok 'AC4 补 pid 缺失＋锁龄超阈值 → 默认只诊断不夺锁，超时 exit 1、账本零写入、锁原样'
  else
    bad 'AC4 补 pid 缺失＋锁龄超阈值 → 默认只诊断不夺锁，超时 exit 1、账本零写入、锁原样' "exit=${la_stale_rc} 账本变=$( [ "${la_stale_before}" = "${la_stale_after}" ] && echo no || echo yes ) 锁在=$( [ -d "${la_lockdir_stale}" ] && echo yes || echo no ) 旁路=${la_stale_sidecar} 令牌=$(sed -n '1p' "${la_lockdir_stale}/token" 2>/dev/null) $(head -n 4 "$D/lockstale.log" | tr '\n' '|' | cut -c 1-200)"
  fi
  rm -rf "${la_lockdir_stale}"

  suite_summary 'ledger-append'
}
