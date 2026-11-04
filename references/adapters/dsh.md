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

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、dsh 官方文档（deepseek-ai/deepseek-harness 仓库 docs/，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.4（historical 调研存档，non-normative，非运行时必读）。 -->
<!-- Output: dsh 宿主差异面：能力→宿主工具对照、三角色承载形态、独立执行体声明（subagent seam 依 profile/provider 配置）；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 <role-contract-dir>/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# dsh 宿主适配层映射（运行时入口）

本文件承载 dsh（DeepSeek Harness CLI）宿主的运行时形态：Cordis 插件注册、profile 口径、工具对照；官方事实依据与取阅日期以各条目内官方文档取阅注记为准；`docs/research/2026-09-agent-host-adapters.md` §3.4 为 historical 调研存档（non-normative，非运行时必读，不作规范依据）。

## 1. 快速摘要

- platform 枚举值：`dsh`；三类接入面归属：插件扩展第二代表（官方架构文档："Every part of the product is a plugin"，Cordis 框架；插件为导出 `apply(ctx)` 的 TypeScript 模块，经 cordis.yml 注册，可逆卸载）；shell hooks 面未在取阅页出现；rules files 面未完整核验（状态 pending）。
- 独立执行体：官方 subagent 文档登记 subagent 为可选 capability seam（`ctx.subagents`，多 provider 并存：spawn-in-process / fork-in-process / acp / codex / claude-code / dsh-sdk）；`sdk-minimal` 明确排除 subagents——声明区分 profile（§2.4）。
- 权限模型登记：dsh-base 含 sandbox 与 approval policy；sdk-minimal 自述 danger-full-access；sandbox 后端 bwrap/Landlock/Seatbelt/ACL；官方 SAFETY 自述未经安全审计、不适合生产。
- 成熟度登记：README 自述 developer preview、预期 breaking changes——方言与对照表可能随版本失效，同步责任见 update_policy。
- 许可证登记：工具与文档 MIT（仓库 LICENSE 原文核验）。
- 方言：无 agent Markdown frontmatter；承载形态为 TypeScript `apply(ctx)` 模块 + cordis.yml 注册（§2.5）。
- 工具面：sdk-minimal 双工具栈 `bash`/`pwsh` 与 `str_replace_editor`，逐能力展开见 §2.2；全量 profile roster 未核验（状态 pending）。

## 2. 可执行规则

### 2.1 公共规则唯一权威（指针）

- 公共规则（映射免责/事实源、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）唯一权威＝`capability-contract.md`；本文件只承载宿主差异面，不复述其正文。
- 能力基元与阶段表：`capability-contract.md` §2.1/§2.2（规则块 R-CC-001）。
- 只读约束等级与降级路径：`capability-contract.md` §2.3（规则块 R-CC-002）；扩展登记：§2.5（R-CC-005）。
- Git 写强制等级与 fallback：`capability-contract.md` §2.2（规则块 R-CC-001）。

### 2.2 能力→宿主工具对照

本表登记的 dsh 工具口径为本宿主差异面（sdk-minimal 双工具栈为已核验底线）；能力语义与阶段归属见 §2.1 指针。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | bash | 目录与现状盘点命令；sdk-minimal 口径无专用盘点工具（全量 roster 未核验，pending） |
| search | bash | 检索命令（grep 等）（全量 roster 未核验，pending） |
| read | bash | 文件读取命令（全量 roster 未核验，pending） |
| edit | str_replace_editor | 补丁式修改（sdk-minimal 口径核验） |
| write | str_replace_editor | 补丁式创建（sdk-minimal 口径核验） |
| execute | bash | 持久 shell（Linux/macOS；Windows 为 pwsh），300 秒超时、单 owner 终端；受 approval/policy seam 约束（profile 依赖）；git_write_enforcement: pending（approval/sandbox seam 为 profile 依赖配置面，全量口径未核验，落定前按 policy-only 从紧处理；实现会话交付报告须记该值与降级原因） |
| readonly-execute | bash | 仅只读命令；readonly_enforcement: pending（只读性由调用方约束；approval/sandbox seam 为 profile 依赖配置面，dsh-base 与 sdk-minimal 档位口径未全量核验（pending：全量 roster），核验后落定四级之一，落定前按 policy-only 从紧处理） |
| vcs-read | bash | git status/log/diff 等只读命令 |
| vcs-write | bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色能力映射

角色合同 `required_capabilities` 到本宿主工具口径的对应（行序＝入口生成序）：

| 角色合同 | required_capabilities | 工具口径 |
| --- | --- | --- |
| <role-contract-dir>/implementation.md | inspect, search, read, edit, write, execute | bash + str_replace_editor |
| <role-contract-dir>/review.md | inspect, search, read, readonly-execute | bash（只读命令） |
| <role-contract-dir>/commit.md | inspect, execute | bash（仅 ticket-run.sh <NN> commit 编排入口） |

### 2.4 独立执行体声明与降级路径

声明区分 profile：全量 profile 支持——官方 subagent 文档登记 subagent capability seam（`ctx.subagents`，多 provider：spawn-in-process / fork-in-process / acp / codex / claude-code / dsh-sdk，取阅 2026-09-06）；`sdk-minimal` 不支持——官方 README 明确排除 subagents；独立 Review 默认由独立 subagent 执行（全量 profile 且已注册 provider）。

- 降级：运行形态为 sdk-minimal、provider 未注册或部署裁剪时，走 `capability-contract.md` §2.3 降级路径 (a)/(b)/(c)，并记录 `independent_review: unavailable` 及实际所选路径（公共规则唯一权威，本文件不复述）。
- 记录面：审查记录字段与 run record 指针按 `capability-contract.md` §2.3/R-CC-002 登记（运行 profile 随记录注明；公共规则唯一权威，本文件不复述）。

### 2.5 三角色承载形态

dsh 无 agent Markdown frontmatter 方言（官方文档登记的扩展形态为 TypeScript `apply(ctx)` 模块 + cordis.yml 注册）；角色承载按"角色说明落 skills/插件资源、工具面随 profile"的组合表达，description 承载派发摘要：示例中的 `<role-contract-dir>` 必须按目标项目登记值展开；新项目默认 `rules/implementation/roles/`，旧项目使用登记的兼容目录（通常是 `docs/agent/roles/`）：

```text
# cordis.yml（目标项目宿主部署位）
plugins:
  - path: ./adapters/roles-implementation   # 导出 apply(ctx) 的 TS 模块：
    # name: implementation
    # description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 <role-contract-dir>/implementation.md 为准"
  - path: ./adapters/roles-review           # name: review；只读独立审查描述
  - path: ./adapters/roles-commit           # name: commit；白名单提交描述
```

### 2.6 模型档位可用性

- 分档能力：不可分档（官方文档未登记按角色或按档位选择模型的键，provider seam 未核验；核验前按不可分档从紧）。
- 角色级模型键：待实测（官方文档未见角色级模型键，取阅 2026-09-06；核验前不写键名）。
- 降级记录格式：`model_tier: inherit`（三档一律继承运行 profile 的 provider 选择，记录所继承的 provider 与运行 profile：全量 profile 或 sdk-minimal；本文件不写模型名）。

| 档位 | 取值来源 |
| --- | --- |
| small | `inherit`（继承运行 profile 的 provider 选定模型） |
| standard | `inherit`（继承运行 profile 的 provider 选定模型） |
| strong | `inherit`（继承运行 profile 的 provider 选定模型） |

### 2.7 短上下文别名与到线策略

- 短上下文别名取值：待实测（本机无 dsh 运行环境，未实测别名的上下文窗口上限取值；provider seam 与全量 roster 未核验（状态 pending），核验前不写键名与取值）。
- 到线行为：待实测（`max_input_size` 到线是压缩上下文还是硬拒绝未实测；approval/sandbox seam 不改变到线语义，核验前不据此判定档位为硬封顶或软封顶）。
- Agent 工具显式覆盖：待实测（provider 选择按运行 profile 决定；逐次派发显式指定模型能否覆盖 profile 选择未核验）。
- 降级记录格式：`short_context: none boundary: <压缩|硬拒绝|待实测> evidence: <实测命令、运行 profile 与日期>`（宿主未提供短上下文别名键时固定记 `none`；`evidence` 须写全量 profile 或 `sdk-minimal`；`boundary` 未实测保持待实测；本文件不写模型标识）。

## 3. 解释与例外

- 本文件工具对照以 sdk-minimal 双工具口径为已核验底线：inspect/search/read/vcs 均经 bash 命令承载；全量 profile 工具 roster 未核验（状态 pending），宿主部署可按官方文档补核验后扩表，不虚构工具名。
- 官方架构文档登记 guard 与审批感知的工具执行管线、sandbox 与 approval policy seam：属宿主强制能力登记面，可用于宿主侧护栏，但不取代角色合同与阶段门禁的规则权威。
- 官方 SAFETY 自述未经安全审计、不适合生产；本映射不声明任何隔离或安全能力，隔离责任在宿主环境部署。
- Experimental Agent Teams（opt-in 协调 seam）为官方实验面登记：不作为独立执行体默认形态。
- 宿主本地适配层实例（目标项目内 cordis.yml 与插件目录）由本映射生成；其与 `<role-contract-dir>/` 合同冲突时以合同为准，并报告差异。
- 只读性、档位与扩展规则见 §2.1 指针；本文件不复述公共规则正文。
