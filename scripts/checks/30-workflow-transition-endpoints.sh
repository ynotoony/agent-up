#!/bin/sh
# Input: check_30 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_workflow
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 30（workflow-transition-endpoints）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 30：workflow transition endpoint 存在（票 219 新增；208 交付面核对）。逐工作流
# （清单 workflow-graph 节登记面）解析 state_machine：states 名集、initial_state、
# transitions 的 from/to 与 trigger；断言 initial_state ∈ states、每个 from/to ∈ states、
# trigger ∈ steps 的 id（端点缺失即 FAIL 指名文件:行号、端点种类与冲突类型）、state 名
# 不跨行重复；states 或 transitions 零行即 FAIL（空图不构成状态模型）。

check_30() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n30_wf=0
n30_states=0
n30_trans=0
w30_tmp=$(mktemp "${t_dir%/}/wfgraph.XXXXXX")
while IFS="$(printf '\t')" read -r w30_rel _w30_pos; do
  [ -n "$w30_rel" ] || continue
  n30_wf=$((n30_wf + 1))
  if [ ! -f "$pkg_root/$w30_rel" ]; then
    add_problem "  - $w30_rel 冲突类型=工作流文件缺失（规则 workflow-graph · 登记面）"
    continue
  fi
  awk_rc=0
  LC_ALL=C awk -v rel="$w30_rel" '
    /^[A-Za-z_][A-Za-z0-9_]*:/ {
      key = $0; sub(/:.*/, "", key)
      in_steps = (key == "steps") ? 1 : 0
      in_sm = (key == "state_machine") ? 1 : 0
      in_states = 0; in_trans = 0
      next
    }
    in_steps && /^  - id: / { v = $0; sub(/^  - id: /, "", v); print "STEP\t" v "\t" FNR; next }
    in_sm && /^  initial_state: / { v = $0; sub(/^  initial_state: /, "", v); print "INIT\t" v "\t" FNR; next }
    in_sm && /^  states:[ \t]*$/ { in_states = 1; in_trans = 0; next }
    in_sm && /^  transitions:[ \t]*$/ { in_states = 0; in_trans = 1; next }
    in_states && /^    - name: / { v = $0; sub(/^    - name: /, "", v); print "STATE\t" v "\t" FNR; next }
    in_trans && /^    - from: / { v = $0; sub(/^    - from: /, "", v); print "FROM\t" v "\t" FNR; next }
    in_trans && /^      to: / { v = $0; sub(/^      to: /, "", v); print "TO\t" v "\t" FNR; next }
    in_trans && /^      trigger: / { v = $0; sub(/^      trigger: /, "", v); print "TRIGGER\t" v "\t" FNR; next }
  ' "$pkg_root/$w30_rel" > "$w30_tmp" || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 30 扫描器异常（awk exit %s）: %s\n' "$awk_rc" "$w30_rel" >&2
    rm -f "$w30_tmp"
    exit 2
  fi
  w30_states=$(LC_ALL=C awk -F'\t' '$1 == "STATE" { print $2 }' "$w30_tmp")
  w30_steps=$(LC_ALL=C awk -F'\t' '$1 == "STEP" { print $2 }' "$w30_tmp")
  if [ -z "$w30_states" ]; then
    add_problem "  - $w30_rel 冲突类型=状态图零 state（规则 workflow-graph · states 缺失）"
    continue
  fi
  n30_states=$((n30_states + $(printf '%s\n' "$w30_states" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }')))
  n30_trans=$((n30_trans + $(LC_ALL=C awk -F'\t' '$1 == "FROM" { n++ } END { print n + 0 }' "$w30_tmp")))
  while IFS="$(printf '\t')" read -r w30_kind w30_val w30_ln; do
    [ -n "$w30_kind" ] || continue
    case $w30_kind in
      INIT|FROM|TO)
        if ! printf '%s\n' "$w30_states" | grep -qxF -- "$w30_val"; then
          add_problem "  - $w30_rel:$w30_ln 冲突类型=transition endpoint 未声明为 state（规则 workflow-graph · ${w30_kind}「${w30_val}」）"
        fi
        ;;
      TRIGGER)
        if ! printf '%s\n' "$w30_steps" | grep -qxF -- "$w30_val"; then
          add_problem "  - $w30_rel:$w30_ln 冲突类型=transition trigger 未声明为 step（规则 workflow-graph · trigger「${w30_val}」）"
        fi
        ;;
    esac
  done < "$w30_tmp"
  w30_dup=$(LC_ALL=C awk -F'\t' '$1 == "STATE" { if (c[$2]++) print $2 }' "$w30_tmp" | LC_ALL=C sort -u)
  for w30_d in $w30_dup; do
    add_problem "  - $w30_rel 冲突类型=state 名跨行重复（规则 workflow-graph · state「${w30_d}」）"
  done
  if [ "$(LC_ALL=C awk -F'\t' '$1 == "INIT" { n++ } END { print n + 0 }' "$w30_tmp")" -eq 0 ]; then
    add_problem "  - $w30_rel 冲突类型=缺 initial_state（规则 workflow-graph · 起点未声明）"
  fi
  if [ "$(LC_ALL=C awk -F'\t' '$1 == "FROM" { n++ } END { print n + 0 }' "$w30_tmp")" -eq 0 ]; then
    add_problem "  - $w30_rel 冲突类型=零 transition（规则 workflow-graph · 状态图不可达）"
  fi
done < "$pm_workflows"
rm -f "$w30_tmp"
if [ -n "$problems" ]; then
  _chk_desc="workflow transition endpoint 存在（工作流 ${n30_wf} 件，状态 ${n30_states} 个，转换 ${n30_trans} 条）"
else
  _chk_desc="workflow transition endpoint 存在（工作流 ${n30_wf} 件，状态 ${n30_states} 个，转换 ${n30_trans} 条）"
fi
:
}
