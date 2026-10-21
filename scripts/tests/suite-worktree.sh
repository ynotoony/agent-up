#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite worktree "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


suite_worktree() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='worktree'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/wt
  mkdir -p "$D"
  WA="$SCRIPT_DIR/worktree-add.sh"
  SAVED_PWD=$(pwd)

  # 夹具仓：main-only 节＝deploy 目录＋agent-up/scripts/export-payload.sh 文件
  wt_build_fixture() {
    rm -rf "$1"
    mkdir -p "$1"
    git -C "$1" init -q
    git -C "$1" config user.email fixture@t
    git -C "$1" config user.name fixture
    mkdir -p "$1/agent-up/scripts" "$1/deploy" "$1/docs"
    echo '#!/bin/sh' > "$1/agent-up/scripts/export-payload.sh"
    echo x > "$1/agent-up/scripts/other.sh"
    echo x > "$1/deploy/build.sh"
    echo x > "$1/docs/a.md"
    cat > "$1/delivery.rules" <<'RULES'
# ==== main-only：worktree 排除清单（worktree-add.sh 读）====

dp_mainonly agent-up/scripts/export-payload.sh
dp_mainonly deploy
RULES
    git -C "$1" add -A
    git -C "$1" commit -qm init
  }

  # 正例 P1：栅栏化创建 → exit 0；main-only 路径不在场；非 main-only 件在场
  # （夹具全程 cd 到夹具仓内运行：脚本以 cwd 判主检出，路径参数按夹具仓相对解析）
  wt_build_fixture "$D/p1/repo"
  cd "$D/p1/repo" || exit 1
  sh "$WA" ../wt1 ticket/42-test >"$D/p1.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 0 ] && [ ! -e "$D/p1/wt1/deploy" ] && [ ! -e "$D/p1/wt1/agent-up/scripts/export-payload.sh" ] && [ -f "$D/p1/wt1/agent-up/scripts/other.sh" ] && [ -f "$D/p1/wt1/docs/a.md" ]; then
    ok '正例 P1 栅栏化创建 exit 0 且 main-only 路径物理不在场、其余件在场'
  else
    bad '正例 P1 栅栏化创建 exit 0 且 main-only 路径物理不在场、其余件在场' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '
' '|')"
  fi

  # 正例 P1b：排除清单持久于 worktree git-dir info/sparse-checkout
  if grep -q '^!deploy$' "$D/p1/repo/.git/worktrees/wt1/info/sparse-checkout" 2>/dev/null && grep -q '^!agent-up/scripts/export-payload.sh$' "$D/p1/repo/.git/worktrees/wt1/info/sparse-checkout" 2>/dev/null; then
    ok '正例 P1b 排除清单持久于 worktree info/sparse-checkout（两条 ! 路径）'
  else
    bad '正例 P1b 排除清单持久于 worktree info/sparse-checkout（两条 ! 路径）' "$(cat "$D/p1/repo/.git/worktrees/wt1/info/sparse-checkout" 2>/dev/null | tr '
' '|')"
  fi

  # 正例 P1c：worktree 内对 main-only 文件运行 → 找不到文件（创建面栅栏的运行侧效果）
  if [ ! -e "$D/p1/wt1/deploy/build.sh" ]; then
    ok '正例 P1c main-only 脚本在 worktree 内不可运行（文件不在场）'
  else
    bad '正例 P1c main-only 脚本在 worktree 内不可运行（文件不在场）' 'deploy/build.sh 意外在场'
  fi

  # 正例 P2：主检出不受栅栏影响（main-only 件全在、主仓 sparse 关闭）
  if [ -f "$D/p1/repo/deploy/build.sh" ] && [ -f "$D/p1/repo/agent-up/scripts/export-payload.sh" ]; then
    ok '正例 P2 主检出零影响（main-only 件全在）'
  else
    bad '正例 P2 主检出零影响（main-only 件全在）' '主检出文件意外缺失'
  fi

  # 负例 N1：分支名不合 ticket/<NN>-<slug> → exit 1
  wt_build_fixture "$D/n1/repo"
  cd "$D/n1/repo" || exit 1
  sh "$WA" ../wt2 main >"$D/n1.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 1 ] && grep -q '分支名不合' "$D/n1.out"; then
    ok '负例 N1 分支名不合形态 → exit 1 指名形态'
  else
    bad '负例 N1 分支名不合形态 → exit 1 指名形态' "exit=$rc $(tail -n 3 "$D/n1.out" | tr '
' '|')"
  fi

  # 负例 N2：链接 worktree 内运行 → exit 1 主检出自拒（cwd 在 P1 的 worktree 内）
  cd "$D/p1/wt1" || exit 1
  sh "$WA" ../wt3 ticket/43-test >"$D/n2.out" 2>&1 </dev/null
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 1 ] && grep -q '主检出自拒' "$D/n2.out"; then
    ok '负例 N2 链接 worktree 内运行 → exit 1 主检出自拒'
  else
    bad '负例 N2 链接 worktree 内运行 → exit 1 主检出自拒' "exit=$rc $(tail -n 3 "$D/n2.out" | tr '
' '|')"
  fi

  # 负例 N3：未声明 main-only 节 → exit 2 拒跑（栅栏未知 fail-closed）
  wt_build_fixture "$D/n3/repo"
  printf '# ==== payload：导出形态（export-payload.sh 读）====
dp_payload_root agent-up
dp_payload_remote r
dp_payload_target b
dp_payload_local_ref l
' > "$D/n3/repo/delivery.rules"
  git -C "$D/n3/repo" add delivery.rules && git -C "$D/n3/repo" commit -qm rules
  cd "$D/n3/repo" || exit 1
  sh "$WA" ../wt4 ticket/44-test >"$D/n3.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 2 ] && grep -q '未声明 main-only 节' "$D/n3.out"; then
    ok '负例 N3 未声明 main-only 节 → exit 2 拒跑（栅栏未知 fail-closed）'
  else
    bad '负例 N3 未声明 main-only 节 → exit 2 拒跑（栅栏未知 fail-closed）' "exit=$rc $(tail -n 3 "$D/n3.out" | tr '
' '|')"
  fi

  # 负例 N4：delivery.rules 解析破坏（dp_mainonly 值重复）→ exit 2
  wt_build_fixture "$D/n4/repo"
  printf '# ==== main-only：worktree 排除清单（worktree-add.sh 读）====
dp_mainonly deploy
dp_mainonly deploy
' > "$D/n4/repo/delivery.rules"
  git -C "$D/n4/repo" add delivery.rules && git -C "$D/n4/repo" commit -qm rules
  cd "$D/n4/repo" || exit 1
  sh "$WA" ../wt5 ticket/45-test >"$D/n4.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 2 ] && grep -q '解析破坏' "$D/n4.out"; then
    ok '负例 N4 delivery.rules 解析破坏 → exit 2 不产生部分结论'
  else
    bad '负例 N4 delivery.rules 解析破坏 → exit 2 不产生部分结论' "exit=$rc $(tail -n 3 "$D/n4.out" | tr '
' '|')"
  fi

  # 负例 N5：既有分支可检出（先建分支再经脚本创建 worktree）
  wt_build_fixture "$D/p3/repo"
  git -C "$D/p3/repo" branch ticket/46-test
  cd "$D/p3/repo" || exit 1
  sh "$WA" ../wt6 ticket/46-test >"$D/p3.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 0 ] && [ -d "$D/p3/wt6" ] && [ ! -e "$D/p3/wt6/deploy" ]; then
    ok '正例 P3 既有分支检出 → exit 0 且栅栏同效'
  else
    bad '正例 P3 既有分支检出 → exit 0 且栅栏同效' "exit=$rc $(tail -n 3 "$D/p3.out" | tr '
' '|')"
  fi

  suite_summary 'worktree'
}
