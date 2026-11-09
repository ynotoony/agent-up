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
#      与维护规则见包内 scripts/README.md「test-record-layer.sh」专节。
#      并行能力（票 292）：--jobs <n>／TEST_RUNNER_JOBS 控制并行度（缺省 auto＝按套件声明的
#      worker 数，--jobs 1 回退既有串行）；声明 worker 的套件（suite_<fn>_worker_count）由
#      runner 分波并行执行、per-worker 独立 journal 与输出捕获，按 worker 序号保序回放并
#      合并为单条套件汇总（断言行顺序与串行输出逐字一致）；栅栏套件经 suite_<fn>_gate 回退串行。

set -u
set -f  # 关闭文件名展开：脚本不依赖 glob
TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2

# shellcheck disable=SC1091  # 套件文件路径由 TESTS_DIR 动态组装（同目录约定成员，票 161）
. "$TESTS_DIR/test-helpers.sh"
TEST_RECORD_SOURCE_ONLY=1
export TEST_RECORD_SOURCE_ONLY
# 公共 fixture builder（票 291）：tests/test-world.sh 由本 runner 统一 source，套件只调用不复制。
# shellcheck disable=SC1091  # 公共夹具库路径由 TESTS_DIR 动态组装（同目录约定成员）
. "$TESTS_DIR/test-world.sh"

# ---- 套件名单（唯一枚举；ALL_SUITES 恰此一处，source／派发／用法／孤儿校验均读本变量）----
ALL_SUITES='module-map ticket-ops ticket-ops-locks progress json-engine check-package check-package-groups check-package-direct append-only check-artifacts delivery-parser stale-claims lane-commit lane-commit-boundary lane-commit-record ledger-append checkpoint-write record-store authority-matrix worktree upgrade-check absorption health shellcheck install dispatch-contract workflow-contract workflow-trust workflow-recovery role-prompt role-permissions ticket-run ticket-repair project-dashboard check-gates docs-generation governance-size ticket-audit merge record-commit evidence-rebind ticket-split context-cost dir-readme dir-readme-migrate dir-readme-freshness runtime-closure adversarial harness'
# ---- fast 车道（票 258）：ALL_SUITES 的短套件子集，日常回归目标 ≤180s。重活留给
#      --suite all；成员是否 ⊆ all 由启动核对与 self-check 双向钉死 ----
FAST_SUITES='module-map progress json-engine append-only check-artifacts delivery-parser stale-claims ledger-append checkpoint-write record-store authority-matrix worktree upgrade-check absorption health role-permissions check-gates docs-generation governance-size context-cost ticket-repair dispatch-contract role-prompt dir-readme adversarial ticket-run'
# ---- 套件家族批（票 292 并行能力与票 291 结构整合）：ALL_SUITES 内的一组成员在
#      --suite all（及显式请求家族代表名）时按家族顺序并行执行——每成员保留自有
#      journal/日志，父进程保序回放并逐成员打印其汇总与用时行（与串行输出同形）；
#      成员须同在 ALL_SUITES 内（启动核对 fail-closed）；缺省 auto＝成员数，--jobs 覆盖。
PARALLEL_FAMILY_LEAD='check-package'
PARALLEL_FAMILY='check-package check-package-groups check-package-direct'


# 套件文件按名单动态 source（名单单一来源；孤儿文件在下方磁盘校验中 fail-closed）
for _s in $ALL_SUITES; do
  _suite_file="$TESTS_DIR/suite-$_s.sh"
  [ -f "$_suite_file" ] || { printf 'test-record-layer: 套件文件缺失: %s\n' "$_suite_file" >&2; exit 2; }
  # shellcheck disable=SC1090,SC1091  # 套件文件按 ALL_SUITES 动态组装（同目录约定成员），非字面量 source
  . "$_suite_file" || { printf 'test-record-layer: 套件载入失败: %s\n' "$_suite_file" >&2; exit 2; }
done

# ---- 磁盘孤儿校验（票 291）：tests/suite-*.sh 集合必须与 ALL_SUITES 双向相等 ----
# 磁盘多出未登记 suite-*.sh ＝ 孤儿套件（永远不会被派发），fail-closed；名单有而磁盘缺
# 已在上面 source 循环逐个指名。零外部依赖：用内层循环比对，不依赖 comm 临时文件。
_disk_suites=$(find "$TESTS_DIR" -maxdepth 1 -name 'suite-*.sh' -print | sed 's|.*/suite-||; s|\.sh$||')
_orphans=''
for _d in $_disk_suites; do
  case " $ALL_SUITES " in
    *" $_d "*) ;;
    *) _orphans="$_orphans $_d" ;;
  esac
done
if [ -n "$_orphans" ]; then
  printf 'test-record-layer: 孤儿套件（磁盘有而 ALL_SUITES 未登记，永不派发）:%s\n' "$_orphans" >&2
  printf 'test-record-layer: 请把套件登记进 ALL_SUITES（唯一清单）或删除该 suite-*.sh\n' >&2
  exit 2
fi


SUITE='all'
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd) || exit 2
PKG_ROOT=''
# 并行度（票 292）：0＝auto（按套件声明的 worker 数）；>=1＝并行上限；--jobs 1 串行。
# 初值必须在参数解析前设定，否则会覆盖已解析的 --jobs。
JOBS=0


suite_listed() {
  case " $ALL_SUITES " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

suite_fn() {
  printf 'suite_%s\n' "$(printf '%s' "$1" | tr '-' '_')"
}

suite_worker_count() {
  # 套件声明的 worker 数（票 292）：suite_<fn>_worker_count 未定义＝1（串行）。
  _swc_fn=$(suite_fn "$1")_worker_count
  if ! command -v "$_swc_fn" >/dev/null 2>&1; then
    printf '1'
    return 0
  fi
  "$_swc_fn"
}

in_family() {
  case " $PARALLEL_FAMILY " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

family_members() {
  # 输出家族成员（ALL_SUITES 顺序子集；仅打印实际在册者）
  for _fm in $ALL_SUITES; do
    in_family "$_fm" && printf '%s ' "$_fm"
  done
}

usage() {
  _usage_suites=$(printf '%s' "$ALL_SUITES" | tr ' ' '|')
  cat <<'USAGE' | sed "s#@ALL_SUITES@#$_usage_suites#"
用法: sh test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
参数:
    --suite <name>      @ALL_SUITES@ | fast | all（缺省 all；fast＝⊆all 的短套件子集，日常回归 ≤180s）
  --script-dir <dir>  被测脚本所在目录（须含 package-manifest scripts 节登记的被测成员）；缺省＝本脚本所在目录（缺省自测同目录）
  --pkg-root <dir>    check-package 套件的包根；缺省＝script-dir 的上一级（check-package.sh 同款）
  --jobs <n>          并行度：套件声明 worker 时的并行上限；缺省 auto（＝该套件 worker 数），
                      --jobs 1 回退串行（既有行为逐行不变）；未声明 worker 的套件始终串行
  -h / --help         打印本用法
环境变量:
    TEST_SUITE_TIMEOUT   单套件超时秒数（缺省 900；check-package 等重套件实测 400–600s，
                         缺省 300 会误判超时——超时机制保留，仅放宽默认值可覆盖）；超时记
                         FAIL 行、继续后续套件、整轮 exit 1
    TEST_ASSERTION_FLOOR 断言数下限；缺省仅 --suite all 生效（1100）；显式设置时对任意车道生效
    TEST_RUNNER_JOBS     并行度（同 --jobs；整型 ≥1；缺省 auto＝按套件声明 worker 数）
退出码: 0 全部断言通过；1 存在失败断言（逐项 FAIL 行见输出）；2 用法或环境错误；130 收到 INT/TERM（清理后退出）
suite 覆盖场景表与维护规则见包内 scripts/README.md「test-record-layer.sh」专节。
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --suite) [ $# -ge 2 ] || { usage >&2; exit 2; }; SUITE=$2; shift 2 ;;
    --script-dir) [ $# -ge 2 ] || { usage >&2; exit 2; }; SCRIPT_DIR=$2; shift 2 ;;
    --pkg-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; PKG_ROOT=$2; shift 2 ;;
    --jobs)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      case $2 in
        ''|*[!0-9]*|0)
          printf 'test-record-layer: --jobs 须为整数 >=1: %s\n' "$2" >&2
          exit 2
          ;;
      esac
      JOBS=$2
      shift 2
      ;;
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
for _s in $(family_members); do
  in_family "$_s" || { printf 'test-record-layer: 家族成员校验异常: %s\n' "$_s" >&2; exit 2; }
done
for _s in $PARALLEL_FAMILY; do
  suite_listed "$_s" || {
    printf 'test-record-layer: PARALLEL_FAMILY 成员不在 ALL_SUITES 内: %s\n' "$_s" >&2
    exit 2
  }
done
[ -d "$SCRIPT_DIR" ] || { printf 'test-record-layer: 被测脚本目录不存在: %s\n' "$SCRIPT_DIR" >&2; exit 2; }
if [ -z "$PKG_ROOT" ]; then
  PKG_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd) || exit 2
fi

# ---- 并行度（票 292）：env 仅在未显式给 --jobs 时生效 ----
if [ -n "${TEST_RUNNER_JOBS:-}" ] && [ "$JOBS" -eq 0 ]; then
  case $TEST_RUNNER_JOBS in
    ''|*[!0-9]*)
      printf 'test-record-layer: TEST_RUNNER_JOBS 须为整数 >=1: %s\n' "$TEST_RUNNER_JOBS" >&2
      exit 2
      ;;
  esac
  JOBS=$TEST_RUNNER_JOBS
fi
case $JOBS in
  ''|*[!0-9]*)
    printf 'test-record-layer: --jobs 须为整数 >=1: %s\n' "$JOBS" >&2
    exit 2
    ;;
esac
if [ "$JOBS" -ne 0 ] && [ "$JOBS" -lt 1 ]; then
  printf 'test-record-layer: --jobs 须为整数 >=1: %s\n' "$JOBS" >&2
  exit 2
fi
[ -d "$PKG_ROOT" ] || { printf 'test-record-layer: 包根不存在: %s\n' "$PKG_ROOT" >&2; exit 2; }
# 被测成员清单权威＝package-manifest.rules scripts 节（票 291：取消 runner 内硬编码清单与
# 清单文件的双源；下方 REQUIRED_MEMBERS 只列本 harness 的运行前提，登记存在性以 manifest 为准）。
REQUIRED_MEMBERS='generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh worktree-add.sh dp-load-rules.sh'
_tm_manifest="$PKG_ROOT/scripts/package-manifest.rules"
[ -f "$_tm_manifest" ] || { printf 'test-record-layer: 包清单缺失（被测成员登记权威）: %s\n' "$_tm_manifest" >&2; exit 2; }
for f in $REQUIRED_MEMBERS; do
  # 引擎自身（check-package.sh）与闭合白名单同口径：不在 pm_script 登记，单列例外。
  if [ "$f" != 'check-package.sh' ]; then
    LC_ALL=C grep -q "^pm_script scripts/$f " "$_tm_manifest" || {
      printf 'test-record-layer: 被测成员未在 package-manifest scripts 节登记: %s\n' "$f" >&2; exit 2
    }
  fi
  [ -f "$SCRIPT_DIR/$f" ] || { printf 'test-record-layer: 被测成员缺失: %s/%s\n' "$SCRIPT_DIR" "$f" >&2; exit 2; }
done
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
# 并行 worker 组 pid 列表（票 292；中断路径经 test-helpers.sh on_signal 逐个停止）
# shellcheck disable=SC2034  # 由 test-helpers.sh on_signal 消费（跨件视野误报）
CURRENT_CHILDREN=''

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

# ---- 多 worker 套件：分波并行＋per-worker journal＋保序回放＋单条汇总（票 292）----

run_suite_group() {
  # $1=套件名 $2=worker 数
  # 每个 worker：独立 $T/journal.<name>.wN 与 $T/group.<name>/wN.log（零共享临时文件；
  # worker 内部另用 $T/cpkg.wN 作为自己的夹具根）；父进程按 worker 序号 wait 后回放日志，
  # 顺序与声明序一致，断言行与串行输出逐字相同；最后只打印一条套件汇总与用时。
  _sg_name=$1
  _sg_count=$2
  CUR_SUITE=$_sg_name
  _sg_dir="$T/group.$_sg_name"
  mkdir -p "$_sg_dir" || exit 2
  _sg_conc=$JOBS
  if [ "$_sg_conc" -le 0 ]; then _sg_conc=$_sg_count; fi
  if [ "$_sg_conc" -gt "$_sg_count" ]; then _sg_conc=$_sg_count; fi
  _sg_start=$(date +%s)
  _sg_total=0
  _sg_fails=0
  _sg_timedout=0
  _sg_exit_bad=0
  _sg_badrc=0
  _sg_i=1
  while [ "$_sg_i" -le "$_sg_count" ]; do
    _sg_hi=$((_sg_i + _sg_conc - 1))
    if [ "$_sg_hi" -gt "$_sg_count" ]; then _sg_hi=$_sg_count; fi
    _sg_wave_pids=''
    _sg_wave_idx=''
    _sg_j=$_sg_i
    while [ "$_sg_j" -le "$_sg_hi" ]; do
      _sg_journal="$T/journal.$_sg_name.w$_sg_j"
      : >"$_sg_journal"
      CUR_JOURNAL=$_sg_journal
      CUR_SUITE=$_sg_name
      ( "$(suite_fn "$_sg_name")_w$_sg_j" ) >"$_sg_dir/w$_sg_j.log" 2>&1 &
      _sg_wave_pids="$_sg_wave_pids $!"
      _sg_wave_idx="$_sg_wave_idx $_sg_j"
      _sg_j=$((_sg_j + 1))
    done
    # shellcheck disable=SC2034  # 由 test-helpers.sh on_signal 消费（跨件视野误报）
    CURRENT_CHILDREN=$_sg_wave_pids
    _sg_running=1
    while [ "$_sg_running" -eq 1 ]; do
      _sg_running=0
      for _sg_p in $_sg_wave_pids; do
        if kill -0 "$_sg_p" 2>/dev/null; then
          _sg_running=1
          break
        fi
      done
      if [ "$_sg_running" -eq 0 ]; then
        break
      fi
      _sg_now=$(date +%s)
      if [ $((_sg_now - _sg_start)) -ge "$SUITE_TIMEOUT" ]; then
        _sg_timedout=1
        for _sg_p in $_sg_wave_pids; do
          kill -TERM "$_sg_p" 2>/dev/null
        done
        sleep 0.2
        for _sg_p in $_sg_wave_pids; do
          kill -KILL "$_sg_p" 2>/dev/null
        done
        break
      fi
      sleep 0.05
    done
    _sg_pids_tmp=$_sg_wave_pids
    _sg_idx_tmp=$_sg_wave_idx
    while [ -n "$_sg_pids_tmp" ]; do
      # shellcheck disable=SC2086  # 有意按空白分词为多参数（worker pid 列表，逐项 shift）
      set -- $_sg_pids_tmp
      _sg_p=$1
      shift
      _sg_pids_tmp=$*
      # shellcheck disable=SC2086  # 有意按空白分词为多参数（worker 序号列表，逐项 shift）
      set -- $_sg_idx_tmp
      _sg_k=$1
      shift
      _sg_idx_tmp=$*
      wait "$_sg_p" 2>/dev/null
      _sg_rc=$?
      cat "$_sg_dir/w$_sg_k.log"
      _sg_journal="$T/journal.$_sg_name.w$_sg_k"
      _sg_n=$(wc -l <"$_sg_journal" | tr -d ' ')
      _sg_f=$(grep -c '^FAIL' "$_sg_journal" 2>/dev/null || true)
      [ -n "$_sg_f" ] || _sg_f=0
      _sg_total=$((_sg_total + _sg_n))
      _sg_fails=$((_sg_fails + _sg_f))
      if [ "$_sg_rc" -ne 0 ] && [ "$_sg_timedout" -eq 0 ]; then
        _sg_exit_bad=1
        _sg_badrc=$_sg_rc
      fi
    done
    # shellcheck disable=SC2034  # 由 test-helpers.sh on_signal 消费（跨件视野误报）
    CURRENT_CHILDREN=''
    if [ "$_sg_timedout" -eq 1 ]; then
      break
    fi
    _sg_i=$((_sg_hi + 1))
  done
  _sg_end=$(date +%s)
  _sg_secs=$((_sg_end - _sg_start))
  TOTAL=$((TOTAL + _sg_total))
  FAILS=$((FAILS + _sg_fails))
  if [ "$_sg_timedout" -eq 1 ]; then
    CUR_JOURNAL=''
    bad "套件超时（上限 $SUITE_TIMEOUT s，TEST_SUITE_TIMEOUT 可覆盖）→ 终止本套件并继续后续" \
      "超时前已记录 $_sg_total 项断言（$_sg_fails 失败）"
    _sg_total=$((_sg_total + 1))
    _sg_fails=$((_sg_fails + 1))
  elif [ "$_sg_exit_bad" -eq 1 ]; then
    CUR_JOURNAL=''
    bad "套件提前退出（exit ${_sg_badrc}）→ 子 shell 隔离，后续套件照跑并出汇总" \
      "退出前已记录 $_sg_total 项断言（$_sg_fails 失败）"
    _sg_total=$((_sg_total + 1))
    _sg_fails=$((_sg_fails + 1))
  fi
  if [ "$_sg_fails" -eq 0 ]; then
    printf 'test-record-layer: [%s] 断言 %d/%d 通过\n' "$_sg_name" "$_sg_total" "$_sg_total"
  else
    printf 'test-record-layer: [%s] 断言 %d/%d 通过（%d 失败）\n' \
      "$_sg_name" "$((_sg_total - _sg_fails))" "$_sg_total" "$_sg_fails"
  fi
  printf 'test-record-layer: [%s] 用时 %ss\n' "$_sg_name" "$_sg_secs"
  # shellcheck disable=SC2034  # 由下一次调度重置（单文件视野误报）
  CUR_JOURNAL=''
}

# ---- 套件家族批：成员并行＋保序回放（票 292 并行能力 × 票 291 拆分结构）----

run_suite_family() {
  # $1=家族代表名（日志目录标识；成员集合取 family_members，顺序＝ALL_SUITES）
  # 每个成员作为一个独立任务在子 shell 内经 dispatch_one 执行（故成员内部的 worker 并行与
  # 栅栏回退口径完全复用），输出重定向到 $T/family.<lead>/<name>.log；父进程分波并发
  # （上限＝JOBS，缺省 auto＝成员数），按家族顺序 wait 后回放日志——各成员自身的
  # PASS/FAIL 行、汇总行与用时行原样保留，顺序与串行一致；TOTAL/FAILS 由回放日志中的
  # 断言行计数（不依赖跨进程 journal）。组超时先 TERM 后 KILL 全部成员任务。
  _ff_lead=$1
  _ff_members=$(family_members)
  _ff_dir="$T/family.$_ff_lead"
  mkdir -p "$_ff_dir" || exit 2
  _ff_start=$(date +%s)
  _ff_total=0
  _ff_fails=0
  _ff_timedout=0
  _ff_n=0
  for _ff_m in $_ff_members; do _ff_n=$((_ff_n + 1)); done
  _ff_conc=$JOBS
  if [ "$_ff_conc" -le 0 ]; then _ff_conc=$_ff_n; fi
  if [ "$_ff_conc" -gt "$_ff_n" ]; then _ff_conc=$_ff_n; fi
  _ff_i=1
  while [ "$_ff_i" -le "$_ff_n" ]; do
    _ff_hi=$((_ff_i + _ff_conc - 1))
    if [ "$_ff_hi" -gt "$_ff_n" ]; then _ff_hi=$_ff_n; fi
    _ff_pids=''
    _ff_names=''
    _ff_k=1
    for _ff_m in $_ff_members; do
      if [ "$_ff_k" -ge "$_ff_i" ] && [ "$_ff_k" -le "$_ff_hi" ]; then
        date +%s >"$_ff_dir/$_ff_m.start"
        ( dispatch_one "$_ff_m"; date +%s >"$_ff_dir/$_ff_m.end" ) >"$_ff_dir/$_ff_m.log" 2>&1 &
        _ff_pids="$_ff_pids $!"
        _ff_names="$_ff_names $_ff_m"
      fi
      _ff_k=$((_ff_k + 1))
    done
    # shellcheck disable=SC2034  # 由 test-helpers.sh on_signal 消费（跨件视野误报）
    CURRENT_CHILDREN=$_ff_pids
    _ff_running=1
    while [ "$_ff_running" -eq 1 ]; do
      _ff_running=0
      for _ff_p in $_ff_pids; do
        if kill -0 "$_ff_p" 2>/dev/null; then
          _ff_running=1
          break
        fi
      done
      if [ "$_ff_running" -eq 0 ]; then
        break
      fi
      _ff_now=$(date +%s)
      if [ $((_ff_now - _ff_start)) -ge "$SUITE_TIMEOUT" ]; then
        _ff_timedout=1
        for _ff_p in $_ff_pids; do
          kill -TERM "$_ff_p" 2>/dev/null
        done
        sleep 0.2
        for _ff_p in $_ff_pids; do
          kill -KILL "$_ff_p" 2>/dev/null
        done
        break
      fi
      sleep 0.05
    done
    _ff_pids_tmp=$_ff_pids
    _ff_names_tmp=$_ff_names
    while [ -n "$_ff_pids_tmp" ]; do
      # shellcheck disable=SC2086  # 有意按空白分词为多参数（成员 pid 列表，逐项 shift）
      set -- $_ff_pids_tmp
      _ff_p=$1
      shift
      _ff_pids_tmp=$*
      # shellcheck disable=SC2086  # 有意按空白分词为多参数（成员名列表，逐项 shift）
      set -- $_ff_names_tmp
      _ff_m=$1
      shift
      _ff_names_tmp=$*
      wait "$_ff_p" 2>/dev/null
      _ff_rc=$?
      cat "$_ff_dir/$_ff_m.log"
      _ff_p=$(grep -c '^PASS  \[' "$_ff_dir/$_ff_m.log" 2>/dev/null || true)
      [ -n "$_ff_p" ] || _ff_p=0
      _ff_f=$(grep -c '^FAIL  \[' "$_ff_dir/$_ff_m.log" 2>/dev/null || true)
      [ -n "$_ff_f" ] || _ff_f=0
      _ff_t=$((_ff_p + _ff_f))
      TOTAL=$((TOTAL + _ff_t))
      FAILS=$((FAILS + _ff_f))
      _ff_total=$((_ff_total + _ff_t))
      _ff_fails=$((_ff_fails + _ff_f))
      _ff_end=$(date +%s)
      if [ -f "$_ff_dir/$_ff_m.end" ]; then
        _ff_end=$(cat "$_ff_dir/$_ff_m.end")
      fi
      _ff_secs=0
      if [ -f "$_ff_dir/$_ff_m.start" ]; then
        _ff_secs=$((_ff_end - $(cat "$_ff_dir/$_ff_m.start")))
      fi
      # 回放日志须含该成员汇总行（run_suite／run_suite_group 自带；异常早退时按既有口径补）
      if ! grep -q "^test-record-layer: \[$_ff_m\] 断言" "$_ff_dir/$_ff_m.log" 2>/dev/null; then
        if [ "$_ff_f" -eq 0 ]; then
          printf 'test-record-layer: [%s] 断言 %d/%d 通过\n' "$_ff_m" "$_ff_t" "$_ff_t"
        else
          printf 'test-record-layer: [%s] 断言 %d/%d 通过（%d 失败；套件未产出汇总行）\n' \
            "$_ff_m" "$((_ff_t - _ff_f))" "$_ff_t" "$_ff_f"
        fi
        printf 'test-record-layer: [%s] 用时 %ss\n' "$_ff_m" "$_ff_secs"
      fi
      if [ "$_ff_rc" -ne 0 ] && [ "$_ff_timedout" -eq 0 ]; then
        _ff_exit_bad=1
        _ff_badrc=$_ff_rc
      fi
    done
    # shellcheck disable=SC2034  # 由 test-helpers.sh on_signal 消费（跨件视野误报）
    CURRENT_CHILDREN=''
    if [ "$_ff_timedout" -eq 1 ]; then
      break
    fi
    _ff_i=$((_ff_hi + 1))
  done
  if [ "$_ff_timedout" -eq 1 ]; then
    CUR_SUITE=$_ff_lead
    CUR_JOURNAL=''
    bad "套件超时（上限 $SUITE_TIMEOUT s，TEST_SUITE_TIMEOUT 可覆盖）→ 终止本套件并继续后续" \
      "超时前已记录 $_ff_total 项断言（$_ff_fails 失败）"
  fi
  # shellcheck disable=SC2034  # 由下一次调度重置（单文件视野误报）
  CUR_JOURNAL=''
}

# 单个套件调度：声明 worker 的走并行池（栅栏套件经 gate 回退串行），否则维持既有串行。
dispatch_one() {
  _do_count=$(suite_worker_count "$1")
  if [ "$_do_count" -gt 1 ]; then
    _do_gate=$(suite_fn "$1")_gate
    if command -v "$_do_gate" >/dev/null 2>&1 && "$_do_gate"; then
      run_suite "$1" "$(suite_fn "$1")"
    else
      run_suite_group "$1" "$_do_count"
    fi
  else
    run_suite "$1" "$(suite_fn "$1")"
  fi
}

dispatch_suite() {
  # 家族批（票 292×291 整合）：ALL_SUITES 中家族成员在代表名位置一次性并行执行并保序
  # 回放（成员各自的汇总/用时行保留）；其余成员在该轮跳过，不得重复执行。显式请求代表名
  # 同样走家族批（覆盖整个家族）；显式请求非代表成员仍只跑该成员（githooks 逐名调用口径）。
  case $SUITE in
    all)
      for _d in $ALL_SUITES; do
        if [ "$_d" = "$PARALLEL_FAMILY_LEAD" ]; then
          run_suite_family "$_d"
        elif in_family "$_d"; then
          continue
        else
          dispatch_one "$_d"
        fi
      done
      run_suite self-check self_check_injection
      ;;
    fast)
      for _d in $FAST_SUITES; do
        if [ "$_d" = "$PARALLEL_FAMILY_LEAD" ]; then
          run_suite_family "$_d"
        elif in_family "$_d"; then
          continue
        else
          dispatch_one "$_d"
        fi
      done
      ;;
    *)
      if [ "$SUITE" = "$PARALLEL_FAMILY_LEAD" ]; then
        run_suite_family "$SUITE"
      else
        dispatch_one "$SUITE"
      fi
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
