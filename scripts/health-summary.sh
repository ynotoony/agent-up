#!/bin/sh
# Input: 仓库根目录（缺省自本脚本位置推导——落位 rules/implementation/scripts/ 上三级；
#        第一参数可指定）、可选包基线目录（第二参数；提供时对账区出对账状态）。
# Output: 体系健康摘要一屏——四分区固定格式：
#         === 打分 ===   lesson 九键行按 scope 的最近分数序列（打分趋势）
#         === 候选 ===   吸收触发候选（调用同目录 absorption-trigger.sh，口径单一承载）
#         === 报警 ===   check-stale-claims gate 模式 STALE 计数（含 S8）
#         === 对账 ===   upgrade-check 汇总行（提供包基线时；缺省显示 未提供包基线）
#         === 总结 ===   四区状态一行汇总；空源显示（无）不虚构数据。
# Pos: 体系仪表盘（R-DP-041 吸收面与 R-DP-028 状态陈述的人类视图，票 139；五方向③）：
#      只读零写入零裁决——所有提示归对应机制（吸收触发器/易腐断言扫描器），本件只聚合
#      呈现；POSIX sh、零外部依赖。
# 用法: sh health-summary.sh [repo-root] [pkg-dir]
# 退出码: 0 正常（无论有无报警——本件是视图不是门禁）；1 用法或环境错误。

prog=health-summary

repo_root=${1:-}
if [ -z "$repo_root" ]; then
  # 缺省根推导：逐级向上找 facts/project/changes.jsonl（兼容两落位形态）
  _d=$(dirname "$0")
  for _i in 1 2 3 4; do
    _d=$(CDPATH='' cd "$_d/.." && pwd)
    [ -f "$_d/facts/project/changes.jsonl" ] && { repo_root=$_d; break; }
  done
fi
if [ -z "$repo_root" ] || [ ! -d "$repo_root" ]; then
  printf '%s: 错误：仓库根不可判定（参数或落位形态）\n' "$prog" >&2
  exit 1
fi
pkg_dir=${2:-}

_ledger="$repo_root/facts/project/changes.jsonl"
_script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)

printf '=== 打分 ===\n'
if [ ! -f "$_ledger" ]; then
  printf '（无账本文件）\n'
else
  _scored=$(LC_ALL=C grep -c '"kind": "lesson"' "$_ledger" 2>/dev/null | tr -d ' ')
  _with_score=$(LC_ALL=C grep '"kind": "lesson"' "$_ledger" 2>/dev/null | LC_ALL=C grep -c '"score_contract"' | tr -d ' ')
  if [ "${_with_score:-0}" -eq 0 ]; then
    printf '（无打分记录——lesson 行 %s 条均未带分数键）\n' "${_scored:-0}"
  else
    LC_ALL=C grep '"kind": "lesson"' "$_ledger" | LC_ALL=C grep '"score_contract"' | LC_ALL=C awk '
      function jval(line, key,    i, rest, j) {
        i = index(line, "\"" key "\": \"")
        if (i == 0) return ""
        rest = substr(line, i + length(key) + 5)
        j = index(rest, "\"")
        return substr(rest, 1, j - 1)
      }
      function jnum(line, key,    i, rest, j) {
        i = index(line, "\"" key "\": ")
        if (i == 0) return ""
        rest = substr(line, i + length(key) + 4)
        j = index(rest, ",")
        k = index(rest, "}")
        if (j == 0 || (k != 0 && k < j)) j = k
        if (j == 0) j = length(rest) + 1
        v = substr(rest, 1, j - 1)
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        return v
      }
      {
        sc = jval($0, "scope")
        c = jnum($0, "score_contract")
        p = jnum($0, "score_predicate")
        r = jnum($0, "score_rework")
        if (sc != "") { order[sc] = order[sc] (order[sc] == "" ? "" : ",") c "|" p "|" r; seen[sc] = 1 }
      }
      END {
        for (s in seen) printf "  %s: 最近分数（合同/谓词/返工）＝ %s\n", s, order[s]
      }'
    printf '  共 %s 条打分记录（%s 条 lesson 行）\n' "${_with_score:-0}" "${_scored:-0}"
  fi
fi

printf '\n=== 候选 ===\n'
if [ -f "$_script_dir/absorption-trigger.sh" ]; then
  _at_out=$(sh "$_script_dir/absorption-trigger.sh" "$repo_root" 2>/dev/null)
  if [ -n "$_at_out" ]; then
    printf '%s\n' "$_at_out"
  else
    printf '（无吸收候选）\n'
  fi
else
  printf '（absorption-trigger.sh 不可用）\n'
fi

printf '\n=== 报警 ===\n'
if [ -f "$_script_dir/check-stale-claims.sh" ]; then
  _sc_out=$(sh "$_script_dir/check-stale-claims.sh" "$repo_root" gate 2>/dev/null || true)
  _stale=$(printf '%s\n' "$_sc_out" | LC_ALL=C grep -c '^STALE' | tr -d ' ')
  if [ "${_stale:-0}" -gt 0 ]; then
    printf '易腐断言过期 %s 处（STALE 行如下）：\n' "$_stale"
    printf '%s\n' "$_sc_out" | LC_ALL=C grep '^STALE' | sed 's/^/  /'
  else
    printf '（无 STALE 报警）\n'
  fi
else
  printf '（check-stale-claims.sh 不可用）\n'
fi

printf '\n=== 对账 ===\n'
if [ -n "$pkg_dir" ] && [ -d "$pkg_dir" ]; then
  if [ -f "$_script_dir/upgrade-check.sh" ]; then
    _uc_out=$(sh "$_script_dir/upgrade-check.sh" "$pkg_dir" "$repo_root" 2>/dev/null | LC_ALL=C grep '汇总:')
    if [ -n "${_uc_out:-}" ]; then
      printf '  %s\n' "$_uc_out"
    else
      printf '  （对账器无输出）\n'
    fi
  else
    printf '  （upgrade-check.sh 不可用）\n'
  fi
else
  printf '（未提供包基线——传第二参数启用对账区）\n'
fi

printf '\n=== 总结 ===\n'
printf '视图生成于 %s（只读聚合；提示与报警的裁决归用户）\n' "$(date '+%Y-%m-%d %H:%M')"
exit 0
