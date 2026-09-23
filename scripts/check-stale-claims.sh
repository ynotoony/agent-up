#!/bin/sh
# Input: 仓库根目录（默认自本脚本位置向上两级推导，第一参数可指定）、本文件登记表内
#        的易腐状态句条目，与模式开关（第二参数或 STALE_CLAIMS_MODE 环境变量）；
#        仓根 delivery.rules（票 72 配置点亮：dp_stale_lit 点亮位、payload 节 remote 名
#        /包前缀/本地导出分支——S1/S2 配置面唯一承载点，解析破坏 exit 2 fail-closed；
#        宣称锚点句「公开包已发布」属协议面留引擎，照设计 §2 分界判据）。
# Output: 登记条目逐项核对结果——STALE 行（过期断言，含 路径:行号:内容 定位）、
#         WARN 行（提醒，含登记日期与【待定】阈值标注）、NOTE 行（比对机制退化说明，
#         不计入失败）、STALE-prone 行（S4 计数模式易腐命中，指名 file:line，
#         计入过期断言计数）、结尾汇总行；票收口模式（gate）发现过期断言 exit 1，
#         会话启动模式（session）仅输出警告 exit 0。
# Pos: 登记表驱动的易腐断言扫描器（REQ-20260904-010 / 票 19）；S4 计数漂移哨兵
#      （票 65）；POSIX sh、零外部依赖、全程只读（除打印外无写操作，Git 仅使用
#      只读子命令）。

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
  2  用法或环境错误（参数过多、模式非法、仓库根不存在等）；delivery.rules 解析破坏亦
     exit 2（票 72 配置点亮，fail-closed 不产生部分结论）。
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

# ---- delivery.rules 加载（票 72 配置点亮；fail-closed 六规则照设计 §2，解析破坏
#      exit 2 不产生部分结论；文件缺失＝全默认：S1/S2 未点亮、remote 名/包前缀不可知）----

# ---- delivery.rules 解析引擎段（fail-closed 六规则，设计 §2；与 export-payload.sh
#      同款，错误前缀参数化）----
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

dp_load_rules "$repo_root" 'check-stale-claims' || exit 2
s1_lit=0
s2_lit=0
case $DP_STALE_LIT in *"S1"*) s1_lit=1 ;; esac
case $DP_STALE_LIT in *"S2"*) s2_lit=1 ;; esac

# ---------------------------------------------------------------------------
# 登记表（首批三条，结构：断言模式 | 权威位置 | 校验方式）
#
# S1 Git 状态句 | docs/archive/progress.md 的「Git 恢复基线」块（2026-09-23 票 87
#    | 迁址自 docs/progress.md）
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
# S4 计数漂移句 | docs/issues/README.md 目录清单锚点行 + docs/issues/index.json 任务条目
#               | docs/ 树 md + docs/agent/artifacts.yaml 现行面计数措辞
#    | machine：两断言（票 65）——①数量相等：README「任务票 NN；」锚点行数与 index
#      「"id": "NN-…"」条目行数机械相等，不等 STALE 指名两侧计数（ticket-ops 双写
#      锁定面漂移）；README/索引缺失或锚点零命中 WARN 跳过不硬猜。②计数模式扫描：
#      「N～M 共」「共 N 量词」命中 STALE-prone 指名 file:line、计入过期断言计数
#      （gate exit 1 / session 只警告）；排除面与豁免表见 S4 数据节（票 65 阻塞→
#      协调层 2026-09-21 裁决 O3：历史真陈述/机器生成面收窄出扫描面，现行面全数字
#      免费、豁免表空表交付）。

progress_rel='docs/archive/progress.md'
readme_rel='README.md'
# S2 次级权威位置＝包内 README（票 72 配置点亮：自 delivery.rules dp_payload_root 派生，
# 引擎零包前缀硬编码；未声明 payload 节时为空，S2 安装行子项按退化语义 WARN 跳过）
pkg_readme_rel=''
[ -n "$DP_ROOT" ] && pkg_readme_rel="$DP_ROOT/README.md"
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

  # 1b 基线块宣称的本地导出分支存在（分支名自 delivery.rules dp_payload_local_ref 读取，
  # 票 72 配置点亮；未声明 payload 节＝分支名不可知，退化 WARN 跳过不硬猜）
  if [ -n "$DP_LOCAL_REF" ]; then
    if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$DP_LOCAL_REF"; then
      emit_stale "$_loc" "基线块宣称本地导出分支 $DP_LOCAL_REF 存在，但该分支引用不存在"
    fi
  else
    emit_warn "$_loc" 'S1-1b 本地导出分支核对跳过：delivery.rules 未声明 payload 节（分支名不可知）'
  fi

  # 1c 基线块宣称的唯一 remote 与地址（remote 名自 delivery.rules dp_payload_remote 读取，
  # 票 72 配置点亮；未声明 payload 节＝remote 名不可知，退化 WARN 跳过不硬猜）
  _remotes=$(git -C "$repo_root" remote || true)
  _claim_url=$(printf '%s' "$_anchor" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ -z "$DP_REMOTE" ]; then
    emit_warn "$_loc" 'S1-1c 唯一 remote 核对跳过：delivery.rules 未声明 payload 节（remote 名不可知）'
  elif [ "$_remotes" != "$DP_REMOTE" ]; then
    emit_stale "$_loc" "基线块宣称唯一 remote 为 ${DP_REMOTE}，实际 remote 列表为：${_remotes:-（空）}"
  else
    _actual=$(git -C "$repo_root" config --get "remote.$DP_REMOTE.url" || true)
    if [ -z "$_actual" ]; then
      emit_stale "$_loc" "基线块宣称 remote $DP_REMOTE 已配置，但未取到其地址"
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

  # 发布远端名自 delivery.rules dp_payload_remote 读取（票 72 配置点亮；
  # 未声明 payload 节＝remote 名不可知，退化 WARN 跳过不硬猜）
  if [ -z "$DP_REMOTE" ]; then
    emit_warn "$_rloc" 'S2 remote 比对跳过：delivery.rules 未声明 payload 节（发布远端名不可知）'
  else
    _actual=$(git -C "$repo_root" config --get "remote.$DP_REMOTE.url" 2>/dev/null || true)
    if [ -z "$_actual" ]; then
      emit_stale "$_rloc" "发布句宣称已发布至 ${_claim}，但本仓库未配置 remote ${DP_REMOTE}"
    elif [ "$(trim_git_url "$_actual")" != "$_claim" ]; then
      emit_stale "$_rloc" "发布句宣称地址 $_claim 与实际 remote ${DP_REMOTE} $(trim_git_url "$_actual") 不一致"
    fi
  fi

  # 安装命令行与发布宣称同源核对（包内 README 的克隆地址与宣称一致；包前缀自
  # delivery.rules dp_payload_root 派生，未声明＝位置不可知，退化 WARN 跳过）
  if [ -z "$pkg_readme_rel" ]; then
    emit_warn "$_rloc" 'S2 安装行同源核对跳过：delivery.rules 未声明 payload 节（包内 README 位置不可知）'
  elif [ -f "$_kf" ]; then
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

# ---- S4 计数漂移哨兵（票 65）------------------------------------------------
#
# S4-① 数量相等：docs/issues/README.md 目录清单锚点行「任务票 <NN>；」（ticket-ops
#      写入锚）行数与 docs/issues/index.json 任务条目行（"id": "<NN>-…" 形态）行数
#      机械相等；不等即 STALE 指名两侧计数（ticket-ops 双写锁定面漂移，手工删行/
#      加行即报）。README 或索引缺失、锚点零命中 → WARN 跳过不硬猜（对齐 S1 非 Git
#      退化语义）。比对对象是「README 里的票行」与「index 里的条目」，两文件自身
#      不入计数。
#
# S4-② 计数模式扫描（推数字免费化，票 61 先例）：扫描面＝docs/ 树 *.md ＋
#      docs/agent/artifacts.yaml，命中下述任一模式即 STALE-prone 指名 file:line，
#      计入过期断言计数（gate exit 1 / session 只警告）。模式为 ERE、全程 LC_ALL=C
#      字节语义；量词用交替字面量而非括号表达式（C locale 下多字节括号表达式按单
#      字节匹配，不可靠）：
#        模式甲：[0-9]+～[0-9]+ 共
#        模式乙：共 [0-9]+ (张|条|项|件|个)
#      排除面（数据注记，每条一句理由——历史真陈述/机器生成面非现行声明，不属
#      「会腐烂的现行计数」；2026-09-21 协调层裁决 O3 收窄）：
#        docs/issues/*.md              票面历史文件——历史票文不改写原则
#        docs/agent/runs/              run record 投影——运行记录面
#        docs/progress-current.md      现役状态投影——Derived 生成器独占写
#        docs/archive/progress.md      冻结历史档案——指针注记后零写入（票 87 迁址）
#        docs/archive/changes.md       只追加账本冻结件——历史条目不可改写（票 87 迁址）
#        docs/architecture/generated/  机器生成投影面——与 runs/ 同性质（票 59 口径）
#      已知限制：文件清单经 find 逐名循环，路径含空白或冒号的病态形态不受理。
#      裁量留痕（票 65）：现行文本预扫 15 命中＞3 停止线 → 阻塞报告 → 协调层裁决
#      O3：排除面如上收窄 ＋ artifacts.yaml 两聚合注记免费化改写（除计数片段外
#      整行逐字保留，改写后 check-artifacts 复跑 exit 0）。
s4_pat='[0-9]+～[0-9]+ 共|共 [0-9]+ (张|条|项|件|个)'

s4_load_exempts() {
  # 豁免表唯一承载点：每条一行「s4_exempt <仓库根相对路径> <行号> <理由（非空）>」，
  # 理由必填、显式登记，无静默豁免；命中行增删致行号漂移时须复核更新或删除登记
  # （对齐 package-manifest.rules vague-exemptions 维护口径）。空表交付（票 65
  # 裁决）＝现行面全数字免费，本表为未来正当例外预留。
  cat <<'S4_EXEMPT_DATA'
S4_EXEMPT_DATA
}

s4_parse_exempts() {
  # 解析豁免表为「路径:行号」键集（恰整行匹配）；结构破坏（无法识别行、行号非正
  # 整数、理由空）即 exit 2，不产生部分结论。解析结果落全局 S4_EXEMPT_KEYS。
  S4_EXEMPT_KEYS=''
  _keys=''
  while IFS= read -r _line; do
    case $_line in
      '' | '#'*) continue ;;
      s4_exempt\ *)
        set -- $_line
        if [ $# -lt 3 ]; then
          printf 'check-stale-claims: 错误：S4 豁免表行字段不足（须 路径 行号 理由）：%s\n' "$_line" >&2
          return 2
        fi
        _p=$2
        _n=$3
        shift 3
        _r="$*"
        case $_p in
          '' | /*)
            printf 'check-stale-claims: 错误：S4 豁免表路径须为非空仓库根相对路径：%s\n' "$_line" >&2
            return 2
            ;;
        esac
        case $_n in
          '' | *[!0-9]*)
            printf 'check-stale-claims: 错误：S4 豁免表行号须为正整数：%s\n' "$_line" >&2
            return 2
            ;;
        esac
        if [ "$_n" -eq 0 ]; then
          printf 'check-stale-claims: 错误：S4 豁免表行号须为正整数：%s\n' "$_line" >&2
          return 2
        fi
        if [ -z "$_r" ]; then
          printf 'check-stale-claims: 错误：S4 豁免表理由必填（无静默豁免）：%s\n' "$_line" >&2
          return 2
        fi
        _keys="$_keys$_p:$_n
"
        ;;
      *)
        printf 'check-stale-claims: 错误：S4 豁免表含无法识别的行：%s\n' "$_line" >&2
        return 2
        ;;
    esac
  done <<S4_EXEMPT_INNER
$(s4_load_exempts)
S4_EXEMPT_INNER
  S4_EXEMPT_KEYS=$_keys
}

check_s4_count() {
  # S4-① 数量相等：README 锚点行数 ↔ index 任务条目行数；缺失/锚点零命中 WARN 跳过。
  _rf="$repo_root/$issues_readme_rel"
  _idx="$repo_root/docs/issues/index.json"
  if [ ! -f "$_rf" ] || [ ! -f "$_idx" ]; then
    emit_warn "$issues_readme_rel" 'S4 数量相等断言跳过：docs/issues/README.md 或 docs/issues/index.json 缺失，按退化语义不硬猜'
    return 0
  fi
  _rn=$(LC_ALL=C grep -c '任务票 [0-9][0-9]*；' "$_rf") || _rn=0
  _in=$(LC_ALL=C grep -c '"id": "[0-9][0-9]*-' "$_idx") || _in=0
  if [ "$_rn" -eq 0 ]; then
    emit_warn "$issues_readme_rel" 'S4 锚点零命中：README 中无「任务票 NN；」锚点行（ticket-ops 写入锚失效），数量相等断言跳过不硬猜'
    return 0
  fi
  if [ "$_rn" -ne "$_in" ]; then
    emit_stale "$issues_readme_rel" "S4 数量相等断言失效：README「任务票 NN；」锚点行 $_rn 行 vs docs/issues/index.json 任务条目 $_in 条——ticket-ops 双写锁定面漂移，核对缺失侧"
  fi
  return 0
}

check_s4_scan() {
  # S4-② 计数模式扫描：artifacts.yaml 单件＋docs/ 树 md（排除面见数据节注记），
  # 命中经豁免表恰整行比对后报 STALE-prone（计入过期断言计数）。
  [ -d "$repo_root/docs" ] || return 0
  _s4_total=0
  _scan_file() {
    _sf=$1
    _sl=$(LC_ALL=C grep -nE "$s4_pat" "$_sf" 2>/dev/null | sed 's/:.*//') || _sl=''
    [ -n "$_sl" ] || return 0
    case $_sf in
      "$repo_root"/*) _srel=${_sf#"$repo_root"/} ;;
      *) _srel=$_sf ;;
    esac
    for _sn in $_sl; do
      if [ -n "$S4_EXEMPT_KEYS" ] && printf '%s\n' "$S4_EXEMPT_KEYS" | grep -qxF "$_srel:$_sn"; then
        continue
      fi
      _s4_total=$((_s4_total + 1))
      printf 'STALE-prone: %s:%s — 计数模式命中（S4-②）：数字会腐烂、计数无关措辞不会（票 61 先例），改写为计数无关措辞或按登记表注记理由豁免\n' "$_srel" "$_sn"
    done
    return 0
  }
  if [ -f "$repo_root/docs/agent/artifacts.yaml" ]; then
    _scan_file "$repo_root/docs/agent/artifacts.yaml"
  fi
  _s4_files=$(find "$repo_root/docs" \
    \( -path "$repo_root/docs/issues" -o -path "$repo_root/docs/agent/runs" -o -path "$repo_root/docs/architecture/generated" \) -prune -o \
    -type f -name '*.md' -print 2>/dev/null)
  for _s4f in $_s4_files; do
    case $_s4f in
      "$repo_root/docs/archive/progress.md" | "$repo_root/docs/archive/changes.md" | "$repo_root/docs/progress-current.md") continue ;;
    esac
    [ -f "$_s4f" ] || continue
    _scan_file "$_s4f"
  done
  stale_count=$((stale_count + _s4_total))
  return 0
}

check_s4() {
  check_s4_count
  check_s4_scan
}

# ---- 执行 ------------------------------------------------------------------
# S1/S2 配置点亮（票 72）：未点亮（delivery.rules 缺失或 calibration 节无 dp_stale_lit
# 登记）→ 打印 SKIP 行，不计过期断言不拦票；点亮＝现行断言逻辑原样执行。
# S3/S4 为通用面（协议），无点亮位恒执行。

if [ "$s1_lit" -eq 1 ]; then
  check_s1
else
  printf 'SKIP: S1 — delivery.rules 未点亮（dp_stale_lit 缺登记）\n'
fi
if [ "$s2_lit" -eq 1 ]; then
  check_s2
else
  printf 'SKIP: S2 — delivery.rules 未点亮（dp_stale_lit 缺登记）\n'
fi
check_s3
s4_parse_exempts
check_s4

_pn=$(prog_name)
# 登记总数动态化（票 72 设计 §4③）：点亮数（S1/S2）＋通用条数（S3/S4 恒 2）；
# 全点亮语境渲染与既有「登记表共 4 条」逐字一致。
_total_entries=$((2 + s1_lit + s2_lit))
if [ "$mode" = "session" ]; then
  printf '%s: 会话启动模式（不拦截）：过期断言 %s 处，提醒 %s 条，请人工核对上方输出\n' "$_pn" "$stale_count" "$warn_count"
  exit 0
fi
if [ "$stale_count" -gt 0 ]; then
  printf '%s: FAIL（%s 处过期断言，登记表共 %s 条）\n' "$_pn" "$stale_count" "$_total_entries"
  exit 1
fi
printf '%s: PASS（登记表 %s 条全部核对，提醒 %s 条）\n' "$_pn" "$_total_entries" "$warn_count"
exit 0
