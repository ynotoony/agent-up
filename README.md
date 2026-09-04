<!-- Input: 同级 `SKILL.md` 的工作流与门禁语义，以及本公开包 `references/` 与 `scripts/` 的实际结构事实。 -->
<!-- Output: 公开包的定位、工作流与门禁、安装调用方式、设计边界、包结构与包内直接成员登记。 -->
<!-- Pos: 公开包入口说明（面向人的目录索引，不承载可执行规则）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Agent Up

> 给 AI Agent 用的项目交付脚手架：让 Agent 知道项目是什么、当前该做什么、如何验证结果，以及如何把工作交给下一个 Agent。

本目录是可独立理解的公开 Skill 包。它把一套可接续、可验证、可审计的工作规则安装到目标项目：不生成业务代码，不替用户猜测领域事实，不绑定任何宿主的工具形态。

## 工作流

与 `SKILL.md` 主流程一致：

```text
盘点 -> 模式判定 -> 访谈 -> 差异清单确认 -> 安装/补缺 -> Implementation -> Review -> Commit -> 收尾报告
```

任何文件写入都先经用户确认差异清单；交付以验证证据为准；提交前必须有独立 Review 通过证据。三道门禁（确认、验证、独立审查）不可裁剪，完整协议见安装后目标项目内的 `docs/development-process.md`。

使用后，目标项目会获得一套让 Agent 能持续工作的共同语言：

- `AGENTS.md`：告诉 Agent 先读什么、不同工作该走哪条路径。
- `docs/`：保存流程权威、领域上下文、需求、任务、进度、变更和机器产物索引。
- `docs/agent/roles/`：Implementation、Review、Commit 三个阶段的平台无关角色合同。
- 契约头和目录登记：让文件知道自己的来源、产出和体系位置。
- run record 与检查点：中断后的工作从事实恢复，而不是依赖聊天记忆。

## 安装与使用

将 `agent-up/` 目录安装到 Agent 的 skills 目录，例如：

```text
~/.agents/skills/agent-up
```

然后在目标项目中调用：

```text
/agent-up
```

首次使用的样子：

1. 技能先盘点目标项目（Git 状态、既有规则、技术栈、验证命令、目录用途）。
2. 展示差异清单：将新建 / 将修改 / 登记不动 / 冲突待决。
3. 你确认后，技能才写入治理文件；旧项目只登记与补缺，不覆盖既有事实。

公开仓库地址和安装来源仍在发布前确定；当前说明不声称本包已经发布，也不提供已确认的 GitHub URL。

本地开发时，可直接将当前 `agent-up/` 目录作为 Skill 目录使用；`SKILL.md` 会读取同目录的 `references/` 载荷。

## 设计边界

本 Skill 负责提供 Agent 项目脚手架，不负责：

- 生成业务代码或替用户决定领域模型。
- 编造权限、数据语义、目录职责或验证命令；没有依据的标 `【待定】`。
- 覆盖旧项目已有的代码、文档、命名和规则。
- 绑定特定宿主的工具名或方言；平台映射只在包内 `references/adapters/`。
- 自动执行 `git push`、部署、发布或创建 GitHub 仓库。
- 在没有实验数据的情况下声称 token 节省、速度或可靠性提升。

## 包结构

```text
agent-up/
├── SKILL.md                  # Skill 入口：定位、触发、核心规则、主流程、按需指引与输出要求
├── README.md                 # 本文件：公开包使用说明与成员登记
├── LICENSE                   # MIT 许可证
├── references/
│   ├── README.md             # 参考资料索引（子目录成员见各自 README）
│   ├── old-project.md        # 旧项目/部分治理项目协调手册
│   ├── protocol/             # 治理格式与读取协议手册
│   ├── templates/            # 治理模板与 manifest（seed 七件套、条件产物、角色合同）
│   ├── adapters/             # 宿主能力契约与宿主映射（平台绑定的唯一落点）
│   └── schemas/              # run record 机器 schema 与样例
└── scripts/                  # 包完整性检查脚本与用法说明（用法、输出格式与退出码见 scripts/README.md）
```

## 许可证

MIT，版权归 `2026 ynotoony`。

## 包内直接成员

| 名字 | 地位 | 功能 |
| --- | --- | --- |
| `LICENSE` | 许可证 | MIT 许可证文本。 |
| `README.md` | 包入口 | 公开包定位、使用方式和成员登记。 |
| `SKILL.md` | Skill 事实源 | `agent-up` 的六类内容入口与初始化边界。 |
| `references/` | Skill 参考目录 | 协议手册、治理模板与 manifest、宿主适配、机器 schema、旧项目手册（子目录索引见 `references/README.md`）。 |
| `scripts/` | 包完整性检查 | `check-package.sh` 七项包完整性检查（POSIX sh、只读、零网络依赖）与 `scripts/README.md` 用法、输出格式、退出码说明。 |
