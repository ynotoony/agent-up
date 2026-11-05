#!/bin/sh
# Input: check_5 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_template
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 5（templates-manifest）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 5：模板清单一致（票 57 数据驱动：数据 templates 节 ↔ 磁盘 .tmpl ↔
# templates/README.md manifest 表双向；manifest＝人读投影，数据＝机器真相）。

check_5() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
templates_dir="$pkg_root/references/templates"
manifest="$templates_dir/README.md"
n_templates=$(wc -l < "$pm_templates" | tr -d ' ')
tmpl_list=''
if [ -d "$templates_dir" ]; then
  tmpl_list=$(find "$templates_dir" -type f -name '*.tmpl' | sort)
fi
disk_count=0
if [ -n "$tmpl_list" ]; then
  disk_count=$(printf '%s\n' "$tmpl_list" | wc -l | tr -d ' ')
fi
problems=''
if [ ! -d "$templates_dir" ]; then
  add_problem '  - references/templates/ 目录不存在'
elif [ "$disk_count" -ne "$n_templates" ]; then
  # 花括号不可省略：$disk_count 后紧跟全角字符时，sh 会把多字节字符并入变量名。
  add_problem "  - .tmpl 数量为 ${disk_count}（预期 ${n_templates}）"
fi
if [ -d "$templates_dir" ]; then
  # 磁盘 .tmpl ⊆ 数据（票 09「无未登记」口径的机器真相侧）
  unreg=''
  sep2=''
  OLDIFS=$IFS
  IFS='
'
  for t in $tmpl_list; do
    IFS=$OLDIFS
    if ! grep -qxF "$(basename "$t")" "$pm_templates"; then
      unreg="$unreg$sep2$(basename "$t")"
      sep2='、'
    fi
  done
  IFS=$OLDIFS
  if [ -n "$unreg" ]; then
    add_problem "  - 数据未登记：$unreg"
  fi
  # 数据 ⊆ 磁盘
  data_no_file=''
  sep2=''
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r b; do
    if [ ! -f "$templates_dir/$b" ]; then
      data_no_file="$data_no_file$sep2$b"
      sep2='、'
    fi
  done < "$pm_templates"
  IFS=$OLDIFS
  if [ -n "$data_no_file" ]; then
    add_problem "  - 数据登记但无实际文件：$data_no_file"
  fi
  # 数据 ↔ manifest 表双向
  if [ ! -f "$manifest" ]; then
    add_problem '  - templates/README.md（manifest）不存在'
  else
    # 仅在“## 目录清单”至“## 取舍”节内提取（票 09 口径：避开取舍登记散文提及）。
    # shellcheck disable=SC2016  # sed 程序刻意字面 $（引号形态由程序语义决定；wiki 长尾误报）
    man_names=$(sed -n '/^## 目录清单/,/^## 取舍/p' "$manifest" | sed -n 's/[^`]*`\([^`]*\.tmpl\)`.*/\1/p' | sort -u)
    data_no_man=''
    sep2=''
    OLDIFS=$IFS
    IFS='
'
    while IFS= read -r b; do
      if ! printf '%s\n' "$man_names" | grep -qxF "$b"; then
        data_no_man="$data_no_man$sep2$b"
        sep2='、'
      fi
    done < "$pm_templates"
    IFS=$OLDIFS
    if [ -n "$data_no_man" ]; then
      add_problem "  - 未在 manifest 登记：$data_no_man"
    fi
    man_no_data=''
    sep2=''
    for m in $man_names; do
      if ! grep -qxF "$m" "$pm_templates"; then
        man_no_data="$man_no_data$sep2$m"
        sep2='、'
      fi
    done
    if [ -n "$man_no_data" ]; then
      add_problem "  - manifest 登记但不在数据：$man_no_data"
    fi
  fi
fi
if [ -n "$problems" ]; then
  _chk_desc="templates 下 .tmpl 为 ${n_templates} 个且全部登记"
else
  _chk_desc="templates 下 .tmpl 为 ${n_templates} 个且全部登记"
fi
:
}
