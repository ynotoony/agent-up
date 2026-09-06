---
id: adapter-dsh
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 在 dsh 宿主生成或维护运行时入口（Cordis 插件、profile 选择、上下文约定）时；评估宿主能力满足度时
trigger: dsh 插件面、能力→工具对照、profile 形态或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、dsh 官方文档（deepseek-ai/deepseek-harness 仓库 docs/，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.4。 -->
<!-- Output: dsh 宿主运行时映射：能力→宿主工具对照、三角色承载形态、独立执行体声明与降级路径（subagent seam 依 profile/provider 配置）。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 docs/agent/roles/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# dsh 宿主适配层映射（运行时入口）

本文件是平台适配层：把 capability-contract 的能力基元映射为 dsh（DeepSeek Harness CLI）宿主运行时形态。适配层只是运行时入口，不是事实源；事实源是目标项目 `docs/agent/roles/` 的平台无关角色合同。官方事实依据与取阅日期登记于 `docs/research/2026-09-agent-host-adapters.md` §3.4（公开包外记录）。

## 1. 快速摘要

- 事实源：`docs/agent/roles/implementation.md`、`review.md`、`commit.md`（平台无关角色合同，七节）。
- 本文件承载：能力→宿主工具对照（§2.2）、三角色承载形态（§2.3）、独立执行体声明与降级路径（§2.4）。
- platform 枚举值：`dsh`；三类接入面归属：插件扩展第二代表（官方架构文档："Every part of the product is a plugin"，Cordis 框架；插件为导出 `apply(ctx)` 的 TypeScript 模块，经 cordis.yml 注册，可逆卸载）；shell hooks 面未在取阅页出现；rules files 面未完整核验【待定】。
- 独立执行体：官方 subagent 文档登记 subagent 为可选 capability seam（`ctx.subagents`，多 provider 并存：spawn-in-process / fork-in-process / acp / codex / claude-code / dsh-sdk）；`sdk-minimal` 明确排除 subagents——声明区分 profile（§2.4）。
- 权限模型登记：dsh-base 含 sandbox 与 approval policy；sdk-minimal 自述 danger-full-access；sandbox 后端 bwrap/Landlock/Seatbelt/ACL；官方 SAFETY 自述未经安全审计、不适合生产。
- 成熟度登记：README 自述 developer preview、预期 breaking changes——方言与对照表可能随版本失效，同步责任见 update_policy。
- 许可证登记：工具与文档 MIT（仓库 LICENSE 原文核验），详见调研报告 §3.4。
- 宿主缺少某能力的工具等价物时按 capability-contract R-CC-001 Stop if 处理，不虚报兼容。
- 无独立 subagent 执行体的降级路径见 capability-contract §2.3；本文件不承载流程规则。
- 本文件规则块前缀 `R-DS-`；能力契约手册前缀 `R-CC-`。

## 2. 可执行规则

### 2.1 适配层地位

#### R-DS-001 映射不是事实源 `MUST`

- **When**：创建、修改或评估 dsh 平台适配文件时。
- **Action**：适配层只承载运行时映射（插件注册形态、profile 口径、工具调用方式）；事实源是 `docs/agent/roles/` 角色合同与核心协议；本文件按宿主方言变化同步。
- **Forbidden**：把适配层当事实源；在适配层新增流程规则或门禁；核心协议或角色合同反向引用本文件内容作为规则依据。
- **Stop if**：适配器与角色合同冲突 → 以合同为准，修正本文件并报告，不改合同。
- **Evidence**：冲突核查以合同为基准通过；本文件无七节合同、门禁等流程规则内容。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）。

### 2.2 能力→宿主工具对照

#### R-DS-002 能力映射与方言同步 `MUST`

- **When**：生成 dsh 运行时入口，或角色合同 `required_capabilities` 变化时。
- **Action**：按本节对照表把 `required_capabilities` 展开为宿主工具口径（取阅页可核验面：sdk-minimal 双工具栈——持久 bash/pwsh 与 str_replace_editor，取阅 2026-09-06）；按 §2.3 形态生成角色承载；角色合同能力声明变化后同步对照表。全量 profile 工具 roster 未核验【待定】，不得以本表冒充全量清单。
- **Forbidden**：对照表出现能力清单之外的工具语义；在角色合同内写平台工具名；宿主缺工具等价物时虚报兼容。
- **Stop if**：某能力在宿主无等价工具 → 按 capability-contract R-CC-001 Stop if 走降级路径或明确阻塞，不降低阶段门禁。
- **Evidence**：对照表覆盖九能力基元且注明核验口径；角色承载与角色合同能力声明一一对应。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §2/§4（R-05-001、R-05-003）。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | bash | 目录与现状盘点命令；sdk-minimal 口径无专用盘点工具【待定：全量 roster】 |
| search | bash | 检索命令（grep 等）【待定：全量 roster】 |
| read | bash | 文件读取命令【待定：全量 roster】 |
| edit | str_replace_editor | 补丁式修改（sdk-minimal 口径核验） |
| write | str_replace_editor | 补丁式创建（sdk-minimal 口径核验） |
| execute | bash | 持久 shell（Linux/macOS；Windows 为 pwsh），300 秒超时、单 owner 终端；受 approval/policy seam 约束（profile 依赖） |
| readonly-execute | bash | 仅只读命令；只读性由调用方约束，profile 默认不强制 |
| vcs-read | bash | git status/log/diff 等只读命令 |
| vcs-write | bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色承载形态

dsh 无 agent Markdown frontmatter 方言（官方文档登记的扩展形态为 TypeScript `apply(ctx)` 模块 + cordis.yml 注册）；角色承载按"角色说明落 skills/插件资源、工具面随 profile"的组合表达，description 承载派发摘要，规则权威在角色合同：

```text
# cordis.yml（目标项目宿主部署位）
plugins:
  - path: ./adapters/roles-implementation   # 导出 apply(ctx) 的 TS 模块：
    # name: implementation
    # description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 docs/agent/roles/implementation.md 为准"
  - path: ./adapters/roles-review           # name: review；只读独立审查描述
  - path: ./adapters/roles-commit           # name: commit；白名单提交描述
```

角色合同 → `required_capabilities` → 宿主工具口径对应：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| docs/agent/roles/implementation.md | inspect, search, read, edit, write, execute | bash + str_replace_editor |
| docs/agent/roles/review.md | inspect, search, read, readonly-execute | bash（只读命令） |
| docs/agent/roles/commit.md | inspect, vcs-read, vcs-write | bash（git 命令） |

### 2.4 独立执行体声明与降级路径

#### R-DS-003 独立执行体与降级如实记录 `MUST`

- **When**：在 dsh 宿主派发独立 Review，或评估宿主独立执行体能力时。
- **Action**：声明区分 profile：全量 profile 支持——官方 subagent 文档登记 subagent capability seam（`ctx.subagents`，多 provider：spawn-in-process / fork-in-process / acp / codex / claude-code / dsh-sdk，取阅 2026-09-06）；`sdk-minimal` 不支持——官方 README 明确排除 subagents。独立 Review 默认由独立 subagent 执行（全量 profile 且已注册 provider）；IF 运行形态为 sdk-minimal、provider 未注册或部署裁剪 THEN 按 capability-contract R-CC-002 依序尝试：(a) 新开独立 session 执行 Review；(b) 用不同执行身份或模型执行 Review；(c) 由用户本人执行独立 Review；并记录 `independent_review: unavailable` 及实际所选替代路径。
- **Forbidden**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；以全量 profile 的 subagent 能力冒充 sdk-minimal 形态；把降级路径说成"与独立 subagent 等价无差"。
- **Stop if**：三条替代路径均不可用 → 任务停在 review_ready，记录阻塞，不进入 Commit。
- **Evidence**：审查记录含 `independent_review` 字段、所选路径与运行 profile；run record 可选指针字段按 schema 回填。
- **Owner**：Review 执行体或主 agent（记录降级决定）。
- **Authority**：capability-contract R-CC-002、SPEC-05 §5（R-05-004）。

## 3. 解释与例外

- 本文件工具对照以 sdk-minimal 双工具口径为已核验底线：inspect/search/read/vcs 均经 bash 命令承载；全量 profile 工具 roster 未核验【待定】，宿主部署可按官方文档补核验后扩表，不虚构工具名。
- 官方架构文档登记 guard 与审批感知的工具执行管线、sandbox 与 approval policy seam：属宿主强制能力登记面，可用于宿主侧护栏，但不取代角色合同与阶段门禁的规则权威。
- 官方 SAFETY 自述未经安全审计、不适合生产；本映射不声明任何隔离或安全能力，隔离责任在宿主环境部署。
- Experimental Agent Teams（opt-in 协调 seam）为官方实验面登记：不作为独立执行体默认形态。
- 宿主本地适配层实例（目标项目内 cordis.yml 与插件目录）由本映射生成；其与 `docs/agent/roles/` 合同冲突时以合同为准，并报告差异。
- capability profile 档位、platform 枚举扩展规则见 `capability-contract.md`；本文件不复述，避免第二权威。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
