#!/bin/sh
# Input: 合同入口（单位置参数）＝派发合同文件路径（JSON 含 "TICKET_ID" 键，或委派合同
#        模板的 {{TICKET_ID}} 节）：脚本自抽 TICKET_ID（<NN>-<slug> 形态）派生分支名
#        ticket/<TICKET_ID> 与站路径（仓库根兄弟目录 <仓库名>-wt/wt<NN>，NN 取自
#        TICKET_ID 首段、仓库名取仓根 basename；站容器缺失自动创建）；旧接口（双位置
#        参数）＝<path> <branch>（与 git worktree add 同序同义；branch 须
#        ticket/<NN>-<slug> 形态），为无合同调用方保留。可选 --force（透传 git，同时
#        放宽同名登记清理）；仓根 delivery.rules（main-only 节 dp_mainonly 排除清单，
#        缺省禁跑见 Output）。
# Output: 一票一 worktree 的栅栏化创建单命令——按 delivery.rules main-only 节逐条排除
#         main-only 路径（目录或文件；sparse-checkout 非锥形模式，创建后该路径在工作树
#         物理不在场：目录内文件不可写、直接运行不存在），输出排除清单行与完成行。
#         delivery.rules 缺失或 main-only 锚点缺失＝拒跑 exit 2（未声明排除形态＝栅栏
#         未知，fail-closed：worktree-add 只在有栅栏配置的仓提供）；解析破坏 exit 2。
# Pos: 公开包 worktree 创建单命令（交付面规则：main-only 脚本禁止在链接 worktree 运行，
#      与 export-payload.sh 真跑门禁、install.sh worktree 自拒互为三闸——创建面排除＋
#      运行面自拒＋规则面成文 R-DP-036）；main-only 解析引擎＝同目录 dp-load-rules.sh
#      （fail-closed 六规则同族；引擎零项目约定硬编码；版本注记见下行 dp-parser）；
#      POSIX sh；不执行 git push / 不删除既有 worktree（同名目录已存在即停，--force 只
#      放宽 git 层）；.sparse-checkout 排除清单持久在该 worktree 的
#      $GIT_DIR/info/sparse-checkout（随 worktree 删除一并消失）。
# dp-parser: 2
#      （本件要求解析器最低版注记；解析唯一实现＝同目录 dp-load-rules.sh，版本唯一
#      来源＝其 DP_PARSER_VERSION。落地拷贝遇未知锚点/指令、解析器缺件或版本漂移即
#      报错指名——同步方式见 references/old-project.md §3 dp-load-rules.sh 引擎件行，
#      文法与版本详见 references/delivery-rules.md。四件同族脚本注记须一致。）

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'worktree-add: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

prog=worktree-add

usage() {
  cat <<'USAGE'
用法: sh worktree-add.sh [--force] <合同文件>
      sh worktree-add.sh [--force] <path> <branch>
参数:
  --force          透传 git worktree add --force（目标已存在等场景）；不改变本脚本其余门禁。
  <合同文件>        合同入口（单参数）：派发合同文件路径（JSON 含 "TICKET_ID" 键，或委派合同
                   模板的 {{TICKET_ID}} 节）；脚本自抽 TICKET_ID 派生分支与站路径，调用方
                   不传路径与分支名。
  <path> <branch>  旧接口（双参数）：worktree 路径（git worktree add 同义：仓库根相对或
                   绝对路径）与新分支名（须匹配 ticket/<NN>-<slug>，NN 为数字；slug 为非空段）。
行为:
  1. 主检出自拒：本脚本只在仓库主检出（git-dir ＝ git-common-dir）运行，链接 worktree
     内运行即拒（exit 1）。
  2. 读仓根 delivery.rules main-only 节（dp_mainonly 逐行一条排除路径；锚点缺失或文件
     缺失＝拒跑 exit 2，栅栏未知 fail-closed；锚点在场即已声明，空清单＝裸锚点＋注释
     条目（分发模板预期形态）；解析破坏 exit 2）。
  3. 合同入口派生：自合同抽 TICKET_ID（<NN>-<slug> 形态），分支名 ticket/<TICKET_ID>、
     站路径 仓库根/../<仓库名>-wt/wt<NN>（NN 自 TICKET_ID 首段、仓库名取仓根 basename）
     均自其派生；站容器目录在防撞闸过后按需自动创建。
  4. git worktree add（--no-checkout）创建；对新区设 sparse-checkout 非锥形模式：
     '/*' 放行全部，再按 dp_mainonly 清单逐条 '!<路径>' 排除，reapply 生效；输出排除
     清单与完成行。
  5. 完成行后提示依赖准备入口（同目录 worktree-deps.sh <站路径>）：本命令只创建
     worktree、不安装依赖；非 npm 仓库由该命令自行 skip。本安装未随附该入口
     （worktree-deps.sh 不在场）时改提示在站内自行准备依赖。
退出码:
  0  创建并排除完成。
  1  fail-closed（链接 worktree 内运行、分支名不合 ticket 形态、worktree add 失败、
     sparse-checkout 设置失败等）。
  2  用法或配置错误（参数不合、非 Git 工作区、delivery.rules 缺失或未声明 main-only
     节或解析破坏、合同文件缺失/不可解析或 TICKET_ID 缺失/形态不合）。
USAGE
}

# ---- 参数解析 ----

force=''
path=''
branch=''
contract_file=''
contract_mode=''
for _arg in "$@"; do
  case $_arg in
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die2 "未知参数: ${_arg}（用法见 --help）" ;;
    *)
      if [ -z "$path" ]; then
        path=$_arg
      elif [ -z "$branch" ]; then
        branch=$_arg
      else
        die2 '至多接受 <合同文件> 或 <path> <branch>（用法见 --help）'
      fi
      ;;
  esac
done

# ---- 接口模式判别（单位置参数＝合同入口；双位置参数＝旧接口）----

[ -n "$path" ] || { usage >&2; die2 '缺少参数（<合同文件> 或 <path> <branch>）'; }
if [ -z "$branch" ]; then
  contract_file=$path
  path=''
  contract_mode=1
fi

# ---- 主检出自拒（第一道闸：链接 worktree 内禁止运行）----

_gd=$(git rev-parse --absolute-git-dir 2>/dev/null) || die2 '目标不是 Git 工作区（须在主检出运行）'
_gcd=$(git rev-parse --git-common-dir 2>/dev/null) || die2 '目标不是 Git 工作区（须在主检出运行）'
case $_gcd in
  /*) ;;
  *) _gcd=$(CDPATH='' cd "$(git rev-parse --show-toplevel)/$_gcd" && pwd) ;;
esac
if [ "$_gd" != "$_gcd" ]; then
  die1 "主检出自拒：当前在链接 worktree（git-dir ${_gd} ≠ common-dir ${_gcd}）。worktree 创建属协调层职责，请在主检出运行本脚本。"
fi

# 仓库根推导统一经 resolve_repo_root（票 227 F4：--git 口径＝当前目录所在仓库顶层——
# 本命令操作用户所在仓库，语义保持 cwd 基准）
repo_root=$(resolve_repo_root --git) || die2 '目标不是 Git 工作区（须在主检出运行）'

# ---- 配置加载（未声明 main-only 节＝栅栏未知，拒跑 exit 2 fail-closed）----
# 共享解析器加载（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh；缺件或版本漂移
# fail-closed exit 2 指名，不内嵌副本）
_dp_parser_file=$(dirname "$0")/dp-load-rules.sh
if [ -f "$_dp_parser_file" ]; then
  # shellcheck source=agent-up/scripts/dp-load-rules.sh  # 路径动态计算，显式声明基线位置
  . "$_dp_parser_file"
else
  die2 "共享解析器缺失: ${_dp_parser_file}（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh，与消费件同目录分发）"
fi
if [ "${DP_PARSER_VERSION:-0}" -lt 2 ]; then
  die2 "共享解析器版本漂移: $_dp_parser_file 版本 ${DP_PARSER_VERSION:-（未声明）} 低于本件最低要求 2（请与包内同件同步）"
fi

dp_load_rules "$repo_root" "$prog" || exit 2
# 已声明＝main-only 锚点在场（含空清单——注释形态示例条目即空清单，模板分发语境）；
# 未声明（锚点缺失或文件缺失）＝栅栏未知，拒跑 fail-closed 不变。
if [ "${DP_MAINONLY_DECLARED:-0}" -ne 1 ]; then
  printf '%s: 拒跑：delivery.rules 未声明 main-only 节（栅栏未知 fail-closed；如本仓无 main-only 脚本，登记空节或径用 git worktree add）\n' "$prog" >&2
  printf '%s: 最小示例（分发模板 references/templates/delivery-rules.tmpl；条目行取消注释即生效，无 main-only 脚本保留空节即可）:\n' "$prog" >&2
  printf '%s:   # ==== main-only：worktree 排除清单（worktree-add.sh 读）====\n' "$prog" >&2
  printf '%s:   # dp_mainonly agent-up/scripts/export-payload.sh\n' "$prog" >&2
  exit 2
fi

# ---- 合同入口派生（TICKET_ID → 分支名与站路径；旧接口跳过本节）----

if [ -n "$contract_mode" ]; then
  [ -f "$contract_file" ] || die2 "合同文件不存在: ${contract_file}"
  # 抽 TICKET_ID：JSON（"TICKET_ID" 键）或委派合同模板（{{TICKET_ID}} 节取次行）；解析由
  # 唯一 JSON 引擎承载（票 227 F3：原内嵌 python heredoc 收敛改调 contract ticket-id；
  # 引擎按需惰性定位——旧接口路径不依赖 python），不可解析即拒跑不产生部分结论。
  _engine_file=$(dirname "$0")/json-validator.py
  [ -f "$_engine_file" ] || \
    die2 "唯一 JSON 引擎缺失: ${_engine_file}（json-validator.py 与本件同目录分发）"
  ticket_id=$(python3 "$_engine_file" contract ticket-id "$contract_file") || \
    die2 "合同文件不可解析（须 UTF-8 文本）: ${contract_file}"
  [ -n "$ticket_id" ] || die2 "合同缺 TICKET_ID（JSON \"TICKET_ID\" 键或 {{TICKET_ID}} 节）: ${contract_file}"
  case $ticket_id in
    [0-9][0-9]*-*) ;;
    *) die2 "TICKET_ID 不合 <NN>-<slug> 形态: ${ticket_id}（合同: ${contract_file}）" ;;
  esac
  branch="ticket/${ticket_id}"
  _nn=$(printf '%s' "$ticket_id" | sed 's/^\([0-9][0-9]*\)-.*/\1/')
  _repo_name=$(basename "$repo_root")
  _wt_parent=$(CDPATH='' cd "$repo_root/.." && pwd) || die2 "仓库根父目录不可进入: ${repo_root}/.."
  path="${_wt_parent}/${_repo_name}-wt/wt${_nn}"
fi

# ---- 分支名形态断言（ticket/<NN>-<slug>；git 分支名允许更宽，本命令收窄；合同入口校验派生分支）----

case $branch in
  ticket/[0-9][0-9]*-*) ;;
  *) die1 "分支名不合 ticket/<NN>-<slug> 形态: ${branch}（一票一 worktree 纪律，路径与分支共用票号）" ;;
esac

# ---- 目标防撞（同名目录已存在即停；--force 只透传 git 层）----

if [ -e "$path" ] && [ -z "${force:-}" ]; then
  die1 "目标路径已存在: ${path}（先核对是否遗留 worktree：git worktree list；确认可弃再 --force）"
fi

# 站容器缺失自动创建（合同入口派生站；置于全部门禁之后——文件系统副作用不先于任何闸）

if [ -n "$contract_mode" ] && [ ! -e "$(dirname "$path")" ]; then
  mkdir -p "$(dirname "$path")" || die1 "站容器目录创建失败: $(dirname "$path")"
fi

# ---- 创建（--no-checkout）与栅栏设置（sparse-checkout 非锥形：放行全部＋逐条排除）----

add_args=''
[ -n "${force:-}" ] && add_args='--force'
# 分支不存在＝创建（git worktree add -b <branch> <path>）；存在＝git worktree add
# <branch> <path>。-b 须与分支名相邻（git 把 -b 后第一个参数当作新分支名）。
if git show-ref --verify --quiet "refs/heads/$branch"; then
  if ! git worktree add $add_args --no-checkout -- "$path" "$branch"; then
    die1 "git worktree add 失败: ${path}（分支被占用或目标不可创建）"
  fi
else
  if ! git worktree add $add_args -b "$branch" --no-checkout -- "$path"; then
    die1 "git worktree add -b 失败: $path ${branch}（目标不可创建或分支名被拒）"
  fi
fi
wt_abs=$(CDPATH='' cd "$path" && pwd) || die1 "新建 worktree 不可进入: $path"
wt_gd=$(git -C "$wt_abs" rev-parse --absolute-git-dir)

if ! git -C "$wt_abs" sparse-checkout init --no-cone; then
  die1 "sparse-checkout init 失败: $wt_abs"
fi
# 排除清单落文件再一次 set（模式含 '!' 前缀，逐行喂入；不带尾斜杠——同一条路径形态
# 同时覆盖文件与目录）。--no-checkout 空树上 reapply 不物化（夹具实证），落盘后以
# read-tree -mu HEAD 按 sparse 模式物化。
_sv=$(mktemp "${TMPDIR:-/tmp}/wtfence.XXXXXX")
# DP_MAINONLY 为换行分隔的纯路径清单（解析引擎已剥指令名），逐行转 '!<路径>' 排除模式。
# 循环体不用 && 短路：空行使短路式返回 1，set -e 杀掉管道子壳，后续步骤被跳过（夹具实证）。
{
  printf '/*\n'
  printf '%s\n' "$DP_MAINONLY" | while IFS= read -r _v; do
    if [ -n "$_v" ]; then printf '!%s\n' "$_v"; fi
  done
} > "$_sv"
if ! git -C "$wt_abs" sparse-checkout set --stdin < "$_sv"; then
  rm -f "$_sv"
  die1 "sparse-checkout set 失败: ${wt_abs}（栅栏未生效，请删除该 worktree 后重试）"
fi
rm -f "$_sv"
if ! git -C "$wt_abs" read-tree -mu HEAD; then
  die1 "read-tree 物化失败: ${wt_abs}（栅栏未生效，请删除该 worktree 后重试）"
fi
# 生效断言：main-only 首条路径在 worktree 内必须不在场（目录或文件皆然）。
_first=$(printf '%s' "$DP_MAINONLY" | sed -n '1p')
if [ -n "$_first" ] && [ -e "$wt_abs/$_first" ]; then
  die1 "栅栏未生效断言失败: $wt_abs/$_first 仍存在（排除模式未生效；请删除该 worktree 后重试）"
fi

printf '%s: 完成: %s（分支 %s）\n' "$prog" "$wt_abs" "$branch"
printf '%s: 栅栏已生效——以下 main-only 路径已从该 worktree 排除（物理不在场）：\n' "$prog"
printf '%s\n' "$DP_MAINONLY" | while IFS= read -r _v; do
  if [ -n "$_v" ]; then printf '%s:   !%s\n' "$prog" "$_v"; fi
done
printf '%s: 排除清单持久于 %s/info/sparse-checkout（随 worktree 删除一并消失）\n' "$prog" "$wt_gd"
printf '%s: 依赖未准备（本命令只创建 worktree，不安装依赖；禁符号链接共享）:\n' "$prog"
_deps_script=$(CDPATH='' cd "$(dirname "$0")" && pwd)/worktree-deps.sh
if [ -f "$_deps_script" ]; then
  printf '%s:   npm 仓库请在该站独立准备: sh %s %s\n' "$prog" "$_deps_script" "$wt_abs"
else
  printf '%s:   本安装未随附依赖准备入口（worktree-deps.sh 不在场），请在站内自行准备依赖\n' "$prog"
fi
exit 0
