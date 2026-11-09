#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite evidence-rebind "$@"
  exit $?
fi
# Input: 同目录 evidence-rebind.sh、ledger-append.sh、record-store.sh、common-helpers.sh、
#        json-validator.py；夹具在 mktemp 临时目录内 git init（票分支工作树形态：审查收据
#        review-evidence.json＋同票 cp md＋changes.jsonl 基线），作者/日期固定。
# Output: 逐项 PASS/FAIL 行与计数汇总；夹具全部 mktemp 并 trap 清理，真实仓库零写入。
# Pos: 审查证据重绑授权面回归（票 288 AC3）：显式授权正例（json 三 sha 重写、cp md 同步、
#      账本留痕行、reviewer 身份提交）＋负例（缺授权/空授权 fail-closed 零改写、非法 sha
#      用法错、证据缺失拒绝）——证明未授权路径 fail-closed 且授权后留痕可追溯。
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（单文件视野误报）

suite_evidence_rebind() {
  CUR_SUITE='evidence-rebind'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/erb
  mkdir -p "$D"
  ER="$SCRIPT_DIR/evidence-rebind.sh"
  ER_ID='41-er-fixture'
  ER_EV_REL="facts/requirements/tickets/${ER_ID}.review-evidence.json"
  ER_CP_REL="facts/requirements/tickets/${ER_ID}-review-checkpoint.md"
  [ -r "$ER" ] || { bad 'evidence-rebind.sh 在场' "缺件: $ER"; suite_summary 'evidence-rebind'; return 0; }

  er_commit() {
    # $1=仓库根 $2=作者邮箱 $3=提交信息
    git -C "$1" add -A
    GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=$2 GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=$2 \
      git -C "$1" -c commit.gpgsign=false commit -qm "$3"
  }

  er_fixture() {
    # $1=仓库根：种子提交 → 产品提交（证据绑定 base=seed head=product）→ cp md 描述旧 sha
    R=$1
    rm -rf "$R"
    mkdir -p "$R/facts/requirements/tickets" "$R/facts/project"
    printf 'product line\n' > "$R/a.txt"
    printf '%s\n' '{"date":"2026-10-01","kind":"change","scope":"41","decision":"fixture seed","evidence_ref":"facts/requirements/tickets/41-er-fixture.json"}' > "$R/facts/project/changes.jsonl"
    git_repo "$R"
    er_commit "$R" impl@example.com 'ticket seed'
    er_base=$(git -C "$R" rev-parse HEAD)
    printf 'product v2\n' >> "$R/a.txt"
    er_commit "$R" impl@example.com 'product change'
    er_head=$(git -C "$R" rev-parse HEAD)
    receipt "$R/$ER_EV_REL" "$R" "$er_base" "$er_head" "$ER_ID" \
      --created-at '2026-10-03T08:00:00Z' --reviewed-at '2026-10-02T10:00:00Z'
    er_old_diff=$(python3 "$SCRIPT_DIR/json-validator.py" json get "$R/$ER_EV_REL" diff_sha)
    er_old_base_s=$(printf '%s' "$er_base" | cut -c1-7)
    er_old_head_s=$(printf '%s' "$er_head" | cut -c1-7)
    er_old_diff_s=$(printf '%s' "$er_old_diff" | cut -c1-7)
    {
      printf '# 票 %s User Review Checkpoint\n\n' "$ER_ID"
      printf 'base %s（%s）\n' "$er_base" "$er_old_base_s"
      printf 'head %s（%s）\n' "$er_head" "$er_old_head_s"
      printf 'diff %s（%s）\n' "$er_old_diff" "$er_old_diff_s"
    } > "$R/$ER_CP_REL"
    er_commit "$R" reviewer@example.com 'review evidence'
  }

  er_ev_get() { python3 "$SCRIPT_DIR/json-validator.py" json get "$1/$ER_EV_REL" "$2" 2>/dev/null || true; }

  # N1：缺 --authorize → exit 1 fail-closed，零改写零提交（证据与 HEAD 前后一致）。
  er_fixture "$D/n1"
  n1_head=$(git -C "$D/n1" rev-parse HEAD)
  n1_ev=$(cksum "$D/n1/$ER_EV_REL")
  sh "$ER" "$D/n1" "$ER_ID" "$(git -C "$D/n1" rev-parse HEAD~2)" "$(git -C "$D/n1" rev-parse HEAD~1)" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '未显式授权' "$D/n1.out" \
    && [ "$(git -C "$D/n1" rev-parse HEAD)" = "$n1_head" ] \
    && [ "$(cksum "$D/n1/$ER_EV_REL")" = "$n1_ev" ]; then
    ok '负例 ERB-N1 缺 --authorize → exit 1 fail-closed（零改写、零提交，不静默改写证据）'
  else
    bad '负例 ERB-N1 缺 --authorize → exit 1 fail-closed（零改写、零提交，不静默改写证据）' "exit=$rc $(tail -n 2 "$D/n1.out" | tr '\n' '|')"
  fi

  # N2：--authorize 空串 → exit 1 fail-closed，零改写零提交。
  er_fixture "$D/n2"
  n2_head=$(git -C "$D/n2" rev-parse HEAD)
  n2_ev=$(cksum "$D/n2/$ER_EV_REL")
  sh "$ER" --authorize '' "$D/n2" "$ER_ID" "$(git -C "$D/n2" rev-parse HEAD~2)" "$(git -C "$D/n2" rev-parse HEAD~1)" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '未显式授权' "$D/n2.out" \
    && [ "$(git -C "$D/n2" rev-parse HEAD)" = "$n2_head" ] \
    && [ "$(cksum "$D/n2/$ER_EV_REL")" = "$n2_ev" ]; then
    ok '负例 ERB-N2 授权依据为空 → exit 1 fail-closed（零改写、零提交）'
  else
    bad '负例 ERB-N2 授权依据为空 → exit 1 fail-closed（零改写、零提交）' "exit=$rc $(tail -n 2 "$D/n2.out" | tr '\n' '|')"
  fi

  # N3：新 sha 形态非法 → exit 2（用法/环境错误），零改写零提交。
  er_fixture "$D/n3"
  n3_head=$(git -C "$D/n3" rev-parse HEAD)
  sh "$ER" --authorize 'fixture 授权' "$D/n3" "$ER_ID" 'not-a-sha' "$(git -C "$D/n3" rev-parse HEAD~1)" > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -Fq '提交号形态不合' "$D/n3.out" \
    && [ "$(git -C "$D/n3" rev-parse HEAD)" = "$n3_head" ]; then
    ok '负例 ERB-N3 新提交号形态非法 → exit 2（零改写、零提交）'
  else
    bad '负例 ERB-N3 新提交号形态非法 → exit 2（零改写、零提交）' "exit=$rc $(tail -n 2 "$D/n3.out" | tr '\n' '|')"
  fi

  # N4：证据文件缺失 → exit 1 指名拒绝，零提交。
  er_fixture "$D/n4"
  rm -f "$D/n4/$ER_EV_REL"
  n4_head=$(git -C "$D/n4" rev-parse HEAD)
  sh "$ER" --authorize 'fixture 授权' "$D/n4" "$ER_ID" "$(git -C "$D/n4" rev-parse HEAD~2)" "$(git -C "$D/n4" rev-parse HEAD~1)" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -Fq '审查证据文件缺失' "$D/n4.out" \
    && [ "$(git -C "$D/n4" rev-parse HEAD)" = "$n4_head" ]; then
    ok '负例 ERB-N4 证据文件缺失 → exit 1 指名拒绝、零提交'
  else
    bad '负例 ERB-N4 证据文件缺失 → exit 1 指名拒绝、零提交' "exit=$rc $(tail -n 2 "$D/n4.out" | tr '\n' '|')"
  fi

  # P1：显式授权 → 三 sha 重写＋cp md 同步＋账本留痕＋reviewer 身份提交，exit 0。
  er_fixture "$D/p1"
  p1_new_base=$(git -C "$D/p1" rev-parse HEAD~2)
  p1_old_base=$(er_ev_get "$D/p1" base_sha)
  p1_old_head=$(er_ev_get "$D/p1" head_sha)
  p1_old_diff=$(er_ev_get "$D/p1" diff_sha)
  printf 'rebased product\n' >> "$D/p1/a.txt"
  er_commit "$D/p1" impl@example.com 'rebased product change'
  p1_new_head=$(git -C "$D/p1" rev-parse HEAD)
  p1_head_before=$(git -C "$D/p1" rev-parse HEAD)
  p1_expect_diff=$(git -C "$D/p1" diff --binary "$p1_new_base" "$p1_new_head" | git -C "$D/p1" hash-object --stdin)
  sh "$ER" --authorize 'fixture 授权：rebase 后重绑' "$D/p1" "$ER_ID" "$p1_new_base" "$p1_new_head" > "$D/p1.out" 2>&1
  rc=$?
  p1_base=$(er_ev_get "$D/p1" base_sha)
  p1_head=$(er_ev_get "$D/p1" head_sha)
  p1_diff=$(er_ev_get "$D/p1" diff_sha)
  p1_subject=$(git -C "$D/p1" log -1 --format=%s HEAD)
  p1_email=$(git -C "$D/p1" log -1 --format=%ae HEAD)
  if [ "$rc" -eq 0 ] \
    && [ "$p1_base" = "$p1_new_base" ] && [ "$p1_head" = "$p1_new_head" ] \
    && [ "$p1_diff" = "$p1_expect_diff" ] \
    && grep -q "$p1_new_head" "$D/p1/$ER_CP_REL" && grep -q "$p1_expect_diff" "$D/p1/$ER_CP_REL" \
    && ! grep -q "$p1_old_head" "$D/p1/$ER_CP_REL" \
    && grep -q '"kind":"rebind"' "$D/p1/facts/project/changes.jsonl" \
    && grep -q '审查证据复绑授权：fixture 授权：rebase 后重绑' "$D/p1/facts/project/changes.jsonl" \
    && [ "$p1_subject" = 'chore(records): 审查证据复绑至 rebase 后 HEAD' ] \
    && [ "$p1_email" = 'reviewer@example.com' ] \
    && grep -q '^evidence-rebind: 授权: fixture 授权：rebase 后重绑$' "$D/p1.out" \
    && grep -q '^evidence-rebind: 账本: facts/project/changes.jsonl' "$D/p1.out" \
    && [ "$(git -C "$D/p1" rev-parse HEAD)" != "$p1_head_before" ]; then
    ok '正例 ERB-P1 显式授权 → base/head/diff 重写＋cp md 同步＋账本留痕＋reviewer 身份提交（exit 0）'
  else
    bad '正例 ERB-P1 显式授权 → base/head/diff 重写＋cp md 同步＋账本留痕＋reviewer 身份提交（exit 0）' \
      "exit=$rc base=$p1_base/$p1_new_base head=$p1_head/$p1_new_head diff_ok=$([ "$p1_diff" = "$p1_expect_diff" ] && echo y || echo n) subject=$p1_subject email=$p1_email old_base=$p1_old_base old_head=$p1_old_head old_diff=$p1_old_diff $(tail -n 2 "$D/p1.out" | tr '\n' '|')"
  fi

  suite_summary 'evidence-rebind'
}
