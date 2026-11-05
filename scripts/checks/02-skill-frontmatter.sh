#!/bin/sh
# Input: check_2 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 2（skill-frontmatter）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 2：SKILL.md frontmatter 为 name: agent-up。

check_2() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
if [ ! -f "$pkg_root/SKILL.md" ]; then
  add_problem 'SKILL.md 不存在'
  _chk_desc='SKILL.md frontmatter 为 name: agent-up'
elif awk '
  NR == 1 { ok = ($0 == "---"); next }
  ok && !closed {
    if ($0 == "---") closed = 1
    else if ($0 ~ /^name: agent-up$/) found = 1
  }
  END { if (ok && closed && found) exit 0; exit 1 }
' "$pkg_root/SKILL.md"; then
  _chk_desc='SKILL.md frontmatter 为 name: agent-up'
else
  add_problem 'frontmatter 缺失、未闭合或不含 name: agent-up 行'
  _chk_desc='SKILL.md frontmatter 为 name: agent-up'
fi
:
}
