#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite json-engine "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: json-engine（票 227 F3：唯一 JSON 引擎 json-validator.py 通用操作面——
# json get/fields/len/pick/count-key 与 ticket-check close/deps/open-body、
# contract ticket-id 正负例覆盖；json-helpers.sh awk 行解析退役后由本套件承接
# 解析层行为回归，至少 12 断言）
# ============================================================

suite_json_engine() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  CUR_SUITE='json-engine'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/jeng
  mkdir -p "$D"
  TAB=$(printf '\t')
  ENGINE="$SCRIPT_DIR/json-validator.py"

  printf '%s\n' '{"id": "123-test", "status": "ready", "checkpoint_ref": "", "complexity": 2}' > "$D/entry.json"
  printf '%s\n' '{"issues": [{"id": "a-first", "status": "done"}, {"id": "b-second", "status": "ready", "n": 7}]}' > "$D/index.json"

  # ---- json fields（generate-progress 条目解析承载）----
  result=$(python3 "$ENGINE" json fields "$D/entry.json" id status checkpoint_ref)
  if [ "$result" = "123-test${TAB}ready${TAB}" ]; then
    ok 'json fields 提取多字段 TAB 分列（缺字段空单元格）'
  else
    bad 'json fields 提取多字段 TAB 分列（缺字段空单元格）' "expected=<3列> actual=$result"
  fi

  python3 "$ENGINE" json fields "$D/entry.json" id nope >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'json fields 缺失字段不报错（空单元格语义）'
  else
    bad 'json fields 缺失字段不报错（空单元格语义）' "expected=0 actual=$rc"
  fi

  printf '%s\n' '[1,2]' | python3 "$ENGINE" json fields - id >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok 'json fields 顶层非对象 exit 2（fail-closed）'
  else
    bad 'json fields 顶层非对象 exit 2（fail-closed）' "expected=2 actual=$rc"
  fi

  # ---- json get（workflow-executor step 元数据承载）----
  result=$(printf '%s\n' '{"steps": [{"id": "s1"}]}' | python3 "$ENGINE" json get - steps.0.id)
  if [ "$result" = "s1" ]; then
    ok 'json get stdin 点路径（数组下标段）取值'
  else
    bad 'json get stdin 点路径（数组下标段）取值' "expected=s1 actual=$result"
  fi

  result=$(python3 "$ENGINE" json get "$D/entry.json" complexity)
  if [ "$result" = "2" ]; then
    ok 'json get 数值标量原样输出'
  else
    bad 'json get 数值标量原样输出' "expected=2 actual=$result"
  fi

  result=$(python3 "$ENGINE" json get "$D/entry.json" nope '[]')
  if [ "$result" = "[]" ]; then
    ok 'json get 缺路径回退 default 字面量'
  else
    bad 'json get 缺路径回退 default 字面量' "expected=[] actual=$result"
  fi

  python3 "$ENGINE" json get "$D/entry.json" nope >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok 'json get 缺路径无 default exit 3'
  else
    bad 'json get 缺路径无 default exit 3' "expected=3 actual=$rc"
  fi

  # ---- json type（收据字段类型校验承载）----
  result=''
  for _type_path in s n b z a o; do
    _type_value=$(printf '%s\n' '{"s": "x", "n": 1, "b": true, "z": null, "a": [], "o": {}}' | \
      python3 "$ENGINE" json type - "$_type_path")
    result="$result${result:+ }$_type_value"
  done
  if [ "$result" = 'string number boolean null array object' ]; then
    ok 'json type 六类取值'
  else
    bad 'json type 六类取值' "expected=string number boolean null array object actual=$result"
  fi

  python3 "$ENGINE" json type "$D/entry.json" nope >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok 'json type 缺路径 exit 3'
  else
    bad 'json type 缺路径 exit 3' "expected=3 actual=$rc"
  fi

  # ---- json len / count-key ----
  result=$(printf '%s\n' '{"transitions": [1,2,3]}' | python3 "$ENGINE" json len - transitions 0)
  if [ "$result" = "3" ]; then
    ok 'json len 数组长度（stdin）'
  else
    bad 'json len 数组长度（stdin）' "expected=3 actual=$result"
  fi

  result=$(printf '%s\n' '{"a": {"completed_at": "x"}, "b": [{"completed_at": "y"}]}' | python3 "$ENGINE" json count-key - completed_at)
  if [ "$result" = "2" ]; then
    ok 'json count-key 递归计数'
  else
    bad 'json count-key 递归计数' "expected=2 actual=$result"
  fi

  # ---- json pick（索引状态读取与状态机转换核对承载）----
  result=$(python3 "$ENGINE" json pick "$D/index.json" issues id b-second status)
  if [ "$result" = "ready" ]; then
    ok 'json pick 单键命中取字段'
  else
    bad 'json pick 单键命中取字段' "expected=ready actual=$result"
  fi

  python3 "$ENGINE" json pick "$D/index.json" issues id zzz status >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok 'json pick 零命中 exit 3'
  else
    bad 'json pick 零命中 exit 3' "expected=3 actual=$rc"
  fi

  result=$(python3 "$ENGINE" json pick "$D/index.json" issues id a-first status done)
  case $result in
    '{"id": "a-first", "status": "done"}') ok 'json pick 多键全等命中输出整元素 JSON' ;;
    *) bad 'json pick 多键全等命中输出整元素 JSON' "actual=$result" ;;
  esac

  # ---- ticket-check close（flip 收口硬拦承载）----
  printf '%s\n' '{"id": "t1", "kind": "request"}' > "$D/req.json"
  python3 "$ENGINE" ticket-check close "$D/req.json" t1 >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'ticket-check close request 票不校验放行'
  else
    bad 'ticket-check close request 票不校验放行' "expected=0 actual=$rc"
  fi

  printf '%s\n' '{"id": "t2", "kind": "task", "actual_time": ""}' > "$D/task-bad.json"
  python3 "$ENGINE" ticket-check close "$D/task-bad.json" t2 >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok 'ticket-check close task 票 actual_time 空白即拒'
  else
    bad 'ticket-check close task 票 actual_time 空白即拒' "expected=1 actual=$rc"
  fi

  # ---- ticket-check deps（blocked_by 完整性门承载）----
  printf '%s\n' '{"id": "t3", "kind": "task", "blocked_by": ["b-second"]}' > "$D/task-dep.json"
  python3 "$ENGINE" ticket-check deps "$D/task-dep.json" "$D/index.json" t3 >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok 'ticket-check deps blocker 未完成即拒（fail-closed）'
  else
    bad 'ticket-check deps blocker 未完成即拒（fail-closed）' "expected=1 actual=$rc"
  fi

  printf '%s\n' '{"id": "t4", "kind": "task", "blocked_by": ["a-first"]}' > "$D/task-dep-ok.json"
  python3 "$ENGINE" ticket-check deps "$D/task-dep-ok.json" "$D/index.json" t4 >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'ticket-check deps blocker 已完成放行'
  else
    bad 'ticket-check deps blocker 已完成放行' "expected=0 actual=$rc"
  fi

  # ---- ticket-check open-body（open id 一致＋理由非空承载）----
  printf '%s\n' '{"id": "other", "complexity_reason": "x", "priority_reason": "y"}' > "$D/body.json"
  python3 "$ENGINE" ticket-check open-body "$D/body.json" t5 >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok 'ticket-check open-body 本体 id 与 --id 不一致即拒（票 79 兜底）'
  else
    bad 'ticket-check open-body 本体 id 与 --id 不一致即拒（票 79 兜底）' "expected=1 actual=$rc"
  fi

  # ---- contract ticket-id（worktree-add 合同入口承载）----
  printf '%s\n' '{"TICKET_ID": "42-contract-slug"}' > "$D/c.json"
  result=$(python3 "$ENGINE" contract ticket-id "$D/c.json")
  if [ "$result" = "42-contract-slug" ]; then
    ok 'contract ticket-id JSON 键提取'
  else
    bad 'contract ticket-id JSON 键提取' "expected=42-contract-slug actual=$result"
  fi

  {
    printf 'text line\n{{TICKET_ID}}\n77-template-slug\n'
  } > "$D/c.tmpl"
  result=$(python3 "$ENGINE" contract ticket-id "$D/c.tmpl")
  if [ "$result" = "77-template-slug" ]; then
    ok 'contract ticket-id 模板节次行提取'
  else
    bad 'contract ticket-id 模板节次行提取' "expected=77-template-slug actual=$result"
  fi

  suite_summary 'json-engine'
}
