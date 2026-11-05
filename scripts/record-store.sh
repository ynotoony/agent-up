#!/bin/sh
# Input: 调用方脚本环境（set -eu、set -f；已 source common-helpers.sh）——仓库根、记录键与
#        写动词参数：record_write 的整文件新内容文件、record_append 的追加片段文件、
#        record_set_json 的 --doc-set <dotted.path>=<json-value> 字段规格；锁与测试钩子
#        RECORD_LOCK_*／TICKET_OPS_LOCK_*（继承或自取、陈旧判定）与
#        RECORD_STORE_TEST_APPEND_HOLD_MS（追加窗口放大，未设零开销）；JSON 序列化经
#        同目录唯一 JSON 引擎 json-validator.py（RECORD_STORE_ENGINE 可覆盖定位）。
# Output: 记录层六类路径的唯一承载表 record_path（index／changes／micro／tickets-readme／
#        ticket:<id>／checkpoint:<id>）与三个写动词——record_write（整文件原子替换）、
#        record_append（追加＋前缀断言）、record_set_json（字段级改写，内部调
#        json-validator.py json set 序列化并回读核对）；内部包办 record_lock_ensure
#        （调用方已持锁则接管同一把、否则本动词自取并在本次写入后按所有权释放）、
#        realpath containment（绝对路径／.. 段／symlink 与父目录逃逸 fail-closed）、
#        同目录 mktemp＋mv 原子替换与追加前缀断言。本库不打印业务进度行（caller 自报）。
# Pos: agent-up 记录层写面 module（票 272）：六类记录路径字面量只在本表出现（派生投影
#      progress-current 与 flips 协议串属既有面，不在本表），写互斥与锁语义
#      同源于 common-helpers.sh 的 record_lock_*／record_prefix_ok；ticket-ops.sh（索引与
#      issues-README 四处写点）、ledger-append.sh（changes／micro 两账本行）、
#      checkpoint-write.sh（User Review Checkpoint 记录块）与 ticket-run.sh
#      （票本体 checkpoint.commit）只经本库写入，零手写 mktemp＋mv／锁断言副本。
#      一旦我被更新，务必同步 rules/implementation/scripts/ 镜像件与同目录 README.md。

# ---- 记录路径表（六类；记录路径字面量的唯一承载点）----
RECORD_STORE_TICKETS_DIR='facts/requirements/tickets'
RECORD_STORE_INDEX='facts/requirements/tickets/index.json'
RECORD_STORE_TICKETS_README='facts/requirements/tickets/README.md'
RECORD_STORE_CHANGES='facts/project/changes.jsonl'
RECORD_STORE_MICRO='facts/project/micro.jsonl'
RECORD_STORE_TICKET_SUFFIX='.json'
RECORD_STORE_CHECKPOINT_SUFFIX='-review-checkpoint.md'

_rs_nl='
'

# 公共依赖兜底：调用方通常已 source common-helpers.sh；未加载时按脚本落位同目录加载，
# 缺失即 fail-closed（无锁语义不写入）。
if ! command -v record_lock_assert >/dev/null 2>&1; then
  _rs_helper_dir=$(dirname -- "$0")
  if [ -f "${_rs_helper_dir}/common-helpers.sh" ]; then
    # shellcheck source=agent-up/scripts/common-helpers.sh  # 动态同目录加载
    # shellcheck disable=SC1091  # 共享库由运行时同目录定位，单文件分析无法跟随动态路径
    . "${_rs_helper_dir}/common-helpers.sh"
  else
    printf 'record-store: FAIL: 共享库缺失（common-helpers.sh）: %s——拒绝在无锁语义下写入\n' \
      "${_rs_helper_dir}/common-helpers.sh" >&2
    exit 2
  fi
fi

# record_store_valid_id <id>：票 id 形态，口径＝ticket-record.schema.json 读侧 id pattern
# ^(REQ-[0-9]{8}-[0-9]{3}|[0-9]{2,}-[a-z0-9-]+) 形态——存量 request 票 REQ-YYYYMMDD-NNN 与任务票
# <NN>-<slug> 均合法（不做类别收窄：checkpoint 与票本体路径须接受 schema 允许的存量形态）。
record_store_valid_id() {
  case ${1:-} in
    '') return 1 ;;
  esac
  printf '%s' "$1" | LC_ALL=C grep -Eq '^(REQ-[0-9]{8}-[0-9]{3}|[0-9]{2,}-[a-z0-9-]+)$'
}

# record_path <记录键>：打印仓库根相对记录路径；未登记键 fail-closed（exit 2）
record_path() {
  case ${1:-} in
    index) printf '%s\n' "$RECORD_STORE_INDEX" ;;
    changes) printf '%s\n' "$RECORD_STORE_CHANGES" ;;
    micro) printf '%s\n' "$RECORD_STORE_MICRO" ;;
    tickets-readme) printf '%s\n' "$RECORD_STORE_TICKETS_README" ;;
    ticket:*)
      _rp_id=${1#ticket:}
      record_store_valid_id "$_rp_id" || \
        die2 "record_path: 票 id 形态不合（schema 读侧允许集＝REQ-YYYYMMDD-NNN 或 NN-slug）: ${_rp_id}"
      printf '%s/%s%s\n' "$RECORD_STORE_TICKETS_DIR" "$_rp_id" "$RECORD_STORE_TICKET_SUFFIX"
      ;;
    checkpoint:*)
      _rp_id=${1#checkpoint:}
      record_store_valid_id "$_rp_id" || \
        die2 "record_path: 票 id 形态不合（schema 读侧允许集＝REQ-YYYYMMDD-NNN 或 NN-slug）: ${_rp_id}"
      printf '%s/%s%s\n' "$RECORD_STORE_TICKETS_DIR" "$_rp_id" "$RECORD_STORE_CHECKPOINT_SUFFIX"
      ;;
    '')
      die2 'record_path: 记录键缺失'
      ;;
    *)
      die2 "record_path: 未登记的记录键: ${1}（路径表＝index|changes|micro|tickets-readme|ticket:<id>|checkpoint:<id>；记录路径只经本表解析）"
      ;;
  esac
}

# record_store_resolve <记录键或仓库根相对记录路径>：打印仓库根相对路径。
# 记录键走 record_path；含 / 的字面路径视为调用方显式传入的记录路径（如 .md 票文件），
# 由 containment 统一校验；裸词一律按未登记记录键拒绝。
record_store_resolve() {
  _rsr_key=${1:-}
  case ${_rsr_key} in
    ''|/*) die1 "记录键或记录路径非法（空或绝对路径）: ${_rsr_key}" ;;
    */*) printf '%s\n' "$_rsr_key" ;;
    *) record_path "$_rsr_key" ;;
  esac
}

# record_store_contain <repo-root> <仓库根相对路径> <create-parent 0|1>：打印目标绝对路径。
# 校验顺序：空/绝对路径 → .. 与 ./ 段 → 父目录 realpath containment（create-parent=1 时
# 先按最近既存祖先判定归属再 mkdir -p，防经 symlink 在仓外建目录）→ 末段 symlink 拒绝。
# 本函数只保证「仓根内」；记录层语义范围由路径表（六类记录键）承载，显式传入的仓库根
# 相对路径（如 legacy .md 票本体）按调用方语义接受但同样受 containment 约束。
# 任一失败 fail-closed，零写入。
record_store_contain() {
  _rsc_root=$1
  _rsc_rel=$2
  _rsc_create=${3:-0}
  case ${_rsc_rel} in
    ''|/*) die1 "记录路径须为仓库根相对路径（不得为空或绝对路径）: ${_rsc_rel}" ;;
  esac
  case "/${_rsc_rel}/" in
    */../*|*/./*) die1 "记录路径不得含 .. 或 ./ 路径段: ${_rsc_rel}" ;;
  esac
  [ -d "${_rsc_root}" ] || die1 "仓库根不存在: ${_rsc_root}"
  _rsc_root_real=$(realpath "${_rsc_root}" 2>/dev/null) || \
    die1 "仓库根 realpath 解析失败: ${_rsc_root}"
  _rsc_parent=$(dirname -- "${_rsc_rel}")
  if [ "${_rsc_create}" = '1' ] && [ ! -d "${_rsc_root}/${_rsc_parent}" ]; then
    _rsc_probe=${_rsc_parent}
    while [ "${_rsc_probe}" != '.' ] && [ "${_rsc_probe}" != '/' ] && \
      [ ! -d "${_rsc_root}/${_rsc_probe}" ]; do
      _rsc_probe=$(dirname -- "${_rsc_probe}")
    done
    _rsc_probe_real=$(realpath "${_rsc_root}/${_rsc_probe}" 2>/dev/null) || \
      die1 "记录路径父目录 realpath 解析失败: ${_rsc_rel}"
    case ${_rsc_probe_real} in
      "${_rsc_root_real}"|"${_rsc_root_real}"/*) : ;;
      *) die1 "记录路径越出仓库根（父目录 realpath containment 失败）: ${_rsc_rel} → ${_rsc_probe_real}" ;;
    esac
    mkdir -p "${_rsc_root}/${_rsc_parent}" || \
      die1 "记录路径父目录创建失败: ${_rsc_rel}"
  fi
  [ -d "${_rsc_root}/${_rsc_parent}" ] || \
    die1 "记录路径父目录不存在（record_write 不代建父目录）: ${_rsc_rel}"
  _rsc_parent_real=$(realpath "${_rsc_root}/${_rsc_parent}" 2>/dev/null) || \
    die1 "记录路径父目录 realpath 解析失败: ${_rsc_rel}"
  case ${_rsc_parent_real} in
    "${_rsc_root_real}"|"${_rsc_root_real}"/*) : ;;
    *) die1 "记录路径越出仓库根（父目录 realpath containment 失败）: ${_rsc_rel} → ${_rsc_parent_real}" ;;
  esac
  [ ! -h "${_rsc_root}/${_rsc_rel}" ] || \
    die1 "记录路径不得为 symlink（symlink 外指 fail-closed）: ${_rsc_rel}"
  printf '%s\n' "${_rsc_root}/${_rsc_rel}"
}

# record_store_lock_begin <repo-root>：调用方已持锁则接管同一把锁（继承或自取皆可），
# 否则经 record_lock_ensure 自取并在 record_store_lock_end 按所有权释放；写点前另经
# record_lock_assert 核对令牌归属（被夺即 fail-closed）。
record_store_lock_begin() {
  RECORD_STORE_LOCK_ACQUIRED=0
  if [ "${RECORD_LOCK_HELD:-0}" = '1' ]; then
    record_lock_assert
    return 0
  fi
  record_lock_ensure "$1"
  record_lock_assert
  if [ "${RECORD_LOCK_OWNED:-0}" = '1' ]; then
    RECORD_STORE_LOCK_ACQUIRED=1
  fi
  return 0
}

record_store_lock_end() {
  if [ "${RECORD_STORE_LOCK_ACQUIRED:-0}" = '1' ]; then
    record_lock_release_owned
  fi
  RECORD_STORE_LOCK_ACQUIRED=0
  return 0
}

# record_store_test_hold：测试钩子——追加前缀窗口放大（未设或 0＝零开销）
record_store_test_hold() {
  case ${RECORD_STORE_TEST_APPEND_HOLD_MS:-} in
    ''|*[!0-9]*|0) return 0 ;;
  esac
  sleep "$((RECORD_STORE_TEST_APPEND_HOLD_MS / 1000)).$(printf '%03d' "$((RECORD_STORE_TEST_APPEND_HOLD_MS % 1000))")"
}

# record_store_mode <文件>：取原文件权限八进制（stat 两形态探测；取不到回退 644）
record_store_mode() {
  _rsm_mode=''
  if [ -e "$1" ]; then
    _rsm_mode=$(stat -f '%Lp' "$1" 2>/dev/null) || _rsm_mode=''
    if [ -z "${_rsm_mode}" ]; then
      _rsm_mode=$(stat -c '%a' "$1" 2>/dev/null) || _rsm_mode=''
    fi
  fi
  printf '%s' "${_rsm_mode:-644}"
}

# record_store_engine：同目录唯一 JSON 引擎定位（安装闭包，缺失 fail-closed）
record_store_engine() {
  _rse_engine=${RECORD_STORE_ENGINE:-"$(dirname -- "$0")/json-validator.py"}
  [ -f "${_rse_engine}" ] || \
    die1 "json-validator.py 不存在（安装闭包缺失）: ${_rse_engine}——记录层字段级改写经唯一 JSON 引擎承载，拒绝旁路（本次零写入）"
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——记录层字段级改写无法执行（fail-closed，本次零写入）'
  printf '%s\n' "${_rse_engine}"
}

# record_write <repo-root> <记录键或记录路径> <内容文件>
# 整文件原子替换：同目录 mktemp＋mv（崩溃只留完整旧版或完整新版，不留半文件）；
# 内容由调用方生成（记录格式知识留在记录语义侧），本动词只承担路径、锁与原子替换。
# 目标可不存在（如独立 checkpoint md 首建）：mv 原子落位，不代建父目录。
record_write() {
  [ $# -eq 3 ] || die2 'record_write 用法: record_write <repo-root> <记录键或记录路径> <内容文件>'
  _rsw_root=$1
  _rsw_key=$2
  _rsw_src=$3
  [ -f "${_rsw_src}" ] || die1 "record_write 内容文件不存在: ${_rsw_src}"
  _rsw_rel=$(record_store_resolve "${_rsw_key}") || exit $?
  _rsw_target=$(record_store_contain "${_rsw_root}" "${_rsw_rel}" 0) || exit $?
  record_store_lock_begin "${_rsw_root}"
  _rsw_dir=$(dirname -- "${_rsw_target}")
  _rsw_tmp=$(mktemp "${_rsw_dir}/.record-store.XXXXXX") || \
    die1 "记录写入临时件创建失败: ${_rsw_rel}"
  if ! cat "${_rsw_src}" > "${_rsw_tmp}"; then
    rm -f "${_rsw_tmp}"
    die1 "记录写入临时件生成失败: ${_rsw_rel}"
  fi
  # 权限还原（票面复审 R2）：既有记录保持原 mode（不因 mktemp 落成 600），目标缺失首建按 644
  if ! chmod "$(record_store_mode "${_rsw_target}")" "${_rsw_tmp}"; then
    rm -f "${_rsw_tmp}"
    die1 "记录写入临时件权限还原失败: ${_rsw_rel}"
  fi
  record_lock_assert
  if ! mv "${_rsw_tmp}" "${_rsw_target}"; then
    rm -f "${_rsw_tmp}"
    die1 "记录文件原子替换失败: ${_rsw_rel}"
  fi
  record_store_lock_end
}

# record_append <repo-root> <记录键或记录路径> <追加片段文件>
# 追加＋前缀断言：先取旧内容现场，直接追加（保持既有 inode 与权限），随后断言旧内容仍是
# 新内容的字节前缀；被并发改写或截断即 fail-closed（本次追加已完成，如实报告不回收）。
# 记录文件懒创建（仅文件本体；父目录在 containment 判定后 mkdir -p）。
record_append() {
  [ $# -eq 3 ] || die2 'record_append 用法: record_append <repo-root> <记录键或记录路径> <追加片段文件>'
  _rsa_root=$1
  _rsa_key=$2
  _rsa_src=$3
  [ -f "${_rsa_src}" ] || die1 "record_append 内容文件不存在: ${_rsa_src}"
  _rsa_rel=$(record_store_resolve "${_rsa_key}") || exit $?
  _rsa_target=$(record_store_contain "${_rsa_root}" "${_rsa_rel}" 1) || exit $?
  record_store_lock_begin "${_rsa_root}"
  record_lock_assert
  if [ ! -f "${_rsa_target}" ]; then
    : > "${_rsa_target}" || die1 "记录文件懒创建失败: ${_rsa_rel}"
  fi
  _rsa_snap=$(mktemp "${TMPDIR:-/tmp}/record-store-prefix.XXXXXX") || \
    die1 "追加前缀现场创建失败: ${_rsa_rel}"
  if ! cp "${_rsa_target}" "${_rsa_snap}"; then
    rm -f "${_rsa_snap}"
    die1 "追加前缀现场复制失败: ${_rsa_rel}"
  fi
  record_lock_assert
  record_store_test_hold
  if ! cat "${_rsa_src}" >> "${_rsa_target}"; then
    rm -f "${_rsa_snap}"
    die1 "记录追加失败: ${_rsa_rel}"
  fi
  if ! record_prefix_ok "${_rsa_snap}" "${_rsa_target}"; then
    rm -f "${_rsa_snap}"
    die1 "追加前缀断言失败：记录文件在追加窗口内被改写或截断（旧内容不再是新内容的字节前缀）: ${_rsa_rel}"
  fi
  rm -f "${_rsa_snap}"
  record_store_lock_end
}

# record_set_json <repo-root> <记录键或记录路径> --doc-set <dotted.path>=<json-value> [...]
# 字段级改写：按序对每个 --doc-set 调唯一 JSON 引擎 json set 序列化到同目录临时件
# （ensure_ascii=False＋indent=2＋末尾换行，与票本体既有 checkpoint.commit 写入形态
# 逐字节一致），每步回读字段核对；全部通过后按原文件权限原子替换。引擎缺失即 fail-closed。
record_set_json() {
  [ $# -ge 4 ] || \
    die2 'record_set_json 用法: record_set_json <repo-root> <记录键或记录路径> --doc-set <dotted.path>=<json-value> [...]'
  _rsj_root=$1
  _rsj_key=$2
  shift 2
  _rsj_specs=''
  while [ $# -gt 0 ]; do
    case $1 in
      --doc-set)
        [ $# -ge 2 ] || die2 '--doc-set 缺值'
        _rsj_specs="${_rsj_specs}${2}${_rs_nl}"
        shift 2
        ;;
      *) die2 "record_set_json 未知参数: $1" ;;
    esac
  done
  [ -n "${_rsj_specs}" ] || die2 'record_set_json 至少需要一个 --doc-set'
  _rsj_rel=$(record_store_resolve "${_rsj_key}") || exit $?
  _rsj_target=$(record_store_contain "${_rsj_root}" "${_rsj_rel}" 0) || exit $?
  [ -f "${_rsj_target}" ] || \
    die1 "记录文件不存在（record_set_json 只做字段级改写，不代创建）: ${_rsj_rel}"
  _rsj_engine=$(record_store_engine) || exit $?
  record_store_lock_begin "${_rsj_root}"
  _rsj_dir=$(dirname -- "${_rsj_target}")
  _rsj_work=$(mktemp "${_rsj_dir}/.record-store.XXXXXX") || \
    die1 "字段级改写临时件创建失败: ${_rsj_rel}"
  if ! cp "${_rsj_target}" "${_rsj_work}"; then
    rm -f "${_rsj_work}"
    die1 "字段级改写现场复制失败: ${_rsj_rel}"
  fi
  _rsj_oldifs=$IFS
  IFS=${_rs_nl}
  for _rsj_spec in ${_rsj_specs}; do
    IFS=${_rsj_oldifs}
    [ -n "${_rsj_spec}" ] || { IFS=${_rs_nl}; continue; }
    case ${_rsj_spec} in
      *=*) _rsj_path=${_rsj_spec%%=*}; _rsj_val=${_rsj_spec#*=} ;;
      *)
        rm -f "${_rsj_work}"
        die1 "record_set_json 字段规格须为 <dotted.path>=<json-value>: ${_rsj_spec}"
        ;;
    esac
    _rsj_next=$(mktemp "${_rsj_dir}/.record-store.XXXXXX") || {
      rm -f "${_rsj_work}"
      die1 "字段级改写临时件创建失败: ${_rsj_rel}"
    }
    if ! python3 "${_rsj_engine}" json set "${_rsj_work}" "${_rsj_path}" "${_rsj_val}" > "${_rsj_next}"; then
      rm -f "${_rsj_work}" "${_rsj_next}"
      die1 "记录字段级改写失败（唯一 JSON 引擎 json set）: ${_rsj_rel}（${_rsj_path}）"
    fi
    if ! python3 "${_rsj_engine}" json get "${_rsj_next}" "${_rsj_path}" > /dev/null; then
      rm -f "${_rsj_work}" "${_rsj_next}"
      die1 "记录字段级改写回读核对失败: ${_rsj_rel}（${_rsj_path}）"
    fi
    mv "${_rsj_next}" "${_rsj_work}" || {
      rm -f "${_rsj_next}" "${_rsj_work}"
      die1 "字段级改写临时件收敛失败: ${_rsj_rel}"
    }
    IFS=${_rs_nl}
  done
  IFS=${_rsj_oldifs}
  chmod "$(record_store_mode "${_rsj_target}")" "${_rsj_work}" || {
    rm -f "${_rsj_work}"
    die1 "字段级改写临时件权限还原失败: ${_rsj_rel}"
  }
  record_lock_assert
  if ! mv "${_rsj_work}" "${_rsj_target}"; then
    rm -f "${_rsj_work}"
    die1 "记录字段级改写原子替换失败: ${_rsj_rel}"
  fi
  record_store_lock_end
}
