#!/bin/sh
# Input: check_29 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_legacy_marker,pm_retired_face,pm_retired_token
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 29（retired-path-activity）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 29：退役能力不在活动创建路径（票 219 新增；207 交付面核对）。退役 token（清单
# retired-path 节）在活动创建路径面（同节 face 登记，目录行递归取 *.md/*.tmpl）内出现
# 时，同行须带显式 legacy 标注词（退役/legacy/retired）；缺失即 FAIL 指名文件:行号、
# token 与冲突类型——活动创建路径不得再提供退役能力，历史事实须显式标注为 legacy。
# 数据驱动（引擎零 token 零标注词硬编码）；面缺失 FAIL，扫描器异常 exit 2。

check_29() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n29_faces=0
n29_hits=0
retired_toks=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_retired")
legacy_marks=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_legmark")
r29_files=$(mktemp "${t_dir%/}/retired29.XXXXXX")
while IFS= read -r r29_row; do
  [ -n "$r29_row" ] || continue
  n29_faces=$((n29_faces + 1))
  if [ -d "$pkg_root/$r29_row" ]; then
    (cd "$pkg_root" && find "$r29_row" -type f \( -name '*.md' -o -name '*.tmpl' \) 2>/dev/null) >> "$r29_files" || true
  elif [ -f "$pkg_root/$r29_row" ]; then
    printf '%s\n' "$r29_row" >> "$r29_files"
  else
    add_problem "  - $r29_row 冲突类型=活动面缺失（规则 retired-path · 登记面不存在）"
  fi
done < "$pm_retface"
LC_ALL=C sort -u "$r29_files" -o "$r29_files"
r29_hits=$(mktemp "${t_dir%/}/retired29.XXXXXX")
OLDIFS=$IFS
IFS='
'
while IFS= read -r r29_f; do
  IFS=$OLDIFS
  [ -n "$r29_f" ] || continue
  [ -f "$pkg_root/$r29_f" ] || continue
  awk_rc=0
  LC_ALL=C TOKS="$retired_toks" MARKS="$legacy_marks" awk -v rel="$r29_f" '
    BEGIN { nt = split(ENVIRON["TOKS"], T, "\n"); nm = split(ENVIRON["MARKS"], M, "\n") }
    {
      hit = ""
      for (i = 1; i <= nt; i++) if (T[i] != "" && index($0, T[i]) > 0) { hit = T[i]; break }
      if (hit == "") next
      okm = 0
      for (i = 1; i <= nm; i++) if (M[i] != "" && index($0, M[i]) > 0) { okm = 1; break }
      if (!okm) printf "%s:%d\t%s\n", rel, FNR, hit
    }
  ' "$pkg_root/$r29_f" >> "$r29_hits" || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 29 扫描器异常（awk exit %s）: %s\n' "$awk_rc" "$r29_f" >&2
    exit 2
  fi
done < "$r29_files"
rm -f "$r29_files"
IFS=$OLDIFS
while IFS="$(printf '\t')" read -r r29_loc r29_tok; do
  [ -n "$r29_loc" ] || continue
  n29_hits=$((n29_hits + 1))
  add_problem "  - $r29_loc 冲突类型=退役能力仍在活动创建路径（规则 retired-path · token「${r29_tok}」无 legacy 标注）"
done < "$r29_hits"
rm -f "$r29_files" "$r29_hits"
if [ -n "$problems" ]; then
  _chk_desc="退役能力不在活动创建路径（面 ${n29_faces} 个，命中 ${n29_hits} 处）"
else
  _chk_desc="退役能力不在活动创建路径（面 ${n29_faces} 个，命中 ${n29_hits} 处）"
fi
:
}
