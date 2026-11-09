#!/bin/sh
# shellcheck disable=SC2154  # 全局变量由 source 方主壳赋值（Input 契约：entries_tsv／readme_file／repo_root／issues_dir_rel／tickets_readme_rel／_engine_file／t_dir）
# Input: 由 generate-progress.sh 主壳在解析索引条目后 source 本件——消费其已设变量：
#        entries_tsv（索引派生 TSV）、readme_file、repo_root、issues_dir_rel、tickets_readme_rel、
#        _engine_file、t_dir、NL／TAB 与 die1/die2（common-helpers.sh）。
# Output: 票表生成块生成与两类核对的函数体（readme_block_render／readme_block_range／
#         readme_sync／readme_check）与块标记常量 block_open／block_close；不执行任何动作、
#         不设 set -eu、不写除调用方指定临时文件与票表生成块以外的路径。
# Pos: 索引派生的第二派生对象（票 290 拆分：README 票表生成块独立成件，进度投影职责仍留
#      主壳）；本件为 generate-progress.sh 的同目录模块，CLI 形态与逐行输出不变，缺件由
#      主壳 fail-closed 指名。POSIX sh。

# 票表块自用的路径常量与派生输入（repo_root 由主壳在 source 前完成推导与赋值）
issues_dir_rel='facts/requirements/tickets'
tickets_readme_rel='facts/requirements/tickets/README.md'
readme_file="$repo_root/$tickets_readme_rel"

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
