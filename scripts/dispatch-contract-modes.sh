#!/bin/sh
# Input: 调用方（check-dispatch-contract.sh）已定义的 SCRIPT_DIR／SCHEMA_PATH／PROMPT_DIR
#        与 usage；各模式函数按调用参数读取合同文件与 schema/模板数据件。
# Output: 四模式实现函数：--check-template 模板漂移、--check 执行体自查、--check-dispatch
#        派发前置、--check-step-budget 步数预算；退出码语义由调用方分派面统一承载。
# Pos: 派发合同校验器四模式实现模块（票 294：从 check-dispatch-contract.sh 拆件）；CLI
#      只留用法/参数校验/模式分派，模式实现与共享提取器集中在本件。
# shellcheck disable=SC2154  # 跨件共享状态（调用方路径常量与辅助函数），单文件视野误报

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

# 步数预算与到线收尾校验（票 253）：合同须含「步数上限：<数字>」声明，以及到线即
# 收尾与另起交接摘要表述。四类缺失各自指名并 exit 1（fail-closed，不给警告放行）：
# ①缺步数上限；②缺到线收尾表述；③上限为空；④上限非数字。四类齐全 exit 0。
# 合同文件不可读 exit 2。取值只认「步数上限」后首个分隔符到标点/括号前的一段。
check_step_budget() {
  _budget_file="$1"

  if [ ! -f "$_budget_file" ]; then
    printf 'ERROR: 合同文件不存在: %s\n' "$_budget_file" >&2
    return 2
  fi

  if ! LC_ALL=C grep -q '步数上限' "$_budget_file"; then
    printf 'FAIL: 派发合同缺步数上限（须写明「步数上限：<数字>」）\n' >&2
    return 1
  fi

  _budget_missing=''
  for _budget_token in 到线 收尾 交接摘要; do
    if ! LC_ALL=C grep -q "$_budget_token" "$_budget_file"; then
      _budget_missing="${_budget_missing}${_budget_token}、"
    fi
  done
  if [ -n "$_budget_missing" ]; then
    _budget_missing=$(printf '%s' "$_budget_missing" | sed 's/、$//')
    printf 'FAIL: 派发合同缺到线收尾表述（缺 %s；须写到线即收尾与另起交接摘要）\n' "$_budget_missing" >&2
    return 1
  fi

  _budget_line=$(LC_ALL=C grep -E '步数上限[[:space:]]*[:：]' "$_budget_file" | head -n 1 || true)
  _budget_value=''
  if [ -n "$_budget_line" ]; then
    _budget_value=$(printf '%s\n' "$_budget_line" \
      | sed -n 's/.*步数上限[[:space:]]*[:：][[:space:]]*//p' \
      | sed 's/[（(，,；;。].*$//' \
      | sed 's/[[:space:]]*$//')
  fi

  if [ -z "$_budget_value" ]; then
    printf 'FAIL: 步数上限为空（须写明「步数上限：<数字>」）\n' >&2
    return 1
  fi

  case "$_budget_value" in
    *[!0-9]*)
      printf 'FAIL: 步数上限非数字：%s\n' "$_budget_value" >&2
      return 1
      ;;
  esac

  printf 'PASS: 步数预算与到线收尾完整（步数上限 %s）\n' "$_budget_value"
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
