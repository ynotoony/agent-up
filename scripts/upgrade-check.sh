#!/bin/sh
# Input: 包基线目录 <pkg-dir>（clone/pull 后的 agent-up 包根，含 scripts/ 与 references/）
#        与目标项目根 <repo-root>（已按本体系初始化）；两位置参数。
# Output: 落地面 vs 包基线的逐件三态对账（全程只读，零写入 fail-closed）——
#         落位脚本：install-policy.rules 登记件在目标仓两落位形态
#         （rules/implementation/scripts/ 新布局／scripts/ 旧布局）下逐件 cmp 包内同名件：
#         两形态皆缺失＝落后（未安装）；字节一致＝同步；存在但不一致＝漂移（可能人工改过）。
#         配置面：仓根 delivery.rules 的 main-only 节锚点行与包内 delivery-rules.tmpl 对照
#         （只对照锚点行存在性——节在＝同步，节缺＝落后；条目差异＝项目事实不判）。
#         模板生成件（rules/ 规则三件等）：规则块 ID 集核对（#### R-XX-NNN 标题抽取，实例缺块=落后列块 ID，
#         实例多余块=登记分歧候选不误报——块级语义差异归独立 Review），不判漂移，
#         附 references/upgrade.md 指路。逐件行＋汇总行；退出码 0 全同步／1 有差距／
#         2 用法或环境错误（参数数量不合、pkg-dir 或 repo-root 不存在、install-policy.rules
#         或 delivery-rules.tmpl 缺失）。
# Pos: 落地面对账器（升级一等流程②；check 系家族件——POSIX sh、零外部依赖、全程只读、
#      fail-closed）：把"消费者仓手里有包基线却看不见差距"机制化（源仓检查 13 mirrors
#      是包侧↔仓根镜像特权，本件面向任意消费者仓）；升级流程入口＝references/upgrade.md
#      （三态处置、漂移裁决、reconcile 规则权威均在彼处与目标项目 rules/project.md，
#      本件只对账不出修复动作——与 check 系 --fix 准则的配对条件留待后续票评估）。
#      引擎零落位路径硬编码：cmp 面自同目录 install-policy.rules 数据读取（先例
#      install.sh 同款加载）；锚点对照仅认全形锚点行（# ==== X：…====），不做部分匹配。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

prog=upgrade-check

usage() {
  cat <<'USAGE'
用法: sh upgrade-check.sh <pkg-dir> <repo-root>
参数:
  pkg-dir    包基线目录（clone/pull 后的 agent-up 包根，含 scripts/ 与 references/）。
  repo-root  目标项目根目录（已按本体系初始化）。
对账口径（全程只读）:
  落位脚本  install-policy.rules 登记件在 <repo-root>/rules/implementation/scripts/ 与
            <repo-root>/scripts/ 两形态下逐件 cmp 包内同名件：皆缺失＝落后（未安装）；
            一致＝同步；存在但不一致＝漂移。
  配置面    仓根 delivery.rules main-only 节锚点行与包内 delivery-rules.tmpl 对照
            （锚点行存在性：节在＝同步、节缺或文件缺＝落后；条目差异不判）。
  模板生成件  rules/ 规则三件与包内拆三模板的对应关系列出（只提示不判漂移），
            指路 references/upgrade.md 人工核对。
退出码: 0 全同步；1 有差距（落后/漂移行见输出）；2 用法或环境错误。
USAGE
}

die2() {
  printf '%s: 错误：%s\n' "$prog" "$1" >&2
  exit 2
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
esac
[ $# -eq 2 ] || { usage >&2; exit 2; }
pkg_dir=$1
repo_root=$2
[ -d "$pkg_dir" ] || die2 "包基线目录不存在: $pkg_dir"
[ -d "$repo_root" ] || die2 "目标项目根不存在: $repo_root"
pkg_dir=$(CDPATH='' cd "$pkg_dir" && pwd)
repo_root=$(CDPATH='' cd "$repo_root" && pwd)
[ -f "$pkg_dir/scripts/install-policy.rules" ] || die2 "包基线缺 install-policy.rules: $pkg_dir/scripts/install-policy.rules"
[ -f "$pkg_dir/scripts/upgrade-check.sh" ] || die2 "包基线缺 upgrade-check.sh（本件应随包分发）: $pkg_dir/scripts/upgrade-check.sh"
[ -f "$pkg_dir/references/templates/delivery-rules.tmpl" ] || die2 "包基线缺 delivery-rules.tmpl: $pkg_dir/references/templates/delivery-rules.tmpl"

# ---- 落位件清单自 install-policy.rules 读取（ip_file 行第一字段；先例 install.sh
#      同款 source 加载；取 agent-up/scripts/ 前缀后的单段文件名）----
policy="$pkg_dir/scripts/install-policy.rules"
_rules_tmp=$(mktemp "${TMPDIR:-/tmp}/upchk.XXXXXX")
cleanup() { rm -f "$_rules_tmp"; }
trap cleanup EXIT HUP INT TERM
LC_ALL=C awk '
  /^ip_file / {
    p = $2
    sub(/^agent-up\/scripts\//, "", p)
    if (p != "" && !(p in seen)) { seen[p] = 1; print p }
  }
' "$policy" > "$_rules_tmp"
[ -s "$_rules_tmp" ] || die2 "install-policy.rules 未解析出任何落位件: $policy"

uc_sync=0
uc_behind=0
uc_drift=0
printf '%s: 落位脚本 cmp（包基线 %s）:\n' "$prog" "$pkg_dir"
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  _new="$repo_root/rules/implementation/scripts/$_f"
  _old="$repo_root/scripts/$_f"
  _pkg="$pkg_dir/scripts/$_f"
  if [ -f "$_new" ]; then
    if cmp -s "$_pkg" "$_new"; then
      printf '%s:   同步  %s（rules/implementation/scripts/）\n' "$prog" "$_f"
      uc_sync=$((uc_sync + 1))
    else
      printf '%s:   漂移  %s（rules/implementation/scripts/ 与包基线不一致——人工改过或本地演化，处置见 references/upgrade.md 三态表）\n' "$prog" "$_f"
      uc_drift=$((uc_drift + 1))
    fi
  elif [ -f "$_old" ]; then
    if cmp -s "$_pkg" "$_old"; then
      printf '%s:   同步  %s（scripts/ 旧布局）\n' "$prog" "$_f"
      uc_sync=$((uc_sync + 1))
    else
      printf '%s:   漂移  %s（scripts/ 与包基线不一致——人工改过或本地演化，处置见 references/upgrade.md 三态表）\n' "$prog" "$_f"
      uc_drift=$((uc_drift + 1))
    fi
  else
    printf '%s:   落后  %s（未安装——两落位形态皆无；install.sh --target <repo-root> <门控> 落位）\n' "$prog" "$_f"
    uc_behind=$((uc_behind + 1))
  fi
done < "$_rules_tmp"

# ---- 配置面：delivery.rules main-only 锚点对照（只认全形锚点行；节在＝同步）----
printf '%s: 配置面（delivery.rules main-only 节锚点）:\n' "$prog"
_manchor='# ==== main-only：worktree 排除清单（worktree-add.sh 读）===='
if [ ! -f "$repo_root/delivery.rules" ]; then
  printf '%s:   落后  delivery.rules 缺失（包内有 delivery-rules.tmpl 可按模板生成；如本仓无快道需求可不装）\n' "$prog"
  uc_behind=$((uc_behind + 1))
elif grep -qF "$_manchor" "$repo_root/delivery.rules"; then
  printf '%s:   同步  main-only 节锚点在位（条目为项目事实不判）\n' "$prog"
  uc_sync=$((uc_sync + 1))
else
  printf '%s:   落后  delivery.rules 无 main-only 节锚点（包内模板有该节；补节见 references/templates/delivery-rules.tmpl）\n' "$prog"
  uc_behind=$((uc_behind + 1))
fi

# ---- 模板生成件对应＋规则块集核对（缺块=落后；多余块=登记分歧候选不误报）----
printf '%s: 模板生成件对应（规则块集核对：缺块=落后，多余块=登记分歧候选；处置见 references/upgrade.md §2）:\n' "$prog"
for _pair in 'rules/assessment.md:references/templates/assessment.md.tmpl' \
             'rules/implementation/discipline.md:references/templates/discipline.md.tmpl' \
             'rules/project.md:references/templates/project.md.tmpl'; do
  _tgt=${_pair%%:*}
  _src=${_pair#*:}
  if [ ! -f "$repo_root/$_tgt" ]; then
    printf '%s:   落后  %s 缺失（对应包内 %s）\n' "$prog" "$_tgt" "$_src"
    uc_behind=$((uc_behind + 1))
    continue
  fi
  # 规则块 ID 集合抽取：模板面（#### R-XX-NNN 标题）vs 实例面同款正则；块 ID 全集比对
  _tmpl_ids=$(LC_ALL=C grep -oE '^#### R-[A-Z]{2}-[0-9]{3}' "$pkg_dir/$_src" 2>/dev/null | sed 's/^#### //' | LC_ALL=C sort -u) || _tmpl_ids=''
  _inst_ids=$(LC_ALL=C grep -oE '^#### R-[A-Z]{2}-[0-9]{3}' "$repo_root/$_tgt" 2>/dev/null | sed 's/^#### //' | LC_ALL=C sort -u) || _inst_ids=''
  _missing=''
  if [ -n "$_tmpl_ids" ]; then
    for _bid in $_tmpl_ids; do
      printf '%s\n' "$_inst_ids" | LC_ALL=C grep -qxF "$_bid" || _missing="$_missing $_bid"
    done
  fi
  _extra=''
  if [ -n "$_inst_ids" ]; then
    for _bid in $_inst_ids; do
      printf '%s\n' "$_tmpl_ids" | LC_ALL=C grep -qxF "$_bid" || _extra="$_extra $_bid"
    done
  fi
  if [ -n "$_missing" ]; then
    printf '%s:   落后  %s 缺规则块:%s（包内 %s 有而实例无——吸收或登记分歧，见 references/upgrade.md §3）\n' "$prog" "$_tgt" "$_missing" "$_src"
    uc_behind=$((uc_behind + 1))
  fi
  if [ -n "$_extra" ]; then
    printf '%s:   分歧候选  %s 有包模板没有的规则块:%s（对照实例分歧登记核认；不判漂移不 FAIL）\n' "$prog" "$_tgt" "$_extra"
  fi
  if [ -z "$_missing" ] && [ -z "$_extra" ]; then
    printf '%s:   同步  %s（规则块集与包内 %s 一致）\n' "$prog" "$_tgt" "$_src"
    uc_sync=$((uc_sync + 1))
  fi
done

printf '%s: 汇总: 同步 %d，落后 %d，漂移 %d\n' "$prog" "$uc_sync" "$uc_behind" "$uc_drift"
if [ "$uc_drift" -gt 0 ] || [ "$uc_behind" -gt 0 ]; then
  printf '%s: 有差距（升级流程入口: 包内 references/upgrade.md；差异面按〔同步/落后/漂移/分歧候选〕分列裁决）\n' "$prog"
  exit 1
fi
printf '%s: 全同步（落地面与包基线一致）\n' "$prog"
