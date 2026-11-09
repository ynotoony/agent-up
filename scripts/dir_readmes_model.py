"""generate-dir-readmes.sh 共享 markdown 模型（票 290 拆分；同目录模块，不直接执行）.

承载目录 README 四段式契约的公共 markdown 模型：范围规则解析与候选集、表格/围栏/行尾
原语、生成块发现与应产出块生成、问题输出。被主壳与 check/sync/migrate/brief 四模块 import。
"""
import fnmatch
import os
import re
import sys


MIGRATE_LIMIT = 25

PLACEHOLDER_DUTY = "【填写：一句话职责】"
PLACEHOLDER_MARK = "【填写："


def die(msg):
    sys.stderr.write("generate-dir-readmes: FAIL: %s\n" % msg)
    sys.exit(2)


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


def emit_problems(problems):
    for path, line, reason in sorted(problems, key=lambda item: (item[0], item[1], item[2])):
        sys.stderr.write("%s:%d: %s\n" % (path, line, reason))
