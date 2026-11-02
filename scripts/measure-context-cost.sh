#!/bin/sh
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
#      先例）＋同目录唯一 JSON 引擎读取基线；用法、退出码与口径表见同目录 README.md 专节。

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

# ---- 会话模式 ----

run_session() {
  if [ -z "$sessions_root" ]; then
    sessions_root=${HOME:-}/.kimi-code/sessions
  fi
  if [ -z "$sessions_root" ] || [ ! -d "$sessions_root" ]; then
    die1 "会话目录不存在: $sessions_root"
  fi

  _stats=$(python3 - "$sessions_root" <<'PY'
import json
import os
import sys

root = sys.argv[1]
files = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames.sort()
    for name in filenames:
        if name == 'wire.jsonl':
            files.append(os.path.join(dirpath, name))
files.sort()


def as_int(value):
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return 0


calls = 0
raw = 0
cache_read = 0
input_added = 0
output = 0
total_tools = 0
zero_tool = 0
one_tool = 0
two_tool = 0
three_tool = 0
big_results = 0
per_file_steps = []

for path in files:
    file_calls = 0
    try:
        handle = open(path, encoding='utf-8', errors='replace')
    except OSError:
        continue
    with handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if not isinstance(obj, dict):
                continue
            kind = obj.get('type')
            if kind == 'usage.record':
                usage = obj.get('usage')
                if not isinstance(usage, dict):
                    usage = {}
                other = as_int(usage.get('inputOther'))
                cache = as_int(usage.get('inputCacheRead'))
                creation = as_int(usage.get('inputCacheCreation'))
                out = as_int(usage.get('output'))
                calls += 1
                file_calls += 1
                raw += other + cache + creation + out
                cache_read += cache
                input_added += other + creation
                output += out
            elif kind == 'agent.message.appended':
                event = obj.get('message')
                msg = event.get('message') if isinstance(event, dict) else None
                if not isinstance(msg, dict):
                    continue
                role = msg.get('role')
                if role == 'assistant':
                    tools = msg.get('toolCalls')
                    if not isinstance(tools, list):
                        tools = []
                    count = len(tools)
                    total_tools += count
                    if count == 0:
                        zero_tool += 1
                    elif count == 1:
                        one_tool += 1
                    elif count == 2:
                        two_tool += 1
                    else:
                        three_tool += 1
                elif role == 'tool':
                    content = msg.get('content')
                    text = ''
                    if isinstance(content, list):
                        for part in content:
                            if isinstance(part, dict) and isinstance(part.get('text'), str):
                                text += part['text']
                    if len(text) > 20000:
                        big_results += 1
    per_file_steps.append(file_calls)

agents = 0
over_250 = 0
dist_le10 = 0
dist_11_50 = 0
dist_51_150 = 0
dist_151_250 = 0
dist_gt250 = 0
for steps in per_file_steps:
    if steps <= 0:
        continue
    agents += 1
    if steps <= 10:
        dist_le10 += 1
    elif steps <= 50:
        dist_11_50 += 1
    elif steps <= 150:
        dist_51_150 += 1
    elif steps <= 250:
        dist_151_250 += 1
    else:
        dist_gt250 += 1
        over_250 += 1

context = (cache_read + input_added) // calls if calls else 0
avg_tools = (total_tools / calls) if calls else 0.0

print('wire_files=%d' % len(files))
print('agents=%d' % agents)
print('calls=%d' % calls)
print('raw=%d' % raw)
print('cache_read=%d' % cache_read)
print('input_added=%d' % input_added)
print('output=%d' % output)
print('context_per_call=%d' % context)
print('tool_calls_per_step=%.2f' % avg_tools)
print('tool_calls_total=%d' % total_tools)
print('tool_results_over_20000=%d' % big_results)
print('agents_over_250_steps=%d' % over_250)
print('steps_zero_tool=%d' % zero_tool)
print('steps_one_tool=%d' % one_tool)
print('steps_two_tool=%d' % two_tool)
print('steps_three_plus_tool=%d' % three_tool)
print('dist_le10=%d' % dist_le10)
print('dist_11_50=%d' % dist_11_50)
print('dist_51_150=%d' % dist_51_150)
print('dist_151_250=%d' % dist_151_250)
print('dist_gt250=%d' % dist_gt250)
PY
  ) || die1 "会话日志聚合失败: $sessions_root"

  wire_files=''
  agents=''
  calls=''
  raw=''
  cache_read=''
  input_added=''
  output=''
  context_per_call=''
  tool_calls_per_step=''
  tool_calls_total=''
  big_results=''
  over_250=''
  zero_tool=''
  one_tool=''
  two_tool=''
  three_tool=''
  dist_le10=''
  dist_11_50=''
  dist_51_150=''
  dist_151_250=''
  dist_gt250=''

  while IFS='=' read -r _k _v; do
    case $_k in
      wire_files) wire_files=$_v ;;
      agents) agents=$_v ;;
      calls) calls=$_v ;;
      raw) raw=$_v ;;
      cache_read) cache_read=$_v ;;
      input_added) input_added=$_v ;;
      output) output=$_v ;;
      context_per_call) context_per_call=$_v ;;
      tool_calls_per_step) tool_calls_per_step=$_v ;;
      tool_calls_total) tool_calls_total=$_v ;;
      tool_results_over_20000) big_results=$_v ;;
      agents_over_250_steps) over_250=$_v ;;
      steps_zero_tool) zero_tool=$_v ;;
      steps_one_tool) one_tool=$_v ;;
      steps_two_tool) two_tool=$_v ;;
      steps_three_plus_tool) three_tool=$_v ;;
      dist_le10) dist_le10=$_v ;;
      dist_11_50) dist_11_50=$_v ;;
      dist_51_150) dist_51_150=$_v ;;
      dist_151_250) dist_151_250=$_v ;;
      dist_gt250) dist_gt250=$_v ;;
    esac
  done <<EOF
$_stats
EOF

  is_int "$wire_files" || die1 "统计结果缺 wire 文件计数: $sessions_root"
  is_int "$calls" || die1 "统计结果缺样本计数: calls"
  if [ "$wire_files" -eq 0 ]; then
    die1 "会话目录无 wire.jsonl: $sessions_root"
  fi
  if [ "$calls" -lt "$min_samples" ]; then
    die1 "样本不足: usage.record 调用数 ${calls} < 阈值 ${min_samples}（缺失项: calls）"
  fi
  for _n in "$raw" "$cache_read" "$input_added" "$output" "$context_per_call" \
    "$big_results" "$over_250"; do
    is_int "$_n" || die1 "统计结果缺整数指标: $_n"
  done
  is_number "$tool_calls_per_step" || die1 "统计结果缺每步工具调用数"

  b_calls='-'
  b_raw='-'
  b_cache_read='-'
  b_input_added='-'
  b_output='-'
  b_context='-'
  b_tools='-'
  b_big='-'
  b_over='-'

  if [ -n "$baseline" ]; then
    [ -f "$baseline" ] || die1 "基线文件不存在: $baseline"
    [ -f "$_engine" ] || die2 "唯一 JSON 引擎缺失: $_engine"
    b_calls=$(baseline_optional calls)
    for _k in raw cache_read input_added output context_per_call tool_calls_per_step \
      tool_results_over_20000 agents_over_250_steps; do
      _bv=$(baseline_get "$_k") || die1 "基线缺指标: $_k"
      case $_k in
        raw) b_raw=$_bv ;;
        cache_read) b_cache_read=$_bv ;;
        input_added) b_input_added=$_bv ;;
        output) b_output=$_bv ;;
        context_per_call) b_context=$_bv ;;
        tool_calls_per_step) b_tools=$_bv ;;
        tool_results_over_20000) b_big=$_bv ;;
        agents_over_250_steps) b_over=$_bv ;;
      esac
    done
    is_int "$b_raw" || die1 "基线指标非整数: raw"
    is_int "$b_cache_read" || die1 "基线指标非整数: cache_read"
    is_int "$b_input_added" || die1 "基线指标非整数: input_added"
    is_int "$b_output" || die1 "基线指标非整数: output"
    is_int "$b_context" || die1 "基线指标非整数: context_per_call"
    is_number "$b_tools" || die1 "基线指标非数字: tool_calls_per_step"
    is_int "$b_big" || die1 "基线指标非整数: tool_results_over_20000"
    is_int "$b_over" || die1 "基线指标非整数: agents_over_250_steps"
  fi

  print_head session "来源=$sessions_root wire=$wire_files"
  print_row raw "$raw" "$b_raw"
  print_row cache_read "$cache_read" "$b_cache_read"
  print_row input_added "$input_added" "$b_input_added"
  print_row output "$output" "$b_output"
  print_row context_per_call "$context_per_call" "$b_context"
  print_row tool_calls_per_step "$tool_calls_per_step" "$b_tools" float
  print_row tool_results_over_20000 "$big_results" "$b_big"
  print_row agents_over_250_steps "$over_250" "$b_over"
  printf '样本: calls=%s 阈值=%s 基线calls=%s agent数=%s 工具调用总数=%s\n' \
    "$calls" "$min_samples" "$b_calls" "$agents" "$tool_calls_total"
  printf '每步工具调用分布: 0个=%s 1个=%s 2个=%s 3个+=%s\n' \
    "$zero_tool" "$one_tool" "$two_tool" "$three_tool"
  printf '每agent步数分布: <=10=%s 11-50=%s 51-150=%s 151-250=%s >250=%s\n' \
    "$dist_le10" "$dist_11_50" "$dist_51_150" "$dist_151_250" "$dist_gt250"
}

# ---- 治理体积模式 ----

run_governance() {
  if [ -z "$templates_dir" ]; then
    templates_dir=$script_dir/../references/templates
  fi
  if [ ! -d "$templates_dir" ]; then
    die1 "模板目录不存在: $templates_dir"
  fi
  templates_dir=$(CDPATH='' cd -- "$templates_dir" && pwd -P) || die1 "模板目录不可判定: $templates_dir"

  _gov_files='AGENTS.md.tmpl core.md.tmpl project.md.tmpl assessment.md.tmpl discipline.md.tmpl agents-triage.md.tmpl agents-implementation.md.tmpl agents-review.md.tmpl agents-commit.md.tmpl'
  for _f in $_gov_files; do
    [ -f "$templates_dir/$_f" ] || die1 "安装件缺失: $templates_dir/$_f"
  done

  _install_chars=0
  _install_blocks=0
  for _f in $_gov_files; do
    _n=$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$templates_dir/$_f") \
      || die1 "安装件不可读: $templates_dir/$_f"
    is_int "$_n" || die1 "安装件字符数异常: $templates_dir/$_f"
    _install_chars=$((_install_chars + _n))
    _b=$(grep -c '^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]' "$templates_dir/$_f" 2>/dev/null || true)
    [ -n "$_b" ] || _b=0
    _install_blocks=$((_install_blocks + _b))
  done

  _stage_sum() {
    _ss_sum=0
    for _ss_f in "$@"; do
      _ss_n=$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$templates_dir/$_ss_f") \
        || die1 "安装件不可读: $templates_dir/$_ss_f"
      _ss_sum=$((_ss_sum + _ss_n))
    done
    printf '%s' "$_ss_sum"
  }

  _triage=$(_stage_sum AGENTS.md.tmpl core.md.tmpl assessment.md.tmpl project.md.tmpl agents-triage.md.tmpl)
  _implementation=$(_stage_sum AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-implementation.md.tmpl)
  _review=$(_stage_sum AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-review.md.tmpl)
  _commit=$(_stage_sum AGENTS.md.tmpl core.md.tmpl project.md.tmpl agents-commit.md.tmpl)

  b_install_chars='-'
  b_install_blocks='-'
  b_triage='-'
  b_implementation='-'
  b_review='-'
  b_commit='-'

  if [ -n "$baseline" ]; then
    [ -f "$baseline" ] || die1 "基线文件不存在: $baseline"
    [ -f "$_engine" ] || die2 "唯一 JSON 引擎缺失: $_engine"
    for _k in install_chars install_blocks stage_triage_chars stage_implementation_chars \
      stage_review_chars stage_commit_chars; do
      _bv=$(baseline_get "$_k") || die1 "基线缺指标: $_k"
      is_int "$_bv" || die1 "基线指标非整数: $_k"
      case $_k in
        install_chars) b_install_chars=$_bv ;;
        install_blocks) b_install_blocks=$_bv ;;
        stage_triage_chars) b_triage=$_bv ;;
        stage_implementation_chars) b_implementation=$_bv ;;
        stage_review_chars) b_review=$_bv ;;
        stage_commit_chars) b_commit=$_bv ;;
      esac
    done
  fi

  print_head governance "模板=$templates_dir"
  print_row install_chars "$_install_chars" "$b_install_chars"
  print_row install_blocks "$_install_blocks" "$b_install_blocks"
  print_row stage_triage_chars "$_triage" "$b_triage"
  print_row stage_implementation_chars "$_implementation" "$b_implementation"
  print_row stage_review_chars "$_review" "$b_review"
  print_row stage_commit_chars "$_commit" "$b_commit"
  printf '口径: 安装件=%s 件 字符数=python3 len(UTF-8 文本) 规则块=^#### R-XX-NNN\n' '9'
}

case $mode in
  session) run_session ;;
  governance) run_governance ;;
esac

exit 0
