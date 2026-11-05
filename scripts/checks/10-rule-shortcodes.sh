#!/bin/sh
# Input: check_10 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_shortcode
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 10（rule-shortcodes）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 10：规则块短码使用 ⊆ 登记（票 57 新增）。扫描范围＝包内全部 *.md 与 *.tmpl
# （同检查 6 文件面）；登记权威＝清单 shortcodes 节；SPEC 规格号（R-02-001 形态）与
# R-<短码>-<三位序号> 占位散文不落入提取模式，零自命中。

check_10() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
codes_col=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_codes")
used_all=''
OLDIFS=$IFS
IFS='
'
for f in $file_list; do
  IFS=$OLDIFS
  hits=$(grep -hoE 'R-[A-Z][A-Z]-[0-9][0-9][0-9]' "$f" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    used_all="$used_all$hits
"
  fi
done
IFS=$OLDIFS
used_prefixes=$(printf '%s' "$used_all" | sed -n 's/^R-\([A-Z][A-Z]\)-[0-9][0-9][0-9]$/\1/p' | sort -u)
unreg_codes=''
sep2=''
for c in $used_prefixes; do
  if ! printf '%s\n' "$codes_col" | grep -qxF "$c"; then
    unreg_codes="$unreg_codes$sep2$c"
    sep2='、'
  fi
done
if [ -n "$unreg_codes" ]; then
  add_problem "  - 未登记短码：$unreg_codes"
fi
if [ -n "$problems" ]; then
  _chk_desc='规则块短码使用均在登记内'
else
  _chk_desc='规则块短码使用均在登记内'
fi
:
}
