<!-- Input: `check-package.sh` 的七项检查实现与 SPEC-06 §5、票 09/11 的例外登记事实（schemas/README.md 的 JSON 契约头例外、templates/README.md 的 artifacts-yaml YAML 契约头例外）；票 12（SPEC-06 §7）11 条场景验收执行记录与沉淀决定（`scenario-checklist.md`）。 -->
<!-- Output: 公开包 scripts/ 目录索引与共享 harness 约定：脚本用途、用法、七项检查说明、输出格式、退出码与维护联动规则。 -->
<!-- Pos: 公开包脚本目录索引；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# 脚本

本目录承载公开包的可执行检查工具。成员清单与本目录实际文件一致，增删成员必须在此登记，不静默增删。

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `README.md` | 目录索引 | 说明脚本用途、用法、七项检查、输出格式、退出码与维护联动规则。 |
| `check-package.sh` | 包完整性检查 | 按七项检查核对包结构与文本事实（SPEC-06 §5 / R-06-004）；POSIX sh（`#!/bin/sh`、`set -eu`）、只读检查、零网络依赖。 |
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

## 维护联动

- 自命中规避：检查 3/4 的扫描范围包含本目录文件，脚本内的敏感模式以字符串拼接或正则转义构造，运行时才拼成完整字面量；因此本目录任何文件不得直接写出检查 3/4 的敏感字面量（旧标识字面量、带尾斜杠的主目录绝对路径前缀、根治理相对引用字面量）。
- 包结构变化（入口文件增删、模板增删、检查项调整）须同步本脚本对应检查与各层 README 登记；不允许为通过检查临时篡改包内容（R-06-004 Forbidden）。
