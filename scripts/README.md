<!-- Input: `check-package.sh` 的七项检查实现与 SPEC-06 §5、票 09/11 的例外登记事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；票 12（SPEC-06 §7）11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）；票 19（REQ-20260904-010）`check-stale-claims.sh` 的两模式、登记表条目与退出码实况。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、七项检查说明、易腐断言扫描器两模式与登记表说明、输出格式、退出码与维护联动规则。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、七项检查、输出格式、退出码与维护联动规则。 |
| `check-package.sh` | 包完整性检查 | 按七项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004）；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
| `check-stale-claims.sh` | 易腐断言扫描器 | 登记表驱动的高流转状态句扫描（REQ-20260904-010 / 票 19）；票收口拦截（gate，发现过期断言 exit 1）与会话启动警告（session，恒 exit 0）两模式；POSIX sh、全程只读、零外部依赖。详见下文专节。 |
| `check-gates.sh` | 快道门禁核对器 | 分级交付道快道的只读门禁核对（REQ-20260904-011 / 票 26）：工作区实际改动 ⊆ 白名单逐项比对 + 按清单重跑验证命令并记录退出码；POSIX sh、严格只读、零外部依赖。详见下文专节。 |
| `lane-commit.sh` | 快道收尾脚本 | 分级交付道快道的合同驱动收尾（REQ-20260904-011 / 票 26）：门禁 → 白名单产品提交 → User Review Checkpoint 追加或微账本落行 → 状态翻转 → 记录提交（两段式，R-RC-003）；POSIX sh、零外部依赖、fail-closed。详见下文专节。 |
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
| 5 | 模板清单与 manifest 一致 | `references/templates/` 下 `.tmpl` 恰 15 个；每个 `.tmpl` 在 `templates/README.md` manifest 有登记行；manifest 目录清单节登记的每个 `.tmpl` 均有实际文件（无多余登记）。增删模板须同步 manifest 与本脚本的预期数量。 |
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
| S1 | Git 状态句 | `docs/progress.md` 的「Git 恢复基线」块 | machine：Git 只读子命令逐项核对基线块宣称（首个提交存在、本地导出分支存在、唯一 remote 与宣称地址一致、本地 main 未被远端跟踪分支包含、工作区存在未提交改动）；非 Git 工作区按流程退化语义输出提醒跳过。 |
| S2 | 发布状态句 | 根 `README.md`「公开包已发布」宣称行 + `agent-up/README.md` 安装行 | machine：文档宣称的仓库地址与实际 remote origin 配置归一化比对、包内安装行同源核对；远端可达性/可见性本地不核验（不出网）→ reminder。 |
| S3 | frontier 句 | `docs/issues/README.md` 架构节 + 目录清单表行 | machine：表行（票文件、状态标注、by 链）逐票对照票面状态——状态取 frontmatter `status`，无 frontmatter 的存量票退化取正文 `**Status:**` 行；表行宣称完成而票面非完成（虚假完成宣称）、票文件缺失、blocked-by 链不一致 → 过期断言；表行标 blocked 而票面已流转（索引同步滞后）、票面无可机读状态 → reminder。 |

机器可校验项直接对现实核验；不可机器校验项输出存在时长提醒（WARN，阈值【待定】，定稿后同步本登记）。

### 输出格式

```text
STALE: <路径:行号> — <断言与现实的差异说明>
WARN: <路径:行号> — <提醒内容（含登记日期与【待定】阈值标注）>
check-stale-claims: PASS（登记表 3 条全部核对，提醒 N 条）    # gate 模式清洁
check-stale-claims: FAIL（N 处过期断言，登记表共 3 条）       # gate 模式存在过期断言
check-stale-claims: 会话启动模式（不拦截）：过期断言 N 处，提醒 N 条，请人工核对上方输出
```

- STALE 行含 `路径:行号` 定位与差异说明；WARN 行为提醒（非失败）；结尾汇总行给出计数与结论。

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

分级交付道快道的合同驱动收尾脚本（REQ-20260904-011 / 票 26）：门禁核对 → 白名单产品提交 → 记录写入（user-review 道 User Review Checkpoint 追加 / micro 道微账本落行）→ 状态翻转 → 记录提交，两段式（先产品提交后纯记录提交，R-RC-003）。POSIX sh（`#!/bin/sh`、`set -eu`）、零外部依赖、零网络依赖、fail-closed（门禁不过或合同格式不合预期即停止报告，停止时零写入零提交，不 best-effort 修补）。脚本权限边界 = 提交合同白名单，不执行白名单外任何写入。

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
| `flips: <file>:<field>:<value>` | 一行一条，可多行；三段均不得为空，各段不得含制表符。 |
| `# 注释` / 空行 | 行首 `#` 与空行忽略；无法识别的行、重复行判合同格式错误（exit 1）。 |

flips 语义：`field` 为 `status` 时对目标文件做状态双写——frontmatter `status:` 行与正文 `**Status:**` 行两锚点各须恰命中一行（frontmatter 块须存在且闭合），正文 Status 行翻转为反引号包裹的 `value`；`field` 为其他值时做整行替换——锚点为字面子串，须恰命中一行，整行换成 `value`。锚点不合规在写入前停止（exit 1）。

### 两段式提交与输出格式

执行顺序（每步失败即停止，停止时未产生任何写入或提交）：

1. 合同解析与语义校验（车道组合、必填行缺失、禁止组合、翻转目标存在性；先于任何写入）。
2. 翻转锚点预校验（只扫描不写入；全部 flips 逐项通过才继续）。
3. 门禁核对（内部调用同目录 check-gates.sh，只读）；任一不符 exit 1。
4. 产品提交：按白名单逐项 `git add`，防御性核对暂存内容不越出白名单，按合同 `message` 创建提交。
5. 状态翻转与记录写入：user-review 道向票文件追加 User Review Checkpoint（裁决原文、裁决时间、产品提交 ID 与说明、diff 摘要）；micro 道向 `docs/agent/micro.md` 落一行（日期、白名单、门禁结果、产品提交 ID），账本不存在时懒创建。
6. 记录提交：翻转目标与记录内容统一入第二段提交（`chore(lane): 记录翻转 — <message>`）。

```text
lane-commit: 翻转: <file>:<field>:<value>
lane-commit: User Review Checkpoint 已追加: <ticket>
lane-commit: 微账本已落行: docs/agent/micro.md
lane-commit: 产品提交 <提交 ID>
lane-commit: 产品文件: <逗号分隔清单>
lane-commit: 记录提交 <提交 ID>
lane-commit: 记录文件: <逗号分隔清单>
lane-commit: PASS（两段式完成：门禁 PASS、翻转 N 项、记录已落盘）
```

- 「User Review Checkpoint 已追加」行仅 user-review 道输出，「微账本已落行」行仅 micro 道输出；失败输出 `lane-commit: FAIL: <原因>`（stderr），逐步骤停止原因可定位。

### 退出码

| 退出码 | 语义 |
| --- | --- |
| 0 | 两段式全部完成（门禁 PASS、产品提交、记录写入、记录提交）。 |
| 1 | 门禁不过或合同 fail-closed 条件（合同格式错误、车道必填缺失或禁止组合、白名单越界、verify 失败、翻转锚点不合规、暂存越出白名单、白名单内无实际改动等）；停止时未产生任何写入或提交。 |
| 2 | 用法或环境错误（参数数量不合、仓库根不存在或不是 Git 仓库、合同文件不可读、同目录 check-gates.sh 缺失等）。 |

### 微账本与维护联动

- 微账本 `docs/agent/micro.md` 与 user-review 道 User Review Checkpoint 由本脚本独占写：微账本懒创建（契约头三行注释 + 数据行），agent 不手写、其他流程不得代写。
- 白名单与 flips 目标均须为仓库根相对文件路径；状态双写锚点依赖票面 frontmatter `status:` 行与正文 `**Status:**` 行格式，票文件格式变化须同步脚本锚点语义与本 README。
- 本脚本用法、合同行格式或退出码变化须同步脚本 usage 文本与本 README 专节；门禁清单格式口径以 check-gates.sh 专节为准。

## 维护联动

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
- 扫描器登记条目（断言模式/权威位置/校验方式）增删或权威位置迁移须同步脚本内登记表与本 README 登记；权威位置失效时扫描器输出 STALE 提示重新核对登记，处置方式是修正登记或修正现实，不得为通过检查改写权威位置的真实内容（R-06-004 同源纪律）；新条目按票 19 Checkpoint 记录的登记流程扩充。
