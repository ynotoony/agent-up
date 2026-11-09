#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S7（替代标记存在性）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s7（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S7 替代标记存在性（R-DP-039 替代标记面配套）---------------------------
#
# superseded_by 存在性断言（票 284 解析收敛：索引条目经唯一 JSON 引擎 json rows 解析——
# 键序无关、紧凑与带空格同受理；原三份 awk jval 副本随解析收敛合一为引擎调用，环检测
# 与收口顺序一次 awk 分类、循环内零命令替换）：
#   ① 指向的票 id 必须真实存在于本索引（缺失即 STALE 指名双方 id）；
#   ② 指向票自身带 superseded_by（替代链环/自指）即 STALE（A 替代 B、B 又被替代的环语义
#      无法裁决现行依据，登记时拆环只指最终替代票）；
#   ③ 指向票状态非终态（替代票尚未收口）仅 WARN 不拦截（先标后收为合法顺序）。
# 字段缺失＝零命中零报（可选字段语义，存量票零回扫，R-DP-039 明文不按时间自动打标）。

check_s7() {
  _idx="$repo_root/$issues_index_rel"
  if [ ! -f "$_idx" ]; then
    emit_warn S7 "$issues_index_rel" 'S7 替代标记断言跳过：索引文件不存在（票状态真相源缺失），对齐 S3/S6 缺失退化语义'
    return 0
  fi
  _s7_rows=$(python3 "$_engine" json rows "$_idx" issues id status superseded_by 2>/dev/null) || {
    emit_warn S7 "$issues_index_rel" 'S7 替代标记断言跳过：索引条目行不可经唯一 JSON 引擎解析（排版破坏归 S3 --check 口径），本次不硬猜'
    return 0
  }
  [ -n "$_s7_rows" ] || return 0
  # 存在性＋链环＋收口顺序一次 awk 分类（action 行回 shell 交 emit_*：STALE 计数与 WARN
  # 条目登记日期口径不变；循环内零命令替换）。
  _s7_actions=$(printf '%s\n' "$_s7_rows" | LC_ALL=C awk -F'\t' -v loc="$issues_index_rel" '
    $1 != "" {
      if (!($1 in seen_id)) { seen_id[$1] = 1; st[$1] = $2 }
      if ($3 != "") { marked[$1] = $3; mlist[++m] = $1 }
    }
    END {
      for (i = 1; i <= m; i++) {
        src = mlist[i]; dst = marked[src]
        if (!(dst in seen_id)) {
          printf "STALE\t%s:%s\tS7 替代标记断言：票 %s 的 superseded_by 指向 %s，但该票不在索引中——替代标记指向的票必须真实存在（R-DP-039），修标或先开替代票\n", loc, src, src, dst
          continue
        }
        if (dst in marked && !reported[dst]) {
          printf "STALE\t%s:%s\tS7 替代标记断言：票 %s 自身亦带 superseded_by 替代标记——替代链出现二度替代（环语义无法裁决现行依据），登记时拆环只指最终替代票（R-DP-039）\n", loc, dst, dst
          reported[dst] = 1
          continue
        }
        if (st[dst] == "done" || st[dst] == "superseded") continue
        if (st[dst] == "") {
          printf "WARN\t%s:%s\tS7 收口顺序提醒：票 %s 的 superseded_by 指向 %s，指向票状态不可读（词表外或排版漂移），人工核对\n", loc, src, src, dst
        } else {
          printf "WARN\t%s:%s\tS7 收口顺序提醒：票 %s 的 superseded_by 指向 %s，替代票尚未收口（状态 %s）——先标后收为合法顺序，收口后本提醒自然消除\n", loc, src, src, dst, st[dst]
        }
      }
    }
  ')
  if [ -n "$_s7_actions" ]; then
    while IFS="$TAB" read -r _s7_tag _s7_loc _s7_msg; do
      [ -n "$_s7_tag" ] || continue
      case $_s7_tag in
        STALE) emit_stale "$_s7_loc" "$_s7_msg" ;;
        WARN) emit_warn S7 "$_s7_loc" "$_s7_msg" ;;
      esac
    done <<S7_ACTIONS
$_s7_actions
S7_ACTIONS
  fi
  return 0
}
