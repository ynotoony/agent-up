<!-- Input: 同级 `../SKILL.md` 对参考资料的读取约定，以及本目录内的旧项目手册、模板、protocol 协议手册、adapters 平台适配与机器 schema（各子目录成员见其 README）。 -->
<!-- Output: `agent-up` 运行时可读取的参考资料索引与直接成员登记。 -->
<!-- Pos: Skill 参考资料目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Skill 参考资料

本目录提供 `agent-up` 运行时读取的旧项目协调手册、治理模板、协议手册、平台适配与机器 schema。本 README 只登记直接成员（一层）；各子目录的成员清单见其自身 `README.md`。

## 目录清单

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明本目录用途并登记直接成员。 |
| `old-project.md` | 旧项目手册 | 指导已有代码或部分治理项目的盘点、补缺与交付。 |
| `templates/` | 模板目录 | 保存新建治理文件和阶段角色合同的模板（manifest 见 `templates/README.md`）。 |
| `protocol/` | 协议手册目录 | 承载治理格式与读取协议手册（短码 `GF`/`RP`），成员与短码登记见 `protocol/README.md`。 |
| `adapters/` | 平台适配目录 | 承载宿主能力契约与宿主映射（短码 `CC`/`ZC`；运行时映射，不是事实源，事实源为目标项目 `docs/agent/roles/` 角色合同与核心协议），成员见 `adapters/README.md`。 |
| `schemas/` | 机器 schema 目录 | 承载 run record 机器 schema 与标注样例（JSON 以 `$id`/`title`/`description` 承载导航元数据），成员与用途见 `schemas/README.md`。 |
