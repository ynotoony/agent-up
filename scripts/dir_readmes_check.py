"""generate-dir-readmes.sh --check／--freshness 实现（票 290 拆分；同目录模块）.

结构校验（check_file）与生成块新鲜度只读断言（run_freshness／diff_block_lines）共用同一
四段式判定面与 --sync 的应产出块生成函数。
"""
import difflib
import os
import re
import sys

from dir_readmes_model import (
    BARE_FILE_RE,
    CLOSE_RE,
    COUNT_LINE_RE,
    COUNT_RES,
    H1_RE,
    H2_RE,
    MIGRATE_LIMIT,
    NA_RE,
    OPEN_RE,
    PLACEHOLDER_MARK,
    die,
    dir_of_readme,
    emit_problems,
    fenced_mask,
    find_blocks,
    is_line_count,
    is_member_header,
    is_separator,
    is_subdir_header,
    parse_old_rows,
    plan_generated_block,
    read_text_exact,
    split_raw_lines,
    strip_comments,
    strip_inline_code,
)


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
