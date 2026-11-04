#!/bin/sh
# Input: 目标宿主配置文件路径（--config）、宿主知识（--set <键>=<值>，可重复）与可选
#        host-profile 路径（--profile）；写入须显式 --write --confirm 双开关，缺省 dry-run。
# Output: dry-run 的「将修改（项目外）」分组（目标路径、逐行片段、备份路径与 host-profile
#         登记建议）零写入；--write 落标记块并报告备份路径——块已同幂等跳过、块有差异即停
#         不覆盖；退出码 0 成功或幂等、1 冲突或父目录缺失、2 用法错误。
# Pos: 宿主无关的宿主用户级配置对账器（Agent Up 公开包脚本）；引擎零宿主专名与键名，
#      宿主能力与键名只从 references/adapters/<host>.md §2.6/§2.7 取并经 --set 传入；
#      一旦我被更新，务必更新同目录 README.md 登记与 tests/suite-check-artifacts.sh。

set -eu

prog=host-config
start_marker='# >>> agent-up host-config >>>'
end_marker='# <<< agent-up host-config <<<'

usage() {
  cat <<'USAGE'
用法: sh host-config.sh --config <file> --set <key>=<value> [--set ...]
                         [--write] [--confirm] [--profile <facts/project/host-profile.md>] [-h]
参数:
  --config <file>   宿主用户级配置文件（可不存在；父目录须存在才可写入）。
  --set <key>=<value>
                    期望写入的一行片段，可重复并按给定顺序落块。键限 [A-Za-z0-9_.-]，
                    值为非空且不含换行；宿主键名与取值由调用方按适配器文档传入。
  --write           写入形态（缺省 dry-run，零写入）。
  --confirm         写入确认；须与 --write 同时出现，缺一即 exit 2。
  --profile <file>  可选 host-profile 路径：dry-run/写入报告附四列登记建议行。
  -h, --help        打印本用法。
写入语义（标记块 '# >>> agent-up host-config >>>' 至 '# <<< agent-up host-config <<<'）:
  目标不存在      创建并写入块；父目录不存在 exit 1 指名。
  块已存在且逐字一致  幂等跳过，exit 0，零写入。
  块已存在但内容不同  视为人工改动：exit 1 指名文件，不覆盖、不写入。
  无标记块        目标存在时先备份为 '<file>.bak.<UTC yyyymmddThhmmssZ>' 再追加。
退出码: 0 成功或幂等；1 冲突或父目录缺失；2 用法或参数错误。
USAGE
}

die2() { printf '%s: 用法错误: %s\n' "$prog" "$1" >&2; exit 2; }
fail1() { printf '%s: FAIL: %s\n' "$prog" "$1" >&2; exit 1; }

cfg=''
profile=''
do_write=0
do_confirm=0
have_set=0
cfg_seen=0

t_dir=${TMPDIR:-/tmp}
tmpdir=$(mktemp -d "$t_dir/host-config.XXXXXX")
frag="$tmpdir/frag.txt"
expected="$tmpdir/expected.txt"
actual="$tmpdir/actual.txt"
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
: > "$frag"

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --config)
      [ $# -ge 2 ] || die2 '--config 缺参数'
      [ "$cfg_seen" -eq 0 ] || die2 '--config 只接受一次'
      cfg=$2
      cfg_seen=1
      shift 2
      ;;
    --set)
      [ $# -ge 2 ] || die2 '--set 缺参数'
      set_arg=$2
      shift 2
      case $set_arg in
        *=*) key=${set_arg%%=*}; value=${set_arg#*=} ;;
        *) die2 "非法 --set（缺 =）: $set_arg" ;;
      esac
      case $key in
        ''|*[!A-Za-z0-9_.-]*) die2 "非法 --set 键（限 A-Za-z0-9_.-）: $key" ;;
      esac
      [ -n "$value" ] || die2 "非法 --set 值（空值）: $key"
      case $value in
        *'
'*) die2 "非法 --set 值（含换行）: $key" ;;
      esac
      printf '%s = %s\n' "$key" "$value" >> "$frag"
      have_set=1
      ;;
    --write) do_write=1; shift ;;
    --confirm) do_confirm=1; shift ;;
    --profile)
      [ $# -ge 2 ] || die2 '--profile 缺参数'
      profile=$2
      shift 2
      ;;
    *) die2 "未知参数: $1" ;;
  esac
done

[ -n "$cfg" ] || die2 '缺 --config'
[ "$have_set" -eq 1 ] || die2 '缺 --set（至少一条）'
if [ "$do_write" -eq 1 ] && [ "$do_confirm" -eq 1 ]; then
  :
elif [ "$do_write" -eq 0 ] && [ "$do_confirm" -eq 0 ]; then
  :
else
  die2 '--write 与 --confirm 须同时出现（写入须显式双开关）'
fi

cfg_dir=$(dirname "$cfg")
cfg_base=$(basename "$cfg")
case $cfg in
  /*) cfg_abs=$cfg ;;
  *)
    if cfg_abs_dir=$(CDPATH='' cd "$cfg_dir" 2>/dev/null && pwd); then
      cfg_abs="$cfg_abs_dir/$cfg_base"
    else
      cfg_abs=$cfg
    fi
    ;;
esac
parent=$(dirname "$cfg_abs")
[ -d "$parent" ] || fail1 "目标父目录不存在: ${parent}（目标: ${cfg_abs}）"

ts=$(date -u +%Y%m%dT%H%M%SZ)
backup=$cfg_abs.bak.$ts

{
  printf '%s\n' "$start_marker"
  cat "$frag"
  printf '%s\n' "$end_marker"
} > "$expected"

profile_line() {
  # $1=状态取值；引擎零宿主知识，只给四列骨架与权威指针
  if [ -n "$profile" ]; then
    printf '  host-profile: %s\n' "$profile"
    printf '  host-profile 建议行: | <宿主> | <三档取值> | <落地方式> | %s |\n' "$1"
    printf '  host-profile 格式: 四列见 references/adapters/README.md（写没写都登记，多宿主多行）\n'
  fi
}

if [ "$do_write" -eq 0 ]; then
  printf '%s: dry-run（默认零写入；写入须 --write --confirm）\n' "$prog"
  printf '将修改（项目外）\n'
  printf '  目标: %s\n' "$cfg_abs"
  printf '  片段:\n'
  sed 's/^/    /' "$frag"
  printf '  备份: %s\n' "$backup"
  printf '  状态: 未勾选，不写入（仅片段）\n'
  profile_line '仅片段'
  exit 0
fi

existed=0
if [ -f "$cfg_abs" ]; then
  existed=1
  starts=$(grep -c -F -x "$start_marker" "$cfg_abs" || true)
  ends=$(grep -c -F -x "$end_marker" "$cfg_abs" || true)
  if [ "$starts" -eq 0 ] && [ "$ends" -eq 0 ]; then
    :
  elif [ "$starts" -eq 1 ] && [ "$ends" -eq 1 ]; then
    awk -v s="$start_marker" -v e="$end_marker" '
      $0 == s { inb = 1 }
      inb { print }
      inb && $0 == e { inb = 0; exit }
    ' "$cfg_abs" > "$actual"
    if cmp -s "$actual" "$expected"; then
      printf '%s: 幂等跳过: %s（标记块与期望逐字一致，零写入）\n' "$prog" "$cfg_abs"
      printf '  备份: 无（幂等，未写入）\n'
      profile_line '已写入'
      exit 0
    fi
    fail1 "标记块与期望不一致，未写入: ${cfg_abs}（疑似人工改动；请人工核对后移除标记块或改回期望内容）"
  else
    fail1 "标记块不完整或重复，未写入: ${cfg_abs}（起始 ${starts} 处，结束 ${ends} 处；请人工核对）"
  fi
fi

if [ "$existed" -eq 1 ]; then
  cp "$cfg_abs" "$backup" || fail1 "备份失败: $backup"
  if [ -s "$cfg_abs" ]; then
    last_byte=$(tail -c 1 "$cfg_abs" | od -An -t u1 | tr -d ' \n')
    if [ "$last_byte" != 10 ]; then
      printf '\n' >> "$cfg_abs"
    fi
  fi
  cat "$expected" >> "$cfg_abs"
else
  cat "$expected" > "$cfg_abs"
fi

printf '%s: 已写入（项目外）: %s\n' "$prog" "$cfg_abs"
printf '  片段:\n'
sed 's/^/    /' "$frag"
if [ "$existed" -eq 1 ]; then
  printf '  备份: %s\n' "$backup"
else
  printf '  备份: 无（目标原不存在，新建）\n'
fi
profile_line '已写入'
exit 0
