#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与行式提交合同文件
#        （lane / ticket / whitelist / message / verify / record-only / verdict_quote /
#         verdict_at / flips），或记录提交入口形式 `--record-commit <repo-root>
#         <message> <记录路径>...`（票 247）。
# Output: 门禁核对、白名单产品提交、记录写入（票 229 记录写职责外移，本件零记录写入面：
#         user-review 道经同目录优先/PATH 回退定位 checkpoint-write.sh review-checkpoint
#         追加 User Review Checkpoint——.md 票追加票尾，.json 票体零追加、落独立
#         facts/requirements/tickets/<id>-review-checkpoint.md（票 108）；micro 道经唯一
#         写入方 ledger-append.sh --micro 落 facts/project/micro.jsonl 行——键序
#         date,lane,whitelist,gates,verify,commit,actual，行型合同＝agent-up 公开包
#         references/schemas/ledger-row.schema.json 的 micro_seven_key/micro_six_key_legacy
#         行族）、索引翻转与状态投影（flips 索引条目口径，票 228 F1/F2 写入方收敛：经
#         同目录 ticket-ops.sh flip-index 子命令代理——索引单写→投影再生→--check 收尾链
#         全仓仅 ticket-ops 一处承载，本件零直接 index.json 写入面与零直接生成器调用；
#         翻转至 done 时目录 README 结构 --check／生成块 --freshness 亦随该代理在 ticket-ops
#         内执行，收口失败即整体失败并指名文件与断言，本件不重复调用生成器（票 266））→
#         机械回写受影响票正文 **Status:** 行（.json 票体无 Status 行，跳过回写）；两段
#         提交的逐步输出，两段提交 ID、各自文件清单与翻转清单分列回报。
#         记录提交面（票 247）：第二段记录提交经单点入口 record_commit_run 承载——持票 246
#         同一把记录层写锁、只暂存 facts/ 记录路径、拒绝部分暂存（暂存内容≠工作区）、
#         只追加账本的 HEAD 旧内容须为待提交版本（暂存 blob）的字节前缀（前缀语义与
#         check-append-only.sh 同源）、对私有索引写出的树断言暂存面恰为记录路径（混提拒绝），
#         再经 write-tree/commit-tree/update-ref CAS 创建提交——断言对象＝被提交对象，共享索引
#         在提交窗口内被并发暂存（中间插入/产品文件）不卷入提交；成功后仅把仍是旧 HEAD 快照
#         的记录路径同步到新提交，并发暂存保留现场。任一不成立 fail-closed 零提交并报首个
#         违规行号。同一入口可独立调用：
#         `lane-commit.sh --record-commit <repo-root> <message> <记录路径>...`。
# Pos: 分级交付道快道收尾脚本（REQ-20260904-011 / 票 26；票 37 行为基线改造；票 229
#      职责拆分——白名单提交留本件，记录写入三类代理化：索引翻转→ticket-ops flip-index、
#      Review Checkpoint→checkpoint-write.sh、微账本→ledger-append.sh）；行为基线 =
#      development-process 模板 §12.5 道脚本承载注记（索引单写经 ticket-ops flip-index
#      代理 → 生成正文 Status 行 → 生成投影——票 34 定稿、票 228 写入方收敛后索引写入
#      与投影再生单点在 ticket-ops）与 R-RC-003（先产品提交后纯记录提交）；POSIX sh、零外部依赖、
#      fail-closed（门禁不过、合同格式不合预期、索引/生成器/记录写入方缺失即停止报告，不写
#      不补；预检先于产品提交，停止时零提交零写入）。脚本权限边界 = 提交合同白名单，不执行
#      白名单外任何写入；facts/requirements/tickets/README.md 与 facts/project/archive/progress.md
#      状态行不属本脚本写入面（README 状态列为人工登记投影，票 35/37 口径）。写入面路径
#      边界（票 144）：whitelist 条目、flips 目标与 ticket 票文件须为仓库根内普通相对文件，
#      ..、绝对路径、symlink 与 realpath 越出仓库根一律在写入前 fail-closed 拒绝。
#      记录提交入口（票 247）写入面＝显式记录路径（须在 facts/ 下）＋私有索引 CAS 提交；锁＝
#      common-helpers.sh record_lock_*（与 ticket-ops/ledger-append 同一把锁）；记录提交不运行
#      Git 提交钩子（commit-tree），也不写 HEAD reflog（update-ref 不含 --create-reflog）。

# 用法、合同行格式与输出格式见同目录 README.md。

# ---- 路径常量区（票 111 波②建立、票 113 波④翻值：治理路径集中于此；值＝rules/facts 新形态 R11-R15/R19）----

FACTS_TICKETS_INDEX='facts/requirements/tickets/index.json'
FACTS_TICKETS_PROGRESS='facts/requirements/tickets/progress-current.md'
FACTS_PROJECT_MICRO='facts/project/micro.jsonl'
RULES_SCRIPTS_DIR='rules/implementation/scripts'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'lane-commit: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

# 用途: 打印用法、合同行格式、翻转语义与退出码说明（本脚本的唯一人读规格入口）。
# 参数: 无。
# 副作用: 仅写 stdout（调用方按场景重定向到 stderr）；无文件读写、不改全局状态。
# 返回码: 恒 0（是否以 exit 0/2 结束由调用方决定）。
usage() {
  cat <<'USAGE'
用法: sh lane-commit.sh [repo-root] <contract-file>
      sh lane-commit.sh --record-commit <repo-root> <message> <记录路径>...
参数:
  repo-root      仓库根目录；缺省取当前目录所在 Git 仓库顶层（仅合同形式可缺省）。
  contract-file  行式提交合同文件（临时输入，不落仓库），行格式（均以行首列为准）:
                   lane: user-review|micro            （micro 道预检，票 58：白名单 ≤3 条目
                                                       且改动集零新建（??）零删除（D），
                                                       违者 exit 1；user-review 不受限）
                   ticket: <仓库根相对路径>          （user-review 必填；micro 不得出现；
                                                       票体 .md 或 .json——.md 票 Checkpoint
                                                       追加票尾，.json 票零追加、Checkpoint
                                                       落独立 facts/requirements/tickets/<id>-review-
                                                       checkpoint.md（<id>＝票文件去后缀），
                                                       票 108；写入经 checkpoint-write.sh）
                   whitelist: <逗号分隔相对路径>      （必填，单项或逗号多项）
                   message: <产品提交说明>            （必填）
                   verify: <验证命令>                 （一行一条，可多行；普通快道至少一条）
                   record-only: <纯记录理由>          （仅纯记录例外；须同时带唯一 verify: N/A）
                   verdict_quote: <用户裁决原文>      （user-review 必填；micro 不得出现）
                   verdict_at: <裁决时间>             （user-review 必填；micro 不得出现）
                   actual: <净工时（净工时口径文本）>  （micro 可选，票 100：记本次微收口
                                                       净工时，经 ledger-append --micro 落
                                                       微账本 actual 键；缺省空串既有六键行
                                                       向后兼容；user-review 不得出现——实际
                                                       用时落票本体 actual_time）
                   flips: <file>:<field>:<value>      （行翻转：一行一条，可多行；field
                                                       不得为 status 或 index；index.json
                                                       及其 realpath 别名不得作为通用目标）
                   flips: facts/requirements/tickets/index.json:index:<id>:<status>:<updated_at>
                                                     （索引条目翻转：user-review 道专用，
                                                       至多一条；id 须与 ticket 票文件名去
                                                       .md/.json 后缀一致；status 为状态机
                                                       裸值；updated_at 允许冒号，取行尾余段）
                 # 注释（行首 #）与空行忽略；其余行判合同格式错误（exit 1）。
                 行翻转语义: 锚点为字面子串，须恰命中一行，整行换成 value；通用 flips
                 直写 index.json 或其 realpath 别名于预检 exit 1，索引仅经专用 index 段
                 委托 ticket-ops。
                 索引条目翻转语义（单写机制，票 37；票 228 起经 ticket-ops 代理）: 调同目录
                 ticket-ops.sh flip-index 承载索引单写（"id" 锚点整行替换，仅改
                 status/updated_at 两值，其余字段原样保留；依赖一条目一行排版）→ 投影再生
                 （generate-progress.sh）并 --check 核对（收尾链全仓仅 ticket-ops 一处，票 228
                 F1/F2 写入方收敛；ticket-ops 同目录优先、PATH 回退，缺失＝预检停止
                 fail-closed）→ 机械回写 ticket 票正文 **Status:** 行（.json 票体无 Status 行，
                 跳过回写，票 108；投影打印件 `value`）。目标 status=done 时 flip-index 另过
                 ticket-ops 的双证门（actual_time＋ticket-audit --operation merge conformant，
                 票 237）与目录 README 两检（结构 --check＋生成块 --freshness，取锁前预检，
                 票 266）：
                 证据未提交/diff 失配/unknown/README 结构不合规即收尾停止（产品提交已创建、
                 记录提交未创建，decision-required），不采信自报 PASS。
                 记录写入委托（票 229，本脚本零 checkpoint/账本写入面）: user-review 道经
                 checkpoint-write.sh review-checkpoint 追加 User Review Checkpoint（stdout
                 末行 `checkpoint-write: 目标文件: <rel>` 为机器契约，目标登记进记录提交）；
                 micro 道经 ledger-append.sh --micro 落微账本行（唯一写入方）。两件均同目录
                 优先、PATH 回退，缺失＝收尾预检停止 fail-closed（先于产品提交）。
  -h / --help    打印本用法。
记录提交入口（--record-commit，票 247）: 两段式第二段的单点入口，也可独立调用。
  持票 246 同一把记录层写锁（Git 公共目录，跨 worktree 共享）→ 记录路径白名单（须在
  facts/ 下，防混提产品文件）→ 拒绝部分暂存（记录路径已在暂存区但与工作区不一致即
  拒绝，不静默重暂存）→ 记录路径须在工作树存在（删除/缺失即拒绝）→ 在私有索引
  （GIT_INDEX_FILE）上只 git add 记录路径（不写共享索引）→ 只追加账本
  （facts/project/changes.jsonl、facts/project/micro.jsonl）的 HEAD 旧内容须为待提交版本
  （私有索引 blob）的字节前缀（与 check-append-only.sh 同一原语）→ 对私有索引写出的树
  断言文件集恰为记录路径（含产品文件即拒绝）→ write-tree → commit-tree → update-ref CAS
  更新当前分支（旧 HEAD 不匹配即失败）。断言对象＝被提交对象；共享索引在窗口内被并发
  暂存不卷入提交，成功后仅同步仍是旧 HEAD 快照的记录路径条目，并发暂存保留现场。
  未改动的记录路径显式列为「已排除」后跳过，不计入提交文件集。
  失败语义: 任一断言不成立即 exit 1、零提交、不改写任何历史行；前缀违规报首个违规行号
  （待提交版行号）。失败不自动回滚暂存内容（不改写他人提交）。
  注: commit-tree 不运行 Git 提交钩子，update-ref 不写 HEAD reflog。
退出码: 0 全部完成；1 门禁不过或合同 fail-closed 条件（停止时未产生任何写入或提交）；
        2 用法或环境错误。
USAGE
}

# ---- 写入面路径边界（票 144）----
# 用途: 校验一个仓库根相对路径是否属本脚本写入面（仓库根内普通相对文件），三道检查
#       均在任何写入前执行：
#       ① 文本层：拒绝 ..（路径段）、绝对路径（/ 开头）与 ./ 前缀——仓库根相对普通文件
#          路径不得携带向上跳段或前缀点缀（文本层先行，防 realpath 前路径拼写歧义）；
#       ② realpath containment：目标物理 realpath 须位于仓库根物理 realpath 之下——
#          symlink 指向仓外（含 /tmp 夹具）、深层 .. 越界、大小写/规格化歧义一律在此拦出；
#       ③ 形态层：symlink 自身拒绝（-h）、仅普通文件（-f && ! -L）——目录不属写入面。
# 参数: $1=repo-root（仓库根目录）；$2=仓库根相对路径；$3=路径角色名（报因时指代来源，
#       如 whitelist 条目 / flips 目标 / ticket 票文件）。
# 副作用: 仅违规时向 stderr 打印一行 FAIL 报因；不写任何文件、不改全局状态（局部变量
#         以 _lir_ 前缀隔离）。
# 返回码: 0 校验通过（静默）；1 任一道检查违规（已向 stderr 报因）。
# POSIX 依赖仅 realpath（POSIX 2018 标准外部命令）与 test 探针；macOS/BSD/GNU 通用。
lc_in_repo() {
  _lir_root=$1
  _lir_path=$2
  _lir_what=$3
  case ${_lir_path} in
    ..|../*|*/..|*/../*|./*|*.|*/./*)
      printf 'lane-commit: FAIL: %s 不得含 .. 或 ./ 路径段: %s\n' "${_lir_what}" "${_lir_path}" >&2
      return 1
      ;;
    /*)
      printf 'lane-commit: FAIL: %s 须为仓库根相对路径，不得为绝对路径: %s\n' "${_lir_what}" "${_lir_path}" >&2
      return 1
      ;;
  esac
  _lir_probe=$(CDPATH='' cd -- "${_lir_root}" 2>/dev/null && pwd -P) || {
    printf 'lane-commit: FAIL: 仓库根不可解析为物理路径: %s\n' "${_lir_root}" >&2
    return 1
  }
  _lir_real=$(realpath "${_lir_root}/${_lir_path}" 2>/dev/null) || {
    printf 'lane-commit: FAIL: %s realpath 解析失败（目标不存在或中途断链）: %s\n' "${_lir_what}" "${_lir_path}" >&2
    return 1
  }
  case ${_lir_real} in
    "${_lir_probe}"/*) : ;;
    *)
      printf 'lane-commit: FAIL: %s 越出仓库根（realpath containment 失败）: %s → %s\n' "${_lir_what}" "${_lir_path}" "${_lir_real}" >&2
      return 1
      ;;
  esac
  [ ! -h "${_lir_root}/${_lir_path}" ] || {
    printf 'lane-commit: FAIL: %s 不得为 symlink: %s\n' "${_lir_what}" "${_lir_path}" >&2
    return 1
  }
  [ -f "${_lir_root}/${_lir_path}" ] || {
    printf 'lane-commit: FAIL: %s 须为仓库根内普通文件: %s\n' "${_lir_what}" "${_lir_path}" >&2
    return 1
  }
  return 0
}

tmp_gate=''
tmp_flip=''
tmp_rc_index=''
lock_owned=0

# ---- 记录提交单点入口（票 247：同锁串行＋前缀门＋私有索引 CAS 提交）----
# 用途: 见文件头「记录提交面」与 usage()：持票 246 同一把记录层写锁，以私有索引
#       （GIT_INDEX_FILE）只暂存 facts/ 记录路径，拒绝部分暂存（工作区与共享索引不一致），
#       断言只追加账本的 HEAD 旧内容须为待提交版本（私有索引 blob）的字节前缀（前缀原语
#       与 check-append-only.sh 同源），再对私有索引写出的树断言文件集恰为记录路径，最后
#       经 write-tree/commit-tree/update-ref CAS 创建提交。断言对象＝被提交对象；任一断言
#       不成立即 fail-closed 零提交（提交对象在 CAS 前不可达）。
# 参数: $1=repo-root；$2=提交说明；其余＝仓库根相对记录路径（至少一条，须在 facts/ 下）。
# 副作用: 取/放记录层写锁；在私有索引上 git add 记录路径（不写共享索引）；创建单个提交并
#         CAS 更新当前分支；成功后把记录路径的共享索引条目同步到新提交（保留并发暂存）。
#         失败路径不回滚已暂存内容、不改写他人提交与任何历史行。
# 返回码: 0 提交创建且树已核对；1 任一断言不成立（零提交）；2 用法或环境错误。
# 测试钩子: RECORD_COMMIT_TEST_MARKER＝私有索引快照完成后写入的标记文件路径；
#           RECORD_COMMIT_TEST_HOLD_MS＝写标记后延迟毫秒数（未设或 0＝零开销）。
# 全局: rc_commit_id 置为本次记录提交 ID。调用方须已把 IFS 设为换行（本文件口径）。
record_commit_run() {
  _rcr_root=$1
  _rcr_msg=$2
  shift 2
  [ $# -ge 1 ] || die1 '记录提交至少需要一条记录路径'
  [ -n "${_rcr_msg}" ] || die1 '记录提交说明为空'
  [ -d "${_rcr_root}" ] || die2 "仓库根不存在: ${_rcr_root}"
  git -C "${_rcr_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${_rcr_root}"

  # 记录路径白名单与写入面边界（只读预检，先于取锁；拒绝把产品文件混进记录提交）
  _rcr_paths=''
  for _rcr_p in "$@"; do
    case ${_rcr_p} in
      facts/*) : ;;
      *) die1 "记录提交拒绝：路径不在 facts/ 记录面内（只暂存记录路径，不得混提产品文件）: ${_rcr_p}" ;;
    esac
    [ -e "${_rcr_root}/${_rcr_p}" ] || \
      die1 "记录提交拒绝：记录路径在工作树不存在: ${_rcr_p}（删除与缺失不属于记录提交，零提交）"
    lc_in_repo "${_rcr_root}" "${_rcr_p}" '记录提交路径' || \
      die1 "记录提交路径边界校验未通过: ${_rcr_p}（须为仓库根内普通相对文件）"
    _rcr_needle="${NL}${_rcr_p}${NL}"
    case "${NL}${_rcr_paths}" in
      *"${_rcr_needle}"*) : ;;
      *) _rcr_paths="${_rcr_paths}${_rcr_p}${NL}" ;;
    esac
  done

  # 持锁（票 246 原语）：独立调用自取锁并负责释放；RECORD_LOCK_INHERITED=1 时按父进程
  # 传入的锁目录与令牌继承持有状态，跳过取锁与释放（锁生命周期归父进程）
  _rcr_own_lock=0
  if record_lock_inherit; then
    :
  else
    record_lock_init "${_rcr_root}"
    record_lock_acquire
    _rcr_own_lock=1
    lock_owned=1
  fi

  _rcr_t_dir=${TMPDIR:-/tmp}
  _rcr_staged=$(git -C "${_rcr_root}" diff --cached --name-only)

  # 部分暂存拒绝（票 247 AC2）：记录路径已在暂存区且暂存内容与工作区不一致即快照过期，
  # 拒绝而非静默重暂存；报首个差异行（待提交暂存版 → 工作区）。
  while IFS= read -r _rcr_p; do
    [ -n "${_rcr_p}" ] || continue
    _rcr_is_staged=0
    while IFS= read -r _rcr_s; do
      [ -n "${_rcr_s}" ] || continue
      if [ "${_rcr_s}" = "${_rcr_p}" ]; then
        _rcr_is_staged=1
      fi
    done <<EOF_STAGED
${_rcr_staged}
EOF_STAGED
    [ "${_rcr_is_staged}" -eq 1 ] || continue
    if git -C "${_rcr_root}" diff --quiet -- "${_rcr_p}"; then
      continue
    fi
    _rcr_idx=$(mktemp "${_rcr_t_dir%/}/record-idx.XXXXXX")
    _rcr_wt=$(mktemp "${_rcr_t_dir%/}/record-wt.XXXXXX")
    if ! git -C "${_rcr_root}" show ":${_rcr_p}" > "${_rcr_idx}" 2>/dev/null; then
      rm -f "${_rcr_idx}" "${_rcr_wt}"
      die1 "记录提交拒绝：读不出 ${_rcr_p} 的暂存内容（零提交）"
    fi
    cp "${_rcr_root}/${_rcr_p}" "${_rcr_wt}"
    _rcr_bad=$(record_first_bad_line "${_rcr_idx}" "${_rcr_wt}")
    if [ -z "${_rcr_bad}" ]; then
      _rcr_bad=$(( $(wc -l < "${_rcr_idx}" | tr -d ' ') + 1 ))
    fi
    rm -f "${_rcr_idx}" "${_rcr_wt}"
    die1 "记录提交拒绝：${_rcr_p} 暂存内容与工作区不一致（部分暂存，首个差异行 ${_rcr_bad}）——零提交；先 git add 该路径或撤销过期暂存后重跑"
  done <<EOF_PATHS
${_rcr_paths}
EOF_PATHS

  # 私有索引（票 247 D1）：从 HEAD 初始化到 GIT_INDEX_FILE 临时件，后续 git add 与全部
  # 断言都只作用于该索引——共享索引在提交窗口内被另一会话改写（中间插入/产品文件暂存）
  # 也不会被卷入提交，断言对象即被提交对象。
  _rcr_index=$(mktemp "${_rcr_t_dir%/}/record-index.XXXXXX") || \
    die1 '记录提交拒绝：无法创建私有索引（零提交）'
  rm -f "${_rcr_index}"
  tmp_rc_index=${_rcr_index}
  if git -C "${_rcr_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" read-tree HEAD || \
      die1 '记录提交拒绝：私有索引初始化失败（read-tree HEAD，零提交）'
  else
    GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" read-tree --empty || \
      die1 '记录提交拒绝：私有索引初始化失败（read-tree --empty，零提交）'
  fi

  # 只暂存记录路径到私有索引；add 后私有索引须与工作区一致（断言对象＝待提交 blob）
  while IFS= read -r _rcr_p; do
    [ -n "${_rcr_p}" ] || continue
    GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" add -- "${_rcr_p}" || \
      die1 "git add 失败（记录提交，私有索引）: ${_rcr_p}"
    GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" diff --quiet -- "${_rcr_p}" || \
      die1 "记录提交拒绝：${_rcr_p} 私有索引内容与工作区不一致（部分暂存）——零提交"
  done <<EOF_PATHS
${_rcr_paths}
EOF_PATHS

  # 前缀断言（票 247 AC1）：HEAD 旧内容须为待提交版本（暂存 blob）的字节前缀；非前缀即
  # 中间插入/改写/截断，报首个违规行号（待提交版行号），零提交、历史行零改写。
  while IFS= read -r _rcr_p; do
    [ -n "${_rcr_p}" ] || continue
    record_append_only_path "${_rcr_p}" || continue
    if ! git -C "${_rcr_root}" cat-file -e "HEAD:${_rcr_p}" 2>/dev/null; then
      continue
    fi
    _rcr_old=$(mktemp "${_rcr_t_dir%/}/record-old.XXXXXX")
    _rcr_new=$(mktemp "${_rcr_t_dir%/}/record-new.XXXXXX")
    if ! git -C "${_rcr_root}" show "HEAD:${_rcr_p}" > "${_rcr_old}" 2>/dev/null; then
      rm -f "${_rcr_old}" "${_rcr_new}"
      die1 "记录提交拒绝：读不出 HEAD:${_rcr_p}（零提交）"
    fi
    if ! GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" show ":${_rcr_p}" > "${_rcr_new}" 2>/dev/null; then
      rm -f "${_rcr_old}" "${_rcr_new}"
      die1 "记录提交拒绝：读不出 ${_rcr_p} 的待提交内容（私有索引，零提交）"
    fi
    if cmp -s "${_rcr_old}" "${_rcr_new}"; then
      rm -f "${_rcr_old}" "${_rcr_new}"
      continue
    fi
    if ! record_prefix_ok "${_rcr_old}" "${_rcr_new}"; then
      _rcr_bad=$(record_first_bad_line "${_rcr_old}" "${_rcr_new}")
      [ -n "${_rcr_bad}" ] || _rcr_bad='?'
      _rcr_old_size=$(wc -c < "${_rcr_old}" | tr -d ' ')
      _rcr_new_size=$(wc -c < "${_rcr_new}" | tr -d ' ')
      rm -f "${_rcr_old}" "${_rcr_new}"
      die1 "记录提交拒绝：${_rcr_p} 的 HEAD 旧内容非待提交版本前缀（中间插入或改写；HEAD ${_rcr_old_size} 字节 → 待提交 ${_rcr_new_size} 字节），首个违规行号 ${_rcr_bad}（待提交版行号）——零提交，历史行零改写"
    fi
    rm -f "${_rcr_old}" "${_rcr_new}"
  done <<EOF_PATHS
${_rcr_paths}
EOF_PATHS

  # 记录路径无实际改动即无提交可创建（零提交，不做空提交）；未改动路径显式告知排除，
  # 与 README「提交文件集恰为实际有改动的记录路径」措辞一致（票 247 D4）。
  _rcr_changed=0
  _rcr_unchanged=''
  while IFS= read -r _rcr_p; do
    [ -n "${_rcr_p}" ] || continue
    if GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" diff --cached --quiet -- "${_rcr_p}"; then
      _rcr_unchanged="${_rcr_unchanged}${_rcr_p}${NL}"
    else
      _rcr_changed=1
    fi
  done <<EOF_PATHS
${_rcr_paths}
EOF_PATHS
  [ "${_rcr_changed}" -eq 1 ] || die1 '记录路径无实际改动，无提交可创建（零提交）'
  if [ -n "${_rcr_unchanged}" ]; then
    printf 'lane-commit: 记录路径无改动，已排除: %s\n' \
      "$(printf '%s' "${_rcr_unchanged}" | paste -sd, -)"
  fi

  # 测试专用同步点（票 247 D3）：私有索引快照已完成、提交尚未创建时写标记文件；并发
  # 用例以标记文件为可观测事件（而非固定 sleep）决定 B 的写入时点，HOLD 仅放大持锁窗口。
  if [ -n "${RECORD_COMMIT_TEST_MARKER:-}" ]; then
    printf '%s\n' "$$" > "${RECORD_COMMIT_TEST_MARKER}" || \
      die1 '测试标记文件写入失败（RECORD_COMMIT_TEST_MARKER）'
  fi
  case ${RECORD_COMMIT_TEST_HOLD_MS:-} in
    ''|*[!0-9]*|0) : ;;
    *) sleep "$((RECORD_COMMIT_TEST_HOLD_MS / 1000)).$(printf '%03d' "$((RECORD_COMMIT_TEST_HOLD_MS % 1000))")" ;;
  esac

  # 提交前归属校验 + 合并态拒绝 + 私有索引写树（票 247 D1/D2）：文件集核对发生在提交
  # 创建之前，断言对象＝将被提交的树；核对通过后 commit-tree 只产生对象、update-ref CAS
  # 才移动分支，故任何失败路径都零可达提交。
  record_lock_assert
  if git -C "${_rcr_root}" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    die1 '合并进行中（MERGE_HEAD 在场）：记录提交不创建合并提交——零提交'
  fi
  _rcr_tree=$(GIT_INDEX_FILE="${_rcr_index}" git -C "${_rcr_root}" write-tree) || \
    die1 '记录提交拒绝：私有索引写树失败（零提交）'
  if git -C "${_rcr_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    _rcr_files=$(git -C "${_rcr_root}" diff-tree --no-commit-id --name-only -r HEAD "${_rcr_tree}")
  else
    _rcr_files=$(git -C "${_rcr_root}" ls-tree -r --name-only "${_rcr_tree}")
  fi
  [ -n "${_rcr_files}" ] || die1 '记录提交拒绝：待提交树与 HEAD 无差异（零提交）'
  while IFS= read -r _rcr_f; do
    [ -n "${_rcr_f}" ] || continue
    _rcr_fneedle="${NL}${_rcr_f}${NL}"
    case "${NL}${_rcr_paths}" in
      *"${_rcr_fneedle}"*) : ;;
      *) die1 "记录提交拒绝：待提交树含记录面外文件（记录提交与产品提交混提）: ${_rcr_f}——零提交；先提交或撤销该暂存后重跑" ;;
    esac
  done <<EOF_FILES
${_rcr_files}
EOF_FILES

  # 树→提交对象→分支 CAS：旧 HEAD 不匹配即失败（并发提交），commit 对象不可达、零提交。
  if git -C "${_rcr_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    _rcr_parent=$(git -C "${_rcr_root}" rev-parse HEAD)
    _rcr_commit=$(git -C "${_rcr_root}" commit-tree "${_rcr_tree}" -p "${_rcr_parent}" -m "${_rcr_msg}") || \
      die1 '记录提交拒绝：commit-tree 创建提交失败（零提交）'
  else
    _rcr_parent=''
    _rcr_commit=$(git -C "${_rcr_root}" commit-tree "${_rcr_tree}" -m "${_rcr_msg}") || \
      die1 '记录提交拒绝：commit-tree 创建提交失败（零提交）'
  fi
  _rcr_commit_tree=$(git -C "${_rcr_root}" rev-parse "${_rcr_commit}^{tree}") || \
    die1 '记录提交拒绝：读不出新提交树（零提交）'
  [ "${_rcr_commit_tree}" = "${_rcr_tree}" ] || \
    die1 '记录提交拒绝：新提交树与私有索引树不一致（内部错误，零提交）'
  _rcr_ref=$(git -C "${_rcr_root}" symbolic-ref -q HEAD) || \
    die1 '记录提交拒绝：HEAD 处于分离状态（须在分支上），零提交'
  record_lock_assert
  if [ -n "${_rcr_parent}" ]; then
    git -C "${_rcr_root}" update-ref -m 'lane-commit: 记录提交' \
      "${_rcr_ref}" "${_rcr_commit}" "${_rcr_parent}" || \
      die1 '记录提交拒绝：HEAD 已变化（并发提交竞态），零提交，重跑同一命令'
  else
    git -C "${_rcr_root}" update-ref -m 'lane-commit: 记录提交' \
      "${_rcr_ref}" "${_rcr_commit}" 0000000000000000000000000000000000000000 || \
      die1 '记录提交拒绝：分支已存在或 CAS 失败（零提交，重跑同一命令）'
  fi
  rc_commit_id=${_rcr_commit}

  # 提交后兜底（票 247 D2）：提交已可达，文件集核对不得再以 exit 1 收场（否则就是
  # 「报错但提交已创建」）；tree 与提交前核对一致，此分支正常不可达，只作内部错误诊断。
  if [ -n "${_rcr_parent}" ]; then
    _rcr_commit_files=$(git -C "${_rcr_root}" diff-tree --no-commit-id --name-only -r "${_rcr_commit}")
  else
    _rcr_commit_files=$(git -C "${_rcr_root}" diff-tree --root --no-commit-id --name-only -r "${_rcr_commit}")
  fi
  [ "${_rcr_commit_files}" = "${_rcr_files}" ] || \
    warn "记录提交文件集与提交前核对不一致（提交已创建，须人工审计）: ${_rcr_commit_files}"

  # 成功后把记录路径的共享索引同步到新提交：仅当共享索引仍是旧 HEAD 快照时改写，
  # 提交窗口内他人暂存的内容保留现场（不覆盖、不回滚；票 247 forbidden）。
  while IFS= read -r _rcr_p; do
    [ -n "${_rcr_p}" ] || continue
    _rcr_old_id=''
    _rcr_idx_id=''
    _rcr_new_id=''
    if [ -n "${_rcr_parent}" ]; then
      _rcr_old_id=$(git -C "${_rcr_root}" rev-parse -q --verify "${_rcr_parent}:${_rcr_p}" 2>/dev/null) || _rcr_old_id=''
    fi
    _rcr_idx_id=$(git -C "${_rcr_root}" rev-parse -q --verify ":${_rcr_p}" 2>/dev/null) || _rcr_idx_id=''
    _rcr_new_id=$(git -C "${_rcr_root}" rev-parse -q --verify "${rc_commit_id}:${_rcr_p}" 2>/dev/null) || _rcr_new_id=''
    if [ "${_rcr_idx_id}" = "${_rcr_new_id}" ]; then
      :
    elif [ "${_rcr_idx_id}" = "${_rcr_old_id}" ]; then
      git -C "${_rcr_root}" reset -q "${rc_commit_id}" -- "${_rcr_p}" || \
        warn "共享索引同步失败（记录提交已创建）: ${_rcr_p}——手工执行 git reset -q HEAD -- ${_rcr_p} 收敛"
    else
      warn "共享索引中 ${_rcr_p} 有并发暂存，已保留现场（记录提交已创建；不静默覆盖）"
    fi
  done <<EOF_PATHS
${_rcr_paths}
EOF_PATHS
  rm -f "${_rcr_index}"
  tmp_rc_index=''

  printf 'lane-commit: 记录提交门: 同锁串行（锁目录 %s）\n' "${RECORD_LOCK_DIR}"
  printf 'lane-commit: 记录提交 %s\n' "${rc_commit_id}"
  printf 'lane-commit: 记录文件: %s\n' "$(printf '%s\n' "${_rcr_files}" | paste -sd, -)"
  if [ "${_rcr_own_lock}" -eq 1 ]; then
    record_lock_release
    lock_owned=0
  fi
}

# 用途: EXIT/HUP/INT/TERM 陷阱体，清理本脚本创建的临时文件并释放本进程自取的记录层
#       写锁（票 247：独立记录提交失败路径不遗留锁；继承锁归父进程，不在此释放）。
# 参数: 无（读取全局 tmp_gate / tmp_flip / tmp_rc_index / lock_owned）。
# 副作用: 删除临时文件（rm -f 幂等，缺文件不报错）；lock_owned=1 时按令牌归属释放锁。
#         注：tmp_flip 分支先清空变量再调 rm，实际只删得掉 tmp_gate；这是既有实现形态，
#         本票仅文档化不改逻辑。（tmp_idx 随索引单写移交 ticket-ops flip-index 代理而撤除，票 228。）
#         记录提交私有索引（tmp_rc_index）在失败路径可能仍在场，一并清除；提交成功路径
#         已先 rm 并置空，此处 rm -f 幂等。
# 返回码: 恒 0（末条 if 不成立时 test 的假值不影响陷阱退出码语义）。
cleanup() {
  if [ -n "${tmp_gate}" ]; then rm -f "${tmp_gate}"; fi
  if [ -n "${tmp_flip}" ]; then tmp_flip=''; rm -f "${tmp_flip}"; fi
  if [ -n "${tmp_rc_index}" ]; then rm -f "${tmp_rc_index}"; tmp_rc_index=''; fi
  if [ "${lock_owned}" -eq 1 ]; then record_lock_release; lock_owned=0; fi
}
trap cleanup EXIT HUP INT TERM

record_mode=0
rc_message=''
if [ "${1:-}" = '--record-commit' ]; then
  record_mode=1
  shift
  if [ $# -lt 3 ]; then
    usage >&2
    exit 2
  fi
  repo_root=$1
  rc_message=$2
  shift 2
fi

if [ "${record_mode}" -eq 0 ]; then
  case $# in
    2)
      repo_root=$1
      contract=$2
      ;;
    1)
      case $1 in
        -h|--help) usage; exit 0 ;;
      esac
      # 仓库根推导统一经 resolve_repo_root（票 227 F4：--git 口径＝当前目录所在仓库顶层）
      repo_root=$(resolve_repo_root --git) || die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
      contract=$1
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
fi

[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"
if [ "${record_mode}" -eq 0 ]; then
  [ -r "${contract}" ] || die2 "合同文件不可读: ${contract}"
fi
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${repo_root}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

IFS=${NL}

# 记录提交入口（票 247）：独立调用走单点入口后即退出，不进入道合同流程
if [ "${record_mode}" -eq 1 ]; then
  record_commit_run "${repo_root}" "${rc_message}" "$@"
  exit 0
fi

[ -r "${script_dir}/check-gates.sh" ] || die2 '同目录 check-gates.sh 缺失，无法执行门禁核对'

# ---- 解析合同 ----

lane_seen=0
lane=''
ticket_seen=0
ticket=''
ticket_is_json=0
message_seen=0
message=''
vq_seen=0
verdict_quote=''
va_seen=0
verdict_at=''
actual_seen=0
actual=''
whitelist=''
verifies=''
record_only_seen=0
record_only=''
flips=''
n_index_flip=0

while IFS= read -r line || [ -n "${line}" ]; do
  case ${line} in
    ''|'#'*) continue ;;
    *:*)
      key=${line%%:*}
      val=${line#*:}
      val=$(printf '%s' "${val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      case ${key} in
        lane)
          [ "${lane_seen}" -eq 0 ] || die1 'lane 行重复'
          lane_seen=1
          lane=${val}
          ;;
        ticket)
          [ "${ticket_seen}" -eq 0 ] || die1 'ticket 行重复'
          ticket_seen=1
          ticket=${val}
          ;;
        message)
          [ "${message_seen}" -eq 0 ] || die1 'message 行重复'
          message_seen=1
          message=${val}
          ;;
        verdict_quote)
          [ "${vq_seen}" -eq 0 ] || die1 'verdict_quote 行重复'
          vq_seen=1
          verdict_quote=${val}
          ;;
        verdict_at)
          [ "${va_seen}" -eq 0 ] || die1 'verdict_at 行重复'
          va_seen=1
          verdict_at=${val}
          ;;
        actual)
          [ "${actual_seen}" -eq 0 ] || die1 'actual 行重复'
          actual_seen=1
          case ${val} in
            *"${TAB}"*) die1 "actual 行不得含制表符（JSON 行安全）: ${val}" ;;
          esac
          actual=${val}
          ;;
        whitelist)
          rest=${val}
          while [ -n "${rest}" ]; do
            entry=${rest%%,*}
            case ${rest} in
              *,*) rest=${rest#*,} ;;
              *) rest='' ;;
            esac
            entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${entry}" ] || die1 'whitelist 含空条目'
            whitelist="${whitelist}${entry}${NL}"
          done
          ;;
        verify)
          [ -n "${val}" ] || die1 'verify 行缺少命令'
          verifies="${verifies}${val}${NL}"
          ;;
        record-only)
          [ "${record_only_seen}" -eq 0 ] || die1 'record-only 行重复'
          [ -n "${val}" ] || die1 'record-only 行缺少理由'
          record_only_seen=1
          record_only=${val}
          ;;
        flips)
          [ -n "${val}" ] || die1 'flips 行缺少内容'
          case ${val} in
            *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
          esac
          f_file=${val%%:*}
          f_rest=${val#*:}
          case ${f_rest} in
            *:*) f_field=${f_rest%%:*} ; f_rest2=${f_rest#*:} ;;
            *) die1 "flips 行须为 file:field:value 三段: ${val}" ;;
          esac
          f_file=$(printf '%s' "${f_file}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          f_field=$(printf '%s' "${f_field}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          [ -n "${f_file}" ] || die1 "flips 行文件名为空: ${val}"
          [ -n "${f_field}" ] || die1 "flips 行 field 为空: ${val}"
          if [ "${f_field}" = 'index' ]; then
            # 索引条目翻转: <file>:index:<id>:<status>:<updated_at>（updated_at 取行尾余段，允许冒号）
            f_id=${f_rest2%%:*}
            f_rest3=${f_rest2#*:}
            case ${f_rest3} in
              "${f_rest2}") die1 "索引条目翻转须为 file:index:<id>:<status>:<updated_at> 五段: ${val}" ;;
            esac
            case ${f_rest3} in
              *:*) : ;;
              *) die1 "索引条目翻转缺 updated_at 段: ${val}" ;;
            esac
            f_status=${f_rest3%%:*}
            f_updated=${f_rest3#*:}
            case ${f_id} in
              *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
            esac
            [ "${f_file}" = "${FACTS_TICKETS_INDEX}" ] || \
              die1 "索引条目翻转目标须为 ${FACTS_TICKETS_INDEX}: ${f_file}"
            [ -n "${f_id}" ] || die1 "索引条目翻转 id 为空: ${val}"
            [ -n "${f_status}" ] || die1 "索引条目翻转 status 为空: ${val}"
            [ -n "${f_updated}" ] || die1 "索引条目翻转 updated_at 为空: ${val}"
            flips="${flips}${f_file}${TAB}index${TAB}${f_id}${TAB}${f_status}${TAB}${f_updated}${NL}"
            n_index_flip=$((n_index_flip + 1))
          else
            f_val=${f_rest2}
            f_val=$(printf '%s' "${f_val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${f_val}" ] || die1 "flips 行 value 为空: ${val}"
            case ${f_val} in
              *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
            esac
            flips="${flips}${f_file}${TAB}${f_field}${TAB}${f_val}${NL}"
          fi
          ;;
        *)
          die1 "无法识别的合同行: ${line}"
          ;;
      esac
      ;;
    *)
      die1 "无法识别的合同行: ${line}"
      ;;
  esac
done < "${contract}"

# ---- 合同语义校验（fail-closed，先于任何写入） ----

[ "${lane_seen}" -eq 1 ] || die1 '合同缺少 lane 行'
[ "${message_seen}" -eq 1 ] && [ -n "${message}" ] || die1 '合同缺少 message 行'
[ -n "${whitelist}" ] || die1 '合同缺少 whitelist 行或白名单为空'

# 普通快道必须有真实验证；纯记录例外必须显式声明理由并使用唯一 N/A 哨兵。
n_verify_lines=0
n_real_verify=0
n_na_verify=0
for vcmd in ${verifies}; do
  n_verify_lines=$((n_verify_lines + 1))
  if [ "${vcmd}" = 'N/A' ]; then
    n_na_verify=$((n_na_verify + 1))
  else
    n_real_verify=$((n_real_verify + 1))
  fi
done
if [ "${record_only_seen}" -eq 1 ]; then
  [ "${n_real_verify}" -eq 0 ] || die1 'record-only 不能同时携带真实 verify 命令'
  [ "${n_na_verify}" -eq 1 ] && [ "${n_verify_lines}" -eq 1 ] || die1 'record-only 必须携带唯一 verify: N/A'
else
  [ "${n_real_verify}" -gt 0 ] || die1 '普通快道至少需要一条 verify；纯记录请显式声明 record-only: <理由> 与 verify: N/A'
  [ "${n_na_verify}" -eq 0 ] || die1 'verify: N/A 仅允许与 record-only 一起使用'
fi

case ${lane} in
  user-review)
    { [ "${ticket_seen}" -eq 1 ] && [ -n "${ticket}" ]; } || die1 'user-review 道缺少 ticket 行'
    { [ "${vq_seen}" -eq 1 ] && [ -n "${verdict_quote}" ]; } || die1 'user-review 道缺少 verdict_quote 行'
    { [ "${va_seen}" -eq 1 ] && [ -n "${verdict_at}" ]; } || die1 'user-review 道缺少 verdict_at 行'
    [ "${actual_seen}" -eq 0 ] || die1 'user-review 道不得携带 actual 行（user-review 道实际用时落票本体 actual_time 字段，ticket-ops flip 收口硬拦——票 100）'
    [ -f "${repo_root}/${ticket}" ] || die1 "user-review 道票文件不存在: ${ticket}"
    lc_in_repo "${repo_root}" "${ticket}" 'ticket 票文件' || die1 'ticket 票文件路径边界校验未通过（票 144：须为仓库根内普通相对文件，写入前拒绝）'
    ;;
  micro)
    [ "${ticket_seen}" -eq 0 ] || die1 'micro 道免票，不得携带 ticket 行'
    [ "${vq_seen}" -eq 0 ] || die1 'micro 道不得携带 verdict_quote 行'
    [ "${va_seen}" -eq 0 ] || die1 'micro 道不得携带 verdict_at 行'
    # actual 行（票 100）：微道记净工时的合同行，落微账本 actual 键；既有六键行
    # （不带 actual 行）向后兼容，缺省空串（开放性口径：可后补不强制）。
    [ -n "$(printf '%s' "${actual}" | tr -d '[:space:]')" ] || actual=''
    ;;
  *)
    die1 "lane 取值须为 user-review 或 micro: ${lane}"
    ;;
esac

# 票体形态分类（票 108）：user-review 道票文件为 .json 时剥 .json 后缀得纯 id——flips id
# 校验与 checkpoint 独立承载分派的共同依据；其余票体沿用 .md 剥离口径（.md 之外不加新
# 约束，既有行为零变化）。
if [ "${lane}" = 'user-review' ]; then
  t_stem=${ticket##*/}
  case ${t_stem} in
    *.json)
      t_stem=${t_stem%.json}
      ticket_is_json=1
      ;;
    *)
      t_stem=${t_stem%.md}
      ticket_is_json=0
      ;;
  esac
fi

if [ "${n_index_flip}" -gt 0 ]; then
  [ "${lane}" = 'user-review' ] || die1 '索引条目翻转仅限 user-review 道（micro 道免票，无票状态可翻）'
  [ "${n_index_flip}" -eq 1 ] || die1 '索引条目翻转至多一条（单写口径，票 37）'
fi

# ---- 写入面路径边界预检（票 144：任何写入前完成；fail-closed 停止时零提交零写入）----
# whitelist 条目与 flips 目标逐一过 lc_in_repo：仓库根内普通相对文件（拒 ..、绝对路径、
# symlink、realpath 越出仓库根）。位置在车道语义校验之后、微道预检与全部写入之前；
# ticket 票文件已在 user-review 语义块内过同款校验。

for wpath in ${whitelist}; do
  lc_in_repo "${repo_root}" "${wpath}" 'whitelist 条目' || \
    die1 "whitelist 条目路径边界校验未通过: ${wpath}（票 144：须为仓库根内普通相对文件）"
done

for flip in ${flips}; do
  f_file=${flip%%"${TAB}"*}
  f_rest=${flip#*"${TAB}"}
  f_field=${f_rest%%"${TAB}"*}
  if [ "${f_file}" = "${FACTS_TICKETS_INDEX}" ] && [ "${f_field}" != 'index' ]; then
    die1 "通用 flips 不得直写索引文件: ${f_file}（index.json 唯一写入方＝ticket-ops.sh；索引翻转须用专用 index 段）"
  fi
  lc_in_repo "${repo_root}" "${f_file}" 'flips 目标' || \
    die1 "flips 目标路径边界校验未通过: ${f_file}（票 144：须为仓库根内普通相对文件）"
  if [ "${f_field}" != 'index' ] && [ -f "${repo_root}/${FACTS_TICKETS_INDEX}" ]; then
    _gf_target_real=$(realpath "${repo_root}/${f_file}" 2>/dev/null) || \
      die1 "通用 flips 目标 realpath 解析失败: ${f_file}"
    _gf_index_real=$(realpath "${repo_root}/${FACTS_TICKETS_INDEX}" 2>/dev/null) || \
      die1 "索引文件 realpath 解析失败: ${FACTS_TICKETS_INDEX}"
    if [ "${_gf_target_real}" = "${_gf_index_real}" ]; then
      die1 "通用 flips 不得直写索引文件: ${f_file}（与 ${FACTS_TICKETS_INDEX} 为同一物理文件；index.json 唯一写入方＝ticket-ops.sh）"
    fi
  fi
done

# ---- 微道预检（票 58：微道只修不建不删；user-review 道不受此限，行为零变化）----
# 两断言：①白名单条目 ≤3（超出属非微任务，改走 user-review 道开票收尾）；
# ②git status 改动集零新建（??）零删除（D）——微任务道准入即机械可验小改，新增/删除
# 文件超出口径；stop 时零写入零提交（本段先于翻转预检与门禁，任何 die1 均安全）。

if [ "${lane}" = 'micro' ]; then
  n_wl=$(printf '%s' "${whitelist}" | wc -w | tr -d ' ')
  [ "${n_wl}" -le 3 ] || die1 "微道白名单条目 ${n_wl} 个（须 ≤3，票 58）——超出属非微任务，改走 user-review 道开票收尾"
  st_out=$(git -C "${repo_root}" status --porcelain)
  while IFS= read -r stline; do
    [ -n "${stline}" ] || continue
    case ${stline} in
      '??'*) die1 "微道改动集含未跟踪新增（??）: ${stline#?? }——微道零新建（票 58），先入库或移出改动集" ;;
      'D'*|?'D'*) die1 "微道改动集含删除（D）: ${stline}——微道零删除（票 58）" ;;
    esac
  done <<EOF_ST
${st_out}
EOF_ST
fi

n_flip=0
record_files=''
for flip in ${flips}; do
  n_flip=$((n_flip + 1))
  f_file=${flip%%"${TAB}"*}
  f_rest=${flip#*"${TAB}"}
  f_field=${f_rest%%"${TAB}"*}
  [ -f "${repo_root}/${f_file}" ] || {
    if [ "${f_field}" = 'index' ]; then
      die1 "索引文件缺失: ${f_file}（票状态真相源，单写不可执行）——先由对应阶段执行体建立索引（issue-index.schema），或改走非快道收尾"
    fi
    die1 "翻转目标文件不存在: ${f_file}"
  }
  fneedle="${NL}${f_file}${NL}"
  case "${NL}${record_files}" in
    *"${fneedle}"*) : ;;
    *) record_files="${record_files}${f_file}${NL}" ;;
  esac
done

# ---- 翻转锚点与索引/生成器预检（只扫描不写入；任何不合规在写入前停止） ----

# 用途: 对单个文件做一次翻转运算并输出结果（不落地）——body 模式整行替换 `**Status:**` 行
#       （投影打印件形态），line 模式把字面锚点所在行整行换成新值；命中行数须恰为 1，用作
#       写入前预检（输出到 /dev/null）与写入期生成（输出到临时文件、由调用方 mv 落位）。
# 参数: $1=仓库根相对文件路径；$2=输出目标路径（/dev/null 即只校验不产出）；$3=模式
#       body|line；$4=锚点（仅 line 模式使用，按字面子串匹配；body 模式传空串）；$5=替换值。
#       经由环境变量 MODE/ANCHOR/VALUE 传入 awk，避免 awk -v 转义歧义。
# 副作用: 写 $2（调用方给的临时文件或 /dev/null）；不合规时向 stderr 打印一行 FAIL 报因。
#         不改仓库内文件（落位由调用方 mv 完成）。依赖全局 repo_root。
# 返回码: 0 命中恰 1 行且已产出；1 命中 0 行或多行（body 模式即 Status 行数 ≠ 1）。
flip_run() {
  MODE=$3 ANCHOR=$4 VALUE=$5 awk '
    BEGIN {
      MODE = ENVIRON["MODE"]
      anchor = ENVIRON["ANCHOR"]
      value = ENVIRON["VALUE"]
    }
    MODE == "body" && $0 ~ /^\*\*Status:\*\*/ {
      body++
      print "**Status:** `" value "`"
      next
    }
    MODE == "line" && index($0, anchor) > 0 {
      hits++
      print value
      next
    }
    { print }
    END {
      rc = 0
      if (MODE == "body") {
        if (body != 1) { printf "lane-commit: FAIL: %s 正文 Status 行命中 %d 行（须恰 1 行）\n", FILENAME, body > "/dev/stderr"; rc = 1 }
      } else {
        if (hits != 1) { printf "lane-commit: FAIL: %s 翻转锚点命中 %d 行（须恰 1 行）\n", FILENAME, hits > "/dev/stderr"; rc = 1 }
      }
      exit rc
    }
  ' "${repo_root}/$1" > "$2"
}

# 用途: 索引单写前的只读预检——核对 index.json 的「一条目一行」排版未被破坏（每个条目行
#       须同行带 status/updated_at），且目标 id 锚点全文恰命中 1 行；零命中或多命中即不执行单写。
# 参数: $1=索引条目 id（票文件去 .md/.json 后缀的纯 id，形如 <NN>-<slug>）。
# 副作用: 只读，不写文件；不合规时向 stderr 打印一行 FAIL 报因。依赖全局
#         repo_root 与 FACTS_TICKETS_INDEX。
# 返回码: 0 预检通过；1 排版破坏、条目零命中或锚点多命中任一成立。
index_precheck() {
  _id=$1
  IDX_ID=${_id} awk '
    BEGIN {
      id = ENVIRON["IDX_ID"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "lane-commit: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——一条目一行排版被破坏（票 33 终裁 T2）\n", FNR > "/dev/stderr"
        bad = 1
      }
      if (index($0, anchor) > 0) hits++
    }
    END {
      rc = 0
      if (n == 0) { printf "lane-commit: FAIL: 索引中未找到条目行（\"id\": 锚点零命中）\n" > "/dev/stderr"; rc = 1 }
      if (hits != 1) { printf "lane-commit: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${repo_root}/${FACTS_TICKETS_INDEX}"
}

# 用途: 索引单写代理定位（票 228 F1/F2 写入方收敛：索引翻转改调同目录 ticket-ops.sh
#       flip-index 子命令承载索引单写＋投影再生＋--check 收尾链，本件零直接 index.json
#       写入面与零直接生成器调用）；同目录优先，PATH 回退；缺失即预检停止。
# PATH 回退手动迭代而非 command -v：落位脚本不要求可执行位（恒经 sh 调用），
# command -v 对不可执行文件不报告。
to_cmd=''
if [ "${n_index_flip}" -gt 0 ]; then
  if [ -f "${script_dir}/ticket-ops.sh" ] && [ -r "${script_dir}/ticket-ops.sh" ]; then
    to_cmd="${script_dir}/ticket-ops.sh"
    printf 'lane-commit: 票务代理定位: 同目录 %s\n' "${to_cmd}"
  else
    _rest=${PATH:-}
    while [ -n "${_rest}" ]; do
      _dir=${_rest%%:*}
      case ${_rest} in
        *:*) _rest=${_rest#*:} ;;
        *) _rest='' ;;
      esac
      [ -n "${_dir}" ] || continue
      if [ -f "${_dir}/ticket-ops.sh" ] && [ -r "${_dir}/ticket-ops.sh" ]; then
        to_cmd="${_dir}/ticket-ops.sh"
        break
      fi
    done
    if [ -n "${to_cmd}" ]; then
      printf 'lane-commit: 票务代理定位: PATH %s\n' "${to_cmd}"
    else
      die1 "票务代理 ticket-ops.sh 不可用（同目录与 PATH 均未找到）——收尾预检停止：index.json 唯一写入方＝ticket-ops.sh（票 228 F1/F2 写入方收敛，索引单写→投影再生→--check 收尾链全仓仅其一处），将 ticket-ops.sh 落位到本脚本同目录（${RULES_SCRIPTS_DIR}/）或 PATH 后重跑"
    fi
  fi
fi

# ---- 记录写入代理定位（票 229：checkpoint-write.sh／ledger-append.sh）----
# 用途: 同目录优先、PATH 回退定位记录写入方（口径同票务代理定位：落位脚本不要求可执行位，
#       恒经 sh 调用；PATH 回退手动迭代）。命中打印路径，缺失返回 1。
lc_locate() {
  _llt_name=$1
  if [ -f "${script_dir}/${_llt_name}" ] && [ -r "${script_dir}/${_llt_name}" ]; then
    printf '%s\n' "${script_dir}/${_llt_name}"
    return 0
  fi
  _llt_rest=${PATH:-}
  while [ -n "${_llt_rest}" ]; do
    _llt_dir=${_llt_rest%%:*}
    case ${_llt_rest} in
      *:*) _llt_rest=${_llt_rest#*:} ;;
      *) _llt_rest='' ;;
    esac
    [ -n "${_llt_dir}" ] || continue
    if [ -f "${_llt_dir}/${_llt_name}" ] && [ -r "${_llt_dir}/${_llt_name}" ]; then
      printf '%s\n' "${_llt_dir}/${_llt_name}"
      return 0
    fi
  done
  return 1
}

# 预检先于产品提交：任一记录写入方缺失即收尾停止（停止时零提交零写入）。
cw_cmd=''
la_cmd=''
if [ "${lane}" = 'user-review' ]; then
  cw_cmd=$(lc_locate checkpoint-write.sh) || die1 "记录写入代理 checkpoint-write.sh 不可用（同目录与 PATH 均未找到）——收尾预检停止：User Review Checkpoint 唯一写入方＝checkpoint-write.sh（票 229 职责拆分），将其落位到本脚本同目录（${RULES_SCRIPTS_DIR}/）或 PATH 后重跑"
  printf 'lane-commit: 记录写入代理定位: %s\n' "${cw_cmd}"
fi
if [ "${lane}" = 'micro' ]; then
  la_cmd=$(lc_locate ledger-append.sh) || die1 "记录写入代理 ledger-append.sh 不可用（同目录与 PATH 均未找到）——收尾预检停止：微账本 facts/project/micro.jsonl 唯一写入方＝ledger-append.sh（票 229 职责拆分），将其落位到本脚本同目录（${RULES_SCRIPTS_DIR}/）或 PATH 后重跑"
  printf 'lane-commit: 记录写入代理定位: %s\n' "${la_cmd}"
fi

for flip in ${flips}; do
  f_field=$(printf '%s' "${flip}" | cut -f 2)
  f_file=${flip%%"${TAB}"*}
  if [ "${f_field}" = 'index' ]; then
    f_id=$(printf '%s' "${flip}" | cut -f 3)
    f_status=$(printf '%s' "${flip}" | cut -f 4)
    f_updated=$(printf '%s' "${flip}" | cut -f 5)
    printf '%s' "${f_id}" | grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
      die1 "索引条目 id 不合 issue-index schema 口径（^[0-9]{2,}-[a-z0-9-]+$）: ${f_id}"
    printf '%s' "${f_status}" | grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || \
      die1 "索引条目 status 不合状态机取值（裸值，不带冒号后缀）: ${f_status}"
    printf '%s' "${f_updated}" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' || \
      die1 "索引条目 updated_at 不合 ISO 8601 口径（YYYY-MM-DDTHH:MM[:SS]）: ${f_updated}"
    [ "${f_id}" = "${t_stem}" ] || \
      die1 "索引条目 id 与 ticket 票文件不符: ${f_id} ≠ ${t_stem}（正文 Status 回写目标由 ticket 行决定）"
    index_precheck "${f_id}" || die1 "索引预检未通过: ${FACTS_TICKETS_INDEX}（${f_id}）——单写已取消，未产生任何写入或提交"
    if [ "${ticket_is_json}" -eq 0 ]; then
      flip_run "${ticket}" /dev/null body '' "${f_status}" || \
        die1 "正文 Status 回写预检未通过: ${ticket}"
    fi
  elif [ "${f_field}" = 'status' ]; then
    die1 "flips 行 field=status 已退役：票状态经索引条目翻转承载（flips: ${FACTS_TICKETS_INDEX}:index:<id>:<status>:<updated_at>，票 37）"
  else
    f_rest=${flip#*"${TAB}"}
    f_val=${f_rest#*"${TAB}"}
    flip_run "${f_file}" /dev/null line "${f_field}" "${f_val}" || \
      die1 "翻转锚点预校验未通过: ${f_file}（${f_field}）"
  fi
done

# ---- 门禁核对（调用同目录 check-gates.sh，只读） ----

t_dir=${TMPDIR:-/tmp}
tmp_gate=$(mktemp "${t_dir%/}/lane-gates.XXXXXX")
{
  printf 'whitelist: %s\n' "$(printf '%s' "${whitelist}" | paste -sd, -)"
  if [ "${record_only_seen}" -eq 1 ]; then
    printf 'record-only: %s\n' "${record_only}"
  fi
  for vcmd in ${verifies}; do
    printf 'verify: %s\n' "${vcmd}"
  done
} > "${tmp_gate}"

grc=0
sh "${script_dir}/check-gates.sh" "${repo_root}" "${tmp_gate}" || grc=$?
if [ "${grc}" -eq 1 ]; then
  die1 '门禁核对未通过（见上方 check-gates 输出），未产生任何写入或提交'
fi
if [ "${grc}" -ne 0 ]; then
  die2 "check-gates.sh 用法或环境错误（exit ${grc}）"
fi

# ---- 产品提交（白名单内暂存，防御性核对后提交） ----

for wpath in ${whitelist}; do
  git -C "${repo_root}" add -- "${wpath}" || die1 "git add 失败: ${wpath}"
done

staged=$(git -c core.quotePath=false -C "${repo_root}" diff --cached --name-only)
[ -n "${staged}" ] || die1 '白名单内无实际改动，无提交可创建'
for spath in ${staged}; do
  sneedle="${NL}${spath}${NL}"
  case "${NL}${whitelist}" in
    *"${sneedle}"*) : ;;
    *) die1 "防御性核对失败：暂存内容越出白名单: ${spath}" ;;
  esac
done

git -C "${repo_root}" commit -m "${message}" || die1 '产品提交创建失败'
cid1=$(git -C "${repo_root}" rev-parse HEAD)
subject1=$(git -C "${repo_root}" log -1 --format=%s "${cid1}")
diffsum1=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-status -r "${cid1}" | tr '\t' ' ' | paste -sd, -)

# ---- 记录写入（索引单写 → 正文 Status 回写 → 行翻转 → Checkpoint / 微账本 → 投影再生） ----

date_today=$(date +%F)

for flip in ${flips}; do
  f_field=$(printf '%s' "${flip}" | cut -f 2)
  f_file=${flip%%"${TAB}"*}
  if [ "${f_field}" = 'index' ]; then
    f_id=$(printf '%s' "${flip}" | cut -f 3)
    f_status=$(printf '%s' "${flip}" | cut -f 4)
    f_updated=$(printf '%s' "${flip}" | cut -f 5)
    # 索引单写经 ticket-ops flip-index 代理（票 228 F1/F2 写入方收敛）：索引锚点整行替换
    # ＋投影再生＋--check 收尾链由代理一处承载；目标状态 done 时代理另在取锁与写入前
    # 跑目录 README 结构 --check／生成块 --freshness（票 266），失败即同等收尾停止——
    # 本件不重复调用生成器。
    # 失败即收尾停止（产品提交已创建，如实报告，重跑幂等——已翻条目再跑无副作用）。
    sh "${to_cmd}" "${repo_root}" flip-index --id "${f_id}" --status "${f_status}" --updated-at "${f_updated}" || \
      die1 "索引翻转代理未过（ticket-ops flip-index fail-closed，详见上方输出）——收尾停止：产品提交 ${cid1} 已创建、记录提交未创建；核对索引排版与代理报因后重跑（幂等，已翻条目再跑无副作用）"
    printf "lane-commit: 索引翻转已代理: ${FACTS_TICKETS_INDEX}（%s → %s，updated_at %s；索引单写＋投影再生 --check 经 ticket-ops flip-index 承载；至 done 时另含目录 README --check/--freshness）\n" "${f_id}" "${f_status}" "${f_updated}"
    if [ "${ticket_is_json}" -eq 1 ]; then
      # .json 票体无 **Status:** 行（状态唯一真相源＝索引），跳过正文回写（票 108）
      printf 'lane-commit: 跳过正文 Status 回写: %s（.json 票体无 **Status:** 行，状态唯一真相源＝索引）\n' "${ticket}"
    else
      tmp_flip=$(mktemp "${t_dir%/}/lane-flip.XXXXXX")
      flip_run "${ticket}" "${tmp_flip}" body '' "${f_status}" || {
        rm -f "${tmp_flip}"
        tmp_flip=''
        die1 "正文 Status 回写未通过锚点校验: ${ticket}——收尾停止：产品提交 ${cid1} 已创建、索引已单写、记录提交未创建"
      }
      mv "${tmp_flip}" "${repo_root}/${ticket}"
      tmp_flip=''
      # shellcheck disable=SC2016  # sed/awk 程序刻意字面 $（引号形态由程序语义决定；wiki 长尾误报）
      printf 'lane-commit: 正文 Status 回写（投影打印件）: %s → **Status:** `%s`\n' "${ticket}" "${f_status}"
    fi
    proj_file=${FACTS_TICKETS_PROGRESS}
    fneedle="${NL}${proj_file}${NL}"
    case "${NL}${record_files}" in
      *"${fneedle}"*) : ;;
      *) record_files="${record_files}${proj_file}${NL}" ;;
    esac
  else
    f_rest=${flip#*"${TAB}"}
    f_val=${f_rest#*"${TAB}"}
    tmp_flip=$(mktemp "${t_dir%/}/lane-flip.XXXXXX")
    flip_run "${f_file}" "${tmp_flip}" line "${f_field}" "${f_val}" || {
      rm -f "${tmp_flip}"
      tmp_flip=''
      die1 "翻转写入未通过锚点校验: ${f_file}（${f_field}）"
    }
    mv "${tmp_flip}" "${repo_root}/${f_file}"
    tmp_flip=''
    printf 'lane-commit: 翻转: %s:%s:%s\n' "${f_file}" "${f_field}" "${f_val}"
  fi
done

# ---- 记录写入（票 229：记录写职责全部外移，本件零 checkpoint/账本写入面）----
# Review Checkpoint 经 checkpoint-write.sh 写入（.md 票追加票尾；.json 票体零追加，落独立
# checkpoint md——票 108 两种票体记录块同格式由代理保证），代理 stdout 末行
# `checkpoint-write: 目标文件: <rel>` 为机器契约，据此登记记录提交面；微账本经唯一写入方
# ledger-append.sh --micro 落行（行族合同与 JSON 转义由写入方承载）。

if [ "${lane}" = 'user-review' ]; then
  ck_out=$(sh "${cw_cmd}" "${repo_root}" review-checkpoint \
    --ticket "${ticket}" \
    --verdict-quote "${verdict_quote}" \
    --verdict-at "${verdict_at}" \
    --commit "${cid1}" \
    --commit-subject "${subject1}" \
    --diff-summary "${diffsum1}" \
    --date "${date_today}") || die1 "User Review Checkpoint 写入代理未过（checkpoint-write.sh fail-closed，详见上方输出）——收尾停止：产品提交 ${cid1} 已创建、记录提交未创建"
  printf '%s\n' "${ck_out}"
  ck_target=$(printf '%s\n' "${ck_out}" | sed -n 's/^checkpoint-write: 目标文件: //p' | tail -n 1)
  [ -n "${ck_target}" ] || die1 'User Review Checkpoint 写入代理未返回目标文件行（checkpoint-write 输出契约破坏）——收尾停止：产品提交已创建、记录提交未创建'
  tneedle="${NL}${ck_target}${NL}"
  case "${NL}${record_files}" in
    *"${tneedle}"*) : ;;
    *) record_files="${record_files}${ck_target}${NL}" ;;
  esac
fi

if [ "${lane}" = 'micro' ]; then
  wl_joined=$(printf '%s' "${whitelist}" | paste -sd, -)
  n_verify=$(printf '%s' "${verifies}" | grep -c . || true)
  sh "${la_cmd}" "${repo_root}" --micro \
    --date "${date_today}" \
    --whitelist "${wl_joined}" \
    --verify "${n_verify}" \
    --commit "${cid1}" \
    --actual "${actual}" || die1 "微账本落行代理未过（ledger-append.sh --micro fail-closed，详见上方输出）——收尾停止：产品提交 ${cid1} 已创建、记录提交未创建"
  record_files="${record_files}${FACTS_PROJECT_MICRO}${NL}"
fi

# 投影再生与 --check 已随索引翻转在 ticket-ops flip-index 代理内完成（票 228 F1/F2：
# 写索引→generate-progress 再生→--check 收尾链全仓仅 ticket-ops 一处承载，本件零直接
# 生成器调用）；翻转至 done 时的目录 README --check/--freshness 同在该代理内执行
# （票 266），本件不重复调用生成器；progress-current.md 由记录提交一并收编（record_files 登记面不变）。

# ---- 记录提交（两段式第二段，R-RC-003；票 247：持同一把锁的前缀门单点入口） ----
# 记录路径经 record_commit_run 单点提交：同锁串行（与 ticket-ops/ledger-append 一把锁）→
# 只暂存记录路径到私有索引 → 拒绝部分暂存 → 只追加账本 HEAD 须为待提交版前缀 → 私有索引
# 写出的树文件集恰为记录路径（混提拒绝）→ commit-tree + update-ref CAS（断言对象＝被提交树）。

set -f
# shellcheck disable=SC2086  # 路径清单按换行分隔、刻意不加引号切分（记录路径不含空白与通配符；set -f 已关通配）
record_commit_run "${repo_root}" "chore(lane): 记录翻转 — ${message}" ${record_files}
set +f
cid2=${rc_commit_id}

# ---- 回报 ----

c1_files=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-only -r "${cid1}" | paste -sd, -)
c2_files=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-only -r "${cid2}" | paste -sd, -)
printf 'lane-commit: 产品提交 %s\n' "${cid1}"
printf 'lane-commit: 产品文件: %s\n' "${c1_files}"
printf 'lane-commit: 记录提交 %s\n' "${cid2}"
printf 'lane-commit: 记录文件: %s\n' "${c2_files}"
printf 'lane-commit: PASS（两段式完成：门禁 PASS、索引单写 %d 处、翻转 %d 项、投影与目录 README 收口已核对、记录已落盘）\n' "${n_index_flip}" "${n_flip}"
