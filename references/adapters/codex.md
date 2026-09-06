---
id: adapter-codex
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 在 Codex 宿主生成或维护运行时入口（config.toml 角色表、hooks、AGENTS.md 上下文）时；评估宿主能力满足度时
trigger: Codex 配置方言、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Codex 官方文档（developers.openai.com/codex/{guides/agents-md,config-reference,config-advanced,skills,security}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.2。 -->
<!-- Output: Codex 宿主运行时映射：能力→宿主工具对照、三角色配置方言模板、独立执行体声明与降级路径。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 docs/agent/roles/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Codex 宿主适配层映射（运行时入口）

本文件是平台适配层：把 capability-contract 的能力基元映射为 Codex 宿主运行时形态。适配层只是运行时入口，不是事实源；事实源是目标项目 `docs/agent/roles/` 的平台无关角色合同。官方事实依据与取阅日期登记于 `docs/research/2026-09-agent-host-adapters.md` §3.2（公开包外记录）。

## 1. 快速摘要

- 事实源：`docs/agent/roles/implementation.md`、`review.md`、`commit.md`（平台无关角色合同，七节）。
- 本文件承载：能力→宿主工具对照（§2.2）、三角色配置方言模板（§2.3）、独立执行体声明与降级路径（§2.4）。
- platform 枚举值：`codex`；三类接入面归属：规则文件代表（官方 agents-md 指南登记 AGENTS.md 发现链：全局 → 项目根到当前目录逐级、就近覆盖、默认 32 KiB 上限）；hooks 与 skills 为辅。
- 独立执行体：官方 config-reference 登记 `agents.enabled`（默认 true）、`agents.default_subagent_model` 与 `agents.<name>` 自定义角色——支持；被配置关闭时按 §2.4 降级。
- 权限模型登记：`sandbox_mode`（read-only / workspace-write / danger-full-access）、`approval_policy` 与 permissions profiles（官方 security/config 文档）。
- hooks 登记为辅助面：`hooks.json` 或 config.toml 内联 `[hooks]` 表（事件含 PreToolUse、PermissionRequest、SubagentStart/Stop 等）；项目级钩子仅在项目受信时加载。
- 许可证登记：工具 Apache-2.0（仓库 LICENSE 原文核验）；官网页面文档许可证未标注【待定注记】，详见调研报告 §3.2。
- 宿主缺少某能力的工具等价物时按 capability-contract R-CC-001 Stop if 处理，不虚报兼容。
- 无独立 subagent 执行体的降级路径见 capability-contract §2.3；本文件不承载流程规则。
- 本文件规则块前缀 `R-CX-`；能力契约手册前缀 `R-CC-`。

## 2. 可执行规则

### 2.1 适配层地位

#### R-CX-001 映射不是事实源 `MUST`

- **When**：创建、修改或评估 Codex 平台适配文件时。
- **Action**：适配层只承载运行时映射（config.toml 角色表、hooks 配置形态、AGENTS.md 上下文约定）；事实源是 `docs/agent/roles/` 角色合同与核心协议；本文件按宿主方言变化同步。
- **Forbidden**：把适配层当事实源；在适配层新增流程规则或门禁；核心协议或角色合同反向引用本文件内容作为规则依据。
- **Stop if**：适配器与角色合同冲突 → 以合同为准，修正本文件并报告，不改合同。
- **Evidence**：冲突核查以合同为基准通过；本文件无七节合同、门禁等流程规则内容。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）。

### 2.2 能力→宿主工具对照

#### R-CX-002 能力映射与方言同步 `MUST`

- **When**：生成 Codex 运行时入口，或角色合同 `required_capabilities` 变化时。
- **Action**：按本节对照表把 `required_capabilities` 展开为宿主工具口径（官方 config-advanced 文档登记的内部工具 `shell` 与 `apply_patch`，取阅 2026-09-06）；按 §2.3 方言模板生成入口配置；角色合同能力声明变化后同步对照表与模板。
- **Forbidden**：对照表出现能力清单之外的工具语义；在角色合同内写平台工具名；宿主缺工具等价物时虚报兼容。
- **Stop if**：某能力在宿主无等价工具 → 按 capability-contract R-CC-001 Stop if 走降级路径或明确阻塞，不降低阶段门禁。
- **Evidence**：对照表覆盖九能力基元；入口配置与角色合同能力声明一一对应。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §2/§4（R-05-001、R-05-003）。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | shell | 目录与现状盘点命令；盘点面随 sandbox_mode 收敛 |
| search | shell | 检索命令（grep 等） |
| read | shell | 文件读取命令；Codex 无专用只读文件工具登记 |
| edit | apply_patch | 补丁式修改既有文件 |
| write | apply_patch | 补丁式创建文件 |
| execute | shell | 可变更工作区状态的命令；受 `sandbox_mode` 与 `approval_policy` 约束 |
| readonly-execute | shell | 仅只读命令；对应 `sandbox_mode = "read-only"` 口径 |
| vcs-read | shell | git status/log/diff 等只读命令 |
| vcs-write | shell | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色配置方言模板

入口配置按角色合同生成，方言形态对齐官方 config-reference 的 `[agents.<name>]` 自定义角色表（description 承载派发摘要，规则权威在角色合同；角色文件化约定由目标项目按宿主部署确定）：

```text
# ~/.codex/config.toml（或目标项目宿主部署位）
[agents.implementation]
description = "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 docs/agent/roles/implementation.md 为准"
```

```text
[agents.review]
description = "Review 阶段执行体运行时入口；只读独立审查，规则以 docs/agent/roles/review.md 为准"
```

```text
[agents.commit]
description = "Commit 阶段执行体运行时入口；白名单提交，规则以 docs/agent/roles/commit.md 为准"
```

角色合同 → `required_capabilities` → 宿主工具口径对应：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| docs/agent/roles/implementation.md | inspect, search, read, edit, write, execute | shell + apply_patch |
| docs/agent/roles/review.md | inspect, search, read, readonly-execute | shell（只读命令；sandbox read-only 口径） |
| docs/agent/roles/commit.md | inspect, vcs-read, vcs-write | shell（git 命令） |

### 2.4 独立执行体声明与降级路径

#### R-CX-003 独立执行体与降级如实记录 `MUST`

- **When**：在 Codex 宿主派发独立 Review，或评估宿主独立执行体能力时。
- **Action**：声明：本宿主支持独立执行体（官方 config-reference 登记 multi-agent 默认启用：`agents.enabled` 默认 true、可 spawn 子代理并可声明 `agents.<name>` 角色，取阅 2026-09-06）；独立 Review 默认由独立执行体执行。IF `agents.enabled` 被配置为 false 或部署裁剪导致独立执行体不可用 THEN 按 capability-contract R-CC-002 依序尝试：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable` 及实际所选替代路径。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径说成"与独立执行体等价无差"。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit。
- **Evidence**：审查记录含 `independent_review` 字段与所选路径；run record 可选指针字段按 schema 回填。
- **Owner**：Review 执行体或主 agent（记录降级决定）。
- **Authority**：capability-contract R-CC-002、SPEC-05 §5（R-05-004）。

## 3. 解释与例外

- Codex 工具面以 `shell` 命令执行为主：inspect/search/read/vcs 均经 shell 命令承载，单能力无专用工具时按任务需要选用命令；只读性由调用方约束与 sandbox_mode 共同收敛。
- AGENTS.md 是宿主上下文发现机制（规则文件面）：角色合同不写入 AGENTS.md 之外的平台配置；目标项目如何铺设 AGENTS.md 属宿主本地部署决定，与 `docs/agent/roles/` 合同冲突时以合同为准，并报告差异。
- skills（`SKILL.md` frontmatter 必含 name/description）是宿主资源分发面登记：本文件不定义任何 skill 内容。
- hooks 是宿主强制能力登记：可用于宿主侧护栏配置，但不取代角色合同与阶段门禁的规则权威。
- capability profile 档位、platform 枚举扩展规则见 `capability-contract.md`；本文件不复述，避免第二权威。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
