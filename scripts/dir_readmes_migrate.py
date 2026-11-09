"""generate-dir-readmes.sh --migrate-dry-run 实现（票 290 拆分；同目录模块）.

旧格式迁移只读预演：形态判定、判断文字整行搬运、DROP/NOTE 登记与零写入自证。
"""
import difflib
import hashlib
import os
import re
import sys

from dir_readmes_check import check_file
from dir_readmes_model import (
    H1_RE,
    H2_RE,
    MEMBER_HEADER_KEYS,
    MIGRATE_LIMIT,
    PLACEHOLDER_DUTY,
    die,
    dir_of_readme,
    emit_problems,
    fenced_mask,
    is_separator,
    is_subdir_header,
    list_subdirs,
    normalize_cell,
    split_raw_lines,
    strip_comments,
    subdir_table_lines,
    table_cells,
)


PLACEHOLDER_AUTHORITY = "【填写：本目录的权威来源】"
PLACEHOLDER_TABOO = "【填写：一条读取禁忌】"

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
