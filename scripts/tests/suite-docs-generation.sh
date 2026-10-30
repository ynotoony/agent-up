#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite docs-generation "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用
# ============================================================
# suite: docs-generation（规则索引生成器回归）
#   ①现行包 --check 零漂移 PASS；②手改索引一行 → exit 1 指名差异；
#   ③新增一个已登记机制的规则块 → --check exit 1 指名缺行；
#   ③b 新增未登记机制的规则块 → exit 2 fail-closed（不静默兜底）；
#   ④生成结果含全部十条 R-CO。
# 夹具全 mktemp：最小包副本只复制 SKILL.md、核心模板、生成器与共享库。
# ============================================================

suite_docs_generation() {
  # shellcheck disable=SC2034
  CUR_SUITE='docs-generation'
  # shellcheck disable=SC2034
  SUITE_FAILS=0
  # shellcheck disable=SC2034
  SUITE_START=$TOTAL
  D=$T/docsgen
  mkdir -p "$D"

  GEN="$SCRIPT_DIR/generate-docs-index.sh"
  IDX="$PKG_ROOT/references/rules-index.md"
  CORE="$PKG_ROOT/references/templates/core.md.tmpl"

  if [ ! -f "$GEN" ] || [ ! -f "$IDX" ] || [ ! -f "$CORE" ]; then
    bad '生成器、生成索引与核心模板在场' "缺件：$GEN / $IDX / $CORE"
    suite_summary 'docs-generation'
    return 1
  fi

  # ① 现行包零漂移
  out=$D/check1.log
  sh "$GEN" --check "$PKG_ROOT" >"$out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'CHECK: PASS' "$out"; then
    ok '现行包 --check 零漂移 exit 0'
  else
    bad '现行包 --check 零漂移 exit 0' "$(sed -n '1,6p' "$out")"
  fi

  # 夹具包：整包副本（机制登记表覆盖包内全部块，缩面夹具会触发「登记条目无对应块」）
  rm -rf "$D/pkg"
  cp -R "$PKG_ROOT" "$D/pkg"
  cp "$D/pkg/references/templates/core.md.tmpl" "$D/pkg/references/templates/core.md.orig"
  if [ $? -eq 0 ] && [ -f "$D/pkg/references/rules-index.md" ]; then
    ok '夹具包首轮生成落盘'
  else
    bad '夹具包首轮生成落盘' "$(sed -n '1,6p' "$D/gen.log")"
    suite_summary 'docs-generation'
    return 1
  fi

  # ④ 十条 R-CO 全在生成索引内
  miss=''
  for n in 001 002 003 004 005 006 007 008 009 010; do
    grep -q "| R-CO-$n |" "$D/pkg/references/rules-index.md" || miss="$miss R-CO-$n"
  done
  if [ -z "$miss" ]; then
    ok '生成索引含全部十条 R-CO'
  else
    bad '生成索引含全部十条 R-CO' "缺：$miss"
  fi

  # ② 手改索引一行 → exit 1 指名差异
  sed 's/授权先于写入/授权先写入/' "$D/pkg/references/rules-index.md" > "$D/pkg/references/rules-index.tmp" \
    && mv "$D/pkg/references/rules-index.tmp" "$D/pkg/references/rules-index.md"
  out=$D/check2.log
  sh "$D/pkg/scripts/generate-docs-index.sh" --check "$D/pkg" >"$out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'R-CO-001' "$out"; then
    ok '手改索引一行 → --check exit 1 并指名差异行'
  else
    bad '手改索引一行 → --check exit 1 并指名差异行' "rc=$rc $(sed -n '1,6p' "$out")"
  fi
  sh "$D/pkg/scripts/generate-docs-index.sh" "$D/pkg" >/dev/null 2>&1

  # ③ 新增已登记机制的规则块 → exit 1（索引缺行）
  sed 's/^R-CO-010|约定$/R-CO-010|约定\nR-CO-099|门禁/' "$D/pkg/scripts/generate-docs-index.sh" > "$D/gen.tmp" \
    && mv "$D/gen.tmp" "$D/pkg/scripts/generate-docs-index.sh"
  cat >> "$D/pkg/references/templates/core.md.tmpl" <<'EOF'

## C11 夹具块

#### R-CO-099 夹具块 `MUST`

- **When**：夹具
- **Action**：夹具
- **Forbidden**：夹具
- **Stop if**：夹具
- **Evidence**：夹具
- **Owner**：夹具
- **Authority**：夹具
EOF
  out=$D/check3.log
  sh "$D/pkg/scripts/generate-docs-index.sh" --check "$D/pkg" >"$out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'R-CO-099' "$out"; then
    ok '新增已登记机制的块 → --check exit 1 指名缺行'
  else
    bad '新增已登记机制的块 → --check exit 1 指名缺行' "rc=$rc $(sed -n '1,8p' "$out")"
  fi

  # ③b 新增未登记机制的块 → exit 2 fail-closed（不静默兜底）
  cat >> "$D/pkg/references/templates/core.md.tmpl" <<'EOF'

#### R-CO-098 未登记机制夹具 `MUST`

- **When**：夹具
- **Action**：夹具
- **Forbidden**：夹具
- **Stop if**：夹具
- **Evidence**：夹具
- **Owner**：夹具
- **Authority**：夹具
EOF
  out=$D/check4.log
  sh "$D/pkg/scripts/generate-docs-index.sh" --check "$D/pkg" >"$out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'R-CO-098' "$out"; then
    ok '新增未登记机制的块 → exit 2 fail-closed 并指名'
  else
    bad '新增未登记机制的块 → exit 2 fail-closed 并指名' "rc=$rc $(sed -n '1,8p' "$out")"
  fi

  # 生成器只写索引文件：夹具模板在 --check 前后逐字节不变
  cp "$D/pkg/references/templates/core.md.tmpl" "$D/pkg/references/templates/keep.tmpl"
  sh "$D/pkg/scripts/generate-docs-index.sh" --check "$D/pkg" >/dev/null 2>&1 || true
  if cmp -s "$D/pkg/references/templates/keep.tmpl" "$D/pkg/references/templates/core.md.tmpl"; then
    ok '--check 零写入（夹具模板逐字节不变）'
  else
    bad '--check 零写入（夹具模板逐字节不变）' '模板被改写'
  fi

  suite_summary 'docs-generation'
}
