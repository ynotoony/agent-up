#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite merge "$@"
  exit $?
fi
# Input: 同目录 merge-ticket.sh、ticket-audit.sh、common-helpers.sh、json-validator.py；
#        夹具在 mktemp 临时目录内 git init：main 基线（票本体＋审计策略）＋票分支
#        worktree（产品提交＋已提交审查收据），作者/提交日期以环境变量固定。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；夹具全部构建于 mktemp 并 trap
#         清理，被测仓库只读零改动（合并成功路径的清场以 worktree/分支实际状态断言）。
# Pos: 合并站证据门回归（票 237）：正例 conformant 证据下 ff 合并放行并清场；actual_time
#      仅在票分支（主检出缺失）时仍放行（票体读票分支 tip）；分支 tip 含规范 Review
#      Checkpoint md 时允许集与 done 门同源放行；负例缺证据/未提交证据拒绝
#      （decision-required，worktree 与分支保留）、审查后产品又提交（P04）、head 重绑但
#      diff_sha 未重算（P05）、无绑定 worktree、主仓不干净、分支不存在与参数形态；安装
#      闭包 fast-lane 真跑（merge-ticket 与 ticket-audit 落位且与包基线字节一致）。
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

SM_ID='41-merge-fixture'
SM_BRANCH='ticket/41-merge-fixture'
SM_EVIDENCE_REL="facts/requirements/tickets/${SM_ID}.review-evidence.json"
SM_POLICY_REL='facts/requirements/audit-policy.json'

sm_commit() {
  # $1=仓库根 $2=作者邮箱 $3=UTC 时间 $4=提交信息
  git -C "$1" add -A
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=$2 GIT_AUTHOR_DATE=$3 \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=$2 GIT_COMMITTER_DATE=$3 \
    git -C "$1" -c commit.gpgsign=false commit -qm "$4"
}

sm_write_evidence() {
  # $1=仓库根 $2=base $3=head：按重算 diff 指纹写审查收据（作者身份由调用方提交时固定）
  python3 - "$1/${SM_EVIDENCE_REL}" "$2" "$3" "$1" <<'PY'
import json, subprocess, sys
path, base, head, repo = sys.argv[1:5]
diff = subprocess.run(
    ['git', '-C', repo, 'diff', '--no-color', '--no-ext-diff', '--no-textconv',
     '--binary', base, head], check=True, stdout=subprocess.PIPE).stdout
diff_sha = subprocess.run(
    ['git', '-C', repo, 'hash-object', '--stdin'], input=diff, check=True,
    stdout=subprocess.PIPE).stdout.decode().strip()
receipt = {
    'schema_version': 1,
    'receipt_kind': 'review',
    'ticket_id': '41-merge-fixture',
    'created_at': '2026-10-03T08:00:00Z',
    'actor': 'reviewer',
    'base_sha': base,
    'head_sha': head,
    'diff_sha': diff_sha,
    'reviewer_identity': 'reviewer@example.com',
    'reviewed_at': '2026-10-02T10:00:00Z',
    'verdict': 'PASS',
    'acceptance': [{'ac_id': 'AC1', 'result': 'pass', 'evidence': 'a.txt:1'}],
}
with open(path, 'w') as fh:
    fh.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
PY
}

sm_make_fixture() {
  # $1=主仓根 $2=worktree 根 [$3=证据形态：committed|uncommitted|none]
  # [$4=附加形态：actual-on-branch＝actual_time 只在票分支提交；checkpoint＝审查后提交规范 Review Checkpoint md]
  R=$1
  WT=$2
  mode=${3:-committed}
  variant=${4:-}
  rm -rf "$R" "$WT"
  mkdir -p "$R/facts/requirements/tickets"
  git -C "$R" init -q
  if [ "$variant" = 'actual-on-branch' ]; then
    cat > "$R/facts/requirements/tickets/${SM_ID}.json" <<'EOF'
{
  "id": "41-merge-fixture",
  "kind": "task",
  "title": "merge fixture",
  "created_at": "2026-10-01"
}
EOF
  elif [ "$variant" = 'checkpoint' ]; then
    cat > "$R/facts/requirements/tickets/${SM_ID}.json" <<'EOF'
{
  "id": "41-merge-fixture",
  "kind": "task",
  "title": "merge fixture",
  "created_at": "2026-10-01",
  "actual_time": "1h（fixture 净工时占位）",
  "dispatch": {
    "commit": {
      "REVIEW_PASS_CHECKPOINT": "facts/requirements/tickets/41-merge-fixture-review-checkpoint.md"
    }
  }
}
EOF
  else
    cat > "$R/facts/requirements/tickets/${SM_ID}.json" <<'EOF'
{
  "id": "41-merge-fixture",
  "kind": "task",
  "title": "merge fixture",
  "created_at": "2026-10-01",
  "actual_time": "1h（fixture 净工时占位）"
}
EOF
  fi
  printf 'seed\n' > "$R/a.txt"
  sm_commit "$R" impl@example.com '2026-10-01T00:00:00Z' 'ticket seed'
  _sm_base=$(git -C "$R" rev-parse HEAD)
  printf '{"schema_version":1,"policy_id":"merge-fixture","effective_from":"2026-10-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["impl@example.com"]}\n' \
    "$_sm_base" > "$R/${SM_POLICY_REL}"
  sm_commit "$R" impl@example.com '2026-10-01T00:00:00Z' 'audit policy'
  _sm_base2=$(git -C "$R" rev-parse HEAD)
  git -C "$R" worktree add -q -b "$SM_BRANCH" "$WT" "$_sm_base2"
  if [ "$variant" = 'actual-on-branch' ]; then
    python3 - "$WT/facts/requirements/tickets/${SM_ID}.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    body = json.load(fh)
body["actual_time"] = "1h（fixture 净工时占位）"
with open(path, "w", encoding="utf-8") as fh:
    fh.write(json.dumps(body, ensure_ascii=False, indent=2) + "\n")
PY
  fi
  printf 'product\n' >> "$WT/a.txt"
  sm_commit "$WT" impl@example.com '2026-10-02T00:00:00Z' 'product change'
  _sm_head=$(git -C "$WT" rev-parse HEAD)
  if [ "$mode" != 'none' ]; then
    sm_write_evidence "$WT" "$_sm_base2" "$_sm_head"
    if [ "$mode" = 'committed' ]; then
      sm_commit "$WT" reviewer@example.com '2026-10-03T00:00:00Z' 'review evidence'
    fi
  fi
  if [ "$variant" = 'checkpoint' ]; then
    printf '# 票 41-merge-fixture User Review Checkpoint\n\nfixture checkpoint\n' \
      > "$WT/facts/requirements/tickets/${SM_ID}-review-checkpoint.md"
    sm_commit "$WT" impl@example.com '2026-10-04T00:00:00Z' 'review checkpoint'
  fi
}

sm_run() {
  # $1=主仓根 $2=输出文件；其余参数原样传给被测脚本
  _sm_repo=$1
  _sm_out=$2
  shift 2
  sh "$SM" "$_sm_repo" "$@" > "$_sm_out" 2>&1
}

suite_merge() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='merge'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/sm
  mkdir -p "$D"
  SM="$SCRIPT_DIR/merge-ticket.sh"
  [ -r "$SM" ] || { bad 'merge-ticket.sh 在场' "缺件: $SM"; suite_summary 'merge'; return 0; }

  # ---- 正例 P1：conformant 证据 → ff 合并放行、模式与哈希打印、worktree/分支清场 ----
  sm_make_fixture "$D/p1" "$D/p1-wt" committed
  p1_tip=$(git -C "$D/p1-wt" rev-parse HEAD)
  sm_run "$D/p1" "$D/p1.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'merge-ticket: 合并成功' "$D/p1.out" \
    && grep -q '模式: fast-forward' "$D/p1.out" \
    && grep -q "合并提交: ${p1_tip}" "$D/p1.out" \
    && grep -q '证据门: ticket-audit --operation merge 允许（conformant）' "$D/p1.out" \
    && grep -q 'merge-ticket: PASS（模式 fast-forward' "$D/p1.out" \
    && [ "$(git -C "$D/p1" rev-parse HEAD)" = "$p1_tip" ] \
    && [ ! -d "$D/p1-wt" ] \
    && ! git -C "$D/p1" rev-parse --verify -q "refs/heads/$SM_BRANCH" >/dev/null 2>&1; then
    ok '正例 P1 conformant 证据 → ff 合并 exit 0、模式/哈希打印且 worktree 与分支已清场'
  else
    bad '正例 P1 conformant 证据 → ff 合并 exit 0、模式/哈希打印且 worktree 与分支已清场' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # ---- 正例 P1b：actual_time 只在票分支（主检出票体缺失该字段）→ 仍合并放行（票 237 缺陷 1）----
  sm_make_fixture "$D/p1b" "$D/p1b-wt" committed actual-on-branch
  p1b_tip=$(git -C "$D/p1b-wt" rev-parse HEAD)
  if git -C "$D/p1b" show "HEAD:facts/requirements/tickets/${SM_ID}.json" | grep -q 'actual_time'; then
    bad '正例 P1b 夹具前提：主检出票体不含 actual_time' '主检出票体意外含 actual_time'
  fi
  sm_run "$D/p1b" "$D/p1b.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'merge-ticket: PASS（模式 fast-forward' "$D/p1b.out" \
    && [ "$(git -C "$D/p1b" rev-parse HEAD)" = "$p1b_tip" ] \
    && git -C "$D/p1b" show "HEAD:facts/requirements/tickets/${SM_ID}.json" | grep -q '"actual_time"' \
    && [ ! -d "$D/p1b-wt" ]; then
    ok '正例 P1b actual_time 仅在票分支 → merge 读分支 tip exit 0、合并后票体带入 actual_time 且已清场'
  else
    bad '正例 P1b actual_time 仅在票分支 → merge 读分支 tip exit 0、合并后票体带入 actual_time 且已清场' "exit=$rc $(tail -n 3 "$D/p1b.out" | tr '\n' '|')"
  fi

  # ---- 正例 P1c：审查后仅提交规范 Review Checkpoint md → 允许集放行（票 237 缺陷 2）----
  sm_make_fixture "$D/p1c" "$D/p1c-wt" committed checkpoint
  p1c_tip=$(git -C "$D/p1c-wt" rev-parse HEAD)
  sm_run "$D/p1c" "$D/p1c.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '证据门: ticket-audit --operation merge 允许（conformant）' "$D/p1c.out" \
    && grep -q 'merge-ticket: PASS（模式 fast-forward' "$D/p1c.out" \
    && [ "$(git -C "$D/p1c" rev-parse HEAD)" = "$p1c_tip" ] \
    && git -C "$D/p1c" cat-file -e "HEAD:facts/requirements/tickets/${SM_ID}-review-checkpoint.md" 2>/dev/null \
    && [ ! -d "$D/p1c-wt" ]; then
    ok '正例 P1c 分支 tip 含合法 Review Checkpoint md → merge exit 0 放行并清场（与 done 门同源）'
  else
    bad '正例 P1c 分支 tip 含合法 Review Checkpoint md → merge exit 0 放行并清场（与 done 门同源）' "exit=$rc $(tail -n 3 "$D/p1c.out" | tr '\n' '|')"
  fi

  # ---- 负例 N1：缺证据 → decision-required，零合并、worktree/分支保留 ----
  sm_make_fixture "$D/n1" "$D/n1-wt" none
  n1_head=$(git -C "$D/n1" rev-parse HEAD)
  sm_run "$D/n1" "$D/n1.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/n1.out" \
    && grep -q 'FAIL P01 receipt-parseable:' "$D/n1.out" \
    && [ "$(git -C "$D/n1" rev-parse HEAD)" = "$n1_head" ] \
    && [ -d "$D/n1-wt" ] \
    && git -C "$D/n1" rev-parse --verify -q "refs/heads/$SM_BRANCH" >/dev/null 2>&1; then
    ok '负例 N1 缺审查证据 → exit 1 decision-required（零合并，worktree 与分支保留）'
  else
    bad '负例 N1 缺审查证据 → exit 1 decision-required（零合并，worktree 与分支保留）' "exit=$rc $(tail -n 3 "$D/n1.out" | tr '\n' '|')"
  fi

  # ---- 负例 N2：证据未提交（工作树有文件、HEAD 未跟踪）→ 拒绝 ----
  sm_make_fixture "$D/n2" "$D/n2-wt" uncommitted
  n2_head=$(git -C "$D/n2" rev-parse HEAD)
  sm_run "$D/n2" "$D/n2.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/n2.out" \
    && grep -q 'FAIL P02 evidence-committed:' "$D/n2.out" \
    && [ "$(git -C "$D/n2" rev-parse HEAD)" = "$n2_head" ] \
    && [ -d "$D/n2-wt" ]; then
    ok '负例 N2 证据未提交 → exit 1 decision-required（未合并，worktree 保留）'
  else
    bad '负例 N2 证据未提交 → exit 1 decision-required（未合并，worktree 保留）' "exit=$rc $(tail -n 3 "$D/n2.out" | tr '\n' '|')"
  fi

  # ---- 负例 N3：无绑定 worktree → 无法核证据，拒绝 ----
  sm_make_fixture "$D/n3" "$D/n3-wt" committed
  git -C "$D/n3" worktree remove "$D/n3-wt"
  sm_run "$D/n3" "$D/n3.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '无绑定 worktree' "$D/n3.out" \
    && grep -q 'decision-required' "$D/n3.out" \
    && git -C "$D/n3" rev-parse --verify -q "refs/heads/$SM_BRANCH" >/dev/null 2>&1; then
    ok '负例 N3 票分支无绑定 worktree → exit 1 decision-required（不合并、分支保留）'
  else
    bad '负例 N3 票分支无绑定 worktree → exit 1 decision-required（不合并、分支保留）' "exit=$rc $(tail -n 3 "$D/n3.out" | tr '\n' '|')"
  fi

  # ---- 负例 N4：主仓不干净 → 证据门前拒绝 ----
  sm_make_fixture "$D/n4" "$D/n4-wt" committed
  printf 'dirty\n' >> "$D/n4/a.txt"
  sm_run "$D/n4" "$D/n4.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '主仓存在未提交改动' "$D/n4.out" \
    && git -C "$D/n4" rev-parse --verify -q "refs/heads/$SM_BRANCH" >/dev/null 2>&1; then
    ok '负例 N4 主仓不干净 → exit 1 拒绝合并（分支保留）'
  else
    bad '负例 N4 主仓不干净 → exit 1 拒绝合并（分支保留）' "exit=$rc $(tail -n 3 "$D/n4.out" | tr '\n' '|')"
  fi

  # ---- 负例 N7：审查后产品又提交（证据已提交但审查边界被污染）→ P04 拒，且非 P02 ----
  sm_make_fixture "$D/n7" "$D/n7-wt" committed
  printf 'late\n' >> "$D/n7-wt/a.txt"
  sm_commit "$D/n7-wt" impl@example.com '2026-10-04T00:00:00Z' 'late product change'
  n7_head=$(git -C "$D/n7" rev-parse HEAD)
  sm_run "$D/n7" "$D/n7.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if require_out 'suite-merge 目标输出在场' "$D/n7.out" \
    && [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/n7.out" \
    && grep -q 'ticket-audit: 判定: nonconformant' "$D/n7.out" \
    && grep -q 'PASS P02 evidence-committed:' "$D/n7.out" \
    && ! grep -q 'FAIL P02 ' "$D/n7.out" \
    && grep -q 'FAIL P04 review-boundary-clean: a.txt' "$D/n7.out" \
    && [ "$(git -C "$D/n7" rev-parse HEAD)" = "$n7_head" ] \
    && [ -d "$D/n7-wt" ]; then
    ok '负例 N7 审查后产品又提交 → exit 1 decision-required 且失败点名为 P04（P02 通过，零合并）'
  else
    bad '负例 N7 审查后产品又提交 → exit 1 decision-required 且失败点名为 P04（P02 通过，零合并）' "exit=$rc $(grep -E '^(PASS P02|FAIL P0[245])' "$D/n7.out" | tr '\n' '|')"
  fi

  # ---- 负例 N7b：证据重绑到新 head 但 diff_sha 未重算（纯 P05）→ P05 拒 ----
  sm_make_fixture "$D/n7b" "$D/n7b-wt" committed
  printf 'late\n' >> "$D/n7b-wt/a.txt"
  sm_commit "$D/n7b-wt" impl@example.com '2026-10-02T12:00:00Z' 'late product change'
  n7b_tip=$(git -C "$D/n7b-wt" rev-parse HEAD)
  n7b_head=$(git -C "$D/n7b" rev-parse HEAD)
  python3 - "$D/n7b-wt/$SM_EVIDENCE_REL" "$n7b_tip" <<'PY'
import json, sys
path, head = sys.argv[1:3]
with open(path, encoding="utf-8") as fh:
    body = json.load(fh)
body["head_sha"] = head
with open(path, "w", encoding="utf-8") as fh:
    fh.write(json.dumps(body, ensure_ascii=False, indent=2) + "\n")
PY
  sm_commit "$D/n7b-wt" reviewer@example.com '2026-10-03T00:00:00Z' 'review evidence rebind'
  sm_run "$D/n7b" "$D/n7b.out" "$SM_BRANCH" "$SM_ID"
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'decision-required' "$D/n7b.out" \
    && grep -q 'PASS P02 evidence-committed:' "$D/n7b.out" \
    && grep -q 'PASS P04 review-boundary-clean:' "$D/n7b.out" \
    && grep -q 'FAIL P05 diff-sha-bound:' "$D/n7b.out" \
    && [ "$(git -C "$D/n7b" rev-parse HEAD)" = "$n7b_head" ] \
    && [ -d "$D/n7b-wt" ]; then
    ok '负例 N7b head 重绑但 diff_sha 未重算 → exit 1 且失败点名为 P05（P02/P04 通过，零合并）'
  else
    bad '负例 N7b head 重绑但 diff_sha 未重算 → exit 1 且失败点名为 P05（P02/P04 通过，零合并）' "exit=$rc $(grep -E '^(PASS P0[24]|FAIL P05)' "$D/n7b.out" | tr '\n' '|')"
  fi

  # ---- 负例 N5/N6：分支不存在 → exit 1；参数形态 → exit 2 ----
  sm_make_fixture "$D/n5" "$D/n5-wt" committed
  printf '{"id": "99-ghost", "kind": "task", "title": "ghost", "created_at": "2026-10-01", "actual_time": "1h"}\n' \
    > "$D/n5/facts/requirements/tickets/99-ghost.json"
  sm_run "$D/n5" "$D/n5.out" 'ticket/99-ghost' '99-ghost'
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '分支不存在' "$D/n5.out"; then
    ok '负例 N5 分支不存在 → exit 1 指名'
  else
    bad '负例 N5 分支不存在 → exit 1 指名' "exit=$rc $(tail -n 2 "$D/n5.out" | tr '\n' '|')"
  fi
  sh "$SM" "$D/n5" "$SM_BRANCH" > "$D/n6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N6 参数不足 → exit 2'
  else
    bad '负例 N6 参数不足 → exit 2' "exit=$rc"
  fi

  # ---- 安装闭包：fast-lane 真跑 → merge-ticket/ticket-audit 落位且与基线字节一致 ----
  if grep -q '^ip_file agent-up/scripts/merge-ticket.sh Conditional fast-lane ' "$SCRIPT_DIR/install-policy.rules" \
    && grep -q '^ip_file agent-up/scripts/ticket-audit.sh Conditional fast-lane ' "$SCRIPT_DIR/install-policy.rules"; then
    ok '安装登记正例 merge-ticket.sh 与 ticket-audit.sh 均在 install-policy fast-lane 节（AC4）'
  else
    bad '安装登记正例 merge-ticket.sh 与 ticket-audit.sh 均在 install-policy fast-lane 节（AC4）' '登记行缺失'
  fi
  if [ -f "$SCRIPT_DIR/install.sh" ]; then
    mkdir -p "$D/inst"
    sh "$SCRIPT_DIR/install.sh" --target "$D/inst" --fast-lane > "$D/inst.out" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] \
      && [ -f "$D/inst/rules/implementation/scripts/merge-ticket.sh" ] \
      && [ -f "$D/inst/rules/implementation/scripts/ticket-audit.sh" ] \
      && cmp -s "$SCRIPT_DIR/merge-ticket.sh" "$D/inst/rules/implementation/scripts/merge-ticket.sh" \
      && cmp -s "$SCRIPT_DIR/ticket-audit.sh" "$D/inst/rules/implementation/scripts/ticket-audit.sh"; then
      ok '安装闭包正例 fast-lane 真跑 → merge-ticket/ticket-audit 落位且与包基线字节一致'
    else
      bad '安装闭包正例 fast-lane 真跑 → merge-ticket/ticket-audit 落位且与包基线字节一致' "exit=$rc $(tail -n 2 "$D/inst.out" | tr '\n' '|')"
    fi
  else
    printf 'SKIP  [merge] install.sh 不在场（worktree 栅栏）——安装闭包真跑覆盖归主检出\n'
  fi

  suite_summary 'merge'
}
