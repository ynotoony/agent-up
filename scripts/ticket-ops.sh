#!/bin/sh
# Input: 子命令与参数（[repo-root] open/take/flip + 选项）与三个票务面数据载体：
#        docs/issues/index.json（票状态真相源，单文件一条目一行，票 33 终裁 T2）、
#        docs/issues/README.md 目录清单状态列（`任务票 <NN>；` 后首个反引号状态 token，
#        人工登记投影，票 37 口径）、docs/changes.jsonl 记录账本（键序
#        date,kind,scope,decision,evidence_ref，一行一事实，禁裸换行）。
# Output: 协调层票务面写入——open＝新票本体 schema 校验＋理由非空断言（票 79，只 open
#         时点生效，存量零回扫）＋校验＋索引新增条目（status=ready）＋README 追加目录
#         清单行＋账本追加行；take/flip＝索引 id 锚点整行替换（status+updated_at）＋README
#         状态 token 替换＋账本追加行；三子命令收尾调 scripts/generate-progress.sh 再生
#         docs/progress-current.md 现役状态投影并 --check 核对。
# Pos: 协调层票务运维单入口脚本（票 41，用户 2026-09-20 裁决 2.1）；行为基线＝
#      development-process §6 零写入三段式第二段与 §12.5 票务脚本承载注记。POSIX sh、
#      零外部依赖（仅 POSIX 标准工具与内建，无 jq；票 79 起 open 本体 schema 校验另用
#      python3 标准库）；fail-closed：校验先于写入，
#      索引排版破坏、README 行缺失或锚点不唯一、账本行不合键序、同 NN 异 slug 撞号
#      （票 77）即停止不写；收尾生成器
#      缺失或 --check 不过即整体失败退出非零，已写部分如实报告。职责边界：只做票务面
#      写入，不执行门禁核对与 Git 提交，不调用 check-gates.sh 与 lane-commit.sh（投影
#      再生调用 generate-progress.sh 不在此限）。

# 用法、数据契约与退出码见同目录 README.md。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh scripts/ticket-ops.sh [repo-root] <command> [options]
参数:
  repo-root      仓库根目录；缺省取脚本所在目录的上一级。
命令:
  open           开票：先过新票本体校验（docs/issues/<id>.json 须已落位并过
                 ticket-record.schema.json 校验＋定级/优先级理由非空断言，票 79；缺本体
                 或校验不过即 fail-closed 零写入），再写索引条目（status=ready）＋
                 issues-README 目录清单追加行＋账本追加行，收尾投影再生＋--check。
                 选项（前四必选）:
                   --id <NN-slug>            票 id（^[0-9]{2,}-[a-z0-9-]+$；须不在索引中且 NN 段未被
                             占用——同 NN 异 slug 撞号拒开，票 77）
                   --complexity <C0-C3>      复杂度档位
                   --title <text>            票标题（用作 README 行功能列文本；不得含
                                             竖线/反引号/换行/制表符）
                   --ledger-line <json>      完整 JSONL 账本行（键序 date,kind,scope,
                                             decision,evidence_ref；紧凑或带空格 JSONL
                                             均可；脚本只校验后追加，不代生成散文；字符
                                             串值不得内嵌引号或反斜杠）
                   [--blocked-by <id,id>]    逗号分隔 blocker id（缺省空数组）
  take           领取：--id --status --ledger-line 三项必选；--status 须为 in_progress。
  flip           收口/状态翻转：--id --status --ledger-line 三项必选；--status 为状态机
                 任意合法值（ready|in_progress|blocked|review_ready|review_pass|
                 review_fail|done|superseded）。
                 take/flip 语义: 索引 id 锚点整行替换（仅改 status/updated_at 两值）→
                 README 状态行锚定 `任务票 <NN>；` 后首个反引号状态 token 替换（行内其余
                 文本不动）→ 账本追加行 → 投影再生＋--check。索引或 README 行缺失、锚点
                 不唯一、账本行非法即停止（fail-closed，写入前预检）。
  -h / --help    打印本用法。
退出码: 0 全部完成；1 fail-closed（校验/锚点/收尾核对不过，已写部分如实报告；open 条目
        已存在即停，非幂等；take/flip 重跑会重复落账本行，核对后处理）；2 用法或环境错误。
USAGE
}

die1() {
  printf 'ticket-ops: FAIL: %s\n' "$1" >&2
  exit 1
}

die2() {
  printf 'ticket-ops: %s\n' "$1" >&2
  exit 2
}

tmp_idx=''
tmp_readme=''
cleanup() {
  if [ -n "${tmp_idx}" ]; then tmp_idx=''; rm -f "${tmp_idx}"; fi
  if [ -n "${tmp_readme}" ]; then tmp_readme=''; rm -f "${tmp_readme}"; fi
}
trap cleanup EXIT HUP INT TERM

[ $# -ge 1 ] || { usage >&2; exit 2; }
case $1 in
  -h|--help) usage; exit 0 ;;
  open|take|flip)
    cmd=$1
    shift
    repo_root=''
    ;;
  *)
    repo_root=$1
    shift
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    case $1 in
      open|take|flip) cmd=$1; shift ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
esac

if [ -z "${repo_root}" ]; then
  repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fi
[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# ---- 选项解析 ----

id=''
complexity=''
title=''
ledger_line=''
blocked_by=''
status=''

while [ $# -gt 0 ]; do
  case $1 in
    --id) [ $# -ge 2 ] || die2 '--id 缺值'; id=$2; shift 2 ;;
    --complexity) [ $# -ge 2 ] || die2 '--complexity 缺值'; complexity=$2; shift 2 ;;
    --title) [ $# -ge 2 ] || die2 '--title 缺值'; title=$2; shift 2 ;;
    --ledger-line) [ $# -ge 2 ] || die2 '--ledger-line 缺值'; ledger_line=$2; shift 2 ;;
    --blocked-by) [ $# -ge 2 ] || die2 '--blocked-by 缺值'; blocked_by=$2; shift 2 ;;
    --status) [ $# -ge 2 ] || die2 '--status 缺值'; status=$2; shift 2 ;;
    *) die2 "未知参数: $1" ;;
  esac
done

# ---- 公共校验（fail-closed，先于任何写入） ----

case ${id} in
  '') die1 "缺少 --id" ;;
esac
printf '%s' "${id}" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
  die1 "id 不合口径（^[0-9]{2,}-[a-z0-9-]+$）: ${id}"
case ${ledger_line} in
  '') die1 "缺少 --ledger-line" ;;
esac
case ${ledger_line} in
  *"${NL}"*|*"${TAB}"*) die1 '账本行含裸换行或制表符（一行一事实，禁裸换行）' ;;
esac
printf '%s' "${ledger_line}" | LC_ALL=C grep -Eq '^\{"date": ?"[0-9]{4}-[0-9]{2}-[0-9]{2}", ?"kind": ?"[^"\\]*", ?"scope": ?"[^"\\]*", ?"decision": ?"[^"\\]*", ?"evidence_ref": ?"[^"\\]*"\}$' || \
  die1 '账本行不合键序或形状（键序 date,kind,scope,decision,evidence_ref；五键齐全、紧凑或带空格 JSONL 均可；字符串值不得内嵌引号或反斜杠）'

case ${cmd} in
  open)
    case ${complexity} in
      '') die1 "缺少 --complexity" ;;
    esac
    printf '%s' "${complexity}" | LC_ALL=C grep -Eq '^C[0-3]$' || \
      die1 "complexity 不合口径（C0-C3）: ${complexity}"
    case ${title} in
      '') die1 "缺少 --title" ;;
    esac
    case ${title} in
      *"|"*|*"\`"*|*"${NL}"*|*"${TAB}"*) die1 'title 不得含竖线、反引号、换行或制表符（README 表格单元安全）' ;;
    esac
    blocked_json=''
    if [ -n "${blocked_by}" ]; then
      rest=${blocked_by}
      while [ -n "${rest}" ]; do
        entry=${rest%%,*}
        case ${rest} in
          *,*) rest=${rest#*,} ;;
          *) rest='' ;;
        esac
        entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        printf '%s' "${entry}" | LC_ALL=C grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
          die1 "blocked_by 条目不合 id 口径: ${entry}"
        if [ -z "${blocked_json}" ]; then
          blocked_json="\"${entry}\""
        else
          blocked_json="${blocked_json}, \"${entry}\""
        fi
      done
    fi
    [ -z "${status}" ] || die2 'open 不得携带 --status（开票状态固定 ready）'
    ;;
  take|flip)
    case ${status} in
      '') die1 "缺少 --status" ;;
    esac
    printf '%s' "${status}" | LC_ALL=C grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || \
      die1 "status 不合状态机取值（裸值）: ${status}"
    if [ "${cmd}" = 'take' ] && [ "${status}" != 'in_progress' ]; then
      die1 "take 的 --status 须为 in_progress（领取语义；其他翻转用 flip）: ${status}"
    fi
    [ -z "${complexity}" ] || die2 'take/flip 不得携带 --complexity'
    [ -z "${title}" ] || die2 'take/flip 不得携带 --title'
    [ -z "${blocked_by}" ] || die2 'take/flip 不得携带 --blocked-by'
    ;;
esac

index_file="${repo_root}/docs/issues/index.json"
readme_file="${repo_root}/docs/issues/README.md"
ledger_file="${repo_root}/docs/changes.jsonl"
# 票 79：open 本体落盘位与 schema 权威（development-process §5.2 开票形态注记）
ticket_file="${repo_root}/docs/issues/${id}.json"
schema_file="${repo_root}/agent-up/references/schemas/ticket-record.schema.json"

[ -f "${index_file}" ] || die1 "索引文件不存在: ${index_file}（票状态真相源缺失，fail-closed）"
[ -r "${index_file}" ] || die1 "索引文件不可读: ${index_file}"
[ -f "${readme_file}" ] || die1 "issues-README 不存在: ${readme_file}"
[ -r "${readme_file}" ] || die1 "issues-README 不可读: ${readme_file}"

nn=${id%%-*}

# ---- 索引与 README 锚点预检（只扫描不写入；任何不合规在写入前停止） ----

index_check() {
  # $1=open|flip；open 要求 id 零命中（可新增），其余要求恰 1 命中（可替换）
  IDX_MODE=$1 IDX_ID=${id} awk '
    BEGIN {
      mode = ENVIRON["IDX_MODE"]
      id = ENVIRON["IDX_ID"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "ticket-ops: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——一条目一行排版被破坏（票 33 终裁 T2）\n", FNR > "/dev/stderr"
        bad = 1
      }
      if (index($0, anchor) > 0) hits++
    }
    END {
      rc = 0
      if (n == 0) { printf "ticket-ops: FAIL: 索引中未找到条目行（\"id\": 锚点零命中）\n" > "/dev/stderr"; rc = 1 }
      if (mode == "open") {
        if (hits != 0) { printf "ticket-ops: FAIL: 索引条目 id 已存在（open 非幂等，命中 %d 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      } else {
        if (hits != 1) { printf "ticket-ops: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      }
      if (bad) rc = 1
      exit rc
    }
  ' "${index_file}"
}

index_nn_check() {
  # open 预检：NN 段唯一性查重（票 77）——账本 renumber-70-72 实录缺口：open 只查全 id
  # （slug 查重），同 NN 异 slug 撞号漏拦，到 take 的 README 锚点预检才兜底。此处开票即拒：
  # 号段被占报明已占完整 id，零写入。NN 提取与 id 口径一致（^[0-9]{2,}-）：仅对合口径的
  # 既有 id 取段比对；畸形既有 id 不产 NN 段、不参与撞号（其本身非法，由 id 口径门与
  # 索引排版门兜底）；来件 id 已过 ^[0-9]{2,}-[a-z0-9-]+$ 门，nn 取值即前导数字段。
  IDX_NN=${nn} IDX_ID=${id} awk '
    BEGIN {
      target = ENVIRON["IDX_NN"]
      tid = ENVIRON["IDX_ID"]
      head = "\"id\": \""
      hlen = length(head)
      m = 0
    }
    index($0, head) > 0 {
      p = index($0, head) + hlen
      rest = substr($0, p)
      q = index(rest, "\"")
      if (q <= 1) next
      eid = substr(rest, 1, q - 1)
      if (eid == tid) next
      if (eid !~ /^[0-9][0-9]+-/) next
      enn = substr(eid, 1, index(eid, "-") - 1)
      if (enn == target) { m++; occ[m] = eid }
    }
    END {
      if (m > 0) {
        list = occ[1]
        for (i = 2; i <= m; i++) list = list ", " occ[i]
        printf "ticket-ops: FAIL: 票号段已被占用（同 NN 异 slug 撞号，open 拒开；先改号或按让号流程处理）: NN %s 已占 id → %s\n", target, list > "/dev/stderr"
        exit 1
      }
      exit 0
    }
  ' "${index_file}"
}

readme_row_check() {
  # open 预检：目录清单表行锚点（^\| `）须至少 1 行
  awk '
    /^\| `/ { hits++ }
    END {
      rc = 0
      if (hits == 0) { printf "ticket-ops: FAIL: issues-README 未找到目录清单表行（^| ` 锚点零命中）\n" > "/dev/stderr"; rc = 1 }
      exit rc
    }
  ' "${readme_file}"
}

readme_token_check() {
  # take/flip 预检：`任务票 <NN>；` 锚点恰 1 行，且其后存在闭合的反引号状态 token
  # 实现注记：位置运算只用 index/substr（同一单位），不用 length——macOS awk 对多字节
  # 字符串 index 回字符位、length 回字节数，混用会错位（票 41 夹具实证）。
  RD_ANCHOR="任务票 ${nn}；" awk '
    BEGIN { anchor = ENVIRON["RD_ANCHOR"] }
    index($0, anchor) > 0 {
      hits++
      p = index($0, anchor)
      s = substr($0, p)
      j = index(s, "`")
      s2 = ""
      if (j > 0) s2 = substr(s, j + 1)
      k = 0
      if (j > 0) k = index(s2, "`")
      if (j == 0 || k == 0) {
        printf "ticket-ops: FAIL: issues-README 第 %d 行锚点后反引号状态 token 缺失或未闭合\n", FNR > "/dev/stderr"
        bad = 1
      }
    }
    END {
      rc = 0
      if (hits != 1) { printf "ticket-ops: FAIL: issues-README 状态行锚点命中 %d 行（须恰 1 行）: %s\n", hits, anchor > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${readme_file}"
}

ticket_body_check() {
  # open 专属预检（票 79）：新票 JSON 本体过 ticket-record.schema.json 校验＋理由非空
  # 断言——required 集（顶层＋allOf if kind=task then）自 schema 文件现场提取，schema 为
  # 唯一权威；非空＝字符串 strip 后非空（blocked_by 须数组，空数组合法＝无依赖）；另断言
  # 本体 id 与 --id 一致（防校验错文件）。只读零写入；任何不过即 exit 1（报文指名缺失项）。
  command -v python3 >/dev/null 2>&1 || \
    die1 'python3 不可用——open 本体 schema 校验无法执行（fail-closed；票 79 起为本体校验依赖）'
  [ -f "${ticket_file}" ] || \
    die1 "新票本体不存在: docs/issues/${id}.json——票 79 起 open 须先落位过 schema 的票 JSON 本体再开票"
  [ -r "${ticket_file}" ] || die1 "新票本体不可读: ${ticket_file}"
  [ -f "${schema_file}" ] || \
    die1 "schema 文件不存在: ${schema_file}（open 本体校验 fail-closed；schema 权威＝Agent Up 包内 references/schemas/ticket-record.schema.json，development-process §5.2）"
  [ -r "${schema_file}" ] || die1 "schema 文件不可读: ${schema_file}"
  python3 - "${ticket_file}" "${schema_file}" "${id}" <<'PYEOF'
import json
import sys

ticket_path, schema_path, want_id = sys.argv[1], sys.argv[2], sys.argv[3]


def fail(msg):
    sys.stderr.write(f"ticket-ops: FAIL: {msg}\n")
    sys.exit(1)


try:
    with open(ticket_path, "r", encoding="utf-8") as fh:
        body = json.load(fh)
except json.JSONDecodeError as exc:
    fail(f"新票本体非合法 JSON: docs/issues/{want_id}.json（第 {exc.lineno} 行 {exc.msg}）")
except OSError as exc:
    fail(f"新票本体不可读: {ticket_path}（{exc.strerror}）")

if not isinstance(body, dict):
    fail(f"新票本体顶层须为 JSON object: {ticket_path}")

try:
    with open(schema_path, "r", encoding="utf-8") as fh:
        schema = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    fail(f"schema 文件不可读或非合法 JSON: {schema_path}（{exc}）")

if not isinstance(schema, dict) or not isinstance(schema.get("required"), list):
    fail(f"schema 形状不合预期（缺顶层 required 数组）: {schema_path}——fail-closed")

problems = []

body_id = body.get("id")
if body_id != want_id:
    problems.append(f"本体 id 与 open --id 不一致（本体 {body_id!r} != --id {want_id!r}）")

kind_props = (schema.get("properties") or {}).get("kind") or {}
kind_enum = kind_props.get("enum") if isinstance(kind_props, dict) else None
body_kind = body.get("kind")
if isinstance(kind_enum, list) and body_kind is not None and body_kind not in kind_enum:
    problems.append(f"kind 不在 schema 枚举内: {body_kind!r}")


def check_required(names, scope):
    # 非空口径：字符串 strip 后非空（空白串按空拒，票 79 只断言非空不做内容判断）
    for name in names:
        if name not in body:
            problems.append(f"{scope}缺少 {name}")
            continue
        value = body[name]
        if name == "blocked_by":
            if not isinstance(value, list):
                problems.append(f"{scope}{name} 须为数组（无依赖为空数组）")
            continue
        if not isinstance(value, str) or not value.strip():
            problems.append(f"{scope}{name} 为空或非字符串（非空断言，票 79）")


check_required(schema["required"], "顶层 ")

task_required = []
for sub in schema.get("allOf") or []:
    if not isinstance(sub, dict):
        continue
    cond_props = (sub.get("if") or {}).get("properties") or {}
    if isinstance(cond_props.get("kind"), dict) and cond_props["kind"].get("const") == "task":
        then = sub.get("then") or {}
        if isinstance(then.get("required"), list):
            task_required.extend(then["required"])
if body_kind == "task":
    check_required(task_required, "task ")

if problems:
    fail("新票本体 schema 校验未过（" + schema_path + "）：" + "；".join(problems))
sys.exit(0)
PYEOF
}

# 生成器定位（收尾投影再生必需；同目录优先，PATH 回退；缺失即预检停止）
gen_cmd=''
if [ -f "${script_dir}/generate-progress.sh" ] && [ -r "${script_dir}/generate-progress.sh" ]; then
  gen_cmd="${script_dir}/generate-progress.sh"
  printf 'ticket-ops: 生成器定位: 同目录 %s\n' "${gen_cmd}"
else
  _rest=${PATH:-}
  while [ -n "${_rest}" ]; do
    _dir=${_rest%%:*}
    case ${_rest} in
      *:*) _rest=${_rest#*:} ;;
      *) _rest='' ;;
    esac
    [ -n "${_dir}" ] || continue
    if [ -f "${_dir}/generate-progress.sh" ] && [ -r "${_dir}/generate-progress.sh" ]; then
      gen_cmd="${_dir}/generate-progress.sh"
      break
    fi
  done
  if [ -n "${gen_cmd}" ]; then
    printf 'ticket-ops: 生成器定位: PATH %s\n' "${gen_cmd}"
  else
    die1 '投影生成器 generate-progress.sh 不可用（同目录与 PATH 均未找到）——预检停止：按 development-process §12.5 派生载体独占写，票务面写入必须伴随投影再生；将生成器落位到本脚本同目录（scripts/）或 PATH 后重跑'
  fi
fi

if [ "${cmd}" = 'open' ]; then
  ticket_body_check || die1 "新票本体校验未通过: docs/issues/${id}.json——未产生任何写入"
  index_check open || die1 "索引预检未通过: docs/issues/index.json（${id}）——未产生任何写入"
  index_nn_check || die1 "NN 段预检未通过: docs/issues/index.json——未产生任何写入"
  readme_row_check || die1 "issues-README 预检未通过: docs/issues/README.md——未产生任何写入"
else
  index_check flip || die1 "索引预检未通过: docs/issues/index.json（${id}）——未产生任何写入"
  readme_token_check || die1 "issues-README 预检未通过: docs/issues/README.md（任务票 ${nn}）——未产生任何写入"
fi

# ---- 写入（索引 → README → 账本 → 投影再生＋--check） ----

t_dir=${TMPDIR:-/tmp}
now_ua=$(date +%Y-%m-%dT%H:%M)
today=$(date +%F)

if [ "${cmd}" = 'open' ]; then
  new_entry="    {\"id\": \"${id}\", \"status\": \"ready\", \"complexity\": \"${complexity}\", \"blocked_by\": [${blocked_json}], \"updated_at\": \"${now_ua}\"}"
  tmp_idx=$(mktemp "${t_dir%/}/tix-idx.XXXXXX")
  IDX_NEW=${new_entry} awk '
    BEGIN { new = ENVIRON["IDX_NEW"] }
    {
      lines[++n] = $0
      if (index($0, "\"id\": \"") > 0) last_entry = n
      if ($0 ~ /^  ]$/) found = 1
    }
    END {
      rc = 0
      if (!found) { printf "ticket-ops: FAIL: 索引未找到条目数组收口行（^  ]$）——拒绝插入\n" > "/dev/stderr"; rc = 1 }
      if (last_entry == 0) { printf "ticket-ops: FAIL: 索引未找到条目行——拒绝插入\n" > "/dev/stderr"; rc = 1 }
      if (rc == 1) exit rc
      for (i = 1; i <= n; i++) {
        if (i == last_entry) {
          line = lines[i]
          if (line !~ /,[[:space:]]*$/) sub(/$/, ",", line)
          print line
          print new
        } else {
          print lines[i]
        }
      }
    }
  ' "${index_file}" > "${tmp_idx}" || {
    rm -f "${tmp_idx}"; tmp_idx=''
    die1 "索引插入未通过校验: docs/issues/index.json——未产生任何写入"
  }
  mv "${tmp_idx}" "${index_file}"
  tmp_idx=''
  printf 'ticket-ops: 索引新增条目: docs/issues/index.json（%s → ready，updated_at %s）\n' "${id}" "${now_ua}"

  row="| \`${id}.json\` | 任务票 ${nn}；\`ready\`（${today} 开票） | ${title} |"
  tmp_readme=$(mktemp "${t_dir%/}/tix-readme.XXXXXX")
  RD_ROW=${row} awk '
    BEGIN { row = ENVIRON["RD_ROW"] }
    { lines[++n] = $0; if ($0 ~ /^\| `/) last = n }
    END {
      if (last == 0) { printf "ticket-ops: FAIL: issues-README 目录清单表行锚点零命中——拒绝插入\n" > "/dev/stderr"; exit 1 }
      for (i = 1; i <= n; i++) { print lines[i]; if (i == last) print row }
    }
  ' "${readme_file}" > "${tmp_readme}" || {
    rm -f "${tmp_readme}"; tmp_readme=''
    die1 "issues-README 行插入未通过校验——索引已写入（${id}），README 未写入"
  }
  mv "${tmp_readme}" "${readme_file}"
  tmp_readme=''
  printf 'ticket-ops: README 追加目录清单行: docs/issues/README.md（任务票 %s；`ready`）\n' "${nn}"
else
  tmp_idx=$(mktemp "${t_dir%/}/tix-idx.XXXXXX")
  IDX_ID=${id} IDX_STATUS=${status} IDX_UA=${now_ua} awk '
    BEGIN {
      id = ENVIRON["IDX_ID"]; nstatus = ENVIRON["IDX_STATUS"]; nua = ENVIRON["IDX_UA"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "ticket-ops: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——拒绝单写\n", FNR > "/dev/stderr"
        bad = 1
        print
        next
      }
      if (index($0, anchor) > 0) {
        hits++
        line = $0
        sub(/"status": "[^"]*"/, "\"status\": \"" nstatus "\"", line)
        sub(/"updated_at": "[^"]*"/, "\"updated_at\": \"" nua "\"", line)
        print line
        next
      }
      print
      next
    }
    { print }
    END {
      rc = 0
      if (n == 0) { printf "ticket-ops: FAIL: 索引中未找到条目行\n" > "/dev/stderr"; rc = 1 }
      if (hits != 1) { printf "ticket-ops: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${index_file}" > "${tmp_idx}" || {
    rm -f "${tmp_idx}"; tmp_idx=''
    die1 "索引单写未通过校验: docs/issues/index.json（${id}）——未产生任何写入"
  }
  mv "${tmp_idx}" "${index_file}"
  tmp_idx=''
  printf 'ticket-ops: 索引单写: docs/issues/index.json（%s → %s，updated_at %s）\n' "${id}" "${status}" "${now_ua}"

  tmp_readme=$(mktemp "${t_dir%/}/tix-readme.XXXXXX")
  RD_ANCHOR="任务票 ${nn}；" RD_STATUS=${status} awk '
    BEGIN { anchor = ENVIRON["RD_ANCHOR"]; nstatus = ENVIRON["RD_STATUS"] }
    index($0, anchor) > 0 {
      hits++
      p = index($0, anchor)
      s = substr($0, p)
      j = index(s, "`")
      s2 = ""
      if (j > 0) s2 = substr(s, j + 1)
      k = 0
      if (j > 0) k = index(s2, "`")
      if (j == 0 || k == 0) {
        printf "ticket-ops: FAIL: issues-README 第 %d 行锚点后反引号状态 token 缺失或未闭合——拒绝改写\n", FNR > "/dev/stderr"
        bad = 1
        print
        next
      }
      print substr($0, 1, p - 1) substr(s, 1, j) nstatus substr(s2, k)
      next
    }
    { print }
    END {
      rc = 0
      if (hits != 1) { printf "ticket-ops: FAIL: issues-README 状态行锚点命中 %d 行（须恰 1 行）: %s\n", hits, anchor > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${readme_file}" > "${tmp_readme}" || {
    rm -f "${tmp_readme}"; tmp_readme=''
    die1 "README 状态 token 替换未通过校验——索引已单写（${id} → ${status}），README 未写入"
  }
  mv "${tmp_readme}" "${readme_file}"
  tmp_readme=''
  printf 'ticket-ops: README 状态列替换: docs/issues/README.md（任务票 %s → `%s`，行内其余文本不动）\n' "${nn}" "${status}"
fi

if [ ! -f "${ledger_file}" ]; then
  mkdir -p "${repo_root}/docs"
  : > "${ledger_file}" || die1 "账本懒创建失败: ${ledger_file}——已写部分如实报告：索引与 README 均已写入，账本与投影未落地"
fi
[ -w "${ledger_file}" ] || die1 "账本不可写: ${ledger_file}——已写部分如实报告：索引与 README 均已写入，账本与投影未落地"
ledger_lineno=$(( $(wc -l < "${ledger_file}" | tr -d ' ') + 1 ))
printf '%s\n' "${ledger_line}" >> "${ledger_file}" || die1 "账本落行失败: ${ledger_file}——已写部分如实报告：索引与 README 均已写入，账本与投影未落地"
printf 'ticket-ops: 账本落行: docs/changes.jsonl（第 %d 行）\n' "${ledger_lineno}"

sh "${gen_cmd}" "${repo_root}" || die1 "投影再生失败（生成器 exit 非 0）——已写部分如实报告：索引与 README 与账本（${ledger_lineno} 行）均已写入、投影未刷新；按生成器报因处理后核对重跑"
sh "${gen_cmd}" --check "${repo_root}" || die1 "投影一致性核对未过（--check exit 非 0）——已写部分如实报告：索引与 README 与账本（${ledger_lineno} 行）均已写入；投影与索引不一致，核对后重跑"
printf 'ticket-ops: 投影已再生并核对: docs/progress-current.md\n'

printf 'ticket-ops: PASS（%s 完成：索引、issues-README、账本、投影 --check 全部落地）\n' "${cmd}"
