"""json-validator.py ticket-check 族：ticket-ops 收口/领取/开票门（票 290 拆分；非独立入口）.

报文为 ticket-ops.sh 合同输出。
"""
import sys

# 本模块由 json-validator.py（薄 CLI）在同进程内 import；共享严格 JSON 加载
# （StrictJSONError／_strict_load／_load_json_file）留在入口模块，本模块经
# from __main__ import 复用同一实现，不复制第二份解析器。

from __main__ import _load_json_file


def ticket_check_close(ticket_path, tid):
    """flip-to-done gate: task ticket body must carry a non-empty actual_time."""
    body = _load_json_file(ticket_path, lambda exc: sys.stderr.write(
        f"ticket-ops: FAIL: 票 {tid} 收口缺 actual_time：票本体不可读或非合法 JSON: {ticket_path}（{exc}）——票 100\n"))
    if body is None:
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
    body = _load_json_file(ticket_path, lambda exc: sys.stderr.write(
        f"ticket-ops: FAIL: 票 {tid} 领取预检失败：票本体不可读或非合法 JSON: {ticket_path}（{exc}）——blocked_by 完整性门\n"))
    if body is None:
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

    index = _load_json_file(index_path, lambda exc: sys.stderr.write(
        f"ticket-ops: FAIL: 票 {tid} 领取预检失败：索引不可读或非合法 JSON: {index_path}（{exc}）——blocked_by 完整性门\n"))
    if index is None:
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
    body = _load_json_file(ticket_path, lambda exc: sys.stderr.write(
        f"ticket-ops: FAIL: 无法读取文件: {exc}\n"))
    if body is None:
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
