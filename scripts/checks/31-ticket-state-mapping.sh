#!/bin/sh
# Input: check_31 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_ticket_status,pm_workflow
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 31（ticket-state-mapping）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 31：状态写票前有合法映射（票 219 新增；208/209 交付面核对）。逐工作流核对
# `state_to_ticket_status` 映射：每个 state 须有映射行（缺映射＝写票前无合法映射）、
# 映射键须为已声明 state（孤键）、映射目标须 ∈ 票状态词表（清单 workflow-graph 节
# ticket-status；词表外目标即非法状态写入）；映射节缺失即 FAIL。

check_31() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n31_wf=0
n31_map=0
ts31_vocab=$(LC_ALL=C sort -u "$pm_tstatus")
n31_tvocab=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_tstatus")
w31_tmp=$(mktemp "${t_dir%/}/wfmap.XXXXXX")
while IFS="$(printf '\t')" read -r w31_rel _w31_pos; do
  [ -n "$w31_rel" ] || continue
  n31_wf=$((n31_wf + 1))
  if [ ! -f "$pkg_root/$w31_rel" ]; then
    continue  # 缺件由检查 30 指名，本项不重复报
  fi
  awk_rc=0
  LC_ALL=C awk -v rel="$w31_rel" '
    /^[A-Za-z_][A-Za-z0-9_]*:/ {
      key = $0; sub(/:.*/, "", key)
      in_sm = (key == "state_machine") ? 1 : 0
      in_map = 0
      next
    }
    in_sm && /^  states:[ \t]*$/ { in_states = 1; next }
    in_sm && /^  transitions:[ \t]*$/ { in_states = 0; next }
    in_sm && /^  state_to_ticket_status:[ \t]*$/ { in_states = 0; in_map = 1; next }
    in_states && /^    - name: / { v = $0; sub(/^    - name: /, "", v); print "STATE\t" v "\t" FNR; next }
    in_map && /^    [a-z][a-z0-9_]*: / {
      line = $0
      sub(/^    /, "", line)
      k = line; sub(/:.*/, "", k)
      v = line; sub(/^[^:]*:[ \t]*/, "", v)
      print "MAP\t" k "\t" v "\t" FNR
      next
    }
  ' "$pkg_root/$w31_rel" > "$w31_tmp" || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 31 扫描器异常（awk exit %s）: %s\n' "$awk_rc" "$w31_rel" >&2
    rm -f "$w31_tmp"
    exit 2
  fi
  w31_states=$(LC_ALL=C awk -F'\t' '$1 == "STATE" { print $2 }' "$w31_tmp")
  w31_mapn=$(LC_ALL=C awk -F'\t' '$1 == "MAP" { n++ } END { print n + 0 }' "$w31_tmp")
  if [ "$w31_mapn" -eq 0 ]; then
    add_problem "  - $w31_rel 冲突类型=状态写票前无合法映射（规则 workflow-state-map · 缺 state_to_ticket_status 节）"
    continue
  fi
  n31_map=$((n31_map + w31_mapn))
  while IFS= read -r w31_s; do
    [ -n "$w31_s" ] || continue
    if ! LC_ALL=C awk -F'\t' -v s="$w31_s" '$1 == "MAP" && $2 == s { f = 1 } END { exit f ? 0 : 1 }' "$w31_tmp"; then
      add_problem "  - $w31_rel 冲突类型=状态无票映射（规则 workflow-state-map · state「${w31_s}」）"
    fi
  done <<EOF
$w31_states
EOF
  while IFS="$(printf '\t')" read -r w31_kind w31_k w31_v w31_ln; do
    [ "$w31_kind" = MAP ] || continue
    if [ -n "$w31_states" ] && ! printf '%s\n' "$w31_states" | grep -qxF -- "$w31_k"; then
      add_problem "  - $w31_rel:$w31_ln 冲突类型=映射键非已声明 state（规则 workflow-state-map · state「${w31_k}」）"
    fi
    if ! printf '%s\n' "$ts31_vocab" | grep -qxF -- "$w31_v"; then
      add_problem "  - $w31_rel:$w31_ln 冲突类型=映射目标越票状态词表（规则 workflow-state-map · 目标「${w31_v}」）"
    fi
  done < "$w31_tmp"
done < "$pm_workflows"
rm -f "$w31_tmp"
if [ -n "$problems" ]; then
  _chk_desc="状态写票前有合法映射（工作流 ${n31_wf} 件，映射 ${n31_map} 条，票状态词表 ${n31_tvocab} 值）"
else
  _chk_desc="状态写票前有合法映射（工作流 ${n31_wf} 件，映射 ${n31_map} 条，票状态词表 ${n31_tvocab} 值）"
fi
:
}
