#!/bin/sh
# Input: 待检包根目录（默认为本脚本所在目录的父目录）与包内全部文本文件。
# Output: 八项包完整性检查的逐项 PASS/FAIL 行与结尾汇总（全部通过 exit 0，任一失败 exit 1）。
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
  0  八项检查全部通过
  1  存在未通过项（逐项 FAIL 行见输出）
  2  用法或环境错误（参数过多、包根不存在等）
八项检查说明、例外登记与输出格式见同目录 README.md。
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
  script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
  pkg_root=$(CDPATH= cd "$script_dir/.." && pwd)
fi
if [ ! -d "$pkg_root" ]; then
  printf 'check-package: 错误：包根目录不存在：%s\n' "$pkg_root" >&2
  exit 2
fi

# 检查 1：必需入口存在（16 个文件；对照 SPEC-06 §2 目标结构与票 09 Checkpoint 清单）。
missing_entries=''
sep=''
for rel in \
  SKILL.md \
  README.md \
  LICENSE \
  references/README.md \
  references/old-project.md \
  references/templates/README.md \
  references/protocol/README.md \
  references/adapters/README.md \
  references/schemas/README.md \
  references/protocol/governance-format.md \
  references/protocol/read-policy.md \
  references/protocol/complexity-profile.md \
  references/adapters/capability-contract.md \
  references/adapters/zcode.md \
  references/schemas/run-record.schema.json \
  references/schemas/run-record.example.json
do
  if [ ! -f "$pkg_root/$rel" ]; then
    missing_entries="$missing_entries$sep  - $rel"
    sep='
'
  fi
done
if [ -n "$missing_entries" ]; then
  fail 1 '必需入口存在（16 个文件）' "$missing_entries"
else
  pass 1 '必需入口存在（16 个文件）'
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

# 检查 5：templates 下 .tmpl 恰 13 个且逐个登记于 manifest（templates/README.md）。
templates_dir="$pkg_root/references/templates"
manifest="$templates_dir/README.md"
if [ ! -d "$templates_dir" ]; then
  fail 5 'templates 下 .tmpl 为 13 个且全部登记' 'references/templates/ 目录不存在'
else
  tmpl_list=$(find "$templates_dir" -type f -name '*.tmpl' | sort)
  if [ -n "$tmpl_list" ]; then
    tmpl_count=$(printf '%s\n' "$tmpl_list" | wc -l | tr -d ' ')
  else
    tmpl_count=0
  fi
  problems=''
  sep='
'
  if [ "$tmpl_count" -ne 13 ]; then
    # 花括号不可省略：$tmpl_count 后紧跟全角字符时，sh 会把多字节字符并入变量名。
    problems="  - .tmpl 数量为 ${tmpl_count}（预期 13）"
  fi
  if [ ! -f "$manifest" ]; then
    problems="${problems}${sep}  - templates/README.md（manifest）不存在"
  else
    unreg=''
    sep2=''
    OLDIFS=$IFS
    IFS='
'
    for t in $tmpl_list; do
      if ! grep -qF "$(basename "$t")" "$manifest"; then
        unreg="$unreg$sep2$(basename "$t")"
        sep2='、'
      fi
    done
    IFS=$OLDIFS
    # 反向核对（票 09 清单“无多余登记”口径）：manifest 目录清单节登记的每个 .tmpl
    # 名都必须有实际文件；仅在“## 目录清单”至“## 取舍”节内提取，避开取舍登记散文提及。
    extra=''
    sep3=''
    for name in $(sed -n '/^## 目录清单/,/^## 取舍/p' "$manifest" | sed -n 's/[^`]*`\([^`]*\.tmpl\)`.*/\1/p' | sort -u); do
      if [ ! -f "$templates_dir/$name" ]; then
        extra="$extra$sep3$name"
        sep3='、'
      fi
    done
    if [ -n "$unreg" ]; then
      if [ -n "$problems" ]; then
        problems="$problems
"
      fi
      problems="${problems}  - 未在 manifest 登记：$unreg"
    fi
    if [ -n "$extra" ]; then
      if [ -n "$problems" ]; then
        problems="$problems
"
      fi
      problems="${problems}  - manifest 登记但无实际文件：$extra"
    fi
  fi
  if [ -n "$problems" ]; then
    fail 5 'templates 下 .tmpl 为 13 个且全部登记' "$problems"
  else
    pass 5 'templates 下 .tmpl 为 13 个且全部登记'
  fi
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

# 检查 8：脚本必需件存在（8 个文件；六脚本＋语言规则表＋目录 README，票 48 fail-closed 守卫：
# 任一缺失即 FAIL 并逐件指名，不因部分存在而放宽）。
missing_scripts=''
sep=''
for rel in \
  scripts/check-gates.sh \
  scripts/lane-commit.sh \
  scripts/check-stale-claims.sh \
  scripts/generate-progress.sh \
  scripts/generate-module-map.sh \
  scripts/ticket-ops.sh \
  scripts/module-map.rules \
  scripts/README.md
do
  if [ ! -f "$pkg_root/$rel" ]; then
    missing_scripts="$missing_scripts$sep  - $rel"
    sep='
'
  fi
done
if [ -n "$missing_scripts" ]; then
  fail 8 '脚本必需件存在（8 个文件）' "$missing_scripts"
else
  pass 8 '脚本必需件存在（8 个文件）'
fi

if [ "$failures" -gt 0 ]; then
  printf 'check-package: FAIL（%s 项未通过，共 8 项）\n' "$failures"
  exit 1
fi
printf 'check-package: PASS\n'
