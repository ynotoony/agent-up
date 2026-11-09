#!/bin/sh
# Input: 同目录被测脚本（启动核对循环为唯一清单，逐件断言在位；main-only 件不在核对
#        面、相关套件自行 SKIP）与参数：--suite/--script-dir/--pkg-root。
#        场景来源＝票 41～45/47 六票 Implementation Checkpoint 的 fixture（只作场景清单）；
#        预期值按被测脚本当前行为独立重建（cmp/逐一相等断言，票 26 教训）；票 56 检查 8
#        清单 8→10 件（追加 install.sh＋install-policy.rules），check-package 套件预期串
#        同步（协调层改判：同步不做推迟）；票 57 包清单数据化（check-package 检查 1/5/8
#        改读 package-manifest.rules 数据＋新增检查 9/10/11），预期串同步十一项口径——
#        正例含新增三查 PASS 行，负例（删 generate-progress.sh）联动检查 9 双 FAIL；
#        协调层改判随票修：检查 11 逐处全等，补 capability-contract §2.5 单处删值负例；
#        票 58 检查 11→13（12＝模糊措辞扫描，13＝镜像 cmp），预期串同步十三项口径并补
#        注入/豁免/镜像负例；新增 append-only 套件（check-append-only.sh 正负例，
#        选定独立 suite 承载并在 README 声明）；票 59 检查 13→14（14＝能力映射一致性），
#        预期串同步十四项口径并补注入未登记基元/删基元负例；新增 check-artifacts 套件
#        （治理产物对账正负例，独立 suite 承载并在 README 声明）；票 60 检查 14→17
#        （15＝模板 §16 规则索引与规则块全集全等、16＝索引机制列受控词表、17＝机械行
#        点名出处存在），check-append-only.sh/check-artifacts.sh 补登记清单 scripts 节
#        （10→12 件），预期串同步十七项口径并补索引删行/加全集外 ID/未登记机制值/
#        机械行点名不存在脚本/检查项号超界/外定义行删标记词负例＋mechanism-vocab
#        词表损坏 exit 2 负例；票 82 包内票号索引禁令断言（检查 17→18——18＝「票 ?[0-9]{2,}」
#        扫描 md/tmpl/json/rules，行级豁免与失效豁免同款核对；.sh 代码面不扫），预期串
#        同步十八项口径并补禁令注入/豁免生效/失效豁免负例；票 72 清单 scripts 节 12→13 件（export-payload.sh 入册），
#        检查 8 预期串计数随动；新增 stale-claims 套件（S1/S2 配置点亮：未点亮 SKIP
#        不计数、点亮按配置断言、delivery.rules 解析破坏 exit 2、汇总登记数动态化，
#        独立 suite 承载并在 README 声明）；票 77（NN 唯一性：ticket-ops open 补同 NN 异
#        slug 撞号拒开 fail-closed，套件补 N7 同 NN 拒＋N8 畸形 id 拒＋新 NN 正开三断言，
#        正例本体随票 79 前置校验落位）；票 79 ticket-ops 套件加 open 本体 schema 校验
#        ＋理由非空断言（正例夹具落位含理由两字段的本体照旧放过；负例＝缺
#        complexity_reason／priority_reason 空值／缺本体文件，均 exit 1 零写入；夹具增
#        schema 权威落位，python3 列为套件环境依赖）；票 81 账本行型扩展（lesson 必带
#        第六键 promoted_to（枚举 新票/rules/sop/validator/test/none）、replan 必带
#        replan_original/replan_replacement/replan_undone 布尔，既有五键行向后兼容）：
#        正例四（lesson promoted_to=sop／replan 三键齐／lesson promoted_to=none 枚举边界／
#        对照组五键 kind=change 行照旧）＋负例四（lesson 缺 promoted_to／promoted_to 越枚举／
#        replan 缺 replan_undone／条件键序破坏，均 exit 1 零写入）进 ticket-ops 套件；
#        票 85（R-DP-033 加固：check-stale-claims 登记表增 S5 方案结论标注句——结论行
#        file: 出处＋轨:受控两值格式断言，向前生效只查工作区新增/修改面）：stale-claims
#        套件登记数期望随动（未点亮 2→3、全点亮 4→5）＋S5 正负例四（新增面标注齐→
#        exit 0；新增面缺标注→STALE 指名 file:line；存量已提交不回溯→exit 0；修改面
#        缺标注→STALE，夹具经 git init 基线提交承载向前生效语义）；票 94（S6 终态哨兵：
#        check-stale-claims 登记表增 S6——索引 id 曾达 done/superseded 被改回非终态即
#        STALE 指名票 id 与跃迁方向，终态史取 Git 基线）：套件登记数期望随动（未点亮
#        3→4、全点亮 5→6）＋S6 正负例四（终态索引照旧→exit 0；done→in_progress→
#        STALE 指名票 id 与跃迁方向；superseded→ready 同款；非终态流转零误报，终态史
#        经 git init 基线提交承载）；票 152 open 本体 schema 全量校验（type/pattern/enum/
#        oneOf/additionalProperties/条件 required 依 schema 执行）：ticket-ops 套件九例
#        随动——正例二（最小 task 本体／request 本体各 exit 0 索引落条目，合法面零回归）
#        ＋负例七（id 越 pattern／complexity 越枚举／profile 越七维 pattern／blocked_by
#        条目越 pattern／额外字段／task 缺条件 required／verification oneOf 零命中，均
#        exit 1 零写入且报文指名字段路径）；票 146（升级对账条件产物两源证据：快道证据＝
#        delivery.rules 在场或快道专属脚本已装，多门控共享脚本不点亮快道——P6 票务道
#        共享脚本安装不点亮→N/A exit 0；N6 快道专属脚本已装缺配置→落后 exit 1；夹具
#        install-policy 补 ticket-ops 门控与 generate-progress.sh 双门控行）；票 145（规则表非执行式解析门禁：三引擎
#        generate-module-map.sh/check-package.sh/install.sh 去 source 改纯文本解析，
#        恶意输入——命令替换、反引号、重定向、未知指令、字段污染——统一 fail-closed：
#        module-map 套件补恶意负例 N4～N6（rc=2 零地图写入），check-package 套件补
#        N24～N27（rc=2 不产生部分结论），新增 install 套件（正例安装全链＋恶意夹具
#        N1～N5 rc=2 零写入＋幂等跳过）并在 README 声明）；票 195 规则块格式校验与索引
#        序言收敛（检查 21→23——22＝规则块九字段格式（Level 受控四值/七字段齐备/块 ID
#        全局唯一）、23＝索引节序言短指针（三宿主 §16 序言逐字等于 governance-format.md
#        R-GF-011 定稿原句），check-package 套件金样串两形态计数 21→23 随动并补正例 P2
#        三宿主序言断言＋负例 N34～N39）；票 196 新增 role-prompt 套件（角色合同/Prompt
#        权威边界：四件角色合同模板权威面正例＋三件 Prompt 零合同正文扫描＋Triage 模板
#        登记闭合＋占位符零漂移正例；duplicate-body Prompt/duplicate-rule/
#        missing-permission/缺权限声明四负例均指名角色，夹具全 mktemp）；票 198
#        ticket-ops 套件增七维 Profile reason 存储合同断言十一项（合同单源 schema
#        profile_reason 恰七键＋协议存储合同与 verification reason 分立声明两正例、
#        七键齐读取面通过正例、malformed 读取面四负例指名键、存量票无 reason 读取兼容
#        正例、open 缺/invalid 拒零写入两负例＋valid 正开落地正例；夹具全 mktemp）。
#        票 252 新增 role-permissions 套件（门禁角色归属只按 checkpoint 节点判定：
#        dispatch-only 改写 exit 0、新建＋跨角色混合批仍 exit 1、单独新建件 exit 0，
#        另含三类既有拒绝路径与全部仓侧夹具逐件回归）。票 263 新增 dir-readme 套件
#        （目录 README 四段式契约校验正负例：成员表「成员／文件／名字」整格表头、
#        计数句九形态含 `N 行`（排除「一行」「第 N 行」）／合同件数／成员文件票、子目录
#        表头分隔行、正文提及词与普通两列表非成员表正例，失败按夹具断言 `文件:行` 行号）。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；套件在子 shell 内运行，断言经
#         $T/journal.<name> 回传父进程计数，套件内 exit/超时不再吞掉已产出断言与整轮汇总；
#         夹具全部构建于 mktemp 临时目录并 trap 清理（异常退出亦清）；被测对象只读零改动，
#         真实仓库零写入。
# Pos: 记录层共享回归 harness（票 49 沉淀，产品自检工具随包分发）：缺省自测同目录包内
#      脚本（check-package.sh 同款路径惯例），--script-dir/--pkg-root 参数化支持复制落位
#      语境；套件集合以本文件 `ALL_SUITES` 唯一枚举为准（启动时逐名核对套件函数在位、
#      `FAST_SUITES` 为短套件子集，成员历次随票扩）＋完整运行（--suite all）末尾注入自检；
#      安装面收敛后新增 docs-generation（规则索引生成器回归）与 governance-size（安装面预算回归）；票 233 新增 project-dashboard 套件（本地项目仪表盘：Node 抽取运行页面核心逻辑，缺 node 即 exit 2；静态零写入/零网络面与安装闭包真跑）；票 234 新增 ticket-audit 套件（证据审计引擎十一谓词：正例三操作面 conformant 与证据位置可追溯，负例/未知分支逐谓词分离，零写入断言以 cksum 与 HEAD 前后比对承载）；新增 context-cost 套件（成本治理度量：合成 wire.jsonl 夹具、基线逐项差值、样本不足 fail-closed 零 stdout、治理体积与每阶段读取集差值）；票 236 新增 ticket-repair 套件（repair 四类纠偏动作：补站/派生投影/禁 main 直提/Review 收据在场，终态与不合口径分支 fail-closed，站与投影外零写入）；票 258 执行模型硬化与快慢分层（ALL_SUITES 唯一枚举＋FAST_SUITES 短车道、per-suite 超时 TEST_SUITE_TIMEOUT 缺省 300s、子 shell 隔离、INT/TERM 清理后 exit 130、断言数下限 ASSERTION_FLOOR=1100、self-check 扩到四目标；新增 suite-harness 常驻覆盖四条负例）；票 269 新增 runtime-closure 套件（六运行脚本运行时依赖只认安装闭包：静态零工作树回退扫描、本地闭包与包工作树副本分歧时以本地为准、五入口闭包缺失 fail-closed 零写入、checkpoint-recovery 邻接 references/ 缺失 fail-closed）；POSIX sh 零外部
#      依赖（夹具 git init/commit 依赖被测脚本自身声明的 Git；self-check 中断负例经 python3 重置 SIGINT 处置）。用法、suite 覆盖表、退出码
#      与维护规则见同目录 README.md 专节。

set -u
set -f  # 关闭文件名展开：脚本不依赖 glob
TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2

# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/test-helpers.sh"
TEST_RECORD_SOURCE_ONLY=1
export TEST_RECORD_SOURCE_ONLY
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-module-map.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-ticket-ops.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-progress.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-json-engine.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-check-package.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-append-only.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-check-artifacts.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-delivery-parser.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-stale-claims.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-absorption.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-health.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-shellcheck.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-lane-commit.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-ledger-append.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-checkpoint-write.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 272）
. "$TESTS_DIR/suite-record-store.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-worktree.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-upgrade-check.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-install.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-authority-matrix.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-dispatch-contract.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-workflow-contract.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/suite-role-prompt.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 252）
. "$TESTS_DIR/suite-role-permissions.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员）
. "$TESTS_DIR/suite-ticket-run.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 236）
. "$TESTS_DIR/suite-ticket-repair.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 233）
. "$TESTS_DIR/suite-project-dashboard.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 245）
. "$TESTS_DIR/suite-check-gates.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，规则索引生成器回归）
. "$TESTS_DIR/suite-docs-generation.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，安装面预算回归）
. "$TESTS_DIR/suite-governance-size.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，证据审计回归）
. "$TESTS_DIR/suite-ticket-audit.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，合并站证据门回归）
. "$TESTS_DIR/suite-merge.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，记录提交单点入口回归，票 288）
. "$TESTS_DIR/suite-record-commit.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，审查证据重绑授权回归，票 288）
. "$TESTS_DIR/suite-evidence-rebind.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，成本度量回归）
. "$TESTS_DIR/suite-context-cost.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，目录 README 结构契约回归）
. "$TESTS_DIR/suite-dir-readme.sh"
# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，运行时依赖只认安装闭包回归，票 269）
. "$TESTS_DIR/suite-runtime-closure.sh"

# shellcheck disable=SC1091  # 对抗金丝雀（票 241）
. "$TESTS_DIR/suite-adversarial.sh"

# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，harness 自身硬化回归，票 258）
. "$TESTS_DIR/suite-harness.sh"


SUITE='all'
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
PKG_ROOT=''

# ---- 套件名单（唯一枚举；--suite all 的执行顺序）----
ALL_SUITES='module-map ticket-ops progress json-engine check-package append-only check-artifacts delivery-parser stale-claims lane-commit ledger-append checkpoint-write record-store authority-matrix worktree upgrade-check absorption health shellcheck install dispatch-contract workflow-contract role-prompt role-permissions ticket-run ticket-repair project-dashboard check-gates docs-generation governance-size ticket-audit merge record-commit evidence-rebind context-cost dir-readme runtime-closure adversarial harness'
# ---- fast 车道（票 258）：ALL_SUITES 的短套件子集，日常回归目标 ≤180s。重活
#      （ticket-ops 全量、ticket-audit、lane-commit、check-package、install、workflow-contract
#      等）留给 --suite all；成员是否 ⊆ all 由启动核对与 self-check 双向钉死 ----
FAST_SUITES='module-map progress json-engine append-only check-artifacts delivery-parser stale-claims ledger-append checkpoint-write record-store authority-matrix worktree upgrade-check absorption health role-permissions check-gates docs-generation governance-size context-cost ticket-repair dispatch-contract role-prompt dir-readme adversarial ticket-run'

suite_listed() {
  case " $ALL_SUITES " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

suite_fn() {
  printf 'suite_%s\n' "$(printf '%s' "$1" | tr '-' '_')"
}

usage() {
  cat <<'USAGE'
用法: sh test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
参数:
    --suite <name>      module-map | ticket-ops | progress | json-engine | check-package | append-only | check-artifacts | delivery-parser | stale-claims | lane-commit | ledger-append | checkpoint-write | record-store | authority-matrix | worktree | upgrade-check | absorption | health | shellcheck | install | dispatch-contract | workflow-contract | role-prompt | role-permissions | ticket-run | ticket-repair | project-dashboard | check-gates | docs-generation | governance-size | ticket-audit | merge | record-commit | evidence-rebind | context-cost | dir-readme | runtime-closure | adversarial | harness | fast | all（缺省 all；fast＝⊆all 的短套件子集，日常回归 ≤180s）
  --script-dir <dir>  被测脚本所在目录（须含八件被测成员）；缺省＝本脚本所在目录（缺省自测同目录）
  --pkg-root <dir>    check-package 套件的包根；缺省＝script-dir 的上一级（check-package.sh 同款）
  -h / --help         打印本用法
环境变量:
    TEST_SUITE_TIMEOUT   单套件超时秒数（缺省 900；check-package 等重套件实测 400–600s，
                         缺省 300 会误判超时——超时机制保留，仅放宽默认值可覆盖）；超时记
                         FAIL 行、继续后续套件、整轮 exit 1
    TEST_ASSERTION_FLOOR 断言数下限；缺省仅 --suite all 生效（1100）；显式设置时对任意车道生效
退出码: 0 全部断言通过；1 存在失败断言（逐项 FAIL 行见输出）；2 用法或环境错误；130 收到 INT/TERM（清理后退出）
suite 覆盖场景表与维护规则见同目录 README.md 专节。
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --suite) [ $# -ge 2 ] || { usage >&2; exit 2; }; SUITE=$2; shift 2 ;;
    --script-dir) [ $# -ge 2 ] || { usage >&2; exit 2; }; SCRIPT_DIR=$2; shift 2 ;;
    --pkg-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; PKG_ROOT=$2; shift 2 ;;
    *) printf 'test-record-layer: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
case $SUITE in
  all|fast) ;;
  *)
    suite_listed "$SUITE" || {
      printf 'test-record-layer: --suite 不合口径: %s\n' "$SUITE" >&2
      usage >&2
      exit 2
    }
    ;;
esac
# 名单↔函数↔子集三向启动核对（suite 文件名约定 suite-<name>.sh，函数名 - 换 _）
for _s in $ALL_SUITES; do
  command -v "$(suite_fn "$_s")" >/dev/null 2>&1 || {
    printf 'test-record-layer: 套件函数缺失: %s（须有同目录 suite-%s.sh）\n' "$(suite_fn "$_s")" "$_s" >&2
    exit 2
  }
done
for _s in $FAST_SUITES; do
  suite_listed "$_s" || {
    printf 'test-record-layer: FAST_SUITES 成员不在 ALL_SUITES 内: %s\n' "$_s" >&2
    exit 2
  }
done
[ -d "$SCRIPT_DIR" ] || { printf 'test-record-layer: 被测脚本目录不存在: %s\n' "$SCRIPT_DIR" >&2; exit 2; }
for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh worktree-add.sh dp-load-rules.sh; do
  [ -f "$SCRIPT_DIR/$f" ] || { printf 'test-record-layer: 被测成员缺失: %s/%s\n' "$SCRIPT_DIR" "$f" >&2; exit 2; }
done
if [ -z "$PKG_ROOT" ]; then
  PKG_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd) || exit 2
fi
[ -d "$PKG_ROOT" ] || { printf 'test-record-layer: 包根不存在: %s\n' "$PKG_ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'test-record-layer: git 不可用——module-map/ticket-ops 夹具依赖被测脚本声明的 Git\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'test-record-layer: python3 不可用——ticket-ops 套件 open 本体 schema 校验依赖（票 79）\n' >&2; exit 2; }

# ---- 计数与输出 ----

TOTAL=0
FAILS=0
# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
SUITE_FAILS=0
# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
CUR_SUITE=''
# 当前套件的结果日志（子 shell 内 ok/bad 写入，父进程按行汇总）
CUR_JOURNAL=''
CURRENT_CHILD=''

# ---- 断言数下限（票 258 AC5）----
# 缺省只对 --suite all 生效（1100＝票 257 收口后的实跑基线）；显式设置时对任意车道生效，
# 供 harness 套件与门禁做「跌破即 FAIL」负例。
ASSERTION_FLOOR=1100
ASSERTION_FLOOR_EXPLICIT=0
if [ -n "${TEST_ASSERTION_FLOOR:-}" ]; then
  case $TEST_ASSERTION_FLOOR in
    *[!0-9]*)
      printf 'test-record-layer: TEST_ASSERTION_FLOOR 须为非负整数: %s\n' "$TEST_ASSERTION_FLOOR" >&2
      exit 2
      ;;
  esac
  ASSERTION_FLOOR=$TEST_ASSERTION_FLOOR
  ASSERTION_FLOOR_EXPLICIT=1
fi

# ---- 单套件超时（票 258 AC1；票 285 放宽默认值）----
# macOS 无 timeout(1)：后台 pid＋kill -0 轮询，超时先 TERM 后 KILL；零新依赖。
# 缺省 900s：check-package 与其它重套件实测 400–600s，缺省 300 在门禁 4（--suite all）
# 造成超时误判；只放宽默认值，超时机制与 TEST_SUITE_TIMEOUT 覆盖语义不变。
SUITE_TIMEOUT=900
if [ -n "${TEST_SUITE_TIMEOUT:-}" ]; then
  case $TEST_SUITE_TIMEOUT in
    ''|*[!0-9]*)
      printf 'test-record-layer: TEST_SUITE_TIMEOUT 须为正整数: %s\n' "$TEST_SUITE_TIMEOUT" >&2
      exit 2
      ;;
  esac
  SUITE_TIMEOUT=$TEST_SUITE_TIMEOUT
fi
[ "$SUITE_TIMEOUT" -ge 1 ] || { printf 'test-record-layer: TEST_SUITE_TIMEOUT 须 ≥1: %s\n' "$SUITE_TIMEOUT" >&2; exit 2; }

# ---- 临时目录与清理（票 11/26 纪律：异常退出路径也清；票 258 中断路径 exit 130）----

T=''
trap cleanup EXIT
trap 'on_signal INT 130' INT
trap 'on_signal TERM 130' TERM
trap 'on_signal HUP 129' HUP
# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
T=$(mktemp -d "${TMPDIR:-/tmp}/test-record-layer.XXXXXX") || exit 2

# ---- 被测脚本只读副本定位（harness 永不改写被测对象）----

# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
MM="$SCRIPT_DIR/generate-module-map.sh"

# ---- 套件执行：子 shell 隔离＋per-suite 超时＋结果日志回传（票 258 AC1/AC2）----

run_suite() {
  # $1=套件名 $2=套件函数
  # 套件在子 shell 里跑：套件内 exit 只终止本套件，不回卷父进程；断言计数经
  # $T/journal.<name> 回传（ok/bad 各写一行），父进程按日志行数累加 TOTAL/FAILS。
  _rs_name=$1
  _rs_fn=$2
  CUR_SUITE=$_rs_name
  _rs_journal="$T/journal.$_rs_name"
  CUR_JOURNAL=$_rs_journal
  : >"$_rs_journal"
  _rs_start=$(date +%s)
  _rs_now=$_rs_start
  ( "$_rs_fn" ) &
  CURRENT_CHILD=$!
  _rs_timedout=0
  _rs_ticks=0
  while kill -0 "$CURRENT_CHILD" 2>/dev/null; do
    _rs_now=$(date +%s)
    if [ $((_rs_now - _rs_start)) -ge "$SUITE_TIMEOUT" ]; then
      _rs_timedout=1
      kill -TERM "$CURRENT_CHILD" 2>/dev/null
      sleep 0.2
      kill -KILL "$CURRENT_CHILD" 2>/dev/null
      break
    fi
    # 短套件高频轮询、长套件降频：不给快套件加固定等待，也不给长套件空转
    if [ "$_rs_ticks" -lt 40 ]; then
      sleep 0.05
    else
      sleep 0.5
    fi
    _rs_ticks=$((_rs_ticks + 1))
  done
  wait "$CURRENT_CHILD"
  _rs_rc=$?
  CURRENT_CHILD=''
  _rs_end=$(date +%s)
  _rs_secs=$((_rs_end - _rs_start))
  _rs_total=$(wc -l <"$_rs_journal" | tr -d ' ')
  _rs_fails=$(grep -c '^FAIL' "$_rs_journal" 2>/dev/null || true)
  [ -n "$_rs_fails" ] || _rs_fails=0
  TOTAL=$((TOTAL + _rs_total))
  FAILS=$((FAILS + _rs_fails))
  if [ "$_rs_timedout" -eq 1 ]; then
    CUR_JOURNAL=''
    bad "套件超时（上限 ${SUITE_TIMEOUT}s，TEST_SUITE_TIMEOUT 可覆盖）→ 终止本套件并继续后续" \
      "超时前已记录 ${_rs_total} 项断言（${_rs_fails} 失败）"
    _rs_total=$((_rs_total + 1))
    _rs_fails=$((_rs_fails + 1))
  elif [ "$_rs_rc" -ne 0 ]; then
    CUR_JOURNAL=''
    bad "套件提前退出（exit ${_rs_rc}）→ 子 shell 隔离，后续套件照跑并出汇总" \
      "退出前已记录 ${_rs_total} 项断言（${_rs_fails} 失败）"
    _rs_total=$((_rs_total + 1))
    _rs_fails=$((_rs_fails + 1))
  fi
  if [ ! -f "$_rs_journal.summary" ]; then
    if [ "$_rs_fails" -eq 0 ]; then
      printf 'test-record-layer: [%s] 断言 %d/%d 通过\n' "$_rs_name" "$_rs_total" "$_rs_total"
    else
      printf 'test-record-layer: [%s] 断言 %d/%d 通过（%d 失败；套件未产出汇总行）\n' \
        "$_rs_name" "$((_rs_total - _rs_fails))" "$_rs_total" "$_rs_fails"
    fi
  fi
  printf 'test-record-layer: [%s] 用时 %ss\n' "$_rs_name" "$_rs_secs"
  # shellcheck disable=SC2034  # 由下一次 run_suite 重置（单文件视野误报）
  CUR_JOURNAL=''
}

dispatch_suite() {
  case $SUITE in
    all)
      for _d in $ALL_SUITES; do
        run_suite "$_d" "$(suite_fn "$_d")"
      done
      run_suite self-check self_check_injection
      ;;
    fast)
      for _d in $FAST_SUITES; do
        run_suite "$_d" "$(suite_fn "$_d")"
      done
      ;;
    *)
      run_suite "$SUITE" "$(suite_fn "$SUITE")"
      ;;
  esac
}

printf 'test-record-layer: suite=%s scripts=%s pkg-root=%s timeout=%ss tmp=%s\n' \
  "$SUITE" "$SCRIPT_DIR" "$PKG_ROOT" "$SUITE_TIMEOUT" "$T"

dispatch_suite

# ---- 断言数下限（票 258 AC5）：跌破即 FAIL，不允许静默跳过后报绿 ----
if [ "$SUITE" = 'all' ] || [ "$ASSERTION_FLOOR_EXPLICIT" -eq 1 ]; then
  if [ "$TOTAL" -lt "$ASSERTION_FLOOR" ]; then
    # shellcheck disable=SC2034  # 由 bad 打印使用（单文件视野误报）
    CUR_SUITE='floor'
    bad "断言数下限：实跑 ${TOTAL} ≥ ${ASSERTION_FLOOR}" \
      '断言数跌破下限——套件被跳过、断言被删或超时截断（下限可经 TEST_ASSERTION_FLOOR 覆盖）'
  fi
fi

if [ "$FAILS" -eq 0 ]; then
  printf 'test-record-layer: PASS（共 %d 项断言，全部通过）\n' "$TOTAL"
  exit 0
fi
printf 'test-record-layer: FAIL（共 %d 项断言，%d 项失败）\n' "$TOTAL" "$FAILS"
exit 1
