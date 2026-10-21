#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite install "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: install（票 145 场景沉淀：install.sh 非执行式规则表解析正负例——合法表
# 安装全链＋幂等跳过＋规则表缺失/损坏 fail-closed＋恶意输入四形态 rc=2 零写入）
# ============================================================

inst_build_pkg() {
  # $1=夹具包根：install.sh＋install-policy.rules＋快道/票务两门控全部登记源
  P=$1
  rm -rf "$P"; mkdir -p "$P/scripts"
  cp "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/install-policy.rules" "$P/scripts/"
  for f in check-gates.sh lane-commit.sh worktree-add.sh upgrade-check.sh generate-progress.sh ticket-ops.sh run-record.sh ticket-grade.sh absorption-trigger.sh health-summary.sh; do
    cp "$SCRIPT_DIR/$f" "$P/scripts/$f" 2>/dev/null || true
  done
}

suite_install() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='install'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/inst
  mkdir -p "$D"
  INST="$SCRIPT_DIR/install.sh"

  # 栅栏环境跳过（R-DP-036：worktree-add.sh 按 delivery.rules dp_mainonly 排除 main-only 件，
  # install.sh 在 worktree 内物理不在场；口径同 check-package 检查 8/9 的 worktree SKIP）：
  # 被测件不在场则整套显式 SKIP 不计数——覆盖面归主检出全量，不宣称不存在的验证。
  if [ ! -f "$INST" ]; then
    printf 'SKIP  [install] 被测件 install.sh 不在场（worktree 栅栏排除 main-only 件）——整套跳过，覆盖归主检出\n'
    suite_summary 'install'
    return 0
  fi

  # 正例 P1：合法表双门控安装 → exit 0 目标恰落 10 件（stdout 摘要行计数）
  # install.sh 的 R-DP-036 worktree 自拒按调用 cwd 判定（非 Git 语境放行）：夹具安装
  # 从 harness 的 mktemp 非 Git 目录调用，避免 harness 在 worktree 内跑时栅栏误拦夹具。
  inst_build_pkg "$D/pkg1"; mkdir -p "$D/proj1"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p1.out" 2>&1
  rc=$?
  p1_n=$(grep -c '^install: OK:' "$D/p1.out")
  if [ "$rc" -eq 0 ] && [ "$p1_n" -eq 10 ] && grep -q '^install: DONE: 复制 10 件、幂等跳过 0 件' "$D/p1.out" \
    && [ -f "$D/proj1/rules/implementation/scripts/check-gates.sh" ] \
    && [ -f "$D/proj1/rules/implementation/scripts/ticket-ops.sh" ]; then
    ok '正例 P1 合法表双门控安装 → exit 0 复制 10 件落位'
  else
    bad '正例 P1 合法表双门控安装 → exit 0 复制 10 件落位' "exit=$rc ok_lines=$p1_n"
  fi

  # 正例 P2：幂等重跑 → 逐件 SKIP exit 0 零新写入（文件集与首跑逐一相等）
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.before"
  ( cd "$D" && sh "$INST" --target "$D/proj1" --fast-lane --ticket-ops ) >"$D/p2.out" 2>&1
  rc=$?
  ( cd "$D/proj1" && LC_ALL=C find . -type f | LC_ALL=C sort ) > "$D/p2.tree.after"
  if [ "$rc" -eq 0 ] && grep -q '^install: DONE: 复制 0 件、幂等跳过 10 件' "$D/p2.out" \
    && cmp -s "$D/p2.tree.before" "$D/p2.tree.after"; then
    ok '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 10 件（文件集零变化）'
  else
    bad '正例 P2 幂等重跑 → exit 0 复制 0 件幂等跳过 10 件（文件集零变化）' "exit=$rc"
  fi

  # 负例 N1：规则表缺失 → exit 2 零写入
  inst_build_pkg "$D/pkg2"; rm -f "$D/pkg2/scripts/install-policy.rules"; mkdir -p "$D/proj2"
  sh "$D/pkg2/scripts/install.sh" --target "$D/proj2" --fast-lane >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -d "$D/proj2/rules" ]; then
    ok '负例 N1 规则表缺失 → exit 2 零写入'
  else
    bad '负例 N1 规则表缺失 → exit 2 零写入' "exit=$rc"
  fi

  # 负例 N2：结构破坏（ip_file 参数数不合预期）→ exit 2 零写入（既有口径回归钉死）
  inst_build_pkg "$D/pkg3"
  printf "ip_file agent-up/scripts/check-gates.sh Conditional\n" >> "$D/pkg3/scripts/install-policy.rules"
  mkdir -p "$D/proj3"
  sh "$D/pkg3/scripts/install.sh" --target "$D/proj3" --fast-lane >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -d "$D/proj3/rules" ]; then
    ok '负例 N2 ip_file 参数数不足 → exit 2 零写入（结构校验 fail-closed）'
  else
    bad '负例 N2 ip_file 参数数不足 → exit 2 零写入（结构校验 fail-closed）' "exit=$rc"
  fi

  # 票 145 恶意输入负例 N3～N6：规则表注入恶意行 → 非执行式解析期 exit 2 零写入，
  # 探针文件断言承载零执行；目标仓 canary 文件断言零非预期写入。
  for ii_i in 1 2 3 4; do
    inst_build_pkg "$D/pkgm$ii_i"
    mkdir -p "$D/projm$ii_i"; printf 'canary\n' > "$D/projm$ii_i/canary"
    printf "ip_gate fast-lane --fast-lane 'fixture gate'\nip_file agent-up/scripts/check-gates.sh Conditional fast-lane 'fixture file'\n" > "$D/pkgm$ii_i/scripts/install-policy.rules"
    case $ii_i in
      1) printf "ip_file 'x\$(touch /tmp/tri145i1)x' Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N3 规则表命令替换注入（引号内美元括号）→ exit 2 零写入'; ii_probe=/tmp/tri145i1 ;;
      2) printf "ip_file 'x\`touch /tmp/tri145i2\`x' Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N4 规则表反引号注入 → exit 2 零写入'; ii_probe=/tmp/tri145i2 ;;
      3) printf "ip_file agent-up/scripts/check-gates.sh > /tmp/tri145i3 Conditional fast-lane 'evil'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N5 规则表引号外重定向注入 → exit 2 零写入'; ii_probe=/tmp/tri145i3 ;;
      4) printf "evil_cmd 'rm' '-rf' '/' 'x' 'y'\n" >> "$D/pkgm$ii_i/scripts/install-policy.rules"; ii_desc='负例 N6 规则表未知指令注入 → exit 2 零写入'; ii_probe='' ;;
    esac
    sh "$D/pkgm$ii_i/scripts/install.sh" --target "$D/projm$ii_i" --fast-lane >/dev/null 2>"$D/pkgm$ii_i/err"
    rc=$?
    if [ "$rc" -eq 2 ] && [ ! -d "$D/projm$ii_i/rules" ] && [ "$(cat "$D/projm$ii_i/canary")" = 'canary' ] \
      && { [ -z "$ii_probe" ] || [ ! -e "$ii_probe" ]; } \
      && grep -q '非执行式解析不合预期' "$D/pkgm$ii_i/err"; then
      ok "$ii_desc"
    else
      bad "$ii_desc" "exit=$rc stderr=$(head -n 1 "$D/pkgm$ii_i/err")"
    fi
  done
  rm -f /tmp/tri145i1 /tmp/tri145i2 /tmp/tri145i3

  suite_summary 'install'
}
