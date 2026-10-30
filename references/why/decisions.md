<!-- Input: 安装面瘦身前后的规则块清单（80 条旧块）与核心规则/脚本归属结论。 -->
<!-- Output: 逐条决策背景：原条 ID｜处置｜为什么删或保留｜兜底所在（核心规则或脚本/手册）。 -->
<!-- Pos: 决策背景档案（references/why/，不安装到目标项目）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 被删条款的决策背景

安装面由 80 个规则块收敛为 10 条核心规则（`../templates/core.md.tmpl`，生成 `rules/core.md`）。
本表逐条登记每条旧块的处置与兜底归属，供后续维护判断「这条还管不管、谁管」。

- **不是删除保护**：G1–G5 五条保证由 C1–C10 承载，见 `../templates/core.md.tmpl` 各块的 G 标注。
- **不是第二权威**：本目录只记背景，任何条文冲突以 `rules/core.md` 与流程三件为准。
- **包内面**：`protocol/` 与 `adapters/` 的规则块未删除，只是不安装；其条目在此登记为「保留」。

## 逐条去向

| 原条 ID | 处置 | 为什么 | 兜底 |
| --- | --- | --- | --- |
| R-AG-001 | 删除 | 记录保护并入 C9（记录只追加）与 C6（不删不盖）；规则本体只剩一处 | C9 |
| R-AG-002 | 删除 | 条件产物默认不创建并入 C1（产物创建须经用户确认） | C1 |
| R-AG-003 | 删除 | 三道门禁拆为 C1/C2/C3 三条，不再单列汇总条 | C1、C2、C3 |
| R-DP-001 | 删除 | 读取阶梯改为 project 骨架表（L0–L4 ＋任务型最小范围） | project §2 表 |
| R-DP-002 | 删除 | 冲突即停并入 C5（冲突即停、单一权威） | C5 |
| R-DP-003 | 删除 | 记录保护并入 C9（JSONL 行级不截断/不改写/不重排/不删除） | C9 |
| R-DP-004 | 删除 | Derived 四标注并入 project 生命周期表 Derived 行 | project §5.1 |
| R-DP-005 | 删除 | Adapter 生成条件并入 project 生命周期表 Adapter 行 | project §5.1 |
| R-DP-006 | 删除 | 默认不创建并入 C1 与 project 触发矩阵表头 | C1 ＋ project §5.2 |
| R-DP-007 | 删除 | 产物单本账并入 project §5.3（十三字段登记口径） | project §5.3 |
| R-DP-008 | 删除 | 四类语义变化触发同步并入 project §5.4 一段 | project §5.4 |
| R-DP-009 | 删除 | 产物状态机取值并入 project §5.5 | project §5.5 |
| R-DP-010 | 删除 | Artifact Plan 作为用户确认形态之一并入 C1 | C1 |
| R-DP-011 | 删除 | 与 AG-003 重复；门禁本体归 C1–C3，车道替代形态归 assessment 三车道表 | C1、C2、C3 |
| R-DP-012 | 删除 | 两套状态机取值并入 C7 受控集合与 project §12 表 | C7 ＋ project §12 |
| R-DP-013 | 删除 | 事实优先级并入 C5 权威层级与 project 恢复顺序 | C5 ＋ project §12 |
| R-DP-014 | 删除 | 八步恢复顺序并入 C7 与 project §12 恢复顺序 | C7 ＋ project §12 |
| R-DP-015 | 删除 | run record 作为状态载体并入 C7 | C7 |
| R-DP-016 | 删除 | 写入所有权并入 C8（单一写者）与 project §12.5 矩阵 | C8 ＋ project §12.5 |
| R-DP-017 | 删除 | Implementation 中断并入 C7（状态落盘可接续） | C7 |
| R-DP-018 | 删除 | Review 中断不得沿用作 pass 并入 C3 禁止项 | C3 |
| R-DP-019 | 删除 | Commit 中断核查并入 C4 停止条件 | C4 |
| R-DP-020 | 删除 | 破坏性操作禁令并入 C6（不删不盖不重置） | C6 |
| R-DP-021 | 删除 | 六条不变量清单被 C1–C10 全覆盖，单列重复 | C1–C10 |
| R-DP-022 | 删除 | Discovery Record 属生成流程细则，非 G 保证；生成面由评审把关 | C3（审查面） |
| R-DP-023 | 删除 | 来源优先级并入 C5 权威层级与 project 取信顺序 | C5 |
| R-DP-024 | 删除 | Profile/capability manifest 属能力档位细节，随 capability-contract 手册承载 | capability-contract.md |
| R-DP-026 | 删除 | 检查点管线并入 C7（阶段推进即落盘） | C7 |
| R-DP-027 | 删除 | 外部引用与许可登记属合规细则，非 G 保证 | C3（审查面） |
| R-DP-028 | 删除 | 状态以权威引用表达并入 C7 与 project 投影口径 | C7 |
| R-DP-029 | 删除 | 命令输出瘦身属上下文卫生，非 G 保证 | discipline §11 |
| R-DP-031 | 删除 | 三车道准入改为 assessment 决策表；车道声明权与判据理由归 C10 | assessment 表 ＋ C10 |
| R-DP-032 | 删除 | 编程思想五问属编码品味，非治理保证；删除后由 C3 审查判断力承载 | C3（质量面） |
| R-DP-033 | 删除 | 方案调研前置属方案质量要求，不构成 G1–G5 保证；删除后由用户验收与 C3 独立审查承载 | C3（质量面） |
| R-DP-034 | 删除 | 用量遥测是记录义务非门禁，删除后 run-record.sh seal 仍 fail-closed | run-record.sh |
| R-DP-035 | 删除 | 体系外真值断言并入 C2（涉运行行为须含一条体系外真值断言） | C2 |
| R-DP-036 | 删除 | main-only 栅栏是本包自用机制，随 delivery.rules 与 worktree-add.sh/export-payload.sh 承载，不构成目标项目运行时要求 | worktree-add.sh、export-payload.sh |
| R-DP-037 | 删除 | 拆票内容边界压成 assessment 拆票段末句（开发性工作开票，治理变更落账本） | assessment 拆票段 |
| R-DP-038 | 删除 | 两问闸改为 assessment「复杂度两问」决策表；空转守卫随脚本通道保留 | assessment 两问表 |
| R-DP-039 | 删除 | 历史票权威剥离属票体系细则；「历史票不等于现行指令」要旨保留在 C5 禁止项 | C5 |
| R-DP-040 | 删除 | 项目地图三时点属派生导航工具纪律，非 G 保证；地图生成器仍在包内 | generate-module-map.sh |
| R-DP-041 | 删除 | 复盘规则生命周期属治理运维流程，非 G 保证；吸收面仍在包内 | absorption-trigger.sh |
| R-DP-042 | 删除 | 需求工作三道改为 assessment 决策表（入口分流），存卡即止的要旨归 C1 | C1 ＋ assessment 表 |
| R-RC-001 | 删除 | 白名单提交并入 C4 与 commit 合同职责节 | C4 ＋ commit 合同 |
| R-RC-002 | 删除 | 停止条件与禁令并入 C4/C6 与 commit 合同停止节 | C4、C6 ＋ commit 合同 |
| R-RC-003 | 删除 | 记录翻转另起纯记录提交并入 C4，追加语义归 C9 | C4、C9 ＋ commit 合同 |
| R-RI-001 | 删除 | Scope 边界并入 C10 与 implementation 合同职责节 | C10 ＋ implementation 合同 |
| R-RI-002 | 删除 | 只实现不自审并入 C2/C3 与 implementation 合同禁止面 | C2、C3 ＋ implementation 合同 |
| R-RI-003 | 删除 | 阻塞即停并入 C5 与 implementation 合同停止节 | C5 ＋ implementation 合同 |
| R-RR-001 | 删除 | 只读审查并入 C3 与 review 合同职责节 | C3 ＋ review 合同 |
| R-RR-002 | 删除 | 独立性与证据核验并入 C3 与 review 合同职责节 | C3 ＋ review 合同 |
| R-RR-003 | 删除 | 降级路径与如实记录并入 C3 停止条与 review 合同输出节 | C3 ＋ review 合同 |
| R-RT-001 | 删除 | 路由层零写入并入 C10 与 triage 合同职责节 | C10 ＋ triage 合同 |
| R-RT-002 | 删除 | 派发不越界并入 C10 与 triage 合同职责节 | C10 ＋ triage 合同 |
| R-AT-001 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/adapter-template.md |
| R-CC-001 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/capability-contract.md |
| R-CC-002 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/capability-contract.md |
| R-CC-003 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/capability-contract.md |
| R-CC-004 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/capability-contract.md |
| R-CC-005 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/adapters/capability-contract.md |
| R-CP-001 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-CP-002 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-CP-003 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-CP-004 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-CP-005 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-CP-006 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/complexity-profile.md |
| R-GF-001 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-002 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-003 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-004 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-005 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-006 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-007 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-008 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-009 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-010 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-GF-011 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/governance-format.md |
| R-RP-001 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/read-policy.md |
| R-RP-002 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/read-policy.md |
| R-RP-003 | 保留（包内面，未安装） | 包内协议/适配手册原样保留，不计入安装面字数与规则块指标 | references/protocol/read-policy.md |
