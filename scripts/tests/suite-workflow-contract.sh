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
# pattern 与 workflow-executor.sh 运行时正则做语料级等价核对；executor 写面
# 记录与文档三键语义逐键一致且 --resume 回读接受；unsupported-step 负例在
# checkpoint sidecar 落盘与任何步骤副作用之前失败。夹具全 mktemp 自建不入
# 仓，被测对象只读；YAML 解析为夹具专用极简块级解析器（映射/序列/纯量/引号
# 纯量，不支持锚点、流集合与多行块标量），校验关键字覆盖 workflow.schema.json
# 在用全集：type/required/properties/patternProperties/additionalProperties/
# pattern/enum/const/minLength/minItems/minimum/maximum/items/oneOf）
# ============================================================

# 夹具校验器（生成到 mktemp 目录，不入包）。模式：
#   schema <workflow.yaml> <schema.json>   实例校验，违例行打印并 exit 1
#   classify <workflow.yaml>               按 executor 支持子集输出逐步骤分类 JSON
#   sidecar <sidecar.json> <workflow.yaml> sidecar 合同校验＋与实例 checkpoint_field 交叉核对
#   pattern-equiv <schema.json> <executor.sh>  checkpoint_field pattern 与运行时正则语料等价
wf_emit_validator() {
  cat > "$1" <<'WFPY'
import json
import re
import sys
from datetime import datetime

TS_RE = re.compile(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')
RECORD_KEYS = {'step_name', 'completed_at', 'outputs'}


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
        extra = keys - RECORD_KEYS
        if extra:
            errors.append(f'{path}: 记录含未定义键 {sorted(extra)}')
        if not isinstance(node.get('step_name'), str) or not node['step_name']:
            errors.append(f'{path}: step_name 必须为非空字符串')
        if not valid_timestamp(node.get('completed_at')):
            errors.append(f'{path}: completed_at 必须为合法 UTC 时刻（YYYY-MM-DDTHH:MM:SSZ）')
        if not isinstance(node.get('outputs'), str):
            errors.append(f'{path}: outputs 必须为字符串')
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


def main(argv):
    if not argv:
        print('用法: wfvalidate.py schema|classify|sidecar|pattern-equiv ...', file=sys.stderr)
        return 2
    mode = argv[0]
    if mode == 'schema':
        with open(argv[2], encoding='utf-8') as handle:
            schema = json.load(handle)
        with open(argv[1], encoding='utf-8') as handle:
            document = yaml_load(handle.read())
        errors = []
        validate(schema, document, '$', errors)
        for line in errors:
            print(line)
        return 1 if errors else 0
    if mode == 'classify':
        classify(argv[1])
        return 0
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
  WF_DIR="$PKG_ROOT/references/workflows"

  if [ ! -f "$EXECUTOR" ] || [ ! -f "$SCHEMA" ] || [ ! -f "$WF_DIR/triage.yaml" ] || [ ! -f "$WF_DIR/implementation.yaml" ]; then
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
      condition: workflow_started
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
      condition: workflow_started
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
      condition: workflow_started
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
      condition: workflow_started
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
    pattern-equiv "$SCHEMA" "$EXECUTOR"

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
      condition: manual_retry
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

  # ---- executor 写面：记录恰三键且与文档语义逐键一致 ----

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
      condition: manual_retry
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
if set(record) != {'step_name', 'completed_at', 'outputs'}:
    sys.exit(f'记录键漂移: {sorted(record)}')
if record['step_name'] != 'write-step':
    sys.exit(f'step_name 漂移: {record["step_name"]!r}')
completed_at = record['completed_at']
if not isinstance(completed_at, str) or re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', completed_at) is None:
    sys.exit(f'completed_at 格式漂移: {completed_at!r}')
datetime.strptime(completed_at, '%Y-%m-%dT%H:%M:%SZ')
if record['outputs'] != '':
    sys.exit(f'outputs 漂移: {record["outputs"]!r}')
print('record-ok')
PY
  then
    ok 'P7 executor 写面记录恰三键且逐键语义一致（step_name/completed_at UTC/outputs）'
  else
    bad 'P7 executor 写面记录恰三键且逐键语义一致（step_name/completed_at UTC/outputs）' \
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
      condition: manual_retry
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

  suite_summary 'workflow-contract'
}
