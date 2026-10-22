---
id: implementation-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Implementation 派发模板）；角色权限与行为规则正文不进本模板，唯一权威为角色合同
lifecycle: Live
read_when: 主 agent 派发 Implementation 阶段任务时
trigger: 派发 Implementation 阶段任务
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/implementation.md（角色合同事实源，MUST 与权限正文唯一承载面）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Implementation 执行体按角色合同完成实现并交付报告。 -->
<!-- Pos: Implementation 阶段派发 prompt 标准模板；占位符格式 {{KEY}}；本模板只承载派发参数、上下文与输出槽，角色权限与行为规则的唯一权威＝角色合同。 -->

# Implementation 阶段派发

按 Implementation 角色合同 `rules/implementation/roles/implementation.md` 实施票 {{TICKET_ID}}。

**角色合同与权威规则（唯一权威，本模板不复写其正文）**：
- 角色合同（唯一事实源）：`rules/implementation/roles/implementation.md`——所需能力、可写字段白名单、Scope 边界、禁止行为（R-RI 系列规则）、验收条件、输出格式与阶段出口均以合同为准；本模板与合同不一致时以合同为准。
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、委派合同固定模板、检查点纪律）、`rules/project.md`（读取阶梯、产物生命周期、验证规则）。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**委派合同**（16 个固定字段；字段语义见 `rules/implementation/discipline.md` §6，Output Contract 以角色合同 §6 输出格式为唯一权威）：

```text
Repository / Absolute Path:
{{REPOSITORY_PATH}}

Task:
{{TASK_DESCRIPTION}}

Goal:
{{GOAL}}

Scope:
{{SCOPE_TREE}}

Out of Scope:
{{OUT_OF_SCOPE}}

Context / Evidence:
{{CONTEXT_EVIDENCE}}

Constraints:
{{CONSTRAINTS}}

Forbidden Changes:
{{FORBIDDEN_CHANGES}}

Acceptance Criteria / Definition of Done:
{{ACCEPTANCE_CRITERIA}}

Verification:
{{VERIFICATION_COMMANDS}}

Output Contract:
按角色合同 §6 输出格式执行（唯一权威，本模板不复写）。

Dependencies / Blockers:
{{DEPENDENCIES_BLOCKERS}}

Risks:
{{RISKS}}

Budget / Checkpoints:
{{BUDGET_CHECKPOINTS}}

Estimated Time:
{{ESTIMATED_TIME}}

Actual Time:
{{ACTUAL_TIME}}
```

**阶段指派**（派发范围，非新增规则）：只完成 Implementation 阶段（实现 + 实现相关验证），不做 Review 或 Commit；完成后写 Implementation Checkpoint 并按角色合同 §6 报告。
