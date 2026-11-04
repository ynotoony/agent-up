#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite check-artifacts "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: check-artifacts（票 59 场景沉淀：治理产物对账正负例——登记↔实物双向对账、
# 懒创建 SKIP、豁免命中不报、解析破坏 fail-closed、用法退出码）
# ============================================================

rt_build_fixture() {
  # $1=夹具仓根：与 check-artifacts.sh 对账数据块基线口径一致的登记↔实物全对账仓
  # （票 113 波④：受管面＝rules/＋facts/ 双递归树，账本与登记按 R9/R11/R12/R13/R15/R25）
  R=$1
  rm -rf "$R"
  mkdir -p "$R/rules/implementation/scripts" "$R/rules/implementation/roles" "$R/facts/requirements/tickets" "$R/facts/requirements/runs" "$R/facts/project"
  printf '# agents\n' > "$R/AGENTS.md"
  printf '#!/bin/sh\n' > "$R/rules/implementation/scripts/tool.sh"
  printf '# notes\n' > "$R/rules/notes.md"
  printf '# impl\n' > "$R/rules/implementation/roles/impl.md"
  printf '# t1\n' > "$R/facts/requirements/tickets/t1.md"
  printf '{"i":1}\n' > "$R/facts/requirements/tickets/index.json"
  printf 'l1\n' > "$R/facts/project/changes.jsonl"
  printf '<!-- projection -->\n' > "$R/facts/requirements/tickets/progress-current.md"
  printf 'r\n' > "$R/facts/requirements/runs/r1.json"
  cat > "$R/facts/project/artifacts.yaml" <<'EOF'
# fixture 登记文件（与被测脚本数据块基线口径互恰）
artifacts:
  - id: agents-md
    path: AGENTS.md
    kind: governance
    lifecycle: Seed
  - id: scripts-tool
    path: rules/implementation/scripts/tool.sh
    kind: script
    lifecycle: Adapter
  - id: rules-notes
    path: rules/notes.md
    kind: spec
    lifecycle: Conditional
  - id: role-impl
    path: rules/implementation/roles/impl.md
    kind: governance
    lifecycle: Seed
  - id: tickets-aggregate
    path: facts/requirements/tickets/*.md（fixture 聚合登记）
    kind: record
    lifecycle: Record
  - id: micro-ledger
    path: facts/project/micro.jsonl（道账本，懒创建）
    kind: record
    lifecycle: Record
  - id: yaml-self
    path: facts/project/artifacts.yaml
    kind: index
    lifecycle: Seed
EOF
}

suite_check_artifacts() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='check-artifacts'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/rt
  mkdir -p "$D"
  CA="$SCRIPT_DIR/check-artifacts.sh"
  HC="$SCRIPT_DIR/host-config.sh"
  REF="$SCRIPT_DIR/../references"

  # 正例 P1：登记↔实物全对账 → exit 0；micro.jsonl 登记暂缺走懒创建 SKIP（不计缺口）
  rt_build_fixture "$D/p1"
  sh "$CA" "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例 P1 全对账 → exit 0'
  else
    bad '正例 P1 全对账 → exit 0' "exit=$rc $(head -n 2 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P2：两条不同规范化路径可同时登记；重复斜杠和点段折叠规则由规范化器处理。
  rt_build_fixture "$D/p2"
  sh "$CA" "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if require_out 'suite-check-artifacts 目标输出在场' "$D/p2.out" && [ "$rc" -eq 0 ] && ! grep -q '规范化 path 重复' "$D/p2.out"; then
    ok '正例 P2 不同登记 id 的独立规范化路径 → exit 0'
  else
    bad '正例 P2 不同规范化路径 → exit 0' "exit=$rc $(grep '规范化 path 重复' "$D/p2.out" | head -n 1)"
  fi

  # 负例 N7/N8：kind/lifecycle 不在模板唯一枚举权威内时 fail-closed 并指名具体值。
  rt_build_fixture "$D/n7"
  sed 's/kind: governance/kind: bogus-kind/' "$D/n7/facts/project/artifacts.yaml" > "$D/n7/artifacts.tmp" \
    && mv "$D/n7/artifacts.tmp" "$D/n7/facts/project/artifacts.yaml"
  sh "$CA" "$D/n7" > "$D/n7.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'kind 未知: agents-md=bogus-kind' "$D/n7.out"; then
    ok '负例 N7 未知 kind → exit 2 并指名非法值'
  else
    bad '负例 N7 未知 kind → exit 2 并指名非法值' "exit=$rc"
  fi

  rt_build_fixture "$D/n8"
  sed 's/lifecycle: Seed/lifecycle: Live/' "$D/n8/facts/project/artifacts.yaml" > "$D/n8/artifacts.tmp" \
    && mv "$D/n8/artifacts.tmp" "$D/n8/facts/project/artifacts.yaml"
  sh "$CA" "$D/n8" > "$D/n8.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'lifecycle 未知: agents-md=Live' "$D/n8.out"; then
    ok '负例 N8 未知 lifecycle → exit 2 并指名非法值'
  else
    bad '负例 N8 未知 lifecycle → exit 2 并指名非法值' "exit=$rc"
  fi

  # 负例 N9：重复分隔符/点段规范化后碰撞，报出两个 id 和冲突路径。
  rt_build_fixture "$D/n9"
  sed 's|path: rules/implementation/roles/impl.md|path: rules//implementation/./scripts/tool.sh|' "$D/n9/facts/project/artifacts.yaml" > "$D/n9/artifacts.tmp" \
    && mv "$D/n9/artifacts.tmp" "$D/n9/facts/project/artifacts.yaml"
  sh "$CA" "$D/n9" > "$D/n9.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '规范化 path 重复: role-impl 与 scripts-tool' "$D/n9.out"; then
    ok '负例 N9 重复规范化 path → exit 2 并指名冲突项'
  else
    bad '负例 N9 重复规范化 path → exit 2 并指名冲突项' "exit=$rc"
  fi
  if require_out 'suite-check-artifacts 目标输出在场' "$D/p1.out" && grep -q 'SKIP: 条目 micro-ledger 登记目标暂缺（数据块懒创建许可）: facts/project/micro.jsonl' "$D/p1.out" && ! grep -q '^check-artifacts: FAIL' "$D/p1.out"; then
    ok '正例 P1 懒创建面登记暂缺 → SKIP 行且零 FAIL（豁免命中不报同证）'
  else
    bad '正例 P1 懒创建面登记暂缺 → SKIP 行且零 FAIL（豁免命中不报同证）' "$(head -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # 负例 N1：登记目标缺失（删已登记文件）→ exit 1 指名条目
  rt_build_fixture "$D/n1"
  rm "$D/n1/rules/implementation/roles/impl.md"
  sh "$CA" "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 条目 role-impl 登记目标不存在: rules/implementation/roles/impl.md' "$D/n1.out"; then
    ok '负例 N1 登记目标缺失 → exit 1 指名条目'
  else
    bad '负例 N1 登记目标缺失 → exit 1 指名条目' "exit=$rc"
  fi

  # 负例 N2：受管范围新增未登记文件 → exit 1 指名路径
  rt_build_fixture "$D/n2"
  printf 'stray\n' > "$D/n2/rules/stray.md"
  sh "$CA" "$D/n2" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 受管文件未登记: rules/stray.md' "$D/n2.out"; then
    ok '负例 N2 受管文件未登记 → exit 1 指名路径'
  else
    bad '负例 N2 受管文件未登记 → exit 1 指名路径' "exit=$rc"
  fi

  # 负例 N3：豁免命中不报——runs/ 整目录内未登记新增文件 → exit 0 且零 FAIL
  rt_build_fixture "$D/n3"
  printf 'x\n' > "$D/n3/facts/requirements/runs/extra.json"
  sh "$CA" "$D/n3" > "$D/n3.out" 2>&1
  rc=$?
  if require_out 'suite-check-artifacts 目标输出在场' "$D/n3.out" && [ "$rc" -eq 0 ] && ! grep -q '^check-artifacts: FAIL' "$D/n3.out"; then
    ok '负例 N3 豁免目录内未登记文件命中豁免 → exit 0 不报'
  else
    bad '负例 N3 豁免目录内未登记文件命中豁免 → exit 0 不报' "exit=$rc"
  fi

  # 票 72 豁免迁移：校准豁免自 delivery.rules calibration 节读取（引擎零路径硬编码）。
  # 正例 M1：声明 dp_artifact_exempt → generated 内未登记文件命中豁免 exit 0
  rt_build_fixture "$D/m1"
  mkdir -p "$D/m1/facts/project/architecture/generated"
  printf '{}\n' > "$D/m1/facts/project/architecture/generated/m.json"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_artifact_exempt facts/project/architecture/generated/\n' > "$D/m1/delivery.rules"
  sh "$CA" "$D/m1" > "$D/m1.out" 2>&1
  rc=$?
  if require_out 'suite-check-artifacts 目标输出在场' "$D/m1.out" && [ "$rc" -eq 0 ] && ! grep -q '^check-artifacts: FAIL' "$D/m1.out"; then
    ok '正例 M1 delivery.rules 声明校准豁免 → generated 内未登记文件不报 exit 0（票 72 迁移）'
  else
    bad '正例 M1 delivery.rules 声明校准豁免 → generated 内未登记文件不报 exit 0（票 72 迁移）' "exit=$rc"
  fi

  # 负例 M2：无 delivery.rules → 豁免消失，生成面文件按未登记 FAIL 暴露（fail-closed）
  rt_build_fixture "$D/m2"
  mkdir -p "$D/m2/facts/project/architecture/generated"
  printf '{}\n' > "$D/m2/facts/project/architecture/generated/m.json"
  sh "$CA" "$D/m2" > "$D/m2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 受管文件未登记: facts/project/architecture/generated/m.json' "$D/m2.out"; then
    ok '负例 M2 无 delivery.rules → 生成面文件按未登记 FAIL（豁免消失 fail-closed，票 72 迁移）'
  else
    bad '负例 M2 无 delivery.rules → 生成面文件按未登记 FAIL（豁免消失 fail-closed，票 72 迁移）' "exit=$rc"
  fi

  # 负例 M3：delivery.rules 解析破坏 → exit 2 fail-closed
  rt_build_fixture "$D/m3"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_bogus x\n' > "$D/m3/delivery.rules"
  sh "$CA" "$D/m3" > "$D/m3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'delivery.rules 解析破坏（fail-closed，不产生部分结论）' "$D/m3.out"; then
    ok '负例 M3 delivery.rules 解析破坏 → exit 2 fail-closed（票 72 迁移）'
  else
    bad '负例 M3 delivery.rules 解析破坏 → exit 2 fail-closed（票 72 迁移）' "exit=$rc"
  fi

  # 负例 N4：登记解析破坏（条目缺 path 字段）→ exit 2 fail-closed
  rt_build_fixture "$D/n4"
  grep -v '    path: rules/notes.md' "$D/n4/facts/project/artifacts.yaml" > "$D/y4.tmp" \
    && mv "$D/y4.tmp" "$D/n4/facts/project/artifacts.yaml"
  sh "$CA" "$D/n4" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '登记解析破坏（fail-closed，不产生部分结论）' "$D/n4.out" && grep -q '条目缺 path 字段: rules-notes' "$D/n4.out"; then
    ok '负例 N4 登记解析破坏 → exit 2 且指名行与条目'
  else
    bad '负例 N4 登记解析破坏 → exit 2 且指名行与条目' "exit=$rc"
  fi

  # 用法负例 N5/N6：无参数 → exit 2；repo-root 不存在 → exit 2
  sh "$CA" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N5 无参数 → exit 2'
  else
    bad '负例 N5 无参数 → exit 2' "exit=$rc"
  fi
  sh "$CA" "$D/no-such-root" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N6 repo-root 不存在 → exit 2'
  else
    bad '负例 N6 repo-root 不存在 → exit 2' "exit=$rc"
  fi

  # ============================================================
  # host-config：宿主用户级配置对账（缺省 dry-run 零写入、写入备份与幂等、
  # 人工改动冲突停手、四类用法负例、host-profile 文档面与 adapter kind 双向对账）
  # ============================================================
  mkdir -p "$D/hc2"
  printf '[agents]\nfoo = 1\n' > "$D/hc2/config.toml"
  cp "$D/hc2/config.toml" "$D/hc2/before.copy"
  sh "$HC" --config "$D/hc2/config.toml" \
    --set 'agents.default_subagent_model=model-a' \
    --set 'model.short_context=262144' \
    --profile facts/project/host-profile.md > "$D/hc2/dry.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q '将修改（项目外）' "$D/hc2/dry.out" \
    && grep -F -q "目标: $D/hc2/config.toml" "$D/hc2/dry.out" \
    && grep -F -q 'agents.default_subagent_model = model-a' "$D/hc2/dry.out" \
    && grep -F -q 'model.short_context = 262144' "$D/hc2/dry.out" \
    && grep -F -q "备份: $D/hc2/config.toml.bak." "$D/hc2/dry.out" \
    && grep -F -q 'host-profile 建议行:' "$D/hc2/dry.out"; then
    ok 'host-config AC1 dry-run → 「将修改（项目外）」含目标绝对路径、逐行片段、.bak 备份路径与 host-profile 建议行'
  else
    bad 'host-config AC1 dry-run → 「将修改（项目外）」含目标绝对路径、逐行片段、.bak 备份路径与 host-profile 建议行' "exit=$rc"
  fi
  if cmp -s "$D/hc2/before.copy" "$D/hc2/config.toml" \
    && [ -z "$(find "$D/hc2" -maxdepth 1 -name 'config.toml.bak.*' -print)" ]; then
    ok 'host-config AC2 dry-run 零写入 → 目标逐字节不变且无备份件'
  else
    bad 'host-config AC2 dry-run 零写入 → 目标逐字节不变且无备份件'
  fi

  mkdir -p "$D/hc3"
  printf '[agents]\nfoo = 1\n' > "$D/hc3/config.toml"
  sh "$HC" --config "$D/hc3/config.toml" \
    --set 'agents.default_subagent_model=model-a' --write --confirm > "$D/hc3/w1.out" 2>&1
  rc=$?
  n_bak=$(find "$D/hc3" -maxdepth 1 -name 'config.toml.bak.*' -print | wc -l | tr -d ' ')
  if [ "$rc" -eq 0 ] && [ "$n_bak" -eq 1 ] && grep -F -q "备份: $D/hc3/config.toml.bak." "$D/hc3/w1.out" \
    && grep -F -q '# >>> agent-up host-config >>>' "$D/hc3/config.toml"; then
    ok 'host-config AC3 写入 → exit 0、先备份再追加标记块'
  else
    bad 'host-config AC3 写入 → exit 0、先备份再追加标记块' "exit=$rc bak=$n_bak"
  fi
  cp "$D/hc3/config.toml" "$D/hc3/written.copy"
  sh "$HC" --config "$D/hc3/config.toml" \
    --set 'agents.default_subagent_model=model-a' --write --confirm > "$D/hc3/w2.out" 2>&1
  rc=$?
  n_bak2=$(find "$D/hc3" -maxdepth 1 -name 'config.toml.bak.*' -print | wc -l | tr -d ' ')
  if [ "$rc" -eq 0 ] && [ "$n_bak2" -eq 1 ] && grep -q '幂等跳过' "$D/hc3/w2.out" \
    && cmp -s "$D/hc3/written.copy" "$D/hc3/config.toml"; then
    ok 'host-config AC3 复跑 → 块逐字一致幂等跳过 exit 0、不重复备份、文件不变'
  else
    bad 'host-config AC3 复跑 → 块逐字一致幂等跳过 exit 0、不重复备份、文件不变' "exit=$rc bak=$n_bak2"
  fi
  sed 's/^agents\.default_subagent_model = model-a$/agents.default_subagent_model = model-x/' \
    "$D/hc3/config.toml" > "$D/hc3/tamper.tmp" && mv "$D/hc3/tamper.tmp" "$D/hc3/config.toml"
  cp "$D/hc3/config.toml" "$D/hc3/tampered.copy"
  sh "$HC" --config "$D/hc3/config.toml" \
    --set 'agents.default_subagent_model=model-a' --write --confirm > "$D/hc3/w3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '不一致' "$D/hc3/w3.out" \
    && grep -F -q "$D/hc3/config.toml" "$D/hc3/w3.out" \
    && cmp -s "$D/hc3/tampered.copy" "$D/hc3/config.toml"; then
    ok 'host-config AC3 人工改块 → exit 1 指名文件、不覆盖、文件不变'
  else
    bad 'host-config AC3 人工改块 → exit 1 指名文件、不覆盖、文件不变' "exit=$rc"
  fi

  if grep -q '仅单档' "$REF/adapters/codex.md" \
    && grep -q '角色级模型键：待实测' "$REF/adapters/codex.md" \
    && grep -q 'model_tier:' "$REF/adapters/codex.md"; then
    ok 'host-config AC4 宿主文件 §2.6 单档口径与降级记录格式在场'
  else
    bad 'host-config AC4 宿主文件 §2.6 单档口径与降级记录格式在场'
  fi
  if grep -F -q '| 宿主 | 三档取值 | 落地方式 | 状态 |' "$REF/adapters/README.md" \
    && grep -q '已写入' "$REF/adapters/README.md" \
    && grep -q '仅片段' "$REF/adapters/README.md" \
    && grep -q '降级 inherit＋原因' "$REF/adapters/README.md" \
    && grep -q '待实测' "$REF/adapters/README.md"; then
    ok 'host-config AC4 adapters README → host-profile 四列表头与四个状态取值在场'
  else
    bad 'host-config AC4 adapters README → host-profile 四列表头与四个状态取值在场'
  fi

  rt_build_fixture "$D/h5"
  printf '# host-profile\n' > "$D/h5/facts/project/host-profile.md"
  cat >> "$D/h5/facts/project/artifacts.yaml" <<'EOF'
  - id: host-profile
    path: facts/project/host-profile.md
    kind: adapter
    lifecycle: Adapter
EOF
  sh "$CA" "$D/h5" > "$D/h5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^check-artifacts: FAIL' "$D/h5.out"; then
    ok 'host-config AC5 host-profile 以 kind: adapter 登记 → 双向对账 exit 0'
  else
    bad 'host-config AC5 host-profile 以 kind: adapter 登记 → 双向对账 exit 0' "exit=$rc"
  fi
  rt_build_fixture "$D/h6"
  printf '# host-profile\n' > "$D/h6/facts/project/host-profile.md"
  sh "$CA" "$D/h6" > "$D/h6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 受管文件未登记: facts/project/host-profile.md' "$D/h6.out"; then
    ok 'host-config AC5 host-profile 未登记 → 反向对账 exit 1 指名路径'
  else
    bad 'host-config AC5 host-profile 未登记 → 反向对账 exit 1 指名路径' "exit=$rc"
  fi

  sh "$HC" --config "$D/hc2/config.toml" --set 'a=b' --write >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then
    ok 'host-config 负例 --write 缺 --confirm → exit 2'
  else
    bad 'host-config 负例 --write 缺 --confirm → exit 2'
  fi
  sh "$HC" --config "$D/hc2/config.toml" --set 'bad key=1' >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then
    ok 'host-config 负例 非法键 → exit 2'
  else
    bad 'host-config 负例 非法键 → exit 2'
  fi
  sh "$HC" --config "$D/hc2/config.toml" --set 'a=' >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then
    ok 'host-config 负例 空值 → exit 2'
  else
    bad 'host-config 负例 空值 → exit 2'
  fi
  sh "$HC" --config "$D/hc2/config.toml" --set 'a=b' --bogus >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then
    ok 'host-config 负例 未知参数 → exit 2'
  else
    bad 'host-config 负例 未知参数 → exit 2'
  fi

  mkdir -p "$D/hc7"
  sh "$HC" --config "$D/hc7/new.toml" --set 'a=b' --write --confirm > "$D/hc7/w.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '目标原不存在，新建' "$D/hc7/w.out" && grep -F -q 'a = b' "$D/hc7/new.toml"; then
    ok 'host-config 正例 目标不存在 → 新建并写块、备份行报无备份'
  else
    bad 'host-config 正例 目标不存在 → 新建并写块、备份行报无备份' "exit=$rc"
  fi

  suite_summary 'check-artifacts'
}
