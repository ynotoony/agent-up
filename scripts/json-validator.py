#!/usr/bin/env python3
"""JSON validation module for agent-up scripts.

Provides three validation entry points:
- ticket: Validate ticket JSON against schema
- grade: Grade ticket complexity
- run: Validate/seal run records and compute stats

Exit codes:
  0 = validation passed (ticket/run modes) or grading completed (grade mode)
  1 = validation failed or invalid input
  2 = usage error or missing dependencies
"""

import sys
import os
import json
import re
from datetime import datetime
from collections import defaultdict


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

    # id pattern
    if 'id' in body and 'id' in props:
        pat = props['id'].get('pattern')
        if pat and not re.fullmatch(pat, body['id']):
            errs.append(f"id 不合 pattern: {body['id']!r}")

    # kind enum
    if 'kind' in body and 'kind' in props:
        enum = props['kind'].get('enum', [])
        if enum and body['kind'] not in enum:
            errs.append(f"kind 不在枚举: {body['kind']!r}")

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
