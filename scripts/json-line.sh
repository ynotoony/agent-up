#!/bin/sh
# Input: 调用方脚本环境（set -eu）与 stdin 的 JSON 行流（每行一条扁平 JSON 对象）；可选
#        函数参数＝调用方 awk 主程序正文（可引用 jval/jnum，stdin 透传）。
# Output: JSON_LINE_AWK＝内联 JSON 行取值器 awk 函数源：jval（字符串值：兼容「"k": "v"」
#         与「"k": v」两形态，缺键返回空串）、jnum（数值/裸值：止于逗号或右花括号，剥
#         两侧空白，缺键返回空串）；json_line_parse <主程序>＝以本函数源＋主程序拼装
#         awk 并从 stdin 读行执行。
# Pos: 内联 JSON 行解析唯一实现点（票 286 D3：absorption-trigger.sh 与 health-summary.sh
#      同源；generate-progress 头注已明确同款实现 retired）——两件只保留各自聚合主程序，
#      取值原语零副本。本件随两消费件同目录定位（mirror＋ticket-ops 安装闭包）。

JSON_LINE_AWK='
function jval(line, key,    i, rest, j) {
  i = index(line, "\"" key "\": \"")
  if (i == 0) { i = index(line, "\"" key "\": "); if (i == 0) return ""; rest = substr(line, i + length(key) + 3) }
  else { rest = substr(line, i + length(key) + 5) }
  j = index(rest, "\"")
  if (j == 0) j = length(rest) + 1
  return substr(rest, 1, j - 1)
}
function jnum(line, key,    i, rest, j, k, v) {
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
'

json_line_parse() {
  # $1=调用方 awk 主程序正文（stdin＝JSON 行流；主程序可自由使用 jval/jnum）
  LC_ALL=C awk "$JSON_LINE_AWK
$1"
}
