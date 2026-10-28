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

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Pi 官方文档（pi.dev/docs/latest/{usage,extensions,skills,security}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.3（historical 调研存档，non-normative，非运行时必读）。 -->
<!-- Output: Pi 宿主差异面：能力→宿主工具对照、三角色承载形态、独立执行体声明（Pi 默认无内置独立执行体）；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 <role-contract-dir>/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Pi 宿主适配层映射（运行时入口）

本文件承载 Pi 宿主的运行时形态：扩展、skills 与上下文约定、工具对照；官方事实依据与取阅日期以各条目内官方文档取阅注记为准；`docs/research/2026-09-agent-host-adapters.md` §3.3 为 historical 调研存档（non-normative，非运行时必读，不作规范依据）。

## 1. 快速摘要

- platform 枚举值：`pi`；三类接入面归属：插件扩展代表（官方 extensions 文档：TypeScript 模块订阅生命周期事件、注册工具/命令、拦截或修改工具调用）；rules files 为辅（`AGENTS.md`/`CLAUDE.md` 项目上下文与 `~/.pi/agent/AGENTS.md` 全局指令）。
- 独立执行体：官方 usage 文档自述不内置 sub-agents/MCP/permission popups 等；默认无独立执行体，降级路径为本文件强制项（§2.4）；扩展文档含 spawn sub-agents 示例，属扩展面可选能力，不视为核心能力。
- 权限模型登记：官方 security 文档——以启动用户账户权限运行、无内置 sandbox、项目信任（project trust）控制项目本地资源加载且"not a sandbox"。
- 许可证登记：工具 MIT（仓库 LICENSE 原文核验）；pi.dev 文档站点未标注独立许可证（未核验项，状态 pending；historical 调研存档注记，non-normative，非运行时必读）。
- 方言：无 agent Markdown frontmatter；承载形态为 skills（`SKILL.md` frontmatter 必含 `name`、`description`）与上下文文件组合（§2.5）。
- 工具面：`find`/`read`/`grep`/`edit`/`write`/`bash`，逐能力展开见 §2.2。

## 2. 可执行规则

### 2.1 公共规则唯一权威（指针）

- 公共规则（映射免责/事实源、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）唯一权威＝`capability-contract.md`；本文件只承载宿主差异面，不复述其正文。
- 能力基元与阶段表：`capability-contract.md` §2.1/§2.2（规则块 R-CC-001）。
- 只读约束等级与降级路径：`capability-contract.md` §2.3（规则块 R-CC-002）；扩展登记：§2.5（R-CC-005）。

### 2.2 能力→宿主工具对照

本表登记的 Pi 工具口径为本宿主差异面；能力语义与阶段归属见 §2.1 指针。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | find + read | 目录与现状盘点（find 列举、read 核对） |
| search | grep、find | 文件名与内容检索 |
| read | read | 读取文件内容 |
| edit | edit | 修改既有文件 |
| write | write | 创建新文件 |
| execute | bash | 可变更工作区状态的命令（Windows 对应为 powershell）；无内置 sandbox，隔离责任在宿主环境 |
| readonly-execute | bash | 仅只读命令；readonly_enforcement: policy-only（官方 security 文档登记：无内置 sandbox、以启动用户账户权限运行、project trust 不是安全边界，取阅 2026-09-06；只读性由调用方约束，宿主不强制） |
| vcs-read | bash | git status/log/diff 等只读命令 |
| vcs-write | bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色能力映射

角色合同 `required_capabilities` 到本宿主工具口径的对应（行序＝入口生成序）：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| <role-contract-dir>/implementation.md | inspect, search, read, edit, write, execute | find/read、grep/find、read、edit、write、bash |
| <role-contract-dir>/review.md | inspect, search, read, readonly-execute | find/read、grep/find、read、bash（只读命令） |
| <role-contract-dir>/commit.md | inspect, vcs-read, vcs-write | find/read、bash（git 命令） |

### 2.4 独立执行体声明与降级路径

声明：本宿主默认无独立 subagent 执行体——官方 usage 文档自述"intentionally does not include built-in MCP, sub-agents, permission popups, plan mode, to-dos, or background bash"（取阅 2026-09-06）；独立 Review 默认走降级路径。

- 降级：按 `capability-contract.md` §2.3 降级路径 (a)/(b)/(c) 依序尝试，并记录 `independent_review: unavailable` 及实际所选路径（公共规则唯一权威，本文件不复述）。IF 目标项目安装了可 spawn sub-agents 的扩展（官方 extensions 文档示例面）THEN 如实登记该扩展承担执行体，不将其记为核心能力。
- 记录面：审查记录字段与 run record 指针按 `capability-contract.md` §2.3/R-CC-002 登记（公共规则唯一权威，本文件不复述）。

### 2.5 三角色承载形态

Pi 无 agent Markdown frontmatter 方言（官方文档未见子代理定义文件形态）；角色承载按官方 skills 方言（`SKILL.md` frontmatter 必含 `name`、`description`）与上下文文件（`AGENTS.md`/`CLAUDE.md`）组合表达，description 承载派发摘要：示例中的 `<role-contract-dir>` 必须按目标项目登记值展开；新项目默认 `rules/implementation/roles/`，旧项目使用登记的兼容目录（通常是 `docs/agent/roles/`）：

```text
skills/implementation/SKILL.md
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 <role-contract-dir>/implementation.md 为准"
---
```

```text
skills/review/SKILL.md
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 <role-contract-dir>/review.md 为准"
---
```

```text
skills/commit/SKILL.md
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 <role-contract-dir>/commit.md 为准"
---
```

## 3. 解释与例外

- inspect 映射为 find + read 的组合：目录结构盘点用 find，现状内容核对用 read；单能力对应多工具时按任务需要选用。
- 扩展（TypeScript 模块，`pi.on(...)` 事件订阅、可 block/modify tool calls、设置权限门控）是宿主强制能力登记面：可用于宿主侧护栏，但不取代角色合同与阶段门禁的规则权威；本文件不定义任何扩展内容。
- 官方 security 文档登记无内置 sandbox：以启动用户权限运行、project trust 不是安全边界——本映射不声明任何隔离能力，隔离责任在宿主环境部署。
- skills 是按需读取的知识资源（官方 skills 文档口径），不是强制策略执行机制；角色规则的约束力来自角色合同，不来自 skill 文本本身。
- 宿主本地适配层实例（目标项目内 skills/ 目录与上下文文件）由本映射生成；其与 `<role-contract-dir>/` 合同冲突时以合同为准，并报告差异。
- 只读性、档位与扩展规则见 §2.1 指针；本文件不复述公共规则正文。
