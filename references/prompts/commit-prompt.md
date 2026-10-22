---
id: commit-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Commit 派发模板）；角色权限与行为规则正文不进本模板，唯一权威为角色合同
lifecycle: Live
read_when: 主 agent 派发 Commit 阶段任务时
trigger: 派发 Commit 阶段任务（Review pass 后）
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/commit.md（角色合同事实源，MUST 与权限正文唯一承载面）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Commit 执行体按角色合同完成提交并交付报告。 -->
<!-- Pos: Commit 阶段派发 prompt 标准模板；占位符格式 {{KEY}}；本模板只承载派发参数、上下文与输出槽，角色权限与行为规则的唯一权威＝角色合同。 -->

# Commit 阶段派发

按 Commit 角色合同 `rules/implementation/roles/commit.md` 提交票 {{TICKET_ID}} 的审查通过交付。

**角色合同与权威规则（唯一权威，本模板不复写其正文）**：
- 角色合同（唯一事实源）：`rules/implementation/roles/commit.md`——所需能力、可写字段白名单与收尾记录翻转权限、停止条件与禁令（R-RC 系列规则）、验收条件、输出格式与阶段出口均以合同为准；本模板与合同不一致时以合同为准。
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、三道门禁）、`rules/project.md`（提交规则）。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**提交合同**：

```text
Review pass 结论位置：
{{REVIEW_PASS_CHECKPOINT}}

文件白名单（只暂存这些文件）：
{{FILE_WHITELIST}}

提交信息：
{{COMMIT_MESSAGE}}

记录翻转授权：
{{RECORD_FLIP_AUTHORIZATION}}

范围检查命令：
{{SCOPE_CHECK_COMMAND}}
```

**阶段指派**（派发范围，非新增规则）：只完成 Commit 阶段（白名单提交 + 授权范围内的记录翻转），不做修复或重新审查；完成后写 Commit Checkpoint，报告按角色合同 §6 输出格式（唯一权威，本模板不复写）。
