<!-- Input: `check-package.sh` 的注册表驱动检查件实现（编号与实现件见 checks/registry.rules）与 SPEC-06 §5、包重组与例外登记的现行定稿事实（JSON 契约头例外登记正文在 `../references/schemas/README.md`、artifacts-yaml YAML 契约头例外登记正文在 `../references/templates/README.md`）；道脚本与票务运维脚本的现行安装政策（`install-policy.rules`）、包清单数据表（`package-manifest.rules`）、镜像登记（mirrors 节，检查 13 机械核对）与各脚本现行行为；派发合同链现行定稿事实（`ticket-record.schema.json` 的 `dispatch` 三阶段派发合同数据节键集镜像 `dispatch-contract.schema.json` `contract_fields`，键集权威在该字典，两处漂移由 dispatch-contract 套件守卫核对；ticket-ops open 对新 task 强制三阶段对象键集恰等且逐键非空白，缺节/缺阶段/缺键/多键/空白值拒开零写入，存量票读取面零回扫；`contract-build.sh` 将票 dispatch 节渲染为 stdout 派发合同纯函数，输出前经 check-dispatch-contract --check 自校验，失败零 stdout；安装闭包随 ticket-ops 门控扩六件——渲染器＋校验器脚本件＋schema＋三模板数据件，install 套件金样 16→22 件随动；dispatch-contract 套件增渲染器正负例与键集单源守卫，ticket-ops 套件增开票门五负例与存量无节票 flip 兼容正例；检查 8/19 清单 28→29 件、检查 13 比对 15→16 对、检查 20 一级 31→32 项，check-package 套件金样串随动；道收尾记录写入拆分——`checkpoint-write.sh` 入册 pm_script 与 mirror、`ledger-append.sh` 增 `--micro` 微账本行模式，检查 8/19 件数与检查 13 比对对数各加一件、检查 20 scripts 一级条目加一项，install 套件双门控实复制件数随动；三阶段编排入口——`ticket-run.sh` 入册 pm_script 与 mirror，implementation/review 两行交付站路径＋合同文件、commit 经结论位（首个非空行须为整行结论记号，或全文件唯一 `Verdict:`／`评审结论：` 行；`PASS:` 证据行不作数）判定 Review pass 后经 check-gates 自动两段提交，workflow-executor 索引写入改委托 ticket-ops flip-index，ticket-chain 索引读取改经唯一 JSON 引擎；安装闭包随 ticket-ops 门控补 ticket-run/worktree-add/dp-load-rules/check-gates，套件与包检金样随动；可恢复协调器——ticket-run 增 next/start/contract/record/verify-dispatch/repair 六子命令与 Git 公共目录 intent 操作记录，next 只读推导下一步、start 建站＋ticket-ops take 幂等收敛、contract 渲染站内合同、record 按 receipt.schema.json 字段合同幂等落位收据（不同内容 decision-required）、verify-dispatch 三类拒绝；legacy implementation/review/commit 行为保留，ticket-run 套件断言随动，站栅栏核验（sparseCheckout＋main-only 不在场＋status 无删除记录〔`D `／` D`／`DD`〕＋ls-files 非空〔空索引单判未物化〕＋sparse 配置逐条 `!` 排除）、跨日账本同源、收据类型/键集校验、源收据清理后按 intent kind 与目标证据判完成、next 在 decision-required 时 exit 1 且恢复提示先核 start 前置（不满足即 decision-required，`next --clear-intent` 为残留 intent 的登记清除路径（只清已判不可收敛者，删除前打印原内容，仍可收敛时拒绝并保留））、主检出＋站内四载体快照随动）；目录 README 四段式契约校验、生成块同步与骨架生成器与范围规则表（`generate-dir-readmes.sh`／`dir-readme.rules`：四段齐全含子目录分隔行、无成员表（整格表头「名字／成员／文件」）、无计数与状态句（含 `N 行`／合同／成员文件票，排除「一行」「第 N 行」）、正文裸露的 `【填写：…】` 占位（注释、行内代码段与围栏代码块内不算）、`--sync` 只重建生成块内子目录表且块外逐字节不动（围栏内标记不算块）、`--init` 四段骨架留占位（目录路径不得含空白）、`--migrate-dry-run` 旧格式迁移只读预演（four-column／member-table／no-table 三形态判定，判断文字按匹配节整行搬运、其余表与段落逐段 `DROP` 登记行范围与原因、缺项与超 25 行（只报不截断）出 `NOTE`、预演前后逐件 sha256 自证零写入，默认只出 ≤15 行摘要：`SUMMARY` 形态计数／`ZERO-WRITE` sha256 证据／分类 `NEEDS-CONFIRM` 待确认清单；`--diff` 连用才出逐件 `MIGRATE`／`DROP`／`NOTE` 与统一 diff，单独出现即 exit 2）、`--brief <rel-dir>` 单目录只读素材包（四节固定标题：目录清单给一级成员类型与文件行数／字节数、判断证据取 `facts/project/artifacts.yaml` 中该目录及目录内条目的 id／path／kind／authority／read_when 原文并按目录／成员／子目录内分组、现状复用 `--check` 判缺段与占位行、生成约定写四段写法与禁止事项；authority／read_when 原文照录（目录外指针原样保留，不做路径改写、不出屏蔽记号）；artifacts 缺失、不可解析或任一条目缺 id／path 时降级为目录清单＋生成约定并输出一行 `DEGRADED:` 原因，exit 0；与四模式互斥且不接受 `--dir`）），其 `dir-readme` 套件断言随票入册；目录 README 门禁返工——`generate-dir-readmes.sh` 增 `--freshness` 只读新鲜度断言（复用 `--sync` 的应产出块生成函数在内存重算、逐行比对，漂移 exit 1 并逐条报 `path:line: 缺失行／多余行` 与 `SUMMARY` 尾行，零写入；补 `--check` 单独发现不了的「新增子目录未入表」）与 `--check --blocks-only`（只校验含生成块的 README，旧格式无块跳过，供收口把结构断言限定在启用生成块的目录），ticket-ops close／flip／flip-index 至 done 在取锁与任何写入之前跑结构与新鲜度两检（任一失败 exit 1、本次零写入、不调用 `--sync`——`--sync` 降为操作者显式修复动作），check-package 检查 21 同口径两检，ticket-ops／lane-commit／dir-readme 套件断言随动；适配差异数据表现行定稿事实（`../references/adapters/adapter-diffs.rules` 四节机器数据行承载五宿主×九基元×三角色映射、enforcement level、独立执行体状态与宿主方言签名；与清单共用非执行式解析引擎，加载段结构校验 fail-closed，检查 27 断言数据 ≡ 现行五宿主 Markdown 对应段，漂移 FAIL；check-package 套件正负例四断言与金样计数随动）；历次入包采纳核对、检查项扩项与行为定稿的历史决策记录原文见包根 `../CHANGELOG.md`「2026-10-26（文档分层波）」迁移节（2026-10-26 自本 README 契约头迁出——README 不再兼任历史决策载体）；派发合同校验器增第四模式 `--check-step-budget`（步数上限与到线收尾四类 fail-closed 指名），三份角色模板同步 R-RI-005 步数预算与到线行为；记录层写面 module（记录层写面收敛票）的六类记录路径表与三写动词接口、九个记录层写点迁移事实与 `json set` 序列化形态。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、三十七项检查说明（清单数据驱动）、包清单数据表格式、适配差异数据表格式、易腐断言扫描器两模式与登记表说明、投影生成器（progress 投影与 README 票表生成块两类派生面）用法与退出码、模块地图生成器用法与语言登记表、道脚本收尾行为（索引翻转经 ticket-ops flip-index 代理、Review Checkpoint 经 checkpoint-write、微账本经 ledger-append --micro、微道预检、记录提交单点入口 `--record-commit` 的同锁串行/前缀断言/部分暂存与混提拒绝）、票务运维脚本五子命令用法与账本写入方 ledger-append 单写方合同、记录层写锁（多脚本共用 `record_lock_*` 原语、锁落点、陈旧锁诊断与显式夺锁、嵌套继承、继承或自取单一入口与所有权感知释放）、落位口径与票表生成块（派生）合同、三阶段编排入口接口与 commit 两段提交、安装脚本用法/退出码与安装政策数据表格式、Record 只追加守卫用法与守卫口径、治理产物对账器用法与受管口径/豁免维护规则、输出格式、退出码、维护联动规则与构建规约（脚本写法约定与 check 系 --fix 设计准则）、证据审计引擎接口（十一谓词、证据位置回溯、操作面窗口与策略/收据字段口径）、目录 README 四段式契约校验、生成块同步与骨架生成器用法与 `dir-readme.rules` 范围文法/断言口径、生成块新鲜度只读断言（`--freshness`）与 `--blocks-only` 结构限定、票务收口两检时序（取锁与写入前、失败零写入、不代跑 `--sync`）、宿主无关配置对账器 `host-config.sh` 的用法与标记块／备份／幂等／冲突停手口径、记录层写面 module `record-store.sh`（六类记录路径表与 record_write／record_append／record_set_json 三写动词、锁与 containment 内部包办、九处写点迁移；`tickets-readme` 路径键保留无写入方）。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。本目录同时是道脚本与票务运维脚本的安装源：安装政策（哪些脚本在什么门控下落位、每件复制基线路径与登记 lifecycle 值）以数据文件 `install-policy.rules` 为唯一承载点（外置数据、引擎零专名，先例 `module-map.rules`），复制动作经 `install.sh` 执行——目标项目用户确认启用分级交付道快道时以 `--fast-lane` 启用，采用任务票体系（`facts/requirements/tickets/` 目录创建）时以 `--ticket-ops` 启用（两套独立门控，启用判定是用户决策，脚本只承接已确认的复制动作），落位与登记口径见 `../SKILL.md` 主流程步骤 5 与 `../references/templates/development-process.md.tmpl` §12.5，脚本用法/退出码/数据格式见下文专节。复制不改变参数语义——`[repo-root]` 缺省仍取当前目录所在 Git 仓库顶层（`generate-progress.sh` 缺省按脚本落位推导仓库根），与落位后用法一致。包内件与本仓根同名件的镜像关系以 `package-manifest.rules` mirrors 节登记行为准，同源演化互为镜像并登记差异——镜像一致性由 `check-package.sh` 检查 13 常驻机械核对（比对对＝mirrors 节登记的包侧/仓根同名件；仓根无 `scripts/` 或无同名件静默跳过，消费项目语义）；历次入包采纳核对记录（各件先包后仓 cmp 零差异）见包根 `../CHANGELOG.md`「2026-10-26（文档分层波）」迁移节。镜像对数以 `package-manifest.rules` mirrors 节登记行为准，同源演化互为镜像并登记差异——镜像一致性由 `check-package.sh` 检查 13 常驻机械核对（比对对＝mirrors 节登记的包侧/仓根同名件，选定 manifest 新节承载而非引擎内注记；仓根无 `scripts/` 或无同名件静默跳过，消费项目语义）。包内落位基线脚本不运行：`ticket-ops.sh` 缺省 repo-root 取脚本所在目录的上一级，包内位置（`agent-up/scripts/`）误运行会错根，落位到目标项目后按落位形态取根——旧布局 `scripts/` 落位缺省即仓库根，新布局 `rules/implementation/scripts/` 落位须显式传 repo-root；`install.sh` 为包侧安装器、只在包内语境运行（不落本仓 `scripts/` 镜像），自带包内误运行守卫（精确化：拦自写自毁三场景——目标含裸 `SKILL.md`（即包根本体）、目标＝本脚本所在目录、目标落位目录＝本脚本所在目录（`cd -P` 物理解析，symlink 绕不过）；仓根含包副本但落位目的地与基线不同目录＝合法源仓落位，不拦）即拒绝（exit 1）；`check-append-only.sh` 为包侧分发工具，落位消费项目后对其记录层文件运行（本仓 worktree 实跑亦合法，见专节）。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、三十七项检查、包清单数据表格式、输出格式、退出码与维护联动规则。 |
| `common-helpers.sh` | 共享错误处理库 | 提供 die1/die2/warn 与 resolve_repo_root 函数——错误输出统一格式（脚本名自动提取）与仓库根推导唯一实现（缺省落位分派／--layout 严格两布局／--git 当前仓库顶层／--marker changes.jsonl 标记上溯，显式参数优先）；被 22 个脚本 source 引用（die 兜底副本已清零）；另提供记录层写锁原语 `record_lock_*`（锁目录定位、有界等待取锁、陈旧诊断与显式夺锁、令牌归属校验、释放与嵌套继承的唯一实现，`ticket-ops.sh`、`ledger-append.sh`、`lane-commit.sh`、`checkpoint-write.sh` 与 `ticket-run.sh` 共用——各脚本零锁代码副本；另提供继承或自取单一入口 `record_lock_ensure` 与所有权感知释放 `record_lock_release_owned`）。；另提供只追加前缀语义原语 `RECORD_APPEND_ONLY_PATHS`／`record_append_only_path`／`record_prefix_ok`／`record_first_bad_line`（账本清单、字节前缀判定与首个违规行号定位的唯一实现，`check-append-only.sh` 与 `lane-commit.sh` 记录提交门共用——前缀语义零副本）。 | |
| `dp-load-rules.sh` | delivery.rules 共享解析库 | `dp_load_rules <repo-root> <错误前缀>` 唯一实现（fail-closed 六规则：未知指令/恰数违/枚举违/跨行重复/路径形态违/锚点重复或条目违属，任一命中返回 2 不产生部分结论）＋`DP_PARSER_VERSION` 单一版本来源；四消费件（check-artifacts.sh/check-stale-claims.sh/export-payload.sh/worktree-add.sh）同目录 source 加载，缺件或版本漂移 fail-closed exit 2 指名；文法与版本权威说明＝`../references/delivery-rules.md`，锚点表与分发模板 delivery-rules.tmpl 逐字一致；随 fast-lane 门控入安装闭包（`install-policy.rules`）。 |
| `json-validator.py` | 唯一 JSON 引擎 | 脚本层全部 JSON 操作的单点承载（python3 标准库，无第三方依赖）：模式面＝ticket（schema 校验＋--new-ticket 开票门）/grade（复杂度定级）/run seal+stats（run record 封存与统计）/json（通用操作：get/type/fields/len/pick/count-key＋set 记录层字段级改写序列化，供脚本层取代内嵌解释器代码与 awk 行解析）/workflow（workflow-executor 专用：steps/state-machine 解析、preflight、index-status、checkpoint sidecar 生命周期）/ticket-check（ticket-ops 收口/领取/开票三门）/contract ticket-id（worktree-add 合同入口提取）；被 ticket-ops.sh/ticket-grade.sh/run-record.sh/generate-progress.sh/workflow-executor.sh/worktree-add.sh/ticket-run.sh 调用（安装闭包同目录定位，缺失 fail-closed）。详见下文「JSON 处理规范」专节。 |
| `check-package.sh` | 包完整性检查 | 按三十七项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004；检查 1/5/8 清单自 `package-manifest.rules` 数据读取，检查 9/10/11 以数据为比对基准；检查 12 规则块体模糊措辞扫描、检查 13 镜像生成物核对（仓侧 rules/implementation/scripts/ 下 mirror 类生成物须与包侧 scripts/ 手写源 byte 全等，缺件/漂移即 FAIL 指名；package-only 不生成不判；生成入口 scripts/generate-mirrors.sh）；检查 14 能力映射一致性（含 readonly-execute 行 `readonly_enforcement` 只读约束等级 enforcement 维度：受控词表＋逐适配器声明与登记预期全等比对）；检查 15 生成索引与规则块全集全等且 `--check` 零漂移、检查 16 索引机制列受控词表、检查 17 机械行点名出处存在（16/17 对象＝生成索引）、检查 19 scripts 节 mode 断言、检查 21 references 树成员闭合与导航（④ 目录 README 兜底只读两检：结构 `--check --blocks-only` 与生成块 `--freshness`，生成器缺失交检查 8，无启用块时零动作）、检查 22 规则块九字段格式（Level 受控四值收尾/七字段齐备/块 ID 全局唯一）、检查 24 布局引用分类与失效检测（modern/legacy/compatibility 三分类，legacy 计数、compatibility 行级豁免理由必填）、检查 25 待定规范声明检测（MUST/MUST NOT 规则块内【待定】来源标记禁令，扫描面 `references/adapters/*.md`，行级豁免标记 `pending-decl-exempt` 理由必填）、检查 26 适配器注册表闭合（`adapter-registry` 节六字段宿主绑定事实单源登记——注册表↔platform 枚举↔适配器文件↔shortcodes 节↔capability targets↔两 README 投影五向闭合，短码全局唯一由注册表单源验证）、检查 27 适配差异数据表一致性（`references/adapters/adapter-diffs.rules` 四节机器数据行 ↔ 现行五宿主 Markdown 对应段剥反引号后逐行逐字段全等，两向漂移 FAIL 指名宿主与段，加载段结构校验 exit 2 fail-closed）、检查 28 宿主差异段生成漂移（`generate-adapter-diffs.sh --check` 把数据表四节渲染为 Markdown 差异段后与现行宿主文件对应段比对——表段只去首尾空白后逐字节 `cmp`（含行内代码反引号等强调记号）、锚语原文在场，漂移 FAIL 指名宿主与段，生成链路无损复现现行文档）、检查 29 退役能力不在活动创建路径（`retired-path` 节退役 token 在活动面内须带 legacy 标注词，缺标注 FAIL 指名文件:行号与 token）、检查 30 workflow transition endpoint 存在（`workflow-graph` 节工作流 `state_machine` 的 initial_state／from／to 须 ∈ states、trigger ∈ steps）、检查 31 状态写票前有合法映射（每 state 须有 `state_to_ticket_status` 映射且目标 ∈ 票状态词表）、检查 32 readonly-execute 声明有 enforcement level（`readonly-sites` 节声明面闭包双向，level 面等级值 ∈ 词表且为 enforcement 目标）、检查 33 MUST 不引用待定规范事实（整包非适配面 MUST 块【待定】禁令，与检查 25 适配面并集闭环）、检查 34 README 非唯一执行契约（`contract-pointers` 节锚点行须含指向权威件的指针，README 不得自任唯一契约）、检查 35 平台短码注册表闭合（适配器归属短码须入注册表、平台短码与规则块短码命名空间不相交）、检查 36 fixture workflow 不标 production executable（fixture 须标非生产定位且不占生产入口名／不含生产可执行声称词）、检查 37 模型档位契约结构（`references/adapters/README.md` 派生表数据行恰四行且 C0–C3 有序、无第五档；五宿主文件与骨架 §2.6 三档行齐全非空，不可分档宿主三档取值为 inherit，仅单档/不可分档宿主角色级模型键标待实测，降级记录格式含 model_tier；五宿主与骨架 §2.7 四要素齐全，别名取值与到线行为落 README 两张受控词表，显式覆盖取值 ∈ 可／否／待实测，降级记录格式含 short_context: 与 boundary: 记录键，写实测结论须含实测证据字样））；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
| `check-append-only.sh` | Record 只追加守卫 | 守卫记录层两类写入语义（承接「Record 行级保护」候选口径）：`facts/project/changes.jsonl` 与 `facts/project/micro.jsonl` 只追加账本（HEAD 旧 blob 须为新内容前缀，中间插入/改写历史行/截断/删除即 FAIL 指名文件与首个违规行号）、`facts/project/archive/progress.md` 与 `facts/project/archive/changes.md` 冻结历史档案（任何 diff 即 FAIL；迁移窗口按 HEAD 旧路径承继基线核对）；文件不存在跳过（懒创建语义）、无 Git 基线（无 HEAD）WARN 退出 0（不硬猜基线先例）；POSIX sh、零外部依赖（仅 POSIX 标准工具与 Git 只读子命令）、fail-closed；前缀判定与首个违规行号定位经 `common-helpers.sh` 共享原语（与 `lane-commit.sh` 记录提交门同一实现，零副本）。可作 verify 命令加入门禁清单。详见下文专节。 |
| `check-artifacts.sh` | 治理产物对账器 | 治理产物登记与实物双向对账（兑现 R-DP-007 逐件登记核对）：正向＝`facts/project/artifacts.yaml` 每条登记 path 目标必须存在（缺失 FAIL 指名条目；数据块懒创建面登记暂缺 SKIP），反向＝数据块受管口径内文件必须被登记（精确/glob/目录聚合覆盖）或命中豁免规则（未登记 FAIL 指名路径，豁免命中不报）；受管口径与豁免规则落脚本内对账数据块（引擎零目录硬编码，对账数据块定谳）；登记解析破坏 exit 2 不产生部分结论；POSIX sh、零外部依赖（仅 POSIX 标准工具）、fail-closed；`--fix` 修复形态（反向未登记 → 十三字段登记条目骨架，dry-run 缺省零写入、`--apply` 显式落盘且与预览逐字一致、与检测共用判定代码；正向缺失不修）。详见下文专节。 |
| `host-config.sh` | 宿主配置对账器 | 宿主无关的宿主用户级配置对账：缺省 dry-run 零写入，输出「将修改（项目外）」分组（目标绝对路径、逐行片段、备份路径与 host-profile 四列登记建议）；`--write --confirm` 双开关缺一 exit 2，写入前备份 `<file>.bak.<UTC yyyymmddThhmmssZ>`，标记块逐字一致幂等跳过 exit 0、块被人工改动即 exit 1 指名不覆盖；`--set key=value` 至少一条、键限 `[A-Za-z0-9_.-]`、值非空不含换行，非法 exit 2；父目录缺失 exit 1；引擎零宿主专名与键名，宿主知识全由调用方按适配器文件传入；POSIX sh、零外部依赖、自包含。详见下文专节。 |
| `check-stale-claims.sh` | 易腐断言扫描器 | 登记表驱动的高流转状态句扫描（REQ-20260904-010；S3 改投影 vs 索引比对、消 S1-1e 恒触发缺口；S4 计数漂移哨兵：README 锚点行数↔index 条目数相等断言＋「N～M 共」「共 N 量词」计数模式扫描；S5 方案结论标注句：结论行 file: 出处＋轨:受控两值格式断言，向前生效只查工作区新增/修改面；S6 终态哨兵：索引 id 曾达 done/superseded 被改回非终态即 STALE 指名票 id 与跃迁方向，终态史取 Git 基线，对账分层＝一致性对账之外终态语义由 S6 承载；S7 替代标记存在性：索引条目 superseded_by 指向票必须真实存在（R-DP-039 替代标记面，悬挂/链环 STALE、非终态指向 WARN）；S8 复盘沉淀指针：lesson 行 promoted_to∈{rules,validator,test} 且指针可 grep 时核对文件存在＋锚点在场，缺失/丢失＝STALE（R-DP-041 检查面））；票收口拦截（gate，发现过期断言 exit 1）与会话启动警告（session，恒 exit 0）两模式；POSIX sh、全程只读、零外部依赖。详见下文专节。 |
| `check-gates.sh` | 快道门禁核对器 | 分级交付道快道的门禁核对（REQ-20260904-011）：工作区实际改动 ⊆ 白名单逐项比对 + 按清单重跑验证命令并记录退出码；现行版本起对验证命令写工作区零容忍——每条 verify 前后各取一次完整快照（跟踪/未跟踪/忽略文件内容哈希、可执行位、目录、符号链接目标、索引、HEAD），allow-output 缺省为空，白名单外变化一律失败并保持现场；POSIX sh、零外部依赖。详见下文专节。 |
| `lane-commit.sh` | 快道收尾脚本 | 分级交付道快道的合同驱动收尾（REQ-20260904-011；单写机制改造；微道预检两断言）：门禁 → 白名单产品提交 → 索引翻转（经同目录 `ticket-ops.sh` `flip-index` 代理承载索引单写＋投影再生＋`--check` 收尾链——写入方收敛，本件零直接 index.json 写入面与零直接生成器调用）→ 票正文 Status 投影打印件回写 → User Review Checkpoint 经 `checkpoint-write.sh` 追加或微账本（`facts/project/micro.jsonl`）经 `ledger-append.sh --micro` 落行（记录写职责拆分，本件零 checkpoint/账本写入面）→ 记录提交（两段式，R-RC-003）；micro 道预检两断言（白名单 ≤3 条目、改动集零新建（??）零删除（D），违者 exit 1，user-review 道不受限）；另提供 `--record-commit <repo-root> <message> <记录路径>...` 记录提交单点入口（持同一把记录层写锁，用私有索引 `GIT_INDEX_FILE` 只暂存 `facts/` 记录路径并拒绝部分暂存，只追加账本 HEAD 须为待提交版本字节前缀否则零提交并报首个违规行号，私有索引写出的树须恰含记录路径，最后 `write-tree`/`commit-tree`/`update-ref` CAS——断言对象＝被提交树，失败零提交，并发暂存不卷入且保留现场，未改动路径显式列为已排除）；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-progress.sh` | 现役状态投影生成器 | 自 `facts/requirements/tickets/index.json`（票状态真相源，一条目一行）生成 `facts/requirements/tickets/progress-current.md` 现役状态投影与 `facts/requirements/tickets/README.md` 的票表生成块（两处 Derived，生成器独占写）；`--check`／`--check-readme` 为两类投影的 dry-run 一致性核对；再生调用单点＝`ticket-ops.sh`（open/take/flip/flip-index 收尾链独占调用；快道索引翻转经 `lane-commit.sh`→`flip-index` 代理触达，零直接调用方；`check-stale-claims.sh` 仅调用 `--check`／`--check-readme` 只读一致性核对，非写链）；运行时依赖＝同目录 common-helpers.sh（die 与 resolve_repo_root）与 json-validator.py json fields 模式（条目字段解析唯一引擎，缺件 fail-closed 指名）；POSIX sh、fail-closed。详见下文专节。 |
| `generate-docs-index.sh` | 规则索引生成器 | 包内规则索引投影的唯一生成器与唯一写入方：扫描包内全部 `*.md`/`*.tmpl` 的 `#### R-<短码>-NNN` 规则块，输出 `../references/rules-index.md`（五列表：ID／标题／所属文件／Level／机制，按 ID 升序，Derived 四标注头）；`--check` 为 dry-run 一致性核对（规范化 `generated_at` 行后逐字节比对，`exit 1` 附 diff 指名差异行，零写入）；机制登记表随脚本内嵌，规则块无登记条目或登记条目无对应块即 `exit 2` fail-closed；POSIX sh，只读扫描零网络。检查 15 经其 `--check` 承载零漂移核对，检查 16/17 以生成索引为比对对象。详见下文专节。 |
| `generate-module-map.sh` | 模块地图生成器 | 静态导入行提取生成 `<root>/facts/project/architecture/module-map.json` 检索索引（方案 A 静态导入行提取拍板；Rust 扩展、表驱动化、七语言批量扩展迭代）：Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌（R-DP-015 算法，输入排除本图自身）；repo-root 参数化（缺省 git toplevel）；引擎为通用规则解释器（加载规则表→发现源码→匹配捕获→策略产边→存在性过滤→组装 JSON），语言知识外置 `module-map.rules`（每语言一行，引擎零语言专名，加语言＝加规则行零引擎改动）；POSIX sh、无 jq/python（stat 与 SHA-256 工具依赖声明见专节）、fail-closed。详见下文专节。 |
| `generate-dir-readmes.sh` | 目录 README 校验／同步／骨架生成、迁移预演与素材包 | 按四段式契约校验目标范围内既有目录 `README.md`（`--check`，缺省行为）：四段齐全（一句话职责／`## 权威`／`## 读取禁忌`／`## 子目录` 三列表头＋紧随分隔行，缺任一段或表头无分隔行均报）、总行数 ≤ 25、无成员表（`## 成员` 段，或表头单元格去空白／反引号／`**` 后整格等于「名字／成员／文件」之一、列数 ≥ 2 且紧随分隔行的表格；正文提及与普通两列表不算）、无计数与状态句（`共 N 件`／`N 个脚本`／中文数字个脚本／`当前没有`／`N 行`（「一行」「第 N 行」不算）／合同件数（`三合同`、`3 份合同`）／`N 个成员`、`N 份文件`、`N 张票`）、正文反引号路径存在（含 `/` 按目标根；不含 `/` 但形如文件名的按 README 所在目录；`N/A` 与其余裸标识符跳过；忽略含 `*` 的通配、绝对路径、URL）、正文裸露的 `【填写：…】` 占位（HTML 注释、行内代码段与围栏代码块内的占位不算）、生成块标记成对（围栏代码块内的标记不算块）；全部通过 exit 0 且零输出，不合规逐条输出 `path:line: 原因`。`--check --blocks-only` 只校验含生成块的 README（无生成块的旧格式跳过，供收口门禁把结构断言限定在启用生成块的目录）。`--freshness` 为生成块新鲜度只读断言：在内存用 `--sync` 同一生成函数重算应产出块，与现行块逐行比对，零写入；漂移即 exit 1 并逐条输出 `path:line: 缺失行: <原文>`／`path:line: 多余行: <原文>`（缺失行行号＝该行在应产出块内的期望位置），无生成块跳过、干净时 exit 0 零输出，块未闭合／重复起始／`dir` 不符 exit 2；它补 `--check` 单独发现不了的「新增子目录未入表」。`--sync` 只重建生成块内的子目录表（块外逐字节不动；行集合＝该目录一级子目录并套用范围规则，按名排序；既有行「一句话」「禁忌」原文复用，新增行一句话取子目录 `README.md` 职责句、取不到写占位，首格路径中的 `|` 转义为 `\|`（读回反转义），消失的子目录整行删除并逐行输出 `DEL`；无生成块的 README 不新建不修改并输出 `SKIP`，围栏代码块内的标记不读不写；未闭合／重复起始／`dir` 值不符 exit 2 且整批零写入）。`--init <rel-dir>` 为新目录写四段骨架（判断位留 `【填写：…】`，目录不存在或 `README.md` 已存在 exit 2 零写入；`--init` 与 `--sync --dir` 的路径规范化后含空白字符即 exit 2 零写入；`--check`／`--sync`／`--freshness`／`--init` 四模式互斥，`--blocks-only` 仅与 `--check` 连用）。`--migrate-dry-run` 对范围内旧格式 `README.md` 只读预演迁移（先过 `--check`，零问题即跳过；形态判定 four-column（4 列且首格为文件类）／member-table（表头任一格归一后为「名字／成员／文件」且紧随分隔行）／no-table（含只有普通两列表者）；建议内容＝H1 前注释块＋H1＋职责句（缺则占位）＋`## 权威`＋`## 读取禁忌`（各自只搬匹配节内的列表项整行）＋自动子目录表；成员表、手册节、非列表段落、H1 前非注释元数据逐段 `DROP` 并登记行范围与原因，缺项与超 25 行（只报不截断）出 `NOTE`；默认摘要模式 stdout 仅 `SUMMARY`（形态计数）、`ZERO-WRITE`（sha256 一致数）与分类 `NEEDS-CONFIRM`（超 25 行／缺职责句／缺权威或禁忌项／未迁入段数），≤15 行，无迁移件零输出；`--diff` 才输出逐件 `MIGRATE`／`DROP`／`NOTE` 与统一 diff，单独出现或与非迁移模式同用 exit 2；任何异常全量 `path:line` 写 stderr、stdout 为空；全程零写入）。`--target`／`--dir`／`--rules` 参数化，范围规则缺省同目录 `dir-readme.rules`；Python 3 标准库实现。`--brief <rel-dir>` 只读输出单目录的 agent 素材包：四节固定标题（目录清单／判断证据／现状／生成约定），素材只取目标目录一级成员与目录内 artifacts 条目原文，目录外条目过滤；`authority`／`read_when` 原文照录（目录外指针原样保留，不改写、不出屏蔽记号）；artifacts 缺失、不可解析或条目缺 id／path 时降级为目录清单＋生成约定并输出 `DEGRADED:` 原因，exit 0；全程零写入。详见下文专节。 |
| `dir-readme.rules` | 目录 README 范围规则表 | `generate-dir-readmes.sh` 的纳入与排除范围唯一承载点（先例 `module-map.rules`：外置数据＋引擎零专名）：每个非空非注释行恰为 `include <pattern>` 或 `exclude <pattern>`，模式相对目标仓库根，`*` 匹配任意字符（含 `/`）、`?` 匹配单字符；至少一条 include，缺件或任一行不合预期即 exit 2（fail-closed）。 |
| `module-map.rules` | 模块地图语言规则表 | `generate-module-map.sh` 的语言提取规则唯一承载点（表驱动化定稿）：每语言一行 `mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>`；strategy 枚举 extension-map（扩展名 glob 语言绑定）/unresolved-node（未解析节点引用直出）/module-path（模块路径文本直出）/direct-file（声明文件候选边＋存在性过滤）；编码语义见本表头部注释与下文专节；规则表缺失或不合预期时引擎 exit 2（fail-closed）。 |
| `generate-adapter-diffs.sh` | 适配器宿主差异段生成器 | 数据表→文档段的唯一渲染器（`references/adapters/adapter-diffs.rules` 四节机器数据行→Markdown 差异段）：`--section cap` 渲染「\| 能力基元 \|」对照表数据行、`role` 渲染「\| <role-contract-dir>/」角色映射表数据行、`exec`／`dialect` 渲染声明与方言锚语；`--check` 逐宿主逐段渲染后与现行宿主文件比对（表段只去首尾空白后逐字节 `cmp`——含行内代码反引号等强调记号，锚语原文在场断言），零漂移 exit 0、漂移 exit 1 逐行指名宿主文件与段（首个差异行与两侧行文随报）、数据表或环境不合预期 exit 2 fail-closed；POSIX sh＋POSIX awk 零外部依赖、只读零写入。检查 28 经其 `--check` 承载生成漂移核对。详见下文专节。 |
| `install-policy.rules` | 安装政策数据表 | 安装政策映射唯一承载点（单源化定稿；先例 `module-map.rules`：外置数据＋引擎零专名）：门控定义行 `ip_gate <gate> <flag> <说明>`、每脚本件×每门控行 `ip_file <pkg-rel-path> <lifecycle> <gate> <说明>`（包内复制基线路径、登记 lifecycle 值、所属门控与角色说明；同一文件属多门控逐门控各一行，引擎按文件路径去重选取）与每数据件×每门控行 `ip_data <pkg-rel-path> <target-rel-path> <lifecycle> <gate> <说明>`（安装后运行时依赖闭包的 schema/profile 等数据件承载行：包内源路径、目标根相对落位路径、登记 lifecycle 值、所属门控与角色说明——随消费脚本同门控复制，落位路径须避开脚本落位目录）；`install.sh` 加载时结构校验（字段数、token/flag/lifecycle/路径形态、(文件/数据件,门控) 唯一、同文件 lifecycle 一致、未定义门控引用、零文件门控、数据件落位路径跨行唯一且同件一致），任一不合预期 exit 2（fail-closed）。 |
| `package-manifest.rules` | 包清单数据表 | 包结构清单唯一承载点（单源化定稿；逐次扩节；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）：十节行式数据——必需入口文件（`pm_entry`）、脚本必需件（`pm_script`，kind 区分普通脚本/规则表与非可执行数据件/test-harness/目录）、.tmpl 模板清单（`pm_template`）、规则块短码登记（`pm_shortcode`）、platform 枚举（`pm_platform`）、模糊措辞词表（`pm_vague_word`）与行级豁免（`pm_vague_exempt`，理由必填）、镜像脚本（`pm_mirror`）、能力基元名单与检查目标（`pm_capability`/`pm_capability_authority`/`pm_capability_target`）、规则索引执行机制受控词表与外定义标记词（`pm_mechanism`/`pm_mechanism_marker`）；`check-package.sh` 加载时结构校验（字段数、路径/kind/短码/platform/词/行号/文件名形态、各节内跨行不重复），任一不合预期 exit 2（fail-closed）；检查 1/5/8 清单与计数、检查 9/10/11/12/13/14/15/16/17 比对基准全部自本表读取，引擎零文件名零短码零枚举值零词表零基元名清单零机制词表。维护规则与行格式见下文专节。 |
| `project-dashboard.html` | 本地项目仪表盘 | 单文件只读 HTML（原生 HTML/CSS/JS，零网络、零第三方运行时依赖）：Chrome/Edge 直接打开，用户点击按钮经 `showDirectoryPicker({mode:'read'})` 只读授权项目根目录后，读取 `facts/project/architecture/module-map.json`、`facts/requirements/tickets/index.json` 与全部 Markdown/JSON 卡片，展示项目依赖图与卡片列表——搜索、状态筛选、节点依赖查看与卡片详情可用，状态冲突以 `index.json` 为准；页面打开期间每 4 秒重新 `getFile()` 自动更新（无手动刷新、无服务器、无启动命令）；缺失或损坏逐项提示且不扫描源码重建；全程零写入零网络，卡片与地图文本按纯文本渲染（无 HTML 解释型赋值面），不支持 File System Access API 的浏览器显示明确提示；纯逻辑核心块暴露 `window.__agentUpDashboard` 供 Node 抽取测试运行。随 ticket-ops 门控入安装闭包（`install-policy.rules`）。回归＝`tests/` 的 project-dashboard 套件（Node 运行核心逻辑；缺 node 即 exit 2）。 |
| `ticket-ops.sh` | 票务运维脚本 | 协调层票务面单入口（本仓交付后入包采纳）：`open`（开票：索引新增条目 status=ready＋账本追加行（README 票表由生成器派生，不追加行）；NN 段查重——同 NN 异 slug 与畸形 id 拒开；open 本体 schema 校验＋定级/优先级理由非空断言＋七维 profile reason 开票门（新 task 必备 `profile_reason` 对象恰七键 D/B/I/U/S/M/O 逐键非空，缺项/越键/空白值即拒零写入；存量票读取面不要求——开票校验与读取校验分层）＋单写并发与崩溃恢复（记录层写锁经共享库原语 `record_lock_*` 承载（索引写点另经 `record-store.sh` 的 `record_write` 落地——路径解析、锁断言与原子替换零副本；README 票表已改由生成器派生、不再经写动词），锁目录＝仓库根 Git 公共目录下 `agent-up-record.lock`——主检与全部 worktree 争用同一把，非 Git 回退 `$TMPDIR` 并按仓库根物理路径派生；mkdir 原子语义＋有界等待，超时 exit 1「并发冲突」；陈旧锁（持有者 pid 不存在，或 pid 缺失且锁龄超 `TICKET_OPS_LOCK_STALE`）默认只诊断不自动夺，`--break-stale-lock` 或 `RECORD_LOCK_BREAK_STALE=1` 才显式夺锁；四个写点前核对令牌归属，被夺即拒绝写入、零写入；嵌套调用 `ledger-append.sh` 传继承标记不重复取锁；测试专用 `RECORD_LOCK_TEST_HOLD_MS`（持锁后延迟，未设零开销）；锁语义见下文「记录层写锁」节；每个写点同目录临时件＋mv 原子替换；索引已达目标状态走幂等重放——补齐 README 行/账本行/投影后 exit 0，不重复落账本行；空索引 `{"issues": []}` 可就地展开落首条目；`TICKET_OPS_FAULT=after-index-write|after-ledger-write|after-projection-write` 写点后 exit 70 供崩溃恢复测试，未知值 exit 2 零写入））／`take`（领取：status=in_progress；blocked_by 完整性门——task 票本体 blocked_by 逐项须在索引登记且 status=done，缺失或未完成即 exit 1 指名 blocker id 与其状态，零写入；request 无 blocked_by 不校验）／`flip`（状态翻转：状态机任意合法值；task 票 flip 至 done 的收口硬拦——票 JSON 本体 actual_time 须已填且非空，缺项 exit 1 指名票 id 与缺项，非 done 翻转不要求，request 不校验；done 另过证据门——调同目录 `ticket-audit.sh --operation merge` 只认 conformant，证据未提交/提交后改动/diff 失配/unknown 即 exit 1 报 decision-required 零写入）／`close`（done 收口入口：--id/--ledger-line，status 固定 done；写入链与证据判定同 flip 至 done，不留自报旁路）／`ledger`（无票账本行入口：不依赖 `facts/requirements/tickets/index.json` 条目 id，账本行形状校验先于写入，仅账本落行不触索引/README/投影——C0 修正类免建票收口经此落行）／`flip-index`（索引单写代理：仅改 status/updated_at＋投影再生＋`--check`＋票表生成块重算＋`--check-readme`；目标 task 票 done 同过 actual_time＋证据门双证）六子命令，索引 id 锚点整行机械改写＋README 票表生成块重算，收尾调用 `generate-progress.sh` 再生 `progress-current.md` 与票表生成块 并 `--check` 核对；校验先于写入、fail-closed（索引一条目一行排版破坏、锚点不唯一或 open 的 README 锚点已存在、账本行不合键序或行型条件键缺失即停止不写）；运行时依赖定位（安装闭包）：open 的 schema 权威与 `json-validator.py` 只认安装闭包——脚本同目录 `json-validator.py` 与 `../references/` 下的 schema/规则数据件（安装器把脚本件落位 `rules/implementation/scripts/`、数据件落位 `rules/implementation/references/`），不读包工作树副本；闭包缺失即 fail-closed 零写入，报缺失绝对路径并指向升级/修补入口（Agent Up 包 `references/upgrade.md` 与 `scripts/install.sh`）；POSIX sh、无 jq（open 本体 schema 校验与 flip actual_time 校验与 done 证据门另用 python3 标准库）。详见下文专节。 |
| `ledger-append.sh` | 记录层账本写入方 | `facts/project/changes.jsonl` 唯一写入方：账本行行族形状校验（键集/键序/按 kind 条件键，行型合同＝`../references/schemas/ledger-row.schema.json` 文档级单源）＋唯一 JSON 引擎 `json-validator.py` json fields 解析门（缺 python3 或引擎即 fail-closed 指名，零写入）＋追加单点（懒创建仅限账本文件本体，父目录随 `mkdir -p`）；`--check` 为零写入预检模式（`ticket-ops.sh` open/take/flip/ledger 写前预检经此承载——校验先于票务面任何写入的 fail-closed 时序保持）；微账本 `facts/project/micro.jsonl` 亦归本件写入面：`--micro` 模式按固定键序生成 `micro_seven_key` 行（date,lane,whitelist,gates,verify,commit,actual）并追加，字段由 shell 层校验（不新增解释器依赖），懒创建仅限账本本体与 `facts/project/` 父目录，既有六键行只追加不改写；道脚本 `lane-commit.sh` 微道落行经本件承载（自身零微账本写入面）；写模式独立调用时自取记录层写锁（共享库原语 `record_lock_*`，与 `ticket-ops.sh` 同一把锁），被 `ticket-ops.sh` 嵌套调用时按继承标记跳过取锁与释放，`--check` 不取锁（锁语义见下文「记录层写锁」节）。运行时依赖＝同目录 common-helpers.sh（die/warn/resolve_repo_root/record_lock_*）、json-validator.py（changes 行族解析门）与 record-store.sh（两账本追加经 `record_append`，懒创建与追加字节前缀断言同源）；POSIX sh、fail-closed。 |
| `checkpoint-write.sh` | Checkpoint 写入方 | User Review Checkpoint 唯一写入方（自 `lane-commit.sh` 拆出的记录写职责）：`review-checkpoint` 子命令按 `--ticket`/`--verdict-quote`/`--verdict-at`/`--commit`/`--commit-subject`/`--diff-summary`（可选 `--date`）写入记录块——`.md` 票追加票尾，`.json` 票体零追加、落独立 `facts/requirements/tickets/<id>-review-checkpoint.md`（创建带一级标题／已存在追加）；stdout 末行 `checkpoint-write: 目标文件: <rel>` 为机器契约，供 `lane-commit.sh` 登记记录提交面；不做索引/账本/投影写入；记录块写入经 `record-store.sh`（.json 票路径表 `checkpoint:<id>`、.md 票传显式记录路径；首建经 `record_write`、追加经 `record_append`——锁断言与原子替换零副本）。POSIX sh、fail-closed。详见下文专节。 |
| `record-store.sh` | 记录层写入 module | 记录层写面唯一实现（记录层写面收敛票）：六类记录路径唯一承载表（`index`／`changes`／`micro`／`tickets-readme`／`ticket:<id>`／`checkpoint:<id>`）与三写动词 `record_write`（整文件原子替换）／`record_append`（追加＋字节前缀断言）／`record_set_json`（字段级改写，内部调 `json-validator.py` 的 `json set` 序列化并回读核对）；内部包办 `record_lock_ensure`（调用方已持锁则接管同一把，否则自取并在本次写入后按所有权释放）、realpath containment（绝对路径／`..` 段／末段 symlink／父目录逃逸 fail-closed）、同目录 mktemp＋mv 原子替换；被 `ticket-ops.sh`（索引写点；README 票表已改由生成器派生、`tickets-readme` 路径键保留无写入方）、`ledger-append.sh`（changes／micro 两账本行）、`checkpoint-write.sh`（Review Checkpoint 记录块）与 `ticket-run.sh`（票本体 checkpoint.commit）共用——六类记录路径字面量收敛到本表（派生投影与 flips 协议串属既有面），锁断言与原子替换机制零副本；POSIX sh、fail-closed。 |
| `run-record.sh` | run record 生成器 | run record 生成与封存单入口（本仓交付后存量清算入包采纳）：`new` 生成十三字段骨架并自动填机械字段、内容字段留【待填：…】由执行体填，`seal` 完整性校验（usage 五子字段必备，缺项 fail-closed）全过后按当前仓库状态刷新机械字段，`stats` 只读聚合 usage 用量报表；`seal`/`stats` 依赖 python3 标准库（不引第三方），SHA-256 与 stat 工具按序探测、缺失即 exit 2；fail-closed。包内文件为本仓根同名件基线 cmp 零差异采纳（先包后仓，包为基准、仓侧为镜像），随 ticket-ops 门控复制（登记见 `install-policy.rules`）；用法/退出码见脚本 `-h` 与头部注释。 |
| `ticket-grade.sh` | 定级建议器 | 票定级建议器（本仓交付后存量清算入包采纳）：读任务票 JSON 机械计算可数判据（承重验收条数、行为/契约件模块数、高风险面关键词、公共接口证据与微道承重可数面），输出各 C 级命中条件、C0-C3 建议、微道资格预审与逐票分歧账；建议不裁决（输出只写「建议/命中/预审」，不写「必须/定级为」，分歧以 Triage 为准）；python3 标准库内嵌、全程只读零写入、fail-closed。包内文件为本仓根同名件基线 cmp 零差异采纳（先包后仓，包为基准、仓侧为镜像），随 ticket-ops 门控复制（登记见 `install-policy.rules`）；用法/判据口径见脚本 `-h` 与头部注释。 |
| `absorption-trigger.sh` | 吸收触发器 | R-DP-041 吸收面机械承载：读账本九键 lesson 行按 scope 聚合分数——同 scope 最近 3 连合同质量高分（≥80）出 PROMOTE 候选（固化为例句）、2 连低（≤40）出 FORBID 候选（进 Forbidden），提示不裁决（对齐 ticket-grade 先例）裁决归用户；数据不足 NOTE；阈值 80/40 为初值可调；POSIX sh、全程只读零写入、零外部依赖。详见下文专节。 |
| `health-summary.sh` | 体系仪表盘 | 四分区只读汇总：打分趋势（lesson 九键行按 scope 最近分数）｜吸收候选（调用同目录 absorption-trigger.sh，口径单一承载）｜扫描报警（check-stale-claims gate STALE 计数含 S8）｜对账状态（提供包基线时出汇总行）；空源显示（无）不虚构；POSIX sh、全程只读零写入、零外部依赖。详见下文专节。 |
| `measure-context-cost.sh` | 成本度量复测器 | 只读统计会话 `wire.jsonl` 的 `usage.record`：raw／缓存重放／新增输入／输出／每次调用上下文／每步工具调用数／超 2 万字符结果数／步数分布；`--governance` 统计安装件字符数、规则块数与每阶段读取集字符数；给定基线 JSON 逐项输出差值（基线−当前，正数＝下降＝收益）；样本不足、路径或指标缺失即 exit 非 0 且零 stdout（不输出半套指标）。详见下文专节。 |
| `install.sh` | 安装脚本（包侧安装器） | 安装政策单源化的执行引擎：按启用门控自查同目录 `install-policy.rules` 得复制集合，脚本件逐件 cp 自包 `scripts/` 至 `<target>/rules/implementation/scripts/`，数据件逐件 cp 自包内源路径至 `<target>/<行内落位路径>`（安装后运行时依赖闭包——schema/profile 等数据件随消费脚本同门控落位，消费脚本按自身落位形态邻接定位），并逐件 cmp 核验字节一致；预检先于复制（脚本件与数据件同口径核验源存在，删任一已登记依赖即安装明确失败指名路径；目标漂移即停，零半套）；已存在且字节一致的同名件幂等跳过，不一致即停（reconcile 纪律不覆盖）；目标目录缺失时创建并输出提示行（scripts 目录 README 生成归执行体，数据目录无 README 义务）；末尾输出登记建议块（每复制件一行 artifacts.yaml 十三字段建议值，脚本件 kind: script、数据件 kind: spec，生成件登记随条目单本账承载），不代写目标治理文件；POSIX sh、零外部依赖、fail-closed；引擎零脚本名零门控专名（加门控＝加规则行零引擎改动）；包侧工具，不落本仓 `scripts/` 镜像。详见下文专节。 |
| `export-payload.sh` | 公开载荷导出单命令 | delivery.rules 驱动的六步导出（命令面权威＝载荷导出设计 §3）：split→树比对（全新 mktemp 展开即用即删）→导出树 check-package→ff 断言（远端 target 头非新导出头祖先＝污染停手，报错文案照设计逐字）→push（裸 push）→ls-remote 复核；`--dry-run` 执行步骤 1～4 零远端写零本地分支写；永不 force（不内建任何改写远端历史的路径）；真跑前置主检出门禁（链接 worktree 内拒绝真跑——R-DP-036 main-only：未合并分支不得上公开仓，`--dry-run` 不受限）；导出形态（前缀/远端/分支）读仓根 `delivery.rules` payload 节，未声明即拒跑 exit 2；POSIX sh。详见下文专节。 |
| `worktree-add.sh` | worktree 栅栏化创建单命令 | 一票一 worktree 的创建面栅栏（R-DP-036 配套；与 export-payload 真跑主检出门禁、install.sh worktree 自拒互为三闸）：主检出自拒（链接 worktree 内拒绝运行）→读仓根 `delivery.rules` main-only 节（锚点缺失或文件缺失＝栅栏未知拒跑 exit 2 fail-closed；锚点在场即已声明，含空清单）→合同入口（单参数传派发合同文件）自抽 TICKET_ID 派生分支名与站路径（旧接口双参数传路径与分支名，形态要求见脚本 `--help`）→`git worktree add --no-checkout` 创建（分支存在即检出、不存在即 `-b` 创建）→sparse-checkout 非锥形模式放行全部＋逐条排除 main-only 路径→`read-tree -mu HEAD` 物化→生效断言（首条排除路径在 worktree 内必须物理不在场，空清单跳过）；main-only 脚本自此在该 worktree 不可运行（文件不在场），排除清单持久于该 worktree `info/sparse-checkout` 随删除消失；POSIX sh、不 push、不删除既有 worktree。 |
| `worktree-prune.sh` | 工作树清理独立命令 | `worktree-prune.sh [--apply] [--force] [--repo-root <dir>]`：三判据＝非主检出＋工作区干净（`git status --porcelain` 为空）＋（分支已并入 `main` 或索引中该票 `status=done`）；输出三类——可清（列出路径/分支/体积）、跳过（有未提交改动）、保留（分支未合并且票未 done），并给可清项数与合计回收体积。缺省 dry-run 零删除；`--apply` 才执行 `git worktree remove --force`＋`git branch -d`（未合并分支在 `--force` 下用 `-D`）；`--force` 才处理跳过/保留项；失败逐项报错并非零退出；幂等可重复执行；不写账本。与 `merge-ticket.sh` 分工：合并强制清自己的站，本命令事后统一清扫全部残留；不接会话开始与 pre-push（用户 2026-11-06 明确）。 |
| `worktree-deps.sh` | worktree 依赖准备单命令 | 一票一 worktree 的依赖面（每个 worktree 独立真实 `node_modules`）：符号链接 `node_modules` 直接拒绝（exit 1 指名绝对路径；目标根与各 workspace 同款）→非 npm 仓库（目标根无 `package.json`）显式 skip exit 0→读 `workspaces` 清单（数组或 `{"packages": [...]}`）展开并逐项断言 `package.json` 在位（缺失 fail-closed exit 1 零安装）→断言全过后在目标根 `npm install`→安装后断言 `node_modules` 为真实目录（非符号链接）；克隆加速默认关闭，仅 `--clone-accel --clone-from <dir>` 显式开启（clonefile 播种，文件系统不支持则回退普通复制）；POSIX sh、不改 `package.json`/lockfile、不删除既有 worktree。 |
| `workflow-executor.sh` | Workflow 运行时执行器 | YAML workflow 定义驱动的流程执行器：按 `../references/schemas/workflow.schema.json` v2 的 `steps` 声明序执行 command/verification 步骤（agent 步骤在任何 checkpoint 落盘与步骤副作用之前 fail-closed）、步骤级 checkpoint 原子落盘、`--resume` 中断续传、`--retry` 幂等重试；shell 信任边界：workflow 文件是受信规则文件，含 command/verification 的 workflow 须调用方显式 `--allow-shell` 才执行——缺省拒绝，未授权在 preflight 之后、checkpoint sidecar 落盘与任何步骤副作用之前 fail-closed（exit 非零，报文指名 `--allow-shell`）；`--param`/`--ticket-file`/`--retry` 只登记与校验，绝不拼接进命令或参与 shell 求值；边界正文唯一声明处＝`../references/schemas/workflow.schema.json` 顶层 description「信任边界」段；实际支持子集与 checkpoint_field/sidecar 读写语义的唯一声明处＝同一 description（`../references/schemas/README.md` 同名节为 legacy 指针；回归＝`tests/` 的 workflow-contract 套件，含未授权 fail-closed 与注入/参数不替换负例）；YAML 解析、checkpoint 与索引只读查询经同目录唯一 JSON 引擎承载，索引写入只委托同目录 `ticket-ops.sh flip-index`（含投影再生与 `--check`），本件零自带索引写面。POSIX sh＋python3（零外部包依赖）、fail-closed。 |
| `verify-contract.sh` | 结构化验收谓词执行器 | 读取票面 `verification` 对象数组，逐条执行 `check` 并核对 `expect`/`expect_exit`；普通任务禁止空数组或缺失字段。纯记录例外必须显式提供 `record_only.reason` 与 `verification: "N/A"`，不得用空值绕过门禁；存量散文 verification 仅作票体兼容，不在此执行。依赖 jq，失败即非零。 |
| `check-dispatch-contract.sh` | 派发合同校验器 | 四模式派发合同校验器：`--check-template` 模板漂移检查（schema 占位符全集与 `../references/prompts/` 三份派发合同模板占位符并集双向零差集）＋`--check <合同文件>` 执行体自查（按特征字段推断合同类型，对照 schema 该类型必备字段清单核对占位符完整性，缺失逐名报出）＋`--check-dispatch <合同文件>` 派发前置校验（取合同 `{{REPOSITORY_PATH}}` 实值要求为主仓 linked worktree——`git-dir` 与 `git-common-dir` 规范路径相等即主检出拒绝；取 `{{TICKET_ID}}` 实值要求主仓 `facts/requirements/tickets/index.json` 中 status=in_progress，未领取或非 in_progress 拒绝；repo-root 由 worktree 的 git-common-dir 反推，不信任调用方传参）＋`--check-step-budget <合同文件>` 步数预算校验（「步数上限：<数字>」与到线收尾／另起交接摘要；缺步数上限、缺到线收尾表述、上限为空、上限非数字四类各自指名拒绝，fail-closed）。POSIX sh＋awk；`--check-dispatch` 另需 python3 解析索引（JSON 引擎与 contract-build.sh 同口径），其余三模式零外部依赖（无 jq/python），全程只读。数据件＝`../references/schemas/dispatch-contract.schema.json`。详见下文专节。 |
| `contract-build.sh` | 派发合同渲染器 | `contract-build.sh <stage> <NN> [repo-root]`：读票 JSON `dispatch.<stage>.<KEY>` 逐字段渲染派发合同到 stdout（{{KEY}} 实值行块形态与 `../references/prompts/` 三模板占位符一致）；字段清单唯一来源＝`../references/schemas/dispatch-contract.schema.json` `contract_fields.<stage>`（纯 awk 现场提取，与校验器同源同法），值唯一来源＝票 dispatch 节（存储合同单源＝`ticket-record.schema.json` dispatch 属性）；纯函数——stdout 唯一交付面、零仓内落盘（自校验暂存件落 `$TMPDIR` 用毕即清），输出前自调同目录 `check-dispatch-contract.sh --check` 自校验，不过即 exit 1 零 stdout（fail-closed：半份合同不出门）；票定位按票本体 id 口径（`^[0-9]{2,}-[a-z0-9-]+$` 过滤 `<NN>-*.json`；派生件 `<id>.review-evidence.json` 等带点号文件不计票本体）恰一命中（零命中或同 NN 多件真实本体 fail-closed 并逐件指名，不猜测渲染对象）；无节票（存量形态）报缺不迁移；POSIX sh＋python3（唯一 JSON 引擎）＋source `common-helpers.sh`；安装闭包随 ticket-ops 门控同落位（`install-policy.rules`：本件＋校验器＋schema＋三模板）。回归＝`tests/` 的 dispatch-contract 套件。 |
| `ticket-run.sh` | 主 agent 编排入口（可恢复协调器） | `ticket-run.sh <NN> <command> [args] [repo-root]`：六子命令 `next`（只读推导下一步）、`start`（建站＋领取，幂等收敛）、`contract`（渲染合同，恰两行）、`record`（按 `receipt.schema.json` 字段合同幂等落位收据）、`verify-dispatch`（重渲染比对，三类拒绝）、`repair`（安全、幂等、追加式纠偏：补建缺失站、重建派生投影、检测 main 直提并给 cherry-pick 迁移建议、缺 Review 只到 `pending-review`／`decision-required`；不写索引／README／账本／票本体，不生成审查结论，不执行 rebase／amend／force-push）；副作用前写 `<git-common-dir>/ticket-run/<NN>.intent`，失败重跑收敛，无法判定返回 `decision-required`。legacy 三阶段保留：implementation/review 恰输出站路径与合同文件两行，主 agent 据此派发，脚本不启动子 agent；implementation 缺站时经 `worktree-add.sh` 创建。commit 只认 Review 结论位（首个非空行须为整行结论记号 `PASS`/`PASS_WITH_NOTES`/`FAIL`，或全文件唯一 `Verdict:`／`评审结论：` 标签行；`PASS:` 证据行不作数，缺失或多义即 fail-closed）后经 `check-gates.sh` 执行范围与白名单门禁，自动创建产品提交；合同明列的索引翻转经 `ticket-ops.sh flip-index` 执行并另建纯记录提交，不伪造 User Review Checkpoint。commit 阶段不渲染合同文件。记录收口段 `checkpoint.commit` 经 `record-store.sh` 的 `record_set_json` 字段级改写（唯一 JSON 引擎 `json set` 序列化，同锁窗口内写点前核对令牌归属）。安装闭包随 ticket-ops 门控同落位。详见下文专节。 |
| `ticket-audit.sh` | 证据审计引擎 | `ticket-audit.sh [<NN>] [--operation read|analyze|merge|push] [--range <base>..<head>] [--max-commits <n>] [--skip <sha>] [--allow-after <rel>]`：对票审查收据做只读审计，逐谓词打印 `PASS`/`FAIL`/`UNKNOWN` 并给操作面判定（read/analyze 放行 unknown，merge/push 只认 conformant）；证据位置可回溯到 `路径@提交:blob`；P04 允许集须逐条 `--allow-after` 显式传入（缺省仅证据）；`--operation push` 与 `--range` 同给时切批量/推送面，对显式区间逐提交判定——无绑定收据的 merge 提交指名票 id 与 P01，ff 单亲提交按 head 树内索引 status 兜底（`--max-commits` 缺省 50、`--skip` 可重复，`<NN>` 可省略）；批量面不替代、不放宽单票 merge 证据门；策略数据＝`facts/requirements/audit-policy.json`，收据 schema＝`references/schemas/receipt.schema.json`；POSIX sh、全程只读零写入。详见下文专节。 |
| `merge-ticket.sh` | 合并站脚本 | `merge-ticket.sh <repo-root> <branch> <ticket-id>`：票分支→main 合并（主仓须干净、当前分支 main；ff 失败降级 `--no-ff`，仍冲突则 `git merge --abort` 清现场 exit 3 停等，成功无条件强制清场（`git worktree remove --force`＋`git branch -d`；站内残渣视为可弃，失败即报错非零退出、不静默））；合并前证据门＝在票分支绑定 worktree 上跑 `ticket-audit --operation merge`，只认 conformant，缺证据/未提交/diff 失配/unknown 即拒绝（decision-required，worktree/分支保留）；actual_time 预检读被合并票分支 tip（主检出仅在分支无票体时回退），允许集与 done 门同源纳入票面声明的规范 Review Checkpoint md，另显式允许 `facts/project/changes.jsonl` 与 `facts/requirements/tickets/README.md` 两个记录面派生件（随每次票务操作必然变动——账本行追加、README 状态列同步，不属被审阅的实现面；主线在分支期间落记录面提交不再被 P04 判成「审阅边界被污染」）；expected exit 0 成功、1 fail-closed、2 用法环境、3 真冲突停等。包内新建（基线＝仓侧同名件）并以 mirror 两落位同步；安装闭包随 fast-lane 门控。回归＝`tests/` 的 merge 套件。 |
| `test-checkpoint-recovery.sh` | Checkpoint 中断续传回归测试 | workflow-executor.sh 中断续传机制回归测试：模拟工作流中断后从 checkpoint 恢复继续执行的场景，验证 checkpoint 文件格式、恢复逻辑正确性；POSIX sh、mktemp 夹具 trap 清理、零工作区写入。供开发/升级时自检 checkpoint 机制。 |
| `upgrade-check.sh` | 落地面升级对账器 | 用户确认升级模式后，以完整治理面组合识别 modern/legacy/mixed；按 install-policy 门控检查新旧脚本落位（双份都 cmp 并报告冲突）；未启用门控显示 N/A；快道证据两源＝delivery.rules 在场或快道专属脚本已装，多门控共享脚本（如 generate-progress.sh）不构成快道证据——未启用快道时 delivery.rules 恒 N/A，快道脚本已装而缺配置才报落后；从模板 manifest 提取固定 Conditional README Emits，目录存在时检查 README，目录不存在时 N/A；旧布局映射到对应 docs/兼容面；动态 `<目录>/README.md` 输出列为人工盘点；对 README/artifacts 与 Derived 不宣称内容同步。全程只读，退出码 0 自动检查面无差距、1 有差距、2 用法环境或布局不明。详见下文专节。 |
| `test-record-layer.sh` | 记录层回归 harness | 六票 fixture 沉淀的常驻自检工具（历次扩 suite）：suite 集合与权威枚举见下文专节（`--suite` 参数化，缺省 all），一条命令回归记录层全链，逐项 PASS/FAIL＋计数，任一失败 exit 非零；缺省自测同目录包内脚本（对被测脚本只以显式 mktemp 夹具根/包根参数驱动，与 ticket-ops.sh「包内不运行」口径不冲突）；POSIX sh、无 jq；open 本体校验路径依赖 python3，缺失即 exit 2；夹具 trap 清理、仓库零写入。详见下文专节。 |
| `tests` | harness 拆分套件目录 | 记录层回归 harness 的套件分片：test-runner.sh 派发器（ALL_SUITES 唯一枚举＋fast 短车道＋per-suite 超时／信号清理／断言下限）＋test-helpers.sh 共享断言（结果日志回传）＋`tests/suite-*.sh` 全部套件（各 suite 可独立运行 `sh tests/suite-<name>.sh`；套件数以文件系统实计数为唯一真源；含 harness 自身硬化负例）；test-record-layer.sh 为兼容入口委托 tests/test-runner.sh；清单 kind=dir。 |
| `generate-mirrors.sh` | 镜像生成器 | 包侧 `scripts/` 手写源 → 仓侧 `rules/implementation/scripts/` 生成物单入口：按 `package-manifest.rules` mirrors 节 mirror 类逐件生成，幂等、逐件 cmp 自证；`--check` 只读核对，漂移/缺件指名 exit 1；package-only 不生成。生成物不得手工编辑。 |
| `checks` | 包检引擎检查件目录 | 检查注册表与检查件分片：`registry.rules`（`chk_total`／`chk_retired` 声明＋每项检查一行号/slug/件/必需数据节）＋每项检查一件 `NN-slug.sh`（统一 interface：引擎传入包根，检查件只判定并经 `add_problem` 报告问题、置描述与 SKIP 面，不打印 PASS/FAIL 行、不碰汇总计数；由 `check-package.sh` 按注册表发现与分发；清单 kind=dir） |

旧项目已有 `<target>/scripts/` 副本属于兼容布局，安装器不搬迁、覆盖或删除。

## 用途与用法

对 `agent-up` 公开包做发布前核对与包内容变化后自查：全部编号检查通过才可宣称包完整（检查 23 已退役，编号不复用）；失败项逐条修复或报告，不为通过检查篡改包内容（R-06-004）。

```text
sh scripts/check-package.sh [package-root]
```

- 无参数：以脚本所在目录的父目录为包根（在本包内运行时，检的就是本包）。
- 带参数：以第一参数为包根（对 subtree 导出目录或临时目录副本复跑时使用）。
- `-h` / `--help`：打印用法。
- 脚本只读：除向 stdout/stderr 打印外无任何写操作；无网络依赖（不出网、无下载行为）。

## 检查项（编号 1–37，检查 23 已退役；编号与实现件由 `checks/registry.rules` 注册表钉住，本表为说明投影，分发与汇总计数不在本表重复登记）

包结构清单的机器真相是数据文件 `package-manifest.rules`（二十二节，行格式与维护规则见下文专节）：检查 1/5/8 的清单与计数自数据读取，检查 9/10/11/12/13/14/15/16/17/21/24/25/26/27/28/29/30/31/32/34/35/36 以数据为比对基准核对登记面与使用面（检查 33 的扫描面与词表语义同检查 25，引擎窄锚点为规则块窗口与豁免标记）；本表为检查口径的人读说明，与数据表冲突时以数据表为机器真相。

| # | 检查 | 实现 |
| --- | --- | --- |
| 1 | 必需入口存在 | 清单 `entry-files` 节逐行 `test -f`（件数与逐件名单以 `package-manifest.rules` `entry-files` 节为机器真相，本行不手抄计数与名单——mutable 计数归权威数据面承载，引用不腐烂，:62 同款先例）；任一缺失即 FAIL 并逐件指名（fail-closed）。 |
| 2 | `SKILL.md` frontmatter 为 `name: agent-up` | 首行 `---` 与闭合 `---` 之间存在 `name: agent-up` 行；frontmatter 缺失或未闭合判失败。 |
| 3 | 包内无旧标识残留 | `grep -rn` 全包扫描旧 Skill 标识字面量（本包改名前的原 Skill 名），零命中为通过；扫描范围含本目录。 |
| 4 | 无绝对路径与根治理引用 | `grep -rn` 扫描用户主目录绝对路径前缀（/Users 或 /home，带尾斜杠匹配）与根治理相对引用字面量（`../` 后接 docs 或 .zcode）。按例外登记结论，模板内 `../specs/` 等兄弟路径属目标项目生成语义，不在本项口径。 |
| 5 | 模板清单一致（数据↔磁盘↔manifest 双向；数据驱动） | `references/templates/` 下实际 `.tmpl` 与清单 `templates` 节集合一致（数量相等、互不缺多），且数据每件在 `templates/README.md` manifest 目录清单节有登记行、manifest 登记的每个 `.tmpl` 都在数据内——manifest 表＝人读投影，数据＝机器真相，双向漂移即 FAIL。 |
| 6 | 文本契约头齐全 | `*.md` 与 `*.tmpl` 在检测窗口内含 `Input:`/`Output:`/`Pos:` 三行：无 frontmatter 的文件取前 5 行，首行为 `---` 的文件取 frontmatter 结束后的 5 行（frontmatter 未闭合判失败）。例外：`artifacts-yaml.tmpl` 以 YAML `#` 注释承载（前 5 行含 `# Input:`/`# Output:`/`# Pos:`，登记见 `templates/README.md`）；`LICENSE` 与 `schemas/*.json` 不属扫描范围（JSON 以 `$id`/`title`/`description` 承载导航元数据，例外登记见 `schemas/README.md`）。 |
| 7 | 根治理文件不在包内 | 包根不存在 `AGENTS.md`（文件）与 `docs/`、`rules/`、`facts/`、`.zcode/`（目录）。 |
| 8 | 脚本必需件存在（扩清单历次联动；件数以数据表现值为准） | 清单 `scripts` 节逐行 `test -f`——件数与逐件名单以 `package-manifest.rules` `scripts` 节为机器真相，本行不手抄计数与名单（旧手抄计数已漏更即腐烂实证；mutable 计数归权威数据面承载，引用不腐烂）；`kind` 枚举三值：`script`（普通脚本）/`rules`（规则表）/`test-harness`（回归 harness——口径差定谳：`test-record-layer.sh` 定为必需件，kind 标 `test-harness`）；任一缺失即 FAIL 并逐件指名缺失件（fail-closed，不因部分存在而放宽）。增删包内脚本成员＝先同步数据表 `scripts` 节与成员表（检查 9 双向核对），再实跑本检查核对。 |
| 9 | scripts/README.md 成员表与数据 scripts 节一致 | 双向口径：①清单 `scripts` 节每件都在成员表登记（表＝人读投影不得漏登必需件）；②成员表登记的每件都是 `scripts/` 下实际文件（表与实物不漂移）。成员表提取锚点＝首列 `名字/地位/功能` 表头行。 |
| 10 | 规则块短码使用均在登记内 | 扫描包内全部 `*.md` 与 `*.tmpl`（同检查 6 文件面）提取规则块 ID `R-<短码>-<三位序号>` 的两字母前缀，与清单 `shortcodes` 节比对：使用⊆登记；SPEC 规格号（`R-02-001` 形态，数字段）不落入提取模式。短码全集以 grep 实测为准（现 16 个），新增短码先登记数据表再使用。 |
| 11 | platform 枚举登记与数据一致（逐处全等） | 各登记处值集合与清单 `platform-enum` 节逐处全等（任一处缺值/多值/改值即不一致，FAIL 行按行号指名漂移处）：`references/templates/artifacts-yaml.tmpl` platform 字段注释区（锚点＝`当前已知集合：` 标记）、`references/adapters/capability-contract.md` 内每个「已知集合」句（frontmatter 与 §2.5 各一处，各自单独比对，不并集）；提取锚点为登记标记文本，值集合以数据为权威。 |
| 12 | 规则块体无模糊措辞（兑现 R-GF-010 自称可静态扫描句） | 词表外置清单 `vague-words` 节（字面匹配非正则，引擎零词表硬编码）；扫描窗口＝包内全部 `*.md` 与 `*.tmpl` 的 `R-<短码>-NNN` 规则块体（块头行起至下一标题行止，块头本身不扫），排除「解释与例外」节（标题含该标记起至下一标题止）与各 README 文件（叙事面）；manifest 自身词表行为 `.rules` 数据文件不在扫描文件面。命中行无法安全换词的经 `vague-exemptions` 节登记行级豁免（路径＋行号＋理由，理由必填）；登记行无命中即失效豁免 FAIL（防行号漂移静默失效）；awk 扫描异常即 exit 2（fail-closed，扫描器失效不得当作零命中放过）。 |
| 13 | 镜像生成物与包侧源一致（包侧单写、仓侧生成） | 登记面＝清单 `mirrors` 节 `pm_mirror <文件名> <类别>` 行（两参数）。`mirror`＝该件须由包侧 `scripts/<名>` 生成（入口 `scripts/generate-mirrors.sh`，幂等、逐件 cmp 自证）：检查 13 核对仓侧 `rules/implementation/scripts/<名>` 生成物存在且与包侧源 byte 全等——缺件 FAIL（生成物缺失）、漂移 FAIL（生成物漂移，重跑生成器）并逐件指名；生成物不得手工编辑。`package-only`＝包侧独有，不生成不核对（仓侧同名实例非生成物，不判差异不判存在）。源仓语境判定＝包根父目录存在 `rules/implementation/scripts/`；不存在＝消费项目语境整项静默跳过（无输出行；`--pkg-root` 参数化语境同口径）。 |
| 14 | 能力映射一致 | 名单＝清单 `capability-primitives` 节九基元名（自 `capability-contract.md` §2.1 权威表现场提取，引擎零基元名硬编码）；①权威表＝`pm_capability_authority` 登记文件，窄锚点「### …能力基元清单」标题下九行表首列提取，与名单双向全等（缺/多/改名即 FAIL 指名权威文件）；②检查目标＝`pm_capability_target` 节逐一核验（三角色 .tmpl 声明行 kind=decl 取 `required_capabilities（运行时）` 行反引号名集合、五适配文件 kind=table 取「| 能力基元 |」对照表首列名集合）——目标名集合与登记预期名单双向全等：注入未登记名（不在名单）／删名（缺少）／改名（未登记＋缺少并报）即 FAIL 指名文件；预期名单经载入校验逐名 ⊆ 名单且八目标并集 ⊇ 名单。表解析锚点失效即 exit 2（fail-closed 不静默过，检查 11 同款）；targets 相对 `$pkg_root` 解析，`--pkg-root` 复制落位语境与镜像检查同口径。 |
| 15 | 生成索引与规则块全集全等且零漂移 | 对象＝`../references/rules-index.md`（`generate-docs-index.sh` 独占写）：①索引表行 ID 集 = 包内全部 `*.md`/`*.tmpl` 的 `#### R-<短码>-NNN` 规则块 ID 集（排除索引自身），双向缺/多 FAIL 指名；②`generate-docs-index.sh --check` 零漂移（规范化 `generated_at` 行后逐字节比对，exit 1 附 diff 指名差异行）。生成器或索引缺失即 FAIL（不静默过）。 |
| 16 | 索引机制列受控词表 | 对象＝生成索引 `../references/rules-index.md` 机制列（五列表第 5 列）；词表＝清单 `mechanism-vocab` 节受控三值（机械/门禁/约定），引擎零词表硬编码。机制列语法：受控值开头，可跟全角括注（出处/说明，不做词表核验）或「；」分段（每段 ∈ 词表）；括号不配对、空段、词表外值即 FAIL 指名 ID。 |
| 17 | 机械行点名出处存在 | 对象＝生成索引机制列（检查 16 同源）。机械行（机制列首段＝「机械」——引擎语义锚点）须在括注内点名：①脚本名 `*.sh` 须真实存在于包 `scripts/` 且在清单 `scripts` 节登记；②检查项号「检查 N」须落在 1..37（引擎自述上限，新增检查须同步）。零脚本零检查项的机械行判缺点名。 |
| 18 | 包内票号索引禁令 | 扫描面＝包内全部 `*.md`/`*.tmpl`/`*.json`/`*.rules`（`*.sh` 代码面不扫——断言名/注释语境为不腐烂载体，扫禁归后续裁决）；模式＝「票 ?[0-9]{2,}」字面正则（本仓票号索引引用，消费者无本仓票务语境，溯源改由 git commit message 与票本承载——citation-rot 定稿）；命中即 FAIL 指名文件:行号；行级豁免经清单 `ticket-citation-ban` 节 `pm_cite_exempt` 登记（路径+行号精确匹配，理由必填），登记行无命中即失效豁免 FAIL（防漂移静默失效，检查 12 同款口径）；豁免表可空。只查模式不判语义（行为描述语义零变化边界由 Review 把关）。 |
| 19 | scripts 节 mode 断言（kind 数据驱动） | 判定源＝清单 `scripts` 节 `pm_script` kind（引擎零文件名硬编码，家族惯例同检查 8/9）：`script`（普通脚本）与 `test-harness`（被调 harness）为可执行类——须 index `100755` 且盘上可执行（出生即残类失效防线：hook 只调可执行件、直接执行依赖 -x 位，mode 残缺静默失效；先例 `.githooks/pre-commit` 门禁 5）；`rules`（数据规则表）为非可执行件——须 index `100644` 且盘上不可执行（数据件误带执行位防扩散）。每件四态核对：index mode（`git ls-files -s`）、盘上 `-x`、期望 mode、kind 枚举兜底（未知 kind 即 FAIL）。包根非 git 语境（`--pkg-root` 复制落位，先例检查 13 静默语义）整项静默跳过零输出行；缺件由检查 8 指名、本项不重复报。 |

| 20 | 包闭合性与符号链接防护 | 三段防线：①scripts 目录一级条目闭合——条目面（`find` 一级条目，含隐藏条目）须 ⊆ 闭合白名单＝清单 `scripts` 节登记件 ∪ 引擎自身（`check-package.sh`）∪ 成员表（`README.md`）∪ 清单数据件自身（`package-manifest.rules`），白名单零硬编码文件名（引擎/成员表/清单件名分别同 `$0`、`scripts_readme_rel` 路径常量与 `pm_rules` 载入路径同源）；未登记额外脚本/文件（含恶意投放）即 FAIL 指名条目。②包内 symlink 防外指——全部包内 symlink 的 readlink 原始目标折算为绝对词法形态后逐段折叠（点段折叠，词法判定不展开中间路径 symlink），折出包根词法域（含断链）即 FAIL 指名 symlink；POSIX 通行路径，不依赖 GNU `readlink -f`。③登记路径 symlink 禁令——检查 1 必需入口登记路径（entry-files）与必需目录（`references/`、`scripts/` 目录自身及其子路径前缀面）不得为 symlink（包内别名或包外指向一体拦截；检查 1/8 既有 `test -f` 判定跟随 symlink 对此天然盲视）。零 git 依赖：非 git 语境照常运行（与检查 19 非 git 静默跳过语义区分）。 |
| 21 | references 树成员闭合与导航 | 三段防线：①references 全树文件 ⊆ 清单登记——`find references/` 全部常规文件逐件核对在清单 `entry-files` 节、或属 `references/templates/` 下 `.tmpl` 且在 `templates` 节（检查 5 同源数据），未登记额外文件（成员增删漏登记、恶意投放、隐藏条目）即 FAIL 指名；②`references/README.md` 目录清单投影双向——`references/` 一级条目（文件与目录）与 README「## 目录清单」表首列反引号名单双向全等（表＝人读投影、数据与实物＝机器真相，先例检查 5/9 投影纪律），单侧缺名即 FAIL 指名，锚点未命中或零成员行判表结构漂移 FAIL；③包内 Markdown 行内链接目标存在——全部 `*.md` 文件的行内链接（方括号标签后紧跟圆括号目标的形态；外链含 `://` 与 `mailto:`、`#` 纯锚点不在口径），剥离锚点段后相对所在文件目录词法折叠（点段折叠，先例检查 20 词法判定形态），目标不存在或折出包根（含绝对路径目标）即 FAIL 指名文件:行号与目标。零 git 依赖。 |
| 22 | 规则块九字段格式 | 依 `../references/protocol/governance-format.md` §2.1 既有定义机械执行（字段集与 Level 枚举为检查语义常量，非第二权威，先例检查 19 kind 枚举）。扫描面＝包内全部 `*.md` 与 `*.tmpl` 的 `#### R-<短码>-<三位序号>` 规则块（含裸 ID 标题）：①标题行须以受控 Level 四值（`MUST`/`MUST NOT`/`SHOULD`/`MAY`，反引号可选）收尾，缺失或自造级即 FAIL 指名 ID 与标题原文；②块体（标题行起至下一标题行止，与检查 12 窗口同口径）七字段 When/Action/Forbidden/Stop if/Evidence/Owner/Authority 须以「`- **字段**：`」形态各至少一行，缺字段即 FAIL 指名 ID 与缺失字段名（全量扫描不排除「解释与例外」节——规则块无处可藏）；③块 ID 全局唯一（governance-format.md update_policy 定稿），跨行或跨文件重复即 FAIL 指名 ID 与各处文件:行号。 |
| 24 | 布局引用分类与失效检测（modern/legacy/compatibility 三分类） | 扫描面＝清单 `layout-face` 节登记面（目录行递归取 `*.md`/`*.tmpl` 并排除 README.md 叙事面，检查 12 同款口径；单文件行整件入面；登记面不存在即 FAIL）。①失效引用三分类：旧布局路径 token（`docs/<path>` 或 `development-process`，前邻字符禁 `/` 与字母数字点连字符，避开 `code.claude.com/docs/` 等外部 URL 形态）——`legacy`＝`layout-legacy-file` 节登记文件（合法保留件，命中只计数不判罚）；`compatibility`＝`layout-compat-exempt` 节登记行（路径＋行号＋理由，显式豁免非隐式忽略；登记行无命中即失效豁免 FAIL，检查 12/18 同款防漂移口径）；`modern`＝其余命中即 FAIL 指名文件:行号与命中 token。②modern 相对链接解析＝面内 `*.tmpl` 行内链接（方括号标签后紧跟圆括号目标的形态，同检查 21③ 描述；外链与纯锚点不在口径）：目标剥锚点段与前导 `./` 后落 `rules/` 或 `facts/` 时须 ∈ 生成布局全集（`layout-universe` 节登记模板按锚点提取的路径行并集，数据驱动），全集外即 FAIL 指名文件:行号、目标与分类。与检查 21③ 关系（实证定谳）：21③ 对包内 `*.md` 行内链接按包内树判定存在性，不适用于模板生成物相对链接（生成目标是消费项目布局）；modern 生成布局目标解析为其正交补面，故立本检查项而非泛化 21③。零 git 依赖。 |
| 25 | 待定规范声明检测 | 扫描面＝`references/adapters/` 全部 `*.md`（宿主映射手册是适配证据的规范承载面；引擎域常量硬编码，先例检查 21 的 `references/` 与检查 23 的 `governance-format.md` 域路径常量）。窗口＝`#### R-<短码>-<三位序号>` 标题 Level 为 `MUST`/`MUST NOT` 的规则块（标题行起至下一标题行止，检查 22 同款窗口口径）。块内行含【待定】来源标记即 FAIL 指名文件:行号（规范规则只引用已核验事实；未核验面在规则块内用状态词表 `pending`/`unsupported`/`local-observation` 标注，本地实验记录移出 MUST 正文降为注记形态）。行级豁免＝命中行内显式标记 `<!-- pending-decl-exempt: <理由> -->`（理由必填；只限写入指引面——【待定】标记机制的指令行本体，先例 `adapter-template.md` R-AT-001 Stop if）；标记行无【待定】命中、不在 MUST 块内或缺理由即失效豁免 FAIL（检查 12/18/24 同款防漂移口径）。零 git 依赖。 |
| 26 | 适配器注册表闭合 | 单一数据源＝清单 `adapter-registry` 节 `pm_adapter` 行（六字段：platform/shortcode/adapter_file/capability_coverage/role_mapping/evidence_status；宿主绑定事实唯一登记面，短码全局唯一由该节单源验证——跨行重复即加载段结构校验 exit 2 fail-closed；字段格式、platform/shortcode/adapter_file 唯一、platform ∈ `platform-enum` 节宿主值（去 `neutral`）、adapter_file 与 platform 同名基线、coverage ⊆ 基元名单均在加载段核验）。五向闭合：①注册表 ↔ `platform-enum` 节双向全等（注册表侧 ∈ 宿主值在加载段 fail-closed，检查段补宿主值缺注册行方向）；②注册表 ↔ 适配器文件在位（`adapter_file` 存在）；③注册表 ↔ `shortcodes` 节（（短码, 所属文件）对在册且全等；注册短码挂其他所属文件即 FAIL——跨面唯一性锚定注册表）；④注册表 ↔ `capability targets` 节 kind=table 行双向一一全等（互为镜像）；⑤注册表 ↔ 两 README 投影——`references/README.md` 「adapters/」行反引号小写 token 集合与注册平台集全等（父 README 不漏列平台）、`references/adapters/README.md` 目录清单表注册行含短码 token 且表内（短码, 文件）投影对逐对在册（宿主对＝adapter-registry 节、其余对＝shortcodes 节，投影不另立登记事实）。R-CC-005 登记链：platform 枚举登记处（`artifacts-yaml.tmpl` 注释区与 `capability-contract.md` 已知集合句）由检查 11 对 platform-enum 节闭合、本检查①对注册表闭合，两级串联全覆盖。零 git 依赖。 |
| 27 | 适配差异数据表一致性 | 数据＝`references/adapters/adapter-diffs.rules` 四节机器数据行（`pm_adapter_cap`/`pm_adapter_role`/`pm_adapter_exec`/`pm_adapter_dialect`；包根相对落位、包侧唯一副本，与清单共用非执行式解析引擎与分发器；加载段结构校验 fail-closed——四节字段数、platform/primitive/role/status/key 小写 token、（platform, primitive）/（platform, role）/（platform, key）与 exec 平台跨行唯一、platform ∈ 注册表平台集、exec 与 dialect 平台去重集 ↔ 注册平台集双向全等（删任一注册平台整行即缺行指名）、primitive ⊆ 基元名单、readonly-execute 行 constraint 内嵌 `readonly_enforcement:` 声明且等级 ∈ enforcement 词表、每平台基元集合 ↔ 注册表 coverage 双向全等，任一不合预期 exit 2 不产生部分结论）。检查段断言「数据 ≡ 现行五宿主 Markdown 对应段」全等，两向漂移即 FAIL 指名宿主与段：①九行能力表——「\| 能力基元 \|」对照表数据行剥反引号（Markdown 强调记号非内容）后按（基元, 工具, 约束）三列逐行逐字段全等，行序＝文档行序；②三角色映射表——「\| <role-contract-dir>/」行按（角色, 能力名单, 工具口径）三列全等（角色名自路径尾段剥变量前缀与 `.md` 后缀），行序敏感；①②两表列数非 3 的行剥反引号原样输出（比对必失配＝漂移面，防多/少列静默截断）；③独立执行体声明——exec 行锚语原文子串在场断言；④宿主特有方言——dialect 行签名锚语原文子串在场断言。表文修正归人工裁决，不静默互改。零 git 依赖。 |
| 28 | 宿主差异段生成漂移 | 链路＝数据表→生成器→文档段：`generate-adapter-diffs.sh --check` 从 `references/adapters/adapter-diffs.rules` 四节机器数据行渲染 Markdown 差异段（cap＝「\| 能力基元 \|」九行、role＝「\| <role-contract-dir>/」三行、exec/dialect＝锚语），再与现行五宿主 `references/adapters/<platform>.md` 对应段比对：表段只去首尾空白、按三列取单元格后**逐字节** `cmp`（行序敏感；含行内代码反引号等强调记号——数据表字段原文承载，强调记号单侧丢失即 FAIL；宿主 role 列先剥变量前缀与 `.md` 后缀；cap/role 两表列数非 3 的行原样输出＝漂移，不静默截断多余列）；exec/dialect 段锚语原文子串在场。零漂移 exit 0 并输出计数汇总；漂移 exit 1 逐行指名宿主文件、段与首个差异行（生成侧与宿主侧行文随报）；生成器缺件、数据表损坏或包根不可用 exit 2 → 本项 FAIL 并附生成器报文（fail-closed，不产生部分结论）。与检查 27 分工：27 按「两侧同剥反引号后全等」的宽松口径断言「数据表 ≡ 文档」，本项按逐字节严格口径断言「经生成器渲染 ≡ 文档」（生成链路无损复现，含强调记号）；表/文档/渲染三方同批同步即双查同绿。零 git 依赖。 |
| 29 | 退役能力不在活动创建路径 | 清单 `retired-path` 节：退役 token（`create-request`／`Intake`）在活动创建路径面（`references/templates` 递归、`read-policy.md`、`capability-contract.md`）内出现时，同行须带 legacy 标注词（退役／legacy／retired）；缺标注即 FAIL 指名 文件:行号、token 与冲突类型（活动路径不得再提供退役能力）。面缺失 FAIL；awk 异常 exit 2 fail-closed。 |
| 30 | workflow transition endpoint 存在 | 清单 `workflow-graph` 节逐工作流解析 `state_machine`：`initial_state`、transition 的 `from`／`to` 须 ∈ `states`，`trigger` 须 ∈ `steps` 的 id；state 名跨行重复、缺 `initial_state`、零 `transition` 均 FAIL 指名 文件:行号 与端点种类（kind 与值）。 |
| 31 | 状态写票前有合法映射 | 每 state 须在 `state_to_ticket_status` 有映射行（缺映射＝写票前无合法映射），映射键须为已声明 state，映射目标须 ∈ `ticket-status` 词表（八值）；映射节缺失、孤键、越界目标均 FAIL 指名文件与条目（state／目标值）。 |
| 32 | readonly-execute 声明有 enforcement level | 闭包双向：`references/` 树凡声明该能力的文件须在 `readonly-sites` 节登记（未登记／登记悬空 FAIL）；`level` 面须声明等级值 ∈ `enforcement-levels` 词表且同时为 `enforcement target`（双向缺一 FAIL）；`reference` 面须含 `readonly_enforcement` 指针；`authority`＝等级模型定义处（豁免值核对）。 |
| 33 | MUST 不引用待定规范事实 | 检查 25 适配域之外的整包 `*.md`／`*.tmpl`：MUST／MUST NOT 规则块内出现【待定】来源标记即 FAIL 指名 文件:行号（两面并集＝整包闭环）。行级豁免＝行尾 HTML 注释 `<!-- pending-decl-exempt: 理由 -->`（须在 MUST 块内、有命中、理由非空，否则失效豁免 FAIL）；散文提及标记不构成豁免指令。 |
| 34 | README 非唯一执行契约 | 清单 `contract-pointers` 节：含登记锚点的 README 行须含指向权威件的指针原文，权威文件须存在且含权威锚点；README 若以自身充当执行契约唯一载体即 FAIL；缺锚点／缺指针／权威失据均指名 文件:行号 与规则（执行契约正文须落在 schema／协议件）。 |
| 35 | 平台短码注册表闭合 | 补检查 26 的两处闭合缺口：①`shortcodes` 节中 owner 为注册表适配器文件的短码行须在 `adapter-registry` 登记（适配器归属短码以注册表单源，不另立登记）；②平台短码与规则块短码命名空间不得相交（同码两义即 FAIL 指名短码与冲突类型）。 |
| 36 | fixture workflow 不标 production executable | 工作流面 `references/workflows/*.yaml` 须全部在 `workflow-graph` 节登记定位（未登记＝定位未决）；fixture 类须 `description` 含非生产标记词、入口名带 `-fixture` 后缀、不占生产入口名、不含生产可执行声称词；production 类入口名须登记且不得带 fixture 标记（违者 FAIL 指名文件与规则）。 |
| 37 | 模型档位契约结构 | `references/adapters/README.md`「模型档位派生表」数据行恰四行且首列按 C0–C3 有序、第二列非空、C0–C2 三档词两两不同、C3 行第二列不得复用三档词（无第五档）；`adapter-registry` 节登记的五份宿主文件与 `adapter-template.md` 骨架均须含「### 2.6 模型档位可用性」，分档能力／角色级模型键／降级记录格式三条 bullet 各恰一行且值非空，档位表恰三行且档位集合＝派生表三档词（各一次）、取值非空；宿主文件额外断言分档能力以 可逐档／仅单档／不可分档 开头、不可分档宿主三档取值均含 inherit、仅单档与不可分档宿主角色级模型键标待实测、降级记录格式含 model_tier，档位取值含 inherit 时该行同含 inherit。三档词自派生表数据读取（引擎零档位词硬编码），模板骨架只做结构断言；§2.7 短上下文别名与到线策略结构断言：宿主与骨架四条 bullet（短上下文别名取值／到线行为／Agent 工具显式覆盖／降级记录格式）各恰一行且非空，宿主侧别名取值落 README「别名取值词表」、到线行为落「到线行为词表」（两张受控词表，越表即 FAIL），显式覆盖取值 ∈ 可／否／待实测（引擎内闭集），降级记录格式须含 `short_context:` 与 `boundary:` 记录键，写实测结论（离开待实测）时该行须含「实测」字样（阻断以推测或代码阅读替代运行实测）；§2.6 与 §2.7 的 bullet 与表格读取均限定各自小节内（两节同用「降级记录格式」标签，不跨节混算）。 |

## 输出格式

```text
PASS: <编号> <描述>
FAIL: <编号> <描述> — <单行详情>
FAIL: <编号> <描述> 详情：
  <多行详情逐行缩进两空格>
check-package: PASS
```

- 每项编号检查输出一行 PASS 或 FAIL（检查 13 例外：包根父目录无镜像落位目录（`scripts/` 与 `rules/implementation/scripts/` 皆无＝消费项目语境）时整项静默跳过，无输出行；检查 19 例外：包根非 git 语境时静默跳过，无输出行）；任一失败时结尾输出 `check-package: FAIL（N 项未通过，共 37 项）`，全部通过时结尾输出 `check-package: PASS`。
- FAIL 详情为可定位信息：文件清单、命中行（`路径:行号:内容`）或计数差异。

## 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部编号检查通过（检查 23 已退役，无输出行）。 |
| 1 | 存在未通过项（逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数过多、包根不存在、包清单数据缺失或损坏等；数据校验 fail-closed，不产生部分结论）。 |

## package-manifest.rules（包清单数据表）

包结构清单唯一承载点（单源化定稿；逐次扩节；先例 `install-policy.rules`：外置数据＋引擎零专名＋结构校验 fail-closed）。`check-package.sh` 启动时 source 本表（与脚本同目录），检查 1/5/8 的清单与计数、检查 9/10/11/12/13/14/15/16/17/21/23/24/25/26/27/29/30/31/32/34/35/36 的比对基准全部自数据读取，引擎零文件名零短码零枚举值零词表零基元名清单零机制词表零退役 token 零工作流路径零声明面——加成员、加短码、加 platform 值、加措辞词、加豁免、加镜像、加能力基元/目标、加机制词表值、加注册表宿主行、加退役 token/活动面、加工作流登记、加 readonly 声明面、加契约指针＝加一行数据＋改对应实物，零引擎改动。注意：引擎按自身所在目录加载本表（与脚本同目录），对包副本核对时以副本自带引擎＋副本 manifest 才能读到副本数据（harness 豁免负例即此口径）。

### 行格式（二十二节）

| 指令 | 字段数 | 语义 |
| --- | --- | --- |
| `pm_entry <pkg-rel-path>` | 1 | 必需入口文件，包根相对路径（检查 1）。 |
| `pm_script <pkg-rel-path> <kind> <说明>` | 3 | 脚本必需件，须 `scripts/` 前缀加单段文件名（检查 8）；`kind` ∈ `script`（普通脚本）/`rules`（规则表）/`test-harness`（回归 harness）——口径差定谳：`test-record-layer.sh` 定为必需件，kind 标 `test-harness`。 |
| `pm_template <basename>` | 1 | `.tmpl` 模板文件名（检查 5，与 `references/templates/README.md` manifest 表双向）。 |
| `pm_shortcode <CODE> <owner>` | 2 | 规则块两字母短码与其所属文件包内相对路径（检查 10：使用⊆登记；与 `references/` 各目录 README 短码登记面同源）。 |
| `pm_platform <value>` | 1 | platform 枚举值（检查 11，与 `artifacts-yaml.tmpl` 注释区、`capability-contract.md` 登记处一致）。 |
| `pm_vague_word <词>` | 1 | 模糊措辞词表项（检查 12），字面匹配非正则；词表依据＝`references/protocol/governance-format.md` R-GF-010 原文列举（现六词），初版 ≥5 词。 |
| `pm_vague_exempt <pkg-rel-path> <行号> <理由>` | 3 | 检查 12 行级豁免：命中行无法安全换词（只换词不换义不可行）时登记，理由必填；登记行无命中即失效豁免 FAIL，行号漂移须复核更新或删除登记。 |
| `pm_mirror <filename> <ownership>` | 2 | 镜像生成规则（检查 13）：包侧 `agent-up/scripts/` 为唯一手写源，仓侧 `rules/implementation/scripts/` 下同名件为生成物（生成入口 `scripts/generate-mirrors.sh`，幂等、逐件 cmp 自证）。`ownership` ∈ `mirror`（须由包侧源生成；检查 13 核对仓侧生成物存在且与包侧源 byte 全等，缺件/漂移 FAIL 指名；生成物不得手工编辑）/`package-only`（包侧独有，不生成不核对；仓侧同名实例非生成物，不判差异不判存在）；文件名须单段、跨行唯一。 |
| `pm_capability <name>` | 1 | 能力基元名单项（检查 14）：九基元名自 `capability-contract.md` §2.1 权威表现场提取登记，不自造基元；小写 token，跨行唯一。 |
| `pm_capability_authority <pkg-rel-path>` | 1 | 能力权威表文件（检查 14），跨行恰一行：引擎以窄锚点「### …能力基元清单」标题定位其表，首列提取与名单双向全等，锚点失效 exit 2。 |
| `pm_capability_target <pkg-rel-path> <kind> <预期名单>` | 3 | 检查 14 逐一核验目标：`kind` ∈ `decl`（角色合同 `required_capabilities（运行时）` 行，提取反引号名集合）/`table`（适配文件「| 能力基元 |」对照表，提取首列名集合）；预期名单（逗号分隔）为该目标现行声明面/对照表现场转录，载入校验逐名 ⊆ 名单且全部目标并集 ⊇ 名单；目标名集合与预期名单双向全等，多/少/改名即 FAIL 指名文件。 |
| `pm_mechanism <值>` | 1 | 规则索引执行机制受控值（检查 16）：模板 rules 三件（assessment.md.tmpl／discipline.md.tmpl／project.md.tmpl）§16 机制列取值 ⊆ 本节值集；受控三值＝机械（点名脚本/检查项现役断言在管）/门禁（阶段 checkpoint 卡）/约定（靠执行体自觉），语义唯一权威见 `../references/protocol/governance-format.md` §2.7；值须非空单 token，跨行唯一。 |
| `pm_mechanism_marker <标记词>` | 1 | 外定义标记词（检查 15/16），跨行恰一行：模板 §16 中定义于模板外手册的规则块行须在机制列显式标注本标记词，未标注算漏行（豁免显式非静默）。 |
| `pm_cite_exempt <pkg-rel-path> <行号> <理由>` | 3 | 包内票号索引禁令行级豁免（检查 18）；路径+行号跨行唯一，行号须正整数，理由必填；登记行无命中即失效豁免 FAIL；节可空（非空下限节之外的显式例外）。 |
| `pm_layout_face <pkg-rel-path>` | 1 | 布局引用分类扫描面（检查 24）：目录行递归取 `*.md`/`*.tmpl` 并排除 README.md（叙事面，检查 12 同款），单文件行整件入面；跨行不重复。 |
| `pm_layout_universe <pkg-rel-path> <锚点>` | 2 | modern 生成布局全集来源（检查 24②）：引擎按锚点从登记模板提取路径行并集；锚点须受限字符集单 token，登记模板跨行唯一。 |
| `pm_layout_legacy_file <pkg-rel-path> <理由>` | 2 | 整文件合法保留面（检查 24 legacy 分类）：登记文件内旧布局路径引用只计数不判罚；理由必填，路径跨行唯一。 |
| `pm_layout_compat_exempt <pkg-rel-path> <行号> <理由>` | 3 | 检查 24 行级显式兼容豁免：只收显式兼容语义与历史出处注记行，理由必填；登记行无命中即失效豁免 FAIL；节可空（先例同 `ticket-citation-ban`）。 |
| `pm_adapter <platform> <shortcode> <adapter_file> <capability_coverage> <role_mapping> <evidence_status>` | 6 | 平台适配注册表行（检查 26）：宿主绑定事实六字段唯一登记面。`platform` 须小写 token 且 ∈ `platform-enum` 节宿主值（`neutral` 不入注册表）；`adapter_file` 须 `references/adapters/<platform>.md` 同名单段名（adapter-template.md 基线）；`capability_coverage` 逗号分隔基元名单逐名 ⊆ `capability-primitives` 节；`role_mapping`＝宿主三角色承载形态 token（现行四值：frontmatter/config-table/skills/cordis-yml）；`evidence_status`＝适配证据核验状态 token（现行两值：verified＝官方登记取阅核验在册，pending＝官方指针未核验或未全量核验，语义同 R-AT-001 状态词表）。短码全局唯一由本节跨行唯一性验证。 |

| `pm_retired_token <token> <说明>` | 2 | 退役能力 token（检查 29）：在 `pm_retired_face` 登记的活动创建路径面内出现时，同行须带 `pm_legacy_marker` 标注词；token 非空单 token 且跨行唯一。 |
| `pm_retired_face <pkg-rel-path>` | 1 | 活动创建路径面（检查 29）：目录行递归取 `*.md`／`*.tmpl`，单文件行整件入面；路径形态同入口面且跨行唯一。 |
| `pm_legacy_marker <标注词>` | 1 | legacy 显式标注词（检查 29），非空单 token 且跨行唯一；退役 token 行缺任一标注即 FAIL。 |
| `pm_workflow <pkg-rel-path> <positioning>` | 2 | 工作流登记面（检查 30/31/36）：`positioning` ∈ `fixture`／`production`；路径跨行唯一。检查 30/31 核对状态图端点与票状态映射，检查 36 核对定位。 |
| `pm_ticket_status <value>` | 1 | 票状态词表（检查 31）：工作流 `state_to_ticket_status` 映射目标的受控值；小写 token 且跨行唯一。 |
| `pm_workflow_fixture_marker <标记词>` | 1 | fixture 非生产定位标记词（检查 36），跨行恰一行；fixture 工作流 `description` 须含该词。 |
| `pm_production_entry <name>` | 1 | 生产入口名登记（检查 36）：fixture 不得占用、production 须登记；小写 token 且跨行唯一。 |
| `pm_production_claim <token>` | 1 | 生产可执行声称词（检查 36）：fixture 工作流出现即 FAIL；非空单 token 且跨行唯一。 |
| `pm_readonly_site <pkg-rel-path> <mode>` | 2 | readonly-execute 声明面（检查 32）：`mode` ∈ `authority`（等级模型定义处）／`level`（声明具体等级值且须为 `enforcement target`）／`reference`（须含 `readonly_enforcement` 指针）；路径跨行唯一。 |
| `pm_contract_pointer <readme> <锚点> <指针原文> <权威文件> <权威锚点>` | 5 | README 执行契约指针（检查 34）：含锚点的 README 行须含指针原文，权威文件须含权威锚点；README+锚点 对跨行唯一。 |

### 结构校验（fail-closed）

引擎加载时逐行核验，任一不合预期 exit 2，不产生部分结论：字段数恰如上表（字段内禁制表符）；路径禁前导斜杠、空白与 `..` 段，`pm_script` 须 `scripts/` 前缀单段名，`pm_template` 须单段 `.tmpl` 名，`pm_shortcode` 短码两字母大写且 owner 须 `references/` 前缀，`pm_platform` 值须小写 token，`pm_vague_word` 词须非空无空白，`pm_vague_exempt` 行号须正整数且理由非空，`pm_mirror` 须单段文件名且所有权类别 ∈ mirror/package-only，`pm_capability` 名须小写 token 且跨行唯一，`pm_capability_authority` 跨行恰一行，`pm_capability_target` 目标路径跨行唯一且 kind ∈ decl/table，`pm_adapter` platform/shortcode/adapter_file 跨行各唯一、adapter_file 与 platform 同名基线、coverage 逐名 ⊆ 名单、role_mapping/evidence_status 须小写 token，`pm_mechanism` 值须非空无空白且跨行唯一，`pm_mechanism_marker` 跨行恰一行，`pm_layout_universe` 锚点须受限字符集单 token 且登记模板跨行唯一，`pm_layout_legacy_file` 理由非空且路径跨行唯一，`pm_layout_compat_exempt` 行号须正整数且理由非空且路径+行号跨行唯一，`pm_retired_token` 非空单 token 且跨行唯一，`pm_retired_face`／`pm_workflow`／`pm_readonly_site` 路径形态且跨行唯一（`pm_workflow` positioning ∈ fixture/production，`pm_readonly_site` mode ∈ authority/level/reference），`pm_legacy_marker`／`pm_production_claim` 非空单 token 且跨行唯一，`pm_ticket_status`／`pm_production_entry` 小写 token 且跨行唯一，`pm_workflow_fixture_marker` 跨行恰一行，`pm_contract_pointer` 五字段且 README+锚点 对跨行唯一；`kind` 枚举三值；各节内路径/文件名/短码/值/词/路径+行号跨行不重复；`pm_capability_target` 预期名单逐名 ⊆ 名单且全部目标并集 ⊇ 名单（名单与检查目标互恰）；除 `vague-exemptions` 与 `ticket-citation-ban`、`layout-compat-exempt` 节可空外，其余各节每节至少一行。

### 维护规则

清单变更先改数据再改实物（数据先行）；本表与 `scripts/README.md` 成员表、`references/` 各目录 README 登记面为「数据＝机器真相、表＝人读投影」关系，一致性由检查 5/9 机械核对，漂移即 FAIL（表文修正归人工裁决，不静默互改）。短码或 platform 新值：先在数据表登记（宿主绑定六字段＝`adapter-registry` 节单源），再按 `references/protocol/governance-format.md` 与 `references/adapters/capability-contract.md`（R-CC-005）流程落登记处与实物；宿主短码投影（`references/adapters/README.md` 与 `references/README.md` adapters 行）由检查 26 对注册表闭合。

vague-words 词表与 vague-exemptions 豁免维护：词表以 R-GF-010 原文列举为准，加词/减词＝改 `vague-words` 节行并同步 harness 夹具（check-package 套件 PASS 行含词数计数，预期串须随动）；扫描窗口与排除口径注记于本表头部注释（规则块体、排除「解释与例外」节与 README 文件）。命中处置顺序：先判可否只换词不换义地修正（保语义），不可安全换词才登记豁免；豁免必须注记理由（引述词表本身的禁令条款属正当豁免，依据 R-GF-010 Evidence「禁令条款内的引述除外」）；正文行增删使豁免行号漂移时，检查 12 报失效豁免，处置＝复核后更新行号或删除登记，不得静默保留。

capability-primitives 名单与检查目标维护：九基元名以 `capability-contract.md` §2.1 权威表为唯一事实源，禁止单侧改——基元增删改名＝先改权威表，再同步本节 `pm_capability` 行与 `pm_capability_target` 预期名单，再改目标实物（角色合同声明行/适配文件对照表），最后同步 harness 夹具（check-package 套件 PASS 行含基元数与目标数计数，预期串须随动；注入/删名负例随名单语义复核）。新增检查目标＝加一行 `pm_capability_target`（预期名单现场转录自目标现行声明面/对照表）并确认并集 ⊇ 名单校验仍过；目标正文声明变化＝先改预期名单再改实物（数据先行）。解析锚点（声明行标记、对照表头列、权威表标题）为引擎窄锚点，目标文件锚点文本漂移即 exit 2，须同步引擎锚点与本注记。

mechanism-vocab 词表与规则索引维护：受控三值以本节为唯一承载点，引擎零词表硬编码；三值语义唯一权威＝`../references/protocol/governance-format.md` §2.7。词表增删值＝先改本节，再改生成器 `generate-docs-index.sh` 内的机制登记表，并同步 harness 夹具（正例 PASS 行含机制值数计数）。索引维护顺序＝先改生成器登记表与规则块本体，再重跑生成器；漂移与缺行由检查 15（全集全等＋`--check`）拦截，机制值越界由检查 16 拦截。机械行点名的脚本必须已在 `scripts` 节登记且真实存在，检查项号须 ≤ 当前检查上限（检查 17），新脚本先登记 `pm_script` 行再进索引机制列；点名的检查项号不得超过引擎检查总数，引擎扩项时同步 `n_total_checks` 与相关表述。

layout-face/layout-universe/layout-legacy-file/layout-compat-exempt 四节维护（检查 24）：面清单与合法保留面变更＝先改本表再动实物（数据先行），并同步 harness 夹具（正例 PASS 行含面件数与 legacy 计数，预期串须随动）；`layout-universe` 登记模板的锚点路径行增删＝实物先行、全集随之（锚点或行形态漂移即提取失效，链接核对失准须同步本节）；`layout-compat-exempt` 只收显式兼容语义与历史出处注记行（逐行注记理由），禁作漏改旧布局引用的兜底；正文行增删使豁免行号漂移时检查 24 报失效豁免，处置＝复核后更新行号或删除登记，不得静默保留。旧布局引用清理顺序＝先逐条判适用布局（modern 面改写为现行路径与权威名，legacy 合法保留面与显式兼容段保留），逐条处置，禁全局替换。

### 适配差异数据表（references/adapters/adapter-diffs.rules）

检查 27 与检查 28 的数据源（包根相对落位、包侧唯一副本、无 `pm_mirror` 镜像登记；检查 1 经 `entry-files` 节登记在册）。引擎以与清单共用的非执行式解析引擎加载本表（词法与 fail-closed 语义同一程序），四节机器数据行承载五宿主（zcode/claude-code/codex/pi/dsh）适配文件的宿主差异面；「数据＝机器真相、宿主 Markdown＝现行文档基线」，两向漂移由检查 27 机械指名（宿主与段），表文修正归人工裁决，不静默互改。

字段内的 Markdown 行内代码记号（反引号）按宿主原文保留，故本表可直接作为生成器的逐字节复现输入（检查 28 的严格口径依赖于此）；反引号在此为惰性文本——非执行式解析器对本表开启「单引号内字面反引号」模式，命令替换与参数展开形态仍拒绝，清单侧维持默认拒绝（恶意输入门禁不放宽）。

| 指令 | 字段数 | 语义 |
| --- | --- | --- |
| `pm_adapter_cap <platform> <primitive> <tool> <constraint>` | 4 | 九基元↔宿主工具映射行（capability-map 节；每平台九行，行序＝宿主对照表行序）。`platform` 须小写 token 且 ∈ `adapter-registry` 节注册平台集；`primitive` 须小写 token 且 ⊆ `capability-primitives` 节名单，（platform, primitive）跨行唯一；`readonly-execute` 行 constraint 须内嵌 `readonly_enforcement:` 声明且等级 ∈ `enforcement-levels` 词表；每平台基元集合与注册表 coverage 字段双向全等。 |
| `pm_adapter_role <platform> <role> <capabilities> <tools>` | 4 | 三阶段角色映射行（role-map 节；每平台三行，行序＝宿主角色表行序）；role 须小写 token，capabilities/tools 非空，（platform, role）跨行唯一。 |
| `pm_adapter_exec <platform> <status> <anchor>` | 3 | 独立执行体状态行（executor-status 节；每平台恰一行）；status 为受控 token（语义单源＝本节登记），anchor＝宿主文件声明句原文锚语（检查 27 在场断言），platform 跨行唯一且去重集 ↔ 注册平台集双向全等（缺任一注册平台即加载段 fail-closed 指名平台）。 |
| `pm_adapter_dialect <platform> <key> <anchor>` | 3 | 宿主特有方言签名行（dialect-signature 节；每平台至少一行）；key 为方言签名 token（语义单源＝本节登记），anchor＝宿主文件方言模板签名原文锚语，（platform, key）跨行唯一且 platform 去重集 ↔ 注册平台集双向全等（缺任一注册平台即加载段 fail-closed 指名平台）。 |

结构校验 fail-closed（任一不合预期 exit 2，不产生部分结论）：四节字段数恰如上表（字段内禁制表符）；platform/primitive/role/status/key 须小写 token，platform ∈ 注册表平台集、primitive ⊆ 基元名单；tool/constraint/capabilities/anchor 非空；跨行唯一口径如上表；exec 与 dialect 的 platform 去重集 ↔ `adapter-registry` 节注册平台集双向全等（exec 每平台恰一行、dialect 每平台至少一行；缺任一注册平台即 exit 2 指名段与平台）；readonly-execute 行等级 ∈ 词表；每平台 cap 基元集合 ↔ `adapter-registry` 节 coverage 字段双向全等。本表零票号引用（检查 18 扫描面含 `*.rules`）；变更口径＝任一侧（本表或宿主 Markdown）变化即被检查 27 拦截，同批同步两侧并随动 harness 金样（PASS 行含行数与条目计数）。

## generate-adapter-diffs.sh（宿主差异段生成器与生成漂移核对）

- 用途：本表四节机器数据行 → 宿主差异段 Markdown 行的唯一渲染器；渲染输出与现行宿主文件对应段零差异即「生成链路无损复现现行文档」，构成文档改写（去重/收敛类改动）前的机械基线。
- 用法：`sh scripts/generate-adapter-diffs.sh [--pkg-root <dir>] [--platform <p>] [--section cap|role|exec|dialect|all] [--check]`（包根缺省取脚本所在目录的上一级；平台缺省全部注册平台，序＝数据表首次出现序）。`--section` 渲染单段供人读/夹具断言：cap 出九行 `| 基元 | 工具 | 约束 |`、role 出三行 `| <role-contract-dir>/<role>.md | 能力 | 工具 |`、exec/dialect 出锚语行；`all` 四段全出、段间空行分隔。
- `--check`：逐宿主逐段比对现行宿主文件——表段只去首尾空白、按三列取单元格后**逐字节** `cmp`（行序敏感；含行内代码反引号等强调记号，数据表字段原文承载，故强调记号单侧丢失即漂移；宿主 role 首列先剥 `<role-contract-dir>/` 前缀与 `.md` 后缀）；exec/dialect 段锚语原文子串在场断言。零漂移 exit 0 并输出计数汇总（宿主数／四段条目数）；漂移 exit 1 逐行指名宿主文件、段与首个差异行（两侧行文随报）；数据表损坏或包根不可用 exit 2。
- 与检查 27 的关系：27 按「两侧同剥反引号后全等」的宽松口径断言「数据表 ≡ 文档」，本件按逐字节的严格口径断言「生成器渲染后 ≡ 文档」；检查 28 调用本件承载后者，两者同批同步即表/文档/渲染三方一致，且 28 额外兜住强调记号单侧丢失。生成器只读零写入，不改任何侧内容（表文与宿主正文修正归人工裁决）。
- 退出码：0 渲染成功或零漂移；1 漂移；2 用法、数据表或包根不合预期（fail-closed）。

## check-stale-claims.sh（易腐断言扫描器）

登记表驱动的易腐状态句扫描器（REQ-20260904-010）：对登记表内的高流转状态句逐条对现实核验，供票收口拦截与会话启动提醒。POSIX sh（`#!/bin/sh`、`set -eu`）、全程只读（除向 stdout/stderr 打印外无写操作，Git 仅使用只读子命令）、零外部依赖、零网络依赖。

### 用法

```text
sh scripts/check-stale-claims.sh [repo-root] [gate|session]
```

- 无参数：按脚本落位形态自推导仓库根——`agent-up/scripts/` 落位取上两级（＝包根的仓库根，在本仓库内运行时检的就是本仓库）、`rules/implementation/scripts/` 落位取上三级（＝仓库根）；其余落位形态 fail-closed 报错退出 2（不静默错根），显式传 repo-root 参数即可。模式默认 `gate`。
- 带参数：第一参数为仓库根，第二参数为模式；模式也可用环境变量 `STALE_CLAIMS_MODE` 指定（第二参数优先）。
- `-h` / `--help`：打印用法。

### 两模式

| 模式 | 触发场景 | 行为 |
| --- | --- | --- |
| `gate`（默认） | 票收口模式 | 发现过期断言输出 `路径:行号:内容` 定位并 exit 1 拦截；清洁 exit 0。 |
| `session` | 会话启动模式 | 输出与 gate 相同的 STALE/WARN 明细，但只作警告不拦截，恒 exit 0。 |

### 登记表结构

登记表内置于脚本，条目结构为 `{断言模式, 权威位置, 校验方式}`，只登记高流转状态句。现役八条（S1～S3 为首批，S4 计数漂移增补，S5 方案结论标注增补，S6 终态哨兵增补，S7 替代标记存在性增补，S8 复盘沉淀指针增补；权威位置为现行文档真实路径）；S1/S2 为配置点亮条目——是否点亮＝仓根 `delivery.rules` calibration 节 `dp_stale_lit` 登记（`S1`/`S2` 枚举，解析破坏 exit 2 fail-closed），未点亮打印 `SKIP: Sx — delivery.rules 未点亮（dp_stale_lit 缺登记）` 不计过期断言不拦票；点亮则现行断言逻辑原样执行，其中 remote 名（S1-1c/S2）、包前缀（S2 次级权威位置）与本地导出分支名（S1-1b）自 payload 节读取（未声明 payload 节＝不可知，退化 WARN 跳过不硬猜）；宣称锚点句属协议面留引擎（设计票 §2 分界判据）；S3/S4/S5/S6/S7/S8 为通用面无点亮位恒执行。

| 编号 | 断言模式 | 权威位置 | 校验方式 |
| --- | --- | --- | --- |
| S1 | Git 状态句 | `facts/project/archive/progress.md` 的「Git 恢复基线」块（2026-09-23 自 docs/progress.md 迁址） | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、唯一 remote 与宣称地址一致、本地 main 未被远端跟踪分支包含）；非 Git 工作区按流程退化语义输出提醒跳过。（修订：移除"工作区存在未提交改动"子项核对——该陈述为历史时点快照，`facts/project/archive/progress.md` 现为冻结历史档案（零写入），清洁工作区属稳态，逐字核对构成恒触发误报（S1-1e 已知缺口）；基线块原文按"不改历史"保留。） |
| S2 | 发布状态句 | 根 `README.md`「公开包已发布」宣称行 + 包内 README 安装行（包前缀自 `delivery.rules` dp_payload_root 派生） | machine：文档宣称的仓库地址与实际 remote 配置归一化比对（remote 名自 dp_payload_remote 读取）、包内安装行同源核对；远端可达性/可见性本地不核验（不出网）→ reminder。 |
| S3 | frontier 句 | `facts/requirements/tickets/index.json`（票状态真相源）+ `facts/requirements/tickets/progress-current.md`（现役状态投影） | machine：投影 vs 索引比对——优先调用 `generate-progress.sh --check`（exit 0 一致；exit 1 投影 stale 或缺失；exit 2 索引缺失或条目排版不合预期）→ 差异即过期断言；生成器不可用时退化为内建最小比对（id/status/updated_at 三元组）并输出 NOTE 说明（不计入失败）。（修订：原"issue 表行逐票对照票面状态"实现退役——README 票表现为索引派生生成块，一致性由 S4 生成块新鲜度核对承载，与索引冲突时以索引为准。） |
| S4 | 计数漂移句 | `facts/requirements/tickets/README.md` 票表生成块 + `facts/requirements/tickets/index.json`；`facts/` 树 md + `facts/project/artifacts.yaml` 现行面计数措辞 | machine：两断言（详见下文 S4 小节）——①生成块新鲜度：README 票表为索引派生生成块，调 `generate-progress.sh --check-readme` 只读核对是否等于索引派生结果（派生口径唯一实现＝生成器，本件零副本）；漂移或未迁移即 STALE 指名生成器报因，README/索引缺失或生成器不可用 WARN 跳过不硬猜。②计数模式扫描：「N～M 共」「共 N 量词」命中输出 STALE-prone 指名 file:line、计入过期断言计数（gate exit 1 / session 只警告）；扫描面排除与豁免表见下文 S4 小节。 |
| S5 | 方案结论标注句 | 扫描面 glob 清单登记的方案类文档（`s5_load_globs` 数据节，现行唯一条目 `facts/requirements/research/*.md`（源仓实例迁移后）；扩面须同步修订 R-DP-033 条文与数据节） | machine：R-DP-033 加固配套格式断言（详见下文 S5 小节）——结论行（行首「结论：」形态）逐行核对证据出处（`file:`）与适用轨（`轨:` 受控两值 本仓自用/agent-up）；只查格式不判语义；向前生效只查工作区新增/修改面（`git status --porcelain`），存量不回溯；非 Git 工作区 WARN 退化跳过。 |
| S6 | 终态哨兵 | `facts/requirements/tickets/index.json`（票状态真相源，一条目一行）＋该索引的 Git 现行提交历史（基线锚） | machine：终态哨兵（详见下文 S6 小节）——索引内 id 曾达终态（done/superseded）而当前 status 回到非终态（ready/in_progress/blocked/review_ready/review_pass/review_fail）即 STALE 指名票 id 与跃迁方向；非 Git 工作区 WARN 退化跳过，索引尚无基线提交且当前行无可提取条目（无可比历史）WARN 跳过；对账分层＝一致性对账（S3 投影↔索引）之外终态语义由 S6 承载。 |
| S7 | 替代标记存在性 | `facts/requirements/tickets/index.json`（票状态真相源，一条目一行） | machine：superseded_by 存在性断言（R-DP-039 替代标记面配套）——索引条目含非空 superseded_by 时，指向的票 id 必须真实存在于本索引（缺失即 STALE 指名双方 id）；指向票自身亦带标记（替代链环/自指）即 STALE；指向票状态非终态（替代票尚未收口）仅 WARN 不拦截（先标后收合法顺序）；字段缺失＝零命中零报（可选字段语义，存量票零回扫），不按时间自动打标。 |
| S8 | 复盘沉淀指针 | `facts/project/changes.jsonl`（教训账本，kind=lesson 行） | machine：沉淀指针核对（R-DP-041 检查面配套）——lesson 行 promoted_to ∈ {rules, validator, test} 且 decision/evidence_ref 含可 grep 文件指针（rules/ 或 scripts/ 路径，可带 #锚点后缀）时，核对指针文件仍存在且锚点在场：文件缺失或锚点丢失＝STALE 指名行号与指针（沉淀被删或指针写错）；promoted_to ∈ {新票, none} 不在扫描面；指针不可 grep 形态＝NOTE 退化不计失败；append-only 校正由人落新行，S8 只报警不代写。 |

机器可校验项直接对现实核验；不可机器校验项输出存在时长提醒（WARN，阈值【待定】，定稿后同步本登记）。

### 输出格式

```text
STALE: <路径:行号> — <断言与现实的差异说明>
WARN: <路径:行号> — <提醒内容（含登记日期与【待定】阈值标注）>
NOTE: <路径> — <比对机制退化说明（生成器不可用时退化为内建最小比对；不计入失败）>
STALE-prone: <路径:行号> — 计数模式命中（S4-②，计入过期断言计数）：改写为计数无关措辞或按登记表注记理由豁免
SKIP: S1 — delivery.rules 未点亮（dp_stale_lit 缺登记）    # 点亮语义：未点亮条目不计数
STALE: facts/requirements/tickets/index.json:<票id> — S6 终态哨兵：票 <票id> 曾达终态，当前 status 被改回非终态 <状态>——done/superseded 为终态，幽灵态即报；合法复开须以新票承载（改 id）或显式 superseded 登记
STALE: facts/requirements/tickets/index.json:<票id> — S7 替代标记断言：票 <票id> 的 superseded_by 指向 <票id>，但该票不在索引中——替代标记指向的票必须真实存在（R-DP-039），修标或先开替代票
check-stale-claims: PASS（登记表 N 条全部核对，提醒 N 条）    # gate 模式清洁；N＝点亮数＋通用条数（动态化，全点亮语境渲染 8）
check-stale-claims: FAIL（N 处过期断言，登记表共 N 条）       # gate 模式存在过期断言；N 同上
check-stale-claims: 会话启动模式（不拦截）：过期断言 N 处，提醒 N 条，请人工核对上方输出
```

- STALE 行含 `路径:行号` 定位与差异说明；WARN 行为提醒（非失败）；NOTE 行为 S3 比对机制退化说明（非失败）；STALE-prone 行为 S4-② 计数模式易腐命中（计入过期断言计数，与 STALE 同口径参与 gate 拦截 / session 警告）；结尾汇总行给出计数与结论。
- S3 生成器定位顺序：本脚本同目录（包内自含）→ `<repo-root>/rules/implementation/scripts/`（新布局落位安装形态）；两处均不可用才退化内建最小比对。两模式对生成器退出码的语义映射一致：差异与异常均计 STALE，gate 拦截 / session 警告。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | gate 模式下无过期断言（提醒照常输出），或 session 模式。 |
| 1 | gate 模式下存在过期断言（STALE 行见输出）。 |
| 2 | 用法或环境错误（参数过多、模式非法、仓库根不存在等）；S4 豁免表结构破坏、S5 扫描面 glob 登记破坏与 delivery.rules 解析破坏亦 exit 2（不产生部分结论）。 |

### S4 计数漂移哨兵

推数字免费化哨兵（先例实证：数字会腐烂、计数无关措辞不会；真发现源头＝artifacts.yaml 注记 16→60 计数漂移穿透既有门禁）。两断言语义：

- S4-① 生成块新鲜度：`facts/requirements/tickets/README.md` 票表为索引派生生成块，调同目录 `generate-progress.sh --check-readme` 只读核对现行块是否等于索引派生结果（派生口径唯一实现＝生成器，本件零副本、不按实现猜）；漂移或块缺失但目录清单表在场（未迁移）即 STALE 指名生成器报因，README/索引缺失或生成器不可用 WARN 跳过不硬猜（随既有退化语义）。原「锚点行数 ↔ 索引条目数」数量相等断言随票表生成化退役（该面漂移已由生成块重算与新鲜度核对覆盖）。
- S4-② 计数模式扫描：扫描面＝`facts/` 树 `*.md` ＋ `facts/project/artifacts.yaml`，出现「<数字>～<数字> 共」或「共 <数字> <量词>（张/条/项/件/个）」即输出 STALE-prone 指名 file:line、计入过期断言计数（gate exit 1 / session 只警告）；模式为 ERE、全程 LC_ALL=C 字节语义。

扫描面排除（历史真陈述/机器生成面非现行声明，命中不报；2026-09-21 协调层裁决 O3 收窄）：`facts/requirements/tickets/*.md`（票面历史文件——历史票文不改写原则）、`facts/requirements/runs/`（run record 投影）、`facts/project/architecture/generated/`（机器生成投影面）、`facts/project/archive/progress.md`（冻结历史档案——指针注记后零写入；2026-09-23 自 docs/ 迁址）、`facts/project/archive/changes.md`（只追加账本冻结件——历史条目不可改写；同批迁址）、`facts/requirements/tickets/progress-current.md`（现役状态投影——Derived 生成器独占写）。

豁免表（脚本内 `s4_load_exempts` 数据节，唯一承载点）：每条一行 `s4_exempt <仓库根相对路径> <行号> <理由>`，理由必填、显式登记、无静默豁免；命中行增删致行号漂移时须复核更新或删除登记（对齐 `package-manifest.rules` vague-exemptions 维护口径）。当前空表交付（裁决定谳）＝现行面全数字免费，本表为未来正当例外预留。

### S5 方案结论标注句

R-DP-033 加固（2026-09-23 复盘产出）配套格式断言：调研/对比产出的结论行逐条标注证据出处与适用轨。断言只查格式不判语义——标注的出处是否真支撑结论归独立评审（合同 Forbidden）。

- 结论行识别规则（登记防误扫）：行首（允许前置空白与一个「- 」列表标记）以「结论：」起始的行；非此形态零命中即零报。
- 结论行格式断言：①证据出处——行内至少一处 `file:`；②适用轨——行内 `轨:` 标注取值 ∈ 受控两值（`本仓自用`／`agent-up`；未来多产品轨预留登记机制不扩展实现）。缺任一即 STALE 指名 `文件:行号`、计入过期断言计数（gate exit 1 / session 只警告）。
- 向前生效（条文写死，风险注记：存量若回溯即红）：只查工作区新增/修改面——`git status --porcelain --untracked-files=all` 判定（未跟踪/新增/修改/改名后路径），存量已提交文件不回溯；非 Git 工作区按流程退化语义 WARN 跳过（对齐 S1）。
- 扫描面 glob 清单（脚本内 `s5_load_globs` 数据节，唯一承载点；条文同步登记于 R-DP-033，扩面两处同步改、禁静默扩面——词表扩面教训）：每行一条「`<目录>/*.md`」形态（单层语义）；现行唯一条目 `facts/requirements/research/*.md`（源仓实例迁移后随波④扩面）；登记破坏（非该形态）exit 2 fail-closed；病态形态（路径含空白/冒号、非 ASCII 引号转义路径）不受理（对齐 S4 已知限制）。

### S6 终态哨兵

终态哨兵（2026-09-24 链执行复盘缺口④配套，R3/R8 合并票）：`facts/requirements/tickets/index.json` 内 id 曾达终态（`done`/`superseded`）而当前 status 回到非终态（`ready`/`in_progress`/`blocked`/`review_ready`/`review_pass`/`review_fail`）即 STALE 指名票 id 与跃迁方向、计入过期断言计数（gate exit 1 / session 只警告）。防的病＝幽灵态静默（重放/误操作把 done 票打回 in_progress 时，投影↔索引一致性对账照绿——一致性对账不查状态语义合法性；对账分层：一致性对账之外，终态语义由 S6 承载）。

- 状态词表（受控，与 `ticket-ops.sh flip --status` 状态机八值一致）：终态 `done | superseded`；非终态 `ready | in_progress | blocked | review_ready | review_pass | review_fail`；词表外的 status 值不越哨兵面零报（排版/词表破坏归 S3 `--check` exit 2 语义）。
- 基线锚＝该索引的 Git 现行提交历史：`git log -p --format= -- facts/requirements/tickets/index.json` 提取历次 + 行的 `id`/`status` 对（缩进宽容），曾见终态即入哨兵集；当前行（工作区现状）同款提取后与哨兵集求交，仅「曾终态→现非终态」报。选型理由：零新增数据源——终态史已由仓库历史承载，夹具/快照清单反而成为第二本可漂移的账；真实历史全量回放零误报（合法流转 done→superseded 等均为终态间迁移不触发）。
- 合法复开路径＝改 id（新票承载重开，旧票显式 superseded 登记）或 `ticket-ops.sh flip` 至合法状态机值；重开终态票属非法跃迁，机器喊。
- 退化语义：非 Git 工作区 → WARN 跳过；索引尚无基线提交**且**当前行无可提取条目（无可比历史）→ WARN 跳过不硬猜（对齐 S1/S5）；索引文件缺失 WARN 跳过（对齐 S3 缺失语义）。已知限制：基线提取走 `git log -p`，merge commit 默认不出 patch——仅经合并冲突引入索引的终态史不入哨兵集（现行流程翻转均经普通提交）；单文件一条目一行排版为提取口径（与 S3 同款），条目跨行排版不受理。

## check-gates.sh（快道门禁核对器）

分级交付道快道的门禁核对器（REQ-20260904-011）：对行式门禁清单逐项核对「工作区实际改动 ⊆ 白名单」，并按清单重跑验证命令、记录退出码，供票收口与道脚本收尾调用。现行版本起对「验证命令更改工作区」零容忍：check-gates 自身不写工作区，但 verify 是任意 shell 命令、可能写入原工作区；每条 verify 执行前后各取一次完整快照，白名单外变化一律失败并保持现场。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖（POSIX 工具与 Git 只读子命令）、零网络依赖。

### 验证命令执行边界

- 快照面：仓库内全部普通文件（含被 `.gitignore` 忽略的文件）的路径、内容对象哈希（经 `git hash-object`，零临时写入仓库）与可执行位；全部目录条目；符号链接的目标哈希；FIFO/套接字等特殊文件的路径存在性；索引条目（mode、blob、stage）；`HEAD` 提交与 `HEAD` 符号引用。
- 快照时机：每条 verify 执行前、执行后各一次。已被修改的文件被再次改写时 `git status` 行可以不变，内容哈希仍能检出——状态行不是判定依据。
- 越界处置：白名单外出现新增、删除或变更即 exit 1，输出失败命令、异常路径（新增/删除/变更）与前后状态差异；异常路径不删除、不回滚，前后快照保留在 `$TMPDIR` 的 `check-gates.*` 目录供诊断；同批剩余 verify 不再执行（输出 `SKIP:` 行），避免越界写入继续扩大。
- 允许输出目录：门禁清单可选 `allow-output:` 行，逗号分隔仓库根相对目录，缺省为空（默认不允许任何写入）。该目录内未跟踪产物的创建、修改与删除视为合法输出，不计越界，也不要求写进 `whitelist:`；同一产物在后续门禁复跑中同样按允许输出放行。目录内含已跟踪文件即拒绝配置（exit 2）——放行面只覆盖未跟踪产物，跟踪文件的任何改动仍须经白名单核对。路径不得为绝对路径、不得含 `..` 段、不得指向 `.git`。
- 已知边界：`.git` 内部对象与引用不在快照面（Git 自身内务会触碰；索引与 HEAD 的变化另经索引/HEAD 快照检出）；验证命令的瞬时写入在同一命令内删除或恢复（净零变化）不判；工作区或索引路径含换行、制表符时拒绝生成快照（exit 2）。
- 成本：每次快照对仓库内全部文件做内容哈希（未使用 `allow-output` 时含 `node_modules` 等被忽略目录）。大缓存目录应登记到 `allow-output`，或接受门禁耗时随仓库体积增长。

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
| `verify: <验证命令>` | 一行一条，可多行；普通快道至少一条真实命令。纯记录例外只允许唯一 `verify: N/A`，且必须同时声明 `record-only: <理由>`。 |
| `allow-output: <逗号分隔的仓库根相对目录>` | 可选，缺省为空（不允许任何 verify 写入）；目录内未跟踪产物视为合法输出。目录内含已跟踪文件、路径为绝对路径或含 `..` 段即拒绝配置（exit 2）。 |
| `record-only: <纯记录理由>` | 可选，显式声明纯记录例外；不得与真实 verify 命令混用。 |
| `# 注释` / 空行 | 行首 `#` 与空行忽略；无法识别的行判格式错误（exit 2）。 |

白名单口径：白名单条目须为仓库根相对**文件路径**。改动集以 `git status --porcelain -uall` 逐文件展开（未跟踪目录不折叠为目录条目），逐文件与白名单条目做全字面比对——目录形态条目（如 `docs/`）在逐文件口径下永不可 PASS，属 fail-closed 方向；`allow-output` 目录内的未跟踪改动按允许输出放行（输出 `PASS: 改动 <路径>（在允许输出目录内）`），不要求重复登记到白名单；路径含空白或转义引用时拒绝解析（exit 2）。

### 输出格式

```text
PASS: 改动 <路径>（在白名单内）
PASS: 改动 <路径>（在允许输出目录内）
FAIL: 改动 <路径>（不在白名单内）
PASS: verify[<序号>] exit=0 <命令>
FAIL: verify[<序号>] exit=<退出码> <命令>
  <verify 失败时的命令输出，逐行缩进两空格>
FAIL: verify[<序号>] 越界改动工作区 N 项（新增 X／删除 Y／变更 Z）
  失败命令: <命令>
  异常路径（新增/删除/变更 ...）:
    + <路径>（新增）／- <路径>（删除）／~ <路径>（变更）
  前后状态差异（前 -／后 +）:
    - <前快照行>
    + <后快照行>
  现场保留: 异常路径不自动删除、不回滚；前后快照保留于 <目录>
SKIP: verify[<序号>] 未执行（前序验证越界改动工作区，就地停止） <命令>
check-gates: PASS（改动 N 项全部在白名单内，verify N 条全部通过）
check-gates: FAIL（N 项未通过）
```

- 实际改动的每个文件（重命名行展开为新旧两侧）逐项输出一行 PASS 或 FAIL；verify 逐条输出退出码记录行，失败时附命令输出（缩进两空格）；越界写入另输出失败命令、异常路径与前后快照差异行（快照行格式为 `路径<TAB>类型<TAB>状态`，差异行截断至 20 行，完整内容见保留的快照目录）；结尾汇总行给出计数与结论。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部通过（改动全在白名单内且 verify 全部 exit 0 且未越界写工作区）。 |
| 1 | 有未过项（越界改动、verify 失败或 verify 越界写工作区，逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库、清单不可读、清单缺少 whitelist 行、清单行无法识别、allow-output 配置非法、快照无法生成、git status 行无法解析等）。 |

## lane-commit.sh（快道收尾脚本）

分级交付道快道的合同驱动收尾脚本（REQ-20260904-011；单写机制改造）：门禁核对 → 白名单产品提交 → 记录写入（索引翻转经同目录 `ticket-ops.sh` `flip-index` 代理——索引单写＋投影再生＋`--check` 收尾链由代理一处承载，写入方收敛后本件零直接 index.json 写入面与零直接生成器调用 → 票正文 Status 投影打印件回写（`.md` 票；`.json` 票体无 `**Status:**` 行，跳过回写并打印说明行）→ Review Checkpoint 经 `checkpoint-write.sh` 写入（`.md` 票追加票尾；`.json` 票体零追加，落独立 `facts/requirements/tickets/<id>-review-checkpoint.md`，`<id>` 为票文件去 `.md`/`.json` 后缀）或微账本经 `ledger-append.sh --micro` 落行（记录写职责外移，本件零 checkpoint/账本写入面））→ 记录提交，两段式（先产品提交后纯记录提交，R-RC-003）。行为基线 = development-process 模板 §12.5 道脚本承载注记（索引单写经 ticket-ops flip-index 代理 → 生成正文 Status 行 → 生成投影）。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖、零网络依赖、fail-closed（门禁不过、合同格式不合预期、索引代理 ticket-ops.sh 或记录写入代理 checkpoint-write.sh／ledger-append.sh 缺失即停止报告；预检先于产品提交，停止时零提交零写入，不 best-effort 修补）。脚本权限边界 = 提交合同白名单，不执行白名单外任何写入；`facts/project/archive/progress.md` 状态行不属本脚本写入面（README 票表生成块由生成器派生并随记录提交收编，本件不手写）。

### 用法

```text
sh scripts/lane-commit.sh [repo-root] <contract-file>
sh scripts/lane-commit.sh --record-commit <repo-root> <message> <记录路径>...
```

- 无参数：仓库根取当前目录所在 Git 仓库顶层；提交合同文件为第一参数。
- 带参数：第一参数为仓库根，第二参数为提交合同文件（行式临时输入，不落仓库）。
- `--record-commit <repo-root> <message> <记录路径>...`：记录提交单点入口（也可独立调用）。参数至少三件；记录路径须为 `facts/` 下的仓库根相对普通文件，且在工作树存在（删除/缺失即指名拒绝）。入口持与 `ticket-ops.sh`／`ledger-append.sh` 同一把记录层写锁（锁目录＝Git 公共目录，跨 worktree 共享），用私有索引（`GIT_INDEX_FILE`，从 HEAD 初始化，不写共享索引）只暂存给定记录路径，提交前断言：① 记录路径无部分暂存（暂存内容与工作区逐字节一致，否则报首个差异行）；② 只追加账本（`facts/project/changes.jsonl`、`facts/project/micro.jsonl`）的 HEAD 旧内容须为待提交版本（私有索引 blob）的字节前缀，否则报首个违规行号（待提交版行号）；③ 私有索引写出的树文件集恰为记录路径（记录面外文件即拒绝）。未改动的记录路径显式打印 `记录路径无改动，已排除: <清单>` 后跳过，不进入提交。任一断言不成立即 `exit 1` 且零提交、历史行零改写（不回滚已暂存内容）；断言通过后经 `git write-tree` → `git commit-tree` → `git update-ref` CAS 更新当前分支（旧 HEAD 不匹配即失败，零提交）——断言对象＝被提交树，提交窗口内他人暂存（中间插入版/产品文件）不卷入，成功后仅把仍是旧 HEAD 快照的记录路径同步到新提交，并发暂存保留现场。成功打印 `lane-commit: 记录提交门: 同锁串行（锁目录 …）` / `记录提交 <ID>` / `记录文件: <清单>`。注：`commit-tree` 不运行 Git 提交钩子，`update-ref` 不写 HEAD reflog。
- `-h` / `--help`：打印用法。

### 合同行格式

行式提交合同文件（均以行首列为准）：

| 行格式 | 说明 |
| --- | --- |
| `lane: user-review` 或 `lane: micro` | 必需，恰一行；取值仅 `user-review` 或 `micro`。micro 道预检两断言：白名单 ≤3 条目、改动集零新建（??）零删除（D）——违者 exit 1；user-review 道不受限。 |
| `ticket: <仓库根相对路径>` | user-review 道必填（票文件须存在）；micro 道不得出现。票体 `.md` 或 `.json`——Checkpoint 承载形态随票体分派（`.md` 票追加票尾；`.json` 票落独立 `facts/requirements/tickets/<id>-review-checkpoint.md`，票体零追加）。 |
| `whitelist: <逗号分隔相对路径>` | 必填，一行可多项；口径同 check-gates.sh（须为仓库根相对文件路径）。 |
| `message: <产品提交说明>` | 必填，恰一行。 |
| `verify: <验证命令>` | 一行一条，可多行；交由 check-gates.sh 重跑并记录退出码。普通快道至少一条真实命令；纯记录例外须唯一 `verify: N/A`。 |
| `record-only: <纯记录理由>` | 可选，显式纯记录例外；仅与 `verify: N/A` 配套。 |
| `verdict_quote: <用户裁决原文>` | user-review 道必填；micro 道不得出现。 |
| `verdict_at: <裁决时间>` | user-review 道必填；micro 道不得出现。 |
| `actual: <净工时>` | micro 道可选（至多一行）：本次微收口净工时文本（净工时口径：会话段累计减中断段），落微账本 `actual` 键；缺省空串——既有六键行向后兼容（合同不带 `actual:` 行照旧落行，actual 记空串）；user-review 道不得出现（其实际用时落票本体 `actual_time` 字段，ticket-ops flip 收口硬拦）。 |
| `flips: <file>:<field>:<value>` | 行翻转：一行一条，可多行；`field` 不得为 `status`（已退役）或 `index`（索引专用段名）。 |
| `flips: facts/requirements/tickets/index.json:index:<id>:<status>:<updated_at>` | 索引条目翻转：user-review 道专用，至多一条；`id` 须与 `ticket` 票文件名去 `.md`/`.json` 后缀一致；`status` 为状态机裸值（ready / in_progress / blocked / review_ready / review_pass / review_fail / done / superseded，不带冒号后缀）；`updated_at` 形如 `YYYY-MM-DDTHH:MM[:SS]`（允许冒号，取行尾余段）。 |
| `# 注释` / 空行 | 行首 `#` 与空行忽略；无法识别的行、重复行判合同格式错误（exit 1）。 |

flips 语义（单写机制）：

- 索引条目翻转（单写机制；写入方收敛后经 ticket-ops 代理）：调用同目录 `ticket-ops.sh` `flip-index --id <id> --status <status> --updated-at <updated_at>` 承载索引单写——`"id": "<id>"` 锚点整行替换，仅改该行 `status` 与 `updated_at` 两值，`complexity`/`blocked_by`/`checkpoint_ref` 等其余字段原样保留；依赖一条目一行排版，条目行不含同行 `status`/`updated_at` 字段或锚点命中数 ≠1 即预检停止；投影再生＋`--check` 收尾链由代理一并执行（全仓仅 ticket-ops 一处）。代理返回后本脚本机械回写 `ticket` 票正文 `**Status:**` 行为反引号包裹的 `status`（投影打印件，过渡期口径；正文 Status 行须恰命中一行；`.json` 票体无 `**Status:**` 行，跳过回写并打印说明行，状态唯一真相源＝索引）。票务代理定位：本脚本同目录优先，PATH 回退（手动迭代 PATH 逐目录探测可读的 `ticket-ops.sh`；不用 `command -v`——落位脚本不要求可执行位、恒经 sh 调用，`command -v` 对不可执行文件不报告，措辞对齐实现 lane-commit.sh 代理定位段）；索引或票务代理缺失属预检条件，先于产品提交停止。索引预检（排版与锚点唯一性）仍由本脚本在预检阶段先行核对（fail-closed 时序前移），代理内的同款校验为写入时点复核。
- 行翻转：锚点为字面子串，须恰命中一行，整行换成 `value`；通用 flips 不得以 `facts/requirements/tickets/index.json` 或其 realpath 同一文件为目标（含仓内父目录 symlink 别名），命中即预检 exit 1、零提交零写入，索引翻转仅经专用 `index` 段委托 `ticket-ops.sh flip-index`。
- `field: status` 已退役（frontmatter status 退役、票状态经索引单写机制承载）：合同携带即停止并指路索引条目口径。锚点不合规在写入前停止（exit 1）。

### 两段式提交与输出格式

执行顺序（每步失败即停止；第 4 步前的停止零提交零写入，第 4 步后的停止保留产品提交并输出指路）：

1. 合同解析与语义校验（车道组合、必填行缺失、禁止组合、索引翻转车道/id/取值校验；先于任何写入）；micro 道预检两断言（白名单条目 ≤3——超出属非微任务改走 user-review 道；`git status` 改动集零新建（??）零删除（D）——微道只修不建不删；任一违者 exit 1，停止时零提交零写入；user-review 道行为零变化）。
2. 翻转目标与预检（只扫描不写入）：翻转目标存在性、索引一条目一行排版与 id 锚点唯一命中、正文 Status 行唯一命中、行翻转锚点唯一命中、写入代理可用性（`ticket-ops.sh`、`checkpoint-write.sh`、`ledger-append.sh`：均同目录 → PATH）；全部通过才继续。
3. 门禁核对（内部调用同目录 check-gates.sh：白名单比对＋验证前后工作区快照，verify 越界写工作区同样失败）；任一不符 exit 1。
4. 产品提交：按白名单逐项 `git add`，防御性核对暂存内容不越出白名单，按合同 `message` 创建提交。
5. 记录写入：索引翻转（经 `ticket-ops.sh` `flip-index` 代理——索引单写＋投影再生＋`--check` 由代理承载）→ 票正文 Status 投影打印件回写（`.json` 票跳过并打印说明行）→ 行翻转 → user-review 道经 `checkpoint-write.sh review-checkpoint` 落 User Review Checkpoint（裁决原文、裁决时间、产品提交 ID 与说明、diff 摘要；`.md` 票追加票尾，`.json` 票落独立 `facts/requirements/tickets/<id>-review-checkpoint.md`——不存在则创建带一级标题、已存在则追加记录块，票体零追加；代理 stdout 末行目标文件契约行登记进记录提交）/ micro 道经 `ledger-append.sh --micro` 向 `facts/project/micro.jsonl` 落一行 JSON。
6. 记录提交（单点入口）：索引、票文件、投影、微账本等记录内容统一经记录提交单点入口入第二段提交（`chore(lane): 记录翻转 — <message>`）——持与 `ticket-ops.sh`／`ledger-append.sh` 同一把记录层写锁、在私有索引上只暂存记录路径、拒绝部分暂存、断言 HEAD 只追加账本内容为待提交版本（私有索引 blob）的字节前缀（不成立零提交并报首个违规行号）、对私有索引写出的树断言文件集恰为记录路径，最后 `write-tree`／`commit-tree`／`update-ref` CAS 提交；未改动记录路径显式列为已排除，并发暂存不卷入且保留现场。

```text
lane-commit: 票务代理定位: 同目录 <路径>|PATH <路径>
lane-commit: 索引翻转已代理: facts/requirements/tickets/index.json（<id> → <status>，updated_at <时间>；索引单写＋投影再生 --check 经 ticket-ops flip-index 承载）
lane-commit: 正文 Status 回写（投影打印件）: <ticket> → **Status:** `<status>`
lane-commit: 跳过正文 Status 回写: <ticket>（.json 票体无 **Status:** 行，状态唯一真相源＝索引）
lane-commit: 翻转: <file>:<field>:<value>
lane-commit: 记录写入代理定位: <checkpoint-write.sh|ledger-append.sh 路径>
checkpoint-write: User Review Checkpoint 已追加: <ticket>
checkpoint-write: User Review Checkpoint 已追加: facts/requirements/tickets/<id>-review-checkpoint.md（.json 票体零追加，独立 checkpoint md 承载）
checkpoint-write: 目标文件: <记录块承载文件>
ledger-append: 微账本落行: facts/project/micro.jsonl（第 N 行）
lane-commit: 记录提交门: 同锁串行（锁目录 <路径>）
lane-commit: 产品提交 <提交 ID>
lane-commit: 产品文件: <逗号分隔清单>
lane-commit: 记录提交 <提交 ID>
lane-commit: 记录文件: <逗号分隔清单>
lane-commit: PASS（两段式完成：门禁 PASS、索引单写 N 处、翻转 N 项、投影已核对、记录已落盘）
```

- 各行为行仅在实际发生时输出（「索引翻转已代理」「正文 Status 回写」随索引条目翻转——投影再生与核对由 ticket-ops flip-index 代理内承载——`.json` 票体以「跳过正文 Status 回写」替代回写行；「checkpoint-write: User Review Checkpoint 已追加」「checkpoint-write: 目标文件」仅 user-review 道，`.json` 票目标为独立 checkpoint md；「ledger-append: 微账本落行」仅 micro 道）；失败输出 `lane-commit: FAIL: <原因>`（stderr），逐步骤停止原因与指路可定位。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 两段式全部完成（门禁 PASS、产品提交、记录写入、投影核对、记录提交）。 |
| 1 | 门禁不过或合同 fail-closed 条件（合同格式错误、车道必填缺失或禁止组合、白名单越界、verify 失败、索引缺失或排版不合预期、正文 Status 行锚点不合规、翻转锚点不合规、写入代理不可用（ticket-ops.sh／checkpoint-write.sh／ledger-append.sh）、索引翻转代理（flip-index）或投影再生/`--check` 未过、checkpoint-write 或 ledger-append 代理未过、暂存越出白名单、白名单内无实际改动、微道预检不过（白名单 >3 条目或改动集含 ??/D）、记录提交前缀门不过（账本中间插入/改写/截断）、部分暂存、记录路径不在 `facts/` 记录面内、记录路径在工作树不存在、记录路径越界（含 `..`）、待提交树含记录面外文件、记录路径均无实际改动等）；预检与门禁阶段的停止零提交零写入，记录写入阶段的停止保留产品提交并输出指路；记录提交门自身失败的停止零提交（已暂存内容按现场保留、不回滚）。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库、合同文件不可读、同目录 check-gates.sh 缺失等）。 |

### 微账本与维护联动

- 记录写入面（职责拆分后）：user-review 道 User Review Checkpoint 由 `checkpoint-write.sh` 独占写，微账本 `facts/project/micro.jsonl`（替代竖线格式 `micro.md`；无存量迁移负担）由 `ledger-append.sh --micro` 独占写——本脚本只做代理定位与记录提交面登记，零直接 checkpoint/账本写入。微账本懒创建（空文件起步，JSONL 不承载注释行），一行一操作，agent 不手写、其他流程不得代写。JSON 行字段与键序固定：`date`（`YYYY-MM-DD`）、`lane`（`micro`）、`whitelist`（逗号分隔白名单，JSON 转义 `"` 与 `\`）、`gates`（`PASS`）、`verify`（重跑验证命令条数）、`commit`（产品提交 ID）、`actual`（净工时文本——微道提交合同 `actual:` 行承载，JSON 转义同 whitelist，缺省空串；既有六键行向后兼容，合同不带 `actual:` 行即落空串）；每行均可被 `json.loads` 解析，禁裸换行。
- 白名单与 flips 目标均须为仓库根相对文件路径；索引条目翻转锚点依赖 `facts/requirements/tickets/index.json` 一条目一行排版与条目行内 `"status"`/`"updated_at"` 字段同行（排版破坏即预检停止），排版口径见 `../references/schemas/issue-index.schema.json`；正文 Status 回写锚点依赖票面 `**Status:**` 行格式（`.json` 票体不承载 Status 行，无此锚点依赖），格式变化须同步脚本锚点语义与本 README。
- 生成器 `generate-progress.sh` 与本脚本同目录落位（生成项目随道脚本由 SKILL 步骤 5 一并复制到 `rules/implementation/scripts/`；旧布局 `scripts/` 兼容副本保留、不自动迁移）；仅 PATH 回退形态运行时，投影再生依赖 PATH 上的同名脚本（再生调用点仍在 ticket-ops flip-index 代理内）。索引、票务代理或记录写入代理缺失的停止属 fail-closed（对齐 development-process R-DP-031 兜底），不存在"缺失就跳过继续"路径。
- 本脚本用法、合同行格式或退出码变化须同步脚本 usage 文本与本 README 专节；门禁清单格式口径以 check-gates.sh 专节为准。

## checkpoint-write.sh（User Review Checkpoint 写入方）

User Review Checkpoint 唯一写入方（自 lane-commit.sh 拆出的记录写职责）：道脚本 `lane-commit.sh` 在 user-review 道收尾时经同目录优先／PATH 回退定位本件并调用 `review-checkpoint` 子命令，本件按票体形态写入记录块——`.md` 票追加票尾；`.json` 票体零追加，落独立 `facts/requirements/tickets/<id>-review-checkpoint.md`（`<id>`＝票文件去 `.md`/`.json` 后缀）。本件不触索引、账本、README 与投影，不反向调用任何道脚本。记录层写锁：参数与路径边界校验通过后、写入之前经共享库 `record_lock_ensure` 取锁——独立调用自取并在退出时按所有权释放，`RECORD_LOCK_INHERITED=1`＋锁目录＋令牌在场时继承父进程锁且不释放父锁；每个写入点前经 `record_lock_assert` 核对令牌归属，被夺即 exit 1 零写入。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖、fail-closed（参数语义不合、票文件不存在或路径越界即停止，停止时零写入）。

### 用法

```text
sh scripts/checkpoint-write.sh [repo-root] review-checkpoint \
  --ticket <票文件> --verdict-quote <裁决原文> --verdict-at <裁决时间> \
  --commit <提交 ID> --commit-subject <提交标题> --diff-summary <diff 摘要> [--date <YYYY-MM-DD>]
```

- `repo-root`：仓库根目录；缺省取当前目录所在 Git 仓库顶层。
- `review-checkpoint`：本件唯一子命令；其他子命令 exit 2（不静默按默认处理）。

### 输入契约

| 参数 | 必填 | 语义 |
| --- | --- | --- |
| `--ticket <path>` | 是 | 仓库根相对票文件（`.md` 或 `.json`），须为仓库根内既存普通文件；含 `..`/`./` 路径段或绝对路径即 exit 1（写入前拒绝）。`.json` 判据＝文件名后缀去 `.json` 得 `<id>`。 |
| `--verdict-quote <text>` | 是 | 用户裁决原文，落记录块「裁决原文」行。 |
| `--verdict-at <time>` | 是 | 裁决时间，落记录块「裁决时间」行。 |
| `--commit <id>` | 是 | 产品提交 ID，落「提交」行（与 subject 同行）。 |
| `--commit-subject <text>` | 是 | 产品提交标题，与 ID 同行。 |
| `--diff-summary <text>` | 是 | 产品提交 diff 摘要，落「diff 摘要」行。 |
| `--date <YYYY-MM-DD>` | 否 | 记录块日期标题；缺省当日；非该口径 exit 1。 |

### 输出契约

- `.md` 票：记录块追加票尾，原内容逐字节保留为前缀；`.json` 票：票体逐字节零追加，独立 checkpoint md 不存在则创建（一级标题 `# 票 <id> User Review Checkpoint（用户即 Review 道）`＋记录块），已存在则追加记录块（一级标题唯一）。
- 记录块格式（与拆出前 `lane-commit.sh` 逐字节一致，两种票体同格式）：`## User Review Checkpoint（<date>，lane-commit.sh）` 标题＋「裁决原文」「裁决时间」「提交」「diff 摘要」四行。
- stdout 逐行人读进度，**末行固定为机器契约行** `checkpoint-write: 目标文件: <仓库根相对路径>`——即本次实际写入的记录块承载文件；`lane-commit.sh` 解析该行登记记录提交面（缺行即视为契约破坏并停止记录提交）。
- 路径边界：`--ticket` 与 `.json` 目标 md 均在仓库根内；除文本路径与末段 symlink 检查外，写前以 realpath 分别解析仓根和目标父目录，父目录 symlink 逃逸即 exit 1、仓外零写入；`.json` 目标 md 已存在且为 symlink 时同样 exit 1。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 记录块写入完成（目标文件契约行已输出）。 |
| 1 | fail-closed（票文件不存在、路径越界、日期越界、写入失败；停止时零写入）。 |
| 2 | 用法或环境错误（缺必填参数、未知参数或子命令、未知多余参数、仓库根不可用）。 |

### 维护联动

- 记录块格式或参数面变化须同步本专节、脚本 `-h` 用法与 harness `checkpoint-write` 套件（正负例随动）；`lane-commit.sh` 的目标文件契约行解析依赖 stdout 末行形态，变更须同步其代理调用段与 `lane-commit` 套件。
- 记录层写锁接线（取锁时点、所有权语义、继承标记）变化须同步本专节、脚本头部注记与 harness `checkpoint-write` 套件的并发／继承断言。
- 仓侧镜像落位 `rules/implementation/scripts/checkpoint-write.sh`（`agent-up/scripts/` 为基准，cmp 零差异）；安装闭包随 fast-lane 门控登记（见 `install-policy.rules`）。

## generate-progress.sh（现役状态投影生成器）

索引派生的双投影生成器（生成规则草案 §5.1.4）：自 `facts/requirements/tickets/index.json`（票状态机器真相源，单文件一条目一行）生成两处 Derived 投影，生成器独占写、agent 不手写，冲突时以索引为准。①`facts/requirements/tickets/progress-current.md` 现役状态投影——四标注头部（generated_from、生成时间、覆盖范围、失效条件）＋每票一行 `| id | status | checkpoint_ref | updated_at |` 状态表，按 id 升序。②`facts/requirements/tickets/README.md` 的票表生成块——`<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->` 与 `<!-- /tickets-readme -->` 之间的整表：行集合与顺序取索引，状态列取索引，名字／开票日期／功能列复用现行块行原文，索引新增条目按票本体 title／created_at 派生，表头与分隔行复用现行行；块外逐字节不动。无票表生成块亦无目录清单表的 README 不新建不改写（显式 SKIP）。POSIX sh（`#!/bin/sh`、`set -eu`）、条目字段解析经同目录唯一 JSON 引擎 `json-validator.py`（无 jq；缺件 fail-closed 指名）、fail-closed——索引缺失、不可读或条目行不合预期即停止报告，不写投影。包内版本与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致（入包核对）；再生调用单点＝`ticket-ops.sh`（open/take/flip/flip-index 收尾链与快道索引翻转代理；`lane-commit.sh` 经 `flip-index` 代理触达，零直接调用；`check-stale-claims.sh` 仅调用两类只读核对，非写链），生成项目由 SKILL 步骤 5 随道脚本一并复制落位 `rules/implementation/scripts/`（旧布局 `scripts/` 兼容副本保留，不自动迁移）。

### 用法

```text
sh scripts/generate-progress.sh [--check|--check-readme] [repo-root]
```

- 无参数：repo-root 缺省按脚本落位推导——包内 `agent-up/scripts/` 落位与仓内镜像 `rules/implementation/scripts/` 落位均自动解析为仓库根；其他落位（含旧布局 `scripts/`）缺省推导不保证命中仓库根，推不到索引即 fail-closed（exit 2）并提示显式传入 repo-root。
- 带参数：以第一参数为仓库根（对临时目录副本或非默认落位复跑时使用）。
- `--check`：progress-current.md 的 dry-run 一致性核对——生成结果与既有投影各自规范化 `generated_at` 行（该行随生成时间漂移，不参与判定）后逐字节比对，一致 exit 0，不一致 exit 1，不写任何文件。
- `--check-readme`：README 票表生成块的 dry-run 新鲜度核对——索引派生结果与现行块逐行比对；漂移或块缺失但目录清单表在场（未迁移）exit 1 并报 `path:line` 与差异行；README 缺失或既无块亦无表 exit 0（跳过）。
- 两核对模式互斥；无参数即写模式（同时再生两处投影，随后回读核对）。
- `-h` / `--help`：打印用法。

### 输出格式

```text
generate-progress: OK: 已生成 <投影路径>
generate-progress: CHECK: PASS — 投影与索引一致: <投影路径>       # --check 一致
generate-progress: CHECK: PASS — 票表生成块与索引派生一致: facts/requirements/tickets/README.md
                                                        # --check-readme 一致
generate-progress: OK: 已生成票表生成块（索引派生，块外逐字节不动）: facts/requirements/tickets/README.md
generate-progress: SKIP: facts/requirements/tickets/README.md: 无票表生成块亦无目录清单表——不新建
generate-progress: FAIL: 投影与索引不一致（stale）: <投影路径>    # --check 不一致，附 diff
<票表路径>:<行号>: 票表生成块与索引派生不一致（stale）——运行生成器刷新；差异: <diff 首行>
<票表路径>:1: 未迁移为生成块: 目录清单表在场但无票表生成块标记——运行生成器（无参数）迁移并刷新
generate-progress: FAIL: <原因>                                   # fail-closed 停止（stderr）
```

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 生成成功，或 `--check` 一致。 |
| 1 | `--check` 不一致（投影 stale）或既有投影缺失；`--check-readme` 生成块漂移或未迁移。 |
| 2 | 用法错误、索引文件缺失/不可读或条目行不合预期（一条目一行排版破坏、条目缺必备字段；fail-closed，不写投影）。 |

### 维护联动

- 生成规则、投影格式或票表生成块标记／派生规则变化须同步重跑生成器刷新两处投影，并登记 `facts/project/artifacts.yaml` 对应条目；条目行锚点为 `"id": "<数字开头 id>"`，索引排版变化须同步本脚本、`lane-commit.sh` 索引单写锚点与 check-stale-claims.sh S3 比对三处；票表生成块标记变化另须同步本专节、`ticket-ops.sh` 同锁窗口核对调用面、`references/templates/issues-README.md.tmpl` 骨架与本目录套件表。
- 包内版本与本仓根 `scripts/` 基线互为镜像：任一侧变化须同步另一侧并 cmp 核对或登记差异。

## generate-module-map.sh（模块地图生成器）

模块地图生成器（调研拍板：落点＝方案 A agent-up 公开包脚本、查询形态＝JSON 直读唯一查询面（`--affected` 不采纳）、更新时机＝双通道；扩 Rust 为四语言、引擎表驱动化、七语言批量扩展（十一语言）迭代）：从仓库源码文件的静态导入语句提取文件/模块级依赖边，生成 `<root>/facts/project/architecture/module-map.json`——Derived 四标注头部（`generated_from`/`generated_at`/`coverage`/`invalidation`，R-DP-004）＋`workspace_fingerprint`（fp-v1，R-DP-015 算法；指纹输入排除本图自身，避免自引用漂移）＋`nodes`（已扫描源码文件，仓库根相对路径）＋`edges`（`from`=仓库根相对路径、`to`=导入语句文本中的模块引用原串（未做路径解析）、`label`=导入语句类别）。此后引擎为通用规则解释器（加载规则表→按扩展名发现源码→逐行匹配捕获→按策略产边→direct-file 候选边存在性过滤→组装 JSON），语言知识外置于同目录 `module-map.rules`（每语言一行，引擎零语言专名；加语言＝加规则行＋fixture、零引擎改动）；规则表随脚本同目录落位（新布局 `rules/implementation/scripts/` 下两件同迁）。本图是项目地图条件产物的承载视图（development-process §5.2 触发矩阵行"项目地图"），只当检索索引不当 Scope 权威，不作为白名单或 watch 依据；Derived 自动生成，agent 不手写。输出为 `python3` `json.loads` 可解析的机器可读 JSON（R-GF-005）。

### 用法

```text
sh scripts/generate-module-map.sh [repo-root]
```

- 无参数：repo-root 缺省取当前目录所在 Git 仓库顶层（check-gates.sh :20 先例）。
- 带参数：以第一参数为仓库根（对临时 fixture 仓或非默认落位复跑时使用）。
- `-h` / `--help`：打印用法。
- 输出落 `<root>/facts/project/architecture/module-map.json`（目录缺失时随生成懒创建）；生成动作对仓库零额外写入（临时文件全部落 TMPDIR）。

### 语言规则表（module-map.rules，十一语言）

语言知识唯一承载点＝同目录 `module-map.rules`：每语言一行 `mm_rule <lang> <exts> <pre_ops> <rules> <coverage> <limits>`，`<rules>` 内为 `@` 连接的提取规则列表（`capture` 段捕获／`scan` 行变换两类，字段以 `~` 连接；op 形态 `s=<ERE>`／`g=<ERE>=<替换>`／`Q`，列表以 `&&` 连接），加载时结构校验（字段数、op 编码、selector/strategy 枚举、扩展名形态与跨行重复）不合预期即 exit 2。路径策略枚举（表驱动化定稿，按既有四语言实际归纳）：`extension-map`（语言绑定，由 `<exts>` 承载）、`unresolved-node`（未解析节点引用直出）、`module-path`（模块路径文本直出）、`direct-file`（声明文件候选边＋存在性过滤）；后两类直出策略共用 verbatim 产出行为、以引用语义区分（影响后续路径解析扩展的归类）。下表为十一语言现行规则行的人读摘要（权威以规则表为准；追加 Go/Java/C#/Ruby/PHP/Swift/Kotlin 七语言，覆盖语言总数 11）：

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

覆盖声明（R-CC-004，保守措辞）：提取规则为语句文本层——不做别名/tsconfig paths 等路径映射解析，不覆盖动态导入、re-export、符号级调用图与构建期代码生成边；注释内的导入文本与字符串字面量构成已知误报源（输出层不做语义过滤）。上表规则经 fixture 最小验证（mktemp 临时仓：四语言正例＋空格/中文路径＋尖括号系统头/内联 mod 块/不存在 mod 负例＋fp-v1 复算比对；Rust 扩展后新旧脚本对同一三语言夹具边集 diff 零变化；表驱动化迁移后新旧引擎对四语言 fixture 边集逐边相等——13/17/7/20 条，nodes 与退出码亦一致——且哑语言规则行零引擎改动产边实证成立；七语言追加后四语言边集回归零变化＋七语言 fixture 边集逐一相等——go 5/java 4/csharp 4/ruby 4/php 4/swift 4/kotlin 4 条，各含去重与注释/字符串内导入负例），未实测项按一般工程知识声明。七语言未覆盖口径逐语言一行：Go——build tag 条件文件不做判别，行首引号形态为文本层近似（raw string 续行等 import 块外行首字符串行可能误报，Go 关键字行已按组屏蔽）；Java——module-info.java 的 requires 句未覆盖，static import 末段可能为成员名（文本层不区分类型与成员）；C#——using 别名未覆盖，using 声明/语句经校验拒绝不产边；Ruby——require_relative 相对路径未按声明文件位置解析（原串直出），动态插值路径、__END__ 数据段、begin/end 块注释、heredoc 内文本与 load 语句未覆盖；PHP——group use 花括号分组与前导反斜杠根相对形态未覆盖，类内 trait use 文本层无法区分可能误报，require/include 表达式拼接不解析（字面量前缀按原串产边，变量形态不产边）；Swift——条件编译块不做判别，testable/exported 属性符号以标点类近似；Kotlin——反引号引用标识符段未覆盖。

### 更新时机（双通道）

1. 登记驱动：目标项目将本图按 development-process §5.3 登记 `facts/project/artifacts.yaml`（lifecycle: Derived，generated_from 必填），`sync_on` 对齐拓扑变化行（文件新增/删除/移动/重命名即重新生成）；登记动作归目标项目 init/补缺流程（见 `../references/old-project.md` §3 项目地图行）。
2. 指纹比对：生成时将 fp-v1 工作区指纹内嵌 `workspace_fingerprint`，使用时按 R-DP-015 算法重算比对，不一致即按 R-DP-009 判 stale，不得当可信导航。已知局限（保守方向安全，设计声明④）：fp-v1 为全工作区粒度，文档改动也判过期；精确化归后续演进。

### 依赖声明（零外部依赖的边界）

POSIX sh 主体（`#!/bin/sh`、`set -eu`、`set -f`）仅用 POSIX 标准工具（find/sed/awk/sort/grep/cut/wc/date/dirname/mktemp/git 只读子命令）；两项平台标配补充，缺失即 fail-closed（exit 2）：`stat`（BSD/GNU 双方言自动探测，取文件字节与 mtime 纪元秒）与系统 SHA-256 工具（`sha256sum`/`shasum -a 256`/`cksum -a sha256`/`openssl dgst -sha256` 按序探测）。语言规则表 `module-map.rules` 与脚本同目录加载：缺失、未登记任何语言行或结构校验不过即 exit 2（fail-closed，不写地图）。

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

- 语言规则表行增删或匹配规则变化＝编辑 `module-map.rules`＋fixture 回归（加语言零引擎改动，AC3 口径）；引擎不得引入语言专名（语言知识唯一承载点＝规则表，AC 硬门禁）；规则表编码（`@`/`~`/`&&`/`=` 分隔与 op 形态）或加载校验口径变化须同步引擎解析器与本专节。fixture 为临时件不入仓；六票 fixture 已沉淀为 `test-record-layer.sh` 的 module-map 套件（见下文专节），规则表或引擎行为变化时以 `sh scripts/test-record-layer.sh --suite module-map` 回归（跑法与历史结果另见历次 run record `last_verified`）。
- 生成项目补缺落位与登记口径见 `../references/old-project.md` §3 项目地图行；本图不预建实例（触发矩阵行命中才创建，R-DP-006）。
- 排版与转义惯例与 `generate-progress.sh` 同源（`set -f`、TMPDIR mktemp＋trap 清理、LC_ALL=C 排序）；两脚本不共享代码，语义变化互不联动。

## generate-dir-readmes.sh（目录 README 校验／同步／骨架生成、迁移预演与素材包）

目录 README 四段式契约的机器判定面（契约骨架＝`../references/templates/dir-README.md.tmpl`）：校验既有 `README.md` 的确定形态，不判断内容语义，也不生成成员清单；`--sync` 只重建生成块内的可派生子目录表，块外逐字节不动；`--freshness` 在内存重算 `--sync` 应产出的生成块并逐行比对，供收口门禁做只读漂移断言；`--init` 为新目录产出可用骨架；`--migrate-dry-run` 为旧格式迁移做只读预演，只输出建议 diff、丢弃行范围与占位提示，不写文件；`--brief` 为单目录产出判断段所需的只读素材包，不写文件。

### 用法

```text
sh scripts/generate-dir-readmes.sh [--target <repo-root>] [--dir <rel>] [--rules <path>]
                                   [--check [--blocks-only] | --sync | --freshness
                                    | --init <rel> | --migrate-dry-run [--diff]
                                    | --brief <rel-dir>]
```

- `--target <repo-root>`：目标仓库根；缺省当前目录。
- `--dir <rel>`：只处理该目录（目标根相对路径）的 `README.md`；目录不存在或目录内无 README → exit 2；`--init` 时不可用。
- `--rules <path>`：范围规则文件；缺省脚本同目录 `dir-readme.rules`，消费者仓库可自定纳入与排除面。
- `--check`：结构校验，零写入，缺省行为。
- `--blocks-only`：仅与 `--check` 连用（缺省 check 模式下也可单独给出，等效 `--check --blocks-only`），只校验含生成块的 README（无生成块的旧格式跳过，不阻断收口）；与 `--sync`／`--freshness`／`--init`／`--migrate-dry-run`／`--brief` 同用即 exit 2。
- `--freshness`：生成块新鲜度只读断言，零写入。复用 `--sync` 的生成函数在内存重算每个生成块（含表头、行序与占位文案），与现行块逐行比对：漂移即 exit 1，逐条输出 `path:line: 缺失行: <原文>`／`path:line: 多余行: <原文>`（行号指向现行块内位置，缺失行给期望行号），末行 `SUMMARY: 生成块漂移 N 件（缺失 X 行／多余 Y 行）`；无生成块的 README 静默跳过；块未闭合、重复起始或 `dir` 值不符 exit 2；干净时 exit 0 且零输出。它独立于 `--sync` 写路径，是发现「新增子目录未入表／删除子目录未删行」的唯一只读断言（`--check` 只校验标记成对，不比对表内容）。
- `--sync`：重建既有生成块内的子目录表。块外逐字节不动；行集合＝该目录一级子目录（套用范围规则的 include／exclude，按名排序）；既有行「一句话」「禁忌」两格原文复用；新增行一句话取该子目录 `README.md` 的职责句、取不到写 `【填写：一句话职责】`，禁忌取不到写 —；首格的目标根相对路径中的 `|` 转义为 `\|`（读回时反转义，保证复跑稳定）；消失的子目录整行删除并逐行输出 `DEL`。无生成块的 `README.md` 不新建、不修改，逐文件输出 `SKIP: <path>: 无生成块`；围栏代码块（```` ``` ````／`~~~`）内的标记不算生成块。有任何文件生成块未闭合、重复起始或 `dir` 值不符时 exit 2，整批零写入。
- `--init <rel-dir>`：为 `<target>/<rel-dir>` 新建 `README.md` 四段骨架（H1、职责句、`## 权威`、`## 读取禁忌`、`## 子目录` 含生成块与自动子目录表），判断位留 `【填写：…】`；目录不存在或目标 `README.md` 已存在 exit 2 零写入；与 `--check`／`--sync`／`--freshness` 互斥。
- `--migrate-dry-run`：旧格式目录 README 向四段式迁移的只读预演，不写任何文件；纳入集合与 `--check` 相同（先过 `--check`，零问题即跳过），默认输出 ≤15 行摘要（`SUMMARY:` 形态计数／`ZERO-WRITE:` sha256 证据／分类 `NEEDS-CONFIRM:` 待确认清单），无迁移件零输出；`--diff` 连用才输出逐件统一 diff 与 `MIGRATE:`／`DROP:`／`NOTE:` 详情。详见下文「迁移预演」节。
- `--diff`：仅与 `--migrate-dry-run` 连用，输出逐件 `MIGRATE:`／`DROP:`／`NOTE:` 与统一 diff 详情；单独出现或与 `--check`／`--sync`／`--init` 同用即 exit 2（用法见 `--help`）。
- `--brief <rel-dir>`：只读输出该目录（目标根相对路径，须存在）的 agent 素材包，四节固定标题与降级语义见下文「素材包」节；与 `--check`／`--sync`／`--init`／`--migrate-dry-run` 互斥，不接受 `--dir`。
- 空白限制：`--init` 与 `--sync --dir` 的目录路径规范化后含空白字符（半角空格、全角空格、制表符等）即 exit 2 零写入。范围规则以空白切词、生成块标记以空白分隔取值，含空白的目录既无法进入范围也无法被标记唯一表示；`--init` 不产出自己读不回的骨架。

### 断言（七项）

1. 四段齐全：一句话职责、`## 权威`、`## 读取禁忌`、`## 子目录`（含 `| 子目录 | 一句话 | 禁忌 |` 三列表头，且表头下一行为 `| --- | --- | --- |` 分隔行；缺段报缺段，有表头无分隔行报「子目录表头缺少分隔行」）。
2. 总行数 ≤ 25。
3. 无成员表：`## 成员` 段，或表头单元格去空白／反引号／`**` 后整格等于「名字」「成员」「文件」之一、列数 ≥ 2 且下一行为分隔行的表格（正文提及与「检查项｜依据文件」这类普通两列表不算）。
4. 无计数与状态句：`共 N 件`／`N 个脚本`／中文数字个脚本／`当前没有`／`N 行`／合同件数（`三合同`、`3 份合同`）／`N 个成员`、`N 份文件`、`N 张票`（N 为阿拉伯数字或中文数字；`N 行`排除「一行」与「第 N 行」这类习惯用法；只查明显形态，不追求完备）。
5. 正文反引号包裹的路径存在，双口径：含 `/` 按目标根校验；不含 `/` 但形如文件名（`^[A-Za-z0-9._-]+\.(md|json|jsonl|sh|py|rules|yaml|yml|html|tmpl)$`）的按 README 所在目录校验；`N/A`（大小写不敏感，可带理由）与其余裸标识符（`--flag`、`true`）跳过。通配、绝对路径、URL 一律忽略。
6. 正文裸露的 `【填写：…】` 占位即 exit 2，逐行报「判断位未填（`【填写：…】` 占位）」；HTML 注释内、反引号代码段内（`…`）与围栏代码块内（```` ``` ````／`~~~`，含更长围栏）的占位不参与判定（`--init` 骨架的头注占位与文档里以行内代码引用的占位说明因此不报）。
7. 生成块 `<!-- dir-readme: generated dir=<rel> -->` 与 `<!-- /dir-readme -->` 成对且 `dir` 值与目录一致（只校验存在性，不比对内容）；围栏代码块内的成对标记不算生成块（`--check` 不判、`--sync` 不读不写）。

### 生成块与子目录表

- 生成块内整段重建为三列表；首格写目标根相对路径（如 `` `docs/sub/` ``），与第 5 条路径口径一致，保证 `--init` 骨架除占位外可通过全部断言。
- 子目录名含 `|` 时首格转义为 `\|`（表格语法要求），`--sync` 读回时按未转义文本匹配既有行，复跑零差异。
- 生成块标记以空白分隔取值（`dir=(\S+)`），故目录路径不得含空白：`--init` 与 `--sync --dir` 遇到含空白的路径 exit 2 零写入，不产出读不回的文件。
- 围栏代码块（```` ``` ````／`~~~`）是展示面，不是契约面：围栏内的成对标记与占位都不参与判定，`--sync` 不改写。
- 块内表外的其它块内文字会被 `--sync` 丢弃：可派生内容放块内，判断文字放块外。
- 模板 `../references/templates/dir-README.md.tmpl` 的子目录表已由生成块包住，新目录可用 `--init` 起骨架后手填判断位。

### 素材包（`--brief`）

为目录 README 的职责、权威、禁忌三节准备素材，只读零写入；输出四节固定标题，便于 agent 与套件按标题取段：

- `## BRIEF 目录清单`：目标目录一级成员（目录标 `README.md` 有无，文件给行数与字节数，符号链接不跟随），只列目标目录内路径。用于判断哪些是权威件。
- `## BRIEF 判断证据`：`facts/project/artifacts.yaml` 中该目录条目（`path` 归一后等于目标目录）与其内条目（一级成员与子目录内后代）的 `id`／`path`／`kind`／`authority`／`read_when` 原文，按「目录／成员／子目录内」分组；路径后括注省略、glob 归入所在目录；目录外条目一律过滤。注释要求结合本目录文件内容改写 authority、不得照抄，目录外指针原样保留。素材不做路径改写，也不输出屏蔽记号。
- `## BRIEF 现状`：`README.md` 是否存在、四段是否齐全、缺段、占位行，复用 `--check` 的逐条判定（不合规时逐条给 `path:line: 原因`）。
- `## BRIEF 生成约定`：四段写法、头注与判断位、禁止成员表／计数句／状态句、路径引用口径（含 `/` 按目标根、裸名按本目录；`--check` 只校验存在性与目标根越界）、25 行预算、判断不出写占位不编造。

降级：`artifacts.yaml` 缺失、不可读、非 UTF-8、缺 `artifacts:` 段、零条目或任一条目缺 `id`／`path` 时，只输出「目录清单＋生成约定」，第二行给 `DEGRADED: <原因>；本次仅输出目录清单与生成约定`，exit 0——不静默、不 exit 2、不部分采用条目（任意 `  - ` 行均为条目边界，缺 `id` 的条目不会被并入上一条）。

### 迁移预演（`--migrate-dry-run`）

旧格式目录 README（四列表成员清单、成员表、纯文字）向四段式契约迁移的只读预演：不写任何文件；默认输出 ≤15 行摘要（形态计数、零写入证据、分类待确认清单），`--diff` 连用才输出逐件详情（统一 diff、`DROP`／`NOTE`／`MIGRATE`），供人工裁剪后再落地。

- 纳入集合：范围内所有 `README.md`；先跑 `--check`，零问题即跳过（已合规目录不进入报告，故全合规时零输出 exit 0）。集合非空时，默认摘要以 `SUMMARY:` 开头，`--diff` 详情以 `MIGRATE: <path>: <形态>: <原行数>→<建议行数>` 开头。
- 形态判定（优先级自上而下）：`four-column`＝4 列且首格为文件类（`文件`／`文件名`／`文件／路径`）且紧随分隔行；`member-table`＝表头任一格去空白／反引号／`**` 后为「名字／成员／文件」且紧随分隔行；`no-table`＝既无四列表头也无成员类表头（含只有普通两列表的旧目录）。
- 建议内容（四段式）：H1 前的 HTML 注释块原样保留＋H1＋职责句（原文无职责句时插 `【填写：一句话职责】` 并出 `NOTE`）＋`## 权威`＋`## 读取禁忌`（只搬原 README 中各自匹配节内的列表项整行，逐字不改写；节标题去反引号、去括注后按名匹配，匹配不上即写占位）＋`## 子目录` 生成块与自动子目录表。
- 逐段 `DROP: <path>: <起>-<止> 行: <原因>`：成员表／四列表（表头至末行）、已搬空的匹配节标题行、未迁入的其它节（非权威／禁忌类）、非列表段落、H1 前的 YAML frontmatter 等元数据块，均登记行范围交人工处理。
- `NOTE: <path>: 原文缺「权威」列表项，建议内容留【填写：…】占位`（禁忌同理）；建议内容超 25 行另出 `NOTE: <path>: 建议内容 N 行，超过上限 25，需人工裁剪`——只报不截断，全文照出。
- `--diff` 详情形态：逐件 `MIGRATE:`／`DROP:`／`NOTE:` 与统一 diff，末行 `SUMMARY: 迁移 N 件（four-column a／member-table b／no-table c）；零写入 sha256 N/N 一致`。
- 默认摘要形态（≤15 行，全部为可 grep 的机器行）：`SUMMARY: 迁移 N 件（member-table a／four-column b／no-table c）`、`ZERO-WRITE: N/N sha256 一致`，以及按类别各一行 `NEEDS-CONFIRM:`——`K 件超 25 行（path N、…）`、`K 件缺职责句，建议留占位`、`K 件缺「权威」或「读取禁忌」列表项，建议留占位`、`M 段内容未迁入（DROP），需人工判是否升格`；某类为 0 时省略该行，集合为空时零输出 exit 0。
- 零写入：预演前后逐件 sha256 比对，任一不一致即 stderr 报「预演前后 sha256 不一致（只读被破坏）」exit 2。
- 失败语义：无 H1、表头缺分隔行等形态异常时，全量 `path:line: 原因` 写 stderr、stdout 为空、exit 2（不出半份报告）；`--migrate-dry-run` 与 `--check`／`--sync`／`--init` 互斥；`--diff` 只能与之连用，单独出现或与其它模式同用 exit 2 并说明用法。

### 输出与退出码

- `--check` 全部通过：exit 0，零输出（`--blocks-only` 时无生成块的 README 不参与）。
- 不合规或异常形态：exit 2，逐条输出 `path:line: 原因`（不聚合）；含无文件、无四段标记可判、规则文件缺失或损坏、目标路径不存在。
- `--freshness`：干净 exit 0 且零输出；漂移 exit 1，逐条 `path:line: 缺失行／多余行: <原文>` 与末行 `SUMMARY: 生成块漂移 N 件（缺失 X 行／多余 Y 行）`；块未闭合／重复起始／`dir` 值不符 exit 2。全程零写入，不调用 `--sync` 写路径。
- `--sync`：逐文件输出 `SYNC: <path>: 生成块已重建（新增 N／删除 M）`、`OK: <path>: 生成块无变化` 或 `SKIP: <path>: 无生成块`；删除行逐行输出 `DEL: <path>: <子目录>: <原一句话>`。
- `--init`：成功输出 `INIT: <rel>/README.md`。
- `--migrate-dry-run`：默认 stdout 仅摘要机器行（`SUMMARY:`／`ZERO-WRITE:`／`NEEDS-CONFIRM:`，≤15 行），集合为空时零输出；`--diff` 连用改为逐件统一 diff（`--- a/<path>`／`+++ b/<path>`）与 `MIGRATE:`／`DROP:`／`NOTE:`／`SUMMARY:` 行。合规件跳过；形态异常时 stderr 全量 `path:line: 原因`、stdout 空、exit 2；全程零写入。
- `--brief`：stdout 为四节固定标题的素材包，首行 `BRIEF: \`<rel>\`（只读素材包，零写入）`；判断证据给出 `id`／`path`／`kind`／`authority`／`read_when` 原文（目录外指针原样保留）；artifacts 降级时第二行 `DEGRADED: <原因>；本次仅输出目录清单与生成约定`，exit 0。目标目录不存在、缺 `--brief` 取值、与其它模式或 `--dir` 同用 → exit 2 且零输出；全程零写入。
- exit 1 保留（当前不产生）。

### 维护联动

- 四段式契约或断言口径变化＝同步 `../references/templates/dir-README.md.tmpl`、本专节与 `dir-readme.rules` 头部注释，并更新 `tests/suite-dir-readme.sh` 夹具。
- 生成块行格式或同步口径变化＝同步模板内说明、本专节「生成块与子目录表」与 `tests/suite-dir-readme.sh`。
- 生成块新鲜度口径（比对范围、`缺失行`／`多余行` 文案、行号口径、exit 1 语义）变化＝同步本专节、`--help` 与 ticket-ops／check-package 的调用面，并更新 `tests/suite-dir-readme.sh` 新鲜度断言；只读红线由套件「目录树 sha256 前后一致」守卫。
- 范围文法变化＝同步本专节与 `dir-readme.rules`；消费者仓库以 `--rules` 自定范围，不在包内追加项目专名。
- 迁移预演口径（形态判定、搬运范围、`DROP`／`NOTE` 文案、25 行上限、摘要／`--diff` 两种输出形态的机器行文案）变化＝同步本专节与 `tests/suite-dir-readme.sh` 迁移套件；只读红线由套件「预演零写入（目录树 sha256 前后一致）」与脚本内逐件 sha256 自证双守。
- 素材包口径（四节标题、分组、判断证据字段集、降级文案、目录外条目过滤、生成约定条目）变化＝同步本专节、模板 `../references/templates/dir-README.md.tmpl` 的「生成约定（--brief）」注释与 `tests/suite-dir-readme.sh` brief 断言。

## 记录层写锁（`ticket-ops.sh`、`ledger-append.sh`、`lane-commit.sh`、`checkpoint-write.sh` 与 `ticket-run.sh` 共用）

记录层写入互斥的唯一实现＝`common-helpers.sh` 的 `record_lock_*` 原语（各消费脚本零锁代码副本，机械断言「`record_lock_acquire() {` 恰一处＋ticket-ops／ledger-append 零锁实现字样」常驻 ticket-ops 套件）。锁的对象是记录层写入面（索引／issues-README／账本／投影／Review Checkpoint／票本体 checkpoint.commit），不是单文件。

取锁与释放经单一入口：`record_lock_ensure <仓库根>` 继承或自取——返回码只表达「锁已就绪」，所有权写回 `RECORD_LOCK_OWNED`（1＝本进程自取，退出前须经 `record_lock_release_owned` 释放；0＝继承，锁生命周期归父进程）；`record_lock_release_owned` 只在自取时删除锁目录，继承形态绝不释放父锁。

- 锁目录：`git -C <仓库根物理路径> rev-parse --git-common-dir` 归一后的 `<公共目录>/agent-up-record.lock`——主检与全部 worktree 争用同一把；非 Git 语境回退 `${TMPDIR:-/tmp}/agent-up-record-<仓库根物理路径 cksum>.lock`。锁目录落在 `.git` 内（或 `$TMPDIR`），不进版本控制跟踪面，持锁期间 `git status --short` 保持为空（白名单门禁不受污染）。
- 取锁：`mkdir` 原子语义（POSIX，macOS/BSD 无 flock 亦可用）；成功后写 `pid` 与 `token`（`pid:时间戳:随机代号`）。等待上限 `TICKET_OPS_LOCK_TIMEOUT`（缺省 20s），超时 exit 1 报「并发冲突」并附锁目录与持有者 pid，零写入。
- 陈旧锁：持有者 pid 确认不存在，或 pid 字段缺失且锁龄超过 `TICKET_OPS_LOCK_STALE`（缺省 600s）——默认只诊断、不自动夺（首轮一条诊断报文后继续等待），`--break-stale-lock`（两脚本皆有）或 `RECORD_LOCK_BREAK_STALE=1` 才显式夺锁；夺锁为 `mv` 到唯一旁路名认领，旁路令牌与观察值不符即放回（目标已被重建则丢弃旁路，绝不嵌套）。
- 令牌归属校验：每个写点前核对锁目录 `token` 仍为本进程令牌，被显式夺走即 exit 1「写锁归属已失效」并零写入；释放仅在令牌匹配时删除锁目录（绝不删他人锁），幂等。
- 嵌套继承：`ticket-ops.sh` 持锁调 `ledger-append.sh` 时传 `RECORD_LOCK_INHERITED=1` ＋锁目录＋令牌，子进程跳过取锁与释放（锁生命周期归父进程，释放经 `record_lock_release_owned` 按所有权判定）；标注继承但目录/令牌缺失即 exit 2 fail-closed，不在无锁状态写入。继承入口＝`ticket-ops.sh` 的 `record_lock_ensure`——父进程持锁调用其 `flip-index`（如 `ticket-run.sh` 记录收口段）时同样传三件，子进程接管同一把锁。
- `--check` 预检模式不取锁（只读零写入）；快道微账本 `lane-commit.sh` → `ledger-append.sh --micro` 按独立调用自取锁。
- 测试钩子：`RECORD_LOCK_TEST_HOLD_MS`（持锁后延迟返回的毫秒数，未设或 0＝零开销）放大「已持锁→下一写点」窗口，用于验证夺锁后原持有者被令牌拦下。
- 回归覆盖＝ticket-ops 套件的锁断言（陈旧锁默认只诊断与两条显式夺锁路径、有界等待超时且锁不被搬走、夺锁后令牌拦写、嵌套继承逐字节等价、主检与 worktree 同一锁目录且持锁零 git 污染、锁原语唯一实现与三镜像件 cmp）与 ledger-append 套件的并发断言（20 进程并行零丢行、并发追加后历史行逐字不变且 `check-append-only` 通过）及锁断言（独立调用遇存活持有者超时零写入、陈旧锁 pid 缺失且锁龄超阈值默认只诊断不夺）；checkpoint-write 套件的写锁接线断言（独立调用自取锁——`RECORD_LOCK_TEST_HOLD_MS` 放大持锁窗口，第二方 exit 1「并发冲突」且票体零写入；继承路径——父进程持锁调用 exit 0、子进程退出后锁目录仍在且令牌原样）与 ticket-run 套件的记录收口段锁窗口断言（flip-index 收到继承标记、checkpoint.commit 内联写入时同一锁目录同令牌、段末释放）。

记录层写面（索引／issues-README／账本／Review Checkpoint／票本体字段级改写）的唯一实现＝`record-store.sh`（记录层写面收敛票）：`record_path` 六类记录路径表即记录路径字面量的唯一承载点（`index`／`changes`／`micro`／`tickets-readme`／`ticket:<id>`／`checkpoint:<id>`），`record_write`／`record_append`／`record_set_json` 三写动词内部包办 `record_lock_ensure`（调用方已持锁则接管同一把、否则自取并在本次写入后按所有权释放）与写点前 `record_lock_assert`、realpath containment、同目录 mktemp＋mv 原子替换、追加字节前缀断言与经唯一 JSON 引擎的字段级改写。`ticket-ops.sh` 四个写点、`ledger-append.sh` 两账本行、`checkpoint-write.sh` 记录块与 `ticket-run.sh` 的 `checkpoint.commit` 全部经该 module 落地，各脚本零手写锁断言／mktemp＋mv 副本，六类记录路径字面量收敛到本表（派生投影 progress-current 与 flips 协议串属既有面，不在本表）；安装闭包随两门控同落位（`install-policy.rules`），仓侧镜像与包内件 cmp 零差（检查 13）。

## ticket-ops.sh（票务运维脚本）

协调层票务面写入单入口（行为基线＝development-process 模板 §12.5 票务脚本承载注记与 §6 零写入三段式第二段）：当前脚本写入新布局的 `facts/requirements/tickets/index.json`（全仓唯一写入方），并驱动两处派生投影——`progress-current.md` 与 `README.md` 的票表生成块（写索引→生成器再生→`--check`／`--check-readme` 收尾链仅本件一处；快道索引翻转经 `flip-index` 代理触达）；README 票表不再由本件手写，账本 `facts/project/changes.jsonl` 落行经同目录唯一写入方 `ledger-append.sh` 承载（本件零直接账本写面，写前预检经其 `--check` 零写入模式保持校验先于写入的 fail-closed 时序），投影由 `generate-progress.sh` 独占写。预检读取到投影收尾全程处于同一把记录层写锁内（读-改-写不丢更新；锁原语、陈旧锁处置与嵌套继承见上文「记录层写锁」节），四个写点前核对锁令牌归属（索引写点经 `record-store.sh` 的 `record_write` 落地——路径解析、锁断言与同目录 mktemp＋mv 零副本；README 票表生成块与投影由生成器独占写）。目录 README 收口门禁前移：`close` 与 `flip`／`flip-index` 至 `done` 在取锁与任何写入之前先跑两检——`generate-dir-readmes.sh --check --blocks-only`（只校验含生成块的 README，旧格式无块不阻断）与 `--freshness`（内存重算生成块逐行比对），任一失败 exit 1 指名 `path:line` 与断言、本次零写入；收口链不调用 `--sync`（`--sync` 是操作者显式修复动作，修复后由其提交）。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、无 jq（仅 POSIX 标准工具与内建；open 本体 schema 校验、take blocked_by 完整性预检与 flip actual_time 收口校验另用 python3 标准库）、fail-closed——校验先于写入，NN 段查重（同 NN 异 slug／畸形 id）、open 本体 schema 校验与定级/优先级理由非空断言、take 的 blocked_by 完整性门（task 票本体 blocked_by 逐项在册且 status=done，缺失或未完成 exit 1 指名 blocker id 与其状态；request 不校验）、flip 至 done 的 task 票 actual_time 收口硬拦（本体字段须已填且非空，缺项 exit 1 指名票 id 与缺项；非 done 翻转与 request 不校验）、索引一条目一行排版破坏、账本行不合键序或行型条件键缺失即停止不写；收尾生成器缺失或 `--check`／`--check-readme` 不过即整体失败，已写部分如实报告（票表生成块与索引在同一锁窗口内派生并核对，无「索引已改而 README 未重算」的中间态）。

### 用法

```text
sh rules/implementation/scripts/ticket-ops.sh [repo-root] <command> [options]
```

- 无参数：repo-root 缺省取脚本所在目录的上一级——旧布局 `scripts/` 落位时该缺省即仓库根；新布局 `rules/implementation/scripts/` 落位时缺省解析为 `rules/implementation/`、非仓库根，须显式传 repo-root（索引与账本均按 `<repo-root>/facts/…` 解析，解析不到即 fail-closed）。
- 带参数：以第一参数为 repo-root（对临时 fixture 仓或非默认落位复跑时使用）。
- `-h` / `--help`：打印用法。
- 四子命令选项：`open` 必选 `--id <NN-slug> --complexity <C0-C3> --title <text> --ledger-line <json>`（可选 `--blocked-by <id,id>`；新 task 票本体另须自带过 schema 的 `profile_reason` 七维 reason 对象——恰七键 D/B/I/U/S/M/O 逐键非空，存储合同见 `../references/schemas/ticket-record.schema.json` 属性与 `../references/protocol/complexity-profile.md` §2.2）；`take` 必选 `--id --status --ledger-line`（status 须为 in_progress；task 票另过 blocked_by 完整性门，见下文「状态跃迁门禁」）；`flip` 必选 `--id --status --ledger-line`（status 为状态机任意合法值；task 票 flip 至 done 另须票本体 actual_time 已填非空，非 done 翻转不要求）；`ledger` 必选 `--ledger-line <json>`（不得携带 --id/--status/--complexity/--title/--blocked-by）；`flip-index` 必选 `--id --status --updated-at`（status 为状态机裸值，updated_at 形如 `YYYY-MM-DDTHH:MM[:SS]`；不得携带 --ledger-line/--complexity/--title/--blocked-by——索引单写代理不落账本行）。
- 数据载体与退出码：索引 `facts/requirements/tickets/index.json`（票状态真相源，一条目一行）、`facts/requirements/tickets/README.md` 目录清单票表生成块（索引派生，生成器独占写，人工不编辑）、账本 `facts/project/changes.jsonl`（键序 date,kind,scope,decision,evidence_ref 五键必备＋按 kind 条件键：lesson 必带第六键 promoted_to（枚举 新票/rules/sop/validator/test/none）、replan 必带 replan_original/replan_replacement/replan_undone（布尔）；一行一事实，禁裸换行）；账本行行族形状校验与追加由唯一写入方 `ledger-append.sh` 承载（`--ledger-line` 口径与其行型合同一致）；退出码 0 全部完成、1 fail-closed（校验/锚点/收尾核对不过，已写部分如实报告）、2 用法或环境错误。
- 收尾投影再生：`open`/`take`/`flip`/`flip-index` 定位同目录 `generate-progress.sh`（PATH 回退），缺失即预检停止（fail-closed）——生成项目落位 `ticket-ops.sh` 时须一并落位生成器；`ledger` 无票面写入不触投影，不要求生成器在位。`flip-index` 为索引单写代理专用收口（快道索引翻转经此承载）：只触索引（锚点整行替换仅改 status/updated_at 两值）＋投影再生＋`--check`＋票表生成块重算＋`--check-readme`，不触账本/票本体（票表与投影均为索引派生面）。
- 账本写入单点：open/take/flip/ledger 的账本行形状校验与落行均由同目录唯一写入方 `ledger-append.sh` 承载（本件同目录优先、PATH 回退定位写入方；缺失即预检停止 fail-closed）——写前预检经其 `--check` 零写入模式先行（校验先于票务面任何写入），实际追加由其执行（懒创建仅限账本文件本体）；`ledger` 无票账本行入口（C0 修正类免建票收口承载）不依赖 `facts/requirements/tickets/index.json` 条目 id，不触索引、README、票文件与投影，故不做投影再生与 `--check`；形状不合即 exit 1 零写入。账本行行型合同（键集/键序/条件键）与退出码详见 `ledger-append.sh` 脚本头注与 `-h`。

### 票表生成块（派生）合同

`facts/requirements/tickets/README.md` 的目录清单票表是**索引派生生成块**，不是票务面手写投影（索引＝唯一状态真相源）：生成块标记 `<!-- tickets-readme: generated from=facts/requirements/tickets/index.json -->` 与 `<!-- /tickets-readme -->` 之间由 `generate-progress.sh` 整表重算，块外逐字节不动；本件不开票据行、不替换状态 token，仅在索引单写后调用生成器再生并以 `--check-readme` 在同一记录层锁窗口内核对。

- 派生规则：行集合与顺序取索引；状态列一律取索引；名字／开票日期／功能列复用现行块行原文；索引新增条目按票本体 `title`／`created_at` 派生（取不到写占位）；表头与分隔行复用现行行；不含「任务票 NN；」锚点的表行（如目录 README 自身登记行）按原文保留。
- 同步时机（索引写点 → 生成器）：`open`＝索引新增条目后再生；`take`／`flip`／`close`＝索引 id 锚点整行替换后再生；`flip-index`＝索引单写代理同样再生（快道翻转后 README 与投影一并更新，随记录提交收编）。两处派生投影与索引处于同一把记录层写锁内，无「索引已改而 README 未重算」的中间态。
- 人工编辑路径：关闭——手改块内行会被 `--check-readme` 判漂移（traceable 报 `path:line`），重跑生成器即按索引重算；缺失／重复／漂移行由重算自愈。块外正文仍可人工维护，不属派生面。
- 失败语义：生成器缺失或再生失败、`--check`／`--check-readme` 不过即整体失败并已写部分如实报告；生成块标记不成对／顺序颠倒 exit 2 fail-closed。回归覆盖＝test-record-layer ticket-ops 套件的生成块断言（重算后全文件逐一相等、块外文本逐字节不变、缺行／重复行／残留漂移行自愈、手工改状态 token 被 `--check-readme` 抓住）与 stale-claims 套件的 S4 正向／反向断言。

### 状态跃迁门禁

状态机跃迁的三道 fail-closed 预检（均在任何写入之前判定，四载体零变化；报文指名票 id 与违规项）：

- take 的 blocked_by 完整性门：领取 task 票时，票本体 `blocked_by` 数组逐项核对索引（状态真相源）——每个被依赖票 id 须在索引登记（存在性）且 `status=done`（完成性）。缺失（索引零命中）或未完成（status 非 done）即 exit 1，逐项指名 blocker id 与其索引状态，零写入；request 票无 `blocked_by`，不校验。正例＝blocker 全 done 后领取成功（索引单写 in_progress）；负例＝missing blocker 与未 done blocker 均拒绝且报文指名。门仅限 take——flip 不做 blocked_by 核对（对照正例：带未完成 blocker 的票 flip 照旧成功，零误伤）。
- flip 的 actual_time 收口硬拦（仅 done）：task 票 flip 至 `done` 时，票本体须含 `actual_time` 字段且非空（净工时口径），缺项或空白即 exit 1 指名票 id 与缺项，零写入；flip 至非 done 状态（ready/in_progress/blocked/review_ready/review_pass/review_fail/superseded）不要求 `actual_time`；request 票一律不校验（豁免不随目标状态变化）。
- 目录 README 收口两检（`close` 与 `flip`／`flip-index` 至 `done`）：预检在取锁与任何写入之前完成，生成器与 `dir-readme.rules` 由同目录或 PATH 定位（缺失即 fail-closed 指名）。①`--check --blocks-only`：只校验含生成块的 README，缺段／成员表／计数句等结构问题 exit 1 并逐条给 `path:line: 原因`，报文附 `--migrate-dry-run` 迁移预演指引；旧格式无生成块不阻断。②`--freshness`：内存重算应产出块并与现行块逐行比对，漂移 exit 1 报 `path:line: 缺失行／多余行`（覆盖新增／删除子目录未入表），报文提示先显式运行 `--sync` 重建并由操作者提交；块结构异常（未闭合／重复起始／`dir` 不符）exit 2。两检只读，任一失败即 exit 1、本次零写入，收口链自身不调用 `--sync`（不产生未提交的静默 README 改动）。
- 回归覆盖＝test-record-layer ticket-ops 套件的状态跃迁门禁断言（独立夹具：missing／未 done blocker 负例零写入指名、blocker 全 done 领取正例、flip 零误伤对照；非 done 翻转无 actual_time 正例、done 缺 actual_time 负例零写入、request 翻转豁免正例）与目录 README 收口断言（结构漂移阻断、新增子目录漂移阻断且 README 与四载体零改写、生成器缺失 fail-closed）。

### 落位口径（与道脚本的关键差异）

- 票务运维是记录层标配，非快道专属：目标项目采用新布局任务票体系时，安装到 `rules/implementation/scripts/`，逐件登记 `facts/project/artifacts.yaml` 条目（kind: script、lifecycle: Conditional、generated_from: agent-up/scripts/ticket-ops.sh）。既有 `docs/issues/`、`docs/changes.jsonl`、`docs/progress-current.md` 等旧路径是兼容/历史数据，本脚本不会读取或写入这些路径；启用本脚本前需确认新布局记录面已作为当前真相源，不能把两套路径混作同一状态源。未采用任务票体系不复制。
- 包内不运行：本包内 `agent-up/scripts/ticket-ops.sh` 是复制基线（生成源），缺省 repo-root 取所在目录的上一级；新布局安装位置为 `rules/implementation/scripts/`。兼容项目已有 `scripts/` 副本可保留，但它不会改变脚本使用 `facts/` 路径常量的行为。
- 包内文件是复制基线，安装后位于目标项目 `rules/implementation/scripts/ticket-ops.sh`；旧 `scripts/ticket-ops.sh` 副本作为兼容面保留，不因此改变脚本的数据路径常量。升级时由 `upgrade-check.sh` 对新旧落位分别与包基线 cmp。

### 与 lane-commit.sh 职责边界

`ticket-ops.sh` 只做票务面写入（open/take/flip/flip-index/ledger），不执行门禁核对与 Git 提交，不调用 `check-gates.sh` 与 `lane-commit.sh`（投影再生调用 `generate-progress.sh`、账本落行调用 `ledger-append.sh` 不在此限）；快道收尾（白名单核对、验证重跑、提交、记录翻转）仍归道脚本两件。非快道票（C1+ 全三阶段）的状态翻转由 `ticket-ops.sh` 承载——lane-commit 只覆盖快道，其索引条目翻转经 `flip-index` 代理复用同一单写机制（id 锚点整行替换，仅改 status/updated_at 两值）；index.json 全仓唯一写入方＝本件，lane-commit 零直接索引写入面。

## install.sh（安装脚本）

安装政策单源化的执行引擎（先例 `generate-module-map.sh` 表驱动化：外置数据＋引擎零专名＋结构校验 fail-closed）：按启用门控自查同目录 `install-policy.rules` 得复制集合（引擎零脚本名零门控专名，加门控＝加规则行零引擎改动），脚本件逐件 `cp` 自包 `scripts/` 至 `<target>/rules/implementation/scripts/`，数据件逐件 `cp` 自包内源路径至 `<target>/<行内落位路径>`（安装后运行时依赖闭包——schema/profile 等数据件随消费脚本同门控落位，消费脚本按自身落位形态邻接定位），并逐件 `cmp` 核验字节一致。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖（仅 POSIX 标准工具与内建，无 jq/python）、fail-closed：规则表缺失或结构校验不过 exit 2 不写任何文件；预检（源存在——脚本件与数据件同口径，删除任一已登记依赖即安装明确失败指名缺失路径、目标可写、同名件冲突）先于复制，停止零半套；包内误运行守卫（精确化：拦自写自毁三场景——目标含裸 `SKILL.md` 即包根本体、目标＝本脚本所在目录、目标落位目录＝本脚本所在目录（`cd -P` 物理解析，symlink 绕不过）；仓根含包副本但落位目的地与复制基线不同目录＝合法源仓落位，不拦）exit 1；已存在且字节一致的同名件幂等跳过，与基线不一致即停报告（reconcile 纪律：人工漂移不覆盖，检出即停报告而非覆盖）。脚本只承接已确认的复制动作——门控启用判定是用户决策（`../SKILL.md` 主流程步骤 5），不代做访谈；不代写目标治理文件（`facts/project/artifacts.yaml`、`scripts/README.md` 均归执行体）。包侧工具：只在包内语境运行，不落本仓 `scripts/` 镜像（out_of_scope 口径登记）。
旧项目已有 `<target>/scripts/` 副本属于兼容布局，安装器不搬迁、覆盖或删除。

### 用法

```text
sh agent-up/scripts/install.sh --target <dir> [--fast-lane] [--ticket-ops]
```

- `--target <dir>`：目标项目根目录（须已存在）；新布局落位 `<dir>/rules/implementation/scripts/`。
- `--fast-lane` / `--ticket-ops`：门控启用 flag（登记于 install-policy.rules 的 `ip_gate` 行；至少给出一个，零 flag 即用法错误）。
- `-h` / `--help`：打印用法。

### 安装政策数据格式（install-policy.rules）

- `ip_gate <gate> <flag> <说明>`：门控定义行（gate token、启用 flag、一句话说明）。
- `ip_file <pkg-rel-path> <lifecycle> <gate> <说明>`：每脚本件×每门控一行——包内复制基线路径（`agent-up/scripts/<文件名>`）、登记 lifecycle 值、所属门控、该门控下角色说明；同一文件属多个门控时逐门控各一行，引擎按文件路径去重选取。
- `ip_data <pkg-rel-path> <target-rel-path> <lifecycle> <gate> <说明>`：每数据件×每门控一行——安装后运行时依赖闭包的数据件承载行：包内源路径（`agent-up/` 前缀多段路径）、目标项目根相对落位路径（多段路径，禁侵入脚本落位目录）、登记 lifecycle 值、所属门控（随消费脚本同门控登记）、角色说明；引擎按源路径去重选取。
- 行首 `#` 与空行忽略；加载时结构校验（字段数、gate/flag/lifecycle/路径字符集与形态、flag 跨行唯一且不与引擎保留参数冲突、(文件/数据件,门控) 跨行唯一、同文件 lifecycle 一致、未定义门控引用、零文件门控、数据件落位路径跨行唯一且同件一致），任一不合预期即 exit 2（fail-closed，不写任何文件）。
- 本表、`install.sh` 引擎与本专节三处登记须同步；复制集合或门控构成变化＝编辑本表（零引擎改动）。

### 输出格式

```text
install: OK: <基线路径> -> <目标>/scripts/<文件>（lifecycle <值>；门控 <命中列表>；<角色说明>）
install: OK: <源路径> -> <目标>/<落位路径>（数据件，lifecycle <值>；门控 <命中列表>；<角色说明>）
install: SKIP: <文件>（目标已存在且与基线字节一致，幂等跳过）
install: NOTE: <目标>/scripts 为本脚本新建——需生成 scripts/README.md（README 生成不归本脚本）
install: NOTE: <目标>/<数据目录> 为本脚本新建（数据目录，无 README 生成义务）
install: 登记建议块（artifacts.yaml 十三字段建议值，可粘贴；写入归执行体，本脚本不代写目标治理文件）:
  {id: …, path: …, kind: script, …, generated_from: …, platform: neutral, update_policy: …}   # 每脚本件一行
install: 登记建议块（数据件，artifacts.yaml 十三字段建议值，可粘贴；写入归执行体，本脚本不代写目标治理文件）:
  {id: …, path: …, kind: spec, …, generated_from: …, platform: neutral, update_policy: …}   # 每数据件一行
install: 登记提醒: 每复制件按登记建议块同步登记 artifacts.yaml 条目（生成件登记并入条目单本账，见包内 development-process 模板 §5.3.1）
install: DONE: 复制 N 件（脚本 <n>＋数据 <m>）、幂等跳过 M 件 -> <目标>/scripts
install: FAIL: <原因>        # fail-closed 停止（stderr，exit 1）
install: <用法或环境错误说明>   # stderr，exit 2
```

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部复制并核验通过。 |
| 1 | fail-closed（包内误运行守卫、目标不存在或不可写、源缺失（脚本件与数据件同口径）、目标同名件与基线不一致、cmp 核验失败；预检先于复制，停止零半套）。 |
| 2 | 用法或环境错误（缺 `--target`、未知参数、零启用门控、规则表缺失或结构校验不过）。 |

### 维护联动

- 复制集合、门控构成或登记 lifecycle 值变化＝编辑 `install-policy.rules`＋同步本专节与 `../SKILL.md` 步骤 5 指向句；引擎解析器或校验口径变化须同步本专节。
- 夹具正负例（fast-lane 恰 3 件/ticket-ops 恰 2 件含回退注记/双开 5 选取去重 4 件/幂等重跑；规则表损坏 exit 2、缺源件 exit 1、包内误运行 exit 1、零 flag exit 2 等）为交付时一次性实跑，证据见票 Checkpoint；harness 沉淀已入 `test-record-layer.sh` 扩 suite。

## check-append-only.sh（Record 只追加守卫）

Record 只追加守卫（承接「Record 行级保护」候选口径）：对仓库记录层两类写入语义做只读核对——`facts/project/changes.jsonl` 与 `facts/project/micro.jsonl` 为只追加账本（Record 类，一行一事实，懒创建）：工作树内容相对 HEAD 旧 blob 必须为尾部追加（旧 blob 内容为新内容前缀），中间插入/改写历史行/截断/删除即违规，FAIL 指名文件与首个违规行号（新文件行号）；`facts/project/archive/progress.md` 与 `facts/project/archive/changes.md`（R14 并列冻结对，同名平移零改写；2026-09-23 自 docs/ 时代迁址）为冻结历史档案（指针注记后零写入，development-process §11）：任何 diff 即违规，迁移窗口（HEAD 尚无后继路径）以后继工作树内容与 HEAD 旧路径逐字节一致为承继通过（旧路径＝docs/ 兼容布局同名件，仅作迁移承继候选，非现行守卫对象）。核对基线＝工作树 vs HEAD（`git diff` 同口径；未跟踪且 HEAD 无同名的新文件按懒创建全追加语义放行）。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖（仅 POSIX 标准工具与 Git 只读子命令 rev-parse/cat-file/show，不含任何 Git 写操作）、fail-closed。可作 verify 命令加入门禁清单（如快道合同 `verify:` 行）。

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
check-append-only: OK: <后继>（迁移承继：与 HEAD <旧路径> 逐字节一致）
check-append-only: OK: <旧路径>（已迁移至 <后继>，内容承继核对通过）
check-append-only: SKIP: <文件>（不存在，懒创建语义）
check-append-only: WARN: 无 Git 基线（无 HEAD），只追加与冻结核对跳过（不硬猜基线先例）
check-append-only: FAIL: <文件> <违规描述（含首个违规行号）>
check-append-only: PASS
```

- 文件不存在跳过（懒创建语义，SKIP）；无 Git 基线（无 HEAD）输出 WARN 并退出 0（首次提交前不硬猜基线）。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部通过（含 SKIP 与无基线 WARN）。 |
| 1 | 存在违规（账本中间插入/改写历史行/截断/删除，或冻结档案出现 diff；FAIL 行指名文件与首个违规行号）。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库）。 |

### 维护规则

- 守卫对象集合（两账本＋两冻结档案）变化须同步脚本 `check_append_file`/`check_frozen_file` 调用段、usage 文本与本专节；三类 Record 语义（只追加/冻结/懒创建）不放宽。
- 前缀判定为字节级（旧 blob 内容为新内容前缀），首个违规行号为新文件行号（行级差异定位）；仅尾行悬挂换行差异按截断报告字节口径。前缀判定与前缀行号定位经 `common-helpers.sh` 共享原语（`record_prefix_ok`／`record_first_bad_line`，账本清单 `RECORD_APPEND_ONLY_PATHS`）承载，与 `lane-commit.sh` 记录提交门同一实现、零副本；语义变化须同步共享原语与两端调用方。
- 行为语义变化经 Review 门禁并同步 harness append-only 套件（正负例随动，红灯不隔票）。

## check-artifacts.sh（治理产物对账器）

实现约束：登记条目的 kind 和 lifecycle 分别按 artifacts-yaml.tmpl 中唯一的 enum 行校验；path 比较先折叠重复斜杠、点段与可消解的 .. 段并移除非根尾斜杠，规范化后重复即 fail-closed，并在错误中列出冲突条目和规范化值。登记解析破坏还包括缺 kind/lifecycle、未知枚举和规范化 path 重复。

治理产物登记与实物双向对账器（兑现 R-DP-007「治理产物逐件登记」的机械核对面）：正向＝`<repo-root>/facts/project/artifacts.yaml` 每条登记条目的 path 目标（剥离全角括注后的路径/聚合 glob/目录）必须存在，缺失 FAIL 指名条目；反向＝数据块受管口径内文件必须被登记（精确相等/case glob/目录聚合前缀三类覆盖）或命中豁免规则，未登记 FAIL 指名路径，豁免命中不报。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖（仅 POSIX 标准工具，无 Git 依赖）、fail-closed——登记解析破坏（缺 artifacts: 顶层键、零条目、条目缺 path、多行 path、path 值空/含空白、未知形态行）即 exit 2 不产生部分结论；退出码口径同 ticket-ops.sh（0 完成 / 1 缺口 / 2 用法环境）。

### 用法

```text
sh scripts/check-artifacts.sh [--fix [--apply]] <repo-root>
```

- `<repo-root>` 必填，仓库根目录（登记文件固定取 `<repo-root>/facts/project/artifacts.yaml`）。
- `--fix`：修复形态（dry-run 缺省，零写入）——复跑同一对账管线，将反向未登记受管文件的登记条目建议块（十三字段骨架，逐条对应一个 FAIL 路径）打印到 stdout；不可机械推断的字段写【按项目填写】占位，粘贴前由执行体补齐。
- `--apply`：仅与 `--fix` 同用（单用即用法错误 exit 2）——把建议条目块追加进 artifacts.yaml（条目块与 dry-run 预览同一生成代码、逐字一致；条目间空行分隔）；追加后本脚本即止，复跑核反向缺口归零归调用方；正向缺失不修（缺的是实物不是登记，补登记归执行体按实际产物定）。
- `-h` / `--help`：打印用法。

### 对账数据块（受管口径与豁免，定谳唯一承载点）

引擎零目录硬编码：受管口径、豁免与懒创建许可全部落脚本内数据块（`load_reconcile_data` 函数，`ca_*` 指令行），维护时不得静默增删，变更理由随行注记：

| 指令 | 语义 |
| --- | --- |
| `ca_managed_file <路径>` | 受管根单文件（存在才进反向清单）。 |
| `ca_managed_tree <目录> <扩展名逗号清单>` | 受管目录（递归，按扩展名过滤）。 |
| `ca_managed_flat <目录> <扩展名逗号清单>` | 受管目录（单层，按扩展名过滤）。 |
| `ca_exempt <路径>` | 反向豁免：精确路径；尾斜杠＝目录整支豁免；理由随行注记。 |
| `ca_lazy <路径>` | 正向暂缺许可：登记目标允许尚不存在（懒创建面），命中输出 SKIP 不计缺口。 |

本仓基线定谳（校准豁免迁入 delivery.rules）：受管＝根 `AGENTS.md`＋`rules/` 树内 md/json/jsonl/yaml/sh/rules＋`facts/` 树内 md/json/jsonl/yaml；豁免分两面——协议豁免（数据块，记录层通用语义＝协议面）：`facts/requirements/runs/`（运行记录投影）、`facts/requirements/tickets/progress-current.md`（生成投影）、`facts/requirements/tickets/index.json`（状态真相源单写面）、`facts/project/changes.jsonl`（追加面）、`facts/project/micro.jsonl`（道账本）；校准豁免（仓根 `delivery.rules` calibration 节 `dp_artifact_exempt`，逐仓不同的校准＝项目约定，自数据块迁入）：`facts/project/architecture/generated/`（生成投影面，理由注记随行）——文件缺失或无该行＝豁免消失，生成面文件按未登记 FAIL 暴露（fail-closed 方向），解析破坏 exit 2。懒创建许可＝`facts/project/micro.jsonl`（道脚本首次收尾懒创建）。目标项目落位后按自身 artifacts.yaml 现状校准数据块（增删 `ca_*` 行）与 delivery.rules calibration 节，不改动引擎。

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

- 产物增删/移动＝同步登记 `facts/project/artifacts.yaml`（数据先行），实跑本脚本核对；登记聚合条目（glob/目录）覆盖语义见上文反向口径。
- 受管口径或豁免变更＝改数据块 `ca_*` 行（理由随行注记）＋实跑盘点＋同步本专节基线定谳表；豁免扩大的裁决归用户（投影/追加面/生成面类），不得为消缺口静默扩豁免。
- 行为语义变化经 Review 门禁并同步 harness check-artifacts 套件（正负例随动，红灯不隔票）。

## host-config.sh（宿主配置对账器）

宿主无关的用户级配置文件对账：把宿主侧配置片段以标记块形式对账到目标文件，引擎零宿主专名与键名——宿主能力与键名由调用方按 `../references/adapters/<host>.md` §2.6/§2.7 取值后经 `--set` 传入。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖、自包含（不 source `common-helpers.sh`）。

### 用法

```text
sh host-config.sh --config <file> --set <key>=<value> [--set ...] [--write] [--confirm]
                  [--profile <facts/project/host-profile.md>] [-h]
```

- `--config` 恰一次；目标可不存在，父目录须存在才可写入（缺失 exit 1 指名）。
- `--set` 至少一条、可重复，按给定顺序落块；键限 `[A-Za-z0-9_.-]`，值非空且不含换行，非法 exit 2。
- `--write` 与 `--confirm` 必须同时出现，缺一 exit 2；两者都缺省＝dry-run，零写入。
- `--profile` 可选；给出时在 dry-run 与写入报告中附 host-profile 四列登记建议行，本脚本不写该文件（登记由执行体完成）。
- `-h`／`--help` 打印用法；未知参数、缺 `--config`、缺 `--set` 均 exit 2。

### 写入语义

标记块固定为 `# >>> agent-up host-config >>>` 至 `# <<< agent-up host-config <<<`，块内逐行 `<key> = <value>`；本脚本不管值内引号与宿主语法，由调用方传入已成形取值。

| 目标现状 | 行为 | 退出码 |
| --- | --- | --- |
| 文件不存在 | 创建并写入块；备份行报「无（目标原不存在，新建）」 | 0 |
| 无标记块 | 先备份为 `<file>.bak.<UTC yyyymmddThhmmssZ>` 再追加块 | 0 |
| 块逐字一致 | 幂等跳过，零写入，备份行报「无（幂等，未写入）」 | 0 |
| 块内容不同 | 视为人工改动：指名文件、不覆盖、零写入 | 1 |
| 标记不完整或重复 | 同上，报起始／结束标记出现次数 | 1 |
| 父目录不存在 | 指名目标，零写入 | 1 |
| 参数或用法错误 | 用法错误 | 2 |

- 逐字比较用 `cmp`：块内任何人工改动（含空白）都会停手，不做自动合并。
- dry-run 输出固定含「将修改（项目外）」分组（目标绝对路径、缩进片段、备份路径、`未勾选，不写入（仅片段）` 状态），供差异清单确认步骤引用；真写入输出同构分组并报实际备份路径。
- 回归＝`tests/suite-check-artifacts.sh` 的 host-config 断言组：dry-run 零写入（前后 sha256 一致）、写入后备份在场、复跑幂等跳过、人工改块冲突停手且文件不变、四类负例 exit 2、host-profile 四列文档面与 `kind: adapter` 双向对账。

## export-payload.sh（公开载荷导出单命令）

delivery.rules 驱动的公开载荷导出单命令（命令面权威＝载荷导出设计 §3）：把手工三重核验固化为命令面。POSIX sh（`#!/bin/sh`、`set -eu`）；导出形态（前缀/远端/目标分支/本地导出分支）读仓根 `delivery.rules` payload 节（引擎零项目约定硬编码）；本命令永不 force——不内建任何改写远端历史的路径（force 属用户授权动作，修复先例即用户明确授权下的一次性救援）。

### 用法

```text
sh scripts/export-payload.sh [--dry-run] [repo-root]
```

- `repo-root` 缺省取本脚本所在目录向上两级；`--dry-run` 语义见下表。
- `-h` / `--help`：打印用法。

### 六步流程

| 步骤 | 动作 | 实跑 | `--dry-run` |
| --- | --- | --- | --- |
| 前置 | 工作区 payload 根内未提交改动即停（导出半成品）；未声明 payload 节拒跑 exit 2；真跑另设主检出门禁（链接 worktree 内拒绝真跑，R-DP-036；`--dry-run` 不受限） | 是 | 干跑免检 |
| 1 split | `git subtree split -P <root>` 产出新导出头 H | 落本地分支 `-b <local_ref>` | 仅经变量传递，不落本地分支引用 |
| 2 树比对 | H 经 `git archive` 展开到全新 mktemp（即用即删），`diff -r` 对照工作区 payload 根须零差异 | 是 | 是 |
| 3 导出树 check-package | 临时展开目录内逐项全过（检查 13 独立语境静默跳过＝预期口径） | 是 | 是 |
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

## worktree-add.sh（worktree 栅栏化创建单命令）

一票一 worktree 工作流的创建面栅栏（R-DP-036 配套；运行面两闸＝export-payload 真跑主检出门禁与 install.sh worktree 自拒，本命令承载创建面一闸——三闸合围 main-only 脚本不得自链接 worktree 运行）。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）；排除清单读仓根 `delivery.rules` main-only 节（引擎零项目约定硬编码；解析经同目录共享解析库 `dp-load-rules.sh` 加载，缺件或版本漂移 fail-closed exit 2 指名，六规则与同族消费脚本同款）。

### 用法

```text
sh scripts/worktree-add.sh [--force] <合同文件>
sh scripts/worktree-add.sh [--force] <path> <branch>   # 旧接口（兼容保留）
```

- `<合同文件>`（合同入口，单参数）：派发合同文件路径（JSON 含 `TICKET_ID` 键，或委派合同模板的 `{{TICKET_ID}}` 节）。脚本自抽 TICKET_ID（票号-短名形态）派生分支名与站路径——分支名携带票号，站＝仓库根兄弟目录（目录容器以仓库名命名，取仓根 basename）下以票号命名的目录，目录名与分支共用同一票号；站容器目录缺失自动创建（在栅栏与防撞闸全过后）。调用方不再传路径与分支名。
- `<path> <branch>`（旧接口，双参数）：worktree 路径（git worktree add 同义）与新分支名；参数形态要求见 `sh scripts/worktree-add.sh --help`。保留供无合同调用方使用（如测试套件与既有编排）。
- `--force`：透传 git worktree add --force（目标已存在等场景）；不改变本脚本其余门禁。
- `-h` / `--help`：打印用法。

### 流程（四步）

| 步骤 | 动作 | 失败行为 |
| --- | --- | --- |
| 1 主检出自拒 | `git rev-parse --absolute-git-dir` ≠ `--git-common-dir`＝链接 worktree，拒绝运行（worktree 创建属协调层职责） | exit 1 |
| 2 配置加载与合同派生 | 读 `<repo-root>/delivery.rules` main-only 节；main-only 锚点缺失或文件缺失＝栅栏未知，拒跑（如本仓无 main-only 脚本，登记空节或径用 `git worktree add`；拒跑输出附分发模板 `../references/templates/delivery-rules.tmpl` 最小示例）；锚点在场即已声明（含空清单——裸锚点＋注释条目＝空排除清单，模板分发语境预期形态）；解析破坏拒跑。合同入口另自派发合同抽 TICKET_ID（票号-短名形态）派生分支名与站路径（仓库名取仓根 basename），合同文件缺失/不可解析或 TICKET_ID 缺失/形态不合同 exit 2 | exit 2 |
| 3 创建 | 分支形态断言（双接口同闸）→站容器缺失自动创建（合同入口；闸后落盘）→分支存在即检出、不存在即 `-b` 创建；`--no-checkout` 延迟物化 | exit 1 |
| 4 栅栏设置与生效断言 | sparse-checkout 非锥形：`/*` 放行全部＋逐条 `!<路径>` 排除（不带尾斜杠，同型覆盖文件与目录）；`read-tree -mu HEAD` 按 sparse 模式物化（`--no-checkout` 空树上 reapply 不物化，实证）；断言首条排除路径在 worktree 内物理不在场 | exit 1（附删除该 worktree 重试指路） |

- main-only 脚本自此在该 worktree 内不可运行（文件不在场——运行缺失文件与写入缺失目录均失败；绕过需显式 `sparse-checkout disable` 并重新物化，非静默动作）。
- 排除清单持久于该 worktree `$GIT_DIR/info/sparse-checkout`，随 worktree 删除一并消失；主检出永不启用 sparse-checkout（零影响）。
- 不执行 git push；不删除既有 worktree（同名目录已存在即停，`--force` 只放宽 git 层）。
- 创建完成行后另打印依赖准备提示（行内给同目录 `worktree-deps.sh <站路径>` 的绝对路径调用；同目录缺该件时改打印「本安装未随附依赖准备入口（worktree-deps.sh 不在场），请在站内自行准备依赖」）：本命令只创建 worktree、不安装依赖；npm 仓库由该命令在站内独立准备，非 npm 仓库由其自行 skip。

## worktree-deps.sh（worktree 依赖准备单命令）

一票一 worktree 工作流的依赖面：每个 worktree 拥有独立**真实** `node_modules`——符号链接共享会把「只读复用」与「安装先删后建」混在一起，任一 worktree 安装即清空他人依赖。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`，workspace 模式展开处局部恢复 glob）；只读判定先于安装，安装仅发生在断言全过之后。

### 用法

```text
sh scripts/worktree-deps.sh [--clone-accel --clone-from <dir>] [<worktree-root>]
```

- `<worktree-root>`：目标 worktree 根（绝对或相对路径）；缺省＝当前目录。
- `--clone-accel`＋`--clone-from <dir>`：克隆加速，**默认关闭**，二者互须；安装前以 `cp -cR`（clonefile）从播种源复制 `node_modules`，文件系统不支持（跨文件系统或非 APFS）时回退 `cp -R` 并提示。目标根已有 `node_modules` 时跳过播种。
- `-h` / `--help`：打印用法。

### 判定顺序

| 步骤 | 动作 | 失败行为 |
| --- | --- | --- |
| 1 符号链接拒绝 | 目标根 `node_modules` 为符号链接即拒（先于任何 skip 判定）；各 workspace 的 `node_modules` 同款检查 | exit 1 指名绝对路径 |
| 2 非 npm 仓库 skip | 目标根无 `package.json`＝非 npm 仓库，显式 `SKIP` 行且 exit 0（不制造假失败） | exit 0 |
| 3 清单断言 | 读 `workspaces`（数组或 `{"packages": [...]}`；形态不合或 JSON 损坏即 exit 2 指名），逐项展开后断言每个 workspace 的 `package.json` 在位；命中项只取目录（普通文件静默跳过，与 npm 一致）；支持单个 brace 组 `packages/{app,lib}`，多组／嵌套／未闭合／range（`{p1..p3}`）显式 exit 2 并指名（请改用目录列举）；绝对路径／含 `..`／含空白条目拒（exit 2） | exit 1 指名缺失路径，零安装 |
| 4 安装与安装后断言 | 断言全过后在目标根 `npm install`；安装后断言 `node_modules` 为真实目录（非符号链接） | exit 1 |

### 退出码

| 码 | 含义 |
| --- | --- |
| 0 | 依赖准备完成，或非 npm 仓库显式 skip |
| 1 | fail-closed（符号链接 `node_modules`、workspace 清单缺失、`npm install` 失败、安装后非真实目录） |
| 2 | 用法或环境错误（参数不合、目标根不存在、node/npm 不可用、JSON 清单损坏、`--clone-accel` 缺 `--clone-from`、播种源不合或为符号链接） |

- 不改 `package.json`/lockfile；不删除既有 worktree；联网仅发生在 `npm install`。
- 安装政策不收录本件（`install-policy.rules` 未登记），落位闭包归后续票面；本件按 `worktree-add.sh` 同目录定位 `common-helpers.sh`。

## dp-load-rules.sh（delivery.rules 共享解析库）

**用途**：`delivery.rules` 四节文法的解析唯一实现——四消费件（`check-artifacts.sh`、`check-stale-claims.sh`、`export-payload.sh`、`worktree-add.sh`）于解析点前同目录 source 本件后调用 `dp_load_rules <repo-root> <错误前缀>`，不再各自内嵌解析副本（五副本漂移风险收敛为单源）。`DP_PARSER_VERSION` 为版本唯一来源，消费件头部 `# dp-parser: N` 为各自最低要求版注记，加载时缺件报「共享解析器缺失」、版本低于最低要求报「共享解析器版本漂移」，均 exit 2 指名路径。

**契约**：解析结论落 `DP_*` 全集全局变量（payload 四字段/forbid/exempt/stale_lit/mainonly 清单与 declared 标记；消费件按需取用，未消费字段非冗余）；返回 0 正常（含文件缺失＝全默认未声明）、2 解析破坏（fail-closed 六规则，不产生部分结论）。本件零副作用（仅定义一变量一函数），不改调用方 shell 选项；锚点表 `an[1..4]` 与 `../references/templates/delivery-rules.tmpl` 逐字一致；文法、指令全集与版本的权威说明＝`../references/delivery-rules.md`（harness 机械核对三方逐一相等）。安装语境随 fast-lane 门控与 `worktree-add.sh` 同落位（同目录定位，安装闭包）。回归＝`tests/` 的 delivery-parser 套件（单源静态断言＋四消费件探针结论逐项相等＋畸形/缺件/漂移负例）。

## upgrade-check.sh（落地面升级对账器）

已治理仓对包新基线的逐件三态对账器（升级一等流程②；升级流程规则权威＝`../references/upgrade.md` 与目标项目 `rules/project.md`，本件只对账不出修复动作——与 check 系 --fix 准则的配对条件留后续票评估）。固定 Conditional README Emits 从 `templates/README.md` manifest 读取；仅当对应目录已存在时才要求 README，未生成目录输出 N/A；动态 `<目录>/README.md` Emits 无固定目标，明确输出人工盘点项；旧布局同时检查已存在的 docs/兼容目录。POSIX sh（`#!/bin/sh`、`set -eu`、`set -f`）、零外部依赖、全程只读（除打印外无写操作）、fail-closed。

### 用法

```text
sh scripts/upgrade-check.sh <pkg-dir> <repo-root>
```

- `<pkg-dir>`：包基线目录（clone/pull 后的 agent-up 包根，含 scripts/ 与 references/）。
- `<repo-root>`：目标项目根（已按本体系初始化）。
- `-h` / `--help`：打印用法。

### 对账口径（三态）

| 态 | cmp 面 | 判定 |
| --- | --- | --- |
| 自动同步 | 机械检查面 | 已启用门控的每份脚本分别与包基线 cmp 一致；规则块 ID 集一致；delivery.rules 仅在快道有证据时检查锚点（证据两源＝delivery.rules 在场或快道专属脚本已装；多门控共享脚本不构成快道证据）。双布局即使两份相同也报告冲突。 |
| 落后 | 条件/模板面 | 已启用门控对应的两种脚本落位均缺失；快道脚本已装而 delivery.rules 缺失，或配置在场而缺锚点；所需规则文件或规则块 ID 缺失；模板 manifest 声明的 Conditional README 对应目录存在但 README 缺失。 |
| 漂移/冲突 | 脚本与布局面 | 任一已安装脚本副本不同于包基线；新旧布局同时存在必报冲突并逐份比较。工具不选择或修复副本。 |

规则块核对覆盖 AGENTS.md、现代 rules 三件与新布局三份角色合同，只比较规则块 ID 集，不比较块内语义。旧式 docs 角色合同按登记兼容面检查存在性。固定 Conditional README Emits 自模板 manifest 提取；目录不存在时 N/A，目录存在但 README 缺失时报落后；旧布局会映射检查 `docs/issues/`、`docs/specs/`、`docs/research/` 和 `scripts/` 中已存在的兼容目录。`<目录>/README.md` 动态 Emits 与 README/artifacts.yaml 等项目定制内容输出人工核对，不据此宣称内容同步；Derived 新鲜度由升级手册单独回访。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 自动检查面无差距；仍可能有人工核对和 Derived 回访待完成。 |
| 1 | 有差距（落后/漂移行见输出；升级流程入口＝`../references/upgrade.md`）。 |
| 2 | 用法或环境错误（参数数量不合、pkg-dir/repo-root 不存在、install-policy.rules 或 delivery-rules.tmpl 或本件在包基线缺失）。 |

## check-dispatch-contract.sh（派发合同校验器）

四模式派发合同校验器：对主 agent 派发的阶段合同（implementation/review/commit）做机械完整性核对、对包内派发合同模板做占位符零漂移核对，并对派发前置条件（linked worktree＋票在 `in_progress`）与步数预算（步数上限＋到线收尾）做准入校验。POSIX sh（`#!/bin/sh`、`set -eu`）＋awk；`--check-dispatch` 另需 python3 解析票索引（JSON 引擎与 `contract-build.sh` 同口径），其余三模式零外部依赖（无 jq/python）；全程只读、fail-closed（schema 或模板缺失即环境错误，不产生部分结论）。

### 数据件与比对基准

- schema 数据件＝`../references/schemas/dispatch-contract.schema.json`：`placeholders` 为 28 个占位符全集（字段名字典）；`contract_fields` 按三阶段列必备字段——implementation 16 字段、review 6 字段、commit 6 字段（字段约束的唯一机器承载点，字段增删＝先改 schema 再改模板与合同实例）。
- 模板比对面＝`../references/prompts/` 三件 `implementation-prompt.md`／`review-prompt.md`／`commit-prompt.md`（占位符承载面，显式三件列举不用 `*.md` 通配——同目录 README 亦含 `{{占位符}}` 文档字样，通配纳入即污染比对基准）。`../references/templates/` 三份角色合同骨架（`agents-*.md.tmpl`）不承载占位符，不在漂移比对面；其中 implementation/review 两份 §1「收到合同首步」句引用本脚本 `--check` 模式，commit 合同为票内 `dispatch.commit` 字段并由 `ticket-run.sh commit` 内部校验，不跑本脚本。
- 派发前置数据面＝合同文件 `{{REPOSITORY_PATH}}`／`{{TICKET_ID}}` 实值行＋主仓 `facts/requirements/tickets/index.json`（路径由目标 worktree 的 `git-common-dir` 反推，不信任调用方传参）。

### 用法

```text
sh scripts/check-dispatch-contract.sh --check-template | --check <合同文件> |
    --check-dispatch <合同文件> | --check-step-budget <合同文件>
```

- `--check-template`：模板漂移检查——schema `placeholders` 全集与三份模板占位符并集做双向零差集（schema 有模板无／模板有 schema 无任一方向非空即 FAIL 并逐名输出差集）。
- `--check <合同文件>`：执行体自查——按特征字段推断合同类型（`{{SCOPE_TREE}}`→implementation、`{{REVIEW_SCOPE}}`→review、`{{FILE_WHITELIST}}`→commit；三者皆无＝无法推断即失败），提取合同文件占位符与 schema 该类型 `contract_fields` 必备清单比对，缺失即 FAIL 并逐名输出缺失字段名。
- `--check-dispatch <合同文件>`：派发前置校验——取 `{{REPOSITORY_PATH}}` 实值（须绝对路径、存在、为工作树根），规范比较 `git rev-parse --git-dir` 与 `--git-common-dir`：两者相等即主检出，FAIL exit 1；linked worktree 时由 `git-common-dir` 的父目录反推主仓根，读主仓索引核验 `{{TICKET_ID}}`——索引无该条目即「未领取」FAIL，`status` 非 `in_progress` 即 FAIL 并报实际状态。PASS 输出 `PASS: 派发前置校验（linked worktree + in_progress: <id>）`。
- `--check-step-budget <合同文件>`：步数预算校验——按「`步数上限`＋分隔符（半角/全角冒号）＋值」提取首个上限值，值取到 `（`、`(`、`，`、`,`、`；`、`;`、`。` 前的片段，并核验到线收尾表述（`到线`／`收尾`／`交接摘要`）在场。四类各自指名拒绝，均 exit 1：缺 `步数上限` 记号（`FAIL: 派发合同缺步数上限（须写明「步数上限：<数字>」）`）、缺到线收尾表述（`FAIL: 派发合同缺到线收尾表述（缺 …）`）、有记号但无分隔符或值为空（`FAIL: 步数上限为空`）、值非纯数字（`FAIL: 步数上限非数字：<值>`）。齐全时输出 `PASS: 步数预算与到线收尾完整（步数上限 <值>）`。合同文件不存在 exit 2。本模式独立于 `--check`／`--check-dispatch`，不并入二者（既有合同可不含预算行）。
- `-h` / `--help`：打印用法。

### 失败语义

| 退出码 | 语义 |
| --- | --- |
| 0 | 通过（模板零差集，或合同文件该类型必备字段完整，或派发前置满足，或步数预算与到线收尾齐全）。 |
| 1 | 失败：差集（`FAIL: schema 有但模板无`／`FAIL: 模板有但 schema 无`）或缺失字段（`FAIL: 合同文件缺失字段：` 后逐名一行）；合同文件不存在、无法推断合同类型、schema 无该类型字段定义同此码；`--check-dispatch` 的主检出路径、未领取票、非 `in_progress` 票同此码；`--check-step-budget` 的缺步数上限、缺到线收尾表述、步数上限为空、步数上限非数字四类同此码。 |
| 2 | 用法或环境错误（未知参数、`--check`／`--check-dispatch`／`--check-step-budget` 缺合同文件参数、schema 数据件缺失、三件模板缺失、占位符集解析为空；`--check-dispatch` 另含：合同缺 `REPOSITORY_PATH`／`TICKET_ID` 实值行、路径非绝对/不存在/非 Git 工作树/非工作树根、主仓索引缺失或不可解析、python3 缺失）。 |

### 维护联动

- schema 占位符或必备字段变化＝先改 schema 数据件，再同步三份 prompt 模板（`--check-template` 拦双向漂移），最后同步 harness 断言（`--suite dispatch-contract`）。
- 合同类型推断特征字段变化＝同步本专节、脚本 `infer_contract_type` 与 schema `contract_fields` 三处。
- 派发前置口径变化（工作树约定、索引状态机、索引落位）＝同步本专节、`check_dispatch_preconditions` 与 Triage 合同派发边界句、capability-contract §2.2；`--suite dispatch-contract` 的 AC4 夹具用临时主仓＋linked worktree 覆盖正负例。
- 步数预算口径变化（上限默认值、到线收尾与交接摘要要素、豁免写法）＝同步三份角色模板的 `R-RI-005` 判据、`check_step_budget` 与 `--suite dispatch-contract`／`--suite role-prompt` 两套件；到线要求本身属角色合同正文，模板侧改动须两套件同改。
- 包内语境运行（schema/模板按 `scripts/` 上一级 `references/` 相对定位）；复制落位（`rules/implementation/scripts/`）语境须同迁 schema 与模板两件，引擎不自动探测其他落位。

## ticket-run.sh（主 agent 编排入口：可恢复协调器）

`ticket-run.sh <NN> <command> [args] [repo-root]` 是可恢复协调器：每个子命令只做一步，副作用只经已登记幂等原子层（`contract-build.sh`／`worktree-add.sh`／`ticket-ops.sh`），不直接写索引、README、账本或投影。有副作用的动作前先向 `<git-common-dir>/ticket-run/<NN>.intent` 追加 `<step> TAB <started|done> TAB <UTC> [TAB <载荷>]`（`record` 的 `started` 行第 4 列记收据绝对路径、第 5 列记 `receipt_kind`，供恢复判定核对实态）；同一命令失败后重跑即收敛，无法判定的状态返回 `decision-required`。

| 子命令 | 行为 | 退出码 |
| --- | --- | --- |
| `next [--clear-intent]` | 只读推导下一步，打印 `ticket-run: 下一步: <token>` 与 `ticket-run: 原因: …`；token 取值 `open`、`start`、`contract implementation`、`contract review`、`commit`、`record`、`done`、`decision-required`。有未完成 intent 时另打印 `ticket-run: 恢复: …`；给出「重跑 X」前先对照该命令的索引前置（`worktree`／`take` 残留要求 `start` 前置 `ready|in_progress`，`record` 残留要求站有效），前置不满足即 `decision-required` 并打印登记清除路径，不提示一条会被前置拒绝的假下一步（`review_ready`／`review_pass`／`blocked` 等非可领取状态同口径）。零写入、不落 intent。`--clear-intent` 只对**已判不可收敛**的残留开放：清除前先打印将被删除的 intent 原内容再删日志并重算下一步；残留仍可收敛（如索引 `in_progress`／`ready` 时 `take` 残留尚可由 `start` 幂等补齐、站有效时 `record` 残留尚可重跑）即拒绝清除、`exit 1` 并指名须重跑的子命令——避免删掉唯一恢复信号、掩盖 `start` 本应做的账本／投影补齐。 | `0` 有下一步（含清除成功）；`1` `decision-required` 或拒绝清除；`2` 用法或环境错误 |
| `start` | 索引须为 `ready` 或 `in_progress`；站缺失时经 `worktree-add.sh`（两参旧接口）建站，随后经 `ticket-ops.sh take` 领取。站已在位且分支为 `ticket/<id>` 时跳过建站，但须先核验栅栏（`core.sparseCheckout=true`、`git status --porcelain` 无删除记录（`D `／` D`／`DD`；空索引窗口即 `D `）、`git ls-files` 非空（空索引单独判「未物化」，提示语与「索引非空但有删除」区分）、`delivery.rules` main-only 清单逐项物理不在场、站内 `info/sparse-checkout` 逐条含 `!<路径>` 排除规则）：核验不通过一律 `decision-required` 并停止写入（不写 intent、不碰索引/README/账本/投影），须按 `worktree-add.sh` 重建站后重跑；核验通过补记 `worktree done`。新建站主路径在 `worktree-add.sh` 返回 0 后走同一核验，失败同样不领取。索引已 `in_progress` 时走 `ticket-ops` 幂等重放补齐 README／账本／投影；账本行日期取本地 `date +%F`（与 `ticket-ops` 的 `updated_at` 同源），索引已 `in_progress` 时取索引 `updated_at` 的日期，避免本地/UTC 跨日或跨午夜重跑重复落行。站路径存在但不是有效 Git worktree、或分支不符即 `decision-required`。 | `0` 收敛；`1` `decision-required`；`2` 用法或环境错误 |
| `contract <stage>` | stage 为 `implementation` 或 `review`；站须有效，合同渲染到 `$TMPDIR`，stdout 恰两行（站路径＋合同文件），不写任何状态载体。 | `0` 两行输出；`1` 站缺失或渲染失败；`2` 用法或环境错误 |
| `record <receipt-file>` | 按 `receipt.schema.json` 字段合同校验收据（顶层键集恰等、必备字段非空、`receipt_kind` 条件必备、字段类型、acceptance 项键集恰等、sha／时间戳／枚举模式）；`review` 落位 `<站>/facts/requirements/tickets/<id>.review-evidence.json`，其余落位 `<站>/facts/requirements/runs/<id>.<kind>.receipt.json`。同内容重跑收敛（补记 intent `record done`）；不同内容返回 `decision-required`，不覆盖既有证据。源收据被清理时，恢复判定按 intent 第 5 列 `receipt_kind` 对应的目标证据存在即视为已完成（内容无法再比对，属已知限制；证据不可覆盖语义保证目标不被后续改写）。字段合同内嵌脚本常量，运行时不读取 schema 文件（安装闭包零新增数据件），常量与 schema 的逐项一致性由 ticket-run 套件单源守卫核对。 | `0` 落位或同内容收敛；`1` 校验未过／证据冲突／站缺失；`2` 用法或环境错误 |
| `verify-dispatch <stage> [合同文件]` | stage 为 `implementation`、`review` 或 `commit`；重渲染票面 `dispatch.<stage>` 并与合同文件逐字比对，拒绝三类：票面缺阶段对象／缺键／空白值（`contract-build.sh` fail-closed）、合同文件缺失、合同漂移。 | `0` PASS；`1` 三类拒绝；`2` 用法或环境错误 |
| `repair` | 安全、幂等、追加式纠偏，四类动作：①**补站**——站缺失且索引状态为 `ready`／`in_progress`／`review_ready`／`review_pass`／`review_fail` 时经 `worktree-add.sh`（两参旧接口）补建并写 intent `repair started`／`done`，站已在位则只核栅栏（同 `start` 口径，含分支须为 `ticket/<id>`），终态票跳过；②**重建派生投影**——先跑 `generate-progress.sh --check`，仅 exit 1（漂移）时再生 `progress-current.md`，其余非 0 判投影无法核验；③**检测 main 直提**——按票分支 ref 与 main 比对（不依赖站是否在位）：`git rev-list --no-merges ticket/<id>..main` 后按 `audit-policy.json` 的 `baseline_sha` 限定范围，过滤治理面路径（`facts/`、`rules/`、`agent-up/`、`.zcode/`、`.githooks/` 与根治理文件），命中即 `decision-required` 并打印逐条候选与 `git cherry-pick <sha>` 迁移建议；④**Review 在场判定**——站内 `<id>.review-evidence.json` 在位，或站缺失时主仓同名路径在位，即 `present`；两处皆无时索引 `done`／`review_pass` → `decision-required`，有实现提交或 `review_ready` → `pending-review`，其余 `not-required`。只写站与 `progress-current.md`，索引／README／账本／票本体零改写；不生成收据或审查结论，不执行 rebase／amend／force-push 或任何历史改写。输出行：`站:`、`派生投影:`、`Review:`、`main 直提:`、`迁移建议:`、`状态载体:`、`结果:`。 | `0` `converged`／`repaired`／`pending-review`；`1` `decision-required`；`2` 用法或环境错误 |

`next` 的 `decision-required` 以退出码 `1` 表达（与「有下一步」的 `0` 区分），自动化消费可凭退出码分流；该退出码不写任何载体，与其余子命令的 fail-closed 口径一致。

站完整性是 `start` 的收敛前提：站路径存在不等于建站完成。`start` 在跳过建站前核验 worktree 栅栏与仓根 `delivery.rules` 的 main-only 清单同源；`core.sparseCheckout` 未设、`git status --porcelain` 有删除记录（`D `／` D`／`DD`）或 `git ls-files` 为空（`--no-checkout` 后 read-tree 前崩溃的空索引；单独判「未物化」，提示语与「索引非空但有删除」区分）、main-only 路径仍在场、站内 `info/sparse-checkout` 缺任一条 `!<路径>` 排除规则、解析器缺失/漂移或 main-only 节未声明，一律 `decision-required` 且零写入（不写 intent、不碰索引/README/账本/投影），须删除站后按 `worktree-add.sh` 重建再重跑。新建站主路径在 `worktree-add.sh` 返回 0 后执行同一核验，不因原子层返回成功就假设栅栏已生效。

legacy 三阶段 `ticket-run.sh <NN> <implementation|review|commit> [repo-root]` 行为保持不变，以任务票 `dispatch` 节为唯一合同来源。implementation/review 的 stdout 恰为 `ticket-run: 站路径: <abs>` 与 `ticket-run: 合同文件: <abs>` 两行；合同文件保留在 `$TMPDIR` 供主 agent 派发，脚本不启动子 agent。implementation 缺站时经 `worktree-add.sh` 创建，review 要求站已存在。

commit 从 `dispatch.commit` 读取六字段：`REVIEW_PASS_CHECKPOINT` 指向站内 Review 文件；`FILE_WHITELIST` 为逗号或换行分隔的仓内文件；`COMMIT_MESSAGE` 为产品提交信息；`SCOPE_CHECK_COMMAND` 一行一条经 `check-gates.sh` 重跑；`TICKET_ID` 须与票文件一致；`RECORD_FLIP_AUTHORIZATION` 为 `none`，或逐行 `flips: facts/requirements/tickets/index.json:index:<id>:<status>:<updated_at>`。脚本先完成全部预检，再创建白名单产品提交；随后进入记录收口段（经共享库 `record_lock_ensure` 自取记录层写锁，覆盖「flip-index → `checkpoint.commit` → 记录提交」全段；`flip-index` 以 `RECORD_LOCK_INHERITED=1`＋锁目录＋令牌接管同一把锁、不自行取锁，段末按所有权释放，失败路径由 EXIT 陷阱兜底）——在站内票本体原子写入 `checkpoint.commit`（`committed_at`＋产品提交 ID），经 `ticket-ops.sh flip-index` 执行明列索引翻转，最后把票文件（及翻转时的索引/投影）统一并入纯记录提交——无翻转也创建记录提交；stdout 依次打产品提交、`checkpoint.commit` 与记录提交行。不生成 User Review Checkpoint，不伪造用户裁决。commit 阶段不渲染阶段合同文件，`$TMPDIR` 不留提交侧产物。任何合同缺失、Review 非 PASS、路径越界、白名单越界或验证失败均 fail-closed。

### Review 结论的唯一判定格式

commit 只认「结论位」，取值仅三种：`PASS`、`PASS_WITH_NOTES`、`FAIL`（大小写不敏感）。结论位只有两种合法形态：

- **整行记号**：首个非空行恰为结论词本身，可带尾随 ASCII 标点、空白或 Markdown 强调修饰（`*`、`_`、反引号、双引号），如 `fail`、`**PASS**`、`FAIL.`。行内再有任何其他文字（如 `PASS: AC1 通过`、`FAIL — 原因`）都不算整行记号。
- **显式标签行**：全文件**唯一一行** `Verdict: <结论>`、`Review Verdict: <结论>` 或 `评审结论：<结论>`（半角/全角冒号均可，`- `、`+ `、`> ` 列表记号可选）；标签值须以结论词开头，其后可跟标点或注记，如 `- 评审结论：**pass**（2026-10-29，说明）`。

其余行一律不参与判定，尤其是 `PASS:`、`pass` 这类证据行——它们既不能推翻首行 `fail`，也不能补出缺失的结论。以下情形 fail-closed、exit 1 零提交：无合法结论、标签行多于一条、标签值不可识别、首行与标签结论冲突。审查文件因此须在报告开头单列一行整行结论，或全文件只留一行标签行。

- 存量格式 `评审结论：**pass**` 及其带注记写法（`- 评审结论：**pass**（…）`）经归一化后等价于标签行，兼容读取；新增审查文件仍建议用 `Verdict: PASS` 单行。

## ticket-audit.sh（证据审计引擎）

`sh scripts/ticket-audit.sh [<NN>] [--repo <dir>] [--operation read|analyze|merge|push] [--range <base>..<head>] [--max-commits <n>] [--skip <sha>]... [--evidence <path>] [--policy <path>] [--allow-after <rel>]...` 对一张任务票的审查收据做只读审计：逐谓词打印 `PASS`／`FAIL`／`UNKNOWN`，再按操作面给放行判定。票定位＝`facts/requirements/tickets/<NN>-*.json`（排除 `*.review-evidence.json` 与 `*.workflow-checkpoint-v1.json`，恰一命中，否则 exit 2）；缺省仓库根＝`git rev-parse --show-toplevel`，缺省证据＝票文件同名 `.review-evidence.json`，缺省策略＝`facts/requirements/audit-policy.json`。target＝仓库 HEAD；全程只读零写入，Git 只读命令之外不落任何文件。

| 谓词 | 名称 | 判据（不合格分支） |
| --- | --- | --- |
| P01 | receipt-parseable | 证据存在、可解析、`schema_version=1`、`receipt_kind=review`、`ticket_id` 与票文件一致；失败即短路，依赖证据内容的谓词不评估 |
| P02 | evidence-committed | 证据被 HEAD 跟踪且工作树内容与 HEAD blob 一致（提交后再改动 FAIL） |
| P03 | base-sha-present | `base_sha` 为 40 位小写十六进制、可解析且为 head 祖先 |
| P04 | review-boundary-clean | `head_sha` 可解析且为 target 祖先；`head..target` 改动只允许证据路径＋调用方 `--allow-after` 显式传入的路径（缺省仅证据，禁止整体放开 facts/或任意文件），多余改动指名 `<path>:1` |
| P05 | diff-sha-bound | `diff_sha` 等于 `base..head` 重算指纹（`git diff --binary` 经 `git hash-object --stdin`） |
| P06 | reviewer-identity-present | `reviewer_identity` 非空且不含空白字符 |
| P07 | reviewer-identity-corroborated | 与证据提交 author email 大小写不敏感相等，且属策略 `trusted_reviewers`；条件不足即 UNKNOWN，不判 FAIL |
| P08 | reviewer-distinct-from-implementer | 审查者不得为 head 作者或策略 `implementation_identities` 成员（自签即 FAIL） |
| P09 | reviewed-at-valid | `reviewed_at` 为 UTC 秒粒度；日粒度 ≥ head 提交日、≤ 证据提交日、≥ 策略 `effective_from`（早于生效日＝旧 PASS，FAIL） |
| P10 | acceptance-results-present | `verdict` 严格三值 `PASS`／`PASS_WITH_NOTES`／`FAIL`；`acceptance` 非空，逐项 `ac_id` 非空且 `result` ∈ `pass`／`fail`／`unknown`；`PASS` 须全 `pass`，`FAIL` 即拒 |
| P11 | policy-applicable | 策略可加载且适用（见下）；任一不满足即 UNKNOWN |

输出三行契约：逐谓词行 `PASS|FAIL|UNKNOWN <Pxx> <名称>: <相对路径>:<行号> — <原因>`；`ticket-audit: 证据位置: <路径>@<提交>:<blob>`（未提交为 `@未提交`）；`ticket-audit: 操作面: <op> 允许|拒绝（…）` 与 `ticket-audit: 判定: conformant|nonconformant|unknown（…）`。退出码：`0`＝conformant，或 unknown 下的 read/analyze；`1`＝nonconformant（任何操作面皆拒），或 unknown 下的 merge/push；`2`＝用法或环境错误。unknown 不阻断读面与诊断，写面（merge/push）只以 conformant 为门。

### 批量/推送面（`--range`）

```text
sh scripts/ticket-audit.sh [<NN>] --operation push --range <base>..<head> \
  [--max-commits <n>] [--skip <sha>]... [--repo <dir>]
```

仅当 `--operation push` 与 `--range` 同时给定时进入批量面；未给 `--range` 时单票行为（输出行与退出码）逐字不变。选取口径只认显式区间：`<base>`／`<head>` 为完整 40 位小写提交号，base 须为 head 祖先（否则 exit 2 用法错误），区间提交按 oldest→newest 枚举；空区间输出一行判定并 exit 0。`--max-commits` 缺省 50，区间提交数超上限即 exit 2 并指名实际条数与上限；`--skip <sha>` 可重复，仅接受完整 40 位小写十六进制，命中的提交输出 skip 行且不计入判定。批量面可省略 `<NN>`——逐提交票 id 取自提交标题（`ticket/<id>` 或「票 <id>」）；标题只给裸号（如「票 <NN>」）时按 head 树索引 `^<NN>-` 前缀唯一匹配解析为全 slug id（依据写全 id），零命中或多命中即 nonconformant 并指名（多命中列出候选，不猜）；`--skip` 不得为空值。

逐提交输出行：`ticket-audit: 批量 <短 sha> <conformant|nonconformant|unknown|skip> <依据>`。判定规则：

- **merge 提交（父提交 ≥2）**：须有绑定该提交的审查收据——区间 head 树内 `facts/requirements/tickets/*.review-evidence.json` 的 `head_sha` 等于该提交；有则 conformant。无则 nonconformant，依据指名票 id 与失败谓词 `P01`（提取不到票 id 时写「票 id 不可解析」，不静默放行）。
- **单亲提交（ff 合并遗留）**：按票状态兜底——票 id 同上解析，读区间 head 树内 `facts/requirements/tickets/index.json` 的该票 `status`；`done` → conformant（依据「兜底：票 <id> status=done」），未 done／未登记 → nonconformant 并指名实际状态。
- **父关系不可读**：`unknown`，按非 conformant 计入。

汇总行 `ticket-audit: 批量 判定: conformant|nonconformant（…）`：skip 以外的提交全部 conformant 才 exit 0，任一 nonconformant/unknown 即 exit 1；仓库、JSON 引擎、票目录或 head 树内索引缺失/不可解析沿用 exit 2。批量面全程只读零写入，只补推送面的区间兜底，不替代、不放宽单票 `--operation merge` 的证据门——无收据的 merge 提交在批量面同样指名 P01，不得以票状态兜底放行。

### 审查收据与审计策略

收据 schema 为 `references/schemas/receipt.schema.json`（draft-07，`additionalProperties: false`）：`receipt_kind=review` 时必备 `base_sha`、`head_sha`、`diff_sha`、`reviewer_identity`、`reviewed_at`、`verdict`、`acceptance`。审计引擎只读取这些字段，不写回。

策略文件（缺省 `facts/requirements/audit-policy.json`，不建独立 schema，字段口径即本节）必备：

- `schema_version`：须为 `1`。
- `effective_from`：`YYYY-MM-DD`；晚于 target 提交日即不适用（UNKNOWN），审查时间早于该日视为旧 PASS（P09 FAIL）。
- `baseline_sha`：40 位小写提交号，须可解析且为 target 祖先。
- `release_baseline`：`none` 或可解析的标签名。
- `trusted_reviewers`：非空 email 数组，P07 据此佐证审查者独立性。
- `implementation_identities`：实现者 email 数组，P08 据此识别自签。

策略缺失、不可解析或任一项不合格即 P11 UNKNOWN；引擎不以默认值兜底，也不据猜测放行写面。

## measure-context-cost.sh（上下文成本与治理体积复测）

只读复测工具：把改动前与改动后的会话成本、治理体积放到同一口径下，差值＝基线−当前，正数即下降即收益。两种模式互斥——缺省会话模式递归读取会话根下全部 `wire.jsonl` 的 `usage.record` 与消息体；`--governance` 读取安装模板九件。输出 ≤40 行；任一指标缺失、样本不足或基线缺键即 exit 非 0 且零 stdout（不输出半套指标）。会话日志与模板目录均零写入，仓库零写入；POSIX sh＋python3 流式聚合（逐行处理，不整仓载入内存）。

### 用法

```text
sh scripts/measure-context-cost.sh [--sessions <dir>] [--baseline <json>] [--min-samples <n>]
sh scripts/measure-context-cost.sh --governance [--templates <dir>] [--baseline <json>]
```

- `--sessions <dir>`：会话根目录，缺省 `$HOME/.kimi-code/sessions`。
- `--baseline <json>`：基线 JSON（键＝指标名，值＝数字）；给定时逐项输出差值与变化率，缺省只输出当前值。
- `--min-samples <n>`：最小 `usage.record` 样本数，缺省 100，合法下界 1（0 会放过 0 条样本的差值表，按用法错误 exit 2 并指名参数与下界）；低于阈值 exit 1 并指名缺失项。
- `--governance`：治理体积模式；`--templates <dir>` 缺省本脚本上一级的 `references/templates`。
- `-h` / `--help`：打印用法，exit 0。

### 指标口径

会话模式（样本＝全部 `usage.record`，calls＝样本数）：

| 指标 | 口径 |
| --- | --- |
| `raw` | `inputOther + output + inputCacheRead + inputCacheCreation` 之和 |
| `cache_read` | `inputCacheRead` 之和 |
| `input_added` | `inputOther + inputCacheCreation` 之和（真正新增输入） |
| `output` | `output` 之和 |
| `context_per_call` | `(inputCacheRead + input_added) / calls`，整除 |
| `tool_calls_per_step` | assistant 消息 `toolCalls` 数组元素总数 / calls，两位小数 |
| `tool_results_over_20000` | `role=tool` 消息文本解码后长度 >20000 的条数 |
| `agents_over_250_steps` | 单文件 `usage.record` 数 >250 的 agent 文件数 |

表后附三行：样本计数（calls／阈值／基线 calls／agent 数／工具调用总数）、每步工具调用分布（0／1／2／3+）、每 agent 步数分布（<=10／11-50／51-150／151-250／>250）。未知字段容忍、坏行跳过；缓存字段缺失按 0 计。

治理模式（安装模板九件＝`AGENTS.md.tmpl`、`core.md.tmpl`、`project.md.tmpl`、`assessment.md.tmpl`、`discipline.md.tmpl`、`agents-triage.md.tmpl`、`agents-implementation.md.tmpl`、`agents-review.md.tmpl`、`agents-commit.md.tmpl`）：

| 指标 | 口径 |
| --- | --- |
| `install_chars` | 九件字符数之和，python3 `len(open(..., encoding="utf-8").read())` |
| `install_blocks` | 九件内 `^#### R-[A-Z][A-Z]-[0-9][0-9][0-9]` 规则块数 |
| `stage_triage_chars` | AGENTS／core／assessment／project／agents-triage |
| `stage_implementation_chars` | AGENTS／core／discipline／project／agents-implementation |
| `stage_review_chars` | AGENTS／core／discipline／project／agents-review |
| `stage_commit_chars` | AGENTS／core／project／agents-commit |

基线口径只算安装九件：瘦身前安装面为 54 块，`references/protocol/`、`references/adapters/` 的 26 块不在安装闭包、不计入（两者合计 80 条旧块，处置另见 `references/why/decisions.md`）。

差值列＝基线−当前，变化率列＝(基线−当前)/基线；正数即下降即收益，负数即增长即代价。基线缺任一同名键即 exit 1 指名缺失键。

### 基线 JSON 形态

键名与上表逐项同名同单位，值为数字；示例（数值仅示形态）：

```json
{"raw": 2254213027, "cache_read": 2198990527, "input_added": 43801527, "output": 11420973, "context_per_call": 143962, "tool_calls_per_step": 1.36, "tool_results_over_20000": 418, "agents_over_250_steps": 11}
```

治理模式以 `install_chars`、`install_blocks`、`stage_triage_chars`、`stage_implementation_chars`、`stage_review_chars`、`stage_commit_chars` 为键（整数）；会话模式可选 `calls` 键。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 全部指标就绪（给基线时逐项出差值）。 |
| 1 | 路径不存在、会话无 `usage.record`、样本低于阈值、基线文件缺失或基线缺指标。 |
| 2 | 用法或环境错误（未知参数、参数不合形态、模板缺件、共享库或 JSON 引擎缺失）。 |

回归＝`tests/` 的 `context-cost` 套件（`sh tests/suite-context-cost.sh` 或 `sh tests/test-runner.sh --suite context-cost`），夹具内建、仓库零留样。

## test-record-layer.sh（记录层回归 harness）

- 布局：`test-record-layer.sh` 为兼容入口（委托 `tests/test-runner.sh`，参数不变）；`tests/test-helpers.sh` 承载 ok/bad/assert_eq/suite_summary/cleanup 等共享函数；每个 suite 一个 `tests/suite-<name>.sh`（内含该套件私有夹具函数），文件头带独立入口（直接 `sh tests/suite-<name>.sh` 即跑该套件）。新增套件三处同步：runner 派发表、本节 suite 覆盖表、清单 scripts 节 dir 行描述。

记录层共享回归 harness：把六票 Implementation Checkpoint 声明待沉淀的一次性 fixture 组装为常驻自检工具——一条命令回归记录层全链。POSIX sh（`#!/bin/sh`、`set -u`、`set -f`）、无 jq；open 本体校验路径依赖 python3 标准库，缺失即 exit 2（夹具 `git init` 依赖被测脚本自身声明的 Git）。缺省自测同目录包内脚本（check-package.sh 同款路径惯例），`--script-dir`/`--pkg-root` 参数化支持复制落位语境；被测脚本只读零改动（发现缺陷停报告，不顺手修、不为通过测试改预期）；夹具全部构建于 mktemp 临时目录并 trap 清理（异常退出亦清），仓库零写入；预期值按被测脚本当前行为独立重建（cmp/逐一相等断言——不为通过测试改预期教训；来源票只作场景清单）。

### 用法

```text
sh scripts/test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
```

- 无参数：`--suite all`；被测脚本目录缺省＝本脚本所在目录，包根缺省＝被测脚本目录的上一级（check-package.sh 同款）。
- `--suite module-map|ticket-ops|progress|json-engine|check-package|append-only|check-artifacts|delivery-parser|stale-claims|lane-commit|ledger-append|checkpoint-write|record-store|authority-matrix|worktree|upgrade-check|absorption|health|shellcheck|install|dispatch-contract|workflow-contract|role-prompt|role-permissions|ticket-run|ticket-repair|project-dashboard|check-gates|docs-generation|governance-size|ticket-audit|merge|context-cost|dir-readme|adversarial|harness|fast|all`：场景参数化，缺省 all（全集以 `tests/test-runner.sh` 用法与枚举为权威）。
- `--suite fast`：短套件车道（`FAST_SUITES`＝`ALL_SUITES` 子集，日常回归目标 ≤180s）；重活（`ticket-ops` 全量、`ticket-audit`、`lane-commit`、`workflow-contract`、`shellcheck`、`merge`、`check-package`、`install`）只在 `all` 跑。子集包含关系由启动核对与 `self-check` 双向钉死。
- 环境变量：`TEST_SUITE_TIMEOUT` 单套件超时秒数（缺省 300，超时记 FAIL 行并继续后续套件）；`TEST_ASSERTION_FLOOR` 断言数下限（缺省仅 `all` 生效＝1100，显式设置时对任意车道生效）。
- 执行模型：每个套件在子 shell 中运行（套件内 `exit` 不终止整轮），断言经 `$T/journal.<name>` 回传父进程计数；`INT`/`TERM` 中断时先停子进程再清临时目录，按约定码退出。
- `--script-dir <dir>`：被测脚本所在目录（须含被测成员全集，权威清单＝`tests/test-runner.sh` 启动核对，含 `generate-module-map.sh`＋`module-map.rules`、`ticket-ops.sh`＋`generate-progress.sh`、`check-package.sh`、`check-append-only.sh`、`check-artifacts.sh`、`check-stale-claims.sh`、`worktree-add.sh`、`dp-load-rules.sh`；main-only 栅栏件 install.sh/export-payload.sh 不在核对清单，相关套件自行 SKIP）；对复制落位副本或被测脚本修改副本复跑时使用。
- `--pkg-root <dir>`：check-package 套件的包根，缺省＝script-dir 的上一级。
- `-h` / `--help`：打印用法。

### suite 覆盖场景表

| suite | 来源票 | 覆盖场景 |
| --- | --- | --- |
| `module-map` |  | 11 语言夹具正例（nodes 19／edges 50 逐一相等＋stdout 摘要计数）＋fp-v1 形状／稳定性／变更检出＋无源码纯文档仓正例（exit 0、nodes/edges 空数组）＋负例 2（规则表损坏 exit 2、非 Git exit 2，均零地图写入） |
| `ticket-ops` |  | 生成项目语境 open→take→flip 全链（索引／README 票表生成块／投影全文件逐一相等＋账本行数；updated_at／开票日期捕获后校验形状重建预期）＋收尾投影 `--check`＋新 NN 正开正例＋负例（重复 id／未知 id／账本键序违规／take 非 in_progress／非法状态值／索引排版破坏／N7 同 NN 异 slug 拒开／N8 畸形 id（个位 NN 段）拒开／N-r1 本体缺 complexity_reason 拒开／N-r2 本体 priority_reason 空值拒开／N-r3 本体文件缺失拒开，均 exit 1 零写入）＋行型正例四（lesson promoted_to=sop open 收录／replan 三键齐 open 收录／lesson promoted_to=none 枚举边界 take 收录／对照组既有五键 kind=change 行 flip 照旧——向后兼容）＋负例四（lesson 缺 promoted_to／promoted_to 越枚举／replan 缺 replan_undone／条件键序破坏，均 exit 1 零写入）＋actual_time 收口硬拦与无票账本行入口（独立夹具：flip 本体 actual_time 空值／字段缺失／本体文件缺失均 exit 1 指名票 id 与缺项；request 票 flip 不校验照旧 exit 0；ledger 键序违规 exit 1 零写入／合法行 exit 0 账本收录无投影再生／缺省根语境同款）＋open 本体 schema 全量校验正负例（独立夹具：正例二——最小 task 本体／request 本体各 exit 0 且索引落条目，合法面零回归；负例七——本体 id 越 pattern／complexity 越枚举／profile 越七维 pattern／blocked_by 条目越 pattern／含 schema 未定义字段（additionalProperties）／task 缺条件 required／verification oneOf 零命中，均 exit 1 零写入且报文指名字段路径）＋票表生成块断言（open/take/flip 不再手写 README：生成块重算后全文件逐一相等且块外文本逐字节不变；README 缺该票行 flip／该票行重复 take／残留漂移行 open 均 exit 0 且生成块按索引归一为恰 1 行、状态＝索引值；无票表 README open exit 0 且生成器显式 SKIP 零改写——`--check-readme` 模式本身的正反向归 progress 与 stale-claims 套件，本行不认领）＋七维 Profile reason 存储合同断言（独立夹具：合同单源 schema `profile_reason` 恰七键 D/B/I/U/S/M/O 禁额外键逐键非空＋协议存储合同与 verification reason 分立声明在场两正例；七键齐非空读取面校验通过正例；malformed 形态读取面四负例指名键——缺维度键／未知维度键／空白值／非对象；存量票无 `profile_reason` 读取面零命中照常通过正例——开票校验与读取校验分层；新 task open 缺 `profile_reason`／缺维度键拒开零写入两负例＋valid 正开索引落条目正例）＋状态跃迁门禁断言（独立夹具：take blocked_by 完整性门——missing blocker／未 done blocker 负例均 exit 1 零写入且报文指名 blocker id（missing 报索引零命中、pending 报其索引 status）、blocker 全 done 领取正例 exit 0 索引单写、带未 done blocker 的票 flip 照旧成功对照（门仅限 take 零误伤）；actual_time 收口 done 条件化——task flip 至非 done 无 actual_time 正例 exit 0 索引单写、done 缺 actual_time 负例 exit 1 零写入指名票 id 与缺项、request 票翻转豁免维持正例 exit 0）＋flip-index 索引单写代理断言（正例二——显式 status/updated_at 索引单写＋投影再生＋票表生成块派生且账本零变化＋其余条目行逐字节保留；负例六——缺 --status／缺 --updated-at／status 越状态机／updated_at 非 ISO 8601／携带 --ledger-line（exit 2）／锚点零命中，均零写入） ＋派发合同门分层断言（改判：缺 dispatch 节／缺阶段对象／越键／收口事实留空／空白值五形态 open 均 exit 0 且索引落 ready——开票不预填未来证据；contract-build 派发时点完整性门四例：无节票／缺阶段对象／缺 implementation.GOAL／review.TICKET_ID 空白均 exit 1 零 stdout，收口事实留空按「（收口时按实际写入）」标注渲染 exit 0；存量无节票 flip 读取面兼容正例 exit 0）＋状态单写与崩溃恢复断言（空索引首开 exit 0 且索引/README/投影一致；并发 8 轮双 open 零丢更新且索引恒合法 JSON；`TICKET_OPS_FAULT` 三写点注入 exit 70 后重跑同一命令收敛、README 行与账本行不重复；投影删除可重建与手改被检出/覆盖）＋并行 take 两张不同票正例（双方 exit 0、两条目均 in_progress、各自持有 updated_at、索引合法 JSON）＋记录层写锁断言（陈旧锁默认只诊断不自动夺——有界等待超时 exit 1 且报文含锁路径/持有者 pid/「仅诊断」、四载体零写入、锁原样；`RECORD_LOCK_BREAK_STALE=1` 与 `--break-stale-lock` 两条显式夺锁路径恢复；存活持有者有界等待超时 exit 1 且锁令牌原样未搬；夺锁后原持有者写点被令牌拦下零写入；嵌套继承 open exit 0 且账本行与独立 ledger-append 落行逐字节相等；主检与 worktree 锁目录同一物理路径且持锁期间两处 `git status` 均空；锁原语唯一实现断言＋三镜像件 cmp） |
| `dir-readme` |  | 目录 README 四段式契约校验：合规夹具 exit 0 且 stdout/stderr 双零输出＋`--dir` 限定正例＋生成块标记成对正例＋同目录单文件名存在正例（含 `true`／`--check` 裸标识符不校验）＋`N/A`（含带理由、大小写变体）正例＋`--rules` 覆盖排除面正例＋正文提及「成员／文件」但非表格正例＋「一行」「第 3 行」习惯用法正例＋普通两列表「检查项｜依据文件」正例；负例——缺段／超 25 行／成员表（`## 成员` 段＋「成员」「文件」「名字」表头三形态）／计数句九形态（`共 N 件`、`N 个脚本`、中文数字个脚本、`N 行`（含 `共 257 行`）、`三合同`、`3 份合同`、`2 个成员`、`3 份文件`、`5 张票`）／状态句／幽灵路径（含 `/` 与单文件名两形态）／生成块未闭合／子目录表头缺分隔行均 exit 2 且按新建夹具断言指名 `文件:行` 行号，规则文件缺失／损坏、目标不存在、`--dir` 目录不存在／目录内无 README、未知参数均 exit 2＋占位断言正例（HTML 注释内 `【填写：】` 不误伤、行内代码段与围栏代码块内不误伤）与负例（散文裸露仍 exit 2）；`--sync`——生成块前后逐字节不变（AC1）＋连跑两次第二次零差异且 exit 0（AC2）＋增行取子目录 README 职责句且既有行两格原文复用＋删行整行移除并逐行报告 `DEL`＋无生成块 `SKIP` 且字节不变＋未闭合／重复起始 exit 2 指名 `文件:行` 零写入＋围栏代码块内成对标记不算块（`SKIP`、字节不变）＋子目录名含 `|` 首格转义且复跑零差异；`--init`——四段骨架＋生成块包住自动子目录表＋占位未清 `--check` exit 2（AC3）＋手填占位后 exit 0 零输出＋目标已存在 exit 2 零写入＋目录名含空白 exit 2 零写入＋与 `--sync` 互斥 exit 2；`--check` 围栏内成对标记不判块、含 `|` 的转义行不误判幽灵路径、模板首格为根相对示例；`--help` 写明两模式、无生成块 SKIP 语义与空白限制；`--migrate-dry-run`——三形态判定（四列表＋手册节 → four-column、成员三列表 → member-table、无表格 → no-table）＋普通两列表不误判 member-table＋AC3 合规 README 零输出 exit 0＋判断文字整行原文搬运且逐字命中（`## 权威` 2 行／`## 读取禁忌` 1 行、未命中 0）＋四列件权威两行原样搬运＋超 40 行判断文字出 NOTE 点名行数且不截断（建议行数＝NOTE 行数）＋成员表与手册节逐段 DROP 且行范围覆盖表头至末行／整节＋预演零写入（目录树 sha256 前后一致）＋`SUMMARY` 给出形态计数与零写入 sha256 证据＋无 H1／表头残缺 exit 2 指名 `文件:行` 且零 stdout＋四模式互斥 `--migrate-dry-run` 与 `--check`／`--sync`／`--init` exit 2＋`--dir` 限定只输出指定目录＋默认摘要模式 ≤15 行且含形态计数／ZERO-WRITE／分类 NEEDS-CONFIRM 行、无 diff 正文＋摘要模式无迁移件双空输出 exit 0＋`--diff` 出逐件统一 diff 与 DROP＋`--diff` 单独出现或与 `--check` 同用 exit 2 并说明用法＋`--diff --check` 报错句内嵌模式名（`与 --check 同用无效`）且行尾无裸模式名＋`--help` 写明摘要／`--diff` 两种形态与 MIGRATE／DROP 报告行；`--brief`——四节固定标题且 exit 0＋目录清单给一级成员、文件行数与字节数＋判断证据按目录／成员／子目录内分组且 kind／authority／read_when 为 artifacts 原文＋AC1 目录清单集合等于目标目录一级成员（不含目录外成员）＋不带出目录外 artifacts 条目＋AC1 证据条目 id 可回查且路径作用域在本目录＋AC1 authority／read_when 原文照录（目录外指针保留、无屏蔽记号）＋AC1 现状 CHECK 回显的目录外引用原样输出＋现状报缺 README、生成约定含占位与 25 行预算＋artifacts 缺失降级为两节并 exit 0＋artifacts 不可解析降级且不静默＋负例任一条目缺 id／path 整索引降级不部分采用＋现状复用 `--check`（合规报「齐全／通过」、缺段报缺段与逐条问题）＋AC2 零写入（目录树 sha256 前后一致）＋AC3 连跑两次输出逐字节一致＋生成约定并输出一行 `DEGRADED:` 且 exit 0＋与 `--check`／`--sync` 互斥、缺值、目录不存在、带 `--dir`／`--diff` 均 exit 2＋`--help` 登记四节与降级语义；`--freshness`——干净生成块 exit 0 且双零输出＋新增子目录未入表 exit 1 报 `缺失行` 与 `SUMMARY` 计数＋删除子目录未删表 exit 1 报 `多余行`＋零写入（目录树 sha256 与 `docs/README.md` 字节前后一致）＋无生成块 README 静默跳过＋块未闭合 exit 2 指名 `文件:行`＋与 `--check`／`--sync` 互斥 exit 2＋`--help` 登记 `--freshness`／`--blocks-only` 与缺失行文案；`--check --blocks-only`——只校验含生成块的 README（旧格式成员表目录跳过，全范围 `--check` 对照仍 exit 2）＋单独出现按缺省 check 模式执行＋与非 check 模式同用 exit 2 |
| `progress` |  | 投影生成（乱序 id＋checkpoint_ref 列）全文件逐一相等、`--check` 一致 exit 0、篡改检出 exit 1、投影缺失 exit 1、索引缺失／条目行缺必备字段 exit 2；票表生成块 `--check-readme` 新模式四例——①有票表无标记 README 经生成器包裹为生成块（标记恰 2）、状态列按索引派生且块外逐字节不变；②未迁移版 exit 1 并指名「未迁移为生成块」；③手改块内状态 token 后 exit 1 报 `path:line` 与差异行；④无票表 README SKIP exit 0 且 README 字节零变化（不新建块） |
| `json-engine` |  | 唯一 JSON 引擎通用操作面正负例（json fields/get/type/len/pick/count-key 含 stdin、缺路径 exit 3、default 回退、顶层非对象 exit 2）＋ticket-check 三门（close request 豁免/task 空白拒；deps 未完成拒/已完成放行；open-body id 不一致拒）＋contract ticket-id 两形态（JSON 键/模板节）；json-helpers.sh awk 行解析退役后由本套件承接解析层行为回归 |
| `check-package` |  | 编号检查正例以清单派生的属性断言覆盖（每注册检查恰一行 PASS/FAIL、PASS 行数＝注册表项数、检查行前缀格式、首行与汇总行逐字、检查 1/8/19/20/21 行内计数与检查 13 核对件数＝清单现查值；检查 23 已退役无输出行；清单增长时计数自动随动，不再逐行复制整份输出）＋必需件缺失负例（mktemp 包副本删件）exit 1 指名缺失件＋检查 9 表实漂移联动＋检查 17 机械行点名脚本缺失联动（R-DP-004 点名 generate-progress.sh）＋检查 11 逐处全等负例（§2.5 单处删值，FAIL 行按行号指名）＋模糊措辞负例：检查 12 注入词表首词入规则块体 exit 1 指名文件:行号（词自夹具包 manifest 提取，harness 零词面字面量）、注入行登记行级豁免后不报 exit 0（豁免生效）、豁免登记行无命中报失效豁免 exit 1、检查 13 生成物核对四负例（N7 手改仓侧生成物→exit 1 指名生成物漂移；N32 仓侧生成物缺失→exit 1 指名缺件；N8 非源仓语境→静默无输出行；N33 package-only 仓侧同名实例→不判差异 exit 0）＋正例 P1 全量生成物＋过渡态实例→exit 0 且 PASS: 13 核对件数＝清单 mirror 现存件数＋能力映射负例：检查 14 注入未登记基元名入角色声明行 exit 1 指名文件、删除一基元名出角色声明行 exit 1 指名文件＋规则索引负例：索引删一行 exit 1 指名缺行、索引加全集外 ID exit 1 指名多行、机制列写未登记值 exit 1 指名、机械行点名不存在脚本 exit 1 指名、机械行点名检查项号超界 exit 1 指名、外定义行删标记词 exit 1 算漏行、mechanism-vocab 词表损坏 exit 2、票号禁令三例（.md 文档面注入票号引用 exit 1 指名文件:行号；注入行登记行级豁免后不报 exit 0；豁免登记行无命中报失效豁免 exit 1）＋mode 断言三例（检查 19：非 git 副本语境静默跳过无输出行 exit 0；git 夹具语境 kind=script 置 644 且 kind=rules 置 755 exit 1 双断言同报指名期望 mode）＋闭合性三例（检查 20：scripts/ 一级未登记额外件含隐藏条目 exit 1 指名条目；symlink 混合面——scripts 外指 symlink 与 references 断链外指 exit 1 外指/别名双报；非 git 语境检查 20 照常运行 exit 0 且 PASS: 20 有输出行）＋references 闭合导航四负例（检查 21：子树新增未登记文件 exit 1 指名条目；已登记成员删除 exit 1 且 FAIL: 1 指名缺件；坏相对链接注入 exit 1 指名文件:行号与目标；一级新增目录未入 README 目录清单投影 exit 1 双报）＋检查 13 生成物核对组（源仓语境＝仓侧 rules/implementation/scripts/ 在场，消费项目整组 SKIP；夹具 mktemp）＋规则块格式与序言指针组（检查 22/23：三宿主 §16 序言逐字等于 R-GF-011 定稿短指针正例各一（锚点检测零宿主名硬编码）；缺九字段——删 Forbidden 行 exit 1 指名 ID 与缺失字段；非法 Level——改自造值 SHALL exit 1 指名 ID 与标题；重复 ID——整块复制 exit 1 指名 ID 与两处行号；序言多行散文 exit 1 指名模板与散文行；序言换第二权威指针 exit 1 指名模板与原文；序言整行删除 exit 1 缺短指针；权威文件缺失——governance-format.md 移出包外 exit 1 且 FAIL: 23 指名缺失件＋汇总行出现＋零 unbound variable（n_hosts 未初始化假绿回归钉死））＋待定规范声明检测三例（检查 25：MUST 块注入【待定】来源行 exit 1 指名文件:行号；命中行带 pending-decl-exempt 行内豁免标记 exit 0 且豁免计数 1→2；标记行无命中报失效豁免 exit 1）＋适配器注册表闭合八例（检查 26：加载段负例二——platform-enum 节删宿主值 exit 2 fail-closed 零部分结论、注册表追加重复短码行 exit 2 指名跨行短码；检查段负例六——注册表删宿主注册行 exit 1 指名枚举宿主值缺注册行、删注册表适配器文件 exit 1 指名缺件、shortcodes 节删镜像行 exit 1 指名失对、capability targets 节删 table 行 exit 1 指名镜像缺口、父 README adapters 行漏列平台 exit 1 指名缺少、目录 README 投影行缺短码 exit 1 指名）＋适配差异数据表一致性四例（检查 27：数据侧单处篡改——改数据不改文档 exit 1 指名宿主与段与首个差异行；文档侧单处篡改——改文档不改数据 exit 1 指名宿主与段；方言签名锚语删除 exit 1 指名失据锚语与 key；capability-map 节追加重复（platform, primitive）行 exit 2 fail-closed 零部分结论且指名跨行重复）＋适配差异数据表平台全集两例（删单平台 exec 行／删单平台 dialect 行 → exit 2 fail-closed 零部分结论且指名段与宿主）＋宿主差异段生成链路十二例（检查 27/28，逐字节口径含强调记号与列数守卫：正例 G1 生成器 cap 首行逐字节等于宿主对照表首行；正例 G2 现行包 `--check` exit 0 且计数汇总齐；正例 G7 数据与文档同批同步 exit 0 零假阳；正例 G8 强调记号行（claude-code execute）渲染结果与宿主原文逐字节相等；负例 G3 数据侧单处篡改生成器 exit 1 指名宿主与段；负例 G4 同一篡改经 check-package FAIL: 28（接通断言）；负例 G5 文档侧单处篡改生成器 exit 1；负例 G6 方言锚语删除生成器 exit 1 指名段；负例 G9 数据侧强调记号丢失生成器 exit 1；负例 G10 文档侧强调记号丢失经 check-package FAIL: 28；负例 G11 宿主 role 行多一列生成器 exit 1 指名 role-map；负例 G12 同一夹具经 check-package FAIL: 27 指名 role-map（列数非 3 两引擎同口径不截断））＋包级语义一致性八项（检查 29～36，各八正例一行逐字在场＋单点注入负例指名文件/条目、规则与冲突类型）：P29～P36 现行包 PASS 行逐字在场；N64 活动面注入未标注退役 token（`:行号`＋token）；N65 transition 目标改未声明 state（TO「missing-state」）；N66 删 state 票映射（state「failed」）；N67 enforcement 目标声明面降级为 reference（双向闭合缺口）；N68 非适配面 MUST 块注入【待定】（文件名:行号）；N69 README 自任唯一契约（文件:行号＋contract-pointer）；N70 适配器归属短码未入注册表（shortcode-closure）；N71 fixture 去掉非生产标记（workflow-positioning） |
| `docs-generation` |  | 规则索引生成器回归：现行包 `--check` 零漂移 exit 0；手改索引一行 → `--check` exit 1 指名差异；新增已登记机制的块 → exit 1 指名缺行；新增未登记机制的块 → exit 2 fail-closed；生成索引含全部十条 R-CO；`--check` 零写入（模板逐字节不变） |
| `governance-size` |  | 安装面预算回归：9 件逐件字数上限 + 合计 ≤30000 + 安装面规则块恰 10 + G 覆盖 + 每阶段读取集 ≤15000 + 隔离门槛在位 + 九件零模糊措辞与零待定标记（实测值超限即 FAIL 并打印实测与上限） |
| `check-artifacts` |  | check-artifacts.sh 正负例：全对账正例 exit 0（含懒创建面登记暂缺 SKIP 行与豁免命中不报）、登记目标缺失 exit 1 指名条目、受管文件未登记 exit 1 指名路径、豁免目录内未登记文件 exit 0 不报、校准豁免迁移三例（delivery.rules 声明 dp_artifact_exempt → generated 不报 exit 0；无 delivery.rules → 豁免消失按未登记 FAIL；delivery.rules 解析破坏 → exit 2）、登记解析破坏 exit 2 指名行与条目、无参数／repo-root 不存在 exit 2；host-config 断言组：dry-run「将修改（项目外）」分组与 sha256 零写入、写入备份与复跑幂等、人工改块 exit 1 且文件不变、--write 缺 --confirm／非法键／空值／未知参数 exit 2、host-profile 四列文档与 kind: adapter 双向对账 |
| `authority-matrix` | 权威矩阵合同 | read-policy §2.3.1 权威与写入边界矩阵一致性断言（六组 authority/writer/resolution 与模板引用双向相等）。 |
| `delivery-parser` |  | delivery.rules 共享解析器单源一致性与正反例：四消费件静态单源断言（零内嵌 `dp_load_rules` 定义＋同目录加载＋最低版注记）＋解析库形状（恰一定义＋恰一版本来源）＋文法说明↔解析库元数据机械核对（指令全集恰 8 两源逐一相等、锚点表恰 4 逐字命中、版本行与 DP_PARSER_VERSION 相等）＋安装政策闭包登记断言（fast-lane ip_file）＋合法四节文法全链 pass（worktree-add 栅栏化创建真跑）＋同一 rules 文件探针逐件采集 DP_* 结论两两 cmp 相等＋结论内容逐项预期（防全空相等）＋负例三组逐件指名失败（畸形文法 exit 2 不产生部分结论、缺解析器、版本漂移；export-payload 分项栅栏不在场时显式 SKIP 覆盖归主检出） |
| `stale-claims` |  | check-stale-claims.sh 配置点亮正负例：未点亮（无 delivery.rules）→ S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 5（通用条数 S3/S4/S5/S6/S7）；点亮（dp_stale_lit S1＋S2 无 payload 节）→ 无 SKIP 行、断言逻辑执行（STALE 行证明）、汇总登记数 7（点亮数＋通用条数）；delivery.rules 解析破坏（未知指令）→ exit 2 指名违规行；S5 正负例四（git 基线提交承载向前生效）：新增面结论行标注齐（file:＋轨:）→ exit 0 零 STALE；新增面缺标注（列表标记变体）→ exit 1 STALE 指名 文件:行号；存量已提交无标注、工作区清洁 → exit 0（存量不回溯）；修改面追加缺标注行 → exit 1 指名追加行、基线标注行不报；S6 终态哨兵正负例四（git 基线提交承载终态史）：终态索引（done/superseded 各一）过 S6 → exit 0 无 S6 STALE；done 票改回 in_progress → exit 1 S6 STALE 指名票 id 与跃迁方向；superseded 票改回 ready → exit 1 同款指名；终态史照旧（done 保持 done）＋非终态票流转 → exit 0 零误报；S7 替代标记正负例四（git 基线提交承载，索引/README 锚点/投影三面自洽覆写单变量隔离）：有效标记（superseded 票指向索引内 done 票）→ exit 0 零 S7 输出；悬挂标记（指向票不在索引）→ exit 1 STALE 指名双方 id；缺字段（存量形态无标记）→ exit 0 零 S7 输出（零回扫）；非终态指向（替代票未收口）→ WARN 提醒先标后收、零 S7 STALE；缺省根推导回归三例（按落位形态锚定防回潮）：rules/implementation/scripts/ 落位无参裸跑 → exit 0 零 STALE 且与显式传参输出逐字节一致、agent-up/scripts/ 落位无参裸跑 → exit 0 零 STALE、未知落位无参裸跑 → exit 2 fail-closed 指名推导失败；S4 扫描覆盖正负例九（扫描面声明实证＋四类例指名）：计数陈述与实际相等 → exit 0 零报、漂移 → exit 1 STALE 指名双侧计数；扫描面深层路径与 artifacts.yaml 命中逐行指名（遗漏防线）；排除面 prune（票面/runs/生成投影）与 case 跳过（冻结档案/账本冻结件/现役投影）、非 md、facts 外（rules 树/仓根）同文零报（误报防线＋扫描范围边界：rules 树不在扫描面）；词表甲乙两臂＋五量词六行逐一指名（假阴性防线）；检查 12 模糊措辞六词入扫描面零报、措辞与计数同文件异行分立仅计数行指名（词表语义分立非等价不互扫）；显式豁免恰行免报非豁免照报、行号漂移不罩他行、缺理由 exit 2 fail-closed（豁免注入只改夹具 eng 副本 heredoc，被测对象本体零改动）；S4 生成块新鲜度两例——生成块等于索引派生 exit 0 零报文、手工改块内状态 token exit 1 STALE 指名生成块与索引派生不一致 |
| `lane-commit` |  | lane-commit.sh 微账本 actual 键正负例（git 夹具承载两段式全链）：micro 合同带 actual 行 → exit 0 且微账本第七键 actual 落值；合同不带 actual 行 → exit 0 且 actual 落空串（既有六键行向后兼容，键序不变）；actual 行重复 → exit 1 零提交零写入；user-review 道携带 actual 行 → exit 1（用时落票本体 actual_time）；actual 行含制表符 → exit 1（JSON 行安全）＋索引翻转代理断言（P-json 全链护航代理路径——索引单写＋投影再生经 ticket-ops flip-index 承载；代理不在场收尾预检停止零提交零写入负例）＋记录写入职责拆分断言（micro 道经 ledger-append --micro 落行且代理定位行在场；user-review 道经 checkpoint-write 落记录块且目标文件契约行在场；两代理分别缺席→收尾预检停止零提交零写入；ledger-append --micro 原子层契约直测三例——--check 零写入／--commit 非 sha exit 1／与 --ledger-line 混用 exit 2）＋记录面收编票表生成块（索引翻转后 README 由生成器派生并随记录提交收编，合同侧通用翻转目标与新生成块共存） |
| `ledger-append` |  | ledger-append.sh 正负例（changes.jsonl 唯一写入方）：五键行显式根追加、`--check` 零写入预检（合法行校验通过且账本逐字节零变化）、lesson 六键／九键（三分数键含 -1=N/A）、replan 八键、账本懒创建、紧凑 JSON＋rules 布局缺省根裸跑、agent-up/scripts 布局缺省根裸跑；负例九——缺 --ledger-line、裸换行、未知键指名、lesson 缺 promoted_to、promoted_to 越枚举、replan 条件键非布尔、唯一 JSON 引擎缺席 fail-closed 指名、未知参数 exit 2、仓根不存在 exit 2，均零写入；`--micro` 微账本行模式契约（--check 零写入、字段越界 fail-closed、与 --ledger-line 互斥）由 `lane-commit` 套件直测覆盖；并发互斥两例——20 进程并行独立调用零丢行且每行与输入逐字对应（相对起点恰增 20 行）、并发追加后历史行逐字不变（种子前缀 cmp）且 `check-append-only` 通过；锁断言两例——独立调用（非 --check）遇存活持有者的锁有界等待超时 exit 1、账本零写入且报文含锁路径与持有者 pid，pid 缺失且锁龄超阈值默认只诊断不夺锁（超时 exit 1、账本零写入、锁目录与令牌原样） |
| `checkpoint-write` |  | checkpoint-write.sh 正负例（User Review Checkpoint 唯一写入方）：`.md` 票追加票尾（原内容前缀保留＋记录块五行）＋stdout 末行目标文件契约行；`.json` 票体逐字节零追加＋独立 checkpoint md 创建（一级标题＋记录块）与二次写入追加；负例——缺 --verdict-quote exit 2、票文件不存在 exit 1、绝对路径 exit 1、--date 越界 exit 1、未知参数 exit 2、无参数 exit 2、未知子命令 exit 2，均零写入；记录层写锁接线两例——AC1 独立调用自取锁：持有者经 `RECORD_LOCK_TEST_HOLD_MS` 放大持锁窗口，第二方 exit 1 报文含「并发冲突」且票体零写入、锁未被搬走；AC2 继承路径：父进程持锁以继承标记调用 exit 0，子进程退出后锁目录仍在且令牌原样（父锁不被释放），父进程释放后锁目录消失 |
| `record-store` | 272 | record-store.sh 记录层写面 module 正负例：`record_path` 六类记录路径逐一相等＋未登记键 exit 2；`record_write` 整文件原子替换逐字节等于内容件、同目录临时件零残留、目标缺失原子首建；`record_append` 追加落尾且历史行逐字节保留、micro 懒创建；`record_set_json` 票本体 `checkpoint.commit` 逐字节等于金样（indent=2＋末尾换行）、引擎缺失与非法 JSON 值两类 fail-closed 零写入；三类负例 fail-closed——绝对路径与 `..` 段越界、记录文件与父目录 symlink 外指（仓外文件零写入）、追加窗口内记录被改写时前缀断言失败 exit 1；独立调用自取写锁并在写入后按所有权释放（锁目录零残留）。 |
| `append-only` |  | check-append-only.sh 正负例：changes.jsonl 尾部追加 exit 0（OK 行含追加计数）、micro.jsonl 同口径追加＋progress.md 零 diff exit 0、中间插入 exit 1 指名文件与首个违规行号、改写历史行／截断／工作树删除 exit 1、progress.md 篡改 exit 1、micro.jsonl 中间插入 exit 1（同口径）、无 Git 基线 WARN 退出 0、懒创建（新建账本 OK＋缺失 SKIP）exit 0、用法负例（无参数／多参数／非 Git 目录 exit 2）、迁移承继三例：迁移窗口 exit 0 双 OK（已迁移＋迁移承继）、迁移落位稳态 exit 0（后继 OK＋旧路径 SKIP）、承继不一致 exit 1 双 FAIL（后继新内容＋旧路径缺失） |
| `health` | 会话健康汇总 | health-summary 四分区汇总正反例（打分/候选/报警/对账，含零写入复核与错误传播）。 |
| `absorption` | 吸收触发扫描 | absorption-trigger 吸收候选触发面正反例（PROMOTE 候选判定与零写入复核）。 |
| `worktree` |  | worktree-add.sh 栅栏化创建正负例（主检出语境）：正常创建→exit 0＋排除路径物理不在场；链接 worktree 内运行→exit 1 自拒；分支名不合 ticket 形态→exit 1；main-only 节缺失→exit 2；合同入口正负例（JSON 与委派合同模板两形态：传合同文件即建站、分支与站路径自 TICKET_ID 派生且栅栏同效；缺 TICKET_ID／形态不合→exit 2 指名）＋完成行依赖准备提示（提示 worktree-deps.sh 与站路径）＋worktree-deps.sh 依赖隔离正负例（mktemp 夹具＋假 npm 零网络：两 worktree 并行准备→各自真实独立 node_modules 互不影响；根与 workspace 的符号链接 node_modules→exit 1 指名路径零安装；workspace 的 package.json 缺失→安装前 exit 1 指名零安装；非 npm 仓库→SKIP exit 0；workspace 命中普通文件静默跳过、简单 brace `{a,b}` 展开匹配、多组/嵌套/未闭合/range 显式 exit 2；worktree-add 同目录缺 worktree-deps.sh → 打印「未随附」且 exit 0；克隆加速显式开启播种／默认关闭不播种／`--clone-accel` 与 `--clone-from` 互须 exit 2；未知参数与目标根不存在 exit 2） |
| `upgrade-check` |  | modern 全布局；规则块缺失报具体 ID、多余块提示分歧候选；manifest Conditional README 已生成时存在性核对、目录未生成时 N/A、目录已生成而 README 缺失时报落后；delivery.rules 未启用 N/A、快道专属脚本已装而配置缺失报落后、票务道共享脚本不点亮快道（P6/N6）；ip_data 数据件三态核对（同步 exit 0／缺失报落后／内容不同报漂移，P7/N7/N8）；旧布局脚本与 docs 条件 README 兼容；双布局冲突且逐份 cmp；单路径歧义 fail-closed；新旧治理面 mixed 明示 |
| `shellcheck` |  | 脚本质量门禁面（静态分析）：被测目录全量 .sh 零告警（含 sh -n 同源面之上的风格与语义告警）＋豁免有证断言——`# shellcheck disable=SCxxxx` 指令须同行带理由注释，无证关检查即 FAIL 指名文件:行号；环境缺 shellcheck 时套件零断言跳过（NOTE 行明示，不制造假绿） |
| `install` |  | install.sh 非执行式规则表解析正负例（合法表双门控安装全链＋幂等重跑零写入＋规则表缺失/结构破坏/恶意输入四形态 rc=2 零写入）＋安装后运行时依赖闭包（minimal target fixture：`--ticket-ops` 安装到干净临时目标后真实执行已安装 ticket-grade 与 ticket-ops open 并读取已安装 schema/profile——索引落条目且投影再生；missing-validator 与 missing-data 负例真走失败路径：运行时消费点删依赖指名 json-validator.py/ticket-record.schema.json、安装预检删依赖 exit 1 指名复制源缺失路径、包副本删 validator/schema/profile 由 check-package exit 1 指名缺失路径）＋共享解析器安装闭包三例（R4 `--fast-lane` 安装 dp-load-rules.sh 落位与包基线字节一致；R5 已安装 worktree-add 真实执行解析通过后未声明 main-only 节拒跑 exit 2 指名；R6 合法四节 rules 栅栏化创建 exit 0 且 main-only 路径物理不在场）＋安装后完整性四例（P1b 全部可执行脚本 --help 冒烟 exit 0；R7 全新 Seed 治理面 → check-artifacts PASS；R8 安装 ticket-ops 的 Seed 项目 → upgrade-check exit 0；R9 安装布局 run-record new＋seal exit 0） |
| `dispatch-contract` |  | check-dispatch-contract.sh 四模式正负例：`--check` 正例（implementation 型全 16 必备字段合同 → exit 0）＋缺失字段负例（去 ACCEPTANCE_CRITERIA → exit 1 且逐名报出）＋类型推断负例（无特征字段 → exit 1）＋review/commit 两型必备字段正例（各 exit 0）；`--check-template` 零漂移正例（exit 0）＋漂移负例（模板副本删一占位符 → exit 1 指名差集方向与字段名）；包闭合负例（mktemp 包副本删已登记 schema/checker 件 → check-package exit 1 指名缺失件）＋contract-build.sh 渲染器正负例：键集单源守卫正例（ticket-record.schema.json dispatch 三阶段 required 集与 dispatch-contract.schema.json contract_fields 三阶段逐一相等）；implementation/review/commit 三阶段渲染正例（票 dispatch 节全键 → exit 0 且 stdout 含该阶段全 {{KEY}} 行块，产物再过 check-dispatch-contract --check exit 0——自校验闭环）；负例（无节存量票渲染 exit 1 零 stdout／缺必备键 exit 1 零 stdout／空白值 exit 1 零 stdout／stage 非法 exit 2／NN 段零命中 exit 1 零 stdout）＋`--check-dispatch` 派发前置正负例（临时主仓＋linked worktree＋索引 in_progress/ready 两票：linked worktree＋in_progress exit 0；主检出路径 exit 1 指名主检出；status=ready exit 1 指名状态与 in_progress 要求；索引无条目 exit 1 指名未领取；非 Git 目录／相对路径／工作树子目录／合同缺 REPOSITORY_PATH exit 2）＋五宿主 execute 行 git_write_enforcement 登记面正负例（生产五宿主受控词表与降级义务；合成 host-enforced 带机制 token 通过、无机制与越词表值指名失败、实现模板删 git_write_enforcement 指名失败）＋`--check-step-budget` 步数预算正负例（含步数上限与到线收尾的合同 → exit 0 且 PASS 行；缺步数上限／缺到线收尾表述／上限为空／上限非数字四类各 exit 1 并逐类指名；合同文件缺失 exit 2） |
| `workflow-contract` |  | workflow schema/实例/执行子集合同正反例：包内 `references/workflows/` 两实例与基底夹具过同一 schema 子集校验（负例对照基底先行）；checkpoint sidecar 夹具过合同校验＋与实例 checkpoint_field 交叉核对＋executor `--resume` 运行时接受（已完成步跳过、待执行步执行）；checkpoint_field 的 schema pattern 与 executor 运行时正则语料级等价；executor 写面记录恒六键（三键基础 step_name/completed_at UTC/outputs＋三键结构化结果 status/exit_code/verification_results）逐键一致＋票指针固定 sibling 引用＋写出记录被 `--resume` 回读接受；实例执行分类（triage 五步全 executable、implementation 2 agent fail-closed＋2 executable）；fixture 定位合同（两实例入口名带 `-fixture` 后缀且不与生产入口 triage/implementation/review 同名、描述首句声明「参考 fixture（非生产）」、步骤命令与验证项零固定路径写入——/tmp、绝对路径重定向、fixture 内 mktemp 均拒）＋同名副本负例（入口名改回 triage 须非零退出并指名与生产入口共用）＋triage fixture 隔离 cwd 端到端跑通且零新增文件＋implementation fixture 的 agent step 经 executor 在任何 sidecar 落盘与步骤副作用之前 fail-closed（exit 非零、零 sidecar、票零改动、报文指名适配器缺失）；schema 负例八（inputs 序列形态／步骤类型越 enum／缺必备字段／额外字段／checkpoint_field 越 pattern／expect_exit 越 maximum／缺 state_machine／oneOf 零命中，均指名拒绝原因）；unsupported-step 负例（exit 非零且先于副作用——探针未执行、零 sidecar、票零改动，报文指名 agent 适配器缺失） |
| `role-prompt` |  | 角色合同/Prompt 权威边界正负例（单一合同权威——角色合同模板承载 MUST 与权限正文，派发 Prompt 只承载参数/上下文/输出槽）：四件角色合同模板权威面正例（能力声明行＋规则块在位，含 Triage）＋现行三件 Prompt 零合同正文边界扫描＋Triage 模板登记闭合五断言（实物＋清单 pm_template/pm_shortcode 数据行＋templates/README.md manifest 与短码投影行）＋占位符全集零漂移（--check-template）＋负例四：duplicate-body Prompt 夹具（复制白名单/规则正文进 Prompt）扫描器失败指名角色文件:行号、duplicate-rule 角色合同夹具（整块复制 R-RT-001）经 check-package 检查 22 失败指名 ID 与角色模板、missing-permission 角色合同夹具（删 readonly-execute）检查 14 失败指名角色模板、Triage 缺权限声明夹具结构断言指名 missing-decl；parameter/context/output-only 对照 Prompt 夹具通过（零误报防线）；能力收窄面正例（四件合同声明与执行能力一致：triage execute 白名单与 --check-dispatch 派发前置口径／impl 不含 vcs-write 且保留 git_write_enforcement 降级义务／review 只写审查证据且无零文件改动旧表述／commit 仅 inspect、execute＋ticket-run 编排入口；capability-contract §2.2 与五宿主 §2.3 投影同口径）＋负例六条（N7 triage 声明删 execute／N8 commit 声明注入 vcs-write／N9 review 恢复零文件改动／N10 impl 删 git_write_enforcement／N11 commit 引入白名单外脚本／N12 triage 派发前置去掉实现阶段限定，均指名角色失败）＋R-RI-005 步数预算与到线判据（P11 三份角色模板各一：规则块在位＋步数上限 80＋到线收尾＋交接摘要要素＋豁免须写理由与上限值＋无不可判定措辞；N13 删规则块／N14 步数上限改空或非数字／N15 删到线收尾或交接摘要要素／N16 豁免缺理由或上限值／建议·尽量等措辞，均指名失败） |
| `ticket-run` |  | 同一带 dispatch 节夹具票真实走完 implementation 建站与两行输出、review 合同复用、commit 缺 Review/最终 FAIL 零提交两负例、结论位负例（首行 fail＋PASS 证据行、`Verdict: FAIL`＋PASS 证据行、仅证据行无结论、仅 `PASS:` 证据行均零提交）、存量格式 `- 评审结论：**pass**（注记）` 兼容正例、Review PASS 后产品/记录两段提交＋索引投影；独立 Review 文件入产品提交且不伪造 User Review Checkpoint；commit 不在 `$TMPDIR` 留合同文件；非法 stage 负例与两个编排器的原子层静态边界；可恢复协调器五子命令（repair 见 `ticket-repair` 行）——next 只读零写入、start 建站＋领取与重跑幂等、start 遇栅栏缺失（core.sparseCheckout 未设）返回 decision-required 且不写 intent 与载体、建站后崩溃重跑补记 worktree done、contract 两行、record 合法收据落位/同内容收敛/不同内容 decision-required/越枚举 verdict/缺必备字段/额外顶层键/notes 非字符串/schema_version 字符串/acceptance 项额外键拒绝且主检出＋站内四载体不变、收据常量与 schema 单源核对、record 落位后崩溃按实态判完成且收敛分支补记 done、本地/UTC 跨日重跑 start 账本仍一行、verify-dispatch 一致通过/合同缺失/合同漂移/缺阶段对象三类拒绝、崩溃注入后 next 报恢复且 start 重跑收敛、站路径被普通目录占用返回 decision-required 零写入、站内 0 文件（status 有 ` D ` 删除记录）与 sparse 配置只有 `/*` 无 `!` 排除规则两类假阳性均 decision-required 零写入、空索引站（`D ` 暂存删除＋ls-files 空，mock 在 sparse set 后 read-tree 前返回）指名未物化且不领取、新建站主路径栅栏未生效不领取、源收据清理后按目标证据＋intent kind 判 record 完成、四载体比对器变异自检、`-h` 五子命令与包内登记、残留 take intent＋索引 done/review_pass 时 next 判 decision-required 且不提示 start（C11b 期望 exit 1）、索引 ready 时 next 给出 start、`next --clear-intent` 先打印原内容再清已判不可收敛的残留、残留仍可收敛时拒绝清除并保留 intent；记录收口段单一锁窗口断言（ticket-ops 包装器观测 flip-index 收到 `RECORD_LOCK_INHERITED=1` 且父锁在场、python3 垫片观测 `checkpoint.commit` 内联写入时同一锁目录令牌仍归父进程、段末锁目录释放） |
| `ticket-repair` |  | repair 四类纠偏动作与票定位回归（夹具：mktemp 票仓，索引一条目一行）：AC1 缺站＋投影缺失 → 补建站并重建投影（`repaired`），二次 repair 收敛为 `converged`（零新提交、四状态载体 cksum 与投影不变、intent 不追加）；AC2 有实现提交无收据 → `pending-review`（exit 0，零收据），索引 `review_pass` 无收据 → `decision-required`（exit 1，不伪造结论），无站 done 票且主仓无收据 → `decision-required`（不判 converged），无站＋main 直提仍检出 1 件并 `decision-required`；AC3 main 直提 → 检出 1 件、打印 cherry-pick 建议并明拒 rebase/amend/force-push，main 与票分支 OID 不变；AC4 收据在场时 contract-build／ticket-run contract／verify-dispatch review 均 exit 0 且渲染票本体，同 NN 两件真实本体 fail-closed 逐件指名，commit 缺 Review pass 零提交；AC5 包侧与仓侧 contract-build／ticket-run 镜像 cmp 零差异；`--audit-recheck` 复跑 ticket-audit 前后逐字一致、十一谓词 PASS、HEAD 不变 |
| `role-permissions` |  | check-role-permissions 角色归属与新建文件豁免正负例（仓侧脚本＋仓侧夹具逐件经 stdin 送入）：只改 dispatch.implementation 与 dispatch.review 的 ready 票体 → exit 0（旧实现按缩进把 dispatch 子键误判为 checkpoint 跨角色）；默认上下文（hunk 内无 `"dispatch": {` 锚点行）只改 dispatch.review 与 dispatch.commit 字段 → exit 0（按 hunk 起始行号读真实票体回溯顶层键，不再回落 checkpoint）；checkpoint 跨角色、只读字段删除行（title/id）、status 无 checkpoint.commit 三类既有拒绝路径逐件 exit 1 且报文指名；批内一件新建票文件＋一件 checkpoint 跨角色修改的混合 diff 仍 exit 1（新建豁免只作用于该文件自身），单独一件新建票文件 exit 0；消费项目语境缺件显式 SKIP，夹具 mktemp 零写入 |
| `merge` |  | 合并站证据门正负例：无绑定 worktree/未提交证据 → 拒绝合并 decision-required（exit 1，worktree/分支保留）；actual_time 仅在票分支（主检出缺失）→ 仍合并放行；分支 tip 含合法 Review Checkpoint md → 允许集与 done 门同源放行；审查后产品又提交 → P04 点名拒（P02 通过）；证据后仅记录面派生件提交（`changes.jsonl`＋`tickets/README.md`）→ P04 放行、合并成功；head 重绑但 diff_sha 未重算 → P05 点名拒（P02/P04 通过）；conformant 证据 → 合并放行（ff/no-ff 模式与提交哈希打印）并强制清场（worktree remove --force＋branch -d，含站内残渣）；未合并分支/主仓不干净/参数形态负例；安装闭包 fast-lane 真跑（merge-ticket＋ticket-audit 落位与包基线字节一致） |
| `project-dashboard` |  | 本地项目仪表盘常驻回归：静态单文件面（无外部脚本/样式引用）＋不可信文本零 HTML 注入面＋零网络 API＋零写入/删与 readwrite 面＋`mode: 'read'` 只读授权＋核心块与测试钩子在场；Node 抽取运行核心逻辑——能力检测与不支持提示／`pickDirectory` 传 `{mode:'read'}` 且缺 API 拒绝／JSON 与索引解析（畸形与缺 id 逐项报）／Markdown 与 JSON 卡片解析（标题、状态、复杂度、对象形态验收、缺字段提示）／状态合并以索引为准并记录正文冲突／全部卡片无遗漏与孤儿索引条目／地图节点边一致与未解析引用／缺失地图声明不重建／损坏与读取失败逐卡指名且不影响其他卡／不可信文本纯文本保留与转义／布局确定性／搜索与状态筛选／快照增量不改输入／自动刷新数据源（每轮重新读取、内容变更、新增与删除文件、单文件读取失败、空目录）＋指纹稳定与变更检出＋核心零写入能力＋页面文件逐字节不变；公开包登记断言（清单 scripts 节、README 成员表、安装政策 ticket-ops 行、runner 派发表）＋安装闭包真跑（登记行复制一件且与基线一致）与缺源件预检负例；搜索按生效状态与索引失败降级两组断言（worktree 栅栏环境 install.sh 不在场时，两条安装闭包断言显式 SKIP） |
| `check-gates` |  | check-gates.sh 验证执行边界正负例：合法只读验证 exit 0 且既有 PASS/汇总行格式保持；五类越界写——新建未跟踪文件（exit 1 指名文件、保持现场、同批后续 verify 输出 SKIP 且不执行）、删除跟踪文件、修改索引（git add）、创建符号链接、改写已修改文件（git status 行不变仍经内容哈希检出）；allow-output 目录内产出 exit 0 且工作区只留白名单改动与允许输出、既有产物复跑按允许输出放行；allow-output 含跟踪文件或路径含 .. → exit 2；record-only + verify N/A 语义不变 |
| （仅 all）注入自检 | 258 | 临时副本上按四类代表面各注入一处：规则表 label 破坏（`module-map`）＋产品脚本首行 `exit 0` 假绿（`ticket-ops`/`ticket-run`/`check-package`，后者在 worktree 栅栏内显式 SKIP 归主检出）；每个目标三断言（整轮 exit 非零＋含 FAIL 逐项行＋仍有套件汇总行），另含未注入对照与套件名三向一致（ALL⊆用法行、FAST⊆ALL、用法行⊆ALL∪{all,fast}） |
| `ticket-audit` |  | 证据审计引擎十一谓词正负例：正例 analyze/read/merge 三面 conformant 且十一谓词逐行 PASS、证据位置 `路径@提交:blob` 与 `git log`／`rev-parse` 逐一相等；负例按谓词分离——P01 证据缺失／非 review 收据／票号不匹配（P01 短路），P02 提交后又改动／未提交（HEAD 未跟踪），P04 证据之后混入产品改动（指名路径）与 head 非祖先，P05 diff 指纹篡改（按行号指名）／base==head 零实现 diff／base≠head 但两提交树相同（空 diff），P09 旧 PASS 与 reviewed_at 越界，P10 自由文本 verdict／FAIL verdict／PASS 含未知验收，P08 自签与策略实现者名单命中；未知分支——P07 身份不可佐证（author 不一致／不在可信名单）与 P11 策略缺失／非法 effective_from／不适用／发布基线标签缺失（analyze exit 0 且 merge/push 拒绝）；用法与环境错误 exit 2；一次审计零写入（文件 cksum 与 HEAD 前后一致）；P04 允许集三例——显式允许记录载体 exit 0、未传入时同改动 exit 1 指名 index.json、产品文件与允许集外 facts 文件仍 FAIL 指名路径；批量/推送面——无绑定收据的 merge 提交 exit 1 并指名票 id 与 P01、有绑定收据的 merge 放行、ff 单亲按 head 树索引 status 兜底（done 放行／in_progress 与未登记拒绝）、票 id 不可解析拒绝、全 conformant 与空区间 exit 0 且逐提交判定行、base 非祖先／非法 range／超 --max-commits／--skip 短 sha／range 未配 push 各 exit 2、--skip 输出 skip 行且不改变其他判定、批量面零写入 |
| `context-cost` |  | 成本度量复测器正负例（mktemp 夹具）：会话模式合成 `wire.jsonl` 夹具逐项相等（raw／cache_read／input_added／output／context_per_call／每步工具调用数／超 2 万字符结果数／超 250 步 agent 数／calls）＋给基线 JSON 逐项差值与变化率＋未知字段容忍、坏行跳过、缓存字段缺失按 0＋负例（样本低于阈值、0 条 `usage.record`（默认阈值）、会话路径不存在、目录无 `wire.jsonl`、基线文件缺失、基线缺指标——均 exit 非 0 且零 stdout，不输出半套指标）＋治理模式九件夹具逐项相等（install_chars／install_blocks／四阶段读取集）＋治理基线差值与缺键负例＋`--help`、非法 `--min-samples` 与 `--min-samples 0`（用法错误 exit 2）用法负例＋只读复核（会话与模板夹具 cksum 前后一致） |
| `adversarial` | 241 | 对抗金丝雀：十条核心规则各一个真跑负例（C1 `checkpoint-write` 缺裁决原文 exit 2 票文件零写入＋无 checkpoint md；C2 `run-record seal` 待填 fail-closed 且 record 字节不变；C3 自签 P08 非 conformant；C4 白名单外改动 `check-gates` 拒且 HEAD 不变；C5 双布局同脚本分歧 `upgrade-check` exit 1 且旧件不删；C6 记录路径被删的 `--record-commit` 拒且零提交；C7 索引无条目的 `ticket-run start` decision-required、索引字节不变；C8 通用 `flips` 直写 `index.json` 拒；C9 历史行改写 `check-append-only` 指名违规行号；C10 同改 implementation／review `check-role-permissions` 拒）＋G1–G5 正负例逐项（G1=`checkpoint-write`、G2=`run-record`、G3=`ticket-audit`、G4=记录提交删除/恢复、G5=`upgrade-check` 冲突/一致）＋一票 ready→done 正常路径五站（start 建站并领取、implementation／review 合同、commit 产品＋记录两段提交且翻 done 与投影、HEAD 恰前进两次）＋安装面（install 后 `run-record new`＋`seal` 真跑、幂等重跑 SKIP、新目录 README 收口后现行 `upgrade-check` 零差距；`install.sh` 为 main-only 件，worktree 显式 SKIP 并打印主检出复跑命令）＋临时副本升级切换（记录升级来源提交、`.zcode/` 字节零改动、`rules/` 手工改动计数 0、与全新安装 `rules/` 逐字节一致、旧 `scripts/` 件零静默覆盖并标旧布局、人工漂移停手不覆盖）＋纯文档项目与 Seed 初始化项目前置流程 |
| `runtime-closure` | 269 | 运行时依赖只认安装闭包正负例：六脚本运行时拼接零 `repo_root/agent-up` 回退（静态负向扫描）＋安装布局邻接闭包正例（ticket-ops open／contract-build 渲染／ledger-append 预检／ticket-run 引擎门）＋本地闭包与包工作树副本内容不同时以本地为准（工作树副本坏件不影响、本地坏件不回退）＋闭包缺失时各入口 fail-closed（exit 非 0、报文含缺失件绝对路径与升级/修补入口）且零写入（索引/README/账本/投影 cksum 前后一致、stdout 空）＋站内 `rules/implementation/scripts/` 闭包缺失语境按预期失败 |
| `harness` | 258 | harness 自身硬化负例（合成夹具＝mktemp 内复制同款 runner/helpers ＋ 按 `ALL_SUITES` 生成的桩套件，只把被验套件换成探针，真实套件零参与）：per-suite 超时（`TEST_SUITE_TIMEOUT=1`＋`sleep` 探针 → 整轮 exit 1、FAIL 行指名超时上限、后续套件照跑、仍有汇总行）＋套件内 `exit 2`（子 shell 隔离 → 整轮 exit 1、FAIL 行指名退出码、后续套件照跑、父进程按日志补出该套件汇总行且退出前断言不丢）＋TERM/INT 中断（经 python3 重置 SIGINT 处置后 exec 绕过后台任务的 SIG_IGN；各三断言：exit 130、输出中断行、临时目录已删除）＋断言数下限（`TEST_ASSERTION_FLOOR=999999` → exit 1 且 FAIL 行指名实测与下限）＋fast 车道静态面（非空且 ⊆ all、真子集、缺省下限 1100 在场） |

本表不登记断言数与套件数：suite 汇总行按实际计数输出，数字以 `--suite` 实跑输出为唯一真相源；套件全集以 `tests/suite-*.sh` 为真源。

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
| 2 | 用法或环境错误（`--suite` 不合口径、被测成员缺失、包根不存在、git 不可用、超时/下限环境变量非数字）。 |
| 130 | 收到 `INT`/`TERM`：停止在跑套件、清理临时目录后退出（`HUP` 为 129）。 |

### 维护规则

- 被测行为合法变更时同步更新本 harness 断言（预期值重新独立重建，不照抄实跑输出）；module-map 专节"维护联动"所述规则表 fixture 回归由此 harness 承载，`--suite module-map` 即回归入口。
- 夹具不入仓：fixture 由 harness 运行时自建于 mktemp（每语言样例＋去重/注释/字符串负例，fixture 纪律），仓库零留样。
- 复制落位（生成项目语境）随记录层工具同迁（同 `ticket-ops.sh` 落位口径，见 `../references/templates/scripts-README.md.tmpl` 自检工具落位句）；落位后缺省自测同目录包内脚本，包内/落位两语境同码。

## JSON 处理规范（唯一 JSON 引擎）

### json-validator.py（唯一 JSON 引擎）

**用途**：脚本层全部 JSON 操作的单点承载（基础库收敛 F3）——python3 标准库实现，无第三方依赖。脚本不再内嵌 python heredoc 或 awk JSON 解析副本；所有解析、校验与 JSON 读写经本引擎的模式面进行。

**模式面**：

1. **ticket**：`python3 json-validator.py ticket <schema> <ticket.json> [--new-ticket]`——票本体 schema 全量校验（`--new-ticket` 为开票门：kind 枚举收窄＋七维 profile reason 强制，语义归 ticket-ops open）。
2. **grade**：`grade <profile.md> <ticket.json> [...]`——复杂度定级建议（ticket-grade.sh 直通）。
3. **run seal / run stats**：run record 封存校验＋机械字段刷新、用量统计（run-record.sh 调用）。
4. **json（通用操作面，src 为文件路径或 `-` 读 stdin）**：
   - `json get <src> <path> [default]`——点路径取值（`steps.0.id` 形态；数组段为十进制下标）；字符串原样、容器紧凑 JSON、标量直出；路径缺失 exit 3，给 default 字面量则回退输出。
   - `json type <src> <path>`——输出 JSON 值类型（`null`/`boolean`/`number`/`string`/`array`/`object`）；路径缺失 exit 3（收据字段类型校验承载）。
   - `json fields <src> <field>...`——对象顶层多字段一行 TAB 分列输出（缺字段空单元格；数据面禁制表符；generate-progress 条目解析承载）。
   - `json len <src> <path> [default]`——字符串/数组/对象长度；缺路径或不可取长度 exit 3。
   - `json pick <src> <array_path> <k1> <v1> [... <kN> <vN>] [field]`——数组首元素多键全等匹配（值按 JSON 值或字符串形态比对）；尾随奇数参数为字段名（只输出该字段，命中元素缺该字段 exit 3），零命中 exit 3（workflow-executor 索引状态读取与状态机转换核对承载）。
   - `json count-key <src> <key>`——对象键递归计数（checkpoint 完成步统计承载）。
   - `json set <src|-> <dotted.path> <json-value>`——按点路径设置值并以记录层规范形态序列化到 stdout（`ensure_ascii=False`＋`indent=2`＋末尾换行；中间层缺失或非对象即建空对象；纯函数零写入，原子替换归 `record-store.sh` 的 `record_set_json`）。
   - 退出码约定：0 完成；1 输入不可读或非合法 JSON；2 用法；3 路径/元素未命中。
5. **workflow（workflow-executor.sh 专用操作，逐行等价迁移自原内嵌 heredoc）**：`steps`／`state-machine`（简化 YAML→JSON 解析）、`preflight`（step id 唯一性、checkpoint_field 格式与重叠、retry 存在性、类型支持、expect_exit 域）、`index-status`（索引状态原子单写）、`checkpoint-init`（sidecar 登记与 checkpoint_ref 锚定）、`read-checkpoint`、`checkpoint-check`（恢复前置校验＋retry 完成记录清除）、`step-check`（单步完成校验）、`record-step`（sidecar 两段原子写：先 checkpoint 后票指针）。报文与退出码为执行器合同输出，改写须随 workflow-contract 套件与 checkpoint-recovery harness 同步。
6. **ticket-check（ticket-ops.sh 三门，报文含 ticket-ops 前缀＝合同输出）**：`close <ticket.json> <id>`（flip 至 done 的 actual_time 收口硬拦）、`deps <ticket.json> <index.json> <id>`（take 的 blocked_by 完整性门）、`open-body <ticket.json> <id>`（open 的本体 id 一致＋理由非空断言）。
7. **contract ticket-id <contract-file>**——派发合同 TICKET_ID 提取（JSON `"TICKET_ID"` 键或 `{{TICKET_ID}}` 模板节次行；worktree-add.sh 合同入口承载；文件不可读 exit 1，值可能为空）。

**运行时依赖定位约定（现行定稿）**：所有运行脚本只认安装闭包——唯一 JSON 引擎在调用方同目录（安装器将引擎随脚本件同目录落位），schema/规则数据件在脚本邻接的 `../references/`（安装布局 `rules/implementation/scripts/` 与 `rules/implementation/references/`，包内 `agent-up/scripts/` 与 `agent-up/references/` 同构）。不得以 `repo_root` 拼接包工作树路径作为回退候选，也不得静默降级或按空范围放行。闭包缺失时各入口 fail-closed：错误信息指名缺失件的绝对路径，并指向升级/修补入口（Agent Up 包 `references/upgrade.md` 升级流程与 `scripts/install.sh` 修补安装）；失败路径零写入（索引/README/账本/投影均不产生字节变化）。

**限制**：`json fields` 输出以 TAB 分列，字段值含制表符时不可分列（索引/schema 数据面禁 TAB）；`json pick` 为线性首匹配，非通用查询语言；workflow 模式各操作与 workflow-executor.sh 的 checkpoint 合同强耦合，不作为通用库复用。

**测试套件**：`test-record-layer.sh --suite json-engine`（覆盖通用操作面与三门正负例，断言数以实跑输出为准）；workflow 模式回归＝workflow-contract 套件与 `test-checkpoint-recovery.sh`。

**调用形态**：`python3 "$(dirname "$0")/json-validator.py" <mode> [args]`（脚本层统一经 python3 显式调用，不依赖可执行位与 shebang 解析）。

## 维护联动

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。检查 12 同理零词面自命中面：词表唯一承载点为 `package-manifest.rules` vague-words 节（`.rules` 不在 md/tmpl 扫描文件面），引擎与本 README 不写词面字面量，harness 夹具注入词自夹具包 manifest 提取。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
- 扫描器登记条目（断言模式/权威位置/校验方式）增删或权威位置迁移须同步脚本内登记表与本 README 登记；权威位置失效时扫描器输出 STALE 提示重新核对登记，处置方式是修正登记或修正现实，不得为通过检查改写权威位置的真实内容（R-06-004 同源纪律）；新条目按登记流程扩充（Checkpoint 记录在案）；S5 扫描面 glob 清单扩面须 R-DP-033 条文与脚本数据节两处同步（禁静默扩面）。

## 构建规约

脚本写法约定（先包后仓——包侧为基准、仓侧镜像，随升级质询 dwfq-30d2bd9a-1 裁决两文件落位；原型＝agent-project-governance harness-design「Shell Harness Construction Rules」）。只约束新增与修改的脚本写法，既有脚本不回改（另票或随触碰自然对齐）；规约属约定非门禁——违反时机器无证据，不配断言，归评审人肉把关。

- 禁把检查写成传给 `eval` 的字符串。
- 禁在检查表达式内嵌命令替换（如 `$(find … | head -1)`）：先算好结果存变量再判，防 quoting 漂移与 `set -e` 误报。
- 优先用返回 shell 状态的 `check_*` 小函数（如 `check_file_exists`、`check_dir_exists`、`check_contains`）。
- 目录内容检查用预计算计数：先取计数存变量再比较，不在检查表达式内联展开。

### check 系验证器配对修复形态（--fix 设计准则）

包分发的 check 系验证器凡能机器定位缺陷的，配对 `--fix` 修复形态；准则四条（先例 `check-artifacts.sh` --fix）：

1. **配对条件**：缺陷可被脚本逐条机器定位（指名文件/行/条目）且修复内容可机械生成骨架——两者皆备才配 `--fix`；修复需语义判断（如权威定级、owner 归属）的输出【按项目填写】占位，粘贴前由执行体补齐。
2. **dry-run 默认**：`--fix` 无参只打印将改动的内容（逐条与 FAIL 输出对应），零写入。
3. **显式落盘**：`--apply` 与 `--fix` 同用才写文件；`--apply` 单用即用法错误 exit 2；落盘内容与 dry-run 预览逐字一致（同一生成代码，禁双实现）。
4. **共用判定代码**：修复与检测跑同一对账/扫描管线取缺陷清单（不复制判定逻辑），`--fix` 不引入第二真相源。

首批落点：`check-artifacts.sh --fix`（反向未登记 → 追加十三字段登记条目骨架进 artifacts.yaml；正向缺失不修——缺的是实物不是登记）。落地仓自有的 README 成员行/契约头检查器（check-doc-governance 系）按同模式自建 fixer，不随包分发。
