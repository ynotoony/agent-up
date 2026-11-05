#!/bin/sh
# Input: check_27 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_adapter,pm_adapter_cap,pm_adapter_dialect,pm_adapter_exec,pm_adapter_role
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 27（adapter-diffs-consistency）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 27：适配差异数据表一致性（票 222 新增）。数据＝references/adapters/
# adapter-diffs.rules 四节机器数据行（pm_adapter_cap／pm_adapter_role／
# pm_adapter_exec／pm_adapter_dialect；包根相对落位、包侧唯一副本，加载段结构
# 校验 fail-closed）。断言「数据 ≡ 现行五宿主 Markdown 对应段」全等，两向漂移
# 即 FAIL 指名宿主与段（表文修正归人工裁决，不静默互改；宿主文档改写归后继
# 生成/去重票——其以本表为输入）。全等口径＝两侧同规约「剥离反引号（Markdown
# 强调记号非内容）后逐行逐字段全等」：
#   ①九行能力表——「| 能力基元 |」对照表数据行按（基元, 工具, 约束）三列比对，
#     行序＝宿主文档行序（行序敏感）；
#   ②三角色映射表——「| <role-contract-dir>/」行按（角色, 能力名单, 工具口径）
#     三列比对（角色名自路径尾段剥 <role-contract-dir>/ 与 .md），行序敏感；
#   ③独立执行体声明——exec 行锚语原文子串在场断言（宿主文件 grep -F）；
#   ④宿主特有方言——dialect 行签名锚语原文子串在场断言（同上）。

a27_extract_cap() {
  # $1=宿主文件：「| 能力基元 |」对照表数据行规约化——剥反引号后（基元, 工具,
  # 约束）三列 TAB 行；单元格数非 3 的行剥反引号原样输出（比对必失配＝漂移面）。
  LC_ALL=C awk -v mk='| 能力基元' '
    function trimbt(x) { gsub(/`/, "", x); gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    {
      if (!inh) { if (index($0, mk) == 1) inh = 1; next }
      if ($0 !~ /^\|/) exit
      c = $0
      sub(/^[[:space:]]*\|/, "", c)
      sub(/[[:space:]]*\|.*/, "", c)
      gsub(/^[[:space:]]+/, "", c); gsub(/[[:space:]]+$/, "", c)
      if (c ~ /^[-:]+$/) next
      n = split($0, f, "|")
      if (n - 2 != 3) { print trimbt($0); next }
      print trimbt(f[2]) "\t" trimbt(f[3]) "\t" trimbt(f[4])
    }
  ' "$1"
}
a27_extract_role() {
  # $1=宿主文件：「| <role-contract-dir>/」行规约化——（角色, 能力名单, 工具口径）
  # 三列 TAB 行；角色名＝首列路径尾段剥 <role-contract-dir>/ 前缀与 .md 后缀。列数非 3
  # 的行剥反引号原样输出（与能力表同款守卫：比对必失配＝漂移面，防多/少列静默截断）。
  LC_ALL=C awk '
    function trimbt(x) { gsub(/`/, "", x); gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    $0 ~ /^\| <role-contract-dir>\// {
      n = split($0, f, "|")
      if (n - 2 != 3) { print trimbt($0); next }
      r = trimbt(f[2])
      sub(/^<role-contract-dir>\//, "", r)
      sub(/\.md$/, "", r)
      print r "\t" trimbt(f[3]) "\t" trimbt(f[4])
    }
  ' "$1"
}
a27_first_diff() {
  # $1/$2=两规约化 TAB 行文件；stdout＝首个差异行号（两侧全等＝0；行数不齐＝
  # 短侧行数＋1）。
  LC_ALL=C awk '
    NR == FNR { d[FNR] = $0; nd = FNR; next }
    { if (!fd && $0 != d[FNR]) fd = FNR; nm = FNR }
    END { if (!fd && nd != nm) fd = (nd < nm ? nd : nm) + 1; print fd + 0 }
  ' "$1" "$2"
}

check_27() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n27_cap=$(wc -l < "$pm_adcap" | tr -d ' ')
n27_role=$(wc -l < "$pm_adrole" | tr -d ' ')
n27_exec=$(wc -l < "$pm_adexec" | tr -d ' ')
n27_dial=$(wc -l < "$pm_addial" | tr -d ' ')
a27_cap_d=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
a27_cap_m=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
a27_role_d=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
a27_role_m=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
n27_hosts=0
# shellcheck disable=SC2034  # 六变量整体解构对齐 pm_adapter 行六字段布局（read 尾字段不可省否则吞并剩余列）；sc/cov/role/ev 本循环不消费
while IFS="$(printf '\t')" read -r a27_plat a27_sc a27_file a27_cov a27_role a27_ev; do
  [ -n "$a27_plat" ] || continue
  n27_hosts=$((n27_hosts + 1))
  a27_host="$pkg_root/$a27_file"
  if [ ! -f "$a27_host" ]; then
    continue  # 适配器文件缺席已由检查 26② 指名，此处不重复计失败
  fi
  # ①九行能力表（行序敏感全等；两侧同规约剥反引号——数据侧强调记号原样承载，
  #   剥离后与宿主抽取同形，检查 27 的宽松口径不变）
  awk -F'\t' -v p="$a27_plat" '$1 == p { a = $2; b = $3; c = $4; gsub(/`/, "", a); gsub(/`/, "", b); gsub(/`/, "", c); print a "\t" b "\t" c }' "$pm_adcap" > "$a27_cap_d"
  a27_extract_cap "$a27_host" > "$a27_cap_m"
  if ! cmp -s "$a27_cap_d" "$a27_cap_m"; then
    a27_fd=$(a27_first_diff "$a27_cap_d" "$a27_cap_m")
    add_problem "  - $a27_file 九行能力表与差异数据表漂移（段＝capability-map；首个差异行 ${a27_fd}，0＝行数不齐）"
  fi
  # ②三角色映射表（行序敏感全等；同①两侧剥反引号口径）
  awk -F'\t' -v p="$a27_plat" '$1 == p { a = $2; b = $3; c = $4; gsub(/`/, "", a); gsub(/`/, "", b); gsub(/`/, "", c); print a "\t" b "\t" c }' "$pm_adrole" > "$a27_role_d"
  a27_extract_role "$a27_host" > "$a27_role_m"
  if ! cmp -s "$a27_role_d" "$a27_role_m"; then
    a27_fd=$(a27_first_diff "$a27_role_d" "$a27_role_m")
    add_problem "  - $a27_file 三角色映射表与差异数据表漂移（段＝role-map；首个差异行 ${a27_fd}，0＝行数不齐）"
  fi
done < "$pm_adapters"
# ③独立执行体声明锚语（原文子串在场）
while IFS="$(printf '\t')" read -r a27_plat a27_status a27_anchor; do
  [ -n "$a27_plat" ] || continue
  a27_file=$(LC_ALL=C awk -F'\t' -v p="$a27_plat" '$1 == p { print $3; exit }' "$pm_adapters")
  if [ -n "$a27_file" ] && [ -f "$pkg_root/$a27_file" ]; then
    if ! grep -qF -- "$a27_anchor" "$pkg_root/$a27_file"; then
      add_problem "  - $a27_file 独立执行体声明锚语失据（段＝executor-status，status=${a27_status}）: $a27_anchor"
    fi
  fi
done < "$pm_adexec"
# ④宿主特有方言签名锚语（原文子串在场）
while IFS="$(printf '\t')" read -r a27_plat a27_key a27_anchor; do
  [ -n "$a27_plat" ] || continue
  a27_file=$(LC_ALL=C awk -F'\t' -v p="$a27_plat" '$1 == p { print $3; exit }' "$pm_adapters")
  if [ -n "$a27_file" ] && [ -f "$pkg_root/$a27_file" ]; then
    if ! grep -qF -- "$a27_anchor" "$pkg_root/$a27_file"; then
      add_problem "  - $a27_file 方言签名锚语失据（段＝dialect-signature，key=${a27_key}）: $a27_anchor"
    fi
  fi
done < "$pm_addial"
rm -f "$a27_cap_d" "$a27_cap_m" "$a27_role_d" "$a27_role_m"
if [ -n "$problems" ]; then
  _chk_desc="适配差异数据表一致性（宿主 ${n27_hosts} 个，cap ${n27_cap} 行，role ${n27_role} 行，exec ${n27_exec} 行，dialect ${n27_dial} 行）"
else
  _chk_desc="适配差异数据表一致性（宿主 ${n27_hosts} 个，cap ${n27_cap} 行，role ${n27_role} 行，exec ${n27_exec} 行，dialect ${n27_dial} 行）"
fi
:
}
