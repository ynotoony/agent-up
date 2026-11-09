#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite check-package-direct "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: check-package-direct（票 291 自 suite-check-package 拆出的注册表分发与定向运行面）：
# 票 273 注册表分发 fail-closed 三例与输出完整性守卫；票 278 --only 定向运行语义
# （选中集合恰等、未选中检查零执行）及变异自检（受控变异必翻红）。

suite_check_package_direct() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='check-package-direct'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/DIRcheck-package-direct
  mkdir -p "$D"
  REPO_SIDE="$PKG_ROOT/../rules/implementation/scripts"
  CP_ONLY_IDS=''
  if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    printf 'SKIP  [check-package-direct] main-only 件不在场（worktree 栅栏）——夹具无法成立，覆盖归主检出\n'
    suite_summary 'check-package-direct'
    return 0
  fi
  cp_manifest="$PKG_ROOT/scripts/package-manifest.rules"
  cp_n_entries=$(LC_ALL=C grep -c '^pm_entry ' "$cp_manifest" 2>/dev/null || true)
  cp_n_templates=$(LC_ALL=C grep -c '^pm_template ' "$cp_manifest" 2>/dev/null || true)
  cp_n_scripts=$(LC_ALL=C grep -c '^pm_script ' "$cp_manifest" 2>/dev/null || true)
  cp_mirror_pairs=0
  # shellcheck disable=SC2013  # manifest pm_mirror 文件名为单 token（清单加载段禁空白），词分隔循环安全
  for _cpm in $(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$cp_manifest"); do
    if [ -f "$PKG_ROOT/scripts/$_cpm" ]; then cp_mirror_pairs=$((cp_mirror_pairs + 1)); fi
  done

  # 票 273：注册表分发 fail-closed 三例（残缺输出不得 exit 0；一致退役不得连带打崩其余件）。
  # 用例 R1：注册表侧退役但清单未同步 → 加载期 exit 2，stdout 零残缺输出。
  cp -R "${PKG_ROOT}" "${D}/pkgreg1"
  grep -v '^chk 6 ' "${D}/pkgreg1/scripts/checks/registry.rules" > "${D}/reg1.a"
  LC_ALL=C awk '{ print } /^chk_retired 23$/ { print "chk_retired 6" }' "${D}/reg1.a" > "${D}/reg1.b"
  mv "${D}/reg1.b" "${D}/pkgreg1/scripts/checks/registry.rules"
  rm -f "${D}/reg1.a"
  : > "${D}/act.reg1"
  : > "${D}/err.reg1"
  CP_ONLY_IDS=''
  sh "${D}/pkgreg1/scripts/check-package.sh" "${D}/pkgreg1" >"${D}/act.reg1" 2>"${D}/err.reg1"
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "${D}/act.reg1" ] && grep -q '注册项数不一致' "${D}/err.reg1"; then
    ok '用例 R1 注册表退役但清单未同步 → exit 2 且 stdout 零残缺输出'
  else
    bad '用例 R1 注册表退役但清单未同步 → exit 2 且 stdout 零残缺输出' "exit=$rc stdout=$(head -c 120 "${D}/act.reg1" | tr '\n' '|')"
  fi

  # 用例 R2：人为让一个检查件崩溃（unbound variable）→ exit 2，stdout 零残缺输出。
  cp -R "${PKG_ROOT}" "${D}/pkgreg2"
  LC_ALL=C awk '{ print } /^check_10\(\) \{$/ { print "  : \"$chk_crash_probe_zzz\"" }' \
    "${D}/pkgreg2/scripts/checks/10-rule-shortcodes.sh" > "${D}/reg2.a"
  mv "${D}/reg2.a" "${D}/pkgreg2/scripts/checks/10-rule-shortcodes.sh"
  : > "${D}/act.reg2"
  : > "${D}/err.reg2"
  CP_ONLY_IDS=''
  sh "${D}/pkgreg2/scripts/check-package.sh" "${D}/pkgreg2" >"${D}/act.reg2" 2>"${D}/err.reg2"
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "${D}/act.reg2" ] && grep -q '检查 10 执行异常中止' "${D}/err.reg2"; then
    ok '用例 R2 检查件崩溃 → exit 2 且 stdout 零残缺输出（不 fail-open）'
  else
    bad '用例 R2 检查件崩溃 → exit 2 且 stdout 零残缺输出（不 fail-open）' "exit=$rc stdout=$(head -c 120 "${D}/act.reg2" | tr '\n' '|')"
  fi

  # 用例 R3：正常退役一件且 registry＋manifest 同步 → exit 0、其余件照常判定、汇总 PASS。
  cp -R "${PKG_ROOT}" "${D}/pkgreg3"
  grep -v '^chk 6 ' "${D}/pkgreg3/scripts/checks/registry.rules" > "${D}/reg3.a"
  LC_ALL=C awk '{ print } /^chk_retired 23$/ { print "chk_retired 6" }' "${D}/reg3.a" > "${D}/reg3.b"
  mv "${D}/reg3.b" "${D}/pkgreg3/scripts/checks/registry.rules"
  grep -v '^pm_check 6 ' "${D}/pkgreg3/scripts/package-manifest.rules" > "${D}/reg3.c"
  LC_ALL=C awk '{ print } /^pm_check_retired 23$/ { print "pm_check_retired 6" }' "${D}/reg3.c" > "${D}/reg3.d"
  mv "${D}/reg3.d" "${D}/pkgreg3/scripts/package-manifest.rules"
  rm -f "${D}/reg3.a" "${D}/reg3.c"
  : > "${D}/act.reg3"
  : > "${D}/err.reg3"
  CP_ONLY_IDS=''
  sh "${D}/pkgreg3/scripts/check-package.sh" "${D}/pkgreg3" >"${D}/act.reg3" 2>"${D}/err.reg3"
  rc=$?
  # 副本语境（非 git、无镜像落位）下检查 13/19 静默：期望行数＝在役行数−2，另加汇总行。
  r3_rows=$(LC_ALL=C awk '$1 == "chk" { n++ } END { print n + 0 }' "${D}/pkgreg3/scripts/checks/registry.rules")
  r3_expect=$((r3_rows - 2))
  r3_dep_ok=1
  for _r3n in 10 12 15 22; do
    grep -q "^PASS: ${_r3n} " "${D}/act.reg3" || r3_dep_ok=0
  done
  if [ "$rc" -eq 0 ] && [ ! -s "${D}/err.reg3" ] \
    && [ "$(grep -c '^PASS: ' "${D}/act.reg3")" -eq "$r3_expect" ] \
    && [ "$(wc -l < "${D}/act.reg3" | tr -d ' ')" -eq $((r3_expect + 1)) ] \
    && grep -qxF 'check-package: PASS' "${D}/act.reg3" \
    && ! grep -q '^FAIL: ' "${D}/act.reg3" \
    && ! grep -q '^PASS: 6 ' "${D}/act.reg3" \
    && [ "$r3_dep_ok" -eq 1 ]; then
    ok "用例 R3 一致退役检查 6 → exit 0、PASS $r3_expect 行＋汇总、依赖件 10/12/15/22 照常判定"
  else
    bad '用例 R3 一致退役检查 6 → exit 0、其余件照常判定、汇总 PASS' \
      "exit=$rc pass=$(grep -c '^PASS: ' "${D}/act.reg3" 2>/dev/null) lines=$(wc -l < "${D}/act.reg3" 2>/dev/null) dep_ok=$r3_dep_ok err=$(head -c 120 "${D}/err.reg3" | tr '\n' '|')"
  fi


  # 票 273 P2 守卫回归 R4：输出完整性守卫双向（缺号/多余号）不得 fail-open。
  # 票 278 起定向运行（--only 12）：守卫按「选中集合 − 语境静默面」比对，缺号/多余号两向
  # 判定与全量同构，夹具只需检查 12 一件即可覆盖两向（耗时从整套约 9s 降到单件）。
  # R4a 缺号：检查 12 提前 return 0（不产行、不设描述）→ exit 2、stdout 0 字节、stderr 指名缺失号 12。
  pkg_copy "$PKG_ROOT" "$D/pkgreg4"
  LC_ALL=C awk '{ print } /^check_12\(\) \{$/ { print "  return 0" }' \
    "$D/pkgreg4/scripts/checks/12-vague-words.sh" > "$D/reg4.a"
  mv "$D/reg4.a" "$D/pkgreg4/scripts/checks/12-vague-words.sh"
  : > "$D/act.reg4a"
  : > "$D/err.reg4a"
  CP_ONLY_IDS='12'
  sh "$D/pkgreg4/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgreg4" > "$D/act.reg4a" 2> "$D/err.reg4a"
  rc=$?
  r4_bad=''
  [ "$rc" -eq 2 ] || r4_bad="$r4_bad 缺号rc=$rc"
  [ ! -s "$D/act.reg4a" ] || r4_bad="$r4_bad 缺号stdout非空"
  grep -q '缺失号' "$D/err.reg4a" || r4_bad="$r4_bad 缺号未指名"
  grep -qE '(^|[^0-9])12([^0-9]|$)' "$D/err.reg4a" || r4_bad="$r4_bad 缺号未指名12"
  # R4b 多余号：检查 12 额外向输出号账本追加 999（多出不属于自己的行）→ exit 2、stdout 0 字节、stderr 指名多余号。
  pkg_copy "$PKG_ROOT" "$D/pkgreg5"
  LC_ALL=C awk '{ print } /^check_12\(\) \{$/ { print "  echo 999 >> \"$chk_emitted_ids\"" }' \
    "$D/pkgreg5/scripts/checks/12-vague-words.sh" > "$D/reg5.a"
  mv "$D/reg5.a" "$D/pkgreg5/scripts/checks/12-vague-words.sh"
  : > "$D/act.reg4b"
  : > "$D/err.reg4b"
  CP_ONLY_IDS='12'
  sh "$D/pkgreg5/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgreg5" > "$D/act.reg4b" 2> "$D/err.reg4b"
  rc=$?
  [ "$rc" -eq 2 ] || r4_bad="$r4_bad 多余号rc=$rc"
  [ ! -s "$D/act.reg4b" ] || r4_bad="$r4_bad 多余号stdout非空"
  grep -q '多余号' "$D/err.reg4b" || r4_bad="$r4_bad 多余号未指名"
  grep -q '999' "$D/err.reg4b" || r4_bad="$r4_bad 多余号未指名999"
  if [ -z "$r4_bad" ]; then
    ok '用例 R4 输出完整性守卫双向（缺号 12／多余号 999 → exit 2 且 stdout 0 字节、stderr 指名）'
  else
    bad '用例 R4 输出完整性守卫双向（缺号 12／多余号 999 → exit 2 且 stdout 0 字节、stderr 指名）' "$r4_bad"
  fi

  # ---- 278 F3：定向运行语义断言（--only 输出恰为选中集合；未选中检查零执行）----
  # 夹具：复制包根，把检查 25 的件替换为「被执行才写哨兵」探针；--only 12 时
  # ①输出行 id 集合恰为 {12}（非选中不得出现）②哨兵不增长（未选中检查不执行）。
  # ③变异自检：把引擎两处 chk_only_mode=1 改成 0（无视 --only 跑全量）后，同一判据
  #    必须翻红（id 集合被全量顶替＋哨兵被写）——断言钉住「定向」语义本身。
  pkg_copy "$PKG_ROOT" "$D/onlyfx"
  cat > "$D/onlyfx/scripts/checks/25-pending-declaration-detection.sh" <<'EOFX'
check_25() {
  printf 'executed\n' >> "${CHK_ONLY_SENTINEL:-/dev/null}"
}
EOFX
  only_sent="$D/onlyfx.sentinel"
  : > "$only_sent"
  CHK_ONLY_SENTINEL="$only_sent" sh "$D/onlyfx/scripts/check-package.sh" --only 12 "$D/onlyfx" >"$D/onlyfx.out" 2>"$D/onlyfx.err"
  rc=$?
  only_ids=$(grep -o '^\(PASS\|FAIL\|SKIP\): [0-9]*' "$D/onlyfx.out" | awk '{print $2}' | LC_ALL=C sort -n | paste -sd, -)
  if [ "$rc" -eq 0 ] && [ "$only_ids" = '12' ] && [ ! -s "$only_sent" ]; then
    ok '定向语义 P-278-F3：--only 12 输出 id 集合恰为 {12} 且未选中检查 25 零执行（哨兵空）'
  else
    bad '定向语义 P-278-F3：--only 12 输出 id 集合恰为 {12} 且未选中检查 25 零执行（哨兵空）' \
      "exit=$rc ids=[$only_ids] sentinel_bytes=$(wc -c < "$only_sent" | tr -d ' ') $(tail -n 2 "$D/onlyfx.err" | tr '\n' '|')"
  fi

  # 变异自检：无视 --only 的引擎必须同时触发上面两条判据（id 集合≠{12}＋哨兵非空）。
  pkg_copy "$D/onlyfx" "$D/onlymut"
  sed 's/chk_only_mode=1/chk_only_mode=0/g' "$D/onlymut/scripts/check-package.sh" > "$D/onlymut/scripts/check-package.sh.tmp" \
    && mv "$D/onlymut/scripts/check-package.sh.tmp" "$D/onlymut/scripts/check-package.sh"
  mut_sent="$D/onlymut.sentinel"
  : > "$mut_sent"
  CHK_ONLY_SENTINEL="$mut_sent" sh "$D/onlymut/scripts/check-package.sh" --only 12 "$D/onlymut" >"$D/onlymut.out" 2>"$D/onlymut.err"
  mut_rc=$?
  mut_ids=$(grep -o '^\(PASS\|FAIL\|SKIP\): [0-9]*' "$D/onlymut.out" | awk '{print $2}' | LC_ALL=C sort -n | paste -sd, -)
  if [ "$mut_ids" != '12' ] && [ -s "$mut_sent" ]; then
    ok '定向语义变异自检：chk_only_mode=1→0 后 id 集合非 {12} 且未选中检查被执行 → 上述断言必红（受控变异可翻红）'
  else
    bad '定向语义变异自检：chk_only_mode=1→0 后 id 集合非 {12} 且未选中检查被执行 → 上述断言必红（受控变异可翻红）' \
      "exit=$mut_rc（变异后守卫 fail-closed 亦算检出）ids=[$mut_ids] sentinel_bytes=$(wc -c < "$mut_sent" | tr -d ' ')"
  fi

  suite_summary 'check-package-direct'
}
