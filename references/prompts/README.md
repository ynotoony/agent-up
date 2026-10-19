---
id: prompts-directory
kind: registry
authority: 权威层级第 4 级（流程规则：派发模板目录）
lifecycle: Live
read_when: 主 agent 查找标准派发模板或新增模板时
trigger: 派发三阶段任务、维护派发模板
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/（三阶段角色合同事实源）
---
<!-- Input: 主 agent 查找标准派发模板。 -->
<!-- Output: 三阶段派发 prompt 模板文件清单与占位符说明。 -->
<!-- Pos: prompts 目录索引（rules/implementation/prompts/README.md）；一旦成员变化，务必更新本登记。 -->

# 三阶段派发 Prompt 模板目录

本目录承载 Implementation / Review / Commit 三阶段标准派发 prompt 模板，保证主 agent 派发时 prompt 格式严格一致，避免遗漏关键信息（角色合同路径、可写字段白名单、权威规则引用）。

## 目录成员

| 文件 | 描述 | 角色合同事实源 | 关键占位符 |
| --- | --- | --- | --- |
| `implementation-prompt.md` | Implementation 阶段派发模板 | `rules/implementation/roles/implementation.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REPOSITORY_PATH}}`, `{{SCOPE_TREE}}`, `{{ACCEPTANCE_CRITERIA}}`, `{{VERIFICATION_COMMANDS}}` |
| `review-prompt.md` | Review 阶段派发模板 | `rules/implementation/roles/review.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REVIEW_SCOPE}}`, `{{IMPLEMENTATION_SUMMARY}}`, `{{ACCEPTANCE_CRITERIA}}`, `{{DIFF_LOCATION}}` |
| `commit-prompt.md` | Commit 阶段派发模板 | `rules/implementation/roles/commit.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REVIEW_PASS_CHECKPOINT}}`, `{{FILE_WHITELIST}}`, `{{COMMIT_MESSAGE}}`, `{{RECORD_FLIP_AUTHORIZATION}}` |

## 使用方式

1. **主 agent 派发时**：读取对应阶段的模板文件，填充占位符参数后直接派发给执行体。
2. **占位符格式**：`{{KEY}}`，主 agent 按票信息、委派合同或审查合同填充。
3. **模板完整性**：每个模板包含：
   - 角色合同路径与权威规则引用
   - 可写字段白名单与只读字段清单
   - 关键纪律（R-RI-*, R-RR-*, R-RC-*）
   - 验收条件与输出格式
   - 阶段出口条件

## 模板权威性

- 模板内容以角色合同事实源为准（`rules/implementation/roles/*.md`）；模板与合同冲突时以合同为准。
- 占位符字段以委派合同固定模板（`rules/implementation/discipline.md` §6）为准。
- 模板更新须同步角色合同语义变化；角色合同变化必须同步模板。

## 关键占位符说明

### Implementation 模板占位符
- `{{TICKET_ID}}`：任务票 ID（如 `172-three-stage-dispatch-prompts`）
- `{{TICKET_PATH}}`：任务票文件绝对路径（如 `facts/requirements/tickets/172-three-stage-dispatch-prompts.json`）
- `{{STATUS}}`：任务票当前状态（如 `ready`, `in_progress`）
- `{{REPOSITORY_PATH}}`：仓库绝对根路径
- `{{SCOPE_TREE}}`：允许修改的文件/目录树结构（树形格式，`├──`/`└──`）
- `{{ACCEPTANCE_CRITERIA}}`：验收条件逐项清单
- `{{VERIFICATION_COMMANDS}}`：验证命令与期望结果

### Review 模板占位符
- `{{REVIEW_SCOPE}}`：审查范围（对照合同逐项）
- `{{IMPLEMENTATION_SUMMARY}}`：Implementation 交付报告摘要
- `{{DIFF_LOCATION}}`：实际 diff 位置（工作区或分支）
- `{{REVIEW_DIMENSIONS}}`：检查维度（合同一致性、验收条件、验证证据、必要性等）

### Commit 模板占位符
- `{{REVIEW_PASS_CHECKPOINT}}`：Review pass 结论位置（票文件 checkpoint.review 或独立记录）
- `{{FILE_WHITELIST}}`：白名单文件清单（逐项绝对路径）
- `{{COMMIT_MESSAGE}}`：提交信息（按仓库规定的 `<type>(<scope>): <结果>` 格式）
- `{{RECORD_FLIP_AUTHORIZATION}}`：记录翻转授权声明（是否授权翻转状态、索引、进度）
- `{{SCOPE_CHECK_COMMAND}}`：范围检查命令（如 `git diff --name-only`）

## 维护纪律

- 新增模板必须登记本 README 成员表。
- 删除模板必须从成员表移除并说明原因。
- 模板语义变化（占位符、可写字段、验收条件）需同步角色合同。
- 三阶段模板为固定不裁剪规则（`rules/implementation/discipline.md` §6），不随项目规模变化。
