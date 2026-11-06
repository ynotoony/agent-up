#!/bin/sh
# Input: check_12 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_vague_exempt,pm_vague_word
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 12（vague-words）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 12：规则块体无模糊措辞（票 58 新增）。词表外置清单 vague-words 节（引擎零词表
# 硬编码，字面匹配非正则）；行级豁免外置 vague-exemptions 节（路径＋行号＋理由；登记行
# 无命中即失效豁免 FAIL，防行号漂移静默失效）。扫描窗口＝包内全部 *.md 与 *.tmpl 的
# R-<短码>-NNN 规则块体（块头行起至下一标题行止，块头本身不扫，规则块结构同
# governance-format.md R-GF-001）；排除「解释与例外」节（标题含该标记起至下一标题止）
# 与各 README 文件（叙事面）；manifest 自身词表行为 .rules 数据文件，不在 md/tmpl
# 扫描文件面（零自命中）。

check_12() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_words=$(wc -l < "$pm_words" | tr -d ' ')
n_exempt=0
[ -s "$pm_exempts" ] && n_exempt=$(wc -l < "$pm_exempts" | tr -d ' ')
words_col=$(LC_ALL=C awk -F'\t' '{print $1}' "$pm_words")
hits_all=''
OLDIFS=$IFS
IFS='
'
for f in $file_list; do
  IFS=$OLDIFS
  case $f in
    */README.md) continue ;;
  esac
  rel=${f#"${pkg_root}/"}
  # 词表经环境变量传入（BSD awk 对含字面换行的 -v 赋值报 "newline in string"，
  # ENVIRON 承载多行值可靠）；awk 异常即 exit 2 fail-closed——扫描器失效不得静默
  # 当作零命中放过（否则词表扫描形同虚设）。
  awk_rc=0
  fhits=$(LC_ALL=C WORDS="$words_col" awk -v rel="$rel" '
    BEGIN { nw = split(ENVIRON["WORDS"], W, "\n") }
    /^#### R-[A-Z][A-Z]-[0-9][0-9][0-9][ \t]/ { inblk = 1; next }
    /^#/ {
      if (index($0, "解释与例外") > 0) expl = 1; else expl = 0
      inblk = 0
      next
    }
    inblk == 1 && expl != 1 {
      for (k = 1; k <= nw; k++) {
        if (W[k] != "" && index($0, W[k]) > 0) printf "%s:%d:%s\n", rel, FNR, W[k]
      }
    }
  ' "$f") || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 12 扫描器异常（awk exit %s）: %s\n' "$awk_rc" "$f" >&2
    exit 2
  fi
  if [ -n "$fhits" ]; then
    hits_all="$hits_all$fhits
"
  fi
done
IFS=$OLDIFS
if [ -n "$hits_all" ]; then
  OLDIFS=$IFS
  IFS='
'
  for h in $hits_all; do
    IFS=$OLDIFS
    h_word=${h##*:}
    h_rest=${h%:*}
    h_ln=${h_rest##*:}
    h_rel=${h_rest%:*}
    # 尾锚精确匹配（协调层 Review 改判随票修）：检索键带尾制表符——豁免行结构为
    # 路径\t行号\t理由（理由经结构校验非空且无制表符），故 "path\t82\t" 只匹配行 82
    # 的豁免行，不匹配 "path\t820\t..."——行号的字符串前缀关系不得误罩其他行命中。
    if ! grep -qF "$(printf '%s\t%s\t' "$h_rel" "$h_ln")" "$pm_exempts"; then
      add_problem "  - $h_rel:$h_ln 命中模糊措辞「${h_word}」"
    fi
  done
  IFS=$OLDIFS
fi
# 失效豁免核对：登记行无命中即 FAIL（检查 12 同款口径，防漂移静默失效）——核对唯一
# 实现＝shared.sh chk_exempt_stale（票 286 D4）。
chk_exempt_stale "$pm_exempts" '词表命中' substring <<EOF
$hits_all
EOF
if [ -n "$problems" ]; then
  _chk_desc="规则块体无模糊措辞（词表 ${n_words} 词，豁免 ${n_exempt} 行）"
else
  _chk_desc="规则块体无模糊措辞（词表 ${n_words} 词，豁免 ${n_exempt} 行）"
fi
:
}
