#!/usr/bin/env node
/**
 * verify-pt.mjs — verifica a PARIDADE de chaves dos dicionários pt-BR
 * injetados no núcleo (core-i18n-pt).
 *
 * Para cada arquivo de locale dos pacotes do núcleo:
 *   • pt vs en  — todo dicionário `en` deve ter um `pt` correspondente com o
 *     MESMO conjunto de chaves (sem chave faltando, sem chave extra);
 *   • en vs zh  — paridade original também é reportada (não deve ter mudado).
 *
 * Uso:
 *   node verify-pt.mjs [--root <raiz-com-os-pacotes>] [--quiet]
 * Padrão da raiz: DSH_CORE_PKGS ou auto-detect (/opt/dsh-tui, /usr/lib).
 * Exit 0 = tudo par, 1 = divergências.
 */
import fs from "node:fs";
import path from "node:path";
import { parseDict } from "./ptlib.mjs";

const args = process.argv.slice(2);
let root = "";
let quiet = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--root") root = args[++i];
  else if (args[i] === "--quiet") quiet = true;
}
const candidates = [
  root,
  process.env.DSH_CORE_PKGS || "",
  "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai",
  "/usr/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai",
];
const PKGS = candidates.find((c) => c && fs.existsSync(path.join(c, "dsh-client-locale")));
if (!PKGS) { console.error("raiz de pacotes não encontrada (use --root ou DSH_CORE_PKGS)."); process.exit(2); }
console.log(`▶ raiz: ${PKGS}`);

function dictsOf(text, lang) {
  const out = [];
  const re = new RegExp(`const (${lang})(?:\\$\\d+)?\\s*=\\s*\\{`, "g");
  let m;
  while ((m = re.exec(text)) !== null) {
    const name = m[0].slice("const ".length, m[0].indexOf(" ="));
    const open = text.indexOf("{", m.index);
    const { map } = parseDict(text, open);
    out.push({ name, map });
  }
  return out.filter((d) => d.map);
}

let problems = 0, files = 0;
const walk = (dir, acc = []) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (e.name !== "node_modules" && !e.name.startsWith(".")) walk(path.join(dir, e.name), acc);
    } else if (e.name === "client.js") acc.push(path.join(dir, e.name));
  }
  return acc;
};
const filesList = walk(PKGS).filter((f) => /\/dsh-client-.*\/lib\/client\.js$/.test(f));

for (const f of filesList) {
  const rel = f.slice(PKGS.length + 1);
  const text = fs.readFileSync(f, "utf8");
  const ens = dictsOf(text, "en");
  if (!ens.length) continue;
  files++;
  const pts = dictsOf(text, "pt");
  const zhs = dictsOf(text, "zh");
  for (const en of ens) {
    const suffix = en.name.slice(2);
    const pt = pts.find((p) => p.name === "pt" + suffix);
    const zh = zhs.find((z) => z.name === "zh" + suffix);
    const enKeys = Object.keys(en.map);
    const zhKeys = zh ? Object.keys(zh.map) : [];
    const ptKeys = pt ? Object.keys(pt.map) : [];
    const missPt = enKeys.filter((k) => !ptKeys.includes(k));
    const extraPt = ptKeys.filter((k) => !enKeys.includes(k));
    const ez = enKeys.filter((k) => !zhKeys.includes(k)).concat(zhKeys.filter((k) => !enKeys.includes(k)));
    const bad = missPt.length || extraPt.length;
    if (!quiet || bad) {
      const tag = pt ? "OK " : "SEM";
      console.log(`${tag} ${rel}  ${en.name} → ${pt ? "pt" + suffix : "pt"}: en=${enKeys.length} pt=${ptKeys.length} zh=${zh ? zhKeys.length : "-"}` +
        (missPt.length ? ` | pt-falta en: ${missPt.slice(0, 5).join(",")}` : "") +
        (extraPt.length ? ` | pt-extra: ${extraPt.slice(0, 5).join(",")}` : "") +
        (ez.length ? ` | zh≠en: ${ez.slice(0, 5).join(",")}` : ""));
    }
    if (bad) { problems++; console.error(`✗ ${rel} ${en.name}: paridade pt/en quebrada.`); }
  }
}
if (problems === 0) console.log(`✔ paridade pt/en OK em ${files} arquivo(s) (e en/zh sem divergência nova).`);
else { console.error(`✋ ${problems} dicionário(s) com paridade pt/en quebrada.`); process.exit(1); }
