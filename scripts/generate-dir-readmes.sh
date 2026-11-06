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
# Pos: 目录 README 结构校验、生成块同步、骨架生成与旧格式迁移预演器（Python 3 标准库
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
import difflib
import fnmatch
import hashlib
import os
import re
import sys

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


PLACEHOLDER_DUTY = "【填写：一句话职责】"
PLACEHOLDER_MARK = "【填写："


def die(msg):
    sys.stderr.write("generate-dir-readmes: FAIL: %s\n" % msg)
    sys.exit(2)


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


def load_rules(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read().splitlines()
    except OSError:
        die("规则文件不存在或不可读: %s" % path)
    includes = []
    excludes = []
    for n, line in enumerate(raw, 1):
        text = line.strip()
        if not text or text.startswith("#"):
            continue
        parts = text.split(None, 1)
        if len(parts) != 2:
            die("规则文件损坏（%s:%d）: %s" % (path, n, text))
        kind, pattern = parts[0], parts[1].strip()
        if kind not in ("include", "exclude") or not pattern or len(pattern.split()) != 1:
            die("规则文件损坏（%s:%d）: %s" % (path, n, text))
        if kind == "include":
            includes.append(pattern)
        else:
            excludes.append(pattern)
            if pattern.endswith("/**"):
                excludes.append(pattern[:-3])
    if not includes:
        die("规则文件损坏（%s）：至少需要一条 include" % path)
    return includes, excludes


def in_scope(rel, includes, excludes):
    if not any(fnmatch.fnmatchcase(rel, p) for p in includes):
        return False
    return not any(fnmatch.fnmatchcase(rel, p) for p in excludes)


def join_rel(parent, name):
    return name if not parent else parent + "/" + name


def normalize_dir(value):
    text = value.replace("\\", "/").strip()
    while text.startswith("./"):
        text = text[2:]
    text = text.rstrip("/")
    if text in ("", "."):
        return ""
    if text.startswith("/") or text.startswith("~"):
        die("--dir 须为目标根相对路径: %s" % value)
    parts = [p for p in text.split("/") if p not in ("", ".")]
    if ".." in parts:
        die("--dir 不得越出目标根: %s" % value)
    return "/".join(parts)


def reject_whitespace(rel, label):
    # 范围规则按空白切词、生成块标记以 dir=(\S+) 取值：含空白的目录永远无法被这两处
    # 唯一表示，写出去即读不回，故在写入模式前 fail-closed。
    if any(ch.isspace() for ch in rel):
        die(
            "%s 含空白字符（%s），目录路径不得含空白（范围规则与生成块标记均以空白分隔）"
            % (label, rel)
        )


def collect_readmes(target, includes, excludes):
    found = []
    for root, dirs, files in os.walk(target):
        rel = os.path.relpath(root, target).replace(os.sep, "/")
        if rel == ".":
            rel = ""
        dirs[:] = sorted(
            d for d in dirs
            if d != ".git" and in_scope(join_rel(rel, d), includes, excludes)
        )
        if "README.md" in files and in_scope(rel, includes, excludes):
            found.append(join_rel(rel, "README.md"))
    return sorted(found)


def resolve_candidates(target, only_arg, includes, excludes, rules_path, mode):
    if only_arg is not None:
        rel = normalize_dir(only_arg)
        if mode == "sync":
            reject_whitespace(rel, "--dir 指向的路径")
        if not os.path.isdir(os.path.join(target, rel)):
            die("--dir 指向的目录不存在: %s" % (only_arg if only_arg else "."))
        if not in_scope(rel, includes, excludes):
            die("--dir 指向的目录不在规则范围内: %s" % (rel or "."))
        candidates = [join_rel(rel, "README.md")]
        if not os.path.isfile(os.path.join(target, candidates[0])):
            die("无文件：目录下没有 README.md: %s" % (rel or "."))
        return candidates
    candidates = collect_readmes(target, includes, excludes)
    if not candidates:
        die("无文件：目标范围内未找到 README.md（规则文件: %s）" % rules_path)
    return candidates


def list_subdirs(target, rel, includes, excludes):
    base = os.path.join(target, rel) if rel else target
    try:
        names = os.listdir(base)
    except OSError:
        die("目录不可读: %s" % (rel or "."))
    found = []
    for name in sorted(names):
        if name == ".git":
            continue
        if not os.path.isdir(os.path.join(base, name)):
            continue
        if in_scope(join_rel(rel, name), includes, excludes):
            found.append(name)
    return found


def strip_comments(lines):
    out = []
    in_comment = False
    for line in lines:
        kept = []
        i = 0
        while i < len(line):
            if in_comment:
                end = line.find("-->", i)
                if end < 0:
                    i = len(line)
                else:
                    in_comment = False
                    i = end + 3
            else:
                start = line.find("<!--", i)
                if start < 0:
                    kept.append(line[i:])
                    i = len(line)
                else:
                    kept.append(line[i:start])
                    in_comment = True
                    i = start + 4
        out.append("".join(kept))
    return out


H1_RE = re.compile(r"^#\s+(\S.*?)\s*$")
H2_RE = re.compile(r"^##\s+(.+?)\s*$")
OPEN_RE = re.compile(r"^<!--\s*dir-readme:\s*generated\s+dir=(\S+)\s*-->$")
CLOSE_RE = re.compile(r"^<!--\s*/dir-readme\s*-->$")
BARE_FILE_RE = re.compile(r"^[A-Za-z0-9._-]+\.(?:md|json|jsonl|sh|py|rules|yaml|yml|html|tmpl)$")
NA_RE = re.compile(r"^n/a(?:[^\w/]|$)", re.IGNORECASE)
MEMBER_HEADER_KEYS = ("名字", "成员", "文件")
COUNT_NUM = r"(?:\d+|[一二三四五六七八九十百千万两]+)"
COUNT_LINE_RE = re.compile(COUNT_NUM + r"\s*行")
COUNT_RES = (
    (re.compile(r"共\s*\d+\s*[件个]"), "计数句"),
    (re.compile(r"\d+\s*个脚本"), "计数句"),
    (re.compile(r"[一二三四五六七八九十百千万两]+\s*个?\s*脚本"), "计数句"),
    (COUNT_LINE_RE, "计数句"),
    (re.compile(COUNT_NUM + r"\s*(?:份|个)?\s*合同"), "计数句"),
    (re.compile(COUNT_NUM + r"\s*(?:个|份|张)\s*(?:成员|文件|票|合同)"), "计数句"),
    (re.compile(r"当前没有"), "状态句"),
)


def table_cells(line):
    text = line.strip()
    if not text.startswith("|"):
        return []
    text = text[1:]
    if text.endswith("|"):
        text = text[:-1]
    return [cell.strip() for cell in text.split("|")]


def row_cells(line):
    # 与 table_cells 同形，但保留 \| 转义：旧行两格原文复用后再次解析须逐字节稳定。
    text = line.strip()
    if not text.startswith("|"):
        return []
    text = text[1:]
    cells = []
    cur = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "\\" and i + 1 < len(text) and text[i + 1] == "|":
            cur.append("\\")
            cur.append("|")
            i += 2
            continue
        if ch == "|":
            cells.append("".join(cur).strip())
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    tail = "".join(cur).strip()
    if tail:
        cells.append(tail)
    return cells


def is_separator(line):
    cells = table_cells(line)
    if not cells:
        return False
    return all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def is_subdir_header(line):
    cells = table_cells(line)
    return len(cells) == 3 and cells[0] == "子目录" and cells[1] == "一句话" and cells[2] == "禁忌"


def normalize_cell(cell):
    return cell.strip().replace("`", "").replace("**", "").strip()


def is_member_header(line):
    cells = table_cells(line)
    if len(cells) < 2 or is_subdir_header(line):
        return False
    return any(normalize_cell(cell) in MEMBER_HEADER_KEYS for cell in cells)


def is_line_count(line, match):
    if match.group(0)[:-1].strip() == "一":
        return False
    return re.search(r"第\s*$", line[:match.start()]) is None


def dir_of_readme(relpath):
    return relpath.rsplit("/", 1)[0] if "/" in relpath else ""


def read_text_exact(target, relpath):
    try:
        with open(os.path.join(target, relpath), "rb") as fh:
            data = fh.read()
    except OSError:
        die("README 不可读: %s" % relpath)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        die("README 不是 UTF-8: %s" % relpath)


def split_raw_lines(text):
    parts = text.split("\n")
    lines = []
    for idx, part in enumerate(parts):
        if idx < len(parts) - 1:
            if part.endswith("\r"):
                lines.append((part[:-1], "\r\n"))
            else:
                lines.append((part, "\n"))
        elif part != "":
            lines.append((part, ""))
    return lines


def join_raw_lines(lines):
    return "".join(content + term for content, term in lines)


def detect_eol(lines):
    for _, term in lines:
        if term == "\r\n":
            return "\r\n"
    return "\n"


FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")


def fenced_mask(lines):
    # 逐行标记是否处于围栏代码块内；围栏定界行本身也算在内。闭合围栏须同字符、
    # 长度不短于开启围栏且其后无信息串（CommonMark 口径）。
    mask = []
    fence_char = None
    fence_len = 0
    for line in lines:
        match = FENCE_RE.match(line)
        if fence_char is None:
            if match and not (match.group(1)[0] == "`" and "`" in match.group(2)):
                fence_char = match.group(1)[0]
                fence_len = len(match.group(1))
                mask.append(True)
            else:
                mask.append(False)
            continue
        mask.append(True)
        if (
            match
            and match.group(1)[0] == fence_char
            and len(match.group(1)) >= fence_len
            and match.group(2).strip() == ""
        ):
            fence_char = None
            fence_len = 0
    return mask


def strip_inline_code(line):
    # 去掉反引号代码段（同长度反引号串闭合），只留散文／表格单元格里的裸文字。
    out = []
    i = 0
    n = len(line)
    while i < n:
        if line[i] != "`":
            out.append(line[i])
            i += 1
            continue
        j = i
        while j < n and line[j] == "`":
            j += 1
        run = j - i
        k = j
        while k < n:
            if line[k] != "`":
                k += 1
                continue
            m = k
            while m < n and line[m] == "`":
                m += 1
            if m - k == run:
                i = m
                break
            k = m
        else:
            out.append(line[i:j])
            i = j
    return "".join(out)


def find_blocks(rel, lines):
    blocks = []
    problems = []
    open_idx = None
    open_dir = None
    expected = dir_of_readme(rel)
    accepted = {"", ".", "./"}
    if expected:
        accepted.update({expected, "./" + expected})
    fences = fenced_mask([content for content, _ in lines])
    for i, (content, _) in enumerate(lines):
        if fences[i]:
            continue
        text = content.strip()
        match = OPEN_RE.match(text)
        if match:
            if open_idx is not None:
                problems.append(
                    (rel, i + 1, "生成块重复起始标记（上一处在第 %d 行）" % (open_idx + 1))
                )
                continue
            open_idx = i
            open_dir = match.group(1)
            continue
        if CLOSE_RE.match(text):
            if open_idx is None:
                problems.append((rel, i + 1, "生成块结束标记缺少起始标记"))
            else:
                if open_dir not in accepted:
                    problems.append(
                        (rel, open_idx + 1, "生成块 dir 值不符: %s（应为 %s）" % (open_dir, expected or "."))
                    )
                blocks.append((open_idx, i, open_dir))
                open_idx = None
                open_dir = None
    if open_idx is not None:
        problems.append((rel, open_idx + 1, "生成块未闭合（缺少 <!-- /dir-readme -->）"))
    return blocks, problems


def read_duty(target, rel, name):
    path = os.path.join(target, rel, name, "README.md") if rel else os.path.join(target, name, "README.md")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
    except OSError:
        return None
    body = strip_comments(lines)
    h1 = None
    for i, line in enumerate(body):
        if H1_RE.match(line):
            h1 = i
            break
    if h1 is None:
        return None
    for i in range(h1 + 1, len(body)):
        line = body[i].strip()
        if not line:
            continue
        if H1_RE.match(line) or H2_RE.match(line):
            break
        if line.startswith("|"):
            continue
        if PLACEHOLDER_MARK in line:
            return None
        return line
    return None


def escape_cell(text):
    return text.replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def parse_old_rows(block_lines, base_rel):
    old = {}
    for content, _ in block_lines:
        if not content.strip().startswith("|"):
            continue
        if is_subdir_header(content) or is_separator(content):
            continue
        cells = row_cells(content)
        if len(cells) < 3:
            continue
        name = cells[0].replace("`", "").strip().rstrip("/").strip()
        name = name.replace("\\|", "|")
        if base_rel and name.startswith(base_rel + "/"):
            name = name[len(base_rel) + 1:]
        if not name or name in old:
            continue
        old[name] = (cells[1], cells[2])
    return old


def subdir_table_lines(subdirs, old, target, base_rel):
    # 首格写成目标根相对路径加反引号：--check 对含 / 的反引号 token 一律按目标根
    # 校验，裸 `sub/` 在嵌套目录会判幽灵路径，根相对写法让生成的骨架自身可通过。
    out = ["| 子目录 | 一句话 | 禁忌 |", "| --- | --- | --- |"]
    for name in subdirs:
        if name in old:
            duty, taboo = old[name]
        else:
            duty = read_duty(target, base_rel, name)
            if duty:
                duty = escape_cell(duty)
            else:
                duty = PLACEHOLDER_DUTY
            taboo = "—"
        cell = escape_cell(join_rel(base_rel, name))
        out.append("| `%s/` | %s | %s |" % (cell, duty, taboo))
    return out


def write_text_exact(target, relpath, text):
    try:
        with open(os.path.join(target, relpath), "wb") as fh:
            fh.write(text.encode("utf-8"))
    except OSError:
        die("写入失败: %s" % relpath)


def plan_generated_block(target, dir_value, old, base_rel, includes, excludes):
    # --sync 与 --freshness 的唯一「应产出块」生成点：先算行集合，再套既有行原文复用。
    # 新鲜度只读模式复用本函数，保证比对基准就是 --sync 会写入的同一内容。
    subdirs = list_subdirs(target, base_rel, includes, excludes)
    generated = ["<!-- dir-readme: generated dir=%s -->" % dir_value]
    generated.extend(subdir_table_lines(subdirs, old, target, base_rel))
    generated.append("<!-- /dir-readme -->")
    return generated, subdirs


def plan_sync_file(target, rel, includes, excludes):
    raw = read_text_exact(target, rel)
    lines = split_raw_lines(raw)
    blocks, problems = find_blocks(rel, lines)
    if problems:
        return None, problems
    if not blocks:
        return {"kind": "skip", "rel": rel}, []
    eol = detect_eol(lines)
    base_rel = dir_of_readme(rel)
    new_lines = list(lines)
    added_total = 0
    removed_total = 0
    deleted = []
    for open_idx, close_idx, dir_value in reversed(blocks):
        old = parse_old_rows(new_lines[open_idx + 1:close_idx], base_rel)
        generated, subdirs = plan_generated_block(
            target, dir_value, old, base_rel, includes, excludes
        )
        last_term = new_lines[close_idx][1]
        gen = [(content, eol) for content in generated]
        gen[-1] = (gen[-1][0], last_term)
        new_lines = new_lines[:open_idx] + gen + new_lines[close_idx + 1:]
        added_total += sum(1 for name in subdirs if name not in old)
        for name in sorted(old):
            if name not in subdirs:
                removed_total += 1
                deleted.append((name, old[name][0]))
    new_text = join_raw_lines(new_lines)
    kind = "changed" if new_text != raw else "ok"
    return {
        "kind": kind,
        "rel": rel,
        "text": new_text,
        "added": added_total,
        "removed": removed_total,
        "deleted": deleted,
    }, []


def run_sync(target, candidates, includes, excludes):
    plans = []
    problems = []
    for rel in candidates:
        plan, probs = plan_sync_file(target, rel, includes, excludes)
        if probs:
            problems.extend(probs)
        else:
            plans.append(plan)
    if problems:
        emit_problems(problems)
        return 2
    for plan in plans:
        rel = plan["rel"]
        if plan["kind"] == "skip":
            sys.stdout.write("SKIP: %s: 无生成块\n" % rel)
            continue
        if plan["kind"] == "ok":
            sys.stdout.write("OK: %s: 生成块无变化\n" % rel)
            continue
        write_text_exact(target, rel, plan["text"])
        sys.stdout.write(
            "SYNC: %s: 生成块已重建（新增 %d／删除 %d）\n"
            % (rel, plan["added"], plan["removed"])
        )
        for name, duty in plan["deleted"]:
            sys.stdout.write("DEL: %s: %s: %s\n" % (rel, name, duty))
    return 0


def diff_block_lines(rel, open_idx, current, expected):
    # 逐行比对现行块（含起始／结束标记）与 --sync 应产出块。行号统一换算成文件行号：
    # 块内索引 0 = 起始标记 = 文件第 open_idx+1 行；缺失行给它在应产出块内的期望行号。
    out = []
    matcher = difflib.SequenceMatcher(None, current, expected, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        if tag in ("delete", "replace"):
            for k in range(i1, i2):
                out.append((rel, open_idx + 1 + k, "多余行", current[k]))
        if tag in ("insert", "replace"):
            for k in range(j1, j2):
                out.append((rel, open_idx + 1 + k, "缺失行", expected[k]))
    return out


def run_freshness(target, candidates, includes, excludes):
    # 只读生成块新鲜度：不写任何文件，不调用 --sync。无生成块的 README 静默跳过；
    # 块级结构异常（未闭合／重复起始／dir 不符）按 --check 同口径 exit 2。
    problems = []
    drift = []
    for rel in candidates:
        raw = read_text_exact(target, rel)
        lines = split_raw_lines(raw)
        blocks, probs = find_blocks(rel, lines)
        if probs:
            problems.extend(probs)
            continue
        if not blocks:
            continue
        base_rel = dir_of_readme(rel)
        for open_idx, close_idx, dir_value in blocks:
            current = [content for content, _ in lines[open_idx:close_idx + 1]]
            old = parse_old_rows(lines[open_idx + 1:close_idx], base_rel)
            expected, _ = plan_generated_block(
                target, dir_value, old, base_rel, includes, excludes
            )
            drift.extend(diff_block_lines(rel, open_idx, current, expected))
    if problems:
        emit_problems(problems)
        return 2
    if drift:
        for rel, line, kind, text in drift:
            sys.stderr.write("%s:%d: %s: %s\n" % (rel, line, kind, text))
        files = sorted({item[0] for item in drift})
        missing = sum(1 for item in drift if item[2] == "缺失行")
        extra = sum(1 for item in drift if item[2] == "多余行")
        sys.stderr.write(
            "SUMMARY: 生成块漂移 %d 件（缺失 %d 行／多余 %d 行）\n"
            % (len(files), missing, extra)
        )
        return 1
    return 0


def run_init(target, init_arg, includes, excludes):
    rel = normalize_dir(init_arg)
    reject_whitespace(rel, "--init 目标路径")
    base = os.path.join(target, rel) if rel else target
    if not os.path.isdir(base):
        die("--init 指向的目录不存在: %s" % (init_arg if init_arg else "."))
    rel_readme = join_rel(rel, "README.md")
    if os.path.exists(os.path.join(target, rel_readme)):
        die("--init 目标 README.md 已存在，拒绝覆盖: %s" % rel_readme)
    name = os.path.basename(base)
    subdirs = list_subdirs(target, rel, includes, excludes)
    table = subdir_table_lines(subdirs, {}, target, rel)
    block_dir = rel if rel else "."
    lines = [
        "<!-- Input: 【填写：本目录内容依赖的事实来源】。 -->",
        "<!-- Output: 【填写：本目录对外提供的导航内容】。 -->",
        "<!-- Pos: 【填写：本目录在体系中的地位】索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->",
        "",
        "# %s" % name,
        "",
        PLACEHOLDER_DUTY,
        "",
        "## 权威",
        "- 现行：【填写：本目录内具有规则效力、以本目录为唯一承载点的文件。】",
        "- 派生：【填写：由生成器或上游重建、不手改的文件及其生成来源。】",
        "",
        "## 读取禁忌",
        "- 【填写：读本目录内容前必须知道的一条禁忌（易腐陈述、别名口径、越层引用）。】",
        "",
        "## 子目录",
        "<!-- dir-readme: generated dir=%s -->" % block_dir,
    ]
    lines.extend(table)
    lines.append("<!-- /dir-readme -->")
    text = "\n".join(lines) + "\n"
    try:
        with open(os.path.join(target, rel_readme), "x", encoding="utf-8", newline="") as fh:
            fh.write(text)
    except FileExistsError:
        die("--init 目标 README.md 已存在，拒绝覆盖: %s" % rel_readme)
    except OSError:
        die("写入失败: %s" % rel_readme)
    sys.stdout.write("INIT: %s\n" % rel_readme)
    return 0


# ---------------------------------------------------------------- 迁移预演

PLACEHOLDER_AUTHORITY = "【填写：本目录的权威来源】"
PLACEHOLDER_TABOO = "【填写：一条读取禁忌】"
MIGRATE_LIMIT = 25
FILE_HEADER_KEYS = ("文件", "文件名", "文件／路径", "文件/路径")
AUTHORITY_SECTION_KEYS = ("架构", "身份与冻结依据", "身份", "定位", "权威")
TABOO_SECTION_KEYS = ("已知限制", "维护纪律", "维护规则", "边界", "读取禁忌", "限制", "约束", "禁止")
TABLE_SHAPE_REASONS = {
    "four": "四列表（表头 %s）",
    "member": "成员表（表头 %s）",
    "other": "普通表格（非成员表，未迁入）",
    "subdir": "子目录表（未迁入）",
}


def heading_key(text):
    # 节名去掉反引号与破折号后的括注：`## 已知限制（冻结态保留，不修补）` 按「已知限制」判。
    return re.split(r"[（(]", text.replace("`", ""))[0].strip()


def section_role(name):
    key = heading_key(name)
    if any(key.startswith(prefix) for prefix in AUTHORITY_SECTION_KEYS):
        return "authority"
    if any(key.startswith(prefix) for prefix in TABOO_SECTION_KEYS):
        return "taboo"
    return None


def looks_like_table_header(cells):
    if len(cells) < 2:
        return False
    if any(normalize_cell(cell) in MEMBER_HEADER_KEYS for cell in cells):
        return True
    if any(cell in ("描述", "角色合同事实源", "关键占位符") for cell in cells):
        return True
    return len(cells) == 4 and normalize_cell(cells[0]) in FILE_HEADER_KEYS


def scan_tables(body, fences):
    # 表格按「表头行＋分隔行」识别；表意已定的表头缺分隔行属残缺，fail-closed 指名行号。
    tables = []
    problems = []
    i = 0
    total = len(body)
    while i < total:
        if fences[i] or not body[i].strip().startswith("|"):
            i += 1
            continue
        start = i
        end = i
        while end + 1 < total and not fences[end + 1] and body[end + 1].strip().startswith("|"):
            end += 1
        header = table_cells(body[start])
        if not (end > start and is_separator(body[start + 1])):
            if looks_like_table_header(header):
                problems.append((start + 1, "表头残缺（表头后缺少分隔行）"))
            i = end + 1
            continue
        if is_subdir_header(body[start]):
            kind = "subdir"
        elif len(header) == 4 and normalize_cell(header[0]) in FILE_HEADER_KEYS:
            kind = "four"
        elif any(normalize_cell(cell) in MEMBER_HEADER_KEYS for cell in header):
            kind = "member"
        else:
            kind = "other"
        tables.append({"start": start, "end": end, "kind": kind, "header": header})
        i = end + 1
    return tables, problems


def merge_drop_ranges(contents, labels, carried):
    # 空行并入相邻同因段；被搬运的行截断范围，避免 DROP 区间把已搬运内容算进去。
    ranges = []
    current = None
    for i in range(len(contents)):
        if i in carried:
            if current is not None:
                ranges.append(current)
                current = None
            continue
        label = labels.get(i)
        if label is None:
            continue
        if current is not None and current[2] == label:
            current[1] = i
            continue
        if current is not None:
            ranges.append(current)
        current = [i, i, label]
    if current is not None:
        ranges.append(current)
    return [(start + 1, end + 1, reason) for start, end, reason in ranges]


def plan_migrate_file(target, rel, contents, body, fences, includes, excludes):
    h1 = None
    for i, line in enumerate(body):
        if not fences[i] and H1_RE.match(line):
            h1 = i
            break
    if h1 is None:
        return None, [(rel, 1, "缺少一级标题 # <目录名>（无法确定形态与职责句）")]

    tables, problems = scan_tables(body, fences)
    if problems:
        return None, [(rel, line_no, reason) for line_no, reason in problems]

    if any(table["kind"] == "four" for table in tables):
        shape = "four-column"
    elif any(table["kind"] == "member" for table in tables):
        shape = "member-table"
    else:
        shape = "no-table"

    duty = None
    for i in range(h1 + 1, len(body)):
        if fences[i]:
            continue
        line = body[i].strip()
        if not line:
            continue
        if re.match(r"^#{1,6}\s", line):
            break
        if line.startswith("|"):
            continue
        duty = i
        break

    sections = []
    for i, line in enumerate(body):
        if fences[i]:
            continue
        match = H2_RE.match(line)
        if match:
            sections.append([i, len(body) - 1, match.group(1).strip()])
    for idx in range(len(sections) - 1):
        sections[idx][1] = sections[idx + 1][0] - 1

    carried = {h1}
    if duty is not None:
        carried.add(duty)
    prefix = []
    for i in range(h1):
        if not contents[i].strip() or not body[i].strip():
            carried.add(i)
            prefix.append(i)

    labels = {}
    for table in tables:
        reason = TABLE_SHAPE_REASONS[table["kind"]]
        if "%s" in reason:
            reason = reason % "｜".join(table["header"])
        for i in range(table["start"], table["end"] + 1):
            labels[i] = reason

    authority = []
    taboo = []
    for start, end, name in sections:
        role = section_role(name)
        if role is None:
            reason = "未迁入节：## %s（非权威／禁忌类）" % name
            labels.setdefault(start, reason)
            for i in range(start + 1, end + 1):
                if contents[i].strip():
                    labels.setdefault(i, reason)
            continue
        labels[start] = "原节标题 ## %s（列表项已迁入）" % name
        bucket = authority if role == "authority" else taboo
        for i in range(start + 1, end + 1):
            line = contents[i]
            if not line.strip():
                continue
            if re.match(r"^\s*[-*+]\s", line):
                carried.add(i)
                bucket.append(i)
                continue
            labels.setdefault(i, "段落（非列表项，未迁入）")

    for i in range(len(contents)):
        if i in carried or i in labels or not contents[i].strip():
            continue
        labels[i] = "H1 之前的元数据块（未迁入）" if i < h1 else "段落（未迁入）"

    out = [contents[i] for i in prefix]
    while out and not out[-1].strip():
        out.pop()
    if out:
        out.append("")
    out.append(contents[h1])
    out.append("")
    gaps = []
    if duty is None:
        out.append(PLACEHOLDER_DUTY)
        gaps.append("职责句")
    else:
        out.append(contents[duty])
    out.append("")
    out.append("## 权威")
    if authority:
        out.extend(contents[i] for i in authority)
    else:
        out.append("- " + PLACEHOLDER_AUTHORITY)
        gaps.append("「权威」列表项")
    out.append("")
    out.append("## 读取禁忌")
    if taboo:
        out.extend(contents[i] for i in taboo)
    else:
        out.append("- " + PLACEHOLDER_TABOO)
        gaps.append("「读取禁忌」列表项")
    out.append("")
    out.append("## 子目录")
    base_rel = dir_of_readme(rel)
    block_dir = base_rel if base_rel else "."
    out.append("<!-- dir-readme: generated dir=%s -->" % block_dir)
    out.extend(subdir_table_lines(list_subdirs(target, base_rel, includes, excludes), {}, target, base_rel))
    out.append("<!-- /dir-readme -->")

    notes = []
    if len(out) > MIGRATE_LIMIT:
        notes.append("建议内容 %d 行，超过上限 %d，需人工裁剪" % (len(out), MIGRATE_LIMIT))
    if gaps:
        notes.append("原文缺%s，建议内容留【填写：…】占位" % "、".join(gaps))

    return {
        "rel": rel,
        "shape": shape,
        "old": contents,
        "new": out,
        "drops": merge_drop_ranges(contents, labels, carried),
        "notes": notes,
    }, []


def render_migrate_plan(plan):
    rel = plan["rel"]
    lines = [
        "MIGRATE: %s: %s: %d→%d" % (rel, plan["shape"], len(plan["old"]), len(plan["new"]))
    ]
    for note in plan["notes"]:
        lines.append("NOTE: %s: %s" % (rel, note))
    for start, end, reason in plan["drops"]:
        lines.append("DROP: %s: %d-%d 行: %s" % (rel, start, end, reason))
    lines.extend(
        difflib.unified_diff(
            plan["old"],
            plan["new"],
            fromfile="a/" + rel,
            tofile="b/" + rel,
            lineterm="",
            n=3,
        )
    )
    return "\n".join(lines)


def run_migrate(target, candidates, includes, excludes, detail):
    before = {}
    plans = []
    problems = []
    for rel in candidates:
        try:
            with open(os.path.join(target, rel), "rb") as fh:
                data = fh.read()
        except OSError:
            problems.append((rel, 1, "README 不可读"))
            continue
        before[rel] = hashlib.sha256(data).hexdigest()
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            problems.append((rel, 1, "README 不是 UTF-8"))
            continue
        if not check_file(target, rel):
            continue
        contents = [content for content, _ in split_raw_lines(text)]
        body = strip_comments(contents)
        plan, probs = plan_migrate_file(
            target, rel, contents, body, fenced_mask(body), includes, excludes
        )
        if probs:
            problems.extend(probs)
        else:
            plans.append(plan)
    if problems:
        emit_problems(problems)
        return 2
    if not plans:
        return 0

    after = {}
    for rel in before:
        try:
            with open(os.path.join(target, rel), "rb") as fh:
                after[rel] = hashlib.sha256(fh.read()).hexdigest()
        except OSError:
            after[rel] = ""
    changed = [rel for rel in before if before[rel] != after.get(rel)]
    if changed:
        for rel in sorted(changed):
            sys.stderr.write("%s:1: 预演前后 sha256 不一致（只读被破坏）\n" % rel)
        return 2

    counts = {"four-column": 0, "member-table": 0, "no-table": 0}
    for plan in plans:
        counts[plan["shape"]] += 1
    if detail:
        blocks = [render_migrate_plan(plan) for plan in plans]
        sys.stdout.write("\n\n".join(blocks) + "\n")
        sys.stdout.write(
            "SUMMARY: 迁移 %d 件（four-column %d／member-table %d／no-table %d）；零写入 sha256 %d/%d 一致\n"
            % (
                len(plans),
                counts["four-column"],
                counts["member-table"],
                counts["no-table"],
                len(before),
                len(before),
            )
        )
        return 0

    over = [(plan["rel"], len(plan["new"])) for plan in plans if len(plan["new"]) > MIGRATE_LIMIT]
    gap_duty = 0
    gap_sections = 0
    dropped = 0
    for plan in plans:
        notes = plan["notes"]
        if any("职责句" in note for note in notes):
            gap_duty += 1
        if any("「权威」列表项" in note or "「读取禁忌」列表项" in note for note in notes):
            gap_sections += 1
        dropped += len(plan["drops"])
    lines = [
        "SUMMARY: 迁移 %d 件（member-table %d／four-column %d／no-table %d）"
        % (len(plans), counts["member-table"], counts["four-column"], counts["no-table"]),
        "ZERO-WRITE: %d/%d sha256 一致" % (len(before), len(before)),
    ]
    if over:
        shown = "、".join("%s %d" % (rel, size) for rel, size in over[:5])
        if len(over) > 5:
            shown += " 等 %d 件" % len(over)
        lines.append(
            "NEEDS-CONFIRM: %d 件超 %d 行（%s）" % (len(over), MIGRATE_LIMIT, shown)
        )
    if gap_duty:
        lines.append("NEEDS-CONFIRM: %d 件缺职责句，建议留占位" % gap_duty)
    if gap_sections:
        lines.append(
            "NEEDS-CONFIRM: %d 件缺「权威」或「读取禁忌」列表项，建议留占位" % gap_sections
        )
    if dropped:
        lines.append(
            "NEEDS-CONFIRM: %d 段内容未迁入（DROP），需人工判是否升格" % dropped
        )
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


def check_file(target, relpath):
    try:
        with open(os.path.join(target, relpath), "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        die("README 不可读: %s" % relpath)

    lines = text.splitlines()
    body = strip_comments(lines)
    problems = []

    def add(line, reason):
        problems.append((relpath, line, reason))

    h1 = None
    for i, line in enumerate(body, 1):
        match = H1_RE.match(line)
        if match:
            h1 = i
            break
    if h1 is None:
        add(1, "缺少一级标题 # <目录名>（无四段标记可判）")
        return problems

    h2 = {}
    for i in range(h1, len(body)):
        line = body[i]
        match = H2_RE.match(line)
        if match:
            name = match.group(1).strip()
            if name not in h2:
                h2[name] = i + 1

    duty = None
    for i in range(h1, len(body)):
        line = body[i].strip()
        if not line:
            continue
        if H1_RE.match(line) or H2_RE.match(line):
            break
        if line.startswith("|"):
            continue
        duty = i + 1
        break
    if duty is None:
        add(h1, "缺少职责句（# 标题之后、## 权威 之前的一句话职责）")

    for name in ("权威", "读取禁忌", "子目录"):
        if name not in h2:
            add(h1, "缺少段：## %s" % name)

    if "子目录" in h2:
        header_line = None
        for i in range(h2["子目录"], len(body)):
            line = body[i]
            if H2_RE.match(line):
                break
            if is_subdir_header(line):
                header_line = i
                break
        if header_line is None:
            add(h2["子目录"], "子目录段缺少表头 | 子目录 | 一句话 | 禁忌 |")
        elif header_line + 1 >= len(body) or not is_separator(body[header_line + 1]):
            add(min(header_line + 2, len(body)), "子目录表头缺少分隔行 | --- | --- | --- |")

    if len(lines) > MIGRATE_LIMIT:
        add(26, "总行数 %d 超过上限 %d" % (len(lines), MIGRATE_LIMIT))

    body_fences = fenced_mask(body)
    for i, line in enumerate(body, 1):
        if body_fences[i - 1]:
            continue
        if PLACEHOLDER_MARK in strip_inline_code(line):
            add(i, "判断位未填（【填写：…】占位）")

    for i, line in enumerate(body, 1):
        if re.match(r"^##\s*成员", line):
            add(i, "保留成员表段（## 成员），目录 README 不登记成员清单")
            continue
        if line.strip().startswith("|"):
            next_line = body[i] if i < len(body) else ""
            if is_member_header(line) and is_separator(next_line):
                add(i, "含成员表（表头为「名字／成员／文件」）")

    for i, line in enumerate(body, 1):
        for pattern, kind in COUNT_RES:
            match = pattern.search(line)
            if not match:
                continue
            if pattern is COUNT_LINE_RE and not is_line_count(line, match):
                continue
            add(i, "含%s：%s" % (kind, match.group(0)))
            break

    for i, line in enumerate(body, 1):
        for span in re.findall(r"`([^`\n]+)`", line):
            token = span.strip()
            if not token:
                continue
            if any(ch in token for ch in "*?<>=\\"):
                continue
            if "://" in token or ":" in token:
                continue
            if token.startswith("/") or token.startswith("~") or token.startswith("#") or token.startswith("-"):
                continue
            if any(ch.isspace() for ch in token):
                continue
            if NA_RE.match(token):
                continue
            if "/" in token:
                base = target
            elif BARE_FILE_RE.match(token):
                base = os.path.join(target, dir_of_readme(relpath))
            else:
                continue
            if token.startswith("./"):
                token = token[2:]
            norm = os.path.normpath(token)
            if norm == ".." or norm.startswith("../"):
                add(i, "引用路径越出目标根: %s" % span)
                continue
            if not os.path.exists(os.path.join(base, norm)):
                add(i, "引用路径不存在: %s" % span)

    open_line = None
    open_dir = None
    expected = dir_of_readme(relpath)
    accepted = {"", ".", "./"}
    if expected:
        accepted.update({expected, "./" + expected})
    raw_fences = fenced_mask(lines)
    for i, raw in enumerate(lines, 1):
        if raw_fences[i - 1]:
            continue
        line = raw.strip()
        match = OPEN_RE.match(line)
        if match:
            if open_line is not None:
                add(i, "生成块重复起始标记（上一处在第 %d 行）" % open_line)
            open_line = i
            open_dir = match.group(1)
            continue
        if CLOSE_RE.match(line):
            if open_line is None:
                add(i, "生成块结束标记缺少起始标记")
            else:
                if open_dir not in accepted:
                    add(open_line, "生成块 dir 值不符: %s（应为 %s）" % (open_dir, expected or "."))
                open_line = None
                open_dir = None
    if open_line is not None:
        add(open_line, "生成块未闭合（缺少 <!-- /dir-readme -->）")

    return problems


def emit_problems(problems):
    for path, line, reason in sorted(problems, key=lambda item: (item[0], item[1], item[2])):
        sys.stderr.write("%s:%d: %s\n" % (path, line, reason))


# ---------------------------------------------------------------- 单目录素材包

BRIEF_GROUP_ORDER = {"目录": 0, "成员": 1, "子目录内": 2}


def artifact_path_text(value):
    # artifacts 的 path 允许在路径后附括注（镜像说明、迁移注记）：素材包只取路径本体，
    # 括注是说明文字，不是条目路径，也不参与作用域判定。
    text = value.strip()
    text = re.split(r"[（(]", text, 1)[0].strip()
    text = text.rstrip("/")
    if not text or text.startswith("/") or text.startswith("~"):
        return None
    return text


def artifact_path_norm(text):
    # 聚合登记的 glob（如 facts/requirements/tickets/*.md）按其所在目录归属。
    base = text.rsplit("/", 1)[0] if "*" in text and "/" in text else text
    if "*" in base:
        return None
    parts = [part for part in base.split("/") if part not in ("", ".")]
    if ".." in parts:
        return None
    return "/".join(parts)


def load_artifacts_index(path):
    # 只读平铺条目：本索引的登记行是 `  - ` 起始的条目加四空格缩进的标量字段，无跨行标量；
    # 任意 `  - ` 行都是条目边界（不能只认 `- id:`，否则缺 id 的条目会被并入上一条）；
    # 缺件、非 UTF-8、缺 artifacts 段、零条目或任一条目缺 id/path 一律整体降级，不部分采用。
    try:
        with open(path, "r", encoding="utf-8") as fh:
            raw = fh.read().splitlines()
    except FileNotFoundError:
        return None, "artifacts 索引缺失"
    except OSError:
        return None, "artifacts 索引不可读"
    except UnicodeDecodeError:
        return None, "artifacts 索引不是 UTF-8"
    entries = []
    current = None
    saw_section = False
    in_section = False
    for line in raw:
        if line.strip() == "artifacts:":
            saw_section = True
            in_section = True
            continue
        if in_section and line and not line[0].isspace() and not line.startswith("#"):
            if current is not None:
                entries.append(current)
                current = None
            in_section = False
        if not in_section:
            continue
        match = re.match(r"^  - (.*)$", line)
        if match:
            if current is not None:
                entries.append(current)
            rest = match.group(1).strip()
            current = {}
            key_match = re.match(r"([A-Za-z_]+):\s*(.*?)\s*$", rest)
            if key_match:
                current[key_match.group(1)] = key_match.group(2)
            else:
                current["id"] = ""
            continue
        if current is None:
            continue
        match = re.match(r"^    ([A-Za-z_]+):\s*(.*?)\s*$", line)
        if not match:
            continue
        key, value = match.group(1), match.group(2)
        if key in ("path", "kind", "authority", "read_when"):
            current[key] = value
    if current is not None:
        entries.append(current)
    if not saw_section:
        return None, "artifacts 索引不可解析（缺 artifacts 段）"
    if not entries:
        return None, "artifacts 索引无有效条目"
    for entry in entries:
        if not entry.get("id") or not entry.get("path"):
            return None, "artifacts 索引条目缺 id 或 path"
    return entries, None


def brief_entries(rel, entries):
    selected = []
    for entry in entries:
        text = artifact_path_text(entry["path"])
        if text is None:
            continue
        norm = artifact_path_norm(text)
        if norm is None:
            continue
        if rel and norm != rel and not norm.startswith(rel + "/"):
            continue
        sub = "" if norm == rel else (norm[len(rel) + 1:] if rel else norm)
        if norm == rel:
            group = "目录"
        elif "/" not in sub:
            group = "成员"
        else:
            group = "子目录内"
        selected.append((group, text, entry))
    selected.sort(key=lambda item: (BRIEF_GROUP_ORDER[item[0]], item[1], item[2]["id"]))
    return selected


def render_brief_listing(target, rel):
    base = os.path.join(target, rel) if rel else target
    try:
        names = sorted(name for name in os.listdir(base) if name != ".git")
    except OSError:
        die("目录不可读: %s" % (rel or "."))
    lines = [
        "## BRIEF 目录清单",
        "- 目标目录：`%s`（一级成员 %d 个）" % (rel or ".", len(names)),
    ]
    if not names:
        lines.append("- （空目录）")
    for name in names:
        path = os.path.join(base, name)
        if os.path.islink(path):
            lines.append("- l `%s`（符号链接，不跟随）" % name)
            continue
        if os.path.isdir(path):
            has_readme = os.path.isfile(os.path.join(path, "README.md"))
            lines.append(
                "- d `%s/`（README.md：%s）" % (name, "有" if has_readme else "无")
            )
            continue
        if os.path.isfile(path):
            try:
                with open(path, "rb") as fh:
                    data = fh.read()
            except OSError:
                lines.append("- f `%s`（不可读）" % name)
                continue
            lines.append(
                "- f `%s`（%d 行，%d 字节）" % (name, len(data.splitlines()), len(data))
            )
            continue
        lines.append("- o `%s`（非常规文件）" % name)
    return lines


def render_brief_evidence(rel, entries):
    lines = [
        "## BRIEF 判断证据",
        "- 来源：artifacts 索引条目（条目 id 可回溯；下列条目路径均在本目录内）",
        "- 注：kind／authority／read_when 为原文；authority 是权威层级描述（约 70 字），"
        "不是「哪份说了算」，须结合本目录文件内容改写，不得原文照抄；目录外指针原样保留，"
        "供写指针用，不得据此读取或转述其内容。",
    ]
    selected = brief_entries(rel, entries)
    if not selected:
        lines.append("- （本目录及目录内没有 artifacts 条目）")
        return lines
    for group, text, entry in selected:
        lines.append("- [%s] 条目 %s：`%s`" % (group, entry["id"], text))
        for key in ("kind", "authority", "read_when"):
            value = entry.get(key, "")
            if value:
                lines.append("  %s: %s" % (key, value))
            else:
                lines.append("  %s: （缺）" % key)
    return lines


def readme_state(target, rel):
    """结构化 README 现状（不解析人类消息）：exists/readable/line_count/no_h1/
    missing_sections/placeholder_lines。"""
    readme_rel = join_rel(rel, "README.md")
    path = os.path.join(target, readme_rel)
    state = {"exists": False, "readable": False, "line_count": 0,
             "no_h1": False, "missing_sections": [], "placeholder_lines": []}
    if not os.path.isfile(path):
        return state
    state["exists"] = True
    try:
        with open(path, "rb") as fh:
            data = fh.read()
        text = data.decode("utf-8", "replace")
    except OSError:
        return state
    state["readable"] = True
    lines = text.splitlines()
    state["line_count"] = len(lines)
    body = strip_comments(lines)
    h1 = None
    for i, line in enumerate(body, 1):
        if H1_RE.match(line):
            h1 = i
            break
    if h1 is None:
        state["no_h1"] = True
        return state
    names = set()
    for i in range(h1, len(body)):
        match = H2_RE.match(body[i])
        if match:
            names.add(match.group(1).strip())
    state["missing_sections"] = [n for n in ("权威", "读取禁忌", "子目录") if n not in names]
    fences = fenced_mask(body)
    for i, line in enumerate(body, 1):
        if fences[i - 1]:
            continue
        if PLACEHOLDER_MARK in strip_inline_code(line):
            state["placeholder_lines"].append(i)
    return state


def render_brief_state(target, rel):
    readme_rel = join_rel(rel, "README.md")
    state = readme_state(target, rel)
    lines = ["## BRIEF 现状"]
    if not state["exists"]:
        lines.append("- README.md：不存在（可经 --init 起骨架，再按生成约定填写判断段）")
        lines.append("- CHECK: 无文件可校验")
        return lines, state
    if not state["readable"]:
        lines.append("- README.md：存在但不可读")
        lines.append("- CHECK: 不可读")
        return lines, state
    lines.append("- README.md：存在（%d 行）" % state["line_count"])
    problems = check_file(target, readme_rel)
    if state["no_h1"]:
        lines.append("- 四段：无法判定（缺一级标题）")
    elif state["missing_sections"]:
        lines.append("- 四段：缺 %s" % "、".join("## " + n for n in state["missing_sections"]))
    else:
        lines.append("- 四段：齐全")
    placeholders = state["placeholder_lines"]
    lines.append(
        "- 占位：%s"
        % ("无" if not placeholders else "、".join("第 %d 行" % n for n in sorted(set(placeholders))))
    )
    if not problems:
        lines.append("- CHECK: 通过")
    else:
        lines.append("- CHECK: 不合规（%d 条）" % len(problems))
        for problem_path, line_no, reason in problems:
            lines.append("- CHECK 详情：%s:%d: %s" % (problem_path, line_no, reason))
    return lines, state


def render_brief_conventions():
    return [
        "## BRIEF 生成约定",
        "- 结构：三行工作登记注释（Input／Output／Pos）＋一级标题＋一句话职责＋## 权威＋"
        "## 读取禁忌＋## 子目录；总行数 ≤ %d。" % MIGRATE_LIMIT,
        "- 头注：保留 Input／Output／Pos 三行，只把【填写：…】替换为事实，不删行。",
        "- 职责句：H1 后一句话，写本目录承载什么、服务谁；判断必须能追到本目录内文件或"
        "上方 artifacts 条目。",
        "- ## 权威：两条列表——`- 现行：` 写本目录内以本目录为唯一承载点、有规则效力的"
        "文件及作用；`- 派生：` 写由生成器或上游重建、不手改的文件及生成来源；"
        "不得照抄 authority 原文。",
        "- ## 读取禁忌：至少一条列表项，写读本目录前必须知道的易腐陈述、别名口径或"
        "越层引用；能追到本目录内文件或 artifacts 条目。",
        "- ## 子目录：保留生成块与 `| 子目录 | 一句话 | 禁忌 |` 三列表；判断文字写在"
        "块外，块内由 --sync 重建。",
        "- 禁止：成员表（含「名字／成员／文件」表头与 ## 成员 段）；计数句"
        "（共 N 件／N 个脚本／N 行／N 份合同／N 个成员等）；状态句（当前没有）；"
        "目标目录以外文件的路径引用（内容约定）。",
        "- 路径引用：含 `/` 按目标根解析，裸文件名按本目录解析；路径记号的段可含"
        "非 ASCII（如 `rules/规则`），单段 `name/` 同样按路径处理；`--check` 校验存在性"
        "与目标根越界，不校验是否越出本目录，目录外引用须自行避免。",
        "- 判断不出时写【填写：…】占位，不编造职责或禁忌；占位会被 --check 判为未填。",
    ]


def run_brief(target, brief_arg):
    rel = normalize_dir(brief_arg)
    if not os.path.isdir(os.path.join(target, rel) if rel else target):
        die("--brief 指向的目录不存在: %s" % (brief_arg if brief_arg else "."))
    index_path = os.path.join(target, "facts", "project", "artifacts.yaml")
    entries, reason = load_artifacts_index(index_path)
    lines = ["BRIEF: `%s`（只读素材包，零写入）" % (rel or ".")]
    if entries is None:
        lines.append("DEGRADED: %s；本次仅输出目录清单与生成约定" % reason)
        lines.extend(render_brief_listing(target, rel))
        lines.extend(render_brief_conventions())
    else:
        lines.extend(render_brief_listing(target, rel))
        lines.extend(render_brief_evidence(rel, entries))
        state_lines, _state = render_brief_state(target, rel)
        lines.extend(state_lines)
        lines.extend(render_brief_conventions())
    sys.stdout.write("\n".join(lines) + "\n")
    return 0


def require_value(argv, i, arg, hint=""):
    """取选项值：缺值（越界／空串／下一参数为选项）即 die，统一缺参数值检查。"""
    if i + 1 >= len(argv):
        die("%s 缺参数值%s" % (arg, hint))
    value = argv[i + 1]
    if value == "" or value.startswith("--"):
        die("%s 缺参数值%s" % (arg, hint))
    return value


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
