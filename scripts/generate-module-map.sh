#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层，check-gates.sh :20 先例）＋语言规则表
#        module-map.rules（与脚本同目录；语言提取知识唯一承载点，票 44 表驱动化）。
# Output: <root>/docs/architecture/module-map.json——Derived 四标注头部（generated_from/
#         generated_at/coverage/invalidation，R-DP-004）＋workspace_fingerprint（fp-v1，
#         R-DP-015 算法；指纹输入排除本图自身，避免自引用漂移）＋nodes（已扫描源码文件，
#         仓库根相对路径）＋edges（from=仓库根相对路径，to=导入语句文本中的模块引用原串，
#         label=导入语句类别）；stdout 输出一行成功摘要；stderr 报告失败原因。
# Pos: 模块地图生成器（票 30 调研拍板方案 A：静态导入行提取；票 42 落位；票 43 扩展；
#      票 44 引擎表驱动化——引擎为通用"加载规则表→按扩展名发现源码→逐行匹配捕获→按策略
#      产边→存在性过滤→组装 JSON"管线，不含任何语言专名；语言覆盖＝规则表登记行，加语言＝
#      加规则行＋fixture、零引擎改动）。本图是项目地图条件产物的承载视图（development-process
#      §5.2 触发矩阵行），只当检索索引不当 Scope 权威，不作为白名单或 watch 依据；Derived
#      自动生成，agent 不手写。POSIX sh、无 jq 与解释器类外部依赖；两项平台标配补充：stat
#      （BSD/GNU 双方言自动探测）与系统 SHA-256 工具（sha256sum/shasum/cksum/openssl 按序
#      探测），缺失即 fail-closed。语言覆盖与未覆盖项如实声明（R-CC-004）：见规则表各行
#      coverage/limits 字段与同目录 README.md 专节。

# 用法、语言规则表说明与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

usage() {
  cat <<'USAGE'
用法: sh generate-module-map.sh [repo-root]
参数:
  repo-root   仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  -h / --help 打印本用法。
输出: <root>/docs/architecture/module-map.json（Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌）。
语言: 提取规则外置于脚本同目录的 module-map.rules（每语言一行，加语言＝加规则行、零引擎改动）；
      规则表缺失或不合预期即退出码 2（fail-closed）。
退出码: 0 生成成功；1 生成条件不满足（无已登记源码、路径含控制字符、写入失败等；
        fail-closed，不写地图）；2 用法或环境错误（非 Git 仓库、仓库根不存在、
        SHA-256/stat 工具缺失、语言规则表缺失或不合预期）。
USAGE
}

die1() {
  printf 'generate-module-map: FAIL: %s\n' "$1" >&2
  exit 1
}

die2() {
  printf 'generate-module-map: %s\n' "$1" >&2
  exit 2
}

case $# in
  0)
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
    ;;
  1)
    case $1 in
      -h|--help) usage; exit 0 ;;
    esac
    repo_root=$1
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: $repo_root"

out_rel='docs/architecture/module-map.json'
out_dir="$repo_root/docs/architecture"
out_file="$repo_root/$out_rel"

# ---- 临时文件与清理（全部落 TMPDIR，仓库内只写地图本件）----

t_dir=${TMPDIR:-/tmp}
tmp_out=''
tmp_edges=''
tmp_nodes=''
tmp_fp=''
tmp_modf=''
tmp_rules=''
probe_file=''
cleanup() {
  rm -f "$tmp_out" "$tmp_edges" "$tmp_nodes" "$tmp_fp" "$tmp_modf" "$tmp_rules" "$probe_file"
}
trap cleanup EXIT HUP INT TERM
tmp_out=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_edges=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_nodes=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_fp=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_rules=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")

# ---- 工具探测：SHA-256 与 stat 方言（缺失即 fail-closed，exit 2）----

sha_cmd=''
if command -v sha256sum >/dev/null 2>&1; then
  sha_cmd='sha256sum'
elif command -v shasum >/dev/null 2>&1; then
  sha_cmd='shasum -a 256'
elif command -v cksum >/dev/null 2>&1 && cksum -a sha256 </dev/null >/dev/null 2>&1; then
  sha_cmd='cksum -a sha256'
elif command -v openssl >/dev/null 2>&1; then
  sha_cmd='openssl dgst -sha256'
fi
[ -n "$sha_cmd" ] || die2 '未找到可用 SHA-256 工具（sha256sum/shasum/cksum -a sha256/openssl 任一）——无法计算 fp-v1 指纹'

probe_file=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
printf 'probe' > "$probe_file"
p_bsd=$(stat -f '%z %m' "$probe_file" 2>/dev/null | grep -E '^[0-9]+ [0-9]+$') || p_bsd=''
p_gnu=$(stat -c '%s %Y' "$probe_file" 2>/dev/null | grep -E '^[0-9]+ [0-9]+$') || p_gnu=''
rm -f "$probe_file"
probe_file=''
if [ -n "$p_bsd" ]; then
  stat_flag='-f'
  stat_fmt='%z %m'
elif [ -n "$p_gnu" ]; then
  stat_flag='-c'
  stat_fmt='%s %Y'
else
  die2 'stat 工具不可用或输出不合预期（BSD/GNU 双方言探测均失败）——无法取文件字节与 mtime'
fi

# ---- 语言规则表加载（票 44 表驱动化：语言知识唯一承载点，引擎零语言专名）----
# 行格式：mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>，逐行 TAB 连接落
# tmp_rules；编码语义见规则表头部注释与同目录 README.md 专节。

mm_rule() {
  if [ "$#" -ne 6 ]; then
    die2 '规则表行参数数量不合预期（mm_rule 须恰 6 个参数）'
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$tmp_rules"
}

mm_script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
mm_rules_path="$mm_script_dir/module-map.rules"
[ -f "$mm_rules_path" ] || die2 "语言规则表缺失: $mm_rules_path"
. "$mm_rules_path"
[ -s "$tmp_rules" ] || die2 "语言规则表未登记任何语言行: $mm_rules_path"

# 结构校验（fail-closed）：字段数、op 编码、规则形态、selector/strategy 枚举、label 字符集、
# 扩展名形态与跨行重复；任何不合预期即 exit 2，不带病运行（避免边集静默漂移）。
mm_bad=$(LC_ALL=C awk -F'\t' '
  function bad(msg) { printf "行 %d: %s\n", NR, msg; badn++ }
  function chk_ops(s,   n, i, v, k, body, eq, rep) {
    if (s == "") return
    n = split(s, v, "&&")
    for (i = 1; i <= n; i++) {
      if (v[i] == "") { bad("op 列表含空项"); continue }
      k = substr(v[i], 1, 1)
      if (k == "Q") {
        if (length(v[i]) != 1) bad("Q op 带多余参数: " v[i])
        continue
      }
      if (length(v[i]) < 3 || substr(v[i], 2, 1) != "=") { bad("op 编码不合预期（须 s=ERE 或 g=ERE=替换 或 Q）: " v[i]); continue }
      body = substr(v[i], 3)
      if (k == "s") continue
      if (k == "g") {
        eq = index(body, "=")
        rep = substr(body, eq + 1)
        if (eq < 2) bad("g op 缺替换段: " v[i])
        else if (index(rep, "&") > 0 || index(rep, "\\") > 0) bad("g op 替换串含 & 或反斜杠: " v[i])
        continue
      }
      bad("未知 op 类型: " k)
    }
  }
  function chk_rule(r,   d, f, sel) {
    d = split(r, f, "~")
    if (f[1] == "capture") {
      if (d != 10) { bad("capture 规则字段数 " d "（预期 10）"); return }
      if (f[4] == "") bad("capture 缺 match")
      if (f[9] == "") bad("capture 缺 label")
      else if (f[9] !~ /^[A-Za-z0-9_-]+$/) bad("label 含非常规字符: " f[9])
      if (f[10] != "unresolved-node" && f[10] != "module-path" && f[10] != "direct-file") bad("capture 未知 strategy: " f[10])
    } else if (f[1] == "scan") {
      if (d != 8) { bad("scan 规则字段数 " d "（预期 8）"); return }
      if (f[2] == "") bad("scan 缺 gate")
      chk_ops(f[3])
      sel = f[4]
      if (sel == "emit") {
        if (f[5] == "") bad("scan/emit 缺 paramA")
      } else if (sel == "pair" || sel == "list" || sel == "declfile") {
        if (f[5] == "") bad("scan/" sel " 缺 paramA")
        if (f[6] == "") bad("scan/" sel " 缺 paramB")
      } else {
        bad("scan 未知 selector: " sel)
      }
      if (f[7] == "") bad("scan 缺 label")
      else if (f[7] !~ /^[A-Za-z0-9_-]+$/) bad("label 含非常规字符: " f[7])
      if (f[8] != "unresolved-node" && f[8] != "module-path" && f[8] != "direct-file") bad("scan 未知 strategy: " f[8])
    } else {
      bad("未知规则类型: " f[1])
    }
  }
  {
    if ($0 == "") { bad("空规则行"); next }
    if (NF != 6) { bad("字段数 " NF "（预期 6）"); next }
    if ($1 == "" || $2 == "") { bad("lang 或 exts 为空"); next }
    nen = split($2, ev, " ")
    for (i = 1; i <= nen; i++) {
      if (ev[i] !~ /^\*[^*]*$/) { bad("扩展名须为单个前导 * 加字面后缀: " ev[i]); continue }
      if (ev[i] ~ /[@~&=\/[:space:]]/) { bad("扩展名含保留分隔符或斜杠: " ev[i]); continue }
      if (ev[i] in seenext) bad("扩展名跨行重复登记: " ev[i])
      else seenext[ev[i]] = 1
    }
    chk_ops($3)
    if ($4 == "") { bad("无提取规则"); next }
    m = split($4, rr, "@")
    for (k = 1; k <= m; k++) chk_rule(rr[k])
  }
  END {
    if (NR < 1) { printf "规则表为空\n"; badn++ }
    if (badn > 0) exit 1
  }
' "$tmp_rules") || true
if [ -n "$mm_bad" ]; then
  printf 'generate-module-map: FAIL: 语言规则表不合预期: %s\n' "$mm_rules_path" >&2
  printf '%s\n' "$mm_bad" >&2
  exit 2
fi

MM_ROWS=$(cat "$tmp_rules")
export MM_ROWS

# ---- 源码文件发现（扩展名自规则表；prune 排除 .git、依赖与构建产物目录、docs/agent/runs）----

mm_exts_all=$(LC_ALL=C awk -F'\t' '{ printf "%s ", $2 }' "$tmp_rules")
set --
mm_first=1
for mm_e in $mm_exts_all; do
  if [ "$mm_first" -eq 1 ]; then
    set -- "$@" '(' -name "$mm_e"
    mm_first=0
  else
    set -- "$@" -o -name "$mm_e"
  fi
done
set -- "$@" ')' -print

src_list=$(cd "$repo_root" && LC_ALL=C find . \
  \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
     -o -name __pycache__ -o -name .venv -o -path './docs/agent/runs' \) -prune -o \
  -type f "$@" \
  | sed 's|^\./||' | LC_ALL=C sort)

[ -n "$src_list" ] || die1 '未发现规则表登记扩展名的源码文件——无可生成的模块地图（fail-closed，不写输出）'

if printf '%s\n' "$src_list" | grep -Eq '[[:cntrl:]]'; then
  die1 '源码文件清单含制表符或其他控制字符（无法安全承载于提取层）——fail-closed'
fi

# ---- 静态导入行提取（通用规则解释器：逐文件 awk，语句文本层，不做语义过滤——票 30 调研结论①）----
# 语言绑定与提取规则全部来自 ENVIRON["MM_ROWS"]（每行 = TAB 连接的六字段规则行）；文件→
# 语言按扩展名字面后缀匹配（规则行序即优先序）；strategy=direct-file 规则产出的候选边在
# 提取后统一经文件存在性过滤（见下节，fail-closed）。

NL='
'
OLDIFS=$IFS
IFS=$NL
for rel in ${src_list}; do
  [ -f "$repo_root/$rel" ] || die1 "源码文件不可读（疑似路径含换行被拆分）: ${rel}"
  LC_ALL=C awk -v src="$rel" '
    function emit(to, label) {
      if (to == "") return
      if (to ~ /[[:cntrl:]]/) return
      printf "%s\t%s\t%s\n", src, to, label
    }
    function apply_ops(s, ops,   n, i, v, k, body, eq, rep) {
      n = split(ops, v, "&&")
      for (i = 1; i <= n; i++) {
        k = substr(v[i], 1, 1)
        if (k == "Q") { gsub(q, "\"", s); continue }
        body = substr(v[i], 3)
        if (k == "s") { sub(body, "", s); continue }
        if (k == "g") {
          eq = index(body, "=")
          rep = substr(body, eq + 1)
          gsub(substr(body, 1, eq - 1), rep, s)
          continue
        }
      }
      return s
    }
    BEGIN {
      q = sprintf("%c", 39)
      ws = "[[:space:]]+"
      nrow = split(ENVIRON["MM_ROWS"], rowv, "\n")
      mapn = 0
      for (ri = 1; ri <= nrow; ri++) {
        if (rowv[ri] == "") continue
        if (split(rowv[ri], rf, "\t") < 6) exit 2
        L = rf[1]
        nen = split(rf[2], ev, " ")
        extn[L] = nen
        for (i = 1; i <= nen; i++) extv[L, i] = ev[i]
        pre[L] = rf[3]
        rulen[L] = split(rf[4], rv, "@")
        for (k = 1; k <= rulen[L]; k++) {
          df = split(rv[k], fv, "~")
          if (fv[1] == "capture") {
            if (df < 10) exit 2
            rkind[L, k] = "capture"
            rgroup[L, k] = fv[2]; rgate[L, k] = fv[3]; rmatch[L, k] = fv[4]
            rstage[L, k] = fv[5]; rpre[L, k] = fv[6]; rsuf[L, k] = fv[7]
            rvalid[L, k] = fv[8]; rlabel[L, k] = fv[9]
          } else if (fv[1] == "scan") {
            if (df < 8) exit 2
            rkind[L, k] = "scan"
            rgate[L, k] = fv[2]; rops[L, k] = fv[3]; rsel[L, k] = fv[4]
            rpa[L, k] = fv[5]; rpb[L, k] = fv[6]; rlabel[L, k] = fv[7]
          } else exit 2
        }
        for (i = 1; i <= nen; i++) {
          mapn++
          mapsfx[mapn] = substr(ev[i], 2)
          maplang[mapn] = L
        }
      }
      if (mapn < 1) exit 2
    }
    FNR == 1 {
      lang = ""
      for (mi = 1; mi <= mapn; mi++) {
        ln = length(mapsfx[mi])
        if (length(src) >= ln && substr(src, length(src) - ln + 1, ln) == mapsfx[mi]) {
          lang = maplang[mi]
          break
        }
      }
      if (lang == "") infile = 0
      else infile = 1
    }
    infile != 1 { next }
    {
      line = $0
      if (pre[lang] != "") line = apply_ops(line, pre[lang])
      gflag = ""
      for (k = 1; k <= rulen[lang]; k++) {
        if (rkind[lang, k] == "capture") {
          g = rgroup[lang, k]
          if (g != "" && index(":" gflag ":", ":" g ":") > 0) continue
          if (rgate[lang, k] != "" && line !~ rgate[lang, k]) continue
          if (!match(line, rmatch[lang, k])) continue
          seg = substr(line, RSTART, RLENGTH)
          if (g != "") gflag = gflag ":" g
          if (rstage[lang, k] != "") {
            if (!match(seg, rstage[lang, k])) continue
            seg = substr(seg, RSTART, RLENGTH)
          }
          if (rpre[lang, k] != "") sub(rpre[lang, k], "", seg)
          if (rsuf[lang, k] != "") sub(rsuf[lang, k], "", seg)
          if (rvalid[lang, k] != "" && seg !~ rvalid[lang, k]) continue
          emit(seg, rlabel[lang, k])
        } else {
          if (line !~ rgate[lang, k]) continue
          rest = line
          if (rops[lang, k] != "") rest = apply_ops(rest, rops[lang, k])
          sel = rsel[lang, k]
          if (sel == "emit") {
            if (rest ~ rpa[lang, k]) emit(rest, rlabel[lang, k])
          } else if (sel == "pair") {
            n = split(rest, tokv, ws)
            if (n >= 2 && tokv[2] == rpa[lang, k] && tokv[1] ~ rpb[lang, k]) {
              emit(tokv[1], rlabel[lang, k])
            }
          } else if (sel == "list") {
            m = split(rest, itemv, rpa[lang, k])
            for (i = 1; i <= m; i++) {
              kk = split(itemv[i], t2, ws)
              tok = ""
              for (j = 1; j <= kk; j++) {
                if (t2[j] != "") { tok = t2[j]; break }
              }
              if (tok != "" && tok ~ rpb[lang, k]) emit(tok, rlabel[lang, k])
            }
          } else if (sel == "declfile") {
            name = rest
            if (name !~ rpb[lang, k]) continue
            dir = src
            if (dir ~ /\//) { sub(/\/[^\/]*$/, "", dir) } else { dir = "" }
            stem = src
            sub(/^.*\//, "", stem)
            esuf = ""
            for (i = 1; i <= extn[lang]; i++) {
              sfx = extv[lang, i]
              sub(/^\*/, "", sfx)
              ln = length(sfx)
              if (ln > 0 && length(stem) >= ln && substr(stem, length(stem) - ln + 1, ln) == sfx) {
                esuf = sfx
                break
              }
            }
            if (esuf != "") stem = substr(stem, 1, length(stem) - length(esuf))
            isres = 0
            res1 = ""
            m = split(rpa[lang, k], resv, ",")
            for (i = 1; i <= m; i++) {
              rs = resv[i]
              if (esuf != "" && length(rs) > length(esuf) && substr(rs, length(rs) - length(esuf) + 1, length(esuf)) == esuf) {
                rs = substr(rs, 1, length(rs) - length(esuf))
              }
              if (i == 1) res1 = rs
              if (stem == rs) isres = 1
            }
            if (isres) cdir = dir
            else if (dir == "") cdir = stem
            else cdir = dir "/" stem
            if (cdir == "") {
              emit(name esuf, rlabel[lang, k])
              emit(name "/" res1 esuf, rlabel[lang, k])
            } else {
              emit(cdir "/" name esuf, rlabel[lang, k])
              emit(cdir "/" name "/" res1 esuf, rlabel[lang, k])
            }
          }
        }
      }
    }
  ' "$repo_root/$rel" >> "$tmp_edges"
done
IFS=$OLDIFS
unset MM_ROWS

# ---- direct-file 策略候选边过滤：仅保留真实存在的文件边（无候选零边，fail-closed）----
# 过滤标签集自规则表归纳（strategy=direct-file 的规则 label），引擎不含语言专名。

tab=$(printf '\t')
filter_labels=$(LC_ALL=C awk -F'\t' '
  {
    m = split($4, rr, "@")
    for (k = 1; k <= m; k++) {
      d = split(rr[k], fv, "~")
      if (d >= 2 && fv[1] == "capture" && fv[10] == "direct-file") print fv[9]
      else if (d >= 2 && fv[1] == "scan" && fv[8] == "direct-file") print fv[7]
    }
  }
' "$tmp_rules" | LC_ALL=C sort -u | tr '\n' ' ')
if [ -n "$filter_labels" ] && [ -s "$tmp_edges" ]; then
  tmp_modf=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
  fl=" $filter_labels"
  while IFS= read -r e_line; do
    e_label=${e_line##*"$tab"}
    case $fl in
      *" $e_label "*)
        e_from=${e_line%%"$tab"*}
        e_rest=${e_line#*"$tab"}
        e_to=${e_rest%%"$tab"*}
        if [ -f "$repo_root/$e_to" ]; then
          printf '%s\t%s\t%s\n' "$e_from" "$e_to" "$e_label" >> "$tmp_modf"
        fi
        ;;
      *)
        printf '%s\n' "$e_line" >> "$tmp_modf"
        ;;
    esac
  done < "$tmp_edges"
  mv -f "$tmp_modf" "$tmp_edges"
fi

# ---- fp-v1 工作区指纹（R-DP-015 算法；输入排除本图自身，避免自引用漂移）----

fp_list=$(cd "$repo_root" && LC_ALL=C find . \
  \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
     -o -name __pycache__ -o -name .venv -o -path './docs/agent/runs' \) -prune -o \
  -type f -print \
  | sed 's|^\./||' | LC_ALL=C sort | grep -v -x -F -e "$out_rel") || fp_list=''

[ -n "$fp_list" ] || die1 '工作区文件清单为空——无法计算 fp-v1 指纹'

IFS=$NL
for rel in ${fp_list}; do
  case ${rel} in
    *"$tab"*) die1 "文件路径含制表符，无法承载指纹行格式: ${rel}" ;;
  esac
  meta=$(stat "$stat_flag" "$stat_fmt" "$repo_root/$rel") || die1 "stat 取文件元数据失败: ${rel}"
  printf '%s' "$meta" | grep -Eq '^[0-9]+ [0-9]+$' || die1 "stat 输出不合预期（非字节/秒对）: ${rel}"
  bytes=${meta%% *}
  mtime=${meta##* }
  printf '%s\t%s\t%s\n' "$rel" "$bytes" "$mtime" >> "$tmp_fp"
done
IFS=$OLDIFS

fp_hex=$(LC_ALL=C ${sha_cmd} < "$tmp_fp" | sed -n 's/.*\([0-9a-f]\{64\}\).*/\1/p' | cut -c1-16)
[ -n "$fp_hex" ] || die1 'SHA-256 计算失败（工具输出未含 64 位十六进制）'
fingerprint="fp-v1:${fp_hex}"

# ---- JSON 组装（转义与排版惯例参照 generate-progress.sh；json.loads 可解析）----

if [ -s "$tmp_edges" ]; then
  LC_ALL=C sort -u -o "$tmp_edges" "$tmp_edges"
fi
nodes_count=$(printf '%s\n' "$src_list" | wc -l | tr -d ' ')
if [ -s "$tmp_edges" ]; then
  edges_count=$(wc -l < "$tmp_edges" | tr -d ' ')
else
  edges_count=0
fi

nodes_body=$(printf '%s\n' "$src_list" | LC_ALL=C awk '{
  s = $0
  gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
  if (NR > 1) printf ",\n"
  printf "    \"%s\"", s
} END { if (NR > 0) printf "\n" }')

edges_body=''
if [ -s "$tmp_edges" ]; then
  edges_body=$(LC_ALL=C awk '
    function jesc(s) {
      gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
      return s
    }
    {
      n = split($0, f, "\t")
      if (n < 3) next
      if (NR > 1) printf ",\n"
      printf "    {\"from\": \"%s\", \"to\": \"%s\", \"label\": \"%s\"}", jesc(f[1]), jesc(f[2]), jesc(f[3])
    }
    END { if (NR > 0) printf "\n" }
  ' "$tmp_edges")
fi

generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

cov_body=$(LC_ALL=C awk -F'\t' '{
  s = sprintf("%s: %s", $1, $5)
  if (NR > 1) printf ",\n      \"%s\"", s
  else printf "      \"%s\"", s
}' "$tmp_rules")

limits_generic='语句文本层提取：不做别名/路径映射解析；注释内的导入文本构成已知误报源（规则经 fixture 最小验证，未实测项按一般工程知识保守声明）'
limits_rows=$(LC_ALL=C awk -F'\t' 'length($6) > 0 { n++; printf "%s%s", (n > 1 ? "；" : ""), $6 }' "$tmp_rules")

{
  printf '{\n'
  printf '  "generated_from": "事实源=仓库源码文件的静态导入行；工具=scripts/generate-module-map.sh（票 30 拍板方案 A 首版，票 42 落位，票 43 扩展，票 44 引擎表驱动化：语言知识外置于与脚本同目录的 module-map.rules 规则表）",\n'
  printf '  "generated_at": "%s",\n' "$generated_at"
  printf '  "coverage": {\n'
  printf '    "languages": [\n%s\n    ],\n' "$cov_body"
  if [ -n "$limits_rows" ]; then
    printf '    "limits": "%s；%s"\n' "$limits_generic" "$limits_rows"
  else
    printf '    "limits": "%s"\n' "$limits_generic"
  fi
  printf '  },\n'
  printf '  "invalidation": "重算 fp-v1 工作区指纹（R-DP-015 算法）与 workspace_fingerprint 不一致，或文件新增/删除/移动/重命名（拓扑变化）未重新生成本图，即按 development-process R-DP-009 判 stale，不得当可信导航；指纹输入排除本图自身（避免自引用漂移）",\n'
  printf '  "workspace_fingerprint": "%s",\n' "$fingerprint"
  printf '  "note": "本图是检索索引（Derived，可整文件重建），不是 Scope 权威，不作为白名单或 watch 依据；edges 的 from=仓库根相对路径，to=导入语句文本中的模块引用原串（未做路径解析），label=导入语句类别",\n'
  if [ -n "$nodes_body" ]; then
    printf '  "nodes": [\n%s  ],\n' "$nodes_body"
  else
    printf '  "nodes": [],\n'
  fi
  if [ -n "$edges_body" ]; then
    printf '  "edges": [\n%s  ]\n' "$edges_body"
  else
    printf '  "edges": []\n'
  fi
  printf '}\n'
} > "$tmp_out"

mkdir -p "$out_dir" || die1 "输出目录创建失败: $out_dir"
mv -f "$tmp_out" "$out_file" || die1 "地图写入失败: $out_file"

printf 'generate-module-map: OK: 已生成 %s（%s，nodes %s，edges %s）\n' "$out_file" "$fingerprint" "$nodes_count" "$edges_count"
