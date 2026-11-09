"""json-validator.py run 族：run record 封存与统计（票 290 拆分；非独立入口）.

seal 校验并刷新机械字段；stats 只读聚合 usage 用量报表。
"""
import json
import os
import re
import sys
from collections import defaultdict


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
