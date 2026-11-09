#!/bin/sh
# Input: check-stale-claims.sh 同进程 source 载入（不单独执行）；上下文变量与共享辅助由
#        引擎在分派前准备（repo_root、script_dir、mode、stale_count/warn_count、_engine、
#        DP_* 配置字段、emit_stale/emit_warn、first_grep_line/trim_git_url/TAB 等）。
# Output: 单一断言组核对——经 emit_stale/emit_warn 输出 STALE/WARN 行并计数（S4 另有
#         STALE-prone 行与 NOTE 行）；只判定，不打印汇总与判定行，不设置退出码。
# Pos: 易腐断言扫描器断言组分片 S4（计数漂移哨兵）；注册表行＝stale-claims-checks.rules，
#      interface 函数名＝check_s4（S4 另含引擎在分派前调用的解析前置钩子）。新增一条断言组
#      ＝加一件分片＋注册表一行，引擎零改动。
# shellcheck disable=SC2034,SC2154  # 依赖引擎上下文变量（同进程单 shell），单文件视野误报

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
