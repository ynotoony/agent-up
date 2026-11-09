#!/bin/sh
# shellcheck disable=SC2154  # 全局变量与共享原语由 source 方主壳赋值／定义（Input 契约：sessions_root／baseline／min_samples／_engine 与 die1／die2／print_head／print_row 等）
# Input: 由 measure-context-cost.sh 主壳 source 本件——消费其已设选项变量（sessions_root／
#        baseline／min_samples）、_engine（同目录 json-validator.py 路径）与共享输出原语
#        （die1／die2／print_head／print_row／baseline_get／baseline_optional／is_int／is_number）。
# Output: run_session 函数体——会话模式指标（usage.record 八项、样本计数、每步工具调用与
#         每 agent 步数分布）的聚合、校验与 ≤ 行输出；不执行任何动作、不设 set -eu。
# Pos: 会话成本指标实现（票 290 拆分：与会话指标与治理指标分开成两件）；本件为
#      measure-context-cost.sh 的同目录模块（包侧独有，不进安装闭包、不落仓侧镜像）。
#      POSIX sh＋python3 流式聚合。

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
