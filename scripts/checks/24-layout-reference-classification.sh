#!/bin/sh
# Input: check_24 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_layout_compat_exempt,pm_layout_face,pm_layout_legacy_file,pm_layout_universe
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 24（layout-reference-classification）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 24：布局引用分类与失效检测（modern/legacy/compatibility 三分类）。扫描面＝清单
# layout-face 节登记面：目录行递归取 *.md/*.tmpl（排除 README.md 叙事面，检查 12 同款
# 口径），单文件行整件入面。分类口径：
#   legacy        ＝清单 layout-legacy-file 节登记文件（旧项目路径手册等票卡定谳的合法
#                   保留件），命中只计数不判罚；
#   compatibility ＝清单 layout-compat-exempt 节登记行（路径＋行号＋理由，显式兼容豁免，
#                   非隐式忽略；登记行无命中即失效豁免 FAIL，检查 12/18 同款防漂移口径）；
#   modern        ＝其余命中：旧布局路径 token（docs/<path> 或 development-process，前邻
#                   字符禁「/」与字母数字点连字符，避开 code.claude.com/docs/ 等外部 URL
#                   形态）即 FAIL 指名文件:行号与命中 token。
# ②modern 相对链接解析＝面内 *.tmpl 的 ](target) 行内链接：目标剥锚点与前导 ./ 后落
#   rules/ 或 facts/（modern 布局）时须 ∈ 生成布局全集（清单 layout-universe 节登记模板
#   按锚点提取的路径行并集，数据驱动）。与检查 21③ 关系（实证定谳）：21③ 对包内 *.md
#   行内链接按包内树判定存在性，不适用于模板生成物相对链接（生成目标是消费项目布局）；
#   modern 生成布局目标解析为其正交补面，故立本检查项而非泛化 21③；*.md 内行内链接
#   存在性仍归 21③，本项不重复。

check_24() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n24_face=0
n24_mod=0
n24_legacy=0
n24_compat=0
n24_links=0
n24_modlines=''
layout24_files=$(mktemp "${t_dir%/}/layout24.XXXXXX")
layout24_hits=$(mktemp "${t_dir%/}/layout24.XXXXXX")
layout24_links=$(mktemp "${t_dir%/}/layout24.XXXXXX")
layout24_univ=$(mktemp "${t_dir%/}/layout24.XXXXXX")
# 面清单组装（face 行＝目录或单文件；登记面不存在即 FAIL，fail-closed 不静默缩面）
while IFS= read -r l24_row; do
  [ -n "$l24_row" ] || continue
  if [ -d "$pkg_root/$l24_row" ]; then
    (cd "$pkg_root" && find "$l24_row" -type f \( -name '*.md' -o -name '*.tmpl' \) ! -name 'README.md' 2>/dev/null) >> "$layout24_files" || true
  elif [ -f "$pkg_root/$l24_row" ]; then
    printf '%s\n' "$l24_row" >> "$layout24_files"
  else
    add_problem "  - layout-face 登记面不存在: $l24_row"
  fi
done < "$pm_layoutface"
LC_ALL=C sort -u "$layout24_files" -o "$layout24_files"
n24_face=$(wc -l < "$layout24_files" | tr -d ' ')
# ①失效引用扫描（逐面文件 grep -noE，命中行落 <rel>:<ln>:<match>）
layout24_pat='(^|[^/A-Za-z0-9._-])(docs/[A-Za-z0-9._/-]+|development-process)'
OLDIFS=$IFS
IFS='
'
while IFS= read -r l24_f; do
  IFS=$OLDIFS
  [ -n "$l24_f" ] || continue
  LC_ALL=C grep -noE "$layout24_pat" "$pkg_root/$l24_f" 2>/dev/null \
    | sed "s|^|$l24_f:|" >> "$layout24_hits" || true
done < "$layout24_files"
IFS=$OLDIFS
# 命中三分类
while IFS= read -r l24_h; do
  [ -n "$l24_h" ] || continue
  l24_rel=${l24_h%%:*}
  l24_rest=${l24_h#*:}
  l24_ln=${l24_rest%%:*}
  l24_m=${l24_rest#*:}
  case $l24_m in
    docs/*|development-process*) l24_tok=$l24_m ;;
    *) l24_tok=${l24_m#?} ;;
  esac
  if LC_ALL=C awk -F'\t' -v p="$l24_rel" 'BEGIN { ok = 0 } $1 == p { ok = 1 } END { exit ok ? 0 : 1 }' "$pm_layoutlf"; then
    n24_legacy=$((n24_legacy + 1))
    continue
  fi
  if grep -qF "$(printf '%s\t%s\t' "$l24_rel" "$l24_ln")" "$pm_layoutce"; then
    n24_compat=$((n24_compat + 1))
    continue
  fi
  case "
$n24_modlines" in
    *"
$l24_rel:$l24_ln
"*) : ;;
    *)
      n24_modlines="$n24_modlines$l24_rel:$l24_ln
"
      n24_mod=$((n24_mod + 1))
      add_problem "  - $l24_rel:$l24_ln modern 布局面失效引用（分类 modern）: $l24_tok"
      ;;
  esac
done < "$layout24_hits"
# 失效豁免核对：登记行无命中即 FAIL（检查 12/18 同款，防漂移静默失效）
while IFS= read -r l24_crow; do
  [ -n "$l24_crow" ] || continue
  l24_crel=${l24_crow%%"$TAB"*}
  l24_crest=${l24_crow#*"$TAB"}
  l24_cln=${l24_crest%%"$TAB"*}
  if ! LC_ALL=C awk -F':' -v p="$l24_crel" -v l="$l24_cln" '$1 == p && $2 == l { f = 1 } END { exit f ? 0 : 1 }' "$layout24_hits"; then
    add_problem "  - 失效豁免（登记行无 legacy 引用命中，须复核更新或删除登记）: $l24_crel:$l24_cln"
  fi
done < "$pm_layoutce"
# ②modern 相对链接解析（面内 *.tmpl；生成布局全集提取与链接核对）
while IFS= read -r l24_urow; do
  [ -n "$l24_urow" ] || continue
  l24_usrc=${l24_urow%%"$TAB"*}
  l24_uanchor=${l24_urow#*"$TAB"}
  if [ ! -f "$pkg_root/$l24_usrc" ]; then
    add_problem "  - layout-universe 登记模板不存在: $l24_usrc"
    continue
  fi
  LC_ALL=C sed -n "s/.*$l24_uanchor \([A-Za-z0-9._/-]*\).*/\1/p" "$pkg_root/$l24_usrc" >> "$layout24_univ" || true
done < "$pm_layoutu"
while IFS= read -r l24_f; do
  IFS=$OLDIFS
  [ -n "$l24_f" ] || continue
  case $l24_f in
    *.tmpl) : ;;
    *) continue ;;
  esac
  LC_ALL=C grep -noE '\]\([^)]+\)' "$pkg_root/$l24_f" 2>/dev/null \
    | sed "s|^|$l24_f:|" >> "$layout24_links" || true
done < "$layout24_files"
IFS=$OLDIFS
while IFS= read -r l24_l; do
  [ -n "$l24_l" ] || continue
  l24_lrel=${l24_l%%:*}
  l24_lrest=${l24_l#*:}
  l24_lln=${l24_lrest%%:*}
  l24_lm=${l24_lrest#*:}
  l24_lt=${l24_lm#](}
  l24_lt=${l24_lt%\)}
  case $l24_lt in
    *'://'*|mailto:*|'#'*) continue ;;
  esac
  l24_lt=${l24_lt%%#*}
  [ -n "$l24_lt" ] || continue
  case $l24_lt in
    ./*) l24_lt=${l24_lt#./} ;;
  esac
  case $l24_lt in
    rules/*|facts/*) : ;;
    *) continue ;;
  esac
  n24_links=$((n24_links + 1))
  # 成员判定＝整行精确相等（-x）：子串口径会让 rules/project 误配 rules/project.md
  if ! grep -qsxF -- "$l24_lt" "$layout24_univ"; then
    add_problem "  - $l24_lrel:$l24_lln modern 布局相对链接目标不在生成布局全集（分类 modern）: $l24_lt"
  fi
done < "$layout24_links"
rm -f "$layout24_files" "$layout24_hits" "$layout24_links" "$layout24_univ"
if [ -n "$problems" ]; then
  _chk_desc="布局引用分类与失效检测（面 ${n24_face} 件，modern 失效 ${n24_mod} 处，legacy ${n24_legacy} 处，compatibility ${n24_compat} 处，modern 链接 ${n24_links} 个）"
else
  _chk_desc="布局引用分类与失效检测（面 ${n24_face} 件，modern 失效 ${n24_mod} 处，legacy ${n24_legacy} 处，compatibility ${n24_compat} 处，modern 链接 ${n24_links} 个）"
fi
:
}
