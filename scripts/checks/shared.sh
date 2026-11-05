#!/bin/sh
# Input: check-package.sh 分发前载入；函数参数为包根相对数据（索引文件路径、输出临时文件）。
# Output: 共享只读派生函数（检查件之间零隐式状态；每件按需自算，退役/崩溃不传导）。
# Pos: 检查件共享辅助模块（注册表发现面仅含检查件 NN-slug.sh；本件由引擎固定载入）。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

chk_index_mech_load() {
  # $1=索引文件 $2=输出临时文件（机制列投影：ID<TAB>机制单元格）→ stdout＝行数
  _cim_idx=$1
  _cim_out=$2
  : > "$_cim_out"
  if [ -f "$_cim_idx" ]; then
    LC_ALL=C awk -F'|' '
      /^\| R-[A-Z][A-Z]-[0-9][0-9][0-9] /{
        id = $2; gsub(/[ \t]/, "", id)
        cell = $6
        sub(/^[ \t]+/, "", cell); sub(/[ \t]+$/, "", cell)
        if (cell == "") next
        print id "\t" cell
      }
    ' "$_cim_idx" >> "$_cim_out"
  fi
  LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$_cim_out"
}
