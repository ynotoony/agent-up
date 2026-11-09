#!/bin/sh
# Input: 目标仓库根目录（缺省当前目录）、可选单目录／新建目录、范围规则文件与模式开关；
#        规则文件缺省为脚本同目录 dir-readme.rules，可由 --rules 覆盖（消费者仓库自定）。
# Output: --check 模式逐条校验目标范围内既有目录 README.md 的四段式契约——四段齐全
#         （职责句／## 权威／## 读取禁忌／## 子目录及其三列表头）、总行数 ≤ 25、无成员表、
#         无计数与状态句、正文反引号路径存在（含 / 按目标根；形如文件名的裸名按 README
#         所在目录）、正文裸露的【填写：…】占位（HTML 注释、行内代码段与围栏代码块内不算）、
#         生成块标记成对（围栏代码块内标记不算块）；全部通过 exit 0 且零
#         输出，不合规逐条输出 `path:line: 原因` 且 exit 2，异常形态 fail-closed exit 2。
#         --freshness 为生成块新鲜度只读断言：在内存重算 --sync 应产出的生成块，与现行
#         块逐行比对（不写任何文件），漂移即 exit 1 并逐条输出 `path:line: 缺失行: <原文>`
#         ／`path:line: 多余行: <原文>`；无生成块的 README 跳过，块未闭合／重复起始／
#         dir 值不符 exit 2。它补 --check 单独发现不了的「新增子目录未入表」（只校验标记
#         成对，不比对表内容）。--check --blocks-only 只校验含生成块的 README（旧格式无
#         生成块跳过），供收口门禁把结构断言限定在启用生成块的目录。
#         --sync 只重建生成块内的子目录表（块外逐字节不动，无生成块的 README 不新建
#         不修改并输出 SKIP）；--init 为新目录写四段骨架（判断位留【填写：…】）。
#         --migrate-dry-run 为旧格式迁移预演（只读）：跳过 --check 零问题的 README，其余按
#         表格结构归入三种形态。默认输出摘要（≤15 行：SUMMARY 形态计数、ZERO-WRITE
#         sha256 证据、NEEDS-CONFIRM 待人工确认清单）；--diff 连用才输出逐文件统一 diff
#         与 MIGRATE／DROP／NOTE 详情（--diff 单独出现即 exit 2）。判断文字整行原文搬运、
#         超 25 行不截断只报 NOTE，预演前后逐件核对 sha256；无迁移件零输出 exit 0。
#         --init 与 --sync --dir 的目录路径规范化后含空白即 exit 2 零写入（范围规则与
#         生成块标记均以空白分隔，含空白的目录二者都无法唯一表示）。
#         --brief <rel-dir> 只读输出单个目录的 agent 素材包（零写入）：目录清单（一级
#         成员的目录／文件、文件行数与字节数）、判断证据（仓库 facts/project/artifacts.yaml
#         中该目录及目录内条目的 id／path／kind／authority／read_when 原文，按目录／一级
#         成员／子目录内分组）、既有 README 现状（复用 --check 判定的缺段、占位行与逐条
#         问题）、生成约定（四段写法、禁止事项与 25 行预算）。四节固定标题便于套件断言；
#         素材只含目标目录一级成员与作用域为本目录的 artifacts 条目，authority／read_when
#         原文照录（目录外指针保留）。artifacts.yaml 缺失或不可
#         解析时降级为「目录清单＋生成约定」，输出一行 DEGRADED 原因并 exit 0，不静默。
#         --brief 与 --check／--sync／--init／--migrate-dry-run 互斥，不接受 --dir。
#         退出码：0 成功；1 仅 --freshness 生成块漂移；2 用法／环境／校验异常（fail-closed，
#         不产生部分结论）；3 stdout 管道被下游提前关闭（BrokenPipe，输出可能被截断）。
# Pos: 目录 README 结构校验、生成块同步、骨架生成与旧格式迁移预演器（单一 CLI 薄壳；
#      实现分五模块同目录分发——dir_readmes_model/check/sync/migrate/brief.py，票 290；
#      Python 3 标准库
#      实现，壳层只做解释器定位与转调）；契约与四段式骨架见
#      references/templates/dir-README.md.tmpl，范围见同目录 dir-readme.rules；两件与
#      本目录 README.md 成员表三处登记须同步。

set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
if ! command -v python3 >/dev/null 2>&1; then
  printf 'generate-dir-readmes: FAIL: python3 不可用（本脚本以 Python 3 标准库实现）\n' >&2
  exit 2
fi
exec python3 - "$here" "$@" <<'PY'
"""generate-dir-readmes.sh 单一 CLI 薄壳（票 290 拆分；实现下沉同目录五模块）.

本件只保留参数解析、用法文本与模式分派；markdown 模型、check/freshness、sync/init、
migrate、brief 各自成同目录模块 import。CLI 参数面、逐行输出与退出码不变。
"""
import os
import sys

_SCRIPT_DIR = sys.argv[1]
sys.path.insert(0, _SCRIPT_DIR)
# 同目录模块 import 不落 __pycache__（包闭合性检查 20 与只读安装面要求；不影响任何输出）
sys.dont_write_bytecode = True

try:
    from dir_readmes_brief import run_brief
    from dir_readmes_check import check_file, run_freshness
    from dir_readmes_migrate import run_migrate
    from dir_readmes_model import (
        die,
        emit_problems,
        find_blocks,
        load_rules,
        read_text_exact,
        resolve_candidates,
        split_raw_lines,
    )
    from dir_readmes_sync import run_init, run_sync
except ImportError as _import_error:
    sys.stderr.write(
        'generate-dir-readmes: FAIL: 安装闭包不完整（同目录模块缺失）: %s\n'
        % _import_error
    )
    sys.exit(2)


USAGE = """用法: generate-dir-readmes.sh [--target <repo-root>] [--dir <rel>] [--rules <path>]
                            [--check [--blocks-only] | --sync | --freshness
                             | --init <rel> | --migrate-dry-run [--diff]
                             | --brief <rel-dir>]
参数:
  --target <repo-root>  目标仓库根目录；缺省取当前目录。
  --dir <rel>           只处理该目录（目标根相对路径）的 README.md；--init 时不可用。
  --rules <path>        范围规则文件；缺省取脚本同目录 dir-readme.rules。
  -h / --help           打印本用法。
模式（互斥，缺省 --check）:
  --check               结构校验，零写入。
  --blocks-only         仅与 --check 连用：只校验含生成块的 README，无生成块的旧格式
                        跳过（不阻断收口）；单独出现或与其它模式同用即 exit 2。
  --freshness           生成块新鲜度只读断言，零写入：在内存按 --sync 同一生成函数重算
                        生成块，与现行块逐行比对。漂移即 exit 1，逐条输出
                        `path:line: 缺失行: <原文>`／`path:line: 多余行: <原文>`（缺失行
                        行号＝该行在生成块内的期望位置）；无生成块的 README 跳过，干净时
                        exit 0 且零输出；块未闭合／重复起始／dir 值不符 exit 2。
                        用于收口门禁发现 --check 单独发现不了的「新增子目录未入表」。
  --sync                重建既有生成块（<!-- dir-readme: generated dir=<rel> --> 至
                        <!-- /dir-readme -->）内的子目录表；块外逐字节不动。无生成块的
                        README 不新建、不修改，逐文件输出 `SKIP: <path>: 无生成块`。
                        新增行的一句话取该子目录 README 的职责句，取不到写
                        【填写：一句话职责】；禁忌取不到写 —。删除的行逐行输出 DEL。
                        围栏代码块（```／~~~）内的标记不算生成块，不读不写。
  --init <rel-dir>      为 <target>/<rel-dir> 新建 README.md 四段骨架，判断位留
                        【填写：…】；目录不存在或 README.md 已存在即 exit 2 零写入。
  --migrate-dry-run     旧格式迁移预演，只读。先以 --check 口径筛面：零问题的 README 不进
                        迁移集合（范围内全合规时零输出、exit 0）。其余按表格结构归入
                        four-column（四列表头且首格为「文件」类关键词）／member-table
                        （表头任一格去空白、反引号与 ** 后整格等于「名字／成员／文件」，且
                        紧随分隔行）／no-table（无上述表；普通两列表不算成员表）。
                        默认摘要模式（≤15 行）：`SUMMARY: 迁移 N 件（member-table a／
                        four-column b／no-table c）`、`ZERO-WRITE: N/N sha256 一致`，以及按
                        类别各一行的 `NEEDS-CONFIRM:`（超 25 行、缺职责句、缺「权威」或
                        「读取禁忌」列表项、未迁入段数）。无迁移件即零输出 exit 0。
                        建议内容四段式：H1 与职责句原文；## 权威／## 读取禁忌 从旧文
                        「架构／身份与冻结依据」「已知限制／维护纪律／边界」类段落整行搬
                        运列表项（不改写、不合并、不换措辞）；## 子目录 复用 --sync 的
                        同一子目录表生成函数。超 25 行只报不截断。全程零写入：每件预演
                        前后核对 sha256，临时文件只落 $TMPDIR；无 H1、表头残缺、不可读
                        一律 exit 2 且不产生部分结论。
  --brief <rel-dir>     只读输出该目录（目标根相对路径，须存在）的 agent 素材包，零写入。
                        四节固定标题：
                        ## BRIEF 目录清单——一级成员（目录／文件／链接），文件给行数与
                        字节数，子目录标注 README.md 有无；
                        ## BRIEF 判断证据——facts/project/artifacts.yaml 中该目录及目录内
                        条目的 id／path／kind／authority／read_when 原文，按目录／一级成员／
                        子目录内分组；authority 明确标注为待改写的层级描述，不是结论；
                        authority／read_when 原文照录，目录外指针（如 rules/project.md §15.1）
                        保留，供写指针用，不得据此读取或转述其内容；
                        ## BRIEF 现状——README.md 是否存在、四段是否齐全、缺段、占位行与
                        逐条问题（复用 --check 判定，回显原文不改写）；
                        ## BRIEF 生成约定——四段写法要求、禁止事项（成员表、计数句、状态句、
                        目录外引用）与 25 行预算。
                        artifacts.yaml 缺失、不可解析或任一条目缺 id／path 时降级为
                        「目录清单＋生成约定」，输出一行 `DEGRADED: <原因>` 并 exit 0，
                        不静默、不 exit 2、不部分采用条目。
                        与 --check／--sync／--freshness／--init／--migrate-dry-run 互斥，
                        不接受 --dir。
  --diff                仅与 --migrate-dry-run 连用：输出逐文件详情——`MIGRATE: <path>:
                        <形态>: <原行数>→<建议行数>`、`DROP: <path>: <起>-<止> 行: <原因>`、
                        `NOTE:`、统一 diff（--- a/<path> / +++ b/<path>）与带零写入证据的
                        SUMMARY 行。单独出现或与 --check／--sync／--freshness／--init
                        同用即 exit 2。
  --init 与 --sync --dir 的目录路径不得含空白字符（范围规则与生成块标记均以空白分隔，
                        含空白的目录既进不了范围也无法被生成块标记唯一表示），
                        规范化后含空白即 exit 2 零写入。
断言（--check）:
  1. 四段齐全：一句话职责、## 权威、## 读取禁忌、## 子目录（三列表头＋分隔行）。
  2. 总行数 ≤ 25。
  3. 无成员表（## 成员段，或表头任一单元去空白、反引号与 ** 后整格等于「名字／成员／文件」的表格；契约子目录表除外）。
  4. 无计数与状态句（共 N 件／N 个脚本／中文数字个脚本／N 行（「一行」「第 N 行」不算）／N 份合同／N 个成员·文件·票／当前没有）。
  5. 正文反引号包裹的路径存在：含 / 的按目标根校验；不含 / 但形如文件名的
     （如 missing-file.md）按 README 所在目录校验；其余裸标识符（--flag、true）与
     N/A（大小写不敏感，可带理由）忽略。
     通配、绝对路径、URL 一律忽略。
  6. 正文裸露的【填写：…】占位即判不通过（HTML 注释内、反引号代码段内与围栏代码块
     内的占位不算）。
  7. 生成块 <!-- dir-readme: generated dir=<rel> --> 与 <!-- /dir-readme --> 成对且
     dir 值与目录一致；围栏代码块（```／~~~，含更长围栏）内的成对标记不算生成块。
退出码:
  0  校验通过／同步完成／骨架已写入／迁移预演完成／素材包已输出（含 artifacts 索引
     缺失或不可解析的降级输出）／生成块新鲜度无漂移（零输出）。
  1  --freshness 发现生成块漂移：逐条 `path:line: 缺失行／多余行: <原文>`，零写入
     （其余模式不产生 1）。
  2  不合规或异常形态（无文件、无四段标记可判、规则文件损坏、目标路径不存在、
     生成块未闭合或重复起始、dir 值不符、--init 目标已存在、--init／--sync --dir
     路径含空白、模式互斥冲突），fail-closed，逐条输出 `path:line: 原因`，写入模式
     零写入；迁移预演另对无 H1、表头残缺、不可读同上 exit 2 且不产生部分结论。
  3  stdout 管道被下游提前关闭（BrokenPipe）：输出可能被截断，按失败退出且不写
     traceback（下游提前退出时不得报成功）。
"""


def require_value(argv, i, arg, hint=""):
    """取选项值：缺值（越界／空串／下一参数为选项）即 die，统一缺参数值检查。"""
    if i + 1 >= len(argv):
        die("%s 缺参数值%s" % (arg, hint))
    value = argv[i + 1]
    if value == "" or value.startswith("--"):
        die("%s 缺参数值%s" % (arg, hint))
    return value


def parse_args(argv):
    here = argv[0]
    target = None
    only = None
    rules = os.path.join(here, "dir-readme.rules")
    explicit = []
    init_dir = None
    brief_dir = None
    detail = False
    blocks_only = False
    i = 1
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            sys.stdout.write(USAGE)
            sys.exit(0)
        if arg == "--diff":
            detail = True
            i += 1
            continue
        if arg == "--blocks-only":
            blocks_only = True
            i += 1
            continue
        if arg == "--check":
            explicit.append("check")
            i += 1
            continue
        if arg == "--freshness":
            explicit.append("freshness")
            i += 1
            continue
        if arg == "--sync":
            explicit.append("sync")
            i += 1
            continue
        if arg == "--migrate-dry-run":
            explicit.append("migrate")
            i += 1
            continue
        if arg == "--init":
            value = require_value(argv, i, arg)
            explicit.append("init")
            init_dir = value
            i += 2
            continue
        if arg == "--brief":
            value = require_value(argv, i, arg, "（须给目标根相对目录）")
            explicit.append("brief")
            brief_dir = value
            i += 2
            continue
        if arg in ("--target", "--dir", "--rules"):
            value = require_value(argv, i, arg)
            if arg == "--target":
                target = value
            elif arg == "--dir":
                only = value
            else:
                rules = value
            i += 2
            continue
        die("未知参数: %s（用法见 --help）" % arg)
    if len(explicit) > 1:
        die("--check／--sync／--freshness／--init／--migrate-dry-run／--brief 互斥，只能给一个")
    if len(explicit) == 0 and detail:
        die("--diff 只能与 --migrate-dry-run 连用（单独出现无效，用法见 --help）")
    mode = explicit[0] if explicit else "check"
    if detail and mode != "migrate":
        die("--diff 只能与 --migrate-dry-run 连用（与 %s 同用无效，用法见 --help）" % ("--" + mode))
    if blocks_only and mode != "check":
        die("--blocks-only 只能与 --check 连用（与 %s 同用无效，用法见 --help）" % ("--" + mode))
    if mode == "init" and only is not None:
        die("--init 不接受 --dir（目标目录由 --init 参数给出）")
    if mode == "brief" and only is not None:
        die("--brief 不接受 --dir（目标目录由 --brief 参数给出）")
    return (target if target is not None else "."), only, rules, mode, init_dir, detail, brief_dir, blocks_only


def main(argv):
    target_arg, only_arg, rules_path, mode, init_arg, detail, brief_arg, blocks_only = parse_args(argv)
    target = os.path.abspath(target_arg)
    if not os.path.isdir(target):
        die("目标路径不存在或不是目录: %s" % target_arg)

    if mode == "brief":
        return run_brief(target, brief_arg)

    includes, excludes = load_rules(rules_path)

    if mode == "init":
        return run_init(target, init_arg, includes, excludes)

    candidates = resolve_candidates(target, only_arg, includes, excludes, rules_path, mode)
    if mode == "sync":
        return run_sync(target, candidates, includes, excludes)
    if mode == "freshness":
        return run_freshness(target, candidates, includes, excludes)
    if mode == "migrate":
        return run_migrate(target, candidates, includes, excludes, detail)

    problems = []
    for rel in candidates:
        if blocks_only:
            raw = read_text_exact(target, rel)
            blocks, probs = find_blocks(rel, split_raw_lines(raw))
            if probs:
                problems.extend(probs)
                continue
            if not blocks:
                continue
        problems.extend(check_file(target, rel))

    if problems:
        emit_problems(problems)
        return 2
    return 0


try:
    _code = main(sys.argv[1:])
    sys.stdout.flush()
except BrokenPipeError:
    # 下游提前关闭管道（如 `| head -5`）：stdout 已被截断，不得报成功。exit 3
    # 明确表示「输出可能不完整」，且不把 traceback 写到 stderr。
    os._exit(3)
sys.exit(_code)
PY
