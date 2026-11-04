<!-- Input: 每次导出波的实际变更面（源仓收口提交与账本）；波级粒度，一次导出推送一条记录。 -->
<!-- Output: 消费者视角的更新说明：新增了什么、行为怎么变、老仓要不要跟；最上新在下，溯源细节不在此展开。 -->
<!-- Pos: 包根更新说明（波级 CHANGELOG）；升级流程配套——消费者 git pull 后读本件判断要不要跟，落地面差距核对跑 scripts/upgrade-check.sh，升级主链在 references/upgrade.md。 -->

# 更新说明

本包的更新以**波**为单位发布：每次导出推送一条记录，最上新在下。每条只写消费者视角的变更面（新增了什么、行为怎么变、老仓要不要跟），溯源细节不在此展开。

已按本体系初始化的项目要跟上新版：跑 `sh <包目录>/scripts/upgrade-check.sh <包目录> <你的项目根>` 看你仓里已装部分与包新版的差距，按 `references/upgrade.md` 走升级流程。

## 2026-11-04（治理运行时与证据链硬化波：安装闭包、用户故事契约、可恢复编排；覆盖 2026-10-28 以来累计 44 张已收口票）

- **运行时依赖只认安装闭包**（本波）：`ticket-ops.sh`／`contract-build.sh`／`ledger-append.sh`／`ticket-run.sh`／`run-record.sh`／`test-checkpoint-recovery.sh` 删除全部 `repo_root/agent-up` 工作树回退，唯一 JSON 引擎与 schema／规则／prompt 数据件只认脚本同目录与邻接 `../references/`；闭包缺失即 fail-closed 零写入，报文指名缺失绝对路径与升级／修补入口（`references/upgrade.md`、`scripts/install.sh`）。本地闭包与包工作树副本内容不同时以本地为准；新增 runtime-closure 套件（13 条定位正负例与零写入指纹）。**升级后 `rules/implementation/references/` 数据闭包必须在场，否则运行入口按设计 fail-closed。**
- **新开 task 卡必填用户故事**（本波）：`ticket-record.schema.json` 新增 `user_stories`（数组、至少一条、条目格式 `US<n>: 作为…，我要…，以便…`）；`ticket-ops open` 经 `json-validator --new-ticket` 对缺项／空数组／非数组／格式不符机械拒收且四载体零写入；向前生效、存量读取零回扫；示例、票模板、assessment 与 AGENTS 路由句同口径。
- **票务编排与恢复**：`ticket-run.sh` 可恢复协调器（next／start／contract／record／verify-dispatch）与 repair 纠偏；派发合同四模式校验（模板零差集／执行体自查／派发前置／步数预算）；步数预算与到线收尾、短上下文别名与模型档位登记；记录层互斥锁、记录提交前缀门、索引单写与崩溃恢复收敛。
- **证据与门禁**：`ticket-audit.sh` 十一谓词审计引擎（merge／push 证据门）；done／merge 收口双证（actual_time＋合并证据）；push 面批量审计兜底；门禁执行隔离、角色权限守卫、包级语义一致性门禁；对抗金丝雀 G1–G5 与 10 条核心规则负例。
- **目录 README 契约**：四段式结构（`--check`）＋生成块同步（`--sync`）＋新鲜度（`--freshness`）＋迁移预演（`--migrate-dry-run`）；收口前结构／新鲜度两检，生成器与范围规则随安装闭包落位。
- **适配器与宿主配置**：能力差异数据表与宿主差异段生成器；公共规则去重与结构基线；角色与包入口术语统一；宿主配置对账（`host-config.sh`）。
- **测试面**：harness 硬化与快慢分层、静态检查与空转加固、包内计数去漂移、`--suite all` 断言数不再硬编码。
- **要不要跟**：已初始化项目建议按 `references/upgrade.md` 升级（运行入口现为 fail-closed，升级后 `rules/implementation/scripts/` 应含 `ticket-audit.sh`／`generate-dir-readmes.sh`／`dir-readme.rules` 等安装件，`rules/implementation/references/` 应有 schema／protocol／prompt 数据闭包）；新开 kind=task 卡须带 `user_stories`。仅使用规则文档、未安装票务脚本的项目不受影响。

## 2026-10-28（脚本事职责拆分波：快道收尾的记录写入外移，单件单责）

- **快道收尾拆分**：`lane-commit.sh` 只保留合同预检与白名单提交，记录写入改由三件原子层代理——索引翻转仍经 `ticket-ops.sh flip-index`，新增 `checkpoint-write.sh` 承载 User Review Checkpoint 写入，微账本行改经 `ledger-append.sh --micro` 落行（`ledger-append.sh` 由此同时成为 `changes.jsonl` 与 `micro.jsonl` 两账本唯一写入方）。CLI 与提交合同格式不变，调用方无需改命令；三件代理均同目录优先、PATH 回退，缺失即收尾预检停止（零提交零写入）。
- **`checkpoint-write.sh` 契约**：`review-checkpoint` 子命令按票体形态写记录块（`.md` 票追加票尾；`.json` 票体零追加、落 `<id>-review-checkpoint.md`），记录块格式与拆分前逐字节一致；stdout 末行 `checkpoint-write: 目标文件: <rel>` 为机器契约，供 lane-commit 登记记录提交面。安装闭包随快道门控补 `checkpoint-write.sh` 与 `ledger-append.sh`。
- **要不要跟**：启用分级交付道快道的项目建议跟（否则新 lane-commit 因代理缺失而在收尾预检停止）；升级后 `rules/implementation/scripts/` 应同时出现 `checkpoint-write.sh`、`ledger-append.sh`。未启用快道、仅用票务脚本的项目不受影响（`ledger-append.sh` 行为向后兼容，`--micro` 为新增模式）。

## 2026-10-26（文档分层波：README 回到索引与指针，执行契约与历史各归其位）

- **README 分层**：包内目录 README 收敛为成员、用途、入口与指针——schemas/README 不再承载唯一执行语义，scripts/README 不再兼任历史决策载体；templates/README 目录清单节＝当前 manifest，「取舍与过渡登记」历史档案原位保留（其条目行号是包清单数据表 layout-compat-exempt 节按检查 24 登记的锚点，整节迁出须联动数据表与测试夹具，归后续票承载），本波起新增迁移决策追加至本文件。
- **workflow 执行契约迁移**：schemas/README「workflow executor 支持子集」节的执行合同正文逐字迁至 `references/schemas/workflow.schema.json` 顶层 `description`（唯一声明处；零语义变化），原节改为 legacy 指针、入站引用可溯；workflow-contract 套件回归锁定不变；2026-10-28 合并重整随动：迁入正文按「条件语义结构化」定稿（2026-10-27 并入，溯源见提交历史与仓库票本）同步至现行节文——六键结构化步骤结果＋可实现条件词表，剥反引号与声明路径适配口径不变，仍零语义变化。
- **历史决策记录迁入**：scripts/README 契约头的历史决策记录与目录序言的入包采纳核对记录原文迁入下方两节，事实零删改；2026-10-28 合并重整随动：并行定稿（派发合同链，提交 cd152d4）追加的现行定稿事实按指针形态留驻 scripts/README 契约头 Input 现行事实句，其定稿史句续录于下方历史决策记录节末。
- **要不要跟**：纯包内文档分层，零行为、零脚本变化；未安装这些包内目录 README 的存量项目零影响。

### 自 scripts/README.md 契约头迁入：历史决策记录原文（2026-10-26 原样搬运）

<!-- Input: `check-package.sh` 的二十六项检查实现（清单数据驱动）与 SPEC-06 §5、包重组与例外登记的定稿事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；SPEC-06 §7 的 11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）；REQ-20260904-010 `check-stale-claims.sh` 的两模式、登记表条目与退出码实况；道脚本单写机制改造事实——flips 索引条目口径（单写 docs/issues/index.json → 票正文 Status 投影打印件 → 生成器投影再生）、微账本 `docs/agent/micro.jsonl` JSON 行、S3 投影 vs 索引比对与 S1-1e 缺口消除、`generate-progress.sh` 入包（与本仓根 `scripts/` 基线 cmp 一致）；语言登记表 Rust 扩展事实（mod 文件边存在性核验＋use 路径表达式原串，四语言）；引擎表驱动化事实（语言知识外置 `module-map.rules`，引擎通用管线零语言专名，四语言边集逐边回归＋哑语言规则行产边实证）；七语言批量扩展事实（Go/Java/C#/Ruby/PHP/Swift/Kotlin 规则行＋fixture 回归，覆盖语言十一种，零引擎改动）；ticket-ops.sh 入包采纳事实（与本仓根 `scripts/` 基线 cmp 零差异复制、专节与落位口径——记录层标配不门控快道，包内不运行声明）；检查项 8 脚本必需件存在性守卫定稿（六 `.sh`＋`module-map.rules`＋`scripts/README.md` 逐一存在性核对，fail-closed 指名缺失件，计数联动七项→八项）；`test-record-layer.sh` 记录层回归 harness 落位事实（六票 fixture 沉淀为常驻自检工具，缺省自测同目录包内脚本、mktemp 夹具 trap 清理、预期值独立重建、注入自检）；安装政策单源化定稿（`install-policy.rules` 政策数据表＋`install.sh` 安装脚本落位——安装政策映射唯一承载点改为外置数据、引擎零专名，检查 8 清单扩为 10 件）；包清单数据化定稿（`package-manifest.rules` 数据单源落位——入口文件/脚本必需件/模板清单/短码登记/platform 枚举唯一承载点，check-package.sh 检查 1/5/8 改读数据、新增检查 9（scripts/README.md 成员表↔数据一致）/10（短码使用⊆登记）/11（platform 枚举登记处↔数据一致），口径差定谳＝test-record-layer.sh 定为必需件 kind 标 test-harness）；小断言打包定稿（检查 11→13——检查 12 规则块体模糊措辞扫描（词表与行级豁免外置 `package-manifest.rules` vague-words/vague-exemptions 节，依据 R-GF-010，引擎零词表硬编码）、检查 13 镜像脚本与仓根同名件 cmp（mirrors 节登记，仓根无 scripts/ 或无同名件静默跳过）；`check-append-only.sh` Record 只追加守卫新建（changes.jsonl/micro.jsonl 尾部追加前缀语义＋progress.md 冻结零 diff，承接 Record 行级保护候选口径）；lane-commit.sh 微道预检两断言（白名单 ≤3、改动集零新建零删除）；harness 扩为五 suite（新增 append-only suite，check-package 套件断言随 12/13 增））；对账＋能力一致性定稿（检查 13→14——检查 14 能力映射一致性（九基元名单与检查目标外置 `package-manifest.rules` capability-primitives 节，基元名自 capability-contract.md §2.1 权威表现场提取，引擎零基元名硬编码；三角色 .tmpl 声明行＋五适配文件对照表逐一双向全等核验，锚点失效 exit 2）；`check-artifacts.sh` 治理产物对账器新建（artifacts.yaml 登记目标存在性＋受管口径登记覆盖双向对账，受管口径与豁免落数据块）；harness 扩为六 suite（新增 check-artifacts suite，check-package 套件断言随 14 增））；规则索引定稿（模板 `development-process.md.tmpl` 新增 §16 规则索引节（49 行三列表＝47 定义＋2 外定义标注，节头三件＝投影声明＋受控三值定义＋诚实性上限声明），检查 14→17——检查 15 索引 ID 集合与包内规则块 grep 并集全等（外定义行豁免比对但须显式标注外定义标记词，未标注算漏行）、检查 16 机制列受控词表（词表外置 `package-manifest.rules` mechanism-vocab 节，引擎零词表硬编码）、检查 17 机械行点名脚本存在且在册＋检查项号不超界；`check-append-only.sh`/`check-artifacts.sh` 补登记清单 scripts 节（10→12 件，检查 17 在册口径的联动缺口）；check-package 套件断言随三查增）；S4 计数漂移哨兵定稿（登记表 S1-S3→S1-S4——S4-① README「任务票 NN；」锚点行数↔index 任务条目数相等断言（ticket-ops 双写锁定面漂移检测）、S4-②「N～M 共」「共 N 量词」计数模式扫描（STALE-prone 指名 file:line 计入过期断言计数，gate exit 1 / session 只警告）；扫描面排除三类历史/生成面（docs/progress.md 冻结档案、docs/changes.md 只追加账本、docs/architecture/generated 生成投影——协调层 2026-09-21 裁决 O3，既排 docs/issues/*.md 票面、docs/agent/runs/、docs/progress-current.md 保留）；豁免表显式实装、空表交付＝现行面全数字免费；输出格式增 STALE-prone 行与登记计数 3→4）；delivery 配置定稿（`export-payload.sh` 公开载荷导出单命令新建（delivery.rules 驱动六步、--dry-run、永不 force，检查 8 清单 12→13 件）；check-stale-claims S1/S2 配置点亮（dp_stale_lit、remote 名/包前缀/本地分支读仓根 delivery.rules、SKIP 行与汇总登记数动态化）；check-artifacts 校准豁免迁移（docs/architecture/generated/ 自数据块迁入 delivery.rules calibration 节）；harness 扩为七 suite（新增 stale-claims 套件，check-package/check-artifacts 套件断言随动））；存量清算定稿（`run-record.sh`/`ticket-grade.sh` 入包采纳——与本仓根同名件 cmp 零差异复制，先包后仓包为基准仓侧为镜像，检查 8 清单 13→15 件、检查 13 mirrors 2→4 对；成员行登记，用法承载归脚本 `-h` 与头部注释，本目录不设专节）；账本行型扩展定稿（`ticket-ops.sh` `--ledger-line` 校验从恰五键改为五键必备＋按 kind 条件键——lesson 必带第六键 promoted_to（枚举 新票/rules/sop/validator/test/none）、replan 必带 replan_original/replan_replacement/replan_undone（布尔），既有五键行向后兼容；2026-10-10 lesson 行型再扩：可选追加三分数键 score_contract/score_predicate/score_rework（0-100 整数或 -1＝N/A，键序固定，带分数则恰九键）——复盘三机械分结构化承载，ticket-ops 套件五例随动；ticket-ops 套件正负例随动，本专节数据载体句与 suite 覆盖表同步）；R-DP-033 加固定稿（check-stale-claims 登记表增 S5 方案结论标注句——结论行 file: 出处＋轨:受控两值格式断言、向前生效只查工作区新增/修改面、扫描面 glob 清单显式登记防过宽；stale-claims 套件登记数期望随动＋S5 正负例四，suite 覆盖表 stale-claims 行计数删格纪律）；S6 终态哨兵定稿（check-stale-claims 登记表增 S6——票状态索引 id 曾达 done/superseded 被改回非终态即 STALE 指名票 id 与跃迁方向，终态史取该索引 Git 现行提交历史为基线锚（零新增数据源；非 Git／无基线提交退化 WARN），登记计数 5→6；test-record-layer stale-claims 套件登记数期望随动＋S6 正负例四，suite 覆盖表随动）；S7 替代标记存在性定稿（check-stale-claims 登记表增 S7——索引条目 superseded_by 指向票存在性硬断言（悬挂/链环 STALE、非终态指向 WARN 先标后收、缺字段零回扫零报），登记计数 6→7；stale-claims 套件登记数期望随动（未点亮 4→5、全点亮 6→7）＋S7 正负例四，suite 覆盖表随动）；upgrade-check 块级核对定稿（模板生成件从只提示升为规则块 ID 集核对——实例缺块=落后逐块列 ID、多余块=登记分歧候选只提示不误报；标准四节报告承载 upgrade.md §5；harness 新增 upgrade-check suite 三断言，--suite 枚举与覆盖表随动）；ShellCheck 门禁面定稿（harness 新增 shellcheck 套件两断言——被测目录全量 .sh 零告警＋`# shellcheck disable=SCxxxx` 指令逐项同行带理由注释（无证豁免 FAIL 指名文件:行号），环境缺 shellcheck 时套件零断言跳过（NOTE 行明示，不制造假绿）；check-stale-claims.sh 缺省根推导翻转为按落位形态自推导——`agent-up/scripts/` 上两级、`rules/implementation/scripts/` 上三级、其余落位 exit 2 fail-closed 指名推导失败，无参裸跑＝显式传参语义对齐，stale-claims 套件随动回归三例，脚本头注与用法同面翻转）。；包闭合性定稿（检查 19→20 新增检查 20 包闭合性与符号链接防护——三段防线：①scripts/ 一级条目闭合（闭合白名单＝清单 scripts 节登记件∪引擎自身∪成员表∪清单数据件自身，未登记额外文件含隐藏条目即 FAIL 指名条目）；②包内 symlink 防外指（readlink 原始目标词法折叠＋包根词法域比对，POSIX 通行零 GNU readlink -f 依赖，越出包根或断链即 FAIL 指名）；③登记路径 symlink 禁令（检查 1 entry-files 登记路径与 references/、scripts/ 目录为 symlink 即 FAIL，包内别名或包外指向一体拦截）；零 git 依赖，非 git 语境照常运行（与检查 19 非 git 静默跳过语义区分）；harness 补三负例（scripts 未登记额外件/symlink 混合面/非 git 语境照常运行），check-package 套件断言 26→29）。；upgrade-check 块级核对定稿（模板生成件从只提示升为规则块 ID 集核对——实例缺块=落后逐块列 ID、多余块=登记分歧候选只提示不误报；标准四节报告承载 upgrade.md §5；harness 新增 upgrade-check suite 三断言，--suite 枚举与覆盖表随动）；派发合同校验器入包定稿（`check-dispatch-contract.sh` 双模式＋schema 数据件 `../references/schemas/dispatch-contract.schema.json`——placeholders 28 占位符全集与 contract_fields 三阶段必备字段（implementation 16／review 6／commit 6），模板比对面＝`../references/prompts/` 三件 `*-prompt.md` 显式列举（templates 三角色合同骨架零占位符不入比对面）；三角色合同模板 §1 加「收到合同首步」自查句（引用本脚本 --check）；检查 1 清单 16→17 件、检查 8/19 清单 26→27 件、harness 扩为 17 套件（新增 dispatch-contract 套件），check-package 套件金样串计数随动）；workflow 执行子集合同定稿（`references/schemas/README.md` 新增「workflow executor 支持子集」节＋`workflow.schema.json` 字段级语义注记（inputs/outputs/depends_on/on_failure/fail_msg 声明不消费、agent fail-closed、checkpoint_field/sidecar 读写语义）；`references/workflows/triage.yaml` inputs/outputs 修正为 schema 映射形态；harness 扩为 18 套件——新增 workflow-contract 套件：两实例＋基底＋sidecar 正例、schema 子集负例八、checkpoint_field pattern 语料级等价与写面三键一致性、unsupported-step 副作用前失败负例）；README 状态列同步合同定稿（ticket-ops open 预检增 README 锚点唯一性门——`任务票 <NN>；` 已在场即拒开零写入，追加语义要求零命中，不制造重复锚点〔防该票后续 take/flip 恰 1 行预检永不过的卡死面〕；ticket-ops 专节新增「README 状态列同步合同」：锚点形态／单行唯一／同步时机／失败语义；ticket-ops 套件增 12 断言——状态迁移正例逐链跨载体相等＋规范化字节比对，缺锚/重锚/锚点已在/缺表锚负例零写入））；角色合同/Prompt 权威去重与 Triage 角色合同模板定稿（`agents-triage.md.tmpl` 入册 Roles 类＋`RT` 短码（pm_template/pm_shortcode 两行＋templates/README.md manifest 与短码投影行），R-RT-001～002 索引行入 discipline.md.tmpl §16（机制列约定）；三件派发 Prompt 收敛为只承载派发参数、上下文与输出槽，零合同正文——占位符 28 全集零漂移；harness 扩为 20 套件——新增 role-prompt 套件：四件合同模板权威面正例＋Prompt 零合同正文边界扫描＋Triage 登记闭合五断言＋duplicate-body Prompt/duplicate-rule（检查 22）/missing-permission（检查 14）/缺权限声明四负例指名角色）；待定规范声明检测定稿（检查 24→25——MUST/MUST NOT 规则块内【待定】来源标记禁令，扫描面＝`references/adapters/` 全部 `*.md`（宿主映射手册是适配证据的规范承载面；引擎域常量硬编码，先例检查 21/23 的域路径常量），行级豁免＝命中行内 `<!-- pending-decl-exempt: <理由> -->`（理由必填，只限写入指引面——【待定】标记机制指令行本体，如 `adapter-template.md` R-AT-001 Stop if），标记行无命中、不在 MUST 块内或缺理由报失效豁免（检查 12/18/24 同款防漂移），check-package 套件正负例三断言与金样计数随动）；适配器注册表单源化定稿（检查 25→26——`package-manifest.rules` 十一节 `adapter-registry` 节 `pm_adapter` 六字段（platform/shortcode/adapter_file/capability_coverage/role_mapping/evidence_status）宿主绑定事实唯一登记面：加载段结构校验（字段格式/跨行唯一/短码全局唯一/platform ∈ 枚举宿主值/adapter_file 与 platform 同名/coverage ⊆ 基元名单，exit 2 fail-closed）＋检查段五向闭合（枚举宿主值缺注册行、适配器文件在位、shortcodes 节（短码, 所属文件）对全等且注册短码不挂他属、capability targets kind=table 行互为镜像、两 README 投影——`references/README.md` adapters 行平台 token 集全等＋`references/adapters/README.md` 目录清单投影对逐对在册）；两 README 短码登记改导航投影不另立登记事实；check-package 套件正负例八断言与金样计数随动）。 -->

2026-10-28 合并重整轮续录（提交 cd152d4 于本波迁入快照后并入契约头同节的定稿史句，原样续接，快照块零触碰）：派发合同链定稿（`ticket-record.schema.json` 增 `dispatch` 三阶段派发合同数据节（键集镜像 contract_fields，键集权威＝dispatch-contract.schema.json，两处漂移由 dispatch-contract 套件守卫核对）；ticket-ops open 增 dispatch 节开票门——新 task 必备三阶段对象键集恰等且逐键非空白，缺节/缺阶段/缺键/多键/空白值拒开零写入，存量票读取面零回扫；`contract-build.sh` 渲染器入包——票 dispatch 节→stdout 派发合同纯函数、输出前经 check-dispatch-contract --check 自校验零输出 fail-closed；安装闭包随 ticket-ops 门控扩六件（渲染器＋校验器脚本件＋schema＋三模板数据件），install 套件金样 16→22 件随动；dispatch-contract 套件增渲染器正负例与键集单源守卫，ticket-ops 套件增开票门五负例与存量无节票 flip 兼容正例；检查 8/19 清单 28→29 件、检查 13 比对 15→16 对、检查 20 一级 31→32 项，check-package 套件金样串随动）。

### 自 scripts/README.md 目录序言迁入：入包采纳核对记录原文（2026-10-26 原样搬运）

`generate-progress.sh` 与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致，两处同源演化须互为镜像并登记差异。`ticket-ops.sh` 包内文件与本仓根 `scripts/ticket-ops.sh` 基线 cmp 零差异（入包采纳核对）；`run-record.sh` 与 `ticket-grade.sh` 包内文件与本仓根同名件基线 cmp 零差异（存量清算入包采纳——先包后仓，包自此为基准、仓侧为镜像，零语义迁移）。`lane-commit.sh` 与 `check-gates.sh` 包内文件与本仓根同名件 cmp 零差异落位（check-gates 为仓根镜像新增对——先包后仓）。

## 2026-10-16（安全与对账强化波：恶意输入拦得住、包封闭、对账不冤枉人）

- **规则表不再执行**：三个引擎（模块地图、包完整性检查、安装器）读规则表从"当脚本执行"改为"当纯文本解析"——规则表里混进命令、反引号、重定向或陌生指令，一律报错拒绝、零写入，不再有执行任意代码的可能。合法表行为逐字节不变。
- **包闭合检查**：包完整性检查升到二十项——scripts 目录里多出未登记文件（含隐藏文件）、指向包外的符号链接、登记路径被换成别名，全部拦截。
- **升级对账不冤枉人**：升级对账器分清"真落后"和"本来就没装"——快道证据认两源（配置文件在场，或快道专属脚本已装）；多门控共享脚本不再误点亮快道；扫描器报错不再被仪表盘吞掉伪装成健康。
- **票系统收紧**：开票时全量校验卡面格式（字段类型、枚举、条件必填），坏卡开不进来；**票分类换成业界四值 bug/enhancement/debt/chore**——你提卡时顺手用熟悉的词，老卡不用动；bug 类卡必须写清复现路径或回归验证。lane-commit 加了路径边界校验，白名单写 `../` 或指向仓库外的软链一律拒绝。
- **工具与文档保养**：ShellCheck 纳入门禁（脚本零告警＋豁免必须带理由）；架构派生视图过期会显式标 stale；文档指路与手抄数字清理（数字以数据表为唯一真相）。
- **要不要跟**：建议跟。升级对账器会把 `scripts/` 下所有脚本与三份规则手册标"落后"；老项目的 `docs/` 布局照旧兼容；未启用快道的项目 `delivery.rules` 报 N/A 不是问题。

## 2026-10-15（Review 发现两级分流：只报正确性缺口，改进建议不阻塞）

- **审查清单增「必要性复核」**：生成的 `rules/implementation/roles/review.md` 审查覆盖清单新增必要性复核——白名单内改动对照验收条件与编程思想五问（R-DP-032）判必要性：推测性抽象、超出验收条件要求的防御性校验与扩展点、提前抽象（同一规律至少三处或规格确认的变化方向才抽象）、读者难以快速理解的复杂度，命中即记 fail 或要求实现方说明依据；同时加反向警告——审查者被要求找缺口通常总会报出一些，须只报影响正确性或既定要求的缺口，其余视为可选，事实高于个人偏好。
- **改进建议单列「建议」节不混流**：审查报告的更好写法与可选优化单列「建议」节，明示不阻塞、不计入 fail；建议级仅限不改变行为与验收结果的写法优化，涉及行为或验收结果的一律按 fail 报。
- **要不要跟**：生成件条文变化，老仓升级后对 `rules/implementation/roles/review.md` 逐件确认；规则块集零变化，对账器升级面零落后。

## 2026-10-14（三种运行模式契约对齐：手册说什么，脚本就做什么）

- **模式路径全对齐**：新项目初始化、旧项目补缺、已治理项目升级三种模式的落位路径与判定口径对齐到脚本实际行为——`scripts/` 手册里 ticket-ops、lane-commit、check-stale-claims 等随道脚本的数据面路径、安装落位（新布局 `rules/implementation/scripts/`）、缺省仓库根推导（各脚本实际是向上一级还是两级）逐一对齐；旧项目的 `docs/` 布局仍是兼容目标，不删不改。
- **适配器角色合同路径变量化**：五份宿主适配器的角色合同示例改为按 `<role-contract-dir>` 变量展开——新项目默认 `rules/implementation/roles/`，旧项目按登记兼容目录展开，照抄示例不再指向不存在的文件。
- **升级对账补盲区**：`upgrade-check.sh` 现在把模板清单里条件生成的 README（specs、research 等）纳入对账——目录存在就核内容、不存在报 N/A 而非漏报；旧布局目录自动映射到 `docs/` 兼容路径；动态生成的文件明确标人工盘点，不再虚报"全同步"。
- **要不要跟**：老仓升级后对账器会把 `scripts/README.md`、`references/adapters/`、`references/old-project.md`、`references/upgrade.md` 标"落后"属预期；未启用快道的项目升级时 `delivery.rules` 报 N/A 不是问题。

## 2026-10-14（需求登记册退役：卡片是需求的唯一去处）

- **需求登记册（REQ 队列）退出**：新项目初始化不再生成 `facts/requirements/requests/` 目录——初始件从八件变七件；需求一律走上一波的卡片（任务票），不再有第二本需求账。状态机从三套（Session/Task/Request）变两套（Session/Task），规则书里所有指路登记册的引用同步清掉。
- **存量项目零影响**：已初始化项目的旧登记原样封存——不删不改不迁移，读法校验用的 schema 保留（标注退役）；旧项目升级手册写明「缺失不补建、旧件冻结只读」。要新需求？直接开卡片。
- **要不要跟**：老仓不跟也安全；跟着升级时对账器会把 `rules/project.md`（状态机两套化）标"落后"、把旧 requests 目录认作既有人工资产——确认保留即可，升级流程不碰它。

## 2026-10-14（卡片规矩：需求工作三道——方案拍板后存卡即止）

- **需求入口三道分流**（生成的 `rules/assessment.md` R-DP-042＋`AGENTS.md` 路由总纲）：用户以需求动作发话时按三道走——**新增需求**＝agent 先在对话出方案（做什么、不做什么、怎么做、影响面、怎么算完），你拍板后 agent 把方案存成卡片（一张卡一个文件，存进任务票目录）即停；**存卡不等于开工，动手必须等你明确说"做"**。**整理需求**＝只做梳理、总结与实施建议，只动嘴不动文件。**完成需求**＝按已确认的卡直接干，不重新出方案；没有卡或需求变了，回到新增需求道重新拍板。
- **卡片＝任务票的沟通用名**：不是新东西——票上"目标/不做什么/范围/验收/风险"这些格子就是方案四要素，`decision` 格存你的拍板原话与日期。票目录 README 新增「卡片」节：正面六格、一生五态（存好/进行中/卡住/归档/弃案）、证据三条（存卡带拍板原话、开工带发令原话、停着的卡不算过期）。
- **两条既有路径零影响**：小修小补的快道与只读问答照旧，不进卡流程；批量授权里"按推荐一路做到硬门禁"的老节奏对新增需求类不再适用——拍板即停，等你发令。
- **要不要跟**：生成件条文变化，老仓升级后对 `rules/assessment.md` 与 `AGENTS.md` 逐件确认；对账器会把这两件标"落后"属预期。

## 2026-10-10（派发合同生命周期：合同写全、地图保鲜、复盘进化）

- **合同完整性门**（生成的 `rules/implementation/discipline.md` R-DP-038）：派发合同必须承载两问回答——改动逐条清单＋每条一个机器判得了对错的验收句，**验收句数＝清单条数**，数不对不派发；合同给全时执行体禁止整文件重读重新发现（读放大是 token 浪费的最大来源）。两层协作不变：可列全的活照常派发 agent。
- **反问即改**：执行体的澄清问题答案必须补进合同原文，不留在聊天——合同随派发迭代，同形态活越派越准。
- **代码地图三时点**（R-DP-040）：升级时回访派生面（该生成没生成＝欠账、拓扑变了没更新＝过期标记）；派发前跑地图圈牵连面写进合同禁区；收口时比对圈定范围与实际改动（圈漏了扣合同分）。
- **复盘打分与规则进化**（R-DP-041）：票收口打三个机器分（合同质量/谓词命中/返工），落账必须表态沉淀去向；高分合同形态固化为例句、低分模式进禁区清单；规则被推翻走 superseded 标注不删除。
- **要不要跟**：生成件条文变化，老仓升级后对三件规则模板逐件确认；地图回访随升级自动执行，无需额外操作。
- **合同与票融合**（票本体 schema 增强派发合同字段）：新票可选 `constraints`（约束数组）与 `dispatch_mode`（派发通道声明）字段；`verification` 支持逐条谓词数组形态（与 scope 逐条等数——完整性门由 schema 机器核对）。存量票零回扫，旧形态继续合法。
- **吸收触发器**（R-DP-041 吸收面机械承载）：新脚本读教训账本的分数键，按任务聚合——同任务连续 3 次合同质量高分提示"固化为例句"、连续 2 次低分提示"进禁区清单"；提示不裁决（对齐票定级建议器先例），裁决归用户；阈值 80/40 为初值可调。
- **复盘扫描器 S8**（易腐断言扫描器登记表 7→8）：教训账本里承诺沉淀到某文件的教训，扫描器核对指针文件存在且锚点在场——沉淀被删或指针写错即报警；登记计数动态化随动。
- **体系仪表盘**（新脚本 health-summary）：一条命令一屏看完体系健康度——打分趋势（按任务最近分数）/吸收候选/扫描报警/升级对账状态，四分区只读聚合；空数据不虚构，提示与报警的裁决仍归用户。
- **机制版本化**：四个核心脚本头部挂机制版本注记（断言组数/账本行型集/触发窗口/投影列的变更计数，dp-parser 先例形态）——升级对账时版本不一致即 cmp 漂移自然暴露，消费仓可知道自己缺哪版机制。
- **打分复核**（R-RR-002 覆盖清单增条）：收口打分（三分数键）由独立 Review 对照客观事实复核（打回次数/验证输出/合同补记），不符报差异——自评分数从此有第二双眼睛。
- **复盘打分结构化**（R-DP-041 配套）：教训账本的 lesson 行支持追加三个分数键（合同质量/谓词命中/返工，0-100 或 N/A），既有行型向后兼容——收口打分从散文变数据，为后续自动扫描与吸收提示打地基。
- **派发通道分流定稿**（R-DP-038 出口校准）：两问全过的活默认亲写一次性脚本（脚本通道是默认出口）；含执行体判断力的活才派发 agent，两问回答以合同承载（完整性门不变）；派发合同随票 Checkpoint 落盘（打分与对账的凭证）；合同含糊处不问清即动手列入禁区；地图新鲜度核对接入收口点检。
- **升级对账看得全了**：对账器对三件规则文件做规则块核对——包新版新增的规则块（你实例里没有的）逐块列出来标"落后"，你项目自定义的块标"分歧候选"不误报；升级报告固定四节格式（同步面/差异面/派生面/结论），不再靠人翻文件找差异。

## 2026-10-10（派发判据：能写脚本就不派 agent）

- **派活先过两问闸**（生成的 `rules/implementation/discipline.md` R-DP-038 判据化改造）：改动面能逐条点名、且每处对错能用机器判定（唯一匹配/期望输出/可跑检查）的活，一律亲写一次性脚本执行，不再派 agent——脚本没有"重读大文件"这回事，同样的活成本从百万级 token 降到几千。改动可否列全按判据判定，不再按任务类型列清单（类型永远列不全，换个马甲就漏）。
- **脚本自带防空转**：派发脚本必须断言预期改动数，实际对不上就报错——杜绝"匹配零处也静默成功"。活里夹着少数需要人判断的点？脚本吃大部分、判断点单独裁决，不再整批交给 agent。
- **要不要跟**：行为面是派发纪律变化（生成件条文），老仓升级后对生成件逐件确认即可；无脚本行为变化。

## 2026-10-10（说人话：文档全面去行话）

- **面向你的文档改成了大白话**：`SKILL.md`、升级手册（`references/upgrade.md`）、旧项目手册（`references/old-project.md`）里的小圈子行话清洗了一遍——"落位/落点"改说"装到哪/写在哪"，"门禁"改说"检查关"，"契约头"改说"文件头登记块"，"决策账本"改说"决策记录账"，"漂移"首次出现处解释为"人工改过、和包对不上"。规则、命令、文件路径一个没变，改的只是说法。
- **新机制（上一波装入）第一次实跑**：本次清洗正是升级流程里"历史票清洗扫描"姊妹能力"行话清洗"的第一次执行，以后大改文档时按同口径保持。
- **要不要跟**：纯文档措辞更新，零行为变化；老仓可以不跟，跟着走一遍升级也无任何风险（对账器会把改动的四个文件标为"落后"，确认即可）。

## 2026-10-09（升级一等流程与六项体验改进）

- **修包补账**：三件记录层脚本（generate-progress／ticket-ops／ticket-grade）包内拷贝的注释、用法句与报错指路仍写旧布局路径（docs/…），本次对齐现行 rules/facts 布局事实——行为路径常量早已是新版，本次仅文案翻值，行为零变化。
- **升级流程补源仓分支**：`references/upgrade.md` 漂移裁决补例外——源仓/维护者仓发现"仓领先于包"（仓侧演进而包内未同步）时，三选项（沿用/跟包/登记分歧）均不适用，唯一合法出口＝先修包（翻值包内落后件）→ 推送 → 同步本机技能 → 再以消费者身份复跑对账器至全同步；顺序不可倒置，禁止绕开修包手工搬文件"修仓"。

- **升级有了正式流程**：已初始化的项目升级不再靠"重新初始化"或碰运气——`SKILL.md` 模式判定新增"已治理（升级）"态，新增 `references/upgrade.md` 升级手册（盘点落地面 → 逐件对比 → 差异清单确认 → 确认后 reconcile 更新 → 验证收尾），漂移件停报告等裁决，记录与用户事实永不触碰。
- **新增落地对账器 `scripts/upgrade-check.sh`**：一条命令看清你的仓与包新基线的差距（同步／落后／漂移三态，全程只读）；随快道门控分发，登记于安装政策表。
- **新增 `references/templates/delivery-rules.tmpl`**：仓根 `delivery.rules` 有了官方模板（四节锚点与解析器逐字一致），启用快道的项目不再需要手写或反编译；`worktree-add.sh` 对"空排除清单"（裸锚点＋注释条目）不再拒跑，配置缺失的报错自带模板最小示例。
- **解析器版本对齐机制**：内嵌 delivery.rules 解析器的四个脚本（check-artifacts／check-stale-claims／export-payload／worktree-add）头部带 `# dp-parser: 2` 版本注记；老落地仓遇到包新增锚点/指令时报错直接指明"落地拷贝可能早于包当前版本，请与包内同件 diff 后同步"，不再只报一句"解析破坏"。旧仓同步指引见 `references/old-project.md` §3。
- **验证清单可按改动面收窄**（生成的 `rules/implementation/discipline.md` §11）：默认全量；全部改动属于项目登记的安全集（纯数据文件）才允许短清单；拿不准即全量，门禁必跑必给结论，合并回 main 全量兜底。
- **一次性批量变换有了承载形态**（R-DP-038）：目录搬家、批量替换用用完即弃脚本执行＋逐条改动清单合同，不再默认派探索式执行体逐文件手搬。
- **差异清单增执行形态与预估**（`SKILL.md` 主流程步骤 4）：每项标注亲写脚本／单 agent／全三阶段管线及保证差，C2 以上任务给三形状对比。
- **`check-artifacts.sh` 新增 `--fix` 修复形态**：反向未登记文件一条命令生成登记条目骨架（dry-run 默认零写入，`--apply` 显式落盘且与预览逐字一致）；check 系验证器修复形态设计准则落 `scripts/README.md`。
