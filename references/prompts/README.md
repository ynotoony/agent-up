---
id: prompts-directory
kind: registry
authority: 权威层级第 4 级（流程规则：派发模板目录）
lifecycle: Live
read_when: 主 agent 查找标准派发模板或新增模板时
trigger: 派发三阶段任务、维护派发模板
owner: 主 agent（路由层）
depends_on: rules/implementation/roles/（角色合同事实源，MUST 与权限正文唯一承载面）
---
<!-- Input: 主 agent 查找标准派发模板。 -->
<!-- Output: 三阶段派发 prompt 模板文件清单与占位符说明。 -->
<!-- Pos: prompts 目录索引（rules/implementation/prompts/README.md）；一旦成员变化，务必更新本登记。 -->

# 三阶段派发 Prompt 模板目录

本目录承载 Implementation / Review / Commit 三阶段标准派发 prompt 模板，保证主 agent 派发时 prompt 格式严格一致，避免遗漏关键信息（角色合同路径、权威规则引用、票信息与合同占位符）。

## 权威分工（单一合同权威）

- **角色合同**（`rules/implementation/roles/*.md`，模板见 `../templates/agents-*.md.tmpl`）是 MUST 行为规则与写入权限正文的**唯一承载面**：所需能力、可写字段白名单、Scope 边界、禁止行为、验收条件、输出格式与阶段出口只在合同展开。
- **派发 Prompt**（本目录）只承载三类内容：**派发参数**（票信息与委派/审查/提交合同占位符）、**上下文**（角色合同与权威规则指针）、**输出槽**（输出格式指向合同对应节，不复写正文）。
- Prompt 与合同不一致时以合同为准；Prompt 不得回填合同正文（白名单清单、规则块、阶段出口等），机械边界由记录层 harness 的 role-prompt 套件常驻断言（`sh scripts/test-record-layer.sh --suite role-prompt`）。

## 目录成员

| 文件 | 描述 | 角色合同事实源 | 关键占位符 |
| --- | --- | --- | --- |
| `implementation-prompt.md` | Implementation 阶段派发模板 | `rules/implementation/roles/implementation.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REPOSITORY_PATH}}`, `{{SCOPE_TREE}}`, `{{ACCEPTANCE_CRITERIA}}`, `{{VERIFICATION_COMMANDS}}` |
| `review-prompt.md` | Review 阶段派发模板 | `rules/implementation/roles/review.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REVIEW_SCOPE}}`, `{{IMPLEMENTATION_SUMMARY}}`, `{{ACCEPTANCE_CRITERIA}}`, `{{DIFF_LOCATION}}` |
| `commit-prompt.md` | Commit 阶段派发模板 | `rules/implementation/roles/commit.md` | `{{TICKET_ID}}`, `{{TICKET_PATH}}`, `{{REVIEW_PASS_CHECKPOINT}}`, `{{FILE_WHITELIST}}`, `{{COMMIT_MESSAGE}}`, `{{RECORD_FLIP_AUTHORIZATION}}` |

## 使用方式

1. **主 agent 派发时**：读取对应阶段的模板文件，填充占位符参数后直接派发给执行体；执行体的行为约束与权限由其首步读取的角色合同承载，不在派发消息里复述。
2. **占位符格式**：`{{KEY}}`，主 agent 按票信息、委派合同或审查合同填充。
3. **模板完整性**（去重定稿）：每个模板包含：
   - 角色合同路径与权威规则引用（唯一权威指针）
   - 票信息与派发参数占位符（合同字段块）
   - 阶段指派与输出槽（输出格式指向合同，不复写正文）

## 模板权威性

- 模板内容以角色合同事实源为准（`rules/implementation/roles/*.md`）；模板与合同冲突时以合同为准。
- 占位符字段以委派合同固定模板（`rules/implementation/discipline.md` §6）为准；占位符全集由 `scripts/check-dispatch-contract.sh --check-template` 机械核对（schema 双向零差集）。
- 角色合同语义变化不需要同步 Prompt 正文（Prompt 零合同正文）；占位符面或权威指针变化才同步本目录模板。

## 关键占位符说明

### Implementation 模板占位符
- `{{TICKET_ID}}`：任务票 ID
- `{{TICKET_PATH}}`：任务票文件绝对路径
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
- 模板更新只增删派发参数、上下文指针与输出槽；不得回填角色合同的 MUST 正文、白名单清单或阶段出口（单一合同权威，role-prompt 套件机械断言）。
- 三阶段模板为固定不裁剪规则（`rules/implementation/discipline.md` §6），不随项目规模变化。
