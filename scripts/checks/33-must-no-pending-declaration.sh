#!/bin/sh
# Input: check_33 所需包根/清单派生数据（由 check-package.sh 分发前载入）：-
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 33（must-no-pending-declaration）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 33：MUST 不引用待定规范事实（票 219 新增；212 交付面整包核对）。检查 25 的
# 适配域专项面之外，本项把同一禁令扩到整包其余 *.md/*.tmpl（两面并集＝整包闭合）：
# `#### R-<短码>-NNN` 标题 Level 为 MUST/MUST NOT 的块体内出现【待定】来源标记即 FAIL
# 指名文件:行号；行内豁免标记 <!-- pending-decl-exempt: 理由 --> 同 25 语义（须在 MUST
# 块内、有【待定】命中、理由非空，否则失效豁免 FAIL）。

check_33() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n33_hits=0
n33_exempt=0
p33_list=$(mktemp "${t_dir%/}/pend33.XXXXXX")
p33_out=$(mktemp "${t_dir%/}/pend33.XXXXXX")
(cd "$pkg_root" && find . -type f \( -name '*.md' -o -name '*.tmpl' \) | sed 's|^\./||' | LC_ALL=C sort) \
  | grep -v '^references/adapters/' > "$p33_list" || true
if [ ! -s "$p33_list" ]; then
  add_problem '  - 待定规范声明检测整包面零 md/tmpl 文件（扫描面失效）'
else
  awk_rc=0
  # shellcheck disable=SC2046,SC2086  # $(cat) 文件清单刻意分词——逐文件作 awk 多文件参数（包路径无空白，清单校验禁空白路径，检查 22/25 同款形态）
  (cd "$pkg_root" && LC_ALL=C awk '
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
      # 标记形态＝行尾 HTML 注释（`-->` 之后仅空白）：散文提及豁免标记（表格说明、契约头
      # 注释块）不是豁免指令本身；纯注释行（首个非空白字符起即 <!--）整行跳过。
      trimmed = $0
      sub(/^[ \t]+/, "", trimmed)
      if (substr(trimmed, 1, 4) == "<!--") next
      hastag = index($0, "【待定】") > 0
      p = index($0, tok)
      valid = 0
      reason = ""
      if (p > 0) {
        rest = substr($0, p + length(tok))
        e = index(rest, "-->")
        if (e > 0) {
          tail = substr(rest, e + 3)
          gsub(/[ \t]+/, "", tail)
          if (tail == "") {
            valid = 1
            reason = substr(rest, 1, e - 1)
            gsub(/^[ \t]+/, "", reason)
            gsub(/[ \t]+$/, "", reason)
          }
        }
      }
      if (!valid && !hastag) next
      if (valid) {
        if (!inmust || !hastag) printf "STALE\t%s\t%d\n", FILENAME, FNR
        else if (reason == "") printf "BADREASON\t%s\t%d\n", FILENAME, FNR
        else printf "EXEMPT\t%s\t%d\n", FILENAME, FNR
      } else if (inmust) {
        printf "HIT\t%s\t%d\n", FILENAME, FNR
      }
    }
  ' $(cat "$p33_list")) > "$p33_out" || awk_rc=$?
  if [ "$awk_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 33 扫描器异常（awk exit %s）\n' "$awk_rc" >&2
    rm -f "$p33_list" "$p33_out"
    exit 2
  fi
  while IFS="$(printf '\t')" read -r _pd3_tag _pd3_rel _pd3_ln; do
    [ -n "$_pd3_tag" ] || continue
    case $_pd3_tag in
      HIT)
        n33_hits=$((n33_hits + 1))
        add_problem "  - ${_pd3_rel}:${_pd3_ln} 冲突类型=MUST 块引用【待定】规范事实（规则 pending-decl · 规范事实须已核验，未核验面用状态词表标注）"
        ;;
      STALE)
        add_problem "  - ${_pd3_rel}:${_pd3_ln} 冲突类型=失效豁免（规则 pending-decl · 标记行无【待定】命中或不在 MUST 块内）"
        ;;
      BADREASON)
        add_problem "  - ${_pd3_rel}:${_pd3_ln} 冲突类型=豁免标记缺理由（规则 pending-decl · 理由必填）"
        ;;
      EXEMPT)
        n33_exempt=$((n33_exempt + 1))
        ;;
    esac
  done < "$p33_out"
fi
rm -f "$p33_list" "$p33_out"
if [ -n "$problems" ]; then
  _chk_desc="MUST 不引用待定规范事实（MUST 块【待定】命中 ${n33_hits} 处，豁免 ${n33_exempt} 行；面＝adapters 外）"
else
  _chk_desc="MUST 不引用待定规范事实（MUST 块【待定】命中 ${n33_hits} 处，豁免 ${n33_exempt} 行；面＝adapters 外）"
fi
:
}
