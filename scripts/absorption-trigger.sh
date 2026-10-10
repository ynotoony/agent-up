#!/bin/sh
# Input: 账本文件（facts/project/changes.jsonl，kind=lesson 且带三分数键 score_contract/
#        score_predicate/score_rework 的九键行）。
# Output: 吸收候选提示行——同 scope 最近 3 条连续 score_contract≥80 → PROMOTE 候选
#         （固化为例句，discipline §6）；同 scope 最近 2 条连续 score_contract≤40 →
#         FORBID 候选（进 Forbidden）；数据不足输出 NOTE；空账本/无九键行零输出；
#         提示不裁决（对齐 ticket-grade 建议不裁决先例），裁决归用户，本脚本零写入。
# Pos: 吸收触发器（R-DP-041 吸收面机械承载，票 135；机制迭代三）：读账本聚合分数、
#      出候选提示，不改任何文件不自动执行；阈值 80/40 为初值（运营期可调，调整经
#      用户拍板）；POSIX sh、零外部依赖、全程只读。
# 用法: sh absorption-trigger.sh [repo-root]
# 退出码: 0 正常（含有提示）；1 用法或环境错误（账本缺失不视为错误＝零输出）。

prog=absorption-trigger

repo_root=${1:-}
if [ -z "$repo_root" ]; then
  # 缺省根推导：逐级向上找 facts/project/changes.jsonl（兼容两落位形态：
  # rules/implementation/scripts/ 三层与 scripts/ 一层；找不到＝无从对账，退出）
  _d=$(dirname "$0")
  repo_root=''
  for _i in 1 2 3 4; do
    _d=$(CDPATH='' cd "$_d/.." && pwd)
    [ -f "$_d/facts/project/changes.jsonl" ] && { repo_root=$_d; break; }
  done
  if [ -z "$repo_root" ]; then
    exit 0
  fi
fi
_ledger="$repo_root/facts/project/changes.jsonl"
if [ ! -f "$_ledger" ]; then
  exit 0
fi

# 抽九键 lesson 行：scope|score_contract，按出现序（Promote/FORBID 只看 score_contract
# 时间序列；score_predicate/score_rework 随行读出供提示行展示）
LC_ALL=C grep -E '"kind": ?"lesson"' "$_ledger" | LC_ALL=C grep -Eq 'score_contract' || exit 0

_tmp=$(mktemp "${TMPDIR:-/tmp}/absorption.XXXXXX") || exit 1
trap 'rm -f "$_tmp"' EXIT HUP INT TERM

LC_ALL=C grep -E '"kind": ?"lesson"' "$_ledger" | LC_ALL=C grep -E '"score_contract"' | LC_ALL=C awk '
  function jval(line, key,    i, rest, j) {
    i = index(line, "\"" key "\": \"")
    if (i == 0) { i = index(line, "\"" key "\": "); if (i == 0) return ""; rest = substr(line, i + length(key) + 3) }
    else { rest = substr(line, i + length(key) + 5) }
    j = index(rest, "\"")
    if (j == 0) j = length(rest) + 1
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
    gsub(/^[ \\t]+|[ \\t]+$/, "", v)
    return v
  }
  {
    sc = jval($0, "scope")
    c = jnum($0, "score_contract")
    p = jnum($0, "score_predicate")
    r = jnum($0, "score_rework")
    if (sc ~ /[ |]/) { print "UNSAFE|" sc; next }
    if (sc != "" && c != "" && c != "-1") print sc "|" c "|" p "|" r
  }
' > "$_tmp"

# 按 scope 分组（保持首次出现序），组内检查最近 3 连高 / 2 连低
_unsafe=$(LC_ALL=C grep -c '^UNSAFE|' "$_tmp" 2>/dev/null) || _unsafe=0
if [ "${_unsafe:-0}" -gt 0 ]; then
  printf 'WARN: %s 条 lesson 行 scope 含竖线或空格（聚合不安全），已排除出吸收面——scope 命名请避开这两字符\n' "$_unsafe" >&2
  LC_ALL=C grep -v '^UNSAFE|' "$_tmp" > "${_tmp}.clean" || true
  mv "${_tmp}.clean" "$_tmp"
fi
_scope_list=$(LC_ALL=C cut -d'|' -f1 "$_tmp" | LC_ALL=C awk '!seen[$0]++')
for _sc in $_scope_list; do
  _seq=$(LC_ALL=C grep -E "^${_sc}\\|" "$_tmp" | LC_ALL=C cut -d'|' -f2 | tail -3 | tr '\n' ' ')
  _full=$(LC_ALL=C grep -E "^${_sc}\\|" "$_tmp" | LC_ALL=C tail -3)
  _count=$(printf '%s\n' "$_full" | grep -c .)
  # 3 连高：最近 3 条都 ≥80
  if [ "$_count" -ge 3 ]; then
    if printf '%s\n' "$_full" | LC_ALL=C awk -F'|' '$2 < 80 {bad=1} END{exit bad?1:0}'; then
      _hi=$(printf '%s\n' "$_full" | LC_ALL=C cut -d'|' -f2 | tr '\n' ',' | sed 's/,$//')
      printf 'PROMOTE 候选: scope=%s 最近 3 连合同质量高分（%s）——候选固化为例句（discipline 委派合同三件配套纪律例句区），裁决归用户\n' "$_sc" "$_hi"
    fi
  fi
  # 2 连低：最近 2 条都 ≤40
  if [ "$_count" -ge 2 ]; then
    _low=$(printf '%s\n' "$_full" | LC_ALL=C tail -2)
    if printf '%s\n' "$_low" | LC_ALL=C awk -F'|' '$2 > 40 {bad=1} END{exit bad?1:0}'; then
      _lo=$(printf '%s\n' "$_low" | LC_ALL=C cut -d'|' -f2 | tr '\n' ',' | sed 's/,$//')
      printf 'FORBID 候选: scope=%s 最近 2 连合同质量低分（%s）——候选进 Forbidden，裁决归用户\n' "$_sc" "$_lo"
    fi
  fi
done

_total=$(wc -l < "$_tmp" | tr -d ' ')
if [ "$_total" -lt 3 ]; then
  printf 'NOTE: 带分数 lesson 行共 %s 条——吸收触发窗口（3 连高/2 连低）数据不足，继续攒分\n' "$_total"
fi

rm -f "$_tmp"
exit 0
