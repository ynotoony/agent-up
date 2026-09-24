<!-- Input: 同级三份协议手册（`governance-format.md`、`read-policy.md`、`complexity-profile.md`）的定位与短码登记事实，以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的协议手册目录索引：直接成员登记与短码登记。 -->
<!-- Pos: Skill 参考资料协议手册目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 治理协议手册

本目录承载 `agent-up` 运行时读取的治理协议手册：治理格式协议、读取协议与复杂度/Profile 协议。成员清单与本目录实际文件一致，增删手册必须在此登记，不静默增删。

## 目录清单

| 名字 | 地位 | 规则块短码 | 功能 |
| --- | --- | --- | --- |
| `README.md` | 目录索引 | 无 | 说明本目录用途并登记直接成员。 |
| `governance-format.md` | 治理格式协议手册（产品事实源） | `GF` | 统一规则块（九字段）、机器优先格式、三层结构、元数据承载形态与文件格式分工；手册短码登记表见其 §2.1。 |
| `read-policy.md` | 读取协议手册（产品事实源） | `RP` | 读取阶梯（L0-L4）、任务型最小读取范围、权威层级冲突处理与 capability profile 档位（minimum/full）加载。 |
| `complexity-profile.md` | 复杂度与 Profile 协议手册（产品事实源） | `CP` | C0-C3 复杂度权威表（触发条件、默认拆票与上下文策略、最低交付证据、高风险面清单）与 D/B/I/U/S/M/O 七维 Profile 权威表（含义、Required 最低证据、状态填法）及复杂度不推断 Profile 的正交原则。 |

## 短码登记

- `GF` = `governance-format.md`，`RP` = `read-policy.md`，`CP` = `complexity-profile.md`；正式登记表在 `governance-format.md` §2.1（`CP` 与 adapters 的 `CC`/`ZC` 在 §2.1 的补记因该手册正文冻结递延，以目录 README 登记面承载），与 `../README.md` adapters 条目（`CC`/`ZC`）、`../templates/README.md` 模板短码互不重叠。
- 新增协议手册：先在 `governance-format.md` §2.1 登记短码，再创建文件并在本 README 登记；该手册正文冻结期间的例外与 `CC`/`ZC`/`CP` 同口径处理。
