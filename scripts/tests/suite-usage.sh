#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite usage "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: usage（票 295 成本治理：repo-only usage-report.sh 用量计量）
# 覆盖：可用会话统计口径（只计 type=assistant/message 的 data.usage 三键求和、
#       calls＝条数、total＝三者和；user/session/无 usage 记录不计）、缺省会话目录
#       推导（DSH_HOME/sessions/--<cwd 编码>--）、目录/文件不可用/日志损坏 →
#       exit 0 + status=unavailable（fail-open 不伪造）、参数错误 exit 2、零写入。
# 依赖：zstd（缺 zstd 整套 SKIP，覆盖归有 zstd 的环境）；被测件为仓侧 repo-only 件
#       rules/implementation/scripts/usage-report.sh（不在公开包安装闭包内）。
# ============================================================

us_report_path() {
  # 打印 repo-only usage-report.sh 路径（仓根 = 包根上一级；消费项目无该件即 SKIP）
  printf '%s' "$PKG_ROOT/../rules/implementation/scripts/usage-report.sh"
}

us_enc() {
  # $1=绝对 cwd：打印该 cwd 的 DSH 会话目录编码（/ 全换 - 后去首 -，两端再由调用方包 --）
  printf '%s' "$1" | sed 's|/|-|g; s|^-||'
}

us_build_session() {
  # $1=会话目录 $2=会话 id $3=模式（ok|corrupt）
  _us_d="$1/$2"
  mkdir -p "$_us_d"
  if [ "$3" = 'corrupt' ]; then
    printf 'not-a-zstd-stream\n' > "$_us_d/session.v4.jsonl.zstd"
    return 0
  fi
  {
    printf '{"type":"session","version":4,"id":"%s"}\n' "$2"
    printf '{"type":"user/message","seq":1,"data":{"text":"hi"}}\n'
    printf '{"type":"assistant/message","seq":2,"data":{"usage":{"inputTokens":100,"cacheReadTokens":20,"outputTokens":5,"cacheWriteTokens":0,"totalTokens":125}}}\n'
    printf '{"type":"assistant/message","seq":3,"data":{"message":{"role":"assistant"},"usage":{"inputTokens":7,"cacheReadTokens":3,"outputTokens":2}}}\n'
    printf '{"type":"assistant/message","seq":4,"data":{"message":{"role":"assistant"}}}\n'
    printf '{"type":"tool/result","seq":5,"data":{"usage":{"inputTokens":999,"cacheReadTokens":999,"outputTokens":999}}}\n'
  } | zstd -q -c > "$_us_d/session.v4.jsonl.zstd"
}

suite_usage() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='usage'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/us
  mkdir -p "$D"

  US=$(us_report_path)
  if [ ! -r "$US" ]; then
    printf 'SKIP  [usage] 被测件不在场（%s）——仓侧 repo-only 件，消费项目不作覆盖声明\n' "$US"
    suite_summary 'usage'
    return 0
  fi
  if ! command -v zstd >/dev/null 2>&1; then
    printf 'SKIP  [usage] 环境缺 zstd——整套 SKIP（不造假绿；覆盖归有 zstd 的环境）\n'
    suite_summary 'usage'
    return 0
  fi

  SID='11111111-2222-3333-4444-555555555555'

  # 正例 P1：两条 assistant/message usage 求和；user/session/无 usage/tool 记录不计
  us_build_session "$D/p1" "$SID" ok
  sh "$US" --session-id "$SID" --sessions-dir "$D/p1" --json > "$D/p1.json" 2> "$D/p1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && require_out 'suite-usage P1 目标输出在场' "$D/p1.json" \
    && python3 - "$D/p1.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
ok = (d.get('schema_version') == 1 and d.get('status') == 'ok'
      and d.get('totals') == {'calls': 2, 'input': 107, 'cache_read': 23, 'output': 7, 'total': 137}
      and len(d.get('sessions') or []) == 1
      and d['sessions'][0]['id'] == '11111111-2222-3333-4444-555555555555'
      and d['sessions'][0]['total'] == 137)
sys.exit(0 if ok else 1)
PY
  then
    ok '正例 P1 可用会话 → status=ok 且 totals 恰为 usage 三键求和（calls=2/input=107/cache=23/output=7/total=137；非 assistant/message 与无 usage 记录不计）'
  else
    bad '正例 P1 可用会话 → status=ok 且 totals 恰为 usage 三键求和' "exit=$rc out=$(head -c 200 "$D/p1.json") err=$(head -c 120 "$D/p1.err" | tr '\n' '|')"
  fi

  # 正例 P1b：--sessions 支持 glob（票 295 复审）——两个会话目录命中恰 2、统计为并集
  GID_A='glob-aaa'
  GID_B='glob-bbb'
  us_build_session "$D/pglob" "$GID_A" ok
  us_build_session "$D/pglob" "$GID_B" ok
  sh "$US" --sessions 'glob-*' --sessions-dir "$D/pglob" --json > "$D/pglob.json" 2> "$D/pglob.err"
  rc=$?
  if [ "$rc" -eq 0 ] && require_out 'suite-usage P1b 目标输出在场' "$D/pglob.json" \
    && python3 - "$D/pglob.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
ok = (d.get('status') == 'ok' and len(d.get('sessions') or []) == 2
      and {s['id'] for s in d['sessions']} == {'glob-aaa', 'glob-bbb'}
      and d.get('totals') == {'calls': 4, 'input': 214, 'cache_read': 46, 'output': 14, 'total': 274})
sys.exit(0 if ok else 1)
PY
  then
    ok '正例 P1b glob 展开：--sessions glob-* 命中恰 2 个会话（字典序去重）且 totals 为并集（calls=4/total=274）'
  else
    bad '正例 P1b glob 展开：--sessions glob-* 命中恰 2 个会话且 totals 为并集（calls=4/total=274）' "exit=$rc out=$(head -c 260 "$D/pglob.json") err=$(head -c 120 "$D/pglob.err" | tr '\n' '|')"
  fi
  sh "$US" --sessions 'no-such-*' --sessions-dir "$D/pglob" --json > "$D/pglob0.out" 2> "$D/pglob0.err"
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$D/pglob0.out" ] && grep -q 'glob 无命中' "$D/pglob0.err" && grep -q 'no-such-\*' "$D/pglob0.err"; then
    ok '负例 P1c glob 无命中 → exit 2 且 stderr 指名 glob 与会话目录（不静默零统计）'
  else
    bad '负例 P1c glob 无命中 → exit 2 且 stderr 指名 glob 与会话目录' "exit=$rc out=$(head -c 120 "$D/pglob0.out") err=$(head -c 160 "$D/pglob0.err" | tr '\n' '|')"
  fi

  # 正例 P1d：bracket glob（[ ] 字符类）——'glob-[ab]*' 命中恰 2；'[g]lob-bbb' 命中恰 1
  sh "$US" --sessions 'glob-[ab]*' --sessions-dir "$D/pglob" --json > "$D/pbr1.json" 2> "$D/pbr1.err"
  rc=$?
  if [ "$rc" -eq 0 ] && require_out 'suite-usage P1d 目标输出在场' "$D/pbr1.json" \
    && python3 - "$D/pbr1.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
ok = (d.get('status') == 'ok' and len(d.get('sessions') or []) == 2
      and {s['id'] for s in d['sessions']} == {'glob-aaa', 'glob-bbb'}
      and d.get('totals') == {'calls': 4, 'input': 214, 'cache_read': 46, 'output': 14, 'total': 274})
sys.exit(0 if ok else 1)
PY
  then
    ok '正例 P1d bracket glob：glob-[ab]* 命中恰 2 个会话且 totals 为并集（字符类展开）'
  else
    bad '正例 P1d bracket glob：glob-[ab]* 命中恰 2 个会话且 totals 为并集' "exit=$rc out=$(head -c 240 "$D/pbr1.json") err=$(head -c 120 "$D/pbr1.err" | tr '\n' '|')"
  fi
  sh "$US" --sessions '[g]lob-bbb' --sessions-dir "$D/pglob" --json > "$D/pbr2.json" 2> "$D/pbr2.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id":"glob-bbb"' "$D/pbr2.json" && grep -q '"total":137' "$D/pbr2.json" \
    && ! grep -q '"id":"glob-aaa"' "$D/pbr2.json"; then
    ok '正例 P1e bracket glob：字面量字符类 [g]lob-bbb 命中恰 1 个会话（calls=2/total=137）'
  else
    bad '正例 P1e bracket glob：字面量字符类 [g]lob-bbb 命中恰 1 个会话' "exit=$rc out=$(head -c 200 "$D/pbr2.json") err=$(head -c 120 "$D/pbr2.err" | tr '\n' '|')"
  fi

  # 正例 P2：缺省会话目录推导（DSH_HOME/sessions/--<cwd 编码>--，不传 --sessions-dir）
  _us_cwd=$(pwd -P)
  _us_enc=$(us_enc "$_us_cwd")
  _us_dir="$D/dsh/sessions/--$_us_enc--"
  us_build_session "$_us_dir" "$SID" ok
  ( cd "$_us_cwd" && DSH_HOME="$D/dsh" sh "$US" --session-id "$SID" --json ) > "$D/p2.json" 2> "$D/p2.err"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"status":"ok"' "$D/p2.json" && grep -q '"total":137' "$D/p2.json"; then
    ok '正例 P2 缺省会话目录推导（DSH_HOME/sessions/--<cwd 编码>--）→ status=ok 且统计一致'
  else
    bad '正例 P2 缺省会话目录推导（DSH_HOME/sessions/--<cwd 编码>--）→ status=ok 且统计一致' "exit=$rc out=$(head -c 200 "$D/p2.json") err=$(head -c 120 "$D/p2.err" | tr '\n' '|')"
  fi

  # 正例 P3：人类可读输出（非 --json）
  sh "$US" --session-id "$SID" --sessions-dir "$D/p1" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q "usage-report: 会话 $SID: calls=2 input=107 cache_read=23 output=7 total=137" "$D/p3.out" \
    && grep -q 'usage-report: 合计: calls=2 input=107 cache_read=23 output=7 total=137' "$D/p3.out"; then
    ok '正例 P3 人类可读输出逐项一致（会话行＋合计行）'
  else
    bad '正例 P3 人类可读输出逐项一致' "exit=$rc out=$(head -c 200 "$D/p3.out")"
  fi

  # 负例 N1：会话目录不存在 → exit 0 + status=unavailable（fail-open）
  sh "$US" --session-id "$SID" --sessions-dir "$D/no-such-dir" --json > "$D/n1.json" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"status":"unavailable"' "$D/n1.json" && grep -q '"reason":"会话目录不存在' "$D/n1.json"; then
    ok '负例 N1 会话目录不存在 → exit 0 且 status=unavailable（fail-open，不伪造数字）'
  else
    bad '负例 N1 会话目录不存在 → exit 0 且 status=unavailable' "exit=$rc out=$(head -c 200 "$D/n1.json")"
  fi

  # 负例 N2：会话日志缺失 → exit 0 + status=unavailable 指名路径
  mkdir -p "$D/n2dir"
  sh "$US" --session-id "$SID" --sessions-dir "$D/n2dir" --json > "$D/n2.json" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"status":"unavailable"' "$D/n2.json" && grep -q "会话日志缺失.*$SID" "$D/n2.json"; then
    ok '负例 N2 会话日志缺失 → exit 0 且 status=unavailable 指名缺失路径'
  else
    bad '负例 N2 会话日志缺失 → exit 0 且 status=unavailable 指名缺失路径' "exit=$rc out=$(head -c 200 "$D/n2.json")"
  fi

  # 负例 N3：日志损坏（非 zstd 流）→ exit 0 + status=unavailable
  us_build_session "$D/n3dir" "$SID" corrupt
  sh "$US" --session-id "$SID" --sessions-dir "$D/n3dir" --json > "$D/n3.json" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"status":"unavailable"' "$D/n3.json" && grep -q '解压或解析失败' "$D/n3.json"; then
    ok '负例 N3 日志损坏 → exit 0 且 status=unavailable（解压/解析失败不伪造统计）'
  else
    bad '负例 N3 日志损坏 → exit 0 且 status=unavailable' "exit=$rc out=$(head -c 200 "$D/n3.json")"
  fi

  # 负例 N4：参数错误 exit 2（缺会话 id / 未知参数 / 非法 id）
  sh "$US" --json > "$D/n4a.out" 2>&1
  rc_a=$?
  sh "$US" --session-id "$SID" --sessions-dir "$D/p1" --bogus > "$D/n4b.out" 2>&1
  rc_b=$?
  sh "$US" --session-id '../evil' --sessions-dir "$D/p1" --json > "$D/n4c.out" 2>&1
  rc_c=$?
  if [ "$rc_a" -eq 2 ] && [ "$rc_b" -eq 2 ] && [ "$rc_c" -eq 2 ]; then
    ok '负例 N4 参数错误（缺会话 id／未知参数／非法 id）→ 均 exit 2'
  else
    bad '负例 N4 参数错误 → 均 exit 2' "rc=$rc_a/$rc_b/$rc_c"
  fi

  # 正例 P4：零写入（统计前后夹具树与 cksum 全等；只读会话日志）
  ( cd "$D" && LC_ALL=C find p1 n3dir dsh -type f -exec cksum {} + | LC_ALL=C sort ) > "$D/before.cksum"
  sh "$US" --session-id "$SID" --sessions-dir "$D/p1" --json >/dev/null 2>&1
  sh "$US" --session-id "$SID" --sessions-dir "$D/n3dir" --json >/dev/null 2>&1
  ( cd "$D" && LC_ALL=C find p1 n3dir dsh -type f -exec cksum {} + | LC_ALL=C sort ) > "$D/after.cksum"
  if cmp -s "$D/before.cksum" "$D/after.cksum"; then
    ok '正例 P4 零写入（会话日志与夹具 cksum 前后一致，只读计量）'
  else
    bad '正例 P4 零写入（会话日志与夹具 cksum 前后一致）'
  fi

  suite_summary 'usage'
}
