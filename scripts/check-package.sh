#!/bin/sh
# Input: 待检包根目录（默认为本脚本所在目录的父目录）与两份数据文件——包清单数据文件
#        scripts/package-manifest.rules（入口文件/脚本必需件/模板清单/短码登记/platform
#        枚举/模糊措辞词表与豁免/镜像脚本/能力基元名单与检查目标/规则索引执行机制受控
#        词表/平台适配注册表/退役能力面/工作流图与定位/readonly 声明面/README 契约指针
#        各节唯一承载点）与适配差异数据表 references/adapters/adapter-diffs.rules（包根
#        相对落位；四节机器数据行，检查 27 数据源）；检查注册表与检查件在 scripts/checks/。
# Output: 三十七项包完整性检查的逐项 PASS/FAIL 行与结尾汇总（全部通过 exit 0，任一失败
#         exit 1；检查 13 仓根无镜像落位目录时静默跳过无输出行；检查 19 非 git 语境静默
#         跳过无输出行）。
# Pos: agent-up 公开包发布前核对工具薄 CLI（SPEC-06 §5 / R-06-004）：只承载参数解析、
#      上下文派生（包根/共享只读派生量/worktree 语境）、三块编排与输出汇总；配置加载/校验
#      在 checks/config-load.sh，检查注册表与分发执行在 checks/registry-dispatch.sh。
#      POSIX sh、只读检查、零网络依赖。

# 用法与检查项实现细节（含各例外登记）见同目录 README.md。
# 自命中规避：检查 3/4 的扫描范围包含本目录文件；检查件内的敏感模式以字符串拼接或正则
# 转义构造，运行时才拼成完整字面量（见 README.md）。

# 路径常量区（治理路径字面量唯一收拢点）：检查件与引擎共享的只读上下文常量。
# shellcheck disable=SC2034  # 跨件共享常量（checks/*.sh 检查件消费），单文件视野误报
docs_dir='docs'
rules_dir='rules'
facts_dir='facts'
scripts_dir='scripts'
scripts_readme_rel='scripts/README.md'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob，展开文件清单时避免意外匹配

failures=0

# Worktree 检测函数：git worktree 内 --git-dir ≠ --git-common-dir。
# 返回 0 表示在 worktree 内，返回 1 表示在主检出或非 git 环境。
is_worktree() {
  git -C "$pkg_root" rev-parse --git-dir >/dev/null 2>&1 || return 1
  _git_dir=$(git -C "$pkg_root" rev-parse --git-dir 2>/dev/null)
  _common_dir=$(git -C "$pkg_root" rev-parse --git-common-dir 2>/dev/null)
  # 规范化为绝对路径后再比较（避免相对/绝对路径字符串不等但语义相等的误判）
  case $_git_dir in
    /*) _git_dir_abs=$_git_dir ;;
    *) _git_dir_abs=$(cd "$pkg_root/$_git_dir" && pwd) ;;
  esac
  case $_common_dir in
    /*) _common_dir_abs=$_common_dir ;;
    *) _common_dir_abs=$(cd "$pkg_root/$_common_dir" && pwd) ;;
  esac
  [ "$_git_dir_abs" != "$_common_dir_abs" ]
}

pass() {
  printf 'PASS: %s %s\n' "$1" "$2" >> "$chk_out_buf"
  printf '%s\n' "$1" >> "$chk_emitted_ids"
}

fail() {
  # $1=编号 $2=描述 $3=详情（可多行；多行时逐行缩进两空格）
  _n=$1
  _desc=$2
  _detail=${3:-}
  case $_detail in
    *'
'*)
      printf 'FAIL: %s %s 详情：\n' "$_n" "$_desc" >> "$chk_out_buf"
      printf '%s\n' "$_detail" | sed 's/^/  /' >> "$chk_out_buf"
      ;;
    '')
      printf 'FAIL: %s %s\n' "$_n" "$_desc" >> "$chk_out_buf"
      ;;
    *)
      printf 'FAIL: %s %s — %s\n' "$_n" "$_desc" "$_detail" >> "$chk_out_buf"
      ;;
  esac
  printf '%s\n' "$_n" >> "$chk_emitted_ids"
  failures=$((failures + 1))
}

# 问题行累加器（单行；多行由 fail() 走详情块缩进排版）：检查件唯一报告入口
problems=''
add_problem() {
  if [ -n "$problems" ]; then
    problems="$problems
"
  fi
  problems="$problems$1"
}

usage() {
  cat <<USAGE
用法: sh check-package.sh [--only <N[,N]>] [package-root]
参数:
  --only <N[,N]>  只运行指定编号的检查（逗号分隔，须已注册；未设＝全量运行）。定向运行
                  时输出只有被选中检查的 PASS/FAIL/SKIP 行；汇总行仍报注册表总项数（便于
                  与全量输出逐字对照），未选中的检查不校验其数据面。全量运行的输出与退出
                  码逐字节不变。
  package-root  待检包根目录（含 SKILL.md 的目录）；缺省时取本脚本所在目录的父目录。
退出码:
  0  ${n_total_checks} 项检查全部通过
  1  存在未通过项（逐项 FAIL 行见输出）
  2  用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等）
${n_total_checks} 项检查说明、例外登记与输出格式见同目录 README.md。
USAGE
}

header_window() {
  # 契约头检测窗口：首行为 --- 的文件取 frontmatter 结束后的 5 行；否则取文件前 5 行。
  # frontmatter 未闭合时窗口为空，契约头检查将失败（视为格式缺陷）。
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && !closed { if ($0 == "---") closed = 1; next }
    { n++; if (n <= 5) print }
  ' "$1"
}

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
# ---- 三块职责：配置加载/校验模块 + 注册表分发执行器；CLI 只编排不实现 ----
# shellcheck source=agent-up/scripts/checks/config-load.sh  # 路径由脚本目录推导
. "$script_dir/checks/config-load.sh"
# shellcheck source=agent-up/scripts/checks/registry-dispatch.sh  # 路径由脚本目录推导
. "$script_dir/checks/registry-dispatch.sh"
pm_loader_bootstrap "$script_dir"
# ---- 检查注册表上界派生（用法文本与汇总行同一来源）----
n_total_checks=$(chk_registry_query_total "$script_dir/checks/registry.rules")
n_total_checks=${n_total_checks:-37}
chk_only_raw=''
pkg_root=''
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --only)
      if [ $# -lt 2 ]; then
        printf 'check-package: 错误：--only 缺值（形如 --only 12 或 --only 12,13）\n' >&2
        exit 2
      fi
      chk_only_raw=$2
      shift 2
      ;;
    --only=*)
      chk_only_raw=${1#--only=}
      shift
      ;;
    -*)
      printf 'check-package: 错误：未知选项：%s\n' "$1" >&2
      exit 2
      ;;
    *)
      if [ -n "$pkg_root" ]; then
        printf 'check-package: 错误：至多接受一个包根参数\n' >&2
        usage >&2
        exit 2
      fi
      pkg_root=$1
      shift
      ;;
  esac
done
if [ -z "$pkg_root" ]; then
  pkg_root=$(CDPATH='' cd "$script_dir/.." && pwd)
fi
if [ ! -d "$pkg_root" ]; then
  printf 'check-package: 错误：包根目录不存在：%s\n' "$pkg_root" >&2
  exit 2
fi

# ---- 定向运行（--only）预解析：注册表纯查询 → 必需数据节 → schema 声明的跨节依赖闭包。
# 闭包单一来源＝config-load.sh 的 schema 登记表（不再维护引擎侧手工闭包表）；全量模式
# chk_section_needed 恒真，以下状态全空，行为与输出逐字节不变。
chk_only_mode=0
chk_need_sections=''
if [ -n "$chk_only_raw" ]; then
  chk_only_mode=1
  _chk_registry_pre="$script_dir/checks/registry.rules"
  if [ ! -f "$_chk_registry_pre" ]; then
    printf 'check-package: 错误：检查注册表缺失: %s\n' "$_chk_registry_pre" >&2
    exit 2
  fi
  chk_need_sections=$(pm_section_closure "$(chk_registry_query_sections "$_chk_registry_pre" "$chk_only_raw")")
fi

pm_loader_init
pm_load_manifests "$pkg_root"

# ---- 共享派生：worktree 环境识别与 main-only 清单（检查 8/9 共用；注册表分发前一次计算）----
mainonly_list=''
in_worktree=0
# 只有检查 8/9 消费该派生面（pm_script）；--only 时未选中即跳过 git 调用
if chk_section_needed pm_script && is_worktree; then
  # 获取主仓库工作树根目录（通过 git-common-dir 向上追溯到工作树根）
  _common_dir=$(git -C "$pkg_root" rev-parse --git-common-dir 2>/dev/null)
  if [ -n "$_common_dir" ]; then
    case $_common_dir in
      /*) _repo_root=$(dirname "$_common_dir") ;;
      *) _repo_root=$(cd "$pkg_root/$_common_dir/.." && pwd) ;;
    esac
    if [ -f "$_repo_root/delivery.rules" ]; then
      # 解析 delivery.rules dp_mainonly 指令（格式：dp_mainonly <路径>，取第二字段）
      mainonly_list=$(LC_ALL=C awk '/^dp_mainonly / { print $2 }' "$_repo_root/delivery.rules")
      if [ -n "$mainonly_list" ]; then
        in_worktree=1
      fi
    fi
  fi
fi

# ---- 共享只读派生量（注册表分发前初始化并显式传入；检查件之间零隐式状态）----
chk_dir="$script_dir/checks"
file_list=$(find "$pkg_root" -type f \( -name '*.md' -o -name '*.tmpl' \) | sort)
idx_file="$pkg_root/references/rules-index.md"
# shellcheck disable=SC1090,SC1091  # 共享检查件辅助函数路径由脚本目录推导（静态视野不可跟随）
. "$chk_dir/shared.sh"

# ============================================================
# 调度：注册表加载与三向断言 → 定向选择集 → 逐项分发 → 输出完整性守卫
# ============================================================
chk_registry_init "$chk_dir"
chk_registry_load
chk_registry_select
chk_registry_assert
chk_dispatch_run "$pkg_root"
chk_output_guard "$pkg_root"
cat "$chk_out_buf"

if [ "$failures" -gt 0 ]; then
  printf 'check-package: FAIL（%s 项未通过，共 %s 项）\n' "$failures" "$n_total_checks"
  exit 1
fi
printf 'check-package: PASS\n'
