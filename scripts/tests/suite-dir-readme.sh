#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite dir-readme "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: dir-readme（目录 README 四段式契约与结构校验）
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

  suite_summary 'dir-readme'
}
