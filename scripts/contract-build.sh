#!/bin/sh
# Input: <stage> <NN> [repo-root]——stage ∈ implementation|review|commit（派发阶段），
#        NN＝票号段（^[0-9]{2,}$，定位 facts/requirements/tickets/<NN>-<slug>.json，
#        恰一命中方渲染）；repo-root 可选（缺省按落位推导——resolve_repo_root，夹具/
#        复制落位语境显式传参）。读取面两数据件：票本体 dispatch.<stage>.<KEY> 逐字段
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
#      （install-policy.rules 登记）。无节票（存量形态）本件 fail-closed 报缺——合同
#      渲染只对带节票可用（开票门自 2026-10-26 起强制新票带节，存量不迁移）。

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
               恰一命中方渲染（零命中或同 NN 异 slug 撞号即 fail-closed）
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
  die2 "NN 不合口径（^[0-9]{2,}$）: ${nn}"

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

# 唯一 JSON 引擎与键集权威定位（安装闭包双布局：先包基线布局，缺失回退本脚本邻接）
_engine="${repo_root}/agent-up/scripts/json-validator.py"
[ -f "$_engine" ] || _engine="${_self_dir}/json-validator.py"
[ -f "$_engine" ] || \
  die2 "json-validator.py 不存在（安装闭包双布局定位均未命中: ${repo_root}/agent-up/scripts/ 与 ${_self_dir}/）"
_dc_schema_pkg="${repo_root}/agent-up/references/schemas/dispatch-contract.schema.json"
_dc_schema="$_dc_schema_pkg"
[ -f "$_dc_schema" ] || _dc_schema="${_self_dir}/../references/schemas/dispatch-contract.schema.json"
[ -f "$_dc_schema" ] || \
  die2 "dispatch-contract.schema.json 不存在（安装闭包双布局定位均未命中: ${_dc_schema_pkg} 与 ${_self_dir}/../references/schemas/）"
_dc_checker="$_self_dir/check-dispatch-contract.sh"
[ -f "$_dc_checker" ] && [ -r "$_dc_checker" ] || \
  die2 "自校验器 check-dispatch-contract.sh 不在本脚本同目录: ${_dc_checker}（安装闭包须随 contract-build 同落位）"

# 票文件定位: facts/requirements/tickets/<NN>-*.json 恰一命中（NN 唯一性由 open 门
# 保证；未开票本体亦受理——glob 撞号即 fail-closed 指名，不猜测渲染对象）
issues_dir="${repo_root}/facts/requirements/tickets"
[ -d "$issues_dir" ] || die1 "票目录不存在: ${issues_dir}"
set +f
set -- "${issues_dir}/${nn}"-*.json
if [ $# -gt 1 ]; then
  die1 "票号段 ${nn} 定位命中 $# 件（同 NN 异 slug 撞号，不猜测渲染对象）"
fi
ticket_file=$1
[ -f "$ticket_file" ] || die1 "票号段 ${nn} 无命中（<NN>-*.json 零匹配，票不存在）: ${issues_dir}/${nn}-*.json"
ticket_id=$(basename "$ticket_file" .json)
set -f

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

# 逐字段取值缓冲（先凑齐再自校验再输出——半份合同不出门）
contract=''
# shellcheck disable=SC2086  # 字段清单逐名一行，刻意按空白分词
for key in $dc_required; do
  val=$(python3 "$_engine" json get "$ticket_file" "dispatch.${stage}.${key}") || \
    die1 "票 ${ticket_id} dispatch.${stage} 缺必备字段或不可读: ${key}（存量无节票不迁移——合同渲染须票自带 dispatch 节）"
  [ -n "$(printf '%s' "$val" | tr -d ' \t\r\n')" ] || \
    die1 "票 ${ticket_id} dispatch.${stage}.${key} 须为非空白字符串（strip 后非空，同 schema 非空口径）"
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
