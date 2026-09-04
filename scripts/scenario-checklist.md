<!-- Input: SPEC-06 §7 发布前 11 条验收场景、票 05～11 Implementation Checkpoint 事实、本次（2026-09-03，macOS）真实执行记录。 -->
<!-- Output: 十一条场景的验收边界、验收方法、逐条执行结果与证据指针清单；发布就绪前置条件核验记录。 -->
<!-- Pos: 票 12（I-08）场景验收清单落盘；包内容变化后可按本清单复验；一旦我被更新，务必更新我的开头注释与 scripts/README.md 成员登记。 -->

# 场景验收清单（SPEC-06 §7 发布前 11 条）

## 验收边界（先读）

- **S1～S9 属"模板即产物"的静态验收**：Agent Up 的交付物是模板、协议手册与检查脚本；场景 1-9 描述的目标项目行为（生成、补缺、恢复、并行、阻塞、降级、漂移）发生在目标项目安装 Agent Up 之后。包级验收只能核对承载这些行为的协议与模板语义正确性，不声称已在真实目标项目中跑通场景（票 12 Risks：静态模拟与真实使用行为有差距，证据效力边界如实记录）。S1-S9 均以"等价静态核对"方式执行（SPEC-06 §7 允许"每条以文档静态核对或脚本证据验证"），未发起 mktemp 行为模拟实验。
- **S10 面向包本体**：以 check-package.sh 真实运行与临时副本负例抽查验证；subtree split 导出目录的全量复跑属票 13，本清单记 `deferred-to-13` 条件项。
- **S11 未测量即 N/A**：无隔离实验数据，按 R-CC-004 与票 12 Forbidden 不声称任何优化收益，不发起实验；仅做收益声明扫描核对。

## 运行环境与结果汇总

- 环境：macOS（Darwin arm64）；日期：2026-09-03；工作目录：仓库根；命令均真实运行。
- 结果：**10 PASS（S1-S10）+ 1 N/A（S11，未测量）+ 0 FAIL**；S10 附 `deferred-to-13` 条件项。

| # | 场景 | 状态 |
| --- | --- | --- |
| S1 | 新项目最小 seed | PASS |
| S2 | 旧项目只补缺 | PASS |
| S3 | 简单任务不建空目录 | PASS |
| S4 | 跨模块建议地图/规格 | PASS |
| S5 | Delivery 恢复 | PASS |
| S6 | Intake 并行 | PASS |
| S7 | 范围变化阻塞 | PASS |
| S8 | 无 subagent 降级 | PASS |
| S9 | 漂移检测 | PASS |
| S10 | 公开导出干净 | PASS（附 deferred-to-13） |
| S11 | token 声明受数据约束 | N/A + reason（未测量；声明扫描零违规） |

---

### S1 新项目最小 seed — `PASS`

- **验收边界**：静态验收（模板即产物）；目标项目空目录初始化行为由 seed 模板语义承载。
- **验收方法**：静态核对 templates manifest 的 seed 七件套映射表与触发矩阵默认不创建条款。
- **核对要点**：seed 恰七件、逐件有模板依据且触发 `always`；seed 之外的产物全部为 Conditional 且默认不创建，Required 产物由 Artifact Plan 判定。
- **本次执行结果**：七件映射逐件在位（`AGENTS.md`、`docs/README.md`、`docs/development-process.md`、`docs/progress.md`、`docs/changes.md`、`docs/requests/README.md`、`docs/agent/artifacts.yaml`），全部 `always`；§5.2 开头句声明条件产物默认不创建；R-DP-006 规定创建决定写入 Artifact Plan 并经用户确认。
- **证据**：`agent-up/references/templates/README.md:24-36`（seed 七件套映射表，七行 :30-36）；`agent-up/references/templates/development-process.md.tmpl:15`（"条件产物按九行触发矩阵默认不创建；不为目录完整性预建空目录或占位文件"）、`:145`、`:159-167`（R-DP-006）。交叉证据：check-package.sh 检查 5（模板清单与 manifest 一致）PASS。

### S2 旧项目只补缺 — `PASS`

- **验收边界**：静态验收；只补缺语义由 old-project.md 手册承载。
- **验收方法**：静态核对 old-project.md 存在性、硬边界五条与"只补缺"生成物表。
- **核对要点**：硬边界五条齐备；生成物表对既有文件只登记/校验/追加、缺失才生成；Record 类不被覆盖。
- **本次执行结果**：手册在位（九字段 frontmatter + 契约头）；硬边界五条（代码布局不动/不重写既有文档/不批量加契约头/规则冲突不静默裁决/脏文件不碰）逐条在位；生成物表"只补缺"语义逐行在位（如 README"已存在的只把直接成员登记补齐"、`.gitignore`"缺失才生成；已存在的只追加"）；Record 不覆盖由产物生命周期条款承载。
- **证据**：`agent-up/references/old-project.md:30-36`（§2 硬边界五条）、`:38-48`（§3 生成物（只补缺）表）、`:51`（§4 差异清单先行）、`:58`（§5 收尾报告差异）；`agent-up/references/templates/development-process.md.tmpl:14`（"Record 只追加或按状态机更新、模板升级不得覆盖"）。

### S3 简单任务不建空目录 — `PASS`

- **验收边界**：静态验收；"非触发"语义由触发矩阵默认不创建条款 + R-DP-006 承载（显式"不触发"清单属 §5.4 同步门槛，见 S9，不属创建矩阵）。
- **验收方法**：静态核对 development-process 模板触发矩阵的默认不创建条款与 R-DP-006。
- **核对要点**：矩阵九行每行均需显式命中条件（C2/C3、用户要求、确认语义等），C0/C1 简单任务无一命中 → specs/issues/architecture 等条件产物不创建；预建空目录被 Forbidden。
- **本次执行结果**：默认不创建条款在位；R-DP-006 Forbidden 列"为目录完整性预建空目录、占位文件或'以后会用到'的产物"；Evidence 要求"每个条件产物的创建能指向命中的触发条件行"。
- **证据**：`agent-up/references/templates/development-process.md.tmpl:145`（"条件产物默认不创建；命中下列至少一条才创建"）、`:149-157`（九行矩阵）、`:159-167`（R-DP-006，Forbidden 在 :161、Evidence 在 :165）；`:15`（快速摘要同行声明）。

### S4 跨模块建议地图/规格 — `PASS`

- **验收边界**：静态验收；建议行为由触发矩阵对应行承载。
- **验收方法**：静态核对触发矩阵中 specs、architecture、项目地图、runs 各行。
- **核对要点**：跨模块 C2/C3 任务命中 specs/architecture/项目地图/runs 行的触发条件。
- **本次执行结果**：四行触发条件逐行在位，跨模块 C2/C3 语义显式写入。
- **证据**：`agent-up/references/templates/development-process.md.tmpl:150`（`docs/specs/`："修改公共行为或接口；存在多条验收路径；跨会话交付；C2/C3 任务合同不足；用户要求"）、`:154`（`docs/architecture/`："用户要求；C2/C3 跨模块；涉及多 Adapter"）、`:155`（`docs/agent/runs/`："C2/C3；跨会话；发生中断；无 Git 基线；改动归属不明"）、`:156`（项目地图："跨模块导航需要；仓库规模大；用户要求；旧地图过期"）。

### S5 Delivery 恢复 — `PASS`

- **验收边界**：静态验收；恢复行为由 development-process 模板 §12 恢复协议承载。
- **验收方法**：静态核对 §12.3 恢复八步固定顺序与 §12.2 事实优先级四层。
- **核对要点**：八步逐条在位且不得跳步；第 6 步重跑最后验证；事实优先级高到低四层。
- **本次执行结果**：八步逐条在位（第 6 步为"重跑最后验证（`last_verified` 记录的命令）"）；事实优先级四层逐条在位（实际文件/测试/Git > Checkpoint/run record > progress > 聊天记录）；R-DP-014 把"未重跑最后验证就交接"列为 Forbidden。
- **证据**：`agent-up/references/templates/development-process.md.tmpl:417-428`（§12.3 八步）、`:396-403`（§12.2 四层）、`:407`（R-DP-013）、`:432`（R-DP-014）、`:22`（快速摘要行）。

### S6 Intake 并行 — `PASS`

- **验收边界**：静态验收；并行行为由 requests-README 模板 Intake 边界与并行规则承载。
- **验收方法**：静态核对 R-RQ-001 Intake 写入边界、Intake/Delivery 并行规则节与五角色写入矩阵。
- **核对要点**：Intake 只写新 REQ；不改当前任务 Scope/验收/progress；五角色矩阵逐行在位。
- **本次执行结果**：R-RQ-001（`MUST`）Action 为"只在本目录新建 `REQ` 文件并登记目录清单"；并行规则节声明两 Session 写入目标不相交、Intake 只写新 REQ；五角色矩阵（Intake/Triage/Delivery/Review/Commit）逐行在位。
- **证据**：`agent-up/references/templates/requests-README.md.tmpl:14-22`（R-RQ-001）、`:41-45`（Intake/Delivery 并行规则）、`:46-54`（写入所有权矩阵五行）、`:56-64`（R-RQ-003 并行写入边界）。

### S7 范围变化阻塞 — `PASS`

- **验收边界**：静态验收；阻塞语义由 requests-README 模板 `blocked: scope-change` 规则承载。
- **验收方法**：静态核对 `blocked: scope-change` IF/THEN 规则两处在位。
- **本次执行结果**：R-RQ-001 与并行规则节各一处 IF/THEN：新需求影响当前任务验收 → 当前任务标 `blocked: scope-change`，由 Triage 承接（建新规格/票）；影响评估不确定 → Request 置 `needs-user-decision`，任务保持冻结。
- **证据**：`agent-up/references/templates/requests-README.md.tmpl:17`（R-RQ-001 Action 内 IF/THEN）、`:45`（并行规则节 IF/THEN + `needs-user-decision` 退化分支）。

### S8 无 subagent 降级 — `PASS`

- **验收边界**：静态验收；降级行为由 capability-contract R-CC-002 承载。
- **验收方法**：静态核对 R-CC-002 三条替代路径与 `independent_review: unavailable` 记录语义。
- **本次执行结果**：三条替代路径依序在位（(a) 新开独立 session；(b) 不同执行身份或模型；(c) 用户本人）；`independent_review: unavailable` 记录语义在位；同一执行体自检不得标 pass（Forbidden）；三路径均不可用停在 review_ready。
- **证据**：`agent-up/references/adapters/capability-contract.md:76-85`（R-CC-002；Action 三路径与记录在 :79、Forbidden 在 :80、Stop if 停在 review_ready 在 :81、run record 指针字段在 :82）、`:27`（快速摘要行）。

### S9 漂移检测 — `PASS`

- **验收边界**：静态验收；漂移检测由同步门槛四类触发、产物状态机与登记协议承载。
- **验收方法**：静态核对 §5.4 同步门槛四类变化 + "不触发"清单、R-DP-007 Stop if 的 `stale` 标记、状态机 stale 边。
- **本次执行结果**：四类变化（契约/拓扑/行为/派生关系）逐行在位；"不触发：错别字与排版修正；纯追加记录……"清单在位；发现登记与实际漂移 → 将相关产物标 `stale` 并报告（R-DP-007 Stop if）；状态机含 `generated ──漂移或触发同步而未同步──> stale` 边，且 `stale` 产物恢复前不得当作可信导航。
- **证据**：`agent-up/references/templates/development-process.md.tmpl:199-206`（§5.4 表，四行 :203-206）、`:208`（不触发清单）、`:210`（R-DP-008）、`:194`（R-DP-007 Stop if 标 `stale`）、`:17` 与 `:224`、`:233`（状态机与 stale 语义）。

### S10 公开导出干净 — `PASS`（附 `deferred-to-13` 条件项）

- **验收边界**：面向包本体；本条为真实脚本运行 + 负例抽查（本次唯一的临时目录执行项）。subtree split 实际导出目录的全量验证属票 13。
- **验收方法**：`sh agent-up/scripts/check-package.sh` 对包本体运行（缺省包根与显式包根两种形态）；负例：临时副本删除一个必需入口文件后复跑，预期 FAIL，随后清理。
- **本次执行结果**：
  - 正例（缺省包根，命令 `sh agent-up/scripts/check-package.sh`）：七项检查逐行 `PASS: 1`～`PASS: 7`，结尾 `check-package: PASS`，exit 0。
  - 正例 b（显式包根，`sh agent-up/scripts/check-package.sh agent-up`）：结尾 `check-package: PASS`，exit 0。
  - 负例（命令序：`TMPD=$(mktemp -d)`；`cp -R agent-up "$TMPD/agent-up"`（仓库根执行）；`rm "$TMPD/agent-up/SKILL.md"`；`sh "$TMPD/agent-up/scripts/check-package.sh" "$TMPD/agent-up"`）：输出 `FAIL: 1 必需入口存在（16 个文件） — - SKILL.md`、`FAIL: 2 SKILL.md frontmatter 为 name: agent-up — SKILL.md 不存在`、`check-package: FAIL（2 项未通过，共 7 项）`，exit 1——检查 1/2 如实暴露缺陷，其余五项不受影响。临时目录已 `rm -rf` 删除并确认不存在，工作区无污染。
- **证据**：上述命令与输出为 2026-09-03 真实运行记录（macOS，Darwin arm64）；脚本约束见 `agent-up/scripts/README.md` 七项检查表。
- **`deferred-to-13` 条件项**：subtree split 导出目录的 `check-package.sh` 全量复跑（含"导出仅含包文件"核对）在票 13 完成导出后补记；本条 PASS 仅覆盖包本体，不得被解读为导出物已验证。

### S11 token 声明受数据约束 — `N/A + reason`

- **状态**：`N/A`。**reason**：未进行任何隔离实验或测量，无实验数据；按 R-CC-004 与票 12 Forbidden（不编造实验数据或测量结论、不发起实验），本条不声称任何 token 节省、可靠性提升或速度提升收益，也不声明包"经优化"。
- **补充核对（声明扫描，票 12 Verification 命令）**：`rg -ni 'token|节省|可靠性提升|速度提升' agent-up --glob '!adapters/**'` 命中 6 处（含 adapters 全包扫描同 6 处），逐处核对均为边界声明或实践规则，**收益声明零命中**：
  1. `agent-up/README.md:62` — 禁令（"在没有实验数据的情况下声称 token 节省、速度或可靠性提升"）；
  2. `agent-up/references/templates/development-process.md.tmpl:295` — 节题"上下文与 token 卫生"（实践规则）；
  3. `agent-up/references/templates/development-process.md.tmpl:306` — smart zone 落盘时机规则（操作指引，非收益声明）；
  4. `agent-up/references/old-project.md:43` — "token 卫生固定写入"（实践引用）；
  5. `agent-up/references/adapters/capability-contract.md:31` — R-CC-004 摘要禁令；
  6. `agent-up/references/adapters/capability-contract.md:106` — R-CC-004 Forbidden。

---

## harness 沉淀决定

本清单沉淀为包成员 `agent-up/scripts/scenario-checklist.md`（理由：11 条中 10 条为可复验的静态核对、S10 复验只需 check-package.sh 与临时副本流程，清单本身即可充当可复跑验收规程），并登记进 `agent-up/scripts/README.md` 成员表。不另建可执行 harness：S1-S9 无需运行时脚本（模板语义核对即验收），S10 已有 check-package.sh，S11 为未测量项。

## 发布就绪前置条件

- 11 条场景逐条核验完成（10 PASS + 1 N/A），无 FAIL 项，**发布就绪前置条件达成**（R-06-008 前半）。
- 剩余前置：S10 的 `deferred-to-13` 全量复跑（票 13 完成 subtree 导出后补记）；独立 Review 复核本清单后票 12 状态改 `done`；票 14 的 GitHub URL/remote/push/发布声明仍需用户**单独授权**（R-06-007），本清单不构成任何发布行为授权。

## 验证记录

| 项 | 结果 |
| --- | --- |
| 本清单契约头 | Input:/Output:/Pos: 三行齐备（文件头 1-3 行），无 frontmatter，属 check-package.sh 检查 6 扫描范围 |
| check-package.sh 正例 | 7 PASS，`check-package: PASS`，exit 0（2026-09-03 实跑） |
| check-package.sh 负例 | 临时副本删 SKILL.md → `FAIL（2 项未通过，共 7 项）`，exit 1；临时目录已清理 |
| S11 声明扫描 | 6 命中逐处核对为禁令/实践表述，收益声明零命中 |
| `git status --short` | `fatal: not a git repository`（exit 128）——本仓库未 Git 化（属票 13），全程零 Git 写操作 |
