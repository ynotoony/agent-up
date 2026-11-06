#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite json-engine "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: json-engine（票 227 F3：唯一 JSON 引擎 json-validator.py 通用操作面——
# json get/fields/len/pick/count-key/set 与 ticket-check close/deps/open-body、
# contract ticket-id 正负例覆盖；票 261 严格化——NaN 与重复键 exit 2、合法输入对照；
# 票 280 契约校准与结构收敛——help/-h/--help exit 0、全局退出码口径、
# workflow index-status 死代码删除（exit 2 零写入）、validate_ticket 走 _strict_load
# （NaN/重复键 exit 1）、四门单一 loader 报文不变、json set 序列化面、grade 接口保留；
# json-helpers.sh awk 行解析退役后由本套件承接解析层行为回归）
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

  result=$(python3 "$ENGINE" json pick "$D/index.json" issues id a-first status 'done')
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

  # ---- 票 261 AC2：非标准 JSON fail-closed（NaN／重复键 exit 2，合法输入仍放行）----
  printf '%s\n' '{"value": NaN}' > "$D/nan.json"
  python3 "$ENGINE" json get "$D/nan.json" value >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok 'json 拒绝 NaN 字面量（exit 2，fail-closed）'
  else
    bad 'json 拒绝 NaN 字面量（exit 2，fail-closed）' "expected=2 actual=$rc"
  fi

  printf '%s\n' '{"key": 1, "key": 2}' > "$D/dup-key.json"
  python3 "$ENGINE" json get "$D/dup-key.json" key >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok 'json 拒绝同一对象重复键（exit 2，fail-closed）'
  else
    bad 'json 拒绝同一对象重复键（exit 2，fail-closed）' "expected=2 actual=$rc"
  fi

  result=$(python3 "$ENGINE" json get "$D/entry.json" status)
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$result" = "ready" ]; then
    ok '严格化后合法 JSON 仍 exit 0 且取值不变（负例对照）'
  else
    bad '严格化后合法 JSON 仍 exit 0 且取值不变（负例对照）' "exit=$rc actual=$result"
  fi

  # ---- 票 280：help 模式（契约头 help 条目）与全局退出码口径 ----
  for harg in help -h --help; do
    python3 "$ENGINE" "$harg" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
      ok "help 模式 $harg exit 0（契约头 help 条目）"
    else
      bad "help 模式 $harg exit 0（契约头 help 条目）" "expected=0 actual=$rc"
    fi
  done

  usage_out=$(python3 "$ENGINE" help 2>&1)
  case $usage_out in
    *'index-status'*) bad 'help 用法不再列出已删除的 workflow index-status（死代码收敛）' 'usage 仍含 index-status' ;;
    *) ok 'help 用法不再列出已删除的 workflow index-status（死代码收敛）' ;;
  esac

  # ---- 票 280：死代码 wf_index_status 删除后 index-status 不再是合同子命令 ----
  printf '%s\n' '{"issues": [{"id": "x-1", "status": "ready"}]}' > "$D/wf-index.json"
  python3 "$ENGINE" workflow index-status "$D/wf-index.json" x-1 'done' >"$D/wf-is.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '参数个数不合合同' "$D/wf-is.out" \
    && grep -q '"status": "ready"' "$D/wf-index.json"; then
    ok 'workflow index-status 死代码删除后 exit 2 且索引文件零写入'
  else
    bad 'workflow index-status 死代码删除后 exit 2 且索引文件零写入' "exit=$rc"
  fi

  # ---- 票 280：validate_ticket 改走 _strict_load（NaN/重复键 exit 1，合法票仍放行）----
  printf '%s\n' '{"type": "object", "required": ["id"], "additionalProperties": false, "properties": {"id": {"type": "string"}}}' > "$D/mini-schema.json"
  printf '%s\n' '{"id": "legal-t"}' > "$D/mini-legal.json"
  python3 "$ENGINE" ticket "$D/mini-schema.json" "$D/mini-legal.json" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok 'ticket 严格化后合法票仍 exit 0（负例对照）'
  else
    bad 'ticket 严格化后合法票仍 exit 0（负例对照）' "expected=0 actual=$rc"
  fi

  printf '%s\n' '{"id": "nan-t", "complexity": NaN}' > "$D/mini-nan.json"
  python3 "$ENGINE" ticket "$D/mini-schema.json" "$D/mini-nan.json" >"$D/t-nan.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'ticket-validate: FAIL: 无法读取文件' "$D/t-nan.out"; then
    ok 'ticket 票体 NaN 字面量经 _strict_load 判非法（exit 1）'
  else
    bad 'ticket 票体 NaN 字面量经 _strict_load 判非法（exit 1）' "exit=$rc"
  fi

  printf '%s\n' '{"id": "dup-t", "id": "dup-t2"}' > "$D/mini-dup.json"
  python3 "$ENGINE" ticket "$D/mini-schema.json" "$D/mini-dup.json" >"$D/t-dup.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '同一对象内重复键' "$D/t-dup.out"; then
    ok 'ticket 票体重复键经 _strict_load 判非法（exit 1）'
  else
    bad 'ticket 票体重复键经 _strict_load 判非法（exit 1）' "exit=$rc"
  fi

  # ---- 票 280：四门经单一 loader，缺失文件仍按既有 ticket-ops 合同报文 exit 1 ----
  python3 "$ENGINE" ticket-check close "$D/no-such-ticket.json" t9 >"$D/tc-miss.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'ticket-ops: FAIL: 票 t9 收口缺 actual_time：票本体不可读或非合法 JSON' "$D/tc-miss.out"; then
    ok 'ticket-check close 缺失文件经单一 loader 仍按合同报文 exit 1'
  else
    bad 'ticket-check close 缺失文件经单一 loader 仍按合同报文 exit 1' "exit=$rc"
  fi

  # ---- 票 280：json set 记录层序列化面（契约头 json 条目补 set）----
  set_out=$(printf '%s\n' '{"a": {"b": 1}}' | python3 "$ENGINE" json set - a.c 2)
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$set_out" | grep -q '"c": 2' \
    && printf '%s' "$set_out" | grep -q '"b": 1'; then
    ok 'json set 点路径设置并规范化序列化输出（中间层对象保留）'
  else
    bad 'json set 点路径设置并规范化序列化输出（中间层对象保留）' "exit=$rc"
  fi

  # ---- 票 280：grade 传递面不变（profile 参数接口保留、不读取）----
  printf 'profile placeholder\n' > "$D/grade-profile.md"
  printf '%s\n' '{"id": "9-grade-t", "complexity": "C1", "scope": ["a"]}' > "$D/grade-ticket.json"
  grade_out=$(python3 "$ENGINE" grade "$D/grade-profile.md" "$D/grade-ticket.json")
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$grade_out" | grep -q '=== 票 9-grade-t ==='; then
    ok 'grade 带 profile 接口参数仍 exit 0 且逐票输出（接口保留、未读取）'
  else
    bad 'grade 带 profile 接口参数仍 exit 0 且逐票输出（接口保留、未读取）' "exit=$rc"
  fi

  suite_summary 'json-engine'
}
