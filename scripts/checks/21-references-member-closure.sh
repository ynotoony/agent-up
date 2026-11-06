#!/bin/sh
# Input: check_21 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_entry,pm_template
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 21（references-member-closure）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 21：references 树成员闭合与导航。四段防线：
#   ①references 全树文件 ⊆ 清单登记——find references/ 全部常规文件逐件核对：包根相对
#     路径在清单 entry-files 节，或属 references/templates/ 下 .tmpl 且在 templates 节
#     （检查 5 同源数据，引擎零文件名硬编码）；未登记额外文件（成员增删漏登记、恶意
#     投放、隐藏条目）即 FAIL 指名；references/ 目录缺失一体 FAIL。
#   ②references/README.md 目录清单投影双向——references/ 一级条目（文件与目录）与
#     README「## 目录清单」表首列反引号名单双向全等（表＝人读投影、数据与实物＝机器
#     真相，先例检查 5/9 投影纪律）；一级条目未登记表或表登记无实物均 FAIL 指名；
#     锚点未命中或零成员行判表结构漂移 FAIL。
#   ③包内 Markdown 行内链接目标存在——全部 *.md 的 ](target) 链接：外链（含 :// 与
#     mailto:）与 # 纯锚点不在口径；其余剥离 #锚点 后相对所在文件目录词法折叠（点段
#     折叠，复用检查 20 词法判定形态），目标不存在或折出包根（含绝对路径目标）即 FAIL
#     指名文件:行号与目标（坏相对链接导航防线）。
#   ④目录 README 兜底（票 266）——只读两检：①generate-dir-readmes.sh --check
#     --blocks-only（只校验含生成块的 README 四段结构，旧格式无生成块跳过）；②--freshness
#     （内存重算 --sync 应产出块并逐行比对，漂移即指名缺失／多余行）。两检均不写文件，
#     失败逐条并入本检查问题面；生成器缺失交检查 8 报（不重复）。

link_resolve() {
  # $1=链接目标 $2=所在文件包根相对路径：输出目标相对所在文件目录词法折叠后的包根相对
  # 路径；折出包根（含绝对路径目标）输出 ESCAPE。词法折叠唯一实现＝shared.sh
  # chk_lex_fold（票 286 D4）；词法判定，不展开路径 symlink。
  case $1 in
    /*) printf 'ESCAPE'; return 0 ;;
  esac
  printf '%s' "$(chk_lex_fold "$(dirname "$2")/$1")"
}

check_21() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_ref_files=0
n_links=0
ref_dir="$pkg_root/references"
ref_readme="$ref_dir/README.md"
if [ ! -d "$ref_dir" ]; then
  add_problem '  - references/ 目录不存在'
else
  # ① 全树成员闭合
  unreg=''
  sep2=''
  OLDIFS=$IFS
  IFS='
'
  for _rf in $(find "$ref_dir" -type f | LC_ALL=C sort); do
    IFS=$OLDIFS
    n_ref_files=$((n_ref_files + 1))
    _rf_rel=${_rf#"${pkg_root}/"}
    if grep -qxF "$_rf_rel" "$pm_entries"; then
      continue
    fi
    case $_rf_rel in
      references/templates/*.tmpl)
        if grep -qxF "$(basename "$_rf_rel")" "$pm_templates"; then
          continue
        fi
        ;;
    esac
    unreg="$unreg$sep2$_rf_rel"
    sep2='、'
  done
  IFS=$OLDIFS
  if [ -n "$unreg" ]; then
    add_problem "  - references 全树未登记条目（闭合白名单＝entry-files ∪ templates 节 .tmpl）: $unreg"
  fi
  # ② README 一级投影双向
  if [ ! -f "$ref_readme" ]; then
    add_problem '  - references/README.md（目录清单投影）不存在'
  else
    # shellcheck disable=SC2016  # sed 捕获组 \(...\) 刻意单引号防 shell 展开
    man_names=$(sed -n '/^## 目录清单/,/^## /p' "$ref_readme" | sed -n 's/^[^`]*`\([^`]*\)`.*/\1/p' | sed 's:/*$::' | LC_ALL=C sort -u)
    if [ -z "$man_names" ]; then
      add_problem '  - references/README.md 目录清单表未提取到成员行（表结构漂移）'
    else
      lvl1_names=''
      OLDIFS=$IFS
      IFS='
'
      for _l1 in $(find "$ref_dir" -mindepth 1 -maxdepth 1 | LC_ALL=C sort); do
        IFS=$OLDIFS
        lvl1_names="$lvl1_names${_l1##*/}
"
      done
      IFS=$OLDIFS
      miss_man=''
      sep2=''
      OLDIFS=$IFS
      IFS='
'
      for _n in $lvl1_names; do
        IFS=$OLDIFS
        [ -n "$_n" ] || continue
        if ! printf '%s\n' "$man_names" | grep -qxF "$_n"; then
          miss_man="$miss_man$sep2$_n"
          sep2='、'
        fi
      done
      IFS=$OLDIFS
      if [ -n "$miss_man" ]; then
        add_problem "  - references/ 一级条目未在 README 目录清单登记: $miss_man"
      fi
      miss_disk=''
      sep2=''
      for _n in $man_names; do
        if [ ! -e "$ref_dir/$_n" ]; then
          miss_disk="$miss_disk$sep2$_n"
          sep2='、'
        fi
      done
      if [ -n "$miss_disk" ]; then
        add_problem "  - README 目录清单登记但 references/ 一级无实物: $miss_disk"
      fi
    fi
  fi
fi
# ③ Markdown 行内链接目标存在
link_raw=$(cd "$pkg_root" && grep -rnoE '\]\([^)]+\)' --include='*.md' . 2>/dev/null | sed 's|^\./||') || link_raw=''
if [ -n "$link_raw" ]; then
  OLDIFS=$IFS
  IFS='
'
  for _lh in $link_raw; do
    IFS=$OLDIFS
    _lf=${_lh%%:*}
    _lrest=${_lh#*:}
    _ll=${_lrest%%:*}
    _lm=${_lrest#*:}
    _lt=${_lm#](}
    _lt=${_lt%\)}
    case $_lt in
      *'://'*|mailto:*|'#'*) continue ;;
    esac
    _lt=${_lt%%#*}
    [ -n "$_lt" ] || continue
    n_links=$((n_links + 1))
    _lr=$(link_resolve "$_lt" "$_lf")
    case $_lr in
      ESCAPE)
        add_problem "  - $_lf:$_ll 坏相对链接（目标为绝对路径或折出包根）: $_lt"
        ;;
      *)
        if [ ! -e "$pkg_root/$_lr" ]; then
          add_problem "  - $_lf:$_ll 坏相对链接（目标不存在）: $_lt"
        fi
        ;;
    esac
  done
  IFS=$OLDIFS
fi
# ④目录 README 兜底（票 266，只读两检；与收口链、升级流程同口径）
#   ①--check --blocks-only：只校验含生成块的 README 四段结构，旧格式无生成块跳过；
#   ②--freshness：在内存重算 --sync 应产出块逐行比对，漂移即指名缺失／多余行。
#   两检都不写文件；生成器缺失由检查 8 覆盖，本段不重复报；无启用目录时零动作（不作为即通过）。
if [ -f "$pkg_root/scripts/generate-dir-readmes.sh" ]; then
  dr_gen="$pkg_root/scripts/generate-dir-readmes.sh"
  dr_rules="$pkg_root/scripts/dir-readme.rules"
  _dr_err=''
  if ! _dr_err=$(sh "$dr_gen" --target "$pkg_root" --rules "$dr_rules" --check --blocks-only 2>&1); then
    while IFS= read -r _dr_line; do
      [ -n "$_dr_line" ] || continue
      add_problem "  - 目录 README 结构校验未过: $_dr_line"
    done <<EOF
${_dr_err}
EOF
  fi
  _dr_err=''
  if ! _dr_err=$(sh "$dr_gen" --target "$pkg_root" --rules "$dr_rules" --freshness 2>&1); then
    while IFS= read -r _dr_line; do
      [ -n "$_dr_line" ] || continue
      add_problem "  - 目录 README 生成块新鲜度未过: $_dr_line"
    done <<EOF
${_dr_err}
EOF
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc="references 树成员闭合与导航（成员 ${n_ref_files} 件，链接 ${n_links} 个）"
else
  _chk_desc="references 树成员闭合与导航（成员 ${n_ref_files} 件，链接 ${n_links} 个）"
fi
:
}
