/**
 * Layout Panel — coluna de informações à direita no DeepSeek Harness
 *
 * Cria uma coluna fixa à direita do dashboard para abrigar os badges
 * flutuantes (FreeLLMAPI, ⚡ Roteador, Modelos, consumo...) e outras
 * informações úteis (últimos arquivos modificados, status do gateway).
 *
 * Como funciona:
 *  - Server-side: registra GET /api/layout-info (via ctx.get("webServer")),
 *    que lista os arquivos mais recentemente modificados do diretório
 *    monitorado (LAYOUT_PANEL_DIR, default /home/deploy/projects) e o status
 *    básico do sistema. Nenhuma credencial é exposta.
 *  - Client-side (inject): injeta a coluna (position:fixed à direita),
 *    aplica padding-right no frame do app (a sessão "desliza" para a
 *    esquerda, sem sobreposição) e move para dentro da coluna todos os
 *    elementos com position:fixed no canto inferior direito (badges), com
 *    CSS !important neutralizando o posicionamento inline deles.
 *
 * Configuração (ambiente do processo dsh-web):
 *   LAYOUT_PANEL_DIR   diretório monitorado (default: /home/deploy/projects)
 *   LAYOUT_PANEL_WIDTH largura da coluna em px (default: 300)
 *
 * O estado (coluna aberta/recolhida) é lembrado em localStorage.
 */

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

// Assets do editor (CodeMirror 5 + marked.js) servidos localmente, sem CDN.
// ATENÇÃO: o webServer faz match de prefix com `${prefix}/` — por isso o path
// NÃO pode terminar com "/" (senão vira "//" e nunca matcheia).
const EDITOR_ASSETS_DIR = path.join(__dirname, "editor-assets");
const EDITOR_ASSETS_URL = "/dlp-editor";

// content-type por extensão para servir os assets do editor
const MIME = {
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".map": "application/json; charset=utf-8",
};

const PANEL_DIR = process.env.LAYOUT_PANEL_DIR || "/home/deploy/projects";
const PANEL_WIDTH = Math.min(Math.max(parseInt(process.env.LAYOUT_PANEL_WIDTH || "300", 10) || 300, 220), 420);

// diretórios/arquivos que nunca aparecem na lista de recentes
const IGNORED_DIRS = new Set([
  "node_modules", ".git", "dist", "build", ".venv", "venv", "__pycache__",
  ".dsh", ".cache", ".next", ".nuxt", "coverage", ".idea", ".vscode",
  "server/data", "data", "logs", ".pm2"
]);
const IGNORED_EXT = new Set([".db", ".sqlite", ".lock", ".log", ".env", ".pid", ".map"]);
const MAX_DEPTH = 5;
const MAX_FILES = 14;

/** Varre o diretório (profundidade limitada) e devolve arquivos com mtime. */
function walkFiles(root, depth, out) {
  if (depth > MAX_DEPTH || out.length >= MAX_FILES * 6) return;
  let entries;
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return;
  }
  for (const ent of entries) {
    if (IGNORED_DIRS.has(ent.name)) continue;
    const full = path.join(root, ent.name);
    let st;
    try {
      st = fs.statSync(full);
    } catch {
      continue;
    }
    if (ent.isDirectory()) {
      walkFiles(full, depth + 1, out);
    } else if (ent.isFile()) {
      const ext = path.extname(ent.name).toLowerCase();
      if (IGNORED_EXT.has(ext)) continue;
      out.push({
        path: full,
        name: ent.name,
        mtimeMs: st.mtimeMs,
        size: st.size,
      });
    }
  }
}

function layoutInfoPayload() {
  const files = [];
  try {
    walkFiles(PANEL_DIR, 0, files);
  } catch (e) {
    /* sem acesso: lista vazia */
  }
  files.sort((a, b) => b.mtimeMs - a.mtimeMs);
  const top = files.slice(0, MAX_FILES).map((f) => ({
    path: f.path,
    rel: path.relative(PANEL_DIR, f.path),
    name: f.name,
    mtimeMs: f.mtimeMs,
    size: f.size,
  }));
  return {
    ok: true,
    dir: PANEL_DIR,
    hostname: os.hostname(),
    uptimeSec: Math.round(process.uptime()),
    files: top,
  };
}

const MAX_EDIT_SIZE = 1024 * 1024; // 1MB — acima disso recusa abrir no editor

/** Resolve um caminho relativo dentro de PANEL_DIR (anti path-traversal). */
function resolveInside(rel) {
  if (typeof rel !== "string" || rel.length === 0) return null;
  const resolved = path.resolve(PANEL_DIR, rel);
  if (resolved !== PANEL_DIR && !resolved.startsWith(PANEL_DIR + path.sep)) return null;
  return resolved;
}

/** Lê um arquivo de texto com limite de tamanho; rejeita binários. */
function readTextFile(rel) {
  const full = resolveInside(rel);
  if (!full) return { error: "caminho fora do diretório monitorado" };
  let st, buf;
  try {
    st = fs.statSync(full);
    buf = fs.readFileSync(full);
  } catch (e) {
    return { error: `não foi possível ler: ${e.code ?? e.message}` };
  }
  if (!st.isFile()) return { error: "não é um arquivo" };
  if (st.size > MAX_EDIT_SIZE) return { error: `arquivo grande demais (${(st.size / 1048576).toFixed(1)}MB, máx 1MB)` };
  // binário? procura byte nulo nos primeiros 8KB
  const probe = buf.subarray(0, 8192);
  if (probe.includes(0)) return { error: "arquivo binário — não pode ser aberto no editor" };
  return { ok: true, content: buf.toString("utf8"), size: st.size, mtimeMs: st.mtimeMs };
}

/** Grava um arquivo de texto com limite de tamanho. */
function writeTextFile(rel, content) {
  const full = resolveInside(rel);
  if (!full) return { error: "caminho fora do diretório monitorado" };
  if (typeof content !== "string") return { error: "conteúdo inválido" };
  if (Buffer.byteLength(content, "utf8") > MAX_EDIT_SIZE) return { error: "conteúdo grande demais (máx 1MB)" };
  try {
    fs.writeFileSync(full, content, "utf8");
    const st = fs.statSync(full);
    return { ok: true, mtimeMs: st.mtimeMs };
  } catch (e) {
    return { error: `não foi possível salvar: ${e.code ?? e.message}` };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT: CSS da coluna (injetado no <head>)
// ═══════════════════════════════════════════════════════════════════════════

const PANEL_CSS = `
#dsh-layout-panel{position:fixed;top:0;right:0;bottom:0;width:${PANEL_WIDTH}px;z-index:2147483646;
  background:#0d1117;border-left:1px solid #30363d;
  display:flex;flex-direction:column;font:12px/1.5 system-ui,sans-serif;color:#e6edf3;
  box-shadow:-8px 0 24px rgba(0,0,0,.35);transition:transform .25s ease;}
#dsh-layout-panel.dlp-closed{transform:translateX(100%);}
#dsh-layout-panel .dlp-head{display:flex;align-items:center;justify-content:space-between;gap:8px;
  padding:10px 12px;border-bottom:1px solid #21262d;flex:none;}
#dsh-layout-panel .dlp-title{font-weight:700;font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:#8b949e;}
#dsh-layout-panel .dlp-toggle{background:transparent;border:0;color:#8b949e;
  cursor:pointer;font:13px/1 system-ui,sans-serif;padding:4px 8px;border-radius:6px;}
#dsh-layout-panel .dlp-toggle:hover{background:#21262d;color:#fff;}
#dsh-layout-panel .dlp-body{flex:1;overflow-y:auto;overflow-x:hidden;padding:10px 12px 16px;}
#dsh-layout-panel .dlp-section{margin-bottom:14px;}
#dsh-layout-panel .dlp-section h3{margin:0 0 6px;font-size:10px;font-weight:700;letter-spacing:.05em;
  text-transform:uppercase;color:#8b949e;}
#dsh-layout-panel .dlp-badges{display:flex;flex-direction:column;gap:6px;margin-bottom:2px;}
#dsh-layout-panel .dlp-badges > *{position:static !important;right:auto !important;bottom:auto !important;
  left:auto !important;top:auto !important;z-index:auto !important;transform:none !important;
  margin:0 !important;width:100% !important;box-sizing:border-box;}
#dsh-layout-panel ul.dlp-files{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:2px;}
#dsh-layout-panel .dlp-file{display:flex;flex-direction:column;gap:1px;padding:5px 8px;border-radius:6px;
  cursor:pointer;border:1px solid transparent;}
#dsh-layout-panel .dlp-file:hover{background:#161b22;border-color:#21262d;}
#dsh-layout-panel .dlp-file .fl-name{font:11px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;color:#e6edf3;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
#dsh-layout-panel .dlp-file .fl-meta{display:flex;justify-content:space-between;gap:8px;font-size:10px;color:#8b949e;}
#dsh-layout-panel .dlp-sys{display:grid;grid-template-columns:1fr 1fr;gap:4px 10px;font-size:11px;}
#dsh-layout-panel .dlp-sys b{color:#8b949e;font-weight:600;}
#dsh-layout-panel .dlp-empty{color:#8b949e;font-size:11px;padding:4px 2px;}
#dsh-layout-panel .dlp-status{display:inline-flex;align-items:center;gap:6px;font-size:11px;}
#dsh-layout-panel .dlp-dot{width:7px;height:7px;border-radius:50%;background:#d29922;flex:none;display:inline-block;}
#dsh-layout-panel .dlp-dot.ok{background:#3fb950;}
#dsh-layout-panel .dlp-dot.bad{background:#f85149;}
#dlp-open-btn{position:fixed;right:0;top:50%;transform:translateY(-50%);z-index:2147483646;
  background:#0d1117;border:1px solid #30363d;border-right:0;
  color:#8b949e;cursor:pointer;font:12px/1 system-ui,sans-serif;
  padding:10px 6px;border-radius:8px 0 0 8px;box-shadow:-4px 0 12px rgba(0,0,0,.3);}
#dlp-open-btn:hover{color:#fff;}
#dlp-editor-modal{position:fixed;inset:0;z-index:2147483647;background:rgba(0,0,0,.6);
  display:flex;align-items:center;justify-content:center;}
#dlp-editor-modal .ed-win{width:min(1200px,96vw);height:min(820px,94vh);background:#0d1117;
  border:1px solid #30363d;border-radius:10px;overflow:hidden;display:flex;flex-direction:column;
  box-shadow:0 14px 56px rgba(0,0,0,.65);}
#dlp-editor-modal .ed-head{display:flex;align-items:center;gap:10px;padding:8px 12px;
  border-bottom:1px solid #21262d;font:12px/1.4 system-ui,sans-serif;color:#9ecbff;flex:none;}
#dlp-editor-modal .ed-file{font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;color:#e6edf3;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;}
#dlp-editor-modal .ed-path{color:#8b949e;font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:35%;}
#dlp-editor-modal .ed-tabs{display:inline-flex;gap:2px;background:#161b22;border:1px solid #21262d;border-radius:6px;padding:2px;flex:none;}
#dlp-editor-modal .ed-tab{background:transparent;border:0;color:#8b949e;border-radius:4px;cursor:pointer;
  padding:4px 12px;font:12px/1 system-ui,sans-serif;}
#dlp-editor-modal .ed-tab.active{background:#30363d;color:#fff;}
#dlp-editor-modal .ed-btn{background:#21262d;border:1px solid #30363d;color:#e6edf3;border-radius:6px;
  cursor:pointer;padding:5px 12px;font:12px/1 system-ui,sans-serif;flex:none;}
#dlp-editor-modal .ed-btn:hover{background:#30363d;}
#dlp-editor-modal .ed-btn.save{background:#238636;border-color:#238636;color:#fff;}
#dlp-editor-modal .ed-btn.save:hover{filter:brightness(1.15);}
#dlp-editor-modal .ed-btn.close{background:transparent;border:0;color:#8b949e;font:15px/1 system-ui,sans-serif;padding:5px 9px;}
#dlp-editor-modal .ed-btn.close:hover{background:#21262d;color:#fff;}
#dlp-editor-modal .ed-wrap{flex:1;display:flex;min-height:0;background:#0d1117;position:relative;}
#dlp-editor-modal .ed-area-cm{flex:1;min-width:0;position:relative;}
#dlp-editor-modal .ed-preview{flex:1;min-width:0;overflow:auto;padding:16px 20px;background:#0d1117;color:#e6edf3;
  font:13px/1.65 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;display:none;}
#dlp-editor-modal .ed-preview.active{display:block;}
#dlp-editor-modal .ed-preview h1,#dlp-editor-modal .ed-preview h2,#dlp-editor-modal .ed-preview h3{color:#9ecbff;margin:14px 0 8px;}
#dlp-editor-modal .ed-preview h1{font-size:20px;border-bottom:1px solid #21262d;padding-bottom:6px;}
#dlp-editor-modal .ed-preview h2{font-size:17px;}
#dlp-editor-modal .ed-preview h3{font-size:14px;}
#dlp-editor-modal .ed-preview p{margin:8px 0;}
#dlp-editor-modal .ed-preview code{background:#161b22;border:1px solid #21262d;border-radius:4px;padding:1px 5px;font:12px ui-monospace,monospace;}
#dlp-editor-modal .ed-preview pre{background:#161b22;border:1px solid #21262d;border-radius:6px;padding:10px 12px;overflow:auto;}
#dlp-editor-modal .ed-preview pre code{background:transparent;border:0;padding:0;}
#dlp-editor-modal .ed-preview a{color:#4d9fff;}
#dlp-editor-modal .ed-preview table{border-collapse:collapse;margin:10px 0;}
#dlp-editor-modal .ed-preview th,#dlp-editor-modal .ed-preview td{border:1px solid #30363d;padding:5px 10px;}
#dlp-editor-modal .ed-preview blockquote{border-left:3px solid #30363d;margin:8px 0;padding:2px 12px;color:#8b949e;}
#dlp-editor-modal .ed-preview ul,#dlp-editor-modal .ed-preview ol{padding-left:22px;margin:8px 0;}
#dlp-editor-modal .ed-preview hr{border:0;border-top:1px solid #21262d;margin:14px 0;}
#dlp-editor-modal .ed-status{flex:none;padding:5px 12px;border-top:1px solid #21262d;font:11px/1.5 system-ui,sans-serif;
  color:#8b949e;display:flex;justify-content:space-between;gap:10px;}
#dlp-editor-modal .ed-status.ok{color:#3fb950;}
#dlp-editor-modal .ed-status.err{color:#f85149;}
#dlp-editor-modal .ed-status .ed-ln{color:#484f58;}
/* CodeMirror — escuro, compacto, sem bordas internas */
#dlp-editor-modal .CodeMirror{height:100%;background:#0d1117;color:#e6edf3;font:13px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace;}
#dlp-editor-modal .CodeMirror-gutters{background:#161b22;border-right:1px solid #21262d;}
#dlp-editor-modal .CodeMirror-linenumber{color:#484f58;}
#dlp-editor-modal .CodeMirror-cursor{border-left:1px solid #e6edf3;}
#dlp-editor-modal .CodeMirror-selected{background:#264f78;}
#dlp-editor-modal .CodeMirror-activeline-background{background:#161b22;}
#dlp-editor-modal .CodeMirror-matchingbracket{color:#3fb950 !important;outline:1px solid #3fb950;}
`;

// ═══════════════════════════════════════════════════════════════════════════
// CLIENT: JS da coluna (injetado no <body>)
// ═══════════════════════════════════════════════════════════════════════════

const PANEL_JS = `(function () {
  "use strict";
  var PANEL_DIR = ${JSON.stringify(PANEL_DIR)};
  var API = "/api/layout-info";
  var API_FILE = "/api/layout-file";
  var FREELMAPI = "http://127.0.0.1:3002";
  var LS_KEY = "dlp-collapsed-v1";

  function esc(s) { var d = document.createElement("div"); d.textContent = s == null ? "" : String(s); return d.innerHTML; }
  function fmtAgo(ms) {
    var s = Math.max(1, Math.floor((Date.now() - ms) / 1000));
    if (s < 60) return s + "s";
    if (s < 3600) return Math.floor(s / 60) + "min";
    if (s < 86400) return Math.floor(s / 3600) + "h";
    return Math.floor(s / 86400) + "d";
  }
  function fmtSize(n) {
    if (n < 1024) return n + "B";
    if (n < 1048576) return (n / 1024).toFixed(1) + "KB";
    return (n / 1048576).toFixed(1) + "MB";
  }

  var panel = null;
  var openBtn = null;

  function build() {
    if (document.getElementById("dsh-layout-panel")) return;
    panel = document.createElement("aside");
    panel.id = "dsh-layout-panel";
    panel.innerHTML =
      '<div class="dlp-head"><span class="dlp-title">Painel</span>' +
      '<button class="dlp-toggle" id="dlp-collapse" title="Recolher painel">»</button></div>' +
      '<div class="dlp-body">' +
        '<div class="dlp-section"><h3>Atalhos</h3><div class="dlp-badges" id="dlp-badges"></div></div>' +
        '<div class="dlp-section"><h3>Últimos arquivos modificados</h3>' +
          '<ul class="dlp-files" id="dlp-files"><li class="dlp-empty">carregando…</li></ul></div>' +
        '<div class="dlp-section"><h3>Gateway FreeLLMAPI</h3>' +
          '<div class="dlp-status"><span class="dlp-dot" id="dlp-fl-dot"></span><span id="dlp-fl-txt">verificando…</span></div></div>' +
        '<div class="dlp-section"><h3>Sistema</h3><div class="dlp-sys" id="dlp-sys">…</div></div>' +
      '</div>';
    document.body.appendChild(panel);
    document.getElementById("dlp-collapse").onclick = function () { setClosed(true); };
    if (localStorage.getItem(LS_KEY) === "1") setClosed(true);
    refreshFiles();
    refreshGateway();
    setInterval(refreshFiles, 10000);
    setInterval(refreshGateway, 4000);
  }

  function setClosed(closed) {
    if (!panel) return;
    panel.classList.toggle("dlp-closed", closed);
    try { localStorage.setItem(LS_KEY, closed ? "1" : "0"); } catch (e) {}
    applyShift();
    if (closed && !openBtn) {
      openBtn = document.createElement("button");
      openBtn.id = "dlp-open-btn";
      openBtn.type = "button";
      openBtn.title = "Abrir painel";
      openBtn.textContent = "«";
      openBtn.onclick = function () { setClosed(false); };
      document.body.appendChild(openBtn);
    }
    if (!closed && openBtn) { openBtn.remove(); openBtn = null; }
  }

  /** Desloca o frame do app para a esquerda (padding-right) quando aberto. */
  function applyShift() {
    var frame = document.querySelector('div[style*="grid-template-columns"]');
    if (!frame) return;
    var closed = panel && panel.classList.contains("dlp-closed");
    if (closed) frame.style.paddingRight = "";
    else frame.style.paddingRight = ${PANEL_WIDTH} + "px";
  }

  /** Move badges flutuantes do canto inferior direito para a coluna. */
  function collectBadges() {
    var host = document.getElementById("dlp-badges");
    if (!panel || !host) return;
    var nodes = document.querySelectorAll("body *");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (!el || el.id === "dsh-layout-panel" || el.id === "dlp-open-btn") continue;
      if (el.closest && el.closest("#dsh-layout-panel")) continue;
      if (el.closest && el.closest("#freellmapi-modal")) continue;
      if (host.contains(el)) continue;
      var cs;
      try { cs = window.getComputedStyle(el); } catch (e) { continue; }
      if (cs.position !== "fixed") continue;
      if (cs.display === "none" || cs.visibility === "hidden") continue;
      var r = el.getBoundingClientRect();
      if (r.width < 20 || r.width > 420 || r.height < 16 || r.height > 120) continue;
      // badges do canto direito: mesmo que o freellmapi-shortcut os tenha
      // empurrado para fora da viewport (top negativo), ainda captura se a
      // borda direita estiver na faixa do canto.
      if (r.right < window.innerWidth - 260) continue;
      if (r.left < window.innerWidth - 340) continue;
      if (r.top > window.innerHeight - 40 && r.bottom > window.innerHeight) continue;
      host.appendChild(el);
    }
  }

  function refreshFiles() {
    var ul = document.getElementById("dlp-files");
    if (!ul) return;
    fetch(API, { method: "GET" })
      .then(function (r) { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
      .then(function (data) {
        var files = (data && data.files) || [];
        if (files.length === 0) {
          ul.innerHTML = '<li class="dlp-empty">nenhum arquivo encontrado em ' + esc(PANEL_DIR) + "</li>";
        } else {
          ul.innerHTML = "";
          files.forEach(function (f) {
            var li = document.createElement("li");
            li.className = "dlp-file";
            li.title = f.path + " (" + new Date(f.mtimeMs).toLocaleString() + ")";
            li.innerHTML =
              '<span class="fl-name">' + esc(f.rel) + "</span>" +
              '<span class="fl-meta"><span>' + fmtAgo(f.mtimeMs) + "</span><span>" + fmtSize(f.size) + "</span></span>";
            li.onclick = function () { openEditor(f); };
            ul.appendChild(li);
          });
        }
        var sys = document.getElementById("dlp-sys");
        if (sys && data) {
          sys.innerHTML =
            "<span><b>Host:</b> " + esc(data.hostname || "-") + "</span>" +
            "<span><b>Uptime:</b> " + fmtAgo(Date.now() - (data.uptimeSec || 0) * 1000) + "</span>" +
            "<span style='grid-column:1/-1'><b>Dir:</b> " + esc(data.dir || PANEL_DIR) + "</span>";
        }
      })
      .catch(function () {
        ul.innerHTML = '<li class="dlp-empty">erro ao listar arquivos</li>';
      });
  }

  // ── Editor de arquivos (estilo IDE com CodeMirror) ────────────────────────
  var edState = null; // { rel, dirty, saved, cm, mode }
  var cmLoaded = false; // assets do CodeMirror já carregados nesta página
  var ASSET = "/dlp-editor/";

  // modo CodeMirror por extensão de arquivo
  var CM_MODES = {
    js: "javascript", mjs: "javascript", cjs: "javascript", ts: "javascript", tsx: "javascript",
    jsx: "javascript", json: { name: "javascript", json: true },
    py: "python", yaml: "yaml", yml: "yaml",
    md: "markdown", markdown: "markdown",
    html: "htmlmixed", htm: "htmlmixed", vue: "htmlmixed", xml: "xml", svg: "xml",
    sh: "shell", bash: "shell", zsh: "shell",
    sql: "sql", css: "css", scss: "css",
    c: "clike", h: "clike", cpp: "clike", hpp: "clike", java: "clike", cs: "clike",
    rb: "ruby", php: "php", go: "go", rs: "rust",
    txt: null, text: null, log: null, conf: null, ini: null, env: null, toml: null
  };
  // arquivos de mode a carregar sob demanda (nome no disco == chave em CM_MODES)
  function cmModeFor(rel) {
    var dot = rel.lastIndexOf(".");
    var ext = dot >= 0 ? rel.slice(dot + 1).toLowerCase() : "";
    return CM_MODES[ext] ?? null;
  }

  // carrega um script/CSS uma única vez; resolve quando pronto
  function loadAsset(tag, src) {
    return new Promise(function (resolve, reject) {
      if (tag === "link") {
        if (document.querySelector('link[href="' + src + '"]')) { resolve(); return; }
        var l = document.createElement("link");
        l.rel = "stylesheet"; l.href = src;
        l.onload = resolve; l.onerror = function () { reject(new Error("css " + src)); };
        document.head.appendChild(l);
        return;
      }
      if (document.querySelector('script[src="' + src + '"]')) { resolve(); return; }
      var s = document.createElement("script");
      s.src = src;
      // async=false preserva a ORDEM de execução: os modos dependem do core
      // (codemirror.min.js) já ter definido CodeMirror antes de rodar.
      s.async = false;
      s.onload = resolve; s.onerror = function () { reject(new Error("js " + src)); };
      document.head.appendChild(s);
    });
  }

  // carrega o core do CodeMirror + tema + marked (uma vez por página)
  function ensureCmLoaded(mode) {
    var tasks = [
      loadAsset("link", ASSET + "codemirror.min.css"),
      loadAsset("link", ASSET + "theme-dracula.css"),
      loadAsset("script", ASSET + "codemirror.min.js"),
      loadAsset("script", ASSET + "marked.min.js")
    ];
    if (mode && mode !== "markdown") tasks.push(loadAsset("script", ASSET + "modes/" + mode + ".min.js"));
    return Promise.all(tasks).then(function () { cmLoaded = true; });
  }

  function edStatus(cls, text) {
    var st = document.getElementById("dlp-ed-status");
    if (!st) return;
    st.className = "ed-status" + (cls ? " " + cls : "");
    st.innerHTML = "<span>" + esc(text) + "</span><span class='ed-ln' id='dlp-ed-ln'>1:1</span>";
  }

  function edUpdateLine() {
    var cm = edState && edState.cm;
    var ln = document.getElementById("dlp-ed-ln");
    if (!cm || !ln) return;
    var cur = cm.getCursor();
    ln.textContent = (cur.line + 1) + ":" + (cur.ch + 1);
  }

  function edRenderPreview() {
    var pv = document.getElementById("dlp-ed-preview");
    var cm = edState && edState.cm;
    if (!pv || !cm) return;
    if (typeof marked !== "undefined" && edState.mode === "markdown") {
      pv.innerHTML = marked.parse(cm.getValue() || "");
    } else {
      pv.innerHTML = "<pre>" + esc(cm.getValue() || "") + "</pre>";
    }
    pv.scrollTop = 0;
  }

  function edShowTab(which) {
    var cmEl = document.getElementById("dlp-ed-cm");
    var pv = document.getElementById("dlp-ed-preview");
    var tabs = document.querySelectorAll("#dlp-editor-modal .ed-tab");
    if (!cmEl || !pv) return;
    var isEdit = which === "edit";
    cmEl.style.display = isEdit ? "block" : "none";
    pv.classList.toggle("active", !isEdit);
    for (var i = 0; i < tabs.length; i++) tabs[i].classList.toggle("active", tabs[i].dataset.tab === which);
    if (!isEdit) edRenderPreview();
    else if (edState && edState.cm) edState.cm.refresh();
  }

  function edSave() {
    if (!edState || !edState.cm) return;
    edStatus("", "salvando…");
    fetch(API_FILE + "?rel=" + encodeURIComponent(edState.rel), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ content: edState.cm.getValue() })
    })
      .then(function (r) { return r.json().then(function (d) { return { status: r.status, d: d }; }); })
      .then(function (res) {
        if (res.d && res.d.ok) {
          edState.dirty = false;
          edState.saved = Date.now();
          edStatus("ok", "salvo ✓ " + new Date(res.d.mtimeMs).toLocaleTimeString());
        } else {
          edStatus("err", "erro: " + (res.d && res.d.error ? res.d.error : "desconhecido"));
        }
      })
      .catch(function () { edStatus("err", "erro de rede ao salvar"); });
  }

  function edClose() {
    var m = document.getElementById("dlp-editor-modal");
    if (m) m.remove();
    edState = null;
    document.removeEventListener("keydown", edKey);
  }

  function edKey(e) {
    if (e.key === "Escape") { edClose(); return; }
    if ((e.ctrlKey || e.metaKey) && (e.key === "s" || e.key === "S")) {
      e.preventDefault();
      edSave();
    }
  }

  function openEditor(f) {
    if (edState) edClose();
    edState = { rel: f.rel, dirty: false, saved: null, cm: null };
    var mode = cmModeFor(f.rel);
    edState.mode = mode;
    var isMd = mode === "markdown";

    var m = document.createElement("div");
    m.id = "dlp-editor-modal";
    m.innerHTML =
      '<div class="ed-win">' +
        '<div class="ed-head">' +
          '<span class="ed-file">' + esc(f.rel) + "</span>" +
          '<span class="ed-path">' + esc(f.path) + "</span>" +
          '<div class="ed-tabs">' +
            '<button class="ed-tab active" data-tab="edit">Editar</button>' +
            (isMd ? '<button class="ed-tab" data-tab="preview">Preview</button>' : "") +
          "</div>" +
          '<button class="ed-btn" id="dlp-ed-copy" title="Copiar caminho">📋</button>' +
          '<button class="ed-btn save" id="dlp-ed-save">💾 Salvar (Ctrl+S)</button>' +
          '<button class="ed-btn close" id="dlp-ed-close" title="Fechar (Esc)">✕</button>' +
        "</div>" +
        '<div class="ed-wrap">' +
          '<div class="ed-area-cm" id="dlp-ed-cm"><textarea id="dlp-ed-area" spellcheck="false"></textarea></div>' +
          '<div class="ed-preview" id="dlp-ed-preview"></div>' +
        "</div>" +
        '<div class="ed-status" id="dlp-ed-status"><span>carregando…</span><span class="ed-ln" id="dlp-ed-ln">1:1</span></div>' +
      "</div>";
    document.body.appendChild(m);
    document.getElementById("dlp-ed-close").onclick = edClose;
    document.getElementById("dlp-ed-save").onclick = edSave;
    document.getElementById("dlp-ed-copy").onclick = function () {
      try { navigator.clipboard.writeText(f.path); } catch (e) {}
      edStatus("ok", "caminho copiado: " + f.path);
    };
    var tabs = m.querySelectorAll(".ed-tab");
    for (var t = 0; t < tabs.length; t++) {
      tabs[t].onclick = function () { edShowTab(this.dataset.tab); };
    }
    m.addEventListener("click", function (e) { if (e.target === m) edClose(); });
    document.addEventListener("keydown", edKey);

    edStatus("", "carregando editor…");
    ensureCmLoaded(mode)
      .catch(function (err) {
        // fallback: sem CodeMirror, usa textarea simples
        var area = document.getElementById("dlp-ed-area");
        if (area) area.style.display = "block";
        edStatus("err", "CodeMirror não carregou (" + (err && err.message ? err.message : err) + ") — modo texto");
        return null;
      })
      .then(function () {
        return fetch(API_FILE + "?rel=" + encodeURIComponent(f.rel), { method: "GET" })
          .then(function (r) { return r.json().then(function (d) { return { status: r.status, d: d }; }); });
      })
      .then(function (res) {
        if (!res || !res.d) return;
        var area = document.getElementById("dlp-ed-area");
        if (!area) return;
        if (!res.d.ok) {
          area.disabled = true;
          edStatus("err", "não foi possível abrir: " + (res.d.error || "erro"));
          return;
        }
        if (cmLoaded && typeof CodeMirror !== "undefined") {
          var cm = CodeMirror.fromTextArea(area, {
            mode: edState.mode ? (typeof edState.mode === "object" ? edState.mode : edState.mode) : "",
            theme: "dracula",
            lineNumbers: true,
            matchBrackets: true,
            autoCloseBrackets: true,
            styleActiveLine: true,
            indentUnit: 2,
            tabSize: 2,
            indentWithTabs: false,
            lineWrapping: false
          });
          // fromTextArea lê o valor do <textarea> (não da opção "value");
          // por isso o conteúdo é injetado DEPOIS de criar a instância.
          cm.setValue(res.d.content);
          cm.scrollTo(0, 0);
          cm.setCursor({ line: 0, ch: 0 });
          edState.cm = cm;
          cm.on("change", function () { edState.dirty = true; });
          cm.on("cursorActivity", edUpdateLine);
          edUpdateLine();
          edStatus("", "pronto · " + fmtSize(res.d.size) + " · UTF-8 · " + (edState.mode || "texto"));
          // O CodeMirror mede a altura do container na criação; se o modal
          // ainda não teve o layout calculado (flex acabou de montar), ele
          // renderiza a viewport errada. refresh() após um tick re-mede e
          // recoloca no topo — sem isso o gutter mostra linha ~140.
          setTimeout(function () {
            if (!edState || edState.cm !== cm) return;
            cm.refresh();
            cm.scrollTo(0, 0);
            cm.setCursor({ line: 0, ch: 0 });
            edUpdateLine();
          }, 120);
        } else {
          area.value = res.d.content;
          area.disabled = false;
          edStatus("", "pronto · " + fmtSize(res.d.size) + " · UTF-8 (texto)");
        }
      })
      .catch(function () {
        var area = document.getElementById("dlp-ed-area");
        if (area) { area.disabled = true; }
        edStatus("err", "erro de rede ao abrir arquivo");
      });
  }

  function refreshGateway() {
    var dot = document.getElementById("dlp-fl-dot");
    var txt = document.getElementById("dlp-fl-txt");
    if (!dot || !txt) return;
    fetch(FREELMAPI + "/api/last-request", { method: "GET" })
      .then(function (r) { if (!r.ok) throw new Error("http " + r.status); return r.json(); })
      .then(function (data) {
        var lr = data && data.lastRequest;
        dot.className = "dlp-dot ok";
        txt.textContent = lr ? ("online · " + lr.platform + "/" + (lr.servedModel || lr.modelId)) : "online · sem requisições";
      })
      .catch(function () {
        dot.className = "dlp-dot bad";
        txt.textContent = "offline";
      });
  }

  function boot() {
    if (!document.body) { setTimeout(boot, 250); return; }
    var style = document.createElement("style");
    style.id = "dlp-style";
    style.textContent = ${JSON.stringify(PANEL_CSS)};
    document.head.appendChild(style);
    build();
    applyShift();
    collectBadges();
    setInterval(collectBadges, 2000);
    setInterval(applyShift, 2000);
    window.addEventListener("resize", applyShift);
    new MutationObserver(function () { applyShift(); }).observe(document.body, { childList: true, subtree: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();`;

// ═══════════════════════════════════════════════════════════════════════════
// CORDIS PLUGIN
// ═══════════════════════════════════════════════════════════════════════════

const layoutPanelPlugin = {
  name: "dsh-layout-panel",

  apply(ctx) {
    // API: últimos arquivos modificados + status (sem credenciais).
    // O host webserver pode ativar DEPOIS do apply deste plugin (que não
    // declara inject) — espera o serviço ficar disponível antes de registrar.
    let tries = 0;
    const waitForWebServer = () => {
      const webServer = ctx.get("webServer");
      if (webServer) {
        ctx.effect(() => {
          const disposers = [
            webServer.register({
              kind: "exact",
              path: "/api/layout-info",
              handler: (_req, res) => {
                res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
                res.end(JSON.stringify(layoutInfoPayload()));
              }
            }),
            // GET /api/layout-file?rel=... → conteúdo do arquivo
            // POST /api/layout-file?rel=... (body JSON {content}) → salva
            webServer.register({
              kind: "exact",
              path: "/api/layout-file",
              handler: (req, res) => {
                const url = new URL(req.url ?? "/", "http://127.0.0.1");
                const rel = url.searchParams.get("rel") ?? "";
                const json = (code, obj) => {
                  res.writeHead(code, { "content-type": "application/json; charset=utf-8" });
                  res.end(JSON.stringify(obj));
                };
                if (req.method === "GET") {
                  const out = readTextFile(rel);
                  json(out.ok ? 200 : 400, out);
                  return;
                }
                if (req.method === "POST") {
                  let body = "";
                  req.on("data", (chunk) => { body += chunk; });
                  req.on("end", () => {
                    let content = "";
                    try { content = JSON.parse(body || "{}").content ?? ""; } catch { content = ""; }
                    const out = writeTextFile(rel, content);
                    json(out.ok ? 200 : 400, out);
                  });
                  return;
                }
                json(405, { error: "método não suportado" });
              }
            }),
            // Assets estáticos do editor (CodeMirror + marked) — prefix route
            webServer.register({
              kind: "exact",
              path: "/dlp-editor-test",
              handler: (_req, res) => {
                res.writeHead(200, { "content-type": "text/plain" });
                res.end("dlp-editor-test ok");
              }
            }),
            webServer.register({
              kind: "prefix",
              path: EDITOR_ASSETS_URL,
              handler: (req, res) => {
                const url = new URL(req.url ?? "/", "http://127.0.0.1");
                const rel = decodeURIComponent(url.pathname.slice(EDITOR_ASSETS_URL.length + 1));
                const full = path.resolve(EDITOR_ASSETS_DIR, rel);
                if (!full.startsWith(EDITOR_ASSETS_DIR + path.sep)) {
                  res.writeHead(403, { "content-type": "text/plain" });
                  res.end("forbidden");
                  return;
                }
                fs.readFile(full, (err, data) => {
                  if (err) {
                    res.writeHead(404, { "content-type": "text/plain" });
                    res.end("not found");
                    return;
                  }
                  res.writeHead(200, { "content-type": MIME[path.extname(full)] ?? "application/octet-stream" });
                  res.end(data);
                });
              }
            })
          ];
          console.log("[LayoutPanel] rotas /api/layout-info, /api/layout-file e /dlp-editor/ registradas");
          return () => { for (const d of disposers) d(); };
        }, "layout-panel: api");
        return;
      }
      if (++tries > 60) {
        console.log("[LayoutPanel] webServer nao ficou disponivel — rota nao registrada");
        return;
      }
      setTimeout(waitForWebServer, 250);
    };
    waitForWebServer();

    // coluna à direita + shift da sessão
    ctx.on("webserver/index-inject", (table) => {
      table.push({ kind: "script", placement: "body", text: PANEL_JS });
    });

    console.log(`[LayoutPanel] coluna direita (${PANEL_WIDTH}px) monitorando ${PANEL_DIR}`);
  }
};

module.exports = layoutPanelPlugin;
module.exports.default = layoutPanelPlugin;
