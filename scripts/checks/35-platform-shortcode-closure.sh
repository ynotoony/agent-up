#!/bin/sh
# Input: check_35 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_adapter,pm_shortcode
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 35（platform-shortcode-closure）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 35：平台短码注册表闭合（票 219 新增；215 交付面核对）。检查 26 覆盖注册表→各投影
# 方向，本项补两处闭合缺口：①shortcodes 节中 owner 为注册表适配器文件的短码行须在
# adapter-registry 节登记（适配器文件归属短码以注册表单源，不得另立登记行）；②平台短码
# （注册表短码）与规则块短码（shortcodes 节非适配器 owner 行）命名空间不得相交（同码
# 两义使 R-XX-NNN 与平台绑定歧义）。

check_35() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n35_reg=$(wc -l < "$pm_adapters" | tr -d ' ')
n35_codes=$(wc -l < "$pm_codes" | tr -d ' ')
n35_plat=$(LC_ALL=C awk -F'\t' '{print $2}' "$pm_adapters" | LC_ALL=C sort -u)
n35_plat_n=$(printf '%s\n' "$n35_plat" | LC_ALL=C awk 'NF { n++ } END { print n + 0 }')
while IFS="$(printf '\t')" read -r c35_sc c35_owner; do
  [ -n "$c35_sc" ] || continue
  if LC_ALL=C awk -F'\t' -v p="$c35_owner" '$3 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_adapters"; then
    if ! LC_ALL=C awk -F'\t' -v s="$c35_sc" -v p="$c35_owner" '$2 == s && $3 == p { f = 1 } END { exit f ? 0 : 1 }' "$pm_adapters"; then
      add_problem "  - shortcodes 节 ${c35_sc} ${c35_owner} 冲突类型=适配器归属短码未入注册表（规则 shortcode-closure · 注册表单源）"
    fi
  fi
done < "$pm_codes"
c35_rulecodes=$(LC_ALL=C awk -F'\t' 'NR == FNR { a[$3] = 1; next } !($2 in a) { print $1 }' "$pm_adapters" "$pm_codes" | LC_ALL=C sort -u)
for c35_p in $n35_plat; do
  if printf '%s\n' "$c35_rulecodes" | grep -qxF -- "$c35_p"; then
    add_problem "  - 短码 ${c35_p} 冲突类型=平台短码与规则块短码命名空间相交（规则 shortcode-closure · 同码两义）"
  fi
done
if [ -n "$problems" ]; then
  _chk_desc="平台短码注册表闭合（注册 ${n35_reg} 行，短码节 ${n35_codes} 行，平台短码 ${n35_plat_n} 个）"
else
  _chk_desc="平台短码注册表闭合（注册 ${n35_reg} 行，短码节 ${n35_codes} 行，平台短码 ${n35_plat_n} 个）"
fi
:
}
