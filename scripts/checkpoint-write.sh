#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与 review-checkpoint 子命令参数：
#        --ticket <仓库根相对票文件>、--verdict-quote <用户裁决原文>、--verdict-at <裁决时间>、
#        --commit <产品提交 ID>、--commit-subject <提交标题>、--diff-summary <diff 摘要>，
#        可选 --date <YYYY-MM-DD>（记录块日期标题，缺省当日）。
# Output: User Review Checkpoint 记录块一处写入——.md 票追加票尾；.json 票体零追加，落独立
#         facts/requirements/tickets/<id>-review-checkpoint.md（<id>＝票文件去 .json 后缀；
#         文件不存在则随记录块创建一级标题，已存在则追加记录块）。记录块格式（日期标题＋
#         裁决原文＋裁决时间＋提交 ID 与标题＋diff 摘要）与本件拆出前 lane-commit.sh 逐字节
#         一致（票 108 两种票体记录块同格式）。stdout 末行固定为机器契约行
#         `checkpoint-write: 目标文件: <仓库根相对路径>`，供调用方登记记录提交面。
# Pos: User Review Checkpoint 唯一写入方（票 229：自 lane-commit.sh 拆出的记录写职责；
#      道脚本 lane-commit.sh 经同目录优先／PATH 回退定位本件，本件不反向调用任何道脚本）。
#      写入面＝调用方传入的票文件（.md）或票目录内独立 checkpoint md；不触索引、账本、
#      README 与投影。记录层写锁（票 271）：写入前经共享库 record_lock_ensure 取锁——独立
#      调用自取并在退出时按所有权释放，RECORD_LOCK_INHERITED=1 时继承父进程锁且不释放；
#      每个写入点前经 record_lock_assert 核对令牌归属，被夺即 fail-closed 零写入（被夺前
#      已完成的写入不回收，如实报告）。POSIX sh、零外部依赖、fail-closed（参数不合、票文件
#      不存在、末段 symlink 或父目录 realpath 越界即停止，停止时零写入）。

# 用法、输入/输出契约与退出码见同目录 README.md checkpoint-write 专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（与其余道脚本同口径：die/warn/resolve_repo_root 单一实现）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'checkpoint-write: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

TICKETS_DIR='facts/requirements/tickets'

usage() {
  cat <<'USAGE'
用法: sh checkpoint-write.sh [repo-root] review-checkpoint --ticket <票文件> \
        --verdict-quote <裁决原文> --verdict-at <裁决时间> \
        --commit <提交 ID> --commit-subject <提交标题> --diff-summary <diff 摘要> \
        [--date <YYYY-MM-DD>]
参数:
  repo-root      仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  review-checkpoint  子命令（本件唯一写入面：User Review Checkpoint 记录块）。
  --ticket <path>        仓库根相对票文件（.md 或 .json），须为仓库根内普通文件。
  --verdict-quote <text> 用户裁决原文（记录块「裁决原文」行）。
  --verdict-at <time>    裁决时间（记录块「裁决时间」行）。
  --commit <id>          产品提交 ID（记录块「提交」行）。
  --commit-subject <s>   产品提交标题（与提交 ID 同行）。
  --diff-summary <s>     产品提交 diff 摘要（记录块「diff 摘要」行）。
  --date <YYYY-MM-DD>    记录块日期标题；缺省当日。
  -h / --help            打印本用法。
输出契约:
  stdout 逐行人读进度，末行固定为 `checkpoint-write: 目标文件: <仓库根相对路径>`——
  即本次实际写入的记录块承载文件（.md 票＝票文件本身；.json 票＝独立 checkpoint md）。
  .md 票追加票尾；.json 票体零追加（状态唯一真相源＝索引，票 108）。
退出码: 0 写入完成；1 fail-closed（参数语义不合、票文件缺失或路径越界；停止时零写入）；
        2 用法或环境错误。
USAGE
}

# 父目录物理边界：realpath 解析仓根与目标父目录，拒绝父目录 symlink 逃逸。
cw_in_repo_parent() {
  _cwp_path=$1
  _cwp_what=$2
  _cwp_root_real=$(realpath "${repo_root}" 2>/dev/null) || \
    die1 "仓库根 realpath 解析失败: ${repo_root}"
  _cwp_parent_real=$(realpath "$(dirname "${repo_root}/${_cwp_path}")" 2>/dev/null) || \
    die1 "${_cwp_what} 父目录 realpath 解析失败: ${_cwp_path}"
  case ${_cwp_parent_real} in
    "${_cwp_root_real}"|"${_cwp_root_real}"/*) : ;;
    *) die1 "${_cwp_what} 越出仓库根（父目录 realpath containment 失败）: ${_cwp_path} → ${_cwp_parent_real}" ;;
  esac
}

# 写入面路径边界：拒绝 .. 与 ./ 路径段、绝对路径、末段 symlink 与父目录物理逃逸，
# 并要求目标为仓库根内既存普通文件；任何写入之前执行（停止时零写入）。
cw_in_repo_file() {
  _cwf_path=$1
  _cwf_what=$2
  case ${_cwf_path} in
    ..|../*|*/..|*/../*|./*|*.|*/./*)
      die1 "${_cwf_what} 不得含 .. 或 ./ 路径段: ${_cwf_path}"
      ;;
    /*)
      die1 "${_cwf_what} 须为仓库根相对路径，不得为绝对路径: ${_cwf_path}"
      ;;
  esac
  [ -f "${repo_root}/${_cwf_path}" ] || die1 "${_cwf_what} 不存在或不是普通文件: ${_cwf_path}"
  [ ! -h "${repo_root}/${_cwf_path}" ] || die1 "${_cwf_what} 不得为 symlink: ${_cwf_path}"
  cw_in_repo_parent "${_cwf_path}" "${_cwf_what}"
}

case $# in
  0) usage >&2; exit 2 ;;
esac

repo_root=''
cmd=''
case $1 in
  -h|--help) usage; exit 0 ;;
  review-checkpoint)
    # 无 repo-root 形态：首参即子命令，仓库根经 resolve_repo_root --git 推导
    cmd=$1
    shift
    ;;
  -*) usage >&2; exit 2 ;;
  *)
    # 首参为仓库根，其后须为子命令
    repo_root=$1
    shift
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    cmd=$1
    shift
    ;;
esac

case ${cmd} in
  review-checkpoint) ;;
  *) usage >&2; exit 2 ;;
esac

[ -n "${repo_root:-}" ] || repo_root=$(resolve_repo_root --git) || \
  die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"

ticket=''
verdict_quote=''
verdict_at=''
commit_id=''
commit_subject=''
diff_summary=''
date_value=''
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --ticket) [ $# -ge 2 ] || die2 '--ticket 缺值'; ticket=$2; shift 2 ;;
    --verdict-quote) [ $# -ge 2 ] || die2 '--verdict-quote 缺值'; verdict_quote=$2; shift 2 ;;
    --verdict-at) [ $# -ge 2 ] || die2 '--verdict-at 缺值'; verdict_at=$2; shift 2 ;;
    --commit) [ $# -ge 2 ] || die2 '--commit 缺值'; commit_id=$2; shift 2 ;;
    --commit-subject) [ $# -ge 2 ] || die2 '--commit-subject 缺值'; commit_subject=$2; shift 2 ;;
    --diff-summary) [ $# -ge 2 ] || die2 '--diff-summary 缺值'; diff_summary=$2; shift 2 ;;
    --date) [ $# -ge 2 ] || die2 '--date 缺值'; date_value=$2; shift 2 ;;
    --*) die2 "未知参数: $1" ;;
    *) die2 "多余参数: $1" ;;
  esac
done

[ -n "${ticket}" ] || die2 '缺少 --ticket'
[ -n "${verdict_quote}" ] || die2 '缺少 --verdict-quote'
[ -n "${verdict_at}" ] || die2 '缺少 --verdict-at'
[ -n "${commit_id}" ] || die2 '缺少 --commit'
[ -n "${commit_subject}" ] || die2 '缺少 --commit-subject'
[ -n "${diff_summary}" ] || die2 '缺少 --diff-summary'
[ -n "${date_value}" ] || date_value=$(date +%F)
printf '%s' "${date_value}" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || \
  die1 "记录块日期不合 YYYY-MM-DD 口径: ${date_value}"

cw_in_repo_file "${ticket}" 'ticket 票文件'

# 票体形态分派（票 108）：.json 票体零追加，Checkpoint 落独立 checkpoint md；.md 票追加票尾。
t_stem=${ticket##*/}
case ${t_stem} in
  *.json) t_stem=${t_stem%.json}; ticket_is_json=1 ;;
  *)
    t_stem=${t_stem%.md}
    ticket_is_json=0
    ;;
esac

# 记录层写锁（票 271）：取锁点在所有参数与路径边界校验之后、写入之前——校验失败路径
# 不取锁亦零写入；继承标记（RECORD_LOCK_INHERITED=1＋锁目录＋令牌）由调用方传入时接管
# 父进程的锁，退出时不释放父锁（record_lock_release_owned 按所有权判定）。
trap 'record_lock_release_owned' EXIT HUP INT TERM
record_lock_ensure "${repo_root}"

# 记录块（与 lane-commit.sh 拆出前同格式：日期标题＋裁决原文＋裁决时间＋提交＋diff 摘要）
emit_checkpoint_block() {
  printf '\n## User Review Checkpoint（%s，lane-commit.sh）\n\n' "${date_value}"
  printf -- '- 裁决原文：%s\n' "${verdict_quote}"
  printf -- '- 裁决时间：%s\n' "${verdict_at}"
  printf -- '- 提交：%s %s\n' "${commit_id}" "${commit_subject}"
  printf -- '- diff 摘要：%s\n' "${diff_summary}"
}

if [ "${ticket_is_json}" -eq 1 ]; then
  ck_target="${TICKETS_DIR}/${t_stem}-review-checkpoint.md"
  cw_in_repo_parent "${ck_target}" 'User Review Checkpoint 目标'
  if [ ! -f "${repo_root}/${ck_target}" ]; then
    record_lock_assert
    { printf '# 票 %s User Review Checkpoint（用户即 Review 道）\n' "${t_stem}"
      emit_checkpoint_block
    } > "${repo_root}/${ck_target}" || die1 "User Review Checkpoint 文件创建失败: ${ck_target}"
  else
    [ ! -h "${repo_root}/${ck_target}" ] || die1 "User Review Checkpoint 目标不得为 symlink: ${ck_target}"
    record_lock_assert
    emit_checkpoint_block >> "${repo_root}/${ck_target}" || die1 "User Review Checkpoint 追加失败: ${ck_target}"
  fi
  printf 'checkpoint-write: User Review Checkpoint 已追加: %s（.json 票体零追加，独立 checkpoint md 承载）\n' "${ck_target}"
else
  ck_target=${ticket}
  record_lock_assert
  emit_checkpoint_block >> "${repo_root}/${ck_target}" || die1 "User Review Checkpoint 追加失败: ${ck_target}"
  printf 'checkpoint-write: User Review Checkpoint 已追加: %s\n' "${ck_target}"
fi

printf 'checkpoint-write: 目标文件: %s\n' "${ck_target}"
