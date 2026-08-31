// Preload para a instancia paralela dsh-h-v1 (Windows).
// Avalia schemastery + dsh-settings ANTES do boot da arvore de plugins.
// Sem isso, os plugins (smart-router, model-visibility) fazem require()
// sincrono desses modulos ESM enquanto o boot ainda os importa em paralelo,
// causando: "Cannot require() ES Module because it is not yet fully loaded".
"use strict";
const path = require("node:path");
const { createRequire } = require("node:module");
const lib = process.env.DSH_CLI_LIB;
if (!lib) {
  console.error("[dsh-preload] DSH_CLI_LIB nao definido; pulando preload.");
} else {
  try {
    const r = createRequire(path.join(lib, "index.js"));
    r("@deepseek-ai/schemastery");
    r("@deepseek-ai/dsh-settings");
    console.error("[dsh-preload] schemastery + dsh-settings avaliados com sucesso.");
  } catch (err) {
    console.error("[dsh-preload] aviso (boot continua):", err.message);
  }
}
