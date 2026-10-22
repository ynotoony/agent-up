---
id: review-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Review 派发模板）；角色权限与行为规则正文不进本模板，唯一权威为角色合同
lifecycle: Live
read_when: 主 agent 派发 Review 阶段任务时
trigger: 派发 Review 阶段任务（Implementation 交付后）
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/review.md（角色合同事实源，MUST 与权限正文唯一承载面）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Review 执行体按角色合同完成独立审查并交付报告。 -->
<!-- Pos: Review 阶段派发 prompt 标准模板；占位符格式 {{KEY}}；本模板只承载派发参数、上下文与输出槽，角色权限与行为规则的唯一权威＝角色合同。 -->

# Review 阶段派发

按 Review 角色合同 `rules/implementation/roles/review.md` 独立审查票 {{TICKET_ID}} 的 Implementation 交付。

**角色合同与权威规则（唯一权威，本模板不复写其正文）**：
- 角色合同（唯一事实源）：`rules/implementation/roles/review.md`——所需能力、可写字段白名单、只读审查与独立性纪律（R-RR 系列规则，含无独立执行体时的降级路径与如实记录）、验收条件、输出格式与阶段出口均以合同为准；本模板与合同不一致时以合同为准。
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、三道门禁）、`rules/project.md`（验证规则）。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**审查合同**：

```text
审查范围：
{{REVIEW_SCOPE}}

Implementation 交付报告摘要：
{{IMPLEMENTATION_SUMMARY}}

规格与验收条件：
{{ACCEPTANCE_CRITERIA}}

实际 diff 位置：
{{DIFF_LOCATION}}

检查维度：
{{REVIEW_DIMENSIONS}}
```

**阶段指派**（派发范围，非新增规则）：只完成 Review 阶段（独立审查 + 结论记录），不做修复或 Commit；完成后写 Independent Review Checkpoint，报告按角色合同 §6 输出格式（唯一权威，本模板不复写）。
