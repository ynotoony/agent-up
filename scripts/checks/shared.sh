#!/bin/sh
# Input: check-package.sh 分发前载入；函数参数为包根相对数据（索引文件路径、输出临时文件）。
# Output: 共享只读派生函数（检查件之间零隐式状态；每件按需自算，退役/崩溃不传导）。
# Pos: 检查件共享辅助模块（注册表发现面仅含检查件 NN-slug.sh；本件由引擎固定载入）。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

chk_index_mech_load() {
  # $1=索引文件 $2=输出临时文件（机制列投影：ID<TAB>机制单元格）→ stdout＝行数
  _cim_idx=$1
  _cim_out=$2
  : > "$_cim_out"
  if [ -f "$_cim_idx" ]; then
    LC_ALL=C awk -F'|' '
      /^\| R-[A-Z][A-Z]-[0-9][0-9][0-9] /{
        id = $2; gsub(/[ \t]/, "", id)
        cell = $6
        sub(/^[ \t]+/, "", cell); sub(/[ \t]+$/, "", cell)
        if (cell == "") next
        print id "\t" cell
      }
    ' "$_cim_idx" >> "$_cim_out"
  fi
  LC_ALL=C awk 'NF { n++ } END { print n + 0 }' "$_cim_out"
}

# ============================================================
# 票 286 D4：checks 公共原语（MUST 扫描／词法路径折叠／失效豁免核对／Markdown 表提取／
# main-only 判定／worktree 语境文案）——6 组重复归一到本件，检查件只调用不复制。
# 口径：函数只做只读派生，零隐式状态；问题报告仍由调用方 add_problem 承载（判定文案
# 留在各件，逐件可读）；每件按需自算，退役/崩溃不传导。
# ============================================================

# chk_must_block_scan <pkg_root> <文件清单> <mode: adapters|package> <输出文件>
# MUST/MUST NOT 规则块内【待定】来源标记扫描（检查 25 adapters 面与检查 33 整包面同源）：
# 标题窗口＝#### R-<短码>-NNN 且 Level 收尾为 MUST/MUST NOT；行级豁免标记
# <!-- pending-decl-exempt: 理由 -->。输出行＝tag<TAB>包根相对路径<TAB>行号，tag ∈
# HIT／STALE／BADREASON／EXEMPT。package 面另按检查 33 原口径：纯注释行整行跳过、标记须
# 为行尾 HTML 注释（--> 之后仅空白）；adapters 与原检查 25 口径一致。返回 awk 退出码。
chk_must_block_scan() {
  _cmb_pkg=$1
  _cmb_list=$2
  _cmb_mode=$3
  _cmb_out=$4
  # shellcheck disable=SC2046,SC2086  # $(cat) 文件清单刻意分词——逐文件作 awk 多文件参数（包路径无空白，清单校验禁空白路径，检查 22/25/33 同款形态）
  LC_ALL=C awk -v pr="$_cmb_pkg" -v mode="$_cmb_mode" '
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
      # 包根可能带尾斜杠（调用方传 "$pkg_root/" 形态）：先在 pr 侧归一尾斜杠，剥前缀后
      # 再去残余前导斜杠（find 对双重斜杠原样保留）——两形态输出同一包根相对路径。
      rp = pr
      while (length(rp) > 1 && substr(rp, length(rp), 1) == "/") rp = substr(rp, 1, length(rp) - 1)
      rel = FILENAME
      if (index(rel, rp) == 1) {
        rel = substr(rel, length(rp) + 2)
        while (substr(rel, 1, 1) == "/") rel = substr(rel, 2)
      }
      if (mode == "package") {
        trimmed = $0
        sub(/^[ \t]+/, "", trimmed)
        if (substr(trimmed, 1, 4) == "<!--") next
      }
      hastag = index($0, "【待定】") > 0
      p = index($0, tok)
      valid = 0
      reason = ""
      if (p > 0) {
        rest = substr($0, p + length(tok))
        e = index(rest, "-->")
        if (mode == "package") {
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
        } else {
          reason = e > 1 ? substr(rest, 1, e - 1) : ""
          gsub(/^[ \t]+/, "", reason)
          gsub(/[ \t]+$/, "", reason)
          valid = 1
        }
      }
      if (mode == "package") {
        if (!valid && !hastag) next
        if (valid) {
          if (!inmust || !hastag) printf "STALE\t%s\t%d\n", rel, FNR
          else if (reason == "") printf "BADREASON\t%s\t%d\n", rel, FNR
          else printf "EXEMPT\t%s\t%d\n", rel, FNR
        } else if (inmust) {
          printf "HIT\t%s\t%d\n", rel, FNR
        }
        next
      }
      if (!hastag && p == 0) next
      if (p > 0) {
        if (!inmust || !hastag) printf "STALE\t%s\t%d\n", rel, FNR
        else if (reason == "") printf "BADREASON\t%s\t%d\n", rel, FNR
        else printf "EXEMPT\t%s\t%d\n", rel, FNR
      } else if (inmust) {
        printf "HIT\t%s\t%d\n", rel, FNR
      }
    }
  ' $(cat "$_cmb_list") > "$_cmb_out"
}

# chk_lex_fold <路径>（检查 20 symlink 目标与检查 21 行内链接共用的词法折叠）
# 逐段折叠空段／点段／可消解双点段，输出无前导斜杠的词法路径；双点段折出顶层时输出
# ESCAPE（调用方判越界）。纯词法判定，不展开路径 symlink，不依赖 readlink -f。
chk_lex_fold() {
  _clf_acc=$1
  _clf_out=''
  _clf_i=1
  _clf_n=$(printf '%s' "$_clf_acc" | LC_ALL=C awk '{ n = split($0, p, "/"); print n }')
  while [ "$_clf_i" -le "$_clf_n" ]; do
    _clf_seg=$(printf '%s' "$_clf_acc" | LC_ALL=C awk -v i="$_clf_i" '{ n = split($0, p, "/"); print p[i] }')
    case $_clf_seg in
      '') ;;
      .) ;;
      ..)
        if [ -z "$_clf_out" ]; then
          printf 'ESCAPE'
          return 0
        fi
        case $_clf_out in
          */*) _clf_out=$(dirname "$_clf_out") ;;
          *) _clf_out='' ;;
        esac
        ;;
      *)
        if [ -n "$_clf_out" ]; then
          _clf_out="$_clf_out/$_clf_seg"
        else
          _clf_out=$_clf_seg
        fi
        ;;
    esac
    _clf_i=$((_clf_i + 1))
  done
  printf '%s' "$_clf_out"
}

# chk_exempt_stale <豁免登记文件> <命中类型文案> <mode: substring|regex|fields>
# （stdin＝命中账本行 <rel>:<ln>:...）
# 行级「失效豁免」核对唯一实现（检查 12 词表／18 票号／24 legacy 引用同款防漂移口径）：
# 登记行在命中账本中无对应 <rel>:<ln> 行即 add_problem 指名。匹配口径按调用方原语义
# 参数化——统一实现不得改变各检查的判定口径（票 286 复审）：
#   substring＝账本任意位置含 <rel>:<ln>:（检查 12 原口径；尾冒号防行号字符串前缀误罩）
#   regex    ＝<rel>:<ln>: 作行首正则匹配（检查 18 原口径；路径内正则元字符按原样生效）
#   fields   ＝账本逐行按 : 切分后字段 1/2 精确相等（检查 24 原口径）
chk_exempt_stale() {
  _ces_ex=$1
  _ces_kind=$2
  _ces_mode=${3:-substring}
  [ -s "$_ces_ex" ] || return 0
  _ces_hits=$(cat)
  while IFS="$TAB" read -r _ces_rel _ces_ln _ces_rest; do
    [ -n "$_ces_rel" ] || continue
    case $_ces_mode in
      regex)
        if ! printf '%s\n' "$_ces_hits" | LC_ALL=C grep -qE "^$_ces_rel:$_ces_ln:" 2>/dev/null; then
          add_problem "  - 失效豁免（登记行无${_ces_kind}，须复核更新或删除登记）: $_ces_rel:$_ces_ln"
        fi
        ;;
      fields)
        if ! printf '%s\n' "$_ces_hits" | LC_ALL=C awk -F':' -v p="$_ces_rel" -v l="$_ces_ln" \
          '$1 == p && $2 == l { f = 1 } END { exit f ? 0 : 1 }'; then
          add_problem "  - 失效豁免（登记行无${_ces_kind}，须复核更新或删除登记）: $_ces_rel:$_ces_ln"
        fi
        ;;
      *)
        case $_ces_hits in
          *"$_ces_rel:$_ces_ln:"*) : ;;
          *)
            add_problem "  - 失效豁免（登记行无${_ces_kind}，须复核更新或删除登记）: $_ces_rel:$_ces_ln"
            ;;
        esac
        ;;
    esac
  done < "$_ces_ex"
}

# chk_table_rows <文件> <表头锚点行>（检查 9 成员表；锚点后表体提取）
# 锚点行＝首列表头行（以 | 开头的字面行）；输出锚点之后的表体行，遇首个非 | 行结束。
chk_table_rows() {
  LC_ALL=C awk -v anchor="$2" 'index($0, anchor) == 1 { f = 1; next } f { if ($0 !~ /^\|/) f = 0; else print }' "$1"
}

# chk_is_mainonly <值> <mode: rel|basename>（检查 8/9 worktree 语境 main-only 过滤）
# rel＝包根相对路径（mainonly 条含 agent-up/ 前缀，比较前去前缀）；basename＝只看文件名。
# 命中返回 0，否则 1。mainonly 清单由引擎分发前派生（$mainonly_list，delivery.rules
# dp_mainonly 行；worktree 语境才非空）。
chk_is_mainonly() {
  _cim_val=$1
  _cim_mode=rel
  if [ $# -ge 2 ] && [ -n "$2" ]; then
    _cim_mode=$2
  fi
  for _cim_mo in $mainonly_list; do
    case $_cim_mode in
      basename)
        _cim_base=$(basename "$_cim_mo")
        [ "$_cim_val" = "$_cim_base" ] && return 0
        ;;
      *)
        _cim_rel=$_cim_mo
        case $_cim_rel in
          agent-up/*) _cim_rel=$(printf '%s' "$_cim_rel" | cut -c 10-) ;;
        esac
        [ "$_cim_val" = "$_cim_rel" ] && return 0
        ;;
    esac
  done
  return 1
}

# chk_worktree_suffix <worktree 语境文案>（检查 8/9 的 worktree/主检出双分支合并）
# worktree 语境输出该文案，主检出语境输出空——供 _chk_desc／_chk_skip 与问题行后缀共用，
# 两分支合并为单分支（判定逻辑零副本）。
chk_worktree_suffix() {
  if [ "$in_worktree" -eq 1 ]; then
    printf '%s' "$1"
  fi
}
