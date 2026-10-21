#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite json-helpers "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: json-helpers（票 158：JSON 解析共享库功能验证——json_extract_string、
# json_extract_number、json_validate_row 三函数正负例覆盖，至少 8 断言）
# ============================================================

suite_json_helpers() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='json-helpers'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/jhelp
  mkdir -p "$D"

  # Source the libraries
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  # shellcheck disable=SC1091  # 被测件路径由 SCRIPT_DIR 动态组装
  . "$SCRIPT_DIR/common-helpers.sh"
  # shellcheck source=agent-up/scripts/json-helpers.sh  # 路径动态计算，显式声明基线位置
  # shellcheck disable=SC1091  # 被测件路径由 SCRIPT_DIR 动态组装
  . "$SCRIPT_DIR/json-helpers.sh"

  # Positive: json_extract_string extracts simple string field
  result=$(json_extract_string '{"id": "123-test", "status": "ready"}' "id")
  if [ "$result" = "123-test" ]; then
    ok 'json_extract_string 提取 id 字段'
  else
    bad 'json_extract_string 提取 id 字段' "expected=123-test actual=$result"
  fi

  # Positive: json_extract_string extracts status field
  result=$(json_extract_string '{"id": "123-test", "status": "in_progress", "updated_at": "2026-01-01"}' "status")
  if [ "$result" = "in_progress" ]; then
    ok 'json_extract_string 提取 status 字段'
  else
    bad 'json_extract_string 提取 status 字段' "expected=in_progress actual=$result"
  fi

  # Positive: json_extract_string handles empty checkpoint_ref
  result=$(json_extract_string '{"id": "90", "checkpoint_ref": "", "status": "ready"}' "checkpoint_ref")
  if [ "$result" = "" ]; then
    ok 'json_extract_string 处理空字符串值'
  else
    bad 'json_extract_string 处理空字符串值' "expected=(empty) actual=$result"
  fi

  # Negative: json_extract_string returns empty for missing field
  result=$(json_extract_string '{"id": "123", "status": "ready"}' "nonexistent")
  if [ -z "$result" ]; then
    ok 'json_extract_string 缺失字段返回空'
  else
    bad 'json_extract_string 缺失字段返回空' "expected=(empty) actual=$result"
  fi

  # Positive: json_extract_number extracts integer
  result=$(json_extract_number '{"complexity": 1, "status": "ready"}' "complexity")
  if [ "$result" = "1" ]; then
    ok 'json_extract_number 提取整数'
  else
    bad 'json_extract_number 提取整数' "expected=1 actual=$result"
  fi

  # Positive: json_extract_number extracts decimal
  result=$(json_extract_number '{"version": 2.5, "name": "test"}' "version")
  if [ "$result" = "2.5" ]; then
    ok 'json_extract_number 提取小数'
  else
    bad 'json_extract_number 提取小数' "expected=2.5 actual=$result"
  fi

  # Negative: json_extract_number returns empty for missing field
  result=$(json_extract_number '{"complexity": 1}' "nonexistent")
  if [ -z "$result" ]; then
    ok 'json_extract_number 缺失字段返回空'
  else
    bad 'json_extract_number 缺失字段返回空' "expected=(empty) actual=$result"
  fi

  # Positive: json_validate_row passes with all required fields
  if json_validate_row '{"id": "90", "status": "ready", "updated_at": "2026-01-01"}' "id" "status" "updated_at" 2>/dev/null; then
    ok 'json_validate_row 所有必备字段存在返回 0'
  else
    bad 'json_validate_row 所有必备字段存在返回 0' "expected=0 actual=$?"
  fi

  # Negative: json_validate_row fails when field missing
  if json_validate_row '{"id": "90", "status": "ready"}' "id" "status" "updated_at" 2>/dev/null; then
    bad 'json_validate_row 缺失必备字段返回 1' "expected=1 actual=0"
  else
    ok 'json_validate_row 缺失必备字段返回 1'
  fi

  # Negative: json_validate_row fails when field empty
  if json_validate_row '{"id": "", "status": "ready"}' "id" "status" 2>/dev/null; then
    bad 'json_validate_row 空值字段返回 1' "expected=1 actual=0"
  else
    ok 'json_validate_row 空值字段返回 1'
  fi

  suite_summary 'json-helpers'
}
