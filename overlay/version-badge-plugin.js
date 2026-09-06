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
  "      b.title = 'overlay v' + (d.version || '?') + (d.commit ? ' (' + d.commit + ')' : '') + ' · atualizado ' + (d.updatedAt || '?') + '\\nClique na versão para abrir o rollback.';",
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
  "      span.textContent = 'v' + (d.version || '?');",
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
        const disposeAll = () => {
          try { if (typeof registerVersion === "function") registerVersion(); } catch { /* já removido */ }
          try { if (typeof registerRollback === "function") registerRollback(); } catch { /* já removido */ }
        };
        console.log("[VersionBadge] rotas /api/dsh-version e /api/dsh-rollback registradas (GET + POST)");
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
  });

  console.log("[VersionBadge] badge de versão + chave de auto-update + rollback ativos");
};

module.exports.default = module.exports;
