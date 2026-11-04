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
  WD="$SCRIPT_DIR/worktree-deps.sh"
  SAVED_PWD=$(pwd)

  # 正例 G1：实现纪律模板 §9 依赖隔离节在位（删改即红，防模板回退）
  _disc_tmpl="$SCRIPT_DIR/../references/templates/discipline.md.tmpl"
  _disc_has9=$(grep -c '^## 9\. ' "$_disc_tmpl" 2>/dev/null || true)
  if [ "${_disc_has9:-0}" -ge 1 ] \
     && grep -q 'worktree-deps\.sh' "$_disc_tmpl" 2>/dev/null \
     && grep -q '默认关闭' "$_disc_tmpl" 2>/dev/null; then
    ok '正例 G1 实现纪律模板含 §9 且保留 worktree-deps.sh 入口与「默认关闭」语义'
  else
    bad '正例 G1 实现纪律模板含 §9 且保留 worktree-deps.sh 入口与「默认关闭」语义' "§9=${_disc_has9:-0} 入口=$(grep -c 'worktree-deps\.sh' "$_disc_tmpl" 2>/dev/null || true) 默认关闭=$(grep -c '默认关闭' "$_disc_tmpl" 2>/dev/null || true)"
  fi

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
    ok '正例 P1 旧接口栅栏化创建 exit 0 且 main-only 路径物理不在场、其余件在场'
  else
    bad '正例 P1 旧接口栅栏化创建 exit 0 且 main-only 路径物理不在场、其余件在场' "exit=$rc $(tail -n 3 "$D/p1.out" | tr '
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

  # 正例 P1d：完成行带依赖准备提示（创建不装依赖，入口指向同目录 worktree-deps.sh）
  if grep -q 'worktree-deps.sh' "$D/p1.out" && grep -q '/p1/wt1' "$D/p1.out"; then
    ok '正例 P1d 完成行提示依赖准备入口（worktree-deps.sh＋站路径）'
  else
    bad '正例 P1d 完成行提示依赖准备入口（worktree-deps.sh＋站路径）' "$(tail -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P1e：同目录缺 worktree-deps.sh 的安装 → 完成行改提示「未随附」且 exit 0
  wt_build_fixture "$D/p5/repo"
  mkdir -p "$D/p5/bin"
  cp "$WA" "$D/p5/bin/worktree-add.sh"
  cp "$SCRIPT_DIR/common-helpers.sh" "$SCRIPT_DIR/dp-load-rules.sh" "$D/p5/bin/"
  cd "$D/p5/repo" || exit 1
  sh "$D/p5/bin/worktree-add.sh" ../wt7 ticket/48-test >"$D/p5.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if require_out 'suite-worktree 目标输出在场' "$D/p5.out" \
    && [ "$rc" -eq 0 ] && [ -d "$D/p5/wt7" ] \
     && grep -q '未随附' "$D/p5.out" && ! grep -q '请在该站独立准备' "$D/p5.out"; then
    ok '正例 P1e 同目录缺 worktree-deps.sh → 完成行提示「未随附」且 exit 0'
  else
    bad '正例 P1e 同目录缺 worktree-deps.sh → 完成行提示「未随附」且 exit 0' "exit=$rc $(tail -n 3 "$D/p5.out" | tr '\n' '|')"
  fi

  # 正例 P2：主检出不受栅栏影响（main-only 件全在、主仓 sparse 关闭）
  if [ -f "$D/p1/repo/deploy/build.sh" ] && [ -f "$D/p1/repo/agent-up/scripts/export-payload.sh" ]; then
    ok '正例 P2 主检出零影响（main-only 件全在）'
  else
    bad '正例 P2 主检出零影响（main-only 件全在）' '主检出文件意外缺失'
  fi

  # 正例 P4：合同入口（JSON）——传合同文件即建站，站路径自 TICKET_ID 派生（仓库名取仓根 basename）且栅栏同效
  wt_build_fixture "$D/p4/repo"
  printf '{"TICKET_ID":"43-worktree-contract"}' > "$D/p4/contract.json"
  cd "$D/p4/repo" || exit 1
  sh "$WA" "$D/p4/contract.json" >"$D/p4.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 0 ] && [ -d "$D/p4/repo-wt/wt43" ] && [ ! -e "$D/p4/repo-wt/wt43/deploy" ] && [ ! -e "$D/p4/repo-wt/wt43/agent-up/scripts/export-payload.sh" ] && [ -f "$D/p4/repo-wt/wt43/agent-up/scripts/other.sh" ]; then
    ok '正例 P4 合同入口（JSON）传合同文件即建站：站路径自 TICKET_ID 派生且栅栏同效'
  else
    bad '正例 P4 合同入口（JSON）传合同文件即建站：站路径自 TICKET_ID 派生且栅栏同效' "exit=$rc $(tail -n 3 "$D/p4.out" | tr '\n' '|')"
  fi

  # 正例 P4b：合同入口派生分支名＝ticket/<TICKET_ID>（调用方不传路径与分支名）
  br=$(git -C "$D/p4/repo-wt/wt43" symbolic-ref --short HEAD 2>/dev/null)
  if [ "$br" = "ticket/43-worktree-contract" ]; then
    ok '正例 P4b 合同入口派生分支名＝ticket/<TICKET_ID>（调用方不传路径与分支名）'
  else
    bad '正例 P4b 合同入口派生分支名＝ticket/<TICKET_ID>（调用方不传路径与分支名）' "branch=$br"
  fi

  # 正例 P4c：合同入口（委派合同模板形态）——自 {{TICKET_ID}} 节次行抽取
  wt_build_fixture "$D/p4c/repo"
  printf '{{TASK_DESCRIPTION}}\n实施票 47-contract-template。\n\n{{TICKET_ID}}\n47-contract-template\n' > "$D/p4c/contract.txt"
  cd "$D/p4c/repo" || exit 1
  sh "$WA" "$D/p4c/contract.txt" >"$D/p4c.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  br=$(git -C "$D/p4c/repo-wt/wt47" symbolic-ref --short HEAD 2>/dev/null)
  if [ "$rc" -eq 0 ] && [ -d "$D/p4c/repo-wt/wt47" ] && [ "$br" = "ticket/47-contract-template" ] && [ ! -e "$D/p4c/repo-wt/wt47/deploy" ]; then
    ok '正例 P4c 合同入口（委派合同模板）自 {{TICKET_ID}} 节派生分支与站路径且栅栏同效'
  else
    bad '正例 P4c 合同入口（委派合同模板）自 {{TICKET_ID}} 节派生分支与站路径且栅栏同效' "exit=$rc branch=$br $(tail -n 3 "$D/p4c.out" | tr '\n' '|')"
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

  # 负例 N6：合同缺 TICKET_ID → exit 2 指名（合同入口 fail-closed）
  wt_build_fixture "$D/n6/repo"
  printf '{"OTHER":"x"}' > "$D/n6/contract.json"
  cd "$D/n6/repo" || exit 1
  sh "$WA" "$D/n6/contract.json" >"$D/n6.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 2 ] && grep -q '缺 TICKET_ID' "$D/n6.out"; then
    ok '负例 N6 合同缺 TICKET_ID → exit 2 指名'
  else
    bad '负例 N6 合同缺 TICKET_ID → exit 2 指名' "exit=$rc $(tail -n 3 "$D/n6.out" | tr '\n' '|')"
  fi

  # 负例 N7：TICKET_ID 形态不合 → exit 2 指名
  wt_build_fixture "$D/n7/repo"
  printf '{{TICKET_ID}}\nnoticket\n' > "$D/n7/contract.txt"
  cd "$D/n7/repo" || exit 1
  sh "$WA" "$D/n7/contract.txt" >"$D/n7.out" 2>&1
  rc=$?
  cd "$SAVED_PWD" || exit 1
  if [ "$rc" -eq 2 ] && grep -q 'TICKET_ID 不合' "$D/n7.out"; then
    ok '负例 N7 TICKET_ID 形态不合 → exit 2 指名'
  else
    bad '负例 N7 TICKET_ID 形态不合 → exit 2 指名' "exit=$rc $(tail -n 3 "$D/n7.out" | tr '\n' '|')"
  fi

  # ---- worktree-deps.sh：依赖按 worktree 隔离 ----
  # 假 npm：不联网，只落调用日志；node_modules 标记写入自身 cwd（供并行互不影响断言）
  mkdir -p "$D/fakebin"
  cat > "$D/fakebin/npm" <<'FAKE_NPM'
#!/bin/sh
printf 'npm %s (cwd=%s)\n' "$*" "$PWD" >> "${FAKE_NPM_LOG:-/dev/null}"
if [ -n "${FAKE_NPM_SEED:-}" ] && [ -f "$PWD/node_modules/.seed-marker" ]; then
  printf 'seeded %s\n' "$PWD" >> "$FAKE_NPM_SEED"
fi
mkdir -p "$PWD/node_modules"
printf '%s\n' "$PWD" > "$PWD/node_modules/.fixture-marker"
FAKE_NPM
  chmod +x "$D/fakebin/npm"
  PATH_FAKE="$D/fakebin:$PATH"

  # 依赖夹具：npm workspaces 仓（packages/* 两个 workspace）
  wd_build_fixture() {
    rm -rf "$1"
    mkdir -p "$1/packages/app" "$1/packages/lib"
    git -C "$1" init -q
    git -C "$1" config user.email fixture@t
    git -C "$1" config user.name fixture
    printf '{"name":"root","private":true,"workspaces":["packages/*"]}\n' > "$1/package.json"
    printf '{"name":"app"}\n' > "$1/packages/app/package.json"
    printf '{"name":"lib"}\n' > "$1/packages/lib/package.json"
    git -C "$1" add -A
    git -C "$1" commit -qm init
  }

  # 依赖夹具变体：workspaces 清单由 $2 指定（JSON 数组字面量）
  wd_build_ws_fixture() {
    rm -rf "$1"
    mkdir -p "$1/packages/app" "$1/packages/lib"
    git -C "$1" init -q
    git -C "$1" config user.email fixture@t
    git -C "$1" config user.name fixture
    printf '{"name":"root","private":true,"workspaces":%s}\n' "$2" > "$1/package.json"
    printf '{"name":"app"}\n' > "$1/packages/app/package.json"
    printf '{"name":"lib"}\n' > "$1/packages/lib/package.json"
    git -C "$1" add -A
    git -C "$1" commit -qm init
  }

  # 正例 AC1a：两个 worktree 并行准备依赖 → 各自 exit 0，假 npm 恰两调
  wd_build_fixture "$D/ac1/repo"
  git -C "$D/ac1/repo" worktree add -q -b dep-a "$D/ac1/wt-a"
  git -C "$D/ac1/repo" worktree add -q -b dep-b "$D/ac1/wt-b"
  FAKE_NPM_LOG="$D/ac1/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac1/wt-a" >"$D/ac1a.out" 2>&1 &
  _pa=$!
  FAKE_NPM_LOG="$D/ac1/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac1/wt-b" >"$D/ac1b.out" 2>&1 &
  _pb=$!
  rca=0; wait "$_pa" || rca=$?
  rcb=0; wait "$_pb" || rcb=$?
  _lines=0
  [ -f "$D/ac1/npm.log" ] && _lines=$(wc -l < "$D/ac1/npm.log" | tr -d ' ')
  if [ "$rca" -eq 0 ] && [ "$rcb" -eq 0 ] && [ "$_lines" = 2 ]; then
    ok '正例 AC1a 两个 worktree 并行准备依赖各自 exit 0（假 npm 恰两调）'
  else
    bad '正例 AC1a 两个 worktree 并行准备依赖各自 exit 0（假 npm 恰两调）' "rc=$rca/$rcb npm日志=${_lines}行 $(tail -n 2 "$D/ac1a.out" | tr '\n' '|') $(tail -n 2 "$D/ac1b.out" | tr '\n' '|')"
  fi

  # 正例 AC1b：两 worktree 各自独立真实 node_modules（非符号链接、不同 inode、标记指向自身）
  _pa_pwd=$(CDPATH='' cd "$D/ac1/wt-a" && pwd -P)
  _pb_pwd=$(CDPATH='' cd "$D/ac1/wt-b" && pwd -P)
  if [ -d "$D/ac1/wt-a/node_modules" ] && [ ! -L "$D/ac1/wt-a/node_modules" ] \
     && [ -d "$D/ac1/wt-b/node_modules" ] && [ ! -L "$D/ac1/wt-b/node_modules" ] \
     && [ "$(cat "$D/ac1/wt-a/node_modules/.fixture-marker" 2>/dev/null)" = "$_pa_pwd" ] \
     && [ "$(cat "$D/ac1/wt-b/node_modules/.fixture-marker" 2>/dev/null)" = "$_pb_pwd" ] \
     && [ ! "$D/ac1/wt-a/node_modules" -ef "$D/ac1/wt-b/node_modules" ]; then
    ok '正例 AC1b 两 worktree 依赖目录各自真实独立（非符号链接、不同 inode、标记指向自身）'
  else
    bad '正例 AC1b 两 worktree 依赖目录各自真实独立（非符号链接、不同 inode、标记指向自身）' "a=$(cat "$D/ac1/wt-a/node_modules/.fixture-marker" 2>/dev/null) b=$(cat "$D/ac1/wt-b/node_modules/.fixture-marker" 2>/dev/null) expect=$_pa_pwd/$_pb_pwd"
  fi

  # 负例 AC2：目标根 node_modules 为符号链接 → exit 1 指名绝对路径且零安装
  wd_build_fixture "$D/ac2/repo"
  mkdir -p "$D/ac2/shared"
  ln -s "$D/ac2/shared" "$D/ac2/repo/node_modules"
  _rp=$(CDPATH='' cd "$D/ac2/repo" && pwd -P)
  FAKE_NPM_LOG="$D/ac2/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac2/repo" >"$D/ac2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '符号链接' "$D/ac2.out" && grep -qF "$_rp/node_modules" "$D/ac2.out" && [ ! -e "$D/ac2/npm.log" ]; then
    ok '负例 AC2 根 node_modules 为符号链接 → exit 1 指名路径＋零安装'
  else
    bad '负例 AC2 根 node_modules 为符号链接 → exit 1 指名路径＋零安装' "exit=$rc $(tail -n 2 "$D/ac2.out" | tr '\n' '|')"
  fi

  # 负例 AC2b：workspace 的 node_modules 为符号链接 → 同款拒绝（安装前发现）
  wd_build_fixture "$D/ac2b/repo"
  mkdir -p "$D/ac2b/shared"
  ln -s "$D/ac2b/shared" "$D/ac2b/repo/packages/app/node_modules"
  _rp=$(CDPATH='' cd "$D/ac2b/repo" && pwd -P)
  FAKE_NPM_LOG="$D/ac2b/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac2b/repo" >"$D/ac2b.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '符号链接' "$D/ac2b.out" && grep -qF "$_rp/packages/app/node_modules" "$D/ac2b.out" && [ ! -e "$D/ac2b/npm.log" ]; then
    ok '负例 AC2b workspace 的 node_modules 为符号链接 → exit 1 指名路径＋零安装'
  else
    bad '负例 AC2b workspace 的 node_modules 为符号链接 → exit 1 指名路径＋零安装' "exit=$rc $(tail -n 2 "$D/ac2b.out" | tr '\n' '|')"
  fi

  # 负例 AC3：删除某 workspace 的 package.json → 安装前停止、指名缺失路径、零安装
  wd_build_fixture "$D/ac3/repo"
  rm "$D/ac3/repo/packages/app/package.json"
  FAKE_NPM_LOG="$D/ac3/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac3/repo" >"$D/ac3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'workspace 清单缺失' "$D/ac3.out" \
     && grep -qF 'packages/app/package.json' "$D/ac3.out" \
     && [ ! -e "$D/ac3/npm.log" ] && [ ! -e "$D/ac3/repo/node_modules" ]; then
    ok '负例 AC3 workspace 的 package.json 缺失 → exit 1 指名路径＋零安装'
  else
    bad '负例 AC3 workspace 的 package.json 缺失 → exit 1 指名路径＋零安装' "exit=$rc $(tail -n 2 "$D/ac3.out" | tr '\n' '|')"
  fi

  # 正例 AC4：无 package.json 的仓库（非 npm 仓库）→ 显式 skip 且 exit 0
  mkdir -p "$D/ac4/plain"
  FAKE_NPM_LOG="$D/ac4/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac4/plain" >"$D/ac4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'SKIP' "$D/ac4.out" && [ ! -e "$D/ac4/npm.log" ]; then
    ok '正例 AC4 非 npm 仓库显式 skip → exit 0 且零安装'
  else
    bad '正例 AC4 非 npm 仓库显式 skip → exit 0 且零安装' "exit=$rc $(tail -n 2 "$D/ac4.out" | tr '\n' '|')"
  fi

  # 正例 AC5：workspaces 模式命中普通文件（packages/README.md）→ 静默跳过且 exit 0
  wd_build_ws_fixture "$D/ac5/repo" '["packages/*"]'
  printf 'x\n' > "$D/ac5/repo/packages/README.md"
  git -C "$D/ac5/repo" add -A && git -C "$D/ac5/repo" commit -qm readme
  FAKE_NPM_LOG="$D/ac5/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac5/repo" >"$D/ac5.out" 2>&1
  rc=$?
  _calls=0
  [ -f "$D/ac5/npm.log" ] && _calls=$(wc -l < "$D/ac5/npm.log" | tr -d ' ')
  if [ "$rc" -eq 0 ] && [ -f "$D/ac5/repo/node_modules/.fixture-marker" ] && [ "$_calls" = 1 ]; then
    ok '正例 AC5 workspace 模式命中普通文件（packages/README.md）→ 静默跳过且 exit 0'
  else
    bad '正例 AC5 workspace 模式命中普通文件（packages/README.md）→ 静默跳过且 exit 0' "exit=$rc calls=$_calls $(tail -n 2 "$D/ac5.out" | tr '\n' '|')"
  fi

  # 正例 AC6：简单 brace workspace（packages/{app,lib}）→ 两目录展开匹配且 exit 0
  wd_build_ws_fixture "$D/ac6/repo" '["packages/{app,lib}"]'
  FAKE_NPM_LOG="$D/ac6/npm.log" PATH="$PATH_FAKE" sh "$WD" "$D/ac6/repo" >"$D/ac6.out" 2>&1
  rc=$?
  _calls=0
  [ -f "$D/ac6/npm.log" ] && _calls=$(wc -l < "$D/ac6/npm.log" | tr -d ' ')
  if [ "$rc" -eq 0 ] && [ -f "$D/ac6/repo/node_modules/.fixture-marker" ] && [ "$_calls" = 1 ]; then
    ok '正例 AC6 简单 brace workspace（packages/{app,lib}）→ 两目录展开匹配且 exit 0'
  else
    bad '正例 AC6 简单 brace workspace（packages/{app,lib}）→ 两目录展开匹配且 exit 0' "exit=$rc calls=$_calls $(tail -n 2 "$D/ac6.out" | tr '\n' '|')"
  fi

  # 正例 CL1：克隆加速显式开启 → 播种源 marker 对假 npm 可见
  wd_build_fixture "$D/cl/repo"
  git -C "$D/cl/repo" worktree add -q -b dep-c "$D/cl/wt"
  mkdir -p "$D/cl/cache"
  : > "$D/cl/cache/.seed-marker"
  FAKE_NPM_LOG="$D/cl/npm.log" FAKE_NPM_SEED="$D/cl/seed.log" PATH="$PATH_FAKE" \
    sh "$WD" --clone-accel --clone-from "$D/cl/cache" "$D/cl/wt" >"$D/cl.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ -s "$D/cl/seed.log" ] && grep -q 'seeded' "$D/cl/seed.log"; then
    ok '正例 CL1 --clone-accel --clone-from 显式开启 → 播种完成（假 npm 见 seed 标记）'
  else
    bad '正例 CL1 --clone-accel --clone-from 显式开启 → 播种完成（假 npm 见 seed 标记）' "exit=$rc $(tail -n 3 "$D/cl.out" | tr '\n' '|')"
  fi

  # 正例 CL2：克隆加速默认关闭 → 不播种（seed 日志为空）
  wd_build_fixture "$D/cl2/repo"
  git -C "$D/cl2/repo" worktree add -q -b dep-d "$D/cl2/wt"
  mkdir -p "$D/cl2/cache"
  : > "$D/cl2/cache/.seed-marker"
  FAKE_NPM_LOG="$D/cl2/npm.log" FAKE_NPM_SEED="$D/cl2/seed.log" PATH="$PATH_FAKE" \
    sh "$WD" "$D/cl2/wt" >"$D/cl2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$D/cl2/seed.log" ]; then
    ok '正例 CL2 克隆加速默认关闭 → 不播种（seed 日志零行）'
  else
    bad '正例 CL2 克隆加速默认关闭 → 不播种（seed 日志零行）' "exit=$rc seed=$(cat "$D/cl2/seed.log" 2>/dev/null | tr '\n' '|')"
  fi

  # 负例 CL3：--clone-accel 缺 --clone-from → exit 2（参数互须，不猜播种源）
  PATH="$PATH_FAKE" sh "$WD" --clone-accel "$D/ac4/plain" >"$D/cl3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '同用' "$D/cl3.out"; then
    ok '负例 CL3 --clone-accel 缺 --clone-from → exit 2 指名互须'
  else
    bad '负例 CL3 --clone-accel 缺 --clone-from → exit 2 指名互须' "exit=$rc $(tail -n 2 "$D/cl3.out" | tr '\n' '|')"
  fi

  # 负例 CL4：--clone-from 单独给出 → exit 2（克隆加速默认关闭，不因单参数自启）
  PATH="$PATH_FAKE" sh "$WD" --clone-from "$D/cl/cache" "$D/ac4/plain" >"$D/cl4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '同用' "$D/cl4.out"; then
    ok '负例 CL4 --clone-from 单独给出 → exit 2（加速默认关闭）'
  else
    bad '负例 CL4 --clone-from 单独给出 → exit 2（加速默认关闭）' "exit=$rc $(tail -n 2 "$D/cl4.out" | tr '\n' '|')"
  fi

  # 负例 U1：未知参数 → exit 2 指名
  PATH="$PATH_FAKE" sh "$WD" --bogus >"$D/u1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '未知参数' "$D/u1.out"; then
    ok '负例 U1 未知参数 → exit 2 指名'
  else
    bad '负例 U1 未知参数 → exit 2 指名' "exit=$rc $(tail -n 2 "$D/u1.out" | tr '\n' '|')"
  fi

  # 负例 U2：目标 worktree 根不存在 → exit 2 指名
  PATH="$PATH_FAKE" sh "$WD" "$D/u2-missing" >"$D/u2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '不存在' "$D/u2.out"; then
    ok '负例 U2 目标根不存在 → exit 2 指名'
  else
    bad '负例 U2 目标根不存在 → exit 2 指名' "exit=$rc $(tail -n 2 "$D/u2.out" | tr '\n' '|')"
  fi

  suite_summary 'worktree'
}
