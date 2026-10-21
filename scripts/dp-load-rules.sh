#!/bin/sh
# delivery.rules 共享解析库（dp_load_rules 唯一实现）
# Input: dp_load_rules <repo-root> <错误前缀>；读取 <repo-root>/delivery.rules
#        （四节锚点＋dp_ 指令行式配置；文法与版本权威说明见 references/delivery-rules.md，
#        分发模板 references/templates/delivery-rules.tmpl）。
# Output: 解析结论全局 DP_*（全集，消费件按需取用，未消费字段非冗余禁删）：
#           DP_PARSER_VERSION（解析器版本，唯一版本来源）、DP_PRESENT（0/1 文件在场）、
#           DP_HAS_PAYLOAD、DP_ROOT、DP_REMOTE、DP_TARGET、DP_LOCAL_REF（payload 节）、
#           DP_FORBID（boundary 节清单，换行分隔尾带换行）、DP_EXEMPT、DP_STALE_LIT
#           （calibration 节）、DP_HAS_MAINONLY、DP_MAINONLY（main-only 节清单）、
#           DP_MAINONLY_DECLARED（main-only 锚点在场＝1，含空清单）。
#         返回 0 正常（含文件缺失＝全默认未声明）；2 解析破坏（错误行已打印 stderr，
#         全局变量不承载部分结论）。四消费件（check-artifacts.sh／check-stale-claims.sh／
#         export-payload.sh／worktree-add.sh）同目录 source 本件后调用，加载处对缺件与
#         版本漂移 fail-closed exit 2 指名。
# Pos: 解析 fail-closed 六规则（未知指令／恰数违／枚举违／跨行重复／路径形态违／锚点
#      重复或条目违属，任一命中返回 2 不产生部分结论）；引擎零项目约定硬编码
#      （前缀/远端/分支/排除清单全部读配置）；本件为唯一实现——消费件不得再内嵌副本，
#      版本演进只改本件（dpv 与 DP_PARSER_VERSION 同步）；锚点表 an[1..4] 与分发模板
#      delivery-rules.tmpl 锚点行逐字一致，写错即解析失败；POSIX sh＋awk，零外部依赖；
#      source 语境设计：本件零副作用（仅定义一变量一函数），不改调用方 shell 选项。

# 解析器版本（唯一版本来源；消费件头部 # dp-parser: N 为各自最低要求版注记）
# shellcheck disable=SC2034  # 单一版本来源：消费件 source 后断言最低版，本件内不自用
DP_PARSER_VERSION=2

dp_load_rules() {
  DP_PRESENT=0
  DP_HAS_PAYLOAD=0
  DP_HAS_MAINONLY=0
  DP_MAINONLY=''
  DP_ROOT=''; DP_REMOTE=''; DP_TARGET=''; DP_LOCAL_REF=''
  DP_FORBID=''; DP_EXEMPT=''; DP_STALE_LIT=''
  _dp_prefix=$2
  _dp_file="$1/delivery.rules"
  [ -f "$_dp_file" ] || return 0
  # shellcheck disable=SC2034  # DP 引擎统一解析产出字段（全集同构契约；调用方未消费≠冗余，禁删）
  DP_PRESENT=1
  _dp_stream=$(mktemp "${TMPDIR:-/tmp}/dprules.XXXXXX") || return 2
  _dp_rc=0
  _dp_err=$(LC_ALL=C awk -v out="$_dp_stream" '
    function bad(msg) { printf "第 %d 行: %s\n", FNR, msg; n++ }
    function bad2(msg) { print msg; n++ }
    BEGIN {
      an[1] = "# ==== payload：导出形态（export-payload.sh 读）===="
      an[2] = "# ==== boundary：禁入名单（pre-push 安检读）===="
      an[3] = "# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）===="
      an[4] = "# ==== main-only：worktree 排除清单（worktree-add.sh 读）===="
      sc[1] = "payload"; sc[2] = "boundary"; sc[3] = "calibration"
      sc[4] = "main-only"
      dpv = 2
    }
    function is_known(d) {
      return (d == "dp_payload_root" || d == "dp_payload_remote" || d == "dp_payload_target" \
        || d == "dp_payload_local_ref" || d == "dp_forbid" || d == "dp_artifact_exempt" \
        || d == "dp_stale_lit" || d == "dp_mainonly")
    }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      hit = 0
      for (k = 1; k <= 4; k++) {
        if (line == an[k]) {
          hit = 1
          if (seen[k]++) bad("锚点重复: " an[k])
          else cur = sc[k]
          break
        }
      }
      if (hit) next
      if (line ~ /^#/) {
        if (line ~ /^# ==== .+：.+====$/) bad2("锚点 " line " 本版解析器（dp-parser: " dpv "）不识别——落地拷贝可能早于包当前版本，请与包内 scripts/dp-load-rules.sh 同步")
        next
      }
      if (line ~ /^[[:space:]]/) { bad("行首空白（指令行须顶格）"); next }
      if (index(line, "\t") > 0) { bad("字段内禁制表符"); next }
      sp = index(line, " ")
      if (sp == 0) { bad("未知指令行: " substr(line, 1, 40)); next }
      d = substr(line, 1, sp - 1)
      v = substr(line, sp + 1)
      if (!is_known(d)) { bad("未知指令行: " d "（锚点/指令表见 dp-load-rules.sh dp_load_rules BEGIN 段与 references/delivery-rules.md；若落地 dp-load-rules.sh 版本早于包内现版，请与包内同件同步）"); next }
      if (v == "" || v ~ /[[:space:]]/) { bad("值须为恰一非空字段（禁空白与多余空格）: " d); next }
      if (d ~ /^dp_payload_/ && cur != "payload") { bad("条目违属：dp_payload_* 仅得出现于 payload 锚点后: " d); next }
      if (d == "dp_forbid" && cur != "boundary") { bad("条目违属：dp_forbid 仅得出现于 boundary 锚点后"); next }
      if ((d == "dp_artifact_exempt" || d == "dp_stale_lit") && cur != "calibration") { bad("条目违属：" d " 仅得出现于 calibration 锚点后"); next }
      if (d == "dp_mainonly" && cur != "main-only") { bad("条目违属：dp_mainonly 仅得出现于 main-only 锚点后"); next }
      if (d == "dp_mainonly") {
        if (v ~ /^\//) { bad("路径禁前导斜杠: " v); next }
        if (v ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " v); next }
        if (v ~ /\/$/) { bad("路径禁尾斜杠: " v); next }
      }
      if ((d == "dp_payload_root" || d == "dp_forbid" || d == "dp_artifact_exempt")) {
        if (v ~ /^\//) { bad("路径禁前导斜杠: " v); next }
        if (v ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " v); next }
      }
      if (d == "dp_stale_lit" && v != "S1" && v != "S2") { bad("枚举违（dp_stale_lit ∈ {S1,S2}）: " v); next }
      if (v in seenval) bad("值跨行重复: " v)
      else seenval[v] = 1
      if (d ~ /^dp_payload_/) cnt[d]++
      if (d == "dp_mainonly") cntmo++
      printf "%s\t%s\n", d, v >> out
    }
    END {
      for (k = 1; k <= 3; k++) if (seen[k] && sc[k] == "payload") haspay = 1
      if (haspay) {
        np = split("dp_payload_root dp_payload_remote dp_payload_target dp_payload_local_ref", pd, " ")
        for (k = 1; k <= np; k++) if (cnt[pd[k]] != 1) bad2("恰数违：payload 节存在时 " pd[k] " 须恰一行（实测 " cnt[pd[k]] + 0 "）")
      }
      if (seen[4]) printf "dp_mainonly_declared\ty\n" >> out
      if (n > 0) exit 1
    }
  ' "$_dp_file") || _dp_rc=$?
  if [ "$_dp_rc" -ne 0 ] || [ -n "$_dp_err" ]; then
    rm -f "$_dp_stream"
    printf '%s: 错误：delivery.rules 解析破坏（fail-closed，不产生部分结论）: %s\n' "$_dp_prefix" "$_dp_file" >&2
    if [ -n "$_dp_err" ]; then
      printf '%s\n' "$_dp_err" >&2
    fi
    return 2
  fi
  while IFS="$(printf '\t')" read -r _dp_d _dp_v; do
    [ -n "${_dp_d:-}" ] || continue
    case $_dp_d in
      dp_payload_root) DP_ROOT=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_remote) DP_REMOTE=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_target) DP_TARGET=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_local_ref) DP_LOCAL_REF=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_forbid) DP_FORBID="$DP_FORBID$_dp_v
" ;;
      dp_artifact_exempt) DP_EXEMPT="$DP_EXEMPT$_dp_v
" ;;
      dp_stale_lit) DP_STALE_LIT="$DP_STALE_LIT$_dp_v
" ;;
      dp_mainonly) DP_MAINONLY="$DP_MAINONLY$_dp_v
" ; DP_HAS_MAINONLY=1 ;;
      dp_mainonly_declared) DP_MAINONLY_DECLARED=1 ;;
    esac
  done < "$_dp_stream"
  rm -f "$_dp_stream"
  return 0
}
