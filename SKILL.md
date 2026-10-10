---
name: agent-up
description: 把 Agent Up 工作规则体系初始化或补齐到任意项目：AGENTS.md 路由入口、rules/facts 规则与事实文档分层、写代码/检查/提交三个角色的岗位合同、机器可查的产物索引、每个文件开头的工作登记块、可核查的交付检查。当用户要求"初始化这个项目"、"新项目开工"、"给项目加 agent 规则/治理"、"补 AGENTS.md"、"补 README 登记或文件头登记块"，或在空目录/已有仓库里开始正式工作前建立规则时使用；已初始化的项目要求"升级"、"同步包新版"、"拉新模板"时也用（升级模式，走 references/upgrade.md）；对新项目和旧项目都生效，旧项目只补缺、不覆盖既有事实。
---
<!-- Input: 目标项目的盘点结果、访谈结论、既有事实与用户确认的差异清单。 -->
<!-- Output: 目标项目工作规则骨架的安装与补缺执行路径、三阶段检查约束与收尾报告；详细协议按需读取 references/ 手册，不在本文件复制。 -->
<!-- Pos: Agent Up 公开包 Skill 入口，只承载定位、触发条件、核心规则、主流程、按需指引与输出要求六类内容；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。（术语注：本文件面向执行体与用户双语阅读——正文术语首次出现处带白话；规则块 ID 与命令名是机器引用锚点不改。） -->

# Agent Up 项目治理初始化

## 1. 定位

Agent Up 是给 AI Agent 的项目交付脚手架：本技能把"路由入口 + 规则/事实文档分层 + 机器可查的产物索引 + 写代码/检查/提交三个角色的岗位合同 + 每个文件开头的工作登记块"安装到目标项目，让工作可验证、可接续、可审计。本技能只做初始化与补缺：不生成业务代码，不替目标项目决定领域事实，不把外部 skill 变成目标项目内置角色。

## 2. 触发条件

- 用户要求初始化项目、新项目开工，或为项目补工作规则、补 `AGENTS.md`、补目录 README 登记或文件头登记块。
- 用户要求升级、同步包新版或拉新模板（目标项目已按本体系初始化）——升级模式，先读 `references/upgrade.md`。
- 空目录或已有仓库中，正式开工前需要建立 Agent 工作规则。
- IF 目标项目已有治理体系且未要求升级 THEN 只补缺失件并校验联动，不执行全新安装；要求升级 THEN 走升级模式。

## 3. 不可违反的核心规则

违反任何一条即失败；完整协议权威是安装到目标项目的规则三件 `rules/assessment.md`＋`rules/implementation/discipline.md`＋`rules/project.md`（由本包 `references/templates/` 拆三规则模板生成）：

1. **路由不复制**：`AGENTS.md` 只做路由和边界声明；流程细节只存在于规则三件（`rules/assessment.md`＋`rules/implementation/discipline.md`＋`rules/project.md`）这一事实源。
2. **不覆盖事实**：既有文档、代码布局、命名和规则一律视为项目事实，只登记、只补缺；冲突报告用户，不静默改写。
3. **不编造事实**：领域词汇、目录职责、验证命令来自盘点和访谈；没有依据的写 `【待定：...】` 并在报告列出。
4. **写代码→检查→提交三步不裁剪**：Implementation -> Review -> Commit 串行、不得合并；语义变化未经用户确认不写文件，无验证证据不算完成，无独立 Review 通过不提交。小任务例外仅对 C0（最小任务）且由 Triage 定级时按准入判据声明的任务生效，执行体无权自选；C0 修正类（修复既有缺陷或既定行为的单请求小改，含语义判断）默认走用户即检查快道：免建票、免独立评审、免五处登记。快道准入判据全文、边界与收尾形态的权威在 `references/protocol/complexity-profile.md` §2.3 与生成的 `rules/assessment.md`（R-DP-031），本条不复述判据。
5. **平台无关**：核心协议与模板只写能力，不写宿主专名与方言；宿主映射只在包内 `references/adapters/`。
6. **冲突即停**：任何两个权威来源冲突时停止修改、报告双方与层级、给出选项、等用户裁决（规则见 `references/protocol/read-policy.md`）。

## 4. 主流程

盘点 → 模式判定 → 访谈与待定 → 差异清单确认 → 安装/补缺 → Implementation → Review → Commit → 收尾报告。

全程按五段检查点管线（checkpoint pipeline）推进：discovery → confirm → generate → verify → handoff（摸底 → 你确认 → 生成 → 验证 → 交接）。六项生成治理收敛模式（盘点记录、取信次序、能力清单、生成件登记并入 artifacts.yaml 一本账 + 对齐更新、检查点管线、证据链登记）在各步骤写进对应文件，规则权威是生成的规则三件（`rules/assessment.md`＋`rules/implementation/discipline.md`＋`rules/project.md`），本文件只标注每件事写在哪。

1. **盘点**：查清 Git 状态、既有规则文件（如 `AGENTS.md`、`CONTRIBUTING.md`、其他宿主规则文件）、技术栈标记、测试/构建/验证命令与顶层目录实际用途；目录职责抽查内部文件确认，不凭目录名猜。盘点结果落为 Discovery Record：逐项登记来源、作用域、冲突与未知，未知写 `【待定：...】`；盘点先于任何生成动作，未登记来源的候选不生成。
2. **模式判定**：全新（空目录或没有工作规则文件）/ 已有代码（先读 `references/old-project.md`）/ 部分治理（只补缺）/ **已治理（升级）**（仓内已有初始化装上的文件且用户要求升级、同步包新版或拉新模板——先读 `references/upgrade.md`，把已装的部分经确认对齐到包新版；既有事实与记录类产物不动）。目标目录不是 Git 仓库时，是否 `git init` 由用户确认决定，不自行初始化。
3. **访谈与待定**：新项目先把定位、角色、核心对象、状态与合法转换、主要流程、范围边界、技术栈与验证方式问清（一次一个问题，附推荐答案；能从仓库查到的事实自己查）；项目特有术语敲定后按 `CONTEXT.md.tmpl` 的词条格式写入领域上下文；没问到的一律 `【待定：...】`，不编造。
4. **差异清单确认**：任何写入之前，先给用户差异清单并等待确认，确认前一个字都不写；清单含现状与目标，按四类分组——将新建 / 将修改 / 登记不动 / 冲突待决。四类分组之外给**执行形态与预估**：先过两问闸——改动面能否逐条列全且每条有机械验收谓词（唯一匹配/期望输出/可跑检查）？两问全过即亲写用完即弃脚本执行（R-DP-038），不进入三选项；不过才逐项（或逐组）标注建议执行形态——亲写脚本 / 单 agent / 全三阶段管线——并给预估与保证差（亲写脚本最快但只承载机械面、无独立 Review 保证，适合一次性批量变换与机械可验改动；单 agent 承担常规单上下文任务；全三阶段管线含独立 Review，保证最强、成本最高）；C2 及以上任务逐项给三形状对比行。每张任务票评估 Complexity 与 Requirement Profile 并写入任务合同；分级、拆票与委派合同规则的权威在生成的规则三件（`rules/assessment.md`＋`rules/implementation/discipline.md`＋`rules/project.md`；何时拆票、委派合同、三道门禁各节），本文件不复制其表格。取信按优先级排序：既有事实 > 用户确认 > 模板 > 自动推断，未知只登记不推断；确认时同时与用户选定能力档位（minimum/full）并落盘能力清单——逐项标 enabled/excluded/pending，排除与待定附原因。
5. **安装/补缺**：按 `references/templates/README.md` 的清单生成初始八件套（seed）、命中的条件产物与三阶段角色合同（生成到 `rules/implementation/roles/`），初始化产物按以下目标形态安放：

   ```
   my-project/
   ├── AGENTS.md                入口（置根）
   ├── rules/                   约束面："应该怎样"
   │   ├── assessment.md            评估规则：需求大小判定（C0~C3）、车道准入、拆票与调研前置
   │   ├── implementation/          实现规则
   │   │   ├── roles/                 三份岗位合同（实现/审查/提交）
   │   │   ├── discipline.md          实现纪律、编程思想五问、三道门禁、worktree 纪律
   │   │   └── scripts/               快道脚本与验证工具（规则的机械执行体）
   │   └── project.md               项目规则：项目自有条款（随生长追加）
   ├── facts/                   事实面："实际怎样"，只追加不改写
   │   ├── requirements/            需求 facts
   │   │   ├── requests/              录入队列
   │   │   ├── tickets/               票本体＋状态索引＋当前状态一览
   │   │   ├── specs/                 规格（每需求的任务书）
   │   │   └── runs/                  大需求运行记录
   │   └── project/                 项目 facts
   │       ├── CONTEXT.md             术语
   │       ├── changes.jsonl          决策记录账（一行一事，只追加）
   │       ├── artifacts.yaml         产物总登记
   │       └── archive/ · micro.jsonl 冻结历史／小任务流水账
   └── .zcode/agents/           运行时入口
   ```

   生成件自带文件头登记块（每个文件开头三行"输入/输出/定位"注释）；模板中"按项目填写"处用盘点与访谈结果填充，没问到写 `【待定：...】`。旧项目和部分治理只补缺失件，登记既有权威来源。快道脚本与票务运维脚本分两套、各自独立决定装不装（都由用户拍板，本流程不代做访谈）：快道脚本在你确认启用分级快道时安装；票务运维脚本在目标项目采用任务票体系（`facts/requirements/tickets/` 目录创建）时安装（记录层标配，与快道无关）。已确认的复制动作经本包 `scripts/install.sh` 执行（`install.sh --target <目标项目根> [--fast-lane] [--ticket-ops]`），装哪几件、每件从哪复制、登记什么值，权威在数据文件 `scripts/install-policy.rules`（外置数据、引擎零专名，本文件不复写映射明细）；装到目标项目 `rules/implementation/scripts/`（目录缺失则由脚本创建并输出提示行，`rules/implementation/scripts/README.md` 生成归执行体），逐件登记 `facts/project/artifacts.yaml` 条目（kind: script；lifecycle、generated_from 等十三字段建议值以脚本输出的登记建议块为准；登记口径以包内拆三规则模板为准）；没启用对应功能就不复制，未启用快道的既有项目迁移按 `references/old-project.md` §3 补缺行安装，快道脚本不可用的停止条件按生成的 `rules/assessment.md`（R-DP-031）照旧兜底；包内 `agent-up/scripts/` 为复制基线、不在包内运行（install.sh 自带包内误运行守卫）。每个生成件随 artifacts.yaml 条目登记（六要素条目内可定位，字段映射见生成的规则三件）；重复执行走对齐更新：检测到人工改过即停并报告而非覆盖，写入前先备份保证可逆。
6. **Implementation**：按任务合同实现变更并运行相关验证，记录检查点；完整交付后停止，不提交。
7. **Review**：由独立于实现者的执行体只读审查；失败则回 Implementation 修复并完整交付后重新独立审查。
8. **Commit**：仅在用户授权与白名单满足后提交；不 push、不部署。
9. **收尾报告**：报告模式判定、访谈结论、新建与修改文件、Complexity/Profile 及证据位置、`【待定】`清单、冲突、验证结果与建议下一步。

历史票记忆淘汰政策（R-DP-039，权威条文在生成的 `rules/project.md` §5.1，本文件只标注每件事写在哪）：五个部分随初始化装上——①类别保留（票 `category` 三值声明：decision 决定类/procedural 过程类/temporal 时效类，schema 与开票流程已承载）；②读取纪律（干活只认现行规则与当前状态一览，旧票只当历史证据）；③替代标记（被推翻的票在索引登记 `superseded_by` 指向替代票，check-stale-claims.sh S7 自动检查指向的票真实存在）；④经验入册（票完成时把"以后都要照做"的说明当场写进规则/事实文件，票面留一句写去哪了——义务条文在生成的 `rules/implementation/discipline.md` 检查点纪律节）；⑤清洗（升级模式专属步骤，`references/upgrade.md` §5 承载：危险票名单交你逐票裁决，不自动删）。面向用户的解释一律先说大白话，仓内行话不直接抛给用户（沟通约定，非机械断言）。

## 5. 按需参考手册（不默认加载）

| 手册 | 何时读 |
| --- | --- |
| `references/protocol/governance-format.md` | 生成或修改治理文件、核对规则块九字段、元数据承载形态或措辞禁令时 |
| `references/protocol/read-policy.md` | 判定会话读取范围、处理权威冲突或按 capability profile 档位加载时 |
| `references/protocol/complexity-profile.md` | 规划、拆票或写任务票前：评估任务大小与需求画像、判定 C2/C3 触发矩阵命中、拆票策略或声明分级快道（两快道准入判据）时 |
| `references/old-project.md` | 已有代码或部分治理项目的盘点、补缺与交付 |
| `references/upgrade.md` | 已治理项目升级（同步包新版）：模式判定命中升级态、盘点已装部分、逐件对比与对齐更新全程 |
| `references/templates/README.md` | 生成工作规则骨架前：模板清单、初始八件套（seed）映射、条件产物触发矩阵与角色合同模板 |
| `references/adapters/`（成员见其目录 README） | 判定宿主能力、处理 `required_capabilities` 冲突、无独立执行体降级，或在宿主生成角色运行时入口时 |
| `references/schemas/`（成员见其目录 README） | 会话恢复填写 run record 或校验其字段时 |

## 6. 最小输出要求

- 验证记录真实命令、环境、日期、结果；未运行的验证写 `N/A + reason`，不以"应该可以"代替证据。
- 全部 `【待定】`项与用户否决的项进入最终报告，不悄悄绕过。
- 权威冲突按停改、报告、给选项、等裁决处理，证据落盘（见 `references/protocol/read-policy.md`）。
- 报告说明安装了哪些治理件、登记了哪些既有权威来源、差异清单四类各落在哪。
- 报告与对话面向用户的解释先给大白话结论再给规范细节；仓内行话（规则编号、内部代号、文件锚点）不直接抛给用户，必须引用时后跟一句白话解释（沟通约定，配合 R-DP-039 清洗面）。
- 登记外部引用与证据链：规范标识加取阅日期，许可证经条款核验而非信任徽标；涉及侧通道（网络、遥测、后台动作）的工具登记其文档化关闭开关，无开关不引入。
- 未获用户明确要求，不执行 `git add`、`git commit`、push、部署或发布。
