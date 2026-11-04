#!/bin/sh
# Input: 仓库根目录（缺省经 resolve_repo_root 落位分派推导）与模式选项：
#        ① changes 行族：--ledger-line <json>（必选，完整 JSONL 账本行）；
#        ② 微账本行族（票 229）：--micro ＋ --date <YYYY-MM-DD>、--whitelist <逗号分隔>、
#           --verify <重跑验证条数>、--commit <产品提交 ID>、可选 --actual <净工时文本>
#           （逐字段传入，行由本件按固定键序生成）；
#        --check（只校验零写入，写前预检模式）对两模式同样适用；--break-stale-lock
#        （或 RECORD_LOCK_BREAK_STALE=1）仅在写模式遇陈旧锁时显式夺锁。
# Output: facts/project/changes.jsonl 追加一行（键序 date,kind,scope,decision,evidence_ref
#         五键必备＋按 kind 条件键：lesson 必带第六键 promoted_to、replan 必带
#         replan_original/replan_replacement/replan_undone；lesson 可选三分数键——带分数
#         则恰九键，键序固定）。本文件为该账本唯一写入方（写入方收敛票 228 F7：ticket-ops
#         open/take/flip/ledger 的账本落行与写前预检改经本件承载，本仓其余脚本零
#         changes.jsonl 写入面）；--check 模式只做形状校验零写入（ticket-ops 校验先于
#         票务面写入的 fail-closed 时序经此保持）。票 229 起 facts/project/micro.jsonl
#         微账本亦归本件写入面（--micro 模式：行型合同同 schema 的 micro_seven_key /
#         micro_six_key_legacy 行族，键序 date,lane,whitelist,gates,verify,commit,actual；
#         懒创建仅限账本文件本体与 facts/project/ 父目录；原有六键行只追加不改写，道脚本
#         lane-commit.sh 零微账本写入面）。票 246 起写模式独立调用时自取记录层写锁
#         （共享库 record_lock_*），被 ticket-ops 嵌套调用时按继承标记跳过取锁与释放；
#         --check 模式不取锁。
# Pos: 记录层账本单写方脚本（changes.jsonl 与 micro.jsonl 两账本）。行型合同＝agent-up
#      公开包 references/schemas/ledger-row.schema.json 的 changes_* 与 micro_* 行族（文档级
#      单源，不运行时读取，安装闭包不含此件）；行族形状校验链（键集/键序/条件键/值域，逐条
#      报文与退出码保持 ticket-ops 套件既有断言字面）＋唯一 JSON 引擎 json-validator.py
#      json fields 解析门（changes 行族 JSON 可解析性由唯一引擎承载——票 227 口径；缺
#      python3 或引擎即 fail-closed 指名，零写入）。懒创建仅限账本文件本体（父目录随
#      mkdir -p）；校验先于写入，零外部依赖（JSON 解析门另用 python3 标准库与引擎件）。
#      微账本行族由 shell 层校验字段并生成固定键序行（不新增解释器依赖，保持 lane-commit
#      微任务道原有运行面）。写互斥经共享库记录层写锁原语承载（票 246：本件不复制锁代码，
#      独立调用自取锁、嵌套调用识别继承、写前令牌归属校验）。

# 用法、行型合同与退出码见同目录 README.md。
# ledger-rowtype-version: 3（五键/lesson 六键九键/replan 八键；机制版本注记，票 133 行型）

changes_ledger_rel='facts/project/changes.jsonl'
micro_ledger_rel='facts/project/micro.jsonl'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5 口径：统一 source common-helpers.sh）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'ledger-append: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/ledger-append.sh [repo-root] --ledger-line <json> [--check]
      sh rules/implementation/scripts/ledger-append.sh [repo-root] --micro \
        --date <YYYY-MM-DD> --whitelist <逗号分隔相对路径> --verify <条数> \
        --commit <产品提交 ID> [--actual <净工时文本>] [--check]
参数:
  repo-root      仓库根目录；缺省按脚本落位分派推导（agent-up/scripts/ 与
                 rules/implementation/scripts/ 两布局可正确推导，其余落位兜底上两级）。
  --ledger-line <json>  完整 JSONL 账本行（键序 date,kind,scope,decision,evidence_ref 五键
                 必备＋按 kind 条件键：lesson 必带第六键 promoted_to（枚举
                 新票/rules/sop/validator/test/none，可选三分数键——带分数则恰九键）、
                 replan 必带 replan_original/replan_replacement/replan_undone（布尔）；
                 行型键集/键序/值域适用表单一合同＝agent-up 公开包 references/schemas/
                 ledger-row.schema.json；紧凑或带空格 JSONL 均可；脚本只校验后追加，
                 不代生成散文；字符串值不得内嵌引号或反斜杠）。
  --micro        微账本行模式（与 --ledger-line 互斥，票 229）：按固定键序生成
                 `{"date": ..., "lane": "micro", "whitelist": ..., "gates": "PASS",
                 "verify": N, "commit": ..., "actual": ...}` 并追加 facts/project/micro.jsonl
                 （行型合同同 schema 的 micro_seven_key 行族；懒创建仅限账本本体与
                 facts/project/ 父目录；既有六键行只追加不改写）。配套字段：
                   --date <YYYY-MM-DD>       行日期（必选）
                   --whitelist <csv>         逗号分隔白名单（必选，JSON 转义写行）
                   --verify <n>              重跑验证命令条数（必选，正整数）
                   --commit <rev>            产品提交 ID（必选，[0-9a-f]{7,}）
                   --actual <text>           净工时文本（可选，缺省空串；JSON 转义写行）
  --check        只校验零写入：行族形状校验（--micro 另含字段校验）全过即 exit 0，不触
                 账本文件（ticket-ops 票务面写前预检与道脚本收尾预检经此模式承载）。
  --break-stale-lock  仅写模式生效：遇到陈旧锁时显式夺锁（等价 RECORD_LOCK_BREAK_STALE=1）；
                 缺省只诊断不夺锁，等待超时即 exit 1。可出现在任意选项位置。
  -h / --help    打印本用法。
环境变量: TICKET_OPS_LOCK_TIMEOUT  写锁等待上限秒数（缺省 20）
          TICKET_OPS_LOCK_STALE    写锁陈旧判据秒数（缺省 600；仅用于 pid 缺失时的锁龄判定）
          RECORD_LOCK_BREAK_STALE  设为 1 时对陈旧锁显式夺锁
          RECORD_LOCK_TEST_HOLD_MS 仅测试用：持锁后延迟返回的毫秒数（未设或 0＝零开销）
互斥边界: 写锁目录由仓库根的 Git 公共目录推导（经 rev-parse 取公共目录并归一为绝对物理
          路径），主检与全部 worktree 争用同一把锁；非 Git 语境回退 $TMPDIR 并按仓库根
          物理路径派生。跨主机/跨用户不互斥。锁目录不进入版本控制跟踪面。
退出码: 0 校验通过（--check）或落行完成；1 fail-closed（行形/字段/解析/写入不过，零写入或
        已写部分如实报告；写锁等待超时或归属失效＝并发冲突，零写入）；2 用法或环境错误。
USAGE
}

repo_root=''
ledger_line=''
check_mode=0
micro_mode=0
micro_date=''
micro_whitelist=''
micro_verify=''
micro_commit=''
micro_actual=''
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --ledger-line) [ $# -ge 2 ] || die2 '--ledger-line 缺值'; ledger_line=$2; shift 2 ;;
    --micro) micro_mode=1; shift ;;
    --date) [ $# -ge 2 ] || die2 '--date 缺值'; micro_date=$2; shift 2 ;;
    --whitelist) [ $# -ge 2 ] || die2 '--whitelist 缺值'; micro_whitelist=$2; shift 2 ;;
    --verify) [ $# -ge 2 ] || die2 '--verify 缺值'; micro_verify=$2; shift 2 ;;
    --commit) [ $# -ge 2 ] || die2 '--commit 缺值'; micro_commit=$2; shift 2 ;;
    --actual) [ $# -ge 2 ] || die2 '--actual 缺值'; micro_actual=$2; shift 2 ;;
    --check) check_mode=1; shift ;;
    --break-stale-lock) RECORD_LOCK_BREAK_STALE=1; export RECORD_LOCK_BREAK_STALE; shift ;;
    --*) die2 "未知参数: $1" ;;
    *) if [ -n "${repo_root}" ]; then die2 "多余参数: $1（只接受一个仓库根）"; fi; repo_root=$1; shift ;;
  esac
done

# 仓库根推导统一经 resolve_repo_root（票 227 F4 口径：显式参数 > 落位分派两布局）
if [ -n "${repo_root}" ]; then
  _rr=$(resolve_repo_root "${repo_root}") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "$_rr" ] || die2 "仓库根不可用: ${repo_root:-（未传参且脚本落位非两布局，无法缺省推导）}"
repo_root=$_rr
[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"

_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# ---- 记录层写锁（票 246：独立调用自取锁；嵌套调用识别继承标记，跳过取锁与释放） ----
lock_for_write() {
  if [ "${check_mode}" -eq 1 ]; then
    return 0
  fi
  if record_lock_inherit; then
    return 0
  fi
  record_lock_init "${repo_root}"
  trap 'record_lock_release' EXIT HUP INT TERM
  record_lock_acquire
}

# ---- 微账本行模式（票 229：facts/project/micro.jsonl 归本件写入面）----
# 逐字段校验后按固定键序生成行；--check 只校验零写入。与 changes 行族互斥：两模式
# 字段不得混用（防调用方误把微账本字段当 changes 行放过）。
if [ "${micro_mode}" -eq 1 ]; then
  case ${ledger_line} in
    '') : ;;
    *) die2 '--micro 与 --ledger-line 互斥（一次只落一类账本行）' ;;
  esac
  [ -n "${micro_date}" ] || die1 '微账本行缺少 --date'
  [ -n "${micro_whitelist}" ] || die1 '微账本行缺少 --whitelist'
  [ -n "${micro_verify}" ] || die1 '微账本行缺少 --verify'
  [ -n "${micro_commit}" ] || die1 '微账本行缺少 --commit'
  printf '%s' "${micro_date}" | LC_ALL=C grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || \
    die1 "微账本行 --date 不合 YYYY-MM-DD 口径: ${micro_date}"
  printf '%s' "${micro_verify}" | LC_ALL=C grep -Eq '^[1-9][0-9]*$' || \
    die1 "微账本行 --verify 须为正整数（重跑验证命令条数）: ${micro_verify}"
  printf '%s' "${micro_commit}" | LC_ALL=C grep -Eq '^[0-9a-f]{7,}$' || \
    die1 "微账本行 --commit 不合产品提交 ID 口径（[0-9a-f]{7,}）: ${micro_commit}"
  for _mf in "${micro_whitelist}" "${micro_actual}"; do
    case ${_mf} in
      *"${NL}"*|*"${TAB}"*) die1 '微账本行字段含裸换行或制表符（一行一事实，禁裸换行）' ;;
    esac
  done
  # JSON 转义：反斜杠先行，再双引号（与拆出前 lane-commit.sh 微账本落行口径一致）
  micro_wl_json=$(printf '%s' "${micro_whitelist}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  micro_actual_json=$(printf '%s' "${micro_actual}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  micro_line=$(printf '{"date": "%s", "lane": "micro", "whitelist": "%s", "gates": "PASS", "verify": %s, "commit": "%s", "actual": "%s"}' \
    "${micro_date}" "${micro_wl_json}" "${micro_verify}" "${micro_commit}" "${micro_actual_json}")
  printf '%s' "${micro_line}" | LC_ALL=C grep -Eq '^\{"date": "[0-9]{4}-[0-9]{2}-[0-9]{2}", "lane": "micro", "whitelist": ".*", "gates": "PASS", "verify": [1-9][0-9]*, "commit": "[0-9a-f]{7,}", "actual": ".*"\}$' || \
    die1 '微账本行不合 micro_seven_key 行族形态（键序 date,lane,whitelist,gates,verify,commit,actual）'
  if [ "${check_mode}" -eq 1 ]; then
    printf 'ledger-append: CHECK: PASS — 微账本行字段与行形校验通过（零写入）\n'
    exit 0
  fi
  lock_for_write
  record_lock_assert
  micro_ledger_file="${repo_root}/${micro_ledger_rel}"
  if [ ! -f "${micro_ledger_file}" ]; then
    mkdir -p "${repo_root}/$(dirname "${micro_ledger_rel}")"
    : > "${micro_ledger_file}" || die1 "微账本懒创建失败: ${micro_ledger_file}"
  fi
  [ -w "${micro_ledger_file}" ] || die1 "微账本不可写: ${micro_ledger_file}"
  micro_lineno=$(( $(wc -l < "${micro_ledger_file}" | tr -d ' ') + 1 ))
  record_lock_assert
  printf '%s\n' "${micro_line}" >> "${micro_ledger_file}" || die1 "微账本落行失败: ${micro_ledger_file}"
  printf "ledger-append: 微账本落行: ${micro_ledger_rel}（第 %d 行）\n" "${micro_lineno}"
  exit 0
fi

case ${ledger_line} in
  '') die1 '缺少 --ledger-line' ;;
esac
case "${micro_date}${micro_whitelist}${micro_verify}${micro_commit}${micro_actual}" in
  '') : ;;
  *) die2 '微账本字段（--date/--whitelist/--verify/--commit/--actual）仅与 --micro 一起使用' ;;
esac
case ${ledger_line} in
  *"${NL}"*|*"${TAB}"*) die1 '账本行含裸换行或制表符（一行一事实，禁裸换行）' ;;
esac
# 行族形状校验（行型合同 references/schemas/ledger-row.schema.json 键集对齐；仅向前生效）：
# 五键必备＋按 kind 条件键＋promoted_to 枚举。非 lesson/replan 维持恰五键收口（既有合法面
# 不放宽不收窄）；lesson 六键（既有）或九键（可选追加三分数键 score_contract/score_predicate/
# score_rework：0-100 整数或 -1=N/A，键序固定，票 133）——第六键 promoted_to 枚举＝
# 新票/rules/sop/validator/test/none（填 none 亦算显式拍板，防教训悬空；越枚举不静默收编）；
# replan 恰八键——三条件键须为布尔字面量 true/false。条件键一律紧跟 evidence_ref 之后按
# 固定次序排布（键序稳定，键序破坏形态同拒）。
if printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"lesson", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"promoted_to": ?"(新票|rules|sop|validator|test|none)"\}$'; then
  :
elif printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"lesson", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"promoted_to": ?"(新票|rules|sop|validator|test|none)", ?"score_contract": ?([0-9]|[1-9][0-9]|100|-1), ?"score_predicate": ?([0-9]|[1-9][0-9]|100|-1), ?"score_rework": ?([0-9]|[1-9][0-9]|100|-1)\}$'; then
  :
elif printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"replan", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"replan_original": ?(true|false), ?"replan_replacement": ?(true|false), ?"replan_undone": ?(true|false)\}$'; then
  :
elif printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"[^"\\]*", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*"\}$'; then
  # 恰五键行：kind=lesson/replan 即缺条件键，指名报因；其余 kind 维持既有合法面
  ledger_kind=$(printf '%s' "${ledger_line}" | sed -n 's/^{"date": \{0,1\}"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}", \{0,1\}"kind": \{0,1\}"\([^"\\]*\)".*/\1/p')
  case ${ledger_kind} in
    lesson) die1 'lesson 行缺第六键 promoted_to（枚举 新票/rules/sop/validator/test/none，填 none 亦算显式拍板——票 81）' ;;
    replan) die1 'replan 行缺条件键 replan_original/replan_replacement/replan_undone（布尔 true/false——票 81）' ;;
  esac
else
  # 形状不符：可定位行型条件键形态的指名报因，否则通用报因（fail-closed 口径不放宽）
  if printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"lesson", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"promoted_to": ?"[^"\\]*", ?"score_[a-z_]+": ?[^}]*\}$'; then
    die1 'lesson 行分数键须为 score_contract→score_predicate→score_rework 固定键序三键齐、值域 0-100 整数或 -1（N/A），带分数则恰九键（票 133）'
  fi
  if printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"lesson", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"promoted_to": ?"[^"\\]*"\}$'; then
    promoted_to_val=$(printf '%s' "${ledger_line}" | sed -n 's/.*"promoted_to": \{0,1\}"\([^"\\]*\)".*/\1/p')
    die1 "lesson 行 promoted_to 越枚举（枚举＝新票/rules/sop/validator/test/none，不静默收编——票 81）: ${promoted_to_val}"
  fi
  if printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"replan", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*", ?"replan_original": ?[^,]*, ?"replan_replacement": ?[^,]*, ?"replan_undone": ?[^}]*\}$'; then
    die1 'replan 行条件键须为布尔字面量 true/false 且按 replan_original→replan_replacement→replan_undone 固定键序（票 81）'
  fi
  # 未知键指名（行型合同 references/schemas/ledger-row.schema.json 键集对齐，不静默收编）：
  # 键名提取＝先剥字符串值再按键引号边界切分（合法行字符串值域不含双引号；畸形行尽力
  # 而为，提取不出未知键即落下方通用报因，fail-closed 结论不变）。行型选择由前序正则
  # 承载，此处只对键名归集：基础五键＋lesson 六/九键与 replan 八键条件键全集。
  ledger_unknown_keys=''
  case ${ledger_line} in
    '{'*'}')
      ledger_unknown_keys=$(printf '%s' "${ledger_line}" \
        | sed -e 's/: *"[^"]*"/:/g' \
        | sed -e 's/, \{0,1\}"/\
/g' \
        | sed -e 's/^{"//' -e 's/".*//' \
        | LC_ALL=C grep -Ev '^(date|kind|scope|decision|evidence_ref|promoted_to|score_contract|score_predicate|score_rework|replan_original|replan_replacement|replan_undone)?$' \
        | paste -sd, -)
      ;;
  esac
  case ${ledger_unknown_keys} in
    '') ;;
    *) die1 "账本行含未知键（不在行型键集内——基础五键 date,kind,scope,decision,evidence_ref＋kind 条件键，行型合同 references/schemas/ledger-row.schema.json）: ${ledger_unknown_keys}" ;;
  esac
  die1 '账本行不合键序或形状（键序 date,kind,scope,decision,evidence_ref；五键必备＋按 kind 条件键：lesson 必带第六键 promoted_to（枚举 新票/rules/sop/validator/test/none）、replan 必带 replan_original/replan_replacement/replan_undone（布尔）——票 81；紧凑或带空格 JSONL 均可；字符串值不得内嵌引号或反斜杠）'
fi

# JSON 解析门（唯一 JSON 引擎承载——票 227 口径；行族链在前的合法面恒过本门，行族链
# 外的残缺 JSON 形态由此 fail-closed 收口）：票 269 起只认安装闭包同目录引擎，不读包
# 工作树副本；缺 python3 或引擎即 fail-closed 指名缺失绝对路径与升级/修补入口，零写入。
_engine="${_self_dir}/json-validator.py"
[ -f "${_engine}" ] || \
  die1 "json-validator.py 不存在（安装闭包缺失）: ${_engine}——运行时依赖只认安装闭包（脚本同目录与 ../references/），不回退包工作树副本；缺失即安装不到位——请按 Agent Up 包 references/upgrade.md 升级或运行 scripts/install.sh 修补安装后重跑（本次零写入）"
command -v python3 >/dev/null 2>&1 || \
  die1 'python3 不可用——账本行 JSON 解析门无法执行（fail-closed；JSON 可解析性由唯一 JSON 引擎承载）'
_ledger_fields=$(printf '%s' "${ledger_line}" | python3 "${_engine}" json fields - date kind scope decision evidence_ref) || \
  die1 '账本行 JSON 解析未过（唯一 JSON 引擎 json-validator.py json fields）——零写入'
_ledger_ncol=$(printf '%s' "${_ledger_fields}" | awk -F'\t' '{ print NF; exit }')
[ "${_ledger_ncol}" = '5' ] || \
  die1 '账本行 JSON 解析未过（五必备键 date,kind,scope,decision,evidence_ref 取值不全）——零写入'

if [ "${check_mode}" -eq 1 ]; then
  printf 'ledger-append: CHECK: PASS — 账本行形状与 JSON 解析校验通过（零写入）\n'
  exit 0
fi

lock_for_write
record_lock_assert
ledger_file="${repo_root}/${changes_ledger_rel}"
if [ ! -f "${ledger_file}" ]; then
  mkdir -p "${repo_root}/$(dirname "${changes_ledger_rel}")"
  : > "${ledger_file}" || die1 "账本懒创建失败: ${ledger_file}"
fi
[ -w "${ledger_file}" ] || die1 "账本不可写: ${ledger_file}"
ledger_lineno=$(( $(wc -l < "${ledger_file}" | tr -d ' ') + 1 ))
record_lock_assert
printf '%s\n' "${ledger_line}" >> "${ledger_file}" || die1 "账本落行失败: ${ledger_file}"
printf "ledger-append: 账本落行: ${changes_ledger_rel}（第 %d 行）\n" "${ledger_lineno}"
