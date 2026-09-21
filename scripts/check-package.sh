#!/bin/sh
# Input: 待检包根目录（默认为本脚本所在目录的父目录）与包清单数据文件
#        package-manifest.rules（与脚本同目录；入口文件/脚本必需件/模板清单/短码登记/
#        platform 枚举/模糊措辞词表与豁免/镜像脚本八节唯一承载点，票 57/58）。
# Output: 十三项包完整性检查的逐项 PASS/FAIL 行与结尾汇总（全部通过 exit 0，任一失败 exit 1；
#         检查 13 仓根无镜像时静默跳过无输出行）。
# Pos: agent-up 公开包发布前核对工具（SPEC-06 §5 / R-06-004）；POSIX sh、只读检查、零网络依赖。

# 用法与检查项实现细节（含各例外登记）见同目录 README.md。
# 自命中规避：检查 3/4 的扫描范围包含本目录文件；下列敏感模式在脚本文本中以
# 字符串拼接或正则转义构造，运行时才拼成完整字面量，因此本目录文件不得直接
# 写出检查 3/4 的敏感字面量（见 README.md）。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob，展开文件清单时避免意外匹配

failures=0

pass() {
  printf 'PASS: %s %s\n' "$1" "$2"
}

fail() {
  # $1=编号 $2=描述 $3=详情（可多行；多行时逐行缩进两空格）
  _n=$1
  _desc=$2
  _detail=${3:-}
  case $_detail in
    *'
'*)
      printf 'FAIL: %s %s 详情：\n' "$_n" "$_desc"
      printf '%s\n' "$_detail" | sed 's/^/  /'
      ;;
    '')
      printf 'FAIL: %s %s\n' "$_n" "$_desc"
      ;;
    *)
      printf 'FAIL: %s %s — %s\n' "$_n" "$_desc" "$_detail"
      ;;
  esac
  failures=$((failures + 1))
}

usage() {
  cat <<'USAGE'
用法: sh check-package.sh [package-root]
参数:
  package-root  待检包根目录（含 SKILL.md 的目录）；缺省时取本脚本所在目录的父目录。
退出码:
  0  十三项检查全部通过
  1  存在未通过项（逐项 FAIL 行见输出）
  2  用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等）
十三项检查说明、例外登记与输出格式见同目录 README.md。
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

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
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
  pkg_root=$(CDPATH= cd "$script_dir/.." && pwd)
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
pm_cleanup() {
  rm -f "$pm_entries" "$pm_scripts" "$pm_templates" "$pm_codes" "$pm_platforms" \
    "$pm_words" "$pm_exempts" "$pm_mirrors"
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

pm_entry() {
  [ $# -eq 1 ] || pm_die 'pm_entry 行参数数量不合预期（须恰 1：包内相对路径）'
  printf '%s\n' "$1" >> "$pm_entries"
}
pm_script() {
  [ $# -eq 3 ] || pm_die 'pm_script 行参数数量不合预期（须恰 3：路径、kind、说明）'
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$pm_scripts"
}
pm_template() {
  [ $# -eq 1 ] || pm_die 'pm_template 行参数数量不合预期（须恰 1：模板文件名）'
  printf '%s\n' "$1" >> "$pm_templates"
}
pm_shortcode() {
  [ $# -eq 2 ] || pm_die 'pm_shortcode 行参数数量不合预期（须恰 2：短码、所属文件）'
  printf '%s\t%s\n' "$1" "$2" >> "$pm_codes"
}
pm_platform() {
  [ $# -eq 1 ] || pm_die 'pm_platform 行参数数量不合预期（须恰 1：枚举值）'
  printf '%s\n' "$1" >> "$pm_platforms"
}
pm_vague_word() {
  [ $# -eq 1 ] || pm_die 'pm_vague_word 行参数数量不合预期（须恰 1：模糊措辞词，字面匹配非正则）'
  printf '%s\n' "$1" >> "$pm_words"
}
pm_vague_exempt() {
  [ $# -eq 3 ] || pm_die 'pm_vague_exempt 行参数数量不合预期（须恰 3：包内相对路径、行号、理由）'
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$pm_exempts"
}
pm_mirror() {
  [ $# -eq 1 ] || pm_die 'pm_mirror 行参数数量不合预期（须恰 1：镜像脚本单段文件名）'
  printf '%s\n' "$1" >> "$pm_mirrors"
}

pm_rules="$script_dir/package-manifest.rules"
if [ ! -f "$pm_rules" ]; then
  printf 'check-package: 错误：包清单数据文件缺失: %s\n' "$pm_rules" >&2
  exit 2
fi
# 预校验（source 前）：非空非注释行须为顶格指令行（五指令之一）——source 对行级失败
# 不具中止性（未知指令行报错后继续执行、尾态可能为 0），故未知指令必须在 source 前
# 即 exit 2，不能只靠 source 返回码收敛。
pm_bad=$(LC_ALL=C awk '
  BEGIN { split("pm_entry pm_script pm_template pm_shortcode pm_platform pm_vague_word pm_vague_exempt pm_mirror", d, " ") }
  function bad(msg) { printf "第 %d 行: %s\n", FNR, msg; n++ }
  /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
  /^[[:space:]]/ { bad("行首空白（指令行须顶格）"); next }
  {
    ok = 0
    for (k = 1; k <= 8; k++) if (substr($0, 1, length(d[k]) + 1) == d[k] " ") ok = 1
    if (!ok) bad("未知指令或非指令行: " substr($0, 1, 40))
  }
  END { if (n > 0) exit 1 }
' "$pm_rules") || true
pm_report "$pm_bad"
# source 窗口临时关 set -e：行执行出错须经返回码收敛为 exit 2，而非被 set -e 直接
# 以 127 退出（fail-closed 统一退出码口径；pm_* 函数内 arg-count 违规经 pm_die 直达 exit 2）。
set +e
. "$pm_rules"
pm_src_rc=$?
set -e
if [ "$pm_src_rc" -ne 0 ]; then
  printf 'check-package: 错误：包清单数据 source 失败（语法损坏或行执行出错，exit %s）: %s\n' "$pm_src_rc" "$pm_rules" >&2
  exit 2
fi

[ -s "$pm_entries" ] || pm_die '清单缺 entry-files 节（零行）'
[ -s "$pm_scripts" ] || pm_die '清单缺 scripts 节（零行）'
[ -s "$pm_templates" ] || pm_die '清单缺 templates 节（零行）'
[ -s "$pm_codes" ] || pm_die '清单缺 shortcodes 节（零行）'
[ -s "$pm_platforms" ] || pm_die '清单缺 platform-enum 节（零行）'
[ -s "$pm_words" ] || pm_die '清单缺 vague-words 节（零行）'
[ -s "$pm_mirrors" ] || pm_die '清单缺 mirrors 节（零行）'

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
    if ($2 !~ /^(script|rules|test-harness)$/) { bad("kind 不合预期（script|rules|test-harness）: " $2); next }
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
    if ($1 in seen) { bad("短码跨行重复: " $1) } else { seen[$1] = 1 }
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
    if (NF != 1) { bad("字段数 " NF "（预期 1，字段内禁制表符）"); next }
    if ($1 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) { bad("须为单段文件名: " $1); next }
    if ($1 in seen) { bad("文件名跨行重复: " $1) } else { seen[$1] = 1 }
  }
  END { if (n > 0) exit 1 }
' "$pm_mirrors") || true
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

# 检查 1：必需入口存在（清单 entry-files 节逐行，票 57 数据驱动；对照 SPEC-06 §2 目标
# 结构与票 09 Checkpoint 清单）。
n_entries=$(wc -l < "$pm_entries" | tr -d ' ')
missing_entries=''
sep=''
for rel in $(cat "$pm_entries"); do
  if [ ! -f "$pkg_root/$rel" ]; then
    missing_entries="$missing_entries$sep  - $rel"
    sep='
'
  fi
done
if [ -n "$missing_entries" ]; then
  fail 1 "必需入口存在（${n_entries} 个文件）" "$missing_entries"
else
  pass 1 "必需入口存在（${n_entries} 个文件）"
fi

# 检查 2：SKILL.md frontmatter 为 name: agent-up。
if [ ! -f "$pkg_root/SKILL.md" ]; then
  fail 2 'SKILL.md frontmatter 为 name: agent-up' 'SKILL.md 不存在'
elif awk '
  NR == 1 { ok = ($0 == "---"); next }
  ok && !closed {
    if ($0 == "---") closed = 1
    else if ($0 ~ /^name: agent-up$/) found = 1
  }
  END { if (ok && closed && found) exit 0; exit 1 }
' "$pkg_root/SKILL.md"; then
  pass 2 'SKILL.md frontmatter 为 name: agent-up'
else
  fail 2 'SKILL.md frontmatter 为 name: agent-up' 'frontmatter 缺失、未闭合或不含 name: agent-up 行'
fi

# 检查 3：包内无旧标识残留（模式运行时为完整旧 Skill 标识字面量，见 README.md）。
old_id='project-ini'"t"
hits=$(grep -rn -e "$old_id" "$pkg_root" 2>/dev/null || true)
if [ -n "$hits" ]; then
  fail 3 '包内无旧标识残留' "$hits"
else
  pass 3 '包内无旧标识残留'
fi

# 检查 4：无绝对路径与根治理引用。
# 绝对路径前缀模式运行时为“斜杠 + Users/home + 斜杠”（拼接构造避免自命中）；
# 根治理引用只查转义字面量“上级 docs”与“上级 .zcode”（.tmpl 内的兄弟路径语义不在本项口径内，按票 09/11 结论）。
pat_users='/'"Users/"
pat_home='/'"home/"
hits=$(grep -rn \
  -e "$pat_users" \
  -e "$pat_home" \
  -e '\.\./docs' \
  -e '\.\./\.zcode' \
  "$pkg_root" 2>/dev/null || true)
if [ -n "$hits" ]; then
  fail 4 '无绝对路径与根治理引用' "$hits"
else
  pass 4 '无绝对路径与根治理引用'
fi

# 检查 5：模板清单一致（票 57 数据驱动：数据 templates 节 ↔ 磁盘 .tmpl ↔
# templates/README.md manifest 表双向；manifest＝人读投影，数据＝机器真相）。
templates_dir="$pkg_root/references/templates"
manifest="$templates_dir/README.md"
n_templates=$(wc -l < "$pm_templates" | tr -d ' ')
tmpl_list=''
if [ -d "$templates_dir" ]; then
  tmpl_list=$(find "$templates_dir" -type f -name '*.tmpl' | sort)
fi
disk_count=0
if [ -n "$tmpl_list" ]; then
  disk_count=$(printf '%s\n' "$tmpl_list" | wc -l | tr -d ' ')
fi
problems=''
if [ ! -d "$templates_dir" ]; then
  add_problem '  - references/templates/ 目录不存在'
elif [ "$disk_count" -ne "$n_templates" ]; then
  # 花括号不可省略：$disk_count 后紧跟全角字符时，sh 会把多字节字符并入变量名。
  add_problem "  - .tmpl 数量为 ${disk_count}（预期 ${n_templates}）"
fi
if [ -d "$templates_dir" ]; then
  # 磁盘 .tmpl ⊆ 数据（票 09「无未登记」口径的机器真相侧）
  unreg=''
  sep2=''
  OLDIFS=$IFS
  IFS='
'
  for t in $tmpl_list; do
    IFS=$OLDIFS
    if ! grep -qxF "$(basename "$t")" "$pm_templates"; then
      unreg="$unreg$sep2$(basename "$t")"
      sep2='、'
    fi
  done
  IFS=$OLDIFS
  if [ -n "$unreg" ]; then
    add_problem "  - 数据未登记：$unreg"
  fi
  # 数据 ⊆ 磁盘
  data_no_file=''
  sep2=''
  OLDIFS=$IFS
  IFS='
'
  for b in $(cat "$pm_templates"); do
    IFS=$OLDIFS
    if [ ! -f "$templates_dir/$b" ]; then
      data_no_file="$data_no_file$sep2$b"
      sep2='、'
    fi
  done
  IFS=$OLDIFS
  if [ -n "$data_no_file" ]; then
    add_problem "  - 数据登记但无实际文件：$data_no_file"
  fi
  # 数据 ↔ manifest 表双向
  if [ ! -f "$manifest" ]; then
    add_problem '  - templates/README.md（manifest）不存在'
  else
    # 仅在“## 目录清单”至“## 取舍”节内提取（票 09 口径：避开取舍登记散文提及）。
    man_names=$(sed -n '/^## 目录清单/,/^## 取舍/p' "$manifest" | sed -n 's/[^`]*`\([^`]*\.tmpl\)`.*/\1/p' | sort -u)
    data_no_man=''
    sep2=''
    OLDIFS=$IFS
    IFS='
'
    for b in $(cat "$pm_templates"); do
      IFS=$OLDIFS
      if ! printf '%s\n' "$man_names" | grep -qxF "$b"; then
        data_no_man="$data_no_man$sep2$b"
        sep2='、'
      fi
    done
    IFS=$OLDIFS
    if [ -n "$data_no_man" ]; then
      add_problem "  - 未在 manifest 登记：$data_no_man"
    fi
    man_no_data=''
    sep2=''
    for m in $man_names; do
      if ! grep -qxF "$m" "$pm_templates"; then
        man_no_data="$man_no_data$sep2$m"
        sep2='、'
      fi
    done
    if [ -n "$man_no_data" ]; then
      add_problem "  - manifest 登记但不在数据：$man_no_data"
    fi
  fi
fi
if [ -n "$problems" ]; then
  fail 5 "templates 下 .tmpl 为 ${n_templates} 个且全部登记" "$problems"
else
  pass 5 "templates 下 .tmpl 为 ${n_templates} 个且全部登记"
fi

# 检查 6：文本契约头齐全。*.md 与 *.tmpl 在检测窗口内须含 Input:/Output:/Pos: 三行；
# 例外（登记见 README.md 与 schemas/README.md、templates/README.md）：
#   - artifacts-yaml.tmpl 以 YAML # 注释承载（前 5 行含 # Input:/# Output:/# Pos:）；
#   - LICENSE 与 schemas/*.json 不在 *.md/*.tmpl 范围内，自然豁免。
file_list=$(find "$pkg_root" -type f \( -name '*.md' -o -name '*.tmpl' \) | sort)
header_missing=''
sep=''
OLDIFS=$IFS
IFS='
'
for f in $file_list; do
  case $f in
    */artifacts-yaml.tmpl)
      win=$(head -n 5 "$f")
      m_in='# Input:'
      m_out='# Output:'
      m_pos='# Pos:'
      ;;
    *)
      win=$(header_window "$f")
      m_in='Input:'
      m_out='Output:'
      m_pos='Pos:'
      ;;
  esac
  miss=''
  case $win in
    *"$m_in"*) ;;
    *) miss='Input' ;;
  esac
  case $win in
    *"$m_out"*) ;;
    *) miss="${miss:+$miss }Output" ;;
  esac
  case $win in
    *"$m_pos"*) ;;
    *) miss="${miss:+$miss }Pos" ;;
  esac
  if [ -n "$miss" ]; then
    header_missing="$header_missing$sep  - ${f#"${pkg_root}/"} 缺 $miss"
    sep='
'
  fi
done
IFS=$OLDIFS
if [ -n "$header_missing" ]; then
  fail 6 '文本契约头齐全（*.md 与 *.tmpl）' "$header_missing"
else
  pass 6 '文本契约头齐全（*.md 与 *.tmpl）'
fi

# 检查 7：根治理文件不在包内（AGENTS.md、docs/、.zcode/）。
gov_found=''
if [ -e "$pkg_root/AGENTS.md" ]; then
  gov_found='AGENTS.md（文件）'
fi
if [ -d "$pkg_root/docs" ]; then
  gov_found="$gov_found docs/（目录）"
fi
if [ -d "$pkg_root/.zcode" ]; then
  gov_found="$gov_found .zcode/（目录）"
fi
if [ -n "$gov_found" ]; then
  fail 7 '根治理文件不在包内' "包根存在：$gov_found"
else
  pass 7 '根治理文件不在包内'
fi

# 检查 8：脚本必需件存在（清单 scripts 节逐行，票 57 数据驱动；kind 区分普通脚本/规则
# 表/test-harness，口径差定谳＝test-record-layer.sh 定为必需件；票 48 fail-closed 守卫：
# 任一缺失即 FAIL 并逐件指名，不因部分存在而放宽）。
n_scripts=$(wc -l < "$pm_scripts" | tr -d ' ')
missing_scripts=''
sep=''
OLDIFS=$IFS
IFS='
'
for row in $(cat "$pm_scripts"); do
  IFS=$OLDIFS
  rel=${row%%"$TAB"*}
  if [ ! -f "$pkg_root/$rel" ]; then
    missing_scripts="$missing_scripts$sep  - $rel"
    sep='
'
  fi
done
IFS=$OLDIFS
if [ -n "$missing_scripts" ]; then
  fail 8 "脚本必需件存在（${n_scripts} 个文件）" "$missing_scripts"
else
  pass 8 "脚本必需件存在（${n_scripts} 个文件）"
fi

# 检查 9：scripts/README.md 成员表 ↔ 数据 scripts 节一致（票 57 新增）。一致口径（双向）：
# ①数据 scripts 节每件都在成员表登记（表＝人读投影不得漏登必需件）；②成员表登记的
# 每件都是 scripts/ 下实际文件（表与实物不漂移）。
problems=''
scripts_readme="$pkg_root/scripts/README.md"
if [ ! -f "$scripts_readme" ]; then
  add_problem '  - scripts/README.md（成员表）不存在'
else
  # 提取成员表（锚点＝首列表头行；表格随首个非 | 行结束），每行取首列反引号名单。
  table_names=$(awk '
    /^\| 名字 \| 地位 \| 功能 \|/ { f = 1; next }
    f { if ($0 !~ /^\|/) f = 0; else print }
  ' "$scripts_readme" | sed -n 's/^| `\([^`]*\)`.*/\1/p')
  if [ -z "$table_names" ]; then
    add_problem '  - 成员表未提取到成员行（表结构漂移）'
  else
    miss_tbl=''
    sep2=''
    OLDIFS=$IFS
    IFS='
'
    for row in $(cat "$pm_scripts"); do
      IFS=$OLDIFS
      rel=${row%%"$TAB"*}
      b=${rel##*/}
      if ! printf '%s\n' "$table_names" | grep -qxF "$b"; then
        miss_tbl="$miss_tbl$sep2$b"
        sep2='、'
      fi
    done
    IFS=$OLDIFS
    if [ -n "$miss_tbl" ]; then
      add_problem "  - 数据登记未在成员表：$miss_tbl"
    fi
    no_file=''
    sep2=''
    for b in $table_names; do
      if [ ! -f "$pkg_root/scripts/$b" ]; then
        no_file="$no_file$sep2$b"
        sep2='、'
      fi
    done
    if [ -n "$no_file" ]; then
      add_problem "  - 成员表登记但无实际文件：$no_file"
    fi
  fi
fi
if [ -n "$problems" ]; then
  fail 9 'scripts/README.md 成员表与数据 scripts 节一致' "$problems"
else
  pass 9 'scripts/README.md 成员表与数据 scripts 节一致'
fi

# 检查 10：规则块短码使用 ⊆ 登记（票 57 新增）。扫描范围＝包内全部 *.md 与 *.tmpl
# （同检查 6 文件面）；登记权威＝清单 shortcodes 节；SPEC 规格号（R-02-001 形态）与
# R-<短码>-<三位序号> 占位散文不落入提取模式，零自命中。
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
  fail 10 '规则块短码使用均在登记内' "$problems"
else
  pass 10 '规则块短码使用均在登记内'
fi

# 检查 11：platform 枚举登记处 ↔ 数据一致（票 57 新增；逐处全等，协调层改判随票修）。
# 登记处（锚点＝登记标记文本，值集合以清单 platform-enum 节为权威）：artifacts-yaml.tmpl
# platform 字段注释区；capability-contract.md 内每个「已知集合」句（frontmatter 与 §2.5
# 各一处）逐处全等，任一处缺值/多值/改值即 FAIL 且按行号指名；adapters 各文件的宿主
# 自述不在本项口径内。
problems=''
platform_data=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_platforms" | sort)
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
  fail 11 'platform 枚举登记与数据一致' "$problems"
else
  pass 11 'platform 枚举登记与数据一致'
fi

# 检查 12：规则块体无模糊措辞（票 58 新增）。词表外置清单 vague-words 节（引擎零词表
# 硬编码，字面匹配非正则）；行级豁免外置 vague-exemptions 节（路径＋行号＋理由；登记行
# 无命中即失效豁免 FAIL，防行号漂移静默失效）。扫描窗口＝包内全部 *.md 与 *.tmpl 的
# R-<短码>-NNN 规则块体（块头行起至下一标题行止，块头本身不扫，规则块结构同
# governance-format.md R-GF-001）；排除「解释与例外」节（标题含该标记起至下一标题止）
# 与各 README 文件（叙事面）；manifest 自身词表行为 .rules 数据文件，不在 md/tmpl
# 扫描文件面（零自命中）。
problems=''
n_words=$(wc -l < "$pm_words" | tr -d ' ')
n_exempt=0
[ -s "$pm_exempts" ] && n_exempt=$(wc -l < "$pm_exempts" | tr -d ' ')
words_col=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_words")
hits_all=''
OLDIFS=$IFS
IFS='
'
for f in $file_list; do
  IFS=$OLDIFS
  case $f in
    */README.md) continue ;;
  esac
  rel=${f#"${pkg_root}/"}
  # 词表经环境变量传入（BSD awk 对含字面换行的 -v 赋值报 "newline in string"，
  # ENVIRON 承载多行值可靠）；awk 异常即 exit 2 fail-closed——扫描器失效不得静默
  # 当作零命中放过（否则词表扫描形同虚设）。
  awk_rc=0
  fhits=$(LC_ALL=C WORDS="$words_col" awk -v rel="$rel" '
    BEGIN { nw = split(ENVIRON["WORDS"], W, "\n") }
    /^#### R-[A-Z][A-Z]-[0-9][0-9][0-9][ \t]/ { inblk = 1; next }
    /^#/ {
      if (index($0, "解释与例外") > 0) expl = 1; else expl = 0
      inblk = 0
      next
    }
    inblk == 1 && expl != 1 {
      for (k = 1; k <= nw; k++) {
        if (W[k] != "" && index($0, W[k]) > 0) printf "%s:%d:%s\n", rel, FNR, W[k]
      }
    }
  ' "$f") || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 12 扫描器异常（awk exit %s）: %s\n' "$awk_rc" "$f" >&2
    exit 2
  fi
  if [ -n "$fhits" ]; then
    hits_all="$hits_all$fhits
"
  fi
done
IFS=$OLDIFS
if [ -n "$hits_all" ]; then
  OLDIFS=$IFS
  IFS='
'
  for h in $hits_all; do
    IFS=$OLDIFS
    h_word=${h##*:}
    h_rest=${h%:*}
    h_ln=${h_rest##*:}
    h_rel=${h_rest%:*}
    # 尾锚精确匹配（协调层 Review 改判随票修）：检索键带尾制表符——豁免行结构为
    # 路径\t行号\t理由（理由经结构校验非空且无制表符），故 "path\t82\t" 只匹配行 82
    # 的豁免行，不匹配 "path\t820\t..."——行号的字符串前缀关系不得误罩其他行命中。
    if ! grep -qF "$(printf '%s\t%s\t' "$h_rel" "$h_ln")" "$pm_exempts"; then
      add_problem "  - $h_rel:$h_ln 命中模糊措辞「${h_word}」"
    fi
  done
  IFS=$OLDIFS
fi
if [ -s "$pm_exempts" ]; then
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    e_rel=${row%%"$TAB"*}
    e_rest=${row#*"$TAB"}
    e_ln=${e_rest%%"$TAB"*}
    case $hits_all in
      *"$e_rel:$e_ln:"*) : ;;
      *)
        # 花括号不可省略：全角字符相邻时防止变量名吞并
        add_problem "  - 失效豁免（登记行无词表命中，须复核更新或删除登记）: $e_rel:$e_ln"
        ;;
    esac
  done < "$pm_exempts"
fi
if [ -n "$problems" ]; then
  fail 12 "规则块体无模糊措辞（词表 ${n_words} 词，豁免 ${n_exempt} 行）" "$problems"
else
  pass 12 "规则块体无模糊措辞（词表 ${n_words} 词，豁免 ${n_exempt} 行）"
fi

# 检查 13：镜像脚本与仓根同名件一致（票 58 新增）。比对对＝清单 mirrors 节登记（对应
# 关系＝包侧 scripts/<名> 与包根父目录仓根 scripts/<名> 同名件，注记见 manifest）；
# 仓根无 scripts/ 或无同名件静默跳过（消费项目语义，--pkg-root 参数化语境同样跳过，
# 无输出行）；逐对 cmp，一致 PASS、差异 FAIL 指名文件。
problems=''
n_mirror=$(wc -l < "$pm_mirrors" | tr -d ' ')
mirror_compared=0
mirror_root=$(CDPATH= cd "$pkg_root/.." 2>/dev/null && pwd) || mirror_root=''
if [ -n "$mirror_root" ] && [ -d "$mirror_root/scripts" ]; then
  OLDIFS=$IFS
  IFS='
'
  for m in $(cat "$pm_mirrors"); do
    IFS=$OLDIFS
    [ -f "$pkg_root/scripts/$m" ] || continue
    [ -f "$mirror_root/scripts/$m" ] || continue
    mirror_compared=$((mirror_compared + 1))
    if ! cmp -s "$pkg_root/scripts/$m" "$mirror_root/scripts/$m"; then
      add_problem "  - scripts/$m 与仓根 scripts/$m 不一致（byte-diff，两处同源演化须互为镜像）"
    fi
  done
  IFS=$OLDIFS
fi
if [ "$mirror_compared" -gt 0 ]; then
  if [ -n "$problems" ]; then
    fail 13 "镜像脚本与仓根同名件一致（比对 ${mirror_compared} 对）" "$problems"
  else
    pass 13 "镜像脚本与仓根同名件一致（比对 ${mirror_compared} 对）"
  fi
fi
# mirror_compared=0（仓根无 scripts/ 或无同名件）→ 静默跳过，无输出行

if [ "$failures" -gt 0 ]; then
  printf 'check-package: FAIL（%s 项未通过，共 13 项）\n' "$failures"
  exit 1
fi
printf 'check-package: PASS\n'
