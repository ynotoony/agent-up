#!/bin/sh
# shellcheck disable=SC2034  # 选项变量由同目录模式模块消费（source 方契约：sessions_root／templates_dir）
# shellcheck disable=SC2329  # 共享输出原语由同目录模式模块调用（跨件视野，非本地直调）
# Input: 会话模式（缺省）＝会话根目录（`--sessions <dir>`，缺省 `$HOME/.kimi-code/sessions`）
#        下全部 `wire.jsonl` 的 `usage.record` 记录与 assistant/tool 消息；治理模式
#        （`--governance`）＝安装模板目录（`--templates <dir>`，缺省本脚本上一级
#        `references/templates`）。可选 `--baseline <json>` 基线、`--min-samples <n>`
#        样本阈值（缺省 100，合法下界 1：0 会放过 0 条样本的差值表，按用法错误 exit 2）。
# Output: 只读指标表——会话模式：raw／cache_read／input_added／output／context_per_call／
#        tool_calls_per_step／tool_results_over_20000／agents_over_250_steps 八项当前值，
#        给基线时逐项输出差值（基线−当前，正数＝下降＝收益）与变化率，另附样本计数、
#        每步工具调用分布与每 agent 步数分布；治理模式：install_chars／install_blocks／
#        每阶段读取集字符数四项（四行）当前值与基线差值。输出 ≤40 行；任何缺失项、
#        样本不足或基线缺指标均 exit 非 0 且零 stdout（不输出半套指标）。
# Pos: 成本治理度量面（只读复测工具，不进安装闭包）：指标口径与基线 JSON 逐项同名同
#      单位，会话日志只读零写入、仓库零写入；POSIX sh＋python3 流式聚合（同进程解释器
#      先例）＋同目录唯一 JSON 引擎读取基线；票 290 拆分：会话指标（measure-context-session.sh）
#      与治理指标（measure-context-governance.sh）各自成同目录模块，本件只保留参数解析、
#      共享输出原语与模式分派；用法、退出码与口径表见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：路径展开只经显式变量

prog=measure-context-cost

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf '%s: FAIL: 共享库缺失: %s\n' "$prog" "$_helper_script" >&2
  exit 2
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || die2 '脚本目录不可判定'

usage() {
  cat <<'USAGE'
用法: sh measure-context-cost.sh [选项]
  --sessions <dir>   会话根目录（缺省 $HOME/.kimi-code/sessions）
  --baseline <json>  基线 JSON（键＝指标名，值＝数字；缺省只输出当前值）
  --min-samples <n>  最小 usage.record 样本数（缺省 100；须 ≥1，0 会放过 0 条样本的差值表；低于阈值 exit 1）
  --governance       治理体积模式（安装件字符数／规则块数／每阶段读取集字符数）
  --templates <dir>  治理模式模板目录（缺省本脚本上一级 references/templates）
  -h / --help        打印本用法
输出: 指标表 ≤40 行；差值＝基线−当前，正数＝下降＝收益。
退出码: 0 成功；1 路径或指标缺失、样本不足；2 用法或环境错误。
USAGE
}

mode=session
sessions_root=''
baseline=''
min_samples=100
templates_dir=''

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --sessions) [ $# -ge 2 ] || { usage >&2; exit 2; }; sessions_root=$2; shift 2 ;;
    --baseline) [ $# -ge 2 ] || { usage >&2; exit 2; }; baseline=$2; shift 2 ;;
    --min-samples) [ $# -ge 2 ] || { usage >&2; exit 2; }; min_samples=$2; shift 2 ;;
    --governance) mode=governance; shift ;;
    --templates) [ $# -ge 2 ] || { usage >&2; exit 2; }; templates_dir=$2; shift 2 ;;
    *) printf '%s: 未知参数: %s\n' "$prog" "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case $min_samples in
  ''|*[!0-9]*) printf '%s: --min-samples 须为整数且 ≥1（合法下界 1）: %s\n' "$prog" "$min_samples" >&2; exit 2 ;;
esac
if [ "$min_samples" -lt 1 ]; then
  printf '%s: --min-samples 须为整数且 ≥1（合法下界 1；0 会放过 0 条样本的差值表）: %s\n' "$prog" "$min_samples" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || die2 'python3 不可用——指标聚合与基线读取依赖'

_engine="$script_dir/json-validator.py"

# 基线读取（唯一 JSON 引擎；缺键 exit 3 → 由调用方指名）
baseline_get() {
  python3 "$_engine" json get "$baseline" "$1" 2>/dev/null
}

baseline_optional() {
  python3 "$_engine" json get "$baseline" "$1" '-' 2>/dev/null || printf '%s' '-'
}

is_int() {
  case $1 in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_number() {
  case $1 in
    ''|*[!0-9.]*|.*|*.) return 1 ;;
    *) return 0 ;;
  esac
}

# 输出一行指标：<名> <当前> <基线|-> <差值|-> <变化率|->（差值＝基线−当前）
print_row() {
  _pr_key=$1
  _pr_cur=$2
  _pr_base=$3
  _pr_float=${4:-int}
  if [ "$_pr_base" = '-' ]; then
    printf '%-24s %14s %14s %14s %10s\n' "$_pr_key" "$_pr_cur" '-' '-' '-'
    return 0
  fi
  if [ "$_pr_float" = float ]; then
    _pr_delta=$(awk -v b="$_pr_base" -v c="$_pr_cur" 'BEGIN { printf "%.2f", b - c }')
    _pr_pct=$(awk -v b="$_pr_base" -v c="$_pr_cur" 'BEGIN { if (b == 0) printf "n/a"; else printf "%.1f%%", (b - c) * 100 / b }')
  else
    _pr_delta=$(( _pr_base - _pr_cur ))
    if [ "$_pr_base" -eq 0 ]; then
      _pr_pct='n/a'
    else
      _pr_pct=$(awk -v b="$_pr_base" -v c="$_pr_cur" 'BEGIN { printf "%.1f%%", (b - c) * 100 / b }')
    fi
  fi
  printf '%-24s %14s %14s %14s %10s\n' "$_pr_key" "$_pr_cur" "$_pr_base" "$_pr_delta" "$_pr_pct"
}

print_head() {
  printf 'measure-context-cost: 模式=%s %s\n' "$1" "$2"
  printf '%s\n' '差值＝基线−当前；正数＝下降＝收益（单位与指标同名同单位）'
  printf '%-24s %14s %14s %14s %10s\n' '指标' '当前' '基线' '差值' '变化率'
}
# ---- 指标模式模块（票 290 拆分：会话指标与治理指标分开，同目录定位）----

for _mc_mod in measure-context-session.sh measure-context-governance.sh; do
  _mc_path=$(dirname "$0")/$_mc_mod
  [ -f "$_mc_path" ] || {
    printf '%s: FAIL: 同目录模块缺失: %s\n' "$prog" "$_mc_path" >&2
    exit 2
  }
  # shellcheck source=agent-up/scripts/measure-context-session.sh  # 路径动态计算，显式声明基线位置
  . "$_mc_path"
done


case $mode in
  session) run_session ;;
  governance) run_governance ;;
esac

exit 0
