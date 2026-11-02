#!/bin/sh
# Input: 目标 worktree 根（可选位置参数，缺省＝当前目录）；可选 --clone-accel 与
#        --clone-from <目录>（克隆加速，缺省关闭）；目标根 package.json 及其
#        workspaces 清单（数组或 {"packages": [...]} 形态）。
# Output: 依赖准备单命令的逐项判定行与完成行——符号链接 node_modules 直接拒绝
#        （exit 1 指名绝对路径）；安装前逐项断言根与各 workspace 的 package.json
#        在位，缺失即 fail-closed 零安装（exit 1 指名缺失路径）；断言全过后在目标根
#        执行 npm install，安装后断言 node_modules 为真实目录（非符号链接）；
#        workspace 模式命中项只取目录（普通文件静默跳过，与 npm 行为一致），支持简单
#        brace（packages/{app,lib}）；
#        目标根无 package.json 的仓库显式 skip 且 exit 0（非 npm 仓库不制造假失败）。
#        克隆加速默认关闭：仅 --clone-accel 且 --clone-from 显式给出时，安装前以
#        cp -cR（clonefile）播种 node_modules，文件系统不支持时回退普通复制并提示。
# Pos: 一票一 worktree 工作流的依赖隔离单命令（创建面 worktree-add.sh 完成行提示
#      接入本命令）。每个 worktree 拥有独立真实 node_modules——符号链接共享会把
#      「只读复用」与「安装先删后建」混在一起，任一 worktree 安装即清空他人依赖。
#      POSIX sh；不删除既有 worktree；不修改 package.json/lockfile；联网仅发生在
#      npm install（测试以临时夹具与假 npm 模拟，不触发真实网络）。
#      一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。

set -eu
set -f  # 关闭文件名展开：默认不依赖 glob（workspace 模式局部恢复）

_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'worktree-deps: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

prog=worktree-deps

usage() {
  cat <<'USAGE'
用法: sh worktree-deps.sh [--clone-accel --clone-from <dir>] [<worktree-root>]
参数:
  <worktree-root>   目标 worktree 根（绝对或相对路径）；缺省＝当前目录。
  --clone-accel     克隆加速（默认关闭）：安装前以 clonefile 从 --clone-from
                    播种 node_modules；不支持 clonefile 的文件系统回退普通复制。
  --clone-from <dir> 播种源目录（真实目录，禁符号链接）；与 --clone-accel 同用。
  -h / --help       打印本用法。
行为:
  1. 目标根 node_modules 为符号链接即拒绝（exit 1 指名路径）；各 workspace 的
     node_modules 同款检查。
  2. 目标根无 package.json＝非 npm 仓库，显式 skip 并 exit 0。
  3. 读 package.json workspaces，逐项展开（支持 packages/{app,lib} 形态的简单
     brace；命中项只取目录，普通文件静默跳过）；每个 workspace 的 package.json 须
     在场，缺失即 fail-closed（exit 1 指名缺失路径，零安装）。多组或嵌套 brace
     不支持，命中即 exit 2 指名并建议改用目录列举。
  4. 全部断言过后在目标根执行 npm install；安装后断言 node_modules 为真实目录。
退出码:
  0  依赖准备完成，或非 npm 仓库显式 skip。
  1  fail-closed（符号链接 node_modules、workspace 清单缺失、npm install 失败、
     安装后 node_modules 非真实目录）。
  2  用法或环境错误（参数不合、目标根不存在、node/npm 不可用、JSON 清单损坏、
     --clone-accel 缺 --clone-from、播种源不合）。
USAGE
}

# ---- 参数解析 ----

repo=''
clone_accel=''
clone_from=''
for _arg in "$@"; do
  case $_arg in
    --clone-accel) clone_accel=1 ;;
    --clone-from)
      # 值在下一轮读取：用显式状态位避免把 --clone-from 的值误判为位置参数
      clone_from='__pending__'
      ;;
    -h|--help) usage; exit 0 ;;
    -*) die2 "未知参数: ${_arg}（用法见 --help）" ;;
    *)
      if [ "$clone_from" = '__pending__' ]; then
        clone_from=$_arg
      elif [ -z "$repo" ]; then
        repo=$_arg
      else
        die2 "至多接受一个 <worktree-root>（用法见 --help）"
      fi
      ;;
  esac
done
if [ "$clone_from" = '__pending__' ]; then
  die2 '--clone-from 缺少目录参数'
fi

if [ -z "$repo" ]; then
  repo='.'
fi
[ -d "$repo" ] || die2 "目标 worktree 根不存在: ${repo}"
repo=$(CDPATH='' cd -- "$repo" && pwd -P) || die2 "目标 worktree 根不可进入: ${repo}"

if [ -n "$clone_accel" ] && [ -z "$clone_from" ]; then
  die2 '--clone-accel 须与 --clone-from <目录> 同用（播种源显式给出，不猜）'
fi
if [ -n "$clone_from" ] && [ -z "$clone_accel" ]; then
  die2 '--clone-from 须与 --clone-accel 同用（克隆加速默认关闭）'
fi
if [ -n "$clone_from" ]; then
  [ -d "$clone_from" ] || die2 "播种源不存在: ${clone_from}"
  [ -L "$clone_from" ] && die2 "播种源为符号链接，拒绝: ${clone_from}（依赖目录必须为真实目录）"
  clone_from=$(CDPATH='' cd -- "$clone_from" && pwd -P) || die2 "播种源不可进入: ${clone_from}"
fi

# ---- 符号链接拒绝（先于任何 skip/安装判定：发现即拒绝，不因非 npm 仓库放过）----

_reject_symlink_node_modules() {
  # $1＝候选 node_modules 路径（绝对）
  if [ -L "$1" ]; then
    die1 "符号链接 node_modules 拒绝: $1（依赖目录必须为真实目录；移除链接后在本 worktree 独立安装）"
  fi
}
_reject_symlink_node_modules "$repo/node_modules"

# ---- 非 npm 仓库显式 skip（无 package.json＝不制造假失败）----

if [ ! -f "$repo/package.json" ]; then
  printf '%s: SKIP: 非 npm 仓库（目标根无 package.json）: %s\n' "$prog" "$repo"
  exit 0
fi

# ---- workspace 清单解析（node 为 npm 生态自带运行时；JSON 损坏 fail-closed）----

command -v node >/dev/null 2>&1 || \
  die2 'node 不可用：解析 package.json workspaces 依赖 node（npm 仓库必带 node）'
_ws_tmp=$(mktemp "${TMPDIR:-/tmp}/wtdeps.XXXXXX") || die2 '临时文件创建失败'
trap 'rm -f "$_ws_tmp"' EXIT HUP INT TERM

if ! node -e '
const fs = require("fs");
let p;
try { p = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { process.exit(2); }
let w = p.workspaces;
if (w === undefined) process.exit(0);
if (Array.isArray(w)) { /* array form */ }
else if (w && Array.isArray(w.packages)) w = w.packages;
else process.exit(3);
for (const x of w) {
  if (typeof x !== "string" || x === "") process.exit(3);
  process.stdout.write(x + "\n");
}
' "$repo/package.json" > "$_ws_tmp"; then
  die2 "package.json 不可解析或 workspaces 形态不合: ${repo}/package.json"
fi

# ---- 逐项断言（全部先于安装；任一缺失即零安装）----

# 单个模式（brace 已展开）匹配：只收目录，普通文件静默跳过（与 npm workspaces 一致）
_ws_append_matches() {
  case $1 in
    *'*'*|*'?'*|*'['*)
      set +f
      # shellcheck disable=SC2086  # 需按 npm workspaces 模式展开 glob（脚本常态 set -f，此处局部恢复）
      for _ws_hit in "$repo"/$1; do
        set -f
        if [ -d "$_ws_hit" ]; then
          _ws_matches="$_ws_matches$_ws_hit
"
        fi
      done
      set -f
      ;;
    *)
      if [ -d "$repo/$1" ]; then
        _ws_matches="$_ws_matches$repo/$1
"
      fi
      ;;
  esac
}

while IFS= read -r _ws_pattern; do
  [ -n "$_ws_pattern" ] || continue
  case $_ws_pattern in
    /*) die2 "workspaces 条目禁绝对路径: ${_ws_pattern}（${repo}/package.json）" ;;
    *..*)
      case $_ws_pattern in
        *'{'*'..'*) die2 "workspaces 条目不支持 brace range: ${_ws_pattern}（${repo}/package.json；请改用目录列举或 {a,b} 形态）" ;;
      esac
      die2 "workspaces 条目禁 .. 段: ${_ws_pattern}（${repo}/package.json）" ;;

    *' '*|*'	'*) die2 "workspaces 条目禁空白: ${_ws_pattern}（${repo}/package.json）" ;;
  esac
  _ws_matches=''
  case $_ws_pattern in
    *'{'*)
      # 简单 brace 展开（packages/{app,lib}）：单大括号组、逗号分隔；多组/嵌套显式拒跑
      _ws_pre=${_ws_pattern%%\{*}
      _ws_rest=${_ws_pattern#*\{}
      case $_ws_rest in
        *'}'*) ;;
        *) die2 "workspaces 条目 brace 未闭合: ${_ws_pattern}（${repo}/package.json；请改用目录列举）" ;;
      esac
      _ws_body=${_ws_rest%%\}*}
      _ws_post=${_ws_rest#*\}}
      case $_ws_body in
        *'{'*|*'}'*) die2 "workspaces 条目不支持嵌套 brace: ${_ws_pattern}（${repo}/package.json；请改用目录列举）" ;;
      esac
      case $_ws_post in
        *'{'*) die2 "workspaces 条目不支持多组 brace: ${_ws_pattern}（${repo}/package.json；请改用目录列举）" ;;
      esac
      _ws_saved_ifs=$IFS
      IFS=','
      set -f
      for _ws_alt in $_ws_body; do
        IFS=$_ws_saved_ifs
        _ws_append_matches "${_ws_pre}${_ws_alt}${_ws_post}"
        IFS=','
      done
      IFS=$_ws_saved_ifs
      set -f
      ;;
    *)
      _ws_append_matches "$_ws_pattern"
      ;;
  esac
  if [ -z "$_ws_matches" ]; then
    die1 "workspace 清单缺失: $repo/$_ws_pattern/package.json（声明模式未命中任何目录；安装前断言，零安装）"
  fi
  # here-doc 替代 printf 管道：断言失败直接在脚本主 shell 退出，不依赖管道退出码
  while IFS= read -r _ws_dir; do
    [ -n "$_ws_dir" ] || continue
    if [ ! -f "$_ws_dir/package.json" ]; then
      die1 "workspace 清单缺失: $_ws_dir/package.json（安装前断言，零安装）"
    fi
    if [ -L "$_ws_dir/node_modules" ]; then
      die1 "符号链接 node_modules 拒绝: $_ws_dir/node_modules（依赖目录必须为真实目录；移除链接后在本 worktree 独立安装）"
    fi
  done <<EOF
$_ws_matches
EOF
done < "$_ws_tmp"

# ---- 克隆加速（默认关闭；显式开启才播种，播种失败回退普通复制）----

if [ -n "$clone_accel" ]; then
  if [ -e "$repo/node_modules" ]; then
    printf '%s: NOTE: 目标根已存在 node_modules，跳过克隆加速播种: %s\n' "$prog" "$repo/node_modules"
  else
    if cp -cR "$clone_from" "$repo/node_modules" 2>/dev/null; then
      printf '%s: 克隆加速：clonefile 播种完成: %s -> %s\n' "$prog" "$clone_from" "$repo/node_modules"
    else
      warn "clonefile 不可用（跨文件系统或平台差异），回退普通复制: ${clone_from} -> ${repo}/node_modules"
      cp -R "$clone_from" "$repo/node_modules" || \
        die1 "播种复制失败: ${clone_from} -> ${repo}/node_modules（依赖目录未准备）"
    fi
  fi
fi

# ---- 安装与安装后断言 ----

command -v npm >/dev/null 2>&1 || die2 'npm 不可用：依赖准备须 npm（PATH 内未找到）'
if ! ( cd "$repo" && npm install ); then
  die1 "npm install 失败: ${repo}（依赖目录可能不完整，请修复后重试；不静默继续）"
fi
if [ -L "$repo/node_modules" ] || [ ! -d "$repo/node_modules" ]; then
  die1 "安装后断言失败: ${repo}/node_modules 不是真实目录（禁止符号链接共享依赖）"
fi

printf '%s: 完成: %s（node_modules 为真实目录，依赖按 worktree 隔离）\n' "$prog" "$repo"
exit 0
