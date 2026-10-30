#!/bin/sh
# Input: 调用方脚本环境（set -eu）与参数——resolve_repo_root 的模式/覆盖根；锁原语的
#        仓库根；TICKET_OPS_LOCK_TIMEOUT／TICKET_OPS_LOCK_STALE／RECORD_LOCK_BREAK_STALE
#        等运行开关。
# Output: 错误与告警报文函数、仓库根推导，以及记录层写锁原语（mkdir 原子取锁、有界等待、
#         陈旧锁只诊断、显式夺锁、令牌归属校验、继承识别与释放）；本库不直接写业务载体。
# Pos: agent-up 脚本共享库，锁原语全仓唯一实现点（票 246）；ticket-ops.sh 与
#      ledger-append.sh 只调用不复制。一旦我被更新，务必同步 rules/implementation/scripts/
#      镜像件与同目录 README.md。

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
