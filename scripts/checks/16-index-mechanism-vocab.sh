#!/bin/sh
# Input: check_16 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_mechanism
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 16（index-mechanism-vocab）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 16：索引机制列值 ⊆ 受控词表。对象＝生成索引 references/rules-index.md 机制列
# （五列表第 5 列）；词表＝清单 mechanism-vocab 节（受控三值，引擎零词表硬编码）。机制列
# 语法：受控值开头，可跟全角括注「（…）」（出处/说明，括注内容不做词表核验、禁嵌套与
# 全角分号），可跟「；」分段（每段须为词表值）。BSD awk 的 index/substr 对多字节字符
# 语义混合不可靠，故先经 sed 把全角括号/分号规范化为 ASCII 再解析（字面替换为字节级，
# 可靠）；剥离后残留括号判括号不配对（fail-closed）。

check_16() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
idx_mech=$(mktemp "${t_dir%/}/idxmech.XXXXXX")
n_row16=$(chk_index_mech_load "$idx_file" "$idx_mech")
mechs=$(cat "$pm_mechs")
n_mechs=$(printf '%s\n' "$mechs" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }')
n_row16=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$idx_mech")
if [ "$n_row16" -eq 0 ]; then
  add_problem '  - 索引表零行，机制列无从核对'
else
  awk_rc=0
  hits16=$(sed -e 's/（/(/g' -e 's/）/)/g' -e 's/；/;/g' "$idx_mech" | LC_ALL=C VOCAB="$mechs" awk -F'\t' '
    BEGIN {
      nv = split(ENVIRON["VOCAB"], V, "\n")
      for (k = 1; k <= nv; k++) if (V[k] != "") voc[V[k]] = 1
    }
    NF {
      id = $1
      t = $2
      gsub(/\([^)]*\)/, "", t)
      gsub(/[ \t]/, "", t)
      if (t ~ /[()]/) { printf "%s\t机制列括号不配对\n", id; next }
      if (t == "") { printf "%s\t机制列为空\n", id; next }
      n = split(t, T, ";")
      for (k = 1; k <= n; k++) {
        if (T[k] == "") { printf "%s\t机制列含空段\n", id; continue }
        if (!(T[k] in voc)) printf "%s\t机制值不在受控词表: %s\n", id, T[k]
      }
    }
  ') || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 16 扫描器异常（awk exit %s）\n' "$awk_rc" >&2
    exit 2
  fi
  if [ -n "$hits16" ]; then
    OLDIFS=$IFS
    IFS='
'
    for h in $hits16; do
      IFS=$OLDIFS
      h_id=${h%%"$TAB"*}
      h_msg=${h#*"$TAB"}
      add_problem "  - $h_id $h_msg"
    done
    IFS=$OLDIFS
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc="索引机制列受控词表（机制 ${n_mechs} 值）"
else
  _chk_desc="索引机制列受控词表（机制 ${n_mechs} 值）"
fi
rm -f "$idx_mech"
:
}
