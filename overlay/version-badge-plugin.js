/**
 * Version Badge — badge de versão no painel lateral direito.
 *
 * Server-side: registra GET /api/dsh-version (via ctx.get("webServer")),
 * devolvendo o conteúdo de .dsh-version.json — arquivo GERADO pelo sync
 * (tools/stamp-version.sh/.ps1) em cada máquina com a versão do repo e o
 * instante da última atualização. Se o arquivo não existir, responde com o
 * estado "local".
 *
 * Client-side: injeta um badge fixo (recolhido pelo LayoutPanel para dentro
 * da coluna direita, .dlp-badges) mostrando "v<versão> · <atualizado em>".
 *
 * Localização do arquivo: mesmo diretório deste plugin (= config viva do
 * harness, ex.: ~/.dsh ou ~/.dsh-v2).
 */
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const VERSION_FILE = path.join(__dirname, ".dsh-version.json");

function versionPayload() {
  try {
    const raw = fs.readFileSync(VERSION_FILE, "utf8");
    const data = JSON.parse(raw);
    return {
      ok: true,
      version: String(data.version ?? "?"),
      commit: String(data.commit ?? ""),
      updatedAt: String(data.updatedAt ?? ""),
    };
  } catch {
    return { ok: false, version: "local", commit: "", updatedAt: "" };
  }
}

const BADGE_JS = `
(function () {
  if (document.getElementById("dsh-version-badge")) return;
  var css = document.createElement("style");
  css.textContent = [
    "#dsh-version-badge{position:fixed;right:16px;bottom:8px;z-index:2147483646;display:inline-flex;align-items:center;gap:6px;background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:2px 10px;font:10.5px/1.6 system-ui,sans-serif;color:#8b949e;white-space:nowrap;cursor:default;}",
    "#dsh-version-badge .v-ver{color:#79c0ff;font-weight:600;}",
    "#dsh-version-badge .v-upd{color:#8b949e;}"
  ].join("\\n");
  document.head.appendChild(css);
  var b = document.createElement("div");
  b.id = "dsh-version-badge";
  b.title = "Versão do overlay instalado neste harness";
  document.body.appendChild(b);
  var refresh = function () {
    fetch("/api/dsh-version", { method: "GET" }).then(function (r) { return r.json(); }).then(function (d) {
      var upd = "";
      try { if (d.updatedAt) upd = new Date(d.updatedAt).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) {}
      var ver = d.version || "?";
      b.title = "overlay v" + ver + (d.commit ? " (" + d.commit + ")" : "") + " · atualizado " + (d.updatedAt || "?");
      b.innerHTML = "<span class='v-ver'>v" + ver + "</span>" + (upd ? "<span class='v-upd'>· " + upd + "</span>" : "");
    }).catch(function () {
      b.innerHTML = "<span class='v-ver'>v?</span>";
    });
  };
  refresh();
  setInterval(refresh, 60000);
})();
`;

module.exports = function versionBadgePlugin(ctx) {
  const webServer = ctx.get("webServer");
  if (webServer) {
    ctx.effect(() => {
      const dispose = webServer.register({
        kind: "exact",
        path: "/api/dsh-version",
        handler: (_req, res) => {
          res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
          res.end(JSON.stringify(versionPayload()));
        },
      });
      console.log("[VersionBadge] rota /api/dsh-version registrada");
      return dispose;
    }, "version-badge: api");
  } else {
    console.log("[VersionBadge] webServer indisponível — rota não registrada");
  }

  ctx.on("webserver/index-inject", (table) => {
    table.push({ kind: "script", placement: "body", text: BADGE_JS });
  });

  console.log("[VersionBadge] badge de versão ativo");
};

module.exports.default = module.exports;
