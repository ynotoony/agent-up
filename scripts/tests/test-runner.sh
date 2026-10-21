#!/bin/sh
# Input: 同目录被测脚本八件（generate-module-map.sh＋module-map.rules、ticket-ops.sh＋
#        generate-progress.sh、check-package.sh、check-append-only.sh、check-artifacts.sh、
#        check-stale-claims.sh、install.sh＋install-policy.rules）与参数：--suite/--script-dir/--pkg-root。
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
#        N1～N5 rc=2 零写入＋幂等跳过）并在 README 声明）。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；夹具全部构建于 mktemp 临时目录
#         并 trap 清理（异常退出亦清）；被测对象只读零改动，真实仓库零写入。
# Pos: 记录层共享回归 harness（票 49 沉淀，产品自检工具随包分发）：缺省自测同目录包内
#      脚本（check-package.sh 同款路径惯例），--script-dir/--pkg-root 参数化支持复制落位
#      语境；七 suite（module-map/ticket-ops/progress/check-package/append-only/
#      check-artifacts/stale-claims）＋完整运行（--suite all）末尾注入自检；POSIX sh 零外部
#      依赖（夹具 git init/commit 依赖被测脚本自身声明的 Git）。用法、suite 覆盖表、退出码
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
. "$TESTS_DIR/suite-json-helpers.sh"
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


SUITE='all'
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
PKG_ROOT=''

usage() {
  cat <<'USAGE'
用法: sh test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
参数:
    --suite <name>      module-map | ticket-ops | progress | check-package | append-only | check-artifacts | delivery-parser | stale-claims | lane-commit | authority-matrix | worktree | upgrade-check | absorption | health | install | dispatch-contract | workflow-contract | all（缺省 all）
  --script-dir <dir>  被测脚本所在目录（须含八件被测成员）；缺省＝本脚本所在目录（缺省自测同目录）
  --pkg-root <dir>    check-package 套件的包根；缺省＝script-dir 的上一级（check-package.sh 同款）
  -h / --help         打印本用法
退出码: 0 全部断言通过；1 存在失败断言（逐项 FAIL 行见输出）；2 用法或环境错误
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
  module-map|ticket-ops|progress|json-helpers|check-package|append-only|check-artifacts|delivery-parser|stale-claims|lane-commit|authority-matrix|worktree|upgrade-check|absorption|health|shellcheck|install|dispatch-contract|workflow-contract|all) ;;
  *) printf 'test-record-layer: --suite 不合口径: %s\n' "$SUITE" >&2; usage >&2; exit 2 ;;
esac
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
CUR_SUITE=''

# ---- 临时目录与清理（票 11/26 纪律：异常退出路径也清）----

T=''
trap cleanup EXIT HUP INT TERM
# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
T=$(mktemp -d "${TMPDIR:-/tmp}/test-record-layer.XXXXXX") || exit 2

# ---- 被测脚本只读副本定位（harness 永不改写被测对象）----

# shellcheck disable=SC2034  # 由 sourced 套件使用（单文件视野误报）
MM="$SCRIPT_DIR/generate-module-map.sh"

printf 'test-record-layer: suite=%s scripts=%s pkg-root=%s\n' "$SUITE" "$SCRIPT_DIR" "$PKG_ROOT"

case $SUITE in
  module-map) suite_module_map ;;
  ticket-ops) suite_ticket_ops ;;
  progress) suite_progress ;;
  json-helpers) suite_json_helpers ;;
  check-package) suite_check_package ;;
  append-only) suite_append_only ;;
  check-artifacts) suite_check_artifacts ;;
  delivery-parser) suite_delivery_parser ;;
  stale-claims) suite_stale_claims ;;
  lane-commit) suite_lane_commit ;;
  authority-matrix) suite_authority_matrix ;;



  worktree) suite_worktree ;;
  upgrade-check) suite_upgrade_check ;;
  absorption) suite_absorption ;;
  health) suite_health ;;
  shellcheck) suite_shellcheck ;;
  install) suite_install ;;
  dispatch-contract) suite_dispatch_contract ;;
  workflow-contract) suite_workflow_contract ;;
  all)
    suite_module_map
    suite_ticket_ops
    suite_progress
    suite_json_helpers
    suite_check_package
    suite_append_only
    suite_check_artifacts
    suite_delivery_parser
    suite_stale_claims
    suite_lane_commit
    suite_authority_matrix
    suite_worktree
    suite_upgrade_check
    suite_absorption
    suite_health
    suite_shellcheck
    suite_install
    suite_dispatch_contract
    suite_workflow_contract
    self_check_injection
    ;;
esac

if [ "$FAILS" -eq 0 ]; then
  printf 'test-record-layer: PASS（共 %d 项断言，全部通过）\n' "$TOTAL"
  exit 0
fi
printf 'test-record-layer: FAIL（共 %d 项断言，%d 项失败）\n' "$TOTAL" "$FAILS"
exit 1
