#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite role-prompt "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）

# ============================================================
# suite: role-prompt（角色合同/Prompt 权威边界断言：角色合同模板是 MUST 行为
# 规则与写入权限正文的唯一承载面，派发 Prompt 只承载派发参数、上下文与输出槽。
# 正例＝四件角色合同模板权威面在位（能力声明行＋规则块）＋现行三件 Prompt 零
# 合同正文＋Triage 模板登记闭合（数据表＋manifest 投影）＋占位符全集零漂移＋五宿主
# 映射去重态（单一公共规则权威指针段在位、零规则块、零公共规则正文）＋结构模板
# 不复述规范正文＋入口术语统一（路由层 Triage＋编码层三阶段，票 218 AC1/AC2）；
# 负例＝duplicate-body Prompt 夹具（复制合同正文进 Prompt）扫描器
# 指名角色失败、parameter/context/output-only Prompt 夹具通过、duplicate-rule 与
# missing-permission 角色合同夹具经 check-package 指名角色失败（检查 22/14）、
# Triage 模板缺权限声明夹具结构断言指名角色失败、公共规则正文回写宿主夹具去重
# 扫描失败。票 238 追加能力收窄面：四件合同声明面与执行能力一致（triage execute
# 白名单／impl git_write_enforcement 降级义务／review 只写审查证据／commit 仅编排
# 入口）＋capability-contract §2.2 与五宿主 §2.3 投影同口径，含六条删/注入负例
# （N10 impl 删 git_write_enforcement／N11 commit 白名单外脚本／N12 triage 派发前置
# 失实现阶段限定）。票 253 步数预算：三份角色模板 R-RI-005 正例（步数上限 80＋到线
# 收尾＋另起交接摘要＋可核豁免）＋四负例（N13 删步数上限／N14 删到线收尾／N15 上限
# 为空／N16 上限非数字，均指名失败）。
# 夹具全 mktemp 自建不入仓，被测对象只读；边界扫描为结构性标记代理
# （规则块头/七字段体/权限清单体/输出格式签名），README 叙事面豁免（对齐
# check-package 检查 12 口径））
# ============================================================

# 边界扫描器：对派发 Prompt 目录做「零合同正文」机械断言。
# 违规面＝①规则块头（#### R-XX-NNN，合同正文载体）；②规则块七字段体行；
# ③权限白名单清单体（可写字段/只读字段/收尾记录翻转权限节与 checkpoint/status/
# 索引/投影字段枚举行）；④输出格式正文签名行。README 为叙事面豁免。
# 用法: rp_scan_boundary <prompts-dir>；违规明细输出 stdout（文件:行: 内容），
#       有违规 return 1，清洁 return 0。
rp_scan_boundary() {
  _rpb_dir="$1"
  _rpb_pat='^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]([^0-9]|$)|^- \*\*(When|Action|Forbidden|Stop if|Evidence|Owner|Authority)\*\*|^\*\*(可写字段|只读字段|收尾记录翻转权限)|^- \`(checkpoint\.|status|facts/requirements/tickets/)|^报告不超过'
  _rpb_hits=0
  for _rpb_f in $(find "$_rpb_dir" -maxdepth 1 -name '*.md' ! -name 'README.md' | LC_ALL=C sort); do
    _rpb_out=$(LC_ALL=C grep -nE "$_rpb_pat" "$_rpb_f" 2>/dev/null) || _rpb_out=''
    if [ -n "$_rpb_out" ]; then
      _rpb_hits=$((_rpb_hits + 1))
      printf '%s\n' "$_rpb_out" | sed "s|^|$_rpb_f:|"
    fi
  done
  [ "$_rpb_hits" -eq 0 ]
}

# 角色合同权威面结构断言：required_capabilities 声明行＋C1–C10 指针在位（条款正文归核心规则，合同零规则块）。
# 用法: rp_role_check <template-file>；缺陷明细输出 stdout，缺陷 return 1。
rp_role_check() {
  _rpf_file="$1"
  if [ ! -f "$_rpf_file" ]; then
    printf 'missing-file: %s\n' "$_rpf_file"
    return 1
  fi
  _rpf_bad=0
  if ! LC_ALL=C grep -q '^required_capabilities（运行时）：' "$_rpf_file"; then
    printf 'missing-decl: %s\n' "$_rpf_file"
    _rpf_bad=1
  fi
  if ! LC_ALL=C grep -q 'C1–C10' "$_rpf_file"; then
    printf 'missing-core-pointer: %s\n' "$_rpf_file"
    _rpf_bad=1
  fi
  return "$_rpf_bad"
}

# 入口术语断言（票 218 AC1/AC2）：入口文件须使用统一术语「路由层 Triage＋编码层
# 三阶段」，且不再出现旧称「四个角色」或把 Triage 当编码阶段的并列行。
# 用法: rp_term_check <标签> <文件> <必含 ERE> [禁含 ERE]；缺陷明细输出 stdout，
#       缺陷 return 1，清洁 return 0。
rp_term_check() {
  _rpt_label="$1"
  _rpt_file="$2"
  _rpt_must="$3"
  _rpt_mustnot="$4"
  if [ ! -f "$_rpt_file" ]; then
    printf 'missing-file: %s\n' "$_rpt_file"
    return 1
  fi
  _rpt_bad=0
  if ! LC_ALL=C grep -qE -- "$_rpt_must" "$_rpt_file"; then
    printf 'missing-term: %s\n' "$_rpt_label"
    _rpt_bad=1
  fi
  if [ -n "$_rpt_mustnot" ] && LC_ALL=C grep -qE -- "$_rpt_mustnot" "$_rpt_file"; then
    printf 'stale-term: %s\n' "$_rpt_label"
    _rpt_bad=1
  fi
  return "$_rpt_bad"
}

# 去重态扫描器：宿主映射文件零规则块、零公共规则正文、唯一权威指针段在位。
# 违规面＝①`#### R-` 规则块头（公共规则正文载体）；②公共规则正文回写（映射免责／能力映射
# 与方言同步／独立执行体与降级／§2.4 记录面正文：审查记录字段与 run record 指针句）；
# ③缺「公共规则唯一权威（指针）」段或 capability-contract.md 指针。用法:
# rp_dedupe_check <host-file>；缺陷明细输出 stdout，有缺陷 return 1，清洁 return 0。
rp_dedupe_check() {
  _rpd_file="$1"
  if [ ! -f "$_rpd_file" ]; then
    printf 'missing-file: %s\n' "$_rpd_file"
    return 1
  fi
  _rpd_bad=0
  if LC_ALL=C grep -q '^#### R-' "$_rpd_file"; then
    printf 'rule-block-present: %s\n' "$_rpd_file"
    _rpd_bad=1
  fi
  if LC_ALL=C grep -qE '映射不是事实源|能力映射与方言同步|独立执行体与降级如实记录|审查记录含|run record 可选指针字段' "$_rpd_file"; then
    printf 'public-rule-body-present: %s\n' "$_rpd_file"
    _rpd_bad=1
  fi
  if ! LC_ALL=C grep -q '^### 2.1 公共规则唯一权威（指针）$' "$_rpd_file"; then
    printf 'missing-authority-pointer-section: %s\n' "$_rpd_file"
    _rpd_bad=1
  fi
  if ! LC_ALL=C grep -q 'capability-contract\.md' "$_rpd_file"; then
    printf 'missing-authority-pointer: %s\n' "$_rpd_file"
    _rpd_bad=1
  fi
  return "$_rpd_bad"
}

# 提取角色合同 required_capabilities（运行时）声明行的反引号基元名（逐名一行；
# 只收纯小写字母/连字符 token，编排入口命令等含空格/点号的反引号串不纳入名单）。
rp_decl_names() {
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  LC_ALL=C grep '^required_capabilities（运行时）：' "$1" | head -n 1 \
    | grep -o '`[a-z][a-z-]*`' | tr -d '`'
}

# 能力收窄断言（票 238）：四件角色合同声明面与可执行能力一致，无「零写入但必须
# 运行脚本」类矛盾。triage 声明含 execute 且文件含编排命令白名单与 --check-dispatch
# 派发前置口径（限实现阶段、linked worktree／in_progress）；implementation 声明不含
# vcs-write 且保留 git_write_enforcement 降级记录义务；review 声明含 readonly-execute、
# 写入面仅追加审查证据、不复述「零文件改动」；commit 声明不含 vcs-read/vcs-write、含
# execute、文件含 ticket-run.sh <NN> commit 编排入口，且不点名白名单外脚本。
# 用法: rp_capability_check <templates-dir>；缺陷明细输出 stdout，有缺陷 return 1。
rp_capability_check() {
  _rpc_dir="$1"
  _rpc_bad=0
  _rpc_triage="$_rpc_dir/agents-triage.md.tmpl"
  _rpc_impl="$_rpc_dir/agents-implementation.md.tmpl"
  _rpc_review="$_rpc_dir/agents-review.md.tmpl"
  _rpc_commit="$_rpc_dir/agents-commit.md.tmpl"

  for _rpc_f in "$_rpc_triage" "$_rpc_impl" "$_rpc_review" "$_rpc_commit"; do
    if [ ! -f "$_rpc_f" ]; then
      printf 'missing-file: %s\n' "$_rpc_f"
      _rpc_bad=1
    fi
  done
  if [ "$_rpc_bad" -ne 0 ]; then
    return 1
  fi

  if ! rp_decl_names "$_rpc_triage" | LC_ALL=C grep -qx 'execute'; then
    printf 'triage 声明缺 execute\n'
    _rpc_bad=1
  fi
  for _rpc_need in 'ticket-run.sh' 'check-dispatch-contract.sh --check-dispatch' 'linked worktree' 'in_progress'; do
    if ! LC_ALL=C grep -qF -- "$_rpc_need" "$_rpc_triage"; then
      printf 'triage 缺编排/派发口径: %s\n' "$_rpc_need"
      _rpc_bad=1
    fi
  done

  if rp_decl_names "$_rpc_impl" | LC_ALL=C grep -qx 'vcs-write'; then
    printf 'implementation 声明越权: vcs-write\n'
    _rpc_bad=1
  fi
  if ! LC_ALL=C grep -q 'git_write_enforcement' "$_rpc_impl"; then
    printf 'implementation 缺 git_write_enforcement 降级记录义务\n'
    _rpc_bad=1
  fi
  if ! LC_ALL=C grep -q '降级' "$_rpc_impl"; then
    printf 'implementation 缺降级原因记录义务\n'
    _rpc_bad=1
  fi

  if ! rp_decl_names "$_rpc_review" | LC_ALL=C grep -qx 'readonly-execute'; then
    printf 'review 声明缺 readonly-execute\n'
    _rpc_bad=1
  fi
  if ! LC_ALL=C grep -q '只写审查证据' "$_rpc_review"; then
    printf 'review 缺只写审查证据边界\n'
    _rpc_bad=1
  fi
  if LC_ALL=C grep -q '零文件改动' "$_rpc_review"; then
    printf 'review 含零文件改动旧表述（与追加审查证据矛盾）\n'
    _rpc_bad=1
  fi

  _rpc_cdecl=$(rp_decl_names "$_rpc_commit")
  for _rpc_need in vcs-read vcs-write; do
    if printf '%s\n' "$_rpc_cdecl" | LC_ALL=C grep -qx "$_rpc_need"; then
      printf 'commit 声明越权: %s\n' "$_rpc_need"
      _rpc_bad=1
    fi
  done
  if ! printf '%s\n' "$_rpc_cdecl" | LC_ALL=C grep -qx 'execute'; then
    printf 'commit 声明缺 execute\n'
    _rpc_bad=1
  fi
  if ! LC_ALL=C grep -qF 'ticket-run.sh <NN> commit' "$_rpc_commit"; then
    printf 'commit 缺 ticket-run.sh <NN> commit 编排入口\n'
    _rpc_bad=1
  fi

  # execute 白名单有牙：commit 合同出现的脚本名（含路径与命令形态）只允许 ticket-run.sh；
  # 其它 .sh 即「必须跑但不在白名单」，防止职责回潮绕过能力声明。
  _rpc_cscripts=$(LC_ALL=C grep -oE '[A-Za-z0-9_./-]+\.sh' "$_rpc_commit" \
    | sed 's#.*/##' | LC_ALL=C sort -u)
  for _rpc_s in $_rpc_cscripts; do
    case $_rpc_s in
      ticket-run.sh) ;;
      *)
        printf 'commit 需运行的脚本不在 execute 白名单: %s\n' "$_rpc_s"
        _rpc_bad=1
        ;;
    esac
  done

  # 派发前置只对实现阶段合同成立（review/commit 合同无 REPOSITORY_PATH）：Triage 边界句
  # 须限定实现阶段，否则 review/commit 派发不可满足。
  if ! LC_ALL=C grep -F 'check-dispatch-contract.sh --check-dispatch' "$_rpc_triage" \
    | LC_ALL=C grep -q '实现阶段'; then
    printf 'triage 派发前置未限定实现阶段（review/commit 合同无 REPOSITORY_PATH）\n'
    _rpc_bad=1
  fi

  return "$_rpc_bad"
}

# 步数预算与到线行为断言（票 253 AC1）：模板须含 R-RI-005 判据块，块内两条阈值
# （单任务步数上限：<数字> 默认 80；到线即收尾＋另起交接摘要含已完成项／未完成项／
# 下一步且不重述全文）与可核豁免（理由＋上限值）逐条在场，且无不可判定措辞。
# 缺陷明细输出 stdout，有缺陷 return 1。
rp_step_budget_check() {
  _rps_file="$1"
  if [ ! -f "$_rps_file" ]; then
    printf 'missing-file: %s\n' "$_rps_file"
    return 1
  fi
  _rps_win=$(LC_ALL=C awk '
    /^\*\*R-RI-005/ { inblk = 1; print; next }
    inblk && /^## / { exit }
    inblk && /^\*\*R-[A-Z][A-Z]-[0-9][0-9][0-9]/ { exit }
    inblk { print }
  ' "$_rps_file")
  if [ -z "$_rps_win" ]; then
    printf 'missing-rule: R-RI-005\n'
    return 1
  fi
  _rps_bad=0
  if ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q '步数上限'; then
    printf 'missing-budget: 步数上限\n'
    _rps_bad=1
  fi
  _rps_val=$(printf '%s\n' "$_rps_win" \
    | grep -E '步数上限[[:space:]]*[:：]' | head -n 1 \
    | sed -n 's/.*步数上限[[:space:]]*[:：][[:space:]]*//p' \
    | sed 's/[（(，,；;。].*$//' \
    | sed 's/[[:space:]]*$//')
  if [ -z "$_rps_val" ]; then
    printf 'budget-empty: 步数上限为空\n'
    _rps_bad=1
  else
    case "$_rps_val" in
      *[!0-9]*)
        printf 'budget-non-numeric: 步数上限非数字（%s）\n' "$_rps_val"
        _rps_bad=1
        ;;
      80) ;;
      *)
        printf 'budget-default: 模板缺省值须为 80（实际 %s）\n' "$_rps_val"
        _rps_bad=1
        ;;
    esac
  fi
  if ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q '到线' \
    || ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q '收尾'; then
    printf 'missing-wrapup: 缺到线收尾\n'
    _rps_bad=1
  fi
  for _rps_need in 交接摘要 已完成 未完成 下一步 不重述; do
    if ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q "$_rps_need"; then
      printf 'missing-handoff: 交接摘要要素缺 %s\n' "$_rps_need"
      _rps_bad=1
    fi
  done
  if ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q '理由' \
    || ! printf '%s\n' "$_rps_win" | LC_ALL=C grep -q '上限值'; then
    printf 'missing-exemption: 豁免须可核（理由＋上限值）\n'
    _rps_bad=1
  fi
  if printf '%s\n' "$_rps_win" | LC_ALL=C grep -qE '建议|尽量|尽可能|大致'; then
    printf 'vague-wording: 不可判定措辞承载数值\n'
    _rps_bad=1
  fi
  return "$_rps_bad"
}

suite_role_prompt() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='role-prompt'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/rp
  mkdir -p "$D"
  TMPL="$PKG_ROOT/references/templates"
  PROMPTS="$PKG_ROOT/references/prompts"
  MANIFEST="$SCRIPT_DIR/package-manifest.rules"

  # ---- 正例（现行包，只读）----

  # 正例 P1（×4）：四件角色合同模板承载 MUST/权限唯一权威面（能力声明行＋规则块在位）
  for _p1r in implementation review commit triage; do
    if rp_role_check "$TMPL/agents-$_p1r.md.tmpl" > "$D/p1-$_p1r.out" 2>&1; then
      ok "正例 P1 角色合同承载 MUST/权限唯一权威面：agents-$_p1r.md.tmpl（能力声明行＋C1–C10 指针在位）"
    else
      bad "正例 P1 角色合同承载 MUST/权限唯一权威面：agents-$_p1r.md.tmpl（能力声明行＋C1–C10 指针在位）" "$(cat "$D/p1-$_p1r.out")"
    fi
  done

  # 正例 P2：现行三件派发 Prompt 零合同正文（参数/上下文/输出槽收敛态）
  if rp_scan_boundary "$PROMPTS" > "$D/p2-scan.out" 2>&1; then
    ok '正例 P2 三件派发 Prompt 零合同正文（只承载派发参数、上下文与输出槽）'
  else
    bad '正例 P2 三件派发 Prompt 零合同正文（只承载派发参数、上下文与输出槽）' "$(head -n 5 "$D/p2-scan.out" | tr '\n' '|')"
  fi

  # 正例 P3（×5）：Triage 模板登记闭合——实物在位＋清单数据两行＋manifest 投影两行
  if [ -f "$TMPL/agents-triage.md.tmpl" ]; then
    ok '正例 P3a Triage 模板实物在位：references/templates/agents-triage.md.tmpl'
  else
    bad '正例 P3a Triage 模板实物在位：references/templates/agents-triage.md.tmpl' '文件不存在'
  fi
  if LC_ALL=C grep -q '^pm_template agents-triage\.md\.tmpl$' "$MANIFEST"; then
    ok '正例 P3b Triage 模板入清单数据：pm_template 行在位'
  else
    bad '正例 P3b Triage 模板入清单数据：pm_template 行在位' 'package-manifest.rules 缺 pm_template agents-triage.md.tmpl'
  fi
  if LC_ALL=C grep -q '^pm_shortcode RT references/templates/agents-triage\.md\.tmpl$' "$MANIFEST"; then
    ok '正例 P3c Triage 模板短码登记：pm_shortcode RT 行在位'
  else
    bad '正例 P3c Triage 模板短码登记：pm_shortcode RT 行在位' 'package-manifest.rules 缺 pm_shortcode RT 行'
  fi
  # shellcheck disable=SC2016  # 反引号为 grep 字面模式（manifest 表行锚点），非命令替换
  if LC_ALL=C grep -q '^| `agents-triage\.md\.tmpl` | Roles |' "$TMPL/README.md"; then
    ok '正例 P3d Triage 模板 manifest 投影：templates/README.md 目录清单行在位'
  else
    bad '正例 P3d Triage 模板 manifest 投影：templates/README.md 目录清单行在位' '缺 manifest 目录清单行'
  fi
  # 安装面收敛后 Triage 模板零规则块：登记闭合改断三面——实物、清单 pm_template 数据行、
  # manifest 目录清单行；短码投影面改断安装面唯一带块件 CO（历史引用码不入人读短码表）。
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if [ -f "$TMPL/agents-triage.md.tmpl" ] \
    && LC_ALL=C grep -q '^pm_template agents-triage\.md\.tmpl$' "$MANIFEST" \
    && LC_ALL=C grep -q '^| `agents-triage\.md\.tmpl` |' "$TMPL/README.md" \
    && LC_ALL=C grep -q '^| `CO` | `core\.md\.tmpl`' "$TMPL/README.md"; then
    ok '正例 P3e Triage 模板登记闭合（实物＋清单数据行＋manifest 行）＋安装面 CO 短码投影'
  else
    bad '正例 P3e Triage 模板登记闭合（实物＋清单数据行＋manifest 行）＋安装面 CO 短码投影' '登记面缺项'
  fi

  # 正例 P4（×3）：三件派发 Prompt 均含角色合同权威指针（上下文面）
  for _p4r in implementation review commit; do
    if LC_ALL=C grep -q "rules/implementation/roles/$_p4r\.md" "$PROMPTS/$_p4r-prompt.md"; then
      ok "正例 P4 $_p4r-prompt.md 含角色合同权威指针"
    else
      bad "正例 P4 $_p4r-prompt.md 含角色合同权威指针" '缺 rules/implementation/roles/ 指针'
    fi
  done

  # 正例 P5：派发 Prompt 占位符全集零漂移（参数面完整，schema 双向零差集）
  sh "$SCRIPT_DIR/check-dispatch-contract.sh" --check-template > "$D/p5-tmpl.out" 2>&1
  _p5rc=$?
  if [ "$_p5rc" -eq 0 ] && grep -q 'PASS: 模板/schema 零差集' "$D/p5-tmpl.out"; then
    ok '正例 P5 三件 Prompt 占位符全集零漂移（check-dispatch-contract --check-template exit 0）'
  else
    bad '正例 P5 三件 Prompt 占位符全集零漂移（check-dispatch-contract --check-template exit 0）' "exit=$_p5rc $(tail -n 3 "$D/p5-tmpl.out" | tr '\n' '|')"
  fi

  # 正例 P6（×5）：五宿主映射文件去重态——单一公共规则权威指针段在位、零规则块、
  # 零公共规则正文（映射免责／能力映射同步／独立执行体降级三段标题与正文均不承载）。
  for _p6h in zcode claude-code codex pi dsh; do
    if rp_dedupe_check "$PKG_ROOT/references/adapters/$_p6h.md" > "$D/p6-$_p6h.out" 2>&1; then
      ok "正例 P6 $_p6h.md 公共规则只留唯一权威指针（零规则块、零公共规则正文）"
    else
      bad "正例 P6 $_p6h.md 公共规则只留唯一权威指针（零规则块、零公共规则正文）" "$(cat "$D/p6-$_p6h.out")"
    fi
  done

  # 正例 P7：结构模板不再复制规范正文——保留唯一权威指针句，不含规范等级表与降级路径枚举。
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  if require_out 'suite-role-prompt 目标输出在场' "$TMPL/../adapters/adapter-template.md" \
    && grep -q '唯一权威＝`capability-contract.md`' "$TMPL/../adapters/adapter-template.md" \
    && ! grep -q '^| 等级 | 定义 |' "$TMPL/../adapters/adapter-template.md" \
    && ! grep -q '依序尝试：(a)' "$TMPL/../adapters/adapter-template.md"; then
    ok '正例 P7 adapter-template.md 为结构基线（指针在位、规范正文不复述）'
  else
    bad '正例 P7 adapter-template.md 为结构基线（指针在位、规范正文不复述）' '模板含规范正文或指针缺失'
  fi

  # 负例 N6：duplicate-rule 宿主夹具（把公共规则块正文写回宿主文件）→ 去重扫描失败指名文件
  mkdir -p "$D/adapter-dup"
  cp "$PKG_ROOT/references/adapters/zcode.md" "$D/adapter-dup/zcode.md"
  cat >> "$D/adapter-dup/zcode.md" <<'EOF'

#### R-ZC-009 映射不是事实源 `MUST`

- **When**：夹具注入。
- **Action**：把公共规则正文写回宿主映射文件（重复承载）。
- **Forbidden**：夹具外使用。
- **Stop if**：无。
- **Evidence**：扫描器指名。
- **Owner**：测试夹具。
- **Authority**：capability-contract R-CC-002。
EOF
  if ! rp_dedupe_check "$D/adapter-dup/zcode.md" > "$D/n6.out" 2>&1; then
    ok '负例 N6 duplicate-rule 宿主夹具 → 去重扫描失败（公共规则正文回写被拒）'
  else
    bad '负例 N6 duplicate-rule 宿主夹具 → 去重扫描失败（公共规则正文回写被拒）' '扫描器对重复正文夹具意外通过（假绿）'
  fi

  # ---- 负例（mktemp 夹具）----

  # 负例 N1：duplicate-body Prompt 夹具（复制合同权限正文进 Prompt）→ 扫描器失败且指名角色
  mkdir -p "$D/prompts-dup"
  cp "$PROMPTS/implementation-prompt.md" "$PROMPTS/review-prompt.md" "$PROMPTS/commit-prompt.md" "$D/prompts-dup/"
  cat >> "$D/prompts-dup/implementation-prompt.md" <<'EOF'

**可写字段：**
- `checkpoint.implementation.*`：Implementation 阶段执行结果记录的所有子字段

**关键纪律**（重复正文注入）：
- **Forbidden**：执行 git add、git commit 或任何版本库写操作（角色合同正文重复承载）。
EOF
  if ! rp_scan_boundary "$D/prompts-dup" > "$D/n1-scan.out" 2>&1; then
    if grep -q 'prompts-dup/implementation-prompt.md:[0-9]' "$D/n1-scan.out"; then
      ok '负例 N1 duplicate-body Prompt 夹具 → 扫描器失败且指名角色（implementation-prompt.md:行号）'
    else
      bad '负例 N1 duplicate-body Prompt 夹具 → 扫描器失败且指名角色（implementation-prompt.md:行号）' "未指名角色文件: $(head -n 2 "$D/n1-scan.out" | tr '\n' '|')"
    fi
  else
    bad '负例 N1 duplicate-body Prompt 夹具 → 扫描器失败且指名角色（implementation-prompt.md:行号）' '扫描器对重复正文夹具意外通过（假绿）'
  fi

  # 负例 N2 对照正例：parameter/context/output-only Prompt 夹具（零规则正文）→ 扫描器通过
  mkdir -p "$D/prompts-clean"
  cat > "$D/prompts-clean/sample-prompt.md" <<'EOF'
# Sample 阶段派发

按 Sample 角色合同 `rules/implementation/roles/sample.md` 实施票 {{TICKET_ID}}。

**角色合同与权威规则（唯一权威，本模板不复写其正文）**：
- 角色合同（唯一事实源）：`rules/implementation/roles/sample.md`（所需能力、Scope 边界、禁止行为、验收条件与输出格式）

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}

**合同参数**：

```text
Task:
{{TASK_DESCRIPTION}}

Output Contract:
按角色合同输出格式执行（唯一权威，本模板不复写）。
```
EOF
  if rp_scan_boundary "$D/prompts-clean" > "$D/n2-scan.out" 2>&1; then
    ok '负例 N2 对照：parameter/context/output-only Prompt 夹具 → 扫描器通过（零误报）'
  else
    bad '负例 N2 对照：parameter/context/output-only Prompt 夹具 → 扫描器通过（零误报）' "$(head -n 3 "$D/n2-scan.out" | tr '\n' '|')"
  fi

  # 负例 N3：duplicate-rule 角色合同夹具（整块复制 R-RT-001）→ check-package 检查 22 失败指名角色（triage）
  pkg_copy "$PKG_ROOT" "$D/pkg-duprule"
  sed -n '/^#### R-CO-001/,/^#### R-CO-002/p' "$TMPL/core.md.tmpl" | sed '$d' >> "$D/pkg-duprule/references/templates/agents-triage.md.tmpl"
  sh "$D/pkg-duprule/scripts/check-package.sh" "$D/pkg-duprule" > "$D/n3-cp.out" 2>&1
  _n3rc=$?
  if [ "$_n3rc" -eq 1 ] && grep -q 'FAIL: 22' "$D/n3-cp.out" && grep -q 'R-CO-001' "$D/n3-cp.out" && grep -q 'agents-triage\.md\.tmpl' "$D/n3-cp.out"; then
    ok '负例 N3 duplicate-rule 角色合同夹具 → check-package 检查 22 失败指名 R-CO-001 与角色模板'
  else
    bad '负例 N3 duplicate-rule 角色合同夹具 → check-package 检查 22 失败指名 R-CO-001 与角色模板' "exit=$_n3rc $(grep -m 2 'FAIL' "$D/n3-cp.out" | tr '\n' '|')"
  fi

  # 负例 N4：missing-permission 角色合同夹具（删 readonly-execute）→ check-package 检查 14 失败指名角色（review）
  pkg_copy "$PKG_ROOT" "$D/pkg-noperm"
  # shellcheck disable=SC2016  # 反引号为 sed 字面删除模式（decl 行权限基元），非命令替换
  sed 's/、`readonly-execute`//' "$D/pkg-noperm/references/templates/agents-review.md.tmpl" > "$D/review.tmp" && mv "$D/review.tmp" "$D/pkg-noperm/references/templates/agents-review.md.tmpl"
  sh "$D/pkg-noperm/scripts/check-package.sh" "$D/pkg-noperm" > "$D/n4-cp.out" 2>&1
  _n4rc=$?
  if [ "$_n4rc" -eq 1 ] && grep -q 'FAIL: 14' "$D/n4-cp.out" && grep -q 'agents-review\.md\.tmpl' "$D/n4-cp.out"; then
    ok '负例 N4 missing-permission 角色合同夹具 → check-package 检查 14 失败指名角色模板与缺失基元'
  else
    bad '负例 N4 missing-permission 角色合同夹具 → check-package 检查 14 失败指名角色模板与缺失基元' "exit=$_n4rc $(grep -m 2 'FAIL' "$D/n4-cp.out" | tr '\n' '|')"
  fi

  # 负例 N5：Triage 模板缺权限声明夹具 → 权威面结构断言失败且指名角色（triage）
  mkdir -p "$D/tmpl-noperm"
  grep -v '^required_capabilities（运行时）：' "$TMPL/agents-triage.md.tmpl" > "$D/tmpl-noperm/agents-triage.md.tmpl"
  if ! rp_role_check "$D/tmpl-noperm/agents-triage.md.tmpl" > "$D/n5-rp.out" 2>&1; then
    if grep -q 'missing-decl' "$D/n5-rp.out" && grep -q 'agents-triage\.md\.tmpl' "$D/n5-rp.out"; then
      ok '负例 N5 Triage 模板缺权限声明夹具 → 结构断言失败指名 missing-decl 与角色模板'
    else
      bad '负例 N5 Triage 模板缺权限声明夹具 → 结构断言失败指名 missing-decl 与角色模板' "$(cat "$D/n5-rp.out")"
    fi
  else
    bad '负例 N5 Triage 模板缺权限声明夹具 → 结构断言失败指名 missing-decl 与角色模板' '结构断言对缺声明夹具意外通过（假绿）'
  fi

  # 正例 P8（×6）：入口术语统一——路由层 Triage＋编码层三阶段（票 218 AC1/AC2）
  # 面＝SKILL.md description/§1、templates/README.md Roles 两行、AGENTS.md.tmpl 代理协作、
  # discipline.md.tmpl 两层协作、capability-contract.md §2.2 能力表。禁词面＝旧称
  # 「四个角色」与编码阶段式 Triage（Planning/Triage 并列行、四阶段能力表）。
  if rp_term_check 'SKILL.md' "$PKG_ROOT/SKILL.md" \
      '路由层 Triage 与编码层三阶段' '四个角色的岗位合同' > "$D/p8a.out" 2>&1; then
    ok '正例 P8a SKILL.md 入口术语统一（路由层 Triage＋编码层三阶段）'
  else
    bad '正例 P8a SKILL.md 入口术语统一（路由层 Triage＋编码层三阶段）' "$(cat "$D/p8a.out")"
  fi
  if rp_term_check 'templates/README.md 编码层可行' "$TMPL/README.md" \
      '编码层三阶段角色合同（与路由层 Triage 合同一并生成）' '' > "$D/p8b.out" 2>&1; then
    ok '正例 P8b templates/README.md 编码层三阶段合同行与路由层合同互指'
  else
    bad '正例 P8b templates/README.md 编码层三阶段合同行与路由层合同互指' "$(cat "$D/p8b.out")"
  fi
  if rp_term_check 'templates/README.md 路由层行' "$TMPL/README.md" \
      '所有项目初始化生成路由层角色合同（两层协作为固定规则' '' > "$D/p8c.out" 2>&1; then
    ok '正例 P8c templates/README.md 路由层合同行与编码层三阶段合同互指'
  else
    bad '正例 P8c templates/README.md 路由层合同行与编码层三阶段合同互指' "$(cat "$D/p8c.out")"
  fi
  if rp_term_check 'AGENTS.md.tmpl' "$TMPL/AGENTS.md.tmpl" \
      '主 agent（路由层 Triage）只做理解、拆分、派发与验收' '' > "$D/p8d.out" 2>&1; then
    ok '正例 P8d AGENTS.md.tmpl 代理协作节标明路由层 Triage 与编码层三阶段'
  else
    bad '正例 P8d AGENTS.md.tmpl 代理协作节标明路由层 Triage 与编码层三阶段' "$(cat "$D/p8d.out")"
  fi
  if rp_term_check 'discipline.md.tmpl' "$TMPL/discipline.md.tmpl" \
      '路由层 Triage 合同与三件阶段合同同目录并列，Triage 属路由层、不计入编码层三阶段' '' > "$D/p8e.out" 2>&1; then
    ok '正例 P8e discipline.md.tmpl 两层协作节区分路由层 Triage 与编码层三阶段'
  else
    bad '正例 P8e discipline.md.tmpl 两层协作节区分路由层 Triage 与编码层三阶段' "$(cat "$D/p8e.out")"
  fi
  if rp_term_check 'capability-contract.md' "$PKG_ROOT/references/adapters/capability-contract.md" \
      '两层协作→能力表（路由层 Triage＋编码层三阶段）' 'Planning/Triage|四阶段→能力表' > "$D/p8f.out" 2>&1; then
    ok '正例 P8f capability-contract.md 能力表按两层协作登记（无编码阶段式 Triage）'
  else
    bad '正例 P8f capability-contract.md 能力表按两层协作登记（无编码阶段式 Triage）' "$(cat "$D/p8f.out")"
  fi

  # ---- 正例 P9/P10（票 238）：角色能力收窄与执行能力一致 ----
  # P9＝四件合同声明面（triage execute 白名单与派发前置口径、impl 不含 vcs-write 且
  # 保留 git_write_enforcement 降级义务、review 只写审查证据、commit 仅编排入口）；
  # P10＝capability-contract §2.2 与五宿主 §2.3 的 Commit/Triage 投影同口径。
  if rp_capability_check "$TMPL" > "$D/p9.out" 2>&1; then
    ok '正例 P9 四件角色合同能力面与执行能力一致（triage execute 白名单／impl 降级／review 只写证据／commit 编排入口）'
  else
    bad '正例 P9 四件角色合同能力面与执行能力一致（triage execute 白名单／impl 降级／review 只写证据／commit 编排入口）' "$(cat "$D/p9.out")"
  fi
  _p10_bad=''
  if ! LC_ALL=C grep -qF 'Triage（主 agent） | inspect、search、execute（仅登记编排命令）' "$PKG_ROOT/references/adapters/capability-contract.md"; then
    _p10_bad="$_p10_bad; capability-contract Triage 行缺 execute"
  fi
  if ! LC_ALL=C grep -qF 'Commit | inspect、execute（仅编排器' "$PKG_ROOT/references/adapters/capability-contract.md"; then
    _p10_bad="$_p10_bad; capability-contract Commit 行缺编排入口能力"
  fi
  if LC_ALL=C grep -qF 'Commit | inspect、vcs-read、vcs-write' "$PKG_ROOT/references/adapters/capability-contract.md"; then
    _p10_bad="$_p10_bad; capability-contract Commit 行仍列 vcs-read/vcs-write"
  fi
  for _p10h in zcode claude-code codex pi dsh; do
    _p10row=$(LC_ALL=C grep -F '| <role-contract-dir>/commit.md |' "$PKG_ROOT/references/adapters/$_p10h.md" || true)
    case "$_p10row" in
      *'inspect, execute'*) ;;
      *) _p10_bad="$_p10_bad; $_p10h commit 行缺 inspect, execute" ;;
    esac
    case "$_p10row" in
      *'ticket-run.sh <NN> commit'*) ;;
      *) _p10_bad="$_p10_bad; $_p10h commit 行缺 ticket-run 编排入口" ;;
    esac
    case "$_p10row" in
      *'vcs-read'* | *'vcs-write'*) _p10_bad="$_p10_bad; $_p10h commit 行仍列 vcs 写能力" ;;
    esac
  done
  if [ -z "$_p10_bad" ]; then
    ok '正例 P10 capability-contract §2.2 与五宿主 §2.3 能力投影同口径（Triage execute／Commit 编排入口）'
  else
    bad '正例 P10 capability-contract §2.2 与五宿主 §2.3 能力投影同口径（Triage execute／Commit 编排入口）' "$_p10_bad"
  fi

  # ---- 负例 N7–N10（票 238）：能力面各删/注入一处 → 断言指名角色失败 ----
  mkdir -p "$D/tmpl-cap"
  cp "$TMPL"/agents-triage.md.tmpl "$TMPL"/agents-implementation.md.tmpl "$TMPL"/agents-review.md.tmpl "$TMPL"/agents-commit.md.tmpl "$D/tmpl-cap/"
  # shellcheck disable=SC2016  # 反引号为 sed 字面删除模式（声明行基元），非命令替换
  sed 's/、`execute`//' "$D/tmpl-cap/agents-triage.md.tmpl" > "$D/n7.tmp" && mv "$D/n7.tmp" "$D/tmpl-cap/agents-triage.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n7.out" 2>&1 && grep -q 'triage 声明缺 execute' "$D/n7.out"; then
    ok '负例 N7 Triage 声明删 execute → 能力断言指名 triage 失败'
  else
    bad '负例 N7 Triage 声明删 execute → 能力断言指名 triage 失败' "$(cat "$D/n7.out")"
  fi
  cp "$TMPL"/agents-commit.md.tmpl "$D/tmpl-cap/agents-commit.md.tmpl"
  # shellcheck disable=SC2016  # 反引号为 sed 字面替换模式（声明行基元），非命令替换
  sed 's/`inspect`、`execute`/`inspect`、`execute`、`vcs-write`/' "$D/tmpl-cap/agents-commit.md.tmpl" > "$D/n8.tmp" && mv "$D/n8.tmp" "$D/tmpl-cap/agents-commit.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n8.out" 2>&1 && grep -q 'commit 声明越权: vcs-write' "$D/n8.out"; then
    ok '负例 N8 Commit 声明注入 vcs-write → 能力断言指名 commit 越权失败'
  else
    bad '负例 N8 Commit 声明注入 vcs-write → 能力断言指名 commit 越权失败' "$(cat "$D/n8.out")"
  fi
  cp "$TMPL"/agents-review.md.tmpl "$D/tmpl-cap/agents-review.md.tmpl"
  printf '\n本角色零文件改动。\n' >> "$D/tmpl-cap/agents-review.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n9.out" 2>&1 && grep -q '零文件改动' "$D/n9.out"; then
    ok '负例 N9 Review 恢复零文件改动表述 → 能力断言指名失败（与追加审查证据矛盾）'
  else
    bad '负例 N9 Review 恢复零文件改动表述 → 能力断言指名失败（与追加审查证据矛盾）' "$(cat "$D/n9.out")"
  fi
  grep -v 'git_write_enforcement' "$TMPL/agents-implementation.md.tmpl" > "$D/tmpl-cap/agents-implementation.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n10.out" 2>&1 && grep -q 'git_write_enforcement' "$D/n10.out"; then
    ok '负例 N10 Implementation 删 git_write_enforcement → 能力断言指名失败（降级义务缺失）'
  else
    bad '负例 N10 Implementation 删 git_write_enforcement → 能力断言指名失败（降级义务缺失）' "$(cat "$D/n10.out")"
  fi
  cp "$TMPL"/agents-triage.md.tmpl "$TMPL"/agents-commit.md.tmpl "$D/tmpl-cap/"
  # shellcheck disable=SC2016  # 单引号字面量内的 markdown 反引号／$ 是断言原文（双引号会触发命令替换），非缺陷
  printf '\n必须运行 `verify-contract.sh` 复核范围。\n' >> "$D/tmpl-cap/agents-commit.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n11.out" 2>&1 && grep -q 'commit 需运行的脚本不在 execute 白名单: verify-contract.sh' "$D/n11.out"; then
    ok '负例 N11 Commit 引入白名单外脚本 → 能力断言指名失败（必须跑但不在 execute）'
  else
    bad '负例 N11 Commit 引入白名单外脚本 → 能力断言指名失败（必须跑但不在 execute）' "$(cat "$D/n11.out")"
  fi
  cp "$TMPL"/agents-commit.md.tmpl "$D/tmpl-cap/agents-commit.md.tmpl"
  sed 's/实现阶段建站派发前/建站派发前/' "$D/tmpl-cap/agents-triage.md.tmpl" > "$D/n12.tmp" && mv "$D/n12.tmp" "$D/tmpl-cap/agents-triage.md.tmpl"
  if ! rp_capability_check "$D/tmpl-cap" > "$D/n12.out" 2>&1 && grep -q 'triage 派发前置未限定实现阶段' "$D/n12.out"; then
    ok '负例 N12 Triage 派发前置去掉实现阶段限定 → 能力断言指名失败（review/commit 无 REPOSITORY_PATH）'
  else
    bad '负例 N12 Triage 派发前置去掉实现阶段限定 → 能力断言指名失败（review/commit 无 REPOSITORY_PATH）' "$(cat "$D/n12.out")"
  fi

  # ---- 正例 P11／负例 N13–N16（票 253）：步数预算与到线行为 ----
  # 正例＝三份角色模板均含 R-RI-005 判据：单任务步数上限：80、到线即收尾、另起交接
  # 摘要（已完成/未完成/下一步/不重述）与可核豁免（理由＋上限值），且无不可判定措辞。
  # 负例四类＝删步数上限／删到线收尾／上限为空／上限非数字，各自指名失败。
  for _p11f in implementation triage review; do
    if rp_step_budget_check "$TMPL/agents-$_p11f.md.tmpl" > "$D/p11-$_p11f.out" 2>&1; then
      ok "正例 P11 agents-$_p11f.md.tmpl 含 R-RI-005（步数上限 80＋到线收尾＋交接摘要＋可核豁免）"
    else
      bad "正例 P11 agents-$_p11f.md.tmpl 含 R-RI-005（步数上限 80＋到线收尾＋交接摘要＋可核豁免）" "$(cat "$D/p11-$_p11f.out")"
    fi
  done
  mkdir -p "$D/sb-tmpl"
  grep -v '步数上限' "$TMPL/agents-implementation.md.tmpl" > "$D/sb-tmpl/nobudget.md.tmpl"
  if ! rp_step_budget_check "$D/sb-tmpl/nobudget.md.tmpl" > "$D/n13.out" 2>&1 && grep -q 'missing-budget' "$D/n13.out"; then
    ok '负例 N13 模板删步数上限 → 断言失败并指名 missing-budget'
  else
    bad '负例 N13 模板删步数上限 → 断言失败并指名 missing-budget' "$(cat "$D/n13.out")"
  fi
  sed 's/到线//g; s/收尾//g' "$TMPL/agents-implementation.md.tmpl" > "$D/sb-tmpl/nowrap.md.tmpl"
  if ! rp_step_budget_check "$D/sb-tmpl/nowrap.md.tmpl" > "$D/n14.out" 2>&1 && grep -q 'missing-wrapup' "$D/n14.out"; then
    ok '负例 N14 模板删到线收尾表述 → 断言失败并指名 missing-wrapup'
  else
    bad '负例 N14 模板删到线收尾表述 → 断言失败并指名 missing-wrapup' "$(cat "$D/n14.out")"
  fi
  sed 's/步数上限：80/步数上限：/' "$TMPL/agents-implementation.md.tmpl" > "$D/sb-tmpl/empty.md.tmpl"
  if ! rp_step_budget_check "$D/sb-tmpl/empty.md.tmpl" > "$D/n15.out" 2>&1 && grep -q 'budget-empty' "$D/n15.out"; then
    ok '负例 N15 模板步数上限值为空 → 断言失败并指名 budget-empty'
  else
    bad '负例 N15 模板步数上限值为空 → 断言失败并指名 budget-empty' "$(cat "$D/n15.out")"
  fi
  sed 's/步数上限：80/步数上限：八十/' "$TMPL/agents-implementation.md.tmpl" > "$D/sb-tmpl/nan.md.tmpl"
  if ! rp_step_budget_check "$D/sb-tmpl/nan.md.tmpl" > "$D/n16.out" 2>&1 && grep -q 'budget-non-numeric' "$D/n16.out"; then
    ok '负例 N16 模板步数上限非数字 → 断言失败并指名 budget-non-numeric'
  else
    bad '负例 N16 模板步数上限非数字 → 断言失败并指名 budget-non-numeric' "$(cat "$D/n16.out")"
  fi

  suite_summary 'role-prompt'
}
