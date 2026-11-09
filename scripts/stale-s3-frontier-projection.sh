#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S3（frontier 句（投影 vs 索引））；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s3（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S3 frontier 句（投影 vs 索引，票 37 改造） -----------------------------

s3_index_rows() {
  # $1=索引文件；经唯一 JSON 引擎 json rows 逐条目输出 "id|status|updated_at"
  # （键序无关、紧凑与带空格同受理；缺必备字段即返回 1 由调用方报排版破坏）。
  _s3_rows=$(python3 "$_engine" json rows "$1" issues id status updated_at 2>/dev/null) || return 1
  [ -n "$_s3_rows" ] || return 0
  printf '%s\n' "$_s3_rows" | awk -F'\t' '
    { if ($1 == "" || $2 == "" || $3 == "") { bad = 1; next } print $1 "|" $2 "|" $3 }
    END { exit bad ? 1 : 0 }
  '
}

s3_projection_rows() {
  # $1=投影文件；输出状态表每行 "id|status|updated_at"（跳过表头与分隔行）。
  awk '
    /^\| / {
      if ($0 ~ /^\| id \|/ || $0 ~ /^\| --- /) next
      n = split($0, c, "|")
      if (n < 5) next
      gsub(/^ +| +$/, "", c[2]); gsub(/^ +| +$/, "", c[3]); gsub(/^ +| +$/, "", c[5])
      if (c[2] == "" || c[3] == "" || c[5] == "") { bad = 1; next }
      print c[2] "|" c[3] "|" c[5]
    }
    END { exit bad ? 1 : 0 }
  ' "$1"
}

check_s3() {
  _idx="$repo_root/$issues_index_rel"
  _proj="$repo_root/$progress_current_rel"
  _gen=''
  if [ -f "$script_dir/generate-progress.sh" ] && [ -r "$script_dir/generate-progress.sh" ]; then
    _gen="$script_dir/generate-progress.sh"
  elif [ -f "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ] && [ -r "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ]; then
    _gen="$repo_root/$repo_scripts_dir_rel/generate-progress.sh"
  fi

  if [ -n "$_gen" ]; then
    # 优先路径：调用生成器 --check（生成器独占写口径下的一致性权威判定）。
    _grc=0
    sh "$_gen" --check "$repo_root" >/dev/null 2>&1 || _grc=$?
    case $_grc in
      0) : ;;
      1) emit_stale "$progress_current_rel" "投影与索引不一致或投影缺失（generate-progress --check exit 1）——运行生成器刷新投影（$progress_current_rel 为 Derived，生成器独占写）" ;;
      2) emit_stale "$issues_index_rel" '索引缺失、不可读或条目行不合预期（generate-progress --check exit 2）——真相源排版须修复或登记条目重新核对' ;;
      *) emit_stale "$progress_current_rel" "投影一致性核对异常（generate-progress --check exit ${_grc}）——人工核对生成器输出" ;;
    esac
    return 0
  fi

  # 退化路径：生成器不可用 → 内建最小比对（id/status/updated_at 三元组）并输出说明。
  printf 'NOTE: %s — 生成器 generate-progress.sh 不可用（脚本同目录与仓库 %s/ 均未找到），S3 退化为内建最小比对（id/status/updated_at 三元组；checkpoint_ref 等列不参与）\n' "$issues_index_rel" "$repo_scripts_dir_rel"
  if [ ! -f "$_idx" ]; then
    emit_stale "$issues_index_rel" '登记的权威位置失效：索引文件不存在（票状态真相源缺失）'
    return 0
  fi
  if [ ! -f "$_proj" ]; then
    emit_stale "$progress_current_rel" '现役状态投影缺失——运行生成器落盘（generate-progress.sh，Derived 生成器独占写）'
    return 0
  fi
  _a=$(s3_index_rows "$_idx") || {
    emit_stale "$issues_index_rel" '索引条目行缺必备字段（id/status/updated_at）或不合一条目一行排版——真相源排版须修复或登记条目重新核对'
    return 0
  }
  _b=$(s3_projection_rows "$_proj") || {
    emit_stale "$progress_current_rel" '投影状态表行缺字段或不含任何状态表行——投影损坏，运行生成器重建'
    return 0
  }
  if [ "$(printf '%s\n' "$_a" | LC_ALL=C sort)" != "$(printf '%s\n' "$_b" | LC_ALL=C sort)" ]; then
    emit_stale "$progress_current_rel" "投影与索引不一致（最小比对 id/status/updated_at 三元组存在差异）——运行生成器刷新投影；与 $issues_index_rel 冲突时以索引为准"
  fi
}
