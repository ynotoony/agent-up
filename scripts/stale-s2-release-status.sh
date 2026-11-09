#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S2（发布状态句）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s2（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S2 发布状态句 ---------------------------------------------------------

check_s2() {
  _rf="$repo_root/$readme_rel"
  _kf="$repo_root/$pkg_readme_rel"
  _rline=$(first_grep_line '公开包已发布' "$_rf")
  if [ -z "$_rline" ]; then
    emit_stale "$readme_rel" '登记的权威位置失效：找不到「公开包已发布」宣称行，登记表条目须重新核对'
    return 0
  fi
  _rloc="$readme_rel:$(printf '%s' "$_rline" | sed 's/:.*//')"
  _claim=$(printf '%s' "$_rline" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ -z "$_claim" ]; then
    emit_stale "$_rloc" '发布宣称行内未提取到仓库地址，断言锚点失效'
    return 0
  fi

  # 发布远端名自 delivery.rules dp_payload_remote 读取（票 72 配置点亮；
  # 未声明 payload 节＝remote 名不可知，退化 WARN 跳过不硬猜）
  if [ -z "$DP_REMOTE" ]; then
    emit_warn S2 "$_rloc" 'S2 remote 比对跳过：delivery.rules 未声明 payload 节（发布远端名不可知）'
  else
    _actual=$(git -C "$repo_root" config --get "remote.$DP_REMOTE.url" 2>/dev/null || true)
    if [ -z "$_actual" ]; then
      emit_stale "$_rloc" "发布句宣称已发布至 ${_claim}，但本仓库未配置 remote ${DP_REMOTE}"
    elif [ "$(trim_git_url "$_actual")" != "$_claim" ]; then
      emit_stale "$_rloc" "发布句宣称地址 $_claim 与实际 remote ${DP_REMOTE} $(trim_git_url "$_actual") 不一致"
    fi
  fi

  # 安装命令行与发布宣称同源核对（包内 README 的克隆地址与宣称一致；包前缀自
  # delivery.rules dp_payload_root 派生，未声明＝位置不可知，退化 WARN 跳过）
  if [ -z "$pkg_readme_rel" ]; then
    emit_warn S2 "$_rloc" 'S2 安装行同源核对跳过：delivery.rules 未声明 payload 节（包内 README 位置不可知）'
  elif [ -f "$_kf" ]; then
    _kline=$(first_grep_line "$_claim" "$_kf")
    if [ -z "$_kline" ]; then
      emit_stale "$pkg_readme_rel" "包内安装说明未找到与发布句一致的地址 $_claim"
    fi
  else
    emit_stale "$pkg_readme_rel" '登记的次级权威位置文件不存在'
  fi

  # 远端可达性与可见性本地不可核验（不出网）→ 存在时长提醒
  emit_warn S2 "$_rloc" "远端仓库可达性与 public 可见性本地不核验（零网络依赖），请按登记周期人工复核宣称：$_claim"
}
