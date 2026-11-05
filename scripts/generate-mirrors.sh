#!/bin/sh
# Input: 包清单 mirrors 节（同目录 package-manifest.rules 的 pm_mirror 行）与包侧
#        scripts/<文件名> 手写源；参数：--check（只读核对，不写）、--pkg-root <dir>、
#        --repo-root <dir>（缺省＝包根父目录）、-h/--help。
# Output: mirror 类登记件的仓侧生成物写入/核对报告：写模式逐件复制后立即 cmp 自证，
#        幂等（同输入同输出，内容与权限位一致）；--check 零写入，漂移/缺件/包侧源缺失
#         逐件指名并 exit 1；用法/环境/清单缺失 exit 2。汇总行含核对件数与改写件数。
# Pos: 镜像生成单入口（票 276 重开治理决定：包侧 agent-up/scripts/ 唯一手写源，仓侧
#      rules/implementation/scripts/ 为生成物）。生成物不得手工编辑；手工改动由
#      check-package.sh 检查 13 与 --check 核对拦截。package-only 件不生成不核对。
#      POSIX sh、零网络依赖、只读清单解析（非执行式）。
set -eu

usage() {
  cat <<USAGE
用法: sh generate-mirrors.sh [--check] [--pkg-root <dir>] [--repo-root <dir>]
参数:
  --check          只读核对仓侧生成物与包侧源（漂移/缺件即 exit 1，不写文件）
  --pkg-root <dir> 包根目录（含 SKILL.md）；缺省＝本脚本所在目录的父目录
  --repo-root <dir> 仓根目录（其 rules/implementation/scripts/ 为生成物落位）；缺省＝包根父目录
  -h / --help      打印本用法
退出码: 0 一致/生成成功；1 存在漂移或缺失；2 用法或环境错误
USAGE
}

script_dir=$(CDPATH='' cd -- "$(dirname "$0")" && pwd) || exit 2
pkg_root=$(CDPATH='' cd -- "$script_dir/.." && pwd) || exit 2
repo_root=''
mirror_mode='write'
while [ $# -gt 0 ]; do
  case $1 in
    --check) mirror_mode='check'; shift ;;
    --pkg-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; pkg_root=$2; shift 2 ;;
    --repo-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; repo_root=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'generate-mirrors: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -d "$pkg_root" ] || { printf 'generate-mirrors: 包根不存在: %s\n' "$pkg_root" >&2; exit 2; }
if [ -z "$repo_root" ]; then
  repo_root=$(CDPATH='' cd -- "$pkg_root/.." && pwd) || exit 2
fi
[ -d "$repo_root" ] || { printf 'generate-mirrors: 仓根不存在: %s\n' "$repo_root" >&2; exit 2; }
manifest="$script_dir/package-manifest.rules"
[ -f "$manifest" ] || { printf 'generate-mirrors: 包清单缺失: %s\n' "$manifest" >&2; exit 2; }
dst_dir="$repo_root/rules/implementation/scripts"
[ -d "$dst_dir" ] || { printf 'generate-mirrors: 仓侧生成物目录不存在: %s\n' "$dst_dir" >&2; exit 2; }

rows=$(LC_ALL=C awk '$1 == "pm_mirror" && $3 == "mirror" { print $2 }' "$manifest")
if [ -z "$rows" ]; then
  printf 'generate-mirrors: 错误：mirrors 节零 mirror 类登记（fail-closed）\n' >&2
  exit 2
fi

checked=0
changed=0
problems=''
sep=''
while IFS= read -r f; do
  [ -n "$f" ] || continue
  src="$pkg_root/scripts/$f"
  dst="$dst_dir/$f"
  if [ ! -f "$src" ]; then
    problems="$problems$sep  - 包侧手写源缺失: scripts/$f"
    sep='
'
    continue
  fi
  checked=$((checked + 1))
  if [ "$mirror_mode" = check ]; then
    if [ ! -f "$dst" ]; then
      problems="$problems$sep  - rules/implementation/scripts/$f 生成物缺失（由 generate-mirrors.sh 生成）"
      sep='
'
    elif ! cmp -s "$src" "$dst"; then
      problems="$problems$sep  - rules/implementation/scripts/$f 与包侧 scripts/$f 不一致（生成物漂移，重跑 generate-mirrors.sh）"
      sep='
'
    elif [ ! -x "$dst" ]; then
      problems="$problems$sep  - rules/implementation/scripts/$f 执行位缺失（生成物权限位须 755）"
      sep='
'
    fi
  else
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
      if [ ! -x "$dst" ]; then
        chmod 755 "$dst"
        changed=$((changed + 1))
      fi
    else
      cp "$src" "$dst"
      chmod 755 "$dst"
      changed=$((changed + 1))
      if ! cmp -s "$src" "$dst"; then
        problems="$problems$sep  - rules/implementation/scripts/$f 生成后 cmp 不一致（自证失败）"
        sep='
'
      fi
    fi
  fi
done <<EOF
$rows
EOF

if [ -n "$problems" ]; then
  printf 'generate-mirrors: 错误：镜像生成物与包侧源不一致（fail-closed）:\n%s\n' "$problems" >&2
  exit 1
fi
if [ "$mirror_mode" = check ]; then
  printf 'OK: 镜像生成物与包侧源一致（核对 %s 件）\n' "$checked"
else
  printf 'OK: 镜像生成完成（核对 %s 件，改写 %s 件，逐件 cmp 一致）\n' "$checked" "$changed"
fi
