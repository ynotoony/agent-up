#!/bin/sh
# Input: 一个或多个任务票 JSON 路径（docs/issues/*.json 形态，票 70 先例）；判据权威＝
#        agent-up/references/protocol/complexity-profile.md §2.1（C0-C3 可数触发条件）
#        与 §2.3（微任务道承重判据可数面）；车道德协议权威＝docs/development-process.md
#        §6 分级交付道（R-DP-031）。票的 profile 七维字段不在可算面，本脚本不读取。
# Output: 每票一节的定级建议表（stdout）——各 C 级命中条件清单、C0-C3 建议、微道资格
#         预审、逐条验收形态标注、与票面 actual 定级（complexity 字段＝Triage 实际定级）
#         的逐票对照；批量末尾输出分歧账汇总。建议不裁决：输出只写「建议/命中/预审」，
#         不写「必须/定级为」；车道结论一律「待 Triage 裁决」。
# Pos: 本仓定级建议器（票 78，判断面最小化第一批，用户 2026-09-22 拍板三选一）；
#      python3 标准库内嵌（先例 scripts/run-record.sh seal/stats）；fail-closed——票文件
#      缺失、非 JSON、缺 id/complexity/acceptance/scope 字段即报明退出，零副作用（全程
#      只读，不写任何文件）。建议与 Triage 定级冲突时以 Triage 为准，分歧如实记录供
#      采纳票引用。

# 用法、判据口径（词表显式登记）与退出码见同目录 README.md 专节。

set -eu
set -f  # 关闭文件名展开：参数只按字面传递

usage() {
  cat <<'USAGE'
用法: sh scripts/ticket-grade.sh <ticket.json> [<ticket.json> ...]
参数:
  ticket.json  任务票 JSON 路径（至少一个；多个则逐票出节，末尾附分歧账汇总）。
  -h / --help  打印本用法。
输出:
  每票一节：实际定级｜验收（原始/承重/样板）｜触及顶层目录｜行为/契约件模块｜白名单
  文件（新建/删除）｜高风险面关键词命中｜公共接口证据｜命中条件｜C0-C3 建议｜微道
  预审｜逐条验收标注｜与实际定级对照。批量末尾：分歧账汇总（一致/分歧计数与名单）。
退出码: 0 全部处理完成（分歧不影响退出码——建议不裁决）；1 fail-closed（票文件缺失、
        非 JSON、缺 id/complexity/acceptance/scope 字段，报明缺项）；2 用法错误。
USAGE
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
esac

[ $# -ge 1 ] || { usage >&2; exit 2; }
die() { printf 'ticket-grade: %s\n' "$1" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || \
  die '未找到 python3（判据计算依赖，口径见 scripts/README.md 专节）——无法计算'

python3 - "$@" <<'PYEOF'
# -*- coding: utf-8 -*-
"""票 78 定级建议器：C0-C3 可数判据全算 + 微道资格预审（建议不裁决）。

判据权威：agent-up/references/protocol/complexity-profile.md §2.1/§2.3。
可算面边界（风险登记，票 78 risks）：只算机械可数面；「不影响运行行为」「上下文
窗口」「公共接口语义」「profile 七维」均属语义面，只列待核点，不机器判定。
"""
import json
import os
import re
import sys
from datetime import datetime

# ---- 显式词表（登记面＝scripts/README.md ticket-grade.sh 专节；改动须夹具复跑并同步）----

# 微道红标语义词（§2.3 承重判据「含任一语义判断即不入微道」的可数代理；窄清单防误报，
# 命中即红标「不入微道」，未命中不构成入道承诺）
RED_WORDS = ["像样", "合理", "满意", "符合口味", "美观", "优雅", "好用", "直观",
             "清晰", "合适", "适当", "良好"]

# 高风险面五项关键词（§2.1 定稿五面名的可数代理；扫描面＝title+goal+acceptance，
# 不扫 scope/out_of_scope——括注与排除项非承诺面）
HIGH_RISK_FACES = [
    ("数据迁移兼容", ["数据迁移", "迁移"]),
    ("认证授权", ["认证", "授权", "权限"]),
    ("安全隐私", ["安全", "隐私", "秘密", "信任边界"]),
    ("外部服务（含支付）", ["外部服务", "支付", "计费", "第三方"]),
    ("发布运行可靠性", ["发布", "部署", "回滚"]),
]

# 命令形态 token（验收「命令或静态检索可判定」的可数代理；命中其一即记命令形态）
CMD_TOKENS = ["sh ", "grep", "exit", "cmp", "test ", "check-package", "python3",
              "json.load", "git ", "实跑", "复跑", "diff", "零命中", "harness",
              "--suite", "--dry-run", "--check", "逐字节", "解析"]

# 门禁样板 AC 识别（各票收尾验收的固定样板，不计承重验收；显式模式防误伤实质验收）
GATE_PATTERN = ("Checkpoint ≤30 行", "check-package")

# 行为/契约件识别（模块数可数代理的候选文件；登记与纯文档不计模块）
CODE_EXTS = (".sh", ".py", ".js", ".ts", ".mjs", ".cjs", ".go", ".rs", ".c", ".h",
             ".rb", ".pl", ".java", ".kt", ".swift")
EXTLESS_FILES = {"pre-push", "pre-commit", "commit-msg", "Makefile"}


def die(msg, code=1):
    sys.stderr.write("ticket-grade: %s\n" % msg)
    sys.exit(code)


def is_behavior_file(path):
    base = path.rsplit("/", 1)[-1]
    if base.endswith(CODE_EXTS):
        return True
    if base in EXTLESS_FILES or base.endswith(".rules"):
        return True
    return base.endswith(".json") and "schema" in base


def is_iface_file(path):
    base = path.rsplit("/", 1)[-1]
    return "/schemas/" in path or base in ("SKILL.md", "AGENTS.md")


def parse_scope(scope_text):
    """解析 scope 树文本 → (文件路径列表, 新建数, 删除数)。

    形态（票 70 先例）：树干层级栈解析——每级 4 字符（│   或空格），├──/└── 为条目；
    尾随 / 为目录头压栈；条目 token 自含 / 时按全路径取用（不并栈）；深度 0 无 /
    的 token 视为仓根文件。全角括注承载新建/删除线索。目录不计入白名单文件数
    （含「实施时定位」类目录条目）——白名单从严不放宽。
    """
    files, new_cnt, del_cnt = [], 0, 0
    stack = []  # 当前目录层级栈
    for raw in scope_text.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        m = re.search(r"[├└]──", line)
        if not m:
            continue  # 根行/说明行
        idx = m.start()
        depth = idx // 4
        rest = line[m.end():].strip()
        token = rest.split("（", 1)[0].strip()
        annot = rest.split("（", 1)[1] if "（" in rest else ""
        if not token:
            continue
        if token.endswith("/"):
            # 目录头：截栈到本层并入栈
            del stack[depth:]
            stack.append(token.rstrip("/"))
            continue
        if "/" in token:
            path = token  # 自含路径，不并栈
        else:
            path = "/".join(stack[:depth] + [token]) if stack[:depth] else token
        if path not in files:
            files.append(path)
        if "新建" in annot:
            new_cnt += 1
        if ("删除" in annot) or ("移除" in annot) or ("退役" in annot):
            del_cnt += 1
    return files, new_cnt, del_cnt


def classify_acs(acceptance):
    """逐条验收标注：样板 / 语义词(红标:词) / 命令形态 / 证据不足。"""
    tags = []
    for a in acceptance:
        if all(g in a for g in GATE_PATTERN):
            tags.append(("样板", None))
            continue
        red = [w for w in RED_WORDS if w in a]
        if red:
            tags.append(("语义词", red[0]))
            continue
        if any(t in a for t in CMD_TOKENS):
            tags.append(("命令形态", None))
            continue
        tags.append(("证据不足", None))
    return tags


def grade(ticket_path):
    try:
        with open(ticket_path, "r", encoding="utf-8") as f:
            raw = f.read()
    except OSError as e:
        die("票文件缺失或不可读: %s（%s）" % (ticket_path, e.strerror))
    try:
        d = json.loads(raw)
    except ValueError as e:
        die("非 JSON 输入: %s（json.loads: %s）" % (ticket_path, e))
    if not isinstance(d, dict):
        die("票顶层非 JSON 对象: %s" % ticket_path)
    for field in ("id", "complexity", "acceptance", "scope"):
        if field not in d or d[field] in (None, "", []):
            die("缺 %s 字段: %s" % (field, ticket_path))
    tid = d["id"]
    declared = d["complexity"]
    acceptance = d["acceptance"]
    if not isinstance(acceptance, list) or not all(isinstance(a, str) for a in acceptance):
        die("acceptance 非字符串数组: %s" % ticket_path)

    scope_files, new_cnt, del_cnt = parse_scope("\n".join(d["scope"])
                                                if isinstance(d["scope"], list)
                                                else d["scope"])
    tags = classify_acs(acceptance)
    boiler = [i + 1 for i, (t, _) in enumerate(tags) if t == "样板"]
    work = [i + 1 for i, (t, _) in enumerate(tags) if t != "样板"]
    aw = len(work)
    reds = [(i + 1, w) for i, (t, w) in enumerate(tags) if t == "语义词"]

    # 模块数可数代理：触及顶层目录（全部文件）＋行为/契约件模块（新建并入，
    # 登记与纯文档不计）
    def topdir(p):
        return p.split("/", 1)[0] if "/" in p else "(仓根)"
    touch_dirs = sorted({topdir(p) for p in scope_files})
    bmods = sorted({topdir(p) for p in scope_files if is_behavior_file(p)})
    whitelist = len(scope_files)

    scan_text = str(d.get("title", "")) + "\n" + str(d.get("goal", "")) + "\n" + \
        "\n".join(acceptance)
    faces = []
    for face, words in HIGH_RISK_FACES:
        hit = [w for w in words if w in scan_text]
        if hit:
            faces.append((face, hit))
    iface = [p for p in scope_files if is_iface_file(p)]

    # ---- 命中条件与建议（建议不裁决：只写「建议/命中」）----
    hits_c3, hits_c2 = [], []
    if aw > 7:
        hits_c3.append("承重验收 %d 条 > 7" % aw)
    if len(bmods) >= 3:
        hits_c3.append("行为/契约件模块 %d 个 ≥ 3（%s）" % (len(bmods), "+".join(bmods)))
    if len(faces) >= 2:
        hits_c3.append("高风险面 %d 个 ≥ 2（%s）" %
                       (len(faces), "、".join(f for f, _ in faces)))
    if 4 <= aw <= 7:
        hits_c2.append("承重验收 %d 条（4-7）" % aw)
    if len(bmods) == 2:
        hits_c2.append("跨 2 个行为/契约件模块（%s）" % "+".join(bmods))
    if len(faces) == 1:
        hits_c2.append("高风险面关键词命中 1 个（%s：%s）" % (faces[0][0], "、".join(faces[0][1])))
    if iface:
        hits_c2.append("公共接口证据 %d 件（%s）" % (len(iface), ", ".join(iface)))

    if hits_c3:
        sug, sugset = "C3", {"C3"}
    elif hits_c2:
        sug, sugset = "≥C2", {"C2", "C3"}
    else:
        sug, sugset = "C0-C1", {"C0", "C1"}
    c0_face = (aw <= 3 and len(bmods) <= 1 and not faces and not iface)

    # ---- 微道资格预审（§2.3 承重判据可数面；前提＝C0 可数面成立）----
    if not c0_face:
        why = []
        if aw > 3:
            why.append("承重验收 %d>3" % aw)
        if len(bmods) > 1:
            why.append("行为件模块 %d>1" % len(bmods))
        if faces:
            why.append("高风险面关键词命中")
        if iface:
            why.append("公共接口证据在册")
        micro = "不适用（C0 可数面不成立：%s）" % "；".join(why)
    else:
        mr = []
        if whitelist > 3:
            mr.append("白名单 %d>3 文件" % whitelist)
        if new_cnt:
            mr.append("新建 %d 件" % new_cnt)
        if del_cnt:
            mr.append("删除 %d 件" % del_cnt)
        if reds:
            mr.append("红标语义词 %s" % ("; ".join("AC%d:%s" % r for r in reds)))
        weak = ["AC%d" % i for i in work
                if tags[i - 1][0] in ("证据不足", "语义词")]
        if weak:
            mr.append("非命令形态验收 %s" % "+".join(weak))
        micro = ("预审可入微道（待 Triage 裁决；判据：C0 可数面＋白名单 %d≤3 文件＋"
                 "零新建零删除＋全命令形态＋零红标）" % whitelist) if not mr \
            else "不入微道（%s）" % "；".join(mr)

    agree = "一致" if declared in sugset else "分歧"

    # ---- 输出（stdout，只读零写入）----
    out = []
    out.append("=== %s ===" % tid)
    out.append("实际定级(Triage): %s" % declared)
    out.append("验收: 原始 %d｜承重 %d｜样板(不计数): %s" %
               (len(acceptance), aw,
                ("AC" + "+AC".join(str(b) for b in boiler)) if boiler else "无"))
    out.append("触及顶层目录: %d [%s]｜行为/契约件模块: %d [%s]" %
               (len(touch_dirs), ", ".join(touch_dirs), len(bmods), ", ".join(bmods)))
    out.append("白名单文件: %d｜新建: %d｜删除: %d" % (whitelist, new_cnt, del_cnt))
    out.append("高风险面关键词命中: %s" %
               ("无" if not faces else "；".join("%s(%s)" % (f, "、".join(w)) for f, w in faces)))
    out.append("公共接口证据: %s" % ("无" if not iface else ", ".join(iface)))
    out.append("命中条件: %s" % ("；".join(hits_c3 + hits_c2) if (hits_c3 or hits_c2)
                                else "无 C2/C3 可数命中（待核语义点：是否不影响运行行为／上下文窗口）"))
    out.append("建议: %s（建议不裁决；待 Triage 核语义点）" % sug)
    out.append("微道预审: %s" % micro)
    out.append("逐条验收: %s" % "｜".join(
        "AC%d=%s%s" % (i + 1, t, ("(红标:%s)" % w) if w else "")
        for i, (t, w) in enumerate(tags)))
    out.append("对照: %s（建议集 {%s} vs 实际 %s）" %
               (agree, "-".join(sorted(sugset)), declared))
    sys.stdout.write("\n".join(out) + "\n")
    return tid, agree, sug


def main():
    argv = sys.argv[1:]
    if not argv:
        usage_sh = ("用法: sh scripts/ticket-grade.sh <ticket.json> [...]  "
                    "（-h 看全量；退出码见 README）")
        die(usage_sh, 2)
    results = [grade(p) for p in argv]
    ok = [t for t, a, _ in results if a == "一致"]
    div = [(t, s) for t, a, s in results if a == "分歧"]
    sys.stdout.write("=== 分歧账（脚本建议 vs Triage 实际定级；供采纳票引用） ===\n")
    sys.stdout.write("一致: %d%s\n" % (len(ok), ("（%s）" % ", ".join(ok)) if ok else ""))
    sys.stdout.write("分歧: %d%s\n" % (len(div),
                     ("（%s）" % ", ".join("%s→建议%s" % x for x in div)) if div else ""))
    sys.stdout.write("评估时点: %s｜建议不裁决：分歧以 Triage 为准，机器面仅承载可数判据证据\n"
                     % datetime.now().strftime("%Y-%m-%d"))


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except BrokenPipeError:
        sys.exit(0)
PYEOF
