---
id: protocol-complexity-profile
kind: protocol
authority: 权威层级第 4 级（流程规则）；复杂度与 Profile 语义上游为 SPEC-06 §4（第 3 级），冲突以 SPEC 为准
lifecycle: Live
read_when: 规划、拆票或写任务票前评估 Complexity 与 Requirement Profile 时；判定 C2/C3 触发矩阵命中、拆票与上下文策略或 Profile 七维证据时；Triage 声明分级交付道车道（快道准入判据）时
trigger: C0-C3 触发条件、高风险面清单、拆票与上下文策略、Profile 七维含义或状态填法、分级交付道快道准入判据语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: C0-C3 表、高风险面清单与七维 Profile 表为定稿基线；数值或语义变化须用户确认并同步上游规格与 development-process 模板指引；规则块 ID 全局唯一不得复用
depends_on: SPEC-06（复杂度画像下沉与 SKILL 六类内容语义）、SPEC-02（格式协议；格式规范由 protocol-governance-format.md 承载）；被 agent-up/SKILL.md 按需手册表与 development-process.md.tmpl §5.2 指引依赖
---
<!-- Input: 本仓库 docs/development-process.md §4/§5 既有 C0-C3 与七维 Profile 定稿语义、协调给定的旧版 SKILL 高风险面基线（旧版正文已重写且 Git 历史不可得）、development-process.md.tmpl §5.2/§8/§11/§12.4 的 C2/C3 与验证阶梯引用事实。 -->
<!-- Output: Agent Up 复杂度分级与 Requirement Profile 的产品事实源：C0-C3 权威表（等级/触发条件/默认拆票与上下文策略/最低交付证据/高风险面清单）与 D/B/I/U/S/M/O 七维 Profile 权威表（含义/Required 最低证据/状态填法）、两者正交原则，以及分级交付道两快道（用户即 Review / 微任务道）准入判据。 -->
<!-- Pos: 公开包 `references/protocol/` 手册之一，复杂度与 Profile 协议的产品事实源；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 复杂度与 Profile 协议

本手册承载任务分级（Complexity C0-C3）与 Requirement Profile（D/B/I/U/S/M/O）的两张权威表及正交原则，供规划、拆票与写票前评估引用。格式、规则块与措辞规范见 `governance-format.md`；读取阶梯与冲突处理见 `read-policy.md`。

## 1. 快速摘要

- 每项工作动工前在任务合同中独立记录 `Complexity: C0|C1|C2|C3`、命中理由和评估日期。
- 任一命中条件即至少该级，按最高命中定级；低级条件不满足不降级已命中的高级。
- 复杂度与 Profile 正交：复杂度不推断 Profile，Profile 不改变复杂度定级。
- C0/C1 单上下文直接交付；C2 以一个上下文可完成为限，预计超限先拆垂直票；C3 不得直接开工，先拆 C0-C2 垂直票或升级协调。
- 分级交付道（三车道）两快道准入判据见 §2.3：车道由 Triage 定级时声明，执行体无权自选；判据外任务一律全三阶段。
- 高风险面五项固定：数据迁移兼容、认证授权、安全隐私、外部服务（含支付）、发布运行可靠性。
- Profile 七维 D/B/I/U/S/M/O 各取 `Required` / `Conditional` / `Advisory` / `N/A` 并附 reason；不留空、不省略维度。
- `Conditional` 写触发条件与本次是否触发；触发时按 `Required` 最低证据执行。
- 适用维度的 `Required` 映射到验证证据（命令、环境、日期、结果、证据位置），不能由 Complexity 代替。
- 目标项目已定义等价权威表时以目标项目权威为准；本手册是 Agent Up 包内默认基线。
- run record 生成条件的"C2/C3"引用以本手册 §2.1 判级为输入；C0/C1 写任务票 Checkpoint。
- 规则块前缀 `R-CP-`；格式规范见 `governance-format.md`（前缀 `R-GF-`）。

## 2. 可执行规则

### 2.1 C0-C3 复杂度权威表

| 等级 | 触发条件（满足其一即至少该级） | 默认拆票与上下文策略 | 最低交付证据 |
| --- | --- | --- | --- |
| C0 | 仅文档、登记、注释或不影响运行行为的元数据；不改生产行为、数据、依赖或公共接口；验收不超过 3 条 | 单上下文直接交付，不拆票 | 范围/差异静态核对；不适用的运行验证逐项 `N/A + reason` |
| C1 | 单一模块或治理件内的行为/配置变更；不改公共接口、数据兼容性、权限边界或外部集成 | 单上下文直接交付，不拆票 | 相关可运行检查或等价静态检查 |
| C2 | 改 1 个公共接口；跨 2 个既有模块；引入 1 个高风险面；验收 4-7 条 | 以一个上下文可完成并验证为限；IF 预计超出一个上下文 THEN 先拆为垂直票再实施 | 契约/集成检查及适用验证（含 run record 生成条件判定） |
| C3 | 无法在一个上下文完成并验证；含 2 个及以上可独立演示或独立回滚的结果；3 个及以上模块；2 个及以上既有公共接口；验收超过 7 条；跨 2 个高风险面；无回滚路径的迁移 | 不得直接开工：拆为 C0-C2 垂直票（每票可独立演示或验证，写明 Blocked by、验收标准与不做什么，按依赖顺序领取）或升级协调 | 各拆出票的交付证据之和；集成验收归属最后的集成票或协调记录 |

高风险面清单（定稿，五项）：

| 高风险面 | 覆盖范围 |
| --- | --- |
| 数据迁移兼容 | 既有数据与模式的迁移、兼容性 |
| 认证授权 | 身份、会话、权限边界 |
| 安全隐私 | 信任边界、秘密、隐私数据处理 |
| 外部服务（含支付） | 第三方集成、支付与计费路径 |
| 发布运行可靠性 | 构建、部署、发布与运行恢复 |

#### R-CP-001 复杂度定级与记录 `MUST`

- **When**：规划、拆票、写任务票，或在规格、变更记录、等价合同中登记工作时。
- **Action**：对照 §2.1 表逐级核对触发条件，记录 `Complexity: C0|C1|C2|C3`、命中理由和评估日期；任一命中即至少该级，按最高命中定级。
- **Forbidden**：未记录等级或命中理由即开工；自造等级（如 C4、"半级"）；用工作量或耗时替代触发条件判级。
- **Stop if**：触发条件命中与否无法判定 → 列入待决项向用户确认后定级，不猜测。
- **Evidence**：任务合同（任务票、规格或变更记录）含等级、命中理由与评估日期。
- **Owner**：主 agent（规划与拆票，development-process 两层模型）。
- **Authority**：本手册 §2.1；SPEC-06 §4（R-06-003）。

#### R-CP-002 C3 拆票门禁 `MUST`

- **When**：任一工作判级为 C3 时。
- **Action**：停止实现；按 §2.1 拆票策略拆为 C0-C2 垂直票（垂直切片，按依赖顺序编号入 `docs/issues/`）或升级协调；拆票理由先更新规格或 `docs/changes.md`。
- **Forbidden**：C3 直接开工；拆出仍命中 C3 的票（IF 单票仍命中 C3 THEN 继续拆或升级协调）；把拆票伪装成单票加长验收清单。
- **Stop if**：无法拆出可独立演示或验证的垂直票 → 停止并升级协调，不降级判级硬开工。
- **Evidence**：C3 判级旁有拆票记录（新票编号或协调记录指针）。
- **Owner**：主 agent（拆票与派发）。
- **Authority**：本手册 §2.1；development-process §8（何时拆票与垂直切片方法权威）。

### 2.2 Requirement Profile 七维权威表

| 维度 | 含义 | `Required` 最低证据 |
| --- | --- | --- |
| D Documentation/governance | 文档、登记与治理面改动 | 契约头、目录成员登记与范围/差异静态核对 |
| B Behavior/business | 业务行为、源码行为或可运行功能改动 | 相关可运行检查或等价可验证证据 |
| I Interface/integration | API、CLI、界面契约、Adapter 或外部系统接口改动 | 契约/集成检查（接口对照、机器 schema 解析或引用可解析性） |
| U Usability/accessibility | 用户界面或用户流程改动 | 界面级验证：用户流程走通与无障碍基本项核对 |
| S Security | 信任边界、认证、授权、秘密或隐私数据处理改动 | 权限验证：明确能做什么与不能做什么 |
| M Migration/data | 模式、数据、迁移或兼容性改动 | 数据核对：迁移前后一致性与回滚路径证据 |
| O Operations | 构建、部署、服务、性能或运行可靠性面改动 | 运行验证：构建、部署或恢复演练及其记录 |

状态填法（四值，逐维附 reason）：

| 状态 | 填法 |
| --- | --- |
| `Required` | 该维度适用且本次交付必须覆盖；记录实际命令、环境、日期、结果与证据位置；同任务内该维度不适用部分逐项 `N/A + reason` |
| `Conditional` | 是否适用取决于任务条件；写明触发条件与本次是否触发；触发时按 `Required` 最低证据执行 |
| `Advisory` | 有价值但非本次门禁；写明 reason 与实际核对范围，不扩展为门禁 |
| `N/A` | 本次不适用；写明 reason，不留空 |

#### R-CP-003 七维独立评估 `MUST`

- **When**：规划、拆票或写任务票评估 Requirement Profile 时。
- **Action**：逐维评估 D/B/I/U/S/M/O 并按 §2.2 状态填法赋值；每个值附 reason；适用维度的 `Required` 映射到验证证据。
- **Forbidden**：省略维度；留空；无 reason 的任何状态；用 Complexity 高低替代维度评估；把 `Advisory` 写成门禁。
- **Stop if**：某维度适用与否无法判定 → 记 `Conditional` 并写触发条件；仍无法判定 → 列入待决项向用户确认。
- **Evidence**：任务合同含七维完整列表，每维状态与 reason 可静态检索。
- **Owner**：主 agent（规划与拆票）。
- **Authority**：本手册 §2.2；SPEC-06 §4（R-06-003）。

#### R-CP-004 复杂度与 Profile 正交 `MUST`

- **When**：评估、复核或 Review 任何任务的 Complexity 与 Requirement Profile 时。
- **Action**：两项评估独立进行：IF 复杂度判级变化 THEN 不改动 Profile 各维状态 ELSE 保持；IF Profile 状态变化 THEN 不改动复杂度判级；Review 对照两表独立核对。
- **Forbidden**：由复杂度推断某维状态（如"C0 所以 S/M/O 一律 N/A"）；由 Profile 维度命中数推升级或降级复杂度；用其中一项结论代替另一项的证据。
- **Stop if**：既有任务合同中两项互相推断（缺独立 reason）→ 记录为缺陷并退回重新独立评估，不就地默认有效。
- **Evidence**：任务合同中复杂度命中理由与七维 reason 各自独立成文，互不引用对方作为唯一依据。
- **Owner**：主 agent（评估）；Review 执行体（复核）。
- **Authority**：本手册 §1/§2；本仓库 `docs/development-process.md` §4/§5 定稿语义（票 10 Fix，2026-09-03）。

#### R-CP-005 目标项目等价权威优先 `MUST`

- **When**：在已安装 Agent Up 的目标项目内评估复杂度与 Profile 时。
- **Action**：IF 目标项目 development-process 或等价权威已定义复杂度/Profile 表 THEN 以该目标项目权威为准 ELSE 以本手册 §2.1/§2.2 为默认基线。
- **Forbidden**：目标项目已有权威表仍用包内手册覆盖之；把本手册的表写进目标项目并声称是目标项目自身的决策。
- **Stop if**：目标项目权威表与本手册基线冲突且目标项目未声明以何者为准 → 按 read-policy R-RP-002 冲突即停处理。
- **Evidence**：评估记录注明所依据的权威表位置（目标项目路径或包内手册）。
- **Owner**：主 agent 或当前会话执行体。
- **Authority**：本手册 §1；read-policy §2.3（权威层级与冲突处理）。

### 2.3 分级交付道快道准入判据

三车道分级交付道（全三阶段 / 用户即 Review / 微任务道）的协议权威在 development-process（§6 分级交付道，R-DP-031）；本节只承载 Triage 声明快道时的准入判据。两条判据均以 §2.1 C0 判级成立为前提；判据外任务一律全三阶段，执行体无权自选车道。

| 车道 | 准入判据（全部满足） |
| --- | --- |
| 用户即 Review | C0 判级成立；工作含语义判断（需用户在主对话对实际 diff 裁决）；裁决原文、时间与 diff 摘要落盘为 Review 证据，OK 后至 Commit 零实现改动 |
| 微任务道 | C0 判级成立；每条验收全机械可验（命令或静态检索可判定通过与否），或纯记录维护（登记行、状态翻转类记录更新）；白名单 ≤3 文件；零新建零删除；含任一语义判断即不入本车道（承重判据，不得放宽） |

#### R-CP-006 快道准入与声明 `MUST`

- **When**：Triage 定级、拆票或写任务票判定任务车道时。
- **Action**：先按 §2.1 判级；C0 任务逐条对照上表：满足"用户即 Review"判据声明该车道，满足"微任务道"判据声明微任务道，任一判据不满足即全三阶段；车道声明与判据命中理由写入任务合同，随派发下达。
- **Forbidden**：执行体自选车道或更改 Triage 车道声明；放宽微任务道"全机械可验"承重判据；拆解含语义判断的工作使其表面上满足微道判据；为进快道改写或压缩验收条件；C1+ 任务声明快道。
- **Stop if**：判据命中与否无法判定 → 按全三阶段处理并报告，不猜测。
- **Evidence**：任务合同含车道声明与逐条判据命中理由，可静态检索。
- **Owner**：主 agent（Triage 定级与车道声明）。
- **Authority**：development-process §6 分级交付道（R-DP-031）；本手册 §2.3。

## 3. 解释与例外

- 数值基线来源：C0-C3 触发条件与最低证据逐条取自本仓库 `docs/development-process.md` §4/§5（Agent Up 自身初始化生成物的定稿语义，与本手册表逐条一致）；高风险面五项清单为协调给定的旧版 SKILL 语义基线——旧版 SKILL 正文已重写、本仓库 Git 历史不可得，原始行文无法从包内核验，按协调指令采用，不构成编造；本仓库 `docs/development-process.md` §8 的"数据迁移、权限、外部集成"三面枚举为旧代际窄化表述，生成项目以该项目 development-process 为准（R-CP-005）。
- 本手册只承载两张表与正交原则；垂直切片拆票方法、委派合同与三道门禁的权威在 development-process（模板 §6/§8 与生成物对应节）；run record 生成条件语义权威在 development-process §12.4，其"C2/C3"引用以本手册 §2.1 判级为输入；C0/C1 不强制 run record，验证记录写任务票 Checkpoint。
- 分级交付道两快道准入判据（§2.3）是 REQ-20260904-011 用户拍板语义的包内判据承载；三车道定义、道脚本与派生载体独占写的协议权威在 development-process（模板 §6 分级交付道、§12.5 道脚本承载注记），本手册不重复其语义。
- 目标项目生成物的权威表位置由 development-process §5.2 的【按项目填写】指引声明；本手册是包内默认基线，不是对生成项目的直接约束（R-CP-005）。
- 本手册短码 `CP` 登记于 `protocol/README.md`；`governance-format.md` §2.1 正式表的补记与 `CC`/`ZC` 一并递延（该手册正文当前冻结，沿票 09/10 先例以目录 README 登记面承载）。
- 本手册自身按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
