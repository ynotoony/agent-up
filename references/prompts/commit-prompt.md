---
id: commit-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Commit 派发模板）
lifecycle: Live
read_when: 主 agent 派发 Commit 阶段任务时
trigger: 派发 Commit 阶段任务（Review pass 后）
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/commit.md（角色合同事实源）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Commit 执行体按角色合同完成提交并交付报告。 -->
<!-- Pos: Commit 阶段派发 prompt 标准模板；占位符格式 {{KEY}}。 -->

# Commit 阶段派发

按 Commit 角色合同 `rules/implementation/roles/commit.md` 提交票 {{TICKET_ID}} 的审查通过交付。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**角色合同与权威规则**：
- 角色合同（事实源）：`rules/implementation/roles/commit.md`（所需能力、Scope 边界、禁止行为、验收条件与输出格式）
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、三道门禁）、`rules/project.md`（提交规则）

**可写字段白名单**（本角色对票文件写入权限）：
- `checkpoint.commit.*`：Commit 阶段提交结果记录的所有子字段
  - 包括但不限于：`completed_at` / `commit_id` / `commit_message` / `committed_files` / `whitelist_check` / `scope_check_command`

**收尾记录翻转权限（提交合同明确授权时）**：
- `status`：任务状态（如 `in_progress` → `done`，通过 `ticket-ops.sh flip` 执行）
- `facts/requirements/tickets/index.json`：索引表状态行
- `facts/requirements/tickets/progress-current.md`：进度投影条目

**只读字段（禁止修改）**：
- `checkpoint.implementation.*`：Implementation 阶段字段（由 Implementation 角色写入）
- `checkpoint.review.*`：Review 阶段字段（由 Review 角色写入）
- 其他顶层字段：`id` / `title` / `scope` / `verification` / `blocked_by` 等（由需求工作流或主 agent 管理）

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

**关键纪律**（R-RC-001 ~ R-RC-003）：
1. **白名单提交**：核对 Review pass 结论在位后，只暂存白名单文件，按合同提交信息创建提交，并回报提交 ID 与实际提交文件清单。**禁止**：暂存或提交白名单外文件；在 Review 结论缺失或非 pass 时创建提交；把多个不可解释的改动混入同一提交。
2. **停止条件与禁令**：发现停止条件即停止并按输出格式报告，不自行解决。停止条件：白名单外存在改动｜Review 结论缺失或非 pass｜工作区状态与提交合同不符｜白名单文件不存在或为空。**禁止**：git push、git reset --hard、强制操作或回滚他人改动；未经用户明确要求推送远端；扩大暂存范围代做修复。
3. **记录翻转例外**：IF 白名单明列记录翻转（索引表状态行、任务票状态行、progress 条目）THEN 先创建产品提交，再对明列记录执行翻转并追加一条纯记录提交 ELSE 只创建产品提交。**禁止**：两类提交之外修改任何文件；把记录翻转与产品改动混入同一提交；翻转白名单未明列的记录。

**验收条件**：
- 白名单逐项核对完成（在/不在 diff 中）；范围检查命令已运行并记录真实结果。
- 创建的提交 ID 与信息已回报；实际提交文件清单与白名单一致。
- 无停止条件触发；触发时已按输出格式报告。

**输出格式**：
报告不超过 30 行：白名单逐项核对结果（在/不在 diff 中）｜范围检查命令与结果｜创建的提交 ID 与信息｜实际提交的文件清单。异常停止时报告触发了哪条停止条件。

**阶段出口**：
- IF 白名单核对与范围检查通过且提交创建 THEN 回报提交 ID 与清单，任务收尾。
- ELSE 按停止条件报告，不创建提交；由主 agent 裁决后续。

只完成 Commit 阶段（白名单提交 + 记录翻转），不做修复或重新审查。完成后写 Commit Checkpoint 并报告。
