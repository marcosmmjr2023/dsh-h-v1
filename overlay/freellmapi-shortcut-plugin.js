/**
 * FreeLLMAPI Shortcut — badge no dashboard do DeepSeek Harness
 *
 * Injeta um badge "FreeLLMAPI" FIXO no canto inferior direito da janela,
 * empilhado ACIMA dos botões flutuantes existentes ("⚡ Roteador" em 16px e
 * "Modelos" em 60px) — em 108px, para não ficar atrás deles. Clicar abre o
 * painel do FreeLLMAPI (http://127.0.0.1:3002) DENTRO do próprio dashboard,
 * numa janela modal com iframe — sem abrir nova aba. Ali é possível adicionar
 * as chaves dos provedores gratuitos (Groq, Cerebras, Mistral, Google, ...).
 *
 * Um pontinho no badge indica a saúde do gateway (verde = online,
 * amarelo = checando, vermelho = offline). Ao lado do nome, o badge mostra o
 * MODELO REAL que respondeu a última requisição com sucesso (ex.:
 * "FreeLLMAPI · mistral/ministral-14b-latest") — consultado a cada 3s em
 * GET /api/last-request. Quando houve failover (o pedido era para um modelo,
 * mas outro respondeu), mostra "⇄ modelo" e o tooltip detalha o que foi
 * pedido. Feche o modal com ✕, clique fora ou Esc.
 */

"use strict";

// Gateway dinâmico: dentro de uma instância (DSH_ENV_NAME) usa o gateway dela; senão o global 3002
function dshEnvFlmUrl() {
  const env = process.env.DSH_ENV_NAME;
  if (env) {
    try {
      const fs = require("node:fs");
      const m = JSON.parse(fs.readFileSync(process.env.HOME + "/.dsh-envs/" + env + "/meta.json", "utf8"));
      if (m && m.freellmapiPort) return "http://127.0.0.1:" + m.freellmapiPort;
    } catch (e) { /* segue global */ }
  }
  return "http://127.0.0.1:3002";
}
const FREELMAPI_DASHBOARD_URL = dshEnvFlmUrl();

const INJECT = `(function () {
  "use strict";
  var URL = ${JSON.stringify(FREELMAPI_DASHBOARD_URL)};
  var css = [
    "#freellmapi-badge{position:fixed;right:16px;top:16px;z-index:2147483647;display:inline-flex;align-items:center;gap:6px;max-width:min(260px,calc(100vw - 32px));background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:3px 11px 3px 9px;font:11px/1.7 system-ui,sans-serif;color:#9ecbff;text-decoration:none;box-shadow:0 2px 10px rgba(0,0,0,.5);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:pointer;letter-spacing:.01em;}",
    "#freellmapi-badge:hover{border-color:#238636;color:#c9e6ff;}",
    "#freellmapi-badge .fl-dot{width:7px;height:7px;border-radius:50%;background:#d29922;flex:none;}",
    "#freellmapi-badge .fl-dot.ok{background:#3fb950;}",
    "#freellmapi-badge .fl-dot.bad{background:#f85149;}",
    "#freellmapi-badge .fl-model{max-width:230px;overflow:hidden;text-overflow:ellipsis;color:#7ee787;font-weight:600;}",
    "#freellmapi-badge .fl-model.fail{color:#ffa657;}",
  ].join("");
  var style = document.createElement("style");
  style.textContent = css;
  document.head.appendChild(style);

  /**
   * Abre o painel do FreeLLMAPI numa JANELA propria (navegacao direta).
   *
   * Antes isto era um modal com <iframe src=URL> — e nao funciona: o gateway
   * usa helmet com X-Frame-Options: SAMEORIGIN e CSP frame-ancestors 'self',
   * e a GUI vive em OUTRA porta (3081/3110/3111), ou seja, outra origem para o
   * navegador. O frame nao carrega e o Chrome mostra "recusou a conexao" no
   * lugar do painel (confirmado no log do Chrome: "Framing
   * 'http://127.0.0.1:3002/' violates ... frame-ancestors 'self'"). Navegacao
   * direta nao sofre dessa restricao — por isso janela, e nao iframe.
   */
  function openModal() {
    window.open(URL, "_blank", "noopener");
  }

  /**
   * Topo do elemento fixo mais ALTO no canto inferior direito (os badges
   * existentes: Roteador ~16px, Modelos ~60px, badge preto de modelo/consumo
   * ~104px+). O nosso badge é posicionado logo ACIMA de todos.
   */
  function highestCornerTop(exclude) {
    var top = null;
    var nodes = document.querySelectorAll("body *");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el === exclude) continue;
      if (exclude && el.contains && el.contains(exclude)) continue;
      // coluna do layout-panel não conta como badge (é um painel inteiro)
      if (el.closest && el.closest("#dsh-layout-panel")) continue;
      var cs;
      try { cs = window.getComputedStyle(el); } catch (e) { continue; }
      if (cs.position !== "fixed") continue;
      var r = el.getBoundingClientRect();
      if (r.width < 10 || r.height < 10) continue;
      // canto inferior direito da viewport
      if (r.right < window.innerWidth - 220) continue;
      if (r.bottom < window.innerHeight - 480 || r.top > window.innerHeight - 60) continue;
      if (top === null || r.top < top) top = r.top;
    }
    return top;
  }
  function place() {
    var badge = document.getElementById("freellmapi-badge");
    if (!badge) return;
    // dentro da coluna do layout-panel: o CSS !important já força static
    if (badge.closest && badge.closest("#dsh-layout-panel")) return;
    var t = highestCornerTop(badge);
    // badge height ~28px; posiciona logo ABAIXO do elemento mais alto + 8px de gap
    var badgeH = 28;
    if (t == null) {
      badge.style.top = "16px";
    } else {
      badge.style.top = (t + badgeH + 8) + "px";
    }
  }

  /**
   * Consulta GET /api/last-request e atualiza o badge com o modelo real que
   * respondeu a última requisição com sucesso. O texto fica:
   *   "FreeLLMAPI · mistral/ministral-14b-latest"
   * Com failover (pedido != resposta), prefixa "⇄" e o tooltip detalha.
   */
  function refreshModel() {
    var badge = document.getElementById("freellmapi-badge");
    if (!badge) return;
    // Sonda o NOSSO servidor (/api/flm-probe), nao o gateway direto: falar com
    // 127.0.0.1:3002 a partir da GUI cruza origens e o navegador bloqueia por
    // CORS sempre que a origem da GUI nao esta no DASHBOARD_ORIGINS do gateway
    // (era o caso da instancia nova, em porta propria). O servidor tambem
    // distingue "gateway fora do ar" de "gateway sem /api/last-request" — antes
    // o 404 desse endpoint pintava o badge de "indisponivel" com o gateway OK.
    fetch("/api/flm-probe", { method: "GET" })
      .then(function (r) { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
      .then(function (data) {
        var span = badge.querySelector(".fl-model");
        var dot = badge.querySelector(".fl-dot");
        if (!span) return;
        if (dot) dot.className = "fl-dot " + (data && data.up ? "ok" : "bad");
        if (!data || !data.up) {
          span.textContent = "indisponível";
          span.className = "fl-model fail";
          badge.title = "Gateway FreeLLMAPI fora do ar (" + ((data && data.base) || "127.0.0.1:3002") + ")";
          return;
        }
        var lr = data.lastRequest;
        if (!lr) {
          span.textContent = data.note || "sem requisições ainda";
          span.className = "fl-model";
          badge.title = "Abrir painel FreeLLMAPI (gerenciar chaves dos modelos gratuitos)";
          return;
        }
        var real = lr.servedModel || lr.modelId;
        var label = lr.platform + "/" + real;
        var failover = lr.requestedModel && lr.requestedModel !== lr.modelId;
        span.textContent = (failover ? "⇄ " : "") + label;
        span.className = "fl-model" + (failover ? " fail" : "");
        var when = new Date(lr.createdAt.replace(" ", "T") + "Z");
        var whenTxt = isNaN(when.getTime()) ? lr.createdAt : when.toLocaleString();
        badge.title =
          "Abrir painel FreeLLMAPI (gerenciar chaves dos modelos gratuitos)\\n" +
          "Última resposta (" + whenTxt + "): " + label +
          (failover ? "\\nPedido era: " + lr.requestedModel + " → respondeu " + real + " (failover)" : "");
      })
      .catch(function () {
        var span = badge.querySelector(".fl-model");
        if (span) { span.textContent = "indisponível"; span.className = "fl-model fail"; }
      });
  }

  function insert() {
    if (document.getElementById("freellmapi-badge")) return true;
    var badge = document.createElement("button");
    badge.id = "freellmapi-badge";
    badge.type = "button";
    badge.title = "Abrir painel FreeLLMAPI (gerenciar chaves dos modelos gratuitos)";
    badge.innerHTML = '<span class="fl-dot"></span>FreeLLMAPI<span class="fl-model">…</span>';
    badge.onclick = openModal;
    document.body.appendChild(badge);
    place();
    // o ponto de status e o texto do modelo vem do MESMO probe (refreshModel),
    // que ja atualiza o .fl-dot — sem uma segunda consulta so para isso
    refreshModel();
    return true;
  }

  // insere assim que o body estiver pronto
  var tries = 0;
  var timer = setInterval(function () {
    if (!document.body) { if (++tries > 800) clearInterval(timer); return; }
    if (insert()) clearInterval(timer);
  }, 250);

  // re-insere se algo remover o badge
  setInterval(function () {
    if (document.body) insert();
  }, 5000);

  // mantém o modelo real da última requisição atualizado
  setInterval(refreshModel, 3000);

  // reposiciona sempre (o badge preto de consumo muda de altura)
  window.addEventListener("resize", place);
  setInterval(place, 2000);
})();`;

module.exports = {
  name: "freellmapi-shortcut",
  apply(ctx) {
    ctx.on("webserver/index-inject", (table) => {
      table.push({
        kind: "script",
        placement: "body",
        text: INJECT,
      });
    });
    // Sonda do gateway pelo LADO DO SERVIDOR (/api/flm-probe, na NOSSA origem).
    // O navegador nao pode consultar o gateway direto: origem diferente => CORS
    // (e o iframe do modal era barrado pelo frame-ancestors do helmet). Aqui o
    // Node consulta e devolve o resultado, entao funciona em QUALQUER porta de
    // GUI/instancia, sem depender do DASHBOARD_ORIGINS do gateway.
    const webServer = ctx.get("webServer");
    if (webServer && typeof webServer.register === "function") {
      const comTimeout = (p, ms) => Promise.race([
        p,
        new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), ms)),
      ]);
      webServer.register({
        kind: "exact",
        path: "/api/flm-probe",
        handler: (req, res) => {
          const responder = (obj) => {
            try {
              res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
              res.end(JSON.stringify(obj));
            } catch { /* conexao ja fechada */ }
          };
          const base = FREELMAPI_DASHBOARD_URL;
          (async () => {
            let up = false;
            let lastRequest = null;
            let note = "";
            try {
              const rp = await comTimeout(fetch(base + "/api/ping"), 4000);
              up = rp.ok;
            } catch { up = false; }
            if (up) {
              try {
                const rl = await comTimeout(fetch(base + "/api/last-request"), 4000);
                if (rl.ok) {
                  const j = await rl.json();
                  lastRequest = (j && j.lastRequest) || null;
                } else if (rl.status === 404) {
                  // esta versao do gateway nao expoe o endpoint: nao e falha
                  note = "gateway sem /api/last-request";
                }
              } catch { /* sem informacao */ }
            }
            responder({ ok: true, up, lastRequest, note, base });
          })();
        },
      });
      console.log("[FreeLLMAPI-Shortcut] rota /api/flm-probe registrada (sonda do gateway pelo servidor)");
    } else {
      console.log("[FreeLLMAPI-Shortcut] webServer indisponivel - badge sem sonda de status");
    }
    console.log("[FreeLLMAPI-Shortcut] badge do FreeLLMAPI injetado no dashboard");
  },
};
