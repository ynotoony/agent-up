#!/bin/sh
# Input: check_22 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 22（ruleblock-nine-fields）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 22：规则块九字段格式（票 195 新增）。依 references/protocol/governance-format.md
# §2.1 既有定义机械执行（本检查是该定义的执行面，非第二权威，字段集与 Level 枚举为检查
# 语义常量，先例检查 19 的 kind 枚举）。扫描面＝包内全部 *.md 与 *.tmpl 的
# `#### R-<短码>-<三位序号>` 规则块（标题行形态同检查 12 扫描窗口，含裸 ID 标题——
# 标题无尾随文字同样落进 Level 核对）：
#   ①标题行须以受控 Level 四值收尾（MUST/MUST NOT/SHOULD/MAY，反引号可选），缺失或
#     自造级即 FAIL 指名 ID 与标题原文；
#   ②块体（标题行起至下一标题行止，与检查 12 窗口同口径）七字段 When/Action/Forbidden/
#     Stop if/Evidence/Owner/Authority 须以「- **字段**：」形态各至少一行，缺字段即
#     FAIL 指名 ID 与缺失字段名（全量扫描不排除「解释与例外」节——规则块无处可藏）；
#   ③块 ID 全局唯一（governance-format.md update_policy 定稿：ID 不得复用），跨行或
#     跨文件重复即 FAIL 指名 ID 与各处文件:行号。

check_22() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
rb_fields=$(mktemp "${t_dir%/}/ruleblock.XXXXXX")
rb_dup=$(mktemp "${t_dir%/}/ruleblock.XXXXXX")
awk_rc=0
# shellcheck disable=SC2086  # $file_list 刻意分词——find 逐文件作 awk 多文件参数（包路径无空白，清单校验禁空白路径）
LC_ALL=C awk -v pr="$pkg_root" '
  BEGIN { nf = split("When×Action×Forbidden×Stop if×Evidence×Owner×Authority", FLD, "×") }
  function report(   k, miss) {
    miss = ""
    for (k = 1; k <= nf; k++) if (!(FLD[k] in have)) miss = miss FLD[k] " "
    if (miss != "") printf "MISSING\t%s\t%s\t%d\t%s\n", id, f, ln, miss
    printf "BLOCK\t%s\t%s\t%d\n", id, f, ln
    inblk = 0
  }
  /^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]([ \t]|$)/ {
    if (inblk) report()
    id = $2
    f = FILENAME
    if (index(f, pr) == 1) f = substr(f, length(pr) + 2)
    ln = FNR
    t = $0
    gsub(/`/, "", t)
    if (t !~ /(MUST NOT|MUST|SHOULD|MAY)[ \t]*$/) printf "BADLEVEL\t%s\t%s\t%d\t%s\n", id, f, ln, t
    delete have
    inblk = 1
    next
  }
  inblk && /^#/ { report(); next }
  inblk && /^- \*\*/ {
    line = $0
    sub(/^- \*\*/, "", line)
    sub(/\*\*：.*/, "", line)
    have[line] = 1
    next
  }
  END { if (inblk) report() }
' $file_list > "$rb_fields" || awk_rc=$?
if [ "$awk_rc" -ne 0 ]; then
  printf 'check-package: 错误：检查 22 扫描器异常（awk exit %s）\n' "$awk_rc" >&2
  rm -f "$rb_fields" "$rb_dup"
  exit 2
fi
n_blocks=$(LC_ALL=C awk -F'\t' '$1 == "BLOCK" { n++ } END { print n + 0 }' "$rb_fields")
grep '^BADLEVEL' "$rb_fields" | LC_ALL=C cut -f2- > "$rb_dup"
while IFS="$(printf '\t')" read -r _rb_id _rb_f _rb_ln _rb_t; do
  [ -n "$_rb_id" ] || continue
  add_problem "  - ${_rb_id} 标题行 Level 缺失或非法（须 MUST/MUST NOT/SHOULD/MAY，标题：${_rb_t}）"
done < "$rb_dup"
grep '^MISSING' "$rb_fields" | LC_ALL=C cut -f2- > "$rb_dup"
while IFS="$(printf '\t')" read -r _rb_id _rb_f _rb_ln _rb_miss; do
  [ -n "$_rb_id" ] || continue
  add_problem "  - ${_rb_id} 块体缺字段（${_rb_f}:${_rb_ln} 起）: $(printf '%s' "$_rb_miss" | sed 's/ $//')"
done < "$rb_dup"
grep '^BLOCK' "$rb_fields" | LC_ALL=C cut -f2- > "$rb_dup"
LC_ALL=C awk -F'\t' '{ c[$1] = c[$1] " " $2 ":" $3; n[$1]++ } END { for (i in n) if (n[i] > 1) printf "DUP\t%s\t%s\n", i, substr(c[i], 2) }' "$rb_dup" \
  | LC_ALL=C sort > "$rb_fields"
while IFS="$(printf '\t')" read -r _dup_tag _rb_id _rb_locs; do
  [ -n "$_dup_tag" ] || continue
  add_problem "  - 规则块 ID 重复（全局唯一，不得复用）: ${_rb_id}（${_rb_locs}）"
done < "$rb_fields"
rm -f "$rb_fields" "$rb_dup"
if [ -n "$problems" ]; then
  _chk_desc="规则块九字段格式（块 ${n_blocks} 个，字段 7 项，级 4 值）"
else
  _chk_desc="规则块九字段格式（块 ${n_blocks} 个，字段 7 项，级 4 值）"
fi
:
}
