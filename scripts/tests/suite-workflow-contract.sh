#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite workflow-contract "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: workflow-contract（workflow schema、实例与执行子集合同正反例：
# references/workflows/ 两实例与 checkpoint sidecar 夹具过同一 schema 子集
# 校验；越 schema／越子集负例被拒且指名原因；checkpoint_field 的 schema
# pattern 与 workflow-executor.sh 运行时正则做语料级等价核对；state_machine
# 跨字段三校验（initial_state/transition from/to∈states）与 state_to_ticket_status
# 映射目标枚举（对 issue-index.schema.json Task 流转值逐键核对＋两 schema 映射
# pattern 语料级漂移护栏）正负例常驻；executor 写面
# 记录与文档六键语义逐键一致（三键基础＋三键结构化结果，票 209）且 --resume
# 回读接受、legacy 三键读面兼容；unsupported-step 负例在
# checkpoint sidecar 落盘与任何步骤副作用之前失败；executor 映射强制（票 221）
# 运行时正负例常驻：合法映射按映射值端到端写票索引，未映射（implementation_done）
# 与映射目标越票状态枚举拒绝转换且票索引零写入；条件语义结构化（票 209）
# 正负例常驻：可实现条件词表（all_verifications_pass/any_verification_failed/
# manual_retry_requested/checkpoint.<路径>）schema pattern 与引擎词表语料级
# 等价、已退役恒真／恒假词 schema 与 executor 双层拒绝（先于 sidecar 落盘）、
# 空 checkpoint 不为 all_verifications_pass（AC1 回归）、验证失败落结构化
# failed 记录并进 blocked（AC2）、manual_retry_requested 仅显式 --retry 生效
# 且重试推进可达（AC3）；fixture 定位合同正例常驻：两实例入口名带
# -fixture 后缀且不与生产入口（triage/implementation/review）共用、描述首句声明
# 「参考 fixture（非生产）」、步骤命令与验证项零固定路径写入（/tmp 重定向、
# 绝对路径重定向、fixture 内 mktemp 均拒），配同名副本负例（入口名改回 triage
# 须非零退出并指名与生产入口共用）；triage fixture 隔离 cwd 端到端执行
# 零外溢（零新增文件，旧 /tmp 占位写入已删）；implementation fixture 的 agent
# step 经 executor 在任何 sidecar 落盘与步骤副作用之前 fail-closed（exit 非零、
# 零 sidecar、票零改动、报文指名适配器缺失）。夹具全 mktemp 自建不入
# 仓，被测对象只读；YAML 解析为夹具专用极简块级解析器（映射/序列/纯量/引号
# 纯量，不支持锚点、流集合与多行块标量），校验关键字覆盖 workflow.schema.json
# 在用全集：type/required/properties/patternProperties/additionalProperties/
# pattern/enum/const/minLength/minItems/minimum/maximum/items/oneOf）
# ============================================================

# 夹具校验器（生成到 mktemp 目录，不入包）。模式：
#   schema <workflow.yaml> <schema.json>   实例校验，违例行打印并 exit 1
#   classify <workflow.yaml>               按 executor 支持子集输出逐步骤分类 JSON
#   positioning <workflow.yaml>            fixture 定位合同：-fixture 后缀＋描述非生产声明＋零外溢写入
#   sidecar <sidecar.json> <workflow.yaml> sidecar 合同校验＋与实例 checkpoint_field 交叉核对
#   pattern-equiv <schema.json> <executor.sh>  checkpoint_field pattern 与运行时正则语料等价
#   mapping-check <workflow.yaml> <schema.json> <issue-index.schema.json>
#                                          state_to_ticket_status 映射目标枚举核对＋两 schema 映射 pattern 漂移护栏
wf_emit_validator() {
  cat > "$1" <<'WFPY'
import json
import re
import sys
from datetime import datetime

TS_RE = re.compile(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
RECORD_KEYS = {'step_name', 'completed_at', 'outputs'}
STRUCT_KEYS = {'status', 'exit_code', 'verification_results'}


def scalar(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ('"', "'"):
        return text[1:-1]
    if text in ('true', 'false'):
        return text == 'true'
    if re.fullmatch(r'-?[0-9]+', text):
        return int(text)
    return text


def key_of(text):
    if text.endswith(':'):
        return text[:-1].strip(), ''
    match = re.match(r'([A-Za-z_][A-Za-z0-9_-]*):\s+(.*)$', text)
    if match:
        return match.group(1), match.group(2)
    return None


def yaml_load(text):
    items = []
    for raw in text.splitlines():
        if not raw.strip():
            continue
        items.append([len(raw) - len(raw.lstrip(' ')), raw.strip()])
    state = {'pos': 0}

    def parse_node(min_indent):
        if state['pos'] >= len(items):
            return None
        indent, content = items[state['pos']]
        if indent < min_indent:
            return None
        if content == '-' or content.startswith('- '):
            return parse_seq(indent)
        return parse_map(indent)

    def parse_seq(seq_indent):
        seq = []
        while state['pos'] < len(items):
            indent, content = items[state['pos']]
            if indent < seq_indent:
                break
            if indent > seq_indent or not (content == '-' or content.startswith('- ')):
                raise ValueError('夹具 YAML 序列缩进非法: ' + content)
            state['pos'] += 1
            rest = content[1:].strip()
            if not rest:
                seq.append(parse_node(seq_indent + 1))
            else:
                parsed = key_of(rest)
                if parsed is None:
                    seq.append(scalar(rest))
                else:
                    key, value = parsed
                    items.insert(state['pos'], [seq_indent + 2, key + ':' + ((' ' + value) if value else '')])
                    seq.append(parse_map(seq_indent + 2))
        return seq

    def parse_map(map_indent):
        mapping = {}
        while state['pos'] < len(items):
            indent, content = items[state['pos']]
            if indent < map_indent or content == '-' or content.startswith('- '):
                break
            if indent > map_indent:
                raise ValueError('夹具 YAML 映射缩进非法: ' + content)
            parsed = key_of(content)
            if parsed is None:
                raise ValueError('夹具 YAML 映射行非法: ' + content)
            key, value = parsed
            state['pos'] += 1
            if value:
                mapping[key] = scalar(value)
            else:
                child = parse_node(map_indent + 1)
                mapping[key] = {} if child is None else child
        return mapping

    root = parse_node(0)
    if state['pos'] != len(items):
        raise ValueError('夹具 YAML 存在未消费行: ' + items[state['pos']][1])
    return root


def check_type(expected, value):
    if expected == 'object':
        return isinstance(value, dict)
    if expected == 'array':
        return isinstance(value, list)
    if expected == 'string':
        return isinstance(value, str)
    if expected == 'integer':
        return type(value) is int
    if expected == 'number':
        return isinstance(value, (int, float)) and type(value) is not bool
    if expected == 'boolean':
        return type(value) is bool
    return True


def validate(schema, value, path, errors):
    if not isinstance(schema, dict):
        return
    expected = schema.get('type')
    if expected is not None and not check_type(expected, value):
        errors.append(f'{path}: 期望类型 {expected}')
        return
    if 'const' in schema and value != schema['const']:
        errors.append(f'{path}: 不满足 const {schema["const"]!r}')
    if 'enum' in schema and value not in schema['enum']:
        errors.append(f'{path}: 值不在 enum 内: {value!r}')
    if isinstance(value, str):
        if 'pattern' in schema and re.search(schema['pattern'], value) is None:
            errors.append(f'{path}: 不匹配 pattern {schema["pattern"]}')
        if 'minLength' in schema and len(value) < schema['minLength']:
            errors.append(f'{path}: 长度小于 minLength {schema["minLength"]}')
    if isinstance(value, list):
        if 'minItems' in schema and len(value) < schema['minItems']:
            errors.append(f'{path}: 项数少于 minItems {schema["minItems"]}')
        if 'items' in schema:
            for index, item in enumerate(value):
                validate(schema['items'], item, f'{path}[{index}]', errors)
    if isinstance(value, dict):
        for name in schema.get('required', []):
            if name not in value:
                errors.append(f'{path}: 缺 required 字段 {name}')
        properties = schema.get('properties', {})
        pattern_properties = schema.get('patternProperties', {})
        for name, child in value.items():
            child_path = f'{path}.{name}'
            matched = False
            if name in properties:
                matched = True
                validate(properties[name], child, child_path, errors)
            for pattern, sub in pattern_properties.items():
                if re.search(pattern, name):
                    matched = True
                    validate(sub, child, child_path, errors)
            if not matched and 'additionalProperties' in schema:
                extra = schema['additionalProperties']
                if extra is False:
                    errors.append(f'{child_path}: 不允许的额外字段')
                elif isinstance(extra, dict):
                    validate(extra, child, child_path, errors)
    if isinstance(value, (int, float)) and type(value) is not bool:
        if 'minimum' in schema and value < schema['minimum']:
            errors.append(f'{path}: 小于 minimum {schema["minimum"]}')
        if 'maximum' in schema and value > schema['maximum']:
            errors.append(f'{path}: 大于 maximum {schema["maximum"]}')
    if 'oneOf' in schema:
        hits = 0
        for sub in schema['oneOf']:
            sub_errors = []
            validate(sub, value, path, sub_errors)
            if not sub_errors:
                hits += 1
        if hits != 1:
            errors.append(f'{path}: oneOf 命中 {hits}（须恰 1）')


def cross_check_state_machine(workflow, errors):
    """schema 子集校验后的跨字段三校验：initial_state 与 transition from/to 必须∈states。"""
    state_machine = workflow.get('state_machine', {})
    if not isinstance(state_machine, dict):
        return
    state_names = {s['name'] for s in state_machine.get('states', []) if isinstance(s, dict) and 'name' in s}
    initial = state_machine.get('initial_state')
    if initial and initial not in state_names:
        errors.append(f'$.state_machine.initial_state: 初始状态必须存在于 states 列表内: {initial!r}')
    for idx, transition in enumerate(state_machine.get('transitions', [])):
        if not isinstance(transition, dict):
            continue
        if transition.get('from') and transition['from'] not in state_names:
            errors.append(f'$.state_machine.transitions[{idx}].from: 源状态必须存在于 states 列表内: {transition["from"]!r}')
        if transition.get('to') and transition['to'] not in state_names:
            errors.append(f'$.state_machine.transitions[{idx}].to: 目标状态必须存在于 states 列表内: {transition["to"]!r}')


def mapping_check(workflow_path, schema_path, issue_index_path):
    """state_to_ticket_status 映射合同：目标逐一过 issue-index 票状态枚举（Task 流转值），
    且 workflow.schema 映射值 pattern 与 issue-index status pattern 做语料级漂移护栏
    （Task 流转值同判，superseded 生命周期标签双侧排除）。"""
    with open(issue_index_path, encoding='utf-8') as handle:
        status_pattern = json.load(handle)['properties']['issues']['items']['properties']['status']['pattern']
    with open(schema_path, encoding='utf-8') as handle:
        mapping_schema = json.load(handle)['properties']['state_machine']['properties']['state_to_ticket_status']
    mapping_pattern = mapping_schema['patternProperties']['^[a-z_]+$']['pattern']
    corpus = [
        'ready', 'in_progress', 'blocked', 'blocked: reason-1', 'blocked: x',
        'review_ready', 'review_pass', 'review_fail', 'done', 'superseded',
        'superseded: gone', 'invalid_status', 'BLOCKED', 'ready:', 'blocked:',
    ]
    drifted = [value for value in corpus
               if (re.fullmatch(mapping_pattern, value) is not None)
               != (value != 'superseded' and re.fullmatch(status_pattern, value) is not None)]
    assert not drifted, f'workflow.schema 映射值 pattern 与 issue-index 票状态枚举漂移: {drifted}'
    with open(workflow_path, encoding='utf-8') as handle:
        workflow = yaml_load(handle.read())
    mapping = (workflow.get('state_machine') or {}).get('state_to_ticket_status')
    errors = []
    if not isinstance(mapping, dict) or not mapping:
        errors.append('$.state_machine.state_to_ticket_status: 缺显式映射声明（workflow_state→ticket_status）')
    else:
        for key in sorted(mapping):
            value = mapping[key]
            if value == 'superseded' or re.fullmatch(status_pattern, value) is None:
                errors.append(f'$.state_machine.state_to_ticket_status.{key}: '
                              f'映射目标 {value!r} 不在 issue-index 票状态枚举（Task 流转值）内')
    for line in errors:
        print(line)
    if not errors:
        print(f'mapping ok: {len(mapping)} 个映射目标均在 issue-index 票状态枚举内')
    return 1 if errors else 0


def valid_timestamp(value):
    if not isinstance(value, str) or TS_RE.fullmatch(value) is None:
        return False
    try:
        datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        return False
    return True


def node_check(node, path, errors):
    if not isinstance(node, dict):
        errors.append(f'{path}: 节点必须为对象')
        return
    keys = set(node)
    if RECORD_KEYS <= keys:
        struct_present = STRUCT_KEYS & keys
        extra = keys - RECORD_KEYS - struct_present
        if extra:
            errors.append(f'{path}: 记录含未定义键 {sorted(extra)}')
        if struct_present and struct_present != STRUCT_KEYS:
            errors.append(f'{path}: 结构化键残缺（须 legacy 三键或六键完整）: {sorted(node)}')
            return
        if not isinstance(node.get('step_name'), str) or not node['step_name']:
            errors.append(f'{path}: step_name 必须为非空字符串')
        if not valid_timestamp(node.get('completed_at')):
            errors.append(f'{path}: completed_at 必须为合法 UTC 时刻（YYYY-MM-DDTHH:MM:SSZ）')
        if not isinstance(node.get('outputs'), str):
            errors.append(f'{path}: outputs 必须为字符串')
        if struct_present:
            if node['status'] not in ('passed', 'failed', 'skipped'):
                errors.append(f'{path}: status 须为 passed|failed|skipped: {node["status"]!r}')
            code = node['exit_code']
            if type(code) is not int or isinstance(code, bool) or not 0 <= code <= 255:
                errors.append(f'{path}: exit_code 须为 0..255 整数: {code!r}')
            results = node['verification_results']
            if not isinstance(results, list):
                errors.append(f'{path}: verification_results 必须为数组')
            else:
                for index, item in enumerate(results):
                    item_path = f'{path}.verification_results[{index}]'
                    if not isinstance(item, dict) or set(item) != {'name', 'status', 'exit_code'}:
                        errors.append(f'{item_path}: 项须恰为 name/status/exit_code 三键')
                        continue
                    if not isinstance(item['name'], str) or not item['name']:
                        errors.append(f'{item_path}.name: 须为非空字符串')
                    if item['status'] not in ('passed', 'failed'):
                        errors.append(f'{item_path}.status: 须为 passed|failed: {item["status"]!r}')
                    item_code = item['exit_code']
                    if type(item_code) is not int or isinstance(item_code, bool) or not 0 <= item_code <= 255:
                        errors.append(f'{item_path}.exit_code: 须为 0..255 整数: {item_code!r}')
        return
    if RECORD_KEYS & keys:
        errors.append(f'{path}: 记录键残缺: {sorted(node)}')
        return
    for name, child in node.items():
        node_check(child, f'{path}.{name}', errors)


def sidecar_check(document, workflow_path):
    errors = []
    checkpoint = None
    if not isinstance(document, dict):
        errors.append('sidecar 根必须为对象')
    else:
        if set(document) != {'version', 'checkpoint'}:
            errors.append(f'sidecar 顶层键须恰为 version/checkpoint，实际 {sorted(document)}')
        if type(document.get('version')) is not int or document.get('version') != 1:
            errors.append('sidecar version 必须为整数 1')
        checkpoint = document.get('checkpoint')
        if not isinstance(checkpoint, dict):
            errors.append('sidecar checkpoint 必须为对象')
        else:
            node_check(checkpoint, 'checkpoint', errors)
    if workflow_path:
        fields = {}
        with open(workflow_path, encoding='utf-8') as handle:
            workflow = yaml_load(handle.read())
        for step in workflow.get('steps', []):
            field = step.get('checkpoint_field', '')
            if field:
                fields[field] = step.get('id', '')

        def walk(node, prefix):
            if not isinstance(node, dict) or RECORD_KEYS <= set(node):
                if isinstance(node, dict):
                    full = 'checkpoint.' + prefix
                    if full not in fields:
                        errors.append(f'sidecar 记录 {full} 不在 workflow 声明的 checkpoint_field 内')
                    elif node.get('step_name') != fields[full]:
                        errors.append(f'sidecar 记录 {full} 的 step_name 与步骤 id 不一致')
                return
            for name, child in node.items():
                walk(child, prefix + '.' + name if prefix else name)

        if isinstance(checkpoint, dict):
            walk(checkpoint, '')
    return errors


def pattern_equiv(schema_path, executor_path):
    with open(schema_path, encoding='utf-8') as handle:
        schema = json.load(handle)
    schema_pattern = schema['properties']['steps']['items']['properties']['checkpoint_field']['pattern']
    with open(executor_path, encoding='utf-8') as handle:
        source = handle.read()
    runtime_patterns = re.findall(r"re\.fullmatch\(r'([^']+)'\s*,\s*field\)", source)
    assert runtime_patterns, 'executor 中未找到 checkpoint_field 运行时正则'
    assert len(set(runtime_patterns)) == 1, f'executor 中 checkpoint_field 正则多处不一致: {runtime_patterns}'
    runtime_pattern = runtime_patterns[0]
    corpus = [
        'checkpoint.a', 'checkpoint.a_b.c1', 'checkpoint.implementation',
        'checkpoint.triage.parse_requirement', 'checkpoint.a.b.c.d.e', 'checkpoint._x',
        'checkpoint', 'checkpoint.', 'checkpoint.a.', '.checkpoint.a', 'checkpointZ.a',
        'checkpoint.A', 'checkpoint.1a', 'checkpoint.a-b', 'checkpoint.a..b',
        'checkpoint.a b', 'checkpoint.a/b', 'checkpoint-A', 'checkpoint.a.b-c',
    ]
    mismatched = []
    for candidate in corpus:
        schema_verdict = re.fullmatch(schema_pattern, candidate) is not None
        runtime_verdict = re.fullmatch(runtime_pattern, candidate) is not None
        if schema_verdict != runtime_verdict:
            mismatched.append((candidate, schema_verdict, runtime_verdict))
    assert not mismatched, f'schema 与运行时 pattern 判定不等价: {mismatched}'
    for candidate in ('checkpoint.a.b', 'checkpoint.test.step1'):
        assert re.fullmatch(schema_pattern, candidate) and re.fullmatch(runtime_pattern, candidate), candidate
    for candidate in ('checkpoint-A',):
        assert not re.fullmatch(schema_pattern, candidate) and not re.fullmatch(runtime_pattern, candidate), candidate
    print(f'pattern 等价: schema={schema_pattern} runtime={runtime_pattern} corpus={len(corpus)}')


def classify(workflow_path):
    with open(workflow_path, encoding='utf-8') as handle:
        workflow = yaml_load(handle.read())
    result = []
    for step in workflow.get('steps', []):
        step_type = step.get('type')
        if step_type in ('command', 'verification'):
            label = 'executable'
        elif step_type == 'agent':
            label = 'fail-closed'
        else:
            label = 'unknown'
        result.append({'id': step.get('id'), 'type': step_type, 'class': label})
    print(json.dumps(result, ensure_ascii=False))


PRODUCTION_ENTRY_NAMES = ('triage', 'implementation', 'review')
FIXTURE_SPILL_PATTERNS = (
    (r'/tmp\b', '固定路径 /tmp'),
    (r'>\s*/', '重定向到绝对路径'),
    (r'\bmktemp\b', 'fixture 内自建临时路径（临时落盘须由调用方 mktemp 隔离）'),
)


def positioning_check(workflow_path):
    """fixture 定位合同（票 211）：入口名带 -fixture 后缀（不与生产入口同名）、
    描述首句声明「参考 fixture（非生产）」、步骤命令与验证项零固定路径写入。"""
    with open(workflow_path, encoding='utf-8') as handle:
        workflow = yaml_load(handle.read())
    errors = []
    meta = workflow.get('workflow') or {}
    name = meta.get('name', '')
    description = meta.get('description', '')
    if not isinstance(name, str) or not name.endswith('-fixture'):
        errors.append(f'$.workflow.name: reference fixture 入口名须带 -fixture 后缀: {name!r}')
    if name in PRODUCTION_ENTRY_NAMES:
        errors.append(f'$.workflow.name: 与生产入口名共用: {name!r}')
    if not isinstance(description, str) or not description.startswith('参考 fixture（非生产）'):
        errors.append('$.workflow.description: 首句须声明「参考 fixture（非生产）」')
    for step in workflow.get('steps', []):
        step_id = step.get('id', '?')
        texts = [('command', step.get('command'))]
        for index, item in enumerate(step.get('verification') or []):
            if isinstance(item, dict):
                for field in ('check', 'expect'):
                    texts.append((f'verification[{index}].{field}', item.get(field)))
        for field, text in texts:
            if not isinstance(text, str):
                continue
            for pattern, label in FIXTURE_SPILL_PATTERNS:
                if re.search(pattern, text):
                    errors.append(f'$.steps[{step_id}].{field}: {label}（fixture 须零外溢写入）')
    for line in errors:
        print(line)
    if not errors:
        print(f'positioning ok: {name}')
    return 1 if errors else 0


def main(argv):
    if not argv:
        print('用法: wfvalidate.py schema|classify|sidecar|pattern-equiv|mapping-check ...', file=sys.stderr)
        return 2
    mode = argv[0]
    if mode == 'schema':
        with open(argv[2], encoding='utf-8') as handle:
            schema = json.load(handle)
        with open(argv[1], encoding='utf-8') as handle:
            document = yaml_load(handle.read())
        errors = []
        validate(schema, document, '$', errors)
        cross_check_state_machine(document, errors)
        for line in errors:
            print(line)
        return 1 if errors else 0
    if mode == 'classify':
        classify(argv[1])
        return 0
    if mode == 'mapping-check':
        return mapping_check(argv[1], argv[2], argv[3])
    if mode == 'sidecar':
        with open(argv[1], encoding='utf-8') as handle:
            document = json.load(handle)
        errors = sidecar_check(document, argv[2] if len(argv) > 2 else None)
        for line in errors:
            print(line)
        return 1 if errors else 0
    if mode == 'pattern-equiv':
        pattern_equiv(argv[1], argv[2])
        return 0
    if mode == 'positioning':
        return positioning_check(argv[1])
    print(f'未知模式: {mode}', file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
WFPY
}

# validator 通过性断言（$1=场景名，其余=validator 参数）
wf_expect_valid() {
  _wf_name=$1
  shift
  if python3 "$D/wfvalidate.py" "$@" > "$D/last-check.out" 2>&1; then
    ok "$_wf_name"
  else
    bad "$_wf_name" "$(tail -n 4 "$D/last-check.out" | tr '\n' '|')"
  fi
}

# validator 拒绝性断言（$1=场景名 $2=输出须命中的拒绝原因，其余=validator 参数）
wf_expect_invalid() {
  _wf_name=$1
  _wf_needle=$2
  shift 2
  if python3 "$D/wfvalidate.py" "$@" > "$D/last-check.out" 2>&1; then
    bad "$_wf_name" 'validator 意外通过（负例未被拒）'
  elif grep -q -- "$_wf_needle" "$D/last-check.out"; then
    ok "$_wf_name"
  else
    bad "$_wf_name" "未命中拒绝原因 [$_wf_needle]，实际输出: $(tail -n 4 "$D/last-check.out" | tr '\n' '|')"
  fi
}

suite_workflow_contract() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='workflow-contract'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/wfcontract
  mkdir -p "$D/inst" "$D/neg" "$D/sidecar" "$D/write" "$D/ac2"
  EXECUTOR="$SCRIPT_DIR/workflow-executor.sh"
  SCHEMA="$PKG_ROOT/references/schemas/workflow.schema.json"
  INDEX_SCHEMA="$PKG_ROOT/references/schemas/issue-index.schema.json"
  WF_DIR="$PKG_ROOT/references/workflows"

  if [ ! -f "$EXECUTOR" ] || [ ! -f "$SCHEMA" ] || [ ! -f "$INDEX_SCHEMA" ] || [ ! -f "$WF_DIR/triage.yaml" ] || [ ! -f "$WF_DIR/implementation.yaml" ]; then
    bad '被测面齐备（executor/schema/两实例）' "executor=$EXECUTOR schema=$SCHEMA wf_dir=$WF_DIR"
    suite_summary 'workflow-contract'
    return 0
  fi

  wf_emit_validator "$D/wfvalidate.py"

  # ---- 正例面：包内两实例过同一 schema 子集校验 ----

  wf_expect_valid 'P1 包内 triage.yaml 过 schema 子集校验' \
    schema "$WF_DIR/triage.yaml" "$SCHEMA"
  wf_expect_valid 'P2 包内 implementation.yaml 过 schema 子集校验' \
    schema "$WF_DIR/implementation.yaml" "$SCHEMA"

  # ---- 负例面基底：基底夹具必须先过同一校验（负例差异归因于单一变异）----

  cat > "$D/neg/base.yaml" <<'EOF'
workflow:
  name: contract-base
  description: 套件基底夹具
  version: "1.0"
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.base.step
      trigger: base-step
EOF
  wf_expect_valid 'P3 基底夹具过同一 schema 子集校验（负例对照基底）' \
    schema "$D/neg/base.yaml" "$SCHEMA"

  # N1：inputs 退化为序列形态（历史数组写法，其余与基底一致）→ 期望类型 object 拒绝
  cat > "$D/neg/n1-inputs-seq.yaml" <<'EOF'
workflow:
  name: contract-base
  description: 套件基底夹具
  version: "1.0"
inputs:
  - name: sample
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.base.step
      trigger: base-step
EOF
  wf_expect_invalid 'N1 inputs 序列形态被拒（schema 须对象）' 'inputs: 期望类型 object' \
    schema "$D/neg/n1-inputs-seq.yaml" "$SCHEMA"

  # N2：未知步骤类型 → enum 拒绝
  sed 's/    type: command/    type: shell/' "$D/neg/base.yaml" > "$D/neg/n2-unknown-type.yaml"
  wf_expect_invalid 'N2 步骤类型越 enum 被拒' '值不在 enum 内' \
    schema "$D/neg/n2-unknown-type.yaml" "$SCHEMA"

  # N3：步骤缺必备字段 description → required 拒绝
  grep -v '^    description: 基底步骤$' "$D/neg/base.yaml" > "$D/neg/n3-missing-desc.yaml"
  wf_expect_invalid 'N3 步骤缺必备字段 description 被拒' '缺 required 字段 description' \
    schema "$D/neg/n3-missing-desc.yaml" "$SCHEMA"

  # N4：步骤携带 schema 未定义字段 → additionalProperties 拒绝
  cat > "$D/neg/n4-extra-key.yaml" <<'EOF'
workflow:
  name: contract-base
  description: 套件基底夹具
  version: "1.0"
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    priority: high
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.base.step
      trigger: base-step
EOF
  wf_expect_invalid 'N4 步骤额外字段被拒' '不允许的额外字段' \
    schema "$D/neg/n4-extra-key.yaml" "$SCHEMA"

  # N5：checkpoint_field 越 pattern → pattern 拒绝
  sed 's/checkpoint_field: checkpoint.base.step/checkpoint_field: checkpoint.Bad-Segment/' \
    "$D/neg/base.yaml" > "$D/neg/n5-bad-field.yaml"
  wf_expect_invalid 'N5 checkpoint_field 越 pattern 被拒' '不匹配 pattern' \
    schema "$D/neg/n5-bad-field.yaml" "$SCHEMA"

  # N6：verification expect_exit 越 255 → maximum 拒绝
  cat > "$D/neg/n6-exit-range.yaml" <<'EOF'
workflow:
  name: contract-exit-range
  description: 负例 expect_exit 越界
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: check-step
    type: verification
    description: 越界验证
    verification:
      - name: N6
        check: printf probe
        expect: probe
        expect_exit: 256
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
  wf_expect_invalid 'N6 expect_exit 越过 maximum 255 被拒' '大于 maximum' \
    schema "$D/neg/n6-exit-range.yaml" "$SCHEMA"

  # N7：缺 state_machine → required 拒绝
  sed '/^state_machine:/,$d' "$D/neg/base.yaml" > "$D/neg/n7-no-statemachine.yaml"
  wf_expect_invalid 'N7 缺 state_machine 被拒' '缺 required 字段 state_machine' \
    schema "$D/neg/n7-no-statemachine.yaml" "$SCHEMA"

  # N8：type=command 而无 command 字段 → oneOf 零命中拒绝
  sed 's/    command: printf base//' "$D/neg/base.yaml" > "$D/neg/n8-oneof-miss.yaml"
  wf_expect_invalid 'N8 command 步骤缺 command 字段被 oneOf 拒' 'oneOf 命中 0' \
    schema "$D/neg/n8-oneof-miss.yaml" "$SCHEMA"

  # ---- checkpoint_field 合同一致性：schema pattern 与运行时正则语料等价 ----

  wf_expect_valid 'P10 checkpoint_field schema pattern 与运行时正则语料级等价' \
    pattern-equiv "$SCHEMA" "$SCRIPT_DIR/json-validator.py"

  # ---- 实例执行分类：支持子集在两实例上的机械判读 ----

  python3 "$D/wfvalidate.py" classify "$WF_DIR/triage.yaml" > "$D/inst/triage-class.json"
  if python3 - "$D/inst/triage-class.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
ids = [item['id'] for item in data]
assert ids == ['parse-requirement', 'estimate-complexity', 'write-card', 'verify-card', 'register-ticket'], ids
assert [item['class'] for item in data] == ['executable'] * 5, data
PY
  then
    ok 'P11 triage 实例逐步分类＝五步全 executable'
  else
    bad 'P11 triage 实例逐步分类＝五步全 executable' "$(cat "$D/inst/triage-class.json")"
  fi

  python3 "$D/wfvalidate.py" classify "$WF_DIR/implementation.yaml" > "$D/inst/impl-class.json"
  if python3 - "$D/inst/impl-class.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
expect = {
    'read-ticket': 'fail-closed',
    'implement-changes': 'fail-closed',
    'verify-acceptance': 'executable',
    'record-checkpoint': 'executable',
}
assert {item['id']: item['class'] for item in data} == expect, data
PY
  then
    ok 'P12 implementation 实例分类＝2 agent fail-closed＋2 executable'
  else
    bad 'P12 implementation 实例分类＝2 agent fail-closed＋2 executable' "$(cat "$D/inst/impl-class.json")"
  fi

  # ---- fixture 定位合同（票 211）：非生产标注、入口名与生产入口分离、零外溢写入 ----

  wf_expect_valid 'P20 triage fixture 定位合同：入口名带 -fixture 后缀＋描述声明非生产＋步骤零固定路径写入' \
    positioning "$WF_DIR/triage.yaml"
  wf_expect_valid 'P21 implementation fixture 定位合同：入口名带 -fixture 后缀＋描述声明非生产＋步骤零固定路径写入' \
    positioning "$WF_DIR/implementation.yaml"

  # N21（定位合同负例）：副本入口名改回生产入口名 → positioning 须非零退出并指名
  sed 's/^  name: triage-fixture$/  name: triage/' "$WF_DIR/triage.yaml" > "$D/neg/n21-prod-entry-name.yaml"
  wf_expect_invalid 'N21 副本入口名与生产入口同名（name: triage）被 positioning 拒并指名' \
    '与生产入口名共用' positioning "$D/neg/n21-prod-entry-name.yaml"

  # P22（AC2）：triage fixture 端到端执行＝隔离 cwd 零新增文件（旧 /tmp 占位写入已删）
  mkdir -p "$D/fixture/run"
  ( cd "$D/fixture/run" && sh "$EXECUTOR" "$WF_DIR/triage.yaml" > "$D/fixture/triage-run.log" 2>&1 )
  fixture_rc=$?
  fixture_entries=$(find "$D/fixture/run" -mindepth 1 2>/dev/null | head -n 3 | tr '\n' ' ')
  if [ "$fixture_rc" -eq 0 ] && [ -z "$fixture_entries" ]; then
    ok 'P22 AC2 triage fixture 端到端跑通且零外溢（隔离 cwd 零新增文件）'
  else
    bad 'P22 AC2 triage fixture 端到端跑通且零外溢（隔离 cwd 零新增文件）' \
      "exit=$fixture_rc entries=[$fixture_entries] $(tail -n 3 "$D/fixture/triage-run.log" | tr '\n' '|')"
  fi

  # N20（AC3）：implementation fixture 的 agent step 在任何 sidecar 落盘与步骤副作用之前 fail-closed
  mkdir -p "$D/fixture/impl"
  printf '{"id":"wf-fixture-fc-test","kind":"task","title":"WF Fixture FC Test","created_at":"2026-10-27"}\n' > "$D/fixture/impl/ticket.json"
  cp "$D/fixture/impl/ticket.json" "$D/fixture/impl/ticket.before"
  sh "$EXECUTOR" "$WF_DIR/implementation.yaml" --ticket-file "$D/fixture/impl/ticket.json" > "$D/fixture/impl/run.log" 2>&1
  impl_fc_rc=$?
  if [ "$impl_fc_rc" -ne 0 ] \
    && [ ! -e "$D/fixture/impl/ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$D/fixture/impl/ticket.json" "$D/fixture/impl/ticket.before" \
    && grep -q '没有 agent 适配器' "$D/fixture/impl/run.log"; then
    ok 'N20 AC3 implementation fixture：agent step fail-closed——exit 非零、零 sidecar、票零改动、报文指名适配器缺失'
  else
    bad 'N20 AC3 implementation fixture：agent step fail-closed——exit 非零、零 sidecar、票零改动、报文指名适配器缺失' \
      "exit=$impl_fc_rc sidecar=$([ -e "$D/fixture/impl/ticket.json.workflow-checkpoint-v1.json" ] && echo present || echo absent) $(tail -n 3 "$D/fixture/impl/run.log" | tr '\n' '|')"
  fi

  # ---- checkpoint sidecar 夹具：合同校验＋运行时接受 ----

  cat > "$D/sidecar/wf-resume.yaml" <<'EOF'
workflow:
  name: contract-resume
  description: 套件恢复夹具
inputs:
  sample_input:
    type: string
    required: false
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: first-step
    type: command
    description: 已完成步骤
    command: printf first >> "$WF_MARK"
    checkpoint_field: checkpoint.resume.first_step
  - id: second-step
    type: command
    description: 待执行步骤
    command: printf second >> "$WF_MARK"
    checkpoint_field: checkpoint.resume.second_step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: manual_retry_requested
EOF
  cat > "$D/sidecar/ticket.json" <<'EOF'
{"id":"wf-contract-resume-test","kind":"task","title":"WF Contract Resume Test","created_at":"2026-10-21","checkpoint_ref":"workflow-checkpoint-v1:ticket.json.workflow-checkpoint-v1.json"}
EOF
  cat > "$D/sidecar/ticket.json.workflow-checkpoint-v1.json" <<'EOF'
{"version":1,"checkpoint":{"resume":{"first_step":{"step_name":"first-step","completed_at":"2026-10-20T00:00:00Z","outputs":""}}}}
EOF
  wf_expect_valid 'P4 sidecar 夹具过合同校验且与实例 checkpoint_field 交叉核对一致' \
    sidecar "$D/sidecar/ticket.json.workflow-checkpoint-v1.json" "$D/sidecar/wf-resume.yaml"

  WF_MARK="$D/sidecar/marker" sh "$EXECUTOR" "$D/sidecar/wf-resume.yaml" \
    --ticket-file "$D/sidecar/ticket.json" --resume > "$D/sidecar/run.log" 2>&1
  resume_rc=$?
  if [ "$resume_rc" -eq 0 ] && [ "$(cat "$D/sidecar/marker")" = "second" ]; then
    ok 'P5 resume 接受 sidecar 夹具：已完成步跳过、待执行步执行（副作用探针＝second）'
  else
    bad 'P5 resume 接受 sidecar 夹具：已完成步跳过、待执行步执行（副作用探针＝second）' \
      "exit=$resume_rc marker=$(cat "$D/sidecar/marker" 2>/dev/null || echo absent) $(tail -n 3 "$D/sidecar/run.log" | tr '\n' '|')"
  fi

  wf_expect_valid 'P6 运行后 sidecar 仍过合同校验（双记录＋step_name 交叉核对）' \
    sidecar "$D/sidecar/ticket.json.workflow-checkpoint-v1.json" "$D/sidecar/wf-resume.yaml"

  # ---- executor 写面：记录恒六键（三键基础＋三键结构化结果，票 209）且与文档语义逐键一致 ----

  cat > "$D/write/wf-write.yaml" <<'EOF'
workflow:
  name: contract-write
  description: 套件写面夹具
inputs:
  sample_input:
    type: string
    required: false
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: write-step
    type: command
    description: 写面步骤
    command: printf mark >> "$WF_WRITE_MARK"
    checkpoint_field: checkpoint.write.rec
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: manual_retry_requested
EOF
  cat > "$D/write/ticket.json" <<'EOF'
{"id":"wf-contract-write-test","kind":"task","title":"WF Contract Write Test","created_at":"2026-10-21"}
EOF
  WF_WRITE_MARK="$D/write/marker" sh "$EXECUTOR" "$D/write/wf-write.yaml" \
    --ticket-file "$D/write/ticket.json" > "$D/write/run1.log" 2>&1
  write_rc=$?
  if [ "$write_rc" -eq 0 ] && python3 - "$D/write" > /dev/null <<'PY'
import json
import re
import sys
from datetime import datetime

base = sys.argv[1]
with open(base + '/ticket.json.workflow-checkpoint-v1.json', encoding='utf-8') as handle:
    document = json.load(handle)
if set(document) != {'version', 'checkpoint'}:
    sys.exit(f'sidecar 顶层键漂移: {sorted(document)}')
if type(document['version']) is not int or document['version'] != 1:
    sys.exit('sidecar version 类型或取值漂移')
record = document['checkpoint']['write']['rec']
if set(record) != {'step_name', 'completed_at', 'outputs', 'status', 'exit_code', 'verification_results'}:
    sys.exit(f'记录键漂移: {sorted(record)}')
if record['step_name'] != 'write-step':
    sys.exit(f'step_name 漂移: {record["step_name"]!r}')
completed_at = record['completed_at']
if not isinstance(completed_at, str) or re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at) is None:
    sys.exit(f'completed_at 格式漂移: {completed_at!r}')
datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
if record['outputs'] != '':
    sys.exit(f'outputs 漂移: {record["outputs"]!r}')
if record['status'] != 'passed':
    sys.exit(f'status 漂移: {record["status"]!r}')
if record['exit_code'] != 0:
    sys.exit(f'exit_code 漂移: {record["exit_code"]!r}')
if record['verification_results'] != []:
    sys.exit(f'verification_results 漂移: {record["verification_results"]!r}')
print('record-ok')
PY
  then
    ok 'P7 executor 写面记录恒六键且逐键语义一致（三键基础＋status=passed/exit_code=0/verification_results 空表）'
  else
    bad 'P7 executor 写面记录恒六键且逐键语义一致（三键基础＋status=passed/exit_code=0/verification_results 空表）' \
      "exit=$write_rc $(tail -n 3 "$D/write/run1.log" | tr '\n' '|')"
  fi

  if python3 - "$D/write" > /dev/null <<'PY'
import json
import sys

base = sys.argv[1]
with open(base + '/ticket.json', encoding='utf-8') as handle:
    ticket = json.load(handle)
expected_ref = 'workflow-checkpoint-v1:ticket.json.workflow-checkpoint-v1.json'
if ticket.get('checkpoint_ref') != expected_ref:
    sys.exit(f'checkpoint_ref 漂移: {ticket.get("checkpoint_ref")!r}')
if 'checkpoint' in ticket:
    sys.exit('票内出现已废弃的顶层 checkpoint')
print('ref-ok')
PY
  then
    ok 'P8 写面票指针＝workflow-checkpoint-v1 固定 sibling 引用且无顶层 checkpoint'
  else
    bad 'P8 写面票指针＝workflow-checkpoint-v1 固定 sibling 引用且无顶层 checkpoint' '票指针核对未过'
  fi

  WF_WRITE_MARK="$D/write/marker" sh "$EXECUTOR" "$D/write/wf-write.yaml" \
    --ticket-file "$D/write/ticket.json" --resume > "$D/write/run2.log" 2>&1
  if [ "$(cat "$D/write/marker")" = "mark" ]; then
    ok 'P9 写出记录被 --resume 回读接受（已完成步不重跑，探针不翻倍）'
  else
    bad 'P9 写出记录被 --resume 回读接受（已完成步不重跑，探针不翻倍）' \
      "marker=$(cat "$D/write/marker") $(tail -n 3 "$D/write/run2.log" | tr '\n' '|')"
  fi

  # ---- AC2：unsupported-step 在任何 checkpoint/sidecar 落盘与步骤副作用之前失败 ----

  cat > "$D/ac2/wf-ac2.yaml" <<'EOF'
workflow:
  name: contract-ac2
  description: 套件不支持步骤夹具
inputs:
  sample_input:
    type: string
    required: false
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: prepare-step
    type: command
    description: 副作用探针
    command: printf ran >> "$WF_AC2_MARK"
    checkpoint_field: checkpoint.ac2.prepare
  - id: agent-step
    type: agent
    description: 执行器不支持的步骤类型
    agent: some-host-agent
    checkpoint_field: checkpoint.ac2.agent
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: manual_retry_requested
EOF
  cat > "$D/ac2/ticket.json" <<'EOF'
{"id":"wf-contract-ac2-test","kind":"task","title":"WF Contract AC2 Test","created_at":"2026-10-21"}
EOF
  cp "$D/ac2/ticket.json" "$D/ac2/ticket.before"
  WF_AC2_MARK="$D/ac2/marker" sh "$EXECUTOR" "$D/ac2/wf-ac2.yaml" \
    --ticket-file "$D/ac2/ticket.json" > "$D/ac2/run.log" 2>&1
  ac2_rc=$?
  if [ "$ac2_rc" -ne 0 ] \
    && [ ! -e "$D/ac2/marker" ] \
    && [ ! -e "$D/ac2/ticket.json.workflow-checkpoint-v1.json" ] \
    && cmp -s "$D/ac2/ticket.json" "$D/ac2/ticket.before"; then
    ok 'N9 unsupported-step：exit 非零且先于副作用——探针未执行、零 sidecar、票零改动'
  else
    bad 'N9 unsupported-step：exit 非零且先于副作用——探针未执行、零 sidecar、票零改动' \
      "exit=$ac2_rc marker=$([ -e "$D/ac2/marker" ] && echo present || echo absent) sidecar=$([ -e "$D/ac2/ticket.json.workflow-checkpoint-v1.json" ] && echo present || echo absent) $(tail -n 3 "$D/ac2/run.log" | tr '\n' '|')"
  fi

  if grep -q '没有 agent 适配器' "$D/ac2/run.log"; then
    ok 'N10 拒绝报文指名 agent 适配器缺失（fail-closed 行为证据）'
  else
    bad 'N10 拒绝报文指名 agent 适配器缺失（fail-closed 行为证据）' "$(tail -n 3 "$D/ac2/run.log" | tr '\n' '|')"
  fi

  # ---- 状态映射契约（票 220）：两实例映射目标过 issue-index 票状态枚举＋三校验负例 ----

  wf_expect_valid 'P13 triage 映射声明过 issue-index 票状态枚举核对（含两 schema 映射 pattern 漂移护栏）' \
    mapping-check "$WF_DIR/triage.yaml" "$SCHEMA" "$INDEX_SCHEMA"
  wf_expect_valid 'P14 implementation 映射声明过 issue-index 票状态枚举核对（含两 schema 映射 pattern 漂移护栏）' \
    mapping-check "$WF_DIR/implementation.yaml" "$SCHEMA" "$INDEX_SCHEMA"

  # N11：initial_state 不在 states 内 → 跨字段核对拒绝
  cat > "$D/neg/n11-initial-out-of-states.yaml" <<'EOF'
workflow:
  name: contract-n11
  description: 负例：initial_state 不在 states 内
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: nonexistent
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.base.step
EOF
  wf_expect_invalid 'N11 initial_state 越 states 被拒' '初始状态必须存在于' \
    schema "$D/neg/n11-initial-out-of-states.yaml" "$SCHEMA"

  # N12：transition from 不在 states 内 → 跨字段核对拒绝
  cat > "$D/neg/n12-transition-from-invalid.yaml" <<'EOF'
workflow:
  name: contract-n12
  description: 负例：transition from 不在 states 内
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: nonexistent_from
      to: pending
      condition: checkpoint.base.step
EOF
  wf_expect_invalid 'N12 transition from 越 states 被拒' '源状态必须存在于' \
    schema "$D/neg/n12-transition-from-invalid.yaml" "$SCHEMA"

  # N13：transition to 不在 states 内 → 跨字段核对拒绝
  cat > "$D/neg/n13-transition-to-invalid.yaml" <<'EOF'
workflow:
  name: contract-n13
  description: 负例：transition to 不在 states 内
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: nonexistent_to
      condition: checkpoint.base.step
EOF
  wf_expect_invalid 'N13 transition to 越 states 被拒' '目标状态必须存在于' \
    schema "$D/neg/n13-transition-to-invalid.yaml" "$SCHEMA"

  # N14：state_to_ticket_status 映射目标越票状态枚举 → pattern 拒绝
  cat > "$D/neg/n14-mapping-out-of-enum.yaml" <<'EOF'
workflow:
  name: contract-n14
  description: 负例：映射目标越票状态枚举
inputs:
  sample_input:
    type: string
    required: true
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: base-step
    type: command
    description: 基底步骤
    command: printf base
    checkpoint_field: checkpoint.base.step
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
      terminal: true
  transitions:
    - from: pending
      to: pending
      condition: checkpoint.base.step
  state_to_ticket_status:
    pending: invalid_status
EOF
  wf_expect_invalid 'N14 state_to_ticket_status 映射越票状态枚举被拒' '不匹配 pattern' \
    schema "$D/neg/n14-mapping-out-of-enum.yaml" "$SCHEMA"

  # N17（票 209）：已退役恒假词 verification_failed 越可实现条件词表 → pattern 拒绝
  sed 's/      condition: checkpoint.base.step/      condition: verification_failed/' \
    "$D/neg/base.yaml" > "$D/neg/n17-retired-condition.yaml"
  wf_expect_invalid 'N17 已退役恒假词 verification_failed 越条件词表被拒' '不匹配 pattern' \
    schema "$D/neg/n17-retired-condition.yaml" "$SCHEMA"

  # ---- executor 映射强制运行时正负例（票 221）：私有状态不直写票索引 ----
  # 票索引夹具 mktemp 自建，经 issues_index_rel 指向，不触仓内真实 index.json。

  wf_map_fixture() {
    mkdir -p "$1"
    cat > "$1/index.json" <<EOF
{
  "issues": [
    {
      "id": "wf-map-enforce-test",
      "kind": "task",
      "status": "$2",
      "updated_at": "2026-10-26T00:00:00"
    }
  ]
}
EOF
    cp "$1/index.json" "$1/index.before"
    printf '{"id":"wf-map-enforce-test","kind":"task","title":"WF Map Enforce Test","created_at":"2026-10-26"}\n' > "$1/ticket.json"
  }

  # P15（AC4）：合法映射端到端写入——私有态 working 经映射写 in_progress（非私有状态名直写）
  wf_map_fixture "$D/map/pos" ready
  cat > "$D/map/pos/wf.yaml" <<'EOF'
workflow:
  name: contract-map-pos
  description: 映射强制正例
inputs:
  sample_input:
    type: string
    required: false
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: map-step
    type: command
    description: 映射正例步骤
    command: printf pos
    checkpoint_field: checkpoint.map.pos
state_machine:
  initial_state: ready
  states:
    - name: ready
      description: 初始
    - name: working
      description: 私有工作态
  transitions:
    - from: ready
      to: working
      condition: checkpoint.map.pos
  state_to_ticket_status:
    working: in_progress
EOF
  issues_index_rel="$D/map/pos/index.json" sh "$EXECUTOR" "$D/map/pos/wf.yaml" \
    --ticket-file "$D/map/pos/ticket.json" > "$D/map/pos/run.log" 2>&1
  map_pos_rc=$?
  if [ "$map_pos_rc" -eq 0 ] && python3 - "$D/map/pos" > /dev/null <<'PY'
import json, sys

base = sys.argv[1]
with open(base + '/index.json', encoding='utf-8') as handle:
    issue = next(i for i in json.load(handle)['issues'] if i['id'] == 'wf-map-enforce-test')
assert issue['status'] == 'in_progress', f'状态漂移: {issue["status"]!r}（期望映射值 in_progress）'
assert issue['status'] != 'working', '私有状态名 working 直写票索引'
assert issue['updated_at'] != '2026-10-26T00:00:00', 'updated_at 未随写入更新'
print('map-pos-ok')
PY
  then
    ok 'P15 合法映射端到端写入：ready→working 按映射值写 in_progress（非私有状态名，updated_at 随动）'
  else
    bad 'P15 合法映射端到端写入：ready→working 按映射值写 in_progress（非私有状态名，updated_at 随动）' \
      "exit=$map_pos_rc $(tail -n 3 "$D/map/pos/run.log" | tr '\n' '|')"
  fi

  # N15（AC1/AC3）：私有状态 implementation_done 无映射 → 拒绝转换、票索引零写入（回归负例常驻）
  wf_map_fixture "$D/map/neg-unmapped" in_progress
  cat > "$D/map/neg-unmapped/wf.yaml" <<'EOF'
workflow:
  name: contract-map-unmapped
  description: 映射强制负例：目标状态未映射
inputs:
  sample_input:
    type: string
    required: false
    description: 样例输入
outputs:
  sample_output:
    type: string
    description: 样例输出
steps:
  - id: done-step
    type: command
    description: 未映射负例步骤
    command: printf done
    checkpoint_field: checkpoint.map.done
state_machine:
  initial_state: in_progress
  states:
    - name: in_progress
      description: 进行中
    - name: implementation_done
      description: 私有完成态
  transitions:
    - from: in_progress
      to: implementation_done
      condition: checkpoint.map.done
  state_to_ticket_status:
    in_progress: in_progress
EOF
  issues_index_rel="$D/map/neg-unmapped/index.json" sh "$EXECUTOR" "$D/map/neg-unmapped/wf.yaml" \
    --ticket-file "$D/map/neg-unmapped/ticket.json" > "$D/map/neg-unmapped/run.log" 2>&1
  map_unmapped_rc=$?
  if [ "$map_unmapped_rc" -eq 0 ] \
    && cmp -s "$D/map/neg-unmapped/index.json" "$D/map/neg-unmapped/index.before" \
    && grep -q '未映射不写票索引: implementation_done' "$D/map/neg-unmapped/run.log"; then
    ok 'N15 implementation_done 未映射：转换被拒、票索引 cmp 零差（私有状态不直写，回归负例）'
  else
    bad 'N15 implementation_done 未映射：转换被拒、票索引 cmp 零差（私有状态不直写，回归负例）' \
      "exit=$map_unmapped_rc $(tail -n 3 "$D/map/neg-unmapped/run.log" | tr '\n' '|')"
  fi

  # N16（AC2）：映射目标越票状态枚举 → 拒绝转换、票索引零写入
  wf_map_fixture "$D/map/neg-outofenum" in_progress
  sed 's/    in_progress: in_progress/    implementation_done: implemented/' \
    "$D/map/neg-unmapped/wf.yaml" | sed 's/name: contract-map-unmapped/name: contract-map-outofenum/' \
    > "$D/map/neg-outofenum/wf.yaml"
  issues_index_rel="$D/map/neg-outofenum/index.json" sh "$EXECUTOR" "$D/map/neg-outofenum/wf.yaml" \
    --ticket-file "$D/map/neg-outofenum/ticket.json" > "$D/map/neg-outofenum/run.log" 2>&1
  map_out_rc=$?
  if [ "$map_out_rc" -eq 0 ] \
    && cmp -s "$D/map/neg-outofenum/index.json" "$D/map/neg-outofenum/index.before" \
    && grep -q '映射目标越票状态枚举，拒绝写票索引: implementation_done → implemented' "$D/map/neg-outofenum/run.log"; then
    ok 'N16 映射目标 implemented 越票状态枚举：拒绝写票索引、票索引 cmp 零差'
  else
    bad 'N16 映射目标 implemented 越票状态枚举：拒绝写票索引、票索引 cmp 零差' \
      "exit=$map_out_rc $(tail -n 3 "$D/map/neg-outofenum/run.log" | tr '\n' '|')"
  fi

  # ---- 条件语义结构化运行时正负例（票 209）：词表求值、退役词双层拒绝、
  # ---- AC1 空 checkpoint 不恒真、AC2 失败进 blocked、AC3 retry 门控 ----

  # P16（AC2）：验证失败先落结构化 failed 记录（六键）再进 blocked（端到端）
  mkdir -p "$D/blocked"
  cat > "$D/blocked/wf.yaml" <<'EOF'
workflow:
  name: contract-blocked
  description: 验证失败进入 blocked（票 209 AC2）
steps:
  - id: fail-step
    type: verification
    description: 必失败的验证步骤
    checkpoint_field: checkpoint.blocked.verify
    verification:
      - name: probe
        check: exit 3
        expect: unreachable
state_machine:
  initial_state: in_progress
  states:
    - name: in_progress
      description: 实施中
    - name: blocked
      description: 阻塞
  transitions:
    - from: in_progress
      to: blocked
      condition: any_verification_failed
  state_to_ticket_status:
    blocked: blocked
EOF
  cat > "$D/blocked/index.json" <<'EOF'
{"issues":[{"id":"wf-cond-blocked-test","kind":"task","status":"in_progress","updated_at":"2026-10-26T00:00:00"}]}
EOF
  cp "$D/blocked/index.json" "$D/blocked/index.before"
  printf '{"id":"wf-cond-blocked-test","kind":"task","title":"WF Cond Blocked Test","created_at":"2026-10-26"}\n' > "$D/blocked/ticket.json"
  issues_index_rel="$D/blocked/index.json" sh "$EXECUTOR" "$D/blocked/wf.yaml" \
    --ticket-file "$D/blocked/ticket.json" > "$D/blocked/run.log" 2>&1
  blocked_rc=$?
  if [ "$blocked_rc" -eq 1 ] && python3 - "$D/blocked" > /dev/null <<'PY'
import json, sys

base = sys.argv[1]
with open(base + '/index.json', encoding='utf-8') as handle:
    issue = next(i for i in json.load(handle)['issues'] if i['id'] == 'wf-cond-blocked-test')
assert issue['status'] == 'blocked', f'状态漂移: {issue["status"]!r}（验证失败应进入 blocked）'
with open(base + '/ticket.json.workflow-checkpoint-v1.json', encoding='utf-8') as handle:
    record = json.load(handle)['checkpoint']['blocked']['verify']
assert set(record) == {'step_name', 'completed_at', 'outputs', 'status', 'exit_code', 'verification_results'}, sorted(record)
assert record['status'] == 'failed', record
assert record['exit_code'] == 3, record
assert record['verification_results'] == [{'name': 'probe', 'status': 'failed', 'exit_code': 3}], record
print('blocked-ok')
PY
  then
    ok 'P16 AC2 端到端：验证失败先落六键 failed 记录（exit_code=3＋逐项结果）再进 blocked'
  else
    bad 'P16 AC2 端到端：验证失败先落六键 failed 记录（exit_code=3＋逐项结果）再进 blocked' \
      "exit=$blocked_rc $(tail -n 3 "$D/blocked/run.log" | tr '\n' '|')"
  fi

  # P17：条件求值与词表预检单元正负例（AC1/AC3/AC4 求值语义；退役词预检拒绝）
  if python3 - "$SCRIPT_DIR/json-validator.py" > "$D/cond-unit.log" 2>&1 <<'PY'
import json
import re
import subprocess
import sys

engine = sys.argv[1]


def ev(condition, checkpoint, steps, retry=''):
    proc = subprocess.run(
        [sys.executable, engine, 'workflow', 'eval-condition', condition, checkpoint, steps, retry],
        capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return proc.stdout.strip()


steps = json.dumps([{'id': 'v', 'type': 'verification', 'checkpoint_field': 'checkpoint.a.b'}])
passed = json.dumps({'a': {'b': {'step_name': 'v', 'completed_at': '2026-10-20T00:00:00Z', 'outputs': '',
                                 'status': 'passed', 'exit_code': 0, 'verification_results': []}}})
failed = json.dumps({'a': {'b': {'step_name': 'v', 'completed_at': '2026-10-20T00:00:00Z', 'outputs': '',
                                 'status': 'failed', 'exit_code': 3,
                                 'verification_results': [{'name': 'v', 'status': 'failed', 'exit_code': 3}]}}})
legacy = json.dumps({'a': {'b': {'step_name': 'v', 'completed_at': '2026-10-20T00:00:00Z', 'outputs': ''}}})
commands_only = json.dumps([{'id': 'c', 'type': 'command'}])

# AC1：空 checkpoint／零验证记录不再恒真（回归钉死「checkpoint 串非空即真」）
assert ev('all_verifications_pass', '{}', steps) == 'false'
assert ev('all_verifications_pass', '{}', '[]') == 'false'
assert ev('all_verifications_pass', '{}', commands_only) == 'false'
assert ev('all_verifications_pass', passed, steps) == 'true'
assert ev('all_verifications_pass', legacy, steps) == 'true', 'legacy 缺 status 应按 passed 解释'
assert ev('all_verifications_pass', failed, steps) == 'false'
assert ev('any_verification_failed', failed, steps) == 'true'
assert ev('any_verification_failed', passed, steps) == 'false'
assert ev('any_verification_failed', '{}', steps) == 'false'
# AC3：manual_retry_requested 仅显式 --retry
assert ev('manual_retry_requested', '{}', steps) == 'false'
assert ev('manual_retry_requested', '{}', steps, 'v') == 'true'
# checkpoint.<路径> 正负例
assert ev('checkpoint.a.b', '{}', steps) == 'false'
assert ev('checkpoint.a.b', passed, steps) == 'true'
assert ev('checkpoint.a.b', legacy, steps) == 'true'
assert ev('checkpoint.a.missing', passed, steps) == 'false'

# 词表预检：词表内全过；已退役词与未知词拒绝
good_sm = {'transitions': [{'from': 'a', 'to': 'b', 'condition': c} for c in
                           ['all_verifications_pass', 'any_verification_failed',
                            'manual_retry_requested', 'checkpoint.a.b']]}
proc = subprocess.run([sys.executable, engine, 'workflow', 'check-conditions', json.dumps(good_sm)],
                      capture_output=True, text=True)
assert proc.returncode == 0, proc.stderr
for retired in ('workflow_started', 'verification_failed', 'manual_retry', 'totally_unknown'):
    bad_sm = {'transitions': [{'from': 'a', 'to': 'b', 'condition': retired}]}
    proc = subprocess.run([sys.executable, engine, 'workflow', 'check-conditions', json.dumps(bad_sm)],
                          capture_output=True, text=True)
    assert proc.returncode != 0, retired
    assert '不在可实现条件词表' in proc.stderr, (retired, proc.stderr)
print('cond-unit-ok')
PY
  then
    ok 'P17 条件求值与词表预检单元正负例：AC1 空 checkpoint 不恒真／AC3 retry 门控／词表外拒绝'
  else
    bad 'P17 条件求值与词表预检单元正负例：AC1 空 checkpoint 不恒真／AC3 retry 门控／词表外拒绝' \
      "$(tail -n 4 "$D/cond-unit.log" | tr '\n' '|')"
  fi

  # P18：schema 条件 pattern 与引擎词表（CONDITION_ENUM＋CHECKPOINT_CONDITION_RE）语料级等价
  if python3 - "$SCHEMA" "$SCRIPT_DIR/json-validator.py" > "$D/cond-equiv.log" 2>&1 <<'PY'
import json
import re
import sys

schema_path, engine_path = sys.argv[1], sys.argv[2]
with open(engine_path, encoding='utf-8') as handle:
    source = handle.read()
enum_match = re.search(r"CONDITION_ENUM = \(([^)]*)\)", source)
assert enum_match, '引擎源中未找到 CONDITION_ENUM'
words = set(re.findall(r"'([^']+)'", enum_match.group(1)))
cre_match = re.search(r"CHECKPOINT_CONDITION_RE = re\.compile\(r'([^']+)'\)", source)
assert cre_match, '引擎源中未找到 CHECKPOINT_CONDITION_RE'
checkpoint_re = cre_match.group(1)
with open(schema_path, encoding='utf-8') as handle:
    schema = json.load(handle)
pattern = schema['properties']['state_machine']['properties']['transitions']['items']['properties']['condition']['pattern']
corpus = [
    'all_verifications_pass', 'any_verification_failed', 'manual_retry_requested',
    'workflow_started', 'verification_failed', 'manual_retry',
    'checkpoint.a', 'checkpoint.a.b', 'checkpoint.triage.parse_requirement', 'checkpoint._x',
    'checkpoint', 'checkpoint.', 'checkpoint.a.', 'checkpoint.A', 'checkpoint.1a',
    'checkpoint.a-b', 'checkpoint.a..b', 'checkpoint.a b', 'checkpoint.a/b',
    'ALL_VERIFICATIONS_PASS', 'unknown_condition', '',
]
for candidate in corpus:
    engine_verdict = candidate in words or re.fullmatch(checkpoint_re, candidate) is not None
    schema_verdict = re.fullmatch(pattern, candidate) is not None
    assert engine_verdict == schema_verdict, (candidate, engine_verdict, schema_verdict)
for candidate in ('all_verifications_pass', 'any_verification_failed', 'manual_retry_requested', 'checkpoint.a.b'):
    assert re.fullmatch(pattern, candidate) is not None, candidate
print(f'condition pattern 等价: schema vs engine corpus={len(corpus)}')
PY
  then
    ok 'P18 schema 条件词表 pattern 与引擎词表语料级等价（退役词双侧同拒，漂移护栏）'
  else
    bad 'P18 schema 条件词表 pattern 与引擎词表语料级等价（退役词双侧同拒，漂移护栏）' \
      "$(tail -n 4 "$D/cond-equiv.log" | tr '\n' '|')"
  fi

  # N18：词表外条件（退役恒真词 workflow_started）在 sidecar 落盘与副作用之前拒绝执行
  mkdir -p "$D/condneg"
  cat > "$D/condneg/wf.yaml" <<'EOF'
workflow:
  name: contract-condneg
  description: 退役条件词拒绝夹具（票 209）
steps:
  - id: probe-step
    type: command
    description: 副作用探针
    command: printf ran >> "$WF_CONDNEG_MARK"
    checkpoint_field: checkpoint.condneg.probe
state_machine:
  initial_state: pending
  states:
    - name: pending
      description: 初始
  transitions:
    - from: pending
      to: pending
      condition: workflow_started
EOF
  printf '{"id":"wf-condneg-test","kind":"task","title":"WF Condneg Test","created_at":"2026-10-26"}\n' > "$D/condneg/ticket.json"
  WF_CONDNEG_MARK="$D/condneg/marker" sh "$EXECUTOR" "$D/condneg/wf.yaml" \
    --ticket-file "$D/condneg/ticket.json" > "$D/condneg/run.log" 2>&1
  condneg_rc=$?
  if [ "$condneg_rc" -ne 0 ] \
    && [ ! -e "$D/condneg/marker" ] \
    && [ ! -e "$D/condneg/ticket.json.workflow-checkpoint-v1.json" ] \
    && grep -q '不在可实现条件词表' "$D/condneg/run.log"; then
    ok 'N18 退役条件词 workflow_started：exit 非零且先于副作用——探针未执行、零 sidecar、报文指名词表'
  else
    bad 'N18 退役条件词 workflow_started：exit 非零且先于副作用——探针未执行、零 sidecar、报文指名词表' \
      "exit=$condneg_rc marker=$([ -e "$D/condneg/marker" ] && echo present || echo absent) $(tail -n 3 "$D/condneg/run.log" | tr '\n' '|')"
  fi

  # P19（AC3 正例）：blocked 票经显式 --retry 重试成功 → manual_retry_requested 推进回 in_progress
  mkdir -p "$D/retry/pos"
  cat > "$D/retry/wf.yaml" <<'EOF'
workflow:
  name: contract-retry
  description: manual_retry_requested 仅显式 --retry 生效（票 209 AC3）
steps:
  - id: retry-step
    type: command
    description: 重试目标步骤
    command: printf retried >> "$WF_RETRY_MARK"
    checkpoint_field: checkpoint.retry.step
state_machine:
  initial_state: blocked
  states:
    - name: blocked
      description: 阻塞
    - name: in_progress
      description: 实施中
  transitions:
    - from: blocked
      to: in_progress
      condition: manual_retry_requested
  state_to_ticket_status:
    in_progress: in_progress
EOF
  cat > "$D/retry/pos/index.json" <<'EOF'
{"issues":[{"id":"wf-cond-retry-test","kind":"task","status":"blocked","updated_at":"2026-10-26T00:00:00"}]}
EOF
  printf '{"id":"wf-cond-retry-test","kind":"task","title":"WF Cond Retry Test","created_at":"2026-10-26","checkpoint_ref":"workflow-checkpoint-v1:ticket.json.workflow-checkpoint-v1.json"}\n' > "$D/retry/pos/ticket.json"
  cat > "$D/retry/pos/ticket.json.workflow-checkpoint-v1.json" <<'EOF'
{"version":1,"checkpoint":{"retry":{"step":{"step_name":"retry-step","completed_at":"2026-10-20T00:00:00Z","outputs":"","status":"failed","exit_code":1,"verification_results":[]}}}}
EOF
  WF_RETRY_MARK="$D/retry/pos/marker" issues_index_rel="$D/retry/pos/index.json" \
    sh "$EXECUTOR" "$D/retry/wf.yaml" --ticket-file "$D/retry/pos/ticket.json" \
    --retry retry-step > "$D/retry/pos/run.log" 2>&1
  retry_pos_rc=$?
  if [ "$retry_pos_rc" -eq 0 ] && python3 - "$D/retry/pos" > /dev/null <<'PY'
import json, sys

base = sys.argv[1]
with open(base + '/index.json', encoding='utf-8') as handle:
    issue = next(i for i in json.load(handle)['issues'] if i['id'] == 'wf-cond-retry-test')
assert issue['status'] == 'in_progress', f'状态漂移: {issue["status"]!r}（显式 retry 应推进 blocked→in_progress）'
with open(base + '/ticket.json.workflow-checkpoint-v1.json', encoding='utf-8') as handle:
    record = json.load(handle)['checkpoint']['retry']['step']
assert record['status'] == 'passed', record
assert record['exit_code'] == 0, record
print('retry-pos-ok')
PY
  then
    ok 'P19 AC3 正例：显式 --retry 重试成功后 manual_retry_requested 推进 blocked→in_progress（旧 failed 记录被清除重写为 passed）'
  else
    bad 'P19 AC3 正例：显式 --retry 重试成功后 manual_retry_requested 推进 blocked→in_progress（旧 failed 记录被清除重写为 passed）' \
      "exit=$retry_pos_rc $(tail -n 3 "$D/retry/pos/run.log" | tr '\n' '|')"
  fi

  # N19（AC3 负例）：同一 workflow 无 --retry 正常执行 → manual_retry_requested 为假、票索引零写入
  mkdir -p "$D/retry/neg"
  cat > "$D/retry/neg/index.json" <<'EOF'
{"issues":[{"id":"wf-cond-retry-test","kind":"task","status":"blocked","updated_at":"2026-10-26T00:00:00"}]}
EOF
  cp "$D/retry/neg/index.json" "$D/retry/neg/index.before"
  printf '{"id":"wf-cond-retry-test","kind":"task","title":"WF Cond Retry Test","created_at":"2026-10-26"}\n' > "$D/retry/neg/ticket.json"
  WF_RETRY_MARK="$D/retry/neg/marker" issues_index_rel="$D/retry/neg/index.json" \
    sh "$EXECUTOR" "$D/retry/wf.yaml" --ticket-file "$D/retry/neg/ticket.json" > "$D/retry/neg/run.log" 2>&1
  retry_neg_rc=$?
  if [ "$retry_neg_rc" -eq 0 ] \
    && [ "$(cat "$D/retry/neg/marker")" = "retried" ] \
    && cmp -s "$D/retry/neg/index.json" "$D/retry/neg/index.before" \
    && grep -q '无可用状态转换' "$D/retry/neg/run.log"; then
    ok 'N19 AC3 负例：无 --retry 时 manual_retry_requested 为假——步骤照跑、票索引 cmp 零差（blocked 不被穿越）'
  else
    bad 'N19 AC3 负例：无 --retry 时 manual_retry_requested 为假——步骤照跑、票索引 cmp 零差（blocked 不被穿越）' \
      "exit=$retry_neg_rc $(tail -n 3 "$D/retry/neg/run.log" | tr '\n' '|')"
  fi

  suite_summary 'workflow-contract'
}
