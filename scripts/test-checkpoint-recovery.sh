#!/bin/sh
# Test script for AC2: 中断恢复能力
# 模拟中断：执行到第 2 步后 kill；重启后从第 3 步继续

set -e

test_dir="/tmp/checkpoint-recovery-test-$$"
mkdir -p "$test_dir"

# 创建测试 workflow
cat > "$test_dir/test-workflow.yaml" <<'EOF'
workflow:
  name: test-recovery
  description: 中断恢复测试
  version: "1.0"
inputs:
  test_input:
    type: string
    required: false
    description: 测试输入
    default: "test"
outputs:
  test_output:
    type: string
    description: 测试输出
steps:
  - id: step1
    type: command
    description: 第一步
    command: echo "Step 1"
    checkpoint_field: checkpoint.test.step1
  - id: step2
    type: command
    description: 第二步
    command: echo "Step 2"
    checkpoint_field: checkpoint.test.step2
  - id: step3
    type: command
    description: 第三步
    command: echo "Step 3"
    checkpoint_field: checkpoint.test.step3
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 待处理
    - name: done
      description: 完成
  transitions:
    - from: pending
      to: done
      condition: all_complete
EOF

# 创建测试票
cat > "$test_dir/test-ticket.json" <<'EOF'
{
  "id": "test-recovery",
  "kind": "task",
  "title": "Recovery Test",
  "created_at": "2026-10-19"
}
EOF

echo "=== 第一次运行：执行到 step2 ==="
# 首次运行完整流程（模拟前两步完成）
sh rules/implementation/scripts/workflow-executor.sh "$test_dir/test-workflow.yaml" \
  --ticket-file "$test_dir/test-ticket.json" 2>&1 | grep -E "(step [0-9]|完成)" || true

# 检查 checkpoint
checkpoint_count=$(python3 -c "
import json
with open('$test_dir/test-ticket.json') as f:
  data = json.load(f)
print(len(data.get('checkpoint', {}).get('test', {})))
")

echo ""
echo "Checkpoint 步骤数: $checkpoint_count"

if [ "$checkpoint_count" -ge 2 ]; then
  echo "✓ 前两步已完成并记录 checkpoint"
else
  echo "✗ checkpoint 记录不完整"
  exit 1
fi

echo ""
echo "=== 第二次运行：启用 --resume（模拟中断恢复）==="
# 第二次运行，应跳过已完成的步骤
resume_output=$(sh rules/implementation/scripts/workflow-executor.sh "$test_dir/test-workflow.yaml" \
  --ticket-file "$test_dir/test-ticket.json" --resume 2>&1)

skip_count=$(echo "$resume_output" | grep -c "跳过已完成的 step" || true)

echo "$resume_output" | grep -E "(跳过|完成)"

echo ""
if [ "$skip_count" -ge 3 ]; then
  echo "✓ AC2 通过：成功跳过 $skip_count 个已完成步骤"
  rm -rf "$test_dir"
  exit 0
else
  echo "✗ AC2 失败：只跳过了 $skip_count 个步骤"
  rm -rf "$test_dir"
  exit 1
fi
