#!/bin/sh
# Input: 仓库根目录（默认自本脚本位置向上两级推导，第一参数可指定）、本文件登记表内
#        的易腐状态句条目，与模式开关（第二参数或 STALE_CLAIMS_MODE 环境变量）。
# Output: 登记条目逐项核对结果——STALE 行（过期断言，含 路径:行号:内容 定位）、
#         WARN 行（提醒，含登记日期与【待定】阈值标注）、NOTE 行（比对机制退化说明，
#         不计入失败）、结尾汇总行；票收口模式（gate）发现过期断言 exit 1，
#         会话启动模式（session）仅输出警告 exit 0。
# Pos: 登记表驱动的易腐断言扫描器（REQ-20260904-010 / 票 19）；POSIX sh、
#      零外部依赖、全程只读（除打印外无写操作，Git 仅使用只读子命令）。

# 用法、登记表条目说明与输出格式见同目录 README.md。
# 状态陈述纪律见 development-process 模板 §15：状态以权威引用表达，本脚本
# 即"登记表条目 = 权威位置 + 核对方式"的执行器。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

usage() {
  cat <<'USAGE'
用法: sh check-stale-claims.sh [repo-root] [gate|session]
参数:
  repo-root  待核对的仓库根目录；缺省时取本脚本所在目录向上两级（脚本位于 agent-up/scripts/）。
  模式        gate  票收口模式（默认）：发现过期断言输出定位并 exit 1，清洁 exit 0。
              session 会话启动模式：同样输出 STALE/WARN 但只作警告，恒 exit 0。
  也可用环境变量 STALE_CLAIMS_MODE=session 指定会话启动模式（第二参数优先）。
  -h / --help 打印本用法。
退出码:
  0  gate 模式下无过期断言（提醒照常输出），或 session 模式。
  1  gate 模式下存在过期断言（STALE 行见输出）。
  2  用法或环境错误（参数过多、模式非法、仓库根不存在等）。
NOTE 行为比对机制退化说明（生成器不可用时退化为内建最小比对），不计入失败。
登记表条目、校验方式与提醒阈值口径见同目录 README.md。
USAGE
}

prog_name() {
  # 输出脚本自身文件名，供汇总行使用（避免在文本里重复书写）。
  printf '%s' "check-stale-claims"
}

stale_count=0
warn_count=0

emit_stale() {
  # $1=定位（路径:行号 或 路径） $2=断言与现实的差异说明
  printf 'STALE: %s — %s\n' "$1" "$2"
  stale_count=$((stale_count + 1))
}

emit_warn() {
  # $1=定位 $2=提醒内容。存在时长阈值未定稿，统一标注【待定】。
  printf 'WARN: %s — %s（提醒自 2026-09-04 登记，存在时长阈值【待定】）\n' "$1" "$2"
  warn_count=$((warn_count + 1))
}

# ---- 通用小工具 -----------------------------------------------------------

first_grep_line() {
  # $1=模式(BRE) $2=文件；输出首个命中行的 行号:内容，无命中输出空。
  grep -n "$1" "$2" 2>/dev/null | sed -n '1p'
}

trim_git_url() {
  # 归一化 Git 远端地址：去结尾 .git 与结尾空白。
  printf '%s' "$1" | sed 's/\.git$//;s/[[:space:]]*$//'
}

prog_dir() {
  # 输出本脚本所在目录绝对路径（供 S3 定位同目录生成器）。
  CDPATH= cd "$(dirname "$0")" && pwd
}

# ---- 参数解析 --------------------------------------------------------------

if [ $# -gt 2 ]; then
  printf 'check-stale-claims: 错误：至多接受两个参数\n' >&2
  usage >&2
  exit 2
fi
mode=${STALE_CLAIMS_MODE:-gate}
if [ $# -eq 1 ]; then
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
  esac
fi
if [ $# -eq 2 ]; then
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
  esac
  mode=$2
fi
case $mode in
  gate | session) ;;
  *)
    printf 'check-stale-claims: 错误：非法模式 %s（可用 gate|session）\n' "$mode" >&2
    exit 2
    ;;
esac

script_dir=$(prog_dir)
if [ $# -ge 1 ]; then
  repo_root=$1
else
  repo_root=$(CDPATH= cd "$script_dir/../.." && pwd)
fi
if [ ! -d "$repo_root" ]; then
  printf 'check-stale-claims: 错误：仓库根目录不存在：%s\n' "$repo_root" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 登记表（首批三条，结构：断言模式 | 权威位置 | 校验方式）
#
# S1 Git 状态句 | docs/progress.md 的「Git 恢复基线」块
#    | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、
#      唯一 remote 与宣称地址一致、本地 main 未被他者远端分支包含）；非 Git 工作区按
#      流程退化语义输出提醒跳过。（2026-09-18 票 37 修订：移除"工作区存在未提交改动"
#      子项核对（原 1e）——该陈述为票 13 时点历史快照，docs/progress.md 现为冻结历史
#      档案（零写入），清洁工作区属稳态，逐字核对构成恒触发误报（S1-1e 已知缺口，
#      1080560 补记在案）；基线块原文按"不改历史"保留，不因本修订改写。）
# S2 发布状态句 | 根 README.md 宣称行 + agent-up/README.md 安装行
#    | machine：文档宣称的仓库地址与实际远端配置归一化比对；远端可达性/可见性本地
#      不核验（不出网）→ reminder。
# S3 frontier 句 | docs/issues/index.json（票状态真相源）+ docs/progress-current.md（现役状态投影）
#    | machine：投影 vs 索引比对——优先调用 generate-progress.sh --check（exit 0 一致；
#      exit 1 投影 stale 或缺失；exit 2 索引缺失或条目排版不合预期）→ 差异即过期断言；
#      生成器不可用时退化为内建最小比对（id/status/updated_at 三元组）并输出 NOTE 说明。
#      （2026-09-18 票 37 修订：原"docs/issues/README.md 表行逐票对照票面状态"实现退役
#      ——README 状态列已定位为人工登记投影（票 35 起），与索引冲突时以索引为准。）

progress_rel='docs/progress.md'
readme_rel='README.md'
pkg_readme_rel='agent-up/README.md'
issues_readme_rel='docs/issues/README.md'

# ---- S1 Git 状态句 ---------------------------------------------------------

check_s1() {
  _pf="$repo_root/$progress_rel"
  _anchor=$(first_grep_line 'Git 恢复基线' "$_pf")
  if [ -z "$_anchor" ]; then
    emit_stale "$progress_rel" '登记的权威位置失效：找不到「Git 恢复基线」块，登记表条目须重新核对'
    return 0
  fi
  _loc="$progress_rel:$(printf '%s' "$_anchor" | sed 's/:.*//')"

  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn "$_loc" '目标当前不是 Git 工作区，Git 状态句条目按流程退化语义跳过（对齐 development-process 例外条款）'
    return 0
  fi

  # 1a 基线块宣称的首个提交存在
  _sha=$(printf '%s' "$_anchor" | sed -n 's/.*首个提交 `\([0-9a-f][0-9a-f]*\)`.*/\1/p')
  if [ -n "$_sha" ]; then
    if ! git -C "$repo_root" cat-file -e "$_sha" >/dev/null 2>&1; then
      emit_stale "$_loc" "基线块宣称首个提交 $_sha 存在，但对象库中找不到该提交"
    fi
  else
    emit_warn "$_loc" '基线块内未提取到首个提交短 SHA，提交存在性未核验'
  fi

  # 1b 基线块宣称的本地导出分支存在
  if ! git -C "$repo_root" show-ref --verify --quiet refs/heads/public-export; then
    emit_stale "$_loc" '基线块宣称本地导出分支 public-export 存在，但该分支引用不存在'
  fi

  # 1c 基线块宣称的唯一 remote 与地址
  _remotes=$(git -C "$repo_root" remote || true)
  _claim_url=$(printf '%s' "$_anchor" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ "$_remotes" != "origin" ]; then
    emit_stale "$_loc" "基线块宣称唯一 remote 为 origin，实际 remote 列表为：${_remotes:-（空）}"
  else
    _actual=$(git -C "$repo_root" config --get remote.origin.url || true)
    if [ -z "$_actual" ]; then
      emit_stale "$_loc" '基线块宣称 remote origin 已配置，但未取到其地址'
    elif [ -n "$_claim_url" ] && [ "$(trim_git_url "$_actual")" != "$_claim_url" ]; then
      emit_stale "$_loc" "基线块宣称 remote 地址 ${_claim_url}，实际为 $(trim_git_url "$_actual")"
    fi
  fi

  # 1d 基线块宣称本地 main 未推送到远端（本地只读判定：main 未被任何远端跟踪分支包含）
  if git -C "$repo_root" show-ref --verify --quiet refs/heads/main; then
    _contained=$(git -C "$repo_root" branch -r --contains main 2>/dev/null || true)
    if [ -n "$_contained" ]; then
      emit_stale "$_loc" '基线块宣称本地 main 未推送，但该提交已包含于远端跟踪分支'
    fi
  else
    emit_warn "$_loc" '本地 main 分支不存在，未推送断言未核验'
  fi

  # 1e（已移除，票 37）：基线块"存在未提交工作区改动"为票 13 时点历史快照，
  # progress.md 现为冻结历史档案（零写入），清洁工作区属稳态——逐字核对恒触发误报
  # （S1-1e 已知缺口，1080560 补记在案），不再作为活断言核对。
}

# ---- S2 发布状态句 ---------------------------------------------------------

check_s2() {
  _rf="$repo_root/$readme_rel"
  _kf="$repo_root/$pkg_readme_rel"
  _rline=$(first_grep_line '公开包已发布' "$_rf")
  if [ -z "$_rline" ]; then
    emit_stale "$readme_rel" '登记的权威位置失效：找不到「公开包已发布」宣称行，登记表条目须重新核对'
    return 0
  fi
  _rloc="$readme_rel:$(printf '%s' "$_rline" | sed 's/:.*//')"
  _claim=$(printf '%s' "$_rline" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ -z "$_claim" ]; then
    emit_stale "$_rloc" '发布宣称行内未提取到仓库地址，断言锚点失效'
    return 0
  fi

  _actual=$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null || true)
  if [ -z "$_actual" ]; then
    emit_stale "$_rloc" "发布句宣称已发布至 ${_claim}，但本仓库未配置 remote origin"
  elif [ "$(trim_git_url "$_actual")" != "$_claim" ]; then
    emit_stale "$_rloc" "发布句宣称地址 $_claim 与实际 remote origin $(trim_git_url "$_actual") 不一致"
  fi

  # 安装命令行与发布宣称同源核对（包内 README 的克隆地址与宣称一致）
  if [ -f "$_kf" ]; then
    _kline=$(first_grep_line "$_claim" "$_kf")
    if [ -z "$_kline" ]; then
      emit_stale "$pkg_readme_rel" "包内安装说明未找到与发布句一致的地址 $_claim"
    fi
  else
    emit_stale "$pkg_readme_rel" '登记的次级权威位置文件不存在'
  fi

  # 远端可达性与可见性本地不可核验（不出网）→ 存在时长提醒
  emit_warn "$_rloc" "远端仓库可达性与 public 可见性本地不核验（零网络依赖），请按登记周期人工复核宣称：$_claim"
}

# ---- S3 frontier 句（投影 vs 索引，票 37 改造） -----------------------------

s3_index_rows() {
  # $1=索引文件；输出每条目一行 "id|status|updated_at"（一条目一行排版，行内提取）。
  awk '
    function jval(line, key,    i, rest, j) {
      i = index(line, "\"" key "\": \"")
      if (i == 0) return ""
      rest = substr(line, i + length(key) + 5)
      j = index(rest, "\"")
      if (j == 0) return ""
      return substr(rest, 1, j - 1)
    }
    index($0, "\"id\": \"") > 0 {
      id = jval($0, "id"); st = jval($0, "status"); ua = jval($0, "updated_at")
      if (id == "" || st == "" || ua == "") { bad = 1; next }
      print id "|" st "|" ua
    }
    END { exit bad ? 1 : 0 }
  ' "$1"
}

s3_projection_rows() {
  # $1=投影文件；输出状态表每行 "id|status|updated_at"（跳过表头与分隔行）。
  awk '
    /^\| / {
      if ($0 ~ /^\| id \|/ || $0 ~ /^\| --- /) next
      n = split($0, c, "|")
      if (n < 5) next
      gsub(/^ +| +$/, "", c[2]); gsub(/^ +| +$/, "", c[3]); gsub(/^ +| +$/, "", c[5])
      if (c[2] == "" || c[3] == "" || c[5] == "") { bad = 1; next }
      print c[2] "|" c[3] "|" c[5]
    }
    END { exit bad ? 1 : 0 }
  ' "$1"
}

check_s3() {
  _idx="$repo_root/docs/issues/index.json"
  _proj="$repo_root/docs/progress-current.md"
  _gen=''
  if [ -f "$script_dir/generate-progress.sh" ] && [ -r "$script_dir/generate-progress.sh" ]; then
    _gen="$script_dir/generate-progress.sh"
  elif [ -f "$repo_root/scripts/generate-progress.sh" ] && [ -r "$repo_root/scripts/generate-progress.sh" ]; then
    _gen="$repo_root/scripts/generate-progress.sh"
  fi

  if [ -n "$_gen" ]; then
    # 优先路径：调用生成器 --check（生成器独占写口径下的一致性权威判定）。
    _grc=0
    sh "$_gen" --check "$repo_root" >/dev/null 2>&1 || _grc=$?
    case $_grc in
      0) : ;;
      1) emit_stale "docs/progress-current.md" '投影与索引不一致或投影缺失（generate-progress --check exit 1）——运行生成器刷新投影（docs/progress-current.md 为 Derived，生成器独占写）' ;;
      2) emit_stale "docs/issues/index.json" '索引缺失、不可读或条目行不合预期（generate-progress --check exit 2）——真相源排版须修复或登记条目重新核对' ;;
      *) emit_stale "docs/progress-current.md" "投影一致性核对异常（generate-progress --check exit $_grc）——人工核对生成器输出" ;;
    esac
    return 0
  fi

  # 退化路径：生成器不可用 → 内建最小比对（id/status/updated_at 三元组）并输出说明。
  printf 'NOTE: docs/issues/index.json — 生成器 generate-progress.sh 不可用（脚本同目录与仓库 scripts/ 均未找到），S3 退化为内建最小比对（id/status/updated_at 三元组；checkpoint_ref 等列不参与）\n'
  if [ ! -f "$_idx" ]; then
    emit_stale "docs/issues/index.json" '登记的权威位置失效：索引文件不存在（票状态真相源缺失）'
    return 0
  fi
  if [ ! -f "$_proj" ]; then
    emit_stale "docs/progress-current.md" '现役状态投影缺失——运行生成器落盘（generate-progress.sh，Derived 生成器独占写）'
    return 0
  fi
  _a=$(s3_index_rows "$_idx") || {
    emit_stale "docs/issues/index.json" '索引条目行缺必备字段（id/status/updated_at）或不合一条目一行排版——真相源排版须修复或登记条目重新核对'
    return 0
  }
  _b=$(s3_projection_rows "$_proj") || {
    emit_stale "docs/progress-current.md" '投影状态表行缺字段或不含任何状态表行——投影损坏，运行生成器重建'
    return 0
  }
  if [ "$(printf '%s\n' "$_a" | LC_ALL=C sort)" != "$(printf '%s\n' "$_b" | LC_ALL=C sort)" ]; then
    emit_stale "docs/progress-current.md" '投影与索引不一致（最小比对 id/status/updated_at 三元组存在差异）——运行生成器刷新投影；与 docs/issues/index.json 冲突时以索引为准'
  fi
}

# ---- 执行 ------------------------------------------------------------------

check_s1
check_s2
check_s3

_pn=$(prog_name)
if [ "$mode" = "session" ]; then
  printf '%s: 会话启动模式（不拦截）：过期断言 %s 处，提醒 %s 条，请人工核对上方输出\n' "$_pn" "$stale_count" "$warn_count"
  exit 0
fi
if [ "$stale_count" -gt 0 ]; then
  printf '%s: FAIL（%s 处过期断言，登记表共 3 条）\n' "$_pn" "$stale_count"
  exit 1
fi
printf '%s: PASS（登记表 3 条全部核对，提醒 %s 条）\n' "$_pn" "$warn_count"
exit 0
