#!/usr/bin/env node
/**
 * ptlib.mjs — funções compartilhadas de leitura dos dicionários compilados
 * de locale do núcleo (core-i18n-pt). Usado por build-pt-patches.mjs e
 * dump-en-phrases.mjs.
 *
 * Os dicionários compilados podem ter:
 *   • chaves com ou sem aspas (nav: "…" ou "nav": "…");
 *   • valores que referenciam constantes de string do próprio arquivo
 *     (ex.: "welcomeTitle": WELCOME_NOTICE_COPY.en.title — com caminho);
 *   • valores com aspas/quebras internas.
 */

/** Remove comentários // e /* *​/ (fora de strings). */
export function stripComments(src) {
  let out = "";
  for (let i = 0; i < src.length; i++) {
    if (src[i] === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (src[i] === "/" && src[i + 1] === "*") { const e = src.indexOf("*/", i + 2); i = e === -1 ? src.length : e + 1; continue; }
    out += src[i];
  }
  return out;
}

/** Coloca aspas em chaves identificadoras, sem tocar em texto dentro de strings. */
export function quoteKeys(src) {
  let out = "";
  let inStr = false;
  for (let i = 0; i < src.length; i++) {
    const c = src[i];
    if (inStr) {
      out += c;
      if (c === "\\") { if (i + 1 < src.length) { out += src[i + 1]; i++; } }
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; out += c; continue; }
    const prev = i === 0 ? "" : src[i - 1];
    if (/[A-Za-z_$]/.test(c) && !/[\w$]/.test(prev)) {
      const mm = /^[A-Za-z_$][\w$]*\s*:/.exec(src.slice(i));
      if (mm) {
        const name = mm[0].replace(/\s*:$/, "");
        out += JSON.stringify(name) + ":";
        i += mm[0].length - 1;
        continue;
      }
    }
    out += c;
  }
  return out;
}

/** Acha o fim de "{ … }" a partir do "{", ciente de strings. */
export function findObject(text, openIdx) {
  let depth = 0, inStr = false;
  for (let i = openIdx; i < text.length; i++) {
    const c = text[i];
    if (inStr) {
      if (c === "\\") { i++; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; continue; }
    if (c === "{") depth++;
    else if (c === "}") { depth--; if (depth === 0) return { end: i + 1 }; }
  }
  throw new Error("objeto sem fechamento");
}

/** Constantes de string do arquivo (const NOME = "…"). */
export function collectStringConsts(text) {
  const defs = {};
  const re = /const\s+([A-Za-z_$][\w$]*)\s*=\s*("(?:[^"\\]|\\.)*")/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    try { defs[m[1]] = JSON.parse(m[2]); } catch { /* não-string */ }
  }
  return defs;
}

/**
 * Constantes de string OU objeto (const NOME = { … }) do arquivo, para
 * resolver valores como WELCOME_NOTICE_COPY.en.title.
 */
export function collectConsts(text) {
  const defs = collectStringConsts(text);
  const re = /const\s+([A-Za-z_$][\w$]*)\s*=\s*\{/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const open = text.indexOf("{", m.index);
    try {
      const { end } = findObject(text, open);
      const body = text.slice(open + 1, end - 1);
      const obj = JSON.parse("{" + dropTrailingCommas(quoteKeys(stripComments(body))) + "}");
      defs[m[1]] = obj;
    } catch { /* ignora */ }
  }
  return defs;
}

/** Substitui valores-identificador/caminho (fora de strings) pelas constantes. */
export function resolveIdentifiers(body, defs) {
  let out = "";
  let inStr = false;
  const lookup = (root, path) => {
    let v = defs[root];
    if (v === undefined) return { ok: false };
    for (const part of path) {
      if (v === null || typeof v !== "object") return { ok: false };
      v = v[part];
      if (v === undefined) return { ok: false };
    }
    return { ok: typeof v === "string", value: v };
  };
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (inStr) {
      out += c;
      if (c === "\\") { if (i + 1 < body.length) { out += body[i + 1]; i++; } }
      else if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; out += c; continue; }
    if (/[A-Za-z_]/.test(c)) {
      const mm = /^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*/.exec(body.slice(i));
      if (mm) {
        const token = mm[0];
        const [root, ...path] = token.split(".");
        if (defs[root] !== undefined) {
          const r = lookup(root, path);
          if (r.ok) { out += JSON.stringify(r.value); i += token.length - 1; continue; }
        }
      }
    }
    out += c;
  }
  return out;
}

/** Remove vírgulas finais (JS permite; JSON não) antes do parse. */
function dropTrailingCommas(s) {
  return s.replace(/,(\s*[}\]])/g, "$1");
}

/**
 * Converte o corpo de um dicionario compilado em JSON, numa unica passada e
 * ciente de literais — corrige tres casos reais que faziam o gerador pular
 * pacotes inteiros no core 0.1.5:
 *   • strings com template literal (`` ` ``) — inclusive com `https://` dentro:
 *     o stripComments antigo via `//` da URL como comentario e cortava a string
 *     ("Bad control character in string literal");
 *   • chaves sem aspas (nav: "Models") — viram "nav": "Models";
 *   • comentarios // e /* *\/ fora de strings.
 * Valores com `${...}` sao preservados como texto (nao casam na tabela de
 * frases, mas mantem o JSON valido em vez de derrubar o dicionario todo).
 */
export function dictBodyToJson(body) {
  let out = "";
  let i = 0;
  while (i < body.length) {
    const c = body[i];
    if (c === '"') {
      let j = i + 1;
      while (j < body.length) {
        if (body[j] === "\\") { j += 2; continue; }
        if (body[j] === '"') { j++; break; }
        j++;
      }
      out += body.slice(i, j);
      i = j;
      continue;
    }
    if (c === "`") {
      let j = i + 1, txt = "";
      while (j < body.length) {
        if (body[j] === "\\") { txt += body[j] + (body[j + 1] ?? ""); j += 2; continue; }
        if (body[j] === "`") { j++; break; }
        txt += body[j];
        j++;
      }
      const unesc = txt
        .replace(/\\n/g, "\n").replace(/\\r/g, "\r").replace(/\\t/g, "\t")
        .replace(/\\`/g, "`").replace(/\\\$/g, "$").replace(/\\\\/g, "\\");
      out += JSON.stringify(unesc);
      i = j;
      continue;
    }
    if (c === "/" && body[i + 1] === "/") { while (i < body.length && body[i] !== "\n") i++; continue; }
    if (c === "/" && body[i + 1] === "*") { const e = body.indexOf("*/", i + 2); i = e === -1 ? body.length : e + 2; continue; }
    if (/[A-Za-z_$]/.test(c) && !/[\w$]/.test(i === 0 ? "" : body[i - 1])) {
      const mm = /^[A-Za-z_$][\w$]*\s*:/.exec(body.slice(i));
      if (mm) { out += JSON.stringify(mm[0].replace(/\s*:$/, "")) + ":"; i += mm[0].length; continue; }
    }
    out += c;
    i++;
  }
  return out;
}

/**
 * Expande spreads de constantes do proprio arquivo: `...PRODUCT_NAMES` vira os
 * pares chave/valor da constante (achada por collectConsts). Spread que nao
 * resolve (import, const fora do arquivo) e removido — assim o dicionario
 * continua JSON valido e as chaves explicitas ainda sao traduzidas.
 * Caso real: dsh-client-ui-open-in-app.
 */
export function expandSpreads(src, defs) {
  return src.replace(/\.\.\.\s*([A-Za-z_$][\w$]*)\s*,?/g, (m, name) => {
    const v = defs[name];
    if (v === null || typeof v !== "object" || Array.isArray(v)) return "";
    const pairs = Object.entries(v)
      .filter(([, val]) => typeof val === "string")
      .map(([k, val]) => `${JSON.stringify(k)}: ${JSON.stringify(val)}`);
    return pairs.length ? pairs.join(", ") + "," : "";
  });
}

/** Le um dicionario (objeto literal) e devolve {map, end} (map=null se falhar). */
export function parseDict(text, openIdx) {
  try {
    const { end } = findObject(text, openIdx);
    const body = text.slice(openIdx + 1, end - 1);
    const defs = collectConsts(text);
    const cleaned = resolveIdentifiers(expandSpreads(dictBodyToJson(body), defs), defs);
    const full = dropTrailingCommas("{" + cleaned + "}");
    return { map: JSON.parse(full), end };
  } catch {
    return { map: null, end: -1 };
  }
}
