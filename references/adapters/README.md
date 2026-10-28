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
| `adapter-template.md` | 平台适配文件结构模板（单文件 per 平台基线） | `AT` | 新建 `<host>.md` 的结构基线：必填段落与骨架（三要素＝能力基元映射、方言承载形态、独立执行体声明）；公共规则只留唯一权威指针，不复制规范正文。 |
| `capability-contract.md` | 宿主能力契约手册（adapters/ 内宿主映射文件的共同上游） | `CC` | 九能力基元、两层协作→能力表（路由层 Triage＋编码层三阶段；历史 Intake 行已于 2026-10-23 退役，现行口径不含该行）、required_capabilities 声明规则、无 subagent 降级路径（含分级交付道车道衔接注记）、微任务道能力束、readonly_enforcement 只读约束等级模型（四级＋pending）与 capability profile 档位定稿、platform 枚举扩展登记。适配器公共规则的唯一权威。 |
| `adapter-diffs.rules` | 适配差异数据表（五宿主差异面机器数据行；数据＝机器真相，宿主 Markdown＝现行文档基线） | 无 | 四节机器数据行：capability-map（九基元↔宿主工具逐宿主映射，含 readonly-execute 行内嵌 readonly_enforcement 等级声明）、role-map（三阶段角色映射）、executor-status（独立执行体状态）、dialect-signature（宿主特有方言签名）；与五份宿主映射文件对应段的一致性由 `check-package.sh` 检查 27 机械核对，两向漂移即 FAIL 指名宿主与段（表文修正归人工裁决，不静默互改）。 |
| `zcode.md` | zcode 宿主映射手册（运行时映射，不是事实源） | `ZC` | 能力→宿主工具对照、三角色 frontmatter 方言模板、独立执行体状态声明（readonly_enforcement: policy-only）；公共规则只留 capability-contract 指针。 |
| `claude-code.md` | claude-code 宿主映射手册（运行时映射，不是事实源；shell hooks 代表） | `CL` | 能力→宿主工具对照、三角色 subagent frontmatter 方言模板、独立执行体声明（readonly_enforcement: policy-only）；公共规则只留 capability-contract 指针。 |
| `codex.md` | codex 宿主映射手册（运行时映射，不是事实源；规则文件代表） | `CX` | 能力→宿主工具对照、三角色 config.toml agents 表方言、独立执行体声明（readonly_enforcement: runner-enforced）；公共规则只留 capability-contract 指针。 |
| `pi.md` | pi 宿主映射手册（运行时映射，不是事实源；插件扩展代表） | `PI` | 能力→宿主工具对照、三角色 skills/上下文承载形态、独立执行体声明（默认无内置；readonly_enforcement: policy-only）；公共规则只留 capability-contract 指针。 |
| `dsh.md` | dsh 宿主映射手册（运行时映射，不是事实源；插件扩展第二代表） | `DS` | 能力→宿主工具对照、三角色 cordis.yml 承载形态、独立执行体声明（按 profile 区分；readonly_enforcement: pending，落定前按 policy-only 从紧）；公共规则只留 capability-contract 指针。 |

## 短码投影（导航，非登记事实）

- 本 README 目录清单表的短码列是导航投影：宿主短码（`ZC`/`CL`/`CX`/`PI`/`DS`）与宿主绑定事实（platform/shortcode/adapter_file/capability_coverage/role_mapping/evidence_status）的机器真相唯一承载于 `../../scripts/package-manifest.rules` `adapter-registry` 节，短码全局唯一由该节单源验证；表列与 `../README.md` adapters 行的一致性由 `check-package.sh` 检查 26 机械核对，漂移即 FAIL（表文修正归人工裁决，不静默互改）。非宿主短码 `AT` = `adapter-template.md`，`CC` = `capability-contract.md`，与 templates/protocol 短码同源登记于同表 `shortcodes` 节。去重后五宿主映射文件不设 `R-<短码>-` 规则块，宿主短码作导航与登记标识保留。
- 新增宿主适配（R-CC-005 收敛后口径）：先在 `../../scripts/package-manifest.rules` `adapter-registry` 节登记六字段行（数据先行，短码两字母不与既有重叠），再按 `capability-contract.md` R-CC-005 落 platform 枚举登记处、按 `adapter-template.md` 结构基线创建 `adapters/<host>.md`；shortcodes 节镜像行与本 README、`../README.md` 投影行随动，漏项由检查 26 指名。

## 公共规则去重

宿主映射文件只承载宿主差异面；公共规则（映射免责、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）的唯一权威是 `capability-contract.md`，每份宿主文件只保留「§2.1 公共规则唯一权威（指针）」一段，不设规则块、不复述规范正文。`adapter-template.md` 同步收敛为结构基线（骨架与必填段说明）。复发护栏＝`role-prompt` 套件 P6（五宿主指针在位＋零规则块＋零公共规则正文）与 N6（公共规则正文回写即失败），以及 `check-package` 检查 14/22/27/28。

## 差异段生成与漂移核对

本目录五份宿主映射文件的差异面（§2.2 九行能力对照表、§2.3 角色映射表行、§2.4 独立执行体声明句、§2.5 方言模板签名）以 `adapter-diffs.rules` 为数据输入，由 `../../scripts/generate-adapter-diffs.sh` 单向渲染；该生成器是差异段的唯一渲染器，不承载任何规则语义。

- 渲染：`sh ../../scripts/generate-adapter-diffs.sh --section cap|role|exec|dialect|all [--platform <p>]`，输出宿主文件对应段的 Markdown 行（含行内代码反引号等强调记号，与数据表字段原文一致）；`all` 四段全出、段间空行分隔。
- 核对：`sh ../../scripts/generate-adapter-diffs.sh --check` 逐宿主逐段渲染后与现行宿主文件比对——表段只去首尾空白、按三列取单元格后**逐字节**比对（含强调记号，宿主角色列先剥 `<role-contract-dir>/` 前缀与 `.md` 后缀；单元格数非 3 的行原样输出＝漂移，不静默截断），锚语段原文在场断言；零漂移 exit 0 并输出计数汇总，漂移 exit 1 逐行指名宿主文件、段与首个差异行，数据表不合预期 exit 2。
- 一致性由 `check-package.sh` 检查 28 常驻机械核对（与检查 27 的数据面一致性互为两层：27 按两侧同剥反引号的宽松口径断言数据 ↔ 文档，28 按逐字节严格口径断言渲染 ↔ 文档，强调记号单侧丢失即 28 FAIL）；漂移时先判来源（表文或宿主正文），人工裁决后就地修正并同批重跑两项检查。
