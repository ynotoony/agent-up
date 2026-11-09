#!/bin/sh
# Input: 调用方脚本环境（set -eu）与参数——resolve_repo_root 的模式/覆盖根；锁原语的
#        仓库根；TICKET_OPS_LOCK_TIMEOUT／TICKET_OPS_LOCK_STALE／RECORD_LOCK_BREAK_STALE
#        等运行开关。
# Output: 错误与告警报文函数、仓库根推导，只追加前缀语义（账本清单、字节前缀判定、
#         首个违规行号定位——check-append-only.sh 与记录提交前缀门共用），记录层
#         写锁原语（mkdir 原子取锁、有界等待、陈旧锁只诊断、显式夺锁、令牌归属校验、
#         嵌套继承、继承或自取单一入口 record_lock_ensure 与所有权感知释放），以及证据门
#         Review Checkpoint 允许集的唯一形态判定；本库不直接写业务载体。
# Pos: agent-up 脚本共享库，锁原语（票 246 原语＋票 271 继承/所有权入口）、前缀语义
#      （票 247）与 Review Checkpoint 允许集判定（票 237）全仓唯一实现点；
#      ticket-ops.sh／merge-ticket.sh／ledger-append.sh／check-append-only.sh／
#      lane-commit.sh／checkpoint-write.sh／ticket-run.sh 只调用不复制。
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

# ---- 证据门 Review Checkpoint 允许集判定（票 294：独立为同目录 evidence-gate.sh）----
_ch_self_dir=${COMMON_HELPERS_DIR:-}
[ -n "$_ch_self_dir" ] || _ch_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1090,SC1091  # 证据门模块路径由调用方脚本目录推导（动态源）
. "$_ch_self_dir/evidence-gate.sh"
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

# ---- 记录层写锁原语（票 294：独立为同目录 record-lock.sh；本件只转发）----
# shellcheck disable=SC1090,SC1091  # 锁原语模块路径由调用方脚本目录推导（动态源）
. "$_ch_self_dir/record-lock.sh"
