#!/bin/sh
# Input: check_26 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_adapter,pm_capability_target,pm_shortcode,pm_platform
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 26（adapter-registry-closure）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 26：适配器注册表闭合（票 215 新增）。单一数据源＝清单 adapter-registry 节
# （pm_adapter 六字段：platform/shortcode/adapter_file/capability_coverage/
# role_mapping/evidence_status；字段格式、跨行唯一与 platform ∈ 枚举宿主值在加载段
# 结构校验 fail-closed，短码全局唯一由该节单源验证）。五向闭合：
#   ①注册表 ↔ platform-enum 节双向全等——注册表侧 ∈ 宿主值（去 neutral）在加载段
#     fail-closed 核验，本处补枚举宿主值缺注册行方向；
#   ②注册表 ↔ 适配器文件在位——adapter_file 存在（命名同名基线已在加载段校验）；
#   ③注册表 ↔ shortcodes 节——（短码, 所属文件）对须在册且全等；注册短码在
#     shortcodes 节挂其他所属文件即 FAIL（跨面唯一性锚定注册表）；
#   ④注册表 ↔ capability targets 节——（adapter_file, coverage）与 kind=table 行
#     双向一一全等（注册表与 pm_capability_target 互为镜像）；
#   ⑤注册表 ↔ 两 README 投影——references/README.md「adapters/」行反引号小写
#     token 集合与注册平台集全等（父 README 不漏列平台）；adapters/README.md
#     目录清单表 `<宿主文件>` 行含 `<短码>` 反引号 token，且表内小写单段 .md 行
#     （宿主映射文件形态）须全部在册（投影不另立登记事实）。
# R-CC-005 登记链口径：platform 枚举登记处（artifacts-yaml.tmpl 注释区与
# capability-contract.md 已知集合句）由检查 11 对 platform-enum 节闭合、本检查①
# 对注册表闭合，两级串联全覆盖；capability-contract.md 枚举段语义不在本检查改写面。

check_26() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n26_rows=$(wc -l < "$pm_adapters" | tr -d ' ')
# ①枚举宿主值集（去 neutral）缺注册行方向（注册表侧 ∈ 宿主值已在加载段核验）
reg_platforms=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_adapters" | LC_ALL=C sort)
host_platforms=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_platforms" | grep -vx 'neutral' | LC_ALL=C sort)
for v in $host_platforms; do
  if ! printf '%s\n' "$reg_platforms" | grep -qx "$v"; then
    add_problem "  - platform-enum 宿主值缺注册行: $v"
  fi
done
# ②适配器文件在位
while IFS="$(printf '\t')" read -r a26_plat a26_sc a26_file a26_cov a26_role a26_ev; do
  [ -n "$a26_plat" ] || continue
  if [ ! -f "$pkg_root/$a26_file" ]; then
    add_problem "  - 注册表适配器文件不存在: $a26_file"
  fi
done < "$pm_adapters"
# ③shortcodes 节（短码, 文件）对全等 + 注册短码不挂其他所属文件
while IFS="$(printf '\t')" read -r a26_plat a26_sc a26_file a26_cov a26_role a26_ev; do
  [ -n "$a26_plat" ] || continue
  if ! grep -qF "$(printf '%s\t%s' "$a26_sc" "$a26_file")" "$pm_codes"; then
    add_problem "  - 注册表（短码, 所属文件）对不在 shortcodes 节: $a26_sc $a26_file"
  fi
  a26_other=$(grep -F "$(printf '%s\t' "$a26_sc")" "$pm_codes" | grep -vF "$(printf '%s\t%s' "$a26_sc" "$a26_file")" || true)
  if [ -n "$a26_other" ]; then
    add_problem "  - 注册短码在 shortcodes 节挂其他所属文件（短码全局唯一锚定注册表）: $a26_other"
  fi
done < "$pm_adapters"
# ④capability targets kind=table 行 ↔ 注册表互为镜像（IFS 收敛为换行保 TAB 字段对）
a26_tab=$(LC_ALL=C awk -F'\t' '$2 == "table" {print $1 "\t" $3}' "$pm_captargets" | LC_ALL=C sort)
a26_regtab=$(LC_ALL=C awk -F'\t' '{print $3 "\t" $4}' "$pm_adapters" | LC_ALL=C sort)
OLDIFS=$IFS
IFS='
'
for v in $a26_regtab; do
  if ! printf '%s\n' "$a26_tab" | grep -qxF "$v"; then
    add_problem "  - 注册表（适配文件, coverage）对不在 capability targets 节 kind=table 行: $(printf '%s' "$v" | tr '\t' ' ')"
  fi
done
for v in $a26_tab; do
  if ! printf '%s\n' "$a26_regtab" | grep -qxF "$v"; then
    add_problem "  - capability targets 节 kind=table 行未入注册表（互为镜像）: $(printf '%s' "$v" | tr '\t' ' ')"
  fi
done
IFS=$OLDIFS
# ⑤references/README.md「adapters/」行投影（父 README 平台全集，不漏列）
# 锚点用 BRE 字面竖线（BSD grep 的 \| 为交替元字符，先例：检查 21② sed 提取同款字面）。
ref_readme26="$pkg_root/references/README.md"
ad_readme26="$pkg_root/references/adapters/README.md"
if [ ! -f "$ref_readme26" ]; then
  add_problem '  - references/README.md 不存在（父 README 投影无承载）'
else
  # shellcheck disable=SC2016  # 单引号内反引号为字面 Markdown 表锚（行首 | `adapters/` | 目录行锚点），非命令替换
  ref26_row=$(grep -n '^| `adapters/`' "$ref_readme26" | head -1)
  if [ -z "$ref26_row" ]; then
    # shellcheck disable=SC2016  # 提示文案内反引号为字面 Markdown 锚原样指名（锚点漂移时供人工比对），非命令替换
    add_problem '  - references/README.md 未找到 adapters 目录行（锚点行首 | `adapters/` |，父 README 投影漂移）'
  else
    # shellcheck disable=SC2016  # grep -oE 与 tr 的反引号为字面 Markdown 锚定界符（平台 token 提取形态本体），非命令替换
    ref26_vals=$(printf '%s\n' "$ref26_row" | cut -d: -f2- | LC_ALL=C grep -oE '`[a-z][a-z0-9-]*`' | tr -d '`' | LC_ALL=C sort -u)
    ref26_diff=''
    for v in $reg_platforms; do
      if ! printf '%s\n' "$ref26_vals" | grep -qx "$v"; then
        # 花括号不可省略：$v 后紧跟全角分号时，sh 会把多字节字符并入变量名（先例检查 5/12/14）
        ref26_diff="${ref26_diff}缺少 ${v}；"
      fi
    done
    for v in $ref26_vals; do
      if ! printf '%s\n' "$reg_platforms" | grep -qx "$v"; then
        ref26_diff="${ref26_diff}多出 ${v}；"
      fi
    done
    if [ -n "$ref26_diff" ]; then
      # 尾部分号剥离（逐项以「；」衔接，末项不带尾分号）
      add_problem "  - references/README.md adapters 行投影与注册表不一致（父 README 不得漏列平台）: $(printf '%s' "$ref26_diff" | sed 's/；$//')"
    fi
  fi
fi
# ⑤adapters/README.md 目录清单投影：注册行含短码 token；表内（短码, 文件）投影对须
# 在册（宿主对＝adapter-registry 节，非宿主对＝shortcodes 节——投影不另立登记事实）。
if [ ! -f "$ad_readme26" ]; then
  add_problem '  - references/adapters/README.md 不存在（目录 README 投影无承载）'
else
  ad26_tab=$(sed -n '/^## 目录清单/,/^## /p' "$ad_readme26")
  if [ -z "$ad26_tab" ]; then
    add_problem '  - references/adapters/README.md 目录清单表未提取到内容（表结构漂移）'
  else
    # shellcheck disable=SC2034  # 六变量整体解构对齐 pm_adapter 行六字段布局（read 尾字段不可省否则吞并剩余列）；coverage/role/evidence 本循环不消费
    while IFS="$(printf '\t')" read -r a26_plat a26_sc a26_file a26_cov a26_role a26_ev; do
      [ -n "$a26_plat" ] || continue
      a26_base=${a26_file##*/}
      # 花括号不可省略：变量名后紧跟全角字符时防止吞并（先例检查 5/12/14）
      if ! printf '%s\n' "$ad26_tab" | grep -E "^\\| \`${a26_base}\`" | grep -qF "\`${a26_sc}\`"; then
        add_problem "  - adapters/README.md 目录清单投影缺行或缺短码: ${a26_base}（${a26_sc}）"
      fi
    done < "$pm_adapters"
    # 反向闭合：表行携带的两字母短码列与首列 .md 名组成投影对，逐对核对在册
    # （名字列取行内首个 <名>.md token＝表首列；短码列取首个两字母大写 token；
    # 「无」短码行与占位 `<host>.md` 形态不落入提取）。
    ad26_pairs=$(printf '%s\n' "$ad26_tab" | LC_ALL=C awk '
      {
        n = split($0, f, "|")
        name = ""; sc = ""
        for (i = 2; i <= n; i++) {
          t = f[i]
          gsub(/`/, "", t)
          gsub(/^[ \t]+/, "", t); gsub(/[ \t]+$/, "", t)
          if (name == "" && t ~ /^[A-Za-z][A-Za-z0-9._-]*\.md$/) name = t
          else if (sc == "" && t ~ /^[A-Z][A-Z]$/) sc = t
        }
        if (name != "" && sc != "") print sc "\t" name
      }' | LC_ALL=C sort -u)
    OLDIFS=$IFS
    IFS='
'
    for pr in $ad26_pairs; do
      a26_sc=${pr%%"$TAB"*}
      a26_base=${pr#*"$TAB"}
      a26_path="references/adapters/$a26_base"
      if ! LC_ALL=C awk -F'\t' -v sc="$a26_sc" -v p="$a26_path" '{ if ($2 == sc && $3 == p) found = 1 } END { exit found ? 0 : 1 }' "$pm_adapters" \
        && ! LC_ALL=C awk -F'\t' -v sc="$a26_sc" -v p="$a26_path" '{ if ($1 == sc && $2 == p) found = 1 } END { exit found ? 0 : 1 }' "$pm_codes"; then
        add_problem "  - adapters/README.md 投影短码对未登记（宿主对入 adapter-registry 节、其余入 shortcodes 节）: $a26_sc $a26_base"
      fi
    done
    IFS=$OLDIFS
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc="适配器注册表闭合（注册 ${n26_rows} 行，投影 2 面）"
else
  _chk_desc="适配器注册表闭合（注册 ${n26_rows} 行，投影 2 面）"
fi
:
}
