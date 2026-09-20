#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层，check-gates.sh :20 先例）。
# Output: <root>/docs/architecture/module-map.json——Derived 四标注头部（generated_from/
#         generated_at/coverage/invalidation，R-DP-004）＋workspace_fingerprint（fp-v1，
#         R-DP-015 算法；指纹输入排除本图自身，避免自引用漂移）＋nodes（已扫描源码文件，
#         仓库根相对路径）＋edges（from=仓库根相对路径，to=导入语句文本中的模块引用原串，
#         label=导入语句类别）；stdout 输出一行成功摘要；stderr 报告失败原因。
# Pos: 模块地图生成器首版（票 30 调研拍板方案 A：静态导入行提取；票 42 落位）。
#      本图是项目地图条件产物的承载视图（development-process §5.2 触发矩阵行），只当
#      检索索引不当 Scope 权威，不作为白名单或 watch 依据；Derived 自动生成，agent 不
#      手写。POSIX sh、无 jq/python；两项平台标配补充：stat（BSD/GNU 双方言自动探测）
#      与系统 SHA-256 工具（sha256sum/shasum/cksum/openssl 按序探测），缺失即 fail-closed。
#      语言覆盖如实声明（R-CC-004）：首发三语言（Python import/from、JS/TS import/
#      require、C/C++ 引号 include）提取规则经 fixture 最小验证；动态 import()、别名与
#      路径映射解析、re-export、尖括号系统头不在覆盖内。

# 用法、语言登记表与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

usage() {
  cat <<'USAGE'
用法: sh generate-module-map.sh [repo-root]
参数:
  repo-root   仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  -h / --help 打印本用法。
输出: <root>/docs/architecture/module-map.json（Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌）。
退出码: 0 生成成功；1 生成条件不满足（无受支持源码、路径含控制字符、写入失败等；
        fail-closed，不写地图）；2 用法或环境错误（非 Git 仓库、仓库根不存在、
        SHA-256/stat 工具缺失）。
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
probe_file=''
cleanup() {
  rm -f "$tmp_out" "$tmp_edges" "$tmp_nodes" "$tmp_fp" "$probe_file"
}
trap cleanup EXIT HUP INT TERM
tmp_out=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_edges=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_nodes=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")
tmp_fp=$(mktemp "${t_dir%/}/genmodulemap.XXXXXX")

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

# ---- 源码文件发现（三语言扩展名；prune 排除 .git、依赖与构建产物目录、docs/agent/runs）----

src_list=$(cd "$repo_root" && LC_ALL=C find . \
  \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
     -o -name __pycache__ -o -name .venv -o -path './docs/agent/runs' \) -prune -o \
  -type f \( -name '*.py' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \
     -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \
     -o -name '*.c' -o -name '*.h' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \
     -o -name '*.hpp' -o -name '*.hh' \) -print \
  | sed 's|^\./||' | LC_ALL=C sort)

[ -n "$src_list" ] || die1 '未发现受支持语言的源码文件（Python/JS/TS/C/C++）——无可生成的模块地图（fail-closed，不写输出）'

if printf '%s\n' "$src_list" | grep -Eq '[[:cntrl:]]'; then
  die1 '源码文件清单含制表符或其他控制字符（无法安全承载于提取层）——fail-closed'
fi

# ---- 静态导入行提取（逐文件 awk，语句文本层，不做语义过滤——票 30 调研结论①）----

NL='
'
OLDIFS=$IFS
IFS=$NL
for rel in ${src_list}; do
  case ${rel} in
    *.py) lang='python' ;;
    *.js|*.mjs|*.cjs|*.jsx|*.ts|*.tsx) lang='js' ;;
    *.c|*.h|*.cc|*.cpp|*.cxx|*.hpp|*.hh) lang='c' ;;
    *) continue ;;
  esac
  [ -f "$repo_root/$rel" ] || die1 "源码文件不可读（疑似路径含换行被拆分）: ${rel}"
  LC_ALL=C awk -v lang="$lang" -v src="$rel" '
    function emit(to, label) {
      if (to == "") return
      if (to ~ /[[:cntrl:]]/) return
      printf "%s\t%s\t%s\n", src, to, label
    }
    FNR == 1 { q = sprintf("%c", 39) }
    lang == "python" {
      line = $0
      sub(/#.*/, "", line)
      if (line ~ /^[[:space:]]*from[[:space:]]/) {
        rest = line
        sub(/^[[:space:]]*from[[:space:]]+/, "", rest)
        n = split(rest, toks, /[[:space:]]+/)
        if (n >= 2 && toks[2] == "import" && toks[1] ~ /^[A-Za-z_.][A-Za-z0-9_.]*$/) {
          emit(toks[1], "python-from")
        }
      }
      if (line ~ /^[[:space:]]*import[[:space:]]/) {
        rest = line
        sub(/^[[:space:]]*import[[:space:]]+/, "", rest)
        gsub(/;/, " ", rest)
        m = split(rest, items, /,/)
        for (i = 1; i <= m; i++) {
          k = split(items[i], t2, /[[:space:]]+/)
          tok = ""
          for (j = 1; j <= k; j++) {
            if (t2[j] != "") { tok = t2[j]; break }
          }
          if (tok ~ /^[A-Za-z_.][A-Za-z0-9_.]*$/) {
            emit(tok, "python-import")
          }
        }
      }
    }
    lang == "js" {
      line = $0
      gsub(q, "\"", line)
      if (line ~ /^[[:space:]]*import[[:space:]({*]/ || line ~ /^[[:space:]]*import[[:space:]]*"/) {
        if (match(line, /from[[:space:]]*"[^"]*"/)) {
          seg = substr(line, RSTART, RLENGTH)
          sub(/^from[[:space:]]*"/, "", seg)
          sub(/"$/, "", seg)
          emit(seg, "js-import")
        }
        if (match(line, /^[[:space:]]*import[[:space:]]*"[^"]+"/)) {
          seg = substr(line, RSTART, RLENGTH)
          sub(/^[[:space:]]*import[[:space:]]*"/, "", seg)
          sub(/"$/, "", seg)
          emit(seg, "js-import")
        }
      }
      if (match(line, /(^|[^A-Za-z0-9_$.])require[[:space:]]*\([[:space:]]*"[^"]+"[[:space:]]*\)/) \
          || match(line, /(^|[^A-Za-z0-9_$.])require[[:space:]]*"[^"]+"/)) {
        seg = substr(line, RSTART, RLENGTH)
        if (match(seg, /"[^"]+"/)) {
          q2 = substr(seg, RSTART, RLENGTH)
          sub(/^"/, "", q2)
          sub(/"$/, "", q2)
          emit(q2, "js-require")
        }
      }
    }
    lang == "c" {
      if (match($0, /^[[:space:]]*#[[:space:]]*include[[:space:]]*"[^"]+"/)) {
        seg = substr($0, RSTART, RLENGTH)
        sub(/^[[:space:]]*#[[:space:]]*include[[:space:]]*"/, "", seg)
        sub(/"$/, "", seg)
        emit(seg, "c-include")
      }
    }
  ' "$repo_root/$rel" >> "$tmp_edges"
done
IFS=$OLDIFS

# ---- fp-v1 工作区指纹（R-DP-015 算法；输入排除本图自身，避免自引用漂移）----

fp_list=$(cd "$repo_root" && LC_ALL=C find . \
  \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
     -o -name __pycache__ -o -name .venv -o -path './docs/agent/runs' \) -prune -o \
  -type f -print \
  | sed 's|^\./||' | LC_ALL=C sort | grep -v -x -F -e "$out_rel") || fp_list=''

[ -n "$fp_list" ] || die1 '工作区文件清单为空——无法计算 fp-v1 指纹'

tab=$(printf '\t')
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

{
  printf '{\n'
  printf '  "generated_from": "事实源=仓库源码文件的静态导入行；工具=scripts/generate-module-map.sh（票 30 拍板方案 A 首版，票 42 落位）",\n'
  printf '  "generated_at": "%s",\n' "$generated_at"
  printf '  "coverage": {\n'
  printf '    "languages": [\n'
  printf '      "python: import / from-import（.py）",\n'
  printf '      "js-ts: import / require（.js .mjs .cjs .jsx .ts .tsx）",\n'
  printf '      "c-cpp: 引号 include（.c .h .cc .cpp .cxx .hpp .hh）"\n'
  printf '    ],\n'
  printf '    "limits": "语句文本层提取：不做别名/路径映射解析；未覆盖动态 import()、re-export、尖括号系统头；注释内的导入文本构成已知误报源（规则经 fixture 最小验证，未实测项按一般工程知识保守声明）"\n'
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
