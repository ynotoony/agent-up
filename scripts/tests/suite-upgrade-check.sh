#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite upgrade-check "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: upgrade-check（票 142：模式判别、双路径、条件门控、人工核对边界）
# ============================================================

uc_build_fixture() {
  # $1=夹具目录：包侧 pkg/（含 references/templates/t.tmpl＋scripts/upgrade-check.sh 拷贝）
  #                实例侧 repo/（含 rules/assessment.md）
  rm -rf "$1"
  mkdir -p "$1/pkg/references/templates" "$1/pkg/scripts" "$1/repo"
  cp "$SCRIPT_DIR/upgrade-check.sh" "$1/pkg/scripts/upgrade-check.sh"
  cp "$PKG_ROOT/scripts/generate-progress.sh" "$1/pkg/scripts/generate-progress.sh"
  printf "ip_gate fast-lane --fast-lane 'fixture fast lane'\nip_gate ticket-ops --ticket-ops 'fixture ticket ops'\nip_file agent-up/scripts/upgrade-check.sh Conditional fast-lane 'fixture checker'\nip_file agent-up/scripts/generate-progress.sh Conditional fast-lane 'fixture shared script'\nip_file agent-up/scripts/generate-progress.sh Conditional ticket-ops 'fallback dependency'\n" > "$1/pkg/scripts/install-policy.rules"
  printf '# ==== payload：导出形态（export-payload.sh 读）====\n# ==== boundary：禁入名单（pre-push 安检读）====\n# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n# ==== main-only：worktree 排除清单（worktree-add.sh 读）====\n' > "$1/pkg/references/templates/delivery-rules.tmpl"
  printf '#### R-AG-001 Agent\nbody\n' > "$1/pkg/references/templates/AGENTS.md.tmpl"
  printf '#### R-DP-001 Alpha\nbody\n#### R-DP-002 Beta\nbody\n' > "$1/pkg/references/templates/assessment.md.tmpl"
  printf '#### R-DP-003 Discipline\nbody\n' > "$1/pkg/references/templates/discipline.md.tmpl"
  printf '#### R-DP-004 Project\nbody\n' > "$1/pkg/references/templates/project.md.tmpl"
  printf '#### R-RI-001 Implementation\nbody\n' > "$1/pkg/references/templates/agents-implementation.md.tmpl"
  printf '#### R-RR-001 Review\nbody\n' > "$1/pkg/references/templates/agents-review.md.tmpl"
  printf '#### R-RC-001 Commit\nbody\n' > "$1/pkg/references/templates/agents-commit.md.tmpl"
  cp "$PKG_ROOT/references/templates/README.md" "$1/pkg/references/templates/README.md"
}

uc_build_modern_repo() {
  mkdir -p "$1/rules/implementation/roles" "$1/facts/project"
  cp "$2/pkg/references/templates/AGENTS.md.tmpl" "$1/AGENTS.md"
  cp "$2/pkg/references/templates/assessment.md.tmpl" "$1/rules/assessment.md"
  cp "$2/pkg/references/templates/discipline.md.tmpl" "$1/rules/implementation/discipline.md"
  cp "$2/pkg/references/templates/project.md.tmpl" "$1/rules/project.md"
  cp "$2/pkg/references/templates/agents-implementation.md.tmpl" "$1/rules/implementation/roles/implementation.md"
  cp "$2/pkg/references/templates/agents-review.md.tmpl" "$1/rules/implementation/roles/review.md"
  cp "$2/pkg/references/templates/agents-commit.md.tmpl" "$1/rules/implementation/roles/commit.md"
  printf '# rules directory\n' > "$1/rules/README.md"
  printf '# facts directory\n' > "$1/facts/README.md"
  printf '# artifacts\n' > "$1/facts/project/artifacts.yaml"
}

suite_upgrade_check() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='upgrade-check'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/uc142
  mkdir -p "$D"
  UC="$SCRIPT_DIR/upgrade-check.sh"

  uc_modern() {
    uc_build_fixture "$1"
    uc_build_modern_repo "$1/repo" "$1"
  }

  # Modern complete surface: delivery and one script prove fast-lane; custom files are manual.
  uc_modern "$D/p1"
  mkdir -p "$D/p1/repo/rules/implementation/scripts"
  mkdir -p "$D/p1/repo/facts/requirements/specs" "$D/p1/repo/facts/requirements/research"
  cp "$D/p1/pkg/scripts/upgrade-check.sh" "$D/p1/repo/rules/implementation/scripts/upgrade-check.sh"
  cp "$D/p1/pkg/scripts/generate-progress.sh" "$D/p1/repo/rules/implementation/scripts/generate-progress.sh"
  printf '# scripts README\n' > "$D/p1/repo/rules/implementation/scripts/README.md"
  printf '# specs README\n' > "$D/p1/repo/facts/requirements/specs/README.md"
  printf '# research README\n' > "$D/p1/repo/facts/requirements/research/README.md"
  cp "$D/p1/pkg/references/templates/delivery-rules.tmpl" "$D/p1/repo/delivery.rules"
  sh "$UC" "$D/p1/pkg" "$D/p1/repo" > "$D/p1.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '布局: modern' "$D/p1.out" \
    && grep -q '人工核对 facts/requirements/specs/README.md' "$D/p1.out" \
    && grep -q '人工核对 facts/requirements/research/README.md' "$D/p1.out" \
    && grep -q '人工核对 <目录>/README.md 动态 Emits' "$D/p1.out" \
    && grep -q '自动检查面无差距；不代表人工核对面' "$D/p1.out"; then
    ok '正例 P1 现代布局与 manifest 中已生成的条件 README'
  else
    bad '正例 P1 现代布局与 manifest 中已生成的条件 README' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # Missing block is behind and names the exact ID.
  uc_modern "$D/n1"
  printf '#### R-DP-001 Alpha\nbody\n' > "$D/n1/repo/rules/assessment.md"
  sh "$UC" "$D/n1/pkg" "$D/n1/repo" > "$D/n1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '落后  rules/assessment.md 缺规则块: R-DP-002' "$D/n1.out"; then
    ok '负例 N1 缺块 → 落后并列出 R-DP-002'
  else
    bad '负例 N1 缺块 → 落后并列出 R-DP-002' "exit=$rc $(tail -n 2 "$D/n1.out" | tr '\n' '|')"
  fi

  # Extra block is a non-blocking divergence candidate.
  uc_modern "$D/p2"
  printf '#### R-DP-099 Extra\nbody\n' >> "$D/p2/repo/rules/assessment.md"
  sh "$UC" "$D/p2/pkg" "$D/p2/repo" > "$D/p2.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '分歧候选  rules/assessment.md 有包模板没有的规则块: R-DP-099' "$D/p2.out"; then
    ok '正例 P2 多余块 → 分歧候选不拦截'
  else
    bad '正例 P2 多余块 → 分歧候选不拦截' "exit=$rc $(tail -n 2 "$D/p2.out" | tr '\n' '|')"
  fi

  # Conditional delivery config is N/A until fast-lane evidence appears.
  uc_modern "$D/p3"
  sh "$UC" "$D/p3/pkg" "$D/p3/repo" > "$D/p3.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'N/A delivery.rules（未启用快道' "$D/p3.out" \
    && grep -q 'N/A  facts/requirements/specs/README.md（Conditional 目录不存在' "$D/p3.out" \
    && grep -q 'N/A  facts/requirements/research/README.md（Conditional 目录不存在' "$D/p3.out"; then
    ok '正例 P3 未启用快道且条件目录未生成 → delivery/README 均 N/A'
  else
    bad '正例 P3 未启用快道且条件目录未生成 → delivery/README 均 N/A' "exit=$rc $(tail -n 2 "$D/p3.out" | tr '\n' '|')"
  fi

  # A conditional directory on disk activates its manifest-declared README check.
  uc_modern "$D/n5"
  mkdir -p "$D/n5/repo/facts/requirements/specs"
  printf '# spec body\n' > "$D/n5/repo/facts/requirements/specs/one.md"
  sh "$UC" "$D/n5/pkg" "$D/n5/repo" > "$D/n5.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '落后  facts/requirements/specs/README.md 缺失（模板 manifest 中已生成的 Conditional README）' "$D/n5.out"; then
    ok '负例 N5 specs 目录已生成但缺 manifest README → 落后'
  else
    bad '负例 N5 specs 目录已生成但缺 manifest README → 落后' "exit=$rc $(tail -n 2 "$D/n5.out" | tr '\n' '|')"
  fi

  # Fast-lane script evidence without config is behind.
  uc_modern "$D/n2"
  mkdir -p "$D/n2/repo/rules/implementation/scripts"
  cp "$D/n2/pkg/scripts/upgrade-check.sh" "$D/n2/repo/rules/implementation/scripts/upgrade-check.sh"
  printf '# scripts README\n' > "$D/n2/repo/rules/implementation/scripts/README.md"
  sh "$UC" "$D/n2/pkg" "$D/n2/repo" > "$D/n2.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '落后  delivery.rules 缺失（快道脚本已装，配置缺失）' "$D/n2.out"; then
    ok '负例 N2 快道已启用但缺配置 → 落后'
  else
    bad '负例 N2 快道已启用但缺配置 → 落后' "exit=$rc $(tail -n 2 "$D/n2.out" | tr '\n' '|')"
  fi

  # Both layouts must be compared independently and reported as conflict.
  uc_modern "$D/n3"
  mkdir -p "$D/n3/repo/rules/implementation/scripts" "$D/n3/repo/scripts"
  cp "$D/n3/pkg/scripts/upgrade-check.sh" "$D/n3/repo/rules/implementation/scripts/upgrade-check.sh"
  cp "$D/n3/pkg/scripts/upgrade-check.sh" "$D/n3/repo/scripts/upgrade-check.sh"
  printf '# local legacy change\n' >> "$D/n3/repo/scripts/upgrade-check.sh"
  printf '# modern scripts README\n' > "$D/n3/repo/rules/implementation/scripts/README.md"
  printf '# legacy scripts README\n' > "$D/n3/repo/scripts/README.md"
  cp "$D/n3/pkg/references/templates/delivery-rules.tmpl" "$D/n3/repo/delivery.rules"
  sh "$UC" "$D/n3/pkg" "$D/n3/repo" > "$D/n3.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '冲突  upgrade-check.sh 同时位于' "$D/n3.out" \
    && grep -q '同步  rules/implementation/scripts/upgrade-check.sh' "$D/n3.out" \
    && grep -q '漂移  scripts/upgrade-check.sh（旧布局' "$D/n3.out"; then
    ok '负例 N3 双布局 → 冲突并分别 cmp，报同步与漂移'
  else
    bad '负例 N3 双布局 → 冲突并分别 cmp，报同步与漂移' "exit=$rc $(tail -n 3 "$D/n3.out" | tr '\n' '|')"
  fi

  # Legacy docs governance remains valid and does not require new rules/roles.
  uc_build_fixture "$D/p4"
  mkdir -p "$D/p4/repo/docs/agent/roles" "$D/p4/repo/scripts"
  mkdir -p "$D/p4/repo/docs/specs" "$D/p4/repo/docs/research"
  cp "$D/p4/pkg/references/templates/AGENTS.md.tmpl" "$D/p4/repo/AGENTS.md"
  printf '# legacy process\n' > "$D/p4/repo/docs/development-process.md"
  printf '# legacy README\n' > "$D/p4/repo/docs/README.md"
  printf '# legacy artifacts\n' > "$D/p4/repo/docs/agent/artifacts.yaml"
  for role in implementation review commit; do printf '# legacy %s\n' "$role" > "$D/p4/repo/docs/agent/roles/$role.md"; done
  printf '# scripts\n' > "$D/p4/repo/scripts/README.md"
  printf '# legacy specs README\n' > "$D/p4/repo/docs/specs/README.md"
  printf '# legacy research README\n' > "$D/p4/repo/docs/research/README.md"
  cp "$D/p4/pkg/scripts/upgrade-check.sh" "$D/p4/repo/scripts/upgrade-check.sh"
  cp "$D/p4/pkg/scripts/generate-progress.sh" "$D/p4/repo/scripts/generate-progress.sh"
  cp "$D/p4/pkg/references/templates/delivery-rules.tmpl" "$D/p4/repo/delivery.rules"
  sh "$UC" "$D/p4/pkg" "$D/p4/repo" > "$D/p4.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '布局: legacy' "$D/p4.out" \
    && grep -q 'N/A  rules/ 与 rules/implementation/roles/ 块检查' "$D/p4.out" \
    && grep -q '人工核对 docs/agent/roles/implementation.md' "$D/p4.out" \
    && grep -q '人工核对 docs/specs/README.md' "$D/p4.out" \
    && grep -q '人工核对 docs/research/README.md' "$D/p4.out" \
    && grep -q '同步  scripts/upgrade-check.sh（旧布局' "$D/p4.out"; then
    ok '正例 P4 旧 docs 布局 → 兼容保留'
  else
    bad '正例 P4 旧 docs 布局 → 兼容保留' "exit=$rc $(tail -n 3 "$D/p4.out" | tr '\n' '|')"
  fi

  # A lone docs directory is ambiguous and must fail closed.
  uc_build_fixture "$D/n4"
  mkdir -p "$D/n4/repo/docs"
  printf '# docs only\n' > "$D/n4/repo/docs/README.md"
  sh "$UC" "$D/n4/pkg" "$D/n4/repo" > "$D/n4.out" 2>&1; rc=$?
  if [ "$rc" -eq 2 ] && grep -q '治理布局不明确' "$D/n4.out"; then
    ok '负例 N4 单一 docs 路径 → 布局不明 fail-closed'
  else
    bad '负例 N4 单一 docs 路径 → 布局不明 fail-closed' "exit=$rc $(tail -n 2 "$D/n4.out" | tr '\n' '|')"
  fi

  # Mixed complete governance surfaces are reported explicitly and both are inspected.
  uc_build_fixture "$D/p5"
  uc_build_modern_repo "$D/p5/repo" "$D/p5"
  mkdir -p "$D/p5/repo/docs/agent/roles"
  printf '# legacy process\n' > "$D/p5/repo/docs/development-process.md"
  printf '# legacy docs README\n' > "$D/p5/repo/docs/README.md"
  printf '# legacy artifacts\n' > "$D/p5/repo/docs/agent/artifacts.yaml"
  for role in implementation review commit; do printf '# legacy %s\n' "$role" > "$D/p5/repo/docs/agent/roles/$role.md"; done
  sh "$UC" "$D/p5/pkg" "$D/p5/repo" > "$D/p5.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '布局: mixed' "$D/p5.out" \
    && grep -q '人工核对 docs/agent/artifacts.yaml' "$D/p5.out" \
    && grep -q '人工核对 facts/project/artifacts.yaml' "$D/p5.out"; then
    ok '正例 P5 新旧治理面并存 → 标记 mixed 并分别检查'
  else
    bad '正例 P5 新旧治理面并存 → 标记 mixed 并分别检查' "exit=$rc $(tail -n 3 "$D/p5.out" | tr '\n' '|')"
  fi

  # Shared multi-gate script (generate-progress.sh: fast-lane + ticket-ops rows) must not
  # light the fast lane. P6: ticket-ops-only install without delivery.rules stays N/A and
  # exits 0; N6: an installed fast-lane-exclusive script without the config is behind (exit 1).
  uc_modern "$D/p6"
  mkdir -p "$D/p6/repo/rules/implementation/scripts"
  cp "$D/p6/pkg/scripts/generate-progress.sh" "$D/p6/repo/rules/implementation/scripts/generate-progress.sh"
  printf '# scripts README\n' > "$D/p6/repo/rules/implementation/scripts/README.md"
  sh "$UC" "$D/p6/pkg" "$D/p6/repo" > "$D/p6.out" 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'N/A delivery.rules（未启用快道）' "$D/p6.out" \
    && grep -q '同步  rules/implementation/scripts/generate-progress.sh' "$D/p6.out" \
    && ! grep -q '配置面（delivery.rules 条件产物）' "$D/p6.out"; then
    ok '正例 P6 票务道安装共享脚本不点亮快道 → delivery.rules N/A 且 exit 0'
  else
    bad '正例 P6 票务道安装共享脚本不点亮快道 → delivery.rules N/A 且 exit 0' "exit=$rc $(tail -n 3 "$D/p6.out" | tr '\n' '|')"
  fi

  uc_modern "$D/n6"
  mkdir -p "$D/n6/repo/rules/implementation/scripts"
  cp "$D/n6/pkg/scripts/upgrade-check.sh" "$D/n6/repo/rules/implementation/scripts/upgrade-check.sh"
  printf '# scripts README\n' > "$D/n6/repo/rules/implementation/scripts/README.md"
  sh "$UC" "$D/n6/pkg" "$D/n6/repo" > "$D/n6.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '落后  delivery.rules 缺失（快道脚本已装，配置缺失）' "$D/n6.out"; then
    ok '负例 N6 快道专属脚本已装但缺 delivery.rules → 落后 exit 1'
  else
    bad '负例 N6 快道专属脚本已装但缺 delivery.rules → 落后 exit 1' "exit=$rc $(tail -n 2 "$D/n6.out" | tr '\n' '|')"
  fi

  suite_summary 'upgrade-check'
}
