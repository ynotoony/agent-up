---
id: protocol-read-policy
kind: protocol
authority: 权威层级第 4 级（流程规则）；读取与权威语义上游为 SPEC-02（第 3 级）
lifecycle: Live
read_when: 会话开始取用治理资源时；判定读取范围、处理权威冲突或按档位加载时
trigger: 读取阶梯、任务型最小读取范围、权威层级或档位加载范围语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 阶梯表、任务型范围表与权威层级顺序为定稿基线；语义变化须用户确认并同步 SPEC-02；minimum 档清单已联动定稿为基线（2026-09-03）
depends_on: SPEC-02、SPEC-04（恢复顺序优先）、SPEC-05 §6（档位语义）、protocol-governance-format.md（格式规范）；minimum 档清单定稿联动收口（已完成，2026-09-03）
---
<!-- Input: SPEC-02 §6/§7 读取阶梯与权威层级、SPEC-05 §6 档位语义、SPEC-04 恢复顺序边界与公开包现有结构事实。 -->
<!-- Output: Agent Up 会话的读取阶梯、任务型最小读取范围、权威层级冲突处理与 capability profile 档位加载手册。 -->
<!-- Pos: 公开包 `references/protocol/` 手册之一，读取协议的产品事实源；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 读取协议

本手册把 SPEC-02 §6/§7 的读取阶梯与权威层级落成 Agent Up 会话取用治理资源时的产品事实源。文件格式、规则块与措辞规范见 `governance-format.md`。

## 1. 快速摘要

- 读取阶梯五级固定：L0 `AGENTS.md` → L1 `docs/progress-current.md`（现役状态投影，Derived）+目录 README → L2 任务票/规格/artifacts.yaml → L3 源码、测试、模板 → L4 protocol/历史/架构按需。
- 按任务类型取最小读取范围；必读集合不得跳过，L4 一律按需，不默认加载。
- 五类任务必读集合：解释 L0；文档/治理维护 L0+L1+L2（涉及件）；新功能/实施 L0-L3；Review L0+L2+实际 diff/文件；Commit L0+L2（含 Review pass 证据）+Git 状态。
- 权威层级六层固定：用户决策 > 目标项目代码/测试/事实记录 > 规格/任务合同 > 流程规则 > Agent Up 模板 > 项目地图等派生文件。
- 冲突即停：停止修改、报告冲突双方与各自层级、给出可选项、等待用户裁决。
- 用户不在场时保持停止状态并记录阻塞，不推进。
- capability profile 分 `minimum`/`full` 两档：`minimum` = 读取阶梯 L0-L2 最小集（已定稿）；`full` 按任务型范围执行并按需加载至 L4。
- 档位只描述治理资源加载范围，不是宿主性能、可靠性或功能承诺。
- 恢复会话按 SPEC-04 恢复流程固定顺序执行，读取阶梯不替代恢复顺序。
- 本手册规则块前缀 `R-RP-`；格式与措辞规范见 `governance-format.md`（前缀 `R-GF-`）。

## 2. 可执行规则

### 2.1 读取阶梯（L0-L4）

| Level | 内容 | 定位 |
| --- | --- | --- |
| L0 | 目标项目 `AGENTS.md` | 路由与边界；每个会话第一步 |
| L1 | `docs/progress-current.md`（现役状态投影，Derived）+ 各目录 `README.md` | 当前状态与导航地图 |
| L2 | 当前任务票、相关规格、`docs/agent/artifacts.yaml` | 任务合同与规范本体 |
| L3 | 与改动相关的源码、测试、模板 | 实施对象事实 |
| L4 | protocol 手册、`changes.md` 历史、架构资料、ADR、research | 协议细节与背景，按需加载 |

#### R-RP-001 按阶梯读取 `MUST`

- **When**：任何会话开始取用治理资源时。
- **Action**：按 §2.2 任务型最小读取范围表取用；必读集合不得跳过；L4 一律按需，不默认加载。
- **Forbidden**：跳过 L0 直接动手；用聊天记忆替代阶梯；一次全量加载全部治理文件。
- **Stop if**：必读集合内信息互相矛盾 → 走 R-RP-002 冲突处理。
- **Evidence**：会话产出能引用其读取层级来源（文件路径或检查点指针）。
- **Owner**：当前会话执行体。
- **Authority**：SPEC-02 §6（R-02-009）。

### 2.2 任务型最小读取范围

| 任务类型 | 必读 | 按需 |
| --- | --- | --- |
| 解释/问答 | L0 | L1 |
| 文档/治理维护 | L0、L1、L2（本次涉及件） | L4 |
| 新功能/实施 | L0、L1、L2、L3 | L4 |
| Review | L0、L2、实际 diff/文件 | L3、L4 |
| Commit | L0、L2（含 Review pass 证据）、Git 状态 | 无 |

### 2.3 权威层级与冲突处理

权威顺序固定（高到低）：

1. 用户决策；
2. 目标项目代码、测试与事实记录；
3. 规格、任务合同；
4. 流程规则（development-process）；
5. Agent Up 模板；
6. 项目地图等派生文件。

#### 2.3.1 权威与写入边界矩阵

本矩阵把高层级顺序细化为六个常见冲突域。模板只能引用矩阵 ID，不另立相同事实的 authority、writer 或 resolution；目标项目的已确认权威仍按本节层级优先。

| ID | 冲突域 | Authority | Writer | Resolution | Template consumer |
| --- | --- | --- | --- | --- | --- |
| AW-01 | user-decision-runtime-facts | 用户决定以用户原始决定为权威；运行事实以实际文件、测试与 Git 观察为准 | 用户作决定；Triage 记录决定；产生运行证据的阶段角色记录其实际观察 | 决定冲突按权威层级停止并交用户裁决；运行事实冲突先核对实际文件、测试与 Git，再更正较低层记录 | project.md.tmpl;discipline.md.tmpl;AGENTS.md.tmpl |
| AW-02 | ticket-index-progress | `facts/requirements/tickets/index.json` 是票状态真相源；`progress-current.md` 是其生成投影 | `ticket-ops.sh` 或获授权的收尾阶段执行体单写索引；`generate-progress.sh` 独占写投影 | 状态不一致以索引为准，并重生成、核对投影；禁止并发写索引 | project.md.tmpl;assessment.md.tmpl;agents-commit.md.tmpl;AGENTS.md.tmpl;agents-implementation.md.tmpl |
| AW-03 | triage-intake | 目标项目流程权威定义 Intake 与 Triage 职责；若项目无等价条款，本协议按任务接收与后续治理协调区分 | Intake 仅创建新需求卡；Triage 负责定级、拆分和派发；二者只写各自职责范围 | 输入、分类或写入归属冲突时停止并报告；不得由 Intake 推进存量任务或由 Triage 覆盖原始用户输入 | project.md.tmpl;assessment.md.tmpl;discipline.md.tmpl;AGENTS.md.tmpl |
| AW-04 | review-checkpoint | 当前任务票的 Independent Review Checkpoint 是审查结论本体；run record 仅可保存指向该本体的引用 | Review 执行体唯一写审查结论；当前运行执行体只回填 run record 指针 | 指针与票内结论冲突时以票内 Review Checkpoint 为准；缺少结论本体不得提交 | project.md.tmpl;agents-review.md.tmpl |
| AW-05 | commit-authorization | 主 agent 明列的提交合同定义本次授权范围，且必须存在适用的 Review PASS 证据 | Commit 执行体仅在授权与 Review 证据齐备后按白名单提交 | 授权或 PASS 缺失、白名单冲突时停止，不提交；push、deploy 仍需单独授权 | project.md.tmpl;discipline.md.tmpl;agents-commit.md.tmpl |
| AW-06 | ticket-body-checkpoints | ticket-record schema 定义票本体形状；阶段合同定义各自 checkpoint 内容；索引定义任务状态 | Triage 维护任务合同；Implementation、Review、Commit 分别写各自 checkpoint；索引状态按 AW-02 写入 | 合同语义变更交 Triage；阶段 checkpoint 只由所属角色写；状态冲突按 AW-02，schema 形状冲突按 schema | project.md.tmpl;assessment.md.tmpl;discipline.md.tmpl;agents-implementation.md.tmpl;agents-commit.md.tmpl |

#### R-RP-002 冲突即停 `MUST`

- **When**：任何两个权威来源对同一事实给出不一致结论时。
- **Action**：停止修改；报告冲突双方、各自层级与内容；给出可选项；等待用户裁决后继续。
- **Forbidden**：自行选择一种解释继续写；静默合并两种说法；用低层级来源覆盖高层级来源。
- **Stop if**：用户不在场 → 保持停止状态并记录阻塞，不推进。
- **Evidence**：冲突报告与用户裁决结果落盘到变更记录或任务票。
- **Owner**：当前会话执行体。
- **Authority**：SPEC-02 §7（R-02-010）、REQ-20260903-001。

### 2.4 capability profile 档位加载（minimum 档定稿）

#### R-RP-003 档位加载范围 `MUST`

- **When**：宿主或会话声明 capability profile 为 `minimum` 或 `full` 时。
- **Action**：`minimum` 档治理资源加载范围为读取阶梯 L0-L2 最小集（定稿清单见下表）；`full` 档按 §2.2 任务型最小读取范围执行并按需加载至 L4。档位只描述治理资源加载范围，不是宿主性能、可靠性或功能承诺。
- **Forbidden**：`minimum` 档默认加载 L4 资源；把档位描述为宿主能力承诺。
- **Stop if**：档位边界无法映射到读取阶梯 → 按定稿表报告冲突，不自行扩大加载范围。
- **Evidence**：会话记录声明档位与实际加载层级；profile 声明只含资源范围描述。
- **Owner**：当前会话执行体。
- **Authority**：SPEC-05 §6（R-05-005）、SPEC-02 §6。

`minimum` 档定稿清单：

| 档位 | 治理资源加载范围 |
| --- | --- |
| `minimum` | L0（目标项目 `AGENTS.md`）+ L1（`docs/progress-current.md` 与涉及目录 `README.md`）+ L2 最小集（当前任务票 + 直接相关规格；artifacts.yaml 在涉及产物关系时加入）；L3 仅按实施动作所需逐个文件加载；L4 不默认加载，protocol 手册仅按需读相关章节 |
| `full` | §2.2 任务型最小读取范围的完整必读集合；L4 按需加载 |

本表已联动定稿（2026-09-03）；档位边界冲突按 R-RP-003 Stop if 处理。

## 3. 解释与例外

- 读取阶梯不替代 SPEC-04 的恢复顺序；恢复会话按 SPEC-04 §8 恢复流程固定顺序执行，其顺序优先。
- L4 资源的精确文件清单在目标项目由 artifacts.yaml 派生（SPEC-02 §11 第二项待决），本手册不枚举。
- 本手册 frontmatter 的 `read_when`/`trigger` 只做导航，不构成规范性读取条件；读取义务以本手册规则块为准。
- `minimum` 档清单是 SPEC-05 §6 待决项（"由 I-01/I-04 在 protocol 手册定稿"）的定稿结果（已联动收口，2026-09-03，本手册 §2.4 为加载范围权威）；SPEC-05 正文的待决标记同步归后续规格维护。
- 本手册自身按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
