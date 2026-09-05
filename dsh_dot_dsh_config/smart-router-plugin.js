/**
 * Smart Model Router for DeepSeek Harness — v2
 *
 * Comportamento (como pedido pelo usuario):
 *
 *  1. Se o modelo escolhido no PICKER for um modelo concreto (ex.:
 *     "minimax/minimax-m3:free", "deepseek-v4-flash") → usa SOMENTE esse
 *     modelo. Nenhum roteamento.
 *
 *  2. Se o modelo escolhido no PICKER for o provider virtual
 *     "smart-router" (ex.: "smart-router/auto", "smart-router/eco",
 *     "smart-router/ultra") → o roteador entra em acao:
 *       - modo: o sufixo do modelo (eco/normal/balanced/ultra) OU "auto"
 *         para usar o modo configurado no painel /smart-router;
 *       - tier: free | go | plus, decidido pela complexidade da tarefa;
 *       - lista do tier: ordem = preferencia E fallback — se o primeiro
 *         falhar (erro do provider), tenta o proximo da lista
 *         automaticamente (fallback runtime via `agent/request-error`).
 *
 *  3. Cada entrada da lista pode apontar para UM PROVEDOR especifico,
 *     inclusive variantes do OpenRouter (ex.:
 *     "openrouter-pro/anthropic/claude-3-haiku@amazon-bedrock") — isso
 *     permite fallback entre provedores diferentes do OpenRouter.
 *
 *  Default de novas sessoes: o roteador gratuito (smart-router/auto).
 *  O harness salvaria a escolha manual de qualquer sessao como default
 *  (agent-default-model); este plugin intercepta saveSelection para que a
 *  escolha manual valha SO para a sessao atual — novas sessoes iniciam
 *  sempre no roteador. A cadeia gratuita (freellmapi -> openrouter ->
 *  opencode gratuito -> opencode zen/deepseek-v4-flash -> deepseek oficial)
 *  fica em settings.yaml (smart-router) e nos presets abaixo.
 *
 * Correcao critica (v2): o listener `agent/request` agora e registrado com
 * `prepend` para rodar como o listener MAIS EXTERNO do waterfall. O
 * `installModelSelection` do harness (que aplica a selecao da sessao por
 * cima do resultado) roda DENTRO de `next()`, e o SmartRouter — sendo o
 * primeiro da cadeia — tem a palavra final sobre o provider/modelo da
 * chamada real. (Na v1 o roteamento era logado mas sobrescrito pela
 * selecao do picker.)
 *
 * Estrutura do settings (namespace `smart-router` em ~/.dsh/settings.yaml):
 *   mode:    eco | normal | balanced | ultra   (nivel de gasto)
 *   custom:  boolean                           (false = usa o preset do modo)
 *   simple/standard/complex: lista de modelos  (ordem = preferencia/fallback,
 *            formato "provider/model[@reasoningEffort]")
 */

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createRequire } = require("node:module");

// resolve schemastery + dsh-settings a partir do grafo do CLI instalado
const CANDIDATE_LIBS = [
  process.env.DSH_CLI_LIB,
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/lib/",
  "/usr/lib/node_modules/@deepseek-ai/dsh/lib/"
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
  throw new Error("[SmartRouter] nao foi possivel carregar schemastery/dsh-settings");
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER VIRTUAL (aparece no seletor de modelos da GUI)
// ═══════════════════════════════════════════════════════════════════════════════

const ROUTER_PROVIDER = "smart-router";

const ROUTER_MODELS = [
  { id: "auto", name: "⚡ Smart Router (modo do painel)" },
  { id: "eco", name: "⚡ Smart Router (eco)" },
  { id: "normal", name: "⚡ Smart Router (normal)" },
  { id: "balanced", name: "⚡ Smart Router (balanced)" },
  { id: "ultra", name: "⚡ Smart Router (ultra)" }
];

/**
 * Adapter virtual: nunca faz chamadas reais. Existe apenas para o provider
 * "smart-router" aparecer no catalogo/seletor e para a selecao da sessao
 * ser valida. Se por algum motivo o roteamento nao acontecer e a chamada
 * cair aqui, lanca um erro orientativo.
 */
function routerAdapter() {
  return {
    providerInfo(provider) {
      return { id: provider, name: "⚡ Smart Router" };
    },
    providerRetryPolicy() {
      return undefined;
    },
    async listModels(provider) {
      return ROUTER_MODELS.map((m) => ({ provider, id: m.id, name: m.name }));
    },
    async resolveModel(provider, model) {
      const found = ROUTER_MODELS.find((m) => m.id === model) ?? ROUTER_MODELS[0];
      return {
        provider,
        id: model,
        name: found.name,
        context: { contextWindow: 1000000 }
      };
    },
    async prepareCall(provider, model) {
      const info = await this.resolveModel(provider, model);
      return {
        model: info,
        stream: async function* () {
          throw new Error(
            "smart-router: selecione um modelo concreto no picker, ou use smart-router/auto com rotas configuradas no painel ⚡ Roteador"
          );
        }
      };
    }
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRESETS POR MODO
// ═══════════════════════════════════════════════════════════════════════════════

const MODE_IDS = ["eco", "normal", "balanced", "ultra"];
const MODE_DESC = {
  eco: "custo minimo",
  normal: "economia padrao",
  balanced: "equilibrado (custo x capacidade)",
  ultra: "modelos avancados"
};

const DEFAULT_MODES = {
  eco: {
    free: [
      // Cadeia do roteador gratuito (ordem = preferencia E fallback):
      // freellmapi -> openrouter (free) -> opencode gratuito ->
      // opencode pago (zen) com deepseek-v4-flash -> deepseek oficial api
      "freellmapi/auto:fast",
      "openrouter-free/thinkingmachines/inkling:free",
      "openrouter-free/z-ai/glm-5.2:free",
      "openrouter-free/minimax/minimax-m3:free",
      "opencode-go-free/mimo-v2.5-free",
      "opencode-go/deepseek-v4-flash",
      "deepseek-official/deepseek-v4-flash"
    ],
    go: [
      "freellmapi/auto:balanced",
      "opencode-go/deepseek-v4-flash",
      "opencode-go/mimo-v2.5",
      "deepseek-official/deepseek-v4-flash"
    ],
    plus: [
      "freellmapi/auto:smart",
      "deepseek-official/deepseek-v4-pro",
      "opencode-go/deepseek-v4-flash"
    ]
  },
  normal: {
    free: [
      "freellmapi/auto:balanced",
      "openrouter-free/thinkingmachines/inkling:free",
      "openrouter-free/z-ai/glm-5.2:free",
      "opencode-go-free/mimo-v2.5-free",
      "opencode-go/deepseek-v4-flash",
      "deepseek-official/deepseek-v4-flash"
    ],
    go: [
      "opencode-go/deepseek-v4-flash",
      "opencode-go/mimo-v2.5",
      "deepseek-official/deepseek-v4-flash"
    ],
    plus: [
      "deepseek-official/deepseek-v4-pro",
      "opencode-go/deepseek-v4-flash"
    ]
  },
  balanced: {
    free: [
      "freellmapi/auto:balanced",
      "opencode-go-free/mimo-v2.5-free",
      "opencode-go/deepseek-v4-flash",
      "deepseek-official/deepseek-v4-flash"
    ],
    go: [
      "opencode-go/deepseek-v4-flash",
      "opencode-go/mimo-v2.5",
      "deepseek-official/deepseek-v4-flash"
    ],
    plus: [
      "deepseek-official/deepseek-v4-pro",
      "opencode-go/deepseek-v4-flash"
    ]
  },
  ultra: {
    free: [
      "freellmapi/auto:smart",
      "opencode-go/deepseek-v4-flash",
      "deepseek-official/deepseek-v4-flash"
    ],
    go: [
      "opencode-go/mimo-v2.5",
      "opencode-go/deepseek-v4-flash",
      "deepseek-official/deepseek-v4-flash"
    ],
    plus: [
      "deepseek-official/deepseek-v4-pro"
    ]
  }
};

const DEFAULT_THRESHOLDS = {
  simple: {
    maxMessageLength: 500,
    keywords: ["oi", "tudo bem", "ajuda", "obrigado", "hello", "hi", "thanks", "help",
               "what is", "o que é", "o que e", "define", "explain briefly", "resuma"]
  },
  complex: {
    minMessageLength: 1000,
    keywords: ["implemente", "implementar", "implement", "crie", "criar", "create",
               "construa", "build", "refatore", "refactor", "otimize", "optimize",
               "arquitetura", "architecture", "design", "padrão", "padrao", "pattern",
               "algoritmo", "algorithm", "complexo", "complex", "avançado", "avancado",
               "advanced", "debug", "refatorar", "escreva um codigo", "desenvolva",
               "microserviços", "microservicos"],
    codeIndicators: ["```", "function", "class", "import", "export", "async", "await",
                     "const ", "let ", "=>", "return"]
  }
};

const TIER_OF = { simple: "free", standard: "go", complex: "plus" };
const TIER_KEYS = { free: "simple", go: "standard", plus: "complex" };

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEMA DE SETTINGS (renderizado na GUI)
// ═══════════════════════════════════════════════════════════════════════════════

const SmartRouterSettings = z.object({
  mode: z.union(MODE_IDS).default("balanced"),
  custom: z.boolean().default(false),
  simple: z.array(z.string()).default([]),
  standard: z.array(z.string()).default([]),
  complex: z.array(z.string()).default([])
});

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/** Texto simples dos blocos de conteudo de uma mensagem. */
function textOf(blocks) {
  if (typeof blocks === "string") return blocks;
  if (!Array.isArray(blocks)) return "";
  return blocks.filter((b) => b?.type === "text").map((b) => b.text).join("");
}

/** "provider/model[@effort]" -> {provider, model, reasoningEffort?}
 *  IMPORTANTE: o "@" so e tratado como effort quando o sufixo for um effort
 *  conhecido (off/low/medium/high/minimal). Variantes do OpenRouter como
 *  "anthropic/claude-3-haiku@amazon-bedrock" tem "@provedor" no MODEL ID e
 *  NAO podem ser confundidas com effort. */
const KNOWN_EFFORTS = new Set(["off", "low", "medium", "high", "minimal"]);
function parseModelEntry(entry) {
  if (typeof entry !== "string") return null;
  const slash = entry.indexOf("/");
  if (slash <= 0) return null;
  const provider = entry.slice(0, slash);
  let model = entry.slice(slash + 1);
  if (!provider || !model) return null;
  let reasoningEffort;
  const at = model.lastIndexOf("@");
  if (at > 0 && KNOWN_EFFORTS.has(model.slice(at + 1))) {
    reasoningEffort = model.slice(at + 1);
    model = model.slice(0, at);
  }
  return { provider, model, ...(reasoningEffort ? { reasoningEffort } : {}) };
}

/** Analisa a conversa e devolve o tier (free | go | plus). */
function analyzeComplexity(thresholds, messages) {
  let score = 0;
  const list = Array.isArray(messages) ? messages : [];

  let lastUser = null;
  for (let i = list.length - 1; i >= 0; i--) {
    if (list[i].role === "user") { lastUser = list[i]; break; }
  }
  const content = lastUser ? (typeof lastUser.content === "string" ? lastUser.content : textOf(lastUser.content)) : "";
  const lower = content.toLowerCase();

  if (content.length < thresholds.simple.maxMessageLength) score -= 2;
  else if (content.length > thresholds.complex.minMessageLength) score += 3;

  const simpleMatches = thresholds.simple.keywords.filter((kw) => lower.includes(kw));
  if (simpleMatches.length > 0) score -= 2;

  const complexMatches = thresholds.complex.keywords.filter((kw) => lower.includes(kw));
  if (complexMatches.length > 0) score += 2 * complexMatches.length;

  const codeMatches = thresholds.complex.codeIndicators.filter((ind) => lower.includes(ind));
  if (codeMatches.length > 0) score += codeMatches.length;

  if ((lower.match(/\?/g) || []).length > 2) score += 2;

  if (list.length > 20) score += 2;
  else if (list.length < 3) score -= 1;

  return { score, tier: score <= -2 ? "free" : score >= 5 ? "plus" : "go" };
}

/** Deriva as mensagens {role, content} da sessao (ignora contexto de runtime). */
function deriveMessages(agent) {
  const messages = [];
  for (const event of agent?.session?.events ?? []) {
    if (event?.type === "user/message") {
      const sourceKind = event.data?.source?.kind ?? event.data?.message?.source?.kind;
      if (sourceKind !== "user") continue;
      const text = textOf(event.data?.content ?? event.data?.message?.content);
      if (text) messages.push({ role: "user", content: text });
    } else if (event?.type === "assistant/message") {
      const text = textOf(event.data?.message?.content ?? event.data?.content);
      if (text) messages.push({ role: "assistant", content: text });
    }
  }
  return messages;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GUI WEB (pagina /smart-router)
// ═══════════════════════════════════════════════════════════════════════════════

const SMART_ROUTER_PAGE = `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Smart Router — DeepSeek Harness</title>
<style>
  :root { --bg:#0d1117; --panel:#161b22; --border:#30363d; --text:#e6edf3; --muted:#8b949e; --accent:#4d6bfe; --green:#3fb950; --yellow:#d29922; --red:#f85149; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .wrap { max-width:980px; margin:0 auto; padding:24px 16px 60px; }
  h1 { font-size:20px; margin:0 0 4px; }
  .sub { color:var(--muted); margin-bottom:20px; }
  .card { background:var(--panel); border:1px solid var(--border); border-radius:10px; padding:16px; margin-bottom:16px; }
  .card h2 { font-size:14px; margin:0 0 10px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); }
  .modes { display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr)); gap:8px; }
  .mode { border:1px solid var(--border); border-radius:8px; padding:10px; cursor:pointer; background:transparent; color:var(--text); text-align:left; }
  .mode.active { border-color:var(--accent); box-shadow:0 0 0 1px var(--accent) inset; }
  .mode b { display:block; font-size:14px; }
  .mode small { color:var(--muted); }
  .mode .badge { display:inline-block; margin-top:6px; font-size:11px; padding:1px 6px; border-radius:20px; background:var(--accent); color:#fff; }
  label.tier { display:block; margin-bottom:14px; }
  label.tier span { display:flex; justify-content:space-between; font-weight:600; }
  label.tier span small { color:var(--muted); font-weight:400; }
  textarea { width:100%; min-height:64px; margin-top:6px; background:#0d1117; color:var(--text); border:1px solid var(--border); border-radius:6px; padding:8px; font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace; }
  textarea:disabled { opacity:.5; }
  .hint { color:var(--muted); font-size:12px; }
  .switch { display:flex; align-items:center; gap:8px; margin-bottom:12px; cursor:pointer; }
  .row { display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
  button.save { background:var(--accent); color:#fff; border:0; border-radius:8px; padding:10px 18px; font-size:14px; cursor:pointer; }
  button.save:hover { filter:brightness(1.1); }
  #msg { font-size:13px; }
  #msg.ok { color:var(--green); } #msg.err { color:#f85149; }
  .models { display:flex; flex-wrap:wrap; gap:6px; }
  .models span { background:#21262d; border:1px solid var(--border); border-radius:20px; padding:2px 10px; font:12px ui-monospace,monospace; }
  code { background:#21262d; border-radius:4px; padding:1px 5px; font:12px ui-monospace,monospace; }
  .foot { color:var(--muted); font-size:12px; margin-top:8px; }
  .tierBox { border:1px solid var(--border); border-radius:8px; padding:10px; margin-bottom:10px; background:#0d1117; }
  .tierBox h4 { margin:0 0 6px; font-size:13px; display:flex; justify-content:space-between; align-items:center; }
  .tierBox h4 small { color:var(--muted); font-weight:400; font-size:11px; }
  .pickerRow { display:flex; gap:6px; margin-bottom:8px; flex-wrap:wrap; }
  .pickerRow select { flex:1; min-width:140px; background:#161b22; color:var(--text); border:1px solid var(--border); border-radius:6px; padding:5px 8px; font:12px ui-monospace,monospace; }
  .pickerRow button { background:var(--accent); color:#fff; border:0; border-radius:6px; padding:5px 12px; font-size:12px; cursor:pointer; }
  .pickerRow button:hover { filter:brightness(1.15); }
  .chipRow { display:flex; flex-wrap:wrap; gap:6px; margin-bottom:8px; }
  .chip { display:inline-flex; align-items:center; gap:6px; background:#21262d; border:1px solid var(--border); border-radius:20px; padding:3px 10px; font:12px ui-monospace,monospace; }
  .chip .n { color:var(--muted); }
  .chip .x { color:var(--muted); cursor:pointer; padding:0 2px; font-weight:700; }
  .chip .x:hover { color:var(--red); }
  .chip .up, .chip .down { cursor:pointer; color:var(--muted); padding:0 2px; }
  .chip .up:hover, .chip .down:hover { color:var(--accent); }
  .muted { color:var(--muted); }
</style>
</head>
<body>
<div class="wrap">
  <p><a href="/" style="color:var(--accent);text-decoration:none;">← Voltar ao app</a></p>
  <h1>⚡ Roteador Inteligente de Modelos</h1>
  <p class="sub">O <b>Smart Router</b> só age quando o modelo do seletor da conversa for <code>smart-router/…</code>.
     Modelos concretos escolhidos no seletor <b>nunca</b> são roteados (vence o modelo escolhido).
     Cada lista abaixo é uma <b>cadeia de fallback</b>: o roteador tenta o primeiro da lista; se falhar, tenta o próximo.
     Você pode misturar provedores e modelos livremente (ex.: variantes do OpenRouter com provedor fixo).</p>

  <div class="card">
    <h2>Modo de gasto</h2>
    <div class="modes" id="modes"></div>
  </div>

  <div class="card">
    <h2>Modelos por categoria</h2>
    <p class="hint">Cada lista tem <b>um modelo por linha, na ordem de preferência (fallback)</b>.
       Se um modelo/provedor falhar ou não estiver disponível, o próximo da lista é usado.
       Formato: <code>provider/model</code> (ex.: <code>opencode-go/mimo-v2.5</code>).
       Para fixar provedor no OpenRouter use as variantes (ex.: <code>openrouter-pro/anthropic/claude-3-haiku@amazon-bedrock</code>).
       Opcional: <code>provider/model@high</code> para fixar o esforço de raciocínio.</p>
    <label class="switch"><input type="checkbox" id="custom"> <span>Personalizar modelos do modo ativo (desmarque para usar os padrões do modo)</span></label>
    <div id="tier-pickers"></div>
  </div>

  <div class="card">
    <h2>Provedores e modelos disponíveis</h2>
    <div id="available" class="models"></div>
    <p class="foot">Só aparecem aqui os provedores configurados e com credencial. O roteador ignora modelos que não existam no provedor.</p>
  </div>

  <div class="row">
    <button class="save" id="save">Salvar configuração</button>
    <span id="msg"></span>
  </div>
  <p class="foot">As mudanças valem a partir do próximo turno. Config salva em <code>~/.dsh/settings.yaml</code> (namespace <code>smart-router</code>).</p>
</div>

<script>
const MODES = [
  { id:"eco", label:"Eco", desc:"custo mínimo", badge:"mais barato" },
  { id:"normal", label:"Normal", desc:"economia padrão", badge:"" },
  { id:"balanced", label:"Balanced", desc:"equilibrado", badge:"padrão" },
  { id:"ultra", label:"Ultra", desc:"modelos avançados", badge:"maior capacidade" }
];
const TIERS = [
  { key:"simple",   tier:"free",  label:"Simples",  hint:"perguntas rápidas, conversa" },
  { key:"standard", tier:"go",    label:"Padrão",   hint:"código moderado, tarefas comuns" },
  { key:"complex",  tier:"plus",  label:"Complexo", hint:"arquitetura, refactor, debug, problemas difíceis" }
];
let state = null;

async function load() {
  const r = await fetch("/api/smart-router");
  state = await r.json();
  render();
}
function esc(s) { const d = document.createElement("div"); d.textContent = s ?? ""; return d.innerHTML; }
function listFor(t) {
  if (state.custom) return state[t.key] || [];
  return (state.lists || {})[t.tier] || [];
}
function providers() { return (state.available || []).filter(p => p !== "smart-router"); }
function modelsOf(p) { return (state.models || {})[p] || []; }
function renderTiers() {
  const host = document.getElementById("tier-pickers");
  host.innerHTML = "";
  for (const t of TIERS) {
    const box = document.createElement("div");
    box.className = "tierBox";
    box.innerHTML = "<h4>" + esc(t.label) + " <small>" + esc(t.hint) + " — ordem = fallback</small></h4>";
    const picker = document.createElement("div");
    picker.className = "pickerRow";
    const provSel = document.createElement("select");
    provSel.innerHTML = "<option value=''>— provedor —</option>";
    for (const p of providers()) {
      provSel.innerHTML += "<option value='" + esc(p) + "'>" + esc(p) + " (" + modelsOf(p).length + ")</option>";
    }
    const modelSel = document.createElement("select");
    modelSel.innerHTML = "<option value=''>— modelo —</option>";
    const addBtn = document.createElement("button");
    addBtn.textContent = "＋ Adicionar";
    provSel.onchange = () => {
      const p = provSel.value;
      modelSel.innerHTML = "<option value=''>— modelo —</option>";
      for (const m of modelsOf(p)) modelSel.innerHTML += "<option value='" + esc(m) + "'>" + esc(m) + "</option>";
    };
    addBtn.onclick = () => {
      const p = provSel.value, m = modelSel.value;
      if (!p || !m) return;
      const entry = p + "/" + m;
      const list = listFor(t);
      if (!list.includes(entry)) { list.push(entry); render(); }
    };
    picker.append(provSel, modelSel, addBtn);
    box.appendChild(picker);

    const chips = document.createElement("div");
    chips.className = "chipRow";
    const list = listFor(t);
    if (list.length === 0) {
      const empty = document.createElement("span");
      empty.className = "muted";
      empty.textContent = "(vazio — usa o preset do modo)";
      chips.appendChild(empty);
    }
    list.forEach((entry, i) => {
      const chip = document.createElement("span");
      chip.className = "chip";
      chip.innerHTML = "<span class='n'>" + (i + 1) + ".</span><span>" + esc(entry) + "</span>" +
        "<span class='up'>↑</span><span class='down'>↓</span><span class='x'>✕</span>";
      chip.querySelector(".up").onclick = () => { if (i > 0) { const l = listFor(t); const tmp = l[i - 1]; l[i - 1] = l[i]; l[i] = tmp; render(); } };
      chip.querySelector(".down").onclick = () => { if (i < list.length - 1) { const l = listFor(t); const tmp = l[i + 1]; l[i + 1] = l[i]; l[i] = tmp; render(); } };
      chip.querySelector(".x").onclick = () => { listFor(t).splice(i, 1); render(); };
      chips.appendChild(chip);
    });
    box.appendChild(chips);
    host.appendChild(box);
  }
}
function render() {
  const modesEl = document.getElementById("modes");
  modesEl.innerHTML = "";
  for (const m of MODES) {
    const b = document.createElement("button");
    b.className = "mode" + (m.id === state.mode ? " active" : "");
    b.innerHTML = "<b>" + m.label + "</b><small>" + (m.desc) + "</small>" + (m.badge ? "<span class='badge'>" + m.badge + "</span>" : "");
    b.onclick = () => { state.mode = m.id; render(); };
    modesEl.appendChild(b);
  }
  document.getElementById("custom").checked = !!state.custom;
  renderTiers();
  const avail = document.getElementById("available");
  avail.innerHTML = "";
  for (const provider of providers()) {
    const span = document.createElement("span");
    span.textContent = provider + ": " + ((state.models || {})[provider] || []).join(", ");
    avail.appendChild(span);
  }
}
function msg(text, ok) {
  const el = document.getElementById("msg");
  el.textContent = text;
  el.className = ok ? "ok" : "err";
}
document.getElementById("custom").onchange = () => {
  state.custom = document.getElementById("custom").checked;
  render();
};
document.getElementById("save").onclick = async () => {
  const body = {
    mode: state.mode,
    custom: state.custom,
    simple: listFor(TIERS[0]),
    standard: listFor(TIERS[1]),
    complex: listFor(TIERS[2])
  };
  const r = await fetch("/api/smart-router", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  const data = await r.json();
  if (data.ok) { msg("Salvo! Vai valer a partir do próximo turno.", true); load(); }
  else msg("Erro: " + (data.error || "desconhecido"), false);
};
load();
</script>
</body>
</html>`;

// ═══════════════════════════════════════════════════════════════════════════════
// CORDIS PLUGIN
// ═══════════════════════════════════════════════════════════════════════════════

const smartRouterPlugin = {
  name: "smart-model-router",

  inject: ["llm", "settings"],

  apply(ctx) {
    const llm = ctx.llm;
    let availCache = new Set();
    let modelCache = new Map(); // provider -> Set(modelId)
    let settingsSource = null;

    // registra o namespace na GUI/arquivo de settings
    installSettingsSection(ctx, "smart-router", SmartRouterSettings, {
      mode: "balanced",
      custom: false,
      simple: [],
      standard: [],
      complex: []
    }, {
      setSource: (get) => { settingsSource = get; },
      onChange: () => {}
    });

    // ── Provider virtual "smart-router" no seletor de modelos ─────────────
    try {
      llm.registerAdapter([ROUTER_PROVIDER], routerAdapter());
      console.log(`[SmartRouter] provider virtual "${ROUTER_PROVIDER}" registrado (aparece no seletor de modelos)`);
    } catch (error) {
      console.log(`[SmartRouter] aviso ao registrar provider virtual: ${error?.message ?? error}`);
    }

    // ── Default protegido: novas sessoes SEMPRE iniciam no roteador gratuito ──
    // O harness salva a escolha manual de QUALQUER sessao como default
    // (agent-default-model -> settings.yaml), entao a proxima sessao nova
    // herdava o ultimo modelo usado. Aqui interceptamos saveSelection para que
    // a escolha manual valha SOMENTE para a sessao atual; o default permanece
    // smart-router/auto (definido em settings.yaml).
    try {
      const agentDefaultModel = ctx.get("agentDefaultModel");
      if (agentDefaultModel && typeof agentDefaultModel.saveSelection === "function") {
        agentDefaultModel.saveSelection = async () => {
          console.log("[SmartRouter] escolha manual de modelo NAO vira default — novas sessoes iniciam no roteador gratuito (smart-router/auto)");
        };
      }
    } catch (error) {
      console.log(`[SmartRouter] aviso ao proteger o default: ${error?.message ?? error}`);
    }

    const refreshAvailable = async () => {
      try { availCache = new Set(llm.listProviders().map((p) => p.id)); } catch { availCache = new Set(); }
      for (const provider of availCache) {
        if (provider === ROUTER_PROVIDER) continue;
        try {
          const models = await llm.listModels(provider);
          modelCache.set(provider, new Set(models.map((m) => m.id)));
        } catch { modelCache.set(provider, new Set()); }
      }
    };
    void refreshAvailable();
    ctx.on("llm/adapters-updated", () => void refreshAvailable());

    /** Config efetiva: presets do modo OU listas customizadas. */
    function effectiveConfig() {
      let s = null;
      try { s = settingsSource ? settingsSource() : null; } catch { s = null; }
      const mode = s && MODE_IDS.includes(s.mode) ? s.mode : "balanced";
      if (s && s.custom === true) {
        const lists = {};
        if (Array.isArray(s.simple) && s.simple.length > 0) lists.free = s.simple;
        if (Array.isArray(s.standard) && s.standard.length > 0) lists.go = s.standard;
        if (Array.isArray(s.complex) && s.complex.length > 0) lists.plus = s.complex;
        if (Object.keys(lists).length > 0) return { mode, lists, custom: true };
      }
      return { mode, lists: DEFAULT_MODES[mode] ?? DEFAULT_MODES.balanced, custom: false };
    }

    /** Lista do tier no formato settings (chave custom: simple/standard/complex). */
    function tierListFor(cfg, tier) {
      if (cfg.custom) {
        const key = TIER_KEYS[tier];
        const list = cfg.lists?.[tier] ?? [];
        return list.length > 0 ? list : null;
      }
      return null;
    }

    /**
     * Resolve a cadeia de candidatos do tier: todas as entradas da lista cujo
     * provider esta disponivel E o modelo existe. A ORDEM preservada = ordem
     * de preferencia/fallback.
     */
    function resolveCandidates(tier, cfg) {
      const list = tierListFor(cfg, tier) ?? cfg.lists?.[tier] ?? [];
      const out = [];
      for (const entry of list) {
        const target = parseModelEntry(entry);
        if (!target) continue;
        // meta-router "openrouter/free" escolhe modelos aleatorios (sem cache
        // hit e com limites de saida imprevisiveis) — usar free individuais.
        if (target.provider === "openrouter-free" && (target.model === "openrouter/free" || target.model === "auto")) continue;
        if (!availCache.has(target.provider)) continue;
        const models = modelCache.get(target.provider);
        if (!models || !models.has(target.model)) continue;
        out.push(target);
      }
      return out;
    }

    /**
     * Estado de fallback por agente: guarda a cadeia de candidatos do turno
     * atual e o indice do candidato em uso, para o `agent/request-error`
     * avancar para o proximo quando o atual falhar. Tambem guarda o modo
     * "bigContext" (CONTEXT_WINDOW_EXCEEDED): quando ativado, o proximo
     * request usa o modelo de MAIOR contexto disponivel, ignorando a
     * escolha concreta do picker.
     */
    const fallbackByAgent = new WeakMap();

    /** Maior contextWindow entre todos os modelos anunciados (cache). */
    const bigContextCache = new Map(); // "provider/model" -> contextWindow

    async function contextWindowOf(provider, model) {
      const key = `${provider}/${model}`;
      if (bigContextCache.has(key)) return bigContextCache.get(key);
      let cw = null;
      try {
        const info = await ctx.llm.resolveModelInfo(provider, model);
        cw = info?.context?.contextWindow ?? null;
      } catch { cw = null; }
      bigContextCache.set(key, cw);
      return cw;
    }

    /** Limite real de saida (defaultMaxTokens) de um modelo, com cache. */
    const maxTokensCache = new Map(); // "provider/model" -> defaultMaxTokens|null
    async function maxTokensOf(provider, model) {
      const key = `${provider}/${model}`;
      if (maxTokensCache.has(key)) return maxTokensCache.get(key);
      let mt = null;
      try {
        const info = await ctx.llm.resolveModelInfo(provider, model);
        mt = info?.defaultMaxTokens ?? null;
      } catch { mt = null; }
      maxTokensCache.set(key, mt);
      return mt;
    }

    /**
     * Busca um modelo de contexto grande e BARATO para o fallback por
     * contexto (resumir/caber a conversa). Usa SOMENTE uma whitelist de
     * modelos conhecidos e baratos — nunca o provider openrouter (Auto
     * Router e modelos imprevisiveis roteiam para modelos caros como
     * Claude Sonnet 5, que foi a causa de ~US$8 de gasto).
     */
    const BIGCTX_PREFERRED = [
      ["opencode-go", "mimo-v2.5"],
      ["opencode-go", "mimo-v2"],
      ["deepseek-official", "deepseek-v4-flash"],
      ["opencode-go", "deepseek-v4-flash"]
    ];
    /** Providers que o fallback automatico NUNCA usa (podem ser caros). */
    const BIGCTX_FORBIDDEN_PROVIDERS = new Set([
      "openrouter",
      "openrouter-free",
      "openrouter-pro"
    ]);
    async function resolveBigContextTarget() {
      // Somente a whitelist de modelos baratos com contexto grande
      for (const [provider, model] of BIGCTX_PREFERRED) {
        if (BIGCTX_FORBIDDEN_PROVIDERS.has(provider)) continue;
        if (!availCache.has(provider)) continue;
        const models = modelCache.get(provider);
        if (!models || !models.has(model)) continue;
        const cw = await contextWindowOf(provider, model);
        if (cw != null && cw >= 262144) return { provider, model, contextWindow: cw };
      }
      // Nenhum barato disponivel: NAO cai em modelo caro — retorna null e o
      // turno mantem o modelo original (o erro de contexto sobe ao inves de gastar).
      return null;
    }

    function installForAgent(agent) {
      const agentCtx = agent?.ctx;
      if (!agentCtx) return;

      const fb = { turnStep: null, candidates: [], index: 0, bigContext: false, overflowCount: 0 };
      fallbackByAgent.set(agent, fb);

      // ── agent/request: COM prepend = listener mais externo ─────────────
      // Correcao v2: roda ANTES do installModelSelection (que aplica a
      // selecao da sessao dentro de next()), entao a decisao AQUI tem a
      // palavra final sobre provider/modelo da chamada real.
      agentCtx.on("agent/request", async (payload, next) => {
        const resolved = await next();
        try {
          // ── modo bigContext (apos CONTEXT_WINDOW_EXCEEDED) ──────────────
          // Ignora a escolha concreta do picker e usa o modelo de maior
          // contexto disponivel, para a sessao voltar a caber.
          if (fb.bigContext) {
            const big = await resolveBigContextTarget();
            if (big && (big.provider !== resolved.provider || big.model !== resolved.model)) {
              console.log(`[SmartRouter] bigContext: ${resolved.provider}/${resolved.model} (contexto insuficiente) -> ${big.provider}/${big.model} (ctx ${big.contextWindow})`);
              fb.bigContext = false;
              fb.overflowCount = 0;
              return { ...resolved, provider: big.provider, model: big.model };
            }
            fb.bigContext = false;
            fb.overflowCount = 0;
            return resolved;
          }

          // modelo concreto escolhido no picker → usa SOMENTE ele (sem rotear)
          if (resolved.provider !== ROUTER_PROVIDER) {
            fb.candidates = [];
            fb.index = 0;
            return resolved;
          }

          // modo: sufixo do modelo sentinela OU "auto" → modo das settings
          const cfg = effectiveConfig();

          // ── Refresh sob demanda do cache de provedores/modelos ──────────
          // No boot (headless/rapido), o adapter de um provider recem-adicionado
          // (ex.: freellmapi) pode registrar DEPOIS do mount do plugin, deixando
          // availCache/modelCache sem ele e o turno caindo no fallback errado.
          // Se alguma entrada das listas aponta para um provider fora do cache,
          // atualiza ANTES de decidir — barato e so ocorre quando falta algo.
          {
            const listed = [...(cfg.lists?.free ?? []), ...(cfg.lists?.go ?? []), ...(cfg.lists?.plus ?? [])];
            const stale = listed.some((entry) => {
              const t = parseModelEntry(entry);
              return t && !availCache.has(t.provider);
            });
            if (stale) await refreshAvailable();
          }

          const sentinelMode = resolved.model;
          const mode = sentinelMode && MODE_IDS.includes(sentinelMode) ? sentinelMode : cfg.mode;

          const messages = deriveMessages(agent);
          const analysis = analyzeComplexity(DEFAULT_THRESHOLDS, messages);
          const tier = analysis.tier;

          // ── Pre-estimativa de contexto: mede a sessao ANTES de escolher ──
          // Evita estourar o limite no meio do turno: so escolhe modelos
          // cujo contextWindow caiba na sessao (com margem de seguranca).
          let sessionTokens = null;
          try {
            const meter = ctx.get("tokenMeter");
            if (meter) {
              const m = meter.measure(agent.session);
              if (m && typeof m.totalTokens === "number") sessionTokens = m.totalTokens;
            }
          } catch { /* sem meter */ }
          if (sessionTokens == null) {
            // fallback: estimativa grosseira por caracteres
            let chars = 0;
            for (const msg of messages) chars += String(msg.content || "").length;
            sessionTokens = Math.ceil(chars / 3.5) + 1200;
          }
          const margin = 4096; // folga para tool results + system + output
          const fits = async (target) => {
            if (sessionTokens == null) return true;
            const cw = await contextWindowOf(target.provider, target.model);
            if (cw == null) return true; // sem info de contexto: assume que cabe
            return sessionTokens + margin <= cw;
          };

          const candidates = resolveCandidates(tier, cfg);
          const turnStep = `${payload?.turn}:${payload?.step}`;
          if (fb.turnStep !== turnStep) {
            fb.turnStep = turnStep;
            fb.index = 0;
          }
          fb.candidates = candidates;

          // filtro por contexto: mantem so os que cabem na sessao
          const fitting = [];
          for (const c of candidates) if (await fits(c)) fitting.push(c);
          fb.candidates = fitting;

          // continuidade (cache hit): se o modelo do request anterior ainda
          // e candidato e cabe, prefere-lo em vez de trocar a cada turno
          const prevHeader = agent.session?.requestHeader?.()?.config;
          let continuityIdx = -1;
          if (prevHeader && prevHeader.provider !== ROUTER_PROVIDER) {
            continuityIdx = fitting.findIndex((c) => c.provider === prevHeader.provider && c.model === prevHeader.model);
          }
          const startIdx = continuityIdx >= 0 ? continuityIdx : Math.min(fb.index, Math.max(0, fitting.length - 1));
          fb.index = startIdx;

          let target = fitting[fb.index] ?? null;
          // se NENHUM candidato do tier cabe, ja cai no bigContext barato
          // (pre-estimado, sem esperar o erro do provider)
          if (!target && sessionTokens != null) {
            const big = await resolveBigContextTarget();
            if (big && (big.provider !== resolved.provider || big.model !== resolved.model)) {
              console.log(`[SmartRouter] ${mode}/${tier} (score ${analysis.score}): sessao ~${Math.round(sessionTokens/1000)}k tokens nao cabe em nenhum da lista -> bigContext ${big.provider}/${big.model} (ctx ${big.contextWindow})`);
              fb.candidates = [big];
              fb.index = 0;
              return { ...resolved, provider: big.provider, model: big.model };
            }
          }
          if (!target) {
            console.log(`[SmartRouter] ${mode}/${tier} (score ${analysis.score}): nenhum modelo disponivel na lista "${tier}" -> mantem selecionado`);
            return resolved;
          }
          if (target.provider !== resolved.provider || target.model !== resolved.model) {
            const routed = {
              ...resolved,
              provider: target.provider,
              model: target.model,
              // Free models do OpenRouter: usa o limite REAL de saida do
              // modelo (defaultMaxTokens) com teto prudente de 16384 — o
              // agente raramente precisa de mais, e evita estourar backend
              // instavel. Sem esse limite, alguns free cortam no meio.
              ...(target.provider === "openrouter-free"
                ? { maxTokens: Math.min(await maxTokensOf(target.provider, target.model) || 8192, 16384) }
                : {}),
              ...(target.reasoningEffort !== void 0 ? { reasoningEffort: target.reasoningEffort } : {})
            };
            const cont = continuityIdx >= 0 ? " [cache-hit]" : "";
            console.log(`[SmartRouter] ${mode}/${tier} (score ${analysis.score}) [${fb.index}/${fitting.length}]${cont}: ${resolved.provider}/${resolved.model} -> ${target.provider}/${target.model} (sessao ~${Math.round((sessionTokens||0)/1000)}k tok)`);
            return routed;
          }
          console.log(`[SmartRouter] ${mode}/${tier} (score ${analysis.score}): mantem ${resolved.provider}/${resolved.model} (sessao ~${Math.round((sessionTokens||0)/1000)}k tok)`);
          return resolved;
        } catch (error) {
          console.log(`[SmartRouter] erro: ${error?.message ?? error}`);
        }
        return resolved;
      }, true /* prepend */);

      // ── agent/request-error: fallback runtime para o proximo candidato ──
      agentCtx.on("agent/request-error", async (payload, next) => {
        const prior = await next();
        try {
          if (prior && prior.kind === "retry") return prior;
          // CONTEXT_WINDOW_EXCEEDED: ativa o modo bigContext (modelo de maior
          // contexto), a menos que ja tenhamos tentado (evita loop).
          if (payload?.failure?.code === "CONTEXT_WINDOW_EXCEEDED") {
            if (fb.overflowCount < 1) {
              fb.bigContext = true;
              fb.overflowCount += 1;
              console.log(`[SmartRouter] CONTEXT_WINDOW_EXCEEDED no ${payload?.provider ?? "?"}: trocando para o modelo de maior contexto...`);
              return { kind: "retry" };
            }
            return void 0; // ja tentamos: deixa o erro final subir
          }
          if (fb.candidates.length === 0) return void 0;
          const current = fb.candidates[fb.index];
          if (!current || current.provider !== payload?.provider) return void 0;
          const nextIndex = fb.index + 1;
          if (nextIndex >= fb.candidates.length) return void 0;
          fb.index = nextIndex;
          const fallback = fb.candidates[nextIndex];
          console.log(`[SmartRouter] fallback ${nextIndex}/${fb.candidates.length}: ${current.provider}/${current.model} (falhou) -> ${fallback.provider}/${fallback.model}`);
          return { kind: "retry" };
        } catch (error) {
          console.log(`[SmartRouter] erro no fallback: ${error?.message ?? error}`);
          return void 0;
        }
      });
    }

    ctx.on("agent/created", ({ agent }) => {
      installForAgent(agent);
    }, { global: true });

    // ── GUI web: pagina /smart-router + API /api/smart-router ───────────────
    const webServer = ctx.get("webServer");
    if (webServer) {
      ctx.effect(() => webServer.register({
        kind: "exact",
        path: "/smart-router",
        handler: (_req, res) => {
          res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
          res.end(SMART_ROUTER_PAGE);
        }
      }), "smart-router: page");

      ctx.effect(() => webServer.register({
        kind: "exact",
        path: "/api/smart-router",
        handler: (req, res) => {
          if (req.method === "POST") {
            let body = "";
            req.on("data", (chunk) => { body += chunk; });
            req.on("end", () => {
              void (async () => {
                try {
                  const patch = JSON.parse(body || "{}");
                  await ctx.settings.update("smart-router", patch);
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
          const s = effectiveConfig();
          let raw = {};
          try { raw = ctx.settings?.get("smart-router") ?? {}; } catch { raw = {}; }
          const models = {};
          for (const [provider, ids] of modelCache) models[provider] = [...ids];
          res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
          res.end(JSON.stringify({
            ...raw,
            mode: s.mode,
            custom: s.custom,
            lists: s.lists,
            available: [...availCache],
            models,
            presets: DEFAULT_MODES,
            modesDesc: MODE_DESC
          }));
        }
      }), "smart-router: api");

      // injeta um botao flutuante "Roteador" na pagina principal (SPA)
      ctx.on("webserver/index-inject", (table) => {
        table.push({
          kind: "script",
          placement: "body",
          text: `(function(){var css="position:fixed;right:16px;bottom:16px;z-index:2147483647;display:inline-flex;align-items:center;gap:6px;background:#4d6bfe;color:#fff;border:0;border-radius:20px;padding:9px 16px;font:13px/1 system-ui,sans-serif;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.5);";function add(){if(document.getElementById("sr-router-btn"))return;var b=document.createElement("button");b.id="sr-router-btn";b.type="button";b.textContent="\\u26A1 Roteador";b.style.cssText=css;b.onclick=function(){location.href="/smart-router";};(document.body||document.documentElement).appendChild(b);}var n=0;var iv=setInterval(function(){if(document.body)add();if(++n>300)clearInterval(iv);},250);})();`
        });
      });
    }

    // servico para status e troca de modo (usado pela TUI e por quem quiser)
    ctx.provide("smartRouter", {
      status: () => {
        const cfg = effectiveConfig();
        const models = {};
        for (const [provider, ids] of modelCache) models[provider] = [...ids];
        return {
          mode: cfg.mode,
          custom: cfg.custom,
          lists: cfg.lists,
          available: [...availCache],
          models,
          presets: DEFAULT_MODES,
          modesDesc: MODE_DESC
        };
      },
      setMode: async (mode) => {
        if (!MODE_IDS.includes(mode)) return false;
        let current = {};
        try { current = ctx.settings?.get("smart-router") ?? {}; } catch { current = {}; }
        try {
          await ctx.settings?.replace("smart-router", { ...current, mode });
          return true;
        } catch { return false; }
      }
    });
  }
};

module.exports = smartRouterPlugin;
module.exports.default = smartRouterPlugin;
