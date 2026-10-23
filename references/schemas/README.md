<!-- Input: 同级机器格式文件（`run-record.schema.json`、`run-record.example.json`、`issue-index.schema.json`、`ticket-record.schema.json`、`ticket-record.example.json`、`workflow.schema.json`、`dispatch-contract.schema.json`、`ledger-row.schema.json`）的定稿事实、workflow executor checkpoint 协议与 workflow executor 支持子集合同（与 `../../scripts/workflow-executor.sh` 运行时读写逐字段核对后声明），以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的机器 schema 目录索引：直接成员登记、用途说明与 workflow executor 支持子集合同声明。 -->
<!-- Pos: Skill 参考资料机器 schema 目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 机器 schema

本目录承载 `agent-up` 运行时读取与核对用的机器格式 schema。成员清单与本目录实际文件一致，增删 schema 必须在此登记，不静默增删。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明本目录用途并登记直接成员。 |
| `run-record.schema.json` | run record 机器 schema（定稿基线，I-03） | run record 十三字段 JSON Schema（draft-07）：字段语义、生成条件（C2/C3、跨会话交接、中断、无 Git 基线、归属不明）、可选 `independent_review` 指针字段与 `fp-v1` 工作区指纹算法定稿说明。 |
| `run-record.example.json` | 标注样例 | `x-sample: true` 的结构样例，不含真实运行数据；用于 schema 结构核对。 |
| `issue-index.schema.json` | 票状态索引机器 schema（定稿基线；语义权威＝方案 C 终裁 T1/T2/T5/T6） | `docs/issues/index.json` 票状态索引 JSON Schema（draft-07）：票状态机唯一真相源，单文件 JSON 一条目一行；条目字段 id/status/lane/complexity/blocked_by/checkpoint_ref/last_verified/updated_at＋可选 superseded_by（R-DP-039 替代标记：被推翻票的回链，指向票存在性由 check-stale-claims.sh S7 硬断言；lane 枚举 `full`/`user-review`/`micro`；`status` 取 Task 状态机；frontmatter `status` 退役后 `checkpoint_ref`/`last_verified` 语义不变）。 |
| `ticket-record.schema.json` | 票/REQ 本体机器 schema（定稿基线；语义权威＝终裁 T9 改判与 SPEC-02 §5.1） | 新开任务票/新 REQ JSON 本体 JSON Schema（draft-07）：文件命名 task `<NN>-<slug>.json`、request `<REQ-id>.json`；required id/kind/title/created_at，kind 枚举 task/request，task 另必备 complexity/profile/blocked_by（allOf if/then），可选 category（R-DP-039 类别保留：四值性质轴 bug/enhancement/debt/chore，bug 类 verification 必带回归验证句，缺省视同 chore；旧三值 decision/procedural/temporal 退役，存量零回扫）；`profile_reason` 属性＝七维 Requirement Profile 逐维 reason 存储合同（对象恰七键 D/B/I/U/S/M/O、值非空字符串；语义权威＝`../protocol/complexity-profile.md` §2.2，与 verification 的 `record_only.reason` 语义分立互不混用；新 task 开票时点经 ticket-ops open 强制必备，存量票读取面不要求——开票校验与读取校验分层）；机器 verification 支持 `expect_exit` 整数（0–255，缺省为 0）；合同散文以 JSON 字符串承载（`\n` 转义），scope 为 Scope 树字符串数组；无 `status` 字段——票状态真相源＝`docs/issues/index.json`（正文 Status 行为投影打印件）；workflow executor 的外置 checkpoint 协议为 `workflow-checkpoint-v1:<同目录 sidecar 文件名>`，sidecar 名为 `<票文件名>.workflow-checkpoint-v1.json`，票仅保存该固定 sibling 引用；存量 Markdown 票与既有 REQ 冻结零改写。 |
| `workflow.schema.json` | Workflow DSL 机器 schema | draft-07 工作流定义：metadata、inputs/outputs、steps 与 state machine；verification 的 `expect_exit` 为可选整数（0–255，缺省为 0）。executor 只执行 command/verification，agent step 在任何 checkpoint 写入前失败关闭；票体通过 `checkpoint_ref` 指向版本化固定 sibling sidecar（格式见 `ticket-record.schema.json`）。executor 实际支持子集与 `checkpoint_field`/sidecar 读写语义见下文「workflow executor 支持子集」节（回归锁定：`../../scripts/tests/suite-workflow-contract.sh`）。 |
| `dispatch-contract.schema.json` | 派发合同占位符清单（数据表 schema，非 JSON Schema draft-07） | 派发合同占位符统一索引与按阶段必备字段表：`placeholders` 为 28 个占位符全集（字段名字典），`contract_fields` 按 implementation（16 字段）／review（6 字段）／commit（6 字段）三阶段列必备字段。权威消费者＝`../../scripts/check-dispatch-contract.sh`——`--check-template` 以 `placeholders` 全集与 `../prompts/` 三份派发合同模板（implementation/review/commit 三件 `*-prompt.md`）的占位符并集做双向零差集核对，`--check` 以 `contract_fields` 对合同文件做按推断类型的必备字段完整性核对（退出码 0 通过／1 失败并逐名输出缺失字段或差集／2 用法或环境错误）。字段约束与失败语义详见 `../../scripts/README.md` 该脚本专节。 |
| `ticket-record.example.json` | 标注样例 | `x-sample: true` 的 task 结构样例，字段值全部为占位，不含真实票面数据；用于 schema 结构核对（request 侧可选字段 origin/decision/depends_on 见 schema description）。 |
| `ledger-row.schema.json` | 账本行运行格式合同（数据表 schema，非 draft-07） | 记录账本行键集/键序/值域的单一合同：`facts/project/changes.jsonl`（`../../scripts/ticket-ops.sh` 写入与行校验）五/六/八/九键行族与 `facts/project/micro.jsonl`（`../../scripts/lane-commit.sh` micro 道机写）七键/既有六键行族，kind 维度适用条件、键序与值域在此单源声明；消费者三方＝`../../scripts/ticket-ops.sh`、`../../scripts/lane-commit.sh`、`../templates/project.md.tmpl` 票务脚本承载注记（键序描述逐字对齐 `rows[].keys`）。文档级单源：两脚本不运行时读取，安装闭包不含此件。 |
| `request-index.schema.json` | 退役（2026-10-14，仅为存量项目保留读法校验；新项目不再生成需求登记册） | `docs/requests/index.json` REQ 状态索引 JSON Schema（draft-07）：REQ 状态唯一真相源，与票账本（issue-index）分账——id 形态 `REQ-YYYYMMDD-NNN`、Request 状态机取值（proposed/triaged/accepted/specified/ready＋旁支 rejected/deferred/needs-user-decision，旁支允许冒号后缀原因）、可选 title/depends_on；单文件一条目一行，机制与 issue-index 同款。 |

## workflow executor 支持子集

`agent-up/scripts/workflow-executor.sh` 对 `workflow.schema.json` 与 checkpoint sidecar 的实际支持面（合同声明处，与运行时逐字段核对；回归锁定＝`../../scripts/tests/` 的 workflow-contract 套件）。schema 合法≠executor 可执行：超出本节的 schema 形态按「声明项」处理，executor 不消费也不因其在场拒绝 workflow。

- 读取并强制（supported）：`steps[]` 的 `id`/`type`/`description`/`checkpoint_field`/`command`/`agent`（仅作 fail-closed 判定）/`verification[]` 子字段 `name`/`check`/`expect`/`expect_exit`，以及 `state_machine` 三件（`initial_state`/`states`/`transitions`）。步骤 `type` 仅 `command`/`verification` 可执行；`agent` 为 schema 合法类型但运行时拒绝执行——未被 `--retry` 跳过的 agent step 使整个 workflow 在 checkpoint sidecar 落盘（含空 bootstrap）与任何步骤命令执行之前失败关闭，不产生任何 checkpoint。
- 声明但不消费（declared, unenforced）：`workflow` 元数据（`name`/`description`/`version`）、`inputs`/`outputs`（命令行 `--param` 仅接收登记，不做参数替换）、`depends_on`（不强制依赖顺序，按 `steps` 声明序执行）、`on_failure`（不读取；任何步骤失败均按 stop 处理）、verification 子字段 `fail_msg`（解析兼容但不输出，失败消息由 executor 自行生成）。
- `checkpoint_field` 语义（schema 与运行时逐字段一致）：路径由两端等价正则封锁——schema `^checkpoint\.[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$` 与运行时 `checkpoint(?:\.[a-z_][a-z0-9_]*)+` fullmatch 判定等价（`checkpoint.` 加至少一段小写/下划线起始段，段间以 `.` 相接）；两个步骤的字段路径相同或互为前缀即整体拒绝（重叠禁写，含 `--retry` 定位步骤时）。步骤成功且带 `--ticket-file` 时原子写入 sidecar 的 `checkpoint` 对象同名嵌套路径；叶子记录恰三键：`step_name`＝本步骤 id、`completed_at`＝UTC 时刻（格式 `YYYY-MM-DDTHH:MM:SSZ` 且日历有效）、`outputs`＝该步骤命令输出字符串（stdout/stderr 合并、去首尾空白）。`--resume` 按同名字段回读并校验：中间节点必须为对象、叶子必须为对象、`step_name` 与本步骤 id 一致、`completed_at` 非空且为合法 UTC 时刻、`outputs` 为字符串，任一不合即拒绝恢复（读面对额外键不敏感；写面恒恰三键）。无 `checkpoint_field` 的步骤不落 checkpoint，恢复时视为未完成重跑。
- checkpoint sidecar（workflow-checkpoint-v1 协议）：固定 sibling 文件 `<票文件名>.workflow-checkpoint-v1.json`，body 恰为两键对象——`version` 整数 1（不接受布尔/字符串/其他版本）与 `checkpoint` 对象（`checkpoint_field` 去 `checkpoint.` 前缀后的嵌套对象；叶节点＝上述三键记录，分支节点＝子节点对象，禁止叶键残缺或叶分支混写）。票体只保存固定 sibling 引用 `checkpoint_ref`（格式见 `ticket-record.schema.json`）；symlink sidecar、非普通文件 sidecar、孤儿非空 sidecar（有文件无引用）、旧锚点引用、任意路径引用、票内已废弃顶层 `checkpoint` 一律拒绝且零写入。
- `state_machine` 运行时语义：仅在带 `--ticket-file` 时于每步完成后尝试推进；当前状态取票状态索引（缺索引或票不在册＝`unknown`，无转换命中即跳过）。转换条件为机械词表判定：`workflow_started`＝真；`checkpoint.<路径>`＝sidecar 对应字段存在且真值；`all_verifications_pass`＝实现为 checkpoint 数据串非空即真（空对象亦非空，故现行实现恒真）；`verification_failed`/`manual_retry`＝恒假；未知条件＝假并告警。条件语义如与名称直觉不符，以本节描述的运行时实际行为为准。

## 契约头例外登记

- JSON 不支持注释：schema JSON 文件以 `$id` / `title` / `description` 承载导航元数据（见 `run-record.schema.json` 与 `issue-index.schema.json` 的 description）；包完整性契约头检查（SPEC-06 §5 第 6 项）对本目录 JSON 文件按 `LICENSE` 同类例外处理。
- run record 的生成条件与字段语义在目标项目 `rules/project.md` §12.4（模板：`../templates/project.md.tmpl`）；本目录只承载机器格式，不承载流程规则。
- 票状态索引的落点、写入机制与状态冲突裁决语义在 SPEC-02 §8 / R-02-014 与目标项目 `rules/project.md` §5.2 触发矩阵、§12.5 道脚本承载注记（方案 C 终裁 T1/T2/T4/T10）；本目录只承载机器格式，不承载流程规则。
- 票/REQ 本体的开票形态、文件命名与状态真相源语义在 SPEC-02 §5.1（R-02-013/R-02-014）与目标项目 `rules/project.md` §5.2 开票形态注记（定稿，2026-09-18）；本目录只承载机器格式，不承载流程规则。
- REQ 状态索引自退役（2026-10-14）：新项目不再生成需求登记册，新需求走卡片（任务票）；本 schema 仅为存量项目旧登记的读法校验保留，冻结只读。
