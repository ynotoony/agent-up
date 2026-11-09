# shellcheck shell=sh  # 本文件只被 test-runner/套件 source（无 shebang，执行入口在 test-runner.sh）

# Input: 各套件传入的夹具根路径与最小事实参数（票 id／状态／scope／说明）。
# Output: 公共世界构建原语（票 291 测试层拆分）：票仓树最小件（索引一条目行／README
#         票表两形态／changes.jsonl 种子行）、delivery.rules main-only 节、Git 夹具初始化
#         与基线提交；全部只写调用方给的 mktemp 夹具根，真实仓库零写入。
# Pos: tests 层公共 fixture builder（tests/test-world.sh；由 test-runner.sh source，
#      套件只调用不复制）。原 suite-ticket-run／suite-ticket-repair／suite-adversarial
#      各自手写的同款票树构造收敛到本文件；新增套件优先复用本文件原语，再按套件差异
#      叠加特化件。world_* override 钩子（test-helpers.sh 的 world_has_override 机制）
#      仍优先于本文件默认实现。一旦我被更新，务必同步 tests/README.md 与 README.md 专节。

# tw_delivery_rules_mainonly <repo-root>
# 写 delivery.rules 的 main-only 节（worktree-add.sh 读取的排除清单）。
tw_delivery_rules_mainonly() {
  cat > "$1/delivery.rules" <<'EOF'
# ==== main-only：worktree 排除清单（worktree-add.sh 读）====

dp_mainonly agent-up/scripts/export-payload.sh
EOF
}

# tw_index_one <repo-root> <id> <status> [complexity] [updated_at]
# 写「一条目一行」索引 fixture（字段序与生产读面一致）。
tw_index_one() {
  cat > "$1/facts/requirements/tickets/index.json" <<EOF
{
  "issues": [
    {"id": "$2", "status": "$3", "complexity": "${4:-C1}", "blocked_by": [], "updated_at": "${5:-2026-10-28T10:00}"}
  ]
}
EOF
}

# tw_readme_generated <repo-root> <id> <status> <label>
# 写含票表生成块（票 277 派生面）的 tickets README fixture；块外标题保持不动。
tw_readme_generated() {
  cat > "$1/facts/requirements/tickets/README.md" <<EOF
# 票据索引（fixture）

## 目录清单

<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->
| 名字 | 地位 | 功能 |
| --- | --- | --- |
| \`$2.json\` | 任务票 ${2%%-*}；\`$3\` | $4 |
<!-- /tickets-readme -->
EOF
}

# tw_readme_plain_row <repo-root> <id> <status> <label>
# 写无生成块的旧形态票表行（迁移前固定夹具口径）。
tw_readme_plain_row() {
  cat > "$1/facts/requirements/tickets/README.md" <<EOF
| \`$2.json\` | 任务票 ${2%%-*}；\`$3\` | $4 |
EOF
}

# tw_changes_seed <repo-root> <scope> <decision> <evidence_ref> [date]
# 写/追加 changes.jsonl 种子行（五键行族，键序 date,kind,scope,decision,evidence_ref）。
# 已存在账本时追加一行（调用方负责只追加语义）。
tw_changes_seed() {
  _tws_file="$1/facts/project/changes.jsonl"
  mkdir -p "$1/facts/project"
  printf '%s\n' "{\"date\":\"${5:-2026-10-28}\",\"kind\":\"change\",\"scope\":\"$2\",\"decision\":\"$3\",\"evidence_ref\":\"$4\"}" >> "$_tws_file"
}

# tw_git_init_commit <repo-root> [commit-message]
# Git 夹具初始化＋基线提交（fixture 身份固定；已初始化则复用仓库，仍做一次提交）。
tw_git_init_commit() {
  git_repo "$1"
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm "${2:-fixture seed}"
}

# tw_ticket_world <repo-root> <id> <status> <label>
# 最小票仓树（索引＋生成块 README＋账本种子＋product.txt）并提交；不建 scripts/ 闭包。
tw_ticket_world() {
  mkdir -p "$1/facts/requirements/tickets" "$1/facts/project"
  tw_index_one "$1" "$2" "$3"
  tw_readme_generated "$1" "$2" "$3" "$4"
  tw_changes_seed "$1" "${2%%-*}" "fixture seed" "facts/requirements/tickets/$2.json"
  printf 'implemented\n' > "$1/product.txt"
  tw_git_init_commit "$1" init
}

# tw_tree_digest <dir>
# 打印目录内容树（sha256＋相对路径），用于夹具零写入比对（自 suite-dir-readme 提取）。
tw_tree_digest() {
  python3 - "$1" <<'PY'
import hashlib
import os
import sys

root = sys.argv[1]
for base, dirs, files in os.walk(root):
    dirs.sort()
    for name in sorted(files):
        path = os.path.join(base, name)
        with open(path, 'rb') as fh:
            digest = hashlib.sha256(fh.read()).hexdigest()
        print(digest, os.path.relpath(path, root))
PY
}
