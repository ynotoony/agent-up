#!/bin/sh
# Input: 调用方脚本环境（set -eu）与以下 awk 变量（经 -v 传入）：lex_progin（错误抬头）、
#        lex_style（pkg＝stdout 形态「<progin>第 N 逻辑行: ...」，stderr＝stderr 形态
#        「<progin>: 数据表第 N 逻辑行: ...」）、lex_allow_bt（1＝引号内反引号作字面量放行）、
#        lex_tabmsg／lex_noargmsg／lex_dollarsuffix（各引擎差异报错文案）、lex_lead（行首
#        空白剥离正则）、q（单引号字符，规避 awk 程序内的引号转义）。
# Output: RULES_LEXER_AWK＝非执行式规则表词法器 awk 函数源（lex_bad／lex_line）：逐物理行
#         处理续行拼接、CR 剥离、注释与空行跳过、单引号词法取段（引号内零解释原样承载）、
#         引号外空白分词；引号外 shell 语法元字符与行内制表符、引号内命令替换/参数展开
#         形态一律拒；token 化结果落全局 L_cmd／L_out／L_nf／L_raw，返回值 1＝就绪、
#         0＝已跳过或已报错（调用方应 next）。指令名/参数数校验属各引擎分发表，不在本件。
# Pos: 规则表词法器唯一实现点（票 286 D1：check-package.sh／install.sh／
#      generate-module-map.sh／generate-adapter-diffs.sh 四引擎同源）——四引擎只保留指令
#      分发表与差异文案参数，词法核心零副本。本件为包侧共享模块（package-only：四引擎
#      均为包侧工具，不落仓侧镜像、不入安装闭包）；随四消费件同目录定位。

# shellcheck disable=SC2034,SC2016  # 变量由调用方 source 后引用（单文件视野误报）；awk 程序刻意单引号形态防 shell 展开
RULES_LEXER_AWK='
function lex_bad(msg) {
  if (lex_style == "stderr") printf "%s: 数据表第 %d 逻辑行: %s\n", lex_progin, ln, msg > "/dev/stderr"
  else printf "%s第 %d 逻辑行: %s\n", lex_progin, ln, msg
  n++
}
function lex_line(cur,   raw, i, L, c, nxt, out, tok, first, inq, inqseen, nf) {
  raw = cur
  ln++
  gsub(/\r/, "", raw)
  while (raw ~ /\\$/) {
    raw = substr(raw, 1, length(raw) - 1)
    if ((getline nxt) <= 0) { lex_bad("续行无后续物理行（行尾反斜杠悬空）"); return 0 }
    ln++
    gsub(/\r/, "", nxt)
    raw = raw nxt
  }
  sub(lex_lead, "", raw)
  if (raw == "" || substr(raw, 1, 1) == "#") return 0
  out = ""; tok = ""; first = 1; inq = 0; inqseen = 0; nf = 0
  L = length(raw)
  for (i = 1; i <= L; i++) {
    c = substr(raw, i, 1)
    if (c == "\t") { lex_bad(lex_tabmsg); return 0 }
    if (c == q) { inq = 1 - inq; inqseen = 1; continue }
    if (!inq && c == " ") {
      if (tok != "" || inqseen) {
        if (first) { L_cmd = tok; first = 0 } else { out = out tok "\t"; nf++ }
        inqseen = 0
      }
      tok = ""
      continue
    }
    if (!inq && index("`$(;|<>&", c) > 0) { lex_bad("引号外 shell 语法元字符（非执行式解析拒绝）: " c); return 0 }
    if (inq && c == "`" && lex_allow_bt != 1) { lex_bad("引号内命令替换形态（反引号）——非执行式解析拒绝"); return 0 }
    if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "(") { lex_bad("引号内命令替换形态（美元括号）" lex_dollarsuffix); return 0 }
    if (inq && c == "$" && i < L && substr(raw, i + 1, 1) == "{") { lex_bad("引号内参数展开形态（美元花括号）" lex_dollarsuffix); return 0 }
    tok = tok c
  }
  if (inq) { lex_bad("单引号未闭合（词法破坏）"); return 0 }
  if (tok != "" || inqseen) {
    # 末 token flush 刻意不置 first=0（基线语义）：单 token 行由此落入下方 no-arg
    # 分支，lex_noargmsg 才可达；空格分支的 flush 仍置 first=0，正常分词不受影响。
    if (first) { L_cmd = tok } else { out = out tok "\t"; nf++ }
  }
  if (first) { lex_bad(lex_noargmsg ": " substr(raw, 1, 40)); return 0 }
  L_out = out
  L_nf = nf
  L_raw = raw
  return 1
}
'
