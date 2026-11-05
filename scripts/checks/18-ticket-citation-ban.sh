#!/bin/sh
# Input: check_18 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_cite_exempt
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 18（ticket-citation-ban）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 18：包内票号索引禁令（citation-rot 定稿配套）。扫描面＝包内 *.md/*.tmpl/*.json/
# *.rules（*.sh 代码面不扫——断言名/注释语境为不腐烂载体，扫禁归后续裁决）；模式＝
# 「票 ?[0-9]{2,}」字面正则，命中即 FAIL 指名文件:行号。行级豁免经清单
# ticket-citation-ban 节 pm_cite_exempt 登记（路径+行号精确匹配，理由必填），登记行
# 无命中即失效豁免 FAIL（防漂移静默失效，检查 12 同款口径）；豁免表当前空表交付。

check_18() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
n_citeex=$(wc -l < "$pm_citeex" | tr -d ' ')
problems=''
awk_rc=0
cand18=$(cd "$pkg_root" && grep -rEn '票 ?[0-9]{2,}' --include='*.md' --include='*.tmpl' --include='*.json' --include='*.rules' . 2>/dev/null | sed 's/^\.\///') || awk_rc=$?
if [ "$awk_rc" -ne 0 ] && [ "$awk_rc" -ne 1 ]; then
  printf 'check-package: 错误：检查 18 扫描器异常（grep exit %s）\n' "$awk_rc" >&2
  exit 2
fi
if [ -n "$cand18" ]; then
  OLDIFS=$IFS
  IFS='
'
  for h in $cand18; do
    IFS=$OLDIFS
    h_path=${h%%:*}
    h_ln=${h#*:}
    h_ln=${h_ln%%:*}
    if LC_ALL=C awk -F'\t' -v p="$h_path" -v l="$h_ln" '$1 == p && $2 == l { f = 1 } END { exit f ? 0 : 1 }' "$pm_citeex"; then
      continue
    fi
    add_problem "  - $h 命中票号索引禁令（票 ?[0-9][0-9]+；溯源改 commit message／票本，禁令依据＝包内零本仓票号索引）"
  done
  IFS=$OLDIFS
fi
# 失效豁免核对：登记行无命中即 FAIL（检查 12 同款，防漂移静默失效）。
if [ "$n_citeex" -gt 0 ]; then
  while IFS="$(printf '\t')" read -r ex_path ex_ln _; do
    [ -n "$ex_path" ] || continue
    if ! printf '%s\n' "$cand18" | LC_ALL=C grep -qE "^${ex_path}:${ex_ln}:" 2>/dev/null; then
      add_problem "  - 失效豁免（登记行无票号命中，须复核更新或删除登记）: ${ex_path}:${ex_ln}"
    fi
  done < "$pm_citeex"
fi
if [ -n "$problems" ]; then
  _chk_desc="包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 ${n_citeex} 行）"
else
  _chk_desc="包内票号索引禁令（扫描面 md/tmpl/json/rules；豁免 ${n_citeex} 行）"
fi
:
}
