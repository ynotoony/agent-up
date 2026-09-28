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

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

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

die2() {
  printf '%s: 错误：%s\n' "$prog" "$1" >&2
  exit 2
}

# ---- delivery.rules 解析引擎段（fail-closed 六规则，设计 §2；消费方共用逻辑，本段
#      内嵌于各消费脚本：未知指令①恰数违②枚举违③跨行重复④路径形态违⑤锚点重复或
#      条目违属⑥，任一命中 exit 2 口径返回 2，不产生部分结论）----
# 用法: dp_load_rules <repo-root> <错误前缀>
# 副作用全局: DP_PRESENT（0/1）、DP_HAS_PAYLOAD（0/1）、DP_ROOT、DP_REMOTE、DP_TARGET、
#   DP_LOCAL_REF、DP_FORBID、DP_EXEMPT、DP_STALE_LIT（清单变量为换行分隔，尾带换行）。
# 返回: 0 正常（含文件缺失＝全默认未声明）；2 解析破坏（错误行已打印 stderr，全局变量
#   不承载部分结论）。
dp_load_rules() {
  DP_PRESENT=0
  DP_HAS_PAYLOAD=0
  DP_ROOT=''; DP_REMOTE=''; DP_TARGET=''; DP_LOCAL_REF=''
  DP_FORBID=''; DP_EXEMPT=''; DP_STALE_LIT=''
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
      sc[1] = "payload"; sc[2] = "boundary"; sc[3] = "calibration"
    }
    function is_known(d) {
      return (d == "dp_payload_root" || d == "dp_payload_remote" || d == "dp_payload_target" \
        || d == "dp_payload_local_ref" || d == "dp_forbid" || d == "dp_artifact_exempt" \
        || d == "dp_stale_lit")
    }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      hit = 0
      for (k = 1; k <= 3; k++) {
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
      if ((d == "dp_payload_root" || d == "dp_forbid" || d == "dp_artifact_exempt")) {
        if (v ~ /^\//) { bad("路径禁前导斜杠: " v); next }
        if (v ~ /(^|\/)\.\.(\/|$)/) { bad("路径含 .. 段: " v); next }
      }
      if (d == "dp_stale_lit" && v != "S1" && v != "S2") { bad("枚举违（dp_stale_lit ∈ {S1,S2}）: " v); next }
      if (v in seenval) bad("值跨行重复: " v)
      else seenval[v] = 1
      if (d ~ /^dp_payload_/) cnt[d]++
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
      dp_payload_root) DP_ROOT=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_remote) DP_REMOTE=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_target) DP_TARGET=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_payload_local_ref) DP_LOCAL_REF=$_dp_v; DP_HAS_PAYLOAD=1 ;;
      dp_forbid) DP_FORBID="$DP_FORBID$_dp_v
" ;;
      dp_artifact_exempt) DP_EXEMPT="$DP_EXEMPT$_dp_v
" ;;
      dp_stale_lit) DP_STALE_LIT="$DP_STALE_LIT$_dp_v
" ;;
    esac
  done < "$_dp_stream"
  rm -f "$_dp_stream"
  return 0
}

# ---- 参数解析 ----

dry_run=0
repo_root=''
for _arg in "$@"; do
  case $_arg in
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die2 "未知参数: $_arg（用法见 --help）" ;;
    *)
      if [ -n "$repo_root" ]; then
        die2 "至多接受一个 repo-root 位置参数（用法见 --help）"
      fi
      repo_root=$_arg
      ;;
  esac
done

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
if [ -z "$repo_root" ]; then
  repo_root=$(CDPATH= cd "$script_dir/../.." && pwd) || die2 '仓库根推导失败（脚本位置异常），请显式传 repo-root'
fi
[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die2 "目标不是 Git 工作区: $repo_root"

# ---- 配置加载（未声明 payload 节＝未声明导出形态，拒跑 exit 2，设计 §2 缺省行为）----

dp_load_rules "$repo_root" "$prog" || exit 2
if [ "$DP_HAS_PAYLOAD" -ne 1 ]; then
  printf '%s: 拒跑：delivery.rules 未声明 payload 节（未声明导出形态，设计 §2 缺省行为）\n' "$prog" >&2
  exit 2
fi
payload_dir="$repo_root/$DP_ROOT"
[ -d "$payload_dir" ] || die2 "payload 根不存在: $repo_root/$DP_ROOT（核对 dp_payload_root）"

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

printf '%s: 步骤 3/6 导出树 check-package（17 项；检查 13 独立语境静默跳过＝预期）\n' "$prog"
if ! sh "$tmp_tree/scripts/check-package.sh" "$tmp_tree"; then
  printf '%s: FAIL: 导出树 check-package 未全过，已停手未推送\n' "$prog" >&2
  exit 1
fi

# ---- 步骤 4/6：ff 断言（污染检测；报错文案照设计 §3 逐字）----

printf '%s: 步骤 4/6 ff 断言（远端 %s target=%s）\n' "$prog" "$DP_REMOTE" "$DP_TARGET"
R=$(git -C "$repo_root" ls-remote "$DP_REMOTE" "refs/heads/$DP_TARGET" 2>/dev/null | LC_ALL=C awk '{print $1; exit}') || R=''
if [ -n "$R" ]; then
  if ! git -C "$repo_root" merge-base --is-ancestor "$R" "$H"; then
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
