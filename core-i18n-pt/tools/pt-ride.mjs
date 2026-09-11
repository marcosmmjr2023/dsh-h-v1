#!/usr/bin/env node
/**
 * pt-ride.mjs — instala/garante o pt-BR num core instalado (qualquer versão),
 * sem depender de patches com contexto (que quebram quando o core muda).
 *
 * Uso:  node pt-ride.mjs --root <depsDir>
 *   depsDir = diretório @deepseek-ai que contém os pacotes dsh-client-*
 *             (normalmente …/@deepseek-ai/dsh/node_modules/@deepseek-ai)
 *
 * Faz:
 *   1. Dicionários: em cada pacote com dicionário `en` sem `pt`, roda o
 *      gerador (build-pt-patches.mjs) — as traduções vêm de
 *      dictionaries/en-phrases.json (indexado por texto EN → funciona em
 *      qualquer versão);
 *   2. Encanamento em dsh-client-locale: adiciona "pt" em LOCALE_IDS,
 *      no metadado de idioma (rótulo "Português"), no <html lang> (pt-BR) e
 *      nos registros dos dicionários comuns/settings.
 * Exit 0 mesmo com etapas que não se apliquem (versões distintas) — reporta.
 */
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { parseDict, findObject } from "./ptlib.mjs";

const args = process.argv.slice(2);
let root = "";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--root") root = args[++i];
}
if (!root || !fs.existsSync(path.join(root, "dsh-client-locale"))) {
  console.error("uso: node pt-ride.mjs --root <depsDir com dsh-client-locale>");
  process.exit(2);
}

const here = path.dirname(fileURLToPath(import.meta.url));
const GEN = path.join(here, "build-pt-patches.mjs");
const PHRASES_PATH = path.join(path.dirname(here), "dictionaries", "en-phrases.json");
const PHRASES = JSON.parse(fs.readFileSync(PHRASES_PATH, "utf8"));
const SKIP = (process.env.DSH_PT_SKIP || "").split(",").map((x) => x.trim()).filter(Boolean);
const skipped = (f) => SKIP.some((k) => f.includes(k));
const report = (s) => console.log("  " + s);
// Backup do original antes da primeira alteracao: e o que permite o
// "apply-pt-core.ps1 -Cmd --revert" devolver o core ao estado de fabrica.
function backupOnce(f) {
  const bak = f + ".dshbak";
  try { if (!fs.existsSync(bak)) fs.copyFileSync(f, bak); } catch { }
}
function writePatched(f, content) { backupOnce(f); fs.writeFileSync(f, content); }
function jsOk(f) {
  const r = spawnSync(process.execPath, ["--check", f], { encoding: "utf8" });
  return r.status === 0;
}

// ── 1) dicionários (sweep com o gerador) ────────────────────────────────
let genFiles = 0;
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name !== "node_modules" && !e.name.startsWith(".")) walk(p);
    } else if (e.name === "client.js") genFiles++;
  }
}
const pkgs = [];
(function collect(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name !== "node_modules" && !e.name.startsWith(".")) collect(p);
    } else if (e.name === "client.js") {
      const t = fs.readFileSync(p, "utf8");
      if (/const en(?:\$\d+)?\s*=\s*\{/.test(t) && !/const pt(?:\$\d+)?\s*=\s*\{/.test(t)) pkgs.push(p);
    }
  }
})(root);
for (const f of pkgs) {
  if (skipped(f)) { report(`ℹ pulado por DSH_PT_SKIP: ${path.relative(root, f)}`); continue; }
  const orig = fs.readFileSync(f, "utf8");
  backupOnce(f);
  const r = spawnSync(process.execPath, [GEN, "--file", f], { encoding: "utf8" });
  if (r.status !== 0 || !jsOk(f)) {
    fs.writeFileSync(f, orig); // guarda: nunca entrega JS inválido
    report(`⚠ pulado (falha/sintaxe) em ${path.relative(root, f)} — segue com en/fallback`);
    continue;
  }
  genFiles++;
  report(`✔ pt (dict) em ${path.relative(root, f)}`);
}
report(`dicionários gerados: ${genFiles} arquivo(s)`);

// ── 2) encanamento ──────────────────────────────────────────────────────
const loc = path.join(root, "dsh-client-locale", "lib");
let steps = 0;

// index.js — LOCALE_IDS (e unions de schema, quando presentes)
for (const f of ["index.js", "client.js"]) {
  const fp = path.join(loc, f);
  if (!fs.existsSync(fp)) continue;
  let s = fs.readFileSync(fp, "utf8");
  const before = s;
  // LOCALE_IDS = ["zh","en"]  (tolerante a espaços)
  s = s.replace(/(LOCALE_IDS\s*=\s*\[)(\s*"zh"\s*,\s*"en"\s*)(\])/g, '$1"zh", "en", "pt"$3');
  // z.union([..., "en" ...]) → adiciona "pt"
  s = s.replace(/(z\.union\(\[)([^\]]*"en"[^\]]*)(\])/g, (m, a, b, c) => (b.includes('"pt"') ? m : a + b + (b.trim().endsWith(",") ? "" : ", ") + '"pt"' + c));
  if (s !== before) {
    writePatched(fp, s);
    if (!jsOk(fp)) {
      const bak = fp + ".dshbak";
      if (fs.existsSync(bak)) fs.copyFileSync(bak, fp);
      report(`⚠ LOCALE_IDS revertido (sintaxe invalida) em ${f}`);
    } else { steps++; report(`✔ LOCALE_IDS/union com "pt" em ${f}`); }
  }
}
// client.js — metadado de idioma (rótulo), html lang pt-BR e registros
{
  const fp = path.join(loc, "client.js");
  let s = fs.readFileSync(fp, "utf8");
  const before = s;
  // (a) formato ANTIGO: metadado en: { label: "English" } → adiciona pt
  if (!s.includes("Português")) {
    s = s.replace(/en:\s*\{\s*label:\s*"English"\s*\}/g, 'en: { label: "English" }, pt: { label: "Português", fallback: "en" }');
  }
  // (b) formato ATUAL (core 0.1.x): a lista de idiomas e' o array
  // LOCALES = Object.freeze([{ id: "zh", label: "中文" }, { id: "en", label: "English" }])
  // e' ELE que a tela Settings -> Language mostra; sem a entrada pt o idioma
  // nunca aparece (era o motivo do pt-BR "nao funcionar" mesmo com tudo aplicado).
  if (!s.includes("Português")) {
    s = s.replace(/(\bLOCALES\s*=\s*Object\.freeze\(\[)([\s\S]*?)(\]\))/, (m, a, b, c) => {
      if (b.includes('id: "pt"') || b.includes("Português")) return m;
      return a + b.replace(/\s*$/, "") + ', { id: "pt", label: "Português" }' + c;
    });
    // lista simples de ids (versoes intermediarias)
    s = s.replace(/(\bconst LOCALES\s*=\s*\[)([^\]]*)(\])/, (m, a, b, c) => {
      if (b.includes('"pt"') || b.includes("Português")) return m;
      return a + b.replace(/\s*$/, "") + (b.trim().endsWith(",") ? "" : ", ") + '"pt"' + c;
    });
  }
  // <html lang> → pt-BR: formato novo (mapa DOCUMENT_LANGUAGE) e antigo (ternario)
  s = s.replace(/(\bDOCUMENT_LANGUAGE\s*=\s*\{)([\s\S]*?)(\};)/, (m, a, b, c) =>
    /(^|[\s{,])pt\s*:/.test(b) ? m : a + b.replace(/\s*$/, "") + ', pt: "pt-BR"' + c);
  // html lang → pt-BR
  s = s.replace(/document\.documentElement\.lang\s*=\s*snapshot\.active\s*===\s*"zh"\s*\?\s*"zh-CN"\s*:\s*snapshot\.active/g,
    'document.documentElement.lang = snapshot.active === "zh" ? "zh-CN" : snapshot.active === "pt" ? "pt-BR" : snapshot.active');
  // registros comuns: register(ns, { zh, en }) ou ({ zh, en }) perto de pt dicts
  s = s.replace(/(register\([^,]+,\s*\{\s*)(zh[\s\S]{0,200}?en)(\s*\}\))/g, (m, a, b, c) => {
    if (b.includes("pt")) return m;
    const lastEn = b.lastIndexOf("en");
    return a + b.slice(0, lastEn + 2) + ", pt" + b.slice(lastEn + 2) + c;
  });
  if (s !== before) {
    writePatched(fp, s);
    if (!jsOk(fp)) {
      const bak = fp + ".dshbak";
      if (fs.existsSync(bak)) fs.copyFileSync(bak, fp);
      report("⚠ encanamento do locale revertido (sintaxe invalida) em client.js");
    } else { steps++; report("✔ rótulo Português/lang pt-BR/registros ajustados em client.js"); }
  }
}
report(`etapas de encanamento: ${steps}`);

// ── 4) dup-guard: locale.register tolera locale repetido (mantém o primeiro) ──
{
  const f = path.join(loc, "client.js");
  if (fs.existsSync(f)) {
    let t = fs.readFileSync(f, "utf8");
    const before = t;
    const old = 'for (const [locale] of pairs) if (locales.has(locale)) throw new Error(`locale namespace "${ns}" already has locale "${locale}"`);';
    if (t.includes(old)) {
      t = t.replace(old, 'for (const [locale] of pairs) if (locales.has(locale)) continue; // dup-safe: mantém o primeiro');
    } else {
      // forma sem backticks/curinga
      const re = /for \(const \[locale\] of pairs\) if \(locales\.has\(locale\)\) throw new Error\([^;]+\);/;
      if (re.test(t)) t = t.replace(re, 'for (const [locale] of pairs) if (locales.has(locale)) continue; // dup-safe: mantém o primeiro');
    }
    if (t !== before) { writePatched(f, t); report("✔ dup-guard aplicado (locale.register tolera duplicata)"); }
    else report("ℹ dup-guard: padrão não encontrado (versão nova do locale?)");
  }
}

// ── 3) reparo de chaves: preenche no dict `pt` qualquer chave `en`
//    traduzível (por valor) que ainda faltar ────────────────────────────
let fixed = 0;
(function repair(root) {
  const files = [];
  (function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (e.name !== "node_modules" && !e.name.startsWith(".")) walk(p); }
      else if (e.name === "client.js") files.push(p);
    }
  })(root);
  const dictsOf = (t, lang) => {
    const out = [];
    const re = new RegExp(`const (${lang})(?:\\$\\d+)?\\s*=\\s*\\{`, "g");
    let m;
    while ((m = re.exec(t)) !== null) {
      const open = t.indexOf("{", m.index);
      const { map } = parseDict(t, open);
      if (map) out.push({ name: m[0].slice("const ".length, m[0].indexOf(" =")), map });
    }
    return out;
  };
  for (const f of files) {
    if (skipped(f)) continue;
    let t = fs.readFileSync(f, "utf8");
    const t0 = t;
    let changed = false;
    const enDicts = dictsOf(t, "en");
    if (!enDicts.length) continue;
    // dictsOf(t,"pt") era recalculado DENTRO do laco (uma vez por dicionario
    // `en`), e cada passada re-escaneava o arquivo inteiro re-parseando todos
    // os dicionarios: num bundle de 6,6 MB isso e n_en x n_pt x custo(arquivo).
    // Cada `pt` so e editado pelo `en` de mesmo sufixo, entao indexar uma vez
    // por arquivo da exatamente o mesmo resultado.
    const ptByName = new Map(dictsOf(t, "pt").map((p) => [p.name, p]));
    for (const en of enDicts) {
      const ptName = "pt" + en.name.slice(2);
      const pts = ptByName.get(ptName);
      if (!pts) continue;
      const missing = Object.keys(en.map).filter((k) => pts.map[k] === undefined && PHRASES[en.map[k]] !== undefined);
      if (!missing.length) continue;
      const open = t.indexOf("const " + ptName + " = {");
      const bodyStart = t.indexOf("{", open) + 1;
      const { end } = findObject(t, bodyStart - 1);
      const indentMatch = /^\s*/m;
      const firstLine = t.slice(open, t.indexOf("\n", open));
      const indent = firstLine.replace(/const .*\{/, "").replace(/\S.*/, "") + "\t";
      let ins = "";
      for (const k of missing) ins += `\n${indent}${JSON.stringify(k)}: ${JSON.stringify(PHRASES[en.map[k]])},`;
      t = t.slice(0, end - 1) + ins + "\n" + t.slice(end - 1);
      fixed += missing.length;
      changed = true;
    }
    if (changed) {
      writePatched(f, t);
      if (!jsOk(f)) { fs.writeFileSync(f, t0); report(`⚠ reparo revertido (sintaxe) em ${path.relative(root, f)}`); }
    }
  }
})(root);
report(`chaves reparadas: ${fixed}`);

// Verificacao final: o rotulo "Português" TEM de estar no client.js do locale,
// senao a UI nunca oferece o idioma (fail loud em vez de sucesso silencioso).
{
  let temRotulo = false;
  try { temRotulo = fs.readFileSync(path.join(loc, "client.js"), "utf8").includes("Português"); } catch { }
  if (!temRotulo) {
    console.error("⚠ pt-ride: idioma pt-BR NAO registrado (rotulo 'Português' ausente).");
    console.error("  O formato do locale deste core pode ter mudado — ajuste os padroes em pt-ride.mjs.");
    process.exitCode = 1;
  } else {
    report("✔ idioma pt-BR registrado (rotulo 'Português' presente)");
  }
}
console.log("✔ pt-ride concluído.");
