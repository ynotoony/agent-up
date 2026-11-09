#!/bin/sh
# Input: facts/requirements/tickets/index.json（票状态索引真相源，单文件一条目一行，票 33 终裁 T2）
# projection-version: 2（投影列形态＋票表生成块；机制版本注记）
#        与可选参数：--check／--check-readme 开关、仓库根目录（缺省按脚本落位分派推导，
#        agent-up/scripts/ 两层或 rules/implementation/scripts/ 三层布局可正确推导，
#        其余落位兜底上两级；check-stale-claims 的严格两布局口径见其专节）。
# Output: 两处索引派生投影（同一生成器独占写，agent 不手写）：
#         ①facts/requirements/tickets/progress-current.md 现役状态投影——Derived 四标注头部
#         （generated_from、生成时间、覆盖范围、失效条件）＋每票一行
#         `| id | status | checkpoint_ref | updated_at |` 状态表，按 id 升序；
#         ②facts/requirements/tickets/README.md 的票表生成块——标记
#         `<!-- tickets-readme: generated from=... -->` 与 `<!-- /tickets-readme -->` 之间整表
#         由索引派生（行集合与顺序取索引；状态列取索引；名字/开票日期/功能列复用现行块行原文，
#         索引新增条目按票本体 title/created_at 派生），块外逐字节不动。
#         --check 模式为 progress-current 的 dry-run；--check-readme 为票表生成块的只读
#         新鲜度断言（块缺失但目录清单表在场＝未迁移，exit 1；README 缺失＝跳过 exit 0）。
#         两类核对不一致即 exit 1，不落盘。
# Pos: 本仓记录层投影生成器（票 33 草案 §5.1.4 生成规则 / 票 35 落位；票 115 波⑤路径随 rules/facts 布局翻值）；
#      生成器独占写 facts/requirements/tickets/progress-current.md 与
#      facts/requirements/tickets/README.md 的票表生成块（派生载体独占写），agent 不手写。
#      POSIX sh；条目字段解析由唯一 JSON 引擎 json-validator.py 承载（原 json-helpers.sh awk 行解析
#      retired，本件零内嵌 JSON 解析副本；引擎同目录分发，缺件 fail-closed 指名）；
#      fail-closed：索引缺失、不可读或条目行不合预期即停止报告，不写投影。投影与索引不一致时以索引为准。

# 用法与退出码见同目录 README.md。

# ---- 路径常量区（票 113 波④：值翻 rules/facts 新形态，映射见 rules-facts-layout-spec §2 R13/R15/R19）----
issues_index_rel='facts/requirements/tickets/index.json'
progress_current_rel='facts/requirements/tickets/progress-current.md'
gen_script_rel='rules/implementation/scripts/generate-progress.sh'

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（die 兜底副本清零，统一 source common-helpers.sh；同目录分发）
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'generate-progress: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

# 唯一 JSON 引擎定位（同目录分发，缺件 fail-closed 指名）
_engine_file=$(dirname "$0")/json-validator.py
if [ ! -f "$_engine_file" ]; then
  printf 'generate-progress: FAIL: 唯一 JSON 引擎缺失: %s（json-validator.py 与本件同目录分发）\n' "$_engine_file" >&2
  exit 2
fi

usage() {
  cat <<'USAGE'
用法: sh rules/implementation/scripts/generate-progress.sh [--check|--check-readme] [repo-root]
参数:
  --check         dry-run 模式：与既有 facts/requirements/tickets/progress-current.md 比对（规范化
                  generated_at 行后逐字节比对），一致 exit 0，不一致 exit 1；不写任何文件。
  --check-readme  dry-run 模式：核对 README 票表生成块是否等于索引派生结果（逐行比对）；
                  不一致或块缺失但目录清单表在场（未迁移）exit 1；README 缺失或既无块亦无表 exit 0。
  repo-root      仓库根目录；缺省按脚本落位分派推导（agent-up/scripts/ 与
                  rules/implementation/scripts/ 两布局可正确推导，其余落位兜底上两级，
                 亦可显式传入）。
  -h / --help    打印本用法。
退出码: 0 生成成功或核对一致；1 核对不一致（投影 stale／生成块漂移或未迁移）；
        2 用法错误、索引文件缺失/不可读或条目行不合预期（fail-closed，不写投影）。
USAGE
}

check_mode=0
readme_check_mode=0
repo_root=''
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --check) check_mode=1 ;;
    --check-readme) readme_check_mode=1 ;;
    --*) die2 "未知参数: $arg" ;;
    -*) usage >&2; exit 2 ;;
    *) if [ -n "$repo_root" ]; then die2 "多余参数: ${arg}（只接受一个仓库根）"; fi; repo_root=$arg ;;
  esac
done
if [ "$check_mode" -eq 1 ] && [ "$readme_check_mode" -eq 1 ]; then
  die2 '--check 与 --check-readme 互斥（一个模式一类投影）'
fi

# 缺省根＝落位分派推导（票 206/227：仓库根推导统一经 resolve_repo_root）
if [ -n "$repo_root" ]; then
  _rr=$(resolve_repo_root "$repo_root") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
if [ -z "$_rr" ]; then
  if [ -n "$repo_root" ]; then
    die2 "仓库根不可用: $repo_root"
  fi
  die2 '仓库根推导失败（脚本落位非两布局，请显式传入仓库根参数，用法见 -h）'
fi
repo_root=$_rr

index_file="$repo_root/$issues_index_rel"
out_file="$repo_root/$progress_current_rel"

[ -f "$index_file" ] || die2 "索引文件不存在: ${index_file}（现役状态投影真相源缺失，fail-closed 不生成；若脚本落位非上述两布局，请显式传入仓库根参数，用法见 -h）"
[ -r "$index_file" ] || die2 "索引文件不可读: $index_file"

# 条目提取依赖一条目一行排版（T2）：行含 `"id": "<数字开头 id>"` 锚点；无命中即排版或内容不合预期，fail-closed。
entries=$(grep '"id": "[0-9]' "$index_file") || {
  printf 'generate-progress: FAIL: %s\n' '索引中未找到条目行（"id": 数字锚点零命中）——确认一条目一行排版' >&2
  exit 2
}

NL='
'
TAB=$(printf '\t')

# 每条目行投影一行状态表；字段解析经唯一 JSON 引擎 json fields（TAB 分列，一行一返回）；
# 必备字段（id/status/updated_at）值均非空（schema minLength），故空值即判缺失；
# checkpoint_ref 可选（省略投影为空单元格）。同一循环按索引顺序积累票表派生用 (id,status)。
rows=''
entries_tsv=''
while IFS= read -r entry_line; do
  # 一条目一行排版行尾带数组分隔逗号（除末条目），剥除后交引擎解析（引擎输入须为合法 JSON）
  _entry_json=${entry_line%,}
  _fields=$(printf '%s\n' "$_entry_json" | python3 "$_engine_file" json fields - id status updated_at checkpoint_ref) || {
    printf 'generate-progress: FAIL: %s\n' "条目行不合 JSON 或缺字段: $entry_line" >&2
    exit 2
  }
  IFS="$TAB" read -r id status updated_at checkpoint_ref <<EOF
$_fields
EOF

  if [ -z "$id" ] || [ -z "$status" ] || [ -z "$updated_at" ]; then
    die2 "条目行缺必备字段或不合预期: $entry_line"
  fi

  if [ -n "$rows" ]; then
    rows="${rows}
"
  fi
  rows="${rows}| ${id} | ${status} | ${checkpoint_ref} | ${updated_at} |"
  entries_tsv="${entries_tsv}${id}${TAB}${status}${NL}"
done <<EOF
$entries
EOF

t_dir=${TMPDIR:-/tmp}
tmp_out=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
tmp_a=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
tmp_b=$(mktemp "${t_dir%/}/genprogress.XXXXXX")
cleanup() {
  rm -f "$tmp_out" "$tmp_a" "$tmp_b"
  rm -f "${tmp_block:-}" "${tmp_cur:-}" "${tmp_new:-}"
  return 0
}
trap cleanup EXIT HUP INT TERM

generated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

{
  printf '<!-- generated_from: %s + %s -->\n' "$issues_index_rel" "$gen_script_rel"
  printf '<!-- generated_at: %s -->\n' "$generated_at"
  printf '<!-- coverage: %s 登记的全部票，每票一行，按 id 升序 -->\n' "$issues_index_rel"
  printf '<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 %s 不一致时以索引为准 -->\n' "$issues_index_rel"
  printf '\n'
  printf '# 现役状态投影（Derived）\n'
  printf '\n'
  printf '| id | status | checkpoint_ref | updated_at |\n'
  printf '| --- | --- | --- | --- |\n'
  printf '%s\n' "$rows" | LC_ALL=C sort
} > "$tmp_out"


# ---- 票表生成块（索引派生；实现同目录模块 progress-readme.sh，票 290 拆分）----
_br_lib=$(dirname "$0")/progress-readme.sh
[ -f "$_br_lib" ] || {
  printf 'generate-progress: FAIL: 同目录模块缺失: %s（progress-readme.sh 与本件同目录分发）\n' "$_br_lib" >&2
  exit 2
}
# shellcheck source=agent-up/scripts/progress-readme.sh  # 路径动态计算，显式声明基线位置
. "$_br_lib"


if [ "$check_mode" -eq 1 ]; then
  # --check：规范化两侧 generated_at 行后逐字节比对（该行随生成时间漂移，不参与一致性判定）。
  [ -f "$out_file" ] || die1 "投影文件不存在: ${out_file}（先运行生成器落盘）"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$tmp_out" > "$tmp_a"
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$out_file" > "$tmp_b"
  if cmp -s "$tmp_a" "$tmp_b"; then
    printf 'generate-progress: CHECK: PASS — 投影与索引一致: %s\n' "$out_file"
    exit 0
  fi
  printf 'generate-progress: FAIL: 投影与索引不一致（stale）: %s\n' "$out_file" >&2
  diff -u "$tmp_b" "$tmp_a" >&2 || true
  exit 1
fi

if [ "$readme_check_mode" -eq 1 ]; then
  readme_check
  exit $?
fi

mv -f "$tmp_out" "$out_file"
printf 'generate-progress: OK: 已生成 %s\n' "$out_file"
readme_sync
