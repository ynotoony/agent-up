"""generate-dir-readmes.sh --brief 实现（票 290 拆分；同目录模块）.

单目录 agent 素材包只读输出：目录清单、判断证据（复用同目录 artifacts-index.sh 的唯一
artifacts 解析，本件零第二套 YAML 解析）、现状（复用 --check 判定）与生成约定。
"""
import os
import re
import subprocess
import sys

from dir_readmes_check import check_file
from dir_readmes_model import (
    H1_RE,
    H2_RE,
    MIGRATE_LIMIT,
    PLACEHOLDER_MARK,
    die,
    fenced_mask,
    join_rel,
    normalize_dir,
    strip_comments,
    strip_inline_code,
)


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


BRIEF_INDEX_REASONS = {
    "MISSING_SECTION": "artifacts 索引不可解析（缺 artifacts 段）",
    "NO_ENTRIES": "artifacts 索引无有效条目",
    "ENTRY_MISSING_IDPATH": "artifacts 索引条目缺 id 或 path",
}

BRIEF_INDEX_FIELDS = ("id", "path", "kind", "authority", "read_when")


def load_artifacts_index(path):
    # 解析唯一实现＝同目录 artifacts-index.sh --brief（票 286 D2：与 check-artifacts.sh 严格
    # 对账解析同一行文法扫描与条目边界规则）。本函数只承载读面/编码面降级分类与条目 dict
    # 投影——「缺失／不可读／非 UTF-8」三类错误仍由本层分类，文案与降级语义不变。
    try:
        with open(path, "r", encoding="utf-8") as fh:
            fh.read()
    except FileNotFoundError:
        return None, "artifacts 索引缺失"
    except OSError:
        return None, "artifacts 索引不可读"
    except UnicodeDecodeError:
        return None, "artifacts 索引不是 UTF-8"
    parser = os.path.join(sys.argv[1], "artifacts-index.sh")
    if not os.path.isfile(parser):
        return None, "artifacts 索引解析器缺失（同目录 artifacts-index.sh，安装闭包不完整）"
    proc = subprocess.run(["sh", parser, "--brief", path],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        stderr_text = proc.stderr.decode("utf-8", "replace").strip()
        token = stderr_text.splitlines()[-1] if stderr_text else ""
        return None, BRIEF_INDEX_REASONS.get(token, "artifacts 索引不可解析（共享解析器不可采用）")
    entries = []
    for line in proc.stdout.decode("utf-8", "replace").splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < len(BRIEF_INDEX_FIELDS):
            parts = parts + [""] * (len(BRIEF_INDEX_FIELDS) - len(parts))
        entries.append(dict(zip(BRIEF_INDEX_FIELDS, parts)))
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
