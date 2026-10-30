#!/bin/sh
# Input: 任务票编号前缀 <NN>、仓库根（缺省当前 Git 仓库）、审查收据文件（缺省
#        facts/requirements/tickets/<NN>-*.review-evidence.json）、审计策略文件（缺省
#        facts/requirements/audit-policy.json）与操作面 --operation（read/analyze/merge/
#        push/release）；收据格式合同＝../references/schemas/receipt.schema.json，
#        证据定位经 git ls-tree／rev-parse／hash-object／merge-base／diff 只读事实。
# Output: 逐谓词一行（PASS/FAIL/UNKNOWN＋谓词号与名＋文件:行号＋原因）、证据位置追溯行
#         （路径@提交:blob）、操作面允许/拒绝行与三值判定行（conformant/nonconformant/
#         unknown）；退出码 0＝conformant 或 unknown 下的读/分析，1＝nonconformant 或
#         unknown 下的 merge/push/发布，2＝用法或环境错误。全程只读零写入。
# Pos: 记录层证据审计引擎（Review 证据绑定 base/diff 的最小 Git 事实判断）：只回答
#      「证据是否已提交、是否绑定当前产品提交、审查者身份是否可佐证、策略是否适用」，
#      不宣称能证明不可验证的独立身份——无法核验即 unknown，不以 unknown 阻断读/分析。
#      POSIX sh＋python3（唯一 JSON 引擎）＋source common-helpers.sh；安装闭包随
#      ticket-ops 门控同落位。回归＝tests/ 的 ticket-audit 套件。

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

usage() {
  cat <<'USAGE'
用法: sh ticket-audit.sh <NN> [选项]
  <NN>                 任务票编号前缀（≥2 位数字）；定位 facts/requirements/tickets/<NN>-*.json 恰一命中
  --repo <dir>         仓库根（缺省＝git rev-parse --show-toplevel）
  --operation <op>     read | analyze | merge | push | release（缺省 analyze）
  --evidence <path>    审查收据路径（缺省＝<票文件>.review-evidence.json）
  --policy <path>      审计策略路径（缺省＝facts/requirements/audit-policy.json）
  -h / --help          打印本用法
退出码: 0＝conformant，或 unknown 下的 read/analyze；1＝nonconformant，或 unknown 下的
        merge/push/release；2＝用法或环境错误。
谓词: P01 收据可解析 / P02 证据已提交 / P03 base 可溯 / P04 审阅边界干净 /
      P05 diff 指纹绑定 / P06 审查者字段在场 / P07 审查者身份可佐证 /
      P08 审查者非实现者 / P09 审查时间有效 / P10 验收结果完备 / P11 策略适用。
USAGE
}

NN=''
REPO=''
OPERATION='analyze'
EVIDENCE=''
POLICY=''

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --repo) [ $# -ge 2 ] || { usage >&2; exit 2; }; REPO=$2; shift 2 ;;
    --operation) [ $# -ge 2 ] || { usage >&2; exit 2; }; OPERATION=$2; shift 2 ;;
    --evidence) [ $# -ge 2 ] || { usage >&2; exit 2; }; EVIDENCE=$2; shift 2 ;;
    --policy) [ $# -ge 2 ] || { usage >&2; exit 2; }; POLICY=$2; shift 2 ;;
    -*) printf 'ticket-audit: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) [ -z "$NN" ] || { printf 'ticket-audit: 多余参数: %s\n' "$1" >&2; usage >&2; exit 2; }; NN=$1; shift ;;
  esac
done
case $NN in
  ''|*[!0-9]*) printf 'ticket-audit: 任务票编号须为纯数字: %s\n' "$NN" >&2; usage >&2; exit 2 ;;
esac
[ "${#NN}" -ge 2 ] || { printf 'ticket-audit: 任务票编号至少两位: %s\n' "$NN" >&2; usage >&2; exit 2; }
case $OPERATION in
  read|analyze|merge|push|release) ;;
  *) printf 'ticket-audit: --operation 不合口径: %s\n' "$OPERATION" >&2; usage >&2; exit 2 ;;
esac

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
[ $# -ge 1 ] || die2 "票文件定位零命中: $TICKET_DIR/$NN-*.json"
[ $# -eq 1 ] || die2 "票文件定位不唯一（$# 件命中）: $TICKET_DIR/$NN-*.json"
TICKET_FILE=$1
TICKET_ID=$(basename "$TICKET_FILE" .json)

# shellcheck disable=SC2317  # 唯一 JSON 引擎包装：失败由调用方判读退出码
jget() { python3 "$JSON_ENGINE" json get "$@" 2>/dev/null; }
jlen() { python3 "$JSON_ENGINE" json len "$@" 2>/dev/null; }
# shellcheck disable=SC2317  # 唯一 JSON 引擎包装：失败由调用方判读退出码
json_readable() { python3 "$JSON_ENGINE" json get "$1" '' >/dev/null 2>&1; }

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

_is_sha() {
  [ "${#1}" -eq 40 ] || return 1
  [ -z "$(printf '%s' "$1" | LC_ALL=C tr -d '0123456789abcdef')" ]
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

# ---- P01 收据可解析 ----

if [ -z "$EVIDENCE_REL" ]; then
  p_fail P01 receipt-parseable "$EVIDENCE:1 — 证据文件不在仓库内（无法绑定 Git 事实）"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
elif [ ! -f "$EVIDENCE" ]; then
  p_fail P01 receipt-parseable "$EVIDENCE_REL:1 — 证据文件缺失"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
elif ! json_readable "$EVIDENCE"; then
  p_fail P01 receipt-parseable "$EVIDENCE_REL:1 — 证据不可解析为 JSON"
  printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
else
  R_SCHEMA=$(jget "$EVIDENCE" schema_version) || R_SCHEMA=''
  R_KIND=$(jget "$EVIDENCE" receipt_kind) || R_KIND=''
  R_TICKET=$(jget "$EVIDENCE" ticket_id) || R_TICKET=''
  if [ "$R_SCHEMA" != '1' ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" schema_version) — schema_version 非 1（实际: ${R_SCHEMA:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  elif [ "$R_KIND" != 'review' ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" receipt_kind) — receipt_kind 非 review（实际: ${R_KIND:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  elif [ "$R_TICKET" != "$TICKET_ID" ]; then
    p_fail P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" ticket_id) — ticket_id 与票文件不一致（票: ${TICKET_ID}，收据: ${R_TICKET:-缺失}）"
    printf 'ticket-audit: 提示: P01 失败，依赖证据内容的谓词未评估\n'
  else
    p_pass P01 receipt-parseable "$EVIDENCE_REL:$(field_line "$EVIDENCE" receipt_kind) — review 收据可解析且 ticket_id 匹配"
  fi
fi

if [ "$FAILS" -gt 0 ]; then
  printf 'ticket-audit: 操作面: %s 拒绝（证据不可解析，无法进入谓词判定）\n' "$OPERATION"
  printf 'ticket-audit: 判定: nonconformant（P01 失败）\n'
  exit 1
fi

# ---- 证据字段读取 ----

R_BASE=$(jget "$EVIDENCE" base_sha) || R_BASE=''
R_HEAD=$(jget "$EVIDENCE" head_sha) || R_HEAD=''
R_DIFF=$(jget "$EVIDENCE" diff_sha) || R_DIFF=''
R_REVIEWER=$(jget "$EVIDENCE" reviewer_identity) || R_REVIEWER=''
R_REVIEWED_AT=$(jget "$EVIDENCE" reviewed_at) || R_REVIEWED_AT=''
R_VERDICT=$(jget "$EVIDENCE" verdict) || R_VERDICT=''

# ---- P02 证据已提交 ----

if [ "$EVIDENCE_TRACKED" -eq 1 ] && [ -n "$EVIDENCE_BLOB" ] && [ "$WORKTREE_BLOB" = "$EVIDENCE_BLOB" ]; then
  p_pass P02 evidence-committed "$EVIDENCE_REL:1 — 证据在 HEAD 跟踪且工作树内容与 HEAD blob 一致"
elif [ "$EVIDENCE_TRACKED" -eq 1 ]; then
  p_fail P02 evidence-committed "$EVIDENCE_REL:1 — 工作树内容与 HEAD blob 不一致（提交后又改动）"
else
  p_fail P02 evidence-committed "$EVIDENCE_REL:1 — 证据未被 HEAD 跟踪（未提交不判 conformant）"
fi

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

# ---- P03 base 可溯 ----

if ! _is_sha "$R_BASE"; then
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 非 40 位小写十六进制: ${R_BASE:-缺失}"
elif ! git -C "$REPO" cat-file -e "$R_BASE^{commit}" 2>/dev/null; then
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 不可解析: $R_BASE"
elif ! _is_sha "$R_HEAD" || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_unknown P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — head_sha 不可解析，base 祖先关系无从判断"
elif git -C "$REPO" merge-base --is-ancestor "$R_BASE" "$R_HEAD" 2>/dev/null; then
  p_pass P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base 可解析且为 head 祖先"
else
  p_fail P03 base-sha-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" base_sha) — base_sha 非 head 祖先: $R_BASE"
fi

# ---- P04 审阅边界干净 ----

if ! _is_sha "$R_HEAD" || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_fail P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head_sha 不可解析: ${R_HEAD:-缺失}"
elif ! git -C "$REPO" merge-base --is-ancestor "$R_HEAD" "$TARGET" 2>/dev/null; then
  p_fail P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head_sha 非 target 祖先（证据所绑产品提交不在此历史）"
else
  _changed=$(git -C "$REPO" diff --name-only "$R_HEAD" "$TARGET" 2>/dev/null) || _changed='@@DIFF-FAILED@@'
  _extra=''
  _old_ifs=$IFS
  IFS='
'
  for _path in $_changed; do
    [ "$_path" = "$EVIDENCE_REL" ] || { _extra=$_path; break; }
  done
  IFS=$_old_ifs
  if [ -n "$_extra" ]; then
    p_fail P04 review-boundary-clean "$_extra:1 — head 之后出现证据文件以外的改动（审阅边界被污染）"
  else
    p_pass P04 review-boundary-clean "$EVIDENCE_REL:$(field_line "$EVIDENCE" head_sha) — head 之后仅证据文件提交（边界干净）"
  fi
fi

# ---- P05 diff 指纹绑定 ----

if ! _is_sha "$R_BASE" || ! _is_sha "$R_HEAD" \
  || ! git -C "$REPO" cat-file -e "$R_BASE^{commit}" 2>/dev/null \
  || ! git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  p_unknown P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — base/head 不可解析，diff 指纹无从重算"
elif ! _is_sha "$R_DIFF"; then
  p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 非 40 位小写十六进制: ${R_DIFF:-缺失}"
else
  _actual=$(git -C "$REPO" diff --no-color --no-ext-diff --no-textconv --binary "$R_BASE" "$R_HEAD" 2>/dev/null | git -C "$REPO" hash-object --stdin 2>/dev/null) || _actual=''
  if [ -n "$_actual" ] && [ "$_actual" = "$R_DIFF" ]; then
    p_pass P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 等于 base..head 重算指纹"
  else
    p_fail P05 diff-sha-bound "$EVIDENCE_REL:$(field_line "$EVIDENCE" diff_sha) — diff_sha 与 base..head 重算指纹不符（声明: ${R_DIFF}，实测: ${_actual:-重算失败}）"
  fi
fi

# ---- P06 审查者字段在场 ----

case $R_REVIEWER in
  '') p_fail P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失或为空" ;;
  *[[:space:]]*) p_fail P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 含空白字符" ;;
  *) p_pass P06 reviewer-identity-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 非空无空白" ;;
esac

# ---- P07 审查者身份可佐证 ----

if [ -z "$R_REVIEWER" ]; then
  p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失，身份无从佐证"
elif [ "$EVIDENCE_TRACKED" -ne 1 ] || [ -z "$EVIDENCE_COMMIT" ]; then
  p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 证据未提交，收据 author 身份无从读取"
else
  _ev_email=$(_commit_email "$EVIDENCE_COMMIT")
  if [ -z "$_ev_email" ]; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 证据提交无 author email，身份无从佐证"
  elif [ "$(_lc "$R_REVIEWER")" != "$(_lc "$_ev_email")" ]; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 与证据提交 author（${_ev_email}）不一致，无法佐证"
  elif [ "$POLICY_STATE" = 'known' ] && ! _id_in "$R_REVIEWER" "$POLICY_TRUSTED"; then
    p_unknown P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 身份不在策略 trusted_reviewers 名单，不宣称独立审查"
  else
    p_pass P07 reviewer-identity-corroborated "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 与证据提交 author 一致$([ "$POLICY_STATE" = 'known' ] && printf '且属可信审查者名单')"
  fi
fi

# ---- P08 审查者非实现者（自签拒绝）----

_impl_heads=''
if _is_sha "$R_HEAD" && git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
  _impl_heads=$(_commit_email "$R_HEAD")
fi
if [ -z "$R_REVIEWER" ]; then
  p_unknown P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — reviewer_identity 缺失，自签判定无从进行"
elif [ -z "$_impl_heads" ] && [ "$POLICY_STATE" != 'known' ]; then
  p_unknown P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 实现者身份不可得（head 无 author email 且无策略），自签判定无从进行"
else
  _impl_set=$_impl_heads
  if [ "$POLICY_STATE" = 'known' ] && [ -n "$POLICY_IMPL" ]; then
    _impl_set="$_impl_heads
$POLICY_IMPL"
  fi
  if _id_in "$R_REVIEWER" "$_impl_set"; then
    p_fail P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 审查者与实现者身份相同（自签不作独立审查证据）"
  else
    p_pass P08 reviewer-distinct-from-implementer "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewer_identity) — 审查者不在实现者身份集内"
  fi
fi

# ---- P09 审查时间有效 ----

case $R_REVIEWED_AT in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) _ra_ok=1 ;;
  *) _ra_ok=0 ;;
esac
if [ "$_ra_ok" -eq 0 ]; then
  p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at 非 UTC ISO 8601 秒粒度: ${R_REVIEWED_AT:-缺失}"
else
  _ra_date=$(printf '%s' "$R_REVIEWED_AT" | cut -c1-10)
  _head_date=''
  if _is_sha "$R_HEAD" && git -C "$REPO" cat-file -e "$R_HEAD^{commit}" 2>/dev/null; then
    _head_date=$(_commit_date "$R_HEAD")
  fi
  _ev_date=''
  if [ "$EVIDENCE_TRACKED" -eq 1 ] && [ -n "$EVIDENCE_COMMIT" ]; then
    _ev_date=$(_commit_date "$EVIDENCE_COMMIT")
  fi
  if [ -z "$_head_date" ]; then
    p_unknown P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — head 提交日期不可取，时间边界无从判断"
  elif [ -z "$_ev_date" ]; then
    p_unknown P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — 证据未提交，reviewed_at 上界无从判断"
  elif _date_lt "$_ra_date" "$_head_date"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at（${_ra_date}）早于 head 提交日（${_head_date}）"
  elif _date_lt "$_ev_date" "$_ra_date"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at（${_ra_date}）晚于证据提交日（${_ev_date}）"
  elif [ "$POLICY_STATE" = 'known' ] && _date_lt "$_ra_date" "$POLICY_EFFECTIVE"; then
    p_fail P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — 旧 PASS：reviewed_at（${_ra_date}）早于策略生效日（${POLICY_EFFECTIVE}）"
  else
    p_pass P09 reviewed-at-valid "$EVIDENCE_REL:$(field_line "$EVIDENCE" reviewed_at) — reviewed_at 落在 head 提交日与证据提交日之间$([ "$POLICY_STATE" = 'known' ] && printf '且不早于策略生效日')"
  fi
fi

# ---- P10 验收结果完备 ----

_p10_reason=''
case $R_VERDICT in
  PASS|PASS_WITH_NOTES|FAIL) ;;
  *) _p10_reason="verdict 非受控三值（实际: ${R_VERDICT:-缺失}；自由文本结论不作证据）" ;;
esac
if [ -z "$_p10_reason" ]; then
  _alen=$(jlen "$EVIDENCE" acceptance) || _alen=''
  case $_alen in
    ''|0|*[!0-9]*) _p10_reason='acceptance 缺失、非数组或空数组' ;;
  esac
fi
if [ -z "$_p10_reason" ]; then
  [ "$R_VERDICT" = 'FAIL' ] && _p10_reason='verdict=FAIL：审查结论未通过，不构成可放行证据'
fi
if [ -z "$_p10_reason" ]; then
  _ai=0
  while [ "$_ai" -lt "$_alen" ]; do
    _ac=$(jget "$EVIDENCE" "acceptance.$_ai.ac_id") || _ac=''
    _ar=$(jget "$EVIDENCE" "acceptance.$_ai.result") || _ar=''
    if [ -z "$_ac" ]; then
      _p10_reason="acceptance[$_ai].ac_id 缺失或为空"
      break
    fi
    case $_ar in
      pass|fail|unknown) ;;
      *) _p10_reason="acceptance[$_ai]（${_ac}）result 非受控三值（实际: ${_ar:-缺失}）"; break ;;
    esac
    if [ "$R_VERDICT" = 'PASS' ] && [ "$_ar" != 'pass' ]; then
      _p10_reason="verdict=PASS 但 acceptance[$_ai]（${_ac}）result=$_ar"
      break
    fi
    _ai=$((_ai + 1))
  done
fi
if [ -z "$_p10_reason" ]; then
  p_pass P10 acceptance-results-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" acceptance) — verdict=$R_VERDICT 且 $_alen 条验收结果齐备"
else
  p_fail P10 acceptance-results-present "$EVIDENCE_REL:$(field_line "$EVIDENCE" acceptance) — $_p10_reason"
fi

# ---- P11 策略适用 ----

if [ "$POLICY_STATE" = 'known' ]; then
  p_pass P11 policy-applicable "$POLICY_REL:$(field_line "$POLICY" effective_from) — 策略合法且适用于 target（生效日 ${POLICY_EFFECTIVE}）"
else
  p_unknown P11 policy-applicable "$POLICY_REL:$(field_line "$POLICY" schema_version) — $POLICY_REASON"
fi

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
