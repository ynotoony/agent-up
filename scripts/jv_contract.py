"""json-validator.py contract 族：派发合同 TICKET_ID 提取（票 290 拆分；非独立入口）.

供 worktree-add.sh 合同入口消费（JSON 键或 {{TICKET_ID}} 模板节）。
"""
import json
import sys


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
