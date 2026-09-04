<!-- Input: 同级两份适配手册（`capability-contract.md`、`zcode.md`）的定位与短码登记事实，以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的平台适配目录索引：直接成员登记与短码登记。 -->
<!-- Pos: Skill 参考资料平台适配目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 平台适配

本目录承载 `agent-up` 运行时读取的宿主能力契约与宿主映射手册。适配层是运行时映射，不是事实源；事实源是平台无关角色合同（目标项目 `docs/agent/roles/`）与核心协议。成员清单与本目录实际文件一致，增删手册必须在此登记，不静默增删。

## 目录清单

| 名字 | 地位 | 规则块短码 | 功能 |
| --- | --- | --- | --- |
| `README.md` | 目录索引 | 无 | 说明本目录用途并登记直接成员。 |
| `capability-contract.md` | 宿主能力契约手册（adapters/ 内宿主映射文件的共同上游） | `CC` | 九能力基元、五阶段→能力表、required_capabilities 声明规则、无 subagent 降级路径、capability profile 档位定稿与 platform 枚举扩展登记。 |
| `zcode.md` | zcode 宿主映射手册（运行时映射，不是事实源） | `ZC` | 能力→宿主工具对照、三角色 frontmatter 方言模板与适配层地位边界。 |

## 短码登记

- `CC` = `capability-contract.md`，`ZC` = `zcode.md`；`../README.md` adapters 条目为 capability-contract.md §3 例外所引登记面，本 README 为同目录登记面，两者与 `../templates/README.md` 模板短码互不重叠。
- 新增宿主适配：先在 `capability-contract.md` R-CC-005 登记枚举值，再创建 `adapters/<host>.md` 并在本 README 登记。
