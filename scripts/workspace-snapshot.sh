#!/bin/sh
# Input: 调用方（check-gates.sh）已初始化的 repo_root／work_dir／cg_* 暂存全局与
#        die2 报文函数；快照落调用方 work_dir。
# Output: cg_snapshot（路径<TAB>类型<TAB>状态 快照生成）、cg_diff（两次快照分类清单与
#        cg_added/cg_removed/cg_changed 计数）、cg_print_paths（异常路径输出）、
#        cg_report（verify 越界改动报告）四个函数。
# Pos: 快道门禁工作区快照子系统模块（票 294：从 check-gates.sh 抽公共库）；快照格式与
#      哈希口径的唯一承载点，check-gates.sh 主件只做白名单与 verify 编排。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（调用方快照上下文），单文件视野误报

# 生成完整工作区快照到 $1：路径<TAB>类型<TAB>状态（内容哈希/索引三元组/HEAD 值）
cg_snapshot() {
  _snap_out=$1
  _tmp="${work_dir}/snap"
  rm -rf "${_tmp}"
  mkdir -p "${_tmp}" || die2 '快照临时目录创建失败（TMPDIR 不可写？）'

  ( CDPATH='' cd -- "${repo_root}" && find . -mindepth 1 -name .git -prune -o -type d -print0 ) > "${_tmp}/dirs.nul" \
    || die2 '工作区目录遍历失败'
  ( CDPATH='' cd -- "${repo_root}" && find . -mindepth 1 -name .git -prune -o -type f -print0 ) > "${_tmp}/files.nul" \
    || die2 '工作区文件遍历失败'
  ( CDPATH='' cd -- "${repo_root}" && find . -mindepth 1 -name .git -prune -o -type f -perm -u+x -print0 ) > "${_tmp}/exec.nul" \
    || die2 '工作区可执行文件遍历失败'
  ( CDPATH='' cd -- "${repo_root}" && find . -mindepth 1 -name .git -prune -o -type l -print0 ) > "${_tmp}/links.nul" \
    || die2 '工作区符号链接遍历失败'
  ( CDPATH='' cd -- "${repo_root}" && find . -mindepth 1 -name .git -prune -o ! -type d ! -type f ! -type l -print0 ) > "${_tmp}/others.nul" \
    || die2 '工作区特殊文件遍历失败'

  _badchars=$(cat "${_tmp}/dirs.nul" "${_tmp}/files.nul" "${_tmp}/links.nul" "${_tmp}/others.nul" | tr -d -c '\n\t' | wc -c | tr -d ' ')
  [ "${_badchars}" -eq 0 ] || die2 '工作区路径含换行或制表符，无法生成快照（环境错误）'

  _ibadchars=$(git -C "${repo_root}" ls-files -z | tr -d -c '\n\t' | wc -c | tr -d ' ')
  [ "${_ibadchars}" -eq 0 ] || die2 '索引路径含换行或制表符，无法生成快照（环境错误）'

  tr '\0' '\n' < "${_tmp}/dirs.nul" | sed 's|^\./||' | LC_ALL=C sort > "${_tmp}/dirs.txt"
  tr '\0' '\n' < "${_tmp}/files.nul" | sed 's|^\./||' | LC_ALL=C sort > "${_tmp}/files.txt"
  tr '\0' '\n' < "${_tmp}/exec.nul" | sed 's|^\./||' | LC_ALL=C sort > "${_tmp}/exec.txt"
  tr '\0' '\n' < "${_tmp}/links.nul" | sed 's|^\./||' | LC_ALL=C sort > "${_tmp}/links.txt"
  tr '\0' '\n' < "${_tmp}/others.nul" | sed 's|^\./||' | LC_ALL=C sort > "${_tmp}/others.txt"

  cg_filter < "${_tmp}/dirs.txt" > "${_tmp}/dirs.f"
  cg_filter < "${_tmp}/files.txt" > "${_tmp}/files.f"
  cg_filter < "${_tmp}/links.txt" > "${_tmp}/links.f"
  cg_filter < "${_tmp}/others.txt" > "${_tmp}/others.f"

  _nf=$(wc -l < "${_tmp}/files.f" | tr -d ' ')
  if [ "${_nf}" -gt 0 ]; then
    ( CDPATH='' cd -- "${repo_root}" && git hash-object --stdin-paths < "${_tmp}/files.f" ) > "${_tmp}/hashes.txt" 2> "${_tmp}/hash.err" \
      || die2 "工作区文件内容哈希失败（环境错误）: $(head -n 1 "${_tmp}/hash.err")"
  else
    : > "${_tmp}/hashes.txt"
  fi
  _nh=$(wc -l < "${_tmp}/hashes.txt" | tr -d ' ')
  [ "${_nf}" -eq "${_nh}" ] || die2 '工作区文件在快照期间不可读或数量变化，快照不完整'

  git -C "${repo_root}" ls-files -s -z | tr '\0' '\n' \
    | awk -F '\t' 'NF >= 2 { printf "%s\tI\t%s\n", $2, $1 }' > "${_tmp}/index.txt"

  if _head=$(git -C "${repo_root}" rev-parse --verify -q HEAD 2>/dev/null); then :; else _head='none'; fi
  if _sym=$(git -C "${repo_root}" symbolic-ref -q HEAD 2>/dev/null); then :; else _sym='detached'; fi

  {
    printf 'HEAD\tH\t%s\n' "${_head}"
    printf 'SYMREF\tH\t%s\n' "${_sym}"
    cat "${_tmp}/index.txt"
    awk -v hf="${_tmp}/hashes.txt" -v xf="${_tmp}/exec.txt" '
      BEGIN {
        n = 0
        while ((getline h < hf) > 0) { n++; H[n] = h }
        while ((getline p < xf) > 0) { X[p] = 1 }
      }
      { mode = (($0 in X) ? "755" : "644"); printf "%s\tF\t%s:%s\n", $0, mode, H[NR] }
    ' "${_tmp}/files.f"
    awk '{ printf "%s\tD\tdir\n", $0 }' "${_tmp}/dirs.f"
    awk '{ printf "%s\tO\tother\n", $0 }' "${_tmp}/others.f"
    while IFS= read -r _lp; do
      [ -n "${_lp}" ] || continue
      _lt=$(readlink "${repo_root}/${_lp}") || die2 "符号链接目标读取失败: ${_lp}"
      case ${_lt} in
        *"${NL}"*) die2 "符号链接目标含换行，无法生成快照: ${_lp}" ;;
      esac
      _lh=$(printf '%s' "${_lt}" | git -C "${repo_root}" hash-object --stdin) \
        || die2 "符号链接目标哈希失败: ${_lp}"
      printf '%s\tL\tsymlink:%s\n' "${_lp}" "${_lh}"
    done < "${_tmp}/links.f"
  } > "${_tmp}/manifest.raw"

  LC_ALL=C sort "${_tmp}/manifest.raw" > "${_snap_out}"
}

# 比对两次快照：$1=前 $2=后；结果写入 work_dir 的分类清单
# 分类按「条目差异」而非路径存在性：同一路径可同时有索引行与工作区行，
# 删除文件时工作区行消失但索引行仍在——路径级集合差会被抵消，故先取
# 仅前侧/仅后侧的条目路径，再以两集合归属判定新增/删除/变更。
cg_diff() {
  _b=$1
  _a=$2
  comm -23 "${_b}" "${_a}" | cut -f1 | LC_ALL=C sort -u > "${work_dir}/p_minus"
  comm -13 "${_b}" "${_a}" | cut -f1 | LC_ALL=C sort -u > "${work_dir}/p_plus"
  comm -13 "${work_dir}/p_minus" "${work_dir}/p_plus" > "${work_dir}/p_added"
  comm -23 "${work_dir}/p_minus" "${work_dir}/p_plus" > "${work_dir}/p_removed"
  comm -12 "${work_dir}/p_minus" "${work_dir}/p_plus" > "${work_dir}/p_changed"
  cg_added=$(wc -l < "${work_dir}/p_added" | tr -d ' ')
  cg_removed=$(wc -l < "${work_dir}/p_removed" | tr -d ' ')
  cg_changed=$(wc -l < "${work_dir}/p_changed" | tr -d ' ')
}

# $1=标签 $2=路径清单 $3=行首记号
cg_print_paths() {
  _label=$1
  _file=$2
  _mark=$3
  _pn=$(wc -l < "${_file}" | tr -d ' ')
  [ "${_pn}" -gt 0 ] || return 0
  printf '  异常路径（%s %d 项）:\n' "${_label}" "${_pn}"
  _pi=0
  while IFS= read -r _pp; do
    [ -n "${_pp}" ] || continue
    _pi=$((_pi + 1))
    if [ "${_pi}" -gt 20 ]; then
      printf '    …（其余 %d 项见保留的快照）\n' "$((_pn - 20))"
      break
    fi
    printf '    %s %s\n' "${_mark}" "${_pp}"
  done < "${_file}"
}

# $1=verify 序号 $2=命令 $3=前快照 $4=后快照
cg_report() {
  _vn=$1
  _vcmd=$2
  _b=$3
  _a=$4
  cg_diff "${_b}" "${_a}"
  printf 'FAIL: verify[%d] 越界改动工作区 %d 项（新增 %d／删除 %d／变更 %d）\n' \
    "${_vn}" "$((cg_added + cg_removed + cg_changed))" "${cg_added}" "${cg_removed}" "${cg_changed}"
  printf '  失败命令: %s\n' "${_vcmd}"
  cg_print_paths '新增' "${work_dir}/p_added" '+'
  cg_print_paths '删除' "${work_dir}/p_removed" '-'
  cg_print_paths '变更' "${work_dir}/p_changed" '~'
  printf '  前后状态差异（前 -／后 +）:\n'
  comm -23 "${_b}" "${_a}" | sed 's/^/    - /' | head -n 20
  comm -13 "${_b}" "${_a}" | sed 's/^/    + /' | head -n 20
  printf '  现场保留: 异常路径不自动删除、不回滚；前后快照保留于 %s\n' "${work_dir}"
}
