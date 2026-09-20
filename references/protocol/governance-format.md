---
id: protocol-governance-format
kind: protocol
authority: 权威层级第 4 级（流程规则）；格式语义上游为 SPEC-02（第 3 级），冲突以 SPEC-02 为准
lifecycle: Live
read_when: 编写或修改任何治理文件、模板或规则块时；Review 治理文件格式 diff 时
trigger: 规则块字段、Level 取值、元数据承载形态、文件格式分工或措辞禁令语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 字段序、类型、规则块格式与短码登记为定稿基线；语义变化须用户确认并同步 SPEC-02 与本手册；规则块 ID 全局唯一不得复用
depends_on: SPEC-02；被 read-policy.md 与票 08/10 的模板、SKILL 重写依赖
---
<!-- Input: SPEC-02 §2/§3/§4/§5/§8/§9 格式协议、SPEC-02 §11 第一项待决的收敛决定与公开包现有结构事实。 -->
<!-- Output: Agent Up 治理文件的统一规则块、机器优先格式、三层结构、元数据承载形态与文件格式分工手册。 -->
<!-- Pos: 公开包 `references/protocol/` 手册之一，治理格式协议的产品事实源；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 治理格式协议

本手册把 SPEC-02 的格式协议落成 Agent Up 生成与维护治理文件时的产品事实源：统一规则块、机器优先格式、三层结构、元数据承载形态与文件格式分工。读取阶梯、权威层级与档位加载见 `read-policy.md`。

## 1. 快速摘要

- 治理文件机器优先：硬规则、状态、条件、权限、验收一律结构化，可被静态定位与核对。
- 可执行规则一律用统一规则块表达，字段固定九项：ID、Level、When、Action、Forbidden、Stop if、Evidence、Owner、Authority。
- 规则块 ID 全局唯一：`R-<所属文件短码>-<三位序号>`；SPEC 用规格号数字（如 `R-02-001`），protocol 手册用登记短码（`GF`、`RP`）。
- Level 只取 `MUST` / `MUST NOT` / `SHOULD` / `MAY`；对具体任务不适用的规则记 `N/A + reason`，不得静默忽略。
- 条件一律 `IF <条件> THEN <动作> ELSE <动作>`，逐条可判真伪。
- 关键规则禁用"尽量、适当、必要时、通常、原则上、酌情"等不可判定措辞。
- 清单、索引、产物关系用 YAML/JSON；领域语义与决策背景留自然语言，放"解释与例外"层。
- 每份治理文件三层：快速摘要（10-20 行）→ 可执行规则 → 解释与例外（按需）。
- 元数据九字段只做导航；正文才是规范本体，冲突以正文为准。
- 元数据承载形态双轨定稿：YAML frontmatter（首选）或 HTML 契约头 + 元数据表（等价头部块）。
- 各治理文件按分工表选定形态：路由、协议、机器索引、任务合同、进度索引、追加历史、词条、地图、图、面向人的 README。
- 读取阶梯、权威层级与档位加载见 `read-policy.md`（前缀 `R-RP-`）。

## 2. 可执行规则

### 2.1 统一规则块

规则块是治理文件表达可执行规则（硬规则、门禁、权限、验收）的唯一结构。标题行含 ID 与 Level，块体含七字段，合计九字段：

| 字段 | 位置 | 内容约束 |
| --- | --- | --- |
| ID | 标题行 | `R-<所属文件短码>-<三位序号>`，全局唯一，不得复用 |
| Level | 标题行 | `MUST` / `MUST NOT` / `SHOULD` / `MAY` 四值之一 |
| When | 块体 | 规则适用的可判定触发条件 |
| Action | 块体 | 要求执行的动作；条件分支用 IF/THEN/ELSE |
| Forbidden | 块体 | 明确禁止的行为；确无内容写 `无` |
| Stop if | 块体 | 触发即停止并报告的条件；确无内容写 `无` |
| Evidence | 块体 | 可核对证据的形态 |
| Owner | 块体 | 负责执行或遵守该规则的角色，平台无关表述 |
| Authority | 块体 | 规则的权威来源（规格章节或上游规则块） |

规则块 ID 前缀方案（定稿，全局唯一）：

- SPEC 文件：`R-<规格号两位数字>-<三位序号>`，如 `R-02-001`。
- `agent-up/references/protocol/` 手册：`R-<文件短码>-<三位序号>`。短码登记表：`GF` = `governance-format.md`，`RP` = `read-policy.md`。新增手册须先在本表登记短码，再使用规则块。

#### R-GF-001 规则块字段齐备 `MUST`

- **When**：任何治理文件表达可执行规则（硬规则、门禁、权限、验收）时。
- **Action**：使用统一规则块：标题行含 `R-<所属文件短码>-<三位序号>` 与 Level；块体含 `When`、`Action`、`Forbidden`、`Stop if`、`Evidence`、`Owner`、`Authority` 七字段。
- **Forbidden**：缺字段；字段改名；把可执行规则散落在无可定位结构的散文中。
- **Stop if**：某字段在语境下确无内容 → 写 `无`；确不适用 → 写 `N/A + reason`；不得删除字段。
- **Evidence**：规则块含全部九字段，且可被按标题前缀的静态检索定位。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §2（R-02-001）。

#### R-GF-002 Level 取值与适用性评估 `MUST`

- **When**：填写规则块 Level 字段，或对具体任务评估规则适用性时。
- **Action**：Level 只取 `MUST`、`MUST NOT`、`SHOULD`、`MAY`。对具体任务评估时，不适用的 `MUST`/`SHOULD` 记录 `N/A + reason`；`SHOULD`/`MAY` 未执行时记录理由。
- **Forbidden**：自造等级（如"建议优先""强制推荐"）；无 reason 的 `N/A`。
- **Stop if**：规则的义务强度无法判定 → 停止并向用户确认，不猜测。
- **Evidence**：每条规则 Level 在允许集合内；适用性评估含 `N/A + reason` 或执行证据。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §2（R-02-002）。

#### R-GF-003 条件表达 `MUST`

- **When**：规则块或流程表达条件分支时。
- **Action**：条件用 `IF <条件> THEN <动作> ELSE <动作>` 表达；多条件用编号子句展开，逐条可判真伪。
- **Forbidden**：用"尽量""适当""必要时""通常""原则上""酌情"表达关键规则的触发或分支。
- **Stop if**：条件本身是未确认事实 → 标 `【待定：...】` 并报告。
- **Evidence**：条件在给定输入下可被逐字判真/判假。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §2（R-02-003）。

### 2.2 机器优先格式

#### R-GF-004 硬规则与状态结构化 `MUST`

- **When**：编写或修改治理文件中的硬规则、状态、条件、权限、验收内容时。
- **Action**：以规则块、表格或状态机结构化表达，可被静态定位与核对。
- **Forbidden**：用连续散文承载上述内容。
- **Stop if**：不结构化就无法如实表达（含待定事实）→ 标 `【待定：...】` 并报告，不编造。
- **Evidence**：对应内容存在结构化块。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §3（R-02-004）、REQ-20260903-001。

#### R-GF-005 清单索引关系机器格式 `MUST`

- **When**：表达清单、索引或产物间关系时。
- **Action**：用 YAML/JSON 机器可读格式（如 artifacts.yaml、项目地图 JSON、票状态索引 JSON）；JSONL 为机器可读清单/账本合法形态（如 `changes.jsonl` 一行一事实）；人类可读说明放配套 README。
- **Forbidden**：用表格或散文替代要求机器消费的索引；机器格式中夹叙事。
- **Stop if**：无。
- **Evidence**：索引文件可被工具直接解析。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §3（R-02-005）。

#### R-GF-006 语义与背景保留自然语言 `MUST`

- **When**：表达领域语义、决策背景或面向人的说明时。
- **Action**：写成自然语言，放"解释与例外"层；README 面向人；语义与结构化规则各归其位。
- **Forbidden**：把语义背景包装成 `MUST` 规则；把可执行规则藏进解释层逃避字段约束。
- **Stop if**：无。
- **Evidence**：解释层内容不承担门禁职能。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §3（R-02-006）。

### 2.3 治理文件三层结构

#### R-GF-007 三层组织 `MUST`

- **When**：编写或大改任何治理文件时。
- **Action**：按三层组织：①快速摘要（10-20 行，让人一分钟看懂定位与硬规则）；②可执行规则（规则块/表格/状态机）；③解释与例外（按需，可省略）。
- **Forbidden**：摘要超载为全文复述；规则层混入叙事；无摘要直接堆规则。
- **Stop if**：摘要压不进 20 行 → 说明文件职责过多，报告用户考虑拆分，不自行拆。
- **Evidence**：文件依次含三层；摘要行数在 10-20 行。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §4（R-02-007）。

### 2.4 元数据承载形态（定稿）

本节收敛 SPEC-02 §11 第一项待决：元数据九字段的承载形态、字段序与类型。

承载双轨：

1. **YAML frontmatter（首选）**：文件以 `---` 围栏的 YAML 头开始，九字段按固定序以标量字符串书写；HTML 契约头（Input/Output/Pos）紧跟 frontmatter 之后。适用于 skill 文件与宿主支持 frontmatter 的文件。
2. **等价头部块**：宿主不支持 frontmatter 的仓库治理 markdown，用 HTML 契约头注释 + `## 元数据` 键值表承载九字段，字段序与语义相同（本工作区 `docs/specs/` 现状即此形态）。

字段序（固定，不得重排）：`id`、`kind`、`authority`、`lifecycle`、`read_when`、`trigger`、`owner`、`update_policy`、`depends_on`。

字段类型（定稿）：

| 字段 | 类型 | 取值约束 |
| --- | --- | --- |
| `id` | string | 全局唯一标识（如 `SPEC-02`、`protocol-governance-format`） |
| `kind` | string 受控枚举 | `spec` / `request` / `process` / `protocol` / `ticket` / `template` / `index` / `record` / `context` / `map` / `readme`；新增值先在本表登记 |
| `authority` | string | `权威层级第 <1-6> 级（<层级名>）`，可附上游来源说明 |
| `lifecycle` | string 受控枚举 | `Record`（确认后不再随正文演进的记录）/ `Live`（随维护持续演进的活文件）；新增值先在本表登记 |
| `read_when` | string | 触发读取本文件的场景描述，条件可判定 |
| `trigger` | string | 须触发同步复审的语义变化描述 |
| `owner` | string | 唯一写入 owner，平台无关角色表述 |
| `update_policy` | string | 变更条件与程序 |
| `depends_on` | string | 上游 id 列表与被依赖说明，以 `；` 分隔 |

承载规则：九字段全部为标量字符串，不使用嵌套结构；缺值写 `【待定：...】`，不留空；元数据只做导航，正文才是规范本体。

#### R-GF-008 元数据九字段与承载形态 `MUST`

- **When**：创建或大改治理文件时。
- **Action**：头部元数据含九字段 `id`、`kind`、`authority`、`lifecycle`、`read_when`、`trigger`、`owner`、`update_policy`、`depends_on`，按本节定稿的承载双轨、字段序与类型书写。
- **Forbidden**：在元数据中写规范性内容——元数据只做导航；正文才是规范本体；重排字段序；使用嵌套结构。
- **Stop if**：元数据与正文冲突 → 以正文为准，修复元数据，报告差异。
- **Evidence**：九字段齐备，顺序与类型符合本节；导航用途与正文不冲突。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §5（R-02-008）、SPEC-02 §11 第一项待决收敛。

### 2.5 文件格式分工

| 文件 | 格式定位 |
| --- | --- |
| `AGENTS.md` | 极短路由：入口与边界声明，不复制流程 |
| `development-process.md` | 完整协议：三阶段、委派、门禁的唯一事实源 |
| `docs/agent/artifacts.yaml` | 机器索引：产物清单与关系（SPEC-03） |
| 任务票 | 元数据 + 固定区块 |
| `docs/issues/index.json` | 票状态索引：JSON＋Schema（`agent-up/references/schemas/issue-index.schema.json`），状态机唯一真相源（单文件 JSON，一条目一行） |
| `progress.md` | 冻结历史档案：指针注记后零写入（票 33 终裁 T12；存量行零改写） |
| `docs/progress-current.md` | 现役状态投影：Derived，generated_from＝`docs/issues/index.json`＋生成器，生成器独占写 |
| `changes.md` | 追加历史：只增不改 |
| `docs/changes.jsonl` | 追加历史（新形态）：JSONL 一行一事实，`kind` 受控五值 `decision`/`change`/`gate`/`export`/`record`，只追加 |
| `CONTEXT.md` | 结构化词条 + 自然语言定义 |
| 项目地图 | JSON |
| 架构图 | diagram-as-code |
| `README.md` | 面向人：目录定位与直接成员登记（一层），不承载可执行规则 |

#### R-GF-009 分工绑定 `MUST`

- **When**：创建或修改上表所列治理文件时。
- **Action**：按分工表选择形态；越界内容移到对应文件。
- **Forbidden**：在 `AGENTS.md` 复制流程细节；在 `progress.md` 展开叙事；改写 `changes.md` 历史条目。
- **Stop if**：内容找不到归属文件 → 报告用户决定归属，不新建冗余文件。
- **Evidence**：各文件形态与分工表一致。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §8（R-02-011）。

### 2.6 措辞规范

#### R-GF-010 关键规则禁用模糊措辞 `MUST NOT`

- **When**：书写任何 `MUST`/`MUST NOT`/门禁/验收语句时。
- **Action**：柔性指引降级为 `SHOULD`/`MAY` 并写清判断依据；关键规则条件用 IF/THEN/ELSE。
- **Forbidden**：在关键规则中使用"尽量、适当、必要时、通常、原则上、酌情"等不可判定的措辞。
- **Stop if**：规则本意确实模糊 → 向用户确认语义后再落规则。
- **Evidence**：对关键规则做模糊词静态扫描，无可判定性命中（禁令条款内的引述除外）。
- **Owner**：该治理文件元数据登记的 owner。
- **Authority**：SPEC-02 §9（R-02-012）、REQ-20260903-001。

## 3. 解释与例外

- SPEC-01 与既有 `changes.md`、`progress.md` 历史条目不追溯改写为规则块或 frontmatter 形态；本手册只约束新写与大改内容。
- 本工作区既有治理文件（如根 `AGENTS.md`、`docs/development-process.md`）当前仅契约头、无九字段头，属等价头部块的过渡欠账，由票 09/10 的公开包重组与模板重写统一收敛；收敛前不构成对既有文件的追溯判罚。
- 本手册定义格式协议，不定义任何具体模板文件的内容；模板落地由票 06～10 承担。
- 元数据九字段适用于分工表所列治理文件与公开包 protocol 手册；`README.md` 是面向人的目录索引，只承载契约头，不强制九字段。
- 本手册自身即自举合规样本：frontmatter 九字段按 §2.4 定稿形态书写，三层结构按 §2.3 组织，规则块用 `R-GF-` 前缀。
