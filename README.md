<!-- Input: 同级 `SKILL.md` 的定位、触发与主流程语义，Agent Up 产品定义（SPEC-01）的问题陈述与核心承诺，2026-09-04 GitHub 发布事实（`https://github.com/ynotoony/agent-up.git`）与本包 `references/`、`scripts/` 的结构事实。 -->
<!-- Output: 公开包的问题陈述、安装与使用方式、设计边界、包结构与包内直接成员登记。 -->
<!-- Pos: 公开包入口说明（面向人的目录索引，不承载可执行规则）；一旦我被更新，务必更新我的开头注释，以及所属文件夹的 README.md。 -->

# Agent Up

> 给 AI Agent 用的 agent-ready 项目交付脚手架：把一套可读取、可核对、可接续的工作协议安装到任意仓库，让 Agent 的工作可验证、可接续、可审计。

没有共同工作协议时，AI Agent 在真实仓库里会直接改代码、重复造轮子、漏掉验证；上下文一切换，进度就丢在聊天记录里；没有范围边界，任务悄悄蔓延；没有独立审查，也照样宣告"完成"。

Agent Up 不生成业务代码。用完之后，你的仓库多出三样东西：

- `AGENTS.md` 路由入口与 `docs/` 权威文档层：Agent 先读什么、不同工作走哪条路径；流程、上下文、需求、任务、进度、变更各有唯一事实源。
- `docs/agent/roles/` 三阶段执行体：Implementation → Review → Commit 串行门禁，不可合并、不可裁剪。
- 契约头、目录登记与检查点：进度、验证证据与下一步落在仓库事实里，新会话从事实接续工作，不依赖聊天记忆。

## 安装

前置条件：一个支持 Skills 的 Agent 环境（能把 skills 目录里的技能交给 Agent 调用）。

把本包克隆到 Agent 的 skills 目录：

```sh
git clone https://github.com/ynotoony/agent-up.git ~/.agents/skills/agent-up
```

本地开发时，也可以把检出的 `agent-up/` 目录直接作为 Skill 目录使用；`SKILL.md` 会读取同目录的 `references/` 载荷。

## 使用

在目标项目里调用：

```text
/agent-up
```

首次运行五步：

1. **盘点**：查清 Git 状态、既有规则文件、技术栈、验证命令与顶层目录实际用途。
2. **模式判定**：全新 / 已有代码 / 部分治理；旧项目只补缺，不覆盖既有事实。
3. **差异清单**：任何写入之前先给出清单，按将新建 / 将修改 / 登记不动 / 冲突待决四类分组。
4. **用户确认**：你逐项确认后才开始写入；确认前一个字都不写。
5. **安装/补缺**：生成治理骨架，登记既有权威来源；没问到的事实标 `【待定】`。

之后的每次任务都走三阶段交付：**Implementation → Review → Commit**。实施者完整交付后停下，由独立于实现者的执行体只读审查，通过后再在用户授权下提交；三道门禁（用户确认、真实验证、独立审查）不可裁剪，完整协议见安装后目标项目内的 `docs/development-process.md`。

**断点接续**：进度、检查点、验证证据与下一步都写在仓库文档里。上下文中断或切换后，新会话从 `docs/progress.md` 与检查点恢复现场，接着上次的位置继续工作，不靠聊天记忆。

## 它不做什么

- 不生成业务代码，不替用户决定领域模型或产品决策。
- 不编造权限、数据语义、目录职责或验证命令；没有依据的标 `【待定】`。
- 不覆盖旧项目已有的代码、文档、命名和规则。
- 不绑定特定宿主的工具名或方言；不声称未测量的 token、速度或可靠性收益。
- 不自动执行 `git push`、部署、发布或创建 GitHub 仓库。

## 仓库结构

```text
agent-up/
├── SKILL.md                  # Skill 入口：定位、触发、核心规则、主流程与按需指引
├── README.md                 # 本文件：使用说明与成员登记
├── LICENSE                   # MIT 许可证
├── references/
│   ├── README.md             # 参考资料索引（子目录成员见各自 README）
│   ├── old-project.md        # 旧项目 / 部分治理项目协调手册
│   ├── protocol/             # 治理格式、读取策略与复杂度协议手册
│   ├── templates/            # 治理模板与 manifest（seed 七件套与角色合同）
│   ├── adapters/             # 宿主能力契约与宿主映射（平台绑定的唯一落点）
│   └── schemas/              # run record 机器 schema 与样例
└── scripts/
    ├── check-package.sh      # 七项包完整性检查（POSIX sh、只读、零网络依赖）
    ├── scenario-checklist.md # 发布前验收场景清单
    └── README.md             # scripts/ 用法、输出格式与退出码说明
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
| `scripts/` | 包完整性检查 | `check-package.sh` 七项包完整性检查与 `scenario-checklist.md` 发布前验收清单（用法、输出格式与退出码见 `scripts/README.md`）。 |
