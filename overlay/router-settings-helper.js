// helper para ler/gravar o namespace "smart-router" em ~/.dsh/settings.yaml.
// Uso (com o node embutido):
//   node helper.js set '{"mode":"ultra"}'
//   node helper.js get
const { createRequire } = require("node:module");
const os = require("node:os");
const path = require("node:path");
const fs = require("node:fs");

const CANDIDATES = [
  process.env.DSH_CLI_LIB,
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/lib/",
  "/usr/lib/node_modules/@deepseek-ai/dsh/lib/"
].filter(Boolean);

let YAML = null;
for (const lib of CANDIDATES) {
  try {
    YAML = createRequire(path.join(lib, "index.js"))("yaml");
    break;
  } catch { /* tenta a proxima */ }
}
if (!YAML) { console.error("yaml nao encontrado"); process.exit(1); }

const home = process.env.DSH_HOME ?? path.join(os.homedir(), ".dsh");
const file = path.join(home, "settings.yaml");
const action = process.argv[2] ?? "get";
const patchArg = process.argv[3];

function load() {
  try { return YAML.parse(fs.readFileSync(file, "utf8")) ?? {}; } catch { return {}; }
}
function save(doc) {
  fs.writeFileSync(file, YAML.stringify(doc));
}

if (action === "get") {
  const section = load()["smart-router"] ?? {};
  process.stdout.write(JSON.stringify(section, null, 2) + "\n");
} else if (action === "set") {
  const patch = JSON.parse(patchArg ?? "{}");
  const doc = load();
  doc["smart-router"] = { ...(doc["smart-router"] ?? {}), ...patch };
  save(doc);
  process.stdout.write("ok\n");
} else {
  console.error("uso: node helper.js get|set '<json>'");
  process.exit(1);
}