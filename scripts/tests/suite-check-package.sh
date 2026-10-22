#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite check-package "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: check-package（票 12/48 场景沉淀：八项正例＋必需件缺失负例；票 56 检查 8 清单
# 8→10 件，预期串同步 10 件口径；票 57 数据化改造＋新增检查 9/10/11，预期串同步
# 十一项口径；协调层改判随票修：检查 11 逐处全等，补 §2.5 单处删值负例；票 58 检查
# 11→13，预期串同步十三项口径——正例含检查 12/13 PASS 行（比对 4 对＝仓根镜像在位
# 语境），补检查 12 注入/豁免/失效豁免与检查 13 镜像篡改/静默跳过负例；票 59 检查
# 13→14，预期串同步十四项口径——正例含检查 14 PASS 行，补检查 14 注入未登记基元/
# 删一基元负例；票 60 检查 14→17，检查 8 清单 10→12 件，预期串同步十七项口径——
# 正例含检查 15/16/17 PASS 行，补索引删行/加全集外 ID/未登记机制值/机械行点名不存在
# 脚本/检查项号超界/外定义行删标记词负例＋mechanism-vocab 词表损坏 exit 2 负例；
# 票 95 检查 18→19，预期串同步十九项口径——正例含检查 19 PASS 行（真包根 git 语境），
# 负例夹具为非 git 语境检查 19 静默跳过无输出行，补 mode 断言负例一对（git 夹具语境：
# kind=script .sh 置 644／kind=rules 规则表置 755，双断言同报）；票 101 删 R-DP-030 规则
# 块与 §15.3 节，预期串检查 15 行 52→51 独立重建（三处）；票 102 合并 R-DP-025 入
# R-DP-007（索引行删一＋R-DP-007 行改写），预期串检查 15 行 51→50 独立重建（三处）；
# 票 103 镜像清单 4→6 对，正例预期串与负例 N7 夹具同步；票 113 波④包翻值后金样串独立
# 重建：检查 5 计数 13→15（三模板拆分入册；票 141 后 16→15 requests 退役）、检查 15 三件索引并集 50 行、检查 7 治理面
# 扩五项（AGENTS.md/docs//rules//facts//.zcode/）；负例 N12/N13/N14/N15/N16/N17 注入目标
# 改新三件索引宿主（assessment/discipline/project.md.tmpl）逐负例独立重推）；
# delivery-rules.tmpl 模板入册后检查 5 计数 15→16（预期串三处独立重建，2026-10-09 用户；票 141 requests 模板退役 16→15）
# 六条包改进拍板 issue 2 落地）；票 118 增 R-DP-038 后检查 15 索引 52→53（预期串三处独立重建，同批 issue 3/4 落地）；票 121 upgrade-check.sh 入册后检查 8 清单 16→17 与检查 19 mode 16→17（预期串独立重建，升级审计拍板落地）；票 123 检查 13 增新布局镜像探测（源仓倒挂拦截）后真包根语境产出 6 对比对行，金样串补该行（预期独立重建）；票 149 检查 19→20 增包闭合性与符号链接防护（scripts 一级闭合＋symlink 防外指＋登记面别名禁令；预期串计数 19→20 翻值、正例补检查 20 PASS 行、N16 注入项号检查 20→21；补负例 N24 未登记额外件/N25 symlink 混合面/N26 非 git 语境检查 20 照常运行）；票 190 检查 13 改跨树同名脚本所有权三分类（pm_mirror 两参数 mirror/package-only/repo-only：mirror 类 11 对逐对 cmp＋仓侧缺同名件报登记悬空；package-only 类 4 件不 cmp——仓侧同名实例属待升级流程同步过渡态不判差异；repo-only 类 4 件断言包内侧缺席；源仓语境门控＝包根父目录两落位目录任一在场，消费项目整项静默跳过）＋新增检查 21 references 树成员闭合与导航（全树文件 ⊆ entry-files∪templates、references/README.md 目录清单一级投影双向、包内 *.md 行内链接目标存在；预期串计数 20→21 翻值、检查 1 计数 18→35、检查 13 比对 9→11 对、正例补检查 21 PASS 行两形态；补负例 N28 references 子树未登记新件/N29 已登记成员删除缺件/N30 坏相对链接/N31 一级目录未入 README 投影/N32 mirror 登记悬空/N33 repo-only 件投放包内＋正例 P1 package-only 过渡态临时夹具（全 mktemp 源仓语境）；N16 注入项号检查 21→22 随总数同步）；票 192 解析器单源化随票修（新增 pm_script dp-load-rules.sh 与 pm_entry references/delivery-rules.md → 检查 1 计数 35→36、检查 8/19 计数 27→28、检查 20 一级 30→31；pm_mirror 两消费件 mirror 翻 package-only（仓侧旧版内嵌解析器副本为待升级流程收敛过渡态）→ 检查 13 比对 11→9 对、三分类夹具组清单随动；检查 21 成员 47→48）；票 193 账本行合同随票修（新增 pm_entry references/schemas/ledger-row.schema.json → 检查 1 计数 36→37、检查 21 成员 48→49）；票 195 规则块格式校验＋索引序言收敛随票修（新增检查 22 规则块九字段格式——Level 受控四值收尾/七字段齐备/块 ID 全局唯一，全量扫描含「解释与例外」节，负例缺字段/非法 Level/重复 ID 各指名字段或 ID；新增检查 23 索引节序言短指针——三宿主 §16 序言逐字等于 governance-format.md R-GF-011 定稿原句，「」窄锚点提取零句子硬编码，三模板 §16 长序言收敛为短指针；预期串计数 21→23 翻值、正例补检查 22/23 PASS 行两形态、N16 注入项号检查 22→24 随总数同步；补负例 N34 缺字段/N35 非法 Level/N36 重复 ID/N37 序言多行散文/N38 第二权威/N39 缺指针＋正例 P2 三宿主序言逐字断言；返工轮补负例 N40 权威文件缺失（检查 23 缺权威分支 n_hosts 未初始化——set -u 崩溃且 EXIT trap 吞状态 exit 0 假绿的回归钉死：断言 exit 1＋FAIL: 23 指名＋汇总行出现＋零 unbound variable，n_hosts 提前至分支外统一初始化）；票 196 Triage 模板入册随票修（新增 pm_template agents-triage.md.tmpl＋pm_shortcode RT 与 discipline.md.tmpl §16 R-RT-001～002 索引行 → 金样串四计数独立重建：检查 5 计数 15→16、检查 15 索引/全集 54→56、检查 21 成员 49→50、检查 22 块 93→95，四个金样块×两形态同步）
# ============================================================

suite_check_package() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='check-package'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/cpkg
  # 仓侧镜像落位目录（检查 13 所有权夹具组用；消费项目语境不存在 → 对应组显式 SKIP）
  REPO_SIDE="$PKG_ROOT/../rules/implementation/scripts"
  mkdir -p "$D"

  # 栅栏环境跳过（R-DP-036：worktree 内 main-only 件 install.sh/export-payload.sh 物理不在场，
  # 正例活树与 cp -R 夹具副本均缺件，金样串为完整包语境独立重建，无法在栅栏环境逐一相等；
  # 口径同 check-package 自身检查 8/9 的 worktree SKIP）：整套显式 SKIP 不计数，覆盖归主检出全量；
  # 检查器本体仍由 pre-commit 门禁 2 在真实树上以 worktree 模式执行。
  if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    printf 'SKIP  [check-package] main-only 件不在场（worktree 栅栏）——检查器自检套件整套跳过，覆盖归主检出；门禁 2 仍跑真实树\n'
    suite_summary 'check-package'
    return 0
  fi

  # 票 177 worktree 变体：check-package 在 worktree 包根对 main-only 检查（8/9）输出
  # SKIP＋变体 PASS 行；黄金串按 PKG_ROOT 同款 worktree 判定条件化（检测逻辑与
  # check-package is_worktree 一致），否则 harness 在 worktree 内对此断言恒红。
  _cp_in_wt=0
  if git -C "$PKG_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    _cp_gd=$(git -C "$PKG_ROOT" rev-parse --git-dir 2>/dev/null)
    _cp_cd=$(git -C "$PKG_ROOT" rev-parse --git-common-dir 2>/dev/null)
    case $_cp_gd in /*) : ;; *) _cp_gd="$PKG_ROOT/$_cp_gd" ;; esac
    case $_cp_cd in /*) : ;; *) _cp_cd="$PKG_ROOT/$_cp_cd" ;; esac
    _cp_gd=$(cd "$_cp_gd" && pwd)
    _cp_cd=$(cd "$_cp_cd" && pwd)
    [ "$_cp_gd" != "$_cp_cd" ] && _cp_in_wt=1
  fi
  if [ "$_cp_in_wt" -eq 1 ]; then
  cat > "$D/exp.positive" <<'EOF'
PASS: 1 必需入口存在（37 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 16 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
SKIP: 8 脚本必需件存在（worktree 环境，跳过 main-only 脚本检查）
PASS: 8 脚本必需件存在（28 个文件，worktree 跳过 main-only）
SKIP: 9 scripts/README.md 成员表与数据 scripts 节一致（worktree 环境，跳过 main-only 成员检查）
PASS: 9 scripts/README.md 成员表与数据 scripts 节一致（worktree 跳过 main-only）
PASS: 10 规则块短码使用均在登记内
PASS: 11 platform 枚举登记与数据一致
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 13 镜像脚本与仓根同名件一致（比对 9 对）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（三件索引并集 56 行，全集 56 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
PASS: 17 机械行点名出处存在（机械 9 行）
PASS: 18 包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 0 行）
PASS: 19 scripts 节 mode 断言（28 件，kind 数据驱动）
PASS: 20 包闭合性与符号链接防护（scripts 一级 31 项，symlink 0 个）
PASS: 21 references 树成员闭合与导航（成员 50 件，链接 2 个）
PASS: 22 规则块九字段格式（块 95 个，字段 7 项，级 4 值）
PASS: 23 索引节序言短指针（宿主 3 件，权威定稿原句逐字核对）
check-package: PASS
EOF
  else
  cat > "$D/exp.positive" <<'EOF'
PASS: 1 必需入口存在（37 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 16 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
PASS: 8 脚本必需件存在（28 个文件）
PASS: 9 scripts/README.md 成员表与数据 scripts 节一致
PASS: 10 规则块短码使用均在登记内
PASS: 11 platform 枚举登记与数据一致
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 13 镜像脚本与仓根同名件一致（比对 9 对）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（三件索引并集 56 行，全集 56 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
PASS: 17 机械行点名出处存在（机械 9 行）
PASS: 18 包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 0 行）
PASS: 19 scripts 节 mode 断言（28 件，kind 数据驱动）
PASS: 20 包闭合性与符号链接防护（scripts 一级 31 项，symlink 0 个）
PASS: 21 references 树成员闭合与导航（成员 50 件，链接 2 个）
PASS: 22 规则块九字段格式（块 95 个，字段 7 项，级 4 值）
PASS: 23 索引节序言短指针（宿主 3 件，权威定稿原句逐字核对）
check-package: PASS
EOF
  fi
  sh "$SCRIPT_DIR/check-package.sh" "$PKG_ROOT" >"$D/act.positive" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "正例 exit 0（包根＝${PKG_ROOT}）"
  else
    bad "正例 exit 0（包根＝${PKG_ROOT}）" "exit=$rc"
  fi
  assert_eq '正例输出逐行逐一相等（二十三项 PASS＋汇总，含检查 9/10/11、12/13 所有权三分类、14、15/16/17、18 票号禁令、19 mode 断言、20 闭合性、21 references 闭合导航、22 规则块九字段与 23 序言短指针）' "$D/act.positive" "$D/exp.positive"

  cp -R "$PKG_ROOT" "$D/pkgcopy"
  rm -f "$D/pkgcopy/scripts/generate-progress.sh"
  cat > "$D/exp.negative" <<'EOF'
PASS: 1 必需入口存在（37 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 16 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
FAIL: 8 脚本必需件存在（28 个文件） —   - scripts/generate-progress.sh
FAIL: 9 scripts/README.md 成员表与数据 scripts 节一致 —   - 成员表登记但无实际文件：generate-progress.sh
PASS: 10 规则块短码使用均在登记内
PASS: 11 platform 枚举登记与数据一致
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（三件索引并集 56 行，全集 56 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
FAIL: 17 机械行点名出处存在（机械 9 行） —   - R-DP-004 机械行点名脚本不存在: generate-progress.sh
PASS: 18 包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 0 行）
PASS: 20 包闭合性与符号链接防护（scripts 一级 30 项，symlink 0 个）
PASS: 21 references 树成员闭合与导航（成员 50 件，链接 2 个）
PASS: 22 规则块九字段格式（块 95 个，字段 7 项，级 4 值）
PASS: 23 索引节序言短指针（宿主 3 件，权威定稿原句逐字核对）
check-package: FAIL（3 项未通过，共 23 项）
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy" >"$D/act.negative" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok '负例 exit 1（副本删必需件，mktemp 副本纪律）'
  else
    bad '负例 exit 1（副本删必需件，mktemp 副本纪律）' "exit=$rc"
  fi
  assert_eq '负例输出逐一相等（fail-closed 指名缺失件＋检查 9 表实漂移联动＋检查 17 机械行点名脚本缺失联动＋检查 18 同步，不因部分存在放宽）' "$D/act.negative" "$D/exp.negative"

  # 票 57 协调层改判随票修：检查 11 逐处全等——§2.5 单处删 pi（frontmatter 完整）
  # 必须单独 FAIL 指名 :119（旧并集口径此场景漏检，回归钉死）。
  cp -R "$PKG_ROOT" "$D/pkgcopy2"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's=`pi` / `dsh`（与=`dsh`（与=' "$D/pkgcopy2/references/adapters/capability-contract.md" >"$D/cc.tmp" && mv "$D/cc.tmp" "$D/pkgcopy2/references/adapters/capability-contract.md"
  cat > "$D/exp.cc" <<'EOF'
PASS: 1 必需入口存在（37 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 16 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
PASS: 8 脚本必需件存在（28 个文件）
PASS: 9 scripts/README.md 成员表与数据 scripts 节一致
PASS: 10 规则块短码使用均在登记内
FAIL: 11 platform 枚举登记与数据一致 —   - capability-contract.md :119 登记与数据不一致：缺少 pi
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（三件索引并集 56 行，全集 56 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
PASS: 17 机械行点名出处存在（机械 9 行）
PASS: 18 包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 0 行）
PASS: 20 包闭合性与符号链接防护（scripts 一级 31 项，symlink 0 个）
PASS: 21 references 树成员闭合与导航（成员 50 件，链接 2 个）
PASS: 22 规则块九字段格式（块 95 个，字段 7 项，级 4 值）
PASS: 23 索引节序言短指针（宿主 3 件，权威定稿原句逐字核对）
check-package: FAIL（1 项未通过，共 23 项）
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy2" >"$D/act.cc" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    ok '负例 exit 1（capability-contract §2.5 单处删 pi，frontmatter 完整）'
  else
    bad '负例 exit 1（capability-contract §2.5 单处删 pi，frontmatter 完整）' "exit=$rc"
  fi
  assert_eq '负例输出逐一相等（检查 11 逐处全等，FAIL 行按行号指名 :119 缺少 pi）' "$D/act.cc" "$D/exp.cc"

  # 票 58 检查 12 负例 N4：词表首词（自夹具包 manifest 词表节提取，harness 零词面字面量）
  # 注入 governance-format.md 首个规则块 Authority 字段之后 → FAIL: 12 指名文件:行号；
  # 注入行同时使既有豁免行号漂移（未豁免命中与失效豁免同报），行级豁免漂移即 FAIL 的
  # fail-closed 行为随之钉死。
  cp -R "$PKG_ROOT" "$D/pkgcopy3"
  w=$(LC_ALL=C awk -F"'" '/^pm_vague_word/{print $2; exit}' "$D/pkgcopy3/scripts/package-manifest.rules")
  gf="$D/pkgcopy3/references/protocol/governance-format.md"
  ln=$(grep -n '^\- \*\*Authority\*\*' "$gf" | head -1 | cut -d: -f1)
  { head -n "$ln" "$gf"; printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; tail -n +"$((ln + 1))" "$gf"; } > "$D/gf.tmp"
  mv "$D/gf.tmp" "$gf"
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy3" >"$D/act.n4" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 12 规则块体无模糊措辞' "$D/act.n4" && grep -q "governance-format.md:$((ln + 1)) 命中模糊措辞" "$D/act.n4"; then
    ok '负例 N4 注入词表首词入规则块体 → exit 1 且 FAIL: 12 指名文件:行号'
  else
    bad '负例 N4 注入词表首词入规则块体 → exit 1 且 FAIL: 12 指名文件:行号' "exit=$rc"
  fi

  # 票 58 检查 12 正例 N5：同一注入落在 read-policy.md（无既有豁免引用文件，豁免行号
  # 零漂移）并在夹具包 manifest 登记行级豁免 → 该行不报，exit 0（豁免生效）。
  cp -R "$PKG_ROOT" "$D/pkgcopy4"
  rp="$D/pkgcopy4/references/protocol/read-policy.md"
  rln=$(grep -n '^\- \*\*Authority\*\*' "$rp" | head -1 | cut -d: -f1)
  { head -n "$rln" "$rp"; printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; tail -n +"$((rln + 1))" "$rp"; } > "$D/rp.tmp"
  mv "$D/rp.tmp" "$rp"
  printf "pm_vague_exempt references/protocol/read-policy.md %d 'harness fixture 豁免正例（登记后该行不报）'\n" "$((rln + 1))" >> "$D/pkgcopy4/scripts/package-manifest.rules"
  # 豁免登记改动须被引擎读到：check-package 加载与自身同目录的 manifest（票 57 口径），
  # 故本组负例以夹具包自带的引擎副本运行（引擎与原物同码，cp 纪律）。
  sh "$D/pkgcopy4/scripts/check-package.sh" "$D/pkgcopy4" >"$D/act.n5" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 12 规则块体无模糊措辞' "$D/act.n5"; then
    ok '正例 N5 注入行登记行级豁免后不报 → exit 0（豁免生效）'
  else
    bad '正例 N5 注入行登记行级豁免后不报 → exit 0（豁免生效）' "exit=$rc"
  fi

  # 票 58 检查 12 负例 N6：豁免登记行无命中（999 行）→ 失效豁免 FAIL（防漂移静默失效）。
  cp -R "$PKG_ROOT" "$D/pkgcopy5"
  printf "pm_vague_exempt references/protocol/governance-format.md 999 'harness fixture 失效豁免负例'\n" >> "$D/pkgcopy5/scripts/package-manifest.rules"
  sh "$D/pkgcopy5/scripts/check-package.sh" "$D/pkgcopy5" >"$D/act.n6" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '失效豁免（登记行无词表命中，须复核更新或删除登记）: references/protocol/governance-format.md:999' "$D/act.n6"; then
    ok '负例 N6 豁免登记行无命中 → exit 1 且 FAIL: 12 报失效豁免'
  else
    bad '负例 N6 豁免登记行无命中 → exit 1 且 FAIL: 12 报失效豁免' "exit=$rc"
  fi

  # 票 58 检查 13 负例 N7：仓根 scripts/ 同名件单处篡改 → FAIL: 13 指名文件。
  # 票 190：夹具仓根复制清单 mirror 类全十一对件（仅复制部分会令检查 13 对缺件报
  # 镜像登记悬空、噪声淹没篡改信号——十一件全在位才只报篡改单点）＋仓侧四件 repo-only
  # 落位（消费项目语境无仓侧目录时 repo-only 行报登记悬空，不影响本负例指名断言）。
  mkdir -p "$D/mrepo/scripts" "$D/mrepo/rules/implementation/scripts"
  cp -R "$PKG_ROOT" "$D/mrepo/agent-up"
  for m in generate-progress.sh ticket-ops.sh absorption-trigger.sh health-summary.sh run-record.sh ticket-grade.sh lane-commit.sh check-gates.sh upgrade-check.sh; do
    cp "$PKG_ROOT/scripts/$m" "$D/mrepo/scripts/$m"
  done
  if [ -d "$REPO_SIDE" ]; then
    for m in merge-ticket.sh check-derived-freshness.sh check-payload-boundary.sh check-role-permissions.sh; do
      cp "$REPO_SIDE/$m" "$D/mrepo/rules/implementation/scripts/$m"
    done
  fi
  printf '# harness fixture 镜像篡改\n' >> "$D/mrepo/scripts/ticket-ops.sh"
  sh "$SCRIPT_DIR/check-package.sh" "$D/mrepo/agent-up" >"$D/act.n7" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 13 镜像脚本与仓根同名件一致' "$D/act.n7" && grep -q 'scripts/ticket-ops.sh 与仓根 scripts/ticket-ops.sh 不一致' "$D/act.n7"; then
    ok '负例 N7 仓根镜像同名件篡改 → exit 1 且 FAIL: 13 指名文件'
  else
    bad '负例 N7 仓根镜像同名件篡改 → exit 1 且 FAIL: 13 指名文件' "exit=$rc"
  fi

  # 票 58 检查 13 负例 N8：仓根无 scripts/（pkgcopy 语境）→ 检查 13 静默跳过无输出行
  # （消费项目语义，--pkg-root 参数化语境同样跳过）。
  if grep -q ': 13 ' "$D/act.negative"; then
    bad '负例 N8 仓根无 scripts/ 时检查 13 静默跳过（无输出行）' '意外出现检查 13 输出行'
  else
    ok '负例 N8 仓根无 scripts/ 时检查 13 静默跳过（无输出行）'
  fi

  # 协调层 Review 改判随票修（尾锚）：负例 N9——governance-format.md 在 R-GF-010
  # Authority 行后填充占位行，使注入命中恰落 :820，并在夹具 manifest 登记行号 8200
  # 的豁免（820 的字符串超集）：尾锚缺失时 "path\t820" 误配 "path\t8200\t..." 豁免行、
  # 命中被罩（旧缺陷方向）；尾锚生效 = :820 命中必须报出（exit 1 且 FAIL: 12 指名
  # :820）。既有 :82 豁免同文件在位，一并验证不误罩 :820 命中。
  cp -R "$PKG_ROOT" "$D/pkgcopy6"
  gf6="$D/pkgcopy6/references/protocol/governance-format.md"
  aln=$(grep -n '^\- \*\*Authority\*\*' "$gf6" | tail -1 | cut -d: -f1)
  pad=$((820 - aln - 1))
  { head -n "$aln" "$gf6"; \
    LC_ALL=C awk 'BEGIN { for (i = 0; i < '"$pad"'; i++) print "- harness fixture 占位行（尾锚负例填充，无词面无短码）" }'; \
    printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; \
    tail -n +"$((aln + 1))" "$gf6"; } > "$D/gf6.tmp"
  mv "$D/gf6.tmp" "$gf6"
  printf "pm_vague_exempt references/protocol/governance-format.md 8200 'harness fixture 尾锚负例（行号字符串超集不误罩 :820 命中）'\n" >> "$D/pkgcopy6/scripts/package-manifest.rules"
  sh "$D/pkgcopy6/scripts/check-package.sh" "$D/pkgcopy6" >"$D/act.n9" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/protocol/governance-format.md:820 命中模糊措辞' "$D/act.n9" && grep -q '失效豁免（登记行无词表命中，须复核更新或删除登记）: references/protocol/governance-format.md:8200' "$D/act.n9"; then
    ok '负例 N9 尾锚证明：:820 注入命中不被 :82/:8200 豁免行号字符串前缀误罩 → exit 1 指名 :820'
  else
    bad '负例 N9 尾锚证明：:820 注入命中不被 :82/:8200 豁免行号字符串前缀误罩 → exit 1 指名 :820' "exit=$rc"
  fi

  # 票 59 检查 14 负例 N10：向 agents-implementation.md.tmpl 的 required_capabilities 行
  # 注入未登记基元名 → exit 1 且 FAIL: 14 指名文件（多出＝不在名单）。
  cp -R "$PKG_ROOT" "$D/pkgcopy7"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/`execute`；治理写入许可/`execute`、`harness-fixture-cap`；治理写入许可/' \
    "$D/pkgcopy7/references/templates/agents-implementation.md.tmpl" > "$D/tmpl7.tmp" \
    && mv "$D/tmpl7.tmp" "$D/pkgcopy7/references/templates/agents-implementation.md.tmpl"
  sh "$D/pkgcopy7/scripts/check-package.sh" "$D/pkgcopy7" >"$D/act.n10" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 14 能力映射一致' "$D/act.n10" && grep -q 'agents-implementation.md.tmpl 未登记基元名 harness-fixture-cap' "$D/act.n10"; then
    ok '负例 N10 注入未登记基元名入角色声明行 → exit 1 且 FAIL: 14 指名文件'
  else
    bad '负例 N10 注入未登记基元名入角色声明行 → exit 1 且 FAIL: 14 指名文件' "exit=$rc"
  fi

  # 票 59 检查 14 负例 N11：自同一声明行删除一基元名（edit）→ exit 1 且 FAIL: 14 指名
  # 文件（缺少＝相对登记预期名单）。
  cp -R "$PKG_ROOT" "$D/pkgcopy8"
  # shellcheck disable=SC2016  # fixture 文本/反引号字面量（刻意单引号，wiki 长尾误报）
  sed 's/、`edit`//' "$D/pkgcopy8/references/templates/agents-implementation.md.tmpl" > "$D/tmpl8.tmp" \
    && mv "$D/tmpl8.tmp" "$D/pkgcopy8/references/templates/agents-implementation.md.tmpl"
  sh "$D/pkgcopy8/scripts/check-package.sh" "$D/pkgcopy8" >"$D/act.n11" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 14 能力映射一致' "$D/act.n11" && grep -q 'agents-implementation.md.tmpl 缺少基元 edit' "$D/act.n11"; then
    ok '负例 N11 删除一基元名出角色声明行 → exit 1 且 FAIL: 14 指名文件'
  else
    bad '负例 N11 删除一基元名出角色声明行 → exit 1 且 FAIL: 14 指名文件' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N12：索引删一行（删 R-DP-037 行）→ exit 1 且 FAIL: 15 指名缺行。
  # 票 113 波④：流程权威拆三后索引宿主为三件模板，R-DP-037 索引行在 assessment.md.tmpl。
  cp -R "$PKG_ROOT" "$D/pkgcopy9"
  grep -v '^| R-DP-037 ' "$D/pkgcopy9/references/templates/assessment.md.tmpl" > "$D/tmpl9.tmp" \
    && mv "$D/tmpl9.tmp" "$D/pkgcopy9/references/templates/assessment.md.tmpl"
  sh "$D/pkgcopy9/scripts/check-package.sh" "$D/pkgcopy9" >"$D/act.n12" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n12" && grep -q '全集 ID 缺索引行: R-DP-037' "$D/act.n12"; then
    ok '负例 N12 索引删一行 → exit 1 且 FAIL: 15 指名缺行（索引变更先改表再动规则块的拦截面）'
  else
    bad '负例 N12 索引删一行 → exit 1 且 FAIL: 15 指名缺行（索引变更先改表再动规则块的拦截面）' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N13：索引表尾加全集外 ID 行（R-DP-999，短码 DP 已登记、序号不存在）
  # → exit 1 且 FAIL: 15 指名多行（检查 10 不误伤：短码在册）。
  # 票 113 波④：注入目标为索引宿主 project.md.tmpl（DP 短码三件之一，锚点在件）。
  cp -R "$PKG_ROOT" "$D/pkgcopy10"
  printf '| R-DP-999 | harness fixture 全集外 ID 负例 | 约定 |\n' >> "$D/pkgcopy10/references/templates/project.md.tmpl"
  sh "$D/pkgcopy10/scripts/check-package.sh" "$D/pkgcopy10" >"$D/act.n13" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n13" && grep -q '索引多出全集外 ID: R-DP-999' "$D/act.n13"; then
    ok '负例 N13 索引加全集外 ID → exit 1 且 FAIL: 15 指名多行'
  else
    bad '负例 N13 索引加全集外 ID → exit 1 且 FAIL: 15 指名多行' "exit=$rc"
  fi

  # 票 60 检查 16 负例 N14：机制列写未登记值（R-DP-001 约定→自动）→ exit 1 且 FAIL: 16
  # 指名 ID 与值（受控词表外置 manifest，harness 零词面字面量——注入值「自动」为场景
  # 固定负例字面量，非词表成员）。票 113 波④：R-DP-001 索引行在 project.md.tmpl。
  cp -R "$PKG_ROOT" "$D/pkgcopy11"
  sed '/^| R-DP-001 /s/| 约定 |$/| 自动 |/' "$D/pkgcopy11/references/templates/project.md.tmpl" > "$D/tmpl11.tmp" \
    && mv "$D/tmpl11.tmp" "$D/pkgcopy11/references/templates/project.md.tmpl"
  sh "$D/pkgcopy11/scripts/check-package.sh" "$D/pkgcopy11" >"$D/act.n14" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 16 索引机制列受控词表' "$D/act.n14" && grep -q 'R-DP-001 机制值不在受控词表: 自动' "$D/act.n14"; then
    ok '负例 N14 机制列写未登记值 → exit 1 且 FAIL: 16 指名 ID 与值'
  else
    bad '负例 N14 机制列写未登记值 → exit 1 且 FAIL: 16 指名 ID 与值' "exit=$rc"
  fi

  # 票 60 检查 17 负例 N15：机械行点名不存在脚本（R-RC-003 出处改 harness-fixture.sh）
  # → exit 1 且 FAIL: 17 指名 ID 与脚本。票 113 波④：R-RC-003 索引行在 discipline.md.tmpl。
  cp -R "$PKG_ROOT" "$D/pkgcopy12"
  sed 's/| 机械（lane-commit.sh） |/| 机械（harness-fixture.sh） |/' "$D/pkgcopy12/references/templates/discipline.md.tmpl" > "$D/tmpl12.tmp" \
    && mv "$D/tmpl12.tmp" "$D/pkgcopy12/references/templates/discipline.md.tmpl"
  sh "$D/pkgcopy12/scripts/check-package.sh" "$D/pkgcopy12" >"$D/act.n15" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 17 机械行点名出处存在' "$D/act.n15" && grep -q 'R-RC-003 机械行点名脚本不存在: harness-fixture.sh' "$D/act.n15"; then
    ok '负例 N15 机械行点名不存在脚本 → exit 1 且 FAIL: 17 指名 ID 与脚本'
  else
    bad '负例 N15 机械行点名不存在脚本 → exit 1 且 FAIL: 17 指名 ID 与脚本' "exit=$rc"
  fi

  # 票 145 恶意输入负例 N24～N27：临时副本 manifest 注入恶意行 → 非执行式解析期
  # exit 2 fail-closed 不产生部分结论（零 PASS/FAIL 检查行输出）——命令替换、反引号、
  # 引号外重定向、未知指令四形态；探针文件断言承载零执行（解析期无任何求值面）。
  for cp_i in 1 2 3 4; do
    cp -R "$PKG_ROOT" "$D/pkgmal$cp_i"
    case $cp_i in
      1) printf "pm_entry SKILL.md\npm_vague_word 'x\$(touch /tmp/trp145cp1)x'\n" >> "$D/pkgmal1/scripts/package-manifest.rules"; cp_desc='负例 N24 manifest 命令替换注入（引号内美元括号）→ exit 2 不产生部分结论'; cp_probe=/tmp/trp145cp1 ;;
      2) printf "pm_vague_word 'x\`touch /tmp/trp145cp2\`x'\n" >> "$D/pkgmal2/scripts/package-manifest.rules"; cp_desc='负例 N25 manifest 反引号注入 → exit 2 不产生部分结论'; cp_probe=/tmp/trp145cp2 ;;
      3) printf "pm_entry SKILL.md > /tmp/trp145cp3\n" >> "$D/pkgmal3/scripts/package-manifest.rules"; cp_desc='负例 N26 manifest 引号外重定向注入 → exit 2 不产生部分结论'; cp_probe=/tmp/trp145cp3 ;;
      4) printf "evil_cmd 'rm' '-rf' '/'\n" >> "$D/pkgmal4/scripts/package-manifest.rules"; cp_desc='负例 N27 manifest 未知指令注入 → exit 2 不产生部分结论'; cp_probe='' ;;
    esac
    sh "$D/pkgmal$cp_i/scripts/check-package.sh" "$D/pkgmal$cp_i" >"$D/act.n24_$cp_i" 2>&1
    rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^PASS' "$D/act.n24_$cp_i" && ! grep -q '^FAIL' "$D/act.n24_$cp_i" \
      && grep -q '非执行式解析不合预期' "$D/act.n24_$cp_i" \
      && { [ -z "$cp_probe" ] || [ ! -e "$cp_probe" ]; }; then
      ok "$cp_desc"
    else
      bad "$cp_desc" "exit=$rc head=$(head -n 1 "$D/act.n24_$cp_i")"
    fi
  done
  rm -f /tmp/trp145cp1 /tmp/trp145cp2 /tmp/trp145cp3

  # 票 60 检查 17 负例 N16：机械行点名检查项号超界（R-RC-003 出处改 lane-commit.sh 检查 18）
  # → exit 1 且 FAIL: 17 指名 ID 与项号（引擎自述总数随检查面增长，票 195 后为 23；注入
  # 检查 24＝超界一位，随总数同步）。
  cp -R "$PKG_ROOT" "$D/pkgcopy13"
  sed 's/| 机械（lane-commit.sh） |/| 机械（lane-commit.sh 检查 24） |/' "$D/pkgcopy13/references/templates/discipline.md.tmpl" > "$D/tmpl13.tmp" \
    && mv "$D/tmpl13.tmp" "$D/pkgcopy13/references/templates/discipline.md.tmpl"
  sh "$D/pkgcopy13/scripts/check-package.sh" "$D/pkgcopy13" >"$D/act.n16" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 17 机械行点名出处存在' "$D/act.n16" && grep -q 'R-RC-003 机械行点名检查项号超界（当前共 23 项）: 检查 24' "$D/act.n16"; then
    ok '负例 N16 机械行点名检查项号超界 → exit 1 且 FAIL: 17 指名 ID 与项号'
  else
    bad '负例 N16 机械行点名检查项号超界 → exit 1 且 FAIL: 17 指名 ID 与项号' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N17：外定义行删标记词（R-CC-002 机制列「门禁；外定义（…）」改「门禁」）
  # → exit 1 且 FAIL: 15 算漏行（外定义豁免须显式标注非静默）。票 113 波④：R-CC-002
  # 索引行在 discipline.md.tmpl。
  cp -R "$PKG_ROOT" "$D/pkgcopy14"
  sed 's/| 门禁；外定义（定义于 references\/adapters\/capability-contract.md） |/| 门禁 |/' "$D/pkgcopy14/references/templates/discipline.md.tmpl" > "$D/tmpl14.tmp" \
    && mv "$D/tmpl14.tmp" "$D/pkgcopy14/references/templates/discipline.md.tmpl"
  sh "$D/pkgcopy14/scripts/check-package.sh" "$D/pkgcopy14" >"$D/act.n17" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n17" && grep -q '外定义 ID 行未标注标记词「外定义」（豁免须显式，未标注算漏行）: R-CC-002（定义于 references/adapters/capability-contract.md）' "$D/act.n17"; then
    ok '负例 N17 外定义行删标记词 → exit 1 且 FAIL: 15 算漏行（豁免显式非静默）'
  else
    bad '负例 N17 外定义行删标记词 → exit 1 且 FAIL: 15 算漏行（豁免显式非静默）' "exit=$rc"
  fi

  # 票 60 负例 N18：manifest mechanism-vocab 词表损坏（重复行）→ 引擎结构校验 exit 2
  # fail-closed（受控词表是检查 16 比对基准，损坏不产生部分结论）。
  cp -R "$PKG_ROOT" "$D/pkgcopy15"
  printf 'pm_mechanism 机械\n' >> "$D/pkgcopy15/scripts/package-manifest.rules"
  sh "$D/pkgcopy15/scripts/check-package.sh" "$D/pkgcopy15" >"$D/act.n18" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'mechanism-vocab 节第' "$D/act.n18"; then
    ok '负例 N18 mechanism-vocab 词表损坏（跨行重复）→ exit 2 fail-closed'
  else
    bad '负例 N18 mechanism-vocab 词表损坏（跨行重复）→ exit 2 fail-closed' "exit=$rc"
  fi

  # 票 82 检查 18 负例 N19：向包内 .md 文档面注入票号引用（「票 41」形态）→ exit 1 且
  # FAIL: 18 指名文件:行号（禁令断言只查模式不判语义）。
  cp -R "$PKG_ROOT" "$D/pkgcopy16"
  printf '\n- harness fixture 票号注入行（引用本仓票 41 联动收口）\n' >> "$D/pkgcopy16/references/protocol/read-policy.md"
  sh "$D/pkgcopy16/scripts/check-package.sh" "$D/pkgcopy16" >"$D/act.n19" 2>&1
  rc=$?
  n19_ln=$(wc -l < "$D/pkgcopy16/references/protocol/read-policy.md" | tr -d ' ')
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 18 包内票号索引禁令' "$D/act.n19" && grep -q "references/protocol/read-policy.md:${n19_ln}:" "$D/act.n19" && grep -q '命中票号索引禁令' "$D/act.n19"; then
    ok '负例 N19 注入票号引用入 .md 文档面 → exit 1 且 FAIL: 18 指名文件:行号'
  else
    bad '负例 N19 注入票号引用入 .md 文档面 → exit 1 且 FAIL: 18 指名文件:行号' "exit=$rc"
  fi

  # 票 82 检查 18 正例 N20：同一注入行经夹具 manifest 登记行级豁免 → 该行不报 exit 0
  # （豁免语境不报；夹具包自带引擎读取自身 manifest——检查 12 N5 同款口径）。
  cp -R "$PKG_ROOT" "$D/pkgcopy17"
  printf '\n- harness fixture 票号注入行（引用本仓票 41 联动收口）\n' >> "$D/pkgcopy17/references/protocol/read-policy.md"
  n20_ln=$(wc -l < "$D/pkgcopy17/references/protocol/read-policy.md" | tr -d ' ')
  printf "pm_cite_exempt references/protocol/read-policy.md %d 'harness fixture 票号豁免正例（登记后该行不报）'\n" "$n20_ln" >> "$D/pkgcopy17/scripts/package-manifest.rules"
  sh "$D/pkgcopy17/scripts/check-package.sh" "$D/pkgcopy17" >"$D/act.n20" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 18 包内票号索引禁令' "$D/act.n20"; then
    ok '正例 N20 注入行登记行级豁免后不报 → exit 0（豁免生效）'
  else
    bad '正例 N20 注入行登记行级豁免后不报 → exit 0（豁免生效）' "exit=$rc"
  fi

  # 票 82 检查 18 负例 N21：豁免登记行无命中（999 行）→ 失效豁免 FAIL
  # （防漂移静默失效，检查 12 N6 同款口径）。
  cp -R "$PKG_ROOT" "$D/pkgcopy18"
  printf "pm_cite_exempt references/protocol/read-policy.md 999 'harness fixture 票号失效豁免负例'\n" >> "$D/pkgcopy18/scripts/package-manifest.rules"
  sh "$D/pkgcopy18/scripts/check-package.sh" "$D/pkgcopy18" >"$D/act.n21" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '失效豁免（登记行无票号命中，须复核更新或删除登记）: references/protocol/read-policy.md:999' "$D/act.n21"; then
    ok '负例 N21 票号豁免登记行无命中 → exit 1 且 FAIL: 18 报失效豁免'
  else
    bad '负例 N21 票号豁免登记行无命中 → exit 1 且 FAIL: 18 报失效豁免' "exit=$rc"
  fi

  # 票 95 检查 19 负例 N22：夹具副本（cp -R 落位＝非 git 语境）检查 19 静默跳过——
  # 全部既有负例输出零检查 19 行的语境前提钉死（git 不可用则 index mode 无从核对，
  # 静默跳过不误报，检查 13 静默语义同款）。
  cp -R "$PKG_ROOT" "$D/pkgcopy19"
  sh "$D/pkgcopy19/scripts/check-package.sh" "$D/pkgcopy19" >"$D/act.n22" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q 'scripts 节 mode 断言' "$D/act.n22"; then
    ok '负例 N22 非 git 语境（cp 副本）检查 19 静默跳过无输出行 → exit 0'
  else
    bad '负例 N22 非 git 语境（cp 副本）检查 19 静默跳过无输出行 → exit 0' "exit=$rc"
  fi

  # 票 95 检查 19 负例 N23：git 夹具语境（worktree 布线）mode 双向负例——kind=script
  # 可执行件置 644 与 kind=rules 数据件置 755 同夹具各一，双断言（index mode＋盘上 -x）
  # 同报且逐件指名期望 mode；git add 后 index 才承载翻转，零布线的纯盘上 chmod 不得
  # 令 index 断言误判。
  cp -R "$PKG_ROOT" "$D/pkgcopy20"
  (
    cd "$D/pkgcopy20" || exit 1
    git init -q
    git add -A
    chmod 644 scripts/generate-progress.sh
    chmod 755 scripts/module-map.rules
    git add scripts/generate-progress.sh scripts/module-map.rules
    git -c user.email=fixture@example.com -c user.name=fixture commit -qm fixture
  ) >/dev/null 2>&1
  sh "$D/pkgcopy20/scripts/check-package.sh" "$D/pkgcopy20" >"$D/act.n23" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '^FAIL: 19 scripts 节 mode 断言（28 件，kind 数据驱动）' "$D/act.n23" \
    && grep -q 'scripts/generate-progress.sh index mode 为 100644（期望 100755，kind=script）' "$D/act.n23" \
    && grep -q 'scripts/generate-progress.sh 盘上不可执行（kind=script 须可执行，chmod 755 修复）' "$D/act.n23" \
    && grep -q 'scripts/module-map.rules index mode 为 100755（期望 100644，kind=rules）' "$D/act.n23" \
    && grep -q 'scripts/module-map.rules 盘上可执行（kind=rules 数据件禁执行位）' "$D/act.n23"; then
    ok '负例 N23 git 语境 mode 双向负例（script→644／rules→755）→ exit 1 且双断言同报指名期望 mode'
  else
    bad '负例 N23 git 语境 mode 双向负例（script→644／rules→755）→ exit 1 且双断言同报指名期望 mode' "exit=$rc"
  fi

  # 票 149 检查 20 负例 N24：scripts/ 一级未登记额外文件（恶意投放面）→ exit 1 且
  # FAIL: 20 指名条目；隐藏条目（. 开头）同入条目面一并拦截。
  cp -R "$PKG_ROOT" "$D/pkgcopy21"
  printf '# harness fixture 未登记额外件\n' > "$D/pkgcopy21/scripts/harness-fixture-extra.sh"
  printf 'x' > "$D/pkgcopy21/scripts/harness-fixture-extra.txt"
  printf 'y' > "$D/pkgcopy21/scripts/.harness-fixture-hidden"
  sh "$D/pkgcopy21/scripts/check-package.sh" "$D/pkgcopy21" >"$D/act.n24" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 20 包闭合性与符号链接防护' "$D/act.n24" \
    && grep -q '.harness-fixture-hidden、harness-fixture-extra.sh、harness-fixture-extra.txt' "$D/act.n24"; then
    ok '负例 N24 scripts/ 一级未登记额外件（含隐藏件）→ exit 1 且 FAIL: 20 指名条目'
  else
    bad '负例 N24 scripts/ 一级未登记额外件（含隐藏件）→ exit 1 且 FAIL: 20 指名条目' "exit=$rc"
  fi

  # 票 149 检查 20 负例 N25：symlink 混合面——scripts 下外指 symlink（AC2 面：脚本
  # symlink 被拒）与 references 下断链外指同夹具，外指面＋别名面双报（readlink 原始
  # 目标＋词法折叠，不依赖 GNU readlink -f）。
  cp -R "$PKG_ROOT" "$D/pkgcopy22"
  ln -sf /etc/passwd "$D/pkgcopy22/scripts/harness-fixture-ro.sh"
  ln -sf ../../../../../../etc/hosts "$D/pkgcopy22/references/templates/harness-fixture-dead.md"
  sh "$D/pkgcopy22/scripts/check-package.sh" "$D/pkgcopy22" >"$D/act.n25" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 20 包闭合性与符号链接防护' "$D/act.n25" \
    && grep -q 'scripts/harness-fixture-ro.sh' "$D/act.n25" \
    && grep -q 'references/templates/harness-fixture-dead.md' "$D/act.n25" \
    && grep -q '包内 symlink 指向包根外部' "$D/act.n25"; then
    ok '负例 N25 symlink 混合面（scripts 外指＋references 断链外指）→ exit 1 且外指/别名双报'
  else
    bad '负例 N25 symlink 混合面（scripts 外指＋references 断链外指）→ exit 1 且外指/别名双报' "exit=$rc"
  fi

  # 票 149 检查 20 负例 N26：非 git 语境（cp 副本，N22 同款）检查 20 照常运行零静默
  # ——闭合性不依赖 git（find 条目面＋readlink），与检查 19 静默跳过语义相区分。
  cp -R "$PKG_ROOT" "$D/pkgcopy23"
  sh "$D/pkgcopy23/scripts/check-package.sh" "$D/pkgcopy23" >"$D/act.n26" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 20 包闭合性与符号链接防护' "$D/act.n26"; then
    ok '负例 N26 非 git 语境检查 20 照常运行 → exit 0 且 PASS: 20 有输出行'
  else
    bad '负例 N26 非 git 语境检查 20 照常运行 → exit 0 且 PASS: 20 有输出行' "exit=$rc"
  fi

  # 票 190 检查 21 负例组（references 树成员闭合与导航；cp 副本 mktemp 纪律，断言独立
  # 重建：每组夹具只注入单点缺陷，FAIL 指名逐字断言）。
  # 负例 N28：references 子树新增未登记文件 → exit 1 且 FAIL: 21 指名条目（成员增漏登记）。
  cp -R "$PKG_ROOT" "$D/pkgcopy24"
  printf 'x' > "$D/pkgcopy24/references/workflows/harness-fixture-extra.txt"
  sh "$D/pkgcopy24/scripts/check-package.sh" "$D/pkgcopy24" >"$D/act.n28" 2>&1
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
  cp -R "$PKG_ROOT" "$D/pkgcopy25"
  rm -f "$D/pkgcopy25/references/workflows/triage.yaml"
  sh "$D/pkgcopy25/scripts/check-package.sh" "$D/pkgcopy25" >"$D/act.n29" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 1 必需入口存在（37 个文件）' "$D/act.n29" \
    && grep -q '  - references/workflows/triage.yaml' "$D/act.n29"; then
    ok '负例 N29 删除已登记 references 成员 → exit 1 且 FAIL: 1 指名缺件'
  else
    bad '负例 N29 删除已登记 references 成员 → exit 1 且 FAIL: 1 指名缺件' "exit=$rc"
  fi

  # 负例 N30：坏相对链接（目标不存在）注入 README → exit 1 且 FAIL: 21 指名文件:行号
  # 与目标（链接检查锚点＝行内 ](target)，外链与纯锚点不在口径）。
  cp -R "$PKG_ROOT" "$D/pkgcopy26"
  printf '\nharness fixture 坏链接注入行：见 [gone](harness-fixture-gone.md)。\n' >> "$D/pkgcopy26/references/README.md"
  sh "$D/pkgcopy26/scripts/check-package.sh" "$D/pkgcopy26" >"$D/act.n30" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 21 references 树成员闭合与导航' "$D/act.n30" \
    && grep -q 'references/README.md:[0-9][0-9]* 坏相对链接（目标不存在）: harness-fixture-gone.md' "$D/act.n30"; then
    ok '负例 N30 坏相对链接注入 → exit 1 且 FAIL: 21 指名文件:行号与目标'
  else
    bad '负例 N30 坏相对链接注入 → exit 1 且 FAIL: 21 指名文件:行号与目标' "exit=$rc"
  fi

  # 负例 N31：一级新增目录未入 README 目录清单投影 → exit 1 且 FAIL: 21 双报
  # （全树未登记条目＋一级条目未在投影登记——数据/实物＝机器真相、README 表＝人读投影）。
  cp -R "$PKG_ROOT" "$D/pkgcopy27"
  mkdir -p "$D/pkgcopy27/references/harness-fixture-dir"
  printf 'x' > "$D/pkgcopy27/references/harness-fixture-dir/extra.txt"
  sh "$D/pkgcopy27/scripts/check-package.sh" "$D/pkgcopy27" >"$D/act.n31" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 21 references 树成员闭合与导航' "$D/act.n31" \
    && grep -q 'references/harness-fixture-dir/extra.txt' "$D/act.n31" \
    && grep -q 'references/ 一级条目未在 README 目录清单登记: harness-fixture-dir' "$D/act.n31"; then
    ok '负例 N31 一级新增目录未入 README 投影 → exit 1 且 FAIL: 21 双报（未登记条目＋投影缺名）'
  else
    bad '负例 N31 一级新增目录未入 README 投影 → exit 1 且 FAIL: 21 双报（未登记条目＋投影缺名）' "exit=$rc"
  fi

  # 票 190 检查 13 所有权三分类夹具组（源仓语境＝仓侧 rules/implementation/scripts/ 在场；
  # 消费项目语境该目录不存在，整组显式 SKIP 不计数，覆盖归源仓；全部夹具 mktemp 纪律）。
  if [ -d "$REPO_SIDE" ]; then
    # 负例 N32：mirror 登记悬空（仓侧少复制一件 health-summary.sh）→ exit 1 且 FAIL: 13
    # 指名悬空件（mirror 类登记须两落位在场，缺件不得静默）。
    mkdir -p "$D/mrepo2/scripts" "$D/mrepo2/rules/implementation/scripts"
    cp -R "$PKG_ROOT" "$D/mrepo2/agent-up"
    for m in generate-progress.sh ticket-ops.sh absorption-trigger.sh run-record.sh ticket-grade.sh lane-commit.sh check-gates.sh upgrade-check.sh; do
      cp "$PKG_ROOT/scripts/$m" "$D/mrepo2/scripts/$m"
    done
    for m in merge-ticket.sh check-derived-freshness.sh check-payload-boundary.sh check-role-permissions.sh; do
      cp "$REPO_SIDE/$m" "$D/mrepo2/rules/implementation/scripts/$m"
    done
    sh "$D/mrepo2/agent-up/scripts/check-package.sh" "$D/mrepo2/agent-up" >"$D/act.n32" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q '^FAIL: 13 镜像脚本与仓根同名件一致' "$D/act.n32" \
      && grep -q 'scripts/health-summary.sh 登记 mirror 但仓侧两落位皆无同名件' "$D/act.n32"; then
      ok '负例 N32 mirror 登记悬空（仓侧缺同名件）→ exit 1 且 FAIL: 13 指名悬空件'
    else
      bad '负例 N32 mirror 登记悬空（仓侧缺同名件）→ exit 1 且 FAIL: 13 指名悬空件' "exit=$rc"
    fi

    # 负例 N33：repo-only 件被投放包内（merge-ticket.sh 复制入 scripts/）→ exit 1 且
    # FAIL: 13 指名（防未决策采纳；夹具继承 N32 仓侧缺件缺陷，指名断言逐字独立）。
    cp -R "$D/mrepo2" "$D/mrepo3"
    cp "$REPO_SIDE/merge-ticket.sh" "$D/mrepo3/agent-up/scripts/merge-ticket.sh"
    sh "$D/mrepo3/agent-up/scripts/check-package.sh" "$D/mrepo3/agent-up" >"$D/act.n33" 2>&1
    rc=$?
    if [ "$rc" -eq 1 ] && grep -q 'scripts/merge-ticket.sh 登记 repo-only 但包内出现同名件' "$D/act.n33"; then
      ok '负例 N33 repo-only 件投放包内 → exit 1 且 FAIL: 13 指名（防未决策采纳）'
    else
      bad '负例 N33 repo-only 件投放包内 → exit 1 且 FAIL: 13 指名（防未决策采纳）' "exit=$rc"
    fi

    # 正例 P1：package-only 过渡态临时夹具（全 mktemp 源仓语境：9 对 mirror 全 cmp＋
    # 4 件 package-only 仓侧同名实例在场不判差异＋4 件 repo-only 包侧缺席）→ exit 0 且
    # PASS: 13 比对 9 对（三分类登记与两侧实物全恰，含检查 21 同过）。
    mkdir -p "$D/porepo/scripts" "$D/porepo/rules/implementation/scripts"
    cp -R "$PKG_ROOT" "$D/porepo/agent-up"
    for m in generate-progress.sh ticket-ops.sh absorption-trigger.sh health-summary.sh run-record.sh ticket-grade.sh lane-commit.sh check-gates.sh upgrade-check.sh; do
      cp "$PKG_ROOT/scripts/$m" "$D/porepo/scripts/$m"
    done
    for m in merge-ticket.sh check-derived-freshness.sh check-payload-boundary.sh check-role-permissions.sh; do
      cp "$REPO_SIDE/$m" "$D/porepo/rules/implementation/scripts/$m"
    done
    sh "$D/porepo/agent-up/scripts/check-package.sh" "$D/porepo/agent-up" >"$D/act.p1" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ] && grep -q '^PASS: 13 镜像脚本与仓根同名件一致（比对 9 对）' "$D/act.p1" \
      && grep -q '^PASS: 21 references 树成员闭合与导航' "$D/act.p1"; then
      ok '正例 P1 package-only 过渡态临时夹具（全 mktemp，三分类与两侧实物全恰）→ exit 0 且 PASS: 13 比对 9 对'
    else
      bad '正例 P1 package-only 过渡态临时夹具（全 mktemp，三分类与两侧实物全恰）→ exit 0 且 PASS: 13 比对 9 对' "exit=$rc"
    fi
  else
    printf 'SKIP  [check-package] 仓侧 rules/implementation/scripts 不在场（消费项目语境）——检查 13 所有权三分类夹具组跳过，覆盖归源仓\n'
  fi

  # 票 195 检查 22/23 组（规则块九字段格式＋§16 序言短指针；夹具全 mktemp，负例每组单点
  # 缺陷，FAIL 指名字段或 ID 逐字断言）。
  # 正例 P2：三索引宿主（锚点「## 16. 规则索引」检测，引擎同款零宿主名硬编码）§16 序言
  # 各自逐字等于 governance-format.md R-GF-011 定稿短指针——权威原句经「」窄锚点独立
  # 重建，harness 零句子硬编码。
  canon=$(LC_ALL=C awk '/索引节首序言只写一句短指针/ { print; exit }' "$PKG_ROOT/references/protocol/governance-format.md" \
    | LC_ALL=C sed -e 's/「/(/g' -e 's/」/)/g' \
    | LC_ALL=C awk '{ i = index($0, "("); if (i > 0) { rest = substr($0, i + 1); j = index(rest, ")"); if (j > 1) { print substr(rest, 1, j - 1); exit } } }')
  if [ -n "$canon" ] && printf '%s' "$canon" | grep -q 'governance-format\.md'; then
    for idx_tmpl in $(find "$PKG_ROOT/references/templates" -name '*.tmpl' | LC_ALL=C sort); do
      grep -q '^## 16\. 规则索引' "$idx_tmpl" 2>/dev/null || continue
      idx_name=$(basename "$idx_tmpl")
      idx_pre=$(LC_ALL=C awk '
        /^## 16\. 规则索引/ { insec = 1; next }
        insec && (/^## / || /^\| ID \|/) { exit }
        insec && NF { print }
      ' "$idx_tmpl")
      if [ -n "$idx_pre" ] && [ "$idx_pre" = "$canon" ]; then
        ok "正例 P2 $idx_name §16 序言＝唯一权威短指针（逐字相等，三宿主各自断言）"
      else
        bad "正例 P2 $idx_name §16 序言＝唯一权威短指针（逐字相等，三宿主各自断言）" '序言与权威原句不一致或缺序言'
      fi
    done
  else
    bad '正例 P2 权威短指针原句独立重建' 'governance-format.md R-GF-011「」锚点未命中'
  fi

  # 负例 N34：缺九字段——assessment.md.tmpl R-DP-037 块体删 Forbidden 行 → exit 1 且
  # FAIL: 22 指名 ID 与缺失字段名（目标块无既有豁免联动，其余 93 块照旧）。
  cp -R "$PKG_ROOT" "$D/pkgrb1"
  grep -v '^\- \*\*Forbidden\*\*：治理变更走任务票' "$D/pkgrb1/references/templates/assessment.md.tmpl" > "$D/rb1.tmp" \
    && mv "$D/rb1.tmp" "$D/pkgrb1/references/templates/assessment.md.tmpl"
  sh "$D/pkgrb1/scripts/check-package.sh" "$D/pkgrb1" >"$D/act.n34" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n34" \
    && grep -q 'R-DP-037 块体缺字段（references/templates/assessment.md.tmpl:[0-9][0-9]* 起）: Forbidden' "$D/act.n34"; then
    ok '负例 N34 规则块删一字段（Forbidden）→ exit 1 且 FAIL: 22 指名 ID 与缺失字段'
  else
    bad '负例 N34 规则块删一字段（Forbidden）→ exit 1 且 FAIL: 22 指名 ID 与缺失字段' "exit=$rc"
  fi

  # 负例 N35：非法 Level——R-DP-037 标题 Level 改自造值 SHALL → exit 1 且 FAIL: 22 指名
  # ID 与标题原文（受控四值 MUST/MUST NOT/SHOULD/MAY 外零容忍）。
  cp -R "$PKG_ROOT" "$D/pkgrb2"
  # shellcheck disable=SC2016  # sed 程序刻意字面（反引号为文本字面量，wiki 长尾误报）
  sed 's/^#### R-DP-037 拆票内容边界 `MUST`$/#### R-DP-037 拆票内容边界 `SHALL`/' "$D/pkgrb2/references/templates/assessment.md.tmpl" > "$D/rb2.tmp" \
    && mv "$D/rb2.tmp" "$D/pkgrb2/references/templates/assessment.md.tmpl"
  sh "$D/pkgrb2/scripts/check-package.sh" "$D/pkgrb2" >"$D/act.n35" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n35" \
    && grep -q 'R-DP-037 标题行 Level 缺失或非法（须 MUST/MUST NOT/SHOULD/MAY，标题：#### R-DP-037 拆票内容边界 SHALL）' "$D/act.n35"; then
    ok '负例 N35 规则块 Level 改自造值（SHALL）→ exit 1 且 FAIL: 22 指名 ID 与标题'
  else
    bad '负例 N35 规则块 Level 改自造值（SHALL）→ exit 1 且 FAIL: 22 指名 ID 与标题' "exit=$rc"
  fi

  # 负例 N36：重复 ID——assessment.md.tmpl 整块复制 R-DP-033（标题＋七字段体，双块均
  # 合法，单点只触发 ID 唯一性）→ exit 1 且 FAIL: 22 指名 ID 与两处文件:行号。
  cp -R "$PKG_ROOT" "$D/pkgrb3"
  awk '{ print } /^#### R-DP-033 / { inblk = 1; buf = $0 "\n"; next } inblk { buf = buf $0 "\n" } inblk && /^- \*\*Authority\*\*：/ { printf "%s", buf; inblk = 0 }' \
    "$D/pkgrb3/references/templates/assessment.md.tmpl" > "$D/rb3.tmp" \
    && mv "$D/rb3.tmp" "$D/pkgrb3/references/templates/assessment.md.tmpl"
  sh "$D/pkgrb3/scripts/check-package.sh" "$D/pkgrb3" >"$D/act.n36" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 22 规则块九字段格式' "$D/act.n36" \
    && grep -q '规则块 ID 重复（全局唯一，不得复用）: R-DP-033（references/templates/assessment.md.tmpl:[0-9][0-9]* references/templates/assessment.md.tmpl:[0-9][0-9]*）' "$D/act.n36"; then
    ok '负例 N36 整块复制重复 ID → exit 1 且 FAIL: 22 指名 ID 与两处行号'
  else
    bad '负例 N36 整块复制重复 ID → exit 1 且 FAIL: 22 指名 ID 与两处行号' "exit=$rc"
  fi

  # 负例 N37：§16 序言短指针外多写格式散文（discipline.md.tmpl 序言后追加机制定义行）
  # → exit 1 且 FAIL: 23 指名模板与多出散文行（AC2「多写了格式散文」负例）。
  cp -R "$PKG_ROOT" "$D/pkgrb4"
  awk '{ print } /^本节为规则块导航投影/ { print "规则索引机制受控三值定义：机械＝点名脚本；门禁＝检查点卡；约定＝自觉。" }' \
    "$D/pkgrb4/references/templates/discipline.md.tmpl" > "$D/rb4.tmp" \
    && mv "$D/rb4.tmp" "$D/pkgrb4/references/templates/discipline.md.tmpl"
  sh "$D/pkgrb4/scripts/check-package.sh" "$D/pkgrb4" >"$D/act.n37" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 23 索引节序言短指针' "$D/act.n37" \
    && grep -q 'discipline.md.tmpl §16 序言多行（短指针外不得另立散文）: 规则索引机制受控三值定义' "$D/act.n37"; then
    ok '负例 N37 序言短指针外多写格式散文 → exit 1 且 FAIL: 23 指名模板与散文行'
  else
    bad '负例 N37 序言短指针外多写格式散文 → exit 1 且 FAIL: 23 指名模板与散文行' "exit=$rc"
  fi

  # 负例 N38：§16 序言换第二权威指针（project.md.tmpl 短指针改指 rules/project.md §16，
  # 即收敛前旧形态）→ exit 1 且 FAIL: 23 指名模板与不一致原文。
  cp -R "$PKG_ROOT" "$D/pkgrb5"
  # shellcheck disable=SC2016  # sed 程序刻意字面（反引号为文本字面量，wiki 长尾误报）
  sed 's|^本节为规则块导航投影，表行语义以各规则块正文为准；规则块格式与执行机制语义的唯一权威见 `references/protocol/governance-format.md`。$|本节序言语义统一见 `rules/project.md` §16。|' \
    "$D/pkgrb5/references/templates/project.md.tmpl" > "$D/rb5.tmp" \
    && mv "$D/rb5.tmp" "$D/pkgrb5/references/templates/project.md.tmpl"
  sh "$D/pkgrb5/scripts/check-package.sh" "$D/pkgrb5" >"$D/act.n38" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 23 索引节序言短指针' "$D/act.n38" \
    && grep -q 'project.md.tmpl §16 序言与唯一权威短指针不一致（须逐字等于 governance-format.md §2.7 定稿原句）: 本节序言语义统一见' "$D/act.n38"; then
    ok '负例 N38 序言换第二权威指针（收敛前旧形态）→ exit 1 且 FAIL: 23 指名模板与原文'
  else
    bad '负例 N38 序言换第二权威指针（收敛前旧形态）→ exit 1 且 FAIL: 23 指名模板与原文' "exit=$rc"
  fi

  # 负例 N39：§16 序言短指针整行删除（assessment.md.tmpl）→ exit 1 且 FAIL: 23 缺短指针
  # （三负例 N37/N38/N39 分别打多行散文、第二权威、缺指针独立方向）。
  cp -R "$PKG_ROOT" "$D/pkgrb6"
  grep -v '^本节为规则块导航投影' "$D/pkgrb6/references/templates/assessment.md.tmpl" > "$D/rb6.tmp" \
    && mv "$D/rb6.tmp" "$D/pkgrb6/references/templates/assessment.md.tmpl"
  sh "$D/pkgrb6/scripts/check-package.sh" "$D/pkgrb6" >"$D/act.n39" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 23 索引节序言短指针' "$D/act.n39" \
    && grep -q 'assessment.md.tmpl §16 序言缺短指针（锚点行与索引表之间无非空序言行）' "$D/act.n39"; then
    ok '负例 N39 序言短指针整行删除 → exit 1 且 FAIL: 23 缺短指针'
  else
    bad '负例 N39 序言短指针整行删除 → exit 1 且 FAIL: 23 缺短指针' "exit=$rc"
  fi

  # 负例 N40（返工轮回归钉死）：格式权威文件缺失（governance-format.md 移出包外）→
  # exit 1 且 FAIL: 23 指名缺失件＋结尾汇总行出现＋零 unbound variable——修复前该分支
  # 未初始化 n_hosts，set -u 展开崩溃且 EXIT trap 吞状态 exit 0 假绿（损坏包整体放行，
  # 违反「任一失败 exit 1」契约），本负例钉死该回归。
  cp -R "$PKG_ROOT" "$D/pkgrb7"
  mv "$D/pkgrb7/references/protocol/governance-format.md" "$D/gf.hidden"
  sh "$D/pkgrb7/scripts/check-package.sh" "$D/pkgrb7" >"$D/act.n40" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && grep -q '^FAIL: 23 索引节序言短指针（宿主 0 件，权威定稿原句逐字核对）' "$D/act.n40" \
    && grep -q '  - 格式权威文件不存在: references/protocol/governance-format.md' "$D/act.n40" \
    && grep -q '^check-package: FAIL（' "$D/act.n40" \
    && ! grep -q 'unbound variable' "$D/act.n40"; then
    ok '负例 N40 权威文件缺失 → exit 1 且 FAIL: 23 指名缺失件＋汇总行出现（unbound variable 假绿回归钉死）'
  else
    bad '负例 N40 权威文件缺失 → exit 1 且 FAIL: 23 指名缺失件＋汇总行出现（unbound variable 假绿回归钉死）' "exit=$rc"
  fi

  suite_summary 'check-package'
}
