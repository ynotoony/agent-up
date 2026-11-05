#!/bin/sh
# Input: check_14 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_capability_authority,pm_capability,pm_capability_target,pm_enforcement_target,pm_enforcement_level
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 14（capability-mapping）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 14：能力映射一致（票 59 新增）。名单＝清单 capability-primitives 节（九基元名，
# 引擎零基元名硬编码）；权威表＝capability_authority 登记文件（窄锚点「### …能力基元
# 清单」标题下九行表首列），与名单逐处全等比对；检查目标＝capability_target 节逐一
# 核验——kind=decl 取目标文件 required_capabilities（运行时）行的反引号名集合（与预期
# 名单双向全等，注入未登记名/删名/改名即 FAIL 指名文件），kind=table 取「| 能力基元 |」
# 对照表首列名集合（与预期名单双向全等，预期名单经载入校验 ⊆ 名单且并集 ⊇ 名单）。
# 表解析锚点失效即 exit 2 不静默过（检查 11 同款 fail-closed）；targets 均为包内文件，
# 相对 $pkg_root 解析（--pkg-root 复制落位语境与镜像检查同口径）。扩展维度：readonly-
# execute 只读约束等级核对——清单 enforcement 词表节（pm_enforcement_level，受控值集）
# 与 targets 节（pm_enforcement_target，适配文件+预期等级），逐适配器提取 readonly-
# execute 行 readonly_enforcement: 值与预期全等比对（缺声明/词表外/不一致 FAIL 指名；
# 行未命中 exit 2）。

cap_extract_decl() {
  # $1=文件：required_capabilities（运行时）行首的行，取该行至全角分号止的反引号段
  LC_ALL=C awk -v mk='required_capabilities（运行时）：' '
    index($0, mk) == 1 {
      rest = substr($0, length(mk) + 1)
      j = index(rest, "；")
      if (j > 0) rest = substr(rest, 1, j - 1)
      n = split(rest, parts, "`")
      for (k = 2; k <= n; k += 2) if (parts[k] != "") print parts[k]
      found = 1
      exit
    }
    END { if (!found) exit 3 }
  ' "$1"
}
cap_extract_table() {
  # $1=文件：「| 能力基元」首列表头行的表，取分隔行后各数据行首列
  LC_ALL=C awk -v mk='| 能力基元' '
    function firstcell(line,   s) {
      s = line
      sub(/^\|[[:space:]]*/, "", s)
      sub(/[[:space:]]*\|.*/, "", s)
      return s
    }
    index($0, mk) == 1 { inh = 1; next }
    inh && !sep && $0 ~ /^\|/ { c = firstcell($0); if (c ~ /^[-: ]+$/) sep = 1; next }
    inh && sep && $0 ~ /^\|/ { print firstcell($0) }
    inh && sep && $0 !~ /^\|/ { exit }
    END { if (!sep) exit 3 }
  ' "$1"
}
cap_extract_auth() {
  # $1=文件：「### …能力基元清单」标题下的表（权威表首列为「能力」），取分隔行后各
  # 数据行首列；锚点＝以 # 开头且含「能力基元清单」的标题行
  LC_ALL=C awk -v mk='能力基元清单' '
    function firstcell(line,   s) {
      s = line
      sub(/^\|[[:space:]]*/, "", s)
      sub(/[[:space:]]*\|.*/, "", s)
      return s
    }
    index($0, mk) > 0 && $0 ~ /^#/ { inh = 1; next }
    inh && !sep && $0 ~ /^\|/ { c = firstcell($0); if (c ~ /^[-: ]+$/) sep = 1; next }
    inh && sep && $0 ~ /^\|/ { print firstcell($0) }
    inh && sep && $0 !~ /^\|/ { exit }
    END { if (!sep) exit 3 }
  ' "$1"
}
enf_extract_decl() {
  # $1=文件：「| 能力基元」对照表中 readonly-execute 行的 readonly_enforcement: 等级
  # token；行未命中 exit 3（fail-closed），行在而声明缺失输出空（调用方报缺声明）。
  LC_ALL=C awk -v mk='| 能力基元' '
    function firstcell(line,   s) {
      s = line
      sub(/^\|[[:space:]]*/, "", s)
      sub(/[[:space:]]*\|.*/, "", s)
      return s
    }
    index($0, mk) == 1 { inh = 1; next }
    inh && !sep && $0 ~ /^\|/ { c = firstcell($0); if (c ~ /^[-: ]+$/) sep = 1; next }
    inh && sep && $0 ~ /^\|/ {
      if (firstcell($0) == "readonly-execute") {
        i = index($0, "readonly_enforcement:")
        if (i > 0) {
          rest = substr($0, i + length("readonly_enforcement:"))
          sub(/^[[:space:]]+/, "", rest)
          if (match(rest, /[a-z][a-z-]*/)) print substr(rest, RSTART, RLENGTH)
        }
        found = 1
        exit
      }
      next
    }
    inh && sep && $0 !~ /^\|/ { exit }
    END { if (!found) exit 3 }
  ' "$1"
}

check_14() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_caps=$(wc -l < "$pm_caps" | tr -d ' ')
n_captargets=$(wc -l < "$pm_captargets" | tr -d ' ')
caps_sorted=$(LC_ALL=C sort "$pm_caps")
cap_auth_path=$(cat "$pm_capauth")
cap_auth_file="$pkg_root/$cap_auth_path"
if [ ! -f "$cap_auth_file" ]; then
  add_problem "  - 能力权威文件不存在: $cap_auth_path"
else
  rc=0
  auth_names=$(cap_extract_auth "$cap_auth_file") || rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$auth_names" ]; then
    printf 'check-package: 错误：检查 14 权威表解析失效（窄锚点未命中或零数据行，fail-closed）: %s\n' "$cap_auth_path" >&2
    exit 2
  fi
  auth_sorted=$(printf '%s\n' "$auth_names" | LC_ALL=C sort -u)
  cap_m=''; cap_x=''; sep2=''
  for v in $caps_sorted; do
    printf '%s\n' "$auth_sorted" | grep -qx "$v" || { cap_m="$cap_m$sep2$v"; sep2='、'; }
  done
  sep2=''
  for v in $auth_sorted; do
    printf '%s\n' "$caps_sorted" | grep -qx "$v" || { cap_x="$cap_x$sep2$v"; sep2='、'; }
  done
  if [ -n "$cap_m" ] || [ -n "$cap_x" ]; then
    cap_msg=''
    if [ -n "$cap_m" ]; then
      cap_msg="缺少 ${cap_m}"
    fi
    if [ -n "$cap_x" ]; then
      if [ -n "$cap_msg" ]; then
        cap_msg="${cap_msg}；多出 ${cap_x}"
      else
        cap_msg="多出 ${cap_x}"
      fi
    fi
    add_problem "  - $cap_auth_path §能力基元清单表与名单不一致：$cap_msg"
  fi
fi
OLDIFS=$IFS
IFS='
'
while IFS= read -r cap_row; do
  IFS=$OLDIFS
  [ -n "$cap_row" ] || continue
  cap_rel=${cap_row%%"$TAB"*}
  cap_rest=${cap_row#*"$TAB"}
  cap_kind=${cap_rest%%"$TAB"*}
  cap_exp=${cap_rest#*"$TAB"}
  cap_file="$pkg_root/$cap_rel"
  if [ ! -f "$cap_file" ]; then
    add_problem "  - 检查目标不存在: $cap_rel"
    continue
  fi
  rc=0
  if [ "$cap_kind" = decl ]; then
    cap_got=$(cap_extract_decl "$cap_file") || rc=$?
  else
    cap_got=$(cap_extract_table "$cap_file") || rc=$?
  fi
  if [ "$rc" -ne 0 ] || [ -z "$cap_got" ]; then
    printf 'check-package: 错误：检查 14 目标解析失效（窄锚点未命中或零数据行，fail-closed）: %s\n' "$cap_rel" >&2
    exit 2
  fi
  cap_got_sorted=$(printf '%s\n' "$cap_got" | LC_ALL=C sort -u)
  cap_exp_sorted=$(printf '%s\n' "$cap_exp" | tr ',' '\n' | LC_ALL=C sort -u)
  cap_m=''; cap_x=''; cap_u=''; sep2=''
  for v in $cap_exp_sorted; do
    printf '%s\n' "$cap_got_sorted" | grep -qx "$v" || { cap_m="$cap_m$sep2$v"; sep2='、'; }
  done
  sep2=''
  for v in $cap_got_sorted; do
    if printf '%s\n' "$cap_exp_sorted" | grep -qx "$v"; then
      continue
    fi
    if printf '%s\n' "$caps_sorted" | grep -qx "$v"; then
      cap_x="$cap_x$sep2$v"
    else
      cap_u="$cap_u$sep2$v"
    fi
    sep2='、'
  done
  if [ -n "$cap_m" ]; then
    # 花括号不可省略：变量名后紧跟全角字符时，sh 会把多字节字符并入变量名（同款先例见检查 5/12）。
    add_problem "  - $cap_rel 缺少基元 ${cap_m}（相对登记预期名单）"
  fi
  if [ -n "$cap_u" ]; then
    add_problem "  - $cap_rel 未登记基元名 ${cap_u}（不在名单，注入或改名）"
  fi
  if [ -n "$cap_x" ]; then
    add_problem "  - $cap_rel 多出基元 ${cap_x}（超出登记预期名单）"
  fi
done < "$pm_captargets"
IFS=$OLDIFS
# 检查 14 扩展维度（readonly-execute 只读约束等级）：词表受控（enforcement 词表节）＋
# 逐适配器对照表 readonly-execute 行提取 readonly_enforcement: 等级 token，与登记预期
# 值全等比对；预期/声明值不在词表、缺声明、值不一致即 FAIL 指名文件；readonly-execute
# 行未命中（表锚点失效或行被删）即 exit 2 不静默过（本检查既有 fail-closed 同款）。
n_enf=$(wc -l < "$pm_enf" | tr -d ' ')
enf_vocab_sorted=$(LC_ALL=C sort -u "$pm_enfvocab")
OLDIFS=$IFS
IFS='
'
while IFS= read -r enf_row; do
  IFS=$OLDIFS
  [ -n "$enf_row" ] || continue
  enf_rel=${enf_row%%"$TAB"*}
  enf_exp=${enf_row#*"$TAB"}
  enf_file="$pkg_root/$enf_rel"
  if [ ! -f "$enf_file" ]; then
    add_problem "  - enforcement 检查目标不存在: $enf_rel"
    continue
  fi
  if ! printf '%s\n' "$enf_vocab_sorted" | grep -qx "$enf_exp"; then
    add_problem "  - $enf_rel 登记预期等级不在受控词表: $enf_exp"
    continue
  fi
  rc=0
  enf_got=$(enf_extract_decl "$enf_file") || rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 14 enforcement 目标解析失效（readonly-execute 行未命中，fail-closed）: %s\n' "$enf_rel" >&2
    exit 2
  fi
  if [ -z "$enf_got" ]; then
    add_problem "  - $enf_rel readonly-execute 行缺 readonly_enforcement 声明"
  elif ! printf '%s\n' "$enf_vocab_sorted" | grep -qx "$enf_got"; then
    add_problem "  - $enf_rel readonly_enforcement 值不在受控词表: $enf_got"
  elif [ "$enf_got" != "$enf_exp" ]; then
    # 花括号不可省略：变量名后紧跟全角字符时，sh 会把多字节字符并入变量名（同款先例见检查 5/12）。
    add_problem "  - $enf_rel readonly_enforcement 声明与登记预期不一致: ${enf_got}（期望 ${enf_exp}）"
  fi
done < "$pm_enf"
IFS=$OLDIFS
if [ -n "$problems" ]; then
  _chk_desc="能力映射一致（基元 ${n_caps} 个，检查目标 ${n_captargets} 个，enforcement ${n_enf} 个）"
else
  _chk_desc="能力映射一致（基元 ${n_caps} 个，检查目标 ${n_captargets} 个，enforcement ${n_enf} 个）"
fi
:
}
