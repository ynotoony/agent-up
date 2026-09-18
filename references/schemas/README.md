<!-- Input: 同级机器格式文件（`run-record.schema.json`、`run-record.example.json`、`issue-index.schema.json`）的定稿事实（票 07、票 34），以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的机器 schema 目录索引：直接成员登记与用途说明。 -->
<!-- Pos: Skill 参考资料机器 schema 目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 机器 schema

本目录承载 `agent-up` 运行时读取与核对用的机器格式 schema。成员清单与本目录实际文件一致，增删 schema 必须在此登记，不静默增删。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明本目录用途并登记直接成员。 |
| `run-record.schema.json` | run record 机器 schema（定稿基线，票 07 / I-03） | run record 十三字段 JSON Schema（draft-07）：字段语义、生成条件（C2/C3、跨会话交接、中断、无 Git 基线、归属不明）、可选 `independent_review` 指针字段与 `fp-v1` 工作区指纹算法定稿说明。 |
| `run-record.example.json` | 标注样例 | `x-sample: true` 的结构样例，不含真实运行数据；用于 schema 结构核对。 |
| `issue-index.schema.json` | 票状态索引机器 schema（定稿基线，票 34；语义权威＝票 33 方案 C 终裁 T1/T2/T5/T6） | `docs/issues/index.json` 票状态索引 JSON Schema（draft-07）：票状态机唯一真相源，单文件 JSON 一条目一行；条目字段 id/status/lane/complexity/blocked_by/checkpoint_ref/last_verified/updated_at（lane 枚举 `full`/`user-review`/`micro`；`status` 取 Task 状态机；frontmatter `status` 退役后 `checkpoint_ref`/`last_verified` 语义不变）。 |

## 契约头例外登记

- JSON 不支持注释：schema JSON 文件以 `$id` / `title` / `description` 承载导航元数据（见 `run-record.schema.json` 与 `issue-index.schema.json` 的 description）；包完整性契约头检查（SPEC-06 §5 第 6 项）对本目录 JSON 文件按 `LICENSE` 同类例外处理。
- run record 的生成条件与字段语义在目标项目 `development-process.md` §12.4（模板：`../templates/development-process.md.tmpl`）；本目录只承载机器格式，不承载流程规则。
- 票状态索引的落点、写入机制与状态冲突裁决语义在 SPEC-02 §8 / R-02-014 与目标项目 `development-process.md` §5.2 触发矩阵、§12.5 道脚本承载注记（票 33 方案 C 终裁 T1/T2/T4/T10，落位票 34）；本目录只承载机器格式，不承载流程规则。
