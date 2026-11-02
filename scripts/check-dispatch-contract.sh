#!/bin/sh
# Input: --check-template（模板漂移检查模式）／--check <合同文件>（执行体自查模式）／
#        --check-dispatch <合同文件>（派发前置校验模式）；schema 数据件与三份派发合同
#        模板按脚本落位相对定位（包内语境）。
# Output: exit 0（通过）／exit 1（失败：输出缺失字段名、差集或派发前置不满足）／
#         exit 2（用法或环境错误：合同/索引不可读、路径非 Git 工作树等）。
# Pos: 三模式派发合同校验器：模板漂移检查（schema 占位符全集与三份派发合同模板占位符
#      并集双向零差集）＋执行体自查（合同文件按推断类型的必备字段完整性核对）＋派发
#      前置校验（合同 REPOSITORY_PATH 须为主仓 linked worktree 且票 status=in_progress；
#      主检出路径、未领取票、非 in_progress 票一律拒绝，repo-root 由 worktree 的
#      git-common-dir 反推）。POSIX sh＋awk；--check-dispatch 另需 python3 解析票索引
#      （JSON 引擎与 contract-build.sh 同口径，其余两模式零外部依赖）。包内语境运行：
#      schema 与模板按 scripts/ 上一级 references/ 相对定位；复制落位（rules/
#      implementation/scripts/ 语境）须同迁 schema 与模板两件，引擎不自动探测其他落位。

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
SCHEMA_PATH="$SCRIPT_DIR/../references/schemas/dispatch-contract.schema.json"
PROMPT_DIR="$SCRIPT_DIR/../references/prompts"

usage() {
  cat <<'USAGE'
用法: sh check-dispatch-contract.sh --check-template | --check <合同文件> |
      --check-dispatch <合同文件>
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
退出码: 0 通过；1 失败（缺失字段名、差集或派发前置不满足见输出）；2 用法或环境错误
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

# 从合同文件取 {{KEY}} 占位符行之后的首个非空行（合同形态＝占位符行＋实值行块，
# 见 contract-build.sh 渲染序；空白行分隔字段块）。
contract_value() {
  LC_ALL=C awk -v key="{{$2}}" '
    $0 == key { want = 1; next }
    want { if ($0 ~ /^[[:space:]]*$/) next; print; exit }
  ' "$1"
}

# 派发前置校验：合同 REPOSITORY_PATH 须为主仓 linked worktree，且 TICKET_ID 在主仓
# 票索引中 status=in_progress。主检出路径、未领取票、非 in_progress 票一律拒绝。
# repo-root 由 worktree 的 git-common-dir 反推（linked worktree 的公共目录＝主仓
# .git），不信任调用方传入的仓根。退出码：0 通过／1 前置不满足／2 环境或输入错误。
check_dispatch_preconditions() {
  _contract_file="$1"

  if [ ! -f "$_contract_file" ]; then
    printf 'ERROR: 合同文件不存在: %s\n' "$_contract_file" >&2
    return 2
  fi

  _repo_path=$(contract_value "$_contract_file" REPOSITORY_PATH)
  _ticket_id=$(contract_value "$_contract_file" TICKET_ID)

  if [ -z "$_repo_path" ] || [ -z "$_ticket_id" ]; then
    printf 'ERROR: 合同缺 {{REPOSITORY_PATH}} 或 {{TICKET_ID}} 实值行: %s\n' "$_contract_file" >&2
    return 2
  fi

  case "$_repo_path" in
    /*) ;;
    *)
      printf 'ERROR: REPOSITORY_PATH 须为绝对路径: %s\n' "$_repo_path" >&2
      return 2
      ;;
  esac

  if [ ! -d "$_repo_path" ]; then
    printf 'ERROR: REPOSITORY_PATH 目录不存在: %s\n' "$_repo_path" >&2
    return 2
  fi

  _repo_real=$(cd -- "$_repo_path" && pwd -P) || {
    printf 'ERROR: REPOSITORY_PATH 不可进入: %s\n' "$_repo_path" >&2
    return 2
  }

  if ! _top=$(git -C "$_repo_real" rev-parse --show-toplevel 2>/dev/null); then
    printf 'ERROR: REPOSITORY_PATH 不是 Git 工作树: %s\n' "$_repo_path" >&2
    return 2
  fi
  _top_real=$(cd -- "$_top" && pwd -P) || {
    printf 'ERROR: 工作树根不可进入: %s\n' "$_top" >&2
    return 2
  }
  if [ "$_top_real" != "$_repo_real" ]; then
    printf 'ERROR: REPOSITORY_PATH 须为工作树根（实际: %s）: %s\n' "$_top_real" "$_repo_path" >&2
    return 2
  fi

  _git_dir=$(git -C "$_repo_real" rev-parse --git-dir 2>/dev/null) || {
    printf 'ERROR: 无法读取 Git 目录: %s\n' "$_repo_path" >&2
    return 2
  }
  _git_common=$(git -C "$_repo_real" rev-parse --git-common-dir 2>/dev/null) || {
    printf 'ERROR: 无法读取 Git 公共目录: %s\n' "$_repo_path" >&2
    return 2
  }
  case "$_git_dir" in /*) ;; *) _git_dir="$_repo_real/$_git_dir" ;; esac
  case "$_git_common" in /*) ;; *) _git_common="$_repo_real/$_git_common" ;; esac
  _git_dir_real=$(cd -- "$_git_dir" && pwd -P) || {
    printf 'ERROR: Git 目录不可进入: %s\n' "$_git_dir" >&2
    return 2
  }
  _git_common_real=$(cd -- "$_git_common" && pwd -P) || {
    printf 'ERROR: Git 公共目录不可进入: %s\n' "$_git_common" >&2
    return 2
  }

  if [ "$_git_dir_real" = "$_git_common_real" ]; then
    printf 'FAIL: 派发目标为主检出（须为 linked worktree）: %s\n' "$_repo_real" >&2
    return 1
  fi

  _main_root=$(dirname -- "$_git_common_real")
  _index_file="$_main_root/facts/requirements/tickets/index.json"
  if [ ! -f "$_index_file" ]; then
    printf 'ERROR: 主仓票索引不存在（无法核验领取状态）: %s\n' "$_index_file" >&2
    return 2
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    printf 'ERROR: --check-dispatch 需 python3 解析票索引（未找到 python3）\n' >&2
    return 2
  fi

  _status_rc=0
  _ticket_status=$(python3 - "$_index_file" "$_ticket_id" <<'PY'
import json
import sys

path, tid = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
except (OSError, ValueError) as exc:
    sys.stderr.write('ERROR: 票索引不可解析: %s (%s)\n' % (path, exc))
    sys.exit(2)
issues = data.get('issues') if isinstance(data, dict) else None
if not isinstance(issues, list):
    sys.stderr.write('ERROR: 票索引缺 issues 数组: %s\n' % path)
    sys.exit(2)
for item in issues:
    if isinstance(item, dict) and item.get('id') == tid:
        status = item.get('status')
        sys.stdout.write(status if isinstance(status, str) else '')
        sys.exit(0)
sys.exit(3)
PY
) || _status_rc=$?

  case "$_status_rc" in
    0) ;;
    3)
      printf 'FAIL: 票 %s 未领取（主仓索引无该条目）: %s\n' "$_ticket_id" "$_index_file" >&2
      return 1
      ;;
    *)
      return 2
      ;;
  esac

  if [ "$_ticket_status" != "in_progress" ]; then
    printf 'FAIL: 票 %s status=%s（派发须 in_progress）: %s\n' "$_ticket_id" "${_ticket_status:-空}" "$_index_file" >&2
    return 1
  fi

  printf 'PASS: 派发前置校验（linked worktree + in_progress: %s）\n' "$_ticket_id"
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
  --check-dispatch)
    if [ -z "${2:-}" ]; then
      printf 'ERROR: --check-dispatch 需要合同文件路径参数\n' >&2
      usage >&2
      exit 2
    fi
    check_dispatch_preconditions "$2"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
