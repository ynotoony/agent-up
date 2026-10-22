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
# 合同正文＋Triage 模板登记闭合（数据表＋manifest 投影）＋占位符全集零漂移；
# 负例＝duplicate-body Prompt 夹具（复制合同正文进 Prompt）扫描器指名角色失败、
# parameter/context/output-only Prompt 夹具通过、duplicate-rule 与
# missing-permission 角色合同夹具经 check-package 指名角色失败（检查 22/14）、
# Triage 模板缺权限声明夹具结构断言指名角色失败。夹具全 mktemp 自建不入仓，
# 被测对象只读；边界扫描为结构性标记代理（规则块头/七字段体/权限清单体/输出
# 格式签名），README 叙事面豁免（对齐 check-package 检查 12 口径））
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

# 角色合同权威面结构断言：required_capabilities 声明行＋至少一个规则块头在位。
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
  if ! LC_ALL=C grep -q '^#### R-' "$_rpf_file"; then
    printf 'missing-rule-block: %s\n' "$_rpf_file"
    _rpf_bad=1
  fi
  return "$_rpf_bad"
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
      ok "正例 P1 角色合同承载 MUST/权限唯一权威面：agents-$_p1r.md.tmpl（能力声明行＋规则块在位）"
    else
      bad "正例 P1 角色合同承载 MUST/权限唯一权威面：agents-$_p1r.md.tmpl（能力声明行＋规则块在位）" "$(cat "$D/p1-$_p1r.out")"
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
  # shellcheck disable=SC2016  # 反引号为 grep 字面模式（短码表行锚点），非命令替换
  if LC_ALL=C grep -q '^| `RT` | `agents-triage' "$TMPL/README.md"; then
    ok '正例 P3e Triage 短码投影：templates/README.md 短码登记行在位'
  else
    bad '正例 P3e Triage 短码投影：templates/README.md 短码登记行在位' '缺 RT 短码登记行'
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
  cp -R "$PKG_ROOT" "$D/pkg-duprule"
  sed -n '/^#### R-RT-001/,/^#### R-RT-002/p' "$TMPL/agents-triage.md.tmpl" | sed '$d' >> "$D/pkg-duprule/references/templates/agents-triage.md.tmpl"
  sh "$D/pkg-duprule/scripts/check-package.sh" "$D/pkg-duprule" > "$D/n3-cp.out" 2>&1
  _n3rc=$?
  if [ "$_n3rc" -eq 1 ] && grep -q 'FAIL: 22' "$D/n3-cp.out" && grep -q 'R-RT-001' "$D/n3-cp.out" && grep -q 'agents-triage\.md\.tmpl' "$D/n3-cp.out"; then
    ok '负例 N3 duplicate-rule 角色合同夹具 → check-package 检查 22 失败指名 R-RT-001 与角色模板'
  else
    bad '负例 N3 duplicate-rule 角色合同夹具 → check-package 检查 22 失败指名 R-RT-001 与角色模板' "exit=$_n3rc $(grep -m 2 'FAIL' "$D/n3-cp.out" | tr '\n' '|')"
  fi

  # 负例 N4：missing-permission 角色合同夹具（删 readonly-execute）→ check-package 检查 14 失败指名角色（review）
  cp -R "$PKG_ROOT" "$D/pkg-noperm"
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

  suite_summary 'role-prompt'
}
