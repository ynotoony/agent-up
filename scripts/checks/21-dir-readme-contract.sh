#!/bin/sh
# Input: 调用方（21-references-member-closure.sh 检查件）已就绪的 pkg_root 与 add_problem。
# Output: chk21_readme_contract：整包目录 README 契约两检（generate-dir-readmes --check
#        --blocks-only 结构、--freshness 生成块新鲜度）失败逐条并入 problems；只读零写入。
# Pos: 检查 21 的目录 README 兜底判定面模块（票 294：从 21 件按判定面拆出）；references
#      成员闭合与链接导航判定仍在 21-references-member-closure.sh。
# shellcheck disable=SC2154  # 跨件共享状态（引擎上下文与 problems），单文件视野误报

chk21_readme_contract() {
# ④目录 README 兜底（票 266，只读两检；与收口链、升级流程同口径）
#   ①--check --blocks-only：只校验含生成块的 README 四段结构，旧格式无生成块跳过；
#   ②--freshness：在内存重算 --sync 应产出块逐行比对，漂移即指名缺失／多余行。
#   两检都不写文件；生成器缺失由检查 8 覆盖，本段不重复报；无启用目录时零动作（不作为即通过）。
if [ -f "$pkg_root/scripts/generate-dir-readmes.sh" ]; then
  dr_gen="$pkg_root/scripts/generate-dir-readmes.sh"
  dr_rules="$pkg_root/scripts/dir-readme.rules"
  _dr_err=''
  if ! _dr_err=$(sh "$dr_gen" --target "$pkg_root" --rules "$dr_rules" --check --blocks-only 2>&1); then
    while IFS= read -r _dr_line; do
      [ -n "$_dr_line" ] || continue
      add_problem "  - 目录 README 结构校验未过: $_dr_line"
    done <<EOF
${_dr_err}
EOF
  fi
  _dr_err=''
  if ! _dr_err=$(sh "$dr_gen" --target "$pkg_root" --rules "$dr_rules" --freshness 2>&1); then
    while IFS= read -r _dr_line; do
      [ -n "$_dr_line" ] || continue
      add_problem "  - 目录 README 生成块新鲜度未过: $_dr_line"
    done <<EOF
${_dr_err}
EOF
  fi
fi
}
