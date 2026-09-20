<!-- Input: `check-package.sh` 的七项检查实现与 SPEC-06 §5、票 09/11 的例外登记事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；票 12（SPEC-06 §7）11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）；票 19（REQ-20260904-010）`check-stale-claims.sh` 的两模式、登记表条目与退出码实况；票 37（拆票计划 C 组②）道脚本改造事实——flips 索引条目口径（单写 docs/issues/index.json → 票正文 Status 投影打印件 → 生成器投影再生）、微账本 `docs/agent/micro.jsonl` JSON 行、S3 投影 vs 索引比对与 S1-1e 缺口消除、`generate-progress.sh` 入包（与本仓根 `scripts/` 基线 cmp 一致）；票 43 语言登记表 Rust 扩展事实（mod 文件边存在性核验＋use 路径表达式原串，四语言）。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、七项检查说明、易腐断言扫描器两模式与登记表说明、投影生成器用法与退出码、模块地图生成器用法与语言登记表、道脚本收尾行为（索引单写机制）、输出格式、退出码与维护联动规则。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。本目录同时是道脚本安装源：`check-gates.sh`、`lane-commit.sh` 与 `generate-progress.sh` 在目标项目用户确认启用分级交付道快道时，由初始化/补缺流程复制落位到目标项目 `scripts/` 并逐件登记（落位与登记口径见 `../SKILL.md` 主流程步骤 5 与 `../references/templates/development-process.md.tmpl` §12.5）；复制不改变参数语义——`[repo-root]` 缺省仍取当前目录所在 Git 仓库顶层（`generate-progress.sh` 缺省取脚本所在目录的上一级），与落位后用法一致。`generate-progress.sh` 与本仓根 `scripts/generate-progress.sh`（e29090f 基线）cmp 一致，两处同源演化须互为镜像并登记差异；票 38（E 票本体 JSON 化）登记：lane-commit 专节 PATH 回退措辞对齐实现（手动迭代 PATH，非 `command -v`）。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、七项检查、输出格式、退出码与维护联动规则。 |
| `check-package.sh` | 包完整性检查 | 按七项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004）；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
| `check-stale-claims.sh` | 易腐断言扫描器 | 登记表驱动的高流转状态句扫描（REQ-20260904-010 / 票 19；票 37 S3 改投影 vs 索引比对、消 S1-1e 恒触发缺口）；票收口拦截（gate，发现过期断言 exit 1）与会话启动警告（session，恒 exit 0）两模式；POSIX sh、全程只读、零外部依赖。详见下文专节。 |
| `check-gates.sh` | 快道门禁核对器 | 分级交付道快道的只读门禁核对（REQ-20260904-011 / 票 26）：工作区实际改动 ⊆ 白名单逐项比对 + 按清单重跑验证命令并记录退出码；POSIX sh、严格只读、零外部依赖。详见下文专节。 |
| `lane-commit.sh` | 快道收尾脚本 | 分级交付道快道的合同驱动收尾（REQ-20260904-011 / 票 26；票 37 单写机制改造）：门禁 → 白名单产品提交 → 索引单写（`docs/issues/index.json` 票状态真相源）→ 票正文 Status 投影打印件回写 → User Review Checkpoint 追加或微账本（`docs/agent/micro.jsonl`）落行 → 生成器投影再生并 `--check` 核对 → 记录提交（两段式，R-RC-003）；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-progress.sh` | 现役状态投影生成器 | 自 `docs/issues/index.json`（票状态真相源，一条目一行）生成 `docs/progress-current.md` 现役状态投影（Derived，生成器独占写；票 33 §5.1.4 / 票 35 落位、票 37 入包）；`--check` 为 dry-run 一致性核对；快道收尾由 `lane-commit.sh` 在索引单写后调用；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
| `generate-module-map.sh` | 模块地图生成器 | 静态导入行提取生成 `<root>/docs/architecture/module-map.json` 检索索引（票 30 拍板方案 A / 票 42 首版 / 票 43 Rust 扩展）：Derived 四标注＋nodes＋edges＋fp-v1 指纹内嵌（R-DP-015 算法，输入排除本图自身）；repo-root 参数化（缺省 git toplevel）；语言覆盖四语言（Python import/from、JS/TS import/require、C/C++ 引号 include、Rust mod 文件边＋use 模块路径边）；POSIX sh、无 jq/python（stat 与 SHA-256 工具依赖声明见专节）、fail-closed。详见下文专节。 |
| `scenario-checklist.md` | 场景验收清单 | SPEC-06 §7 发布前 11 条场景的验收边界、逐条执行结果与证据指针（票 12 / R-06-008）；S1-S9 为模板语义静态核对、S10 记 check-package.sh 实跑与临时副本负例及 `deferred-to-13` 条件项、S11 记 `N/A + reason`（未测量）；包内容变化后按本清单复验。 |

## 用途与用法

对 `agent-up` 公开包做发布前核对与包内容变化后自查：七项检查全部通过才可宣称包完整；失败项逐条修复或报告，不为通过检查篡改包内容（R-06-004）。

```text
sh scripts/check-package.sh [package-root]
```

- 无参数：以脚本所在目录的父目录为包根（在本包内运行时，检的就是本包）。
- 带参数：以第一参数为包根（对 subtree 导出目录或临时目录副本复跑时使用）。
- `-h` / `--help`：打印用法。
- 脚本只读：除向 stdout/stderr 打印外无任何写操作；无网络依赖（不出网、无下载行为）。

## 七项检查

| # | 检查 | 实现 |
| --- | --- | --- |
| 1 | 必需入口存在 | 16 个文件逐一 `test -f`：包根 `SKILL.md`、`README.md`、`LICENSE`；`references/` 下 `README.md`、`old-project.md`；`templates/`、`protocol/`、`adapters/`、`schemas/` 四个目录 README；`protocol/` 三手册（governance-format、read-policy、complexity-profile）；`adapters/` 两手册（capability-contract、zcode）；`schemas/` 两 JSON（run-record.schema.json、run-record.example.json）。 |
| 2 | `SKILL.md` frontmatter 为 `name: agent-up` | 首行 `---` 与闭合 `---` 之间存在 `name: agent-up` 行；frontmatter 缺失或未闭合判失败。 |
| 3 | 包内无旧标识残留 | `grep -rn` 全包扫描旧 Skill 标识字面量（本包改名前的原 Skill 名），零命中为通过；扫描范围含本目录。 |
| 4 | 无绝对路径与根治理引用 | `grep -rn` 扫描用户主目录绝对路径前缀（/Users 或 /home，带尾斜杠匹配）与根治理相对引用字面量（`../` 后接 docs 或 .zcode）。按票 09/11 结论，模板内 `../specs/` 等兄弟路径属目标项目生成语义，不在本项口径。 |
| 5 | 模板清单与 manifest 一致 | `references/templates/` 下 `.tmpl` 恰 13 个；每个 `.tmpl` 在 `templates/README.md` manifest 有登记行；manifest 目录清单节登记的每个 `.tmpl` 均有实际文件（无多余登记）。增删模板须同步 manifest 与本脚本的预期数量。 |
| 6 | 文本契约头齐全 | `*.md` 与 `*.tmpl` 在检测窗口内含 `Input:`/`Output:`/`Pos:` 三行：无 frontmatter 的文件取前 5 行，首行为 `---` 的文件取 frontmatter 结束后的 5 行（frontmatter 未闭合判失败）。例外：`artifacts-yaml.tmpl` 以 YAML `#` 注释承载（前 5 行含 `# Input:`/`# Output:`/`# Pos:`，登记见 `templates/README.md`）；`LICENSE` 与 `schemas/*.json` 不属扫描范围（JSON 以 `$id`/`title`/`description` 承载导航元数据，例外登记见 `schemas/README.md`）。 |
| 7 | 根治理文件不在包内 | 包根不存在 `AGENTS.md`（文件）、`docs/`（目录）、`.zcode/`（目录）。 |

## 输出格式

```text
PASS: <编号> <描述>
FAIL: <编号> <描述> — <单行详情>
FAIL: <编号> <描述> 详情：
  <多行详情逐行缩进两空格>
check-package: PASS
```

- 七项检查逐项输出一行 PASS 或 FAIL；任一失败时结尾输出 `check-package: FAIL（N 项未通过，共 7 项）`，全部通过时结尾输出 `check-package: PASS`。
- FAIL 详情为可定位信息：文件清单、命中行（`路径:行号:内容`）或计数差异。

## 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 七项检查全部通过。 |
| 1 | 存在未通过项（逐项 FAIL 行见输出）。 |
| 2 | 用法或环境错误（参数过多、包根不存在等）。 |

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

模块地图生成器首版（票 30 调研拍板：落点＝方案 A agent-up 公开包脚本、查询形态＝JSON 直读唯一查询面（`--affected` 不采纳）、更新时机＝双通道、首发语言三种，票 43 扩 Rust 为四语言；票 42 落位）：从仓库源码文件的静态导入语句提取文件/模块级依赖边，生成 `<root>/docs/architecture/module-map.json`——Derived 四标注头部（`generated_from`/`generated_at`/`coverage`/`invalidation`，R-DP-004）＋`workspace_fingerprint`（fp-v1，R-DP-015 算法；指纹输入排除本图自身，避免自引用漂移）＋`nodes`（已扫描源码文件，仓库根相对路径）＋`edges`（`from`=仓库根相对路径、`to`=导入语句文本中的模块引用原串（未做路径解析）、`label`=导入语句类别）。本图是项目地图条件产物的承载视图（development-process §5.2 触发矩阵行"项目地图"），只当检索索引不当 Scope 权威，不作为白名单或 watch 依据；Derived 自动生成，agent 不手写。输出为 `python3` `json.loads` 可解析的机器可读 JSON（R-GF-005）。

### 用法

```text
sh scripts/generate-module-map.sh [repo-root]
```

- 无参数：repo-root 缺省取当前目录所在 Git 仓库顶层（check-gates.sh :20 先例）。
- 带参数：以第一参数为仓库根（对临时 fixture 仓或非默认落位复跑时使用）。
- `-h` / `--help`：打印用法。
- 输出落 `<root>/docs/architecture/module-map.json`（目录缺失时随生成懒创建）；生成动作对仓库零额外写入（临时文件全部落 TMPDIR）。

### 语言登记表（四语言）

| 语言 | 扩展名 | 匹配规则（语句文本层） | label 取值 |
| --- | --- | --- | --- |
| Python | `.py` | `import a[.b][, c]`（逗号列表、`as` 别名取模块名、行尾 `#` 注释剥离）与 `from m import ...`（含相对导入 `.`/`..`） | `python-import` / `python-from` |
| JS/TS | `.js .mjs .cjs .jsx .ts .tsx` | `import ... from '...'`、裸 `import '...'`、`require('...')`（单双引号归一处理）；re-export（`export ... from`）与动态 `import()` 未覆盖 | `js-import` / `js-require` |
| C/C++ | `.c .h .cc .cpp .cxx .hpp .hh` | 引号 `#include "..."`；尖括号系统头 `#include <...>` 不提取 | `c-include` |
| Rust | `.rs` | `mod x;` 声明（分号收尾；内联块 `mod x {` 不匹配）映射文件边：子模块目录＝声明文件同目录（声明文件为 `mod.rs`/`main.rs`/`lib.rs` 时）或同名子目录（其余），候选 `x.rs` 与 `x/mod.rs` 经文件存在性核验后产边，无候选零边；`use` 路径表达式原串产模块路径边（`crate::`/`self::`/`super::`/`::`开头/外部 crate 路径；brace 组取 `{` 前缀、`as` 别名取前缀、glob 剥尾 `::*`、`r#` 原始标识符段按原串保留；多行 brace 组取首行前缀）；宏生成声明、pub use 转发语义、extern crate、`#[path]` 重定位、块注释内文本未覆盖 | `rust-mod` / `rust-use` |

覆盖声明（R-CC-004，保守措辞）：提取规则为语句文本层——不做别名/tsconfig paths 等路径映射解析，不覆盖动态导入、re-export、符号级调用图与构建期代码生成边；注释内的导入文本与字符串字面量构成已知误报源（输出层不做语义过滤）。上表规则经 fixture 最小验证（mktemp 临时仓：四语言正例＋空格/中文路径＋尖括号系统头/内联 mod 块/不存在 mod 负例＋fp-v1 复算比对；票 43 新旧脚本对同一三语言夹具边集 diff 零变化），未实测项按一般工程知识声明。

### 更新时机（双通道）

1. 登记驱动：目标项目将本图按 development-process §5.3 登记 `docs/agent/artifacts.yaml`（lifecycle: Derived，generated_from 必填），`sync_on` 对齐拓扑变化行（文件新增/删除/移动/重命名即重新生成）；登记动作归目标项目 init/补缺流程（见 `../references/old-project.md` §3 项目地图行）。
2. 指纹比对：生成时将 fp-v1 工作区指纹内嵌 `workspace_fingerprint`，使用时按 R-DP-015 算法重算比对，不一致即按 R-DP-009 判 stale，不得当可信导航。已知局限（保守方向安全，票 30 ④声明）：fp-v1 为全工作区粒度，文档改动也判过期；精确化归后续演进。

### 依赖声明（零外部依赖的边界）

POSIX sh 主体（`#!/bin/sh`、`set -eu`、`set -f`）仅用 POSIX 标准工具（find/sed/awk/sort/grep/cut/wc/date/mktemp/git 只读子命令）；两项平台标配补充，缺失即 fail-closed（exit 2）：`stat`（BSD/GNU 双方言自动探测，取文件字节与 mtime 纪元秒）与系统 SHA-256 工具（`sha256sum`/`shasum -a 256`/`cksum -a sha256`/`openssl dgst -sha256` 按序探测）。

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
| 2 | 用法或环境错误（非 Git 仓库、仓库根不存在、SHA-256/stat 工具缺失）。 |

### 维护联动

- 语言登记表增删或匹配规则变化须同步 fixture 自检与本专节；fixture 为临时件不入仓（跑法与结果见票 42/票 43 run record `last_verified`），沉淀为共享验证归后续票。
- 生成项目补缺落位与登记口径见 `../references/old-project.md` §3 项目地图行；本图不预建实例（触发矩阵行命中才创建，R-DP-006）。
- 排版与转义惯例与 `generate-progress.sh` 同源（`set -f`、TMPDIR mktemp＋trap 清理、LC_ALL=C 排序）；两脚本不共享代码，语义变化互不联动。

## 维护联动

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
- 扫描器登记条目（断言模式/权威位置/校验方式）增删或权威位置迁移须同步脚本内登记表与本 README 登记；权威位置失效时扫描器输出 STALE 提示重新核对登记，处置方式是修正登记或修正现实，不得为通过检查改写权威位置的真实内容（R-06-004 同源纪律）；新条目按票 19 Checkpoint 记录的登记流程扩充。
