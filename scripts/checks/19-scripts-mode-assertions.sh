#!/bin/sh
# Input: check_19 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_script
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 19（scripts-mode-assertions）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 19：scripts 节可执行位断言（mode 全量）。判定源＝清单 pm_script kind（数据驱动，
# 引擎零文件名硬编码，家族惯例同检查 8/9）：kind=script（普通脚本）与 kind=test-harness
# （被调 harness）为可执行类——须 index 100755 且盘上可执行（出生即残类失效防线：hook
# 只调可执行件、直接执行依赖 -x 位，mode 残缺静默失效，先例 .githooks 门禁 5）；kind=rules
# （数据规则表）为非可执行件——须 index 100644 且盘上不可执行（数据件误带执行位防扩散）。
# 每件四态核对：index mode（git ls-files -s）、盘上 -x、期望 mode、kind 枚举兜底（未知
# kind 即 FAIL，防 kind 枚举扩张漏配期望）。$pkg_root 非 git worktree 时（--pkg-root
# 复制落位语境，先例检查 13 静默跳过语义）整项静默跳过零输出行——git 不可用时 index
# mode 无从核对，不核对不宣称（假 PASS 与误报都不发生）。

check_19() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_mode_scripts=$(wc -l < "$pm_scripts" | tr -d ' ')
if git -C "$pkg_root" rev-parse --git-dir >/dev/null 2>&1; then
  OLDIFS=$IFS
  IFS='
'
  while IFS= read -r row; do
    rel=${row%%"$TAB"*}
    kind=${row#*"$TAB"}
    kind=${kind%%"$TAB"*}
    case $kind in
      script|test-harness) want=100755; want_exec=1 ;;
      rules) want=100644; want_exec=0 ;;
      dir) continue ;;  # 目录成员（kind=dir，如 tests/ 套件目录）：git 不跟踪目录 mode，无可执行位语义，不核对不宣称
      *)
        add_problem "  - $rel kind 不合预期（script|rules|test-harness|dir 外值，期望 mode 未配置）: $kind"
        continue
        ;;
    esac
    idx_mode=$(git -C "$pkg_root" ls-files -s -- "$rel" | LC_ALL=C awk '{print $1; exit}')
    if [ ! -f "$pkg_root/$rel" ]; then
      continue  # 缺件由检查 8 指名，本项不重复报
    fi
    if [ -z "$idx_mode" ]; then
      add_problem "  - $rel 未被 git 跟踪（index mode 无从核对，期望 ${want}）"
      continue
    fi
    if [ "$idx_mode" != "$want" ]; then
      # 花括号不可省略：全角字符相邻时防止变量名吞并（先例检查 12）
      add_problem "  - $rel index mode 为 ${idx_mode}（期望 ${want}，kind=${kind}）"
    fi
    if [ "$want_exec" -eq 1 ] && ! [ -x "$pkg_root/$rel" ]; then
      add_problem "  - $rel 盘上不可执行（kind=${kind} 须可执行，chmod 755 修复）"
    fi
    if [ "$want_exec" -eq 0 ] && [ -x "$pkg_root/$rel" ]; then
      add_problem "  - $rel 盘上可执行（kind=${kind} 数据件禁执行位）"
    fi
  done < "$pm_scripts"
  IFS=$OLDIFS
  if [ -n "$problems" ]; then
    _chk_desc="scripts 节 mode 断言（${n_mode_scripts} 件，kind 数据驱动）"
  else
    _chk_desc="scripts 节 mode 断言（${n_mode_scripts} 件，kind 数据驱动）"
  fi
fi
:
}
