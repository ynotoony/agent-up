---
id: implementation-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Implementation 派发模板）
lifecycle: Live
read_when: 主 agent 派发 Implementation 阶段任务时
trigger: 派发 Implementation 阶段任务
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/implementation.md（角色合同事实源）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Implementation 执行体按角色合同完成实现并交付报告。 -->
<!-- Pos: Implementation 阶段派发 prompt 标准模板；占位符格式 {{KEY}}。 -->

# Implementation 阶段派发

按 Implementation 角色合同 `rules/implementation/roles/implementation.md` 实施票 {{TICKET_ID}}。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**角色合同与权威规则**：
- 角色合同（事实源）：`rules/implementation/roles/implementation.md`（所需能力、Scope 边界、禁止行为、验收条件与输出格式）
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、委派合同、检查点纪律）、`rules/project.md`（读取阶梯、产物生命周期、验证规则）

**可写字段白名单**（本角色对票文件写入权限）：
- `checkpoint.implementation.*`：Implementation 阶段执行结果记录的所有子字段
  - 包括但不限于：`completed_at` / `changed_files` / `acceptance_status` / `verification_evidence` / `implementation_notes` / 步骤级 checkpoint

**只读字段（禁止修改）**：
- `checkpoint.review.*`：Review 阶段字段（由 Review 角色写入）
- `checkpoint.commit.*`：Commit 阶段字段（由 Commit 角色写入）
- `status`：任务状态（由 Commit 角色在收尾时翻转）
- 其他顶层字段：`id` / `title` / `scope` / `verification` / `blocked_by` 等（由需求工作流或主 agent 管理）

**委派合同**（16 个固定字段）：

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
报告不超过 60 行，依次包含：修改文件清单（绝对路径）｜验证命令与真实结果｜已落盘的 Checkpoint 位置｜未解决问题与交给 Review 的上下文｜风险。不接受只有"完成"的摘要。代码证据只给 `文件:行号区间`。报告须含一行 token 用量自报（宿主提供执行体用量遥测时如实填报数值与来源，不提供时记 N/A + reason）。

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

**关键纪律**（R-RI-001 ~ R-RI-003）：
1. **Scope 边界**：只修改委派合同 Scope 白名单内的文件；发现他人未提交改动只记录归属，不清理、不覆盖。
2. **只实现不自审**：实现与实现相关验证一体完成；运行与本次改动直接相关的测试/构建/类型检查并报告真实命令与结果；自检结果只作实现内验证记录，不替代独立 Review 结论。**禁止**：宣布审查通过或以自检替代 Review 结论；虚构、省略或美化验证结果；执行 git add、git commit 或任何版本库写操作（本合同未声明 vcs-write）。
3. **阻塞即停**：发现事实冲突、前置依赖未满足或委派合同含糊时，停止实现，按输出格式返回阻塞报告，等待派发方裁决后继续。

**验证要求**：
- 验证优先复用仓库既有共享验证（本仓库现役：`sh agent-up/scripts/check-package.sh` 与 Git 只读命令）；没有适用的才新增脚本并当场登记；一次性脚本在 Checkpoint 标注"待沉淀"。
- 验证必须记录命令、环境、结果和日期；未运行的验证明确写 `N/A + reason`，禁止用"应该可以"代替证据。

**接通条件**：
合同声称交付的新能力须在交付面可达路径上被行使或核对通过；仅孤立单元验证或文件存在不算接通；确属仅交付内部件的，须在 Checkpoint 登记 residual 及归属。

**阶段出口**：
- IF 全部验收条件满足且无阻塞 THEN 交付报告并移交 Review，不自行宣布通过。
- ELSE 按输出格式返回阻塞报告；任务保持 in_progress 或按状态机记 blocked，不进入 Review。

只完成 Implementation 阶段（实现 + 验证），不做 Review 或 Commit。完成后写 Implementation Checkpoint 并报告。
