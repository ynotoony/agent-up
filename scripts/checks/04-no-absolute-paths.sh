#!/bin/sh
# Input: check_4 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 4（no-absolute-paths）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 4：无绝对路径与根治理引用。
# 绝对路径前缀模式运行时为“斜杠 + Users/home + 斜杠”（拼接构造避免自命中）；
# 根治理引用只查转义字面量“上级 docs”与“上级 .zcode”（.tmpl 内的兄弟路径语义不在本项口径内，按票 09/11 结论）。

check_4() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
pat_users='/'"Users/"
pat_home='/'"home/"
hits=$(grep -rn \
  -e "$pat_users" \
  -e "$pat_home" \
  -e '\.\./docs' \
  -e '\.\./\.zcode' \
  "$pkg_root" 2>/dev/null || true)
if [ -n "$hits" ]; then
  add_problem "$hits"
  _chk_desc='无绝对路径与根治理引用'
else
  _chk_desc='无绝对路径与根治理引用'
fi
:
}
