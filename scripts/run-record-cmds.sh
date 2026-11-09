#!/bin/sh
# Input: 调用方（run-record.sh）已解析的全局：cmd／repo_root／RUNS_DIR_REL／ISSUES_DIR_REL／
#        SCRIPTS_README_REL／_self_dir／t_dir，以及共享计算函数 compute_fingerprint／
#        compute_mf_rel／absolutize／check_path_safety／json_array_body／get_index_status／
#        get_vcs_ref 与 die1／die2。
# Output: rr_cmd_stats：stats 只读聚合（委派唯一 JSON 引擎）；rr_cmd_new：new 骨架生成；
#        rr_cmd_seal：seal 校验并刷新机械字段（委派唯一 JSON 引擎）。
# Pos: run record 三子命令分层模块（票 294）；主件只做用法、子命令/仓库根解析、工具探测
#      与共享机械字段计算。
# shellcheck disable=SC2154  # 跨件共享状态（调用方上下文），单文件视野误报

rr_cmd_stats() {
if [ "$cmd" = stats ]; then
  [ -d "$repo_root/$RUNS_DIR_REL" ] || \
    die1 "$RUNS_DIR_REL/ 不存在——无卡可聚合（fail-closed）"

  # 票 269：唯一 JSON 引擎只认安装闭包同目录，不读包工作树副本
  validator_script="${_self_dir}/json-validator.py"
  [ -f "$validator_script" ] || \
    die2 "json-validator.py 不存在（安装闭包缺失）: ${validator_script}——运行时光依赖只认安装闭包（脚本同目录与 ../references/），不回退包工作树副本；缺失即安装不到位——请按 Agent Up 包 references/upgrade.md 升级或运行 scripts/install.sh 修补安装后重跑"

  python3 "$validator_script" run stats "$repo_root/$RUNS_DIR_REL"
  exit $?
fi
}

rr_cmd_new() {
# ---- new：生成骨架 ----

if [ "$cmd" = 'new' ]; then
  ticket=''
  phase=''
  mode=''
  while [ $# -gt 0 ]; do
    case $1 in
      --ticket) [ $# -ge 2 ] || die2 '--ticket 缺值'; ticket=$2; shift 2 ;;
      --phase) [ $# -ge 2 ] || die2 '--phase 缺值'; phase=$2; shift 2 ;;
      --mode) [ $# -ge 2 ] || die2 '--mode 缺值'; mode=$2; shift 2 ;;
      *) die2 "未知参数: $1" ;;
    esac
  done
  case $ticket in
    '') die2 '缺少 --ticket' ;;
  esac
  printf '%s' "$ticket" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
    die2 "ticket 不合口径（^[0-9]{2,}-[a-z0-9-]+\$）: $ticket"
  [ -n "$phase" ] || phase='implementation'
  case $phase in
    implementation) phase_sfx='impl' ;;
    review) phase_sfx='rev' ;;
    commit) phase_sfx='cmt' ;;
    *) die2 "phase 不合枚举（implementation|review|commit）: $phase" ;;
  esac
  [ -n "$mode" ] || mode='delivery'
  case $mode in
    delivery|intake|triage) ;;
    *) die2 "mode 不合枚举（delivery|intake|triage）: $mode" ;;
  esac

  run_id="$(date +%Y%m%d)-t${ticket%%-*}${phase_sfx}"
  printf '%s' "$run_id" | LC_ALL=C grep -Eq '^[0-9]{8}-[a-z0-9]{6,}$' || \
    die1 "生成的 run_id 不合 schema pattern: ${run_id}"

  out_rel="$RUNS_DIR_REL/${run_id}.json"
  out_dir="$repo_root/$RUNS_DIR_REL"
  out_file="$repo_root/$out_rel"
  [ -e "$out_file" ] && die1 "目标文件已存在（new 非幂等防覆盖）: $out_file"

  idx_status=$(get_index_status "$ticket")
  now_ua=$(date +%Y-%m-%dT%H:%M)
  vcs_ref=$(get_vcs_ref)
  fingerprint=$(compute_fingerprint)
  mf_rel=$(compute_mf_rel)
  # 本骨架自身即本次运行的改动之一，显式并入 modified_files（t54 惯例：record 自列）。
  mf_rel=$(printf '%s\n%s\n' "$mf_rel" "$out_rel" | LC_ALL=C sort -u)
  check_path_safety "$mf_rel" 'modified_files'
  mf_json=$(printf '%s\n' "$mf_rel" | absolutize | json_array_body)

  tmp_out=$(mktemp "${t_dir%/}/runrecord.XXXXXX")
  {
    printf '{\n'
    printf '  "run_id": "%s",\n' "$run_id"
    printf '  "mode": "%s",\n' "$mode"
    printf '  "phase": "%s",\n' "$phase"
    printf '  "task": "'"$ISSUES_DIR_REL"'/%s.json（票 %s）",\n' "$ticket" "${ticket%%-*}"
    printf '  "status": {\n'
    printf '    "session": "active",\n'
    printf '    "task": "%s"\n' "$idx_status"
    printf '  },\n'
    printf '  "scope": [\n'
    printf '    "【待填：本次运行 Scope 白名单（自主 agent 委派合同逐字抄录，绝对路径）】"\n'
    printf '  ],\n'
    printf '  "baseline": {\n'
    printf '    "vcs_ref": "%s",\n' "$vcs_ref"
    printf '    "workspace_fingerprint": "%s"\n' "$fingerprint"
    printf '  },\n'
    printf '  "modified_files": %s,\n' "$mf_json"
    printf '  "last_verified": {\n'
    printf '    "command": "【待填：最后一条验证命令原文】",\n'
    printf '    "result": "【待填：真实结果（pass、fail: 原因或 N/A + reason）】",\n'
    printf '    "at": "【待填：验证时间，ISO 8601 日期或日期时间】"\n'
    printf '  },\n'
    printf '  "next_step": "【待填：下一步动作（可判定，不写状态性散文）】",\n'
    printf '  "blocker": "",\n'
    printf '  "network": "unknown",\n'
    printf '  "updated_at": "%s"\n' "$now_ua"
    printf '}\n'
  } > "$tmp_out"

  mkdir -p "$out_dir" || die1 "输出目录创建失败: $out_dir"
  [ -e "$out_file" ] && die1 "目标文件已存在（new 非幂等防覆盖）: $out_file"
  mv -f "$tmp_out" "$out_file" || die1 "骨架写入失败: $out_file"
  tmp_out=''
  printf 'run-record: OK: 已生成 %s（run_id %s，指纹 %s，vcs %s，索引状态 %s；机械字段已填，待填 5 处＝scope/last_verified×3/next_step）\n' \
    "$out_file" "$run_id" "$fingerprint" "$vcs_ref" "$idx_status"
  exit 0
fi
}

rr_cmd_seal() {
# ---- seal：校验并刷新机械字段 ----

rr_file=''
while [ $# -gt 0 ]; do
  case $1 in
    --file) [ $# -ge 2 ] || die2 '--file 缺值'; rr_file=$2; shift 2 ;;
    *) die2 "未知参数: $1" ;;
  esac
done
case $rr_file in
  '') die2 '缺少 --file' ;;
esac
[ -f "$rr_file" ] || die1 "run record 文件不存在: $rr_file"
[ -r "$rr_file" ] || die1 "run record 文件不可读: $rr_file"
command -v python3 >/dev/null 2>&1 || \
  die2 "未找到 python3（seal 解析校验依赖，口径见 $SCRIPTS_README_REL 专节）——无法校验"

if grep -q -F '【待填' "$rr_file"; then
  die1 '存在【待填】残留（scope/last_verified/next_step 未填或未删干净）——fail-closed'
fi

now_ua=$(date +%Y-%m-%dT%H:%M)
vcs_ref=$(get_vcs_ref)
fingerprint=$(compute_fingerprint)
mf_rel=$(compute_mf_rel)
check_path_safety "$mf_rel" 'modified_files'
mf_abs=$(printf '%s\n' "$mf_rel" | absolutize)

# 票 160：使用独立 Python 模块 json-validator.py（run seal 模式）
validator_script="${_self_dir}/json-validator.py"
[ -f "$validator_script" ] || \
  die2 "json-validator.py 不存在（安装闭包缺失）: ${validator_script}——运行时依赖只认安装闭包（脚本同目录与 ../references/），不回退包工作树副本；缺失即安装不到位——请按 Agent Up 包 references/upgrade.md 升级或运行 scripts/install.sh 修补安装后重跑"

RR_UPDATED_AT=$now_ua RR_VCS_REF=$vcs_ref RR_FP=$fingerprint RR_MF=$mf_abs \
  python3 "$validator_script" run seal "$rr_file"
}
