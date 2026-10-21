#!/bin/sh
# Input: --check-template（模板漂移检查模式）或 --check <合同文件>（执行体自查模式）；
#        schema 数据件与三份派发合同模板按脚本落位相对定位（包内语境）。
# Output: exit 0（通过）／exit 1（失败：输出缺失字段名或差集）／exit 2（用法或环境错误）。
# Pos: 双模式派发合同校验器：模板漂移检查（schema 占位符全集与三份派发合同模板占位符
#      并集双向零差集）＋执行体自查（合同文件按推断类型的必备字段完整性核对）。
#      POSIX sh＋awk，零外部依赖（无 jq/python）。包内语境运行：schema 与模板按
#      scripts/ 上一级 references/ 相对定位；复制落位（rules/implementation/scripts/
#      语境）须同迁 schema 与模板两件，引擎不自动探测其他落位。

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
SCHEMA_PATH="$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json"
PROMPT_DIR="$SCRIPT_DIR/../references/prompts"

usage() {
  cat <<'USAGE'
用法: sh check-dispatch-contract.sh --check-template | --check <合同文件>
模式:
    --check-template      模板漂移检查：schema 占位符全集与三份派发合同模板
                          （references/prompts/ 下 implementation/review/commit
                          三件 *-prompt.md）占位符并集做双向零差集核对
    --check <合同文件>    执行体自查：按特征字段推断合同类型（implementation/
                          review/commit），对照 schema 该类型必备字段清单核对
                          合同文件占位符完整性
退出码: 0 通过；1 失败（缺失字段名或差集见输出）；2 用法或环境错误
-h / --help             打印本用法
USAGE
}

require_inputs() {
  if [ ! -f "$SCHEMA_PATH" ]; then
    printf 'ERROR: schema 数据件不存在: %s\n' "$SCHEMA_PATH" >&2
    exit 2
  fi
  if [ ! -f "$PROMPT_DIR/implementation-prompt.md" ] || \
     [ ! -f "$PROMPT_DIR/review-prompt.md" ] || \
     [ ! -f "$PROMPT_DIR/commit-prompt.md" ]; then
    printf 'ERROR: 派发合同模板缺失（须三件齐备）: %s/{implementation,review,commit}-prompt.md\n' "$PROMPT_DIR" >&2
    exit 2
  fi
}

# 从 schema 提取占位符全集（去重排序；纯 awk 解析，占位符逐名一行）
extract_schema_placeholders() {
  LC_ALL=C awk '
    index($0, "\"placeholders\":") > 0 { in_block=1; next }
    in_block && /\]/ { in_block=0; next }
    in_block && /"[A-Z_]+"/ {
      line=$0
      gsub(/[",]/, "", line)
      gsub(/^[[:space:]]+/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line ~ /^[A-Z_]+$/) print line
    }
  ' "$SCHEMA_PATH" | LC_ALL=C sort -u
}

# 从三份派发合同模板提取占位符（原始 {{TOKEN}} 逐处一行）。显式三件列举、不用
# *.md 通配：同目录 README 亦含 {{占位符}} 字样（文档语境），通配纳入即污染比对
# 基准；去重排序在调用侧管道完成。
extract_template_placeholders() {
  grep -hoE '\{\{[A-Z_]+\}\}' "$PROMPT_DIR/implementation-prompt.md" || true
  grep -hoE '\{\{[A-Z_]+\}\}' "$PROMPT_DIR/review-prompt.md" || true
  grep -hoE '\{\{[A-Z_]+\}\}' "$PROMPT_DIR/commit-prompt.md" || true
}

# 推断合同类型（按特征字段：implementation/review/commit 各一）
infer_contract_type() {
  _contract_file="$1"

  if LC_ALL=C grep -q '{{SCOPE_TREE}}' "$_contract_file"; then
    printf 'implementation'
  elif LC_ALL=C grep -q '{{REVIEW_SCOPE}}' "$_contract_file"; then
    printf 'review'
  elif LC_ALL=C grep -q '{{FILE_WHITELIST}}' "$_contract_file"; then
    printf 'commit'
  else
    printf 'unknown'
  fi
}

# 从 schema 提取指定类型的必备字段清单（逐名一行；类型键未定义时输出为空）
extract_required_fields() {
  _type="$1"

  LC_ALL=C awk -v sect="\"${_type}\":" '
    index($0, sect) > 0 && /\[/ { in_block=1; next }
    in_block && /\]/ { in_block=0; next }
    in_block && /"[A-Z_]+"/ {
      line=$0
      gsub(/[",]/, "", line)
      gsub(/^[[:space:]]+/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line ~ /^[A-Z_]+$/) print line
    }
  ' "$SCHEMA_PATH"
}

# 检查合同文件必备字段（提取文件占位符，对照 schema 该类型必备清单，缺失即逐名报出）
check_contract_file() {
  _contract_file="$1"

  if [ ! -f "$_contract_file" ]; then
    printf 'ERROR: 合同文件不存在: %s\n' "$_contract_file" >&2
    return 1
  fi

  _contract_type=$(infer_contract_type "$_contract_file")

  if [ "$_contract_type" = "unknown" ]; then
    printf 'ERROR: 无法推断合同类型（缺少特征字段）\n' >&2
    return 1
  fi

  printf '检测到合同类型: %s\n' "$_contract_type"

  _found_placeholders=$(grep -oE '\{\{[A-Z_]+\}\}' "$_contract_file" | sed 's/[{}]//g' | LC_ALL=C sort -u)

  _required_fields=$(extract_required_fields "$_contract_type")
  if [ -z "$_required_fields" ]; then
    printf 'ERROR: schema 中无 %s 类型字段定义\n' "$_contract_type" >&2
    return 1
  fi

  _missing=$(printf '%s\n' "$_required_fields" | while IFS= read -r _field; do
    if ! printf '%s\n' "$_found_placeholders" | LC_ALL=C grep -qx "$_field"; then
      printf '%s\n' "$_field"
    fi
  done)

  if [ -n "$_missing" ]; then
    printf 'FAIL: 合同文件缺失字段：\n' >&2
    printf '%s\n' "$_missing" >&2
    return 1
  fi

  printf 'PASS: 合同文件字段完整（类型: %s）\n' "$_contract_type"
  return 0
}

# 模板漂移检查（schema 占位符全集与模板占位符并集双向零差集）
check_template_drift() {
  _schema_set=$(extract_schema_placeholders)
  _template_set=$(extract_template_placeholders | sed 's/[{}]//g' | LC_ALL=C sort -u)

  if [ -z "$_schema_set" ] || [ -z "$_template_set" ]; then
    printf 'ERROR: 占位符集为空（schema 或模板解析失败，不产生零差集结论）\n' >&2
    return 2
  fi

  _schema_only=$(printf '%s\n' "$_schema_set" | while IFS= read -r _p; do
    if ! printf '%s\n' "$_template_set" | LC_ALL=C grep -qx "$_p"; then
      printf '%s\n' "$_p"
    fi
  done)

  _template_only=$(printf '%s\n' "$_template_set" | while IFS= read -r _p; do
    if ! printf '%s\n' "$_schema_set" | LC_ALL=C grep -qx "$_p"; then
      printf '%s\n' "$_p"
    fi
  done)

  if [ -n "$_schema_only" ] || [ -n "$_template_only" ]; then
    if [ -n "$_schema_only" ]; then
      printf 'FAIL: schema 有但模板无：\n' >&2
      printf '%s\n' "$_schema_only" >&2
    fi
    if [ -n "$_template_only" ]; then
      printf 'FAIL: 模板有但 schema 无：\n' >&2
      printf '%s\n' "$_template_only" >&2
    fi
    return 1
  fi

  printf 'PASS: 模板/schema 零差集\n'
  return 0
}

# 主入口
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --check-template)
    require_inputs
    check_template_drift
    ;;
  --check)
    if [ -z "${2:-}" ]; then
      printf 'ERROR: --check 需要合同文件路径参数\n' >&2
      usage >&2
      exit 2
    fi
    require_inputs
    check_contract_file "$2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
