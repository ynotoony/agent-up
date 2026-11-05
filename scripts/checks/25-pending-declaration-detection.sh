#!/bin/sh
# Input: check_25 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 25（pending-declaration-detection）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 25：待定规范声明检测（票 212 新增）。规范规则只引用已核验事实——MUST/MUST NOT
# 规则块内不得出现【待定】来源标记（未核验面在规则块内用状态词表标注：pending/
# unsupported/local-observation；本地实验记录移出 MUST 正文降为注记形态）。
# 扫描面＝references/adapters/ 全部 *.md（宿主映射手册是适配证据的规范承载面；引擎
# 硬编码该域路径，先例检查 21 的 references/ 与检查 24 的 governance-format.md 域常量；
# 写入指引面豁免见下）。窗口＝#### R-<短码>-NNN 标题 Level 为 MUST/MUST NOT 的规则块
#（标题行起至下一标题行止，检查 22 同款窗口口径）：
#   ①块内行含【待定】即 FAIL 指名文件:行号；
#   ②行级豁免＝命中行内显式标记 <!-- pending-decl-exempt: <理由> -->（理由必填）：
#     只限写入指引面（【待定】标记机制的指令行本体，如 adapter-template.md R-AT-001
#     Stop if）；标记行无【待定】命中、不在 MUST 块内或缺理由 → 失效豁免 FAIL
#    （检查 12/18/24 同款防漂移口径）。零 git 依赖。

check_25() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n25_hits=0
n25_exempt=0
pd25_dir="$pkg_root/references/adapters"
if [ ! -d "$pd25_dir" ]; then
  add_problem '  - 待定规范声明检测扫描面不存在: references/adapters'
else
  pd25_list=$(mktemp "${t_dir%/}/pend25.XXXXXX")
  pd25_out=$(mktemp "${t_dir%/}/pend25.XXXXXX")
  find "$pd25_dir" -type f -name '*.md' | LC_ALL=C sort > "$pd25_list"
  if [ ! -s "$pd25_list" ]; then
    add_problem '  - 待定规范声明检测扫描面零 md 文件: references/adapters'
  else
    awk_rc=0
    # shellcheck disable=SC2046,SC2086  # $(cat) 文件清单刻意分词——find 逐文件作 awk 多文件参数（包路径无空白，清单校验禁空白路径，检查 22 同款形态）
    LC_ALL=C awk -v pr="$pkg_root" '
      BEGIN { tok = "<!-- pending-decl-exempt:" }
      FNR == 1 { inmust = 0 }
      /^#/ {
        if ($0 ~ /^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]([ \t]|$)/) {
          t = $0
          gsub(/`/, "", t)
          inmust = (t ~ /(MUST NOT|MUST)[ \t]*$/) ? 1 : 0
        } else {
          inmust = 0
        }
        next
      }
      {
        hastag = index($0, "【待定】") > 0
        p = index($0, tok)
        if (!hastag && p == 0) next
        rel = FILENAME
        if (index(rel, pr) == 1) rel = substr(rel, length(pr) + 2)
        if (p > 0) {
          rest = substr($0, p + length(tok))
          e = index(rest, "-->")
          reason = e > 1 ? substr(rest, 1, e - 1) : ""
          gsub(/^[ \t]+/, "", reason)
          gsub(/[ \t]+$/, "", reason)
          if (!inmust || !hastag) printf "STALE\t%s\t%d\n", rel, FNR
          else if (reason == "") printf "BADREASON\t%s\t%d\n", rel, FNR
          else printf "EXEMPT\t%s\t%d\n", rel, FNR
        } else if (inmust) {
          printf "HIT\t%s\t%d\n", rel, FNR
        }
      }
    ' $(cat "$pd25_list") > "$pd25_out" || awk_rc=$?
    if [ "$awk_rc" -ne 0 ]; then
      printf 'check-package: 错误：检查 25 扫描器异常（awk exit %s）\n' "$awk_rc" >&2
      rm -f "$pd25_list" "$pd25_out"
      exit 2
    fi
    while IFS="$(printf '\t')" read -r _pd_tag _pd_rel _pd_ln; do
      [ -n "$_pd_tag" ] || continue
      case $_pd_tag in
        HIT)
          n25_hits=$((n25_hits + 1))
          add_problem "  - ${_pd_rel}:${_pd_ln} MUST 块命中【待定】来源标记（规范事实须已核验；未核验面用状态词表 pending/unsupported/local-observation 标注，本地实验记录移出 MUST 正文）"
          ;;
        STALE)
          add_problem "  - ${_pd_rel}:${_pd_ln} 失效豁免（pending-decl-exempt 标记行无【待定】命中或不在 MUST 块内，须复核更新或删除标记）"
          ;;
        BADREASON)
          add_problem "  - ${_pd_rel}:${_pd_ln} 豁免标记缺理由（<!-- pending-decl-exempt: 理由 -->，理由必填）"
          ;;
        EXEMPT)
          n25_exempt=$((n25_exempt + 1))
          ;;
      esac
    done < "$pd25_out"
  fi
  rm -f "$pd25_list" "$pd25_out"
fi
if [ -n "$problems" ]; then
  _chk_desc="待定规范声明检测（MUST 块【待定】命中 ${n25_hits} 处，豁免 ${n25_exempt} 行）"
else
  _chk_desc="待定规范声明检测（MUST 块【待定】命中 ${n25_hits} 处，豁免 ${n25_exempt} 行）"
fi
:
}
