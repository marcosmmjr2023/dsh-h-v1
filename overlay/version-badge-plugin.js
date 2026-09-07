/**
 * Version Badge — badge de versão + chave de auto-atualização + ROLLBACK no painel.
 *
 * Server-side (via ctx.get("webServer")):
 *   GET  /api/dsh-version → { ok, version, commit, updatedAt, autoUpdate }
 *     .dsh-version.json  é GERADO pelo sync (tools/stamp-version.sh/.ps1).
 *     autoUpdate = true quando NÃO existe <config viva>/.dsh-autoupdate.off.
 *   POST /api/dsh-version {"autoUpdate": bool} → cria/remove o flag
 *     .dsh-autoupdate.off (o agendador local de auto-update consulta esse
 *     flag antes de sincronizar). Arquivo é LOCAL da máquina.
 *
 *   GET  /api/dsh-rollback → { ok, current, tags[], snapshots[], previous, autoUpdate }
 *     Lista as versões publicadas (tags vX.Y.Z) e os snapshots locais
 *     (~/.dsh-snapshots) disponíveis para voltar.
 *   POST /api/dsh-rollback {"target": "v0.2.0" | "snap-20260906-..."}
 *     → roda tools/rollback.sh <target> (snapshot automático do estado atual),
 *       DESLIGA o auto-update (flag .dsh-autoupdate.off) e reinicia o harness
 *       sozinho quando ele roda sob pm2 (senão orienta reiniciar manualmente).
 *
 * Client-side: badge "v<versão> · <atualizado>" + botão "🔄 auto" (ON/OFF)
 * + botão "↩" que abre o painel de rollback (voltar para uma versão anterior
 * se uma atualização quebrar o sistema). Recolhidos pelo LayoutPanel na
 * coluna direita (.dlp-badges).
 *
 * Localização dos arquivos: mesmo diretório deste plugin (= config viva).
 * Clone do repo: env DSH_CLONE ou ~/dsh-v2 ou ~/dsh-h-v1 (primeiro com .git).
 */
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFile, spawn } = require("node:child_process");

const VERSION_FILE = path.join(__dirname, ".dsh-version.json");
const AUTO_UPDATE_OFF = path.join(__dirname, ".dsh-autoupdate.off");
const HOME = os.homedir();

function autoUpdateEnabled() {
  return !fs.existsSync(AUTO_UPDATE_OFF);
}

function cloneDir() {
  if (process.env.DSH_CLONE) return process.env.DSH_CLONE;
  const candidates = [
    path.join(HOME, "dsh-v2"),
    path.join(HOME, "dsh-h-v1"),
  ];
  for (const c of candidates) {
    try {
      if (fs.existsSync(path.join(c, ".git")) && fs.existsSync(path.join(c, "tools", "rollback.sh"))) return c;
    } catch { /* tenta o próximo */ }
  }
  return candidates[0];
}

function snapRoot() {
  return process.env.DSH_SNAP_ROOT || path.join(HOME, ".dsh-snapshots");
}

function versionPayload() {
  let data = { ok: false, version: "local", commit: "", updatedAt: "" };
  try {
    data = JSON.parse(fs.readFileSync(VERSION_FILE, "utf8"));
  } catch { /* sem arquivo: instalado manualmente */ }
  return {
    ok: true,
    version: String(data.version ?? "?"),
    commit: String(data.commit ?? ""),
    updatedAt: String(data.updatedAt ?? ""),
    autoUpdate: autoUpdateEnabled(),
  };
}

function setAutoUpdate(enabled) {
  try {
    if (enabled) {
      if (fs.existsSync(AUTO_UPDATE_OFF)) fs.unlinkSync(AUTO_UPDATE_OFF);
    } else {
      fs.writeFileSync(AUTO_UPDATE_OFF, "off\n");
    }
    return { ok: true, autoUpdate: autoUpdateEnabled() };
  } catch (e) {
    return { ok: false, error: String(e.message || e) };
  }
}

function git(args, cb) {
  execFile("git", ["-C", cloneDir()].concat(args), { timeout: 15000 }, (err, stdout, stderr) => {
    if (err) return cb(null, err.message || String(err));
    cb(String(stdout || "").trim());
  });
}

function listSnapshots() {
  const root = snapRoot();
  try {
    return fs.readdirSync(root, { withFileTypes: true })
      .filter((d) => d.isDirectory() && /^snap-/.test(d.name))
      .map((d) => d.name)
      .sort()
      .reverse()
      .slice(0, 8);
  } catch {
    return [];
  }
}

function rollbackList(cb) {
  const current = versionPayload();
  git(["tag", "--list", "v[0-9]*", "--sort=-version:refname", "--format=%(refname:short) %(creatordate:short)"], (tagsText) => {
    const tags = [];
    let names = [];
    if (tagsText) {
      tagsText.split("\n").forEach((line) => {
        const m = /^(\S+)\s+(.*)$/.exec(line);
        if (m) { tags.push({ name: m[1], date: m[2] }); names.push(m[1]); }
      });
    }
    let previous = null;
    const cur = String(current.version || "");
    const idx = names.indexOf(cur);
    if (idx === -1) previous = names.length ? names[0] : null;
    else if (idx + 1 < names.length) previous = names[idx + 1];
    cb({
      ok: true,
      current: { version: cur, commit: current.commit, updatedAt: current.updatedAt },
      tags,
      snapshots: listSnapshots(),
      previous,
      autoUpdate: autoUpdateEnabled(),
      clone: cloneDir(),
    });
  });
}

function doRollback(target, cb) {
  const clone = cloneDir();
  const rollbackTool = path.join(clone, "tools", "rollback.sh");
  if (!fs.existsSync(rollbackTool)) {
    cb({ ok: false, error: "tools/rollback.sh não encontrado no clone: " + clone });
    return;
  }
  const isSnapshot = /^snap-/.test(target);
  const args = isSnapshot ? ["--snapshot", target] : [target];
  const env = Object.assign({}, process.env, {
    DSH_CLONE: clone,
    DSH_LIVE: __dirname,
    DSH_SNAP_ROOT: snapRoot(),
  });
  execFile(rollbackTool, args, { env, timeout: 180000, maxBuffer: 8 * 1024 * 1024 }, (err, stdout, stderr) => {
    const output = String(stdout || "") + (stderr ? "\n[stderr]\n" + stderr : "");
    if (err) {
      cb({ ok: false, error: "rollback falhou (exit " + (err.code ?? "?") + ")", output });
      return;
    }
    const auto = setAutoUpdate(false); // desliga o auto-update: não reaplica a versão que quebrou
    cb({ ok: true, output, autoUpdate: auto.ok ? false : true, rollbackedTo: target });
  });
}

// Descobre o nome do processo pm2 atual (para reiniciar sozinho após rollback)
function pm2NameOfCurrent(cb) {
  if (!process.env.PM2_HOME) return cb(null);
  execFile("pm2", ["jlist"], { timeout: 8000 }, (err, stdout) => {
    if (err) return cb(null);
    try {
      const list = JSON.parse(String(stdout));
      const me = list.find((p) => String(p.pid) === String(process.pid));
      cb(me ? String(me.name) : null);
    } catch {
      cb(null);
    }
  });
}

function scheduleRestart(delayMs) {
  pm2NameOfCurrent((name) => {
    if (!name) {
      console.log("[VersionBadge] rollback ok — reinicie o harness manualmente (sem pm2).");
      return;
    }
    console.log("[VersionBadge] reiniciando " + name + " em " + delayMs + "ms (rollback aplicado)…");
    setTimeout(() => {
      const child = spawn("pm2", ["restart", name], {
        detached: true,
        stdio: "ignore",
        env: process.env,
      });
      child.unref();
    }, delayMs);
  });
}

// ══ CORE (kernel-like): status + atualização/rollback MANUAL via sudo ══
const CORE_CANDIDATES = [
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/package.json",
  "/usr/lib/node_modules/@deepseek-ai/dsh/package.json",
];
const CORE_CHECK_CACHE = path.join(__dirname, ".dsh-core-check.json");
const CORE_HISTORY = path.join(__dirname, ".dsh-core-history.json");

function coreInstalledVersion() {
  for (const f of CORE_CANDIDATES) {
    try { return JSON.parse(fs.readFileSync(f, "utf8")).version; } catch { /* tenta próximo */ }
  }
  return "?";
}
function corePinned() {
  const clone = cloneDir();
  try {
    const m = JSON.parse(fs.readFileSync(path.join(clone, "manifest.json"), "utf8"));
    return { pkg: m.core && m.core.package, pinned: m.core && m.core.pinned };
  } catch { return { pkg: "@deepseek-ai/dsh", pinned: "" }; }
}
function coreLatest(force, cb) {
  let cached = null;
  try { cached = JSON.parse(fs.readFileSync(CORE_CHECK_CACHE, "utf8")); } catch { /* sem cache */ }
  const fresh = cached && cached.latest && (Date.now() - (cached.at || 0)) < 60 * 60 * 1000;
  if (fresh && !force) { cb(cached.latest, cached.at); return; }
  execFile("npm", ["view", "@deepseek-ai/dsh", "version"], { timeout: 25000 }, (err, stdout) => {
    const latest = err ? "" : String(stdout || "").trim().split("\n").pop() || "";
    if (latest) {
      try { fs.writeFileSync(CORE_CHECK_CACHE, JSON.stringify({ latest, at: Date.now() })); } catch { /* ok */ }
    } else if (cached && cached.latest) { cb(cached.latest, cached.at); return; }
    cb(latest, latest ? Date.now() : 0);
  });
}
function corePatchesOk(installed) {
  // marcador deixado pelo apply-pt-core.sh junto aos pacotes do core
  const roots = [
    "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules",
    "/usr/lib/node_modules/@deepseek-ai/dsh/node_modules",
  ];
  for (const r of roots) {
    try {
      const marker = fs.readFileSync(path.join(r, ".dsh-core-pt-applied"), "utf8");
      if (marker.includes("core=" + installed)) return { ok: true, note: "pt-BR aplicado" };
    } catch { /* sem marcador */ }
  }
  return { ok: false, note: "sem pt-BR (reaplicar: apply-pt-core.sh --force)" };
}
function coreHistory() {
  try {
    const h = JSON.parse(fs.readFileSync(CORE_HISTORY, "utf8"));
    return Array.isArray(h) ? h.slice(0, 5) : [];
  } catch { return []; }
}
function sudoersOk(cb) {
  execFile("sudo", ["-n", "-l"], { timeout: 8000 }, (err) => cb(!err));
}
function coreStatus(forceCheck, cb) {
  const installed = coreInstalledVersion();
  const pinned = corePinned();
  const patches = corePatchesOk(installed);
  coreLatest(forceCheck, (latest, at) => {
    cb({
      ok: true,
      installed,
      package: pinned.pkg,
      pinned: pinned.pinned,
      latest: latest || "?",
      hasUpdate: !!(latest && latest !== installed),
      checkedAt: at || Date.now(),
      patches,
      history: coreHistory(),
    });
  });
}
// executa a ação do core e, em caso de sucesso, agenda o reinício da GUI
function runCoreAction(action, version, json, res) {
  coreAction(action, version, (r) => {
    json(r.ok ? 200 : 500, r, res);
    if (r.ok) scheduleRestart(2600);
  });
}
function coreAction(action, version, cb) {  const tool = path.join(cloneDir(), "core-i18n-pt", "tools", "core-update.sh");
  if (!fs.existsSync(tool)) { cb({ ok: false, error: "core-update.sh não encontrado no repo" }); return; }
  if (!/^[0-9A-Za-z._-]+$/.test(String(version || ""))) { cb({ ok: false, error: "versão inválida" }); return; }
  const args = ["-n", tool, "--live", __dirname, action === "rollback" ? "--rollback" : "--install", version];
  execFile("sudo", args, { timeout: 300000, maxBuffer: 16 * 1024 * 1024 }, (err, stdout, stderr) => {
    const output = String(stdout || "") + (stderr ? "\n" + stderr : "");
    if (err) {
      cb({ ok: false, error: "falha (sudo?)", needSudo: true, output });
      return;
    }
    cb({ ok: true, output });
  });
}

const CORE_UI_JS = [
  "(function () {",
  "  if (document.getElementById('dsh-core-badge')) return;",
  "  var s2 = document.createElement('style');",
  "  s2.textContent = [",
  "    '#dsh-core-badge{position:fixed;right:16px;bottom:34px;z-index:2147483646;display:inline-flex;align-items:center;gap:6px;background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:2px 10px;font:10px/1.6 system-ui,sans-serif;color:#8b949e;cursor:pointer;box-shadow:0 2px 10px rgba(0,0,0,.4);}',",
  "    '#dsh-core-badge .cb-new{color:#f0883e;font-weight:600;}',",
  "    '#dsh-core-badge .cb-old{color:#3fb950;}',",
  "    '#dsh-core-panel{position:fixed;right:16px;bottom:74px;z-index:2147483647;width:340px;max-width:calc(100vw - 24px);background:#0d1117;border:1px solid #30363d;border-radius:10px;padding:10px 12px;font:11px/1.5 system-ui,sans-serif;color:#e6edf3;box-shadow:0 8px 30px rgba(0,0,0,.6);}',",
  "    '#dsh-core-panel h4{margin:0 0 6px;font-size:11px;color:#f0883e;}',",
  "    '#dsh-core-panel .cb-row{display:flex;justify-content:space-between;gap:8px;padding:3px 0;border-top:1px solid #21262d;}',",
  "    '#dsh-core-panel .cb-row:first-of-type{border-top:0;}',",
  "    '#dsh-core-panel button{margin:4px 6px 4px 0;padding:3px 10px;border:0;border-radius:999px;background:#21262d;color:#e6edf3;font:10.5px/1.4 system-ui,sans-serif;cursor:pointer;}',",
  "    '#dsh-core-panel button:hover{background:#30363d;}',",
  "    '#dsh-core-panel .cb-warn{color:#f85149;}',",
  "    '#dsh-core-panel .cb-note{color:#8b949e;font-size:10px;white-space:pre-wrap;max-height:150px;overflow:auto;}'",
  "  ].join('\\n');",
  "  document.head.appendChild(s2);",
  "  var chip = document.createElement('div');",
  "  chip.id = 'dsh-core-badge';",
  "  chip.title = 'Núcleo do DeepSeek Harness — clique para ver/atualizar';",
  "  document.body.appendChild(chip);",
  "  var panel = document.createElement('div');",
  "  panel.id = 'dsh-core-panel';",
  "  panel.style.display = 'none';",
  "  document.body.appendChild(panel);",
  "  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>\"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '\"': '&quot;', \"'\": '&#39;' }[c]; }); };",
  "  var refresh = function () {",
  "    fetch('/api/dsh-core', { method: 'GET' }).then(function (r) { return r.json(); }).then(function (d) {",
  "      if (!d || !d.ok) return;",
  "      var label = 'core ' + esc(d.installed);",
  "      var cls = '';",
  "      if (d.hasUpdate) { label += ' · nova ' + esc(d.latest); cls = 'cb-new'; }",
  "      else if (!d.patches.ok) { label += ' · sem pt'; cls = 'cb-warn'; }",
  "      chip.innerHTML = '<span class=\"' + (cls || 'cb-old') + '\">' + label + '</span>';",
  "      panel.dataset.status = JSON.stringify(d);",
  "    }).catch(function () {});",
  "  };",
  "  var act = function (action, version, label) {",
  "    if (!window.confirm('Núcleo (' + action + '): ' + label + '?\\n\\nNada é automático — você confirma a operação. O harness será reiniciado ao final.')) return;",
  "    panel.innerHTML = '<h4>Núcleo</h4><div class=\"cb-note\">' + (action === 'rollback' ? 'Revertendo' : 'Atualizando') + ' o core para ' + esc(label) + '… (pode levar alguns minutos; ao final a GUI reinicia).</div>';",
  "    fetch('/api/dsh-core', {",
  "      method: 'POST',",
  "      headers: { 'content-type': 'application/json' },",
  "      body: JSON.stringify({ action: action, version: version })",
  "    }).then(function (r) { return r.json(); }).then(function (res) {",
  "      if (!res.ok) {",
  "        panel.innerHTML = '<h4>Núcleo</h4><div class=\"cb-warn\">' + esc(res.error || 'falhou') + '</div><div class=\"cb-note\">' + esc(res.output || (res.needSudo ? 'Rode no terminal: sudo core-i18n-pt/tools/core-update.sh' : '')) + '</div>';",
  "        return;",
  "      }",
  "      panel.innerHTML = '<h4>Núcleo</h4><div class=\"cb-note\">' + esc(res.output || 'ok') + '</div><div class=\"cb-note\">Reiniciando a GUI… recarregue a página (F5) se necessário.</div>';",
  "      refresh();",
  "    }).catch(function () {",
  "      panel.innerHTML = '<h4>Núcleo</h4><div class=\"cb-note\">Reiniciando… recarregue a página (F5).</div>';",
  "    });",
  "  };",
  "  var open = function () {",
  "    if (panel.style.display !== 'none') { panel.style.display = 'none'; return; }",
  "    panel.style.display = 'block';",
  "    panel.innerHTML = '<h4>Núcleo (kernel)</h4><div class=\"cb-note\">Carregando…</div>';",
  "    fetch('/api/dsh-core', { method: 'GET' }).then(function (r) { return r.json(); }).then(function (d) {",
  "      var h = ['<h4>Núcleo do DeepSeek Harness</h4>'];",
  "      h.push('<div class=\"cb-note\">Atualização sempre MANUAL (nada automático) — semelhante a um kernel. A checagem de versão nova é automática.</div>');",
  "      h.push('<div class=\"cb-row\"><span>Instalado</span><b>' + esc(d.installed) + '</b></div>');",
  "      h.push('<div class=\"cb-row\"><span>Pinado no repo</span><b>' + esc(d.pinned || '—') + '</b></div>');",
  "      h.push('<div class=\"cb-row\"><span>Disponível</span><b>' + esc(d.latest) + (d.hasUpdate ? ' ⚠' : '') + '</b></div>');",
  "      h.push('<div class=\"cb-row\"><span>pt-BR (patch)</span><b>' + (d.patches && d.patches.ok ? 'aplicado' : '<span class=\"cb-warn\">pendente</span>') + '</b></div>');",
  "      if (d.hasUpdate) {",
  "        h.push('<div><button data-a=\"update\" data-v=\"' + esc(d.latest) + '\" data-l=\"' + esc(d.latest) + '\">Atualizar para ' + esc(d.latest) + '</button></div>');",
  "      }",
  "      var rb = (d.pinned && d.pinned !== d.installed) ? d.pinned : ((d.history && d.history[0] && d.history[0].from) || '');",
  "      if (rb && rb !== d.installed) {",
  "        h.push('<div><button data-a=\"rollback\" data-v=\"' + esc(rb) + '\" data-l=\"' + esc(rb) + '\">↩ Voltar p/ ' + esc(rb) + '</button><span class=\"cb-note\"> (última que funcionava)</span></div>');",
  "      }",
  "      if (d.history && d.history.length) {",
  "        h.push('<div class=\"cb-note\">Histórico: ' + d.history.map(function (x) { return x.version + (x.patchesOk ? '' : ' (sem pt)'); }).join(' → ') + '</div>');",
  "      }",
  "      panel.innerHTML = h.join('');",
  "      Array.prototype.forEach.call(panel.querySelectorAll('button[data-a]'), function (b) {",
  "        b.addEventListener('click', function () { act(b.getAttribute('data-a'), b.getAttribute('data-v'), b.getAttribute('data-l')); });",
  "      });",
  "    }).catch(function () { panel.innerHTML = '<h4>Núcleo</h4><div class=\"cb-warn\">Falha ao consultar o core.</div>'; });",
  "  };",
  "  chip.addEventListener('click', open);",
  "  refresh();",
  "  setInterval(refresh, 120000);",
  "})();",
].join("\n");

const BADGE_JS = [
  "(function () {",
  "  if (document.getElementById('dsh-version-badge')) return;",
  "  var css = document.createElement('style');",
  "  css.textContent = [",
  "    '#dsh-version-badge{position:fixed;right:16px;bottom:8px;z-index:2147483646;display:inline-flex;align-items:center;gap:8px;background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:2px 6px 2px 10px;font:10.5px/1.6 system-ui,sans-serif;white-space:nowrap;box-shadow:0 2px 10px rgba(0,0,0,.4);}',",
  "    '#dsh-version-badge .v-ver{color:#79c0ff;font-weight:600;cursor:pointer;}',",
  "    '#dsh-version-badge .v-upd{color:#8b949e;}',",
  "    '#dsh-version-badge button{margin:0;padding:2px 8px;border:0;border-radius:999px;background:#21262d;color:#8b949e;font:10px/1.4 system-ui,sans-serif;cursor:pointer;}',",
  "    '#dsh-version-badge button:hover{background:#30363d;color:#e6edf3;}',",
  "    '#dsh-version-badge .v-toggle.on{color:#3fb950;}',",
  "    '#dsh-version-badge .v-toggle.off{color:#f85149;}',",
  "    '#dsh-version-badge .v-rollback{color:#d29922;}',",
  "    '#dsh-rollback-panel{position:fixed;right:16px;bottom:44px;z-index:2147483647;width:320px;max-width:calc(100vw - 24px);max-height:60vh;overflow:auto;background:#0d1117;border:1px solid #30363d;border-radius:10px;padding:10px 12px;font:11px/1.5 system-ui,sans-serif;color:#e6edf3;box-shadow:0 8px 30px rgba(0,0,0,.6);}',",
  "    '#dsh-rollback-panel h4{margin:0 0 6px;font-size:11px;color:#79c0ff;}',",
  "    '#dsh-rollback-panel .rb-row{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:4px 2px;border-top:1px solid #21262d;}',",
  "    '#dsh-rollback-panel .rb-row:first-of-type{border-top:0;}',",
  "    '#dsh-rollback-panel .rb-name{font-weight:600;color:#e6edf3;}',",
  "    '#dsh-rollback-panel .rb-date{color:#8b949e;font-size:10px;}',",
  "    '#dsh-rollback-panel .rb-cur{color:#3fb950;font-size:10px;}',",
  "    '#dsh-rollback-panel .rb-btn{flex:0 0 auto;}',",
  "    '#dsh-rollback-panel .rb-note{color:#8b949e;margin-top:8px;padding-top:6px;border-top:1px solid #21262d;font-size:10px;}',",
  "    '#dsh-rollback-panel .rb-err{color:#f85149;white-space:pre-wrap;}',",
  "    '#dsh-rollback-panel .rb-ok{color:#3fb950;white-space:pre-wrap;max-height:120px;overflow:auto;}'",
  "  ].join('\\n');",
  "  document.head.appendChild(css);",
  "",
  "  var b = document.createElement('div');",
  "  b.id = 'dsh-version-badge';",
  "  document.body.appendChild(b);",
  "  var panel = document.createElement('div');",
  "  panel.id = 'dsh-rollback-panel';",
  "  panel.style.display = 'none';",
  "  document.body.appendChild(panel);",
  "",
  "  var state = { autoUpdate: true };",
  "  var esc = function (s) {",
  "    return String(s == null ? '' : s).replace(/[&<>\"']/g, function (c) {",
  "      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '\"': '&quot;', \"'\": '&#39;' }[c];",
  "    });",
  "  };",
  "  var verLabel = function (v) {",
  "    v = String(v == null ? '?' : v);",
  "    return (v.charAt(0) === 'v' || v.charAt(0) === 'V') ? v : 'v' + v;",
  "  };",
  "  var ask = function (msg) { try { return window.confirm(msg); } catch (e) { return true; } };",
  "",
  "  var doRollback = function (target, label) {",
  "    if (!ask('Voltar para ' + label + '?\\n\\n• O estado atual será salvo num snapshot antes\\n• O auto-update será DESLIGADO (para não reaplicar a versão que quebrou)\\n• O harness será reiniciado\\n\\nContinuar?')) return;",
  "    panel.innerHTML = '<h4>↩ Rollback</h4><div class=\"rb-note\">Voltando para <b>' + esc(label) + '</b>… snapshot + restauração podem levar alguns segundos.</div>';",
  "    fetch('/api/dsh-rollback', {",
  "      method: 'POST',",
  "      headers: { 'content-type': 'application/json' },",
  "      body: JSON.stringify({ target: target })",
  "    }).then(function (r) { return r.json(); }).then(function (res) {",
  "      if (!res.ok) {",
  "        panel.innerHTML = '<h4>↩ Rollback</h4><div class=\"rb-err\">' + esc(res.error || 'falhou') + '</div><div class=\"rb-note\">Veja o terminal/log para detalhes.</div>';",
  "        return;",
  "      }",
  "      panel.innerHTML = '<h4>↩ Rollback</h4><div class=\"rb-ok\">' + esc(res.output || '') + '</div><div class=\"rb-note\"><b>Auto-update DESLIGADO.</b> Reiniciando o harness… a página vai recarregar; se não recarregar sozinha, atualize (F5).</div>';",
  "    }).catch(function () {",
  "      // servidor reiniciou no meio — sinal de sucesso",
  "      panel.innerHTML = '<h4>↩ Rollback</h4><div class=\"rb-note\">Reiniciando o harness… recarregue a página (F5) para ver a versão anterior.</div>';",
  "    });",
  "  };",
  "",
  "  var openRollback = function () {",
  "    if (panel.style.display !== 'none') { panel.style.display = 'none'; return; }",
  "    panel.style.display = 'block';",
  "    panel.innerHTML = '<h4>↩ Rollback de versão</h4><div class=\"rb-note\">Carregando…</div>';",
  "    fetch('/api/dsh-rollback', { method: 'GET' }).then(function (r) { return r.json(); }).then(function (d) {",
  "      var html = ['<h4>↩ Rollback de versão</h4>'];",
  "      html.push('<div class=\"rb-row\"><span class=\"rb-name\">Atual: ' + esc(d.current.version) + '</span><span class=\"rb-cur\">instalado</span></div>');",
  "      if (d.previous) {",
  "        html.push('<div class=\"rb-row\"><span><span class=\"rb-name\">' + esc(d.previous) + '</span> <span class=\"rb-date\">(anterior)</span></span><span class=\"rb-btn\"><button class=\"rb-voltar\" data-t=\"' + esc(d.previous) + '\" data-l=\"' + esc(d.previous) + '\">↩ Voltar</button></span></div>');",
  "      } else {",
  "        html.push('<div class=\"rb-note\">Sem versão anterior publicada (a atual é a mais antiga ou não tem tag). Use um snapshot abaixo, ou no terminal: tools/rollback.sh list</div>');",
  "      }",
  "      var tagRows = (d.tags || []).filter(function (t) { return t.name !== d.previous && t.name !== d.current.version; }).map(function (t) {",
  "        return '<div class=\"rb-row\"><span><span class=\"rb-name\">' + esc(t.name) + '</span> <span class=\"rb-date\">' + esc(t.date || '') + '</span></span><span class=\"rb-btn\"><button data-t=\"' + esc(t.name) + '\" data-l=\"' + esc(t.name) + '\">↩ Voltar</button></span></div>';",
  "      });",
  "      if (tagRows.length) {",
  "        html.push('<div class=\"rb-note\" style=\"margin-top:6px;\">Versões publicadas (tags):</div>');",
  "        html.push.apply(html, tagRows);",
  "      }",
  "      if (d.snapshots && d.snapshots.length) {",
  "        html.push('<div class=\"rb-note\" style=\"margin-top:6px;\">Snapshots locais (estado exato desta máquina):</div>');",
  "        d.snapshots.forEach(function (s) {",
  "          html.push('<div class=\"rb-row\"><span class=\"rb-name\" style=\"font-weight:400;\">' + esc(s) + '</span><span class=\"rb-btn\"><button data-t=\"' + esc(s) + '\" data-l=\"' + esc(s) + '\">↩ Voltar</button></span></div>');",
  "        });",
  "      }",
  "      html.push('<div class=\"rb-note\">Ao voltar: o auto-update é desligado e o harness reinicia. Para religar depois de testar, clique em 🔄 auto: OFF.</div>');",
  "      panel.innerHTML = html.join('');",
  "      Array.prototype.forEach.call(panel.querySelectorAll('button[data-t]'), function (btn) {",
  "        btn.addEventListener('click', function () { doRollback(btn.getAttribute('data-t'), btn.getAttribute('data-l')); });",
  "      });",
  "    }).catch(function () {",
  "      panel.innerHTML = '<h4>↩ Rollback</h4><div class=\"rb-err\">Não foi possível listar versões.</div>';",
  "    });",
  "  };",
  "",
  "  var refresh = function () {",
  "    fetch('/api/dsh-version', { method: 'GET' }).then(function (r) { return r.json(); }).then(function (d) {",
  "      state = d || state;",
  "      var upd = '';",
  "      try { if (d.updatedAt) upd = new Date(d.updatedAt).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); } catch (e) {}",
  "      b.title = 'overlay ' + verLabel(d.version) + (d.commit ? ' (' + d.commit + ')' : '') + ' · atualizado ' + (d.updatedAt || '?') + '\\nClique na versão para abrir o rollback.';",
  "      var btn = document.createElement('button');",
  "      btn.className = 'v-toggle ' + (d.autoUpdate ? 'on' : 'off');",
  "      btn.type = 'button';",
  "      btn.title = 'Atualização automática (sync + reinício quando houver versão nova). Clique para ' + (d.autoUpdate ? 'DESLIGAR' : 'LIGAR');",
  "      btn.textContent = '🔄 ' + (d.autoUpdate ? 'auto: ON' : 'auto: OFF');",
  "      btn.onclick = function (ev) {",
  "        ev.stopPropagation();",
  "        fetch('/api/dsh-version', {",
  "          method: 'POST',",
  "          headers: { 'content-type': 'application/json' },",
  "          body: JSON.stringify({ autoUpdate: !d.autoUpdate })",
  "        }).then(function (r) { return r.json(); }).then(function (res) {",
  "          state.autoUpdate = res.autoUpdate;",
  "          refresh();",
  "        }).catch(function () {});",
  "      };",
  "      var rb = document.createElement('button');",
  "      rb.className = 'v-rollback';",
  "      rb.type = 'button';",
  "      rb.title = 'Rollback de versão — voltar se uma atualização quebrou o sistema';",
  "      rb.textContent = '↩';",
  "      rb.onclick = function (ev) { ev.stopPropagation(); openRollback(); };",
  "      b.innerHTML = '';",
  "      var span = document.createElement('span');",
  "      span.className = 'v-ver';",
  "      span.title = b.title;",
  "      span.textContent = verLabel(d.version);",
  "      span.onclick = function () { openRollback(); };",
  "      b.appendChild(span);",
  "      if (upd) { var u = document.createElement('span'); u.className = 'v-upd'; u.textContent = '· ' + upd; b.appendChild(u); }",
  "      b.appendChild(btn);",
  "      b.appendChild(rb);",
  "    }).catch(function () {",
  "      b.innerHTML = '<span class=\"v-ver\">v?</span>';",
  "    });",
  "  };",
  "  refresh();",
  "  setInterval(refresh, 60000);",
  "})();",
].join("\n");

module.exports = function versionBadgePlugin(ctx) {
  // O host webserver pode ativar DEPOIS do apply deste plugin — espera ficar
  // disponível antes de registrar (mesmo padrão do LayoutPanel).
  let tries = 0;
  const waitForWebServer = () => {
    const webServer = ctx.get("webServer");
    if (webServer) {
      ctx.effect(() => {
        const json = (code, obj, res) => {
          res.writeHead(code, { "content-type": "application/json; charset=utf-8" });
          res.end(JSON.stringify(obj));
        };
        const readBody = (req, done) => {
          let body = "";
          req.on("data", (c) => { body += c; });
          req.on("end", () => done(body));
        };
        const registerVersion = webServer.register({
          kind: "exact",
          path: "/api/dsh-version",
          handler: (req, res) => {
            if (req.method === "GET") { json(200, versionPayload(), res); return; }
            if (req.method === "POST") {
              readBody(req, (body) => {
                let enable = null;
                try { enable = JSON.parse(body || "{}").autoUpdate; } catch { /* inválido */ }
                if (typeof enable !== "boolean") { json(400, { ok: false, error: "autoUpdate deve ser boolean" }, res); return; }
                json(200, setAutoUpdate(enable), res);
              });
              return;
            }
            json(405, { ok: false, error: "método não suportado" }, res);
          },
        });
        const registerRollback = webServer.register({
          kind: "exact",
          path: "/api/dsh-rollback",
          handler: (req, res) => {
            if (req.method === "GET") {
              rollbackList((payload) => json(200, payload, res));
              return;
            }
            if (req.method === "POST") {
              readBody(req, (body) => {
                let target = "";
                try { target = String(JSON.parse(body || "{}").target || "").trim(); } catch { /* inválido */ }
                if (!/^[A-Za-z0-9._-]+$/.test(target)) {
                  json(400, { ok: false, error: "target inválido (ex.: v0.2.0 ou snap-20260906-...) — use o painel ou tools/rollback.sh" }, res);
                  return;
                }
                doRollback(target, (result) => {
                  json(result.ok ? 200 : 500, result, res);
                  if (result.ok) scheduleRestart(1800);
                });
              });
              return;
            }
            json(405, { ok: false, error: "método não suportado" }, res);
          },
        });
        const registerCore = webServer.register({
          kind: "exact",
          path: "/api/dsh-core",
          handler: (req, res) => {
            if (req.method === "GET") {
              const force = /[?&]force=1/.test(req.url || "");
              coreStatus(!!force, (payload) => json(200, payload, res));
              return;
            }
            if (req.method === "POST") {
              readBody(req, (body) => {
                let action = "", version = "";
                try { const p = JSON.parse(body || "{}"); action = String(p.action || ""); version = String(p.version || ""); } catch { /* inválido */ }
                if (action !== "update" && action !== "rollback") {
                  json(400, { ok: false, error: "action deve ser update|rollback" }, res);
                  return;
                }
                if (!version) {
                  if (action === "update") {
                    coreStatus(false, (st) => { if (st.latest && st.latest !== "?") { runCoreAction(action, st.latest, json, res); } else json(400, { ok: false, error: "sem versão nova conhecida" }, res); });
                    return;
                  }
                  json(400, { ok: false, error: "informe a versão p/ rollback" }, res);
                  return;
                }
                runCoreAction(action, version, json, res);
              });
              return;
            }
            json(405, { ok: false, error: "método não suportado" }, res);
          },
        });
        const disposeAll = () => {
          try { if (typeof registerVersion === "function") registerVersion(); } catch { /* já removido */ }
          try { if (typeof registerRollback === "function") registerRollback(); } catch { /* já removido */ }
          try { if (typeof registerCore === "function") registerCore(); } catch { /* já removido */ }
        };
        console.log("[VersionBadge] rotas /api/dsh-version, /api/dsh-rollback e /api/dsh-core registradas (GET + POST)");
        return disposeAll;
      }, "version-badge: api");
      return;
    }
    if (++tries > 60) {
      console.log("[VersionBadge] webServer não ficou disponível — rotas não registradas");
      return;
    }
    setTimeout(waitForWebServer, 250);
  };
  waitForWebServer();

  ctx.on("webserver/index-inject", (table) => {
    table.push({ kind: "script", placement: "body", text: BADGE_JS });
    table.push({ kind: "script", placement: "body", text: CORE_UI_JS });
  });

  console.log("[VersionBadge] badge de versão + chave de auto-update + rollback ativos");
};

module.exports.default = module.exports;
