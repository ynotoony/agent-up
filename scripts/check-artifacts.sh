#!/bin/sh
# Input: 仓库根目录（唯一参数）与其治理产物登记 facts/project/artifacts.yaml；受管口径与协议
#        豁免自本脚本对账数据块（ca_* 指令，票 59 D2 定谳）读取——引擎零目录硬编码；
#        校准豁免自仓根 delivery.rules calibration 节 dp_artifact_exempt 读取（票 72 迁移，
#        解析破坏 exit 2 fail-closed；缺该行＝豁免消失，对应文件按未登记 FAIL 暴露）。
# Output: 登记与实物双向对账的逐项 FAIL/SKIP 行与两方向汇总：正向＝每条登记 path 目标
#         必须存在（缺失 FAIL 指名条目，数据块懒创建面暂缺 SKIP）；反向＝受管范围内文件
#         必须被登记或命中豁免规则（未登记 FAIL 指名路径，豁免命中不报）；
#         条目稳定 id 全集唯一（重复行按登记解析破坏 exit 2 处理，票 147 唯一性检查）。
# Pos: 治理产物对账器（票 59；兑现 R-DP-007 逐件登记核对）：POSIX sh、零外部依赖、
#      fail-closed（yaml 解析破坏 exit 2 不产生部分结论）；退出码口径同 ticket-ops.sh：
#      0 全对账 / 1 存在缺口 / 2 用法或环境错误。用法、受管口径与豁免维护规则见同目录
#      README.md 专节。--fix 修复形态（配对设计准则见同目录 README「构建规约」前节）：
#      缺省 dry-run 仅打印将追加的登记条目建议块零写入；显式 --apply 才落盘（反向未登记
#      文件的十三字段登记条目骨架逐条追加进 artifacts.yaml，正向缺失不修——缺的是实物
#      不是登记）；修复与检测共用同一判定代码（--fix 复跑同一对账管线取未登记清单）。
# dp-parser: 2
#      （本件要求解析器最低版注记；解析唯一实现＝同目录 dp-load-rules.sh，版本唯一
#      来源＝其 DP_PARSER_VERSION。落地拷贝遇未知锚点/指令、解析器缺件或版本漂移即
#      报错指名——同步方式见 references/old-project.md §3 dp-load-rules.sh 引擎件行，
#      文法与版本详见 references/delivery-rules.md。四件同族脚本注记须一致。）

set -eu
set -f  # 关闭文件名展开：模式匹配只经 case，路径展开不可依赖

# Source common helper functions
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  die2() { printf 'check-artifacts: %s\n' "$1" >&2; exit 2; }
fi

# ---- 路径常量区（票 111 波②建立；票 113 波④翻值 rules/facts 新形态：
#      映射 R9/R11/R12/R13/R15/R25）----
artifacts_yaml='facts/project/artifacts.yaml'  # 治理产物登记（R9，仓根相对）
rules_dir='rules'                              # 受管目录：约束面（递归树根）
facts_dir='facts'                              # 受管目录：事实面（递归树根）
requirements_runs='facts/requirements/runs/'   # 协议豁免：运行记录投影（整目录，R25）
progress_current='facts/requirements/tickets/progress-current.md'  # 协议豁免：生成投影（R13）
issues_index='facts/requirements/tickets/index.json'  # 协议豁免：状态真相源单写面（R15）
changes_jsonl='facts/project/changes.jsonl'    # 协议豁免：追加面账本（R11）
micro_jsonl='facts/project/micro.jsonl'        # 协议豁免＋懒创建：道账本（R12）

usage() {
  cat <<'USAGE'
用法: sh check-artifacts.sh [--fix [--apply]] <repo-root>
参数:
  repo-root  仓库根目录（其治理产物登记为 <repo-root>/facts/project/artifacts.yaml）。
  --fix      修复形态（dry-run 缺省）：复跑同一对账管线，将反向未登记文件的登记条目
             建议块（十三字段骨架，逐条对应一个 FAIL 路径）打印到 stdout，零写入。
  --apply    仅与 --fix 同用：把建议条目块追加进 artifacts.yaml（与 dry-run 预览同源
             生成、逐字一致）；追加后本脚本即止（不复跑），复跑核缺口归零归调用方——
             正向缺失（实物不存在）不修，缺的是实物不是登记，补登记归执行体按实际产物定。
对账口径:
  正向  登记条目 path 目标（剥离全角括注）必须存在（文件/目录/聚合 glob ≥1 匹配）；
        数据块懒创建面登记暂缺输出 SKIP 不计缺口。
  反向  数据块受管口径内文件必须被登记（精确/glob/目录聚合覆盖）或命中豁免规则；
        未登记 FAIL 指名路径。
  唯一  条目稳定 id 全集唯一；重复 id 按登记解析破坏处理（exit 2，票 147）。
退出码: 0 全对账；1 存在缺口（FAIL 行见输出）；2 用法或环境错误（参数数量不合、
        repo-root 不存在、artifacts.yaml 缺失或解析破坏、条目 id 重复、数据块
        不合预期）。
USAGE
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
ca_fix=0
ca_apply=0
ca_pos=''
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --fix) ca_fix=1 ;;
    --apply) ca_apply=1 ;;
    *)
      if [ -n "$ca_pos" ]; then usage >&2; die2 '多余位置参数（repo-root 恰一）'; fi
      ca_pos=$1
      ;;
  esac
  shift
done
[ "$ca_apply" -eq 0 ] || [ "$ca_fix" -eq 1 ] || { usage >&2; die2 '--apply 仅与 --fix 同用'; }
repo_root=$ca_pos
[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
repo_root=$(CDPATH='' cd "$repo_root" && pwd)
yaml="$repo_root/$artifacts_yaml"
[ -f "$yaml" ] || die2 "治理产物登记缺失: facts/project/artifacts.yaml（相对 ${repo_root}）"

script_dir=$(CDPATH='' cd "$(dirname -- "$0")" && pwd)
enum_template="$script_dir/../references/templates/artifacts-yaml.tmpl"
[ -f "$enum_template" ] || die2 "枚举权威模板缺失: $enum_template"
ca_kind_values=$(awk '/^# enum kind: / { sub(/^# enum kind: /, ""); print }' "$enum_template")
ca_lifecycle_values=$(awk '/^# enum lifecycle: / { sub(/^# enum lifecycle: /, ""); print }' "$enum_template")
ca_kind_count=$(printf '%s\n' "$ca_kind_values" | awk 'NF { n++ } END { print n + 0 }')
ca_lifecycle_count=$(printf '%s\n' "$ca_lifecycle_values" | awk 'NF { n++ } END { print n + 0 }')
[ "$ca_kind_count" -eq 1 ] && [ "$ca_lifecycle_count" -eq 1 ] \
  || die2 "kind/lifecycle 枚举权威各须恰一行: $enum_template"

t_dir=${TMPDIR:-/tmp}
ca_entries=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
ca_managed=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
ca_scan=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
ca_unreg_list=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
cleanup() { rm -f "$ca_entries" "$ca_managed" "$ca_scan" "$ca_unreg_list"; }
trap cleanup EXIT HUP INT TERM

# ---- 对账数据块（票 59 D2 定谳；受管口径与协议豁免唯一承载点，引擎零目录硬编码；
#      路径字面值见头部路径常量区，票 111 波②）----
# ca_managed_file <repo-root 相对路径>       受管根单文件（存在才进反向清单）
# ca_managed_tree <目录> <扩展名逗号清单>     受管目录（递归，按扩展名过滤）
# ca_managed_flat <目录> <扩展名逗号清单>     受管目录（单层，按扩展名过滤；rules/facts
#                                              布局下无数据块调用方，引擎段已移除）
# ca_exempt <路径>                           反向豁免：精确路径；尾斜杠＝目录整支豁免
# ca_lazy <路径>                             正向暂缺许可：登记目标允许尚不存在（懒创建面）
# 注记（票 72 豁免迁移）：校准类豁免（docs/architecture/generated/，机器生成投影面）
# 已迁入仓根 delivery.rules calibration 节 dp_artifact_exempt——逐仓不同的校准＝项目
# 约定（设计票 §2 分界判据）；本数据块仅保留记录层通用语义的协议豁免（基线五项）。
load_reconcile_data() {
  ca_managed_file AGENTS.md
  ca_managed_tree "$rules_dir" md,json,jsonl,yaml,sh,rules
  ca_managed_tree "$facts_dir" md,json,jsonl,yaml
  # 协议豁免（票 59 基线五项：记录层通用语义＝协议面留引擎，理由注记＝维护时不得
  # 静默增删；校准豁免见 delivery.rules calibration 节）：
  ca_exempt "$requirements_runs"          # 运行记录投影（整目录，R25）
  ca_exempt "$progress_current"           # 生成投影（生成器独占写，R13）
  ca_exempt "$issues_index"               # 状态真相源单写面（R15）
  ca_exempt "$changes_jsonl"              # 追加面账本（R11）
  ca_exempt "$micro_jsonl"                # 道账本（懒创建追加面，R12）
  # 懒创建面（登记允许暂缺，票 59 校准：微账本由道脚本首次收尾懒创建）：
  ca_lazy "$micro_jsonl"
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
# ca_managed_flat 指令处理函数已随 rules/facts 布局适配移除（票 113：双递归树收敛，
# 单层平面扫描无数据块调用方）。
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
  # 注：flat 分支保留（scan_ext_files 通用形态），rules/facts 布局仅走 tree 分支。
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
# 共享解析器加载（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh；缺件或版本漂移
# fail-closed exit 2 指名，不内嵌副本；定义载入在此、消费在对账数据块装载后的 calibration 节）
_dp_parser_file=$(dirname "$0")/dp-load-rules.sh
if [ -f "$_dp_parser_file" ]; then
  # shellcheck source=agent-up/scripts/dp-load-rules.sh  # 路径动态计算，显式声明基线位置
  . "$_dp_parser_file"
else
  die2 "共享解析器缺失: ${_dp_parser_file}（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh，与消费件同目录分发）"
fi
if [ "${DP_PARSER_VERSION:-0}" -lt 2 ]; then
  die2 "共享解析器版本漂移: $_dp_parser_file 版本 ${DP_PARSER_VERSION:-（未声明）} 低于本件最低要求 2（请与包内同件同步）"
fi

load_reconcile_data

# 校准豁免自 delivery.rules calibration 节读取（票 72 迁移；解析破坏 exit 2；文件缺失
# 或无 dp_artifact_exempt 行＝豁免消失，生成面文件按未登记 FAIL 暴露，fail-closed 不静默）
if ! dp_load_rules "$repo_root" 'check-artifacts'; then
  exit 2
fi
if [ -n "$DP_EXEMPT" ]; then
  while IFS= read -r _dpx; do
    [ -n "$_dpx" ] || continue
    ca_exempt "$_dpx"
  done <<DP_EXEMPT_INNER
$DP_EXEMPT
DP_EXEMPT_INNER
fi

# ---- 登记解析（fail-closed：结构破坏 exit 2 不产生部分结论）----
# 口径：artifacts: 顶层键恰一；条目行＝两空格缩进「- id: 」；path 行＝四空格缩进
# 「path: 」；每条目恰一 path 行且值非空、不含 ASCII 空白；条目稳定 id 全集唯一
# （重复 id＝解析破坏 exit 2，票 147）；path 值剥离首个全角左括注
# （聚合登记的中文说明尾注）与其后全部内容；kind/lifecycle 依模板各自唯一的
# enum 行校验；path 比较折叠重复 /、. 和可消解的 .. 段并去尾 /；其他缩进字段
# 行忽略；未知形态行即解析破坏。
ca_bad=$(LC_ALL=C awk -v kind_values="$ca_kind_values" -v lifecycle_values="$ca_lifecycle_values" '
  function bad(msg) { printf "ERR: 第 %d 行: %s\n", FNR, msg; n++ }
  function normalize_path(path, parts, count, i, value, result, depth, stack) {
    count = split(path, parts, "/")
    depth = 0
    for (i = 1; i <= count; i++) {
      value = parts[i]
      if (value == "" || value == ".") continue
      if (value == ".." && depth > 0 && stack[depth] != "..") {
        delete stack[depth]
        depth--
        continue
      }
      stack[++depth] = value
    }
    for (i = 1; i <= depth; i++) result = result (i == 1 ? "" : "/") stack[i]
    return result == "" ? "." : result
  }
  function allowed(field, value, values, count, i) {
    count = split(field == "kind" ? kind_values : lifecycle_values, values, " ")
    for (i = 1; i <= count; i++) if (values[i] == value) return 1
    return 0
  }
  /^artifacts:[[:space:]]*$/ { top = 1; next }
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  /^  - id: / {
    if (curid != "") {
      if (!curpath) bad("条目缺 path 字段: " curid)
      if (!curkind) bad("条目缺 kind 字段: " curid)
      if (!curlifecycle) bad("条目缺 lifecycle 字段: " curid)
    }
    curid = substr($0, 9)
    sub(/[[:space:]]+$/, "", curid)
    if (curid == "") bad("条目 id 为空")
    else if (curid in seenid) bad("条目 id 重复: " curid "（首见行 " seenid[curid] "）")
    else seenid[curid] = FNR
    nent++
    curpath = ""
    curkind = ""
    curlifecycle = ""
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
    else {
      curpath = v
      normalized = normalize_path(v)
      if (normalized in seenpath) bad("规范化 path 重复: " curid " 与 " seenpath[normalized] " → " normalized)
      else seenpath[normalized] = curid
      printf "%s\t%s\n", curid, v
    }
    next
  }
  /^    kind: / {
    if (curid == "") { bad("kind 字段在条目外"); next }
    if (curkind != "") { bad("条目重复 kind 字段: " curid); next }
    value = substr($0, 11)
    sub(/[[:space:]]+$/, "", value)
    if (value == "") bad("条目 kind 值为空: " curid)
    else if (!allowed("kind", value)) bad("条目 kind 未知: " curid "=" value)
    curkind = value
    next
  }
  /^    lifecycle: / {
    if (curid == "") { bad("lifecycle 字段在条目外"); next }
    if (curlifecycle != "") { bad("条目重复 lifecycle 字段: " curid); next }
    value = substr($0, 16)
    sub(/[[:space:]]+$/, "", value)
    if (value == "") bad("条目 lifecycle 值为空: " curid)
    else if (!allowed("lifecycle", value)) bad("条目 lifecycle 未知: " curid "=" value)
    curlifecycle = value
    next
  }
  /^[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*:/ { next }
  { bad("无法解析的行: " substr($0, 1, 40)) }
  END {
    if (curid != "") {
      if (!curpath) bad("条目缺 path 字段: " curid)
      if (!curkind) bad("条目缺 kind 字段: " curid)
      if (!curlifecycle) bad("条目缺 lifecycle 字段: " curid)
    }
    if (!top) bad("缺 artifacts: 顶层键")
    if (nent == 0) bad("零条目")
    if (n > 0) exit 1
  }
' "$yaml") || ca_parse_rc=$?
if [ "${ca_parse_rc:-0}" -ne 0 ]; then
  printf 'check-artifacts: 错误：登记解析破坏（fail-closed，不产生部分结论）: %s\n' "$artifacts_yaml" >&2
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
          # shellcheck disable=SC2254  # case 模式变量＝目录前缀豁免的刻意 glob 匹配（登记数据受控）
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
          # shellcheck disable=SC2254  # case 模式变量＝目录前缀豁免的刻意 glob 匹配（登记数据受控）
        case $_f in
          $_p) return 0 ;;
        esac
        ;;
    esac
  done
  IFS=$_oifs
  return 1
}

# ---- 栅栏 worktree 识别（R-DP-036 同款，口径同 check-package 检查 8/9）----
# worktree-add.sh 按主检出 delivery.rules dp_mainonly 物理排除 main-only 件；链接 worktree
# 内这些登记目标不在场属栅栏语义而非缺失——正向审计对其 SKIP 不计缺失（主检出不受影响，
# 仍 fail-closed 指名缺失）。判别＝git-dir ≠ git-common-dir；dp_mainonly 取自主检出根。
ca_in_worktree=0
ca_mainonly=''
if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  _ca_gd=$(git -C "$repo_root" rev-parse --git-dir 2>/dev/null)
  _ca_cd=$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)
  case $_ca_gd in /*) : ;; *) _ca_gd="$repo_root/$_ca_gd" ;; esac
  case $_ca_cd in /*) : ;; *) _ca_cd="$repo_root/$_ca_cd" ;; esac
  _ca_gd=$(CDPATH='' cd "$_ca_gd" 2>/dev/null && pwd)
  _ca_cd=$(CDPATH='' cd "$_ca_cd" 2>/dev/null && pwd)
  if [ -n "$_ca_gd" ] && [ -n "$_ca_cd" ] && [ "$_ca_gd" != "$_ca_cd" ]; then
    _ca_main_root=$(dirname "$_ca_cd")
    if [ -f "$_ca_main_root/delivery.rules" ]; then
      ca_mainonly=$(LC_ALL=C awk '/^dp_mainonly / { print $2 }' "$_ca_main_root/delivery.rules")
      [ -n "$ca_mainonly" ] && ca_in_worktree=1
    fi
  fi
fi

# ---- 正向：登记目标存在性 ----
ca_targets=0
ca_fencedskip=0
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
  elif [ "$ca_in_worktree" -eq 1 ] && printf '%s\n' "$ca_mainonly" | LC_ALL=C grep -qxF "$ca_etgt"; then
    ca_fencedskip=$((ca_fencedskip + 1))
    printf 'check-artifacts: SKIP: 条目 %s 登记目标在 worktree 内不在场（R-DP-036 栅栏排除的 main-only 件，主检出照常审计）: %s\n' "$ca_eid" "$ca_etgt"
  else
    ca_missing=$((ca_missing + 1))
    printf 'check-artifacts: FAIL: 条目 %s 登记目标不存在: %s\n' "$ca_eid" "$ca_etgt"
  fi
done < "$ca_entries"

# ---- 反向：受管文件登记覆盖 ----
ca_files=0
ca_unreg=0
ca_exempthit=0
: > "$ca_unreg_list"
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
    printf '%s\n' "$ca_f" >> "$ca_unreg_list"
  fi
done < "$ca_managed"

# ---- --fix 修复形态（票 119；与检测共用同一判定代码——未登记清单即上循环产出）----
# 登记 id 推导：路径去扩展名取末段、非 [a-z0-9-] 字段折叠为单横线（含前导），前缀
# artifact-；十三字段骨架中不可机械推断的值写【按项目填写：...】占位，粘贴前由执行体
# 按实际产物补齐（缺值写 N/A + reason 纪律见 artifacts-yaml.tmpl）；骨架 id 按路径
# 机械推导、不查既有条目——与既有 id 撞名时由执行体改定后再落（复跑本脚本以
# 「条目 id 重复」行零命中为准，票 147 唯一性检查）。
# 单一生成：建议块先写临时文件一次成型，dry-run cat 预览／--apply 追加两用（同一生成
# 代码，禁双实现——预览与落盘逐字一致由同源保证）。
if [ "$ca_fix" -eq 1 ]; then
  if [ ! -s "$ca_unreg_list" ]; then
    printf 'check-artifacts: --fix: 无未登记受管文件，无需修复\n'
  else
    ca_fix_block=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
    cleanup() { rm -f "$ca_entries" "$ca_managed" "$ca_scan" "$ca_unreg_list" "$ca_fix_block"; }
    while IFS= read -r ca_f; do
      [ -n "$ca_f" ] || continue
      ca_fid=$(printf '%s' "${ca_f%.*}" | tr '/' '\n' | tail -n 1 | sed 's/[^a-z0-9-][^a-z0-9-]*/-/g; s/^-*//; s/-*$//')
      [ -n "$ca_fid" ] || ca_fid=artifact
      {
        printf '  - id: artifact-%s\n' "$ca_fid"
        printf '    path: %s\n' "$ca_f"
        printf '    kind: 【按项目填写：governance/index/record/script 等；新增值先在 artifacts-yaml.tmpl 注释区登记】\n'
        printf '    authority: 【按项目填写：权威层级第 N 级（理由）】\n'
        printf '    owner: 【按项目填写：唯一写入者】\n'
        printf '    lifecycle: 【按项目填写：Seed/Conditional/Record/Derived/Adapter】\n'
        printf '    trigger: 【按项目填写：创建触发条件】\n'
        printf '    read_when: 【按项目填写：读取时机】\n'
        printf '    sync_on: 【按项目填写：契约/拓扑/行为/派生/无】\n'
        printf '    depends_on: []\n'
        printf '    generated_from: N/A + reason（非派生件写不适用理由）\n'
        printf '    platform: neutral\n'
        printf '    update_policy: 【按项目填写：更新策略】\n'
        printf '\n'
      } >> "$ca_fix_block"
    done < "$ca_unreg_list"
    if [ "$ca_apply" -eq 1 ]; then
      cat "$ca_fix_block" >> "$yaml"
      printf 'check-artifacts: --apply: 已追加 %d 条登记条目骨架进 %s（占位值须补齐；复跑本脚本核反向缺口归零）\n' \
        "$(wc -l < "$ca_unreg_list" | tr -d ' ')" "$artifacts_yaml"
    else
      printf 'check-artifacts: --fix: %d 个未登记受管文件的登记条目建议块（dry-run 缺省零写入；显式 --apply 追加进 %s）:\n' \
        "$(wc -l < "$ca_unreg_list" | tr -d ' ')" "$artifacts_yaml"
      cat "$ca_fix_block"
    fi
  fi
fi

printf 'check-artifacts: 正向: 登记目标 %d 个，缺失 %d 个，懒创建暂缺 %d 个\n' \
  "$ca_targets" "$ca_missing" "$ca_lazyskip"
if [ "$ca_fencedskip" -gt 0 ]; then
  printf 'check-artifacts: 正向: 栅栏跳过 %d 个（worktree 内 dp_mainonly 件，主检出照常审计）\n' "$ca_fencedskip"
fi
printf 'check-artifacts: 反向: 受管文件 %d 个，未登记 %d 个，豁免命中 %d 个\n' \
  "$ca_files" "$ca_unreg" "$ca_exempthit"
if [ "$ca_missing" -gt 0 ] || [ "$ca_unreg" -gt 0 ]; then
  printf 'check-artifacts: FAIL（正向缺失 %d，反向未登记 %d）\n' "$ca_missing" "$ca_unreg"
  exit 1
fi
printf 'check-artifacts: PASS\n'
