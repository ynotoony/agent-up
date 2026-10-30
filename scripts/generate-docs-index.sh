#!/bin/sh
# Input: 包内全部 *.md 与 *.tmpl 的规则块标题行（`#### R-<短码>-<三位序号> <标题> <Level>`）与
#        本件内嵌机制登记表（ID→机制列取值，含括注出处）；可选参数 --check 与包根目录。
# Output: references/rules-index.md 规则索引投影（Derived 四标注头＋五列表：ID｜标题｜所属文件｜
#        Level｜机制，按 ID 升序）；--check 为 dry-run：生成结果与磁盘文件各自规范化
#        generated_at 行后逐字节比对，一致 exit 0，不一致 exit 1 并逐行指名差异，零写入。
# Pos: 包内规则索引唯一生成器与唯一写入方（单写者语义：本文件只由本脚本写，agent 不手写；
#      与 generate-progress.sh 同族）。扫描面排除本件自身输出；机制登记表缺条目即 exit 2
#      fail-closed（新增规则块须同时登记机制，不静默兜底）。
# 用法与退出码见同目录 README.md。

# ---- 路径常量区 ----
index_rel='references/rules-index.md'
gen_script_rel='scripts/generate-docs-index.sh'

set -u
set -f

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'generate-docs-index: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
用法: sh scripts/generate-docs-index.sh [--check] [package-root]
参数:
  --check       dry-run 模式：与既有 references/rules-index.md 比对（规范化 generated_at 行后
                逐字节比对），一致 exit 0，不一致 exit 1；不写任何文件。
  package-root  包根目录（含 SKILL.md 的目录）；缺省取本脚本落位的上一级。
  -h / --help   打印本用法。
退出码: 0 生成成功或 --check 一致；1 --check 不一致（索引 stale）；2 用法错误、扫描面为空、
        规则块标题或 Level 形态不合预期、或机制登记表缺条目（fail-closed，不产生部分结论）。
USAGE
}

check_mode=0
pkg_arg=''
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --check) check_mode=1 ;;
    --*) die2 "未知参数: $arg" ;;
    -*) usage >&2; exit 2 ;;
    *) if [ -n "$pkg_arg" ]; then die2 "多余参数: ${arg}（只接受一个包根）"; fi; pkg_arg=$arg ;;
  esac
done

if [ -n "$pkg_arg" ]; then
  pkg_root=$(CDPATH='' cd -- "$pkg_arg" 2>/dev/null && pwd -P) || die2 "包根不可用: $pkg_arg"
else
  pkg_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd -P) || die2 '包根推导失败'
fi
[ -f "$pkg_root/SKILL.md" ] || die2 "包根不像 agent-up 包（缺 SKILL.md）: $pkg_root"

out_file="$pkg_root/$index_rel"
out_rel=$index_rel

# ---- 机制登记表（唯一事实承载点）：ID|机制列取值 ----
# 机制语义受控三值见 references/protocol/governance-format.md §2.7；机械类括注须点名
# 包内真实存在的脚本（scripts/ 单段文件名）或检查项号（检查 17 核验；检查器本体不算
# 包内脚本，机械行的检查项出处写作「检查 N」）。
mechanism_table() {
  cat <<'TABLE'
R-AT-001|机械（检查 27）
R-CC-001|门禁
R-CC-002|门禁
R-CC-003|约定
R-CC-004|约定
R-CC-005|机械（检查 26）
R-CO-001|门禁
R-CO-002|门禁
R-CO-003|门禁
R-CO-004|机械（check-gates.sh、lane-commit.sh）
R-CO-005|约定
R-CO-006|约定
R-CO-007|机械（generate-progress.sh、checkpoint-write.sh）
R-CO-008|门禁
R-CO-009|机械（check-append-only.sh）
R-CO-010|约定
R-CP-001|门禁
R-CP-002|门禁
R-CP-003|约定
R-CP-004|约定
R-CP-005|约定
R-CP-006|机械（check-gates.sh、lane-commit.sh）
R-GF-001|机械（检查 22）
R-GF-002|机械（检查 22）
R-GF-003|约定
R-GF-004|约定
R-GF-005|约定
R-GF-006|约定
R-GF-007|约定
R-GF-008|约定
R-GF-009|约定
R-GF-010|机械（检查 12）
R-GF-011|约定
R-RP-001|约定
R-RP-002|约定
R-RP-003|约定
TABLE
}

# ---- 规则块扫描：标题行 + 行号，面＝包内 *.md/*.tmpl，排除本件输出 ----
_t_dir=${TMPDIR:-/tmp}
tmp_blocks=$(mktemp "${_t_dir%/}/docsindex.XXXXXX")
tmp_out=$(mktemp "${_t_dir%/}/docsindex.XXXXXX")
tmp_mech=$(mktemp "${_t_dir%/}/docsindex.XXXXXX")
tmp_a=$(mktemp "${_t_dir%/}/docsindex.XXXXXX")
tmp_b=$(mktemp "${_t_dir%/}/docsindex.XXXXXX")
cleanup() {
  rm -f "$tmp_blocks" "$tmp_out" "$tmp_mech" "$tmp_a" "$tmp_b"
}
trap cleanup EXIT HUP INT TERM

(cd "$pkg_root" && find . -type f \( -name '*.md' -o -name '*.tmpl' \) | sed 's|^\./||' | sort) > "$tmp_a" \
  || die2 '扫描面列举失败'

TAB=$(printf '\t')
: > "$tmp_blocks"
while IFS= read -r f; do
  [ "$f" = "$out_rel" ] && continue
  grep -nE '^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]([[:space:]]|$)' "$pkg_root/$f" 2>/dev/null \
    | while IFS=: read -r ln line; do
        printf '%s\t%s\t%s\n' "$f" "$ln" "$line"
      done >> "$tmp_blocks"
done < "$tmp_a"

[ -s "$tmp_blocks" ] || die2 '扫描面零规则块（锚点「#### R-xx-NNN」未命中）'

mechanism_table > "$tmp_mech"

awk -F'\t' -v tab="$TAB" '
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  {
    file = $1; ln = $2; line = $3
    t = line
    gsub(/`/, "", t)
    sub(/^####[ \t]+/, "", t)
    if (t ~ /[ \t]MUST NOT[ \t]*$/) { level = "MUST NOT"; sub(/[ \t]*MUST NOT[ \t]*$/, "", t) }
    else if (t ~ /[ \t]MUST[ \t]*$/) { level = "MUST"; sub(/[ \t]*MUST[ \t]*$/, "", t) }
    else if (t ~ /[ \t]SHOULD[ \t]*$/) { level = "SHOULD"; sub(/[ \t]*SHOULD[ \t]*$/, "", t) }
    else if (t ~ /[ \t]MAY[ \t]*$/) { level = "MAY"; sub(/[ \t]*MAY[ \t]*$/, "", t) }
    else { printf "BADLEVEL\t%s:%s\t%s\n", file, ln, line > "/dev/stderr"; exit 2 }
    n = split(t, W, /[ \t]+/)
    id = W[1]
    if (id !~ /^R-[A-Z][A-Z]-[0-9][0-9][0-9]$/) {
      printf "BADID\t%s:%s\t%s\n", file, ln, line > "/dev/stderr"
      exit 2
    }
    title = t
    sub(/^[^ \t]+[ \t]+/, "", title)
    print id tab trim(title) tab file tab level
  }
' "$tmp_blocks" > "$tmp_a" || die2 '规则块标题解析失败（形态不合预期）'

dups=$(LC_ALL=C cut -f1 "$tmp_a" | LC_ALL=C sort | LC_ALL=C uniq -d)
[ -z "$dups" ] || die2 "规则块 ID 重复: $(printf '%s' "$dups" | tr '\n' ' ')"

n_blocks=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$tmp_a")
n_mech=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$tmp_mech")

# 逐块取机制；缺条目即 fail-closed 指名（不静默兜底）
unreg=''
sep=''
while IFS="$TAB" read -r id title file level; do
  cell=$(LC_ALL=C awk -F'|' -v i="$id" '$1 == i { print $2; exit }' "$tmp_mech")
  if [ -z "$cell" ]; then
    unreg="$unreg$sep$id"
    sep='、'
    continue
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$title" "$file" "$level" "$cell" >> "$tmp_b"
done < "$tmp_a"
if [ -n "$unreg" ]; then
  die2 "机制登记表缺条目（新增规则块须同时登记机制）: $unreg"
fi

# 机制登记表多余条目（已删块未撤登记）＝漂移，指名但不阻断生成方向；--check 会整文件不一致。
extra=''
sep=''
while IFS= read -r row; do
  [ -n "$row" ] || continue
  mid=${row%%|*}
  if ! LC_ALL=C cut -f1 "$tmp_a" | grep -qxF "$mid"; then
    extra="$extra$sep$mid"
    sep='、'
  fi
done < "$tmp_mech"
if [ -n "$extra" ]; then
  die2 "机制登记表有条目无对应规则块（须撤登记）: $extra"
fi

generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

{
  printf '<!-- Input: 包内全部 *.md 与 *.tmpl 的规则块标题行与块体（本文件由 generate-docs-index.sh 独占写） -->\n'
  printf '<!-- Output: 规则索引投影：每块一行（ID｜标题｜所属文件｜Level｜机制），按 ID 升序 -->\n'
  printf '<!-- Pos: 包内规则块导航投影（Derived）；规则块格式权威＝references/protocol/governance-format.md -->\n'
  printf '<!-- generated_from: 包内规则块扫描 ＋ %s -->\n' "$gen_script_rel"
  printf '<!-- generated_at: %s -->\n' "$generated_at"
  printf '<!-- coverage: 包内 %s 个规则块（%s 节登记机制值），每块一行 -->\n' "$n_blocks" "$n_mech"
  printf '<!-- invalidation: Derived 投影，可由生成器整文件重建；与规则块正文不一致时以正文为准 -->\n'
  printf '\n'
  printf '# 规则索引（Derived）\n'
  printf '\n'
  printf '| ID | 标题 | 所属文件 | Level | 机制 |\n'
  printf '| --- | --- | --- | --- | --- |\n'
  LC_ALL=C sort "$tmp_b" | LC_ALL=C cut -f1-5 \
    | LC_ALL=C awk -F'\t' '{ printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }'
} > "$tmp_out"

if [ "$check_mode" -eq 1 ]; then
  [ -f "$out_file" ] || die1 "索引文件不存在: ${out_file}（先运行生成器落盘）"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$tmp_out" > "$tmp_a"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$out_file" > "$tmp_b"
  if cmp -s "$tmp_a" "$tmp_b"; then
    printf 'generate-docs-index: CHECK: PASS — 索引与规则块一致: %s（%s 块）\n' "$out_file" "$n_blocks"
    exit 0
  fi
  printf 'generate-docs-index: FAIL: 索引与规则块不一致（stale）: %s\n' "$out_file" >&2
  diff -u "$tmp_b" "$tmp_a" >&2 || true
  exit 1
fi

mv -f "$tmp_out" "$out_file"
printf 'generate-docs-index: OK: 已生成 %s（%s 块）\n' "$out_file" "$n_blocks"
