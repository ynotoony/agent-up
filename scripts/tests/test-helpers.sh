
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
  for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh worktree-add.sh install.sh install-policy.rules; do
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
