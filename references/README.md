<!-- Input: 同级 `../SKILL.md` 对参考资料的读取约定，以及本目录内的旧项目手册、升级手册、delivery.rules 文法与版本说明、模板、protocol 协议手册、adapters 平台适配、prompts 派发模板、workflows 流程实例与机器 schema（各子目录成员见其 README）。 -->
<!-- Output: `agent-up` 运行时可读取的参考资料索引与直接成员登记。 -->
<!-- Pos: Skill 参考资料目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Skill 参考资料

本目录提供 `agent-up` 运行时读取的旧项目协调手册、升级手册、delivery.rules 文法与版本说明、治理模板、协议手册、平台适配、派发 prompt 模板、workflow 流程实例与机器 schema。本 README 只登记直接成员（一层）；各子目录的成员清单见其自身 `README.md`。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明本目录用途并登记直接成员。 |
| `old-project.md` | 旧项目手册 | 指导已有代码或部分治理项目的盘点、补缺与交付。 |
| `upgrade.md` | 升级手册 | 指导已初始化项目同步包新版的升级主链（模式判定第四态；盘点落地面→逐件三态对比→差异清单确认→reconcile 更新→验证收尾）。 |
| `delivery-rules.md` | delivery.rules 文法与版本说明 | 仓根 `delivery.rules` 四节文法、指令全集、fail-closed 六规则与解析版本单源的权威说明（共享解析库 `../scripts/dp-load-rules.sh` 的文法对齐面）。 |
| `templates/` | 模板目录 | 保存新建治理文件和阶段角色合同的模板（manifest 见 `templates/README.md`）。 |
| `protocol/` | 协议手册目录 | 承载治理格式与读取协议手册（短码 `GF`/`RP`），成员与短码登记见 `protocol/README.md`。 |
| `adapters/` | 平台适配目录 | 承载宿主能力契约与五份宿主映射（platform 全集 `zcode`/`claude-code`/`codex`/`pi`/`dsh`，机器真相＝`../scripts/package-manifest.rules` 的 adapter-registry 节，宿主短码为注册表投影；运行时映射，不是事实源，事实源为目标项目角色合同（新布局缺省 `rules/implementation/roles/`，旧项目为登记的兼容目录如 `docs/agent/roles/`）与核心协议），成员与短码投影见 `adapters/README.md`。 |
| `prompts/` | 派发模板目录 | 承载 Implementation / Review / Commit 三阶段派发 prompt 模板，为 `../scripts/check-dispatch-contract.sh` `--check-template` 的占位符比对面，成员与占位符说明见 `prompts/README.md`。 |
| `workflows/` | 流程实例目录 | 承载 workflow schema（`schemas/workflow.schema.json`）的参考 fixture 实例 YAML（非生产：`workflow.name` 带 `-fixture` 后缀，入口名与将来生产实例分离）；经 `../scripts/workflow-executor.sh` 按支持子集驱动，三档定位（schema-valid／executor-supported／production-ready）与成员见 `workflows/README.md`。 |
| `schemas/` | 机器 schema 目录 | 承载 run record／派发合同／票记录／索引／workflow 机器 schema 与标注样例（JSON 以 `$id`/`title`/`description` 承载导航元数据；workflow executor 支持子集合同唯一声明处＝`schemas/workflow.schema.json` 顶层 description），成员与用途见 `schemas/README.md`。 |
