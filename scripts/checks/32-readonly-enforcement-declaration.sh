#!/bin/sh
# Input: check_32 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_enforcement_target,pm_enforcement_level,pm_readonly_site
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 32（readonly-enforcement-declaration）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 32：readonly-execute 声明有 enforcement level（票 219 新增；210/212 交付面核对）。
# 闭包双向：references/ 树凡声明 readonly-execute 的文件须在清单 readonly-sites 节登记
# （未登记即 FAIL）；登记面须真实存在且确实声明该能力（登记悬空 FAIL）；mode=level 的
# 声明面须给出具体等级值（readonly_enforcement: <token>，值 ∈ enforcement 词表）且须为
# enforcement 目标（pm_enforcement_target 双向闭合）；mode=reference 须含
# readonly_enforcement 指针（引用等级模型）；mode=authority＝模型定义处豁免等级值核对。

check_32() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n32_decl=0
n32_level=0
n32_vocab=$(LC_ALL=C sort -u "$pm_enfvocab")
n32_vocab_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_enfvocab")
r32_list=$(mktemp "${t_dir%/}/roexec.XXXXXX")
find "$pkg_root/references" -type f \( -name '*.md' -o -name '*.tmpl' \) | LC_ALL=C sort > "$r32_list" || true
while IFS= read -r r32_abs; do
  [ -n "$r32_abs" ] || continue
  grep -qF -- 'readonly-execute' "$r32_abs" || continue
  r32_rel=${r32_abs#"$pkg_root/"}
  n32_decl=$((n32_decl + 1))
  if ! LC_ALL=C awk -F'\t' -v p="$r32_rel" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_rosites"; then
    add_problem "  - $r32_rel 冲突类型=readonly-execute 声明未登记声明面（规则 readonly-site · 缺 readonly-sites 行）"
  fi
done < "$r32_list"
rm -f "$r32_list"
while IFS="$(printf '\t')" read -r r32_rel r32_mode; do
  [ -n "$r32_rel" ] || continue
  if [ ! -f "$pkg_root/$r32_rel" ]; then
    add_problem "  - $r32_rel 冲突类型=声明面文件缺失（规则 readonly-site · mode=${r32_mode}）"
    continue
  fi
  if ! grep -qF -- 'readonly-execute' "$pkg_root/$r32_rel"; then
    add_problem "  - $r32_rel 冲突类型=声明面未声明 readonly-execute（规则 readonly-site · 登记悬空 mode=${r32_mode}）"
    continue
  fi
  case $r32_mode in
    level)
      n32_level=$((n32_level + 1))
      r32_levels=$(LC_ALL=C awk '
        {
          line = $0
          while ((i = index(line, "readonly_enforcement:")) > 0) {
            rest = substr(line, i + length("readonly_enforcement:"))
            sub(/^[ \t`]+/, "", rest)
            if (match(rest, /^[a-z][a-z-]*/)) print substr(rest, RSTART, RLENGTH)
            line = rest
          }
        }
      ' "$pkg_root/$r32_rel")
      if [ -z "$r32_levels" ]; then
        add_problem "  - $r32_rel 冲突类型=readonly 声明缺 enforcement level（规则 readonly-site · mode=level 未声明 readonly_enforcement 值）"
      else
        for r32_lv in $r32_levels; do
          if ! printf '%s\n' "$n32_vocab" | grep -qxF -- "$r32_lv"; then
            add_problem "  - $r32_rel 冲突类型=enforcement level 越受控词表（规则 readonly-site · 值「${r32_lv}」）"
          fi
        done
      fi
      if ! LC_ALL=C awk -F'\t' -v p="$r32_rel" '$1 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_enf"; then
        add_problem "  - $r32_rel 冲突类型=level 声明面未登记 enforcement 目标（规则 readonly-site · 双向闭合缺 pm_enforcement_target 行）"
      fi
      ;;
    reference)
      if ! grep -qF -- 'readonly_enforcement' "$pkg_root/$r32_rel"; then
        add_problem "  - $r32_rel 冲突类型=readonly 声明缺 enforcement level 指针（规则 readonly-site · mode=reference 未引等级模型）"
      fi
      ;;
    authority)
      : # 等级模型定义处：值核对归 mode=level 声明面
      ;;
  esac
done < "$pm_rosites"
while IFS="$(printf '\t')" read -r r32_tgt _r32_exp; do
  [ -n "$r32_tgt" ] || continue
  if ! LC_ALL=C awk -F'\t' -v p="$r32_tgt" -v m="level" '$1 == p && $2 == m { f = 1 } END { exit f ? 0 : 1 }' "$pm_rosites"; then
    add_problem "  - $r32_tgt 冲突类型=enforcement 目标未登记 level 声明面（规则 readonly-site · 双向闭合缺 readonly-sites 行）"
  fi
done < "$pm_enf"
if [ -n "$problems" ]; then
  _chk_desc="readonly-execute 声明有 enforcement level（声明面 ${n32_decl} 个，level ${n32_level} 个，词表 ${n32_vocab_n} 值）"
else
  _chk_desc="readonly-execute 声明有 enforcement level（声明面 ${n32_decl} 个，level ${n32_level} 个，词表 ${n32_vocab_n} 值）"
fi
:
}
