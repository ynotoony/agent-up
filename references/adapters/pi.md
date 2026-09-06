---
id: adapter-pi
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 在 Pi 宿主生成或维护运行时入口（扩展、skills、AGENTS.md 上下文）时；评估宿主能力满足度时
trigger: Pi 扩展面、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Pi 官方文档（pi.dev/docs/latest/{usage,extensions,skills,security}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.3。 -->
<!-- Output: Pi 宿主运行时映射：能力→宿主工具对照、三角色承载形态、独立执行体声明与降级路径（Pi 默认无内置独立执行体）。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 docs/agent/roles/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Pi 宿主适配层映射（运行时入口）

本文件是平台适配层：把 capability-contract 的能力基元映射为 Pi 宿主运行时形态。适配层只是运行时入口，不是事实源；事实源是目标项目 `docs/agent/roles/` 的平台无关角色合同。官方事实依据与取阅日期登记于 `docs/research/2026-09-agent-host-adapters.md` §3.3（公开包外记录）。

## 1. 快速摘要

- 事实源：`docs/agent/roles/implementation.md`、`review.md`、`commit.md`（平台无关角色合同，七节）。
- 本文件承载：能力→宿主工具对照（§2.2）、三角色承载形态（§2.3）、独立执行体声明与降级路径（§2.4）。
- platform 枚举值：`pi`；三类接入面归属：插件扩展代表（官方 extensions 文档：TypeScript 模块订阅生命周期事件、注册工具/命令、拦截或修改工具调用）；rules files 为辅（`AGENTS.md`/`CLAUDE.md` 项目上下文与 `~/.pi/agent/AGENTS.md` 全局指令）。
- 独立执行体：官方 usage 文档自述不内置 sub-agents/MCP/permission popups 等；默认无独立执行体，降级路径为本文件强制项（§2.4）；扩展文档含 spawn sub-agents 示例，属扩展面可选能力，不视为核心能力。
- 权限模型登记：官方 security 文档——以启动用户账户权限运行、无内置 sandbox、项目信任（project trust）控制项目本地资源加载且"not a sandbox"。
- 许可证登记：工具 MIT（仓库 LICENSE 原文核验）；pi.dev 文档站点未标注独立许可证【待定注记】，详见调研报告 §3.3。
- 规则权威始终在角色合同与 development-process；扩展的拦截/门控属宿主强制能力登记，不是门禁规则来源。
- 宿主缺少某能力的工具等价物时按 capability-contract R-CC-001 Stop if 处理，不虚报兼容。
- 本文件规则块前缀 `R-PI-`；能力契约手册前缀 `R-CC-`。

## 2. 可执行规则

### 2.1 适配层地位

#### R-PI-001 映射不是事实源 `MUST`

- **When**：创建、修改或评估 Pi 平台适配文件时。
- **Action**：适配层只承载运行时映射（扩展形态、skills 承载、AGENTS.md 上下文约定）；事实源是 `docs/agent/roles/` 角色合同与核心协议；本文件按宿主方言变化同步。
- **Forbidden**：把适配层当事实源；在适配层新增流程规则或门禁；核心协议或角色合同反向引用本文件内容作为规则依据。
- **Stop if**：适配器与角色合同冲突 → 以合同为准，修正本文件并报告，不改合同。
- **Evidence**：冲突核查以合同为基准通过；本文件无七节合同、门禁等流程规则内容。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）。

### 2.2 能力→宿主工具对照

#### R-PI-002 能力映射与方言同步 `MUST`

- **When**：生成 Pi 运行时入口，或角色合同 `required_capabilities` 变化时。
- **Action**：按本节对照表把 `required_capabilities` 展开为宿主工具清单（官方 usage 文档内建工具清单，取阅 2026-09-06）；按 §2.3 形态生成角色承载；角色合同能力声明变化后同步对照表。
- **Forbidden**：对照表出现能力清单之外的工具语义；在角色合同内写平台工具名；宿主缺工具等价物时虚报兼容。
- **Stop if**：某能力在宿主无等价工具 → 按 capability-contract R-CC-001 Stop if 走降级路径或明确阻塞，不降低阶段门禁。
- **Evidence**：对照表覆盖九能力基元；角色承载与角色合同能力声明一一对应。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §2/§4（R-05-001、R-05-003）。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | find + read | 目录与现状盘点（find 列举、read 核对） |
| search | grep、find | 文件名与内容检索 |
| read | read | 读取文件内容 |
| edit | edit | 修改既有文件 |
| write | write | 创建新文件 |
| execute | bash | 可变更工作区状态的命令（Windows 对应为 powershell）；无内置 sandbox，隔离责任在宿主环境 |
| readonly-execute | bash | 仅只读命令；只读性由调用方约束，宿主不强制 |
| vcs-read | bash | git status/log/diff 等只读命令 |
| vcs-write | bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色承载形态

Pi 无 agent Markdown frontmatter 方言（官方文档未见子代理定义文件形态）；角色承载按官方 skills 方言（`SKILL.md` frontmatter 必含 `name`、`description`）与上下文文件（`AGENTS.md`/`CLAUDE.md`）组合表达。description 承载派发摘要，规则权威在角色合同：

```text
skills/implementation/SKILL.md
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 docs/agent/roles/implementation.md 为准"
---
```

```text
skills/review/SKILL.md
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 docs/agent/roles/review.md 为准"
---
```

```text
skills/commit/SKILL.md
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 docs/agent/roles/commit.md 为准"
---
```

角色合同 → `required_capabilities` → 宿主工具口径对应：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| docs/agent/roles/implementation.md | inspect, search, read, edit, write, execute | find/read、grep/find、read、edit、write、bash |
| docs/agent/roles/review.md | inspect, search, read, readonly-execute | find/read、grep/find、read、bash（只读命令） |
| docs/agent/roles/commit.md | inspect, vcs-read, vcs-write | find/read、bash（git 命令） |

### 2.4 独立执行体声明与降级路径

#### R-PI-003 独立执行体与降级如实记录 `MUST`

- **When**：在 Pi 宿主派发独立 Review，或评估宿主独立执行体能力时。
- **Action**：声明：本宿主默认无独立 subagent 执行体——官方 usage 文档自述"intentionally does not include built-in MCP, sub-agents, permission popups, plan mode, to-dos, or background bash"（取阅 2026-09-06）。独立 Review 按 capability-contract R-CC-002 依序尝试：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable` 及实际所选替代路径。IF 目标项目安装了可 spawn sub-agents 的扩展（官方 extensions 文档示例面）THEN 如实登记该扩展承担执行体，不将其记为核心能力。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径或扩展面说成"与独立 subagent 等价无差"。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit。
- **Evidence**：审查记录含 `independent_review` 字段与所选路径；run record 可选指针字段按 schema 回填。
- **Owner**：Review 执行体或主 agent（记录降级决定）。
- **Authority**：capability-contract R-CC-002、SPEC-05 §5（R-05-004）。

## 3. 解释与例外

- inspect 映射为 find + read 的组合：目录结构盘点用 find，现状内容核对用 read；单能力对应多工具时按任务需要选用。
- 扩展（TypeScript 模块，`pi.on(...)` 事件订阅、可 block/modify tool calls、设置权限门控）是宿主强制能力登记面：可用于宿主侧护栏，但不取代角色合同与阶段门禁的规则权威；本文件不定义任何扩展内容。
- 官方 security 文档登记无内置 sandbox：以启动用户权限运行、project trust 不是安全边界——本映射不声明任何隔离能力，隔离责任在宿主环境部署。
- skills 是按需读取的知识资源（官方 skills 文档口径），不是强制策略执行机制；角色规则的约束力来自角色合同，不来自 skill 文本本身。
- 宿主本地适配层实例（目标项目内 skills/ 目录与上下文文件）由本映射生成；其与 `docs/agent/roles/` 合同冲突时以合同为准，并报告差异。
- capability profile 档位、platform 枚举扩展规则见 `capability-contract.md`；本文件不复述，避免第二权威。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
