#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S8（复盘沉淀指针）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s8（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报
# ---- S8 复盘沉淀指针（R-DP-041 检查面配套）---------------------------------
#
# lesson 行沉淀指针核对（票 284：教训账本缺失改 WARN 显式退化，不再静默返回 0；指针抽取
# 单次 awk 预计算、循环内零命令替换；账本路径经 changes_jsonl_rel 常量承载）：
# changes.jsonl 的 kind=lesson 行，promoted_to ∈ {rules, validator, test} 且 decision/
# evidence_ref 含可 grep 文件指针（rules/ 或 scripts/ 开头路径，可带 #锚点后缀）时——
# ①指针文件存在于仓库根；②带 #锚点时锚点文本在文件中可 grep。文件缺失或锚点丢失＝
# STALE 指名行号与指针（沉淀被删或指针写错）。promoted_to ∈ {新票, none} 跳过（新票由
# 票务系统管、none 无沉淀义务）；指针不可 grep 形态＝NOTE 退化说明不计失败。零 lesson
# 行零报。账本文件缺失＝WARN 显式跳过（对齐 S3/S6/S7 缺失退化语义）。变量引用一律用
# 花括号形态（bash 3.2 set -u 多字节变量名解析事故，票 127 教训）。

check_s8() {
  _ledger="$repo_root/$changes_jsonl_rel"
  if [ ! -f "$_ledger" ]; then
    emit_warn S8 "$changes_jsonl_rel" 'S8 复盘沉淀指针断言跳过：教训账本不存在（记录层账本缺失），按退化语义显式跳过不硬猜（对齐 S3/S6/S7 缺失退化；不再静默返回 0）'
    return 0
  fi
  # 单次 awk 预计算（行号｜指针｜文件｜锚点）：lesson+promoted_to 过滤、首个可 grep 指针
  # 抽取与锚点收窄一并在扫描内完成（原逐行命令替换与整册 cat 已去除）。
  _s8_ptrs=$(LC_ALL=C awk '
    {
      line = $0
      if (line !~ /"kind": ?"lesson"/) next
      if (line !~ /"promoted_to": ?"(rules|validator|test)"/) next
      if (!match(line, /[^A-Za-z0-9._\/-](rules|scripts)\/[A-Za-z0-9._\/-]+(#[^" ]*)?/)) next
      ptr = substr(line, RSTART + 1, RLENGTH - 1)
      file = ptr
      anchor = ""
      h = index(ptr, "#")
      if (h > 0) { file = substr(ptr, 1, h - 1); anchor = substr(ptr, h + 1) }
      if (anchor != "") {
        n = index(anchor, " ")
        if (n > 1) anchor = substr(anchor, 1, n - 1)
        gsub(/[。.,，;；:：)）!！?？"]+$/, "", anchor)
      }
      printf "%d\t%s\t%s\t%s\n", NR, ptr, file, anchor
    }
  ' "$_ledger" 2>/dev/null) || _s8_ptrs=''
  _s8_hit=0
  while IFS="$TAB" read -r _s8_ln _s8_ptr _s8_file _s8_anchor; do
    [ -n "$_s8_ln" ] || continue
    _s8_hit=$((_s8_hit + 1))
    if [ ! -f "$repo_root/$_s8_file" ]; then
      emit_stale "$_ledger:$_s8_ln" "S8 复盘沉淀指针：lesson 行沉淀指针 ${_s8_ptr} 指向的文件不存在——沉淀被删或指针写错（R-DP-041 检查面），修指针或重沉淀"
      continue
    fi
    if [ -n "${_s8_anchor}" ]; then
      _s8_arc_rc=0
      LC_ALL=C grep -qF "${_s8_anchor}" "$repo_root/$_s8_file" 2>/dev/null || _s8_arc_rc=$?
      if [ "$_s8_arc_rc" -eq 1 ]; then
        emit_stale "$_ledger:$_s8_ln" "S8 复盘沉淀指针：lesson 行沉淀指针 ${_s8_ptr} 的锚点在目标文件中不存在——文件已演进或指针写错（R-DP-041 检查面），修指针或落新 lesson 行校正（append-only）"
      elif [ "$_s8_arc_rc" -ge 2 ]; then
        emit_warn S8 "$_ledger:$_s8_ln" "S8 锚点核对异常（目标文件不可读或 grep 错误）：${_s8_ptr}——人工核对"
      fi
    fi
  done <<S8_PTRS
$_s8_ptrs
S8_PTRS
  if [ "$_s8_hit" -eq 0 ]; then
    printf 'NOTE: %s — 无可 grep 沉淀指针的 lesson 行（S8 扫描面零命中，promoted_to 新票/none 或指针不可 grep 形态不在面）\n' "$changes_jsonl_rel"
  fi
  return 0
}
