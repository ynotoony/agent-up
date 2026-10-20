#!/bin/sh
# Input: workflow YAML 文件路径 + 参数（如 --param ticket_id=165）
# Output: 执行 workflow 的 steps，每个 step 完成后写入 checkpoint（原子化），支持中断恢复
# Pos: 工作流执行器（票 166）；解析 agent-up/references/schemas/workflow.schema.json v2 格式的 YAML
#      文件，执行 agent/command/verification 三种步骤类型，步骤级 checkpoint 原子化落盘
#      （每个 step 完成立即写入票文件的 checkpoint 字段），中断后从 checkpoint 恢复执行

set -eu

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/workflow-executor.sh <workflow.yaml> [options]
参数:
  workflow.yaml    工作流定义文件（基于 workflow.schema.json v2）
选项:
  --param <key=value>     输入参数（可多次指定）
  --ticket-file <path>    票文件路径（用于写入 checkpoint）
  --resume                从 checkpoint 恢复（跳过已完成的 steps）
  --retry <step_id>       重试指定 step（幂等重新执行）
  -h / --help             打印本用法
退出码: 0 成功；1 执行失败；2 用法错误
USAGE
}

die1() {
  printf 'workflow-executor: FAIL: %s\n' "$1" >&2
  exit 1
}

die2() {
  printf 'workflow-executor: %s\n' "$1" >&2
  exit 2
}

# ---- 参数解析 ----

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
  *)
    workflow_file=$1
    shift
    ;;
esac

[ -f "${workflow_file}" ] || die2 "workflow 文件不存在: ${workflow_file}"

# 解析选项
params_list=""  # 使用空格分隔的字符串代替关联数组
ticket_file=''
resume_mode=false
retry_step=""

while [ $# -gt 0 ]; do
  case $1 in
    --param)
      shift
      [ $# -ge 1 ] || die2 "--param 需要参数"
      # 解析 key=value
      params_list="$params_list $1"
      shift
      ;;
    --ticket-file)
      shift
      [ $# -ge 1 ] || die2 "--ticket-file 需要参数"
      ticket_file=$1
      shift
      ;;
    --resume)
      resume_mode=true
      shift
      ;;
    --retry)
      shift
      [ $# -ge 1 ] || die2 "--retry 需要参数"
      retry_step=$1
      shift
      ;;
    *)
      die2 "未知选项: $1"
      ;;
  esac
done

# ---- YAML 解析器（简化版：仅支持 workflow.schema.json v2 格式）----

# 简化 YAML 解析（仅支持基本格式，零外部依赖）
# 提取 steps 信息：id, type, description, checkpoint_field, agent/command/verification
parse_workflow_steps() {
  # 使用 Python 解析 YAML（使用 json 模块模拟简单 YAML）
  python3 - "$workflow_file" <<'PYTHON'
import sys
import json
import re

workflow_file = sys.argv[1]

with open(workflow_file, 'r') as f:
  content = f.read()

# 简化 YAML 解析：提取 steps 数组
steps = []
in_steps = False
current_step = None
indent_stack = []

for line in content.splitlines():
  stripped = line.lstrip()
  indent = len(line) - len(stripped)

  if stripped.startswith('steps:'):
    in_steps = True
    indent_stack = [indent]
    continue

  if in_steps:
    # 检测步骤开始（- id:）
    if re.match(r'^- id:', stripped):
      if current_step:
        steps.append(current_step)
      current_step = {}
      indent_stack = [indent]
      # 提取 id
      current_step['id'] = stripped.split(':', 1)[1].strip()

    # 检测非步骤的顶层键（state_machine 等）
    elif indent == 0 and stripped and not stripped.startswith('-'):
      # 退出 steps 块
      if current_step:
        steps.append(current_step)
        current_step = None  # 清空，避免循环结束后重复 append
      break

    # 解析步骤字段
    elif current_step is not None and stripped:
      if ':' in stripped:
        key, value = stripped.split(':', 1)
        key = key.strip()
        value = value.strip()

        if key in ['type', 'description', 'checkpoint_field', 'agent', 'command']:
          current_step[key] = value
        elif key == 'verification':
          # verification 是数组，需要特殊处理
          current_step['verification'] = []
        elif key in ['name', 'check', 'expect', 'fail_msg', 'description'] and 'verification' in current_step:
          # verification 子项
          if not current_step['verification'] or (key == 'name'):
            current_step['verification'].append({})
          if key == 'description':
            key = 'verify_description'  # 避免与 step description 冲突
          current_step['verification'][-1][key] = value

if current_step:
  steps.append(current_step)

print(json.dumps(steps))
PYTHON
}

steps_json=$(parse_workflow_steps) || die1 "YAML 解析失败"

steps_count=$(echo "$steps_json" | python3 -c "
import sys, json
steps = json.load(sys.stdin)
print(len(steps))")

printf 'workflow-executor: 解析到 %d 个 steps\n' "$steps_count"

# ---- State Machine 解析 ----

# 解析 state_machine 定义（states + transitions）
parse_state_machine() {
  python3 - "$workflow_file" <<'PYTHON'
import sys
import json
import re

workflow_file = sys.argv[1]

with open(workflow_file, 'r') as f:
  content = f.read()

# 简化 YAML 解析：提取 state_machine 块
state_machine = {
  "initial_state": "",
  "states": [],
  "transitions": []
}

in_state_machine = False
in_states = False
in_transitions = False
current_state = None
current_transition = None

for line in content.splitlines():
  stripped = line.lstrip()
  indent = len(line) - len(stripped)

  if stripped.startswith('state_machine:'):
    in_state_machine = True
    continue

  if in_state_machine:
    # 检测退出 state_machine 块
    if indent == 0 and stripped and not stripped.startswith(' '):
      break

    if stripped.startswith('initial_state:'):
      state_machine['initial_state'] = stripped.split(':', 1)[1].strip()

    elif stripped.startswith('states:'):
      in_states = True
      in_transitions = False
      continue

    elif stripped.startswith('transitions:'):
      in_transitions = True
      in_states = False
      continue

    # 解析 states 数组
    elif in_states and re.match(r'^- name:', stripped):
      if current_state:
        state_machine['states'].append(current_state)
      current_state = {}
      current_state['name'] = stripped.split(':', 1)[1].strip()

    elif in_states and current_state is not None and ':' in stripped:
      key, value = stripped.split(':', 1)
      key = key.strip()
      value = value.strip()
      if key in ['description', 'terminal']:
        if key == 'terminal':
          current_state[key] = value.lower() in ['true', 'yes']
        else:
          current_state[key] = value

    # 解析 transitions 数组
    elif in_transitions and re.match(r'^- from:', stripped):
      if current_transition:
        state_machine['transitions'].append(current_transition)
      current_transition = {}
      current_transition['from'] = stripped.split(':', 1)[1].strip()

    elif in_transitions and current_transition is not None and ':' in stripped:
      key, value = stripped.split(':', 1)
      key = key.strip()
      value = value.strip()
      if key in ['to', 'condition', 'trigger']:
        current_transition[key] = value

# 添加最后一个项
if current_state:
  state_machine['states'].append(current_state)
if current_transition:
  state_machine['transitions'].append(current_transition)

print(json.dumps(state_machine))
PYTHON
}

state_machine_json=$(parse_state_machine) || die1 "State Machine 解析失败"

printf 'workflow-executor: 解析到 state_machine 定义\n'

# ---- State Machine Executor ----

# 读取当前票状态（从 index.json）
get_current_status() {
  ticket_id=$1
  index_file="${issues_index_rel:-facts/requirements/tickets/index.json}"

  if [ ! -f "$index_file" ]; then
    echo "unknown"
    return
  fi

  python3 - "$index_file" "$ticket_id" <<'PYTHON'
import sys, json
index_file = sys.argv[1]
ticket_id = sys.argv[2]

with open(index_file, 'r') as f:
  data = json.load(f)

for issue in data.get('issues', []):
  if issue.get('id') == ticket_id:
    print(issue.get('status', 'unknown'))
    sys.exit(0)

print('unknown')
PYTHON
}

# 验证状态转换是否合法（根据 state_machine 定义）
validate_transition() {
  from_state=$1
  to_state=$2

  # 检查转换是否在 transitions 列表中
  python3 - "$from_state" "$to_state" <<PYTHON
import sys, json

from_state = sys.argv[1]
to_state = sys.argv[2]
state_machine = json.loads('''$state_machine_json''')

for transition in state_machine.get('transitions', []):
  if transition.get('from') == from_state and transition.get('to') == to_state:
    print('valid')
    sys.exit(0)

print('invalid')
PYTHON
}

# 评估转换条件是否满足
evaluate_condition() {
  condition=$1

  # 机械化条件判定
  case $condition in
    workflow_started)
      # workflow 已启动（总是 true）
      echo "true"
      ;;
    all_verifications_pass)
      # 所有验证通过（检查最近的 verification step 是否通过）
      # 这里简化实现：如果有 checkpoint 记录说明通过
      if [ -n "$checkpoint_data" ]; then
        echo "true"
      else
        echo "false"
      fi
      ;;
    checkpoint.*)
      # 检查 checkpoint 字段是否存在
      field_path=$condition
      result=$(echo "$checkpoint_data" | python3 -c "
import sys, json
checkpoint = json.load(sys.stdin)
field = '$field_path'.replace('checkpoint.', '')
parts = field.split('.')
data = checkpoint
for part in parts:
  if isinstance(data, dict) and part in data:
    data = data[part]
  else:
    print('false')
    sys.exit(0)
print('true' if data else 'false')")
      echo "$result"
      ;;
    verification_failed)
      # 验证失败（与 all_verifications_pass 相反）
      echo "false"
      ;;
    manual_retry)
      # 手动重试（由用户触发，这里默认 false）
      echo "false"
      ;;
    *)
      # 未知条件，默认 false
      printf 'workflow-executor: 警告：未知条件 %s\n' "$condition" >&2
      echo "false"
      ;;
  esac
}

# 原子化更新票状态（使用临时文件 + mv）
update_status() {
  ticket_id=$1
  new_status=$2
  index_file="${issues_index_rel:-facts/requirements/tickets/index.json}"

  if [ ! -f "$index_file" ]; then
    die1 "index.json 不存在: $index_file"
  fi

  printf '  状态转换: %s → %s\n' "$(get_current_status "$ticket_id")" "$new_status"

  # 使用 Python 原子化更新
  python3 - "$index_file" "$ticket_id" "$new_status" <<'PYTHON'
import sys, json, tempfile, os
from datetime import datetime

index_file = sys.argv[1]
ticket_id = sys.argv[2]
new_status = sys.argv[3]

# 读取索引
with open(index_file, 'r') as f:
  data = json.load(f)

# 查找并更新票状态
found = False
for issue in data.get('issues', []):
  if issue.get('id') == ticket_id:
    issue['status'] = new_status
    issue['updated_at'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M')
    found = True
    break

if not found:
  print(f'FAIL: 票 {ticket_id} 不在索引中', file=sys.stderr)
  sys.exit(1)

# 原子化写入（临时文件 + mv）
index_dir = os.path.dirname(index_file)
with tempfile.NamedTemporaryFile('w', dir=index_dir, delete=False, suffix='.json') as tmp_f:
  json.dump(data, tmp_f, indent=2, ensure_ascii=False)
  tmp_f.write('\n')
  tmp_name = tmp_f.name

os.rename(tmp_name, index_file)
print(f'状态已更新: {new_status}')
PYTHON

  # shellcheck disable=SC2181  # here-document 退出码必须通过 $? 检查，无法内联
  if [ $? -ne 0 ]; then
    die1 "状态更新失败"
  fi
}

# 尝试推进状态机（检查所有可能的转换）
try_advance_state() {
  ticket_id=$1
  current_status=$(get_current_status "$ticket_id")

  printf '\nworkflow-executor: 检查状态机转换（当前状态: %s）\n' "$current_status"

  # 遍历所有转换，查找当前状态可触发的转换
  transitions_count=$(echo "$state_machine_json" | python3 -c "
import sys, json
sm = json.load(sys.stdin)
print(len(sm.get('transitions', [])))")

  trans_idx=0
  while [ "$trans_idx" -lt "$transitions_count" ]; do
    transition=$(echo "$state_machine_json" | python3 -c "
import sys, json
sm = json.load(sys.stdin)
print(json.dumps(sm['transitions'][$trans_idx]))" "$trans_idx")

    from_state=$(echo "$transition" | python3 -c "
import sys, json
t = json.load(sys.stdin)
print(t.get('from', ''))")

    to_state=$(echo "$transition" | python3 -c "
import sys, json
t = json.load(sys.stdin)
print(t.get('to', ''))")

    condition=$(echo "$transition" | python3 -c "
import sys, json
t = json.load(sys.stdin)
print(t.get('condition', ''))")

    # 检查是否匹配当前状态
    if [ "$from_state" = "$current_status" ]; then
      # 评估条件
      condition_result=$(evaluate_condition "$condition")

      if [ "$condition_result" = "true" ]; then
        printf '  条件满足: %s → %s (条件: %s)\n' "$from_state" "$to_state" "$condition"

        # 验证转换合法性
        if [ "$(validate_transition "$from_state" "$to_state")" = "valid" ]; then
          # 执行状态转换
          update_status "$ticket_id" "$to_state"
          return 0
        else
          printf '  警告：非法状态转换 %s → %s\n' "$from_state" "$to_state" >&2
        fi
      fi
    fi

    trans_idx=$((trans_idx + 1))
  done

  printf '  无可用状态转换\n'
  return 1
}

# ---- Checkpoint 读取与恢复 ----

# 读取已完成的 steps（从 ticket JSON 的 checkpoint 字段）
read_checkpoint() {
  if [ -z "$ticket_file" ] || [ ! -f "$ticket_file" ]; then
    echo "{}"
    return
  fi

  python3 - "$ticket_file" <<'PYTHON'
import sys, json
ticket_file = sys.argv[1]
with open(ticket_file, 'r') as f:
  ticket = json.load(f)
checkpoint = ticket.get('checkpoint', {})
print(json.dumps(checkpoint))
PYTHON
}

checkpoint_data=$(read_checkpoint)

# 恢复模式日志输出
if [ "$resume_mode" = true ]; then
  printf '\nworkflow-executor: 恢复模式启用（从 checkpoint 恢复）\n'

  # 统计已完成的 steps
  completed_count=$(echo "$checkpoint_data" | python3 -c "
import sys, json
checkpoint = json.load(sys.stdin)
count = 0
def count_completed(data):
    global count
    if isinstance(data, dict):
        if 'completed_at' in data:
            count += 1
        for v in data.values():
            count_completed(v)
count_completed(checkpoint)
print(count)")

  printf '  已完成 steps: %d\n' "$completed_count"
fi

if [ -n "$retry_step" ]; then
  printf '\nworkflow-executor: 幂等重试模式（重新执行 step: %s）\n' "$retry_step"
fi

# ---- 步骤执行循环 ----

i=0
while [ "$i" -lt "$steps_count" ]; do
  # 提取当前 step 的元数据
  step_json=$(echo "$steps_json" | python3 -c "
import sys, json
steps = json.load(sys.stdin)
print(json.dumps(steps[$i]))" "$i")

  step_id=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('id', ''))")

  step_type=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('type', ''))")

  step_desc=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('description', ''))")

  checkpoint_field=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('checkpoint_field', ''))")

  # 中断恢复：检查是否已完成
  if [ "$resume_mode" = true ]; then
    step_completed=$(echo "$checkpoint_data" | python3 -c "
import sys, json
checkpoint = json.load(sys.stdin)
field = '$checkpoint_field'.split('.')
data = checkpoint
for key in field[1:]:  # 跳过 'checkpoint' 前缀
  data = data.get(key, {})
print('true' if isinstance(data, dict) and 'completed_at' in data else 'false')")

    if [ "$step_completed" = "true" ]; then
      printf 'workflow-executor: 跳过已完成的 step: %s\n' "$step_id"
      i=$((i + 1))
      continue
    else
      printf 'workflow-executor: 从此 step 继续执行: %s\n' "$step_id"
    fi
  fi

  # 幂等重试：如果指定了 --retry，只执行该 step
  if [ -n "$retry_step" ]; then
    if [ "$step_id" != "$retry_step" ]; then
      i=$((i + 1))
      continue
    fi
    printf 'workflow-executor: 幂等重试 step: %s\n' "$step_id"
  fi

  printf '\nworkflow-executor: 执行 step %d/%d: %s (%s)\n' $((i + 1)) "$steps_count" "$step_id" "$step_type"
  printf '  描述: %s\n' "$step_desc"

  # 执行步骤（根据类型）
  step_outputs=""
  step_exit_code=0

  case $step_type in
    command)
      command_str=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('command', ''))")

      printf '  命令: %s\n' "$command_str"
      step_outputs=$(eval "$command_str" 2>&1) || step_exit_code=$?

      if [ $step_exit_code -ne 0 ]; then
        printf 'workflow-executor: 命令执行失败 (退出码 %d)\n' $step_exit_code >&2
        die1 "step $step_id 失败"
      fi
      ;;

    verification)
      verification_json=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(json.dumps(step.get('verification', [])))")

      verification_count=$(echo "$verification_json" | python3 -c "
import sys, json
verifications = json.load(sys.stdin)
print(len(verifications))")

      printf '  验证项数: %d\n' "$verification_count"

      j=0
      all_pass=true
      while [ "$j" -lt "$verification_count" ]; do
        verify_item=$(echo "$verification_json" | python3 -c "
import sys, json
verifications = json.load(sys.stdin)
print(json.dumps(verifications[$j]))" "$j")

        verify_name=$(echo "$verify_item" | python3 -c "
import sys, json
item = json.load(sys.stdin)
print(item.get('name', ''))")

        verify_check=$(echo "$verify_item" | python3 -c "
import sys, json
item = json.load(sys.stdin)
print(item.get('check', ''))")

        verify_expect=$(echo "$verify_item" | python3 -c "
import sys, json
item = json.load(sys.stdin)
print(item.get('expect', ''))")

        printf '  验证 %d/%d: %s\n' $((j + 1)) "$verification_count" "$verify_name"

        actual_output=$(eval "$verify_check" 2>&1) || true

        # 移除 expect 中的引号（支持 "PASS" 和 PASS 两种写法）
        expect_clean=$(echo "$verify_expect" | sed 's/^"\(.*\)"$/\1/')

        if echo "$actual_output" | grep -qF "$expect_clean"; then
          printf '    ✓ 通过\n'
        else
          printf '    ✗ 失败\n' >&2
          printf '    期望: %s\n' "$expect_clean" >&2
          printf '    实际: %s\n' "$actual_output" >&2
          all_pass=false
        fi

        j=$((j + 1))
      done

      if [ "$all_pass" = false ]; then
        die1 "step $step_id 验证失败"
      fi
      ;;

    agent)
      agent_path=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('agent', ''))")

      printf '  agent: %s\n' "$agent_path"
      printf '  （agent 调用暂不支持，需宿主集成）\n'
      # TODO: 集成 agent 调用逻辑（需宿主提供 agent 执行器）
      ;;

    *)
      die1 "未知 step 类型: $step_type"
      ;;
  esac

  # ---- 原子化 Checkpoint 写入 ----

  if [ -n "$checkpoint_field" ] && [ -n "$ticket_file" ]; then
    completed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    printf '  写入 checkpoint: %s\n' "$checkpoint_field"

    # 使用 Python 更新 ticket JSON 的 checkpoint 字段
    python3 - "$ticket_file" "$checkpoint_field" "$step_id" "$completed_at" "$step_outputs" <<'PYTHON'
import sys, json
from datetime import datetime

ticket_file = sys.argv[1]
checkpoint_field = sys.argv[2]
step_id = sys.argv[3]
completed_at = sys.argv[4]
step_outputs = sys.argv[5]

# 读取票文件
with open(ticket_file, 'r') as f:
  ticket = json.load(f)

# 确保 checkpoint 字段存在
if 'checkpoint' not in ticket:
  ticket['checkpoint'] = {}

# 解析 checkpoint_field 路径（如 checkpoint.implementation.ticket_parsed）
field_parts = checkpoint_field.split('.')

# 从 checkpoint 根开始导航（跳过第一个 'checkpoint'）
current = ticket['checkpoint']

# 导航到目标位置的父节点
for part in field_parts[1:-1]:
  if part not in current:
    current[part] = {}
  current = current[part]

# 写入步骤级 checkpoint
last_field = field_parts[-1]
current[last_field] = {
  "step_name": step_id,
  "completed_at": completed_at,
  "outputs": step_outputs.strip() if step_outputs else ""
}

# 写回票文件（原子化：先写临时文件，再 rename）
import tempfile, os
ticket_dir = os.path.dirname(ticket_file)
with tempfile.NamedTemporaryFile('w', dir=ticket_dir, delete=False) as tmp_f:
  json.dump(ticket, tmp_f, indent=2, ensure_ascii=False)
  tmp_f.write('\n')
  tmp_name = tmp_f.name

os.rename(tmp_name, ticket_file)
print(f"Checkpoint 已写入: {checkpoint_field}")
PYTHON

    # shellcheck disable=SC2181  # here-document 退出码必须通过 $? 检查，无法内联
    if [ $? -ne 0 ]; then
      die1 "checkpoint 写入失败"
    fi

    # 重新读取 checkpoint（用于状态机条件判定）
    checkpoint_data=$(read_checkpoint)
  fi

  printf '  ✓ step 完成\n'

  # 幂等重试模式：完成目标 step 后立即退出
  if [ -n "$retry_step" ] && [ "$step_id" = "$retry_step" ]; then
    printf '\nworkflow-executor: step %s 执行完成（幂等重试）\n' "$step_id"
    exit 0
  fi

  # ---- 状态机推进 ----
  # 每个 step 完成后，尝试推进状态机
  if [ -n "$ticket_file" ]; then
    # 从 ticket 文件提取 ticket_id
    ticket_id=$(python3 - "$ticket_file" <<'PYTHON'
import sys, json, os
ticket_file = sys.argv[1]
with open(ticket_file, 'r') as f:
  ticket = json.load(f)
print(ticket.get('id', os.path.basename(ticket_file).replace('.json', '')))
PYTHON
)

    if [ -n "$ticket_id" ]; then
      try_advance_state "$ticket_id" || true
    fi
  fi

  i=$((i + 1))
done

printf '\nworkflow-executor: 所有 steps 执行完成\n'
exit 0
