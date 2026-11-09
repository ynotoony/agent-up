#!/bin/sh
# Input: 任务票编号前缀 <NN>、仓库根（缺省当前 Git 仓库）、审查收据文件（缺省
#        facts/requirements/tickets/<NN>-*.review-evidence.json）、审计策略文件（缺省
#        facts/requirements/audit-policy.json）与操作面 --operation（read/analyze/merge/
#        push）；--operation push 与 --range <base>..<head> 同给时切批量面（--max-commits
#        缺省 50、--skip <sha> 可重复），区间取 base..head 逐提交判定：merge 提交查 head
#        树内 *.review-evidence.json 的 head_sha 是否绑定该提交，单亲提交按 head 树内
#        index.json 的票 status 兜底；收据格式合同＝../references/schemas/receipt.schema.json，
#        证据定位经 git ls-tree／rev-parse／hash-object／merge-base／diff 只读事实。
# Output: 单票面：逐谓词一行（PASS/FAIL/UNKNOWN＋谓词号与名＋文件:行号＋原因）、证据位置
#         追溯行（路径@提交:blob）、操作面允许/拒绝行与三值判定行（conformant/
#         nonconformant/unknown）；退出码 0＝conformant 或 unknown 下的读/分析，1＝
#         nonconformant 或 unknown 下的 merge/push，2＝用法或环境错误。
#         批量面：逐提交一行 `ticket-audit: 批量 <短 sha> <conformant|nonconformant|
#         unknown|skip> <依据>` 与批量判定汇总行；退出码 0＝全部 conformant（含空区间），
#         1＝任一非 conformant，2＝用法或环境错误。全程只读零写入。
# Pos: 记录层证据审计引擎（Review 证据绑定 base/diff 的最小 Git 事实判断）：只回答
#      「证据是否已提交、是否绑定当前产品提交、审查者身份是否可佐证、策略是否适用」，
#      不宣称能证明不可验证的独立身份——无法核验即 unknown，不以 unknown 阻断读/分析。
#      POSIX sh＋python3（唯一 JSON 引擎）＋source common-helpers.sh；安装闭包随
#      ticket-ops 门控同落位。回归＝tests/ 的 ticket-audit 套件。
#      谓词注册表化并分片（票 289）：执行顺序与分片定位单源＝同目录 audit-predicates.rules，
#      每谓词一件 audit-pNN-slug.sh 分片同进程 source；引擎只做配置加载、Git 事实定位、
#      分派与汇总判定，谓词判定逻辑全在分片内（新增谓词＝加分片＋注册表一行）。
#      票 237 补正：base==head 或 base..head 为空 diff 时 P05 判非 conformant 并指名
#      原因——零实现 diff 不得作为绑定实现的审查收据收口。
#      票 262 补批量/推送面：显式 --range 逐提交判定，无收据 merge 提交指名票 id 与
#      失败谓词 P01，ff 合并（单亲提交）按 head 树索引 status 兜底；标题票号只给裸号
#      时按 head 树索引 ^<NN>- 前缀唯一解析为全 slug（零命中/多命中均指名拒绝）；
#      不替代、不放宽单票 merge 面证据门，未给 --range 时单票行为逐字不变。

# shellcheck disable=SC2034,SC2329  # 分片共享上下文（TICKET_ID/辅助函数由同进程 source 的谓词分片消费），单文件视野误报
set -eu
set -f

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
_helper_script=$SCRIPT_DIR/common-helpers.sh
if [ ! -f "$_helper_script" ]; then
  printf 'ticket-audit: FAIL: 共享库缺失（同目录定位）: %s\n' "$_helper_script" >&2
  exit 2
fi
# shellcheck source=agent-up/scripts/common-helpers.sh
. "$_helper_script"

JSON_ENGINE=$SCRIPT_DIR/json-validator.py
[ -f "$JSON_ENGINE" ] || die2 "唯一 JSON 引擎缺失（同目录定位）: $JSON_ENGINE"
command -v python3 >/dev/null 2>&1 || die2 'python3 不可用——收据与策略解析依赖唯一 JSON 引擎'
command -v git >/dev/null 2>&1 || die2 'git 不可用——本引擎只做 Git 事实判断'
command -v awk >/dev/null 2>&1 || die2 'awk 不可用——日期分界比较依赖 POSIX awk'

# shellcheck disable=SC2317  # 唯一 JSON 引擎包装：失败由调用方判读退出码
jget() { python3 "$JSON_ENGINE" json get "$@" 2>/dev/null; }
jlen() { python3 "$JSON_ENGINE" json len "$@" 2>/dev/null; }
# shellcheck disable=SC2317  # 唯一 JSON 引擎包装：失败由调用方判读退出码
json_readable() { python3 "$JSON_ENGINE" json get "$1" '' >/dev/null 2>&1; }

usage() {
  cat <<'USAGE'
用法: sh ticket-audit.sh [<NN>] [选项]
  <NN>                 任务票编号前缀（≥2 位数字）；单票面必填，定位
                       facts/requirements/tickets/<NN>-*.json 恰一命中；批量面可省略
                       （逐提交票 id 取自提交标题）
  --repo <dir>         仓库根（缺省＝git rev-parse --show-toplevel）
  --operation <op>     read | analyze | merge | push（缺省 analyze）
  --range <a>..<b>     批量/推送面：对显式区间逐提交审计（仅与 --operation push 同用；
                       a/b 为 40 位小写提交号，a 须为 b 祖先）
  --max-commits <n>    批量区间提交数上限（缺省 50；超限 exit 2 并指名实际条数与上限）
  --skip <sha>         批量面豁免的提交（完整 40 位小写十六进制，可重复；输出 skip 行）
  --evidence <path>    审查收据路径（缺省＝<票文件>.review-evidence.json）
  --policy <path>      审计策略路径（缺省＝facts/requirements/audit-policy.json）
  --allow-after <rel>  额外允许出现在 head 之后的仓库根相对路径（可重复；缺省仅证据
                       文件。调用方显式传入记录载体，禁止整体放开 facts/或任意文件）
  -h / --help          打印本用法
退出码: 0＝conformant，或 unknown 下的 read/analyze；1＝nonconformant，或 unknown 下的
        merge/push；2＝用法或环境错误。批量面：0＝全部 conformant（含空区间），1＝任一
        非 conformant。
批量输出行: ticket-audit: 批量 <短 sha> <conformant|nonconformant|unknown|skip> <依据>
谓词: P01 收据可解析 / P02 证据已提交 / P03 base 可溯 / P04 审阅边界干净 /
      P05 diff 指纹绑定 / P06 审查者字段在场 / P07 审查者身份可佐证 /
      P08 审查者非实现者 / P09 审查时间有效 / P10 验收结果完备 / P11 策略适用。
USAGE
}

NL='
'
NN=''
REPO=''
OPERATION='analyze'
EVIDENCE=''
POLICY=''
ALLOW_AFTER=''
RANGE=''
BATCH_BASE=''
BATCH_HEAD=''
MAX_COMMITS=50
MAX_COMMITS_SET=0
SKIP_SHAS=''
BATCH=0

_is_sha() {
  [ "${#1}" -eq 40 ] || return 1
  [ -z "$(printf '%s' "$1" | LC_ALL=C tr -d '0123456789abcdef')" ]
}

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --repo) [ $# -ge 2 ] || { usage >&2; exit 2; }; REPO=$2; shift 2 ;;
    --operation) [ $# -ge 2 ] || { usage >&2; exit 2; }; OPERATION=$2; shift 2 ;;
    --range) [ $# -ge 2 ] || { usage >&2; exit 2; }; RANGE=$2; shift 2 ;;
    --max-commits) [ $# -ge 2 ] || { usage >&2; exit 2; }; MAX_COMMITS=$2; MAX_COMMITS_SET=1; shift 2 ;;
    --skip)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      [ -n "$2" ] || { printf 'ticket-audit: --skip 不得为空（须给完整 40 位小写十六进制提交号）\n' >&2; exit 2; }
      SKIP_SHAS="${SKIP_SHAS}${NL}$2"
      shift 2
      ;;
    --evidence) [ $# -ge 2 ] || { usage >&2; exit 2; }; EVIDENCE=$2; shift 2 ;;
    --policy) [ $# -ge 2 ] || { usage >&2; exit 2; }; POLICY=$2; shift 2 ;;
    --allow-after)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      case $2 in
        ''|/*|..|../*|*/..|*/../*)
          printf 'ticket-audit: --allow-after 须为仓库根相对路径且不得含 ..: %s\n' "$2" >&2
          exit 2
          ;;
      esac
      ALLOW_AFTER="${ALLOW_AFTER}${NL}$2"
      shift 2
      ;;
    -*) printf 'ticket-audit: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$NN" ] || { printf 'ticket-audit: 多余参数: %s\n' "$1" >&2; usage >&2; exit 2; }; NN=$1; shift ;;
  esac
done
case $OPERATION in
  read|analyze|merge|push) ;;
  *) printf 'ticket-audit: --operation 不合口径: %s\n' "$OPERATION" >&2; usage >&2; exit 2 ;;
esac

# ---- 批量/推送面选项校验 ----

case $MAX_COMMITS in
  ''|*[!0-9]*) printf 'ticket-audit: --max-commits 须为十进制整数: %s\n' "$MAX_COMMITS" >&2; exit 2 ;;
esac
[ "$MAX_COMMITS" -ge 1 ] || { printf 'ticket-audit: --max-commits 须 ≥1: %s\n' "$MAX_COMMITS" >&2; exit 2; }

if [ -z "$RANGE" ]; then
  if [ "$MAX_COMMITS_SET" -eq 1 ] || [ -n "$SKIP_SHAS" ]; then
    printf 'ticket-audit: --max-commits/--skip 仅与 --range 同用\n' >&2
    exit 2
  fi
else
  [ "$OPERATION" = 'push' ] || {
    printf 'ticket-audit: --range 仅与 --operation push 同用（实际: %s）\n' "$OPERATION" >&2
    exit 2
  }
  case $RANGE in
    *'..'*)
      BATCH_BASE=${RANGE%%..*}
      BATCH_HEAD=${RANGE#*..}
      ;;
    *)
      printf 'ticket-audit: --range 形态须为 <base>..<head>: %s\n' "$RANGE" >&2
      exit 2
      ;;
  esac
  _is_sha "$BATCH_BASE" || {
    printf 'ticket-audit: --range base 须为完整 40 位小写十六进制: %s\n' "$BATCH_BASE" >&2
    exit 2
  }
  _is_sha "$BATCH_HEAD" || {
    printf 'ticket-audit: --range head 须为完整 40 位小写十六进制: %s\n' "$BATCH_HEAD" >&2
    exit 2
  }
  if [ -n "$SKIP_SHAS" ]; then
    _skip_ifs=$IFS
    IFS=$NL
    for _skip_sha in $SKIP_SHAS; do
      [ -n "$_skip_sha" ] || continue
      _is_sha "$_skip_sha" || {
        IFS=$_skip_ifs
        printf 'ticket-audit: --skip 须为完整 40 位小写十六进制提交号: %s\n' "$_skip_sha" >&2
        exit 2
      }
    done
    IFS=$_skip_ifs
  fi
  BATCH=1
fi

if [ "$BATCH" -eq 1 ]; then
  if [ -n "$NN" ]; then
    case $NN in
      *[!0-9]*) printf 'ticket-audit: 任务票编号须为纯数字: %s\n' "$NN" >&2; usage >&2; exit 2 ;;
    esac
    [ "${#NN}" -ge 2 ] || { printf 'ticket-audit: 任务票编号至少两位: %s\n' "$NN" >&2; usage >&2; exit 2; }
  fi
else
  case $NN in
    ''|*[!0-9]*) printf 'ticket-audit: 任务票编号须为纯数字: %s\n' "$NN" >&2; usage >&2; exit 2 ;;
  esac
  [ "${#NN}" -ge 2 ] || { printf 'ticket-audit: 任务票编号至少两位: %s\n' "$NN" >&2; usage >&2; exit 2; }
fi

# ---- 仓库与票定位 ----

if [ -z "$REPO" ]; then
  REPO=$(git rev-parse --show-toplevel 2>/dev/null) || die2 '--repo 缺省推导失败：当前目录不在 Git 仓库内（请显式传 --repo）'
fi
[ -d "$REPO" ] || die2 "仓库目录不存在: $REPO"
REPO=$(CDPATH='' cd -- "$REPO" && pwd -P) || die2 "仓库目录不可进入: $REPO"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die2 "不是 Git 仓库: $REPO"
TARGET=$(git -C "$REPO" rev-parse --verify -q HEAD) || die2 "仓库无 HEAD 提交: $REPO"

TICKET_DIR=$REPO/facts/requirements/tickets
[ -d "$TICKET_DIR" ] || die2 "票目录不存在: $TICKET_DIR"
case $- in *f*) _noglob=1 ;; *) _noglob=0 ;; esac
set +f
set --
for _f in "$TICKET_DIR"/"$NN"-*.json; do
  [ -e "$_f" ] || continue
  case $_f in
    *.review-evidence.json | *.workflow-checkpoint-v1.json) continue ;;
  esac
  set -- "$@" "$_f"
done
if [ "$_noglob" -eq 1 ]; then set -f; fi

# ---- 批量/推送面（仅在 --operation push 与 --range 同给时进入）----

_b_batch_die2() { printf 'ticket-audit: %s\n' "$*" >&2; exit 2; }

# 提交标题 → 票 id：优先 ticket/<id>，其次「票 <id>」；提取不到返回 1（不静默放行）
_b_batch_ticket_id() {
  _bt_id=$(printf '%s\n' "$1" | sed -n 's|.*ticket/\([0-9][0-9]*[-A-Za-z0-9._]*\).*|\1|p' | head -n 1)
  if [ -z "$_bt_id" ]; then
    _bt_id=$(printf '%s\n' "$1" | sed -n 's|.*票[[:space:]]*\([0-9][0-9]*[-A-Za-z0-9._]*\).*|\1|p' | head -n 1)
  fi
  [ -n "$_bt_id" ] || return 1
  printf '%s\n' "$_bt_id"
}

# 区间 head 树索引 id 全集（按需一次加载，供裸号前缀解析）
_b_batch_index_ids=''
_b_batch_index_ids_loaded=0
_b_batch_load_ids() {
  if [ "$_b_batch_index_ids_loaded" -eq 1 ]; then
    return 0
  fi
  _bl_total=$(printf '%s' "$_b_index" | python3 "$JSON_ENGINE" json len - issues 2>/dev/null) || return 1
  _bl_i=0
  while [ "$_bl_i" -lt "$_bl_total" ]; do
    _bl_id=$(printf '%s' "$_b_index" | python3 "$JSON_ENGINE" json get - "issues.${_bl_i}.id" 2>/dev/null) || _bl_id=''
    [ -z "$_bl_id" ] || _b_batch_index_ids="${_b_batch_index_ids}${NL}${_bl_id}"
    _bl_i=$((_bl_i + 1))
  done
  _b_batch_index_ids_loaded=1
  return 0
}

# 标题票号 → 索引全 slug：已含 slug 的 id 原样精确匹配；裸号按 ^<NN>- 前缀唯一匹配。
# 结果置 _b_resolve_id（空＝未解析）；多命中另置 _b_resolve_cands（逗号分隔候选）。
# 直接调用而非命令替换：调用方须读到 _b_resolve_n/_b_resolve_cands 的判定细节。
_b_batch_resolve_id() {
  _br_want=$1
  _b_resolve_id=''
  _b_resolve_cands=''
  _b_resolve_n=0
  case $_br_want in
    *-*) _b_resolve_n=1; _b_resolve_id=$_br_want; return 0 ;;
  esac
  _b_batch_load_ids || return 1
  _br_ifs=$IFS
  IFS=$NL
  for _br_id in $_b_batch_index_ids; do
    [ -n "$_br_id" ] || continue
    case $_br_id in
      "$_br_want"-*)
        _b_resolve_n=$((_b_resolve_n + 1))
        if [ -z "$_b_resolve_cands" ]; then
          _b_resolve_cands=$_br_id
        else
          _b_resolve_cands="${_b_resolve_cands}, ${_br_id}"
        fi
        ;;
    esac
  done
  IFS=$_br_ifs
  [ "$_b_resolve_n" -eq 1 ] || return 1
  _b_resolve_id=$_b_resolve_cands
  return 0
}

# 区间 head 树内绑定目标提交的审查收据（head_sha 相等；命不中返回 1）
_b_batch_receipt_for() {
  printf '%s\n' "$_b_receipts" | while IFS= read -r _br_path; do
    [ -n "$_br_path" ] || continue
    _br_head=$(git -C "$REPO" show "$BATCH_HEAD:$_br_path" 2>/dev/null | python3 "$JSON_ENGINE" json get - head_sha 2>/dev/null) || _br_head=''
    if [ "$_br_head" = "$1" ]; then
      printf '%s\n' "$_br_path"
      break
    fi
  done
}

_b_batch_skipped() {
  _bs_ifs=$IFS
  IFS=$NL
  for _bs_sha in $SKIP_SHAS; do
    if [ "$_bs_sha" = "$1" ]; then
      IFS=$_bs_ifs
      return 0
    fi
  done
  IFS=$_bs_ifs
  return 1
}

run_batch() {
  git -C "$REPO" cat-file -e "$BATCH_BASE^{commit}" 2>/dev/null \
    || _b_batch_die2 "区间 base 不可解析: $BATCH_BASE"
  git -C "$REPO" cat-file -e "$BATCH_HEAD^{commit}" 2>/dev/null \
    || _b_batch_die2 "区间 head 不可解析: $BATCH_HEAD"
  git -C "$REPO" merge-base --is-ancestor "$BATCH_BASE" "$BATCH_HEAD" 2>/dev/null \
    || _b_batch_die2 "区间 base 非 head 祖先: ${BATCH_BASE}..${BATCH_HEAD}"
  _b_commits=$(git -C "$REPO" rev-list --reverse "$BATCH_BASE..$BATCH_HEAD" 2>/dev/null) \
    || _b_batch_die2 "区间提交枚举失败: ${BATCH_BASE}..${BATCH_HEAD}"

  _b_old_ifs=$IFS
  IFS=$NL
  _b_count=0
  for _b_sha in $_b_commits; do
    _b_count=$((_b_count + 1))
  done
  IFS=$_b_old_ifs
  [ "$_b_count" -le "$MAX_COMMITS" ] \
    || _b_batch_die2 "区间提交数 ${_b_count} 超上限 ${MAX_COMMITS}（--max-commits 可调）"

  if [ "$_b_count" -eq 0 ]; then
    printf 'ticket-audit: 批量 判定: conformant（区间 %s..%s 无提交）\n' "$BATCH_BASE" "$BATCH_HEAD"
    exit 0
  fi

  _b_index=$(git -C "$REPO" show "${BATCH_HEAD}:facts/requirements/tickets/index.json" 2>/dev/null) \
    || _b_batch_die2 "区间 head 树内票索引缺失: facts/requirements/tickets/index.json@${BATCH_HEAD}"
  printf '%s' "$_b_index" | python3 "$JSON_ENGINE" json get - issues >/dev/null 2>&1 \
    || _b_batch_die2 "区间 head 树内票索引不可解析或 issues 缺失: facts/requirements/tickets/index.json@${BATCH_HEAD}"

  _b_receipts=$(git -C "$REPO" ls-tree -r --name-only "$BATCH_HEAD" -- facts/requirements/tickets 2>/dev/null \
    | grep '\.review-evidence\.json$') || _b_receipts=''

  _b_bad=0
  _b_skipped_n=0
  IFS=$NL
  for _b_sha in $_b_commits; do
    _b_short=$(git -C "$REPO" rev-parse --short=12 "$_b_sha")
    if _b_batch_skipped "$_b_sha"; then
      printf 'ticket-audit: 批量 %s skip 依据：--skip 显式豁免（不计入判定）\n' "$_b_short"
      _b_skipped_n=$((_b_skipped_n + 1))
      continue
    fi
    _b_subject=$(git -C "$REPO" show -s --format=%s "$_b_sha" 2>/dev/null) || _b_subject=''
    _b_parents=$(git -C "$REPO" rev-list --parents -n 1 "$_b_sha" 2>/dev/null) || _b_parents=''
    _b_rawid=$(_b_batch_ticket_id "$_b_subject") || _b_rawid=''
    _b_tid=''
    _b_badid=''
    if [ -n "$_b_rawid" ]; then
      _b_batch_resolve_id "$_b_rawid" || :
      _b_tid=$_b_resolve_id
      if [ -z "$_b_tid" ]; then
        if [ "$_b_resolve_n" -gt 1 ]; then
          _b_badid="票 id 不唯一（裸号 ${_b_rawid} 命中 ${_b_resolve_cands}）"
        else
          _b_badid="票 ${_b_rawid} 未登记（索引无 ^${_b_rawid}- 前缀条目）"
        fi
      fi
    fi
    if [ -z "$_b_parents" ]; then
      _b_verdict=unknown
      _b_reason='提交父关系不可读，判定无从进行'
    else
      _b_pcount=$(printf '%s\n' "$_b_parents" | awk '{print NF - 1; exit}')
      if [ "$_b_pcount" -ge 2 ]; then
        _b_receipt=$(_b_batch_receipt_for "$_b_sha")
        if [ -n "$_b_receipt" ]; then
          _b_verdict=conformant
          _b_reason="merge：收据 ${_b_receipt} 的 head_sha 绑定本提交"
        elif [ -n "$_b_tid" ]; then
          _b_verdict=nonconformant
          _b_reason="merge：票 ${_b_tid} 无绑定审查收据（失败谓词 P01）"
        elif [ -n "$_b_badid" ]; then
          _b_verdict=nonconformant
          _b_reason="merge：${_b_badid}，无绑定审查收据（失败谓词 P01）"
        else
          _b_verdict=nonconformant
          _b_reason='merge：票 id 不可解析，无绑定审查收据（失败谓词 P01）'
        fi
      elif [ -z "$_b_rawid" ]; then
        _b_verdict=nonconformant
        _b_reason='票 id 不可解析（提交标题无「票 <id>」或 ticket/<id>）'
      elif [ -z "$_b_tid" ]; then
        _b_verdict=nonconformant
        if [ "$_b_resolve_n" -gt 1 ]; then
          _b_reason="兜底：${_b_badid}，不猜"
        else
          _b_reason="兜底：${_b_badid}，status 缺失"
        fi
      else
        _b_status=$(printf '%s' "$_b_index" | python3 "$JSON_ENGINE" json pick - issues id "$_b_tid" status 2>/dev/null) || _b_status=''
        if [ "$_b_status" = 'done' ]; then
          _b_verdict=conformant
          _b_reason="兜底：票 ${_b_tid} status=done"
        elif [ -z "$_b_status" ]; then
          _b_verdict=nonconformant
          _b_reason="兜底：票 ${_b_tid} 未登记（索引无该票，status 缺失）"
        else
          _b_verdict=nonconformant
          _b_reason="兜底：票 ${_b_tid} status=${_b_status}（非 done）"
        fi
      fi
    fi
    printf 'ticket-audit: 批量 %s %s %s\n' "$_b_short" "$_b_verdict" "$_b_reason"
    [ "$_b_verdict" = 'conformant' ] || _b_bad=$((_b_bad + 1))
  done
  IFS=$_b_old_ifs

  if [ "$_b_bad" -eq 0 ]; then
    printf 'ticket-audit: 批量 判定: conformant（%d 个提交，%d 跳过，全部 conformant）\n' \
      "$_b_count" "$_b_skipped_n"
    exit 0
  fi
  printf 'ticket-audit: 批量 判定: nonconformant（%d 个提交中 %d 个非 conformant，%d 跳过）\n' \
    "$_b_count" "$_b_bad" "$_b_skipped_n"
  exit 1
}

if [ "$BATCH" -eq 1 ]; then
  run_batch
fi

[ $# -ge 1 ] || die2 "票文件定位零命中: $TICKET_DIR/$NN-*.json"
[ $# -eq 1 ] || die2 "票文件定位不唯一（$# 件命中）: $TICKET_DIR/$NN-*.json"
TICKET_FILE=$1
TICKET_ID=$(basename "$TICKET_FILE" .json)

if [ -z "$EVIDENCE" ]; then
  EVIDENCE=${TICKET_FILE%.json}.review-evidence.json
fi
case $EVIDENCE in
  /*) ;;
  *) EVIDENCE=$REPO/$EVIDENCE ;;
esac
if [ -z "$POLICY" ]; then
  POLICY=$REPO/facts/requirements/audit-policy.json
fi
case $POLICY in
  /*) ;;
  *) POLICY=$REPO/$POLICY ;;
esac

EVIDENCE_REL=''
case $EVIDENCE in
  "$REPO"/*) EVIDENCE_REL=${EVIDENCE#"$REPO"/} ;;
esac
POLICY_REL=''
case $POLICY in
  "$REPO"/*) POLICY_REL=${POLICY#"$REPO"/} ;;
  *) POLICY_REL=$POLICY ;;
esac

# ---- 输出与计数 ----

FAILS=0
UNKNOWNS=0

p_pass() { printf 'PASS %s %s: %s\n' "$1" "$2" "$3"; }
p_fail() { printf 'FAIL %s %s: %s\n' "$1" "$2" "$3"; FAILS=$((FAILS + 1)); }
p_unknown() { printf 'UNKNOWN %s %s: %s\n' "$1" "$2" "$3"; UNKNOWNS=$((UNKNOWNS + 1)); }

# 字段所在行号（首命中；缺失回退第 1 行）
field_line() {
  _fl=$(grep -n -F "\"$2\"" "$1" 2>/dev/null | head -n 1 | cut -d: -f1) || _fl=''
  printf '%s' "${_fl:-1}"
}

_commit_date() { git -C "$REPO" show -s --format=%aI "$1" 2>/dev/null | cut -c1-10; }
_commit_email() { git -C "$REPO" show -s --format=%ae "$1" 2>/dev/null; }
_lc() { printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]'; }
# a 早于 b（YYYY-MM-DD 字典序）返回 0
_date_lt() { LC_ALL=C awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'; }

# 身份名单（JSON 字符串数组）→ 换行分隔；空白项或非数组即失败
load_ids() {
  _ln=$(jlen "$POLICY" "$1") || return 1
  case $_ln in ''|*[!0-9]*) return 1 ;; esac
  [ "$_ln" -ge 1 ] || return 1
  _li=0
  while [ "$_li" -lt "$_ln" ]; do
    _lv=$(jget "$POLICY" "$1.$_li") || return 1
    case $_lv in ''|*[[:space:]]*) return 1 ;; esac
    printf '%s\n' "$_lv"
    _li=$((_li + 1))
  done
}

# 大小写不敏感成员判断：$1 待查身份，$2 换行分隔名单
_id_in() {
  _needle=$(_lc "$1")
  _old_ifs=$IFS
  IFS='
'
  for _cand in $2; do
    if [ "$(_lc "$_cand")" = "$_needle" ]; then
      IFS=$_old_ifs
      return 0
    fi
  done
  IFS=$_old_ifs
  return 1
}

# ---- 证据的 Git 事实定位 ----

EVIDENCE_COMMIT=''
EVIDENCE_BLOB=''
WORKTREE_BLOB=''
EVIDENCE_TRACKED=0
if [ -n "$EVIDENCE_REL" ] && [ -f "$EVIDENCE" ]; then
  if git -C "$REPO" ls-tree -r --name-only HEAD -- "$EVIDENCE_REL" 2>/dev/null | grep -qxF "$EVIDENCE_REL"; then
    EVIDENCE_TRACKED=1
    EVIDENCE_COMMIT=$(git -C "$REPO" log -1 --format=%H -- "$EVIDENCE_REL" 2>/dev/null) || EVIDENCE_COMMIT=''
    EVIDENCE_BLOB=$(git -C "$REPO" rev-parse -q --verify "HEAD:$EVIDENCE_REL" 2>/dev/null) || EVIDENCE_BLOB=''
  fi
  WORKTREE_BLOB=$(git -C "$REPO" hash-object -- "$EVIDENCE_REL" 2>/dev/null) || WORKTREE_BLOB=''
fi

# ---- 证据字段读取 ----

R_BASE=$(jget "$EVIDENCE" base_sha) || R_BASE=''
R_HEAD=$(jget "$EVIDENCE" head_sha) || R_HEAD=''
R_DIFF=$(jget "$EVIDENCE" diff_sha) || R_DIFF=''
R_REVIEWER=$(jget "$EVIDENCE" reviewer_identity) || R_REVIEWER=''
R_REVIEWED_AT=$(jget "$EVIDENCE" reviewed_at) || R_REVIEWED_AT=''
R_VERDICT=$(jget "$EVIDENCE" verdict) || R_VERDICT=''

# ---- 策略加载（P07/P08/P09 依赖；判定行在 P11 输出）----

POLICY_STATE='unknown'
POLICY_REASON=''
POLICY_TRUSTED=''
POLICY_IMPL=''
POLICY_EFFECTIVE=''

if [ ! -f "$POLICY" ]; then
  POLICY_REASON="策略文件缺失: $POLICY_REL"
elif ! json_readable "$POLICY"; then
  POLICY_REASON="策略不可解析: $POLICY_REL"
else
  _psv=$(jget "$POLICY" schema_version) || _psv=''
  _pef=$(jget "$POLICY" effective_from) || _pef=''
  _pbs=$(jget "$POLICY" baseline_sha) || _pbs=''
  _prb=$(jget "$POLICY" release_baseline) || _prb=''
  _ptr=$(load_ids trusted_reviewers) || _ptr=''
  if [ "$_psv" != '1' ]; then
    POLICY_REASON="策略 schema_version 非 1（实际: ${_psv:-缺失}）"
  else
    case $_pef in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
      *) _pef='' ;;
    esac
  fi
  if [ -z "$POLICY_REASON" ] && [ -z "$_pef" ]; then
    POLICY_REASON="策略 effective_from 非 YYYY-MM-DD: $POLICY_REL"
  fi
  if [ -z "$POLICY_REASON" ] && ! _is_sha "$_pbs"; then
    POLICY_REASON="策略 baseline_sha 非 40 位小写十六进制: $POLICY_REL"
  fi
  if [ -z "$POLICY_REASON" ] && ! git -C "$REPO" cat-file -e "$_pbs^{commit}" 2>/dev/null; then
    POLICY_REASON="策略 baseline_sha 不可解析: $_pbs"
  fi
  if [ -z "$POLICY_REASON" ] && [ -z "$_prb" ]; then
    POLICY_REASON="策略 release_baseline 缺失（须为 none 或标签名）: $POLICY_REL"
  fi
  if [ -z "$POLICY_REASON" ] && [ "$_prb" != 'none' ] \
    && ! git -C "$REPO" rev-parse --verify -q "refs/tags/$_prb^{commit}" >/dev/null 2>&1; then
    POLICY_REASON="策略 release_baseline 标签不可解析: $_prb"
  fi
  if [ -z "$POLICY_REASON" ] && [ -z "$_ptr" ]; then
    POLICY_REASON="策略 trusted_reviewers 为空或含空白项: $POLICY_REL"
  fi
  if [ -z "$POLICY_REASON" ]; then
    _ptd=$(_commit_date "$TARGET")
    if [ -z "$_ptd" ]; then
      POLICY_REASON='target 提交日期不可取，策略适用性无法判断'
    elif _date_lt "$_ptd" "$_pef"; then
      POLICY_REASON="策略生效日 ${_pef} 晚于 target 提交日 ${_ptd}（不适用）"
    elif ! git -C "$REPO" merge-base --is-ancestor "$_pbs" "$TARGET" 2>/dev/null; then
      POLICY_REASON="策略 baseline_sha 非 target 祖先（不适用）: $_pbs"
    fi
  fi
  if [ -z "$POLICY_REASON" ]; then
    POLICY_STATE='known'
    POLICY_EFFECTIVE=$_pef
    POLICY_TRUSTED=$_ptr
    POLICY_IMPL=$(load_ids implementation_identities) || POLICY_IMPL=''
  fi
fi
# ---- 谓词注册表加载与统一分派（P01-P11 注册表化、每谓词分片；引擎零谓词逻辑，
#      只做 Git 事实准备与汇总判定）----
_audit_registry="$SCRIPT_DIR/audit-predicates.rules"
[ -f "$_audit_registry" ] || die2 "谓词注册表缺失（同目录定位）: $_audit_registry"
_audit_rc=0
_audit_rows=$(LC_ALL=C awk '
  function bad(msg) { printf "  - 注册表第 %d 行: %s\n", FNR, msg > "/dev/stderr"; n++ }
  /^[[:space:]]*$/ { next }
  /^[[:space:]]*#/ { next }
  {
    if ($1 != "pr") { bad("未知指令: " $1 "（预期 pr）"); next }
    if (NF != 5) { bad("字段数 " NF "（预期 5：pr、谓词号、slug、分片、halt 标记）"); next }
    if ($2 !~ /^P[0-9][0-9]$/) bad("谓词号须 P 加两位数字: " $2)
    if ($3 !~ /^[a-z][a-z0-9-]*$/) bad("slug 须小写 token: " $3)
    if ($4 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) bad("分片须单段 *.sh 文件名: " $4)
    if ($5 != "halt" && $5 != "-") bad("halt 标记须 halt 或 -: " $5)
    if ($2 in seen_id) bad("谓词号跨行重复: " $2); else seen_id[$2] = 1
    if ($4 in seen_file) bad("分片跨行重复: " $4); else seen_file[$4] = 1
    if (n == 0) print $2 "\t" $3 "\t" $4 "\t" $5
  }
  END { exit (n ? 1 : 0) }
' "$_audit_registry") || _audit_rc=$?
if [ "$_audit_rc" -ne 0 ]; then
  printf 'ticket-audit: 错误：谓词注册表结构不合预期（fail-closed，不产生部分结论）: %s\n' "$_audit_registry" >&2
  exit 2
fi

# 先载入校验后分派（两段式）：载入段逐谓词 source 分片并核对统一 interface，缺件/
# 载入失败/函数缺失即 exit 2 fail-closed——此段在输出任何谓词判定行之前完成，故缺件
# 场景零部分结论（只输出 stderr 指名，不产生 PASS/FAIL 或判定行）。分片统一 interface＝
# check_pNN，只经 p_pass/p_fail/p_unknown 报告。
while IFS="$(printf '\t')" read -r _pr_id _pr_slug _pr_file _pr_halt; do
  [ -n "$_pr_id" ] || continue
  _pr_path="$SCRIPT_DIR/$_pr_file"
  [ -f "$_pr_path" ] || die2 "谓词分片缺失: ${_pr_path}（谓词 ${_pr_id}）"
  # shellcheck disable=SC1090  # 分片路径由注册表现算（动态发现），静态视野不可跟随
  . "$_pr_path" || die2 "谓词分片载入失败: ${_pr_path}（谓词 ${_pr_id}）"
  _pr_fn=check_$(printf '%s' "$_pr_id" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  command -v "$_pr_fn" >/dev/null 2>&1 || \
    die2 "谓词分片未定义统一 interface 函数: ${_pr_fn}（${_pr_path}）"
done <<EOF
$_audit_rows
EOF

# 分派段：注册表顺序逐谓词调用；halt 标记谓词失败即停止后续评估（收据可解析门）。
while IFS="$(printf '\t')" read -r _pr_id _pr_slug _pr_file _pr_halt; do
  [ -n "$_pr_id" ] || continue
  _pr_fn=check_$(printf '%s' "$_pr_id" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  "$_pr_fn"
  if [ "$_pr_halt" = 'halt' ] && [ "$FAILS" -gt 0 ]; then
    printf 'ticket-audit: 操作面: %s 拒绝（证据不可解析，无法进入谓词判定）\n' "$OPERATION"
    printf 'ticket-audit: 判定: nonconformant（%s 失败）\n' "$_pr_id"
    exit 1
  fi
done <<EOF
$_audit_rows
EOF

# ---- 证据位置、操作面与三值判定 ----

if [ "$EVIDENCE_TRACKED" -eq 1 ] && [ -n "$EVIDENCE_COMMIT" ]; then
  printf 'ticket-audit: 证据位置: %s@%s:%s\n' "$EVIDENCE_REL" "$EVIDENCE_COMMIT" "$EVIDENCE_BLOB"
else
  printf 'ticket-audit: 证据位置: %s@未提交\n' "$EVIDENCE_REL"
fi

case $OPERATION in
  read|analyze) _write_op=0 ;;
  *) _write_op=1 ;;
esac

if [ "$FAILS" -gt 0 ]; then
  printf 'ticket-audit: 操作面: %s 拒绝（证据 nonconformant）\n' "$OPERATION"
  printf 'ticket-audit: 判定: nonconformant（%d 项失败，%d 项未知）\n' "$FAILS" "$UNKNOWNS"
  exit 1
fi
if [ "$UNKNOWNS" -gt 0 ]; then
  if [ "$_write_op" -eq 1 ]; then
    printf 'ticket-audit: 操作面: %s 拒绝（策略/身份不可核验，不得以 unknown 放行写面）\n' "$OPERATION"
  else
    printf 'ticket-audit: 操作面: %s 允许（unknown 不阻断读/分析）\n' "$OPERATION"
  fi
  printf 'ticket-audit: 判定: unknown（%d 项未知）\n' "$UNKNOWNS"
  if [ "$_write_op" -eq 0 ]; then
    exit 0
  fi
  exit 1
fi
printf 'ticket-audit: 操作面: %s 允许（证据 conformant）\n' "$OPERATION"
printf 'ticket-audit: 判定: conformant（十一谓词全过）\n'
exit 0
