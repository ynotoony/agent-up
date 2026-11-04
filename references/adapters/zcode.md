---
id: adapter-zcode
kind: protocol
authority: 权威层级第 4 级（流程规则：宿主适配层映射）；能力语义上游为 adapter-capability-contract 与 SPEC-05，冲突以平台无关角色合同（<role-contract-dir>/）与 SPEC-05 为准
lifecycle: Live
read_when: 在宿主生成或维护运行时入口（frontmatter 方言、工具对照）时；评估宿主能力满足度时
trigger: 宿主 frontmatter 方言、能力→工具对照或运行时入口形态变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 本文件只是运行时映射，不是事实源；与角色合同冲突时以合同为准并修正本文件；宿主方言变化须同步 capability-contract 登记面
depends_on: adapter-capability-contract（能力契约）；SPEC-05 §4（R-05-003 适配层地位）；被目标项目宿主适配层实例依赖
---
<!-- Input: adapter-capability-contract.md 能力契约、原宿主 frontmatter 形态（name/color/description/tools）与目标项目角色合同路径约定（<role-contract-dir>/）。 -->
<!-- Output: zcode 宿主差异面：能力→宿主工具对照、三角色 frontmatter 方言模板、独立执行体声明；公共规则唯一权威＝capability-contract.md。 -->
<!-- Pos: 公开包 adapters/ 宿主映射文件（运行时映射，不是事实源；事实源是目标项目 <role-contract-dir>/ 角色合同）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md（references/README.md）。 -->

# 宿主适配层映射（zcode 运行时入口）

本文件承载 zcode 宿主的运行时形态：frontmatter 方言、工具对照与原宿主绑定 frontmatter 的迁移形态；公共规则不在此复述。

## 1. 快速摘要

- platform 枚举值：`zcode`；frontmatter 方言对齐宿主 `name`/`color`/`description`/`tools` 四字段。
- 原宿主 frontmatter（name/color/tools 与描述内工具列举）自角色模板移入本文件（SPEC-06 §3 R-06-002 平台绑定出模板）。
- 运行时入口的 name/description 承载派发摘要；入口三件按角色合同生成，落在 `.zcode/agents/`。
- 工具面：`Read`/`Grep`/`Glob`/`Edit`/`Write`/`Bash`，逐能力展开见 §2.2。
- 独立 subagent 执行体状态＝local-observation（本仓库 `.zcode/agents/` 实跑观察面；官方文档指针未核验，状态标 pending）。
- readonly_execute 本宿主登记 `readonly_enforcement: policy-only`（宿主默认沙箱行为未核验，观察记录不作等级依据，注记见 §3）。
- 方言与装载时序的本地观察记录（思考档位声明、会话内改写不生效）见 §3 注记。

## 2. 可执行规则

### 2.1 公共规则唯一权威（指针）

- 公共规则（映射免责/事实源、能力声明、能力映射同步义务、readonly 等级、无 subagent 降级路径与记录义务、档位、platform 扩展）唯一权威＝`capability-contract.md`；本文件只承载宿主差异面，不复述其正文。
- 能力基元与阶段表：`capability-contract.md` §2.1/§2.2（规则块 R-CC-001）。
- 只读约束等级与降级路径：`capability-contract.md` §2.3（规则块 R-CC-002）；扩展登记：§2.5（R-CC-005）。
- Git 写强制等级与 fallback：`capability-contract.md` §2.2（规则块 R-CC-001）。

### 2.2 能力→宿主工具对照

本表登记的 zcode 工具口径为本宿主差异面；能力语义与阶段归属见 §2.1 指针。

| 能力基元 | 宿主工具 | 约束 |
| --- | --- | --- |
| inspect | Glob + Read | 目录与现状盘点 |
| search | Grep、Glob | 文件名与内容检索 |
| read | Read | 读取文件内容 |
| edit | Edit | 修改既有文件 |
| write | Write | 创建新文件 |
| execute | Bash | 可变更工作区状态的命令；git_write_enforcement: policy-only（无默认 git 写 deny 配置，Git 写禁令由角色合同自律；实现会话交付报告须记该值与降级原因） |
| readonly-execute | Bash | 仅只读命令；readonly_enforcement: policy-only（只读性由调用方约束；宿主默认沙箱行为未核验，观察状态标 local-observation——本地观察记录见 §3 注记，不作本行等级依据） |
| vcs-read | Bash | git status/log/diff 等只读命令 |
| vcs-write | Bash | git add/commit 等写命令 |

### 2.3 三角色能力映射

角色合同 `required_capabilities` 到本宿主工具清单的对应（行序＝入口生成序）：

| 角色合同 | required_capabilities | tools |
| --- | --- | --- |
| <role-contract-dir>/implementation.md | inspect, search, read, edit, write, execute | [Read, Grep, Glob, Edit, Write, Bash] |
| <role-contract-dir>/review.md | inspect, search, read, readonly-execute | [Read, Grep, Glob, Bash] |
| <role-contract-dir>/commit.md | inspect, execute | [Read, Grep, Glob, Bash（仅 ticket-run.sh <NN> commit 编排入口）] |

### 2.4 独立执行体声明与降级路径

声明：本宿主独立 subagent 执行体状态＝local-observation（本仓库 `.zcode/agents/` 运行时入口按独立 subagent 会话形态派发执行，实跑观察面；官方文档指针未核验，状态标 pending；本地观察记录见 §3 注记，不充当本条支持声明依据）。独立 Review 默认由独立 subagent 执行。

- 降级：部署裁剪或权限配置导致 subagent 不可用时，走 `capability-contract.md` §2.3 降级路径 (a)/(b)/(c)，并记录 `independent_review: unavailable` 及实际所选路径（公共规则唯一权威，本文件不复述）。
- 记录面：审查记录字段与 run record 指针按 `capability-contract.md` §2.3/R-CC-002 登记（公共规则唯一权威，本文件不复述）。

### 2.5 三角色 frontmatter 方言模板

入口文件按角色合同生成，frontmatter 形态固定如下（description 承载派发摘要）：示例中的 `<role-contract-dir>` 必须按目标项目登记值展开；新项目默认 `rules/implementation/roles/`，旧项目使用登记的兼容目录（通常是 `docs/agent/roles/`）：

```text
---
name: implementation
description: "Implementation 阶段执行体运行时入口；合同、Scope 与输出以 <role-contract-dir>/implementation.md 为准"
color: blue
tools: [Read, Grep, Glob, Edit, Write, Bash]
---
```

```text
---
name: review
description: "Review 阶段执行体运行时入口；只读独立审查，规则以 <role-contract-dir>/review.md 为准"
color: orange
tools: [Read, Grep, Glob, Bash]
---
```

```text
---
name: commit
description: "Commit 阶段执行体运行时入口；白名单提交，规则以 <role-contract-dir>/commit.md 为准"
color: green
tools: [Read, Grep, Glob, Bash]
---
```

### 2.6 模型档位可用性

- 分档能力：可逐档（按入口 frontmatter 逐会话声明模型；来源＝§3 本地观察注记，状态 local-observation，官方文档指针未核验，不冒充官方支持声明）。
- 角色级模型键：`model`（subagent frontmatter 字段，本地观察来源 2026-09-30，状态 local-observation）。
- 降级记录格式：`model_tier: inherit`（入口未声明模型时按会话模型执行，记录该行与所继承的会话档位；本文件不写模型名）。

| 档位 | 取值来源 |
| --- | --- |
| small | frontmatter `model:` 填部署侧选定的低成本 provider/model，并按 §3 注记同声明思考档位（本文件不写模型名） |
| standard | frontmatter `model:` 填部署侧选定的中间成本 provider/model，思考档位同声明（本文件不写模型名） |
| strong | frontmatter `model:` 填部署侧选定的高能力 provider/model，思考档位同声明（本文件不写模型名） |

### 2.7 短上下文别名与到线策略

- 短上下文别名取值：262144 token（短上下文别名的上下文窗口上限口径＝`max_context_size` 262144 token，约 256Ki token；本机 Kimi Code CLI 只读实测 2026-11-04：19 个已登记别名中 4 个取 262144、15 个取 1048576；四个 262144 短上下文别名均未设 `max_input_size`，全文件仅 1 处该键为 `DeepSeek/deepseek-flash` 的 `200000`，不属短上下文别名；命令与结果见该票 Implementation Checkpoint）。
- 到线行为：待实测（未发起到线请求：`max_input_size` 到线是压缩上下文还是硬拒绝未实测；核验前不据此判定档位为硬封顶或软封顶）。
- Agent 工具显式覆盖：否（本机运行面 Agent 工具形参仅 prompt/description/subagent_type/resume/run_in_background 且 `additionalProperties` 为 false，无 `model` 形参，逐次派发不能覆盖 §2.6 的入口级 `model` 声明；2026-11-04 只读核对）。
- 降级记录格式：`short_context: <262144 token|none> boundary: <压缩|硬拒绝|待实测> evidence: <实测命令与环境>`（未取短上下文别名时记 `none`；`boundary` 与 `evidence` 按实测填写，未实测保持待实测；本文件不写模型标识）。

## 3. 解释与例外

- inspect 映射为 Glob + Read 的组合：目录结构盘点用 Glob，现状内容核对用 Read；单能力对应多工具时按任务需要选用。
- 宿主本地适配层实例（目标项目内 `.zcode/agents/` 等价目录）由本映射生成；其与 `<role-contract-dir>/` 合同冲突时以合同为准，并报告差异。
- 本地观察注记（local-observation，2026-09-30 宿主实跑记录；非规范事实源，不作规则块支持声明依据）：钉模型的 agent 须显式声明思考档位——agent profile 的模型选择不继承会话档位，选中模型而档位缺失时 spawn 即报 reasoning-level-missing；声明语法＝frontmatter `model: provider/model$档位` 或独立字段 `thoughtLevel: <档位>`（来源＝宿主实装：模型选择分隔符常量与 agent profile 解析器，`model_fallback` 非宿主字段），适配层实例 frontmatter 已按 `$high` 补声明并移除死字段；agent profile 于会话启动时装载，会话中改写 frontmatter 不生效，补丁实弹验证归新会话首派发；验证通过前，general-purpose 子代理注入同内容角色合同仍为现行有效独立形态（落 §2.4 降级路径 (b)「不同执行身份」）。
- 本地观察注记（local-observation，2026-10-26 单机实测；非规范事实源）：宿主默认沙箱对包外写入拒绝、工作区内写入不拦截；官方文档对默认沙箱行为的指针未核验（pending），核验前 readonly-execute 行维持 policy-only 从紧口径，本记录不充当 host-enforced/runner-enforced 等级依据。
- 能力 base 与阶段语义见 §2.1 指针；本文件不复述公共规则正文。
- 本文件与 capability-contract 按 `governance-format.md` 定稿的 frontmatter、三层结构与规则块格式书写（自举合规）。
