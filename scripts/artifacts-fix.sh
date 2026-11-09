#!/bin/sh
# Input: 调用方（check-artifacts.sh）已加载的检测态全局：ca_fix/ca_apply/ca_unreg_list/
#        ca_entries/ca_managed/ca_scan/t_dir/yaml/artifacts_yaml；只由 check-artifacts 调用。
# Output: --fix 建议块生成与 --apply 追加写面（预览与落盘同源；dry-run 缺省零写入）；函数
#        ca_fix_face 无返回值约定，失败路径经调用方既有 exit 语义承载。
# Pos: check-artifacts.sh 的 --fix 修复写面模块（票 294：对账面与写面分离）；本件不承载
#      正向/反向对账判定，判定仍在 check-artifacts.sh 主件。
# shellcheck disable=SC2154  # 跨件共享状态（调用方检测态全局），单文件视野误报

ca_fix_face() {
# ---- --fix 修复形态（票 119；与检测共用同一判定代码——未登记清单即上循环产出）----
# 登记 id 推导：路径去扩展名取末段、非 [a-z0-9-] 字段折叠为单横线（含前导），前缀
# artifact-；十三字段骨架中不可机械推断的值写【按项目填写：...】占位，粘贴前由执行体
# 按实际产物补齐（缺值写 N/A + reason 纪律见 artifacts-yaml.tmpl）；骨架 id 按路径
# 机械推导、不查既有条目——与既有 id 撞名时由执行体改定后再落（复跑本脚本以
# 「条目 id 重复」行零命中为准，票 147 唯一性检查）。
# 单一生成：建议块先写临时文件一次成型，dry-run cat 预览／--apply 追加两用（同一生成
# 代码，禁双实现——预览与落盘逐字一致由同源保证）。
if [ "$ca_fix" -eq 1 ]; then
  if [ ! -s "$ca_unreg_list" ]; then
    printf 'check-artifacts: --fix: 无未登记受管文件，无需修复\n'
  else
    ca_fix_block=$(mktemp "${t_dir%/}/reconcile.XXXXXX")
    # shellcheck disable=SC2329  # cleanup 由调用方 trap 回调（单文件视野误报）
    cleanup() { rm -f "$ca_entries" "$ca_managed" "$ca_scan" "$ca_unreg_list" "$ca_fix_block"; }
    while IFS= read -r ca_f; do
      [ -n "$ca_f" ] || continue
      ca_fid=$(printf '%s' "${ca_f%.*}" | tr '/' '\n' | tail -n 1 | sed 's/[^a-z0-9-][^a-z0-9-]*/-/g; s/^-*//; s/-*$//')
      [ -n "$ca_fid" ] || ca_fid=artifact
      {
        printf '  - id: artifact-%s\n' "$ca_fid"
        printf '    path: %s\n' "$ca_f"
        printf '    kind: 【按项目填写：governance/index/record/script 等；新增值先在 artifacts-yaml.tmpl 注释区登记】\n'
        printf '    authority: 【按项目填写：权威层级第 N 级（理由）】\n'
        printf '    owner: 【按项目填写：唯一写入者】\n'
        printf '    lifecycle: 【按项目填写：Seed/Conditional/Record/Derived/Adapter】\n'
        printf '    trigger: 【按项目填写：创建触发条件】\n'
        printf '    read_when: 【按项目填写：读取时机】\n'
        printf '    sync_on: 【按项目填写：契约/拓扑/行为/派生/无】\n'
        printf '    depends_on: []\n'
        printf '    generated_from: N/A + reason（非派生件写不适用理由）\n'
        printf '    platform: neutral\n'
        printf '    update_policy: 【按项目填写：更新策略】\n'
        printf '\n'
      } >> "$ca_fix_block"
    done < "$ca_unreg_list"
    if [ "$ca_apply" -eq 1 ]; then
      cat "$ca_fix_block" >> "$yaml"
      printf 'check-artifacts: --apply: 已追加 %d 条登记条目骨架进 %s（占位值须补齐；复跑本脚本核反向缺口归零）\n' \
        "$(wc -l < "$ca_unreg_list" | tr -d ' ')" "$artifacts_yaml"
    else
      printf 'check-artifacts: --fix: %d 个未登记受管文件的登记条目建议块（dry-run 缺省零写入；显式 --apply 追加进 %s）:\n' \
        "$(wc -l < "$ca_unreg_list" | tr -d ' ')" "$artifacts_yaml"
      cat "$ca_fix_block"
    fi
  fi
fi
}
