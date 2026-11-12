<!-- Input: 同级机器格式文件（`run-record.schema.json`、`run-record.example.json`、`issue-index.schema.json`、`ticket-record.schema.json`、`ticket-record.example.json`、`dispatch-contract.schema.json`、`ledger-row.schema.json`、`receipt.schema.json`）的定稿事实、，以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的机器 schema 目录索引：直接成员登记、用途说明。 -->
<!-- Pos: Skill 参考资料机器 schema 目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 机器 schema

本目录承载 `agent-up` 运行时读取与核对用的机器格式 schema。成员清单与本目录实际文件一致，增删 schema 必须在此登记，不静默增删。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明本目录用途并登记直接成员。 |
| `run-record.schema.json` | run record 机器 schema（定稿基线，I-03） | run record 十三字段 JSON Schema（draft-07）：字段语义、生成条件（C2/C3、跨会话交接、中断、无 Git 基线、归属不明）、可选 `independent_review` 指针字段与 `fp-v1` 工作区指纹算法定稿说明。 |
| `run-record.example.json` | 标注样例 | `x-sample: true` 的结构样例，不含真实运行数据；用于 schema 结构核对。 |
| `issue-index.schema.json` | 票状态索引机器 schema（定稿基线；语义权威＝方案 C 终裁 T1/T2/T5/T6） | `facts/requirements/tickets/index.json` 票状态索引 JSON Schema（draft-07）：票状态机唯一真相源，单文件 JSON 一条目一行；条目字段 id/status/lane/complexity/blocked_by/checkpoint_ref/last_verified/updated_at＋可选 superseded_by（R-DP-039 替代标记：被推翻票的回链，指向票存在性由 check-stale-claims.sh S7 硬断言；lane 枚举 `full`/`user-review`/`micro`；`status` 取 Task 状态机；frontmatter `status` 退役后 `checkpoint_ref`/`last_verified` 语义不变）。 |
| `ticket-record.schema.json` | 票本体机器 schema（定稿基线；语义权威＝终裁 T9 改判与 SPEC-02 §5.1） | 新开任务票 JSON 本体 JSON Schema（draft-07）：文件命名 task `<NN>-<slug>.json`；历史 request（REQ，kind=request）自 2026-10-23 退役——新需求一律走任务票（卡片），kind 枚举只留 task，开票脚本（ticket-ops open）拒绝 kind=request 与 REQ-* 格式 id 且零写入；存量 REQ 冻结只读，读取校验（json-validator --ticket 不传 --new-ticket）仍接受 kind=request 与 REQ-* id 模式以兼容存量数据。required id/kind/title/created_at，task 另必备 complexity/profile/blocked_by（allOf if/then），可选 category（R-DP-039 类别保留：四值性质轴 bug/enhancement/debt/chore，bug 类 verification 必带回归验证句，缺省视同 chore；旧三值 decision/procedural/temporal 退役，存量零回扫）；`profile_reason` 属性＝七维 Requirement Profile 逐维 reason 存储合同（对象恰七键 D/B/I/U/S/M/O、值非空字符串；语义权威＝`../protocol/complexity-profile.md` §2.2，与 verification 的 `record_only.reason` 语义分立互不混用；新 task 开票时点经 ticket-ops open 强制必备，存量票读取面不要求——开票校验与读取校验分层）；`dispatch` 属性＝三阶段派发合同数据节存储合同（对象必备 implementation/review/commit 三阶段子对象，各阶段键集镜像自 `dispatch-contract.schema.json` `contract_fields` 该阶段必备字段清单——implementation 16 键／review 6 键／commit 6 键，键集权威在该字典、两处漂移由 `../../../dev/tests/suite-dispatch-contract.sh` 套件守卫核对；每键值为非空白字符串＝渲染派发合同时对应 `{{KEY}}` 占位符的实值；自 2026-10-26 起新开票经 ticket-ops open 强制必备且逐键非空白，存量票零回扫——读取校验与 take/flip 不要求本节，开票校验与读取校验分层；渲染消费面＝`../../scripts/contract-build.sh`，节语义详见 schema 该属性 description）；机器 verification 支持 `expect_exit` 整数（0–255，缺省为 0）；合同散文以 JSON 字符串承载（`\n` 转义），scope 为 Scope 树字符串数组；无 `status` 字段——票状态真相源＝`facts/requirements/tickets/index.json`（正文 Status 行为投影打印件）；存量 Markdown 票冻结零改写。 |
| `dispatch-contract.schema.json` | 派发合同占位符清单（数据表 schema，非 JSON Schema draft-07） | 派发合同占位符统一索引与按阶段必备字段表：`placeholders` 为 28 个占位符全集（字段名字典），`contract_fields` 按 implementation（16 字段）／review（6 字段）／commit（6 字段）三阶段列必备字段。权威消费者＝`../../scripts/check-dispatch-contract.sh`——`--check-template` 以 `placeholders` 全集与 `../prompts/` 三份派发合同模板（implementation/review/commit 三件 `*-prompt.md`）的占位符并集做双向零差集核对，`--check` 以 `contract_fields` 对合同文件做按推断类型的必备字段完整性核对（退出码 0 通过／1 失败并逐名输出缺失字段或差集／2 用法或环境错误），`--check-dispatch` 实现阶段合同派发前置校验（解析 `REPOSITORY_PATH` 与 `TICKET_ID`，要求目标为 linked worktree 且票 `status=in_progress`；主检出路径、未领取票或非 in_progress 一律拒绝）。字段约束与失败语义详见 `../../scripts/README.md` 该脚本专节。 |
| `ticket-record.example.json` | 标注样例 | `x-sample: true` 的 task 结构样例，字段值全部为占位，不含真实票面数据；用于 schema 结构核对（request 侧可选字段 origin/decision/depends_on 见 schema description；`dispatch` 节为三阶段派发合同数据样例——三阶段对象各带该阶段全键占位值，形态与 `ticket-record.schema.json` dispatch 属性一致）。 |
| `ledger-row.schema.json` | 账本行运行格式合同（数据表 schema，非 draft-07） | 记录账本行键集/键序/值域的单一合同：`facts/project/changes.jsonl`（`../../scripts/ticket-ops.sh` 写入与行校验）五/六/八/九键行族与 `facts/project/micro.jsonl`（`../../scripts/lane-commit.sh` micro 道机写）七键/既有六键行族，kind 维度适用条件、键序与值域在此单源声明；消费者三方＝`../../scripts/ticket-ops.sh`、`../../scripts/lane-commit.sh`、`../templates/project.md.tmpl` 票务脚本承载注记（键序描述逐字对齐 `rows[].keys`）。文档级单源：两脚本不运行时读取，安装闭包不含此件。 |
| `request-index.schema.json` | 退役（2026-10-14，仅为存量项目保留历史读法、非现行路径；新项目不再生成需求登记册） | `docs/requests/index.json` REQ 状态索引 JSON Schema（draft-07）：REQ 状态唯一真相源，与票账本（issue-index）分账——id 形态 `REQ-YYYYMMDD-NNN`、Request 状态机取值（proposed/triaged/accepted/specified/ready＋旁支 rejected/deferred/needs-user-decision，旁支允许冒号后缀原因）、可选 title/depends_on；单文件一条目一行，机制与 issue-index 同款。 |
| `receipt.schema.json` | 审查收据机器 schema（证据审计引擎输入侧） | draft-07、`additionalProperties: false`：顶层必备 `schema_version`／`receipt_kind`／`ticket_id`／`created_at`／`actor`，`receipt_kind` 经 `allOf if/then` 分阶段补必备字段（dispatch：`base_sha`／`target_stage`；implementation：`base_sha`／`head_sha`／`implementer_identity`／`commit_sha`；review：`base_sha`／`head_sha`／`diff_sha`／`reviewer_identity`／`reviewed_at`／`verdict`／`acceptance`；commit：`base_sha`／`commit_sha`／`commit_message`）；`verdict` 受控三值 `PASS`／`PASS_WITH_NOTES`／`FAIL`，`acceptance` 非空且逐项 `ac_id` 非空、`result` ∈ `pass`／`fail`／`unknown`；sha 字段为 40 位小写十六进制，时间字段为 UTC 秒粒度。消费者＝`../../scripts/ticket-audit.sh`（只读审计，按此取字段不写回）；文档级 schema，安装闭包不含此件。 |

## 契约头例外登记

- JSON 不支持注释：schema JSON 文件以 `$id` / `title` / `description` 承载导航元数据（见 `run-record.schema.json` 与 `issue-index.schema.json` 的 description）；包完整性契约头检查（SPEC-06 §5 第 6 项）对本目录 JSON 文件按 `LICENSE` 同类例外处理。
- run record 的生成条件与字段语义在目标项目 `rules/project.md` §12.4（模板：`../templates/project.md.tmpl`）；本目录只承载机器格式，不承载流程规则。
- 票状态索引的落点、写入机制与状态冲突裁决语义在 SPEC-02 §8 / R-02-014 与目标项目 `rules/project.md` §5.2 触发矩阵、§12.5 道脚本承载注记（方案 C 终裁 T1/T2/T4/T10）；本目录只承载机器格式，不承载流程规则。
- 票/REQ 本体的开票形态、文件命名与状态真相源语义在 SPEC-02 §5.1（R-02-013/R-02-014）与目标项目 `rules/project.md` §5.2 开票形态注记（定稿，2026-09-18）；本目录只承载机器格式，不承载流程规则。
- REQ 状态索引自退役（2026-10-14）：新项目不再生成需求登记册，新需求走卡片（任务票）；本 schema 仅为存量项目旧登记的读法校验保留，冻结只读。

> ticket-record.schema.json 的 checkpoint 属性承载三阶段检查点容器（implementation/review/commit，payload 形状由角色合同承载），并保留历史字符串形态只读兼容（80/82 两张）；其余未知顶层字段仍按 schema 拒绝。
