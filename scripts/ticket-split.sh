#!/bin/sh
# Input: 仓库根（位置参数可省，缺省经 resolve_repo_root 推导）与批量拆票表（--batch <file>，
#        非执行式文本行，每有效行＝「<票 id> <账本行 JSON>」：首个 ASCII 空格前为票 id，
#        其后整行原样作为票务 open 的 --ledger-line；空行与 # 起始行为注释）。票本体的
#        complexity／title／blocked_by 自 facts/requirements/tickets/<id>.json 派生（唯一
#        JSON 引擎 json get），批量表不重复承载这三项——避免索引条目与票本体漂移。
# Output: 拆票收尾单入口（票 293）：逐张复用同目录 ticket-ops.sh open 的全量校验（本体
#        schema／七维 profile reason 门／NN 段查重／账本行型预检）与幂等重放，全部成功后
#        经同目录 record-commit.sh（私有索引／前缀门／CAS 唯一提交 plumbing）一次性提交
#        记录面（N 张票本体＋index＋changes＋progress-current＋tickets README）。任一票
#        失败即零提交并指名失败票（已成功开票的写入保留，重跑同一命令按幂等路径收敛）；
#        记录面与 HEAD 全部一致时不创建空提交（幂等重跑 exit 0）；提交失败如实报告并
#        保留工作区可重试。本件只做批量编排——票务校验／幂等／投影再生归 ticket-ops.sh，
#        记录提交归 record-commit.sh，本件零词法核心、零索引写入、零账本写入、零提交
#        plumbing 副本。POSIX sh（#!/bin/sh、set -eu、set -f）、fail-closed。
# Pos: 拆票批量入口（票 293 D1：批量开票＋一次性记录提交）；同目录定位 ticket-ops.sh／
#      record-commit.sh／record-store.sh／common-helpers.sh／json-validator.py（安装闭包
#      形态，缺件即预检停止）。仓侧 rules/implementation/scripts/ 同名件为
#      generate-mirrors.sh 生成物，禁止手改。用法、批量表格式与退出码见同目录 README.md
#      「ticket-split.sh」专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

prog=ticket-split

# Source common helper functions（共享错误处理、仓库根推导与记录层写锁原语）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf '%s: FAIL: 共享库缺失: %s\n' "$prog" "$_helper_script" >&2
  exit 2
fi

# 记录路径唯一承载表（record_path：index／changes／tickets-readme／ticket:<id>）
_record_store=$(dirname "$0")/record-store.sh
if [ -f "$_record_store" ]; then
  # shellcheck source=agent-up/scripts/record-store.sh  # 动态同目录加载
  # shellcheck disable=SC1091  # 共享库由运行时同目录定位，单文件分析无法跟随动态路径
  . "$_record_store"
else
  printf '%s: FAIL: 记录写入 module 缺失: %s\n' "$prog" "$_record_store" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# 投影载体（既有面，不在 record-store 路径表内；与 ticket-ops.sh 同值）
progress_current_rel='facts/requirements/tickets/progress-current.md'

usage() {
  cat <<'USAGE'
用法: sh ticket-split.sh [repo-root] --batch <file>
参数:
  repo-root       仓库根目录；缺省经 resolve_repo_root 推导（落位形态或当前 Git 仓库）。
  --batch <file>  批量拆票表（必选）：每有效行「<票 id> <账本行 JSON>」——首个 ASCII 空格
                  前为票 id（^[0-9]{2,}-[a-z0-9-]+$），其后整行原样作为 open 的
                  --ledger-line（键序/行型合同同 ledger-append.sh）；空行与 # 起始行注释。
                  票本体的 complexity／title／blocked_by 由本件从
                  facts/requirements/tickets/<id>.json 派生，批量表不重复承载。
  -h / --help     打印本用法。
行为:
  批量层只做编排：逐张调用同目录 ticket-ops.sh open（本体 schema 校验、七维 profile
  reason 门、NN 段查重、账本行型预检与幂等重放全部沿用单票路径，本件不复制任何校验
  规则）；全部成功后经同目录 record-commit.sh（--name ticket-split）一次性提交记录面
  路径：N 张票本体＋facts/requirements/tickets/index.json＋facts/project/changes.jsonl
  ＋facts/requirements/tickets/progress-current.md＋facts/requirements/tickets/README.md。
  全程持同一把记录层写锁（子调用经继承标记接管，不各自取锁）。提交说明按记录面规范
  生成：chore(records): <YYYY-MM-DD> 拆票批量开票（票 <id1>/<id2>…）。
失败语义: 批量表格式／id 口径／批内重复或 NN 撞号／票本体缺失 → exit 1 零写入（先于任何
  open）；任一票 open 失败 → 继续尝试其余票以指名全部失败票，随后 exit 1 且零提交（已
  成功开票的写入保留，修好后重跑同一命令按幂等路径收敛）；记录提交失败 → exit 1 如实
  报告，工作区保留可重试。全部记录路径与 HEAD 一致（幂等重放）→ exit 0 且不建空提交。
退出码: 0 全部开票完成且记录提交创建，或幂等重放无提交可创建；1 fail-closed（批量表/
  票本体/open/提交任一不过；零提交）；2 用法或环境错误（缺 --batch、依赖件缺失、仓库根
  非 Git 仓库等）。
环境变量: TICKET_OPS_LOCK_TIMEOUT／TICKET_OPS_LOCK_STALE／RECORD_LOCK_BREAK_STALE／
  RECORD_LOCK_INHERITED（记录层写锁，语义见 common-helpers.sh；本件自取锁后子调用继承）。
USAGE
}

# ---- 选项解析 ----
repo_root_arg=''
batch_file=''
while [ $# -gt 0 ]; do
  case $1 in
    --batch)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      batch_file=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --break-stale-lock)
      RECORD_LOCK_BREAK_STALE=1
      export RECORD_LOCK_BREAK_STALE
      shift
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      [ -z "${repo_root_arg}" ] || { usage >&2; exit 2; }
      repo_root_arg=$1
      shift
      ;;
  esac
done
[ -n "${batch_file}" ] || { usage >&2; exit 2; }
[ -r "${batch_file}" ] || die2 "批量拆票表不存在或不可读: ${batch_file}"

# ---- 仓库根与运行时依赖定位（预检，先于任何写入）----
if [ -n "${repo_root_arg}" ]; then
  _rr=$(resolve_repo_root "${repo_root_arg}") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "${_rr}" ] || die2 "仓库根不可用: ${repo_root_arg:-（未传参且脚本落位无法缺省推导）}"
[ -d "${_rr}" ] || die2 "仓库根不存在: ${_rr}"
repo_root=${_rr}
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 ||   die2 "仓库根不是 Git 仓库（记录提交需 Git）: ${repo_root}"

ticket_ops_cmd="${script_dir}/ticket-ops.sh"
record_commit_cmd="${script_dir}/record-commit.sh"
_engine="${script_dir}/json-validator.py"
for _req in "${ticket_ops_cmd}" "${record_commit_cmd}" "${_engine}" "${script_dir}/ledger-append.sh" "${script_dir}/generate-progress.sh"; do
  [ -f "${_req}" ] && [ -r "${_req}" ] ||     die2 "运行时依赖缺失（安装闭包不完整）: ${_req}——按 Agent Up 包 references/upgrade.md 升级或运行 scripts/install.sh 修补安装后重跑"
done
command -v python3 >/dev/null 2>&1 || die2 'python3 不可用——票本体字段派生（唯一 JSON 引擎）无法执行'

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ticket-split.XXXXXX") || die2 '临时目录创建失败'
tmp_rows="${tmp_dir}/rows"
cleanup() {
  rm -rf "${tmp_dir}"
  # 记录层写锁按所有权释放（未取锁或继承父锁时幂等空操作，父锁不删）
  record_lock_release_owned
}
trap cleanup EXIT HUP INT TERM

# ---- 批量表解析（fail-closed，先于任何票务写入）----
ids_set=''
n_rows=0
_ln=0
while IFS= read -r _line || [ -n "${_line}" ]; do
  _ln=$((_ln + 1))
  case ${_line} in
    ''|'#'*) continue ;;
  esac
  case ${_line} in
    *' '*) : ;;
    *) die1 "批量拆票表第 ${_ln} 行缺少账本行（格式：<票 id> <账本行 JSON>，首个空格后为账本行）" ;;
  esac
  _id=${_line%% *}
  _ledger=${_line#* }
  case ${_id} in
    '') die1 "批量拆票表第 ${_ln} 行票 id 为空" ;;
  esac
  printf '%s' "${_id}" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' ||     die1 "批量拆票表第 ${_ln} 行票 id 不合口径（^[0-9]{2,}-[a-z0-9-]+$）: ${_id}"
  [ -n "${_ledger}" ] || die1 "批量拆票表第 ${_ln} 行账本行为空（首个空格后须为完整 JSONL 账本行）"
  case "${NL}${ids_set}" in
    *"${NL}${_id}${NL}"*) die1 "批量拆票表票 id 批内重复: ${_id}——同一批不得重复开票" ;;
  esac
  ids_set="${ids_set}${_id}${NL}"
  printf '%s\t%s\n' "${_id}" "${_ledger}" >> "${tmp_rows}"
  n_rows=$((n_rows + 1))
done < "${batch_file}"
[ "${n_rows}" -ge 1 ] || die1 "批量拆票表零有效行: ${batch_file}"

# ---- 批内 NN 号段唯一性预检：同 NN 异 slug 在单票 open 侧会被索引查重拒开，但那是批内
#      自撞；此处一次指名全部冲突者，避免逐票失败才发现 ----
_nn_seen=''
_nn_dup=''
while IFS="${TAB}" read -r _id _ledger; do
  _nn=${_id%%-*}
  case "${NL}${_nn_seen}" in
    *"${NL}${_nn}=${NL}"*) _nn_dup="${_nn_dup}${_id}（NN ${_nn}） " ;;
    *) _nn_seen="${_nn_seen}${_nn}=${NL}" ;;
  esac
done < "${tmp_rows}"
[ -z "${_nn_dup}" ] || die1 "批量拆票表批内 NN 撞号（同 NN 异 slug 不得同批开票）: ${_nn_dup}"

# ---- 票本体在位预检（缺件批量前即停，零 open 零写入）----
_missing_body=''
while IFS="${TAB}" read -r _id _ledger; do
  _body="${repo_root}/$(record_path "ticket:${_id}")"
  if [ ! -f "${_body}" ] || [ ! -r "${_body}" ]; then
    _missing_body="${_missing_body}${_id} "
  fi
done < "${tmp_rows}"
[ -z "${_missing_body}" ] ||   die1 "批量拆票表所列票本体缺失（先落位过 schema 的票 JSON 本体再批量开票；零写入）: ${_missing_body}"

# ---- 单票 open（复用 ticket-ops.sh 全量校验与幂等；持锁继承，不各自取锁）----
split_open_one() {
  # $1=票 id $2=账本行；返回 0＝成功（输出已打印），1＝失败（已打印报因）
  _so_id=$1
  _so_ledger=$2
  _so_body="${repo_root}/$(record_path "ticket:${_so_id}")"
  _so_cx=''
  _so_title=''
  _so_blocked=''
  _so_blocked_raw=''
  _so_rc=0
  if ! _so_cx=$(python3 "${_engine}" json get "${_so_body}" complexity 2>&1); then
    _so_rc=1
  fi
  if [ "${_so_rc}" -eq 0 ] && ! _so_title=$(python3 "${_engine}" json get "${_so_body}" title 2>&1); then
    _so_rc=1
  fi
  if [ "${_so_rc}" -eq 0 ] && ! _so_blocked_raw=$(python3 "${_engine}" json get "${_so_body}" blocked_by '[]' 2>&1); then
    _so_rc=1
  fi
  if [ "${_so_rc}" -eq 0 ]; then
    # blocked_by 数组 → open 的逗号分隔形态（票 id 字符集不含引号/逗号/空白，纯文本归一安全）
    _so_blocked=$(printf '%s' "${_so_blocked_raw}" | sed 's/^\[//; s/\]$//; s/"//g; s/[[:space:]]//g')
  fi
  if [ "${_so_rc}" -ne 0 ]; then
    printf 'ticket-split: 开票失败: %s（票本体字段派生失败：%s）\n' "${_so_id}" "${_so_cx}" >&2
    return 1
  fi
  _so_out=''
  _so_rc=0
  if [ -n "${_so_blocked}" ]; then
    _so_out=$(RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
      sh "${ticket_ops_cmd}" "${repo_root}" open --id "${_so_id}" --complexity "${_so_cx}" \
        --title "${_so_title}" --ledger-line "${_so_ledger}" --blocked-by "${_so_blocked}" 2>&1) || _so_rc=$?
  else
    _so_out=$(RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
      sh "${ticket_ops_cmd}" "${repo_root}" open --id "${_so_id}" --complexity "${_so_cx}" \
        --title "${_so_title}" --ledger-line "${_so_ledger}" 2>&1) || _so_rc=$?
  fi
  if [ "${_so_rc}" -ne 0 ]; then
    printf 'ticket-split: 开票失败: %s（ticket-ops open exit %s）\n' "${_so_id}" "${_so_rc}" >&2
    [ -z "${_so_out}" ] || printf '%s\n' "${_so_out}" >&2
    return 1
  fi
  [ -z "${_so_out}" ] || printf '%s\n' "${_so_out}"
  return 0
}

# 记录层写锁：本件自取一次并跨「全部 open → 记录提交」持有；子调用经继承标记接管同一把
record_lock_ensure "${repo_root}"

_n=0
_fail_ids=''
while IFS="${TAB}" read -r _id _ledger; do
  _n=$((_n + 1))
  printf 'ticket-split: 开票（%d/%d）: %s\n' "${_n}" "${n_rows}" "${_id}"
  if split_open_one "${_id}" "${_ledger}"; then
    :
  else
    _fail_ids="${_fail_ids}${_id} "
  fi
done < "${tmp_rows}"

if [ -n "${_fail_ids}" ]; then
  printf 'ticket-split: FAIL: 批量开票失败（失败票: %s）——零提交；已成功开票的写入保留，修好后重跑同一命令即按幂等路径收敛\n' "${_fail_ids}" >&2
  exit 1
fi

# ---- 记录面路径组装（票本体逐张＋index＋changes＋tickets README＋progress）----
record_paths=''
while IFS="${TAB}" read -r _id _ledger; do
  record_paths="${record_paths}$(record_path "ticket:${_id}")${NL}"
done < "${tmp_rows}"
record_paths="${record_paths}$(record_path index)${NL}$(record_path changes)${NL}$(record_path tickets-readme)${NL}${progress_current_rel}${NL}"

# ---- 变化判定：全部记录路径与 HEAD 无实质差异即幂等重放，不创建空提交 ----
# progress 投影头部 generated_at 注释行是派生时间戳（非内容事实）：幂等重放会刷新它，
# 不能据此判变更（否则每次重跑都产出只含时间戳的空提交）。仅该行差异时按「无实质变更」
# 处理，并把投影恢复为 HEAD 版本（派生载体独占写，回退零信息丢失）。
split_real_change() {
  # $1=记录路径；返回 0＝实质变更，1＝无变更，2＝仅投影时间戳行差异
  _src_p=$1
  _src_full="${repo_root}/${_src_p}"
  if ! git -C "${repo_root}" cat-file -e "HEAD:${_src_p}" 2>/dev/null; then
    return 0
  fi
  if git -C "${repo_root}" diff --quiet HEAD -- "${_src_p}" 2>/dev/null; then
    return 1
  fi
  if [ "${_src_p}" = "${progress_current_rel}" ]; then
    _src_old=$(git -C "${repo_root}" show "HEAD:${_src_p}" | sed '/^<!-- generated_at: /d' | cksum)
    _src_new=$(sed '/^<!-- generated_at: /d' "${_src_full}" | cksum)
    if [ "${_src_old}" = "${_src_new}" ]; then
      return 2
    fi
  fi
  return 0
}
_changed=0
_tsonly=0
for _p in ${record_paths}; do
  [ -n "${_p}" ] || continue
  [ -e "${repo_root}/${_p}" ] || continue
  _pc=0
  split_real_change "${_p}" || _pc=$?
  case ${_pc} in
    0) _changed=1; break ;;
    2) _tsonly=1 ;;
    *) : ;;
  esac
done
if [ "${_changed}" -eq 0 ]; then
  if [ "${_tsonly}" -eq 1 ]; then
    _head_progress=${tmp_dir}/head-progress.md
    git -C "${repo_root}" show "HEAD:${progress_current_rel}" > "${_head_progress}"
    record_write "${repo_root}" "${progress_current_rel}" "${_head_progress}"
    printf 'ticket-split: 投影仅生成时间戳差异，已恢复为 HEAD 版本（非内容变更，零提交）\n'
  fi
  printf 'ticket-split: 记录面与 HEAD 一致（批量开票为幂等重放），无提交可创建——零空提交\n'
  printf 'ticket-split: PASS（批量开票 %d 张，全部已在记录面并已提交；未创建提交）\n' "${n_rows}"
  exit 0
fi

# ---- 一次性记录提交（同锁继承；提交说明按记录面规范生成）----
_today=$(date +%Y-%m-%d)
_ids_joined=$(printf '%s' "${ids_set}" | paste -sd'/' -)
_commit_msg="chore(records): ${_today} 拆票批量开票（票 ${_ids_joined}）"
_record_rc=0
_record_out=''
# shellcheck disable=SC2086  # 记录路径清单按换行分隔、刻意不加引号切分（路径无空白；set -f 已关通配）
if _record_out=$(RECORD_LOCK_INHERITED=1 RECORD_LOCK_DIR="${RECORD_LOCK_DIR}" RECORD_LOCK_TOKEN="${RECORD_LOCK_TOKEN}" \
    sh "${record_commit_cmd}" --name "${prog}" "${repo_root}" "${_commit_msg}" ${record_paths} 2>&1); then
  :
else
  _record_rc=$?
fi
[ -z "${_record_out}" ] || printf '%s\n' "${_record_out}"
if [ "${_record_rc}" -ne 0 ]; then
  printf 'ticket-split: FAIL: 记录提交未创建（record-commit.sh fail-closed，exit %s）——批量开票已全部落地，工作区保留可重试：按上方报因处理后重跑同一命令即收敛\n' "${_record_rc}" >&2
  exit 1
fi
_commit=$(printf '%s\n' "${_record_out}" | sed -n 's/^ticket-split: 记录提交 \([0-9a-f][0-9a-f]*\)$/\1/p' | tail -n 1)
[ -n "${_commit}" ] || die1 '记录提交入口未返回提交 ID（record-commit.sh 输出契约破坏）——提交可能已创建，须人工核对'
printf 'ticket-split: PASS（批量开票 %d 张＋记录提交 %s）\n' "${n_rows}" "${_commit}"
