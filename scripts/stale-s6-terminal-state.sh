#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S6（终态哨兵）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s6（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S6 终态哨兵（票 94，R3/R8 合并）-----------------------------------------
#
# 终态哨兵：facts/requirements/tickets/index.json（票状态真相源）内 id 曾达终态（done/superseded）
# 而当前 status 回到非终态 → STALE 指名票 id 与跃迁方向（复盘缺口④：W5 重放把 done
# 票打回 in_progress 时对账照绿——S3 只查投影↔索引一致性，不查状态语义合法性）。
# 基线锚＝该索引的 Git 现行提交历史：`git log -p` 逐提交提取 + 行的 id/status，曾见
# 终态即入哨兵集（选型见登记表 S6 注记）。终态/非终态受控词表：
#   终态   done | superseded
#   非终态 ready | in_progress | blocked | review_ready | review_pass | review_fail
# （与 ticket-ops.sh flip --status 的状态机八值一致；超集之外的 status 值属排版/词表
# 破坏，归 S3 --check exit 2 语义，本哨兵不另断言。）
# 退化语义：非 Git 工作区 → WARN 跳过；索引尚无基线提交且当前行无可提取条目（无可比
# 历史）→ WARN 跳过，不硬猜。已知限制：`git log -p` 对 merge commit 默认不出 patch
# ——仅经合并冲突引入索引的终态史不入哨兵集（现行流程翻转均经普通提交）。

check_s6() {
  _idx="$repo_root/$issues_index_rel"
  if [ ! -f "$_idx" ]; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引文件不存在（票状态真相源缺失），对齐 S3 缺失退化语义'
    return 0
  fi
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：目标当前不是 Git 工作区，终态基线不可判定，按流程退化语义跳过（对齐 S1/S5）'
    return 0
  fi
  # 基线提取（票 284 解析收敛）：历史 + 行先聚合为 JSON 数组，后经唯一 JSON 引擎
  # json rows 一次解析（键序无关、紧凑与带空格同受理；不逐行起子进程、不内嵌 jval）。
  _s6_hist_raw=$(git -C "$repo_root" log -p --format= -- "$issues_index_rel" 2>/dev/null \
    | LC_ALL=C grep '^+.*{"id"' | sed 's/^+//; s/,[[:space:]]*$//') || _s6_hist_raw=''
  _s6_hist=''
  if [ -n "$_s6_hist_raw" ]; then
    _s6_hist=$( { printf '['; printf '%s\n' "$_s6_hist_raw" | paste -sd, -; printf ']'; } \
      | python3 "$_engine" json rows - '' id status 2>/dev/null ) || _s6_hist=''
  fi
  _s6_now=$(python3 "$_engine" json rows "$_idx" issues id status 2>/dev/null) || {
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引条目行不可经唯一 JSON 引擎解析（排版破坏归 S3 --check 口径），本次不硬猜'
    return 0
  }
  if [ -z "$_s6_hist" ] && [ -z "$_s6_now" ]; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引尚无基线提交且当前行无可提取条目（无可比历史），不硬猜'
    return 0
  fi
  # 曾见终态集：历史段任一时刻 status 为终态的 id（终态票现行终态属合法稳态，不报；
  # 只有「曾终态→现非终态」才报）。分类一次 awk 完成（历史段入集→分隔标记→当前行判定），
  # 循环内零命令替换，action 行回 shell 交 emit_stale（计数与报文口径不变）。
  _s6_actions=$( { printf '%s\n' "$_s6_hist"; printf '@@S6_SPLIT@@\n'; printf '%s\n' "$_s6_now"; } \
    | LC_ALL=C awk -F'\t' -v loc="$issues_index_rel" '
      BEGIN { phase = 1 }
      $0 == "@@S6_SPLIT@@" { phase = 2; next }
      phase == 1 { if ($2 == "done" || $2 == "superseded") term[$1] = 1; next }
      {
        st = $2
        if (st == "ready" || st == "in_progress" || st == "blocked" || st == "review_ready" || st == "review_pass" || st == "review_fail") {
          if ($1 in term) printf "STALE\t%s:%s\tS6 终态哨兵：票 %s 曾达终态，当前 status 被改回非终态 %s——done/superseded 为终态，幽灵态即报；合法复开须以新票承载（改 id）或显式 superseded 登记\n", loc, $1, $1, st
        }
      }
    ')
  if [ -n "$_s6_actions" ]; then
    while IFS="$TAB" read -r _s6_tag _s6_loc _s6_msg; do
      [ -n "$_s6_tag" ] || continue
      case $_s6_tag in
        STALE) emit_stale "$_s6_loc" "$_s6_msg" ;;
      esac
    done <<S6_ACTIONS
$_s6_actions
S6_ACTIONS
  fi
  return 0
}
