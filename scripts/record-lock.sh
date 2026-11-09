#!/bin/sh
# Input: 调用方（common-helpers.sh）已定义的 die1／die2／warn 报文函数；锁目录与令牌经
#        RECORD_LOCK_* 环境变量、TICKET_OPS_LOCK_TIMEOUT／STALE、RECORD_LOCK_BREAK_STALE
#        开关传入。
# Output: 记录层写锁原语：record_lock_init／new_token／test_hold／steal／acquire／assert／
#        release／inherit／ensure／release_owned（mkdir 原子取锁、有界等待、陈旧锁只诊断、
#        显式夺锁、令牌归属校验、嵌套继承与所有权感知释放的唯一实现）。
# Pos: 记录层写锁原语模块（票 294：从 common-helpers.sh 分出并发状态机）；ticket-ops.sh、
#      ledger-append.sh、lane-commit.sh、checkpoint-write.sh、ticket-run.sh 经
#      common-helpers.sh 转发共用，零副本。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（调用方报文函数与锁上下文），单文件视野误报

# ---- 记录层写锁原语（票 246／票 271：全仓唯一实现；ticket-ops.sh、ledger-append.sh、lane-commit.sh、checkpoint-write.sh 与 ticket-run.sh 共用）----
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
: "${RECORD_LOCK_OWNED:=0}"

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

# 有界等待取锁；空锁目录 exit 1（不得落到 CWD 相对路径），超时 exit 1「并发冲突」
# （含锁路径与持有者 pid），零写入
record_lock_acquire() {
  if [ -z "${RECORD_LOCK_DIR:-}" ]; then
    die1 "写锁目录未初始化（RECORD_LOCK_DIR 为空）——拒绝取锁，零写入"
  fi
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

# 取锁唯一入口（票 271）：继承或自取。RECORD_LOCK_INHERITED=1 时接管父进程的锁
# （锁目录与令牌经环境传入），跳过 init/acquire 且不承担释放责任；否则按仓库根
# 初始化锁目录并自取。返回码只表达「锁已就绪」（0＝就绪；继承标记残缺经 die2、
# 取锁超时或未初始化经 die1 退出，均 fail-closed）；所有权经 RECORD_LOCK_OWNED 回读：
# 1＝本进程自取，退出前须经 record_lock_release_owned 释放；0＝继承，锁生命周期归
# 父进程，本进程不得释放。
record_lock_ensure() {
  # 同进程重复调用：已自取且令牌仍在手则幂等返回
  if [ "${RECORD_LOCK_OWNED:-0}" -eq 1 ] && [ "${RECORD_LOCK_HELD:-0}" -eq 1 ]; then
    return 0
  fi
  RECORD_LOCK_OWNED=0
  if record_lock_inherit; then
    return 0
  fi
  record_lock_init "$1"
  record_lock_acquire
  RECORD_LOCK_OWNED=1
  return 0
}

# 按所有权释放（票 271）：自取（RECORD_LOCK_OWNED=1）才删除锁目录；继承时只清本地持有
# 标记，绝不动父进程的锁。幂等，可作 EXIT 陷阱体。
record_lock_release_owned() {
  if [ "${RECORD_LOCK_OWNED:-0}" -eq 1 ]; then
    record_lock_release
  else
    RECORD_LOCK_HELD=0
  fi
  RECORD_LOCK_OWNED=0
  return 0
}
