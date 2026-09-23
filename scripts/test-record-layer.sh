#!/bin/sh
# Input: 同目录被测脚本八件（generate-module-map.sh＋module-map.rules、ticket-ops.sh＋
#        generate-progress.sh、check-package.sh、check-append-only.sh、check-artifacts.sh、
#        check-stale-claims.sh）与参数：--suite/--script-dir/--pkg-root。
#        场景来源＝票 41～45/47 六票 Implementation Checkpoint 的 fixture（只作场景清单）；
#        预期值按被测脚本当前行为独立重建（cmp/逐一相等断言，票 26 教训）；票 56 检查 8
#        清单 8→10 件（追加 install.sh＋install-policy.rules），check-package 套件预期串
#        同步（协调层改判：同步不做推迟）；票 57 包清单数据化（check-package 检查 1/5/8
#        改读 package-manifest.rules 数据＋新增检查 9/10/11），预期串同步十一项口径——
#        正例含新增三查 PASS 行，负例（删 generate-progress.sh）联动检查 9 双 FAIL；
#        协调层改判随票修：检查 11 逐处全等，补 capability-contract §2.5 单处删值负例；
#        票 58 检查 11→13（12＝模糊措辞扫描，13＝镜像 cmp），预期串同步十三项口径并补
#        注入/豁免/镜像负例；新增 append-only 套件（check-append-only.sh 正负例，
#        选定独立 suite 承载并在 README 声明）；票 59 检查 13→14（14＝能力映射一致性），
#        预期串同步十四项口径并补注入未登记基元/删基元负例；新增 check-artifacts 套件
#        （治理产物对账正负例，独立 suite 承载并在 README 声明）；票 60 检查 14→17
#        （15＝模板 §16 规则索引与规则块全集全等、16＝索引机制列受控词表、17＝机械行
#        点名出处存在），check-append-only.sh/check-artifacts.sh 补登记清单 scripts 节
#        （10→12 件），预期串同步十七项口径并补索引删行/加全集外 ID/未登记机制值/
#        机械行点名不存在脚本/检查项号超界/外定义行删标记词负例＋mechanism-vocab
#        词表损坏 exit 2 负例；票 72 清单 scripts 节 12→13 件（export-payload.sh 入册），
#        检查 8 预期串计数随动；新增 stale-claims 套件（S1/S2 配置点亮：未点亮 SKIP
#        不计数、点亮按配置断言、delivery.rules 解析破坏 exit 2、汇总登记数动态化，
#        独立 suite 承载并在 README 声明）；票 77（NN 唯一性：ticket-ops open 补同 NN 异
#        slug 撞号拒开 fail-closed，套件补 N7 同 NN 拒＋N8 畸形 id 拒＋新 NN 正开三断言，
#        正例本体随票 79 前置校验落位）；票 79 ticket-ops 套件加 open 本体 schema 校验
#        ＋理由非空断言（正例夹具落位含理由两字段的本体照旧放过；负例＝缺
#        complexity_reason／priority_reason 空值／缺本体文件，均 exit 1 零写入；夹具增
#        schema 权威落位，python3 列为套件环境依赖）。
# Output: 逐项 PASS/FAIL 行与计数汇总（任一失败 exit 1）；夹具全部构建于 mktemp 临时目录
#         并 trap 清理（异常退出亦清）；被测对象只读零改动，真实仓库零写入。
# Pos: 记录层共享回归 harness（票 49 沉淀，产品自检工具随包分发）：缺省自测同目录包内
#      脚本（check-package.sh 同款路径惯例），--script-dir/--pkg-root 参数化支持复制落位
#      语境；七 suite（module-map/ticket-ops/progress/check-package/append-only/
#      check-artifacts/stale-claims）＋完整运行（--suite all）末尾注入自检；POSIX sh 零外部
#      依赖（夹具 git init/commit 依赖被测脚本自身声明的 Git）。用法、suite 覆盖表、退出码
#      与维护规则见同目录 README.md 专节。

set -u
set -f  # 关闭文件名展开：脚本不依赖 glob

SUITE='all'
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 2
PKG_ROOT=''

usage() {
  cat <<'USAGE'
用法: sh test-record-layer.sh [--suite <name>] [--script-dir <dir>] [--pkg-root <dir>]
参数:
  --suite <name>      module-map | ticket-ops | progress | check-package | append-only | check-artifacts | stale-claims | all（缺省 all）
  --script-dir <dir>  被测脚本所在目录（须含八件被测成员）；缺省＝本脚本所在目录（缺省自测同目录）
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
  module-map|ticket-ops|progress|check-package|append-only|check-artifacts|stale-claims|all) ;;
  *) printf 'test-record-layer: --suite 不合口径: %s\n' "$SUITE" >&2; usage >&2; exit 2 ;;
esac
[ -d "$SCRIPT_DIR" ] || { printf 'test-record-layer: 被测脚本目录不存在: %s\n' "$SCRIPT_DIR" >&2; exit 2; }
for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh; do
  [ -f "$SCRIPT_DIR/$f" ] || { printf 'test-record-layer: 被测成员缺失: %s/%s\n' "$SCRIPT_DIR" "$f" >&2; exit 2; }
done
if [ -z "$PKG_ROOT" ]; then
  PKG_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd) || exit 2
fi
[ -d "$PKG_ROOT" ] || { printf 'test-record-layer: 包根不存在: %s\n' "$PKG_ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'test-record-layer: git 不可用——module-map/ticket-ops 夹具依赖被测脚本声明的 Git\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'test-record-layer: python3 不可用——ticket-ops 套件 open 本体 schema 校验依赖（票 79）\n' >&2; exit 2; }

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

tix_body() {
  # $1=本体落盘路径 $2=票 id：最小过 schema 的 task 票本体（含理由两字段，票 79 正例形态；
  # 字段各占一行便于负例 sed 逐字段破坏）
  cat > "$1" <<EOF
{
  "id": "$2",
  "kind": "task",
  "title": "fixture ticket $2",
  "created_at": "2026-09-19",
  "complexity": "C1",
  "profile": "D:Required,B:Required,I:Required,U:N/A,S:N/A,M:N/A,O:N/A",
  "blocked_by": [],
  "complexity_reason": "fixture 定级理由（正例，非空）",
  "priority_reason": "fixture 优先级理由（正例，非空）"
}
EOF
}

tix_build_fixture() {
  # $1=夹具项目根（生成项目语境：scripts/ 落位两件，docs/issues 三载体就绪；
  # 票 79 起另落位 schema 权威与被 open 票的本体文件）
  F=$1
  rm -rf "$F"
  mkdir -p "$F/scripts" "$F/docs/issues"
  cp "$SCRIPT_DIR/ticket-ops.sh" "$SCRIPT_DIR/generate-progress.sh" "$F/scripts/"
  SCHEMA_SRC="${SCRIPT_DIR}/../references/schemas/ticket-record.schema.json"
  [ -f "$SCHEMA_SRC" ] || { printf 'test-record-layer: 夹具依赖缺失: %s（ticket-ops open 本体校验的 schema 权威）\n' "$SCHEMA_SRC" >&2; exit 2; }
  mkdir -p "$F/agent-up/references/schemas"
  cp "$SCHEMA_SRC" "$F/agent-up/references/schemas/ticket-record.schema.json"
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
  # 票 79：被 open 票的本体文件落位（正例 30 全链＋负例 N1 的 10／N3 的 40，
  # 保证各负例仍命中原语义路径而非被本体缺失提前拦截）
  tix_body "$F/docs/issues/30-gamma-third.json" 30-gamma-third
  tix_body "$F/docs/issues/10-alpha-first.json" 10-alpha-first
  tix_body "$F/docs/issues/40-delta-fourth.json" 40-delta-fourth

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
  tix_body "$F5/docs/issues/40-delta-fourth.json" 40-delta-fourth
  sed 's/"updated_at": "2026-09-19T10:00"/"note": "排版破坏"/' "$F5/docs/issues/index.json" > "$F5/idx.tmp" && mv "$F5/idx.tmp" "$F5/docs/issues/index.json"
  S5=$(tix_state "$F5")
  sh "$F5/scripts/ticket-ops.sh" open --id 40-delta-fourth --complexity C0 --title d --ledger-line "$LED_OPEN" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S5" = "$(tix_state "$F5")" ] && [ ! -f "$F5/docs/progress-current.md" ]; then
    ok '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）'
  else
    bad '负例 N5 索引排版破坏 → exit 1 零写入且无投影（fail-closed 预检先于写入）' "exit=$rc"
  fi

  # N7/N8/正例：独立夹具（tix_build_fixture 会重赋 F，勿依赖前段 F 指向）——
  # 同 NN 异 slug 撞号拒开（票 77，账本 renumber-70-72 缺口）＋畸形 id 一并拒＋新 NN 正开零回归
  tix_build_fixture "$D/fix7"
  F7=$D/fix7
  S7=$(tix_state "$F7")
  # 票 79 起本体校验前置：gamma-clone 本体先落位（tix_body 正例形态含理由两字段），流程方能到达 NN 段查重
  tix_body "$F7/docs/issues/20-gamma-clone.json" 20-gamma-clone
  sh "$F7/scripts/ticket-ops.sh" open --id 20-gamma-clone --complexity C1 --title d --ledger-line "$LED_OPEN" >"$D/nn7.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S7" = "$(tix_state "$F7")" ] && grep -q '20-beta-second' "$D/nn7.log"; then
    ok '负例 N7 同 NN 异 slug open → exit 1 零写入且报明已占完整 id（票 77 NN 唯一性）'
  else
    bad '负例 N7 同 NN 异 slug open → exit 1 零写入且报明已占完整 id（票 77 NN 唯一性）' "exit=$rc $(head -n 2 "$D/nn7.log" | tr '\n' '|')"
  fi

  # N8：畸形 id（NN 段不合 ^[0-9]{2,}-）→ 一并拒，零写入（NN 段提取与 id 正则一致，防绕过段查重）
  sh "$F7/scripts/ticket-ops.sh" open --id 7-short-nn --complexity C1 --title d --ledger-line "$LED_OPEN" >/dev/null 2>&1
  [ "$?" -eq 1 ] && [ "$S7" = "$(tix_state "$F7")" ] && ok '负例 N8 畸形 id（个位 NN 段）open → exit 1 零写入（id 口径门先拦）' || bad '负例 N8 畸形 id（个位 NN 段）open → exit 1 零写入（id 口径门先拦）' "exit/状态不符"

  # 正例：同夹具换新 NN 新 slug 正常开票照旧（open 成功路径零回归；票 79 起本体先落位——
  # tix_body 正例形态含理由两字段，过本体校验后走完全链）
  tix_body "$F7/docs/issues/40-delta-fourth.json" 40-delta-fourth
  sh "$F7/scripts/ticket-ops.sh" open --id 40-delta-fourth --complexity C0 --title 'Delta fixture ticket' --ledger-line "$LED_OPEN" >"$D/nn-pos.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '"id": "40-delta-fourth"' "$F7/docs/issues/index.json"; then
    ok '正例 新 NN 新 slug open → exit 0 且索引落条目（正常开票零回归，票 77 后）'
  else
    bad '正例 新 NN 新 slug open → exit 0 且索引落条目（正常开票零回归，票 77 后）' "exit=$rc $(head -n 2 "$D/nn-pos.log" | tr '\n' '|')"
  fi

  # ---- 票 79 断言：open 本体 schema 校验＋理由非空（拒缺理由＋放过正常）----
  # 放过正常＝本套件正例全链 open（本体含理由两字段）照旧 exit 0 并全链落地；
  # 拒缺理由三负例（N-r1 缺 complexity_reason／N-r2 priority_reason 空值／N-r3 缺本体）
  # 均 exit 1、零写入，且报文指名缺失项。
  tix_body "$F/docs/issues/50-epsilon-fifth.json" 50-epsilon-fifth
  sed '/"complexity_reason"/d' "$F/docs/issues/50-epsilon-fifth.json" > "$D/b1.tmp" && mv "$D/b1.tmp" "$F/docs/issues/50-epsilon-fifth.json"
  S79=$(tix_state "$F")
  sh "$F/scripts/ticket-ops.sh" open --id 50-epsilon-fifth --complexity C1 --title eps --ledger-line "$LED_OPEN" >"$D/nr1.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q 'complexity_reason' "$D/nr1.log"; then
    ok '负例 N-r1 本体缺 complexity_reason → exit 1 零写入且报文指名字段（票 79）'
  else
    bad '负例 N-r1 本体缺 complexity_reason → exit 1 零写入且报文指名字段（票 79）' "exit=$rc $(head -n 2 "$D/nr1.log" | tr '\n' '|')"
  fi

  tix_body "$F/docs/issues/51-zeta-sixth.json" 51-zeta-sixth
  sed 's/"priority_reason": "fixture 优先级理由（正例，非空）"/"priority_reason": ""/' "$F/docs/issues/51-zeta-sixth.json" > "$D/b2.tmp" && mv "$D/b2.tmp" "$F/docs/issues/51-zeta-sixth.json"
  sh "$F/scripts/ticket-ops.sh" open --id 51-zeta-sixth --complexity C1 --title zeta --ledger-line "$LED_OPEN" >"$D/nr2.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q 'priority_reason' "$D/nr2.log"; then
    ok '负例 N-r2 本体 priority_reason 空值 → exit 1 零写入且报文指名字段（票 79）'
  else
    bad '负例 N-r2 本体 priority_reason 空值 → exit 1 零写入且报文指名字段（票 79）' "exit=$rc $(head -n 2 "$D/nr2.log" | tr '\n' '|')"
  fi

  sh "$F/scripts/ticket-ops.sh" open --id 60-eta-seventh --complexity C1 --title eta --ledger-line "$LED_OPEN" >"$D/nr3.log" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ "$S79" = "$(tix_state "$F")" ] && grep -q '新票本体不存在' "$D/nr3.log"; then
    ok '负例 N-r3 本体文件缺失 → exit 1 零写入（先落位本体再开票，票 79）'
  else
    bad '负例 N-r3 本体文件缺失 → exit 1 零写入（先落位本体再开票，票 79）' "exit=$rc $(head -n 2 "$D/nr3.log" | tr '\n' '|')"
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
# suite: check-package（票 12/48 场景沉淀：八项正例＋必需件缺失负例；票 56 检查 8 清单
# 8→10 件，预期串同步 10 件口径；票 57 数据化改造＋新增检查 9/10/11，预期串同步
# 十一项口径；协调层改判随票修：检查 11 逐处全等，补 §2.5 单处删值负例；票 58 检查
# 11→13，预期串同步十三项口径——正例含检查 12/13 PASS 行（比对 4 对＝仓根镜像在位
# 语境），补检查 12 注入/豁免/失效豁免与检查 13 镜像篡改/静默跳过负例；票 59 检查
# 13→14，预期串同步十四项口径——正例含检查 14 PASS 行，补检查 14 注入未登记基元/
# 删一基元负例；票 60 检查 14→17，检查 8 清单 10→12 件，预期串同步十七项口径——
# 正例含检查 15/16/17 PASS 行，补索引删行/加全集外 ID/未登记机制值/机械行点名不存在
# 脚本/检查项号超界/外定义行删标记词负例＋mechanism-vocab 词表损坏 exit 2 负例）
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
PASS: 8 脚本必需件存在（15 个文件）
PASS: 9 scripts/README.md 成员表与数据 scripts 节一致
PASS: 10 规则块短码使用均在登记内
PASS: 11 platform 枚举登记与数据一致
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 13 镜像脚本与仓根同名件一致（比对 4 对）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（索引 51 行，全集 51 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
PASS: 17 机械行点名出处存在（机械 9 行）
check-package: PASS
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$PKG_ROOT" >"$D/act.positive" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok "正例 exit 0（包根＝${PKG_ROOT}）" || bad "正例 exit 0（包根＝${PKG_ROOT}）" "exit=$rc"
  assert_eq '正例输出逐行逐一相等（十七项 PASS＋汇总，含票 57 检查 9/10/11、票 58 检查 12/13、票 59 检查 14 与票 60 检查 15/16/17）' "$D/act.positive" "$D/exp.positive"

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
FAIL: 8 脚本必需件存在（15 个文件） —   - scripts/generate-progress.sh
FAIL: 9 scripts/README.md 成员表与数据 scripts 节一致 —   - 成员表登记但无实际文件：generate-progress.sh
PASS: 10 规则块短码使用均在登记内
PASS: 11 platform 枚举登记与数据一致
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（索引 51 行，全集 51 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
FAIL: 17 机械行点名出处存在（机械 9 行） —   - R-DP-004 机械行点名脚本不存在: generate-progress.sh
check-package: FAIL（3 项未通过，共 17 项）
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy" >"$D/act.negative" 2>&1
  rc=$?
  [ "$rc" -eq 1 ] && ok '负例 exit 1（副本删必需件，mktemp 副本纪律）' || bad '负例 exit 1（副本删必需件，mktemp 副本纪律）' "exit=$rc"
  assert_eq '负例输出逐一相等（fail-closed 指名缺失件＋检查 9 表实漂移联动＋检查 17 机械行点名脚本缺失联动，不因部分存在放宽）' "$D/act.negative" "$D/exp.negative"

  # 票 57 协调层改判随票修：检查 11 逐处全等——§2.5 单处删 pi（frontmatter 完整）
  # 必须单独 FAIL 指名 :119（旧并集口径此场景漏检，回归钉死）。
  cp -R "$PKG_ROOT" "$D/pkgcopy2"
  sed 's=`pi` / `dsh`（与=`dsh`（与=' "$D/pkgcopy2/references/adapters/capability-contract.md" >"$D/cc.tmp" && mv "$D/cc.tmp" "$D/pkgcopy2/references/adapters/capability-contract.md"
  cat > "$D/exp.cc" <<'EOF'
PASS: 1 必需入口存在（16 个文件）
PASS: 2 SKILL.md frontmatter 为 name: agent-up
PASS: 3 包内无旧标识残留
PASS: 4 无绝对路径与根治理引用
PASS: 5 templates 下 .tmpl 为 13 个且全部登记
PASS: 6 文本契约头齐全（*.md 与 *.tmpl）
PASS: 7 根治理文件不在包内
PASS: 8 脚本必需件存在（15 个文件）
PASS: 9 scripts/README.md 成员表与数据 scripts 节一致
PASS: 10 规则块短码使用均在登记内
FAIL: 11 platform 枚举登记与数据一致 —   - capability-contract.md :119 登记与数据不一致：缺少 pi
PASS: 12 规则块体无模糊措辞（词表 6 词，豁免 2 行）
PASS: 14 能力映射一致（基元 9 个，检查目标 8 个）
PASS: 15 模板规则索引与规则块全集全等（索引 51 行，全集 51 ID）
PASS: 16 索引机制列受控词表（机制 3 值＋标记 1 词）
PASS: 17 机械行点名出处存在（机械 9 行）
check-package: FAIL（1 项未通过，共 17 项）
EOF
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy2" >"$D/act.cc" 2>&1
  rc=$?
  [ "$rc" -eq 1 ] && ok '负例 exit 1（capability-contract §2.5 单处删 pi，frontmatter 完整）' || bad '负例 exit 1（capability-contract §2.5 单处删 pi，frontmatter 完整）' "exit=$rc"
  assert_eq '负例输出逐一相等（检查 11 逐处全等，FAIL 行按行号指名 :119 缺少 pi）' "$D/act.cc" "$D/exp.cc"

  # 票 58 检查 12 负例 N4：词表首词（自夹具包 manifest 词表节提取，harness 零词面字面量）
  # 注入 governance-format.md 首个规则块 Authority 字段之后 → FAIL: 12 指名文件:行号；
  # 注入行同时使既有豁免行号漂移（未豁免命中与失效豁免同报），行级豁免漂移即 FAIL 的
  # fail-closed 行为随之钉死。
  cp -R "$PKG_ROOT" "$D/pkgcopy3"
  w=$(LC_ALL=C awk -F"'" '/^pm_vague_word/{print $2; exit}' "$D/pkgcopy3/scripts/package-manifest.rules")
  gf="$D/pkgcopy3/references/protocol/governance-format.md"
  ln=$(grep -n '^\- \*\*Authority\*\*' "$gf" | head -1 | cut -d: -f1)
  { head -n "$ln" "$gf"; printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; tail -n +"$((ln + 1))" "$gf"; } > "$D/gf.tmp"
  mv "$D/gf.tmp" "$gf"
  sh "$SCRIPT_DIR/check-package.sh" "$D/pkgcopy3" >"$D/act.n4" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 12 规则块体无模糊措辞' "$D/act.n4" && grep -q "governance-format.md:$((ln + 1)) 命中模糊措辞" "$D/act.n4"; then
    ok '负例 N4 注入词表首词入规则块体 → exit 1 且 FAIL: 12 指名文件:行号'
  else
    bad '负例 N4 注入词表首词入规则块体 → exit 1 且 FAIL: 12 指名文件:行号' "exit=$rc"
  fi

  # 票 58 检查 12 正例 N5：同一注入落在 read-policy.md（无既有豁免引用文件，豁免行号
  # 零漂移）并在夹具包 manifest 登记行级豁免 → 该行不报，exit 0（豁免生效）。
  cp -R "$PKG_ROOT" "$D/pkgcopy4"
  rp="$D/pkgcopy4/references/protocol/read-policy.md"
  rln=$(grep -n '^\- \*\*Authority\*\*' "$rp" | head -1 | cut -d: -f1)
  { head -n "$rln" "$rp"; printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; tail -n +"$((rln + 1))" "$rp"; } > "$D/rp.tmp"
  mv "$D/rp.tmp" "$rp"
  printf "pm_vague_exempt references/protocol/read-policy.md %d 'harness fixture 豁免正例（登记后该行不报）'\n" "$((rln + 1))" >> "$D/pkgcopy4/scripts/package-manifest.rules"
  # 豁免登记改动须被引擎读到：check-package 加载与自身同目录的 manifest（票 57 口径），
  # 故本组负例以夹具包自带的引擎副本运行（引擎与原物同码，cp 纪律）。
  sh "$D/pkgcopy4/scripts/check-package.sh" "$D/pkgcopy4" >"$D/act.n5" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^PASS: 12 规则块体无模糊措辞' "$D/act.n5"; then
    ok '正例 N5 注入行登记行级豁免后不报 → exit 0（豁免生效）'
  else
    bad '正例 N5 注入行登记行级豁免后不报 → exit 0（豁免生效）' "exit=$rc"
  fi

  # 票 58 检查 12 负例 N6：豁免登记行无命中（999 行）→ 失效豁免 FAIL（防漂移静默失效）。
  cp -R "$PKG_ROOT" "$D/pkgcopy5"
  printf "pm_vague_exempt references/protocol/governance-format.md 999 'harness fixture 失效豁免负例'\n" >> "$D/pkgcopy5/scripts/package-manifest.rules"
  sh "$D/pkgcopy5/scripts/check-package.sh" "$D/pkgcopy5" >"$D/act.n6" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '失效豁免（登记行无词表命中，须复核更新或删除登记）: references/protocol/governance-format.md:999' "$D/act.n6"; then
    ok '负例 N6 豁免登记行无命中 → exit 1 且 FAIL: 12 报失效豁免'
  else
    bad '负例 N6 豁免登记行无命中 → exit 1 且 FAIL: 12 报失效豁免' "exit=$rc"
  fi

  # 票 58 检查 13 负例 N7：仓根 scripts/ 同名件单处篡改 → FAIL: 13 指名文件。
  mkdir -p "$D/mrepo/scripts"
  cp -R "$PKG_ROOT" "$D/mrepo/agent-up"
  cp "$PKG_ROOT/scripts/generate-progress.sh" "$PKG_ROOT/scripts/ticket-ops.sh" "$D/mrepo/scripts/"
  printf '# harness fixture 镜像篡改\n' >> "$D/mrepo/scripts/ticket-ops.sh"
  sh "$SCRIPT_DIR/check-package.sh" "$D/mrepo/agent-up" >"$D/act.n7" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 13 镜像脚本与仓根同名件一致' "$D/act.n7" && grep -q 'scripts/ticket-ops.sh 与仓根 scripts/ticket-ops.sh 不一致' "$D/act.n7"; then
    ok '负例 N7 仓根镜像同名件篡改 → exit 1 且 FAIL: 13 指名文件'
  else
    bad '负例 N7 仓根镜像同名件篡改 → exit 1 且 FAIL: 13 指名文件' "exit=$rc"
  fi

  # 票 58 检查 13 负例 N8：仓根无 scripts/（pkgcopy 语境）→ 检查 13 静默跳过无输出行
  # （消费项目语义，--pkg-root 参数化语境同样跳过）。
  if grep -q ': 13 ' "$D/act.negative"; then
    bad '负例 N8 仓根无 scripts/ 时检查 13 静默跳过（无输出行）' '意外出现检查 13 输出行'
  else
    ok '负例 N8 仓根无 scripts/ 时检查 13 静默跳过（无输出行）'
  fi

  # 协调层 Review 改判随票修（尾锚）：负例 N9——governance-format.md 在 R-GF-010
  # Authority 行后填充占位行，使注入命中恰落 :820，并在夹具 manifest 登记行号 8200
  # 的豁免（820 的字符串超集）：尾锚缺失时 "path\t820" 误配 "path\t8200\t..." 豁免行、
  # 命中被罩（旧缺陷方向）；尾锚生效 = :820 命中必须报出（exit 1 且 FAIL: 12 指名
  # :820）。既有 :82 豁免同文件在位，一并验证不误罩 :820 命中。
  cp -R "$PKG_ROOT" "$D/pkgcopy6"
  gf6="$D/pkgcopy6/references/protocol/governance-format.md"
  aln=$(grep -n '^\- \*\*Authority\*\*' "$gf6" | tail -1 | cut -d: -f1)
  pad=$((820 - aln - 1))
  { head -n "$aln" "$gf6"; \
    LC_ALL=C awk 'BEGIN { for (i = 0; i < '"$pad"'; i++) print "- harness fixture 占位行（尾锚负例填充，无词面无短码）" }'; \
    printf -- '- harness fixture 注入行（词表首词：%s）\n' "$w"; \
    tail -n +"$((aln + 1))" "$gf6"; } > "$D/gf6.tmp"
  mv "$D/gf6.tmp" "$gf6"
  printf "pm_vague_exempt references/protocol/governance-format.md 8200 'harness fixture 尾锚负例（行号字符串超集不误罩 :820 命中）'\n" >> "$D/pkgcopy6/scripts/package-manifest.rules"
  sh "$D/pkgcopy6/scripts/check-package.sh" "$D/pkgcopy6" >"$D/act.n9" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'references/protocol/governance-format.md:820 命中模糊措辞' "$D/act.n9" && grep -q '失效豁免（登记行无词表命中，须复核更新或删除登记）: references/protocol/governance-format.md:8200' "$D/act.n9"; then
    ok '负例 N9 尾锚证明：:820 注入命中不被 :82/:8200 豁免行号字符串前缀误罩 → exit 1 指名 :820'
  else
    bad '负例 N9 尾锚证明：:820 注入命中不被 :82/:8200 豁免行号字符串前缀误罩 → exit 1 指名 :820' "exit=$rc"
  fi

  # 票 59 检查 14 负例 N10：向 agents-implementation.md.tmpl 的 required_capabilities 行
  # 注入未登记基元名 → exit 1 且 FAIL: 14 指名文件（多出＝不在名单）。
  cp -R "$PKG_ROOT" "$D/pkgcopy7"
  sed 's/`execute`；治理写入许可/`execute`、`harness-fixture-cap`；治理写入许可/' \
    "$D/pkgcopy7/references/templates/agents-implementation.md.tmpl" > "$D/tmpl7.tmp" \
    && mv "$D/tmpl7.tmp" "$D/pkgcopy7/references/templates/agents-implementation.md.tmpl"
  sh "$D/pkgcopy7/scripts/check-package.sh" "$D/pkgcopy7" >"$D/act.n10" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 14 能力映射一致' "$D/act.n10" && grep -q 'agents-implementation.md.tmpl 未登记基元名 harness-fixture-cap' "$D/act.n10"; then
    ok '负例 N10 注入未登记基元名入角色声明行 → exit 1 且 FAIL: 14 指名文件'
  else
    bad '负例 N10 注入未登记基元名入角色声明行 → exit 1 且 FAIL: 14 指名文件' "exit=$rc"
  fi

  # 票 59 检查 14 负例 N11：自同一声明行删除一基元名（edit）→ exit 1 且 FAIL: 14 指名
  # 文件（缺少＝相对登记预期名单）。
  cp -R "$PKG_ROOT" "$D/pkgcopy8"
  sed 's/、`edit`//' "$D/pkgcopy8/references/templates/agents-implementation.md.tmpl" > "$D/tmpl8.tmp" \
    && mv "$D/tmpl8.tmp" "$D/pkgcopy8/references/templates/agents-implementation.md.tmpl"
  sh "$D/pkgcopy8/scripts/check-package.sh" "$D/pkgcopy8" >"$D/act.n11" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 14 能力映射一致' "$D/act.n11" && grep -q 'agents-implementation.md.tmpl 缺少基元 edit' "$D/act.n11"; then
    ok '负例 N11 删除一基元名出角色声明行 → exit 1 且 FAIL: 14 指名文件'
  else
    bad '负例 N11 删除一基元名出角色声明行 → exit 1 且 FAIL: 14 指名文件' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N12：索引删一行（删 R-RQ-003 行）→ exit 1 且 FAIL: 15 指名缺行。
  cp -R "$PKG_ROOT" "$D/pkgcopy9"
  grep -v '^| R-RQ-003 ' "$D/pkgcopy9/references/templates/development-process.md.tmpl" > "$D/tmpl9.tmp" \
    && mv "$D/tmpl9.tmp" "$D/pkgcopy9/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy9/scripts/check-package.sh" "$D/pkgcopy9" >"$D/act.n12" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n12" && grep -q '全集 ID 缺索引行: R-RQ-003' "$D/act.n12"; then
    ok '负例 N12 索引删一行 → exit 1 且 FAIL: 15 指名缺行（索引变更先改表再动规则块的拦截面）'
  else
    bad '负例 N12 索引删一行 → exit 1 且 FAIL: 15 指名缺行（索引变更先改表再动规则块的拦截面）' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N13：索引表尾加全集外 ID 行（R-DP-999，短码 DP 已登记、序号不存在）
  # → exit 1 且 FAIL: 15 指名多行（检查 10 不误伤：短码在册）。
  cp -R "$PKG_ROOT" "$D/pkgcopy10"
  printf '| R-DP-999 | harness fixture 全集外 ID 负例 | 约定 |\n' >> "$D/pkgcopy10/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy10/scripts/check-package.sh" "$D/pkgcopy10" >"$D/act.n13" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n13" && grep -q '索引多出全集外 ID: R-DP-999' "$D/act.n13"; then
    ok '负例 N13 索引加全集外 ID → exit 1 且 FAIL: 15 指名多行'
  else
    bad '负例 N13 索引加全集外 ID → exit 1 且 FAIL: 15 指名多行' "exit=$rc"
  fi

  # 票 60 检查 16 负例 N14：机制列写未登记值（R-DP-001 约定→自动）→ exit 1 且 FAIL: 16
  # 指名 ID 与值（受控词表外置 manifest，harness 零词面字面量——注入值「自动」为场景
  # 固定负例字面量，非词表成员）。
  cp -R "$PKG_ROOT" "$D/pkgcopy11"
  sed '/^| R-DP-001 /s/| 约定 |$/| 自动 |/' "$D/pkgcopy11/references/templates/development-process.md.tmpl" > "$D/tmpl11.tmp" \
    && mv "$D/tmpl11.tmp" "$D/pkgcopy11/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy11/scripts/check-package.sh" "$D/pkgcopy11" >"$D/act.n14" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 16 索引机制列受控词表' "$D/act.n14" && grep -q 'R-DP-001 机制值不在受控词表: 自动' "$D/act.n14"; then
    ok '负例 N14 机制列写未登记值 → exit 1 且 FAIL: 16 指名 ID 与值'
  else
    bad '负例 N14 机制列写未登记值 → exit 1 且 FAIL: 16 指名 ID 与值' "exit=$rc"
  fi

  # 票 60 检查 17 负例 N15：机械行点名不存在脚本（R-RC-003 出处改 harness-fixture.sh）
  # → exit 1 且 FAIL: 17 指名 ID 与脚本。
  cp -R "$PKG_ROOT" "$D/pkgcopy12"
  sed 's/| 机械（lane-commit.sh） |/| 机械（harness-fixture.sh） |/' "$D/pkgcopy12/references/templates/development-process.md.tmpl" > "$D/tmpl12.tmp" \
    && mv "$D/tmpl12.tmp" "$D/pkgcopy12/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy12/scripts/check-package.sh" "$D/pkgcopy12" >"$D/act.n15" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 17 机械行点名出处存在' "$D/act.n15" && grep -q 'R-RC-003 机械行点名脚本不存在: harness-fixture.sh' "$D/act.n15"; then
    ok '负例 N15 机械行点名不存在脚本 → exit 1 且 FAIL: 17 指名 ID 与脚本'
  else
    bad '负例 N15 机械行点名不存在脚本 → exit 1 且 FAIL: 17 指名 ID 与脚本' "exit=$rc"
  fi

  # 票 60 检查 17 负例 N16：机械行点名检查项号超界（R-RC-003 出处改 lane-commit.sh 检查 18）
  # → exit 1 且 FAIL: 17 指名 ID 与项号（引擎自述总数 17）。
  cp -R "$PKG_ROOT" "$D/pkgcopy13"
  sed 's/| 机械（lane-commit.sh） |/| 机械（lane-commit.sh 检查 18） |/' "$D/pkgcopy13/references/templates/development-process.md.tmpl" > "$D/tmpl13.tmp" \
    && mv "$D/tmpl13.tmp" "$D/pkgcopy13/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy13/scripts/check-package.sh" "$D/pkgcopy13" >"$D/act.n16" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 17 机械行点名出处存在' "$D/act.n16" && grep -q 'R-RC-003 机械行点名检查项号超界（当前共 17 项）: 检查 18' "$D/act.n16"; then
    ok '负例 N16 机械行点名检查项号超界 → exit 1 且 FAIL: 17 指名 ID 与项号'
  else
    bad '负例 N16 机械行点名检查项号超界 → exit 1 且 FAIL: 17 指名 ID 与项号' "exit=$rc"
  fi

  # 票 60 检查 15 负例 N17：外定义行删标记词（R-CC-002 机制列「门禁；外定义（…）」改「门禁」）
  # → exit 1 且 FAIL: 15 算漏行（外定义豁免须显式标注非静默）。
  cp -R "$PKG_ROOT" "$D/pkgcopy14"
  sed 's/| 门禁；外定义（定义于 references\/adapters\/capability-contract.md） |/| 门禁 |/' "$D/pkgcopy14/references/templates/development-process.md.tmpl" > "$D/tmpl14.tmp" \
    && mv "$D/tmpl14.tmp" "$D/pkgcopy14/references/templates/development-process.md.tmpl"
  sh "$D/pkgcopy14/scripts/check-package.sh" "$D/pkgcopy14" >"$D/act.n17" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^FAIL: 15 模板规则索引与规则块全集全等' "$D/act.n17" && grep -q '外定义 ID 行未标注标记词「外定义」（豁免须显式，未标注算漏行）: R-CC-002（定义于 references/adapters/capability-contract.md）' "$D/act.n17"; then
    ok '负例 N17 外定义行删标记词 → exit 1 且 FAIL: 15 算漏行（豁免显式非静默）'
  else
    bad '负例 N17 外定义行删标记词 → exit 1 且 FAIL: 15 算漏行（豁免显式非静默）' "exit=$rc"
  fi

  # 票 60 负例 N18：manifest mechanism-vocab 词表损坏（重复行）→ 引擎结构校验 exit 2
  # fail-closed（受控词表是检查 16 比对基准，损坏不产生部分结论）。
  cp -R "$PKG_ROOT" "$D/pkgcopy15"
  printf 'pm_mechanism 机械\n' >> "$D/pkgcopy15/scripts/package-manifest.rules"
  sh "$D/pkgcopy15/scripts/check-package.sh" "$D/pkgcopy15" >"$D/act.n18" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'mechanism-vocab 节第' "$D/act.n18"; then
    ok '负例 N18 mechanism-vocab 词表损坏（跨行重复）→ exit 2 fail-closed'
  else
    bad '负例 N18 mechanism-vocab 词表损坏（跨行重复）→ exit 2 fail-closed' "exit=$rc"
  fi

  suite_summary 'check-package'
}

# ============================================================
# suite: append-only（票 58 场景沉淀：check-append-only.sh 正负例——只追加账本前缀
# 语义＋progress.md 冻结＋懒创建跳过＋无 HEAD WARN＋用法退出码）
# ============================================================

ao_git_commit() {
  # $1=夹具仓根：全量暂存并提交（本地身份经 -c 内联，零全局污染）
  git -C "$1" add -A
  git -C "$1" -c user.email=fixture@example.com -c user.name=fixture commit -qm fixture
}

ao_build_fixture() {
  # $1=夹具仓根：三守卫对象齐备（changes.jsonl 3 行／micro.jsonl 1 行／progress.md 冻结）
  R=$1
  rm -rf "$R"
  mkdir -p "$R/docs/agent"
  printf 'l1\nl2\nl3\n' > "$R/docs/changes.jsonl"
  printf '{"date": "2026-09-21", "lane": "micro", "whitelist": "a.txt", "gates": "PASS", "verify": 1, "commit": "x"}\n' > "$R/docs/agent/micro.jsonl"
  printf '# 冻结历史档案（fixture）\n' > "$R/docs/progress.md"
  git -C "$R" init -q
  ao_git_commit "$R"
}

suite_append_only() {
  CUR_SUITE='append-only'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/ao
  mkdir -p "$D"
  AO="$SCRIPT_DIR/check-append-only.sh"

  # 正例 P1：changes.jsonl 尾部追加 → exit 0（历史前缀核对通过）
  ao_build_fixture "$D/p1"
  printf 'l4\n' >> "$D/p1/docs/changes.jsonl"
  sh "$AO" "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: docs/changes.jsonl（尾部追加 1 行，历史前缀核对通过）' "$D/p1.out"; then
    ok '正例 P1 changes.jsonl 尾部追加 → exit 0（OK 行含追加计数）'
  else
    bad '正例 P1 changes.jsonl 尾部追加 → exit 0（OK 行含追加计数）' "exit=$rc"
  fi

  # 正例 P2：micro.jsonl 同口径追加 → OK；progress.md 零 diff → OK
  ao_build_fixture "$D/p2"
  printf '{"date": "2026-09-21", "lane": "micro", "whitelist": "b.txt", "gates": "PASS", "verify": 1, "commit": "y"}\n' >> "$D/p2/docs/agent/micro.jsonl"
  sh "$AO" "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: docs/agent/micro.jsonl（尾部追加 1 行' "$D/p2.out" && grep -q 'OK: docs/progress.md（与 HEAD 一致，零 diff）' "$D/p2.out"; then
    ok '正例 P2 micro.jsonl 追加＋progress.md 零 diff → exit 0（micro.jsonl 同口径）'
  else
    bad '正例 P2 micro.jsonl 追加＋progress.md 零 diff → exit 0（micro.jsonl 同口径）' "exit=$rc"
  fi

  # 负例 N1：中间插入 → exit 1 指名文件与首个违规行号（新文件行号 2）
  ao_build_fixture "$D/n1"
  sed '2i\
INSERTED' "$D/n1/docs/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n1/docs/changes.jsonl"
  sh "$AO" "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/changes.jsonl 历史行被改写或中间插入' "$D/n1.out" && grep -q '首个违规行号 2（新文件行号）' "$D/n1.out"; then
    ok '负例 N1 changes.jsonl 中间插入 → exit 1 指名文件与首个违规行号 2'
  else
    bad '负例 N1 changes.jsonl 中间插入 → exit 1 指名文件与首个违规行号 2' "exit=$rc"
  fi

  # 负例 N2：改写历史行 → exit 1 指名首个违规行号
  ao_build_fixture "$D/n2"
  sed '2s/.*/REWRITTEN/' "$D/n2/docs/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n2/docs/changes.jsonl"
  sh "$AO" "$D/n2" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/changes.jsonl' "$D/n2.out"; then
    ok '负例 N2 changes.jsonl 改写历史行 → exit 1 指名文件'
  else
    bad '负例 N2 changes.jsonl 改写历史行 → exit 1 指名文件' "exit=$rc"
  fi

  # 负例 N3：截断（删尾行）→ exit 1
  ao_build_fixture "$D/n3"
  sed '$d' "$D/n3/docs/changes.jsonl" > "$D/x" && mv "$D/x" "$D/n3/docs/changes.jsonl"
  sh "$AO" "$D/n3" > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/changes.jsonl' "$D/n3.out"; then
    ok '负例 N3 changes.jsonl 截断 → exit 1'
  else
    bad '负例 N3 changes.jsonl 截断 → exit 1' "exit=$rc"
  fi

  # 负例 N4：账本删除（HEAD 有、工作树无）→ exit 1
  ao_build_fixture "$D/n4"
  rm -f "$D/n4/docs/changes.jsonl"
  sh "$AO" "$D/n4" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/changes.jsonl 在 HEAD 存在但工作树缺失（只追加账本不得删除历史）' "$D/n4.out"; then
    ok '负例 N4 changes.jsonl 工作树删除 → exit 1（不得删除历史）'
  else
    bad '负例 N4 changes.jsonl 工作树删除 → exit 1（不得删除历史）' "exit=$rc"
  fi

  # 负例 N5：progress.md 篡改 → exit 1（冻结档案任何 diff 即违规）
  ao_build_fixture "$D/n5"
  printf '# 冻结历史档案（fixture）篡改行\n' >> "$D/n5/docs/progress.md"
  sh "$AO" "$D/n5" > "$D/n5.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/progress.md 冻结历史档案出现 diff' "$D/n5.out"; then
    ok '负例 N5 progress.md 篡改 → exit 1（冻结档案零 diff）'
  else
    bad '负例 N5 progress.md 篡改 → exit 1（冻结档案零 diff）' "exit=$rc"
  fi

  # 负例 N6：micro.jsonl 中间插入 → exit 1（同口径覆盖第二账本）
  ao_build_fixture "$D/n6"
  sed '1i\
EARLY' "$D/n6/docs/agent/micro.jsonl" > "$D/x" && mv "$D/x" "$D/n6/docs/agent/micro.jsonl"
  sh "$AO" "$D/n6" > "$D/n6.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: docs/agent/micro.jsonl' "$D/n6.out"; then
    ok '负例 N6 micro.jsonl 中间插入 → exit 1（与 changes.jsonl 同口径）'
  else
    bad '负例 N6 micro.jsonl 中间插入 → exit 1（与 changes.jsonl 同口径）' "exit=$rc"
  fi

  # 正例 P3：无 Git 基线（无 HEAD）→ WARN 退出 0（票 49 先例，不硬猜）
  rm -rf "$D/p3"; mkdir -p "$D/p3/docs"
  printf 'x\n' > "$D/p3/docs/changes.jsonl"
  git -C "$D/p3" init -q
  sh "$AO" "$D/p3" > "$D/p3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'WARN: 无 Git 基线（无 HEAD）' "$D/p3.out"; then
    ok '正例 P3 无 Git 基线（无 HEAD）→ WARN 退出 0（不硬猜基线）'
  else
    bad '正例 P3 无 Git 基线（无 HEAD）→ WARN 退出 0（不硬猜基线）' "exit=$rc"
  fi

  # 正例 P4：懒创建语义——两账本与 progress.md 均不存在 → SKIP 且 exit 0；
  # changes.jsonl 工作树新建（HEAD 无）→ 全部行为追加 OK。
  rm -rf "$D/p4"; mkdir -p "$D/p4"
  printf 'seed\n' > "$D/p4/seed"
  git -C "$D/p4" init -q
  ao_git_commit "$D/p4"
  mkdir -p "$D/p4/docs"
  printf 'new\n' > "$D/p4/docs/changes.jsonl"
  sh "$AO" "$D/p4" > "$D/p4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'OK: docs/changes.jsonl（工作树新建，全部行为追加，懒创建语义）' "$D/p4.out" && grep -q 'SKIP: docs/agent/micro.jsonl（不存在，懒创建语义）' "$D/p4.out" && grep -q 'SKIP: docs/progress.md（不存在）' "$D/p4.out"; then
    ok '正例 P4 懒创建（新建账本 OK＋缺失 SKIP）→ exit 0'
  else
    bad '正例 P4 懒创建（新建账本 OK＋缺失 SKIP）→ exit 0' "exit=$rc"
  fi

  # 用法负例 N7：无参数 → exit 2；多参数 → exit 2；非 Git 目录 → exit 2
  sh "$AO" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N7 无参数 → exit 2' || bad '负例 N7 无参数 → exit 2' "exit=$rc"
  sh "$AO" a b >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N8 两参数 → exit 2' || bad '负例 N8 两参数 → exit 2' "exit=$rc"
  mkdir -p "$D/nogit"
  sh "$AO" "$D/nogit" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N9 非 Git 目录 → exit 2' || bad '负例 N9 非 Git 目录 → exit 2' "exit=$rc"

  suite_summary 'append-only'
}

# ============================================================
# suite: check-artifacts（票 59 场景沉淀：治理产物对账正负例——登记↔实物双向对账、
# 懒创建 SKIP、豁免命中不报、解析破坏 fail-closed、用法退出码）
# ============================================================

rt_build_fixture() {
  # $1=夹具仓根：与 check-artifacts.sh 对账数据块基线口径一致的登记↔实物全对账仓
  R=$1
  rm -rf "$R"
  mkdir -p "$R/scripts" "$R/docs/agent/roles" "$R/docs/issues" "$R/docs/agent/runs"
  printf '# agents\n' > "$R/AGENTS.md"
  printf '#!/bin/sh\n' > "$R/scripts/tool.sh"
  printf '# notes\n' > "$R/docs/notes.md"
  printf '# impl\n' > "$R/docs/agent/roles/impl.md"
  printf '# t1\n' > "$R/docs/issues/t1.md"
  printf '{"i":1}\n' > "$R/docs/issues/index.json"
  printf 'l1\n' > "$R/docs/changes.jsonl"
  printf '<!-- projection -->\n' > "$R/docs/progress-current.md"
  printf 'r\n' > "$R/docs/agent/runs/r1.json"
  cat > "$R/docs/agent/artifacts.yaml" <<'EOF'
# fixture 登记文件（与被测脚本数据块基线口径互恰）
artifacts:
  - id: agents-md
    path: AGENTS.md
  - id: scripts-tool
    path: scripts/tool.sh
  - id: docs-notes
    path: docs/notes.md
  - id: role-impl
    path: docs/agent/roles/impl.md
  - id: issues-aggregate
    path: docs/issues/*.md（fixture 聚合登记）
  - id: micro-ledger
    path: docs/agent/micro.jsonl（道账本，懒创建）
  - id: yaml-self
    path: docs/agent/artifacts.yaml
EOF
}

suite_check_artifacts() {
  CUR_SUITE='check-artifacts'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/rt
  mkdir -p "$D"
  CA="$SCRIPT_DIR/check-artifacts.sh"

  # 正例 P1：登记↔实物全对账 → exit 0；micro.jsonl 登记暂缺走懒创建 SKIP（不计缺口）
  rt_build_fixture "$D/p1"
  sh "$CA" "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && ok '正例 P1 全对账 → exit 0' || bad '正例 P1 全对账 → exit 0' "exit=$rc $(head -n 2 "$D/p1.out" | tr '\n' '|')"
  if grep -q 'SKIP: 条目 micro-ledger 登记目标暂缺（数据块懒创建许可）: docs/agent/micro.jsonl' "$D/p1.out" && ! grep -q '^check-artifacts: FAIL' "$D/p1.out"; then
    ok '正例 P1 懒创建面登记暂缺 → SKIP 行且零 FAIL（豁免命中不报同证）'
  else
    bad '正例 P1 懒创建面登记暂缺 → SKIP 行且零 FAIL（豁免命中不报同证）' "$(head -n 3 "$D/p1.out" | tr '\n' '|')"
  fi

  # 负例 N1：登记目标缺失（删已登记文件）→ exit 1 指名条目
  rt_build_fixture "$D/n1"
  rm "$D/n1/docs/agent/roles/impl.md"
  sh "$CA" "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 条目 role-impl 登记目标不存在: docs/agent/roles/impl.md' "$D/n1.out"; then
    ok '负例 N1 登记目标缺失 → exit 1 指名条目'
  else
    bad '负例 N1 登记目标缺失 → exit 1 指名条目' "exit=$rc"
  fi

  # 负例 N2：受管范围新增未登记文件 → exit 1 指名路径
  rt_build_fixture "$D/n2"
  printf 'stray\n' > "$D/n2/docs/stray.md"
  sh "$CA" "$D/n2" > "$D/n2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 受管文件未登记: docs/stray.md' "$D/n2.out"; then
    ok '负例 N2 受管文件未登记 → exit 1 指名路径'
  else
    bad '负例 N2 受管文件未登记 → exit 1 指名路径' "exit=$rc"
  fi

  # 负例 N3：豁免命中不报——runs/ 整目录内未登记新增文件 → exit 0 且零 FAIL
  rt_build_fixture "$D/n3"
  printf 'x\n' > "$D/n3/docs/agent/runs/extra.json"
  sh "$CA" "$D/n3" > "$D/n3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^check-artifacts: FAIL' "$D/n3.out"; then
    ok '负例 N3 豁免目录内未登记文件命中豁免 → exit 0 不报'
  else
    bad '负例 N3 豁免目录内未登记文件命中豁免 → exit 0 不报' "exit=$rc"
  fi

  # 票 72 豁免迁移：校准豁免自 delivery.rules calibration 节读取（引擎零路径硬编码）。
  # 正例 M1：声明 dp_artifact_exempt → generated 内未登记文件命中豁免 exit 0
  rt_build_fixture "$D/m1"
  mkdir -p "$D/m1/docs/architecture/generated"
  printf '{}\n' > "$D/m1/docs/architecture/generated/m.json"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_artifact_exempt docs/architecture/generated/\n' > "$D/m1/delivery.rules"
  sh "$CA" "$D/m1" > "$D/m1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q '^check-artifacts: FAIL' "$D/m1.out"; then
    ok '正例 M1 delivery.rules 声明校准豁免 → generated 内未登记文件不报 exit 0（票 72 迁移）'
  else
    bad '正例 M1 delivery.rules 声明校准豁免 → generated 内未登记文件不报 exit 0（票 72 迁移）' "exit=$rc"
  fi

  # 负例 M2：无 delivery.rules → 豁免消失，生成面文件按未登记 FAIL 暴露（fail-closed）
  rt_build_fixture "$D/m2"
  mkdir -p "$D/m2/docs/architecture/generated"
  printf '{}\n' > "$D/m2/docs/architecture/generated/m.json"
  sh "$CA" "$D/m2" > "$D/m2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'FAIL: 受管文件未登记: docs/architecture/generated/m.json' "$D/m2.out"; then
    ok '负例 M2 无 delivery.rules → 生成面文件按未登记 FAIL（豁免消失 fail-closed，票 72 迁移）'
  else
    bad '负例 M2 无 delivery.rules → 生成面文件按未登记 FAIL（豁免消失 fail-closed，票 72 迁移）' "exit=$rc"
  fi

  # 负例 M3：delivery.rules 解析破坏 → exit 2 fail-closed
  rt_build_fixture "$D/m3"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_bogus x\n' > "$D/m3/delivery.rules"
  sh "$CA" "$D/m3" > "$D/m3.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'delivery.rules 解析破坏（fail-closed，不产生部分结论）' "$D/m3.out"; then
    ok '负例 M3 delivery.rules 解析破坏 → exit 2 fail-closed（票 72 迁移）'
  else
    bad '负例 M3 delivery.rules 解析破坏 → exit 2 fail-closed（票 72 迁移）' "exit=$rc"
  fi

  # 负例 N4：登记解析破坏（条目缺 path 字段）→ exit 2 fail-closed
  rt_build_fixture "$D/n4"
  grep -v '    path: docs/notes.md' "$D/n4/docs/agent/artifacts.yaml" > "$D/y4.tmp" \
    && mv "$D/y4.tmp" "$D/n4/docs/agent/artifacts.yaml"
  sh "$CA" "$D/n4" > "$D/n4.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q '登记解析破坏（fail-closed，不产生部分结论）' "$D/n4.out" && grep -q '条目缺 path 字段: docs-notes' "$D/n4.out"; then
    ok '负例 N4 登记解析破坏 → exit 2 且指名行与条目'
  else
    bad '负例 N4 登记解析破坏 → exit 2 且指名行与条目' "exit=$rc"
  fi

  # 用法负例 N5/N6：无参数 → exit 2；repo-root 不存在 → exit 2
  sh "$CA" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N5 无参数 → exit 2' || bad '负例 N5 无参数 → exit 2' "exit=$rc"
  sh "$CA" "$D/no-such-root" >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 2 ] && ok '负例 N6 repo-root 不存在 → exit 2' || bad '负例 N6 repo-root 不存在 → exit 2' "exit=$rc"

  suite_summary 'check-artifacts'
}

# ============================================================
# suite: stale-claims（票 72 场景沉淀：S1/S2 配置点亮正负例——未点亮 SKIP 不计数、
# 点亮按配置断言、delivery.rules 解析破坏 exit 2、汇总登记数动态化）
# ============================================================

sc_build_fixture() {
  # $1=夹具目录：仓库建于 <dir>/repo（eng 引擎目录由 suite 另行创建）；S1/S2 退化语义
  # 最小仓（非 Git 工作区→S1 WARN 退化；S3 退化＝夹具引擎目录只放被测脚本单件，
  # generator 不可用走内建最小比对，索引↔投影一致面可控；S4 锚点行 1↔index 条目 1
  # 相等）。S2 权威位置（根 README 宣称行）故意缺席——点亮断言经「登记的权威位置
  # 失效」STALE 行证明执行，免建完整发布面。
  R="$1/repo"
  rm -rf "$1"
  mkdir -p "$R/docs/issues" "$R/scripts"
  printf '# progress\n\nGit 恢复基线：占位锚点（S1 权威位置在位）\n' > "$R/docs/progress.md"
  printf '{"id": "90-fixture", "status": "ready", "updated_at": "2026-09-22T00:00:00Z"}\n' > "$R/docs/issues/index.json"
  printf '# projection\n\n| id | status | checkpoint_ref | updated_at |\n| --- | --- | --- | --- |\n| 90-fixture | ready | - | 2026-09-22T00:00:00Z |\n' > "$R/docs/progress-current.md"
  printf '# issues\n\n任务票 1；\n' > "$R/docs/issues/README.md"
}

sc_run() {
  # $1=夹具仓根；经夹具引擎目录单件副本运行（触发 S3 退化路径，engine 同目录无生成器）
  sh "$1/eng/check-stale-claims.sh" "$1/repo" gate
}

suite_stale_claims() {
  CUR_SUITE='stale-claims'
  SUITE_FAILS=0
  SUITE_START=$TOTAL
  D=$T/scl
  mkdir -p "$D"
  SC="$SCRIPT_DIR/check-stale-claims.sh"

  # 正例 P1：未点亮（无 delivery.rules）→ S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 2
  sc_build_fixture "$D/p1"
  mkdir -p "$D/p1/eng"
  cp "$SC" "$D/p1/eng/check-stale-claims.sh"
  sc_run "$D/p1" > "$D/p1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] \
    && grep -q 'SKIP: S1 — delivery.rules 未点亮（dp_stale_lit 缺登记）' "$D/p1.out" \
    && grep -q 'SKIP: S2 — delivery.rules 未点亮（dp_stale_lit 缺登记）' "$D/p1.out" \
    && grep -q '登记表 2 条全部核对' "$D/p1.out" \
    && ! grep -q '^STALE' "$D/p1.out"; then
    ok '正例 P1 未点亮 → S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 2'
  else
    bad '正例 P1 未点亮 → S1/S2 SKIP 行、零 STALE、exit 0、汇总登记数 2' "exit=$rc $(tail -n 2 "$D/p1.out" | tr '\n' '|')"
  fi

  # 正例 P2：点亮（dp_stale_lit S1＋S2，无 payload 节）→ 无 SKIP 行、S1/S2 断言逻辑执行
  # （S2 权威位置缺席 STALE、S1 退化 WARN）、汇总登记数 4（点亮数＋通用条数）
  sc_build_fixture "$D/p2"
  mkdir -p "$D/p2/eng"
  cp "$SC" "$D/p2/eng/check-stale-claims.sh"
  cat > "$D/p2/repo/delivery.rules" <<'EOF'
# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====

dp_stale_lit S1
dp_stale_lit S2
EOF
  sc_run "$D/p2" > "$D/p2.out" 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] \
    && ! grep -q '^SKIP: S1' "$D/p2.out" \
    && ! grep -q '^SKIP: S2' "$D/p2.out" \
    && grep -q '^STALE: README.md' "$D/p2.out" \
    && grep -q '登记表共 4 条' "$D/p2.out"; then
    ok '正例 P2 点亮 → S1/S2 断言逻辑执行（无 SKIP、STALE 行证明断言在跑）、汇总登记数 4（点亮数＋通用条数）'
  else
    bad '正例 P2 点亮 → S1/S2 断言逻辑执行（无 SKIP、STALE 行证明断言在跑）、汇总登记数 4（点亮数＋通用条数）' "exit=$rc $(tail -n 2 "$D/p2.out" | tr '\n' '|')"
  fi

  # 负例 N1：delivery.rules 解析破坏（未知指令）→ exit 2 fail-closed 指名
  sc_build_fixture "$D/n1"
  mkdir -p "$D/n1/eng"
  cp "$SC" "$D/n1/eng/check-stale-claims.sh"
  printf '# ==== calibration：校准豁免与点亮（check-artifacts/check-stale-claims 读）====\n\ndp_bogus x\n' > "$D/n1/repo/delivery.rules"
  sc_run "$D/n1" > "$D/n1.out" 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'delivery.rules 解析破坏（fail-closed，不产生部分结论）' "$D/n1.out" && grep -q '未知指令行' "$D/n1.out"; then
    ok '负例 N1 delivery.rules 解析破坏 → exit 2 且指名违规行'
  else
    bad '负例 N1 delivery.rules 解析破坏 → exit 2 且指名违规行' "exit=$rc"
  fi

  suite_summary 'stale-claims'
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
  for f in generate-module-map.sh module-map.rules ticket-ops.sh generate-progress.sh check-package.sh check-append-only.sh check-artifacts.sh check-stale-claims.sh; do
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
  append-only) suite_append_only ;;
  check-artifacts) suite_check_artifacts ;;
  stale-claims) suite_stale_claims ;;
  all)
    suite_module_map
    suite_ticket_ops
    suite_progress
    suite_check_package
    suite_append_only
    suite_check_artifacts
    suite_stale_claims
    self_check_injection
    ;;
esac

if [ "$FAILS" -eq 0 ]; then
  printf 'test-record-layer: PASS（共 %d 项断言，全部通过）\n' "$TOTAL"
  exit 0
fi
printf 'test-record-layer: FAIL（共 %d 项断言，%d 项失败）\n' "$TOTAL" "$FAILS"
exit 1
