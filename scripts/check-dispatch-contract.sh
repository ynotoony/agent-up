#!/bin/sh
# Input: --check-template（模板漂移检查模式）／--check <合同文件>（执行体自查模式）／
#        --check-dispatch <合同文件>（派发前置校验模式）／--check-step-budget <合同文件>
#        （步数预算与到线收尾校验模式）；schema 数据件与三份派发合同模板按脚本落位
#        相对定位（包内语境）。
# Output: exit 0（通过）／exit 1（失败：输出缺失字段名、差集、派发前置不满足或步数
#         预算四类缺失之一）／exit 2（用法或环境错误：合同/索引不可读、路径非 Git
#         工作树等）。
# Pos: 四模式派发合同校验器：模板漂移检查（schema 占位符全集与三份派发合同模板占位符
#      并集双向零差集）＋执行体自查（合同文件按推断类型的必备字段完整性核对）＋派发
#      前置校验（合同 REPOSITORY_PATH 须为主仓 linked worktree 且票 status=in_progress；
#      主检出路径、未领取票、非 in_progress 票一律拒绝，repo-root 由 worktree 的
#      git-common-dir 反推）＋步数预算校验（缺步数上限／缺到线收尾表述／上限为空／
#      上限非数字四类各自指名拒绝）。POSIX sh＋awk；--check-dispatch 另需 python3 解析
#      票索引（JSON 引擎与 contract-build.sh 同口径），其余三模式零外部依赖。包内语境
#      运行：schema 与模板按 scripts/ 上一级 references/ 相对定位；复制落位（rules/
#      implementation/scripts/ 语境）须同迁 schema 与模板两件，引擎不自动探测其他落位。

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
SCHEMA_PATH="$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json"
PROMPT_DIR="$SCRIPT_DIR/../references/prompts"

usage() {
  cat <<'USAGE'
用法: sh check-dispatch-contract.sh --check-template | --check <合同文件> |
      --check-dispatch <合同文件> | --check-step-budget <合同文件>
模式:
    --check-template      模板漂移检查：schema 占位符全集与三份派发合同模板
                          （references/prompts/ 下 implementation/review/commit
                          三件 *-prompt.md）占位符并集做双向零差集核对
    --check <合同文件>    执行体自查：按特征字段推断合同类型（implementation/
                          review/commit），对照 schema 该类型必备字段清单核对
                          合同文件占位符完整性
    --check-dispatch <合同文件>
                          派发前置校验：取合同 {{REPOSITORY_PATH}} 实值要求为
                          主仓 linked worktree（主检出拒绝），取 {{TICKET_ID}}
                          实值要求主仓 index 中该票 status=in_progress（未领取
                          或非 in_progress 拒绝）；repo-root 由 worktree 反推
    --check-step-budget <合同文件>
                          步数预算校验：合同须含「步数上限：<数字>」与到线即
                          收尾／另起交接摘要表述；缺步数上限、缺到线收尾表述、
                          上限为空、上限非数字四类各自指名拒绝（fail-closed）
退出码: 0 通过；1 失败（缺失字段名、差集、派发前置不满足或步数预算缺失见输出）；
        2 用法或环境错误
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

# ---- 四模式实现（票 294：独立为同目录 dispatch-contract-modes.sh；本件只留参数与分派）----
# shellcheck disable=SC1090,SC1091  # 模式模块路径由脚本目录推导（动态源，静态视野不可跟随）
. "$SCRIPT_DIR/dispatch-contract-modes.sh"

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
  --check-dispatch)
    if [ -z "${2:-}" ]; then
      printf 'ERROR: --check-dispatch 需要合同文件路径参数\n' >&2
      usage >&2
      exit 2
    fi
    check_dispatch_preconditions "$2"
    ;;
  --check-step-budget)
    if [ -z "${2:-}" ]; then
      printf 'ERROR: --check-step-budget 需要合同文件路径参数\n' >&2
      usage >&2
      exit 2
    fi
    check_step_budget "$2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
