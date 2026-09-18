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
<!-- Input: 旧项目盘点事实与既有规则。 -->
<!-- Output: 旧项目治理补缺路径。 -->
<!-- Pos: 旧项目路径参考手册；说明治理体系如何在不改既有事实的前提下补缺。 -->

# 旧项目协调手册

目标是在**不打断既有工作方式**的前提下，让治理体系覆盖旧项目。旧项目的价值在于它的现状；本技能的价值是补上可接续性和规则自持，不是改造。

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
- **不批量加契约头**：契约头先只加到本次生成的治理文档（`AGENTS.md`、docs 权威文档、新建目录 README）。存量源码和文档要不要补头，列为建议交给用户决定。
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
| `docs/changes.jsonl` | 新事实账本（一行一事实，只追加，懒创建）；项目尚有旧 `docs/changes.md` 时冻结旧档并加指针注记，新事实只写 JSONL，不迁移历史。 |
| 根/目录 `README.md` | 缺失才生成；已存在的只把"直接成员登记"补齐，其余内容原样保留。 |
| `.gitignore` | 缺失才生成；已存在的只追加明显缺失的条目（依赖、构建产物、`.env`），追加前列出。 |
| 三阶段角色合同（`docs/agent/roles/`） | 平台无关角色合同缺失才生成（协作固定，不作为决策点），宿主运行时入口由适配层生成；已存在的对照 development-process 代理协作章节校验角色边界是否一致。 |
| `scripts/` 共享 harness | 已有脚本目录登记为共享验证权威并补 README 约定；已有一次性验证脚本列"待沉淀"清单交用户决定是否迁移；缺失则懒创建。 |
| 道脚本（`scripts/check-gates.sh`、`scripts/lane-commit.sh`） | 用户确认启用分级交付道快道时才补缺：从 agent-up 公开包 `scripts/` 复制落位目标项目 `scripts/` 并逐件登记 generation manifest 与 `docs/agent/artifacts.yaml`（`scripts/` 目录缺失则连同 `scripts/README.md` 一并生成）；未启用不补，道脚本不可用停止条件按 development-process R-DP-031 兜底。 |
| `scripts/generate-progress.sh` | 复制落位（道脚本行同款口径）：从 agent-up 公开包 `scripts/` 复制到目标项目 `scripts/` 并逐件登记 generation manifest 与 `docs/agent/artifacts.yaml`（`scripts/` 目录缺失则连同 `scripts/README.md` 一并生成）；现役状态投影 `docs/progress-current.md` 由其从 `docs/issues/index.json` 生成，生成器独占写。 |

## 4. 差异清单先行

差异清单按 `SKILL.md` 主流程"差异清单确认"步骤的通用规则执行——所有模式一律先行、含现状与目标对比、按四类分组。旧项目模式额外要求：

- **登记不动**一列要明确到具体文件，尤其是既有规则文件（`.cursorrules` 等）和架构文档，让用户看清哪些东西被登记为权威来源但保持原样。
- 用户否决的项记入报告，不悄悄绕过。

## 5. 收尾报告差异

旧项目模式下，报告额外包含：登记了哪些既有权威来源、哪些既有规则与体系存在冲突、建议后续补头/补登记的文件清单（不在本次执行）。
