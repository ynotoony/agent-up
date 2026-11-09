#!/bin/sh
# Input: ticket-ops.sh 同进程 source 载入（不单独执行）；函数调用时依赖主入口已计算的
#        上下文变量：ticket_file、id、nn、repo_root、_engine、_closure_hint、audit_cmd、
#        issues_dir_rel、issues_index_rel、progress_current_rel，以及共享库函数
#        die1/die2、review_checkpoint_allow_after。
# Output: 三套收口门禁函数（actual_time_check／audit_gate／blocked_by_check），行为、
#         输出文案与退出码与抽取前逐字一致；只定义函数、无顶层副作用、不取锁不改状态。
# Pos: ticket-ops 门禁函数库（同进程函数库，非独立进程）：同进程 source 保持记录锁
#      窗口不变（锁区间仍覆盖预检读取到投影收尾，锁令牌继承语义不变）；主入口只留
#      配置加载、执行与汇总。
# shellcheck disable=SC2034,SC2154  # 依赖主入口上下文变量（同进程单 shell），单文件视野误报

# ---- actual_time 收口硬拦（票 100，flip 至 done 专属） ----

actual_time_check() {
  # flip 收口硬拦（票 100，决策 2 fail-closed）：task 票 flip 至 done 时点，JSON 本体
  # 须含 actual_time 字段且非空（净工时口径，strip 后非空；schema 同款非空口径），缺项
  # 或空白即 exit 1 指名票 id 与缺项，零写入。调用点已条件化——仅 flip 目标 status=done
  # 时执行，非 done 翻转不要求 actual_time（收口语义只属终态 done）。request 票不校验
  # （open 时点已过 schema 校验的 kind 为准；本体缺失不属本断言语义——由 open 时点
  # 保证存在，此处缺本体即报缺项指名票 id）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——flip actual_time 收口校验无法执行（fail-closed；票 100 起为 flip 校验依赖）'
  [ -r "${ticket_file}" ] || \
    die1 "票 ${id} 收口缺 actual_time：票本体不可读: ${ticket_file}（flip 校验须先读本票本体核 actual_time——票 100）"
  [ -f "${_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包缺失）: ${_engine}——${_closure_hint}"
  # 收口硬拦判据由唯一 JSON 引擎承载（票 227 F3；报文为 ticket-ops 合同输出）
  python3 "${_engine}" ticket-check close "${ticket_file}" "${id}"
}

# ---- done 证据门（票 237：只认 234 审计引擎的 conformant 判定） ----

audit_gate() {
  # $1=入口名（close|flip|flip-index）：done 收口前调同目录 ticket-audit.sh
  # --operation merge，只认 conformant（exit 0）；nonconformant/unknown（exit 1）即
  # 报 decision-required 并零写入；用法/环境错误（exit 2）按环境错误停。request 票
  # 沿用既有豁免（与 actual_time 同口径，不要求审查证据）。不采信自报 PASS：
  # 证据未提交、提交后改动、diff 失配、身份/策略不可核验一律拒绝。
  _ag_entry=$1
  _ag_kind='task'
  if [ -r "${ticket_file}" ] && [ -f "${_engine}" ]; then
    _ag_kind=$(python3 "${_engine}" json get "${ticket_file}" kind 2>/dev/null) || _ag_kind='task'
  fi
  if [ "${_ag_kind}" = 'request' ]; then
    printf 'ticket-ops: 证据门: %s request 票沿用豁免（kind=request；不要求审查证据）\n' "${_ag_entry}"
    return 0
  fi
  [ -n "${audit_cmd}" ] || die1 "证据审计引擎 ticket-audit.sh 不可用（同目录与 PATH 均未找到）——${_ag_entry} 至 done 预检停止：done 只认 ticket-audit --operation merge 的 conformant 判定（票 237），将 ticket-audit.sh 落位后重跑；未产生任何写入"
  # 显式允许集（票 237 裁决）：done 面的合法后置写面＝记录载体（索引与投影＋本票票体
  # 的 checkpoint.commit）＋票面声明的 Review Checkpoint；仅逐条显式传入，默认仍只认
  # 证据文件，不整体放开 facts 面。
  # 形态约束（不得放宽）由 common-helpers 的 review_checkpoint_allow_after 唯一承载：
  # 只认本票规范路径 facts/requirements/tickets/<票 id>-review-checkpoint.md。
  _ag_cp=$(review_checkpoint_allow_after "${id}" "${_engine}" "${ticket_file}")
  _ag_ticket_rel="${issues_dir_rel}/${id}.json"
  _ag_rc=0
  if [ -n "${_ag_cp}" ]; then
    sh "${audit_cmd}" "${nn}" --repo "${repo_root}" --operation merge \
      --allow-after "${issues_index_rel}" \
      --allow-after "${progress_current_rel}" \
      --allow-after 'facts/project/changes.jsonl' \
      --allow-after 'facts/requirements/tickets/README.md' \
      --allow-after "${_ag_ticket_rel}" \
      --allow-after "${_ag_cp}" || _ag_rc=$?
  else
    sh "${audit_cmd}" "${nn}" --repo "${repo_root}" --operation merge \
      --allow-after "${issues_index_rel}" \
      --allow-after "${progress_current_rel}" \
      --allow-after 'facts/project/changes.jsonl' \
      --allow-after 'facts/requirements/tickets/README.md' \
      --allow-after "${_ag_ticket_rel}" || _ag_rc=$?
  fi
  case ${_ag_rc} in
    0)
      printf 'ticket-ops: 证据门: %s 放行（ticket-audit --operation merge conformant）\n' "${_ag_entry}"
      ;;
    2)
      die2 "证据审计引擎用法/环境错误（exit 2）——${_ag_entry} 至 done 预检停止，未产生任何写入"
      ;;
    *)
      die1 "decision-required: ${_ag_entry} 至 done 要求票 ${id} 的审查证据判 conformant（ticket-audit --operation merge exit ${_ag_rc}）——证据缺失/未提交/提交后改动/diff 失配/身份或策略不可核验一律拒绝；零写入，补齐已提交证据与审计策略后重跑"
      ;;
  esac
  return 0
}

# ---- blocked_by 领取完整性门（take 专属） ----

blocked_by_check() {
  # take 领取预检（fail-closed 零写入）：task 票本体 blocked_by 数组逐项核对索引——每个
  # 被依赖票 id 须在索引中登记（存在性）且 status=done（完成性，索引为状态真相源）；
  # 缺失（索引零命中）或未完成（status 非 done）即 exit 1，逐项指名 blocker id 与其索引
  # 状态，任何写入之前停止。request 票无 blocked_by（schema request 分支省略），不校验；
  # 本体缺失不属本断言语义——由 open 时点保证存在，此处缺本体即报缺项指名票 id
  # （口径同 actual_time 收口硬拦的本体缺失先例）。门仅限 take——flip 不做 blocked_by
  # 核对。依赖 python3（JSON 解析，fail-closed）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——take blocked_by 完整性预检无法执行（fail-closed）'
  [ -r "${ticket_file}" ] || \
    die1 "票 ${id} 领取预检失败：票本体不可读: ${ticket_file}（blocked_by 完整性门须读本票声明的被依赖票清单）"
  [ -f "${_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包缺失）: ${_engine}——${_closure_hint}"
  # 领取完整性门判据由唯一 JSON 引擎承载（票 227 F3；报文为 ticket-ops 合同输出）
  python3 "${_engine}" ticket-check deps "${ticket_file}" "${index_file}" "${id}"
}
