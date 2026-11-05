#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite progress "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: progress（票 35 场景沉淀：生成/--check/篡改检出/fail-closed；票 113 波④夹具
# 索引落 facts/requirements/tickets/，checkpoint_ref 数据值按 R25 翻 facts/requirements/runs/；
# 票 206 两布局（agent-up/scripts／rules/implementation/scripts）裸跑缺省根推导正例
# ＋非标落位 fail-closed 负例；票表生成块 --check-readme 新模式四例：迁移包裹且块外逐字节
# 不变、未迁移 exit 1 指名、手改漂移 exit 1 报 path:line 与差异行、无票表 SKIP exit 0 零副作用）
# ============================================================

suite_progress() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='progress'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/prog
  mkdir -p "$D"
  P=$D/fix
  mkdir -p "$P/facts/requirements/tickets"
  cat > "$P/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "12-yankee-first", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T12:00"},
    {"id": "03-zulu-third", "status": "ready", "complexity": "C0", "blocked_by": [], "updated_at": "2026-09-19T08:00"},
    {"id": "07-xray-second", "status": "review_pass", "complexity": "C2", "blocked_by": ["03-zulu-third"], "checkpoint_ref": "facts/requirements/runs/20260918-t07impl.json", "updated_at": "2026-09-19T09:30"}
  ]
}
EOF
  sh "$SCRIPT_DIR/generate-progress.sh" "$P" >"$D/gen.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '生成 exit 0（乱序 id 索引）'
  else
    bad '生成 exit 0（乱序 id 索引）' "exit=$rc $(head -n 1 "$D/gen.log")"
  fi

  {
    printf '<!-- generated_from: facts/requirements/tickets/index.json + rules/implementation/scripts/generate-progress.sh -->\n'
    printf '<!-- generated_at: NORMALIZED -->\n'
    printf '<!-- coverage: facts/requirements/tickets/index.json 登记的全部票，每票一行，按 id 升序 -->\n'
    printf '<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 facts/requirements/tickets/index.json 不一致时以索引为准 -->\n'
    printf '\n# 现役状态投影（Derived）\n\n'
    printf '| id | status | checkpoint_ref | updated_at |\n'
    printf '| --- | --- | --- | --- |\n'
    printf '%s\n' \
      '| 03-zulu-third | ready |  | 2026-09-19T08:00 |' \
      '| 07-xray-second | review_pass | facts/requirements/runs/20260918-t07impl.json | 2026-09-19T09:30 |' \
      '| 12-yankee-first | in_progress |  | 2026-09-19T12:00 |' | LC_ALL=C sort
  } > "$D/exp.md"
  tix_norm_progress "$P/facts/requirements/tickets/progress-current.md" > "$D/act.md"
  assert_eq '投影全文件逐一相等（含 checkpoint_ref 列与空单元格，generated_at 规范化）' "$D/act.md" "$D/exp.md"

  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '--check 一致 exit 0（dry-run 不写）'
  else
    bad '--check 一致 exit 0（dry-run 不写）' "exit=$rc"
  fi

  sed 's/| ready |/| done |/' "$P/facts/requirements/tickets/progress-current.md" > "$D/tamper.tmp" && mv "$D/tamper.tmp" "$P/facts/requirements/tickets/progress-current.md"
  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok '篡改检出 → --check exit 1（投影 stale）'
  else
    bad '篡改检出 → --check exit 1（投影 stale）' "exit=$rc"
  fi

  rm -f "$P/facts/requirements/tickets/progress-current.md"
  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok '投影缺失 → --check exit 1（先运行生成器落盘）'
  else
    bad '投影缺失 → --check exit 1（先运行生成器落盘）' "exit=$rc"
  fi

  mkdir -p "$D/noindex/facts/requirements/tickets"
  sh "$SCRIPT_DIR/generate-progress.sh" "$D/noindex" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '索引缺失 → exit 2（fail-closed 不写投影）'
  else
    bad '索引缺失 → exit 2（fail-closed 不写投影）' "exit=$rc"
  fi

  mkdir -p "$D/badidx/facts/requirements/tickets"
  cat > "$D/badidx/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": []}
  ]
}
EOF
  sh "$SCRIPT_DIR/generate-progress.sh" "$D/badidx" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '条目行缺必备字段（updated_at）→ exit 2'
  else
    bad '条目行缺必备字段（updated_at）→ exit 2' "exit=$rc"
  fi

  # ---- 票 206：两布局裸跑缺省根推导（真实脚本复制进临时仓，无参生成＋--check；
  #      展开一律 ${} 花括号——全角标点紧邻时 bash UTF-8 locale 会把后续字节并入变量名）----
  for prog206_layout in 'agent-up/scripts' 'rules/implementation/scripts'; do
    prog206_root="${T}/prog206-$(printf '%s' "${prog206_layout}" | tr '/' '-')"
    mkdir -p "${prog206_root}/${prog206_layout}" "${prog206_root}/facts/requirements/tickets"
    cp "${SCRIPT_DIR}/generate-progress.sh" "${SCRIPT_DIR}/common-helpers.sh" "${SCRIPT_DIR}/json-validator.py" "${prog206_root}/${prog206_layout}/"
    cat > "${prog206_root}/facts/requirements/tickets/index.json" <<'EOF'
{
  "issues": [
    {"id": "01-alfa-only", "status": "ready", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-23T00:00"}
  ]
}
EOF
    sh "${prog206_root}/${prog206_layout}/generate-progress.sh" >"${prog206_root}/gen.log" 2>&1
    prog206_rc=$?
    if [ "${prog206_rc}" -eq 0 ]; then
      ok "裸跑生成 exit 0（落位 ${prog206_layout}，无参缺省根推导）"
    else
      bad "裸跑生成 exit 0（落位 ${prog206_layout}，无参缺省根推导）" "exit=${prog206_rc} $(head -n 1 "${prog206_root}/gen.log")"
    fi
    if [ -f "${prog206_root}/facts/requirements/tickets/progress-current.md" ]; then
      ok "投影落盘于推导根（落位 ${prog206_layout}）"
    else
      bad "投影落盘于推导根（落位 ${prog206_layout}）" "progress-current.md 未出现在夹具仓根"
    fi
    sh "${prog206_root}/${prog206_layout}/generate-progress.sh" --check >"${prog206_root}/chk.log" 2>&1
    prog206_rc=$?
    if [ "${prog206_rc}" -eq 0 ]; then
      ok "裸跑 --check exit 0（落位 ${prog206_layout}）"
    else
      bad "裸跑 --check exit 0（落位 ${prog206_layout}）" "exit=${prog206_rc} $(head -n 1 "${prog206_root}/chk.log")"
    fi
  done

  # ---- 票 206：非标落位裸跑，推导根无索引 → exit 2（fail-closed 语义保持）----
  prog206_lonely="${T}/prog206-lonely/nested/deep"
  mkdir -p "${prog206_lonely}"
  cp "${SCRIPT_DIR}/generate-progress.sh" "${SCRIPT_DIR}/common-helpers.sh" "${SCRIPT_DIR}/json-validator.py" "${prog206_lonely}/"
  sh "${prog206_lonely}/generate-progress.sh" >"${T}/prog206-lonely/err.log" 2>&1
  prog206_rc=$?
  if [ "${prog206_rc}" -eq 2 ]; then
    ok '非标落位裸跑索引缺失 → exit 2（fail-closed 不写投影）'
  else
    bad '非标落位裸跑索引缺失 → exit 2（fail-closed 不写投影）' "exit=${prog206_rc} $(head -n 1 "${T}/prog206-lonely/err.log")"
  fi

  # ---- 票表生成块（README 票表索引派生）与 --check-readme 新模式四例 ----
  # 夹具沿用本套件 mktemp 风格：有票表无标记 README（迁移前形态）＋索引两条目（02 状态与
  # README 存量 token 故意不同，验证状态列按索引派生）。
  prog_rm=$D/rm
  mkdir -p "$prog_rm/facts/requirements/tickets"
  cat > "$prog_rm/facts/requirements/tickets/index.json" <<'EOF'
 {
  "issues": [
    {"id": "01-alfa", "status": "ready", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-01T09:00"},
    {"id": "02-beta", "status": "done", "complexity": "C0", "blocked_by": [], "updated_at": "2026-10-02T09:00"}
  ]
 }
EOF
  cat > "$prog_rm/facts/requirements/tickets/README.md" <<'EOF'
# issues

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `01-alfa.json` | 任务票 01；`ready`（2026-10-01 开票） | alfa row |
| `02-beta.json` | 任务票 02；`ready`（2026-10-02 开票） | beta row |
EOF
  sed -n '1,/^[|] /p' "$prog_rm/facts/requirements/tickets/README.md" | sed '$d' > "$D/rm.outside.before"

  # ② 未迁移：有目录清单表但无生成块标记 → --check-readme exit 1 并指名
  sh "$SCRIPT_DIR/generate-progress.sh" --check-readme "$prog_rm" >"$D/rm-unmig.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '未迁移为生成块' "$D/rm-unmig.out"; then
    ok '票表生成块②未迁移：--check-readme exit 1 并指名「未迁移为生成块」'
  else
    bad '票表生成块②未迁移：--check-readme exit 1 并指名「未迁移为生成块」' "exit=$rc $(head -n 1 "$D/rm-unmig.out")"
  fi

  # ① 迁移包裹：生成器把既有目录清单表包成生成块，状态列按索引派生，块外逐字节不变
  sh "$SCRIPT_DIR/generate-progress.sh" "$prog_rm" >"$D/rm-mig.out" 2>&1
  rc=$?
  sed '/^<!-- tickets-readme: generated from=/,/^<!-- \/tickets-readme -->$/d' "$prog_rm/facts/requirements/tickets/README.md" > "$D/rm.outside.after"
  # shellcheck disable=SC2016  # 反引号是 README 表格字面串的一部分（非命令替换；改双引号会触发执行）
  prog_rm_row01='| `01-alfa.json` | 任务票 01；`ready`（2026-10-01 开票） | alfa row |'
  # shellcheck disable=SC2016  # 同上：反引号是字面串的一部分，非命令替换
  prog_rm_row02='| `02-beta.json` | 任务票 02；`done`（2026-10-02 开票） | beta row |'
  if [ "$rc" -eq 0 ] \
    && [ "$(grep -c 'tickets-readme' "$prog_rm/facts/requirements/tickets/README.md")" = '2' ] \
    && grep -q -F -- "$prog_rm_row01" "$prog_rm/facts/requirements/tickets/README.md" \
    && grep -q -F -- "$prog_rm_row02" "$prog_rm/facts/requirements/tickets/README.md" \
    && cmp -s "$D/rm.outside.before" "$D/rm.outside.after"; then
    ok '票表生成块①迁移包裹：有票表无标记 README 包成生成块（标记恰 2）、状态列按索引派生、块外逐字节不变'
  else
    bad '票表生成块①迁移包裹：有票表无标记 README 包成生成块（标记恰 2）、状态列按索引派生、块外逐字节不变' "exit=$rc 标记=$(grep -c 'tickets-readme' "$prog_rm/facts/requirements/tickets/README.md") $(head -n 1 "$D/rm-mig.out")"
  fi

  # ③ 手改漂移：块内状态 token 被手工改（done→ready）→ --check-readme exit 1 报 path:line 与差异行
  # shellcheck disable=SC2016  # 反引号是 sed 表达式里的字面状态 token（非命令替换）
  prog_rm_tamper='s/任务票 02；`done`/任务票 02；`ready`/'
  sed "$prog_rm_tamper" "$prog_rm/facts/requirements/tickets/README.md" > "$D/rm.tamper.tmp" \
    && mv "$D/rm.tamper.tmp" "$prog_rm/facts/requirements/tickets/README.md"
  sh "$SCRIPT_DIR/generate-progress.sh" --check-readme "$prog_rm" >"$D/rm-drift.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '票表生成块与索引派生不一致' "$D/rm-drift.out" \
    && grep -qE 'README.md:[0-9]+: 票表生成块与索引派生不一致' "$D/rm-drift.out" \
    && grep -q '差异:' "$D/rm-drift.out"; then
    ok '票表生成块③手改漂移：块内状态 token 手改 → --check-readme exit 1 报 path:line 与差异行'
  else
    bad '票表生成块③手改漂移：块内状态 token 手改 → --check-readme exit 1 报 path:line 与差异行' "exit=$rc $(head -n 1 "$D/rm-drift.out")"
  fi

  # ④ 无票表 README：既无生成块亦无目录清单表 → --check-readme SKIP exit 0 且零副作用
  prog_rm2=$D/rm-notable
  mkdir -p "$prog_rm2/facts/requirements/tickets"
  cp "$prog_rm/facts/requirements/tickets/index.json" "$prog_rm2/facts/requirements/tickets/index.json"
  printf '# issues\n\n仅是说明文字，无票表。\n' > "$prog_rm2/facts/requirements/tickets/README.md"
  prog_rm2_ck0=$(cksum "$prog_rm2/facts/requirements/tickets/README.md")
  sh "$SCRIPT_DIR/generate-progress.sh" --check-readme "$prog_rm2" >"$D/rm-notable.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q 'CHECK: SKIP' "$D/rm-notable.out" \
    && [ "$prog_rm2_ck0" = "$(cksum "$prog_rm2/facts/requirements/tickets/README.md")" ]; then
    ok '票表生成块④无票表 README：--check-readme SKIP exit 0 且 README 字节零变化（不新建块）'
  else
    bad '票表生成块④无票表 README：--check-readme SKIP exit 0 且 README 字节零变化（不新建块）' "exit=$rc $(head -n 1 "$D/rm-notable.out")"
  fi

  suite_summary 'progress'
}
