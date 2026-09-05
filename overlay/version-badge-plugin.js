/**
 * Version Badge — badge de versão + chave de auto-atualização no painel direito.
 *
 * Server-side (via ctx.get("webServer")):
 *   GET  /api/dsh-version → { ok, version, commit, updatedAt, autoUpdate }
 *     .dsh-version.json  é GERADO pelo sync (tools/stamp-version.sh/.ps1).
 *     autoUpdate = true quando NÃO existe <config viva>/.dsh-autoupdate.off.
 *   POST /api/dsh-version {"autoUpdate": bool} → cria/remove o flag
 *     .dsh-autoupdate.off (o agendador local de auto-update consulta esse
 *     flag antes de sincronizar). Arquivo é LOCAL da máquina.
 *
 * Client-side: badge "v<versão> · <atualizado>" + botão "🔄 auto" (ON/OFF),
 * recolhidos pelo LayoutPanel para a coluna direita (.dlp-badges).
 *
 * Localização dos arquivos: mesmo diretório deste plugin (= config viva).
 */
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const VERSION_FILE = path.join(__dirname, ".dsh-version.json");
const AUTO_UPDATE_OFF = path.join(__dirname, ".dsh-autoupdate.off");

function autoUpdateEnabled() {
  return !fs.existsSync(AUTO_UPDATE_OFF);
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

const BADGE_JS = `
(function () {
  if (document.getElementById("dsh-version-badge")) return;
  var css = document.createElement("style");
  css.textContent = [
    "#dsh-version-badge{position:fixed;right:16px;bottom:8px;z-index:2147483646;display:inline-flex;align-items:center;gap:8px;background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:2px 6px 2px 10px;font:10.5px/1.6 system-ui,sans-serif;white-space:nowrap;}",
    "#dsh-version-badge .v-ver{color:#79c0ff;font-weight:600;}",
    "#dsh-version-badge .v-upd{color:#8b949e;}",
    "#dsh-version-badge .v-toggle{margin:0;padding:2px 8px;border:0;border-radius:999px;background:#21262d;color:#8b949e;font:10px/1.4 system-ui,sans-serif;cursor:pointer;}",
    "#dsh-version-badge .v-toggle:hover{background:#30363d;color:#e6edf3;}",
    "#dsh-version-badge .v-toggle.on{color:#3fb950;}",
    "#dsh-version-badge .v-toggle.off{color:#f85149;}"
  ].join("\\n");
  document.head.appendChild(css);

  var b = document.createElement("div");
  b.id = "dsh-version-badge";
  b.title = "Versão do overlay instalado neste harness";
  document.body.appendChild(b);

  var state = { autoUpdate: true };
  var refresh = function () {
    fetch("/api/dsh-version", { method: "GET" }).then(function (r) { return r.json(); }).then(function (d) {
      state = d || state;
      var upd = "";
      try { if (d.updatedAt) upd = new Date(d.updatedAt).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) {}
      b.title = "overlay v" + (d.version || "?") + (d.commit ? " (" + d.commit + ")" : "") + " · atualizado " + (d.updatedAt || "?");
      var btn = document.createElement("button");
      btn.className = "v-toggle " + (d.autoUpdate ? "on" : "off");
      btn.type = "button";
      btn.title = "Atualização automática (sync + reinício quando houver versão nova). Clique para " + (d.autoUpdate ? "DESLIGAR" : "LIGAR");
      btn.textContent = "🔄 " + (d.autoUpdate ? "auto: ON" : "auto: OFF");
      btn.onclick = function (ev) {
        ev.stopPropagation();
        fetch("/api/dsh-version", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ autoUpdate: !d.autoUpdate })
        }).then(function (r) { return r.json(); }).then(function (res) {
          state.autoUpdate = res.autoUpdate;
          refresh();
        }).catch(function () {});
      };
      b.innerHTML = "";
      var span = document.createElement("span");
      span.className = "v-ver";
      span.textContent = "v" + (d.version || "?");
      b.appendChild(span);
      if (upd) { var u = document.createElement("span"); u.className = "v-upd"; u.textContent = "· " + upd; b.appendChild(u); }
      b.appendChild(btn);
    }).catch(function () {
      b.innerHTML = "<span class='v-ver'>v?</span>";
    });
  };
  refresh();
  setInterval(refresh, 60000);
})();
`;

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
        const dispose = webServer.register({
          kind: "exact",
          path: "/api/dsh-version",
          handler: (req, res) => {
            if (req.method === "GET") { json(200, versionPayload(), res); return; }
            if (req.method === "POST") {
              let body = "";
              req.on("data", (c) => { body += c; });
              req.on("end", () => {
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
        console.log("[VersionBadge] rota /api/dsh-version registrada (GET + POST)");
        return dispose;
      }, "version-badge: api");
      return;
    }
    if (++tries > 60) {
      console.log("[VersionBadge] webServer não ficou disponível — rota não registrada");
      return;
    }
    setTimeout(waitForWebServer, 250);
  };
  waitForWebServer();

  ctx.on("webserver/index-inject", (table) => {
    table.push({ kind: "script", placement: "body", text: BADGE_JS });
  });

  console.log("[VersionBadge] badge de versão + chave de auto-update ativos");
};

module.exports.default = module.exports;
