/**
 * OpenRouter Enhanced — granulometria fina na escolha de modelos OpenRouter.
 *
 * Registra dois provedores extras no seletor de modelos do Harness:
 *
 *   - openrouter-free  ("OpenRouter Free"): somente modelos gratuitos
 *     (pricing prompt/completion = 0), direto da API do OpenRouter.
 *
 *   - openrouter-pro   ("OpenRouter Pro"): modelos populares com uma entrada
 *     por provedor disponivel (ex.: "Claude 3.5 Haiku — via Anthropic",
 *     "… — via Amazon Bedrock"). Cada variante injeta
 *     `provider: { order: [<provedor>] }` na request do OpenRouter, que e o
 *     mecanismo oficial de roteamento por provedor.
 *
 * Implementacao: subclasse de PiAiAdapter (do dsh-llm-pi-ai) com override de
 * `modelOf` — o ponto unico por onde o model id selecionado vira o objeto de
 * modelo pi-ai usado na request. Para ids de variante ("modelo@provedor"),
 * devolve o modelo real com compat.openRouterRouting, que o pi-ai ja traduz
 * para o campo `provider` do corpo da request.
 *
 * Dados estaticos em openrouter-enhanced-data.json (gerados da API do
 * OpenRouter: /models + /models/{id}/endpoints). Regeneraveis a qualquer
 * momento.
 */
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { createRequire } = require("node:module");
const { pathToFileURL } = require("node:url");

// resolve os pacotes do CLI instalado (mesmo padrao do smart-router)
const CANDIDATE_LIBS = [
  process.env.DSH_CLI_LIB,
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/lib/",
  "/usr/lib/node_modules/@deepseek-ai/dsh/lib/",
].filter(Boolean);

let requireCli = null;
let cliLib = null;
for (const lib of CANDIDATE_LIBS) {
  try {
    requireCli = createRequire(path.join(lib, "index.js"));
    cliLib = lib;
    break;
  } catch { /* tenta a proxima */ }
}
if (!requireCli) {
  throw new Error("[openrouter-enhanced] nao foi possivel localizar o CLI instalado");
}

const DATA_FILE = path.join(__dirname, "openrouter-enhanced-data.json");
const data = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));

const FREE = "openrouter-free";
const PRO = "openrouter-pro";
const BASE_URL = "https://openrouter.ai/api/v1";
const API_KEY_ENV = "OPENROUTER_API_KEY";

function piAiDist() {
  return path.join(path.dirname(cliLib), "node_modules", "@earendil-works", "pi-ai", "dist");
}

const plugin = {
  name: "openrouter-enhanced",
  inject: ["llm"],

  async apply(ctx) {
    // import() dinamico e sequencial: evita a corrida entre o require sincrono
    // (CJS) e o carregamento ESM paralelo do mesmo modulo pelo boot.
    const resolvePkg = (name) => requireCli.resolve(name);
    const { PiAiAdapter } = await import(pathToFileURL(resolvePkg("@deepseek-ai/dsh-llm-pi-ai")).href);
    const { LlmError, assertUsableApiKey } = await import(pathToFileURL(resolvePkg("@deepseek-ai/dsh-llm")).href);
    const pi = await import(pathToFileURL(path.join(piAiDist(), "index.js")).href);
    const { openAICompletionsApi } = await import(pathToFileURL(path.join(piAiDist(), "api", "openai-completions.lazy.js")).href);
    const { createProvider, InMemoryCredentialStore, envApiKeyAuth } = pi;

    /** Mesma convencao do llm-pi-ai: resolve a chave pelo apiKeyEnv do perfil. */
    const resolveApiKey = async (provider, profile) => {
      const ref = profile.apiKeyEnv;
      if (ref === void 0) return void 0;
      const credentials = ctx.get("credentials");
      const hit = credentials !== void 0 ? (await credentials.resolve(ref))?.value : void 0;
      if (hit !== void 0 && hit.length > 0) return assertUsableApiKey(hit, "openrouter-enhanced", ref);
      throw new LlmError(
        `openrouter-enhanced: no credential for provider route "${provider}"; its profile resolves ${ref}, which is not set — store ${ref} through the web Models page (OpenRouter)`,
        "MISSING_CREDENTIAL"
      );
    };

    /**
     * Subclasse que traduz ids de variante ("modelo@provedor") no modelo real
     * com o roteamento de provedor que o pi-ai envia como `provider` no corpo
     * da request (compat.openRouterRouting).
     */
    class OpenRouterAdapter extends PiAiAdapter {
      modelOf(snapshot, provider, model) {
        if (provider === PRO) {
          const variant = data.variantMap[model];
          if (variant !== void 0) {
            const base = variant.base;
            return {
              ...base,
              id: variant.realId,
              name: variant.name,
              compat: { ...(base.compat ?? {}), openRouterRouting: variant.routing }
            };
          }
        }
        return super.modelOf(snapshot, provider, model);
      }

      /**
      * Inclui a descricao (preco/latencia/throughput/uptime) no catalogo que o
      * seletor de modelos renderiza como segunda linha de cada opcao.
      */
      listModels(provider) {
        return Promise.resolve().then(() => {
          const snapshot = this.current();
          this.profileOf(snapshot, provider);
          return snapshot.models.getModels(provider).map((model) => ({
            provider,
            id: model.id,
            name: model.name,
            inputModalities: [...model.input],
            ...model.description === void 0 ? {} : { description: model.description }
          }));
        });
      }
    }

    const makeProvider = (id, displayName, models) => createProvider({
      id,
      name: displayName,
      baseUrl: BASE_URL,
      auth: { apiKey: envApiKeyAuth("OpenRouter API key", [API_KEY_ENV]) },
      models,
      api: openAICompletionsApi()
    });

    const profileFor = (id, displayName, models) => ({
      provider: id,
      displayName,
      apiKeyEnv: API_KEY_ENV,
      retryPolicy: void 0,
      reasoning: void 0,
      streamIdleTimeoutMs: 300000,
      maxRequestImageBytes: 20 * 1024 * 1024,
      requestImagePixelBudget: 2048 * 2048,
      requestImageMaxBytes: 1024 * 1024,
      configuredMaxTokens: new Map(),
      headers: void 0,
      piProvider: makeProvider(id, displayName, models)
    });

    const profiles = new Map([
      [FREE, profileFor(FREE, "OpenRouter Free", data.freeModels)],
      [PRO, profileFor(PRO, "OpenRouter Pro", data.proModels)]
    ]);

    const adapter = new OpenRouterAdapter({
      profiles: () => profiles,
      resolveApiKey,
      auth: { credentials: new InMemoryCredentialStore() },
      resolveAttachments: () => ctx.get("attachments"),
      onReplayDegrade: ({ provider, model, reason }) => {
        ctx.logger.warn(`openrouter-enhanced: unusable replay state on "${provider}/${model}"; sending as provider-neutral content (${reason})`);
      }
    });

    ctx.llm.registerAdapter([FREE, PRO], adapter);
    ctx.logger.info(`openrouter-enhanced: registrados ${FREE} (${data.freeModels.length} modelos) e ${PRO} (${data.proModels.length} modelos)`);
  }
};

module.exports = plugin;
module.exports.default = plugin;
