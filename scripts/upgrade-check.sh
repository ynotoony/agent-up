#!/bin/sh
# Input: 包基线目录 <pkg-dir> 与目标项目根 <repo-root>（升级意图由调用者确认）。
# Output: 只读核对布局、已启用脚本、delivery.rules 锚点、规则块 ID 集及定制件存在性。
# Pos: Agent Up 已治理仓升级对账器；模糊布局与包基线缺件返回 2。

set -eu
set -f

# Source common helper functions
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  die2() { printf '%s: 错误：%s\n' "$prog" "$1" >&2; exit 2; }
fi

prog=upgrade-check
tab=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh upgrade-check.sh <pkg-dir> <repo-root>
参数:
  pkg-dir    包基线目录（含 scripts/ 与 references/）。
  repo-root  已由用户选择升级模式的目标项目根目录。
对账口径（全程只读）:
  以完整信号组合识别现代、旧式或混合治理布局；部分/歧义布局 fail-closed。
  install-policy.rules 中已启用脚本分别检查 rules/implementation/scripts/ 与 scripts/；
  双落位逐份 cmp 并报告冲突，不静默选择一份。未启用门控显示 N/A。
  delivery.rules 仅在快道有证据时要求（证据＝delivery.rules 在场，或快道专属脚本已装；
  多门控共享脚本不构成快道证据）；规则块只核 ID 集；README、artifacts 与 Derived
  Conditional README emits 从 references/templates/README.md manifest 读取；目录存在时检查，
  未生成目录显示 N/A。旧 docs/ 条件目录只在旧/混合布局下映射检查。artifacts 与 Derived
  只报告存在性或人工回访，不把人工核对说成内容同步。
退出码: 0 自动检查面无差距；1 有落后/漂移/双布局冲突；2 用法、环境或布局不明确。
USAGE
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

policy="$pkg_dir/scripts/install-policy.rules"
[ -f "$policy" ] || die2 "包基线缺 install-policy.rules: $policy"
[ -f "$pkg_dir/scripts/upgrade-check.sh" ] || die2 "包基线缺 upgrade-check.sh: $pkg_dir/scripts/upgrade-check.sh"
for _required in \
  references/templates/delivery-rules.tmpl \
  references/templates/AGENTS.md.tmpl \
  references/templates/assessment.md.tmpl \
  references/templates/discipline.md.tmpl \
  references/templates/project.md.tmpl \
  references/templates/agents-implementation.md.tmpl \
  references/templates/agents-review.md.tmpl \
  references/templates/agents-commit.md.tmpl \
  references/templates/README.md
do
  [ -f "$pkg_dir/$_required" ] || die2 "包基线缺 $_required"
done

tmp_files=$(mktemp "${TMPDIR:-/tmp}/upchk-files.XXXXXX")
tmp_anchors=$(mktemp "${TMPDIR:-/tmp}/upchk-anchors.XXXXXX")
tmp_readmes=$(mktemp "${TMPDIR:-/tmp}/upchk-readmes.XXXXXX")
# shellcheck disable=SC2329  # shellcheck 0.11.0 伪影：cleanup 经 trap 引用真实生效（运行期逐字节等价），末行无条件 exit 0 与 trap 组合触发误报——最小复现：trap f EXIT 后接无条件 exit 0
cleanup() { rm -f "$tmp_files" "$tmp_anchors" "$tmp_readmes"; }
trap cleanup 0 HUP INT TERM

# Keep policy data as data and fail closed on malformed rows relevant to this checker.
LC_ALL=C awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  $1 == "ip_file" {
    if (NF < 5 || $2 !~ /^agent-up\/scripts\/[A-Za-z0-9][A-Za-z0-9._-]*$/ || $4 !~ /^[a-z][a-z0-9-]*$/) { bad = 1; next }
    p = $2; sub(/^agent-up\/scripts\//, "", p)
    if (!(p in seen)) { order[++n] = p; seen[p] = 1 }
    gates[p] = gates[p] " " $4
    next
  }
  $1 == "ip_gate" { next }
  { bad = 1 }
  END {
    if (n == 0) bad = 1
    if (bad) exit 1
    for (i = 1; i <= n; i++) print order[i] "\t" gates[order[i]]
  }
' "$policy" > "$tmp_files" || die2 "install-policy.rules 结构无效或没有落位件: $policy"

# Read fixed README Emits from the live template manifest. Generic <目录>/README.md has no
# fixed path and remains a manual directory-inventory check; conditional outputs activate if present.
LC_ALL=C awk -F'|' '
  function trim(s) { sub(/^[[:space:]]*/, "", s); sub(/[[:space:]]*$/, "", s); gsub(/`/, "", s); return s }
  /^## 目录清单/ { manifest = 1; next }
  manifest && /^\|/ {
    name = trim($2)
    target = trim($4)
    if (name ~ /README[.]md[.]tmpl$/ && name !~ /^dir-/ && target ~ /\/README[.]md$/) {
      if (target ~ /^\// || target ~ /(^|\/)\.\.(\/|$)/) { bad = 1; next }
      print target
      count++
    }
  }
  END { if (bad || count == 0) exit 1 }
' "$pkg_dir/references/templates/README.md" > "$tmp_readmes" \
  || die2 "模板 manifest 的条件 README emits 无法解析: $pkg_dir/references/templates/README.md"

# A docs path alone is never legacy evidence. Only complete combinations select a layout.
modern_complete=1
for _p in AGENTS.md rules/assessment.md rules/implementation/discipline.md rules/project.md facts/project/artifacts.yaml; do
  [ -f "$repo_root/$_p" ] || modern_complete=0
done
legacy_complete=1
for _p in AGENTS.md docs/development-process.md docs/agent/artifacts.yaml; do
  [ -f "$repo_root/$_p" ] || legacy_complete=0
done
modern_partial=0
for _p in rules/assessment.md rules/implementation/discipline.md rules/project.md facts/project/artifacts.yaml; do
  [ -e "$repo_root/$_p" ] && modern_partial=1
done
if [ "$modern_complete" -eq 1 ] && [ "$legacy_complete" -eq 1 ]; then
  layout=mixed
elif [ "$modern_complete" -eq 1 ]; then
  layout=modern
elif [ "$legacy_complete" -eq 1 ] && [ "$modern_partial" -eq 0 ]; then
  layout=legacy
else
  die2 "治理布局不明确；现代完整信号=AGENTS.md+rules 三件+facts/project/artifacts.yaml，旧式完整信号=AGENTS.md+docs/development-process.md+docs/agent/artifacts.yaml；请先确认布局并补全盘点（docs/ 单一路径不构成旧式信号）"
fi

uc_sync=0
uc_behind=0
uc_drift=0
uc_conflict=0
uc_manual=0
printf '%s: 布局: %s（模式由用户意图确认；布局由完整信号组合识别）\n' "$prog" "$layout"

# Fast evidence has two independent sources: the delivery.rules file itself (the
# conditional product is installed = lane active), and an installed fast-lane-exclusive
# script (a policy row gated only by fast-lane = scripts shipped while the config went
# missing, a real upgrade gap). Shared files carry multiple gate rows in
# install-policy.rules — a ticket-ops install of generate-progress.sh must never light
# the fast lane; with no fast evidence the conditional product stays N/A.
fast_enabled=0
ticket_enabled=0
[ -f "$repo_root/delivery.rules" ] && fast_enabled=1
[ -f "$repo_root/facts/requirements/tickets/index.json" ] && ticket_enabled=1
[ -f "$repo_root/docs/issues/index.json" ] && ticket_enabled=1
while IFS="$tab" read -r _f _gates; do
  _new="$repo_root/rules/implementation/scripts/$_f"
  _old="$repo_root/scripts/$_f"
  if [ -f "$_new" ] || [ -f "$_old" ]; then
    case " $_gates " in *" ticket-ops "*) ticket_enabled=1 ;; esac
    case " $_gates " in
      *" fast-lane "*)
        case " $_gates " in
          *" ticket-ops "*) : ;;
          *) fast_enabled=1 ;;
        esac
        ;;
    esac
  fi
done < "$tmp_files"

printf '%s: 落位脚本（install-policy.rules 中已启用门控逐份核对）:\n' "$prog"
while IFS="$tab" read -r _f _gates; do
  _active=0
  case " $_gates " in *" fast-lane "*) [ "$fast_enabled" -eq 1 ] && _active=1 ;; esac
  case " $_gates " in *" ticket-ops "*) [ "$ticket_enabled" -eq 1 ] && _active=1 ;; esac
  case " $_gates " in
    *" fast-lane "*|*" ticket-ops "*) : ;;
    *) if [ -f "$repo_root/rules/implementation/scripts/$_f" ] || [ -f "$repo_root/scripts/$_f" ]; then _active=1; fi ;;
  esac
  if [ "$_active" -eq 0 ]; then
    printf '%s:   N/A  %s（门控未启用/无安装证据）\n' "$prog" "$_f"
    continue
  fi
  _new="$repo_root/rules/implementation/scripts/$_f"
  _old="$repo_root/scripts/$_f"
  _pkg="$pkg_dir/scripts/$_f"
  [ -f "$_pkg" ] || die2 "install-policy 登记件不在包基线: $_pkg"
  _has_new=0; _has_old=0
  [ -f "$_new" ] && _has_new=1
  [ -f "$_old" ] && _has_old=1
  if [ "$_has_new" -eq 1 ] && [ "$_has_old" -eq 1 ]; then
    printf '%s:   冲突  %s 同时位于 rules/implementation/scripts/ 与 scripts/；两份均独立对比，需人工收敛\n' "$prog" "$_f"
    uc_conflict=$((uc_conflict + 1))
  fi
  if [ "$_has_new" -eq 0 ] && [ "$_has_old" -eq 0 ]; then
    printf '%s:   落后  %s 两种落位均缺失（门控已启用）\n' "$prog" "$_f"
    uc_behind=$((uc_behind + 1))
    continue
  fi
  if [ "$_has_new" -eq 1 ]; then
    if cmp -s "$_pkg" "$_new"; then
      printf '%s:   同步  rules/implementation/scripts/%s（与包基线 cmp 一致）\n' "$prog" "$_f"
      uc_sync=$((uc_sync + 1))
    else
      printf '%s:   漂移  rules/implementation/scripts/%s（与包基线不同）\n' "$prog" "$_f"
      uc_drift=$((uc_drift + 1))
    fi
  fi
  if [ "$_has_old" -eq 1 ]; then
    if cmp -s "$_pkg" "$_old"; then
      printf '%s:   同步  scripts/%s（旧布局，与包基线 cmp 一致）\n' "$prog" "$_f"
      uc_sync=$((uc_sync + 1))
    else
      printf '%s:   漂移  scripts/%s（旧布局，与包基线不同）\n' "$prog" "$_f"
      uc_drift=$((uc_drift + 1))
    fi
  fi
done < "$tmp_files"

if [ "$fast_enabled" -eq 0 ]; then
  printf '%s: 配置面: N/A delivery.rules（未启用快道）\n' "$prog"
else
  printf '%s: 配置面（delivery.rules 条件产物）:\n' "$prog"
  if [ ! -f "$repo_root/delivery.rules" ]; then
    printf '%s:   落后  delivery.rules 缺失（快道脚本已装，配置缺失）\n' "$prog"
    uc_behind=$((uc_behind + 1))
  else
    grep '^# ====' "$pkg_dir/references/templates/delivery-rules.tmpl" > "$tmp_anchors"
    [ -s "$tmp_anchors" ] || die2 'delivery-rules.tmpl 没有可核对的节锚点'
    _missing_anchor=0
    while IFS= read -r _anchor; do
      if ! grep -qF "$_anchor" "$repo_root/delivery.rules"; then
        printf '%s:   落后  delivery.rules 缺锚点: %s\n' "$prog" "$_anchor"
        _missing_anchor=1
        uc_behind=$((uc_behind + 1))
      fi
    done < "$tmp_anchors"
    if [ "$_missing_anchor" -eq 0 ]; then
      printf '%s:   锚点齐全 delivery.rules（配置内容属于项目事实，需人工核对）\n' "$prog"
      uc_sync=$((uc_sync + 1))
      uc_manual=$((uc_manual + 1))
    fi
  fi
fi

uc_check_blocks() {
  _target=$1
  _template=$2
  if [ ! -f "$repo_root/$_target" ]; then
    printf '%s:   落后  %s 缺失（对应包内 %s）\n' "$prog" "$_target" "$_template"
    uc_behind=$((uc_behind + 1))
    return
  fi
  _tmpl_ids=$(LC_ALL=C grep -oE '^#### R-[A-Z]{2}-[0-9]{3}' "$pkg_dir/$_template" | sed 's/^#### //' | LC_ALL=C sort -u) || _tmpl_ids=''
  _inst_ids=$(LC_ALL=C grep -oE '^#### R-[A-Z]{2}-[0-9]{3}' "$repo_root/$_target" | sed 's/^#### //' | LC_ALL=C sort -u) || _inst_ids=''
  _missing=''
  for _bid in $_tmpl_ids; do
    printf '%s\n' "$_inst_ids" | LC_ALL=C grep -qxF "$_bid" || _missing="$_missing $_bid"
  done
  _extra=''
  for _bid in $_inst_ids; do
    printf '%s\n' "$_tmpl_ids" | LC_ALL=C grep -qxF "$_bid" || _extra="$_extra $_bid"
  done
  if [ -n "$_missing" ]; then
    printf '%s:   落后  %s 缺规则块:%s\n' "$prog" "$_target" "$_missing"
    uc_behind=$((uc_behind + 1))
  fi
  if [ -n "$_extra" ]; then
    printf '%s:   分歧候选  %s 有包模板没有的规则块:%s（只提示，不判漂移）\n' "$prog" "$_target" "$_extra"
  fi
  if [ -z "$_missing" ] && [ -z "$_extra" ]; then
    printf '%s:   同步  %s（规则块 ID 集与包内一致；不比较块内语义）\n' "$prog" "$_target"
    uc_sync=$((uc_sync + 1))
  fi
}

printf '%s: 规则块 ID 集（不比较块内语义）:\n' "$prog"
uc_check_blocks AGENTS.md references/templates/AGENTS.md.tmpl
if [ "$layout" = modern ] || [ "$layout" = mixed ]; then
  uc_check_blocks rules/assessment.md references/templates/assessment.md.tmpl
  uc_check_blocks rules/implementation/discipline.md references/templates/discipline.md.tmpl
  uc_check_blocks rules/project.md references/templates/project.md.tmpl
  uc_check_blocks rules/implementation/roles/implementation.md references/templates/agents-implementation.md.tmpl
  uc_check_blocks rules/implementation/roles/review.md references/templates/agents-review.md.tmpl
  uc_check_blocks rules/implementation/roles/commit.md references/templates/agents-commit.md.tmpl
else
  printf '%s:   N/A  rules/ 与 rules/implementation/roles/ 块检查（旧式兼容布局不要求新路径）\n' "$prog"
fi

uc_check_presence() {
  _path=$1
  _label=$2
  if [ -f "$repo_root/$_path" ]; then
    printf '%s:   人工核对 %s（仅确认存在，不判定内容同步）\n' "$prog" "$_path"
    uc_manual=$((uc_manual + 1))
  else
    printf '%s:   落后  %s 缺失（%s）\n' "$prog" "$_path" "$_label"
    uc_behind=$((uc_behind + 1))
  fi
}

printf '%s: 定制产物与 manifest README（只核存在性；Conditional 目录未生成时 N/A）:\n' "$prog"
if [ "$layout" = modern ] || [ "$layout" = mixed ]; then
  uc_check_presence rules/README.md '模板 manifest 目录 README'
  uc_check_presence facts/README.md '模板 manifest 目录 README'
  uc_check_presence facts/project/artifacts.yaml '模板 manifest 产物索引'
fi
if [ "$layout" = legacy ] || [ "$layout" = mixed ]; then
  uc_check_presence docs/development-process.md '旧布局流程权威，保留原路径'
  uc_check_presence docs/README.md '旧布局目录 README，保留原路径'
  uc_check_presence docs/agent/artifacts.yaml '旧布局产物索引，保留原路径'
  for _role in implementation review commit; do
    uc_check_presence "docs/agent/roles/$_role.md" '旧布局角色合同，保留并按登记路径读取'
  done
fi
while IFS= read -r _manifest_path; do
  _manifest_dir=${_manifest_path%/README.md}
  if [ -d "$repo_root/$_manifest_dir" ]; then
    uc_check_presence "$_manifest_path" '模板 manifest 中已生成的 Conditional README'
  else
    printf '%s:   N/A  %s（Conditional 目录不存在，未生成）\n' "$prog" "$_manifest_path"
  fi
  if [ "$layout" = legacy ] || [ "$layout" = mixed ]; then
    case $_manifest_path in
      facts/requirements/tickets/README.md) _legacy_path=docs/issues/README.md ;;
      facts/requirements/specs/README.md) _legacy_path=docs/specs/README.md ;;
      facts/requirements/research/README.md) _legacy_path=docs/research/README.md ;;
      rules/implementation/scripts/README.md) _legacy_path=scripts/README.md ;;
      *) _legacy_path='' ;;
    esac
    if [ -n "$_legacy_path" ]; then
      _legacy_dir=${_legacy_path%/README.md}
      if [ -d "$repo_root/$_legacy_dir" ]; then
        uc_check_presence "$_legacy_path" '旧布局中已存在的条件目录 README；保留旧路径'
      else
        printf '%s:   N/A  %s（旧布局 Conditional 目录不存在，未生成）\n' "$prog" "$_legacy_path"
      fi
    fi
  fi
done < "$tmp_readmes"
printf '%s:   人工核对 <目录>/README.md 动态 Emits（按目标仓已登记/新建治理目录逐项检查）\n' "$prog"
uc_manual=$((uc_manual + 1))

printf '%s: Derived 面: 人工回访（本器不验证生成新鲜度；按 references/upgrade.md §5 回访项目地图及其他 Derived）\n' "$prog"
uc_manual=$((uc_manual + 1))
printf '%s: 汇总: 自动同步 %d，落后 %d，漂移 %d，双布局冲突 %d，人工核对 %d\n' \
  "$prog" "$uc_sync" "$uc_behind" "$uc_drift" "$uc_conflict" "$uc_manual"
if [ "$uc_drift" -gt 0 ] || [ "$uc_behind" -gt 0 ] || [ "$uc_conflict" -gt 0 ]; then
  printf '%s: 有差距（处置流程见 references/upgrade.md；人工核对项仍须完成）\n' "$prog"
  exit 1
fi
printf '%s: 自动检查面无差距；不代表人工核对面或 Derived 已同步\n' "$prog"
exit 0
