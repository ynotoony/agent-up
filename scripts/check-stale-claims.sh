#!/bin/sh
# Input: 仓库根目录（缺省按脚本落位自推导——agent-up/scripts/ 上两级、
#        rules/implementation/scripts/ 上三级，尾径校验失败报错退出 2，第一参数可指定）、
#        同目录唯一 JSON 引擎 json-validator.py 与 python3（index.json 条目行、教训账本
#        指针与历史终态行一律经引擎解析，缺件/不可用 exit 2 fail-closed，不内嵌解析副本）、
#        本文件登记表内
#        的易腐状态句条目，与模式开关（第二参数或 STALE_CLAIMS_MODE 环境变量）；
#        仓根 delivery.rules（票 72 配置点亮：dp_stale_lit 点亮位、payload 节 remote 名
#        /包前缀/本地导出分支——S1/S2 配置面唯一承载点，解析破坏 exit 2 fail-closed；
#        宣称锚点句「公开包已发布」属协议面留引擎，照设计 §2 分界判据）；与 Git 历史
#        （S6 终态基线锚：facts/requirements/tickets/index.json 的现行提交历史，票 94——只读 log -p，
#        不读其他历史面）。
# Output: 登记条目逐项核对结果——STALE 行（过期断言，含 路径:行号:内容 定位）、
#         WARN 行（提醒，含该条目登记日期〔stale_entry_date 数据节按条目取〕与【待定】
#         阈值标注；缺失退化面一律 WARN 显式说明，不静默放行）、NOTE 行（比对机制退化说明，
#         不计入失败）、STALE-prone 行（S4 计数模式易腐命中，指名 file:line，
#         计入过期断言计数）、S6 非法跃迁行（STALE，指名票 id 与跃迁方向 done/superseded
#         → 非终态）、结尾汇总行；票收口模式（gate）发现过期断言 exit 1，
#         会话启动模式（session）仅输出警告 exit 0。
# Pos: 登记表驱动的易腐断言扫描器（REQ-20260904-010 / 票 19）；S4 计数漂移哨兵
#      （票 65）；S5 方案结论标注句（票 85，R-DP-033 加固配套格式断言）；S6 终态哨兵
#      （票 94，done/superseded 被改回非终态即 STALE/FAIL——复盘缺口④幽灵态机器报警）；
#      POSIX sh、零外部依赖（JSON 解析经同目录唯一引擎 json-validator.py json rows/
#      json fields，缺件或 python3 不可用 exit 2 fail-closed）、全程只读（除打印外无写
#      操作，Git 仅使用只读子命令）。
# dp-parser: 2
# stale-claims-version: 8（断言组 S1-S8；机制版本注记，dp-parser 先例）
#      （本件要求解析器最低版注记；解析唯一实现＝同目录 dp-load-rules.sh，版本唯一
#      来源＝其 DP_PARSER_VERSION。落地拷贝遇未知锚点/指令、解析器缺件或版本漂移即
#      报错指名——同步方式见 references/old-project.md §3 dp-load-rules.sh 引擎件行，
#      文法与版本详见 references/delivery-rules.md。四件同族脚本注记须一致。）

# 用法、登记表条目说明与输出格式见同目录 README.md。
# 状态陈述纪律见 development-process 模板 §15：状态以权威引用表达，本脚本
# 即"登记表条目 = 权威位置 + 核对方式"的执行器。

# ---- 路径常量区（票 111 波②收拢；票 113 波④按 rules-facts-layout-spec §2 R9/R13/R14/R15/R18/R19/R24/R25 翻值）----
progress_rel='facts/project/archive/progress.md'
progress_current_rel='facts/requirements/tickets/progress-current.md'
archive_changes_rel='facts/project/archive/changes.md'
issues_dir_rel='facts/requirements/tickets'
issues_readme_rel='facts/requirements/tickets/README.md'
issues_index_rel='facts/requirements/tickets/index.json'
changes_jsonl_rel='facts/project/changes.jsonl'
artifacts_yaml_rel='facts/project/artifacts.yaml'
agent_runs_dir_rel='facts/requirements/runs'
arch_generated_dir_rel='facts/project/architecture/generated'
repo_scripts_dir_rel='rules/implementation/scripts'
s5_scan_glob='facts/requirements/research/*.md'
facts_tree_rel='facts'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

TAB=$(printf '\t')  # 引擎 json rows/json fields 的 TAB 分列读取（S3/S6/S7/S8）

# Source common helper functions（票 227 F4/F5：仓库根推导统一经 resolve_repo_root --layout）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'check-stale-claims: 错误：共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
用法: sh check-stale-claims.sh [repo-root] [gate|session]
参数:
  repo-root  待核对的仓库根目录；缺省按脚本落位自推导（agent-up/scripts/ 上两级＝仓库根、
             rules/implementation/scripts/ 上三级＝仓库根，其余语境报错退出 2 须显式传参）。
  模式        gate  票收口模式（默认）：发现过期断言输出定位并 exit 1，清洁 exit 0。
              session 会话启动模式：同样输出 STALE/WARN 但只作警告，恒 exit 0。
  也可用环境变量 STALE_CLAIMS_MODE=session 指定会话启动模式（第二参数优先）。
  -h / --help 打印本用法。
退出码:
  0  gate 模式下无过期断言（提醒照常输出），或 session 模式。
  1  gate 模式下存在过期断言（STALE 行见输出）。
  2  用法或环境错误（参数过多、模式非法、仓库根不存在等）；delivery.rules 解析破坏、
     同目录唯一 JSON 引擎 json-validator.py 缺失或 python3 不可用亦 exit 2（运行时依赖
     只认安装闭包，fail-closed 不产生部分结论）。
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

# 条目登记日期数据节（WARN 行「提醒自 … 登记」按条目取，不再全局硬编码）：来源＝
# 各条目核对函数（check_sN）首次进入本文件的提交日期（git log -S 检索），条目新增/迁移
# 时随复核更新；S1/S2/S3 为同批首批登记，S4 起各自成条。
stale_entry_date() {
  case $1 in
    S1 | S2 | S3) printf '2026-09-06' ;;
    S4) printf '2026-09-22' ;;
    S5) printf '2026-09-24' ;;
    S6) printf '2026-09-28' ;;
    S7) printf '2026-10-09' ;;
    S8) printf '2026-10-10' ;;
    *) printf '' ;;
  esac
}

emit_warn() {
  # $1=条目（S1-S8，登记日期按条目取） $2=定位 $3=提醒内容；存在时长阈值未定稿，统一标注【待定】。
  _wdate=$(stale_entry_date "$1")
  printf 'WARN: %s — %s（提醒自 %s 登记，存在时长阈值【待定】）\n' "$2" "$3" "${_wdate:-未知}"
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
  CDPATH='' cd "$(dirname "$0")" && pwd
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
  # 缺省根推导（票 227 F4：统一经 resolve_repo_root --layout 严格两布局口径；
  # 非两落位形态 → fail-closed 报错退出 2，不静默错根：rules/ 下报假 STALE 教训）。
  _csc_rr=$(resolve_repo_root --layout) || _csc_rr=''
  if [ -z "$_csc_rr" ]; then
    printf 'check-stale-claims: 错误：无法从脚本落位推导仓库根（%s）——两落位形态为 agent-up/scripts/ 与 rules/implementation/scripts/，其余语境请显式传 repo-root 参数\n' "$script_dir" >&2
    exit 2
  fi
  repo_root=$_csc_rr
fi
if [ ! -d "$repo_root" ]; then
  printf 'check-stale-claims: 错误：仓库根目录不存在：%s\n' "$repo_root" >&2
  exit 2
fi

# ---- delivery.rules 加载（配置点亮；fail-closed 六规则照设计 §2，解析破坏
#      exit 2 不产生部分结论；文件缺失＝全默认：S1/S2 未点亮、remote 名/包前缀不可知）----
# 共享解析器加载（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh；缺件或版本漂移
# fail-closed exit 2 指名，不内嵌副本）
_dp_parser_file=$(dirname "$0")/dp-load-rules.sh
if [ -f "$_dp_parser_file" ]; then
  # shellcheck source=agent-up/scripts/dp-load-rules.sh  # 路径动态计算，显式声明基线位置
  . "$_dp_parser_file"
else
  printf 'check-stale-claims: 错误：共享解析器缺失: %s（dp_load_rules 唯一实现＝同目录 dp-load-rules.sh，与消费件同目录分发）\n' "$_dp_parser_file" >&2
  exit 2
fi
if [ "${DP_PARSER_VERSION:-0}" -lt 2 ]; then
  printf 'check-stale-claims: 错误：共享解析器版本漂移: %s 版本 %s 低于本件最低要求 2（请与包内同件同步）\n' "$_dp_parser_file" "${DP_PARSER_VERSION:-（未声明）}" >&2
  exit 2
fi

dp_load_rules "$repo_root" 'check-stale-claims' || exit 2

# 唯一 JSON 引擎（运行时依赖只认脚本同目录安装闭包）：index.json 条目行、历史终态行与
# 教训账本指针一律经同目录 json-validator.py 解析（json rows/json fields），不内嵌解析
# 副本、不回退包工作树副本；缺件或 python3 不可用即 exit 2 fail-closed 指名。
_engine=$(dirname "$0")/json-validator.py
if [ ! -f "$_engine" ]; then
  printf 'check-stale-claims: 错误：唯一 JSON 引擎缺失（安装闭包缺失）: %s——运行时依赖只认脚本同目录（与 common-helpers.sh／dp-load-rules.sh 同分发）；缺失即安装不到位，请按 Agent Up 包 references/upgrade.md 升级或 scripts/install.sh 修补后重跑（本次不产生结论）\n' "$_engine" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'check-stale-claims: 错误：python3 不可用——唯一 JSON 引擎无法执行（fail-closed，本次不产生结论）\n' >&2
  exit 2
fi

s1_lit=0
s2_lit=0
case $DP_STALE_LIT in *"S1"*) s1_lit=1 ;; esac
case $DP_STALE_LIT in *"S2"*) s2_lit=1 ;; esac

# ---------------------------------------------------------------------------
# 登记表（首批三条，结构：断言模式 | 权威位置 | 校验方式）
#
# S1 Git 状态句 | facts/project/archive/progress.md 的「Git 恢复基线」块（2026-09-23 票 87
#    | 迁址自 docs/progress.md，现 facts/project/archive/progress.md）
#    | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、
#      唯一 remote 与宣称地址一致、本地 main 未被他者远端分支包含）；非 Git 工作区按
#      流程退化语义输出提醒跳过。（2026-09-18 票 37 修订：移除"工作区存在未提交改动"
#      子项核对（原 1e）——该陈述为票 13 时点历史快照，docs/progress.md（现 facts/project/archive/progress.md）现为冻结历史
#      档案（零写入），清洁工作区属稳态，逐字核对构成恒触发误报（S1-1e 已知缺口，
#      1080560 补记在案）；基线块原文按"不改历史"保留，不因本修订改写。）
# S2 发布状态句 | 根 README.md 宣称行 + agent-up/README.md 安装行
#    | machine：文档宣称的仓库地址与实际远端配置归一化比对；远端可达性/可见性本地
#      不核验（不出网）→ reminder。
# S3 frontier 句 | facts/requirements/tickets/index.json（票状态真相源）+ facts/requirements/tickets/progress-current.md（现役状态投影）
#    | machine：投影 vs 索引比对——优先调用 generate-progress.sh --check（exit 0 一致；
#      exit 1 投影 stale 或缺失；exit 2 索引缺失或条目排版不合预期）→ 差异即过期断言；
#      生成器不可用时退化为内建最小比对（id/status/updated_at 三元组）并输出 NOTE 说明；
#      条目行经唯一 JSON 引擎 json rows 解析（票 284：键序无关、紧凑与带空格同受理，
#      不再用行内正则 jval）。
#      （2026-09-18 票 37 修订：原"docs/issues/README.md（现 facts/requirements/tickets/README.md）表行逐票对照票面状态"实现退役
#      ——README 票表为索引派生生成块（一致性由 S4 生成块新鲜度核对承载），与索引冲突时以索引为准。）
# S4 计数漂移句 | facts/requirements/tickets/README.md 票表生成块 + facts/requirements/tickets/index.json
#               | facts/ 树 md + facts/project/artifacts.yaml 现行面计数措辞
#    | machine：两断言（票 277 收敛）——①生成块新鲜度：README 票表已改为索引派生生成块，
#      原「锚点行数 vs 索引条目数」数量相等断言退役，改调 generate-progress.sh
#      --check-readme 只读核对派生一致（派生口径唯一实现＝生成器，本件零副本）；不一致
#      或未迁移即 STALE 指名生成器报因，README/索引缺失或生成器不可用 WARN 跳过不硬猜。
#      ②计数模式扫描：
#      「N～M 共」「共 N 量词」命中 STALE-prone 指名 file:line、计入过期断言计数
#      （gate exit 1 / session 只警告）；排除面与豁免表见 S4 数据节（票 65 阻塞→
#      协调层 2026-09-21 裁决 O3：历史真陈述/机器生成面收窄出扫描面，现行面全数字
#      免费、豁免表空表交付）。
# S5 方案结论标注句 | 扫描面 glob 清单登记的方案类文档（s5_load_globs 数据节，现行唯一
#               | 条目 facts/requirements/research/*.md；扩面须同步修订 R-DP-033 条文与本数据节，
#               | 禁静默扩面——票 78 词表教训）
#    | machine：R-DP-033 加固配套格式断言（票 85）——结论行（识别规则登记于 S5 数据
#      节：行首「结论：」形态）逐行核对证据出处（file:）与适用轨（轨:本仓自用／
#      agent-up，受控两值）；只查格式不判语义（出处是否真支撑结论归独立评审，合同
#      Forbidden）；向前生效：只查工作区新增/修改面（git status --porcelain 判定），
#      存量已提交文件不回溯（条文写死，票 85 风险注记：存量若回溯即红）；非 Git
#      工作区 WARN 退化跳过（对齐 S1）。
# S6 终态哨兵 | facts/requirements/tickets/index.json（票状态真相源，一条目一行）
#    | machine：终态哨兵（票 94，复盘缺口④幽灵态）——索引内 id 曾达终态（done/
#      superseded）而当前 status 回到非终态（ready/in_progress/blocked/review_ready/
#      review_pass/review_fail）即 STALE 指名票 id 与跃迁方向。基线锚＝该索引的 Git
#      现行提交历史（`git log -p` 提取历次 + 行、经唯一 JSON 引擎 json rows 解析
#      id/status——票 284；选型理由：零新增数据源
#      ——终态史已由仓库历史承载，夹具快照反而成为第二本可漂移的账；非 Git 工作区
#      WARN 跳过；索引尚无基线提交且当前行无可提取条目（无可比历史）WARN 跳过，对齐
#      S1/S5）。对账分层：一致性对账
#      （投影↔索引，S3）之外，终态语义由 S6 承载（development-process §5.1）。
# S7 替代标记存在性 | facts/requirements/tickets/index.json（票状态真相源，一条目一行）
#    | machine：superseded_by 替代标记存在性断言（R-DP-039 替代标记面配套）——索引条目
#      含非空 superseded_by 时，指向的票 id 必须真实存在于本索引（缺失即 STALE 指名
#      双方 id）；指向票自身带 superseded_by（替代链环）即 STALE；指向票状态非终态
#      （替代票尚未收口）即 WARN 提醒不拦截（收口顺序合法：先标后收）。字段缺失＝
#      零命中零报（可选字段语义，存量票零回扫）；不按时间自动打标。条目经唯一 JSON
#      引擎 json rows 解析（票 284：三份 awk jval 副本随解析收敛合一，键序无关）。
# S8 复盘沉淀指针 | facts/project/changes.jsonl（教训账本，kind=lesson 行）
#    | machine：沉淀指针核对（R-DP-041 检查面配套）——lesson 行 promoted_to ∈
#      {rules, validator, test} 且 decision/evidence_ref 含可 grep 文件指针（rules/ 或
#      scripts/ 路径，可带 #锚点后缀）时，核对指针文件仍存在且锚点在场：文件缺失或
#      锚点丢失＝STALE 指名行号与指针（沉淀被删或指针写错）；promoted_to ∈
#      {新票, none} 不在扫描面（新票由票务系统管、none 无沉淀义务）；指针不可 grep
#      形态＝NOTE 退化说明不计失败（锚点语义漂移归独立 Review，append-only 校正由
#      人落新行，S8 只报警不代写）。已知限制：同一行多指针只核首个命中（漏报面，
#      指针写法应一行动一处）；锚点 grep -F 定字面；紧凑 JSON（键后无空格）同受扫描。
#      NOTE 零命中行仅当账本内无任何可 grep 指针的 lesson 行时打一条（混合账本下
#      不可 grep 行零提示归本限制注记，不另打行）。账本文件缺失＝WARN 显式跳过（票 284
#      关闭 fail-open：不再静默返回 0，对齐 S3/S6/S7 缺失退化语义）。

readme_rel='README.md'
# S2 次级权威位置＝包内 README（票 72 配置点亮：自 delivery.rules dp_payload_root 派生，
# 引擎零包前缀硬编码；未声明 payload 节时为空，S2 安装行子项按退化语义 WARN 跳过）
pkg_readme_rel=''
[ -n "$DP_ROOT" ] && pkg_readme_rel="$DP_ROOT/README.md"

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
    emit_warn S1 "$_loc" '目标当前不是 Git 工作区，Git 状态句条目按流程退化语义跳过（对齐 development-process 例外条款）'
    return 0
  fi

  # 1a 基线块宣称的首个提交存在
  # shellcheck disable=SC2016  # sed/awk 程序刻意字面 $（引号形态由程序语义决定；wiki 长尾误报）
  _sha=$(printf '%s' "$_anchor" | sed -n 's/.*首个提交 `\([0-9a-f][0-9a-f]*\)`.*/\1/p')
  if [ -n "$_sha" ]; then
    if ! git -C "$repo_root" cat-file -e "$_sha" >/dev/null 2>&1; then
      emit_stale "$_loc" "基线块宣称首个提交 $_sha 存在，但对象库中找不到该提交"
    fi
  else
    emit_warn S1 "$_loc" '基线块内未提取到首个提交短 SHA，提交存在性未核验'
  fi

  # 1b 基线块宣称的本地导出分支存在（分支名自 delivery.rules dp_payload_local_ref 读取，
  # 票 72 配置点亮；未声明 payload 节＝分支名不可知，退化 WARN 跳过不硬猜）
  if [ -n "$DP_LOCAL_REF" ]; then
    if ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$DP_LOCAL_REF"; then
      emit_stale "$_loc" "基线块宣称本地导出分支 $DP_LOCAL_REF 存在，但该分支引用不存在"
    fi
  else
    emit_warn S1 "$_loc" 'S1-1b 本地导出分支核对跳过：delivery.rules 未声明 payload 节（分支名不可知）'
  fi

  # 1c 基线块宣称的唯一 remote 与地址（remote 名自 delivery.rules dp_payload_remote 读取，
  # 票 72 配置点亮；未声明 payload 节＝remote 名不可知，退化 WARN 跳过不硬猜）
  _remotes=$(git -C "$repo_root" remote || true)
  _claim_url=$(printf '%s' "$_anchor" | sed -n 's/.*\(https:\/\/github\.com\/[A-Za-z0-9._/-]*\).*/\1/p' | sed 's/\.git$//')
  if [ -z "$DP_REMOTE" ]; then
    emit_warn S1 "$_loc" 'S1-1c 唯一 remote 核对跳过：delivery.rules 未声明 payload 节（remote 名不可知）'
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
    emit_warn S1 "$_loc" '本地 main 分支不存在，未推送断言未核验'
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
    emit_warn S2 "$_rloc" 'S2 remote 比对跳过：delivery.rules 未声明 payload 节（发布远端名不可知）'
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
    emit_warn S2 "$_rloc" 'S2 安装行同源核对跳过：delivery.rules 未声明 payload 节（包内 README 位置不可知）'
  elif [ -f "$_kf" ]; then
    _kline=$(first_grep_line "$_claim" "$_kf")
    if [ -z "$_kline" ]; then
      emit_stale "$pkg_readme_rel" "包内安装说明未找到与发布句一致的地址 $_claim"
    fi
  else
    emit_stale "$pkg_readme_rel" '登记的次级权威位置文件不存在'
  fi

  # 远端可达性与可见性本地不可核验（不出网）→ 存在时长提醒
  emit_warn S2 "$_rloc" "远端仓库可达性与 public 可见性本地不核验（零网络依赖），请按登记周期人工复核宣称：$_claim"
}

# ---- S3 frontier 句（投影 vs 索引，票 37 改造） -----------------------------

s3_index_rows() {
  # $1=索引文件；经唯一 JSON 引擎 json rows 逐条目输出 "id|status|updated_at"
  # （键序无关、紧凑与带空格同受理；缺必备字段即返回 1 由调用方报排版破坏）。
  _s3_rows=$(python3 "$_engine" json rows "$1" issues id status updated_at 2>/dev/null) || return 1
  [ -n "$_s3_rows" ] || return 0
  printf '%s\n' "$_s3_rows" | awk -F'\t' '
    { if ($1 == "" || $2 == "" || $3 == "") { bad = 1; next } print $1 "|" $2 "|" $3 }
    END { exit bad ? 1 : 0 }
  '
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
  _idx="$repo_root/$issues_index_rel"
  _proj="$repo_root/$progress_current_rel"
  _gen=''
  if [ -f "$script_dir/generate-progress.sh" ] && [ -r "$script_dir/generate-progress.sh" ]; then
    _gen="$script_dir/generate-progress.sh"
  elif [ -f "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ] && [ -r "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ]; then
    _gen="$repo_root/$repo_scripts_dir_rel/generate-progress.sh"
  fi

  if [ -n "$_gen" ]; then
    # 优先路径：调用生成器 --check（生成器独占写口径下的一致性权威判定）。
    _grc=0
    sh "$_gen" --check "$repo_root" >/dev/null 2>&1 || _grc=$?
    case $_grc in
      0) : ;;
      1) emit_stale "$progress_current_rel" "投影与索引不一致或投影缺失（generate-progress --check exit 1）——运行生成器刷新投影（$progress_current_rel 为 Derived，生成器独占写）" ;;
      2) emit_stale "$issues_index_rel" '索引缺失、不可读或条目行不合预期（generate-progress --check exit 2）——真相源排版须修复或登记条目重新核对' ;;
      *) emit_stale "$progress_current_rel" "投影一致性核对异常（generate-progress --check exit ${_grc}）——人工核对生成器输出" ;;
    esac
    return 0
  fi

  # 退化路径：生成器不可用 → 内建最小比对（id/status/updated_at 三元组）并输出说明。
  printf 'NOTE: %s — 生成器 generate-progress.sh 不可用（脚本同目录与仓库 %s/ 均未找到），S3 退化为内建最小比对（id/status/updated_at 三元组；checkpoint_ref 等列不参与）\n' "$issues_index_rel" "$repo_scripts_dir_rel"
  if [ ! -f "$_idx" ]; then
    emit_stale "$issues_index_rel" '登记的权威位置失效：索引文件不存在（票状态真相源缺失）'
    return 0
  fi
  if [ ! -f "$_proj" ]; then
    emit_stale "$progress_current_rel" '现役状态投影缺失——运行生成器落盘（generate-progress.sh，Derived 生成器独占写）'
    return 0
  fi
  _a=$(s3_index_rows "$_idx") || {
    emit_stale "$issues_index_rel" '索引条目行缺必备字段（id/status/updated_at）或不合一条目一行排版——真相源排版须修复或登记条目重新核对'
    return 0
  }
  _b=$(s3_projection_rows "$_proj") || {
    emit_stale "$progress_current_rel" '投影状态表行缺字段或不含任何状态表行——投影损坏，运行生成器重建'
    return 0
  }
  if [ "$(printf '%s\n' "$_a" | LC_ALL=C sort)" != "$(printf '%s\n' "$_b" | LC_ALL=C sort)" ]; then
    emit_stale "$progress_current_rel" "投影与索引不一致（最小比对 id/status/updated_at 三元组存在差异）——运行生成器刷新投影；与 $issues_index_rel 冲突时以索引为准"
  fi
}

# ---- S4 计数漂移哨兵（票 65）------------------------------------------------
#
# S4-① 生成块新鲜度：facts/requirements/tickets/README.md 票表为索引派生生成块，调同目录
#      generate-progress.sh --check-readme 只读核对现行块是否等于索引派生结果（派生口径唯一
#      实现＝生成器，本件零副本、不按实现猜）；漂移或块缺失但目录清单表在场（未迁移）即
#      STALE 指名生成器报因。README 或索引缺失、生成器不可用 → WARN 跳过不硬猜（对齐 S1
#      非 Git 退化语义）。原「锚点行数 ↔ 索引条目数」数量相等断言随票表生成化退役。
#
# S4-② 计数模式扫描（推数字免费化，票 61 先例）：扫描面＝facts/ 树 *.md ＋
#      facts/project/artifacts.yaml，命中下述任一模式即 STALE-prone 指名 file:line，
#      计入过期断言计数（gate exit 1 / session 只警告）。模式为 ERE、全程 LC_ALL=C
#      字节语义；量词用交替字面量而非括号表达式（C locale 下多字节括号表达式按单
#      字节匹配，不可靠）：
#        模式甲：[0-9]+～[0-9]+ 共
#        模式乙：共 [0-9]+ (张|条|项|件|个)
#      排除面（数据注记，每条一句理由——历史真陈述/机器生成面非现行声明，不属
#      「会腐烂的现行计数」；2026-09-21 协调层裁决 O3 收窄）：
#        facts/requirements/tickets/*.md       票面历史文件——历史票文不改写原则
#        facts/requirements/runs/              run record 投影——运行记录面
#        facts/requirements/tickets/progress-current.md      现役状态投影——Derived 生成器独占写
#        facts/project/archive/progress.md      冻结历史档案——指针注记后零写入（票 87 迁址）
#        facts/project/archive/changes.md       只追加账本冻结件——历史条目不可改写（票 87 迁址）
#        facts/project/architecture/generated/  机器生成投影面——与 runs/ 同性质（票 59 口径）
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
        # shellcheck disable=SC2086  # set -- \$_line 刻意按空白分词取字段（分词即解析手段）
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

check_s4_block() {
  # S4-① 生成块新鲜度（票 277）：README 票表改为索引派生生成块——原「锚点行数 ↔ 索引条目数」
  # 数量相等断言退役，改为调用 generate-progress.sh --check-readme 只读核对（token/派生
  # 口径唯一实现＝生成器，本件零副本；不按实现猜）。README/索引缺失或生成器不可用 →
  # WARN 跳过不硬猜（对齐 S1/S3 退化语义）。
  _rf="$repo_root/$issues_readme_rel"
  _idx="$repo_root/$issues_index_rel"
  if [ ! -f "$_rf" ] || [ ! -f "$_idx" ]; then
    emit_warn S4 "$issues_readme_rel" "S4 生成块新鲜度断言跳过：$issues_readme_rel 或 $issues_index_rel 缺失，按退化语义不硬猜"
    return 0
  fi
  _s4_gen=''
  if [ -f "$script_dir/generate-progress.sh" ] && [ -r "$script_dir/generate-progress.sh" ]; then
    _s4_gen="$script_dir/generate-progress.sh"
  elif [ -f "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ] && [ -r "$repo_root/$repo_scripts_dir_rel/generate-progress.sh" ]; then
    _s4_gen="$repo_root/$repo_scripts_dir_rel/generate-progress.sh"
  fi
  if [ -z "$_s4_gen" ]; then
    emit_warn S4 "$issues_readme_rel" 'S4 生成块新鲜度断言跳过：generate-progress.sh 不可用（脚本同目录与仓库 scripts 目录均未找到），不按实现猜派生口径'
    return 0
  fi
  _s4_rc=0
  _s4_out=$(sh "$_s4_gen" --check-readme "$repo_root" 2>&1) || _s4_rc=$?
  case $_s4_rc in
    0) : ;;
    1) emit_stale "$issues_readme_rel" "票表生成块与索引派生不一致（stale）——运行生成器（无参数）刷新：${_s4_out:-（生成器无输出）}" ;;
    2) emit_stale "$issues_readme_rel" "票表生成块结构异常（generate-progress --check-readme exit 2）：${_s4_out:-（生成器无输出）}" ;;
    *) emit_stale "$issues_readme_rel" "票表生成块核对异常（generate-progress --check-readme exit ${_s4_rc}）：${_s4_out:-（生成器无输出）}" ;;
  esac
  return 0
}

check_s4_scan() {
  # S4-② 计数模式扫描：artifacts.yaml 单件＋facts/ 树 md（排除面见数据节注记），
  # 命中经豁免表恰整行比对后报 STALE-prone（计入过期断言计数）。
  [ -d "$repo_root/$facts_tree_rel" ] || return 0
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
  if [ -f "$repo_root/$artifacts_yaml_rel" ]; then
    _scan_file "$repo_root/$artifacts_yaml_rel"
  fi
  if [ -d "$repo_root/$facts_tree_rel" ]; then
    _s4_files=$(find "$repo_root/$facts_tree_rel" \
      \( -path "$repo_root/$issues_dir_rel" -o -path "$repo_root/$agent_runs_dir_rel" -o -path "$repo_root/$arch_generated_dir_rel" \) -prune -o \
      -type f -name '*.md' -print 2>/dev/null)
    for _s4f in $_s4_files; do
      case $_s4f in
        "$repo_root/$progress_rel" | "$repo_root/$archive_changes_rel" | "$repo_root/$progress_current_rel") continue ;;
      esac
      [ -f "$_s4f" ] || continue
      _scan_file "$_s4f"
    done
  fi
  stale_count=$((stale_count + _s4_total))
  return 0
}

check_s4() {
  check_s4_block
  check_s4_scan
}

# ---- S5 方案结论标注句（票 85）------------------------------------------------
#
# R-DP-033 加固配套格式断言：调研/对比产出的结论行逐条标注证据出处与适用轨。
# 只查格式不判语义——标注的出处是否真支撑结论归独立评审（合同 Forbidden）。
#
# 扫描面 glob 清单（唯一承载点；条文同步登记于 R-DP-033，扩面两处同步改，禁静默
# 扩面——票 78 词表教训）：每行一条「<目录>/*.md」形态，单层语义（目录直属 .md）；
# 病态形态（路径含空白/冒号、非 ASCII 引号转义路径）不受理（对齐 S4 已知限制）。
# 结论行识别规则（登记防误扫）：行首（允许前置空白与一个「- 」列表标记）以「结论：」
# 起始的行；非此形态零命中即零报。
# 适用轨受控词表：本仓自用 | agent-up（两值；未来多产品轨预留登记机制，不扩展实现）。

s5_load_globs() {
  printf '%s\n' "$s5_scan_glob"
}

s5_track_pat='轨:(本仓自用|agent-up)'
s5_line_pat='^[[:space:]]*(-[[:space:]]+)?结论：'

check_s5() {
  # S5：扫描面文件 ∩ 工作区新增/修改面（git status --porcelain 判定）→ 结论行逐行
  # 核对 file: 出处与轨:标注；缺任一 emit_stale 指名 file:line（计入过期断言计数）。
  _s5_globs=$(s5_load_globs)
  [ -n "$_s5_globs" ] || return 0
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn S5 "$s5_scan_glob" 'S5 结论标注断言跳过：目标当前不是 Git 工作区，新增/修改面无法判定，按流程退化语义跳过（对齐 S1）'
    return 0
  fi
  _s5_changed=$(git -C "$repo_root" -c core.quotePath=off status --porcelain --untracked-files=all 2>/dev/null) || _s5_changed=''
  [ -n "$_s5_changed" ] || return 0
  for _s5_g in $_s5_globs; do
    case $_s5_g in
      */*.md) _s5_dir=${_s5_g%/*.md} ;;
      *)
        printf 'check-stale-claims: 错误：S5 扫描面 glob 登记破坏（须「<目录>/*.md」形态）：%s\n' "$_s5_g" >&2
        return 2
        ;;
    esac
    for _s5_line in $_s5_changed; do
      [ -n "$_s5_line" ] || continue
      _s5_path=${_s5_line#?? }
      case $_s5_path in
        *' -> '*) _s5_path=${_s5_path##* -> } ;;  # 改名条目取新路径
      esac
      case $_s5_path in
        "$_s5_dir"/*) ;;
        *) continue ;;
      esac
      _s5_base=${_s5_path#"$_s5_dir"/}
      case $_s5_base in
        *.md) ;;
        *) continue ;;
      esac
      case $_s5_base in
        */*) continue ;;  # 单层语义：子目录直属面外不扫（glob 登记语义）
      esac
      [ -f "$repo_root/$_s5_path" ] || continue
      _s5_hits=$(LC_ALL=C grep -nE "$s5_line_pat" "$repo_root/$_s5_path" 2>/dev/null) || _s5_hits=''
      [ -n "$_s5_hits" ] || continue
      while IFS= read -r _s5_hit; do
        [ -n "$_s5_hit" ] || continue
        _s5_ln=${_s5_hit%%:*}
        _s5_txt=${_s5_hit#*:}
        _s5_miss=''
        case $_s5_txt in
          *file:*) : ;;
          *) _s5_miss='证据出处（file:）' ;;
        esac
        if ! printf '%s\n' "$_s5_txt" | LC_ALL=C grep -qE "$s5_track_pat"; then
          if [ -n "$_s5_miss" ]; then
            _s5_miss="${_s5_miss}、适用轨（轨:本仓自用|agent-up）"
          else
            _s5_miss='适用轨（轨:本仓自用|agent-up）'
          fi
        fi
        [ -n "$_s5_miss" ] || continue
        emit_stale "$_s5_path:$_s5_ln" "结论行缺标注（S5，票 85）：缺${_s5_miss}——按 R-DP-033 逐条标注（只查格式不判语义）"
      done <<S5_HITS_INNER
$_s5_hits
S5_HITS_INNER
    done
  done
  return 0
}

# ---- S6 终态哨兵（票 94，R3/R8 合并）-----------------------------------------
#
# 终态哨兵：facts/requirements/tickets/index.json（票状态真相源）内 id 曾达终态（done/superseded）
# 而当前 status 回到非终态 → STALE 指名票 id 与跃迁方向（复盘缺口④：W5 重放把 done
# 票打回 in_progress 时对账照绿——S3 只查投影↔索引一致性，不查状态语义合法性）。
# 基线锚＝该索引的 Git 现行提交历史：`git log -p` 逐提交提取 + 行的 id/status，曾见
# 终态即入哨兵集（选型见登记表 S6 注记）。终态/非终态受控词表：
#   终态   done | superseded
#   非终态 ready | in_progress | blocked | review_ready | review_pass | review_fail
# （与 ticket-ops.sh flip --status 的状态机八值一致；超集之外的 status 值属排版/词表
# 破坏，归 S3 --check exit 2 语义，本哨兵不另断言。）
# 退化语义：非 Git 工作区 → WARN 跳过；索引尚无基线提交且当前行无可提取条目（无可比
# 历史）→ WARN 跳过，不硬猜。已知限制：`git log -p` 对 merge commit 默认不出 patch
# ——仅经合并冲突引入索引的终态史不入哨兵集（现行流程翻转均经普通提交）。

check_s6() {
  _idx="$repo_root/$issues_index_rel"
  if [ ! -f "$_idx" ]; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引文件不存在（票状态真相源缺失），对齐 S3 缺失退化语义'
    return 0
  fi
  if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：目标当前不是 Git 工作区，终态基线不可判定，按流程退化语义跳过（对齐 S1/S5）'
    return 0
  fi
  # 基线提取（票 284 解析收敛）：历史 + 行先聚合为 JSON 数组，后经唯一 JSON 引擎
  # json rows 一次解析（键序无关、紧凑与带空格同受理；不逐行起子进程、不内嵌 jval）。
  _s6_hist_raw=$(git -C "$repo_root" log -p --format= -- "$issues_index_rel" 2>/dev/null \
    | LC_ALL=C grep '^+.*{"id"' | sed 's/^+//; s/,[[:space:]]*$//') || _s6_hist_raw=''
  _s6_hist=''
  if [ -n "$_s6_hist_raw" ]; then
    _s6_hist=$( { printf '['; printf '%s\n' "$_s6_hist_raw" | paste -sd, -; printf ']'; } \
      | python3 "$_engine" json rows - '' id status 2>/dev/null ) || _s6_hist=''
  fi
  _s6_now=$(python3 "$_engine" json rows "$_idx" issues id status 2>/dev/null) || {
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引条目行不可经唯一 JSON 引擎解析（排版破坏归 S3 --check 口径），本次不硬猜'
    return 0
  }
  if [ -z "$_s6_hist" ] && [ -z "$_s6_now" ]; then
    emit_warn S6 "$issues_index_rel" 'S6 终态哨兵跳过：索引尚无基线提交且当前行无可提取条目（无可比历史），不硬猜'
    return 0
  fi
  # 曾见终态集：历史段任一时刻 status 为终态的 id（终态票现行终态属合法稳态，不报；
  # 只有「曾终态→现非终态」才报）。分类一次 awk 完成（历史段入集→分隔标记→当前行判定），
  # 循环内零命令替换，action 行回 shell 交 emit_stale（计数与报文口径不变）。
  _s6_actions=$( { printf '%s\n' "$_s6_hist"; printf '@@S6_SPLIT@@\n'; printf '%s\n' "$_s6_now"; } \
    | LC_ALL=C awk -F'\t' -v loc="$issues_index_rel" '
      BEGIN { phase = 1 }
      $0 == "@@S6_SPLIT@@" { phase = 2; next }
      phase == 1 { if ($2 == "done" || $2 == "superseded") term[$1] = 1; next }
      {
        st = $2
        if (st == "ready" || st == "in_progress" || st == "blocked" || st == "review_ready" || st == "review_pass" || st == "review_fail") {
          if ($1 in term) printf "STALE\t%s:%s\tS6 终态哨兵：票 %s 曾达终态，当前 status 被改回非终态 %s——done/superseded 为终态，幽灵态即报；合法复开须以新票承载（改 id）或显式 superseded 登记\n", loc, $1, $1, st
        }
      }
    ')
  if [ -n "$_s6_actions" ]; then
    while IFS="$TAB" read -r _s6_tag _s6_loc _s6_msg; do
      [ -n "$_s6_tag" ] || continue
      case $_s6_tag in
        STALE) emit_stale "$_s6_loc" "$_s6_msg" ;;
      esac
    done <<S6_ACTIONS
$_s6_actions
S6_ACTIONS
  fi
  return 0
}
# ---- S7 替代标记存在性（R-DP-039 替代标记面配套）---------------------------
#
# superseded_by 存在性断言（票 284 解析收敛：索引条目经唯一 JSON 引擎 json rows 解析——
# 键序无关、紧凑与带空格同受理；原三份 awk jval 副本随解析收敛合一为引擎调用，环检测
# 与收口顺序一次 awk 分类、循环内零命令替换）：
#   ① 指向的票 id 必须真实存在于本索引（缺失即 STALE 指名双方 id）；
#   ② 指向票自身带 superseded_by（替代链环/自指）即 STALE（A 替代 B、B 又被替代的环语义
#      无法裁决现行依据，登记时拆环只指最终替代票）；
#   ③ 指向票状态非终态（替代票尚未收口）仅 WARN 不拦截（先标后收为合法顺序）。
# 字段缺失＝零命中零报（可选字段语义，存量票零回扫，R-DP-039 明文不按时间自动打标）。

check_s7() {
  _idx="$repo_root/$issues_index_rel"
  if [ ! -f "$_idx" ]; then
    emit_warn S7 "$issues_index_rel" 'S7 替代标记断言跳过：索引文件不存在（票状态真相源缺失），对齐 S3/S6 缺失退化语义'
    return 0
  fi
  _s7_rows=$(python3 "$_engine" json rows "$_idx" issues id status superseded_by 2>/dev/null) || {
    emit_warn S7 "$issues_index_rel" 'S7 替代标记断言跳过：索引条目行不可经唯一 JSON 引擎解析（排版破坏归 S3 --check 口径），本次不硬猜'
    return 0
  }
  [ -n "$_s7_rows" ] || return 0
  # 存在性＋链环＋收口顺序一次 awk 分类（action 行回 shell 交 emit_*：STALE 计数与 WARN
  # 条目登记日期口径不变；循环内零命令替换）。
  _s7_actions=$(printf '%s\n' "$_s7_rows" | LC_ALL=C awk -F'\t' -v loc="$issues_index_rel" '
    $1 != "" {
      if (!($1 in seen_id)) { seen_id[$1] = 1; st[$1] = $2 }
      if ($3 != "") { marked[$1] = $3; mlist[++m] = $1 }
    }
    END {
      for (i = 1; i <= m; i++) {
        src = mlist[i]; dst = marked[src]
        if (!(dst in seen_id)) {
          printf "STALE\t%s:%s\tS7 替代标记断言：票 %s 的 superseded_by 指向 %s，但该票不在索引中——替代标记指向的票必须真实存在（R-DP-039），修标或先开替代票\n", loc, src, src, dst
          continue
        }
        if (dst in marked && !reported[dst]) {
          printf "STALE\t%s:%s\tS7 替代标记断言：票 %s 自身亦带 superseded_by 替代标记——替代链出现二度替代（环语义无法裁决现行依据），登记时拆环只指最终替代票（R-DP-039）\n", loc, dst, dst
          reported[dst] = 1
          continue
        }
        if (st[dst] == "done" || st[dst] == "superseded") continue
        if (st[dst] == "") {
          printf "WARN\t%s:%s\tS7 收口顺序提醒：票 %s 的 superseded_by 指向 %s，指向票状态不可读（词表外或排版漂移），人工核对\n", loc, src, src, dst
        } else {
          printf "WARN\t%s:%s\tS7 收口顺序提醒：票 %s 的 superseded_by 指向 %s，替代票尚未收口（状态 %s）——先标后收为合法顺序，收口后本提醒自然消除\n", loc, src, src, dst, st[dst]
        }
      }
    }
  ')
  if [ -n "$_s7_actions" ]; then
    while IFS="$TAB" read -r _s7_tag _s7_loc _s7_msg; do
      [ -n "$_s7_tag" ] || continue
      case $_s7_tag in
        STALE) emit_stale "$_s7_loc" "$_s7_msg" ;;
        WARN) emit_warn S7 "$_s7_loc" "$_s7_msg" ;;
      esac
    done <<S7_ACTIONS
$_s7_actions
S7_ACTIONS
  fi
  return 0
}

# ---- S8 复盘沉淀指针（R-DP-041 检查面配套）---------------------------------
#
# lesson 行沉淀指针核对（票 284：教训账本缺失改 WARN 显式退化，不再静默返回 0；指针抽取
# 单次 awk 预计算、循环内零命令替换；账本路径经 changes_jsonl_rel 常量承载）：
# changes.jsonl 的 kind=lesson 行，promoted_to ∈ {rules, validator, test} 且 decision/
# evidence_ref 含可 grep 文件指针（rules/ 或 scripts/ 开头路径，可带 #锚点后缀）时——
# ①指针文件存在于仓库根；②带 #锚点时锚点文本在文件中可 grep。文件缺失或锚点丢失＝
# STALE 指名行号与指针（沉淀被删或指针写错）。promoted_to ∈ {新票, none} 跳过（新票由
# 票务系统管、none 无沉淀义务）；指针不可 grep 形态＝NOTE 退化说明不计失败。零 lesson
# 行零报。账本文件缺失＝WARN 显式跳过（对齐 S3/S6/S7 缺失退化语义）。变量引用一律用
# 花括号形态（bash 3.2 set -u 多字节变量名解析事故，票 127 教训）。

check_s8() {
  _ledger="$repo_root/$changes_jsonl_rel"
  if [ ! -f "$_ledger" ]; then
    emit_warn S8 "$changes_jsonl_rel" 'S8 复盘沉淀指针断言跳过：教训账本不存在（记录层账本缺失），按退化语义显式跳过不硬猜（对齐 S3/S6/S7 缺失退化；不再静默返回 0）'
    return 0
  fi
  # 单次 awk 预计算（行号｜指针｜文件｜锚点）：lesson+promoted_to 过滤、首个可 grep 指针
  # 抽取与锚点收窄一并在扫描内完成（原逐行命令替换与整册 cat 已去除）。
  _s8_ptrs=$(LC_ALL=C awk '
    {
      line = $0
      if (line !~ /"kind": ?"lesson"/) next
      if (line !~ /"promoted_to": ?"(rules|validator|test)"/) next
      if (!match(line, /[^A-Za-z0-9._\/-](rules|scripts)\/[A-Za-z0-9._\/-]+(#[^" ]*)?/)) next
      ptr = substr(line, RSTART + 1, RLENGTH - 1)
      file = ptr
      anchor = ""
      h = index(ptr, "#")
      if (h > 0) { file = substr(ptr, 1, h - 1); anchor = substr(ptr, h + 1) }
      if (anchor != "") {
        n = index(anchor, " ")
        if (n > 1) anchor = substr(anchor, 1, n - 1)
        gsub(/[。.,，;；:：)）!！?？"]+$/, "", anchor)
      }
      printf "%d\t%s\t%s\t%s\n", NR, ptr, file, anchor
    }
  ' "$_ledger" 2>/dev/null) || _s8_ptrs=''
  _s8_hit=0
  while IFS="$TAB" read -r _s8_ln _s8_ptr _s8_file _s8_anchor; do
    [ -n "$_s8_ln" ] || continue
    _s8_hit=$((_s8_hit + 1))
    if [ ! -f "$repo_root/$_s8_file" ]; then
      emit_stale "$_ledger:$_s8_ln" "S8 复盘沉淀指针：lesson 行沉淀指针 ${_s8_ptr} 指向的文件不存在——沉淀被删或指针写错（R-DP-041 检查面），修指针或重沉淀"
      continue
    fi
    if [ -n "${_s8_anchor}" ]; then
      _s8_arc_rc=0
      LC_ALL=C grep -qF "${_s8_anchor}" "$repo_root/$_s8_file" 2>/dev/null || _s8_arc_rc=$?
      if [ "$_s8_arc_rc" -eq 1 ]; then
        emit_stale "$_ledger:$_s8_ln" "S8 复盘沉淀指针：lesson 行沉淀指针 ${_s8_ptr} 的锚点在目标文件中不存在——文件已演进或指针写错（R-DP-041 检查面），修指针或落新 lesson 行校正（append-only）"
      elif [ "$_s8_arc_rc" -ge 2 ]; then
        emit_warn S8 "$_ledger:$_s8_ln" "S8 锚点核对异常（目标文件不可读或 grep 错误）：${_s8_ptr}——人工核对"
      fi
    fi
  done <<S8_PTRS
$_s8_ptrs
S8_PTRS
  if [ "$_s8_hit" -eq 0 ]; then
    printf 'NOTE: %s — 无可 grep 沉淀指针的 lesson 行（S8 扫描面零命中，promoted_to 新票/none 或指针不可 grep 形态不在面）\n' "$changes_jsonl_rel"
  fi
  return 0
}

# ---- 执行 ------------------------------------------------------------------
# S1/S2 配置点亮（票 72）：未点亮（delivery.rules 缺失或 calibration 节无 dp_stale_lit
# 登记）→ 打印 SKIP 行，不计过期断言不拦票；点亮＝现行断言逻辑原样执行。
# S3/S4/S5/S6/S7/S8 为通用面（协议），无点亮位恒执行。

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
check_s5
check_s6
check_s7
check_s8

_pn=$(prog_name)
# 登记总数动态化（票 72 设计 §4③）：点亮数（S1/S2）＋通用条数（S3/S4/S5/S6/S7/S8 恒 6）；
# 全点亮语境渲染「登记表共 8 条」（票 134 起 7→8）。
_total_entries=$((6 + s1_lit + s2_lit))
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
