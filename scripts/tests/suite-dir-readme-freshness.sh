#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite dir-readme-freshness "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: dir-readme-freshness（票 291 自 suite-dir-readme 拆出的新鲜度与结构限定能力面）：
# --freshness 只读新鲜度断言（缺失行/多余行逐条 path:line）与 --check --blocks-only 结构
# 限定；含 --brief 末段 BrokenPipe exit 3 与 --help 登记断言。

suite_dir_readme_freshness() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='dir-readme-freshness'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/drf
  mkdir -p "$D"
  G="$SCRIPT_DIR/generate-dir-readmes.sh"
  # 尾段 BrokenPipe 用例复用 --brief 夹具根（原 brief 段）；树指纹用公共 tw_tree_digest
  B=$D/brief
  mkdir -p "$B/repo/docs"
  : > "$B/repo/docs/a.md"

  # ---- 生成块新鲜度（--freshness）与结构限定（--check --blocks-only）----
  F=$D/fresh
  rm -rf "$F"
  mkdir -p "$F/repo/docs/child" "$F/repo/legacy"
  printf '# child\n\n子目录职责句。\n' > "$F/repo/docs/child/README.md"
  cat > "$F/repo/docs/README.md" <<'EOF'
# docs

文档目录职责句。

## 权威
- 现行：`docs/child/README.md`

## 读取禁忌
- 不把本文件当白名单。

## 子目录
<!-- dir-readme: generated dir=docs -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
| `docs/child/` | 子目录职责句。 | — |
<!-- /dir-readme -->
EOF
  # 旧格式目录：无生成块、有成员表（全范围 --check 会报，blocks-only 应跳过）
  cat > "$F/repo/legacy/README.md" <<'EOF'
# legacy

旧格式目录。

## 成员
| 名字 | 说明 |
| --- | --- |
| a | 说明 |
EOF

  # F1 干净生成块 → exit 0 且双零输出
  sh "$G" --target "$F/repo" --freshness >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/fresh.out" ] && [ ! -s "$D/fresh.err" ]; then
    ok '正例 --freshness 生成块与现状一致 → exit 0 且 stdout/stderr 零输出'
  else
    bad '正例 --freshness 生成块与现状一致 → exit 0 且 stdout/stderr 零输出' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi

  # F2 --check --blocks-only 跳过旧格式 README；全范围 --check 仍报（限定不是放宽）
  sh "$G" --target "$F/repo" --check --blocks-only >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/fresh.out" ] && [ ! -s "$D/fresh.err" ]; then
    ok '正例 --check --blocks-only 只校验含生成块的 README（旧格式无块跳过）'
  else
    bad '正例 --check --blocks-only 只校验含生成块的 README（旧格式无块跳过）' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi
  sh "$G" --target "$F/repo" --check >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qE '^legacy/README\.md:[0-9]+: ' "$D/fresh.err" \
    && grep -qF '成员表' "$D/fresh.err"; then
    ok '对照 全范围 --check 对旧格式 README 仍 exit 2（blocks-only 是收口限定）'
  else
    bad '对照 全范围 --check 对旧格式 README 仍 exit 2（blocks-only 是收口限定）' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi

  # F3 新增子目录未入表 → exit 1 报「缺失行」，且零写入
  mkdir -p "$F/repo/docs/newdir"
  printf '# newdir\n\n新增子目录职责句。\n' > "$F/repo/docs/newdir/README.md"
  dr_migrate_tree "$F/repo" > "$D/fresh-tree-before"
  _fresh_sha_before=$(grep ' docs/README.md$' "$D/fresh-tree-before")
  sh "$G" --target "$F/repo" --freshness >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  dr_migrate_tree "$F/repo" > "$D/fresh-tree-after"
  if [ "$rc" -eq 1 ] && [ ! -s "$D/fresh.out" ] \
    && grep -qE '^docs/README\.md:[0-9]+: 缺失行: .*docs/newdir/' "$D/fresh.err" \
    && grep -qF 'SUMMARY: 生成块漂移 1 件（缺失 1 行／多余 0 行）' "$D/fresh.err"; then
    ok '负例 --freshness 新增子目录未入表 → exit 1 指名 docs/README.md:行 缺失行'
  else
    bad '负例 --freshness 新增子目录未入表 → exit 1 指名 docs/README.md:行 缺失行' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi
  if cmp -s "$D/fresh-tree-before" "$D/fresh-tree-after" \
    && [ "$_fresh_sha_before" = "$(grep ' docs/README.md$' "$D/fresh-tree-after")" ]; then
    ok 'AC1 --freshness 零写入（目录树 sha256 与 docs/README.md 字节前后一致）'
  else
    bad 'AC1 --freshness 零写入（目录树 sha256 与 docs/README.md 字节前后一致）' "$(diff "$D/fresh-tree-before" "$D/fresh-tree-after" | head -n 2 | tr '\n' '|')"
  fi

  # F4 删除子目录未删表 → exit 1 报「多余行」
  rm -rf "$F/repo/docs/newdir" "$F/repo/docs/child"
  sh "$G" --target "$F/repo" --freshness >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -s "$D/fresh.out" ] \
    && grep -qE '^docs/README\.md:[0-9]+: 多余行: .*docs/child/' "$D/fresh.err" \
    && grep -qF 'SUMMARY: 生成块漂移 1 件（缺失 0 行／多余 1 行）' "$D/fresh.err"; then
    ok '负例 --freshness 删除子目录未删表 → exit 1 指名 docs/README.md:行 多余行'
  else
    bad '负例 --freshness 删除子目录未删表 → exit 1 指名 docs/README.md:行 多余行' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi
  mkdir -p "$F/repo/docs/child"
  printf '# child\n\n子目录职责句。\n' > "$F/repo/docs/child/README.md"

  # F5 无生成块 README 静默跳过（--dir 限定单目录）
  sh "$G" --target "$F/repo" --freshness --dir legacy >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/fresh.out" ] && [ ! -s "$D/fresh.err" ]; then
    ok '正例 --freshness 无生成块 README 静默跳过 → exit 0 零输出'
  else
    bad '正例 --freshness 无生成块 README 静默跳过 → exit 0 零输出' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi

  # F6 块未闭合 → exit 2 指名 file:line（复用 --check 块级判定）
  mkdir -p "$F/repo/bad"
  cat > "$F/repo/bad/README.md" <<'EOF'
# bad

职责句。

## 权威
- 现行：无

## 读取禁忌
- 无

## 子目录
<!-- dir-readme: generated dir=bad -->
| 子目录 | 一句话 | 禁忌 |
| --- | --- | --- |
EOF
  sh "$G" --target "$F/repo" --freshness --dir bad >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 2 ] && grep -qE '^bad/README\.md:[0-9]+: 生成块未闭合' "$D/fresh.err"; then
    ok '负例 --freshness 块未闭合 → exit 2 指名 file:line（与 --check 同口径）'
  else
    bad '负例 --freshness 块未闭合 → exit 2 指名 file:line（与 --check 同口径）' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi
  rm -rf "$F/repo/bad"

  # F7 参数互斥：--freshness 与其它模式、--blocks-only 与非 check 模式同用均 exit 2；
  # --blocks-only 单独出现按缺省 check 模式（等效 --check --blocks-only）执行
  sh "$G" --target "$F/repo" --blocks-only >"$D/fresh.out" 2>"$D/fresh.err"
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/fresh.out" ] && [ ! -s "$D/fresh.err" ]; then
    ok '正例 --blocks-only 单独出现按缺省 check 模式执行（等效 --check --blocks-only）'
  else
    bad '正例 --blocks-only 单独出现按缺省 check 模式执行（等效 --check --blocks-only）' "exit=$rc $(head -n 2 "$D/fresh.err" | tr '\n' '|')"
  fi
  dr_fresh_err=1
  sh "$G" --target "$F/repo" --freshness --sync >"$D/fresh.out" 2>"$D/fresh.err"
  [ "$?" -eq 2 ] && grep -qF '互斥' "$D/fresh.err" || dr_fresh_err=0
  sh "$G" --target "$F/repo" --freshness --check >"$D/fresh.out" 2>"$D/fresh.err"
  [ "$?" -eq 2 ] && grep -qF '互斥' "$D/fresh.err" || dr_fresh_err=0
  sh "$G" --target "$F/repo" --blocks-only --sync >"$D/fresh.out" 2>"$D/fresh.err"
  [ "$?" -eq 2 ] && grep -qF -- '--blocks-only 只能与 --check 连用' "$D/fresh.err" || dr_fresh_err=0
  sh "$G" --target "$F/repo" --blocks-only --migrate-dry-run >"$D/fresh.out" 2>"$D/fresh.err"
  [ "$?" -eq 2 ] && grep -qF -- '--blocks-only 只能与 --check 连用' "$D/fresh.err" || dr_fresh_err=0
  if [ "$dr_fresh_err" -eq 1 ]; then
    ok '负例 --freshness 与其它模式互斥、--blocks-only 与非 check 模式同用均 exit 2'
  else
    bad '负例 --freshness 与其它模式互斥、--blocks-only 与非 check 模式同用均 exit 2' "$(tr '\n' '|' < "$D/fresh.err")"
  fi

  # F8 --help 登记 --freshness 与 --blocks-only 语义
  sh "$G" --help >"$D/fresh.out" 2>"$D/fresh.err"
  if grep -qF -- '--freshness' "$D/fresh.out" \
    && grep -qF -- '--blocks-only' "$D/fresh.out" \
    && grep -qF '缺失行' "$D/fresh.out"; then
    ok '正例 --help 登记 --freshness／--blocks-only 与缺失行文案'
  else
    bad '正例 --help 登记 --freshness／--blocks-only 与缺失行文案' "stdout=$(grep -F -- '--freshness' "$D/fresh.out" | head -n 1)"
  fi

  # B9 截断输出不得报成功：stdout 管道被下游关闭（BrokenPipe）→ exit 3 且无 traceback。
  python3 - "$G" "$B/repo" <<'PY'
import os, subprocess, sys
r, w = os.pipe()
os.close(r)
p = subprocess.run(["sh", sys.argv[1], "--target", sys.argv[2], "--brief", "docs"],
                   stdout=w, stderr=subprocess.PIPE)
os.close(w)
sys.exit(0 if (p.returncode == 3 and b"Traceback" not in p.stderr) else 1)
PY
  dr_pipe_rc=$?
  if [ "$dr_pipe_rc" -eq 0 ]; then
    ok '负例 --brief stdout 被下游关闭 → exit 3（截断不报成功）且无 traceback'
  else
    bad '负例 --brief stdout 被下游关闭 → exit 3（截断不报成功）且无 traceback' '见 python 断言'
  fi

  suite_summary 'dir-readme-freshness'
}
