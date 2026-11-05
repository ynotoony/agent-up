#!/bin/sh
# Input: check_13 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_mirror
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 13（mirror-scripts）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 13：镜像生成物与包侧源一致（票 276 重开治理决定：包侧 agent-up/scripts/ 为唯一
# 手写源，仓侧 rules/implementation/scripts/ 下同名件为生成物）。登记面＝清单 mirrors 节
# pm_mirror <文件名> <类别> 两参数行；mirror＝该件须由包侧源生成（仓侧生成物存在且与
# 包侧源 byte 全等；缺件/漂移即 FAIL 指名，修复入口＝scripts/generate-mirrors.sh）；
# package-only＝包侧独有，不生成不核对（仓侧同名实例非生成物，本项不判差异不判存在）。
# 源仓语境判定＝包根父目录存在 rules/implementation/scripts/；不存在＝消费项目语境，
# 整项静默跳过无输出行（--pkg-root 参数化语境同口径）。包侧源缺失由检查 8 指名，本项
# 不重复报；生成物缺失或漂移只报单点，不连带其他件。

check_13() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
mirror_checked=0
mirror_root=$(CDPATH='' cd "$pkg_root/.." 2>/dev/null && pwd) || mirror_root=''
mirror_new_dir='rules/implementation/scripts'
in_mirror_ctx=0
if [ -n "$mirror_root" ] && [ -d "$mirror_root/$mirror_new_dir" ]; then
  in_mirror_ctx=1
fi
if [ "$in_mirror_ctx" -eq 1 ]; then
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r mrow; do
    IFS=$OLDIFS
    m=$(printf '%s' "$mrow" | cut -f1 -d"$TAB")
    m_own=$(printf '%s' "$mrow" | cut -f2 -d"$TAB")
    case $m_own in
      mirror)
        if [ ! -f "$pkg_root/$scripts_dir/$m" ]; then
          add_problem "  - $scripts_dir/$m 登记 mirror 但包侧手写源缺失（补件或撤册；生成物不得手工编辑）"
          continue
        fi
        mirror_checked=$((mirror_checked + 1))
        if [ ! -f "$mirror_root/$mirror_new_dir/$m" ]; then
          add_problem "  - $mirror_new_dir/$m 生成物缺失（由 $scripts_dir/generate-mirrors.sh 从包侧源生成）"
        elif ! cmp -s "$pkg_root/$scripts_dir/$m" "$mirror_root/$mirror_new_dir/$m"; then
          add_problem "  - $mirror_new_dir/$m 与包侧 $scripts_dir/$m 不一致（生成物漂移，重跑 $scripts_dir/generate-mirrors.sh）"
        fi
        ;;
      package-only)
        :
        ;;
    esac
  done < "$pm_mirrors"
  IFS=$OLDIFS
  if [ "$mirror_checked" -gt 0 ] || [ -n "$problems" ]; then
    if [ -n "$problems" ]; then
      _chk_desc="镜像生成物与包侧源一致（核对 $mirror_checked 件）"
    else
      _chk_desc="镜像生成物与包侧源一致（核对 $mirror_checked 件）"
    fi
  fi
fi
# 消费项目语境（仓侧无 rules/implementation/scripts/）→ 整项静默跳过，无输出行
:
}
