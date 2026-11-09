#!/bin/sh
# Input: 调用方（14-capability-mapping.sh 检查件）已就绪的 pkg_root／pm_enf／pm_enfvocab／
#        TAB／add_problem 与 problems。
# Output: chk14_enforcement_face：enforcement 词表受控与逐适配器 readonly-execute 等级声明
#        核对（缺声明/词表外/不一致并入 problems；行未命中 exit 2 不静默过）；n_enf 供描述。
# Pos: 检查 14 的 enforcement 判定面模块（票 294：从 14 件按判定面拆出）；能力基元映射
#      判定仍在 14-capability-mapping.sh。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎上下文与 problems/n_enf），单文件视野误报

enf_extract_decl() {
  # $1=文件：「| 能力基元」对照表中 readonly-execute 行的 readonly_enforcement: 等级
  # token；行未命中 exit 3（fail-closed），行在而声明缺失输出空（调用方报缺声明）。
  LC_ALL=C awk -v mk='| 能力基元' '
    function firstcell(line,   s) {
      s = line
      sub(/^\|[[:space:]]*/, "", s)
      sub(/[[:space:]]*\|.*/, "", s)
      return s
    }
    index($0, mk) == 1 { inh = 1; next }
    inh && !sep && $0 ~ /^\|/ { c = firstcell($0); if (c ~ /^[-: ]+$/) sep = 1; next }
    inh && sep && $0 ~ /^\|/ {
      if (firstcell($0) == "readonly-execute") {
        i = index($0, "readonly_enforcement:")
        if (i > 0) {
          rest = substr($0, i + length("readonly_enforcement:"))
          sub(/^[[:space:]]+/, "", rest)
          if (match(rest, /[a-z][a-z-]*/)) print substr(rest, RSTART, RLENGTH)
        }
        found = 1
        exit
      }
      next
    }
    inh && sep && $0 !~ /^\|/ { exit }
    END { if (!found) exit 3 }
  ' "$1"
}

chk14_enforcement_face() {
# 检查 14 扩展维度（readonly-execute 只读约束等级）：词表受控（enforcement 词表节）＋
# 逐适配器对照表 readonly-execute 行提取 readonly_enforcement: 等级 token，与登记预期
# 值全等比对；预期/声明值不在词表、缺声明、值不一致即 FAIL 指名文件；readonly-execute
# 行未命中（表锚点失效或行被删）即 exit 2 不静默过（本检查既有 fail-closed 同款）。
n_enf=$(wc -l < "$pm_enf" | tr -d ' ')
enf_vocab_sorted=$(LC_ALL=C sort -u "$pm_enfvocab")
OLDIFS=$IFS
IFS='
'
while IFS= read -r enf_row; do
  IFS=$OLDIFS
  [ -n "$enf_row" ] || continue
  enf_rel=${enf_row%%"$TAB"*}
  enf_exp=${enf_row#*"$TAB"}
  enf_file="$pkg_root/$enf_rel"
  if [ ! -f "$enf_file" ]; then
    add_problem "  - enforcement 检查目标不存在: $enf_rel"
    continue
  fi
  if ! printf '%s\n' "$enf_vocab_sorted" | grep -qx "$enf_exp"; then
    add_problem "  - $enf_rel 登记预期等级不在受控词表: $enf_exp"
    continue
  fi
  rc=0
  enf_got=$(enf_extract_decl "$enf_file") || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 14 enforcement 目标解析失效（readonly-execute 行未命中，fail-closed）: %s\n' "$enf_rel" >&2
    exit 2
  fi
  if [ -z "$enf_got" ]; then
    add_problem "  - $enf_rel readonly-execute 行缺 readonly_enforcement 声明"
  elif ! printf '%s\n' "$enf_vocab_sorted" | grep -qx "$enf_got"; then
    add_problem "  - $enf_rel readonly_enforcement 值不在受控词表: $enf_got"
  elif [ "$enf_got" != "$enf_exp" ]; then
    # 花括号不可省略：变量名后紧跟全角字符时，sh 会把多字节字符并入变量名（同款先例见检查 5/12）。
    add_problem "  - $enf_rel readonly_enforcement 声明与登记预期不一致: ${enf_got}（期望 ${enf_exp}）"
  fi
done < "$pm_enf"
IFS=$OLDIFS
}
