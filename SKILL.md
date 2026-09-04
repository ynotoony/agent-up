---
name: agent-up
description: 把 Agent Up 治理体系初始化或补齐到任意项目：AGENTS.md 路由入口、docs 权威文档分层、docs/agent/roles 三阶段角色合同、机器产物索引、契约头与目录 README 登记、可审计交付门禁。当用户要求"初始化这个项目"、"新项目开工"、"给项目加 agent 规则/治理"、"补 AGENTS.md"、"补 README 登记或契约头"，或在空目录/已有仓库里开始正式工作前建立规则时使用；对新项目和旧项目都生效，旧项目只补缺、不覆盖既有事实。
---
<!-- Input: 目标项目的盘点结果、访谈结论、既有事实与用户确认的差异清单。 -->
<!-- Output: 目标项目治理骨架的安装与补缺执行路径、三阶段门禁约束与收尾报告；详细协议按需读取 references/ 手册，不在本文件复制。 -->
<!-- Pos: Agent Up 公开包 Skill 入口，只承载定位、触发条件、核心规则、主流程、按需指引与输出要求六类内容；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Agent Up 项目治理初始化

## 1. 定位

Agent Up 是给 AI Agent 的项目交付脚手架：本技能把"路由入口 + 权威文档分层 + 机器产物索引 + 三阶段角色合同 + 契约头"安装到目标项目，让工作可验证、可接续、可审计。本技能只做初始化与补缺：不生成业务代码，不替目标项目决定领域事实，不把外部 skill 变成目标项目内置角色。

## 2. 触发条件

- 用户要求初始化项目、新项目开工，或为项目补治理规则、补 `AGENTS.md`、补目录 README 登记或契约头。
- 空目录或已有仓库中，正式开工前需要建立 Agent 工作规则。
- IF 目标项目已有治理体系 THEN 只补缺失件并校验联动，不执行全新安装。

## 3. 不可违反的核心规则

违反任何一条即失败；完整协议权威是安装到目标项目的 `docs/development-process.md`（由本包 `references/templates/development-process.md.tmpl` 生成）：

1. **路由不复制**：`AGENTS.md` 只做路由和边界声明；流程细节只存在于 development-process 一个事实源。
2. **不覆盖事实**：既有文档、代码布局、命名和规则一律视为项目事实，只登记、只补缺；冲突报告用户，不静默改写。
3. **不编造事实**：领域词汇、目录职责、验证命令来自盘点和访谈；没有依据的写 `【待定：...】` 并在报告列出。
4. **三阶段门禁不裁剪**：Implementation -> Review -> Commit 串行、不得合并；语义变化未经用户确认不写文件，无验证证据不算完成，无独立 Review 通过不提交。
5. **平台无关**：核心协议与模板只写能力，不写宿主专名与方言；宿主映射只在包内 `references/adapters/`。
6. **冲突即停**：任何两个权威来源冲突时停止修改、报告双方与层级、给出选项、等用户裁决（规则见 `references/protocol/read-policy.md`）。

## 4. 主流程

盘点 → 模式判定 → 访谈与待定 → 差异清单确认 → 安装/补缺 → Implementation → Review → Commit → 收尾报告。

1. **盘点**：查清 Git 状态、既有规则文件（如 `AGENTS.md`、`CONTRIBUTING.md`、其他宿主规则文件）、技术栈标记、测试/构建/验证命令与顶层目录实际用途；目录职责抽查内部文件确认，不凭目录名猜。
2. **模式判定**：全新（空目录或无治理骨架）/ 已有代码（先读 `references/old-project.md`）/ 部分治理（只补缺）。目标目录不是 Git 仓库时，是否 `git init` 由用户确认决定，不自行初始化。
3. **访谈与待定**：新项目先把定位、角色、核心对象、状态与合法转换、主要流程、范围边界、技术栈与验证方式问清（一次一个问题，附推荐答案；能从仓库查到的事实自己查）；项目特有术语敲定后按 `CONTEXT.md.tmpl` 的词条格式写入领域上下文；没问到的一律 `【待定：...】`，不编造。
4. **差异清单确认**：任何写入之前，先给用户差异清单并等待确认，确认前一个字都不写；清单含现状与目标，按四类分组——将新建 / 将修改 / 登记不动 / 冲突待决。每张任务票评估 Complexity 与 Requirement Profile 并写入任务合同；分级、拆票与委派合同规则的权威在生成的 `docs/development-process.md`（何时拆票、委派合同、三道门禁各节），本文件不复制其表格。
5. **安装/补缺**：按 `references/templates/README.md` 的 manifest 生成 seed 七件套、命中的条件产物与三阶段角色合同（生成到 `docs/agent/roles/`）；生成件自带契约头；模板中"按项目填写"处用盘点与访谈结果填充，没问到写 `【待定：...】`。旧项目和部分治理只补缺失件，登记既有权威来源。
6. **Implementation**：按任务合同实现变更并运行相关验证，记录检查点；完整交付后停止，不提交。
7. **Review**：由独立于实现者的执行体只读审查；失败则回 Implementation 修复并完整交付后重新独立审查。
8. **Commit**：仅在用户授权与白名单满足后提交；不 push、不部署。
9. **收尾报告**：报告模式判定、访谈结论、新建与修改文件、Complexity/Profile 及证据位置、`【待定】`清单、冲突、验证结果与建议下一步。

## 5. 按需参考手册（不默认加载）

| 手册 | 何时读 |
| --- | --- |
| `references/protocol/governance-format.md` | 生成或修改治理文件、核对规则块九字段、元数据承载形态或措辞禁令时 |
| `references/protocol/read-policy.md` | 判定会话读取范围、处理权威冲突或按 capability profile 档位加载时 |
| `references/protocol/complexity-profile.md` | 规划、拆票或写任务票前：评估 Complexity 与 Requirement Profile、判定 C2/C3 触发矩阵命中或拆票策略时 |
| `references/old-project.md` | 已有代码或部分治理项目的盘点、补缺与交付 |
| `references/templates/README.md` | 生成治理骨架前：模板 manifest、seed 七件套映射、条件产物触发矩阵与角色合同模板 |
| `references/adapters/`（成员见其目录 README） | 判定宿主能力、处理 `required_capabilities` 冲突、无独立执行体降级，或在宿主生成角色运行时入口时 |
| `references/schemas/`（成员见其目录 README） | 会话恢复填写 run record 或校验其字段时 |

## 6. 最小输出要求

- 验证记录真实命令、环境、日期、结果；未运行的验证写 `N/A + reason`，不以"应该可以"代替证据。
- 全部 `【待定】`项与用户否决的项进入最终报告，不悄悄绕过。
- 权威冲突按停改、报告、给选项、等裁决处理，证据落盘（见 `references/protocol/read-policy.md`）。
- 报告说明安装了哪些治理件、登记了哪些既有权威来源、差异清单四类的落点。
- 未获用户明确要求，不执行 `git add`、`git commit`、push、部署或发布。
