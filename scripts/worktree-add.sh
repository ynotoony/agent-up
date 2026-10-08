#!/bin/sh
# Input: 位置参数 <path> <branch>（与 git worktree add 同序同义；path 仓库根相对或绝对，
#        branch 须 ticket/<NN>-<slug> 形态），可选 --force（透传 git，同时放宽同名登记
#        清理）；仓根 delivery.rules（main-only 节 dp_mainonly 排除清单，缺省禁跑见
#        Output）。
# Output: 一票一 worktree 的栅栏化创建单命令——按 delivery.rules main-only 节逐条排除
#         main-only 路径（目录或文件；sparse-checkout 非锥形模式，创建后该路径在工作树
#         物理不在场：目录内文件不可写、直接运行不存在），输出排除清单行与完成行。
#         delivery.rules 缺失或未声明 main-only 节＝拒跑 exit 2（未声明排除形态＝栅栏
#         未知，fail-closed：worktree-add 只在有栅栏配置的仓提供）；解析破坏 exit 2。
# Pos: 公开包 worktree 创建单命令（交付面规则：main-only 脚本禁止在链接 worktree 运行，
#      与 export-payload.sh 真跑门禁、install.sh worktree 自拒互为三闸——创建面排除＋
#      运行面自拒＋规则面成文 R-DP-036）；解析引擎段内嵌（fail-closed 六规则同族；
#      引擎零项目约定硬编码）；POSIX sh；不执行 git push / 不删除既有 worktree（同名
#      目录已存在即停，--force 只放宽 git 层）；.sparse-checkout 排除清单持久在该
#      worktree 的 $GIT_DIR/info/sparse-checkout（随 worktree 删除一并消失）。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

prog=worktree-add

usage() {
  cat <<'USAGE'
用法: sh worktree-add.sh [--force] <path> <branch>
参数:
  --force  透传 git worktree add --force（目标已存在等场景）；不改变本脚本其余门禁。
  <path>   worktree 路径（git worktree add 同义：仓库根相对或绝对路径）。
  <branch> 新分支名，须匹配 ticket/<NN>-<slug>（NN 为数字；slug 为非空段）。
行为:
  1. 主检出自拒：本脚本只在仓库主检出（git-dir ＝ git-common-dir）运行，链接 worktree
     内运行即拒（exit 1）。
  2. 读仓根 delivery.rules main-only 节（dp_mainonly 逐行一条排除路径；未声明节＝拒跑
     exit 2，栅栏未知 fail-closed；解析破坏 exit 2）。
  3. git worktree add（--no-checkout）创建；对新区设 sparse-checkout 非锥形模式：
     '/*' 放行全部，再按 dp_mainonly 清单逐条 '!<路径>' 排除，reapply 生效；输出排除
     清单与完成行。
退出码:
  0  创建并排除完成。
  1  fail-closed（链接 worktree 内运行、分支名不合 ticket 形态、worktree add 失败、
     sparse-checkout 设置失败等）。
  2  用法或配置错误（参数不合、非 Git 工作区、delivery.rules 缺失或未声明 main-only
     节或解析破坏）。
USAGE
}

die1() {
  printf '%s: FAIL: %s\n' "$prog" "$1" >&2
  exit 1
}

die2() {
  printf '%s: 错误：%s\n' "$prog" "$1" >&2
  exit 2
}

# ---- delivery.rules 解析引擎段（fail-closed 六规则，与同族消费脚本同款；本脚本消费
#      main-only 节。用法: dp_load_rules <repo-root> <错误前缀>；副作用全局 DP_*；
#      返回 0 正常（含文件缺失＝全默认未声明）、2 解析破坏（不产生部分结论）----
dp_load_rules() {
  DP_PRESENT=0
  DP_HAS_MAINONLY=0
  DP_MAINONLY=''
  _dp_prefix=$2
  _dp_file="$1/delivery.rules"
  [ -f "$_dp_file" ] || return 0
  DP_PRESENT=1
  _dp_stream=$(mktemp "${TMPDIR:-/tmp}/dprules.XXXXXX") || return 2
  _dp_rc=0
  _dp_err=$(LC_ALL=C awk -v out="$_dp_stream" '
    function bad(msg) { printf "第 %d 行: %s\n", FNR, msg; n++ }
    function bad2(msg) { print msg; n++ }
    BEGIN {
      an[1] = "# ==== payload：导出形态（export-payload.sh 读）===="
      an[2] = "# ==== boundary：禁入名单（pre-push 安检读）===="
      an[3] = "# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）===="
      an[4] = "# ==== main-only：worktree 排除清单（worktree-add.sh 读）===="
      sc[1] = "payload"; sc[2] = "boundary"; sc[3] = "calibration"; sc[4] = "main-only"
    }
    function is_known(d) {
      return (d == "dp_payload_root" || d == "dp_payload_remote" || d == "dp_payload_target" \
        || d == "dp_payload_local_ref" || d == "dp_forbid" || d == "dp_artifact_exempt" \
        || d == "dp_stale_lit" || d == "dp_mainonly")
    }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      hit = 0
      for (k = 1; k <= 4; k++) {
        if (line == an[k]) {
          hit = 1
          if (seen[k]++) bad("锚点重复: " an[k])
          else cur = sc[k]
          break
        }
      }
      if (hit) next
      if (line ~ /^#/) next
      if (line ~ /^[[:space:]]/) { bad("行首空白（指令行须顶格）"); next }
      if (index(line, "\t") > 0) { bad("字段内禁制表符"); next }
      sp = index(line, " ")
      if (sp == 0) { bad("未知指令行: " substr(line, 1, 40)); next }
      d = substr(line, 1, sp - 1)
      v = substr(line, sp + 1)
      if (!is_known(d)) { bad("未知指令行: " d); next }
      if (v == "" || v ~ /[[:space:]]/) { bad("值须为恰一非空字段（禁空白与多余空格）: " d); next }
      if (d ~ /^dp_payload_/ && cur != "payload") { bad("条目违属：dp_payload_* 仅得出现于 payload 锚点后: " d); next }
      if (d == "dp_forbid" && cur != "boundary") { bad("条目违属：dp_forbid 仅得出现于 boundary 锚点后"); next }
      if ((d == "dp_artifact_exempt" || d == "dp_stale_lit") && cur != "calibration") { bad("条目违属：" d " 仅得出现于 calibration 锚点后"); next }
      if (d == "dp_mainonly" && cur != "main-only") { bad("条目违属：dp_mainonly 仅得出现于 main-only 锚点后"); next }
      if (d == "dp_mainonly") {
        if (v ~ /^\//) { bad("路径禁前导斜杠: " v); next }
        if (v ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " v); next }
        if (v ~ /\/$/) { bad("路径禁尾斜杠: " v); next }
      }
      if ((d == "dp_payload_root" || d == "dp_forbid" || d == "dp_artifact_exempt")) {
        if (v ~ /^\//) { bad("路径禁前导斜杠: " v); next }
        if (v ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " v); next }
      }
      if (d == "dp_stale_lit" && v != "S1" && v != "S2") { bad("枚举违（dp_stale_lit ∈ {S1,S2}）: " v); next }
      if (v in seenval) bad("值跨行重复: " v)
      else seenval[v] = 1
      if (d ~ /^dp_payload_/) cnt[d]++
      if (d == "dp_mainonly") cntmo++
      printf "%s\t%s\n", d, v >> out
    }
    END {
      for (k = 1; k <= 3; k++) if (seen[k] && sc[k] == "payload") haspay = 1
      if (haspay) {
        np = split("dp_payload_root dp_payload_remote dp_payload_target dp_payload_local_ref", pd, " ")
        for (k = 1; k <= np; k++) if (cnt[pd[k]] != 1) bad2("恰数违：payload 节存在时 " pd[k] " 须恰一行（实测 " cnt[pd[k]] + 0 "）")
      }
      if (n > 0) exit 1
    }
  ' "$_dp_file") || _dp_rc=$?
  if [ "$_dp_rc" -ne 0 ] || [ -n "$_dp_err" ]; then
    rm -f "$_dp_stream"
    printf '%s: 错误：delivery.rules 解析破坏（fail-closed，不产生部分结论）: %s\n' "$_dp_prefix" "$_dp_file" >&2
    if [ -n "$_dp_err" ]; then
      printf '%s\n' "$_dp_err" >&2
    fi
    return 2
  fi
  while IFS="$(printf '\t')" read -r _dp_d _dp_v; do
    [ -n "${_dp_d:-}" ] || continue
    case $_dp_d in
      dp_mainonly) DP_MAINONLY="$DP_MAINONLY$_dp_v
" ; DP_HAS_MAINONLY=1 ;;
    esac
  done < "$_dp_stream"
  rm -f "$_dp_stream"
  return 0
}

# ---- 参数解析 ----

force=''
path=''
branch=''
for _arg in "$@"; do
  case $_arg in
    --force) force=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die2 "未知参数: $_arg（用法见 --help）" ;;
    *)
      if [ -z "$path" ]; then
        path=$_arg
      elif [ -z "$branch" ]; then
        branch=$_arg
      else
        die2 '至多接受 <path> <branch> 两个位置参数（用法见 --help）'
      fi
      ;;
  esac
done
[ -n "$path" ] || { usage >&2; die2 '缺少 <path> <branch> 位置参数'; }
[ -n "$branch" ] || { usage >&2; die2 '缺少 <branch> 位置参数'; }

# ---- 主检出自拒（第一道闸：链接 worktree 内禁止运行）----

_gd=$(git rev-parse --absolute-git-dir 2>/dev/null) || die2 '目标不是 Git 工作区（须在主检出运行）'
_gcd=$(git rev-parse --git-common-dir 2>/dev/null) || die2 '目标不是 Git 工作区（须在主检出运行）'
case $_gcd in
  /*) ;;
  *) _gcd=$(CDPATH= cd "$(git rev-parse --show-toplevel)/$_gcd" && pwd) ;;
esac
if [ "$_gd" != "$_gcd" ]; then
  die1 "主检出自拒：当前在链接 worktree（git-dir ${_gd} ≠ common-dir ${_gcd}）。worktree 创建属协调层职责，请在主检出运行本脚本。"
fi

repo_root=$(git rev-parse --show-toplevel)

# ---- 分支名形态断言（ticket/<NN>-<slug>；git 分支名允许更宽，本命令收窄）----

case $branch in
  ticket/[0-9][0-9]*-*) ;;
  *) die1 "分支名不合 ticket/<NN>-<slug> 形态: ${branch}（一票一 worktree 纪律，路径与分支共用票号）" ;;
esac

# ---- 配置加载（未声明 main-only 节＝栅栏未知，拒跑 exit 2 fail-closed）----

dp_load_rules "$repo_root" "$prog" || exit 2
if [ "$DP_HAS_MAINONLY" -ne 1 ]; then
  printf '%s: 拒跑：delivery.rules 未声明 main-only 节（栅栏未知 fail-closed；如本仓无 main-only 脚本，登记空节或径用 git worktree add）\n' "$prog" >&2
  exit 2
fi

# ---- 目标防撞（同名目录已存在即停；--force 只透传 git 层）----

if [ -e "$path" ] && [ -z "${force:-}" ]; then
  die1 "目标路径已存在: ${path}（先核对是否遗留 worktree：git worktree list；确认可弃再 --force）"
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
wt_abs=$(CDPATH= cd "$path" && pwd) || die1 "新建 worktree 不可进入: $path"
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
_first=${DP_MAINONLY%%$'\n'*}
if [ -e "$wt_abs/$_first" ]; then
  die1 "栅栏未生效断言失败: $wt_abs/$_first 仍存在（排除模式未生效；请删除该 worktree 后重试）"
fi

printf '%s: 完成: %s（分支 %s）\n' "$prog" "$wt_abs" "$branch"
printf '%s: 栅栏已生效——以下 main-only 路径已从该 worktree 排除（物理不在场）：\n' "$prog"
printf '%s\n' "$DP_MAINONLY" | while IFS= read -r _v; do
  if [ -n "$_v" ]; then printf '%s:   !%s\n' "$prog" "$_v"; fi
done
printf '%s: 排除清单持久于 %s/info/sparse-checkout（随 worktree 删除一并消失）\n' "$prog" "$wt_gd"
exit 0
