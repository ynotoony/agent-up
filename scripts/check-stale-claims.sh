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
#      断言组注册表化并分片（票 289）：执行顺序、点亮位与前置钩子单源＝同目录
#      stale-claims-checks.rules，每组一件 stale-sN-slug.sh 分片同进程 source；引擎只留
#      配置加载、报告格式与汇总判定，断言组核对逻辑全在分片内（新增组＝加分片＋注册表一行）。
# dp-parser: 2
# stale-claims-version: 8（断言组 S1-S8；机制版本注记，dp-parser 先例）
#      （本件要求解析器最低版注记；解析唯一实现＝同目录 dp-load-rules.sh，版本唯一
#      来源＝其 DP_PARSER_VERSION。落地拷贝遇未知锚点/指令、解析器缺件或版本漂移即
#      报错指名——同步方式见 references/old-project.md §3 dp-load-rules.sh 引擎件行，
#      文法与版本详见 references/delivery-rules.md。四件同族脚本注记须一致。）

# 用法、登记表条目说明与输出格式见同目录 README.md。
# 状态陈述纪律见 rules/project.md §12 会话恢复与状态陈述：状态以权威引用表达，本脚本
# 即"登记表条目 = 权威位置 + 核对方式"的执行器。

# shellcheck disable=SC2034,SC2329  # 路径常量与辅助函数由同进程 source 的断言组分片消费（分片化见文件头 Pos 注记），单文件视野误报
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
#      （投影↔索引，S3）之外，终态语义由 S6 承载（rules/project.md §5.5 产物状态机）。
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

# ---- 断言组注册表加载与统一分派（S1-S8 注册表化、每断言组分片；引擎只做配置加载、
#      报告格式与汇总判定）----
_sc_registry="$script_dir/stale-claims-checks.rules"
if [ ! -f "$_sc_registry" ]; then
  printf 'check-stale-claims: 错误：断言组注册表缺失（同目录定位）: %s\n' "$_sc_registry" >&2
  exit 2
fi
_sc_rc=0
_sc_rows=$(LC_ALL=C awk '
  function bad(msg) { printf "  - 注册表第 %d 行: %s\n", FNR, msg > "/dev/stderr"; n++ }
  /^[[:space:]]*$/ { next }
  /^[[:space:]]*#/ { next }
  {
    if ($1 != "sc") { bad("未知指令: " $1 "（预期 sc）"); next }
    if (NF != 5) { bad("字段数 " NF "（预期 5：sc、断言组号、分片、点亮位、前置钩子）"); next }
    if ($2 !~ /^S[1-9][0-9]*$/) bad("断言组号须 S 加数字: " $2)
    if ($3 !~ /^[a-z0-9][a-z0-9-]*\.sh$/) bad("分片须单段 *.sh 文件名: " $3)
    if ($4 != "-" && $4 !~ /^S[1-9][0-9]*$/) bad("点亮位须 - 或断言组号: " $4)
    if ($5 != "-" && $5 !~ /^[a-z][a-z0-9_]*$/) bad("前置钩子须 - 或函数名: " $5)
    if ($2 in seen_id) bad("断言组号跨行重复: " $2); else seen_id[$2] = 1
    if ($3 in seen_file) bad("分片跨行重复: " $3); else seen_file[$3] = 1
    if (n == 0) print $2 "\t" $3 "\t" $4 "\t" $5
  }
  END { exit (n ? 1 : 0) }
' "$_sc_registry") || _sc_rc=$?
if [ "$_sc_rc" -ne 0 ]; then
  printf 'check-stale-claims: 错误：断言组注册表结构不合预期（fail-closed，不产生部分结论）: %s\n' "$_sc_registry" >&2
  exit 2
fi

# 注册表顺序逐组分派：分片统一 interface＝check_sN（只经 emit_stale/emit_warn 报告）；
# 点亮位未点名的组打印 SKIP 行不计入登记数；前置钩子在分派前装载该组配置数据节。
_total_entries=0
while IFS="$(printf '\t')" read -r _sc_id _sc_file _sc_lit _sc_pre; do
  [ -n "$_sc_id" ] || continue
  _sc_path="$script_dir/$_sc_file"
  if [ ! -f "$_sc_path" ]; then
    printf 'check-stale-claims: 错误：断言组分片缺失: %s（%s）\n' "$_sc_path" "$_sc_id" >&2
    exit 2
  fi
  # shellcheck disable=SC1090  # 分片路径由注册表现算（动态发现），静态视野不可跟随
  . "$_sc_path" || {
    printf 'check-stale-claims: 错误：断言组分片载入失败: %s（%s）\n' "$_sc_path" "$_sc_id" >&2
    exit 2
  }
  _sc_fn=check_$(printf '%s' "$_sc_id" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  if ! command -v "$_sc_fn" >/dev/null 2>&1; then
    printf 'check-stale-claims: 错误：断言组分片未定义统一 interface 函数: %s（%s）\n' "$_sc_fn" "$_sc_path" >&2
    exit 2
  fi
  if [ "$_sc_lit" != '-' ]; then
    case $DP_STALE_LIT in
      *"$_sc_lit"*) ;;
      *)
        printf 'SKIP: %s — delivery.rules 未点亮（dp_stale_lit 缺登记）\n' "$_sc_id"
        continue
        ;;
    esac
  fi
  if [ "$_sc_pre" != '-' ]; then
    "$_sc_pre"
  fi
  _total_entries=$((_total_entries + 1))
  "$_sc_fn"
done <<EOF
$_sc_rows
EOF

_pn=$(prog_name)
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
