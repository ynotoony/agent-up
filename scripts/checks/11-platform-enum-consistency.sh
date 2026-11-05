#!/bin/sh
# Input: check_11 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_platform
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 11（platform-enum-consistency）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 11：platform 枚举登记处 ↔ 数据一致（票 57 新增；逐处全等，协调层改判随票修）。
# 登记处（锚点＝登记标记文本，值集合以清单 platform-enum 节为权威）：artifacts-yaml.tmpl
# platform 字段注释区；capability-contract.md 内每个「已知集合」句（frontmatter 与 §2.5
# 各一处）逐处全等，任一处缺值/多值/改值即 FAIL 且按行号指名；adapters 各文件的宿主
# 自述不在本项口径内。

pm_enum_diff() {
  # $1=登记处取值（每行一个）；与数据 platform_data 比对，输出「缺少／多出」摘要或空串
  _miss=''
  _extra=''
  _s2=''
  for v in $platform_data; do
    if ! printf '%s\n' "$1" | grep -qx "$v"; then
      _miss="$_miss$_s2$v"
      _s2='、'
    fi
  done
  _s2=''
  for v in $1; do
    if ! printf '%s\n' "$platform_data" | grep -qx "$v"; then
      _extra="$_extra$_s2$v"
      _s2='、'
    fi
  done
  _r=''
  if [ -n "$_miss" ]; then
    _r="缺少 ${_miss}"
  fi
  if [ -n "$_extra" ]; then
    if [ -n "$_r" ]; then
      # 花括号不可省略：$_r 后紧跟全角字符时，sh 会把多字节字符并入变量名。
      _r="${_r}；多出 ${_extra}"
    else
      _r="多出 ${_extra}"
    fi
  fi
  printf '%s' "$_r"
}

check_11() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
platform_data=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_platforms" | sort)
tmpl_site="$pkg_root/references/templates/artifacts-yaml.tmpl"
cc_site="$pkg_root/references/adapters/capability-contract.md"
if [ ! -f "$tmpl_site" ]; then
  add_problem '  - references/templates/artifacts-yaml.tmpl 不存在'
else
  # 提取用 LC_ALL=C awk 字节级 index/substr（BSD sed 对多字节 RE 不可靠）；锚点＝
  # “当前已知集合：”，取值段至全角分号止。
  seg=$(LC_ALL=C awk -v mk='当前已知集合：' -v tail='；' '
    {
      i = index($0, mk)
      if (i > 0) {
        rest = substr($0, i + length(mk))
        j = index(rest, tail)
        if (j > 0) rest = substr(rest, 1, j - 1)
        print rest
        exit
      }
    }
  ' "$tmpl_site")
  if [ -z "$seg" ]; then
    add_problem '  - artifacts-yaml.tmpl 未找到 platform 枚举登记处（当前已知集合标记）'
  else
    site_vals=$(printf '%s\n' "$seg" | tr '/' '\n' | tr -d ' ' | LC_ALL=C sort)
    diff_detail=$(pm_enum_diff "$site_vals")
    if [ -n "$diff_detail" ]; then
      add_problem "  - artifacts-yaml.tmpl 登记与数据不一致：$diff_detail"
    fi
  fi
fi
if [ ! -f "$cc_site" ]; then
  add_problem '  - references/adapters/capability-contract.md 不存在'
else
  # 锚点＝「已知集合」句（本文件 frontmatter 与 §2.5 各有一处登记）；协调层 2026-09-21
  # 改判随票修：比对口径为逐处全等——每个登记处单独与数据比对，任一处缺值/多值/改值
  # 即 FAIL（并集口径存在单处删值盲区，废止）；FAIL 行按行号指名漂移处。每句取值段截于
  # 全角分号/左括注/句号最早者，strip 反引号后按斜杠分值。
  cc_raw=$(LC_ALL=C awk -v mk='已知集合' '
    function cutat(s, t,   j) { j = index(s, t); if (j == 0) j = length(s) + 1; return j }
    {
      i = index($0, mk)
      if (i > 0) {
        rest = substr($0, i + length(mk))
        j = cutat(rest, "；")
        k = cutat(rest, "（")
        l = cutat(rest, "。")
        e = j
        if (k < e) e = k
        if (l < e) e = l
        if (e <= length(rest)) rest = substr(rest, 1, e - 1)
        print FNR "\t" rest
      }
    }
  ' "$cc_site")
  if [ -z "$cc_raw" ]; then
    add_problem '  - capability-contract.md 未找到 platform 枚举登记处（已知集合标记）'
  else
    OLDIFS=$IFS
    IFS='
'
    for row in $cc_raw; do
      IFS=$OLDIFS
      cc_ln=${row%%"$TAB"*}
      seg=${row#*"$TAB"}
      site_vals=$(printf '%s\n' "$seg" | tr -d '`' | tr '/' '\n' | tr -d ' ' | LC_ALL=C sort -u)
      diff_detail=$(pm_enum_diff "$site_vals")
      if [ -n "$diff_detail" ]; then
        add_problem "  - capability-contract.md :${cc_ln} 登记与数据不一致：$diff_detail"
      fi
    done
    IFS=$OLDIFS
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc='platform 枚举登记与数据一致'
else
  _chk_desc='platform 枚举登记与数据一致'
fi
:
}
