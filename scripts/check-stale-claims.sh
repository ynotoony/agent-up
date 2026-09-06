#!/bin/sh
# Input: 仓库根目录（默认自本脚本位置向上两级推导，第一参数可指定）、本文件登记表内
#        的易腐状态句条目，与模式开关（第二参数或 STALE_CLAIMS_MODE 环境变量）。
# Output: 登记条目逐项核对结果——STALE 行（过期断言，含 路径:行号:内容 定位）、
#         WARN 行（提醒，含登记日期与【待定】阈值标注）、结尾汇总行；
#         票收口模式（gate）发现过期断言 exit 1，会话启动模式（session）仅输出警告 exit 0。
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

frontmatter_field() {
  # $1=文件 $2=字段名；输出 frontmatter 内 "字段: 值" 的值部分（无则空）。
  _f=$1
  _key=$2
  awk -v key="$_key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && !closed {
      if ($0 == "---") { exit }
      if (index($0, key ":") == 1) {
        val = substr($0, length(key) + 2)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        print val
        exit
      }
    }
  ' "$_f"
}

nums_of() {
  # $1=形如 "16" 或 "16 + 23" 或 "[16-governance-generation-refresh, 23-schema-backfill]"
  # 或 "18/19/20/21" 的标注文本；输出其中的纯数字序列（单空格分隔、无首尾空白、
  # 升序去重）。分隔符逐个 tr 归空格（BSD tr 对多字符集合的解析有歧义，不用）；
  # BRE 的 + 是字面量，"一个及以上"的区间语义在此不可用。
  printf '%s\n' "$1" | tr '[' ' ' | tr ']' ' ' | tr ',' ' ' | tr '/' ' ' | tr '+' ' ' | tr -s ' \t' '\n' | sed -n 's/^\([0-9][0-9]*\).*/\1/p' | sort -n | uniq | tr '\n' ' ' | sed 's/^ *//;s/ *$//'
}

lists_equal() {
  # $1 $2=空格分隔的数字序列；集合相等返回 0，否则 1。
  # 显式用空格分词：调用点可能处于 IFS=换行 的表行循环内，不得依赖外部 IFS。
  _a=$1
  _b=$2
  _l_oldifs=$IFS
  IFS=' '
  _bad=0
  for _x in $_a; do
    case " $_b " in
      *" $_x "*) ;;
      *) _bad=1 ;;
    esac
  done
  for _x in $_b; do
    case " $_a " in
      *" $_x "*) ;;
      *) _bad=1 ;;
    esac
  done
  IFS=$_l_oldifs
  return "$_bad"
}

first_grep_line() {
  # $1=模式(BRE) $2=文件；输出首个命中行的 行号:内容，无命中输出空。
  grep -n "$1" "$2" 2>/dev/null | sed -n '1p'
}

trim_git_url() {
  # 归一化 Git 远端地址：去结尾 .git 与结尾空白。
  printf '%s' "$1" | sed 's/\.git$//;s/[[:space:]]*$//'
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

if [ $# -ge 1 ]; then
  repo_root=$1
else
  script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
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
#      唯一 remote 与宣称地址一致、本地 main 未被他者远端分支包含、工作区存在未提交
#      改动）；非 Git 工作区按流程退化语义输出提醒跳过。
# S2 发布状态句 | 根 README.md 宣称行 + agent-up/README.md 安装行
#    | machine：文档宣称的仓库地址与实际远端配置归一化比对；远端可达性/可见性本地
#      不核验（不出网）→ reminder。
# S3 frontier 句 | docs/issues/README.md 架构节 + 目录清单表行
#    | machine：表行（票文件、状态标注、by 链）逐票对照票面状态——状态取 frontmatter
#      status，无 frontmatter 的存量票退化取正文 `**Status:**` 行；表行宣称完成而票面
#      非完成 → 过期断言（虚假完成宣称）；票文件缺失或 blocked-by 链不一致 →
#      过期断言；表行标 blocked 而票面已流转（同步滞后）→ reminder（索引同步由
#      Triage 批量流转承担，滞后属流程常态）；票面无可机读状态 → reminder。

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

  # 1e 基线块宣称工作区存在未提交改动
  _dirty=$(git -C "$repo_root" status --porcelain 2>/dev/null || true)
  if [ -z "$_dirty" ]; then
    emit_stale "$_loc" '基线块宣称存在未提交工作区改动，当前工作区状态为清洁——基线块须收口更新'
  fi
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

# ---- S3 frontier 句 --------------------------------------------------------

check_s3() {
  _if="$repo_root/$issues_readme_rel"
  if [ ! -f "$_if" ]; then
    emit_stale "$issues_readme_rel" '登记的权威位置失效：文件不存在'
    return 0
  fi
  _arch=$(first_grep_line '^## 架构' "$_if")
  if [ -z "$_arch" ]; then
    emit_stale "$issues_readme_rel" '登记的权威位置失效：找不到架构节，frontier 断言锚点丢失'
    return 0
  fi

  _rows=$(grep -E '^\| `[0-9]+-[A-Za-z0-9-]*\.md` \| 任务票' "$_if" 2>/dev/null || true)
  if [ -z "$_rows" ]; then
    emit_stale "$issues_readme_rel" '目录清单中未找到任何任务票表行，frontier 断言无核对对象'
    return 0
  fi

  OLDIFS=$IFS
  IFS='
'
  for _row in $_rows; do
    # 逐字段独立提取：状态括注（完成时间等注记）与 by 链均可缺省，缺其一不判失败。
    _fname=$(printf '%s\n' "$_row" | sed -n 's/^| `\([^`]*\)\.md`.*/\1/p')
    _tno=$(printf '%s\n' "$_row" | sed -n 's/^| `[^`]*` | 任务票 \([0-9][0-9]*\).*/\1/p')
    _tstate=$(printf '%s\n' "$_row" | sed -n 's/^| `[^`]*` | 任务票 [0-9][0-9]*；`\([a-z_]*\)`.*/\1/p')
    _tby=$(printf '%s\n' "$_row" | sed -n 's/.*（by \([^）]*\)）.*/\1/p')
    [ -n "$_fname" ] && [ -n "$_tno" ] && [ -n "$_tstate" ] || continue
    _tf="$repo_root/docs/issues/${_fname}.md"
    _iloc="$issues_readme_rel:$(_row_lineno "$_row")"
    if [ ! -f "$_tf" ]; then
      emit_stale "$_iloc" "表行宣称任务票 $_tno 存在，但票文件 docs/issues/${_fname}.md 不存在"
      continue
    fi
    _fm_state=$(frontmatter_field "$_tf" 'status')
    if [ -z "$_fm_state" ]; then
      # 无 frontmatter 的存量票（01～04 未回填批次）：退化取票面正文 Status 行。
      _fm_state=$(sed -n 's/^\*\*Status:\*\* `\([a-z_]*\)`.*/\1/p' "$_tf" | sed -n '1p')
    fi
    _fm_by=$(frontmatter_field "$_tf" 'blocked_by')
    if [ -z "$_fm_state" ]; then
      emit_warn "$_iloc" "票 $_tno 票面无 frontmatter status 也无正文 Status 行，状态现势性未核验"
      continue
    fi

    # 断言级：表行宣称完成而票面并非完成（虚假完成宣称）
    if [ "$_tstate" = "done" ] && [ "$_fm_state" != "done" ]; then
      emit_stale "$_iloc" "表行宣称票 $_tno 状态 done，票面状态为 $_fm_state"
    fi

    if [ "$_tstate" = "blocked" ]; then
      if [ "$_fm_state" != "blocked" ]; then
        # 提醒级：表行标 blocked 而票面已流转（Triage 批量同步前的常态滞后）
        emit_warn "$_iloc" "表行标注 blocked，票 $_tno 票面状态已为 ${_fm_state}（索引同步滞后项，交 Triage 流转时更新）"
      elif [ -z "$_fm_by" ]; then
        # 提醒级：票面 blocked 但无机读 by 链，表行链条无法机核
        emit_warn "$_iloc" "票 $_tno 票面无 blocked_by 标注，表行 by 链（${_tby}）无法机核"
      elif ! lists_equal "$(nums_of "$_tby")" "$(nums_of "$_fm_by")"; then
        # 断言级：by 链与票面 blocked_by 不一致
        emit_stale "$_iloc" "表行宣称 blocked-by 链为 ${_tby}，票 $_tno 票面 blocked_by 为 ${_fm_by}，链不一致"
      fi
    fi
  done
  IFS=$OLDIFS
}

_row_lineno() {
  # $1=表行内容；在 issues/README.md 中定位该行行号（固定串整行匹配，取首个命中；
  # 不做转义与截断——按字节截断可能切碎多字节字符致匹配失效）。
  grep -Fn -- "$1" "$repo_root/$issues_readme_rel" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\):.*/\1/p' | sed -n '1p'
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
