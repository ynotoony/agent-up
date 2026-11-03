#!/bin/sh
# Input: 目标仓库根目录（缺省当前目录）、可选单目录／新建目录、范围规则文件与模式开关；
#        规则文件缺省为脚本同目录 dir-readme.rules，可由 --rules 覆盖（消费者仓库自定）。
# Output: --check 模式逐条校验目标范围内既有目录 README.md 的四段式契约——四段齐全
#         （职责句／## 权威／## 读取禁忌／## 子目录及其三列表头）、总行数 ≤ 25、无成员表、
#         无计数与状态句、正文反引号路径存在（含 / 按目标根；形如文件名的裸名按 README
#         所在目录）、正文裸露的【填写：…】占位（HTML 注释、行内代码段与围栏代码块内不算）、
#         生成块标记成对（围栏代码块内标记不算块）；全部通过 exit 0 且零
#         输出，不合规逐条输出 `path:line: 原因` 且 exit 2，异常形态 fail-closed exit 2。
#         --sync 只重建生成块内的子目录表（块外逐字节不动，无生成块的 README 不新建
#         不修改并输出 SKIP）；--init 为新目录写四段骨架（判断位留【填写：…】）。
#         --init 与 --sync --dir 的目录路径规范化后含空白即 exit 2 零写入（范围规则与
#         生成块标记均以空白分隔，含空白的目录二者都无法唯一表示）。
# Pos: 目录 README 结构校验、生成块同步与骨架生成器（Python 3 标准库实现，壳层只做
#      解释器定位与转调）；契约与四段式骨架见 references/templates/dir-README.md.tmpl，
#      范围见同目录 dir-readme.rules；两件与本目录 README.md 成员表三处登记须同步。

set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
if ! command -v python3 >/dev/null 2>&1; then
  printf 'generate-dir-readmes: FAIL: python3 不可用（本脚本以 Python 3 标准库实现）\n' >&2
  exit 2
fi
exec python3 - "$here" "$@" <<'PY'
import fnmatch
import os
import re
import sys

USAGE = """用法: generate-dir-readmes.sh [--target <repo-root>] [--dir <rel>] [--rules <path>]
                            [--check | --sync | --init <rel>]
参数:
  --target <repo-root>  目标仓库根目录；缺省取当前目录。
  --dir <rel>           只处理该目录（目标根相对路径）的 README.md；--init 时不可用。
  --rules <path>        范围规则文件；缺省取脚本同目录 dir-readme.rules。
  -h / --help           打印本用法。
模式（互斥，缺省 --check）:
  --check               结构校验，零写入。
  --sync                重建既有生成块（<!-- dir-readme: generated dir=<rel> --> 至
                        <!-- /dir-readme -->）内的子目录表；块外逐字节不动。无生成块的
                        README 不新建、不修改，逐文件输出 `SKIP: <path>: 无生成块`。
                        新增行的一句话取该子目录 README 的职责句，取不到写
                        【填写：一句话职责】；禁忌取不到写 —。删除的行逐行输出 DEL。
                        围栏代码块（```／~~~）内的标记不算生成块，不读不写。
  --init <rel-dir>      为 <target>/<rel-dir> 新建 README.md 四段骨架，判断位留
                        【填写：…】；目录不存在或 README.md 已存在即 exit 2 零写入。
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
  0  校验通过／同步完成／骨架已写入（含无生成块的 SKIP）。
  1  保留（当前不产生）。
  2  不合规或异常形态（无文件、无四段标记可判、规则文件损坏、目标路径不存在、
     生成块未闭合或重复起始、--init 目标已存在、--init／--sync --dir 路径含空白、
     模式互斥冲突），fail-closed，逐条输出 `path:line: 原因`，写入模式零写入。
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
    i = 1
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            sys.stdout.write(USAGE)
            sys.exit(0)
        if arg == "--check":
            explicit.append("check")
            i += 1
            continue
        if arg == "--sync":
            explicit.append("sync")
            i += 1
            continue
        if arg == "--init":
            if i + 1 >= len(argv):
                die("%s 缺参数值" % arg)
            value = argv[i + 1]
            if value == "" or value.startswith("--"):
                die("%s 缺参数值" % arg)
            explicit.append("init")
            init_dir = value
            i += 2
            continue
        if arg in ("--target", "--dir", "--rules"):
            if i + 1 >= len(argv):
                die("%s 缺参数值" % arg)
            value = argv[i + 1]
            if value == "" or value.startswith("--"):
                die("%s 缺参数值" % arg)
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
        die("--check／--sync／--init 互斥，只能给一个")
    mode = explicit[0] if explicit else "check"
    if mode == "init" and only is not None:
        die("--init 不接受 --dir（目标目录由 --init 参数给出）")
    return (target if target is not None else "."), only, rules, mode, init_dir


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
        subdirs = list_subdirs(target, base_rel, includes, excludes)
        generated = ["<!-- dir-readme: generated dir=%s -->" % dir_value]
        generated.extend(subdir_table_lines(subdirs, old, target, base_rel))
        generated.append("<!-- /dir-readme -->")
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

    if len(lines) > 25:
        add(26, "总行数 %d 超过上限 25" % len(lines))

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


def main(argv):
    target_arg, only_arg, rules_path, mode, init_arg = parse_args(argv)
    target = os.path.abspath(target_arg)
    if not os.path.isdir(target):
        die("目标路径不存在或不是目录: %s" % target_arg)
    includes, excludes = load_rules(rules_path)

    if mode == "init":
        return run_init(target, init_arg, includes, excludes)

    candidates = resolve_candidates(target, only_arg, includes, excludes, rules_path, mode)
    if mode == "sync":
        return run_sync(target, candidates, includes, excludes)

    problems = []
    for rel in candidates:
        problems.extend(check_file(target, rel))

    if problems:
        emit_problems(problems)
        return 2
    return 0


sys.exit(main(sys.argv[1:]))
PY
