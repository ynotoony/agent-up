"""json-validator.py workflow 族：workflow 定义解析、状态机语义与 checkpoint 生命周期（票 290 拆分；非独立入口）.

steps/state-machine 解析、条件词表预检与结构化结果求值、映射强制，以及 checkpoint sidecar
的初始化／读取／一致性核对／step 判定／原子写入——票 290 起 checkpoint 生命周期实现单点收敛于
本模块（workflow-executor.sh 只保留调用顺序编排，零生命周期实现副本）。
"""
import json
import os
import re
import sys
import tempfile
from datetime import datetime


TICKET_STATUS_RE = re.compile(
    r'(ready|in_progress|blocked(:[ a-zA-Z0-9-]+)?|review_ready|review_pass|review_fail|done)')

# 状态机转换条件可实现词表（票 209）：三个具名条件＋checkpoint.<路径> 形态；
# 词表外条件（含已退役恒真词 workflow_started 与恒假词 verification_failed/
# manual_retry）在 check-conditions 预检 fail-closed 拒绝，零副作用。
CONDITION_ENUM = ('all_verifications_pass', 'any_verification_failed', 'manual_retry_requested')
CHECKPOINT_CONDITION_RE = re.compile(r'checkpoint(?:\.[a-z_][a-z0-9_]*)+')

# 步骤结构化结果 status 枚举（票 209）；skipped 为词表保留值，executor 写面
# 当前零写入（保留给宿主 agent 适配器的跳过语义）。
RESULT_STATUS = ('passed', 'failed', 'skipped')

# verification_results 项键集（票 209）
VERIFY_ITEM_KEYS = {'name', 'status', 'exit_code'}


def wf_parse_steps(workflow_file):
    """Parse the simplified workflow YAML into a steps JSON array."""
    with open(workflow_file, 'r') as f:
        content = f.read()

    steps = []
    in_steps = False
    current_step = None
    indent_stack = []

    for line in content.splitlines():
        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if stripped.startswith('steps:'):
            in_steps = True
            indent_stack = [indent]
            continue

        if in_steps:
            if re.match(r'^- id:', stripped):
                if current_step:
                    steps.append(current_step)
                current_step = {}
                indent_stack = [indent]
                current_step['id'] = stripped.split(':', 1)[1].strip()

            elif indent == 0 and stripped and not stripped.startswith('-'):
                if current_step:
                    steps.append(current_step)
                    current_step = None
                break

            elif current_step is not None and stripped:
                # 序列项前缀剥离（票 209）：verification 子项以 `- name: ...` 起始，
                # 不剥 `- ` 则键名带前缀（`- name`）被丢弃，逐项 name 恒缺——
                # 结构化 verification_results 需要真实 name，此处统一剥前缀。
                if stripped.startswith('- '):
                    stripped = stripped[2:].strip()
                if ':' in stripped:
                    key, value = stripped.split(':', 1)
                    key = key.strip()
                    value = value.strip()

                    if key in ['type', 'description', 'checkpoint_field', 'agent', 'command']:
                        current_step[key] = value
                    elif key == 'verification':
                        current_step['verification'] = []
                    elif key in ['name', 'check', 'expect', 'expect_exit', 'fail_msg', 'description'] and 'verification' in current_step:
                        if not current_step['verification'] or (key == 'name'):
                            current_step['verification'].append({})
                        if key == 'description':
                            key = 'verify_description'
                        if key == 'expect_exit' and re.fullmatch(r'-?[0-9]+', value):
                            current_step['verification'][-1][key] = int(value)
                        else:
                            current_step['verification'][-1][key] = value

    if current_step:
        steps.append(current_step)

    print(json.dumps(steps))
    return 0


def wf_parse_state_machine(workflow_file):
    """Parse the simplified workflow YAML state_machine block into JSON."""
    with open(workflow_file, 'r') as f:
        content = f.read()

    state_machine = {
        "initial_state": "",
        "states": [],
        "transitions": [],
        "state_to_ticket_status": {}
    }

    in_state_machine = False
    in_states = False
    in_transitions = False
    in_mapping = False
    current_state = None
    current_transition = None

    for line in content.splitlines():
        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if stripped.startswith('state_machine:'):
            in_state_machine = True
            continue

        if in_state_machine:
            if indent == 0 and stripped and not stripped.startswith(' '):
                break

            if stripped.startswith('initial_state:'):
                state_machine['initial_state'] = stripped.split(':', 1)[1].strip()

            elif stripped.startswith('states:'):
                in_states = True
                in_transitions = False
                continue

            elif stripped.startswith('transitions:'):
                in_transitions = True
                in_states = False
                in_mapping = False
                continue

            elif stripped.startswith('state_to_ticket_status:'):
                # state_to_ticket_status 映射块（票 221：workflow_state→ticket_status
                # 显式映射；解析为执行器映射强制的数据面）
                in_mapping = True
                in_states = False
                in_transitions = False
                continue

            elif in_states and re.match(r'^- name:', stripped):
                if current_state:
                    state_machine['states'].append(current_state)
                current_state = {}
                current_state['name'] = stripped.split(':', 1)[1].strip()

            elif in_states and current_state is not None and ':' in stripped:
                key, value = stripped.split(':', 1)
                key = key.strip()
                value = value.strip()
                if key in ['description', 'terminal']:
                    if key == 'terminal':
                        current_state[key] = value.lower() in ['true', 'yes']
                    else:
                        current_state[key] = value

            elif in_transitions and re.match(r'^- from:', stripped):
                if current_transition:
                    state_machine['transitions'].append(current_transition)
                current_transition = {}
                current_transition['from'] = stripped.split(':', 1)[1].strip()

            elif in_transitions and current_transition is not None and ':' in stripped:
                key, value = stripped.split(':', 1)
                key = key.strip()
                value = value.strip()
                if key in ['to', 'condition', 'trigger']:
                    current_transition[key] = value

            # 解析 state_to_ticket_status 映射键值（票 221）
            elif in_mapping and ':' in stripped:
                key, value = stripped.split(':', 1)
                state_machine['state_to_ticket_status'][key.strip()] = value.strip()

    if current_state:
        state_machine['states'].append(current_state)
    if current_transition:
        state_machine['transitions'].append(current_transition)

    print(json.dumps(state_machine))
    return 0


def wf_preflight(retry_step, raw_steps):
    """Validate step ids, checkpoint fields, retry target and step support
    before any checkpoint file is created or updated."""
    steps = json.loads(raw_steps)
    step_ids = [step.get('id', '') for step in steps]
    if len(step_ids) != len(set(step_ids)):
        raise SystemExit('workflow step id 必须唯一')
    if retry_step and retry_step not in step_ids:
        raise SystemExit(f"--retry 指定的 step 不存在: {retry_step}")
    checkpoint_fields = []
    for step in steps:
        field = step.get('checkpoint_field', '')
        if field:
            if not re.fullmatch(r'checkpoint(?:\.[a-z_][a-z0-9_]*)+', field):
                raise SystemExit(f"step {step.get('id', '')} 的 checkpoint_field 格式无效")
            for prior_field, prior_step in checkpoint_fields:
                if field == prior_field or field.startswith(prior_field + '.') or prior_field.startswith(field + '.'):
                    raise SystemExit(f"step {step.get('id', '')} 与 step {prior_step} 的 checkpoint_field 重叠")
            checkpoint_fields.append((field, step.get('id', '')))
        if retry_step and step.get('id') != retry_step:
            continue
        step_type = step.get('type', '')
        if step_type == 'agent':
            raise SystemExit(f"step {step.get('id', '')} 需要宿主 agent 执行器，但当前执行器没有 agent 适配器")
        if step_type not in ('command', 'verification'):
            raise SystemExit(f"未知 step 类型: {step_type}")
        if step_type == 'verification':
            for item in step.get('verification', []):
                value = item.get('expect_exit', 0)
                if type(value) is not int or not 0 <= value <= 255:
                    name = item.get('name', '')
                    raise SystemExit(f"step {step.get('id', '')} verification {name} 的 expect_exit 必须是 0..255 整数")
    return 0


def wf_check_ticket_status(value):
    """Exit 0 iff value is a legal issue-index ticket status (票 221 值域判定)."""
    return 0 if TICKET_STATUS_RE.fullmatch(value) else 1


def wf_check_conditions(raw_state_machine):
    """Fail closed on any transition condition outside the implementable
    vocabulary (票 209). Must run before any checkpoint file is created or any
    step side effect happens; retired words (workflow_started/verification_failed/
    manual_retry) are rejected by the same gate."""
    if raw_state_machine == '-':
        state_machine = json.load(sys.stdin)
    else:
        state_machine = json.loads(raw_state_machine)
    for idx, transition in enumerate(state_machine.get('transitions', [])):
        condition = transition.get('condition', '')
        if condition in CONDITION_ENUM:
            continue
        if CHECKPOINT_CONDITION_RE.fullmatch(condition):
            continue
        raise SystemExit(
            f"transition[{idx}] 条件 {condition!r} 不在可实现条件词表"
            f"（all_verifications_pass|any_verification_failed|manual_retry_requested|"
            f"checkpoint.<路径>）；拒绝执行（workflow_started/verification_failed/manual_retry 已退役）")
    return 0


def _wf_condition_record(checkpoint, field):
    """Navigate a checkpoint.<a>.<b> style path from the checkpoint root;
    returns None when any segment is missing or walks through a non-dict."""
    data = checkpoint
    for part in field.split('.')[1:]:
        if not isinstance(data, dict) or part not in data:
            return None
        data = data[part]
    return data


def wf_eval_condition(condition, raw_checkpoint, raw_steps, retry_step):
    """Evaluate one state-machine condition against structured step results
    (票 209). Prints true/false; exit 0. Unknown conditions print a warning and
    false (defense in depth — check-conditions rejects them before any run)."""
    checkpoint = json.loads(raw_checkpoint) if raw_checkpoint.strip() else {}
    steps = json.loads(raw_steps) if raw_steps.strip() else []
    verdict = False
    if condition == 'all_verifications_pass':
        recorded = 0
        verdict = True
        for step in steps:
            if step.get('type') != 'verification':
                continue
            field = step.get('checkpoint_field', '')
            if not field:
                continue
            record = _wf_condition_record(checkpoint, field)
            if not isinstance(record, dict):
                verdict = False
                break
            recorded += 1
            if record.get('status', 'passed') != 'passed':
                verdict = False
                break
        if recorded == 0:
            verdict = False
    elif condition == 'any_verification_failed':
        for step in steps:
            if step.get('type') != 'verification':
                continue
            field = step.get('checkpoint_field', '')
            if not field:
                continue
            record = _wf_condition_record(checkpoint, field)
            if isinstance(record, dict) and record.get('status') == 'failed':
                verdict = True
                break
    elif condition == 'manual_retry_requested':
        verdict = bool(retry_step)
    elif condition.startswith('checkpoint.'):
        value = _wf_condition_record(checkpoint, condition)
        verdict = value is not None and value is not False and value != '' and value != 0
    else:
        print(f'workflow-executor: 警告：未知条件 {condition}\n', file=sys.stderr)
        verdict = False
    print('true' if verdict else 'false')
    return 0


def wf_map_status(raw_state_machine, to_state):
    """Print state_to_ticket_status[to_state]（票 221 映射解析）.

    Exit codes: 0 = mapped and target in ticket-status enum;
    3 = unmapped (no key for to_state); 1 = mapped but target out of enum.
    """
    if raw_state_machine == '-':
        state_machine = json.load(sys.stdin)
    else:
        state_machine = json.loads(raw_state_machine)
    mapping = state_machine.get('state_to_ticket_status') or {}
    value = mapping.get(to_state, '')
    print(value)
    if value == '':
        return 3
    return 0 if TICKET_STATUS_RE.fullmatch(value) else 1


def wf_checkpoint_init(ticket_file):
    """Register the workflow checkpoint sidecar and anchor ticket checkpoint_ref."""
    def atomic_write(path, document):
        directory = os.path.dirname(path) or '.'
        temporary = None
        try:
            with tempfile.NamedTemporaryFile('w', dir=directory, delete=False, encoding='utf-8') as f:
                json.dump(document, f, indent=2, ensure_ascii=False)
                f.write('\n')
                temporary = f.name
            os.replace(temporary, path)
        finally:
            if temporary and os.path.exists(temporary):
                os.unlink(temporary)

    ticket_file = os.path.realpath(ticket_file)
    with open(ticket_file, encoding='utf-8') as f:
        ticket = json.load(f)
    if not isinstance(ticket, dict):
        raise SystemExit('票文件必须包含 JSON 对象')
    if 'checkpoint' in ticket:
        raise SystemExit('票文件含已废弃的顶层 checkpoint')
    basename = os.path.basename(ticket_file) + '.workflow-checkpoint-v1.json'
    expected_ref = 'workflow-checkpoint-v1:' + basename
    ref = ticket.get('checkpoint_ref', '')
    if not isinstance(ref, str):
        raise SystemExit('checkpoint_ref 必须是字符串')
    if ref and ref != expected_ref:
        raise SystemExit('checkpoint_ref 不是 workflow-checkpoint-v1 固定同目录引用；拒绝解释旧锚点或任意路径')
    path = os.path.join(os.path.dirname(ticket_file), basename)
    if os.path.islink(path):
        raise SystemExit('workflow checkpoint sidecar 不得是符号链接')
    if os.path.lexists(path) and not os.path.isfile(path):
        raise SystemExit('workflow checkpoint sidecar 必须是普通文件')
    if os.path.isfile(path):
        with open(path, encoding='utf-8') as f:
            sidecar = json.load(f)
        if not isinstance(sidecar, dict) or type(sidecar.get('version')) is not int or sidecar['version'] != 1:
            raise SystemExit('workflow checkpoint sidecar version 必须为整数 1')
        if not isinstance(sidecar.get('checkpoint'), dict):
            raise SystemExit('workflow checkpoint sidecar 必须包含 checkpoint 对象')
        if not ref:
            if sidecar['checkpoint'] != {}:
                raise SystemExit('发现无 checkpoint_ref 的非空 workflow checkpoint sidecar；拒绝恢复孤儿状态')
            ticket['checkpoint_ref'] = expected_ref
            atomic_write(ticket_file, ticket)
    elif ref:
        raise SystemExit('checkpoint_ref 指向的 sidecar 文件不存在')
    else:
        # Register an empty checkpoint before running steps. A crash before the
        # ticket pointer is saved leaves only this safe, recoverable empty state.
        atomic_write(path, {'version': 1, 'checkpoint': {}})
        ticket['checkpoint_ref'] = expected_ref
        atomic_write(ticket_file, ticket)
    print(path)
    return 0


def wf_read_checkpoint(checkpoint_file):
    """Read the checkpoint object from a sidecar document."""
    with open(checkpoint_file, encoding='utf-8') as f:
        document = json.load(f)
    if not isinstance(document, dict) or not isinstance(document.get('checkpoint', {}), dict):
        raise SystemExit('checkpoint 文件格式无效：需要对象中的 checkpoint 对象')
    checkpoint = document.get('checkpoint', {})
    print(json.dumps(checkpoint))
    return 0


def wf_checkpoint_check(checkpoint_file, raw_checkpoint, raw_steps, retry_step):
    """Validate every checkpoint path this invocation may read or write before
    the first workflow command can produce an external side effect. A retry
    clears its prior completion record first, so a failed retry cannot look
    completed."""
    checkpoint = json.loads(raw_checkpoint)
    steps = json.loads(raw_steps)
    if not isinstance(checkpoint, dict):
        raise SystemExit('checkpoint 根必须为对象')
    missing = object()

    selected_steps = [step for step in steps if not retry_step or step.get('id') == retry_step]
    for step in selected_steps:
        field = step.get('checkpoint_field', '')
        if not field:
            continue
        if not re.fullmatch(r'checkpoint(?:\.[a-z_][a-z0-9_]*)+', field):
            raise SystemExit(f"step {step.get('id', '')} 的 checkpoint_field 格式无效")
        data = checkpoint
        for part in field.split('.')[1:]:
            if not isinstance(data, dict):
                raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的字段路径中间节点必须为对象")
            if part not in data:
                data = missing
                break
            data = data[part]
        if data is missing:
            continue
        if not isinstance(data, dict):
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录必须为对象")
        if data.get('step_name') != step.get('id'):
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 step_name 不匹配")
        completed_at = data.get('completed_at')
        if not isinstance(completed_at, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at):
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 completed_at 格式无效")
        try:
            datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
        except ValueError:
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 completed_at 时间值无效")
        if not isinstance(data.get('outputs'), str):
            raise SystemExit(f"checkpoint 中 step {step.get('id', '')} 的完成记录 outputs 必须为字符串")
        _wf_check_structured_keys(data, f"checkpoint 中 step {step.get('id', '')} 的完成记录")

    if retry_step and checkpoint_file:
        step = next(step for step in steps if step.get('id') == retry_step)
        field = step.get('checkpoint_field', '')
        if field:
            with open(checkpoint_file, encoding='utf-8') as f:
                document = json.load(f)
            current = document['checkpoint']
            parts = field.split('.')[1:]
            parents = []
            for part in parts[:-1]:
                if part not in current:
                    current = None
                    break
                parents.append((current, part))
                current = current[part]
            leaf = parts[-1]
            if current is not None and leaf in current:
                del current[leaf]
                for parent, key in reversed(parents):
                    if parent[key] == {}:
                        del parent[key]
                    else:
                        break
                directory = os.path.dirname(checkpoint_file) or '.'
                temporary = None
                try:
                    with tempfile.NamedTemporaryFile('w', dir=directory, delete=False, encoding='utf-8') as f:
                        json.dump(document, f, indent=2, ensure_ascii=False)
                        f.write('\n')
                        temporary = f.name
                    os.replace(temporary, checkpoint_file)
                finally:
                    if temporary and os.path.exists(temporary):
                        os.unlink(temporary)
    return 0


def _wf_check_structured_keys(record, what):
    """Validate the structured result keys of a completion record (票 209):
    a leaf is either a legacy three-key record (no structured keys) or a full
    six-key record (status/exit_code/verification_results all present and
    valid); partial presence is rejected — no intermediate form."""
    present = {'status', 'exit_code', 'verification_results'} & set(record)
    if present and present != {'status', 'exit_code', 'verification_results'}:
        raise SystemExit(f'{what}结构化键残缺（须 legacy 三键或新六键完整）：缺 {sorted({"status", "exit_code", "verification_results"} - present)}')
    if 'status' in present:
        if record['status'] not in RESULT_STATUS:
            raise SystemExit(f'{what}status 越枚举（passed|failed|skipped）: {record["status"]!r}')
    if 'exit_code' in present:
        code = record['exit_code']
        if type(code) is not int or isinstance(code, bool) or not 0 <= code <= 255:
            raise SystemExit(f'{what}exit_code 须为 0..255 整数: {code!r}')
    if 'verification_results' in present:
        results = record['verification_results']
        if not isinstance(results, list):
            raise SystemExit(f'{what}verification_results 必须为数组')
        for item in results:
            if not isinstance(item, dict) or set(item) != VERIFY_ITEM_KEYS:
                raise SystemExit(f'{what}verification_results 项须恰为键 {sorted(VERIFY_ITEM_KEYS)}')
            if not isinstance(item['name'], str) or not item['name']:
                raise SystemExit(f'{what}verification_results 项 name 须为非空字符串')
            if item['status'] not in ('passed', 'failed'):
                raise SystemExit(f'{what}verification_results 项 status 须为 passed|failed: {item["status"]!r}')
            code = item['exit_code']
            if type(code) is not int or isinstance(code, bool) or not 0 <= code <= 255:
                raise SystemExit(f'{what}verification_results 项 exit_code 须为 0..255 整数: {code!r}')


def wf_step_check(raw_checkpoint, checkpoint_field, step_id):
    """Resume-mode single-step completion check; prints true/false, fails
    closed on invalid completion records. Completion for resume means status
    passed (legacy records without status count as passed, 票 209 backward
    compatibility); failed/skipped records are re-run."""

    checkpoint = json.loads(raw_checkpoint)
    field = checkpoint_field.split('.')
    data = checkpoint
    for key in field[1:]:
        if not isinstance(data, dict):
            raise SystemExit('checkpoint 路径中间节点必须为对象')
        if key not in data:
            print('false')
            return 0
        data = data[key]
    else:
        if not isinstance(data, dict):
            raise SystemExit('完成记录必须为对象')
        if data.get('step_name') != step_id:
            raise SystemExit('完成记录 step_name 与当前 step 不匹配')
        completed_at = data.get('completed_at')
        if not isinstance(completed_at, str) or not completed_at:
            raise SystemExit('完成记录 completed_at 必须为非空字符串')
        if not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at):
            raise SystemExit('完成记录 completed_at 格式无效')
        try:
            datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
        except ValueError:
            raise SystemExit('完成记录 completed_at 时间值无效')
        if not isinstance(data.get('outputs'), str):
            raise SystemExit('完成记录 outputs 必须为字符串')
        _wf_check_structured_keys(data, '完成记录')
        print('true' if data.get('status', 'passed') == 'passed' else 'false')
    return 0


def _wf_parse_verify_items(encoded):
    """Decode the executor's verification-result items encoding (票 209):
    items separated by \\x1e, fields (name/status/exit_code) by \\x1f; empty
    string means no items. Returns the validated JSON-ready list."""
    items = []
    if encoded == '':
        return items
    for chunk in encoded.split('\x1e'):
        if chunk == '':
            continue
        parts = chunk.split('\x1f')
        if len(parts) != 3:
            raise SystemExit('verification_results 项编码字段数须为 3（name/status/exit_code）')
        name, status, exit_code = parts
        if not name:
            raise SystemExit('verification_results 项 name 须非空')
        if status not in ('passed', 'failed'):
            raise SystemExit(f'verification_results 项 status 须为 passed|failed: {status!r}')
        if not re.fullmatch(r'[0-9]+', exit_code) or int(exit_code) > 255:
            raise SystemExit(f'verification_results 项 exit_code 须为 0..255 整数: {exit_code!r}')
        items.append({'name': name, 'status': status, 'exit_code': int(exit_code)})
    return items


def wf_record_step(checkpoint_file, ticket_file, checkpoint_field, step_id,
                   completed_at, step_outputs, step_status, step_exit_code,
                   verify_items_encoded):
    """Atomically record one step (with its structured result, 票 209) into the
    sidecar, then anchor the ticket's checkpoint_ref (sidecar first, pointer
    second)."""
    # 读取票文件；顶层 checkpoint 是旧格式，永不回写。
    with open(ticket_file, encoding='utf-8') as f:
        ticket = json.load(f)
    if 'checkpoint' in ticket:
        raise SystemExit('票文件含已废弃的顶层 checkpoint')

    if os.path.exists(checkpoint_file):
        with open(checkpoint_file, encoding='utf-8') as f:
            document = json.load(f)
        if not isinstance(document, dict) or type(document.get('version')) is not int or document['version'] != 1:
            raise SystemExit('workflow checkpoint sidecar version 必须为整数 1')
        if not isinstance(document.get('checkpoint'), dict):
            raise SystemExit('workflow checkpoint sidecar 必须包含 checkpoint 对象')
    else:
        document = {'version': 1, 'checkpoint': {}}

    # 解析 checkpoint_field 路径（如 checkpoint.implementation.ticket_parsed）
    field_parts = checkpoint_field.split('.')
    if len(field_parts) < 2 or field_parts[0] != 'checkpoint':
        raise SystemExit('checkpoint_field 必须以 checkpoint. 开头')

    # 结构化结果值域死守（票 209）：status 枚举、exit_code 0..255、
    # verification_results 项编码逐项校验后再落盘。
    if step_status not in RESULT_STATUS:
        raise SystemExit(f'step status 越枚举（passed|failed|skipped）: {step_status!r}')
    if not re.fullmatch(r'[0-9]+', step_exit_code) or int(step_exit_code) > 255:
        raise SystemExit(f'step exit_code 须为 0..255 整数: {step_exit_code!r}')
    verify_items = _wf_parse_verify_items(verify_items_encoded)

    # 从 checkpoint 根开始导航（跳过第一个 'checkpoint'）
    current = document['checkpoint']

    # 导航到目标位置的父节点
    for part in field_parts[1:-1]:
        if part not in current:
            current[part] = {}
        current = current[part]

    # 写入步骤级 checkpoint（含结构化结果；写面恒六键，票 209）
    last_field = field_parts[-1]
    current[last_field] = {
        "step_name": step_id,
        "completed_at": completed_at,
        "outputs": step_outputs.strip() if step_outputs else "",
        "status": step_status,
        "exit_code": int(step_exit_code),
        "verification_results": verify_items
    }

    # 写回独立 checkpoint 文件（原子化：先写临时文件，再替换）。
    checkpoint_dir = os.path.dirname(checkpoint_file) or '.'
    os.makedirs(checkpoint_dir, exist_ok=True)
    with tempfile.NamedTemporaryFile('w', dir=checkpoint_dir, delete=False, encoding='utf-8') as tmp_f:
        json.dump(document, tmp_f, indent=2, ensure_ascii=False)
        tmp_f.write('\n')
        checkpoint_tmp = tmp_f.name
    os.replace(checkpoint_tmp, checkpoint_file)

    # 票体只保存指针；保持其他字段原样。
    ticket['checkpoint_ref'] = 'workflow-checkpoint-v1:' + os.path.basename(checkpoint_file)
    ticket_dir = os.path.dirname(ticket_file) or '.'
    with tempfile.NamedTemporaryFile('w', dir=ticket_dir, delete=False, encoding='utf-8') as tmp_f:
        json.dump(ticket, tmp_f, indent=2, ensure_ascii=False)
        tmp_f.write('\n')
        ticket_tmp = tmp_f.name
    os.replace(ticket_tmp, ticket_file)
    print(f"Checkpoint 已写入外部文件: {checkpoint_file}#{checkpoint_field}")
    return 0
