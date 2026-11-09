#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S1（Git 状态句）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s1（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S1 Git 状态句 ---------------------------------------------------------

check_s1() {
  _pf="$repo_root/$progress_rel"
  _anchor=$(first_grep_line 'Git 恢复基线' "$_pf")
  if [ -z "$_anchor" ]; then
    emit_stale "$progress_rel" '登记的权威位置失效：找不到「Git 恢复基线」块，登记表条目须重新核对'
    return 0
  fi
  _loc="$progress_rel:$(printf '%s' "$_anchor" | sed 's/:.*//')"

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn S1 "$_loc" '目标当前不是 Git 工作区，Git 状态句条目按流程退化语义跳过（对齐 development-process 例外条款）'
    return 0
  fi

  # 1a 基线块宣称的首个提交存在
  # shellcheck disable=SC2016  # sed/awk 程序刻意字面 $（引号形态由程序语义决定；wiki 长尾误报）
  _sha=$(printf '%s' "$_anchor" | sed -n 's/.*首个提交 `\([0-9a-f][0-9a-f]*\)`.*/\1/p')
  if [ -n "$_sha" ]; then
    if ! git -C "$repo_root" cat-file -e "$_sha" >/dev/null 2>&1; then
      emit_stale "$_loc" "基线块宣称首个提交 $_sha 存在，但对象库中找不到该提交"
    fi
  else
    emit_warn S1 "$_loc" '基线块内未提取到首个提交短 SHA，提交存在性未核验'
  fi

  # 1b 基线块宣称的本地导出分支存在（分支名自 delivery.rules dp_payload_local_ref 读取，
  # 票 72 配置点亮；未声明 payload 节＝分支名不可知，退化 WARN 跳过不硬猜）
  if [ -n "$DP_LOCAL_REF" ]; then
    if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$DP_LOCAL_REF"; then
      emit_stale "$_loc" "基线块宣称本地导出分支 $DP_LOCAL_REF 存在，但该分支引用不存在"
    fi
  else
    emit_warn S1 "$_loc" 'S1-1b 本地导出分支核对跳过：delivery.rules 未声明 payload 节（分支名不可知）'
  fi

  # 1c 基线块宣称的唯一 remote 与地址（remote 名自 delivery.rules dp_payload_remote 读取，
  # 票 72 配置点亮；未声明 payload 节＝remote 名不可知，退化 WARN 跳过不硬猜）
  _remotes=$(git -C "$repo_root" remote || true)
  _claim_url=$(printf '%s' "$_anchor" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ -z "$DP_REMOTE" ]; then
    emit_warn S1 "$_loc" 'S1-1c 唯一 remote 核对跳过：delivery.rules 未声明 payload 节（remote 名不可知）'
  elif [ "$_remotes" != "$DP_REMOTE" ]; then
    emit_stale "$_loc" "基线块宣称唯一 remote 为 ${DP_REMOTE}，实际 remote 列表为：${_remotes:-（空）}"
  else
    _actual=$(git -C "$repo_root" config --get "remote.$DP_REMOTE.url" || true)
    if [ -z "$_actual" ]; then
      emit_stale "$_loc" "基线块宣称 remote $DP_REMOTE 已配置，但未取到其地址"
    elif [ -n "$_claim_url" ] && [ "$(trim_git_url "$_actual")" != "$_claim_url" ]; then
      emit_stale "$_loc" "基线块宣称 remote 地址 ${_claim_url}，实际为 $(trim_git_url "$_actual")"
    fi
  fi

  # 1d 基线块宣称本地 main 未推送到远端（本地只读判定：main 未被任何远端跟踪分支包含）
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
    _contained=$(git -C "$repo_root" branch -r --contains main 2>/dev/null || true)
    if [ -n "$_contained" ]; then
      emit_stale "$_loc" '基线块宣称本地 main 未推送，但该提交已包含于远端跟踪分支'
    fi
  else
    emit_warn S1 "$_loc" '本地 main 分支不存在，未推送断言未核验'
  fi

  # 1e（已移除，票 37）：基线块"存在未提交工作区改动"为票 13 时点历史快照，
  # progress.md 现为冻结历史档案（零写入），清洁工作区属稳态——逐字核对恒触发误报
  # （S1-1e 已知缺口，1080560 补记在案），不再作为活断言核对。
}
