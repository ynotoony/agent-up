# shellcheck shell=sh  # 本文件只被 test-runner/套件 source（无 shebang，执行入口在 test-runner.sh）

# 子 shell 隔离（票 258）下的断言记分：套件在子 shell 内跑，计数器改动出不了子 shell，
# 故 ok/bad 同时把结果写进当前套件日志（CUR_JOURNAL，由 test-runner.sh 逐套件重置），
# 父进程按日志行数汇总总数与失败数——suite 内 exit/超时都不再丢已产出的断言计数。
# 注意：重定向子 shell 里的「探针式」断言（如故意让 require_out 翻红以自检前置能力）
# 必须在该子 shell 内显式 `CUR_JOURNAL=''`，否则探针 FAIL 会混入套件日志被父进程计分
# （先例＝suite-shellcheck 防空转自检；票 258 回归发现并修复）。
harness_note_result() {
  if [ -n "${CUR_JOURNAL:-}" ]; then
    printf '%s\n' "$1" >>"$CUR_JOURNAL" || return 0
  fi
  return 0
}

ok() {
  TOTAL=$((TOTAL + 1))
  harness_note_result PASS
  printf 'PASS  [%s] %s\n' "$CUR_SUITE" "$1"
}

bad() {
  TOTAL=$((TOTAL + 1))
  FAILS=$((FAILS + 1))
  SUITE_FAILS=$((SUITE_FAILS + 1))
  harness_note_result FAIL
  printf 'FAIL  [%s] %s\n' "$CUR_SUITE" "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | sed 's/^/      详情: /'
  fi
}

assert_eq() {
  # $1=场景名 $2=实际文件 $3=预期文件
  if cmp -s "$2" "$3"; then
    ok "$1（逐一相等）"
  else
    bad "$1" "$(diff "$3" "$2" 2>/dev/null | sed -n '2,7p' | tr '\n' '|')"
  fi
}

# 负例断言防空转前置：目标输出文件须在场且非空。文件缺失时 `! grep -q` 会空转通过
# （断言变假绿），本前置把它变成 FAIL 并指名缺哪件。缺省要求非空；stderr 等合法空
# 输出的目标用 --allow-empty（在场即可——空 stderr 是合法通过，缺失才是空转）。
require_out() {
  # [--allow-empty] $1=断言标签 $2...=目标输出文件
  _ro_allow=0
  if [ "${1:-}" = '--allow-empty' ]; then
    _ro_allow=1
    shift
  fi
  _ro_lbl=$1
  shift
  for _ro_f in "$@"; do
    if [ ! -f "$_ro_f" ] || { [ "$_ro_allow" -eq 0 ] && [ ! -s "$_ro_f" ]; }; then
      bad "$_ro_lbl" "目标文件缺失或为空（负例断言不得空转）: $_ro_f"
      return 1
    fi
  done
  return 0
}
# shellcheck disable=SC2329  # cleanup 由 trap 回调（shellcheck 单文件视野误报）
cleanup() { [ -n "${T:-}" ] && rm -rf "$T"; return 0; }

# shellcheck disable=SC2329  # on_signal 由 trap 回调（shellcheck 单文件视野误报）
# 中断路径（票 258）：先停掉在跑的套件子 shell，再删临时目录，最后按约定码退出。
# 正常路径不经过本函数，既有退出码（0/1/2）不变；INT/TERM 统一 130，HUP 129。
on_signal() {
  trap - EXIT INT TERM HUP
  if [ -n "${CURRENT_CHILD:-}" ]; then
    kill -TERM "$CURRENT_CHILD" 2>/dev/null
    sleep 0.2
    kill -KILL "$CURRENT_CHILD" 2>/dev/null
  fi
  cleanup
  printf 'test-record-layer: 中断（%s）——已停止在跑套件并清理临时目录，exit %s\n' "$1" "$2" >&2
  exit "$2"
}

tix_norm_progress() {
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$1"
}

# ============================================================
# 注入自检（仅 --suite all）：临时副本上故意破坏一处，harness 必须抓住
# 票 258：注入面由 module-map 单件扩到四个代表套件——规则表面（module-map）、
# 票务写面（ticket-ops）、编排面（ticket-run）、包检面（check-package）；每件三断言
# （exit 非零＋FAIL 逐项行＋套件汇总行），另保留未注入对照与套件名名单自检。
# 子 shell 隔离后套件内注入仍须被逐行抓住，不得因提前 exit 吞掉汇总。
# ============================================================

self_check_injection() {
  CUR_SUITE='self-check'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/inject
  mkdir -p "$D"

  _si_targets='module-map ticket-ops ticket-run check-package'
  for _si_t in $_si_targets; do
    mkdir -p "$D/$_si_t"
    cp -R "$SCRIPT_DIR" "$D/$_si_t/scripts"
    cp -R "$PKG_ROOT/references" "$D/$_si_t/references"
  done
  # 缺陷一：规则表边集破坏（module-map 既有注入面）
  sed 's/~python-import~/~python-importX~/' "$D/module-map/scripts/module-map.rules" \
    >"$D/module-map/scripts/module-map.rules.tmp" \
    && mv "$D/module-map/scripts/module-map.rules.tmp" "$D/module-map/scripts/module-map.rules"
  # 缺陷二～四：产品脚本一进场就 exit 0（假绿形态——什么都没做却报成功）
  for _si_f in ticket-ops ticket-run check-package; do
    awk 'NR==1 { print; print "exit 0"; next } { print }' \
      "$D/$_si_f/scripts/$_si_f.sh" >"$D/$_si_f/scripts/$_si_f.sh.tmp" \
      && mv "$D/$_si_f/scripts/$_si_f.sh.tmp" "$D/$_si_f/scripts/$_si_f.sh"
  done
  for _si_t in $_si_targets; do
    sh "$0" --suite "$_si_t" --script-dir "$D/$_si_t/scripts" --pkg-root "$PKG_ROOT" \
      >"$D/$_si_t.log" 2>&1
    _si_rc=$?
    if [ "$_si_t" = 'check-package' ] && grep -q 'main-only 件不在场' "$D/$_si_t.log" 2>/dev/null; then
      printf 'SKIP  [self-check] check-package 套件在 worktree 栅栏内整套跳过——注入覆盖归主检出\n'
      continue
    fi
    if [ "$_si_rc" -ne 0 ]; then
      ok "注入自检 exit 非零（${_si_t}：临时副本上的破坏被抓住）"
    else
      bad "注入自检 exit 非零（${_si_t}：临时副本上的破坏被抓住）" '注入运行意外通过'
    fi
    if grep -q '^FAIL  \[' "$D/$_si_t.log"; then
      ok "注入自检输出含 FAIL 逐项行（${_si_t}：失败可定位）"
    else
      bad "注入自检输出含 FAIL 逐项行（${_si_t}：失败可定位）" '无 FAIL 行'
    fi
    if grep -q "^test-record-layer: \[$_si_t\] 断言" "$D/$_si_t.log"; then
      ok "注入自检仍有套件汇总行（${_si_t}：失败不吞汇总）"
    else
      bad "注入自检仍有套件汇总行（${_si_t}：失败不吞汇总）" '无套件汇总行'
    fi
  done
  # 未注入对照：同一副本照常通过——证明上面的红灯来自注入而非副本语境
  mkdir -p "$D/control"
  cp -R "$SCRIPT_DIR" "$D/control/scripts"
  cp -R "$PKG_ROOT/references" "$D/control/references"
  sh "$0" --suite module-map --script-dir "$D/control/scripts" --pkg-root "$PKG_ROOT" \
    >"$D/control.log" 2>&1
  _si_rc=$?
  if [ "$_si_rc" -eq 0 ] && grep -q '^test-record-layer: PASS' "$D/control.log"; then
    ok '未注入对照：同副本 module-map 套件照常通过（exit 0 且汇总 PASS）'
  else
    bad '未注入对照：同副本 module-map 套件照常通过（exit 0 且汇总 PASS）' \
      "exit=${_si_rc}；$(tail -2 "$D/control.log" 2>/dev/null | tr '\n' '|')"
  fi
  # 自检：套件名名单三向一致——ALL_SUITES ⊆ 用法行、FAST_SUITES ⊆ ALL_SUITES、
  # 用法行 ⊆ ALL_SUITES∪{all,fast}。缺名会让 --suite <name> 被拒而派发成为死码
  # （票 257 删重复行时丢过 merge）。
  _si_runner=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/test-runner.sh
  _si_all=$(sed -n "s/^ALL_SUITES='\(.*\)'$/\1/p" "$_si_runner" | tr ' ' '\n' | sed '/^$/d')
  _si_fast=$(sed -n "s/^FAST_SUITES='\(.*\)'$/\1/p" "$_si_runner" | tr ' ' '\n' | sed '/^$/d')
  _si_usage=$(sed -n 's/^ *--suite <name> *\(module-map.*\)$/\1/p' "$_si_runner" \
    | sed 's/（.*//' | tr '|' '\n' | sed 's/^ *//; s/ *$//' | sed '/^$/d')
  _si_bad=''
  for _si_n in $_si_all; do
    printf '%s\n' "$_si_usage" | grep -qx -- "$_si_n" || _si_bad="$_si_bad 用法缺名:$_si_n"
  done
  if [ -n "$_si_all" ] && [ -n "$_si_usage" ] && [ -z "$_si_bad" ]; then
    ok "套件名自检：ALL_SUITES ⊆ 用法行（$(printf '%s\n' "$_si_all" | wc -l | tr -d ' ') 名）"
  else
    bad '套件名自检：ALL_SUITES ⊆ 用法行' "用法名单=${_si_usage:-<空>}${_si_bad}"
  fi
  _si_bad=''
  for _si_n in $_si_fast; do
    printf '%s\n' "$_si_all" | grep -qx -- "$_si_n" || _si_bad="$_si_bad 越集:$_si_n"
  done
  if [ -n "$_si_fast" ] && [ -z "$_si_bad" ]; then
    ok "套件名自检：FAST_SUITES ⊆ ALL_SUITES（$(printf '%s\n' "$_si_fast" | wc -l | tr -d ' ') 名）"
  else
    bad '套件名自检：FAST_SUITES ⊆ ALL_SUITES' "fast=${_si_fast:-<空>}${_si_bad}"
  fi
  _si_known=$(printf 'all\nfast\n%s\n' "$_si_all")
  _si_bad=''
  for _si_n in $_si_usage; do
    printf '%s\n' "$_si_known" | grep -qx -- "$_si_n" || _si_bad="$_si_bad 未登记名:$_si_n"
  done
  if [ -n "$_si_usage" ] && [ -z "$_si_bad" ]; then
    ok '套件名自检：用法行 ⊆ ALL_SUITES∪{all,fast}'
  else
    bad '套件名自检：用法行 ⊆ ALL_SUITES∪{all,fast}' "用法名单=${_si_usage:-<空>}${_si_bad}"
  fi
  suite_summary 'self-check'
}

# ---- 汇总 ----

suite_summary() {
  n=$((TOTAL - SUITE_START))
  if [ "$SUITE_FAILS" -eq 0 ]; then
    printf 'test-record-layer: [%s] 断言 %d/%d 通过\n' "$1" "$n" "$n"
  else
    printf 'test-record-layer: [%s] 断言 %d/%d 通过（%d 失败）\n' "$1" "$((n - SUITE_FAILS))" "$n" "$SUITE_FAILS"
  fi
  # 汇总行已产出：父进程据此不再补一行（套件提前 exit 时由父进程按日志计数补报）
  if [ -n "${CUR_JOURNAL:-}" ]; then
    : >"$CUR_JOURNAL.summary"
  fi
  return 0
}
