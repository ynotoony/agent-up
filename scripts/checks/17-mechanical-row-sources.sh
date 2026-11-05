#!/bin/sh
# Input: check_17 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_script
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 17（mechanical-row-sources）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 17：机械行点名出处存在。机械行（机制列首段＝受控值「机械」——该值
# 为引擎语义锚点，词表成员资格仍以清单为权威）须在括注内点名出处：脚本名（*.sh）必须
# 真实存在于包 $scripts_dir 且在清单 scripts 节登记；检查项号（「检查 N」）必须落在
# 1..37（引擎自述上限，新增检查须同步）。仅机械行核验（门禁/约定行括注不做
# 存在性核对）；零脚本零检查项的机械行判缺点名。对象＝生成索引机制列（检查 16 同源）。

check_17() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_mrow=0
mech_m='机械'
idx_mech=$(mktemp "${t_dir%/}/idxmech.XXXXXX")
n_row16=$(chk_index_mech_load "$idx_file" "$idx_mech")
if [ "$n_row16" -eq 0 ]; then
  add_problem '  - 索引表零行，机械行无从核对'
else
  awk_rc=0
  cand17=$(sed -e 's/（/(/g' -e 's/）/)/g' -e 's/；/;/g' -e 's/检查/CHK/g' "$idx_mech" | LC_ALL=C MECH_M="$mech_m" awk -F'\t' '
    function paren_span(s,   i, j) {
      i = index(s, "(")
      if (i == 0) return ""
      s = substr(s, i + 1)
      j = index(s, ")")
      if (j == 0) return ""
      return substr(s, 1, j - 1)
    }
    BEGIN { mk = ENVIRON["MECH_M"] }
    NF {
      id = $1; cell = $2
      i = index(cell, "(")
      head = cell
      if (i > 0) head = substr(cell, 1, i - 1)
      n = split(head, H, ";")
      seg = H[1]
      gsub(/[ \t]/, "", seg)
      if (seg != mk) next
      n_mrow++
      ev = paren_span(cell)
      print id "\tEV\t" ev
      rest = ev
      while (match(rest, /[A-Za-z0-9._-]+\.sh/) > 0) {
        print id "\tS\t" substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
      }
      rest = ev
      while (match(rest, /CHK [0-9][0-9]*/) > 0) {
        num = substr(rest, RSTART, RLENGTH)
        sub(/^CHK /, "", num)
        print id "\tC\t" num
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
    END { printf "COUNT\t%d\n", n_mrow + 0 }
  ') || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 17 扫描器异常（awk exit %s）\n' "$awk_rc" >&2
    exit 2
  fi
  n_mrow=$(printf '%s\n' "$cand17" | LC_ALL=C awk -F'\t' '$1 == "COUNT" { print $2; exit }')
  prev_id=''; prev_ev=''; prev_n=0
  OLDIFS=$IFS
  IFS='
'
  for row in $cand17; do
    IFS=$OLDIFS
    row_id=${row%%"$TAB"*}
    row_rest=${row#*"$TAB"}
    row_kind=${row_rest%%"$TAB"*}
    row_val=${row_rest#*"$TAB"}
    case $row_kind in
      COUNT) continue ;;
      EV)
        if [ -n "$prev_id" ] && [ "$prev_n" -eq 0 ]; then
          add_problem "  - ${prev_id} 机械行未点名脚本或检查项（原文：${prev_ev}）"
        fi
        prev_id=$row_id; prev_ev=$row_val; prev_n=0
        if [ -z "$row_val" ]; then
          add_problem "  - $row_id 机械行缺点名出处（须在括注内点名脚本或检查项）"
        fi
        ;;
      S)
        prev_n=$((prev_n + 1))
        if [ ! -f "$pkg_root/$scripts_dir/$row_val" ]; then
          add_problem "  - $row_id 机械行点名脚本不存在: $row_val"
        elif ! LC_ALL=C awk -F'\t' -v p="$scripts_dir/$row_val" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_scripts"; then
          add_problem "  - $row_id 机械行点名脚本未在清单 scripts 节登记: $row_val"
        fi
        ;;
      C)
        prev_n=$((prev_n + 1))
        case $row_val in
          ''|*[!0-9]*)
            add_problem "  - $row_id 机械行点名检查项号形态不合预期: $row_val"
            ;;
          *)
            if [ "$row_val" -lt 1 ] || [ "$row_val" -gt "$n_total_checks" ]; then
              add_problem "  - $row_id 机械行点名检查项号超界（当前共 ${n_total_checks} 项）: 检查 $row_val"
            fi
            ;;
        esac
        ;;
    esac
  done
  IFS=$OLDIFS
  if [ -n "$prev_id" ] && [ "$prev_n" -eq 0 ]; then
    add_problem "  - ${prev_id} 机械行未点名脚本或检查项（原文：${prev_ev}）"
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc="机械行点名出处存在（机械 ${n_mrow} 行）"
else
  _chk_desc="机械行点名出处存在（机械 ${n_mrow} 行）"
fi
rm -f "$idx_mech"
:
}
