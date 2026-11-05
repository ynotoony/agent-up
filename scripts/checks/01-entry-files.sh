#!/bin/sh
# Input: check_1 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_entry
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 1（entry-files）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 1：必需入口存在（清单 entry-files 节逐行，票 57 数据驱动；对照 SPEC-06 §2 目标
# 结构与票 09 Checkpoint 清单）。

check_1() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
n_entries=$(wc -l < "$pm_entries" | tr -d ' ')
missing_entries=''
sep=''
while IFS= read -r rel; do
  if [ ! -f "$pkg_root/$rel" ]; then
    missing_entries="$missing_entries$sep  - $rel"
    sep='
'
  fi
done < "$pm_entries"
if [ -n "$missing_entries" ]; then
  add_problem "$missing_entries"
  _chk_desc="必需入口存在（${n_entries} 个文件）"
else
  _chk_desc="必需入口存在（${n_entries} 个文件）"
fi
:
}
