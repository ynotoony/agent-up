#!/bin/sh
# Input: 调用方（generate-module-map.sh）已就绪的 repo_root／out_rel／RUNS_DIR_REL／
#        sha_cmd／stat_flag／stat_fmt／tab／NL／tmp_fp 与 die1 报文函数。
# Output: mm_compute_fingerprint：R-DP-015 fp-v1 工作区指纹算法（清单排除本图自身、字节+
#        mtime 行序稳定、SHA-256 取前 16 位），结果写全局 fingerprint。
# Pos: 模块地图 fp-v1 指纹算法模块（票 294：算法独立变更轴）；生成器主件只做发现、
#      解释器与 JSON 组装。
# shellcheck disable=SC2154,SC2034  # 跨件共享状态（调用方上下文与 fingerprint），单文件视野误报

mm_compute_fingerprint() {
# ---- fp-v1 工作区指纹（R-DP-015 算法；输入排除本图自身，避免自引用漂移）----

fp_list=$(cd "$repo_root" && LC_ALL=C find . \
  \( -name .git -o -name node_modules -o -name dist -o -name build -o -name coverage \
     -o -name __pycache__ -o -name .venv -o -path "./$RUNS_DIR_REL" \) -prune -o \
  -type f -print \
  | sed 's|^\./||' | LC_ALL=C sort | grep -v -x -F -e "$out_rel") || fp_list=''

[ -n "$fp_list" ] || die1 '工作区文件清单为空——无法计算 fp-v1 指纹'

IFS=$NL
for rel in ${fp_list}; do
  case ${rel} in
    *"$tab"*) die1 "文件路径含制表符，无法承载指纹行格式: ${rel}" ;;
  esac
  meta=$(stat "$stat_flag" "$stat_fmt" "$repo_root/$rel") || die1 "stat 取文件元数据失败: ${rel}"
  printf '%s' "$meta" | grep -Eq '^[0-9]+ [0-9]+$' || die1 "stat 输出不合预期（非字节/秒对）: ${rel}"
  bytes=${meta%% *}
  mtime=${meta##* }
  printf '%s\t%s\t%s\n' "$rel" "$bytes" "$mtime" >> "$tmp_fp"
done
IFS=$OLDIFS

fp_hex=$(LC_ALL=C ${sha_cmd} < "$tmp_fp" | sed -n 's/.*\([0-9a-f]\{64\}\).*/\1/p' | cut -c1-16)
[ -n "$fp_hex" ] || die1 'SHA-256 计算失败（工具输出未含 64 位十六进制）'
fingerprint="fp-v1:${fp_hex}"
}
