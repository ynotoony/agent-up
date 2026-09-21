#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与行式提交合同文件
#        （lane / ticket / whitelist / message / verify / verdict_quote / verdict_at / flips）。
# Output: 门禁核对、白名单产品提交、记录写入（user-review 道追加 User Review Checkpoint；
#         micro 道向 docs/agent/micro.jsonl 懒创建落 JSON 行）、索引单写与状态投影
#         （flips 索引条目口径：单写 docs/issues/index.json → 机械回写受影响票正文
#         **Status:** 行 → 调 generate-progress.sh 再生 docs/progress-current.md 投影并
#         --check 核对）与两段提交的逐步输出，两段提交 ID、各自文件清单与翻转清单分列回报。
# Pos: 分级交付道快道收尾脚本（REQ-20260904-011 / 票 26；票 37 行为基线改造）；行为基线 =
#      development-process 模板 §12.5 道脚本承载注记（单写索引 → 生成正文 Status 行 →
#      生成投影，票 34 定稿）与 R-RC-003（先产品提交后纯记录提交）；POSIX sh、零外部依赖、
#      fail-closed（门禁不过、合同格式不合预期、索引/生成器缺失即停止报告，不写不补；
#      预检先于产品提交，停止时零提交零写入）。脚本权限边界 = 提交合同白名单，不执行
#      白名单外任何写入；docs/issues/README.md 与 docs/progress.md 状态行不属本脚本写入面
#      （README 状态列为人工登记投影，票 35/37 口径）。

# 用法、合同行格式与输出格式见同目录 README.md。

set -eu
set -f  # 关闭文件名展开：脚本不依赖 glob

NL='
'
TAB=$(printf '\t')

usage() {
  cat <<'USAGE'
用法: sh lane-commit.sh [repo-root] <contract-file>
参数:
  repo-root      仓库根目录；缺省取当前目录所在 Git 仓库顶层。
  contract-file  行式提交合同文件（临时输入，不落仓库），行格式（均以行首列为准）:
                   lane: user-review|micro            （micro 道预检，票 58：白名单 ≤3 条目
                                                       且改动集零新建（??）零删除（D），
                                                       违者 exit 1；user-review 不受限）
                   ticket: <仓库根相对路径>          （user-review 必填；micro 不得出现）
                   whitelist: <逗号分隔相对路径>      （必填，单项或逗号多项）
                   message: <产品提交说明>            （必填）
                   verify: <验证命令>                 （一行一条，可多行）
                   verdict_quote: <用户裁决原文>      （user-review 必填；micro 不得出现）
                   verdict_at: <裁决时间>             （user-review 必填；micro 不得出现）
                   flips: <file>:<field>:<value>      （行翻转：一行一条，可多行；field
                                                       不得为 status 或 index）
                   flips: docs/issues/index.json:index:<id>:<status>:<updated_at>
                                                     （索引条目翻转：user-review 道专用，
                                                       至多一条；id 须与 ticket 票文件名去
                                                       .md 一致；status 为状态机裸值；
                                                       updated_at 允许冒号，取行尾余段）
                 # 注释（行首 #）与空行忽略；其余行判合同格式错误（exit 1）。
                 行翻转语义: 锚点为字面子串，须恰命中一行，整行换成 value。
                 索引条目翻转语义（单写机制，票 37）: 单写 docs/issues/index.json（"id" 锚点
                 整行替换，仅改 status/updated_at 两值，其余字段原样保留；依赖一条目一行
                 排版）→ 机械回写 ticket 票正文 **Status:** 行（投影打印件 `value`）→ 调
                 generate-progress.sh 再生 docs/progress-current.md 并 --check 核对（生成器
                 同目录优先、PATH 回退；索引或生成器缺失＝预检停止，fail-closed）。
  -h / --help    打印本用法。
退出码: 0 全部完成；1 门禁不过或合同 fail-closed 条件（停止时未产生任何写入或提交）；
        2 用法或环境错误。
USAGE
}

die1() {
  printf 'lane-commit: FAIL: %s\n' "$1" >&2
  exit 1
}

die2() {
  printf 'lane-commit: %s\n' "$1" >&2
  exit 2
}

tmp_gate=''
tmp_flip=''
tmp_idx=''
cleanup() {
  if [ -n "${tmp_gate}" ]; then rm -f "${tmp_gate}"; fi
  if [ -n "${tmp_flip}" ]; then tmp_flip=''; rm -f "${tmp_flip}"; fi
  if [ -n "${tmp_idx}" ]; then tmp_idx=''; rm -f "${tmp_idx}"; fi
}
trap cleanup EXIT HUP INT TERM

case $# in
  2)
    repo_root=$1
    contract=$2
    ;;
  1)
    case $1 in
      -h|--help) usage; exit 0 ;;
    esac
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die2 '当前目录不在 Git 仓库内，且未提供 repo-root'
    contract=$1
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[ -d "${repo_root}" ] || die2 "仓库根不存在: ${repo_root}"
[ -r "${contract}" ] || die2 "合同文件不可读: ${contract}"
git -C "${repo_root}" rev-parse --git-dir >/dev/null 2>&1 || die2 "仓库根不是 Git 仓库: ${repo_root}"
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -r "${script_dir}/check-gates.sh" ] || die2 '同目录 check-gates.sh 缺失，无法执行门禁核对'

IFS=${NL}

# ---- 解析合同 ----

lane_seen=0
lane=''
ticket_seen=0
ticket=''
message_seen=0
message=''
vq_seen=0
verdict_quote=''
va_seen=0
verdict_at=''
whitelist=''
verifies=''
flips=''
n_index_flip=0

while IFS= read -r line || [ -n "${line}" ]; do
  case ${line} in
    ''|'#'*) continue ;;
    *:*)
      key=${line%%:*}
      val=${line#*:}
      val=$(printf '%s' "${val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      case ${key} in
        lane)
          [ "${lane_seen}" -eq 0 ] || die1 'lane 行重复'
          lane_seen=1
          lane=${val}
          ;;
        ticket)
          [ "${ticket_seen}" -eq 0 ] || die1 'ticket 行重复'
          ticket_seen=1
          ticket=${val}
          ;;
        message)
          [ "${message_seen}" -eq 0 ] || die1 'message 行重复'
          message_seen=1
          message=${val}
          ;;
        verdict_quote)
          [ "${vq_seen}" -eq 0 ] || die1 'verdict_quote 行重复'
          vq_seen=1
          verdict_quote=${val}
          ;;
        verdict_at)
          [ "${va_seen}" -eq 0 ] || die1 'verdict_at 行重复'
          va_seen=1
          verdict_at=${val}
          ;;
        whitelist)
          rest=${val}
          while [ -n "${rest}" ]; do
            entry=${rest%%,*}
            case ${rest} in
              *,*) rest=${rest#*,} ;;
              *) rest='' ;;
            esac
            entry=$(printf '%s' "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${entry}" ] || die1 'whitelist 含空条目'
            whitelist="${whitelist}${entry}${NL}"
          done
          ;;
        verify)
          [ -n "${val}" ] || die1 'verify 行缺少命令'
          verifies="${verifies}${val}${NL}"
          ;;
        flips)
          [ -n "${val}" ] || die1 'flips 行缺少内容'
          case ${val} in
            *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
          esac
          f_file=${val%%:*}
          f_rest=${val#*:}
          case ${f_rest} in
            *:*) f_field=${f_rest%%:*} ; f_rest2=${f_rest#*:} ;;
            *) die1 "flips 行须为 file:field:value 三段: ${val}" ;;
          esac
          f_file=$(printf '%s' "${f_file}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          f_field=$(printf '%s' "${f_field}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          [ -n "${f_file}" ] || die1 "flips 行文件名为空: ${val}"
          [ -n "${f_field}" ] || die1 "flips 行 field 为空: ${val}"
          if [ "${f_field}" = 'index' ]; then
            # 索引条目翻转: <file>:index:<id>:<status>:<updated_at>（updated_at 取行尾余段，允许冒号）
            f_id=${f_rest2%%:*}
            f_rest3=${f_rest2#*:}
            case ${f_rest3} in
              "${f_rest2}") die1 "索引条目翻转须为 file:index:<id>:<status>:<updated_at> 五段: ${val}" ;;
            esac
            case ${f_rest3} in
              *:*) : ;;
              *) die1 "索引条目翻转缺 updated_at 段: ${val}" ;;
            esac
            f_status=${f_rest3%%:*}
            f_updated=${f_rest3#*:}
            case ${f_id} in
              *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
            esac
            [ "${f_file}" = 'docs/issues/index.json' ] || \
              die1 "索引条目翻转目标须为 docs/issues/index.json: ${f_file}"
            [ -n "${f_id}" ] || die1 "索引条目翻转 id 为空: ${val}"
            [ -n "${f_status}" ] || die1 "索引条目翻转 status 为空: ${val}"
            [ -n "${f_updated}" ] || die1 "索引条目翻转 updated_at 为空: ${val}"
            flips="${flips}${f_file}${TAB}index${TAB}${f_id}${TAB}${f_status}${TAB}${f_updated}${NL}"
            n_index_flip=$((n_index_flip + 1))
          else
            f_val=${f_rest2}
            f_val=$(printf '%s' "${f_val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${f_val}" ] || die1 "flips 行 value 为空: ${val}"
            case ${f_val} in
              *"${TAB}"*) die1 "flips 行各段不得含制表符: ${val}" ;;
            esac
            flips="${flips}${f_file}${TAB}${f_field}${TAB}${f_val}${NL}"
          fi
          ;;
        *)
          die1 "无法识别的合同行: ${line}"
          ;;
      esac
      ;;
    *)
      die1 "无法识别的合同行: ${line}"
      ;;
  esac
done < "${contract}"

# ---- 合同语义校验（fail-closed，先于任何写入） ----

[ "${lane_seen}" -eq 1 ] || die1 '合同缺少 lane 行'
[ "${message_seen}" -eq 1 ] && [ -n "${message}" ] || die1 '合同缺少 message 行'
[ -n "${whitelist}" ] || die1 '合同缺少 whitelist 行或白名单为空'

case ${lane} in
  user-review)
    { [ "${ticket_seen}" -eq 1 ] && [ -n "${ticket}" ]; } || die1 'user-review 道缺少 ticket 行'
    { [ "${vq_seen}" -eq 1 ] && [ -n "${verdict_quote}" ]; } || die1 'user-review 道缺少 verdict_quote 行'
    { [ "${va_seen}" -eq 1 ] && [ -n "${verdict_at}" ]; } || die1 'user-review 道缺少 verdict_at 行'
    [ -f "${repo_root}/${ticket}" ] || die1 "user-review 道票文件不存在: ${ticket}"
    ;;
  micro)
    [ "${ticket_seen}" -eq 0 ] || die1 'micro 道免票，不得携带 ticket 行'
    [ "${vq_seen}" -eq 0 ] || die1 'micro 道不得携带 verdict_quote 行'
    [ "${va_seen}" -eq 0 ] || die1 'micro 道不得携带 verdict_at 行'
    ;;
  *)
    die1 "lane 取值须为 user-review 或 micro: ${lane}"
    ;;
esac

if [ "${n_index_flip}" -gt 0 ]; then
  [ "${lane}" = 'user-review' ] || die1 '索引条目翻转仅限 user-review 道（micro 道免票，无票状态可翻）'
  [ "${n_index_flip}" -eq 1 ] || die1 '索引条目翻转至多一条（单写口径，票 37）'
  t_stem=${ticket%.md}
  t_stem=${t_stem##*/}
fi

# ---- 微道预检（票 58：微道只修不建不删；user-review 道不受此限，行为零变化）----
# 两断言：①白名单条目 ≤3（超出属非微任务，改走 user-review 道开票收尾）；
# ②git status 改动集零新建（??）零删除（D）——微任务道准入即机械可验小改，新增/删除
# 文件超出口径；stop 时零写入零提交（本段先于翻转预检与门禁，任何 die1 均安全）。

if [ "${lane}" = 'micro' ]; then
  n_wl=0
  for wentry in ${whitelist}; do
    n_wl=$((n_wl + 1))
  done
  [ "${n_wl}" -le 3 ] || die1 "微道白名单条目 ${n_wl} 个（须 ≤3，票 58）——超出属非微任务，改走 user-review 道开票收尾"
  st_out=$(git -C "${repo_root}" status --porcelain)
  while IFS= read -r stline; do
    [ -n "${stline}" ] || continue
    case ${stline} in
      '??'*) die1 "微道改动集含未跟踪新增（??）: ${stline#?? }——微道零新建（票 58），先入库或移出改动集" ;;
      'D'*|?'D'*) die1 "微道改动集含删除（D）: ${stline}——微道零删除（票 58）" ;;
    esac
  done <<EOF_ST
${st_out}
EOF_ST
fi

n_flip=0
record_files=''
for flip in ${flips}; do
  n_flip=$((n_flip + 1))
  f_file=${flip%%"${TAB}"*}
  f_rest=${flip#*"${TAB}"}
  f_field=${f_rest%%"${TAB}"*}
  [ -f "${repo_root}/${f_file}" ] || {
    if [ "${f_field}" = 'index' ]; then
      die1 "索引文件缺失: ${f_file}（票状态真相源，单写不可执行）——先由对应阶段执行体建立索引（issue-index.schema），或改走非快道收尾"
    fi
    die1 "翻转目标文件不存在: ${f_file}"
  }
  fneedle="${NL}${f_file}${NL}"
  case "${NL}${record_files}" in
    *"${fneedle}"*) : ;;
    *) record_files="${record_files}${f_file}${NL}" ;;
  esac
done

# ---- 翻转锚点与索引/生成器预检（只扫描不写入；任何不合规在写入前停止） ----

flip_run() {
  # $1=仓库根相对路径 $2=输出目标路径(check 传 /dev/null) $3=模式(body|line)
  # $4=锚点(line 模式字面子串) $5=替换值；锚点不合规 exit 1
  MODE=$3 ANCHOR=$4 VALUE=$5 awk '
    BEGIN {
      MODE = ENVIRON["MODE"]
      anchor = ENVIRON["ANCHOR"]
      value = ENVIRON["VALUE"]
    }
    MODE == "body" && $0 ~ /^\*\*Status:\*\*/ {
      body++
      print "**Status:** `" value "`"
      next
    }
    MODE == "line" && index($0, anchor) > 0 {
      hits++
      print value
      next
    }
    { print }
    END {
      rc = 0
      if (MODE == "body") {
        if (body != 1) { printf "lane-commit: FAIL: %s 正文 Status 行命中 %d 行（须恰 1 行）\n", FILENAME, body > "/dev/stderr"; rc = 1 }
      } else {
        if (hits != 1) { printf "lane-commit: FAIL: %s 翻转锚点命中 %d 行（须恰 1 行）\n", FILENAME, hits > "/dev/stderr"; rc = 1 }
      }
      exit rc
    }
  ' "${repo_root}/$1" > "$2"
}

index_precheck() {
  # $1=索引条目 id；核对一条目一行排版与 id 锚点唯一命中（只读）
  _id=$1
  IDX_ID=${_id} awk '
    BEGIN {
      id = ENVIRON["IDX_ID"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "lane-commit: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——一条目一行排版被破坏（票 33 终裁 T2）\n", FNR > "/dev/stderr"
        bad = 1
      }
      if (index($0, anchor) > 0) hits++
    }
    END {
      rc = 0
      if (n == 0) { printf "lane-commit: FAIL: 索引中未找到条目行（\"id\": 锚点零命中）\n" > "/dev/stderr"; rc = 1 }
      if (hits != 1) { printf "lane-commit: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${repo_root}/docs/issues/index.json"
}

index_write() {
  # $1=id $2=新 status $3=新 updated_at；单写一行（id 锚点整行替换），写 tmp 由调用方 mv
  IDX_ID=$1 IDX_STATUS=$2 IDX_UA=$3 awk '
    BEGIN {
      id = ENVIRON["IDX_ID"]; nstatus = ENVIRON["IDX_STATUS"]; nua = ENVIRON["IDX_UA"]
      anchor = "\"id\": \"" id "\""
    }
    index($0, "\"id\": \"") > 0 {
      n++
      if ($0 !~ /"status": "/ || $0 !~ /"updated_at": "/) {
        printf "lane-commit: FAIL: 索引第 %d 行条目行缺同行的 status/updated_at 字段——拒绝单写\n", FNR > "/dev/stderr"
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
      if (n == 0) { printf "lane-commit: FAIL: 索引中未找到条目行\n" > "/dev/stderr"; rc = 1 }
      if (hits != 1) { printf "lane-commit: FAIL: 索引条目锚点命中 %d 行（须恰 1 行）: %s\n", hits, id > "/dev/stderr"; rc = 1 }
      if (bad) rc = 1
      exit rc
    }
  ' "${repo_root}/docs/issues/index.json"
}

# 生成器定位（索引翻转时必需；同目录优先，PATH 回退；缺失即预检停止）
# PATH 回退手动迭代而非 command -v：落位脚本不要求可执行位（恒经 sh 调用），
# command -v 对不可执行文件不报告。
gen_cmd=''
if [ "${n_index_flip}" -gt 0 ]; then
  if [ -f "${script_dir}/generate-progress.sh" ] && [ -r "${script_dir}/generate-progress.sh" ]; then
    gen_cmd="${script_dir}/generate-progress.sh"
    printf 'lane-commit: 生成器定位: 同目录 %s\n' "${gen_cmd}"
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
      printf 'lane-commit: 生成器定位: PATH %s\n' "${gen_cmd}"
    else
      die1 '投影生成器 generate-progress.sh 不可用（同目录与 PATH 均未找到）——收尾预检停止：按 development-process §12.5 派生载体独占写，索引翻转必须伴随投影再生；将生成器落位到本脚本同目录（scripts/）或 PATH 后重跑'
    fi
  fi
fi

for flip in ${flips}; do
  f_field=$(printf '%s' "${flip}" | cut -f 2)
  f_file=${flip%%"${TAB}"*}
  if [ "${f_field}" = 'index' ]; then
    f_id=$(printf '%s' "${flip}" | cut -f 3)
    f_status=$(printf '%s' "${flip}" | cut -f 4)
    f_updated=$(printf '%s' "${flip}" | cut -f 5)
    printf '%s' "${f_id}" | grep -Eq '^[0-9]{2,}-[a-z0-9-]+$' || \
      die1 "索引条目 id 不合 issue-index schema 口径（^[0-9]{2,}-[a-z0-9-]+$）: ${f_id}"
    printf '%s' "${f_status}" | grep -Eq '^(ready|in_progress|blocked|review_ready|review_pass|review_fail|done|superseded)$' || \
      die1 "索引条目 status 不合状态机取值（裸值，不带冒号后缀）: ${f_status}"
    printf '%s' "${f_updated}" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$' || \
      die1 "索引条目 updated_at 不合 ISO 8601 口径（YYYY-MM-DDTHH:MM[:SS]）: ${f_updated}"
    [ "${f_id}" = "${t_stem}" ] || \
      die1 "索引条目 id 与 ticket 票文件不符: ${f_id} ≠ ${t_stem}（正文 Status 回写目标由 ticket 行决定）"
    index_precheck "${f_id}" || die1 "索引预检未通过: docs/issues/index.json（${f_id}）——单写已取消，未产生任何写入或提交"
    flip_run "${ticket}" /dev/null body '' "${f_status}" || \
      die1 "正文 Status 回写预检未通过: ${ticket}"
  elif [ "${f_field}" = 'status' ]; then
    die1 "flips 行 field=status 已退役：票状态经索引条目翻转承载（flips: docs/issues/index.json:index:<id>:<status>:<updated_at>，票 37）"
  else
    f_rest=${flip#*"${TAB}"}
    f_val=${f_rest#*"${TAB}"}
    flip_run "${f_file}" /dev/null line "${f_field}" "${f_val}" || \
      die1 "翻转锚点预校验未通过: ${f_file}（${f_field}）"
  fi
done

# ---- 门禁核对（调用同目录 check-gates.sh，只读） ----

t_dir=${TMPDIR:-/tmp}
tmp_gate=$(mktemp "${t_dir%/}/lane-gates.XXXXXX")
{
  printf 'whitelist: %s\n' "$(printf '%s' "${whitelist}" | paste -sd, -)"
  for vcmd in ${verifies}; do
    printf 'verify: %s\n' "${vcmd}"
  done
} > "${tmp_gate}"

grc=0
sh "${script_dir}/check-gates.sh" "${repo_root}" "${tmp_gate}" || grc=$?
if [ "${grc}" -eq 1 ]; then
  die1 '门禁核对未通过（见上方 check-gates 输出），未产生任何写入或提交'
fi
if [ "${grc}" -ne 0 ]; then
  die2 "check-gates.sh 用法或环境错误（exit ${grc}）"
fi

# ---- 产品提交（白名单内暂存，防御性核对后提交） ----

for wpath in ${whitelist}; do
  git -C "${repo_root}" add -- "${wpath}" || die1 "git add 失败: ${wpath}"
done

staged=$(git -c core.quotePath=false -C "${repo_root}" diff --cached --name-only)
[ -n "${staged}" ] || die1 '白名单内无实际改动，无提交可创建'
for spath in ${staged}; do
  sneedle="${NL}${spath}${NL}"
  case "${NL}${whitelist}" in
    *"${sneedle}"*) : ;;
    *) die1 "防御性核对失败：暂存内容越出白名单: ${spath}" ;;
  esac
done

git -C "${repo_root}" commit -m "${message}" || die1 '产品提交创建失败'
cid1=$(git -C "${repo_root}" rev-parse HEAD)
subject1=$(git -C "${repo_root}" log -1 --format=%s "${cid1}")
diffsum1=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-status -r "${cid1}" | tr '\t' ' ' | paste -sd, -)

# ---- 记录写入（索引单写 → 正文 Status 回写 → 行翻转 → Checkpoint / 微账本 → 投影再生） ----

date_today=$(date +%F)

for flip in ${flips}; do
  f_field=$(printf '%s' "${flip}" | cut -f 2)
  f_file=${flip%%"${TAB}"*}
  if [ "${f_field}" = 'index' ]; then
    f_id=$(printf '%s' "${flip}" | cut -f 3)
    f_status=$(printf '%s' "${flip}" | cut -f 4)
    f_updated=$(printf '%s' "${flip}" | cut -f 5)
    tmp_idx=$(mktemp "${t_dir%/}/lane-idx.XXXXXX")
    index_write "${f_id}" "${f_status}" "${f_updated}" > "${tmp_idx}" || {
      rm -f "${tmp_idx}"
      tmp_idx=''
      die1 "索引单写未通过校验: docs/issues/index.json（${f_id}）——收尾停止：产品提交 ${cid1} 已创建、记录提交未创建；核对索引排版后重跑（幂等，已翻条目再跑无副作用）"
    }
    mv "${tmp_idx}" "${repo_root}/docs/issues/index.json"
    tmp_idx=''
    printf 'lane-commit: 索引单写: docs/issues/index.json（%s → %s，updated_at %s）\n' "${f_id}" "${f_status}" "${f_updated}"
    tmp_flip=$(mktemp "${t_dir%/}/lane-flip.XXXXXX")
    flip_run "${ticket}" "${tmp_flip}" body '' "${f_status}" || {
      rm -f "${tmp_flip}"
      tmp_flip=''
      die1 "正文 Status 回写未通过锚点校验: ${ticket}——收尾停止：产品提交 ${cid1} 已创建、索引已单写、记录提交未创建"
    }
    mv "${tmp_flip}" "${repo_root}/${ticket}"
    tmp_flip=''
    printf 'lane-commit: 正文 Status 回写（投影打印件）: %s → **Status:** `%s`\n' "${ticket}" "${f_status}"
    proj_file='docs/progress-current.md'
    fneedle="${NL}${proj_file}${NL}"
    case "${NL}${record_files}" in
      *"${fneedle}"*) : ;;
      *) record_files="${record_files}${proj_file}${NL}" ;;
    esac
  else
    f_rest=${flip#*"${TAB}"}
    f_val=${f_rest#*"${TAB}"}
    tmp_flip=$(mktemp "${t_dir%/}/lane-flip.XXXXXX")
    flip_run "${f_file}" "${tmp_flip}" line "${f_field}" "${f_val}" || {
      rm -f "${tmp_flip}"
      tmp_flip=''
      die1 "翻转写入未通过锚点校验: ${f_file}（${f_field}）"
    }
    mv "${tmp_flip}" "${repo_root}/${f_file}"
    tmp_flip=''
    printf 'lane-commit: 翻转: %s:%s:%s\n' "${f_file}" "${f_field}" "${f_val}"
  fi
done

if [ "${lane}" = 'user-review' ]; then
  {
    printf '\n## User Review Checkpoint（%s，lane-commit.sh）\n\n' "${date_today}"
    printf -- '- 裁决原文：%s\n' "${verdict_quote}"
    printf -- '- 裁决时间：%s\n' "${verdict_at}"
    printf -- '- 提交：%s %s\n' "${cid1}" "${subject1}"
    printf -- '- diff 摘要：%s\n' "${diffsum1}"
  } >> "${repo_root}/${ticket}" || die1 "User Review Checkpoint 追加失败: ${ticket}"
  tneedle="${NL}${ticket}${NL}"
  case "${NL}${record_files}" in
    *"${tneedle}"*) : ;;
    *) record_files="${record_files}${ticket}${NL}" ;;
  esac
  printf 'lane-commit: User Review Checkpoint 已追加: %s\n' "${ticket}"
fi

if [ "${lane}" = 'micro' ]; then
  micro_file='docs/agent/micro.jsonl'
  mkdir -p "${repo_root}/docs/agent"
  if [ ! -f "${repo_root}/${micro_file}" ]; then
    : > "${repo_root}/${micro_file}" || die1 '微账本懒创建失败'
  fi
  [ -w "${repo_root}/${micro_file}" ] || die1 "微账本不可写: ${micro_file}"
  wl_joined=$(printf '%s' "${whitelist}" | paste -sd, -)
  wl_json=$(printf '%s' "${wl_joined}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  n_verify=$(printf '%s' "${verifies}" | grep -c . || true)
  printf '{"date": "%s", "lane": "micro", "whitelist": "%s", "gates": "PASS", "verify": %d, "commit": "%s"}\n' \
    "${date_today}" "${wl_json}" "${n_verify}" "${cid1}" >> "${repo_root}/${micro_file}" || die1 '微账本落行失败'
  record_files="${record_files}${micro_file}${NL}"
  printf 'lane-commit: 微账本已落行: %s\n' "${micro_file}"
fi

if [ -n "${gen_cmd}" ]; then
  sh "${gen_cmd}" "${repo_root}" || die1 "投影再生失败（生成器 exit 非 0）——收尾停止：产品提交 ${cid1} 已创建、索引与正文 Status 已更新、投影未刷新、记录提交未创建；手动运行生成器（sh ${gen_cmd} ${repo_root}）核对报因，修复后重跑收尾（幂等）"
  sh "${gen_cmd}" --check "${repo_root}" || die1 "投影一致性核对未过（--check exit 非 0）——收尾停止：投影与索引不一致或不可读，记录提交未创建；按生成器输出指路修复后重跑收尾（幂等）"
  printf 'lane-commit: 投影已再生并核对: docs/progress-current.md\n'
fi

# ---- 记录提交（两段式第二段，R-RC-003） ----

for rpath in ${record_files}; do
  git -C "${repo_root}" add -- "${rpath}" || die1 "git add 失败（记录提交）: ${rpath}"
done

git -C "${repo_root}" commit -m "chore(lane): 记录翻转 — ${message}" || die1 '记录提交创建失败'
cid2=$(git -C "${repo_root}" rev-parse HEAD)

# ---- 回报 ----

c1_files=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-only -r "${cid1}" | paste -sd, -)
c2_files=$(git -C "${repo_root}" diff-tree --root --no-commit-id --name-only -r "${cid2}" | paste -sd, -)
printf 'lane-commit: 产品提交 %s\n' "${cid1}"
printf 'lane-commit: 产品文件: %s\n' "${c1_files}"
printf 'lane-commit: 记录提交 %s\n' "${cid2}"
printf 'lane-commit: 记录文件: %s\n' "${c2_files}"
printf 'lane-commit: PASS（两段式完成：门禁 PASS、索引单写 %d 处、翻转 %d 项、投影已核对、记录已落盘）\n' "${n_index_flip}" "${n_flip}"
