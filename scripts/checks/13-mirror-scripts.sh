#!/bin/sh
# Input: check_13 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_mirror
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 13（mirror-scripts）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 13：镜像脚本与仓根同名件一致（票 58 新增；跨树同名脚本所有权三分类，登记域＝
# 清单 mirrors 节 pm_mirror <文件名> <所有权> 两参数行）。三分类语义：
#   mirror        包侧 $scripts_dir/<名> 与仓侧同名件（$scripts_dir/ 与
#                 rules/implementation/scripts/ 两落位任一在场）互为镜像，逐对 cmp，
#                 byte 差异即 FAIL 指名；仓侧两落位皆无同名件即 FAIL（镜像登记悬空）。
#   package-only  包侧为唯一维护权威，不 cmp；包侧缺件由检查 8 指名本项不重复报；仓侧
#                 同名实例在场属待升级流程同步的过渡态（升级主链见 references/upgrade.md），
#                 不判差异不判存在。
#   repo-only     仅仓侧存在、包侧明确不收录：包内出现同名件即 FAIL（防未决策采纳）；
#                 仓侧两落位皆无同名件即 FAIL（登记悬空）。
# 票 123 增补（源仓倒挂拦截）保留：仓侧落位形态两处探测（旧 $scripts_dir/ 与新布局
# rules/implementation/scripts/）。源仓语境判定＝包根父目录存在两落位目录任一；皆无＝
# 消费项目语境，整项静默跳过无输出行（--pkg-root 参数化语境同口径）。

check_13() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
mirror_compared=0
mirror_root=$(CDPATH='' cd "$pkg_root/.." 2>/dev/null && pwd) || mirror_root=''
mirror_new_dir='rules/implementation/scripts'
in_mirror_ctx=0
if [ -n "$mirror_root" ] && { [ -d "$mirror_root/$scripts_dir" ] || [ -d "$mirror_root/$mirror_new_dir" ]; }; then
  in_mirror_ctx=1
fi
if [ "$in_mirror_ctx" -eq 1 ]; then
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r mrow; do
    IFS=$OLDIFS
    m=${mrow%%"$TAB"*}
    m_own=${mrow#*"$TAB"}
    _m_dst=''
    _m_loc=''
    if [ -n "$mirror_root" ] && [ -f "$mirror_root/$scripts_dir/$m" ]; then
      _m_dst="$mirror_root/$scripts_dir/$m"
      _m_loc="$scripts_dir/$m"
    elif [ -n "$mirror_root" ] && [ -f "$mirror_root/$mirror_new_dir/$m" ]; then
      _m_dst="$mirror_root/$mirror_new_dir/$m"
      _m_loc="$mirror_new_dir/$m"
    fi
    case $m_own in
      mirror)
        if [ ! -f "$pkg_root/$scripts_dir/$m" ]; then
          continue  # 包侧缺件由检查 8 指名，本项不重复报
        fi
        if [ -z "$_m_dst" ]; then
          # 花括号不可省略：全角字符相邻时防止变量名吞并（先例检查 5/12/17）
          add_problem "  - $scripts_dir/$m 登记 mirror 但仓侧两落位皆无同名件（镜像登记悬空，须复核同步或改所有权类别）"
          continue
        fi
        mirror_compared=$((mirror_compared + 1))
        if ! cmp -s "$pkg_root/$scripts_dir/$m" "$_m_dst"; then
          add_problem "  - $scripts_dir/$m 与仓根 $_m_loc 不一致（byte-diff，两处同源演化须互为镜像）"
        fi
        ;;
      package-only)
        : # 包侧缺件由检查 8 指名；不 cmp，仓侧同名实例过渡态不判（升级主链收口）
        ;;
      repo-only)
        if [ -f "$pkg_root/$scripts_dir/$m" ]; then
          add_problem "  - $scripts_dir/$m 登记 repo-only 但包内出现同名件（防未决策采纳，须改登记 mirror 或移除包内侧）"
        fi
        if [ -z "$_m_dst" ]; then
          add_problem "  - $m 登记 repo-only 但仓侧两落位皆无同名件（登记悬空，须复核移除登记或恢复仓侧件）"
        fi
        ;;
    esac
  done < "$pm_mirrors"
  IFS=$OLDIFS
  if [ "$mirror_compared" -gt 0 ] || [ -n "$problems" ]; then
    if [ -n "$problems" ]; then
      _chk_desc="镜像脚本与仓根同名件一致（比对 ${mirror_compared} 对）"
    else
      _chk_desc="镜像脚本与仓根同名件一致（比对 ${mirror_compared} 对）"
    fi
  fi
fi
# 消费项目语境（两落位目录皆无）或零 mirror 类登记且零问题 → 静默跳过，无输出行
:
}
