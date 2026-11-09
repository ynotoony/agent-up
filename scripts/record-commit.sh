#!/bin/sh
# Input: 记录提交任务：仓库根目录（缺省无——独立入口须显式给出）、提交说明与若干仓库根
#        相对记录路径（须在 facts/ 下）；可选 --name <输出前缀>（缺省 record-commit）。
#        记录层写锁经 common-helpers record_lock_*（与 ticket-ops/ledger-append/checkpoint-write
#        同一把锁）；RECORD_LOCK_INHERITED=1 时按父进程锁目录与令牌继承持有状态。
# Output: 单点记录提交入口（票 288 自 lane-commit.sh 迁出的记录提交实现，全仓唯一一份提交
#         plumbing）：持锁 → 只暂存记录路径到私有索引（GIT_INDEX_FILE，不写共享索引）→
#        拒绝部分暂存（暂存内容≠工作区）→ 只追加账本的 HEAD 旧内容须为待提交版本（私有
#        索引 blob）的字节前缀（与 check-append-only.sh 同源）→ 对私有索引写出的树断言
#        文件集恰为记录路径（混提拒绝）→ write-tree/commit-tree/update-ref CAS 创建提交。
#        两段提交的第二段与 ticket-run commit 记录收口共用本入口；输出行与失败语义与
#        迁出前逐字一致（成功三行：记录提交门/记录提交/记录文件；失败 exit 1 零提交并
#        报首个违规行号，失败不自动回滚暂存内容）。任一断言不成立 fail-closed 零提交。
#        调用方经 --name 指定输出与报错前缀：lane-commit 传 lane-commit 保持原输出行，
#        ticket-run 传 ticket-run 保持其失败报文口径；独立调用缺省 record-commit。
# Pos: 记录提交实现单点（票 288：自 lane-commit.sh 的 --record-commit 段迁出；ticket-run.sh
#      commit 记录收口改调本件，两套提交 plumbing 收敛为一套）。本件只做记录提交，不含
#      道合同解析/门禁/产品提交；写入面＝显式记录路径（须在 facts/ 下）＋私有索引 CAS
#      提交；不运行 Git 提交钩子（commit-tree），不写 HEAD reflog（update-ref 不含
#      --create-reflog）。POSIX sh、零外部依赖、fail-closed。仓侧 rules/implementation/scripts/
#      同名件为 generate-mirrors.sh 生成物，禁止手改。

# 用法与失败语义见同目录 README.md「record-commit.sh」节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'record-commit: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'

# 输出与报错前缀：缺省 record-commit；lane-commit/ticket-run 委托时传自身名字以保持既有
# 输出行与失败报文（票 288：迁出前后语义逐字不变）。
rc_name='record-commit'

rc_fail() {
  printf '%s: FAIL: %s\n' "$rc_name" "$1" >&2
  exit 1
}
rc_die2() {
  printf '%s: %s\n' "$rc_name" "$1" >&2
  exit 2
}

usage() {
  cat <<'USAGE'
用法: sh record-commit.sh [--name <输出前缀>] <repo-root> <message> <记录路径>...
参数:
  repo-root      仓库根目录。
  message        记录提交说明（非空）。
  记录路径...    至少一条仓库根相对记录路径（须在 facts/ 下、工作树存在、仓库根内普通文件）。
  --name <前缀>  输出与报错前缀（缺省 record-commit；lane-commit.sh 委托时传 lane-commit，
                 ticket-run.sh 委托时传 ticket-run，以保持迁出前逐字输出与失败语义）。
  -h / --help    打印本用法。
行为:
  持记录层写锁 → 记录路径白名单（须在 facts/ 下，防混提产品文件）→ 拒绝部分暂存（记录
  路径已在暂存区但与工作区不一致即拒绝，不静默重暂存）→ 记录路径须在工作树存在（删除/
  缺失即拒绝）→ 在私有索引（GIT_INDEX_FILE）上只 git add 记录路径（不写共享索引）→
  只追加账本（facts/project/changes.jsonl、facts/project/micro.jsonl）的 HEAD 旧内容须为
  待提交版本（私有索引 blob）的字节前缀（与 check-append-only.sh 同一原语）→ 对私有索引
  写出的树断言文件集恰为记录路径（含产品文件即拒绝）→ write-tree → commit-tree →
  update-ref CAS 更新当前分支（旧 HEAD 不匹配即失败）。断言对象＝被提交对象；共享索引
  在窗口内被并发暂存不卷入提交，成功后仅同步仍是旧 HEAD 快照的记录路径条目，并发暂存
  保留现场。未改动的记录路径显式列为「已排除」后跳过，不计入提交文件集。
失败语义: 任一断言不成立即 exit 1、零提交、不改写任何历史行；前缀违规报首个违规行号
  （待提交版行号）。失败不自动回滚暂存内容（不改写他人提交）。
注: commit-tree 不运行 Git 提交钩子，update-ref 不写 HEAD reflog。
退出码: 0 提交创建且树已核对；1 记录提交门断言失败（零提交）；2 用法或环境错误。
环境与测试钩子: RECORD_COMMIT_TEST_MARKER（私有索引快照后写标记文件）、
  RECORD_COMMIT_TEST_HOLD_MS（标记后延迟毫秒，未设或 0＝零开销）、
  RECORD_LOCK_TEST_HOLD_MS／RECORD_LOCK_BREAK_STALE／TICKET_OPS_LOCK_TIMEOUT／
  TICKET_OPS_LOCK_STALE（记录层写锁，语义见 common-helpers.sh）。
USAGE
}

# ---- 共享小原语（换行集合；与 lane-commit.sh 同口径，票 282 去重形态）----
# 换行集合表示＝「元素+换行」顺序拼接（元素内不含换行；查重按整元素匹配，不按子串）。
rc_nlset_put() {
  _rnp_set=$1
  _rnp_val=$2
  case "${NL}${_rnp_set}" in
    *"${NL}${_rnp_val}${NL}"*) rc_nlset_result=${_rnp_set}; return 0 ;;
  esac
  rc_nlset_result="${_rnp_set}${_rnp_val}${NL}"
}
rc_nlset_contains() {
  case "${NL}$1" in
    *"${NL}$2${NL}"*) return 0 ;;
  esac
  return 1
}

# ---- 写入面路径边界（票 144 口径；记录提交入口复用）----
# 用途: 校验仓库根相对路径属写入面：文本层拒 .. 与绝对路径、realpath containment 限仓内、
#       形态层拒 symlink 且仅普通文件。违规向 stderr 报因并返回 1。
rc_in_repo() {
  _rir_root=$1
  _rir_path=$2
  _rir_what=$3
  case ${_rir_path} in
    ..|../*|*/..|*/../*|./*|*.|*/./*)
      printf '%s: FAIL: %s 不得含 .. 或 ./ 路径段: %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" >&2
      return 1
      ;;
    /*)
      printf '%s: FAIL: %s 须为仓库根相对路径，不得为绝对路径: %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" >&2
      return 1
      ;;
  esac
  _rir_probe=$(CDPATH='' cd -- "${_rir_root}" 2>/dev/null && pwd -P) || {
    printf '%s: FAIL: 仓库根不可解析为物理路径: %s\n' "${rc_name}" "${_rir_root}" >&2
    return 1
  }
  _rir_real=$(realpath "${_rir_root}/${_rir_path}" 2>/dev/null) || {
    printf '%s: FAIL: %s realpath 解析失败（目标不存在或中途断链）: %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" >&2
    return 1
  }
  case ${_rir_real} in
    "${_rir_probe}"/*) : ;;
    *)
      printf '%s: FAIL: %s 越出仓库根（realpath containment 失败）: %s → %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" "${_rir_real}" >&2
      return 1
      ;;
  esac
  [ ! -h "${_rir_root}/${_rir_path}" ] || {
    printf '%s: FAIL: %s 不得为 symlink: %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" >&2
    return 1
  }
  [ -f "${_rir_root}/${_rir_path}" ] || {
    printf '%s: FAIL: %s 须为仓库根内普通文件: %s\n' "${rc_name}" "${_rir_what}" "${_rir_path}" >&2
    return 1
  }
  return 0
}

tmp_rc_index=''
lock_owned=0

# 用途: EXIT/HUP/INT/TERM 陷阱体，清理私有索引临时件并按所有权释放自取的记录层写锁。
cleanup() {
  if [ -n "${tmp_rc_index}" ]; then rm -f "${tmp_rc_index}"; tmp_rc_index=''; fi
  if [ "${lock_owned}" -eq 1 ]; then record_lock_release; lock_owned=0; fi
}
trap cleanup EXIT HUP INT TERM

# ---- 参数解析 ----
while [ $# -gt 0 ]; do
  case $1 in
    --name)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      rc_name=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done
case ${rc_name} in
  ''|*[!A-Za-z0-9._-]*) printf 'record-commit: 输出前缀非法: %s\n' "${rc_name}" >&2; exit 2 ;;
esac
[ $# -ge 3 ] || { usage >&2; exit 2; }
rc_repo_root=$1
rc_message=$2
shift 2
# 调用方须已把 IFS 设为换行（本文件口径）
IFS=${NL}

[ -d "${rc_repo_root}" ] || rc_die2 "仓库根不存在: ${rc_repo_root}"
git -C "${rc_repo_root}" rev-parse --git-dir >/dev/null 2>&1 || rc_die2 "仓库根不是 Git 仓库: ${rc_repo_root}"
[ -n "${rc_message}" ] || rc_fail '记录提交说明为空'

# 记录路径白名单与写入面边界（只读预检，先于取锁；拒绝把产品文件混进记录提交）
rc_paths=''
for rc_p in "$@"; do
  case ${rc_p} in
    facts/*) : ;;
    *) rc_fail "记录提交拒绝：路径不在 facts/ 记录面内（只暂存记录路径，不得混提产品文件）: ${rc_p}" ;;
  esac
  [ -e "${rc_repo_root}/${rc_p}" ] || \
    rc_fail "记录提交拒绝：记录路径在工作树不存在: ${rc_p}（删除与缺失不属于记录提交，零提交）"
  rc_in_repo "${rc_repo_root}" "${rc_p}" '记录提交路径' || \
    rc_fail "记录提交路径边界校验未通过: ${rc_p}（须为仓库根内普通相对文件）"
  rc_nlset_put "${rc_paths}" "${rc_p}"; rc_paths=${rc_nlset_result}
done

# 持锁（票 246 原语）：独立调用自取锁并负责释放；RECORD_LOCK_INHERITED=1 时按父进程
# 传入的锁目录与令牌继承持有状态，跳过取锁与释放（锁生命周期归父进程）
if record_lock_inherit; then
  :
else
  record_lock_init "${rc_repo_root}"
  record_lock_acquire
  lock_owned=1
fi

rc_t_dir=${TMPDIR:-/tmp}
rc_staged=$(git -C "${rc_repo_root}" diff --cached --name-only)

# 部分暂存拒绝（票 247 AC2）：记录路径已在暂存区且暂存内容与工作区不一致即快照过期，
# 拒绝而非静默重暂存；报首个差异行（待提交暂存版 → 工作区）。
while IFS= read -r rc_p; do
  [ -n "${rc_p}" ] || continue
  rc_is_staged=0
  while IFS= read -r rc_s; do
    [ -n "${rc_s}" ] || continue
    if [ "${rc_s}" = "${rc_p}" ]; then
      rc_is_staged=1
    fi
  done <<EOF_STAGED
${rc_staged}
EOF_STAGED
  [ "${rc_is_staged}" -eq 1 ] || continue
  if git -C "${rc_repo_root}" diff --quiet -- "${rc_p}"; then
    continue
  fi
  rc_idx=$(mktemp "${rc_t_dir%/}/record-idx.XXXXXX")
  rc_wt=$(mktemp "${rc_t_dir%/}/record-wt.XXXXXX")
  if ! git -C "${rc_repo_root}" show ":${rc_p}" > "${rc_idx}" 2>/dev/null; then
    rm -f "${rc_idx}" "${rc_wt}"
    rc_fail "记录提交拒绝：读不出 ${rc_p} 的暂存内容（零提交）"
  fi
  cp "${rc_repo_root}/${rc_p}" "${rc_wt}"
  rc_bad=$(record_first_bad_line "${rc_idx}" "${rc_wt}")
  if [ -z "${rc_bad}" ]; then
    rc_bad=$(( $(wc -l < "${rc_idx}" | tr -d ' ') + 1 ))
  fi
  rm -f "${rc_idx}" "${rc_wt}"
  rc_fail "记录提交拒绝：${rc_p} 暂存内容与工作区不一致（部分暂存，首个差异行 ${rc_bad}）——零提交；先 git add 该路径或撤销过期暂存后重跑"
done <<EOF_PATHS
${rc_paths}
EOF_PATHS

# 私有索引（票 247 D1）：从 HEAD 初始化到 GIT_INDEX_FILE 临时件，后续 git add 与全部
# 断言都只作用于该索引——共享索引在提交窗口内被另一会话改写（中间插入/产品文件暂存）
# 也不会被卷入提交，断言对象即被提交对象。
rc_index=$(mktemp "${rc_t_dir%/}/record-index.XXXXXX") || \
  rc_fail '记录提交拒绝：无法创建私有索引（零提交）'
rm -f "${rc_index}"
tmp_rc_index=${rc_index}
if git -C "${rc_repo_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" read-tree HEAD || \
    rc_fail '记录提交拒绝：私有索引初始化失败（read-tree HEAD，零提交）'
else
  GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" read-tree --empty || \
    rc_fail '记录提交拒绝：私有索引初始化失败（read-tree --empty，零提交）'
fi

# 只暂存记录路径到私有索引；add 后私有索引须与工作区一致（断言对象＝待提交 blob）
while IFS= read -r rc_p; do
  [ -n "${rc_p}" ] || continue
  GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" add -- "${rc_p}" || \
    rc_fail "git add 失败（记录提交，私有索引）: ${rc_p}"
  GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" diff --quiet -- "${rc_p}" || \
    rc_fail "记录提交拒绝：${rc_p} 私有索引内容与工作区不一致（部分暂存）——零提交"
done <<EOF_PATHS
${rc_paths}
EOF_PATHS

# 前缀断言（票 247 AC1）：HEAD 旧内容须为待提交版本（暂存 blob）的字节前缀；非前缀即
# 中间插入/改写/截断，报首个违规行号（待提交版行号），零提交、历史行零改写。
while IFS= read -r rc_p; do
  [ -n "${rc_p}" ] || continue
  record_append_only_path "${rc_p}" || continue
  if ! git -C "${rc_repo_root}" cat-file -e "HEAD:${rc_p}" 2>/dev/null; then
    continue
  fi
  rc_old=$(mktemp "${rc_t_dir%/}/record-old.XXXXXX")
  rc_new=$(mktemp "${rc_t_dir%/}/record-new.XXXXXX")
  if ! git -C "${rc_repo_root}" show "HEAD:${rc_p}" > "${rc_old}" 2>/dev/null; then
    rm -f "${rc_old}" "${rc_new}"
    rc_fail "记录提交拒绝：读不出 HEAD:${rc_p}（零提交）"
  fi
  if ! GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" show ":${rc_p}" > "${rc_new}" 2>/dev/null; then
    rm -f "${rc_old}" "${rc_new}"
    rc_fail "记录提交拒绝：读不出 ${rc_p} 的待提交内容（私有索引，零提交）"
  fi
  if cmp -s "${rc_old}" "${rc_new}"; then
    rm -f "${rc_old}" "${rc_new}"
    continue
  fi
  if ! record_prefix_ok "${rc_old}" "${rc_new}"; then
    rc_bad=$(record_first_bad_line "${rc_old}" "${rc_new}")
    [ -n "${rc_bad}" ] || rc_bad='?'
    rc_old_size=$(wc -c < "${rc_old}" | tr -d ' ')
    rc_new_size=$(wc -c < "${rc_new}" | tr -d ' ')
    rm -f "${rc_old}" "${rc_new}"
    rc_fail "记录提交拒绝：${rc_p} 的 HEAD 旧内容非待提交版本前缀（中间插入或改写；HEAD ${rc_old_size} 字节 → 待提交 ${rc_new_size} 字节），首个违规行号 ${rc_bad}（待提交版行号）——零提交，历史行零改写"
  fi
  rm -f "${rc_old}" "${rc_new}"
done <<EOF_PATHS
${rc_paths}
EOF_PATHS

# 记录路径无实际改动即无提交可创建（零提交，不做空提交）；未改动路径显式告知排除，
# 与 README「提交文件集恰为实际有改动的记录路径」措辞一致（票 247 D4）。
rc_changed=0
rc_unchanged=''
while IFS= read -r rc_p; do
  [ -n "${rc_p}" ] || continue
  if GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" diff --cached --quiet -- "${rc_p}"; then
    rc_nlset_put "${rc_unchanged}" "${rc_p}"; rc_unchanged=${rc_nlset_result}
  else
    rc_changed=1
  fi
done <<EOF_PATHS
${rc_paths}
EOF_PATHS
[ "${rc_changed}" -eq 1 ] || rc_fail '记录路径无实际改动，无提交可创建（零提交）'
if [ -n "${rc_unchanged}" ]; then
  printf '%s: 记录路径无改动，已排除: %s\n' \
    "${rc_name}" "$(printf '%s' "${rc_unchanged}" | paste -sd, -)"
fi

# 测试专用同步点（票 247 D3）：私有索引快照已完成、提交尚未创建时写标记文件；并发
# 用例以标记文件为可观测事件（而非固定 sleep）决定 B 的写入时点，HOLD 仅放大持锁窗口。
if [ -n "${RECORD_COMMIT_TEST_MARKER:-}" ]; then
  printf '%s\n' "$$" > "${RECORD_COMMIT_TEST_MARKER}" || \
    rc_fail '测试标记文件写入失败（RECORD_COMMIT_TEST_MARKER）'
fi
case ${RECORD_COMMIT_TEST_HOLD_MS:-} in
  ''|*[!0-9]*|0) : ;;
  *) sleep "$((RECORD_COMMIT_TEST_HOLD_MS / 1000)).$(printf '%03d' "$((RECORD_COMMIT_TEST_HOLD_MS % 1000))")" ;;
esac

# 提交前归属校验 + 合并态拒绝 + 私有索引写树（票 247 D1/D2）：文件集核对发生在提交
# 创建之前，断言对象＝将被提交的树；核对通过后 commit-tree 只产生对象、update-ref CAS
# 才移动分支，故任何失败路径都零可达提交。
record_lock_assert
if git -C "${rc_repo_root}" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  rc_fail '合并进行中（MERGE_HEAD 在场）：记录提交不创建合并提交——零提交'
fi
rc_tree=$(GIT_INDEX_FILE="${rc_index}" git -C "${rc_repo_root}" write-tree) || \
  rc_fail '记录提交拒绝：私有索引写树失败（零提交）'
if git -C "${rc_repo_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  rc_files=$(git -C "${rc_repo_root}" diff-tree --no-commit-id --name-only -r HEAD "${rc_tree}")
else
  rc_files=$(git -C "${rc_repo_root}" ls-tree -r --name-only "${rc_tree}")
fi
[ -n "${rc_files}" ] || rc_fail '记录提交拒绝：待提交树与 HEAD 无差异（零提交）'
while IFS= read -r rc_f; do
  [ -n "${rc_f}" ] || continue
  rc_nlset_contains "${rc_paths}" "${rc_f}" || \
    rc_fail "记录提交拒绝：待提交树含记录面外文件（记录提交与产品提交混提）: ${rc_f}——零提交；先提交或撤销该暂存后重跑"
done <<EOF_FILES
${rc_files}
EOF_FILES

# 树→提交对象→分支 CAS：旧 HEAD 不匹配即失败（并发提交），commit 对象不可达、零提交。
if git -C "${rc_repo_root}" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  rc_parent=$(git -C "${rc_repo_root}" rev-parse HEAD)
  rc_commit=$(git -C "${rc_repo_root}" commit-tree "${rc_tree}" -p "${rc_parent}" -m "${rc_message}") || \
    rc_fail '记录提交拒绝：commit-tree 创建提交失败（零提交）'
else
  rc_parent=''
  rc_commit=$(git -C "${rc_repo_root}" commit-tree "${rc_tree}" -m "${rc_message}") || \
    rc_fail '记录提交拒绝：commit-tree 创建提交失败（零提交）'
fi
rc_commit_tree=$(git -C "${rc_repo_root}" rev-parse "${rc_commit}^{tree}") || \
  rc_fail '记录提交拒绝：读不出新提交树（零提交）'
[ "${rc_commit_tree}" = "${rc_tree}" ] || \
  rc_fail '记录提交拒绝：新提交树与私有索引树不一致（内部错误，零提交）'
rc_ref=$(git -C "${rc_repo_root}" symbolic-ref -q HEAD) || \
  rc_fail '记录提交拒绝：HEAD 处于分离状态（须在分支上），零提交'
record_lock_assert
if [ -n "${rc_parent}" ]; then
  git -C "${rc_repo_root}" update-ref -m "${rc_name}: 记录提交" \
    "${rc_ref}" "${rc_commit}" "${rc_parent}" || \
    rc_fail '记录提交拒绝：HEAD 已变化（并发提交竞态），零提交，重跑同一命令'
else
  git -C "${rc_repo_root}" update-ref -m "${rc_name}: 记录提交" \
    "${rc_ref}" "${rc_commit}" 0000000000000000000000000000000000000000 || \
    rc_fail '记录提交拒绝：分支已存在或 CAS 失败（零提交，重跑同一命令）'
fi
rc_commit_id=${rc_commit}

# 提交后兜底（票 247 D2）：提交已可达，文件集核对不得再以 exit 1 收场（否则就是
# 「报错但提交已创建」）；tree 与提交前核对一致，此分支正常不可达，只作内部错误诊断。
if [ -n "${rc_parent}" ]; then
  rc_commit_files=$(git -C "${rc_repo_root}" diff-tree --no-commit-id --name-only -r "${rc_commit}")
else
  rc_commit_files=$(git -C "${rc_repo_root}" diff-tree --root --no-commit-id --name-only -r "${rc_commit}")
fi
[ "${rc_commit_files}" = "${rc_files}" ] || \
  warn "记录提交文件集与提交前核对不一致（提交已创建，须人工审计）: ${rc_commit_files}"

# 成功后把记录路径的共享索引同步到新提交：仅当共享索引仍是旧 HEAD 快照时改写，
# 提交窗口内他人暂存的内容保留现场（不覆盖、不回滚；票 247 forbidden）。
while IFS= read -r rc_p; do
  [ -n "${rc_p}" ] || continue
  rc_old_id=''
  rc_idx_id=''
  rc_new_id=''
  if [ -n "${rc_parent}" ]; then
    rc_old_id=$(git -C "${rc_repo_root}" rev-parse -q --verify "${rc_parent}:${rc_p}" 2>/dev/null) || rc_old_id=''
  fi
  rc_idx_id=$(git -C "${rc_repo_root}" rev-parse -q --verify ":${rc_p}" 2>/dev/null) || rc_idx_id=''
  rc_new_id=$(git -C "${rc_repo_root}" rev-parse -q --verify "${rc_commit_id}:${rc_p}" 2>/dev/null) || rc_new_id=''
  if [ "${rc_idx_id}" = "${rc_new_id}" ]; then
    :
  elif [ "${rc_idx_id}" = "${rc_old_id}" ]; then
    git -C "${rc_repo_root}" reset -q "${rc_commit_id}" -- "${rc_p}" || \
      warn "共享索引同步失败（记录提交已创建）: ${rc_p}——手工执行 git reset -q HEAD -- ${rc_p} 收敛"
  else
    warn "共享索引中 ${rc_p} 有并发暂存，已保留现场（记录提交已创建；不静默覆盖）"
  fi
done <<EOF_PATHS
${rc_paths}
EOF_PATHS
rm -f "${rc_index}"
tmp_rc_index=''

printf '%s: 记录提交门: 同锁串行（锁目录 %s）\n' "${rc_name}" "${RECORD_LOCK_DIR}"
printf '%s: 记录提交 %s\n' "${rc_name}" "${rc_commit_id}"
printf '%s: 记录文件: %s\n' "${rc_name}" "$(printf '%s\n' "${rc_files}" | paste -sd, -)"
if [ "${lock_owned}" -eq 1 ]; then
  record_lock_release
  lock_owned=0
fi
