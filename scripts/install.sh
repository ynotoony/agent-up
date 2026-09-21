#!/bin/sh
# Input: 命令行参数（--target <dir> 必选＋门控启用 flag）与安装政策数据文件
#        install-policy.rules（与脚本同目录；门控集合构成、每文件复制基线路径与登记
#        lifecycle 值的唯一承载点，票 56 单源化）。
# Output: 按启用门控自数据读复制集合（引擎零脚本名零门控专名），逐件 cp 自包 scripts/
#         至 <target>/scripts/ 并 cmp 核验字节一致；stdout 输出逐件 OK/SKIP 行＋新建
#         scripts/README.md 提示行（目录缺失时）＋登记建议块（每复制件一行 artifacts.yaml
#         十三字段建议值＋generation manifest 提示行）；stderr 报告失败原因。不代写目标
#         治理文件（artifacts.yaml、generation manifest、scripts/README.md 均归执行体）。
# Pos: 安装脚本（票 56）。POSIX sh、零外部依赖（仅 POSIX 标准工具与内建，无 jq/python）、
#      set -eu、fail-closed：规则表缺失或结构校验不过 exit 2 不写任何文件；预检（源存在、
#      目标可写、目标同名件冲突）先于复制，停止零半套；包内误运行守卫（--target 解析后
#      含 agent-up/SKILL.md 或 SKILL.md、或等于本脚本所在目录）exit 1；源缺失/目标不存在
#      或不可写/目标同名件与基线不一致 exit 1（reconcile 纪律：人工漂移不覆盖，检出即
#      停报告）；已存在且字节一致的同名件幂等跳过；复制后 cmp 逐件核验。本脚本为包侧
#      工具（复制基线安装器），不落本仓 scripts/ 镜像；落位语境不存在——引擎只在包内
#      运行，目标目录即落位目的地。

# 用法、安装政策数据格式与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh scripts/install.sh --target <dir> [--fast-lane] [--ticket-ops]
参数:
  --target <dir>  目标项目根目录（须已存在）；复制落位于 <dir>/scripts/。
  --fast-lane     门控启用 flag 之一：复制道脚本集合（构成见同目录 install-policy.rules）。
  --ticket-ops    门控启用 flag 之一：复制票务运维脚本集合（含生成器回退依赖）。
  -h / --help     打印本用法。
行为: 按启用门控自查同目录 install-policy.rules 得复制集合（引擎零脚本名零门控专名，
      加门控＝加规则行零引擎改动），逐件 cp 自包 scripts/ 至 <target>/scripts/ 并 cmp
      核验字节一致；目标 scripts/ 缺失时创建并输出需生成 scripts/README.md 提示行
      （README 生成不归本脚本）；末尾输出登记建议块（每复制件一行 artifacts.yaml 十三
      字段建议值＋generation manifest 提示），不代写目标治理文件。已存在且字节一致的
      同名件幂等跳过；与基线不一致即停（不覆盖人工漂移，reconcile 纪律）。
退出码: 0 全部复制并核验通过；1 fail-closed（包内误运行守卫、目标不存在或不可写、源
        缺失、目标同名件与基线不一致、cmp 核验失败；预检先于复制，停止零半套）；2 用法
        或环境错误（缺 --target、未知参数、零启用门控、规则表缺失或结构校验不过）。
USAGE
}

die1() {
  printf 'install: FAIL: %s\n' "$1" >&2
  exit 1
}

die2() {
  printf 'install: %s\n' "$1" >&2
  exit 2
}

# ---- 临时文件与清理（全部落 TMPDIR，目标项目只写复制件）----

t_dir=${TMPDIR:-/tmp}
tmp_gates=''
tmp_rows=''
tmp_copied=''
cleanup() {
  rm -f "$tmp_gates" "$tmp_rows" "$tmp_copied"
}
trap cleanup EXIT HUP INT TERM
tmp_gates=$(mktemp "${t_dir%/}/installpolicy.XXXXXX")
tmp_rows=$(mktemp "${t_dir%/}/installpolicy.XXXXXX")
tmp_copied=$(mktemp "${t_dir%/}/installpolicy.XXXXXX")

# ---- 安装政策规则表加载（外置数据＋引擎零专名，先例 generate-module-map.sh）----
# 行格式（数据文件头部注释为权威口径）：
#   ip_gate <gate> <flag> <说明>
#   ip_file <pkg-rel-path> <lifecycle> <gate> <说明>
# 逐行 TAB 连接落 tmp_gates / tmp_rows，供结构校验与集合选取。

ip_gate() {
  [ $# -eq 3 ] || die2 '规则表 ip_gate 行参数数量不合预期（须恰 3：gate、flag、说明）'
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp_gates"
}

ip_file() {
  [ $# -eq 4 ] || die2 '规则表 ip_file 行参数数量不合预期（须恰 4：基线路径、lifecycle、门控、说明）'
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$tmp_rows"
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
rules_path="$script_dir/install-policy.rules"
[ -f "$rules_path" ] || die2 "安装政策规则表缺失: $rules_path"
if ! . "$rules_path"; then
  die2 "安装政策规则表 source 失败（语法损坏或行执行出错）: $rules_path"
fi
[ -s "$tmp_gates" ] || die2 "安装政策规则表未定义任何门控行: $rules_path"
[ -s "$tmp_rows" ] || die2 "安装政策规则表未登记任何文件行: $rules_path"

# ---- 规则表结构校验（fail-closed：任何不合预期即 exit 2，不写任何文件）----
# 字段数与字段内制表符（由 -F'\t' 字段数承载）、gate/flag/lifecycle/路径字符集、flag 跨行
# 唯一且不与引擎保留参数冲突、(文件,门控) 唯一、同文件 lifecycle 一致、未定义门控引用、
# 零文件门控——先例 generate-module-map.sh 对 module-map.rules 的处理。

ip_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "%s第 %d 行: %s\n", seg, FNR, msg; badn++ }
  NR == FNR {
    seg = "门控段"
    if (NF != 3) { bad("ip_gate 字段数 " NF "（预期 3）"); next }
    if ($1 !~ /^[a-z][a-z0-9-]*$/) { bad("gate token 不合预期（小写字母开头，小写字母/数字/连字符）: " $1); next }
    if ($2 !~ /^--[a-z][a-z0-9-]*$/) { bad("flag 不合预期（-- 加小写 token）: " $2); next }
    if ($2 == "--target" || $2 == "-h" || $2 == "--help") { bad("flag 与引擎保留参数冲突: " $2); next }
    if ($3 == "") { bad("ip_gate 缺说明"); next }
    if ($1 in gseen) { bad("gate 跨行重复定义: " $1) } else { gseen[$1] = 1 }
    if ($2 in fseen) { bad("flag 跨行重复定义: " $2) } else { fseen[$2] = 1 }
    next
  }
  {
    seg = "文件段"
    if (NF != 4) { bad("ip_file 字段数 " NF "（预期 4）"); next }
    if ($1 !~ /^agent-up\/scripts\/[A-Za-z0-9][A-Za-z0-9._-]*$/) { bad("基线路径不合预期（须 agent-up/scripts/ 前缀加单段文件名，禁 .. 与斜杠入名）: " $1); next }
    if ($2 !~ /^[A-Za-z][A-Za-z0-9_-]*$/) { bad("lifecycle 不合预期（非空 token；枚举权威＝artifacts-yaml.tmpl）: " $2); next }
    if (!($3 in gseen)) { bad("引用未定义门控: " $3); next }
    if ($4 == "") { bad("ip_file 缺说明"); next }
    key = $1 SUBSEP $3
    if (key in pseen) { bad("(文件,门控) 跨行重复: " $1 " @ " $3) } else { pseen[key] = 1 }
    if ($1 in flc && flc[$1] != $2) { bad("同文件跨行 lifecycle 不一致: " $1 "（" flc[$1] " vs " $2 "）") }
    flc[$1] = $2
    gcount[$3]++
    ord[++n] = $0
    next
  }
  END {
    if (badn > 0) exit 1
    for (g in gseen) {
      if (!(g in gcount)) { printf "门控无任何文件行: %s\n", g; badn++ }
    }
    if (badn > 0) exit 1
  }
' "$tmp_gates" "$tmp_rows") || true
if [ -n "$ip_bad" ]; then
  printf 'install: FAIL: 安装政策规则表不合预期: %s\n' "$rules_path" >&2
  printf '%s\n' "$ip_bad" >&2
  exit 2
fi

# ---- 参数解析（门控 flag 自规则表读取，引擎零门控专名）----

target=''
enabled=''
while [ $# -gt 0 ]; do
  case $1 in
    --target)
      [ $# -ge 2 ] || die2 '--target 缺值'
      if [ -n "$target" ]; then
        die2 '--target 重复给出'
      fi
      target=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      hit=$(LC_ALL=C awk -F'\t' -v f="$1" '$2 == f { print $1 }' "$tmp_gates")
      if [ -z "$hit" ]; then
        usage >&2
        die2 "未知参数（未登记的门控 flag 或非法参数）: $1"
      fi
      case "$hit" in
        *"$NL"*) die2 "flag 命中多个门控（规则表 flag 重复）: $1" ;;
      esac
      case " $enabled " in
        *" $hit "*) ;;
        *) enabled="$enabled $hit" ;;
      esac
      shift
      ;;
  esac
done
if [ -z "$target" ]; then
  usage >&2
  die2 '缺少 --target <dir>'
fi
if [ -z "$(printf '%s' "$enabled" | tr -d ' ')" ]; then
  usage >&2
  die2 '零启用门控：至少给出一个门控 flag（本包登记的 flag 见同目录 install-policy.rules）'
fi
enabled=${enabled# }

# ---- 包内误运行守卫与目标解析（fail-closed，exit 1）----

[ -d "$target" ] || die1 "目标目录不存在: $target"
target_abs=$(CDPATH= cd "$target" && pwd) || die1 "目标目录不可进入: $target"
if [ -e "$target_abs/agent-up/SKILL.md" ]; then
  die1 "包内误运行守卫：目标含 agent-up/SKILL.md（疑似包所在仓根或含包副本）: $target_abs"
fi
if [ -e "$target_abs/SKILL.md" ]; then
  die1 "包内误运行守卫：目标含 SKILL.md（疑似包目录）: $target_abs"
fi
if [ "$target_abs" = "$script_dir" ]; then
  die1 "包内误运行守卫：目标为本脚本所在目录: $target_abs"
fi

# ---- 复制集合选取（按启用门控取行，按文件路径去重）----

plan=$(LC_ALL=C awk -F'\t' -v en="$enabled" '
  BEGIN {
    n = split(en, ev, " ")
    for (i = 1; i <= n; i++) on[ev[i]] = 1
  }
  {
    if ($3 in on) {
      if (!($1 in sel)) { sel[$1] = 1; ord[++k] = $1; lc[$1] = $2; hit[$1] = $3; note[$1] = $4 }
      else hit[$1] = hit[$1] " " $3
    }
  }
  END {
    for (i = 1; i <= k; i++) printf "%s\t%s\t%s\t%s\n", ord[i], lc[ord[i]], hit[ord[i]], note[ord[i]]
  }
' "$tmp_rows")
[ -n "$plan" ] || die1 '启用门控未选中任何文件（规则表与门控状态不一致）——fail-closed'

# ---- 预检（先于任何写入：源缺失/目标同名件漂移即停，零半套）----

missing_src=''
conflict=''
sep='
'
oldifs=$IFS
IFS=$NL
for row in $plan; do
  IFS=$oldifs
  p=${row%%"$TAB"*}
  base=${p##*/}
  src="$script_dir/$base"
  dst="$target_abs/scripts/$base"
  if [ ! -f "$src" ]; then
    missing_src="$missing_src$sep  - ${p}（包内缺失: ${src}）"
  fi
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    conflict="$conflict$sep  - ${base}（目标已存在且与包内基线不一致——人工漂移，reconcile 纪律不覆盖）"
  fi
done
IFS=$oldifs
if [ -n "$missing_src" ]; then
  die1 "复制源缺失（fail-closed，零半套）:$missing_src"
fi
if [ -n "$conflict" ]; then
  die1 "目标同名件与包内基线不一致（fail-closed，零半套，请先走 reconcile 处理漂移）:$conflict"
fi

# ---- 复制与逐件 cmp 核验（目标 scripts/ 缺失时创建并提示 README 事项）----

dst_dir="$target_abs/scripts"
created_scripts=0
if [ ! -d "$dst_dir" ]; then
  mkdir -p "$dst_dir" || die1 "目标 scripts 目录创建失败: $dst_dir"
  created_scripts=1
fi
[ -w "$dst_dir" ] || die1 "目标 scripts 目录不可写: $dst_dir"

copied=0
skipped=0
IFS=$NL
for row in $plan; do
  IFS=$oldifs
  p=${row%%"$TAB"*}
  rest=${row#*"$TAB"}
  lc=${rest%%"$TAB"*}
  rest=${rest#*"$TAB"}
  gates=${rest%%"$TAB"*}
  note=${rest##*"$TAB"}
  base=${p##*/}
  src="$script_dir/$base"
  dst="$dst_dir/$base"
  if [ -e "$dst" ]; then
    printf 'install: SKIP: %s（目标已存在且与基线字节一致，幂等跳过）\n' "$base"
    skipped=$((skipped + 1))
  else
    cp "$src" "$dst" || die1 "复制失败: $p -> $dst"
    if ! cmp -s "$src" "$dst"; then
      die1 "cmp 核验失败（复制后与基线字节不一致）: $dst"
    fi
    printf 'install: OK: %s -> %s（lifecycle %s；门控 %s；%s）\n' "$p" "$dst" "$lc" "$gates" "$note"
    printf '%s\n' "$row" >> "$tmp_copied"
    copied=$((copied + 1))
  fi
done
IFS=$oldifs

if [ "$created_scripts" -eq 1 ]; then
  printf 'install: NOTE: %s 为本脚本新建——需生成 scripts/README.md（目录索引；README 生成不归本脚本，由执行体按包内模板补齐）\n' "$dst_dir"
fi

# ---- 登记建议块（每复制件一行 artifacts.yaml 十三字段建议值；不代写目标治理文件）----

if [ "$copied" -gt 0 ]; then
  printf 'install: 登记建议块（artifacts.yaml 十三字段建议值，可粘贴；写入归执行体，本脚本不代写目标治理文件）:\n'
  IFS=$NL
  for row in $(cat "$tmp_copied"); do
    IFS=$oldifs
    p=${row%%"$TAB"*}
    rest=${row#*"$TAB"}
    lc=${rest%%"$TAB"*}
    base=${p##*/}
    idbase=${base%.*}
    printf '  {id: script-%s, path: scripts/%s, kind: script, authority: 权威层级第 4 级（流程规则；按目标项目权威层级定级）, owner: 经用户确认的执行体, lifecycle: %s, trigger: 对应门控启用（用户在差异清单确认时）, read_when: 目标项目运行该脚本时, sync_on: 无（包基线同源演化须登记差异）, depends_on: [development-process], generated_from: %s, platform: neutral, update_policy: 禁止覆盖（人工漂移走 reconcile，检出即停报告）}\n' "$idbase" "$base" "$lc" "$p"
  done
  IFS=$oldifs
  printf 'install: 登记提醒: 每复制件同步登记 generation manifest（来源、日期、目标、用户确认、版本与恢复说明）；建议块仅为可粘贴建议值。\n'
fi

printf 'install: DONE: 复制 %s 件、幂等跳过 %s 件 -> %s（集合与登记 lifecycle 值出自 install-policy.rules）\n' "$copied" "$skipped" "$dst_dir"
exit 0
