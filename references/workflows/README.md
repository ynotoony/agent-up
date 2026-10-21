---
id: workflows-directory
kind: registry
authority: 权威层级第 4 级（流程规则：workflow 实例目录）
lifecycle: Live
read_when: 主 agent 查找可执行 workflow 实例或维护实例时
trigger: 派发 workflow、维护 workflow 实例
owner: 主 agent（路由层）
depends_on: references/schemas/workflow.schema.json（实例 schema 事实源）
---
<!-- Input: 主 agent 查找可执行 workflow 实例。 -->
<!-- Output: workflow 实例文件清单与 schema 对应关系。 -->
<!-- Pos: workflows 目录索引；一旦成员变化，务必更新本登记。 -->

# Workflow 实例目录

本目录承载 workflow schema（`../schemas/workflow.schema.json`）的可执行实例 YAML：主 agent 按 workflow 定义的步骤序列驱动任务流程，条件跳过、工具调用、checkpoint 落盘与中断续传由 `../scripts/workflow-executor.sh` 承载。

## 目录成员

| 文件 | 描述 | 执行分类 |
| --- | --- | --- |
| `triage.yaml` | 需求分诊流程实例（从需求描述到 ready 票） | 步骤全 executable |
| `implementation.yaml` | Implementation 阶段流程实例 | agent 步骤 fail-closed 与 executable 步骤混合 |

## schema 对应关系

- 实例字段以 [workflow.schema.json](../schemas/workflow.schema.json) 为机器真相；实例与 schema 的语义漂移由记录层回归 harness 的 workflow-contract 套件核对（实例正例、schema 子集负例与 executor 运行时行为）。
- `inputs`/`outputs`/`depends_on`/`on_failure`/`fail_msg` 为声明字段，executor 声明不消费；`checkpoint_field`/`sidecar` 承载中断续传的读写语义（字段级注记见 `../schemas/README.md`「workflow executor 支持子集」节）。

## 维护纪律

- 新增实例必须登记本 README 成员表，并过 schema 子集校验正例。
- 删除实例必须从成员表移除并说明原因。
- 实例语义变化须同步 `../schemas/README.md` 的 schema 语义注记。
