#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite dir-readme-migrate "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: dir-readme-migrate（票 291 自 suite-dir-readme 拆出的迁移预演能力面）：
# --migrate-dry-run 旧格式迁移只读预演——four-column／member-table／no-table 三形态判定、
# 判断文字整行搬运、DROP／NOTE 登记、缺项与超长只报不截断、预演前后 sha256 零写入自证、
# 摘要/逐件 diff 两模式输出。

suite_dir_readme_migrate() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='dir-readme-migrate'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/drm
  mkdir -p "$D"
  G="$SCRIPT_DIR/generate-dir-readmes.sh"

  # ============================================================
  # --migrate-dry-run（旧格式迁移预演：形态判定、原样搬运、DROP／NOTE、零写入）
  # ============================================================

  MG=$D/migrate
  mkdir -p "$MG/repo/four" "$MG/repo/member" "$MG/repo/plain" "$MG/repo/two-col"
  mkdir -p "$MG/compliant/docs" "$MG/over" "$MG/anomaly/no-h1" "$MG/anomaly/broken"

  cat > "$MG/repo/four/README.md" <<'EOF'
# 派发模板

本目录承载派发模板。

## 权威分工

- 模板以角色合同为准。
- 模板与合同冲突时以合同为准。

## 目录成员

| 文件 | 描述 | 角色合同事实源 | 关键占位符 |
| --- | --- | --- | --- |
| `a.md` | A 阶段模板 | `roles/a.md` | `{{A}}` |

## 使用方式

1. 第一步：读取模板。
2. 第二步：填充占位符。
EOF

  cat > "$MG/repo/member/README.md" <<'EOF'
# 目录

## 架构

- 规则一：本目录只承载合同。
- 规则二：冲突时以合同为准。

## 已知限制

- 限制一：链接按冻结态保留。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `a.md` | 文档 | 说明 |
EOF

  cat > "$MG/repo/plain/README.md" <<'EOF'
# 目录

本目录的职责句。

## 架构

- 规则一。

## 边界

- 不越层引用。
EOF

  cat > "$MG/repo/two-col/README.md" <<'EOF'
# 目录

本目录的职责句。

| 检查项 | 依据文件 |
| --- | --- |
| 结构 | `a.md` |
EOF

  : > "$MG/compliant/docs/a.md"
  dr_base_readme "$MG/compliant/docs/README.md"

  # 超限夹具：架构节 40 条列表项，建议内容必然 > 25 行
  {
    printf '# 大目录\n\n大目录职责句。\n\n## 架构\n\n'
    dr_i=1
    while [ "$dr_i" -le 40 ]; do
      printf -- '- 判断条目 %s：原文整行搬运。\n' "$dr_i"
      dr_i=$((dr_i + 1))
    done
  } > "$MG/over/README.md"

  printf 'no heading here\n\n## 权威\n- x\n' > "$MG/anomaly/no-h1/README.md"
  printf '# 破损\n\n职责句。\n\n| 名字 | 地位 | 功能 |\n| a | b | c |\n' > "$MG/anomaly/broken/README.md"

  dr_migrate_probe() {
    # $1=原 README $2=预演 stdout：从统一 diff 重建建议内容后打印
    # `LINES=n AUTH=n TABOO=n MISSING=n`（MISSING＝未能在原文逐字命中的判断行数）
    python3 - "$1" "$2" <<'PY'
import re
import sys

orig_path, out_path = sys.argv[1], sys.argv[2]
old_lines = open(orig_path, encoding="utf-8").read().splitlines()
old = set(old_lines)
text = open(out_path, encoding="utf-8").read().split("\n")
start = next((i for i, line in enumerate(text) if line.startswith("+++ b/")), None)
hunks = []
if start is not None:
    cur = None
    for line in text[start + 1:]:
        if line.startswith("MIGRATE:") or line.startswith("SUMMARY:"):
            break
        match = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if match:
            cur = {"new_start": int(match.group(1)), "lines": []}
            hunks.append(cur)
            continue
        if cur is not None:
            cur["lines"].append(line)
# 按 hunk 行号把 diff 还原成完整的新文件（hunk 间的未变更行从原文补回）
new = []
oi = 0
for hunk in hunks:
    while len(new) < hunk["new_start"] - 1:
        new.append(old_lines[oi])
        oi += 1
    for line in hunk["lines"]:
        tag, body = line[:1], line[1:]
        if tag == " ":
            new.append(body)
            oi += 1
        elif tag == "-":
            oi += 1
        elif tag == "+":
            new.append(body)
for line in old_lines[oi:]:
    new.append(line)
while new and new[-1] == "":
    new.pop()
auth = taboo = missing = 0
section = None
for line in new:
    if line == "## 权威" or line == "## 读取禁忌":
        section = line
        continue
    if line.startswith("## "):
        section = None
        continue
    if section is not None and line.strip() and "【填写：" not in line:
        if line not in old:
            missing += 1
        if section == "## 权威":
            auth += 1
        else:
            taboo += 1
print("LINES=%d AUTH=%d TABOO=%d MISSING=%d" % (len(new), auth, taboo, missing))
PY
  }


  tw_tree_digest "$MG/repo" > "$D/migrate-tree-before"
  sh "$G" --target "$MG/repo" --migrate-dry-run --diff >"$D/migrate-all.out" 2>"$D/migrate-all.err"
  rc=$?
  tw_tree_digest "$MG/repo" > "$D/migrate-tree-after"

  # M1 三种形态各一 fixture（four-column／member-table／no-table）
  if [ "$rc" -eq 0 ] && grep -qF 'MIGRATE: four/README.md: four-column:' "$D/migrate-all.out"; then
    ok '正例 迁移预演 四列表 + 手册节 → four-column'
  else
    bad '正例 迁移预演 四列表 + 手册节 → four-column' "exit=$rc $(grep -F 'MIGRATE: four' "$D/migrate-all.out" | tr '\n' '|')"
  fi
  if grep -qF 'MIGRATE: member/README.md: member-table:' "$D/migrate-all.out"; then
    ok '正例 迁移预演 成员三列表 → member-table'
  else
    bad '正例 迁移预演 成员三列表 → member-table' "$(grep -F 'MIGRATE: member' "$D/migrate-all.out" | tr '\n' '|')"
  fi
  if grep -qF 'MIGRATE: plain/README.md: no-table:' "$D/migrate-all.out"; then
    ok '正例 迁移预演 无表格 → no-table'
  else
    bad '正例 迁移预演 无表格 → no-table' "$(grep -F 'MIGRATE: plain' "$D/migrate-all.out" | tr '\n' '|')"
  fi

  # M2 普通两列表（检查项｜依据文件）不得判成 member-table
  if require_out 'suite-dir-readme 目标输出在场' "$D/migrate-all.out" \
    && grep -qF 'MIGRATE: two-col/README.md: no-table:' "$D/migrate-all.out" \
    && ! grep -qF 'MIGRATE: two-col/README.md: member-table:' "$D/migrate-all.out"; then
    ok '正例 普通两列表不误判 member-table → no-table'
  else
    bad '正例 普通两列表不误判 member-table → no-table' "$(grep -F 'MIGRATE: two-col' "$D/migrate-all.out" | tr '\n' '|')"
  fi

  # M3 合规 README 不进入迁移集合 → 零输出 exit 0（AC3）
  sh "$G" --target "$MG/compliant" --migrate-dry-run >"$D/migrate-ok.out" 2>"$D/migrate-ok.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/migrate-ok.out" ] && [ ! -s "$D/migrate-ok.err" ]; then
    ok 'AC3 摘要模式无迁移件零输出且 exit 0'
  else
    bad 'AC3 摘要模式无迁移件零输出且 exit 0' "exit=$rc stdout=$(head -n 1 "$D/migrate-ok.out")"
  fi

  # M4 判断文字原样搬运：## 权威 2 行、## 读取禁忌 1 行且逐字命中原文
  sh "$G" --target "$MG/repo" --dir member --migrate-dry-run --diff >"$D/migrate-member.out" 2>"$D/migrate-member.err"
  probe=$(dr_migrate_probe "$MG/repo/member/README.md" "$D/migrate-member.out")
  if [ "$probe" = 'LINES=16 AUTH=2 TABOO=1 MISSING=0' ]; then
    ok 'AC2 判断文字整行原文搬运且逐字命中（权威 2／禁忌 1／未命中 0）'
  else
    bad 'AC2 判断文字整行原文搬运且逐字命中（权威 2／禁忌 1／未命中 0）' "$probe"
  fi
  sh "$G" --target "$MG/repo" --dir four --migrate-dry-run --diff >"$D/migrate-four.out" 2>"$D/migrate-four.err"
  probe=$(dr_migrate_probe "$MG/repo/four/README.md" "$D/migrate-four.out")
  if [ "$probe" = 'LINES=16 AUTH=2 TABOO=0 MISSING=0' ]; then
    ok 'AC2 四列件权威两行原样搬运且未改写'
  else
    bad 'AC2 四列件权威两行原样搬运且未改写' "$probe"
  fi

  # M5 超限：NOTE 点名行数、建议内容不截断（40 条判断条目全在）
  sh "$G" --target "$MG/over" --migrate-dry-run --diff >"$D/migrate-over.out" 2>"$D/migrate-over.err"
  over_note=$(sed -n 's/^NOTE: README\.md: 建议内容 \([0-9][0-9]*\) 行，超过上限 25，需人工裁剪$/\1/p' "$D/migrate-over.out")
  probe=$(dr_migrate_probe "$MG/over/README.md" "$D/migrate-over.out")
  if [ -n "$over_note" ] && [ "$probe" = "LINES=$over_note AUTH=40 TABOO=0 MISSING=0" ]; then
    ok 'AC2 超限 40 行判断文字 → NOTE 点名行数且不截断（建议行数＝NOTE 行数）'
  else
    bad 'AC2 超限 40 行判断文字 → NOTE 点名行数且不截断（建议行数＝NOTE 行数）' "note=${over_note:-无} $probe"
  fi
  if require_out 'suite-dir-readme 目标输出在场' "$D/migrate-over.out" \
    && grep -qF 'NOTE: over/README.md: 原文缺职责句' "$D/migrate-over.out" \
    || ! grep -qF '【填写：一句话职责】' "$D/migrate-over.out"; then
    ok '正例 已有职责句时不再插职责占位'
  else
    bad '正例 已有职责句时不再插职责占位' "$(grep -F 'NOTE: over' "$D/migrate-over.out" | tr '\n' '|')"
  fi

  # M6 丢弃段：成员表与手册节各有 DROP 行且行范围覆盖原文
  hdr=$(grep -n '^| 名字' "$MG/repo/member/README.md" | cut -d: -f1)
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  last=$(grep -n '^| `a\.md`' "$MG/repo/member/README.md" | cut -d: -f1)
  if grep -qF "DROP: member/README.md: $hdr-$last 行: 成员表（表头 名字｜地位｜功能）" "$D/migrate-member.out"; then
    ok 'AC2 成员表逐段 DROP 且行范围覆盖表头至末行'
  else
    bad 'AC2 成员表逐段 DROP 且行范围覆盖表头至末行' "$(grep -F 'DROP: member' "$D/migrate-member.out" | tr '\n' '|')"
  fi
  man=$(grep -n '^## 使用方式' "$MG/repo/four/README.md" | cut -d: -f1)
  man_end=$(wc -l < "$MG/repo/four/README.md" | tr -d ' ')
  if grep -qF "DROP: four/README.md: $man-$man_end 行: 未迁入节：## 使用方式（非权威／禁忌类）" "$D/migrate-four.out"; then
    ok 'AC2 手册节逐段 DROP 且行范围覆盖整节'
  else
    bad 'AC2 手册节逐段 DROP 且行范围覆盖整节' "$(grep -F 'DROP: four' "$D/migrate-four.out" | tr '\n' '|')"
  fi

  # M7 零写入：预演前后目录树内容哈希完全一致（含无新增 .bak／临时件）
  if cmp -s "$D/migrate-tree-before" "$D/migrate-tree-after"; then
    ok 'AC2 迁移预演零写入（目录树 sha256 前后一致）'
  else
    bad 'AC2 迁移预演零写入（目录树 sha256 前后一致）' "$(diff "$D/migrate-tree-before" "$D/migrate-tree-after" | tr '\n' '|')"
  fi
  if grep -qF 'SUMMARY: 迁移 4 件（four-column 1／member-table 1／no-table 2）；零写入 sha256 4/4 一致' "$D/migrate-all.out"; then
    ok '正例 预演汇总行给出形态计数与零写入 sha256 证据'
  else
    bad '正例 预演汇总行给出形态计数与零写入 sha256 证据' "$(grep -F 'SUMMARY' "$D/migrate-all.out" | tr '\n' '|')"
  fi

  # M7b 默认摘要模式：≤15 行、无 diff 正文、含形态计数与 ZERO-WRITE
  sh "$G" --target "$MG/repo" --migrate-dry-run >"$D/migrate-summary.out" 2>"$D/migrate-summary.err"
  rc=$?
  sum_lines=$(wc -l <"$D/migrate-summary.out" | tr -d ' ')
  if require_out 'suite-dir-readme 目标输出在场' "$D/migrate-summary.out" \
    && [ "$rc" -eq 0 ] && [ "$sum_lines" -le 15 ] && [ ! -s "$D/migrate-summary.err" ] \
    && grep -qF 'SUMMARY: 迁移 4 件（member-table 1／four-column 1／no-table 2）' "$D/migrate-summary.out" \
    && grep -qF 'ZERO-WRITE: 4/4 sha256 一致' "$D/migrate-summary.out" \
    && ! grep -qF -- '--- a/' "$D/migrate-summary.out"; then
    ok '正例 默认摘要 ≤15 行且含形态计数与 ZERO-WRITE（无 diff 正文）'
  else
    bad '正例 默认摘要 ≤15 行且含形态计数与 ZERO-WRITE（无 diff 正文）' "exit=$rc lines=$sum_lines $(tr '\n' '|' <"$D/migrate-summary.out")"
  fi
  if grep -qF 'NEEDS-CONFIRM: 1 件缺职责句，建议留占位' "$D/migrate-summary.out" \
    && grep -qF 'NEEDS-CONFIRM: 2 件缺「权威」或「读取禁忌」列表项，建议留占位' "$D/migrate-summary.out" \
    && grep -qE '^NEEDS-CONFIRM: [0-9]+ 段内容未迁入（DROP），需人工判是否升格$' "$D/migrate-summary.out"; then
    ok '正例 默认摘要含分类待人工确认清单行'
  else
    bad '正例 默认摘要含分类待人工确认清单行' "$(tr '\n' '|' <"$D/migrate-summary.out")"
  fi

  # M7c --diff 详情与 --diff 单独出现
  if grep -qF -- '--- a/member/README.md' "$D/migrate-member.out" \
    && grep -qF 'DROP: member/README.md:' "$D/migrate-member.out"; then
    ok '正例 --diff 输出逐文件详情（统一 diff 与 DROP）'
  else
    bad '正例 --diff 输出逐文件详情（统一 diff 与 DROP）' "$(head -n 1 "$D/migrate-member.out")"
  fi
  dr_diff=1
  sh "$G" --target "$MG/repo" --diff >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '只能与 --migrate-dry-run 连用' "$D/err" || dr_diff=0
  sh "$G" --target "$MG/repo" --diff --check >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '只能与 --migrate-dry-run 连用' "$D/err" || dr_diff=0
  if [ "$dr_diff" -eq 1 ]; then
    ok '负例 --diff 单独出现或与 --check 同用 → exit 2 并说明用法'
  else
    bad '负例 --diff 单独出现或与 --check 同用 → exit 2 并说明用法' "$(tr '\n' '|' <"$D/err")"
  fi
  sh "$G" --target "$MG/repo" --diff --check >"$D/out" 2>"$D/err"
  dr_rc=$?
  if require_out 'suite-dir-readme 目标输出在场' "$D/err" \
    && [ "$dr_rc" -eq 2 ] \
    && grep -qF '（与 --check 同用无效，用法见 --help）' "$D/err" \
    && ! grep -qE '用法见 --help）check$' "$D/err"; then
    ok '负例 --diff --check 模式名嵌入句内且行尾无裸模式名'
  else
    bad '负例 --diff --check 模式名嵌入句内且行尾无裸模式名' "exit=$dr_rc $(tr '\n' '|' <"$D/err")"
  fi

  # M8 异常形态：无 H1／表头残缺 → exit 2 指名 file:line 且不产生部分结论
  sh "$G" --target "$MG/anomaly" --migrate-dry-run >"$D/migrate-bad.out" 2>"$D/migrate-bad.err"
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$D/migrate-bad.out" ] \
    && grep -qF 'no-h1/README.md:1: 缺少一级标题' "$D/migrate-bad.err"; then
    ok '负例 无 H1 → exit 2 指名 file:line 且零 stdout'
  else
    bad '负例 无 H1 → exit 2 指名 file:line 且零 stdout' "exit=$rc stdout=$(head -n 1 "$D/migrate-bad.out") stderr=$(tr '\n' '|' < "$D/migrate-bad.err")"
  fi
  if grep -qF 'broken/README.md:5: 表头残缺（表头后缺少分隔行）' "$D/migrate-bad.err"; then
    ok '负例 表头残缺 → exit 2 指名表头行'
  else
    bad '负例 表头残缺 → exit 2 指名表头行' "$(tr '\n' '|' < "$D/migrate-bad.err")"
  fi

  # M9 与三种既有模式互斥 → exit 2
  dr_mutex=1
  for dr_mode in '--check' '--sync' '--init member'; do
    # shellcheck disable=SC2086  # 三个模式串按空格拆成参数，--init 需带目录值
    sh "$G" --target "$MG/repo" --migrate-dry-run $dr_mode >"$D/out" 2>"$D/err"
    dr_mutex_rc=$?
    if ! require_out '负例 --migrate-dry-run 与 --check／--sync／--init 互斥 → exit 2' "$D/err" \
      || [ "$dr_mutex_rc" -ne 2 ] || ! grep -qF '互斥' "$D/err"; then
      dr_mutex=0
    fi
  done
  if [ "$dr_mutex" -eq 1 ]; then
    ok '负例 --migrate-dry-run 与 --check／--sync／--init 互斥 → exit 2'
  else
    bad '负例 --migrate-dry-run 与 --check／--sync／--init 互斥 → exit 2' "$(tr '\n' '|' < "$D/err")"
  fi

  # M10 --dir 限定生效
  if require_out 'suite-dir-readme 目标输出在场' "$D/migrate-member.out" \
    && grep -qF 'MIGRATE: member/README.md:' "$D/migrate-member.out" \
    && ! grep -qF 'MIGRATE: four/README.md:' "$D/migrate-member.out"; then
    ok '正例 --dir 限定只输出指定目录的迁移建议'
  else
    bad '正例 --dir 限定只输出指定目录的迁移建议' "$(grep -F 'MIGRATE:' "$D/migrate-member.out" | tr '\n' '|')"
  fi

  # M11 --help 写明两种输出形态与 --diff 用法
  sh "$G" --help >"$D/out" 2>"$D/err"
  if grep -qF -- '--migrate-dry-run' "$D/out" \
    && grep -qF -- '--diff' "$D/out" \
    && grep -qF '摘要' "$D/out" \
    && grep -qF 'MIGRATE:' "$D/out" \
    && grep -qF 'DROP:' "$D/out"; then
    ok '正例 --help 写明摘要／--diff 两种形态与 MIGRATE／DROP 报告行'
  else
    bad '正例 --help 写明摘要／--diff 两种形态与 MIGRATE／DROP 报告行' "stdout=$(head -n 1 "$D/out")"
  fi

  # B1 --brief 素材包：四节固定标题、目录清单、artifacts 原文与分组、条目作用域
  B=$D/brief
  mkdir -p "$B/repo/docs/sub" "$B/repo/other" "$B/repo/facts/project" "$B/repo/refs" \
    "$B/nofacts/docs" "$B/badfacts/docs" "$B/badfacts/facts/project" \
    "$B/badentry/docs" "$B/badentry/facts/project"
  : > "$B/repo/docs/a.md"
  : > "$B/repo/docs/b.md"
  : > "$B/repo/other/secret.md"
  : > "$B/nofacts/docs/a.md"
  : > "$B/badfacts/docs/a.md"
  cat > "$B/repo/facts/project/artifacts.yaml" <<'EOF'
artifacts:
  - id: docs-dir
    path: docs/
    kind: governance
    authority: 权威层级第 6 级（导航索引：docs 目录登记；规则权威＝rules/project.md §15.1；另见 facts/project）
    read_when: 查阅 docs 目录职责时；另见 ../SKILL.md；核对 rules/implementation/roles
  - id: docs-a
    path: docs/a.md
    kind: governance
    authority: 权威层级第 2 级（事实记录：docs 样例）
    read_when: 校验 docs 段时
  - id: docs-sub-doc
    path: docs/sub/inner.md
    kind: spec
    authority: 权威层级第 3 级（规格：子目录内样例）
    read_when: 校验子目录内分组时
  - id: other-secret
    path: other/secret.md
    kind: governance
    authority: 权威层级第 6 级（越界条目：不得出现在 docs 素材包）
    read_when: 校验越界过滤时
EOF
  printf 'entries:\n  - id: docs-a\n    path: docs/a.md\n' \
    > "$B/badfacts/facts/project/artifacts.yaml"
  cat > "$B/badentry/facts/project/artifacts.yaml" <<'EOF'
artifacts:
  - id: docs-a
    path: docs/a.md
    kind: governance
  - path: docs/b.md
    kind: spec
    authority: 权威层级第 1 级
EOF
  cat > "$B/repo/refs/README.md" <<'EOF'
# refs

现状 CHECK 回显样例。

## 权威
- 现行：`other/missing.md`
- 派生：`../`

## 读取禁忌
- 无

## 子目录
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
EOF
  dr_brief() {
    # $1=目标根 $2=相对目录：结果落 $D/brief.out／$D/brief.err／$D/brief.rc
    sh "$G" --target "$1" --brief "$2" >"$D/brief.out" 2>"$D/brief.err"
    printf '%s\n' "$?" > "$D/brief.rc"
  }
  dr_brief "$B/repo" docs
  dr_brief_rc=$(cat "$D/brief.rc")
  if [ "$dr_brief_rc" -eq 0 ] \
    && [ "$(grep -c '^## BRIEF' "$D/brief.out")" -eq 4 ] \
    && grep -qxF '## BRIEF 目录清单' "$D/brief.out" \
    && grep -qxF '## BRIEF 判断证据' "$D/brief.out" \
    && grep -qxF '## BRIEF 现状' "$D/brief.out" \
    && grep -qxF '## BRIEF 生成约定' "$D/brief.out"; then
    ok '正例 --brief 输出四节固定标题且 exit 0'
  else
    bad '正例 --brief 输出四节固定标题且 exit 0' "exit=$dr_brief_rc $(grep '^## BRIEF' "$D/brief.out" | tr '\n' '|')"
  fi
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if grep -qF -- '- 目标目录：`docs`（一级成员 3 个）' "$D/brief.out" \
    && grep -qF -- '- d `sub/`（README.md：无）' "$D/brief.out" \
    && grep -qF -- '- f `a.md`（0 行，0 字节）' "$D/brief.out"; then
    ok '正例 --brief 目录清单列一级成员、文件行数与字节数'
  else
    bad '正例 --brief 目录清单列一级成员、文件行数与字节数' "$(sed -n '2,6p' "$D/brief.out" | tr '\n' '|')"
  fi
  # AC1 目录清单＝目标目录一级成员集合（`ls -1` 口径），正文里的成员不得混入
  # shellcheck disable=SC2012  # 对照口径必须与被测 brief 的 `ls -1` 输出同形（find 会改变非字母名与排序口径），非缺陷
  dr_docs_ls=$(CDPATH='' cd -- "$B/repo/docs" && LC_ALL=C ls -1 | LC_ALL=C sort)
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  dr_docs_listed=$(sed -n '/^## BRIEF 目录清单$/,/^## BRIEF 判断证据$/p' "$D/brief.out" \
    | sed -n 's/^- [dfol] `\([^`]*\)`.*$/\1/p' | sed 's|/$||' | LC_ALL=C sort)
  dr_docs_n=$(printf '%s\n' "$dr_docs_ls" | grep -c .)
  if [ "$dr_docs_listed" = "$dr_docs_ls" ] \
    && grep -qF -- "- 目标目录：\`docs\`（一级成员 $dr_docs_n 个）" "$D/brief.out" \
    && ! printf '%s\n' "$dr_docs_listed" | grep -qx 'inner.md'; then
    ok 'AC1 --brief 目录清单集合等于目标目录一级成员（不含目录外成员）'
  else
    bad 'AC1 --brief 目录清单集合等于目标目录一级成员（不含目录外成员）' "ls=$(printf '%s' "$dr_docs_ls" | tr '\n' ',') listed=$(printf '%s' "$dr_docs_listed" | tr '\n' ',')"
  fi
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if grep -qF -- '- [目录] 条目 docs-dir：`docs`' "$D/brief.out" \
    && grep -qF -- '- [成员] 条目 docs-a：`docs/a.md`' "$D/brief.out" \
    && grep -qF -- '- [子目录内] 条目 docs-sub-doc：`docs/sub/inner.md`' "$D/brief.out"; then
    ok '正例 --brief 判断证据按目录／成员／子目录内分组'
  else
    bad '正例 --brief 判断证据按目录／成员／子目录内分组' "$(grep -F '条目 ' "$D/brief.out" | tr '\n' '|')"
  fi
  if grep -qF '  kind: governance' "$D/brief.out" \
    && grep -qF '  authority: 权威层级第 2 级（事实记录：docs 样例）' "$D/brief.out" \
    && grep -qF '  read_when: 校验 docs 段时' "$D/brief.out" \
    && grep -qF '不是「哪份说了算」' "$D/brief.out"; then
    ok '正例 --brief 证据字段为 artifacts 原文且标注 authority 不可照抄'
  else
    bad '正例 --brief 证据字段为 artifacts 原文且标注 authority 不可照抄' "$(grep -F '  authority:' "$D/brief.out" | tr '\n' '|')"
  fi
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief.out" \
    && ! grep -qF 'other-secret' "$D/brief.out" \
    && ! grep -qF 'other/secret.md' "$D/brief.out"; then
    ok '正例 --brief 不带出目录外 artifacts 条目'
  else
    bad '正例 --brief 不带出目录外 artifacts 条目' "$(grep -F 'other' "$D/brief.out" | tr '\n' '|')"
  fi
  # AC1 证据段每条「[分组] 条目 id：路径」都能回查索引，且索引路径作用域在本目录；
  # fixture 里的 other-secret 是别目录条目，不得被带出
  dr_brief_scope() {
    # $1=brief 输出文件 $2=artifacts 索引 $3=相对目录：打印问题行（空输出即通过）——
    # 证据段每条「[分组] 条目 id：路径」都能回查索引，路径作用域均在本目录。
    python3 - "$1" "$2" "$3" <<'PY'
import re, sys

out_path, index_path, rel = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(out_path, encoding="utf-8").read()
begin = text.find("## BRIEF 判断证据")
end = text.find("## BRIEF 现状")
section = text[begin:end] if begin >= 0 and end > begin else ""
shown = re.findall(r"^- \[[^\]]+\] 条目 (\S+)：`([^`]+)`$", section, re.M)
index = {}
cur = None
for line in open(index_path, encoding="utf-8"):
    line = line.rstrip("\n")
    match = re.match(r"^  - id: (\S+)$", line)
    if match:
        cur = match.group(1)
        index[cur] = None
        continue
    match = re.match(r"^    path: (.+)$", line)
    if match and cur is not None and index[cur] is None:
        index[cur] = re.split(r"[（(]", match.group(1).strip(), 1)[0].strip().rstrip("/")
problems = []
if not shown:
    problems.append("证据段无条目")
for entry_id, path in shown:
    if entry_id not in index:
        problems.append("id 不可回查:%s" % entry_id)
        continue
    known = index[entry_id]
    if known != path:
        problems.append("路径与索引不符:%s:%s!=%s" % (entry_id, path, known))
    if not (known == rel or known.startswith(rel + "/")):
        problems.append("作用域越界:%s:%s" % (entry_id, known))
if re.search(r"条目 other-secret：", section):
    problems.append("带出别目录条目 other-secret")
sys.stdout.write("\n".join(problems))
PY
  }
  dr_scope=$(dr_brief_scope "$D/brief.out" "$B/repo/facts/project/artifacts.yaml" docs)
  if [ -z "$dr_scope" ]; then
    ok 'AC1 --brief 判断证据条目 id 可回查且路径作用域在本目录'
  else
    bad 'AC1 --brief 判断证据条目 id 可回查且路径作用域在本目录' "$(printf '%s' "$dr_scope" | tr '\n' '|')"
  fi
  # AC1 回归钉：authority／read_when 原文照录，目录外指针逐字保留，不再出现屏蔽记号
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief.out" \
    && grep -qF '规则权威＝rules/project.md §15.1' "$D/brief.out" \
    && grep -qF '另见 ../SKILL.md' "$D/brief.out" \
    && ! grep -qF '〈目录外〉' "$D/brief.out" \
    && ! grep -qF 'MASKED' "$D/brief.out"; then
    ok 'AC1 --brief authority／read_when 原文照录（目录外指针保留、无屏蔽记号）'
  else
    bad 'AC1 --brief authority／read_when 原文照录（目录外指针保留、无屏蔽记号）' "$(grep -F '规则权威' "$D/brief.out" | tr '\n' '|')"
  fi
  # AC1 现状 CHECK 回显含目录外引用时原样输出，理由文字不被改写
  dr_brief "$B/repo" refs
  dr_brief_rc=$(cat "$D/brief.rc")
  cp "$D/brief.out" "$D/brief-refs.out"
  dr_brief "$B/repo" docs
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief-refs.out" \
    && [ "$dr_brief_rc" -eq 0 ] \
    && grep -qF '引用路径不存在: other/missing.md' "$D/brief-refs.out" \
    && grep -qF '引用路径越出目标根: ../' "$D/brief-refs.out" \
    && ! grep -qF '〈目录外〉' "$D/brief-refs.out" \
    && ! grep -qF 'MASKED' "$D/brief-refs.out"; then
    ok 'AC1 --brief 现状 CHECK 回显的目录外引用原样输出'
  else
    bad 'AC1 --brief 现状 CHECK 回显的目录外引用原样输出' "exit=$dr_brief_rc $(grep -F 'CHECK 详情' "$D/brief-refs.out" | tr '\n' '|')"
  fi
  if grep -qF -- '- README.md：不存在' "$D/brief.out" \
    && grep -qF -- '- CHECK: 无文件可校验' "$D/brief.out" \
    && grep -qF -- '- 判断不出时写【填写：…】占位' "$D/brief.out"; then
    ok '正例 --brief 现状报缺 README、生成约定含占位与 25 行预算'
  else
    bad '正例 --brief 现状报缺 README、生成约定含占位与 25 行预算' "$(sed -n '/## BRIEF 现状/,$p' "$D/brief.out" | head -n 3 | tr '\n' '|')"
  fi

  # B2 降级：artifacts 缺失／缺 artifacts 段 → exit 0、一行 DEGRADED、仍出目录清单与约定
  dr_brief "$B/nofacts" docs
  dr_brief_rc=$(cat "$D/brief.rc")
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief.out" \
    && [ "$dr_brief_rc" -eq 0 ] \
    && grep -qE '^DEGRADED: artifacts 索引缺失；本次仅输出目录清单与生成约定$' "$D/brief.out" \
    && ! grep -q '^## BRIEF 判断证据' "$D/brief.out" \
    && grep -qxF '## BRIEF 目录清单' "$D/brief.out" \
    && grep -qxF '## BRIEF 生成约定' "$D/brief.out"; then
    ok '正例 --brief artifacts 缺失降级为两节并 exit 0'
  else
    bad '正例 --brief artifacts 缺失降级为两节并 exit 0' "exit=$dr_brief_rc $(head -n 2 "$D/brief.out" | tr '\n' '|')"
  fi
  dr_brief "$B/badfacts" docs
  dr_brief_rc=$(cat "$D/brief.rc")
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief.out" \
    && [ "$dr_brief_rc" -eq 0 ] \
    && grep -qE '^DEGRADED: artifacts 索引不可解析（缺 artifacts 段）' "$D/brief.out" \
    && ! grep -q '^## BRIEF 判断证据' "$D/brief.out"; then
    ok '正例 --brief artifacts 不可解析降级且不静默'
  else
    bad '正例 --brief artifacts 不可解析降级且不静默' "exit=$dr_brief_rc $(head -n 2 "$D/brief.out" | tr '\n' '|')"
  fi
  # 条目边界按任意 `  - ` 行切分：任一条目缺 id／path 都整索引降级，不部分采用
  dr_brief "$B/badentry" docs
  dr_brief_rc=$(cat "$D/brief.rc")
  if require_out 'suite-dir-readme 目标输出在场' "$D/brief.out" \
    && [ "$dr_brief_rc" -eq 0 ] \
    && grep -qE '^DEGRADED: artifacts 索引条目缺 id 或 path' "$D/brief.out" \
    && ! grep -q '^## BRIEF 判断证据' "$D/brief.out" \
    && ! grep -qF 'docs/b.md' "$D/brief.out"; then
    ok '负例 --brief artifacts 任一条目缺 id／path 整索引降级不部分采用'
  else
    bad '负例 --brief artifacts 任一条目缺 id／path 整索引降级不部分采用' "exit=$dr_brief_rc $(head -n 3 "$D/brief.out" | tr '\n' '|')"
  fi

  # B3 AC2／AC3：合规 README 现状判通过、--brief 零写入且连跑两次输出一致
  dr_base_readme "$B/repo/docs/README.md"
  tw_tree_digest "$B/repo" > "$D/brief-tree-before"
  sh "$G" --target "$B/repo" --check --dir docs >"$D/check.out" 2>"$D/check.err"
  dr_check_rc=$?
  dr_brief "$B/repo" docs
  tw_tree_digest "$B/repo" > "$D/brief-tree-after"
  cp "$D/brief.out" "$D/brief-first.out"
  dr_brief "$B/repo" docs
  if [ "$dr_check_rc" -eq 0 ] && [ ! -s "$D/check.out" ] \
    && grep -qF -- '- 四段：齐全' "$D/brief-first.out" \
    && grep -qF -- '- CHECK: 通过' "$D/brief-first.out"; then
    ok '正例 --brief 现状复用 --check 判定（合规 README 报齐全与通过）'
  else
    bad '正例 --brief 现状复用 --check 判定（合规 README 报齐全与通过）' "exit=$dr_check_rc $(sed -n '/## BRIEF 现状/,+3p' "$D/brief-first.out" | tr '\n' '|')"
  fi
  if cmp -s "$D/brief-tree-before" "$D/brief-tree-after"; then
    ok 'AC2 --brief 零写入（目录树 sha256 前后一致）'
  else
    bad 'AC2 --brief 零写入（目录树 sha256 前后一致）' "$(diff "$D/brief-tree-before" "$D/brief-tree-after" | tr '\n' '|')"
  fi
  if cmp -s "$D/brief-first.out" "$D/brief.out"; then
    ok 'AC3 --brief 连跑两次输出逐字节一致'
  else
    bad 'AC3 --brief 连跑两次输出逐字节一致' "$(diff "$D/brief-first.out" "$D/brief.out" | head -n 2 | tr '\n' '|')"
  fi

  # B4 现状缺段可见
  mkdir -p "$B/repo/sparse"
  printf '# sparse\n\n一句话职责。\n' > "$B/repo/sparse/README.md"
  dr_brief "$B/repo" sparse
  if [ "$(cat "$D/brief.rc")" -eq 0 ] \
    && grep -qF -- '- 四段：缺 ' "$D/brief.out" \
    && grep -qF -- '- CHECK: 不合规（' "$D/brief.out"; then
    ok '正例 --brief 现状列出缺段与逐条 CHECK 问题'
  else
    bad '正例 --brief 现状列出缺段与逐条 CHECK 问题' "$(sed -n '/## BRIEF 现状/,+6p' "$D/brief.out" | tr '\n' '|')"
  fi

  # B5 参数错误与互斥 → exit 2
  dr_brief_err=1
  sh "$G" --target "$B/repo" --brief docs --check >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '互斥' "$D/err" || dr_brief_err=0
  sh "$G" --target "$B/repo" --brief >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF -- '--brief 缺参数值' "$D/err" || dr_brief_err=0
  sh "$G" --target "$B/repo" --brief no/such/dir >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '目录不存在' "$D/err" || dr_brief_err=0
  sh "$G" --target "$B/repo" --brief docs --dir docs >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '不接受 --dir' "$D/err" || dr_brief_err=0
  sh "$G" --target "$B/repo" --brief docs --diff >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '只能与 --migrate-dry-run 连用' "$D/err" || dr_brief_err=0
  sh "$G" --target "$B/repo" --brief docs --sync >"$D/out" 2>"$D/err"
  [ "$?" -eq 2 ] && grep -qF '互斥' "$D/err" || dr_brief_err=0
  if [ "$dr_brief_err" -eq 1 ]; then
    ok '负例 --brief 与其它模式互斥、缺值、目录不存在、带 --dir／--diff 均 exit 2'
  else
    bad '负例 --brief 与其它模式互斥、缺值、目录不存在、带 --dir／--diff 均 exit 2' "$(tr '\n' '|' < "$D/err")"
  fi

  # B6 --help 登记 --brief 四节与降级语义
  sh "$G" --help >"$D/out" 2>"$D/err"
  if grep -qF -- '--brief <rel-dir>' "$D/out" \
    && grep -qF '## BRIEF 判断证据' "$D/out" \
    && grep -qF 'DEGRADED: <原因>' "$D/out"; then
    ok '正例 --help 登记 --brief 四节与降级语义'
  else
    bad '正例 --help 登记 --brief 四节与降级语义' "stdout=$(grep -F -- '--brief' "$D/out" | head -n 1)"
  fi


  suite_summary 'dir-readme-migrate'
}
