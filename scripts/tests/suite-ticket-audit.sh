#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite ticket-audit "$@"
  exit $?
fi
# Input: 同目录 ticket-audit.sh 与 shared-helpers（test-helpers.sh）；夹具在 mktemp 临时
#        目录内 git init（票文件＋审计策略＋产品提交＋已提交审查收据），作者/提交日期
#        以环境变量固定，收据字段经唯一 JSON 引擎改写以分离单一谓词。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；夹具全部构建于 mktemp 并 trap
#         清理，被测仓库只读零改动（零写入断言以 cksum 与 HEAD 前后比对承载）。
# Pos: 记录层回归 harness 的 ticket-audit 套件（十一谓词正负例）：正例断言 conformant
#      与证据位置可追溯，负例逐条分离 P01～P11 的失败/未知分支与操作面窗口。
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: ticket-audit（证据绑定与最小 Git 审计）
# 覆盖：正例三面（analyze/read/merge 全 conformant、十一谓词逐行 PASS、证据位置
# 路径@提交:blob 与 git log/rev-parse 逐一相等）；负例按谓词分离——P01 不可解析/
# 非 review 收据/票号不匹配、P02 提交后又改动与未提交（HEAD 未跟踪）、P03 base 不可解析、P04 证据之后
# 混入产品改动与 head 非祖先、P05 diff 指纹篡改、P09 旧 PASS 与时间越界、P10
# 自由文本 verdict/FAIL verdict/非 pass 验收、P08 自签与策略实现者名单命中；
# 未知分支——P07 身份不可佐证与不在可信名单、P11 策略缺失/非法/不适用/标签缺失
# （analyze exit 0 且 merge exit 1）；用法与环境错误 exit 2；一次审计零写入。
# ============================================================

TA_EVIDENCE_REL='facts/requirements/tickets/07-fixture.review-evidence.json'
TA_POLICY_REL='facts/requirements/audit-policy.json'

ta_commit_all() {
  # $1=夹具仓根 $2=作者邮箱 $3=UTC 时间 $4=提交信息
  git -C "$1" add -A
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=$2 GIT_AUTHOR_DATE=$3 \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=$2 GIT_COMMITTER_DATE=$3 \
    git -C "$1" -c commit.gpgsign=false commit -qm "$4"
}

ta_amend_author() {
  # $1=夹具仓根 $2=新作者邮箱 $3=UTC 时间：改写 HEAD 提交作者身份（树与提交信息不变）
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=$2 GIT_AUTHOR_DATE=$3 \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=$2 GIT_COMMITTER_DATE=$3 \
    git -C "$1" -c commit.gpgsign=false commit -q --amend --no-edit --reset-author
}

ta_write_evidence() {
  # $1=夹具仓根：按 .base/.head 文件写审查收据（多行 JSON，字段行号可定位）
  python3 - "$1/${TA_EVIDENCE_REL}" "$(cat "$1.base")" "$(cat "$1.head")" "$1" <<'PY'
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
    'ticket_id': '07-fixture',
    'created_at': '2026-10-03T08:00:00Z',
    'actor': 'reviewer',
    'base_sha': base,
    'head_sha': head,
    'diff_sha': diff_sha,
    'reviewer_identity': 'reviewer@example.com',
    'reviewed_at': '2026-10-03T08:00:00Z',
    'verdict': 'PASS',
    'acceptance': [{'ac_id': 'AC1', 'result': 'pass', 'evidence': 'a.txt:1'}],
}
with open(path, 'w') as fh:
    fh.write(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
PY
}

ta_make_fixture() {
  # $1=夹具仓根 [$2=策略补丁「点路径=JSON 字面量」，多条以 ; 分隔，在策略提交前合并]
  # 时序：C0 票种子 → C1 策略 → C2 产品提交 → C3 审查收据（基点/头写入 $1.base/$1.head）
  _ta_d=$1
  _ta_patch=${2:-}
  rm -rf "$_ta_d" "$_ta_d.base" "$_ta_d.head"
  mkdir -p "$_ta_d/facts/requirements/tickets"
  git -C "$_ta_d" init -q
  printf 'seed\n' > "$_ta_d/a.txt"
  printf '{"id":"07-fixture","kind":"task","title":"fixture","created_at":"2026-10-01T00:00:00Z"}\n' \
    > "$_ta_d/facts/requirements/tickets/07-fixture.json"
  ta_commit_all "$_ta_d" impl@example.com '2026-10-01T00:00:00Z' 'ticket seed'
  _ta_base=$(git -C "$_ta_d" rev-parse HEAD)
  printf '{"schema_version":1,"policy_id":"fixture-policy","effective_from":"2026-10-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["impl@example.com"]}\n' \
    "$_ta_base" > "$_ta_d/${TA_POLICY_REL}"
  if [ -n "$_ta_patch" ]; then
    _ta_ifs=$IFS
    IFS=';'
    for _ta_one in $_ta_patch; do
      IFS=$_ta_ifs
      ta_set_path "$_ta_d/${TA_POLICY_REL}" "${_ta_one%%=*}" "${_ta_one#*=}"
    done
    IFS=$_ta_ifs
  fi
  ta_commit_all "$_ta_d" impl@example.com '2026-10-01T00:00:00Z' 'audit policy'
  printf 'product\n' >> "$_ta_d/a.txt"
  ta_commit_all "$_ta_d" impl@example.com '2026-10-02T00:00:00Z' 'product change'
  _ta_head=$(git -C "$_ta_d" rev-parse HEAD)
  printf '%s\n' "$_ta_base" > "$_ta_d.base"
  printf '%s\n' "$_ta_head" > "$_ta_d.head"
  ta_write_evidence "$_ta_d"
  ta_commit_all "$_ta_d" reviewer@example.com '2026-10-03T00:00:00Z' 'review evidence'
}

ta_set_path() {
  # $1=JSON 文件 $2=点路径（列表用数字段） $3=JSON 字面量
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
path, dotted, literal = sys.argv[1:4]
with open(path) as fh:
    data = json.load(fh)
node = data
parts = dotted.split('.')
for part in parts[:-1]:
    node = node[int(part)] if isinstance(node, list) else node[part]
last = parts[-1]
if isinstance(node, list):
    node[int(last)] = json.loads(literal)
else:
    node[last] = json.loads(literal)
with open(path, 'w') as fh:
    fh.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
}

ta_run() {
  # $1=夹具仓根 $2=输出文件；其余参数原样传给被测引擎
  _ta_repo=$1
  _ta_out=$2
  shift 2
  sh "$TA" 07 --repo "$_ta_repo" "$@" > "$_ta_out" 2>&1
}

ta_expect() {
  # $1=场景名 $2=实际退出码 $3=期望退出码 $4=输出文件；其余为须在场的整行子串
  _te_name=$1
  _te_rc=$2
  _te_want=$3
  _te_out=$4
  shift 4
  if [ "$_te_rc" -ne "$_te_want" ]; then
    bad "$_te_name" "exit=$_te_rc 期望=$_te_want"
    return 0
  fi
  for _te_pat in "$@"; do
    if ! grep -qF -- "$_te_pat" "$_te_out"; then
      bad "$_te_name" "缺行: $_te_pat"
      return 0
    fi
  done
  ok "$_te_name"
}

suite_ticket_audit() {
  CUR_SUITE='ticket-audit'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/ta
  mkdir -p "$D"
  TA="$SCRIPT_DIR/ticket-audit.sh"
  [ -r "$TA" ] || { bad 'ticket-audit.sh 在场' "缺件: $TA"; suite_summary 'ticket-audit'; return 0; }

  # ---- 正例 P1：analyze 全 conformant，十一谓词逐行 PASS，证据位置可追溯 ----

  ta_make_fixture "$D/p1"
  ta_run "$D/p1" "$D/p1.out"
  rc=$?
  ta_expect '正例 P1 analyze → exit 0 且判定 conformant' "$rc" 0 "$D/p1.out" 'ticket-audit: 判定: conformant'
  p1_n=$(grep -c '^PASS P' "$D/p1.out")
  if [ "$p1_n" -eq 11 ] && [ "$(grep -c '^FAIL\|^UNKNOWN' "$D/p1.out")" -eq 0 ]; then
    ok '正例 P1 十一谓词逐行 PASS（P01～P11 齐，无 FAIL/UNKNOWN 行）'
  else
    bad '正例 P1 十一谓词逐行 PASS（P01～P11 齐，无 FAIL/UNKNOWN 行）' "PASS 行=$p1_n"
  fi
  _want_commit=$(git -C "$D/p1" log -1 --format=%H -- "$TA_EVIDENCE_REL")
  _want_blob=$(git -C "$D/p1" rev-parse "HEAD:$TA_EVIDENCE_REL")
  ta_expect '正例 P1 证据位置可回溯到提交与 blob（AC3）' 0 0 "$D/p1.out" \
    "ticket-audit: 证据位置: ${TA_EVIDENCE_REL}@${_want_commit}:${_want_blob}"

  # ---- 正例 P2/P3：read 与 merge 同判 conformant 允许 ----

  ta_run "$D/p1" "$D/p2.out" --operation read
  rc=$?
  ta_expect '正例 P2 read → exit 0 且操作面允许' "$rc" 0 "$D/p2.out" \
    'ticket-audit: 操作面: read 允许'
  ta_run "$D/p1" "$D/p3.out" --operation merge
  rc=$?
  ta_expect '正例 P3 merge（证据 conformant）→ exit 0 允许' "$rc" 0 "$D/p3.out" \
    'ticket-audit: 操作面: merge 允许'

  # ---- 正例 P4：--help 零副作用 ----

  sh "$TA" --help > "$D/help.out" 2>&1
  rc=$?
  ta_expect '正例 P4 --help → exit 0 且打印用法' "$rc" 0 "$D/help.out" '用法: sh ticket-audit.sh'

  # ---- 负例 N1：证据提交后又改工作树（合法 JSON）→ P02 ----

  ta_make_fixture "$D/n1"
  ta_set_path "$D/n1/$TA_EVIDENCE_REL" actor '"someone-else"'
  ta_run "$D/n1" "$D/n1.out"
  rc=$?
  ta_expect '负例 N1 证据提交后又改动 → exit 1 且 P02 指名' "$rc" 1 "$D/n1.out" \
    'FAIL P02 evidence-committed:' '工作树内容与 HEAD blob 不一致' 'ticket-audit: 判定: nonconformant'

  # ---- 负例 N1b：证据文件在，但从未提交（HEAD 不跟踪）→ P02 ----

  ta_make_fixture "$D/n1b"
  git -C "$D/n1b" rm -q --cached "$TA_EVIDENCE_REL"
  _n1b_new=$(GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=reviewer@example.com \
    GIT_AUTHOR_DATE='2026-10-04T00:00:00Z' GIT_COMMITTER_NAME=fixture \
    GIT_COMMITTER_EMAIL=reviewer@example.com GIT_COMMITTER_DATE='2026-10-04T00:00:00Z' \
    git -C "$D/n1b" -c commit.gpgsign=false commit-tree \
    "$(git -C "$D/n1b" write-tree)" -p HEAD -m 'drop evidence from history')
  git -C "$D/n1b" update-ref HEAD "$_n1b_new"
  ta_run "$D/n1b" "$D/n1b.out"
  rc=$?
  ta_expect '负例 N1b 证据未提交（HEAD 未跟踪）→ exit 1 且 P02 指名' "$rc" 1 "$D/n1b.out" \
    'FAIL P02 evidence-committed:' '证据未被 HEAD 跟踪' 'ticket-audit: 判定: nonconformant'

  # ---- 负例 N2：证据之后混入产品提交 → P04 指名越界路径 ----

  ta_make_fixture "$D/n2"
  printf 'late\n' > "$D/n2/b.txt"
  ta_commit_all "$D/n2" impl@example.com '2026-10-04T00:00:00Z' 'late product change'
  ta_run "$D/n2" "$D/n2.out"
  rc=$?
  ta_expect '负例 N2 证据后混入产品改动 → exit 1 且 P04 指名 b.txt' "$rc" 1 "$D/n2.out" \
    'FAIL P04 review-boundary-clean: b.txt:1'

  # ---- 负例 N3：diff_sha 篡改并提交 → P05（行号＝diff_sha 行） ----

  ta_make_fixture "$D/n3"
  _dline=$(grep -n -F '"diff_sha"' "$D/n3/$TA_EVIDENCE_REL" | head -n 1 | cut -d: -f1)
  ta_set_path "$D/n3/$TA_EVIDENCE_REL" diff_sha '"0000000000000000000000000000000000000000"'
  ta_commit_all "$D/n3" reviewer@example.com '2026-10-03T00:00:00Z' 'tampered diff'
  ta_run "$D/n3" "$D/n3.out"
  rc=$?
  ta_expect '负例 N3 diff 指纹篡改 → exit 1 且 P05 按行号指名' "$rc" 1 "$D/n3.out" \
    "FAIL P05 diff-sha-bound: ${TA_EVIDENCE_REL}:${_dline} —"

  # ---- 负例 N3b：base_sha == head_sha（零实现 diff）→ P05 明拒，不得判 conformant ----
  ta_make_fixture "$D/n3b"
  _n3b_head=$(cat "$D/n3b.head")
  _n3b_empty=$(printf '' | git -C "$D/n3b" hash-object --stdin)
  ta_set_path "$D/n3b/$TA_EVIDENCE_REL" base_sha "\"${_n3b_head}\""
  ta_set_path "$D/n3b/$TA_EVIDENCE_REL" diff_sha "\"${_n3b_empty}\""
  ta_commit_all "$D/n3b" reviewer@example.com '2026-10-03T00:00:00Z' 'zero diff receipt'
  ta_run "$D/n3b" "$D/n3b.out" --operation merge
  rc=$?
  ta_expect '负例 N3b base_sha==head_sha（空 diff 旁路）→ exit 1 且 P05 指名' "$rc" 1 "$D/n3b.out" \
    'PASS P03 base-sha-present:' 'FAIL P05 diff-sha-bound:' 'base_sha 与 head_sha 相同' 'ticket-audit: 判定: nonconformant'

  # ---- 负例 N3c：base≠head 但两提交树相同（空 diff）→ P05 明拒 ----
  ta_make_fixture "$D/n3c"
  _n3c_base=$(git -C "$D/n3c" rev-parse HEAD)
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=impl@example.com \
    GIT_AUTHOR_DATE='2026-10-02T00:00:00Z' GIT_COMMITTER_NAME=fixture \
    GIT_COMMITTER_EMAIL=impl@example.com GIT_COMMITTER_DATE='2026-10-02T00:00:00Z' \
    git -C "$D/n3c" -c commit.gpgsign=false commit -q --allow-empty -m 'tree unchanged'
  _n3c_head=$(git -C "$D/n3c" rev-parse HEAD)
  _n3c_empty=$(printf '' | git -C "$D/n3c" hash-object --stdin)
  ta_set_path "$D/n3c/$TA_EVIDENCE_REL" base_sha "\"${_n3c_base}\""
  ta_set_path "$D/n3c/$TA_EVIDENCE_REL" head_sha "\"${_n3c_head}\""
  ta_set_path "$D/n3c/$TA_EVIDENCE_REL" diff_sha "\"${_n3c_empty}\""
  ta_commit_all "$D/n3c" reviewer@example.com '2026-10-03T00:00:00Z' 'empty diff receipt'
  ta_run "$D/n3c" "$D/n3c.out" --operation merge
  rc=$?
  ta_expect '负例 N3c base..head 树相同（空 diff）→ exit 1 且 P05 指名' "$rc" 1 "$D/n3c.out" \
    'PASS P02 evidence-committed:' 'PASS P04 review-boundary-clean:' 'FAIL P05 diff-sha-bound:' 'base..head 无差异'

  # ---- 负例 N4：自由文本 verdict → P10 ----

  ta_make_fixture "$D/n4"
  ta_set_path "$D/n4/$TA_EVIDENCE_REL" verdict '"PASS: AC1 通过"'
  ta_commit_all "$D/n4" reviewer@example.com '2026-10-03T00:00:00Z' 'free text verdict'
  ta_run "$D/n4" "$D/n4.out"
  rc=$?
  ta_expect '负例 N4 自由文本 verdict → exit 1 且 P10 拒' "$rc" 1 "$D/n4.out" \
    'FAIL P10 acceptance-results-present:' 'verdict 非受控三值'

  # ---- 负例 N5：verdict=FAIL 或 PASS 含非 pass 验收 → P10 ----

  ta_make_fixture "$D/n5"
  ta_set_path "$D/n5/$TA_EVIDENCE_REL" verdict '"FAIL"'
  ta_commit_all "$D/n5" reviewer@example.com '2026-10-03T00:00:00Z' 'fail verdict'
  ta_run "$D/n5" "$D/n5.out"
  rc=$?
  ta_expect '负例 N5 verdict=FAIL → exit 1 且 P10 拒' "$rc" 1 "$D/n5.out" \
    'FAIL P10 acceptance-results-present:' 'verdict=FAIL'
  ta_make_fixture "$D/n5b"
  ta_set_path "$D/n5b/$TA_EVIDENCE_REL" acceptance.0.result '"unknown"'
  ta_commit_all "$D/n5b" reviewer@example.com '2026-10-03T00:00:00Z' 'unknown acceptance'
  ta_run "$D/n5b" "$D/n5b.out"
  rc=$?
  ta_expect '负例 N5b PASS 含 unknown 验收 → exit 1 且 P10 拒' "$rc" 1 "$D/n5b.out" \
    'FAIL P10 acceptance-results-present:' 'verdict=PASS 但 acceptance[0]'

  # ---- 负例 N6/N7：自签与策略实现者名单命中 → P08 ----

  ta_make_fixture "$D/n6"
  ta_set_path "$D/n6/$TA_EVIDENCE_REL" reviewer_identity '"impl@example.com"'
  ta_commit_all "$D/n6" impl@example.com '2026-10-03T00:00:00Z' 'self signed review'
  ta_run "$D/n6" "$D/n6.out"
  rc=$?
  ta_expect '负例 N6 审查者与 head 作者同一 → exit 1 且 P08 拒' "$rc" 1 "$D/n6.out" \
    'FAIL P08 reviewer-distinct-from-implementer:' '自签'
  ta_make_fixture "$D/n7" \
    'trusted_reviewers=["reviewer@example.com","reviewer2@example.com"];implementation_identities=["impl@example.com","reviewer2@example.com"]'
  ta_set_path "$D/n7/$TA_EVIDENCE_REL" reviewer_identity '"reviewer2@example.com"'
  ta_commit_all "$D/n7" reviewer2@example.com '2026-10-03T00:00:00Z' 'reviewer2 evidence'
  ta_run "$D/n7" "$D/n7.out"
  rc=$?
  ta_expect '负例 N7 审查者命中策略实现者名单 → exit 1 且 P08 拒' "$rc" 1 "$D/n7.out" \
    'FAIL P08 reviewer-distinct-from-implementer:'

  # ---- 未知 N8：身份不在可信名单 / 与收据 author 不一致 → P07 unknown ----

  ta_make_fixture "$D/n8"
  ta_set_path "$D/n8/$TA_EVIDENCE_REL" reviewer_identity '"reviewer2@example.com"'
  ta_commit_all "$D/n8" reviewer2@example.com '2026-10-03T00:00:00Z' 'untrusted reviewer'
  ta_run "$D/n8" "$D/n8.out"
  rc=$?
  ta_expect '未知 N8 身份不在 trusted_reviewers → analyze exit 0 且 P07 unknown' "$rc" 0 "$D/n8.out" \
    'UNKNOWN P07 reviewer-identity-corroborated:' 'ticket-audit: 判定: unknown' 'ticket-audit: 操作面: analyze 允许'
  ta_run "$D/n8" "$D/n8.merge.out" --operation merge
  rc=$?
  ta_expect '未知 N8b 同一证据 merge → exit 1 且拒绝' "$rc" 1 "$D/n8.merge.out" \
    'ticket-audit: 操作面: merge 拒绝'
  ta_make_fixture "$D/n8c"
  ta_amend_author "$D/n8c" stranger@example.com '2026-10-03T00:00:00Z'
  ta_run "$D/n8c" "$D/n8c.out"
  rc=$?
  ta_expect '未知 N8c 收据 author 与 reviewer_identity 不一致 → P07 unknown 且 analyze exit 0' "$rc" 0 "$D/n8c.out" \
    'UNKNOWN P07 reviewer-identity-corroborated:' 'ticket-audit: 判定: unknown'

  # ---- 未知 N9：策略缺失/非法/不适用/标签缺失 → P11 unknown，读面 exit 0、写面 exit 1 ----

  ta_make_fixture "$D/n9"
  rm -f "$D/n9/$TA_POLICY_REL"
  ta_run "$D/n9" "$D/n9.out"
  rc=$?
  ta_expect '未知 N9 策略缺失 → P11 unknown 且 analyze exit 0' "$rc" 0 "$D/n9.out" \
    'UNKNOWN P11 policy-applicable:' '策略文件缺失' 'ticket-audit: 判定: unknown'
  ta_run "$D/n9" "$D/n9.push.out" --operation push
  rc=$?
  ta_expect '未知 N9b 策略缺失下 push → exit 1 拒绝' "$rc" 1 "$D/n9.push.out" \
    'ticket-audit: 操作面: push 拒绝'
  ta_make_fixture "$D/n10" 'effective_from="2026-10"'
  ta_run "$D/n10" "$D/n10.out"
  rc=$?
  ta_expect '未知 N10 策略 effective_from 非法 → P11 unknown' "$rc" 0 "$D/n10.out" \
    'UNKNOWN P11 policy-applicable:' 'effective_from'
  ta_make_fixture "$D/n11" 'effective_from="2026-10-05"'
  ta_run "$D/n11" "$D/n11.out"
  rc=$?
  ta_expect '未知 N11 策略生效日晚于 target → P11 unknown（不适用）' "$rc" 0 "$D/n11.out" \
    'UNKNOWN P11 policy-applicable:' '不适用'
  ta_make_fixture "$D/n12" 'release_baseline="v-missing-tag"'
  ta_run "$D/n12" "$D/n12.out"
  rc=$?
  ta_expect '未知 N12 发布基线标签不存在 → P11 unknown' "$rc" 0 "$D/n12.out" \
    'UNKNOWN P11 policy-applicable:' 'release_baseline 标签不可解析'

  # ---- 负例 N13～N15：收据缺失/非 review/票号不匹配 → P01 短路 exit 1 ----

  ta_make_fixture "$D/n13"
  rm -f "$D/n13/$TA_EVIDENCE_REL"
  ta_run "$D/n13" "$D/n13.out"
  rc=$?
  ta_expect '负例 N13 证据缺失 → exit 1 且 P01 短路' "$rc" 1 "$D/n13.out" \
    'FAIL P01 receipt-parseable:' '证据文件缺失' 'P01 失败，依赖证据内容的谓词未评估'
  ta_make_fixture "$D/n14"
  ta_set_path "$D/n14/$TA_EVIDENCE_REL" receipt_kind '"dispatch"'
  ta_run "$D/n14" "$D/n14.out"
  rc=$?
  ta_expect '负例 N14 receipt_kind 非 review → exit 1 且 P01' "$rc" 1 "$D/n14.out" \
    'FAIL P01 receipt-parseable:' 'receipt_kind 非 review'
  ta_make_fixture "$D/n15"
  ta_set_path "$D/n15/$TA_EVIDENCE_REL" ticket_id '"08-other"'
  ta_run "$D/n15" "$D/n15.out"
  rc=$?
  ta_expect '负例 N15 ticket_id 与票文件不一致 → exit 1 且 P01' "$rc" 1 "$D/n15.out" \
    'FAIL P01 receipt-parseable:' 'ticket_id 与票文件不一致'

  # ---- 负例 N16～N18：base 不可解析 / head 非祖先 / 审查时间越界 ----

  ta_make_fixture "$D/n16"
  ta_set_path "$D/n16/$TA_EVIDENCE_REL" base_sha '"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"'
  ta_commit_all "$D/n16" reviewer@example.com '2026-10-03T00:00:00Z' 'bad base'
  ta_run "$D/n16" "$D/n16.out"
  rc=$?
  ta_expect '负例 N16 base_sha 不可解析 → exit 1 且 P03' "$rc" 1 "$D/n16.out" \
    'FAIL P03 base-sha-present:' 'base_sha 不可解析'
  ta_make_fixture "$D/n17"
  _orphan=$(GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=impl@example.com \
    GIT_AUTHOR_DATE='2026-10-02T00:00:00Z' GIT_COMMITTER_NAME=fixture \
    GIT_COMMITTER_EMAIL=impl@example.com GIT_COMMITTER_DATE='2026-10-02T00:00:00Z' \
    git -C "$D/n17" -c commit.gpgsign=false commit-tree "$(git -C "$D/n17" rev-parse 'HEAD^{tree}')" -m orphan)
  ta_set_path "$D/n17/$TA_EVIDENCE_REL" head_sha "\"$_orphan\""
  ta_commit_all "$D/n17" reviewer@example.com '2026-10-03T00:00:00Z' 'orphan head'
  ta_run "$D/n17" "$D/n17.out"
  rc=$?
  ta_expect '负例 N17 head_sha 非 target 祖先 → exit 1 且 P04' "$rc" 1 "$D/n17.out" \
    'FAIL P04 review-boundary-clean:' '非 target 祖先'
  ta_make_fixture "$D/n18"
  ta_set_path "$D/n18/$TA_EVIDENCE_REL" reviewed_at '"2026-10-04T08:00:00Z"'
  ta_commit_all "$D/n18" reviewer@example.com '2026-10-03T00:00:00Z' 'late review time'
  ta_run "$D/n18" "$D/n18.out"
  rc=$?
  ta_expect '负例 N18 reviewed_at 晚于证据提交日 → exit 1 且 P09' "$rc" 1 "$D/n18.out" \
    'FAIL P09 reviewed-at-valid:' '晚于证据提交日'

  # ---- 负例 N19：旧 PASS（reviewed_at 早于策略生效日但晚于 head）→ P09 ----

  ta_make_fixture "$D/n19" 'effective_from="2026-10-03"'
  ta_set_path "$D/n19/$TA_EVIDENCE_REL" reviewed_at '"2026-10-02T08:00:00Z"'
  ta_commit_all "$D/n19" reviewer@example.com '2026-10-03T00:00:00Z' 'old pass'
  ta_run "$D/n19" "$D/n19.out"
  rc=$?
  ta_expect '负例 N19 旧 PASS（早于策略生效日）→ exit 1 且 P09' "$rc" 1 "$D/n19.out" \
    'FAIL P09 reviewed-at-valid:' '旧 PASS'

  # ---- 票 237：P04 显式允许集（默认仅证据；逐条传入，禁止整体放开 facts 面） ----

  # 正例：head 之后只有证据＋显式允许的记录载体 → conformant。
  ta_make_fixture "$D/p04a"
  mkdir -p "$D/p04a/facts/requirements/tickets"
  printf '{"issues": []}\n' > "$D/p04a/facts/requirements/tickets/index.json"
  ta_commit_all "$D/p04a" reviewer@example.com '2026-10-04T00:00:00Z' 'record carrier update'
  ta_run "$D/p04a" "$D/p04a.out" --operation merge \
    --allow-after facts/requirements/tickets/index.json
  rc=$?
  ta_expect '正例 P04a 显式允许记录载体 → exit 0 且 P04 放行' "$rc" 0 "$D/p04a.out" \
    'PASS P04 review-boundary-clean:' 'ticket-audit: 判定: conformant'
  ta_run "$D/p04a" "$D/p04a.strict.out" --operation merge
  rc=$?
  ta_expect '负例 P04b 同一改动未传入允许集 → exit 1 且 P04 指名 index.json' "$rc" 1 "$D/p04a.strict.out" \
    'FAIL P04 review-boundary-clean: facts/requirements/tickets/index.json:1'

  # 负例：产品文件即使传入记录载体允许集仍 FAIL，指名该产品路径。
  ta_make_fixture "$D/p04c"
  mkdir -p "$D/p04c/agent-up/scripts"
  printf 'product note\n' > "$D/p04c/agent-up/scripts/README.md"
  ta_commit_all "$D/p04c" reviewer@example.com '2026-10-04T00:00:00Z' 'product after evidence'
  ta_run "$D/p04c" "$D/p04c.out" --operation merge \
    --allow-after facts/requirements/tickets/index.json \
    --allow-after facts/requirements/tickets/progress-current.md
  rc=$?
  ta_expect '负例 P04c 允许集下产品文件仍被拒 → exit 1 指名 agent-up/scripts/README.md' "$rc" 1 "$D/p04c.out" \
    'FAIL P04 review-boundary-clean: agent-up/scripts/README.md:1'

  # 负例：允许集之外的其他 facts 文件仍 FAIL（证明非整体放开 facts 面）。
  ta_make_fixture "$D/p04d"
  printf '{}\n' > "$D/p04d/facts/requirements/tickets/08-other.json"
  ta_commit_all "$D/p04d" reviewer@example.com '2026-10-04T00:00:00Z' 'other facts after evidence'
  ta_run "$D/p04d" "$D/p04d.out" --operation merge \
    --allow-after facts/requirements/tickets/index.json \
    --allow-after facts/requirements/tickets/progress-current.md
  rc=$?
  ta_expect '负例 P04d 允许集之外 facts 文件仍被拒 → exit 1 指名 08-other.json' "$rc" 1 "$D/p04d.out" \
    'FAIL P04 review-boundary-clean: facts/requirements/tickets/08-other.json:1'

  # ---- 负例 N20：一次审计零写入（文件 cksum 与 HEAD 前后一致） ----

  ta_make_fixture "$D/n20"
  _head_before=$(git -C "$D/n20" rev-parse HEAD)
  ( cd "$D/n20" && LC_ALL=C find . -type f ! -path './.git/*' -exec cksum {} + | LC_ALL=C sort ) > "$D/n20.before"
  ta_run "$D/n20" "$D/n20.out"
  rc=$?
  ( cd "$D/n20" && LC_ALL=C find . -type f ! -path './.git/*' -exec cksum {} + | LC_ALL=C sort ) > "$D/n20.after"
  if [ "$rc" -eq 0 ] && cmp -s "$D/n20.before" "$D/n20.after"; then
    ok '负例 N20 审计零写入（文件集合与内容 cksum 前后一致）'
  else
    bad '负例 N20 审计零写入（文件集合与内容 cksum 前后一致）' "exit=$rc 差异=$(diff "$D/n20.before" "$D/n20.after" 2>/dev/null | head -n 3 | tr '\n' '|')"
  fi
  if [ "$(git -C "$D/n20" rev-parse HEAD)" = "$_head_before" ]; then
    ok '负例 N20b 审计前后 HEAD 不变'
  else
    bad '负例 N20b 审计前后 HEAD 不变' 'HEAD 被改写'
  fi

  # ---- 用法与环境错误 exit 2 ----

  sh "$TA" > "$D/u1.out" 2>&1
  rc=$?
  ta_expect '用法 U1 缺 NN → exit 2' "$rc" 2 "$D/u1.out"
  sh "$TA" 07 --operation sync --repo "$D/p1" > "$D/u2.out" 2>&1
  rc=$?
  ta_expect '用法 U2 非法 --operation → exit 2' "$rc" 2 "$D/u2.out" '--operation 不合口径'
  mkdir -p "$D/notgit"
  sh "$TA" 07 --repo "$D/notgit" > "$D/u3.out" 2>&1
  rc=$?
  ta_expect '用法 U3 非 Git 目录 → exit 2' "$rc" 2 "$D/u3.out" '不是 Git 仓库'

  suite_summary 'ticket-audit'
}
