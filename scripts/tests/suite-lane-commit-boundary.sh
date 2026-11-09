#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite lane-commit-boundary "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: lane-commit-boundary（票 291 自 suite-lane-commit 拆出的写入面路径边界能力面）：
# 票 144 边界矩阵——whitelist/flips/ticket 三类写入面的 ../ 跳段、绝对路径、仓外
# symlink（realpath containment）与仓内 symlink 自身均写入前 exit 1；负例统一零提交
# 零写入零仓外副作用；末位合法回归正例。

suite_lane_commit_boundary() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='lane-commit-boundary'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/lcb
  mkdir -p "$D"
  LC="$SCRIPT_DIR/lane-commit.sh"

  # ---- 票 144 断言：写入面路径边界（whitelist/flips/ticket 须仓库根内普通相对文件）----
  # 边界矩阵：../ 向上跳段／绝对路径／symlink 指向仓外（realpath containment，macOS
  # /tmp → /private/tmp 规格化歧义同口径拦出）／仓内 symlink 自身——均写入前 exit 1；
  # flips 目标与 ticket 票文件走同款 lc_in_repo 校验各一负例；负例统一零提交零写入零
  # 仓外副作用（夹具外哨兵文件内容＋仓库工作树结构/内容指纹前后不变）；末位合法回归
  # 正例（symlink 在场语境合法相对路径照旧收口，AC 零回归）。
  lc_build_fixture "$D/bm"
  printf 'outside-sentinel\n' > "$D/bm-outside-sentinel.txt"
  ln -s "$D/bm-outside-sentinel.txt" "$D/bm/outside-link.txt"
  ln -s 'a.txt' "$D/bm/inside-link.txt"
  lc_git_commit "$D/bm"
  printf 'change\n' > "$D/bm/a.txt"
  bm_n0=$(git -C "$D/bm" rev-list --count HEAD)
  bm_ls0=$(cd "$D/bm" && find . -name .git -prune -o -print | LC_ALL=C sort | cksum)
  bm_ck0=$(cd "$D/bm" && find . -name .git -prune -o -type f -print | LC_ALL=C sort | xargs cksum | cksum)
  bm_sent0=$(cksum "$D/bm-outside-sentinel.txt")

  {
    printf 'lane: micro\n'
    printf 'whitelist: ../bm-outside-sentinel.txt\n'
    printf 'message: escape dotdot\n'
    printf 'verify: true\n'
  } > "$D/bm-a.contract"
  sh "$LC" "$D/bm" "$D/bm-a.contract" >"$D/bm-a.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得含 .. 或 ./ 路径段' "$D/bm-a.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144a whitelist 含 ..（../ 向上跳段）→ exit 1 报文本层违规且零提交（票 144）'
  else
    bad '负例 N-144a whitelist 含 ..（../ 向上跳段）→ exit 1 报文本层违规且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-a.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: /tmp/lc144-nonexistent-outside\n'
    printf 'message: escape absolute\n'
    printf 'verify: true\n'
  } > "$D/bm-b.contract"
  sh "$LC" "$D/bm" "$D/bm-b.contract" >"$D/bm-b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得为绝对路径' "$D/bm-b.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144b whitelist 绝对路径 → exit 1 报文本层违规且零提交（票 144）'
  else
    bad '负例 N-144b whitelist 绝对路径 → exit 1 报文本层违规且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-b.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: outside-link.txt\n'
    printf 'message: escape symlink\n'
    printf 'verify: true\n'
  } > "$D/bm-c.contract"
  sh "$LC" "$D/bm" "$D/bm-c.contract" >"$D/bm-c.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '越出仓库根（realpath containment 失败）' "$D/bm-c.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144c whitelist symlink 指向仓外 → exit 1 realpath containment 拦出且零提交（票 144）'
  else
    bad '负例 N-144c whitelist symlink 指向仓外 → exit 1 realpath containment 拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-c.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: inside-link.txt\n'
    printf 'message: inside symlink\n'
    printf 'verify: true\n'
  } > "$D/bm-d.contract"
  sh "$LC" "$D/bm" "$D/bm-d.contract" >"$D/bm-d.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不得为 symlink' "$D/bm-d.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144d whitelist 仓内 symlink 自身 → exit 1 形态层拦出且零提交（票 144：仅普通文件）'
  else
    bad '负例 N-144d whitelist 仓内 symlink 自身 → exit 1 形态层拦出且零提交（票 144：仅普通文件）' "exit=$rc $(tail -n 2 "$D/bm-d.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: micro\n'
    printf 'whitelist: a.txt\n'
    printf 'message: flips escape\n'
    printf 'verify: true\n'
    printf 'flips: outside-link.txt:note:hello\n'
  } > "$D/bm-e.contract"
  sh "$LC" "$D/bm" "$D/bm-e.contract" >"$D/bm-e.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'flips 目标路径边界校验未通过' "$D/bm-e.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144e flips 目标 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）'
  else
    bad '负例 N-144e flips 目标 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-e.out" | tr '\n' '|')"
  fi

  {
    printf 'lane: user-review\n'
    printf 'ticket: outside-link.txt\n'
    printf 'whitelist: a.txt\n'
    printf 'message: ticket escape\n'
    printf 'verify: true\n'
    printf 'verdict_quote: OK\n'
    printf 'verdict_at: 2026-10-15T12:00\n'
  } > "$D/bm-f.contract"
  sh "$LC" "$D/bm" "$D/bm-f.contract" >"$D/bm-f.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'ticket 票文件 越出仓库根' "$D/bm-f.out" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$bm_n0" ]; then
    ok '负例 N-144f ticket 票文件 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）'
  else
    bad '负例 N-144f ticket 票文件 symlink 指向仓外 → exit 1 边界校验拦出且零提交（票 144）' "exit=$rc $(tail -n 2 "$D/bm-f.out" | tr '\n' '|')"
  fi

  # 负例副作用核验（票 144 AC3）：全部负例后——仓外哨兵文件内容不变、仓库工作树
  # 结构（文件名集）与内容（逐文件 cksum 链）指纹均与负例前基线全等。
  if [ "$(cksum "$D/bm-outside-sentinel.txt")" = "$bm_sent0" ] \
    && [ "$(cd "$D/bm" && find . -name .git -prune -o -print | LC_ALL=C sort | cksum)" = "$bm_ls0" ] \
    && [ "$(cd "$D/bm" && find . -name .git -prune -o -type f -print | LC_ALL=C sort | xargs cksum | cksum)" = "$bm_ck0" ]; then
    ok '负例副作用核验 仓外哨兵内容＋仓库工作树结构/内容指纹负例前后全等（票 144 AC3 零仓外副作用）'
  else
    bad '负例副作用核验 仓外哨兵内容＋仓库工作树结构/内容指纹负例前后全等（票 144 AC3 零仓外副作用）' '哨兵 cksum 或仓库指纹漂移'
  fi

  # 正例 P-144：合法仓内相对路径零回归——symlink 在场语境（同夹具）micro 合同照旧
  # 两段式收口 exit 0 且微账本落行（AC：合法目标行为不变）。负例段 lc_git_commit 已把
  # a.txt 既有改动入库，此处再造已跟踪文件改动供产品提交承载。
  printf 'change-144\n' > "$D/bm/a.txt"
  lc_contract "$D/bm-p.contract" '30m（票 144 合法回归占位）'
  sh "$LC" "$D/bm" "$D/bm-p.contract" >"$D/bm-p.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"actual": "30m（票 144 合法回归占位）"' "$D/bm/facts/project/micro.jsonl" \
    && [ "$(git -C "$D/bm" rev-list --count HEAD)" -eq "$((bm_n0 + 2))" ]; then
    ok '正例 P-144 symlink 在场语境合法相对路径 micro 全链 → exit 0 两段提交＋微账本落行（票 144 零回归）'
  else
    bad '正例 P-144 symlink 在场语境合法相对路径 micro 全链 → exit 0 两段提交＋微账本落行（票 144 零回归）' "exit=$rc $(tail -n 3 "$D/bm-p.out" | tr '\n' '|')"
  fi

  suite_summary 'lane-commit-boundary'
}
