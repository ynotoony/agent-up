#!/bin/sh
# Input: 仓库根目录（缺省取当前目录所在 Git 仓库顶层）与行式提交合同文件
#        （lane / ticket / whitelist / message / verify / verdict_quote / verdict_at / flips）。
# Output: 门禁核对、白名单产品提交、记录写入（user-review 道追加 User Review Checkpoint；
#         micro 道向 docs/agent/micro.md 懒创建落行）、状态翻转与记录提交的逐步输出，
#         两段提交 ID、各自文件清单与翻转清单分列回报。
# Pos: 分级交付道快道收尾脚本（REQ-20260904-011 / 票 26）；行为基线 = development-process
#      模板 §12.5 道脚本承载注记与 agents-commit 模板 R-RC-003（先产品提交后纯记录提交）；
#      POSIX sh、零外部依赖、fail-closed（门禁不过或合同格式不合预期即停止报告，不写不补）。
#      脚本权限边界 = 提交合同白名单，不执行白名单外任何写入。

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
                   lane: user-review|micro
                   ticket: <仓库根相对路径>          （user-review 必填；micro 不得出现）
                   whitelist: <逗号分隔相对路径>      （必填，单项或逗号多项）
                   message: <产品提交说明>            （必填）
                   verify: <验证命令>                 （一行一条，可多行）
                   verdict_quote: <用户裁决原文>      （user-review 必填；micro 不得出现）
                   verdict_at: <裁决时间>             （user-review 必填；micro 不得出现）
                   flips: <file>:<field>:<value>      （一行一条，可多行）
                 # 注释（行首 #）与空行忽略；其余行判合同格式错误（exit 1）。
                 flips 语义: field 为 status 时对目标文件做状态双写（frontmatter status 行与
                 正文 **Status:** 行，两锚点各须恰命中一行，正文翻转为 **Status:** `<value>`）；
                 否则为整行替换（锚点为字面子串，须恰命中一行，整行换成 value）。
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
cleanup() {
  if [ -n "${tmp_gate}" ]; then rm -f "${tmp_gate}"; fi
  if [ -n "${tmp_flip}" ]; then rm -f "${tmp_flip}"; fi
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
            *:*) f_field=${f_rest%%:*} ; f_val=${f_rest#*:} ;;
            *) die1 "flips 行须为 file:field:value 三段: ${val}" ;;
          esac
          f_file=$(printf '%s' "${f_file}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          f_field=$(printf '%s' "${f_field}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          f_val=$(printf '%s' "${f_val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          [ -n "${f_file}" ] || die1 "flips 行文件名为空: ${val}"
          [ -n "${f_field}" ] || die1 "flips 行 field 为空: ${val}"
          [ -n "${f_val}" ] || die1 "flips 行 value 为空: ${val}"
          flips="${flips}${f_file}${TAB}${f_field}${TAB}${f_val}${NL}"
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

n_flip=0
record_files=''
for flip in ${flips}; do
  n_flip=$((n_flip + 1))
  f_file=${flip%%"${TAB}"*}
  [ -f "${repo_root}/${f_file}" ] || die1 "翻转目标文件不存在: ${f_file}"
  fneedle="${NL}${f_file}${NL}"
  case "${NL}${record_files}" in
    *"${fneedle}"*) : ;;
    *) record_files="${record_files}${f_file}${NL}" ;;
  esac
done

# ---- 翻转锚点预校验（只扫描不写入；任何不合规在写入前停止） ----

flip_run() {
  # $1=仓库根相对路径 $2=输出目标路径(check 传 /dev/null) $3=模式(status|line)
  # $4=锚点 $5=替换值；锚点不合规 exit 1
  MODE=$3 ANCHOR=$4 VALUE=$5 awk '
    BEGIN {
      MODE = ENVIRON["MODE"]
      anchor = ENVIRON["ANCHOR"]
      value = ENVIRON["VALUE"]
    }
    FNR == 1 && $0 == "---" { infm = 1; open_seen = 1; print; next }
    infm && $0 == "---" { infm = 0; done_fm = 1; print; next }
    infm && $0 ~ /^status:/ {
      fm++
      if (MODE == "status") print "status: " value; else print
      next
    }
    infm { print; next }
    $0 ~ /^\*\*Status:\*\*/ {
      body++
      if (MODE == "status") print "**Status:** `" value "`"; else print
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
      if (MODE == "status") {
        if (!open_seen) { printf "lane-commit: FAIL: %s 缺 frontmatter 块\n", FILENAME > "/dev/stderr"; rc = 1 }
        else if (!done_fm) { printf "lane-commit: FAIL: %s frontmatter 未闭合\n", FILENAME > "/dev/stderr"; rc = 1 }
        else if (fm != 1) { printf "lane-commit: FAIL: %s frontmatter status 行命中 %d 行（须恰 1 行）\n", FILENAME, fm > "/dev/stderr"; rc = 1 }
        else if (body != 1) { printf "lane-commit: FAIL: %s 正文 Status 行命中 %d 行（须恰 1 行）\n", FILENAME, body > "/dev/stderr"; rc = 1 }
      } else {
        if (hits != 1) { printf "lane-commit: FAIL: %s 翻转锚点命中 %d 行（须恰 1 行）\n", FILENAME, hits > "/dev/stderr"; rc = 1 }
      }
      exit rc
    }
  ' "${repo_root}/$1" > "$2"
}

for flip in ${flips}; do
  f_file=${flip%%"${TAB}"*}
  f_rest=${flip#*"${TAB}"}
  f_field=${f_rest%%"${TAB}"*}
  f_val=${f_rest#*"${TAB}"}
  if [ "${f_field}" = 'status' ]; then f_mode=status; else f_mode=line; fi
  flip_run "${f_file}" /dev/null "${f_mode}" "${f_field}" "${f_val}" || \
    die1 "翻转锚点预校验未通过: ${f_file}（${f_field}）"
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

# ---- 记录写入（翻转 → Checkpoint / 微账本；写入后统一进记录提交） ----

date_today=$(date +%F)

for flip in ${flips}; do
  f_file=${flip%%"${TAB}"*}
  f_rest=${flip#*"${TAB}"}
  f_field=${f_rest%%"${TAB}"*}
  f_val=${f_rest#*"${TAB}"}
  if [ "${f_field}" = 'status' ]; then f_mode=status; else f_mode=line; fi
  tmp_flip=$(mktemp "${t_dir%/}/lane-flip.XXXXXX")
  flip_run "${f_file}" "${tmp_flip}" "${f_mode}" "${f_field}" "${f_val}" || {
    rm -f "${tmp_flip}"
    tmp_flip=''
    die1 "翻转写入未通过锚点校验: ${f_file}（${f_field}）"
  }
  mv "${tmp_flip}" "${repo_root}/${f_file}"
  tmp_flip=''
  printf 'lane-commit: 翻转: %s:%s:%s\n' "${f_file}" "${f_field}" "${f_val}"
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
  micro_file='docs/agent/micro.md'
  mkdir -p "${repo_root}/docs/agent"
  if [ ! -f "${repo_root}/${micro_file}" ]; then
    {
      printf '%s\n' '<!-- Input: 微任务道收尾的机械事实（日期、白名单文件、门禁结果、提交 ID）；本文件由道脚本独占写。 -->'
      printf '%s\n' '<!-- Output: 一行一操作的微账本记录行。 -->'
      printf '%s\n' '<!-- Pos: lane-commit.sh 懒创建与独占写（REQ-20260904-011 / 票 25 development-process 模板 §12.5 承载注记）；agent 不手写。 -->'
    } > "${repo_root}/${micro_file}" || die1 '微账本懒创建失败'
  fi
  [ -w "${repo_root}/${micro_file}" ] || die1 "微账本不可写: ${micro_file}"
  wl_joined=$(printf '%s' "${whitelist}" | paste -sd, -)
  printf '%s | %s | gates=PASS verify=%d | %s\n' "${date_today}" "${wl_joined}" "$(printf '%s' "${verifies}" | grep -c . || true)" "${cid1}" >> "${repo_root}/${micro_file}" || die1 '微账本落行失败'
  record_files="${record_files}${micro_file}${NL}"
  printf 'lane-commit: 微账本已落行: %s\n' "${micro_file}"
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
printf 'lane-commit: PASS（两段式完成：门禁 PASS、翻转 %d 项、记录已落盘）\n' "${n_flip}"
