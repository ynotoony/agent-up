"""json-validator.py grade 族：票复杂度定级建议（票 290 拆分；非独立入口）.

profile .md 参数为接口保留值（可数判据全部来自票本体，不读该件）。
"""
import json
import re
import sys
from datetime import datetime


def grade_ticket(ticket_path, profile_path):
    """Grade ticket complexity based on criteria.

    Args:
        ticket_path: Path to ticket JSON file
        profile_path: 接口保留参数（complexity-profile.md 路径）：可数判据全部取自
            票本体（scope/forbidden/risks/title），当前实现不读取该文件——与
            ticket-grade.sh 传递面保持接口一致（其脚本头注声明票的七维 profile
            字段不在可算面）

    Returns:
        五元组 (ticket_id, alignment_status, suggested_grade, hits, actual)：
        hits 为各档命中理由字典、actual 为票本体登记的复杂度值
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
        profile_path: 接口保留参数（同上，仅逐票透传；当前实现不读取）

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
