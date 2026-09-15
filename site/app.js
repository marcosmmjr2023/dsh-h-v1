/* FreeDSH — melhorias progressivas da landing page.
 * Sem dependências: alternador PT/EN, botões de copiar e fallback do GIF.
 * Tudo é opcional: sem JavaScript a página continua legível em português. */
(function () {
  "use strict";

  var STORAGE_KEY = "freedsh-lang";
  var DEFAULT_LANG = "pt"; // o site nasce em pt-BR
  // Atributos que também têm versão traduzida (data-pt-alt / data-en-alt, ...)
  var ATTRS = ["alt", "title", "aria-label", "content", "placeholder"];

  var currentLang = DEFAULT_LANG;

  /* ---------- idioma ---------- */

  function readStoredLang() {
    try {
      var saved = window.localStorage.getItem(STORAGE_KEY);
      return saved === "en" || saved === "pt" ? saved : null;
    } catch (e) {
      return null; // localStorage pode falhar em file:// ou modo privado
    }
  }

  function storeLang(lang) {
    try { window.localStorage.setItem(STORAGE_KEY, lang); } catch (e) { /* ignora */ }
  }

  function applyLang(lang) {
    currentLang = lang === "en" ? "en" : DEFAULT_LANG;
    var suffix = currentLang === "en" ? "en" : "pt";

    Array.prototype.forEach.call(document.querySelectorAll("[data-pt], [data-en]"), function (el) {
      var value = el.getAttribute("data-" + suffix);
      if (value !== null) el.textContent = value;
    });

    ATTRS.forEach(function (attr) {
      Array.prototype.forEach.call(document.querySelectorAll("[data-pt-" + attr + "], [data-en-" + attr + "]"), function (el) {
        var value = el.getAttribute("data-" + suffix + "-" + attr);
        if (value !== null) el.setAttribute(attr, value);
      });
    });

    document.documentElement.lang = currentLang === "en" ? "en" : "pt-BR";

    Array.prototype.forEach.call(document.querySelectorAll(".lang-btn"), function (btn) {
      btn.setAttribute("aria-pressed", String(btn.getAttribute("data-lang") === currentLang));
    });

    var status = document.getElementById("copy-status");
    if (status) status.textContent = ""; // evita mensagem no idioma antigo
  }

  function setupLangSwitch() {
    var box = document.getElementById("lang-switch");
    if (!box) return;

    var stored = readStoredLang();
    box.hidden = false; // o alternador só passa a existir quando o JS está ativo

    box.addEventListener("click", function (event) {
      var btn = event.target.closest ? event.target.closest(".lang-btn") : null;
      if (!btn) return;
      var lang = btn.getAttribute("data-lang") === "en" ? "en" : "pt";
      if (lang === currentLang) return;
      applyLang(lang);
      storeLang(lang);
    });

    if (stored && stored !== currentLang) applyLang(stored);
  }

  /* ---------- copiar comando ---------- */

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    // Fallback (funciona em file:// e navegadores antigos)
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.top = "-1000px";
      document.body.appendChild(area);
      area.select();
      var ok = false;
      try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
      document.body.removeChild(area);
      ok ? resolve() : reject(new Error("copy failed"));
    });
  }

  function setupCopyButtons() {
    var status = document.getElementById("copy-status");

    Array.prototype.forEach.call(document.querySelectorAll("[data-copy]"), function (btn) {
      btn.addEventListener("click", function () {
        var target = document.getElementById(btn.getAttribute("data-copy"));
        if (!target) return;
        var text = target.textContent;

        copyText(text).then(function () {
          if (status) {
            status.textContent = currentLang === "en" ? "Command copied." : "Comando copiado.";
          }
        }).catch(function () {
          if (status) {
            status.textContent = currentLang === "en"
              ? "Copy failed — select the command and copy it manually."
              : "Não foi possível copiar — selecione o comando e copie manualmente.";
          }
        });
      });
    });
  }

  /* ---------- GIF aberto direto do disco ---------- */

  function setupDemoFallback() {
    var img = document.getElementById("demo-gif");
    if (!img) return;
    var fallback = img.getAttribute("data-fallback-src");
    if (!fallback) return;

    // Publicado no Pages o GIF está em assets/ ao lado do index.html;
    // aberto do disco ele está em ../assets/ (fora de site/).
    function useFallback() {
      if (img.getAttribute("src") !== fallback) img.setAttribute("src", fallback);
    }

    // O erro pode acontecer ANTES deste script rodar (o arquivo é local e
    // falha rápido), então o estado atual também é conferido aqui.
    if (img.complete && img.naturalWidth === 0) useFallback();
    img.addEventListener("error", useFallback);
  }

  /* ---------- início ---------- */

  function init() {
    setupLangSwitch();
    setupCopyButtons();
    setupDemoFallback();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
