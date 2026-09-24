<!-- Input: `check-package.sh` 的十四项检查实现（清单数据驱动，票 57/58/59）与 SPEC-06 §5、票 09/11 的例外登记事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；票 12（SPEC-06 §7）11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）；票 19（REQ-20260904-010）`check-stale-claims.sh` 的两模式、登记表条目与退出码实况；票 37（拆票计划 C 组②）道脚本改造事实——flips 索引条目口径（单写 docs/issues/index.json → 票正文 Status 投影打印件 → 生成器投影再生）、微账本 `docs/agent/micro.jsonl` JSON 行、S3 投影 vs 索引比对与 S1-1e 缺口消除、`generate-progress.sh` 入包（与本仓根 `scripts/` 基线 cmp 一致）；票 43 语言登记表 Rust 扩展事实（mod 文件边存在性核验＋use 路径表达式原串，四语言）；票 44 引擎表驱动化事实（语言知识外置 `module-map.rules`，引擎通用管线零语言专名，四语言边集逐边回归＋哑语言规则行产边实证）；票 45 七语言批量扩展事实（Go/Java/C#/Ruby/PHP/Swift/Kotlin 规则行＋fixture 回归，覆盖语言十一种，零引擎改动）；票 47（ticket-ops.sh 入包采纳：与本仓根 `scripts/` 基线 cmp 零差异复制、专节与落位口径——记录层标配不门控快道，包内不运行声明）；票 48（检查项 8 脚本必需件存在性守卫：六 `.sh`＋`module-map.rules`＋`scripts/README.md` 逐一存在性核对，fail-closed 指名缺失件，计数联动七项→八项）；票 49（`test-record-layer.sh` 记录层回归 harness 落位：票 41～45/47 六票 fixture 沉淀为常驻自检工具，缺省自测同目录包内脚本、mktemp 夹具 trap 清理、预期值独立重建、注入自检）；票 56（安装政策单源化：`install-policy.rules` 政策数据表＋`install.sh` 安装脚本落位——安装政策映射唯一承载点改为外置数据、引擎零专名，检查 8 清单扩为 10 件）；票 57（包清单数据化：`package-manifest.rules` 数据单源落位——入口文件/脚本必需件/模板清单/短码登记/platform 枚举唯一承载点，check-package.sh 检查 1/5/8 改读数据、新增检查 9（scripts/README.md 成员表↔数据一致）/10（短码使用⊆登记）/11（platform 枚举登记处↔数据一致），口径差定谳＝test-record-layer.sh 定为必需件 kind 标 test-harness）；票 58（小断言打包：检查 11→13——检查 12 规则块体模糊措辞扫描（词表与行级豁免外置 `package-manifest.rules` vague-words/vague-exemptions 节，依据 R-GF-010，引擎零词表硬编码）、检查 13 镜像脚本与仓根同名件 cmp（mirrors 节登记，仓根无 scripts/ 或无同名件静默跳过）；`check-append-only.sh` Record 只追加守卫新建（changes.jsonl/micro.jsonl 尾部追加前缀语义＋progress.md 冻结零 diff，承接票 54 候选 C3 口径）；lane-commit.sh 微道预检两断言（白名单 ≤3、改动集零新建零删除）；harness 扩为五 suite（新增 append-only suite，check-package 套件断言随 12/13 增））；票 59（对账＋能力一致性：检查 13→14——检查 14 能力映射一致性（九基元名单与检查目标外置 `package-manifest.rules` capability-primitives 节，基元名自 capability-contract.md §2.1 权威表现场提取，引擎零基元名硬编码；三角色 .tmpl 声明行＋五适配文件对照表逐一双向全等核验，锚点失效 exit 2）；`check-artifacts.sh` 治理产物对账器新建（artifacts.yaml 登记目标存在性＋受管口径登记覆盖双向对账，受管口径与豁免落数据块）；harness 扩为六 suite（新增 check-artifacts suite，check-package 套件断言随 14 增））；票 60（规则索引：模板 `development-process.md.tmpl` 新增 §16 规则索引节（49 行三列表＝47 定义＋2 外定义标注，节头三件＝投影声明＋受控三值定义＋诚实性上限声明），检查 14→17——检查 15 索引 ID 集合与包内规则块 grep 并集全等（外定义行豁免比对但须显式标注外定义标记词，未标注算漏行）、检查 16 机制列受控词表（词表外置 `package-manifest.rules` mechanism-vocab 节，引擎零词表硬编码）、检查 17 机械行点名脚本存在且在册＋检查项号不超界；`check-append-only.sh`/`check-artifacts.sh` 补登记清单 scripts 节（10→12 件，检查 17 在册口径的联动缺口）；check-package 套件断言随三查增）；票 65（S4 计数漂移哨兵：登记表 S1-S3→S1-S4——S4-① README「任务票 NN；」锚点行数↔index 任务条目数相等断言（ticket-ops 双写锁定面漂移检测）、S4-②「N～M 共」「共 N 量词」计数模式扫描（STALE-prone 指名 file:line 计入过期断言计数，gate exit 1 / session 只警告）；扫描面排除三类历史/生成面（docs/progress.md 冻结档案、docs/changes.md 只追加账本、docs/architecture/generated 生成投影——协调层 2026-09-21 裁决 O3，既排 docs/issues/*.md 票面、docs/agent/runs/、docs/progress-current.md 保留）；豁免表显式实装、空表交付＝现行面全数字免费；输出格式增 STALE-prone 行与登记计数 3→4）；票 72（delivery 配置：`export-payload.sh` 公开载荷导出单命令新建（delivery.rules 驱动六步、--dry-run、永不 force，检查 8 清单 12→13 件）；check-stale-claims S1/S2 配置点亮（dp_stale_lit、remote 名/包前缀/本地分支读仓根 delivery.rules、SKIP 行与汇总登记数动态化）；check-artifacts 校准豁免迁移（docs/architecture/generated/ 自数据块迁入 delivery.rules calibration 节）；harness 扩为七 suite（新增 stale-claims 套件，check-package/check-artifacts 套件断言随动））；票 88（存量清算：`run-record.sh`/`ticket-grade.sh` 入包采纳——与本仓根同名件 cmp 零差异复制，先包后仓包为基准仓侧为镜像，检查 8 清单 13→15 件、检查 13 mirrors 2→4 对；成员行登记，用法承载归脚本 `-h` 与头部注释，本目录不设专节）。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、十七项检查说明（清单数据驱动）、包清单数据表格式、易腐断言扫描器两模式与登记表说明、投影生成器用法与退出码、模块地图生成器用法与语言登记表、道脚本收尾行为（索引单写机制＋微道预检）、票务运维脚本三子命令用法与落位口径、安装脚本用法/退出码与安装政策数据表格式、Record 只追加守卫用法与守卫口径、治理产物对账器用法与受管口径/豁免维护规则、输出格式、退出码与维护联动规则。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。本目录同时是道脚本与票务运维脚本的安装源：安装政策（哪些脚本在什么门控下落位、每件复制基线路径与登记 lifecycle 值）以数据文件 `install-policy.rules` 为唯一承载点（外置数据、引擎零专名，先例 `module-map.rules`），复制动作经 `install.sh` 执行——目标项目用户确认启用分级交付道快道时以 `--fast-lane` 启用，采用任务票体系（`docs/issues/` 目录创建）时以 `--ticket-ops` 启用（两套独立门控，启用判定是用户决策，脚本只承接已确认的复制动作），落位与登记口径见 `../SKILL.md` 主流程步骤 5 与 `../references/templates/development-process.md.tmpl` §12.5，脚本用法/退出码/数据格式见下文专节。复制不改变参数语义——`[repo-root]` 缺省仍取当前目录所在 Git 仓库顶层（`generate-progress.sh` 缺省取脚本所在目录的上一级），与落位后用法一致。`generate-progress.sh` 与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致，两处同源演化须互为镜像并登记差异。`ticket-ops.sh` 包内文件与本仓根 `scripts/ticket-ops.sh` 基线 cmp 零差异（票 47 入包核对）；`run-record.sh` 与 `ticket-grade.sh` 包内文件与本仓根同名件基线 cmp 零差异（票 88 存量清算入包采纳——先包后仓，包自此为基准、仓侧为镜像，零语义迁移）。四对同源演化须互为镜像并登记差异——镜像一致性自票 58 起由 `check-package.sh` 检查 13 常驻机械核对（比对对＝`package-manifest.rules` mirrors 节登记的包侧/仓根同名件，选定 manifest 新节承载而非引擎内注记；仓根无 `scripts/` 或无同名件静默跳过，消费项目语义）。包内落位基线脚本不运行：`ticket-ops.sh` 缺省 repo-root 取脚本所在目录的上一级，包内位置（`agent-up/scripts/`）误运行会错根，落位到目标项目 `scripts/` 后语义才正确；`install.sh` 为包侧安装器、只在包内语境运行（不落本仓 `scripts/` 镜像），自带包内误运行守卫——`--target` 解析后含 `agent-up/SKILL.md` 或 `SKILL.md`、或等于本脚本所在目录即拒绝（exit 1）；`check-append-only.sh` 为包侧分发工具，落位消费项目后对其记录层文件运行（本仓 worktree 实跑亦合法，见专节）。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、十七项检查、包清单数据表格式、输出格式、退出码与维护联动规则。 |
| `check-package.sh` | 包完整性检查 | 按十七项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004；票 57 起检查 1/5/8 清单自 `package-manifest.rules` 数据读取，检查 9/10/11 以数据为比对基准；票 58 新增检查 12 规则块体模糊措辞扫描、检查 13 镜像脚本与仓根同名件 cmp；票 59 新增检查 14 能力映射一致性；票 60 新增检查 15 模板规则索引与规则块全集全等、检查 16 索引机制列受控词表、检查 17 机械行点名出处存在）；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
| `check-append-only.sh` | Record 只追加守卫 | 守卫记录层两类写入语义（票 58；承接票 54 候选 C3「Record 行级保护」口径）：`docs/changes.jsonl` 与 `docs/agent/micro.jsonl` 只追加账本（HEAD 旧 blob 须为新内容前缀，中间插入/改写历史行/截断/删除即 FAIL 指名文件与首个违规行号）、`docs/progress.md`（未迁移仓）及其迁移后继 `docs/archive/progress.md`（票 87）冻结历史档案（任何 diff 即 FAIL；迁移窗口按 HEAD 旧路径承继基线核对）；文件不存在跳过（懒创建语义）、无 Git 基线（无 HEAD）WARN 退出 0（票 49 先例）；POSIX sh、零外部依赖（仅 POSIX 标准工具与 Git 只读子命令）、fail-closed。可作 verify 命令加入门禁清单。详见下文专节。 |
| `check-artifacts.sh` | 治理产物对账器 | 治理产物登记与实物双向对账（票 59；兑现 R-DP-007 逐件登记核对）：正向＝`docs/agent/artifacts.yaml` 每条登记 path 目标必须存在（缺失 FAIL 指名条目；数据块懒创建面登记暂缺 SKIP），反向＝数据块受管口径内文件必须被登记（精确/glob/目录聚合覆盖）或命中豁免规则（未登记 FAIL 指名路径，豁免命中不报）；受管口径与豁免规则落脚本内对账数据块（引擎零目录硬编码，票 59 D2 定谳）；登记解析破坏 exit 2 不产生部分结论；POSIX sh、零外部依赖（仅 POSIX 标准工具）、fail-closed。详见下文专节。 |
| `check-stale-claims.sh` | 易腐断言扫描器 | 登记表驱动的高流转状态句扫描（REQ-20260904-010 / 票 19；票 37 S3 改投影 vs 索引比对、消 S1-1e 恒触发缺口；票 65 S4 计数漂移哨兵：README 锚点行数↔index 条目数相等断言＋「N～M 共」「共 N 量词」计数模式扫描）；票收口拦截（gate，发现过期断言 exit 1）与会话启动警告（session，恒 exit 0）两模式；POSIX sh、全程只读、零外部依赖。详见下文专节。 |
| `check-gates.sh` | 快道门禁核对器 | 分级交付道快道的只读门禁核对（REQ-20260904-011 / 票 26）：工作区实际改动 ⊆ 白名单逐项比对 + 按清单重跑验证命令并记录退出码；POSIX sh、严格只读、零外部依赖。详见下文专节。 |
| `lane-commit.sh` | 快道收尾脚本 | 分级交付道快道的合同驱动收尾（REQ-20260904-011 / 票 26；票 37 单写机制改造；票 58 微道预检）：门禁 → 白名单产品提交 → 索引单写（`docs/issues/index.json` 票状态真相源）→ 票正文 Status 投影打印件回写 → User Review Checkpoint 追加或微账本（`docs/agent/micro.jsonl`）落行 → 生成器投影再生并 `--check` 核对 → 记录提交（两段式，R-RC-003）；micro 道预检两断言（白名单 ≤3 条目、改动集零新建（??）零删除（D），违者 exit 1，user-review 道不受限）；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-progress.sh` | 现役状态投影生成器 | 自 `docs/issues/index.json`（票状态真相源，一条目一行）生成 `docs/progress-current.md` 现役状态投影（Derived，生成器独占写；票 33 §5.1.4 / 票 35 落位、票 37 入包）；`--check` 为 dry-run 一致性核对；快道收尾由 `lane-commit.sh` 在索引单写后调用；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-module-map.sh` | 模块地图生成器 | 静态导入行提取生成 `<root>/docs/architecture/module-map.json` 检索索引（票 30 拍板方案 A / 票 42 首版 / 票 43 Rust 扩展 / 票 44 表驱动化 / 票 45 七语言批量扩展）：Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌（R-DP-015 算法，输入排除本图自身）；repo-root 参数化（缺省 git toplevel）；引擎为通用规则解释器（加载规则表→发现源码→匹配捕获→策略产边→存在性过滤→组装 JSON），语言知识外置 `module-map.rules`（每语言一行，引擎零语言专名，加语言＝加规则行零引擎改动）；POSIX sh、无 jq/python（stat 与 SHA-256 工具依赖声明见专节）、fail-closed。详见下文专节。 |
| `module-map.rules` | 模块地图语言规则表 | `generate-module-map.sh` 的语言提取规则唯一承载点（票 44 表驱动化）：每语言一行 `mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>`；strategy 枚举 extension-map（扩展名 glob 语言绑定）/unresolved-node（未解析节点引用直出）/module-path（模块路径文本直出）/direct-file（声明文件候选边＋存在性过滤）；编码语义见本表头部注释与下文专节；规则表缺失或不合预期时引擎 exit 2（fail-closed）。 |
| `install-policy.rules` | 安装政策数据表 | 安装政策映射唯一承载点（票 56 单源化；先例 `module-map.rules`：外置数据＋引擎零专名）：门控定义行 `ip_gate <gate> <flag> <说明>` 与每文件×每门控行 `ip_file <pkg-rel-path> <lifecycle> <gate> <说明>`（包内复制基线路径、登记 lifecycle 值、所属门控与角色说明；同一文件属多门控逐门控各一行，引擎按文件路径去重选取）；`install.sh` 加载时结构校验（字段数、token/flag/lifecycle/路径形态、(文件,门控) 唯一、同文件 lifecycle 一致、未定义门控引用、零文件门控），任一不合预期 exit 2（fail-closed）。 |
| `package-manifest.rules` | 包清单数据表 | 包结构清单唯一承载点（票 57 单源化；票 58/59/60 扩节；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）：十节行式数据——必需入口文件（`pm_entry`）、脚本必需件（`pm_script`，kind 区分普通脚本/规则表/test-harness）、.tmpl 模板清单（`pm_template`）、规则块短码登记（`pm_shortcode`）、platform 枚举（`pm_platform`）、模糊措辞词表（`pm_vague_word`）与行级豁免（`pm_vague_exempt`，理由必填）、镜像脚本（`pm_mirror`）、能力基元名单与检查目标（`pm_capability`/`pm_capability_authority`/`pm_capability_target`，票 59）、规则索引执行机制受控词表与外定义标记词（`pm_mechanism`/`pm_mechanism_marker`，票 60）；`check-package.sh` 加载时结构校验（字段数、路径/kind/短码/platform/词/行号/文件名形态、各节内跨行不重复），任一不合预期 exit 2（fail-closed）；检查 1/5/8 清单与计数、检查 9/10/11/12/13/14/15/16/17 比对基准全部自本表读取，引擎零文件名零短码零枚举值零词表零基元名清单零机制词表。维护规则与行格式见下文专节。 |
| `ticket-ops.sh` | 票务运维脚本 | 协调层票务面单入口（票 41 本仓交付 / 票 47 入包采纳）：`open`（开票：索引新增条目 status=ready＋issues-README 目录清单追加行＋账本追加行；NN 段查重——同 NN 异 slug 与畸形 id 拒开；open 本体 schema 校验＋定级/优先级理由非空断言）／`take`（领取：status=in_progress）／`flip`（状态翻转：状态机任意合法值）三子命令，索引与 README 锚点整行/单 token 机械改写，收尾调用 `generate-progress.sh` 再生 `docs/progress-current.md` 并 `--check` 核对；校验先于写入、fail-closed（索引一条目一行排版破坏、锚点不唯一、账本行不合键序即停止不写）；POSIX sh、无 jq（open 本体 schema 校验另用 python3 标准库）。详见下文专节。 |
| `run-record.sh` | run record 生成器 | run record 生成与封存单入口（票 55 本仓交付 / 票 88 存量清算入包采纳）：`new` 生成十三字段骨架并自动填机械字段、内容字段留【待填：…】由执行体填，`seal` 完整性校验（usage 五子字段必备，缺项 fail-closed）全过后按当前仓库状态刷新机械字段，`stats` 只读聚合 usage 用量报表；`seal`/`stats` 依赖 python3 标准库（不引第三方），SHA-256 与 stat 工具按序探测、缺失即 exit 2；fail-closed。包内文件为本仓根同名件基线 cmp 零差异采纳（先包后仓，包为基准、仓侧为镜像），随 ticket-ops 门控复制（登记见 `install-policy.rules`）；用法/退出码见脚本 `-h` 与头部注释。 |
| `ticket-grade.sh` | 定级建议器 | 票定级建议器（票 78 本仓交付 / 票 88 存量清算入包采纳）：读任务票 JSON 机械计算可数判据（承重验收条数、行为/契约件模块数、高风险面关键词、公共接口证据与微道承重可数面），输出各 C 级命中条件、C0-C3 建议、微道资格预审与逐票分歧账；建议不裁决（输出只写「建议/命中/预审」，不写「必须/定级为」，分歧以 Triage 为准）；python3 标准库内嵌、全程只读零写入、fail-closed。包内文件为本仓根同名件基线 cmp 零差异采纳（先包后仓，包为基准、仓侧为镜像），随 ticket-ops 门控复制（登记见 `install-policy.rules`）；用法/判据口径见脚本 `-h` 与头部注释。 |
| `install.sh` | 安装脚本（包侧安装器） | 安装政策单源化的执行引擎（票 56）：按启用门控自查同目录 `install-policy.rules` 得复制集合，逐件 cp 自包 `scripts/` 至 `<target>/scripts/` 并 cmp 核验字节一致；预检先于复制（源缺失/目标漂移即停，零半套）；已存在且字节一致的同名件幂等跳过，不一致即停（reconcile 纪律不覆盖）；目标 `scripts/` 缺失时创建并输出 README 生成提示行（README 生成归执行体）；末尾输出登记建议块（每复制件一行 artifacts.yaml 十三字段建议值＋generation manifest 提示），不代写目标治理文件；POSIX sh、零外部依赖、fail-closed；引擎零脚本名零门控专名（加门控＝加规则行零引擎改动）；包侧工具，不落本仓 `scripts/` 镜像。详见下文专节。 |
| `export-payload.sh` | 公开载荷导出单命令 | delivery.rules 驱动的六步导出（票 72；命令面权威＝票 69 设计 §3）：split→树比对（全新 mktemp 展开即用即删）→导出树 check-package→ff 断言（远端 target 头非新导出头祖先＝污染停手，报错文案照设计逐字）→push（裸 push）→ls-remote 复核；`--dry-run` 执行步骤 1～4 零远端写零本地分支写；永不 force（不内建任何改写远端历史的路径）；导出形态（前缀/远端/分支）读仓根 `delivery.rules` payload 节，未声明即拒跑 exit 2；POSIX sh。详见下文专节。 |
| `test-record-layer.sh` | 记录层回归 harness | 六票（41～45/47）fixture 沉淀的常驻自检工具（票 49；票 58/59 扩 suite）：suite 集合与权威枚举见下文专节（`--suite` 参数化，缺省 all），一条命令回归记录层全链，逐项 PASS/FAIL＋计数，任一失败 exit 非零；缺省自测同目录包内脚本（对被测脚本只以显式 mktemp 夹具根/包根参数驱动，与 ticket-ops.sh「包内不运行」口径不冲突）；POSIX sh、无 jq；open 本体校验路径依赖 python3，缺失即 exit 2；夹具 trap 清理、仓库零写入。详见下文专节。 |
| `scenario-checklist.md` | 场景验收清单 | SPEC-06 §7 发布前 11 条场景的验收边界、逐条执行结果与证据指针（票 12 / R-06-008）；S1-S9 为模板语义静态核对、S10 记 check-package.sh 实跑与临时副本负例及 `deferred-to-13` 条件项、S11 记 `N/A + reason`（未测量）；包内容变化后按本清单复验。 |

## 用途与用法

对 `agent-up` 公开包做发布前核对与包内容变化后自查：十七项检查全部通过才可宣称包完整；失败项逐条修复或报告，不为通过检查篡改包内容（R-06-004）。

```text
sh scripts/check-package.sh [package-root]
```

- 无参数：以脚本所在目录的父目录为包根（在本包内运行时，检的就是本包）。
- 带参数：以第一参数为包根（对 subtree 导出目录或临时目录副本复跑时使用）。
- `-h` / `--help`：打印用法。
- 脚本只读：除向 stdout/stderr 打印外无任何写操作；无网络依赖（不出网、无下载行为）。

## 检查项（十七项，清单数据驱动）

包结构清单的机器真相是数据文件 `package-manifest.rules`（十节，行格式与维护规则见下文专节）：检查 1/5/8 的清单与计数自数据读取，检查 9/10/11/12/13/14/15/16/17 以数据为比对基准核对登记面与使用面；本表为检查口径的人读说明，与数据表冲突时以数据表为机器真相。

| # | 检查 | 实现 |
| --- | --- | --- |
| 1 | 必需入口存在 | 清单 `entry-files` 节逐行 `test -f`（现 16 件：包根 `SKILL.md`、`README.md`、`LICENSE`；`references/` 下目录 README 与手册、`schemas/` 两 JSON——逐件名单见数据表，票 57 起不再硬编码于引擎）；任一缺失即 FAIL 并逐件指名（fail-closed）。 |
| 2 | `SKILL.md` frontmatter 为 `name: agent-up` | 首行 `---` 与闭合 `---` 之间存在 `name: agent-up` 行；frontmatter 缺失或未闭合判失败。 |
| 3 | 包内无旧标识残留 | `grep -rn` 全包扫描旧 Skill 标识字面量（本包改名前的原 Skill 名），零命中为通过；扫描范围含本目录。 |
| 4 | 无绝对路径与根治理引用 | `grep -rn` 扫描用户主目录绝对路径前缀（/Users 或 /home，带尾斜杠匹配）与根治理相对引用字面量（`../` 后接 docs 或 .zcode）。按票 09/11 结论，模板内 `../specs/` 等兄弟路径属目标项目生成语义，不在本项口径。 |
| 5 | 模板清单一致（数据↔磁盘↔manifest 双向；票 57 数据驱动） | `references/templates/` 下实际 `.tmpl` 与清单 `templates` 节集合一致（数量相等、互不缺多），且数据每件在 `templates/README.md` manifest 目录清单节有登记行、manifest 登记的每个 `.tmpl` 都在数据内——manifest 表＝人读投影，数据＝机器真相，双向漂移即 FAIL。 |
| 6 | 文本契约头齐全 | `*.md` 与 `*.tmpl` 在检测窗口内含 `Input:`/`Output:`/`Pos:` 三行：无 frontmatter 的文件取前 5 行，首行为 `---` 的文件取 frontmatter 结束后的 5 行（frontmatter 未闭合判失败）。例外：`artifacts-yaml.tmpl` 以 YAML `#` 注释承载（前 5 行含 `# Input:`/`# Output:`/`# Pos:`，登记见 `templates/README.md`）；`LICENSE` 与 `schemas/*.json` 不属扫描范围（JSON 以 `$id`/`title`/`description` 承载导航元数据，例外登记见 `schemas/README.md`）。 |
| 7 | 根治理文件不在包内 | 包根不存在 `AGENTS.md`（文件）、`docs/`（目录）、`.zcode/`（目录）。 |
| 8 | 脚本必需件存在（票 48；票 56 扩清单；票 57 数据驱动；票 60 补登记 12 件口径；票 88 存量清算 13→15 件） | 清单 `scripts` 节逐行 `test -f`（现 15 件：`scripts/` 下十二 `.sh`（check-gates、lane-commit、check-stale-claims、generate-progress、generate-module-map、ticket-ops、run-record、ticket-grade——后两件票 88 入包采纳；install、check-append-only、check-artifacts、export-payload）、两规则表（`module-map.rules`、`install-policy.rules`）、`test-record-layer.sh`——票 57 口径差定谳定为必需件，kind 标 `test-harness`）；任一缺失即 FAIL 并逐件指名缺失件（fail-closed，不因部分存在而放宽）。增删包内脚本成员须同步数据表 `scripts` 节。 |
| 9 | scripts/README.md 成员表与数据 scripts 节一致（票 57 新增） | 双向口径：①清单 `scripts` 节每件都在成员表登记（表＝人读投影不得漏登必需件）；②成员表登记的每件都是 `scripts/` 下实际文件（表与实物不漂移）。成员表提取锚点＝首列 `名字/地位/功能` 表头行。 |
| 10 | 规则块短码使用均在登记内（票 57 新增） | 扫描包内全部 `*.md` 与 `*.tmpl`（同检查 6 文件面）提取规则块 ID `R-<短码>-<三位序号>` 的两字母前缀，与清单 `shortcodes` 节比对：使用⊆登记；SPEC 规格号（`R-02-001` 形态，数字段）不落入提取模式。短码全集以 grep 实测为准（现 16 个），新增短码先登记数据表再使用。 |
| 11 | platform 枚举登记与数据一致（票 57 新增；逐处全等） | 各登记处值集合与清单 `platform-enum` 节逐处全等（任一处缺值/多值/改值即不一致，FAIL 行按行号指名漂移处）：`references/templates/artifacts-yaml.tmpl` platform 字段注释区（锚点＝`当前已知集合：` 标记）、`references/adapters/capability-contract.md` 内每个「已知集合」句（frontmatter 与 §2.5 各一处，各自单独比对，不并集）；提取锚点为登记标记文本，值集合以数据为权威。 |
| 12 | 规则块体无模糊措辞（票 58 新增；兑现 R-GF-010 自称可静态扫描句） | 词表外置清单 `vague-words` 节（字面匹配非正则，引擎零词表硬编码）；扫描窗口＝包内全部 `*.md` 与 `*.tmpl` 的 `R-<短码>-NNN` 规则块体（块头行起至下一标题行止，块头本身不扫），排除「解释与例外」节（标题含该标记起至下一标题止）与各 README 文件（叙事面）；manifest 自身词表行为 `.rules` 数据文件不在扫描文件面。命中行无法安全换词的经 `vague-exemptions` 节登记行级豁免（路径＋行号＋理由，理由必填）；登记行无命中即失效豁免 FAIL（防行号漂移静默失效）；awk 扫描异常即 exit 2（fail-closed，扫描器失效不得当作零命中放过）。 |
| 13 | 镜像脚本与仓根同名件一致（票 58 新增） | 比对对＝清单 `mirrors` 节登记（对应关系＝包侧 `scripts/<名>` 与包根父目录仓根 `scripts/<名>` 同名件，现状四对：generate-progress.sh/ticket-ops.sh/ticket-grade.sh/run-record.sh——后两件票 88 存量清算采纳），逐对 `cmp`；仓根无 `scripts/` 或无同名件静默跳过（无输出行；消费项目语义，`--pkg-root` 参数化语境同样跳过）；一致 PASS、差异 FAIL 指名文件。 |
| 14 | 能力映射一致（票 59 新增） | 名单＝清单 `capability-primitives` 节九基元名（自 `capability-contract.md` §2.1 权威表现场提取，引擎零基元名硬编码）；①权威表＝`pm_capability_authority` 登记文件，窄锚点「### …能力基元清单」标题下九行表首列提取，与名单双向全等（缺/多/改名即 FAIL 指名权威文件）；②检查目标＝`pm_capability_target` 节逐一核验（三角色 .tmpl 声明行 kind=decl 取 `required_capabilities（运行时）` 行反引号名集合、五适配文件 kind=table 取「| 能力基元 |」对照表首列名集合）——目标名集合与登记预期名单双向全等：注入未登记名（不在名单）／删名（缺少）／改名（未登记＋缺少并报）即 FAIL 指名文件；预期名单经载入校验逐名 ⊆ 名单且八目标并集 ⊇ 名单。表解析锚点失效即 exit 2（fail-closed 不静默过，检查 11 同款）；targets 相对 `$pkg_root` 解析，`--pkg-root` 复制落位语境与镜像检查同口径。 |
| 15 | 模板规则索引与规则块全集全等（票 60 新增） | 全集＝清单 `templates` 节全部 `.tmpl` 的规则块 ID（`R-<短码>-NNN`）grep 并集去重（索引宿主文件先排除表行自身再提取——索引表在扫描面内，表行加什么 ID 全集就含什么 ID，不排除则「多出全集外 ID」方向退化失效）；索引表＝`references/templates/development-process.md.tmpl` 「## 16. 规则索引」节内三列表行（窄锚点，先例检查 11/14；锚点缺失、零表行、行格式不合预期、ID 跨行重复均 FAIL）。双向全等：索引多出全集外 ID（加行）与全集 ID 缺索引行（删行/漏行）均 FAIL 指名 ID。外定义行＝短码登记 owner 不在 `references/templates/` 下的 ID（经清单 `shortcodes` 节数据判定，引擎零 ID 硬编码）：豁免一句话内容比对，但机制列必须显式标注外定义标记词（清单 `pm_mechanism_marker`），未标注算漏行 FAIL（豁免显式非静默）。索引变更先改本表再动规则块：反向（先加规则块后补索引）由本检查拦截。 |
| 16 | 索引机制列受控词表（票 60 新增） | 词表＝清单 `mechanism-vocab` 节受控三值（机械/门禁/约定）＋外定义标记词（`pm_mechanism_marker` 恰一行），引擎零词表零标记词硬编码。机制列语法：受控值开头，可跟全角括注「（…）」（出处/说明，括注内容不做词表核验，禁嵌套括号与全角分号），可跟「；外定义（…）」附加段（首段须为机制受控值，附加段须为词表值）；每段剥离括注后须为词表值，未登记值（含 ASCII 括号残留、空段、空列）即 FAIL 指名 ID 与值。BSD awk 对多字节 index/substr 字节/字符位语义混合不可靠，引擎先经 sed 把全角括号/分号规范化为 ASCII 再解析（字面替换为字节级，可靠）。 |
| 17 | 机械行点名出处存在（票 60 新增） | 机械行（机制列首段＝受控值「机械」——引擎语义锚点，词表成员资格仍以清单为权威）须在括注内点名出处：①脚本名（`*.sh`）必须真实存在于包 `scripts/` 且在清单 `scripts` 节登记（缺一即 FAIL 指名 ID 与脚本，票 60 借此补登记 check-append-only.sh/check-artifacts.sh）；②检查项号（「检查 N」）必须 ≤ 当前检查总数（引擎自述，现 17）。零脚本零检查项的机械行判缺点名出处 FAIL。仅机械行核验，门禁/约定行括注不做存在性核对。 |

## 输出格式

```text
PASS: <编号> <描述>
FAIL: <编号> <描述> — <单行详情>
FAIL: <编号> <描述> 详情：
  <多行详情逐行缩进两空格>
check-package: PASS
```

- 十七项检查逐项输出一行 PASS 或 FAIL（检查 13 例外：仓根无 `scripts/` 或无同名件时静默跳过，无输出行）；任一失败时结尾输出 `check-package: FAIL（N 项未通过，共 17 项）`，全部通过时结尾输出 `check-package: PASS`。
- FAIL 详情为可定位信息：文件清单、命中行（`路径:行号:内容`）或计数差异。

## 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 十七项检查全部通过。 |
| 1 | 存在未通过项（逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等；数据校验 fail-closed，不产生部分结论）。 |

## package-manifest.rules（包清单数据表）

包结构清单唯一承载点（票 57 单源化；票 58/59/60 扩节；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）。`check-package.sh` 启动时 source 本表（与脚本同目录），检查 1/5/8 的清单与计数、检查 9/10/11/12/13/14/15/16/17 的比对基准全部自数据读取，引擎零文件名零短码零枚举值零词表零基元名清单零机制词表——加成员、加短码、加 platform 值、加措辞词、加豁免、加镜像、加能力基元/目标、加机制词表值＝加一行数据＋改对应实物，零引擎改动。注意：引擎按自身所在目录加载本表（与脚本同目录），对包副本核对时以副本自带引擎＋副本 manifest 才能读到副本数据（harness 豁免负例即此口径）。

### 行格式（十节）

| 指令 | 字段数 | 语义 |
| --- | --- | --- |
| `pm_entry <pkg-rel-path>` | 1 | 必需入口文件，包根相对路径（检查 1）。 |
| `pm_script <pkg-rel-path> <kind> <说明>` | 3 | 脚本必需件，须 `scripts/` 前缀加单段文件名（检查 8）；`kind` ∈ `script`（普通脚本）/`rules`（规则表）/`test-harness`（回归 harness）——票 57 口径差定谳：`test-record-layer.sh` 定为必需件，kind 标 `test-harness`。 |
| `pm_template <basename>` | 1 | `.tmpl` 模板文件名（检查 5，与 `references/templates/README.md` manifest 表双向）。 |
| `pm_shortcode <CODE> <owner>` | 2 | 规则块两字母短码与其所属文件包内相对路径（检查 10：使用⊆登记；与 `references/` 各目录 README 短码登记面同源）。 |
| `pm_platform <value>` | 1 | platform 枚举值（检查 11，与 `artifacts-yaml.tmpl` 注释区、`capability-contract.md` 登记处一致）。 |
| `pm_vague_word <词>` | 1 | 模糊措辞词表项（检查 12），字面匹配非正则；词表依据＝`references/protocol/governance-format.md` R-GF-010 原文列举（现六词），初版 ≥5 词。 |
| `pm_vague_exempt <pkg-rel-path> <行号> <理由>` | 3 | 检查 12 行级豁免：命中行无法安全换词（只换词不换义不可行）时登记，理由必填；登记行无命中即失效豁免 FAIL，行号漂移须复核更新或删除登记。 |
| `pm_mirror <filename>` | 1 | 镜像脚本单段文件名（检查 13）：包侧 `scripts/<filename>` 与包根父目录仓根 `scripts/<filename>` 同名件逐对 cmp；仓根无 `scripts/` 或无同名件静默跳过。 |
| `pm_capability <name>` | 1 | 能力基元名单项（检查 14）：九基元名自 `capability-contract.md` §2.1 权威表现场提取登记，不自造基元；小写 token，跨行唯一。 |
| `pm_capability_authority <pkg-rel-path>` | 1 | 能力权威表文件（检查 14），跨行恰一行：引擎以窄锚点「### …能力基元清单」标题定位其表，首列提取与名单双向全等，锚点失效 exit 2。 |
| `pm_capability_target <pkg-rel-path> <kind> <预期名单>` | 3 | 检查 14 逐一核验目标：`kind` ∈ `decl`（角色合同 `required_capabilities（运行时）` 行，提取反引号名集合）/`table`（适配文件「| 能力基元 |」对照表，提取首列名集合）；预期名单（逗号分隔）为该目标现行声明面/对照表现场转录，载入校验逐名 ⊆ 名单且全部目标并集 ⊇ 名单；目标名集合与预期名单双向全等，多/少/改名即 FAIL 指名文件。 |
| `pm_mechanism <值>` | 1 | 规则索引执行机制受控值（检查 16）：模板 `development-process.md.tmpl` §16 机制列取值 ⊆ 本节值集；受控三值＝机械（点名脚本/检查项现役断言在管）/门禁（阶段 checkpoint 卡）/约定（靠执行体自觉），语义见模板 §16 节头；值须非空单 token，跨行唯一。 |
| `pm_mechanism_marker <标记词>` | 1 | 外定义标记词（检查 15/16），跨行恰一行：模板 §16 中定义于模板外手册的规则块行须在机制列显式标注本标记词，未标注算漏行（豁免显式非静默）。 |

### 结构校验（fail-closed）

引擎加载时逐行核验，任一不合预期 exit 2，不产生部分结论：字段数恰如上表（字段内禁制表符）；路径禁前导斜杠、空白与 `..` 段，`pm_script` 须 `scripts/` 前缀单段名，`pm_template` 须单段 `.tmpl` 名，`pm_shortcode` 短码两字母大写且 owner 须 `references/` 前缀，`pm_platform` 值须小写 token，`pm_vague_word` 词须非空无空白，`pm_vague_exempt` 行号须正整数且理由非空，`pm_mirror` 须单段文件名，`pm_capability` 名须小写 token 且跨行唯一，`pm_capability_authority` 跨行恰一行，`pm_capability_target` 目标路径跨行唯一且 kind ∈ decl/table，`pm_mechanism` 值须非空无空白且跨行唯一，`pm_mechanism_marker` 跨行恰一行；`kind` 枚举三值；各节内路径/文件名/短码/值/词/路径+行号跨行不重复；`pm_capability_target` 预期名单逐名 ⊆ 名单且全部目标并集 ⊇ 名单（名单与检查目标互恰）；除 `vague-exemptions` 节可空外，其余九节每节至少一行。

### 维护规则

清单变更先改数据再改实物（数据先行）；本表与 `scripts/README.md` 成员表、`references/` 各目录 README 登记面为「数据＝机器真相、表＝人读投影」关系，一致性由检查 5/9 机械核对，漂移即 FAIL（表文修正归人工裁决，不静默互改）。短码或 platform 新值：先在数据表登记，再按 `references/protocol/governance-format.md` 与 `references/adapters/capability-contract.md`（R-CC-005）流程落登记面与实物。

vague-words 词表与 vague-exemptions 豁免维护（票 58）：词表以 R-GF-010 原文列举为准，加词/减词＝改 `vague-words` 节行并同步 harness 夹具（check-package 套件 PASS 行含词数计数，预期串须随动）；扫描窗口与排除口径注记于本表头部注释（规则块体、排除「解释与例外」节与 README 文件）。命中处置顺序：先判可否只换词不换义地修正（保语义），不可安全换词才登记豁免；豁免必须注记理由（引述词表本身的禁令条款属正当豁免，依据 R-GF-010 Evidence「禁令条款内的引述除外」）；正文行增删使豁免行号漂移时，检查 12 报失效豁免，处置＝复核后更新行号或删除登记，不得静默保留。

capability-primitives 名单与检查目标维护（票 59）：九基元名以 `capability-contract.md` §2.1 权威表为唯一事实源，禁止单侧改——基元增删改名＝先改权威表，再同步本节 `pm_capability` 行与 `pm_capability_target` 预期名单，再改目标实物（角色合同声明行/适配文件对照表），最后同步 harness 夹具（check-package 套件 PASS 行含基元数与目标数计数，预期串须随动；注入/删名负例随名单语义复核）。新增检查目标＝加一行 `pm_capability_target`（预期名单现场转录自目标现行声明面/对照表）并确认并集 ⊇ 名单校验仍过；目标正文声明变化＝先改预期名单再改实物（数据先行）。解析锚点（声明行标记、对照表头列、权威表标题）为引擎窄锚点，目标文件锚点文本漂移即 exit 2，须同步引擎锚点与本注记。

mechanism-vocab 词表与规则索引维护（票 60）：受控三值与外定义标记词以本节为唯一承载点，引擎零词表硬编码；词表增删值＝先改本节，再改模板 `development-process.md.tmpl` §16 机制列取值，并同步 harness 夹具（正例 PASS 行含机制值数与标记词数计数）。索引维护顺序＝先改模板 §16 索引表，再动规则块本体；反向（先加/改规则块后补索引行）由检查 15 拦截（全集 ID 缺索引行 FAIL）。机械行点名的脚本必须已在 `scripts` 节登记且真实存在（检查 17），新脚本先登记 `pm_script` 行再进索引机制列；点名的检查项号不得超过引擎检查总数，引擎扩项时同步 `n_total_checks` 与模板 §16 节头表述。

## check-stale-claims.sh（易腐断言扫描器）

登记表驱动的易腐状态句扫描器（REQ-20260904-010 / 票 19）：对登记表内的高流转状态句逐条对现实核验，供票收口拦截与会话启动提醒。POSIX sh（`#!/bin/sh`、`set -eu`）、全程只读（除向 stdout/stderr 打印外无写操作，Git 仅使用只读子命令）、零外部依赖、零网络依赖。

### 用法

```text
sh scripts/check-stale-claims.sh [repo-root] [gate|session]
```

- 无参数：以脚本所在目录向上两级为仓库根（脚本位于 `agent-up/scripts/`；在本仓库内运行时，检的就是本仓库），模式默认 `gate`。
- 带参数：第一参数为仓库根，第二参数为模式；模式也可用环境变量 `STALE_CLAIMS_MODE` 指定（第二参数优先）。
- `-h` / `--help`：打印用法。

### 两模式

| 模式 | 触发场景 | 行为 |
| --- | --- | --- |
| `gate`（默认） | 票收口模式 | 发现过期断言输出 `路径:行号:内容` 定位并 exit 1 拦截；清洁 exit 0。 |
| `session` | 会话启动模式 | 输出与 gate 相同的 STALE/WARN 明细，但只作警告不拦截，恒 exit 0。 |

### 登记表结构

登记表内置于脚本，条目结构为 `{断言模式, 权威位置, 校验方式}`，只登记高流转状态句。现役四条（S1～S3 为票 19 首批，S4 为票 65 增补；权威位置为现行文档真实路径）；票 72 起 S1/S2 为配置点亮条目——是否点亮＝仓根 `delivery.rules` calibration 节 `dp_stale_lit` 登记（`S1`/`S2` 枚举，解析破坏 exit 2 fail-closed），未点亮打印 `SKIP: Sx — delivery.rules 未点亮（dp_stale_lit 缺登记）` 不计过期断言不拦票；点亮则现行断言逻辑原样执行，其中 remote 名（S1-1c/S2）、包前缀（S2 次级权威位置）与本地导出分支名（S1-1b）自 payload 节读取（未声明 payload 节＝不可知，退化 WARN 跳过不硬猜）；宣称锚点句属协议面留引擎（设计票 §2 分界判据）；S3/S4 为通用面无点亮位恒执行。

| 编号 | 断言模式 | 权威位置 | 校验方式 |
| --- | --- | --- | --- |
| S1 | Git 状态句 | `docs/archive/progress.md` 的「Git 恢复基线」块（2026-09-23 票 87 迁址自 docs/progress.md） | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、唯一 remote 与宣称地址一致、本地 main 未被远端跟踪分支包含）；非 Git 工作区按流程退化语义输出提醒跳过。（票 37 修订：移除"工作区存在未提交改动"子项核对——该陈述为票 13 时点历史快照，`docs/progress.md` 现为冻结历史档案（零写入），清洁工作区属稳态，逐字核对构成恒触发误报（S1-1e 已知缺口）；基线块原文按"不改历史"保留。） |
| S2 | 发布状态句 | 根 `README.md`「公开包已发布」宣称行 + 包内 README 安装行（包前缀自 `delivery.rules` dp_payload_root 派生，票 72） | machine：文档宣称的仓库地址与实际 remote 配置归一化比对（remote 名自 dp_payload_remote 读取）、包内安装行同源核对；远端可达性/可见性本地不核验（不出网）→ reminder。 |
| S3 | frontier 句 | `docs/issues/index.json`（票状态真相源）+ `docs/progress-current.md`（现役状态投影） | machine：投影 vs 索引比对——优先调用 `generate-progress.sh --check`（exit 0 一致；exit 1 投影 stale 或缺失；exit 2 索引缺失或条目排版不合预期）→ 差异即过期断言；生成器不可用时退化为内建最小比对（id/status/updated_at 三元组）并输出 NOTE 说明（不计入失败）。（票 37 修订：原"`docs/issues/README.md` 表行逐票对照票面状态"实现退役——README 状态列已定位为人工登记投影（票 35 起），与索引冲突时以索引为准。） |
| S4 | 计数漂移句 | `docs/issues/README.md` 目录清单锚点行（「任务票 NN；」）+ `docs/issues/index.json` 任务条目；`docs/` 树 md + `docs/agent/artifacts.yaml` 现行面计数措辞 | machine：两断言（票 65，详见下文 S4 小节）——①数量相等：README「任务票 NN；」锚点行数与 index「`"id": "NN-…"`」条目数机械相等，不等 STALE 指名两侧计数（ticket-ops 双写锁定面漂移）；README/索引缺失或锚点零命中 WARN 跳过不硬猜。②计数模式扫描：「N～M 共」「共 N 量词」命中输出 STALE-prone 指名 file:line、计入过期断言计数（gate exit 1 / session 只警告）；扫描面排除与豁免表见下文 S4 小节。 |

机器可校验项直接对现实核验；不可机器校验项输出存在时长提醒（WARN，阈值【待定】，定稿后同步本登记）。

### 输出格式

```text
STALE: <路径:行号> — <断言与现实的差异说明>
WARN: <路径:行号> — <提醒内容（含登记日期与【待定】阈值标注）>
NOTE: <路径> — <比对机制退化说明（生成器不可用时退化为内建最小比对；不计入失败）>
STALE-prone: <路径:行号> — 计数模式命中（S4-②，计入过期断言计数）：改写为计数无关措辞或按登记表注记理由豁免
SKIP: S1 — delivery.rules 未点亮（dp_stale_lit 缺登记）    # 票 72 点亮语义：未点亮条目不计数
check-stale-claims: PASS（登记表 N 条全部核对，提醒 N 条）    # gate 模式清洁；N＝点亮数＋通用条数（票 72 动态化，全点亮语境渲染 4）
check-stale-claims: FAIL（N 处过期断言，登记表共 N 条）       # gate 模式存在过期断言；N 同上
check-stale-claims: 会话启动模式（不拦截）：过期断言 N 处，提醒 N 条，请人工核对上方输出
```

- STALE 行含 `路径:行号` 定位与差异说明；WARN 行为提醒（非失败）；NOTE 行为 S3 比对机制退化说明（非失败）；STALE-prone 行为 S4-② 计数模式易腐命中（计入过期断言计数，与 STALE 同口径参与 gate 拦截 / session 警告）；结尾汇总行给出计数与结论。
- S3 生成器定位顺序：本脚本同目录（包内自含）→ 仓库根 `scripts/`（落位安装形态）；两处均不可用才退化内建最小比对。两模式对生成器退出码的语义映射一致：差异与异常均计 STALE，gate 拦截 / session 警告。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | gate 模式下无过期断言（提醒照常输出），或 session 模式。 |
| 1 | gate 模式下存在过期断言（STALE 行见输出）。 |
| 2 | 用法或环境错误（参数过多、模式非法、仓库根不存在等）；S4 豁免表结构破坏与 delivery.rules 解析破坏亦 exit 2（票 72，不产生部分结论）。 |

### S4 计数漂移哨兵（票 65）

推数字免费化哨兵（票 61 先例：数字会腐烂、计数无关措辞不会；真发现源头＝票 59 的 artifacts.yaml 注记 16→60 计数漂移穿透既有门禁）。两断言语义：

- S4-① 数量相等：`docs/issues/README.md` 目录清单「任务票 <NN>；」锚点行数（ticket-ops 写入锚）与 `docs/issues/index.json` 任务条目数（`"id": "<NN>-…"` 形态）机械相等，不等即 STALE 指名两侧计数（ticket-ops 双写锁定面的漂移检测，手工删行/加行即报）；README/索引缺失或锚点零命中 WARN 跳过不硬猜（随既有退化语义）。
- S4-② 计数模式扫描：扫描面＝`docs/` 树 `*.md` ＋ `docs/agent/artifacts.yaml`，出现「<数字>～<数字> 共」或「共 <数字> <量词>（张/条/项/件/个）」即输出 STALE-prone 指名 file:line、计入过期断言计数（gate exit 1 / session 只警告）；模式为 ERE、全程 LC_ALL=C 字节语义。

扫描面排除（历史真陈述/机器生成面非现行声明，命中不报；2026-09-21 协调层裁决 O3 收窄）：`docs/issues/*.md`（票面历史文件——历史票文不改写原则）、`docs/agent/runs/`（run record 投影）、`docs/architecture/generated/`（机器生成投影面）、`docs/archive/progress.md`（冻结历史档案——指针注记后零写入；2026-09-23 票 87 迁址）、`docs/archive/changes.md`（只追加账本冻结件——历史条目不可改写；2026-09-23 票 87 迁址）、`docs/progress-current.md`（现役状态投影——Derived 生成器独占写）。

豁免表（脚本内 `s4_load_exempts` 数据节，唯一承载点）：每条一行 `s4_exempt <仓库根相对路径> <行号> <理由>`，理由必填、显式登记、无静默豁免；命中行增删致行号漂移时须复核更新或删除登记（对齐 `package-manifest.rules` vague-exemptions 维护口径）。当前空表交付（票 65 裁决）＝现行面全数字免费，本表为未来正当例外预留。

## check-gates.sh（快道门禁核对器）

分级交付道快道的只读门禁核对器（REQ-20260904-011 / 票 26）：对行式门禁清单逐项核对「工作区实际改动 ⊆ 白名单」，并按清单重跑验证命令、记录退出码，供票收口与道脚本收尾调用。POSIX sh（`#!/bin/sh`、`set -eu`）、严格只读（除向 stdout/stderr 打印外无任何写操作；Git 仅使用只读子命令 `rev-parse`/`status`，无临时文件）、零外部依赖、零网络依赖。

### 用法

```text
sh scripts/check-gates.sh [repo-root] <gates-file>
```

- 无参数：仓库根取当前目录所在 Git 仓库顶层；门禁清单文件为第一参数。
- 带参数：第一参数为仓库根，第二参数为门禁清单文件（行式输入）。
- `-h` / `--help`：打印用法。

### 门禁清单行格式

行式门禁清单文件（均以行首列为准）：

| 行格式 | 说明 |
| --- | --- |
| `whitelist: <逗号分隔的仓库根相对路径>` | 必需，至少一行；一行可多项，逗号分隔。 |
| `verify: <验证命令>` | 一行一条，可多行；每条在仓库根内执行并记录退出码。 |
| `# 注释` / 空行 | 行首 `#` 与空行忽略；无法识别的行判格式错误（exit 2）。 |

白名单口径：白名单条目须为仓库根相对**文件路径**。改动集以 `git status --porcelain -uall` 逐文件展开（未跟踪目录不折叠为目录条目），逐文件与白名单条目做全字面比对——目录形态条目（如 `docs/`）在逐文件口径下永不可 PASS，属 fail-closed 方向；路径含空白或转义引用时拒绝解析（exit 2）。

### 输出格式

```text
PASS: 改动 <路径>（在白名单内）
FAIL: 改动 <路径>（不在白名单内）
PASS: verify[<序号>] exit=0 <命令>
FAIL: verify[<序号>] exit=<退出码> <命令>
  <verify 失败时的命令输出，逐行缩进两空格>
check-gates: PASS（改动 N 项全部在白名单内，verify N 条全部通过）
check-gates: FAIL（N 项未通过）
```

- 实际改动的每个文件（重命名行展开为新旧两侧）逐项输出一行 PASS 或 FAIL；verify 逐条输出退出码记录行，失败时附命令输出（缩进两空格）；结尾汇总行给出计数与结论。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部通过（改动全在白名单内且 verify 全部 exit 0）。 |
| 1 | 有未过项（越界改动或 verify 失败，逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库、清单不可读、清单缺少 whitelist 行、清单行无法识别、git status 行无法解析等）。 |

## lane-commit.sh（快道收尾脚本）

分级交付道快道的合同驱动收尾脚本（REQ-20260904-011 / 票 26；票 37 单写机制改造）：门禁核对 → 白名单产品提交 → 记录写入（索引单写 → 票正文 Status 投影打印件回写 → User Review Checkpoint 追加或微账本落行 → 生成器投影再生并 `--check` 核对）→ 记录提交，两段式（先产品提交后纯记录提交，R-RC-003）。行为基线 = development-process 模板 §12.5 道脚本承载注记（单写索引 → 生成正文 Status 行 → 生成投影，票 34 定稿）。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖、零网络依赖、fail-closed（门禁不过、合同格式不合预期、索引或生成器缺失即停止报告；预检先于产品提交，停止时零提交零写入，不 best-effort 修补）。脚本权限边界 = 提交合同白名单，不执行白名单外任何写入；`docs/issues/README.md` 与 `docs/progress.md` 状态行不属本脚本写入面（README 状态列为人工登记投影，票 35/37 口径）。

### 用法

```text
sh scripts/lane-commit.sh [repo-root] <contract-file>
```

- 无参数：仓库根取当前目录所在 Git 仓库顶层；提交合同文件为第一参数。
- 带参数：第一参数为仓库根，第二参数为提交合同文件（行式临时输入，不落仓库）。
- `-h` / `--help`：打印用法。

### 合同行格式

行式提交合同文件（均以行首列为准）：

| 行格式 | 说明 |
| --- | --- |
| `lane: user-review` 或 `lane: micro` | 必需，恰一行；取值仅 `user-review` 或 `micro`。micro 道预检两断言（票 58）：白名单 ≤3 条目、改动集零新建（??）零删除（D）——违者 exit 1；user-review 道不受限。 |
| `ticket: <仓库根相对路径>` | user-review 道必填（票文件须存在）；micro 道不得出现。 |
| `whitelist: <逗号分隔相对路径>` | 必填，一行可多项；口径同 check-gates.sh（须为仓库根相对文件路径）。 |
| `message: <产品提交说明>` | 必填，恰一行。 |
| `verify: <验证命令>` | 一行一条，可多行；交由 check-gates.sh 重跑并记录退出码。 |
| `verdict_quote: <用户裁决原文>` | user-review 道必填；micro 道不得出现。 |
| `verdict_at: <裁决时间>` | user-review 道必填；micro 道不得出现。 |
| `flips: <file>:<field>:<value>` | 行翻转：一行一条，可多行；`field` 不得为 `status`（已退役）或 `index`（索引专用段名）。 |
| `flips: docs/issues/index.json:index:<id>:<status>:<updated_at>` | 索引条目翻转：user-review 道专用，至多一条；`id` 须与 `ticket` 票文件名去 `.md` 一致；`status` 为状态机裸值（ready / in_progress / blocked / review_ready / review_pass / review_fail / done / superseded，不带冒号后缀）；`updated_at` 形如 `YYYY-MM-DDTHH:MM[:SS]`（允许冒号，取行尾余段）。 |
| `# 注释` / 空行 | 行首 `#` 与空行忽略；无法识别的行、重复行判合同格式错误（exit 1）。 |

flips 语义（票 37）：

- 索引条目翻转（单写机制）：单写 `docs/issues/index.json`——`"id": "<id>"` 锚点整行替换，仅改该行 `status` 与 `updated_at` 两值，`complexity`/`blocked_by`/`checkpoint_ref` 等其余字段原样保留；依赖一条目一行排版（票 33 终裁 T2），条目行不含同行 `status`/`updated_at` 字段或锚点命中数 ≠1 即预检停止。随后机械回写 `ticket` 票正文 `**Status:**` 行为反引号包裹的 `status`（投影打印件，票 35 过渡期口径；正文 Status 行须恰命中一行），再调用 `generate-progress.sh` 再生 `docs/progress-current.md` 并 `--check` 核对（两步任一非 0 即停止，输出指路）。生成器定位：本脚本同目录优先，PATH 回退（手动迭代 PATH 逐目录探测可读的 `generate-progress.sh`；不用 `command -v`——落位脚本不要求可执行位、恒经 sh 调用，`command -v` 对不可执行文件不报告，票 38 措辞对齐实现 lane-commit.sh 生成器定位段）；索引或生成器缺失属预检条件，先于产品提交停止。
- 行翻转：锚点为字面子串，须恰命中一行，整行换成 `value`。
- `field: status` 已退役（票 34 frontmatter status 退役、票 37 单写机制承载票状态）：合同携带即停止并指路索引条目口径。锚点不合规在写入前停止（exit 1）。

### 两段式提交与输出格式

执行顺序（每步失败即停止；第 4 步前的停止零提交零写入，第 4 步后的停止保留产品提交并输出指路）：

1. 合同解析与语义校验（车道组合、必填行缺失、禁止组合、索引翻转车道/id/取值校验；先于任何写入）；micro 道预检两断言（票 58：白名单条目 ≤3——超出属非微任务改走 user-review 道；`git status` 改动集零新建（??）零删除（D）——微道只修不建不删；任一违者 exit 1，停止时零提交零写入；user-review 道行为零变化）。
2. 翻转目标与预检（只扫描不写入）：翻转目标存在性、索引一条目一行排版与 id 锚点唯一命中、正文 Status 行唯一命中、行翻转锚点唯一命中、生成器可用性（同目录 → PATH）；全部通过才继续。
3. 门禁核对（内部调用同目录 check-gates.sh，只读）；任一不符 exit 1。
4. 产品提交：按白名单逐项 `git add`，防御性核对暂存内容不越出白名单，按合同 `message` 创建提交。
5. 记录写入：索引单写 → 票正文 Status 投影打印件回写 → 行翻转 → user-review 道向票文件追加 User Review Checkpoint（裁决原文、裁决时间、产品提交 ID 与说明、diff 摘要）/ micro 道向 `docs/agent/micro.jsonl` 落一行 JSON → 生成器投影再生并 `--check` 核对。
6. 记录提交：索引、票文件、投影、微账本等记录内容统一入第二段提交（`chore(lane): 记录翻转 — <message>`）。

```text
lane-commit: 生成器定位: 同目录 <路径>|PATH <路径>
lane-commit: 索引单写: docs/issues/index.json（<id> → <status>，updated_at <时间>）
lane-commit: 正文 Status 回写（投影打印件）: <ticket> → **Status:** `<status>`
lane-commit: 翻转: <file>:<field>:<value>
lane-commit: User Review Checkpoint 已追加: <ticket>
lane-commit: 微账本已落行: docs/agent/micro.jsonl
lane-commit: 投影已再生并核对: docs/progress-current.md
lane-commit: 产品提交 <提交 ID>
lane-commit: 产品文件: <逗号分隔清单>
lane-commit: 记录提交 <提交 ID>
lane-commit: 记录文件: <逗号分隔清单>
lane-commit: PASS（两段式完成：门禁 PASS、索引单写 N 处、翻转 N 项、投影已核对、记录已落盘）
```

- 各行为行仅在实际发生时输出（「索引单写」「正文 Status 回写」「投影已再生并核对」随索引条目翻转；「User Review Checkpoint 已追加」仅 user-review 道；「微账本已落行」仅 micro 道）；失败输出 `lane-commit: FAIL: <原因>`（stderr），逐步骤停止原因与指路可定位。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 两段式全部完成（门禁 PASS、产品提交、记录写入、投影核对、记录提交）。 |
| 1 | 门禁不过或合同 fail-closed 条件（合同格式错误、车道必填缺失或禁止组合、白名单越界、verify 失败、索引缺失或排版不合预期、正文 Status 行锚点不合规、翻转锚点不合规、生成器不可用、投影再生或 `--check` 未过、暂存越出白名单、白名单内无实际改动、微道预检不过（白名单 >3 条目或改动集含 ??/D，票 58）等）；预检与门禁阶段的停止零提交零写入，记录写入阶段的停止保留产品提交并输出指路。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库、合同文件不可读、同目录 check-gates.sh 缺失等）。 |

### 微账本与维护联动

- 微账本 `docs/agent/micro.jsonl`（票 37 起，替代竖线格式 `micro.md`；无存量迁移负担）与 user-review 道 User Review Checkpoint 由本脚本独占写：微账本懒创建（空文件起步，JSONL 不承载注释行），一行一操作，agent 不手写、其他流程不得代写。JSON 行字段与键序固定：`date`（`YYYY-MM-DD`）、`lane`（`micro`）、`whitelist`（逗号分隔白名单，JSON 转义 `"` 与 `\`）、`gates`（`PASS`）、`verify`（重跑验证命令条数）、`commit`（产品提交 ID）；每行均可被 `json.loads` 解析，禁裸换行。
- 白名单与 flips 目标均须为仓库根相对文件路径；索引条目翻转锚点依赖 `docs/issues/index.json` 一条目一行排版（票 33 终裁 T2）与条目行内 `"status"`/`"updated_at"` 字段同行（排版破坏即预检停止），排版口径见 `../references/schemas/issue-index.schema.json`；正文 Status 回写锚点依赖票面 `**Status:**` 行格式，格式变化须同步脚本锚点语义与本 README。
- 生成器 `generate-progress.sh` 与本脚本同目录落位（生成项目 `scripts/` 由 SKILL 步骤 5 一并复制）；仅 PATH 回退形态运行时，投影再生依赖 PATH 上的同名脚本。索引或生成器缺失的停止属 fail-closed（对齐 development-process R-DP-031 兜底），不存在"缺失就跳过继续"路径。
- 本脚本用法、合同行格式或退出码变化须同步脚本 usage 文本与本 README 专节；门禁清单格式口径以 check-gates.sh 专节为准。

## generate-progress.sh（现役状态投影生成器）

投影生成器（票 33 草案 §5.1.4 生成规则 / 票 35 本仓落位 / 票 37 入包）：自 `docs/issues/index.json`（票状态机器真相源，单文件一条目一行，票 33 终裁 T2）生成 `docs/progress-current.md` 现役状态投影——Derived 四标注头部（generated_from、生成时间、覆盖范围、失效条件）＋每票一行 `| id | status | checkpoint_ref | updated_at |` 状态表，按 id 升序。生成器独占写 `docs/progress-current.md`（development-process 模板 §12.5 派生载体独占写），agent 不手写该投影；投影与索引不一致时以索引为准。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖（无 jq/python）、fail-closed——索引缺失、不可读或条目行不合预期即停止报告，不写投影。包内版本与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致（票 37 入包核对）；快道收尾由 `lane-commit.sh` 在索引单写后自动调用，生成项目由 SKILL 步骤 5 随道脚本一并复制落位 `scripts/`。

### 用法

```text
sh scripts/generate-progress.sh [--check] [repo-root]
```

- 无参数：repo-root 缺省取脚本所在目录的上一级（落位形态 `scripts/` 即仓库根）。
- 带参数：以第一参数为仓库根（对临时目录副本或非默认落位复跑时使用）。
- `--check`：dry-run 一致性核对——生成结果与既有 `docs/progress-current.md` 各自规范化 `generated_at` 行（该行随生成时间漂移，不参与判定）后逐字节比对，一致 exit 0，不一致 exit 1，不写任何文件。
- `-h` / `--help`：打印用法。

### 输出格式

```text
generate-progress: OK: 已生成 <投影路径>
generate-progress: CHECK: PASS — 投影与索引一致: <投影路径>       # --check 一致
generate-progress: FAIL: 投影与索引不一致（stale）: <投影路径>    # --check 不一致，附 diff
generate-progress: FAIL: <原因>                                   # fail-closed 停止（stderr）
```

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 生成成功，或 `--check` 一致。 |
| 1 | `--check` 不一致（投影 stale）或既有投影缺失。 |
| 2 | 用法错误、索引文件缺失/不可读或条目行不合预期（一条目一行排版破坏、条目缺必备字段；fail-closed，不写投影）。 |

### 维护联动

- 生成规则或投影格式变化须同步重跑生成器刷新投影，并登记 `docs/agent/artifacts.yaml` 对应条目；条目行锚点为 `"id": "<数字开头 id>"`，索引排版变化须同步本脚本、`lane-commit.sh` 索引单写锚点与 check-stale-claims.sh S3 比对三处。
- 包内版本与本仓根 `scripts/` 基线互为镜像：任一侧变化须同步另一侧并 cmp 核对或登记差异（票 37 入包口径）。

## generate-module-map.sh（模块地图生成器）

模块地图生成器（票 30 调研拍板：落点＝方案 A agent-up 公开包脚本、查询形态＝JSON 直读唯一查询面（`--affected` 不采纳）、更新时机＝双通道，票 43 扩 Rust 为四语言，票 44 引擎表驱动化，票 45 七语言批量扩展（十一语言）；票 42 落位）：从仓库源码文件的静态导入语句提取文件/模块级依赖边，生成 `<root>/docs/architecture/module-map.json`——Derived 四标注头部（`generated_from`/`generated_at`/`coverage`/`invalidation`，R-DP-004）＋`workspace_fingerprint`（fp-v1，R-DP-015 算法；指纹输入排除本图自身，避免自引用漂移）＋`nodes`（已扫描源码文件，仓库根相对路径）＋`edges`（`from`=仓库根相对路径、`to`=导入语句文本中的模块引用原串（未做路径解析）、`label`=导入语句类别）。票 44 起引擎为通用规则解释器（加载规则表→按扩展名发现源码→逐行匹配捕获→按策略产边→direct-file 候选边存在性过滤→组装 JSON），语言知识外置于同目录 `module-map.rules`（每语言一行，引擎零语言专名；加语言＝加规则行＋fixture、零引擎改动）；规则表随脚本同目录落位（复制落位形态 `scripts/` 下两件同迁）。本图是项目地图条件产物的承载视图（development-process §5.2 触发矩阵行"项目地图"），只当检索索引不当 Scope 权威，不作为白名单或 watch 依据；Derived 自动生成，agent 不手写。输出为 `python3` `json.loads` 可解析的机器可读 JSON（R-GF-005）。

### 用法

```text
sh scripts/generate-module-map.sh [repo-root]
```

- 无参数：repo-root 缺省取当前目录所在 Git 仓库顶层（check-gates.sh :20 先例）。
- 带参数：以第一参数为仓库根（对临时 fixture 仓或非默认落位复跑时使用）。
- `-h` / `--help`：打印用法。
- 输出落 `<root>/docs/architecture/module-map.json`（目录缺失时随生成懒创建）；生成动作对仓库零额外写入（临时文件全部落 TMPDIR）。

### 语言规则表（module-map.rules，十一语言）

语言知识唯一承载点＝同目录 `module-map.rules`（票 44）：每语言一行 `mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>`，`<rules>` 内为 `@` 连接的提取规则列表（`capture` 段捕获／`scan` 行变换两类，字段以 `~` 连接；op 形态 `s=<ERE>`／`g=<ERE>=<替换>`／`Q`，列表以 `&&` 连接），加载时结构校验（字段数、op 编码、selector/strategy 枚举、扩展名形态与跨行重复）不合预期即 exit 2。路径策略枚举（票 44 定稿，按既有四语言实际归纳）：`extension-map`（语言绑定，由 `<exts>` 承载）、`unresolved-node`（未解析节点引用直出）、`module-path`（模块路径文本直出）、`direct-file`（声明文件候选边＋存在性过滤）；后两类直出策略共用 verbatim 产出行为、以引用语义区分（影响后续路径解析扩展的归类）。下表为十一语言现行规则行的人读摘要（权威以规则表为准；票 45 追加 Go/Java/C#/Ruby/PHP/Swift/Kotlin 七语言，覆盖语言总数 11）：

| 语言 | 扩展名 | 匹配规则（语句文本层） | label 取值 |
| --- | --- | --- | --- |
| Python | `.py` | `import a[.b][, c]`（逗号列表、`as` 别名取模块名、行尾 `#` 注释剥离）与 `from m import ...`（含相对导入 `.`/`..`） | `python-import` / `python-from` |
| JS/TS | `.js .mjs .cjs .jsx .ts .tsx` | `import ... from '...'`、裸 `import '...'`、`require('...')`（单双引号归一处理）；re-export（`export ... from`）与动态 `import()` 未覆盖 | `js-import` / `js-require` |
| C/C++ | `.c .h .cc .cpp .cxx .hpp .hh` | 引号 `#include "..."`；尖括号系统头 `#include <...>` 不提取 | `c-include` |
| Rust | `.rs` | `mod x;` 声明（分号收尾；内联块 `mod x {` 不匹配）映射文件边：子模块目录＝声明文件同目录（声明文件为 `mod.rs`/`main.rs`/`lib.rs` 时）或同名子目录（其余），候选 `x.rs` 与 `x/mod.rs` 经文件存在性核验后产边，无候选零边；`use` 路径表达式原串产模块路径边（`crate::`/`self::`/`super::`/`::`开头/外部 crate 路径；brace 组取 `{` 前缀、`as` 别名取前缀、glob 剥尾 `::*`、`r#` 原始标识符段按原串保留；多行 brace 组取首行前缀）；宏生成声明、pub use 转发语义、extern crate、`#[path]` 重定位、块注释内文本未覆盖 | `rust-mod` / `rust-use` |
| Go | `.go` | `import "path"` 单行（含别名/`_`/`.` 前缀）＋括号块内 `"path"` 行（行首引号形态，可带单个别名/`_`/`.`；Go 关键字行按组屏蔽）；行注释剥离 | `go-import` |
| Java | `.java` | `import a.b.c;`（分号收尾；`static` 前缀剥离；on-demand `.*` 剥尾取包路径）；行注释剥离 | `java-import` |
| C# | `.cs` | `using X.Y.Z;`（分号收尾；`static` 前缀剥离；别名与 using 声明/语句形态校验拒绝不产边）；行注释剥离 | `csharp-using` |
| Ruby | `.rb` | `require 'x'` / `require("x")` / `require_relative '...'`（引号串，单双引号归一，`#` 注释剥离；相对路径原串直出） | `ruby-require` / `ruby-require-relative` |
| PHP | `.php` | `use A\B\C;`（反斜杠分隔；`function`/`const` 前缀与 `as` 别名剥离；group use 校验拒绝不产边）＋`require`/`include[_once]` 引号串；行注释剥离、单双引号归一 | `php-use` / `php-require` |
| Swift | `.swift` | `import Module`（`@testable`/`@_exported`/`export` 前缀与 kind 前缀（struct/class/func/enum/protocol/typealias）剥离，属性符号以标点类近似）；行注释剥离 | `swift-import` |
| Kotlin | `.kt .kts` | `import a.b.c`（分号可选；`as` 别名剥离；on-demand `.*` 剥尾取包路径）；行注释剥离 | `kotlin-import` |

覆盖声明（R-CC-004，保守措辞）：提取规则为语句文本层——不做别名/tsconfig paths 等路径映射解析，不覆盖动态导入、re-export、符号级调用图与构建期代码生成边；注释内的导入文本与字符串字面量构成已知误报源（输出层不做语义过滤）。上表规则经 fixture 最小验证（mktemp 临时仓：四语言正例＋空格/中文路径＋尖括号系统头/内联 mod 块/不存在 mod 负例＋fp-v1 复算比对；票 43 新旧脚本对同一三语言夹具边集 diff 零变化；票 44 迁移后新旧引擎对四语言 fixture 边集逐边相等——13/17/7/20 条，nodes 与退出码亦一致——且哑语言规则行零引擎改动产边实证成立；票 45 追加七语言后四语言边集回归零变化＋七语言 fixture 边集逐一相等——go 5/java 4/csharp 4/ruby 4/php 4/swift 4/kotlin 4 条，各含去重与注释/字符串内导入负例），未实测项按一般工程知识声明。七语言未覆盖口径逐语言一行（票 45）：Go——build tag 条件文件不做判别，行首引号形态为文本层近似（raw string 续行等 import 块外行首字符串行可能误报，Go 关键字行已按组屏蔽）；Java——module-info.java 的 requires 句未覆盖，static import 末段可能为成员名（文本层不区分类型与成员）；C#——using 别名未覆盖，using 声明/语句经校验拒绝不产边；Ruby——require_relative 相对路径未按声明文件位置解析（原串直出），动态插值路径、__END__ 数据段、begin/end 块注释、heredoc 内文本与 load 语句未覆盖；PHP——group use 花括号分组与前导反斜杠根相对形态未覆盖，类内 trait use 文本层无法区分可能误报，require/include 表达式拼接不解析（字面量前缀按原串产边，变量形态不产边）；Swift——条件编译块不做判别，testable/exported 属性符号以标点类近似；Kotlin——反引号引用标识符段未覆盖。

### 更新时机（双通道）

1. 登记驱动：目标项目将本图按 development-process §5.3 登记 `docs/agent/artifacts.yaml`（lifecycle: Derived，generated_from 必填），`sync_on` 对齐拓扑变化行（文件新增/删除/移动/重命名即重新生成）；登记动作归目标项目 init/补缺流程（见 `../references/old-project.md` §3 项目地图行）。
2. 指纹比对：生成时将 fp-v1 工作区指纹内嵌 `workspace_fingerprint`，使用时按 R-DP-015 算法重算比对，不一致即按 R-DP-009 判 stale，不得当可信导航。已知局限（保守方向安全，票 30 ④声明）：fp-v1 为全工作区粒度，文档改动也判过期；精确化归后续演进。

### 依赖声明（零外部依赖的边界）

POSIX sh 主体（`#!/bin/sh`、`set -eu`、`set -f`）仅用 POSIX 标准工具（find/sed/awk/sort/grep/cut/wc/date/dirname/mktemp/git 只读子命令）；两项平台标配补充，缺失即 fail-closed（exit 2）：`stat`（BSD/GNU 双方言自动探测，取文件字节与 mtime 纪元秒）与系统 SHA-256 工具（`sha256sum`/`shasum -a 256`/`cksum -a sha256`/`openssl dgst -sha256` 按序探测）。语言规则表 `module-map.rules` 与脚本同目录加载（票 44）：缺失、未登记任何语言行或结构校验不过即 exit 2（fail-closed，不写地图）。

### 输出格式

```text
generate-module-map: OK: 已生成 <地图路径>（fp-v1:<hex16>，nodes N，edges M）
generate-module-map: FAIL: <原因>        # 生成条件不满足（stderr，exit 1，不写地图）
generate-module-map: <环境错误说明>       # 用法或环境错误（stderr，exit 2）
```

JSON 顶层键：`generated_from`、`generated_at`（UTC）、`coverage`（`languages`＋`limits`）、`invalidation`（失效条件：fp-v1 不一致或拓扑变化未同步）、`workspace_fingerprint`、`note`（检索索引非 Scope 权威声明＋edges 字段语义）、`nodes`（字符串数组）、`edges`（`{from, to, label}` 对象数组，排序去重）。字符串转义覆盖 `\`、`"`、制表与回车控制符；非 ASCII（UTF-8）路径原样保留。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 地图生成成功。 |
| 1 | 生成条件不满足（无受支持源码文件、路径含控制字符、写入失败等；fail-closed，不写地图）。 |
| 2 | 用法或环境错误（非 Git 仓库、仓库根不存在、SHA-256/stat 工具缺失、语言规则表缺失或结构校验不过）。 |

### 维护联动

- 语言规则表行增删或匹配规则变化＝编辑 `module-map.rules`＋fixture 回归（加语言零引擎改动，票 44 AC3 口径）；引擎不得引入语言专名（语言知识唯一承载点＝规则表，票 44 AC 硬门禁）；规则表编码（`@`/`~`/`&&`/`=` 分隔与 op 形态）或加载校验口径变化须同步引擎解析器与本专节。fixture 为临时件不入仓；六票（42/43/44/45）fixture 已沉淀为 `test-record-layer.sh` 的 module-map 套件（票 49，见下文专节），规则表或引擎行为变化时以 `sh scripts/test-record-layer.sh --suite module-map` 回归（跑法与历史结果另见票 42/票 43/票 44 run record `last_verified`）。
- 生成项目补缺落位与登记口径见 `../references/old-project.md` §3 项目地图行；本图不预建实例（触发矩阵行命中才创建，R-DP-006）。
- 排版与转义惯例与 `generate-progress.sh` 同源（`set -f`、TMPDIR mktemp＋trap 清理、LC_ALL=C 排序）；两脚本不共享代码，语义变化互不联动。

## ticket-ops.sh（票务运维脚本）

协调层票务面写入单入口（票 41 本仓交付 / 票 47 入包采纳；行为基线＝development-process 模板 §12.5 票务脚本承载注记与 §6 零写入三段式第二段）：开票、领取与收口状态翻转、`docs/issues/index.json` 单写、issues-README 状态列登记、`docs/changes.jsonl` 账本落行、`docs/progress-current.md` 投影再生，六个写入面逐项经本脚本承载。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、无 jq（仅 POSIX 标准工具与内建；open 本体 schema 校验另用 python3 标准库）、fail-closed——校验先于写入，NN 段查重（同 NN 异 slug／畸形 id）、open 本体 schema 校验与定级/优先级理由非空断言、索引一条目一行排版破坏、README 行缺失或锚点不唯一、账本行不合键序即停止不写；收尾投影再生缺失或 `--check` 不过即整体失败，已写部分如实报告。

### 用法

```text
sh scripts/ticket-ops.sh [repo-root] <command> [options]
```

- 无参数：repo-root 缺省取脚本所在目录的上一级（落位形态 `scripts/` 即仓库根）。
- 带参数：以第一参数为 repo-root（对临时 fixture 仓或非默认落位复跑时使用）。
- `-h` / `--help`：打印用法。
- 三子命令选项：`open` 必选 `--id <NN-slug> --complexity <C0-C3> --title <text> --ledger-line <json>`（可选 `--blocked-by <id,id>`）；`take` 必选 `--id --status --ledger-line`（status 须为 in_progress）；`flip` 必选 `--id --status --ledger-line`（status 为状态机任意合法值）。
- 数据载体与退出码：索引 `docs/issues/index.json`（票状态真相源，一条目一行，票 33 终裁 T2）、issues-README 目录清单状态列（`任务票 <NN>；` 后首个反引号状态 token，人工登记投影）、账本 `docs/changes.jsonl`（键序 date,kind,scope,decision,evidence_ref，一行一事实，禁裸换行）；退出码 0 全部完成、1 fail-closed（校验/锚点/收尾核对不过，已写部分如实报告）、2 用法或环境错误。
- 收尾投影再生：定位同目录 `generate-progress.sh`（PATH 回退），缺失即预检停止（fail-closed）——生成项目落位 `ticket-ops.sh` 时须一并落位生成器。

### 落位口径（与道脚本的关键差异）

- 票务运维是记录层标配，非快道专属：目标项目采用任务票体系（`docs/issues/` 目录创建）时随初始化/补缺复制落位目标项目 `scripts/` 并逐件登记 generation manifest 与 `docs/agent/artifacts.yaml`（kind: script、lifecycle: Conditional、generated_from: agent-up/scripts/ticket-ops.sh）；不门控于快道启用，未采用任务票体系不复制。三处口径同源：`../SKILL.md` 主流程步骤 5、本专节、`../references/old-project.md` §3 补缺行。
- 包内不运行：本包内 `agent-up/scripts/ticket-ops.sh` 是复制基线（生成源），缺省 repo-root 取所在目录的上一级，包内位置误运行会错根；仅落位到目标项目 `scripts/` 后按缺省语境运行。
- 包内文件与本仓根 `scripts/ticket-ops.sh` 基线 cmp 零差异（票 47 入包核对）；采纳后两份副本同源演化，任一侧变化须同步另一侧并 cmp 核对或逐条登记差异。

### 与 lane-commit.sh 职责边界

`ticket-ops.sh` 只做票务面写入（open/take/flip），不执行门禁核对与 Git 提交，不调用 `check-gates.sh` 与 `lane-commit.sh`（投影再生调用 `generate-progress.sh` 不在此限）；快道收尾（白名单核对、验证重跑、提交、记录翻转）仍归道脚本两件。非快道票（C1+ 全三阶段）的状态翻转由 `ticket-ops.sh` 承载——lane-commit 只覆盖快道，两者在 `docs/issues/index.json` 单写机制上同锚点语义（id 锚点整行替换，仅改 status/updated_at 两值）。

## install.sh（安装脚本）

安装政策单源化的执行引擎（票 56；先例 `generate-module-map.sh` 表驱动化：外置数据＋引擎零专名＋结构校验 fail-closed）：按启用门控自查同目录 `install-policy.rules` 得复制集合（引擎零脚本名零门控专名，加门控＝加规则行零引擎改动），逐件 `cp` 自包 `scripts/` 至 `<target>/scripts/` 并 `cmp` 核验字节一致。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖（仅 POSIX 标准工具与内建，无 jq/python）、fail-closed：规则表缺失或结构校验不过 exit 2 不写任何文件；预检（源存在、目标可写、同名件冲突）先于复制，停止零半套；包内误运行守卫（`--target` 解析后含 `agent-up/SKILL.md` 或 `SKILL.md`、或等于本脚本所在目录）exit 1；已存在且字节一致的同名件幂等跳过，与基线不一致即停报告（reconcile 纪律：人工漂移不覆盖，检出即停报告而非覆盖）。脚本只承接已确认的复制动作——门控启用判定是用户决策（`../SKILL.md` 主流程步骤 5），不代做访谈；不代写目标治理文件（`docs/agent/artifacts.yaml`、generation manifest、`scripts/README.md` 均归执行体）。包侧工具：只在包内语境运行，不落本仓 `scripts/` 镜像（票 56 out_of_scope 口径）。

### 用法

```text
sh agent-up/scripts/install.sh --target <dir> [--fast-lane] [--ticket-ops]
```

- `--target <dir>`：目标项目根目录（须已存在）；落位 `<dir>/scripts/`。
- `--fast-lane` / `--ticket-ops`：门控启用 flag（登记于 install-policy.rules 的 `ip_gate` 行；至少给出一个，零 flag 即用法错误）。
- `-h` / `--help`：打印用法。

### 安装政策数据格式（install-policy.rules）

- `ip_gate <gate> <flag> <说明>`：门控定义行（gate token、启用 flag、一句话说明）。
- `ip_file <pkg-rel-path> <lifecycle> <gate> <说明>`：每文件×每门控一行——包内复制基线路径（`agent-up/scripts/<文件名>`）、登记 lifecycle 值、所属门控、该门控下角色说明；同一文件属多个门控时逐门控各一行，引擎按文件路径去重选取。
- 行首 `#` 与空行忽略；加载时结构校验（字段数、gate/flag/lifecycle/路径字符集与形态、flag 跨行唯一且不与引擎保留参数冲突、(文件,门控) 跨行唯一、同文件 lifecycle 一致、未定义门控引用、零文件门控），任一不合预期即 exit 2（fail-closed，不写任何文件）。
- 本表、`install.sh` 引擎与本专节三处登记须同步；复制集合或门控构成变化＝编辑本表（零引擎改动）。

### 输出格式

```text
install: OK: <基线路径> -> <目标>/scripts/<文件>（lifecycle <值>；门控 <命中列表>；<角色说明>）
install: SKIP: <文件>（目标已存在且与基线字节一致，幂等跳过）
install: NOTE: <目标>/scripts 为本脚本新建——需生成 scripts/README.md（README 生成不归本脚本）
install: 登记建议块（artifacts.yaml 十三字段建议值，可粘贴；写入归执行体，本脚本不代写目标治理文件）:
  {id: …, path: …, kind: script, …, generated_from: …, platform: neutral, update_policy: …}   # 每复制件一行
install: 登记提醒: 每复制件同步登记 generation manifest（来源、日期、目标、用户确认、版本与恢复说明）
install: DONE: 复制 N 件、幂等跳过 M 件 -> <目标>/scripts
install: FAIL: <原因>        # fail-closed 停止（stderr，exit 1）
install: <用法或环境错误说明>   # stderr，exit 2
```

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部复制并核验通过。 |
| 1 | fail-closed（包内误运行守卫、目标不存在或不可写、源缺失、目标同名件与基线不一致、cmp 核验失败；预检先于复制，停止零半套）。 |
| 2 | 用法或环境错误（缺 `--target`、未知参数、零启用门控、规则表缺失或结构校验不过）。 |

### 维护联动

- 复制集合、门控构成或登记 lifecycle 值变化＝编辑 `install-policy.rules`＋同步本专节与 `../SKILL.md` 步骤 5 指向句；引擎解析器或校验口径变化须同步本专节。
- 夹具正负例（fast-lane 恰 3 件/ticket-ops 恰 2 件含回退注记/双开 5 选取去重 4 件/幂等重跑；规则表损坏 exit 2、缺源件 exit 1、包内误运行 exit 1、零 flag exit 2 等）为票 56 一次性实跑，证据见票 Checkpoint；harness 沉淀归后续票（`test-record-layer.sh` 扩 suite）。

## check-append-only.sh（Record 只追加守卫）

Record 只追加守卫（票 58；承接票 54 候选 C3「Record 行级保护」口径）：对仓库记录层两类写入语义做只读核对——`docs/changes.jsonl` 与 `docs/agent/micro.jsonl` 为只追加账本（Record 类，一行一事实，懒创建）：工作树内容相对 HEAD 旧 blob 必须为尾部追加（旧 blob 内容为新内容前缀），中间插入/改写历史行/截断/删除即违规，FAIL 指名文件与首个违规行号（新文件行号）；`docs/progress.md`（未迁移仓）及其迁移后继 `docs/archive/progress.md`（票 87，2026-09-23）为冻结历史档案（指针注记后零写入，development-process §11）：任何 diff 即违规，迁移窗口（HEAD 尚无后继路径）以后继工作树内容与 HEAD 旧路径逐字节一致为承继通过。核对基线＝工作树 vs HEAD（`git diff` 同口径；未跟踪且 HEAD 无同名的新文件按懒创建全追加语义放行）。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖（仅 POSIX 标准工具与 Git 只读子命令 rev-parse/cat-file/show，不含任何 Git 写操作）、fail-closed。可作 verify 命令加入门禁清单（如快道合同 `verify:` 行）。

### 用法

```text
sh scripts/check-append-only.sh <repo-root>
```

- `<repo-root>` 必填，仓库根目录。
- `-h` / `--help`：打印用法。

### 输出格式

```text
check-append-only: OK: <文件>（尾部追加 N 行，历史前缀核对通过）
check-append-only: OK: <文件>（工作树新建，全部行为追加，懒创建语义）
check-append-only: OK: <文件>（与 HEAD 一致，零 diff）
check-append-only: OK: <后继>（迁移承继：与 HEAD <旧路径> 逐字节一致，票 87）
check-append-only: OK: <旧路径>（已迁移至 <后继>，内容承继核对通过，票 87）
check-append-only: SKIP: <文件>（不存在，懒创建语义）
check-append-only: WARN: 无 Git 基线（无 HEAD），只追加与冻结核对跳过（票 49 先例：不硬猜基线）
check-append-only: FAIL: <文件> <违规描述（含首个违规行号）>
check-append-only: PASS
```

- 文件不存在跳过（懒创建语义，SKIP）；无 Git 基线（无 HEAD）输出 WARN 并退出 0（票 49 先例：首次提交前不硬猜基线）。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部通过（含 SKIP 与无基线 WARN）。 |
| 1 | 存在违规（账本中间插入/改写历史行/截断/删除，或冻结档案出现 diff；FAIL 行指名文件与首个违规行号）。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库）。 |

### 维护规则

- 守卫对象集合（两账本＋progress.md）变化须同步脚本 `check_append_file`/`check_frozen_file` 调用段、usage 文本与本专节；三类 Record 语义（只追加/冻结/懒创建）不放宽。
- 前缀判定为字节级（旧 blob 内容为新内容前缀），首个违规行号为新文件行号（行级差异定位）；仅尾行悬挂换行差异按截断报告字节口径。
- 行为语义变化经 Review 门禁并同步 harness append-only 套件（正负例随动，红灯不隔票）。

## check-artifacts.sh（治理产物对账器）

治理产物登记与实物双向对账器（票 59；兑现 R-DP-007「治理产物逐件登记」的机械核对面）：正向＝`<repo-root>/docs/agent/artifacts.yaml` 每条登记条目的 path 目标（剥离全角括注后的路径/聚合 glob/目录）必须存在，缺失 FAIL 指名条目；反向＝数据块受管口径内文件必须被登记（精确相等/case glob/目录聚合前缀三类覆盖）或命中豁免规则，未登记 FAIL 指名路径，豁免命中不报。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖（仅 POSIX 标准工具，无 Git 依赖）、fail-closed——登记解析破坏（缺 artifacts: 顶层键、零条目、条目缺 path、多行 path、path 值空/含空白、未知形态行）即 exit 2 不产生部分结论；退出码口径同 ticket-ops.sh（0 完成 / 1 缺口 / 2 用法环境）。

### 用法

```text
sh scripts/check-artifacts.sh <repo-root>
```

- `<repo-root>` 必填，仓库根目录（登记文件固定取 `<repo-root>/docs/agent/artifacts.yaml`）。
- `-h` / `--help`：打印用法。

### 对账数据块（受管口径与豁免，票 59 D2 定谳唯一承载点）

引擎零目录硬编码：受管口径、豁免与懒创建许可全部落脚本内数据块（`load_reconcile_data` 函数，`ca_*` 指令行），维护时不得静默增删，变更理由随行注记：

| 指令 | 语义 |
| --- | --- |
| `ca_managed_file <路径>` | 受管根单文件（存在才进反向清单）。 |
| `ca_managed_tree <目录> <扩展名逗号清单>` | 受管目录（递归，按扩展名过滤）。 |
| `ca_managed_flat <目录> <扩展名逗号清单>` | 受管目录（单层，按扩展名过滤）。 |
| `ca_exempt <路径>` | 反向豁免：精确路径；尾斜杠＝目录整支豁免；理由随行注记。 |
| `ca_lazy <路径>` | 正向暂缺许可：登记目标允许尚不存在（懒创建面），命中输出 SKIP 不计缺口。 |

本仓基线定谳（票 59；票 72 豁免迁移）：受管＝根 `AGENTS.md`＋`docs/` 树内 md/json/jsonl/yaml＋`scripts/` 单层 sh/rules；豁免分两面——协议豁免（数据块，记录层通用语义＝协议面）：`docs/agent/runs/`（运行记录投影）、`docs/progress-current.md`（生成投影）、`docs/issues/index.json`（状态真相源单写面）、`docs/changes.jsonl`（追加面）、`docs/agent/micro.jsonl`（道账本）；校准豁免（仓根 `delivery.rules` calibration 节 `dp_artifact_exempt`，逐仓不同的校准＝项目约定，票 72 自数据块迁入）：`docs/architecture/generated/`（生成投影面，理由注记随行）——文件缺失或无该行＝豁免消失，生成面文件按未登记 FAIL 暴露（fail-closed 方向），解析破坏 exit 2。懒创建许可＝`docs/agent/micro.jsonl`（道脚本首次收尾懒创建）。目标项目落位后按自身 artifacts.yaml 现状校准数据块（增删 `ca_*` 行）与 delivery.rules calibration 节，不改动引擎。

### 输出格式

```text
check-artifacts: SKIP: 条目 <id> 登记目标暂缺（数据块懒创建许可）: <path>
check-artifacts: FAIL: 条目 <id> 登记目标不存在: <path>
check-artifacts: FAIL: 受管文件未登记: <path>
check-artifacts: 正向: 登记目标 N 个，缺失 K 个，懒创建暂缺 S 个
check-artifacts: 反向: 受管文件 M 个，未登记 U 个，豁免命中 E 个
check-artifacts: PASS
```

- FAIL/SKIP 行先行定位（条目 id 或受管路径），两方向汇总行收口；任一缺口时结尾输出 `check-artifacts: FAIL（正向缺失 K，反向未登记 U）`。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 登记与实物全对账（含豁免命中与懒创建 SKIP）。 |
| 1 | 存在对账缺口（正向登记目标缺失或反向受管文件未登记；FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数数量不合、repo-root 不存在、artifacts.yaml 缺失或解析破坏、数据块不合预期）。 |

### 维护规则

- 产物增删/移动＝同步登记 `docs/agent/artifacts.yaml`（数据先行），实跑本脚本核对；登记聚合条目（glob/目录）覆盖语义见上文反向口径。
- 受管口径或豁免变更＝改数据块 `ca_*` 行（理由随行注记）＋实跑盘点＋同步本专节基线定谳表；豁免扩大的裁决归用户（投影/追加面/生成面类），不得为消缺口静默扩豁免。
- 行为语义变化经 Review 门禁并同步 harness check-artifacts 套件（正负例随动，红灯不隔票）。

## export-payload.sh（公开载荷导出单命令）

delivery.rules 驱动的公开载荷导出单命令（票 72；命令面权威＝票 69 设计 §3）：把票 68 手工三重核验固化为命令面。POSIX sh（`#!/bin/sh`、`set -eu`）；导出形态（前缀/远端/目标分支/本地导出分支）读仓根 `delivery.rules` payload 节（引擎零项目约定硬编码）；本命令永不 force——不内建任何改写远端历史的路径（force 属用户授权动作，票 68 修复即用户明确授权下的一次性救援）。

### 用法

```text
sh scripts/export-payload.sh [--dry-run] [repo-root]
```

- `repo-root` 缺省取本脚本所在目录向上两级；`--dry-run` 语义见下表。
- `-h` / `--help`：打印用法。

### 六步流程

| 步骤 | 动作 | 实跑 | `--dry-run` |
| --- | --- | --- | --- |
| 前置 | 工作区 payload 根内未提交改动即停（导出半成品）；未声明 payload 节拒跑 exit 2 | 是 | 是 |
| 1 split | `git subtree split -P <root>` 产出新导出头 H | 落本地分支 `-b <local_ref>` | 仅经变量传递，不落本地分支引用 |
| 2 树比对 | H 经 `git archive` 展开到全新 mktemp（即用即删），`diff -r` 对照工作区 payload 根须零差异 | 是 | 是 |
| 3 导出树 check-package | 临时展开目录内 17 项全过（检查 13 独立语境静默跳过＝预期，票 68 口径） | 是 | 是 |
| 4 ff 断言 | `git ls-remote` 取远端头 R；R 空＝首推放行；否则 `merge-base --is-ancestor R H`，失败＝污染停手（报错文案照设计逐字） | 是 | 是 |
| 5 push | `git push <remote> <local_ref>:<target>` 裸 push | 是 | 只打印将执行的命令 |
| 6 ls-remote 复核 | 再取远端头须等于 H（推送后漂移即停） | 是 | 跳过 |

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 流程完成（或 `--dry-run` 步骤 1～4 完成）。 |
| 1 | 流程失败停手（工作区不洁、树比对差异、check-package 未全过、ff 断言不过、push 被拒、推送后漂移）。 |
| 2 | 用法或配置错误（参数不合、非 Git 工作区、delivery.rules 缺 payload 节或解析破坏、payload 根不存在、git subtree 不可用）。 |

真实推送公开仓须用户现场授权；日常自证以 `--dry-run` 为准（零远端写、零本地分支写）。

## test-record-layer.sh（记录层回归 harness）

记录层共享回归 harness（票 49 沉淀）：把票 41～45/47 六票 Implementation Checkpoint 声明待沉淀的一次性 fixture 组装为常驻自检工具——一条命令回归记录层全链。POSIX sh（`#!/bin/sh`、`set -u`、`set -f`）、无 jq；open 本体校验路径依赖 python3 标准库，缺失即 exit 2（夹具 `git init` 依赖被测脚本自身声明的 Git）。缺省自测同目录包内脚本（check-package.sh 同款路径惯例），`--script-dir`/`--pkg-root` 参数化支持复制落位语境；被测脚本只读零改动（发现缺陷停报告，不顺手修、不为通过测试改预期）；夹具全部构建于 mktemp 临时目录并 trap 清理（异常退出亦清），仓库零写入；预期值按被测脚本当前行为独立重建（cmp/逐一相等断言，票 26 教训；来源票只作场景清单）。

### 用法

```text
sh scripts/test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
```

- 无参数：`--suite all`；被测脚本目录缺省＝本脚本所在目录，包根缺省＝被测脚本目录的上一级（check-package.sh 同款）。
- `--suite module-map|ticket-ops|progress|check-package|append-only|check-artifacts|stale-claims|all`：场景参数化，缺省 all。
- `--script-dir <dir>`：被测脚本所在目录（须含八件被测成员：`generate-module-map.sh`＋`module-map.rules`、`ticket-ops.sh`＋`generate-progress.sh`、`check-package.sh`、`check-append-only.sh`、`check-artifacts.sh`、`check-stale-claims.sh`）；对复制落位副本或被测脚本修改副本复跑时使用。
- `--pkg-root <dir>`：check-package 套件的包根，缺省＝script-dir 的上一级。
- `-h` / `--help`：打印用法。

### suite 覆盖场景表

| suite | 来源票 | 覆盖场景 | 断言数 |
| --- | --- | --- | --- |
| `module-map` | 42/43/44/45 | 11 语言夹具正例（nodes 19／edges 50 逐一相等＋stdout 摘要计数）＋fp-v1 形状／稳定性／变更检出＋负例 3（规则表损坏 exit 2、无源码 exit 1、非 Git exit 2，均零地图写入） | 10 |
| `ticket-ops` | 41/47 | 生成项目语境 open→take→flip 全链（索引／issues-README／投影全文件逐一相等＋账本行数；updated_at／开票日期捕获后校验形状重建预期）＋收尾投影 `--check`＋新 NN 正开正例＋负例（重复 id／未知 id／账本键序违规／take 非 in_progress／非法状态值／索引排版破坏／N7 同 NN 异 slug 拒开／N8 畸形 id（个位 NN 段）拒开／N-r1 本体缺 complexity_reason 拒开／N-r2 本体 priority_reason 空值拒开／N-r3 本体文件缺失拒开，均 exit 1 零写入） |  |
| `progress` | 35 | 投影生成（乱序 id＋checkpoint_ref 列）全文件逐一相等、`--check` 一致 exit 0、篡改检出 exit 1、投影缺失 exit 1、索引缺失／条目行缺必备字段 exit 2 | 7 |
| `check-package` | 12/48/57/58/59/60 | 十七项正例输出逐行逐一相等（含票 48 检查项 8、票 57 检查 9/10/11、票 58 检查 12/13、票 59 检查 14、票 60 检查 15/16/17——检查 13 PASS 行＝仓根镜像在位语境比对 2 对）＋必需件缺失负例（mktemp 包副本删件）exit 1 指名缺失件＋检查 9 表实漂移联动＋检查 17 机械行点名脚本缺失联动（R-DP-004 点名 generate-progress.sh）＋检查 11 逐处全等负例（§2.5 单处删值，FAIL 行按行号指名）＋票 58 负例：检查 12 注入词表首词入规则块体 exit 1 指名文件:行号（词自夹具包 manifest 提取，harness 零词面字面量）、注入行登记行级豁免后不报 exit 0（豁免生效）、豁免登记行无命中报失效豁免 exit 1、检查 13 仓根镜像同名件篡改 exit 1 指名文件、仓根无 scripts/ 时静默跳过（无输出行）＋票 59 负例：检查 14 注入未登记基元名入角色声明行 exit 1 指名文件、删除一基元名出角色声明行 exit 1 指名文件＋票 60 负例：索引删一行 exit 1 指名缺行、索引加全集外 ID exit 1 指名多行、机制列写未登记值 exit 1 指名、机械行点名不存在脚本 exit 1 指名、机械行点名检查项号超界 exit 1 指名、外定义行删标记词 exit 1 算漏行、mechanism-vocab 词表损坏 exit 2 | 21 |
| `check-artifacts` | 59/72 | check-artifacts.sh 正负例：全对账正例 exit 0（含懒创建面登记暂缺 SKIP 行与豁免命中不报）、登记目标缺失 exit 1 指名条目、受管文件未登记 exit 1 指名路径、豁免目录内未登记文件 exit 0 不报、票 72 校准豁免迁移三例（delivery.rules 声明 dp_artifact_exempt → generated 不报 exit 0；无 delivery.rules → 豁免消失按未登记 FAIL；delivery.rules 解析破坏 → exit 2）、登记解析破坏 exit 2 指名行与条目、无参数／repo-root 不存在 exit 2 | 11 |
| `stale-claims` | 72 | check-stale-claims.sh 配置点亮正负例：未点亮（无 delivery.rules）→ S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 2；点亮（dp_stale_lit S1＋S2 无 payload 节）→ 无 SKIP 行、断言逻辑执行（STALE 行证明）、汇总登记数 4（点亮数＋通用条数）；delivery.rules 解析破坏（未知指令）→ exit 2 指名违规行 | 3 |
| `append-only` | 58/87 | check-append-only.sh 正负例：changes.jsonl 尾部追加 exit 0（OK 行含追加计数）、micro.jsonl 同口径追加＋progress.md 零 diff exit 0、中间插入 exit 1 指名文件与首个违规行号、改写历史行／截断／工作树删除 exit 1、progress.md 篡改 exit 1、micro.jsonl 中间插入 exit 1（同口径）、无 Git 基线 WARN 退出 0、懒创建（新建账本 OK＋缺失 SKIP）exit 0、用法负例（无参数／多参数／非 Git 目录 exit 2）、票 87 迁移承继三例：迁移窗口 exit 0 双 OK（已迁移＋迁移承继）、迁移落位稳态 exit 0（后继 OK＋旧路径 SKIP）、承继不一致 exit 1 双 FAIL（后继新内容＋旧路径缺失） | 16 |
| （仅 all）注入自检 | 49 | 临时副本上故意注入一处规则表 label 破坏——harness 必须 exit 非零且输出 FAIL 行（测试自检，验证 harness 敏感度） | 2 |

断言计数为 2026-09-21 票 60 交付时点值，随维护增减（suite 汇总行按实际计数输出）。

### 输出格式与退出码

```text
PASS  [<suite>] <场景>                       # 或 FAIL（附「详情:」行）
test-record-layer: [<suite>] 断言 N/N 通过
test-record-layer: PASS（共 N 项断言，全部通过）    # exit 0
test-record-layer: FAIL（共 N 项断言，M 项失败）    # exit 1
```

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部断言通过。 |
| 1 | 存在失败断言（逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（`--suite` 不合口径、被测成员缺失、包根不存在、git 不可用）。 |

### 维护规则

- 被测行为合法变更时同步更新本 harness 断言（预期值重新独立重建，不照抄实跑输出）；module-map 专节"维护联动"所述规则表 fixture 回归由此 harness 承载，`--suite module-map` 即回归入口。
- 夹具不入仓：fixture 由 harness 运行时自建于 mktemp（每语言样例＋去重/注释/字符串负例，票 42～45 fixture 纪律），仓库零留样。
- 复制落位（生成项目语境）随记录层工具同迁（同 `ticket-ops.sh` 落位口径，见 `../references/templates/scripts-README.md.tmpl` 自检工具落位句）；落位后缺省自测同目录包内脚本，包内/落位两语境同码。

## 维护联动

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。检查 12 同理零词面自命中面：词表唯一承载点为 `package-manifest.rules` vague-words 节（`.rules` 不在 md/tmpl 扫描文件面），引擎与本 README 不写词面字面量，harness 夹具注入词自夹具包 manifest 提取。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
- 扫描器登记条目（断言模式/权威位置/校验方式）增删或权威位置迁移须同步脚本内登记表与本 README 登记；权威位置失效时扫描器输出 STALE 提示重新核对登记，处置方式是修正登记或修正现实，不得为通过检查改写权威位置的真实内容（R-06-004 同源纪律）；新条目按票 19 Checkpoint 记录的登记流程扩充。

## 构建规约

脚本写法约定（票 84；先包后仓——包侧为基准、仓侧镜像，随升级质询 dwfq-30d2bd9a-1 裁决两文件落位；原型＝agent-project-governance harness-design「Shell Harness Construction Rules」）。只约束新增与修改的脚本写法，既有脚本不回改（另票或随触碰自然对齐）；规约属约定非门禁——违反时机器无证据，不配断言，归评审人肉把关。

- 禁把检查写成传给 `eval` 的字符串。
- 禁在检查表达式内嵌命令替换（如 `$(find … | head -1)`）：先算好结果存变量再判，防 quoting 漂移与 `set -e` 误报。
- 优先用返回 shell 状态的 `check_*` 小函数（如 `check_file_exists`、`check_dir_exists`、`check_contains`）。
- 目录内容检查用预计算计数：先取计数存变量再比较，不在检查表达式内联展开。
