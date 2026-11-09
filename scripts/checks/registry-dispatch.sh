#!/bin/sh
# Input: check-package.sh 薄 CLI 传入引擎目录（checks/）与包根；注册表数据源＝同目录
#        registry.rules（非执行式解析，与清单共用词法器）；检查件＝同目录 NN-slug.sh，
#        由注册表行发现并载入。
# Output: 注册表查询函数（编号上界、定向运行的必需数据节——纯查询，零副作用）、注册表加载
#        与三向完整性断言、定向选择集规范化、检查件载入与统一分发、输出完整性守卫；
#        断言或分发不合预期即 exit 2 fail-closed（stdout 零部分结论）。
# Pos: 检查注册表与分发执行器（agent-up/scripts/checks/registry-dispatch.sh）：
#      注册表解析/断言/查询、检查件载入、逐项分发与输出集合守卫的唯一承载点；
#      引擎只留参数、上下文派生、调度与输出汇总。
# shellcheck disable=SC2034,SC2154  # 跨件共享状态（引擎全局账本/上下文），单文件视野误报

# ============================================================
# 一、注册表纯查询（无副作用；供用法文本、定向运行预解析与依赖闭包使用）
# ============================================================

chk_registry_query_total() {
  # $1=注册表文件 → 编号上界（chk_total 首行第二字段）；文件缺失/无行输出空
  [ -f "$1" ] || return 0
  LC_ALL=C awk '$1 == "chk_total" { print $2; exit }' "$1"
}

chk_registry_query_sections() {
  # $1=注册表文件 $2=--only 原文（逗号分隔）→ 选中检查声明的必需数据节（逗号展开为空格）；
  # 未注册号不产出节名（合法性由注册表加载后的规范化判定指名）。
  [ -f "$1" ] || return 0
  LC_ALL=C awk -v only="$2" '
    BEGIN { n = split(only, a, ","); for (i = 1; i <= n; i++) want[a[i]] = 1 }
    $1 == "chk" {
      if ($2 in want) {
        gsub(",", " ", $5)
        printf "%s ", $5
      }
    }
  ' "$1"
}

# ============================================================
# 二、注册表加载与三向完整性断言
# ============================================================

chk_registry_init() {
  # $1=引擎 checks 目录
  chk_registry_file="$1/registry.rules"
  chk_parsed="$pm_tmpdir/registry-parsed"
  chk_rows="$pm_tmpdir/registry-rows"
  chk_retired="$pm_tmpdir/registry-retired"
  chk_total_rows="$pm_tmpdir/registry-total-rows"
  : > "$chk_parsed"
  : > "$chk_rows"
  : > "$chk_retired"
  : > "$chk_total_rows"
}

chk_load_report() {
  chk_load_bad="$chk_load_bad$1
"
}

chk_registry_load() {
  # 解析→行形态校验→按指令分流账本→全局计数与在役号集合（缺件/损坏由解析层 fail-closed）
  pm_parse_data "$chk_registry_file" "$chk_parsed" '检查注册表' || { rm -f "$chk_parsed"; chk_parsed=''; exit 2; }
  chk_bad_field=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "检查注册表第 %d 行: %s\n", FNR, msg; n++ }
    $1 == "chk_total" { if (NF != 2) bad("chk_total 字段数 " NF "（预期 2）"); next }
    $1 == "chk_retired" { if (NF != 2) bad("chk_retired 字段数 " NF "（预期 2）"); next }
    $1 == "chk" {
      if (NF != 5) { bad("chk 字段数 " NF "（预期 5：号、slug、件、必需数据节）"); next }
      if ($2 !~ /^[1-9][0-9]*$/) bad("检查号须正整数: " $2)
      if ($3 !~ /^[a-z][a-z0-9-]*$/) bad("slug 须小写 token: " $3)
      if ($4 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) bad("检查件须为单段 *.sh 文件名: " $4)
    }
    END { if (n > 0) exit 1 }
  ' "$chk_parsed") || true
  if [ -n "$chk_bad_field" ]; then
    printf 'check-package: 错误：检查注册表结构不合预期（fail-closed，不产生部分结论）: %s\n%s\n' "$chk_registry_file" "$chk_bad_field" >&2
    exit 2
  fi
  while IFS= read -r chk_row; do
    chk_cmd=${chk_row%%"$TAB"*}
    chk_rest=${chk_row#*"$TAB"}
    case $chk_cmd in
      chk_total) printf '%s\n' "$chk_rest" >> "$chk_total_rows" ;;
      chk_retired) printf '%s\n' "$chk_rest" >> "$chk_retired" ;;
      chk) printf '%s\n' "$chk_rest" >> "$chk_rows" ;;
    esac
  done < "$chk_parsed"
  rm -f "$chk_parsed"; chk_parsed=''

  chk_load_bad=''
  chk_total_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_total_rows")
  if [ "$chk_total_reg_n" -ne 1 ]; then
    chk_load_report "  - 注册表 chk_total 须恰一行（实际 ${chk_total_reg_n} 行）"
  fi
  chk_total_reg=$(head -n 1 "$chk_total_rows")
  if ! printf '%s\n' "$chk_total_reg" | LC_ALL=C grep -qE '^[1-9][0-9]*$'; then
    chk_load_report "  - 注册表 chk_total 须正整数: ${chk_total_reg:-<空>}"
  fi
  if [ "$chk_total_reg" != "$pm_check_total_n" ]; then
    chk_load_report "  - 注册表 chk_total 与清单 check-registry 编号上界不一致: $chk_total_reg ≠ $pm_check_total_n"
  fi
  chk_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_rows")
  chk_man_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_checks")
  chk_ret_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$pm_checkretired")
  chk_ret_reg_n=$(LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$chk_retired")
  chk_exp_n=$((chk_total_reg - chk_ret_n))
  if [ "$chk_reg_n" -ne "$chk_man_n" ] || [ "$chk_reg_n" -ne "$chk_exp_n" ]; then
    chk_load_report "  - 注册项数不一致：注册表 ${chk_reg_n}／清单 ${chk_man_n}／上界−退役 $chk_exp_n"
  fi
  if [ "$chk_ret_reg_n" -ne "$chk_ret_n" ]; then
    chk_load_report "  - 退役号行数不一致：注册表 ${chk_ret_reg_n}／清单 $chk_ret_n"
  fi
  chk_ids=$(LC_ALL=C awk -F'\t' 'NF { print $1 }' "$chk_rows" | LC_ALL=C sort -n)
}

chk_registry_select() {
  # 定向运行选择集合规范化（--only N[,N]）：未设时运行集合＝在役号全集，行为与全量一致。
  chk_run_ids=$chk_ids
  [ "$chk_only_mode" -eq 1 ] || return 0
  chk_only_norm=''
  chk_only_bad=''
  _chk_oldifs=$IFS
  IFS=','
  # shellcheck disable=SC2086  # 逗号分词即解析手段（列表值已由调用方以单参数传入）
  set -- $chk_only_raw
  IFS=$_chk_oldifs
  # 号集合改为 shell 内成员判定：逐号 grep 派生进程在定向运行的固定开销里占比可观
  chk_ids_sp=' '
  for _id_sp in $chk_ids; do chk_ids_sp="$chk_ids_sp$_id_sp "; done
  for chk_one in "$@"; do
    case $chk_one in
      ''|*[!0-9]*) chk_only_bad="$chk_only_bad $chk_one"; continue ;;
    esac
    case $chk_ids_sp in
      *" $chk_one "*) ;;
      *) chk_only_bad="$chk_only_bad $chk_one"; continue ;;
    esac
    chk_only_norm="$chk_only_norm$chk_one
"
  done
  if [ -n "$chk_only_bad" ]; then
    printf 'check-package: 错误：--only 含未注册或非法检查号:%s（已注册: %s）\n' "$chk_only_bad" "$(printf '%s' "$chk_ids" | tr '\n' ' ')" >&2
    exit 2
  fi
  chk_run_ids=$(printf '%s' "$chk_only_norm" | LC_ALL=C sort -n -u)
  chk_run_ids_sp=' '
  for _id_sp in $chk_run_ids; do chk_run_ids_sp="$chk_run_ids_sp$_id_sp "; done
}

chk_registry_assert() {
  # 三向完整性断言的校验面：全量模式＝全表三向校验；--only 模式只校验全局计数与被选中的
  # 检查行（行级形态/重复、号集合与 slug 对），退役号集合与编号连续性属全表性质，定向运行
  # 不校验（改由提交门禁的全量运行兜底）。随后载入检查件并断言统一 interface 函数齐备。
  chk_rows_scope=$chk_rows
  chk_man_scope=$pm_checks
  chk_ids_scope=$chk_ids
  if [ "$chk_only_mode" -eq 1 ]; then
    chk_rows_scope="$pm_tmpdir/registry-rows-scope"
    chk_man_scope="$pm_tmpdir/manifest-checks-scope"
    LC_ALL=C awk -F'\t' -v want="$chk_run_ids_sp" '
      BEGIN { n = split(want, a, " "); for (i = 1; i <= n; i++) w[a[i]] = 1 }
      ($1 in w)
    ' "$chk_rows" > "$chk_rows_scope"
    LC_ALL=C awk -F'\t' -v want="$chk_run_ids_sp" '
      BEGIN { n = split(want, a, " "); for (i = 1; i <= n; i++) w[a[i]] = 1 }
      ($1 in w)
    ' "$pm_checks" > "$chk_man_scope"
    chk_ids_scope=$chk_run_ids
  fi
  chk_bad_reg=$(LC_ALL=C awk -F'\t' '
    function bad(msg) { printf "  - 注册表第 %d 行: %s\n", FNR, msg; n++ }
    {
      if (NF != 4) { bad("字段数 " NF "（预期 4）"); next }
      if ($1 !~ /^[1-9][0-9]*$/) { bad("检查号须正整数: " $1); next }
      if ($2 !~ /^[a-z][a-z0-9-]*$/) { bad("slug 须小写 token: " $2); next }
      if ($3 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) { bad("检查件须为单段 *.sh 文件名: " $3); next }
      if ($4 != "-" && $4 !~ /^[a-z_]+(,[a-z_]+)*$/) { bad("必需数据节形态不合预期: " $4); next }
      if ($1 in seenid) { bad("检查号跨行重复: " $1) } else { seenid[$1] = 1 }
      if ($2 in seenslug) { bad("slug 跨行重复: " $2) } else { seenslug[$2] = 1 }
      if ($3 in seenfile) { bad("检查件跨行重复: " $3) } else { seenfile[$3] = 1 }
    }
    END { if (n > 0) exit 1 }
  ' "$chk_rows_scope") || true
  if [ -n "$chk_bad_reg" ]; then
    chk_load_bad="$chk_load_bad$chk_bad_reg
"
  fi
  chk_man_ids=$(LC_ALL=C awk -F'\t' 'NF { print $1 }' "$chk_man_scope" | LC_ALL=C sort -n)
  if [ "$chk_ids_scope" != "$chk_man_ids" ]; then
    chk_load_report '  - 注册表在役检查号集合与清单 check-registry 不一致'
  fi
  chk_pairs=$(LC_ALL=C awk -F'\t' 'NF { print $1 "\t" $2 }' "$chk_rows_scope" | LC_ALL=C sort -n)
  chk_man_pairs=$(LC_ALL=C awk -F'\t' 'NF { print $1 "\t" $2 }' "$chk_man_scope" | LC_ALL=C sort -n)
  if [ "$chk_pairs" != "$chk_man_pairs" ]; then
    chk_load_report '  - 注册表（检查号, slug）对与清单 check-registry 不一致'
  fi
  if [ "$chk_only_mode" -eq 0 ]; then
    chk_ret_ids=$(LC_ALL=C awk 'NF { print $1 }' "$pm_checkretired" | LC_ALL=C sort -n)
    chk_ret_reg_ids=$(LC_ALL=C awk 'NF { print $1 }' "$chk_retired" | LC_ALL=C sort -n)
    if [ "$chk_ret_ids" != "$chk_ret_reg_ids" ]; then
      chk_load_report '  - 注册表退役号集合与清单 check-registry 不一致'
    fi
    chk_union=$(printf '%s\n%s\n' "$chk_ids" "$chk_ret_ids" | LC_ALL=C awk 'NF { print $1 }' | LC_ALL=C sort -n | LC_ALL=C uniq)
    chk_gap=$(printf '%s\n' "$chk_union" | LC_ALL=C awk -v total="$chk_total_reg" '
      BEGIN { for (i = 1; i <= total; i++) want[i] = 1 }
      NF { have[$1] = 1 }
      END { for (i = 1; i <= total; i++) if (!(i in have)) print i }
    ')
    if [ -n "$chk_gap" ]; then
      chk_load_report "  - 编号连续性与退役声明不一致（缺失号）: $(printf '%s' "$chk_gap" | tr '\n' ' ')"
    fi
  fi
  # 定向运行只载入被选中的检查件（其余不参与行级校验、不 source）：行集在 awk 内一次筛出。
  chk_src_list=''
  if [ "$chk_only_mode" -eq 1 ]; then
    chk_src_input=$(LC_ALL=C awk -F'\t' -v want="$chk_run_ids_sp" '
      BEGIN { n = split(want, a, " "); for (i = 1; i <= n; i++) w[a[i]] = 1 }
      ($1 in w)
    ' "$chk_rows")
  else
    chk_src_input=$(LC_ALL=C sort -n -t"$(printf '\t')" -k1,1n "$chk_rows")
  fi
  while IFS="$(printf '\t')" read -r chk_n chk_slug chk_file chk_required; do
    [ -n "$chk_n" ] || continue
    if [ ! -f "$chk_dir/$chk_file" ]; then
      chk_load_report "  - 检查件不存在: checks/${chk_file}（检查 ${chk_n}）"
      continue
    fi
    if [ "$chk_required" != "-" ]; then
      for chk_req in $(printf '%s' "$chk_required" | tr ',' ' '); do
        # shellcheck disable=SC2194  # 常量词表（清单指令名白名单）刻意字面，非变量遗漏
        case " pm_entry pm_script pm_template pm_shortcode pm_platform pm_vague_word pm_vague_exempt pm_mirror pm_capability pm_capability_authority pm_capability_target pm_mechanism pm_cite_exempt pm_layout_face pm_layout_universe pm_layout_legacy_file pm_layout_compat_exempt pm_enforcement_level pm_enforcement_target pm_adapter pm_adapter_cap pm_adapter_role pm_adapter_exec pm_adapter_dialect pm_retired_token pm_retired_face pm_legacy_marker pm_workflow pm_workflow_fixture_marker pm_production_entry pm_production_claim pm_ticket_status pm_readonly_site pm_contract_pointer " in
          *" $chk_req "*) ;;
          *) chk_load_report "  - 必需数据节未登记: ${chk_req}（检查 ${chk_n}）" ;;
        esac
      done
    fi
    chk_src_list="$chk_src_list$chk_dir/$chk_file
"
  done <<EOF
$chk_src_input
EOF
  while IFS= read -r chk_fn_path; do
    [ -n "$chk_fn_path" ] || continue
    # shellcheck disable=SC1090  # 检查件路径由注册表现算（动态发现），静态视野不可跟随
    . "$chk_fn_path" || { chk_load_report "  - 检查件载入失败: $chk_fn_path"; continue; }
  done <<EOF
$chk_src_list
EOF
  chk_missing_fn=''
  chk_check_ids=$chk_ids
  if [ "$chk_only_mode" -eq 1 ]; then chk_check_ids=$chk_run_ids; fi
  while IFS= read -r chk_n; do
    [ -n "$chk_n" ] || continue
    if ! command -v "check_$chk_n" >/dev/null 2>&1; then
      chk_missing_fn="$chk_missing_fn check_$chk_n"
    fi
  done <<EOF
$chk_check_ids
EOF
  if [ -n "$chk_missing_fn" ]; then
    chk_load_report "  - 检查件未定义统一 interface 函数:$chk_missing_fn"
  fi
  if [ -n "$chk_load_bad" ]; then
    printf 'check-package: 错误：检查注册表完整性断言未通过（fail-closed，不产生部分结论）:\n%s' "$chk_load_bad" >&2
    exit 2
  fi
  n_total_checks=$chk_total_reg
}

# ============================================================
# 三、统一分发执行器：注册表顺序逐项调用检查件，引擎统一生成 PASS/FAIL/SKIP 行。
# 输出先缓冲、完整性守卫通过后一次性落 stdout：检查件崩溃/主动 exit 2/输出残缺一律
# fail-closed（stderr 指名，stdout 零残缺输出），杜绝 exit 0 的残缺包检。
# ============================================================

chk_dispatch_run() {
  # $1=包根（传给检查件的契约参数）
  while IFS= read -r chk_n; do
    [ -n "$chk_n" ] || continue
    : > "$chk_state_desc"
    : > "$chk_state_skip"
    : > "$chk_state_problems"
    : > "$chk_state_stdout"
    chk_rc=0
    ( problems=''
      _chk_desc=''
      _chk_skip=''
      # 共享 scratch（引擎显式初始化后传入；检查件之间零隐式状态）
      sep=''
      sep2=''
      sep_a=''
      sep_e=''
      OLDIFS=$IFS
      "check_$chk_n" "$1"
      printf '%s' "$_chk_desc" > "$chk_state_desc"
      printf '%s' "$_chk_skip" > "$chk_state_skip"
      printf '%s' "$problems" > "$chk_state_problems"
    ) > "$chk_state_stdout" || chk_rc=$?
    if [ "$chk_rc" -eq 2 ]; then
      exit 2
    elif [ "$chk_rc" -ne 0 ]; then
      printf 'check-package: 错误：检查 %s 执行异常中止（fail-closed，不产生部分结论）\n' "$chk_n" >&2
      exit 2
    fi
    if [ -s "$chk_state_stdout" ]; then
      printf 'check-package: 错误：检查 %s 直接写 stdout（违反检查件 interface：只判定与报告问题）\n' "$chk_n" >&2
      exit 2
    fi
    _chk_desc=$(cat "$chk_state_desc")
    _chk_skip=$(cat "$chk_state_skip")
    problems=$(cat "$chk_state_problems")
    if [ -n "$_chk_skip" ]; then
      printf 'SKIP: %s %s\n' "$chk_n" "$_chk_skip" >> "$chk_out_buf"
    fi
    if [ -n "$problems" ]; then
      if [ -z "$_chk_desc" ]; then
        printf 'check-package: 错误：检查 %s 未声明描述（检查件 interface 违约）\n' "$chk_n" >&2
        exit 2
      fi
      fail "$chk_n" "$_chk_desc" "$problems"
    elif [ -n "$_chk_desc" ]; then
      pass "$chk_n" "$_chk_desc"
    fi
  done <<EOF
$chk_run_ids
EOF
}

chk_output_guard() {
  # $1=包根：实际输出号集合 == 注册表在役集合（扣除语境静默 13/19）
  chk_silent=''
  chk_mirror_root=$(CDPATH='' cd -- "$1/.." 2>/dev/null && pwd) || chk_mirror_root=''
  if [ -z "$chk_mirror_root" ] || { [ ! -d "$chk_mirror_root/scripts" ] && [ ! -d "$chk_mirror_root/rules/implementation/scripts" ]; }; then
    chk_silent="$chk_silent 13"
  fi
  if ! git -C "$1" rev-parse --git-dir >/dev/null 2>&1; then
    chk_silent="$chk_silent 19"
  fi
  chk_expected_ids=$(printf '%s\n' "$chk_run_ids" | LC_ALL=C awk -v sk="$chk_silent " 'BEGIN { n = split(sk, a, " "); for (i = 1; i <= n; i++) if (a[i] != "") s[a[i]] = 1 } !($0 in s)')
  chk_actual_ids=$(LC_ALL=C sort -n "$chk_emitted_ids")
  if [ "$chk_actual_ids" != "$chk_expected_ids" ]; then
    printf '%s\n' "$chk_expected_ids" > "$chk_emitted_ids.expected"
    printf '%s\n' "$chk_actual_ids" > "$chk_emitted_ids.actual"
    chk_missing=$(LC_ALL=C awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' "$chk_emitted_ids.actual" "$chk_emitted_ids.expected")
    chk_extra=$(LC_ALL=C awk 'NR == FNR { want[$0] = 1; next } !($0 in want)' "$chk_emitted_ids.expected" "$chk_emitted_ids.actual")
    chk_missing=$(printf '%s' "$chk_missing" | tr '\n' ' ')
    chk_extra=$(printf '%s' "$chk_extra" | tr '\n' ' ')
    printf 'check-package: 错误：检查输出不完整（fail-closed，不产生部分结论）：缺失号 [%s] 多余号 [%s]\n' "$chk_missing" "$chk_extra" >&2
    exit 2
  fi
}
