# shellcheck shell=sh  # 本文件只被 test-runner/套件 source（无 shebang，执行入口在 test-runner.sh）

ok() {
  TOTAL=$((TOTAL + 1))
  printf 'PASS  [%s] %s\n' "$CUR_SUITE" "$1"
}

bad() {
  TOTAL=$((TOTAL + 1))
  FAILS=$((FAILS + 1))
  SUITE_FAILS=$((SUITE_FAILS + 1))
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
cleanup() { [ -n "$T" ] && rm -rf "$T"; return 0; }

tix_norm_progress() {
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$1"
}

# ============================================================
# 注入自检（仅 --suite all）：临时副本上故意破坏一处，harness 必须抓住
# ============================================================

self_check_injection() {
  CUR_SUITE='self-check'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/inject
  mkdir -p "$D/injectpkg/scripts"
  for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh worktree-add.sh dp-load-rules.sh install.sh install-policy.rules; do
    cp "$SCRIPT_DIR/$f" "$D/injectpkg/scripts/$f"
  done
  sed 's/~python-import~/~python-importX~/' "$SCRIPT_DIR/module-map.rules" > "$D/rules.tmp" && mv "$D/rules.tmp" "$D/injectpkg/scripts/module-map.rules"
  sh "$0" --suite module-map --script-dir "$D/injectpkg/scripts" >"$D/out.log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    ok '注入自检 exit 非零（harness 抓住临时副本上的边集破坏）'
  else
    bad '注入自检 exit 非零（harness 抓住临时副本上的边集破坏）' '注入运行意外通过'
  fi
  if grep -q '^FAIL' "$D/out.log"; then
    ok '注入自检输出含 FAIL 逐项行（失败可定位）'
  else
    bad '注入自检输出含 FAIL 逐项行（失败可定位）' '无 FAIL 行'
  fi
  # 自检：套件名三处名单同集合——派发 case 名 ⊆ 校验名单 ⊆ 用法行。
  # 缺名会让 --suite <name> 被拒而派发分支成死码（票 257 删重复行时丢过 merge）。
  _si_runner=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/test-runner.sh
  _si_dispatch=$(sed -n 's/^  \([a-z][a-z-]*\)) suite_[a-z_]* ;;$/\1/p' "$_si_runner")
  _si_valid=$(sed -n 's/^  \(module-map|[a-z|-]*\)) ;;$/\1/p' "$_si_runner" \
    | tr '|' '\n' | sed '/^$/d')
  _si_usage=$(sed -n 's/^ *--suite <name> *\(module-map.*\)$/\1/p' "$_si_runner" \
    | sed 's/（.*//' | tr '|' '\n' | sed 's/^ *//; s/ *$//' | sed '/^$/d')
  _si_bad=''
  for _si_n in $_si_dispatch; do
    printf '%s\n' "$_si_valid" | grep -qx -- "$_si_n" || _si_bad="$_si_bad 派发缺校验:$_si_n"
  done
  if [ -n "$_si_dispatch" ] && [ -n "$_si_valid" ] && [ -z "$_si_bad" ]; then
    ok "套件名自检：派发 case 名 ⊆ 校验名单（$(printf '%s\n' "$_si_dispatch" | wc -l | tr -d ' ') 名）"
  else
    bad '套件名自检：派发 case 名 ⊆ 校验名单' "校验名单=${_si_valid:-<空>}${_si_bad}"
  fi
  _si_bad=''
  for _si_n in $_si_valid; do
    printf '%s\n' "$_si_usage" | grep -qx -- "$_si_n" || _si_bad="$_si_bad 校验缺用法:$_si_n"
  done
  if [ -n "$_si_usage" ] && [ -z "$_si_bad" ]; then
    ok "套件名自检：校验名单 ⊆ 用法行（$(printf '%s\n' "$_si_valid" | wc -l | tr -d ' ') 名）"
  else
    bad '套件名自检：校验名单 ⊆ 用法行' "用法名单=${_si_usage:-<空>}${_si_bad}"
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
}
