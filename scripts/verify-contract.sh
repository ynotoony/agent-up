#!/bin/sh
# verify-contract.sh - 契约验证器
# 读取票文件 verification 数组，逐条执行 check 命令，比对 expect/expect_exit，输出 PASS/FAIL。
set -eu

ticket_file="$1"

# 用法检查
if [ $# -lt 1 ]; then
  echo "用法: $0 <ticket-file.json>" >&2
  echo "示例: $0 facts/requirements/tickets/165-workflow-schema-v2.json" >&2
  exit 2
fi

if [ ! -f "$ticket_file" ]; then
  echo "错误: 文件不存在 $ticket_file" >&2
  exit 1
fi

# 依赖检查
if ! command -v jq >/dev/null 2>&1; then
  echo "错误: 需要 jq（brew install jq 或 apt-get install jq）" >&2
  exit 1
fi

# 读取 verification 字段（必须是对象数组）
verification_type=$(jq -r 'if .verification then (.verification | type) else "null" end' "$ticket_file")
if [ "$verification_type" != "array" ]; then
  echo "错误: verification 字段必须是数组（当前类型: $verification_type）" >&2
  exit 1
fi

verification_count=$(jq -r '.verification | length' "$ticket_file")
if [ "$verification_count" -eq 0 ]; then
  echo "verify-contract: 无验收条件（verification 为空数组）"
  exit 0
fi

# 逐条执行验证
all_pass=true
i=0
while [ $i -lt "$verification_count" ]; do
  name=$(jq -r ".verification[$i].name" "$ticket_file")
  check=$(jq -r ".verification[$i].check" "$ticket_file")
  expect=$(jq -r ".verification[$i].expect // empty" "$ticket_file")
  expect_exit=$(jq -r ".verification[$i].expect_exit // empty" "$ticket_file")

  echo "验证 $((i + 1))/$verification_count: $name"

  # 执行 check 命令（捕获输出与退出码）
  set +e
  actual_output=$(sh -c "$check" 2>&1)
  actual_exit=$?
  set -e

  # 比对 expect_exit（如果有）
  if [ -n "$expect_exit" ]; then
    if [ "$actual_exit" -eq "$expect_exit" ]; then
      echo "  PASS"
    else
      echo "  FAIL（期望退出码 $expect_exit，实际 $actual_exit）"
      all_pass=false
    fi
  # 比对 expect（输出内容）
  elif [ -n "$expect" ]; then
    # 去除引号（jq 输出带引号的字符串需要 strip）
    expect_clean=$(echo "$expect" | sed 's/^"\(.*\)"$/\1/')
    # 规范化空白（精确匹配策略）：移除所有空白符（包括换行），适配 JSON 格式输出
    actual_normalized=$(echo "$actual_output" | tr -d ' \t\n\r')
    expect_normalized=$(echo "$expect_clean" | tr -d ' \t\n\r')

    if [ "$actual_normalized" = "$expect_normalized" ]; then
      echo "  PASS"
    else
      # fallback: 尾行匹配（适配 command && echo PASS 格式）
      actual_last_line=$(echo "$actual_output" | tail -1)
      if [ "$actual_last_line" = "$expect_clean" ]; then
        echo "  PASS"
      else
        echo "  FAIL"
        echo "    期望: $expect_clean"
        echo "    实际: $actual_output"
        all_pass=false
      fi
    fi
  else
    # 缺少断言字段
    echo "  FAIL（缺少 expect 或 expect_exit 字段）"
    all_pass=false
  fi

  i=$((i + 1))
done

# 汇总
if [ "$all_pass" = true ]; then
  echo "verify-contract: 全部通过 ($verification_count/$verification_count)"
  exit 0
else
  echo "verify-contract: 存在失败项"
  exit 1
fi
