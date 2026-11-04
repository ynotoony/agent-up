#!/bin/sh
if [ "${TEST_RECORD_SOURCE_ONLY:-0}" != 1 ]; then
  TESTS_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 2
  sh "$TESTS_DIR/test-runner.sh" --suite project-dashboard "$@"
  exit $?
fi
# shellcheck disable=SC2034  # CUR_SUITE/SUITE_FAILS/SUITE_START 由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）


# ============================================================
# suite: project-dashboard（本地项目仪表盘 project-dashboard.html）
# 覆盖：静态单文件与零外部依赖断言；纯逻辑核心块在 Node 中抽取运行——JSON/Markdown
# 卡片解析、状态合并（index.json 为准）、自动刷新数据源（每次 collect 重新读取、内容
# 变更/新增文件反映）、缺失与损坏逐项提示、不可信文本纯文本渲染与转义；零写入静态
# 面（无写入/删除 API、无网络 API）；公开包登记（清单 scripts 节、README 成员表、
# 安装政策门控、runner 派发表）；安装门控真跑落位。
# 环境依赖：node（抽取运行页面核心逻辑）；缺 node 时本套件 exit 2（不制造假绿）。
# 夹具全部 mktemp，trap 清理；仓库零写入。
# ============================================================

DASH_NAME='project-dashboard.html'

pd_node_program() {
  # 输出 Node 测试程序到 stdout；参数：$1=HTML 路径
  cat <<'NODE_TEST'
'use strict';
const fs = require('fs');
const vm = require('vm');
const htmlPath = process.argv[2];
const html = fs.readFileSync(htmlPath, 'utf8');

let failures = 0;
const pendingChecks = [];
function check(name, fn) {
  try {
    const value = fn();
    if (value && typeof value.then === 'function') {
      pendingChecks.push(value.then(function () {
        console.log('ok: ' + name);
      }, function (err) {
        failures += 1;
        console.log('not ok: ' + name + ' -- ' + (err && err.message ? err.message : String(err)));
      }));
      return;
    }
    if (value === false) throw new Error('断言返回 false');
    console.log('ok: ' + name);
  } catch (err) {
    failures += 1;
    console.log('not ok: ' + name + ' -- ' + (err && err.message ? err.message : String(err)));
  }
}
function eq(actual, expected, label) {
  const a = JSON.stringify(actual);
  const b = JSON.stringify(expected);
  if (a !== b) throw new Error((label ? label + ' ' : '') + '期望 ' + b + ' 实际 ' + a);
}
function truthy(value, label) {
  if (!value) throw new Error((label || '断言') + ' 不成立');
}

const coreMatch = /<script id="agent-up-dashboard-core">([\s\S]*?)<\/script>/.exec(html);
if (!coreMatch) {
  console.log('not ok: 页面存在核心脚本块 -- 未找到 agent-up-dashboard-core');
  process.exit(1);
}
const sandbox = { window: {}, console: console };
vm.createContext(sandbox);
vm.runInContext(coreMatch[1], sandbox, { filename: 'agent-up-dashboard-core.js' });
const core = sandbox.window.__agentUpDashboard;
if (!core) {
  console.log('not ok: 核心脚本块暴露 window.__agentUpDashboard -- 未暴露');
  process.exit(1);
}

const MAP_TEXT = JSON.stringify({
  generated_at: '2026-10-27T10:00',
  workspace_fingerprint: 'abcd1234',
  nodes: ['README.md', 'scripts/run.sh', 'scripts/lib.sh'],
  edges: [
    { from: 'scripts/run.sh', to: 'scripts/lib.sh', label: 'source' },
    { from: 'scripts/run.sh', to: 'external-pkg', label: 'import' }
  ]
});
const INDEX_TEXT = JSON.stringify({
  issues: [
    { id: '01-md-card', status: 'done', complexity: 'C0', blocked_by: [], updated_at: '2026-10-01T10:00' },
    { id: '02-json-card', status: 'in_progress', complexity: 'C2', blocked_by: ['01-md-card'], updated_at: '2026-10-02T10:00' },
    { id: '03-orphan', status: 'ready', complexity: 'C1', blocked_by: [], updated_at: '2026-10-03T10:00' }
  ]
});
const MD_TEXT = [
  '# 01 — Markdown 卡片标题',
  '',
  '**Status:** `superseded`',
  '',
  '**Complexity:** `C0`',
  '',
  '**Blocked by:** 无；可立即领取。',
  '',
  '**Acceptance:**',
  '',
  '- [x] 第一条验收',
  '- [ ] 第二条验收',
  '',
  '**Scope:**',
  '',
  '- docs/ 目录'
].join('\n');
const JSON_TEXT = JSON.stringify({
  id: '02-json-card',
  kind: 'task',
  title: 'JSON 卡片标题',
  complexity: 'C2',
  blocked_by: ['01-md-card'],
  acceptance: [
    { text: '机器可验条件', kind: 'machine', verify_ref: 'verification[0]' },
    '字符串形态验收'
  ],
  scope: ['agent-up/scripts/']
});

function snapshotFixture() {
  return {
    at: 1700000000000,
    moduleMap: { text: MAP_TEXT, error: null },
    index: { text: INDEX_TEXT, error: null },
    tickets: [
      { name: '01-md-card.md', text: MD_TEXT, error: null },
      { name: '02-json-card.json', text: JSON_TEXT, error: null }
    ],
    ticketsError: null
  };
}

function assertApi() {
  const names = ['parseJson', 'parseIndex', 'parseMarkdownCard', 'normalizeTicketCard', 'buildViewModel',
    'collectProjectModel', 'pickDirectory', 'detectCapabilities', 'layoutGraph', 'buildGraphModel',
    'filterCards', 'nodeRelations', 'escapeHtml', 'plainText', 'fingerprintSnapshot', 'buildSnapshot'];
  names.forEach((name) => truthy(typeof core[name] === 'function', '缺少核心函数 ' + name));
}

check('核心块暴露解析、状态合并、刷新与安全渲染函数', assertApi);

check('能力检测：无 API 时给出明确不支持提示', () => {
  const caps = core.detectCapabilities({});
  eq(caps.supported, false);
  eq(caps.code, 'unsupported');
  truthy(/Chrome/.test(caps.message) && /Edge/.test(caps.message), '提示须点名 Chrome 与 Edge');
});

check('能力检测：存在 API 时判定支持；pickDirectory 以 read 模式请求授权', () => {
  let seenOptions = null;
  const scope = {
    showDirectoryPicker: function (options) { seenOptions = options; return Promise.resolve({ name: 'demo-root' }); }
  };
  eq(core.detectCapabilities(scope).supported, true);
  const pending = core.pickDirectory(scope);
  eq(seenOptions, { mode: 'read' });
  eq(typeof pending.then, 'function');
  pending.then(function () {}, function () {});
});

check('能力检测：缺少 API 时 pickDirectory 拒绝而非静默绕过', () => {
  return core.pickDirectory({}).then(function () {
    throw new Error('缺 API 时不应成功');
  }, function (err) {
    truthy(/不支持/.test(err.message), '拒绝原因须指明不支持');
  });
});

check('JSON 解析：合法与损坏分别给出结果与错误信息', () => {
  eq(core.parseJson('{"a":1}').ok, true);
  eq(core.parseJson('{"a":1}').value.a, 1);
  const bad = core.parseJson('{oops');
  eq(bad.ok, false);
  truthy(/JSON 解析失败/.test(bad.error), '错误信息须标明 JSON 解析失败');
});

check('索引解析：条目映射与畸形结构逐项报出', () => {
  const ok = core.parseIndex(INDEX_TEXT);
  eq(ok.ok, true);
  eq(ok.entries.length, 3);
  eq(ok.byId['02-json-card'].status, 'in_progress');
  eq(ok.byId['02-json-card'].blockedBy, ['01-md-card']);
  const broken = core.parseIndex('{"issues": {}}');
  eq(broken.ok, false);
  truthy(/issues/.test(broken.error), '错误须指名 issues 数组');
  const noId = core.parseIndex('{"issues": [{"status": "done"}, {"id": "09-x", "status": "ready"}]}');
  eq(noId.ok, true);
  eq(noId.warnings.length >= 1, true);
  truthy(/缺少 id/.test(noId.warnings.join(' ')), '缺 id 条目须逐条提示');
});

check('Markdown 卡片解析：标题、状态、复杂度与验收列表', () => {
  const card = core.parseMarkdownCard(MD_TEXT, '01-md-card.md');
  eq(card.id, '01-md-card');
  eq(card.title, 'Markdown 卡片标题');
  eq(card.declaredStatus, 'superseded');
  eq(card.complexity, 'C0');
  eq(card.acceptance, ['第一条验收', '第二条验收']);
  eq(card.blockedBy, []);
  eq(card.format, 'markdown');
});

check('JSON 卡片解析：对象形态验收条件与缺字段提示', () => {
  const card = core.normalizeTicketCard(JSON.parse(JSON_TEXT), '02-json-card.json', JSON_TEXT.length);
  eq(card.title, 'JSON 卡片标题');
  eq(card.acceptance, ['机器可验条件', '字符串形态验收']);
  eq(card.blockedBy, ['01-md-card']);
  const bare = core.normalizeTicketCard({ id: '10-bare' }, '10-bare.json', 20);
  truthy(bare.warnings.join(' ').indexOf('缺少标题') >= 0, '缺 title 须逐项提示');
});

check('状态合并：index.json 为准并记录正文冲突', () => {
  const model = core.buildViewModel(snapshotFixture());
  const md = model.cardsById['01-md-card'];
  eq(md.status, 'done');
  eq(md.statusSource, 'index');
  eq(md.statusConflict, { card: 'superseded', index: 'done' });
  eq(model.conflicts.length, 1);
  truthy(model.warnings.join(' ').indexOf('以索引为准') >= 0, '冲突提示须写明以索引为准');
});

check('搜索按生效状态：索引状态可搜、正文冲突状态不误命中', () => {
  const model = core.buildViewModel({
    at: 1,
    moduleMap: { text: MAP_TEXT, error: null },
    index: { text: JSON.stringify({ issues: [{ id: '05-conflict', status: 'done', complexity: 'C1', blocked_by: [] }] }), error: null },
    tickets: [{ name: '05-conflict.md', text: '# 05 — 冲突卡\n\n**Status:** `ready`\n\n**Complexity:** `C1`\n', error: null }]
  });
  eq(model.cards[0].status, 'done');
  eq(model.cards[0].statusConflict, { card: 'ready', index: 'done' });
  eq(core.filterCards(model.cards, 'done', 'all').map((card) => card.id), ['05-conflict']);
  eq(core.filterCards(model.cards, 'ready', 'all').length, 0);
  eq(core.filterCards(model.cards, '', 'done').map((card) => card.id), ['05-conflict']);
  eq(core.filterCards(model.cards, '', 'ready').length, 0);
  truthy(model.cards[0].searchText.indexOf('done') >= 0, 'searchText 须含生效状态');
});

check('索引读取失败：模型标记降级、状态按正文并保留失败提示', () => {
  const model = core.buildViewModel({
    at: 1,
    moduleMap: { text: MAP_TEXT, error: null },
    index: { text: null, error: '没有读取权限（NotAllowedError）' },
    tickets: [{ name: '01-md-card.md', text: MD_TEXT, error: null }]
  });
  eq(model.indexOk, false);
  eq(model.degraded, true);
  eq(model.cards[0].status, 'superseded');
  eq(model.cards[0].statusSource, 'card');
  truthy(model.warnings.join(' ').indexOf('没有读取权限') >= 0, '索引失败提示须保留');
});

check('全部卡片无遗漏：Markdown 与 JSON 卡同时列出，孤儿索引条目逐项提示', () => {
  const model = core.buildViewModel(snapshotFixture());
  eq(model.counts.cards, 2);
  eq(model.cards.map((card) => card.id).sort(), ['01-md-card', '02-json-card']);
  eq(model.orphans.map((entry) => entry.id), ['03-orphan']);
  truthy(model.warnings.join(' ').indexOf('03-orphan') >= 0, '孤儿索引条目须指名');
});

check('地图节点/边与 module-map.json 一致并列出未解析引用', () => {
  const model = core.buildViewModel(snapshotFixture());
  eq(model.graph.ok, true);
  eq(model.graph.nodes, ['README.md', 'scripts/run.sh', 'scripts/lib.sh']);
  eq(model.graph.edges.length, 2);
  eq(model.graph.dangling.length, 1);
  eq(model.graph.dangling[0].to, 'external-pkg');
  eq(core.nodeRelations(model.graph, 'scripts/run.sh').outgoing.length, 1);
  eq(core.nodeRelations(model.graph, 'scripts/run.sh').dangling.length, 1);
  eq(core.nodeRelations(model.graph, 'scripts/lib.sh').incoming.length, 1);
});

check('缺失地图逐项提示且声明不扫描源码重建', () => {
  const snapshot = snapshotFixture();
  snapshot.moduleMap = { text: null, error: '文件或目录不存在（NotFoundError）' };
  const model = core.buildViewModel(snapshot);
  eq(model.graph.ok, false);
  const joined = model.warnings.join(' ');
  truthy(joined.indexOf('module-map.json') >= 0, '提示须指名地图路径');
  truthy(joined.indexOf('不扫描源码重建') >= 0, '提示须声明不重建地图');
});

check('损坏卡片与读取失败卡片逐项提示、不静默遗漏、不影响其他卡片', () => {
  const snapshot = snapshotFixture();
  snapshot.tickets.push({ name: '03-broken.json', text: '{not json', error: null });
  snapshot.tickets.push({ name: '04-unreadable.md', text: null, error: '没有读取权限（NotAllowedError）' });
  snapshot.tickets.push({ name: '05-not-a-card.txt', text: 'ignored', error: null });
  const model = core.buildViewModel(snapshot);
  eq(model.counts.cards, 4);
  eq(model.counts.invalidCards, 2);
  const joined = model.warnings.join(' ');
  truthy(joined.indexOf('03-broken.json') >= 0, '损坏 JSON 卡须指名文件');
  truthy(joined.indexOf('04-unreadable.md') >= 0, '读取失败卡须指名文件');
  eq(model.cardsById['01-md-card'].status, 'done');
});

check('不可信文本纯文本保留并转义，不产生可执行标记', () => {
  const payload = '<img src=x onerror="globalThis.__pwned=1"><script>bad()</script>';
  const card = core.parseMarkdownCard('# 99 — ' + payload + '\n\n**Status:** `ready`\n', '99-pwn.md');
  eq(card.title, payload);
  truthy(card.title.indexOf('<img') === 0, '解析结果保持纯文本原样（由渲染层按文本节点落位）');
  const escaped = core.escapeHtml(payload);
  truthy(escaped.indexOf('<img') < 0 && escaped.indexOf('&lt;img') === 0, '转义输出不得含原始标签');
  truthy(escaped.indexOf('&quot;') >= 0, '引号须转义');
  const model = core.buildViewModel({
    at: 1,
    moduleMap: { text: MAP_TEXT, error: null },
    index: { text: JSON.stringify({ issues: [] }), error: null },
    tickets: [{ name: '99-pwn.md', text: '# 99 — ' + payload + '\n', error: null }]
  });
  eq(model.warnings.join(' ').indexOf('<img') >= 0, false);
  eq(model.cards[0].title, payload);
});

check('布局稳定：同输入同位置，节点落在画布内且按依赖分列', () => {
  const graph = core.buildGraphModel(JSON.parse(MAP_TEXT));
  const first = core.layoutGraph(graph, { hGap: 200, vGap: 30, pad: 20 });
  const second = core.layoutGraph(graph, { hGap: 200, vGap: 30, pad: 20 });
  eq(first.positions, second.positions);
  eq(first.positions['scripts/lib.sh'].x > first.positions['scripts/run.sh'].x, true);
  Object.keys(first.positions).forEach((name) => {
    truthy(first.positions[name].x + first.nodeWidth <= first.width, name + ' 越出画布宽度');
    truthy(first.positions[name].y + first.nodeHeight <= first.height, name + ' 越出画布高度');
  });
});

check('搜索与状态筛选按卡片字段生效', () => {
  const model = core.buildViewModel(snapshotFixture());
  eq(core.filterCards(model.cards, '', 'all').length, 2);
  eq(core.filterCards(model.cards, '', 'done').map((c) => c.id), ['01-md-card']);
  eq(core.filterCards(model.cards, '验收', 'all').map((c) => c.id), ['02-json-card', '01-md-card']);
  eq(core.filterCards(model.cards, '不存在关键词', 'all').length, 0);
});

const mutationTarget = {
  at: 1,
  moduleMap: { text: MAP_TEXT, error: null },
  index: { text: INDEX_TEXT, error: null },
  tickets: [{ name: '01-md-card.md', text: MD_TEXT, error: null }],
  ticketsError: null
};

check('快照增量重建不修改输入对象', () => {
  const before = JSON.stringify(mutationTarget);
  const next = core.buildSnapshot(mutationTarget, [{ name: '02-new.json', text: '{}' }]);
  eq(JSON.stringify(mutationTarget), before);
  eq(next.tickets.length, 2);
  eq(next.tickets[1].name, '02-new.json');
});

function makeSource(files, errors) {
  const state = { reads: [], lists: 0 };
  return {
    calls: state,
    now: () => 1700000000000,
    listTickets: () => {
      state.lists += 1;
      return Promise.resolve(Object.keys(files).filter((key) => key.indexOf('facts/requirements/tickets/') === 0)
        .map((key) => key.slice('facts/requirements/tickets/'.length)));
    },
    readText: (segments) => {
      const key = segments.join('/');
      state.reads.push(key);
      if (errors && errors[key]) {
        const err = new Error(errors[key]);
        err.name = 'NotFoundError';
        return Promise.reject(err);
      }
      if (!Object.prototype.hasOwnProperty.call(files, key)) {
        const err = new Error('缺失 ' + key);
        err.name = 'NotFoundError';
        return Promise.reject(err);
      }
      return Promise.resolve(files[key]);
    }
  };
}

function baseFiles() {
  return {
    'facts/project/architecture/module-map.json': MAP_TEXT,
    'facts/requirements/tickets/index.json': INDEX_TEXT,
    'facts/requirements/tickets/01-md-card.md': MD_TEXT,
    'facts/requirements/tickets/02-json-card.json': JSON_TEXT
  };
}

async function refreshChecks() {
  const files = baseFiles();
  const source = makeSource(files, {});
  const first = await core.collectProjectModel(source);
  let model = core.buildViewModel(first);
  check('自动刷新数据源：首次读取地图、索引与每张卡片', () => {
    truthy(source.calls.reads.indexOf('facts/project/architecture/module-map.json') >= 0, '未读取地图');
    truthy(source.calls.reads.indexOf('facts/requirements/tickets/index.json') >= 0, '未读取索引');
    truthy(source.calls.reads.indexOf('facts/requirements/tickets/01-md-card.md') >= 0, '未读取 Markdown 卡');
    truthy(source.calls.reads.indexOf('facts/requirements/tickets/02-json-card.json') >= 0, '未读取 JSON 卡');
    eq(model.counts.cards, 2);
  });

  const readsAfterFirst = source.calls.reads.length;
  const firstFingerprint = model.fingerprint;
  files['facts/requirements/tickets/01-md-card.md'] = MD_TEXT.replace('Markdown 卡片标题', 'Markdown 卡片标题（已更新）');
  const second = await core.collectProjectModel(source);
  model = core.buildViewModel(second);
  check('自动刷新数据源：再次 collect 重新 getFile 并反映内容变更', () => {
    eq(source.calls.reads.length > readsAfterFirst, true);
    eq(source.calls.lists, 2);
    truthy(model.fingerprint !== firstFingerprint, '内容变更后指纹须变化');
    eq(model.cardsById['01-md-card'].title, 'Markdown 卡片标题（已更新）');
  });

  files['facts/requirements/tickets/06-added.md'] = '# 06 — 新增卡片\n\n**Status:** `ready`\n';
  const third = await core.collectProjectModel(source);
  model = core.buildViewModel(third);
  check('自动刷新数据源：新增卡片文件在下次 collect 出现', () => {
    eq(model.counts.cards, 3);
    eq(model.cardsById['06-added'].title, '新增卡片');
  });

  delete files['facts/requirements/tickets/06-added.md'];
  const fourth = await core.collectProjectModel(source);
  model = core.buildViewModel(fourth);
  check('自动刷新数据源：删除卡片文件在下次 collect 消失', () => {
    eq(model.counts.cards, 2);
    eq(model.cardsById['06-added'], undefined);
  });

  const brokenFiles = baseFiles();
  const brokenSource = makeSource(brokenFiles, { 'facts/requirements/tickets/02-json-card.json': '读不到' });
  const fifth = await core.collectProjectModel(brokenSource);
  model = core.buildViewModel(fifth);
  check('刷新期单文件读取失败：逐项提示且其余卡片照常更新', () => {
    eq(model.counts.cards, 2);
    eq(model.counts.invalidCards, 1);
    truthy(model.warnings.join(' ').indexOf('02-json-card.json') >= 0, '失败卡片须指名');
    eq(model.cardsById['01-md-card'].status, 'done');
  });

  const emptySource = makeSource({}, {});
  const sixth = await core.collectProjectModel(emptySource);
  model = core.buildViewModel(sixth);
  check('空目录：地图/索引缺失逐项提示且不抛异常', () => {
    eq(model.counts.cards, 0);
    truthy(model.warnings.join(' ').indexOf('module-map.json') >= 0, '地图缺失须提示');
    truthy(model.warnings.join(' ').indexOf('index.json') >= 0, '索引缺失须提示');
  });

  check('指纹：同内容稳定、变化即不同', () => {
    const a = core.fingerprintSnapshot(snapshotFixture());
    const b = core.fingerprintSnapshot(snapshotFixture());
    eq(a, b);
    const changed = snapshotFixture();
    changed.tickets[0].text = changed.tickets[0].text + '\n补充\n';
    truthy(core.fingerprintSnapshot(changed) !== a, '内容变化须使指纹变化');
  });

  check('核心不暴露任何写入/删除/网络能力', () => {
    const forbidden = ['writeFile', 'createWritable', 'removeEntry', 'remove', 'fetch', 'request'];
    forbidden.forEach((name) => eq(typeof core[name], 'undefined'));
  });

  if (failures > 0) process.exitCode = 1;
}

refreshChecks().then(function () { return Promise.all(pendingChecks); }).then(() => {
  if (failures > 0) process.exit(1);
}, (err) => {
  console.log('not ok: 刷新检查执行异常 -- ' + (err && err.message ? err.message : String(err)));
  process.exit(1);
});
NODE_TEST
}

suite_project_dashboard() {
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  CUR_SUITE='project-dashboard'
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_FAILS=0
  # shellcheck disable=SC2034  # 套件计数器由 sourced 的 test-helpers.sh suite_summary 使用（单文件视野误报）
  SUITE_START=$TOTAL
  D=$T/pdash
  mkdir -p "$D"

  HTML="$SCRIPT_DIR/$DASH_NAME"
  if [ ! -f "$HTML" ]; then
    bad "页面文件存在 checks/$DASH_NAME" "未找到 $HTML"
    suite_summary 'project-dashboard'
    return 0
  fi
  cp "$HTML" "$D/original.html"

  # ---- 静态面：单文件、零外部依赖、零写入、零网络 ----
  if require_out 'suite-project-dashboard 目标输出在场' "$HTML" && ! grep -q '<script src=' "$HTML" && ! grep -q '<link ' "$HTML" && ! grep -q '@import' "$HTML"; then
    ok '单一自包含文件：无外部脚本、样式或资源引用'
  else
    bad '单一自包含文件：无外部脚本、样式或资源引用' '发现外部引用'
  fi

  if grep -Ei 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function' "$HTML" >/dev/null 2>&1; then
    bad '不可信文本不进入 HTML 注入面（无 HTML 解释型赋值 API）' "$(grep -Ein 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function' "$HTML" | head -n 3)"
  else
    ok '不可信文本不进入 HTML 注入面（无 HTML 解释型赋值 API）'
  fi

  if grep -Ei 'fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon|navigator\.sendBeacon' "$HTML" >/dev/null 2>&1; then
    bad '零网络：页面不含任何网络请求 API' "$(grep -Ein 'fetch\(|XMLHttpRequest|WebSocket|EventSource|sendBeacon' "$HTML" | head -n 3)"
  else
    ok '零网络：页面不含任何网络请求 API'
  fi

  if grep -Ei 'createWritable|removeEntry|\.remove\(\)|getFileHandle\([^)]*create: *true|getDirectoryHandle\([^)]*create: *true|readwrite' "$HTML" >/dev/null 2>&1; then
    bad '零写入：页面不申请读写权限或写删文件' "$(grep -Ein 'createWritable|removeEntry|readwrite' "$HTML" | head -n 3)"
  else
    ok '零写入：页面不申请读写权限或写删文件'
  fi

  if grep -q "mode: 'read'" "$HTML"; then
    ok '目录授权显式使用只读模式（mode: read）'
  else
    bad '目录授权显式使用只读模式（mode: read）' '未找到只读模式参数'
  fi

  if grep -q 'id="agent-up-dashboard-core"' "$HTML" && grep -q '__agentUpDashboard' "$HTML"; then
    ok '纯逻辑核心块与 window.__agentUpDashboard 测试钩子在场'
  else
    bad '纯逻辑核心块与 window.__agentUpDashboard 测试钩子在场' '缺少核心脚本块或测试钩子'
  fi

  # ---- Node 抽取运行核心逻辑 ----
  if ! command -v node >/dev/null 2>&1; then
    printf 'project-dashboard: node 不可用——本套件在 Node 中抽取运行页面核心逻辑（JSON/Markdown 解析、状态合并、刷新数据源、安全渲染）\n' >&2
    exit 2
  fi
  pd_node_program > "$D/core.test.js"
  node "$D/core.test.js" "$HTML" > "$D/node.out" 2>&1
  node_rc=$?
  while IFS= read -r line; do
    case $line in
      'ok: '*) ok "${line#ok: }" ;;
      'not ok: '*) bad "${line#not ok: }" ;;
      *) : ;;
    esac
  done < "$D/node.out"
  if require_out 'suite-project-dashboard 目标输出在场' "$D/node.out" && [ "$node_rc" -ne 0 ] && ! grep -q '^not ok: ' "$D/node.out"; then
    bad 'Node 核心逻辑执行完成' "$(tail -n 3 "$D/node.out" | tr '\n' '|')"
  fi

  # ---- 页面文件只读零改动（抽取运行不应改文件）----
  if cmp -s "$HTML" "$D/original.html"; then
    ok '抽取运行前后页面文件逐字节一致（零写入）'
  else
    bad '抽取运行前后页面文件逐字节一致（零写入）' '页面文件被修改'
  fi

  # ---- 公开包登记 ----
  MANIFEST="$SCRIPT_DIR/package-manifest.rules"
  if grep -q "^pm_script scripts/$DASH_NAME " "$MANIFEST"; then
    ok '包清单 scripts 节登记仪表盘件'
  else
    bad '包清单 scripts 节登记仪表盘件' "缺少 pm_script scripts/$DASH_NAME 行"
  fi

  if grep -q "| \`$DASH_NAME\` |" "$SCRIPT_DIR/README.md"; then
    ok 'scripts/README.md 成员表登记仪表盘件'
  else
    bad 'scripts/README.md 成员表登记仪表盘件' '成员表缺少行'
  fi

  POLICY="$SCRIPT_DIR/install-policy.rules"
  if grep -q "^ip_file agent-up/scripts/$DASH_NAME Conditional ticket-ops " "$POLICY"; then
    ok '安装政策登记仪表盘复制行（ticket-ops 门控）'
  else
    bad '安装政策登记仪表盘复制行（ticket-ops 门控）' '缺少 ip_file ticket-ops 行'
  fi

  if grep -q 'suite-project-dashboard.sh' "$SCRIPT_DIR/tests/test-runner.sh"; then
    ok 'runner 派发表登记 project-dashboard 套件'
  else
    bad 'runner 派发表登记 project-dashboard 套件' 'test-runner.sh 未登记'
  fi

  # 栅栏环境跳过（口径同 check-package 检查 8/9 与 suite-install：worktree-add.sh 按
  # delivery.rules dp_mainonly 排除 main-only 件，install.sh 在 worktree 内物理不在场）：
  # 两条安装闭包断言显式 SKIP 不计数，覆盖归主检出全量，不宣称不存在的验证。
  if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    printf 'SKIP  [project-dashboard] 安装闭包真跑与缺源件负例（install.sh main-only 栅栏件不在场）——两条断言跳过，覆盖归主检出\n'
  else
    # ---- 安装闭包真跑：按登记的复制行落位（夹具政策＝真实登记两行，源件齐） ----
    PKG="$D/pkg"
    mkdir -p "$PKG/scripts" "$D/proj"
    cp "$SCRIPT_DIR/install.sh" "$HTML" "$PKG/scripts/"
    grep -F 'ip_gate ticket-ops --ticket-ops ' "$POLICY" > "$PKG/scripts/install-policy.rules"
    grep -F "ip_file agent-up/scripts/$DASH_NAME Conditional ticket-ops " "$POLICY" >> "$PKG/scripts/install-policy.rules"
    ( cd "$D" && sh "$PKG/scripts/install.sh" --target "$D/proj" --ticket-ops ) > "$D/install.out" 2>&1
    install_rc=$?
    if [ "$install_rc" -eq 0 ] \
      && [ -f "$D/proj/rules/implementation/scripts/$DASH_NAME" ] \
      && cmp -s "$HTML" "$D/proj/rules/implementation/scripts/$DASH_NAME" \
      && grep -q '^install: DONE: 复制 1 件（脚本 1＋数据 0）' "$D/install.out"; then
      ok '安装闭包真跑：登记行经 ticket-ops 门控复制仪表盘一件且与基线字节一致'
    else
      bad '安装闭包真跑：登记行经 ticket-ops 门控复制仪表盘一件且与基线字节一致' "exit=$install_rc out=$(tail -n 2 "$D/install.out" | tr '\n' '|')"
    fi

    # 负例：包内缺仪表盘源件 → 预检失败 exit 1 指名路径、零写入
    PKGB="$D/pkgb"
    mkdir -p "$PKGB/scripts" "$D/projb"
    cp "$SCRIPT_DIR/install.sh" "$PKGB/scripts/"
    cp "$PKG/scripts/install-policy.rules" "$PKGB/scripts/"
    ( cd "$D" && sh "$PKGB/scripts/install.sh" --target "$D/projb" --ticket-ops ) > /dev/null 2>"$D/install-bad.err"
    bad_rc=$?
    if [ "$bad_rc" -eq 1 ] && grep -q "$DASH_NAME" "$D/install-bad.err" && [ ! -d "$D/projb/rules" ]; then
      ok '安装预检负例：缺源件 exit 1 指名路径、零写入'
    else
      bad '安装预检负例：缺源件 exit 1 指名路径、零写入' "exit=$bad_rc err=$(head -n 1 "$D/install-bad.err")"
    fi
  fi

  suite_summary 'project-dashboard'
}
