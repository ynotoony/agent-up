#!/bin/sh
# shellcheck disable=SC2154  # 全局变量与共享原语由 source 方主壳赋值／定义（Input 契约：templates_dir／baseline／script_dir／_engine 与 die1／die2／print_head／print_row 等）
# Input: 由 measure-context-cost.sh 主壳 source 本件——消费其已设选项变量（templates_dir／
#        baseline／script_dir）、_engine 路径与共享输出原语（die1／die2／print_head／
#        print_row／baseline_get／is_int）。
# Output: run_governance 函数体——治理体积模式指标（安装件字符数／规则块数／四阶段读取集
#         字符数）的统计、校验与输出；不执行任何动作、不设 set -eu。
# Pos: 治理体积指标实现（票 290 拆分：与会话指标分开成两件）；本件为 measure-context-cost.sh
#      的同目录模块（包侧独有，不进安装闭包、不落仓侧镜像）。POSIX sh＋python3。

# ---- 治理体积模式 ----

run_governance() {
  if [ -z "$templates_dir" ]; then
    templates_dir=$script_dir/../references/templates
  fi
  if [ ! -d "$templates_dir" ]; then
    die1 "模板目录不存在: $templates_dir"
  fi
  templates_dir=$(CDPATH='' cd -- "$templates_dir" && pwd -P) || die1 "模板目录不可判定: $templates_dir"

  _gov_files='AGENTS.md.tmpl core.md.tmpl project.md.tmpl assessment.md.tmpl discipline.md.tmpl agents-triage.md.tmpl agents-implementation.md.tmpl agents-review.md.tmpl agents-commit.md.tmpl'
  for _f in $_gov_files; do
    [ -f "$templates_dir/$_f" ] || die1 "安装件缺失: $templates_dir/$_f"
  done

  _install_chars=0
  _install_blocks=0
  for _f in $_gov_files; do
    _n=$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$templates_dir/$_f") \
      || die1 "安装件不可读: $templates_dir/$_f"
    is_int "$_n" || die1 "安装件字符数异常: $templates_dir/$_f"
    _install_chars=$((_install_chars + _n))
    _b=$(grep -c '^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]' "$templates_dir/$_f" 2>/dev/null || true)
    [ -n "$_b" ] || _b=0
    _install_blocks=$((_install_blocks + _b))
  done

  _stage_sum() {
    _ss_sum=0
    for _ss_f in "$@"; do
      _ss_n=$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' "$templates_dir/$_ss_f") \
        || die1 "安装件不可读: $templates_dir/$_ss_f"
      _ss_sum=$((_ss_sum + _ss_n))
    done
    printf '%s' "$_ss_sum"
  }

  _triage=$(_stage_sum AGENTS.md.tmpl core.md.tmpl assessment.md.tmpl project.md.tmpl agents-triage.md.tmpl)
  _implementation=$(_stage_sum AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-implementation.md.tmpl)
  _review=$(_stage_sum AGENTS.md.tmpl core.md.tmpl discipline.md.tmpl project.md.tmpl agents-review.md.tmpl)
  _commit=$(_stage_sum AGENTS.md.tmpl core.md.tmpl project.md.tmpl agents-commit.md.tmpl)

  b_install_chars='-'
  b_install_blocks='-'
  b_triage='-'
  b_implementation='-'
  b_review='-'
  b_commit='-'

  if [ -n "$baseline" ]; then
    [ -f "$baseline" ] || die1 "基线文件不存在: $baseline"
    [ -f "$_engine" ] || die2 "唯一 JSON 引擎缺失: $_engine"
    for _k in install_chars install_blocks stage_triage_chars stage_implementation_chars \
      stage_review_chars stage_commit_chars; do
      _bv=$(baseline_get "$_k") || die1 "基线缺指标: $_k"
      is_int "$_bv" || die1 "基线指标非整数: $_k"
      case $_k in
        install_chars) b_install_chars=$_bv ;;
        install_blocks) b_install_blocks=$_bv ;;
        stage_triage_chars) b_triage=$_bv ;;
        stage_implementation_chars) b_implementation=$_bv ;;
        stage_review_chars) b_review=$_bv ;;
        stage_commit_chars) b_commit=$_bv ;;
      esac
    done
  fi

  print_head governance "模板=$templates_dir"
  print_row install_chars "$_install_chars" "$b_install_chars"
  print_row install_blocks "$_install_blocks" "$b_install_blocks"
  print_row stage_triage_chars "$_triage" "$b_triage"
  print_row stage_implementation_chars "$_implementation" "$b_implementation"
  print_row stage_review_chars "$_review" "$b_review"
  print_row stage_commit_chars "$_commit" "$b_commit"
  printf '口径: 安装件=%s 件 字符数=python3 len(UTF-8 文本) 规则块=^#### R-XX-NNN\n' '9'
}
