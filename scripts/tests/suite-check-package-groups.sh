#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite check-package-groups "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh 使用（shellcheck 单文件视野误报）

# suite: check-package-groups（票 291 自 suite-check-package 拆出的分组负例夹具面）：
# 按被检能力分组的整包变异负例——检查 13 生成物/检查 21 references 闭合与导航/
# 检查 22 规则块格式/检查 24 布局引用/检查 25 待定声明/检查 26 适配器注册表闭合/
# 检查 27 适配差异一致性/检查 28 生成漂移；每组 cp -R 独立夹具、单一变异归因。

suite_check_package_groups() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='check-package-groups'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/DIRcheck-package-groups
  mkdir -p "$D"
  REPO_SIDE="$PKG_ROOT/../rules/implementation/scripts"
  CP_ONLY_IDS=''
  if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    printf 'SKIP  [check-package-groups] main-only 件不在场（worktree 栅栏）——夹具无法成立，覆盖归主检出\n'
    suite_summary 'check-package-groups'
    return 0
  fi
  # 正例基线输出（P29～P35 逐行断言读本文件）：与主套件同一生成命令（零写入审计面）。
  sh "$SCRIPT_DIR/check-package.sh" "$PKG_ROOT" > "$D/act.positive" 2>&1 || true
  cp_manifest="$PKG_ROOT/scripts/package-manifest.rules"
  cp_n_entries=$(LC_ALL=C grep -c '^pm_entry ' "$cp_manifest" 2>/dev/null || true)
  cp_n_templates=$(LC_ALL=C grep -c '^pm_template ' "$cp_manifest" 2>/dev/null || true)
  cp_n_scripts=$(LC_ALL=C grep -c '^pm_script ' "$cp_manifest" 2>/dev/null || true)
  cp_mirror_pairs=0
  # shellcheck disable=SC2013  # manifest pm_mirror 文件名为单 token（清单加载段禁空白），词分隔循环安全
  for _cpm in $(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$cp_manifest"); do
    if [ -f "$PKG_ROOT/scripts/$_cpm" ]; then cp_mirror_pairs=$((cp_mirror_pairs + 1)); fi
  done

  # 票 190 检查 21 负例组（references 树成员闭合与导航；cp 副本 mktemp 纪律，断言独立
  # 重建：每组夹具只注入单点缺陷，FAIL 指名逐字断言）。
  # 负例 N28：references 子树新增未登记文件 → exit 1 且 FAIL: 21 指名条目（成员增漏登记）。
  pkg_copy "$PKG_ROOT" "$D/pkgcopy24"
  printf 'x' > "$D/pkgcopy24/references/workflows/harness-fixture-extra.txt"
  CP_ONLY_IDS='21'
  sh "$D/pkgcopy24/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgcopy24" >"$D/act.n28" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 21 references 树成员闭合与导航' "$D/act.n28" \
    && grep -q 'references 全树未登记条目' "$D/act.n28" \
    && grep -q 'references/workflows/harness-fixture-extra.txt' "$D/act.n28"; then
    ok '负例 N28 references 子树新增未登记文件 → exit 1 且 FAIL: 21 指名条目'
  else
    bad '负例 N28 references 子树新增未登记文件 → exit 1 且 FAIL: 21 指名条目' "exit=$rc"
  fi

  # 负例 N29：删除已登记 references 成员（triage.yaml）→ exit 1 且 FAIL: 1 指名缺件
  # （成员删漏销登记＝登记与实物漂移的第一拦截面，检查 1 必需入口口径）。
  pkg_copy "$PKG_ROOT" "$D/pkgcopy25"
  rm -f "$D/pkgcopy25/references/workflows/triage.yaml"
  CP_ONLY_IDS='1'
  sh "$D/pkgcopy25/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgcopy25" >"$D/act.n29" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q "^FAIL: 1 必需入口存在（${cp_n_entries} 个文件）" "$D/act.n29" \
    && grep -q '  - references/workflows/triage.yaml' "$D/act.n29"; then
    ok '负例 N29 删除已登记 references 成员 → exit 1 且 FAIL: 1 指名缺件'
  else
    bad '负例 N29 删除已登记 references 成员 → exit 1 且 FAIL: 1 指名缺件' "exit=$rc"
  fi

  # 负例 N30：坏相对链接（目标不存在）注入 README → exit 1 且 FAIL: 21 指名文件:行号
  # 与目标（链接检查锚点＝行内 ](target)，外链与纯锚点不在口径）。
  pkg_copy "$PKG_ROOT" "$D/pkgcopy26"
  printf '\nharness fixture 坏链接注入行：见 [gone](harness-fixture-gone.md)。\n' >> "$D/pkgcopy26/references/README.md"
  CP_ONLY_IDS='21'
  sh "$D/pkgcopy26/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgcopy26" >"$D/act.n30" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 21 references 树成员闭合与导航' "$D/act.n30" \
    && grep -q 'references/README.md:[0-9][0-9]* 坏相对链接（目标不存在）: harness-fixture-gone.md' "$D/act.n30"; then
    ok '负例 N30 坏相对链接注入 → exit 1 且 FAIL: 21 指名文件:行号与目标'
  else
    bad '负例 N30 坏相对链接注入 → exit 1 且 FAIL: 21 指名文件:行号与目标' "exit=$rc"
  fi

  # 负例 N31：一级新增目录未入 README 目录清单投影 → exit 1 且 FAIL: 21 双报
  # （全树未登记条目＋一级条目未在投影登记——数据/实物＝机器真相、README 表＝人读投影）。
  pkg_copy "$PKG_ROOT" "$D/pkgcopy27"
  mkdir -p "$D/pkgcopy27/references/harness-fixture-dir"
  printf 'x' > "$D/pkgcopy27/references/harness-fixture-dir/extra.txt"
  CP_ONLY_IDS='21'
  sh "$D/pkgcopy27/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgcopy27" >"$D/act.n31" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 21 references 树成员闭合与导航' "$D/act.n31" \
    && grep -q 'references/harness-fixture-dir/extra.txt' "$D/act.n31" \
    && grep -q 'references/ 一级条目未在 README 目录清单登记: harness-fixture-dir' "$D/act.n31"; then
    ok '负例 N31 一级新增目录未入 README 投影 → exit 1 且 FAIL: 21 双报（未登记条目＋投影缺名）'
  else
    bad '负例 N31 一级新增目录未入 README 投影 → exit 1 且 FAIL: 21 双报（未登记条目＋投影缺名）' "exit=$rc"
  fi

  # 票 276 检查 13 生成物核对夹具组（源仓语境＝仓侧 rules/implementation/scripts/
  # 在场；消费项目语境该目录不存在，整组显式 SKIP 不计数，覆盖归源仓；全部夹具 mktemp 纪律）。
  if [ -d "$REPO_SIDE" ]; then
    # 负例 N32：仓侧生成物缺失（少生成一件 health-summary.sh）→ exit 1 且 FAIL: 13 指名缺件。
    mkdir -p "$D/mrepo2/rules/implementation/scripts"
    pkg_copy "$PKG_ROOT" "$D/mrepo2/agent-up"
    # shellcheck disable=SC2013  # 清单 pm_mirror 文件名为单 token，词分隔循环安全
    for m in $(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$PKG_ROOT/scripts/package-manifest.rules"); do
      if [ -f "$PKG_ROOT/scripts/$m" ] && [ "$m" != "health-summary.sh" ]; then
        cp "$PKG_ROOT/scripts/$m" "$D/mrepo2/rules/implementation/scripts/$m"
      fi
    done
    CP_ONLY_IDS='13'
    sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/mrepo2/agent-up" >"$D/act.n32" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FAIL: 13 镜像生成物与包侧源一致' "$D/act.n32" \
      && grep -q 'rules/implementation/scripts/health-summary.sh 生成物缺失' "$D/act.n32"; then
      ok '负例 N32 仓侧生成物缺失 → exit 1 且 FAIL: 13 指名缺件'
    else
      bad '负例 N32 仓侧生成物缺失 → exit 1 且 FAIL: 13 指名缺件' "exit=$rc"
    fi

    # 负例 N33（改判）：package-only 件在仓侧的同名实例非生成物 → 不判差异（exit 0）。
    mkdir -p "$D/mrepo3/rules/implementation/scripts"
    cp -R "$PKG_ROOT" "$D/mrepo3/agent-up"
    # shellcheck disable=SC2013  # 清单 pm_mirror 文件名为单 token，词分隔循环安全
    for m in $(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$PKG_ROOT/scripts/package-manifest.rules"); do
      if [ -f "$PKG_ROOT/scripts/$m" ]; then
        cp "$PKG_ROOT/scripts/$m" "$D/mrepo3/rules/implementation/scripts/$m"
      fi
    done
    printf '# stale package-only fixture\n' > "$D/mrepo3/rules/implementation/scripts/verify-contract.sh"
    CP_ONLY_IDS='13'
    sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/mrepo3/agent-up" >"$D/act.n33" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -q "^PASS: 13 镜像生成物与包侧源一致（核对 ${cp_mirror_pairs} 件）" "$D/act.n33"; then
      ok '负例 N33 package-only 仓侧同名实例非生成物 → exit 0 不判差异'
    else
      bad '负例 N33 package-only 仓侧同名实例非生成物 → exit 0 不判差异' "exit=$rc"
    fi

    # 正例 P1：全量生成物 + package-only 过渡态同名实例 → exit 0 且 PASS: 13 核对 N 件。
    mkdir -p "$D/porepo/rules/implementation/scripts"
    pkg_copy "$PKG_ROOT" "$D/porepo/agent-up"
    # shellcheck disable=SC2013  # 清单 pm_mirror 文件名为单 token，词分隔循环安全
    for m in $(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$PKG_ROOT/scripts/package-manifest.rules"); do
      if [ -f "$PKG_ROOT/scripts/$m" ]; then
        cp "$PKG_ROOT/scripts/$m" "$D/porepo/rules/implementation/scripts/$m"
      fi
    done
    printf '# stale transition copy\n' > "$D/porepo/rules/implementation/scripts/test-checkpoint-recovery.sh"
    CP_ONLY_IDS='13,21'
    sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/porepo/agent-up" >"$D/act.p1" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -q "^PASS: 13 镜像生成物与包侧源一致（核对 ${cp_mirror_pairs} 件）" "$D/act.p1" \
      && grep -q '^PASS: 21 references 树成员闭合与导航' "$D/act.p1"; then
      ok "正例 P1 全量生成物 + package-only 过渡态同名实例 → exit 0 且 PASS: 13 核对 ${cp_mirror_pairs} 件"
    else
      bad '正例 P1 全量生成物 + package-only 过渡态同名实例 → exit 0 且 PASS: 13 核对件数' "exit=$rc"
    fi
  else
    printf 'SKIP  [check-package] 仓侧 rules/implementation/scripts 不在场（消费项目语境）——检查 13 生成物核对夹具组跳过，覆盖归源仓\n'
  fi

  # 检查 22 组（规则块九字段格式；夹具全 mktemp，负例每组单点缺陷，FAIL 指名字段或 ID
  # 逐字断言）。检查 23（索引节序言短指针）已随模板 §16 退役，无宿主即无断言面。
  # 负例 N34：缺九字段——core.md.tmpl R-CO-001 块体删 Forbidden 行 → exit 1 且
  # FAIL: 22 指名 ID 与缺失字段名（目标块无既有豁免联动，其余 35 块照旧）。
  pkg_copy "$PKG_ROOT" "$D/pkgrb1"
  grep -v '^\- \*\*Forbidden\*\*：未经确认写文件' "$D/pkgrb1/references/templates/core.md.tmpl" > "$D/rb1.tmp" \
    && mv "$D/rb1.tmp" "$D/pkgrb1/references/templates/core.md.tmpl"
  CP_ONLY_IDS='22'
  sh "$D/pkgrb1/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgrb1" >"$D/act.n34" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n34" \
    && grep -q 'R-CO-001 块体缺字段（references/templates/core.md.tmpl:[0-9][0-9]* 起）: Forbidden' "$D/act.n34"; then
    ok '负例 N34 规则块删一字段（Forbidden）→ exit 1 且 FAIL: 22 指名 ID 与缺失字段'
  else
    bad '负例 N34 规则块删一字段（Forbidden）→ exit 1 且 FAIL: 22 指名 ID 与缺失字段' "exit=$rc"
  fi

  # 负例 N35：非法 Level——R-CO-001 标题 Level 改自造值 SHALL → exit 1 且 FAIL: 22 指名
  # ID 与标题原文（受控四值 MUST/MUST NOT/SHOULD/MAY 外零容忍）。
  pkg_copy "$PKG_ROOT" "$D/pkgrb2"
  # shellcheck disable=SC2016  # sed 程序刻意字面（反引号为文本字面量，wiki 长尾误报）
  sed 's/^#### R-CO-001 授权先于写入（G1） `MUST`$/#### R-CO-001 授权先于写入（G1） `SHALL`/' "$D/pkgrb2/references/templates/core.md.tmpl" > "$D/rb2.tmp" \
    && mv "$D/rb2.tmp" "$D/pkgrb2/references/templates/core.md.tmpl"
  CP_ONLY_IDS='22'
  sh "$D/pkgrb2/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgrb2" >"$D/act.n35" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n35" \
    && grep -q 'R-CO-001 标题行 Level 缺失或非法（须 MUST/MUST NOT/SHOULD/MAY，标题：#### R-CO-001 授权先于写入（G1） SHALL）' "$D/act.n35"; then
    ok '负例 N35 规则块 Level 改自造值（SHALL）→ exit 1 且 FAIL: 22 指名 ID 与标题'
  else
    bad '负例 N35 规则块 Level 改自造值（SHALL）→ exit 1 且 FAIL: 22 指名 ID 与标题' "exit=$rc"
  fi

  # 负例 N36：重复 ID——core.md.tmpl 整块复制 R-CO-001（标题＋七字段体，双块均合法，
  # 单点只触发 ID 唯一性）→ exit 1 且 FAIL: 22 指名 ID 与两处文件:行号。
  pkg_copy "$PKG_ROOT" "$D/pkgrb3"
  awk '{ print } /^#### R-CO-001 / { inblk = 1; buf = $0 "\n"; next } inblk { buf = buf $0 "\n" } inblk && /^- \*\*Authority\*\*：/ { printf "%s", buf; inblk = 0 }' \
    "$D/pkgrb3/references/templates/core.md.tmpl" > "$D/rb3.tmp" \
    && mv "$D/rb3.tmp" "$D/pkgrb3/references/templates/core.md.tmpl"
  CP_ONLY_IDS='22'
  sh "$D/pkgrb3/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgrb3" >"$D/act.n36" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n36" \
    && grep -q '规则块 ID 重复（全局唯一，不得复用）: R-CO-001（references/templates/core.md.tmpl:[0-9][0-9]* references/templates/core.md.tmpl:[0-9][0-9]*）' "$D/act.n36"; then
    ok '负例 N36 整块复制重复 ID → exit 1 且 FAIL: 22 指名 ID 与两处行号'
  else
    bad '负例 N36 整块复制重复 ID → exit 1 且 FAIL: 22 指名 ID 与两处行号' "exit=$rc"
  fi

  # 正例 P3：modern 相对链接正例——AGENTS.md.tmpl 注入生成布局全集内目标（rules/project.md
  # ∈ artifacts-yaml.tmpl path 行）→ exit 0 且 PASS: 24、modern 链接计数 9→10。
  pkg_copy "$PKG_ROOT" "$D/pkgl1"
  printf '\nharness fixture 注入行：见 [项目协议](rules/project.md)。\n' >> "$D/pkgl1/references/templates/AGENTS.md.tmpl"
  CP_ONLY_IDS='24'
  sh "$D/pkgl1/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl1" >"$D/act.p3" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 24 布局引用分类与失效检测' "$D/act.p3" \
    && grep -q 'modern 链接 5 个' "$D/act.p3"; then
    ok '正例 P3 modern 相对链接（全集内目标）注入 → exit 0 且 PASS: 24 链接计数随动'
  else
    bad '正例 P3 modern 相对链接（全集内目标）注入 → exit 0 且 PASS: 24 链接计数随动' "exit=$rc"
  fi

  # 负例 N41：modern 坏链——注入全集外 modern 目标 → exit 1 且 FAIL: 24 指名文件:行号、
  # 目标与分类（modern）。
  pkg_copy "$PKG_ROOT" "$D/pkgl2"
  printf '\nharness fixture 坏链接注入行：见 [不存在件](rules/harness-fixture-gone.md)。\n' >> "$D/pkgl2/references/templates/AGENTS.md.tmpl"
  CP_ONLY_IDS='24'
  sh "$D/pkgl2/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl2" >"$D/act.n41" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 24 布局引用分类与失效检测' "$D/act.n41" \
    && grep -q 'references/templates/AGENTS.md.tmpl:[0-9][0-9]* modern 布局相对链接目标不在生成布局全集（分类 modern）: rules/harness-fixture-gone.md' "$D/act.n41"; then
    ok '负例 N41 modern 坏链（全集外目标）→ exit 1 且 FAIL: 24 指名文件:行号与目标（分类 modern）'
  else
    bad '负例 N41 modern 坏链（全集外目标）→ exit 1 且 FAIL: 24 指名文件:行号与目标（分类 modern）' "exit=$rc"
  fi

  # 负例 N42：modern-stale-reference——modern 面（read-policy.md）注入旧布局路径引用 →
  # exit 1 且 FAIL: 24 指名文件:行号与命中 token（分类 modern）。
  pkg_copy "$PKG_ROOT" "$D/pkgl3"
  printf '\nharness fixture 失效引用注入行 docs/development-process.md\n' >> "$D/pkgl3/references/protocol/read-policy.md"
  CP_ONLY_IDS='24'
  sh "$D/pkgl3/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl3" >"$D/act.n42" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 24 布局引用分类与失效检测' "$D/act.n42" \
    && grep -q 'references/protocol/read-policy.md:[0-9][0-9]* modern 布局面失效引用（分类 modern）: docs/development-process.md' "$D/act.n42"; then
    ok '负例 N42 modern 面注入旧布局路径 → exit 1 且 FAIL: 24 指名文件:行号与 token（分类 modern）'
  else
    bad '负例 N42 modern 面注入旧布局路径 → exit 1 且 FAIL: 24 指名文件:行号与 token（分类 modern）' "exit=$rc"
  fi

  # 正例 P4：legacy 合法保留——old-project.md（layout-legacy-file 登记件）注入旧布局
  # 路径引用 → exit 0（legacy 只计数不判罚，计数 13→14）。
  pkg_copy "$PKG_ROOT" "$D/pkgl4"
  printf '\nharness fixture legacy 注入行 docs/development-process.md\n' >> "$D/pkgl4/references/old-project.md"
  CP_ONLY_IDS='24'
  sh "$D/pkgl4/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl4" >"$D/act.p4" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 24 布局引用分类与失效检测（面 32 件，modern 失效 0 处，legacy 14 处' "$D/act.p4"; then
    ok '正例 P4 legacy 件（old-project.md）注入旧布局引用 → exit 0 且 legacy 计数 13→14'
  else
    bad '正例 P4 legacy 件（old-project.md）注入旧布局引用 → exit 0 且 legacy 计数 13→14' "exit=$rc"
  fi

  # 正例 P5：显式兼容豁免——modern 面注入行经夹具 manifest 登记行级豁免 → 该行不报、
  # exit 0（豁免生效，compatibility 计数随动）；并以哨兵 cmp 断言非目标文件未被改动
  # （检查器只读；等价语义＝兼容豁免不伴随任何文件改写，非全局替换）。
  pkg_copy "$PKG_ROOT" "$D/pkgl5"
  cp "$D/pkgl5/references/upgrade.md" "$D/pkgl5.upgrade.sentinel"
  printf '\nharness fixture 兼容注入行 docs/agent/artifacts.yaml\n' >> "$D/pkgl5/references/protocol/read-policy.md"
  p5_ln=$(wc -l < "$D/pkgl5/references/protocol/read-policy.md" | tr -d ' ')
  printf "pm_layout_compat_exempt references/protocol/read-policy.md %d 'harness fixture 兼容豁免正例（登记后该行不报）'\n" "$p5_ln" >> "$D/pkgl5/scripts/package-manifest.rules"
  CP_ONLY_IDS='24'
  sh "$D/pkgl5/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl5" >"$D/act.p5" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 24 布局引用分类与失效检测' "$D/act.p5" \
    && grep -q 'compatibility 53 处' "$D/act.p5" && cmp -s "$D/pkgl5/references/upgrade.md" "$D/pkgl5.upgrade.sentinel"; then
    ok '正例 P5 显式兼容豁免登记 → exit 0 且 compatibility 计数随动＋非目标文件哨兵 cmp 未被动'
  else
    bad '正例 P5 显式兼容豁免登记 → exit 0 且 compatibility 计数随动＋非目标文件哨兵 cmp 未被动' "exit=$rc"
  fi

  # 负例 N43：豁免不外溢（非全局替换断言）——两 modern 面各注入一行，只豁免其一 →
  # exit 1 且 FAIL: 24 仅指名未豁免件，被豁免件不报（豁免逐行显式，无隐式全局忽略）。
  pkg_copy "$PKG_ROOT" "$D/pkgl6"
  printf '\nharness fixture 已豁免注入行 docs/agent/artifacts.yaml\n' >> "$D/pkgl6/references/protocol/read-policy.md"
  n43_ln=$(wc -l < "$D/pkgl6/references/protocol/read-policy.md" | tr -d ' ')
  printf '\nharness fixture 未豁免注入行 docs/issues/index.json\n' >> "$D/pkgl6/references/protocol/governance-format.md"
  printf "pm_layout_compat_exempt references/protocol/read-policy.md %d 'harness fixture 豁免范围断言（仅罩本行）'\n" "$n43_ln" >> "$D/pkgl6/scripts/package-manifest.rules"
  CP_ONLY_IDS='24'
  sh "$D/pkgl6/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgl6" >"$D/act.n43" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.n43" \
    && [ "$rc" -eq 1 ] \
    && grep -q 'references/protocol/governance-format.md:[0-9][0-9]* modern 布局面失效引用（分类 modern）: docs/issues/index.json' "$D/act.n43" \
    && ! grep -q 'references/protocol/read-policy.md:'"$n43_ln"' modern 布局面失效引用' "$D/act.n43"; then
    ok '负例 N43 豁免不外溢 → exit 1 且仅指名未豁免件（非全局替换等价断言）'
  else
    bad '负例 N43 豁免不外溢 → exit 1 且仅指名未豁免件（非全局替换等价断言）' "exit=$rc"
  fi

  # 票 212 检查 25 待定规范声明检测夹具组（扫描面 references/adapters/*.md 的 MUST 块；
  # cp 副本 mktemp 纪律，断言独立重建）。公共规则去重后宿主映射文件零规则块，夹具锚点取
  # 结构模板 R-AT-001 的 Authority 行（MUST 块内注入，行号现场提取）。
  # 负例 N48：MUST 块内注入【待定】来源行（R-AT-001 Authority 行后）→ exit 1 且
  # FAIL: 25 指名文件:行号（规范事实不得依赖未定来源）。
  pkg_copy "$PKG_ROOT" "$D/pkpd1"
  pdln=$(grep -n '^\- \*\*Authority\*\*：capability-contract R-CC-005、SPEC-05 §4（R-05-003）。$' "$D/pkpd1/references/adapters/adapter-template.md" | head -1 | cut -d: -f1)
  { head -n "$pdln" "$D/pkpd1/references/adapters/adapter-template.md"; printf -- '- harness fixture 待定注入行：官方依据【待定】\n'; tail -n +"$((pdln + 1))" "$D/pkpd1/references/adapters/adapter-template.md"; } > "$D/zc.tmp" \
    && mv "$D/zc.tmp" "$D/pkpd1/references/adapters/adapter-template.md"
  CP_ONLY_IDS='25'
  sh "$D/pkpd1/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkpd1" >"$D/act.n48" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 25 待定规范声明检测' "$D/act.n48" \
    && grep -q "references/adapters/adapter-template.md:$((pdln + 1)) MUST 块命中【待定】来源标记" "$D/act.n48"; then
    ok '负例 N48 MUST 块注入【待定】来源行 → exit 1 且 FAIL: 25 指名文件:行号'
  else
    bad '负例 N48 MUST 块注入【待定】来源行 → exit 1 且 FAIL: 25 指名文件:行号' "exit=$rc"
  fi

  # 正例 N49：同一注入行带 <!-- pending-decl-exempt: 理由 --> 行级豁免 → 该行不报
  # exit 0（写入指引豁免生效；豁免计数 1→2 随注入行随动，R-AT-001 在册豁免不受扰）。
  pkg_copy "$PKG_ROOT" "$D/pkpd2"
  pdln2=$(grep -n '^\- \*\*Authority\*\*：capability-contract R-CC-005、SPEC-05 §4（R-05-003）。$' "$D/pkpd2/references/adapters/adapter-template.md" | head -1 | cut -d: -f1)
  { head -n "$pdln2" "$D/pkpd2/references/adapters/adapter-template.md"; printf -- '- harness fixture 待定注入行：官方依据【待定】<!-- pending-decl-exempt: harness fixture 写入指引豁免正例 -->\n'; tail -n +"$((pdln2 + 1))" "$D/pkpd2/references/adapters/adapter-template.md"; } > "$D/zc2.tmp" \
    && mv "$D/zc2.tmp" "$D/pkpd2/references/adapters/adapter-template.md"
  CP_ONLY_IDS='25'
  sh "$D/pkpd2/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkpd2" >"$D/act.n49" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 25 待定规范声明检测（MUST 块【待定】命中 0 处，豁免 2 行）' "$D/act.n49"; then
    ok '正例 N49 命中行登记行内豁免标记后不报 → exit 0 且豁免计数 1→2'
  else
    bad '正例 N49 命中行登记行内豁免标记后不报 → exit 0 且豁免计数 1→2' "exit=$rc"
  fi

  # 负例 N50：失效豁免——标记行无【待定】命中 → exit 1 且 FAIL: 25 报失效豁免
  # （防漂移静默失效，检查 12/18/24 同款口径）。
  pkg_copy "$PKG_ROOT" "$D/pkpd3"
  pdln3=$(grep -n '^\- \*\*Authority\*\*：capability-contract R-CC-005、SPEC-05 §4（R-05-003）。$' "$D/pkpd3/references/adapters/adapter-template.md" | head -1 | cut -d: -f1)
  { head -n "$pdln3" "$D/pkpd3/references/adapters/adapter-template.md"; printf -- '- harness fixture 失效豁免注入行（无待定命中）<!-- pending-decl-exempt: harness fixture 失效豁免负例 -->\n'; tail -n +"$((pdln3 + 1))" "$D/pkpd3/references/adapters/adapter-template.md"; } > "$D/zc3.tmp" \
    && mv "$D/zc3.tmp" "$D/pkpd3/references/adapters/adapter-template.md"
  CP_ONLY_IDS='25'
  sh "$D/pkpd3/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkpd3" >"$D/act.n50" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 25 待定规范声明检测' "$D/act.n50" \
    && grep -q "references/adapters/adapter-template.md:$((pdln3 + 1)) 失效豁免（pending-decl-exempt 标记行无【待定】命中或不在 MUST 块内，须复核更新或删除标记）" "$D/act.n50"; then
    ok '负例 N50 豁免标记行无命中 → exit 1 且 FAIL: 25 报失效豁免'
  else
    bad '负例 N50 豁免标记行无命中 → exit 1 且 FAIL: 25 报失效豁免' "exit=$rc"
  fi

  # 票 215 检查 26 适配器注册表闭合夹具组（单一数据源＝清单 adapter-registry 节 pm_adapter
  # 行；五向闭合逐向一负例＋加载段结构校验 fail-closed 一负例；cp 副本 mktemp 纪律，
  # manifest 改动须被引擎读到，本组以夹具包自带引擎副本运行，断言独立重建）。
  # 负例 N51（①枚举闭合加载段）：platform-enum 节删 dsh 宿主值 → 注册表 dsh 行
  # ∈ 枚举宿主值核验失败 → exit 2 fail-closed 零部分结论（stdout 零 PASS 行）且错误
  # 指名跨节失据行（先例＝pm_enforcement_target 预期等级 ∈ 词表加载段同款）。
  pkg_copy "$PKG_ROOT" "$D/pkar1"
  grep -v '^pm_platform dsh$' "$D/pkar1/scripts/package-manifest.rules" > "$D/pm51.tmp" \
    && mv "$D/pm51.tmp" "$D/pkar1/scripts/package-manifest.rules"
  CP_ONLY_IDS='26'
  sh "$D/pkar1/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar1" >"$D/act.n51" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.n51" \
    && [ "$rc" -eq 2 ] && grep -q 'platform 不在 platform-enum 节宿主值（neutral 平台无关不入注册表）: dsh' "$D/act.n51" \
    && ! grep -q '^PASS:' "$D/act.n51"; then
    ok '负例 N51 platform-enum 节删宿主值 → exit 2 fail-closed 且指名注册表平台值失据'
  else
    bad '负例 N51 platform-enum 节删宿主值 → exit 2 fail-closed 且指名注册表平台值失据' "exit=$rc"
  fi

  # 负例 N58（①枚举闭合检查段）：adapter-registry 节删 dsh 注册行 → 枚举宿主值缺
  # 注册行方向 → exit 1 且 FAIL: 26 指名（④镜像方向联动 FAIL 不断言，归本组 N54 口径）。
  # 票 222 起差异数据表 platform ∈ 注册表在加载段 fail-closed——注册行删除须同批同步
  # 差异数据表 dsh 四节行（两处漂移分别由加载段与检查 26① 指名），本负例同步删除使
  # 检查段 ① 方向可达。
  pkg_copy "$PKG_ROOT" "$D/pkar8"
  grep -v '^pm_adapter dsh ' "$D/pkar8/scripts/package-manifest.rules" > "$D/pm58.tmp" \
    && mv "$D/pm58.tmp" "$D/pkar8/scripts/package-manifest.rules"
  sed -e '/^pm_adapter_cap dsh /d' -e '/^pm_adapter_role dsh /d' -e '/^pm_adapter_exec dsh /d' -e '/^pm_adapter_dialect dsh /d' \
    "$D/pkar8/references/adapters/adapter-diffs.rules" > "$D/ad58.tmp" \
    && mv "$D/ad58.tmp" "$D/pkar8/references/adapters/adapter-diffs.rules"
  CP_ONLY_IDS='26'
  sh "$D/pkar8/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar8" >"$D/act.n58" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n58" \
    && grep -q 'platform-enum 宿主值缺注册行: dsh' "$D/act.n58"; then
    ok '负例 N58 注册表删宿主注册行 → exit 1 且 FAIL: 26 指名枚举宿主值缺注册行'
  else
    bad '负例 N58 注册表删宿主注册行 → exit 1 且 FAIL: 26 指名枚举宿主值缺注册行' "exit=$rc"
  fi

  # 负例 N52（②文件在位）：删注册表 adapter_file 实物 references/adapters/dsh.md →
  # exit 1 且 FAIL: 26 指名（检查 1/21 对入口与树闭合联动 FAIL 不断言，归各自口径）。
  pkg_copy "$PKG_ROOT" "$D/pkar2"
  rm "$D/pkar2/references/adapters/dsh.md"
  CP_ONLY_IDS='26'
  sh "$D/pkar2/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar2" >"$D/act.n52" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n52" \
    && grep -q '注册表适配器文件不存在: references/adapters/dsh.md' "$D/act.n52"; then
    ok '负例 N52 删注册表适配器文件 → exit 1 且 FAIL: 26 指名缺件'
  else
    bad '负例 N52 删注册表适配器文件 → exit 1 且 FAIL: 26 指名缺件' "exit=$rc"
  fi

  # 负例 N53（③shortcodes 闭合）：shortcodes 节删 DS 镜像行 →（短码, 所属文件）对
  # 不在册 → exit 1 且 FAIL: 26 指名（检查 10 对使用面联动 FAIL 不断言，归票 57 口径）。
  pkg_copy "$PKG_ROOT" "$D/pkar3"
  grep -v '^pm_shortcode DS references/adapters/dsh.md$' "$D/pkar3/scripts/package-manifest.rules" > "$D/pm53.tmp" \
    && mv "$D/pm53.tmp" "$D/pkar3/scripts/package-manifest.rules"
  CP_ONLY_IDS='26'
  sh "$D/pkar3/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar3" >"$D/act.n53" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n53" \
    && grep -q '注册表（短码, 所属文件）对不在 shortcodes 节: DS references/adapters/dsh.md' "$D/act.n53"; then
    ok '负例 N53 shortcodes 节删注册短码镜像行 → exit 1 且 FAIL: 26 指名失对'
  else
    bad '负例 N53 shortcodes 节删注册短码镜像行 → exit 1 且 FAIL: 26 指名失对' "exit=$rc"
  fi

  # 负例 N54（④capability targets 镜像）：capability targets 节删 dsh kind=table 行 →
  # 注册表（适配文件, coverage）对失镜像 → exit 1 且 FAIL: 26 指名（互为镜像双向闭合）。
  pkg_copy "$PKG_ROOT" "$D/pkar4"
  grep -v '^pm_capability_target references/adapters/dsh.md table ' "$D/pkar4/scripts/package-manifest.rules" > "$D/pm54.tmp" \
    && mv "$D/pm54.tmp" "$D/pkar4/scripts/package-manifest.rules"
  CP_ONLY_IDS='26'
  sh "$D/pkar4/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar4" >"$D/act.n54" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n54" \
    && grep -q '注册表（适配文件, coverage）对不在 capability targets 节 kind=table 行: references/adapters/dsh.md' "$D/act.n54"; then
    ok '负例 N54 capability targets 节删 table 行 → exit 1 且 FAIL: 26 指名镜像缺口'
  else
    bad '负例 N54 capability targets 节删 table 行 → exit 1 且 FAIL: 26 指名镜像缺口' "exit=$rc"
  fi

  # 负例 N55（⑤父 README 投影，AC3 钉死）：references/README.md adapters 行删 `dsh`
  # 平台 token → 投影缺平台 → exit 1 且 FAIL: 26 指名（父 README 不得漏列平台）。
  pkg_copy "$PKG_ROOT" "$D/pkar5"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's=`pi`/`dsh`，=`pi`，=' "$D/pkar5/references/README.md" > "$D/rr55.tmp" \
    && mv "$D/rr55.tmp" "$D/pkar5/references/README.md"
  CP_ONLY_IDS='26'
  sh "$D/pkar5/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar5" >"$D/act.n55" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n55" \
    && grep -q 'references/README.md adapters 行投影与注册表不一致（父 README 不得漏列平台）: 缺少 dsh' "$D/act.n55"; then
    ok '负例 N55 父 README adapters 行漏列平台 → exit 1 且 FAIL: 26 指名缺少 dsh'
  else
    bad '负例 N55 父 README adapters 行漏列平台 → exit 1 且 FAIL: 26 指名缺少 dsh' "exit=$rc"
  fi

  # 负例 N56（⑤目录 README 投影）：adapters/README.md 目录清单 zcode 行短码格清空 →
  # 投影缺短码 → exit 1 且 FAIL: 26 指名（投影不另立登记事实，漂移即 FAIL）。
  pkg_copy "$PKG_ROOT" "$D/pkar6"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/| `ZC` |/|  |/' "$D/pkar6/references/adapters/README.md" > "$D/ar56.tmp" \
    && mv "$D/ar56.tmp" "$D/pkar6/references/adapters/README.md"
  CP_ONLY_IDS='26'
  sh "$D/pkar6/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar6" >"$D/act.n56" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 26 适配器注册表闭合' "$D/act.n56" \
    && grep -q 'adapters/README.md 目录清单投影缺行或缺短码: zcode.md（ZC）' "$D/act.n56"; then
    ok '负例 N56 目录 README 投影行缺短码 → exit 1 且 FAIL: 26 指名'
  else
    bad '负例 N56 目录 README 投影行缺短码 → exit 1 且 FAIL: 26 指名' "exit=$rc"
  fi

  # 负例 N57（加载段结构校验，AC4 钉死）：adapter-registry 节追加重复 ZC 短码行 →
  # 短码全局唯一由单一数据源加载段验证 → exit 2 fail-closed 零部分结论（stdout 零
  # PASS 行），错误信息指名跨行短码。
  pkg_copy "$PKG_ROOT" "$D/pkar7"
  grep '^pm_adapter zcode ' "$PKG_ROOT/scripts/package-manifest.rules" >> "$D/pkar7/scripts/package-manifest.rules"
  CP_ONLY_IDS='26'
  sh "$D/pkar7/scripts/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkar7" >"$D/act.n57" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.n57" \
    && [ "$rc" -eq 2 ] && grep -q 'adapter-registry 节第 6 行: shortcode 跨行重复（短码全局唯一由本节单源验证）: ZC' "$D/act.n57" \
    && ! grep -q '^PASS:' "$D/act.n57"; then
    ok '负例 N57 注册表追加重复短码行 → exit 2 fail-closed 零部分结论且指名跨行短码'
  else
    bad '负例 N57 注册表追加重复短码行 → exit 2 fail-closed 零部分结论且指名跨行短码' "exit=$rc"
  fi

  # 票 222 检查 27 适配差异数据表一致性夹具组（数据源＝包根相对落位
  # references/adapters/adapter-diffs.rules，引擎读 pkg_root 数据——主检出引擎可直接
  # 运行，manifest 零夹具改动；cp 副本 mktemp 纪律，断言独立重建）。
  # 负例 AD1（数据侧漂移，改数据不改文档）：capability-map 节 zcode inspect 行工具串
  # 单处篡改 → exit 1 且 FAIL: 27 指名宿主与段（九行能力表）与首个差异行号。
  pkg_copy "$PKG_ROOT" "$D/pkad1"
  sed "s/pm_adapter_cap zcode inspect 'Glob + Read'/pm_adapter_cap zcode inspect 'Glob + ReadX'/" \
    "$D/pkad1/references/adapters/adapter-diffs.rules" > "$D/ad1.tmp" \
    && mv "$D/ad1.tmp" "$D/pkad1/references/adapters/adapter-diffs.rules"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad1" >"$D/act.ad1" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 27 适配差异数据表一致性' "$D/act.ad1" \
    && grep -q 'references/adapters/zcode.md 九行能力表与差异数据表漂移（段＝capability-map；首个差异行 1，0＝行数不齐）' "$D/act.ad1"; then
    ok '负例 AD1 差异数据表单处篡改（改数据不改文档）→ exit 1 且 FAIL: 27 指名宿主与段'
  else
    bad '负例 AD1 差异数据表单处篡改（改数据不改文档）→ exit 1 且 FAIL: 27 指名宿主与段' "exit=$rc"
  fi

  # 负例 AD2（文档侧漂移，改文档不改数据）：宿主 zcode.md 对照表 search 行工具串单处
  # 篡改 → exit 1 且 FAIL: 27 指名宿主与段（行序敏感全等的反方向；首个差异行 2）。
  pkg_copy "$PKG_ROOT" "$D/pkad2"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/| search | Grep、Glob | 文件名与内容检索 |/| search | Grep、GlobX | 文件名与内容检索 |/' \
    "$D/pkad2/references/adapters/zcode.md" > "$D/ad2.tmp" \
    && mv "$D/ad2.tmp" "$D/pkad2/references/adapters/zcode.md"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad2" >"$D/act.ad2" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 27 适配差异数据表一致性' "$D/act.ad2" \
    && grep -q 'references/adapters/zcode.md 九行能力表与差异数据表漂移（段＝capability-map；首个差异行 2，0＝行数不齐）' "$D/act.ad2"; then
    ok '负例 AD2 宿主对照表单处篡改（改文档不改数据）→ exit 1 且 FAIL: 27 指名宿主与段'
  else
    bad '负例 AD2 宿主对照表单处篡改（改文档不改数据）→ exit 1 且 FAIL: 27 指名宿主与段' "exit=$rc"
  fi

  # 负例 AD3（锚语漂移）：宿主 zcode.md 删三处 frontmatter tools 方言签名行（锚语原文
  # 只在 §2.3 模板块行首）→ exit 1 且 FAIL: 27 指名方言锚语失据（④在场断言方向；
  # role-map 表行不含行首 tools: 形态不受扰）。
  pkg_copy "$PKG_ROOT" "$D/pkad3"
  # shellcheck disable=SC2016  # sed 程序刻意字面（方括号为字面锚语片段，非字符类）
  grep -v '^tools: \[Read, Grep, Glob, Edit, Write, Bash\]$' \
    "$D/pkad3/references/adapters/zcode.md" > "$D/ad3.tmp" \
    && mv "$D/ad3.tmp" "$D/pkad3/references/adapters/zcode.md"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad3" >"$D/act.ad3" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 27 适配差异数据表一致性' "$D/act.ad3" \
    && grep -qF 'references/adapters/zcode.md 方言签名锚语失据（段＝dialect-signature，key=frontmatter-tools-list）' "$D/act.ad3"; then
    ok '负例 AD3 宿主方言签名锚语删除 → exit 1 且 FAIL: 27 指名失据锚语（key 随报）'
  else
    bad '负例 AD3 宿主方言签名锚语删除 → exit 1 且 FAIL: 27 指名失据锚语（key 随报）' "exit=$rc"
  fi

  # 负例 AD4（加载段结构校验，fail-closed 钉死）：capability-map 节追加重复
  # （platform, primitive）行 → exit 2 零部分结论（stdout 零 PASS 行）且指名跨行重复。
  pkg_copy "$PKG_ROOT" "$D/pkad4"
  grep '^pm_adapter_cap zcode inspect ' "$PKG_ROOT/references/adapters/adapter-diffs.rules" >> "$D/pkad4/references/adapters/adapter-diffs.rules"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad4" >"$D/act.ad4" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.ad4" \
    && [ "$rc" -eq 2 ] && grep -q 'adapter-diffs capability-map 节第 46 行: （platform, primitive）跨行重复: zcode inspect' "$D/act.ad4" \
    && ! grep -q '^PASS:' "$D/act.ad4"; then
    ok '负例 AD4 差异数据表追加重复（platform, primitive）行 → exit 2 fail-closed 零部分结论且指名'
  else
    bad '负例 AD4 差异数据表追加重复（platform, primitive）行 → exit 2 fail-closed 零部分结论且指名' "exit=$rc"
  fi

  # 负例 AD5（executor-status 平台全集，R1 删除方向）：删 pm_adapter_exec zcode 整行 →
  # 加载段平台集合 ↔ 注册平台集双向全等失败 → exit 2 fail-closed 零部分结论且指名段与宿主。
  pkg_copy "$PKG_ROOT" "$D/pkad5"
  grep -v '^pm_adapter_exec zcode ' "$PKG_ROOT/references/adapters/adapter-diffs.rules" \
    > "$D/pkad5/references/adapters/adapter-diffs.rules"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad5" >"$D/act.ad5" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.ad5" \
    && [ "$rc" -eq 2 ] && grep -q 'adapter-diffs executor-status 节: 缺平台行（每注册平台恰一行）: zcode' "$D/act.ad5" \
    && ! grep -q '^PASS:' "$D/act.ad5"; then
    ok '负例 AD5 差异数据表删单平台 exec 行 → exit 2 fail-closed 且指名段与宿主'
  else
    bad '负例 AD5 差异数据表删单平台 exec 行 → exit 2 fail-closed 且指名段与宿主' "exit=$rc"
  fi

  # 负例 AD6（dialect-signature 平台全集，R1 删除方向）：删 pm_adapter_dialect zcode 整行
  # → 加载段平台集合 ↔ 注册平台集双向全等失败 → exit 2 fail-closed 零部分结论且指名段与宿主。
  pkg_copy "$PKG_ROOT" "$D/pkad6"
  grep -v '^pm_adapter_dialect zcode ' "$PKG_ROOT/references/adapters/adapter-diffs.rules" \
    > "$D/pkad6/references/adapters/adapter-diffs.rules"
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkad6" >"$D/act.ad6" 2>&1
  rc=$?
  if require_out 'suite-check-package 目标输出在场' "$D/act.ad6" \
    && [ "$rc" -eq 2 ] && grep -q 'adapter-diffs dialect-signature 节: 缺平台行（每注册平台至少一行）: zcode' "$D/act.ad6" \
    && ! grep -q '^PASS:' "$D/act.ad6"; then
    ok '负例 AD6 差异数据表删单平台 dialect 行 → exit 2 fail-closed 且指名段与宿主'
  else
    bad '负例 AD6 差异数据表删单平台 dialect 行 → exit 2 fail-closed 且指名段与宿主' "exit=$rc"
  fi

  # 票 223 检查 28 宿主差异段生成漂移夹具组（生成器＝同目录 generate-adapter-diffs.sh，
  # 数据源＝包根相对落位 adapter-diffs.rules，宿主＝references/adapters/<platform>.md；
  # 主检出引擎可直接运行，manifest 零夹具改动；cp 副本 mktemp 纪律，断言独立重建）。
  # 正例 G1（渲染无损）：`--section cap --platform zcode` 首行逐字节等于宿主对照表首行
  # （逐字节口径：只去首尾空白，不剥反引号）。
  printf '| inspect | Glob + Read | 目录与现状盘点 |\n' > "$D/exp.g1"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --section cap --platform zcode >"$D/act.g1" 2>&1
  sed -n '1p' "$D/act.g1" >"$D/act.g1.first"
  assert_eq '正例 G1 生成器 cap 首行逐字节等于宿主对照表首行（渲染无损）' "$D/act.g1.first" "$D/exp.g1"

  # 正例 G2（首轮零漂移）：现行包 `--check` exit 0 且输出计数汇总（五宿主四段条目数）。
  if sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$PKG_ROOT" --check >"$D/act.g2" 2>&1 \
    && grep -q '^OK: 生成漂移零差异（宿主 5 个，cap 45 行，role 15 行，exec 5 行，dialect 5 行）' "$D/act.g2"; then
    ok '正例 G2 生成器 --check 现行包零漂移 → exit 0 且计数汇总齐'
  else
    bad '正例 G2 生成器 --check 现行包零漂移 → exit 0 且计数汇总齐' "$(head -n 2 "$D/act.g2" | tr '\n' '|')"
  fi

  # 负例 G3（数据侧漂移，经生成器直核）：capability-map 节 zcode inspect 工具串单处篡改
  # → 生成器 --check exit 1，指名宿主文件、段与首个差异行。
  pkg_copy "$PKG_ROOT" "$D/pkgad7"
  sed "s/pm_adapter_cap zcode inspect 'Glob + Read'/pm_adapter_cap zcode inspect 'Glob + ReadX'/" \
    "$D/pkgad7/references/adapters/adapter-diffs.rules" > "$D/gd7.tmp" \
    && mv "$D/gd7.tmp" "$D/pkgad7/references/adapters/adapter-diffs.rules"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad7" --check >"$D/act.g3" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/adapters/zcode.md 九行能力表与生成输出漂移（段＝capability-map；首个差异行 1）' "$D/act.g3"; then
    ok '负例 G3 数据侧单处篡改 → 生成器 exit 1 指名宿主与段与首个差异行'
  else
    bad '负例 G3 数据侧单处篡改 → 生成器 exit 1 指名宿主与段与首个差异行' "exit=$rc"
  fi

  # 负例 G4（检查 28 接通断言）：同一数据侧篡改副本经 check-package 检 → exit 1 且
  # FAIL: 28 指名宿主与段（生成漂移检查在交付面可达路径上被行使）。
  CP_ONLY_IDS='28'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgad7" >"$D/act.g4" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 28 宿主差异段生成漂移' "$D/act.g4" \
    && grep -q 'references/adapters/zcode.md 九行能力表与生成输出漂移（段＝capability-map' "$D/act.g4"; then
    ok '负例 G4 数据改而文档未跟 → check-package FAIL: 28 指名宿主与段'
  else
    bad '负例 G4 数据改而文档未跟 → check-package FAIL: 28 指名宿主与段' "exit=$rc"
  fi

  # 负例 G5（文档侧漂移，改文档不改数据）：宿主 zcode.md 对照表 search 行单处篡改
  # → 生成器 --check exit 1，首个差异行 2（反方向同口径）。
  pkg_copy "$PKG_ROOT" "$D/pkgad8"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/| search | Grep、Glob | 文件名与内容检索 |/| search | Grep、GlobX | 文件名与内容检索 |/' \
    "$D/pkgad8/references/adapters/zcode.md" > "$D/gd8.tmp" \
    && mv "$D/gd8.tmp" "$D/pkgad8/references/adapters/zcode.md"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad8" --check >"$D/act.g5" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/adapters/zcode.md 九行能力表与生成输出漂移（段＝capability-map；首个差异行 2）' "$D/act.g5"; then
    ok '负例 G5 文档侧单处篡改 → 生成器 exit 1 指名宿主与段与首个差异行'
  else
    bad '负例 G5 文档侧单处篡改 → 生成器 exit 1 指名宿主与段与首个差异行' "exit=$rc"
  fi

  # 负例 G6（锚语失据）：宿主 zcode.md 删三处 frontmatter tools 方言签名行 → 生成器
  # --check exit 1 指名 dialect-signature 段。
  pkg_copy "$PKG_ROOT" "$D/pkgad9"
  # shellcheck disable=SC2016  # sed 程序刻意字面（方括号为字面锚语片段，非字符类）
  grep -v '^tools: \[Read, Grep, Glob, Edit, Write, Bash\]$' \
    "$D/pkgad9/references/adapters/zcode.md" > "$D/gd9.tmp" \
    && mv "$D/gd9.tmp" "$D/pkgad9/references/adapters/zcode.md"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad9" --check >"$D/act.g6" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/adapters/zcode.md 方言签名锚语失据（段＝dialect-signature）' "$D/act.g6"; then
    ok '负例 G6 方言签名锚语删除 → 生成器 exit 1 指名宿主与段'
  else
    bad '负例 G6 方言签名锚语删除 → 生成器 exit 1 指名宿主与段' "exit=$rc"
  fi

  # 正例 G7（无假阳）：数据与文档同批同步（两侧同改 inspect 工具串）→ 生成器 --check
  # exit 0（同步变更不误报，防「改两侧即红」的假阳性）。
  pkg_copy "$PKG_ROOT" "$D/pkgad10"
  sed "s/pm_adapter_cap zcode inspect 'Glob + Read'/pm_adapter_cap zcode inspect 'Glob + ReadX'/" \
    "$D/pkgad10/references/adapters/adapter-diffs.rules" > "$D/gd10a.tmp" \
    && mv "$D/gd10a.tmp" "$D/pkgad10/references/adapters/adapter-diffs.rules"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/| inspect | Glob + Read | 目录与现状盘点 |/| inspect | Glob + ReadX | 目录与现状盘点 |/' \
    "$D/pkgad10/references/adapters/zcode.md" > "$D/gd10b.tmp" \
    && mv "$D/gd10b.tmp" "$D/pkgad10/references/adapters/zcode.md"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad10" --check >"$D/act.g7" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^OK: 生成漂移零差异' "$D/act.g7"; then
    ok '正例 G7 数据与文档同批同步 → 生成器 exit 0（同步变更零假阳）'
  else
    bad '正例 G7 数据与文档同批同步 → 生成器 exit 0（同步变更零假阳）' "exit=$rc"
  fi

  # 正例 G8（强调记号逐字节）：数据表保留行内代码反引号，渲染行须与宿主原文逐字节相等
  # （claude-code execute 行；夹具期望串为该行原文，非剥反引号形态）。
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  printf '| execute | Bash | 可变更工作区状态的命令；受 `permissions` 规则约束；git_write_enforcement: policy-only（`permissions` 与 hooks 为配置面闸门，登记面无默认 git 写 deny；实现会话交付报告须记该值与降级原因） |\n' > "$D/exp.g8"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --section cap --platform claude-code >"$D/act.g8" 2>&1
  sed -n '6p' "$D/act.g8" >"$D/act.g8.row"
  assert_eq '正例 G8 强调记号行渲染结果与宿主原文逐字节相等（不剥反引号）' "$D/act.g8.row" "$D/exp.g8"

  # 负例 G9（数据侧强调记号丢失）：数据表 claude-code execute constraint 去掉两处反引号
  # （文档仍带）→ 生成器 --check exit 1，指名 claude-code.md 与 capability-map 段。
  pkg_copy "$PKG_ROOT" "$D/pkgad11"
  # shellcheck disable=SC2016  # sed 程序刻意字面（反引号为被删字符，非命令替换）
  sed 's/受 `permissions` 规则约束/受 permissions 规则约束/' \
    "$D/pkgad11/references/adapters/adapter-diffs.rules" > "$D/gd11.tmp" \
    && mv "$D/gd11.tmp" "$D/pkgad11/references/adapters/adapter-diffs.rules"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad11" --check >"$D/act.g9" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/adapters/claude-code.md 九行能力表与生成输出漂移（段＝capability-map' "$D/act.g9"; then
    ok '负例 G9 数据侧强调记号丢失 → 生成器 exit 1 指名宿主与段'
  else
    bad '负例 G9 数据侧强调记号丢失 → 生成器 exit 1 指名宿主与段' "exit=$rc"
  fi

  # 负例 G10（文档侧强调记号丢失，检查 28 接通方向）：宿主 claude-code.md execute 行去掉
  # 两处反引号（数据仍带）→ check-package exit 1 且 FAIL: 28 指名宿主与段。
  pkg_copy "$PKG_ROOT" "$D/pkgad12"
  # shellcheck disable=SC2016  # sed 程序刻意字面（反引号为被删字符，非命令替换）
  sed 's/受 `permissions` 规则约束/受 permissions 规则约束/' \
    "$D/pkgad12/references/adapters/claude-code.md" > "$D/gd12.tmp" \
    && mv "$D/gd12.tmp" "$D/pkgad12/references/adapters/claude-code.md"
  CP_ONLY_IDS='28'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgad12" >"$D/act.g10" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 28 宿主差异段生成漂移' "$D/act.g10" \
    && grep -q 'references/adapters/claude-code.md 九行能力表与生成输出漂移（段＝capability-map' "$D/act.g10"; then
    ok '负例 G10 文档侧强调记号丢失 → check-package FAIL: 28 指名宿主与段'
  else
    bad '负例 G10 文档侧强调记号丢失 → check-package FAIL: 28 指名宿主与段' "exit=$rc"
  fi

  # 负例 G11（宿主 role 行列数守卫，生成器侧）：zcode.md 角色映射表首行追加第 4 单元格
  # → 生成器 --check exit 1 且指名 role-map 段（列数非 3 的行原样输出＝漂移，不静默截断
  # 多余列）。
  pkg_copy "$PKG_ROOT" "$D/pkgad13"
  sed '/^| <role-contract-dir>\/implementation.md | inspect, search, read, edit, write, execute |/s/ |$/ extra |/' \
    "$D/pkgad13/references/adapters/zcode.md" > "$D/gd13.tmp" \
    && mv "$D/gd13.tmp" "$D/pkgad13/references/adapters/zcode.md"
  sh "$SCRIPT_DIR/generate-adapter-diffs.sh" --pkg-root "$D/pkgad13" --check >"$D/act.g11" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/adapters/zcode.md 三角色映射表与生成输出漂移（段＝role-map' "$D/act.g11"; then
    ok '负例 G11 宿主 role 行多一列 → 生成器 exit 1 指名 role-map 段'
  else
    bad '负例 G11 宿主 role 行多一列 → 生成器 exit 1 指名 role-map 段' "exit=$rc"
  fi

  # 负例 G12（检查 27 同形缺口守卫）：同一夹具经 check-package → exit 1 且 FAIL: 27 指名
  # role-map 段（角色表列数非 3 不再被静默截断）。
  CP_ONLY_IDS='27'
  sh "$SCRIPT_DIR/check-package.sh" --only "$CP_ONLY_IDS" "$D/pkgad13" >"$D/act.g12" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 27 适配差异数据表一致性' "$D/act.g12" \
    && grep -q 'references/adapters/zcode.md 三角色映射表与差异数据表漂移（段＝role-map' "$D/act.g12"; then
    ok '负例 G12 宿主 role 行多一列 → check-package FAIL: 27 指名 role-map 段'
  else
    bad '负例 G12 宿主 role 行多一列 → check-package FAIL: 27 指名 role-map 段' "exit=$rc"
  fi

  # 包级语义门禁八项（检查 29～36）：正例＝现行包正例运行的 PASS 行逐字在场（八项各自
  # 独立编号与计数，正例面即零缺陷语境）；负例＝mktemp 副本单点注入，断言 FAIL 行逐字
  # 指名文件/条目、规则与冲突类型（AC2 口径：文件、规则、冲突类型三者齐备）。
  if grep -qxF 'PASS: 29 退役能力不在活动创建路径（面 3 个，命中 0 处）' "$D/act.positive"; then
    ok '正例 P29 检查 29 退役能力不在活动创建路径 → PASS 行逐字在场（面 3 个，命中 0 处）'
  else
    bad '正例 P29 检查 29 退役能力不在活动创建路径 → PASS 行逐字在场（面 3 个，命中 0 处）' "$(grep -m1 '^..: 29' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 30 workflow transition endpoint 存在（工作流 2 件，状态 12 个，转换 11 条）' "$D/act.positive"; then
    ok '正例 P30 检查 30 workflow transition endpoint 存在 → PASS 行逐字在场（状态 12 个，转换 11 条）'
  else
    bad '正例 P30 检查 30 workflow transition endpoint 存在 → PASS 行逐字在场（状态 12 个，转换 11 条）' "$(grep -m1 '^..: 30' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 31 状态写票前有合法映射（工作流 2 件，映射 12 条，票状态词表 8 值）' "$D/act.positive"; then
    ok '正例 P31 检查 31 状态写票前有合法映射 → PASS 行逐字在场（映射 12 条，词表 8 值）'
  else
    bad '正例 P31 检查 31 状态写票前有合法映射 → PASS 行逐字在场（映射 12 条，词表 8 值）' "$(grep -m1 '^..: 31' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 32 readonly-execute 声明有 enforcement level（声明面 9 个，level 5 个，词表 5 值）' "$D/act.positive"; then
    ok '正例 P32 检查 32 readonly 声明有 enforcement level → PASS 行逐字在场（声明面 9 个，level 5 个）'
  else
    bad '正例 P32 检查 32 readonly 声明有 enforcement level → PASS 行逐字在场（声明面 9 个，level 5 个）' "$(grep -m1 '^..: 32' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 33 MUST 不引用待定规范事实（MUST 块【待定】命中 0 处，豁免 0 行；面＝adapters 外）' "$D/act.positive"; then
    ok '正例 P33 检查 33 MUST 不引用待定规范事实 → PASS 行逐字在场（adapters 外整包面）'
  else
    bad '正例 P33 检查 33 MUST 不引用待定规范事实 → PASS 行逐字在场（adapters 外整包面）' "$(grep -m1 '^..: 33' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 34 README 非唯一执行契约（登记指针 1 条，自带指针 1 行）' "$D/act.positive"; then
    ok '正例 P34 检查 34 README 非唯一执行契约 → PASS 行逐字在场（指针 1 条命中 1 行）'
  else
    bad '正例 P34 检查 34 README 非唯一执行契约 → PASS 行逐字在场（指针 1 条命中 1 行）' "$(grep -m1 '^..: 34' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 35 平台短码注册表闭合（注册 5 行，短码节 19 行，平台短码 5 个）' "$D/act.positive"; then
    ok '正例 P35 检查 35 平台短码注册表闭合 → PASS 行逐字在场（注册 5 行，平台短码 5 个）'
  else
    bad '正例 P35 检查 35 平台短码注册表闭合 → PASS 行逐字在场（注册 5 行，平台短码 5 个）' "$(grep -m1 '^..: 35' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 36 fixture workflow 不标 production executable（工作流 2 件，fixture 2 件，production 0 件）' "$D/act.positive"; then
    ok '正例 P36 检查 36 fixture workflow 不标 production executable → PASS 行逐字在场（fixture 2 件）'
  else
    bad '正例 P36 检查 36 fixture workflow 不标 production executable → PASS 行逐字在场（fixture 2 件）' "$(grep -m1 '^..: 36' "$D/act.positive")"
  fi
  if grep -qxF 'PASS: 37 模型档位契约结构（宿主 5 个，模板 1 件，档位 3 个）' "$D/act.positive"; then
    ok '正例 P37 检查 37 模型档位契约结构 → PASS 行逐字在场（宿主 5 个，模板 1 件）'
  else
    bad '正例 P37 检查 37 模型档位契约结构 → PASS 行逐字在场（宿主 5 个，模板 1 件）' "$(grep -m1 '^..: 37' "$D/act.positive")"
  fi

  suite_summary 'check-package-groups'
}
