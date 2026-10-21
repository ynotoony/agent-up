#!/bin/sh
# Input: 仓库根目录（缺省自本脚本位置向上两级推导，位置参数可指定）、--dry-run 开关，
#        与仓根 delivery.rules payload 节（dp_payload_root／dp_payload_remote／
#        dp_payload_target／dp_payload_local_ref；未声明 payload 节即拒跑 exit 2，
#        解析破坏 exit 2——票 69 设计 §2 契约）。
# Output: 六步导出流程（split→树比对→导出树 check-package→ff 断言→push→ls-remote
#         复核）的逐步进度行与结果；--dry-run 执行第 1～4 步（split 头仅经变量传递
#         不落本地分支引用，临时目录即用即删），第 5 步只打印将执行的 push 命令、
#         第 6 步跳过，全程零远端写、零本地分支写，退出码语义同实跑；任何失败停手。
# Pos: 公开载荷导出单命令（票 69 设计 §3 命令面／票 72 落地）：单命令固化票 68 的手工
#      三重核验；ff 断言＝污染检测（远端 target 头非新导出头祖先即停手，报错文案照
#      设计逐字）；本命令永不 force——不内建任何改写远端历史的路径（理由见设计 §3：
#      force 属用户授权动作，票 68 的修复即用户明确授权下的一次性救援）；树比对用全新
#      mktemp 展开即用即删（票 68 教训：禁陈旧 /tmp 展开与 worktree .git 接线文件）；
#      delivery.rules 解析引擎段内嵌（fail-closed 六规则照设计 §2，供本脚本消费；
#      引擎零项目约定硬编码——前缀/远端/分支全部读配置）；POSIX sh；真实推送公开仓
#      须用户现场授权（本仓以 --dry-run 为准）。
# dp-parser: 2
#      （本件要求解析器最低版注记；解析唯一实现＝同目录 dp-load-rules.sh，版本唯一
#      来源＝其 DP_PARSER_VERSION。落地拷贝遇未知锚点/指令、解析器缺件或版本漂移即
#      报错指名——同步方式见 references/old-project.md §3 dp-load-rules.sh 引擎件行，
#      文法与版本详见 references/delivery-rules.md。四件同族脚本注记须一致。）

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  die2() { printf '%s: 错误：%s\n' "$prog" "$1" >&2; exit 2; }
fi

prog=export-payload

usage() {
  cat <<'USAGE'
用法: sh export-payload.sh [--dry-run] [repo-root]
参数:
  --dry-run   执行步骤 1～4（split 头仅经变量传递不落本地分支引用，临时目录即用即删），
              第 5 步只打印将执行的 push 命令、第 6 步跳过；全程零远端写、零本地分支写。
  repo-root   仓库根目录（读 <root>/delivery.rules）；缺省取本脚本所在目录向上两级。
退出码:
  0  流程完成（或 --dry-run 步骤 1～4 完成）。
  1  流程失败停手（工作区不洁、树比对差异、check-package 未全过、ff 断言不过、推送后漂移）。
  2  用法或配置错误（参数不合、非 Git 工作区、delivery.rules 缺失 payload 节或解析破坏、
     payload 根不存在、git subtree 不可用）。
USAGE
}

# ---- 参数解析 ----

dry_run=0
repo_root=''
for _arg in "$@"; do
  case $_arg in
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die2 "未知参数: ${_arg}（用法见 --help）" ;;
    *)
      if [ -n "$repo_root" ]; then
        die2 "至多接受一个 repo-root 位置参数（用法见 --help）"
      fi
      repo_root=$_arg
      ;;
  esac
done

# ---- 主检出门禁（真跑前置；R-DP-036：公开仓推送属 main-only 动作，禁止自链接
#      worktree 发布未合并分支——链接 worktree 判别＝git-dir ≠ git-common-dir。
#      --dry-run 零写入零远端接触，不受本门禁约束）----

if [ "$dry_run" -ne 1 ]; then
  _ep_gd=$(git rev-parse --absolute-git-dir 2>/dev/null) || die2 '目标不是 Git 工作区'
  _ep_gcd=$(git rev-parse --git-common-dir 2>/dev/null) || die2 '目标不是 Git 工作区'
  case $_ep_gcd in
    /*) ;;
    *) _ep_gcd=$(CDPATH='' cd "$(git rev-parse --show-toplevel)/$_ep_gcd" && pwd) ;;
  esac
  if [ "$_ep_gd" != "$_ep_gcd" ]; then
    printf '%s: FAIL: 主检出门禁：当前在链接 worktree（git-dir %s ≠ common-dir %s）。真跑推送属 main-only 动作（R-DP-036）：未合并分支不得上公开仓，请在主检出（main）运行；--dry-run 不受限。\n' "$prog" "${_ep_gd}" "${_ep_gcd}" >&2
    exit 1
  fi
fi

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
if [ -z "$repo_root" ]; then
  repo_root=$(CDPATH='' cd "$script_dir/../.." && pwd) || die2 '仓库根推导失败（脚本位置异常），请显式传 repo-root'
fi
[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die2 "目标不是 Git 工作区: $repo_root"

# ---- 配置加载（未声明 payload 节＝未声明导出形态，拒跑 exit 2，设计 §2 缺省行为）----

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
if [ "$DP_HAS_PAYLOAD" -ne 1 ]; then
  printf '%s: 拒跑：delivery.rules 未声明 payload 节（未声明导出形态，设计 §2 缺省行为）\n' "$prog" >&2
  exit 2
fi
payload_dir="$repo_root/$DP_ROOT"
[ -d "$payload_dir" ] || die2 "payload 根不存在: $repo_root/${DP_ROOT}（核对 dp_payload_root）"

# ---- 前置：工作区 payload 根内有未提交改动 → 报错停手（导出半成品）----

_dirty=$(git -C "$repo_root" status --porcelain -- "$DP_ROOT") || true
if [ -n "$_dirty" ]; then
  printf '%s: FAIL: 工作区 payload 根 %s 内有未提交改动（导出半成品），已停手。先提交或清理：\n' "$prog" "$DP_ROOT" >&2
  printf '%s\n' "$_dirty" | sed 's/^/  /' >&2
  exit 1
fi

# ---- 步骤 1/6：split（--dry-run 不落本地分支引用，split 头仅经变量传递）----

printf '%s: 步骤 1/6 subtree split（prefix=%s%s）\n' "$prog" "$DP_ROOT" "${dry_run:+，--dry-run 不落本地分支引用}"
if [ "$dry_run" -eq 1 ]; then
  if ! H=$(git -C "$repo_root" subtree split -P "$DP_ROOT"); then
    printf '%s: FAIL: git subtree split 失败（git subtree 子命令不可用或仓库状态异常），已停手\n' "$prog" >&2
    exit 2
  fi
else
  if ! git -C "$repo_root" subtree split -P "$DP_ROOT" -b "$DP_LOCAL_REF" >/dev/null 2>&1; then
    printf '%s: FAIL: git subtree split -b %s 失败（分支被占用或 git subtree 子命令不可用），已停手\n' "$prog" "$DP_LOCAL_REF" >&2
    exit 2
  fi
  H=$(git -C "$repo_root" rev-parse --verify "refs/heads/$DP_LOCAL_REF")
fi
[ -n "$H" ] || { printf '%s: FAIL: split 未产出导出头，已停手\n' "$prog" >&2; exit 2; }
printf '%s: 导出头 H=%s\n' "$prog" "$H"

# ---- 步骤 2/6：树比对（全新 mktemp 展开即用即删，票 68 教训）----

_t_dir=${TMPDIR:-/tmp}
tmp_tree=$(mktemp -d "${_t_dir%/}/export-payload-tree.XXXXXX")
tmp_diff=$(mktemp "${_t_dir%/}/export-payload-diff.XXXXXX")
# shellcheck disable=SC2329  # trap 引用的清理函数——shellcheck 单文件视野误报（dp_cleanup 由 trap 回调）
dp_cleanup() { rm -rf "$tmp_tree"; rm -f "$tmp_diff"; }
trap dp_cleanup EXIT HUP INT TERM

printf '%s: 步骤 2/6 树比对（导出头 archive 全新 mktemp 展开 vs 工作区 %s）\n' "$prog" "$DP_ROOT"
if ! git -C "$repo_root" archive "$H" | tar -x -C "$tmp_tree"; then
  printf '%s: FAIL: 导出头 %s archive 展开失败，已停手\n' "$prog" "$H" >&2
  exit 1
fi
# 排除 .git 名：git archive 天然不含 .git；worktree 顶层接线文件（票 68 教训）不得入比对。
if ! diff -r -x '.git' "$tmp_tree" "$payload_dir" > "$tmp_diff" 2>&1; then
  printf '%s: FAIL: 树比对存在差异（疑似未提交改动、忽略文件或展开污染），已停手未推送。差异：\n' "$prog" >&2
  sed 's/^/  /' "$tmp_diff" >&2
  exit 1
fi
printf '%s: 树比对零差异\n' "$prog"

# ---- 步骤 3/6：导出树 check-package（独立语境：检查 13 镜像静默跳过＝预期，票 68 口径）----

printf '%s: 步骤 3/6 导出树 check-package（逐项核对；检查 13 独立语境静默跳过＝预期）\n' "$prog"
if ! sh "$tmp_tree/scripts/check-package.sh" "$tmp_tree"; then
  printf '%s: FAIL: 导出树 check-package 未全过，已停手未推送\n' "$prog" >&2
  exit 1
fi

# ---- 步骤 4/6：ff 断言（污染检测；报错文案照设计 §3 逐字）----

printf '%s: 步骤 4/6 ff 断言（远端 %s target=%s）\n' "$prog" "$DP_REMOTE" "$DP_TARGET"
R=$(git -C "$repo_root" ls-remote "$DP_REMOTE" "refs/heads/$DP_TARGET" 2>/dev/null | LC_ALL=C awk '{print $1; exit}') || R=''
if [ -n "$R" ]; then
  if ! git -C "$repo_root" merge-base --is-ancestor "$R" "$H"; then
    # shellcheck disable=SC2016  # printf 格式串含字面反引号文案（刻意单引号；shellcheck 对格式串反引号字面量的长尾误报）
    printf '%s: FAIL: ff 断言不过——远端 `%s/%s` 头 `%s` 不是新导出头 `%s` 的祖先。远端分支含导出管线之外的历史（疑似他人直推、回滚或覆盖污染）。已停手，未推送。本命令永不 --force；如确认远端需恢复或覆盖，须用户明确授权并另票执行（先例：票 68 载荷边界恢复）。\n' \
      "$prog" "$DP_REMOTE" "$DP_TARGET" "$R" "$H" >&2
    exit 1
  fi
  printf '%s: ff 断言通过（远端头 %s 为导出头 %s 祖先）\n' "$prog" "$R" "$H"
else
  printf '%s: 远端 %s 分支 %s 不存在＝首推放行\n' "$prog" "$DP_REMOTE" "$DP_TARGET"
fi

# ---- 步骤 5/6：push（裸 push，无 --force；--dry-run 只打印将执行命令）----

if [ "$dry_run" -eq 1 ]; then
  printf '%s: 步骤 5/6 --dry-run：将执行 push 命令（未执行）：\n  git push %s %s:%s\n' \
    "$prog" "$DP_REMOTE" "$DP_LOCAL_REF" "$DP_TARGET"
  printf '%s: 步骤 6/6 --dry-run 跳过（ls-remote 复核属推送后动作）\n' "$prog"
  printf '%s: --dry-run 完成（步骤 1～4 实跑：split 未落本地分支引用、零远端写、临时目录即用即删）\n' "$prog"
  exit 0
fi

printf '%s: 步骤 5/6 push（裸 push，第 4 步已保证 fast-forward）\n' "$prog"
if ! git -C "$repo_root" push "$DP_REMOTE" "$DP_LOCAL_REF:$DP_TARGET"; then
  printf '%s: FAIL: push 被拒（远端或网络拒绝），已停手\n' "$prog" >&2
  exit 1
fi

# ---- 步骤 6/6：ls-remote 复核（推送后漂移检测）----

printf '%s: 步骤 6/6 ls-remote 复核\n' "$prog"
R2=$(git -C "$repo_root" ls-remote "$DP_REMOTE" "refs/heads/$DP_TARGET" 2>/dev/null | LC_ALL=C awk '{print $1; exit}') || R2=''
if [ "$R2" != "$H" ]; then
  printf '%s: FAIL: 推送后漂移——远端 %s/%s 头 %s ≠ 导出头 %s，已停手（人工核对远端）\n' \
    "$prog" "$DP_REMOTE" "$DP_TARGET" "${R2:-（空）}" "$H" >&2
  exit 1
fi
printf '%s: 完成：远端 %s/%s ＝ 导出头 %s\n' "$prog" "$DP_REMOTE" "$DP_TARGET" "$H"
exit 0
