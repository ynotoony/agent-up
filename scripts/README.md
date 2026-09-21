<!-- Input: `check-package.sh` 的十一项检查实现（清单数据驱动，票 57）与 SPEC-06 §5、票 09/11 的例外登记事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；票 12（SPEC-06 §7）11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）；票 19（REQ-20260904-010）`check-stale-claims.sh` 的两模式、登记表条目与退出码实况；票 37（拆票计划 C 组②）道脚本改造事实——flips 索引条目口径（单写 docs/issues/index.json → 票正文 Status 投影打印件 → 生成器投影再生）、微账本 `docs/agent/micro.jsonl` JSON 行、S3 投影 vs 索引比对与 S1-1e 缺口消除、`generate-progress.sh` 入包（与本仓根 `scripts/` 基线 cmp 一致）；票 43 语言登记表 Rust 扩展事实（mod 文件边存在性核验＋use 路径表达式原串，四语言）；票 44 引擎表驱动化事实（语言知识外置 `module-map.rules`，引擎通用管线零语言专名，四语言边集逐边回归＋哑语言规则行产边实证）；票 45 七语言批量扩展事实（Go/Java/C#/Ruby/PHP/Swift/Kotlin 规则行＋fixture 回归，覆盖语言十一种，零引擎改动）；票 47（ticket-ops.sh 入包采纳：与本仓根 `scripts/` 基线 cmp 零差异复制、专节与落位口径——记录层标配不门控快道，包内不运行声明）；票 48（检查项 8 脚本必需件存在性守卫：六 `.sh`＋`module-map.rules`＋`scripts/README.md` 逐一存在性核对，fail-closed 指名缺失件，计数联动七项→八项）；票 49（`test-record-layer.sh` 记录层回归 harness 落位：票 41～45/47 六票 fixture 沉淀为四 suite 常驻自检工具，缺省自测同目录包内脚本、mktemp 夹具 trap 清理、预期值独立重建、注入自检）；票 56（安装政策单源化：`install-policy.rules` 政策数据表＋`install.sh` 安装脚本落位——安装政策映射唯一承载点改为外置数据、引擎零专名，检查 8 清单扩为 10 件）；票 57（包清单数据化：`package-manifest.rules` 五节数据单源落位——入口文件/脚本必需件/模板清单/短码登记/platform 枚举唯一承载点，check-package.sh 检查 1/5/8 改读数据、新增检查 9（scripts/README.md 成员表↔数据一致）/10（短码使用⊆登记）/11（platform 枚举登记处↔数据一致），检查项 8→11，口径差定谳＝test-record-layer.sh 定为必需件 kind 标 test-harness）。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、十一项检查说明（清单数据驱动）、包清单数据表格式、易腐断言扫描器两模式与登记表说明、投影生成器用法与退出码、模块地图生成器用法与语言登记表、道脚本收尾行为（索引单写机制）、票务运维脚本三子命令用法与落位口径、安装脚本用法/退出码与安装政策数据表格式、输出格式、退出码与维护联动规则。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。本目录同时是道脚本与票务运维脚本的安装源：安装政策（哪些脚本在什么门控下落位、每件复制基线路径与登记 lifecycle 值）以数据文件 `install-policy.rules` 为唯一承载点（外置数据、引擎零专名，先例 `module-map.rules`），复制动作经 `install.sh` 执行——目标项目用户确认启用分级交付道快道时以 `--fast-lane` 启用，采用任务票体系（`docs/issues/` 目录创建）时以 `--ticket-ops` 启用（两套独立门控，启用判定是用户决策，脚本只承接已确认的复制动作），落位与登记口径见 `../SKILL.md` 主流程步骤 5 与 `../references/templates/development-process.md.tmpl` §12.5，脚本用法/退出码/数据格式见下文专节。复制不改变参数语义——`[repo-root]` 缺省仍取当前目录所在 Git 仓库顶层（`generate-progress.sh` 缺省取脚本所在目录的上一级），与落位后用法一致。`generate-progress.sh` 与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致，两处同源演化须互为镜像并登记差异。`ticket-ops.sh` 包内文件与本仓根 `scripts/ticket-ops.sh` 基线 cmp 零差异（票 47 入包核对），两处同源演化须互为镜像并登记差异。包内落位基线脚本不运行：`ticket-ops.sh` 缺省 repo-root 取脚本所在目录的上一级，包内位置（`agent-up/scripts/`）误运行会错根，落位到目标项目 `scripts/` 后语义才正确；`install.sh` 为包侧安装器、只在包内语境运行（不落本仓 `scripts/` 镜像），自带包内误运行守卫——`--target` 解析后含 `agent-up/SKILL.md` 或 `SKILL.md`、或等于本脚本所在目录即拒绝（exit 1）。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、十一项检查、包清单数据表格式、输出格式、退出码与维护联动规则。 |
| `check-package.sh` | 包完整性检查 | 按十一项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004；票 57 起检查 1/5/8 清单自 `package-manifest.rules` 数据读取，检查 9/10/11 以数据为比对基准）；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
| `check-stale-claims.sh` | 易腐断言扫描器 | 登记表驱动的高流转状态句扫描（REQ-20260904-010 / 票 19；票 37 S3 改投影 vs 索引比对、消 S1-1e 恒触发缺口）；票收口拦截（gate，发现过期断言 exit 1）与会话启动警告（session，恒 exit 0）两模式；POSIX sh、全程只读、零外部依赖。详见下文专节。 |
| `check-gates.sh` | 快道门禁核对器 | 分级交付道快道的只读门禁核对（REQ-20260904-011 / 票 26）：工作区实际改动 ⊆ 白名单逐项比对 + 按清单重跑验证命令并记录退出码；POSIX sh、严格只读、零外部依赖。详见下文专节。 |
| `lane-commit.sh` | 快道收尾脚本 | 分级交付道快道的合同驱动收尾（REQ-20260904-011 / 票 26；票 37 单写机制改造）：门禁 → 白名单产品提交 → 索引单写（`docs/issues/index.json` 票状态真相源）→ 票正文 Status 投影打印件回写 → User Review Checkpoint 追加或微账本（`docs/agent/micro.jsonl`）落行 → 生成器投影再生并 `--check` 核对 → 记录提交（两段式，R-RC-003）；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-progress.sh` | 现役状态投影生成器 | 自 `docs/issues/index.json`（票状态真相源，一条目一行）生成 `docs/progress-current.md` 现役状态投影（Derived，生成器独占写；票 33 §5.1.4 / 票 35 落位、票 37 入包）；`--check` 为 dry-run 一致性核对；快道收尾由 `lane-commit.sh` 在索引单写后调用；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-module-map.sh` | 模块地图生成器 | 静态导入行提取生成 `<root>/docs/architecture/module-map.json` 检索索引（票 30 拍板方案 A / 票 42 首版 / 票 43 Rust 扩展 / 票 44 表驱动化 / 票 45 七语言批量扩展）：Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌（R-DP-015 算法，输入排除本图自身）；repo-root 参数化（缺省 git toplevel）；引擎为通用规则解释器（加载规则表→发现源码→匹配捕获→策略产边→存在性过滤→组装 JSON），语言知识外置 `module-map.rules`（每语言一行，引擎零语言专名，加语言＝加规则行零引擎改动）；POSIX sh、无 jq/python（stat 与 SHA-256 工具依赖声明见专节）、fail-closed。详见下文专节。 |
| `module-map.rules` | 模块地图语言规则表 | `generate-module-map.sh` 的语言提取规则唯一承载点（票 44 表驱动化）：每语言一行 `mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>`；strategy 枚举 extension-map（扩展名 glob 语言绑定）/unresolved-node（未解析节点引用直出）/module-path（模块路径文本直出）/direct-file（声明文件候选边＋存在性过滤）；编码语义见本表头部注释与下文专节；规则表缺失或不合预期时引擎 exit 2（fail-closed）。 |
| `install-policy.rules` | 安装政策数据表 | 安装政策映射唯一承载点（票 56 单源化；先例 `module-map.rules`：外置数据＋引擎零专名）：门控定义行 `ip_gate <gate> <flag> <说明>` 与每文件×每门控行 `ip_file <pkg-rel-path> <lifecycle> <gate> <说明>`（包内复制基线路径、登记 lifecycle 值、所属门控与角色说明；同一文件属多门控逐门控各一行，引擎按文件路径去重选取）；`install.sh` 加载时结构校验（字段数、token/flag/lifecycle/路径形态、(文件,门控) 唯一、同文件 lifecycle 一致、未定义门控引用、零文件门控），任一不合预期 exit 2（fail-closed）。 |
| `package-manifest.rules` | 包清单数据表 | 包结构清单唯一承载点（票 57 单源化；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）：五节行式数据——必需入口文件（`pm_entry`）、脚本必需件（`pm_script`，kind 区分普通脚本/规则表/test-harness）、.tmpl 模板清单（`pm_template`）、规则块短码登记（`pm_shortcode`）、platform 枚举（`pm_platform`）；`check-package.sh` 加载时结构校验（字段数、路径/kind/短码/platform 形态、各节内跨行不重复、五节缺一不可），任一不合预期 exit 2（fail-closed）；检查 1/5/8 清单与计数、检查 9/10/11 比对基准全部自本表读取，引擎零文件名零短码零枚举值清单。维护规则与行格式见下文专节。 |
| `ticket-ops.sh` | 票务运维脚本 | 协调层票务面单入口（票 41 本仓交付 / 票 47 入包采纳）：`open`（开票：索引新增条目 status=ready＋issues-README 目录清单追加行＋账本追加行）／`take`（领取：status=in_progress）／`flip`（状态翻转：状态机任意合法值）三子命令，索引与 README 锚点整行/单 token 机械改写，收尾调用 `generate-progress.sh` 再生 `docs/progress-current.md` 并 `--check` 核对；校验先于写入、fail-closed（索引一条目一行排版破坏、锚点不唯一、账本行不合键序即停止不写）；POSIX sh、零外部依赖（无 jq/python）。详见下文专节。 |
| `install.sh` | 安装脚本（包侧安装器） | 安装政策单源化的执行引擎（票 56）：按启用门控自查同目录 `install-policy.rules` 得复制集合，逐件 cp 自包 `scripts/` 至 `<target>/scripts/` 并 cmp 核验字节一致；预检先于复制（源缺失/目标漂移即停，零半套）；已存在且字节一致的同名件幂等跳过，不一致即停（reconcile 纪律不覆盖）；目标 `scripts/` 缺失时创建并输出 README 生成提示行（README 生成归执行体）；末尾输出登记建议块（每复制件一行 artifacts.yaml 十三字段建议值＋generation manifest 提示），不代写目标治理文件；POSIX sh、零外部依赖、fail-closed；引擎零脚本名零门控专名（加门控＝加规则行零引擎改动）；包侧工具，不落本仓 `scripts/` 镜像。详见下文专节。 |
| `test-record-layer.sh` | 记录层回归 harness | 六票（41～45/47）fixture 沉淀的常驻自检工具（票 49）：四 suite（module-map/ticket-ops/progress/check-package，`--suite` 参数化，缺省 all）一条命令回归记录层全链，逐项 PASS/FAIL＋计数，任一失败 exit 非零；缺省自测同目录包内脚本（对被测脚本只以显式 mktemp 夹具根/包根参数驱动，与 ticket-ops.sh「包内不运行」口径不冲突）；POSIX sh、零外部依赖、夹具 trap 清理、仓库零写入。详见下文专节。 |
| `scenario-checklist.md` | 场景验收清单 | SPEC-06 §7 发布前 11 条场景的验收边界、逐条执行结果与证据指针（票 12 / R-06-008）；S1-S9 为模板语义静态核对、S10 记 check-package.sh 实跑与临时副本负例及 `deferred-to-13` 条件项、S11 记 `N/A + reason`（未测量）；包内容变化后按本清单复验。 |

## 用途与用法

对 `agent-up` 公开包做发布前核对与包内容变化后自查：十一项检查全部通过才可宣称包完整；失败项逐条修复或报告，不为通过检查篡改包内容（R-06-004）。

```text
sh scripts/check-package.sh [package-root]
```

- 无参数：以脚本所在目录的父目录为包根（在本包内运行时，检的就是本包）。
- 带参数：以第一参数为包根（对 subtree 导出目录或临时目录副本复跑时使用）。
- `-h` / `--help`：打印用法。
- 脚本只读：除向 stdout/stderr 打印外无任何写操作；无网络依赖（不出网、无下载行为）。

## 检查项（十一项，清单数据驱动）

包结构清单的机器真相是数据文件 `package-manifest.rules`（五节，行格式与维护规则见下文专节）：检查 1/5/8 的清单与计数自数据读取，检查 9/10/11 以数据为比对基准核对登记面与使用面；本表为检查口径的人读说明，与数据表冲突时以数据表为机器真相。

| # | 检查 | 实现 |
| --- | --- | --- |
| 1 | 必需入口存在 | 清单 `entry-files` 节逐行 `test -f`（现 16 件：包根 `SKILL.md`、`README.md`、`LICENSE`；`references/` 下目录 README 与手册、`schemas/` 两 JSON——逐件名单见数据表，票 57 起不再硬编码于引擎）；任一缺失即 FAIL 并逐件指名（fail-closed）。 |
| 2 | `SKILL.md` frontmatter 为 `name: agent-up` | 首行 `---` 与闭合 `---` 之间存在 `name: agent-up` 行；frontmatter 缺失或未闭合判失败。 |
| 3 | 包内无旧标识残留 | `grep -rn` 全包扫描旧 Skill 标识字面量（本包改名前的原 Skill 名），零命中为通过；扫描范围含本目录。 |
| 4 | 无绝对路径与根治理引用 | `grep -rn` 扫描用户主目录绝对路径前缀（/Users 或 /home，带尾斜杠匹配）与根治理相对引用字面量（`../` 后接 docs 或 .zcode）。按票 09/11 结论，模板内 `../specs/` 等兄弟路径属目标项目生成语义，不在本项口径。 |
| 5 | 模板清单一致（数据↔磁盘↔manifest 双向；票 57 数据驱动） | `references/templates/` 下实际 `.tmpl` 与清单 `templates` 节集合一致（数量相等、互不缺多），且数据每件在 `templates/README.md` manifest 目录清单节有登记行、manifest 登记的每个 `.tmpl` 都在数据内——manifest 表＝人读投影，数据＝机器真相，双向漂移即 FAIL。 |
| 6 | 文本契约头齐全 | `*.md` 与 `*.tmpl` 在检测窗口内含 `Input:`/`Output:`/`Pos:` 三行：无 frontmatter 的文件取前 5 行，首行为 `---` 的文件取 frontmatter 结束后的 5 行（frontmatter 未闭合判失败）。例外：`artifacts-yaml.tmpl` 以 YAML `#` 注释承载（前 5 行含 `# Input:`/`# Output:`/`# Pos:`，登记见 `templates/README.md`）；`LICENSE` 与 `schemas/*.json` 不属扫描范围（JSON 以 `$id`/`title`/`description` 承载导航元数据，例外登记见 `schemas/README.md`）。 |
| 7 | 根治理文件不在包内 | 包根不存在 `AGENTS.md`（文件）、`docs/`（目录）、`.zcode/`（目录）。 |
| 8 | 脚本必需件存在（票 48；票 56 扩清单；票 57 数据驱动） | 清单 `scripts` 节逐行 `test -f`（现 10 件：`scripts/` 下七 `.sh`（check-gates、lane-commit、check-stale-claims、generate-progress、generate-module-map、ticket-ops、install）、两规则表（`module-map.rules`、`install-policy.rules`）、`test-record-layer.sh`——票 57 口径差定谳定为必需件，kind 标 `test-harness`）；任一缺失即 FAIL 并逐件指名缺失件（fail-closed，不因部分存在而放宽）。增删包内脚本成员须同步数据表 `scripts` 节。 |
| 9 | scripts/README.md 成员表与数据 scripts 节一致（票 57 新增） | 双向口径：①清单 `scripts` 节每件都在成员表登记（表＝人读投影不得漏登必需件）；②成员表登记的每件都是 `scripts/` 下实际文件（表与实物不漂移）。成员表提取锚点＝首列 `名字/地位/功能` 表头行。 |
| 10 | 规则块短码使用均在登记内（票 57 新增） | 扫描包内全部 `*.md` 与 `*.tmpl`（同检查 6 文件面）提取规则块 ID `R-<短码>-<三位序号>` 的两字母前缀，与清单 `shortcodes` 节比对：使用⊆登记；SPEC 规格号（`R-02-001` 形态，数字段）不落入提取模式。短码全集以 grep 实测为准（现 16 个），新增短码先登记数据表再使用。 |
| 11 | platform 枚举登记与数据一致（票 57 新增；逐处全等） | 各登记处值集合与清单 `platform-enum` 节逐处全等（任一处缺值/多值/改值即不一致，FAIL 行按行号指名漂移处）：`references/templates/artifacts-yaml.tmpl` platform 字段注释区（锚点＝`当前已知集合：` 标记）、`references/adapters/capability-contract.md` 内每个「已知集合」句（frontmatter 与 §2.5 各一处，各自单独比对，不并集）；提取锚点为登记标记文本，值集合以数据为权威。 |

## 输出格式

```text
PASS: <编号> <描述>
FAIL: <编号> <描述> — <单行详情>
FAIL: <编号> <描述> 详情：
  <多行详情逐行缩进两空格>
check-package: PASS
```

- 十一项检查逐项输出一行 PASS 或 FAIL；任一失败时结尾输出 `check-package: FAIL（N 项未通过，共 11 项）`，全部通过时结尾输出 `check-package: PASS`。
- FAIL 详情为可定位信息：文件清单、命中行（`路径:行号:内容`）或计数差异。

## 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 十一项检查全部通过。 |
| 1 | 存在未通过项（逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等；数据校验 fail-closed，不产生部分结论）。 |

## package-manifest.rules（包清单数据表）

包结构清单唯一承载点（票 57 单源化；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）。`check-package.sh` 启动时 source 本表（与脚本同目录），检查 1/5/8 的清单与计数、检查 9/10/11 的比对基准全部自数据读取，引擎零文件名零短码零枚举值清单——加成员、加短码、加 platform 值＝加一行数据＋改对应实物，零引擎改动。

### 行格式（五节）

| 指令 | 字段数 | 语义 |
| --- | --- | --- |
| `pm_entry <pkg-rel-path>` | 1 | 必需入口文件，包根相对路径（检查 1）。 |
| `pm_script <pkg-rel-path> <kind> <说明>` | 3 | 脚本必需件，须 `scripts/` 前缀加单段文件名（检查 8）；`kind` ∈ `script`（普通脚本）/`rules`（规则表）/`test-harness`（回归 harness）——票 57 口径差定谳：`test-record-layer.sh` 定为必需件，kind 标 `test-harness`。 |
| `pm_template <basename>` | 1 | `.tmpl` 模板文件名（检查 5，与 `references/templates/README.md` manifest 表双向）。 |
| `pm_shortcode <CODE> <owner>` | 2 | 规则块两字母短码与其所属文件包内相对路径（检查 10：使用⊆登记；与 `references/` 各目录 README 短码登记面同源）。 |
| `pm_platform <value>` | 1 | platform 枚举值（检查 11，与 `artifacts-yaml.tmpl` 注释区、`capability-contract.md` 登记处一致）。 |

### 结构校验（fail-closed）

引擎加载时逐行核验，任一不合预期 exit 2，不产生部分结论：字段数恰如上表（字段内禁制表符）；路径禁前导斜杠、空白与 `..` 段，`pm_script` 须 `scripts/` 前缀单段名，`pm_template` 须单段 `.tmpl` 名，`pm_shortcode` 短码两字母大写且 owner 须 `references/` 前缀，`pm_platform` 值须小写 token；`kind` 枚举三值；各节内路径/文件名/短码/值跨行不重复；五节每节至少一行。

### 维护规则

清单变更先改数据再改实物（数据先行）；本表与 `scripts/README.md` 成员表、`references/` 各目录 README 登记面为「数据＝机器真相、表＝人读投影」关系，一致性由检查 5/9 机械核对，漂移即 FAIL（表文修正归人工裁决，不静默互改）。短码或 platform 新值：先在数据表登记，再按 `references/protocol/governance-format.md` 与 `references/adapters/capability-contract.md`（R-CC-005）流程落登记面与实物。

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

登记表内置于脚本，条目结构为 `{断言模式, 权威位置, 校验方式}`，只登记高流转状态句。首批三条（权威位置为现行文档真实路径）：

| 编号 | 断言模式 | 权威位置 | 校验方式 |
| --- | --- | --- | --- |
| S1 | Git 状态句 | `docs/progress.md` 的「Git 恢复基线」块 | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、唯一 remote 与宣称地址一致、本地 main 未被远端跟踪分支包含）；非 Git 工作区按流程退化语义输出提醒跳过。（票 37 修订：移除"工作区存在未提交改动"子项核对——该陈述为票 13 时点历史快照，`docs/progress.md` 现为冻结历史档案（零写入），清洁工作区属稳态，逐字核对构成恒触发误报（S1-1e 已知缺口）；基线块原文按"不改历史"保留。） |
| S2 | 发布状态句 | 根 `README.md`「公开包已发布」宣称行 + `agent-up/README.md` 安装行 | machine：文档宣称的仓库地址与实际 remote origin 配置归一化比对、包内安装行同源核对；远端可达性/可见性本地不核验（不出网）→ reminder。 |
| S3 | frontier 句 | `docs/issues/index.json`（票状态真相源）+ `docs/progress-current.md`（现役状态投影） | machine：投影 vs 索引比对——优先调用 `generate-progress.sh --check`（exit 0 一致；exit 1 投影 stale 或缺失；exit 2 索引缺失或条目排版不合预期）→ 差异即过期断言；生成器不可用时退化为内建最小比对（id/status/updated_at 三元组）并输出 NOTE 说明（不计入失败）。（票 37 修订：原"`docs/issues/README.md` 表行逐票对照票面状态"实现退役——README 状态列已定位为人工登记投影（票 35 起），与索引冲突时以索引为准。） |

机器可校验项直接对现实核验；不可机器校验项输出存在时长提醒（WARN，阈值【待定】，定稿后同步本登记）。

### 输出格式

```text
STALE: <路径:行号> — <断言与现实的差异说明>
WARN: <路径:行号> — <提醒内容（含登记日期与【待定】阈值标注）>
NOTE: <路径> — <比对机制退化说明（生成器不可用时退化为内建最小比对；不计入失败）>
check-stale-claims: PASS（登记表 3 条全部核对，提醒 N 条）    # gate 模式清洁
check-stale-claims: FAIL（N 处过期断言，登记表共 3 条）       # gate 模式存在过期断言
check-stale-claims: 会话启动模式（不拦截）：过期断言 N 处，提醒 N 条，请人工核对上方输出
```

- STALE 行含 `路径:行号` 定位与差异说明；WARN 行为提醒（非失败）；NOTE 行为 S3 比对机制退化说明（非失败）；结尾汇总行给出计数与结论。
- S3 生成器定位顺序：本脚本同目录（包内自含）→ 仓库根 `scripts/`（落位安装形态）；两处均不可用才退化内建最小比对。两模式对生成器退出码的语义映射一致：差异与异常均计 STALE，gate 拦截 / session 警告。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | gate 模式下无过期断言（提醒照常输出），或 session 模式。 |
| 1 | gate 模式下存在过期断言（STALE 行见输出）。 |
| 2 | 用法或环境错误（参数过多、模式非法、仓库根不存在等）。 |

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
| `lane: user-review` 或 `lane: micro` | 必需，恰一行；取值仅 `user-review` 或 `micro`。 |
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

1. 合同解析与语义校验（车道组合、必填行缺失、禁止组合、索引翻转车道/id/取值校验；先于任何写入）。
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
| 1 | 门禁不过或合同 fail-closed 条件（合同格式错误、车道必填缺失或禁止组合、白名单越界、verify 失败、索引缺失或排版不合预期、正文 Status 行锚点不合规、翻转锚点不合规、生成器不可用、投影再生或 `--check` 未过、暂存越出白名单、白名单内无实际改动等）；预检与门禁阶段的停止零提交零写入，记录写入阶段的停止保留产品提交并输出指路。 |
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

协调层票务面写入单入口（票 41 本仓交付 / 票 47 入包采纳；行为基线＝development-process 模板 §12.5 票务脚本承载注记与 §6 零写入三段式第二段）：开票、领取与收口状态翻转、`docs/issues/index.json` 单写、issues-README 状态列登记、`docs/changes.jsonl` 账本落行、`docs/progress-current.md` 投影再生，六个写入面逐项经本脚本承载。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖（仅 POSIX 标准工具与内建，无 jq/python）、fail-closed——校验先于写入，索引一条目一行排版破坏、README 行缺失或锚点不唯一、账本行不合键序即停止不写；收尾投影再生缺失或 `--check` 不过即整体失败，已写部分如实报告。

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

## test-record-layer.sh（记录层回归 harness）

记录层共享回归 harness（票 49 沉淀）：把票 41～45/47 六票 Implementation Checkpoint 声明待沉淀的一次性 fixture 组装为常驻自检工具——一条命令回归记录层全链。POSIX sh（`#!/bin/sh`、`set -u`、`set -f`）、零外部依赖（夹具 `git init` 依赖被测脚本自身声明的 Git）。缺省自测同目录包内脚本（check-package.sh 同款路径惯例），`--script-dir`/`--pkg-root` 参数化支持复制落位语境；被测脚本只读零改动（发现缺陷停报告，不顺手修、不为通过测试改预期）；夹具全部构建于 mktemp 临时目录并 trap 清理（异常退出亦清），仓库零写入；预期值按被测脚本当前行为独立重建（cmp/逐一相等断言，票 26 教训；来源票只作场景清单）。

### 用法

```text
sh scripts/test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
```

- 无参数：`--suite all`；被测脚本目录缺省＝本脚本所在目录，包根缺省＝被测脚本目录的上一级（check-package.sh 同款）。
- `--suite module-map|ticket-ops|progress|check-package|all`：场景参数化，缺省 all。
- `--script-dir <dir>`：被测脚本所在目录（须含五件被测成员：`generate-module-map.sh`＋`module-map.rules`、`ticket-ops.sh`＋`generate-progress.sh`、`check-package.sh`）；对复制落位副本或被测脚本修改副本复跑时使用。
- `--pkg-root <dir>`：check-package 套件的包根，缺省＝script-dir 的上一级。
- `-h` / `--help`：打印用法。

### suite 覆盖场景表

| suite | 来源票 | 覆盖场景 | 断言数 |
| --- | --- | --- | --- |
| `module-map` | 42/43/44/45 | 11 语言夹具正例（nodes 19／edges 50 逐一相等＋stdout 摘要计数）＋fp-v1 形状／稳定性／变更检出＋负例 3（规则表损坏 exit 2、无源码 exit 1、非 Git exit 2，均零地图写入） | 10 |
| `ticket-ops` | 41/47 | 生成项目语境 open→take→flip 全链（索引／issues-README／投影全文件逐一相等＋账本行数；updated_at／开票日期捕获后校验形状重建预期）＋收尾投影 `--check`＋负例 6（重复 id／未知 id／账本键序违规／take 非 in_progress／非法状态值／索引排版破坏）exit 1 零写入 | 22 |
| `progress` | 35 | 投影生成（乱序 id＋checkpoint_ref 列）全文件逐一相等、`--check` 一致 exit 0、篡改检出 exit 1、投影缺失 exit 1、索引缺失／条目行缺必备字段 exit 2 | 7 |
| `check-package` | 12/48/57 | 十一项正例输出逐行逐一相等（含票 48 检查项 8、票 57 新增检查 9/10/11）＋必需件缺失负例（mktemp 包副本删件）exit 1 指名缺失件＋检查 9 表实漂移联动（单缺失件为单行 ` — 详情` 形态）＋检查 11 逐处全等负例（§2.5 单处删值，FAIL 行按行号指名；协调层改判随票修） | 6 |
| （仅 all）注入自检 | 49 | 临时副本上故意注入一处规则表 label 破坏——harness 必须 exit 非零且输出 FAIL 行（测试自检，验证 harness 敏感度） | 2 |

断言计数为 2026-09-20 交付时点值，随维护增减（suite 汇总行按实际计数输出）。

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

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
- 扫描器登记条目（断言模式/权威位置/校验方式）增删或权威位置迁移须同步脚本内登记表与本 README 登记；权威位置失效时扫描器输出 STALE 提示重新核对登记，处置方式是修正登记或修正现实，不得为通过检查改写权威位置的真实内容（R-06-004 同源纪律）；新条目按票 19 Checkpoint 记录的登记流程扩充。
