---
id: reference-upgrade
kind: protocol
authority: 权威层级第 4 级（流程规则：已治理仓升级路径手册）；冲突判定上游为 protocol/read-policy.md 权威层级与目标项目 rules/ 三件
lifecycle: Live
read_when: 主流程模式判定为已治理（升级）时；已安装本体系的项目要把落地面同步到包新基线时；用户要求升级、同步包新版或拉新模板时
trigger: 升级模式判别、升级主链步骤、落地面三态分类或漂移处置语义变化
owner: Agent Up 公开包维护者（变更经 Implementation -> Review -> Commit 门禁）
update_policy: 升级主链与三态口径为定稿基线；语义变化须用户确认并同步 SKILL.md 模式判定与主流程
depends_on: agent-up/SKILL.md（主流程与模式判定）；reconcile 规则权威＝目标项目 rules/project.md 生成收敛模式节；对账工具＝scripts/upgrade-check.sh
---
<!-- Input: 目标项目落地面现状（落位脚本、模板生成件、delivery.rules）、包新基线（clone/pull 后的包目录）、既有登记（facts/project/artifacts.yaml）。 -->
<!-- Output: 已治理仓把落地面同步到包新基线的升级主链：盘点落地面、逐件对比三态、差异清单确认、确认后 reconcile 更新、验证与收尾。 -->
<!-- Pos: 已治理仓升级路径手册（与 old-project.md 平级的第三入口：old-project 管"未治理仓补缺"，本手册管"已治理仓跟上新版"）；只承载流程步骤与三态口径，reconcile 与 Record 保护的规则权威在目标项目 rules/project.md（漂移即停、备份可逆、模板升级不得覆盖 Record），本手册照引不复制。 -->

# 已治理仓升级手册

目标项目已按本体系初始化（seed 件在位）后，公开包演进出新版（新脚本、新模板、新条款），升级＝**把仓内落地面有确认地对齐到包新基线**。升级不是重装：既有事实、记录与用户改过的一切照旧，动的只有用户确认要跟的件。

## 1. 判别与盘点（动手前完成）

- 判别：仓内已有 seed 件（`AGENTS.md`＋`rules/` 规则三件＋`facts/project/artifacts.yaml`，含旧布局形态）即升级候选；以用户话语（"升级/同步包新版/拉新模板"）确认进入本手册，不单凭文件存在性自行定轨。
- 盘点落地面（列成清单供第 2 步对比）：
  - **落位脚本**：`rules/implementation/scripts/`（新布局）或 `scripts/`（旧布局）内来自包的件（登记 `generated_from` 指向包内路径的 artifacts.yaml 条目）。
  - **模板生成件**：`rules/assessment.md`、`rules/implementation/discipline.md`、`rules/project.md`、各 README、`AGENTS.md`（登记 `generated_from` 指向包内 `.tmpl`）。
  - **配置面**：仓根 `delivery.rules`（如有）。
  - 包基线：用户 clone/pull 后的包目录（本手册命令里的 `<pkg-dir>`）。

## 2. 逐件对比（三态）

跑 `sh <pkg-dir>/scripts/upgrade-check.sh <pkg-dir> <repo-root>`（全程只读），或人工逐件 `cmp`。三态口径：

| 态 | 判定 | 含义 |
| --- | --- | --- |
| 同步 | 字节一致或节锚点在位 | 无需动作 |
| 落后 | 包内有新版（或新件），仓内为旧版/缺失，且仓内无人工改动迹象 | 可对齐，走第 3 步确认 |
| 漂移 | 仓内文件与包任何已知版本都不一致（人工改过或本地演化） | **停**：报告用户，等裁决（沿用改 / 放弃本地改跟包 / 登记分歧保持现状） |

模板生成件（rules/ 三件等）项目侧可能合法改写过（项目自有条款槽位本就设计为随生长追加），对账器只标"落后"不判漂移——是否采纳新版条款由用户按第 3 步逐件决定，执行体不得整文件覆盖。

## 3. 差异清单确认（确认前零写入）

按 `SKILL.md` 主流程步骤 4 通用规则执行（含现状与目标、四类分组、执行形态与预估）；升级态额外要求：

- **将更新**一列逐件标注来源版本去向（旧拷贝 → 包新基线），让用户看清每一件跟不跟。
- 漂移件逐件给三选项（沿用／跟包／登记分歧），用户逐项裁决后才能进第 4 步。
- 新增件（包有而仓无，如新模板、新脚本）单列，标注其触发条件与生成义务（如 `delivery-rules.tmpl` 生成 `delivery.rules` 归仓根）。

## 4. reconcile 更新（确认后逐件）

- 规则权威＝目标项目 `rules/project.md` 生成收敛模式节（reconcile：漂移即停、写入前备份、幂等），本手册不复制判据，只定顺序：
  1. 先落位脚本（`install.sh --target <repo-root> <门控>`：幂等跳过同步件、复制新增件、漂移即停）；
  2. 再配置面（`delivery.rules` 按模板生成或按 diff 逐节对齐——锚点行逐字匹配，禁手抄）；
  3. 后模板生成件（逐件：备份现件 → 按新模板重生成 → 项目自有条款与【按项目填写】值按现件回填 → 用户确认关键条款 diff）；
  4. 每件更新后重跑该件配套验证（脚本 `sh -n`＋家族夹具；条款件过包对账器）。
- 解析器族升级（内嵌 `dp_load_rules` 的四脚本）按 `old-project.md` §3 dp_load_rules 引擎件行同步六 hunk，或整件对齐包新基线后核 `# dp-parser` 注记一致。
- Record 类产物（账本、索引、运行记录）与用户事实**不在升级面**：模板升级不得覆盖（R-DP-003 口径），永不触碰。

## 5. 验证与收尾

- 全套验证：包自检 `sh <pkg-dir>/scripts/check-package.sh`；仓侧 gate（落位的 check-artifacts/check-stale-claims/check-gates 族）；`upgrade-check.sh` 复跑确认残余差距清零或仅剩用户裁决保留项。
- 收尾报告按 `SKILL.md` 步骤 9，额外列：更新件清单（旧→新）、漂移件裁决结果、登记面同步情况（artifacts.yaml 条目 `generated_from`/update_policy 括注随更新件刷新）。

## 6. 包基线获取

包基线＝公开仓最新 main（`git clone`/`git pull` 更新包目录）；更新了什么读包根 `CHANGELOG.md`（波级条目）。未 pull 的旧包目录不可作升级基线——先更新包，再谈升级仓。
