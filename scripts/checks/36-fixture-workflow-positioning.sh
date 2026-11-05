#!/bin/sh
# Input: check_36 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_production_claim,pm_production_entry,pm_workflow_fixture_marker,pm_workflow
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 36（fixture-workflow-positioning）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 36：fixture workflow 不标 production executable（票 219 新增；211 交付面核对）。
# 工作流面（references/workflows/*.yaml）须全部在清单 workflow-graph 节登记定位（未登记
# ＝定位未决）；fixture 类须在 description 声明 fixture 标记词、入口名带 -fixture 后缀、
# 不占生产入口名、不含生产可执行声称词（不得把参考夹具标成生产可执行）；production 类
# 须入口名在 pm_production_entry 登记、不得带 fixture 标记与后缀。

check_36() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n36_wf=0
n36_fix=0
n36_prod=0
n36_face=$(cd "$pkg_root" && find references/workflows -type f -name '*.yaml' 2>/dev/null | LC_ALL=C sort)
n36_mark=$(cat "$pm_wffixmark")
OLDIFS=$IFS
IFS='
'
for f36 in $n36_face; do
  IFS=$OLDIFS
  [ -n "$f36" ] || continue
  n36_wf=$((n36_wf + 1))
  if ! LC_ALL=C awk -F'\t' -v p="$f36" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_workflows"; then
    add_problem "  - $f36 冲突类型=工作流未登记定位（规则 workflow-positioning · 缺 workflow-graph 行）"
  fi
done
IFS=$OLDIFS
while IFS="$(printf '\t')" read -r f36_rel f36_pos; do
  [ -n "$f36_rel" ] || continue
  if [ ! -f "$pkg_root/$f36_rel" ]; then
    add_problem "  - $f36_rel 冲突类型=工作流文件缺失（规则 workflow-positioning · 登记面）"
    continue
  fi
  f36_name=$(LC_ALL=C awk '
    /^workflow:/ { wf = 1; next }
    wf && /^  name: / { v = $0; sub(/^  name: /, "", v); print v; exit }
    wf && /^[A-Za-z_]/ { wf = 0 }
  ' "$pkg_root/$f36_rel")
  f36_desc=$(LC_ALL=C awk '
    /^workflow:/ { wf = 1; next }
    wf && /^  description: / { v = $0; sub(/^  description: /, "", v); print v; exit }
    wf && /^[A-Za-z_]/ { wf = 0 }
  ' "$pkg_root/$f36_rel")
  case $f36_pos in
    fixture)
      n36_fix=$((n36_fix + 1))
      case $f36_name in
        *-fixture) : ;;
        *) add_problem "  - $f36_rel 冲突类型=fixture 入口名缺 -fixture 后缀（规则 workflow-positioning · name「${f36_name}」）" ;;
      esac
      case $f36_desc in
        *"$n36_mark"*) : ;;
        *) add_problem "  - $f36_rel 冲突类型=fixture 未标非生产定位（规则 workflow-positioning · description 缺「${n36_mark}」）" ;;
      esac
      if printf '%s\n' "$(cat "$pm_prodentries")" | grep -qxF -- "$f36_name"; then
        add_problem "  - $f36_rel 冲突类型=fixture 占用生产入口名（规则 workflow-positioning · name「${f36_name}」）"
      fi
      while IFS= read -r f36_claim; do
        [ -n "$f36_claim" ] || continue
        if grep -qF -- "$f36_claim" "$pkg_root/$f36_rel"; then
          add_problem "  - $f36_rel 冲突类型=fixture 标 production executable（规则 workflow-positioning · 声称词「${f36_claim}」）"
        fi
      done < "$pm_prodclaims"
      ;;
    production)
      n36_prod=$((n36_prod + 1))
      if ! printf '%s\n' "$(cat "$pm_prodentries")" | grep -qxF -- "$f36_name"; then
        add_problem "  - $f36_rel 冲突类型=production 入口名未登记（规则 workflow-positioning · name「${f36_name}」）"
      fi
      case $f36_name in
        *-fixture) add_problem "  - $f36_rel 冲突类型=production 入口名带 fixture 后缀（规则 workflow-positioning · name「${f36_name}」）" ;;
      esac
      case $f36_desc in
        *"$n36_mark"*) add_problem "  - $f36_rel 冲突类型=production 工作流带 fixture 标记（规则 workflow-positioning · description 含「${n36_mark}」）" ;;
      esac
      ;;
  esac
done < "$pm_workflows"
if [ -n "$problems" ]; then
  _chk_desc="fixture workflow 不标 production executable（工作流 ${n36_wf} 件，fixture ${n36_fix} 件，production ${n36_prod} 件）"
else
  _chk_desc="fixture workflow 不标 production executable（工作流 ${n36_wf} 件，fixture ${n36_fix} 件，production ${n36_prod} 件）"
fi
:
}
