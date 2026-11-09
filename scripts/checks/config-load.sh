#!/bin/sh
# Input: 引擎引导时传入本目录（check-package.sh 的 script_dir）；pm_loader_init 无参数（用
#        pm_tmpdir 派生账本）；pm_load_manifests 传入包根。两份数据源＝同目录
#        package-manifest.rules 与包根相对 references/adapters/adapter-diffs.rules。
# Output: 引擎全局 pm_* 账本（每节一个文件，TAB 字段行；零行＝节缺失）与 pm_tmpdir 生命周期；
#        逐节 schema 登记驱动的通用行校验器＋跨节专用校验器；任一结构不合预期即 exit 2
#        fail-closed（stdout 零部分结论）。
# Pos: 配置加载/校验模块（agent-up/scripts/checks/config-load.sh）：非执行式词法器接入、
#      逐节 schema 登记、通用校验器与清单加载接口的唯一承载点，由 check-package.sh 薄 CLI 载入。
# shellcheck disable=SC2034,SC2154  # 跨件共享状态（引擎全局账本/上下文），单文件视野误报

# ============================================================
# 一、词法器接入与清单加载接口
# ============================================================

pm_loader_bootstrap() {
  # $1=引擎所在目录（script_dir）。词法器为同目录 rules-lexer.sh 的共享实现（唯一词法核心）。
  _plb_dir=$1
  pm_rules="$_plb_dir/package-manifest.rules"
  _plb_lexer="$_plb_dir/rules-lexer.sh"
  if [ -f "$_plb_lexer" ]; then
    # shellcheck disable=SC1090,SC1091  # 词法器路径由调用方目录推导（动态源，静态视野不可跟随）
    . "$_plb_lexer"
  else
    printf 'check-package: 错误：共享规则表词法器缺失: %s\n' "$_plb_lexer" >&2
    exit 2
  fi
  # 逐节 schema 登记的节名全集（分发白名单与账本创建面同一来源）
  pm_sections=$(pm_schema_ids)
}

pm_die() {
  printf 'check-package: 错误：包清单数据不合预期（fail-closed，不产生部分结论）: %s\n' "$pm_rules" >&2
  printf 'check-package: %s\n' "$1" >&2
  exit 2
}

pm_report() {
  # $1=结构校验错误文本（空＝通过）
  if [ -n "$1" ]; then
    printf 'check-package: 错误：包清单数据不合预期（fail-closed，不产生部分结论）: %s\n' "$pm_rules" >&2
    printf '%s\n' "$1" >&2
    exit 2
  fi
}

pm_die_ad() {
  printf 'check-package: 错误：适配差异数据表不合预期（fail-closed，不产生部分结论）: %s\n' "$pm_adrules" >&2
  printf 'check-package: %s\n' "$1" >&2
  exit 2
}

pm_report_data() {
  # $1=结构校验错误文本（空＝通过） $2=数据文件路径 $3=数据文件抬头文案
  if [ -n "$1" ]; then
    printf 'check-package: 错误：%s不合预期（fail-closed，不产生部分结论）: %s\n' "$3" "$2" >&2
    printf '%s\n' "$1" >&2
    exit 2
  fi
}

# ---- 非执行式解析：词法核心唯一实现＝rules-lexer.sh；本件只保留指令名/参数数分发表 ----
# 清单只作为受控文本数据解析，未知指令、恶意 shell 片段与结构破坏统一 fail-closed
# exit 2，不产生部分结论。字段值只作数据承载、解析期零求值零二次展开。
# shellcheck disable=SC2016  # awk 程序刻意单引号形态：程序内 $0/$1 等禁 shell 展开
pm_dispatch_awk='
{
  if (!lex_line($0)) next
  ar = -1
  if (L_cmd == "pm_entry" || L_cmd == "pm_template" || L_cmd == "pm_platform" || L_cmd == "pm_capability" || L_cmd == "pm_capability_authority" || L_cmd == "pm_mechanism" || L_cmd == "pm_mechanism_marker" || L_cmd == "pm_vague_word" || L_cmd == "pm_layout_face" || L_cmd == "pm_enforcement_level" || L_cmd == "pm_retired_face" || L_cmd == "pm_legacy_marker" || L_cmd == "pm_ticket_status" || L_cmd == "pm_workflow_fixture_marker" || L_cmd == "pm_production_entry" || L_cmd == "pm_production_claim") ar = 1
  else if (L_cmd == "pm_shortcode" || L_cmd == "pm_mirror" || L_cmd == "pm_layout_universe" || L_cmd == "pm_layout_legacy_file" || L_cmd == "pm_enforcement_target" || L_cmd == "pm_retired_token" || L_cmd == "pm_workflow" || L_cmd == "pm_readonly_site") ar = 2
  else if (L_cmd == "pm_script" || L_cmd == "pm_vague_exempt" || L_cmd == "pm_cite_exempt" || L_cmd == "pm_capability_target" || L_cmd == "pm_layout_compat_exempt") ar = 3
  else if (L_cmd == "pm_adapter_exec" || L_cmd == "pm_adapter_dialect") ar = 3
  else if (L_cmd == "pm_adapter_cap" || L_cmd == "pm_adapter_role") ar = 4
  else if (L_cmd == "pm_contract_pointer") ar = 5
  else if (L_cmd == "pm_check") ar = 2
  else if (L_cmd == "pm_check_total" || L_cmd == "pm_check_retired") ar = 1
  else if (L_cmd == "chk") ar = 4
  else if (L_cmd == "chk_total" || L_cmd == "chk_retired") ar = 1
  else if (L_cmd == "pm_adapter") ar = 6
  if (ar < 0) { lex_bad("未知指令或非指令行: " substr(L_raw, 1, 40)); next }
  if (L_nf != ar) { lex_bad("参数数量不合预期（" L_cmd " 须恰 " ar " 个参数）: " L_nf); next }
  print L_cmd "\t" substr(L_out, 1, length(L_out) - 1)
}
END { if (n > 0) exit 1 }
'

pm_parse_data() {
  # $1=数据文件（输入） $2=解析产物账本（覆盖写） $3=错误抬头文案 $4=（可选）字面反引号 1/0
  pm_parse_bad=''
  LC_ALL=C awk -v lex_progin="$1" -v lex_style=pkg -v lex_allow_bt="${4:-0}" \
    -v lex_lead='^[[:space:]]+' \
    -v lex_tabmsg='行内制表符（字段边界污染，TAB 为解析器注入唯一边界符）' \
    -v lex_noargmsg='未知指令或非指令行（无参数）' \
    -v lex_dollarsuffix='——非执行式解析拒绝' \
    -v q="'" "$RULES_LEXER_AWK$pm_dispatch_awk" "$1" > "$2" || pm_parse_bad=1
  pm_parse_bad=${pm_parse_bad:-}
  if [ -n "$pm_parse_bad" ]; then
    printf 'check-package: 错误：%s非执行式解析不合预期（fail-closed，不产生部分结论）: %s\n' "$3" "$1" >&2
    return 1
  fi
  return 0
}

pm_dispatch_file() {
  # $1=解析产物账本（指令\t参数 TAB 行）：按指令名分发到同名节账本（pm_sections 白名单）。
  # 非本表节的指令不落账（数据指令分发表已拒绝未知指令；chk* 行属检查注册表解析面）。
  pm_dispatch_row=''
  pm_dispatch_cmd=''
  pm_dispatch_rest=''
  while IFS= read -r pm_dispatch_row; do
    pm_dispatch_cmd=${pm_dispatch_row%%"$TAB"*}
    pm_dispatch_rest=${pm_dispatch_row#*"$TAB"}
    case " $pm_sections " in
      *" $pm_dispatch_cmd "*) ;;
      *) continue ;;
    esac
    # 定向运行只落被选中检查声明的节及其 schema 声明的跨节依赖（全量模式恒真）
    if chk_section_needed "$pm_dispatch_cmd"; then
      printf '%s\n' "$pm_dispatch_rest" >> "$pm_tmpdir/$pm_dispatch_cmd"
    fi
  done < "$1"
}

pm_loader_init() {
  # 单一临时目录承载全部账本：一次 mktemp -d 取代逐件 mktemp（同语义、同清理面）
  TAB=$(printf '\t')
  t_dir=${TMPDIR:-/tmp}
  pm_tmpdir=$(mktemp -d "${t_dir%/}/pkgcheck.XXXXXX")
  trap pm_cleanup EXIT HUP INT TERM
  pm_entries="$pm_tmpdir/pm_entry"
  pm_scripts="$pm_tmpdir/pm_script"
  pm_templates="$pm_tmpdir/pm_template"
  pm_codes="$pm_tmpdir/pm_shortcode"
  pm_platforms="$pm_tmpdir/pm_platform"
  pm_words="$pm_tmpdir/pm_vague_word"
  pm_exempts="$pm_tmpdir/pm_vague_exempt"
  pm_mirrors="$pm_tmpdir/pm_mirror"
  pm_caps="$pm_tmpdir/pm_capability"
  pm_capauth="$pm_tmpdir/pm_capability_authority"
  pm_captargets="$pm_tmpdir/pm_capability_target"
  pm_mechs="$pm_tmpdir/pm_mechanism"
  pm_citeex="$pm_tmpdir/pm_cite_exempt"
  pm_layoutface="$pm_tmpdir/pm_layout_face"
  pm_layoutu="$pm_tmpdir/pm_layout_universe"
  pm_layoutlf="$pm_tmpdir/pm_layout_legacy_file"
  pm_layoutce="$pm_tmpdir/pm_layout_compat_exempt"
  pm_enf="$pm_tmpdir/pm_enforcement_target"
  pm_enfvocab="$pm_tmpdir/pm_enforcement_level"
  pm_adapters="$pm_tmpdir/pm_adapter"
  pm_adcap="$pm_tmpdir/pm_adapter_cap"
  pm_adrole="$pm_tmpdir/pm_adapter_role"
  pm_adexec="$pm_tmpdir/pm_adapter_exec"
  pm_addial="$pm_tmpdir/pm_adapter_dialect"
  pm_retired="$pm_tmpdir/pm_retired_token"
  pm_retface="$pm_tmpdir/pm_retired_face"
  pm_legmark="$pm_tmpdir/pm_legacy_marker"
  pm_workflows="$pm_tmpdir/pm_workflow"
  pm_wffixmark="$pm_tmpdir/pm_workflow_fixture_marker"
  pm_prodentries="$pm_tmpdir/pm_production_entry"
  pm_prodclaims="$pm_tmpdir/pm_production_claim"
  pm_tstatus="$pm_tmpdir/pm_ticket_status"
  pm_rosites="$pm_tmpdir/pm_readonly_site"
  pm_cptrs="$pm_tmpdir/pm_contract_pointer"
  pm_checks="$pm_tmpdir/pm_check"
  pm_checktotal="$pm_tmpdir/pm_check_total"
  pm_checkretired="$pm_tmpdir/pm_check_retired"
  pm_parsed="$pm_tmpdir/manifest-parsed"
  chk_out_buf="$pm_tmpdir/chk-out"
  chk_state_desc="$pm_tmpdir/chk-state-desc"
  chk_state_skip="$pm_tmpdir/chk-state-skip"
  chk_state_problems="$pm_tmpdir/chk-state-problems"
  chk_state_stdout="$pm_tmpdir/chk-state-stdout"
  chk_emitted_ids="$pm_tmpdir/chk-emitted-ids"
  # 节账本须预先在位（零行＝节缺失判定基准）；重定向建空件，零进程开销
  for _pl_f in $pm_sections; do
    : > "$pm_tmpdir/$_pl_f"
  done
  for _pl_f in "$pm_parsed" "$chk_out_buf" "$chk_state_desc" "$chk_state_skip" \
    "$chk_state_problems" "$chk_state_stdout" "$chk_emitted_ids"; do
    : > "$_pl_f"
  done
  # schema 登记表落盘一次（校验驱动按行读，避免每次重算与 here-doc 展开）
  pm_schema_table > "$pm_tmpdir/schema-rows"
}

pm_cleanup() {
  # 全部账本共处一个临时目录，一次递归删除（逐件 mktemp 在 macOS 上固定开销高）
  [ -n "$pm_tmpdir" ] || return 0
  rm -rf -- "$pm_tmpdir"
}

# ---- 清单加载接口（CLI 唯一调用点）：解析→按节分发→逐节校验，任一失败 exit 2 ----
pm_load_manifests() {
  # $1=包根
  [ -f "$pm_rules" ] || {
    printf 'check-package: 错误：包清单数据文件缺失: %s\n' "$pm_rules" >&2
    exit 2
  }
  pm_parse_data "$pm_rules" "$pm_parsed" '包清单数据' || { rm -f "$pm_parsed"; pm_parsed=''; exit 2; }
  pm_dispatch_file "$pm_parsed"
  rm -f "$pm_parsed"; pm_parsed=''
  # ---- 适配差异数据表加载（包根相对落位，包侧唯一副本；共用同一解析引擎与分发器）----
  pm_adrules="$1/references/adapters/adapter-diffs.rules"
  if [ ! -f "$pm_adrules" ]; then
    printf 'check-package: 错误：适配差异数据表缺失: %s\n' "$pm_adrules" >&2
    exit 2
  fi
  pm_parsed="$pm_tmpdir/adapter-diffs-parsed"
  : > "$pm_parsed"
  pm_parse_data "$pm_adrules" "$pm_parsed" '适配差异数据表' 1 || { rm -f "$pm_parsed"; pm_parsed=''; exit 2; }
  pm_dispatch_file "$pm_parsed"
  rm -f "$pm_parsed"; pm_parsed=''
  pm_validate_sections
}

# ============================================================
# 二、逐节 schema 登记（单一登记点）
# 列：节名｜行标签｜字段数｜字段规格（; 分隔，type 或 type^自定义文案[^次文案]）｜
#     唯一键字段号（, 分隔；- 空）｜唯一性文案｜标志（p=非空下限 A=适配差异表抬头）｜
#     非空下限文案｜跨节依赖节名（, 分隔）｜专用校验器函数名（- 走通用行校验器）
# 加一节清单＝本表加一行＋（按需）专用校验器一件；分发、账本创建与非空下限随之生效。
# ============================================================

pm_schema_table() {
  cat <<'EOS'
pm_entry|entry-files 节|1|path|1|路径跨行重复|p|清单缺 entry-files 节（零行）|-|-
pm_script|scripts 节|3|scriptpath;enum:script,rules,test-harness,dir^kind 不合预期;nonempty^缺说明|1|路径跨行重复|p|清单缺 scripts 节（零行）|-|-
pm_template|templates 节|1|tmpl|1|文件名跨行重复|p|清单缺 templates 节（零行）|-|-
pm_shortcode|shortcodes 节|2|code2;refspath|1,2|短码与所属文件对跨行重复|p|清单缺 shortcodes 节（零行）|-|-
pm_platform|platform-enum 节|1|token|1|枚举值跨行重复|p|清单缺 platform-enum 节（零行）|-|-
pm_adapter|adapter-registry 节|-|-|-|-|pA|清单缺 adapter-registry 节（零行）|pm_platform,pm_capability|pm_v_adapter_registry
pm_adapter_cap|adapter-diffs capability-map 节|-|-|-|-|pA|差异数据表缺 capability-map 节（零行）|pm_adapter,pm_capability,pm_enforcement_level|pm_v_adapter_diff_cap
pm_adapter_role|adapter-diffs role-map 节|-|-|-|-|pA|差异数据表缺 role-map 节（零行）|pm_adapter|pm_v_adapter_diff_role
pm_adapter_exec|adapter-diffs executor-status 节|-|-|-|-|pA|差异数据表缺 executor-status 节（零行）|pm_adapter|pm_v_adapter_diff_exec
pm_adapter_dialect|adapter-diffs dialect-signature 节|-|-|-|-|pA|差异数据表缺 dialect-signature 节（零行）|pm_adapter|pm_v_adapter_diff_dialect
pm_vague_word|vague-words 节|1|word^词为空^词含空白（字面匹配非正则，空白词无法定位）|1|词跨行重复|p|清单缺 vague-words 节（零行）|-|-
pm_vague_exempt|vague-exemptions 节|3|path;int^行号须正整数;nonempty^缺理由（行级豁免须注记理由）|1,2|路径+行号跨行重复|-|-|-|-
pm_mirror|mirrors 节|2|filename;enum:mirror,package-only^所有权类别不合预期|1|文件名跨行重复|p|清单缺 mirrors 节（零行）|-|-
pm_cite_exempt|ticket-citation-ban 豁免节|3|path;int^行号须正整数;nonempty^缺理由（行级豁免须注记理由）|1,2|路径+行号跨行重复|-|-|-|-
pm_layout_face|layout-face 节|1|path|1|路径跨行重复|p|清单缺 layout-face 节（零行）|-|-
pm_layout_universe|layout-universe 节|2|path;anchor|1|登记模板路径跨行重复|p|清单缺 layout-universe 节（零行）|-|-
pm_layout_legacy_file|layout-legacy-file 节|2|path;nonempty^缺理由（整文件合法保留须注记理由）|1|路径跨行重复|p|清单缺 layout-legacy-file 节（零行）|-|-
pm_layout_compat_exempt|layout-compat-exempt 节|3|path;int^行号须正整数;nonempty^缺理由（兼容豁免须注记理由）|1,2|路径+行号跨行重复|-|-|-|-
pm_capability|capability-primitives 节|1|token^基元名须小写 token（字母开头，小写字母/数字/连字符）|1|基元名跨行重复|p|清单缺 capability-primitives 节（零行）|-|-
pm_capability_authority|capability authority 行|-|-|-|-|p|清单缺 capability authority 登记（零行）|-|pm_v_capability_authority
pm_capability_target|capability targets 行|-|-|-|-|p|清单缺 capability targets 登记（零行）|pm_capability|pm_v_capability_target
pm_enforcement_level|enforcement 词表|1|tokdash|1|等级值跨行重复|p|清单缺 enforcement 词表登记（零行）|-|-
pm_enforcement_target|enforcement targets 行|-|-|-|-|p|清单缺 enforcement targets 登记（零行）|pm_enforcement_level|pm_v_enforcement_target
pm_mechanism|mechanism-vocab 节|1|word^值为空^值含空白（受控值须为单 token）|1|值跨行重复|p|清单缺 mechanism-vocab 节（零行）|-|-
pm_retired_token|retired-path 节|2|word^退役 token 须非空单 token^退役 token 须非空单 token;nonempty^缺说明|1|token 跨行重复|p|清单缺 retired-path 节退役 token 登记（零行）|-|-
pm_retired_face|retired-path 活动面|1|path|1|路径跨行重复|p|清单缺 retired-path 节活动面登记（零行）|-|-
pm_legacy_marker|retired-path 标注词|1|word^ledger 标注词须非空单 token^ledger 标注词须非空单 token|1|标注词跨行重复|p|清单缺 retired-path 节 legacy 标注词登记（零行）|-|-
pm_workflow|workflow-graph 节|2|path;enum:fixture,production^定位枚举不合预期|1|工作流路径跨行重复|p|清单缺 workflow-graph 节工作流登记（零行）|-|-
pm_ticket_status|workflow-graph 票状态词表|1|tokstatus^票状态值须小写 token（小写字母/数字/下划线）|1|票状态值跨行重复|p|清单缺 workflow-graph 节票状态词表登记（零行）|-|-
pm_workflow_fixture_marker|workflow-positioning fixture 标记词行|-|-|-|-|p|清单缺 workflow-positioning 节 fixture 标记词登记（零行）|-|pm_v_workflow_fixture_marker
pm_production_entry|workflow-positioning 生产入口|1|token^生产入口名须小写 token|1|生产入口名跨行重复|p|清单缺 workflow-positioning 节生产入口登记（零行）|-|-
pm_production_claim|workflow-positioning 生产可执行声称词|1|word^声称词须非空单 token^声称词须非空单 token|1|声称词跨行重复|p|清单缺 workflow-positioning 节生产可执行声称词登记（零行）|-|-
pm_readonly_site|readonly-sites 节|2|path;enum:authority,level,reference^模式枚举不合预期|1|声明面路径跨行重复|p|清单缺 readonly-sites 节声明面登记（零行）|-|-
pm_contract_pointer|contract-pointers 节|5|path^README 路径不合预期;nonempty^锚点为空;nonempty^指针原文为空;path^权威文件路径不合预期;nonempty^权威锚点为空|1,2|README+锚点 对跨行重复|p|清单缺 contract-pointers 节 README 契约指针登记（零行）|-|-
pm_check_total|check-registry 节|-|-|-|-|p|清单缺 check-registry 节编号上界（零行）|-|pm_v_check_total
pm_check_retired|check-registry 节|-|-|-|-|-|-|-|pm_v_check_retired
pm_check|check-registry 节|-|-|-|-|p|清单缺 check-registry 节检查登记（零行）|-|pm_v_check_rows
EOS
}

pm_schema_ids() {
  pm_schema_table | LC_ALL=C awk -F'|' 'NF { printf "%s%s", (n++ ? " " : ""), $1 } END { print "" }'
}

pm_schema_deps() {
  # $1=节名 → 空格分隔的依赖节名（无依赖输出空行）
  pm_schema_table | LC_ALL=C awk -F'|' -v want="$1" '
    $1 == want { if ($9 != "-") gsub(",", " ", $9); print $9; exit }
  '
}

pm_section_closure() {
  # $1...=需要的数据节；输出闭包（自身＋schema 声明的跨节依赖，含注册表交叉校验节）
  _psc_set=" $* pm_check pm_check_total pm_check_retired "
  _psc_more=1
  while [ "$_psc_more" -eq 1 ]; do
    _psc_more=0
    for _psc_s in $_psc_set; do
      for _psc_d in $(pm_schema_deps "$_psc_s"); do
        case " $_psc_set " in
          *" $_psc_d "*) ;;
          *) _psc_set="$_psc_set$_psc_d "; _psc_more=1 ;;
        esac
      done
    done
  done
  printf '%s' "$_psc_set"
}

chk_section_needed() {
  # $1=数据节名：全量模式恒真；定向运行＝需要集合成员判定（分发、非空下限与校验共用）
  [ "$chk_only_mode" -eq 0 ] && return 0
  case " $chk_need_sections " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# ============================================================
# 三、通用行校验器（schema 声明驱动；字段类型→错误文案的唯一实现）
# ============================================================

# shellcheck disable=SC2016  # awk 程序单引号形态：程序内 $i/$0 等禁 shell 展开
pm_rows_awk='
function typerr(typ, m1, m2, val,   nv, i, ev, out) {
  if (typ == "path") {
    if (val !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) return (m1 != "" ? m1 : "路径不合预期（禁前导斜杠、空白与特殊字符）") ": " val
    if (val ~ /(^|\/)\.\.(\/|$)/) return (m2 != "" ? m2 : "路径含 .. 段") ": " val
    return ""
  }
  if (typ == "refspath") {
    if (val !~ /^references\/[A-Za-z0-9][A-Za-z0-9._\/-]*$/) return (m1 != "" ? m1 : "所属文件须 references/ 前缀包内相对路径") ": " val
    if (val ~ /(^|\/)\.\.(\/|$)/) return (m2 != "" ? m2 : "路径含 .. 段") ": " val
    return ""
  }
  if (typ == "scriptpath") { if (val !~ /^scripts\/[A-Za-z0-9][A-Za-z0-9._-]*$/) return (m1 != "" ? m1 : "路径须 scripts/ 前缀加单段文件名（禁 .. 与斜杠入名）") ": " val; return "" }
  if (typ == "tmpl") { if (val !~ /^[A-Za-z0-9][A-Za-z0-9._-]*\.tmpl$/) return (m1 != "" ? m1 : "须为单段 .tmpl 文件名") ": " val; return "" }
  if (typ == "filename") { if (val !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) return (m1 != "" ? m1 : "须为单段文件名") ": " val; return "" }
  if (typ == "token") { if (val !~ /^[a-z][a-z0-9-]*$/) return (m1 != "" ? m1 : "值须小写 token") ": " val; return "" }
  if (typ == "tokdash") { if (val !~ /^[a-z][a-z-]*$/) return (m1 != "" ? m1 : "值须小写 token（小写字母/连字符）") ": " val; return "" }
  if (typ == "tokstatus") { if (val !~ /^[a-z][a-z0-9_]*$/) return (m1 != "" ? m1 : "值须小写 token（小写字母/数字/下划线）") ": " val; return "" }
  if (typ == "code2") { if (val !~ /^[A-Z][A-Z]$/) return (m1 != "" ? m1 : "短码须两字母大写") ": " val; return "" }
  if (typ == "int") { if (val !~ /^[0-9]+$/ || val + 0 <= 0) return (m1 != "" ? m1 : "须正整数") ": " val; return "" }
  if (typ == "nonempty") { if (val == "") return (m1 != "" ? m1 : "缺必填内容"); return "" }
  if (typ == "word") {
    if (val == "") return (m1 != "" ? m1 : "值为空")
    if (val ~ /[[:space:]]/) return (m1 != "" ? m1 : "值含空白（受控值须为单 token）") ": " val
    return ""
  }
  if (typ == "anchor") { if (val !~ /^[A-Za-z0-9:_\/-]+$/) return (m1 != "" ? m1 : "锚点须为受限字符集单 token") ": " val; return "" }
  if (typ ~ /^enum:/) {
    nv = split(substr(typ, 6), ev, ",")
    out = (m1 != "" ? m1 : "枚举不合预期") "（"
    for (i = 1; i <= nv; i++) out = out (i > 1 ? "|" : "") ev[i]
    out = out "）"
    for (i = 1; i <= nv; i++) if (val == ev[i]) return ""
    return out ": " val
  }
  return ""
}
function bad(msg) { printf "%s第 %d 行: %s\n", label, FNR, msg; n++ }
BEGIN { ns = split(specs, sp, ";"); nk = (uniq == "-" || uniq == "") ? 0 : split(uniq, kf, ",") }
{
  if (NF != nfv + 0) { bad("字段数 " NF "（预期 " nfv "）"); next }
  rowok = 1
  for (i = 1; i <= ns; i++) {
    npart = split(sp[i], pt, "^")
    err = typerr(pt[1], (npart >= 2 ? pt[2] : ""), (npart >= 3 ? pt[3] : ""), $i)
    if (err != "") { bad(err); rowok = 0 }
  }
  if (!rowok) next
  if (nk > 0) {
    key = ""
    disp = ""
    for (i = 1; i <= nk; i++) {
      key = key (i > 1 ? SUBSEP : "") $kf[i]
      disp = disp (i > 1 ? " " : "") $kf[i]
    }
    if (key in seen) { bad((dupmsg != "-" && dupmsg != "" ? dupmsg : "跨行重复") ": " disp); next }
    seen[key] = 1
  }
}
END { if (n > 0) exit 1 }
'

pm_validate_rows() {
  # $1=节名 $2=行标签 $3=字段数 $4=字段规格 $5=唯一键 $6=唯一性文案
  _pvr_bad=$(LC_ALL=C awk -F'\t' -v label="$2" -v nfv="$3" -v specs="$4" \
    -v uniq="$5" -v dupmsg="$6" "$pm_rows_awk" "$pm_tmpdir/$1") || true
  pm_report "$_pvr_bad"
}

# ============================================================
# 四、跨节专用校验器（schema 未表达的聚合/交叉约束）
# ============================================================

pm_v_capability_authority() {
  [ "$(wc -l < "$pm_capauth" | tr -d ' ')" -eq 1 ] || pm_die 'capability authority 须恰一行'
  _pvca_bad=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "capability authority 行: %s\n", msg; n++ }
    {
      if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
      if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
      if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_capauth") || true
  pm_report "$_pvca_bad"
}

pm_v_workflow_fixture_marker() {
  [ "$(wc -l < "$pm_wffixmark" | tr -d ' ')" -eq 1 ] || pm_die 'workflow-positioning fixture 标记词须恰一行'
  _pvwm_bad=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "workflow-positioning fixture 标记词行: %s\n", msg; n++ }
    {
      if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
      if ($1 == "") { bad("标记词为空"); next }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_wffixmark") || true
  pm_report "$_pvwm_bad"
}

pm_v_adapter_registry() {
  # platform ∈ platform-enum 宿主值、coverage ⊆ capability-primitives 名单需两节账本
  _pvar_capnames=$(LC_ALL=C awk -F'\t' '{ printf "%s%s", (NR > 1 ? "," : ""), $1 }' "$pm_caps")
  _pvar_hostplat=$(LC_ALL=C awk -F'\t' '$1 != "neutral" { if (n++) printf ","; printf "%s", $1 }' "$pm_platforms")
  _pvar_bad=$(LC_ALL=C awk -F'\t' -v capnames="$_pvar_capnames" -v hostplat="$_pvar_hostplat" '
    function bad(msg) { printf "adapter-registry 节第 %d 行: %s\n", FNR, msg; n++ }
    BEGIN { m = split(capnames, a, ","); for (i = 1; i <= m; i++) cap[a[i]] = 1; hp = split(hostplat, hb, ","); for (i = 1; i <= hp; i++) hostp[hb[i]] = 1 }
    {
      if (NF != 6) { bad("字段数 " NF "（预期 6：platform、shortcode、adapter_file、capability_coverage、role_mapping、evidence_status）"); next }
      if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("platform 须小写 token: " $1); next }
      if (!($1 in hostp)) { bad("platform 不在 platform-enum 节宿主值（neutral 平台无关不入注册表）: " $1); next }
      if ($1 in seenp) { bad("platform 跨行重复: " $1) } else { seenp[$1] = 1 }
      if ($2 !~ /^[A-Z][A-Z]$/) { bad("shortcode 须两字母大写: " $2); next }
      if ($2 in seens) { bad("shortcode 跨行重复（短码全局唯一由本节单源验证）: " $2) } else { seens[$2] = 1 }
      if ($3 !~ /^references\/adapters\/[A-Za-z0-9][A-Za-z0-9._-]*\.md$/) { bad("adapter_file 须 references/adapters/ 前缀单段 .md 名: " $3); next }
      if ($3 in seenf) { bad("adapter_file 跨行重复: " $3) } else { seenf[$3] = 1 }
      if ($3 != "references/adapters/" $1 ".md") { bad("adapter_file 须与 platform 同名（references/adapters/<platform>.md 基线）: " $3); next }
      m2 = split($4, ca, ",")
      if (m2 < 1) { bad("capability_coverage 空"); next }
      for (j = 1; j <= m2; j++) {
        if (ca[j] !~ /^[a-z][a-z0-9-]*$/) { bad("capability_coverage 含非法基元名（须小写 token 逗号分隔）: " ca[j]); next }
        if (!(ca[j] in cap)) { bad("capability_coverage 基元名不在 capability-primitives 名单: " ca[j]); next }
      }
      if ($5 !~ /^[a-z][a-z0-9-]*$/) { bad("role_mapping 须小写 token: " $5); next }
      if ($6 !~ /^[a-z][a-z0-9-]*$/) { bad("evidence_status 须小写 token: " $6); next }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_adapters") || true
  pm_report "$_pvar_bad"
}

pm_v_adapter_diff_cap() {
  # capability-map 节行形态＋跨节引用（平台∈注册表、基元∈名单、readonly 等级∈词表）
  # ＋每平台基元集合 ↔ 注册表 coverage 双向全等收尾
  _pvdc_adplats=$(LC_ALL=C awk -F'\t' '{ if (n++) printf ","; printf "%s", $1 }' "$pm_adapters")
  _pvdc_capnames=$(LC_ALL=C awk -F'\t' '{ printf "%s%s", (NR > 1 ? "," : ""), $1 }' "$pm_caps")
  _pvdc_bad=$(LC_ALL=C awk -F'\t' -v adplats="$_pvdc_adplats" -v capnames="$_pvdc_capnames" '
    function bad(msg) { printf "adapter-diffs capability-map 节第 %d 行: %s\n", FNR, msg; n++ }
    BEGIN { m = split(adplats, a, ","); for (i = 1; i <= m; i++) ap[a[i]] = 1; cm = split(capnames, b, ","); for (i = 1; i <= cm; i++) cap[b[i]] = 1 }
    NR == FNR { ev[$1] = 1; next }
    {
      if (NF != 4) { bad("字段数 " NF "（预期 4：platform、primitive、tool、constraint）"); next }
      if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("platform 须小写 token: " $1); next }
      if (!($1 in ap)) { bad("platform 不在 adapter-registry 节注册平台集: " $1); next }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("primitive 须小写 token: " $2); next }
      if (!($2 in cap)) { bad("primitive 不在 capability-primitives 节名单: " $2); next }
      key = $1 "\t" $2
      if (key in seen) { bad("（platform, primitive）跨行重复: " $1 " " $2) } else { seen[key] = 1 }
      if ($3 == "" || $4 == "") { bad("tool/constraint 不得为空"); next }
      if ($2 == "readonly-execute") {
        li = index($4, "readonly_enforcement:")
        if (li == 0) { bad("readonly-execute 行 constraint 缺 readonly_enforcement: 等级声明"); next }
        rest = substr($4, li + 21)
        sub(/^[[:space:]]+/, "", rest)
        if (match(rest, /[a-z][a-z-]*/)) {
          lv = substr(rest, RSTART, RLENGTH)
          if (!(lv in ev)) bad("readonly-execute 行等级不在 enforcement-levels 词表: " lv)
        } else {
          bad("readonly-execute 行 constraint 缺 readonly_enforcement: 等级声明")
        }
      }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_enfvocab" "$pm_adcap") || true
  pm_report_data "$_pvdc_bad" "$pm_adrules" '适配差异数据表'
  _pvdc_dat=$(LC_ALL=C awk -F'\t' '{ print $1 "\t" $2 }' "$pm_adcap" | LC_ALL=C sort)
  _pvdc_reg=$(LC_ALL=C awk -F'\t' '{ m = split($4, ca, ","); for (j = 1; j <= m; j++) print $1 "\t" ca[j] }' "$pm_adapters" | LC_ALL=C sort)
  if [ "$_pvdc_dat" != "$_pvdc_reg" ]; then
    pm_report_data '每平台能力基元集合与 adapter-registry 节 coverage 字段须双向全等（capability-map 节 ↔ 注册表漂移）' "$pm_adrules" '适配差异数据表'
  fi
}

pm_v_adapter_diff_role() {
  _pvdr_adplats=$(LC_ALL=C awk -F'\t' '{ if (n++) printf ","; printf "%s", $1 }' "$pm_adapters")
  _pvdr_bad=$(LC_ALL=C awk -F'\t' -v adplats="$_pvdr_adplats" '
    function bad(msg) { printf "adapter-diffs role-map 节第 %d 行: %s\n", FNR, msg; n++ }
    BEGIN { m = split(adplats, a, ","); for (i = 1; i <= m; i++) ap[a[i]] = 1 }
    {
      if (NF != 4) { bad("字段数 " NF "（预期 4：platform、role、capabilities、tools）"); next }
      if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("platform 须小写 token: " $1); next }
      if (!($1 in ap)) { bad("platform 不在 adapter-registry 节注册平台集: " $1); next }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("role 须小写 token: " $2); next }
      if ($3 == "" || $4 == "") { bad("capabilities/tools 不得为空"); next }
      key = $1 "\t" $2
      if (key in seen) { bad("（platform, role）跨行重复: " $1 " " $2) } else { seen[key] = 1 }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_adrole") || true
  pm_report_data "$_pvdr_bad" "$pm_adrules" '适配差异数据表'
}

pm_v_adapter_diff_exec() {
  _pvde_adplats=$(LC_ALL=C awk -F'\t' '{ if (n++) printf ","; printf "%s", $1 }' "$pm_adapters")
  _pvde_bad=$(LC_ALL=C awk -F'\t' -v adplats="$_pvde_adplats" '
    function bad(msg) { printf "adapter-diffs executor-status 节第 %d 行: %s\n", FNR, msg; n++ }
    BEGIN { m = split(adplats, a, ","); for (i = 1; i <= m; i++) ap[a[i]] = 1 }
    {
      if (NF != 3) { bad("字段数 " NF "（预期 3：platform、status、anchor）"); next }
      if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("platform 须小写 token: " $1); next }
      if (!($1 in ap)) { bad("platform 不在 adapter-registry 节注册平台集: " $1); next }
      if ($1 in seenp) { bad("platform 跨行重复（每平台恰一行）: " $1) } else { seenp[$1] = 1 }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("status 须小写 token（语义单源＝本节登记）: " $2); next }
      if ($3 == "") { bad("anchor 不得为空"); next }
    }
    END {
      if (n == 0) {
        for (i = 1; i <= m; i++) {
          if (!(a[i] in seenp)) { printf "adapter-diffs executor-status 节: 缺平台行（每注册平台恰一行）: %s\n", a[i]; n++ }
        }
      }
      if (n > 0) exit 1
    }
  ' "$pm_adexec") || true
  pm_report_data "$_pvde_bad" "$pm_adrules" '适配差异数据表'
}

pm_v_adapter_diff_dialect() {
  _pvdd_adplats=$(LC_ALL=C awk -F'\t' '{ if (n++) printf ","; printf "%s", $1 }' "$pm_adapters")
  _pvdd_bad=$(LC_ALL=C awk -F'\t' -v adplats="$_pvdd_adplats" '
    function bad(msg) { printf "adapter-diffs dialect-signature 节第 %d 行: %s\n", FNR, msg; n++ }
    BEGIN { m = split(adplats, a, ","); for (i = 1; i <= m; i++) ap[a[i]] = 1 }
    {
      if (NF != 3) { bad("字段数 " NF "（预期 3：platform、key、anchor）"); next }
      if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("platform 须小写 token: " $1); next }
      if (!($1 in ap)) { bad("platform 不在 adapter-registry 节注册平台集: " $1); next }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("key 须小写 token（语义单源＝本节登记）: " $2); next }
      if ($3 == "") { bad("anchor 不得为空"); next }
      key = $1 "\t" $2
      seenp[$1] = 1
      if (key in seen) { bad("（platform, key）跨行重复: " $1 " " $2) } else { seen[key] = 1 }
    }
    END {
      if (n == 0) {
        for (i = 1; i <= m; i++) {
          if (!(a[i] in seenp)) { printf "adapter-diffs dialect-signature 节: 缺平台行（每注册平台至少一行）: %s\n", a[i]; n++ }
        }
      }
      if (n > 0) exit 1
    }
  ' "$pm_addial") || true
  pm_report_data "$_pvdd_bad" "$pm_adrules" '适配差异数据表'
}

pm_v_capability_target() {
  _pvct_bad=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "capability targets 行（%s）: %s\n", $1, msg; n++ }
    FNR == NR { caps[$1] = 1; next }
    {
      rowbad = 0
      if (NF != 3) { bad("字段数 " NF "（预期 3：目标路径、kind、预期名单）"); next }
      if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); rowbad = 1 }
      else if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); rowbad = 1 }
      else if ($1 in tseen) { bad("目标路径跨行重复: " $1); rowbad = 1 }
      else tseen[$1] = 1
      if ($2 != "decl" && $2 != "table") { bad("kind 须 decl（required_capabilities 声明行）或 table（能力基元对照表）: " $2); rowbad = 1 }
      if ($3 == "") { bad("预期名单为空"); rowbad = 1 }
      else {
        nname = split($3, arr, ",")
        for (k = 1; k <= nname; k++) {
          nm = arr[k]
          if (nm !~ /^[a-z][a-z0-9-]*$/) { bad("预期名单基元名形态不合预期: " nm); rowbad = 1 }
          else if (!(nm in caps)) { bad("预期名单含名单未登记基元: " nm); rowbad = 1 }
          else useen[nm] = 1
        }
      }
      if (!rowbad) ok++
    }
    END {
      for (c in caps) if (!(c in useen)) { printf "capability targets 并集缺名单基元 %s（名单与检查目标须互恰）\n", c; n++ }
      if (n > 0) exit 1
    }
  ' "$pm_caps" "$pm_captargets") || true
  pm_report "$_pvct_bad"
}

pm_v_enforcement_target() {
  _pvet_bad=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "enforcement targets 行（%s）: %s\n", $1, msg; n++ }
    FNR == NR { vocab[$1] = 1; next }
    {
      if (NF != 2) { bad("字段数 " NF "（预期 2：目标路径、预期等级）"); next }
      if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
      if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
      if ($1 in tseen) { bad("目标路径跨行重复: " $1); next }
      tseen[$1] = 1
      if (!($2 in vocab)) { bad("预期等级不在受控词表: " $2) }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_enfvocab" "$pm_enf") || true
  pm_report "$_pvet_bad"
}

pm_v_check_total() {
  _pvck_bad=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "check-registry 节第 %d 行: %s\n", FNR, msg; n++ }
    {
      if (NF != 1) { bad("字段数 " NF "（预期 1：编号上界）"); next }
      if ($1 !~ /^[1-9][0-9]*$/) { bad("编号上界须正整数: " $1) }
    }
    END { if (FNR != 1) bad("编号上界须恰一行（实际 " FNR " 行）"); if (n > 0) exit 1 }
  ' "$pm_checktotal") || true
  pm_report "$_pvck_bad"
  pm_check_total_n=$(cat "$pm_checktotal")
}

pm_v_check_retired() {
  _pvcrt_bad=$(LC_ALL=C awk -F'\t' -v total="$pm_check_total_n" '
    function bad(msg) { printf "check-registry 节第 %d 行: %s\n", FNR, msg; n++ }
    {
      if (NF != 1) { bad("字段数 " NF "（预期 1：退役号）"); next }
      if ($1 !~ /^[1-9][0-9]*$/) { bad("退役号须正整数: " $1); next }
      if ($1 + 0 > total) { bad("退役号超出编号上界: " $1); next }
      if ($1 in seen) { bad("退役号跨行重复: " $1) } else { seen[$1] = 1 }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_checkretired") || true
  pm_report "$_pvcrt_bad"
}

pm_v_check_rows() {
  _pvcr_bad=$(LC_ALL=C awk -F'\t' -v total="$pm_check_total_n" '
    function bad(msg) { printf "check-registry 节第 %d 行: %s\n", FNR, msg; n++ }
    {
      if (NF != 2) { bad("字段数 " NF "（预期 2：检查号、slug）"); next }
      if ($1 !~ /^[1-9][0-9]*$/) { bad("检查号须正整数: " $1); next }
      if ($1 + 0 > total) { bad("检查号超出编号上界: " $1); next }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("slug 须小写 token: " $2); next }
      if ($1 in seenid) { bad("检查号跨行重复: " $1) } else { seenid[$1] = 1 }
      if ($2 in seenslug) { bad("slug 跨行重复: " $2) } else { seenslug[$2] = 1 }
    }
    END { if (n > 0) exit 1 }
  ' "$pm_checks") || true
  pm_report "$_pvcr_bad"
}

# ============================================================
# 五、逐节校验驱动（schema 顺序即校验顺序；未选中的节不校验其数据面）
# ============================================================

pm_validate_sections() {
  while IFS='|' read -r _pvs_sec _pvs_label _pvs_nf _pvs_specs _pvs_uniq _pvs_dup \
    _pvs_flags _pvs_pmsg _pvs_deps _pvs_fn; do
    [ -n "$_pvs_sec" ] || continue
    chk_section_needed "$_pvs_sec" || continue
    _pvs_file="$pm_tmpdir/$_pvs_sec"
    case $_pvs_flags in
      *p*)
        if [ ! -s "$_pvs_file" ]; then
          case $_pvs_flags in
            *A*) pm_die_ad "$_pvs_pmsg" ;;
            *) pm_die "$_pvs_pmsg" ;;
          esac
        fi
        ;;
    esac
    if [ "$_pvs_fn" != "-" ] && [ -n "$_pvs_fn" ]; then
      "$_pvs_fn"
    else
      pm_validate_rows "$_pvs_sec" "$_pvs_label" "$_pvs_nf" "$_pvs_specs" "$_pvs_uniq" "$_pvs_dup"
    fi
  done < "$pm_tmpdir/schema-rows"
}
