#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite stale-claims "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: stale-claims（票 72 场景沉淀：S1/S2 配置点亮正负例——未点亮 SKIP 不计数、
# 点亮按配置断言、delivery.rules 解析破坏 exit 2、汇总登记数动态化；票 85 增补：
# S5 方案结论标注句正负例四——向前生效经 git init 基线提交承载；票 94 增补：
# S6 终态哨兵正负例四——终态史经 git init 基线提交承载，done→in_progress／
# superseded→ready 非法跃迁即报、终态稳态与非终态流转零误报；票 194 增补：
# S4 扫描覆盖正负例九——扫描面声明实证（IN＝facts 树 md＋artifacts.yaml 单件／
# OUT＝排除面、非 md、facts 外 rules 树与仓根）、target-count 等值与漂移指名、
# omission/false-positive/false-negative 三防线逐行指名、词表语义分立（与检查 12
# 模糊措辞六词不互扫）与显式豁免三例（恰行免报／行号漂移照报／缺理由 exit 2，
# 豁免注入只改 eng 夹具副本 heredoc，被测对象本体零改动）
# ============================================================

sc_build_fixture() {
  # $1=夹具目录：仓库建于 <dir>/repo（eng 引擎目录由 suite 另行创建）；S1/S2 退化语义
  # 最小仓（非 Git 工作区→S1 WARN 退化；S3 退化＝夹具引擎目录只放被测脚本单件，
  # generator 不可用走内建最小比对，索引↔投影一致面可控；S4 锚点行 1↔index 条目 1
  # 相等）。S2 权威位置（根 README 宣称行）故意缺席——点亮断言经「登记的权威位置
  # 失效」STALE 行证明执行，免建完整发布面。（票 113 波④：夹具树翻 rules/facts 新形态
  # R13/R15/R14/R18——tickets 三载体、facts/project/archive 冻结件、research 扫描面目录。）
  R="$1/repo"
  rm -rf "$1"
  mkdir -p "$R/facts/requirements/tickets" "$R/facts/project/archive" "$R/facts/requirements/research"
  printf '# progress\n\nGit 恢复基线：占位锚点（S1 权威位置在位）\n' > "$R/facts/project/archive/progress.md"
  printf '{"id": "90-fixture", "status": "ready", "updated_at": "2026-09-22T00:00:00Z"}\n' > "$R/facts/requirements/tickets/index.json"
  printf '# projection\n\n| id | status | checkpoint_ref | updated_at |\n| --- | --- | --- | --- |\n| 90-fixture | ready | - | 2026-09-22T00:00:00Z |\n' > "$R/facts/requirements/tickets/progress-current.md"
  printf '# issues\n\n任务票 1；\n' > "$R/facts/requirements/tickets/README.md"
}

sc_run() {
  # $1=夹具仓根；经夹具引擎目录单件副本运行（触发 S3 退化路径，engine 同目录无生成器）
  sh "$1/eng/check-stale-claims.sh" "$1/repo" gate
}

sc_git_baseline() {
  # $1=夹具仓根：git init＋全量提交基线（承载 S5 向前生效语义——基线外才有新增/修改面；
  # 配置随 progress 套件先例内联 -c，不污染全局）
  git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm baseline
}

suite_stale_claims() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='stale-claims'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/scl
  mkdir -p "$D"
  SC="$SCRIPT_DIR/check-stale-claims.sh"

  # 正例 P1：未点亮（无 delivery.rules）→ S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 2
  sc_build_fixture "$D/p1"
  mkdir -p "$D/p1/eng"
  cp "$SC" "$D/p1/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p1/eng/dp-load-rules.sh"
  sc_run "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q 'SKIP: S1 — delivery.rules 未点亮（dp_stale_lit 缺登记）' "$D/p1.out" \
    && grep -q 'SKIP: S2 — delivery.rules 未点亮（dp_stale_lit 缺登记）' "$D/p1.out" \
    && grep -q '登记表 6 条全部核对' "$D/p1.out" \
    && ! grep -q '^STALE' "$D/p1.out"; then
    ok '正例 P1 未点亮 → S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 6（通用条数 S3/S4/S5/S6/S7/S8，票 134）'
  else
    bad '正例 P1 未点亮 → S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 6（通用条数 S3/S4/S5/S6/S7/S8，票 134）' "exit=$rc $(tail -n 2 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P2：点亮（dp_stale_lit S1＋S2，无 payload 节）→ 无 SKIP 行、S1/S2 断言逻辑执行
  # （S2 权威位置缺席 STALE、S1 退化 WARN）、汇总登记数 5（点亮数＋通用条数 S3/S4/S5，票 85）
  sc_build_fixture "$D/p2"
  mkdir -p "$D/p2/eng"
  cp "$SC" "$D/p2/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p2/eng/dp-load-rules.sh"
  cat > "$D/p2/repo/delivery.rules" <<'EOF'
# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====

dp_stale_lit S1
dp_stale_lit S2
EOF
  sc_run "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && ! grep -q '^SKIP: S1' "$D/p2.out" \
    && ! grep -q '^SKIP: S2' "$D/p2.out" \
    && grep -q '^STALE: README.md' "$D/p2.out" \
    && grep -q '登记表共 8 条' "$D/p2.out"; then
    ok '正例 P2 点亮 → S1/S2 断言逻辑执行（无 SKIP、STALE 行证明断言在跑）、汇总登记数 8（点亮数＋通用条数 S3/S4/S5/S6/S7/S8，票 134）'
  else
    bad '正例 P2 点亮 → S1/S2 断言逻辑执行（无 SKIP、STALE 行证明断言在跑）、汇总登记数 8（点亮数＋通用条数 S3/S4/S5/S6/S7/S8，票 134）' "exit=$rc $(tail -n 2 "$D/p2.out" | tr '\n' '|')"
  fi

  # 负例 N1：delivery.rules 解析破坏（未知指令）→ exit 2 fail-closed 指名
  sc_build_fixture "$D/n1"
  mkdir -p "$D/n1/eng"
  cp "$SC" "$D/n1/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n1/eng/dp-load-rules.sh"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_bogus x\n' > "$D/n1/repo/delivery.rules"
  sc_run "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'delivery.rules 解析破坏（fail-closed，不产生部分结论）' "$D/n1.out" && grep -q '未知指令行' "$D/n1.out"; then
    ok '负例 N1 delivery.rules 解析破坏 → exit 2 且指名违规行'
  else
    bad '负例 N1 delivery.rules 解析破坏 → exit 2 且指名违规行' "exit=$rc"
  fi

  # 正例 P3（票 85）：S5 新增面正例——基线提交后新增扫描面文档（未跟踪），结论行带
  # file: 出处＋轨:标注 → exit 0、零 STALE（登记表 3 条证明 S5 入表计数）
  sc_build_fixture "$D/p3"
  mkdir -p "$D/p3/eng" "$D/p3/repo/facts/requirements/research"
  cp "$SC" "$D/p3/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p3/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p3/repo"
  printf '# 调研夹具\n\n结论：采用方案 X（出处 file:facts/requirements/research/ref.md；轨:本仓自用）\n' > "$D/p3/repo/facts/requirements/research/2026-09-24-p3.md"
  sc_run "$D/p3" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q '^STALE' "$D/p3.out" \
    && grep -q '登记表 6 条全部核对' "$D/p3.out"; then
    ok '正例 P3 S5 新增面结论行标注齐（file:＋轨:）→ exit 0 零 STALE、登记表 6 条'
  else
    bad '正例 P3 S5 新增面结论行标注齐（file:＋轨:）→ exit 0 零 STALE、登记表 6 条' "exit=$rc $(tail -n 2 "$D/p3.out" | tr '\n' '|')"
  fi

  # 负例 N2（票 85）：S5 新增面负例——新增扫描面文档结论行缺标注（列表标记变体）
  # → exit 1 且 STALE 指名 文件:行号（AC2 口径）
  sc_build_fixture "$D/n2"
  mkdir -p "$D/n2/eng" "$D/n2/repo/facts/requirements/research"
  cp "$SC" "$D/n2/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n2/eng/dp-load-rules.sh"
  sc_git_baseline "$D/n2/repo"
  printf '# 调研夹具\n\n- 结论：采用方案 Y\n' > "$D/n2/repo/facts/requirements/research/2026-09-24-n2.md"
  sc_run "$D/n2" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^STALE: facts/requirements/research/2026-09-24-n2.md:3' "$D/n2.out" && grep -q '结论行缺标注（S5，票 85）' "$D/n2.out"; then
    ok '负例 N2 S5 新增面结论行缺标注 → exit 1 且 STALE 指名 facts/requirements/research/…:3'
  else
    bad '负例 N2 S5 新增面结论行缺标注 → exit 1 且 STALE 指名 facts/requirements/research/…:3' "exit=$rc $(tail -n 2 "$D/n2.out" | tr '\n' '|')"
  fi

  # 正例 P4（票 85）：S5 存量不回溯正例——无标注结论行已随基线提交、工作区清洁
  # → 新增/修改面为空，exit 0 零 STALE（向前生效口径：存量已提交文件不回溯）
  sc_build_fixture "$D/p4"
  mkdir -p "$D/p4/eng" "$D/p4/repo/facts/requirements/research"
  cp "$SC" "$D/p4/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p4/eng/dp-load-rules.sh"
  printf '# 调研夹具\n\n结论：存量行不标注（历史零改写）\n' > "$D/p4/repo/facts/requirements/research/2026-09-24-p4.md"
  sc_git_baseline "$D/p4/repo"
  sc_run "$D/p4" > "$D/p4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^STALE' "$D/p4.out"; then
    ok '正例 P4 S5 存量已提交不回溯 → exit 0 零 STALE（向前生效）'
  else
    bad '正例 P4 S5 存量已提交不回溯 → exit 0 零 STALE（向前生效）' "exit=$rc $(tail -n 2 "$D/p4.out" | tr '\n' '|')"
  fi

  # 负例 N3（票 85）：S5 修改面负例——基线提交标注齐的文档，工作区追加缺标注结论行
  # → exit 1 且 STALE 指名追加行 文件:行号（修改面在查）
  sc_build_fixture "$D/n3"
  mkdir -p "$D/n3/eng" "$D/n3/repo/facts/requirements/research"
  cp "$SC" "$D/n3/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n3/eng/dp-load-rules.sh"
  printf '# 调研夹具\n\n结论：基线行标注齐（出处 file:ref.md；轨:agent-up）\n' > "$D/n3/repo/facts/requirements/research/2026-09-24-n3.md"
  sc_git_baseline "$D/n3/repo"
  printf '\n结论：追加行未标注\n' >> "$D/n3/repo/facts/requirements/research/2026-09-24-n3.md"
  sc_run "$D/n3" > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^STALE: facts/requirements/research/2026-09-24-n3.md:5' "$D/n3.out" && ! grep -q '^STALE: facts/requirements/research/2026-09-24-n3.md:3' "$D/n3.out"; then
    ok '负例 N3 S5 修改面追加行缺标注 → exit 1 且 STALE 指名追加行 :5（基线行 ：3 不报）'
  else
    bad '负例 N3 S5 修改面追加行缺标注 → exit 1 且 STALE 指名追加行 :5（基线行 ：3 不报）' "exit=$rc $(tail -n 2 "$D/n3.out" | tr '\n' '|')"
  fi

  # S6 辅助：夹具三面自洽覆写（索引↔issues-README 锚点数↔投影行——S4 数量相等与
  # S3 最小比对同夹具内保持绿，S6 断言单变量隔离；终态史经 git log -p 基线锚承载）
  sc_s6_write() {
    # $1=夹具仓根 $2=91 状态 $3=91 updated_at $4=92 状态 $5=92 updated_at
    printf '{"id": "91-s6-done", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "%s"}\n{"id": "92-s6-superseded", "status": "%s", "complexity": "C0", "blocked_by": [], "updated_at": "%s"}\n' "$2" "$3" "$4" "$5" > "$1/facts/requirements/tickets/index.json"
    printf '# issues\n\n任务票 1；\n任务票 2；\n' > "$1/facts/requirements/tickets/README.md"
    printf '# projection\n\n| id | status | checkpoint_ref | updated_at |\n| --- | --- | --- | --- |\n| 91-s6-done | %s | - | %s |\n| 92-s6-superseded | %s | - | %s |\n' "$2" "$3" "$4" "$5" > "$1/facts/requirements/tickets/progress-current.md"
  }

  # 正例 P5（票 94）：S6 终态哨兵正例——终态索引（done/superseded 各一）随基线提交
  # 入终态史，工作区照旧（终态保持终态）→ exit 0、无 S6 STALE（合法稳态零误报）
  sc_build_fixture "$D/p5"
  mkdir -p "$D/p5/eng"
  cp "$SC" "$D/p5/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p5/eng/dp-load-rules.sh"
  sc_s6_write "$D/p5/repo" 'done' 2026-09-28T00:00:00Z superseded 2026-09-28T00:00:00Z
  sc_git_baseline "$D/p5/repo"
  sc_run "$D/p5" > "$D/p5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q '^STALE' "$D/p5.out" \
    && ! grep -q 'S6 终态哨兵' "$D/p5.out"; then
    ok '正例 P5 S6 终态索引照旧（done/superseded 保持终态）→ exit 0 零 STALE（合法稳态）'
  else
    bad '正例 P5 S6 终态索引照旧（done/superseded 保持终态）→ exit 0 零 STALE（合法稳态）' "exit=$rc $(tail -n 2 "$D/p5.out" | tr '\n' '|')"
  fi

  # 负例 N4（票 94）：S6 终态哨兵负例——基线提交的 done 票被改回 in_progress
  # （索引与投影同步改写，镜像道脚本单写语义；S6 断言单变量隔离）
  # → exit 1 且 S6 STALE 指名票 id 与跃迁方向（AC2 口径）
  sc_build_fixture "$D/n4"
  mkdir -p "$D/n4/eng"
  cp "$SC" "$D/n4/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n4/eng/dp-load-rules.sh"
  sc_s6_write "$D/n4/repo" 'done' 2026-09-28T00:00:00Z superseded 2026-09-28T00:00:00Z
  sc_git_baseline "$D/n4/repo"
  sc_s6_write "$D/n4/repo" in_progress 2026-09-28T01:00:00Z superseded 2026-09-28T00:00:00Z
  sc_run "$D/n4" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '^STALE: facts/requirements/tickets/index.json:91-s6-done' "$D/n4.out" \
    && grep -q 'S6 终态哨兵：' "$D/n4.out" \
    && grep -q '被改回非终态 in_progress' "$D/n4.out"; then
    ok '负例 N4 S6 done 票改回 in_progress → exit 1 STALE 指名票 id 与跃迁方向'
  else
    bad '负例 N4 S6 done 票改回 in_progress → exit 1 STALE 指名票 id 与跃迁方向' "exit=$rc $(tail -n 2 "$D/n4.out" | tr '\n' '|')"
  fi

  # 负例 N5（票 94）：S6 superseded 同款覆盖——基线提交的 superseded 票改回 ready
  # → exit 1 且 S6 STALE 指名票 id 与跃迁方向（AC3 口径）
  sc_build_fixture "$D/n5"
  mkdir -p "$D/n5/eng"
  cp "$SC" "$D/n5/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n5/eng/dp-load-rules.sh"
  sc_s6_write "$D/n5/repo" 'done' 2026-09-28T00:00:00Z superseded 2026-09-28T00:00:00Z
  sc_git_baseline "$D/n5/repo"
  sc_s6_write "$D/n5/repo" 'done' 2026-09-28T00:00:00Z ready 2026-09-28T01:00:00Z
  sc_run "$D/n5" > "$D/n5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '^STALE: facts/requirements/tickets/index.json:92-s6-superseded' "$D/n5.out" \
    && grep -q '被改回非终态 ready' "$D/n5.out"; then
    ok '负例 N5 S6 superseded 票改回 ready → exit 1 STALE 指名票 id 与跃迁方向'
  else
    bad '负例 N5 S6 superseded 票改回 ready → exit 1 STALE 指名票 id 与跃迁方向' "exit=$rc $(tail -n 2 "$D/n5.out" | tr '\n' '|')"
  fi

  # 正例 P6（票 94）：S6 非终态流转零误报——基线提交 ready 票，索引＋投影同步改
  # in_progress（ready→in_progress 合法流转，从未达终态）→ exit 0、无 S6 STALE
  sc_build_fixture "$D/p6"
  mkdir -p "$D/p6/eng"
  cp "$SC" "$D/p6/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p6/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p6/repo"
  printf '{"id": "90-fixture", "status": "in_progress", "updated_at": "2026-09-28T01:00:00Z"}\n' > "$D/p6/repo/facts/requirements/tickets/index.json"
  printf '# projection\n\n| id | status | checkpoint_ref | updated_at |\n| --- | --- | --- | --- |\n| 90-fixture | in_progress | - | 2026-09-28T01:00:00Z |\n' > "$D/p6/repo/facts/requirements/tickets/progress-current.md"
  sc_run "$D/p6" > "$D/p6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q '^STALE' "$D/p6.out" \
    && ! grep -q 'S6 终态哨兵' "$D/p6.out"; then
    ok '正例 P6 S6 非终态流转（ready→in_progress）→ exit 0 零误报'
  else
    bad '正例 P6 S6 非终态流转（ready→in_progress）→ exit 0 零误报' "exit=$rc $(tail -n 2 "$D/p6.out" | tr '\n' '|')"
  fi

  # S7 替代标记正负例四（票 127，R-DP-039 替代标记面配套）——索引单变量隔离：
  # P7 有效标记（superseded_by 指向索引内 done 票）→ exit 0 零 S7 输出；
  # N6 悬挂标记（指向票不在索引）→ exit 1 STALE 指名双方 id；
  # P8 缺字段（存量票零回扫语义）→ exit 0 零 S7 输出；
  # N7 非终态指向（替代票尚未收口）→ WARN 提醒不拦截（先标后收合法）。
  sc_s7_write() {
    # $1=夹具仓根 $2=91 status $3=91 superseded_by（空串=缺字段） $4=92 status
    # 同步覆写 README 锚点行（S4 数量相等：2 条目↔2 锚点）与投影行（S3 最小比对），
    # S7 断言单变量隔离。
    if [ -n "$3" ]; then
      printf '{"id": "91-s7", "status": "%s", "superseded_by": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-09T10:00"}\n{"id": "92-s7", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-09T11:00"}\n' "$2" "$3" "$4" > "$1/facts/requirements/tickets/index.json"
    else
      printf '{"id": "91-s7", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-09T10:00"}\n{"id": "92-s7", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "2026-10-09T11:00"}\n' "$2" "$4" > "$1/facts/requirements/tickets/index.json"
    fi
    printf '# issues\n\n任务票 1；\n任务票 2；\n' > "$1/facts/requirements/tickets/README.md"
    printf '# projection\n\n| id | status | checkpoint_ref | updated_at |\n| --- | --- | --- | --- |\n| 91-s7 | %s | - | 2026-10-09T10:00 |\n| 92-s7 | %s | - | 2026-10-09T11:00 |\n' "$2" "$4" > "$1/facts/requirements/tickets/progress-current.md"
  }

  # 正例 P7（票 127）：S7 有效标记——superseded 票指向索引内 done 票 → exit 0、无 S7 行
  sc_build_fixture "$D/p7"
  mkdir -p "$D/p7/eng"
  cp "$SC" "$D/p7/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p7/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p7/repo"
  sc_s7_write "$D/p7/repo" superseded 92-s7 'done'
  sc_run "$D/p7" > "$D/p7.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q 'S7 替代标记' "$D/p7.out" \
    && ! grep -q 'S7 收口顺序' "$D/p7.out"; then
    ok '正例 P7 S7 有效标记（superseded→done 在索引）→ exit 0 零 S7 输出'
  else
    bad '正例 P7 S7 有效标记（superseded→done 在索引）→ exit 0 零 S7 输出' "exit=$rc $(tail -n 2 "$D/p7.out" | tr '\n' '|')"
  fi

  # 负例 N6（票 127）：S7 悬挂标记——superseded_by 指向不在索引的票 → exit 1 且
  # STALE 指名双方 id（存在性硬断言）
  sc_build_fixture "$D/n6"
  mkdir -p "$D/n6/eng"
  cp "$SC" "$D/n6/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n6/eng/dp-load-rules.sh"
  sc_git_baseline "$D/n6/repo"
  sc_s7_write "$D/n6/repo" superseded 99-none 'done'
  sc_run "$D/n6" > "$D/n6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '^STALE: facts/requirements/tickets/index.json:91-s7' "$D/n6.out" \
    && grep -q 'S7 替代标记断言：票 91-s7 的 superseded_by 指向 99-none，但该票不在索引中' "$D/n6.out"; then
    ok '负例 N6 S7 悬挂标记 → exit 1 STALE 指名 91-s7 与 99-none'
  else
    bad '负例 N6 S7 悬挂标记 → exit 1 STALE 指名 91-s7 与 99-none' "exit=$rc $(tail -n 2 "$D/n6.out" | tr '\n' '|')"
  fi

  # 正例 P8（票 127）：S7 缺字段零回扫——索引无任何 superseded_by 字段（存量票形态）
  # → exit 0、无 S7 行（可选字段语义，缺字段零命中零报）
  sc_build_fixture "$D/p8"
  mkdir -p "$D/p8/eng"
  cp "$SC" "$D/p8/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p8/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p8/repo"
  sc_s7_write "$D/p8/repo" superseded '' 'done'
  sc_run "$D/p8" > "$D/p8.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q 'S7 替代标记' "$D/p8.out" \
    && ! grep -q 'S7 收口顺序' "$D/p8.out"; then
    ok '正例 P8 S7 缺字段零回扫（存量形态无标记）→ exit 0 零 S7 输出'
  else
    bad '正例 P8 S7 缺字段零回扫（存量形态无标记）→ exit 0 零 S7 输出' "exit=$rc $(tail -n 2 "$D/p8.out" | tr '\n' '|')"
  fi

  # 负例 N7（票 127）：S7 非终态指向——替代票尚未收口（in_progress）→ WARN 提醒
  # 不拦截（无 S7 STALE；先标后收合法顺序，对照 P7 终态指向零输出）
  sc_build_fixture "$D/n7"
  mkdir -p "$D/n7/eng"
  cp "$SC" "$D/n7/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n7/eng/dp-load-rules.sh"
  sc_git_baseline "$D/n7/repo"
  sc_s7_write "$D/n7/repo" superseded 92-s7 in_progress
  sc_run "$D/n7" > "$D/n7.out" 2>&1
  rc=$?
  if ! grep -q 'S7 替代标记' "$D/n7.out" \
    && grep -q 'S7 收口顺序提醒：票 91-s7 的 superseded_by 指向 92-s7，替代票尚未收口（状态 in_progress）' "$D/n7.out"; then
    ok '负例 N7 S7 非终态指向 → WARN 提醒先标后收、零 S7 STALE'
  else
    bad '负例 N7 S7 非终态指向 → WARN 提醒先标后收、零 S7 STALE' "exit=$rc $(tail -n 2 "$D/n7.out" | tr '\n' '|')"
  fi

  # S8 复盘沉淀指针正负例四（票 134，R-DP-041 检查面配套）——changes.jsonl 单变量隔离：
  # P9 指针在位（promoted_to=rules＋rules/x.md#锚点 文件与锚点均在）→ 零 S8 STALE；
  # N8 文件被删（指针指向 rules/gone.md）→ STALE 指名文件不存在；
  # N9 锚点丢失（锚点文本不在目标文件中）→ STALE 指名锚点不存在；
  # P10 none 行跳过（promoted_to=none）→ 零 S8 输出、NOTE 扫描面零命中。
  sc_s8_write() {
    # $1=夹具仓根 $2=decision（含指针） $3=promoted_to $4=建 rules/x.md（1=建含锚点/0=不建）
    mkdir -p "$1/facts/project" "$1/repo/../repo" 2>/dev/null
    mkdir -p "$1/rules"
    [ "$4" = "1" ] && printf '锚点文本在这里\n' > "$1/rules/x.md"
    printf '{"date": "2026-10-10", "kind": "lesson", "scope": "s8", "decision": "%s", "evidence_ref": "x", "promoted_to": "%s", "score_contract": 90, "score_predicate": 100, "score_rework": 0}\n' "$2" "$3" > "$1/facts/project/changes.jsonl"
    return 0
  }

  # 正例 P9（票 134）：S8 指针在位 → 无 S8 STALE
  sc_build_fixture "$D/p9"
  mkdir -p "$D/p9/eng"
  cp "$SC" "$D/p9/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p9/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p9/repo"
  sc_s8_write "$D/p9/repo" '沉淀到 rules/x.md#锚点文本在这里' rules 1
  sc_run "$D/p9" > "$D/p9.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q 'S8 复盘沉淀指针' "$D/p9.out"; then
    ok '正例 P9 S8 指针在位（文件＋锚点均在）→ exit 0 零 S8 STALE'
  else
    bad '正例 P9 S8 指针在位（文件＋锚点均在）→ exit 0 零 S8 STALE' "exit=$rc $(grep 'S8' "$D/p9.out" | head -1)"
  fi

  # 负例 N8（票 134）：S8 文件被删 → STALE 指名文件不存在
  sc_build_fixture "$D/n8b"
  mkdir -p "$D/n8b/eng"
  cp "$SC" "$D/n8b/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n8b/eng/dp-load-rules.sh"
  sc_git_baseline "$D/n8b/repo"
  sc_s8_write "$D/n8b/repo" '沉淀到 rules/gone.md' rules 0
  sc_run "$D/n8b" > "$D/n8b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'S8 复盘沉淀指针：lesson 行沉淀指针 rules/gone.md 指向的文件不存在' "$D/n8b.out"; then
    ok '负例 N8 S8 文件被删 → exit 1 STALE 指名 rules/gone.md 不存在'
  else
    bad '负例 N8 S8 文件被删 → STALE 指名 rules/gone.md 不存在' "exit=$rc $(grep 'S8' "$D/n8b.out" | head -1)"
  fi

  # 负例 N9（票 134）：S8 锚点丢失 → STALE 指名锚点不存在
  sc_build_fixture "$D/n9"
  mkdir -p "$D/n9/eng"
  cp "$SC" "$D/n9/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/n9/eng/dp-load-rules.sh"
  sc_git_baseline "$D/n9/repo"
  sc_s8_write "$D/n9/repo" '沉淀到 rules/x.md#锚点已不在' rules 1
  sc_run "$D/n9" > "$D/n9.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'S8 复盘沉淀指针：lesson 行沉淀指针 rules/x.md#锚点已不在 的锚点在目标文件中不存在' "$D/n9.out"; then
    ok '负例 N9 S8 锚点丢失 → exit 1 STALE 指名锚点不存在'
  else
    bad '负例 N9 S8 锚点丢失 → STALE 指名锚点不存在' "exit=$rc $(grep 'S8' "$D/n9.out" | head -1)"
  fi

  # 正例 P10（票 134）：S8 none 行跳过 → 零 S8 STALE、NOTE 扫描面零命中
  sc_build_fixture "$D/p10"
  mkdir -p "$D/p10/eng"
  cp "$SC" "$D/p10/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p10/eng/dp-load-rules.sh"
  sc_git_baseline "$D/p10/repo"
  sc_s8_write "$D/p10/repo" '教训无沉淀指针' none 0
  sc_run "$D/p10" > "$D/p10.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q 'S8 复盘沉淀指针' "$D/p10.out" && grep -q 'S8 扫描面零命中' "$D/p10.out"; then
    ok '正例 P10 S8 none 行跳过 → exit 0 零 S8 输出＋NOTE 零命中'
  else
    bad '正例 P10 S8 none 行跳过 → 零 S8 输出＋NOTE 零命中' "exit=$rc $(grep 'S8' "$D/p10.out" | head -1)"
  fi

  # 裸跑回归断言四（防回潮）：缺省根推导按落位形态（rules/implementation/scripts/
  # 上三级）——无参裸跑零 STALE 且与显式传参调用逐字节一致；包内落位/未知落位负例。
  # （夹具引擎目录单件语义：S3 走退化路径，索引↔投影一致面由 sc_s7_write 同款
  # 覆写控制；断言经夹具内 sh 直接调用，非 sc_run——sc_run 固定显式传参。）
  sc_bare_run() {
    # $1=夹具目录 $2=夹具引擎落位相对路径（相对 repo） $3=显式传参对照输出文件 $4=裸跑输出文件
    mkdir -p "$1/repo/rules/implementation/scripts"
    mkdir -p "$1/repo/$(dirname "$2")"
    cp "$SC" "$1/repo/$2"
    cp "$SCRIPT_DIR/dp-load-rules.sh" "$1/repo/$(dirname "$2")/dp-load-rules.sh"
    cp "$SC" "$1/repo/eng/check-stale-claims.sh"
    cp "$SCRIPT_DIR/dp-load-rules.sh" "$1/repo/eng/dp-load-rules.sh"
    ( cd "$1/repo" && sh "$2" ) > "$4" 2>&1
    _bare_rc=$?
    sh "$1/repo/eng/check-stale-claims.sh" "$1/repo" gate > "$3" 2>&1
    return $_bare_rc
  }

  # P11 rules/ 落位裸跑：exit 0 零 STALE，与显式传参输出逐字节一致
  sc_build_fixture "$D/p11"
  sc_git_baseline "$D/p11/repo"
  mkdir -p "$D/p11/repo/eng"
  sc_bare_run "$D/p11" rules/implementation/scripts/check-stale-claims.sh "$D/p11.explicit" "$D/p11.out"
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^STALE' "$D/p11.out" && cmp -s "$D/p11.out" "$D/p11.explicit"; then
    ok '正例 P11 rules/ 落位无参裸跑 → exit 0 零 STALE，与显式传参输出逐字节一致'
  else
    bad '正例 P11 rules/ 落位无参裸跑 → exit 0 零 STALE，与显式传参输出逐字节一致' "exit=$rc $(tail -n 2 "$D/p11.out" | tr '\n' '|')"
  fi

  # P12 包内落位裸跑：agent-up/scripts/ 上两级＝仓库根，exit 0 零 STALE
  sc_build_fixture "$D/p12"
  sc_git_baseline "$D/p12/repo"
  mkdir -p "$D/p12/repo/agent-up/scripts" "$D/p12/repo/eng"
  cp "$SC" "$D/p12/repo/agent-up/scripts/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p12/repo/agent-up/scripts/dp-load-rules.sh"
  cp "$SC" "$D/p12/repo/eng/check-stale-claims.sh"
  cp "$SCRIPT_DIR/dp-load-rules.sh" "$D/p12/repo/eng/dp-load-rules.sh"
  ( cd "$D/p12/repo" && sh agent-up/scripts/check-stale-claims.sh ) > "$D/p12.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^STALE' "$D/p12.out"; then
    ok '正例 P12 包内落位无参裸跑 → exit 0 零 STALE'
  else
    bad '正例 P12 包内落位无参裸跑 → exit 0 零 STALE' "exit=$rc $(tail -n 2 "$D/p12.out" | tr '\n' '|')"
  fi

  # N12 未知落位裸跑：fail-closed 报错退出 2（不静默错根）
  sc_build_fixture "$D/n12"
  sc_git_baseline "$D/n12/repo"
  mkdir -p "$D/n12/repo/eng" "$D/n12/repo/loose"
  cp "$SC" "$D/n12/repo/loose/check-stale-claims.sh"
  cp "$SC" "$D/n12/repo/eng/check-stale-claims.sh"
  ( cd "$D/n12/repo" && sh loose/check-stale-claims.sh ) > "$D/n12.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '无法从脚本落位推导仓库根' "$D/n12.out"; then
    ok '负例 N12 未知落位无参裸跑 → exit 2 fail-closed 指名推导失败'
  else
    bad '负例 N12 未知落位无参裸跑 → exit 2 fail-closed 指名推导失败' "exit=$rc $(tail -n 2 "$D/n12.out" | tr '\n' '|')"
  fi

  # ---- S4 扫描覆盖与词表正负例九（票 194）------------------------------------
  # 扫描面声明实证（以脚本数据节声明为准）：IN＝facts/ 树 *.md（排除面外）＋
  # facts/project/artifacts.yaml 单件；OUT＝prune 排除面（tickets/、runs/、
  # architecture/generated/）＋case 跳过面（archive/progress.md、archive/changes.md、
  # progress-current.md）＋非 md ＋facts 外（rules 树、仓根）。四类例各产生指名结果
  # （退出码＋报文指名 file:line，非出现性 grep）；豁免注入只改 eng 夹具副本
  # heredoc，被测对象本体零改动（真实豁免表维持空表交付）。
  sc_eng_setup() {
    # $1=夹具目录：eng 引擎目录＋被测件单件副本（含共享解析器，票 192 语境）
    mkdir -p "$1/eng"
    cp "$SC" "$1/eng/check-stale-claims.sh"
    cp "$SCRIPT_DIR/dp-load-rules.sh" "$1/eng/dp-load-rules.sh"
  }
  sc_s4_exempt_inject() {
    # $1=夹具目录 $2=注入豁免行（s4_exempt 路径 行号 理由 形态，空串不注入）；
    # 注入点＝副本 s4_load_exempts heredoc 闭标行前（恰整行匹配 S4_EXEMPT_DATA
    # 闭标行，开头 <<'S4_EXEMPT_DATA' 形态不等值不误中）。
    # shellcheck disable=SC2016  # awk 程序单引号防 shell 展开 $0（家族先例同款形态必需）
    awk -v ex="$2" '$0 == "S4_EXEMPT_DATA" { if (ex != "") print ex } { print }' \
      "$1/eng/check-stale-claims.sh" > "$1/eng/csc.injected" || return 2
    mv "$1/eng/csc.injected" "$1/eng/check-stale-claims.sh"
  }

  # S4-T1（target-count 正向）：计数陈述与实际相等（README 锚点 1↔index 条目 1）
  # → exit 0、零 S4 报文（等值零误报）
  sc_build_fixture "$D/s4t1"
  sc_eng_setup "$D/s4t1"
  sc_run "$D/s4t1" > "$D/s4t1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q '^STALE' "$D/s4t1.out" \
    && ! grep -q 'STALE-prone' "$D/s4t1.out" \
    && ! grep -q 'S4 数量相等' "$D/s4t1.out"; then
    ok 'S4-T1 计数陈述与实际相等（锚点 1↔条目 1）→ exit 0 零 S4 报文（target-count 正向）'
  else
    bad 'S4-T1 计数陈述与实际相等（锚点 1↔条目 1）→ exit 0 零 S4 报文（target-count 正向）' "exit=$rc $(tail -n 2 "$D/s4t1.out" | tr '\n' '|')"
  fi

  # S4-T2（target-count 反向）：计数陈述与实际漂移（锚点 2↔条目 1）→ exit 1 且
  # STALE 指名双侧计数（报文含两侧计数文本，非出现性 grep）
  sc_build_fixture "$D/s4t2"
  sc_eng_setup "$D/s4t2"
  printf '# issues\n\n任务票 1；\n任务票 2；\n' > "$D/s4t2/repo/facts/requirements/tickets/README.md"
  sc_run "$D/s4t2" > "$D/s4t2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -qF 'S4 数量相等断言失效：README「任务票 NN；」锚点行 2 行 vs facts/requirements/tickets/index.json 任务条目 1 条' "$D/s4t2.out"; then
    ok 'S4-T2 计数陈述与实际漂移（锚点 2↔条目 1）→ exit 1 STALE 指名双侧计数'
  else
    bad 'S4-T2 计数陈述与实际漂移（锚点 2↔条目 1）→ exit 1 STALE 指名双侧计数' "exit=$rc $(tail -n 2 "$D/s4t2.out" | tr '\n' '|')"
  fi

  # S4-OM1（omission 防线：应扫未扫即抓）：扫描面深层路径（排除面外嵌套目录）与
  # artifacts.yaml 单件各布命中 → exit 1 且逐行指名（声明为扫描面即必达）
  sc_build_fixture "$D/s4om1"
  sc_eng_setup "$D/s4om1"
  mkdir -p "$D/s4om1/repo/facts/project/notes/sub"
  printf '# 深层笔记\n\n范围行：2～3 共\n合计行：共 4 项\n' > "$D/s4om1/repo/facts/project/notes/sub/deep.md"
  printf 'kind: 事实登记\nmeta: 批次 6～9 共\n' > "$D/s4om1/repo/facts/project/artifacts.yaml"
  sc_run "$D/s4om1" > "$D/s4om1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -qF 'STALE-prone: facts/project/notes/sub/deep.md:3 —' "$D/s4om1.out" \
    && grep -qF 'STALE-prone: facts/project/notes/sub/deep.md:4 —' "$D/s4om1.out" \
    && grep -qF 'STALE-prone: facts/project/artifacts.yaml:2 —' "$D/s4om1.out"; then
    ok 'S4-OM1 扫描面深层路径与 artifacts.yaml 命中 → exit 1 逐行指名（omission 防线）'
  else
    bad 'S4-OM1 扫描面深层路径与 artifacts.yaml 命中 → exit 1 逐行指名（omission 防线）' "exit=$rc $(grep -c 'STALE-prone' "$D/s4om1.out")"
  fi

  # S4-FP1（false-positive 防线：不应报而报即抓）：与命中同文布进排除面 prune 三处
  # （票面 md/runs/生成投影）、case 跳过三处（冻结档案/账本冻结件/现役投影）、非 md、
  # facts 外（rules 树、仓根）→ exit 0、零 STALE-prone（扫描范围声明边界实证：
  # 规则树不在扫描面）
  sc_build_fixture "$D/s4fp1"
  sc_eng_setup "$D/s4fp1"
  printf '# 票面\n历史范围 2～3 共\n' > "$D/s4fp1/repo/facts/requirements/tickets/190-fp.md"
  mkdir -p "$D/s4fp1/repo/facts/requirements/runs" "$D/s4fp1/repo/facts/project/architecture/generated" "$D/s4fp1/repo/rules/implementation"
  printf 'run 记录：共 4 项\n' > "$D/s4fp1/repo/facts/requirements/runs/run-fp.md"
  printf '生成投影：3～5 共\n' > "$D/s4fp1/repo/facts/project/architecture/generated/gen-fp.md"
  printf '\n历史：3～5 共\n' >> "$D/s4fp1/repo/facts/project/archive/progress.md"
  printf '# 账本冻结件\n只追加：共 4 项\n' > "$D/s4fp1/repo/facts/project/archive/changes.md"
  printf '\n批次 2～3 共\n' >> "$D/s4fp1/repo/facts/requirements/tickets/progress-current.md"
  printf '共 4 项\n' > "$D/s4fp1/repo/facts/fp.txt"
  printf '规则树笔记：2～3 共\n' > "$D/s4fp1/repo/rules/implementation/notes.md"
  printf '根目录笔记：共 4 项\n' > "$D/s4fp1/repo/FP-ROOT.md"
  sc_run "$D/s4fp1" > "$D/s4fp1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && ! grep -q 'STALE-prone' "$D/s4fp1.out" \
    && ! grep -q '^STALE' "$D/s4fp1.out"; then
    ok 'S4-FP1 排除面 prune/case 跳过、非 md、facts 外（rules 树/仓根）同文零报（false-positive 防线＋扫描范围声明）'
  else
    bad 'S4-FP1 排除面 prune/case 跳过、非 md、facts 外（rules 树/仓根）同文零报（false-positive 防线＋扫描范围声明）' "exit=$rc $(grep 'STALE-prone' "$D/s4fp1.out" | head -3 | tr '\n' '|')"
  fi

  # S4-FN1（false-negative 防线：应报未报即抓）：词表甲乙两臂＋乙臂五量词全变体
  # 布进扫描面 → exit 1 且六行逐一指名（任一臂/量词交替失效即抓）
  sc_build_fixture "$D/s4fn1"
  sc_eng_setup "$D/s4fn1"
  printf '甲臂：2～3 共\n乙张：共 12 张\n乙条：共 12 条\n乙项：共 12 项\n乙件：共 12 件\n乙个：共 12 个\n' > "$D/s4fn1/repo/facts/requirements/research/2026-10-21-fn.md"
  sc_run "$D/s4fn1" > "$D/s4fn1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:1 —' "$D/s4fn1.out" \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:2 —' "$D/s4fn1.out" \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:3 —' "$D/s4fn1.out" \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:4 —' "$D/s4fn1.out" \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:5 —' "$D/s4fn1.out" \
    && grep -qF 'STALE-prone: facts/requirements/research/2026-10-21-fn.md:6 —' "$D/s4fn1.out"; then
    ok 'S4-FN1 词表甲乙两臂＋五量词六行 → exit 1 逐一指名（false-negative 防线）'
  else
    bad 'S4-FN1 词表甲乙两臂＋五量词六行 → exit 1 逐一指名（false-negative 防线）' "exit=$rc $(grep -c 'STALE-prone' "$D/s4fn1.out")"
  fi

  # S4-V1（词表语义分立，AC2）：与检查 12 模糊措辞词表（尽量/适当/必要时/通常/
  # 原则上/酌情六词）非等价——纯措辞文件入 S4 扫描面零报（正例）；措辞与计数同文
  # 异行分立，仅计数行指名（负例：词表外措辞行不因邻行命中而连坐）
  sc_build_fixture "$D/s4v1"
  sc_eng_setup "$D/s4v1"
  mkdir -p "$D/s4v1/repo/facts/project/notes"
  printf '措辞面：尽量适当，必要时通常；原则上酌情处理。\n' > "$D/s4v1/repo/facts/project/notes/vocab.md"
  printf '措辞行：必要时酌情\n计数行：共 4 项\n' > "$D/s4v1/repo/facts/project/notes/mixed.md"
  sc_run "$D/s4v1" > "$D/s4v1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -qF 'STALE-prone: facts/project/notes/mixed.md:2 —' "$D/s4v1.out" \
    && ! grep -qF 'STALE-prone: facts/project/notes/vocab.md' "$D/s4v1.out" \
    && ! grep -qF 'STALE-prone: facts/project/notes/mixed.md:1 —' "$D/s4v1.out"; then
    ok 'S4-V1 检查 12 模糊措辞六词入扫描面零报、仅计数行指名（词表语义分立非等价不互扫）'
  else
    bad 'S4-V1 检查 12 模糊措辞六词入扫描面零报、仅计数行指名（词表语义分立非等价不互扫）' "exit=$rc $(grep 'STALE-prone' "$D/s4v1.out" | tr '\n' '|')"
  fi

  # S4-X1（显式豁免正例）：副本注入豁免行（路径＋行号＋理由）恰行免报 ：3，
  # 非豁免命中照报指名（豁免不扩大面）
  sc_build_fixture "$D/s4x1"
  sc_eng_setup "$D/s4x1"
  sc_s4_exempt_inject "$D/s4x1" 's4_exempt facts/exempt-fix.md 3 审计正当例外：样例行（理由必填显式登记）'
  printf '第一行\n第二行\n命中行：共 6 项\n' > "$D/s4x1/repo/facts/exempt-fix.md"
  printf '他行命中：4～6 共\n' > "$D/s4x1/repo/facts/other-fix.md"
  sc_run "$D/s4x1" > "$D/s4x1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && ! grep -qF 'STALE-prone: facts/exempt-fix.md:3 —' "$D/s4x1.out" \
    && grep -qF 'STALE-prone: facts/other-fix.md:1 —' "$D/s4x1.out"; then
    ok 'S4-X1 显式豁免（路径＋行号＋理由）恰行免报 exempt-fix.md:3、非豁免命中照报 other-fix.md:1'
  else
    bad 'S4-X1 显式豁免（路径＋行号＋理由）恰行免报 exempt-fix.md:3、非豁免命中照报 other-fix.md:1' "exit=$rc $(grep 'STALE-prone' "$D/s4x1.out" | tr '\n' '|')"
  fi

  # S4-X2（豁免负例：行号漂移）：登记行号 ：3 而实际命中 ：4 → 恰整行匹配不罩他行，
  # 照报指名 ：4（豁免机械可验证，漂移静默免报即抓）
  sc_build_fixture "$D/s4x2"
  sc_eng_setup "$D/s4x2"
  sc_s4_exempt_inject "$D/s4x2" 's4_exempt facts/exempt-fix.md 3 审计正当例外：登记行号 3'
  printf '第一行\n第二行\n第三行\n命中行：共 6 项\n' > "$D/s4x2/repo/facts/exempt-fix.md"
  sc_run "$D/s4x2" > "$D/s4x2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -qF 'STALE-prone: facts/exempt-fix.md:4 —' "$D/s4x2.out"; then
    ok 'S4-X2 豁免行号漂移（登记 :3 实际命中 :4）→ exit 1 恰整行匹配不罩他行照报指名 :4'
  else
    bad 'S4-X2 豁免行号漂移（登记 :3 实际命中 :4）→ exit 1 恰整行匹配不罩他行照报指名 :4' "exit=$rc $(grep 'STALE-prone' "$D/s4x2.out" | tr '\n' '|')"
  fi

  # S4-X3（豁免负例：结构破坏）：豁免行缺理由（理由必填无静默豁免）→ exit 2
  # fail-closed 指名，不产生部分结论
  sc_build_fixture "$D/s4x3"
  sc_eng_setup "$D/s4x3"
  sc_s4_exempt_inject "$D/s4x3" 's4_exempt facts/exempt-fix.md 3'
  sc_run "$D/s4x3" > "$D/s4x3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] \
    && grep -qF 'S4 豁免表理由必填（无静默豁免）' "$D/s4x3.out"; then
    ok 'S4-X3 豁免表结构破坏（缺理由）→ exit 2 fail-closed 指名（豁免显式无静默）'
  else
    bad 'S4-X3 豁免表结构破坏（缺理由）→ exit 2 fail-closed 指名（豁免显式无静默）' "exit=$rc $(tail -n 2 "$D/s4x3.out" | tr '\n' '|')"
  fi

  suite_summary 'stale-claims'
}
