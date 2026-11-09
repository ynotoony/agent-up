"""json-validator.py json 族：通用 JSON 操作面（票 290 拆分；非独立入口）.

get/type/fields/len/pick/count-key/rows/set 的单点实现：rows 供 check-stale-claims 行式
消费索引条目；set 为记录层字段级改写序列化面（纯函数，原子替换归 record-store.sh）。
"""
import json
import re
import sys

# 本模块由 json-validator.py（薄 CLI）在同进程内 import；共享严格 JSON 加载
# （StrictJSONError／_strict_load／_load_json_file）留在入口模块，本模块经
# from __main__ import 复用同一实现，不复制第二份解析器。

from __main__ import StrictJSONError, _strict_load


_MISSING = object()


def _load_json(src, what='JSON'):
    """Load JSON from a file path or '-' (stdin). Non-standard JSON
    (NaN/Infinity/-Infinity literals, duplicate keys) exits 2; other read or
    parse failures exit 1."""
    try:
        if src == '-':
            return _strict_load(sys.stdin)
        with open(src, 'r', encoding='utf-8') as f:
            return _strict_load(f)
    except StrictJSONError as e:
        print(f'json-validator: FAIL: {what} 不合法: {src}（{e}）', file=sys.stderr)
        sys.exit(2)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f'json-validator: FAIL: 无法读取或解析{what}: {src}（{e}）', file=sys.stderr)
        sys.exit(1)


def _navigate(root, path):
    """Navigate a dotted path; segments index dicts by key and lists by
    non-negative decimal index. Returns _MISSING when the path does not exist."""
    data = root
    if path == '' or path is None:
        return data
    for part in path.split('.'):
        if isinstance(data, dict):
            if part not in data:
                return _MISSING
            data = data[part]
        elif isinstance(data, list):
            if not re.fullmatch(r'[0-9]+', part):
                return _MISSING
            idx = int(part)
            if idx >= len(data):
                return _MISSING
            data = data[idx]
        else:
            return _MISSING
    return data


def _print_value(value):
    """Print a scalar raw (strings unquoted) and containers as compact JSON."""
    if isinstance(value, str):
        print(value)
    elif value is True:
        print('true')
    elif value is False:
        print('false')
    elif value is None:
        print('null')
    elif isinstance(value, (dict, list)):
        print(json.dumps(value, ensure_ascii=False))
    else:
        print(value)


def _parse_scalar(raw):
    """Parse a shell-provided literal as JSON; fall back to a raw string."""
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        return raw


def json_get(args):
    """json get <src> <path> [default]
    Print the value at a dotted path. Strings print raw, containers as compact
    JSON. Missing path exits 3, unless a default literal is provided."""
    if len(args) not in (2, 3):
        print('用法: json-validator.py json get <src|-> <path> [default]', file=sys.stderr)
        sys.exit(2)
    src, path = args[0], args[1]
    data = _load_json(src)
    value = _navigate(data, path)
    if value is _MISSING:
        if len(args) == 3:
            _print_value(_parse_scalar(args[2]))
            return 0
        print(f'json-validator: FAIL: 路径不存在: {path}', file=sys.stderr)
        return 3
    _print_value(value)
    return 0


def json_fields(args):
    """json fields <src|-> <field> [<field> ...]
    Print top-level fields of an object joined by TAB on one line (missing
    fields as empty cells). Data face must not contain TAB characters."""
    if len(args) < 2:
        print('用法: json-validator.py json fields <src|-> <field> [<field> ...]', file=sys.stderr)
        sys.exit(2)
    src = args[0]
    data = _load_json(src)
    if not isinstance(data, dict):
        print(f'json-validator: FAIL: fields 要求顶层为对象: {src}', file=sys.stderr)
        return 2
    cells = []
    for field in args[1:]:
        value = data.get(field)
        if value is None:
            cells.append('')
        elif isinstance(value, str):
            cells.append(value)
        elif isinstance(value, (dict, list)):
            cells.append(json.dumps(value, ensure_ascii=False))
        elif value is True:
            cells.append('true')
        elif value is False:
            cells.append('false')
        else:
            cells.append(str(value))
    print('\t'.join(cells))
    return 0


def json_len(args):
    """json len <src|-> <path> [default]
    Print the length of the string/array/object at a dotted path. Missing path
    or non-lengthable value exits 3, unless a default number is provided."""
    if len(args) not in (2, 3):
        print('用法: json-validator.py json len <src|-> <path> [default]', file=sys.stderr)
        sys.exit(2)
    src, path = args[0], args[1]
    data = _load_json(src)
    value = _navigate(data, path)
    if value is _MISSING or not isinstance(value, (str, list, dict)):
        if len(args) == 3:
            print(args[2])
            return 0
        print(f'json-validator: FAIL: 路径不存在或不可取长度: {path}', file=sys.stderr)
        return 3
    print(len(value))
    return 0


def json_type(args):
    """json type <src|-> <path>
    Print the JSON type of the value at a dotted path (null/boolean/number/
    string/array/object). Missing path exits 3."""
    if len(args) != 2:
        print('用法: json-validator.py json type <src|-> <path>', file=sys.stderr)
        sys.exit(2)
    src, path = args[0], args[1]
    data = _load_json(src)
    value = _navigate(data, path)
    if value is _MISSING:
        print(f'json-validator: FAIL: 路径不存在: {path}', file=sys.stderr)
        return 3
    if value is None:
        print('null')
    elif isinstance(value, bool):
        print('boolean')
    elif isinstance(value, (int, float)):
        print('number')
    elif isinstance(value, str):
        print('string')
    elif isinstance(value, list):
        print('array')
    else:
        print('object')
    return 0


def json_pick(args):
    """json pick <src|-> <array_path> <k1> <v1> [... <kN> <vN>] [field]
    Print the first array element matching ALL key/value pairs (values compared
    as JSON value or string form). With a trailing odd argument, print only that
    field. No match exits 3."""
    if len(args) < 4:
        print('用法: json-validator.py json pick <src|-> <array_path> <k> <v> [...] [field]', file=sys.stderr)
        sys.exit(2)
    src, array_path = args[0], args[1]
    rest = args[2:]
    if len(rest) % 2 == 1:
        field = rest[-1]
        pairs = rest[:-1]
    else:
        field = None
        pairs = rest
    data = _load_json(src)
    arr = _navigate(data, array_path)
    if arr is _MISSING or not isinstance(arr, list):
        print(f'json-validator: FAIL: 数组路径不存在或非数组: {array_path}', file=sys.stderr)
        return 3
    for element in arr:
        if not isinstance(element, dict):
            continue
        matched = True
        for i in range(0, len(pairs), 2):
            key, want = pairs[i], pairs[i + 1]
            have = element.get(key)
            if have != want and str(have) != want:
                matched = False
                break
        if not matched:
            continue
        if field is None:
            _print_value(element)
            return 0
        value = element.get(field)
        if field not in element:
            print(f'json-validator: FAIL: 命中元素缺字段: {field}', file=sys.stderr)
            return 3
        _print_value(value)
        return 0
    return 3


def json_count_key(args):
    """json count-key <src|-> <key>
    Count occurrences of a key in nested objects (recursive)."""
    if len(args) != 2:
        print('用法: json-validator.py json count-key <src|-> <key>', file=sys.stderr)
        sys.exit(2)
    data = _load_json(args[0])
    key = args[1]
    count = 0

    def visit(node):
        nonlocal count
        if isinstance(node, dict):
            if key in node:
                count += 1
            for value in node.values():
                visit(value)
        elif isinstance(node, list):
            for value in node:
                visit(value)

    visit(data)
    print(count)
    return 0


def json_rows(args):
    """json rows <src|-> <array_path> <field> [<field> ...]
    Print one TAB-separated line per array element with the given top-level
    fields (missing field = empty cell; strings raw, booleans/numbers raw,
    null empty, containers compact JSON). <array_path> may be '' for the
    document root array. Exit 0 done; 2 usage; 3 path missing; 1 unreadable,
    non-standard JSON, value not an array, or element not an object."""
    if len(args) < 3:
        print('用法: json-validator.py json rows <src|-> <array_path> <field> [<field> ...]', file=sys.stderr)
        sys.exit(2)
    src, path, fields = args[0], args[1], args[2:]
    data = _load_json(src)
    value = data if path == '' else _navigate(data, path)
    if value is _MISSING:
        print(f'json-validator: FAIL: 路径不存在: {path}', file=sys.stderr)
        return 3
    if not isinstance(value, list):
        print(f'json-validator: FAIL: json rows 要求路径指向数组: {path or "（根）"}', file=sys.stderr)
        return 1
    for idx, element in enumerate(value):
        if not isinstance(element, dict):
            print(f'json-validator: FAIL: json rows 第 {idx} 个元素不是对象', file=sys.stderr)
            return 1
        cells = []
        for field in fields:
            item = element.get(field)
            if item is None:
                cells.append('')
            elif isinstance(item, str):
                cells.append(item)
            elif item is True:
                cells.append('true')
            elif item is False:
                cells.append('false')
            elif isinstance(item, (dict, list)):
                cells.append(json.dumps(item, ensure_ascii=False))
            else:
                cells.append(str(item))
        print('\t'.join(cells))
    return 0


def json_set(args):
    """json set <src|-> <dotted.path> <json-value>
    Print the document with <json-value> (parsed as JSON) set at the dotted
    path; missing or non-object intermediate segments are replaced by empty
    objects (last segment is created/overwritten). Serialization is the
    record-layer canonical form: ensure_ascii=False, indent=2, trailing
    newline. Pure function: no file is written, callers own the atomic
    replace (record-store.sh record_set_json). Exits 0 on success, 2 on
    usage / invalid value / non-standard JSON, 1 on unreadable source."""
    if len(args) != 3:
        print('用法: json-validator.py json set <src|-> <dotted.path> <json-value>', file=sys.stderr)
        sys.exit(2)
    src, path, raw = args[0], args[1], args[2]
    try:
        value = json.loads(raw)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f'json-validator: FAIL: json set 值不合 JSON: {raw}（{exc}）', file=sys.stderr)
        sys.exit(2)
    parts = [part for part in path.split('.') if part != '']
    if not parts:
        print('用法: json-validator.py json set <src|-> <dotted.path> <json-value>', file=sys.stderr)
        sys.exit(2)
    data = _load_json(src)
    node = data
    if not isinstance(node, dict):
        print(f'json-validator: FAIL: json set 要求顶层为对象: {src}', file=sys.stderr)
        return 2
    for part in parts[:-1]:
        child = node.get(part)
        if not isinstance(child, dict):
            child = {}
            node[part] = child
        node = child
    node[parts[-1]] = value
    sys.stdout.write(json.dumps(data, ensure_ascii=False, indent=2))
    sys.stdout.write('\n')
    return 0
