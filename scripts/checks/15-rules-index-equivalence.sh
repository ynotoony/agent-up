#!/bin/sh
# Input: check_15 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 15（rules-index-equivalence）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 15：生成索引与包内规则块全集全等且零漂移（安装面收敛适配）。唯一对象＝
# references/rules-index.md（generate-docs-index.sh 独占写；模板 §16 手写索引已退役）。
# 两项断言：
#   ①全集全等——索引表行 ID 集 = 包内全部 *.md/*.tmpl 的规则块 ID 集（排除索引自身），
#     双向缺/多即 FAIL 指名；
#   ②零漂移——generate-docs-index.sh --check exit 0（渲染结果与磁盘逐字比对，generated_at
#     行规范化）；exit 1 附 diff 指名差异行，其它退出码视为环境或形态错误一并 FAIL。
# 生成器或索引缺失即 FAIL（不静默过）；本项只读，--check 零写入。

check_15() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
gen_docs="$pkg_root/$scripts_dir/generate-docs-index.sh"
n_idx=0
n_union=0
if [ ! -f "$gen_docs" ]; then
  add_problem "  - 规则索引生成器不存在: ${scripts_dir}/generate-docs-index.sh"
fi
if [ ! -f "$idx_file" ]; then
  add_problem '  - 生成索引不存在: references/rules-index.md（先运行 generate-docs-index.sh 落盘）'
else
  idx_ids=$(LC_ALL=C awk -F'|' '
    /^\| R-[A-Z][A-Z]-[0-9][0-9][0-9] /{
      id = $2; gsub(/[ \t]/, "", id); print id
    }
  ' "$idx_file" | LC_ALL=C sort -u)
  n_idx=$(printf '%s\n' "$idx_ids" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }')
  union_ids=''
  OLDIFS=$IFS
  IFS='
'
  for t in $file_list; do
    IFS=$OLDIFS
    [ "$t" = "$idx_file" ] && continue
    hits=$(grep -hoE '^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]' "$t" 2>/dev/null | sed 's/^#### //' || true)
    if [ -n "$hits" ]; then
      union_ids="$union_ids$hits
"
    fi
  done
  IFS=$OLDIFS
  union_ids=$(printf '%s' "$union_ids" | LC_ALL=C sort -u)
  n_union=$(printf '%s\n' "$union_ids" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }')
  if [ "$n_idx" -eq 0 ]; then
    add_problem '  - 索引表零行（生成索引无规则块表行）'
  fi
  extra=''; sep2=''
  OLDIFS=$IFS
  IFS='
'
  for id in $idx_ids; do
    IFS=$OLDIFS
    if ! printf '%s\n' "$union_ids" | grep -qxF "$id"; then
      extra="$extra$sep2$id"
      sep2='、'
    fi
  done
  IFS=$OLDIFS
  missing=''; sep2=''
  for id in $union_ids; do
    if ! printf '%s\n' "$idx_ids" | grep -qxF "$id"; then
      missing="$missing$sep2$id"
      sep2='、'
    fi
  done
  if [ -n "$extra" ]; then
    add_problem "  - 索引多出全集外 ID: $extra"
  fi
  if [ -n "$missing" ]; then
    add_problem "  - 规则块缺索引行: $missing"
  fi
fi
if [ -f "$gen_docs" ] && [ -f "$idx_file" ]; then
  gen_rc=0
  gen_out=$(sh "$gen_docs" --check "$pkg_root" 2>&1) || gen_rc=$?
  case $gen_rc in
    0) : ;;
    1) add_problem "  - 生成索引与规则块不一致（stale，--check exit 1）：$(printf '%s\n' "$gen_out" | head -n 12)" ;;
    *) add_problem "  - 生成器 --check 非预期退出（exit ${gen_rc}）：$(printf '%s\n' "$gen_out" | head -n 6)" ;;
  esac
fi
if [ -n "$problems" ]; then
  _chk_desc="生成索引与规则块全集全等且零漂移（索引 ${n_idx} 行，全集 ${n_union} ID）"
else
  _chk_desc="生成索引与规则块全集全等且零漂移（索引 ${n_idx} 行，全集 ${n_union} ID）"
fi
:
}
