#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════
// check-npm-package.mjs — confere o conteúdo do pacote npm ANTES de publicar
//
// Roda em qualquer lugar com Node 20+ e npm:
//   node tools/check-npm-package.mjs
//
// Por que existe: o campo `files` do package.json é a única barreira entre o
// repositório e o que o mundo baixa. Um `overlay/` inteiro, por exemplo, levava
// junto a CONFIG VIVA espelhada no repo — anexos das sessões, settings.yaml do
// usuário, profiles/ — e nada disso é usado em runtime pelos plugins. Este script
// falha se algo assim voltar, e também se faltar um arquivo que o bundle precisa.
// ═══════════════════════════════════════════════════════════════
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const raiz = path.resolve(import.meta.dirname, "..");
process.chdir(raiz);

/** Arquivos que o bundle instalado por `dsh plugin add` precisa ter. */
const OBRIGATORIOS = [
  ["package.json", "manifesto que declara dsh.bundle.patch"],
  ["cordis.bundle.yml", "a camada (bundle) com os plugins do painel"],
  ["overlay/smart-router-plugin.js", "roteador free-first"],
  ["overlay/model-visibility-plugin.js", "filtro do catálogo de modelos"],
  ["overlay/openrouter-enhanced-plugin.js", "grupos do OpenRouter"],
  ["overlay/freellmapi-shortcut-plugin.js", "atalho do FreeLLMAPI"],
  ["overlay/layout-panel-plugin.js", "coluna lateral com os badges"],
  ["overlay/version-badge-plugin.js", "badge de versão, auto-update e rollback"],
  ["overlay/router-settings-helper.js", "helper de settings usado pelo roteador"],
  ["overlay/editor-assets/codemirror.min.js", "assets do editor do painel lateral"],
  ["overlay/openrouter-enhanced-data.json", "catálogo padrão semeado na config viva"],
  ["overlay/cordis.patch.yml.win.tpl", "referência de configuração citada pelo bundle"],
  ["tools/rollback.ps1", "rollback no Windows (usado pelo badge)"],
  ["tools/rollback.sh", "rollback no Linux (usado pelo badge)"],
  ["tools/sync-pull.ps1", "sync usado pelo botão de atualizar"],
  ["tools/sync-excludes.txt", "exclusões lidas pelo sync"],
  ["tools/ps-host.ps1", "resolução do host PowerShell (5.1 x 7.x)"],
  ["core-i18n-pt/dictionaries/en-phrases.json", "dicionário pt-BR"],
  ["core-i18n-pt/tools/pt-ride.mjs", "aplicador da tradução pt-BR"],
  ["assets/deepseek.ico", "ícone usado por tools/run-gui.ps1 e core-env.ps1"],
  ["README.md", "página do pacote no npm"],
  ["LICENSE", "licença"],
];

/** Caminhos que NUNCA podem entrar no pacote publicado. */
const PROIBIDOS = [
  [/^overlay\/attachments\//, "anexos de sessões do usuário (config viva espelhada)"],
  [/^overlay\/settings\.yaml$/, "settings do usuário (config viva espelhada)"],
  [/^overlay\/profiles\//, "perfis locais do harness"],
  [/^overlay\/\.agent-presets\//, "presets locais do usuário"],
  [/^overlay\/llm-deepseek\//, "catálogo local do provedor DeepSeek"],
  [/\.credentials\.yaml$/, "credenciais"],
  [/\.encryption-key$/, "chave de criptografia local"],
  [/\.dsh-version\.json$/, "carimbo de versão da máquina"],
  [/\.npmrc$/, "configuração local do npm"],
  [/\.mp4$/, "vídeo pesado (o GIF do README já cobre a demonstração)"],
  [/^tools\/test\.sh$/, "fixtures de teste com chaves falsas sk-... (o npm escaneia por segredos)"],
];

let problemas = 0;

const falha = (msg) => { console.error("  ✖ " + msg); problemas++; };

// ── 1. o manifesto ──────────────────────────────────────────────────────────
const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
console.log("manifesto:", `${pkg.name}@${pkg.version}`);
if (!pkg.name) falha("package.json sem nome");
if (pkg.private === true) falha("package.json com \"private\": true — o npm recusa publicar");
if (!pkg.license) falha("package.json sem licença (o npm mostra 'no license')");
const patch = pkg.dsh?.bundle?.patch;
if (!patch) falha("package.json sem dsh.bundle.patch — `dsh plugin add` não reconheceria o pacote como bundle");
else if (!fs.existsSync(patch)) falha(`dsh.bundle.patch aponta para ${patch}, que não existe`);
if (pkg.scripts?.prepare || pkg.scripts?.prepublish || pkg.scripts?.install || pkg.scripts?.postinstall) {
  falha("há script de ciclo de vida (prepare/install/postinstall): o pnpm BLOQUEIA build de dependência git até o usuário liberar em allowBuilds, o que quebraria `dsh plugin add github:...`");
}
if (Array.isArray(pkg.files) && pkg.files.some((f) => f === "overlay/" || f === ".")) {
  falha("files inclui o diretório overlay/ inteiro (arrasta a config viva) — liste os arquivos necessários");
}

// ── 2. conteúdo real do pacote ──────────────────────────────────────────────
let saida;
try {
  // Avisos do npm vão para stderr; o JSON sai no stdout.
  saida = execSync("npm pack --dry-run --json", {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
} catch (e) {
  console.error("npm pack --dry-run falhou:", (e && e.message) || e);
  process.exit(1);
}
const info = JSON.parse(saida)[0];
const arquivos = (info.files ?? []).map((f) => f.path.replace(/\\/g, "/")).sort();
const kb = Math.round((info.size ?? 0) / 1024);
console.log(`pacote: ${arquivos.length} arquivos, ${kb} KB (tarball ${Math.round((info.unpackedSize ?? 0) / 1024)} KB descompactado)`);

const conjunto = new Set(arquivos);
console.log("\nobrigatórios:");
for (const [f, porque] of OBRIGATORIOS) {
  if (!conjunto.has(f)) falha(`falta ${f} (${porque})`);
}
console.log("\nproibidos:");
for (const [re, porque] of PROIBIDOS) {
  const achados = arquivos.filter((f) => re.test(f));
  if (achados.length) {
    falha(`${achados.length} arquivo(s) que não deveriam estar no pacote — ${porque}: ${achados.slice(0, 3).join(", ")}${achados.length > 3 ? " …" : ""}`);
  }
}

// ── 3. resumo ───────────────────────────────────────────────────────────────
if (problemas === 0) {
  console.log(`\n✔ pacote ok: ${OBRIGATORIOS.length} verificações de presença e ${PROIBIDOS.length} de exclusão passaram.`);
  console.log("  instalação para quem já usa o harness: dsh plugin --profile web add " + (pkg.name ?? "freedsh"));
} else {
  console.error(`\n✖ ${problemas} problema(s) no pacote — corrija o campo "files" (ou o manifesto) antes de publicar.`);
}
process.exitCode = problemas === 0 ? 0 : 1;
