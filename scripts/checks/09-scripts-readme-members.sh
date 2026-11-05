#!/bin/sh
# Input: check_9 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_script
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 9（scripts-readme-members）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 9：$scripts_readme_rel 成员表 ↔ 数据 scripts 节一致（票 57 新增）。一致口径（双向）：
# ①数据 scripts 节每件都在成员表登记（表＝人读投影不得漏登必需件）；②成员表登记的
# 每件都是 $scripts_dir 下实际文件（表与实物不漂移）。
# 票 177：worktree 环境豁免 main-only 脚本的成员表检查，主检出保持原有检查。

check_9() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
scripts_readme="$pkg_root/$scripts_readme_rel"

if [ "$in_worktree" -eq 1 ]; then
  _chk_skip="$scripts_readme_rel 成员表与数据 scripts 节一致（worktree 环境，跳过 main-only 成员检查）"
  # worktree 环境：检查非 main-only 脚本与成员表一致性
  if [ ! -f "$scripts_readme" ]; then
    add_problem "  - ${scripts_readme_rel}（成员表）不存在"
  else
    # shellcheck disable=SC2016  # sed 正则捕获组 \(...\) 必须单引号防止 shell 展开
    table_names=$(awk '
      /^\| 名字 \| 地位 \| 功能 \|/ { f = 1; next }
      f { if ($0 !~ /^\|/) f = 0; else print }
    ' "$scripts_readme" | sed -n 's/^| `\([^`]*\)`.*/\1/p')
    if [ -z "$table_names" ]; then
      add_problem '  - 成员表未提取到成员行（表结构漂移）'
    else
      miss_tbl=''
      sep2=''
      OLDIFS=$IFS
      IFS='
'
      while IFS= read -r row; do
        rel=${row%%"$TAB"*}
        b=${rel##*/}
        # 跳过 main-only 脚本的成员表检查（delivery.rules 路径含 agent-up/ 前缀）
        is_mainonly=0
        for mo in $mainonly_list; do
          mo_rel="${mo#agent-up/}"
          if [ "$rel" = "$mo_rel" ]; then
            is_mainonly=1
            break
          fi
        done
        if [ "$is_mainonly" -eq 0 ] && ! printf '%s\n' "$table_names" | grep -qxF "$b"; then
          miss_tbl="$miss_tbl$sep2$b"
          sep2='、'
        fi
      done < "$pm_scripts"
      IFS=$OLDIFS
      if [ -n "$miss_tbl" ]; then
        add_problem "  - 数据登记未在成员表（worktree 跳过 main-only）：$miss_tbl"
      fi
      no_file=''
      sep2=''
      for b in $table_names; do
        # 跳过 main-only 脚本的文件存在性检查
        is_mainonly_b=0
        for mo in $mainonly_list; do
          mo_basename=${mo##*/}
          if [ "$b" = "$mo_basename" ]; then
            is_mainonly_b=1
            break
          fi
        done
        if [ "$is_mainonly_b" -eq 0 ] && [ ! -f "$pkg_root/$scripts_dir/$b" ] && [ ! -d "$pkg_root/$scripts_dir/$b" ]; then
          no_file="$no_file$sep2$b"
          sep2='、'
        fi
      done
      if [ -n "$no_file" ]; then
        add_problem "  - 成员表登记但无实际文件（worktree 跳过 main-only）：$no_file"
      fi
    fi
  fi
  if [ -n "$problems" ]; then
    _chk_desc="${scripts_readme_rel} 成员表与数据 scripts 节一致（worktree 跳过 main-only）"
  else
    _chk_desc="${scripts_readme_rel} 成员表与数据 scripts 节一致（worktree 跳过 main-only）"
  fi
else
  # 主检出：检查全部 scripts 节与成员表一致性
  if [ ! -f "$scripts_readme" ]; then
    add_problem "  - ${scripts_readme_rel}（成员表）不存在"
  else
    # 提取成员表（锚点＝首列表头行；表格随首个非 | 行结束），每行取首列反引号名单。
    # shellcheck disable=SC2016  # awk 程序刻意字面 $（引号形态由程序语义决定；wiki 长尾误报）
    table_names=$(awk '
      /^\| 名字 \| 地位 \| 功能 \|/ { f = 1; next }
      f { if ($0 !~ /^\|/) f = 0; else print }
    ' "$scripts_readme" | sed -n 's/^| `\([^`]*\)`.*/\1/p')
    if [ -z "$table_names" ]; then
      add_problem '  - 成员表未提取到成员行（表结构漂移）'
    else
      miss_tbl=''
      sep2=''
      OLDIFS=$IFS
      IFS='
'
      while IFS= read -r row; do
        rel=${row%%"$TAB"*}
        b=${rel##*/}
        if ! printf '%s\n' "$table_names" | grep -qxF "$b"; then
          miss_tbl="$miss_tbl$sep2$b"
          sep2='、'
        fi
      done < "$pm_scripts"
      IFS=$OLDIFS
      if [ -n "$miss_tbl" ]; then
        add_problem "  - 数据登记未在成员表：$miss_tbl"
      fi
      no_file=''
      sep2=''
      for b in $table_names; do
        if [ ! -f "$pkg_root/$scripts_dir/$b" ] && [ ! -d "$pkg_root/$scripts_dir/$b" ]; then
          no_file="$no_file$sep2$b"
          sep2='、'
        fi
      done
      if [ -n "$no_file" ]; then
        add_problem "  - 成员表登记但无实际文件：$no_file"
      fi
    fi
  fi
  if [ -n "$problems" ]; then
    _chk_desc="${scripts_readme_rel} 成员表与数据 scripts 节一致"
  else
    _chk_desc="${scripts_readme_rel} 成员表与数据 scripts 节一致"
  fi
fi
:
}
