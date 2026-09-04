<!-- Input: `SKILL.md` 对新项目治理骨架的生成约定、seed 七件套与触发矩阵约定（`../protocol/` 手册）、SPEC-05 角色合同七节与能力声明约定（能力语义见 `../adapters/capability-contract.md`），以及本目录的模板文件。 -->
<!-- Output: `agent-up` 生成治理文件时可读取的模板 manifest：直接成员、Emits 目标路径、创建触发条件、产物生命周期与规则块短码登记。 -->
<!-- Pos: Skill 治理模板目录索引与模板 manifest；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 治理模板

本目录保存 `agent-up` 生成目标项目治理骨架时使用的模板。本 README 是模板 manifest：登记全部直接成员及其 Emits 目标路径、创建触发条件与产物生命周期；模板清单与本目录实际文件一致，增删模板必须在此登记理由，不静默增删。

## 规则块短码登记表

模板内规则块 ID 前缀为 `R-<模板短码>-<三位序号>`，全局唯一；新增短码先登记再使用：

| 短码 | 模板（生成产物） |
| --- | --- |
| `AG` | `AGENTS.md.tmpl`（→ `AGENTS.md`） |
| `DP` | `development-process.md.tmpl`（→ `docs/development-process.md`） |
| `RQ` | `requests-README.md.tmpl`（→ `docs/requests/README.md`） |
| `RI` | `agents-implementation.md.tmpl`（→ `docs/agent/roles/implementation.md`） |
| `RR` | `agents-review.md.tmpl`（→ `docs/agent/roles/review.md`） |
| `RC` | `agents-commit.md.tmpl`（→ `docs/agent/roles/commit.md`） |

公开包 `../protocol/` 手册短码（`GF`、`RP`）见 `../protocol/governance-format.md`；`../adapters/` 手册短码（`CC`、`ZC`）见 `../adapters/capability-contract.md`，与模板短码互不重叠。

## seed 七件套映射

新项目初始化默认生成且仅生成七件 seed（其余产物按触发矩阵与 Artifact Plan 处理）：

| seed 件（Emits） | 模板 | 生命周期 | 创建触发条件 |
| --- | --- | --- | --- |
| `AGENTS.md` | `AGENTS.md.tmpl` | Seed | always |
| `docs/README.md` | `dir-README.md.tmpl` | Seed | always |
| `docs/development-process.md` | `development-process.md.tmpl` | Seed | always |
| `docs/progress.md` | `progress.md.tmpl` | Seed | always |
| `docs/changes.md` | `changes.md.tmpl` | Seed | always |
| `docs/requests/README.md` | `requests-README.md.tmpl` | Seed | always |
| `docs/agent/artifacts.yaml` | `artifacts-yaml.tmpl` | Seed | always |

## 目录清单（manifest）

| 名字 | 类别 | Emits 目标路径 | 创建触发条件 | 规则块短码 | 功能 |
| --- | --- | --- | --- | --- | --- |
| `README.md` | 目录索引 | 本 README | 目录创建 | 无 | 模板 manifest 与短码登记。 |
| `AGENTS.md.tmpl` | Seed | `AGENTS.md` | always | `AG` | 生成根 Agent 路由入口：先读什么、快速规则、工作类型路由与停止条件。 |
| `development-process.md.tmpl` | Seed | `docs/development-process.md` | always | `DP` | 生成唯一流程权威：读取阶梯、权威层级、产物生命周期、三阶段协作、门禁、会话恢复协议（三套状态机、八步恢复顺序、run record、写入所有权矩阵、故障处理、破坏性恢复禁令、六条不变量）、验证与提交。 |
| `progress.md.tmpl` | Seed | `docs/progress.md` | always | 无 | 生成进度紧凑索引（每票 ≤5 行，Checkpoint 指针）。 |
| `changes.md.tmpl` | Seed | `docs/changes.md` | always | 无 | 生成按日期追加的变更审计记录骨架。 |
| `requests-README.md.tmpl` | Seed | `docs/requests/README.md` | always | `RQ` | 生成 REQ 队列规则：请求状态机、Intake/Triage 边界、Intake/Delivery 并行规则与写入所有权矩阵。 |
| `artifacts-yaml.tmpl` | Seed | `docs/agent/artifacts.yaml` | always | 无 | 生成产物机器索引：十三字段说明与 seed 七件初始登记。 |
| `dir-README.md.tmpl` | Seed（兼条件性） | `<目录>/README.md` | docs 目录：always；其他受 Git 管理目录：新建目录时 | 无 | 生成目录 README 与直接成员登记。 |
| `CONTEXT.md.tmpl` | Conditional | `docs/CONTEXT.md` | 确认了项目特有术语、角色或状态 | 无 | 生成结构化词条 + 自然语言定义的领域上下文。 |
| `issues-README.md.tmpl` | Conditional | `docs/issues/README.md` | 需要 ≥2 张票；存在 Blocked by 依赖；跨会话交接 | 无 | 生成任务票目录规则与票模板。 |
| `specs-README.md.tmpl` | Conditional | `docs/specs/README.md` | 修改公共行为或接口；多条验收路径；跨会话交付；C2/C3 任务合同不足；用户要求 | 无 | 生成规格目录规则与规格模板。 |
| `research-README.md.tmpl` | Conditional | `docs/research/README.md` | 需要外部调研、方案对比或 spike | 无 | 生成调研目录归档规则与报告模板。 |
| `scripts-README.md.tmpl` | Conditional | `scripts/README.md` | 可重复验证需要沉淀为共享 harness | 无 | 生成共享验证 harness 目录索引与登记约定。 |
| `agents-implementation.md.tmpl` | Roles | `docs/agent/roles/implementation.md` | 所有项目初始化生成三阶段角色合同 | `RI` | 生成 Implementation 阶段平台无关角色合同（七节 + required_capabilities 能力基元声明 + 规则块 R-RI-001～003）。 |
| `agents-review.md.tmpl` | Roles | `docs/agent/roles/review.md` | 所有项目初始化生成三阶段角色合同 | `RR` | 生成 Review 阶段平台无关角色合同（七节 + 只读能力声明 + 降级记录规则块 R-RR-001～003）。 |
| `agents-commit.md.tmpl` | Roles | `docs/agent/roles/commit.md` | 所有项目初始化生成三阶段角色合同 | `RC` | 生成 Commit 阶段平台无关角色合同（七节 + 版本库能力声明 + 规则块 R-RC-001～003）。 |

## 取舍与过渡登记

- `scripts-README.md.tmpl` 纳入为条件性模板：`scripts/` 是触发矩阵中的条件性产物，其目录 README 必须随脚本目录一起生成才符合"受 Git 管理的目录必须有 README"约定；正文复制自外部源并同步 `development-process` 模板的验证章节指向，故按条件性模板登记。
- 单一权威：流程细节只在 `development-process.md.tmpl` 一个事实源；`AGENTS.md.tmpl` 只路由加快速规则，`progress/changes/requests/artifacts` 模板只承载各自格式（requests 的 Intake/Delivery 并行边界为队列侧同一矩阵的复述，权威在 development-process），不复制其余流程细节。
- run record 机器 schema 不以模板承载：定稿落公开包 `../schemas/run-record.schema.json`（含样例 `run-record.example.json`，票 07 定稿；生成条件与字段语义在 `development-process.md.tmpl` §12.4），无 `run-record-yaml.tmpl`。
- 角色模板（`agents-*.tmpl`）平台绑定已剥离（票 08 / I-04，2026-09-03）：宿主 frontmatter（name/color/tools 与描述内工具列举）移至 `../adapters/zcode.md` 运行时映射；模板改为治理格式九字段元数据 + SPEC-05 §4 角色合同七节，`required_capabilities` 只用能力基元；Emits 路径定稿为 `docs/agent/roles/`（platform: neutral，收敛票 06 未决项⑤），宿主运行时入口由适配层生成（见 `../adapters/zcode.md`）。
- 模板目录形态定稿（票 09 / I-05，2026-09-03）：以扁平目录 + manifest 类别列（Seed/Conditional/Roles）承载 SPEC-06 §2 的分组语义，不建 `seed/`、`conditional/`、`roles/` 子目录——票 06/08 已把票面子目录方案收敛为扁平直改（消除双轨漂移），本组无独立文件组，建目录违反懒创建（R-06-001）；本票零移动零增删，模板清单未变，旧模板正文改写仍归票 10。
- `CONTEXT/dir-README/issues/specs/research/scripts` 模板保留为条件性模板（触发矩阵命中才使用）；票 10（2026-09-03）收窄执行：该批模板正文维持票 06～09 已验收的结构化短文形态，不改写为规则块——其生成物是面向人的目录索引，规则权威在 development-process；各模板补 `read_when` 元数据注记行（对齐 `CONTEXT.md.tmpl` 先例，只做导航），语义未变。
- `artifacts-yaml.tmpl` 契约头以 YAML `#` 注释承载（文件第 1～3 行 `# Input:` / `# Output:` / `# Pos:`）：生成物 `docs/agent/artifacts.yaml` 是 YAML，顶部 HTML 注释会破坏解析，故不采用 `<!-- -->` 形态；包完整性检查（票 11）对该模板的 `^<!-- Input:` 扫描按 `../schemas/README.md` 登记的 JSON 例外同口径豁免（票 10，2026-09-03）。
- `development-process.md.tmpl` §5.2 触发矩阵补 C2/C3 指引句（票 10 Fix，2026-09-03，收口票 10 Checkpoint 未决项①）：复杂度与 Profile 权威表位置写为【按项目填写】占位，不硬编码 Agent Up 包路径；包内默认基线落 `../protocol/complexity-profile.md`（短码 `CP`，登记见 `../protocol/README.md`）。
