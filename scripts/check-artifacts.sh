#!/bin/sh
# Input: 仓库根目录（唯一参数）与其治理产物登记 docs/agent/artifacts.yaml；受管口径与豁免
#        规则自本脚本对账数据块（ca_* 指令，票 59 D2 定谳）读取——引擎零目录硬编码。
# Output: 登记与实物双向对账的逐项 FAIL/SKIP 行与两方向汇总：正向＝每条登记 path 目标
#         必须存在（缺失 FAIL 指名条目，数据块懒创建面暂缺 SKIP）；反向＝受管范围内文件
#         必须被登记或命中豁免规则（未登记 FAIL 指名路径，豁免命中不报）。
# Pos: 治理产物对账器（票 59；兑现 R-DP-007 逐件登记核对）：POSIX sh、零外部依赖、
#      fail-closed（yaml 解析破坏 exit 2 不产生部分结论）；退出码口径同 ticket-ops.sh：
#      0 全对账 / 1 存在缺口 / 2 用法或环境错误。用法、受管口径与豁免维护规则见同目录
#      README.md 专节。

set -eu
set -f  # 关闭文件名展开：模式匹配只经 case，路径展开不可依赖

usage() {
  cat <<'USAGE'
用法: sh check-artifacts.sh <repo-root>
参数:
  repo-root  仓库根目录（其治理产物登记为 <repo-root>/docs/agent/artifacts.yaml）。
对账口径:
  正向  登记条目 path 目标（剥离全角括注）必须存在（文件/目录/聚合 glob ≥1 匹配）；
        数据块懒创建面登记暂缺输出 SKIP 不计缺口。
  反向  数据块受管口径内文件必须被登记（精确/glob/目录聚合覆盖）或命中豁免规则；
        未登记 FAIL 指名路径。
退出码: 0 全对账；1 存在缺口（FAIL 行见输出）；2 用法或环境错误（参数数量不合、
        repo-root 不存在、artifacts.yaml 缺失或解析破坏、数据块不合预期）。
USAGE
}

die2() {
  printf 'check-artifacts: %s\n' "$1" >&2
  exit 2
}

[ $# -eq 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
esac
repo_root=$1
[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
repo_root=$(CDPATH= cd "$repo_root" && pwd)
yaml="$repo_root/docs/agent/artifacts.yaml"
[ -f "$yaml" ] || die2 "治理产物登记缺失: docs/agent/artifacts.yaml（相对 $repo_root）"

t_dir=${TMPDIR:-/tmp}
ca_entries=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
ca_managed=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
ca_scan=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
cleanup() { rm -f "$ca_entries" "$ca_managed" "$ca_scan"; }
trap cleanup EXIT HUP INT TERM

# ---- 对账数据块（票 59 D2 定谳；受管口径与豁免唯一承载点，引擎零目录硬编码）----
# ca_managed_file <repo-root 相对路径>       受管根单文件（存在才进反向清单）
# ca_managed_tree <目录> <扩展名逗号清单>     受管目录（递归，按扩展名过滤）
# ca_managed_flat <目录> <扩展名逗号清单>     受管目录（单层，按扩展名过滤）
# ca_exempt <路径>                           反向豁免：精确路径；尾斜杠＝目录整支豁免
# ca_lazy <路径>                             正向暂缺许可：登记目标允许尚不存在（懒创建面）
load_reconcile_data() {
  ca_managed_file AGENTS.md
  ca_managed_tree docs md,json,jsonl,yaml
  ca_managed_flat scripts sh,rules
  # 豁免（票 59 基线五项＋校准一项，理由注记＝维护时不得静默增删）：
  ca_exempt docs/agent/runs/              # 运行记录投影（整目录）
  ca_exempt docs/progress-current.md      # 生成投影（生成器独占写）
  ca_exempt docs/issues/index.json        # 状态真相源单写面
  ca_exempt docs/changes.jsonl            # 追加面账本
  ca_exempt docs/agent/micro.jsonl        # 道账本（懒创建追加面）
  ca_exempt docs/architecture/generated/  # 生成投影面（票 59 校准：机器生成运行输出，与 runs/ 同性质）
  # 懒创建面（登记允许暂缺，票 59 校准：微账本由道脚本首次收尾懒创建）：
  ca_lazy docs/agent/micro.jsonl
}

ca_exempts=''
ca_lazy=''
ca_managed_file() {
  if [ -f "$repo_root/$1" ]; then
    printf '%s\n' "$1" >> "$ca_managed"
  fi
  return 0
}
ca_exempt() {
  case $1 in
    ''|*' '*) die2 "对账数据块豁免路径不合预期: $1" ;;
  esac
  ca_exempts="$ca_exempts$1
"
}
ca_lazy() {
  case $1 in
    ''|*' '*) die2 "对账数据块懒创建路径不合预期: $1" ;;
  esac
  ca_lazy="$ca_lazy$1
"
}
ca_managed_tree() {
  if [ -d "$repo_root/$1" ]; then
    scan_ext_files "$repo_root/$1" tree "$2"
  fi
  return 0
}
ca_managed_flat() {
  if [ -d "$repo_root/$1" ]; then
    scan_ext_files "$repo_root/$1" flat "$2"
  fi
  return 0
}
scan_ext_files() {
  # $1=绝对目录 $2=tree|flat $3=扩展名逗号清单；命中文件以 repo-root 相对路径追加。
  # case 模式位上的变量展开发生在模式语法解析之后——模式内竖线是字面量而非分隔符，
  # 故逐扩展名单独分支匹配（每文件首扩展开停）。
  _dir=$1
  _mode=$2
  _oifs=$IFS
  _nl=''
  IFS=','
  for _e in $3; do
    IFS=$_oifs
    case $_e in
      ''|*[!a-z0-9]*) die2 "对账数据块扩展名不合预期: $_e" ;;
    esac
    _nl="$_nl$_e
"
  done
  IFS=$_oifs
  if [ -z "$_nl" ]; then
    die2 "对账数据块扩展名清单为空"
  fi
  if [ "$_mode" = flat ]; then
    find "$_dir" -maxdepth 1 -type f > "$ca_scan" 2>/dev/null || true
  else
    find "$_dir" -type f > "$ca_scan" 2>/dev/null || true
  fi
  while IFS= read -r _fp; do
    [ -n "$_fp" ] || continue
    IFS='
'
    for _e in $_nl; do
      IFS=$_oifs
      case $_fp in
        *."$_e")
          printf '%s\n' "${_fp#"$repo_root"/}" >> "$ca_managed"
          break
          ;;
      esac
    done
    IFS=$_oifs
  done < "$ca_scan"
  return 0
}
load_reconcile_data

# ---- 登记解析（fail-closed：结构破坏 exit 2 不产生部分结论）----
# 口径：artifacts: 顶层键恰一；条目行＝两空格缩进「- id: 」；path 行＝四空格缩进
# 「path: 」；每条目恰一 path 行且值非空、不含 ASCII 空白；path 值剥离首个全角左括注
# （聚合登记的中文说明尾注）与其后全部内容；其他缩进字段行忽略；未知形态行即解析破坏。
ca_bad=$(LC_ALL=C awk '
  function bad(msg) { printf "ERR: 第 %d 行: %s\n", FNR, msg; n++ }
  /^artifacts:[[:space:]]*$/ { top = 1; next }
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  /^  - id: / {
    if (curid != "" && !curpath) bad("条目缺 path 字段: " curid)
    curid = substr($0, 9)
    sub(/[[:space:]]+$/, "", curid)
    if (curid == "") bad("条目 id 为空")
    nent++
    curpath = ""
    next
  }
  /^    path: / {
    if (curid == "") { bad("path 字段在条目外"); next }
    if (curpath != "") { bad("条目多行 path 字段: " curid); next }
    v = substr($0, 11)
    i = index(v, "（")
    if (i > 0) v = substr(v, 1, i - 1)
    gsub(/^[[:space:]]+/, "", v)
    gsub(/[[:space:]]+$/, "", v)
    if (v == "") bad("条目 path 值为空: " curid)
    else if (v ~ /[[:space:]]/) bad("条目 path 含空白（无法安全匹配）: " curid)
    else { curpath = v; printf "%s\t%s\n", curid, v }
    next
  }
  /^[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*:/ { next }
  { bad("无法解析的行: " substr($0, 1, 40)) }
  END {
    if (curid != "" && !curpath) bad("条目缺 path 字段: " curid)
    if (!top) bad("缺 artifacts: 顶层键")
    if (nent == 0) bad("零条目")
    if (n > 0) exit 1
  }
' "$yaml") || ca_parse_rc=$?
if [ "${ca_parse_rc:-0}" -ne 0 ]; then
  printf 'check-artifacts: 错误：登记解析破坏（fail-closed，不产生部分结论）: docs/agent/artifacts.yaml\n' >&2
  printf '%s\n' "$ca_bad" | grep '^ERR: ' | sed 's/^ERR: //' >&2
  exit 2
fi
printf '%s\n' "$ca_bad" | grep -v '^ERR: ' > "$ca_entries"

reg_pats=$(LC_ALL=C awk -F'\t' '{print $2}' "$ca_entries")

target_exists() {
  # $1=repo-root 相对目标（可含 glob / 尾斜杠目录）
  _t=$1
  case $_t in
    *'*'*)
      _d=$(dirname "$_t")
      _b=$(basename "$_t")
      if [ ! -d "$repo_root/$_d" ]; then
        return 1
      fi
      [ -n "$(find "$repo_root/$_d" -maxdepth 1 -type f -name "$_b" 2>/dev/null | head -n 1)" ]
      ;;
    */)
      [ -d "$repo_root/$_t" ]
      ;;
    *)
      [ -e "$repo_root/$_t" ]
      ;;
  esac
}

is_exempt() {
  # $1=repo-root 相对路径；尾斜杠豁免项＝目录整支前缀豁免
  _f=$1
  _oifs=$IFS
  IFS='
'
  for _x in $ca_exempts; do
    IFS=$_oifs
    case $_x in
      */)
        case $_f in
          $_x*) return 0 ;;
        esac
        ;;
      *)
        case $_f in
          $_x) return 0 ;;
        esac
        ;;
    esac
  done
  IFS=$_oifs
  return 1
}

is_lazy() {
  _t=$1
  _oifs=$IFS
  IFS='
'
  for _x in $ca_lazy; do
    IFS=$_oifs
    if [ "$_x" = "$_t" ]; then
      return 0
    fi
  done
  IFS=$_oifs
  return 1
}

reg_covered() {
  # $1=repo-root 相对路径；登记覆盖＝精确相等（无 glob 元字符时）／case glob／目录聚合前缀
  _f=$1
  _oifs=$IFS
  IFS='
'
  for _p in $reg_pats; do
    IFS=$_oifs
    case $_p in
      */)
        case $_f in
          $_p*) return 0 ;;
        esac
        ;;
      *)
        case $_f in
          $_p) return 0 ;;
        esac
        ;;
    esac
  done
  IFS=$_oifs
  return 1
}

# ---- 正向：登记目标存在性 ----
ca_targets=0
ca_missing=0
ca_lazyskip=0
while IFS="$(printf '\t')" read -r ca_eid ca_etgt; do
  [ -n "$ca_eid" ] || continue
  ca_targets=$((ca_targets + 1))
  if target_exists "$ca_etgt"; then
    continue
  fi
  if is_lazy "$ca_etgt"; then
    ca_lazyskip=$((ca_lazyskip + 1))
    printf 'check-artifacts: SKIP: 条目 %s 登记目标暂缺（数据块懒创建许可）: %s\n' "$ca_eid" "$ca_etgt"
  else
    ca_missing=$((ca_missing + 1))
    printf 'check-artifacts: FAIL: 条目 %s 登记目标不存在: %s\n' "$ca_eid" "$ca_etgt"
  fi
done < "$ca_entries"

# ---- 反向：受管文件登记覆盖 ----
ca_files=0
ca_unreg=0
ca_exempthit=0
while IFS= read -r ca_f; do
  [ -n "$ca_f" ] || continue
  ca_files=$((ca_files + 1))
  if is_exempt "$ca_f"; then
    ca_exempthit=$((ca_exempthit + 1))
  elif reg_covered "$ca_f"; then
    :
  else
    ca_unreg=$((ca_unreg + 1))
    printf 'check-artifacts: FAIL: 受管文件未登记: %s\n' "$ca_f"
  fi
done < "$ca_managed"

printf 'check-artifacts: 正向: 登记目标 %d 个，缺失 %d 个，懒创建暂缺 %d 个\n' \
  "$ca_targets" "$ca_missing" "$ca_lazyskip"
printf 'check-artifacts: 反向: 受管文件 %d 个，未登记 %d 个，豁免命中 %d 个\n' \
  "$ca_files" "$ca_unreg" "$ca_exempthit"
if [ "$ca_missing" -gt 0 ] || [ "$ca_unreg" -gt 0 ]; then
  printf 'check-artifacts: FAIL（正向缺失 %d，反向未登记 %d）\n' "$ca_missing" "$ca_unreg"
  exit 1
fi
printf 'check-artifacts: PASS\n'
