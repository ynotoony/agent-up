---
id: adapter-capability-contract
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主能力契约）；能力语义上游为 SPEC-05（第 3 级）
lifecycle: Live
read_when: 评估宿主兼容性、编写或维护平台适配层、裁决 required_capabilities 冲突、登记新宿主或核对分级交付道快道能力束时
trigger: 能力基元清单、两层协作→能力表、降级路径、readonly_enforcement 等级、capability profile 档位、platform 枚举或分级交付道快道能力束语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 能力基元与能力表对齐 SPEC-05 §2/§3；档位加载范围权威在 read-policy.md §2.4；语义变化须用户确认并同步 SPEC-05 与 read-policy.md；本文件是 adapters/ 内宿主映射文件的共同上游
depends_on: SPEC-05（能力协议上游）；protocol-read-policy（档位加载范围权威）；被 adapters/ 内宿主映射文件依赖
---
<!-- Input: SPEC-05 §2-§7 能力协议、platform 枚举定稿（neutral/zcode）、independent_review 与 run record 指针字段定稿、read-policy.md 档位表。 -->
<!-- Output: 宿主能力契约手册：九能力基元、两层协作→能力表（路由层 Triage＋编码层三阶段；历史 Intake 行退役 2026-10-23）、required_capabilities 声明规则、无 subagent 降级路径（含车道衔接注记）、readonly_enforcement 只读约束等级模型（四级＋pending 标注）与只读约束降级路径、分级交付道微任务道能力束、capability profile 档位定稿与 platform 枚举扩展规则。 -->
<!-- Pos: 公开包 adapters/ 能力契约手册，adapters/ 内宿主映射文件的共同上游；能力语义上游为 SPEC-05；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md（references/README.md）。 -->

# 宿主能力契约

本手册定义宿主必须满足的能力契约：角色合同以 `required_capabilities` 声明所需能力，平台适配层把能力映射为宿主运行时形态。本文件不绑定任何平台的工具形态；工具对照只出现在各宿主映射文件（如 `zcode.md`）。

## 1. 快速摘要

- 运行时能力基元九个固定：inspect / search / read / edit / write / execute / readonly-execute / vcs-read / vcs-write。
- `create-spec` / `create-task` 是治理写入许可，不是宿主运行时能力；历史治理写入许可 `create-request` 已退役（2026-10-23）：新需求一律走任务票（卡片），不再创建 request（REQ），存量 REQ 冻结只读。
- 两层协作→能力表固定两层底线（路由层 Triage＋编码层三阶段；历史 Intake 行随 `create-request` 退役 2026-10-23 移除，见 §2.2 legacy 注记）：路由层 Triage（inspect、search、execute（仅登记编排命令）；create-spec、create-task）、编码层 Implementation（inspect、search、edit、write、execute）、Review（inspect、search、readonly-execute）、Commit（inspect、execute（仅 ticket-run commit 编排入口））。
- 能力表未列 read：edit/write/inspect 组合已蕴含所需读取面；平台无关角色合同把 read 显式列入 `required_capabilities` 是显式化，不是扩权。
- `required_capabilities` 取值限于 §2.1 清单；核心协议与角色合同不得写死平台工具名或 frontmatter 方言。
- 无独立 subagent 执行体时依序走降级路径 a/b/c，记录 `independent_review: unavailable`；同一执行体自检不得标 pass；三条路径均不可用停在 review_ready。
- readonly-execute 的只读约束按宿主声明的 `readonly_enforcement` 等级承载（host-enforced / runner-enforced / policy-only / unavailable，未核验标 pending）：仅 host/runner 级可作宿主保证的正式 Review 能力；policy-only 必须记录降级，unavailable 只能走独立 session、不同执行身份或用户 Review，pending 按 policy-only 从紧处理。
- execute 的 git 写子面按宿主声明的 `git_write_enforcement` 等级承载（独立于 readonly_enforcement，同词表）：仅 host/runner 级为宿主强制拒绝；policy-only/pending/unavailable 为软约束，Implementation 交付报告必须记录该值与降级原因。
- 分级交付道快道（C0，rules/assessment.md §6 R-DP-031）：用户即 Review 车道内降级路径 (c) 升格为合法审查方式；微任务道能力束 = Implementation 束 + vcs-write（经道脚本行使），pass 证据 = 机械门禁输出。
- capability profile 分 `minimum` / `full` 两档：minimum 为读取阶梯 L0-L2 最小集（定稿清单见 `read-policy.md` §2.4），full 按任务型范围执行并按需加载至 L4。
- 档位只描述治理资源加载范围，不是宿主性能、可靠性或功能承诺。
- platform 枚举已知集合 `neutral` / `zcode` / `claude-code` / `codex` / `pi` / `dsh`；新增宿主值先在 artifacts-yaml 模板 platform 注释区登记，再建 `adapters/<host>.md` 映射文件。
- 未测量不声明：无实验数据不得声称 token 节省、速度或可靠性提升。
- 本文件规则块前缀 `R-CC-`；宿主映射文件不设规则块，公共规则只留指向本契约的指针，宿主短码仅作注册表与 README 导航标识。

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
| readonly-execute | 执行命令，只读约束按 readonly_enforcement 等级保证（等级表见 §2.3） |
| vcs-read | 读取版本库状态与历史 |
| vcs-write | 创建提交等版本库写操作 |

`create-spec` / `create-task` 是治理写入许可（允许创建哪类治理文件，对齐目标项目写入所有权矩阵），不是宿主运行时能力。历史治理写入许可 `create-request` 自 2026-10-23 退役：新需求一律走任务票（卡片），不再创建 request（REQ）；存量 REQ 冻结只读（读取面兼容，见 `../schemas/ticket-record.schema.json` 退役标注）。

### 2.2 两层协作→能力表（路由层 Triage＋编码层三阶段）

| 层 | 角色／阶段 | required_capabilities（运行时） | 治理写入许可 |
| --- | --- | --- | --- |
| 路由层 | Triage（主 agent） | inspect、search、execute（仅登记编排命令） | create-spec、create-task |
| 编码层 | Implementation | inspect、search、edit、write、execute | 任务 Scope 内文件 + Implementation Checkpoint |
| 编码层 | Review | inspect、search、readonly-execute | 审查证据（Independent Review Checkpoint） |
| 编码层 | Commit | inspect、execute（仅编排器 `ticket-run.sh <NN> commit`） | 编排器产出 + 提交合同明列的记录翻转 |

注：本表未列 read——edit/write/inspect 组合已蕴含所需读取面（SPEC-05 §7）；平台无关角色合同可把 read 显式列入 `required_capabilities`，属显式化而非扩权，能力表基线不变。Review 行 readonly-execute 的正式保证力随宿主 `readonly_enforcement` 等级而定（§2.3 等级表）：仅 host/runner 级为宿主保证，policy-only/unavailable/pending 按降级记录处理。

Triage 的 execute 只用于登记过的编排命令（ticket-run、ticket-ops、check-dispatch-contract、worktree-add、lane-commit、check-package、generate-progress），不得直接编辑产品或治理状态。Commit 不持有 vcs-read/vcs-write：版本库读取经 inspect 的只读命令，提交与记录翻转一律经编排器；vcs-write 仍保留给编排器与微任务道脚本行使（见下方能力束注记）。

git_write_enforcement 等级（独立于 readonly_enforcement，同四级＋pending 词表）：宿主 execute 行的 git 写子面按本等级登记——host-enforced/runner-enforced 表示宿主或执行器在命令层拒绝 git 写，须注明实施机制；policy-only/pending/unavailable 不构成宿主保证，Implementation 交付报告必须记 `git_write_enforcement: <值>` 与降级原因，不得声称已强制撤权。当前五宿主登记值均为 policy-only/pending（无默认 deny 配置）；需硬隔离时以独立系统用户或只读挂载运行实现会话，或按宿主机制登记 deny 规则后复核升级等级。

legacy 注记（单列，不混入当前流程）：历史 Intake 阶段（required_capabilities：inspect、search；治理写入许可：create-request）随 `create-request` 退役（2026-10-23）移出本表。Triage 是路由层角色，不是编码层三阶段之一：新需求一律走任务票（卡片，由路由层 Triage 开 task 票），不再创建 request（REQ）；存量 REQ 冻结只读。

微任务道能力束注记（分级交付道，rules/assessment.md §6 R-DP-031）：准入判据内的微任务道由单执行体全程完成，能力束 = Implementation 束（inspect、search、edit、write、execute）+ vcs-write。vcs-write 经道脚本行使：调用权在主 agent，微执行体不组装提交合同、不自行执行 git 写；快道收尾（门禁重跑、白名单提交、记录翻转、账本落行）由道脚本按提交合同执行（rules/project.md §12.5 道脚本承载注记），脚本权限边界 = 提交合同白名单。

#### R-CC-001 能力声明 `MUST`

- **When**：编写核心协议、角色合同或评估宿主兼容性时。
- **Action**：以 `required_capabilities` 声明所需能力，取值限于 §2.1 能力清单与治理写入许可；平台无关角色合同在"所需能力"节承载该声明。IF 宿主映射的 execute 行 THEN 按 §2.2 声明 `git_write_enforcement: <等级>`（host-enforced / runner-enforced / policy-only / unavailable / pending）：host/runner 级须注明实施机制，policy-only/pending/unavailable 须在 Implementation 合同保留交付报告记录该值与降级原因的义务。
- **Forbidden**：在核心协议与角色合同中写死任何平台工具名、frontmatter 方言或专有字段；声明 §2.1 之外的"能力"；把 policy-only/pending/unavailable 的 execute 行说成已强制拒绝 git 写，或省略降级记录义务。
- **Stop if**：某阶段所需能力在目标宿主无法满足 → 走 §2.3 降级路径或明确阻塞，不降低阶段门禁；宿主 execute 行缺 `git_write_enforcement` 等级或越出词表 → 补齐后复核，不按默认强制处理。
- **Evidence**：协议与合同文本可按 §2.1/§2.2 逐项核对；核心协议与角色合同的平台专名扫描零命中；各适配器 execute 行含 `git_write_enforcement` 等级（host/runner 级含机制 token），Implementation 合同含该值与降级原因的记录义务。
- **Owner**：Implementation 执行体（经用户确认的方案）。
- **Authority**：SPEC-05 §2/§3（R-05-001）。

### 2.3 readonly_enforcement 等级与无 subagent 降级路径

#### R-CC-002 只读约束等级与降级如实记录 `MUST`

- **When**：宿主映射或使用 readonly-execute 能力时；宿主无独立 subagent 执行体，或独立 Review 无法由独立执行身份完成时。
- **Action**：IF 宿主映射 readonly-execute THEN 在适配器能力对照表该行声明 `readonly_enforcement: <等级>` 及实施机制口径，等级取 §2.3 等级表四级之一，未核验处按 R-AT-001 标 pending 并注明未核验面，不虚构核验来源；IF 无独立 subagent 执行体 THEN 依序尝试替代路径：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable`（含义：平台无独立 subagent 执行体）及实际所选替代路径 ELSE 使用独立 subagent 执行 Review。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径说成"与独立 subagent 等价无差"；把 policy-only/unavailable/pending 声明或当作宿主保证的只读能力；声明等级表之外的等级值。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit；宿主 readonly_enforcement 非 host/runner 级且无法走已声明降级路径 → 停在 review_ready 记录阻塞，不以普通 execute 代行 Review 只读命令。
- **Evidence**：各适配器 readonly-execute 行含 `readonly_enforcement` 等级与实施机制描述；审查记录含 `independent_review` 字段与所选路径，宿主非 host/runner 级时含 `readonly_enforcement` 值与降级原因；run record 可选指针字段 `independent_review`（verdict / ticket_ref / checkpoint / at）在结论落盘后回填（schema：`../schemas/run-record.schema.json`）。
- **Owner**：Review 执行体或主 agent（记录降级决定）；宿主适配层（声明 readonly_enforcement 等级）。
- **Authority**：SPEC-05 §5（R-05-004）。

readonly_enforcement 等级表：

| 等级 | 定义 | Review 审查方式 | 降级路径 |
| --- | --- | --- | --- |
| host-enforced | 宿主在命令执行层面强制只读约束（进程级/文件系统级隔离，工作区与外部状态不可变） | 可作宿主保证的正式 Review 能力 | 无降级；约束失效即停并记录 |
| runner-enforced | 执行器在 readonly-execute 调用栈上强制只读约束（如 read-only 沙箱口径，越界调用被拒） | 可作宿主保证的正式 Review 能力 | 机制不可用时降级 policy-only 并记录 |
| policy-only | 只读约束由调用者（角色/策略）自律维护；执行器同 execute，只读性不受宿主保证 | 不得作为正式 Review 保证；审查记录记 `readonly_enforcement: policy-only` 与降级原因 | 按下方降级路径 (a)/(b)/(c) 执行并记录原文 |
| unavailable | 宿主无 readonly-execute 等价工具或能力 | 不得作为 Review 能力使用；Review 须走独立 session、不同执行身份或用户 Review | 按下方降级路径 (a)/(b)/(c) 执行并记录原文 |
| pending | 等级未按官方文档或宿主实测核验（R-AT-001） | 按 policy-only 同等从紧处理：不得当作宿主保证，核验后落定 | 落定前按 policy-only 记录降级 |

降级记录义务：`readonly_enforcement` 为 policy-only/unavailable/pending 时，审查记录必须记该值与降级原因（宿主无强制机制／配置关闭／核验缺失等）及实际所选审查方式；"只读"名义不提高其证据力上限。

衔接（run record schema 定稿）：审查记录本体落任务票 `## Independent Review Checkpoint`（Review 唯一写入目标）；run record 的 `independent_review` 只承载机器可检索指针，不承载审查本体。

车道衔接注记（分级交付道，rules/assessment.md §6 R-DP-031）：用户即 Review 车道（C0 且含语义判断）内，自降级路径 (c)（用户本人执行 Review）升格为该车道的合法审查方式——用户在主对话对实际 diff 裁决，裁决原文、时间与 diff 摘要由道脚本落盘为 User Review Checkpoint；微任务道（C0 且全机械可验）内，pass 证据 = 道脚本机械门禁输出而非审查结论——"同一执行体自检不得标 pass"的禁令按车道语义重述为：门禁重跑输出可作 pass 证据，审查结论仍不得由微执行体自签；C1+ 任务降级路径与禁令不变。readonly_enforcement 为 host/runner 级的宿主，readonly-execute 可作宿主保证的正式 Review 能力；policy-only/unavailable/pending 须按本节记录降级原文，任何车道不因等级标注放宽只读约束。

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
- **Action**：IF 需要支持新宿主 THEN 依序执行：①在 artifacts-yaml 模板 platform 字段注释区登记新宿主值（目标项目同步其 artifacts.yaml 注释区）；②在 adapters/ 新建 `<host>.md` 宿主映射文件（能力→宿主工具对照、方言承载形态、独立执行体声明、运行时入口形态），不设 `R-<host 短码>-` 规则块——公共规则只留指向本契约的指针（唯一权威＝本文件），宿主短码仅作注册表与 README 导航标识；③核心协议与角色合同保持平台无关，不做平台化改写 ELSE 不预置适配器文件与未使用的 platform 取值。
- **Forbidden**：未登记 platform 取值就在产物中使用该值；把宿主映射写进核心协议或角色合同；为"将来可能"预建适配器文件。
- **Stop if**：新宿主无法满足 §2.2 某阶段所需能力 → 按 R-CC-001 Stop if 走降级路径或明确阻塞，不虚报兼容。
- **Evidence**：platform 取值集合、artifacts-yaml 模板注释区与 adapters/ 映射文件三者一致。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）、SPEC-03 §10 第二项收敛记录。

## 3. 解释与例外

- 本文件位于 adapters/，承载能力契约与档位语义的包内登记；能力语义的规格上游是 SPEC-05，档位加载范围的精确清单权威是 `read-policy.md` §2.4——两者都不是本文件的派生物；核心流程权威（rules/ 流程规则三件、SPEC-04）不依赖本文件。
- 宿主映射文件（`zcode.md` 等）单向依赖本文件；本文件不引用任何宿主映射的工具对照内容。
- 能力表未列 read 的蕴含说明（SPEC-05 §7）：Implementation 的 edit/write/inspect、Review 的 inspect 已蕴含所需读取面；角色合同显式声明 read 是把蕴含面写明，不改变 §2.2 能力表基线。
- 宿主本地适配层实例（如目标项目内 `.zcode/agents/` 目录）由宿主映射文件约定生成；其与 `<role-contract-dir>/` 角色合同冲突时以合同为准（SPEC-05 R-05-003）。
- 本文件与宿主映射文件按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）；`CC`/`ZC` 短码登记于 `../README.md`，governance-format §2.1 手册短码表的补记归后续包结构任务。
- 宿主映射同步义务（承载面单源化）：适配层的能力对照表与方言/承载模板须随角色合同 `required_capabilities` 声明变化同步更新（对照表、模板与差异数据表为同一变更面）。
- 映射免责（承载面单源化）：适配层只承载运行时映射，不是事实源；与角色合同冲突时以合同为准并修正适配文件（SPEC-05 R-05-003）。
- 适配层禁止面（承载面单源化）：禁止在适配层新增流程规则或门禁；禁止核心协议或角色合同反向引用适配层内容作为规则依据；能力对照表不得出现能力清单之外的工具语义。
- 适配层验收证据（承载面单源化）：宿主映射文件无七节合同与门禁内容，冲突核查以角色合同为基准通过；唯一权威指针段之外不承载公共规则正文。
