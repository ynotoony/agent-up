#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite module-map "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（shellcheck 单文件视野误报）


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
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='module-map'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/mm
  mkdir -p "$D"
  mm_build_fixture "$D/repo"

  out=$(sh "$MM" "$D/repo" 2>"$D/err1")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok '正例生成 exit 0（11 语言夹具仓）'
  else
    bad '正例生成 exit 0（11 语言夹具仓）' "exit=$rc stderr=$(head -n 1 "$D/err1")"
  fi

  summary=$(printf '%s\n' "$out" | sed -n 's/^generate-module-map: OK: .*（fp-v1:[0-9a-f]\{16\}，nodes \([0-9]\{1,\}\)，edges \([0-9]\{1,\}\)）$/\1 \2/p')
  if [ "$summary" = '19 50' ]; then
    ok 'stdout 摘要计数（nodes 19，edges 50）'
  else
    bad 'stdout 摘要计数（nodes 19，edges 50）' "实际: $summary"
  fi

  map="$D/repo/facts/project/architecture/module-map.json"
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
  fp2=$(sed -n 's/^  "workspace_fingerprint": "\(fp-v1:[0-9a-f]\{16\}\)",\{0,1\}$/\1/p' "$D/repo/facts/project/architecture/module-map.json")
  if [ -n "$fp1" ] && [ "$fp1" = "$fp2" ]; then
    ok 'fp 稳定性（同输入复跑指纹不变）'
  else
    bad 'fp 稳定性（同输入复跑指纹不变）' "$fp1 vs $fp2"
  fi

  printf '\n' >> "$D/repo/app.py"
  sh "$MM" "$D/repo" >/dev/null 2>&1
  fp3=$(sed -n 's/^  "workspace_fingerprint": "\(fp-v1:[0-9a-f]\{16\}\)",\{0,1\}$/\1/p' "$D/repo/facts/project/architecture/module-map.json")
  if [ -n "$fp3" ] && [ "$fp1" != "$fp3" ]; then
    ok 'fp 变更检出（内容改动后指纹变化）'
  else
    bad 'fp 变更检出（内容改动后指纹变化）' "$fp1 vs $fp3"
  fi

  # 负例 N1：规则表损坏 → exit 2 且不写地图（临时副本上结构破坏：mm_rule 参数数不合预期，
  # 被测本体零触碰；行为级破坏——label 漂移——由注入自检与边集断言承载）
  mkdir -p "$D/broken"
  cp "$SCRIPT_DIR/generate-module-map.sh" "$D/broken/"
  cp "$SCRIPT_DIR/module-map.rules" "$D/broken/module-map.rules"
  printf "mm_rule 'bogus-lang' '*.py'\n" >> "$D/broken/module-map.rules"
  rm -rf "$D/repo2"; mm_build_fixture "$D/repo2"
  sh "$D/broken/generate-module-map.sh" "$D/repo2" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ ! -f "$D/repo2/facts/project/architecture/module-map.json" ]; then
    ok '负例 N1 规则表损坏 → exit 2 且零地图写入'
  else
    bad '负例 N1 规则表损坏 → exit 2 且零地图写入' "exit=$rc"
  fi

  # 负例 N2：无已登记源码 → exit 1 且不写地图
  mkdir -p "$D/empty"; git -C "$D/empty" init >/dev/null 2>&1
  sh "$MM" "$D/empty" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ] && [ ! -f "$D/empty/facts/project/architecture/module-map.json" ]; then
    ok '负例 N2 无源码 → exit 1 且零地图写入（fail-closed）'
  else
    bad '负例 N2 无源码 → exit 1 且零地图写入（fail-closed）' "exit=$rc"
  fi

  # 负例 N3：非 Git 目录 → exit 2
  mkdir -p "$D/nogit"
  sh "$MM" "$D/nogit" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    ok '负例 N3 非 Git 目录 → exit 2'
  else
    bad '负例 N3 非 Git 目录 → exit 2' "exit=$rc"
  fi

  # 票 145 恶意输入负例 N4～N6：临时副本规则表注入恶意行 → 解析期 exit 2 且零地图写入
  # （命令替换/反引号/未知指令先于任何规则语义执行被拒——非执行式解析门禁）。
  for mm_i in 1 2 3; do
    mkdir -p "$D/mal$mm_i"
    cp "$SCRIPT_DIR/generate-module-map.sh" "$D/mal$mm_i/"
    cp "$SCRIPT_DIR/module-map.rules" "$D/mal$mm_i/module-map.rules"
    rm -rf "$D/mrepo$mm_i"; mm_build_fixture "$D/mrepo$mm_i"
    case $mm_i in
      1) printf "mm_rule 'python' '*.py' '' '' 'cov' 'x\$(touch /tmp/trl145mm1)x'\n" >> "$D/mal1/module-map.rules" ;;
      2) printf "mm_rule 'python' '*.py' '' '' 'cov' 'x\`touch /tmp/trl145mm2\`x'\n" >> "$D/mal2/module-map.rules" ;;
      3) printf "evil_cmd 'rm' '-rf' '/' 'x' 'y' 'z'\n" >> "$D/mal3/module-map.rules" ;;
    esac
    sh "$D/mal$mm_i/generate-module-map.sh" "$D/mrepo$mm_i" >"/dev/null" 2>"$D/mal$mm_i/err"
    rc=$?
    case $mm_i in
      1) mm_desc='负例 N4 规则表命令替换注入（引号内美元括号）→ exit 2 且零地图写入'; mm_probe=/tmp/trl145mm1 ;;
      2) mm_desc='负例 N5 规则表反引号注入 → exit 2 且零地图写入'; mm_probe=/tmp/trl145mm2 ;;
      3) mm_desc='负例 N6 未知指令注入 → exit 2 且零地图写入'; mm_probe='' ;;
    esac
    if [ "$rc" -eq 2 ] && [ ! -f "$D/mrepo$mm_i/facts/project/architecture/module-map.json" ] \
      && { [ -z "$mm_probe" ] && ! ls "$mm_probe" >/dev/null 2>&1 || [ -n "$mm_probe" ] && [ ! -e "$mm_probe" ]; } \
      && grep -q '非执行式解析不合预期' "$D/mal$mm_i/err"; then
      ok "$mm_desc"
    else
      bad "$mm_desc" "exit=$rc stderr=$(head -n 1 "$D/mal$mm_i/err")"
    fi
  done
  rm -f /tmp/trl145mm1 /tmp/trl145mm2

  # 票 137 schema 融合断言三例（grep 形态零依赖）
  if grep -q '"constraints"' "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" \
    && grep -q '"dispatch_mode"' "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json" \
    && grep -q '"oneOf"' "$SCRIPT_DIR/../references/schemas/ticket-record.schema.json"; then
    ok 'schema 融合三件在位（constraints/dispatch_mode/verification oneOf）'
  else
    bad 'schema 融合三件在位（constraints/dispatch_mode/verification oneOf）'
  fi

  suite_summary 'module-map'
}
