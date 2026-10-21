#!/bin/sh
# Input: none
# Output: repeatable positive and negative checks for workflow checkpoint safety
# Pos: workflow-executor.sh interruption/recovery regression harness; workspace read-only

set -eu
script_dir=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
executor="$script_dir/workflow-executor.sh"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/checkpoint-recovery-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

cat > "$test_dir/test-workflow.yaml" <<'EOF'
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

cat > "$test_dir/test-ticket.json" <<EOF
{"id":"test-recovery","kind":"task","title":"Recovery Test","created_at":"2026-10-20"}
EOF
export TEST_OUTPUT="$test_dir/output"
export STEP2_STARTED="$test_dir/step2.started"
export STEP2_PID="$test_dir/step2.pid"

echo "=== negative: --resume requires a ticket file ==="
set +e
TEST_OUTPUT="$test_dir/no-ticket-output" sh "$executor" "$test_dir/test-workflow.yaml" --resume >"$test_dir/no-ticket-resume.log" 2>&1
no_ticket_resume_rc=$?
set -e
[ "$no_ticket_resume_rc" -eq 2 ] || { echo "FAIL: --resume without --ticket-file returned $no_ticket_resume_rc instead of usage error"; exit 1; }
grep -q -- '--resume 需要 --ticket-file' "$test_dir/no-ticket-resume.log"
[ ! -e "$test_dir/no-ticket-output" ] || { echo "FAIL: --resume without --ticket-file executed a command"; exit 1; }
echo "PASS: --resume without --ticket-file fails before workflow side effects"

echo "=== interruption: terminate while step2 is running ==="
set +e
python3 - "$executor" "$test_dir/test-workflow.yaml" "$test_dir/test-ticket.json" "$test_dir/first.log" "$STEP2_STARTED" "$STEP2_PID" <<'PYTHON'
import os, signal, subprocess, sys, time

executor, workflow, ticket, log_path, started_path, pid_path = sys.argv[1:]
with open(log_path, 'w', encoding='utf-8') as log:
    proc = subprocess.Popen(
        ['sh', executor, workflow, '--ticket-file', ticket],
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
PYTHON
first_rc=$?
set -e
[ "$first_rc" -eq 0 ] || { echo "FAIL: interruption harness failed"; exit 1; }
[ -f "$test_dir/test-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: checkpoint file missing"; cat "$test_dir/first.log"; exit 1; }
[ "$(cat "$test_dir/output")" = "step1" ] || { echo "FAIL: interrupted step produced output"; exit 1; }
[ -f "$STEP2_STARTED" ] || { echo "FAIL: interruption did not reach step2"; exit 1; }
python3 - "$test_dir/test-ticket.json" "$test_dir/test-ticket.json.workflow-checkpoint-v1.json" <<'PYTHON'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
checkpoint = json.load(open(sys.argv[2], encoding='utf-8'))
assert 'checkpoint' not in ticket
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:test-ticket.json.workflow-checkpoint-v1.json'
assert 'step1' in checkpoint['checkpoint']['test']
assert 'step2' not in checkpoint['checkpoint']['test']
PYTHON
echo "PASS: interruption persisted only the completed step"

echo "=== resume: continue from step2 ==="
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/test-ticket.json" --resume >"$test_dir/resume.log" 2>&1
[ "$(cat "$test_dir/output")" = "step1step3" ] || { echo "FAIL: resume output mismatch"; exit 1; }
grep -q '跳过已完成的 step: step1' "$test_dir/resume.log"
grep -q '从此 step 继续执行: step2' "$test_dir/resume.log"
echo "PASS: resume skipped step1 and executed step2/step3"

echo "=== positive: resume reruns steps without checkpoint_field ==="
cat > "$test_dir/optional-checkpoint-workflow.yaml" <<'EOF'
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
cat > "$test_dir/optional-checkpoint-ticket.json" <<'EOF'
{"id":"optional-checkpoint-test","kind":"task","title":"Optional Checkpoint Test","created_at":"2026-10-20"}
EOF
export OPTIONAL_CHECKPOINT_OUTPUT="$test_dir/optional-checkpoint-output"
sh "$executor" "$test_dir/optional-checkpoint-workflow.yaml" --ticket-file "$test_dir/optional-checkpoint-ticket.json" >"$test_dir/optional-checkpoint-first.log" 2>&1
sh "$executor" "$test_dir/optional-checkpoint-workflow.yaml" --ticket-file "$test_dir/optional-checkpoint-ticket.json" --resume >"$test_dir/optional-checkpoint-resume.log" 2>&1
[ "$(cat "$OPTIONAL_CHECKPOINT_OUTPUT")" = "saveduntrackeduntracked" ] || { echo "FAIL: resume did not rerun the step without checkpoint_field"; exit 1; }
grep -q '跳过已完成的 step: checkpointed-step' "$test_dir/optional-checkpoint-resume.log"
grep -q '从此 step 继续执行: uncheckpointed-step' "$test_dir/optional-checkpoint-resume.log"
echo "PASS: resume treats a step without checkpoint_field as unrecorded"

echo "=== negative: malformed completion records fail closed ==="
cat > "$test_dir/resume-validation-workflow.yaml" <<'EOF'
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
  invalid_ticket="$test_dir/resume-invalid-$invalid_record-ticket.json"
  invalid_sidecar="$invalid_ticket.workflow-checkpoint-v1.json"
  invalid_output="$test_dir/resume-invalid-$invalid_record.output"
  python3 - "$invalid_ticket" "$invalid_sidecar" "$invalid_record" <<'PYTHON'
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
PYTHON
  cp "$invalid_ticket" "$invalid_ticket.before"
  cp "$invalid_sidecar" "$invalid_sidecar.before"
  set +e
  INVALID_OUTPUT="$invalid_output" sh "$executor" "$test_dir/resume-validation-workflow.yaml" --ticket-file "$invalid_ticket" --resume >"$test_dir/resume-invalid-$invalid_record.log" 2>&1
  invalid_resume_rc=$?
  set -e
  [ "$invalid_resume_rc" -ne 0 ] || { echo "FAIL: invalid $invalid_record completion record was accepted"; exit 1; }
  grep -q '完成记录' "$test_dir/resume-invalid-$invalid_record.log"
  [ ! -e "$invalid_output" ] || { echo "FAIL: invalid $invalid_record record allowed the command to run"; exit 1; }
  cmp -s "$invalid_ticket" "$invalid_ticket.before"
  cmp -s "$invalid_sidecar" "$invalid_sidecar.before"
done
echo "PASS: null, empty, mismatched, and malformed completion records fail closed"

echo "=== negative: unsupported agent step fails closed ==="
cat > "$test_dir/agent-workflow.yaml" <<'EOF'
workflow:
  name: unsupported-agent
  version: "1.0"
steps:
  - id: agent-step
    type: agent
    agent: implementation
    checkpoint_field: checkpoint.agent.done
EOF
cat > "$test_dir/agent-ticket.json" <<'EOF'
{"id":"agent-test","kind":"task","title":"Agent Test","created_at":"2026-10-20"}
EOF
set +e
sh "$executor" "$test_dir/agent-workflow.yaml" --ticket-file "$test_dir/agent-ticket.json" >"$test_dir/agent.log" 2>&1
agent_rc=$?
set -e
[ "$agent_rc" -ne 0 ] || { echo "FAIL: unsupported agent step succeeded"; exit 1; }
grep -q '没有 agent 适配器' "$test_dir/agent.log"
[ ! -f "$test_dir/agent-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: agent failure wrote checkpoint"; exit 1; }
echo "PASS: unsupported agent step failed closed without checkpoint"

echo "=== negative: completed unsupported agent cannot be skipped on resume ==="
python3 - "$test_dir/resume-agent-ticket.json" "$test_dir/resume-agent-ticket.json.workflow-checkpoint-v1.json" <<'PYTHON'
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
PYTHON
cp "$test_dir/resume-agent-ticket.json" "$test_dir/resume-agent-ticket.before"
set +e
sh "$executor" "$test_dir/agent-workflow.yaml" --ticket-file "$test_dir/resume-agent-ticket.json" --resume >"$test_dir/resume-agent.log" 2>&1
resume_agent_rc=$?
set -e
[ "$resume_agent_rc" -ne 0 ] || { echo "FAIL: completed unsupported agent was skipped"; exit 1; }
grep -q '没有 agent 适配器' "$test_dir/resume-agent.log"
cmp -s "$test_dir/resume-agent-ticket.json" "$test_dir/resume-agent-ticket.before"
echo "PASS: resume cannot skip unsupported agent steps"

echo "=== negative: legacy top-level checkpoint is rejected ==="
cat > "$test_dir/legacy-ticket.json" <<'EOF'
{"id":"legacy-test","kind":"task","title":"Legacy Test","created_at":"2026-10-20","checkpoint":{"old":{"completed_at":"2026-10-20T00:00:00Z"}}}
EOF
set +e
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/legacy-ticket.json" >"$test_dir/legacy.log" 2>&1
legacy_rc=$?
set -e
[ "$legacy_rc" -ne 0 ] || { echo "FAIL: legacy top-level checkpoint was accepted"; exit 1; }
grep -q '已废弃的顶层 checkpoint' "$test_dir/legacy.log"
python3 - "$test_dir/legacy-ticket.json" <<'PYTHON'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
assert 'checkpoint_ref' not in ticket
assert 'checkpoint' in ticket
PYTHON
echo "PASS: legacy top-level checkpoint failed closed without mutation"

echo "=== negative: legacy checkpoint_ref anchor is not reinterpreted ==="
cat > "$test_dir/anchor-ticket.json" <<'EOF'
{"id":"anchor-test","kind":"task","title":"Anchor Test","created_at":"2026-10-20","checkpoint_ref":"facts/requirements/tickets/anchor-ticket.json#Checkpoint"}
EOF
cp "$test_dir/anchor-ticket.json" "$test_dir/anchor-ticket.before"
set +e
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/anchor-ticket.json" >"$test_dir/anchor.log" 2>&1
anchor_rc=$?
set -e
[ "$anchor_rc" -ne 0 ] || { echo "FAIL: legacy checkpoint_ref anchor was accepted"; exit 1; }
grep -q '拒绝解释旧锚点或任意路径' "$test_dir/anchor.log"
cmp -s "$test_dir/anchor-ticket.json" "$test_dir/anchor-ticket.before"
echo "PASS: legacy checkpoint_ref anchor failed closed without mutation"

echo "=== negative: checkpoint_ref traversal and symlink are rejected ==="
cat > "$test_dir/traversal-ticket.json" <<'EOF'
{"id":"traversal-test","kind":"task","title":"Traversal Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:../outside.json"}
EOF
printf '%s\n' '{"sentinel":true}' > "$test_dir/outside.json"
cp "$test_dir/outside.json" "$test_dir/outside.before"
set +e
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/traversal-ticket.json" >"$test_dir/traversal.log" 2>&1
traversal_rc=$?
set -e
[ "$traversal_rc" -ne 0 ] || { echo "FAIL: traversal checkpoint_ref was accepted"; exit 1; }
grep -q '拒绝解释旧锚点或任意路径' "$test_dir/traversal.log"
cmp -s "$test_dir/outside.json" "$test_dir/outside.before"
cat > "$test_dir/symlink-ticket.json" <<'EOF'
{"id":"symlink-test","kind":"task","title":"Symlink Test","created_at":"2026-10-20"}
EOF
ln -s "$test_dir/outside.json" "$test_dir/symlink-ticket.json.workflow-checkpoint-v1.json"
set +e
TEST_OUTPUT="$test_dir/symlink-output" sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/symlink-ticket.json" >"$test_dir/symlink.log" 2>&1
symlink_rc=$?
set -e
[ "$symlink_rc" -ne 0 ] || { echo "FAIL: symlink checkpoint sidecar was accepted"; exit 1; }
grep -q '不得是符号链接' "$test_dir/symlink.log"
[ ! -e "$test_dir/symlink-output" ] || { echo "FAIL: command ran before symlink rejection"; exit 1; }
cmp -s "$test_dir/outside.json" "$test_dir/outside.before"
echo "PASS: traversal reference and symlink sidecar failed closed"

echo "=== negative: unreferenced deterministic sidecar is rejected ==="
cat > "$test_dir/orphan-ticket.json" <<'EOF'
{"id":"orphan-test","kind":"task","title":"Orphan Test","created_at":"2026-10-20"}
EOF
printf '%s\n' '{"version":1,"checkpoint":{"test":{"step1":{"completed_at":"2026-10-20T00:00:00Z"}}}}' > "$test_dir/orphan-ticket.json.workflow-checkpoint-v1.json"
set +e
TEST_OUTPUT="$test_dir/orphan-output" sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/orphan-ticket.json" >"$test_dir/orphan.log" 2>&1
orphan_rc=$?
set -e
[ "$orphan_rc" -ne 0 ] || { echo "FAIL: unreferenced sidecar was accepted"; exit 1; }
grep -q '拒绝恢复孤儿状态' "$test_dir/orphan.log"
[ ! -e "$test_dir/orphan-output" ] || { echo "FAIL: workflow ran before orphan checkpoint rejection"; exit 1; }
echo "PASS: unreferenced sidecar failed closed"

echo "=== positive: empty bootstrap sidecar is recovered ==="
cat > "$test_dir/bootstrap-workflow.yaml" <<'EOF'
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
cat > "$test_dir/bootstrap-ticket.json" <<'EOF'
{"id":"bootstrap-test","kind":"task","title":"Bootstrap Test","created_at":"2026-10-20"}
EOF
printf '%s\n' '{"version":1,"checkpoint":{}}' > "$test_dir/bootstrap-ticket.json.workflow-checkpoint-v1.json"
TEST_OUTPUT="$test_dir/bootstrap-output" sh "$executor" "$test_dir/bootstrap-workflow.yaml" --ticket-file "$test_dir/bootstrap-ticket.json" --resume >"$test_dir/bootstrap.log" 2>&1
[ "$(cat "$test_dir/bootstrap-output")" = "bootstrap" ] || { echo "FAIL: bootstrap recovery output mismatch"; exit 1; }
python3 - "$test_dir/bootstrap-ticket.json" "$test_dir/bootstrap-ticket.json.workflow-checkpoint-v1.json" <<'PYTHON'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
checkpoint = json.load(open(sys.argv[2], encoding='utf-8'))
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:bootstrap-ticket.json.workflow-checkpoint-v1.json'
assert 'bootstrap' in checkpoint['checkpoint']['test']
PYTHON
echo "PASS: empty bootstrap sidecar was safely attached and execution resumed"

echo "=== negative: referenced sidecar requires version 1 and checkpoint object ==="
cat > "$test_dir/sidecar-ticket.json" <<'EOF'
{"id":"sidecar-test","kind":"task","title":"Sidecar Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:sidecar-ticket.json.workflow-checkpoint-v1.json"}
EOF
printf '%s\n' '{"version":2,"checkpoint":{}}' > "$test_dir/sidecar-ticket.json.workflow-checkpoint-v1.json"
set +e
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/sidecar-ticket.json" >"$test_dir/sidecar-version.log" 2>&1
sidecar_version_rc=$?
set -e
[ "$sidecar_version_rc" -ne 0 ] || { echo "FAIL: unsupported sidecar version was accepted"; exit 1; }
grep -q 'version 必须为整数 1' "$test_dir/sidecar-version.log"
printf '%s\n' '{"version":1,"checkpoint":[]}' > "$test_dir/sidecar-ticket.json.workflow-checkpoint-v1.json"
set +e
sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/sidecar-ticket.json" >"$test_dir/sidecar-shape.log" 2>&1
sidecar_shape_rc=$?
set -e
[ "$sidecar_shape_rc" -ne 0 ] || { echo "FAIL: malformed checkpoint shape was accepted"; exit 1; }
grep -q '必须包含 checkpoint 对象' "$test_dir/sidecar-shape.log"
echo "PASS: sidecar version and shape are validated"

echo "=== negative: malformed nested checkpoint is rejected before command side effects ==="
cat > "$test_dir/nested-ticket.json" <<'EOF'
{"id":"nested-test","kind":"task","title":"Nested Test","created_at":"2026-10-20","checkpoint_ref":"workflow-checkpoint-v1:nested-ticket.json.workflow-checkpoint-v1.json"}
EOF
printf '%s\n' '{"version":1,"checkpoint":{"test":false}}' > "$test_dir/nested-ticket.json.workflow-checkpoint-v1.json"
cp "$test_dir/nested-ticket.json.workflow-checkpoint-v1.json" "$test_dir/nested-sidecar.before"
set +e
TEST_OUTPUT="$test_dir/nested-output" sh "$executor" "$test_dir/test-workflow.yaml" --ticket-file "$test_dir/nested-ticket.json" >"$test_dir/nested-checkpoint.log" 2>&1
nested_checkpoint_rc=$?
set -e
[ "$nested_checkpoint_rc" -ne 0 ] || { echo "FAIL: malformed nested checkpoint was accepted"; exit 1; }
[ ! -e "$test_dir/nested-output" ] || { echo "FAIL: command ran before nested checkpoint rejection"; exit 1; }
cmp -s "$test_dir/nested-ticket.json.workflow-checkpoint-v1.json" "$test_dir/nested-sidecar.before"
grep -q 'checkpoint.*必须为对象' "$test_dir/nested-checkpoint.log"
echo "PASS: malformed nested checkpoint failed before command side effects"

echo "=== negative: verification exit code cannot be masked by matching output ==="
cat > "$test_dir/verification-workflow.yaml" <<'EOF'
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
cat > "$test_dir/verification-ticket.json" <<'EOF'
{"id":"verification-test","kind":"task","title":"Verification Test","created_at":"2026-10-20"}
EOF
set +e
sh "$executor" "$test_dir/verification-workflow.yaml" --ticket-file "$test_dir/verification-ticket.json" >"$test_dir/verification.log" 2>&1
verification_rc=$?
set -e
[ "$verification_rc" -ne 0 ] || { echo "FAIL: failing verification succeeded from matching output"; exit 1; }
grep -q '退出码 7，期望 0' "$test_dir/verification.log"
python3 - "$test_dir/verification-ticket.json" "$test_dir/verification-ticket.json.workflow-checkpoint-v1.json" <<'PYTHON'
import json, sys
ticket = json.load(open(sys.argv[1], encoding='utf-8'))
sidecar = json.load(open(sys.argv[2], encoding='utf-8'))
assert ticket.get('checkpoint_ref') == 'workflow-checkpoint-v1:verification-ticket.json.workflow-checkpoint-v1.json'
assert sidecar == {'version': 1, 'checkpoint': {}}
PYTHON
echo "PASS: verification exit code is enforced"

echo "=== positive: explicit nonzero expect_exit is honored ==="
sed 's/expect_exit: 0/expect_exit: 7/' "$test_dir/verification-workflow.yaml" > "$test_dir/expected-nonzero-workflow.yaml"
cat > "$test_dir/expected-nonzero-ticket.json" <<'EOF'
{"id":"expected-nonzero-test","kind":"task","title":"Expected Nonzero Test","created_at":"2026-10-20"}
EOF
sh "$executor" "$test_dir/expected-nonzero-workflow.yaml" --ticket-file "$test_dir/expected-nonzero-ticket.json" >"$test_dir/expected-nonzero.log" 2>&1
grep -q '✓ 通过' "$test_dir/expected-nonzero.log"
echo "PASS: explicit nonzero expect_exit accepts the matching command result"

echo "=== positive: omitted expect_exit defaults to 0 ==="
sed '/expect_exit:/d; s/printf PASS; exit 7/printf PASS/' "$test_dir/verification-workflow.yaml" > "$test_dir/default-exit-workflow.yaml"
cat > "$test_dir/default-exit-ticket.json" <<'EOF'
{"id":"default-exit-test","kind":"task","title":"Default Exit Test","created_at":"2026-10-20"}
EOF
sh "$executor" "$test_dir/default-exit-workflow.yaml" --ticket-file "$test_dir/default-exit-ticket.json" >"$test_dir/default-exit.log" 2>&1
grep -q '✓ 通过' "$test_dir/default-exit.log"
echo "PASS: omitted expect_exit accepts exit code 0"

echo "=== negative: malformed expect_exit fails closed ==="
sed 's/expect_exit: 0/expect_exit: nope/' "$test_dir/verification-workflow.yaml" > "$test_dir/invalid-exit-workflow.yaml"
cat > "$test_dir/invalid-exit-ticket.json" <<'EOF'
{"id":"invalid-exit-test","kind":"task","title":"Invalid Exit Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/invalid-exit-ticket.json" "$test_dir/invalid-exit-ticket.before"
set +e
sh "$executor" "$test_dir/invalid-exit-workflow.yaml" --ticket-file "$test_dir/invalid-exit-ticket.json" >"$test_dir/invalid-exit.log" 2>&1
invalid_exit_rc=$?
set -e
[ "$invalid_exit_rc" -ne 0 ] || { echo "FAIL: malformed expect_exit was accepted"; exit 1; }
grep -q 'expect_exit 必须是 0..255 整数' "$test_dir/invalid-exit.log"
cmp -s "$test_dir/invalid-exit-ticket.json" "$test_dir/invalid-exit-ticket.before"
[ ! -e "$test_dir/invalid-exit-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: malformed expect_exit wrote a checkpoint"; exit 1; }
echo "PASS: malformed expect_exit failed before checkpoint writes"

echo "=== negative: quoted integer expect_exit is not treated as an integer ==="
sed 's/expect_exit: 0/expect_exit: "7"/' "$test_dir/verification-workflow.yaml" > "$test_dir/quoted-exit-workflow.yaml"
cat > "$test_dir/quoted-exit-ticket.json" <<'EOF'
{"id":"quoted-exit-test","kind":"task","title":"Quoted Exit Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/quoted-exit-ticket.json" "$test_dir/quoted-exit-ticket.before"
set +e
sh "$executor" "$test_dir/quoted-exit-workflow.yaml" --ticket-file "$test_dir/quoted-exit-ticket.json" >"$test_dir/quoted-exit.log" 2>&1
quoted_exit_rc=$?
set -e
[ "$quoted_exit_rc" -ne 0 ] || { echo "FAIL: quoted integer expect_exit was accepted"; exit 1; }
grep -q 'expect_exit 必须是 0..255 整数' "$test_dir/quoted-exit.log"
cmp -s "$test_dir/quoted-exit-ticket.json" "$test_dir/quoted-exit-ticket.before"
[ ! -e "$test_dir/quoted-exit-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: quoted integer expect_exit wrote a checkpoint"; exit 1; }
echo "PASS: quoted integer expect_exit is rejected before checkpoint writes"

echo "=== negative: out-of-range expect_exit is rejected before checkpoint writes ==="
sed 's/expect_exit: 0/expect_exit: 256/' "$test_dir/verification-workflow.yaml" > "$test_dir/out-of-range-exit-workflow.yaml"
cat > "$test_dir/out-of-range-exit-ticket.json" <<'EOF'
{"id":"out-of-range-exit-test","kind":"task","title":"Out of Range Exit Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/out-of-range-exit-ticket.json" "$test_dir/out-of-range-exit-ticket.before"
set +e
sh "$executor" "$test_dir/out-of-range-exit-workflow.yaml" --ticket-file "$test_dir/out-of-range-exit-ticket.json" >"$test_dir/out-of-range-exit.log" 2>&1
out_of_range_exit_rc=$?
set -e
[ "$out_of_range_exit_rc" -ne 0 ] || { echo "FAIL: out-of-range expect_exit was accepted"; exit 1; }
grep -q 'expect_exit 必须是 0..255 整数' "$test_dir/out-of-range-exit.log"
cmp -s "$test_dir/out-of-range-exit-ticket.json" "$test_dir/out-of-range-exit-ticket.before"
[ ! -e "$test_dir/out-of-range-exit-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: out-of-range expect_exit wrote a checkpoint"; exit 1; }
echo "PASS: out-of-range expect_exit is rejected before checkpoint writes"

echo "=== positive: --retry skips unrelated unsupported steps ==="
cat > "$test_dir/retry-workflow.yaml" <<'EOF'
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
cat > "$test_dir/retry-ticket.json" <<'EOF'
{"id":"retry-test","kind":"task","title":"Retry Test","created_at":"2026-10-20"}
EOF
export RETRY_OUTPUT="$test_dir/retry-output"
sh "$executor" "$test_dir/retry-workflow.yaml" --ticket-file "$test_dir/retry-ticket.json" --retry target-command >"$test_dir/retry.log" 2>&1
[ "$(cat "$RETRY_OUTPUT")" = "retry" ] || { echo "FAIL: retry target did not run"; exit 1; }
grep -q '幂等重试 step: target-command' "$test_dir/retry.log"
echo "PASS: --retry executes target without rejecting unrelated agent step"

echo "=== negative: retry rejects overlapping checkpoint fields before writes ==="
cat > "$test_dir/retry-overlap-workflow.yaml" <<'EOF'
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
cat > "$test_dir/retry-overlap-ticket.json" <<'EOF'
{"id":"retry-overlap-test","kind":"task","title":"Retry Overlap Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/retry-overlap-ticket.json" "$test_dir/retry-overlap-ticket.before"
set +e
RETRY_OVERLAP_OUTPUT="$test_dir/retry-overlap-output" sh "$executor" "$test_dir/retry-overlap-workflow.yaml" --ticket-file "$test_dir/retry-overlap-ticket.json" --retry retry-target >"$test_dir/retry-overlap.log" 2>&1
retry_overlap_rc=$?
set -e
[ "$retry_overlap_rc" -ne 0 ] || { echo "FAIL: overlapping checkpoint fields were accepted"; exit 1; }
grep -q 'checkpoint_field 重叠' "$test_dir/retry-overlap.log"
[ ! -e "$test_dir/retry-overlap-output" ] || { echo "FAIL: overlapping retry workflow ran a command"; exit 1; }
[ ! -e "$test_dir/retry-overlap-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: overlapping retry workflow wrote a sidecar"; exit 1; }
cmp -s "$test_dir/retry-overlap-ticket.json" "$test_dir/retry-overlap-ticket.before"
echo "PASS: overlapping checkpoint paths fail before writes"

echo "=== negative: retry target must exist ==="
set +e
sh "$executor" "$test_dir/retry-workflow.yaml" --ticket-file "$test_dir/retry-ticket.json" --retry missing-step >"$test_dir/retry-missing.log" 2>&1
retry_missing_rc=$?
set -e
[ "$retry_missing_rc" -ne 0 ] || { echo "FAIL: nonexistent retry step succeeded"; exit 1; }
grep -q -- '--retry 指定的 step 不存在' "$test_dir/retry-missing.log"
echo "PASS: nonexistent retry step fails closed"

echo "=== negative: empty --retry target writes nothing ==="
cat > "$test_dir/empty-retry-workflow.yaml" <<'EOF'
workflow:
  name: empty-retry
  version: "1.0"
steps:
  - id: step1
    type: command
    command: printf executed>>$EMPTY_RETRY_OUTPUT
    checkpoint_field: checkpoint.test.step1
EOF
cat > "$test_dir/empty-retry-ticket.json" <<'EOF'
{"id":"empty-retry-test","kind":"task","title":"Empty Retry Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/empty-retry-ticket.json" "$test_dir/empty-retry-ticket.before"
set +e
EMPTY_RETRY_OUTPUT="$test_dir/empty-retry.output" sh "$executor" "$test_dir/empty-retry-workflow.yaml" --ticket-file "$test_dir/empty-retry-ticket.json" --retry "" >"$test_dir/empty-retry.log" 2>&1
empty_retry_rc=$?
set -e
[ "$empty_retry_rc" -eq 2 ] || { echo "FAIL: empty --retry returned $empty_retry_rc instead of usage error"; exit 1; }
grep -q -- '--retry 目标不能为空' "$test_dir/empty-retry.log"
[ ! -e "$test_dir/empty-retry.output" ] || { echo "FAIL: empty --retry executed the workflow command"; exit 1; }
[ ! -e "$test_dir/empty-retry-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: empty --retry wrote a sidecar"; exit 1; }
cmp -s "$test_dir/empty-retry-ticket.json" "$test_dir/empty-retry-ticket.before"
echo "PASS: empty --retry fails before command or checkpoint writes"

echo "=== negative: unsupported retry target fails before checkpoint writes ==="
cat > "$test_dir/retry-agent-ticket.json" <<'EOF'
{"id":"retry-agent-test","kind":"task","title":"Retry Agent Test","created_at":"2026-10-20"}
EOF
cp "$test_dir/retry-agent-ticket.json" "$test_dir/retry-agent-ticket.before"
set +e
sh "$executor" "$test_dir/retry-workflow.yaml" --ticket-file "$test_dir/retry-agent-ticket.json" --retry unrelated-agent >"$test_dir/retry-agent.log" 2>&1
retry_agent_rc=$?
set -e
[ "$retry_agent_rc" -ne 0 ] || { echo "FAIL: unsupported retry target succeeded"; exit 1; }
grep -q '没有 agent 适配器' "$test_dir/retry-agent.log"
[ ! -e "$test_dir/retry-agent-ticket.json.workflow-checkpoint-v1.json" ] || { echo "FAIL: unsupported retry target wrote sidecar"; exit 1; }
cmp -s "$test_dir/retry-agent-ticket.json" "$test_dir/retry-agent-ticket.before"
echo "PASS: unsupported retry target fails before checkpoint writes"

echo "=== negative: failed retry invalidates old completion before resume ==="
cat > "$test_dir/retry-failure-workflow.yaml" <<'EOF'
workflow:
  name: retry-failure
  version: "1.0"
steps:
  - id: retry-command
    type: command
    command: printf run >> "$RETRY_FAILURE_OUTPUT"; if [ "${FAIL_RETRY:-0}" = 1 ]; then exit 7; fi
    checkpoint_field: checkpoint.retry_failure.run
EOF
cat > "$test_dir/retry-failure-ticket.json" <<'EOF'
{"id":"retry-failure-test","kind":"task","title":"Retry Failure Test","created_at":"2026-10-20"}
EOF
RETRY_FAILURE_OUTPUT="$test_dir/retry-failure-output" sh "$executor" "$test_dir/retry-failure-workflow.yaml" --ticket-file "$test_dir/retry-failure-ticket.json" >"$test_dir/retry-failure-first.log" 2>&1
set +e
FAIL_RETRY=1 RETRY_FAILURE_OUTPUT="$test_dir/retry-failure-output" sh "$executor" "$test_dir/retry-failure-workflow.yaml" --ticket-file "$test_dir/retry-failure-ticket.json" --retry retry-command >"$test_dir/retry-failure-retry.log" 2>&1
retry_failure_rc=$?
set -e
[ "$retry_failure_rc" -ne 0 ] || { echo "FAIL: failed retry unexpectedly succeeded"; exit 1; }
RETRY_FAILURE_OUTPUT="$test_dir/retry-failure-output" sh "$executor" "$test_dir/retry-failure-workflow.yaml" --ticket-file "$test_dir/retry-failure-ticket.json" --resume >"$test_dir/retry-failure-resume.log" 2>&1
[ "$(cat "$test_dir/retry-failure-output")" = "runrunrun" ] || { echo "FAIL: resume skipped the step after a failed retry"; exit 1; }
grep -q '从此 step 继续执行: retry-command' "$test_dir/retry-failure-resume.log"
echo "PASS: resume reran a step after its retry failed"

schema_dir="$script_dir/../references/schemas"
[ -d "$schema_dir" ] || schema_dir="$script_dir/../../../agent-up/references/schemas"
python3 - "$schema_dir/workflow.schema.json" "$schema_dir/ticket-record.schema.json" <<'PYTHON'
import json, re, sys
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
    if path.endswith('workflow.schema.json'):
        field_pattern = root['properties']['steps']['items']['properties']['checkpoint_field']['pattern']
        assert re.fullmatch(field_pattern, 'checkpoint.test.step1')
    else:
        checkpoint_ref = root['properties']['checkpoint_ref']['description']
        assert 'workflow-checkpoint-v1' in checkpoint_ref
print('PASS: expect_exit schema is integer 0..255')
PYTHON
grep -q 'workflow-checkpoint-v1' "$schema_dir/README.md"

echo "Checkpoint recovery and safety tests passed"
