#!/bin/sh
# Input: 同目录被测脚本五件（generate-module-map.sh＋module-map.rules、ticket-ops.sh＋
#        generate-progress.sh、check-package.sh）与参数：--suite/--script-dir/--pkg-root。
#        场景来源＝票 41～45/47 六票 Implementation Checkpoint 的 fixture（只作场景清单）；
#        预期值按被测脚本当前行为独立重建（cmp/逐一相等断言，票 26 教训）。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；夹具全部构建于 mktemp 临时目录
#         并 trap 清理（异常退出亦清）；被测对象只读零改动，真实仓库零写入。
# Pos: 记录层共享回归 harness（票 49 沉淀，产品自检工具随包分发）：缺省自测同目录包内
#      脚本（check-package.sh 同款路径惯例），--script-dir/--pkg-root 参数化支持复制落位
#      语境；四 suite（module-map/ticket-ops/progress/check-package）＋完整运行（--suite
#      all）末尾注入自检；POSIX sh 零外部依赖（夹具 git init 依赖被测脚本自身声明的
#      Git）。用法、suite 覆盖表、退出码与维护规则见同目录 README.md 专节。

set -u
set -f  # 关闭文件名展开：脚本不依赖 glob

SUITE='all'
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 2
PKG_ROOT=''

usage() {
  cat <<'USAGE'
用法: sh test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
参数:
  --suite <name>      module-map | ticket-ops | progress | check-package | all（缺省 all）
  --script-dir <dir>  被测脚本所在目录（须含五件被测成员）；缺省＝本脚本所在目录（缺省自测同目录）
  --pkg-root <dir>    check-package 套件的包根；缺省＝script-dir 的上一级（check-package.sh 同款）
  -h / --help         打印本用法
退出码: 0 全部断言通过；1 存在失败断言（逐项 FAIL 行见输出）；2 用法或环境错误
suite 覆盖场景表与维护规则见同目录 README.md 专节。
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --suite) [ $# -ge 2 ] || { usage >&2; exit 2; }; SUITE=$2; shift 2 ;;
    --script-dir) [ $# -ge 2 ] || { usage >&2; exit 2; }; SCRIPT_DIR=$2; shift 2 ;;
    --pkg-root) [ $# -ge 2 ] || { usage >&2; exit 2; }; PKG_ROOT=$2; shift 2 ;;
    *) printf 'test-record-layer: 未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
case $SUITE in
  module-map|ticket-ops|progress|check-package|all) ;;
  *) printf 'test-record-layer: --suite 不合口径: %s\n' "$SUITE" >&2; usage >&2; exit 2 ;;
esac
[ -d "$SCRIPT_DIR" ] || { printf 'test-record-layer: 被测脚本目录不存在: %s\n' "$SCRIPT_DIR" >&2; exit 2; }
for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh; do
  [ -f "$SCRIPT_DIR/$f" ] || { printf 'test-record-layer: 被测成员缺失: %s/%s\n' "$SCRIPT_DIR" "$f" >&2; exit 2; }
done
if [ -z "$PKG_ROOT" ]; then
  PKG_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd) || exit 2
fi
[ -d "$PKG_ROOT" ] || { printf 'test-record-layer: 包根不存在: %s\n' "$PKG_ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'test-record-layer: git 不可用——module-map/ticket-ops 夹具依赖被测脚本声明的 Git\n' >&2; exit 2; }

# ---- 计数与输出 ----

TOTAL=0
FAILS=0
CUR_SUITE=''

ok() {
  TOTAL=$((TOTAL + 1))
  printf 'PASS  [%s] %s\n' "$CUR_SUITE" "$1"
}

bad() {
  TOTAL=$((TOTAL + 1))
  FAILS=$((FAILS + 1))
  SUITE_FAILS=$((SUITE_FAILS + 1))
  printf 'FAIL  [%s] %s\n' "$CUR_SUITE" "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | sed 's/^/      详情: /'
  fi
}

assert_eq() {
  # $1=场景名 $2=实际文件 $3=预期文件
  if cmp -s "$2" "$3"; then
    ok "$1（逐一相等）"
  else
    bad "$1" "$(diff "$3" "$2" 2>/dev/null | sed -n '2,7p' | tr '\n' '|')"
  fi
}

# ---- 临时目录与清理（票 11/26 纪律：异常退出路径也清）----

T=''
cleanup() { [ -n "$T" ] && rm -rf "$T"; return 0; }
trap cleanup EXIT HUP INT TERM
T=$(mktemp -d "${TMPDIR:-/tmp}/test-record-layer.XXXXXX") || exit 2

# ---- 被测脚本只读副本定位（harness 永不改写被测对象）----

MM="$SCRIPT_DIR/generate-module-map.sh"

# ============================================================
# suite: module-map（票 42/43/44/45 场景沉淀）
# ============================================================

mm_json() {
  # 规范化数组收口行悬挂排版后输出规范化 JSON（仅用于提取，不回写）
  sed -e 's/"[[:space:]]*\][[:space:]]*,\{0,1\}$/"/' -e 's/}[[:space:]]*\][[:space:]]*,\{0,1\}$/}/' "$1"
}

mm_build_fixture() {
  # $1=夹具仓根：11 语言样例（票 42/43/45 场景清单）＋每语言负例（注释/字符串/非法形态）
  R=$1
  rm -rf "$R"
  mkdir -p "$R/src/app" "$R/src/network" "$R/sub"
  touch "$R/util.h" "$R/src/app/widgets.rs" "$R/src/network/client.rs" "$R/util.rs" "$R/type.rs"
  cat > "$R/app.py" <<'EOF'
import os
import requests, flask
import sys;
from mypkg import something
from mypkg.mod import thing
x = "import fake"
EOF
  cat > "$R/app.js" <<'EOF'
import x from 'mod-a'
import "side-effect"
const fs = require('fs')
const s = "import fake from 'nope'"
EOF
  cat > "$R/main.c" <<'EOF'
#include "util.h"
#  include "sub/dir.h"
#include <stdio.h>
EOF
  cat > "$R/main.rs" <<'EOF'
mod util;
mod r#type;
mod ghost;
use std::collections::HashMap;
use crate::app::Widget as W;
use fmt::Result::*;
pub use other::thing;
// use fake::path;
EOF
  cat > "$R/src/app.rs" <<'EOF'
mod widgets;
EOF
  cat > "$R/src/network/mod.rs" <<'EOF'
mod client;
use inner::thing;
EOF
  cat > "$R/main.go" <<'EOF'
package main

import "fmt"
import _ "embed"
import exec "os/exec"

import (
  "net/http"
  alias "golang.org/x/text/transform"
  . "math"
)

func helper() {
  fmt.Println("import fake")
}
// import "fake/pkg"
EOF
  cat > "$R/Main.java" <<'EOF'
import java.util.List;
import static java.lang.Math.abs;
import java.awt.*;
// import fake.pkg.Fake;
String s = "import fake.pkg;";
EOF
  cat > "$R/Program.cs" <<'EOF'
using System.Collections.Generic;
using static System.Math;
using var x = GetThing();
using Foo = Bar.Baz;
EOF
  cat > "$R/app.rb" <<'EOF'
require 'json'
require "json"
require('set')
require_relative 'lib/helper'
# require 'fake'
require_fake "x"
EOF
  cat > "$R/index.php" <<'EOF'
use App\Models\User;
use App\Services\Billing as Bill;
use function App\helpers\do_thing;
use App\{Models, Services};
use \App\Root;
require "config.php";
require_once "vendor/autoload.php";
include 'lang/en.php';
// use Fake\Thing;
EOF
  cat > "$R/app.swift" <<'EOF'
import Foundation
@testable import AppCore
@_exported import SharedKit
export import PublicKit
import struct MyMod.MyStruct
// import FakeKit
EOF
  cat > "$R/main.kt" <<'EOF'
import kotlin.math.sqrt
import java.util.ArrayList as AL
import kotlinx.coroutines.*
import com.example.Foo;
import `weird name`.Foo
// import fake.pkg
EOF
  cat > "$R/build.kts" <<'EOF'
import something.else
EOF
  git -C "$R" init >/dev/null 2>&1
}

mm_expected_nodes() {
  # 独立重建：夹具仓登记扩展名源码文件全集（19 个，nodes 语义＝已扫描源码文件）
  printf '%s\n' \
    'Main.java' 'Program.cs' 'app.js' 'app.py' 'app.rb' 'app.swift' 'build.kts' \
    'index.php' 'main.c' 'main.go' 'main.kt' 'main.rs' 'src/app.rs' \
    'src/app/widgets.rs' 'src/network/client.rs' 'src/network/mod.rs' 'type.rs' \
    'util.h' 'util.rs'
}

mm_expected_edges() {
  # 独立重建：11 语言边集 50 条（规则表逐行人工推导；每语言含去重/注释/字符串负例；
  # rust 含 r# 两制＋mod 保留名目录/同名子目录两候选＋ghost 零边；php 含 JSON 反斜杠转义）
  cat <<'EOF'
Main.java	java.util.List	java-import
Main.java	java.lang.Math.abs	java-import
Main.java	java.awt	java-import
Program.cs	System.Collections.Generic	csharp-using
Program.cs	System.Math	csharp-using
app.js	mod-a	js-import
app.js	side-effect	js-import
app.js	fs	js-require
app.py	os	python-import
app.py	requests	python-import
app.py	flask	python-import
app.py	sys	python-import
app.py	mypkg	python-from
app.py	mypkg.mod	python-from
app.rb	json	ruby-require
app.rb	set	ruby-require
app.rb	lib/helper	ruby-require-relative
app.swift	Foundation	swift-import
app.swift	AppCore	swift-import
app.swift	SharedKit	swift-import
app.swift	PublicKit	swift-import
app.swift	MyMod.MyStruct	swift-import
build.kts	something.else	kotlin-import
index.php	App\\Models\\User	php-use
index.php	App\\Services\\Billing	php-use
index.php	App\\helpers\\do_thing	php-use
index.php	config.php	php-require
index.php	vendor/autoload.php	php-require
index.php	lang/en.php	php-require
main.c	util.h	c-include
main.c	sub/dir.h	c-include
main.go	fmt	go-import
main.go	embed	go-import
main.go	os/exec	go-import
main.go	net/http	go-import
main.go	golang.org/x/text/transform	go-import
main.go	math	go-import
main.kt	kotlin.math.sqrt	kotlin-import
main.kt	java.util.ArrayList	kotlin-import
main.kt	kotlinx.coroutines	kotlin-import
main.kt	com.example.Foo	kotlin-import
main.rs	util.rs	rust-mod
main.rs	type.rs	rust-mod
main.rs	std::collections::HashMap	rust-use
main.rs	crate::app::Widget	rust-use
main.rs	fmt::Result	rust-use
main.rs	other::thing	rust-use
src/app.rs	src/app/widgets.rs	rust-mod
src/network/mod.rs	src/network/client.rs	rust-mod
src/network/mod.rs	inner::thing	rust-use
EOF
}

suite_module_map() {
  CUR_SUITE='module-map'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/mm
  mkdir -p "$D"
  mm_build_fixture "$D/repo"

  out=$(sh "$MM" "$D/repo" 2>"$D/err1")
  rc=$?
  [ "$rc" -eq 0 ] && ok '正例生成 exit 0（11 语言夹具仓）' || bad '正例生成 exit 0（11 语言夹具仓）' "exit=$rc stderr=$(head -n 1 "$D/err1")"

  summary=$(printf '%s\n' "$out" | sed -n 's/^generate-module-map: OK: .*（fp-v1:[0-9a-f]\{16\}，nodes \([0-9]\{1,\}\)，edges \([0-9]\{1,\}\)）$/\1 \2/p')
  [ "$summary" = '19 50' ] && ok 'stdout 摘要计数（nodes 19，edges 50）' || bad 'stdout 摘要计数（nodes 19，edges 50）' "实际: $summary"

  map="$D/repo/docs/architecture/module-map.json"
  mm_json "$map" > "$D/norm.json"
  sed -n 's/^    "\([^"]*\)"[[:space:]]*,\{0,1\}$/\1/p' "$D/norm.json" | LC_ALL=C sort > "$D/nodes.actual"
  mm_expected_nodes | LC_ALL=C sort > "$D/nodes.expected"
  assert_eq 'nodes 清单逐一相等（19 个源码文件）' "$D/nodes.actual" "$D/nodes.expected"

  sed -n 's/^    {"from": "\([^"]*\)", "to": "\([^"]*\)", "label": "\([^"]*\)"}[[:space:]]*,\{0,1\}$/\1\t\2\t\3/p' "$D/norm.json" | LC_ALL=C sort > "$D/edges.actual"
  mm_expected_edges | LC_ALL=C sort > "$D/edges.expected"
  assert_eq '11 语言边集逐一相等（50 条，含 direct-file 存在性过滤与去重）' "$D/edges.actual" "$D/edges.expected"

  fp1=$(sed -n 's/^  "workspace_fingerprint": "\(fp-v1:[0-9a-f]\{16\}\)",\{0,1\}$/\1/p' "$D/norm.json")
  case $fp1 in
    fp-v1:????????????????) ok 'fp-v1 形状（fp-v1:16 位十六进制）' ;;
    *) bad 'fp-v1 形状（fp-v1:16 位十六进制）' "实际: $fp1" ;;
  esac

  sh "$MM" "$D/repo" >/dev/null 2>&1
  fp2=$(sed -n 's/^  "workspace_fingerprint": "\(fp-v1:[0-9a-f]\{16\}\)",\{0,1\}$/\1/p' "$D/repo/docs/architecture/module-map.json")
  [ -n "$fp1" ] && [ "$fp1" = "$fp2" ] && ok 'fp 稳定性（同输入复跑指纹不变）' || bad 'fp 稳定性（同输入复跑指纹不变）' "$fp1 vs $fp2"

  printf '\n' >> "$D/repo/app.py"
  sh "$MM" "$D/repo" >/dev/null 2>&1
  fp3=$(sed -n 's/^  "workspace_fingerprint": "\(fp-v1:[0-9a-f]\{16\}\)",\{0,1\}$/\1/p' "$D/repo/docs/architecture/module-map.json")
  [ -n "$fp3" ] && [ "$fp1" != "$fp3" ] && ok 'fp 变更检出（内容改动后指纹变化）' || bad 'fp 变更检出（内容改动后指纹变化）' "$fp1 vs $fp3"

  # 负例 N1：规则表损坏 → exit 2 且不写地图（临时副本上结构破坏：mm_rule 参数数不合预期，
  # 被测本体零触碰；行为级破坏——label 漂移——由注入自检与边集断言承载）
  mkdir -p "$D/broken"
  cp "$SCRIPT_DIR/generate-module-map.sh" "$D/broken/"
  cp "$SCRIPT_DIR/module-map.rules" "$D/broken/module-map.rules"
  printf "mm_rule 'bogus-lang' '*.py'\n" >> "$D/broken/module-map.rules"
  rm -rf "$D/repo2"; mm_build_fixture "$D/repo2"
  sh "$D/broken/generate-module-map.sh" "$D/repo2" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -f "$D/repo2/docs/architecture/module-map.json" ]; then
    ok '负例 N1 规则表损坏 → exit 2 且零地图写入'
  else
    bad '负例 N1 规则表损坏 → exit 2 且零地图写入' "exit=$rc"
  fi

  # 负例 N2：无已登记源码 → exit 1 且不写地图
  mkdir -p "$D/empty"; git -C "$D/empty" init >/dev/null 2>&1
  sh "$MM" "$D/empty" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -f "$D/empty/docs/architecture/module-map.json" ]; then
    ok '负例 N2 无源码 → exit 1 且零地图写入（fail-closed）'
  else
    bad '负例 N2 无源码 → exit 1 且零地图写入（fail-closed）' "exit=$rc"
  fi

  # 负例 N3：非 Git 目录 → exit 2
  mkdir -p "$D/nogit"
  sh "$MM" "$D/nogit" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N3 非 Git 目录 → exit 2' || bad '负例 N3 非 Git 目录 → exit 2' "exit=$rc"

  suite_summary 'module-map'
}

# ============================================================
# suite: ticket-ops（票 41/47 场景沉淀：生成项目语境全链＋fail-closed 负例）
# ============================================================

tix_build_fixture() {
  # $1=夹具项目根（生成项目语境：scripts/ 落位两件，docs/issues 三载体就绪）
  F=$1
  rm -rf "$F"
  mkdir -p "$F/scripts" "$F/docs/issues"
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$F/scripts/"
  cat > "$F/docs/issues/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},
    {"id": "20-beta-second", "status": "ready", "complexity": "C2", "blocked_by": [], "updated_at": "2026-09-19T11:00"}
  ]
}
EOF
  cat > "$F/docs/issues/README.md" <<'EOF'
# 票据索引（fixture）

| 名字 | 状态 | 说明 |
| --- | --- | --- |
| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |
| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |
EOF
  cat > "$F/docs/changes.jsonl" <<'EOF'
{"date": "2026-09-19", "kind": "scope", "scope": "docs/issues", "decision": "fixture seed", "evidence_ref": "docs/issues/index.json"}
EOF
}

tix_state() {
  # 夹具四载体状态指纹（负例零写入断言用）
  {
    cksum "$1/docs/issues/index.json" "$1/docs/issues/README.md" "$1/docs/changes.jsonl"
    if [ -f "$1/docs/progress-current.md" ]; then cksum "$1/docs/progress-current.md"; else printf 'no-projection\n'; fi
  } | cksum
}

tix_norm_progress() {
  sed 's|^<!-- generated_at: .*-->$|<!-- generated_at: NORMALIZED -->|' "$1"
}

tix_expected_progress() {
  # 独立重建：三票投影全文（generated_at 行规范化；按 id 升序）
  cat <<'EOF'
<!-- generated_from: docs/issues/index.json + scripts/generate-progress.sh -->
<!-- generated_at: NORMALIZED -->
<!-- coverage: docs/issues/index.json 登记的全部票，每票一行，按 id 升序 -->
<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 docs/issues/index.json 不一致时以索引为准 -->

# 现役状态投影（Derived）

| id | status | checkpoint_ref | updated_at |
| --- | --- | --- | --- |
EOF
  printf '%s\n' \
    '| 10-alpha-first | done |  | 2026-09-19T10:00 |' \
    "| 20-beta-second | $1 |  | $2 |" \
    "| 30-gamma-third | $3 |  | $4 |" | LC_ALL=C sort
}

tix_expect_full() {
  # $1=夹具根 $2=repo30状态 $3=repo30时间 $4=repo20状态 $5=repo20时间 $6=README行30 $7=README行20 $8=账本行数
  F=$1
  {
    printf '{\n  "issues": [\n'
    printf '    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T10:00"},\n'
    printf '    {"id": "20-beta-second", "status": "%s", "complexity": "C2", "blocked_by": [], "updated_at": "%s"},\n' "$4" "$5"
    printf '    {"id": "30-gamma-third", "status": "%s", "complexity": "C1", "blocked_by": [], "updated_at": "%s"}\n' "$2" "$3"
    printf '  ]\n}\n'
  } > "$F/exp.index.json"
  assert_eq '索引全文件逐一相等（一条目一行，id 锚点单写）' "$F/docs/issues/index.json" "$F/exp.index.json"

  {
    printf '# 票据索引（fixture）\n\n| 名字 | 状态 | 说明 |\n| --- | --- | --- |\n'
    printf '| `10-alpha-first.json` | 任务票 10；`done`（2026-09-19 开票） | Alpha fixture ticket |\n'
    printf '%s\n' "$7"
    printf '%s\n' "$6"
  } > "$F/exp.readme.md"
  assert_eq 'issues-README 全文件逐一相等（状态 token 单替换，其余文本不动）' "$F/docs/issues/README.md" "$F/exp.readme.md"

  tix_expected_progress "$4" "$5" "$2" "$3" > "$F/exp.progress.md"
  tix_norm_progress "$F/docs/progress-current.md" > "$F/act.progress.md"
  assert_eq '投影全文件逐一相等（generated_at 规范化后 cmp，票 35 三路径口径）' "$F/act.progress.md" "$F/exp.progress.md"

  n=$(wc -l < "$F/docs/changes.jsonl" | tr -d ' ')
  [ "$n" -eq "$8" ] && ok "账本行数＝$8（一行一事实，追加不重写）" || bad "账本行数＝$8（一行一事实，追加不重写）" "实际 $n"
}

suite_ticket_ops() {
  CUR_SUITE='ticket-ops'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/tix
  mkdir -p "$D"
  tix_build_fixture "$D/fix"
  F=$D/fix

  LED_OPEN='{"date": "2026-09-20", "kind": "scope", "scope": "docs/issues", "decision": "fixture open 30", "evidence_ref": "docs/issues/30-gamma-third.json"}'
  LED_TAKE='{"date": "2026-09-20", "kind": "scope", "scope": "docs/issues", "decision": "fixture take 30", "evidence_ref": "docs/issues/30-gamma-third.json"}'
  LED_FLIP='{"date": "2026-09-20", "kind": "scope", "scope": "docs/issues", "decision": "fixture flip 20", "evidence_ref": "docs/issues/20-beta-second.json"}'

  # ---- 正例全链：open → take → flip（生成项目语境：缺省 repo-root＝脚本所在目录上一级）----
  sh "$F/scripts/ticket-ops.sh" open --id 30-gamma-third --complexity C1 --title 'Gamma fixture ticket' --ledger-line "$LED_OPEN" >"$D/open.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok 'open exit 0（生成项目语境，缺省根＝落位 scripts/ 上一级）' || bad 'open exit 0（生成项目语境，缺省根＝落位 scripts/ 上一级）' "exit=$rc $(head -n 2 "$D/open.log" | tr '\n' '|')"

  UA30=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/docs/issues/index.json" | tail -n 1)
  case $UA30 in
    ????-??-??T??:??) ;;
    *) bad 'open 后索引条目 updated_at 形状（YYYY-MM-DDTHH:MM）' "实际: $UA30" ;;
  esac
  TODAY=$(sed -n 's/.*（\(20[0-9-]*\) 开票）.*/\1/p' "$F/docs/issues/README.md" | tail -n 1)
  case $TODAY in
    20??-??-??) ;;
    *) bad 'open 后 README 行开票日期形状' "实际: $TODAY" ;;
  esac
  ROW30='| `30-gamma-third.json` | 任务票 30；`ready`（'"$TODAY"' 开票） | Gamma fixture ticket |'
  tix_expect_full "$F" 'ready' "$UA30" 'ready' '2026-09-19T11:00' "$ROW30" '| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |' 2

  sh "$F/scripts/ticket-ops.sh" take --id 30-gamma-third --status in_progress --ledger-line "$LED_TAKE" >"$D/take.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok 'take exit 0（领取语义 status=in_progress）' || bad 'take exit 0（领取语义 status=in_progress）' "exit=$rc $(head -n 2 "$D/take.log" | tr '\n' '|')"
  UA30B=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/docs/issues/index.json" | tail -n 1)
  ROW30B='| `30-gamma-third.json` | 任务票 30；`in_progress`（'"$TODAY"' 开票） | Gamma fixture ticket |'
  tix_expect_full "$F" 'in_progress' "$UA30B" 'ready' '2026-09-19T11:00' "$ROW30B" '| `20-beta-second.json` | 任务票 20；`ready`（2026-09-19 开票） | Beta fixture ticket |' 3

  sh "$F/scripts/ticket-ops.sh" flip --id 20-beta-second --status review_ready --ledger-line "$LED_FLIP" >"$D/flip.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok 'flip exit 0（状态机任意合法值翻转）' || bad 'flip exit 0（状态机任意合法值翻转）' "exit=$rc $(head -n 2 "$D/flip.log" | tr '\n' '|')"
  UA20=$(sed -n 's/.*"updated_at": "\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}\)".*/\1/p' "$F/docs/issues/index.json" | sed -n '2p')
  ROW20B='| `20-beta-second.json` | 任务票 20；`review_ready`（2026-09-19 开票） | Beta fixture ticket |'
  tix_expect_full "$F" 'in_progress' "$UA30B" 'review_ready' "$UA20" "$ROW30B" "$ROW20B" 4

  sh "$F/scripts/generate-progress.sh" --check "$F" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok '收尾投影 --check exit 0（全链后一致性核对）' || bad '收尾投影 --check exit 0（全链后一致性核对）' "exit=$rc"

  # ---- 负例（fail-closed 零写入；N5 用独立夹具）----
  S0=$(tix_state "$F")
  sh "$F/scripts/ticket-ops.sh" open --id 10-alpha-first --complexity C1 --title dup --ledger-line "$LED_OPEN" >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ] && ok '负例 N1 重复 id open → exit 1 零写入（open 非幂等）' || bad '负例 N1 重复 id open → exit 1 零写入（open 非幂等）' "exit/状态不符"
  sh "$F/scripts/ticket-ops.sh" flip --id 99-ghost-none --status done --ledger-line "$LED_FLIP" >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ] && ok '负例 N2 未知 id flip → exit 1 零写入' || bad '负例 N2 未知 id flip → exit 1 零写入' "exit/状态不符"
  sh "$F/scripts/ticket-ops.sh" open --id 40-delta-fourth --complexity C0 --title d --ledger-line '{"kind": "scope", "date": "2026-09-20", "scope": "x", "decision": "bad-order", "evidence_ref": "y"}' >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ] && ok '负例 N3 账本键序违规 → exit 1 零写入' || bad '负例 N3 账本键序违规 → exit 1 零写入' "exit/状态不符"
  sh "$F/scripts/ticket-ops.sh" take --id 20-beta-second --status ready --ledger-line "$LED_FLIP" >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ] && ok '负例 N4 take 非 in_progress → exit 1 零写入' || bad '负例 N4 take 非 in_progress → exit 1 零写入' "exit/状态不符"
  sh "$F/scripts/ticket-ops.sh" flip --id 20-beta-second --status bogus_status --ledger-line "$LED_FLIP" >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S0" = "$(tix_state "$F")" ] && ok '负例 N6 非法状态值 → exit 1 零写入' || bad '负例 N6 非法状态值 → exit 1 零写入' "exit/状态不符"

  # N5：索引一条目一行排版破坏（条目缺 updated_at）→ 预检停止，零写入且无投影
  tix_build_fixture "$D/fix5"
  F5=$D/fix5
  sed 's/"updated_at": "2026-09-19T10:00"/"note": "排版破坏"/' "$F5/docs/issues/index.json" > "$F5/idx.tmp" && mv "$F5/idx.tmp" "$F5/docs/issues/index.json"
  S5=$(tix_state "$F5")
  sh "$F5/scripts/ticket-ops.sh" open --id 40-delta-fourth --complexity C0 --title d --ledger-line "$LED_OPEN" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S5" = "$(tix_state "$F5")" ] && [ ! -f "$F5/docs/progress-current.md" ]; then
    ok '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）'
  else
    bad '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）' "exit=$rc"
  fi

  suite_summary 'ticket-ops'
}

# ============================================================
# suite: progress（票 35 场景沉淀：生成/--check/篡改检出/fail-closed）
# ============================================================

suite_progress() {
  CUR_SUITE='progress'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/prog
  mkdir -p "$D"
  P=$D/fix
  mkdir -p "$P/docs/issues"
  cat > "$P/docs/issues/index.json" <<'EOF'
{
  "issues": [
    {"id": "12-yankee-first", "status": "in_progress", "complexity": "C1", "blocked_by": [], "updated_at": "2026-09-19T12:00"},
    {"id": "03-zulu-third", "status": "ready", "complexity": "C0", "blocked_by": [], "updated_at": "2026-09-19T08:00"},
    {"id": "07-xray-second", "status": "review_pass", "complexity": "C2", "blocked_by": ["03-zulu-third"], "checkpoint_ref": "docs/agent/runs/20260918-t07impl.json", "updated_at": "2026-09-19T09:30"}
  ]
}
EOF
  sh "$SCRIPT_DIR/generate-progress.sh" "$P" >"$D/gen.log" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok '生成 exit 0（乱序 id 索引）' || bad '生成 exit 0（乱序 id 索引）' "exit=$rc $(head -n 1 "$D/gen.log")"

  {
    printf '<!-- generated_from: docs/issues/index.json + scripts/generate-progress.sh -->\n'
    printf '<!-- generated_at: NORMALIZED -->\n'
    printf '<!-- coverage: docs/issues/index.json 登记的全部票，每票一行，按 id 升序 -->\n'
    printf '<!-- invalidation: 本文件为 Derived 投影，可由生成器整文件重建；与 docs/issues/index.json 不一致时以索引为准 -->\n'
    printf '\n# 现役状态投影（Derived）\n\n'
    printf '| id | status | checkpoint_ref | updated_at |\n'
    printf '| --- | --- | --- | --- |\n'
    printf '%s\n' \
      '| 03-zulu-third | ready |  | 2026-09-19T08:00 |' \
      '| 07-xray-second | review_pass | docs/agent/runs/20260918-t07impl.json | 2026-09-19T09:30 |' \
      '| 12-yankee-first | in_progress |  | 2026-09-19T12:00 |' | LC_ALL=C sort
  } > "$D/exp.md"
  tix_norm_progress "$P/docs/progress-current.md" > "$D/act.md"
  assert_eq '投影全文件逐一相等（含 checkpoint_ref 列与空单元格，generated_at 规范化）' "$D/act.md" "$D/exp.md"

  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok '--check 一致 exit 0（dry-run 不写）' || bad '--check 一致 exit 0（dry-run 不写）' "exit=$rc"

  sed 's/| ready |/| done |/' "$P/docs/progress-current.md" > "$D/tamper.tmp" && mv "$D/tamper.tmp" "$P/docs/progress-current.md"
  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 1 ] && ok '篡改检出 → --check exit 1（投影 stale）' || bad '篡改检出 → --check exit 1（投影 stale）' "exit=$rc"

  rm -f "$P/docs/progress-current.md"
  sh "$SCRIPT_DIR/generate-progress.sh" --check "$P" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 1 ] && ok '投影缺失 → --check exit 1（先运行生成器落盘）' || bad '投影缺失 → --check exit 1（先运行生成器落盘）' "exit=$rc"

  mkdir -p "$D/noindex/docs/issues"
  sh "$SCRIPT_DIR/generate-progress.sh" "$D/noindex" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '索引缺失 → exit 2（fail-closed 不写投影）' || bad '索引缺失 → exit 2（fail-closed 不写投影）' "exit=$rc"

  mkdir -p "$D/badidx/docs/issues"
  cat > "$D/badidx/docs/issues/index.json" <<'EOF'
{
  "issues": [
    {"id": "10-alpha-first", "status": "done", "complexity": "C1", "blocked_by": []}
  ]
}
EOF
  sh "$SCRIPT_DIR/generate-progress.sh" "$D/badidx" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '条目行缺必备字段（updated_at）→ exit 2' || bad '条目行缺必备字段（updated_at）→ exit 2' "exit=$rc"

  suite_summary 'progress'
}

# ============================================================
# suite: check-package（票 12/48 场景沉淀：八项正例＋必需件缺失负例）
# ============================================================

suite_check_package() {
  CUR_SUITE='check-package'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/cpkg
  mkdir -p "$D"

  cat > "$D/exp.positive" <<'EOF'
PASS: 1 必需入口存在（16 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 13 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
PASS: 8 脚本必需件存在（8 个文件）
check-package: PASS
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$PKG_ROOT" >"$D/act.positive" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok "正例 exit 0（包根＝${PKG_ROOT}）" || bad "正例 exit 0（包根＝${PKG_ROOT}）" "exit=$rc"
  assert_eq '正例输出逐行逐一相等（八项 PASS＋汇总，含票 48 检查项 8）' "$D/act.positive" "$D/exp.positive"

  cp -R "$PKG_ROOT" "$D/pkgcopy"
  rm -f "$D/pkgcopy/scripts/generate-progress.sh"
  cat > "$D/exp.negative" <<'EOF'
PASS: 1 必需入口存在（16 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 13 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
FAIL: 8 脚本必需件存在（8 个文件） —   - scripts/generate-progress.sh
check-package: FAIL（1 项未通过，共 8 项）
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy" >"$D/act.negative" 2>&1
  rc=$?
  [ "$rc" -eq 1 ] && ok '负例 exit 1（副本删必需件，mktemp 副本纪律）' || bad '负例 exit 1（副本删必需件，mktemp 副本纪律）' "exit=$rc"
  assert_eq '负例输出逐一相等（fail-closed 指名缺失件，不因部分存在放宽）' "$D/act.negative" "$D/exp.negative"

  suite_summary 'check-package'
}

# ============================================================
# 注入自检（仅 --suite all）：临时副本上故意破坏一处，harness 必须抓住
# ============================================================

self_check_injection() {
  CUR_SUITE='self-check'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/inject
  mkdir -p "$D/injectpkg/scripts"
  for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh; do
    cp "$SCRIPT_DIR/$f" "$D/injectpkg/scripts/$f"
  done
  sed 's/~python-import~/~python-importX~/' "$SCRIPT_DIR/module-map.rules" > "$D/rules.tmp" && mv "$D/rules.tmp" "$D/injectpkg/scripts/module-map.rules"
  sh "$0" --suite module-map --script-dir "$D/injectpkg/scripts" >"$D/out.log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    ok '注入自检 exit 非零（harness 抓住临时副本上的边集破坏）'
  else
    bad '注入自检 exit 非零（harness 抓住临时副本上的边集破坏）' '注入运行意外通过'
  fi
  if grep -q '^FAIL' "$D/out.log"; then
    ok '注入自检输出含 FAIL 逐项行（失败可定位）'
  else
    bad '注入自检输出含 FAIL 逐项行（失败可定位）' '无 FAIL 行'
  fi
  suite_summary 'self-check'
}

# ---- 汇总 ----

suite_summary() {
  n=$((TOTAL - SUITE_START))
  if [ "$SUITE_FAILS" -eq 0 ]; then
    printf 'test-record-layer: [%s] 断言 %d/%d 通过\n' "$1" "$n" "$n"
  else
    printf 'test-record-layer: [%s] 断言 %d/%d 通过（%d 失败）\n' "$1" "$((n - SUITE_FAILS))" "$n" "$SUITE_FAILS"
  fi
}

printf 'test-record-layer: suite=%s scripts=%s pkg-root=%s\n' "$SUITE" "$SCRIPT_DIR" "$PKG_ROOT"

case $SUITE in
  module-map) suite_module_map ;;
  ticket-ops) suite_ticket_ops ;;
  progress) suite_progress ;;
  check-package) suite_check_package ;;
  all)
    suite_module_map
    suite_ticket_ops
    suite_progress
    suite_check_package
    self_check_injection
    ;;
esac

if [ "$FAILS" -eq 0 ]; then
  printf 'test-record-layer: PASS（共 %d 项断言，全部通过）\n' "$TOTAL"
  exit 0
fi
printf 'test-record-layer: FAIL（共 %d 项断言，%d 项失败）\n' "$TOTAL" "$FAILS"
exit 1
