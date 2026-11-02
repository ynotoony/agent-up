#!/bin/sh
# Input: 子命令与参数（[repo-root] open/take/flip/close + 选项）与三个票务面数据载体：
#        facts/requirements/tickets/index.json（票状态真相源，单文件一条目一行，票 33 终裁 T2）、
#        facts/requirements/tickets/README.md 目录清单状态列（`任务票 <NN>；` 后首个反引号状态 token，
#        人工登记投影，票 37 口径）、facts/project/changes.jsonl 记录账本（键序
#        date,kind,scope,decision,evidence_ref，五键必备＋按 kind 条件键：lesson 必带
#        第六键 promoted_to、replan 必带 replan_original/replan_replacement/replan_undone
#        ——票 81，一行一事实，禁裸换行）。
# Output: 协调层票务面写入——index.json 票状态唯一写入方（写入方收敛票 228 F1/F2：
#         全仓 index.json 写入仅本件承载；lane-commit 快道索引翻转改调本件 flip-index
#         子命令代理，写索引→generate-progress 再生→--check 收尾链全仓仅本件一处）；
#         changes.jsonl 账本落行经同目录唯一写入方 ledger-append.sh 承载（票 228 F7：
#         行族形状校验与追加单点移出本件，写前预检经其 --check 零写入模式保持
#         fail-closed 时序）——open＝新票本体 ticket-record.schema.json 全量校验
#         （type/pattern/enum/oneOf/additionalProperties/条件 required 依 schema 文件
#         执行，票 152）＋理由非空断言（票 79，只 open 时点生效，存量零回扫）＋七维
#         profile reason 开票门（新 task 必备 profile_reason 对象且逐键非空，缺项/越键/
#         空白值即 fail-closed 零写入；存储合同单源＝schema profile_reason 属性与
#         references/protocol/complexity-profile.md §2.2，与 verification 的
#         record_only.reason 语义分立；读取面不要求本字段，存量零回扫）＋校验＋
#         索引新增条目（status=ready；空索引 {"issues": []} 就地展开落首条目）＋
#         README 追加目录清单行（`任务票 <NN>；` 锚点零命中方可追加，已在场即拒零写入）
#         ＋账本追加行；dispatch 派发合同数据节不在开票门内（开票不预填未来证据，
#         派发阶段由 contract-build.sh 做完整性门）；
#         take/flip＝索引 id 锚点整行替换（status+updated_at）＋README
#         状态 token 替换＋账本追加行；take 另做 blocked_by 领取完整性门（task 票本体
#         blocked_by 逐项须在索引登记且 status=done，缺失或未完成即 exit 1 指名 blocker
#         id 与其状态，零写入；request 无 blocked_by 不校验）；flip 至 done 另做 task 票
#         actual_time 收口硬拦（票 100：票 JSON 本体 actual_time 须已填且非空，缺项即
#         exit 1 指名票 id 与缺项；非 done 翻转不要求，request 不校验）＋ done 证据门
#         （票 237：调同目录 ticket-audit.sh --operation merge，只认 conformant；非
#         conformant/unknown 即 exit 1 报 decision-required 并零写入）＋账本追加行；
#         close＝done 收口入口（票 237，--id/--ledger-line 必选，status 固定 done）：
#         与 flip 至 done 同一条写入链与同一证据判定（actual_time＋审计双证），不留
#         自报旁路；
#         ledger＝无票账本行入口（票 100：不依赖 facts/requirements/tickets/index.json
#         条目 id，账本行形状校验先于写入，仅账本落行，不触索引/README/投影）；
#         flip-index＝索引单写代理（票 228：快道收尾 lane-commit 的索引条目翻转经此
#         承载——--id/--status/--updated-at 三项必选，锚点整行替换仅改 status/updated_at
#         两值＋投影再生＋--check 收尾；不触 README/账本/票本体，不落账本行；票 237
#         起目标 task 票 done 同口径要求 actual_time＋审计 conformant 双证）。
#         open/take/flip/close/flip-index 收尾调 rules/implementation/scripts/generate-progress.sh 再生 facts/requirements/tickets/progress-current.md
#         现役状态投影并 --check 核对（再生调用全仓仅本件承载；ledger 无索引面改动，
#         不做投影再生）。
# Pos: 协调层票务运维单入口脚本（票 41，用户 2026-09-20 裁决 2.1）；行为基线＝
#      development-process §6 零写入三段式第二段与 §12.5 票务脚本承载注记。POSIX sh、
#      零外部依赖（仅 POSIX 标准工具与内建，无 jq；票 79 起 open 本体 schema 校验另用
#      python3 标准库）；fail-closed：校验先于写入，
#      索引排版破坏、README 行缺失或锚点不唯一（含 open 锚点已存在——追加语义要求
#      零命中）、账本行不合键序、同 NN 异 slug 撞号
#      （票 77）即停止不写；收尾生成器
#      缺失或 --check 不过即整体失败退出非零，已写部分如实报告。运行时依赖定位（安装
#      闭包）：open 的 schema 权威与 json-validator.py 校验器先取包基线布局
#      （<repo-root>/agent-up/…），缺失回退安装布局（本脚本同目录及其 references/ 邻接
#      目录——安装器把脚本件落位 rules/implementation/scripts/、数据件落位
#      rules/implementation/references/）；两布局均未命中即报明双候选 fail-closed。
#      职责边界：只做票务面
#      写入，不执行门禁核对与 Git 提交，不调用 check-gates.sh 与 lane-commit.sh（投影
#      再生调用 generate-progress.sh 不在此限）。

# 用法、数据契约与退出码见同目录 README.md。
# 单写路径（票 246 承接票 243）：索引为唯一可变状态真相源；状态写入先经共享库
# record_lock_acquire 取记录层写锁（mkdir 原子语义，锁目录由仓库根的 Git 公共目录推导，
# 主检与全部 worktree 共享；陈旧锁只诊断，显式 --break-stale-lock 才夺；等待超时即
# exit 1 并发冲突），锁区间覆盖预检读取到投影收尾；四个写点前经 record_lock_assert 核对
# 令牌归属（被夺锁即拒绝写入）；每个写点先生成同目录临时件再 mv 原子替换（崩溃只留
# 完整旧版或完整新版）；嵌套调用 ledger-append.sh 时传继承标记，不重复取锁；索引已达
# 目标状态时走幂等重放（补齐 README/账本/投影后 exit 0，不重复落账本行），故崩溃后
# 重跑同一命令即可收敛，无需手工编辑任何状态文件。
# 故障注入契约（崩溃恢复测试）：TICKET_OPS_FAULT=<after-index-write|
# after-ledger-write|after-projection-write>，该写点完整落盘后 exit 70 并打印
# 「ticket-ops: FAULT injected: <point>」；未知值 exit 2 零写入。
# ledger-rowtype-version: 3（五键/lesson 六键九键/replan 八键；机制版本注记，票 133 行型）
# 行型合同：账本行键集/键序/值域适用表单一真相源＝agent-up 公开包
# references/schemas/ledger-row.schema.json（本脚本行校验与其 rows[].keys/值域逐条
# 对齐；文档级单源，不运行时读取，安装闭包不含此件）。

# ---- 路径常量区（票 113 波④：值翻 rules/facts 新形态，映射见 rules-facts-layout-spec §2 R11/R13/R15/R19）----
issues_index_rel='facts/requirements/tickets/index.json'
issues_readme_rel='facts/requirements/tickets/README.md'
issues_dir_rel='facts/requirements/tickets'
progress_current_rel='facts/requirements/tickets/progress-current.md'
scripts_dir_rel='rules/implementation/scripts'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'ticket-ops: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/ticket-ops.sh [repo-root] <command> [options]
参数:
  repo-root      仓库根目录；缺省取脚本所在目录的上一级。
  --break-stale-lock  仅在遇到陈旧锁时显式夺锁（等价 RECORD_LOCK_BREAK_STALE=1）；
                      缺省只诊断不夺锁，等待超时即 exit 1。可出现在任意选项位置。
命令:
  open           开票：先过新票本体校验（facts/requirements/tickets/<id>.json 须已落位并过
                 ticket-record.schema.json 全量校验——type/pattern/enum/oneOf/
                 additionalProperties 与条件 required 依 schema 执行（票 152），非空断言
                 同前，票 79；另强制新 task 七维 profile reason：profile_reason 对象
                 恰七键 D/B/I/U/S/M/O 且逐键非空，存储合同见 schema 属性与
                 complexity-profile.md §2.2；dispatch 派发合同数据节不属开票门——开票
                 不预填未来证据，本节由派发方在派发时点落位、contract-build.sh 在派发
                 阶段做完整性门）；缺本体或校验不过即 fail-closed 零写入），
                 再写索引条目
                 （status=ready；空索引 {"issues": []} 可就地展开落首条目）＋
                 issues-README 目录清单追加行（`任务票 <NN>；` 锚点已在场即拒——追加
                 语义要求零命中，不制造重复锚点；空表只有表头时插在表头之后）＋账本
                 追加行，收尾投影再生＋--check。
                 幂等：同一 id 已在索引且状态为 ready 时走幂等重放——只补齐 README 行、
                 账本行与投影后 exit 0，不重写索引、不重复落账本行；索引已是其他状态
                 则 exit 1 冲突（改状态须走 flip），零写入。
                 选项（前四必选）:
                   --id <NN-slug>            票 id（^[0-9]{2,}-[a-z0-9-]+$；须不在索引中且 NN 段未被
                             占用——同 NN 异 slug 撞号拒开，票 77）
                   --complexity <C0-C3>      复杂度档位
                   --title <text>            票标题（用作 README 行功能列文本；不得含
                                             竖线/反引号/换行/制表符）
                   --ledger-line <json>      完整 JSONL 账本行（键序 date,kind,scope,
                                             decision,evidence_ref 五键必备＋按 kind 条件
                                             键，票 81：lesson 必带第六键 promoted_to（枚
                                             举 新票/rules/sop/validator/test/none），replan
                                             必带 replan_original/replan_replacement/
                                             replan_undone（布尔）；行型键集/键序/值域适
                                             用表单一合同＝agent-up 公开包 references/
                                             schemas/ledger-row.schema.json；紧凑或带空
                                             格 JSONL 均可；脚本只校验后追加，不代生成
                                             散文；字符串值不得内嵌引号或反斜杠）
                   [--blocked-by <id,id>]    逗号分隔 blocker id（缺省空数组）
  take           领取：--id --status --ledger-line 三项必选；--status 须为 in_progress。
                 领取预检（blocked_by 完整性门）：task 票本体 blocked_by 逐项须在索引
                 登记且 status=done，缺失（索引零命中）或未完成即 exit 1 指名 blocker
                 id 与其状态（fail-closed 零写入）；request 票无 blocked_by 不校验。
  flip           收口/状态翻转：--id --status --ledger-line 三项必选；--status 为状态机
                 任意合法值（ready|in_progress|blocked|review_ready|review_pass|
                 review_fail|done|superseded）。task 票 flip 至 done 的收口硬拦（票 100）：
                 本票 JSON 本体（facts/requirements/tickets/<id>.json）须含 actual_time
                 字段且非空（净工时口径，会话段累计减中断段），缺项或空白即 exit 1 指名
                 票 id 与缺项（fail-closed 零写入）；非 done 翻转不要求 actual_time；
                 request 票不校验。done 另过证据门（票 237）：调同目录 ticket-audit.sh
                 --operation merge，只认 conformant；未提交、提交后改动、diff 失配、
                 unknown 一律 exit 1 报 decision-required 并零写入（不采信自报 PASS）。
                 take/flip 语义: 索引 id 锚点整行替换（仅改 status/updated_at 两值）→
                 README 状态行锚定 `任务票 <NN>；` 后首个反引号状态 token 替换（行内其余
                 文本不动）→ 账本追加行 → 投影再生＋--check。索引或 README 行缺失、锚点
                 不唯一、账本行非法即停止（fail-closed，写入前预检）。
  close          done 收口入口（票 237）：--id --ledger-line 两项必选，status 固定 done
                 （不得携带 --status）；写入链与证据判定与 flip 至 done 完全一致
                 （actual_time + ticket-audit --operation merge conformant 双证），只多
                 一个入口别名，不留自报旁路；request 票沿用 actual_time 与证据门豁免
                 （kind=request 不要求审查证据）。
  ledger         无票账本行入口（票 100）：--ledger-line 必选；不依赖 facts/requirements/tickets/index.json
                 条目 id，账本行形状校验与落行由唯一写入方 ledger-append.sh 承载（票 228
                 F7），通过后向 facts/project/changes.jsonl 追加该行；不触索引/README/票文件/投影
                 （C0 修正类免建票收口经此落账本行，决策 4）。
  flip-index     索引单写代理（票 228 F1/F2，快道收尾 lane-commit 专用）：--id --status
                 --updated-at 三项必选（--status 为状态机裸值，--updated-at 为 ISO 8601
                 YYYY-MM-DDTHH:MM[:SS]）；索引 id 锚点整行替换（仅改 status/updated_at
                 两值）→ 投影再生＋--check；不触 README/账本/票本体（README 状态列与
                 账本行归各自治道承载，票 35/37 口径），不得携带 --ledger-line。目标
                 task 票 done 同过 actual_time＋证据门双证（票 237）；request 票沿用
                 两项豁免（kind=request 不要求审查证据）。
  -h / --help    打印本用法。
退出码: 0 全部完成；1 fail-closed（校验/锚点/收尾核对不过，已写部分如实报告；并发写锁
        等待超时＝并发冲突，零写入，重跑同一命令即收敛；open 目标状态非 ready 即冲突
        拒绝；done 缺证据即 decision-required）；2 用法或环境错误（含未知
        TICKET_OPS_FAULT 注入点）；
        70 故障注入点命中（TICKET_OPS_FAULT，崩溃恢复测试用；该写点已完整落盘）。
环境变量: TICKET_OPS_LOCK_TIMEOUT  写锁等待上限秒数（缺省 20）
          TICKET_OPS_LOCK_STALE    写锁陈旧判据秒数（缺省 600；仅用于 pid 缺失时的锁龄判定，
                                   不单独授权夺锁）
          RECORD_LOCK_BREAK_STALE  设为 1 时对陈旧锁显式夺锁（等价 --break-stale-lock；
                                   未设＝只诊断不夺锁）
          RECORD_LOCK_TEST_HOLD_MS 仅测试用：持锁后延迟返回的毫秒数（未设或 0＝零开销）
          TICKET_OPS_FAULT         崩溃注入点 after-index-write|after-ledger-write|
                                   after-projection-write（未设＝正常路径）
互斥边界: 写锁目录由仓库根的 Git 公共目录推导（经 rev-parse 取公共目录并归一为绝对物理
          路径），主检与全部 worktree 争用同一把锁；非 Git 语境回退 $TMPDIR 并按仓库根
          物理路径派生。跨主机/跨用户不互斥。锁目录不进入版本控制跟踪面。
USAGE
}

tmp_idx=''
tmp_readme=''
cleanup() {
  if [ -n "${tmp_idx}" ]; then rm -f "${tmp_idx}"; tmp_idx=''; fi
  if [ -n "${tmp_readme}" ]; then rm -f "${tmp_readme}"; tmp_readme=''; fi
  record_lock_release
}
trap cleanup EXIT HUP INT TERM

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
  open|take|flip|close|ledger|flip-index)
    cmd=$1
    shift
    repo_root=''
    ;;
  *)
    repo_root=$1
    shift
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    case $1 in
      open|take|flip|close|ledger|flip-index) cmd=$1; shift ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
esac

# 仓库根推导统一经 resolve_repo_root（票 227 F4：显式参数 > 落位分派两布局）
if [ -n "${repo_root}" ]; then
  _rr=$(resolve_repo_root "${repo_root}") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "$_rr" ] || die2 "仓库根不可用: ${repo_root:-（未传参且脚本落位非两布局，无法缺省推导）}"
repo_root=$_rr
[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
record_lock_init "${repo_root}"

# ---- 选项解析 ----

id=''
complexity=''
title=''
ledger_line=''
blocked_by=''
status=''
updated_at=''

while [ $# -gt 0 ]; do
  case $1 in
    --id) [ $# -ge 2 ] || die2 '--id 缺值'; id=$2; shift 2 ;;
    --complexity) [ $# -ge 2 ] || die2 '--complexity 缺值'; complexity=$2; shift 2 ;;
    --title) [ $# -ge 2 ] || die2 '--title 缺值'; title=$2; shift 2 ;;
    --ledger-line) [ $# -ge 2 ] || die2 '--ledger-line 缺值'; ledger_line=$2; shift 2 ;;
    --blocked-by) [ $# -ge 2 ] || die2 '--blocked-by 缺值'; blocked_by=$2; shift 2 ;;
    --status) [ $# -ge 2 ] || die2 '--status 缺值'; status=$2; shift 2 ;;
    --updated-at) [ $# -ge 2 ] || die2 '--updated-at 缺值'; updated_at=$2; shift 2 ;;
    --break-stale-lock)
      RECORD_LOCK_BREAK_STALE=1
      export RECORD_LOCK_BREAK_STALE
      shift
      ;;
    *) die2 "未知参数: $1" ;;
  esac
done

# ---- 公共校验（fail-closed，先于任何写入） ----

# 票锚定命令（open/take/flip/close/flip-index）才要求 --id；ledger 无票面不依赖 id（票 100）
case ${cmd} in
  open|take|flip|close|flip-index)
    case ${id} in
      '') die1 "缺少 --id" ;;
    esac
    # open 命令禁 REQ-* id 格式（2026-10-23 退役：新需求走任务票，不创建 request；
    # 存量 REQ 冻结只读，读取校验不经本门——json-validator ticket 不传 --new-ticket）
    case ${cmd}-${id} in
      open-REQ-*) die1 "REQ-* 格式 id 已退役（2026-10-23）：新需求一律走任务票 <NN>-<slug> 格式；存量 REQ 冻结只读" ;;
    esac
    printf '%s' "${id}" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
      die1 "id 不合口径（^[0-9]{2,}-[a-z0-9-]+$）: ${id}"
    ;;
esac
# flip-index＝索引单写代理，不落账本行，不要求 --ledger-line（票 228 F1/F2）
if [ "${cmd}" != 'flip-index' ]; then
  case ${ledger_line} in
    '') die1 "缺少 --ledger-line" ;;
  esac
  # 账本行形状校验与落行统一由唯一写入方 ledger-append.sh 承载（票 228 F7：
  # changes.jsonl 写入单点；此处写前预检经其 --check 零写入模式承载——校验先于票务面
  # 任何写入的 fail-closed 时序保持；报文为 ledger-append 合同输出，逐条行型报因与
  # 退出码同原内嵌链字面迁移）。写入方定位：同目录优先，PATH 回退；缺失即预检停止。
  ledger_cmd=''
  if [ -f "${script_dir}/ledger-append.sh" ] && [ -r "${script_dir}/ledger-append.sh" ]; then
    ledger_cmd="${script_dir}/ledger-append.sh"
    printf 'ticket-ops: 账本写入方定位: 同目录 %s\n' "${ledger_cmd}"
  else
    _rest=${PATH:-}
    while [ -n "${_rest}" ]; do
      _dir=${_rest%%:*}
      case ${_rest} in
        *:*) _rest=${_rest#*:} ;;
        *) _rest='' ;;
      esac
      [ -n "${_dir}" ] || continue
      if [ -f "${_dir}/ledger-append.sh" ] && [ -r "${_dir}/ledger-append.sh" ]; then
        ledger_cmd="${_dir}/ledger-append.sh"
        break
      fi
    done
    if [ -n "${ledger_cmd}" ]; then
      printf 'ticket-ops: 账本写入方定位: PATH %s\n' "${ledger_cmd}"
    else
      die1 "账本写入方 ledger-append.sh 不可用（同目录与 PATH 均未找到）——预检停止：changes.jsonl 唯一写入方＝本脚本同目录 ledger-append.sh（票 228 F7 单写方承载），将其落位后重跑"
    fi
  fi
  sh "${ledger_cmd}" "${repo_root}" --check --ledger-line "${ledger_line}" || \
    die1 "账本行校验未过（唯一写入方 ledger-append.sh --check fail-closed，详见上方 stderr）——未产生任何写入"
fi

case ${cmd} in
  open)
    case ${complexity} in
      '') die1 "缺少 --complexity" ;;
    esac
    printf '%s' "${complexity}" | LC_ALL=C grep -Eq '^C[0-3]$' || \
      die1 "complexity 不合口径（C0-C3）: ${complexity}"
    case ${title} in
      '') die1 "缺少 --title" ;;
    esac
    case ${title} in
      *"|"*|*"\`"*|*"${NL}"*|*"${TAB}"*) die1 'title 不得含竖线、反引号、换行或制表符（README 表格单元安全）' ;;
    esac
    blocked_json=''
    if [ -n "${blocked_by}" ]; then
      rest=${blocked_by}
      while [ -n "${rest}" ]; do
        entry=${rest%%,*}
        case ${rest} in
          *,*) rest=${rest#*,} ;;
          *) rest='' ;;
        esac
        entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        printf '%s' "${entry}" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
          die1 "blocked_by 条目不合 id 口径: ${entry}"
        if [ -z "${blocked_json}" ]; then
          blocked_json="\"${entry}\""
        else
          blocked_json="${blocked_json}, \"${entry}\""
        fi
      done
    fi
    [ -z "${status}" ] || die2 'open 不得携带 --status（开票状态固定 ready）'
    [ -z "${updated_at}" ] || die2 'open 不得携带 --updated-at（开票 updated_at 由本件生成）'
    ;;
  take|flip)
    case ${status} in
      '') die1 "缺少 --status" ;;
    esac
    printf '%s' "${status}" | LC_ALL=C grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || \
      die1 "status 不合状态机取值（裸值）: ${status}"
    if [ "${cmd}" = 'take' ] && [ "${status}" != 'in_progress' ]; then
      die1 "take 的 --status 须为 in_progress（领取语义；其他翻转用 flip）: ${status}"
    fi
    [ -z "${complexity}" ] || die2 'take/flip 不得携带 --complexity'
    [ -z "${title}" ] || die2 'take/flip 不得携带 --title'
    [ -z "${blocked_by}" ] || die2 'take/flip 不得携带 --blocked-by'
    [ -z "${updated_at}" ] || die2 'take/flip 不得携带 --updated-at（updated_at 由本件生成）'
    ;;
  close)
    [ -z "${status}" ] || die2 'close 不得携带 --status（收口状态固定 done）'
    [ -z "${complexity}" ] || die2 'close 不得携带 --complexity'
    [ -z "${title}" ] || die2 'close 不得携带 --title'
    [ -z "${blocked_by}" ] || die2 'close 不得携带 --blocked-by'
    [ -z "${updated_at}" ] || die2 'close 不得携带 --updated-at（updated_at 由本件生成）'
    status='done'
    ;;
  flip-index)
    [ -z "${ledger_line}" ] || die2 'flip-index 不得携带 --ledger-line（索引单写代理不落账本行——票 228 F1/F2）'
    [ -z "${complexity}" ] || die2 'flip-index 不得携带 --complexity'
    [ -z "${title}" ] || die2 'flip-index 不得携带 --title'
    [ -z "${blocked_by}" ] || die2 'flip-index 不得携带 --blocked-by'
    case ${status} in
      '') die1 'flip-index 缺少 --status' ;;
    esac
    printf '%s' "${status}" | LC_ALL=C grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || \
      die1 "flip-index 的 --status 不合状态机取值（裸值）: ${status}"
    case ${updated_at} in
      '') die1 'flip-index 缺少 --updated-at' ;;
    esac
    printf '%s' "${updated_at}" | LC_ALL=C grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' || \
      die1 "updated_at 不合 ISO 8601 口径（YYYY-MM-DDTHH:MM[:SS]）: ${updated_at}"
    ;;
  ledger)
    [ -z "${id}" ] || die2 'ledger 不得携带 --id（无票账本行入口不依赖票 id，票 100）'
    [ -z "${status}" ] || die2 'ledger 不得携带 --status（无票面状态可翻，票 100）'
    [ -z "${complexity}" ] || die2 'ledger 不得携带 --complexity'
    [ -z "${title}" ] || die2 'ledger 不得携带 --title'
    [ -z "${blocked_by}" ] || die2 'ledger 不得携带 --blocked-by'
    ;;
esac

index_file="${repo_root}/${issues_index_rel}"
readme_file="${repo_root}/${issues_readme_rel}"
# 本脚本所在目录（安装闭包回退定位基准；包基线布局＝agent-up/scripts/，安装布局＝
# rules/implementation/scripts/——两者相对自身目录的 references/ 邻接路径同构）。
_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# 唯一 JSON 引擎定位（票 227 F3；安装闭包定位同 schema 权威：先包基线布局
# （<repo-root>/agent-up/scripts/json-validator.py），缺失回退本脚本同目录）
_engine="${repo_root}/agent-up/scripts/json-validator.py"
[ -f "${_engine}" ] || _engine="${_self_dir}/json-validator.py"
# 证据审计引擎定位（票 237：done 证据门；同目录优先，PATH 回退——与 ledger-append
# 同款定位口径，落位不要求可执行位，恒经 sh 调用）
audit_cmd=''
if [ -f "${script_dir}/ticket-audit.sh" ] && [ -r "${script_dir}/ticket-audit.sh" ]; then
  audit_cmd="${script_dir}/ticket-audit.sh"
else
  _arest=${PATH:-}
  while [ -n "${_arest}" ]; do
    _adir=${_arest%%:*}
    case ${_arest} in
      *:*) _arest=${_arest#*:} ;;
      *) _arest='' ;;
    esac
    [ -n "${_adir}" ] || continue
    if [ -f "${_adir}/ticket-audit.sh" ] && [ -r "${_adir}/ticket-audit.sh" ]; then
      audit_cmd="${_adir}/ticket-audit.sh"
      break
    fi
  done
fi
# 票 79：open 本体落盘位与 schema 权威（development-process §5.2 开票形态注记）。
# 安装闭包定位：先包基线布局（<repo-root>/agent-up/references/schemas/…），缺失回退
# 安装布局（本脚本邻接 references/schemas/…）；均未命中时停在回退路径，由 open 预检
# 报明双候选 fail-closed。
ticket_file="${repo_root}/${issues_dir_rel}/${id}.json"
schema_file_pkg="${repo_root}/agent-up/references/schemas/ticket-record.schema.json"
schema_file="${schema_file_pkg}"
[ -f "${schema_file}" ] || schema_file="${_self_dir}/../references/schemas/ticket-record.schema.json"
# dispatch 节键集权威（dispatch-contract.schema.json）自票 243 起不在本件读取：开票不再
# 校验派发合同数据节（AC6），键集核对移至派发阶段消费面（contract-build.sh 渲染前自校验）。

# 票 100：flip 收口硬拦载体定位（actual_time 校验用）；ledger 无票面，不要求票本体。
case ${cmd} in
  ledger) ;;
  flip-index)
    # 索引单写代理（票 228 F1/F2）：只触索引，不要求 README/票本体在位
    [ -f "${index_file}" ] || die1 "索引文件不存在: ${index_file}（票状态真相源缺失，fail-closed）"
    [ -r "${index_file}" ] || die1 "索引文件不可读: ${index_file}"
    ;;
  *)
    [ -f "${index_file}" ] || die1 "索引文件不存在: ${index_file}（票状态真相源缺失，fail-closed）"
    [ -r "${index_file}" ] || die1 "索引文件不可读: ${index_file}"
    [ -f "${readme_file}" ] || die1 "issues-README 不存在: ${readme_file}"
    [ -r "${readme_file}" ] || die1 "issues-README 不可读: ${readme_file}"
    ;;
esac

nn=${id%%-*}

# ---- 故障注入契约（票 243：崩溃恢复测试用，未设或空串＝正常路径零差异）----
# TICKET_OPS_FAULT=<point>，point ∈ after-index-write|after-ledger-write|
# after-projection-write：该写点完整落盘后立即 exit 70 并打印 FAULT 报文，其后写点不执行；
# 未知值＝exit 2 零写入（用法/环境错误口径）。重跑同一命令由幂等路径收敛。
case ${TICKET_OPS_FAULT:-} in
  '') ;;
  after-index-write|after-ledger-write|after-projection-write) ;;
  *) die2 "未知 TICKET_OPS_FAULT 注入点: ${TICKET_OPS_FAULT}（合法值 after-index-write|after-ledger-write|after-projection-write）——未产生任何写入" ;;
esac

fault_point() {
  # $1=写点名：命中注入点即完整落盘后终止（exit 70），供崩溃恢复测试与幂等重跑验证
  [ "${TICKET_OPS_FAULT:-}" = "$1" ] || return 0
  printf 'ticket-ops: FAULT injected: %s\n' "$1" >&2
  exit 70
}

# ---- 状态写锁（票 246：原语下沉 common-helpers.sh，本脚本只调用不复制）----
# 锁目录由仓库根的 Git 公共目录推导（跨主检与 worktree 共享），陈旧锁只诊断、显式参数
# 才夺；取锁/令牌校验/释放细节见共享库 record_lock_* 与同目录 README.md。

# ---- 状态读取辅助（票 243：幂等判定共用；只读，写入前判定） ----

ledger_rel='facts/project/changes.jsonl'
ledger_file="${repo_root}/${ledger_rel}"

index_entry_state() {
  # 打印: absent | present <status>；排版破坏或锚点多行 exit 2（fail-closed，零写入）
  IDX_ID=${id} awk '
    BEGIN { id = ENVIRON["IDX_ID"]; anchor = "\"id\": \"" id "\"" }
    index($0, "\"id\": \"") > 0 {
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) bad = 1
      if (index($0, anchor) > 0) {
        hits++
        p = index($0, "\"status\": \"")
        if (p > 0) {
          s = substr($0, p + 11)
          st = substr(s, 1, index(s, "\"") - 1)
        }
      }
    }
    END {
      if (bad) {
        printf "ticket-ops: FAIL: 索引条目行缺同行 status/updated_at 字段——一条目一行排版被破坏（票 33 终裁 T2）\n" > "/dev/stderr"
        exit 2
      }
      if (hits == 0) { print "absent"; exit 0 }
      if (hits > 1) { printf "ticket-ops: FAIL: 索引条目 id 命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; exit 2 }
      print "present " st
      exit 0
    }
  ' "${index_file}"
}

readme_anchor_count() {
  # `任务票 <NN>；` 锚点行数（幂等判定：0＝缺失待插、1＝已在场、>1＝漂移拒写）
  RD_NN_ANCHOR="任务票 ${nn}；" awk '
    BEGIN { anchor = ENVIRON["RD_NN_ANCHOR"] }
    index($0, anchor) > 0 { hits++ }
    END { print hits + 0 }
  ' "${readme_file}"
}

ledger_row_exists() {
  # 账本幂等判定（仅状态操作 open/take/flip 使用；`ledger` 无票入口保持只追加）：
  # 与既有行「逐字相同」或「解析后 JSON 对象相等」即视为同一操作已落账——后者吸收
  # 键序与 JSON 内部空白差异，但不做「删掉全部空白」的宽松匹配（否则
  # "decision":"a b" 与 "a  b" 会被误判为同一行）。
  [ -f "${ledger_file}" ] || return 1
  grep -Fqx -- "${ledger_line}" "${ledger_file}" && return 0
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "${ledger_file}" "${ledger_line}" <<'PY'
import json
import sys

path, line = sys.argv[1], sys.argv[2]
try:
    target = json.loads(line)
except ValueError:
    sys.exit(1)
with open(path, encoding='utf-8') as fh:
    for raw in fh:
        raw = raw.strip()
        if not raw:
            continue
        try:
            if json.loads(raw) == target:
                sys.exit(0)
        except ValueError:
            continue
sys.exit(1)
PY
}

# ---- actual_time 收口硬拦（票 100，flip 至 done 专属） ----

actual_time_check() {
  # flip 收口硬拦（票 100，决策 2 fail-closed）：task 票 flip 至 done 时点，JSON 本体
  # 须含 actual_time 字段且非空（净工时口径，strip 后非空；schema 同款非空口径），缺项
  # 或空白即 exit 1 指名票 id 与缺项，零写入。调用点已条件化——仅 flip 目标 status=done
  # 时执行，非 done 翻转不要求 actual_time（收口语义只属终态 done）。request 票不校验
  # （open 时点已过 schema 校验的 kind 为准；本体缺失不属本断言语义——由 open 时点
  # 保证存在，此处缺本体即报缺项指名票 id）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——flip actual_time 收口校验无法执行（fail-closed；票 100 起为 flip 校验依赖）'
  [ -r "${ticket_file}" ] || \
    die1 "票 ${id} 收口缺 actual_time：票本体不可读: ${ticket_file}（flip 校验须先读本票本体核 actual_time——票 100）"
  [ -f "${_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包双布局定位均未命中: ${repo_root}/agent-up/scripts/ 与 ${_self_dir}/）"
  # 收口硬拦判据由唯一 JSON 引擎承载（票 227 F3；报文为 ticket-ops 合同输出）
  python3 "${_engine}" ticket-check close "${ticket_file}" "${id}"
}

# ---- done 证据门（票 237：只认 234 审计引擎的 conformant 判定） ----

audit_gate() {
  # $1=入口名（close|flip|flip-index）：done 收口前调同目录 ticket-audit.sh
  # --operation merge，只认 conformant（exit 0）；nonconformant/unknown（exit 1）即
  # 报 decision-required 并零写入；用法/环境错误（exit 2）按环境错误停。request 票
  # 沿用既有豁免（与 actual_time 同口径，不要求审查证据）。不采信自报 PASS：
  # 证据未提交、提交后改动、diff 失配、身份/策略不可核验一律拒绝。
  _ag_entry=$1
  _ag_kind='task'
  if [ -r "${ticket_file}" ] && [ -f "${_engine}" ]; then
    _ag_kind=$(python3 "${_engine}" json get "${ticket_file}" kind 2>/dev/null) || _ag_kind='task'
  fi
  if [ "${_ag_kind}" = 'request' ]; then
    printf 'ticket-ops: 证据门: %s request 票沿用豁免（kind=request；不要求审查证据）\n' "${_ag_entry}"
    return 0
  fi
  [ -n "${audit_cmd}" ] || die1 "证据审计引擎 ticket-audit.sh 不可用（同目录与 PATH 均未找到）——${_ag_entry} 至 done 预检停止：done 只认 ticket-audit --operation merge 的 conformant 判定（票 237），将 ticket-audit.sh 落位后重跑；未产生任何写入"
  # 显式允许集（票 237 裁决）：done 面的合法后置写面＝记录载体（索引与投影＋本票票体
  # 的 checkpoint.commit）＋票面声明的 Review Checkpoint；仅逐条显式传入，默认仍只认
  # 证据文件，不整体放开 facts 面。
  # 形态约束（不得放宽）由 common-helpers 的 review_checkpoint_allow_after 唯一承载：
  # 只认本票规范路径 facts/requirements/tickets/<票 id>-review-checkpoint.md。
  _ag_cp=$(review_checkpoint_allow_after "${id}" "${_engine}" "${ticket_file}")
  _ag_ticket_rel="${issues_dir_rel}/${id}.json"
  _ag_rc=0
  if [ -n "${_ag_cp}" ]; then
    sh "${audit_cmd}" "${nn}" --repo "${repo_root}" --operation merge \
      --allow-after "${issues_index_rel}" \
      --allow-after "${progress_current_rel}" \
      --allow-after "${_ag_ticket_rel}" \
      --allow-after "${_ag_cp}" || _ag_rc=$?
  else
    sh "${audit_cmd}" "${nn}" --repo "${repo_root}" --operation merge \
      --allow-after "${issues_index_rel}" \
      --allow-after "${progress_current_rel}" \
      --allow-after "${_ag_ticket_rel}" || _ag_rc=$?
  fi
  case ${_ag_rc} in
    0)
      printf 'ticket-ops: 证据门: %s 放行（ticket-audit --operation merge conformant）\n' "${_ag_entry}"
      ;;
    2)
      die2 "证据审计引擎用法/环境错误（exit 2）——${_ag_entry} 至 done 预检停止，未产生任何写入"
      ;;
    *)
      die1 "decision-required: ${_ag_entry} 至 done 要求票 ${id} 的审查证据判 conformant（ticket-audit --operation merge exit ${_ag_rc}）——证据缺失/未提交/提交后改动/diff 失配/身份或策略不可核验一律拒绝；零写入，补齐已提交证据与审计策略后重跑"
      ;;
  esac
  return 0
}

# ---- blocked_by 领取完整性门（take 专属） ----

blocked_by_check() {
  # take 领取预检（fail-closed 零写入）：task 票本体 blocked_by 数组逐项核对索引——每个
  # 被依赖票 id 须在索引中登记（存在性）且 status=done（完成性，索引为状态真相源）；
  # 缺失（索引零命中）或未完成（status 非 done）即 exit 1，逐项指名 blocker id 与其索引
  # 状态，任何写入之前停止。request 票无 blocked_by（schema request 分支省略），不校验；
  # 本体缺失不属本断言语义——由 open 时点保证存在，此处缺本体即报缺项指名票 id
  # （口径同 actual_time 收口硬拦的本体缺失先例）。门仅限 take——flip 不做 blocked_by
  # 核对。依赖 python3（JSON 解析，fail-closed）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——take blocked_by 完整性预检无法执行（fail-closed）'
  [ -r "${ticket_file}" ] || \
    die1 "票 ${id} 领取预检失败：票本体不可读: ${ticket_file}（blocked_by 完整性门须读本票声明的被依赖票清单）"
  [ -f "${_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包双布局定位均未命中: ${repo_root}/agent-up/scripts/ 与 ${_self_dir}/）"
  # 领取完整性门判据由唯一 JSON 引擎承载（票 227 F3；报文为 ticket-ops 合同输出）
  python3 "${_engine}" ticket-check deps "${ticket_file}" "${index_file}" "${id}"
}

# ---- 索引与 README 锚点预检（只扫描不写入；任何不合规在写入前停止） ----

index_check() {
  # $1=open|flip；open 要求 id 零命中（可新增），其余要求恰 1 命中（可替换）
  IDX_MODE=$1 IDX_ID=${id} awk '
    BEGIN {
      mode = ENVIRON["IDX_MODE"]
      id = ENVIRON["IDX_ID"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "ticket-ops: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——一条目一行排版被破坏（票 33 终裁 T2）\n", FNR > "/dev/stderr"
        bad = 1
      }
      if (index($0, anchor) > 0) hits++
    }
    END {
      rc = 0
      if (n == 0) { printf "ticket-ops: FAIL: 索引中未找到条目行（\"id\": 锚点零命中）\n" > "/dev/stderr"; rc = 1 }
      if (mode == "open") {
        if (hits != 0) { printf "ticket-ops: FAIL: 索引条目 id 已存在（open 非幂等，命中 %d 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      } else {
        if (hits != 1) { printf "ticket-ops: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      }
      if (bad) rc = 1
      exit rc
    }
  ' "${index_file}"
}

index_nn_check() {
  # open 预检：NN 段唯一性查重（票 77）——账本 renumber-70-72 实录缺口：open 只查全 id
  # （slug 查重），同 NN 异 slug 撞号漏拦，到 take 的 README 锚点预检才兜底。此处开票即拒：
  # 号段被占报明已占完整 id，零写入。NN 提取与 id 口径一致（^[0-9]{2,}-）：仅对合口径的
  # 既有 id 取段比对；畸形既有 id 不产 NN 段、不参与撞号（其本身非法，由 id 口径门与
  # 索引排版门兜底）；来件 id 已过 ^[0-9]{2,}-[a-z0-9-]+$ 门，nn 取值即前导数字段。
  IDX_NN=${nn} IDX_ID=${id} awk '
    BEGIN {
      target = ENVIRON["IDX_NN"]
      tid = ENVIRON["IDX_ID"]
      head = "\"id\": \""
      hlen = length(head)
      m = 0
    }
    index($0, head) > 0 {
      p = index($0, head) + hlen
      rest = substr($0, p)
      q = index(rest, "\"")
      if (q <= 1) next
      eid = substr(rest, 1, q - 1)
      if (eid == tid) next
      if (eid !~ /^[0-9][0-9]+-/) next
      enn = substr(eid, 1, index(eid, "-") - 1)
      if (enn == target) { m++; occ[m] = eid }
    }
    END {
      if (m > 0) {
        list = occ[1]
        for (i = 2; i <= m; i++) list = list ", " occ[i]
        printf "ticket-ops: FAIL: 票号段已被占用（同 NN 异 slug 撞号，open 拒开；先改号或按让号流程处理）: NN %s 已占 id → %s\n", target, list > "/dev/stderr"
        exit 1
      }
      exit 0
    }
  ' "${index_file}"
}

readme_row_check() {
  # open 预检：目录清单表须在场——表头分隔行（^\| ---）或数据行（^\| `）至少一项；
  # 票 243 起空表（仅表头、无数据行＝新项目首开形态）合法，新行插在表头之后。
  awk '
    /^\| `/ { rows++ }
    /^\| ---/ { head++ }
    END {
      if (rows == 0 && head == 0) {
        printf "ticket-ops: FAIL: issues-README 未找到目录清单表（^| --- 表头与 ^| ` 数据行均零命中）\n" > "/dev/stderr"
        exit 1
      }
      exit 0
    }
  ' "${readme_file}"
}

readme_nn_check() {
  # open 预检：`任务票 <NN>；` 锚点须零命中——open 是追加新行语义，锚点已在场即索引↔README
  # 漂移（或号段复用残留行），照追加将制造重复锚点（take/flip 预检要求恰 1 行，重复后该票
  # 永久卡死），故开票即拒零写入（fail-closed 前置，与 index_nn_check 同为 NN 唯一性门；
  # 锚点不唯一时不猜测更新对象，先核对漂移或改号；多字节位置运算只用 index，口径同
  # readme_token_check 注记）。
  RD_NN_ANCHOR="任务票 ${nn}；" awk '
    BEGIN { anchor = ENVIRON["RD_NN_ANCHOR"] }
    index($0, anchor) > 0 { hits++ }
    END {
      if (hits > 0) {
        printf "ticket-ops: FAIL: issues-README 锚点行已存在（open 追加语义要求零命中，命中 %d 行——先核对索引与 README 漂移或改号，不静默叠行）: %s\n", hits, anchor > "/dev/stderr"
        exit 1
      }
      exit 0
    }
  ' "${readme_file}"
}

readme_token_check() {
  # take/flip 预检：`任务票 <NN>；` 锚点恰 1 行，且其后存在闭合的反引号状态 token
  # 实现注记：位置运算只用 index/substr（同一单位），不用 length——macOS awk 对多字节
  # 字符串 index 回字符位、length 回字节数，混用会错位（票 41 夹具实证）。
  RD_ANCHOR="任务票 ${nn}；" awk '
    BEGIN { anchor = ENVIRON["RD_ANCHOR"] }
    index($0, anchor) > 0 {
      hits++
      p = index($0, anchor)
      s = substr($0, p)
      j = index(s, "`")
      s2 = ""
      if (j > 0) s2 = substr(s, j + 1)
      k = 0
      if (j > 0) k = index(s2, "`")
      if (j == 0 || k == 0) {
        printf "ticket-ops: FAIL: issues-README 第 %d 行锚点后反引号状态 token 缺失或未闭合\n", FNR > "/dev/stderr"
        bad = 1
      }
    }
    END {
      rc = 0
      if (hits != 1) { printf "ticket-ops: FAIL: issues-README 状态行锚点命中 %d 行（须恰 1 行）: %s\n", hits, anchor > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${readme_file}"
}

ticket_body_check() {
  # open 专属预检（票 79 起）：新票 JSON 本体过 ticket-record.schema.json 校验＋理由非空
  # 断言——票 152 起全量执行 schema 约束（不再只提取 required）：type/pattern/enum/oneOf/
  # additionalProperties 与 allOf 条件 required 均自 schema 文件现场执行（校验器＝在用
  # 约束词的机械执行子集，schema 为唯一权威）；非空＝字符串 strip 后非空（blocked_by 须
  # 数组，空数组合法＝无依赖）；另断言本体 id 与 --id 一致（防校验错文件）。新 task 七维
  # profile reason 门（--new-ticket 路径）：profile_reason 必备且恰七键逐键非空，缺项/
  # 越键/空白值即拒（存储合同单源＝schema profile_reason 属性与 complexity-profile.md
  # §2.2；读取面不要求本字段，存量零回扫——开票校验与读取校验分层）。只读零写入；
  # 任何不过即 exit 1（报文指名缺失项）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——open 本体 schema 校验无法执行（fail-closed；票 79 起为本体校验依赖）'
  [ -f "${ticket_file}" ] || \
    die1 "新票本体不存在: ${issues_dir_rel}/${id}.json——票 79 起 open 须先落位过 schema 的票 JSON 本体再开票"
  [ -r "${ticket_file}" ] || die1 "新票本体不可读: ${ticket_file}"
  [ -f "${schema_file}" ] || \
    die1 "schema 文件不存在（安装闭包双布局定位均未命中: ${schema_file_pkg} 与 ${schema_file}）（open 本体校验 fail-closed；schema 权威＝Agent Up 包内 references/schemas/ticket-record.schema.json，development-process §5.2）"
  [ -r "${schema_file}" ] || die1 "schema 文件不可读: ${schema_file}"

  [ -f "${_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包双布局定位均未命中: ${repo_root}/agent-up/scripts/ 与 ${_self_dir}/）"

  # 票 160：schema 校验由唯一 JSON 引擎 json-validator.py 承载（票 227 F3：原内嵌
  # python heredoc 收敛改调 ticket-check open-body；207 交付的 --new-ticket 门语义保留）
  python3 "${_engine}" ticket "${schema_file}" "${ticket_file}" --new-ticket || \
    die1 "票本体 schema 校验未过（详见上方 stderr）"

  # id 一致性与理由非空断言（票 79；引擎承载，报文为 ticket-ops 合同输出）
  python3 "${_engine}" ticket-check open-body "${ticket_file}" "${id}"
}


# 生成器定位（收尾投影再生必需；同目录优先，PATH 回退；缺失即预检停止）
# ledger（票 100 无票账本行入口）不触投影面，不要求生成器在位。
gen_cmd=''
if [ "${cmd}" = 'ledger' ]; then
  :
elif [ -f "${script_dir}/generate-progress.sh" ] && [ -r "${script_dir}/generate-progress.sh" ]; then
  gen_cmd="${script_dir}/generate-progress.sh"
  printf 'ticket-ops: 生成器定位: 同目录 %s\n' "${gen_cmd}"
else
  _rest=${PATH:-}
  while [ -n "${_rest}" ]; do
    _dir=${_rest%%:*}
    case ${_rest} in
      *:*) _rest=${_rest#*:} ;;
      *) _rest='' ;;
    esac
    [ -n "${_dir}" ] || continue
    if [ -f "${_dir}/generate-progress.sh" ] && [ -r "${_dir}/generate-progress.sh" ]; then
      gen_cmd="${_dir}/generate-progress.sh"
      break
    fi
  done
  if [ -n "${gen_cmd}" ]; then
    printf 'ticket-ops: 生成器定位: PATH %s\n' "${gen_cmd}"
  else
    die1 "投影生成器 generate-progress.sh 不可用（同目录与 PATH 均未找到）——预检停止：按 development-process §12.5 派生载体独占写，票务面写入必须伴随投影再生；将生成器落位到本脚本同目录（${scripts_dir_rel}/）或 PATH 后重跑"
  fi
fi

# ---- 状态预检（锁内：票 246 单写路径——预检读取与写入同锁区间，防读-改-写丢更新）----

record_lock_acquire

replay=0
if [ "${cmd}" = 'open' ]; then
  open_state=$(index_entry_state) || die1 "索引预检未通过: ${issues_index_rel}（${id}）——未产生任何写入"
  case ${open_state} in
    absent)
      ticket_body_check || die1 "新票本体校验未通过: ${issues_dir_rel}/${id}.json——未产生任何写入"
      index_nn_check || die1 "NN 段预检未通过: ${issues_index_rel}——未产生任何写入"
      readme_row_check || die1 "issues-README 预检未通过: ${issues_readme_rel}——未产生任何写入"
      readme_nn_check || die1 "issues-README 锚点预检未通过: ${issues_readme_rel}（任务票 ${nn}）——未产生任何写入"
      ;;
    'present ready')
      # 票 243 幂等：崩溃后重跑同一 open 命令即走此路径——索引已在目标状态，只补齐
      # README 行、账本行与投影，不重写索引、不重复落行（AC3 收敛的实现基础）。
      replay=1
      printf 'ticket-ops: 幂等重放: 索引已是目标状态 ready（%s）——补齐记录面与投影，不重写索引\n' "${id}"
      ;;
    'present '*)
      die1 "索引条目 id 已存在且状态为 ${open_state#present }（open 幂等仅限目标状态 ready；改状态须走 flip）: ${id}——未产生任何写入"
      ;;
    *)
      die1 "索引预检未通过: ${issues_index_rel}（${id}）——未产生任何写入"
      ;;
  esac
elif [ "${cmd}" = 'ledger' ]; then
  : # 无票面：账本行形状校验已于公共段完成（票 100），无索引/README 预检
else
  index_check flip || die1 "索引预检未通过: ${issues_index_rel}（${id}）——未产生任何写入"
  # flip-index（票 228 F1/F2 索引单写代理）不触 README，不做 README 锚点预检
  if [ "${cmd}" != 'flip-index' ]; then
    readme_token_check || die1 "issues-README 预检未通过: ${issues_readme_rel}（任务票 ${nn}）——未产生任何写入"
  fi
  if [ "${cmd}" = 'take' ]; then
    blocked_by_check || die1 "blocked_by 领取预检未通过: ${issues_dir_rel}/${id}.json——未产生任何写入（blocked_by 完整性门 fail-closed）"
  fi
  # 票 237：close/flip/flip-index 三入口至 task 票 done 同一双证门——actual_time 先于
  # 证据门（既有票 100 报文不变），证据门只认 ticket-audit --operation merge conformant。
  case ${cmd} in
    flip|close)
      if [ "${status}" = 'done' ]; then
        actual_time_check || die1 "actual_time 收口校验未通过: ${issues_dir_rel}/${id}.json——未产生任何写入（票 100 fail-closed）"
        audit_gate "${cmd}"
      fi
      ;;
    flip-index)
      if [ "${status}" = 'done' ]; then
        actual_time_check || die1 "actual_time 收口校验未通过: ${issues_dir_rel}/${id}.json——未产生任何写入（票 100 fail-closed）"
        audit_gate 'flip-index'
      fi
      ;;
  esac
  # 票 243 幂等：索引已是目标状态即跳过索引写（flip-index 由显式 --updated-at 承载，
  # 重放写同值属无害幂等，不另判）
  if [ "${cmd}" != 'flip-index' ]; then
    cur_entry=$(index_entry_state) || die1 "索引预检未通过: ${issues_index_rel}（${id}）——未产生任何写入"
    if [ "${cur_entry}" = "present ${status}" ]; then
      replay=1
      printf 'ticket-ops: 幂等重放: 索引已是目标状态 %s（%s）——补齐记录面与投影，不重写索引\n' "${status}" "${id}"
    fi
  fi
fi
# ---- 写入（锁内单写路径：索引 → README → 账本 → 投影；票 243） ----
# 写序固定；每个写点先在同目录临时件上生成全文再 mv 原子替换（同文件系统 rename 原子：
# 崩溃只留完整旧版或完整新版，不留半行/半文件）；写点后设故障注入检查点
# （TICKET_OPS_FAULT，票 243 AC3）；索引已处目标状态时走幂等重放——只补齐派生面与
# 记录面，不重写索引、不重复落账本行，故崩溃后重跑同一命令无需编辑任何文件。

now_ua=$(date +%Y-%m-%dT%H:%M)
today=$(date +%F)
index_dir=$(dirname -- "${index_file}")
readme_dir=$(dirname -- "${readme_file}")

if [ "${cmd}" = 'open' ] && [ "${replay}" -eq 0 ]; then
  new_entry="    {\"id\": \"${id}\", \"status\": \"ready\", \"complexity\": \"${complexity}\", \"blocked_by\": [${blocked_json}], \"updated_at\": \"${now_ua}\"}"
  tmp_idx=$(mktemp "${index_dir}/.tix-tmp.idx.XXXXXX")
  if grep -qF '"id": "' "${index_file}"; then
    # 常规模态：有条目行，新条目插在末条目之后（末行补逗号）
    IDX_NEW=${new_entry} awk '
      BEGIN { new = ENVIRON["IDX_NEW"] }
      {
        lines[++n] = $0
        if (index($0, "\"id\": \"") > 0) last_entry = n
        if ($0 ~ /^[[:space:]]*\][[:space:]]*$/) close_line = n
      }
      END {
        if (last_entry == 0 || close_line == 0) {
          printf "ticket-ops: FAIL: 索引条目区收口行缺失（^ ] 零命中）——拒绝插入\n" > "/dev/stderr"
          exit 1
        }
        for (i = 1; i <= n; i++) {
          if (i == last_entry) {
            line = lines[i]
            if (line !~ /,[[:space:]]*$/) sub(/$/, ",", line)
            print line
            print new
          } else {
            print lines[i]
          }
        }
        exit 0
      }
    ' "${index_file}" > "${tmp_idx}" || {
      rm -f "${tmp_idx}"; tmp_idx=''
      die1 "索引插入未通过校验: ${issues_index_rel}——未产生任何写入"
    }
  else
    # 空索引首开（票 243 AC1）：{\n  "issues": []\n} 就地展开为多行数组并落首条目，
    # 不预置占位条目。
    IDX_NEW=${new_entry} awk '
      BEGIN { new = ENVIRON["IDX_NEW"] }
      {
        if (!expanded && $0 ~ /"issues"[[:space:]]*:[[:space:]]*\[[[:space:]]*\][[:space:]]*,?[[:space:]]*$/) {
          line = $0
          comma = (line ~ /,[[:space:]]*$/) ? "," : ""
          sub(/\[[[:space:]]*\][[:space:]]*,?[[:space:]]*$/, "[", line)
          print line
          print new
          print "  ]" comma
          expanded = 1
          next
        }
        print
      }
      END {
        if (!expanded) {
          printf "ticket-ops: FAIL: 空索引未找到可展开的 issues 数组（\"issues\": [] 零命中）——拒绝插入\n" > "/dev/stderr"
          exit 1
        }
        exit 0
      }
    ' "${index_file}" > "${tmp_idx}" || {
      rm -f "${tmp_idx}"; tmp_idx=''
      die1 "空索引首开插入未通过校验: ${issues_index_rel}——未产生任何写入"
    }
  fi
  record_lock_assert
  mv "${tmp_idx}" "${index_file}"
  tmp_idx=''
  printf "ticket-ops: 索引新增条目: ${issues_index_rel}（%s → ready，updated_at %s）\n" "${id}" "${now_ua}"
  fault_point after-index-write
elif [ "${cmd}" != 'open' ] && [ "${cmd}" != 'ledger' ] && [ "${replay}" -eq 0 ]; then
  # take/flip/flip-index 共用索引单写（票 228 F1/F2：全仓 index.json 写入仅本件承载；
  # flip-index 的 updated_at 用显式 --updated-at 值，take/flip 由本件生成 now_ua）
  idx_ua=${now_ua}
  if [ "${cmd}" = 'flip-index' ]; then
    idx_ua=${updated_at}
  fi
  tmp_idx=$(mktemp "${index_dir}/.tix-tmp.idx.XXXXXX")
  IDX_ID=${id} IDX_STATUS=${status} IDX_UA=${idx_ua} awk '
    BEGIN {
      id = ENVIRON["IDX_ID"]; nstatus = ENVIRON["IDX_STATUS"]; nua = ENVIRON["IDX_UA"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "ticket-ops: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——拒绝单写\n", FNR > "/dev/stderr"
        bad = 1
        print
        next
      }
      if (index($0, anchor) > 0) {
        hits++
        line = $0
        sub(/"status": "[^"]*"/, "\"status\": \"" nstatus "\"", line)
        sub(/"updated_at": "[^"]*"/, "\"updated_at\": \"" nua "\"", line)
        print line
        next
      }
      print
      next
    }
    { print }
    END {
      rc = 0
      if (n == 0) { printf "ticket-ops: FAIL: 索引中未找到条目行\n" > "/dev/stderr"; rc = 1 }
      if (hits != 1) { printf "ticket-ops: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${index_file}" > "${tmp_idx}" || {
    rm -f "${tmp_idx}"; tmp_idx=''
    die1 "索引单写未通过校验: ${issues_index_rel}（${id}）——未产生任何写入"
  }
  record_lock_assert
  mv "${tmp_idx}" "${index_file}"
  tmp_idx=''
  printf "ticket-ops: 索引单写: ${issues_index_rel}（%s → %s，updated_at %s）\n" "${id}" "${status}" "${idx_ua}"
  fault_point after-index-write
fi

# ---- README 同步（open 追加目录行；take/flip 替换状态 token） ----

if [ "${cmd}" = 'open' ]; then
  row="| \`${id}.json\` | 任务票 ${nn}；\`ready\`（${today} 开票） | ${title} |"
  readme_rows=$(readme_anchor_count)
  case ${readme_rows} in
    0)
      tmp_readme=$(mktemp "${readme_dir}/.tix-tmp.readme.XXXXXX")
      RD_ROW=${row} awk '
        BEGIN { row = ENVIRON["RD_ROW"] }
        { lines[++n] = $0; if ($0 ~ /^\| `/) last = n; if ($0 ~ /^\| ---/) head = n }
        END {
          if (last == 0) last = head
          if (last == 0) {
            printf "ticket-ops: FAIL: issues-README 未找到目录清单表行或表头锚点——拒绝插入\n" > "/dev/stderr"
            exit 1
          }
          for (i = 1; i <= n; i++) { print lines[i]; if (i == last) print row }
        }
      ' "${readme_file}" > "${tmp_readme}" || {
        rm -f "${tmp_readme}"; tmp_readme=''
        die1 "issues-README 行插入未通过校验——索引已写入（${id}），README 未写入；重跑同一命令即收敛"
      }
      record_lock_assert
      mv "${tmp_readme}" "${readme_file}"
      tmp_readme=''
      printf "ticket-ops: README 追加目录清单行: ${issues_readme_rel}（任务票 %s；\`ready\`）\n" "${nn}"
      ;;
    1)
      printf 'ticket-ops: README 行已在场（幂等跳过插入）: 任务票 %s\n' "${nn}"
      ;;
    *)
      die1 "issues-README 锚点行命中 ${readme_rows} 行（须恰 1 行）: 任务票 ${nn}；——先核对索引与 README 漂移，不静默叠行（索引已写入 ${id}）"
      ;;
  esac
elif [ "${cmd}" = 'take' ] || [ "${cmd}" = 'flip' ] || [ "${cmd}" = 'close' ]; then
  tmp_readme=$(mktemp "${readme_dir}/.tix-tmp.readme.XXXXXX")
  RD_ANCHOR="任务票 ${nn}；" RD_STATUS=${status} awk '
    BEGIN { anchor = ENVIRON["RD_ANCHOR"]; nstatus = ENVIRON["RD_STATUS"] }
    index($0, anchor) > 0 {
      hits++
      p = index($0, anchor)
      s = substr($0, p)
      j = index(s, "`")
      s2 = ""
      if (j > 0) s2 = substr(s, j + 1)
      k = 0
      if (j > 0) k = index(s2, "`")
      if (j == 0 || k == 0) {
        printf "ticket-ops: FAIL: issues-README 第 %d 行锚点后反引号状态 token 缺失或未闭合——拒绝改写\n", FNR > "/dev/stderr"
        bad = 1
        print
        next
      }
      print substr($0, 1, p - 1) substr(s, 1, j) nstatus substr(s2, k)
      next
    }
    { print }
    END {
      rc = 0
      if (hits != 1) { printf "ticket-ops: FAIL: issues-README 状态行锚点命中 %d 行（须恰 1 行）: %s\n", hits, anchor > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${readme_file}" > "${tmp_readme}" || {
    rm -f "${tmp_readme}"; tmp_readme=''
    die1 "README 状态 token 替换未通过校验——索引已单写（${id} → ${status}），README 未写入；重跑同一命令即收敛"
  }
  record_lock_assert
  mv "${tmp_readme}" "${readme_file}"
  tmp_readme=''
  printf "ticket-ops: README 状态列替换: ${issues_readme_rel}（任务票 %s → \`%s\`，行内其余文本不动）\n" "${nn}" "${status}"
fi

# ---- 账本落行（票 228 F7 唯一写入方＝同目录 ledger-append.sh；票 243 状态操作幂等） ----
# 行形校验已于公共段经其 --check 零写入模式预检（fail-closed 时序：校验先于票务面任何
# 写入）。去重边界：只对状态操作（open/take/flip）判重——同一操作重跑不重复落行；
# `ledger` 无票入口保持只追加不判重（无「同一操作」概念，静默跳过会吞掉事实）。
if [ "${cmd}" = 'open' ] || [ "${cmd}" = 'take' ] || [ "${cmd}" = 'flip' ] || [ "${cmd}" = 'close' ]; then
  if ledger_row_exists; then
    printf 'ticket-ops: 账本行已在场（幂等跳过追加）: %s\n' "${ledger_rel}"
  else
    record_lock_assert
    RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
      sh "${ledger_cmd}" "${repo_root}" --ledger-line "${ledger_line}" || \
      die1 "账本落行未过（唯一写入方 ledger-append.sh fail-closed，详见上方输出）——已写部分如实报告；重跑同一命令即收敛"
  fi
  fault_point after-ledger-write
elif [ "${cmd}" = 'ledger' ]; then
  record_lock_assert
  RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
    sh "${ledger_cmd}" "${repo_root}" --ledger-line "${ledger_line}" || \
    die1 "账本落行未过（唯一写入方 ledger-append.sh fail-closed，详见上方输出）——未产生任何写入"
  fault_point after-ledger-write
fi

if [ "${cmd}" = 'ledger' ]; then
  : # 无票面写入收口（票 100）：不触索引/README/投影，仅账本落行（经唯一写入方承载）
  printf 'ticket-ops: PASS（ledger 完成：账本落行经 ledger-append.sh 承载，无票面写入——票 100 无票账本行入口）\n'
  exit 0
fi

# ---- 投影再生＋核对（唯一派生面；票 246 失败即非零退出，重跑幂等收敛） ----

record_lock_assert
sh "${gen_cmd}" "${repo_root}" || die1 "投影再生失败（生成器 exit 非 0）——已写部分如实报告：索引与 README 与账本均已写入、投影未刷新；按生成器报因处理后重跑同一命令即收敛"
fault_point after-projection-write
sh "${gen_cmd}" --check "${repo_root}" || die1 "投影一致性核对未过（--check exit 非 0）——已写部分如实报告：索引、README、账本与投影均已写入；投影与索引不一致，重跑同一命令即收敛"
printf 'ticket-ops: 投影已再生并核对: %s\n' "$progress_current_rel"

replay_note=''
if [ "${replay}" -eq 1 ]; then
  replay_note='（幂等重放）'
fi
if [ "${cmd}" = 'flip-index' ]; then
  printf 'ticket-ops: PASS（flip-index 完成：索引单写＋投影 --check 落地；不触 README/账本/票本体——票 228 F1/F2 索引单写代理）\n'
else
  printf 'ticket-ops: PASS（%s 完成%s：索引、issues-README、账本、投影 --check 全部落地）\n' "${cmd}" "${replay_note}"
fi
