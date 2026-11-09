#!/bin/sh
# Input: 子命令与选项（new/seal/stats）与机械字段事实源三类：facts/requirements/tickets/index.json（票状态
#        真相源，status.task 现值）、Git 只读命令（rev-parse HEAD 全哈希、status 改动
#        清单）、工作区文件面（fp-v1 指纹，R-DP-015 算法，定稿描述权威＝agent-up/
#        references/schemas/run-record.schema.json workspace_fingerprint 字段）。stats
#        的输入＝facts/requirements/runs/*.json 全量只读扫描（票 71）。
# Output: new＝facts/requirements/runs/<YYYYMMDD>-t<NN><phase 后缀>.json 十三字段骨架——机械字段
#         （run_id/mode/phase/task/status/updated_at/vcs_ref/指纹/modified_files）自动填，
#         内容字段（scope/last_verified/next_step）留【待填：…】由执行体填，blocker 缺省
#         空串、network 缺省 unknown；seal＝校验（python3 json.load 可解析、十四必填字段
#         齐含子键——票 70 usage 入必备、全文零【待填】残留、run_id/mode/status.session/
#         status.task/workspace_fingerprint/updated_at 逐项对照 schema pattern/enum、
#         usage 必备且五子字段齐——票 70：缺 usage 或缺任一子字段 fail-closed 报明缺项，
#         两段式落齐须在 seal 前完成）全过后按当前仓库状态重算重写四个机械字段
#         （updated_at/vcs_ref/指纹/modified_files；重算指纹与旧值不同属正常刷新不算
#         fail）；stats＝只读聚合 facts/requirements/runs/*.json 的 usage 用量报表（票 71）：
#         总卡数、带 usage 卡数与覆盖率、tokens_total/requests/duration_seconds 三项
#         合计、缺 usage 卡 run_id 清单与口径说明行；零写入，坏 JSON 卡或 usage 形状
#         坏值 fail-closed 报文件名（exit 1）。
# Pos: run record 生成器（票 55，用户 2026-09-21 改判：直接自动生成骨架与机械字段，而非
#      事后检查）；十三字段口径权威＝agent-up/references/schemas/run-record.schema.json
#      （脚本内嵌对照其定稿的 pattern/enum，不运行时读 schema，schema 变化须同步本脚本）；
#      公开包采纳归后续导出票。POSIX sh、fail-closed：校验先于写入，任一不过 exit 1
#      零残留；SHA-256 按 sha256sum/shasum/cksum -a sha256/openssl 序探测、stat BSD/GNU
#      双方言探测（先例 agent-up/scripts/generate-module-map.sh）。依赖口径：python3 仅
#      用于 seal 的解析校验与机械字段重写（本仓恒有 python3；new 子命令零解释器依赖）；
#      其余仅 POSIX 标准工具与 Git 只读子命令。

# 用法、检查项清单与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

# Source common helper functions（票 227 F5：die 兜底副本清零，统一 source common-helpers.sh）
_self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || {
  printf 'run-record: FAIL: 脚本目录不可解析\n' >&2
  exit 2
}
# shellcheck disable=SC1090,SC1091  # 子命令模块路径由脚本目录推导（动态源，静态视野不可跟随）
. "${_self_dir}/run-record-cmds.sh"
_helper_script=$(dirname "$0")/common-helpers.sh
if [ -f "$_helper_script" ]; then
  # shellcheck source=agent-up/scripts/common-helpers.sh  # 路径动态计算，显式声明基线位置
  . "$_helper_script"
else
  printf 'run-record: FAIL: 共享库缺失: %s\n' "$_helper_script" >&2
  exit 2
fi

NL='
'

# ---- 路径常量区（票 111 波②建立、票 113 波④翻值：治理路径字面量收敛于此；值＝rules/facts 新形态 R15/R25/R19；SCRIPTS_README_REL 包内自引用保持现值）----
RUNS_DIR_REL='facts/requirements/runs'
ISSUES_DIR_REL='facts/requirements/tickets'
SCRIPTS_README_REL='scripts/README.md'

usage() {
  cat <<'USAGE'
用法: sh scripts/run-record.sh [repo-root] <command> [options]
参数:
  repo-root      仓库根目录；缺省取脚本所在目录的上一级。
命令:
  new            生成 run record 骨架: facts/requirements/runs/<YYYYMMDD>-t<NN><后缀>.json
                 （后缀: implementation=impl / review=rev / commit=cmt；run_id＝文件名
                 去 .json，沿现役惯例如 20260921-t54impl）。机械字段自动填:
                 updated_at（当前 ISO 分钟）、baseline.vcs_ref（git rev-parse HEAD 全
                 哈希）、baseline.workspace_fingerprint（fp-v1: 排除 .git/node_modules/
                 dist/build/coverage/__pycache__/.venv/facts-requirements-runs，相对路径字典序，
                 每行 路径<TAB>字节<TAB>mtime 纪元秒，SHA-256 前 16 位）、modified_files
                 （git status --porcelain -uall 改动清单＋本骨架自身，未跟踪目录展开到
                 文件，绝对路径）、status.task（自
                 facts/requirements/tickets/index.json 读该票现值）、status.session=active、task（票
                 路径）、mode/phase（取参数，缺省 delivery/implementation）。内容字段
                 scope/last_verified/next_step 留【待填：…】由执行体填；blocker 缺省
                 空串、network 缺省 unknown（不算待填）。目标文件已存在即 exit 1（非幂
                 等防覆盖，撞日多卡由调用方换 phase 或后缀，脚本不静默改名）。选项:
                   --ticket <NN-slug>   票 id（^[0-9]{2,}-[a-z0-9-]+$，必选；须已在
                                        facts/requirements/tickets/index.json 登记恰 1 行且状态在 run
                                        record status.task 枚举内）
                   [--phase implementation|review|commit]
                   [--mode delivery|intake|triage]
  seal           校验并收口既有 run record: --file <path> 必选（路径按调用方给出值取，
                 建议绝对路径）。校验①python3 json.load 可解析；②十四必填字段齐（含
                 status/baseline/last_verified 子键；usage 收口必备——票 70）；③全文零
                 【待填】残留；④run_id/mode/status.session/status.task/
                 workspace_fingerprint/updated_at 逐项对照 schema pattern/enum；⑤usage
                 必备（票 70 收口硬门禁）：缺 usage 或缺任一五子字段（tokens_total/
                 requests/duration_seconds/source/at）即 fail-closed 并报明缺项，两段式
                 落齐（执行体先落 duration_seconds/source/at，协调层回填 tokens_total/
                 requests）须在 seal 前完成；未定义子字段拒绝、三个数值字段须 ≥0 整数、
                 source ∈ executor|coordinator|mixed、at 同 updated_at 分钟精度
                 pattern。全过后按当前仓库状态重算重写四个机械字段（updated_at/vcs_ref/
                 指纹/modified_files；重算指纹与文件内旧值不同属正常刷新不算 fail），
                 缩进 2 写回。任一校验不过 exit 1（文件保持原字节）。
  stats          只读聚合 facts/requirements/runs/*.json 的 usage 用量报表（票 71）：输出总卡
                 数、带 usage 卡数与覆盖率、tokens_total/requests/duration_seconds 三
                 项合计、缺 usage 卡 run_id 清单与口径说明行。零写入零参数；坏 JSON
                 卡或 usage 形状坏值（非对象/非 ≥0 整数）fail-closed 报文件名 exit 1
                 （不静默跳过）；runs 目录或 .json 卡缺失 exit 1。缺 usage 卡不计入
                 合计、计数并排输出防误读为全量口径。
  -h / --help    打印本用法。
退出码: 0 全部完成；1 fail-closed（校验不过、待填残留、票索引缺失/无该票条目/锚点不唯一/
        状态出枚举、new 目标文件已存在、seal 文件缺失或不可读、指纹输入异常）；2 用法或
        环境错误（参数形态、未知子命令/选项、仓库根不存在或非 Git 仓库、无 HEAD、
        SHA-256/stat/python3 工具缺失）。
USAGE
}

# ---- 临时文件与清理（全部落 TMPDIR，仓库内只写目标 run record 本件）----

t_dir=${TMPDIR:-/tmp}
tmp_fp=''
tmp_mf=''
tmp_out=''
probe_file=''
cleanup() {
  rm -f "$tmp_fp" "$tmp_mf" "$tmp_out" "$probe_file"
}
trap cleanup EXIT HUP INT TERM

# ---- 子命令与仓库根解析 ----

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
  new|seal|stats)
    cmd=$1
    shift
    repo_root=''
    ;;
  *)
    repo_root=$1
    shift
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    case $1 in
      new|seal|stats) cmd=$1; shift ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
esac

# 仓库根推导统一经 resolve_repo_root（票 227 F4：显式参数 > 落位分派两布局）
if [ -n "$repo_root" ]; then
  _rr=$(resolve_repo_root "$repo_root") || _rr=''
else
  _rr=$(resolve_repo_root) || _rr=''
fi
[ -n "$_rr" ] || die2 '仓库根推导失败（脚本落位非两布局，请显式传入仓库根参数）'
repo_root=$_rr
[ -d "$repo_root" ] || die2 "仓库根不存在: $repo_root"
git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || \
  die2 "仓库根不是 Git 仓库: $repo_root"

# ---- stats 子命令（票 71）：只读聚合 usage 用量报表，零写入，坏卡 fail-closed ----
# 票 160：使用独立 Python 模块 json-validator.py（run stats 模式）

if [ "$cmd" = stats ]; then
  rr_cmd_stats
fi

# ---- 工具探测：SHA-256 与 stat 方言（缺失即 fail-closed，exit 2）----

sha_cmd=''
if command -v sha256sum >/dev/null 2>&1; then
  sha_cmd='sha256sum'
elif command -v shasum >/dev/null 2>&1; then
  sha_cmd='shasum -a 256'
elif command -v cksum >/dev/null 2>&1 && cksum -a sha256 </dev/null >/dev/null 2>&1; then
  sha_cmd='cksum -a sha256'
elif command -v openssl >/dev/null 2>&1; then
  sha_cmd='openssl dgst -sha256'
fi
[ -n "$sha_cmd" ] || die2 '未找到可用 SHA-256 工具（sha256sum/shasum/cksum -a sha256/openssl 任一）——无法计算 fp-v1 指纹'

probe_file=$(mktemp "${t_dir%/}/runrecord.XXXXXX")
printf 'probe' > "$probe_file"
p_bsd=$(stat -f '%z %m' "$probe_file" 2>/dev/null | grep -E '^[0-9]+ [0-9]+$') || p_bsd=''
p_gnu=$(stat -c '%s %Y' "$probe_file" 2>/dev/null | grep -E '^[0-9]+ [0-9]+$') || p_gnu=''
rm -f "$probe_file"
probe_file=''
if [ -n "$p_bsd" ]; then
  stat_flag='-f'
  stat_fmt='%z %m'
elif [ -n "$p_gnu" ]; then
  stat_flag='-c'
  stat_fmt='%s %Y'
else
  die2 'stat 工具不可用或输出不合预期（BSD/GNU 双方言探测均失败）——无法取文件字节与 mtime'
fi

# ---- 共享计算：fp-v1 指纹与 modified_files 清单（new/seal 同口径）----

compute_fingerprint() {
  # fp-v1（R-DP-015；算法描述权威＝run-record.schema.json workspace_fingerprint 字段）：
  # 全文件排除 .git/node_modules/dist/build/coverage/__pycache__/.venv 与 facts/requirements/runs
  # （运行记录自身不参与指纹，避免自引用漂移），相对路径字典序，每行
  # 路径<TAB>字节数<TAB>mtime 纪元秒，SHA-256 十六进制前 16 位记 fp-v1:<hex16>。
  tmp_fp=$(mktemp "${t_dir%/}/runrecord.XXXXXX")
  : > "$tmp_fp"
  fp_list=$(cd "$repo_root" && LC_ALL=C find . \
    \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
       -o -name __pycache__ -o -name .venv -o -path "./$RUNS_DIR_REL" \) -prune -o \
    -type f -print \
    | sed 's|^\./||' | LC_ALL=C sort) || fp_list=''
  [ -n "$fp_list" ] || die1 '工作区文件清单为空——无法计算 fp-v1 指纹'
  if printf '%s\n' "$fp_list" | grep -Eq '[[:cntrl:]]'; then
    die1 '工作区文件路径含制表符或其他控制字符（无法承载指纹行格式）——fail-closed'
  fi
  old_ifs=$IFS
  IFS=$NL
  for rel in $fp_list; do
    meta=$(stat "$stat_flag" "$stat_fmt" "$repo_root/$rel") || die1 "stat 取文件元数据失败: $rel"
    printf '%s' "$meta" | grep -Eq '^[0-9]+ [0-9]+$' || die1 "stat 输出不合预期（非字节/秒对）: $rel"
    bytes=${meta%% *}
    mtime=${meta##* }
    printf '%s\t%s\t%s\n' "$rel" "$bytes" "$mtime" >> "$tmp_fp"
  done
  IFS=$old_ifs
  fp_hex=$(LC_ALL=C ${sha_cmd} < "$tmp_fp" | sed -n 's/.*\([0-9a-f]\{64\}\).*/\1/p' | cut -c1-16)
  [ -n "$fp_hex" ] || die1 'SHA-256 计算失败（工具输出未含 64 位十六进制）'
  rm -f "$tmp_fp"
  tmp_fp=''
  printf 'fp-v1:%s' "$fp_hex"
}

compute_mf_rel() {
  # git status 改动清单（porcelain v1 -uall：未跟踪目录展开到文件；rename 取新路径），
  # 仓库根相对路径排序去重。
  tmp_mf=$(mktemp "${t_dir%/}/runrecord.XXXXXX")
  git -C "$repo_root" -c core.quotepath=false status --porcelain -uall > "$tmp_mf" 2>/dev/null || \
    die2 'git status 执行失败（Git 环境异常）'
  sed -e 's/^...//' -e 's/.* -> //' "$tmp_mf" | LC_ALL=C sort -u
  rm -f "$tmp_mf"
  tmp_mf=''
}

absolutize() {
  # stdin: 每行一个相对路径；stdout: 仓库根前缀绝对路径（一行一路径）。
  while IFS= read -r rel_line; do
    [ -n "$rel_line" ] || continue
    printf '%s/%s\n' "$repo_root" "$rel_line"
  done
}

check_path_safety() {
  # $1=清单（多行字符串）$2=用途说明：拒绝控制字符与 git 引号转义路径（无法安全承载）。
  [ -n "$1" ] || return 0
  if printf '%s\n' "$1" | grep -Eq '[[:cntrl:]]'; then
    die1 "$2 清单路径含制表符或其他控制字符——fail-closed"
  fi
  if printf '%s\n' "$1" | grep -q '^"'; then
    die1 "$2 清单含 git 引号转义路径（引号/反斜杠等特殊字符）——fail-closed，请人工处理"
  fi
}

json_array_body() {
  # stdin: 每行一个字符串；stdout: JSON 数组字面量（缩进 2 风格，转义 \\ 与 "；
  # 括号由 awk 自身产出，不依赖命令替换保留尾换行）。
  LC_ALL=C awk '
    BEGIN { printf "[" }
    { s = $0; gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
      if (n++) printf ","
      printf "\n    \"%s\"", s }
    END { if (n > 0) printf "\n  "; printf "]" }'
}

get_index_status() {
  # $1=票 id：自 facts/requirements/tickets/index.json 锚点行读 status 现值（真相源；fail-closed 校验）。
  idx_file="$repo_root/$ISSUES_DIR_REL/index.json"
  [ -f "$idx_file" ] || die1 "票索引文件不存在: $idx_file（票状态真相源缺失）"
  [ -r "$idx_file" ] || die1 "票索引文件不可读: $idx_file"
  idx_hits=$(grep -c -F "\"id\": \"${1}\"" "$idx_file" || true)
  [ "$idx_hits" -eq 1 ] || die1 "票索引锚点命中 ${idx_hits} 行（须恰 1 行）: ${1}"
  idx_line=$(grep -F "\"id\": \"${1}\"" "$idx_file")
  idx_status=$(printf '%s' "$idx_line" | sed -n 's/.*"status": "\([^"]*\)".*/\1/p')
  [ -n "$idx_status" ] || die1 "索引条目缺同行 status 值: ${1}"
  printf '%s' "$idx_status" | LC_ALL=C grep -Eq '^(ready|in_progress|blocked(:[ a-zA-Z0-9-]+)?|review_ready|review_pass|review_fail|done)$' || \
    die1 "索引状态 ${idx_status} 不在 run record status.task 枚举内（如 superseded）——fail-closed，请人工确认"
  printf '%s' "$idx_status"
}

get_vcs_ref() {
  vcs_ref_val=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null) || \
    die2 'git rev-parse HEAD 失败（无提交或 Git 环境异常）——无法填 baseline.vcs_ref'
  printf '%s' "$vcs_ref_val"
}

rr_cmd_new "$@"

# ---- seal：校验并刷新机械字段 ----
: "$SCRIPTS_README_REL"  # 子命令模块消费面（跨件共享）
rr_cmd_seal "$@"
