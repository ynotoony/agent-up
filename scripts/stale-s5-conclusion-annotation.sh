#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S5（方案结论标注句）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s5（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

# ---- S5 方案结论标注句（票 85）------------------------------------------------
#
# R-DP-033 加固配套格式断言：调研/对比产出的结论行逐条标注证据出处与适用轨。
# 只查格式不判语义——标注的出处是否真支撑结论归独立评审（合同 Forbidden）。
#
# 扫描面 glob 清单（唯一承载点；条文同步登记于 R-DP-033，扩面两处同步改，禁静默
# 扩面——票 78 词表教训）：每行一条「<目录>/*.md」形态，单层语义（目录直属 .md）；
# 病态形态（路径含空白/冒号、非 ASCII 引号转义路径）不受理（对齐 S4 已知限制）。
# 结论行识别规则（登记防误扫）：行首（允许前置空白与一个「- 」列表标记）以「结论：」
# 起始的行；非此形态零命中即零报。
# 适用轨受控词表：本仓自用 | agent-up（两值；未来多产品轨预留登记机制，不扩展实现）。

s5_load_globs() {
  printf '%s\n' "$s5_scan_glob"
}

s5_track_pat='轨:(本仓自用|agent-up)'
s5_line_pat='^[[:space:]]*(-[[:space:]]+)?结论：'

check_s5() {
  # S5：扫描面文件 ∩ 工作区新增/修改面（git status --porcelain 判定）→ 结论行逐行
  # 核对 file: 出处与轨:标注；缺任一 emit_stale 指名 file:line（计入过期断言计数）。
  _s5_globs=$(s5_load_globs)
  [ -n "$_s5_globs" ] || return 0
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn S5 "$s5_scan_glob" 'S5 结论标注断言跳过：目标当前不是 Git 工作区，新增/修改面无法判定，按流程退化语义跳过（对齐 S1）'
    return 0
  fi
  _s5_changed=$(git -C "$repo_root" -c core.quotePath=off status --porcelain --untracked-files=all 2>/dev/null) || _s5_changed=''
  [ -n "$_s5_changed" ] || return 0
  for _s5_g in $_s5_globs; do
    case $_s5_g in
      */*.md) _s5_dir=${_s5_g%/*.md} ;;
      *)
        printf 'check-stale-claims: 错误：S5 扫描面 glob 登记破坏（须「<目录>/*.md」形态）：%s\n' "$_s5_g" >&2
        return 2
        ;;
    esac
    for _s5_line in $_s5_changed; do
      [ -n "$_s5_line" ] || continue
      _s5_path=${_s5_line#?? }
      case $_s5_path in
        *' -> '*) _s5_path=${_s5_path##* -> } ;;  # 改名条目取新路径
      esac
      case $_s5_path in
        "$_s5_dir"/*) ;;
        *) continue ;;
      esac
      _s5_base=${_s5_path#"$_s5_dir"/}
      case $_s5_base in
        *.md) ;;
        *) continue ;;
      esac
      case $_s5_base in
        */*) continue ;;  # 单层语义：子目录直属面外不扫（glob 登记语义）
      esac
      [ -f "$repo_root/$_s5_path" ] || continue
      _s5_hits=$(LC_ALL=C grep -nE "$s5_line_pat" "$repo_root/$_s5_path" 2>/dev/null) || _s5_hits=''
      [ -n "$_s5_hits" ] || continue
      while IFS= read -r _s5_hit; do
        [ -n "$_s5_hit" ] || continue
        _s5_ln=${_s5_hit%%:*}
        _s5_txt=${_s5_hit#*:}
        _s5_miss=''
        case $_s5_txt in
          *file:*) : ;;
          *) _s5_miss='证据出处（file:）' ;;
        esac
        if ! printf '%s\n' "$_s5_txt" | LC_ALL=C grep -qE "$s5_track_pat"; then
          if [ -n "$_s5_miss" ]; then
            _s5_miss="${_s5_miss}、适用轨（轨:本仓自用|agent-up）"
          else
            _s5_miss='适用轨（轨:本仓自用|agent-up）'
          fi
        fi
        [ -n "$_s5_miss" ] || continue
        emit_stale "$_s5_path:$_s5_ln" "结论行缺标注（S5，票 85）：缺${_s5_miss}——按 R-DP-033 逐条标注（只查格式不判语义）"
      done <<S5_HITS_INNER
$_s5_hits
S5_HITS_INNER
    done
  done
  return 0
}
