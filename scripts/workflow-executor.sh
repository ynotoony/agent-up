#!/bin/sh
# Input: workflow YAML 文件路径 + 参数（如 --param ticket_id=165）
# Output: 执行 workflow 的 steps，每个 step 完成后写入外部 checkpoint（原子化），支持中断恢复
# Pos: 工作流执行器（票 166）；解析 agent-up/references/schemas/workflow.schema.json v2 格式的 YAML
#      文件，执行 agent/command/verification 三种步骤类型，步骤级 checkpoint 原子化落盘。
#      checkpoint 与票文件分离，票只保存 checkpoint_ref；中断后从外部 checkpoint 恢复执行。

set -eu

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/workflow-executor.sh <workflow.yaml> [options]
参数:
  workflow.yaml    工作流定义文件（基于 workflow.schema.json v2）
选项:
  --param <key=value>     输入参数（可多次指定）
  --ticket-file <path>    票文件路径（用于保存 checkpoint_ref）
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
      [ -f "$ticket_file" ] || die2 "票文件不存在: $ticket_file"
      ticket_file=$(python3 - "$ticket_file" <<'PYTHON'
import os, sys
path = os.path.abspath(sys.argv[1])
if os.path.islink(path) or not os.path.isfile(path):
    print('workflow-executor: FAIL: 票文件必须是非符号链接普通文件', file=sys.stderr)
    raise SystemExit(1)
print(os.path.realpath(path))
PYTHON
) || die1 "无法规范化票文件路径"
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
      [ -n "$retry_step" ] || die2 "--retry 目标不能为空"
      shift
      ;;
    *)
      die2 "未知选项: $1"
      ;;
  esac
done

if [ "$resume_mode" = true ] && [ -z "$ticket_file" ]; then
  die2 "--resume 需要 --ticket-file"
fi

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
        elif key in ['name', 'check', 'expect', 'expect_exit', 'fail_msg', 'description'] and 'verification' in current_step:
          # verification 子项
          if not current_step['verification'] or (key == 'name'):
            current_step['verification'].append({})
          if key == 'description':
            key = 'verify_description'  # 避免与 step description 冲突
          if key == 'expect_exit' and re.fullmatch(r'-?[0-9]+', value):
            current_step['verification'][-1][key] = int(value)
          else:
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

# Reject unsupported execution before creating or updating checkpoint files.
python3 - "$retry_step" "$steps_json" <<'PYTHON' || die1 "workflow 包含执行器不支持的 step"
import json, re, sys
retry_step, raw_steps = sys.argv[1:]
steps = json.loads(raw_steps)
step_ids = [step.get('id', '') for step in steps]
if len(step_ids) != len(set(step_ids)):
    raise SystemExit('workflow step id 必须唯一')
if retry_step and retry_step not in step_ids:
    raise SystemExit(f"--retry 指定的 step 不存在: {retry_step}")
checkpoint_fields = []
for step in steps:
    field = step.get('checkpoint_field', '')
    if field:
        if not re.fullmatch(r'checkpoint(?:\.[a-z_][a-z0-9_]*)+', field):
            raise SystemExit(f"step {step.get('id', '')} 的 checkpoint_field 格式无效")
        for prior_field, prior_step in checkpoint_fields:
            if field == prior_field or field.startswith(prior_field + '.') or prior_field.startswith(field + '.'):
                raise SystemExit(f"step {step.get('id', '')} 与 step {prior_step} 的 checkpoint_field 重叠")
        checkpoint_fields.append((field, step.get('id', '')))
    if retry_step and step.get('id') != retry_step:
        continue
    step_type = step.get('type', '')
    if step_type == 'agent':
        raise SystemExit(f"step {step.get('id', '')} 需要宿主 agent 执行器，但当前执行器没有 agent 适配器")
    if step_type not in ('command', 'verification'):
        raise SystemExit(f"未知 step 类型: {step_type}")
    if step_type == 'verification':
        for item in step.get('verification', []):
            value = item.get('expect_exit', 0)
            if type(value) is not int or not 0 <= value <= 255:
                name = item.get('name', '')
                raise SystemExit(f"step {step.get('id', '')} verification {name} 的 expect_exit 必须是 0..255 整数")
PYTHON

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

# checkpoint 与票体分离。启动时先登记空 sidecar，再执行任何 step；旧锚点格式、
# 任意路径和 schema 禁止的顶层 checkpoint 均停止，不做隐式迁移。
checkpoint_file=""
if [ -n "$ticket_file" ]; then
  checkpoint_file=$(python3 - "$ticket_file" <<'PYTHON'
import json, os, sys, tempfile

def atomic_write(path, document):
    directory = os.path.dirname(path) or '.'
    temporary = None
    try:
        with tempfile.NamedTemporaryFile('w', dir=directory, delete=False, encoding='utf-8') as f:
            json.dump(document, f, indent=2, ensure_ascii=False)
            f.write('\n')
            temporary = f.name
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)

ticket_file = os.path.realpath(sys.argv[1])
with open(ticket_file, encoding='utf-8') as f:
    ticket = json.load(f)
if not isinstance(ticket, dict):
    raise SystemExit('票文件必须包含 JSON 对象')
if 'checkpoint' in ticket:
    raise SystemExit('票文件含已废弃的顶层 checkpoint')
basename = os.path.basename(ticket_file) + '.workflow-checkpoint-v1.json'
expected_ref = 'workflow-checkpoint-v1:' + basename
ref = ticket.get('checkpoint_ref', '')
if not isinstance(ref, str):
    raise SystemExit('checkpoint_ref 必须是字符串')
if ref and ref != expected_ref:
    raise SystemExit('checkpoint_ref 不是 workflow-checkpoint-v1 固定同目录引用；拒绝解释旧锚点或任意路径')
path = os.path.join(os.path.dirname(ticket_file), basename)
if os.path.islink(path):
    raise SystemExit('workflow checkpoint sidecar 不得是符号链接')
if os.path.lexists(path) and not os.path.isfile(path):
    raise SystemExit('workflow checkpoint sidecar 必须是普通文件')
if os.path.isfile(path):
    with open(path, encoding='utf-8') as f:
        sidecar = json.load(f)
    if not isinstance(sidecar, dict) or type(sidecar.get('version')) is not int or sidecar['version'] != 1:
        raise SystemExit('workflow checkpoint sidecar version 必须为整数 1')
    if not isinstance(sidecar.get('checkpoint'), dict):
        raise SystemExit('workflow checkpoint sidecar 必须包含 checkpoint 对象')
    if not ref:
        if sidecar['checkpoint'] != {}:
            raise SystemExit('发现无 checkpoint_ref 的非空 workflow checkpoint sidecar；拒绝恢复孤儿状态')
        ticket['checkpoint_ref'] = expected_ref
        atomic_write(ticket_file, ticket)
elif ref:
    raise SystemExit('checkpoint_ref 指向的 sidecar 文件不存在')
else:
    # Register an empty checkpoint before running steps. A crash before the
    # ticket pointer is saved leaves only this safe, recoverable empty state.
    atomic_write(path, {'version': 1, 'checkpoint': {}})
    ticket['checkpoint_ref'] = expected_ref
    atomic_write(ticket_file, ticket)
print(path)
PYTHON
) || die1 "票的 checkpoint_ref 或 checkpoint 文件不安全/不受支持"
fi

# 读取已完成的 steps（从外部 checkpoint JSON 的 checkpoint 字段）
read_checkpoint() {
  if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
    echo "{}"
    return
  fi

  python3 - "$checkpoint_file" <<'PYTHON'
import sys, json
checkpoint_file = sys.argv[1]
with open(checkpoint_file, encoding='utf-8') as f:
  document = json.load(f)
if not isinstance(document, dict) or not isinstance(document.get('checkpoint', {}), dict):
  raise SystemExit('checkpoint 文件格式无效：需要对象中的 checkpoint 对象')
checkpoint = document.get('checkpoint', {})
print(json.dumps(checkpoint))
PYTHON
}

checkpoint_data=$(read_checkpoint)

# Validate every checkpoint path this invocation may read or write before the
# first workflow command can produce an external side effect. A retry clears
# its prior completion record first, so a failed retry cannot look completed.
python3 - "$checkpoint_file" "$checkpoint_data" "$steps_json" "$retry_step" <<'PYTHON' || die1 "checkpoint 与 workflow 定义不匹配；拒绝执行"
import json, os, re, sys, tempfile
from datetime import datetime

checkpoint_file, raw_checkpoint, raw_steps, retry_step = sys.argv[1:]
checkpoint = json.loads(raw_checkpoint)
steps = json.loads(raw_steps)
if not isinstance(checkpoint, dict):
    raise SystemExit('checkpoint 根必须为对象')
missing = object()

selected_steps = [step for step in steps if not retry_step or step.get('id') == retry_step]
for step in selected_steps:
    field = step.get('checkpoint_field', '')
    if not field:
        continue
    if not re.fullmatch(r'checkpoint(?:\.[a-z_][a-z0-9_]*)+', field):
        raise SystemExit(f"step {step.get('id', '')} 的 checkpoint_field 格式无效")
    data = checkpoint
    for part in field.split('.')[1:]:
        if not isinstance(data, dict):
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的字段路径中间节点必须为对象")
        if part not in data:
            data = missing
            break
        data = data[part]
    if data is missing:
        continue
    if not isinstance(data, dict):
        raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录必须为对象")
    if data.get('step_name') != step.get('id'):
        raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 step_name 不匹配")
    completed_at = data.get('completed_at')
    if not isinstance(completed_at, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at):
        raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 completed_at 格式无效")
    try:
        datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 completed_at 时间值无效")
    if not isinstance(data.get('outputs'), str):
        raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 outputs 必须为字符串")

if retry_step and checkpoint_file:
    step = next(step for step in steps if step.get('id') == retry_step)
    field = step.get('checkpoint_field', '')
    if field:
        with open(checkpoint_file, encoding='utf-8') as f:
            document = json.load(f)
        current = document['checkpoint']
        parts = field.split('.')[1:]
        parents = []
        for part in parts[:-1]:
            if part not in current:
                current = None
                break
            parents.append((current, part))
            current = current[part]
        leaf = parts[-1]
        if current is not None and leaf in current:
            del current[leaf]
            for parent, key in reversed(parents):
                if parent[key] == {}:
                    del parent[key]
                else:
                    break
            directory = os.path.dirname(checkpoint_file) or '.'
            temporary = None
            try:
                with tempfile.NamedTemporaryFile('w', dir=directory, delete=False, encoding='utf-8') as f:
                    json.dump(document, f, indent=2, ensure_ascii=False)
                    f.write('\n')
                    temporary = f.name
                os.replace(temporary, checkpoint_file)
            finally:
                if temporary and os.path.exists(temporary):
                    os.unlink(temporary)
PYTHON

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
retry_target_found=0
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

  # Retry executes only its target; unrelated steps must not be rejected or resumed.
  if [ -n "$retry_step" ] && [ "$step_id" != "$retry_step" ]; then
    i=$((i + 1))
    continue
  fi
  if [ -n "$retry_step" ]; then
    retry_target_found=1
  fi

  case $step_type in
    command|verification) : ;;
    agent) die1 "step $step_id 需要宿主 agent 执行器，但当前执行器没有 agent 适配器；未写入 checkpoint" ;;
    *) die1 "未知 step 类型: $step_type" ;;
  esac

  step_desc=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('description', ''))")

  checkpoint_field=$(echo "$step_json" | python3 -c "
import sys, json
step = json.load(sys.stdin)
print(step.get('checkpoint_field', ''))")

  # 中断恢复：检查是否已完成
  if [ "$resume_mode" = true ] && [ -z "$retry_step" ]; then
    if [ -z "$checkpoint_field" ]; then
      step_completed=false
    else
      step_completed=$(python3 - "$checkpoint_data" "$checkpoint_field" "$step_id" <<'PYTHON'
import json, re, sys
from datetime import datetime

checkpoint = json.loads(sys.argv[1])
field = sys.argv[2].split('.')
step_id = sys.argv[3]
data = checkpoint
for key in field[1:]:
    if not isinstance(data, dict):
        raise SystemExit('checkpoint 路径中间节点必须为对象')
    if key not in data:
        print('false')
        break
    data = data[key]
else:
    if not isinstance(data, dict):
        raise SystemExit('完成记录必须为对象')
    if data.get('step_name') != step_id:
        raise SystemExit('完成记录 step_name 与当前 step 不匹配')
    completed_at = data.get('completed_at')
    if not isinstance(completed_at, str) or not completed_at:
        raise SystemExit('完成记录 completed_at 必须为非空字符串')
    if not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at):
        raise SystemExit('完成记录 completed_at 格式无效')
    try:
        datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        raise SystemExit('完成记录 completed_at 时间值无效')
    if not isinstance(data.get('outputs'), str):
        raise SystemExit('完成记录 outputs 必须为字符串')
    print('true')
PYTHON
) || die1 "checkpoint 中 step $step_id 的完成记录无效；拒绝恢复"
    fi

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

        verify_expect_exit=$(echo "$verify_item" | python3 -c "
import sys, json
item = json.load(sys.stdin)
value = item.get('expect_exit', 0)
if type(value) is int:
    code = value
else:
    code = -1
print(code if 0 <= code <= 255 else 'INVALID')")
        case $verify_expect_exit in
          ''|*[!0-9]*) die1 "step $step_id verification $verify_name 的 expect_exit 必须是 0..255 整数" ;;
        esac

        printf '  验证 %d/%d: %s\n' $((j + 1)) "$verification_count" "$verify_name"

        verify_exit_code=0
        actual_output=$(eval "$verify_check" 2>&1) || verify_exit_code=$?

        # 移除 expect 中的引号（支持 "PASS" 和 PASS 两种写法）
        expect_clean=$(echo "$verify_expect" | sed 's/^"\(.*\)"$/\1/')

        if [ "$verify_exit_code" -ne "$verify_expect_exit" ]; then
          printf '    ✗ 失败（退出码 %d，期望 %s）\n' "$verify_exit_code" "$verify_expect_exit" >&2
          printf '    实际: %s\n' "$actual_output" >&2
          all_pass=false
        elif echo "$actual_output" | grep -qF "$expect_clean"; then
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
      die1 "step $step_id 需要宿主 agent 执行器，但当前执行器没有 agent 适配器；未写入 checkpoint"
      ;;

    *)
      die1 "未知 step 类型: $step_type"
      ;;
  esac

  # ---- 原子化 Checkpoint 写入 ----

  if [ -n "$checkpoint_field" ] && [ -n "$ticket_file" ]; then
    completed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    printf '  写入 checkpoint: %s\n' "$checkpoint_field"

    # 先原子写独立 checkpoint，再原子更新票的 checkpoint_ref。
    python3 - "$checkpoint_file" "$ticket_file" "$checkpoint_field" "$step_id" "$completed_at" "$step_outputs" <<'PYTHON'
import sys, json
import os, tempfile

checkpoint_file = sys.argv[1]
ticket_file = sys.argv[2]
checkpoint_field = sys.argv[3]
step_id = sys.argv[4]
completed_at = sys.argv[5]
step_outputs = sys.argv[6]

# 读取票文件；顶层 checkpoint 是旧格式，永不回写。
with open(ticket_file, encoding='utf-8') as f:
  ticket = json.load(f)
if 'checkpoint' in ticket:
  raise SystemExit('票文件含已废弃的顶层 checkpoint')

if os.path.exists(checkpoint_file):
  with open(checkpoint_file, encoding='utf-8') as f:
    document = json.load(f)
  if not isinstance(document, dict) or type(document.get('version')) is not int or document['version'] != 1:
    raise SystemExit('workflow checkpoint sidecar version 必须为整数 1')
  if not isinstance(document.get('checkpoint'), dict):
    raise SystemExit('workflow checkpoint sidecar 必须包含 checkpoint 对象')
else:
  document = {'version': 1, 'checkpoint': {}}

# 解析 checkpoint_field 路径（如 checkpoint.implementation.ticket_parsed）
field_parts = checkpoint_field.split('.')
if len(field_parts) < 2 or field_parts[0] != 'checkpoint':
  raise SystemExit('checkpoint_field 必须以 checkpoint. 开头')

# 从 checkpoint 根开始导航（跳过第一个 'checkpoint'）
current = document['checkpoint']

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

# 写回独立 checkpoint 文件（原子化：先写临时文件，再替换）。
checkpoint_dir = os.path.dirname(checkpoint_file) or '.'
os.makedirs(checkpoint_dir, exist_ok=True)
with tempfile.NamedTemporaryFile('w', dir=checkpoint_dir, delete=False, encoding='utf-8') as tmp_f:
  json.dump(document, tmp_f, indent=2, ensure_ascii=False)
  tmp_f.write('\n')
  checkpoint_tmp = tmp_f.name
os.replace(checkpoint_tmp, checkpoint_file)

# 票体只保存指针；保持其他字段原样。
ticket['checkpoint_ref'] = 'workflow-checkpoint-v1:' + os.path.basename(checkpoint_file)
ticket_dir = os.path.dirname(ticket_file) or '.'
with tempfile.NamedTemporaryFile('w', dir=ticket_dir, delete=False, encoding='utf-8') as tmp_f:
  json.dump(ticket, tmp_f, indent=2, ensure_ascii=False)
  tmp_f.write('\n')
  ticket_tmp = tmp_f.name
os.replace(ticket_tmp, ticket_file)
print(f"Checkpoint 已写入外部文件: {checkpoint_file}#{checkpoint_field}")
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

if [ -n "$retry_step" ] && [ "$retry_target_found" -eq 0 ]; then
  die2 "--retry 指定的 step 不存在: $retry_step"
fi

printf '\nworkflow-executor: 所有 steps 执行完成\n'
exit 0
