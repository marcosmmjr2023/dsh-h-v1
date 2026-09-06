#!/usr/bin/env node
import { findObject, parseDict } from "./ptlib.mjs";
/**
 * dump-en-phrases.mjs — extrai as frases em inglês dos dicionários compilados
 * de um/dois arquivos de locale do núcleo (para alimentar en-phrases.json).
 *
 * Uso:
 *   node dump-en-phrases.mjs --file <client.js> [--file B …] [--json] [--only-new <en-phrases.json>]
 *
 * Saída padrão (legível):
 *   <dict> : <key> = <valor en>        (uma por linha)
 * Com --only-new <caminho do en-phrases.json>, lista apenas valores que ainda
 * não têm tradução. Com --json, imprime o catálogo estruturado.
 */
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const args = process.argv.slice(2);
const files = [];
let json = false;
let onlyNew = "";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--file") files.push(args[++i]);
  else if (args[i] === "--json") json = true;
  else if (args[i] === "--only-new") onlyNew = args[++i];
}

let existing = {};
if (onlyNew) { try { existing = JSON.parse(fs.readFileSync(onlyNew, "utf8")); } catch {} }

const catalog = [];
for (const file of files) {
  const text = fs.readFileSync(file, "utf8");
  const re = /const (en)(?:\$\d+)?\s*=\s*\{/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const decl = m[0];
    const name = decl.slice("const ".length, decl.indexOf(" ="));
    const openIdx = text.indexOf("{", m.index);
    const { map } = parseDict(text, openIdx);
    if (!map) { console.error(`⚠ ${file} ${name}: dicionário não parseado`); continue; }
    catalog.push({ file, dict: name, map });
  }
}

const seen = new Set();
const out = [];
for (const c of catalog) {
  for (const [k, v] of Object.entries(c.map)) {
    if (onlyNew && existing[v] !== undefined) continue;
    if (seen.has(v)) continue;
    seen.add(v);
    out.push(json
      ? { file: c.file, dict: c.dict, key: k, en: v }
      : `${c.dict} : ${k} = ${v.replace(/\n/g, "\\n")}`);
  }
}
if (json) console.log(JSON.stringify(out, null, 1));
else console.log(out.join("\n"));
console.error(`# ${out.length} valor(es) único(s)` + (onlyNew ? " ainda sem tradução" : "") + " em " + files.length + " arquivo(s).");
