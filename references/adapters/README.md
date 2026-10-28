<!-- Input: 同级适配手册（`capability-contract.md`、`adapter-template.md`、五份宿主映射文件与适配差异数据表 `adapter-diffs.rules`）的定位、来源状态与短码投影（机器真相＝`../../scripts/package-manifest.rules` adapter-registry 节），以及 `../README.md` 对本目录的登记。 -->
<!-- Output: `agent-up` 运行时可读取的平台适配目录索引：直接成员登记与短码导航投影（不另立登记事实）。 -->
<!-- Pos: Skill 参考资料平台适配目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 平台适配

本目录承载 `agent-up` 运行时读取的宿主能力契约与宿主映射手册。适配层是运行时映射，不是事实源；事实源是平台无关角色合同（目标项目 `<role-contract-dir>/`）与核心协议。成员清单与本目录实际文件一致，增删手册必须在此登记，不静默增删。

`<role-contract-dir>` 是目标项目已登记的角色合同目录变量：新项目默认为 `rules/implementation/roles`；旧项目兼容模式读取其登记的等价目录（通常为 `docs/agent/roles`），保留既有文件，不自动迁移。宿主映射示例必须在生成时展开该变量，不能把任一布局写成所有项目的唯一事实源。

## 目录清单

| 名字 | 地位 | 规则块短码 | 功能 |
| --- | --- | --- | --- |
| `README.md` | 目录索引 | 无 | 说明本目录用途并登记直接成员。 |
| `adapter-template.md` | 平台适配文件结构模板（单文件 per 平台基线） | `AT` | 新建 `<host>.md` 的结构基线：必填段落、规则块骨架与三要素（能力基元映射、frontmatter 方言、独立执行体声明与降级路径）骨架。 |
| `capability-contract.md` | 宿主能力契约手册（adapters/ 内宿主映射文件的共同上游） | `CC` | 九能力基元、四阶段→能力表（历史五阶段含 Intake 行，退役 2026-10-23）、required_capabilities 声明规则、无 subagent 降级路径（含分级交付道车道衔接注记）、微任务道能力束、readonly_enforcement 只读约束等级模型（四级＋pending）与 capability profile 档位定稿、platform 枚举扩展登记。 |
| `adapter-diffs.rules` | 适配差异数据表（五宿主差异面机器数据行；数据＝机器真相，宿主 Markdown＝现行文档基线） | 无 | 四节机器数据行：capability-map（九基元↔宿主工具逐宿主映射，含 readonly-execute 行内嵌 readonly_enforcement 等级声明）、role-map（三阶段角色映射）、executor-status（独立执行体状态）、dialect-signature（宿主特有方言签名）；与五份宿主映射文件对应段的一致性由 `check-package.sh` 检查 27 机械核对，两向漂移即 FAIL 指名宿主与段（表文修正归人工裁决，不静默互改）。 |
| `zcode.md` | zcode 宿主映射手册（运行时映射，不是事实源） | `ZC` | 能力→宿主工具对照、三角色 frontmatter 方言模板、适配层地位边界与独立执行体状态声明（readonly_enforcement: policy-only）。 |
| `claude-code.md` | claude-code 宿主映射手册（运行时映射，不是事实源；shell hooks 代表） | `CL` | 能力→宿主工具对照、三角色 subagent frontmatter 方言模板、独立执行体声明与降级路径（readonly_enforcement: policy-only）。 |
| `codex.md` | codex 宿主映射手册（运行时映射，不是事实源；规则文件代表） | `CX` | 能力→宿主工具对照、三角色 config.toml agents 表方言、独立执行体声明与降级路径（readonly_enforcement: runner-enforced）。 |
| `pi.md` | pi 宿主映射手册（运行时映射，不是事实源；插件扩展代表） | `PI` | 能力→宿主工具对照、三角色 skills/上下文承载形态、独立执行体声明（默认无内置）与降级路径（readonly_enforcement: policy-only）。 |
| `dsh.md` | dsh 宿主映射手册（运行时映射，不是事实源；插件扩展第二代表） | `DS` | 能力→宿主工具对照、三角色 cordis.yml 承载形态、独立执行体声明（按 profile 区分）与降级路径（readonly_enforcement: pending，落定前按 policy-only 从紧）。 |

## 短码投影（导航，非登记事实）

- 本 README 目录清单表的规则块短码列是导航投影：宿主短码（`ZC`/`CL`/`CX`/`PI`/`DS`）与宿主绑定事实（platform/shortcode/adapter_file/capability_coverage/role_mapping/evidence_status）的机器真相唯一承载于 `../../scripts/package-manifest.rules` `adapter-registry` 节，短码全局唯一由该节单源验证；表列与 `../README.md` adapters 行的一致性由 `check-package.sh` 检查 26 机械核对，漂移即 FAIL（表文修正归人工裁决，不静默互改）。非宿主短码 `AT` = `adapter-template.md`，`CC` = `capability-contract.md`，与 templates/protocol 短码同源登记于同表 `shortcodes` 节。
- 新增宿主适配（R-CC-005 收敛后口径）：先在 `../../scripts/package-manifest.rules` `adapter-registry` 节登记六字段行（数据先行，短码两字母不与既有重叠），再按 `capability-contract.md` R-CC-005 落 platform 枚举登记处、按 `adapter-template.md` 结构基线创建 `adapters/<host>.md`；shortcodes 节镜像行与本 README、`../README.md` 投影行随动，漏项由检查 26 指名。
