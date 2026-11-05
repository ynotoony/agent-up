#!/usr/bin/env python3
"""JSON engine for agent-up scripts (票 227 F3：脚本层唯一 JSON 引擎).

Entry points:
- ticket: Validate ticket JSON against schema
- grade: Grade ticket complexity
- run: Validate/seal run records and compute stats
- json: Generic JSON operations (get/type/fields/len/pick/count-key) for the shell
  script layer — the single JSON engine replacing embedded python heredocs and
  awk JSON parsing
- workflow: workflow-executor.sh JSON operations (steps/state-machine parsing,
  preflight, index status, checkpoint sidecar lifecycle, state_to_ticket_status
  mapping enforcement (票 221), condition vocabulary check/evaluation over
  structured step results (票 209))
- ticket-check: ticket-ops.sh gates (close/deps/open-body)
- contract: dispatch-contract TICKET_ID extraction (worktree-add.sh)

Exit codes:
  0 = operation completed
  1 = validation failed or invalid input (3 = path/element miss for json ops)
  2 = usage error, missing dependencies, or non-standard JSON document in json ops
      (NaN/Infinity/-Infinity literals, duplicate keys in one object)
"""

import sys
import os
import json
import re
import tempfile
from datetime import datetime
from collections import defaultdict


class StrictJSONError(json.JSONDecodeError):
    """非标准 JSON：NaN/Infinity/-Infinity 字面量或同一对象内重复键。

    继承 JSONDecodeError，既有调用方的 except json.JSONDecodeError 分支照常把它
    判为非法 JSON；json 通用操作面把它映射为 exit 2。
    """

    def __init__(self, message):
        super().__init__(message, '', 0)


def _reject_json_constant(name):
    raise StrictJSONError(f'非标准 JSON 字面量: {name}')


def _reject_duplicate_keys(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise StrictJSONError(f'同一对象内重复键: {key}')
        obj[key] = value
    return obj


def _strict_load(fp):
    """json.load 的严格形态：拒绝 NaN/Infinity/-Infinity 与重复键。"""
    return json.load(fp, parse_constant=_reject_json_constant,
                     object_pairs_hook=_reject_duplicate_keys)


# ============================================================
# Ticket validation (extracted from ticket-ops.sh)
# ============================================================

def validate_ticket(schema_path, ticket_path, new_ticket=False):
    """Validate ticket JSON against schema.

    Args:
        schema_path: Path to ticket-record.schema.json
        ticket_path: Path to ticket JSON file

    Returns:
        0 on success, 1 on validation failure
    """
    try:
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f)
        with open(ticket_path, 'r', encoding='utf-8') as f:
            body = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        print(f"ticket-validate: FAIL: 无法读取文件: {e}", file=sys.stderr)
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


# ============================================================
# Ticket grading (extracted from ticket-grade.sh)
# ============================================================

def grade_ticket(ticket_path, profile_path):
    """Grade ticket complexity based on criteria.

    Args:
        ticket_path: Path to ticket JSON file
        profile_path: Path to complexity-profile.md

    Returns:
        Tuple of (ticket_id, alignment_status, suggested_grade)
    """
    try:
        with open(ticket_path, 'r', encoding='utf-8') as f:
            ticket = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        print(f"ticket-grade: FAIL: 无法读取票: {e}", file=sys.stderr)
        sys.exit(1)

    tid = ticket.get('id', 'unknown')
    actual = ticket.get('complexity', 'N/A')

    # Simplified grading logic (extracted from ticket-grade.sh)
    # Counts various complexity indicators
    hits = {'c3': [], 'c2': [], 'c1': [], 'c0': []}

    # C3 triggers (example: 架构变更、协议设计等)
    scope = ticket.get('scope', [])
    forbidden = ticket.get('forbidden', [])
    risks = ticket.get('risks', [])

    scope_text = ' '.join(scope) if isinstance(scope, list) else str(scope)
    forbidden_text = ' '.join(forbidden) if isinstance(forbidden, list) else str(forbidden)

    # C3: 多层协议、架构重构
    if re.search(r'架构|协议|重构|schema|API.*契约', scope_text + forbidden_text, re.I):
        hits['c3'].append('架构/协议变更')

    # C2: 多文件修改、流程变更
    if len(scope) >= 3 or len(risks) >= 2:
        hits['c2'].append('多文件或多风险点')

    # C1: 单一职责变更
    if len(scope) == 1 or len(scope) == 2:
        hits['c1'].append('单一或双文件变更')

    # C0: 纯记录、格式调整
    title = ticket.get('title', '')
    if re.search(r'登记|记录|格式|typo|文案', title, re.I):
        hits['c0'].append('记录或格式类')

    # Determine suggested grade
    if hits['c3']:
        suggested = 'C3'
    elif hits['c2']:
        suggested = 'C2'
    elif hits['c1']:
        suggested = 'C1'
    else:
        suggested = 'C0'

    alignment = '一致' if suggested == actual else '分歧'

    return (tid, alignment, suggested, hits, actual)


def grade_tickets_batch(ticket_paths, profile_path):
    """Grade multiple tickets and output summary.

    Args:
        ticket_paths: List of ticket JSON paths
        profile_path: Path to complexity-profile.md

    Returns:
        0 on success
    """
    results = []
    for path in ticket_paths:
        result = grade_ticket(path, profile_path)
        results.append(result)

    # Output per-ticket details
    for tid, alignment, suggested, hits, actual in results:
        print(f"\n=== 票 {tid} ===")
        print(f"Triage 实际定级: {actual}")
        print(f"脚本建议: {suggested}")
        print(f"对照: {alignment}")

        for level in ['c3', 'c2', 'c1', 'c0']:
            if hits[level]:
                print(f"  {level.upper()} 命中: {', '.join(hits[level])}")

    # Summary
    ok = [t for t, a, _, _, _ in results if a == '一致']
    div = [(t, s, ac) for t, a, s, _, ac in results if a == '分歧']

    print("\n=== 分歧账（脚本建议 vs Triage 实际定级；供采纳票引用） ===")
    print(f"一致: {len(ok)}{('（' + ', '.join(ok) + '）') if ok else ''}")
    print(f"分歧: {len(div)}{('（' + ', '.join(f'{t}→建议{s}（实际{ac}）' for t, s, ac in div) + '）') if div else ''}")
    print(f"评估时点: {datetime.now().strftime('%Y-%m-%d')}｜建议不裁决：分歧以 Triage 为准，机器面仅承载可数判据证据")

    return 0


# ============================================================
# Run record validation and stats (extracted from run-record.sh)
# ============================================================

def seal_run_record(record_path, env_vars):
    """Seal run record with validation and mechanical field updates.

    Args:
        record_path: Path to run record JSON file
        env_vars: Dict with RR_UPDATED_AT, RR_VCS_REF, RR_FP, RR_MF

    Returns:
        0 on success, 1 on validation failure
    """
    try:
        with open(record_path, 'r', encoding='utf-8') as f:
            rec = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        print(f'run-record: FAIL: seal 校验未过（fail-closed，文件未改动）:', file=sys.stderr)
        print(f'  - JSON 解析失败: {e}', file=sys.stderr)
        return 1

    errs = []

    # Required fields check
    required_top = ['run_id', 'mode', 'phase', 'task', 'status', 'updated_at',
                    'baseline', 'scope', 'last_verified', 'next_step', 'blocker',
                    'modified_files', 'network', 'usage']
    for fld in required_top:
        if fld not in rec:
            errs.append(f'缺顶层必填字段: {fld}')

    # baseline subfields
    if 'baseline' in rec:
        if not isinstance(rec['baseline'], dict):
            errs.append('baseline 不是对象')
        else:
            for sub in ['vcs_ref', 'workspace_fingerprint']:
                if sub not in rec['baseline']:
                    errs.append(f'baseline 缺子字段: {sub}')

    # usage subfields
    if 'usage' in rec:
        if not isinstance(rec['usage'], dict):
            errs.append('usage 不是对象')
        else:
            if 'at' not in rec['usage']:
                errs.append('usage 缺子字段: at')
            else:
                uat = rec['usage']['at']
                if not isinstance(uat, str) or not re.fullmatch(
                        r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}', uat):
                    errs.append(f'usage.at 不合 pattern YYYY-MM-DDTHH:MM（同 updated_at 风格）: {uat!r}')

    if errs:
        print('run-record: FAIL: seal 校验未过（fail-closed，文件未改动）:', file=sys.stderr)
        for e in errs:
            print(f'  - {e}', file=sys.stderr)
        return 1

    # Update mechanical fields
    rec['updated_at'] = env_vars['RR_UPDATED_AT']
    rec['baseline']['vcs_ref'] = env_vars['RR_VCS_REF']
    rec['baseline']['workspace_fingerprint'] = env_vars['RR_FP']
    rec['modified_files'] = [ln for ln in env_vars['RR_MF'].split('\n') if ln != '']

    with open(record_path, 'w', encoding='utf-8') as f:
        json.dump(rec, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f'run-record: OK: seal 通过，机械字段已按当前仓库状态刷新（updated_at/vcs_ref/指纹/modified_files）: {record_path}')
    return 0


def stats_run_records(records_dir):
    """Aggregate usage statistics from run records.

    Args:
        records_dir: Path to facts/requirements/runs directory

    Returns:
        0 on success
    """
    if not os.path.isdir(records_dir):
        print(f'run-record: stats: 目录不存在: {records_dir}', file=sys.stderr)
        return 1

    files = sorted([f for f in os.listdir(records_dir) if f.endswith('.json')])
    if not files:
        print('run-record: stats: 无运行记录')
        return 0

    by_task = defaultdict(lambda: {'count': 0, 'phases': set(), 'last': None})
    by_phase = defaultdict(int)
    total = 0

    for fname in files:
        fpath = os.path.join(records_dir, fname)
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                rec = json.load(f)

            task = rec.get('task', 'unknown')
            phase = rec.get('phase', 'unknown')
            updated = rec.get('updated_at', '')

            by_task[task]['count'] += 1
            by_task[task]['phases'].add(phase)
            by_task[task]['last'] = updated
            by_phase[phase] += 1
            total += 1
        except (IOError, json.JSONDecodeError):
            continue

    print(f'=== 运行记录统计（总计 {total} 条） ===\n')

    print('按任务分组:')
    for task in sorted(by_task.keys()):
        info = by_task[task]
        phases_str = ', '.join(sorted(info['phases']))
        print(f"  {task}: {info['count']} 次（{phases_str}）最近 {info['last']}")

    print('\n按阶段分组:')
    for phase in sorted(by_phase.keys()):
        print(f"  {phase}: {by_phase[phase]} 次")

    return 0


# ============================================================
# Generic JSON operations (票 227 F3：唯一 JSON 引擎的通用操作面)
# 供脚本层取代内嵌 python heredoc 与 awk JSON 解析；src='-' 读 stdin。
# ============================================================

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


# ============================================================
# Workflow operations (票 227 F3：workflow-executor.sh 内嵌 python heredoc 收敛承载；
# 各操作与原 heredoc 逐行等价迁移，报文与退出码为执行器合同，勿改写)
# ============================================================

# issue-index 票状态枚举（Task 流转值，不含生命周期标签 superseded）；
# pattern 与 issue-index.schema.json status pattern 同源（票 221 写票索引值域强制）。
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


def wf_index_status(index_file, ticket_id, new_status):
    """Atomically update one ticket's status/updated_at in issues index.json."""
    # 写票索引值域死守（票 221）：越枚举值零写入 fail-closed；workflow 私有状态
    # 不经 state_to_ticket_status 映射不得到达本写面。
    if TICKET_STATUS_RE.fullmatch(new_status) is None:
        print(f'FAIL: {new_status!r} 不在 issue-index 票状态枚举（Task 流转值）内；拒绝写票索引', file=sys.stderr)
        return 1

    with open(index_file, 'r') as f:
        data = json.load(f)

    found = False
    for issue in data.get('issues', []):
        if issue.get('id') == ticket_id:
            issue['status'] = new_status
            issue['updated_at'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M')
            found = True
            break

    if not found:
        print(f'FAIL: 票 {ticket_id} 不在索引中', file=sys.stderr)
        return 1

    index_dir = os.path.dirname(index_file)
    with tempfile.NamedTemporaryFile('w', dir=index_dir, delete=False, suffix='.json') as tmp_f:
        json.dump(data, tmp_f, indent=2, ensure_ascii=False)
        tmp_f.write('\n')
        tmp_name = tmp_f.name

    os.rename(tmp_name, index_file)
    print(f'状态已更新: {new_status}')
    return 0


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


# ============================================================
# Ticket gate operations (票 227 F3：ticket-ops.sh 内嵌 python heredoc 收敛承载；
# 报文含调用方 ticket-ops 前缀，为 ticket-ops 合同输出，勿改写)
# ============================================================

def ticket_check_close(ticket_path, tid):
    """flip-to-done gate: task ticket body must carry a non-empty actual_time."""
    try:
        with open(ticket_path, "r", encoding="utf-8") as fh:
            body = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 收口缺 actual_time：票本体不可读或非合法 JSON: {ticket_path}（{exc}）——票 100\n")
        return 1

    if not isinstance(body, dict):
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 收口缺 actual_time：票本体顶层须为 JSON object——票 100\n")
        return 1

    if body.get("kind") != "task":
        return 0  # request 票不校验（票 100 AC2）

    value = body.get("actual_time")
    if not isinstance(value, str) or not value.strip():
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 收口缺 actual_time：task 票收口须填 actual_time（净工时口径，实际完成时间；会话段累计减中断段，测量基础随票 Checkpoint 落盘）——票 100\n")
        return 1

    return 0


def ticket_check_deps(ticket_path, index_path, tid):
    """take gate: task ticket blocked_by entries must exist in the index and be done."""
    try:
        with open(ticket_path, "r", encoding="utf-8") as fh:
            body = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 领取预检失败：票本体不可读或非合法 JSON: {ticket_path}（{exc}）——blocked_by 完整性门\n")
        return 1

    if not isinstance(body, dict):
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 领取预检失败：票本体顶层须为 JSON object——blocked_by 完整性门\n")
        return 1

    if body.get("kind") != "task":
        return 0  # request 票无 blocked_by，不校验

    blocked = body.get("blocked_by")
    if not isinstance(blocked, list):
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 领取预检失败：task 票本体 blocked_by 须为数组（schema 口径）——blocked_by 完整性门\n")
        return 1

    try:
        with open(index_path, "r", encoding="utf-8") as fh:
            index = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 领取预检失败：索引不可读或非合法 JSON: {index_path}（{exc}）——blocked_by 完整性门\n")
        return 1

    status_by_id = {}
    for entry in index.get("issues", []):
        if isinstance(entry, dict) and isinstance(entry.get("id"), str):
            status_by_id[entry["id"]] = entry.get("status")

    problems = []
    for dep in blocked:
        if not isinstance(dep, str):
            continue
        st = status_by_id.get(dep)
        if st is None:
            problems.append(f"blocked_by 引用票不存在（索引零命中）: {dep}")
        elif st != "done":
            problems.append(f"blocked_by 引用票未完成（status={st}）: {dep}")

    if problems:
        for p in problems:
            sys.stderr.write(f"ticket-ops: FAIL: 票 {tid} 领取被拒：{p}——零写入（fail-closed，blocked_by 完整性门）\n")
        return 1

    return 0


def ticket_check_open_body(ticket_path, want_id):
    """open gate: body id must match --id; reason fields must be non-empty."""
    try:
        with open(ticket_path, "r", encoding="utf-8") as f:
            body = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        sys.stderr.write(f"ticket-ops: FAIL: 无法读取文件: {e}\n")
        return 1

    problems = []

    got_id = body.get("id", "")
    if got_id != want_id:
        problems.append(f"本体 id 字段（{got_id!r}）与 --id 参数（{want_id!r}）不一致（票 79 兜底，防校验错文件）")

    reason_fields = ["complexity_reason", "priority_reason"]
    for fld in reason_fields:
        val = body.get(fld)
        if val is not None:
            if not isinstance(val, str) or not val.strip():
                problems.append(f"{fld} 须为非空字符串（票 79 理由非空断言）: {val!r}")

    if problems:
        sys.stderr.write("ticket-ops: FAIL: " + "；".join(problems) + "\n")
        return 1

    sys.stderr.write(f"ticket-ops: OK: 本体校验通过（id={got_id}；理由非空通过）\n")
    return 0


# ============================================================
# Dispatch contract helpers (票 227 F3：worktree-add.sh 合同入口 TICKET_ID 提取收敛)
# ============================================================

def contract_ticket_id(contract_file):
    """Extract TICKET_ID from a dispatch contract (JSON "TICKET_ID" key or
    {{TICKET_ID}} template section). Prints the value (possibly empty); exits 1
    on unreadable/non-UTF-8 input."""
    try:
        with open(contract_file, encoding='utf-8') as f:
            text = f.read()
    except (OSError, UnicodeDecodeError) as exc:
        print(f'json-validator: FAIL: 合同文件不可读或非 UTF-8 文本: {contract_file}（{exc}）', file=sys.stderr)
        return 1
    value = ""
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            value = str(data.get("TICKET_ID", "")).strip()
    except Exception:
        pass
    if not value:
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line.strip() == "{{TICKET_ID}}" and i + 1 < len(lines):
                value = lines[i + 1].strip()
                break
    print(value)
    return 0


# ============================================================
# CLI interface
# ============================================================

def print_usage():
    """Print usage information."""
    print("""用法: python3 json-validator.py <mode> [options]

模式:
  ticket <schema> <ticket.json> [--new-ticket]
      验证任务票 JSON 是否符合 schema
      退出码: 0=通过, 1=不合规

  grade <profile.md> <ticket.json> [...]
      评估任务票复杂度并输出建议
      退出码: 0=完成

  run seal <record.json>
      封存运行记录（校验＋刷新机械字段）
      环境变量: RR_UPDATED_AT, RR_VCS_REF, RR_FP, RR_MF
      退出码: 0=通过, 1=不合规

  run stats <records-dir>
      汇总运行记录统计
      退出码: 0=完成

  json get <src|-> <path> [default] | json type <src|-> <path> |
  json fields <src|-> <field>... | json len <src|-> <path> [default] |
  json pick <src|-> <array_path> <k> <v> [...] [field] | json count-key <src|-> <key> |
  json set <src|-> <dotted.path> <json-value>
      通用 JSON 操作面（脚本层唯一 JSON 引擎；src='-' 读 stdin；json set 为
      记录层字段级改写序列化面：输出 ensure_ascii=False＋indent=2＋末尾换行，
      纯函数零写入，原子替换归 record-store.sh）
      退出码: 0=完成, 3=路径/元素未命中, 2=用法, 1=输入不可读或非合法 JSON

  workflow <steps|state-machine|map-status|check-status|check-conditions|
            eval-condition|preflight|index-status|checkpoint-init|read-checkpoint|
            checkpoint-check|step-check|record-step> [args]
      workflow-executor.sh 专用 JSON 操作（逐行等价迁移自原内嵌 heredoc；map-status/
      check-status 为票 221 映射强制：map-status 退出码 0=映射合法/3=未映射/1=越枚举；
      check-conditions/eval-condition 为票 209 条件词表预检与结构化结果求值：
      eval-condition 打印 true/false，record-step 含 status/exit_code/
      verification_results 结构化结果）
      退出码: 0=完成, 1=校验不过, 2=用法

  ticket-check <close|deps|open-body> [args]
      ticket-ops.sh 收口/领取/开票门（报文为 ticket-ops 合同输出）
      退出码: 0=通过, 1=不过

  contract ticket-id <contract-file>
      派发合同 TICKET_ID 提取（JSON 键或 {{TICKET_ID}} 模板节）
      退出码: 0=完成（值可能为空）, 1=文件不可读

示例:
  python3 json-validator.py ticket \\
      agent-up/references/schemas/ticket-record.schema.json \\
      facts/requirements/tickets/160-python-validator-module.json

  python3 json-validator.py grade \\
      agent-up/references/protocol/complexity-profile.md \\
      facts/requirements/tickets/*.json

  RR_UPDATED_AT="2024-01-15T10:30" \\
  RR_VCS_REF="abc123" \\
  RR_FP="fp-v1:..." \\
  RR_MF="file1.txt\\nfile2.txt" \\
  python3 json-validator.py run seal facts/requirements/runs/20240115-t160impl.json

  python3 json-validator.py run stats facts/requirements/runs/
""", file=sys.stderr)


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(2)

    mode = sys.argv[1]

    if mode == 'ticket':
        if len(sys.argv) not in (4, 5) or (len(sys.argv) == 5 and sys.argv[4] != '--new-ticket'):
            print("用法: python3 json-validator.py ticket <schema> <ticket.json> [--new-ticket]", file=sys.stderr)
            sys.exit(2)
        schema_path = sys.argv[2]
        ticket_path = sys.argv[3]
        sys.exit(validate_ticket(schema_path, ticket_path, new_ticket=(len(sys.argv) == 5)))

    elif mode == 'grade':
        if len(sys.argv) < 4:
            print("用法: python3 json-validator.py grade <profile.md> <ticket.json> [...]", file=sys.stderr)
            sys.exit(2)
        profile_path = sys.argv[2]
        ticket_paths = sys.argv[3:]
        sys.exit(grade_tickets_batch(ticket_paths, profile_path))

    elif mode == 'run':
        if len(sys.argv) < 3:
            print("用法: python3 json-validator.py run <seal|stats> [args]", file=sys.stderr)
            sys.exit(2)

        submode = sys.argv[2]

        if submode == 'seal':
            if len(sys.argv) != 4:
                print("用法: python3 json-validator.py run seal <record.json>", file=sys.stderr)
                sys.exit(2)
            record_path = sys.argv[3]
            env_vars = {
                'RR_UPDATED_AT': os.environ.get('RR_UPDATED_AT', ''),
                'RR_VCS_REF': os.environ.get('RR_VCS_REF', ''),
                'RR_FP': os.environ.get('RR_FP', ''),
                'RR_MF': os.environ.get('RR_MF', '')
            }
            sys.exit(seal_run_record(record_path, env_vars))

        elif submode == 'stats':
            if len(sys.argv) != 4:
                print("用法: python3 json-validator.py run stats <records-dir>", file=sys.stderr)
                sys.exit(2)
            records_dir = sys.argv[3]
            sys.exit(stats_run_records(records_dir))

        else:
            print(f"未知 run 子模式: {submode}", file=sys.stderr)
            print_usage()
            sys.exit(2)

    elif mode == 'json':
        if len(sys.argv) < 3:
            print("用法: python3 json-validator.py json <get|type|fields|len|pick|count-key|set> [args]", file=sys.stderr)
            sys.exit(2)
        op = sys.argv[2]
        if op == 'get':
            sys.exit(json_get(sys.argv[3:]))
        elif op == 'type':
            sys.exit(json_type(sys.argv[3:]))
        elif op == 'fields':
            sys.exit(json_fields(sys.argv[3:]))
        elif op == 'len':
            sys.exit(json_len(sys.argv[3:]))
        elif op == 'pick':
            sys.exit(json_pick(sys.argv[3:]))
        elif op == 'count-key':
            sys.exit(json_count_key(sys.argv[3:]))
        elif op == 'set':
            sys.exit(json_set(sys.argv[3:]))
        else:
            print(f"未知 json 子命令: {op}", file=sys.stderr)
            print_usage()
            sys.exit(2)

    elif mode == 'workflow':
        if len(sys.argv) < 3:
            print("用法: python3 json-validator.py workflow <steps|state-machine|map-status|check-status|preflight|index-status|checkpoint-init|read-checkpoint|checkpoint-check|step-check|record-step> [args]", file=sys.stderr)
            sys.exit(2)
        sub = sys.argv[2]
        try:
            if sub == 'steps' and len(sys.argv) == 4:
                sys.exit(wf_parse_steps(sys.argv[3]))
            elif sub == 'state-machine' and len(sys.argv) == 4:
                sys.exit(wf_parse_state_machine(sys.argv[3]))
            elif sub == 'map-status' and len(sys.argv) == 5:
                sys.exit(wf_map_status(sys.argv[3], sys.argv[4]))
            elif sub == 'check-status' and len(sys.argv) == 4:
                sys.exit(wf_check_ticket_status(sys.argv[3]))
            elif sub == 'check-conditions' and len(sys.argv) == 4:
                sys.exit(wf_check_conditions(sys.argv[3]))
            elif sub == 'eval-condition' and len(sys.argv) == 7:
                sys.exit(wf_eval_condition(sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]))
            elif sub == 'preflight' and len(sys.argv) == 5:
                sys.exit(wf_preflight(sys.argv[3], sys.argv[4]))
            elif sub == 'index-status' and len(sys.argv) == 6:
                sys.exit(wf_index_status(sys.argv[3], sys.argv[4], sys.argv[5]))
            elif sub == 'checkpoint-init' and len(sys.argv) == 4:
                sys.exit(wf_checkpoint_init(sys.argv[3]))
            elif sub == 'read-checkpoint' and len(sys.argv) == 4:
                sys.exit(wf_read_checkpoint(sys.argv[3]))
            elif sub == 'checkpoint-check' and len(sys.argv) == 7:
                sys.exit(wf_checkpoint_check(sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]))
            elif sub == 'step-check' and len(sys.argv) == 6:
                sys.exit(wf_step_check(sys.argv[3], sys.argv[4], sys.argv[5]))
            elif sub == 'record-step' and len(sys.argv) == 12:
                sys.exit(wf_record_step(sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6],
                                        sys.argv[7], sys.argv[8], sys.argv[9], sys.argv[10],
                                        sys.argv[11]))
            else:
                print(f"workflow {sub}: 参数个数不合合同", file=sys.stderr)
                print_usage()
                sys.exit(2)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"workflow {sub}: 输入不可读或非合法 JSON: {exc}", file=sys.stderr)
            sys.exit(1)

    elif mode == 'ticket-check':
        if len(sys.argv) < 3:
            print("用法: python3 json-validator.py ticket-check <close|deps|open-body> [args]", file=sys.stderr)
            sys.exit(2)
        sub = sys.argv[2]
        if sub == 'close' and len(sys.argv) == 5:
            sys.exit(ticket_check_close(sys.argv[3], sys.argv[4]))
        elif sub == 'deps' and len(sys.argv) == 6:
            sys.exit(ticket_check_deps(sys.argv[3], sys.argv[4], sys.argv[5]))
        elif sub == 'open-body' and len(sys.argv) == 5:
            sys.exit(ticket_check_open_body(sys.argv[3], sys.argv[4]))
        else:
            print(f"ticket-check {sub}: 参数个数不合合同", file=sys.stderr)
            print_usage()
            sys.exit(2)

    elif mode == 'contract':
        if len(sys.argv) == 4 and sys.argv[2] == 'ticket-id':
            sys.exit(contract_ticket_id(sys.argv[3]))
        print("用法: python3 json-validator.py contract ticket-id <contract-file>", file=sys.stderr)
        sys.exit(2)

    elif mode in ['-h', '--help', 'help']:
        print_usage()
        sys.exit(0)

    else:
        print(f"未知模式: {mode}", file=sys.stderr)
        print_usage()
        sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except BrokenPipeError:
        sys.exit(0)
    except KeyboardInterrupt:
        sys.exit(1)
