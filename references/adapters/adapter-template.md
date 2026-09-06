---
id: adapter-template
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射模板）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同与 SPEC-05 为准
lifecycle: Live
read_when: 新建平台适配文件（`adapters/<host>.md`）时；评估既有适配器结构完整性时
trigger: 新宿主适配器创建（R-CC-005 第②步）或适配器结构基线变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 结构基线变化须与 capability-contract 登记面同步，并核对既有适配器不漂移；本文件是结构模板，不承载任何平台的工具对照事实
depends_on: adapter-capability-contract（能力契约与 R-CC-005 扩展登记流程）；SPEC-05 §4（适配层地位）
---

<!-- Input: adapter-capability-contract.md 能力契约、R-CC-005 新宿主扩展登记流程与既有适配器（zcode.md 等）的结构先例。 -->
<!-- Output: 平台适配文件的单文件结构模板：必填段落、规则块骨架与独立执行体声明/降级路径骨架（占位符形式，不含任何平台事实）。 -->
<!-- Pos: 公开包 adapters/ 结构模板（新建 `<host>.md` 时复制本骨架并填入该平台已核验事实）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 平台适配文件模板（单文件 per 平台基线）

本模板定义 `adapters/<host>.md` 的结构基线：单文件 per 平台，段落骨架与规则块格式固定，平台事实由各适配文件按官方文档核验后填入。新建适配器前先按 capability-contract R-CC-005 顺序登记 platform 枚举值，再复制本骨架。

## 1. 快速摘要

- 单文件 per 平台是定稿基线形态；文件名 `<host>.md` 与 platform 枚举值一致（小写连字符）。
- 每份适配文件必含三要素：能力基元映射、frontmatter 方言、独立执行体声明与降级路径；三要素缺一即不合格。
- 事实准入：能力映射、方言与执行体声明只登记官方文档可核验事实并注明来源与取阅日期；未核验处写【待定】，不虚构。
- 规则块前缀 `R-<host 短码>-`；短码两字母，登记于本目录 README 短码登记节，与既有短码互不重叠。
- 本模板自身是结构模板，不承载平台工具对照事实；平台专名只出现在各 `<host>.md` 与 R-CC-005 两处登记位。
- 适配文件是运行时映射，不是事实源；与平台无关角色合同冲突时以合同为准。
- 收益声明禁止：无实验数据不得写 token 节省、速度或可靠性提升（R-CC-004）。
- 平台文档与方言随版本变化；适配文件触发条件声明方言变化时同步。

## 2. 可执行规则

### 2.1 结构基线

#### R-AT-001 三要素齐备 `MUST`

- **When**：新建或修改任何 `adapters/<host>.md` 时。
- **Action**：按本模板骨架产出：frontmatter 九字段 + 契约头三行（Input/Output/Pos）+ §1 快速摘要 + §2 可执行规则（含 R-<短码>-001 映射不是事实源、R-<短码>-002 能力映射与方言同步、R-<短码>-003 独立执行体声明与降级路径）+ §3 解释与例外；独立执行体声明与降级路径不得缺省。
- **Forbidden**：缺三要素之一；引用未核验的第三方观察作为分类依据；写平台无关角色合同中禁止的平台专名。
- **Stop if**：平台官方文档不可达或身份存疑 → 停止登记，写【待定】并报告，不虚构事实。
- **Evidence**：适配文件可对照本模板逐段核对；三要素各有对应小节。
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
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准；宿主方言变化须同步登记面
depends_on: adapter-capability-contract
---
<!-- Input: <官方文档取阅记录；调研报告引用路径>。 -->
<!-- Output: <host> 宿主运行时映射：能力→工具对照、方言模板、独立执行体声明与降级路径。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# <host> 宿主适配层映射（运行时入口）

## 1. 快速摘要
<!-- 事实源声明；本文件承载三要素；规范标识与官方源指针；规则块短码声明。 -->

## 2. 可执行规则
### 2.1 适配层地位
#### R-<短码>-001 映射不是事实源 `MUST`
<!-- When/Action/Forbidden/Stop if/Evidence/Owner/Authority，对齐 R-ZC-001 语义。 -->

### 2.2 能力→宿主工具对照
#### R-<短码>-002 能力映射与方言同步 `MUST`
<!-- 九能力基元逐行映射 + 方言模板；每行注明官方文档依据与取阅日期；未核验写【待定】。 -->

### 2.3 独立执行体声明与降级路径
#### R-<短码>-003 独立执行体与降级如实记录 `MUST`
<!-- 声明宿主是否具备独立 subagent 执行体（官方文档依据 + 取阅日期）； -->
<!-- 支持时：登记执行体形态与调用方式； -->
<!-- 不支持或被裁剪时：按 capability-contract R-CC-002 依序 a/b/c 降级，记录 independent_review: unavailable。 -->

## 3. 解释与例外
<!-- 单能力多工具选用规则；宿主本地适配层实例与角色合同冲突处理；不复述 capability-contract 内容。 -->
```

## 3. 解释与例外

- 模板骨架中的占位注释在成文时删除；规则块按 governance-format 定稿格式书写（When/Action/Forbidden/Stop if/Evidence/Owner/Authority 九要素）。
- 宿主能力覆盖不全不阻塞登记：按已核验口径书写映射，未核验能力逐项写【待定】；某阶段所需能力无法满足时按 capability-contract R-CC-001 Stop if 处理。
- 同一宿主存在多 profile / 配置档位时（如最小安装裁剪 subagent），声明须区分档位，不得以最高配档冒充默认形态。
- 本文件与既有适配器（`zcode.md` 等）结构漂移时，以本模板为准核对并报告，不静默改写他人文件。
