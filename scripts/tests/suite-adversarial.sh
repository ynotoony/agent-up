#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite adversarial "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: adversarial（票 241 对抗金丝雀）
# 覆盖：10 条核心规则各一个真实负例——C1 未确认写入（checkpoint-write 缺裁决原文
# exit 2 零写入）、C2 无证据完成（run-record seal 待填 fail-closed 字节不变）、C3 自审
# （ticket-audit P08 自签非 conformant）、C4 越界提交（lane-commit check-gates 白名单
# 外 fail 零提交）、C5 冲突继续（upgrade-check 双布局冲突 exit 1）、C6 破坏性操作
# （记录提交拒绝删除路径，HEAD 不变）、C7 状态不落盘（ticket-run start 索引无条目
# decision-required exit 1 零写入）、C8 双写（通用 flips 直写索引拒绝）、C9 改写记录
# （check-append-only 历史行改写 exit 1 指名行号）、C10 越角色（check-role-permissions
# 跨角色 diff exit 1）；G1–G5 各一次正例与负例（G1=C1、G2=C2、G3=C3、G4=C6、G5=C5）。
# 另含：夹具项目一票 ready→done 正常路径（ticket-run start→implementation→review→
# commit）、安装后 run-record seal 与 upgrade-check（install.sh 为 main-only 件，worktree
# 缺席时显式 SKIP 并说明，主检出以 --script-dir/--pkg-root 真跑）、临时副本升级切换
# （记录来源提交、rules/ 与 .zcode/ 仅工具写入、旧 scripts/ 标旧布局且零静默覆盖）、
# 纯文档项目与 Seed 初始化项目的前置流程。
# 全部夹具 mktemp 构建并 trap 清理；每条负例先核被测脚本在场，非零退出必须来自目标
# 规则且副作用为零，缺依赖不当负例有效。
# ============================================================

adv_need() {
  # $1=文件路径 $2=场景标签：被测脚本/必备件不在场即为失败断言（不把缺依赖当负例有效）
  if [ ! -s "$1" ]; then
    bad "$2 前置件在场" "缺件或空文件: $1"
    return 1
  fi
  return 0
}

adv_git() {
  # $1=仓库根；其余原样传给 git（本地身份内联，零全局污染）
  _ag_root=$1
  shift
  git -C "$_ag_root" -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false "$@"
}

adv_commit() {
  # $1=仓库根 $2=提交信息 [$3=作者邮箱] [$4=提交日期，默认 2026-10-01T00:00:00Z]
  _ac_email=${3:-fixture@example.com}
  _ac_date=${4:-2026-10-01T00:00:00Z}
  git -C "$1" add -A
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL="$_ac_email" GIT_AUTHOR_DATE="$_ac_date" \
    GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL="$_ac_email" GIT_COMMITTER_DATE="$_ac_date" \
    git -C "$1" -c commit.gpgsign=false commit -qm "$2"
}

adv_head() {
  git -C "$1" rev-parse HEAD
}

adv_sig() {
  LC_ALL=C cksum < "$1"
}

adv_tree_sig() {
  # $1=目录：全文件路径＋cksum 归一后取总校验（目录不存在输出 absent）
  [ -d "$1" ] || { printf 'absent\n'; return 0; }
  (cd "$1" && find . -type f -print | LC_ALL=C sort | while IFS= read -r _ats_f; do
    printf '%s ' "$_ats_f"
    LC_ALL=C cksum < "$_ats_f"
  done) | LC_ALL=C cksum
}

adv_want() {
  # $1=场景名 $2=实际退出码 $3=期望退出码 $4=输出文件；其后为须在场的整行子串
  _aw_name=$1
  _aw_rc=$2
  _aw_want=$3
  _aw_out=$4
  shift 4
  if [ "$_aw_rc" -ne "$_aw_want" ]; then
    bad "$_aw_name" "exit=$_aw_rc 期望=$_aw_want 输出=$(tr '\n' '|' < "$_aw_out" | cut -c1-400)"
    return 0
  fi
  if ! require_out "$_aw_name" "$_aw_out"; then
    return 0
  fi
  while [ $# -gt 0 ]; do
    _aw_pat=$1
    shift
    if ! grep -Fq -- "$_aw_pat" "$_aw_out"; then
      bad "$_aw_name" "缺报文「${_aw_pat}」；实际=$(tr '\n' '|' < "$_aw_out" | cut -c1-400)"
      return 0
    fi
  done
  ok "$_aw_name"
}

adv_same() {
  # $1=场景名 $2=前值 $3=后值
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    bad "$1" "前=$2 后=$3"
  fi
}

adv_clean() {
  # $1=仓库根 $2=场景名：工作树零改动（负例零副作用）
  if [ -z "$(git -C "$1" status --porcelain -uall)" ]; then
    ok "$2"
  else
    bad "$2" "$(git -C "$1" status --porcelain -uall | tr '\n' '|' | cut -c1-400)"
  fi
}

# ---- 夹具构建器 ----

adv_ticket_doc() {
  # $1=输出文件 $2=票 id：最小 JSON 票体（checkpoint-write 只要求普通文件在场）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "adversarial fixture",
  "created_at": "2026-10-29"
}
EOF
}

adv_index_one() {
  # $1=仓库根 $2=票 id $3=status：索引恰一条目（一条目一行，与真实索引排版同款）
  mkdir -p "$1/facts/requirements/tickets"
  {
    printf '{\n  "issues": [\n'
    printf '    {"id": "%s", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-29T10:00"}\n' "$2" "$3"
    printf '  ]\n}\n'
  } > "$1/facts/requirements/tickets/index.json"
}

adv_seed_governance() {
  # $1=项目根：八件套模板＋四角色合同＋artifacts 索引＋最小票面（Seed 初始化面）
  _asg_tpl="$PKG_ROOT/references/templates"
  mkdir -p "$1/rules/implementation/roles" "$1/facts/project" "$1/facts/requirements/tickets"
  cp "$_asg_tpl/AGENTS.md.tmpl" "$1/AGENTS.md"
  cp "$_asg_tpl/core.md.tmpl" "$1/rules/core.md"
  cp "$_asg_tpl/assessment.md.tmpl" "$1/rules/assessment.md"
  cp "$_asg_tpl/discipline.md.tmpl" "$1/rules/implementation/discipline.md"
  cp "$_asg_tpl/project.md.tmpl" "$1/rules/project.md"
  for _asg_role in implementation review commit triage; do
    cp "$_asg_tpl/agents-$_asg_role.md.tmpl" "$1/rules/implementation/roles/$_asg_role.md"
  done
  cp "$_asg_tpl/artifacts-yaml.tmpl" "$1/facts/project/artifacts.yaml"
  : > "$1/rules/README.md"
  : > "$1/facts/README.md"
  printf '# 任务票索引（adversarial fixture）\n' > "$1/facts/requirements/tickets/README.md"
  adv_index_one "$1" '10-seed-fixture' in_progress
}

adv_close_dir_readmes() {
  # $1=项目根 $2=场景标签：安装后给新建治理目录补 README 骨架（新目录收口流程；
  # upgrade-check 的 manifest README 面只核存在性，缺口由本步闭合）
  _acdr_gen="$1/rules/implementation/scripts/generate-dir-readmes.sh"
  _acdr_d='rules/implementation/scripts'
  if [ -d "$1/$_acdr_d" ] && [ ! -f "$1/$_acdr_d/README.md" ]; then
    if [ -s "$_acdr_gen" ] \
      && sh "$_acdr_gen" --target "$1" --init "$_acdr_d" > "$D/close.out" 2>&1; then
      ok "$2 新目录 README 骨架经生成器落位（${_acdr_d}）"
    else
      bad "$2 新目录 README 骨架经生成器落位（${_acdr_d}）" \
        "$(tail -n 2 "$D/close.out" 2>/dev/null | tr '\n' '|')"
    fi
  fi
}

adv_pkg_fixture() {
  # $1=包根：upgrade-check 夹具包（两脚本＋模板八件＋规则表＋模板 manifest）
  _apf=$1
  rm -rf "$_apf"
  mkdir -p "$_apf/scripts" "$_apf/references/templates"
  cp "$SCRIPT_DIR/upgrade-check.sh" "$SCRIPT_DIR/common-helpers.sh" "$_apf/scripts/"
  cp "$SCRIPT_DIR/generate-progress.sh" "$_apf/scripts/"
  printf "ip_gate fast-lane --fast-lane 'fixture fast lane'\nip_file agent-up/scripts/upgrade-check.sh Conditional fast-lane 'fixture checker'\nip_file agent-up/scripts/generate-progress.sh Conditional fast-lane 'fixture shared script'\n" \
    > "$_apf/scripts/install-policy.rules"
  printf '# ==== payload：导出形态（export-payload.sh 读）====\n# ==== boundary：禁入名单（pre-push 安检读）====\n# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n# ==== main-only：worktree 排除清单（worktree-add.sh 读）====\n' \
    > "$_apf/references/templates/delivery-rules.tmpl"
  printf '#### R-AG-001 Agent\nbody\n' > "$_apf/references/templates/AGENTS.md.tmpl"
  printf '#### R-CO-001 Grant\nbody\n' > "$_apf/references/templates/core.md.tmpl"
  printf '#### R-DP-001 Alpha\nbody\n#### R-DP-002 Beta\nbody\n' > "$_apf/references/templates/assessment.md.tmpl"
  printf '#### R-DP-003 Discipline\nbody\n' > "$_apf/references/templates/discipline.md.tmpl"
  printf '#### R-DP-004 Project\nbody\n' > "$_apf/references/templates/project.md.tmpl"
  printf '#### R-RI-001 Implementation\nbody\n' > "$_apf/references/templates/agents-implementation.md.tmpl"
  printf '#### R-RR-001 Review\nbody\n' > "$_apf/references/templates/agents-review.md.tmpl"
  printf '#### R-RC-001 Commit\nbody\n' > "$_apf/references/templates/agents-commit.md.tmpl"
  cp "$PKG_ROOT/references/templates/README.md" "$_apf/references/templates/README.md"
}

adv_modern_repo() {
  # $1=仓库根 $2=夹具包根：现代完整治理面＋delivery.rules（fast-lane 证据）
  mkdir -p "$1/rules/implementation/roles" "$1/rules/implementation/scripts" "$1/facts/project"
  printf '# scripts directory\n' > "$1/rules/implementation/scripts/README.md"
  cp "$2/references/templates/AGENTS.md.tmpl" "$1/AGENTS.md"
  cp "$2/references/templates/core.md.tmpl" "$1/rules/core.md"
  cp "$2/references/templates/assessment.md.tmpl" "$1/rules/assessment.md"
  cp "$2/references/templates/discipline.md.tmpl" "$1/rules/implementation/discipline.md"
  cp "$2/references/templates/project.md.tmpl" "$1/rules/project.md"
  cp "$2/references/templates/agents-implementation.md.tmpl" "$1/rules/implementation/roles/implementation.md"
  cp "$2/references/templates/agents-review.md.tmpl" "$1/rules/implementation/roles/review.md"
  cp "$2/references/templates/agents-commit.md.tmpl" "$1/rules/implementation/roles/commit.md"
  printf '# rules directory\n' > "$1/rules/README.md"
  printf '# facts directory\n' > "$1/facts/README.md"
  printf '# artifacts\n' > "$1/facts/project/artifacts.yaml"
  cp "$2/references/templates/delivery-rules.tmpl" "$1/delivery.rules"
}

adv_lane_fixture() {
  # $1=仓库根：lane-commit/check-gates 全闭包＋微账本＋索引＋变更账本基线
  _alf=$1
  rm -rf "$_alf"
  mkdir -p "$_alf/rules/implementation/scripts" "$_alf/facts/project" "$_alf/facts/requirements/tickets"
  for _alf_f in lane-commit.sh check-gates.sh common-helpers.sh json-validator.py ticket-ops.sh \
    generate-progress.sh generate-dir-readmes.sh dir-readme.rules checkpoint-write.sh ledger-append.sh record-store.sh ticket-audit.sh; do
    cp "$SCRIPT_DIR/$_alf_f" "$_alf/rules/implementation/scripts/$_alf_f"
  done
  printf '{"date": "2026-10-01", "lane": "micro", "whitelist": "a.txt", "gates": "PASS", "verify": 1, "commit": "seed", "actual": ""}\n' \
    > "$_alf/facts/project/micro.jsonl"
  printf '%s\n' '{"date":"2026-10-01","kind":"change","scope":"fixture","decision":"seed","evidence_ref":"facts/project/changes.jsonl"}' \
    > "$_alf/facts/project/changes.jsonl"
  adv_index_one "$_alf" '50-lane-fixture' in_progress
  printf 'seed\n' > "$_alf/a.txt"
  printf 'base\n' > "$_alf/b.txt"
  git_repo "$_alf"
  adv_commit "$_alf" seed
  printf 'changed\n' > "$_alf/a.txt"
}

adv_lane_contract() {
  # $1=合同文件 $2=whitelist [$3=额外合同行]
  {
    printf 'lane: micro\n'
    printf 'whitelist: %s\n' "$2"
    printf 'message: adversarial micro commit\n'
    printf 'verify: true\n'
    [ -z "${3:-}" ] || printf '%s\n' "$3"
  } > "$1"
}

adv_audit_fixture() {
  # $1=仓库根 $2=收据 reviewer_identity $3=收据提交作者邮箱
  _aaf=$1
  rm -rf "$_aaf"
  mkdir -p "$_aaf/facts/requirements/tickets"
  git_repo "$_aaf"
  printf 'seed\n' > "$_aaf/a.txt"
  printf '{"id":"41-fixture","kind":"task","title":"fixture","created_at":"2026-10-01T00:00:00Z"}\n' \
    > "$_aaf/facts/requirements/tickets/41-fixture.json"
  adv_commit "$_aaf" 'ticket seed' fixture@example.com
  _aaf_base=$(adv_head "$_aaf")
  printf '{"schema_version":1,"policy_id":"adversarial-fixture","effective_from":"2026-10-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["fixture@example.com"]}\n' \
    "$_aaf_base" > "$_aaf/facts/requirements/audit-policy.json"
  adv_commit "$_aaf" 'audit policy' fixture@example.com
  printf 'product\n' >> "$_aaf/a.txt"
  adv_commit "$_aaf" 'product change' fixture@example.com 2026-10-02T00:00:00Z
  _aaf_head=$(adv_head "$_aaf")
  receipt "$_aaf/facts/requirements/tickets/41-fixture.review-evidence.json" "$_aaf" "$_aaf_base" "$_aaf_head" \
    41-fixture --reviewer "$2" --ac-evidence 'a.txt:1' \
    --created-at '2026-10-02T12:00:00Z' --reviewed-at '2026-10-02T12:00:00Z'
  adv_commit "$_aaf" 'review evidence' "$3" 2026-10-03T00:00:00Z
}

adv_run_record_fixture() {
  # $1=仓库根：索引一条 ready＋git 基线（run-record new 的机械字段依赖）
  rm -rf "$1"
  mkdir -p "$1"
  adv_index_one "$1" '42-fixture' ready
  adv_ticket_doc "$1/facts/requirements/tickets/42-fixture.json" '42-fixture'
  printf 'x\n' > "$1/a.txt"
  git -C "$1" init -q
  adv_commit "$1" seed
}

adv_run_record_new() {
  # $1=仓库根：生成 run record 并回显文件名
  sh "$SCRIPT_DIR/run-record.sh" "$1" new --ticket 42-fixture > "$D/rr-new.out" 2>&1
  _arr_rc=$?
  if [ "$_arr_rc" -ne 0 ]; then
    printf ''
    return "$_arr_rc"
  fi
  LC_ALL=C find "$1/facts/requirements/runs" -name '*.json' -type f | head -n 1
}

adv_run_record_fill() {
  # $1=run record 文件：补齐 seal 必备内容字段与 usage
  python3 - "$1" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, encoding='utf-8') as f:
    d = json.load(f)
d['scope'] = ['fixture-scope']
d['last_verified'] = {'command': 'sh run-record.sh seal', 'result': 'pass', 'at': '2026-10-29'}
d['next_step'] = 'seal fixture'
d['usage'] = {'tokens_total': 1, 'requests': 1, 'duration_seconds': 1,
              'source': 'executor', 'at': d['updated_at']}
with open(p, 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
}

adv_ticket_run_fixture() {
  # $1=主检出根：ticket-run 全链夹具（索引 ready，站由 start 创建）
  _atr=$1
  rm -rf "$_atr"
  mkdir -p "$_atr/rules/implementation/scripts" "$_atr/rules/implementation/references/schemas" \
    "$_atr/rules/implementation/references/prompts" "$_atr/facts/requirements/tickets" "$_atr/facts/project"
  for _atr_f in ticket-run.sh contract-build.sh check-dispatch-contract.sh worktree-add.sh dp-load-rules.sh \
    check-gates.sh ticket-ops.sh generate-progress.sh generate-dir-readmes.sh dir-readme.rules ledger-append.sh \
    record-store.sh common-helpers.sh json-validator.py ticket-audit.sh; do
    cp "$SCRIPT_DIR/$_atr_f" "$_atr/rules/implementation/scripts/$_atr_f"
  done
  cp "$PKG_ROOT/references/schemas/dispatch-contract.schema.json" "$_atr/rules/implementation/references/schemas/"
  for _atr_p in implementation-prompt.md review-prompt.md commit-prompt.md; do
    cp "$PKG_ROOT/references/prompts/$_atr_p" "$_atr/rules/implementation/references/prompts/"
  done
  printf '# ==== main-only：worktree 排除清单（worktree-add.sh 读）====\ndp_mainonly agent-up/scripts/export-payload.sh\n' \
    > "$_atr/delivery.rules"
  printf 'implemented\n' > "$_atr/product.txt"
  adv_index_one "$_atr" '90-run-fixture' ready
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  printf '| `90-run-fixture.json` | 任务票 90；`ready` | fixture |\n' > "$_atr/facts/requirements/tickets/README.md"
  printf '%s\n' '{"date":"2026-10-29","kind":"change","scope":"90","decision":"fixture seed","evidence_ref":"facts/requirements/tickets/90-run-fixture.json"}' \
    > "$_atr/facts/project/changes.jsonl"
  python3 - "$_atr" <<'PY'
import json, sys
root = sys.argv[1]
impl_keys = ['REPOSITORY_PATH', 'TASK_DESCRIPTION', 'GOAL', 'SCOPE_TREE', 'OUT_OF_SCOPE',
             'CONTEXT_EVIDENCE', 'CONSTRAINTS', 'FORBIDDEN_CHANGES', 'ACCEPTANCE_CRITERIA',
             'VERIFICATION_COMMANDS', 'DEPENDENCIES_BLOCKERS', 'RISKS', 'BUDGET_CHECKPOINTS',
             'ESTIMATED_TIME', 'ACTUAL_TIME', 'TICKET_ID']
review_keys = ['REVIEW_SCOPE', 'IMPLEMENTATION_SUMMARY', 'ACCEPTANCE_CRITERIA',
               'DIFF_LOCATION', 'REVIEW_DIMENSIONS', 'TICKET_ID']
ticket = {
    'id': '90-run-fixture', 'kind': 'task', 'title': 'adversarial normal path',
    'created_at': '2026-10-29', 'blocked_by': [], 'actual_time': '1h（fixture 净工时占位）',
    'dispatch': {
        'implementation': {k: 'fixture implementation ' + k for k in impl_keys},
        'review': {k: 'fixture review ' + k for k in review_keys},
        'commit': {
            'REVIEW_PASS_CHECKPOINT': 'facts/requirements/tickets/90-run-fixture-review-checkpoint.md',
            'FILE_WHITELIST': 'product.txt,facts/requirements/tickets/90-run-fixture-review-checkpoint.md,facts/requirements/tickets/90-run-fixture.review-evidence.json',
            'COMMIT_MESSAGE': 'test: adversarial normal path',
            'RECORD_FLIP_AUTHORIZATION': 'flips: facts/requirements/tickets/index.json:index:90-run-fixture:done:2026-10-29T12:00',
            'SCOPE_CHECK_COMMAND': 'test -f product.txt',
            'TICKET_ID': '90-run-fixture',
        },
    },
}
with open(root + '/facts/requirements/tickets/90-run-fixture.json', 'w', encoding='utf-8') as fh:
    json.dump(ticket, fh, ensure_ascii=False, indent=2)
    fh.write('\n')
PY
  git_repo "$_atr"
  adv_commit "$_atr" init
}

adv_run_record_seal_pair() {
  # $1=仓库根：先无证据 seal（负例），再补齐 seal（正例）；供 C2 与 G2 共用
  _arse_file=$(adv_run_record_new "$1")
  _arse_newrc=$?
  if [ "$_arse_newrc" -ne 0 ] || [ -z "$_arse_file" ]; then
    bad 'C2 run-record new 生成骨架' "exit=$_arse_newrc 输出=$(tr '\n' '|' < "$D/rr-new.out")"
    return 1
  fi
  _arse_sig=$(adv_sig "$_arse_file")
  sh "$SCRIPT_DIR/run-record.sh" "$1" seal --file "$_arse_file" > "$D/rr-seal-neg.out" 2>&1
  _arse_rc=$?
  _arse_sig2=$(adv_sig "$_arse_file")
  adv_want 'C2 无证据完成：run-record seal 待填 fail-closed' "$_arse_rc" 1 "$D/rr-seal-neg.out" \
    '存在【待填】残留' 'fail-closed'
  adv_same 'C2 seal 拒绝时 run record 字节不变' "$_arse_sig" "$_arse_sig2"
  adv_run_record_fill "$_arse_file"
  sh "$SCRIPT_DIR/run-record.sh" "$1" seal --file "$_arse_file" > "$D/rr-seal-pos.out" 2>&1
  _arse_rc=$?
  adv_want 'G2 证据齐备：run-record seal 通过' "$_arse_rc" 0 "$D/rr-seal-pos.out" 'seal 通过'
}

# ---- 单条规则负例 ----

adv_c1() {
  CW="$SCRIPT_DIR/checkpoint-write.sh"
  adv_need "$CW" 'C1' || return 0
  R=$D/c1
  rm -rf "$R"; mkdir -p "$R/facts/requirements/tickets"
  adv_ticket_doc "$R/facts/requirements/tickets/21-c1.json" '21-c1'
  _before=$(adv_sig "$R/facts/requirements/tickets/21-c1.json")
  sh "$CW" "$R" review-checkpoint --ticket facts/requirements/tickets/21-c1.json \
    --verdict-at 2026-10-29T10:00 --commit abc1234 --commit-subject 'fixture' \
    --diff-summary 'a.txt:1' > "$D/c1.out" 2>&1
  _rc=$?
  _after=$(adv_sig "$R/facts/requirements/tickets/21-c1.json")
  adv_want 'C1 未确认写入：缺裁决原文被拒（exit 2）' "$_rc" 2 "$D/c1.out" '缺少 --verdict-quote'
  adv_same 'C1 拒绝时票文件字节不变' "$_before" "$_after"
  if [ ! -e "$R/facts/requirements/tickets/21-c1-review-checkpoint.md" ]; then
    ok 'C1 拒绝时零 Checkpoint 文件写入'
  else
    bad 'C1 拒绝时零 Checkpoint 文件写入' '出现 21-c1-review-checkpoint.md'
  fi
}

adv_c2() {
  adv_need "$SCRIPT_DIR/run-record.sh" 'C2' || return 0
  adv_run_record_fixture "$D/c2"
  adv_run_record_seal_pair "$D/c2"
}

adv_c3() {
  adv_need "$SCRIPT_DIR/ticket-audit.sh" 'C3' || return 0
  R=$D/c3
  adv_audit_fixture "$R" 'fixture@example.com' 'fixture@example.com'
  _head=$(adv_head "$R")
  sh "$SCRIPT_DIR/ticket-audit.sh" 41 --repo "$R" --operation merge > "$D/c3.out" 2>&1
  _rc=$?
  adv_want 'C3 自审：ticket-audit P08 拒自签' "$_rc" 1 "$D/c3.out" \
    'FAIL P08 reviewer-distinct-from-implementer' '审查者与实现者身份相同' '判定: nonconformant'
  adv_same 'C3 审计零写入（HEAD 不变）' "$_head" "$(adv_head "$R")"
  adv_clean "$R" 'C3 审计零写入（工作树干净）'
}

adv_c4() {
  for _f in lane-commit.sh check-gates.sh common-helpers.sh json-validator.py; do
    adv_need "$SCRIPT_DIR/$_f" 'C4' || return 0
  done
  R=$D/c4
  adv_lane_fixture "$R"
  printf 'outside\n' >> "$R/b.txt"
  adv_lane_contract "$D/c4.contract" 'a.txt'
  _head=$(adv_head "$R")
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/lane-commit.sh" "$R" "$D/c4.contract") \
    > "$D/c4.out" 2>&1
  _rc=$?
  adv_want 'C4 越界提交：白名单外改动被拒' "$_rc" 1 "$D/c4.out" 'FAIL: 改动 b.txt（不在白名单内）'
  adv_same 'C4 拒绝时零提交（HEAD 不变）' "$_head" "$(adv_head "$R")"
}

adv_c5() {
  adv_need "$SCRIPT_DIR/upgrade-check.sh" 'C5' || return 0
  P=$D/c5pkg
  adv_pkg_fixture "$P"
  R=$D/c5repo
  rm -rf "$R"
  adv_modern_repo "$R" "$P"
  mkdir -p "$R/rules/implementation/scripts" "$R/scripts"
  cp "$P/scripts/upgrade-check.sh" "$R/rules/implementation/scripts/upgrade-check.sh"
  cp "$P/scripts/generate-progress.sh" "$R/rules/implementation/scripts/generate-progress.sh"
  cp "$P/scripts/upgrade-check.sh" "$R/scripts/upgrade-check.sh"
  cp "$P/scripts/generate-progress.sh" "$R/scripts/generate-progress.sh"
  printf '# divergent legacy copy\n' >> "$R/scripts/upgrade-check.sh"
  sh "$SCRIPT_DIR/upgrade-check.sh" "$P" "$R" > "$D/c5.out" 2>&1
  _rc=$?
  adv_want 'C5 冲突继续：双布局同脚本分歧 exit 1' "$_rc" 1 "$D/c5.out" \
    '冲突  upgrade-check.sh 同时位于' '漂移  scripts/upgrade-check.sh（旧布局'
  if [ -f "$R/scripts/upgrade-check.sh" ]; then
    ok 'C5 冲突时旧文件未被静默删除'
  else
    bad 'C5 冲突时旧文件未被静默删除' 'scripts/upgrade-check.sh 消失'
  fi
}

adv_c6() {
  adv_need "$SCRIPT_DIR/lane-commit.sh" 'C6' || return 0
  R=$D/c6
  adv_lane_fixture "$R"
  adv_git "$R" checkout -- a.txt
  _head=$(adv_head "$R")
  rm -f "$R/facts/project/changes.jsonl"
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/lane-commit.sh" \
    --record-commit "$R" 'adversarial record' facts/project/changes.jsonl) > "$D/c6.out" 2>&1
  _rc=$?
  adv_want 'C6 破坏性操作：记录提交拒绝删除路径' "$_rc" 1 "$D/c6.out" \
    '记录提交拒绝：记录路径在工作树不存在' '零提交'
  adv_same 'C6 拒绝时零提交（HEAD 不变）' "$_head" "$(adv_head "$R")"
}

adv_c7() {
  _repo_scripts="$PKG_ROOT/../rules/implementation/scripts"
  adv_need "$_repo_scripts/ticket-run.sh" 'C7' || return 0
  R=$D/c7
  rm -rf "$R"; mkdir -p "$R/rules/implementation/scripts" "$R/facts/requirements/tickets"
  pkg_copy "$_repo_scripts/." "$R/rules/implementation/scripts/"
  printf '{"issues": []}\n' > "$R/facts/requirements/tickets/index.json"
  adv_ticket_doc "$R/facts/requirements/tickets/43-c7.json" '43-c7'
  git_repo "$R"
  adv_commit "$R" seed
  _before=$(adv_sig "$R/facts/requirements/tickets/index.json")
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/ticket-run.sh" 43 start "$R") \
    > "$D/c7.out" 2>&1
  _rc=$?
  adv_want 'C7 状态不落盘：索引无条目 start 拒绝' "$_rc" 1 "$D/c7.out" \
    'start 前置未满足：索引无该票条目（先 open）'
  adv_same 'C7 拒绝时索引字节不变' "$_before" "$(adv_sig "$R/facts/requirements/tickets/index.json")"
  adv_clean "$R" 'C7 拒绝时零写入（工作树干净）'
}

adv_c8() {
  adv_need "$SCRIPT_DIR/lane-commit.sh" 'C8' || return 0
  R=$D/c8
  adv_lane_fixture "$R"
  _before=$(adv_sig "$R/facts/requirements/tickets/index.json")
  adv_lane_contract "$D/c8.contract" 'a.txt' 'flips: facts/requirements/tickets/index.json:status:done'
  _head=$(adv_head "$R")
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/lane-commit.sh" "$R" "$D/c8.contract") \
    > "$D/c8.out" 2>&1
  _rc=$?
  adv_want 'C8 双写：通用 flips 直写索引被拒' "$_rc" 1 "$D/c8.out" \
    '通用 flips 不得直写索引文件' 'index.json 唯一写入方＝ticket-ops.sh'
  adv_same 'C8 拒绝时索引字节不变' "$_before" "$(adv_sig "$R/facts/requirements/tickets/index.json")"
  adv_same 'C8 拒绝时零提交（HEAD 不变）' "$_head" "$(adv_head "$R")"
}

adv_c9() {
  adv_need "$SCRIPT_DIR/check-append-only.sh" 'C9' || return 0
  R=$D/c9
  rm -rf "$R"; mkdir -p "$R/facts/project"
  printf 'l1\nl2\nl3\n' > "$R/facts/project/changes.jsonl"
  git_repo "$R"
  adv_commit "$R" seed
  awk 'NR==2{print "REWRITTEN"} {print}' "$R/facts/project/changes.jsonl" > "$D/c9.tmp"
  mv "$D/c9.tmp" "$R/facts/project/changes.jsonl"
  sh "$SCRIPT_DIR/check-append-only.sh" "$R" > "$D/c9.out" 2>&1
  _rc=$?
  adv_want 'C9 改写记录：check-append-only 指名文件与行号' "$_rc" 1 "$D/c9.out" \
    'FAIL: facts/project/changes.jsonl 历史行被改写或中间插入' '首个违规行号 2'
}

adv_c10() {
  _rp_script="$PKG_ROOT/../rules/implementation/scripts/check-role-permissions.sh"
  _rp_perm="$PKG_ROOT/../rules/implementation/roles/role-permissions.json"
  adv_need "$_rp_script" 'C10' || return 0
  adv_need "$_rp_perm" 'C10' || return 0
  R=$D/c10
  rm -rf "$R"
  mkdir -p "$R/rules/implementation/scripts" "$R/rules/implementation/roles"
  cp "$_rp_script" "$R/rules/implementation/scripts/check-role-permissions.sh"
  cp "$_rp_perm" "$R/rules/implementation/roles/role-permissions.json"
  git_repo "$R"
  adv_commit "$R" seed
  cat > "$D/c10-cross.patch" <<'EOF'
diff --git a/facts/requirements/tickets/44-c10.json b/facts/requirements/tickets/44-c10.json
index 1111111..2222222 100644
--- a/facts/requirements/tickets/44-c10.json
+++ b/facts/requirements/tickets/44-c10.json
@@ -1,12 +1,12 @@
 {
   "id": "44-c10",
   "title": "x",
   "status": "ready",
   "checkpoint": {
-    "implementation": {}
+    "implementation": {
+      "started_at": "2026-10-29"
+    },
+    "review": {
+      "started_at": "2026-10-29"
+    }
   }
 }
EOF
  sh "$R/rules/implementation/scripts/check-role-permissions.sh" < "$D/c10-cross.patch" \
    > "$D/c10.out" 2>&1
  _rc=$?
  adv_want 'C10 越角色：implementation 与 review 同改被拒' "$_rc" 1 "$D/c10.out" \
    'checkpoint.implementation 和 checkpoint.review 同时改动（跨角色违规）'
  adv_clean "$R" 'C10 拒绝时零写入（夹具仓干净）'
}

# ---- G1–G5 正负例 ----

adv_g1() {
  CW="$SCRIPT_DIR/checkpoint-write.sh"
  adv_need "$CW" 'G1' || return 0
  R=$D/g1
  rm -rf "$R"; mkdir -p "$R/facts/requirements/tickets"
  adv_ticket_doc "$R/facts/requirements/tickets/22-g1.json" '22-g1'
  _before=$(adv_sig "$R/facts/requirements/tickets/22-g1.json")
  sh "$CW" "$R" review-checkpoint --ticket facts/requirements/tickets/22-g1.json \
    --verdict-at 2026-10-29T10:00 --commit abc1234 --commit-subject 'fixture' \
    --diff-summary 'a.txt:1' > "$D/g1-neg.out" 2>&1
  _rc=$?
  adv_want 'G1 负例：缺用户裁决原文 → 拒绝写入' "$_rc" 2 "$D/g1-neg.out" '缺少 --verdict-quote'
  adv_same 'G1 负例：票文件零写入' "$_before" "$(adv_sig "$R/facts/requirements/tickets/22-g1.json")"
  sh "$CW" "$R" review-checkpoint --ticket facts/requirements/tickets/22-g1.json \
    --verdict-quote '用户确认：通过' --verdict-at 2026-10-29T10:00 --commit abc1234 \
    --commit-subject 'fixture' --diff-summary 'a.txt:1' > "$D/g1-pos.out" 2>&1
  _rc=$?
  adv_want 'G1 正例：裁决原文齐备 → 写入 Checkpoint' "$_rc" 0 "$D/g1-pos.out" \
    'User Review Checkpoint' 'checkpoint-write: 目标文件:'
  if grep -Fq '用户确认：通过' "$R/facts/requirements/tickets/22-g1-review-checkpoint.md" 2>/dev/null; then
    ok 'G1 正例：Checkpoint 记录裁决原文'
  else
    bad 'G1 正例：Checkpoint 记录裁决原文' '独立 checkpoint 文件缺裁决原文'
  fi
}

adv_g2() {
  adv_need "$SCRIPT_DIR/run-record.sh" 'G2' || return 0
  adv_run_record_fixture "$D/g2"
  adv_run_record_seal_pair "$D/g2"
}

adv_g3() {
  adv_need "$SCRIPT_DIR/ticket-audit.sh" 'G3' || return 0
  R=$D/g3
  adv_audit_fixture "$R" 'reviewer@example.com' 'reviewer@example.com'
  sh "$SCRIPT_DIR/ticket-audit.sh" 41 --repo "$R" --operation merge > "$D/g3-pos.out" 2>&1
  _rc=$?
  adv_want 'G3 正例：独立审查者 → merge conformant' "$_rc" 0 "$D/g3-pos.out" \
    'PASS P08 reviewer-distinct-from-implementer' '判定: conformant'
  R2=$D/g3neg
  adv_audit_fixture "$R2" 'fixture@example.com' 'fixture@example.com'
  sh "$SCRIPT_DIR/ticket-audit.sh" 41 --repo "$R2" --operation merge > "$D/g3-neg.out" 2>&1
  _rc=$?
  adv_want 'G3 负例：自签 → P08 非 conformant' "$_rc" 1 "$D/g3-neg.out" \
    'FAIL P08 reviewer-distinct-from-implementer' '判定: nonconformant'
}

adv_g4() {
  adv_need "$SCRIPT_DIR/lane-commit.sh" 'G4' || return 0
  R=$D/g4
  adv_lane_fixture "$R"
  adv_git "$R" checkout -- a.txt
  _head=$(adv_head "$R")
  rm -f "$R/facts/project/changes.jsonl"
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/lane-commit.sh" \
    --record-commit "$R" 'adversarial record' facts/project/changes.jsonl) > "$D/g4-neg.out" 2>&1
  _rc=$?
  adv_want 'G4 负例：删除记录文件 → 记录提交拒绝' "$_rc" 1 "$D/g4-neg.out" \
    '记录提交拒绝：记录路径在工作树不存在'
  adv_same 'G4 负例：零提交（HEAD 不变）' "$_head" "$(adv_head "$R")"
  adv_git "$R" checkout -- facts/project/changes.jsonl
  printf '%s\n' '{"date":"2026-10-29","kind":"change","scope":"g4","decision":"restored","evidence_ref":"facts/project/changes.jsonl"}' \
    >> "$R/facts/project/changes.jsonl"
  _count=$(git -C "$R" rev-list --count HEAD)
  (cd "$R" && TMPDIR="$D/tmp" sh "$R/rules/implementation/scripts/lane-commit.sh" \
    --record-commit "$R" 'adversarial record' facts/project/changes.jsonl) > "$D/g4-pos.out" 2>&1
  _rc=$?
  adv_want 'G4 正例：恢复后尾部追加 → 记录提交成功' "$_rc" 0 "$D/g4-pos.out" \
    'lane-commit: 记录提交 ' 'lane-commit: 记录文件: facts/project/changes.jsonl'
  if [ "$(git -C "$R" rev-list --count HEAD)" -eq "$((_count + 1))" ] \
    && [ "$(git -C "$R" show --name-only --format= HEAD | grep -c .)" -eq 1 ] \
    && git -C "$R" show --name-only --format= HEAD | grep -qx 'facts/project/changes.jsonl'; then
    ok 'G4 正例：记录提交恰含 changes.jsonl 且 HEAD 前进一次'
  else
    bad 'G4 正例：记录提交恰含 changes.jsonl 且 HEAD 前进一次' \
      "count=$(git -C "$R" rev-list --count HEAD) 期望=$((_count + 1))"
  fi
}

adv_g5() {
  adv_need "$SCRIPT_DIR/upgrade-check.sh" 'G5' || return 0
  P=$D/g5pkg
  adv_pkg_fixture "$P"
  R=$D/g5repo
  rm -rf "$R"
  adv_modern_repo "$R" "$P"
  mkdir -p "$R/rules/implementation/scripts"
  cp "$P/scripts/upgrade-check.sh" "$R/rules/implementation/scripts/upgrade-check.sh"
  cp "$P/scripts/generate-progress.sh" "$R/rules/implementation/scripts/generate-progress.sh"
  sh "$SCRIPT_DIR/upgrade-check.sh" "$P" "$R" > "$D/g5-pos.out" 2>&1
  _rc=$?
  adv_want 'G5 正例：单布局与包基线一致 → exit 0' "$_rc" 0 "$D/g5-pos.out" \
    '布局: modern' '自动检查面无差距'
  R2=$D/g5neg
  rm -rf "$R2"
  adv_modern_repo "$R2" "$P"
  mkdir -p "$R2/rules/implementation/scripts" "$R2/scripts"
  cp "$P/scripts/upgrade-check.sh" "$R2/rules/implementation/scripts/upgrade-check.sh"
  cp "$P/scripts/generate-progress.sh" "$R2/rules/implementation/scripts/generate-progress.sh"
  cp "$P/scripts/upgrade-check.sh" "$R2/scripts/upgrade-check.sh"
  cp "$P/scripts/generate-progress.sh" "$R2/scripts/generate-progress.sh"
  printf '# divergent legacy copy\n' >> "$R2/scripts/upgrade-check.sh"
  sh "$SCRIPT_DIR/upgrade-check.sh" "$P" "$R2" > "$D/g5-neg.out" 2>&1
  _rc=$?
  adv_want 'G5 负例：双布局冲突 → exit 1 且不静默选边' "$_rc" 1 "$D/g5-neg.out" \
    '冲突  upgrade-check.sh 同时位于' '漂移  scripts/upgrade-check.sh（旧布局'
}

# ---- 正常路径：一票 ready→done ----

adv_normal_path() {
  _np_need=0
  for _f in ticket-run.sh worktree-add.sh contract-build.sh check-dispatch-contract.sh dp-load-rules.sh \
    ticket-ops.sh check-gates.sh generate-progress.sh generate-dir-readmes.sh dir-readme.rules ledger-append.sh \
    record-store.sh common-helpers.sh json-validator.py ticket-audit.sh; do
    [ -s "$SCRIPT_DIR/$_f" ] || { bad '正常路径 前置件在场' "缺件: $SCRIPT_DIR/$_f"; _np_need=1; }
  done
  [ "$_np_need" -eq 0 ] || return 0
  MAIN=$D/normal/main
  mkdir -p "$D/normal/tmp"
  adv_ticket_run_fixture "$MAIN"
  WT=$(realpath "$D/normal")/main-wt/wt90
  _tr() { run_in_fixture "$MAIN" env TMPDIR="$D/normal/tmp" sh "$MAIN/rules/implementation/scripts/ticket-run.sh" "$@"; }
  _tr 90 start "$MAIN" > "$D/np-start.out" 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ] && [ -d "$WT" ] \
    && grep -Fq 'ticket-run: 票状态: in_progress' "$D/np-start.out" \
    && grep -q '"id": "90-run-fixture", "status": "in_progress"' "$MAIN/facts/requirements/tickets/index.json"; then
    ok '正常路径 P1 ready→start 建站并领取为 in_progress'
  else
    bad '正常路径 P1 ready→start 建站并领取为 in_progress' "exit=$_rc $(tr '\n' '|' < "$D/np-start.out" | cut -c1-400)"
  fi
  _tr 90 implementation "$MAIN" > "$D/np-impl.out" 2>&1
  _rc=$?
  _impl_contract=$(sed -n 's/^ticket-run: 合同文件: //p' "$D/np-impl.out")
  if [ "$_rc" -eq 0 ] && [ -n "$_impl_contract" ] && [ -f "$_impl_contract" ]; then
    ok '正常路径 P2 implementation 产出站与合同'
  else
    bad '正常路径 P2 implementation 产出站与合同' "exit=$_rc $(tr '\n' '|' < "$D/np-impl.out" | cut -c1-400)"
  fi
  _tr 90 review "$MAIN" > "$D/np-review.out" 2>&1
  _rc=$?
  adv_want '正常路径 P3 review 复用站并产出合同' "$_rc" 0 "$D/np-review.out" 'ticket-run: 合同文件:'
  printf 'Verdict: **PASS**\n' > "$WT/facts/requirements/tickets/90-run-fixture-review-checkpoint.md"
  _base=$(adv_head "$WT")
  printf 'implemented v2\n' >> "$WT/product.txt"
  git -C "$WT" add product.txt
  git -C "$WT" -c user.email=fixture@example.com -c user.name=fixture -c commit.gpgsign=false \
    commit -qm 'product implementation'
  _head=$(adv_head "$WT")
  _excl=$(git -C "$WT" rev-parse --git-path info/exclude)
  case $_excl in /*) ;; *) _excl="$WT/$_excl" ;; esac
  mkdir -p "$(dirname "$_excl")"
  printf '%s\n' 'facts/requirements/audit-policy.json' >> "$_excl"
  printf '{"schema_version":1,"policy_id":"normal-path-fixture","effective_from":"2026-01-01","baseline_sha":"%s","release_baseline":"none","trusted_reviewers":["reviewer@example.com"],"implementation_identities":["fixture@example.com"]}\n' \
    "$_base" > "$WT/facts/requirements/audit-policy.json"
  receipt "$WT/facts/requirements/tickets/90-run-fixture.review-evidence.json" "$WT" "$_base" "$_head" \
    90-run-fixture --created-at "$(date -u +%Y-%m-%d)T12:00:00Z" \
    --reviewed-at "$(date -u +%Y-%m-%d)T12:00:00Z"
  git -C "$WT" config user.email reviewer@example.com
  git -C "$WT" config user.name reviewer
  _count=$(git -C "$WT" rev-list --count HEAD)
  _tr 90 commit "$MAIN" > "$D/np-commit.out" 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ] \
    && grep -q '"id": "90-run-fixture", "status": "done"' "$WT/facts/requirements/tickets/index.json" \
    && grep -Fq '| 90-run-fixture | done |' "$WT/facts/requirements/tickets/progress-current.md" \
    && grep -Fq 'ticket-run: 产品提交:' "$D/np-commit.out" \
    && grep -Fq 'ticket-run: 记录提交:' "$D/np-commit.out"; then
    ok '正常路径 P4 commit 完成产品/记录两段提交并翻 done＋投影'
  else
    bad '正常路径 P4 commit 完成产品/记录两段提交并翻 done＋投影' \
      "exit=$_rc $(tr '\n' '|' < "$D/np-commit.out" | cut -c1-500)"
  fi
  if [ "$(git -C "$WT" rev-list --count HEAD)" -eq "$((_count + 2))" ]; then
    ok '正常路径 P5 收口后 HEAD 恰前进两次（产品＋记录）'
  else
    bad '正常路径 P5 收口后 HEAD 恰前进两次（产品＋记录）' \
      "count=$(git -C "$WT" rev-list --count HEAD) 期望=$((_count + 2))"
  fi
}

# ---- 安装面：run-record seal 与 upgrade-check（install.sh 为 main-only 件） ----

adv_install_surface() {
  INST="$SCRIPT_DIR/install.sh"
  if [ ! -s "$INST" ]; then
    printf 'SKIP  [adversarial] install.sh 不在场（%s；worktree 栅栏排除 main-only 件）——安装后 run-record seal/upgrade-check 场景跳过，覆盖归主检出：--script-dir <主检出>/agent-up/scripts --pkg-root <主检出>/agent-up\n' "$INST"
    return 0
  fi
  adv_need "$SCRIPT_DIR/upgrade-check.sh" 'AC2' || return 0
  SEED=$D/install/seed
  mkdir -p "$D/install"
  adv_seed_governance "$SEED"
  git_repo "$SEED"
  adv_commit "$SEED" seed
  (cd "$D/install" && sh "$INST" --target "$SEED" --ticket-ops) > "$D/ac2-install.out" 2>&1
  _rc=$?
  adv_want 'AC2 安装器把 ticket-ops 闭包写入 Seed 项目' "$_rc" 0 "$D/ac2-install.out" 'OK'
  adv_close_dir_readmes "$SEED" 'AC2'
  _inst_rr="$SEED/rules/implementation/scripts/run-record.sh"
  if adv_need "$_inst_rr" 'AC2 安装后 run-record'; then
    sh "$_inst_rr" "$SEED" new --ticket 10-seed-fixture > "$D/ac2-rr-new.out" 2>&1
    _rc=$?
    _rrfile=$(LC_ALL=C find "$SEED/facts/requirements/runs" -name '*.json' -type f 2>/dev/null | head -n 1)
    if [ "$_rc" -eq 0 ] && [ -n "$_rrfile" ]; then
      adv_run_record_fill "$_rrfile"
      sh "$_inst_rr" "$SEED" seal --file "$_rrfile" > "$D/ac2-rr-seal.out" 2>&1
      _rc=$?
      adv_want 'AC2 安装布局 run-record new＋seal 真跑通过' "$_rc" 0 "$D/ac2-rr-seal.out" 'seal 通过'
    else
      bad 'AC2 安装布局 run-record new 生成骨架' "exit=$_rc $(tr '\n' '|' < "$D/ac2-rr-new.out")"
    fi
  fi
  (cd "$D/install" && sh "$INST" --target "$SEED" --ticket-ops) > "$D/ac2-reinstall.out" 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ] && grep -q 'SKIP' "$D/ac2-reinstall.out"; then
    ok 'AC2 幂等重跑安装器：已一致件 SKIP'
  else
    bad 'AC2 幂等重跑安装器：已一致件 SKIP' "exit=$_rc $(tr '\n' '|' < "$D/ac2-reinstall.out" | cut -c1-300)"
  fi
  sh "$SCRIPT_DIR/upgrade-check.sh" "$PKG_ROOT" "$SEED" > "$D/ac2-upgrade.out" 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ] && grep -Fq '自动检查面无差距' "$D/ac2-upgrade.out" \
    && grep -Fq '落后 0，漂移 0，双布局冲突 0' "$D/ac2-upgrade.out"; then
    ok 'AC2 现行 upgrade-check 对安装后 Seed 真跑 exit 0（无落后/漂移/冲突）'
  else
    bad 'AC2 现行 upgrade-check 对安装后 Seed 真跑 exit 0（无落后/漂移/冲突）' \
      "exit=$_rc $(grep -E '落后|漂移|冲突|结构无效' "$D/ac2-upgrade.out" | head -n 3 | tr '\n' '|')"
  fi
}

# ---- 临时副本升级切换：零手工改 rules/ 与 .zcode/，旧文件标旧布局 ----

adv_upgrade_switch() {
  INST="$SCRIPT_DIR/install.sh"
  if [ ! -s "$INST" ]; then
    printf 'SKIP  [adversarial] install.sh 不在场（%s；worktree 栅栏排除 main-only 件）——临时副本升级切换场景跳过，覆盖归主检出\n' "$INST"
    return 0
  fi
  OLD=$D/upgrade/old
  FRESH=$D/upgrade/fresh
  mkdir -p "$D/upgrade"
  adv_seed_governance "$OLD"
  mkdir -p "$OLD/docs/agent/roles" "$OLD/scripts"
  printf '# legacy process\n' > "$OLD/docs/development-process.md"
  printf '# legacy docs\n' > "$OLD/docs/README.md"
  printf '# legacy artifacts\n' > "$OLD/docs/agent/artifacts.yaml"
  for _ur in implementation review commit; do
    printf '# legacy role %s\n' "$_ur" > "$OLD/docs/agent/roles/$_ur.md"
  done
  cp "$SCRIPT_DIR/upgrade-check.sh" "$OLD/scripts/upgrade-check.sh"
  cp "$SCRIPT_DIR/generate-progress.sh" "$OLD/scripts/generate-progress.sh"
  _adv_repo_root=$(CDPATH='' cd -- "$PKG_ROOT/.." && pwd) || _adv_repo_root=''
  if [ -n "$_adv_repo_root" ] && [ -d "$_adv_repo_root/.zcode" ]; then
    pkg_copy "$_adv_repo_root/.zcode" "$OLD/.zcode"
  fi
  git_repo "$OLD"
  adv_commit "$OLD" 'old project baseline'
  _source_commit=$(adv_head "$OLD")
  _zcode_before=$(adv_tree_sig "$OLD/.zcode")
  _old_script_sig=$(adv_sig "$OLD/scripts/upgrade-check.sh")
  (cd "$D/upgrade" && sh "$INST" --target "$OLD" --ticket-ops --fast-lane) > "$D/ac3-install.out" 2>&1
  _rc=$?
  adv_want 'AC3 临时副本执行工具升级（install --ticket-ops --fast-lane）' "$_rc" 0 "$D/ac3-install.out" 'OK'
  printf '升级来源提交: %s\n' "$_source_commit"
  _zcode_after=$(adv_tree_sig "$OLD/.zcode")
  adv_same 'AC3 升级后 .zcode/ 字节零改动' "$_zcode_before" "$_zcode_after"
  git -C "$OLD" status --porcelain -uall > "$D/ac3-status.txt"
  _manual=0
  _manual_list=''
  while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _p=${_line#?? }
    case $_p in
      rules/implementation/scripts/*|rules/implementation/references/*) ;;
      rules/*|.zcode/*) _manual=$((_manual + 1)); _manual_list="$_manual_list $_p" ;;
    esac
  done < "$D/ac3-status.txt"
  if [ "$_manual" -eq 0 ]; then
    ok 'AC3 rules/ 与 .zcode/ 手工改动计数为零（变更面恰为安装器落位路径）'
  else
    bad 'AC3 rules/ 与 .zcode/ 手工改动计数为零（变更面恰为安装器落位路径）' \
      "手工改动 ${_manual} 处:${_manual_list}"
  fi
  adv_seed_governance "$FRESH"
  git_repo "$FRESH"
  adv_commit "$FRESH" fresh
  (cd "$D/upgrade" && sh "$INST" --target "$FRESH" --ticket-ops --fast-lane) > "$D/ac3-fresh.out" 2>&1
  _rc=$?
  if [ "$_rc" -eq 0 ] && diff -r "$OLD/rules" "$FRESH/rules" > "$D/ac3-diff.out" 2>&1; then
    ok 'AC3 升级后 rules/ 与全新工具安装逐字节一致（治理面由工具生成）'
  else
    bad 'AC3 升级后 rules/ 与全新工具安装逐字节一致（治理面由工具生成）' \
      "exit=$_rc $(head -n 3 "$D/ac3-diff.out" | tr '\n' '|')"
  fi
  if [ -f "$OLD/scripts/upgrade-check.sh" ] \
    && [ "$(adv_sig "$OLD/scripts/upgrade-check.sh")" = "$_old_script_sig" ]; then
    ok 'AC7 旧 scripts/ 文件升级后仍在且字节不变（零静默覆盖）'
  else
    bad 'AC7 旧 scripts/ 文件升级后仍在且字节不变（零静默覆盖）' '旧文件缺失或被覆盖'
  fi
  sh "$SCRIPT_DIR/upgrade-check.sh" "$PKG_ROOT" "$OLD" > "$D/ac7-upgrade.out" 2>&1
  _rc=$?
  if grep -Fq '布局: mixed' "$D/ac7-upgrade.out" \
    && grep -Fq '同步  scripts/upgrade-check.sh（旧布局' "$D/ac7-upgrade.out" \
    && grep -Fq '人工核对 docs/development-process.md' "$D/ac7-upgrade.out"; then
    ok 'AC7 旧项目标 mixed/旧布局并逐件提示人工核对（需用户确认后移除）'
  else
    bad 'AC7 旧项目标 mixed/旧布局并逐件提示人工核对（需用户确认后移除）' \
      "exit=$_rc $(grep -E '布局|旧布局|人工核对' "$D/ac7-upgrade.out" | head -n 4 | tr '\n' '|')"
  fi
  CONFLICT=$D/upgrade/conflict
  adv_seed_governance "$CONFLICT"
  mkdir -p "$CONFLICT/rules/implementation/scripts"
  printf '# manually diverged\n' > "$CONFLICT/rules/implementation/scripts/ticket-ops.sh"
  _conflict_sig=$(adv_sig "$CONFLICT/rules/implementation/scripts/ticket-ops.sh")
  (cd "$D/upgrade" && sh "$INST" --target "$CONFLICT" --ticket-ops) > "$D/ac7-conflict.out" 2>&1
  _rc=$?
  adv_want 'AC7 安装器遇人工漂移停手（不覆盖）' "$_rc" 1 "$D/ac7-conflict.out" \
    '目标同名件与包内基线不一致'
  adv_same 'AC7 停手后人工件字节不变' "$_conflict_sig" \
    "$(adv_sig "$CONFLICT/rules/implementation/scripts/ticket-ops.sh")"
}

# ---- 纯文档项目与 Seed 项目前置流程 ----

adv_doc_seed() {
  adv_need "$SCRIPT_DIR/generate-module-map.sh" 'AC4' || return 0
  adv_need "$SCRIPT_DIR/check-artifacts.sh" 'AC4' || return 0
  DOC=$D/doc/docproj
  rm -rf "$D/doc"; mkdir -p "$DOC/docs"
  printf '# 纯文档项目\n' > "$DOC/README.md"
  printf '说明\n' > "$DOC/docs/note.md"
  git_repo "$DOC"
  adv_commit "$DOC" doc
  sh "$SCRIPT_DIR/generate-module-map.sh" "$DOC" > "$D/ac4-doc.out" 2>&1
  _rc=$?
  _map="$DOC/facts/project/architecture/module-map.json"
  if [ "$_rc" -eq 0 ] && [ -f "$_map" ] \
    && python3 - "$_map" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    d = json.load(fh)
sys.exit(0 if d.get('nodes') == [] and d.get('edges') == [] else 1)
PY
  then
    ok 'AC4 纯文档项目：module-map 生成空 nodes/edges 合法地图 exit 0'
  else
    bad 'AC4 纯文档项目：module-map 生成空 nodes/edges 合法地图 exit 0' "exit=$_rc $(tail -n 2 "$D/ac4-doc.out" | tr '\n' '|')"
  fi
  SEED2=$D/doc/seed
  adv_seed_governance "$SEED2"
  sh "$SCRIPT_DIR/check-artifacts.sh" "$SEED2" > "$D/ac4-seed.out" 2>&1
  _rc=$?
  adv_want 'AC4 Seed 初始化项目：check-artifacts PASS（登记与实际一一对应）' "$_rc" 0 \
    "$D/ac4-seed.out" 'check-artifacts: PASS'
  if [ -s "$SCRIPT_DIR/install.sh" ]; then
    (cd "$D/doc" && sh "$SCRIPT_DIR/install.sh" --target "$SEED2" --ticket-ops) > "$D/ac4-install.out" 2>&1
    _rc=$?
    if [ "$_rc" -eq 0 ]; then
      adv_close_dir_readmes "$SEED2" 'AC4'
      sh "$SCRIPT_DIR/upgrade-check.sh" "$PKG_ROOT" "$SEED2" > "$D/ac4-upgrade.out" 2>&1
      _rc=$?
      if [ "$_rc" -eq 0 ] && grep -Fq '自动检查面无差距' "$D/ac4-upgrade.out"; then
        ok 'AC4 Seed 初始化项目装工具并收口目录 README 后：upgrade-check 自动检查面无差距'
      else
        bad 'AC4 Seed 初始化项目装工具并收口目录 README 后：upgrade-check 自动检查面无差距' \
          "exit=$_rc $(grep -E '落后|漂移|冲突|结构无效' "$D/ac4-upgrade.out" | head -n 3 | tr '\n' '|')"
      fi
    else
      bad 'AC4 Seed 初始化项目装工具并收口目录 README 后：upgrade-check 自动检查面无差距' \
        "install exit=$_rc $(tail -n 3 "$D/ac4-install.out" | tr '\n' '|')"
    fi
  else
    printf 'SKIP  [adversarial] AC4 Seed 初始化项目 upgrade-check（install.sh 不在场：%s；未装工具的项目自动检查面不适用，覆盖归主检出）\n' "$SCRIPT_DIR"
  fi
}

# ---- 套件入口 ----

suite_adversarial() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='adversarial'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/adv
  mkdir -p "$D" "$D/tmp"
  adv_c1
  adv_c2
  adv_c3
  adv_c4
  adv_c5
  adv_c6
  adv_c7
  adv_c8
  adv_c9
  adv_c10
  adv_g1
  adv_g2
  adv_g3
  adv_g4
  adv_g5
  adv_normal_path
  adv_install_surface
  adv_upgrade_switch
  adv_doc_seed
  suite_summary 'adversarial'
}
