<!-- Input: 仓根 `delivery.rules` 行式配置的四节文法定稿事实、共享解析库 `scripts/dp-load-rules.sh` 的解析口径与版本事实、分发模板 `templates/delivery-rules.tmpl` 的锚点面。 -->
<!-- Output: delivery.rules 文法与版本的权威说明：四节锚点、指令全集、fail-closed 六规则、版本单源与消费者映射。 -->
<!-- Pos: 包内文法参考手册（不进目标项目，逐仓事实由采纳方按模板生成 delivery.rules）；文法演进只改本说明与解析库（两者由 harness 机械核对一致），锚点行与模板逐字一致；落地拷贝同步路径见 old-project.md §3。 -->

# delivery.rules 文法与版本说明

仓根 `delivery.rules` 是导出形态、边界禁入、校准点与 worktree 排除清单的项目约定唯一承载点：行式配置，四节锚点＋`dp_` 指令行，逐仓不同的事实进本文件，全局一致的协议面留各引擎与数据表。本说明是文法与版本的权威描述；机械核对由解析库与 harness 承载（指令全集、锚点表、版本三方逐一相等）。

## 消费者与消费节映射

| 消费者 | 消费节 | 读取字段 |
| --- | --- | --- |
| `scripts/export-payload.sh` | payload | `DP_ROOT`/`DP_REMOTE`/`DP_TARGET`/`DP_LOCAL_REF`（未声明 payload 节＝拒跑） |
| 采纳仓 pre-push 安检（仓侧） | boundary | `DP_FORBID` 清单 |
| `scripts/check-artifacts.sh` | calibration | `DP_EXEMPT`（缺该行＝豁免消失，按未登记暴露） |
| `scripts/check-stale-claims.sh` | calibration | `DP_STALE_LIT`（未点亮＝S1/S2 断言 SKIP） |
| `scripts/worktree-add.sh` | main-only | `DP_MAINONLY`/`DP_MAINONLY_DECLARED`（未声明＝栅栏未知，拒跑） |

四消费者的解析一律经共享解析库 `scripts/dp-load-rules.sh`（同目录 source 后调用 `dp_load_rules <repo-root> <错误前缀>`），不内嵌各自的解析副本。

## 文法

行形态：指令行须顶格；每行恰一条指令，指令名与值以单个空格分隔，值须为恰一非空字段（禁空白、制表符与多余空格）；`#` 开头为注释行（跳过）；空行跳过；`# ==== X：Y ====` 形态为本版不识别的锚点行，命中即报「解析破坏」（落地拷贝版本落后的升级信号）。

四节锚点（与解析库锚点表 `an[1..4]` 及分发模板逐字一致）：

```text
# ==== payload：导出形态（export-payload.sh 读）====
# ==== boundary：禁入名单（pre-push 安检读）====
# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====
# ==== main-only：worktree 排除清单（worktree-add.sh 读）====
```

指令全集（恰 8）: dp_artifact_exempt dp_forbid dp_mainonly dp_payload_local_ref dp_payload_remote dp_payload_root dp_payload_target dp_stale_lit

| 指令 | 所属节 | 值形态 | 恰数 | 语义 |
| --- | --- | --- | --- | --- |
| `dp_payload_root` | payload | 仓库根相对路径（禁前导斜杠、`..` 段） | 节存在时恰一行 | 公开包在仓内的根目录 |
| `dp_payload_remote` | payload | 远端名 | 节存在时恰一行 | 公开仓远端 |
| `dp_payload_target` | payload | 分支名 | 节存在时恰一行 | 公开仓目标分支 |
| `dp_payload_local_ref` | payload | 分支名 | 节存在时恰一行 | 本地导出分支 |
| `dp_forbid` | boundary | 仓库根相对路径（禁前导斜杠、`..` 段；尾斜杠＝整支） | 逐行一条 | 禁入名单（命中拒推） |
| `dp_artifact_exempt` | calibration | 仓库根相对路径（禁前导斜杠、`..` 段；尾斜杠＝整支） | 逐行一条 | 机器生成投影面对账豁免 |
| `dp_stale_lit` | calibration | 枚举 `S1`/`S2` | 逐行一条，二选一或都亮 | 易腐断言扫描点亮位 |
| `dp_mainonly` | main-only | 仓库根相对路径（禁前导斜杠、`..` 段、尾斜杠） | 逐行一条 | worktree 创建面排除清单 |

fail-closed 六规则（任一命中＝解析破坏，返回 2，不产生部分结论）：未知指令；恰数违（payload 节存在时四条 payload 指令各恰一行）；枚举违（`dp_stale_lit` 越 `{S1,S2}`）；值跨行重复（全文件值集合禁重复）；路径形态违（前导斜杠、`..` 段；`dp_mainonly` 另禁尾斜杠）；锚点重复或条目违属（指令仅得出现于所属锚点后，锚点行重复即破坏）。文件缺失＝全默认未声明（返回 0，各消费件按各自缺省语义处置）。

## 版本与单源

dp-parser 现行版本: 2

- 版本唯一来源＝`scripts/dp-load-rules.sh` 的 `DP_PARSER_VERSION` 变量（与其内部 awk `dpv` 同值同步）；本说明的版本行、解析库变量、分发模板锚点表三方由 harness 机械核对逐一相等，指令全集与锚点表同源核对。
- 消费件头部 `# dp-parser: N` 注记为该件要求的解析器最低版：加载时解析库缺件报「共享解析器缺失」、版本低于最低要求报「共享解析器版本漂移」，均 fail-closed exit 2 指名路径。
- 落地拷贝遇未知锚点/指令、解析器缺件或版本漂移＝落地版本落后包内现版的升级信号，按 `old-project.md` §3 整件同步，不手改单点。
