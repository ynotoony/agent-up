#!/bin/sh
# Input: 调用方（37-model-tier-contract.sh 检查件）已就绪的 pkg_root／add_problem／problems
#        与 a37_* 通用读值器（a37_get）。
# Output: §2.7 短上下文别名与到线策略判定面：a37_vocab（词表读值）、a37_in_vocab（落表
#        判定）、a37_check_27（段在位/四条 bullet/受控词表/显式覆盖/证据闸逐项断言）。
# Pos: 检查 37 的 §2.7 契约段模块（票 294：双契约段按判定面拆分）；§2.6 模型档位可用性
#      判定仍在 37-model-tier-contract.sh。
# shellcheck disable=SC2154  # 跨件共享状态（引擎上下文与 problems），单文件视野误报

a37_vocab() {
  LC_ALL=C awk -v want="$2" -F'|' '
    function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
    /^## 短上下文别名与到线词表/ { top = 1; next }
    top && /^## / { top = 0 }
    top && /^### / { sec = $0; sub(/^### /, "", sec); sub(/词表.*$/, "", sec); next }
    top && sec == want && /^\|/ {
      c1 = trim($2)
      if (c1 == "取值" || c1 ~ /^-+$/) next
      gsub(/`/, "", c1)
      if (c1 != "") print c1
    }' "$1"
}
a37_in_vocab() {
  a37_v_ok=1
  while IFS= read -r a37_v_item; do
    [ -n "$a37_v_item" ] || continue
    case $1 in
      "$a37_v_item"|"$a37_v_item"（*|"$a37_v_item"\(*) a37_v_ok=0; break ;;
    esac
  done <<EOF
$2
EOF
  [ "$a37_v_ok" -eq 0 ]
}
a37_check_27() {
  a37_27_rel=$1
  a37_27_kind=$2
  a37_27_abs="$pkg_root/$a37_27_rel"
  [ -f "$a37_27_abs" ] || return 0
  if ! grep -q '^### 2\.7 短上下文别名与到线策略' "$a37_27_abs"; then
    add_problem "  - ${a37_27_rel} 缺「### 2.7 短上下文别名与到线策略」段"
    return 0
  fi
  for a37_27_lab in 短上下文别名取值 到线行为 'Agent 工具显式覆盖' 降级记录格式; do
    a37_27_cnt=$(a37_get "$a37_27_abs" "$a37_27_lab" count '2\.7 ')
    a37_27_val=$(a37_get "$a37_27_abs" "$a37_27_lab" value '2\.7 ')
    if [ "$a37_27_cnt" -ne 1 ]; then
      add_problem "  - ${a37_27_rel} §2.7「${a37_27_lab}」行应恰 1 行（实为 ${a37_27_cnt} 行）"
    elif [ -z "$a37_27_val" ]; then
      add_problem "  - ${a37_27_rel} §2.7「${a37_27_lab}」取值为空"
    fi
  done
  [ "$a37_27_kind" = host ] || return 0
  a37_27_alias=$(a37_get "$a37_27_abs" 短上下文别名取值 value '2\.7 ')
  a37_27_bound=$(a37_get "$a37_27_abs" 到线行为 value '2\.7 ')
  a37_27_cover=$(a37_get "$a37_27_abs" 'Agent 工具显式覆盖' value '2\.7 ')
  a37_27_rec=$(a37_get "$a37_27_abs" 降级记录格式 value '2\.7 ')
  if [ -n "$a37_27_alias" ] && ! a37_in_vocab "$a37_27_alias" "$a37_alias_vocab"; then
    add_problem "  - ${a37_27_rel} §2.7 短上下文别名取值未落别名取值词表: ${a37_27_alias}"
  fi
  if [ -n "$a37_27_bound" ] && ! a37_in_vocab "$a37_27_bound" "$a37_bound_vocab"; then
    add_problem "  - ${a37_27_rel} §2.7 到线行为取值未落到线行为词表（压缩／硬拒绝／待实测）: ${a37_27_bound}"
  fi
  case $a37_27_cover in
    '') ;;
    *)
      a37_27_cover_ok=0
      for a37_27_kw in 可 否 待实测; do
        case $a37_27_cover in
          "$a37_27_kw") a37_27_cover_ok=1 ;;
          "$a37_27_kw"（*|"$a37_27_kw"'('*|"$a37_27_kw"：*|"$a37_27_kw":*) a37_27_cover_ok=1 ;;
        esac
        if [ "$a37_27_cover_ok" -eq 1 ]; then break; fi
      done
      if [ "$a37_27_cover_ok" -ne 1 ]; then
        add_problem "  - ${a37_27_rel} §2.7 Agent 工具显式覆盖须整词以 可／否／待实测 起首（其后为行尾或分隔符）: ${a37_27_cover}"
      fi
      ;;
  esac
  case $a37_27_rec in
    *short_context:*|'') ;;
    *) add_problem "  - ${a37_27_rel} §2.7 降级记录格式须含记录键 short_context: ${a37_27_rec}" ;;
  esac
  case $a37_27_rec in
    *boundary:*|'') ;;
    *) add_problem "  - ${a37_27_rel} §2.7 降级记录格式须含记录键 boundary: ${a37_27_rec}" ;;
  esac
  case $a37_27_alias in
    待实测*|'') ;;
    *实测*)
      case $a37_27_alias in
        *未实测*|*待实测*)
          add_problem "  - ${a37_27_rel} §2.7 短上下文别名取值离开待实测时不得含 未实测／待实测 字样: ${a37_27_alias}" ;;
      esac
      ;;
    *) add_problem "  - ${a37_27_rel} §2.7 短上下文别名取值离开待实测时须含实测证据字样: ${a37_27_alias}" ;;
  esac
  case $a37_27_bound in
    待实测*|'') ;;
    *实测*)
      case $a37_27_bound in
        *未实测*|*待实测*)
          add_problem "  - ${a37_27_rel} §2.7 到线行为离开待实测时不得含 未实测／待实测 字样: ${a37_27_bound}" ;;
      esac
      ;;
    *) add_problem "  - ${a37_27_rel} §2.7 到线行为写实测结论时须含实测证据字样: ${a37_27_bound}" ;;
  esac
}
