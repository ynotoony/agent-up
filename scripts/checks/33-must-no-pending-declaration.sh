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
  # 扫描面组装（base 等价）：先在本地副本归一包根尾斜杠（find 对尾斜杠归一输出，
  # 双重斜杠则原样保留），排除模式与文件路径同源——尾斜杠调用不再让适配器面排除静默
  # 失效；chk_must_block_scan 内的 pr 归一负责把绝对/相对前缀都剥成包根相对路径。
  p33_root=$pkg_root
  while [ "${p33_root%/}" != "$p33_root" ]; do p33_root=${p33_root%/}; done
  find "$p33_root" -type f \( -name '*.md' -o -name '*.tmpl' \) | LC_ALL=C sort \
    | grep -vF "$p33_root/references/adapters/" > "$p33_list" || true
if [ ! -s "$p33_list" ]; then
  add_problem '  - 待定规范声明检测整包面零 md/tmpl 文件（扫描面失效）'
else
  pd33_rc=0
  chk_must_block_scan "$pkg_root" "$p33_list" package "$p33_out" || pd33_rc=$?
  if [ "$pd33_rc" -ne 0 ]; then
    printf 'check-package: 错误：检查 33 扫描器异常（awk exit %s）\n' "$pd33_rc" >&2
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
