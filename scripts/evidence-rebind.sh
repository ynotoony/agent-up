#!/bin/sh
# Input: 显式授权依据（--authorize <授权依据>，必填）、票分支绑定 worktree、票 id、rebase 后
#        新 base/head 两个 40 位提交号；环境 RECORD_LOCK_INHERITED=1＋锁目录＋令牌时继承父进程
#        记录层写锁（merge-ticket 合并锁），否则自取并在退出时按所有权释放。
# Output: 审查证据重绑单点实现（票 288 自 merge-ticket.sh 的 rebase 后重绑段抽出）：按证据
#        文件自身 base_sha/head_sha/diff_sha 重算并写回（diff 以 git diff --binary |
#        git hash-object 重算），同步 cp md 的 base/head/diff 描述，以证据 reviewer_identity
#        作为 author/committer 在合并前提交「审查证据复绑至 rebase 后 HEAD」，并向
#        facts/project/changes.jsonl 追加一条复绑记录（账本留痕，经唯一写入方 ledger-append.sh）。
#        未显式授权即 fail-closed（exit 1、零改写零提交）；授权依据缺省不猜、不静默改写证据。
# Pos: 审查证据重绑写入方单点（票 288：merge-ticket 只做合并/冲突/清场与证据门，证据重绑
#      归本件）。写入面＝站内 review-evidence.json／同票 cp md／changes.jsonl 追加行；写前
#      全部预检（授权、形态、证据在场、reviewer 身份、新 diff 可算），写点在记录层写锁内，
#      失败即报错不合并、保留现场（worktree 与分支不清理）。POSIX sh、零外部依赖
#      （python3 经唯一 JSON 引擎同目录定位）、fail-closed。仓侧同名件为 generate-mirrors.sh
#      生成物，禁止手改。

# 用法与退出码见同目录 README.md「evidence-rebind.sh」节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  # shellcheck disable=SC1091  # 共享库由运行时同目录定位，单文件分析无法跟随动态路径
  . "$_helper_script"
else
  printf 'evidence-rebind: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

# 记录写入 module（记录路径表唯一承载点）；缺失即 fail-closed（零写入）。
_record_store=$(dirname "$0")/record-store.sh
if [ -f "$_record_store" ]; then
  # shellcheck source=agent-up/scripts/record-store.sh  # 动态同目录加载
  # shellcheck disable=SC1091  # 共享库由运行时同目录定位，单文件分析无法跟随动态路径
  . "$_record_store"
else
  printf 'evidence-rebind: FAIL: 记录写入 module 缺失: %s\n' "$_record_store" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh evidence-rebind.sh --authorize <授权依据> <worktree> <ticket-id> <new-base-sha> <new-head-sha>
参数:
  --authorize <授权依据>  必填：本次重绑的显式授权依据（用户/主 agent 授权原文或可检索引用）；
                        缺省或空白即 exit 1 fail-closed（零改写零提交，不静默改写审查证据）。
  worktree                票分支绑定 worktree（审查证据与产品提交所在站）。
  ticket-id               票 id（<NN>-<slug>），定位 review-evidence.json 与 cp md。
  new-base-sha            rebase 后新基线提交（40 位小写十六进制），写回 base_sha。
  new-head-sha            rebase 后新产品提交（40 位小写十六进制），写回 head_sha 并据此
                          重算 diff_sha（git diff --binary | git hash-object）。
行为:
  预检（授权非空且不含引号/反斜杠/制表符/换行；票 id 与两提交号形态；站为 Git worktree；
  证据文件在场且 base/head/diff 与 reviewer_identity 可解析；新 diff 可算）→ 取记录层写锁
  （父进程已持则继承同一把）→ 改写 review-evidence.json 三个 sha → 同步 cp md 的
  base/head/diff 描述（存在则改）→ 经 ledger-append.sh 追加复绑账本行（留痕）→ 以证据
  reviewer_identity 作为 author/committer 提交「审查证据复绑至 rebase 后 HEAD」。
  输出四行：授权、证据（base/head/diff 旧→新）、账本、提交 ID。
退出码: 0 重绑完成；1 fail-closed（未授权/形态不合/证据缺失/写回或提交失败；零改写或
        已改写未提交，如实报错不静默）；2 用法或环境错误（参数数量、仓库/站无效、引擎或
        写入方缺失）。
USAGE
}

# ---- 参数解析与预检（全部先于任何写入）----

authorization=''
while [ $# -gt 0 ]; do
  case $1 in
    --authorize)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      authorization=$2
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
[ $# -eq 4 ] || { usage >&2; exit 2; }
[ -n "${authorization}" ] || \
  die1 '未显式授权：缺少 --authorize <授权依据>——审查证据不得静默改写（fail-closed，零写入零提交）'
case ${authorization} in
  *'"'*|*\\*|*"${TAB}"*|*"${NL}"*)
    die1 "授权依据不得含双引号/反斜杠/制表符/换行（账本行与 JSON 安全）: ${authorization}"
    ;;
esac

wt=$1
ticket_id=$2
new_base=$3
new_head=$4

printf '%s' "${ticket_id}" | grep -Eq '^[0-9]{2,}-[a-z0-9]+([a-z0-9-]*[a-z0-9])?$' || \
  die2 "ticket-id 不合规范（须为 <NN>-<slug>）: ${ticket_id}"
for _sha in "${new_base}" "${new_head}"; do
  printf '%s' "${_sha}" | grep -Eq '^[0-9a-f]{40}$' || \
    die2 "提交号形态不合（须 40 位小写十六进制）: ${_sha}"
done
[ -d "${wt}" ] || die2 "worktree 不存在: ${wt}"
git -C "${wt}" rev-parse --git-dir >/dev/null 2>&1 || die2 "worktree 不是有效 Git 仓库: ${wt}"
wt=$(CDPATH='' cd -- "${wt}" && pwd -P) || die2 'worktree 物理路径不可解析'

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || die2 '脚本目录不可解析'
json_engine="${script_dir}/json-validator.py"
[ -f "${json_engine}" ] || die2 "唯一 JSON 引擎缺失: ${json_engine}"
ledger_append="${script_dir}/ledger-append.sh"
[ -r "${ledger_append}" ] || die2 "账本唯一写入方缺失: ${ledger_append}"
command -v python3 >/dev/null 2>&1 || die2 'python3 不可用，无法读写审查证据 JSON'

ev_rel="${RECORD_STORE_TICKETS_DIR}/${ticket_id}.review-evidence.json"
cp_rel="${RECORD_STORE_TICKETS_DIR}/${ticket_id}-review-checkpoint.md"
changes_rel=$(record_path changes)
ev_file="${wt}/${ev_rel}"
cp_file="${wt}/${cp_rel}"
[ -f "${ev_file}" ] || die1 "审查证据文件缺失，无法重绑（零改写）: ${ev_rel}"
[ ! -L "${ev_file}" ] || die1 "审查证据文件不得为 symlink（零改写）: ${ev_rel}"

old_base=$(python3 "${json_engine}" json get "${ev_file}" base_sha 2>/dev/null) || old_base=''
old_head=$(python3 "${json_engine}" json get "${ev_file}" head_sha 2>/dev/null) || old_head=''
old_diff=$(python3 "${json_engine}" json get "${ev_file}" diff_sha 2>/dev/null) || old_diff=''
for _sha in "${old_base}" "${old_head}" "${old_diff}"; do
  printf '%s' "${_sha}" | grep -Eq '^[0-9a-f]{40}$' || \
    die1 "审查证据 base/head/diff 形态不合（须 40 位小写十六进制），无法重绑（零改写）: ${ev_rel}"
done
reviewer=$(python3 "${json_engine}" json get "${ev_file}" reviewer_identity 2>/dev/null) || reviewer=''
[ -n "${reviewer}" ] || die1 "审查证据缺 reviewer_identity，无法以审查者身份提交重绑（零改写）: ${ev_rel}"
case ${reviewer} in
  *' '*|*"${TAB}"*|*"${NL}"*|*'"'*|*\\*)
    die1 "reviewer_identity 形态不合（不得含空白/引号/反斜杠）：${reviewer}"
    ;;
esac

new_diff=$(git -C "${wt}" diff --binary "${new_base}" "${new_head}" | git -C "${wt}" hash-object --stdin) || new_diff=''
printf '%s' "${new_diff}" | grep -Eq '^[0-9a-f]{40}$' || \
  die1 "rebase 后 diff 指纹重算失败（未写入、未提交）"

# ---- 写点（记录层写锁内；父进程已持锁则继承同一把）----

record_lock_ensure "${wt}"
cleanup() { record_lock_release_owned; }
trap cleanup EXIT HUP INT TERM

_ev_mode=$(stat -f '%Lp' "${ev_file}" 2>/dev/null) || _ev_mode=$(stat -c '%a' "${ev_file}" 2>/dev/null) || _ev_mode=''
[ -n "${_ev_mode}" ] || _ev_mode='644'
for _pair in "base_sha:${new_base}" "head_sha:${new_head}" "diff_sha:${new_diff}"; do
  _key=${_pair%%:*}
  _val=${_pair#*:}
  _ev_tmp="${ev_file}.rebind.$$"
  if ! python3 "${json_engine}" json set "${ev_file}" "${_key}" "\"${_val}\"" > "${_ev_tmp}"; then
    rm -f "${_ev_tmp}"
    die1 "审查证据 ${_key} 重写失败（未提交）: ${ev_rel}"
  fi
  mv "${_ev_tmp}" "${ev_file}" || {
    rm -f "${_ev_tmp}"
    die1 "审查证据原子替换失败（未提交）: ${ev_rel}"
  }
done
chmod "${_ev_mode}" "${ev_file}" 2>/dev/null || true

cp_changed=0
if [ -f "${cp_file}" ]; then
  _cp_mode=$(stat -f '%Lp' "${cp_file}" 2>/dev/null) || _cp_mode=$(stat -c '%a' "${cp_file}" 2>/dev/null) || _cp_mode=''
  [ -n "${_cp_mode}" ] || _cp_mode='644'
  _cp_tmp="${cp_file}.rebind.$$"
  _cp_sed=''
  for _pair in "${old_base}:${new_base}" "${old_head}:${new_head}" "${old_diff}:${new_diff}"; do
    _o=${_pair%%:*}
    _n=${_pair#*:}
    [ "${_o}" = "${_n}" ] && continue
    _cp_sed="${_cp_sed}s/${_o}/${_n}/g;"
    _os=$(printf '%s' "${_o}" | cut -c1-7)
    _ns=$(printf '%s' "${_n}" | cut -c1-7)
    [ "${_os}" = "${_ns}" ] || _cp_sed="${_cp_sed}s/${_os}/${_ns}/g;"
  done
  if [ -n "${_cp_sed}" ]; then
    sed "${_cp_sed}" "${cp_file}" > "${_cp_tmp}" || {
      rm -f "${_cp_tmp}"
      die1 "cp md 证据描述同步失败（未提交）: ${cp_rel}"
    }
    mv "${_cp_tmp}" "${cp_file}" || {
      rm -f "${_cp_tmp}"
      die1 "cp md 原子替换失败（未提交）: ${cp_rel}"
    }
    chmod "${_cp_mode}" "${cp_file}" 2>/dev/null || true
    cp_changed=1
  fi
fi

# 账本留痕（票 288）：复绑事实落 changes.jsonl 一行；写入方＝同目录 ledger-append.sh（唯一
# 写入方），继承本进程已持有的记录层写锁。授权依据与新旧 sha 全入 decision，可追溯。
_ledger_row=$(printf '{"date":"%s","kind":"rebind","scope":"ticket/%s","decision":"审查证据复绑授权：%s；base %s→%s，head %s→%s，diff %s→%s","evidence_ref":"%s"}' \
  "$(date -u +%F)" "${ticket_id}" "${authorization}" "${old_base}" "${new_base}" "${old_head}" "${new_head}" "${old_diff}" "${new_diff}" "${ev_rel}")
RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
  sh "${ledger_append}" "${wt}" --ledger-line "${_ledger_row}" || \
  die1 "审查证据重绑账本留痕失败（ledger-append fail-closed；证据已改写未提交，未合并）: ${changes_rel}"

if [ "${cp_changed}" -eq 1 ]; then
  git -C "${wt}" add -- "${ev_rel}" "${cp_rel}" "${changes_rel}" || \
    die1 "审查证据复绑暂存失败（未提交）: ${ev_rel}"
else
  git -C "${wt}" add -- "${ev_rel}" "${changes_rel}" || \
    die1 "审查证据复绑暂存失败（未提交）: ${ev_rel}"
fi
GIT_AUTHOR_NAME="reviewer" GIT_AUTHOR_EMAIL="${reviewer}" \
  GIT_COMMITTER_NAME="reviewer" GIT_COMMITTER_EMAIL="${reviewer}" \
  git -C "${wt}" -c commit.gpgsign=false commit -qm 'chore(records): 审查证据复绑至 rebase 后 HEAD' || \
  die1 "审查证据复绑提交失败（未合并；worktree 与分支保留）"

commit_sha=$(git -C "${wt}" rev-parse HEAD)
printf 'evidence-rebind: 授权: %s\n' "${authorization}"
printf 'evidence-rebind: 证据: %s（base %s → %s，head %s → %s，diff %s → %s）\n' \
  "${ev_rel}" "${old_base}" "${new_base}" "${old_head}" "${new_head}" "${old_diff}" "${new_diff}"
printf 'evidence-rebind: 账本: %s（追加复绑记录）\n' "${changes_rel}"
printf 'evidence-rebind: 提交: %s\n' "${commit_sha}"
