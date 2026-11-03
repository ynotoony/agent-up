#!/bin/sh
# Input: 目标仓库根目录（缺省当前目录）、可选单目录、范围规则文件与 --check 开关；
#        规则文件缺省为脚本同目录 dir-readme.rules，可由 --rules 覆盖（消费者仓库自定）。
# Output: --check 模式逐条校验目标范围内既有目录 README.md 的四段式契约——四段齐全
#         （职责句／## 权威／## 读取禁忌／## 子目录及其三列表头）、总行数 ≤ 25、无成员表、
#         无计数与状态句、正文反引号路径存在（含 / 按目标根；形如文件名的裸名按 README
#         所在目录）、生成块标记成对；全部通过 exit 0 且零
#         输出，不合规逐条输出 `path:line: 原因` 且 exit 2，异常形态 fail-closed exit 2。
#         本版只做 --check，不写文件、不生成成员清单。
# Pos: 目录 README 结构校验器（Python 3 标准库实现，壳层只做解释器定位与转调）；
#      契约与四段式骨架见 references/templates/dir-README.md.tmpl，范围见同目录
#      dir-readme.rules；两件与本目录 README.md 成员表三处登记须同步。

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

USAGE = """用法: generate-dir-readmes.sh [--target <repo-root>] [--dir <rel>] [--rules <path>] [--check]
参数:
  --target <repo-root>  目标仓库根目录；缺省取当前目录。
  --dir <rel>           只校验该目录（目标根相对路径）的 README.md。
  --rules <path>        范围规则文件；缺省取脚本同目录 dir-readme.rules。
  --check               结构校验（缺省行为；保留开关以显式表达意图）。
  -h / --help           打印本用法。
断言:
  1. 四段齐全：一句话职责、## 权威、## 读取禁忌、## 子目录（三列表头＋分隔行）。
  2. 总行数 ≤ 25。
  3. 无成员表（## 成员段，或表头任一单元去空白、反引号与 ** 后整格等于「名字／成员／文件」的表格；契约子目录表除外）。
  4. 无计数与状态句（共 N 件／N 个脚本／中文数字个脚本／N 行（「一行」「第 N 行」不算）／N 份合同／N 个成员·文件·票／当前没有）。
  5. 正文反引号包裹的路径存在：含 / 的按目标根校验；不含 / 但形如文件名的
     （如 missing-file.md）按 README 所在目录校验；其余裸标识符（--flag、true）与
     N/A（大小写不敏感，可带理由）忽略。
     通配、绝对路径、URL 一律忽略。
退出码:
  0  全部通过，零输出。
  1  生成结果与既有 README 漂移（保留给后续生成/同步模式；本版不产生）。
  2  不合规或异常形态（无文件、无四段标记可判、规则文件损坏、目标路径不存在），
     逐条输出 `path:line: 原因`，fail-closed。
"""


def die(msg):
    sys.stderr.write("generate-dir-readmes: FAIL: %s\n" % msg)
    sys.exit(2)


def parse_args(argv):
    here = argv[0]
    target = None
    only = None
    rules = os.path.join(here, "dir-readme.rules")
    i = 1
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            sys.stdout.write(USAGE)
            sys.exit(0)
        if arg == "--check":
            i += 1
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
    return (target if target is not None else "."), only, rules


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
    for i, raw in enumerate(lines, 1):
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


def main(argv):
    target_arg, only_arg, rules_path = parse_args(argv)
    target = os.path.abspath(target_arg)
    if not os.path.isdir(target):
        die("目标路径不存在或不是目录: %s" % target_arg)
    includes, excludes = load_rules(rules_path)

    if only_arg is not None:
        rel = normalize_dir(only_arg)
        if not os.path.isdir(os.path.join(target, rel)):
            die("--dir 指向的目录不存在: %s" % (only_arg if only_arg else "."))
        if not in_scope(rel, includes, excludes):
            die("--dir 指向的目录不在规则范围内: %s" % (rel or "."))
        candidates = [join_rel(rel, "README.md")]
        if not os.path.isfile(os.path.join(target, candidates[0])):
            die("无文件：目录下没有 README.md: %s" % (rel or "."))
    else:
        candidates = collect_readmes(target, includes, excludes)
        if not candidates:
            die("无文件：目标范围内未找到 README.md（规则文件: %s）" % rules_path)

    problems = []
    for rel in candidates:
        problems.extend(check_file(target, rel))

    if problems:
        for path, line, reason in sorted(problems, key=lambda item: (item[0], item[1], item[2])):
            sys.stderr.write("%s:%d: %s\n" % (path, line, reason))
        sys.exit(2)
    return 0


sys.exit(main(sys.argv[1:]))
PY
