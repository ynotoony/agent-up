#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite workflow-recovery "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: workflow-recovery（票 291 自 suite-workflow-contract 拆出的中断恢复与安全回归面）：
# 票 260 —— 中断现场、续传、sidecar 协议（version/shape/引用/孤儿/symlink/traversal）、恢复
# 前置校验、verification expect_exit 域、--retry 边界与 schema 引用合同。

suite_workflow_recovery() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='workflow-recovery'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/DIRworkflow-recovery
  mkdir -p "$D"
  EXECUTOR="$SCRIPT_DIR/workflow-executor.sh"
  SCHEMA="$PKG_ROOT/references/schemas/workflow.schema.json"
  if [ ! -f "$EXECUTOR" ] || [ ! -f "$SCHEMA" ]; then
    bad '被测面齐备（executor/schema）' "executor=$EXECUTOR schema=$SCHEMA"
    suite_summary 'workflow-recovery'
    return 0
  fi

  # ---- checkpoint 中断恢复与安全回归（票 260：自原独立恢复 harness 逐例迁入）----
  # 原 650 行独立 harness 不在任何 runner 派发面；此节承接其全部正负例且语义不弱化：
  # 中断现场、续传、sidecar 协议（version/shape/引用/孤儿/symlink/traversal）、
  # 恢复前置校验（畸形完成记录/legacy 形态/bootstrap）、verification expect_exit 域、
  # --retry 边界与 schema 合同。夹具仍全落 $D（runner mktemp）零工作区写入。

  CP="$D/checkpoint"
  mkdir -p "$CP"

  cat > "$CP/test-workflow.yaml" <<'EOF'
workflow:
  name: test-recovery
  version: "1.0"
steps:
  - id: step1
    type: command
    description: first step
    command: printf step1>>$TEST_OUTPUT
    checkpoint_field: checkpoint.test.step1
  - id: step2
    type: command
    description: long-running step, interrupted before checkpoint
    command: sh -c 'touch "$STEP2_STARTED"; echo $$ > "$STEP2_PID"; exec sleep 5'
    checkpoint_field: checkpoint.test.step2
  - id: step3
    type: command
    description: third step
    command: printf step3>>$TEST_OUTPUT
    checkpoint_field: checkpoint.test.step3
EOF
  printf '{"id":"test-recovery","kind":"task","title":"Recovery Test","created_at":"2026-10-20"}\n' > "$CP/test-ticket.json"

  # N26：--resume 缺 --ticket-file 须在 workflow 副作用之前 fail-closed
  TEST_OUTPUT="$CP/no-ticket-output" sh "$EXECUTOR" "$CP/test-workflow.yaml" \
    --allow-shell --resume > "$CP/no-ticket-resume.log" 2>&1
  no_ticket_resume_rc=$?
  if [ "$no_ticket_resume_rc" -eq 2 ] \
    && grep -q -- '--resume 需要 --ticket-file' "$CP/no-ticket-resume.log" \
    && [ ! -e "$CP/no-ticket-output" ]; then
    ok 'N26 --resume 缺 --ticket-file：exit 2 用法拒绝且无步骤副作用'
  else
    bad 'N26 --resume 缺 --ticket-file：exit 2 用法拒绝且无步骤副作用' \
      "exit=$no_ticket_resume_rc output=$([ -e "$CP/no-ticket-output" ] && echo present || echo absent) $(tail -n 3 "$CP/no-ticket-resume.log" | tr '\n' '|')"
  fi

  # P26：在 step2 执行中终止整个进程组，且不留步骤子进程（中断注入 harness）
  TEST_OUTPUT="$CP/output" STEP2_STARTED="$CP/step2.started" STEP2_PID="$CP/step2.pid" \
    python3 - "$EXECUTOR" "$CP/test-workflow.yaml" "$CP/test-ticket.json" "$CP/first.log" \
      "$CP/step2.started" "$CP/step2.pid" > "$CP/interrupt.log" 2>&1 <<'PY'
import os, signal, subprocess, sys, time

executor, workflow, ticket, log_path, started_path, pid_path = sys.argv[1:]
with open(log_path, 'w', encoding='utf-8') as log:
    proc = subprocess.Popen(
        ['sh', executor, workflow, '--allow-shell', '--ticket-file', ticket],
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    deadline = time.time() + 10
    while not os.path.exists(started_path) and proc.poll() is None and time.time() < deadline:
        time.sleep(0.05)
    if not os.path.exists(started_path):
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
        proc.wait()
        with open(log_path, encoding='utf-8') as failed_log:
            sys.stderr.write(failed_log.read())
        sys.exit('workflow did not reach step2 before timeout')
    with open(pid_path, encoding='utf-8') as pid_file:
        child_pid = int(pid_file.read().strip())
    os.killpg(proc.pid, signal.SIGTERM)
    rc = proc.wait(timeout=5)
    child_stopped = False
    for _ in range(40):
        try:
            os.kill(child_pid, 0)
        except ProcessLookupError:
            child_stopped = True
            break
        probe = subprocess.run(['ps', '-o', 'stat=', '-p', str(child_pid)], capture_output=True, text=True)
        if probe.returncode != 0 or probe.stdout.strip().startswith('Z'):
            child_stopped = True
            break
        time.sleep(0.05)
    if not child_stopped:
        try:
            os.kill(child_pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        sys.exit('interrupted workflow left its step process running')
    print(rc)
    if rc == 0:
        sys.exit('interrupted workflow unexpectedly succeeded')
PY
  interrupt_harness_rc=$?
  if [ "$interrupt_harness_rc" -eq 0 ]; then
    ok 'P26 中断注入：step2 执行中被终止、执行器非零退出、步骤子进程无残留'
  else
    bad 'P26 中断注入：step2 执行中被终止、执行器非零退出、步骤子进程无残留' \
      "$(tail -n 6 "$CP/interrupt.log" | tr '\n' '|')"
  fi

  # P27：中断现场＝sidecar 已落盘、只产出 step1、step2 已实际开始
  if [ -f "$CP/test-ticket.json.workflow-checkpoint-v1.json" ] \
    && [ "$(cat "$CP/output" 2>/dev/null)" = "step1" ] \
    && [ -f "$CP/step2.started" ]; then
    ok 'P27 中断现场：checkpoint sidecar 已落盘、仅 step1 产出、step2 已开始执行'
  else
    bad 'P27 中断现场：checkpoint sidecar 已落盘、仅 step1 产出、step2 已开始执行' \
      "sidecar=$([ -e "$CP/test-ticket.json.workflow-checkpoint-v1.json" ] && echo present || echo absent) output=$(cat "$CP/output" 2>/dev/null || echo absent) started=$([ -e "$CP/step2.started" ] && echo present || echo absent)"
  fi

  # P28：中断后的票指针与 sidecar 记录格式（固定 sibling 引用；只记已完成步骤）
  if python3 - "$CP/test-ticket.json" "$CP/test-ticket.json.workflow-checkpoint-v1.json" \
    > "$CP/interrupt-shape.log" 2>&1 <<'PY'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
checkpoint = json.load(open(sys.argv[2], encoding='utf-8'))
assert 'checkpoint' not in ticket
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:test-ticket.json.workflow-checkpoint-v1.json'
assert 'step1' in checkpoint['checkpoint']['test']
assert 'step2' not in checkpoint['checkpoint']['test']
print('interrupt-shape-ok')
PY
  then
    ok 'P28 中断后票指针＝workflow-checkpoint-v1 固定 sibling 引用、sidecar 仅记已完成的 step1'
  else
    bad 'P28 中断后票指针＝workflow-checkpoint-v1 固定 sibling 引用、sidecar 仅记已完成的 step1' \
      "$(tail -n 4 "$CP/interrupt-shape.log" | tr '\n' '|')"
  fi

  # P29：--resume 跳过 step1、从 step2 继续并完成 step3
  TEST_OUTPUT="$CP/output" sh "$EXECUTOR" "$CP/test-workflow.yaml" \
    --allow-shell --ticket-file "$CP/test-ticket.json" --resume > "$CP/resume.log" 2>&1
  resume_rc=$?
  if [ "$resume_rc" -eq 0 ] \
    && [ "$(cat "$CP/output" 2>/dev/null)" = "step1step3" ] \
    && grep -q '跳过已完成的 step: step1' "$CP/resume.log" \
    && grep -q '从此 step 继续执行: step2' "$CP/resume.log"; then
    ok 'P29 续传：跳过已完成 step1、从 step2 继续执行（产出 step1step3）'
  else
    bad 'P29 续传：跳过已完成 step1、从 step2 继续执行（产出 step1step3）' \
      "exit=$resume_rc output=$(cat "$CP/output" 2>/dev/null || echo absent) $(tail -n 3 "$CP/resume.log" | tr '\n' '|')"
  fi

  # P30：无 checkpoint_field 的步骤不被记录，--resume 时视为未完成重跑
  cat > "$CP/optional-checkpoint-workflow.yaml" <<'EOF'
workflow:
  name: optional-checkpoint
  version: "1.0"
steps:
  - id: checkpointed-step
    type: command
    command: printf saved >> "$OPTIONAL_CHECKPOINT_OUTPUT"
    checkpoint_field: checkpoint.optional.saved
  - id: uncheckpointed-step
    type: command
    command: printf untracked >> "$OPTIONAL_CHECKPOINT_OUTPUT"
EOF
  printf '{"id":"optional-checkpoint-test","kind":"task","title":"Optional Checkpoint Test","created_at":"2026-10-20"}\n' > "$CP/optional-checkpoint-ticket.json"
  OPTIONAL_CHECKPOINT_OUTPUT="$CP/optional-checkpoint-output" sh "$EXECUTOR" "$CP/optional-checkpoint-workflow.yaml" \
    --allow-shell --ticket-file "$CP/optional-checkpoint-ticket.json" > "$CP/optional-checkpoint-first.log" 2>&1
  OPTIONAL_CHECKPOINT_OUTPUT="$CP/optional-checkpoint-output" sh "$EXECUTOR" "$CP/optional-checkpoint-workflow.yaml" \
    --allow-shell --ticket-file "$CP/optional-checkpoint-ticket.json" --resume > "$CP/optional-checkpoint-resume.log" 2>&1
  if [ "$(cat "$CP/optional-checkpoint-output" 2>/dev/null)" = "saveduntrackeduntracked" ] \
    && grep -q '跳过已完成的 step: checkpointed-step' "$CP/optional-checkpoint-resume.log" \
    && grep -q '从此 step 继续执行: uncheckpointed-step' "$CP/optional-checkpoint-resume.log"; then
    ok 'P30 无 checkpoint_field 的步骤不被记录：--resume 视其为未完成并重跑（产出 saveduntrackeduntracked）'
  else
    bad 'P30 无 checkpoint_field 的步骤不被记录：--resume 视其为未完成并重跑（产出 saveduntrackeduntracked）' \
      "output=$(cat "$CP/optional-checkpoint-output" 2>/dev/null || echo absent) $(tail -n 3 "$CP/optional-checkpoint-resume.log" | tr '\n' '|')"
  fi

  # N27～N30：四类畸形完成记录（null／空串／step_name 不匹配／日历非法）fail-closed
  cat > "$CP/resume-validation-workflow.yaml" <<'EOF'
workflow:
  name: resume-validation
  version: "1.0"
steps:
  - id: step1
    type: command
    command: printf executed>>$INVALID_OUTPUT
    checkpoint_field: checkpoint.test.step1
EOF
  for invalid_record in null empty wrong-step bad-timestamp; do
    invalid_ticket="$CP/resume-invalid-$invalid_record-ticket.json"
    invalid_sidecar="$invalid_ticket.workflow-checkpoint-v1.json"
    invalid_output="$CP/resume-invalid-$invalid_record.output"
    python3 - "$invalid_ticket" "$invalid_sidecar" "$invalid_record" <<'PY'
import json, sys
ticket_path, sidecar_path, invalid_record = sys.argv[1:]
record = {
    'step_name': 'step1',
    'completed_at': '2026-10-20T00:00:00Z',
    'outputs': '',
}
if invalid_record == 'null':
    record['completed_at'] = None
elif invalid_record == 'empty':
    record['completed_at'] = ''
elif invalid_record == 'wrong-step':
    record['step_name'] = 'different-step'
elif invalid_record == 'bad-timestamp':
    record['completed_at'] = '2026-13-40T00:00:00Z'
ticket = {
    'id': 'resume-validation-test', 'kind': 'task', 'title': 'Resume Validation Test',
    'created_at': '2026-10-20',
    'checkpoint_ref': 'workflow-checkpoint-v1:' + sidecar_path.rsplit('/', 1)[-1],
}
sidecar = {'version': 1, 'checkpoint': {'test': {'step1': record}}}
for path, data in ((ticket_path, ticket), (sidecar_path, sidecar)):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f)
PY
    cp "$invalid_ticket" "$invalid_ticket.before"
    cp "$invalid_sidecar" "$invalid_sidecar.before"
    INVALID_OUTPUT="$invalid_output" sh "$EXECUTOR" "$CP/resume-validation-workflow.yaml" \
      --allow-shell --ticket-file "$invalid_ticket" --resume > "$CP/resume-invalid-$invalid_record.log" 2>&1
    invalid_resume_rc=$?
    case $invalid_record in
      null) invalid_id='N27'; invalid_label='completed_at=null' ;;
      empty) invalid_id='N28'; invalid_label='completed_at 空串' ;;
      wrong-step) invalid_id='N29'; invalid_label='step_name 与步骤 id 不匹配' ;;
      bad-timestamp) invalid_id='N30'; invalid_label='completed_at 非合法 UTC 时刻' ;;
    esac
    if [ "$invalid_resume_rc" -ne 0 ] \
      && grep -q '完成记录' "$CP/resume-invalid-$invalid_record.log" \
      && [ ! -e "$invalid_output" ] \
      && cmp -s "$invalid_ticket" "$invalid_ticket.before" \
      && cmp -s "$invalid_sidecar" "$invalid_sidecar.before"; then
      ok "$invalid_id 畸形完成记录（${invalid_label}）：拒绝恢复、命令未执行、票与 sidecar 零改动"
    else
      bad "$invalid_id 畸形完成记录（${invalid_label}）：拒绝恢复、命令未执行、票与 sidecar 零改动" \
        "exit=$invalid_resume_rc output=$([ -e "$invalid_output" ] && echo present || echo absent) $(tail -n 3 "$CP/resume-invalid-$invalid_record.log" | tr '\n' '|')"
    fi
  done

  # N31：不支持的 agent step fail-closed，且不写 checkpoint
  cat > "$CP/agent-workflow.yaml" <<'EOF'
workflow:
  name: unsupported-agent
  version: "1.0"
steps:
  - id: agent-step
    type: agent
    agent: implementation
    checkpoint_field: checkpoint.agent.done
EOF
  printf '{"id":"agent-test","kind":"task","title":"Agent Test","created_at":"2026-10-20"}\n' > "$CP/agent-ticket.json"
  sh "$EXECUTOR" "$CP/agent-workflow.yaml" --allow-shell \
    --ticket-file "$CP/agent-ticket.json" > "$CP/agent.log" 2>&1
  agent_rc=$?
  if [ "$agent_rc" -ne 0 ] \
    && grep -q '没有 agent 适配器' "$CP/agent.log" \
    && [ ! -f "$CP/agent-ticket.json.workflow-checkpoint-v1.json" ]; then
    ok 'N31 不支持的 agent step：fail-closed、指名适配器缺失、零 checkpoint'
  else
    bad 'N31 不支持的 agent step：fail-closed、指名适配器缺失、零 checkpoint' \
      "exit=$agent_rc sidecar=$([ -e "$CP/agent-ticket.json.workflow-checkpoint-v1.json" ] && echo present || echo absent) $(tail -n 3 "$CP/agent.log" | tr '\n' '|')"
  fi

  # N32：即使 sidecar 声称 agent step 已完成，--resume 也不得跳过它
  python3 - "$CP/resume-agent-ticket.json" "$CP/resume-agent-ticket.json.workflow-checkpoint-v1.json" <<'PY'
import json, sys
ticket_path, checkpoint_path = sys.argv[1:]
ticket = {
    'id': 'resume-agent-test', 'kind': 'task', 'title': 'Resume Agent Test',
    'created_at': '2026-10-20',
    'checkpoint_ref': 'workflow-checkpoint-v1:resume-agent-ticket.json.workflow-checkpoint-v1.json',
}
checkpoint = {'version': 1, 'checkpoint': {'agent': {'done': {
    'step_name': 'agent-step', 'completed_at': '2026-10-20T00:00:00Z', 'outputs': ''
}}}}
for path, data in ((ticket_path, ticket), (checkpoint_path, checkpoint)):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f)
PY
  cp "$CP/resume-agent-ticket.json" "$CP/resume-agent-ticket.before"
  sh "$EXECUTOR" "$CP/agent-workflow.yaml" --allow-shell \
    --ticket-file "$CP/resume-agent-ticket.json" --resume > "$CP/resume-agent.log" 2>&1
  resume_agent_rc=$?
  if [ "$resume_agent_rc" -ne 0 ] \
    && grep -q '没有 agent 适配器' "$CP/resume-agent.log" \
    && cmp -s "$CP/resume-agent-ticket.json" "$CP/resume-agent-ticket.before"; then
    ok 'N32 已完成的不支持 agent step 不能被 --resume 跳过：仍 fail-closed、票零改动'
  else
    bad 'N32 已完成的不支持 agent step 不能被 --resume 跳过：仍 fail-closed、票零改动' \
      "exit=$resume_agent_rc $(tail -n 3 "$CP/resume-agent.log" | tr '\n' '|')"
  fi

  # N33：已废弃的票内顶层 checkpoint 被拒且零迁移写入
  printf '{"id":"legacy-test","kind":"task","title":"Legacy Test","created_at":"2026-10-20","checkpoint":{"old":{"completed_at":"2026-10-20T00:00:00Z"}}}\n' > "$CP/legacy-ticket.json"
  sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/legacy-ticket.json" > "$CP/legacy.log" 2>&1
  legacy_rc=$?
  if [ "$legacy_rc" -ne 0 ] \
    && grep -q '已废弃的顶层 checkpoint' "$CP/legacy.log" \
    && python3 - "$CP/legacy-ticket.json" > "$CP/legacy-shape.log" 2>&1 <<'PY'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
assert 'checkpoint_ref' not in ticket
assert 'checkpoint' in ticket
print('legacy-shape-ok')
PY
  then
    ok 'N33 legacy 顶层 checkpoint：fail-closed、报文指名废弃形态、票零迁移写入'
  else
    bad 'N33 legacy 顶层 checkpoint：fail-closed、报文指名废弃形态、票零迁移写入' \
      "exit=$legacy_rc $(tail -n 3 "$CP/legacy.log" | tr '\n' '|')"
  fi

  # N34：legacy checkpoint_ref 锚点形态不被重新解释
  printf '{"id":"anchor-test","kind":"task","title":"Anchor Test","created_at":"2026-10-20","checkpoint_ref":"facts/requirements/tickets/anchor-ticket.json#Checkpoint"}\n' > "$CP/anchor-ticket.json"
  cp "$CP/anchor-ticket.json" "$CP/anchor-ticket.before"
  sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/anchor-ticket.json" > "$CP/anchor.log" 2>&1
  anchor_rc=$?
  if [ "$anchor_rc" -ne 0 ] \
    && grep -q '拒绝解释旧锚点或任意路径' "$CP/anchor.log" \
    && cmp -s "$CP/anchor-ticket.json" "$CP/anchor-ticket.before"; then
    ok 'N34 legacy checkpoint_ref 锚点：拒绝重新解释、票零改动'
  else
    bad 'N34 legacy checkpoint_ref 锚点：拒绝重新解释、票零改动' \
      "exit=$anchor_rc $(tail -n 3 "$CP/anchor.log" | tr '\n' '|')"
  fi

  # N35：checkpoint_ref 路径穿越被拒且不触碰目标文件
  printf '{"id":"traversal-test","kind":"task","title":"Traversal Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:../outside.json"}\n' > "$CP/traversal-ticket.json"
  printf '%s\n' '{"sentinel":true}' > "$CP/outside.json"
  cp "$CP/outside.json" "$CP/outside.before"
  sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/traversal-ticket.json" > "$CP/traversal.log" 2>&1
  traversal_rc=$?
  if [ "$traversal_rc" -ne 0 ] \
    && grep -q '拒绝解释旧锚点或任意路径' "$CP/traversal.log" \
    && cmp -s "$CP/outside.json" "$CP/outside.before"; then
    ok 'N35 checkpoint_ref 路径穿越：拒绝任意路径引用、目标文件零改动'
  else
    bad 'N35 checkpoint_ref 路径穿越：拒绝任意路径引用、目标文件零改动' \
      "exit=$traversal_rc $(tail -n 3 "$CP/traversal.log" | tr '\n' '|')"
  fi

  # N36：sidecar 为符号链接时在命令副作用之前拒绝
  printf '{"id":"symlink-test","kind":"task","title":"Symlink Test","created_at":"2026-10-20"}\n' > "$CP/symlink-ticket.json"
  ln -s "$CP/outside.json" "$CP/symlink-ticket.json.workflow-checkpoint-v1.json"
  TEST_OUTPUT="$CP/symlink-output" sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/symlink-ticket.json" > "$CP/symlink.log" 2>&1
  symlink_rc=$?
  if [ "$symlink_rc" -ne 0 ] \
    && grep -q '不得是符号链接' "$CP/symlink.log" \
    && [ ! -e "$CP/symlink-output" ] \
    && cmp -s "$CP/outside.json" "$CP/outside.before"; then
    ok 'N36 symlink sidecar：命令执行前拒绝、探针零产出、目标文件零改动'
  else
    bad 'N36 symlink sidecar：命令执行前拒绝、探针零产出、目标文件零改动' \
      "exit=$symlink_rc output=$([ -e "$CP/symlink-output" ] && echo present || echo absent) $(tail -n 3 "$CP/symlink.log" | tr '\n' '|')"
  fi

  # N37：无引用且非空的确定性 sidecar 属孤儿状态，命令执行前拒绝
  printf '{"id":"orphan-test","kind":"task","title":"Orphan Test","created_at":"2026-10-20"}\n' > "$CP/orphan-ticket.json"
  printf '%s\n' '{"version":1,"checkpoint":{"test":{"step1":{"completed_at":"2026-10-20T00:00:00Z"}}}}' > "$CP/orphan-ticket.json.workflow-checkpoint-v1.json"
  TEST_OUTPUT="$CP/orphan-output" sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/orphan-ticket.json" > "$CP/orphan.log" 2>&1
  orphan_rc=$?
  if [ "$orphan_rc" -ne 0 ] \
    && grep -q '拒绝恢复孤儿状态' "$CP/orphan.log" \
    && [ ! -e "$CP/orphan-output" ]; then
    ok 'N37 无引用的非空 sidecar：拒绝恢复孤儿状态、命令执行前终止'
  else
    bad 'N37 无引用的非空 sidecar：拒绝恢复孤儿状态、命令执行前终止' \
      "exit=$orphan_rc output=$([ -e "$CP/orphan-output" ] && echo present || echo absent) $(tail -n 3 "$CP/orphan.log" | tr '\n' '|')"
  fi

  # P31：空 bootstrap sidecar 被安全接纳并登记引用后继续执行
  cat > "$CP/bootstrap-workflow.yaml" <<'EOF'
workflow:
  name: checkpoint-bootstrap
  version: "1.0"
steps:
  - id: bootstrap
    type: command
    description: bootstrap checkpoint
    command: printf bootstrap>>$TEST_OUTPUT
    checkpoint_field: checkpoint.test.bootstrap
EOF
  printf '{"id":"bootstrap-test","kind":"task","title":"Bootstrap Test","created_at":"2026-10-20"}\n' > "$CP/bootstrap-ticket.json"
  printf '%s\n' '{"version":1,"checkpoint":{}}' > "$CP/bootstrap-ticket.json.workflow-checkpoint-v1.json"
  TEST_OUTPUT="$CP/bootstrap-output" sh "$EXECUTOR" "$CP/bootstrap-workflow.yaml" --allow-shell \
    --ticket-file "$CP/bootstrap-ticket.json" --resume > "$CP/bootstrap.log" 2>&1
  if [ "$(cat "$CP/bootstrap-output" 2>/dev/null)" = "bootstrap" ] \
    && python3 - "$CP/bootstrap-ticket.json" "$CP/bootstrap-ticket.json.workflow-checkpoint-v1.json" \
      > "$CP/bootstrap-shape.log" 2>&1 <<'PY'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
checkpoint = json.load(open(sys.argv[2], encoding='utf-8'))
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:bootstrap-ticket.json.workflow-checkpoint-v1.json'
assert 'bootstrap' in checkpoint['checkpoint']['test']
print('bootstrap-shape-ok')
PY
  then
    ok 'P31 空 bootstrap sidecar：安全接纳、登记固定引用并继续执行'
  else
    bad 'P31 空 bootstrap sidecar：安全接纳、登记固定引用并继续执行' \
      "output=$(cat "$CP/bootstrap-output" 2>/dev/null || echo absent) $(tail -n 4 "$CP/bootstrap-shape.log" 2>/dev/null | tr '\n' '|')"
  fi

  # N38/N39：被引用 sidecar 的 version 与 checkpoint 形态校验
  printf '{"id":"sidecar-test","kind":"task","title":"Sidecar Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:sidecar-ticket.json.workflow-checkpoint-v1.json"}\n' > "$CP/sidecar-ticket.json"
  printf '%s\n' '{"version":2,"checkpoint":{}}' > "$CP/sidecar-ticket.json.workflow-checkpoint-v1.json"
  sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/sidecar-ticket.json" > "$CP/sidecar-version.log" 2>&1
  sidecar_version_rc=$?
  if [ "$sidecar_version_rc" -ne 0 ] && grep -q 'version 必须为整数 1' "$CP/sidecar-version.log"; then
    ok 'N38 sidecar version≠1：拒绝并指名 version 必须为整数 1'
  else
    bad 'N38 sidecar version≠1：拒绝并指名 version 必须为整数 1' \
      "exit=$sidecar_version_rc $(tail -n 3 "$CP/sidecar-version.log" | tr '\n' '|')"
  fi
  printf '%s\n' '{"version":1,"checkpoint":[]}' > "$CP/sidecar-ticket.json.workflow-checkpoint-v1.json"
  sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/sidecar-ticket.json" > "$CP/sidecar-shape.log" 2>&1
  sidecar_shape_rc=$?
  if [ "$sidecar_shape_rc" -ne 0 ] && grep -q '必须包含 checkpoint 对象' "$CP/sidecar-shape.log"; then
    ok 'N39 sidecar checkpoint 非对象：拒绝并指名必须包含 checkpoint 对象'
  else
    bad 'N39 sidecar checkpoint 非对象：拒绝并指名必须包含 checkpoint 对象' \
      "exit=$sidecar_shape_rc $(tail -n 3 "$CP/sidecar-shape.log" | tr '\n' '|')"
  fi

  # N40：嵌套 checkpoint 节点畸形时先于命令副作用拒绝且不重写 sidecar
  printf '{"id":"nested-test","kind":"task","title":"Nested Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:nested-ticket.json.workflow-checkpoint-v1.json"}\n' > "$CP/nested-ticket.json"
  printf '%s\n' '{"version":1,"checkpoint":{"test":false}}' > "$CP/nested-ticket.json.workflow-checkpoint-v1.json"
  cp "$CP/nested-ticket.json.workflow-checkpoint-v1.json" "$CP/nested-sidecar.before"
  TEST_OUTPUT="$CP/nested-output" sh "$EXECUTOR" "$CP/test-workflow.yaml" --allow-shell \
    --ticket-file "$CP/nested-ticket.json" > "$CP/nested-checkpoint.log" 2>&1
  nested_rc=$?
  if [ "$nested_rc" -ne 0 ] \
    && [ ! -e "$CP/nested-output" ] \
    && cmp -s "$CP/nested-ticket.json.workflow-checkpoint-v1.json" "$CP/nested-sidecar.before" \
    && grep -q 'checkpoint.*必须为对象' "$CP/nested-checkpoint.log"; then
    ok 'N40 畸形嵌套 checkpoint：命令副作用前拒绝、sidecar 零改写'
  else
    bad 'N40 畸形嵌套 checkpoint：命令副作用前拒绝、sidecar 零改写' \
      "exit=$nested_rc output=$([ -e "$CP/nested-output" ] && echo present || echo absent) $(tail -n 3 "$CP/nested-checkpoint.log" | tr '\n' '|')"
  fi

  # N41：verification 退出码不可被匹配输出掩盖，失败先落结构化记录
  cat > "$CP/verification-workflow.yaml" <<'EOF'
workflow:
  name: verification-exit
  version: "1.0"
steps:
  - id: bad-verification
    type: verification
    verification:
      - name: failing command
        check: printf PASS; exit 7
        expect: PASS
        expect_exit: 0
    checkpoint_field: checkpoint.verify.done
EOF
  printf '{"id":"verification-test","kind":"task","title":"Verification Test","created_at":"2026-10-20"}\n' > "$CP/verification-ticket.json"
  sh "$EXECUTOR" "$CP/verification-workflow.yaml" --allow-shell \
    --ticket-file "$CP/verification-ticket.json" > "$CP/verification.log" 2>&1
  verification_rc=$?
  if [ "$verification_rc" -ne 0 ] \
    && grep -q '退出码 7，期望 0' "$CP/verification.log" \
    && python3 - "$CP/verification-ticket.json" "$CP/verification-ticket.json.workflow-checkpoint-v1.json" \
      > "$CP/verification-shape.log" 2>&1 <<'PY'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
sidecar = json.load(open(sys.argv[2], encoding='utf-8'))
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:verification-ticket.json.workflow-checkpoint-v1.json'
record = sidecar['checkpoint']['verify']['done']
assert record['status'] == 'failed', record
assert record['exit_code'] == 7, record
assert record['verification_results'] == [{'name': 'failing command', 'status': 'failed', 'exit_code': 7}], record
print('verification-shape-ok')
PY
  then
    ok 'N41 verification 退出码不可被匹配输出掩盖：失败退出、先落 status=failed/exit_code=7 结构化记录'
  else
    bad 'N41 verification 退出码不可被匹配输出掩盖：失败退出、先落 status=failed/exit_code=7 结构化记录' \
      "exit=$verification_rc $(tail -n 4 "$CP/verification-shape.log" 2>/dev/null | tr '\n' '|')"
  fi

  # P32：显式非零 expect_exit 命中即通过
  sed 's/expect_exit: 0/expect_exit: 7/' "$CP/verification-workflow.yaml" > "$CP/expected-nonzero-workflow.yaml"
  printf '{"id":"expected-nonzero-test","kind":"task","title":"Expected Nonzero Test","created_at":"2026-10-20"}\n' > "$CP/expected-nonzero-ticket.json"
  sh "$EXECUTOR" "$CP/expected-nonzero-workflow.yaml" --allow-shell \
    --ticket-file "$CP/expected-nonzero-ticket.json" > "$CP/expected-nonzero.log" 2>&1
  if grep -q '✓ 通过' "$CP/expected-nonzero.log"; then
    ok 'P32 显式 expect_exit=7：命令退出 7 被判定通过'
  else
    bad 'P32 显式 expect_exit=7：命令退出 7 被判定通过' "$(tail -n 3 "$CP/expected-nonzero.log" | tr '\n' '|')"
  fi

  # P33：省略 expect_exit 时缺省为 0
  sed '/expect_exit:/d; s/printf PASS; exit 7/printf PASS/' "$CP/verification-workflow.yaml" > "$CP/default-exit-workflow.yaml"
  printf '{"id":"default-exit-test","kind":"task","title":"Default Exit Test","created_at":"2026-10-20"}\n' > "$CP/default-exit-ticket.json"
  sh "$EXECUTOR" "$CP/default-exit-workflow.yaml" --allow-shell \
    --ticket-file "$CP/default-exit-ticket.json" > "$CP/default-exit.log" 2>&1
  if grep -q '✓ 通过' "$CP/default-exit.log"; then
    ok 'P33 省略 expect_exit：缺省按 0 判定通过'
  else
    bad 'P33 省略 expect_exit：缺省按 0 判定通过' "$(tail -n 3 "$CP/default-exit.log" | tr '\n' '|')"
  fi

  # N42～N44：expect_exit 非整数／带引号整数／越 255 均先于 checkpoint 写入拒绝
  for invalid_exit in nope '"7"' 256; do
    case $invalid_exit in
      nope) invalid_exit_id='N42'; invalid_exit_label='非整数 nope' ;;
      '"7"') invalid_exit_id='N43'; invalid_exit_label='带引号整数 "7"' ;;
      256) invalid_exit_id='N44'; invalid_exit_label='越界 256' ;;
    esac
    invalid_exit_slug=$(printf '%s' "$invalid_exit" | tr -d '"')
    sed "s/expect_exit: 0/expect_exit: $invalid_exit/" "$CP/verification-workflow.yaml" > "$CP/invalid-exit-$invalid_exit_slug-workflow.yaml"
    printf '{"id":"invalid-exit-test","kind":"task","title":"Invalid Exit Test","created_at":"2026-10-20"}\n' > "$CP/invalid-exit-$invalid_exit_slug-ticket.json"
    cp "$CP/invalid-exit-$invalid_exit_slug-ticket.json" "$CP/invalid-exit-$invalid_exit_slug-ticket.before"
    sh "$EXECUTOR" "$CP/invalid-exit-$invalid_exit_slug-workflow.yaml" --allow-shell \
      --ticket-file "$CP/invalid-exit-$invalid_exit_slug-ticket.json" > "$CP/invalid-exit-$invalid_exit_slug.log" 2>&1
    invalid_exit_rc=$?
    if [ "$invalid_exit_rc" -ne 0 ] \
      && grep -q 'expect_exit 必须是 0..255 整数' "$CP/invalid-exit-$invalid_exit_slug.log" \
      && cmp -s "$CP/invalid-exit-$invalid_exit_slug-ticket.json" "$CP/invalid-exit-$invalid_exit_slug-ticket.before" \
      && [ ! -e "$CP/invalid-exit-$invalid_exit_slug-ticket.json.workflow-checkpoint-v1.json" ]; then
      ok "$invalid_exit_id expect_exit ${invalid_exit_label}：拒绝、票零改动、零 checkpoint 写入"
    else
      bad "$invalid_exit_id expect_exit ${invalid_exit_label}：拒绝、票零改动、零 checkpoint 写入" \
        "exit=$invalid_exit_rc sidecar=$([ -e "$CP/invalid-exit-$invalid_exit_slug-ticket.json.workflow-checkpoint-v1.json" ] && echo present || echo absent) $(tail -n 3 "$CP/invalid-exit-$invalid_exit_slug.log" | tr '\n' '|')"
    fi
  done

  # P34：--retry 定位步骤时不因无关 agent step 整体拒绝
  cat > "$CP/retry-workflow.yaml" <<'EOF'
workflow:
  name: retry-target
  version: "1.0"
steps:
  - id: unrelated-agent
    type: agent
    agent: implementation
    checkpoint_field: checkpoint.retry.agent
  - id: target-command
    type: command
    command: printf retry>>$RETRY_OUTPUT
    checkpoint_field: checkpoint.retry.command
EOF
  printf '{"id":"retry-test","kind":"task","title":"Retry Test","created_at":"2026-10-20"}\n' > "$CP/retry-ticket.json"
  RETRY_OUTPUT="$CP/retry-output" sh "$EXECUTOR" "$CP/retry-workflow.yaml" --allow-shell \
    --ticket-file "$CP/retry-ticket.json" --retry target-command > "$CP/retry.log" 2>&1
  if [ "$(cat "$CP/retry-output" 2>/dev/null)" = "retry" ] \
    && grep -q '幂等重试 step: target-command' "$CP/retry.log"; then
    ok 'P34 --retry：跳过无关 agent step、仅重试目标命令'
  else
    bad 'P34 --retry：跳过无关 agent step、仅重试目标命令' \
      "output=$(cat "$CP/retry-output" 2>/dev/null || echo absent) $(tail -n 3 "$CP/retry.log" | tr '\n' '|')"
  fi

  # N45：checkpoint_field 重叠在写入前拒绝
  cat > "$CP/retry-overlap-workflow.yaml" <<'EOF'
workflow:
  name: retry-overlap
  version: "1.0"
steps:
  - id: retry-target
    type: command
    command: printf target >> "$RETRY_OVERLAP_OUTPUT"
    checkpoint_field: checkpoint.retry_path
  - id: unrelated-child
    type: command
    command: printf child >> "$RETRY_OVERLAP_OUTPUT"
    checkpoint_field: checkpoint.retry_path.child
EOF
  printf '{"id":"retry-overlap-test","kind":"task","title":"Retry Overlap Test","created_at":"2026-10-20"}\n' > "$CP/retry-overlap-ticket.json"
  cp "$CP/retry-overlap-ticket.json" "$CP/retry-overlap-ticket.before"
  RETRY_OVERLAP_OUTPUT="$CP/retry-overlap-output" sh "$EXECUTOR" "$CP/retry-overlap-workflow.yaml" \
    --allow-shell --ticket-file "$CP/retry-overlap-ticket.json" --retry retry-target > "$CP/retry-overlap.log" 2>&1
  retry_overlap_rc=$?
  if [ "$retry_overlap_rc" -ne 0 ] \
    && grep -q 'checkpoint_field 重叠' "$CP/retry-overlap.log" \
    && [ ! -e "$CP/retry-overlap-output" ] \
    && [ ! -e "$CP/retry-overlap-ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$CP/retry-overlap-ticket.json" "$CP/retry-overlap-ticket.before"; then
    ok 'N45 checkpoint_field 重叠：写入前拒绝、命令零执行、零 sidecar、票零改动'
  else
    bad 'N45 checkpoint_field 重叠：写入前拒绝、命令零执行、零 sidecar、票零改动' \
      "exit=$retry_overlap_rc output=$([ -e "$CP/retry-overlap-output" ] && echo present || echo absent) $(tail -n 3 "$CP/retry-overlap.log" | tr '\n' '|')"
  fi

  # N46：--retry 目标不存在即拒绝
  sh "$EXECUTOR" "$CP/retry-workflow.yaml" --allow-shell \
    --ticket-file "$CP/retry-ticket.json" --retry missing-step > "$CP/retry-missing.log" 2>&1
  retry_missing_rc=$?
  if [ "$retry_missing_rc" -ne 0 ] && grep -q -- '--retry 指定的 step 不存在' "$CP/retry-missing.log"; then
    ok 'N46 --retry 目标不存在：拒绝并指名 step 不存在'
  else
    bad 'N46 --retry 目标不存在：拒绝并指名 step 不存在' \
      "exit=$retry_missing_rc $(tail -n 3 "$CP/retry-missing.log" | tr '\n' '|')"
  fi

  # N47：空 --retry 目标按用法错误拒绝且零写入
  cat > "$CP/empty-retry-workflow.yaml" <<'EOF'
workflow:
  name: empty-retry
  version: "1.0"
steps:
  - id: step1
    type: command
    command: printf executed>>$EMPTY_RETRY_OUTPUT
    checkpoint_field: checkpoint.test.step1
EOF
  printf '{"id":"empty-retry-test","kind":"task","title":"Empty Retry Test","created_at":"2026-10-20"}\n' > "$CP/empty-retry-ticket.json"
  cp "$CP/empty-retry-ticket.json" "$CP/empty-retry-ticket.before"
  EMPTY_RETRY_OUTPUT="$CP/empty-retry.output" sh "$EXECUTOR" "$CP/empty-retry-workflow.yaml" \
    --allow-shell --ticket-file "$CP/empty-retry-ticket.json" --retry "" > "$CP/empty-retry.log" 2>&1
  empty_retry_rc=$?
  if [ "$empty_retry_rc" -eq 2 ] \
    && grep -q -- '--retry 目标不能为空' "$CP/empty-retry.log" \
    && [ ! -e "$CP/empty-retry.output" ] \
    && [ ! -e "$CP/empty-retry-ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$CP/empty-retry-ticket.json" "$CP/empty-retry-ticket.before"; then
    ok 'N47 空 --retry 目标：exit 2 用法拒绝、命令零执行、零 sidecar、票零改动'
  else
    bad 'N47 空 --retry 目标：exit 2 用法拒绝、命令零执行、零 sidecar、票零改动' \
      "exit=$empty_retry_rc output=$([ -e "$CP/empty-retry.output" ] && echo present || echo absent) $(tail -n 3 "$CP/empty-retry.log" | tr '\n' '|')"
  fi

  # N48：--retry 指向不支持的 agent step 时在 checkpoint 写入前拒绝
  printf '{"id":"retry-agent-test","kind":"task","title":"Retry Agent Test","created_at":"2026-10-20"}\n' > "$CP/retry-agent-ticket.json"
  cp "$CP/retry-agent-ticket.json" "$CP/retry-agent-ticket.before"
  sh "$EXECUTOR" "$CP/retry-workflow.yaml" --allow-shell \
    --ticket-file "$CP/retry-agent-ticket.json" --retry unrelated-agent > "$CP/retry-agent.log" 2>&1
  retry_agent_rc=$?
  if [ "$retry_agent_rc" -ne 0 ] \
    && grep -q '没有 agent 适配器' "$CP/retry-agent.log" \
    && [ ! -e "$CP/retry-agent-ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$CP/retry-agent-ticket.json" "$CP/retry-agent-ticket.before"; then
    ok 'N48 --retry 指向不支持的 agent step：拒绝、零 sidecar、票零改动'
  else
    bad 'N48 --retry 指向不支持的 agent step：拒绝、零 sidecar、票零改动' \
      "exit=$retry_agent_rc $(tail -n 3 "$CP/retry-agent.log" | tr '\n' '|')"
  fi

  # N49：重试失败须使旧完成记录失效，后续 --resume 重跑该步
  cat > "$CP/retry-failure-workflow.yaml" <<'EOF'
workflow:
  name: retry-failure
  version: "1.0"
steps:
  - id: retry-command
    type: command
    command: printf run >> "$RETRY_FAILURE_OUTPUT"; if [ "${FAIL_RETRY:-0}" = 1 ]; then exit 7; fi
    checkpoint_field: checkpoint.retry_failure.run
EOF
  printf '{"id":"retry-failure-test","kind":"task","title":"Retry Failure Test","created_at":"2026-10-20"}\n' > "$CP/retry-failure-ticket.json"
  RETRY_FAILURE_OUTPUT="$CP/retry-failure-output" sh "$EXECUTOR" "$CP/retry-failure-workflow.yaml" \
    --allow-shell --ticket-file "$CP/retry-failure-ticket.json" > "$CP/retry-failure-first.log" 2>&1
  FAIL_RETRY=1 RETRY_FAILURE_OUTPUT="$CP/retry-failure-output" sh "$EXECUTOR" "$CP/retry-failure-workflow.yaml" \
    --allow-shell --ticket-file "$CP/retry-failure-ticket.json" --retry retry-command > "$CP/retry-failure-retry.log" 2>&1
  retry_failure_rc=$?
  RETRY_FAILURE_OUTPUT="$CP/retry-failure-output" sh "$EXECUTOR" "$CP/retry-failure-workflow.yaml" \
    --allow-shell --ticket-file "$CP/retry-failure-ticket.json" --resume > "$CP/retry-failure-resume.log" 2>&1
  if [ "$retry_failure_rc" -ne 0 ] \
    && [ "$(cat "$CP/retry-failure-output" 2>/dev/null)" = "runrunrun" ] \
    && grep -q '从此 step 继续执行: retry-command' "$CP/retry-failure-resume.log"; then
    ok 'N49 重试失败使旧完成记录失效：后续 --resume 重跑该步（产出 runrunrun）'
  else
    bad 'N49 重试失败使旧完成记录失效：后续 --resume 重跑该步（产出 runrunrun）' \
      "retry_exit=$retry_failure_rc output=$(cat "$CP/retry-failure-output" 2>/dev/null || echo absent) $(tail -n 3 "$CP/retry-failure-resume.log" | tr '\n' '|')"
  fi

  # P35～P37：schema 合同（expect_exit 整数 0..255、checkpoint_field pattern、
  # workflow-checkpoint-v1 引用与 README 登记）
  TICKET_SCHEMA="$PKG_ROOT/references/schemas/ticket-record.schema.json"
  if python3 - "$SCHEMA" "$TICKET_SCHEMA" > "$CP/schema-exit.log" 2>&1 <<'PY'
import json, sys
for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as f:
        root = json.load(f)
    found = []
    def visit(node):
        if isinstance(node, dict):
            props = node.get('properties', {})
            if 'expect_exit' in props:
                found.append(props['expect_exit'])
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)
    visit(root)
    assert found and all(p.get('type') == 'integer' and p.get('minimum') == 0 and p.get('maximum') == 255 for p in found), path
print('schema-exit-ok')
PY
  then
    ok 'P35 两份 schema 的 expect_exit 均为 integer 0..255'
  else
    bad 'P35 两份 schema 的 expect_exit 均为 integer 0..255' "$(tail -n 4 "$CP/schema-exit.log" | tr '\n' '|')"
  fi

  if python3 - "$SCHEMA" > "$CP/schema-pattern.log" 2>&1 <<'PY'
import json, re, sys
with open(sys.argv[1], encoding='utf-8') as f:
    root = json.load(f)
field_pattern = root['properties']['steps']['items']['properties']['checkpoint_field']['pattern']
assert re.fullmatch(field_pattern, 'checkpoint.test.step1')
print('schema-pattern-ok')
PY
  then
    ok 'P36 workflow schema 的 checkpoint_field pattern 接受 checkpoint.test.step1'
  else
    bad 'P36 workflow schema 的 checkpoint_field pattern 接受 checkpoint.test.step1' \
      "$(tail -n 4 "$CP/schema-pattern.log" | tr '\n' '|')"
  fi

  if python3 - "$TICKET_SCHEMA" > "$CP/schema-ref.log" 2>&1 <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    root = json.load(f)
checkpoint_ref = root['properties']['checkpoint_ref']['description']
assert 'workflow-checkpoint-v1' in checkpoint_ref
print('schema-ref-ok')
PY
  then
    schema_ref_ok=1
  else
    schema_ref_ok=0
  fi
  if [ "$schema_ref_ok" -eq 1 ] && grep -q 'workflow-checkpoint-v1' "$PKG_ROOT/references/schemas/README.md"; then
    ok 'P37 ticket-record schema 声明 workflow-checkpoint-v1 引用且 schemas README 同步登记'
  else
    bad 'P37 ticket-record schema 声明 workflow-checkpoint-v1 引用且 schemas README 同步登记' \
      "$(tail -n 4 "$CP/schema-ref.log" | tr '\n' '|')"
  fi

  suite_summary 'workflow-recovery'
}
