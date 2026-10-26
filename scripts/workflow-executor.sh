#!/bin/sh
# Input: workflow YAML 文件路径 + 参数（如 --param ticket_id=165）
# Output: 执行 workflow 的 steps，每个 step 完成后写入外部 checkpoint（原子化），支持中断恢复
# Pos: 工作流执行器（票 166）；解析 agent-up/references/schemas/workflow.schema.json v2 格式的 YAML
#      文件，执行 agent/command/verification 三种步骤类型，步骤级 checkpoint 原子化落盘。
#      checkpoint 与票文件分离，票只保存 checkpoint_ref；中断后从外部 checkpoint 恢复执行。
#      JSON 层唯一引擎（票 227 F3）：YAML 解析、step/checkpoint/index 的全部 JSON 操作
#      改调同目录 json-validator.py（workflow/json 模式；原内嵌 python heredoc 已收敛 retired），
#      本件零内嵌解释器代码；引擎缺件 fail-closed 指名。

set -eu

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'workflow-executor: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

# 唯一 JSON 引擎定位（同目录分发；安装器将脚本件与引擎同目录落位）
_engine_file=$(dirname "$0")/json-validator.py
[ -f "$_engine_file" ] || {
  printf 'workflow-executor: FAIL: 唯一 JSON 引擎缺失: %s（json-validator.py 与本件同目录分发）\n' "$_engine_file" >&2
  exit 2
}

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
      # 票文件规范化（原内嵌 python heredoc 收敛为 POSIX test＋物理 cd——票 227 F3；
      # 语义保持：须是非符号链接普通文件，失败报文逐字保留）
      _tf_dir=$(CDPATH='' cd -- "$(dirname -- "$ticket_file")" 2>/dev/null && pwd -P) || _tf_dir=''
      if [ -z "$_tf_dir" ] || [ -L "$ticket_file" ] || [ ! -f "$ticket_file" ]; then
        printf 'workflow-executor: FAIL: 票文件必须是非符号链接普通文件\n' >&2
        die1 '无法规范化票文件路径'
      fi
      ticket_file="$_tf_dir/$(basename -- "$ticket_file")"
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

# ---- YAML 解析（唯一 JSON 引擎承载：workflow steps / state-machine 模式）----

steps_json=$(python3 "$_engine_file" workflow steps "$workflow_file") || die1 "YAML 解析失败"

steps_count=$(printf '%s\n' "$steps_json" | python3 "$_engine_file" json len - '')

printf 'workflow-executor: 解析到 %d 个 steps\n' "$steps_count"

# Reject unsupported execution before creating or updating checkpoint files.
python3 "$_engine_file" workflow preflight "$retry_step" "$steps_json" || die1 "workflow 包含执行器不支持的 step"

# ---- State Machine 解析 ----

state_machine_json=$(python3 "$_engine_file" workflow state-machine "$workflow_file") || die1 "State Machine 解析失败"

mapping_count=$(printf '%s' "$state_machine_json" | python3 "$_engine_file" json len - state_to_ticket_status 0)

printf 'workflow-executor: 解析到 state_machine 定义（票状态映射 %s 条）\n' "$mapping_count"

# ---- State Machine Executor ----

# 读取当前票状态（从 index.json）
get_current_status() {
  ticket_id=$1
  index_file="${issues_index_rel:-facts/requirements/tickets/index.json}"

  if [ ! -f "$index_file" ]; then
    echo "unknown"
    return
  fi

  _gcs_rc=0
  _gcs_status=$(python3 "$_engine_file" json pick "$index_file" issues id "$ticket_id" status) || _gcs_rc=$?
  if [ "$_gcs_rc" -eq 3 ] || { [ "$_gcs_rc" -eq 0 ] && [ -z "$_gcs_status" ]; }; then
    echo 'unknown'
    return 0
  fi
  if [ "$_gcs_rc" -ne 0 ]; then
    return "$_gcs_rc"
  fi
  printf '%s\n' "$_gcs_status"
}

# 校验值是否为 issue-index 票状态枚举合法值（Task 流转值，不含生命周期标签
# superseded）。判定在唯一 JSON 引擎面 workflow check-status（票 221；pattern 与
# issue-index.schema.json status pattern 同源）。
is_valid_ticket_status() {
  python3 "$_engine_file" workflow check-status "$1" >/dev/null 2>&1
}

# 验证状态转换是否合法（根据 state_machine 定义）
validate_transition() {
  from_state=$1
  to_state=$2

  # 检查转换是否在 transitions 列表中
  if printf '%s' "$state_machine_json" | \
      python3 "$_engine_file" json pick - transitions from "$from_state" to "$to_state" >/dev/null 2>&1; then
    printf 'valid\n'
  else
    printf 'invalid\n'
  fi
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
      # 检查 checkpoint 字段是否存在（数据面为步骤完成记录对象；缺路径/空值＝false）
      field_path=$condition
      _ec_rc=0
      result=$(printf '%s' "$checkpoint_data" | python3 "$_engine_file" json get - "${field_path#checkpoint.}" 'null') || _ec_rc=$?
      case $result in
        ''|'null'|'false'|'0'|'""') result='false' ;;
        *) result='true' ;;
      esac
      if [ "$_ec_rc" -ne 0 ]; then result='false'; fi
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

# 原子化更新票状态（使用临时文件 + mv；引擎侧原子写）
# 原子化更新票状态（使用临时文件 + mv；引擎侧原子写）。
# 写票索引前强制值域死守（票 221）：越枚举值零写入 fail-closed；workflow 私有
# 状态不经 state_to_ticket_status 映射不得到达本函数写面（引擎 index-status 内
# 另有同 pattern 二次校验，双层防御）。
update_status() {
  ticket_id=$1
  new_status=$2
  index_file="${issues_index_rel:-facts/requirements/tickets/index.json}"

  if [ ! -f "$index_file" ]; then
    die1 "index.json 不存在: $index_file"
  fi

  if ! is_valid_ticket_status "$new_status"; then
    die1 "拒绝写票索引: $new_status 不在 issue-index 票状态枚举（Task 流转值）内"
  fi

  printf '  状态转换: %s → %s\n' "$(get_current_status "$ticket_id")" "$new_status"

  python3 "$_engine_file" workflow index-status "$index_file" "$ticket_id" "$new_status" || \
    die1 "状态更新失败"
}

# 尝试推进状态机（检查所有可能的转换）
try_advance_state() {
  ticket_id=$1
  current_status=$(get_current_status "$ticket_id")

  printf '\nworkflow-executor: 检查状态机转换（当前状态: %s）\n' "$current_status"

  # 遍历所有转换，查找当前状态可触发的转换
  transitions_count=$(printf '%s' "$state_machine_json" | python3 "$_engine_file" json len - transitions 0)

  trans_idx=0
  while [ "$trans_idx" -lt "$transitions_count" ]; do
    transition=$(printf '%s' "$state_machine_json" | python3 "$_engine_file" json get - "transitions.$trans_idx")

    from_state=$(printf '%s' "$transition" | python3 "$_engine_file" json get - from '')
    to_state=$(printf '%s' "$transition" | python3 "$_engine_file" json get - to '')
    condition=$(printf '%s' "$transition" | python3 "$_engine_file" json get - condition '')

    # 检查是否匹配当前状态
    if [ "$from_state" = "$current_status" ]; then
      # 评估条件
      condition_result=$(evaluate_condition "$condition")

      if [ "$condition_result" = "true" ]; then
        printf '  条件满足: %s → %s (条件: %s)\n' "$from_state" "$to_state" "$condition"

        # 验证转换合法性
        if [ "$(validate_transition "$from_state" "$to_state")" = "valid" ]; then
          # 映射强制（票 221）：workflow 私有状态不直写票索引；每条转换到达时
          # 查 state_to_ticket_status[to]，未映射或映射目标越票状态枚举 → 拒绝
          # 转换且零写票索引；映射合法才按映射值写。
          _ms_rc=0
          mapped_status=$(printf '%s' "$state_machine_json" | \
            python3 "$_engine_file" workflow map-status - "$to_state") || _ms_rc=$?
          if [ "$_ms_rc" -eq 3 ]; then
            printf '  未映射不写票索引: %s（state_to_ticket_status 无该状态映射）\n' "$to_state"
          elif [ "$_ms_rc" -ne 0 ]; then
            printf '  警告：映射目标越票状态枚举，拒绝写票索引: %s → %s\n' "$to_state" "$mapped_status" >&2
          else
            # 执行状态转换（写映射值，非私有状态名）
            update_status "$ticket_id" "$mapped_status"
            return 0
          fi
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
  checkpoint_file=$(python3 "$_engine_file" workflow checkpoint-init "$ticket_file") || \
    die1 "票的 checkpoint_ref 或 checkpoint 文件不安全/不受支持"
fi

# 读取已完成的 steps（从外部 checkpoint JSON 的 checkpoint 字段）
read_checkpoint() {
  if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
    echo "{}"
    return
  fi

  python3 "$_engine_file" workflow read-checkpoint "$checkpoint_file"
}

checkpoint_data=$(read_checkpoint)

# Validate every checkpoint path this invocation may read or write before the
# first workflow command can produce an external side effect. A retry clears
# its prior completion record first, so a failed retry cannot look completed.
python3 "$_engine_file" workflow checkpoint-check "$checkpoint_file" "$checkpoint_data" "$steps_json" "$retry_step" || \
  die1 "checkpoint 与 workflow 定义不匹配；拒绝执行"

# 恢复模式日志输出
if [ "$resume_mode" = true ]; then
  printf '\nworkflow-executor: 恢复模式启用（从 checkpoint 恢复）\n'

  # 统计已完成的 steps
  completed_count=$(printf '%s' "$checkpoint_data" | python3 "$_engine_file" json count-key - completed_at)

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
  step_json=$(printf '%s' "$steps_json" | python3 "$_engine_file" json get - "$i")

  step_id=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - id '')
  step_type=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - type '')

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

  step_desc=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - description '')
  checkpoint_field=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - checkpoint_field '')

  # 中断恢复：检查是否已完成
  if [ "$resume_mode" = true ] && [ -z "$retry_step" ]; then
    if [ -z "$checkpoint_field" ]; then
      step_completed=false
    else
      step_completed=$(python3 "$_engine_file" workflow step-check "$checkpoint_data" "$checkpoint_field" "$step_id") || \
        die1 "checkpoint 中 step $step_id 的完成记录无效；拒绝恢复"
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
      command_str=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - command '')

      printf '  命令: %s\n' "$command_str"
      step_outputs=$(eval "$command_str" 2>&1) || step_exit_code=$?

      if [ $step_exit_code -ne 0 ]; then
        printf 'workflow-executor: 命令执行失败 (退出码 %d)\n' $step_exit_code >&2
        die1 "step $step_id 失败"
      fi
      ;;

    verification)
      verification_json=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - verification '[]')

      verification_count=$(printf '%s' "$verification_json" | python3 "$_engine_file" json len - '')

      printf '  验证项数: %d\n' "$verification_count"

      j=0
      all_pass=true
      while [ "$j" -lt "$verification_count" ]; do
        verify_item=$(printf '%s' "$verification_json" | python3 "$_engine_file" json get - "$j")

        verify_name=$(printf '%s' "$verify_item" | python3 "$_engine_file" json get - name '')
        verify_check=$(printf '%s' "$verify_item" | python3 "$_engine_file" json get - check '')
        verify_expect=$(printf '%s' "$verify_item" | python3 "$_engine_file" json get - expect '')
        # expect_exit 缺省 0；非 0..255 整数（含引号字符串字面量与越界值）在 preflight
        # 已 fail-closed，此处兜底同款报文。
        verify_expect_exit=$(printf '%s' "$verify_item" | python3 "$_engine_file" json get - expect_exit 0)
        case $verify_expect_exit in
          ''|*[!0-9]*) die1 "step $step_id verification $verify_name 的 expect_exit 必须是 0..255 整数" ;;
        esac
        if [ "$verify_expect_exit" -gt 255 ]; then
          die1 "step $step_id verification $verify_name 的 expect_exit 必须是 0..255 整数"
        fi

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
      agent_path=$(printf '%s' "$step_json" | python3 "$_engine_file" json get - agent '')

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

    # 先原子写独立 checkpoint，再原子更新票的 checkpoint_ref（引擎侧两段原子写）。
    python3 "$_engine_file" workflow record-step "$checkpoint_file" "$ticket_file" "$checkpoint_field" "$step_id" "$completed_at" "$step_outputs" || \
      die1 "checkpoint 写入失败"

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
    # 从 ticket 文件提取 ticket_id（缺 id 键时回退文件名去 .json 后缀，语义保持）
    _tid_default=$(basename "$ticket_file" .json)
    ticket_id=$(python3 "$_engine_file" json get "$ticket_file" id "$_tid_default")

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
