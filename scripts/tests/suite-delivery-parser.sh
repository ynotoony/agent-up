#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite delivery-parser "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: delivery-parser（delivery.rules 共享解析器单源一致性与正反例：
# 四消费件静态单源断言（零内嵌 dp_load_rules 定义＋同目录加载＋最低版注记）＋
# 合法四节文法全链 pass（worktree-add 栅栏化创建真跑）＋同一 rules 文件经
# 探针夹具逐件采集 DP_* 解析结论并逐项相等＋畸形文法/缺解析器/版本漂移三类
# 负例逐件指名失败（畸形另断言不产生部分结论）＋文法说明与解析库元数据
# 机械核对（指令全集/锚点表/版本三方逐一相等）＋安装政策闭包登记断言。
# export-payload.sh 属 main-only 栅栏件：物理不在场时其分项显式 SKIP 不计数，
# 覆盖归主检出全量。被测对象只读，夹具全 mktemp＋git init 临时仓。）
# ============================================================

DP_LIB_NAME='dp-load-rules.sh'

dp_build_fixture() {
  # $1=夹具仓根 $2=delivery.rules 文件 [$3=bare＝不建 payload 根目录（export-payload
  # 正例语境：解析通过后确定性停在 payload 根缺失）]：git 夹具仓（cwd 在内即主检出）
  rm -rf "$1"
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email fixture@t
  git -C "$1" config user.name fixture
  if [ "${3:-}" != 'bare' ]; then
    mkdir -p "$1/agent-up/scripts" "$1/fenced"
    echo '#!/bin/sh' > "$1/agent-up/scripts/export-payload.sh"
    echo x > "$1/fenced/deep.sh"
  else
    mkdir -p "$1/fenced"
    echo x > "$1/fenced/deep.sh"
  fi
  cp "$2" "$1/delivery.rules"
  # check-artifacts 前置最小登记（对账器先核登记与枚举权威模板再达解析器加载点）
  mkdir -p "$1/facts/project"
  cat > "$1/facts/project/artifacts.yaml" <<'YAML'
artifacts:
  - id: yaml-self
    path: facts/project/artifacts.yaml
    kind: index
    lifecycle: Seed
YAML
  git -C "$1" add -A
  git -C "$1" commit -qm init
}

dp_valid_rules() {
  cat > "$1" <<'RULES'
# ==== payload：导出形态（export-payload.sh 读）====
dp_payload_root agent-up
dp_payload_remote origin-remote
dp_payload_target trunk
dp_payload_local_ref export-ref

# ==== boundary：禁入名单（pre-push 安检读）====
dp_forbid fenced

# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====
dp_artifact_exempt gen
dp_stale_lit S1
dp_stale_lit S2

# ==== main-only：worktree 排除清单（worktree-add.sh 读）====
dp_mainonly fenced/deep.sh
RULES
}

dp_malformed_rules() {
  # 合法结构中段注入未知指令：既触发未知指令负例，又断言失败时不产生部分结论
  # （payload 根行在前、解析整体失败，DP_ROOT 必须为空）
  cat > "$1" <<'RULES'
# ==== payload：导出形态（export-payload.sh 读）====
dp_payload_root agent-up
dp_bogus_unknown_directive y

# ==== main-only：worktree 排除清单（worktree-add.sh 读）====
dp_mainonly fenced/deep.sh
RULES
}

dp_probe_build() {
  # $1=布局目录：消费件副本＋探针化解析器副本（sed 改名原实现＋包装函数采集 DP_*）
  # ＋common-helpers 副本；DP_PROBE_OUT 环境变量指向采集文件
  mkdir -p "$1"
  cp "$SCRIPT_DIR/common-helpers.sh" "$1/"
  sed 's/^dp_load_rules() {/dp_load_rules_impl() {/' "$SCRIPT_DIR/$DP_LIB_NAME" > "$1/$DP_LIB_NAME"
  cat >> "$1/$DP_LIB_NAME" <<'PROBE'

# ---- 探针包装（harness 夹具注入，非包内物）：采集 dp_load_rules 调用后的 DP_* 全态 ----
dp_load_rules() {
  dp_load_rules_impl "$@"
  _dpp_rc=$?
  if [ -n "${DP_PROBE_OUT:-}" ]; then
    {
      printf 'version=%s\n' "${DP_PARSER_VERSION:-}"
      printf 'rc=%s\n' "$_dpp_rc"
      printf 'PRESENT=%s\n' "${DP_PRESENT-}"
      printf 'HAS_PAYLOAD=%s\n' "${DP_HAS_PAYLOAD-}"
      printf 'ROOT=%s\n' "${DP_ROOT-}"
      printf 'REMOTE=%s\n' "${DP_REMOTE-}"
      printf 'TARGET=%s\n' "${DP_TARGET-}"
      printf 'LOCAL_REF=%s\n' "${DP_LOCAL_REF-}"
      printf 'FORBID=%s\n' "${DP_FORBID-}"
      printf 'EXEMPT=%s\n' "${DP_EXEMPT-}"
      printf 'STALE_LIT=%s\n' "${DP_STALE_LIT-}"
      printf 'HAS_MAINONLY=%s\n' "${DP_HAS_MAINONLY-}"
      printf 'MAINONLY=%s\n' "${DP_MAINONLY-}"
      printf 'MAINONLY_DECLARED=%s\n' "${DP_MAINONLY_DECLARED-}"
    } > "$DP_PROBE_OUT"
  fi
  return "$_dpp_rc"
}
PROBE
  cp "$SCRIPT_DIR/check-artifacts.sh" "$SCRIPT_DIR/check-stale-claims.sh" "$SCRIPT_DIR/worktree-add.sh" "$1/" 2>/dev/null
  if [ -f "$SCRIPT_DIR/export-payload.sh" ]; then
    cp "$SCRIPT_DIR/export-payload.sh" "$1/"
  fi
  # check-artifacts 枚举权威模板按「脚本目录上一级 references/」定位（$0 语义），落布局父目录
  mkdir -p "$1/../references/templates"
  cp "$SCRIPT_DIR/../references/templates/artifacts-yaml.tmpl" "$1/../references/templates/"
  return 0
}

dp_run_consumer() {
  # $1=布局目录 $2=消费件 $3=探针输出 $4=夹具仓根 $5=场景名
  # stdout+stderr 落 $D/run.<场景>.<消费件>.log；退出码经 return 传出
  _rc_layout=$1; _rc_c=$2; _rc_probe=$3; _rc_repo=$4
  case $_rc_c in
    worktree-add.sh)
      ( cd "$_rc_repo" && DP_PROBE_OUT="$_rc_probe" sh "$_rc_layout/$_rc_c" ../wt-probe ticket/97-probe ) > "$D/run.$5.$_rc_c.log" 2>&1
      ;;
    check-artifacts.sh)
      ( cd "$_rc_repo" && DP_PROBE_OUT="$_rc_probe" sh "$_rc_layout/$_rc_c" "$_rc_repo" ) > "$D/run.$5.$_rc_c.log" 2>&1
      ;;
    check-stale-claims.sh)
      ( cd "$_rc_repo" && DP_PROBE_OUT="$_rc_probe" sh "$_rc_layout/$_rc_c" "$_rc_repo" gate ) > "$D/run.$5.$_rc_c.log" 2>&1
      ;;
    export-payload.sh)
      ( cd "$_rc_repo" && DP_PROBE_OUT="$_rc_probe" sh "$_rc_layout/$_rc_c" --dry-run "$_rc_repo" ) > "$D/run.$5.$_rc_c.log" 2>&1
      ;;
  esac
  return $?
}

suite_delivery_parser() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='delivery-parser'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/dparser
  mkdir -p "$D"
  DP_LIB="$SCRIPT_DIR/$DP_LIB_NAME"
  DP_DOC="$SCRIPT_DIR/../references/delivery-rules.md"
  # 栅栏态：export-payload.sh 物理不在场时其分项 SKIP（覆盖归主检出全量）
  EP_PRESENT=0
  if [ -f "$SCRIPT_DIR/export-payload.sh" ]; then
    EP_PRESENT=1
  fi

  # ---- 静态单源断言：四消费件零内嵌定义＋同目录加载＋最低版注记 ----
  for dp_c in check-artifacts.sh check-stale-claims.sh worktree-add.sh export-payload.sh; do
    if [ "$dp_c" = 'export-payload.sh' ] && [ "$EP_PRESENT" -eq 0 ]; then
      printf 'SKIP  [delivery-parser] 静态单源断言 %s（main-only 栅栏件不在场）——跳过，覆盖归主检出\n' "$dp_c"
      continue
    fi
    dp_f="$SCRIPT_DIR/$dp_c"
    dp_defs=$(grep -c '^dp_load_rules()' "$dp_f")
    # shellcheck disable=SC2016  # source 行字面量比对（刻意单引号防展开，grep -qF 定长匹配）
    if [ "$dp_defs" -eq 0 ] \
      && grep -qF "_dp_parser_file=\$(dirname \"\$0\")/$DP_LIB_NAME" "$dp_f" \
      && grep -qF '. "$_dp_parser_file"' "$dp_f" \
      && grep -q '^# dp-parser: 2$' "$dp_f"; then
      ok "静态单源断言 ${dp_c}：零内嵌 dp_load_rules 定义＋同目录加载共享解析器＋最低版注记 dp-parser: 2"
    else
      bad "静态单源断言 ${dp_c}：零内嵌 dp_load_rules 定义＋同目录加载共享解析器＋最低版注记 dp-parser: 2" "内嵌定义数=$dp_defs"
    fi
  done

  # ---- 解析库形状：唯一实现＋唯一版本来源 ----
  dp_fn=$(grep -c '^dp_load_rules()' "$DP_LIB")
  dp_ver=$(grep -c '^DP_PARSER_VERSION=' "$DP_LIB")
  if [ "$dp_fn" -eq 1 ] && [ "$dp_ver" -eq 1 ]; then
    ok '解析库形状：dp-load-rules.sh 恰一个 dp_load_rules 定义＋恰一个 DP_PARSER_VERSION 版本来源'
  else
    bad '解析库形状：dp-load-rules.sh 恰一个 dp_load_rules 定义＋恰一个 DP_PARSER_VERSION 版本来源' "定义=$dp_fn 版本行=$dp_ver"
  fi

  # ---- 文法说明 ↔ 解析库元数据机械核对（指令全集/锚点表/版本三方逐一相等）----
  awk '/^    function is_known\(/,/^    }$/' "$DP_LIB" | grep -o 'dp_[a-z_]*' | LC_ALL=C sort -u > "$D/meta.parser"
  sed -n 's/^指令全集（恰 8）: //p' "$DP_DOC" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort -u > "$D/meta.doc"
  dp_n=$(wc -l < "$D/meta.parser" | tr -d ' ')
  if [ "$dp_n" -eq 8 ] && cmp -s "$D/meta.parser" "$D/meta.doc"; then
    ok '文法说明↔解析库：指令全集恰 8 条且两源逐一相等（is_known 集合＝说明机器行）'
  else
    bad '文法说明↔解析库：指令全集恰 8 条且两源逐一相等（is_known 集合＝说明机器行）' "解析库集合=$dp_n 条 diff=$(diff "$D/meta.doc" "$D/meta.parser" 2>/dev/null | LC_ALL=C tr '\n' '|')"
  fi
  grep -o 'an\[[1-4]\] = ".*"' "$DP_LIB" | sed 's/^an\[[1-4]\] = "//; s/"$//' > "$D/anchors"
  dp_anchor_miss=''
  while IFS= read -r dp_a; do
    [ -n "$dp_a" ] || continue
    grep -qF "$dp_a" "$DP_DOC" || dp_anchor_miss="$dp_anchor_miss|$dp_a"
  done < "$D/anchors"
  dp_anchor_n=$(wc -l < "$D/anchors" | tr -d ' ')
  if [ "$dp_anchor_n" -eq 4 ] && [ -z "$dp_anchor_miss" ]; then
    ok '文法说明↔解析库：四节锚点表 an[1..4] 与说明逐字一致（恰 4 条全命中）'
  else
    bad '文法说明↔解析库：四节锚点表 an[1..4] 与说明逐字一致（恰 4 条全命中）' "锚点数=$dp_anchor_n 缺失=$dp_anchor_miss"
  fi
  dp_pv=$(sed -n 's/^DP_PARSER_VERSION=//p' "$DP_LIB")
  dp_dv=$(sed -n 's/^dp-parser 现行版本: //p' "$DP_DOC")
  if [ -n "$dp_pv" ] && [ "$dp_pv" = "$dp_dv" ]; then
    ok "文法说明↔解析库：解析器版本单源一致（现行版本 ${dp_pv}，说明行与变量逐一相等）"
  else
    bad '文法说明↔解析库：解析器版本单源一致（说明行与变量逐一相等）' "解析库=$dp_pv 说明=$dp_dv"
  fi

  # ---- 安装政策闭包登记：共享解析器随 worktree-add 同门控入安装闭包 ----
  if grep -qF "ip_file agent-up/scripts/$DP_LIB_NAME Conditional fast-lane " "$SCRIPT_DIR/install-policy.rules" \
    && grep -qF 'ip_file agent-up/scripts/worktree-add.sh Conditional fast-lane ' "$SCRIPT_DIR/install-policy.rules"; then
    ok '安装政策闭包：dp-load-rules.sh 与 worktree-add.sh 同在 fast-lane 门控 ip_file 登记（同目录定位安装闭包）'
  else
    bad '安装政策闭包：dp-load-rules.sh 与 worktree-add.sh 同在 fast-lane 门控 ip_file 登记（同目录定位安装闭包）'
  fi

  # ---- 正例：合法四节文法全链 pass（worktree-add 栅栏化创建真跑）----
  dp_valid_rules "$D/rules.valid"
  dp_build_fixture "$D/fx.valid" "$D/rules.valid"
  ( cd "$D/fx.valid" && sh "$SCRIPT_DIR/worktree-add.sh" ../wt.valid ticket/91-probe ) > "$D/valid.wta.log" 2>&1
  dp_rc=$?
  if [ "$dp_rc" -eq 0 ] && [ ! -e "$D/wt.valid/fenced" ] && [ -f "$D/wt.valid/agent-up/scripts/export-payload.sh" ] \
    && grep -q '^!fenced/deep.sh$' "$D/fx.valid/.git/worktrees/wt.valid/info/sparse-checkout" 2>/dev/null; then
    ok '正例 合法四节文法 → worktree-add 栅栏化创建 exit 0 且 main-only 路径物理不在场（共享解析器全链生效）'
  else
    bad '正例 合法四节文法 → worktree-add 栅栏化创建 exit 0 且 main-only 路径物理不在场（共享解析器全链生效）' "exit=$dp_rc $(tail -n 3 "$D/valid.wta.log" | LC_ALL=C tr '\n' '|')"
  fi

  # ---- 一致性探针：同一 rules 文件逐件采集 DP_* 解析结论并逐项相等 ----
  dp_probe_build "$D/probe"
  dp_valid_rules "$D/rules.ep"
  dp_build_fixture "$D/fx.ep" "$D/rules.ep" bare
  dp_present=''
  for dp_c in check-artifacts.sh check-stale-claims.sh worktree-add.sh export-payload.sh; do
    if [ "$dp_c" = 'export-payload.sh' ] && [ "$EP_PRESENT" -eq 0 ]; then
      printf 'SKIP  [delivery-parser] 一致性探针 %s（main-only 栅栏件不在场）——跳过，覆盖归主检出\n' "$dp_c"
      continue
    fi
    dp_probe_out="$D/probe.$dp_c.out"
    dp_repo="$D/fx.valid"
    [ "$dp_c" = 'export-payload.sh' ] && dp_repo="$D/fx.ep"
    dp_run_consumer "$D/probe" "$dp_c" "$dp_probe_out" "$dp_repo" valid
    dp_rc=$?
    dp_parse_ok=0
    if [ -f "$dp_probe_out" ] && grep -q '^rc=0$' "$dp_probe_out"; then
      dp_parse_ok=1
    fi
    dp_clean=1
    if grep -q '解析破坏' "$D/run.valid.$dp_c.log"; then
      dp_clean=0
    fi
    # export-payload 正例语境＝payload 根缺失夹具（解析成功后确定性 exit 2 指名，最短越解析点路径）
    if [ "$dp_c" = 'export-payload.sh' ]; then
      if [ "$dp_parse_ok" -eq 1 ] && [ "$dp_rc" -eq 2 ] && grep -q 'payload 根不存在' "$D/run.valid.$dp_c.log"; then
        ok "一致性探针 ${dp_c}：合法文法解析通过（探针 rc=0）且 DP_ROOT 流转生效（payload 根不存在 exit 2 指名＝越解析点确定性失败）"
      else
        bad "一致性探针 ${dp_c}：合法文法解析通过且越解析点（payload 根不存在 exit 2 指名）" "exit=$dp_rc 探针=$(cat "$dp_probe_out" 2>/dev/null | LC_ALL=C tr '\n' '|')"
      fi
    elif [ "$dp_parse_ok" -eq 1 ] && [ "$dp_clean" -eq 1 ]; then
      ok "一致性探针 ${dp_c}：合法四节文法解析通过（探针 rc=0，输出零解析破坏）"
    else
      bad "一致性探针 ${dp_c}：合法四节文法解析通过（探针 rc=0，输出零解析破坏）" "exit=$dp_rc 探针=$(cat "$dp_probe_out" 2>/dev/null | LC_ALL=C tr '\n' '|')"
    fi
    dp_present="$dp_present $dp_c"
  done
  # 逐项相等：在场消费件的探针结论两两 cmp（同一 rules 文件、同一解析库实现）
  dp_eq=1
  dp_first=''
  dp_detail=''
  for dp_c in $dp_present; do
    if [ ! -f "$D/probe.$dp_c.out" ]; then
      dp_eq=0
      dp_detail="$dp_detail|$dp_c 缺探针"
      continue
    fi
    if [ -z "$dp_first" ]; then
      dp_first="$D/probe.$dp_c.out"
    else
      cmp -s "$dp_first" "$D/probe.$dp_c.out" || { dp_eq=0; dp_detail="$dp_detail|$dp_c 与首件不等"; }
    fi
  done
  dp_n_present=$(echo "$dp_present" | wc -w | tr -d ' ')
  if [ "$dp_eq" -eq 1 ] && [ "$dp_n_present" -ge 3 ]; then
    ok "四消费者解析结论逐项相等（同一 rules 文件探针逐项 cmp，$dp_n_present 件两两相等；栅栏外含 export-payload 共四件）"
  else
    bad "四消费者解析结论逐项相等（同一 rules 文件探针逐项 cmp；栅栏外含 export-payload 共四件）" "在场=$dp_n_present $dp_detail"
  fi
  # 结论内容断言（防全空相等假阳性）：版本与四节字段逐项为预期值
  if [ -n "$dp_first" ] \
    && grep -q '^version=2$' "$dp_first" \
    && grep -q '^rc=0$' "$dp_first" \
    && grep -q '^PRESENT=1$' "$dp_first" \
    && grep -q '^HAS_PAYLOAD=1$' "$dp_first" \
    && grep -q '^ROOT=agent-up$' "$dp_first" \
    && grep -q '^REMOTE=origin-remote$' "$dp_first" \
    && grep -q '^TARGET=trunk$' "$dp_first" \
    && grep -q '^LOCAL_REF=export-ref$' "$dp_first" \
    && grep -q '^FORBID=fenced$' "$dp_first" \
    && grep -q '^EXEMPT=gen$' "$dp_first" \
    && grep -q '^STALE_LIT=S1' "$dp_first" \
    && grep -q '^S2$' "$dp_first" \
    && grep -q '^HAS_MAINONLY=1$' "$dp_first" \
    && grep -q '^MAINONLY=fenced/deep.sh$' "$dp_first" \
    && grep -q '^MAINONLY_DECLARED=1$' "$dp_first"; then
    ok '解析结论内容断言：版本 2 与四节字段逐项为预期值（防全空相等假阳性）'
  else
    bad '解析结论内容断言：版本 2 与四节字段逐项为预期值（防全空相等假阳性）' "$(cat "$dp_first" 2>/dev/null | LC_ALL=C tr '\n' '|')"
  fi

  # ---- 负例一：畸形文法 → 逐件 exit 2 指名解析破坏且不产生部分结论 ----
  dp_malformed_rules "$D/rules.bad"
  for dp_c in check-artifacts.sh check-stale-claims.sh worktree-add.sh export-payload.sh; do
    if [ "$dp_c" = 'export-payload.sh' ] && [ "$EP_PRESENT" -eq 0 ]; then
      printf 'SKIP  [delivery-parser] 畸形文法负例 %s（main-only 栅栏件不在场）——跳过，覆盖归主检出\n' "$dp_c"
      continue
    fi
    dp_build_fixture "$D/fx.bad" "$D/rules.bad"
    rm -f "$D/probe.bad.$dp_c.out"
    dp_run_consumer "$D/probe" "$dp_c" "$D/probe.bad.$dp_c.out" "$D/fx.bad" malformed
    dp_rc=$?
    dp_no_partial=0
    if [ -f "$D/probe.bad.$dp_c.out" ] \
      && grep -q '^rc=2$' "$D/probe.bad.$dp_c.out" \
      && grep -q '^ROOT=$' "$D/probe.bad.$dp_c.out" \
      && grep -q '^HAS_PAYLOAD=0$' "$D/probe.bad.$dp_c.out"; then
      dp_no_partial=1
    fi
    if [ "$dp_rc" -eq 2 ] && grep -q '解析破坏' "$D/run.malformed.$dp_c.log" && [ "$dp_no_partial" -eq 1 ]; then
      ok "负例 畸形文法 $dp_c → exit 2 指名解析破坏且探针证不产生部分结论（DP_ROOT 空）"
    else
      bad "负例 畸形文法 $dp_c → exit 2 指名解析破坏且探针证不产生部分结论（DP_ROOT 空）" "exit=$dp_rc 探针=$(cat "$D/probe.bad.$dp_c.out" 2>/dev/null | LC_ALL=C tr '\n' '|') 日志=$(tail -n 2 "$D/run.malformed.$dp_c.log" | LC_ALL=C tr '\n' '|')"
    fi
  done

  # ---- 负例二：缺解析器（布局目录无 dp-load-rules.sh）→ 逐件 exit 2 指名缺失 ----
  for dp_c in check-artifacts.sh check-stale-claims.sh worktree-add.sh export-payload.sh; do
    if [ "$dp_c" = 'export-payload.sh' ] && [ "$EP_PRESENT" -eq 0 ]; then
      printf 'SKIP  [delivery-parser] 缺解析器负例 %s（main-only 栅栏件不在场）——跳过，覆盖归主检出\n' "$dp_c"
      continue
    fi
    rm -rf "$D/miss"
    mkdir -p "$D/miss" "$D/references/templates"
    cp "$SCRIPT_DIR/common-helpers.sh" "$D/miss/"
    cp "$SCRIPT_DIR/$dp_c" "$D/miss/"
    cp "$SCRIPT_DIR/../references/templates/artifacts-yaml.tmpl" "$D/references/templates/"
    dp_run_consumer "$D/miss" "$dp_c" "$D/probe.unused.out" "$D/fx.valid" "miss.$dp_c"
    dp_rc=$?
    if [ "$dp_rc" -eq 2 ] && grep -q '共享解析器缺失' "$D/run.miss.$dp_c.$dp_c.log" && grep -qF "$DP_LIB_NAME" "$D/run.miss.$dp_c.$dp_c.log"; then
      ok "负例 缺解析器 $dp_c → exit 2 指名共享解析器缺失与路径"
    else
      bad "负例 缺解析器 $dp_c → exit 2 指名共享解析器缺失与路径" "exit=$dp_rc $(tail -n 2 "$D/run.miss.$dp_c.$dp_c.log" | LC_ALL=C tr '\n' '|')"
    fi
  done

  # ---- 负例三：版本漂移（解析器副本 DP_PARSER_VERSION=1）→ 逐件 exit 2 指名漂移 ----
  for dp_c in check-artifacts.sh check-stale-claims.sh worktree-add.sh export-payload.sh; do
    if [ "$dp_c" = 'export-payload.sh' ] && [ "$EP_PRESENT" -eq 0 ]; then
      printf 'SKIP  [delivery-parser] 版本漂移负例 %s（main-only 栅栏件不在场）——跳过，覆盖归主检出\n' "$dp_c"
      continue
    fi
    rm -rf "$D/drift"
    mkdir -p "$D/drift" "$D/references/templates"
    cp "$SCRIPT_DIR/common-helpers.sh" "$D/drift/"
    cp "$SCRIPT_DIR/$dp_c" "$D/drift/"
    sed 's/^DP_PARSER_VERSION=2$/DP_PARSER_VERSION=1/' "$SCRIPT_DIR/$DP_LIB_NAME" > "$D/drift/$DP_LIB_NAME"
    cp "$SCRIPT_DIR/../references/templates/artifacts-yaml.tmpl" "$D/references/templates/"
    dp_run_consumer "$D/drift" "$dp_c" "$D/probe.unused.out" "$D/fx.valid" "drift.$dp_c"
    dp_rc=$?
    if [ "$dp_rc" -eq 2 ] && grep -q '共享解析器版本漂移' "$D/run.drift.$dp_c.$dp_c.log" && grep -q '低于本件最低要求 2' "$D/run.drift.$dp_c.$dp_c.log"; then
      ok "负例 版本漂移 $dp_c → exit 2 指名解析器版本漂移（版本 1 低于最低要求 2）"
    else
      bad "负例 版本漂移 $dp_c → exit 2 指名解析器版本漂移（版本 1 低于最低要求 2）" "exit=$dp_rc $(tail -n 2 "$D/run.drift.$dp_c.$dp_c.log" | LC_ALL=C tr '\n' '|')"
    fi
  done

  suite_summary 'delivery-parser'
}
