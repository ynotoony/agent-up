#!/bin/sh
# Input: check_20 所需包根/清单派生数据（由 check-package.sh 分发前载入）：pm_entry,pm_script
# Output: 判定结果（problems 累加 + _chk_desc/_chk_skip），不打印 PASS/FAIL、不碰汇总计数。
# Pos: 包完整性检查 20（package-closure-symlink）检查件；由 checks/registry.rules 发现并由引擎统一报告。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（引擎清单派生变量/前序检查件赋值），单文件视野误报

# 检查 20：包闭合性与符号链接防护（票 149 新增）。三段防线：
#   ①scripts 目录一级条目闭合——条目面（find 一级条目）须 ⊆ 闭合白名单＝清单
#     scripts 节登记件 ∪ 引擎自身（check-package.sh）∪ 成员表（README.md）∪ 清单
#     数据件自身（package-manifest.rules，与 pm_rules 同源取名）；未登记额外脚本/
#     文件（含恶意投放）即 FAIL 指名条目。
#   ②包内 symlink 防外指——全部包内 symlink 的 readlink 原始目标折算为绝对词法形态
#     后逐段折叠（点段折叠，resolve_within；词法判定不展开中间路径 symlink），折出
#     包根词法域即 FAIL 指名 symlink（含断链）；外指 symlink 会绕过 grep/find -type f
#     的内容扫描面，放行＝包闭合性结论不可靠。readlink 原始目标＋词法规范化为 POSIX
#     通行路径，不依赖 GNU readlink -f。
#   ③登记路径 symlink 禁令——检查 1 必需入口登记路径（entry-files）与必需目录
#     （references/、scripts/ 目录自身及其子路径前缀面）不得为 symlink（包内别名或
#     包外指向一体拦截；[ -f ] 跟随 symlink 的既有判定对此天然盲视）。
# 闭合白名单零硬编码文件名：引擎自身、成员表与清单数据件名分别同 $0、
# scripts_readme_rel 路径常量与 pm_rules 载入路径同源。

resolve_within() {
  # $1=symlink 路径（与 find 输出同形态）：输出 readlink 原始目标经词法规范化（点段
  # 折叠）后的包根相对路径；越出包根输出 ESCAPE，断链（折叠后不存在）输出 BROKEN。
  # POSIX 通行路径：只用 readlink 原始目标＋词法折叠，不依赖 GNU readlink -f；中间
  # 路径组件的 symlink 不展开（词法判定，注记见 README.md）。
  _rl_target=$(readlink "$1")
  case $_rl_target in
    /*) _rl_acc=$_rl_target ;;
    *) _rl_acc=$(dirname "$1")/$_rl_target ;;
  esac
  _rl_out=''
  _rl_i=1
  _rl_n=$(printf '%s' "$_rl_acc" | LC_ALL=C awk '{ n = split($0, p, "/"); print n }')
  while [ "$_rl_i" -le "$_rl_n" ]; do
    _rl_seg=$(printf '%s' "$_rl_acc" | LC_ALL=C awk -v i="$_rl_i" '{ n = split($0, p, "/"); print p[i] }')
    case $_rl_seg in
      '') ;;
      .) ;;
      ..)
        if [ -z "$_rl_out" ]; then
          printf 'ESCAPE'
          return 0
        fi
        case $_rl_out in
          */*) _rl_out=${_rl_out%/*} ;;
          *) _rl_out='' ;;
        esac
        ;;
      *)
        if [ -n "$_rl_out" ]; then
          _rl_out="$_rl_out/$_rl_seg"
        else
          _rl_out=$_rl_seg
        fi
        ;;
    esac
    _rl_i=$((_rl_i + 1))
  done
  # 折叠体为无前导斜杠的绝对路径词法形态，与包根词法体（pkg_root_rel）比对：
  # 前缀剥离＝包根内（输出包根相对路径）；恰等包根＝根外相对空间；其余＝包根外。
  case $_rl_out in
    "${pkg_root_rel}"/*)
      _rl_out=${_rl_out#"$pkg_root_rel"/}
      if [ -e "$pkg_root/$_rl_out" ]; then
        printf '%s' "$_rl_out"
      else
        printf 'BROKEN'
      fi
      ;;
    *) printf 'ESCAPE' ;;
  esac
}

check_20() {
  # $1=包根（契约参数；检查件只读判定，报告问题经 add_problem）
problems=''
n_closure=0
n_extra=''
n_syms=0
n_escape=''
n_alias=''
scripts_dir_abs="$pkg_root/$scripts_dir"
pkg_root_abs=${pkg_root%/}
pkg_root_rel=${pkg_root_abs#/}
if [ -d "$scripts_dir_abs" ]; then
  OLDIFS=$IFS
  IFS='
'
  for _c_entry in $(find "$scripts_dir_abs" -mindepth 1 -maxdepth 1 | LC_ALL=C sort); do
    IFS=$OLDIFS
    _c_name=${_c_entry##*/}
    if ! grep -qF "$(printf '%s\t' "$scripts_dir/$_c_name")" "$pm_scripts" \
      && [ "$_c_name" != "$(basename "$0")" ] \
      && [ "$_c_name" != "${scripts_readme_rel##*/}" ] \
      && [ "$_c_name" != "$(basename "$pm_rules")" ]; then
      n_extra="$n_extra$sep2$_c_name"
      sep2='、'
    fi
    n_closure=$((n_closure + 1))
  done
  IFS=$OLDIFS
fi
if [ -n "$n_extra" ]; then
  add_problem "  - scripts/ 一级存在未登记条目（闭合白名单＝scripts 节登记件∪引擎∪成员表∪清单件）: $n_extra"
fi
sep2=''
sep_e=''
sep_a=''
OLDIFS=$IFS
IFS='
'
for _s in $(find "$pkg_root" -type l | LC_ALL=C sort); do
  IFS=$OLDIFS
  n_syms=$((n_syms + 1))
  _s_rel=${_s#"$pkg_root_abs"/}
  _s_res=$(resolve_within "$_s")
  case $_s_res in
    BROKEN)
      # 花括号不可省略：变量名后紧跟全角字符时防止吞并（先例检查 5/12/17）
      n_alias="$n_alias$sep_a${_s_rel}（断链）"
      sep_a='、'
      ;;
    ESCAPE)
      n_escape="$n_escape$sep_e$_s_rel"
      sep_e='、'
      ;;
    *)
      # 别名判定面＝必需目录（references/、scripts/）∪ 检查 1 必需入口登记路径
      # （entry-files 精确整行匹配）：登记件被包内 symlink 偷换同样进 FAIL 面。
      _s_hit=''
      case $_s_rel in
        references|references/*|"$scripts_dir"|"$scripts_dir"/*) _s_hit=1 ;;
      esac
      if [ -z "$_s_hit" ] && grep -qxF "$_s_rel" "$pm_entries"; then
        _s_hit=1
      fi
      if [ -n "$_s_hit" ]; then
        n_alias="$n_alias$sep_a$_s_rel"
        sep_a='、'
      fi
      ;;
  esac
done
IFS=$OLDIFS
if [ -n "$n_escape" ]; then
  add_problem "  - 包内 symlink 指向包根外部: $n_escape"
fi
if [ -n "$n_alias" ]; then
  add_problem "  - 登记路径或必需目录为 symlink/别名: $n_alias"
fi
if [ -n "$problems" ]; then
  _chk_desc="包闭合性与符号链接防护（scripts 一级 ${n_closure} 项，symlink ${n_syms} 个）"
else
  _chk_desc="包闭合性与符号链接防护（scripts 一级 ${n_closure} 项，symlink ${n_syms} 个）"
fi
:
}
