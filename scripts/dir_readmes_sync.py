"""generate-dir-readmes.sh --sync／--init 实现（票 290 拆分；同目录模块）.

生成块重建（只动块内）与四段骨架写入的写面；无生成块的 README 不新建不修改。
"""
import os
import sys

from dir_readmes_model import (
    PLACEHOLDER_DUTY,
    detect_eol,
    die,
    dir_of_readme,
    emit_problems,
    find_blocks,
    join_rel,
    join_raw_lines,
    list_subdirs,
    normalize_dir,
    parse_old_rows,
    plan_generated_block,
    read_text_exact,
    reject_whitespace,
    split_raw_lines,
    subdir_table_lines,
    write_text_exact,
)


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
