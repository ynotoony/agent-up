#!/bin/sh
# Input: check_37 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_adapter
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 37（model-tier-contract）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 37：模型档位契约结构（复杂度派生档位 ↔ 适配器 §2.6）与短上下文别名契约结构
# （↔ 适配器 §2.7）。四层断言：①
# references/adapters/README.md「模型档位派生表」数据行恰四行且首列按 C0–C3 有序、第二列
# 非空、C0–C2 三档词两两不同、C3 行第二列不得复用任三档词（无第五档）；②adapter-registry
# 登记宿主文件与 adapter-template.md 骨架均含「### 2.6 模型档位可用性」，分档能力／
# 角色级模型键／降级记录格式三条 bullet 各恰一行且值非空，档位表恰三行且档位集合＝派生表
# 三档词（各一次）、取值非空；③宿主文件额外断言：分档能力以 可逐档／仅单档／不可分档
# 开头，不可分档宿主三档取值均含 inherit，仅单档与不可分档宿主角色级模型键标待实测，
# 降级记录格式含 model_tier，档位取值含 inherit 时该行同含 inherit；④宿主文件与骨架均含
# 「### 2.7 短上下文别名与到线策略」，短上下文别名取值／到线行为／Agent 工具显式覆盖／
# 降级记录格式四条 bullet 各恰一行且值非空；宿主侧别名取值落 README「别名取值词表」、
# 到线行为落「到线行为词表」（两表为受控词表，越表即 FAIL），显式覆盖取值 ∈ 可／否／待实测
# （引擎内闭集，同 §2.6 分档能力先例），降级记录格式须含 short_context: 与 boundary: 两个
# 记录键；证据闸——别名取值或到线行为离开待实测（即写实测结论）时该行须含「实测」字样，
# 阻断以推测或代码阅读替代运行实测。三档词与两张词表均自 README 数据读取（引擎零取值硬编码）；
# 模板骨架是占位，只做 §2.7 结构断言。§2.6 与 §2.7 的 bullet 读取均限定在各自小节内
# （两节同用「降级记录格式」标签，不跨节计数）。

a37_get() {
  LC_ALL=C awk -v sec="${4:-2\\.6 }" -v lab="$2" -v mode="$3" '
    BEGIN { pre = "- " lab "：" ; prel = length(pre); head = "^### " sec }
    $0 ~ head { insec = 1; next }
    insec && /^#+ / { insec = 0 }
    insec && index($0, pre) == 1 {
      n++; v = substr($0, prel + 1); gsub(/^[ \t]+/, "", v); gsub(/[ \t]+$/, "", v); last = v
    }
    END { if (mode == "count") print n + 0; else print last }' "$1"
}
a37_tier_rows() {
  LC_ALL=C awk -F'|' '
    function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
    /^### 2\.6 / { insec = 1; next }
    insec && /^#+ / { insec = 0 }
    insec && /^\|/ {
      c1 = trim($2); c2 = trim($3)
      if (c1 == "档位" || c1 ~ /^-+$/) next
      if (c1 == "" && c2 == "") next
      print c1 "\t" c2
    }' "$1"
}
a37_check() {
  # $1=包根相对路径 $2=host|template
  a37_rel=$1
  a37_kind=$2
  a37_abs="$pkg_root/$a37_rel"
  if [ ! -f "$a37_abs" ]; then
    add_problem "  - 缺少适配文件: ${a37_rel}"
    return
  fi
  if ! grep -q '^### 2\.6 模型档位可用性' "$a37_abs"; then
    add_problem "  - ${a37_rel} 缺「### 2.6 模型档位可用性」段"
    return
  fi
  for a37_lab in 分档能力 角色级模型键 降级记录格式; do
    a37_cnt=$(a37_get "$a37_abs" "$a37_lab" count)
    a37_val=$(a37_get "$a37_abs" "$a37_lab" value)
    if [ "$a37_cnt" -ne 1 ]; then
      add_problem "  - ${a37_rel} §2.6「${a37_lab}」行应恰 1 行（实为 ${a37_cnt} 行）"
    elif [ -z "$a37_val" ]; then
      add_problem "  - ${a37_rel} §2.6「${a37_lab}」取值为空"
    fi
  done
  a37_tr=$(a37_tier_rows "$a37_abs")
  a37_tr_n=$(printf '%s\n' "$a37_tr" | grep -c . || true)
  if [ "$a37_tr_n" -ne "$n37_tiers" ]; then
    add_problem "  - ${a37_rel} §2.6 档位表应恰 ${n37_tiers} 行（small/standard/strong），实为 ${a37_tr_n} 行"
  fi
  a37_set=$(printf '%s\n' "$a37_tr" | cut -f1 | LC_ALL=C sort | tr '\n' ' ')
  a37_want_set=$(printf '%s\n%s\n%s\n' "$a37_t1" "$a37_t2" "$a37_t3" | LC_ALL=C sort | tr '\n' ' ')
  if [ "$a37_set" != "$a37_want_set" ]; then
    add_problem "  - ${a37_rel} §2.6 档位集合与派生表不一致（应＝「${a37_want_set% }」，实为「${a37_set% }」）"
  fi
  a37_tr_empty=$(printf '%s\n' "$a37_tr" | awk -F'\t' '$2 == "" { print $1 }' | tr '\n' ' ')
  if [ -n "$a37_tr_empty" ]; then
    add_problem "  - ${a37_rel} §2.6 档位取值空: ${a37_tr_empty% }"
  fi
  if [ "$a37_kind" = host ]; then
    a37_dial=$(a37_get "$a37_abs" 分档能力 value)
    case $a37_dial in
      可逐档*) a37_tier_mode=逐档 ;;
      仅单档*) a37_tier_mode=单档 ;;
      不可分档*) a37_tier_mode=不可分档 ;;
      *) a37_tier_mode=bad ;;
    esac
    if [ "$a37_tier_mode" = bad ]; then
      add_problem "  - ${a37_rel} §2.6 分档能力须以 可逐档／仅单档／不可分档 开头: ${a37_dial}"
    fi
    if [ "$a37_tier_mode" = 不可分档 ]; then
      a37_no_inh=$(printf '%s\n' "$a37_tr" | awk -F'\t' 'index($2, "inherit") == 0 { print $1 }' | tr '\n' ' ')
      if [ -n "$a37_no_inh" ]; then
        add_problem "  - ${a37_rel} §2.6 不可分档宿主三档取值须均为 inherit（缺: ${a37_no_inh% }）"
      fi
    fi
    if [ "$a37_tier_mode" = 单档 ] || [ "$a37_tier_mode" = 不可分档 ]; then
      a37_key=$(a37_get "$a37_abs" 角色级模型键 value)
      case $a37_key in
        *待实测*) ;;
        *) add_problem "  - ${a37_rel} §2.6 仅单档/不可分档宿主的角色级模型键须标待实测: ${a37_key}" ;;
      esac
    fi
    a37_rec=$(a37_get "$a37_abs" 降级记录格式 value)
    case $a37_rec in
      *model_tier*) ;;
      *) add_problem "  - ${a37_rel} §2.6 降级记录格式须含 model_tier: ${a37_rec}" ;;
    esac
    if printf '%s\n' "$a37_tr" | awk -F'\t' 'index($2, "inherit") > 0 { f = 1 } END { exit f ? 0 : 1 }'; then
      case $a37_rec in
        *inherit*) ;;
        *) add_problem "  - ${a37_rel} §2.6 档位取值含 inherit 时降级记录格式须同样含 inherit: ${a37_rec}" ;;
      esac
    fi
    n37_hosts=$((n37_hosts + 1))
  else
    n37_tmpl=$((n37_tmpl + 1))
  fi
  a37_check_27 "$a37_rel" "$a37_kind"
}
# ---- §2.7 短上下文别名与到线策略判定面（票 294：独立为同目录 37-short-context.sh）----
# shellcheck disable=SC1090,SC1091  # 短上下文判定面模块由引擎 checks 目录推导（动态源）
. "${chk_dir}/37-short-context.sh"

check_37() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n37_hosts=0
n37_tmpl=0
n37_tiers=3
ad37_readme="$pkg_root/references/adapters/README.md"
ad37_tmpl="$pkg_root/references/adapters/adapter-template.md"
a37_t1=''
a37_t2=''
a37_t3=''
if [ ! -f "$ad37_readme" ]; then
  add_problem '  - references/adapters/README.md 不存在（模型档位派生表无承载）'
else
  a37_rows=$(sed -n '/^## 模型档位派生表/,/^## /p' "$ad37_readme" | LC_ALL=C awk -F'|' '
    function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
    /^\|/ {
      c1 = trim($2); c2 = trim($3)
      if (c1 == "复杂度" || c1 ~ /^-+$/) next
      if (c1 == "" && c2 == "") next
      print c1 "\t" c2
    }')
  a37_row_n=$(printf '%s\n' "$a37_rows" | grep -c . || true)
  if [ "$a37_row_n" -ne 4 ]; then
    add_problem "  - 模型档位派生表数据行应为 4 行（C0–C3），实为 ${a37_row_n} 行"
  fi
  a37_order=$(printf '%s\n' "$a37_rows" | cut -f1 | tr '\n' ' ' | sed 's/ $//')
  if [ "$a37_order" != 'C0 C1 C2 C3' ]; then
    add_problem "  - 模型档位派生表首列须按 C0 C1 C2 C3 有序（逐行对应 §2.1），实为「${a37_order}」"
  fi
  a37_empty=$(printf '%s\n' "$a37_rows" | awk -F'\t' '$2 == "" { print NR }' | tr '\n' ' ')
  if [ -n "$a37_empty" ]; then
    add_problem "  - 模型档位派生表档位列有空行（第 ${a37_empty% } 行）"
  fi
  a37_t1=$(printf '%s\n' "$a37_rows" | awk -F'\t' '$1 == "C0" { print $2; exit }')
  a37_t2=$(printf '%s\n' "$a37_rows" | awk -F'\t' '$1 == "C1" { print $2; exit }')
  a37_t3=$(printf '%s\n' "$a37_rows" | awk -F'\t' '$1 == "C2" { print $2; exit }')
  a37_c3=$(printf '%s\n' "$a37_rows" | awk -F'\t' '$1 == "C3" { print $2; exit }')
  if [ -z "$a37_t1" ] || [ -z "$a37_t2" ] || [ -z "$a37_t3" ]; then
    add_problem "  - 模型档位派生表 C0–C2 档位词须非空（实为「${a37_t1}」「${a37_t2}」「${a37_t3}」）"
  else
    if [ "$a37_t1" = "$a37_t2" ] || [ "$a37_t1" = "$a37_t3" ] || [ "$a37_t2" = "$a37_t3" ]; then
      add_problem "  - 模型档位派生表 C0–C2 档位词须两两不同（实为「${a37_t1}」「${a37_t2}」「${a37_t3}」）"
    fi
    case $a37_c3 in
      "$a37_t1"|"$a37_t2"|"$a37_t3")
        add_problem "  - C3 行第二列不得复用三档词（无第五档）: ${a37_c3}" ;;
    esac
  fi
fi

# 单文件 §2.6 结构断言读值器（$1=文件 $2=bullet 标签 $3=count|value $4=小节锚，缺省 `2\.6 `）
# 限定在小节内读取：命中「### <小节锚>」标题起算，遇任一下一行标题即止。§2.6 与 §2.7 同用
# 「降级记录格式」等标签，跨节计数会把两节 bullet 混算，故一律按小节收敛。

# 单文件 §2.6 档位表解析（$1=文件；输出「档位<TAB>取值」行；同款小节收敛，§2.7 表不混入）


# 检查 37④ 词表读值器：README「短上下文别名与到线词表」小节内指定子词表的首列取值
# （$1=文件 $2=子词表名：别名取值|到线行为；反引号剥离后输出）

# 取值落词表判定（$1=取值 $2=词表多行文本）：恰等，或在取值后紧跟括号说明

# 单文件 §2.7 短上下文别名与到线策略结构断言（$1=包根相对路径 $2=host|template）：
# 段在位、四条 bullet 各恰一行且值非空；宿主侧再加两张受控词表落表、显式覆盖三值整词
# 起首（可／否／待实测 后须为行尾或分隔符）、降级记录格式记录键齐备与证据闸（离开待实测
# 的取值须含「实测」且不得含「未实测／待实测」字样）。模板只做结构断言。

a37_alias_vocab=$(a37_vocab "$ad37_readme" 别名取值)
a37_bound_vocab=$(a37_vocab "$ad37_readme" 到线行为)
if [ -z "$a37_alias_vocab" ] || [ -z "$a37_bound_vocab" ]; then
  add_problem '  - references/adapters/README.md「短上下文别名与到线词表」取值未解析到（两张受控词表无承载）'
fi

OLDIFS37=$IFS
IFS='
'
# shellcheck disable=SC2013  # 适配注册表行以 TAB 分列取第 3 字段（路径无空白），IFS 收敛换行即按行迭代
for a37_reg in $(LC_ALL=C awk -F'\t' '{ print $3 }' "$pm_adapters"); do
  IFS=$OLDIFS37
  a37_check "$a37_reg" host
  IFS='
'
done
IFS=$OLDIFS37
if [ -f "$ad37_tmpl" ]; then
  a37_check 'references/adapters/adapter-template.md' template
else
  add_problem '  - references/adapters/adapter-template.md 不存在（骨架 §2.6 无承载）'
fi
if [ -n "$problems" ]; then
  _chk_desc="模型档位契约结构（宿主 ${n37_hosts} 个，模板 ${n37_tmpl} 件，档位 ${n37_tiers} 个）"
else
  _chk_desc="模型档位契约结构（宿主 ${n37_hosts} 个，模板 ${n37_tmpl} 件，档位 ${n37_tiers} 个）"
fi
:
}
