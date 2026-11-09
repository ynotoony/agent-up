#!/bin/sh
# Input: 调用方（ledger-append.sh）已解析的全局：micro_mode／micro_date／micro_whitelist／
#        micro_verify／micro_commit／micro_actual／micro_ledger_rel／check_mode／repo_root／
#        ledger_line／NL／TAB／_self_dir，以及来自 common-helpers 的 die1／die2、
#        record_lock_*／record_append 原语。
# Output: ledger_row_micro：micro 七键行族字段校验＋行形断言＋--check 出口＋落行；
#        ledger_row_changes：changes 行族互斥/键序/条件键形状校验＋JSON 解析门。
# Pos: 两账本行族校验模块（票 294：从 ledger-append.sh 分出两行族，写点仍经 record-store
#      的 record_append）；主件只做参数、锁与落地编排。
# shellcheck disable=SC2154  # 跨件共享状态（调用方行族上下文），单文件视野误报

ledger_row_micro() {
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
  if [ -f "${micro_ledger_file}" ]; then
    [ -w "${micro_ledger_file}" ] || die1 "微账本不可写: ${micro_ledger_file}"
    micro_lineno=$(( $(wc -l < "${micro_ledger_file}" | tr -d ' ') + 1 ))
  else
    micro_lineno=1
  fi
  micro_payload=$(mktemp "${TMPDIR:-/tmp}/ledger-append-micro.XXXXXX") || \
    die1 '微账本落行暂存件创建失败（零写入）'
  if ! printf '%s\n' "${micro_line}" > "${micro_payload}"; then
    rm -f "${micro_payload}"
    die1 "微账本落行暂存件写入失败（零写入）: ${micro_ledger_file}"
  fi
  record_append "${repo_root}" micro "${micro_payload}" || {
    rm -f "${micro_payload}"
    die1 "微账本落行失败: ${micro_ledger_file}"
  }
  rm -f "${micro_payload}"
  printf "ledger-append: 微账本落行: ${micro_ledger_rel}（第 %d 行）\n" "${micro_lineno}"
  exit 0
fi
}

ledger_row_changes() {
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
}
