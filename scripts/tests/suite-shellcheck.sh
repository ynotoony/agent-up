#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite shellcheck "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


# ============================================================
# suite: shellcheck（静态分析门禁面：脚本全量零告警；豁免逐项有证——
# disable 指令必须同行带理由注释，防无证关检查；环境依赖 shellcheck，
# 缺失即套件零断言跳过（不制造假绿），由调用方按环境依赖口径处置）
# ============================================================

suite_shellcheck() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='shellcheck'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/shellcheck
  mkdir -p "$D"

  if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'test-record-layer: NOTE suite=shellcheck 环境缺 shellcheck——套件零断言跳过（不制造假绿；门禁语义归调用方按环境依赖口径处置）\n'
    suite_summary 'shellcheck'
    return 0
  fi

  # 被测清单：find 枚举（harness 顶层 set -f 禁 shell glob，不能用 *.sh 通配）
  _sh_list="$D/files.txt"
  find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' | LC_ALL=C sort > "$_sh_list"
  _sh_n=$(wc -l < "$_sh_list" | tr -d ' ')
  if [ "$_sh_n" -eq 0 ]; then
    bad '脚本全量 shellcheck 零告警' "被测目录无 .sh 文件: $SCRIPT_DIR"
    suite_summary 'shellcheck'
    return 0
  fi

  _sh_sc_out="$D/all.out"
  # set -u/-f 语境（无 set -e）：非零退出码显式接住；清单经 xargs 展开（禁裸
  # $() 词分割——新门禁自身口径）；路径含空白的落位不受支持（家族先例 S4 同款口径）
  xargs shellcheck > "$_sh_sc_out" 2>&1 < "$_sh_list"
  _sh_rc=$?
  if [ "$_sh_rc" -eq 0 ]; then
    ok "脚本全量 shellcheck 零告警（${_sh_n} 件）"
  else
    bad '脚本全量 shellcheck 零告警' "$(head -n 6 "$_sh_sc_out" | tr '\n' '|')"
  fi

  # 豁免有证断言：disable 指令必须同行带理由注释（防无证关检查——「用关闭检查代替
  # 逐项判断」禁令的机器化）；形态约定＝'# shellcheck disable=SCxxxx  # 理由'，
  # 第二个 # 之后剥空白须非空。awk 程序单引号形态必需（$0 等 awk 内建禁 shell 展开），
  # 模式在 BEGIN 拼接构造（禁字面敏感模式自命中，维护联动同款）；诊断行写独立文件，
  # stdout 只承载计数汇总行（cut 取数面干净）。
  _sh_sc_exempt="$D/exempt.out"
  _sh_sc_diag="$D/exempt-diag.txt"
  # shellcheck disable=SC2016  # awk 程序必须单引号防 shell 展开 $0，展开即破坏语义——SC2016 为形态必需非缺陷
  xargs awk -v diag="$_sh_sc_diag" '
    BEGIN { pat = "# shell" "check disable=" }
    FNR == 1 { file = FILENAME; sub(/.*\//, "", file) }
    index($0, pat) > 0 {
      n++
      rest = $0
      head = index(rest, "#")
      tail = index(substr(rest, head + 1), "#")
      if (tail > 0) {
        rest = substr(substr(rest, head + 1), tail + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", rest)
      } else {
        rest = ""
      }
      if (rest == "") { printf "无证豁免: %s:%d: %s\n", file, FNR, $0 > diag; bad++ }
    }
    END { printf "%d\t%d\n", n + 0, bad + 0 }
  ' > "$_sh_sc_exempt" < "$_sh_list"
  _sh_exempt_n=$(cut -f1 "$_sh_sc_exempt")
  _sh_exempt_bad=$(cut -f2 "$_sh_sc_exempt")
  if [ "$_sh_exempt_bad" -eq 0 ]; then
    ok "豁免有证（disable 指令 ${_sh_exempt_n} 处逐项带理由注释）"
  else
    bad '豁免有证（disable 指令逐项带理由注释）' "$(head -n 4 "$_sh_sc_diag" | tr '\n' '|')"
  fi

  suite_summary 'shellcheck'
}
