#!/bin/sh
# Input: facts/requirements/tickets/index.json（票状态索引真相源，单文件一条目一行，票 33 终裁 T2）
# projection-version: 2（投影列形态＋票表生成块；机制版本注记）
#        与可选参数：--check／--check-readme 开关、仓库根目录（缺省按脚本落位分派推导，
#        agent-up/scripts/ 两层或 rules/implementation/scripts/ 三层布局可正确推导，
#        其余落位兜底上两级；check-stale-claims 的严格两布局口径见其专节）。
# Output: 两处索引派生投影（同一生成器独占写，agent 不手写）：
#         ①facts/requirements/tickets/progress-current.md 现役状态投影——Derived 四标注头部
#         （generated_from、生成时间、覆盖范围、失效条件）＋每票一行
#         `| id | status | checkpoint_ref | updated_at |` 状态表，按 id 升序；
#         ②facts/requirements/tickets/README.md 的票表生成块——标记
#         `<!-- tickets-readme: generated from=... -->` 与 `<!-- /tickets-readme -->` 之间整表
#         由索引派生（行集合与顺序取索引；状态列取索引；名字/开票日期/功能列复用现行块行原文，
#         索引新增条目按票本体 title/created_at 派生），块外逐字节不动。
#         --check 模式为 progress-current 的 dry-run；--check-readme 为票表生成块的只读
#         新鲜度断言（块缺失但目录清单表在场＝未迁移，exit 1；README 缺失＝跳过 exit 0）。
#         两类核对不一致即 exit 1，不落盘。
# Pos: 本仓记录层投影生成器（票 33 草案 §5.1.4 生成规则 / 票 35 落位；票 115 波⑤路径随 rules/facts 布局翻值）；
#      生成器独占写 facts/requirements/tickets/progress-current.md 与
#      facts/requirements/tickets/README.md 的票表生成块（派生载体独占写），agent 不手写。
#      POSIX sh；条目字段解析由唯一 JSON 引擎 json-validator.py 承载（原 json-helpers.sh awk 行解析
#      retired，本件零内嵌 JSON 解析副本；引擎同目录分发，缺件 fail-closed 指名）；
#      fail-closed：索引缺失、不可读或条目行不合预期即停止报告，不写投影。投影与索引不一致时以索引为准。

# 用法与退出码见同目录 README.md。

# ---- 路径常量区（票 113 波④：值翻 rules/facts 新形态，映射见 rules-facts-layout-spec §2 R13/R15/R19）----
issues_index_rel='facts/requirements/tickets/index.json'
progress_current_rel='facts/requirements/tickets/progress-current.md'
tickets_readme_rel='facts/requirements/tickets/README.md'
issues_dir_rel='facts/requirements/tickets'
gen_script_rel='rules/implementation/scripts/generate-progress.sh'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（die 兜底副本清零，统一 source common-helpers.sh；同目录分发）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'generate-progress: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

# 唯一 JSON 引擎定位（同目录分发，缺件 fail-closed 指名）
_engine_file=$(dirname "$0")/json-validator.py
if [ ! -f "$_engine_file" ]; then
  printf 'generate-progress: FAIL: 唯一 JSON 引擎缺失: %s（json-validator.py 与本件同目录分发）\n' "$_engine_file" >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/generate-progress.sh [--check|--check-readme] [repo-root]
参数:
  --check         dry-run 模式：与既有 facts/requirements/tickets/progress-current.md 比对（规范化
                  generated_at 行后逐字节比对），一致 exit 0，不一致 exit 1；不写任何文件。
  --check-readme  dry-run 模式：核对 README 票表生成块是否等于索引派生结果（逐行比对）；
                  不一致或块缺失但目录清单表在场（未迁移）exit 1；README 缺失或既无块亦无表 exit 0。
  repo-root      仓库根目录；缺省按脚本落位分派推导（agent-up/scripts/ 与
                  rules/implementation/scripts/ 两布局可正确推导，其余落位兜底上两级，
                 亦可显式传入）。
  -h / --help    打印本用法。
退出码: 0 生成成功或核对一致；1 核对不一致（投影 stale／生成块漂移或未迁移）；
        2 用法错误、索引文件缺失/不可读或条目行不合预期（fail-closed，不写投影）。
USAGE
}

check_mode=0
readme_check_mode=0
repo_root=''
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --check) check_mode=1 ;;
    --check-readme) readme_check_mode=1 ;;
    --*) die2 "未知参数: $arg" ;;
    -*) usage >&2; exit 2 ;;
    *) if [ -n "$repo_root" ]; then die2 "多余参数: ${arg}（只接受一个仓库根）"; fi; repo_root=$arg ;;
  esac
done
if [ "$check_mode" -eq 1 ] && [ "$readme_check_mode" -eq 1 ]; then
  die2 '--check 与 --check-readme 互斥（一个模式一类投影）'
fi

# 缺省根＝落位分派推导（票 206/227：仓库根推导统一经 resolve_repo_root）
if [ -n "$repo_root" ]; then
  _rr=$(resolve_repo_root "$repo_root") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
if [ -z "$_rr" ]; then
  if [ -n "$repo_root" ]; then
    die2 "仓库根不可用: $repo_root"
  fi
  die2 '仓库根推导失败（脚本落位非两布局，请显式传入仓库根参数，用法见 -h）'
fi
repo_root=$_rr

index_file="$repo_root/$issues_index_rel"
out_file="$repo_root/$progress_current_rel"
readme_file="$repo_root/$tickets_readme_rel"

[ -f "$index_file" ] || die2 "索引文件不存在: ${index_file}（现役状态投影真相源缺失，fail-closed 不生成；若脚本落位非上述两布局，请显式传入仓库根参数，用法见 -h）"
[ -r "$index_file" ] || die2 "索引文件不可读: $index_file"

# 条目提取依赖一条目一行排版（T2）：行含 `"id": "<数字开头 id>"` 锚点；无命中即排版或内容不合预期，fail-closed。
entries=$(grep '"id": "[0-9]' "$index_file") || {
  printf 'generate-progress: FAIL: %s\n' '索引中未找到条目行（"id": 数字锚点零命中）——确认一条目一行排版' >&2
  exit 2
}

NL='
'
TAB=$(printf '\t')

# 每条目行投影一行状态表；字段解析经唯一 JSON 引擎 json fields（TAB 分列，一行一返回）；
# 必备字段（id/status/updated_at）值均非空（schema minLength），故空值即判缺失；
# checkpoint_ref 可选（省略投影为空单元格）。同一循环按索引顺序积累票表派生用 (id,status)。
rows=''
entries_tsv=''
while IFS= read -r entry_line; do
  # 一条目一行排版行尾带数组分隔逗号（除末条目），剥除后交引擎解析（引擎输入须为合法 JSON）
  _entry_json=${entry_line%,}
  _fields=$(printf '%s\n' "$_entry_json" | python3 "$_engine_file" json fields - id status updated_at checkpoint_ref) || {
    printf 'generate-progress: FAIL: %s\n' "条目行不合 JSON 或缺字段: $entry_line" >&2
    exit 2
  }
  IFS="$TAB" read -r id status updated_at checkpoint_ref <<EOF
$_fields
EOF

  if [ -z "$id" ] || [ -z "$status" ] || [ -z "$updated_at" ]; then
    die2 "条目行缺必备字段或不合预期: $entry_line"
  fi

  if [ -n "$rows" ]; then
    rows="${rows}
"
  fi
  rows="${rows}| ${id} | ${status} | ${checkpoint_ref} | ${updated_at} |"
  entries_tsv="${entries_tsv}${id}${TAB}${status}${NL}"
done <<EOF
$entries
EOF

t_dir=${TMPDIR:-/tmp}
tmp_out=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
tmp_a=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
tmp_b=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
cleanup() {
  rm -f "$tmp_out" "$tmp_a" "$tmp_b"
  rm -f "${tmp_block:-}" "${tmp_cur:-}" "${tmp_new:-}"
  return 0
}
trap cleanup EXIT HUP INT TERM

generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

{
  printf '<!-- generated_from: %s + %s -->\n' "$issues_index_rel" "$gen_script_rel"
  printf '<!-- generated_at: %s -->\n' "$generated_at"
  printf '<!-- coverage: %s 登记的全部票，每票一行，按 id 升序 -->\n' "$issues_index_rel"
  printf '<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 %s 不一致时以索引为准 -->\n' "$issues_index_rel"
  printf '\n'
  printf '# 现役状态投影（Derived）\n'
  printf '\n'
  printf '| id | status | checkpoint_ref | updated_at |\n'
  printf '| --- | --- | --- | --- |\n'
  printf '%s\n' "$rows" | LC_ALL=C sort
} > "$tmp_out"

# ---- 票表生成块（索引派生；块外逐字节不动）----
# 单点生成：行集合与顺序取索引；状态列一律取索引；名字/开票日期/功能列复用现行块行原文，
# 索引新增条目按票本体 title/created_at 派生（功能列取不到即占位）。--sync 与 --check-readme
# 共用本生成点，保证核对基准就是写模式会写入的同一内容。
block_open='<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->'
block_close='<!-- /tickets-readme -->'

readme_block_render() {
  # $1=输出块文件（含起止标记＋表头＋数据行）。行集合与顺序取索引；状态列取索引；
  # 表头/分隔行与名字/开票日期/功能列复用现行块行（或迁移前目录清单表行）原文；索引新增
  # 条目按票本体 title/created_at 派生。表内不含「任务票 NN；」锚点的行（如目录 README
  # 自身登记行）按原文保留在表头之后，不参与索引派生。
  _br_out=$1
  _br_dir=$(mktemp -d "${t_dir%/}/genprogress.XXXXXX") || die2 '临时目录创建失败'
  _br_range=$(readme_block_range) || { rm -rf "$_br_dir"; return $?; }
  _br_start=${_br_range%% *}
  _br_end=${_br_range##* }
  printf '%s' "$entries_tsv" > "$_br_dir/index.tsv"
  : > "$_br_dir/old.tsv"
  : > "$_br_dir/meta.tsv"
  : > "$_br_dir/extra.tsv"
  : > "$_br_dir/head.tsv"
  if [ -f "$readme_file" ] && [ "$_br_start" -gt 0 ]; then
    awk -v tstart="$_br_start" -v tend="$_br_end" \
      -v extraf="$_br_dir/extra.tsv" -v headf="$_br_dir/head.tsv" '
      NR < tstart || NR > tend { next }
      /^<!-- tickets-readme: generated from=/ { next }
      /^<!-- \/tickets-readme -->$/ { next }
      /^\| / {
        line = $0
        if (!hdrseen) { print line > headf; hdrseen = 1; next }
        if (!sepseen && line ~ /^\| *---/) { print line > headf; sepseen = 1; next }
        sepseen = 1
        i = index(line, " | ")
        if (i == 0) next
        cell1 = substr(line, 3, i - 3)
        rest = substr(line, i + 3)
        j = index(rest, " | ")
        if (j == 0) next
        cell2 = substr(rest, 1, j - 1)
        if (cell2 !~ /任务票 [0-9]/) { print line > extraf; next }
        desc = substr(rest, j + 3)
        sub(/ *[|][ ]*$/, "", desc)
        name = cell1
        gsub(/`/, "", name)
        id = name
        sub(/\.md$/, "", id)
        sub(/\.json$/, "", id)
        if (id == "") next
        p = index(cell2, "；")
        if (p == 0) next
        tail = substr(cell2, p + 1)
        b1 = index(tail, "`")
        if (b1 == 0) next
        rest2 = substr(tail, b1 + 1)
        b2 = index(rest2, "`")
        if (b2 == 0) next
        suffix = substr(rest2, b2 + 1)
        gsub(/^ +| +$/, "", suffix)
        print id "\t" name "\t" suffix "\t" desc
      }
    ' "$readme_file" > "$_br_dir/old.tsv"
  fi
  # 索引中未在现行行出现的条目＝新增行：按票本体派生名字/开票日期/功能列
  awk -F "$TAB" -v oldf="$_br_dir/old.tsv" '
    BEGIN { while ((getline l < oldf) > 0) { split(l, a, "\t"); seen[a[1]] = 1 } }
    !($1 in seen) { print $1 }
  ' "$_br_dir/index.tsv" > "$_br_dir/missing.tsv"
  if [ -s "$_br_dir/missing.tsv" ]; then
    while IFS= read -r _nid; do
      [ -n "$_nid" ] || continue
      _nname="${_nid}.json"
      if [ -f "$repo_root/$issues_dir_rel/${_nid}.md" ]; then _nname="${_nid}.md"; fi
      _nsuf=''
      _ndesc=''
      _nbody="$repo_root/$issues_dir_rel/${_nid}.json"
      if [ -f "$_nbody" ]; then
        _ncreated=$(python3 "$_engine_file" json get "$_nbody" created_at 2>/dev/null) || _ncreated=''
        _ntitle=$(python3 "$_engine_file" json get "$_nbody" title 2>/dev/null) || _ntitle=''
        if [ -n "$_ncreated" ]; then _nsuf="（${_ncreated} 开票）"; fi
        if [ -n "$_ntitle" ]; then _ndesc=$_ntitle; fi
      fi
      if [ -z "$_ndesc" ]; then _ndesc='【填写：功能描述】'; fi
      printf '%s\t%s\t%s\t%s\n' "$_nid" "$_nname" "$_nsuf" "$_ndesc"
    done < "$_br_dir/missing.tsv" > "$_br_dir/meta.tsv"
  fi
  awk -F "$TAB" -v openm="$block_open" -v closem="$block_close" \
    -v oldf="$_br_dir/old.tsv" -v metaf="$_br_dir/meta.tsv" \
    -v extraf="$_br_dir/extra.tsv" -v headf="$_br_dir/head.tsv" '
    BEGIN {
      while ((getline l < oldf) > 0) { split(l, a, "\t"); oname[a[1]] = a[2]; osuf[a[1]] = a[3]; odesc[a[1]] = a[4]; ohit[a[1]] = 1 }
      while ((getline l < metaf) > 0) { split(l, b, "\t"); mname[b[1]] = b[2]; msuf[b[1]] = b[3]; mdesc[b[1]] = b[4] }
      nh = 0
      while ((getline l < headf) > 0) { if (l != "") { nh++; head[nh] = l } }
      print openm
      if (nh >= 2) { print head[1]; print head[2] }
      else { print "| 名字 | 地位 | 功能 |"; print "| --- | --- | --- |" }
      while ((getline l < extraf) > 0) { if (l != "") print l }
    }
    { ids[++n] = $1; st[$1] = $2 }
    END {
      for (i = 1; i <= n; i++) {
        id = ids[i]
        if (id in ohit) { name = oname[id]; suf = osuf[id]; desc = odesc[id] }
        else { name = mname[id]; suf = msuf[id]; desc = mdesc[id] }
        if (name == "") name = id ".json"
        nn = id
        sub(/-.*/, "", nn)
        print "| `" name "` | 任务票 " nn "；`" st[id] "`" suf " | " desc " |"
      }
      print closem
    }
  ' "$_br_dir/index.tsv" > "$_br_out"
  rm -rf "$_br_dir"
  return 0
}

readme_block_range() {
  # stdout: "<start> <end>"（替换范围，含标记；迁移形态为既有目录清单表范围）；
  # 无块亦无表输出 "0 0"；标记不成对/重复/顺序颠倒 return 2（fail-closed 不猜）。
  _ob=$(grep -c -F -x -- "$block_open" "$readme_file" 2>/dev/null) || _ob=0
  _cb=$(grep -c -F -x -- "$block_close" "$readme_file" 2>/dev/null) || _cb=0
  if [ "$_ob" -gt 1 ] || [ "$_cb" -gt 1 ] || [ "$_ob" -ne "$_cb" ]; then
    printf 'generate-progress: FAIL: %s 票表生成块标记不成对或重复（起 %s／止 %s）——人工核对标记后重跑\n' "$tickets_readme_rel" "$_ob" "$_cb" >&2
    return 2
  fi
  if [ "$_ob" -eq 1 ]; then
    _s=$(grep -n -F -x -- "$block_open" "$readme_file" | head -n 1 | cut -d: -f1)
    _e=$(grep -n -F -x -- "$block_close" "$readme_file" | head -n 1 | cut -d: -f1)
    if [ "$_e" -le "$_s" ]; then
      printf 'generate-progress: FAIL: %s 票表生成块起止顺序颠倒（起 %s／止 %s）\n' "$tickets_readme_rel" "$_s" "$_e" >&2
      return 2
    fi
    printf '%s %s\n' "$_s" "$_e"
    return 0
  fi
  # 迁移形态：块缺失时按既有目录清单表（表头＋分隔行＋连续数据行）就地包裹
  _sep=$(grep -n -E '^[|] *---' "$readme_file" | head -n 1 | cut -d: -f1) || _sep=''
  case ${_sep} in ''|*[!0-9]*) printf '0 0\n'; return 0 ;; esac
  if [ "$_sep" -le 1 ]; then printf '0 0\n'; return 0; fi
  _hdr=$((_sep - 1))
  _hdr_line=$(sed -n "${_hdr}p" "$readme_file")
  case ${_hdr_line} in
    '|'*) ;;
    *) printf '0 0\n'; return 0 ;;
  esac
  _end=$(awk -v s="$_sep" 'NR > s { if ($0 !~ /^[|]/) { print NR - 1; done = 1; exit } } END { if (!done) print NR }' "$readme_file")
  case ${_end} in ''|*[!0-9]*) printf '0 0\n'; return 0 ;; esac
  printf '%s %s\n' "$_hdr" "$_end"
  return 0
}

readme_sync() {
  [ -f "$readme_file" ] || {
    printf 'generate-progress: SKIP: %s: 文件不存在（无票表可派生）\n' "$tickets_readme_rel"
    return 0
  }
  _range=$(readme_block_range) || return $?
  _start=${_range%% *}
  _end=${_range##* }
  if [ "$_start" -eq 0 ]; then
    printf 'generate-progress: SKIP: %s: 无票表生成块亦无目录清单表——不新建（报告用户后迁移）\n' "$tickets_readme_rel"
    return 0
  fi
  tmp_block=$(mktemp "${t_dir%/}/genprogress.XXXXXX") || die2 '临时文件创建失败'
  tmp_new=$(mktemp "${t_dir%/}/genprogress.XXXXXX") || die2 '临时文件创建失败'
  readme_block_render "$tmp_block"
  awk -v start="$_start" -v end="$_end" -v bf="$tmp_block" '
    BEGIN { while ((getline l < bf) > 0) { nb++; blk[nb] = l } }
    {
      if (NR == start) { for (i = 1; i <= nb; i++) print blk[i] }
      if (NR >= start && NR <= end) next
      print
    }
  ' "$readme_file" > "$tmp_new" || die2 "票表生成块写入失败: $tickets_readme_rel"
  mv -f "$tmp_new" "$readme_file"
  rm -f "$tmp_new"
  tmp_new=''
  rm -f "$tmp_block"
  tmp_block=''
  printf 'generate-progress: OK: 已生成票表生成块（索引派生，块外逐字节不动）: %s\n' "$tickets_readme_rel"
  return 0
}

readme_check() {
  [ -f "$readme_file" ] || {
    printf 'generate-progress: CHECK: SKIP — %s 不存在\n' "$tickets_readme_rel"
    return 0
  }
  _range=$(readme_block_range) || return $?
  _start=${_range%% *}
  _end=${_range##* }
  if [ "$_start" -eq 0 ]; then
    printf 'generate-progress: CHECK: SKIP — %s 无票表生成块亦无目录清单表\n' "$tickets_readme_rel"
    return 0
  fi
  _ob=$(grep -c -F -x -- "$block_open" "$readme_file" 2>/dev/null) || _ob=0
  if [ "$_ob" -eq 0 ]; then
    printf '%s:1: 未迁移为生成块: 目录清单表在场但无票表生成块标记——运行生成器（无参数）迁移并刷新\n' "$tickets_readme_rel" >&2
    return 1
  fi
  tmp_block=$(mktemp "${t_dir%/}/genprogress.XXXXXX") || die2 '临时文件创建失败'
  tmp_cur=$(mktemp "${t_dir%/}/genprogress.XXXXXX") || die2 '临时文件创建失败'
  readme_block_render "$tmp_block"
  sed -n "${_start},${_end}p" "$readme_file" > "$tmp_cur"
  if cmp -s "$tmp_block" "$tmp_cur"; then
    printf 'generate-progress: CHECK: PASS — 票表生成块与索引派生一致: %s\n' "$tickets_readme_rel"
    return 0
  fi
  _hunk=$(diff "$tmp_cur" "$tmp_block" 2>/dev/null | sed -n '1p') || _hunk=''
  _rel_line=$(printf '%s' "$_hunk" | sed 's/[^0-9].*//')
  case ${_rel_line} in ''|*[!0-9]*) _rel_line=1 ;; esac
  _abs_line=$((_start + _rel_line - 1))
  printf '%s:%d: 票表生成块与索引派生不一致（stale）——运行生成器刷新；差异: %s\n' \
    "$tickets_readme_rel" "$_abs_line" "$_hunk" >&2
  diff "$tmp_cur" "$tmp_block" 2>/dev/null | sed -n '2,6p' >&2 || true
  return 1
}

if [ "$check_mode" -eq 1 ]; then
  # --check：规范化两侧 generated_at 行后逐字节比对（该行随生成时间漂移，不参与一致性判定）。
  [ -f "$out_file" ] || die1 "投影文件不存在: ${out_file}（先运行生成器落盘）"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$tmp_out" > "$tmp_a"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$out_file" > "$tmp_b"
  if cmp -s "$tmp_a" "$tmp_b"; then
    printf 'generate-progress: CHECK: PASS — 投影与索引一致: %s\n' "$out_file"
    exit 0
  fi
  printf 'generate-progress: FAIL: 投影与索引不一致（stale）: %s\n' "$out_file" >&2
  diff -u "$tmp_b" "$tmp_a" >&2 || true
  exit 1
fi

if [ "$readme_check_mode" -eq 1 ]; then
  readme_check
  exit $?
fi

mv -f "$tmp_out" "$out_file"
printf 'generate-progress: OK: 已生成 %s\n' "$out_file"
readme_sync
