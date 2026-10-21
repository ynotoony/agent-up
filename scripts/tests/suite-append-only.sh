#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite append-only "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: append-only（票 58 场景沉淀：check-append-only.sh 正负例——只追加账本前缀
# 语义＋progress.md 冻结＋懒创建跳过＋无 HEAD WARN＋用法退出码；票 87 增迁移承继
# 语义三例：迁移窗口双 OK、迁移落位稳态、承继不一致负例；票 113 波④夹具翻值
# rules/facts 新形态（R11/R12/R14）：迁移窗口三例按引擎新冻结对（progress.md→
# changes.md 后继）重推，HEAD 旧路径＋工作树后继承继语义不变）
# ============================================================

ao_git_commit() {
  # $1=夹具仓根：全量暂存并提交（本地身份经 -c 内联，零全局污染）
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm fixture
}

ao_build_fixture() {
  # $1=夹具仓根：三守卫对象齐备（changes.jsonl 3 行／micro.jsonl 1 行／progress.md 冻结；
  # 票 113 波④：facts/project/ 账本＋facts/project/archive/ 冻结件）
  R=$1
  rm -rf "$R"
  mkdir -p "$R/facts/project/archive"
  printf 'l1\nl2\nl3\n' > "$R/facts/project/changes.jsonl"
  printf '{"date": "2026-09-21", "lane": "micro", "whitelist": "a.txt", "gates": "PASS", "verify": 1, "commit": "x"}\n' > "$R/facts/project/micro.jsonl"
  printf '# 冻结历史档案（fixture）\n' > "$R/facts/project/archive/progress.md"
  git -C "$R" init -q
  ao_git_commit "$R"
}

suite_append_only() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='append-only'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/ao
  mkdir -p "$D"
  AO="$SCRIPT_DIR/check-append-only.sh"

  # 正例 P1：changes.jsonl 尾部追加 → exit 0（历史前缀核对通过）
  ao_build_fixture "$D/p1"
  printf 'l4\n' >> "$D/p1/facts/project/changes.jsonl"
  sh "$AO" "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: facts/project/changes.jsonl（尾部追加 1 行，历史前缀核对通过）' "$D/p1.out"; then
    ok '正例 P1 changes.jsonl 尾部追加 → exit 0（OK 行含追加计数）'
  else
    bad '正例 P1 changes.jsonl 尾部追加 → exit 0（OK 行含追加计数）' "exit=$rc"
  fi

  # 正例 P2：micro.jsonl 同口径追加 → OK；archive/progress.md 零 diff → OK
  ao_build_fixture "$D/p2"
  printf '{"date": "2026-09-21", "lane": "micro", "whitelist": "b.txt", "gates": "PASS", "verify": 1, "commit": "y"}\n' >> "$D/p2/facts/project/micro.jsonl"
  sh "$AO" "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: facts/project/micro.jsonl（尾部追加 1 行' "$D/p2.out" && grep -q 'OK: facts/project/archive/progress.md（与 HEAD 一致，零 diff）' "$D/p2.out"; then
    ok '正例 P2 micro.jsonl 追加＋progress.md 零 diff → exit 0（micro.jsonl 同口径）'
  else
    bad '正例 P2 micro.jsonl 追加＋progress.md 零 diff → exit 0（micro.jsonl 同口径）' "exit=$rc"
  fi

  # 负例 N1：中间插入 → exit 1 指名文件与首个违规行号（新文件行号 2）
  ao_build_fixture "$D/n1"
  sed '2i\
INSERTED' "$D/n1/facts/project/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n1/facts/project/changes.jsonl"
  sh "$AO" "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/changes.jsonl 历史行被改写或中间插入' "$D/n1.out" && grep -q '首个违规行号 2（新文件行号）' "$D/n1.out"; then
    ok '负例 N1 changes.jsonl 中间插入 → exit 1 指名文件与首个违规行号 2'
  else
    bad '负例 N1 changes.jsonl 中间插入 → exit 1 指名文件与首个违规行号 2' "exit=$rc"
  fi

  # 负例 N2：改写历史行 → exit 1 指名首个违规行号
  ao_build_fixture "$D/n2"
  sed '2s/.*/REWRITTEN/' "$D/n2/facts/project/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n2/facts/project/changes.jsonl"
  sh "$AO" "$D/n2" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/changes.jsonl' "$D/n2.out"; then
    ok '负例 N2 changes.jsonl 改写历史行 → exit 1 指名文件'
  else
    bad '负例 N2 changes.jsonl 改写历史行 → exit 1 指名文件' "exit=$rc"
  fi

  # 负例 N3：截断（删尾行）→ exit 1
  ao_build_fixture "$D/n3"
  sed '$d' "$D/n3/facts/project/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n3/facts/project/changes.jsonl"
  sh "$AO" "$D/n3" > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/changes.jsonl' "$D/n3.out"; then
    ok '负例 N3 changes.jsonl 截断 → exit 1'
  else
    bad '负例 N3 changes.jsonl 截断 → exit 1' "exit=$rc"
  fi

  # 负例 N4：账本删除（HEAD 有、工作树无）→ exit 1
  ao_build_fixture "$D/n4"
  rm -f "$D/n4/facts/project/changes.jsonl"
  sh "$AO" "$D/n4" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/changes.jsonl 在 HEAD 存在但工作树缺失（只追加账本不得删除历史）' "$D/n4.out"; then
    ok '负例 N4 changes.jsonl 工作树删除 → exit 1（不得删除历史）'
  else
    bad '负例 N4 changes.jsonl 工作树删除 → exit 1（不得删除历史）' "exit=$rc"
  fi

  # 负例 N5：archive/progress.md 篡改 → exit 1（冻结档案任何 diff 即违规）
  ao_build_fixture "$D/n5"
  printf '# 冻结历史档案（fixture）篡改行\n' >> "$D/n5/facts/project/archive/progress.md"
  sh "$AO" "$D/n5" > "$D/n5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/archive/progress.md 冻结历史档案出现 diff' "$D/n5.out"; then
    ok '负例 N5 progress.md 篡改 → exit 1（冻结档案零 diff）'
  else
    bad '负例 N5 progress.md 篡改 → exit 1（冻结档案零 diff）' "exit=$rc"
  fi

  # 负例 N6：micro.jsonl 中间插入 → exit 1（同口径覆盖第二账本）
  ao_build_fixture "$D/n6"
  sed '1i\
EARLY' "$D/n6/facts/project/micro.jsonl" > "$D/x" && mv "$D/x" "$D/n6/facts/project/micro.jsonl"
  sh "$AO" "$D/n6" > "$D/n6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: facts/project/micro.jsonl' "$D/n6.out"; then
    ok '负例 N6 micro.jsonl 中间插入 → exit 1（与 changes.jsonl 同口径）'
  else
    bad '负例 N6 micro.jsonl 中间插入 → exit 1（与 changes.jsonl 同口径）' "exit=$rc"
  fi

  # 正例 P3：无 Git 基线（无 HEAD）→ WARN 退出 0（票 49 先例，不硬猜）
  rm -rf "$D/p3"; mkdir -p "$D/p3/facts/project"
  printf 'x\n' > "$D/p3/facts/project/changes.jsonl"
  git -C "$D/p3" init -q
  sh "$AO" "$D/p3" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'WARN: 无 Git 基线（无 HEAD）' "$D/p3.out"; then
    ok '正例 P3 无 Git 基线（无 HEAD）→ WARN 退出 0（不硬猜基线）'
  else
    bad '正例 P3 无 Git 基线（无 HEAD）→ WARN 退出 0（不硬猜基线）' "exit=$rc"
  fi

  # 正例 P4：懒创建语义——两账本与冻结件均不存在 → SKIP 且 exit 0；
  # changes.jsonl 工作树新建（HEAD 无）→ 全部行为追加 OK。
  rm -rf "$D/p4"; mkdir -p "$D/p4"
  printf 'seed\n' > "$D/p4/seed"
  git -C "$D/p4" init -q
  ao_git_commit "$D/p4"
  mkdir -p "$D/p4/facts/project"
  printf 'new\n' > "$D/p4/facts/project/changes.jsonl"
  sh "$AO" "$D/p4" > "$D/p4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: facts/project/changes.jsonl（工作树新建，全部行为追加，懒创建语义）' "$D/p4.out" && grep -q 'SKIP: facts/project/micro.jsonl（不存在，懒创建语义）' "$D/p4.out" && grep -q 'SKIP: facts/project/archive/progress.md（不存在）' "$D/p4.out"; then
    ok '正例 P4 懒创建（新建账本 OK＋缺失 SKIP）→ exit 0'
  else
    bad '正例 P4 懒创建（新建账本 OK＋缺失 SKIP）→ exit 0' "exit=$rc"
  fi

  # 正例 P5：迁移窗口（票 87；票 113 波④按引擎新冻结对重推）——HEAD 有
  # facts/project/archive/progress.md，工作树迁至后继 facts/project/archive/changes.md
  # （旧路径删除、内容逐字节承继）→ exit 0 双 OK。
  ao_build_fixture "$D/p5"
  mv "$D/p5/facts/project/archive/progress.md" "$D/p5/facts/project/archive/changes.md"
  sh "$AO" "$D/p5" > "$D/p5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q 'OK: facts/project/archive/changes.md（迁移承继：与 HEAD facts/project/archive/progress.md 逐字节一致，票 87）' "$D/p5.out" \
    && grep -q 'OK: facts/project/archive/progress.md（已迁移至 facts/project/archive/changes.md，内容承继核对通过，票 87）' "$D/p5.out"; then
    ok '正例 P5 迁移窗口（HEAD 旧路径＋工作树后继逐字节承继）→ exit 0 双 OK'
  else
    bad '正例 P5 迁移窗口（HEAD 旧路径＋工作树后继逐字节承继）→ exit 0 双 OK' "exit=$rc"
  fi

  # 正例 P6：迁移落位稳态（票 87；票 113 波④按引擎新冻结对重推）——迁移入 HEAD 后
  # 再跑 → 后继 OK＋旧路径 SKIP。
  ao_build_fixture "$D/p6"
  mv "$D/p6/facts/project/archive/progress.md" "$D/p6/facts/project/archive/changes.md"
  ao_git_commit "$D/p6"
  sh "$AO" "$D/p6" > "$D/p6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q 'OK: facts/project/archive/changes.md（与 HEAD 一致，零 diff）' "$D/p6.out" \
    && grep -q 'SKIP: facts/project/archive/progress.md（不存在）' "$D/p6.out"; then
    ok '正例 P6 迁移落位稳态（HEAD 与工作树均为后继路径）→ exit 0（后继 OK＋旧路径 SKIP）'
  else
    bad '正例 P6 迁移落位稳态（HEAD 与工作树均为后继路径）→ exit 0（后继 OK＋旧路径 SKIP）' "exit=$rc"
  fi

  # 负例 N10：迁移承继不一致（票 87；票 113 波④按引擎新冻结对重推）——后继 ≠ HEAD
  # 旧路径内容且旧路径工作树缺失 → exit 1 双 FAIL（后继相对 HEAD 出现新内容＋旧路径
  # 工作树缺失）。
  ao_build_fixture "$D/n10"
  cp "$D/n10/facts/project/archive/progress.md" "$D/n10/facts/project/archive/changes.md"
  printf '篡改行\n' >> "$D/n10/facts/project/archive/changes.md"
  rm -f "$D/n10/facts/project/archive/progress.md"
  sh "$AO" "$D/n10" > "$D/n10.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q 'FAIL: facts/project/archive/changes.md 冻结历史档案相对 HEAD 出现新内容' "$D/n10.out" \
    && grep -q 'FAIL: facts/project/archive/progress.md 冻结历史档案在 HEAD 存在但工作树缺失' "$D/n10.out"; then
    ok '负例 N10 迁移承继不一致（后继新增内容＋旧路径缺失）→ exit 1 双 FAIL'
  else
    bad '负例 N10 迁移承继不一致（后继新增内容＋旧路径缺失）→ exit 1 双 FAIL' "exit=$rc"
  fi

  # 用法负例 N7：无参数 → exit 2；多参数 → exit 2；非 Git 目录 → exit 2
  sh "$AO" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N7 无参数 → exit 2'
  else
    bad '负例 N7 无参数 → exit 2' "exit=$rc"
  fi
  sh "$AO" a b >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N8 两参数 → exit 2'
  else
    bad '负例 N8 两参数 → exit 2' "exit=$rc"
  fi
  mkdir -p "$D/nogit"
  sh "$AO" "$D/nogit" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N9 非 Git 目录 → exit 2'
  else
    bad '负例 N9 非 Git 目录 → exit 2' "exit=$rc"
  fi

  suite_summary 'append-only'
}
