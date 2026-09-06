#!/usr/bin/env node
/**
 * build-pt-patches.mjs — injeta dicionários pt-BR nos arquivos compilados de
 * locale do núcleo (@deepseek-ai/dsh, core-i18n-pt).
 *
 * Para cada arquivo passado, faz o seguinte (sem tocar no restante):
 *   1. localiza cada dicionário `const en<Suffix> = { … };` (sufixo pode ser
 *      vazio, `$1`, `$2`, …) e lê as chaves/valores em inglês;
 *   2. verifica equivalência de chaves vs o dicionário `zh<Suffix>`;
 *   3. insere logo após o dicionário `en` um dicionário `pt<Suffix>` com as
 *      chaves cujo texto em inglês tem tradução em en-phrases.json (chaves
 *      ainda não traduzidas ficam de fora → o runtime cai no fallback `en`);
 *   4. nas chamadas `xxx.register(...)` cujo objeto de argumentos referencia
 *      os dicionários (estilo `en: en$1` ou abreviado `en,`), adiciona o par
 *      `pt` correspondente.
 *
 * Uso:
 *   node build-pt-patches.mjs --file <caminho/do/client.js> [--phrases <json>] [--check]
 *
 * Observação: rode sobre uma CÓPIA dos arquivos (workspace) — os diffs
 * resultantes viram patches em core-i18n-pt/patches/.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
const files = [];
let phrasesPath = "";
let checkOnly = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--file") files.push(args[++i]);
  else if (args[i] === "--phrases") phrasesPath = args[++i];
  else if (args[i] === "--check") checkOnly = true;
}
if (!files.length) {
  console.error("uso: build-pt-patches.mjs --file <client.js> [--phrases en-phrases.json] [--check]");
  process.exit(2);
}

const PHRASES_PATH = phrasesPath || path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "dictionaries", "en-phrases.json");
let phrases = {};
try { phrases = JSON.parse(fs.readFileSync(PHRASES_PATH, "utf8")); } catch (e) { console.error("não li frases:", e.message); }

/** Remove comentários // e /* *​/ de um trecho de objeto. */
function stripComments(src) {
  let out = "";
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (src[i] === "/" && src[i + 1] === "*") {
      const end = src.indexOf("*/", i + 2);
      i = end === -1 ? src.length : end + 1;
      continue;
    }
    out += src[i];
  }
  return out;
}

/** Acha o corpo de "{ … }" a partir do índice do "{", devolvendo {body,end} (end = índice após o '}'). */
function findObject(text, openIdx) {
  let depth = 0;
  let inStr = false;
  for (let i = openIdx; i < text.length; i++) {
    const c = text[i];
    if (inStr) {
      if (c === "\\") { i++; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; continue; }
    if (c === "{") depth++;
    else if (c === "}") {
      depth--;
      if (depth === 0) return { body: text.slice(openIdx + 1, i), end: i + 1 };
    }
  }
  throw new Error("objeto sem fechamento");
}

/** Lê um dicionário (objeto literal) como map chave→valor; devolve {map|null,end}. */
function parseDict(text, openIdx) {
  const { body, end } = findObject(text, openIdx);
  const clean = stripComments(body);
  try {
    return { map: JSON.parse("{" + clean + "}"), end };
  } catch {
    return { map: null, end };
  }
}

let problems = 0;
for (const file of files) {
  if (!fs.existsSync(file)) { console.error("✗ arquivo não existe:", file); problems++; continue; }
  const base = fs.readFileSync(file, "utf8");
  let text = base;

  const dicts = [];
  const re = /const (zh|en)(\$?\w*)\s*=\s*\{/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const decl = m[0];
    const name = decl.slice("const ".length, decl.indexOf(" ="));
    const lineStart = text.lastIndexOf("\n", m.index) + 1;
    const indent = text.slice(lineStart, m.index);
    const openIdx = text.indexOf("{", m.index);
    const { map, end } = parseDict(text, openIdx);
    dicts.push({ lang: m[1], name, indent, openIdx, end, map, added: false });
  }
  if (!dicts.length) { console.log(`  ℹ ${file}: nenhum dicionário encontrado.`); continue; }

  const enDicts = dicts.filter((d) => d.lang === "en");
  const edits = [];

  for (const en of enDicts) {
    if (en.map === null) { console.error(`  ✗ ${file}: dicionário ${en.name} não é JSON puro — pulado.`); problems++; continue; }
    const zh = dicts.find((d) => d.lang === "zh" && d.name.replace(/^zh/, "en") === en.name);
    const zhKeys = zh && zh.map ? Object.keys(zh.map) : [];
    const enKeys = Object.keys(en.map);
    const missZh = enKeys.filter((k) => !zhKeys.includes(k));
    const missEn = zhKeys.filter((k) => !enKeys.includes(k));
    if (missZh.length || missEn.length) {
      console.error(`  ⚠ ${en.name}: chaves divergentes zh/en — só en: [${missZh}], só zh: [${missEn}]`);
    }

    const entries = [];
    let covered = 0;
    for (const k of enKeys) {
      const v = en.map[k];
      const pt = phrases[v];
      if (typeof pt === "string" && pt.length) { entries.push(`${en.indent}\t"${k}": ${JSON.stringify(pt)},`); covered++; }
    }
    if (!entries.length) { console.log(`  ℹ ${en.name}: sem tradução no en-phrases.json (${enKeys.length} chaves) — sem pt por enquanto.`); continue; }
    const ptName = "pt" + en.name.slice(2);
    if (new RegExp(`const ${ptName}\\s*=`).test(text)) { console.log(`  ℐ ${ptName} já existe — pulado (idempotente).`); continue; }
    const semi = text.indexOf(";", en.end);
    const ptBlock = `\n${en.indent}const ${ptName} = {\n` + entries.join("\n") + `\n${en.indent}};\n`;
    edits.push({ start: en.end, end: semi + 1, text: text.slice(en.end, semi + 1) + ptBlock });
    en.ptName = ptName;
    en.added = true;
    console.log(`  ✓ ${en.name} → ${ptName} (${covered}/${enKeys.length} chaves traduzidas; ${enKeys.length - covered} caem no fallback en)`);
  }

  // register(...): adiciona o par pt no objeto de argumentos
  const regRe = /\.register\(/g;
  let rm;
  while ((rm = regRe.exec(text)) !== null) {
    const openParen = text.indexOf("(", rm.index);
    let depth = 0, inStr = false, closeParen = -1;
    for (let i = openParen; i < text.length; i++) {
      const c = text[i];
      if (inStr) { if (c === "\\") i++; else if (c === '"') inStr = false; continue; }
      if (c === '"') { inStr = true; continue; }
      if (c === "(") depth++;
      else if (c === ")") { depth--; if (depth === 0) { closeParen = i; break; } }
    }
    if (closeParen === -1) continue;
    const inner = text.slice(openParen, closeParen);

    for (const en of enDicts.filter((d) => d.added)) {
      const pat = new RegExp(`\\ben:\\s*${en.name}\\b`);
      const mm = pat.exec(inner);
      if (mm) {
        const abs = openParen + mm.index;
        const lineStart = text.lastIndexOf("\n", abs) + 1;
        const indent = text.slice(lineStart, abs);
        edits.push({ start: abs, end: abs + mm[0].length, text: `pt: ${en.ptName},\n${indent}${mm[0]}` });
        continue;
      }
      if (en.name === "en") {
        // estilo abreviado: linha só com `en` (propriedade = variável en) dentro do register
        const lnRe = /\n([ \t]*)en([ \t]*)(\n)/g;
        const lm = lnRe.exec(inner);
        if (lm) {
          const abs = openParen + lm.index + 1; // depois do \n inicial
          const ind = lm[1];
          const trail = lm[2];
          edits.push({
            start: abs,
            end: abs + ind.length + 2 + trail.length + 1, // cobre indent + 'en' + trail + \n
            text: `${ind}pt,\n${ind}en${trail}\n`,
          });
        }
      }
    }
  }

  if (checkOnly) { console.log(`  [--check] ${file}: ${edits.length} edição(ões) planejada(s).`); continue; }
  edits.sort((a, b) => b.start - a.start);
  for (const e of edits) text = text.slice(0, e.start) + e.text + text.slice(e.end);
  if (text === base) { console.log(`  ℹ ${file}: sem alterações.`); continue; }
  fs.writeFileSync(file, text);
  console.log(`✔ ${file}: ${edits.length} edição(ões) aplicada(s).`);
}

if (problems) { console.error(`resumo: ${problems} problema(s).`); process.exit(1); }
