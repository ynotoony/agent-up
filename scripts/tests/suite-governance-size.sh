#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != "1" ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite governance-size "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用
# ============================================================
# suite: governance-size（安装面预算回归）
#   预算表内嵌于本套件：9 件安装件逐件上限 + 合计 ≤30000 + 安装面规则块恰 10 +
#   核心规则 G 覆盖（逐条带 G1–G5）+ 每阶段读取集 ≤15000 + 隔离门槛在位 +
#   安装件不得引用未安装手册（悬空指针防复发）。
#   字符数口径＝python3 len(text)（中文按字计）；超限即 FAIL 并打印实测值与上限。
#   9 件＝AGENTS + core + project + assessment + discipline + 四份角色合同。
# ============================================================

GOV_INSTALL_FILES='AGENTS.md.tmpl core.md.tmpl project.md.tmpl assessment.md.tmpl discipline.md.tmpl agents-triage.md.tmpl agents-implementation.md.tmpl agents-review.md.tmpl agents-commit.md.tmpl'
GOV_LIMIT_AGENTS=1800
GOV_LIMIT_CORE=4400
GOV_LIMIT_PROJECT=3200
GOV_LIMIT_ASSESSMENT=2800
GOV_LIMIT_DISCIPLINE=4600
GOV_LIMIT_ROLE=2600
GOV_TOTAL_LIMIT=30000
GOV_BLOCK_TOTAL=10

gov_limit_for() {
  case $1 in
    AGENTS.md.tmpl) printf '%s' "$GOV_LIMIT_AGENTS" ;;
    core.md.tmpl) printf '%s' "$GOV_LIMIT_CORE" ;;
    project.md.tmpl) printf '%s' "$GOV_LIMIT_PROJECT" ;;
    assessment.md.tmpl) printf '%s' "$GOV_LIMIT_ASSESSMENT" ;;
    discipline.md.tmpl) printf '%s' "$GOV_LIMIT_DISCIPLINE" ;;
    *) printf '%s' "$GOV_LIMIT_ROLE" ;;
  esac
}

suite_governance_size() {
  # shellcheck disable=SC2034
  CUR_SUITE='governance-size'
  # shellcheck disable=SC2034
  SUITE_FAILS=0
  # shellcheck disable=SC2034
  SUITE_START=$TOTAL
  TPL="$PKG_ROOT/references/templates"
  total=0

  if ! command -v python3 >/dev/null 2>&1; then
    bad 'python3 可用（字符数口径依赖）' 'python3 不在 PATH'
    suite_summary 'governance-size'
    return 1
  fi

  for f in $GOV_INSTALL_FILES; do
    limit=$(gov_limit_for "$f")
    if [ ! -f "$TPL/$f" ]; then
      bad "安装件在场: $f" '缺件'
      continue
    fi
    n=$(python3 -c 'import sys;print(len(open(sys.argv[1],encoding="utf-8").read()))' "$TPL/$f")
    total=$((total + n))
    if [ "$n" -le "$limit" ]; then
      ok "字数预算: $f ${n} ≤ ${limit}"
    else
      bad "字数预算: $f ${n} ≤ ${limit}" "实测 ${n} 超上限 ${limit}"
    fi
  done

  if [ "$total" -le "$GOV_TOTAL_LIMIT" ]; then
    ok "安装面合计 ${total} ≤ ${GOV_TOTAL_LIMIT}"
  else
    bad "安装面合计 ${total} ≤ ${GOV_TOTAL_LIMIT}" "实测 ${total} 超上限 ${GOV_TOTAL_LIMIT}"
  fi

  blocks=0
  for f in $GOV_INSTALL_FILES; do
    [ -f "$TPL/$f" ] || continue
    c=$(grep -c '^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]' "$TPL/$f" 2>/dev/null || true)
    blocks=$((blocks + ${c:-0}))
  done
  if [ "$blocks" -eq "$GOV_BLOCK_TOTAL" ]; then
    ok "安装面规则块恰 ${GOV_BLOCK_TOTAL} 个"
  else
    bad "安装面规则块恰 ${GOV_BLOCK_TOTAL} 个" "实测 ${blocks} 个（上限/期望 ${GOV_BLOCK_TOTAL}）"
  fi

  # 核心规则 G 覆盖：10 条逐条带（G1）～（G5），且五条保证各至少出现一次
  _co_file="$TPL/core.md.tmpl"
  _co_tagged=$(grep -cE '^#### R-CO-[0-9]{3}.*（G[1-5]' "$_co_file" 2>/dev/null || true)
  if [ "${_co_tagged:-0}" -eq "$GOV_BLOCK_TOTAL" ]; then
    ok "核心规则 G 覆盖: ${_co_tagged}/${GOV_BLOCK_TOTAL} 条带 G 标注"
  else
    bad "核心规则 G 覆盖: ${_co_tagged}/${GOV_BLOCK_TOTAL} 条带 G 标注" "逐条须带（G1）～（G5）之一"
  fi
  _co_missing_g=''
  for g in 1 2 3 4 5; do grep -q "（G$g" "$_co_file" || _co_missing_g="$_co_missing_g G$g"; done
  if [ -z "$_co_missing_g" ]; then
    ok '核心规则覆盖 G1–G5 五条保证'
  else
    bad '核心规则覆盖 G1–G5 五条保证' "缺:$_co_missing_g"
  fi

  GOV_STAGE_LIMIT=15000
  gov_stage_check() {
    _gs_name=$1; shift
    _gs_sum=0
    for _gs_f in "$@"; do
      if [ ! -f "$TPL/$_gs_f" ]; then bad "每阶段读取集: $_gs_name 缺件 $_gs_f" '缺件'; return; fi
      _gs_n=$(python3 -c 'import sys;print(len(open(sys.argv[1],encoding="utf-8").read()))' "$TPL/$_gs_f")
      _gs_sum=$((_gs_sum + _gs_n))
    done
    if [ "$_gs_sum" -le "$GOV_STAGE_LIMIT" ]; then
      ok "每阶段读取集: $_gs_name ${_gs_sum} ≤ ${GOV_STAGE_LIMIT}"
    else
      bad "每阶段读取集: $_gs_name ${_gs_sum} ≤ ${GOV_STAGE_LIMIT}" "实测 ${_gs_sum} 超上限"
    fi
  }
  gov_stage_check triage AGENTS.md.tmpl core.md.tmpl assessment.md.tmpl project.md.tmpl agents-triage.md.tmpl
  gov_stage_check implementation AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-implementation.md.tmpl
  gov_stage_check review AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-review.md.tmpl
  gov_stage_check commit AGENTS.md.tmpl core.md.tmpl project.md.tmpl agents-commit.md.tmpl

  if grep -q '^### 3\.1 工作隔离门槛' "$TPL/project.md.tmpl"; then
    ok 'project.md.tmpl 含 §3.1 工作隔离门槛'
  else
    bad 'project.md.tmpl 含 §3.1 工作隔离门槛' '缺该节'
  fi

  # 安装面零模糊措辞（与包检检查 12 同词表；此处只测安装面九件）
  vague=$(grep -nE '尽量|适当|必要时|通常|原则上|酌情' $(
    for f in $GOV_INSTALL_FILES; do printf '%s ' "$TPL/$f"; done
  ) 2>/dev/null || true)
  if [ -z "$vague" ]; then
    ok '安装面九件零模糊措辞'
  else
    bad '安装面九件零模糊措辞' "$(printf '%s\n' "$vague" | sed -n '1,6p')"
  fi

  # 安装件不得引用未安装手册：逐行扫未安装手册名与 references/ 子目录前缀（protocol/
  # adapters/prompts 均不在安装闭包；references/schemas 只装了条件件
  # ticket-record／dispatch-contract，故按文件名禁 ledger-row.schema.json 而不整目录禁）。
  # 用法: gov_uninstalled_refs <模板目录>；命中输出「<文件>:<行号>:<行>」。
  gov_uninstalled_refs() {
    _gur_dir=$1
    for _gur_f in $GOV_INSTALL_FILES; do
      [ -f "$_gur_dir/$_gur_f" ] || continue
      LC_ALL=C grep -nE 'read-policy|capability-contract|governance-format|complexity-profile|adapter-template|ledger-row\.schema\.json|references/protocol/|references/adapters/|references/prompts/' "$_gur_dir/$_gur_f" 2>/dev/null \
        | sed "s|^|$_gur_f:|"
    done
  }
  _gur_lbl='安装件零未安装手册引用（9 件无 read-policy／protocol／adapters／prompts／ledger-row 指针）'
  _gur_hit=$(gov_uninstalled_refs "$TPL")
  if [ -z "$_gur_hit" ]; then
    ok "$_gur_lbl"
  else
    bad "$_gur_lbl" "$(printf '%s\n' "$_gur_hit" | sed -n '1,8p')"
  fi
  # 负例：临时副本注入两条悬空指针 → 扫描器必须逐条指名文件:行号（断言不得空转）
  _gur_fx="$T/govsize-fixture"
  rm -rf "$_gur_fx"
  mkdir -p "$_gur_fx"
  for _gur_f in $GOV_INSTALL_FILES; do [ -f "$TPL/$_gur_f" ] && cp "$TPL/$_gur_f" "$_gur_fx/$_gur_f"; done
  printf '\n- 悬空指针夹具：写入边界见 `references/protocol/read-policy.md` §2.3.1。\n' >> "$_gur_fx/agents-triage.md.tmpl"
  printf '\n- 悬空指针夹具：行型合同单源＝`references/schemas/ledger-row.schema.json`。\n' >> "$_gur_fx/agents-review.md.tmpl"
  _gur_neg=$(gov_uninstalled_refs "$_gur_fx")
  _gur_neg_ok=1
  printf '%s\n' "$_gur_neg" | grep -q '^agents-triage\.md\.tmpl:[0-9][0-9]*:.*read-policy' || _gur_neg_ok=0
  printf '%s\n' "$_gur_neg" | grep -q '^agents-review\.md\.tmpl:[0-9][0-9]*:.*ledger-row\.schema\.json' || _gur_neg_ok=0
  if [ "$_gur_neg_ok" = 1 ]; then
    ok '负例：注入 read-policy／ledger-row 悬空指针 → 扫描器逐条指名文件:行号（断言非空转）'
  else
    bad '负例：注入 read-policy／ledger-row 悬空指针 → 扫描器逐条指名文件:行号（断言非空转）' "$(printf '%s\n' "$_gur_neg" | sed -n '1,3p')"
  fi

  # 安装面零待定标记与占位残留
  pend=$(grep -nE '【待定|待补充|TODO' $(
    for f in $GOV_INSTALL_FILES; do printf '%s ' "$TPL/$f"; done
  ) 2>/dev/null || true)
  if [ -z "$pend" ]; then
    ok '安装面九件零待定/TODO 标记'
  else
    bad '安装面九件零待定/TODO 标记' "$(printf '%s\n' "$pend" | sed -n '1,6p')"
  fi

  suite_summary 'governance-size'
}
