#!/bin/sh
# Input: check_7 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 7（no-root-governance）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 7：根治理文件不在包内（AGENTS.md、$docs_dir、$rules_dir、$facts_dir、.zcode/——
# 票 113 波④：rules/、facts/ 为新布局治理面，包内禁出现目标录像 docs/ 旧形态）。

check_7() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
gov_found=''
if [ -e "$pkg_root/AGENTS.md" ]; then
  gov_found='AGENTS.md（文件）'
fi
if [ -d "$pkg_root/$docs_dir" ]; then
  gov_found="$gov_found $docs_dir/（目录）"
fi
if [ -d "$pkg_root/$rules_dir" ]; then
  gov_found="$gov_found $rules_dir/（目录）"
fi
if [ -d "$pkg_root/$facts_dir" ]; then
  gov_found="$gov_found $facts_dir/（目录）"
fi
if [ -d "$pkg_root/.zcode" ]; then
  gov_found="$gov_found .zcode/（目录）"
fi
if [ -n "$gov_found" ]; then
  add_problem "包根存在：$gov_found"
  _chk_desc='根治理文件不在包内'
else
  _chk_desc='根治理文件不在包内'
fi

:
}
