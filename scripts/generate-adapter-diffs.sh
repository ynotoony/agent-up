#!/bin/sh
# Input: 包根目录（缺省取本脚本所在目录的上一级）与适配差异数据表
#        references/adapters/adapter-diffs.rules（票 222 四节机器数据行）；宿主 Markdown
#        落位按适配器注册表基线约定 references/adapters/<platform>.md。
# Output: --section 渲染模式：按段输出宿主差异段的 Markdown 行（cap＝「| 能力基元 |」
#        对照表数据行、role＝「| <role-contract-dir>/」角色映射表数据行、exec＝独立执行体
#        声明锚语、dialect＝方言签名锚语）；--check 模式：渲染输出与现行宿主文件对应段
#        逐字节比对，零漂移 exit 0 并输出计数汇总、漂移 exit 1 逐行指名宿主与段、数据表
#        或环境不合预期 exit 2（fail-closed，不产生部分结论）。
# Pos: 公开包 adapters/ 差异段的唯一渲染器（数据表→文档段的单向生成链路）；check-package.sh
#      检查 28 经本件核对生成漂移。比对口径＝**逐字节全等**：渲染行与宿主对应段行只去首尾
#      空白、按三列取单元格后逐字节 cmp（行序敏感），行内代码反引号等强调记号属被比对内容
#      （数据表字段原文承载，单侧丢失即漂移）；锚语按原文子串在场断言。检查 27 另按「两侧
#      同剥反引号后全等」的宽松口径核对数据面，两者互补。本件不改任何侧内容，只渲染与比对。
# 用法: sh generate-adapter-diffs.sh [--pkg-root <dir>] [--platform <p>]
#        [--section cap|role|exec|dialect|all] [--check]
# 退出码: 0 渲染成功或 --check 零漂移；1 --check 发现漂移（逐行指名宿主与段）；2 用法、
#        数据表缺失/损坏或包根不存在（fail-closed）。

set -eu

prog=generate-adapter-diffs

usage() {
  cat <<'USAGE'
用法: sh generate-adapter-diffs.sh [选项]
选项:
  --pkg-root <dir>   包根目录（含 SKILL.md）；缺省取本脚本所在目录的上一级
  --platform <p>     只渲染/核对单个宿主（缺省全部注册平台，序＝数据表首次出现序）
  --section <name>   段选择：cap（能力对照表）/role（角色映射表）/exec（独立执行体
                     声明锚语）/dialect（方言签名锚语）/all（四段全出，段间空行分隔）
  --check            渲染输出与现行宿主文件对应段比对；零漂移 exit 0，漂移 exit 1
  -h, --help         显示本用法
退出码:
  0  渲染成功或 --check 零漂移
  1  --check 发现漂移（逐行指名宿主文件与段）
  2  用法错误、包根或数据表缺失/损坏（fail-closed，不产生部分结论）
USAGE
}

die() {
  printf '%s: 错误：%s\n' "$prog" "$1" >&2
  exit 2
}

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
pkg_root=''
platform_filter=''
section='all'
check_mode=0

while [ $# -gt 0 ]; do
  case $1 in
    --pkg-root)
      [ $# -ge 2 ] || die '--pkg-root 需要目录参数'
      pkg_root=$2
      shift 2
      ;;
    --platform)
      [ $# -ge 2 ] || die '--platform 需要平台值'
      platform_filter=$2
      shift 2
      ;;
    --section)
      [ $# -ge 2 ] || die '--section 需要段名（cap|role|exec|dialect|all）'
      section=$2
      shift 2
      ;;
    --check)
      check_mode=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $1（见 --help）"
      ;;
  esac
done

case $section in
  cap|role|exec|dialect|all) ;;
  *) die "段名不合预期（cap|role|exec|dialect|all）: $section" ;;
esac

if [ -z "$pkg_root" ]; then
  pkg_root=$(CDPATH='' cd "$script_dir/.." && pwd)
  # 包内引擎副本（复制落位语境）同样按脚本上一级取根，与 check-package.sh 同款惯例
fi
[ -d "$pkg_root" ] || die "包根目录不存在: $pkg_root"

rules="$pkg_root/references/adapters/adapter-diffs.rules"
[ -f "$rules" ] || die "适配差异数据表缺失: $rules"

t_root=$(mktemp -d "${TMPDIR:-/tmp}/gad.XXXXXX") || die '临时目录创建失败'
trap 'rm -rf "$t_root"' EXIT HUP INT TERM

dat="$t_root/rows"
gen="$t_root/gen"
hostcanon="$t_root/host"
anchors="$t_root/anchors"

# ---- 非执行式解析（与 check-package.sh 加载段同词法：注释行、单引号词法、续行拼接；
#      引号外 shell 元字符与行内制表符拒绝；四节指令各自字段数 fail-closed）----
LC_ALL=C awk '
  function bad(msg) { printf "%s: 数据表第 %d 逻辑行: %s\n", "generate-adapter-diffs", ln, msg > "/dev/stderr"; err = 1 }
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
    sub(/^[ \t]+/, "", raw)
    if (raw == "" || substr(raw, 1, 1) == "#") next
    out = ""; tok = ""; first = 1; inq = 0; inqseen = 0; nf = 0
    L = length(raw)
    for (i = 1; i <= L; i++) {
      c = substr(raw, i, 1)
      if (c == "\t") { bad("行内制表符（字段边界污染）"); next }
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
      # 引号内反引号＝本表强调记号（行内代码）的字面承载，非命令替换：数据表字段原文即
      # 宿主 Markdown 原文，生成器须逐字节复现；命令替换与参数展开形态仍拒绝（见下行）。
      if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "(") { bad("引号内命令替换形态（美元括号）"); next }
      if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "{") { bad("引号内参数展开形态（美元花括号）"); next }
      tok = tok c
    }
    if (inq) { bad("单引号未闭合（词法破坏）"); next }
    if (tok != "" || inqseen) {
      if (first) { cmd = tok } else { out = out tok "\t"; nf++ }
    }
    if (first) { bad("非指令行（无参数）: " substr(raw, 1, 40)); next }
    ar = -1; tag = ""
    if (cmd == "pm_adapter_cap") { ar = 4; tag = "cap" }
    else if (cmd == "pm_adapter_role") { ar = 4; tag = "role" }
    else if (cmd == "pm_adapter_exec") { ar = 3; tag = "exec" }
    else if (cmd == "pm_adapter_dialect") { ar = 3; tag = "dialect" }
    if (ar < 0) { bad("未知指令或非指令行: " substr(raw, 1, 40)); next }
    if (nf != ar) { bad("参数数量不合预期（" cmd " 须恰 " ar " 个参数）: " nf); next }
    print tag "\t" substr(out, 1, length(out) - 1)
  }
  END { if (err) exit 1 }
' "$rules" > "$dat" || die "适配差异数据表不合预期（fail-closed，不产生部分结论）: $rules"

# ---- 段账本计数与平台序（数据表首次出现序＝宿主文档序）----
sec_rows() {
  # $1=段名：输出该段行数（可再经调用方按平台过滤）
  LC_ALL=C awk -F'\t' -v s="$1" '$1 == s { n++ } END { print n + 0 }' "$dat"
}
for _s in cap role exec dialect; do
  [ "$(sec_rows "$_s")" -gt 0 ] || die "差异数据表缺 ${_s} 段（零行）"
done
plats=$(LC_ALL=C awk -F'\t' '!seen[$2]++ { print $2 }' "$dat")
[ -n "$plats" ] || die '差异数据表零数据行'

if [ -n "$platform_filter" ]; then
  printf '%s\n' "$plats" | grep -qxF -- "$platform_filter" \
    || die "平台不在数据表登记平台集: $platform_filter"
fi

render_section() {
  # $1=段名 $2=平台（空＝全部）：输出该段渲染行（Markdown 形态，无强调记号）。
  case $1 in
    cap)
      LC_ALL=C awk -F'\t' -v s="$1" -v p="$2" \
        '$1 == s && (p == "" || $2 == p) { printf "| %s | %s | %s |\n", $3, $4, $5 }' "$dat"
      ;;
    role)
      LC_ALL=C awk -F'\t' -v s="$1" -v p="$2" \
        '$1 == s && (p == "" || $2 == p) { printf "| <role-contract-dir>/%s.md | %s | %s |\n", $3, $4, $5 }' "$dat"
      ;;
    exec|dialect)
      LC_ALL=C awk -F'\t' -v s="$1" -v p="$2" \
        '$1 == s && (p == "" || $2 == p) { print $4 }' "$dat"
      ;;
  esac
}

extract_host_table() {
  # $1=宿主文件 $2=段名（cap|role）：宿主对应段数据行——去首尾空白、三列 TAB 分隔逐行
  # 输出（不剥反引号：强调记号属被比对内容）；列数非 3 的行原样输出（比对必失配＝漂移面）。
  LC_ALL=C awk -v s="$2" '
    function trim(x) { gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    s == "cap" {
      mk = "| 能力基元"
      if (!inh) { if (index($0, mk) == 1) inh = 1; next }
      if ($0 !~ /^\|/) exit
      c = $0
      sub(/^[[:space:]]*\|/, "", c)
      sub(/[[:space:]]*\|.*/, "", c)
      gsub(/^[[:space:]]+/, "", c); gsub(/[[:space:]]+$/, "", c)
      if (c ~ /^[-:]+$/) next
      n = split($0, f, "|")
      if (n - 2 != 3) { print trim($0); next }
      print trim(f[2]) "\t" trim(f[3]) "\t" trim(f[4])
    }
    s == "role" {
      if ($0 !~ /^\| <role-contract-dir>\//) next
      n = split($0, f, "|")
      if (n - 2 != 3) { print trim($0); next }
      r = trim(f[2])
      sub(/^<role-contract-dir>\//, "", r)
      sub(/\.md$/, "", r)
      print r "\t" trim(f[3]) "\t" trim(f[4])
    }
  ' "$1"
}

normalize_table_rows() {
  # stdin=渲染行（Markdown 三列行）$1=段名（cap|role）：去首尾空白并转 TAB 三列（不剥
  # 反引号——与宿主抽取同一严格口径，强调记号差异即漂移）；role 段首列按宿主口径剥
  # <role-contract-dir>/ 前缀与 .md 后缀。
  LC_ALL=C awk -v s="$1" '
    function trim(x) { gsub(/^[ \t]+/, "", x); gsub(/[ \t]+$/, "", x); return x }
    {
      n = split($0, f, "|")
      if (n - 2 != 3) { print trim($0); next }
      c1 = trim(f[2])
      if (s == "role") { sub(/^<role-contract-dir>\//, "", c1); sub(/\.md$/, "", c1) }
      print c1 "\t" trim(f[3]) "\t" trim(f[4])
    }
  '
}

first_diff() {
  # $1/$2=两规约化 TAB 行文件：首个差异行号（两侧全等＝0；行数不齐＝短侧行数＋1）。
  LC_ALL=C awk '
    NR == FNR { d[FNR] = $0; nd = FNR; next }
    { if (!fd && $0 != d[FNR]) fd = FNR; nm = FNR }
    END { if (!fd && nd != nm) fd = (nd < nm ? nd : nm) + 1; print fd + 0 }
  ' "$1" "$2"
}

line_at() {
  LC_ALL=C awk -v i="$2" 'FNR == i { print; exit }' "$1"
}

# ---- 渲染模式 ----
if [ "$check_mode" -eq 0 ]; then
  if [ "$section" != "all" ]; then
    render_section "$section" "$platform_filter"
    exit 0
  fi
  _first=1
  for _p in $plats; do
    if [ -n "$platform_filter" ] && [ "$_p" != "$platform_filter" ]; then
      continue
    fi
    for _s in cap role exec dialect; do
      _block=$(render_section "$_s" "$_p")
      [ -n "$_block" ] || continue
      if [ "$_first" -eq 0 ]; then
        printf '\n'
      fi
      printf '%s\n' "$_block"
      _first=0
    done
  done
  exit 0
fi

# ---- 漂移核对模式：逐宿主逐段渲染比对（fail-closed：结果全量收集后一次判定）----
n_drift=0
n_hosts=0
drift_report=''
add_drift() {
  n_drift=$((n_drift + 1))
  drift_report="$drift_report$1
"
}

for _p in $plats; do
  if [ -n "$platform_filter" ] && [ "$_p" != "$platform_filter" ]; then
    continue
  fi
  n_hosts=$((n_hosts + 1))
  _host_rel="references/adapters/$_p.md"
  _host="$pkg_root/$_host_rel"
  if [ ! -f "$_host" ]; then
    add_drift "  - $_host_rel 宿主文件缺席（无对照面；段＝capability-map／role-map／executor-status／dialect-signature）"
    continue
  fi
  for _s in cap role exec dialect; do
    case $_s in
      cap) _seg_name='capability-map'; _label='九行能力表' ;;
      role) _seg_name='role-map'; _label='三角色映射表' ;;
      exec) _seg_name='executor-status'; _label='独立执行体声明锚语' ;;
      dialect) _seg_name='dialect-signature'; _label='方言签名锚语' ;;
    esac
    if [ "$section" != "all" ] && [ "$section" != "$_s" ]; then
      continue
    fi
    case $_s in
      cap|role)
        render_section "$_s" "$_p" > "$gen"
        normalize_table_rows "$_s" < "$gen" > "$gen.norm"
        extract_host_table "$_host" "$_s" > "$hostcanon"
        if ! cmp -s "$gen.norm" "$hostcanon"; then
          _fd=$(first_diff "$gen.norm" "$hostcanon")
          if [ "$_fd" -eq 0 ]; then
            _fd_desc='0＝行数不齐'
            _g=''
            _h=''
          else
            _fd_desc=$_fd
            _g=$(line_at "$gen.norm" "$_fd")
            _h=$(line_at "$hostcanon" "$_fd")
          fi
          add_drift "  - ${_host_rel} ${_label}与生成输出漂移（段＝${_seg_name}；首个差异行 ${_fd_desc}）: 生成「${_g}」≠ 宿主「${_h}」"
        fi
        rm -f "$gen.norm"
        ;;
      exec|dialect)
        # 锚语在场断言：生成锚语原文须为宿主文件内容的子串（原文在场即零漂移）
        render_section "$_s" "$_p" > "$anchors"
        while IFS= read -r _anchor; do
          [ -n "$_anchor" ] || continue
          if ! grep -qF -- "$_anchor" "$_host"; then
            add_drift "  - ${_host_rel} ${_label}失据（段＝${_seg_name}）: ${_anchor}"
          fi
        done < "$anchors"
        ;;
    esac
  done
done

n_cap=$(sec_rows cap)
n_role=$(sec_rows role)
n_exec=$(sec_rows exec)
n_dial=$(sec_rows dialect)

if [ "$n_drift" -gt 0 ]; then
  printf '%s' "$drift_report"
  printf '生成漂移 %s 处（宿主 %s 个，cap %s 行，role %s 行，exec %s 行，dialect %s 行）\n' \
    "$n_drift" "$n_hosts" "$n_cap" "$n_role" "$n_exec" "$n_dial"
  exit 1
fi

printf 'OK: 生成漂移零差异（宿主 %s 个，cap %s 行，role %s 行，exec %s 行，dialect %s 行）\n' \
  "$n_hosts" "$n_cap" "$n_role" "$n_exec" "$n_dial"
exit 0
