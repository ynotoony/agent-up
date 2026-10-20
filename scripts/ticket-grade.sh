#!/bin/sh
# Input: 一个或多个任务票 JSON 路径（facts/requirements/tickets/*.json 形态，票 70 先例）；判据权威＝
#        agent-up/references/protocol/complexity-profile.md §2.1（C0-C3 可数触发条件）
#        与 §2.3（微任务道承重判据可数面）；车道德协议权威＝rules/assessment.md
#        §6 分级交付道（R-DP-031，流程权威拆三件）。票的 profile 七维字段不在可算面，本脚本不读取。
# Output: 每票一节的定级建议表（stdout）——各 C 级命中条件清单、C0-C3 建议、微道资格
#         预审、逐条验收形态标注、与票面 actual 定级（complexity 字段＝Triage 实际定级）
#         的逐票对照；批量末尾输出分歧账汇总。建议不裁决：输出只写「建议/命中/预审」，
#         不写「必须/定级为」；车道结论一律「待 Triage 裁决」。
# Pos: 本仓定级建议器（票 78，判断面最小化第一批，用户 2026-09-22 拍板三选一）；
#      python3 标准库内嵌（先例 rules/implementation/scripts/run-record.sh seal/stats）；fail-closed——票文件
#      缺失、非 JSON、缺 id/complexity/acceptance/scope 字段即报明退出，零副作用（全程
#      只读，不写任何文件）。建议与 Triage 定级冲突时以 Triage 为准，分歧如实记录供
#      采纳票引用。

# 用法、判据口径（词表显式登记）与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：参数只按字面传递

# ---- 路径常量区（票 111 波②建；票 115 波⑤值翻新布局）----
scripts_readme='rules/implementation/scripts/README.md'  # 口径登记面（同目录 README ticket-grade 专节）

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/ticket-grade.sh <ticket.json> [<ticket.json> ...]
参数:
  ticket.json  任务票 JSON 路径（至少一个；多个则逐票出节，末尾附分歧账汇总）。
  -h / --help  打印本用法。
输出:
  每票一节：实际定级｜验收（原始/承重/样板）｜触及顶层目录｜行为/契约件模块｜白名单
  文件（新建/删除）｜高风险面关键词命中｜公共接口证据｜命中条件｜C0-C3 建议｜微道
  预审｜逐条验收标注｜与实际定级对照。批量末尾：分歧账汇总（一致/分歧计数与名单）。
退出码: 0 全部处理完成（分歧不影响退出码——建议不裁决）；1 fail-closed（票文件缺失、
        非 JSON、缺 id/complexity/acceptance/scope 字段，报明缺项）；2 用法错误。
USAGE
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac

[ $# -ge 1 ] || { usage >&2; exit 2; }
die() { printf 'ticket-grade: %s\n' "$1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || \
  die "未找到 python3（判据计算依赖，口径见 $scripts_readme 专节）——无法计算"

# 票 160：使用独立 Python 模块 json-validator.py（grade 模式）
script_dir="$(cd "$(dirname "$0")" && pwd)"
validator_script="${script_dir}/json-validator.py"
[ -f "${validator_script}" ] || die "json-validator.py 不存在: ${validator_script}"

# profile.md 路径（虽然当前实现未使用，但保持接口一致性）
profile_md="${script_dir}/../references/protocol/complexity-profile.md"

exec python3 "${validator_script}" grade "${profile_md}" "$@"
