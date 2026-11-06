#!/bin/sh
# Input: 模式与数据文件：--strict <kind枚举行> <lifecycle枚举行> <artifacts.yaml>（严格
#        对账解析）或 --brief <artifacts.yaml>（--brief 素材证据宽松解析）；数据文件路径
#        必须存在。读面/编码面语义归调用方：严格侧 fail-closed 由本件承担，宽松侧
#        「缺失/不可读/非 UTF-8」降级文案保持 Python 调用方原口径。
# Output: stdout＝解析产物；stderr＝诊断。--strict：合法条目「id<TAB>path」逐行 stdout，
#        结构破坏行「ERR: 第 N 行: ...」逐行 stderr 且 exit 1（不产生部分结论）；
#        --brief：条目「id<TAB>path<TAB>kind<TAB>authority<TAB>read_when」逐行 stdout
#        （缺字段留空列）；缺 artifacts 段／零条目／任一条目缺 id 或 path 时 stdout 空、
#        stderr 单行原因 token（MISSING_SECTION／NO_ENTRIES／ENTRY_MISSING_IDPATH）
#        exit 1。用法错误或数据文件缺失 exit 2。
# Pos: artifacts.yaml 索引解析唯一实现点（票 286 D2：check-artifacts.sh 严格登记解析与
#      generate-dir-readmes.sh --brief 素材证据解析同源）——同一行文法扫描与条目边界
#      规则；两模式只差字段白名单与校验强度（严格＝全 schema＋enum＋路径归一唯一性，
#      宽松＝id/path 必填的平铺条目）。调用方只保留呈现与降级文案映射；本件随消费件
#      同目录定位（mirror＋fast-lane/ticket-ops 安装闭包，check-artifacts 侧为包侧工具）。

set -eu
set -f  # 关闭文件名展开：本件只按参数取路径

prog=artifacts-index

usage() {
  cat <<'USAGE'
用法: sh artifacts-index.sh --strict <kind枚举行> <lifecycle枚举行> <artifacts.yaml>
      sh artifacts-index.sh --brief <artifacts.yaml>
退出码: 0 解析成功；1 结构破坏（严格）或索引不可采用（宽松）；2 用法或数据文件缺失
USAGE
}

mode=''
kind_values=''
lifecycle_values=''
data=''
case ${1:-} in
  -h|--help)
    usage
    exit 0
    ;;
  --strict)
    [ $# -eq 4 ] || { usage >&2; exit 2; }
    mode=strict
    kind_values=$2
    lifecycle_values=$3
    data=$4
    ;;
  --brief)
    [ $# -eq 2 ] || { usage >&2; exit 2; }
    mode=brief
    data=$2
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
[ -f "$data" ] || { printf '%s: 错误：数据文件缺失: %s\n' "$prog" "$data" >&2; exit 2; }

LC_ALL=C awk -v mode="$mode" -v kind_values="$kind_values" -v lifecycle_values="$lifecycle_values" '
function bad(msg) {
  printf "ERR: 第 %d 行: %s\n", FNR, msg > "/dev/stderr"
  n++
}
function normalize_path(path, parts, count, i, value, result, depth, stack) {
  count = split(path, parts, "/")
  depth = 0
  for (i = 1; i <= count; i++) {
    value = parts[i]
    if (value == "" || value == ".") continue
    if (value == ".." && depth > 0 && stack[depth] != "..") {
      delete stack[depth]
      depth--
      continue
    }
    stack[++depth] = value
  }
  for (i = 1; i <= depth; i++) result = result (i == 1 ? "" : "/") stack[i]
  return result == "" ? "." : result
}
function allowed(field, value, values, count, i) {
  count = split(field == "kind" ? kind_values : lifecycle_values, values, " ")
  for (i = 1; i <= count; i++) if (values[i] == value) return 1
  return 0
}
function strict_finish() {
  if (!curpath) bad("条目缺 path 字段: " curid)
  if (!curkind) bad("条目缺 kind 字段: " curid)
  if (!curlifecycle) bad("条目缺 lifecycle 字段: " curid)
}
function brief_set(key, value) {
  if (key == "id") curid = value
  else if (key == "path") curpath = value
  else if (key == "kind") curkind = value
  else if (key == "authority") curauth = value
  else if (key == "read_when") curread = value
}
function brief_flush(   row) {
  if (!current) return
  if (curid == "" || curpath == "") briefbad = 1
  row = curid "\t" curpath "\t" curkind "\t" curauth "\t" curread
  rows[++nrow] = row
  nent++
  current = 0
  curid = ""; curpath = ""; curkind = ""; curauth = ""; curread = ""
}
{
  line = $0
  if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
  # artifacts: 段头识别口径按两侧原语义分开：严格侧承 base 严格解析的行首锚定（缩进段头
  # 归「其他缩进字段」忽略）；宽松侧承 base Python 素材解析的 line.strip() == "artifacts:"，
  # 允许前导空白（缩进段头亦开段）。
  if (line ~ /^artifacts:[[:space:]]*$/ || (mode == "brief" && line ~ /^[[:space:]]*artifacts:[[:space:]]*$/)) {
    top = 1
    if (mode == "brief") { sawsec = 1; ins = 1 }
    next
  }
  if (mode == "strict") {
    if (line ~ /^  - id: /) {
      if (curid != "") strict_finish()
      curid = substr(line, 9)
      sub(/[[:space:]]+$/, "", curid)
      if (curid == "") bad("条目 id 为空")
      else if (curid in seenid) bad("条目 id 重复: " curid "（首见行 " seenid[curid] "）")
      else seenid[curid] = FNR
      nent++
      curpath = ""
      curkind = ""
      curlifecycle = ""
      next
    }
    if (line ~ /^    path: /) {
      if (curid == "") { bad("path 字段在条目外"); next }
      if (curpath != "") { bad("条目多行 path 字段: " curid); next }
      v = substr(line, 11)
      i = index(v, "（")
      if (i > 0) v = substr(v, 1, i - 1)
      gsub(/^[[:space:]]+/, "", v)
      gsub(/[[:space:]]+$/, "", v)
      if (v == "") bad("条目 path 值为空: " curid)
      else if (v ~ /[[:space:]]/) bad("条目 path 含空白（无法安全匹配）: " curid)
      else {
        curpath = v
        normalized = normalize_path(v)
        if (normalized in seenpath) bad("规范化 path 重复: " curid " 与 " seenpath[normalized] " → " normalized)
        else seenpath[normalized] = curid
        printf "%s\t%s\n", curid, v
      }
      next
    }
    if (line ~ /^    kind: /) {
      if (curid == "") { bad("kind 字段在条目外"); next }
      if (curkind != "") { bad("条目重复 kind 字段: " curid); next }
      value = substr(line, 11)
      sub(/[[:space:]]+$/, "", value)
      if (value == "") bad("条目 kind 值为空: " curid)
      else if (!allowed("kind", value)) bad("条目 kind 未知: " curid "=" value)
      curkind = value
      next
    }
    if (line ~ /^    lifecycle: /) {
      if (curid == "") { bad("lifecycle 字段在条目外"); next }
      if (curlifecycle != "") { bad("条目重复 lifecycle 字段: " curid); next }
      value = substr(line, 16)
      sub(/[[:space:]]+$/, "", value)
      if (value == "") bad("条目 lifecycle 值为空: " curid)
      else if (!allowed("lifecycle", value)) bad("条目 lifecycle 未知: " curid "=" value)
      curlifecycle = value
      next
    }
    if (line ~ /^[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*:/) next
    bad("无法解析的行: " substr(line, 1, 40))
    next
  }
  if (!ins) next
  if (line != "" && substr(line, 1, 1) != " " && substr(line, 1, 1) != "\t" && substr(line, 1, 1) != "#") {
    brief_flush()
    ins = 0
    next
  }
  if (line ~ /^  - /) {
    brief_flush()
    current = 1
    rest = substr(line, 5)
    sub(/^[[:space:]]+/, "", rest)
    sub(/[[:space:]]+$/, "", rest)
    if (match(rest, /^[A-Za-z_]+:/)) {
      key = substr(rest, 1, RLENGTH - 1)
      value = substr(rest, RLENGTH + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      brief_set(key, value)
    } else {
      curid = ""
    }
    next
  }
  if (!current) next
  if (match(line, /^    [A-Za-z_]+:/)) {
    key = substr(line, 5, RLENGTH - 5)
    value = substr(line, RLENGTH + 1)
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    if (key == "path" || key == "kind" || key == "authority" || key == "read_when") brief_set(key, value)
  }
  next
}
END {
  if (mode == "strict") {
    if (curid != "") strict_finish()
    if (!top) bad("缺 artifacts: 顶层键")
    if (nent == 0) bad("零条目")
    if (n > 0) exit 1
    exit 0
  }
  brief_flush()
  if (!sawsec) { print "MISSING_SECTION" > "/dev/stderr"; exit 1 }
  if (nent == 0) { print "NO_ENTRIES" > "/dev/stderr"; exit 1 }
  if (briefbad) { print "ENTRY_MISSING_IDPATH" > "/dev/stderr"; exit 1 }
  for (i = 1; i <= nrow; i++) print rows[i]
  exit 0
}
' "$data"
