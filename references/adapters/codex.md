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

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Codex 官方文档（developers.openai.com/codex/{guides/agents-md,config-reference,config-advanced,skills,security}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.2（historical 调研存档，non-normative，非运行时必读）。 -->
<!-- Output: Codex 宿主差异面：能力→宿主工具对照、三角色配置方言模板、独立执行体声明；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 <role-contract-dir>/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Codex 宿主适配层映射（运行时入口）

本文件承载 Codex 宿主的运行时形态：config.toml 角色表、hooks 与 AGENTS.md 上下文约定、工具对照；官方事实依据与取阅日期以各条目内官方文档取阅注记为准；`docs/research/2026-09-agent-host-adapters.md` §3.2 为 historical 调研存档（non-normative，非运行时必读，不作规范依据）。

## 1. 快速摘要

- platform 枚举值：`codex`；三类接入面归属：规则文件代表（官方 agents-md 指南登记 AGENTS.md 发现链：全局 → 项目根到当前目录逐级、就近覆盖、默认 32 KiB 上限）；hooks 与 skills 为辅。
- 独立执行体：官方 config-reference 登记 `agents.enabled`（默认 true）、`agents.default_subagent_model` 与 `agents.<name>` 自定义角色——支持。
- 权限模型登记：`sandbox_mode`（read-only / workspace-write / danger-full-access）、`approval_policy` 与 permissions profiles（官方 security/config 文档）。
- hooks 登记为辅助面：`hooks.json` 或 config.toml 内联 `[hooks]` 表（事件含 PreToolUse、PermissionRequest、SubagentStart/Stop 等）；项目级钩子仅在项目受信时加载。
- 许可证登记：工具 Apache-2.0（仓库 LICENSE 原文核验）；官网页面文档许可证未标注（未核验项，状态 pending；historical 调研存档注记，non-normative，非运行时必读）。
- 方言：config.toml `[agents.<name>]` 自定义角色表，description 承载派发摘要。
- 工具面：`shell` 与 `apply_patch` 两工具承载九能力，逐能力展开见 §2.2。

## 2. 可执行规则

### 2.1 公共规则唯一权威（指针）

- 公共规则（映射免责/事实源、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）唯一权威＝`capability-contract.md`；本文件只承载宿主差异面，不复述其正文。
- 能力基元与阶段表：`capability-contract.md` §2.1/§2.2（规则块 R-CC-001）。
- 只读约束等级与降级路径：`capability-contract.md` §2.3（规则块 R-CC-002）；扩展登记：§2.5（R-CC-005）。
- Git 写强制等级与 fallback：`capability-contract.md` §2.2（规则块 R-CC-001）。

### 2.2 能力→宿主工具对照

本表登记的 Codex 工具口径为本宿主差异面；能力语义与阶段归属见 §2.1 指针。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | shell | 目录与现状盘点命令；盘点面随 sandbox_mode 收敛 |
| search | shell | 检索命令（grep 等） |
| read | shell | 文件读取命令；Codex 无专用只读文件工具登记 |
| edit | apply_patch | 补丁式修改既有文件 |
| write | apply_patch | 补丁式创建文件 |
| execute | shell | 可变更工作区状态的命令；受 `sandbox_mode` 与 `approval_policy` 约束；git_write_enforcement: policy-only（read-only 档位使实现不可行，workspace-write 不拒绝 .git 写，登记面无默认 deny；实现会话交付报告须记该值与降级原因） |
| readonly-execute | shell | 仅只读命令；readonly_enforcement: runner-enforced（`sandbox_mode = "read-only"` 运行器沙箱口径，越界写被执行器拒绝；官方 security/config 文档登记，取阅 2026-09-06） |
| vcs-read | shell | git status/log/diff 等只读命令 |
| vcs-write | shell | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色能力映射

角色合同 `required_capabilities` 到本宿主工具口径的对应（行序＝入口生成序）：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| <role-contract-dir>/implementation.md | inspect, search, read, edit, write, execute | shell + apply_patch |
| <role-contract-dir>/review.md | inspect, search, read, readonly-execute | shell（只读命令；sandbox read-only 口径） |
| <role-contract-dir>/commit.md | inspect, execute | shell（仅 ticket-run.sh <NN> commit 编排入口） |

### 2.4 独立执行体声明与降级路径

声明：本宿主支持独立执行体（官方 config-reference 登记 multi-agent 默认启用：`agents.enabled` 默认 true、可 spawn 子代理并可声明 `agents.<name>` 角色，取阅 2026-09-06）；独立 Review 默认由独立执行体执行。

- 降级：`agents.enabled` 被配置为 false 或部署裁剪导致独立执行体不可用时，走 `capability-contract.md` §2.3 降级路径 (a)/(b)/(c)，并记录 `independent_review: unavailable` 及实际所选路径（公共规则唯一权威，本文件不复述）。
- 记录面：审查记录字段与 run record 指针按 `capability-contract.md` §2.3/R-CC-002 登记（公共规则唯一权威，本文件不复述）。

### 2.5 三角色配置方言模板

入口配置按角色合同生成，方言形态对齐官方 config-reference 的 `[agents.<name>]` 自定义角色表（description 承载派发摘要；角色文件化约定由目标项目按宿主部署确定）：示例中的 `<role-contract-dir>` 必须按目标项目登记值展开；新项目默认 `rules/implementation/roles/`，旧项目使用登记的兼容目录（通常是 `docs/agent/roles/`）：

```text
# ~/.codex/config.toml（或目标项目宿主部署位）
[agents.implementation]
description = "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 <role-contract-dir>/implementation.md 为准"
```

```text
[agents.review]
description = "Review 阶段执行体运行时入口；只读独立审查，规则以 <role-contract-dir>/review.md 为准"
```

```text
[agents.commit]
description = "Commit 阶段执行体运行时入口；白名单提交，规则以 <role-contract-dir>/commit.md 为准"
```

### 2.6 模型档位可用性

- 分档能力：仅单档（官方 config-reference 只登记 `agents.default_subagent_model` 一个子代理模型键，取阅 2026-09-06；无按角色或按档位分设的已核实键）。
- 角色级模型键：待实测（官方 config-reference 未登记 `agents.<name>` 的模型字段，取阅 2026-09-06；核验前不写键名）。
- 降级记录格式：`model_tier: default_subagent`（要求档位与单档取值不同时，记录实际生效的键与所要求的档位，不假装已分档；本文件不写模型名）。

| 档位 | 取值来源 |
| --- | --- |
| small | `[agents] default_subagent_model`（唯一已核实子代理模型键，三档共用同一取值） |
| standard | `[agents] default_subagent_model`（同上，三档共用同一取值） |
| strong | `[agents] default_subagent_model`（同上；本宿主不能按档位区分模型能力） |

## 3. 解释与例外

- Codex 工具面以 `shell` 命令执行为主：inspect/search/read/vcs 均经 shell 命令承载，单能力无专用工具时按任务需要选用命令；只读性由调用方约束与 sandbox_mode 共同收敛。
- AGENTS.md 是宿主上下文发现机制（规则文件面）：角色合同不写入 AGENTS.md 之外的平台配置；目标项目如何铺设 AGENTS.md 属宿主本地部署决定，与 `<role-contract-dir>/` 合同冲突时以合同为准，并报告差异。
- skills（`SKILL.md` frontmatter 必含 name/description）是宿主资源分发面登记：本文件不定义任何 skill 内容。
- hooks 是宿主强制能力登记：可用于宿主侧护栏配置，但不取代角色合同与阶段门禁的规则权威。
- 只读性、档位与扩展规则见 §2.1 指针；本文件不复述公共规则正文。
