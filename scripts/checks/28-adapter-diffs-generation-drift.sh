#!/bin/sh
# Input: check_28 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_adapter,pm_adapter_cap,pm_adapter_dialect,pm_adapter_exec,pm_adapter_role
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 28（adapter-diffs-generation-drift）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 28：宿主差异段生成漂移（票 223 新增）。链路＝数据表 → 生成器渲染 → 渲染输出 ≡
# 宿主对应段。渲染器＝同目录 generate-adapter-diffs.sh（--check 模式；数据表四节机器
# 数据行 → Markdown 差异段），比对口径＝逐字节（含行内代码反引号等强调记号，数据表字段
# 原样承载）：cap/role 段渲染行与宿主对应段只去首尾空白、按三列取单元格后逐行逐字节 cmp
# （行序敏感，不剥反引号），exec/dialect 段锚语原文在场断言。与检查 27 的分工：27 断言
# 「数据表 ≡ 文档」（宽松口径＝两侧同剥反引号后全等），28 断言「经生成器渲染 ≡ 文档」
# （严格口径＝含强调记号逐字节一致，证明生成链路无损复现现行文档）；两者同批同步即
# 表/文档/渲染三方一致，且 28 额外兜住「强调记号单侧丢失」。漂移即 FAIL 指名宿主文件
# 与段；生成器缺件或数据面不合预期同样 FAIL（缺件另由检查 8 报）。

check_28() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n28_hosts=$(wc -l < "$pm_adapters" | tr -d ' ')
n28_cap=$(wc -l < "$pm_adcap" | tr -d ' ')
n28_role=$(wc -l < "$pm_adrole" | tr -d ' ')
n28_exec=$(wc -l < "$pm_adexec" | tr -d ' ')
n28_dial=$(wc -l < "$pm_addial" | tr -d ' ')
a28_out=''
if a28_out=$(sh "$script_dir/generate-adapter-diffs.sh" --pkg-root "$pkg_root" --check 2>&1); then
  _chk_desc="宿主差异段生成漂移零差异（宿主 ${n28_hosts} 个，cap ${n28_cap} 行，role ${n28_role} 行，exec ${n28_exec} 行，dialect ${n28_dial} 行）"
else
  add_problem "$a28_out"
  _chk_desc="宿主差异段生成漂移（宿主 ${n28_hosts} 个，cap ${n28_cap} 行，role ${n28_role} 行，exec ${n28_exec} 行，dialect ${n28_dial} 行）"
fi
:
}
