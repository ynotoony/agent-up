#!/bin/sh
# verify-contract.sh - 结构化验收谓词执行器
# 严格校验对象数组字段后，逐条执行 check 并比对 expect 或 expect_exit。
# 普通任务禁止空 verification；纯记录任务必须显式 record_only.reason + verification=N/A。
set -eu

# 用法检查
if [ $# -lt 1 ]; then
  echo "用法: $0 <ticket-file.json>" >&2
  echo "示例: $0 facts/requirements/tickets/165-workflow-schema-v2.json" >&2
  exit 2
fi

ticket_file="$1"

if [ ! -f "$ticket_file" ]; then
  echo "错误: 文件不存在 $ticket_file" >&2
  exit 1
fi

# 依赖检查
if ! command -v jq >/dev/null 2>&1; then
  echo "错误: 需要 jq（brew install jq 或 apt-get install jq）" >&2
  exit 1
fi

# JSON and record-only metadata are checked without jq scalar coercion.
if ! jq -e 'type == "object"' "$ticket_file" >/dev/null 2>&1; then
  echo '错误: ticket JSON 顶层必须是 object' >&2
  exit 1
fi

record_only_present=$(jq -r 'has("record_only")' "$ticket_file")
verification_type=$(jq -r 'if has("verification") then (.verification | type) else "missing" end' "$ticket_file")
if [ "$record_only_present" = true ]; then
  if ! jq -e '
    (.record_only | type == "object") and
    (.record_only | keys == ["reason"]) and
    (.record_only.reason | type == "string" and test("\\S")) and
    (.verification == "N/A")
  ' "$ticket_file" >/dev/null 2>&1; then
    echo '错误: record_only 必须恰为含非空字符串 reason 的对象，并与 verification: "N/A" 配套' >&2
    exit 1
  fi
  record_only_reason=$(jq -r '.record_only.reason' "$ticket_file")
  echo "verify-contract: PASS（纯记录例外：${record_only_reason}）"
  exit 0
fi

if [ "$verification_type" = missing ] || [ "$verification_type" = null ]; then
  echo '错误: 普通任务必须提供 verification；纯记录任务须显式 record_only.reason + verification: "N/A"' >&2
  exit 1
fi

if [ "$verification_type" = string ]; then
  if [ "$(jq -r '.verification' "$ticket_file")" = N/A ]; then
    echo '错误: verification: "N/A" 必须同时声明 record_only.reason' >&2
  else
    echo '错误: 存量字符串 verification 不是可执行谓词；不得按 shell 命令执行' >&2
  fi
  exit 1
fi

if [ "$verification_type" != array ]; then
  echo "错误: verification 必须是对象数组（当前类型: $verification_type）" >&2
  exit 1
fi

verification_count=$(jq -r '.verification | length' "$ticket_file")
if [ "$verification_count" -eq 0 ]; then
  echo '错误: 普通任务禁止空 verification；纯记录请显式 record_only.reason + verification: N/A' >&2
  exit 1
fi

array_form=$(jq -r 'if all(.verification[]; type == "string") then "strings" elif all(.verification[]; type == "object") then "objects" else "mixed" end' "$ticket_file")
if [ "$array_form" = strings ]; then
  if ! jq -e 'all(.verification[]; type == "string" and test("\\S"))' "$ticket_file" >/dev/null 2>&1; then
    echo '错误: legacy verification 字符串数组含非字符串或空白项' >&2
    exit 1
  fi
  echo '错误: legacy verification 字符串数组是散文谓词，不可由此执行器运行' >&2
  exit 1
fi
if [ "$array_form" != objects ]; then
  echo '错误: verification 数组不得混用字符串与对象' >&2
  exit 1
fi

if ! jq -e '
  all(.verification[];
    (type == "object") and
    ((keys - ["name", "description", "check", "expect", "expect_exit", "fail_msg"]) | length == 0) and
    (.name | type == "string" and test("\\S")) and
    (.check | type == "string" and test("\\S")) and
    ((has("expect") and (has("expect_exit") | not)) or (has("expect_exit") and (has("expect") | not))) and
    (if has("expect") then (.expect | type == "string" and test("\\S")) else true end) and
    (if has("expect_exit") then (.expect_exit | type == "number" and floor == . and . >= 0) else true end) and
    (if has("description") then (.description | type == "string") else true end) and
    (if has("fail_msg") then (.fail_msg | type == "string") else true end)
  )
' "$ticket_file" >/dev/null 2>&1; then
  echo '错误: verification 对象含未知字段、缺失/错误类型字段，或 expect 与 expect_exit 不合约束' >&2
  exit 1
fi

# 逐条执行验证
all_pass=true
i=0
while [ $i -lt "$verification_count" ]; do
  name=$(jq -r ".verification[$i].name" "$ticket_file")
  check=$(jq -r ".verification[$i].check" "$ticket_file")
  has_expect_exit=$(jq -r ".verification[$i] | has(\"expect_exit\")" "$ticket_file")
  expect=$(jq -r ".verification[$i] | if has(\"expect\") then .expect else \"\" end" "$ticket_file")
  expect_exit=$(jq -r ".verification[$i] | if has(\"expect_exit\") then .expect_exit else \"\" end" "$ticket_file")

  echo "验证 $((i + 1))/$verification_count: $name"

  # 执行 check 命令（捕获输出与退出码）
  set +e
  actual_output=$(sh -c "$check" 2>&1)
  actual_exit=$?
  set -e

  # 比对 expect_exit（如果有）
  if [ "$has_expect_exit" = true ]; then
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
