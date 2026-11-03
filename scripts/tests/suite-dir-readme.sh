#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite dir-readme "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: dir-readme（目录 README 四段式契约校验、生成块同步与骨架生成）
# 夹具全部构建于 mktemp 临时目录，仓库零写入；正例断言 exit 0 且 stdout/stderr 双零输出，
# 负例断言 exit 2 且逐条报文指名 相对路径:行 与原因片段。
# ============================================================

dr_base_readme() {
  # $1=目标 README 路径：四段齐全、18 行、引用路径真实、无计数与成员表
  cat > "$1" <<'EOF'
<!-- Input: docs/a.md -->
<!-- Output: 导航 -->
<!-- Pos: 根索引 -->

# docs

文档目录职责说明。

## 权威
- 现行：`docs/a.md`
- 派生：无

## 读取禁忌
- 不把本文件当白名单。

## 子目录
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
| sub | 子目录 | 不递归引用 |
EOF
}

dr_run_dir() {
  # 以 --dir docs 运行一次，结果落 $D/out $D/err $D/rc（供断言读取）
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  printf '%s\n' "$?" > "$D/rc"
}

dr_expect_fail() {
  # $1=场景名 $2=原因片段 $3=期望行号（可选，缺省任意行）：断言 exit 2＋报文含
  # docs/README.md:行 与原因片段
  dr_run_dir
  _rc=$(cat "$D/rc")
  _line_re='^docs/README\.md:[0-9]+: '
  if [ -n "${3:-}" ]; then
    _line_re="^docs/README\\.md:$3: "
  fi
  if [ "$_rc" -eq 2 ] \
    && grep -Eq "$_line_re" "$D/err" \
    && grep -qF "$2" "$D/err"; then
    ok "$1"
  else
    bad "$1" "exit=$_rc stderr=$(head -n 2 "$D/err" 2>/dev/null | tr '\n' '|')"
  fi
}

suite_dir_readme() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='dir-readme'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/dirreadme
  rm -rf "$D"
  mkdir -p "$D"
  G="$SCRIPT_DIR/generate-dir-readmes.sh"
  R=$D/repo
  mkdir -p "$R/docs/sub" "$R/facts"
  : > "$R/docs/a.md"
  : > "$R/facts/b.json"

  # P1 合规 fixture → exit 0 且双零输出
  dr_base_readme "$R/docs/README.md"
  sh "$G" --target "$R" >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 合规 fixture → exit 0 且 stdout/stderr 零输出'
  else
    bad '正例 合规 fixture → exit 0 且 stdout/stderr 零输出' "exit=$rc stdout=$(head -n 1 "$D/out") stderr=$(head -n 1 "$D/err")"
  fi

  # P2 --dir 限定单目录 → exit 0 且零输出
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 --dir 限定单目录 → exit 0 且零输出'
  else
    bad '正例 --dir 限定单目录 → exit 0 且零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # P3 生成块标记成对且 dir 值正确 → exit 0（只校验存在性，不比对内容）
  dr_base_readme "$R/docs/README.md"
  {
    printf '<!-- dir-readme: generated dir=docs -->\n'
    cat "$R/docs/README.md"
    printf '<!-- /dir-readme -->\n'
  } > "$D/marked.md" && mv "$D/marked.md" "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 生成块标记成对 → exit 0'
  else
    bad '正例 生成块标记成对 → exit 0' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N1 缺段 → exit 2 且指名 docs/README.md:行
  dr_base_readme "$R/docs/README.md"
  grep -v '^## 读取禁忌' "$R/docs/README.md" | grep -v '^不把本文件当白名单' > "$D/tmp" && mv "$D/tmp" "$R/docs/README.md"
  dr_expect_fail '负例 缺段（## 读取禁忌）→ exit 2 指名 file:line' '缺少段：## 读取禁忌'

  # N2 超 25 行 → exit 2
  dr_base_readme "$R/docs/README.md"
  dr_i=1
  while [ "$dr_i" -le 8 ]; do
    printf '补充说明第 %s 条。\n' "$dr_i" >> "$R/docs/README.md"
    dr_i=$((dr_i + 1))
  done
  dr_expect_fail '负例 总行数 26 超上限 → exit 2 指名 file:line' '超过上限 25'

  # N3 含成员表 → exit 2
  dr_base_readme "$R/docs/README.md"
  {
    printf '\n## 成员\n'
    printf '| 名字 | 地位 | 功能 |\n'
    printf '| --- | --- | --- |\n'
    printf '| a.md | 文档 | 说明 |\n'
  } >> "$R/docs/README.md"
  dr_expect_fail '负例 含成员表（## 成员）→ exit 2 指名 file:line' '成员表'

  # N4 计数句三形态 → exit 2
  dr_base_readme "$R/docs/README.md"
  printf -- '- 本目录共 3 件文件。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「共 N 件」→ exit 2 指名 file:line' '计数句'

  dr_base_readme "$R/docs/README.md"
  printf -- '- 本目录有 2 个脚本。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「N 个脚本」→ exit 2 指名 file:line' '计数句'

  dr_base_readme "$R/docs/README.md"
  printf -- '- 本目录三个脚本互相引用。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句（中文数字个脚本）→ exit 2 指名 file:line' '计数句'

  # N5 状态句 → exit 2
  dr_base_readme "$R/docs/README.md"
  printf -- '- 当前没有调研报告。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 状态句「当前没有」→ exit 2 指名 file:line' '状态句'

  # N6 幽灵路径 → exit 2
  dr_base_readme "$R/docs/README.md"
  sed 's|`docs/a.md`|`docs/ghost.md`|' "$R/docs/README.md" > "$D/tmp" && mv "$D/tmp" "$R/docs/README.md"
  dr_expect_fail '负例 引用幽灵路径 → exit 2 指名 file:line' '引用路径不存在: docs/ghost.md'

  # N6b 幽灵单文件名（不含 /）：按 README 所在目录校验 → exit 2 且指名该文件名
  dr_base_readme "$R/docs/README.md"
  printf -- '- 参见 `missing-file.md`。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 引用幽灵单文件名 → exit 2 指名 file:line' '引用路径不存在: missing-file.md'

  # P5 同目录单文件名存在 → exit 0；裸标识符（true、--check）不按路径校验
  dr_base_readme "$R/docs/README.md"
  : > "$R/docs/real-file.md"
  {
    printf -- '- 参见 `real-file.md`。\n'
    printf -- '- 状态 `true`，开关 `--check`。\n'
  } >> "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 同目录单文件名存在且裸标识符不校验 → exit 0 零输出'
  else
    bad '正例 同目录单文件名存在且裸标识符不校验 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # P6 N/A 例外（大小写不敏感，可带理由）→ exit 0
  dr_base_readme "$R/docs/README.md"
  {
    printf -- '- 状态 `N/A`。\n'
    printf -- '- 兼容性 `n/a（不适用）`。\n'
  } >> "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 N/A 引用不按路径校验 → exit 0 零输出'
  else
    bad '正例 N/A 引用不按路径校验 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # P7 正文提及「成员／文件」但非表格 → 不误判成员表，exit 0
  dr_base_readme "$R/docs/README.md"
  printf -- '- 本目录不登记成员清单，也不列文件清单。\n' >> "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 正文提及成员／文件非表格 → exit 0 零输出'
  else
    bad '正例 正文提及成员／文件非表格 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N13 成员表（表头含「成员」，2 列以上）→ exit 2 且行号指向表头
  dr_base_readme "$R/docs/README.md"
  {
    printf '\n| 成员 | 身份 | 冻结依据 |\n'
    printf '| --- | --- | --- |\n'
    printf '| a.md | 文档 | 契约 |\n'
  } >> "$R/docs/README.md"
  dr_expect_fail '负例 成员表（表头含「成员」）→ exit 2 指名表头行' '含成员表' 21

  # N14 计数句「三合同」→ exit 2 且行号指向该行
  dr_base_readme "$R/docs/README.md"
  printf -- '- 角色分三合同。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「三合同」→ exit 2 指名行号' '含计数句：三合同' 20

  # N15 计数句「3 份合同」→ exit 2
  dr_base_readme "$R/docs/README.md"
  printf -- '- 本季度 3 份合同已归档。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「3 份合同」→ exit 2' '含计数句：3 份合同' 20

  # N16 计数句「257 行」→ exit 2（行数陈述）
  dr_base_readme "$R/docs/README.md"
  printf -- '- 成员表共 257 行。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「257 行」→ exit 2 指名行号' '含计数句：257 行' 20

  # P8 「一行」「第 3 行」为中文习惯用法，不判计数 → exit 0
  dr_base_readme "$R/docs/README.md"
  {
    printf -- '- 索引一条目一行，单文件定序。\n'
    printf -- '- 一行代码即可复现。\n'
    printf -- '- 参见上文第 3 行。\n'
  } >> "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 「一行」「第 3 行」非计数 → exit 0 零输出'
  else
    bad '正例 「一行」「第 3 行」非计数 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N24 纯计数句「共 257 行」仍判计数 → exit 2
  dr_base_readme "$R/docs/README.md"
  printf -- '- 共 257 行。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「共 257 行」→ exit 2 指名行号' '含计数句：257 行' 20

  # P9 普通两列表（表头单元格不等于成员表关键词）→ exit 0
  dr_base_readme "$R/docs/README.md"
  {
    printf '\n| 检查项 | 依据文件 |\n'
    printf '| --- | --- |\n'
    printf '| 结构 | a.md |\n'
  } >> "$R/docs/README.md"
  sh "$G" --target "$R" --dir docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 两列表「检查项|依据文件」非成员表 → exit 0 零输出'
  else
    bad '正例 两列表「检查项|依据文件」非成员表 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N21／N22 成员表表头「文件」「名字」（无 ## 成员 段）→ exit 2 指名表头行
  dr_base_readme "$R/docs/README.md"
  {
    printf '\n| 文件 | 描述 |\n'
    printf '| --- | --- |\n'
    printf '| a.md | 文档 |\n'
  } >> "$R/docs/README.md"
  dr_expect_fail '负例 成员表表头「文件」→ exit 2 指名表头行' '含成员表' 21

  dr_base_readme "$R/docs/README.md"
  {
    printf '\n| 名字 | 地位 |\n'
    printf '| --- | --- |\n'
    printf '| a | 文档 |\n'
  } >> "$R/docs/README.md"
  dr_expect_fail '负例 成员表表头「名字」→ exit 2 指名表头行' '含成员表' 21

  # N17～N19 计数句「N 个成员／N 份文件／N 张票」→ exit 2
  dr_base_readme "$R/docs/README.md"
  printf -- '- 现有 2 个成员参与维护。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「2 个成员」→ exit 2' '含计数句：2 个成员' 20

  dr_base_readme "$R/docs/README.md"
  printf -- '- 本次提交 3 份文件。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「3 份文件」→ exit 2' '含计数句：3 份文件' 20

  dr_base_readme "$R/docs/README.md"
  printf -- '- 本批 5 张票已收口。\n' >> "$R/docs/README.md"
  dr_expect_fail '负例 计数句「5 张票」→ exit 2' '含计数句：5 张票' 20

  # N20 子目录表头缺分隔行 → exit 2 且行号指向缺失位置
  dr_base_readme "$R/docs/README.md"
  grep -v '^| --- | --- | --- |$' "$R/docs/README.md" > "$D/tmp" && mv "$D/tmp" "$R/docs/README.md"
  dr_expect_fail '负例 子目录表头缺分隔行 → exit 2 指名行号' '子目录表头缺少分隔行' 18

  # N7 生成块未闭合（缺标记）→ exit 2
  dr_base_readme "$R/docs/README.md"
  {
    printf '<!-- dir-readme: generated dir=docs -->\n'
    cat "$R/docs/README.md"
  } > "$D/tmp" && mv "$D/tmp" "$R/docs/README.md"
  dr_expect_fail '负例 生成块未闭合 → exit 2 指名 file:line' '生成块未闭合'

  # N8 无规则文件 → exit 2
  dr_base_readme "$R/docs/README.md"
  sh "$G" --target "$R" --rules "$D/no-such.rules" >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '规则文件不存在或不可读' "$D/err"; then
    ok '负例 规则文件缺失 → exit 2 fail-closed'
  else
    bad '负例 规则文件缺失 → exit 2 fail-closed' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N9 规则文件损坏 → exit 2
  dr_base_readme "$R/docs/README.md"
  printf 'bogus not-a-directive\n' > "$D/broken.rules"
  sh "$G" --target "$R" --rules "$D/broken.rules" >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '规则文件损坏' "$D/err"; then
    ok '负例 规则文件损坏 → exit 2 fail-closed'
  else
    bad '负例 规则文件损坏 → exit 2 fail-closed' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N10 目标路径不存在 → exit 2
  sh "$G" --target "$D/no-such-target" >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '目标路径不存在' "$D/err"; then
    ok '负例 目标路径不存在 → exit 2 fail-closed'
  else
    bad '负例 目标路径不存在 → exit 2 fail-closed' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # P4 --rules 覆盖：排除 docs 后，破损 README 不参与校验 → exit 0 零输出
  dr_base_readme "$R/docs/README.md"
  grep -v '^## 读取禁忌' "$R/docs/README.md" | grep -v '^不把本文件当白名单' > "$D/tmp" && mv "$D/tmp" "$R/docs/README.md"
  dr_base_readme "$R/facts/README.md"
  printf 'include *\nexclude docs/**\n' > "$D/override.rules"
  sh "$G" --target "$R" --rules "$D/override.rules" >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 --rules 覆盖排除面 → exit 0 零输出'
  else
    bad '正例 --rules 覆盖排除面 → exit 0 零输出' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N11 --dir 目录不存在 / 目录内无 README → exit 2
  sh "$G" --target "$R" --dir no-such-dir >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '目录不存在' "$D/err"; then
    ok '负例 --dir 目录不存在 → exit 2'
  else
    bad '负例 --dir 目录不存在 → exit 2' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi
  mkdir -p "$R/docs/sub"
  rm -f "$R/docs/sub/README.md"
  sh "$G" --target "$R" --dir docs/sub >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '无文件' "$D/err"; then
    ok '负例 --dir 目录内无 README → exit 2 无文件'
  else
    bad '负例 --dir 目录内无 README → exit 2 无文件' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # N12 未知参数 → exit 2
  sh "$G" --target "$R" --bogus >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '未知参数' "$D/err"; then
    ok '负例 未知参数 → exit 2'
  else
    bad '负例 未知参数 → exit 2' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # ============================================================
  # --sync / --init（生成块重建、骨架生成与占位断言）
  # ============================================================

  S=$D/sync
  mkdir -p "$S/docs/alpha" "$S/docs/beta"
  printf '# alpha\n\n阿尔法职责句。\n' > "$S/docs/alpha/README.md"
  cat > "$S/docs/README.md" <<'EOF'
<!-- Input: 块外头注 -->
<!-- Output: 块外导航 -->
<!-- Pos: 块外定位 -->

# docs

块外职责句。

## 权威
- 现行：无
- 派生：无

## 读取禁忌
- 块外禁忌句。

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
| `docs/beta/` | 贝塔原句 | 贝塔原禁忌 |
<!-- /dir-readme -->

块外尾注一行。
EOF
  cp "$S/docs/README.md" "$D/sync-before.md"
  awk '/^<!-- dir-readme: generated/{exit} {print}' "$D/sync-before.md" > "$D/sync-head-before"
  awk 'f{print} /^<!-- \/dir-readme -->$/{f=1}' "$D/sync-before.md" > "$D/sync-tail-before"
  sh "$G" --target "$S" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 --sync 重建生成块 → exit 0'
  else
    bad '正例 --sync 重建生成块 → exit 0' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # AC1 块外逐字节不变（块前、块后分别 cmp）
  awk '/^<!-- dir-readme: generated/{exit} {print}' "$S/docs/README.md" > "$D/sync-head-after"
  if cmp -s "$D/sync-head-before" "$D/sync-head-after"; then
    ok 'AC1 --sync 生成块之前逐字节不变'
  else
    bad 'AC1 --sync 生成块之前逐字节不变' "$(diff "$D/sync-head-before" "$D/sync-head-after" 2>/dev/null | sed -n '2,5p' | tr '\n' '|')"
  fi
  awk 'f{print} /^<!-- \/dir-readme -->$/{f=1}' "$S/docs/README.md" > "$D/sync-tail-after"
  if cmp -s "$D/sync-tail-before" "$D/sync-tail-after"; then
    ok 'AC1 --sync 生成块之后逐字节不变'
  else
    bad 'AC1 --sync 生成块之后逐字节不变' "$(diff "$D/sync-tail-before" "$D/sync-tail-after" 2>/dev/null | sed -n '2,5p' | tr '\n' '|')"
  fi

  # 增行：新子目录自动出行，一句话取子目录 README 职责句；既有行两格原文复用
  if grep -qF '| `docs/alpha/` | 阿尔法职责句。 | — |' "$S/docs/README.md" \
    && grep -qF '| `docs/beta/` | 贝塔原句 | 贝塔原禁忌 |' "$S/docs/README.md"; then
    ok '正例 --sync 增行取子目录职责句且既有行两格原文复用'
  else
    bad '正例 --sync 增行取子目录职责句且既有行两格原文复用' "$(sed -n '/dir-readme: generated/,/\/dir-readme/p' "$S/docs/README.md" | tr '\n' '|')"
  fi

  # AC2 幂等：第二次零差异且 exit 0
  cp "$S/docs/README.md" "$D/sync-after1.md"
  sh "$G" --target "$S" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && cmp -s "$D/sync-after1.md" "$S/docs/README.md"; then
    ok 'AC2 连跑两次 --sync：第二次 exit 0 且零差异'
  else
    bad 'AC2 连跑两次 --sync：第二次 exit 0 且零差异' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # 删行：子目录消失后整行删除，并逐行报告 DEL
  rm -rf "$S/docs/beta"
  sh "$G" --target "$S" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qF 'beta' "$S/docs/README.md"; then
    ok '正例 --sync 子目录消失后整行删除 → exit 0'
  else
    bad '正例 --sync 子目录消失后整行删除 → exit 0' "exit=$rc remaining=$(grep -F 'beta' "$S/docs/README.md" | tr '\n' '|')"
  fi
  if grep -qF 'DEL: docs/README.md: beta: 贝塔原句' "$D/out"; then
    ok '正例 --sync 逐行报告删除行 DEL'
  else
    bad '正例 --sync 逐行报告删除行 DEL' "stdout=$(tr '\n' '|' < "$D/out")"
  fi

  # 无生成块 → SKIP、exit 0、文件字节不变
  NB=$D/sync-no-block
  mkdir -p "$NB"
  cat > "$NB/README.md" <<'EOF'
# plain

无生成块的职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
EOF
  cp "$NB/README.md" "$D/no-block-before.md"
  sh "$G" --target "$NB" --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -qxF 'SKIP: README.md: 无生成块' "$D/out"; then
    ok '正例 --sync 无生成块 → SKIP 且 exit 0'
  else
    bad '正例 --sync 无生成块 → SKIP 且 exit 0' "exit=$rc stdout=$(tr '\n' '|' < "$D/out")"
  fi
  if cmp -s "$D/no-block-before.md" "$NB/README.md"; then
    ok '正例 --sync 无生成块不新建不修改（字节不变）'
  else
    bad '正例 --sync 无生成块不新建不修改（字节不变）' '文件被改动'
  fi

  # 未闭合生成块 → exit 2 指名行号、零写入
  U=$D/sync-unclosed
  mkdir -p "$U/docs"
  cat > "$U/docs/README.md" <<'EOF'
# docs

职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
EOF
  cp "$U/docs/README.md" "$D/unclosed-before.md"
  sh "$G" --target "$U" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF 'docs/README.md:12: 生成块未闭合' "$D/err"; then
    ok '负例 --sync 生成块未闭合 → exit 2 指名 path:line'
  else
    bad '负例 --sync 生成块未闭合 → exit 2 指名 path:line' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi
  if cmp -s "$D/unclosed-before.md" "$U/docs/README.md"; then
    ok '负例 --sync 生成块未闭合 → 零写入'
  else
    bad '负例 --sync 生成块未闭合 → 零写入' '文件被改动'
  fi

  # 重复起始标记 → exit 2、指名行号、零写入
  DU=$D/sync-duplicate
  mkdir -p "$DU/docs"
  cat > "$DU/docs/README.md" <<'EOF'
# docs

职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
<!-- dir-readme: generated dir=docs -->
<!-- dir-readme: generated dir=docs -->
<!-- /dir-readme -->
EOF
  cp "$DU/docs/README.md" "$D/duplicate-before.md"
  sh "$G" --target "$DU" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] \
    && grep -qF 'docs/README.md:13: 生成块重复起始标记' "$D/err" \
    && cmp -s "$D/duplicate-before.md" "$DU/docs/README.md"; then
    ok '负例 --sync 生成块重复起始 → exit 2 指名 path:line 且零写入'
  else
    bad '负例 --sync 生成块重复起始 → exit 2 指名 path:line 且零写入' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # --sync 与 --init 互斥 → exit 2
  sh "$G" --target "$S" --sync --init docs >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '互斥' "$D/err"; then
    ok '负例 --sync 与 --init 同时给 → exit 2'
  else
    bad '负例 --sync 与 --init 同时给 → exit 2' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # --init 生成四段骨架，判断位留占位，--check 因占位 exit 2；手填后 exit 0
  I=$D/init
  mkdir -p "$I/area/child"
  printf '# child\n\n子目录职责。\n' > "$I/area/child/README.md"
  sh "$G" --target "$I" --init area >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$I/area/README.md" ]; then
    ok '正例 --init 新目录 → exit 0 且生成 README.md'
  else
    bad '正例 --init 新目录 → exit 0 且生成 README.md' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi
  if grep -qxF '# area' "$I/area/README.md" \
    && grep -qxF '## 权威' "$I/area/README.md" \
    && grep -qxF '## 读取禁忌' "$I/area/README.md" \
    && grep -qxF '## 子目录' "$I/area/README.md"; then
    ok '正例 --init 骨架四段齐全'
  else
    bad '正例 --init 骨架四段齐全' "$(tr '\n' '|' < "$I/area/README.md")"
  fi
  if grep -qF '<!-- dir-readme: generated dir=area -->' "$I/area/README.md" \
    && grep -qF '| `area/child/` | 子目录职责。 | — |' "$I/area/README.md"; then
    ok '正例 --init 生成块包住自动子目录表'
  else
    bad '正例 --init 生成块包住自动子目录表' "$(sed -n '/dir-readme: generated/,/\/dir-readme/p' "$I/area/README.md" | tr '\n' '|')"
  fi
  sh "$G" --target "$I" --dir area --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '判断位未填（【填写：…】占位）' "$D/err"; then
    ok 'AC3 --init 骨架占位未清 → --check exit 2'
  else
    bad 'AC3 --init 骨架占位未清 → --check exit 2' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi
  python3 - "$I/area/README.md" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()
text = re.sub(r"【填写：[^】]*】", "已填", text)
with open(path, "w", encoding="utf-8", newline="") as fh:
    fh.write(text)
PY
  sh "$G" --target "$I" --dir area --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok 'AC3 手填占位后 --check exit 0 且零输出'
  else
    bad 'AC3 手填占位后 --check exit 0 且零输出' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # --init 目标已存在 → exit 2 零写入
  cp "$I/area/README.md" "$D/init-before.md"
  sh "$G" --target "$I" --init area >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '已存在' "$D/err"; then
    ok '负例 --init 目标 README.md 已存在 → exit 2'
  else
    bad '负例 --init 目标 README.md 已存在 → exit 2' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi
  if cmp -s "$D/init-before.md" "$I/area/README.md"; then
    ok '负例 --init 目标已存在 → 零写入'
  else
    bad '负例 --init 目标已存在 → 零写入' '文件被改动'
  fi

  # 占位断言不误伤 HTML 注释内的【填写：】
  C=$D/placeholder-comment
  mkdir -p "$C/docs/sub"
  : > "$C/docs/a.md"
  dr_base_readme "$C/docs/README.md"
  {
    printf '<!-- Input: 【填写：注释内占位不算正文】 -->\n'
    cat "$C/docs/README.md"
  } > "$D/tmp" && mv "$D/tmp" "$C/docs/README.md"
  sh "$G" --target "$C" --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 HTML 注释内【填写：】不误伤 → exit 0 零输出'
  else
    bad '正例 HTML 注释内【填写：】不误伤 → exit 0 零输出' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # F1 空白目录名 fail-closed：--init 与 --sync --dir 均 exit 2、零写入
  W=$D/whitespace
  mkdir -p "$W/区域 子目录"
  sh "$G" --target "$W" --init '区域 子目录' >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '目录路径不得含空白' "$D/err"; then
    ok '负例 --init 目录名含空白 → exit 2 点明限制'
  else
    bad '负例 --init 目录名含空白 → exit 2 点明限制' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi
  if [ ! -e "$W/区域 子目录/README.md" ]; then
    ok '负例 --init 目录名含空白 → 零写入'
  else
    bad '负例 --init 目录名含空白 → 零写入' 'README.md 被创建'
  fi
  sh "$G" --target "$W" --dir '区域 子目录' --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '目录路径不得含空白' "$D/err"; then
    ok '负例 --sync --dir 目录名含空白 → exit 2'
  else
    bad '负例 --sync --dir 目录名含空白 → exit 2' "exit=$rc stderr=$(head -n 1 "$D/err")"
  fi

  # F2 占位断言只拦散文／表格单元格：行内代码段与围栏代码块内的【填写：】不误伤
  PH=$D/placeholder-scope
  mkdir -p "$PH/docs/sub"
  : > "$PH/docs/a.md"
  dr_base_readme "$PH/docs/README.md"
  printf '文档里以行内代码引用占位写法 `【填写：…】`，不是待填判断位。\n' >> "$PH/docs/README.md"
  sh "$G" --target "$PH" --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 行内代码段内【填写：】不误伤 → exit 0 零输出'
  else
    bad '正例 行内代码段内【填写：】不误伤 → exit 0 零输出' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi
  printf '```text\n【填写：围栏内占位】\n```\n' >> "$PH/docs/README.md"
  sh "$G" --target "$PH" --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 围栏代码块内【填写：】不误伤 → exit 0 零输出'
  else
    bad '正例 围栏代码块内【填写：】不误伤 → exit 0 零输出' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi
  printf '散文里裸写【填写：露出的占位】。\n' >> "$PH/docs/README.md"
  sh "$G" --target "$PH" --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qF '判断位未填（【填写：…】占位）' "$D/err"; then
    ok '负例 散文裸露【填写：】仍 exit 2'
  else
    bad '负例 散文裸露【填写：】仍 exit 2' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # F3 围栏代码块内的成对标记不是生成块：--sync 不读不写、--check 不判
  FB=$D/fence-block
  mkdir -p "$FB/docs"
  cat > "$FB/docs/README.md" <<'EOF'
# docs

职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |

示例（围栏内只是展示，不是真生成块）：

```markdown
<!-- dir-readme: generated dir=docs -->
| `docs/` | 示例 | — |
<!-- /dir-readme -->
```
EOF
  cp "$FB/docs/README.md" "$D/fence-before.md"
  sh "$G" --target "$FB" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -qxF 'SKIP: docs/README.md: 无生成块' "$D/out"; then
    ok '正例 --sync 围栏内标记不算块 → SKIP 且 exit 0'
  else
    bad '正例 --sync 围栏内标记不算块 → SKIP 且 exit 0' "exit=$rc stdout=$(tr '\n' '|' < "$D/out")"
  fi
  if cmp -s "$D/fence-before.md" "$FB/docs/README.md"; then
    ok '正例 --sync 围栏内标记不读不写（字节不变）'
  else
    bad '正例 --sync 围栏内标记不读不写（字节不变）' "diff=$(diff "$D/fence-before.md" "$FB/docs/README.md" | tr '\n' '|')"
  fi
  sh "$G" --target "$FB" --dir docs --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 --check 围栏内成对标记不判块 → exit 0 零输出'
  else
    bad '正例 --check 围栏内成对标记不判块 → exit 0 零输出' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # F4 模板首格与根相对路径口径一致
  TMPL="$SCRIPT_DIR/../references/templates/dir-README.md.tmpl"
  if grep -qF '| `notes/sub/` |' "$TMPL" && ! grep -qF '【一级子目录名】' "$TMPL"; then
    ok '正例 模板首格为根相对示例（无「一级子目录名」占位）'
  else
    bad '正例 模板首格为根相对示例（无「一级子目录名」占位）' "$(grep -n 'notes/sub/\|一级子目录名' "$TMPL" | tr '\n' '|')"
  fi

  # F5 子目录名含 |：首格转义为 \|，读回反转义后复跑零差异，--check 不误判幽灵路径
  PP=$D/pipe
  mkdir -p "$PP/docs/a|b"
  printf '# a|b\n\n管道职责。\n' > "$PP/docs/a|b/README.md"
  cat > "$PP/docs/README.md" <<'EOF'
# docs

职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
<!-- /dir-readme -->
EOF
  sh "$G" --target "$PP" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -qF '| `docs/a\|b/` | 管道职责。 | — |' "$PP/docs/README.md"; then
    ok '正例 --sync 子目录名含 | → 首格转义 \|'
  else
    bad '正例 --sync 子目录名含 | → 首格转义 \|' "exit=$rc row=$(grep -F 'a\|b' "$PP/docs/README.md" | tr '\n' '|')"
  fi
  cp "$PP/docs/README.md" "$D/pipe-after1.md"
  sh "$G" --target "$PP" --dir docs --sync >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && cmp -s "$D/pipe-after1.md" "$PP/docs/README.md"; then
    ok '正例 含 | 的行复跑 --sync 零差异'
  else
    bad '正例 含 | 的行复跑 --sync 零差异' "exit=$rc"
  fi
  sh "$G" --target "$PP" --dir docs --check >"$D/out" 2>"$D/err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/out" ] && [ ! -s "$D/err" ]; then
    ok '正例 含 | 的行 --check exit 0（转义不误判幽灵路径）'
  else
    bad '正例 含 | 的行 --check exit 0（转义不误判幽灵路径）' "exit=$rc stderr=$(tr '\n' '|' < "$D/err")"
  fi

  # --help 写明两个写入模式、无生成块的 SKIP 语义与空白限制
  sh "$G" --help >"$D/out" 2>"$D/err"
  if grep -qF -- '--sync' "$D/out" \
    && grep -qF -- '--init' "$D/out" \
    && grep -qF '无生成块' "$D/out" \
    && grep -qF '不得含空白' "$D/out"; then
    ok '正例 --help 写明 --sync／--init、无生成块 SKIP 与空白限制'
  else
    bad '正例 --help 写明 --sync／--init、无生成块 SKIP 与空白限制' "stdout=$(head -n 1 "$D/out")"
  fi

  suite_summary 'dir-readme'
}
