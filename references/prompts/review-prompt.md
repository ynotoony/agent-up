---
id: review-dispatch-prompt-template
kind: template
authority: 权威层级第 4 级（流程规则：Review 派发模板）
lifecycle: Live
read_when: 主 agent 派发 Review 阶段任务时
trigger: 派发 Review 阶段任务（Implementation 交付后）
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/review.md（角色合同事实源）
---
<!-- Input: 主 agent 填充占位符参数后直接派发。 -->
<!-- Output: Review 执行体按角色合同完成独立审查并交付报告。 -->
<!-- Pos: Review 阶段派发 prompt 标准模板；占位符格式 {{KEY}}。 -->

# Review 阶段派发

按 Review 角色合同 `rules/implementation/roles/review.md` 独立审查票 {{TICKET_ID}} 的 Implementation 交付。

**票信息**：
- ID: {{TICKET_ID}}
- 票文件：{{TICKET_PATH}}
- 状态：{{STATUS}}

**角色合同与权威规则**：
- 角色合同（事实源）：`rules/implementation/roles/review.md`（所需能力、Scope 边界、禁止行为、验收条件与输出格式）
- 流程权威：`rules/assessment.md`（需求工作流）、`rules/implementation/discipline.md`（两层协作、三道门禁）、`rules/project.md`（验证规则）

**可写字段白名单**（本角色对票文件写入权限）：
- `checkpoint.review.*`：Review 阶段审查结论记录的所有子字段
  - 包括但不限于：`completed_at` / `reviewer` / `verdict` / `review_scope` / `review_dimensions` / `ac_verification` / `blocking_issues_resolved` / `non_blocking_findings` / `gate_checks` / `independent_verification`

**只读字段（禁止修改）**：
- `checkpoint.implementation.*`：Implementation 阶段字段（由 Implementation 角色写入）
- `checkpoint.commit.*`：Commit 阶段字段（由 Commit 角色写入）
- `status`：任务状态（由 Commit 角色在收尾时翻转）
- 其他顶层字段：`id` / `title` / `scope` / `verification` / `blocked_by` 等（由需求工作流或主 agent 管理）

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

**关键纪律**（R-RR-001 ~ R-RR-003）：
1. **只读审查**：只读审查；可运行不改变仓库文件的检查命令；产出只落盘任务票 Independent Review Checkpoint。**禁止**：修改、修复、格式化、生成或删除任何文件；执行 git add、git commit 或任何提交前代办操作；把修复做掉再宣布通过。
2. **独立性与证据核验**：独立于完成实现的执行体执行审查；对交付报告声称的证据逐项抽查核验，不以口头结论为准；按审查合同声明的级别至少覆盖：
   - 合同 Scope 与实际 diff 的一致性（白名单外改动即 fail）
   - 验收条件逐项核对
   - 验证证据的真实性与覆盖
   - 共享 harness 复用情况（一次性脚本须标注"待沉淀"）
   - 版本库范围检查
   - 文档与登记联动（契约头、目录成员登记）同步
   - 收口打分复核（票含 lesson 三分数键时：对照本执行体视野内客观事实核自评分与事实相符，不符即报差异；只报不改，改分归协调层）
   - 必要性复核（白名单内改动对照验收条件判必要性，命中即记 fail 或要求实现方说明依据）：推测性抽象（YAGNI）、超出验收条件要求的防御性校验与扩展点、提前抽象（违反 R-DP-032 禁止项）、读者难以快速理解的复杂度
   **反向警告**：审查者被要求找缺口，总会报出一些，须只报影响正确性或既定要求的缺口，事实高于个人偏好，其余视为可选。
3. **降级如实记录**：IF 无独立 subagent 执行体 THEN 依序尝试替代路径：(a) 新开独立 session 执行本合同审查；(b) 用不同执行身份或模型执行本合同审查；(c) 由用户本人执行独立审查；并记录 `independent_review: unavailable`（含义：平台无独立 subagent 执行体）与实际所选替代路径 ELSE 使用独立执行体完成审查。**禁止**：把同一执行体的自检标记为 Review pass；静默跳过独立 Review；把降级路径描述为"与独立执行体等价无差"。

**审查检查点**：
- 检查范围对照审查合同逐项完成；每项验收条件有 `文件:行号区间` 证据。
- 交付报告声称的证据已抽查核验；范围检查命令已运行并记录真实结果。
- 结论为明确 `pass` 或 `fail`；fail 附问题定位。

**输出格式**：
报告不超过 60 行，必须以明确结论开头：`pass` 或 `fail`。改进建议（更好写法、可选优化）单列「建议」节，明示不阻塞、不计入 fail；建议级仅限不改变行为与验收结果的写法优化，涉及行为或验收结果的一律按 fail 报。依次包含：结论｜检查范围（对照合同逐项）｜每项验收条件的证据（`文件:行号区间`）｜发现的问题与定位｜后续建议。未运行的检查明确写"未运行"和原因，禁止用"应该可以"代替证据。报告须含一行 token 用量自报（宿主提供执行体用量遥测时如实填报数值与来源，不提供时记 N/A + reason）。

**阶段出口**：
- IF 结论 pass THEN 审查记录落盘任务票 Independent Review Checkpoint（降级时含 `independent_review: unavailable` 与所选路径），移交 Commit。
- ELSE 如实报 fail 并给出问题定位；修复由主 agent 重新派发 Implementation，不由本角色代做。

只完成 Review 阶段（独立审查 + 结论记录），不做修复或 Commit。完成后写 Independent Review Checkpoint 并报告。
