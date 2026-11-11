#!/usr/bin/env python3
"""JSON engine for agent-up scripts (票 227 F3：脚本层唯一 JSON 引擎).

Entry points:
- ticket: Validate ticket JSON against schema (strict parse: duplicate keys and
  NaN/Infinity/-Infinity literals are invalid input)
- grade: Grade ticket complexity (the profile .md argument is interface-reserved:
  all countable criteria come from the ticket body, the file is not read)
- run: Validate/seal run records and compute stats
- json: Generic JSON operations (get/type/fields/len/pick/count-key/rows/set) for
  the shell script layer — the single JSON engine replacing embedded python
  heredocs and awk JSON parsing; rows prints one TAB-separated line per array
  element (check-stale-claims.sh index/ledger consumption); set is the
  record-layer field rewrite serializer (pure function, atomic replace belongs
  to record-store.sh)
- ticket-check: ticket-ops.sh gates (close/deps/open-body)
- contract: dispatch-contract TICKET_ID extraction (worktree-add.sh)
- help: print usage to stderr; aliases -h/--help (exit 0)

七族实现下沉同目录模块（票 290）：jv_ticket.py（ticket schema 解释器）、jv_grade.py、
jv_run.py、jv_json_ops.py、jv_ticket_check.py、
jv_contract.py；本件只保留薄 CLI 与共享严格 JSON 加载（StrictJSONError／_strict_load／
_load_json_file），模块经 from __main__ import 复用同一加载实现。CLI 参数面、逐行输出与
退出码不变。

Exit codes:
  0 = operation completed (含 BrokenPipeError：下游管道提前关闭按完成处理，不报失败)
  1 = validation failed or invalid input (含 KeyboardInterrupt：Ctrl-C 中断按失败退出)
      (3 = path/element miss, json ops only)
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


# ============================================================
# Shared strict JSON loading（票 290：共享加载留在薄 CLI，七族模块复用同一实现）
# ============================================================


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


def _load_json_file(path, on_error, strict=False):
    """单一 JSON 文件读取器（票 280：四处 open+load+FAIL 副本收敛于此）。

    读取并解析 path；失败时调用 on_error(exc) 由调用方输出既有合同报文，
    返回 None（调用方据此 return 1 / sys.exit(1)）。strict=True 时经
    _strict_load（拒绝 NaN/Infinity/-Infinity 与重复键），缺省保持 json.load
    既有语义（四处 ticket-check 门的行为不变）。
    """
    try:
        with open(path, 'r', encoding='utf-8') as handle:
            return _strict_load(handle) if strict else json.load(handle)
    except (IOError, json.JSONDecodeError) as exc:
        on_error(exc)
        return None


# ============================================================
# Family modules（票 290 拆分：七族各成同目录模块；缺件 fail-closed exit 2）
# ============================================================

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# 同目录族模块 import 不落 __pycache__（包闭合性检查 20 与只读安装面要求；不影响任何输出）
sys.dont_write_bytecode = True

try:
    from jv_contract import contract_ticket_id
    from jv_grade import grade_ticket, grade_tickets_batch
    from jv_json_ops import (
        json_count_key,
        json_fields,
        json_get,
        json_len,
        json_pick,
        json_rows,
        json_set,
        json_type,
    )
    from jv_run import seal_run_record, stats_run_records
    from jv_ticket import validate_ticket
    from jv_ticket_check import (
        ticket_check_close,
        ticket_check_deps,
        ticket_check_open_body,
    )
except ImportError as _import_error:
    sys.stderr.write(
        'json-validator: FAIL: 安装闭包不完整（同目录模块缺失）: %s\n' % _import_error
    )
    sys.exit(2)


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
  json rows <src|-> <array_path> <field>... |
  json set <src|-> <dotted.path> <json-value>
      通用 JSON 操作面（脚本层唯一 JSON 引擎；src='-' 读 stdin；json rows 数字组
      逐元素按字段输出 TAB 分列一行（缺字段空单元；路径缺失 3、值非数组/元素非
      对象 1），供 check-stale-claims 以行式消费索引条目；json set 为
      记录层字段级改写序列化面：输出 ensure_ascii=False＋indent=2＋末尾换行，
      纯函数零写入，原子替换归 record-store.sh）
      退出码: 0=完成, 3=路径/元素未命中, 2=用法, 1=输入不可读或非合法 JSON

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
            print("用法: python3 json-validator.py json <get|type|fields|len|pick|count-key|rows|set> [args]", file=sys.stderr)
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
        elif op == 'rows':
            sys.exit(json_rows(sys.argv[3:]))
        elif op == 'set':
            sys.exit(json_set(sys.argv[3:]))
        else:
            print(f"未知 json 子命令: {op}", file=sys.stderr)
            print_usage()
            sys.exit(2)

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
