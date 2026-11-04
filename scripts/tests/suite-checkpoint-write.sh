#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite checkpoint-write "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: checkpoint-write（票 229 场景沉淀：User Review Checkpoint 唯一写入方
# checkpoint-write.sh 的输入/输出契约正负例——.md 票追加票尾、.json 票落独立
# <id>-review-checkpoint.md（创建带一级标题／已存在追加记录块、票体逐字节零追加）、
# stdout 末行目标文件机器契约行；参数缺失/票文件缺失/绝对路径/父目录 symlink 逃逸/
# 日期越界 fail-closed 与未知参数、无参数用法错误；记录块格式（日期标题＋裁决原文＋裁决时间＋提交＋diff
# 摘要）与拆出前 lane-commit.sh 逐字节一致）
# ============================================================

cw_fixture() {
  # $1=夹具根：仅需 facts/requirements/tickets/ 与票文件（本件不依赖 Git）
  rm -rf "$1"
  mkdir -p "$1/facts/requirements/tickets"
}

cw_run() {
  # $1=夹具根 $2=票文件（仓库根相对） $3=输出文件；其余固定参数
  sh "$CW" "$1" review-checkpoint \
    --ticket "$2" \
    --verdict-quote 'OK（票 229 checkpoint 夹具裁决）' \
    --verdict-at '2026-10-28T10:00' \
    --commit 'abcdef1234567890' \
    --commit-subject 'fix(scope): fixture subject' \
    --diff-summary 'M a.txt' \
    --date '2026-10-28' > "$3" 2>&1
}

suite_checkpoint_write() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='checkpoint-write'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/cw
  mkdir -p "$D"
  CW="$SCRIPT_DIR/checkpoint-write.sh"

  # 正例 P1：.md 票追加票尾——原内容逐字节保留为前缀，记录块五行齐备，stdout 末行
  # 目标文件＝票文件本身（机器契约行，lance-commit 据此登记记录提交面）。
  cw_fixture "$D/p1"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '# 票 33\n\n**Status:** `in_progress`\n' > "$D/p1/facts/requirements/tickets/33-cw-ticket.md"
  cw_run "$D/p1" 'facts/requirements/tickets/33-cw-ticket.md' "$D/p1.out"
  rc=$?
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  p1_prefix=$(printf '# 票 33\n\n**Status:** `in_progress`')
  if [ "$rc" -eq 0 ] \
    && [ "$(head -n 3 "$D/p1/facts/requirements/tickets/33-cw-ticket.md")" = "$p1_prefix" ] \
    && grep -q '^## User Review Checkpoint（2026-10-28，lane-commit.sh）$' "$D/p1/facts/requirements/tickets/33-cw-ticket.md" \
    && grep -q -- '- 裁决原文：OK（票 229 checkpoint 夹具裁决）' "$D/p1/facts/requirements/tickets/33-cw-ticket.md" \
    && grep -q -- '- 裁决时间：2026-10-28T10:00' "$D/p1/facts/requirements/tickets/33-cw-ticket.md" \
    && grep -q -- '- 提交：abcdef1234567890 fix(scope): fixture subject' "$D/p1/facts/requirements/tickets/33-cw-ticket.md" \
    && grep -q -- '- diff 摘要：M a.txt' "$D/p1/facts/requirements/tickets/33-cw-ticket.md" \
    && [ "$(tail -n 1 "$D/p1.out")" = 'checkpoint-write: 目标文件: facts/requirements/tickets/33-cw-ticket.md' ]; then
    ok '正例 P1 .md 票追加票尾（原内容前缀保留＋记录块五行）且 stdout 末行目标文件契约行在场'
  else
    bad '正例 P1 .md 票追加票尾（原内容前缀保留＋记录块五行）且 stdout 末行目标文件契约行在场' "exit=$rc $(tail -n 2 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P2：.json 票体零追加，Checkpoint 落独立 <id>-review-checkpoint.md（带一级标题）。
  cw_fixture "$D/p2"
  printf '{"id": "33-cw-ticket", "title": "fixture"}\n' > "$D/p2/facts/requirements/tickets/33-cw-ticket.json"
  p2_ck0=$(cksum "$D/p2/facts/requirements/tickets/33-cw-ticket.json")
  cw_run "$D/p2" 'facts/requirements/tickets/33-cw-ticket.json' "$D/p2.out"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(cksum "$D/p2/facts/requirements/tickets/33-cw-ticket.json")" = "$p2_ck0" ] \
    && [ "$(head -n 1 "$D/p2/facts/requirements/tickets/33-cw-ticket-review-checkpoint.md")" = '# 票 33-cw-ticket User Review Checkpoint（用户即 Review 道）' ] \
    && grep -q '^## User Review Checkpoint（2026-10-28，lane-commit.sh）$' "$D/p2/facts/requirements/tickets/33-cw-ticket-review-checkpoint.md" \
    && [ "$(tail -n 1 "$D/p2.out")" = 'checkpoint-write: 目标文件: facts/requirements/tickets/33-cw-ticket-review-checkpoint.md' ]; then
    ok '正例 P2 .json 票体逐字节零追加＋独立 checkpoint md 创建（一级标题＋记录块）且目标契约行指向独立件'
  else
    bad '正例 P2 .json 票体逐字节零追加＋独立 checkpoint md 创建（一级标题＋记录块）且目标契约行指向独立件' "exit=$rc $(tail -n 2 "$D/p2.out" | tr '\n' '|')"
  fi

  # 正例 P3：同票二次写入——独立 checkpoint md 已存在则追加记录块（一级标题唯一）。
  cw_run "$D/p2" 'facts/requirements/tickets/33-cw-ticket.json' "$D/p3.out"
  rc=$?
  if [ "$rc" -eq 0 ] \
    && [ "$(grep -c '^# 票 33-cw-ticket User Review Checkpoint' "$D/p2/facts/requirements/tickets/33-cw-ticket-review-checkpoint.md")" -eq 1 ] \
    && [ "$(grep -c '^## User Review Checkpoint' "$D/p2/facts/requirements/tickets/33-cw-ticket-review-checkpoint.md")" -eq 2 ]; then
    ok '正例 P3 .json 票二次写入 → 独立 checkpoint md 追加记录块（一级标题恰 1、记录块 2）'
  else
    bad '正例 P3 .json 票二次写入 → 独立 checkpoint md 追加记录块（一级标题恰 1、记录块 2）' "exit=$rc 标题=$(grep -c '^# 票' "$D/p2/facts/requirements/tickets/33-cw-ticket-review-checkpoint.md" 2>/dev/null)"
  fi

  # 负例 N1：缺 --verdict-quote → exit 2（用法错误，零写入）
  cw_fixture "$D/n1"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '# 票\n\n**Status:** `in_progress`\n' > "$D/n1/facts/requirements/tickets/33-cw-ticket.md"
  n1_ck0=$(cksum "$D/n1/facts/requirements/tickets/33-cw-ticket.md")
  sh "$CW" "$D/n1" review-checkpoint --ticket 'facts/requirements/tickets/33-cw-ticket.md' \
    --verdict-at '2026-10-28T10:00' --commit abcdef1 --commit-subject s --diff-summary d \
    >"$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '缺少 --verdict-quote' "$D/n1.out" \
    && [ "$(cksum "$D/n1/facts/requirements/tickets/33-cw-ticket.md")" = "$n1_ck0" ]; then
    ok '负例 N1 缺 --verdict-quote → exit 2 且零写入'
  else
    bad '负例 N1 缺 --verdict-quote → exit 2 且零写入' "exit=$rc $(tail -n 2 "$D/n1.out" | tr '\n' '|')"
  fi

  # 负例 N2：票文件不存在 → exit 1 fail-closed（零写入）
  sh "$CW" "$D/n1" review-checkpoint --ticket 'facts/requirements/tickets/99-missing.md' \
    --verdict-quote OK --verdict-at '2026-10-28T10:00' --commit abcdef1 --commit-subject s \
    --diff-summary d >"$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'ticket 票文件 不存在或不是普通文件' "$D/n2.out"; then
    ok '负例 N2 票文件不存在 → exit 1 fail-closed 零写入'
  else
    bad '负例 N2 票文件不存在 → exit 1 fail-closed 零写入' "exit=$rc $(tail -n 2 "$D/n2.out" | tr '\n' '|')"
  fi

  # 负例 N3：票文件绝对路径 → exit 1（路径边界，写入前拒绝）
  sh "$CW" "$D/n1" review-checkpoint --ticket "$D/n1/facts/requirements/tickets/33-cw-ticket.md" \
    --verdict-quote OK --verdict-at '2026-10-28T10:00' --commit abcdef1 --commit-subject s \
    --diff-summary d >"$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '须为仓库根相对路径' "$D/n3.out"; then
    ok '负例 N3 票文件绝对路径 → exit 1 路径边界拒绝零写入'
  else
    bad '负例 N3 票文件绝对路径 → exit 1 路径边界拒绝零写入' "exit=$rc $(tail -n 2 "$D/n3.out" | tr '\n' '|')"
  fi

  # 负例 N4：--date 非 YYYY-MM-DD → exit 1（零写入）
  sh "$CW" "$D/n1" review-checkpoint --ticket 'facts/requirements/tickets/33-cw-ticket.md' \
    --verdict-quote OK --verdict-at '2026-10-28T10:00' --commit abcdef1 --commit-subject s \
    --diff-summary d --date '2026/10/28' >"$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '记录块日期不合 YYYY-MM-DD 口径' "$D/n4.out" \
    && [ "$(cksum "$D/n1/facts/requirements/tickets/33-cw-ticket.md")" = "$n1_ck0" ]; then
    ok '负例 N4 --date 越界 → exit 1 且零写入'
  else
    bad '负例 N4 --date 越界 → exit 1 且零写入' "exit=$rc $(tail -n 2 "$D/n4.out" | tr '\n' '|')"
  fi

  # 负例 N5：未知参数 → exit 2（用法错误）
  sh "$CW" "$D/n1" review-checkpoint --ticket 'facts/requirements/tickets/33-cw-ticket.md' \
    --verdict-quote OK --verdict-at '2026-10-28T10:00' --commit abcdef1 --commit-subject s \
    --diff-summary d --bogus x >"$D/n5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '未知参数' "$D/n5.out"; then
    ok '负例 N5 未知参数 → exit 2（用法错误）'
  else
    bad '负例 N5 未知参数 → exit 2（用法错误）' "exit=$rc $(tail -n 2 "$D/n5.out" | tr '\n' '|')"
  fi

  # 负例 N6：无参数 → exit 2（用法错误）
  sh "$CW" >"$D/n6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '用法: sh checkpoint-write.sh' "$D/n6.out"; then
    ok '负例 N6 无参数 → exit 2 打印用法'
  else
    bad '负例 N6 无参数 → exit 2 打印用法' "exit=$rc $(tail -n 2 "$D/n6.out" | tr '\n' '|')"
  fi

  # 负例 N7：子命令未知 → exit 2（拒绝静默按 review-checkpoint 处理）
  sh "$CW" "$D/n1" unknown-cmd --ticket x >"$D/n7.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N7 未知子命令 → exit 2'
  else
    bad '负例 N7 未知子命令 → exit 2' "exit=$rc $(tail -n 2 "$D/n7.out" | tr '\n' '|')"
  fi

  # 负例 N8：票文件父目录 symlink 指向仓外 → realpath containment 拒绝且仓外票体零写入
  cw_fixture "$D/n8"
  mkdir -p "$D/n8-outside"
  printf '# 票\n' > "$D/n8-outside/33-cw-ticket.md"
  rmdir "$D/n8/facts/requirements/tickets"
  ln -s "$D/n8-outside" "$D/n8/facts/requirements/tickets"
  n8_ck0=$(cksum "$D/n8-outside/33-cw-ticket.md")
  cw_run "$D/n8" 'facts/requirements/tickets/33-cw-ticket.md' "$D/n8.out"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '越出仓库根' "$D/n8.out" \
    && [ "$(cksum "$D/n8-outside/33-cw-ticket.md")" = "$n8_ck0" ]; then
    ok '负例 N8 票文件父目录 symlink 逃逸 → exit 1 且仓外零写入'
  else
    bad '负例 N8 票文件父目录 symlink 逃逸 → exit 1 且仓外零写入' "exit=$rc $(tail -n 2 "$D/n8.out" | tr '\n' '|')"
  fi

  suite_summary 'checkpoint-write'
}
