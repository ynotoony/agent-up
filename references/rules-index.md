<!-- Input: 包内全部 *.md 与 *.tmpl 的规则块标题行与块体（本文件由 generate-docs-index.sh 独占写） -->
<!-- Output: 规则索引投影：每块一行（ID｜标题｜所属文件｜Level｜机制），按 ID 升序 -->
<!-- Pos: 包内规则块导航投影（Derived）；规则块格式权威＝references/protocol/governance-format.md -->
<!-- generated_from: 包内规则块扫描 ＋ dev/tools/generate-docs-index.sh -->
<!-- generated_at: 2026-11-11T09:27:04Z -->
<!-- coverage: 包内 36 个规则块（36 节登记机制值），每块一行 -->
<!-- invalidation: Derived 投影，可由生成器整文件重建；与规则块正文不一致时以正文为准 -->

# 规则索引（Derived）

| ID | 标题 | 所属文件 | Level | 机制 |
| --- | --- | --- | --- | --- |
| R-AT-001 | 宿主差异面齐备 | references/adapters/adapter-template.md | MUST | 机械（检查 27） |
| R-CC-001 | 能力声明 | references/adapters/capability-contract.md | MUST | 门禁 |
| R-CC-002 | 只读约束等级与降级如实记录 | references/adapters/capability-contract.md | MUST | 门禁 |
| R-CC-003 | 档位语义 | references/adapters/capability-contract.md | MUST | 约定 |
| R-CC-004 | 未测量不声明 | references/adapters/capability-contract.md | MUST NOT | 约定 |
| R-CC-005 | 新宿主扩展登记 | references/adapters/capability-contract.md | MUST | 机械（检查 26） |
| R-CO-001 | 授权先于写入（G1） | references/templates/core.md.tmpl | MUST | 门禁 |
| R-CO-002 | 无验证证据不算完成（G2） | references/templates/core.md.tmpl | MUST | 门禁 |
| R-CO-003 | 审查证据才可提交（G3） | references/templates/core.md.tmpl | MUST | 门禁 |
| R-CO-004 | 只提交白名单（G3） | references/templates/core.md.tmpl | MUST | 机械（check-gates.sh、lane-commit.sh） |
| R-CO-005 | 冲突即停、单一权威（G5） | references/templates/core.md.tmpl | MUST | 约定 |
| R-CO-006 | 不删不盖不重置（G4、G5） | references/templates/core.md.tmpl | MUST | 约定 |
| R-CO-007 | 状态落盘、可接续（G4） | references/templates/core.md.tmpl | MUST | 机械（generate-progress.sh、checkpoint-write.sh） |
| R-CO-008 | 单一写者（G5） | references/templates/core.md.tmpl | MUST | 门禁 |
| R-CO-009 | 记录只追加（G5） | references/templates/core.md.tmpl | MUST | 机械（check-append-only.sh） |
| R-CO-010 | 角色不越界（G1、G3） | references/templates/core.md.tmpl | MUST | 约定 |
| R-CP-001 | 复杂度定级与记录 | references/protocol/complexity-profile.md | MUST | 门禁 |
| R-CP-002 | C3 拆票门禁 | references/protocol/complexity-profile.md | MUST | 门禁 |
| R-CP-003 | 七维独立评估 | references/protocol/complexity-profile.md | MUST | 约定 |
| R-CP-004 | 复杂度与 Profile 正交 | references/protocol/complexity-profile.md | MUST | 约定 |
| R-CP-005 | 目标项目等价权威优先 | references/protocol/complexity-profile.md | MUST | 约定 |
| R-CP-006 | 快道准入与声明 | references/protocol/complexity-profile.md | MUST | 机械（check-gates.sh、lane-commit.sh） |
| R-GF-001 | 规则块字段齐备 | references/protocol/governance-format.md | MUST | 机械（检查 22） |
| R-GF-002 | Level 取值与适用性评估 | references/protocol/governance-format.md | MUST | 机械（检查 22） |
| R-GF-003 | 条件表达 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-004 | 硬规则与状态结构化 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-005 | 清单索引关系机器格式 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-006 | 语义与背景保留自然语言 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-007 | 三层组织 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-008 | 元数据九字段与承载形态 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-009 | 分工绑定 | references/protocol/governance-format.md | MUST | 约定 |
| R-GF-010 | 关键规则禁用模糊措辞 | references/protocol/governance-format.md | MUST NOT | 机械（检查 12） |
| R-GF-011 | 索引投影纪律 | references/protocol/governance-format.md | MUST | 约定 |
| R-RP-001 | 按阶梯读取 | references/protocol/read-policy.md | MUST | 约定 |
| R-RP-002 | 冲突即停 | references/protocol/read-policy.md | MUST | 约定 |
| R-RP-003 | 档位加载范围 | references/protocol/read-policy.md | MUST | 约定 |
