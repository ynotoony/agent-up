---
id: workflows-directory
kind: registry
authority: 权威层级第 4 级（流程规则：workflow 实例目录）
lifecycle: Live
read_when: 主 agent 查找 workflow 实例、核对实例定位或维护实例时
trigger: 维护 workflow 实例、判定实例能否当作可执行流程调用
owner: 主 agent（路由层）
depends_on: references/schemas/workflow.schema.json（实例 schema 事实源）
---
<!-- Input: 主 agent 查找 workflow 实例、核对实例定位与可执行性。 -->
<!-- Output: workflow 实例清单、三档定位定义、agent step 拒绝行为与 schema 对应关系。 -->
<!-- Pos: workflows 目录索引；一旦成员变化，务必更新本登记。 -->

# Workflow 实例目录

本目录承载 workflow schema（`../schemas/workflow.schema.json`）的实例 YAML。**目录内现有两实例均为 reference fixture（参考夹具），非生产流程**：其中的 echo／占位命令只为让 schema 与 executor 子集合同可被回归，不代表任何真实业务流程已可执行。

## 三档定位

三档判据互不等价，逐档取证：

| 档位 | 含义 | 取证方式 |
| --- | --- | --- |
| schema-valid | 过 `workflow.schema.json` 子集校验及跨字段校验（`initial_state`／transition `from`/`to`∈`states`、映射目标∈票状态枚举） | workflow-contract 套件 `schema`／`mapping-check` 模式 |
| executor-supported | 步骤逐条落在 `workflow-executor.sh` 支持子集内（`type` 仅 `command`／`verification`），`checkpoint_field`／sidecar 语义可运行时核对 | workflow-contract 套件 `classify` 模式＋端到端执行 |
| production-ready | 步骤命令承载真实业务动作、失败可诊断、产物可核验，且经用户明确采纳为生产入口 | 无机械断言，由 Review 与用户裁决 |

`schema-valid` 不蕴含 `executor-supported`，`executor-supported` 不蕴含 `production-ready`。两实例分档不同：`triage.yaml` 已达第二档（五步全 `command`／`verification`，端到端 exit 0），`implementation.yaml` 只到第一档（含 agent step，executor 在任何 checkpoint 落盘前 fail-closed）。本目录当前**零 production-ready 实例**。

## 目录成员

| 文件 | `workflow.name` | 定位 | 步骤分类 |
| --- | --- | --- | --- |
| `triage.yaml` | `triage-fixture` | reference fixture（非生产） | 五步 `command`／`verification`，executor-supported |
| `implementation.yaml` | `implementation-fixture` | reference fixture（非生产） | 2 agent（fail-closed）＋2 `command`／`verification`，executor 不支持整条 workflow |

- 两文件 `workflow.description` 首句即声明「参考 fixture（非生产）」。
- fixture 只读无外溢：步骤命令不写仓、不写 `/tmp`、不写任何固定路径；需要落盘的临时数据一律由调用方 `mktemp` 自建（回归锁定见 `../../scripts/tests/suite-workflow-contract.sh`）。
- fixture 的 `workflow.name` 带 `-fixture` 后缀，与将来生产实例的入口名（`triage`／`implementation`）分离：同一入口名不得既指向本目录夹具又指向生产流程。

## agent step 的 fail-closed 行为

`workflow-executor.sh` 不支持 agent step：未被 `--retry` 跳过的 agent 步骤会使整条 workflow 在**任何 checkpoint sidecar 落盘与任何步骤命令执行之前**失败关闭——exit 非零，报文为 `step <id> 需要宿主 agent 执行器，但当前执行器没有 agent 适配器`（preflight 阶段判定，无分号后缀），零 sidecar、票文件零改动。

因此 `implementation.yaml` 只能作为 schema／子集合同的正例夹具被校验与分类，**不能当作可执行流程调用**；生产版 Implementation 流程（票本体生成、校验、索引登记、checkpoint、映射的真正实现）留待另行开票。

## schema 对应关系

- 实例字段以 [workflow.schema.json](../schemas/workflow.schema.json) 为机器真相；实例与 schema 的语义漂移由记录层回归 harness 的 workflow-contract 套件核对（实例正例、schema 子集负例、executor 运行时行为与实例定位）。
- `inputs`/`outputs`/`depends_on`/`on_failure`/`fail_msg` 为声明字段，executor 声明不消费；`checkpoint_field`/`sidecar` 承载中断续传的读写语义（字段级注记见 `../schemas/README.md`「workflow executor 支持子集」节，合同正文唯一声明处＝`workflow.schema.json` 顶层 `description`）。

## 维护纪律

- 新增实例必须登记本 README 成员表，并过 schema 子集校验正例。
- 新增实例若为 reference fixture，`workflow.name` 须带 `-fixture` 后缀，`workflow.description` 首句须声明「参考 fixture（非生产）」，步骤命令零固定路径写入。
- 删除实例必须从成员表移除并说明原因。
- 实例语义变化须同步 `../schemas/README.md` 的 schema 语义注记与 workflow-contract 套件断言。
