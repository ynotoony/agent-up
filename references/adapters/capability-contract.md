---
id: adapter-capability-contract
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主能力契约）；能力语义上游为 SPEC-05（第 3 级），冲突以 SPEC-05 为准
lifecycle: Live
read_when: 评估宿主兼容性、编写或维护平台适配层、裁决 required_capabilities 冲突或登记新宿主时
trigger: 能力基元清单、阶段→能力表、降级路径、capability profile 档位或 platform 枚举语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 能力基元与阶段表对齐 SPEC-05 §2/§3；档位加载范围权威在 read-policy.md §2.4；语义变化须用户确认并同步 SPEC-05 与 read-policy.md；本文件是 adapters/ 内宿主映射文件的共同上游
depends_on: SPEC-05（能力协议上游）；protocol-read-policy（档位加载范围权威）；被 adapters/ 内宿主映射文件依赖
---
<!-- Input: SPEC-05 §2-§7 能力协议、票 06 platform 枚举定稿（neutral/zcode）、票 07 independent_review 与 run record 指针字段定稿、read-policy.md 档位表。 -->
<!-- Output: 宿主能力契约手册：九能力基元、五阶段→能力表、required_capabilities 声明规则、无 subagent 降级路径、capability profile 档位定稿与 platform 枚举扩展规则。 -->
<!-- Pos: 公开包 adapters/ 能力契约手册，adapters/ 内宿主映射文件的共同上游；能力语义上游为 SPEC-05，冲突以 SPEC-05 为准；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md（references/README.md）。 -->

# 宿主能力契约

本手册定义宿主必须满足的能力契约：角色合同以 `required_capabilities` 声明所需能力，平台适配层把能力映射为宿主运行时形态。本文件不绑定任何平台的工具形态；工具对照只出现在各宿主映射文件（如 `zcode.md`）。

## 1. 快速摘要

- 运行时能力基元九个固定：inspect / search / read / edit / write / execute / readonly-execute / vcs-read / vcs-write。
- `create-request` / `create-spec` / `create-task` 是治理写入许可，不是宿主运行时能力。
- 阶段→能力表固定五阶段底线：Intake（inspect、search；create-request）、Planning/Triage（inspect、search；create-spec、create-task）、Implementation（inspect、search、edit、write、execute）、Review（inspect、search、readonly-execute）、Commit（inspect、vcs-read、vcs-write）。
- 阶段表未列 read：edit/write/inspect 组合已蕴含所需读取面；平台无关角色合同把 read 显式列入 `required_capabilities` 是显式化，不是扩权。
- `required_capabilities` 取值限于 §2.1 清单；核心协议与角色合同不得写死平台工具名或 frontmatter 方言。
- 无独立 subagent 执行体时依序走降级路径 a/b/c，记录 `independent_review: unavailable`；同一执行体自检不得标 pass；三条路径均不可用停在 review_ready。
- capability profile 分 `minimum` / `full` 两档：minimum 为读取阶梯 L0-L2 最小集（定稿清单见 `read-policy.md` §2.4），full 按任务型范围执行并按需加载至 L4。
- 档位只描述治理资源加载范围，不是宿主性能、可靠性或功能承诺。
- platform 枚举已知集合 `neutral` / `zcode` / `claude-code` / `codex` / `pi` / `dsh`；新增宿主值先在 artifacts-yaml 模板 platform 注释区登记，再建 `adapters/<host>.md` 映射文件。
- 未测量不声明：无实验数据不得声称 token 节省、速度或可靠性提升。
- 本文件规则块前缀 `R-CC-`；宿主映射文件前缀 `R-ZC-`。

## 2. 可执行规则

### 2.1 能力基元清单

| 能力 | 含义 |
| --- | --- |
| inspect | 只读盘点工作区结构与现状 |
| search | 检索文件与内容 |
| read | 读取文件内容 |
| edit | 修改既有文件 |
| write | 创建新文件 |
| execute | 执行命令（可变更工作区状态） |
| readonly-execute | 仅执行只读命令 |
| vcs-read | 读取版本库状态与历史 |
| vcs-write | 创建提交等版本库写操作 |

`create-request` / `create-spec` / `create-task` 是治理写入许可（允许创建哪类治理文件，对齐目标项目写入所有权矩阵），不是宿主运行时能力。

### 2.2 阶段→能力表

| 阶段 | required_capabilities（运行时） | 治理写入许可 |
| --- | --- | --- |
| Intake | inspect、search | create-request |
| Planning/Triage | inspect、search | create-spec、create-task |
| Implementation | inspect、search、edit、write、execute | 任务 Scope 内文件 + Implementation Checkpoint |
| Review | inspect、search、readonly-execute | 审查记录 |
| Commit | inspect、vcs-read、vcs-write | 暂存/提交 |

注：本表未列 read——edit/write/inspect 组合已蕴含所需读取面（SPEC-05 §7）；平台无关角色合同可把 read 显式列入 `required_capabilities`，属显式化而非扩权，阶段表基线不变。

#### R-CC-001 能力声明 `MUST`

- **When**：编写核心协议、角色合同或评估宿主兼容性时。
- **Action**：以 `required_capabilities` 声明所需能力，取值限于 §2.1 能力清单与治理写入许可；平台无关角色合同在"所需能力"节承载该声明。
- **Forbidden**：在核心协议与角色合同中写死任何平台工具名、frontmatter 方言或专有字段；声明 §2.1 之外的"能力"。
- **Stop if**：某阶段所需能力在目标宿主无法满足 → 走 §2.3 降级路径或明确阻塞，不降低阶段门禁。
- **Evidence**：协议与合同文本可按 §2.1/§2.2 逐项核对；核心协议与角色合同的平台专名扫描零命中。
- **Owner**：Implementation 执行体（经用户确认的方案）。
- **Authority**：SPEC-05 §2/§3（R-05-001）。

### 2.3 无 subagent 降级路径

#### R-CC-002 降级与如实记录 `MUST`

- **When**：宿主无独立 subagent 执行体，或独立 Review 无法由独立执行身份完成时。
- **Action**：IF 无独立 subagent 执行体 THEN 依序尝试替代路径：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable`（含义：平台无独立 subagent 执行体）及实际所选替代路径 ELSE 使用独立 subagent 执行 Review。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径说成"与独立 subagent 等价无差"。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit。
- **Evidence**：审查记录含 `independent_review` 字段与所选路径；run record 可选指针字段 `independent_review`（verdict / ticket_ref / checkpoint / at）在结论落盘后回填（schema：`../schemas/run-record.schema.json`）。
- **Owner**：Review 执行体或主 agent（记录降级决定）。
- **Authority**：SPEC-05 §5（R-05-004）。

衔接（run record schema 定稿）：审查记录本体落任务票 `## Independent Review Checkpoint`（Review 唯一写入目标）；run record 的 `independent_review` 只承载机器可检索指针，不承载审查本体。

### 2.4 capability profile 档位（定稿）

#### R-CC-003 档位语义 `MUST`

- **When**：声明 capability profile 或配置治理资源加载范围时。
- **Action**：分 `minimum` / `full` 两档：`minimum` 加载读取阶梯 L0-L2 最小集（定稿清单以 `read-policy.md` §2.4 为权威）；`full` 按任务型最小读取范围执行并按需加载至 L4。档位只描述治理资源加载范围，不是宿主性能、可靠性或功能承诺。
- **Forbidden**：把档位描述为宿主性能、可靠性或功能承诺；`minimum` 档默认加载 L4 资源；在本文件复述或改写 `read-policy.md` 的精确清单形成第二权威。
- **Stop if**：档位边界无法映射到读取阶梯 → 报告并等待用户裁决，不自行扩大加载范围。
- **Evidence**：profile 声明只含资源范围描述，并可对照 `read-policy.md` §2.4 定稿表。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §6（R-05-005）、SPEC-02 §6、read-policy.md §2.4。

收敛记录：SPEC-05 §8 第一项待决（`minimum` 档精确资源清单由 I-01/I-04 在 protocol 手册定稿）已收口——定稿表落 `read-policy.md` §2.4，本文件登记档位语义；SPEC-05 正文的待决标记同步归后续规格维护。

#### R-CC-004 未测量不声明 `MUST NOT`

- **When**：任何输出、手册或协议文本描述本工具链收益时。
- **Action**：收益声明以记录的实验数据为前提（对齐 SPEC-06 发布前场景 11）。
- **Forbidden**：无实验数据而声称 token 节省、速度或可靠性提升。
- **Stop if**：用户要求写此类声明 → 出示数据缺失事实，等待实验或撤回声明。
- **Evidence**：所有收益声明可指向实验数据记录。
- **Owner**：所有执行体。
- **Authority**：SPEC-05 §6（R-05-006）、SPEC-06 §7（R-06-009）。

### 2.5 platform 枚举与宿主扩展

platform 取值描述产物或文件的平台绑定面：`neutral` 表示平台无关；宿主值仅用于宿主适配层实例与绑定产物。已知集合 `neutral` / `zcode` / `claude-code` / `codex` / `pi` / `dsh`（与 artifacts-yaml 模板 platform 字段注释区一致）。

#### R-CC-005 新宿主扩展登记 `MUST`

- **When**：需要支持新宿主、登记新 platform 取值或新增平台适配文件时。
- **Action**：IF 需要支持新宿主 THEN 依序执行：①在 artifacts-yaml 模板 platform 字段注释区登记新宿主值（目标项目同步其 artifacts.yaml 注释区）；②在 adapters/ 新建 `<host>.md` 宿主映射文件（能力→宿主工具对照、frontmatter 方言、运行时入口形态），规则块前缀 `R-<host 短码>-`；③核心协议与角色合同保持平台无关，不做平台化改写 ELSE 不预置适配器文件与未使用的 platform 取值。
- **Forbidden**：未登记 platform 取值就在产物中使用该值；把宿主映射写进核心协议或角色合同；为"将来可能"预建适配器文件。
- **Stop if**：新宿主无法满足 §2.2 某阶段所需能力 → 按 R-CC-001 Stop if 走降级路径或明确阻塞，不虚报兼容。
- **Evidence**：platform 取值集合、artifacts-yaml 模板注释区与 adapters/ 映射文件三者一致。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）、SPEC-03 §10 第二项收敛记录。

## 3. 解释与例外

- 本文件位于 adapters/，承载能力契约与档位语义的包内登记；能力语义的规格上游是 SPEC-05，档位加载范围的精确清单权威是 `read-policy.md` §2.4——两者都不是本文件的派生物；核心流程权威（development-process、SPEC-04）不依赖本文件。
- 宿主映射文件（`zcode.md` 等）单向依赖本文件；本文件不引用任何宿主映射的工具对照内容。
- 能力表未列 read 的蕴含说明（SPEC-05 §7）：Implementation 的 edit/write/inspect、Review 的 inspect 已蕴含所需读取面；角色合同显式声明 read 是把蕴含面写明，不改变 §2.2 阶段表基线。
- 宿主本地适配层实例（如目标项目内 `.zcode/agents/` 目录）由宿主映射文件约定生成；其与 `docs/agent/roles/` 角色合同冲突时以合同为准（SPEC-05 R-05-003）。
- 本文件与宿主映射文件按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）；`CC`/`ZC` 短码登记于 `../README.md`，governance-format §2.1 手册短码表的补记归后续包结构任务。
