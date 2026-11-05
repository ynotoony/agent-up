#!/bin/sh
# Input: <stage> <NN> [repo-root]——stage ∈ implementation|review|commit（派发阶段），
#        NN＝票号段（^[0-9]{2,}$，定位 facts/requirements/tickets/<NN>-<slug>.json，
#        按票本体 id 口径筛选后恰一命中方渲染；派生件如 <id>.review-evidence.json 带
#        点号、不参与计数，同 NN 多件真实本体仍 fail-closed 指名）；repo-root 可选
#        （缺省按落位推导——resolve_repo_root，夹具/复制落位语境显式传参）。读取面两数据件：票本体 dispatch.<stage>.<KEY> 逐字段
#        实值（唯一 JSON 引擎 json get 承载）＋references/schemas/
#        dispatch-contract.schema.json contract_fields.<stage> 必备字段清单（渲染序）。
# Output: stdout 渲染派发合同——逐字段 {{KEY}} 占位符行＋实值行块（形态与
#         references/prompts/ 三模板的 {{KEY}} 占位符一致、与合同实例一致）；全程纯
#         函数（stdout 唯一交付面，零仓内落盘零状态；自校验暂存件落 $TMPDIR 用毕即
#         清，非持久产物）。
# Pos: 派发合同渲染器（脚本单一职责链新建；编排入口消费本件产物）：字段清单唯一来源
#      ＝dispatch-contract.schema.json contract_fields（与 check-dispatch-contract.sh
#      同源同法纯 awk 提取）；值唯一来源＝票 JSON dispatch 节（存储合同单源＝
#      ticket-record.schema.json dispatch 属性）。输出前自调同目录
#      check-dispatch-contract.sh --check 自校验——校验不过 exit 1 零 stdout 输出
#      （fail-closed：半份合同不出门）。POSIX sh＋python3（唯一 JSON 引擎）；source
#      common-helpers.sh（die1/die2/resolve_repo_root）。安装闭包：
#      check-dispatch-contract.sh＋dispatch-contract.schema.json＋references/prompts/
#      三模板（校验器 require_inputs 面）随 ticket-ops 门控同落位
#      （install-policy.rules 登记）。无节票本件 fail-closed 报缺——票 243 起开票不再
#      要求 dispatch 节（不预填未来证据），本节由派发方在派发时点填齐后本件才可渲染。

set -eu
set -f  # 关闭文件名展开：票文件定位用受控一次性 set +f 段

# Source common helper functions（同 ticket-ops 口径：缺失 fail-closed exit 2）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'contract-build: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'

usage() {
  cat <<'USAGE'
用法: sh contract-build.sh <stage> <NN> [repo-root]
参数:
  stage        派发阶段: implementation | review | commit
  NN           票号段（^[0-9]{2,}$）——定位 facts/requirements/tickets/<NN>-<slug>.json，
               按票本体 id 口径筛选后恰一命中方渲染（派生件 <id>.review-evidence.json
               等带点号不计；零命中或同 NN 多件真实本体即 fail-closed 指名）
  repo-root    仓库根目录；缺省按脚本落位推导（agent-up/scripts/ 上两级／
               rules/implementation/scripts/ 上三级），夹具语境显式传参
行为: 读票 JSON dispatch 节（dispatch.<stage>.<KEY>）逐字段渲染派发合同到 stdout；
      字段清单＝references/schemas/dispatch-contract.schema.json contract_fields.<stage>；
      输出前自调同目录 check-dispatch-contract.sh --check 自校验，不过即 exit 1 零输出。
      纯函数: 零仓内落盘（自校验暂存件落 $TMPDIR 用毕即清）。
退出码: 0 渲染成功；1 fail-closed（缺节/缺键/空白值/票定位失败/自校验未过——零 stdout）；
        2 用法或环境错误（参数或 stage 非法、共享库/引擎/键集权威/校验器缺失）。
-h / --help  打印本用法
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac
[ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
stage=$1
nn=$2
repo_root=${3:-}

case $stage in
  implementation|review|commit) ;;
  *) die2 "stage 须为 implementation|review|commit 之一: ${stage}" ;;
esac
printf '%s' "$nn" | LC_ALL=C grep -Eq '^[0-9]{2,}$' || \
  die2 "NN 不合口径（^[0-9]{2,}\$）: ${nn}"

# 仓库根推导统一经 resolve_repo_root（显式参数 > 落位分派两布局，同 ticket-ops）
if [ -n "$repo_root" ]; then
  _rr=$(resolve_repo_root "$repo_root") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "$_rr" ] || die2 "仓库根不可用: ${repo_root:-（未传参且脚本落位非两布局，无法缺省推导）}"
repo_root=$_rr
[ -d "$repo_root" ] || die2 "仓库根不存在: ${repo_root}"

_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
_closure_root=$(CDPATH='' cd -- "${_self_dir}/.." && pwd -P) || _closure_root="${_self_dir}/.."
_closure_hint="运行时依赖只认安装闭包（脚本同目录与 ../references/），不回退包工作树副本；缺失即安装不到位——请按 Agent Up 包 references/upgrade.md 升级或运行 scripts/install.sh 修补安装后重跑"

# 唯一 JSON 引擎与键集权威定位（票 269：只认安装闭包——脚本同目录引擎与邻接
# references/ 数据件，缺失 fail-closed）
_engine="${_self_dir}/json-validator.py"
[ -f "$_engine" ] || \
  die2 "json-validator.py 不存在（安装闭包缺失）: ${_engine}——${_closure_hint}"
_dc_schema="${_closure_root}/references/schemas/dispatch-contract.schema.json"
[ -f "$_dc_schema" ] || \
  die2 "dispatch-contract.schema.json 不存在（安装闭包缺失）: ${_dc_schema}——${_closure_hint}"
_dc_checker="$_self_dir/check-dispatch-contract.sh"
[ -f "$_dc_checker" ] && [ -r "$_dc_checker" ] || \
  die2 "自校验器 check-dispatch-contract.sh 不在本脚本同目录: ${_dc_checker}（安装闭包须随 contract-build 同落位）"

# 票文件定位: facts/requirements/tickets/<NN>-<slug>.json 按票本体 id 口径恰一命中。
# 票本体文件名不含点号（slug 仅 [a-z0-9-]，与 ticket-record.schema.json 的 id 口径
# 同源）；派生件（独立审查收据 <id>.review-evidence.json、工作流 sidecar 等）带点号，
# 不参与计数——否则有收据的票在 <NN>-*.json 中必命中两件而被误判撞号。同 NN 多件
# 真实本体仍 fail-closed 并逐件指名（NN 唯一性由 open 门保证，不猜测渲染对象）。
issues_dir="${repo_root}/facts/requirements/tickets"
[ -d "$issues_dir" ] || die1 "票目录不存在: ${issues_dir}"
set +f
_hit_count=0
_hit_list=''
ticket_file=''
for _cand in "${issues_dir}/${nn}"-*.json; do
  [ -f "$_cand" ] || continue
  _cand_id=$(basename "$_cand" .json)
  printf '%s' "$_cand_id" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || continue
  _hit_count=$((_hit_count + 1))
  [ -n "$ticket_file" ] || ticket_file=$_cand
  _hit_list="${_hit_list}${NL}  ${_cand}"
done
set -f
if [ "$_hit_count" -eq 0 ]; then
  die1 "票号段 ${nn} 无命中（<NN>-<slug>.json 零匹配，派生件不计票本体）: ${issues_dir}/${nn}-*.json"
elif [ "$_hit_count" -gt 1 ]; then
  die1 "票号段 ${nn} 定位命中 ${_hit_count} 件票本体（同 NN 异 slug 撞号，不猜测渲染对象）:${_hit_list}"
fi
ticket_id=$(basename "$ticket_file" .json)

# 字段清单提取（与 check-dispatch-contract.sh --check 同源同法；纯 awk，字段逐名一行）
dc_required=$(LC_ALL=C awk -v sect="\"${stage}\":" '
  index($0, sect) > 0 && /\[/ { in_block=1; next }
  in_block && /\]/ { in_block=0; next }
  in_block && /"[A-Z_]+"/ {
    line=$0
    gsub(/[",]/, "", line)
    gsub(/^[[:space:]]+/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    if (line ~ /^[A-Z_]+$/) print line
  }
' "$_dc_schema")
[ -n "$dc_required" ] || \
  die1 "dispatch-contract.schema.json 无 ${stage} 阶段必备字段定义（键集权威文件损坏或漂移）"

# 阶段键集恰等门（评审整改）：本阶段对象不得携带 contract_fields 之外的键、也不得缺键
# ——越键/缺键即 exit 1 零 stdout，报文逐键指名（此前开票 dispatch 门删除后由本门承接）。
python3 "$_engine" json len "$ticket_file" "dispatch.${stage}" >/dev/null 2>&1 || \
  die1 "票 ${ticket_id} 缺 dispatch.${stage} 阶段对象（派发阶段须在票面 dispatch 节填齐本阶段合同数据）"
_dc_diff=$(DC_REQUIRED="${dc_required}" python3 - "$ticket_file" "dispatch.${stage}" <<'PY'
import json
import os
import sys

path, expr = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as fh:
    node = json.load(fh)
for part in expr.split('.'):
    node = node[part]
keys = set(node)
req = set(os.environ['DC_REQUIRED'].split())
missing = sorted(req - keys)
extra = sorted(keys - req)
if not missing and not extra:
    sys.exit(0)
parts = []
if missing:
    parts.append('缺键: ' + ', '.join(missing))
if extra:
    parts.append('越键: ' + ', '.join(extra))
print('；'.join(parts))
sys.exit(3)
PY
) || die1 "票 ${ticket_id} dispatch.${stage} 键集与 contract_fields 不恰等（${_dc_diff:-键集不可读}；键集权威＝dispatch-contract.schema.json contract_fields.${stage}）"

# 逐字段取值缓冲（先凑齐再自校验再输出——半份合同不出门）
contract=''
# shellcheck disable=SC2086  # 字段清单逐名一行，刻意按空白分词
for key in $dc_required; do
  val=$(python3 "$_engine" json get "$ticket_file" "dispatch.${stage}.${key}") || \
    die1 "票 ${ticket_id} dispatch.${stage} 缺必备字段或不可读: ${key}（派发阶段须在票面 dispatch 节填齐本阶段合同数据——票 243 起开票不再预填，本节在派发时点落位）"
  if [ -z "$(printf '%s' "$val" | tr -d ' \t\r\n')" ]; then
    # 票 243：收口时点事实（净工时／实施摘要／审查通过指针）开票与派发时均不预填，
    # 留空即在合同上标注「收口时按实际写入」，不阻断派发；其余键空白即派发门 fail-closed。
    case $key in
      ACTUAL_TIME|IMPLEMENTATION_SUMMARY|REVIEW_PASS_CHECKPOINT)
        val='（收口时按实际写入）'
        ;;
      *)
        die1 "票 ${ticket_id} dispatch.${stage}.${key} 须为非空白字符串（派发时点完整性门；ACTUAL_TIME/IMPLEMENTATION_SUMMARY/REVIEW_PASS_CHECKPOINT 属收口事实键，可留空）"
        ;;
    esac
  fi
  if [ -z "$contract" ]; then
    contract="{{${key}}}${NL}${val}"
  else
    contract="${contract}${NL}${NL}{{${key}}}${NL}${val}"
  fi
done

# 输出前自校验（校验器只收文件路径：暂存件落 $TMPDIR 用毕即清；不过即零 stdout）
_cb_tmp=$(mktemp "${TMPDIR:-/tmp}/cbuild.XXXXXX")
_cb_out=$(mktemp "${TMPDIR:-/tmp}/cbuild.XXXXXX")
cleanup() {
  rm -f "${_cb_tmp}" "${_cb_out}"
}
trap cleanup EXIT HUP INT TERM
printf '%s\n' "$contract" > "$_cb_tmp"
if ! sh "$_dc_checker" --check "$_cb_tmp" > "$_cb_out" 2>&1; then
  cat "$_cb_out" >&2
  die1 "渲染产物自校验未过（check-dispatch-contract --check exit 非 0）——零输出（fail-closed）"
fi
rm -f "$_cb_tmp" "$_cb_out"
_cb_tmp=''; _cb_out=''
printf '%s\n' "$contract"
