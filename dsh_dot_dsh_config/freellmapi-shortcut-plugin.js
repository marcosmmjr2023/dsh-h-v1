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

const FREELMAPI_DASHBOARD_URL = "http://127.0.0.1:3002";

const INJECT = `(function () {
  "use strict";
  var URL = ${JSON.stringify(FREELMAPI_DASHBOARD_URL)};
  var css = [
    "#freellmapi-badge{position:fixed;right:16px;bottom:176px;z-index:2147483647;display:inline-flex;align-items:center;gap:6px;background:#0d1117;border:1px solid #30363d;border-radius:999px;padding:3px 11px 3px 9px;font:11px/1.7 system-ui,sans-serif;color:#9ecbff;text-decoration:none;box-shadow:0 2px 10px rgba(0,0,0,.5);white-space:nowrap;cursor:pointer;letter-spacing:.01em;}",
    "#freellmapi-badge:hover{border-color:#238636;color:#c9e6ff;}",
    "#freellmapi-badge .fl-dot{width:7px;height:7px;border-radius:50%;background:#d29922;flex:none;}",
    "#freellmapi-badge .fl-dot.ok{background:#3fb950;}",
    "#freellmapi-badge .fl-dot.bad{background:#f85149;}",
    "#freellmapi-badge .fl-model{max-width:230px;overflow:hidden;text-overflow:ellipsis;color:#7ee787;font-weight:600;}",
    "#freellmapi-badge .fl-model.fail{color:#ffa657;}",
    "#freellmapi-modal{position:fixed;inset:0;z-index:2147483647;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;}",
    "#freellmapi-modal .fl-win{width:min(980px,92vw);height:min(720px,88vh);background:#0d1117;border:1px solid #30363d;border-radius:10px;overflow:hidden;display:flex;flex-direction:column;box-shadow:0 14px 56px rgba(0,0,0,.65);}",
    "#freellmapi-modal .fl-head{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:9px 12px;border-bottom:1px solid #30363d;font:12px/1.4 system-ui,sans-serif;color:#9ecbff;flex:none;}",
    "#freellmapi-modal .fl-title{display:inline-flex;align-items:center;gap:7px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}",
    "#freellmapi-modal .fl-close{background:transparent;border:0;color:#8b949e;font:15px/1 system-ui,sans-serif;cursor:pointer;padding:5px 9px;border-radius:6px;flex:none;}",
    "#freellmapi-modal .fl-close:hover{background:#21262d;color:#fff;}",
    "#freellmapi-modal iframe{flex:1;border:0;width:100%;height:100%;background:#fff;}"
  ].join("");
  var style = document.createElement("style");
  style.textContent = css;
  document.head.appendChild(style);

  function closeModal() {
    var m = document.getElementById("freellmapi-modal");
    if (m) m.remove();
    document.removeEventListener("keydown", escHandler);
  }
  function escHandler(e) { if (e.key === "Escape") closeModal(); }
  function openModal() {
    if (document.getElementById("freellmapi-modal")) return;
    var m = document.createElement("div");
    m.id = "freellmapi-modal";
    m.innerHTML =
      '<div class="fl-win">' +
        '<div class="fl-head">' +
          '<span class="fl-title">🆓 FreeLLMAPI — gerenciar chaves dos modelos gratuitos</span>' +
          '<button class="fl-close" title="Fechar (Esc)">✕</button>' +
        "</div>" +
        '<iframe src="' + URL + '" title="FreeLLMAPI"></iframe>' +
      "</div>";
    document.body.appendChild(m);
    m.querySelector(".fl-close").onclick = closeModal;
    m.addEventListener("click", function (e) { if (e.target === m) closeModal(); });
    document.addEventListener("keydown", escHandler);
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
      if (el.id === "freellmapi-modal") continue;
      if (el.closest && el.closest("#freellmapi-modal")) continue;
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
    var h = highestCornerTop(badge);
    badge.style.bottom = (h == null ? 176 : Math.max(8, window.innerHeight - h + 8)) + "px";
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
    fetch(URL + "/api/last-request", { method: "GET" })
      .then(function (r) { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
      .then(function (data) {
        var span = badge.querySelector(".fl-model");
        if (!span) return;
        var lr = data && data.lastRequest;
        if (!lr) {
          span.textContent = "sem requisições ainda";
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
    try {
      fetch(URL + "/api/ping", { method: "GET" })
        .then(function (r) { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
        .then(function () { var d = badge.querySelector(".fl-dot"); if (d) d.className = "fl-dot ok"; })
        .catch(function () { var d = badge.querySelector(".fl-dot"); if (d) d.className = "fl-dot bad"; });
    } catch (e) { /* fetch indisponivel */ }
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
    console.log("[FreeLLMAPI-Shortcut] badge do FreeLLMAPI injetado no dashboard");
  },
};
