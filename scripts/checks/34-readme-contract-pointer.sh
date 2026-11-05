#!/bin/sh
# Input: check_34 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_contract_pointer
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 34（readme-contract-pointer）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 34：README 非唯一执行契约（票 219 新增；217 交付面核对）。清单 contract-pointers
# 节逐行：含锚点词的 README 行须含指针原文（执行契约正文不得以 README 自任唯一，须指向
# 权威件），权威文件须真实存在且含权威锚点；README 任一行出现「唯一声明处＝本」
# 「唯一执行契约＝本」自任契约形态即 FAIL（执行契约须落在 schema/协议件）。

check_34() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n34_ptrs=0
n34_lines=0
while IFS="$(printf '\t')" read -r c34_readme c34_anchor c34_ptr c34_auth c34_aanchor; do
  [ -n "$c34_readme" ] || continue
  n34_ptrs=$((n34_ptrs + 1))
  if [ ! -f "$pkg_root/$c34_readme" ]; then
    add_problem "  - $c34_readme 冲突类型=契约承载 README 缺失（规则 contract-pointer · 锚点「${c34_anchor}」）"
    continue
  fi
  c34_hits=$(grep -nF -- "$c34_anchor" "$pkg_root/$c34_readme" || true)
  if [ -z "$c34_hits" ]; then
    add_problem "  - $c34_readme 冲突类型=契约锚点未命中（规则 contract-pointer · 锚点「${c34_anchor}」）"
  else
    OLDIFS=$IFS
    IFS='
'
    for c34_h in $c34_hits; do
      IFS=$OLDIFS
      c34_ln=${c34_h%%:*}
      c34_text=${c34_h#*:}
      case $c34_text in
        *"$c34_ptr"*) n34_lines=$((n34_lines + 1)) ;;
        *)
          add_problem "  - $c34_readme:$c34_ln 冲突类型=README 独占执行契约（规则 contract-pointer · 锚点「${c34_anchor}」缺指针 ${c34_ptr}）"
          ;;
      esac
    done
    IFS=$OLDIFS
  fi
  if [ ! -f "$pkg_root/$c34_auth" ]; then
    add_problem "  - $c34_auth 冲突类型=契约权威件缺失（规则 contract-pointer · README 指针悬空）"
  elif ! grep -qF -- "$c34_aanchor" "$pkg_root/$c34_auth"; then
    add_problem "  - $c34_auth 冲突类型=权威件缺契约锚点（规则 contract-pointer · 锚点「${c34_aanchor}」）"
  fi
done < "$pm_cptrs"
c34_readmes=$(cd "$pkg_root" && find . -type f -name 'README.md' | sed 's|^\./||' | LC_ALL=C sort)
OLDIFS=$IFS
IFS='
'
for c34_r in $c34_readmes; do
  IFS=$OLDIFS
  [ -n "$c34_r" ] || continue
  c34_claim=$(grep -nE '唯一(声明处|执行契约)＝本[ ]*(README|文件|文档)' "$pkg_root/$c34_r" || true)
  if [ -n "$c34_claim" ]; then
    OLDIFS=$IFS
    IFS='
'
    for c34_c in $c34_claim; do
      IFS=$OLDIFS
      c34_cln=${c34_c%%:*}
      add_problem "  - $c34_r:$c34_cln 冲突类型=README 自任唯一执行契约（规则 contract-pointer · 执行契约须指向 schema/协议件）"
    done
    IFS=$OLDIFS
  fi
done
IFS=$OLDIFS
if [ -n "$problems" ]; then
  _chk_desc="README 非唯一执行契约（登记指针 ${n34_ptrs} 条，自带指针 ${n34_lines} 行）"
else
  _chk_desc="README 非唯一执行契约（登记指针 ${n34_ptrs} 条，自带指针 ${n34_lines} 行）"
fi
:
}
