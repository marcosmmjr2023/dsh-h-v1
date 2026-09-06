#!/usr/bin/env node
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

function stripComments(src) {
  let out = "";
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (src[i] === "/" && src[i + 1] === "*") { const e = src.indexOf("*/", i + 2); i = e === -1 ? src.length : e + 1; continue; }
    out += src[i];
  }
  return out;
}
function findObject(text, openIdx) {
  let depth = 0, inStr = false;
  for (let i = openIdx; i < text.length; i++) {
    const c = text[i];
    if (inStr) { if (c === "\\") i++; else if (c === '"') inStr = false; continue; }
    if (c === '"') { inStr = true; continue; }
    if (c === "{") depth++;
    else if (c === "}") { depth--; if (depth === 0) return { end: i + 1 }; }
  }
  throw new Error("objeto sem fechamento");
}
function parseDict(text, openIdx) {
  const { end } = findObject(text, openIdx);
  const body = text.slice(openIdx + 1, end - 1);
  try { return { map: JSON.parse("{" + stripComments(body) + "}"), end }; }
  catch { return { map: null, end }; }
}

let existing = {};
if (onlyNew) { try { existing = JSON.parse(fs.readFileSync(onlyNew, "utf8")); } catch {} }

const catalog = [];
for (const file of files) {
  const text = fs.readFileSync(file, "utf8");
  const re = /const (en)(\$?\w*)\s*=\s*\{/g;
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
