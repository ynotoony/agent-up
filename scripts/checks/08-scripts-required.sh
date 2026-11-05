#!/bin/sh
# Input: check_8 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_script
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 8（scripts-required）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 8：脚本必需件存在（清单 scripts 节逐行，票 57 数据驱动；kind 区分普通脚本/规则
# 表/test-harness，口径差定谳＝test-record-layer.sh 定为必需件；票 48 fail-closed 守卫：
# 任一缺失即 FAIL 并逐件指名，不因部分存在而放宽）。
# 票 177：worktree 环境豁免 main-only 脚本检查（delivery.rules dp_mainonly 清单），
# 主检出保持原有检查（仍检测全部 scripts 节登记件）。

check_8() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
n_scripts=$(wc -l < "$pm_scripts" | tr -d ' ')
missing_scripts=''
sep=''

if [ "$in_worktree" -eq 1 ]; then
  _chk_skip='脚本必需件存在（worktree 环境，跳过 main-only 脚本检查）'
  # worktree 环境：检查非 main-only 脚本
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r row; do
    rel=${row%%"$TAB"*}
    # 判断是否为 main-only 脚本（delivery.rules 路径含 agent-up/ 前缀，需匹配 scripts/ 相对路径）
    is_mainonly=0
    for mo in $mainonly_list; do
      # mo 形如 agent-up/scripts/export-payload.sh，rel 形如 scripts/export-payload.sh
      # 匹配时去掉 agent-up/ 前缀
      mo_rel="${mo#agent-up/}"
      if [ "$rel" = "$mo_rel" ]; then
        is_mainonly=1
        break
      fi
    done
    if [ "$is_mainonly" -eq 0 ] && [ ! -f "$pkg_root/$rel" ] && [ ! -d "$pkg_root/$rel" ]; then
      missing_scripts="$missing_scripts$sep  - $rel"
      sep='
'
    fi
  done < "$pm_scripts"
  IFS=$OLDIFS
  if [ -n "$missing_scripts" ]; then
    add_problem "$missing_scripts"
    _chk_desc="脚本必需件存在（${n_scripts} 个文件，worktree 跳过 main-only）"
  else
    _chk_desc="脚本必需件存在（${n_scripts} 个文件，worktree 跳过 main-only）"
  fi
else
  # 主检出：检查全部 scripts 节登记件
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r row; do
    rel=${row%%"$TAB"*}
    if [ ! -f "$pkg_root/$rel" ] && [ ! -d "$pkg_root/$rel" ]; then
      missing_scripts="$missing_scripts$sep  - $rel"
      sep='
'
    fi
  done < "$pm_scripts"
  IFS=$OLDIFS
  if [ -n "$missing_scripts" ]; then
    add_problem "$missing_scripts"
    _chk_desc="脚本必需件存在（${n_scripts} 个文件）"
  else
    _chk_desc="脚本必需件存在（${n_scripts} 个文件）"
  fi
fi
:
}
