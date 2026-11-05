#!/bin/sh
# Input: 待检包根目录（默认为本脚本所在目录的父目录）与两份数据文件——包清单数据文件
#        package-manifest.rules（与脚本同目录；入口文件/脚本必需件/模板清单/短码登记/
#        platform 枚举/模糊措辞词表与豁免/镜像脚本/能力基元名单与检查目标/规则索引执行
#        机制受控词表/平台适配注册表/退役能力面/工作流图与定位/readonly 声明面/README
#        契约指针各节唯一承载点）与适配差异数据表 references/adapters/adapter-diffs.rules
#        （包根相对落位；四节机器数据行，检查 27 数据源）。两份均为非执行式解析
#        （fail-closed）。
# Output: 三十七项包完整性检查的逐项 PASS/FAIL 行与结尾汇总（全部通过 exit 0，任一失败
#         exit 1；检查 13 仓根无镜像落位目录时静默跳过无输出行；检查 19 非 git 语境静默
#         跳过无输出行）。
# Pos: agent-up 公开包发布前核对工具（SPEC-06 §5 / R-06-004）；POSIX sh、只读检查、零网络依赖。

# 用法与检查项实现细节（含各例外登记）见同目录 README.md。
# 自命中规避：检查 3/4 的扫描范围包含本目录文件；下列敏感模式在脚本文本中以
# 字符串拼接或正则转义构造，运行时才拼成完整字面量，因此本目录文件不得直接
# 写出检查 3/4 的敏感字面量（见 README.md）。

# 路径常量区（票 111 波②批次 1/6）：治理路径字面量唯一收拢点；值＝原字面量，零翻值，
# 数据区外禁再写游离治理路径字面量（注释同）；正则内转义形态与检查 3/4 自命中规避
# 构造豁免（见头部注记与各检查内注记）。
# shellcheck disable=SC2034  # 跨件共享常量/状态（checks/*.sh 检查件消费、引擎分发面赋值），单文件视野误报
docs_dir='docs'
rules_dir='rules'
facts_dir='facts'
scripts_dir='scripts'
scripts_readme_rel='scripts/README.md'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob，展开文件清单时避免意外匹配

failures=0

# Worktree 检测函数（票 177）：git worktree 内 --git-dir ≠ --git-common-dir。
# 返回 0 表示在 worktree 内，返回 1 表示在主检出或非 git 环境。
is_worktree() {
  git -C "$pkg_root" rev-parse --git-dir >/dev/null 2>&1 || return 1
  _git_dir=$(git -C "$pkg_root" rev-parse --git-dir 2>/dev/null)
  _common_dir=$(git -C "$pkg_root" rev-parse --git-common-dir 2>/dev/null)
  # 规范化为绝对路径后再比较（避免相对/绝对路径字符串不等但语义相等的误判）
  case $_git_dir in
    /*) _git_dir_abs=$_git_dir ;;
    *) _git_dir_abs=$(cd "$pkg_root/$_git_dir" && pwd) ;;
  esac
  case $_common_dir in
    /*) _common_dir_abs=$_common_dir ;;
    *) _common_dir_abs=$(cd "$pkg_root/$_common_dir" && pwd) ;;
  esac
  [ "$_git_dir_abs" != "$_common_dir_abs" ]
}

pass() {
  printf 'PASS: %s %s\n' "$1" "$2" >> "$chk_out_buf"
  printf '%s\n' "$1" >> "$chk_emitted_ids"
}

fail() {
  # $1=编号 $2=描述 $3=详情（可多行；多行时逐行缩进两空格）
  _n=$1
  _desc=$2
  _detail=${3:-}
  case $_detail in
    *'
'*)
      printf 'FAIL: %s %s 详情：\n' "$_n" "$_desc" >> "$chk_out_buf"
      printf '%s\n' "$_detail" | sed 's/^/  /' >> "$chk_out_buf"
      ;;
    '')
      printf 'FAIL: %s %s\n' "$_n" "$_desc" >> "$chk_out_buf"
      ;;
    *)
      printf 'FAIL: %s %s — %s\n' "$_n" "$_desc" "$_detail" >> "$chk_out_buf"
      ;;
  esac
  printf '%s\n' "$_n" >> "$chk_emitted_ids"
  failures=$((failures + 1))
}

usage() {
  cat <<USAGE
用法: sh check-package.sh [package-root]
参数:
  package-root  待检包根目录（含 SKILL.md 的目录）；缺省时取本脚本所在目录的父目录。
退出码:
  0  ${n_total_checks} 项检查全部通过
  1  存在未通过项（逐项 FAIL 行见输出）
  2  用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等）
${n_total_checks} 项检查说明、例外登记与输出格式见同目录 README.md。
USAGE
}

header_window() {
  # 契约头检测窗口：首行为 --- 的文件取 frontmatter 结束后的 5 行；否则取文件前 5 行。
  # frontmatter 未闭合时窗口为空，契约头检查将失败（视为格式缺陷）。
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && !closed { if ($0 == "---") closed = 1; next }
    { n++; if (n <= 5) print }
  ' "$1"
}

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
# ---- 检查注册表上界派生（用法文本与汇总行同一来源）----
chk_registry_file="$script_dir/checks/registry.rules"
n_total_checks=''
if [ -f "$chk_registry_file" ]; then
  n_total_checks=$(LC_ALL=C awk '$1 == "chk_total" { print $2; exit }' "$chk_registry_file")
fi
n_total_checks=${n_total_checks:-37}
if [ $# -gt 1 ]; then
  printf 'check-package: 错误：至多接受一个参数\n' >&2
  usage >&2
  exit 2
fi
if [ $# -eq 1 ]; then
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
  esac
  pkg_root=$1
else
  pkg_root=$(CDPATH='' cd "$script_dir/.." && pwd)
fi
if [ ! -d "$pkg_root" ]; then
  printf 'check-package: 错误：包根目录不存在：%s\n' "$pkg_root" >&2
  exit 2
fi

# ---- 包清单数据加载（外置数据＋引擎零专名＋结构校验 fail-closed，票 57；先例
#      install.sh×install-policy.rules：数据文件与脚本同目录，缺文件/缺节/字段非法/
#      重复即 exit 2，不产生部分结论）----

TAB=$(printf '\t')
t_dir=${TMPDIR:-/tmp}
pm_entries=''
pm_scripts=''
pm_templates=''
pm_codes=''
pm_platforms=''
pm_words=''
pm_exempts=''
pm_mirrors=''
pm_caps=''
pm_capauth=''
pm_captargets=''
pm_mechs=''
pm_citeex=''
pm_layoutface=''
pm_layoutu=''
pm_layoutlf=''
pm_layoutce=''
pm_idxmech=''
pm_idxids=''
pm_parsed=''
pm_enf=''
pm_enfvocab=''
pm_adapters=''
pm_adcap=''
pm_adrole=''
pm_adexec=''
pm_addial=''
pm_retired=''
pm_retface=''
pm_legmark=''
pm_workflows=''
pm_wffixmark=''
pm_prodentries=''
pm_prodclaims=''
pm_tstatus=''
pm_rosites=''
pm_cptrs=''
pm_checks=''
pm_checktotal=''
pm_checkretired=''
chk_parsed=''
chk_rows=''
chk_retired=''
chk_total_rows=''
chk_out_buf=''
chk_state_desc=''
chk_state_skip=''
chk_state_problems=''
chk_state_stdout=''
chk_emitted_ids=''
pm_cleanup() {
  rm -f "$pm_entries" "$pm_scripts" "$pm_templates" "$pm_codes" "$pm_platforms" \
    "$pm_words" "$pm_exempts" "$pm_mirrors" "$pm_caps" "$pm_capauth" "$pm_captargets" \
    "$pm_mechs" "$pm_citeex" "$pm_layoutface" "$pm_layoutu" \
    "$pm_layoutlf" "$pm_layoutce" "$pm_idxmech" "$pm_idxids" "$pm_parsed" \
    "$pm_enf" "$pm_enfvocab" "$pm_adapters" \
    "$pm_adcap" "$pm_adrole" "$pm_adexec" "$pm_addial" \
    "$pm_retired" "$pm_retface" "$pm_legmark" "$pm_workflows" "$pm_wffixmark" \
    "$pm_prodentries" "$pm_prodclaims" "$pm_tstatus" "$pm_rosites" "$pm_cptrs" \
    "$pm_checks" "$pm_checktotal" "$pm_checkretired" \
    "$chk_parsed" "$chk_rows" "$chk_retired" "$chk_total_rows" \
    "$chk_out_buf" "$chk_state_desc" "$chk_state_skip" "$chk_state_problems" "$chk_state_stdout" \
    "$chk_emitted_ids" "$chk_emitted_ids.expected" "$chk_emitted_ids.actual"
}
trap pm_cleanup EXIT HUP INT TERM
pm_entries=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_scripts=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_templates=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_codes=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_platforms=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_words=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_exempts=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_mirrors=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_caps=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_capauth=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_captargets=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_mechs=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_citeex=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_layoutface=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_layoutu=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_layoutlf=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_layoutce=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_idxmech=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_idxids=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_parsed=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_enf=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_enfvocab=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_adapters=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_adcap=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_adrole=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_adexec=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_addial=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_retired=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_retface=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_legmark=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_workflows=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_wffixmark=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_prodentries=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_prodclaims=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_tstatus=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_rosites=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_cptrs=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
pm_checks=$(mktemp "$t_dir/pkgmanifest.XXXXXX")
pm_checktotal=$(mktemp "$t_dir/pkgmanifest.XXXXXX")
pm_checkretired=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
chk_out_buf=$(mktemp "${t_dir%/}/chkresult.XXXXXX")
chk_state_desc=$(mktemp "${t_dir%/}/chkresult.XXXXXX")
chk_state_skip=$(mktemp "${t_dir%/}/chkresult.XXXXXX")
chk_state_problems=$(mktemp "${t_dir%/}/chkresult.XXXXXX")
chk_state_stdout=$(mktemp "${t_dir%/}/chkresult.XXXXXX")
chk_emitted_ids=$(mktemp "${t_dir%/}/chkresult.XXXXXX")

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
  # （适配差异数据表专用报告面，错误行文由各校验块自带节名前缀指名）。
  if [ -n "$1" ]; then
    printf 'check-package: 错误：%s不合预期（fail-closed，不产生部分结论）: %s\n' "$3" "$2" >&2
    printf '%s\n' "$1" >&2
    exit 2
  fi
}


pm_rules="$script_dir/package-manifest.rules"
if [ ! -f "$pm_rules" ]; then
  printf 'check-package: 错误：包清单数据文件缺失: %s\n' "$pm_rules" >&2
  exit 2
fi
# ---- 非执行式清单解析（票 145）：不再 source 清单——清单只作为受控文本数据解析，
# 未知指令、恶意 shell 片段与结构破坏统一 fail-closed exit 2，不产生部分结论。awk 逐
# 逻辑行处理「指令 参数...」——续行（行尾反斜杠）拼接、单引号词法取段（与 sh 单引号
# 字面量同语义：引号内零解释原样承载）、引号外空白分词；指令名与参数数由引擎核验
# （二十一指令各自参数数），未登记指令即 exit 2。解析在全部结构校验之前完成，恶意输入
# （命令替换、重定向、管道、字段污染）在执行任何检查语义前即被拒绝：引号外禁止 shell
# 语法元字符（` $ ( ) ; & | < >），引号内禁止命令替换形态（` 与 $( 与 ${）；解析期零
# 求值零二次展开（awk 产出的 TAB 行只经引擎逐节再分发），字段值只作数据承载。行内制
# 表符与 CR 为污染形态（字段边界唯一边界符＝解析器注入 TAB），直接拒绝。解析先落临时
# 文件、末尾按指令名原子分发到各节账本（all-or-nothing：解析失败零行落账）。
pm_parse_data() {
  # $1=数据文件（输入） $2=解析产物账本（覆盖写） $3=错误抬头文案（「包清单数据」／
  # 「适配差异数据表」） $4=（可选）字面反引号模式 1／0：差异数据表的强调记号（行内代码
  # 反引号）为惰性文本，须原样承载以支持生成器逐字节复现；清单侧保持默认 0（引号内
  # 反引号仍按命令替换形态拒绝，恶意输入门禁不放宽）。命令替换与参数展开形态两侧一律拒绝。
  pm_parse_bad=''
  LC_ALL=C awk -v progin="$1" -v allow_bt="${4:-0}" '
  function bad(msg) { printf "%s第 %d 逻辑行: %s\n", progin, ln, msg; n++ }
  {
    raw = $0; ln++
    gsub(/\r/, "", raw)
    while (raw ~ /\\$/) {
      raw = substr(raw, 1, length(raw) - 1)
      if ((getline nxt) <= 0) { bad("续行无后续物理行（行尾反斜杠悬空）"); next }
      ln++
      gsub(/\r/, "", nxt)
      raw = raw nxt
    }
    sub(/^[[:space:]]+/, "", raw)
    if (raw == "" || substr(raw, 1, 1) == "#") next
    out = ""; tok = ""; first = 1; inq = 0; inqseen = 0; nf = 0
    L = length(raw)
    for (i = 1; i <= L; i++) {
      c = substr(raw, i, 1)
      if (c == "\t") { bad("行内制表符（字段边界污染，TAB 为解析器注入唯一边界符）"); next }
      if (c == "'"'"'") { inq = 1 - inq; inqseen = 1; continue }
      if (!inq && c == " ") {
        if (tok != "" || inqseen) {
          if (first) { cmd = tok; first = 0 } else { out = out tok "\t"; nf++ }
          inqseen = 0
        }
        tok = ""
        continue
      }
      if (!inq && index("`$(;|<>&", c) > 0) { bad("引号外 shell 语法元字符（非执行式解析拒绝）: " c); next }
      if (inq && c == "`" && allow_bt != 1) { bad("引号内命令替换形态（反引号）——非执行式解析拒绝"); next }
      if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "(") { bad("引号内命令替换形态（美元括号）——非执行式解析拒绝"); next }
      if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "{") { bad("引号内参数展开形态（美元花括号）——非执行式解析拒绝"); next }
      tok = tok c
    }
    if (inq) { bad("单引号未闭合（词法破坏）"); next }
    if (tok != "" || inqseen) {
      if (first) { cmd = tok } else { out = out tok "\t"; nf++ }
      inqseen = 0
    }
    if (first) { bad("未知指令或非指令行（无参数）: " substr(raw, 1, 40)); next }
    ar = -1
    if (cmd == "pm_entry" || cmd == "pm_template" || cmd == "pm_platform" || cmd == "pm_capability" || cmd == "pm_capability_authority" || cmd == "pm_mechanism" || cmd == "pm_mechanism_marker" || cmd == "pm_vague_word" || cmd == "pm_layout_face" || cmd == "pm_enforcement_level" || cmd == "pm_retired_face" || cmd == "pm_legacy_marker" || cmd == "pm_ticket_status" || cmd == "pm_workflow_fixture_marker" || cmd == "pm_production_entry" || cmd == "pm_production_claim") ar = 1
    else if (cmd == "pm_shortcode" || cmd == "pm_mirror" || cmd == "pm_layout_universe" || cmd == "pm_layout_legacy_file" || cmd == "pm_enforcement_target" || cmd == "pm_retired_token" || cmd == "pm_workflow" || cmd == "pm_readonly_site") ar = 2
    else if (cmd == "pm_script" || cmd == "pm_vague_exempt" || cmd == "pm_cite_exempt" || cmd == "pm_capability_target" || cmd == "pm_layout_compat_exempt") ar = 3
    else if (cmd == "pm_adapter_exec" || cmd == "pm_adapter_dialect") ar = 3
    else if (cmd == "pm_adapter_cap" || cmd == "pm_adapter_role") ar = 4
    else if (cmd == "pm_contract_pointer") ar = 5
    else if (cmd == "pm_check") ar = 2
    else if (cmd == "pm_check_total" || cmd == "pm_check_retired") ar = 1
    else if (cmd == "chk") ar = 4
    else if (cmd == "chk_total" || cmd == "chk_retired") ar = 1
    else if (cmd == "pm_adapter") ar = 6
    if (ar < 0) { bad("未知指令或非指令行: " substr(raw, 1, 40)); next }
    if (nf != ar) { bad("参数数量不合预期（" cmd " 须恰 " ar " 个参数）: " nf); next }
    print cmd "\t" substr(out, 1, length(out) - 1)
  }
  END { if (n > 0) exit 1 }
  ' "$1" > "$2" || pm_parse_bad=1
  pm_parse_bad=${pm_parse_bad:-}
  if [ -n "$pm_parse_bad" ]; then
    printf 'check-package: 错误：%s非执行式解析不合预期（fail-closed，不产生部分结论）: %s\n' "$3" "$1" >&2
    return 1
  fi
  return 0
}
pm_parse_data "$pm_rules" "$pm_parsed" '包清单数据' || { rm -f "$pm_parsed"; pm_parsed=''; exit 2; }
pm_dispatch_file() {
  # $1=解析产物账本（指令\t参数 TAB 行），逐行按指令名原子分发到各节账本
  # （all-or-nothing：两份数据文件全部解析完成后才进入分发，账本零部分落账）。
  pm_dispatch_row=''
  pm_dispatch_cmd=''
  pm_dispatch_rest=''
  while IFS= read -r pm_dispatch_row; do
    pm_dispatch_cmd=${pm_dispatch_row%%"$TAB"*}
    pm_dispatch_rest=${pm_dispatch_row#*"$TAB"}
    case $pm_dispatch_cmd in
    pm_entry) printf '%s\n' "$pm_dispatch_rest" >> "$pm_entries" ;;
    pm_script) printf '%s\n' "$pm_dispatch_rest" >> "$pm_scripts" ;;
    pm_template) printf '%s\n' "$pm_dispatch_rest" >> "$pm_templates" ;;
    pm_shortcode) printf '%s\n' "$pm_dispatch_rest" >> "$pm_codes" ;;
    pm_platform) printf '%s\n' "$pm_dispatch_rest" >> "$pm_platforms" ;;
    pm_vague_word) printf '%s\n' "$pm_dispatch_rest" >> "$pm_words" ;;
    pm_vague_exempt) printf '%s\n' "$pm_dispatch_rest" >> "$pm_exempts" ;;
    pm_mirror) printf '%s\n' "$pm_dispatch_rest" >> "$pm_mirrors" ;;
    pm_capability) printf '%s\n' "$pm_dispatch_rest" >> "$pm_caps" ;;
    pm_capability_authority) printf '%s\n' "$pm_dispatch_rest" >> "$pm_capauth" ;;
    pm_capability_target) printf '%s\n' "$pm_dispatch_rest" >> "$pm_captargets" ;;
    pm_mechanism) printf '%s\n' "$pm_dispatch_rest" >> "$pm_mechs" ;;
    pm_cite_exempt) printf '%s\n' "$pm_dispatch_rest" >> "$pm_citeex" ;;
    pm_layout_face) printf '%s\n' "$pm_dispatch_rest" >> "$pm_layoutface" ;;
    pm_layout_universe) printf '%s\n' "$pm_dispatch_rest" >> "$pm_layoutu" ;;
    pm_layout_legacy_file) printf '%s\n' "$pm_dispatch_rest" >> "$pm_layoutlf" ;;
    pm_layout_compat_exempt) printf '%s\n' "$pm_dispatch_rest" >> "$pm_layoutce" ;;
    pm_enforcement_level) printf '%s\n' "$pm_dispatch_rest" >> "$pm_enfvocab" ;;
    pm_enforcement_target) printf '%s\n' "$pm_dispatch_rest" >> "$pm_enf" ;;
    pm_adapter) printf '%s\n' "$pm_dispatch_rest" >> "$pm_adapters" ;;
    pm_adapter_cap) printf '%s\n' "$pm_dispatch_rest" >> "$pm_adcap" ;;
    pm_adapter_role) printf '%s\n' "$pm_dispatch_rest" >> "$pm_adrole" ;;
    pm_adapter_exec) printf '%s\n' "$pm_dispatch_rest" >> "$pm_adexec" ;;
    pm_adapter_dialect) printf '%s\n' "$pm_dispatch_rest" >> "$pm_addial" ;;
    pm_retired_token) printf '%s\n' "$pm_dispatch_rest" >> "$pm_retired" ;;
    pm_retired_face) printf '%s\n' "$pm_dispatch_rest" >> "$pm_retface" ;;
    pm_legacy_marker) printf '%s\n' "$pm_dispatch_rest" >> "$pm_legmark" ;;
    pm_workflow) printf '%s\n' "$pm_dispatch_rest" >> "$pm_workflows" ;;
    pm_workflow_fixture_marker) printf '%s\n' "$pm_dispatch_rest" >> "$pm_wffixmark" ;;
    pm_production_entry) printf '%s\n' "$pm_dispatch_rest" >> "$pm_prodentries" ;;
    pm_production_claim) printf '%s\n' "$pm_dispatch_rest" >> "$pm_prodclaims" ;;
    pm_ticket_status) printf '%s\n' "$pm_dispatch_rest" >> "$pm_tstatus" ;;
    pm_readonly_site) printf '%s\n' "$pm_dispatch_rest" >> "$pm_rosites" ;;
    pm_contract_pointer) printf '%s\n' "$pm_dispatch_rest" >> "$pm_cptrs" ;;
    pm_check) printf '%s\n' "$pm_dispatch_rest" >> "$pm_checks" ;;
    pm_check_total) printf '%s\n' "$pm_dispatch_rest" >> "$pm_checktotal" ;;
    pm_check_retired) printf '%s\n' "$pm_dispatch_rest" >> "$pm_checkretired" ;;
  esac
  done < "$1"
}
pm_dispatch_file "$pm_parsed"
rm -f "$pm_parsed"; pm_parsed=''

# ---- 适配差异数据表加载（票 222）：包根相对落位（包侧唯一副本，无 pm_mirror 镜像
# 登记），与清单共用同一非执行式解析引擎与分发器；解析失败零行落账 exit 2。
pm_adrules="$pkg_root/references/adapters/adapter-diffs.rules"
pm_parsed=$(mktemp "${t_dir%/}/pkgmanifest.XXXXXX")
if [ ! -f "$pm_adrules" ]; then
  printf 'check-package: 错误：适配差异数据表缺失: %s\n' "$pm_adrules" >&2
  exit 2
fi
pm_parse_data "$pm_adrules" "$pm_parsed" '适配差异数据表' 1 || { rm -f "$pm_parsed"; pm_parsed=''; exit 2; }
pm_dispatch_file "$pm_parsed"
rm -f "$pm_parsed"; pm_parsed=''

[ -s "$pm_adcap" ] || pm_die_ad '差异数据表缺 capability-map 节（零行）'
[ -s "$pm_adrole" ] || pm_die_ad '差异数据表缺 role-map 节（零行）'
[ -s "$pm_adexec" ] || pm_die_ad '差异数据表缺 executor-status 节（零行）'
[ -s "$pm_addial" ] || pm_die_ad '差异数据表缺 dialect-signature 节（零行）'

[ -s "$pm_entries" ] || pm_die '清单缺 entry-files 节（零行）'
[ -s "$pm_scripts" ] || pm_die '清单缺 scripts 节（零行）'
[ -s "$pm_templates" ] || pm_die '清单缺 templates 节（零行）'
[ -s "$pm_codes" ] || pm_die '清单缺 shortcodes 节（零行）'
[ -s "$pm_platforms" ] || pm_die '清单缺 platform-enum 节（零行）'
[ -s "$pm_words" ] || pm_die '清单缺 vague-words 节（零行）'
[ -s "$pm_mirrors" ] || pm_die '清单缺 mirrors 节（零行）'
[ -s "$pm_caps" ] || pm_die '清单缺 capability-primitives 节（零行）'
[ -s "$pm_capauth" ] || pm_die '清单缺 capability authority 登记（零行）'
[ -s "$pm_captargets" ] || pm_die '清单缺 capability targets 登记（零行）'
[ -s "$pm_enfvocab" ] || pm_die '清单缺 enforcement 词表登记（零行）'
[ -s "$pm_enf" ] || pm_die '清单缺 enforcement targets 登记（零行）'
[ -s "$pm_mechs" ] || pm_die '清单缺 mechanism-vocab 节（零行）'
[ -s "$pm_layoutface" ] || pm_die '清单缺 layout-face 节（零行）'
[ -s "$pm_layoutu" ] || pm_die '清单缺 layout-universe 节（零行）'
[ -s "$pm_layoutlf" ] || pm_die '清单缺 layout-legacy-file 节（零行）'
[ -s "$pm_adapters" ] || pm_die '清单缺 adapter-registry 节（零行）'
[ -s "$pm_retired" ] || pm_die '清单缺 retired-path 节退役 token 登记（零行）'
[ -s "$pm_retface" ] || pm_die '清单缺 retired-path 节活动面登记（零行）'
[ -s "$pm_legmark" ] || pm_die '清单缺 retired-path 节 legacy 标注词登记（零行）'
[ -s "$pm_workflows" ] || pm_die '清单缺 workflow-graph 节工作流登记（零行）'
[ -s "$pm_wffixmark" ] || pm_die '清单缺 workflow-positioning 节 fixture 标记词登记（零行）'
[ -s "$pm_prodentries" ] || pm_die '清单缺 workflow-positioning 节生产入口登记（零行）'
[ -s "$pm_prodclaims" ] || pm_die '清单缺 workflow-positioning 节生产可执行声称词登记（零行）'
[ -s "$pm_tstatus" ] || pm_die '清单缺 workflow-graph 节票状态词表登记（零行）'
[ -s "$pm_rosites" ] || pm_die '清单缺 readonly-sites 节声明面登记（零行）'
[ -s "$pm_cptrs" ] || pm_die '清单缺 contract-pointers 节 README 契约指针登记（零行）'
[ -s "$pm_checks" ] || pm_die '清单缺 check-registry 节检查登记（零行）'
[ -s "$pm_checktotal" ] || pm_die '清单缺 check-registry 节编号上界（零行）'

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "entry-files 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($1 in seen) { bad("路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_entries") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "scripts 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 3) { bad("字段数 " NF "（预期 3：路径、kind、说明）"); next }
    if ($1 !~ /^scripts\/[A-Za-z0-9][A-Za-z0-9._-]*$/) { bad("路径须 scripts/ 前缀加单段文件名（禁 .. 与斜杠入名）: " $1); next }
    if ($2 !~ /^(script|rules|test-harness|dir)$/) { bad("kind 不合预期（script|rules|test-harness|dir）: " $2); next }
    if ($3 == "") { bad("缺说明"); next }
    if ($1 in seen) { bad("路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_scripts") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "templates 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*\.tmpl$/) { bad("须为单段 .tmpl 文件名: " $1); next }
    if ($1 in seen) { bad("文件名跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_templates") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "shortcodes 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：短码、所属文件）"); next }
    if ($1 !~ /^[A-Z][A-Z]$/) { bad("短码须两字母大写: " $1); next }
    if ($2 !~ /^references\/[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("所属文件须 references/ 前缀包内相对路径: " $2); next }
    if ($2 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $2); next }
    # 判重口径＝「短码+所属文件」对：一短码允许多行 owner 登记多件所属（流程权威拆三，
    # DP 一码对应 rules 三件模板），同对重复才违规。
    key = $1 "\t" $2
    if (key in seen) { bad("短码与所属文件对跨行重复: " $1 " " $2) } else { seen[key] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_codes") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "platform-enum 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("枚举值须小写 token（字母开头，小写字母/数字/连字符）: " $1); next }
    if ($1 in seen) { bad("枚举值跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_platforms") || true
pm_report "$pm_bad"

# adapter-registry 节结构校验（检查 26 数据面；coverage ⊆ 基元名单与 platform ∈ 枚举
# 宿主值需 pm_caps／pm_platforms 账本，分发循环已完结，账本齐备）。
# platform/shortcode/adapter_file 跨行唯一；platform ∈ platform-enum 节宿主值
# （去 neutral——平台无关不入注册表；检查段 ① 只补枚举宿主值缺注册行方向）；
# adapter_file 须 references/adapters/<platform>.md 同名单段名（adapter-template.md
# 基线：文件名与枚举值一致）；coverage 逐名 ⊆ pm_capability 名单；
# role_mapping/evidence_status 须小写 token（两值语义单源＝本节登记，引擎零词表硬编码）。
pm_capnames=$(LC_ALL=C awk -F'\t' '{ printf "%s%s", (NR > 1 ? "," : ""), $1 }' "$pm_caps")
pm_hostplat=$(LC_ALL=C awk -F'\t' '$1 != "neutral" { if (n++) printf ","; printf "%s", $1 }' "$pm_platforms")
pm_bad=$(LC_ALL=C awk -F'\t' -v capnames="$pm_capnames" -v hostplat="$pm_hostplat" '
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
pm_report "$pm_bad"

# adapter-diffs 数据表结构校验（检查 27 数据面；票 222；需 pm_adapters／pm_caps／
# pm_enfvocab 账本，两份数据文件分发已完结）。四节字段数、token 形态、跨行唯一、
# platform ∈ 注册表平台集、primitive ⊆ 基元名单、readonly-execute 行等级 ∈
# enforcement 词表 fail-closed；每平台基元集合 ↔ 注册表 coverage 双向全等收尾。
pm_adplats=$(LC_ALL=C awk -F'\t' '{ if (n++) printf ","; printf "%s", $1 }' "$pm_adapters")
pm_bad=$(LC_ALL=C awk -F'\t' -v adplats="$pm_adplats" -v capnames="$pm_capnames" '
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
pm_report_data "$pm_bad" "$pm_adrules" '适配差异数据表'

pm_bad=$(LC_ALL=C awk -F'\t' -v adplats="$pm_adplats" '
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
pm_report_data "$pm_bad" "$pm_adrules" '适配差异数据表'

pm_bad=$(LC_ALL=C awk -F'\t' -v adplats="$pm_adplats" '
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
pm_report_data "$pm_bad" "$pm_adrules" '适配差异数据表'

pm_bad=$(LC_ALL=C awk -F'\t' -v adplats="$pm_adplats" '
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
pm_report_data "$pm_bad" "$pm_adrules" '适配差异数据表'

# 每平台 cap 基元集合 ↔ adapter-registry 节 coverage 字段双向全等（fail-closed 收尾）。
pm_adcov_dat=$(LC_ALL=C awk -F'\t' '{ print $1 "\t" $2 }' "$pm_adcap" | LC_ALL=C sort)
pm_adcov_reg=$(LC_ALL=C awk -F'\t' '{ m = split($4, ca, ","); for (j = 1; j <= m; j++) print $1 "\t" ca[j] }' "$pm_adapters" | LC_ALL=C sort)
if [ "$pm_adcov_dat" != "$pm_adcov_reg" ]; then
  pm_report_data '每平台能力基元集合与 adapter-registry 节 coverage 字段须双向全等（capability-map 节 ↔ 注册表漂移）' "$pm_adrules" '适配差异数据表'
fi

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "vague-words 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 == "") { bad("词为空"); next }
    if ($1 ~ /[[:space:]]/) { bad("词含空白（字面匹配非正则，空白词无法定位）: " $1); next }
    if ($1 in seen) { bad("词跨行重复") } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_words") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "vague-exemptions 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 3) { bad("字段数 " NF "（预期 3：路径、行号、理由）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 !~ /^[0-9]+$/ || $2 + 0 <= 0) { bad("行号须正整数: " $2); next }
    if ($3 == "") { bad("缺理由（行级豁免须注记理由）"); next }
    key = $1 "\t" $2
    if (key in seen) { bad("路径+行号跨行重复: " $1 ":" $2) } else { seen[key] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_exempts") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "mirrors 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：文件名、所有权类别）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) { bad("须为单段文件名: " $1); next }
    if ($2 != "mirror" && $2 != "package-only" && $2 != "repo-only") { bad("所有权类别不合预期（mirror|package-only|repo-only）: " $2); next }
    if ($1 in seen) { bad("文件名跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_mirrors") || true
pm_report "$pm_bad"

# 票号禁令豁免节结构校验（检查 18；节可空＝当前全免费交付，区别于其余非空下限节）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "ticket-citation-ban 豁免节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 3) { bad("字段数 " NF "（预期 3：路径、行号、理由）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 !~ /^[0-9]+$/ || $2 + 0 <= 0) { bad("行号须正整数: " $2); next }
    if ($3 == "") { bad("缺理由（行级豁免须注记理由）"); next }
    key = $1 "\t" $2
    if (key in seen) { bad("路径+行号跨行重复: " $1 ":" $2) } else { seen[key] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_citeex") || true
pm_report "$pm_bad"

# 布局引用分类四节结构校验（检查 24；face/universe/legacy-file 三节非空下限，
# compat-exempt 可空＝显式兼容豁免零登记的合法形态，先例 ticket-citation-ban）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "layout-face 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($1 in seen) { bad("路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_layoutface") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "layout-universe 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：登记模板路径、提取锚点）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 !~ /^[A-Za-z0-9:_\/-]+$/) { bad("锚点须为受限字符集单 token（字母数字与冒号斜杠连字符下划线点）: " $2); next }
    if ($1 in seen) { bad("登记模板路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_layoutu") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "layout-legacy-file 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：路径、理由）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 == "") { bad("缺理由（整文件合法保留须注记理由）"); next }
    if ($1 in seen) { bad("路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_layoutlf") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "layout-compat-exempt 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 3) { bad("字段数 " NF "（预期 3：路径、行号、理由）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 !~ /^[0-9]+$/ || $2 + 0 <= 0) { bad("行号须正整数: " $2); next }
    if ($3 == "") { bad("缺理由（兼容豁免须注记理由）"); next }
    key = $1 "\t" $2
    if (key in seen) { bad("路径+行号跨行重复: " $1 ":" $2) } else { seen[key] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_layoutce") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "capability-primitives 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("基元名须小写 token（字母开头，小写字母/数字/连字符）: " $1); next }
    if ($1 in seen) { bad("基元名跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_caps") || true
pm_report "$pm_bad"

[ "$(wc -l < "$pm_capauth" | tr -d ' ')" -eq 1 ] || pm_die 'capability authority 须恰一行'
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "capability authority 行: %s\n", msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
  }
  END { if (n > 0) exit 1 }
' "$pm_capauth") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
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
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "enforcement 词表行: %s\n", msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[a-z][a-z-]*$/) { bad("等级值须小写 token（小写字母/连字符）: " $1); next }
    if ($1 in seen) { bad("等级值跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_enfvocab") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
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
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "mechanism-vocab 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 == "") { bad("值为空"); next }
    if ($1 ~ /[[:space:]]/) { bad("值含空白（受控值须为单 token）: " $1); next }
    if ($1 in seen) { bad("值跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_mechs") || true
pm_report "$pm_bad"

# retired-path 三节结构校验（检查 29 数据面；token 须单 token、标注词非空、活动面
# 路径形态同入口面口径）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "retired-path 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：token、说明）"); next }
    if ($1 == "" || $1 ~ /[[:space:]]/) { bad("退役 token 须非空单 token: " $1); next }
    if ($2 == "") { bad("缺说明"); next }
    if ($1 in seen) { bad("token 跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_retired") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "retired-path 活动面第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($1 in seen) { bad("路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_retface") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "retired-path 标注词第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 == "" || $1 ~ /[[:space:]]/) { bad("ledger 标注词须非空单 token: " $1); next }
    if ($1 in seen) { bad("标注词跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_legmark") || true
pm_report "$pm_bad"

# workflow-graph / workflow-positioning 三节结构校验（检查 30/31/36 数据面）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "workflow-graph 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：工作流路径、定位）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 != "fixture" && $2 != "production") { bad("定位枚举不合预期（fixture|production）: " $2); next }
    if ($1 in seen) { bad("工作流路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_workflows") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "workflow-graph 票状态词表第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[a-z][a-z0-9_]*$/) { bad("票状态值须小写 token（小写字母/数字/下划线）: " $1); next }
    if ($1 in seen) { bad("票状态值跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_tstatus") || true
pm_report "$pm_bad"

[ "$(wc -l < "$pm_wffixmark" | tr -d ' ')" -eq 1 ] || pm_die 'workflow-positioning fixture 标记词须恰一行'
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "workflow-positioning fixture 标记词行: %s\n", msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 == "") { bad("标记词为空"); next }
  }
  END { if (n > 0) exit 1 }
' "$pm_wffixmark") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "workflow-positioning 生产入口第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("生产入口名须小写 token: " $1); next }
    if ($1 in seen) { bad("生产入口名跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_prodentries") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "workflow-positioning 生产可执行声称词第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 == "" || $1 ~ /[[:space:]]/) { bad("声称词须非空单 token: " $1); next }
    if ($1 in seen) { bad("声称词跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_prodclaims") || true
pm_report "$pm_bad"

# readonly-sites 结构校验（检查 32 数据面；mode 枚举三值、路径跨行唯一）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "readonly-sites 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 2) { bad("字段数 " NF "（预期 2：声明面路径、模式）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("路径不合预期（禁前导斜杠、空白与特殊字符）: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " $1); next }
    if ($2 != "authority" && $2 != "level" && $2 != "reference") { bad("模式枚举不合预期（authority|level|reference）: " $2); next }
    if ($1 in seen) { bad("声明面路径跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_rosites") || true
pm_report "$pm_bad"

# contract-pointers 结构校验（检查 34 数据面；五字段，readme+锚点 对跨行唯一）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "contract-pointers 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 5) { bad("字段数 " NF "（预期 5：README 路径、锚点、指针原文、权威文件、权威锚点）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("README 路径不合预期: " $1); next }
    if ($1 ~ /(^|\/)\.\.(\/|$)/) { bad("README 路径含 .. 段: " $1); next }
    if ($2 == "") { bad("锚点为空"); next }
    if ($3 == "") { bad("指针原文为空"); next }
    if ($4 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) { bad("权威文件路径不合预期: " $4); next }
    if ($4 ~ /(^|\/)\.\.(\/|$)/) { bad("权威文件路径含 .. 段: " $4); next }
    if ($5 == "") { bad("权威锚点为空"); next }
    key = $1 "\t" $2
    if (key in seen) { bad("README+锚点 对跨行重复: " $1 " " $2) } else { seen[key] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_cptrs") || true
pm_report "$pm_bad"

# check-registry 节结构校验（检查注册表登记面；编号上界恰一行正整数，退役号与在役行跨行唯一）。
pm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "check-registry 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1：编号上界）"); next }
    if ($1 !~ /^[1-9][0-9]*$/) { bad("编号上界须正整数: " $1) }
  }
  END { if (FNR != 1) bad("编号上界须恰一行（实际 " FNR " 行）"); if (n > 0) exit 1 }
' "$pm_checktotal") || true
pm_report "$pm_bad"

pm_check_total_n=$(cat "$pm_checktotal")
pm_bad=$(LC_ALL=C awk -F'\t' -v total="$pm_check_total_n" '
  function bad(msg) { printf "check-registry 节第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 1) { bad("字段数 " NF "（预期 1：退役号）"); next }
    if ($1 !~ /^[1-9][0-9]*$/) { bad("退役号须正整数: " $1); next }
    if ($1 + 0 > total) { bad("退役号超出编号上界: " $1); next }
    if ($1 in seen) { bad("退役号跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_checkretired") || true
pm_report "$pm_bad"

pm_bad=$(LC_ALL=C awk -F'\t' -v total="$pm_check_total_n" '
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
pm_report "$pm_bad"

# 问题行累加器（单行；多行由 fail() 走详情块缩进排版）
problems=''
add_problem() {
  if [ -n "$problems" ]; then
    problems="$problems
"
  fi
  problems="$problems$1"
}


# ---- 共享派生：worktree 环境识别与 main-only 清单（检查 8/9 共用；注册表分发前一次计算）----
# 票 177：worktree 内 delivery.rules dp_mainonly 清单的脚本不检查存在性。
mainonly_list=''
in_worktree=0
if is_worktree; then
  # 获取主仓库工作树根目录（通过 git-common-dir 向上追溯到工作树根）
  _common_dir=$(git -C "$pkg_root" rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$_common_dir" ]; then
    # git-common-dir 返回 .git 目录，需要向上一级到工作树根
    case $_common_dir in
      /*) _repo_root=$(dirname "$_common_dir") ;;
      *) _repo_root=$(cd "$pkg_root/$_common_dir/.." && pwd) ;;
    esac
    if [ -f "$_repo_root/delivery.rules" ]; then
      # 解析 delivery.rules dp_mainonly 指令（格式：dp_mainonly <路径>，取第二字段）
      mainonly_list=$(LC_ALL=C awk '/^dp_mainonly / { print $2 }' "$_repo_root/delivery.rules")
      if [ -n "$mainonly_list" ]; then
        in_worktree=1
      fi
    fi
  fi
fi

# ---- 共享只读派生量（引擎分发前初始化并显式传入；检查件之间零隐式状态）----
chk_dir="$script_dir/checks"
file_list=$(find "$pkg_root" -type f \( -name '*.md' -o -name '*.tmpl' \) | sort)
idx_file="$pkg_root/references/rules-index.md"
# shellcheck disable=SC1090,SC1091  # 共享检查件辅助函数路径由脚本目录推导（静态视野不可跟随）
. "$chk_dir/shared.sh"

# ============================================================
# 检查注册表加载、完整性断言与统一分发
# ============================================================
chk_dir="$script_dir/checks"
chk_parsed=$(mktemp "${t_dir%/}/chkregistry.XXXXXX")
chk_rows=$(mktemp "${t_dir%/}/chkregistry.XXXXXX")
chk_retired=$(mktemp "${t_dir%/}/chkregistry.XXXXXX")
chk_total_rows=$(mktemp "${t_dir%/}/chkregistry.XXXXXX")
pm_parse_data "$chk_registry_file" "$chk_parsed" '检查注册表' || { rm -f "$chk_parsed"; chk_parsed=''; exit 2; }
chk_bad_field=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "检查注册表第 %d 行: %s\n", FNR, msg; n++ }
  $1 == "chk_total" { if (NF != 2) bad("chk_total 字段数 " NF "（预期 2）"); next }
  $1 == "chk_retired" { if (NF != 2) bad("chk_retired 字段数 " NF "（预期 2）"); next }
  $1 == "chk" {
    if (NF != 5) { bad("chk 字段数 " NF "（预期 5：号、slug、件、必需数据节）"); next }
    if ($2 !~ /^[1-9][0-9]*$/) bad("检查号须正整数: " $2)
    if ($3 !~ /^[a-z][a-z0-9-]*$/) bad("slug 须小写 token: " $3)
    if ($4 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) bad("检查件须为单段 *.sh 文件名: " $4)
  }
  END { if (n > 0) exit 1 }
' "$chk_parsed") || true
if [ -n "$chk_bad_field" ]; then
  printf 'check-package: 错误：检查注册表结构不合预期（fail-closed，不产生部分结论）: %s\n%s\n' "$chk_registry_file" "$chk_bad_field" >&2
  exit 2
fi
while IFS= read -r chk_row; do
  chk_cmd=${chk_row%%"$TAB"*}
  chk_rest=${chk_row#*"$TAB"}
  case $chk_cmd in
    chk_total) printf '%s\n' "$chk_rest" >> "$chk_total_rows" ;;
    chk_retired) printf '%s\n' "$chk_rest" >> "$chk_retired" ;;
    chk) printf '%s\n' "$chk_rest" >> "$chk_rows" ;;
  esac
done < "$chk_parsed"
rm -f "$chk_parsed"; chk_parsed=''

chk_load_bad=''
chk_load_report() {
  chk_load_bad="$chk_load_bad$1
"
}
chk_total_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_total_rows")
if [ "$chk_total_reg_n" -ne 1 ]; then
  chk_load_report "  - 注册表 chk_total 须恰一行（实际 ${chk_total_reg_n} 行）"
fi
chk_total_reg=$(head -n 1 "$chk_total_rows")
if ! printf '%s\n' "$chk_total_reg" | LC_ALL=C grep -qE '^[1-9][0-9]*$'; then
  chk_load_report "  - 注册表 chk_total 须正整数: ${chk_total_reg:-<空>}"
fi
if [ "$chk_total_reg" != "$pm_check_total_n" ]; then
  chk_load_report "  - 注册表 chk_total 与清单 check-registry 编号上界不一致: $chk_total_reg ≠ $pm_check_total_n"
fi
chk_bad_reg=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "  - 注册表第 %d 行: %s\n", FNR, msg; n++ }
  {
    if (NF != 4) { bad("字段数 " NF "（预期 4）"); next }
    if ($1 !~ /^[1-9][0-9]*$/) { bad("检查号须正整数: " $1); next }
    if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("slug 须小写 token: " $2); next }
    if ($3 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) { bad("检查件须为单段 *.sh 文件名: " $3); next }
    if ($4 != "-" && $4 !~ /^[a-z_]+(,[a-z_]+)*$/) { bad("必需数据节形态不合预期: " $4); next }
    if ($1 in seenid) { bad("检查号跨行重复: " $1) } else { seenid[$1] = 1 }
    if ($2 in seenslug) { bad("slug 跨行重复: " $2) } else { seenslug[$2] = 1 }
    if ($3 in seenfile) { bad("检查件跨行重复: " $3) } else { seenfile[$3] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$chk_rows") || true
if [ -n "$chk_bad_reg" ]; then
  chk_load_bad="$chk_load_bad$chk_bad_reg
"
fi
chk_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_rows")
chk_man_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_checks")
chk_ret_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_checkretired")
chk_ret_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_retired")
chk_exp_n=$((chk_total_reg - chk_ret_n))
if [ "$chk_reg_n" -ne "$chk_man_n" ] || [ "$chk_reg_n" -ne "$chk_exp_n" ]; then
  chk_load_report "  - 注册项数不一致：注册表 ${chk_reg_n}／清单 ${chk_man_n}／上界−退役 $chk_exp_n"
fi
if [ "$chk_ret_reg_n" -ne "$chk_ret_n" ]; then
  chk_load_report "  - 退役号行数不一致：注册表 ${chk_ret_reg_n}／清单 $chk_ret_n"
fi
chk_ids=$(LC_ALL=C awk -F'\t' 'NF { print $1 }' "$chk_rows" | LC_ALL=C sort -n)
chk_man_ids=$(LC_ALL=C awk -F'\t' 'NF { print $1 }' "$pm_checks" | LC_ALL=C sort -n)
chk_ret_ids=$(LC_ALL=C awk 'NF { print $1 }' "$pm_checkretired" | LC_ALL=C sort -n)
chk_ret_reg_ids=$(LC_ALL=C awk 'NF { print $1 }' "$chk_retired" | LC_ALL=C sort -n)
if [ "$chk_ids" != "$chk_man_ids" ]; then
  chk_load_report '  - 注册表在役检查号集合与清单 check-registry 不一致'
fi
if [ "$chk_ret_ids" != "$chk_ret_reg_ids" ]; then
  chk_load_report '  - 注册表退役号集合与清单 check-registry 不一致'
fi
chk_pairs=$(LC_ALL=C awk -F'\t' 'NF { print $1 "\t" $2 }' "$chk_rows" | LC_ALL=C sort -n)
chk_man_pairs=$(LC_ALL=C awk -F'\t' 'NF { print $1 "\t" $2 }' "$pm_checks" | LC_ALL=C sort -n)
if [ "$chk_pairs" != "$chk_man_pairs" ]; then
  chk_load_report '  - 注册表（检查号, slug）对与清单 check-registry 不一致'
fi
chk_union=$(printf '%s\n%s\n' "$chk_ids" "$chk_ret_ids" | LC_ALL=C awk 'NF { print $1 }' | LC_ALL=C sort -n | LC_ALL=C uniq)
chk_gap=$(printf '%s\n' "$chk_union" | LC_ALL=C awk -v total="$chk_total_reg" '
  BEGIN { for (i = 1; i <= total; i++) want[i] = 1 }
  NF { have[$1] = 1 }
  END { for (i = 1; i <= total; i++) if (!(i in have)) print i }
')
if [ -n "$chk_gap" ]; then
  chk_load_report "  - 编号连续性与退役声明不一致（缺失号）: $(printf '%s' "$chk_gap" | tr '\n' ' ')"
fi
chk_src_list=''
while IFS="$(printf '\t')" read -r chk_n chk_slug chk_file chk_required; do
  [ -n "$chk_n" ] || continue
  if [ ! -f "$chk_dir/$chk_file" ]; then
    chk_load_report "  - 检查件不存在: checks/${chk_file}（检查 ${chk_n}）"
    continue
  fi
  if [ "$chk_required" != "-" ]; then
    for chk_req in $(printf '%s' "$chk_required" | tr ',' ' '); do
      # shellcheck disable=SC2194  # 常量词表（清单指令名白名单）刻意字面，非变量遗漏
      case " pm_entry pm_script pm_template pm_shortcode pm_platform pm_vague_word pm_vague_exempt pm_mirror pm_capability pm_capability_authority pm_capability_target pm_mechanism pm_cite_exempt pm_layout_face pm_layout_universe pm_layout_legacy_file pm_layout_compat_exempt pm_enforcement_level pm_enforcement_target pm_adapter pm_adapter_cap pm_adapter_role pm_adapter_exec pm_adapter_dialect pm_retired_token pm_retired_face pm_legacy_marker pm_workflow pm_workflow_fixture_marker pm_production_entry pm_production_claim pm_ticket_status pm_readonly_site pm_contract_pointer " in
        *" $chk_req "*) ;;
        *) chk_load_report "  - 必需数据节未登记: ${chk_req}（检查 ${chk_n}）" ;;
      esac
    done
  fi
  chk_src_list="$chk_src_list$chk_dir/$chk_file
"
done <<EOF
$(LC_ALL=C sort -n -t"$(printf '\t')" -k1,1n "$chk_rows")
EOF
while IFS= read -r chk_fn_path; do
  [ -n "$chk_fn_path" ] || continue
  # shellcheck disable=SC1090  # 检查件路径由注册表现算（动态发现），静态视野不可跟随
  . "$chk_fn_path" || { chk_load_report "  - 检查件载入失败: $chk_fn_path"; continue; }
done <<EOF
$chk_src_list
EOF
chk_missing_fn=''
while IFS= read -r chk_n; do
  [ -n "$chk_n" ] || continue
  if ! command -v "check_$chk_n" >/dev/null 2>&1; then
    chk_missing_fn="$chk_missing_fn check_$chk_n"
  fi
done <<EOF
$chk_ids
EOF
if [ -n "$chk_missing_fn" ]; then
  chk_load_report "  - 检查件未定义统一 interface 函数:$chk_missing_fn"
fi
if [ -n "$chk_load_bad" ]; then
  printf 'check-package: 错误：检查注册表完整性断言未通过（fail-closed，不产生部分结论）:\n%s' "$chk_load_bad" >&2
  exit 2
fi
n_total_checks=$chk_total_reg


# ============================================================
# 统一分发：注册表顺序逐项调用检查件；引擎统一生成 PASS/FAIL/SKIP 行与汇总计数。
# 输出先缓冲、完整性守卫通过后一次性落 stdout：检查件崩溃/主动 exit 2/输出残缺一律
# fail-closed（stderr 指名，stdout 零残缺输出），杜绝 exit 0 的残缺包检。
# ============================================================
while IFS= read -r chk_n; do
  [ -n "$chk_n" ] || continue
  : > "$chk_state_desc"
  : > "$chk_state_skip"
  : > "$chk_state_problems"
  : > "$chk_state_stdout"
  chk_rc=0
  ( problems=''
    _chk_desc=''
    _chk_skip=''
    # 共享 scratch（引擎显式初始化后传入；检查件之间零隐式状态）
    sep=''
    sep2=''
    sep_a=''
    sep_e=''
    OLDIFS=$IFS
    "check_$chk_n" "$pkg_root"
    printf '%s' "$_chk_desc" > "$chk_state_desc"
    printf '%s' "$_chk_skip" > "$chk_state_skip"
    printf '%s' "$problems" > "$chk_state_problems"
  ) > "$chk_state_stdout" || chk_rc=$?
  if [ "$chk_rc" -eq 2 ]; then
    exit 2
  elif [ "$chk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 %s 执行异常中止（fail-closed，不产生部分结论）\n' "$chk_n" >&2
    exit 2
  fi
  if [ -s "$chk_state_stdout" ]; then
    printf 'check-package: 错误：检查 %s 直接写 stdout（违反检查件 interface：只判定与报告问题）\n' "$chk_n" >&2
    exit 2
  fi
  _chk_desc=$(cat "$chk_state_desc")
  _chk_skip=$(cat "$chk_state_skip")
  problems=$(cat "$chk_state_problems")
  if [ -n "$_chk_skip" ]; then
    printf 'SKIP: %s %s\n' "$chk_n" "$_chk_skip" >> "$chk_out_buf"
  fi
  if [ -n "$problems" ]; then
    if [ -z "$_chk_desc" ]; then
      printf 'check-package: 错误：检查 %s 未声明描述（检查件 interface 违约）\n' "$chk_n" >&2
      exit 2
    fi
    fail "$chk_n" "$_chk_desc" "$problems"
  elif [ -n "$_chk_desc" ]; then
    pass "$chk_n" "$_chk_desc"
  fi
done <<EOF
$chk_ids
EOF

# ---- 输出完整性守卫：实际输出号集合 == 注册表在役集合（扣除语境静默 13/19）----
chk_silent=''
chk_mirror_root=$(CDPATH='' cd -- "$pkg_root/.." 2>/dev/null && pwd) || chk_mirror_root=''
if [ -z "$chk_mirror_root" ] || { [ ! -d "$chk_mirror_root/scripts" ] && [ ! -d "$chk_mirror_root/rules/implementation/scripts" ]; }; then
  chk_silent="$chk_silent 13"
fi
if ! git -C "$pkg_root" rev-parse --git-dir >/dev/null 2>&1; then
  chk_silent="$chk_silent 19"
fi
chk_expected_ids=$(printf '%s\n' "$chk_ids" | LC_ALL=C awk -v sk="$chk_silent " 'BEGIN { n = split(sk, a, " "); for (i = 1; i <= n; i++) if (a[i] != "") s[a[i]] = 1 } !($0 in s)')
chk_actual_ids=$(LC_ALL=C sort -n "$chk_emitted_ids")
if [ "$chk_actual_ids" != "$chk_expected_ids" ]; then
  printf '%s\n' "$chk_expected_ids" > "$chk_emitted_ids.expected"
  printf '%s\n' "$chk_actual_ids" > "$chk_emitted_ids.actual"
  chk_missing=$(LC_ALL=C awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' "$chk_emitted_ids.actual" "$chk_emitted_ids.expected")
  chk_extra=$(LC_ALL=C awk 'NR == FNR { want[$0] = 1; next } !($0 in want)' "$chk_emitted_ids.expected" "$chk_emitted_ids.actual")
  chk_missing=$(printf '%s' "$chk_missing" | tr '\n' ' ')
  chk_extra=$(printf '%s' "$chk_extra" | tr '\n' ' ')
  printf 'check-package: 错误：检查输出不完整（fail-closed，不产生部分结论）：缺失号 [%s] 多余号 [%s]\n' "$chk_missing" "$chk_extra" >&2
  exit 2
fi
cat "$chk_out_buf"

if [ "$failures" -gt 0 ]; then
  printf 'check-package: FAIL（%s 项未通过，共 %s 项）\n' "$failures" "$n_total_checks"
  exit 1
fi
printf 'check-package: PASS\n'
