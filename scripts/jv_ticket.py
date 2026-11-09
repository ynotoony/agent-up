"""json-validator.py ticket 族：票本体 schema 解释器（票 290 拆分；非独立入口）.

含 --new-ticket 开票门（kind 枚举收窄＋七维 profile reason 强制），语义归 ticket-ops open。
"""
import re
import sys

# 本模块由 json-validator.py（薄 CLI）在同进程内 import；共享严格 JSON 加载
# （StrictJSONError／_strict_load／_load_json_file）留在入口模块，本模块经
# from __main__ import 复用同一实现，不复制第二份解析器。

from __main__ import _load_json_file


def validate_ticket(schema_path, ticket_path, new_ticket=False):
    """Validate ticket JSON against schema.

    Args:
        schema_path: Path to ticket-record.schema.json
        ticket_path: Path to ticket JSON file

    Returns:
        0 on success, 1 on validation failure
    """
    def _load_fail(exc):
        print(f"ticket-validate: FAIL: 无法读取文件: {exc}", file=sys.stderr)

    # schema 为受信规则数据件，按 json.load 既有语义读取（其文档面允许重复键：
    # expect_exit 在 verification oneOf 两分支各出现一次，严格键检会误判 schema 非法）；
    # 票本体是输入面，改走 _strict_load（拒绝 NaN/Infinity/-Infinity 与重复键）。
    schema = _load_json_file(schema_path, _load_fail)
    if schema is None:
        return 1
    body = _load_json_file(ticket_path, _load_fail, strict=True)
    if body is None:
        return 1

    errs = []

    def schema_string_valid(value, rules):
        if not isinstance(value, str):
            return False
        min_length = rules.get('minLength')
        if min_length is not None and len(value) < min_length:
            return False
        pattern = rules.get('pattern')
        return pattern is None or re.search(pattern, value) is not None

    # Type checks
    if not isinstance(body, dict):
        errs.append('根对象不是 object')
        print('ticket-validate: FAIL: JSON 不合 schema:', file=sys.stderr)
        for e in errs:
            print(f'  - {e}', file=sys.stderr)
        return 1

    # Required fields
    for req in schema.get('required', []):
        if req not in body:
            errs.append(f'缺必填字段: {req}')

    # additionalProperties: false
    if schema.get('additionalProperties') is False:
        allowed = set(schema.get('properties', {}).keys())
        for k in body.keys():
            if k not in allowed and k != 'x-sample':
                errs.append(f'额外字段（schema 禁）: {k}')

    # Properties validation
    props = schema.get('properties', {})

    if 'scope' in body and 'scope' in props:
        scope = body['scope']
        if not isinstance(scope, list):
            errs.append('scope 不是数组')
        else:
            item_rules = props['scope'].get('items', {})
            for i, item in enumerate(scope):
                if not schema_string_valid(item, item_rules):
                    errs.append(f'scope[{i}] 必须是非空字符串')

    # kind enum
    if 'kind' in body and 'kind' in props:
        enum = props['kind'].get('enum', [])
        if enum and body['kind'] not in enum:
            errs.append(f"kind 不在枚举: {body['kind']!r}")
        # new-ticket gate: reject kind=request (retired 2026-10-23)
        if new_ticket and body['kind'] == 'request':
            errs.append(
                "kind=request 已退役（2026-10-23）：新需求一律走任务票（task），"
                "不再创建 request（REQ）；存量 REQ 冻结只读"
            )

    # id pattern
    if 'id' in body and 'id' in props:
        pat = props['id'].get('pattern')
        if pat and not re.fullmatch(pat, body['id']):
            errs.append(f"id 不合 pattern: {body['id']!r}")
        # new-ticket gate: reject REQ-* format (retired 2026-10-23)
        if new_ticket and body['id'].startswith('REQ-'):
            errs.append(
                "REQ-* 格式 id 已退役（2026-10-23）：新需求一律走任务票 <NN>-<slug> 格式；"
                "存量 REQ 冻结只读"
            )

    # complexity enum
    if 'complexity' in body and 'complexity' in props:
        enum = props['complexity'].get('enum', [])
        if enum and body['complexity'] not in enum:
            errs.append(f"complexity 不在枚举: {body['complexity']!r}")

    # profile pattern
    if 'profile' in body and 'profile' in props:
        pat = props['profile'].get('pattern')
        if pat and not re.fullmatch(pat, body['profile']):
            errs.append(f"profile 不合 pattern: {body['profile']!r}")

    # profile_reason shape (storage contract: exactly the seven dimension keys
    # D/B/I/U/S/M/O, each a non-blank string; per-state reason semantics live in
    # references/protocol/complexity-profile.md).  Shape is enforced whenever the
    # field is present (read and open paths alike); presence for new task tickets
    # is enforced further down, gated on new_ticket (legacy tickets have no such
    # field and stay readable — open-time gate vs read-time shape, layered).
    if 'profile_reason' in body and 'profile_reason' in props:
        pr = body['profile_reason']
        pr_rules = props['profile_reason']
        pr_props = pr_rules.get('properties', {})
        if not isinstance(pr, dict):
            errs.append('profile_reason 必须是对象（七维 reason 存储形态：恰七键 D/B/I/U/S/M/O，值＝非空字符串）')
        else:
            for key in pr_rules.get('required', []):
                if key not in pr:
                    errs.append(f'profile_reason 缺维度键: {key}')
            for key in pr:
                if key not in pr_props:
                    errs.append(f'profile_reason 含未知维度键（七维＝D/B/I/U/S/M/O）: {key}')
                elif not schema_string_valid(pr[key], pr_props.get(key, {})):
                    errs.append(f'profile_reason.{key} 必须是非空字符串')

    # user_stories gate (2026-11-04): 新 task 票开票时点必须带至少一条格式合规
    # 的用户故事。presence 只在开票路径（--new-ticket）要求；读取面不要求本字段——
    # 存量票（从未携带）零回扫照常可读（开票校验与读取校验分层，同 profile_reason）。
    # 注意：本字段刻意不进 schema 的 allOf then.required（该清单由本校验器读取面
    # 一并执行，加入会使存量 task 票读取即拒）；开票必备语义由本 new_ticket 门承载。
    if new_ticket and body.get('kind') == 'task' and 'user_stories' not in body:
        errs.append(
            '新 task 票必须提供 user_stories（用户故事数组，至少一条，条目格式 '
            'US<n>: 作为<角色>，我要<功能>，以便<收益>；schema 见 ticket-record.schema.json '
            'user_stories 属性）；存量票读取面不要求本字段'
        )

    # 条目格式单源＝schema user_stories 属性（数组 minItems 1、items pattern
    # ^US<n>: 作为…，我要…，以便…$），本门按 schema 现场执行其在用约束词子集。
    if new_ticket and body.get('kind') == 'task' and 'user_stories' in body:
        us = body['user_stories']
        us_item_rules = props.get('user_stories', {}).get('items', {})
        if not isinstance(us, list):
            errs.append('user_stories 必须是数组（每条＝一个用户故事字符串）')
        elif not us:
            errs.append('user_stories 不能为空数组（kind=task 至少一条用户故事）')
        else:
            for i, item in enumerate(us):
                if not schema_string_valid(item, us_item_rules):
                    errs.append(
                        f'user_stories[{i}] 不合格式（须为 US<n>: 作为<角色>，我要<功能>，以便<收益>）: {item!r}'
                    )

    # blocked_by array items pattern
    if 'blocked_by' in body and 'blocked_by' in props:
        if not isinstance(body['blocked_by'], list):
            errs.append('blocked_by 不是数组')
        else:
            items_schema = props['blocked_by'].get('items', {})
            item_pat = items_schema.get('pattern')
            if item_pat:
                for i, item in enumerate(body['blocked_by']):
                    if not isinstance(item, str) or not re.fullmatch(item_pat, item):
                        errs.append(f"blocked_by[{i}] 不合 pattern: {item!r}")

    # Preserve historical ticket forms. Scope/predicate parity is checked on
    # new-ticket creation only, so reading an existing ticket remains stable.
    if new_ticket and body.get('kind') == 'task' and 'record_only' not in body:
        ver = body.get('verification')
        if not isinstance(ver, list) or not ver or not all(isinstance(item, dict) for item in ver):
            errs.append('新 task 票必须提供非空对象数组 verification；纯记录须使用 record_only.reason + verification="N/A"')

    # Seven-dimension profile reason is mandatory for new task tickets at open
    # time (fail-closed); existing tickets never carried this field and are not
    # rescanned — the read path only checks its shape when present (see above).
    if new_ticket and body.get('kind') == 'task' and 'profile_reason' not in body:
        errs.append(
            '新 task 票必须提供 profile_reason（七维逐维 reason 对象：键＝D/B/I/U/S/M/O，'
            '每键非空字符串，存储合同见 ticket-record.schema.json profile_reason 属性与 '
            'references/protocol/complexity-profile.md §2.2）；存量票读取面不要求本字段'
        )

    if 'verification' in body and 'verification' in props:
        ver = body['verification']
        one_of = props['verification'].get('oneOf', [])
        legacy_item_rules = next((
            branch.get('items', {}) for branch in one_of
            if branch.get('type') == 'array' and branch.get('items', {}).get('type') == 'string'
        ), {})
        structured_item_rules = next((
            branch.get('items', {}) for branch in one_of
            if branch.get('type') == 'array' and branch.get('items', {}).get('type') == 'object'
        ), {})
        structured_fields = structured_item_rules.get('properties', {})
        if one_of:
            matched = False
            # Check if matches any of the oneOf schemas
            if isinstance(ver, str):
                matched = any(s.get('type') == 'string' for s in one_of)
            elif isinstance(ver, list):
                matched = any(s.get('type') == 'array' for s in one_of)
            if not matched:
                errs.append('verification 不匹配任何 oneOf schema（须为字符串或数组）')

        if isinstance(ver, list):
            if not ver:
                errs.append('verification 数组不能为空（普通任务至少需要一条谓词）')
            elif all(isinstance(item, str) for item in ver):
                pass
            elif all(isinstance(item, dict) for item in ver):
                pass
            else:
                errs.append('verification 数组不得混用字符串与对象形态')
            scope = body.get('scope')
            if new_ticket and body.get('kind') == 'task' and ver and all(isinstance(item, dict) for item in ver):
                if not isinstance(scope, list):
                    errs.append('结构化 verification 新票必须提供 scope 数组')
                else:
                    if any(not isinstance(item, str) or not item.strip() for item in scope):
                        errs.append('结构化 verification 新票的 scope 每项必须是非空字符串')
                    if len(ver) != len(scope):
                        errs.append(
                            f'verification 与 scope 条目数不一致: verification={len(ver)}, scope={len(scope)}'
                        )
            for i, predicate in enumerate(ver):
                if isinstance(predicate, str):
                    if not schema_string_valid(predicate, legacy_item_rules):
                        errs.append(f'verification[{i}] 不能为空字符串')
                    continue
                if not isinstance(predicate, dict):
                    errs.append(f'verification[{i}] 必须是非空字符串或对象')
                    continue
                allowed_predicate = {'name', 'description', 'check', 'expect', 'expect_exit', 'fail_msg'}
                for field in predicate:
                    if field not in allowed_predicate:
                        errs.append(f'verification[{i}] 含未定义字段: {field}')
                required = ('name', 'check')
                for field in required:
                    value = predicate.get(field)
                    if not schema_string_valid(value, structured_fields.get(field, {})):
                        errs.append(f'verification[{i}].{field} 必须是非空字符串')
                has_expect = 'expect' in predicate
                has_expect_exit = 'expect_exit' in predicate
                if has_expect == has_expect_exit:
                    errs.append(f'verification[{i}] 必须且只能提供 expect 或 expect_exit 之一')
                if has_expect and not schema_string_valid(predicate['expect'], structured_fields.get('expect', {})):
                    errs.append(f'verification[{i}].expect 必须是非空字符串')
                if has_expect_exit and (not isinstance(predicate['expect_exit'], int) or isinstance(predicate['expect_exit'], bool) or predicate['expect_exit'] < 0):
                    errs.append(f'verification[{i}].expect_exit 必须是非负整数')
                for field in ('description', 'fail_msg'):
                    if field in predicate and not isinstance(predicate[field], str):
                        errs.append(f'verification[{i}].{field} 必须是字符串')

    # Pure record work must opt into the exception explicitly.  This keeps
    # historical tickets readable while preventing new empty-verification
    # records from silently passing a delivery gate.
    if 'record_only' in body:
        record_only = body['record_only']
        if not isinstance(record_only, dict):
            errs.append('record_only 必须是对象')
        elif set(record_only) != {'reason'}:
            errs.append('record_only 仅允许 reason 字段')
        elif not schema_string_valid(record_only.get('reason'), props['record_only']['properties']['reason']):
            errs.append('record_only.reason 必须是非空字符串')
        if body.get('verification') != 'N/A':
            errs.append('record_only 仅允许与 verification="N/A" 配套')
    elif body.get('verification') == 'N/A':
        errs.append('verification="N/A" 必须同时声明 record_only.reason')

    # allOf conditional required (kind=task requires additional fields)
    if 'kind' in body and body['kind'] == 'task':
        all_of = schema.get('allOf', [])
        for rule in all_of:
            if_clause = rule.get('if', {})
            if_props = if_clause.get('properties', {})
            if_kind = if_props.get('kind', {})
            if if_kind.get('const') == 'task':
                then_clause = rule.get('then', {})
                then_required = then_clause.get('required', [])
                for req in then_required:
                    if req not in body:
                        errs.append(f'kind=task 要求字段: {req}')

    if errs:
        print('ticket-validate: FAIL: JSON 不合 schema:', file=sys.stderr)
        for e in errs:
            print(f'  - {e}', file=sys.stderr)
        return 1

    return 0
