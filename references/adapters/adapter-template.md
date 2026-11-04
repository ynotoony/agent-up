---
id: adapter-template
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射模板）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 新建平台适配文件（`adapters/<host>.md`）时；评估既有适配器结构完整性时
trigger: 新宿主适配器创建（R-CC-005 第②步）或适配器结构基线变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 结构基线变化须与 capability-contract 登记面同步，并核对既有适配器不漂移；本文件是结构模板，不承载任何平台的工具对照事实，也不复述公共规则正文
depends_on: adapter-capability-contract（能力契约与 R-CC-005 扩展登记流程）；SPEC-05 §4（适配层地位）
---

<!-- Input: adapter-capability-contract.md 能力契约、R-CC-005 新宿主扩展登记流程与既有适配器（zcode.md 等）的结构先例。 -->
<!-- Output: 平台适配文件的单文件结构基线：必填段落、骨架与三要素说明（占位符形式，不含任何平台事实），公共规则只留指针。 -->
<!-- Pos: 公开包 adapters/ 结构模板（新建 `<host>.md` 时复制本骨架并填入该平台已核验事实）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 平台适配文件模板（单文件 per 平台结构基线）

本模板定义 `adapters/<host>.md` 的结构基线：单文件 per 平台，段落骨架固定，平台事实由各适配文件按官方文档核验后填入；公共规则正文不在适配文件承载。

## 1. 快速摘要

- 单文件 per 平台是定稿基线形态；文件名 `<host>.md` 与 platform 枚举值一致（小写连字符）。
- 每份适配文件必含三要素：能力基元映射、方言承载形态、独立执行体声明；三要素缺一即不合格。
- 公共规则（映射免责、能力声明与映射同步义务、readonly 等级、降级路径、记录义务、档位、platform 扩展）只在适配文件保留一个权威指针段，唯一权威＝`capability-contract.md`。
- 事实准入：能力映射、方言与执行体声明只登记官方文档可核验事实并注明来源与取阅日期；未核验面用状态词表标注（pending/unsupported/local-observation），【待定】标记只用于结构规则块外注记面。
- 差异面数据驱动：九行能力表、三角色映射表、执行体声明锚语与方言签名以 `adapter-diffs.rules` 为数据输入，由生成器单向渲染，手改正文即被漂移检查拦截；适配文件不设 `R-<短码>-` 规则块，结构约束由本模板 R-AT-001 执行，短码只作导航登记。
- 能力对照表 readonly-execute 行必须声明 `readonly_enforcement: <等级>`（四级＋pending；等级语义唯一权威见 `capability-contract.md` §2.3，本模板不复述）；execute 行必须声明 `git_write_enforcement: <等级>`（同词表；等级语义与降级记录义务唯一权威见 `capability-contract.md` §2.2）。
- 角色合同根以 `<role-contract-dir>` 表示；新项目默认 `rules/implementation/roles/`，旧项目兼容模式从登记面读取既有等价路径（通常为 `docs/agent/roles/`），生成宿主配置时必须展开变量。
- 收益声明禁止：无实验数据不得写 token 节省、速度或可靠性提升（唯一权威见 `capability-contract.md` R-CC-004）。
- 平台文档与方言随版本变化；适配文件触发条件声明方言变化时同步。
- 新宿主登记顺序：先在 `package-manifest.rules` adapter-registry 节登记六字段行，再按 `capability-contract.md` R-CC-005 登记 platform 枚举值，最后复制本骨架。

## 2. 可执行规则

### 2.1 结构基线

#### R-AT-001 宿主差异面齐备 `MUST`

- **When**：新建或修改任何 `adapters/<host>.md` 时。
- **Action**：按 §2.2 骨架产出：frontmatter 九字段＋契约头三行（Input/Output/Pos）＋§1 宿主事实摘要＋§2 可执行规则（§2.1 公共规则唯一权威指针、§2.2 能力→宿主工具对照表、§2.3 三角色能力映射表、§2.4 独立执行体声明、§2.5 方言承载模板、§2.6 模型档位可用性、§2.7 短上下文别名与到线策略四要素）＋§3 解释与例外；不设规则块；能力对照表 readonly-execute 行声明 `readonly_enforcement: <等级>`，execute 行声明 `git_write_enforcement: <等级>`；§2.7 的别名取值与到线行为取值落 `README.md` 两张受控词表，未实测一律写待实测。
- **Forbidden**：缺段落之一；在适配文件复述公共规则正文或另立第二权威；引用未核验的第三方观察作为分类依据；写平台无关角色合同中禁止的平台专名。
- **Stop if**：平台官方文档不可达或身份存疑 → 停止登记，写【待定】并报告，不虚构事实。<!-- pending-decl-exempt: 写入指引面——本行是【待定】标记机制的指令本体（R-AT-001 事实准入），非未核验规范事实 -->
- **Evidence**：适配文件可对照 §2.2 骨架逐段核对；三要素各有对应小节，公共规则段只有指针。
- **Owner**：Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）。
- **Authority**：capability-contract R-CC-005、SPEC-05 §4（R-05-003）。

### 2.2 骨架（复制后按平台填入）

```text
---
id: adapter-<host>
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05
lifecycle: Live
read_when: 在 <host> 宿主生成或维护运行时入口时
trigger: <host> 宿主方言、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract
---
<!-- Input: <官方文档取阅记录；调研报告引用路径>。 -->
<!-- Output: <host> 宿主差异面：能力→工具对照、方言承载模板、独立执行体声明；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# <host> 宿主适配层映射（运行时入口）

<宿主运行时形态一段：本文件承载什么；公共规则不在此复述。>

## 1. 快速摘要
<!-- 宿主特有事实：platform 枚举值、接入面归属、独立执行体状态、权限/许可证、方言形态；
     只列本宿主差异事实，不复述公共规则。 -->

## 2. 可执行规则
### 2.1 公共规则唯一权威（指针）
<!-- 一段指针＋能力基元、readonly 等级、降级路径、扩展登记的节位指针；
     公共规则唯一权威＝capability-contract.md，本文件不复述。 -->

### 2.2 能力→宿主工具对照
<!-- 「| 能力基元 |」九行表（数据驱动，行文与 adapter-diffs.rules 逐字节一致）；
     每行注明官方文档依据与取阅日期；readonly-execute 行须含 readonly_enforcement: <等级>，
     execute 行须含 git_write_enforcement: <等级>。 -->

### 2.3 三角色能力映射
<!-- 「| <role-contract-dir>/<role>.md |」三行表（数据驱动，行文与数据表逐字节一致）。 -->

### 2.4 独立执行体声明与降级路径
<!-- 本宿主执行体状态声明句（官方文档依据＋取阅日期）；降级与记录要求只给 capability-contract §2.3 指针。 -->

### 2.5 方言承载模板
<!-- 三角色入口的方言模板（frontmatter / config.toml / skills / cordis.yml 等）；
     <role-contract-dir> 变量展开说明与旧项目兼容目录并陈句。 -->

### 2.6 模型档位可用性
- 分档能力：<可逐档|仅单档|不可分档>（依据＝<官方文档依据＋取阅日期 或 local-observation>）
- 角色级模型键：<已核实键名>（来源与取阅日期）／待实测（未核实面不写键名）
- 降级记录格式：`model_tier: <inherit|单档键名>`（<记录口径>；本文件不写模型名）

| 档位 | 取值来源 |
| --- | --- |
| small | <本宿主 small 档取值来源> |
| standard | <本宿主 standard 档取值来源> |
| strong | <本宿主 strong 档取值来源> |

### 2.7 短上下文别名与到线策略
- 短上下文别名取值：<取值词表项|待实测>（<单位与含义；实测命令、环境与日期>）
- 到线行为：<压缩|硬拒绝|待实测>（<实测证据或待实测原因；未实测不得写压缩或硬拒绝>）
- Agent 工具显式覆盖：<可|否|待实测>（<宿主派发面依据>）
- 降级记录格式：`short_context: <取值|none> boundary: <压缩|硬拒绝|待实测> evidence: <实测命令与结果>`（<记录口径>；本文件不写模型名）

## 3. 解释与例外
<!-- 单能力多工具选用规则；宿主本地适配层实例与角色合同冲突处理；宿主特有观察注记。 -->
```

## 3. 解释与例外

- 骨架中的占位注释在成文时删除；规则块（仅在必须机械执行结构约束时）按 governance-format 定稿格式书写（When/Action/Forbidden/Stop if/Evidence/Owner/Authority 七字段）。
- 宿主能力覆盖不全不阻塞登记：按已核验口径书写映射，未核验能力逐项标注状态；某阶段所需能力无法满足时按 `capability-contract.md` R-CC-001 Stop if 处理。
- 同一宿主存在多 profile / 配置档位时（如最小安装裁剪 subagent），声明须区分档位，不得以最高配档冒充默认形态。
- 本文件与既有适配器（`zcode.md` 等）结构漂移时，以本模板为准核对并报告，不静默改写他人文件。
