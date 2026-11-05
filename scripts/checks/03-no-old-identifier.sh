#!/bin/sh
# Input: check_3 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 3（no-old-identifier）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 3：包内无旧标识残留（模式运行时为完整旧 Skill 标识字面量，见 README.md）。

check_3() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
old_id='project-ini'"t"
hits=$(grep -rn -e "$old_id" "$pkg_root" 2>/dev/null || true)
if [ -n "$hits" ]; then
  add_problem "$hits"
  _chk_desc='包内无旧标识残留'
else
  _chk_desc='包内无旧标识残留'
fi
:
}
