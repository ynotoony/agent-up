#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite workflow-trust "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: workflow-trust（票 291 自 suite-workflow-contract 拆出的 shell 信任边界能力面）：
# 票 213 —— --allow-shell 显式授权、缺省拒绝 command/verification 执行、--param/--ticket-file/--retry
# 调用方输入只登记不拼接；负例以副作用探针与零写入断言证明未执行。

suite_workflow_trust() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='workflow-trust'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/DIRworkflow-trust
  mkdir -p "$D"
  EXECUTOR="$SCRIPT_DIR/workflow-executor.sh"
  SCHEMA="$PKG_ROOT/references/schemas/workflow.schema.json"
  if [ ! -f "$EXECUTOR" ] || [ ! -f "$SCHEMA" ]; then
    bad '被测面齐备（executor/schema）' "executor=$EXECUTOR schema=$SCHEMA"
    suite_summary 'workflow-trust'
    return 0
  fi

  # ---- shell 信任边界（票 213）：--allow-shell 显式授权、缺省拒绝 ----
  # workflow 文件是受信规则文件；command/verification 原样执行须显式授权。
  # 调用方输入（--param/--ticket-file/--retry）只登记，不拼接进命令。

  mkdir -p "$D/trust/deny-cmd" "$D/trust/deny-verify" "$D/trust/grant" "$D/trust/retry" "$D/trust/inject"

  cat > "$D/trust/deny-cmd/wf.yaml" <<'EOF'
workflow:
  name: contract-trust-deny-cmd
  description: 信任边界负例：未授权 command
steps:
  - id: probe-step
    type: command
    description: 副作用探针
    command: printf ran >> "$WF_TRUST_MARK"
    checkpoint_field: checkpoint.trust.probe
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.trust.probe
EOF
  printf '{"id":"wf-trust-deny-test","kind":"task","title":"WF Trust Deny Test","created_at":"2026-10-28"}\n' > "$D/trust/deny-cmd/ticket.json"
  cp "$D/trust/deny-cmd/ticket.json" "$D/trust/deny-cmd/ticket.before"
  WF_TRUST_MARK="$D/trust/deny-cmd/marker" sh "$EXECUTOR" "$D/trust/deny-cmd/wf.yaml" \
    --ticket-file "$D/trust/deny-cmd/ticket.json" > "$D/trust/deny-cmd/run.log" 2>&1
  trust_deny_rc=$?
  if [ "$trust_deny_rc" -ne 0 ] \
    && [ ! -e "$D/trust/deny-cmd/marker" ] \
    && [ ! -e "$D/trust/deny-cmd/ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$D/trust/deny-cmd/ticket.json" "$D/trust/deny-cmd/ticket.before" \
    && grep -q -- '--allow-shell' "$D/trust/deny-cmd/run.log"; then
    ok 'N22 AC2 未授权 command workflow：exit 非零且先于副作用——探针未执行、零 sidecar、票零改动、报文指名 --allow-shell'
  else
    bad 'N22 AC2 未授权 command workflow：exit 非零且先于副作用——探针未执行、零 sidecar、票零改动、报文指名 --allow-shell' \
      "exit=$trust_deny_rc marker=$([ -e "$D/trust/deny-cmd/marker" ] && echo present || echo absent) $(tail -n 3 "$D/trust/deny-cmd/run.log" | tr '\n' '|')"
  fi

  cat > "$D/trust/deny-verify/wf.yaml" <<'EOF'
workflow:
  name: contract-trust-deny-verify
  description: 信任边界负例：未授权 verification
steps:
  - id: verify-step
    type: verification
    description: 验证副作用探针
    checkpoint_field: checkpoint.trust.verify
    verification:
      - name: probe
        check: printf ran >> "$WF_TRUST_MARK"
        expect: ran
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: all_verifications_pass
EOF
  printf '{"id":"wf-trust-deny-verify-test","kind":"task","title":"WF Trust Deny Verify Test","created_at":"2026-10-28"}\n' > "$D/trust/deny-verify/ticket.json"
  cp "$D/trust/deny-verify/ticket.json" "$D/trust/deny-verify/ticket.before"
  WF_TRUST_MARK="$D/trust/deny-verify/marker" sh "$EXECUTOR" "$D/trust/deny-verify/wf.yaml" \
    --ticket-file "$D/trust/deny-verify/ticket.json" > "$D/trust/deny-verify/run.log" 2>&1
  trust_deny_verify_rc=$?
  if [ "$trust_deny_verify_rc" -ne 0 ] \
    && [ ! -e "$D/trust/deny-verify/marker" ] \
    && [ ! -e "$D/trust/deny-verify/ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$D/trust/deny-verify/ticket.json" "$D/trust/deny-verify/ticket.before" \
    && grep -q -- '--allow-shell' "$D/trust/deny-verify/run.log"; then
    ok 'N23 AC2 未授权 verification-only workflow：exit 非零且先于副作用——check 未执行、零 sidecar、票零改动、报文指名 --allow-shell'
  else
    bad 'N23 AC2 未授权 verification-only workflow：exit 非零且先于副作用——check 未执行、零 sidecar、票零改动、报文指名 --allow-shell' \
      "exit=$trust_deny_verify_rc marker=$([ -e "$D/trust/deny-verify/marker" ] && echo present || echo absent) $(tail -n 3 "$D/trust/deny-verify/run.log" | tr '\n' '|')"
  fi

  # P23（AC3/AC4）：--allow-shell 授权后照常执行；--param 载荷含命令替换与串联
  # 分隔符时零执行、零进入命令，checkpoint 记录只有 workflow 字面量。
  cat > "$D/trust/grant/wf.yaml" <<'EOF'
workflow:
  name: contract-trust-grant
  description: 参数不替换锁测试（已授权）
steps:
  - id: param-command
    type: command
    description: 参数不替换正例命令
    command: printf literal-param
    checkpoint_field: checkpoint.param.command
  - id: param-verify
    type: verification
    description: 参数不替换正例验证
    checkpoint_field: checkpoint.param.verify
    verification:
      - name: param-lock
        check: printf verify-literal
        expect: verify-literal
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.param.command
EOF
  printf '{"id":"wf-trust-grant-test","kind":"task","title":"WF Trust Grant Test","created_at":"2026-10-28"}\n' > "$D/trust/grant/ticket.json"
  WF_TRUST_MARK="$D/trust/grant/injected" sh "$EXECUTOR" "$D/trust/grant/wf.yaml" --allow-shell \
    --ticket-file "$D/trust/grant/ticket.json" \
    --param 'payload=$(touch "$WF_TRUST_MARK")' \
    --param 'payload2=`touch "$WF_TRUST_MARK"`' \
    --param 'payload3=; touch "$WF_TRUST_MARK"' > "$D/trust/grant/run.log" 2>&1
  trust_grant_rc=$?
  if [ "$trust_grant_rc" -eq 0 ] \
    && [ ! -e "$D/trust/grant/injected" ] \
    && python3 - "$D/trust/grant" > /dev/null <<'PY'
import json
import sys

base = sys.argv[1]
with open(base + '/ticket.json.workflow-checkpoint-v1.json', encoding='utf-8') as handle:
    document = json.load(handle)
command = document['checkpoint']['param']['command']
verification = document['checkpoint']['param']['verify']
assert command['outputs'] == 'literal-param', command
assert command['status'] == 'passed' and command['exit_code'] == 0, command
assert verification['outputs'] == '', verification
assert verification['status'] == 'passed' and verification['exit_code'] == 0, verification
assert verification['verification_results'] == [{'name': 'param-lock', 'status': 'passed', 'exit_code': 0}], verification
assert 'payload' not in json.dumps(document, ensure_ascii=False), '--param 值进入 checkpoint'
print('param-lock-ok')
PY
  then
    ok 'P23 AC3/AC4 --allow-shell 授权后执行；--param 的命令替换/串联载荷零执行、零进入命令，记录仅 workflow 字面量'
  else
    bad 'P23 AC3/AC4 --allow-shell 授权后执行；--param 的命令替换/串联载荷零执行、零进入命令，记录仅 workflow 字面量' \
      "exit=$trust_grant_rc marker=$([ -e "$D/trust/grant/injected" ] && echo present || echo absent) $(tail -n 3 "$D/trust/grant/run.log" | tr '\n' '|')"
  fi

  # N24（AC4）：--retry 注入载荷只作为不存在的 step id 被拒，零副作用
  cp "$D/trust/grant/wf.yaml" "$D/trust/retry/wf.yaml"
  printf '{"id":"wf-trust-retry-test","kind":"task","title":"WF Trust Retry Test","created_at":"2026-10-28"}\n' > "$D/trust/retry/ticket.json"
  cp "$D/trust/retry/ticket.json" "$D/trust/retry/ticket.before"
  WF_TRUST_MARK="$D/trust/retry/injected" sh "$EXECUTOR" "$D/trust/retry/wf.yaml" --allow-shell \
    --ticket-file "$D/trust/retry/ticket.json" \
    --retry 'param-command; touch "$WF_TRUST_MARK"' > "$D/trust/retry/run.log" 2>&1
  trust_retry_rc=$?
  if [ "$trust_retry_rc" -ne 0 ] \
    && [ ! -e "$D/trust/retry/injected" ] \
    && [ ! -e "$D/trust/retry/ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$D/trust/retry/ticket.json" "$D/trust/retry/ticket.before" \
    && grep -q -- '--retry 指定的 step 不存在' "$D/trust/retry/run.log"; then
    ok 'N24 AC4 --retry 注入载荷（step id 后接 ; touch）：按不存在 step 拒绝，探针未执行、零 sidecar、票零改动'
  else
    bad 'N24 AC4 --retry 注入载荷（step id 后接 ; touch）：按不存在 step 拒绝，探针未执行、零 sidecar、票零改动' \
      "exit=$trust_retry_rc marker=$([ -e "$D/trust/retry/injected" ] && echo present || echo absent) $(tail -n 3 "$D/trust/retry/run.log" | tr '\n' '|')"
  fi

  # P24（AC4）：--ticket-file 路径含命令替换文本时按普通文件路径处理，零执行
  cat > "$D/trust/inject/wf.yaml" <<'EOF'
workflow:
  name: contract-trust-inject
  description: ticket 路径注入负例（已授权）
steps:
  - id: inject-step
    type: command
    description: 路径注入探针
    command: printf ticket-file-literal
    checkpoint_field: checkpoint.trust.inject
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.trust.inject
EOF
  inj_mark="$D/trust/inject/injected"
  inj_ticket="$D/trust/inject/ticket\$(touch \"\$WF_TRUST_MARK\").json"
  printf '{"id":"wf-trust-inject-test","kind":"task","title":"WF Trust Inject Test","created_at":"2026-10-28"}\n' > "$inj_ticket"
  WF_TRUST_MARK="$inj_mark" sh "$EXECUTOR" "$D/trust/inject/wf.yaml" --allow-shell \
    --ticket-file "$inj_ticket" > "$D/trust/inject/run.log" 2>&1
  trust_inject_rc=$?
  if [ "$trust_inject_rc" -eq 0 ] \
    && [ ! -e "$inj_mark" ] \
    && python3 - "$inj_ticket.workflow-checkpoint-v1.json" > /dev/null <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    record = json.load(handle)['checkpoint']['trust']['inject']
assert record['outputs'] == 'ticket-file-literal', record
assert record['status'] == 'passed', record
print('ticket-path-lock-ok')
PY
  then
    ok 'P24 AC4 --ticket-file 路径含命令替换文本：按普通路径处理、命令照跑，注入载荷零执行'
  else
    bad 'P24 AC4 --ticket-file 路径含命令替换文本：按普通路径处理、命令照跑，注入载荷零执行' \
      "exit=$trust_inject_rc marker=$([ -e "$inj_mark" ] && echo present || echo absent) $(tail -n 3 "$D/trust/inject/run.log" | tr '\n' '|')"
  fi

  # P25（AC1）：信任边界缺省值写入 schema 合同与 executor/README 文档
  usage_out=$(sh "$EXECUTOR" --help 2>&1) || usage_out=''
  if python3 - "$SCHEMA" > "$D/trust/doc.log" 2>&1 <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    schema = json.load(handle)
description = schema['description']
assert '信任边界' in description and '--allow-shell' in description, description[:200]
steps = schema['properties']['steps']['items']['properties']
assert '--allow-shell' in steps['command']['description'], steps['command']['description']
check = steps['verification']['items']['properties']['check']
assert '--allow-shell' in check['description'], check['description']
print('trust-doc-ok')
PY
  then
    doc_schema_ok=1
  else
    doc_schema_ok=0
  fi
  if [ "$doc_schema_ok" -eq 1 ] \
    && printf '%s' "$usage_out" | grep -q -- '--allow-shell' \
    && grep -q -- '--allow-shell' "$SCRIPT_DIR/README.md" \
    && grep -q -- '--allow-shell' "$PKG_ROOT/references/schemas/README.md"; then
    ok 'P25 AC1 信任边界缺省值写入 schema description/字段描述、executor 用法与两处 README 登记'
  else
    bad 'P25 AC1 信任边界缺省值写入 schema description/字段描述、executor 用法与两处 README 登记' \
      "schema/usage/README 缺少 --allow-shell 信任边界声明: $(tail -n 2 "$D/trust/doc.log" | tr '\n' '|')"
  fi

  suite_summary 'workflow-trust'
}
