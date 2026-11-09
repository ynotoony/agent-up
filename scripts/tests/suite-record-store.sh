#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite record-store "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: record-store（票 272 记录层写面 module 回归）
# record_path 六类记录路径唯一承载表；record_write 整文件原子替换（含目标缺失首建）；
# record_append 追加＋字节前缀断言（含懒创建）；record_set_json 字段级改写经唯一 JSON
# 引擎 json set 序列化（indent=2＋ensure_ascii=False＋末尾换行）并回读核对；三类负例
# fail-closed——越界路径（绝对路径／.. 段／父目录 symlink 逃逸）、symlink 外指、追加
# 前缀破坏（并发改写窗口内被截断，RECORD_STORE_TEST_APPEND_HOLD_MS 放大窗口）。
# 探针只 source 公开 interface（路径表＋三写动词），不按实现猜内部函数。
# ============================================================

rs_fixture() {
  # $1=夹具根：记录层四类载体＋票本体（非 Git 语境，锁走 $TMPDIR 回退）
  rm -rf "$1"
  mkdir -p "$1/facts/requirements/tickets" "$1/facts/project"
  printf '# 票据索引（fixture）\n' > "$1/facts/requirements/tickets/README.md"
  printf '{\n  "issues": []\n}\n' > "$1/facts/requirements/tickets/index.json"
  printf '%s\n' '{"date":"2026-01-01","kind":"change","scope":"s","decision":"seed","evidence_ref":"e"}' \
    > "$1/facts/project/changes.jsonl"
  printf '{\n  "id": "41-rs-fixture",\n  "checkpoint": {}\n}\n' \
    > "$1/facts/requirements/tickets/41-rs-fixture.json"
}

rs_probe() {
  # $1=动词名；其余透传（模块函数经探针 source 后按名调用）
  sh "$D/probe.sh" "$SCRIPT_DIR" "$@"
}

suite_record_store() {
  # shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）
  CUR_SUITE='record-store'
  # shellcheck disable=SC2034  # 同上：套件计数由父进程按日志汇总
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 同上：套件起点计数由父进程按日志汇总
  SUITE_START=$TOTAL
  D=$T/rs
  mkdir -p "$D"
  F=$D/fix
  rs_fixture "$F"
  cat > "$D/probe.sh" <<'PROBE'
#!/bin/sh
set -eu
set -f
_sd=$1
shift
COMMON_HELPERS_DIR=$_sd
export COMMON_HELPERS_DIR
. "$_sd/common-helpers.sh"
. "$_sd/record-store.sh"
"$@"
PROBE

  # ---- 正例：路径表六类 ----
  rs_path_case() {
    # $1=记录键 $2=期望路径 $3=场景名
    _rp_out=$(rs_probe record_path "$1" 2>"$D/path.err") || _rp_out=''
    if [ "$_rp_out" = "$2" ]; then
      ok "$3（$1 → $2）"
    else
      bad "$3（$1 → $2）" "实际: $_rp_out $(head -n 1 "$D/path.err" 2>/dev/null)"
    fi
  }
  rs_path_case index 'facts/requirements/tickets/index.json' '正例 路径表 index'
  rs_path_case changes 'facts/project/changes.jsonl' '正例 路径表 changes'
  rs_path_case micro 'facts/project/micro.jsonl' '正例 路径表 micro'
  rs_path_case tickets-readme 'facts/requirements/tickets/README.md' '正例 路径表 tickets-readme'
  rs_path_case 'ticket:41-rs-fixture' 'facts/requirements/tickets/41-rs-fixture.json' '正例 路径表 ticket:<id>'
  rs_path_case 'checkpoint:41-rs-fixture' 'facts/requirements/tickets/41-rs-fixture-review-checkpoint.md' '正例 路径表 checkpoint:<id>'
  rs_probe record_path bogus-key >"$D/unknown.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '未登记的记录键' "$D/unknown.log"; then
    ok '负例 未登记记录键 → exit 2 指名（记录路径只经路径表解析）'
  else
    bad '负例 未登记记录键 → exit 2 指名（记录路径只经路径表解析）' "exit=$rc $(head -n 2 "$D/unknown.log" | tr '\n' '|')"
  fi

  # ---- 正例：record_write 整文件原子替换 ----
  printf '{"issues": [\n  {"id": "41-rs-fixture", "status": "ready"}\n]}\n' > "$D/new-index.json"
  rs_probe record_write "$F" index "$D/new-index.json" >"$D/rw.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && cmp -s "$D/new-index.json" "$F/facts/requirements/tickets/index.json"; then
    ok '正例 record_write index → 整文件原子替换逐字节等于内容件'
  else
    bad '正例 record_write index → 整文件原子替换逐字节等于内容件' "exit=$rc $(head -n 2 "$D/rw.log" | tr '\n' '|')"
  fi
  if [ -z "$(ls "$F/facts/requirements/tickets"/.record-store.* 2>/dev/null)" ]; then
    ok '正例 record_write 同目录临时件零残留'
  else
    bad '正例 record_write 同目录临时件零残留' "$(ls "$F/facts/requirements/tickets"/.record-store.* 2>/dev/null)"
  fi
  printf '# 票 41 User Review Checkpoint（fixture）\n' > "$D/ck-content.md"
  rs_probe record_write "$F" 'checkpoint:41-rs-fixture' "$D/ck-content.md" >"$D/rw2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && cmp -s "$D/ck-content.md" "$F/facts/requirements/tickets/41-rs-fixture-review-checkpoint.md"; then
    ok '正例 record_write checkpoint 目标缺失 → 原子首建逐字节等于内容件'
  else
    bad '正例 record_write checkpoint 目标缺失 → 原子首建逐字节等于内容件' "exit=$rc $(head -n 2 "$D/rw2.log" | tr '\n' '|')"
  fi

  # ---- 正例：record_append 追加＋前缀保留（历史字节不变） ----
  cp "$F/facts/project/changes.jsonl" "$D/seed-changes.jsonl"
  printf '%s\n' '{"date":"2026-01-02","kind":"change","scope":"s","decision":"second","evidence_ref":"e"}' > "$D/append.txt"
  rs_probe record_append "$F" changes "$D/append.txt" >"$D/ra.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 record_append changes 目标在场 → 追加落尾 exit 0'
  else
    bad '正例 record_append changes 目标在场 → 追加落尾 exit 0' "exit=$rc $(head -n 2 "$D/ra.log" | tr '\n' '|')"
  fi
  cat "$D/seed-changes.jsonl" "$D/append.txt" > "$D/expected-changes.jsonl"
  if cmp -s "$D/expected-changes.jsonl" "$F/facts/project/changes.jsonl"; then
    ok '正例 record_append changes → 历史行逐字节保留且追加行落尾'
  else
    bad '正例 record_append changes → 历史行逐字节保留且追加行落尾' "$(diff "$D/expected-changes.jsonl" "$F/facts/project/changes.jsonl" 2>/dev/null | head -n 3 | tr '\n' '|')"
  fi
  rs_probe record_append "$F" micro "$D/append.txt" >"$D/ram.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && cmp -s "$D/append.txt" "$F/facts/project/micro.jsonl"; then
    ok '正例 record_append micro → 懒创建父目录与账本本体并落首行'
  else
    bad '正例 record_append micro → 懒创建父目录与账本本体并落首行' "exit=$rc $(head -n 2 "$D/ram.log" | tr '\n' '|')"
  fi

  # ---- 负例：越界路径 fail-closed（绝对路径／.. 段／父目录 symlink 逃逸） ----
  rs_fixture "$D/fix1"
  printf '{"issues": []}\n' > "$D/out.json"
  rs_probe record_write "$D/fix1" "$D/out.json" "$D/new-index.json" >"$D/nabs.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '记录路径' "$D/nabs.log"; then
    ok '负例 N1 record_write 绝对路径 → exit 1 零写入（路径字面量只经路径表）'
  else
    bad '负例 N1 record_write 绝对路径 → exit 1 零写入（路径字面量只经路径表）' "exit=$rc $(head -n 2 "$D/nabs.log" | tr '\n' '|')"
  fi
  rs_fixture "$D/fix2"
  : > "$D/outside.json"
  before=$(cksum "$D/outside.json" | awk '{print $1}')
  rs_probe record_write "$D/fix2" '../outside.json' "$D/new-index.json" >"$D/ndot.log" 2>&1
  rc=$?
  after=$(cksum "$D/outside.json" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && grep -q '路径段' "$D/ndot.log"; then
    ok '负例 N2 record_write 含 .. 路径段 → exit 1 仓外文件零写入'
  else
    bad '负例 N2 record_write 含 .. 路径段 → exit 1 仓外文件零写入' "exit=$rc before=$before after=$after $(head -n 2 "$D/ndot.log" | tr '\n' '|')"
  fi
  rs_fixture "$D/fix3"
  mkdir -p "$D/outside-dir"
  printf 'outside\n' > "$D/outside-dir/changes.jsonl"
  rm -rf "$D/fix3/facts/project"
  ln -s "$D/outside-dir" "$D/fix3/facts/project"
  before=$(cksum "$D/outside-dir/changes.jsonl" | awk '{print $1}')
  rs_probe record_append "$D/fix3" changes "$D/append.txt" >"$D/npar.log" 2>&1
  rc=$?
  after=$(cksum "$D/outside-dir/changes.jsonl" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
    ok '负例 N3 记录路径父目录 symlink 外指 → exit 1 仓外文件零写入（realpath containment）'
  else
    bad '负例 N3 记录路径父目录 symlink 外指 → exit 1 仓外文件零写入（realpath containment）' "exit=$rc before=$before after=$after $(head -n 2 "$D/npar.log" | tr '\n' '|')"
  fi

  # ---- 负例：记录文件末段 symlink 外指 ----
  rs_fixture "$D/fix4"
  : > "$D/outside-link.jsonl"
  printf 'outside\n' > "$D/outside-link.jsonl"
  rm -f "$D/fix4/facts/project/changes.jsonl"
  ln -s "$D/outside-link.jsonl" "$D/fix4/facts/project/changes.jsonl"
  before=$(cksum "$D/outside-link.jsonl" | awk '{print $1}')
  rs_probe record_append "$D/fix4" changes "$D/append.txt" >"$D/nlink.log" 2>&1
  rc=$?
  after=$(cksum "$D/outside-link.jsonl" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && grep -q 'symlink' "$D/nlink.log"; then
    ok '负例 N4 记录文件为 symlink（外指）→ exit 1 且链接目标零写入'
  else
    bad '负例 N4 记录文件为 symlink（外指）→ exit 1 且链接目标零写入' "exit=$rc before=$before after=$after $(head -n 2 "$D/nlink.log" | tr '\n' '|')"
  fi

  # ---- 负例：追加前缀破坏（追加窗口内记录被改写/截断） ----
  rs_fixture "$D/fix5"
  RECORD_STORE_TEST_APPEND_HOLD_MS=600 \
    sh "$D/probe.sh" "$SCRIPT_DIR" record_append "$D/fix5" changes "$D/append.txt" >"$D/nprefix.log" 2>&1 &
  rs_prefix_pid=$!
  sleep 0.3
  printf 'REWRITTEN\n' > "$D/fix5/facts/project/changes.jsonl"
  wait "$rs_prefix_pid"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '前缀' "$D/nprefix.log"; then
    ok '负例 N5 追加窗口内记录被改写 → 追加前缀断言失败 exit 1（fail-closed 如实报告）'
  else
    bad '负例 N5 追加窗口内记录被改写 → 追加前缀断言失败 exit 1（fail-closed 如实报告）' "exit=$rc $(head -n 2 "$D/nprefix.log" | tr '\n' '|')"
  fi

  # ---- 正例：record_set_json 字段级改写（唯一 JSON 引擎序列化形态） ----
  rs_fixture "$D/fix6"
  RECORD_STORE_ENGINE="$SCRIPT_DIR/json-validator.py" \
    rs_probe record_set_json "$D/fix6" 'ticket:41-rs-fixture' \
      --doc-set 'checkpoint.commit={"committed_at": "2026-11-05", "commit": "abc1234"}' \
      >"$D/set.log" 2>&1
  rc=$?
  cat > "$D/expected-ticket.json" <<'EOF'
{
  "id": "41-rs-fixture",
  "checkpoint": {
    "commit": {
      "committed_at": "2026-11-05",
      "commit": "abc1234"
    }
  }
}
EOF
  if [ "$rc" -eq 0 ] && cmp -s "$D/expected-ticket.json" "$D/fix6/facts/requirements/tickets/41-rs-fixture.json"; then
    ok '正例 record_set_json 票本体 checkpoint.commit → 字段级改写逐字节等于金样（indent=2＋末尾换行）'
  else
    bad '正例 record_set_json 票本体 checkpoint.commit → 字段级改写逐字节等于金样（indent=2＋末尾换行）' "exit=$rc $(diff "$D/expected-ticket.json" "$D/fix6/facts/requirements/tickets/41-rs-fixture.json" 2>/dev/null | head -n 4 | tr '\n' '|')"
  fi
  before=$(cksum "$D/fix6/facts/requirements/tickets/41-rs-fixture.json" | awk '{print $1}')
  RECORD_STORE_ENGINE="$D/no-such-engine.py" \
    rs_probe record_set_json "$D/fix6" 'ticket:41-rs-fixture' \
      --doc-set 'checkpoint.commit={"committed_at": "2026-11-06", "commit": "def5678"}' \
      >"$D/setmiss.log" 2>&1
  rc=$?
  after=$(cksum "$D/fix6/facts/requirements/tickets/41-rs-fixture.json" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && [ "$before" = "$after" ] && grep -q 'json-validator.py' "$D/setmiss.log"; then
    ok '负例 N6 唯一 JSON 引擎缺失 → exit 1 票本体零写入且指名缺失件'
  else
    bad '负例 N6 唯一 JSON 引擎缺失 → exit 1 票本体零写入且指名缺失件' "exit=$rc before=$before after=$after $(head -n 2 "$D/setmiss.log" | tr '\n' '|')"
  fi
  before=$(cksum "$D/fix6/facts/requirements/tickets/41-rs-fixture.json" | awk '{print $1}')
  RECORD_STORE_ENGINE="$SCRIPT_DIR/json-validator.py" \
    rs_probe record_set_json "$D/fix6" 'ticket:41-rs-fixture' \
      --doc-set 'checkpoint.commit={bad json' >"$D/setbad.log" 2>&1
  rc=$?
  after=$(cksum "$D/fix6/facts/requirements/tickets/41-rs-fixture.json" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && [ "$before" = "$after" ]; then
    ok '负例 N7 字段值不合 JSON → exit 1 票本体零写入'
  else
    bad '负例 N7 字段值不合 JSON → exit 1 票本体零写入' "exit=$rc before=$before after=$after $(head -n 2 "$D/setbad.log" | tr '\n' '|')"
  fi

  # ---- 正例 R2：record_write 权限还原（既有记录保原 mode；目标缺失首建 0644） ----
  rs_fixture "$D/fix8"
  chmod 640 "$D/fix8/facts/requirements/tickets/index.json"
  rs_probe record_write "$D/fix8" index "$D/new-index.json" >"$D/mode1.log" 2>&1
  rc=$?
  rs_mode1=$(stat -f '%Lp' "$D/fix8/facts/requirements/tickets/index.json" 2>/dev/null) || \
    rs_mode1=$(stat -c '%a' "$D/fix8/facts/requirements/tickets/index.json" 2>/dev/null) || rs_mode1=''
  if [ "$rc" -eq 0 ] && [ "$rs_mode1" = '640' ]; then
    ok '正例 R2 record_write 既有记录保留原权限（640 不被 mktemp 落成 600）'
  else
    bad '正例 R2 record_write 既有记录保留原权限（640 不被 mktemp 落成 600）' "exit=$rc mode=$rs_mode1 $(head -n 2 "$D/mode1.log" | tr '\n' '|')"
  fi
  rs_probe record_write "$D/fix8" 'checkpoint:41-rs-fixture' "$D/ck-content.md" >"$D/mode2.log" 2>&1
  rc=$?
  rs_mode2=$(stat -f '%Lp' "$D/fix8/facts/requirements/tickets/41-rs-fixture-review-checkpoint.md" 2>/dev/null) || \
    rs_mode2=$(stat -c '%a' "$D/fix8/facts/requirements/tickets/41-rs-fixture-review-checkpoint.md" 2>/dev/null) || rs_mode2=''
  if [ "$rc" -eq 0 ] && [ "$rs_mode2" = '644' ]; then
    ok '正例 R2 record_write 目标缺失首建按 0644 落位（不遗留 mktemp 的 600）'
  else
    bad '正例 R2 record_write 目标缺失首建按 0644 落位（不遗留 mktemp 的 600）' "exit=$rc mode=$rs_mode2"
  fi

  # ---- 负例 F1：票 id 形态不合 fail-closed 且不得退化为 unbound variable 展开 ----
  LC_ALL=C sh "$D/probe.sh" "$SCRIPT_DIR" record_path 'ticket:bad-id' >"$D/idbad-c.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '形态不合' "$D/idbad-c.log" \
    && ! grep -Eq 'unbound variable|parameter not set' "$D/idbad-c.log"; then
    ok '负例 F1 LC_ALL=C 下 ticket:bad-id → exit 2 指名形态不合（无 unbound variable 退化）'
  else
    bad '负例 F1 LC_ALL=C 下 ticket:bad-id → exit 2 指名形态不合（无 unbound variable 退化）' "exit=$rc $(head -n 2 "$D/idbad-c.log" | tr '\n' '|')"
  fi
  sh "$D/probe.sh" "$SCRIPT_DIR" record_path 'ticket:bad-id' >"$D/idbad-def.log" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '形态不合' "$D/idbad-def.log" \
    && ! grep -Eq 'unbound variable|parameter not set' "$D/idbad-def.log"; then
    ok '负例 F1 默认 locale 下 ticket:bad-id → exit 2 指名形态不合（无 unbound variable 退化）'
  else
    bad '负例 F1 默认 locale 下 ticket:bad-id → exit 2 指名形态不合（无 unbound variable 退化）' "exit=$rc $(head -n 2 "$D/idbad-def.log" | tr '\n' '|')"
  fi

  # ---- 正例 F1 连带：schema 读侧合法存量 request 票 id（REQ-YYYYMMDD-NNN）可建 checkpoint ----
  rs_fixture "$D/fix9"
  printf '{\n  "id": "REQ-20260904-011",\n  "kind": "request"\n}\n' \
    > "$D/fix9/facts/requirements/tickets/REQ-20260904-011.json"
  sh "$SCRIPT_DIR/checkpoint-write.sh" "$D/fix9" review-checkpoint \
    --ticket 'facts/requirements/tickets/REQ-20260904-011.json' \
    --verdict-quote 'OK（REQ id 夹具）' --verdict-at '2026-11-05T16:00' \
    --commit 'abcdef1234567890' --commit-subject 'fixture' \
    --diff-summary 'M a.txt' --date '2026-11-05' >"$D/reqcw.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$D/fix9/facts/requirements/tickets/REQ-20260904-011-review-checkpoint.md" ] \
    && grep -q 'User Review Checkpoint' "$D/fix9/facts/requirements/tickets/REQ-20260904-011-review-checkpoint.md"; then
    ok '正例 F1 连带 REQ-20260904-011 存量 request 票 → checkpoint-write exit 0 建独立 checkpoint md'
  else
    bad '正例 F1 连带 REQ-20260904-011 存量 request 票 → checkpoint-write exit 0 建独立 checkpoint md' "exit=$rc $(head -n 2 "$D/reqcw.log" | tr '\n' '|')"
  fi

  # ---- 正例 R1-①：持锁窗口内第二方写被挡（RECORD_LOCK_TEST_HOLD_MS 放大窗口） ----
  rs_fixture "$D/fix10"
  rs_lock_dir10=$(COMMON_HELPERS_DIR="$SCRIPT_DIR" sh -c '. "$1/common-helpers.sh"; record_lock_init "$2"; printf "%s" "$RECORD_LOCK_DIR"' sh "$SCRIPT_DIR" "$D/fix10")
  before=$(cksum "$D/fix10/facts/requirements/tickets/index.json" | awk '{print $1}')
  RECORD_LOCK_TEST_HOLD_MS=3000 \
    sh "$D/probe.sh" "$SCRIPT_DIR" record_append "$D/fix10" changes "$D/append.txt" >"$D/lockhold.log" 2>&1 &
  rs_hold_pid=$!
  rs_wait=0
  while [ ! -d "$rs_lock_dir10" ] && [ "$rs_wait" -lt 40 ]; do
    sleep 0.05
    rs_wait=$((rs_wait + 1))
  done
  TICKET_OPS_LOCK_TIMEOUT=1 \
    sh "$D/probe.sh" "$SCRIPT_DIR" record_write "$D/fix10" index "$D/new-index.json" >"$D/locksecond.log" 2>&1
  rc2=$?
  wait "$rs_hold_pid"
  rc1=$?
  after=$(cksum "$D/fix10/facts/requirements/tickets/index.json" | awk '{print $1}')
  if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 1 ] && grep -q '并发冲突' "$D/locksecond.log" && [ "$before" = "$after" ]; then
    ok '正例 R1-① 持锁窗口内第二方 record_write → exit 1「并发冲突」且零写入'
  else
    bad '正例 R1-① 持锁窗口内第二方 record_write → exit 1「并发冲突」且零写入' "hold_exit=$rc1 second_exit=$rc2 lock=$([ -d "$rs_lock_dir10" ] && echo present || echo absent) before=$before after=$after $(head -n 2 "$D/locksecond.log" | tr '\n' '|')"
  fi

  # ---- 正例 R1-②：调用方持锁时令牌归属校验生效（篡改令牌后写入被拒） ----
  rs_fixture "$D/fix11"
  before=$(cksum "$D/fix11/facts/requirements/tickets/index.json" | awk '{print $1}')
  rs_lock_dir3=$(COMMON_HELPERS_DIR="$SCRIPT_DIR" sh -c '. "$1/common-helpers.sh"; record_lock_init "$2"; printf "%s" "$RECORD_LOCK_DIR"' sh "$SCRIPT_DIR" "$D/fix11")
  cat > "$D/probe-tamper.sh" <<PROBE
#!/bin/sh
set -eu
set -f
COMMON_HELPERS_DIR="$SCRIPT_DIR"
. "$SCRIPT_DIR/common-helpers.sh"
. "$SCRIPT_DIR/record-store.sh"
record_lock_ensure "\$1"
printf 'tampered\n' > "\${RECORD_LOCK_DIR}/token"
record_write "\$1" index "\$2"
PROBE
  sh "$D/probe-tamper.sh" "$D/fix11" "$D/new-index.json" >"$D/tamper.log" 2>&1
  rc=$?
  after=$(cksum "$D/fix11/facts/requirements/tickets/index.json" | awk '{print $1}')
  if [ "$rc" -eq 1 ] && grep -q '写锁归属已失效' "$D/tamper.log" && [ "$before" = "$after" ]; then
    ok '正例 R1-② 持锁后令牌被篡改 → 写点前归属校验 exit 1 且零写入'
  else
    bad '正例 R1-② 持锁后令牌被篡改 → 写点前归属校验 exit 1 且零写入' "exit=$rc before=$before after=$after $(head -n 2 "$D/tamper.log" | tr '\n' '|')"
  fi
  rm -rf "$rs_lock_dir3"

  # ---- 正例：记录写入自取写锁并在本次写入后释放（独立调用形态） ----
  rs_fixture "$D/fix7"
  rs_lock_dir=$(COMMON_HELPERS_DIR="$SCRIPT_DIR" sh -c '. "$1/common-helpers.sh"; record_lock_init "$2"; printf "%s" "$RECORD_LOCK_DIR"' sh "$SCRIPT_DIR" "$D/fix7")
  rs_probe record_write "$D/fix7" index "$D/new-index.json" >"$D/lock.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -e "$rs_lock_dir" ] && [ ! -L "$rs_lock_dir" ]; then
    ok '正例 独立调用自取记录层写锁并在本次写入后按所有权释放（锁目录零残留）'
  else
    bad '正例 独立调用自取记录层写锁并在本次写入后按所有权释放（锁目录零残留）' "exit=$rc lock=$rs_lock_dir"
  fi
}
