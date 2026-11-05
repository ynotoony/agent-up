#!/bin/sh
# Input: check_6 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 6（contract-headers）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 6：文本契约头齐全。*.md 与 *.tmpl 在检测窗口内须含 Input:/Output:/Pos: 三行；
# 例外（登记见 README.md 与 schemas/README.md、templates/README.md）：
#   - artifacts-yaml.tmpl 以 YAML # 注释承载（前 5 行含 # Input:/# Output:/# Pos:）；
#   - LICENSE 与 schemas/*.json 不在 *.md/*.tmpl 范围内，自然豁免。

check_6() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
header_missing=''
sep=''
OLDIFS=$IFS
IFS='
'
for f in $file_list; do
  case $f in
    */artifacts-yaml.tmpl)
      win=$(head -n 5 "$f")
      m_in='# Input:'
      m_out='# Output:'
      m_pos='# Pos:'
      ;;
    */delivery-rules.tmpl)
      win=$(head -n 5 "$f")
      m_in='# Input:'
      m_out='# Output:'
      m_pos='# Pos:'
      ;;
    *)
      win=$(header_window "$f")
      m_in='Input:'
      m_out='Output:'
      m_pos='Pos:'
      ;;
  esac
  miss=''
  case $win in
    *"$m_in"*) ;;
    *) miss='Input' ;;
  esac
  case $win in
    *"$m_out"*) ;;
    *) miss="${miss:+$miss }Output" ;;
  esac
  case $win in
    *"$m_pos"*) ;;
    *) miss="${miss:+$miss }Pos" ;;
  esac
  if [ -n "$miss" ]; then
    header_missing="$header_missing$sep  - ${f#"${pkg_root}/"} 缺 $miss"
    sep='
'
  fi
done
IFS=$OLDIFS
if [ -n "$header_missing" ]; then
  add_problem "$header_missing"
  _chk_desc='文本契约头齐全（*.md 与 *.tmpl）'
else
  _chk_desc='文本契约头齐全（*.md 与 *.tmpl）'
fi
:
}
