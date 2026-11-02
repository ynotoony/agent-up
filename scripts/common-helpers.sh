#!/bin/sh
# Input: 调用方脚本环境（set -eu）与参数——resolve_repo_root 的模式/覆盖根；锁原语的
#        仓库根；TICKET_OPS_LOCK_TIMEOUT／TICKET_OPS_LOCK_STALE／RECORD_LOCK_BREAK_STALE
#        等运行开关。
# Output: 错误与告警报文函数、仓库根推导，只追加前缀语义（账本清单、字节前缀判定、
#         首个违规行号定位——check-append-only.sh 与记录提交前缀门共用），记录层
#         写锁原语（mkdir 原子取锁、有界等待、陈旧锁只诊断、显式夺锁、令牌归属校验、
#         继承识别与释放），以及证据门 Review Checkpoint 允许集的唯一形态判定；本库
#         不直接写业务载体。
# Pos: agent-up 脚本共享库，锁原语（票 246）、前缀语义（票 247）与 Review Checkpoint
#      允许集判定（票 237）全仓唯一实现点；ticket-ops.sh／merge-ticket.sh／
#      ledger-append.sh／check-append-only.sh／lane-commit.sh 只调用不复制。
#      一旦我被更新，务必同步 rules/implementation/scripts/ 镜像件与同目录 README.md。

# Extract script name from $0 for error messages
_script_name() {
  basename "$0" | sed 's/\.sh$//'
}

# Exit 1 with FAIL prefix (validation/logical errors)
die1() {
  printf '%s: FAIL: %s\n' "$(_script_name)" "$1" >&2
  exit 1
}

# Exit 2 with plain prefix (usage/environment errors)
die2() {
  printf '%s: %s\n' "$(_script_name)" "$1" >&2
  exit 2
}

# Warning message (non-fatal)
warn() {
  printf '%s: WARNING: %s\n' "$(_script_name)" "$1" >&2
}

# review_checkpoint_allow_after <票 id> <JSON 引擎> <票体来源>
# 证据门允许集里 Review Checkpoint 路径的唯一判定实现：<票体来源> 为票体文件路径或
# '-'（读 stdin）。票面 dispatch.commit.REVIEW_PASS_CHECKPOINT 恰为本票规范路径
# facts/requirements/tickets/<id>-review-checkpoint.md 时打印该路径；未声明或形态
# 不符打印空（形态不符附告警）。ticket-ops 证据门与 merge-ticket 合并门共用本函数，
# 禁止各写一份——两处口径必须同源，否则 done 能过而 merge 恒拒。
review_checkpoint_allow_after() {
  _rca_id=$1
  _rca_engine=$2
  _rca_src=$3
  [ -f "$_rca_engine" ] || return 0
  _rca_val=$(python3 "$_rca_engine" json get "$_rca_src" 'dispatch.commit.REVIEW_PASS_CHECKPOINT' 2>/dev/null) || _rca_val=''
  case $_rca_val in
    '') ;;
    "facts/requirements/tickets/${_rca_id}-review-checkpoint.md") printf '%s\n' "$_rca_val" ;;
    *) printf '%s: 证据门: REVIEW_PASS_CHECKPOINT 形态不符，不纳入允许集: %s\n' "$(_script_name)" "$_rca_val" >&2 ;;
  esac
  return 0
}

# resolve_repo_root [--git|--marker|--layout] [override]
# 仓库根推导唯一实现（票 227 F4：三套根推导约定统一改调本函数）。
# 模式:
#   (缺省)     落位分派推导：override（第一非模式参数，存在即规范化为物理绝对路径）>
#              $0 落位推导——*/rules/implementation/scripts/ 上三级、
#              */agent-up/scripts/ 上两级、其余落位兜底上两级（generate-progress
#              票 206 口径）。输出物理绝对路径；推导失败 return 1。
#   --layout   同缺省的落位分派，但仅认两规范落位（agent-up/scripts/ 与
#              rules/implementation/scripts/），其余落位 return 1（check-stale-claims
#              fail-closed 口径：非规范落位不静默错根）。
#   --git      override > git rev-parse --show-toplevel（以当前目录所在仓库为准；
#              check-gates/lane-commit/generate-module-map/worktree-add 口径）。
#   --marker   override > 自 $0 目录逐级向上（至多 4 级）找 facts/project/changes.jsonl
#              标记（absorption-trigger/health-summary 口径；找不到 return 1）。
# 输出: 推导根路径打印到 stdout；失败 return 非 0 且不输出。调用方负责失败报文。
resolve_repo_root() {
  _rr_mode='' _rr_override=''
  for _rr_arg in "$@"; do
    case $_rr_arg in
      --git|--marker|--layout) _rr_mode=$_rr_arg ;;
      '') : ;;
      *) _rr_override=$_rr_arg ;;
    esac
  done
  if [ -n "$_rr_override" ]; then
    (CDPATH='' cd -- "$_rr_override" 2>/dev/null && pwd -P)
    return
  fi
  case $_rr_mode in
    --git)
      git rev-parse --show-toplevel 2>/dev/null
      return
      ;;
    --marker)
      _rr_dir=$(dirname -- "$0")
      _rr_i=0
      while [ "$_rr_i" -lt 4 ]; do
        _rr_dir=$(CDPATH='' cd -- "$_rr_dir/.." 2>/dev/null && pwd -P) || return 1
        if [ -f "${_rr_dir}/facts/project/changes.jsonl" ]; then
          printf '%s\n' "$_rr_dir"
          return 0
        fi
        _rr_i=$((_rr_i + 1))
      done
      return 1
      ;;
    *)
      _rr_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || return 1
      case $_rr_dir in
        */rules/implementation/scripts) _rr_root=${_rr_dir%/*/*/*} ;;
        */agent-up/scripts) _rr_root=${_rr_dir%/*/*} ;;
        *)
          if [ "$_rr_mode" = '--layout' ]; then
            return 1
          fi
          _rr_root=${_rr_dir%/*/*}
          ;;
      esac
      printf '%s\n' "$_rr_root"
      ;;
  esac
}

# ---- 只追加前缀语义（票 247：check-append-only.sh 与 lane-commit.sh 记录提交门共用）----
# 前缀判定的唯一实现点：校验「旧内容是否为新的字节前缀」与首个违规行号定位均在此，
# 库外零副本；调用方只负责取旧/新两份内容文件并组装报因。
# 只追加账本清单（仓库根相对，逐行一条；换行分隔以免调用方 IFS 差异影响切分）：
# 记录提交前缀门仅对该集合断言 HEAD 前缀；check-append-only.sh 启动时以
# record_append_only_path 自校验本地常量，防清单漂移。
RECORD_APPEND_ONLY_PATHS='facts/project/changes.jsonl
facts/project/micro.jsonl'

# 判定路径是否属只追加账本清单（0＝是，1＝否）
record_append_only_path() {
  _rao_path=$1
  for _rao_known in ${RECORD_APPEND_ONLY_PATHS}; do
    if [ "$_rao_path" = "$_rao_known" ]; then
      return 0
    fi
  done
  return 1
}

# 前缀判定：$1=旧内容文件 $2=新内容文件；0＝旧内容是新的字节前缀（合法尾部追加），
# 1＝不是（中间插入/改写/截断/删除任一）。字节口径（head -c 截取后 cmp），不做行归一。
record_prefix_ok() {
  _rpo_old_size=$(wc -c < "$1" | tr -d ' ')
  _rpo_new_size=$(wc -c < "$2" | tr -d ' ')
  [ "$_rpo_new_size" -ge "$_rpo_old_size" ] || return 1
  head -c "$_rpo_old_size" "$2" | cmp -s - "$1"
}

# 首个违规行号（新内容文件行号）：旧行与新行逐一相等比对，首个不等行即输出；新内容行数
# 少于旧内容（截断）时输出缺失位置（新行数+1）；无行级差异时无输出（恒 0，行号经 stdout
# 传递，避免 set -e 下命令替换非零退出歧义）。
# 注：$1 为空文件时 awk 的 NR==FNR 对 $2 每一行都成立，这些行只被读入 old[] 而不参与
# 比较，函数因此无输出——空旧内容视为任意新内容的字节前缀（与 record_prefix_ok 同口径）。
# 调用方按「无行级差异」处理：前缀门在调用前已由 record_prefix_ok 判定，空旧内容不会
# 走到本函数；部分暂存预检在暂存 blob 为空时无差异行可报，由调用方回退到「暂存行数+1」。
record_first_bad_line() {
  LC_ALL=C awk '
    NR == FNR { old[FNR] = $0; on = FNR; next }
    FNR <= on && $0 != old[FNR] { print FNR; found = 1; exit }
    END { if (!found && FNR < on) print FNR + 1 }
  ' "$1" "$2"
}

# ---- 记录层写锁原语（票 246：全仓唯一实现；ticket-ops.sh 与 ledger-append.sh 共用）----
# mkdir 原子创建语义（POSIX，macOS/BSD 无 flock 亦可用）。锁目录由仓库根的 Git 公共目录
# 推导（git rev-parse --git-common-dir，cd -P 归一为物理绝对路径），使主检与全部 worktree
# 争用同一把锁；非 Git 语境回退 $TMPDIR 并按仓库根物理路径派生，保证同机同用户仍互斥。
# 锁目录落 .git 内（非 Git 回退则落 $TMPDIR），不进入版本控制跟踪面、不污染 git status。
# 陈旧锁（持有者 pid 不存在，或 pid 字段缺失且锁龄超 TICKET_OPS_LOCK_STALE 秒）只诊断、
# 不自动夺；只有 RECORD_LOCK_BREAK_STALE=1（或等价 CLI 参数）才显式夺锁。夺锁以锁目录内
# token 文件（pid:时间戳:随机代号）核对归属：原持有者令牌不符即拒绝写入。
# 取默认值而非硬赋值：嵌套调用方（如 ticket-ops 调 ledger-append）经环境传入锁目录与令牌，
# source 本库时不得清空；自取锁路径由 record_lock_init 重置。
: "${RECORD_LOCK_DIR:=}"
: "${RECORD_LOCK_TOKEN:=}"
: "${RECORD_LOCK_HELD:=0}"

# 按仓库根解析锁目录（幂等；每次调用重置持有状态与令牌）
record_lock_init() {
  _rlock_root=$1
  _rlock_phys=$(CDPATH='' cd -- "$_rlock_root" 2>/dev/null && pwd -P) || _rlock_phys=$_rlock_root
  _rlock_common=''
  if command -v git >/dev/null 2>&1; then
    _rlock_common=$(git -C "$_rlock_phys" rev-parse --git-common-dir 2>/dev/null) || _rlock_common=''
  fi
  if [ -n "$_rlock_common" ]; then
    case $_rlock_common in
      /*) ;;
      *) _rlock_common="${_rlock_phys}/${_rlock_common}" ;;
    esac
    _rlock_common=$(CDPATH='' cd -- "$_rlock_common" 2>/dev/null && pwd -P) || _rlock_common=''
  fi
  if [ -n "$_rlock_common" ]; then
    RECORD_LOCK_DIR="${_rlock_common}/agent-up-record.lock"
  else
    RECORD_LOCK_DIR="${TMPDIR:-/tmp}/agent-up-record-$(printf '%s' "${_rlock_phys}" | cksum | awk '{print $1}').lock"
  fi
  RECORD_LOCK_HELD=0
  RECORD_LOCK_TOKEN=''
}

# 生成唯一令牌：pid:时间戳:六位随机代号
record_lock_new_token() {
  printf '%s:%s:%s' "$$" "$(date +%s)" "$(awk 'BEGIN{srand(); printf "%06d", int(rand()*1000000)}')"
}

# 测试钩子：持锁后延迟返回，放大「已持锁 → 下一写点」窗口；未设或 0＝零开销
record_lock_test_hold() {
  case ${RECORD_LOCK_TEST_HOLD_MS:-} in
    ''|*[!0-9]*|0) return 0 ;;
  esac
  sleep "$((RECORD_LOCK_TEST_HOLD_MS / 1000)).$(printf '%03d' "$((RECORD_LOCK_TEST_HOLD_MS % 1000))")"
}

# 显式夺锁：$1=观察到的旧令牌 $2=陈旧判据报文。mv 到唯一旁路名成功的一方获得删除权；
# 旁路令牌与观察值不符即放回（目标已被重建则丢弃旁路，绝不 mv 嵌套）。
# 0＝夺锁成功（调用方重试 mkdir）；1＝未夺（他人先到或锁已换新），调用方继续等待。
record_lock_steal() {
  _rlock_expect=$1
  _rlock_why=$2
  _rlock_bypass="${RECORD_LOCK_DIR}.steal.$$"
  rm -rf "$_rlock_bypass"
  mv "${RECORD_LOCK_DIR}" "$_rlock_bypass" 2>/dev/null || return 1
  _rlock_seen=$(sed -n '1p' "${_rlock_bypass}/token" 2>/dev/null) || _rlock_seen=''
  if [ "$_rlock_seen" != "$_rlock_expect" ]; then
    if [ -e "${RECORD_LOCK_DIR}" ] || [ -L "${RECORD_LOCK_DIR}" ]; then
      rm -rf "$_rlock_bypass"
    elif ! mv "$_rlock_bypass" "${RECORD_LOCK_DIR}" 2>/dev/null; then
      rm -rf "$_rlock_bypass"
    fi
    return 1
  fi
  warn "显式夺锁（${_rlock_why}）: ${RECORD_LOCK_DIR}（原令牌 ${_rlock_expect:-缺失}）"
  rm -rf "$_rlock_bypass"
  return 0
}

# 有界等待取锁；超时 exit 1「并发冲突」（含锁路径与持有者 pid），零写入
record_lock_acquire() {
  _rlock_timeout=${TICKET_OPS_LOCK_TIMEOUT:-20}
  case $_rlock_timeout in ''|*[!0-9]*) _rlock_timeout=20 ;; esac
  _rlock_stale=${TICKET_OPS_LOCK_STALE:-600}
  case $_rlock_stale in ''|*[!0-9]*) _rlock_stale=600 ;; esac
  _rlock_stale_min=$((_rlock_stale / 60))
  [ "$_rlock_stale_min" -ge 1 ] || _rlock_stale_min=1
  _rlock_waited_cs=0
  _rlock_diag=0
  while :; do
    if mkdir "${RECORD_LOCK_DIR}" 2>/dev/null; then
      RECORD_LOCK_TOKEN=$(record_lock_new_token)
      printf '%s\n' "$$" > "${RECORD_LOCK_DIR}/pid" 2>/dev/null || true
      printf '%s\n' "$RECORD_LOCK_TOKEN" > "${RECORD_LOCK_DIR}/token" 2>/dev/null || true
      RECORD_LOCK_HELD=1
      record_lock_test_hold
      return 0
    fi
    _rlock_holder=$(sed -n '1p' "${RECORD_LOCK_DIR}/pid" 2>/dev/null) || _rlock_holder=''
    case $_rlock_holder in ''|*[!0-9]*) _rlock_holder='' ;; esac
    _rlock_token=$(sed -n '1p' "${RECORD_LOCK_DIR}/token" 2>/dev/null) || _rlock_token=''
    _rlock_reason=''
    if [ -n "$_rlock_holder" ]; then
      kill -0 "$_rlock_holder" 2>/dev/null || _rlock_reason="持有者 pid ${_rlock_holder} 已不存在"
    elif [ -n "$(find "${RECORD_LOCK_DIR}" -prune -mmin +"${_rlock_stale_min}" 2>/dev/null)" ]; then
      _rlock_reason="pid 字段缺失且锁龄超过 ${_rlock_stale}s"
    fi
    if [ -n "$_rlock_reason" ]; then
      if [ "${RECORD_LOCK_BREAK_STALE:-0}" = '1' ]; then
        if record_lock_steal "$_rlock_token" "$_rlock_reason"; then
          continue
        fi
      elif [ "$_rlock_diag" -eq 0 ]; then
        warn "陈旧写锁（${_rlock_reason}）仅诊断不自动夺锁: ${RECORD_LOCK_DIR}——继续等待至超时；显式加 --break-stale-lock 或 RECORD_LOCK_BREAK_STALE=1 才夺锁"
        _rlock_diag=1
      fi
    fi
    if [ "$_rlock_waited_cs" -ge $((_rlock_timeout * 100)) ]; then
      die1 "并发冲突：等待写锁释放超时 ${_rlock_timeout}s（锁目录: ${RECORD_LOCK_DIR}；持有者 pid ${_rlock_holder:-未知}${_rlock_reason:+；${_rlock_reason}}）——零写入，重跑同一命令即按幂等路径收敛"
    fi
    sleep 0.05
    _rlock_waited_cs=$((_rlock_waited_cs + 5))
  done
}

# 写点前归属校验：令牌不符（锁已被显式夺走）即拒绝写入并 exit 1
record_lock_assert() {
  if [ "${RECORD_LOCK_HELD:-0}" -ne 1 ]; then
    die1 "写锁未持有即试图写入（内部错误；锁目录: ${RECORD_LOCK_DIR:-未初始化}）——零写入"
  fi
  _rlock_seen=$(sed -n '1p' "${RECORD_LOCK_DIR}/token" 2>/dev/null) || _rlock_seen=''
  if [ "$_rlock_seen" != "$RECORD_LOCK_TOKEN" ]; then
    RECORD_LOCK_HELD=0
    die1 "写锁归属已失效（锁已被显式夺走；锁目录: ${RECORD_LOCK_DIR}；本进程令牌 ${RECORD_LOCK_TOKEN}，现锁令牌 ${_rlock_seen:-缺失}）——拒绝写入，零写入；查明夺锁原因后重跑同一命令即按幂等路径收敛"
  fi
}

# 释放：仅在令牌仍归本进程时删除锁目录（绝不删他人锁）；幂等
record_lock_release() {
  [ "${RECORD_LOCK_HELD:-0}" -eq 1 ] || return 0
  _rlock_seen=$(sed -n '1p' "${RECORD_LOCK_DIR}/token" 2>/dev/null) || _rlock_seen=''
  if [ -n "$RECORD_LOCK_TOKEN" ] && [ "$_rlock_seen" = "$RECORD_LOCK_TOKEN" ]; then
    rm -rf "${RECORD_LOCK_DIR}"
  fi
  RECORD_LOCK_HELD=0
}

# 嵌套继承：RECORD_LOCK_INHERITED=1 时按父进程传入的锁目录/令牌接管持有状态，跳过取锁与
# 释放（不设 trap，锁生命周期归父进程）；0＝已继承，1＝未设继承标记
record_lock_inherit() {
  [ "${RECORD_LOCK_INHERITED:-0}" = '1' ] || return 1
  if [ -z "${RECORD_LOCK_DIR:-}" ] || [ -z "${RECORD_LOCK_TOKEN:-}" ]; then
    die2 '继承写锁（RECORD_LOCK_INHERITED=1）但 RECORD_LOCK_DIR／RECORD_LOCK_TOKEN 缺失——拒绝在无锁状态下写入'
  fi
  RECORD_LOCK_HELD=1
  return 0
}
