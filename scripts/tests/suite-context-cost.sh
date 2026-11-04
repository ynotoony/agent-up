#!/bin/sh
# Input: 同目录被测脚本 measure-context-cost.sh（只读调用）与其依赖 common-helpers.sh、
#        json-validator.py；夹具参数：合成 wire.jsonl 会话树、fixture 基线 JSON、治理体积
#        模板夹（九件）——全部构建于 mktemp 临时目录，trap 清理。
# Output: 逐项 PASS/FAIL 断言与套件汇总：AC1 四项基数逐项相等、AC2 基线差值／样本阈值／
#        缺失项 fail-closed（exit 非零且零 stdout）、阈值 0／空样本同样拒绝、AC5 治理三项与每阶段读取集差值、
#        未知字段容忍与只读零写入复核。
# Pos: context-cost 套件（成本治理度量面回归）；直接运行 sh tests/suite-context-cost.sh
#      即跑本套件；派发表／suite 覆盖表见同目录 README.md 与 test-runner.sh。

if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite context-cost "$@"
  exit $?
fi

# ============================================================
# suite: context-cost（会话成本与治理体积复测）
#   夹具口径：main＝2 次 usage.record、1+2+0 个工具调用、1 个 25001 字符 tool 结果；
#   sub＝1 次 usage.record、0 工具调用。合计 raw=13350、cache_read=11000、
#   input_added=1800、output=550、context_per_call=12800/3=4266。
#   基线 JSON＝raw14000／cache11500／added1900／output600／context4300／
#   tools1.20／big2／over1／calls4，差值＝基线−当前。
# ============================================================

cc_make_sessions() {
  # $1=夹具根：sessions/a/agents/{main,sub}/wire.jsonl
  rm -rf "$1"
  mkdir -p "$1/sessions/a/agents/main" "$1/sessions/a/agents/sub"
  cat > "$1/sessions/a/agents/main/wire.jsonl" <<'EOF'
{"type":"usage.record","agentId":"main","model":"m","usage":{"inputOther":1000,"output":300,"inputCacheRead":5000,"inputCacheCreation":200},"usageScope":"turn","time":1,"futureField":"tolerated"}
{"type":"agent.message.appended","message":{"message":{"role":"assistant","content":[],"toolCalls":[{"type":"function","id":"c1","name":"Read","arguments":"{}"}]},"meta":{}}}
{"type":"agent.message.appended","message":{"message":{"role":"tool","content":[{"type":"text","text":"small result"}],"toolCallId":"c1"},"meta":{}}}
{"type":"usage.record","agentId":"main","model":"m","usage":{"inputOther":500,"output":200,"inputCacheRead":6000,"inputCacheCreation":0},"usageScope":"turn","time":2,"unknownUsageField":{"x":1}}
{"type":"agent.message.appended","message":{"message":{"role":"assistant","content":[],"toolCalls":[{"type":"function","id":"c2","name":"Read","arguments":"{}"},{"type":"function","id":"c3","name":"Read","arguments":"{}"}]},"meta":{}}}
{"type":"agent.message.appended","message":{"message":{"role":"assistant","content":[],"toolCalls":[]},"meta":{}}}
EOF
  {
    printf '%s' '{"type":"agent.message.appended","message":{"message":{"role":"tool","content":[{"type":"text","text":"'
    awk 'BEGIN { for (i = 0; i < 25001; i++) printf "x" }'
    printf '%s\n' '"}],"toolCallId":"c3"},"meta":{}}}'
  } >> "$1/sessions/a/agents/main/wire.jsonl"
  cat > "$1/sessions/a/agents/sub/wire.jsonl" <<'EOF'
{"type":"usage.record","agentId":"sub","model":"m","usage":{"inputOther":100,"output":50,"inputCacheRead":0,"inputCacheCreation":0},"usageScope":"turn","time":3}
EOF
}

cc_make_session_baseline() {
  cat > "$1" <<'EOF'
{
  "raw": 14000,
  "cache_read": 11500,
  "input_added": 1900,
  "output": 600,
  "context_per_call": 4300,
  "tool_calls_per_step": 1.20,
  "tool_results_over_20000": 2,
  "agents_over_250_steps": 1,
  "calls": 4
}
EOF
}

cc_make_templates() {
  # $1=模板目录；九件内容固定，字符数可手算：安装件 46 字、2 个规则块
  rm -rf "$1"
  mkdir -p "$1"
  printf 'a\n' > "$1/AGENTS.md.tmpl"
  printf 'c\n' > "$1/core.md.tmpl"
  printf 'd\n' > "$1/project.md.tmpl"
  printf 'e\n' > "$1/assessment.md.tmpl"
  printf 'f\n' > "$1/discipline.md.tmpl"
  printf 'g\n' > "$1/agents-triage.md.tmpl"
  printf 'h\n' > "$1/agents-implementation.md.tmpl"
  printf 'i\n' > "$1/agents-review.md.tmpl"
  printf 'j\n#### R-AA-001\n#### R-AA-002\n' > "$1/agents-commit.md.tmpl"
}

cc_make_gov_baseline() {
  cat > "$1" <<'EOF'
{
  "install_chars": 60,
  "install_blocks": 4,
  "stage_triage_chars": 20,
  "stage_implementation_chars": 20,
  "stage_review_chars": 20,
  "stage_commit_chars": 50
}
EOF
}

cc_run() {
  sh "$SCRIPT_DIR/measure-context-cost.sh" "$@" > "$D/out" 2> "$D/err"
  rc=$?
}

cc_row() {
  # $1=指标名：输出该行第 2 列（当前值）
  awk -v k="$1" '$1 == k { print $2; exit }' "$D/out"
}

cc_delta() {
  # $1=指标名：输出该行第 4 列（差值＝基线−当前）
  awk -v k="$1" '$1 == k { print $4; exit }' "$D/out"
}

cc_assert_row() {
  # $1=断言名 $2=期望 $3=实际
  if [ "$3" = "$2" ]; then
    ok "$1（$2）"
  else
    bad "$1（期望 $2）" "实际 ${3:-<空>}"
  fi
}

suite_context_cost() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='context-cost'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/context-cost
  mkdir -p "$D"
  SCRIPT="$SCRIPT_DIR/measure-context-cost.sh"

  if [ ! -f "$SCRIPT" ]; then
    bad '被测脚本在场' "缺件: $SCRIPT"
    suite_summary 'context-cost'
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    bad 'python3 可用（指标聚合依赖）' 'python3 不在 PATH'
    suite_summary 'context-cost'
    return 1
  fi

  cc_make_sessions "$D/s1"
  cc_make_session_baseline "$D/session-baseline.json"
  _before=$(cksum "$D/s1/sessions/a/agents/main/wire.jsonl" "$D/s1/sessions/a/agents/sub/wire.jsonl")

  # ---- AC1：四项基数逐项相等 ----
  cc_run --sessions "$D/s1/sessions" --min-samples 3
  cc_assert_row 'AC1 raw' 13350 "$(cc_row raw)"
  cc_assert_row 'AC1 cache_read（缓存重放）' 11000 "$(cc_row cache_read)"
  cc_assert_row 'AC1 input_added（新增输入）' 1800 "$(cc_row input_added)"
  cc_assert_row 'AC1 output' 550 "$(cc_row output)"
  cc_assert_row '每次调用上下文=输入合计/调用数' 4266 "$(cc_row context_per_call)"
  cc_assert_row '每步工具调用数（均值 2 位）' 1.00 "$(cc_row tool_calls_per_step)"
  cc_assert_row '超 2 万字符结果数（长度取解码文本）' 1 "$(cc_row tool_results_over_20000)"
  cc_assert_row '超 250 步 agent 数' 0 "$(cc_row agents_over_250_steps)"
  if [ "$rc" -eq 0 ] && grep -q '^样本: calls=3 阈值=3 ' "$D/out"; then
    ok '样本计数非空（calls=3 阈值=3）'
  else
    bad '样本计数非空（calls=3 阈值=3）' "exit=$rc $(grep '^样本:' "$D/out")"
  fi
  if grep -qF '每步工具调用分布: 0个=1 1个=1 2个=1 3个+=0' "$D/out"; then
    ok '每步工具调用分布（0/1/2 各 1 步）'
  else
    bad '每步工具调用分布（0/1/2 各 1 步）' "$(grep '每步工具调用分布' "$D/out")"
  fi
  if grep -q '^每agent步数分布: <=10=2 11-50=0 ' "$D/out"; then
    ok '每 agent 步数分布（两 agent 均 ≤10 步）'
  else
    bad '每 agent 步数分布（两 agent 均 ≤10 步）' "$(grep '每agent步数分布' "$D/out")"
  fi
  _lines=$(wc -l < "$D/out" | tr -d ' ')
  if [ "$_lines" -le 40 ]; then
    ok "输出不超过 40 行（实际 ${_lines} 行）"
  else
    bad "输出不超过 40 行（实际 ${_lines} 行）"
  fi

  # ---- AC2：基线逐项差值 ----
  cc_run --sessions "$D/s1/sessions" --baseline "$D/session-baseline.json" --min-samples 3
  if [ "$rc" -eq 0 ]; then
    ok 'AC2 给定基线 JSON → exit 0'
  else
    bad 'AC2 给定基线 JSON → exit 0' "exit=$rc $(head -c 160 "$D/err")"
  fi
  cc_assert_row 'AC2 raw 差值' 650 "$(cc_delta raw)"
  cc_assert_row 'AC2 cache_read 差值' 500 "$(cc_delta cache_read)"
  cc_assert_row 'AC2 input_added 差值' 100 "$(cc_delta input_added)"
  cc_assert_row 'AC2 output 差值' 50 "$(cc_delta output)"
  cc_assert_row 'AC2 context_per_call 差值' 34 "$(cc_delta context_per_call)"
  cc_assert_row 'AC2 tool_calls_per_step 差值（下降为负收益）' 0.20 "$(cc_delta tool_calls_per_step)"
  cc_assert_row 'AC2 tool_results_over_20000 差值' 1 "$(cc_delta tool_results_over_20000)"
  cc_assert_row 'AC2 agents_over_250_steps 差值' 1 "$(cc_delta agents_over_250_steps)"
  if grep -q '基线calls=4' "$D/out"; then
    ok 'AC2 样本计数含基线 calls=4'
  else
    bad 'AC2 样本计数含基线 calls=4' "$(grep '^样本:' "$D/out")"
  fi

  # ---- AC2 负例：样本不足 / 路径缺失 / 基线缺失，均零 stdout 且指名 ----
  cc_run --sessions "$D/s1/sessions" --baseline "$D/session-baseline.json" --min-samples 4
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q '样本不足' "$D/err" && grep -q 'calls' "$D/err"; then
    ok 'AC2 样本不足 → exit 非 0、零 stdout、指名 calls 与阈值'
  else
    bad 'AC2 样本不足 → exit 非 0、零 stdout、指名 calls 与阈值' "exit=$rc stdout=$(wc -c < "$D/out") $(head -c 120 "$D/err")"
  fi

  cc_run --sessions "$D/no-such-sessions"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q "$D/no-such-sessions" "$D/err"; then
    ok 'AC2 会话路径不存在 → exit 非 0、零 stdout、指名路径'
  else
    bad 'AC2 会话路径不存在 → exit 非 0、零 stdout、指名路径' "exit=$rc $(head -c 120 "$D/err")"
  fi

  mkdir -p "$D/empty-sessions"
  cc_run --sessions "$D/empty-sessions"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q '无 wire.jsonl' "$D/err"; then
    ok 'AC2 目录无 wire.jsonl → exit 非 0、零 stdout、指名缺失项'
  else
    bad 'AC2 目录无 wire.jsonl → exit 非 0、零 stdout、指名缺失项' "exit=$rc $(head -c 120 "$D/err")"
  fi

  mkdir -p "$D/zero-records"
  printf '%s\n' '{"type":"session.meta","agentId":"main"}' > "$D/zero-records/wire.jsonl"
  cc_run --sessions "$D/zero-records" --baseline "$D/session-baseline.json"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q '样本不足' "$D/err" && grep -q 'calls' "$D/err"; then
    ok 'AC2 0 条 usage.record＋基线＋默认阈值 → exit 非 0、零 stdout、指名 calls'
  else
    bad 'AC2 0 条 usage.record＋基线＋默认阈值 → exit 非 0、零 stdout、指名 calls' "exit=$rc stdout=$(wc -c < "$D/out") $(head -c 120 "$D/err")"
  fi

  cc_run --sessions "$D/s1/sessions" --baseline "$D/no-such-baseline.json" --min-samples 3
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q "$D/no-such-baseline.json" "$D/err"; then
    ok 'AC2 基线路径不存在 → exit 非 0、零 stdout、指名路径'
  else
    bad 'AC2 基线路径不存在 → exit 非 0、零 stdout、指名路径' "exit=$rc $(head -c 120 "$D/err")"
  fi

  printf '%s\n' '{"raw": 1}' > "$D/partial-baseline.json"
  cc_run --sessions "$D/s1/sessions" --baseline "$D/partial-baseline.json" --min-samples 3
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q '基线缺指标: cache_read' "$D/err"; then
    ok 'AC2 基线缺指标 → exit 非 0、零 stdout、指名首个缺失指标'
  else
    bad 'AC2 基线缺指标 → exit 非 0、零 stdout、指名首个缺失指标' "exit=$rc $(head -c 120 "$D/err")"
  fi

  # ---- 无基线时只输出当前值，基线列占位 '-' ----
  cc_run --sessions "$D/s1/sessions" --min-samples 3
  if [ "$rc" -eq 0 ] && [ "$(awk '$1 == "raw" { print $3 }' "$D/out")" = '-' ]; then
    ok '无基线 → 基线列占位为 -，仍输出当前值'
  else
    bad '无基线 → 基线列占位为 -，仍输出当前值' "exit=$rc $(awk '$1 == "raw"' "$D/out")"
  fi

  # ---- 未知字段与缺字段容忍：只取已知数值键，缺 cache 字段按 0 ----
  rm -rf "$D/tolerant"
  mkdir -p "$D/tolerant/agents/main"
  cat > "$D/tolerant/agents/main/wire.jsonl" <<'EOF'
{"type":"usage.record","agentId":"main","model":"m","usage":{"inputOther":10,"output":5,"brandNewField":99},"usageScope":"turn","time":1}
EOF
  cc_run --sessions "$D/tolerant" --min-samples 1
  cc_assert_row '未知字段容忍且缺失缓存字段按 0（raw=15）' 15 "$(cc_row raw)"
  cc_assert_row '缺失缓存字段按 0（cache_read=0）' 0 "$(cc_row cache_read)"

  # ---- 只读零写入复核 ----
  _after=$(cksum "$D/s1/sessions/a/agents/main/wire.jsonl" "$D/s1/sessions/a/agents/sub/wire.jsonl")
  if [ "$_before" = "$_after" ]; then
    ok '只读零写入复核（夹具 cksum 前后一致）'
  else
    bad '只读零写入复核（夹具 cksum 前后一致）' 'cksum 变化'
  fi

  # ---- AC5：治理体积模式 ----
  cc_make_templates "$D/templates"
  cc_make_gov_baseline "$D/gov-baseline.json"
  cc_run --governance --templates "$D/templates" --baseline "$D/gov-baseline.json"
  if [ "$rc" -eq 0 ]; then
    ok 'AC5 治理模式给定基线 → exit 0'
  else
    bad 'AC5 治理模式给定基线 → exit 0' "exit=$rc $(head -c 160 "$D/err")"
  fi
  cc_assert_row 'AC5 安装件字符数' 46 "$(cc_row install_chars)"
  cc_assert_row 'AC5 安装件规则块数' 2 "$(cc_row install_blocks)"
  cc_assert_row 'AC5 triage 读取集字符数' 10 "$(cc_row stage_triage_chars)"
  cc_assert_row 'AC5 implementation 读取集字符数' 10 "$(cc_row stage_implementation_chars)"
  cc_assert_row 'AC5 review 读取集字符数' 10 "$(cc_row stage_review_chars)"
  cc_assert_row 'AC5 commit 读取集字符数' 36 "$(cc_row stage_commit_chars)"
  cc_assert_row 'AC5 安装件字符数差值（下降为正收益）' 14 "$(cc_delta install_chars)"
  cc_assert_row 'AC5 规则块数差值' 2 "$(cc_delta install_blocks)"
  cc_assert_row 'AC5 triage 差值' 10 "$(cc_delta stage_triage_chars)"
  cc_assert_row 'AC5 implementation 差值' 10 "$(cc_delta stage_implementation_chars)"
  cc_assert_row 'AC5 review 差值' 10 "$(cc_delta stage_review_chars)"
  cc_assert_row 'AC5 commit 差值' 14 "$(cc_delta stage_commit_chars)"

  cc_run --governance --templates "$D/no-such-templates"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q "$D/no-such-templates" "$D/err"; then
    ok 'AC5 模板目录不存在 → exit 非 0、零 stdout、指名路径'
  else
    bad 'AC5 模板目录不存在 → exit 非 0、零 stdout、指名路径' "exit=$rc $(head -c 120 "$D/err")"
  fi

  rm -f "$D/templates/agents-review.md.tmpl"
  cc_run --governance --templates "$D/templates"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q 'agents-review.md.tmpl' "$D/err"; then
    ok 'AC5 安装件缺失 → exit 非 0、零 stdout、指名缺失件'
  else
    bad 'AC5 安装件缺失 → exit 非 0、零 stdout、指名缺失件' "exit=$rc $(head -c 120 "$D/err")"
  fi

  printf '%s\n' '{"install_chars": 60}' > "$D/partial-gov.json"
  cc_make_templates "$D/templates2"
  cc_run --governance --templates "$D/templates2" --baseline "$D/partial-gov.json"
  if [ "$rc" -ne 0 ] && [ ! -s "$D/out" ] && grep -q '基线缺指标: install_blocks' "$D/err"; then
    ok 'AC5 治理基线缺指标 → exit 非 0、零 stdout、指名缺失指标'
  else
    bad 'AC5 治理基线缺指标 → exit 非 0、零 stdout、指名缺失指标' "exit=$rc $(head -c 120 "$D/err")"
  fi

  # ---- 用法面 ----
  cc_run --help
  if [ "$rc" -eq 0 ] && grep -q '用法:' "$D/out"; then
    ok '--help 打印用法 exit 0'
  else
    bad '--help 打印用法 exit 0' "exit=$rc"
  fi
  cc_run --min-samples abc
  if [ "$rc" -eq 2 ] && [ ! -s "$D/out" ]; then
    ok '非法 --min-samples → exit 2、零 stdout'
  else
    bad '非法 --min-samples → exit 2、零 stdout' "exit=$rc"
  fi
  cc_run --sessions "$D/zero-records" --baseline "$D/session-baseline.json" --min-samples 0
  if [ "$rc" -eq 2 ] && [ ! -s "$D/out" ] && grep -q 'min-samples' "$D/err" && grep -q '下界 1' "$D/err"; then
    ok '--min-samples 0 → exit 2、零 stdout、指名参数与合法下界'
  else
    bad '--min-samples 0 → exit 2、零 stdout、指名参数与合法下界' "exit=$rc stdout=$(wc -c < "$D/out") $(head -c 120 "$D/err")"
  fi

  suite_summary 'context-cost'
}
