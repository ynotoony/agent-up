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

<!-- Input: adapter-capability-contract.md 能力契约、adapter-template.md 结构基线、Claude Code 官方文档（code.claude.com/docs/en/{hooks,sub-agents,settings}，取阅 2026-09-06）与 docs/research/2026-09-agent-host-adapters.md §3.1（historical 调研存档，non-normative，非运行时必读）。 -->
<!-- Output: Claude Code 宿主差异面：能力→宿主工具对照、三角色 frontmatter 方言模板、独立执行体声明；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 <role-contract-dir>/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Claude Code 宿主适配层映射（运行时入口）

本文件承载 Claude Code 宿主的运行时形态：subagent 定义、hooks 与权限配置形态、工具对照；官方事实依据与取阅日期以各条目内官方文档取阅注记为准；`docs/research/2026-09-agent-host-adapters.md` §3.1 为 historical 调研存档（non-normative，非运行时必读，不作规范依据）。

## 1. 快速摘要

- platform 枚举值：`claude-code`；三类接入面归属：shell hooks 代表（官方 hooks 文档登记 `PreToolUse` 可阻断工具调用）；plugins/subagents 为辅。
- 独立执行体：官方 sub-agents 文档登记 `.claude/agents/<name>.md` 子代理定义（frontmatter `name`/`description`/`tools`/`model`）——支持。
- 权限模型登记：settings 分层文件 + `permissions.allow`/`ask`/`deny` 与 `permissions.defaultMode`；deny/ask 立即生效，allow 在目录受信后生效（官方 settings 文档）。
- 许可证登记：工具为专有（已核验 2026-09-06）——仓库无开源 LICENSE 文件（`LICENSE` raw 路径 404），存在 `LICENSE.md` 专有声明（© Anthropic PBC，Use is subject to Anthropic's Commercial Terms of Service，raw 原文核验），非开源；官方文档未标注独立文档许可证（historical 调研存档注记，non-normative，非运行时必读）。
- 方言：subagent frontmatter 对齐官方 `name`/`description`/`tools`/`model` 四字段，`model: inherit` 为占位。
- hooks（`PreToolUse` 可 deny 等）是宿主强制能力登记：可用于宿主侧护栏配置，不取代角色合同与阶段门禁的规则权威。
- 工具面：`Read`/`Grep`/`Glob`/`Edit`/`Write`/`Bash`，逐能力展开见 §2.2。

## 2. 可执行规则

### 2.1 公共规则唯一权威（指针）

- 公共规则（映射免责/事实源、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）唯一权威＝`capability-contract.md`；本文件只承载宿主差异面，不复述其正文。
- 能力基元与阶段表：`capability-contract.md` §2.1/§2.2（规则块 R-CC-001）。
- 只读约束等级与降级路径：`capability-contract.md` §2.3（规则块 R-CC-002）；扩展登记：§2.5（R-CC-005）。
- Git 写强制等级与 fallback：`capability-contract.md` §2.2（规则块 R-CC-001）。

### 2.2 能力→宿主工具对照

本表登记的 Claude Code 工具口径为本宿主差异面；能力语义与阶段归属见 §2.1 指针。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | Glob + Read | 目录与现状盘点 |
| search | Grep、Glob | 文件名与内容检索 |
| read | Read | 读取文件内容 |
| edit | Edit | 修改既有文件 |
| write | Write | 创建新文件 |
| execute | Bash | 可变更工作区状态的命令；受 `permissions` 规则约束；git_write_enforcement: policy-only（`permissions` 与 hooks 为配置面闸门，登记面无默认 git 写 deny；实现会话交付报告须记该值与降级原因） |
| readonly-execute | Bash | 仅只读命令；readonly_enforcement: policy-only（permissions.allow/ask/deny 与 hooks 为调用面闸门与配置面护栏，官方 settings/hooks 文档取阅 2026-09-06；登记面无默认只读隔离，sandbox 类隔离能力未核验（状态 pending，不据此声明宿主强制隔离）；只读性由调用方约束） |
| vcs-read | Bash | git status/log/diff 等只读命令 |
| vcs-write | Bash | git add/commit 等写命令；未经用户明确要求不执行（角色合同禁令优先于宿主能力） |

### 2.3 三角色能力映射

角色合同 `required_capabilities` 到本宿主工具清单的对应（行序＝入口生成序）：

| 角色合同 | required_capabilities | tools |
| --- | --- | --- |
| <role-contract-dir>/implementation.md | inspect, search, read, edit, write, execute | [Read, Grep, Glob, Edit, Write, Bash] |
| <role-contract-dir>/review.md | inspect, search, read, readonly-execute | [Read, Grep, Glob, Bash] |
| <role-contract-dir>/commit.md | inspect, execute | [Read, Grep, Glob, Bash（仅 ticket-run.sh <NN> commit 编排入口）] |

### 2.4 独立执行体声明与降级路径

声明：本宿主支持独立 subagent 执行体（官方 sub-agents 文档，`.claude/agents/<name>.md` 定义，取阅 2026-09-06）；独立 Review 默认由独立 subagent 执行。

- 降级：部署裁剪或权限配置导致 subagent 不可用时，走 `capability-contract.md` §2.3 降级路径 (a)/(b)/(c)，并记录 `independent_review: unavailable` 及实际所选路径（公共规则唯一权威，本文件不复述）。
- 记录面：审查记录字段与 run record 指针按 `capability-contract.md` §2.3/R-CC-002 登记（公共规则唯一权威，本文件不复述）。

### 2.5 三角色 frontmatter 方言模板

入口文件按角色合同生成，frontmatter 形态对齐官方 sub-agents 文档方言（`name`/`description`/`tools`/`model`；description 承载派发摘要）：示例中的 `<role-contract-dir>` 必须按目标项目登记值展开；新项目默认 `rules/implementation/roles/`，旧项目使用登记的兼容目录（通常是 `docs/agent/roles/`）：

```text
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 <role-contract-dir>/implementation.md 为准"
tools: [Read, Grep, Glob, Edit, Write, Bash]
model: inherit
---
```

```text
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 <role-contract-dir>/review.md 为准"
tools: [Read, Grep, Glob, Bash]
model: inherit
---
```

```text
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 <role-contract-dir>/commit.md 为准"
tools: [Read, Grep, Glob, Bash]
model: inherit
---
```

## 3. 解释与例外

- inspect 映射为 Glob + Read 的组合：目录结构盘点用 Glob，现状内容核对用 Read；单能力对应多工具时按任务需要选用。
- hooks（`PreToolUse` 可 deny 等）是宿主强制能力登记：可用于宿主侧护栏配置，但不取代角色合同与阶段门禁的规则权威；本文件不定义任何 hooks 配置内容。
- `model: inherit` 为方言占位：实际取值按目标项目部署决定；本文件不承诺模型行为。
- 宿主本地适配层实例（目标项目内 `.claude/agents/` 目录）由本映射生成；其与 `<role-contract-dir>/` 合同冲突时以合同为准，并报告差异。
- 只读性、档位与扩展规则见 §2.1 指针；本文件不复述公共规则正文。
