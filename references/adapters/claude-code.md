---
id: adapter-claude-code
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 在 Claude Code 宿主生成或维护运行时入口（subagent 定义、hooks、权限配置）时；评估宿主能力满足度时
trigger: Claude Code frontmatter 方言、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Claude Code 官方文档（code.claude.com/docs/en/{hooks,sub-agents,settings}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.1。 -->
<!-- Output: Claude Code 宿主运行时映射：能力→宿主工具对照、三角色 frontmatter 方言模板、独立执行体声明与降级路径。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 docs/agent/roles/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Claude Code 宿主适配层映射（运行时入口）

本文件是平台适配层：把 capability-contract 的能力基元映射为 Claude Code 宿主运行时形态。适配层只是运行时入口，不是事实源；事实源是目标项目 `docs/agent/roles/` 的平台无关角色合同。官方事实依据与取阅日期登记于 `docs/research/2026-09-agent-host-adapters.md` §3.1（公开包外记录）。

## 1. 快速摘要

- 事实源：`docs/agent/roles/implementation.md`、`review.md`、`commit.md`（平台无关角色合同，七节）。
- 本文件承载：能力→宿主工具对照（§2.2）、三角色 frontmatter 方言模板（§2.3）、独立执行体声明与降级路径（§2.4）。
- platform 枚举值：`claude-code`；三类接入面归属：shell hooks 代表（官方 hooks 文档登记 `PreToolUse` 可阻断工具调用）；plugins/subagents 为辅。
- 独立执行体：官方 sub-agents 文档登记 `.claude/agents/<name>.md` 子代理定义（frontmatter `name`/`description`/`tools`/`model`）——支持；不可用时按 §2.4 降级。
- 权限模型登记：settings 分层文件 + `permissions.allow`/`ask`/`deny` 与 `permissions.defaultMode`；deny/ask 立即生效，allow 在目录受信后生效（官方 settings 文档）。
- 许可证登记：工具为专有（已核验 2026-09-06）——仓库无开源 LICENSE 文件（`LICENSE` raw 路径 404），存在 `LICENSE.md` 专有声明（© Anthropic PBC，Use is subject to Anthropic's Commercial Terms of Service，raw 原文核验），非开源；官方文档未标注独立文档许可证，详见调研报告 §3.1。
- 规则权威始终在角色合同与 development-process；hooks 属宿主强制能力登记，不是门禁规则来源。
- 宿主缺少某能力的工具等价物时按 capability-contract R-CC-001 Stop if 处理，不虚报兼容。
- 无独立 subagent 执行体的降级路径见 capability-contract §2.3；本文件不承载流程规则。
- 本文件规则块前缀 `R-CL-`；能力契约手册前缀 `R-CC-`。

## 2. 可执行规则

### 2.1 适配层地位

#### R-CL-001 映射不是事实源 `MUST`

- **When**：创建、修改或评估 Claude Code 平台适配文件时。
- **Action**：适配层只承载运行时映射（subagent 定义文件、hooks 配置形态、工具调用方式）；事实源是 `docs/agent/roles/` 角色合同与核心协议；本文件按宿主方言变化同步。
- **Forbidden**：把适配层当事实源；在适配层新增流程规则或门禁；核心协议或角色合同反向引用本文件内容作为规则依据。
- **Stop if**：适配器与角色合同冲突 → 以合同为准，修正本文件并报告，不改合同。
- **Evidence**：冲突核查以合同为基准通过；本文件无七节合同、门禁等流程规则内容。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）。

### 2.2 能力→宿主工具对照

#### R-CL-002 能力映射与方言同步 `MUST`

- **When**：生成 Claude Code 运行时入口，或角色合同 `required_capabilities` 变化时。
- **Action**：按本节对照表把 `required_capabilities` 展开为宿主工具清单（官方文档登记的内建工具，取阅 2026-09-06）；按 §2.3 方言模板生成入口文件；角色合同能力声明变化后同步对照表与模板。
- **Forbidden**：对照表出现能力清单之外的工具语义；在角色合同内写平台工具名；宿主缺工具等价物时虚报兼容。
- **Stop if**：某能力在宿主无等价工具 → 按 capability-contract R-CC-001 Stop if 走降级路径或明确阻塞，不降低阶段门禁。
- **Evidence**：对照表覆盖九能力基元；入口文件 frontmatter 与角色合同能力声明一一对应。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §2/§4（R-05-001、R-05-003）。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | Glob + Read | 目录与现状盘点 |
| search | Grep、Glob | 文件名与内容检索 |
| read | Read | 读取文件内容 |
| edit | Edit | 修改既有文件 |
| write | Write | 创建新文件 |
| execute | Bash | 可变更工作区状态的命令；受 `permissions` 规则约束 |
| readonly-execute | Bash | 仅只读命令 |
| vcs-read | Bash | git status/log/diff 等只读命令 |
| vcs-write | Bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色 frontmatter 方言模板

入口文件按角色合同生成，frontmatter 形态对齐官方 sub-agents 文档方言（`name`/`description`/`tools`/`model`；description 承载派发摘要，规则权威在角色合同）：

```text
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 docs/agent/roles/implementation.md 为准"
tools: [Read, Grep, Glob, Edit, Write, Bash]
model: inherit
---
```

```text
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 docs/agent/roles/review.md 为准"
tools: [Read, Grep, Glob, Bash]
model: inherit
---
```

```text
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 docs/agent/roles/commit.md 为准"
tools: [Read, Grep, Glob, Bash]
model: inherit
---
```

角色合同 → `required_capabilities` → 宿主工具清单对应：

| 角色合同 | required_capabilities | tools |
| --- | --- | --- |
| docs/agent/roles/implementation.md | inspect, search, read, edit, write, execute | [Read, Grep, Glob, Edit, Write, Bash] |
| docs/agent/roles/review.md | inspect, search, read, readonly-execute | [Read, Grep, Glob, Bash] |
| docs/agent/roles/commit.md | inspect, vcs-read, vcs-write | [Read, Grep, Glob, Bash] |

### 2.4 独立执行体声明与降级路径

#### R-CL-003 独立执行体与降级如实记录 `MUST`

- **When**：在 Claude Code 宿主派发独立 Review，或评估宿主独立执行体能力时。
- **Action**：声明：本宿主支持独立 subagent 执行体（官方 sub-agents 文档，`.claude/agents/<name>.md` 定义，取阅 2026-09-06）；独立 Review 默认由独立 subagent 执行。IF 部署裁剪或权限配置导致 subagent 不可用 THEN 按 capability-contract R-CC-002 依序尝试：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable` 及实际所选替代路径。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径说成"与独立 subagent 等价无差"。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit。
- **Evidence**：审查记录含 `independent_review` 字段与所选路径；run record 可选指针字段按 schema 回填。
- **Owner**：Review 执行体或主 agent（记录降级决定）。
- **Authority**：capability-contract R-CC-002、SPEC-05 §5（R-05-004）。

## 3. 解释与例外

- inspect 映射为 Glob + Read 的组合：目录结构盘点用 Glob，现状内容核对用 Read；单能力对应多工具时按任务需要选用。
- hooks（`PreToolUse` 可 deny 等）是宿主强制能力登记：可用于宿主侧护栏配置，但不取代角色合同与阶段门禁的规则权威；本文件不定义任何 hooks 配置内容。
- `model: inherit` 为方言占位：实际取值按目标项目部署决定；本文件不承诺模型行为。
- 宿主本地适配层实例（目标项目内 `.claude/agents/` 目录）由本映射生成；其与 `docs/agent/roles/` 合同冲突时以合同为准，并报告差异。
- capability profile 档位、platform 枚举扩展规则见 `capability-contract.md`；本文件不复述，避免第二权威。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
