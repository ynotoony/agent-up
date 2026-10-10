---
id: reference-old-project
kind: protocol
authority: 权威层级第 4 级（流程规则：旧项目路径手册）；冲突判定上游为 protocol/read-policy.md 权威层级与目标项目 development-process
lifecycle: Live
read_when: 主流程模式判定为已有代码或部分治理项目时；旧项目盘点、补缺与收尾报告全程
trigger: 旧项目硬边界、只补缺生成物清单或差异清单/收尾报告差异语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 硬边界与"只补缺"语义为定稿基线；语义变化须用户确认并同步 SKILL.md 主流程与模板 manifest
depends_on: agent-up/SKILL.md（主流程与差异清单规则）；生成物模板见 references/templates/README.md manifest
---
<!-- Input: 旧项目盘点事实与既有规则；新票/新 REQ JSON 本体补缺行（存量零改写）；模块地图生成器补缺行（项目地图触发行懒创建）；ticket-ops.sh 补缺行（记录层标配落位口径，不门控于快道启用）；道脚本与票务运维脚本安装政策单源化（落位集合改指公开包 scripts/install-policy.rules 数据，复制动作经 scripts/install.sh 执行，本表不再复写映射明细）。 -->
<!-- Output: 旧项目治理补缺路径。 -->
<!-- Pos: 旧项目路径参考手册；说明治理体系如何在不改既有事实的前提下补缺。（术语注：seed 件＝初始化时装上的基础文件；契约头＝文件开头三行登记块；懒创建＝用到才建。） -->

# 旧项目协调手册

目标是在**不打断既有工作方式**的前提下，让治理体系覆盖旧项目。旧项目的价值在于它的现状；本技能的价值是补上可接续性和规则自持，不是改造。

> 指路：目标项目**已按本体系初始化**（初始装上的文件都在）且要跟上包新版——那不是本手册的事，走 `references/upgrade.md` 升级手册（已治理仓升级）；本手册管"未治理仓补缺"这一半。

## 1. 盘点输出（动手前完成）

把以下事实列成一张清单，作为后续所有决定的依据：

- Git 状态：是否仓库、当前分支、脏文件及归属判断。
- 既有规则与文档：`AGENTS.md`、`CLAUDE.md`、`.cursorrules`、`CONTRIBUTING.md`、`docs/`、根/目录 `README.md`，各自覆盖什么、是否互相冲突。
- 既有权威事实源：架构文档、AIDR/决策记录、oncall/runbook、规格文档——这些就是未来的"权威来源"，登记即可，不搬家不重写。
- 技术栈与命令：包管理器、测试/构建/lint 命令（从 manifest 和 CI 配置里核实，不猜）。
- 顶层目录用途：抽查内部文件确认。

## 2. 硬边界

- **代码布局不动**：不把代码挪进 `private/` 之类的划分；那是特定项目的选择，不是本体系的组成部分。
- **不重写既有文档**：已有 README/架构文档保持原样；登记为权威来源，缺的才补。
- **不批量加文件头登记块**：文件头登记块（契约头，文件开头三行"输入/输出/定位"注释）先只加到本次生成的治理文档（`AGENTS.md`、docs 权威文档、新建目录 README）。存量源码和文档要不要补头，列为建议交给用户决定。
- **规则冲突不静默裁决**：既有规则（如 `.cursorrules`）与治理体系冲突时，报告差异并让用户选；不擅自删改任何一方的规则文件。
- **脏文件不碰**：未提交改动只做归属判断，不清理、不覆盖。

## 3. 生成物（只补缺）

| 缺失件 | 动作 |
| --- | --- |
| `AGENTS.md` | 按模板生成路由；权威来源映射指向既有文档（保留其原路径），流程细节路由到新生成的 `docs/development-process.md`；最小仓库边界按盘点事实填写（密钥不进 Git、不碰他人改动、不自动 push 三条通用边界 + 项目特有边界）。 |
| `docs/development-process.md` | 按模板生成；目录边界、验证命令等【按项目填写】处用盘点结果填；两层协作与 token 卫生固定写入，不裁剪、不作为决策点。 |
| `docs/CONTEXT.md` | 只在能从既有文档提炼出真实领域语言时生成；提炼不到就只放骨架 + `【待定】`，不编词汇。 |
| `docs/README.md` | 按模板生成。 |
| `docs/issues/index.json` | 状态真相源（票状态机唯一真相源，单文件一条目一行）；已有票的项目建快照登记（缺失才建，格式见公开包 `references/schemas/issue-index.schema.json`）。 |
| `docs/issues/` 新票 JSON 本体 | 既有项目采用本体系后，新开任务票/REQ 以 JSON 文件承载（task `<NN>-<slug>.json`、request `<REQ-id>.json`，schema 见公开包 `references/schemas/ticket-record.schema.json`；本体无 `status` 字段，票状态真相源＝`docs/issues/index.json`）；存量 Markdown 票与既有 REQ 冻结零改写（frontmatter 为历史形态，定稿口径）。 |
| `docs/requests/index.json` | REQ 状态真相源（Request 状态机，单文件一条目一行，与票账本分账，定稿口径）；已有 REQ 的项目建快照登记（缺失才建，格式见公开包 `references/schemas/request-index.schema.json`）。 |
| `docs/changes.jsonl` | 新的决策记录账（一行记一件事，只追加不修改，用到才建）；项目尚有旧 `docs/changes.md` 时冻结旧档并加指针注记，新事实只写 JSONL，不迁移历史。 |
| 根/目录 `README.md` | 缺失才生成；已存在的只把"直接成员登记"补齐，其余内容原样保留。 |
| `.gitignore` | 缺失才生成；已存在的只追加明显缺失的条目（依赖、构建产物、`.env`），追加前列出。 |
| 三阶段角色合同（`docs/agent/roles/`） | 平台无关角色合同缺失才生成（协作固定，不作为决策点），宿主运行时入口由适配层生成；已存在的对照 development-process 代理协作章节校验角色边界是否一致。 |
| `scripts/` 共享验证脚本 | 已有脚本目录登记为共享验证权威并补 README 约定；已有一次性验证脚本列"待沉淀"清单交用户决定是否迁移；缺失则用到才建。 |
| 快道脚本（装哪几件、每件的复制来源见公开包 `scripts/install-policy.rules`） | 你确认启用分级快道（简单小任务免走全流程）时才补缺：经 agent-up 公开包 `scripts/install.sh`（`--target <目标项目根> --fast-lane`）复制到目标项目 `scripts/`（装哪几件、每件从哪复制、登记什么值以 `install-policy.rules` 数据为准，本表不复写；`scripts/` 目录缺失由脚本创建并输出提示行，`scripts/README.md` 生成归执行体），逐件登记 `docs/agent/artifacts.yaml` 条目（登记口径以包内 development-process §5.3.1 为准）；不启用不装，快道脚本不可用的停止条件按 development-process R-DP-031 兜底；当前任务状态一览 `docs/progress-current.md` 由装好的进度生成器自 `docs/issues/index.json` 生成，只由生成器写。 |
| 票务运维脚本（装哪几件同上数据源） | 目标项目采用任务票体系（`docs/issues/` 目录创建）时补缺（记录层标配，与快道启用互不相干、各装各的）：经 agent-up 公开包 `scripts/install.sh`（`--target <目标项目根> --ticket-ops`）复制到目标项目 `scripts/`（含生成器回退依赖注记，装哪几件以 `install-policy.rules` 为准），逐件登记 `docs/agent/artifacts.yaml` 条目（登记口径以包内 development-process §5.3.1 为准）；不采用任务票体系不装。 |
| `scripts/generate-module-map.sh` | 模块地图生成（项目地图的触发条件命中时才装；地图文件不预建，首次运行才生成——R-DP-006）：从 agent-up 公开包 `scripts/` 复制到目标项目 `scripts/` 并逐件登记（`scripts/` 目录缺失则连同 `scripts/README.md` 一并生成）；运行生成 `docs/architecture/module-map.json`（检索索引，不是改哪里的依据），并按 development-process §5.3 登记 `docs/agent/artifacts.yaml`（lifecycle 标注 Derived（可再生文件），generated_from 必填，`sync_on` 对齐拓扑变化行）。 |
| 一次性批量变换（目录搬家、批量路径替换、批量登记改写） | 按生成的 `rules/implementation/discipline.md` R-DP-038 变换合同派发：用完即弃脚本执行＋合同逐条改动清单＋标出需要人判断的点，不默认派探索式执行体逐文件手搬；差异清单给执行方式与预估（直接写脚本/单个 agent/全三阶段管线，见 `SKILL.md` 主流程步骤 4）。 |
| `dp_load_rules` 引擎件升级（四脚本内嵌同款函数：`check-artifacts.sh`／`check-stale-claims.sh`／`export-payload.sh`／`worktree-add.sh`） | 落地拷贝的解析器版本对齐（包升级加锚点/指令后旧拷贝报「解析破坏」时的修复路径）：①先看本件头部 `# dp-parser: N` 版本注记——无该行＝升级前老拷贝，N 小于包内同件注记＝落后，均按②同步；②自包内现版同件同步六 hunk（`BEGIN` 锚点表 `an`/`sc` 行、`dpv` 版本变量、`is_known` 指令清单、锚点循环上界与违属校验块、锚点形态识别块（`# ==== X：…====` 形态行不识别即报错）、未知指令定向文案句）——四件逐件同步后 `sh -n` 核对并以未知锚点/指令夹具复跑验证定向报错；同步仅对齐解析表与报错文案，不改解析六规则与 fail-closed 语义。 |

## 4. 差异清单先行

差异清单按 `SKILL.md` 主流程"差异清单确认"步骤的通用规则执行——所有模式一律先行、含现状与目标对比、按四类分组。旧项目模式额外要求：

- **登记不动**一列要明确到具体文件，尤其是既有规则文件（`.cursorrules` 等）和架构文档，让用户看清哪些东西被登记为权威来源但保持原样。
- 用户否决的项记入报告，不悄悄绕过。

## 5. 收尾报告差异

旧项目模式下，报告额外包含：登记了哪些既有权威来源、哪些既有规则与体系存在冲突、建议后续补头/补登记的文件清单（不在本次执行）。
