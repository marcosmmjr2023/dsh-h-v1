/**
 * Smart Model Router for DeepSeek Harness
 *
 * Roteamento automatico e inteligente entre provedores LLM, baseado em
 * complexidade da tarefa.
 *
 * DIFERENTE da abordagem anterior (llm/stream), este plugin roteia no hook
 * correto: `agent/request` (waterfall por-agente). Nesse hook o listener pode
 * MODIFICAR o config de provider/modelo e a mudanca REALMENTE vale — ao
 * contrario do llm/stream, cujo waterfall ignora as options alteradas.
 *
 * Fluxo:
 *   1. Escuta `agent/created` (global) para pegar cada agente publicado.
 *   2. Instala um listener `agent/request` no contexto do agente.
 *   3. A cada request, analisa a conversa (sessao) e escolhe um tier.
 *   4. Mapeia o tier para um provider/modelo disponivel e devolve o config
 *      alterado (provider, model, e opcionalmente reasoningEffort/maxTokens).
 *
 * @module smart-model-router
 */

const DEFAULT_ROUTING_CONFIG = {
  enabled: true,
  // Tier por complexidade. `providers` e a ordem de preferencia; o primeiro
  // disponivel (registrado e com credencial) vence. `models` eh a lista de ids
  // validos para o provider escolhido.
  tiers: {
    free: {
      providers: ["opencode-go"],
      models: ["mimo-v2.5"],
      reasoningEffort: "off",
      maxTokens: 8192
    },
    go: {
      providers: ["deepseek-official"],
      models: ["deepseek-v4-flash"],
      reasoningEffort: "medium",
      maxTokens: 16384
    },
    plus: {
      providers: ["deepseek-official", "opencode-go"],
      models: ["deepseek-v4-pro"],
      reasoningEffort: "high",
      maxTokens: 32768
    }
  },

  // Limiares de complexidade
  thresholds: {
    simple: {
      maxMessageLength: 500,
      maxToolCount: 3,
      keywords: ["hello", "hi", "thanks", "help", "what is", "define", "explain briefly"]
    },
    complex: {
      minMessageLength: 1000,
      minToolCount: 5,
      keywords: ["implement", "create", "build", "refactor", "debug", "optimize",
                 "architecture", "design pattern", "algorithm", "complex", "advanced"],
      codeIndicators: ["```", "function", "class", "import", "export", "async", "await"]
    }
  },

  // Fallback de roteamento
  fallback: {
    enabled: true,
    maxRetries: 2,
    retryDelayMs: 1000
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/** Texto simples dos blocos de conteudo de uma mensagem. */
function textOf(blocks) {
  if (typeof blocks === "string") return blocks;
  if (!Array.isArray(blocks)) return "";
  return blocks.filter((b) => b?.type === "text").map((b) => b.text).join("");
}

/** Merge da config do patch (entry config) sobre os defaults. */
function mergeRoutingConfig(userConfig = {}) {
  const base = DEFAULT_ROUTING_CONFIG;
  return {
    ...base,
    ...userConfig,
    tiers: { ...base.tiers, ...(userConfig.tiers || {}) },
    thresholds: { ...base.thresholds, ...(userConfig.thresholds || {}) },
    fallback: { ...base.fallback, ...(userConfig.fallback || {}) }
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPLEXITY ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Analisa a complexidade de uma conversa e devolve o tier alvo.
 */
function analyzeComplexity(config, messages) {
  const reasons = [];
  let score = 0;
  const list = Array.isArray(messages) ? messages : [];

  // ultima mensagem do usuario
  let lastUser = null;
  for (let i = list.length - 1; i >= 0; i--) {
    if (list[i].role === "user") { lastUser = list[i]; break; }
  }
  const content = lastUser ? (typeof lastUser.content === "string" ? lastUser.content : textOf(lastUser.content)) : "";
  const lower = content.toLowerCase();

  // tamanho
  if (content.length < config.thresholds.simple.maxMessageLength) {
    score -= 2;
    reasons.push("short message");
  } else if (content.length > config.thresholds.complex.minMessageLength) {
    score += 3;
    reasons.push("long message");
  }

  // keywords simples
  const simpleMatches = config.thresholds.simple.keywords.filter((kw) => lower.includes(kw));
  if (simpleMatches.length > 0) {
    score -= 2;
    reasons.push(`simple keywords: ${simpleMatches.join(",")}`);
  }

  // keywords complexas
  const complexMatches = config.thresholds.complex.keywords.filter((kw) => lower.includes(kw));
  if (complexMatches.length > 0) {
    score += 2 * complexMatches.length;
    reasons.push(`complex keywords: ${complexMatches.join(",")}`);
  }

  // indicadores de codigo
  const codeMatches = config.thresholds.complex.codeIndicators.filter((ind) => lower.includes(ind));
  if (codeMatches.length > 0) {
    score += codeMatches.length;
    reasons.push(`code indicators: ${codeMatches.join(",")}`);
  }

  // perguntas multiplas
  const questionMarks = (lower.match(/\?/g) || []).length;
  if (questionMarks > 2) {
    score += 2;
    reasons.push("multiple questions");
  }

  // contexto da conversa
  if (list.length > 20) {
    score += 2;
    reasons.push("long conversation");
  } else if (list.length < 3) {
    score -= 1;
    reasons.push("short conversation");
  }

  // tier
  const tier = score <= -2 ? "free" : score >= 5 ? "plus" : "go";
  return { score, tier, reasons };
}

/** Deriva a lista de mensagens {role, content} a partir dos eventos da sessao. */
function deriveMessages(agent) {
  const messages = [];
  for (const event of agent?.session?.events ?? []) {
    if (event?.type === "user/message") {
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
// CORDIS PLUGIN
// ═══════════════════════════════════════════════════════════════════════════════

const smartRouterPlugin = {
  name: "smart-model-router",

  inject: ["llm"],

  apply(ctx, userConfig) {
    const config = mergeRoutingConfig(userConfig);
    const llm = ctx.llm;

    // lista de providers disponiveis (registrados com credencial)
    const availableProviders = () => {
      try {
        return llm.listProviders().map((p) => p.id);
      } catch { return []; }
    };

    // resolve o alvo do tier: primeiro provider disponivel da lista
    function resolveTarget(tierId) {
      const tier = config.tiers?.[tierId];
      if (!tier) return null;
      const providers = Array.isArray(tier.providers) ? tier.providers : [tier.providers];
      const models = Array.isArray(tier.models) ? tier.models : [tier.models];
      const avail = availableProviders();
      for (const provider of providers) {
        if (!avail.includes(provider)) continue;
        if (models.length === 0) continue;
        return {
          provider,
          model: models[0],
          ...(tier.reasoningEffort !== void 0 ? { reasoningEffort: tier.reasoningEffort } : {}),
          ...(tier.maxTokens !== void 0 ? { maxTokens: tier.maxTokens } : {})
        };
      }
      return null;
    }

    // instalacao por agente
    function installForAgent(agent) {
      const agentCtx = agent?.ctx;
      if (!agentCtx) return;

      agentCtx.on("agent/request", async (payload, next) => {
        const resolved = await next();
        try {
          const messages = deriveMessages(agent);
          const analysis = analyzeComplexity(config, messages);
          const target = resolveTarget(analysis.tier);

          if (target && (target.provider !== resolved.provider || target.model !== resolved.model)) {
            const routed = {
              ...resolved,
              provider: target.provider,
              model: target.model,
              ...(target.reasoningEffort !== void 0 ? { reasoningEffort: target.reasoningEffort } : {}),
              ...(target.maxTokens !== void 0 ? { maxTokens: target.maxTokens } : {})
            };
            console.log(`[SmartRouter] ${analysis.tier} (score ${analysis.score}): ${resolved.provider}/${resolved.model} -> ${target.provider}/${target.model}`);
            return routed;
          }
          console.log(`[SmartRouter] ${analysis.tier} (score ${analysis.score}): mantem ${resolved.provider}/${resolved.model}`);
        } catch (error) {
          console.log(`[SmartRouter] erro na analise: ${error?.message ?? error}`);
        }
        return resolved;
      });
    }

    // hooka todos os agentes, presentes e futuros
    ctx.on("agent/created", ({ agent }) => {
      if (config.enabled === false) return;
      installForAgent(agent);
    }, { global: true });
  }
};

module.exports = smartRouterPlugin;
module.exports.default = smartRouterPlugin;