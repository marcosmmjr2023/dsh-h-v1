/**
 * Model Visibility — filtra o catalogo de modelos no seletor da GUI.
 *
 * O seletor de modelos (dsh-client-ui-model-selection) renderiza os grupos
 * de `session.models` / `llm.models`, que por sua vez sao montados por
 * `buildModelCatalog(ctx)` chamando `ctx.llm.listProviders()` e
 * `ctx.llm.listModels(provider)`. Este plugin:
 *
 *  1. Registra o namespace de settings `model-visibility`:
 *       hiddenProviders: [providerId, ...]      -> esconde o grupo inteiro
 *       hiddenModels:    ["provider/model", ...] -> esconde modelos avulsos
 *     (ex.: "openrouter-pro/anthropic/claude-3-haiku@amazon-bedrock")
 *
 *  2. Faz monkey-patch de `ctx.llm.listModels` para filtrar o que o catalogo
 *     anuncia. Como o `buildModelCatalog` descarta grupos sem modelos, um
 *     provider inteiro oculto some do seletor; um modelo avulso oculto some
 *     do grupo. O `routeServed`/dispatch NAO e tocado: um modelo oculto
 *     continua valido se ja estiver selecionado na sessao.
 *
 *  3. Pagina web `/models` (botao flutuante "Modelos") com checkboxes para
 *     marcar/desmarcar tudo, e API `/api/model-visibility` (GET/POST).
 *
 * O patch de `listModels` roda uma unica vez por instancia de `llm` e
 * preserva o metodo original via closure. A lista de ocultos e lida a cada
 * chamada (dinamico: muda sem restart; vale no proximo turno/render).
 */

"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");

// resolve schemastery + dsh-settings a partir do grafo do CLI instalado
const CANDIDATE_LIBS = [
  process.env.DSH_CLI_LIB,
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/lib/",
  "/usr/lib/node_modules/@deepseek-ai/dsh/lib/",
].filter(Boolean);

let z = null;
let installSettingsSection = null;
for (const lib of CANDIDATE_LIBS) {
  try {
    const requireCli = createRequire(path.join(lib, "index.js"));
    z = requireCli("@deepseek-ai/schemastery");
    ({ installSettingsSection } = requireCli("@deepseek-ai/dsh-settings"));
    break;
  } catch { /* tenta a proxima */ }
}
if (!z || !installSettingsSection) {
  throw new Error("[model-visibility] nao foi possivel carregar schemastery/dsh-settings");
}

const NS = "model-visibility";

const ModelVisibilitySettings = z.object({
  hiddenProviders: z.array(z.string()).default([]),
  hiddenModels: z.array(z.string()).default([])
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGINA WEB (/models)
// ═══════════════════════════════════════════════════════════════════════════

// String.raw: preserva as barras invertidas dos regex do JS embutido (ex.:
// /\$?([\d.]+)\/1M/). Numa template literal comum o Node as consumiria como
// escapes e a pagina serviria um JS quebrado (SyntaxError -> lista vazia).
const PAGE = String.raw`<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Modelos visíveis — DeepSeek Harness</title>
<style>
  :root { --bg:#0d1117; --panel:#161b22; --border:#30363d; --text:#e6edf3; --muted:#8b949e; --accent:#4d6bfe; --green:#3fb950; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .wrap { max-width:900px; margin:0 auto; padding:24px 16px 60px; }
  h1 { font-size:20px; margin:0 0 4px; }
  .sub { color:var(--muted); margin-bottom:20px; }
  .card { background:var(--panel); border:1px solid var(--border); border-radius:10px; padding:16px; margin-bottom:16px; }
  .card h2 { font-size:14px; margin:0 0 10px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); }
  .group { border:1px solid var(--border); border-radius:8px; padding:10px; margin-bottom:10px; background:#0d1117; }
  .groupHead { display:flex; align-items:center; gap:8px; margin-bottom:8px; }
  .groupHead label { font-weight:600; font-size:14px; display:flex; align-items:center; gap:8px; cursor:pointer; }
  .groupHead .count { color:var(--muted); font-size:12px; }
  .models { display:flex; flex-direction:column; gap:4px; padding-left:28px; }
  .model { display:flex; align-items:flex-start; gap:8px; padding:4px 6px; border-radius:6px; }
  .model:hover { background:#161b22; }
  .model label { display:flex; align-items:flex-start; gap:8px; cursor:pointer; flex:1; min-width:0; }
  .model .mname { font:12px ui-monospace,monospace; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .model .desc { color:var(--muted); font-size:11px; line-height:1.45; word-break:break-word; }
  .model input[type=checkbox] { margin-top:2px; flex:none; }
  input[type=checkbox] { accent-color:var(--accent); width:15px; height:15px; }
  .row { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-top:14px; }
  button.save { background:var(--accent); color:#fff; border:0; border-radius:8px; padding:10px 18px; font-size:14px; cursor:pointer; }
  button.save:hover { filter:brightness(1.1); }
  button.ghost { background:transparent; color:var(--muted); border:1px solid var(--border); border-radius:8px; padding:8px 14px; font-size:13px; cursor:pointer; }
  button.ghost:hover { color:var(--text); }
  #msg { font-size:13px; }
  #msg.ok { color:var(--green); } #msg.err { color:#f85149; }
  .foot { color:var(--muted); font-size:12px; margin-top:8px; }
  .muted { color:var(--muted); }
  .filters { display:flex; flex-direction:column; gap:10px; }
  .frow { display:flex; gap:14px; flex-wrap:wrap; align-items:flex-end; }
  .filters label { display:flex; flex-direction:column; gap:4px; font-size:11px; color:var(--muted); }
  .filters input, .filters select { background:#0d1117; color:var(--text); border:1px solid var(--border); border-radius:6px; padding:5px 8px; font:12px system-ui,sans-serif; min-width:120px; }
  .filters input[type=text] { min-width:180px; }
  .intel { color:var(--accent); font-weight:700; }
  .tag-modal { font-size:10px; padding:1px 6px; border-radius:20px; background:#1f3d2b; color:var(--green); margin-left:6px; }
</style>
</head>
<body>
<div class="wrap">
  <p><a href="/" style="color:var(--accent);text-decoration:none;">← Voltar ao app</a> · <a href="/smart-router" style="color:var(--accent);text-decoration:none;">⚡ Roteador</a></p>
  <h1>☑ Modelos visíveis no seletor</h1>
  <p class="sub">Clique no <b>checkbox do grupo (provedor)</b> para marcar/desmarcar <b>todos</b> de uma vez —
     a lista continua visível para você marcar individualmente os que quiser (ex.: deixe só 20 de 137).
     Vale a partir do próximo turno/render. Modelos já selecionados continuam funcionando mesmo ocultos
     (o filtro é só de exibição; o roteador também ignora modelos ocultos).</p>

  <div class="card">
    <h2>Filtros e ordenação</h2>
    <div class="filters">
      <div class="frow">
        <label>Busca
          <input type="text" id="f-search" placeholder="ex.: claude, haiku, 3-haiku…">
        </label>
        <label>Inteligência mín.
          <select id="f-intel"><option value="0">qualquer</option><option value="5">★★★★★ (5)</option><option value="4">★★★★+ (4)</option><option value="3">★★★+ (3)</option><option value="2">★★+ (2)</option><option value="1">★ (1)</option></select>
        </label>
        <label>Estrelas mín.
          <select id="f-stars"><option value="0">qualquer</option><option value="3">★★★</option><option value="2">★★</option><option value="1">★</option></select>
        </label>
        <label>Modalidade
          <select id="f-mode"><option value="">qualquer</option><option value="text">só texto</option><option value="image">aceita imagem</option></select>
        </label>
        <label>Preço máx (input $/1M)
          <input type="number" id="f-price" min="0" step="0.01" placeholder="∞">
        </label>
        <label>TPS mín.
          <input type="number" id="f-tps" min="0" step="5" placeholder="0">
        </label>
        <label>Latência máx (ms)
          <input type="number" id="f-lat" min="0" step="50" placeholder="∞">
        </label>
      </div>
      <div class="frow">
        <label>Ordenar por
          <select id="f-sort">
            <option value="intel">Inteligência (maior)</option>
            <option value="price">Preço (menor)</option>
            <option value="tps">Tokens/s (maior)</option>
            <option value="lat">Latência (menor)</option>
            <option value="name">Nome (A-Z)</option>
          </select>
        </label>
        <label>Mostrar
          <select id="f-vis">
            <option value="all">todos</option>
            <option value="visible">só os marcados</option>
            <option value="hidden">só os ocultos</option>
          </select>
        </label>
        <span id="filterCount" class="muted"></span>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Provedores e modelos</h2>
    <div id="groups"></div>
  </div>

  <div class="row">
    <button class="save" id="save">Salvar</button>
    <button class="ghost" id="all">Marcar todos</button>
    <button class="ghost" id="none">Desmarcar todos</button>
    <span id="msg"></span>
  </div>
  <p class="foot">Config salva em <code>~/.dsh/settings.yaml</code> (namespace <code>model-visibility</code>).
     Para editar manualmente: <code>hiddenProviders</code> (grupos inteiros) e
     <code>hiddenModels</code> (formato <code>provider/model</code>).</p>
</div>

<script>
let state = null;
async function load() {
  const r = await fetch("/api/model-visibility");
  state = await r.json();
  render();
}
function esc(s) { const d = document.createElement("div"); d.textContent = s ?? ""; return d.innerHTML; }
// Renderiza um texto destacando os marcadores de qualidade via DOM (nunca
// innerHTML — evita vazar codigo HTML cru na tela).
function renderMarked(text) {
  const frag = document.createDocumentFragment();
  const push = (t, color, weight) => {
    if (!t) return;
    if (color) {
      const b = document.createElement("b");
      b.textContent = t;
      b.style.color = color;
      b.style.fontWeight = weight || "700";
      frag.appendChild(b);
    } else {
      frag.appendChild(document.createTextNode(t));
    }
  };
  const RULES = [
    ["[evitar]", "#f85149", "700"],
    ["[intermediário]", "#d29922", "600"],
    ["[intermediario]", "#d29922", "600"],
    ["[melhor]", "#3fb950", "700"],
    ["(barato)", "#3fb950", "700"]
  ];
  let rest = text ?? "";
  while (rest.length > 0) {
    let bestIdx = -1, bestRule = null;
    for (const r of RULES) {
      const i = rest.indexOf(r[0]);
      if (i !== -1 && (bestIdx === -1 || i < bestIdx)) { bestIdx = i; bestRule = r; }
    }
    if (bestIdx === -1 || !bestRule) { push(rest); break; }
    push(rest.slice(0, bestIdx));
    push(bestRule[0], bestRule[1], bestRule[2]);
    rest = rest.slice(bestIdx + bestRule[0].length);
  }
  return frag;
}
function isHiddenProvider(p) { return (state.hiddenProviders || []).includes(p); }
function isHiddenModel(entry) { return (state.hiddenModels || []).includes(entry); }
function toggle(entry, hidden) {
  const list = hidden ? (state.hiddenModels ||= []) : (state.hiddenModels ||= []);
  const at = list.indexOf(entry);
  if (hidden && at === -1) list.push(entry);
  if (!hidden && at !== -1) list.splice(at, 1);
}
/** Esconde/mostra TODOS os modelos de um grupo (provider) via hiddenModels. */
function toggleGroup(g, hidden) {
  state.hiddenModels ||= [];
  const hiddenSet = new Set(state.hiddenModels);
  for (const m of (g.models || [])) {
    const entry = g.id + "/" + m.id;
    if (hidden) hiddenSet.add(entry);
    else hiddenSet.delete(entry);
  }
  state.hiddenModels = [...hiddenSet];
}
function groupState(g) {
  const models = g.models || [];
  if (models.length === 0) return "all";
  let visible = 0;
  for (const m of models) if (!isHiddenModel(g.id + "/" + m.id)) visible++;
  if (visible === 0) return "none";
  if (visible === models.length) return "all";
  return "partial";
}
function filters() {
  return {
    search: (document.getElementById("f-search")?.value || "").toLowerCase(),
    intel: +document.getElementById("f-intel")?.value || 0,
    stars: +document.getElementById("f-stars")?.value || 0,
    mode: document.getElementById("f-mode")?.value || "",
    price: parseFloat(document.getElementById("f-price")?.value),
    tps: parseFloat(document.getElementById("f-tps")?.value),
    lat: parseFloat(document.getElementById("f-lat")?.value),
    sort: document.getElementById("f-sort")?.value || "intel",
    vis: document.getElementById("f-vis")?.value || "all"
  };
}
function intelStars(n) { n = n || 0; return "★★★★★".slice(0, n); }
function modalOf(m) {
  const mods = m.modalities || [];
  if (mods.includes("image")) return "image";
  return "text";
}
function descMetrics(m) {
  // extrai preco/tps/latencia da description: "$x/$y/1M", "N tok/s", "lat Nms"
  const d = m.description || "";
  const priceM = d.match(/\$?([\d.]+)\/\$?([\d.]+)\/1M/);
  const tpsM = d.match(/(\d+)\s*tok\/s/);
  const latM = d.match(/lat\s*(\d+)ms/);
  return {
    price: priceM ? +priceM[1] : (m.cost ? m.cost.input : undefined),
    tps: tpsM ? +tpsM[1] : undefined,
    lat: latM ? +latM[1] : undefined
  };
}
function starsOf(m) {
  const n = (m.name || "");
  if (n.startsWith("★★★")) return 3;
  if (n.startsWith("★★")) return 2;
  if (n.startsWith("★")) return 1;
  return 0;
}
function matchesFilters(m, f) {
  if (f.search) {
    const hay = ((m.name || "") + " " + (m.id || "") + " " + (m.description || "")).toLowerCase();
    if (hay.indexOf(f.search) === -1) return false;
  }
  const intel = m.intelligence || 0;
  if (f.intel > 0 && intel < f.intel) return false;
  if (f.stars > 0 && starsOf(m) < f.stars) return false;
  if (f.mode === "image" && modalOf(m) !== "image") return false;
  if (f.mode === "text" && modalOf(m) !== "text") return false;
  const met = descMetrics(m);
  if (f.price > 0 && met.price !== undefined && met.price > f.price) return false;
  if (f.tps > 0 && met.tps !== undefined && met.tps < f.tps) return false;
  if (f.lat > 0 && met.lat !== undefined && met.lat > f.lat) return false;
  if (f.vis === "visible" && isHiddenModel(m.__entry)) return false;
  if (f.vis === "hidden" && !isHiddenModel(m.__entry)) return false;
  return true;
}
function sortKey(m, f) {
  const met = descMetrics(m);
  switch (f.sort) {
    case "price": return met.price !== undefined ? met.price : 1e9;
    case "tps": return met.tps !== undefined ? -met.tps : -1e9;
    case "lat": return met.lat !== undefined ? met.lat : 1e9;
    case "name": return (m.name || m.id || "").toLowerCase();
    default: return -(m.intelligence || 0);
  }
}
function render() {
  const host = document.getElementById("groups");
  host.innerHTML = "";
  const f = filters();
  let totalShown = 0, totalModels = 0;
  const groups = (state.groups || []).map(g => ({
    ...g,
    models: (g.models || []).map(m => ({ ...m, __entry: g.id + "/" + m.id }))
  }));
  for (const g of groups) {
    const gs = groupState(g);
    const visibleCount = g.models.filter((m) => !isHiddenModel(m.__entry)).length;
    // filtra modelos por criterios
    let shown = g.models.filter((m) => matchesFilters(m, f));
    shown.sort((a, b) => {
      const ka = sortKey(a, f), kb = sortKey(b, f);
      if (typeof ka === "string" || typeof kb === "string") return String(ka).localeCompare(String(kb));
      return ka - kb;
    });
    totalModels += g.models.length;
    totalShown += shown.length;
    const box = document.createElement("div");
    box.className = "group";
    const boxEl = document.createElement("div");
    boxEl.className = "groupHead";
    const lbl = document.createElement("label");
    const cbP = document.createElement("input");
    cbP.type = "checkbox";
    cbP.checked = gs !== "none";
    cbP.indeterminate = gs === "partial";
    cbP.onchange = () => {
      toggleGroup(g, !cbP.checked);
      render();
    };
    lbl.append(cbP, document.createTextNode(esc(g.name || g.id)));
    boxEl.appendChild(lbl);
    const cnt = document.createElement("span");
    cnt.className = "count";
    cnt.textContent = visibleCount + "/" + g.models.length + " visíveis · " + shown.length + " na busca";
    boxEl.appendChild(cnt);
    box.appendChild(boxEl);
    const models = document.createElement("div");
    models.className = "models";
    if (shown.length === 0) {
      const empty = document.createElement("div");
      empty.className = "muted";
      empty.style.padding = "4px 6px";
      empty.textContent = "(nenhum modelo com esses filtros)";
      models.appendChild(empty);
    }
    for (const m of shown) {
      const row = document.createElement("div");
      row.className = "model";
      const lblM = document.createElement("label");
      const cbM = document.createElement("input");
      cbM.type = "checkbox";
      cbM.checked = !isHiddenModel(m.__entry);
      cbM.onchange = () => { toggle(m.__entry, !cbM.checked); render(); };
      const col = document.createElement("span");
      col.style.display = "flex";
      col.style.flexDirection = "column";
      col.style.gap = "2px";
      col.style.minWidth = "0";
      const nm = document.createElement("span");
      nm.className = "mname";
      nm.appendChild(renderMarked(m.name || m.id));
      // tag de inteligencia + modalidade
      if (m.intelligence) {
        const i = document.createElement("span");
        i.className = "intel";
        i.textContent = " " + intelStars(m.intelligence);
        nm.appendChild(i);
      }
      if (modalOf(m) === "image") {
        const tg = document.createElement("span");
        tg.className = "tag-modal";
        tg.textContent = "img";
        nm.appendChild(tg);
      }
      col.appendChild(nm);
      if (m.description) {
        const d = document.createElement("span");
        d.className = "desc";
        d.appendChild(renderMarked(m.description));
        col.appendChild(d);
      }
      lblM.append(cbM, col);
      row.appendChild(lblM);
      models.appendChild(row);
    }
    box.appendChild(models);
    host.appendChild(box);
  }
  const fc = document.getElementById("filterCount");
  if (fc) fc.textContent = totalShown + "/" + totalModels + " modelos correspondem aos filtros";
}
function msg(text, ok) { const el = document.getElementById("msg"); el.textContent = text; el.className = ok ? "ok" : "err"; }
document.getElementById("all").onclick = () => { state.hiddenProviders = []; state.hiddenModels = []; render(); };
document.getElementById("none").onclick = () => {
  // desmarca todos os MODELOS (hiddenModels), mantendo as listas visiveis
  state.hiddenProviders = [];
  state.hiddenModels = [];
  for (const g of (state.groups || [])) {
    for (const m of (g.models || [])) {
      state.hiddenModels.push(g.id + "/" + m.id);
    }
  }
  render();
};
document.getElementById("save").onclick = async () => {
  const body = {
    hiddenProviders: state.hiddenProviders || [],
    hiddenModels: state.hiddenModels || []
  };
  const r = await fetch("/api/model-visibility", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  const data = await r.json();
  if (data.ok) { msg("Salvo! Vale a partir do próximo turno.", true); load(); }
  else msg("Erro: " + (data.error || "desconhecido"), false);
};
// filtros: qualquer mudanca re-renderiza
for (const id of ["f-search", "f-intel", "f-stars", "f-mode", "f-price", "f-tps", "f-lat", "f-sort", "f-vis"]) {
  const el = document.getElementById(id);
  if (el) {
    const ev = (id === "f-search" || id === "f-price" || id === "f-tps" || id === "f-lat") ? "input" : "change";
    el.addEventListener(ev, () => render());
  }
}
load();
</script>
</body>
</html>`;

// ═══════════════════════════════════════════════════════════════════════════
// PLUGIN
// ═══════════════════════════════════════════════════════════════════════════

const modelVisibilityPlugin = {
  name: "model-visibility",

  inject: ["llm", "settings"],

  apply(ctx) {
    const llm = ctx.llm;
    let settingsSource = null;
    let patched = false;
    let originalListModels = null;

    installSettingsSection(ctx, NS, ModelVisibilitySettings, {
      hiddenProviders: [],
      hiddenModels: []
    }, {
      setSource: (get) => { settingsSource = get; },
      onChange: () => {}
    });

    function visibility() {
      let s = null;
      try { s = settingsSource ? settingsSource() : null; } catch { s = null; }
      return {
        hiddenProviders: new Set(Array.isArray(s?.hiddenProviders) ? s.hiddenProviders : []),
        hiddenModels: new Set(Array.isArray(s?.hiddenModels) ? s.hiddenModels : [])
      };
    }

    // monkey-patch unico de listModels: filtra o catalogo sem tocar no dispatch.
    function patchListModels() {
      if (patched) return;
      patched = true;
      originalListModels = llm.listModels.bind(llm);
      llm.listModels = async (provider) => {
        const models = await originalListModels(provider);
        const v = visibility();
        if (v.hiddenProviders.has(provider)) return [];
        if (v.hiddenModels.size === 0) return models;
        return models.filter((m) => !v.hiddenModels.has(provider + "/" + m.id));
      };
      console.log("[model-visibility] listModels patcheado (filtro de catalogo ativo)");
    }
    patchListModels();

    // tambem repatacha se o servico for substituido (adapters-updated)
    ctx.on("llm/adapters-updated", () => {
      if (!patched && llm.listModels) patchListModels();
    });

    // ── catalogo completo (para a pagina) ────────────────────────────────
    // Usa o listModels ORIGINAL (sem filtro) para a pagina listar TUDO,
    // incluindo o que esta oculto — e necessario para poder desmarcar.
    // Enriquece cada modelo com metadados do data file do openrouter-enhanced
    // (intelligence, modalities, cost, contextWindow) para os filtros/ordenacao.
    const ENH_DATA_FILE = path.join(__dirname, "openrouter-enhanced-data.json");
    let enhIndex = null; // "provider/id" -> meta
    function enhMetaOf(provider, model) {
      if (enhIndex === null) {
        enhIndex = new Map();
        try {
          const data = JSON.parse(fs.readFileSync(ENH_DATA_FILE, "utf8"));
          const add = (providerId, models) => {
            for (const m of models || []) {
              enhIndex.set(providerId + "/" + m.id, {
                intelligence: m.intelligence,
                input: m.input,
                cost: m.cost,
                contextWindow: m.contextWindow,
                reasoning: !!m.reasoning
              });
            }
          };
          add("openrouter-free", data.freeModels);
          add("openrouter-pro", data.proModels);
        } catch { /* data file ausente: usa apenas o catalogo basico */ }
      }
      return enhIndex.get(provider + "/" + model) || null;
    }
    async function fullCatalog() {
      const groups = [];
      for (const provider of llm.listProviders()) {
        try {
          const models = originalListModels ? await originalListModels(provider.id) : await llm.listModels(provider.id);
          if (models.length === 0) continue;
          groups.push({
            id: provider.id,
            name: provider.name,
            models: models.map((m) => {
              const enh = enhMetaOf(provider.id, m.id);
              let contextWindow;
              try {
                // info do adapter (context) se disponivel; fallback: enh
                const info = llm.resolveModelInfo ? null : null;
                void info;
              } catch { /* ignora */ }
              return {
                id: m.id,
                name: m.name,
                ...m.description === void 0 ? {} : { description: m.description },
                ...m.inputModalities !== void 0 ? { modalities: [...m.inputModalities] } : {},
                ...enh !== null && enh.intelligence !== void 0 ? { intelligence: enh.intelligence } : {},
                ...enh !== null && enh.input !== void 0 ? { modalities: enh.input } : {},
                ...enh !== null && enh.cost !== void 0 ? { cost: enh.cost } : {},
                ...enh !== null && enh.contextWindow !== void 0 ? { contextWindow: enh.contextWindow } : {},
                ...enh !== null && enh.reasoning !== void 0 ? { reasoning: enh.reasoning } : {}
              };
            })
          });
        } catch { /* provider com erro: pula */ }
      }
      return groups;
    }

    // ── web ───────────────────────────────────────────────────────────────
    const webServer = ctx.get("webServer");
    if (webServer) {
      ctx.effect(() => webServer.register({
        kind: "exact",
        path: "/models",
        handler: (_req, res) => {
          res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
          res.end(PAGE);
        }
      }), "model-visibility: page");

      ctx.effect(() => webServer.register({
        kind: "exact",
        path: "/api/model-visibility",
        handler: (req, res) => {
          if (req.method === "POST") {
            let body = "";
            req.on("data", (chunk) => { body += chunk; });
            req.on("end", () => {
              void (async () => {
                try {
                  const patch = JSON.parse(body || "{}");
                  await ctx.settings.update(NS, patch);
                  res.writeHead(200, { "content-type": "application/json" });
                  res.end(JSON.stringify({ ok: true }));
                } catch (error) {
                  res.writeHead(400, { "content-type": "application/json" });
                  res.end(JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
                }
              })();
            });
            return;
          }
          void (async () => {
            try {
              const groups = await fullCatalog();
              let raw = {};
              try { raw = ctx.settings?.get(NS) ?? {}; } catch { raw = {}; }
              res.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
              res.end(JSON.stringify({
                ...raw,
                groups
              }));
            } catch (error) {
              res.writeHead(500, { "content-type": "application/json" });
              res.end(JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
            }
          })();
        }
      }), "model-visibility: api");

      // ── status do modelo em uso (barra inferior) ────────────────────────
      // Retorna o provider/modelo REAL (pos-roteamento) da sessao + custo
      // estimado, para o badge da barra inferior mostrar o que esta servindo.
      ctx.effect(() => webServer.register({
        kind: "exact",
        path: "/api/model-status",
        handler: (req, res) => {
          void (async () => {
            try {
              const url = new URL(req.url ?? "/", "http://x");
              const sessionId = url.searchParams.get("sessionId") || "";
              const agents = ctx.get("agents");
              const agent = agents ? agents.get(sessionId) : undefined;
              const header = agent?.session?.requestHeader?.();
              const config = header?.config;
              if (!config) {
                res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
                res.end(JSON.stringify({ ok: true, active: false }));
                return;
              }
              // custo estimado: cost do data file do openrouter-enhanced (por 1M),
              // com fallback para provedores do harness (deepseek-official, opencode-go)
              const enh = enhMetaOf(config.provider, config.model);
              let cost = enh && enh.cost ? enh.cost : null;
              if (cost == null) {
                // tabela de custo aproximada (USD por 1M tokens), p/ badge
                const FALLBACK_COST = {
                  "deepseek-official/deepseek-v4-flash": { input: 0.27, output: 1.10 },
                  "deepseek-official/deepseek-v4-pro": { input: 1.20, output: 4.00 },
                  "opencode-go/mimo-v2.5": { input: 0.0, output: 0.0 },
                  "opencode-go/mimo-v2": { input: 0.0, output: 0.0 },
                  "opencode-go/deepseek-v4-flash": { input: 0.27, output: 1.10 },
                  "opencode-go-free/mimo-v2.5-free": { input: 0.0, output: 0.0 }
                };
                cost = FALLBACK_COST[config.provider + "/" + config.model] ?? null;
              }
              let contextWindow = enh && enh.contextWindow ? enh.contextWindow : null;
              if (contextWindow == null) {
                try {
                  const info = await ctx.llm.resolveModelInfo(config.provider, config.model);
                  contextWindow = info?.context?.contextWindow ?? null;
                } catch { /* ignora */ }
              }
              res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
              res.end(JSON.stringify({
                ok: true,
                active: true,
                provider: config.provider,
                model: config.model,
                reasoningEffort: config.reasoningEffort ?? null,
                maxTokens: config.maxTokens ?? null,
                contextWindow,
                cost,
                free: cost ? (cost.input === 0 && cost.output === 0) : null,
                sessionId
              }));
            } catch (error) {
              res.writeHead(500, { "content-type": "application/json" });
              res.end(JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
            }
          })();
        }
      }), "model-visibility: model-status");

      // botao flutuante "Modelos" na pagina principal (ao lado do Roteador)
      ctx.on("webserver/index-inject", (table) => {
        table.push({
          kind: "script",
          placement: "body",
          text: `(function(){var css="position:fixed;right:16px;bottom:60px;z-index:2147483647;display:inline-flex;align-items:center;gap:6px;background:#2ea043;color:#fff;border:0;border-radius:20px;padding:9px 16px;font:13px/1 system-ui,sans-serif;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.5);";function add(){if(document.getElementById("mv-btn"))return;var b=document.createElement("button");b.id="mv-btn";b.type="button";b.textContent="\\u2611 Modelos";b.style.cssText=css;b.onclick=function(){location.href="/models";};(document.body||document.documentElement).appendChild(b);}var n=0;var iv=setInterval(function(){if(document.body)add();if(++n>300)clearInterval(iv);},250);})();`
        });
        // pinta nomes de modelo por qualidade no seletor nativo, de forma LEVE:
        // polling curto, restrito a spans DENTRO do popup do seletor (menu),
        // sem MutationObserver global e sem varrer o app inteiro.
        table.push({
          kind: "script",
          placement: "body",
          text: `(function(){
            var GREEN="#3fb950", ORANGE="#d29922", RED="#f85149";
            function insideMenu(el){
              var n=el;
              for(var i=0;i<6&&n;i++,n=n.parentElement){
                if(n.getAttribute&&/menu|popup/i.test(n.getAttribute("class")||""))return true;
              }
              return false;
            }
            function paint(){
              var all=document.querySelectorAll("span");
              for(var i=0;i<all.length;i++){
                var el=all[i];
                if(el.dataset&&el.dataset.mvPainted)continue;
                if(!insideMenu(el))continue;
                var t=(el.textContent||"").trim();
                if(!t||t.length>70)continue;
                if(t.indexOf("★★★")===0){el.style.color=GREEN;el.style.fontWeight="700";if(el.dataset)el.dataset.mvPainted="1";continue;}
                if(t.indexOf("★★")===0){el.style.color=ORANGE;el.style.fontWeight="600";if(el.dataset)el.dataset.mvPainted="1";continue;}
                if(t.indexOf("★")===0){el.style.color=RED;el.style.fontWeight="600";if(el.dataset)el.dataset.mvPainted="1";continue;}
                if(t.indexOf("[melhor]")>=0){el.style.color=GREEN;el.style.fontWeight="700";if(el.dataset)el.dataset.mvPainted="1";continue;}
                if(t.indexOf("[intermedi")>=0){el.style.color=ORANGE;el.style.fontWeight="600";if(el.dataset)el.dataset.mvPainted="1";continue;}
                if(t.indexOf("[evitar]")>=0){el.style.color=RED;el.style.fontWeight="600";if(el.dataset)el.dataset.mvPainted="1";}
              }
            }
            setInterval(paint,700);
          })();`
        });
        // ── badge da barra inferior: mostra o modelo REAL em uso ──────────
        // Consulta /api/model-status (provider/model pos-roteamento) e pinta
        // um badge fixo no canto inferior com modelo, provedor e custo.
        table.push({
          kind: "script",
          placement: "body",
          text: `(function(){
            var css="position:fixed;right:16px;bottom:104px;z-index:2147483647;background:#0d1117;color:#e6edf3;border:1px solid #4d6bfe;border-radius:14px;padding:7px 12px;font:12px/1.45 system-ui,sans-serif;box-shadow:0 4px 14px rgba(0,0,0,.5);max-width:min(240px,30vw);cursor:pointer;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;text-overflow:ellipsis;word-break:break-word;white-space:normal;";
            // O app guarda a sessao ativa em localStorage["dsh.sessions.current"]
            // ({"sessionId":"session-<uuid>"}) — NAO na URL. Le de la primeiro,
            // com fallback para hash/pathname/search (formato antigo).
            function sessionId(){
              try{
                var raw=localStorage.getItem("dsh.sessions.current");
                if(raw){
                  var obj=JSON.parse(raw);
                  if(obj&&obj.sessionId)return obj.sessionId;
                }
                // fallback: qualquer chave de sessao conhecida no localStorage
                for(var i=0;i<localStorage.length;i++){
                  var k=localStorage.key(i);
                  if(k&&/session/i.test(k)){
                    try{
                      var o=JSON.parse(localStorage.getItem(k));
                      if(o&&o.sessionId)return o.sessionId;
                    }catch(e2){}
                  }
                }
              }catch(e){}
              try{
                var m=location.hash.match(/session[sS]?:([a-zA-Z0-9-]+)/)||location.pathname.match(/session[sS]?:([a-zA-Z0-9-]+)/)||location.search.match(/session[sS]?:([a-zA-Z0-9-]+)/);
                return m?m[1]:"";
              }catch(e){return "";}
            }
            function short(p,m){
              var mm=(m||"").split("/").pop()||m;
              return (p||"")+"/"+mm;
            }
            // abre o seletor de modelos da conversa (trigger do picker nativo)
            function openModelPicker(){
              var trig=null;
              var btns=document.querySelectorAll("button");
              for(var i=0;i<btns.length;i++){
                var b=btns[i];
                if(!b||b.disabled)continue;
                var t=(b.textContent||"").toLowerCase();
                // o trigger do picker mostra o modelo atual (contem 'router',
                // 'flash', 'mimo', 'haiku', etc.) e costuma ter chevron
                if(t&&t.length<60&&(/router|flash|mimo|mini|haiku|sonnet|pro|auto|free/.test(t))&&b.querySelector("svg")){trig=b;break;}
              }
              if(!trig){
                // fallback: qualquer botao com svg perto da barra inferior
                var all=document.querySelectorAll("button");
                for(var i=all.length-1;i>=0;i--){
                  if(all[i].querySelector("svg")&&all[i].offsetHeight>0){trig=all[i];break;}
                }
              }
              if(trig){trig.click();}
            }
            function add(){
              if(document.getElementById("mv-status"))return;
              var b=document.createElement("div");b.id="mv-status";b.style.cssText=css;
              b.title="Modelo em uso (provedor/modelo + custo). Clique para abrir o seletor de modelos.";
              b.onclick=openModelPicker;
              (document.body||document.documentElement).appendChild(b);
            }
            // texto completo sempre no tooltip (o ellipsis corta a visao, nao os dados)
            function setTitle(b, txt){
              b.title = (txt||"") + " — clique para abrir o seletor de modelos.";
            }
            function fmtCost(c){
              if(!c)return "";
              if(c.input===0&&c.output===0)return "· grátis";
              var v=c.input*1+c.output*1;
              if(v>=1)return "· $"+v.toFixed(2)+"/1M";
              if(v>=0.001)return "· $"+v.toFixed(4)+"/1M";
              return "· $"+v.toFixed(6)+"/1M";
            }
            var last="";
            function tick(){
              add();
              var b=document.getElementById("mv-status");if(!b)return;
              var sid=sessionId();
              if(!sid){b.textContent="⚡ sem sessão";b.style.opacity=".7";setTitle(b,"Sem sessão ativa");return;}
              fetch("/api/model-status?sessionId="+encodeURIComponent(sid)).then(function(r){return r.json();}).then(function(d){
                if(!d||!d.ok||!d.active){b.textContent="⚡ aguardando…";b.style.opacity=".7";setTitle(b,"Sessão aguardando (sem modelo em uso ainda)");return;}
                var txt="⚡ "+short(d.provider,d.model)+" "+fmtCost(d.cost);
                if(d.free)txt+=" (free)";
                if(d.reasoningEffort)txt+=" · "+d.reasoningEffort;
                if(d.contextWindow)txt+=" · "+(d.contextWindow>=1000000?(d.contextWindow/1000000)+"M":Math.round(d.contextWindow/1000)+"k");
                b.textContent=txt;b.style.opacity="1";
                setTitle(b,"Modelo em uso: "+txt);
                last=txt;
              }).catch(function(){b.textContent=last||"⚡ …";setTitle(b,last||"Erro ao consultar modelo");});
            }
            setInterval(tick,2000);
            setTimeout(tick,500);
          })();`
        });
      });
    }
  }
};

module.exports = modelVisibilityPlugin;
module.exports.default = modelVisibilityPlugin;
