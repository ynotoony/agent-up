---
id: adapter-zcode
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同（docs/agent/roles/）与 SPEC-05 为准
lifecycle: Live
read_when: 在宿主生成或维护运行时入口（frontmatter 方言、工具对照）时；评估宿主能力满足度时
trigger: 宿主 frontmatter 方言、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---
<!-- Input: adapter-capability-contract.md 能力契约、原宿主 frontmatter 形态（name/color/description/tools）与目标项目角色合同路径约定（docs/agent/roles/）。 -->
<!-- Output: 宿主运行时映射手册：能力→宿主工具对照、三角色 frontmatter 方言模板与适配层地位边界。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 docs/agent/roles/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md（references/README.md）。 -->

# 宿主适配层映射（运行时入口）

本文件是平台适配层：把 capability-contract 的能力基元映射为宿主运行时形态（frontmatter 方言与工具对照），并承载原宿主绑定 frontmatter 的迁移形态。适配层只是运行时入口，不是事实源；事实源是目标项目 `docs/agent/roles/` 的平台无关角色合同。

## 1. 快速摘要

- 事实源：`docs/agent/roles/implementation.md`、`review.md`、`commit.md`（平台无关角色合同，七节）。
- 本文件承载：能力→宿主工具对照（§2.2）、三角色 frontmatter 方言模板（§2.3）。
- 原宿主 frontmatter（name/color/tools 与描述内工具列举）自角色模板移入本文件（SPEC-06 §3 R-06-002 平台绑定出模板）。
- 适配层与角色合同冲突 → 以合同为准，修正本文件并报告（SPEC-05 R-05-003）。
- `required_capabilities` → 宿主工具清单按 §2.2 对照表逐能力展开；角色合同能力声明变化后须同步对照表与方言模板。
- 运行时入口的 name/description 承载派发摘要；规则权威始终在角色合同与 development-process。
- 九能力对照完整覆盖：inspect/search/read（盘点/检索/读取）、edit/write（修改/创建）、execute 与 readonly-execute（命令执行，只读性由调用方约束）、vcs-read/vcs-write（版本库只读/写命令）。
- 宿主缺少某能力的工具等价物时按 capability-contract R-CC-001 Stop if 处理，不虚报兼容。
- 无独立 subagent 执行体的降级路径见 capability-contract §2.3；本文件不承载流程规则。
- 本文件规则块前缀 `R-ZC-`；能力契约手册前缀 `R-CC-`。

## 2. 可执行规则

### 2.1 适配层地位

#### R-ZC-001 映射不是事实源 `MUST`

- **When**：创建、修改或评估任何平台适配文件时。
- **Action**：适配层只承载运行时映射（入口名、frontmatter 方言、工具调用方式）；事实源是 `docs/agent/roles/` 角色合同与核心协议；本文件按宿主方言变化同步。
- **Forbidden**：把适配层当事实源；在适配层新增流程规则或门禁；核心协议或角色合同反向引用本文件内容作为规则依据。
- **Stop if**：适配器与角色合同冲突 → 以合同为准，修正本文件并报告，不改合同。
- **Evidence**：冲突核查以合同为基准通过；本文件无七节合同、门禁等流程规则内容。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：SPEC-05 §4（R-05-003）。

### 2.2 能力→宿主工具对照

#### R-ZC-002 能力映射与方言同步 `MUST`

- **When**：生成宿主运行时入口，或角色合同 `required_capabilities` 变化时。
- **Action**：按本节对照表把 `required_capabilities` 展开为宿主工具清单；按 §2.3 方言模板生成入口文件；角色合同能力声明变化后同步对照表与模板。
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
| execute | Bash | 可变更工作区状态的命令 |
| readonly-execute | Bash | 仅只读命令 |
| vcs-read | Bash | git status/log/diff 等只读命令 |
| vcs-write | Bash | git add/commit 等写命令 |

### 2.3 三角色 frontmatter 方言模板

入口文件按角色合同生成，frontmatter 形态固定如下（description 承载派发摘要，规则权威在角色合同）：

```text
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 docs/agent/roles/implementation.md 为准"
color: blue
tools: [Read, Grep, Glob, Edit, Write, Bash]
---
```

```text
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 docs/agent/roles/review.md 为准"
color: orange
tools: [Read, Grep, Glob, Bash]
---
```

```text
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 docs/agent/roles/commit.md 为准"
color: green
tools: [Read, Grep, Glob, Bash]
---
```

角色合同 → `required_capabilities` → 宿主工具清单对应：

| 角色合同 | required_capabilities | tools |
| --- | --- | --- |
| docs/agent/roles/implementation.md | inspect, search, read, edit, write, execute | [Read, Grep, Glob, Edit, Write, Bash] |
| docs/agent/roles/review.md | inspect, search, read, readonly-execute | [Read, Grep, Glob, Bash] |
| docs/agent/roles/commit.md | inspect, vcs-read, vcs-write | [Read, Grep, Glob, Bash] |

## 3. 解释与例外

- inspect 映射为 Glob + Read 的组合：目录结构盘点用 Glob，现状内容核对用 Read；单能力对应多工具时按任务需要选用。
- 宿主本地适配层实例（目标项目内 `.zcode/agents/` 等目录）由本映射生成；其与 `docs/agent/roles/` 合同冲突时以合同为准，并报告差异。
- capability profile 档位、无 subagent 降级路径与 platform 枚举扩展规则见 `capability-contract.md`；本文件不复述，避免第二权威。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
