#!/usr/bin/env python3
"""
Regenera openrouter-enhanced-data.json a partir da API do OpenRouter.

Fontes:
  - GET https://openrouter.ai/api/v1/models          (lista de modelos + pricing)
  - GET https://openrouter.ai/api/v1/models/{id}/endpoints
      com Authorization Bearer <OPENROUTER_API_KEY> (provedores + pricing +
      latency_last_30m + throughput_last_30m + uptime + status por endpoint)

Gera os objetos de modelo pi-ai (id/name/description/compat) usados pelo
plugin openrouter-enhanced. A descricao carrega: preco por 1M, latencia p50,
throughput p50 e uptime. A variante mais barata de cada modelo ganha o selo
"💰" no nome.

Uso:  python3 regenerate-openrouter-data.py
"""
import json
import re
import time
import urllib.request

BASE_URL = "https://openrouter.ai/api/v1"
OUT = __file__.rsplit("/", 1)[0] + "/openrouter-enhanced-data.json"

# ---------------------------------------------------------------------------
# resolucao de dependencias (catalogo pi-ai instalado)
# ---------------------------------------------------------------------------
CANDIDATE_LIBS = [
    "/opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/lib/",
    "/usr/lib/node_modules/@deepseek-ai/dsh/lib/",
]
CAT = {}
for lib in CANDIDATE_LIBS:
    try:
        with open(lib.replace("lib/", "node_modules/@earendil-works/pi-ai/dist/providers/data/openrouter.json")) as f:
            CAT = json.load(f)["openai-completions"]
        break
    except OSError:
        continue

CRED_FILE = __file__.rsplit("/", 1)[0] + "/.credentials.yaml"
API_KEY = ""
try:
    import yaml  # pyyaml normalmente presente no grafo do CLI
    API_KEY = yaml.safe_load(open(CRED_FILE))["refs"].get("OPENROUTER_API_KEY") or ""
except Exception:
    pass
if not API_KEY:
    print("AVISO: OPENROUTER_API_KEY nao encontrada em", CRED_FILE,
          "- latencia/throughput/uptime nao serao capturados")

OFFICIAL = {
    "anthropic/": "Anthropic", "openai/": "OpenAI", "google/": "Google", "deepseek/": "DeepSeek",
    "meta-llama/": "Meta", "mistralai/": "Mistral", "qwen/": "Alibaba", "x-ai/": "xAI",
    "moonshotai/": "Moonshot AI", "z-ai/": "Z.AI", "nvidia/": "NVIDIA", "minimax/": "Minimax",
    "liquid/": "Liquid", "cohere/": "Cohere", "amazon/": "Amazon", "openrouter/": "OpenRouter",
    "thinkingmachines/": "Thinking Machines", "inclusionai/": "Inclusion AI", "poolside/": "Poolside",
}
MAX_ENDPOINT_VARIANTS = 6
CURATED = [
    "anthropic/claude-3.5-sonnet", "anthropic/claude-3.5-haiku", "anthropic/claude-3.7-sonnet",
    "anthropic/claude-sonnet-4", "anthropic/claude-opus-4", "anthropic/claude-4.5-sonnet",
    "anthropic/claude-haiku-4.5", "anthropic/claude-3-haiku",
    "openai/gpt-4o", "openai/gpt-4o-mini", "openai/gpt-4.1", "openai/gpt-4.1-mini",
    "openai/o3", "openai/o3-mini", "openai/o4-mini", "openai/gpt-5", "openai/gpt-5-mini",
    "google/gemini-2.5-pro", "google/gemini-2.5-flash", "google/gemini-3-pro", "google/gemini-3-flash",
    "google/gemini-2.0-flash", "deepseek/deepseek-chat", "deepseek/deepseek-reasoner",
    "deepseek/deepseek-r1", "deepseek/deepseek-v3", "meta-llama/llama-3.3-70b-instruct",
    "meta-llama/llama-3.1-8b-instruct", "qwen/qwen-3-235b-a22b", "qwen/qwen3.5-max", "qwen/qwen3.5-plus",
    "mistralai/mistral-large", "mistralai/mistral-small", "x-ai/grok-4", "x-ai/grok-3",
    "moonshotai/kimi-k2", "moonshotai/kimi-k2-thinking", "z-ai/glm-4.6", "z-ai/glm-5", "z-ai/glm-5.2",
    "nvidia/nemotron-3-super-120b-a12b", "nvidia/nemotron-3-ultra-550b-a55b",
    "minimax/minimax-m2.7", "minimax/minimax-m3", "openai/gpt-oss-20b", "openai/gpt-oss-120b",
]


def get_json(url, user_agent=False):
    headers = {}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"
    if user_agent:
        headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"
    req = urllib.request.Request(url, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                return json.load(r)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1)


def get_html(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode("utf-8", errors="replace")
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1)


# cache de data_policy/quantization extraidos da pagina web do modelo
_policy_cache = {}


def provider_policies(mid):
    """{provider_slug: {retainsPrompts, retentionDays, training, quantization}} do HTML do modelo."""
    if mid in _policy_cache:
        return _policy_cache[mid]
    out = {}
    try:
        html = get_html(f"https://openrouter.ai/{mid}")
        # pares provider_slug + data_policy + quantization no JSON escapado do Next.js
        for m in re.finditer(r'provider_slug\\":\\"([^\\"]+)', html):
            slug = m.group(1)
            seg = html[m.end():m.end() + 8000]
            dm = re.search(r'data_policy\\":', seg)
            if not dm:
                continue
            start = seg.find("{", dm.start())
            depth = 0
            i = start
            while i < len(seg):
                if seg[i] == "{":
                    depth += 1
                elif seg[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            raw = seg[start:i + 1].replace('\\"', '"').replace("\\\\", "\\")
            try:
                dp = json.loads(raw)
            except Exception:
                continue
            qm = re.search(r'quantization\\":\\"([^\\"]+)', seg)
            out[slug] = {
                "retainsPrompts": bool(dp.get("retainsPrompts")),
                "retentionDays": dp.get("retentionDays"),
                "training": bool(dp.get("training") or dp.get("trainingOpenRouter")),
                "quantization": qm.group(1) if qm else None,
            }
    except Exception:
        pass
    _policy_cache[mid] = out
    return out


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "provider"


def official_of(mid):
    for prefix, name in OFFICIAL.items():
        if mid.startswith(prefix):
            return name
    return None


def mod_input(mods):
    out = ["text"] if "text" in mods else []
    if "image" in mods:
        out.append("image")
    return out


def intelligence_of(mid, name, price_in, price_out, context):
    """Grau de inteligencia heuristico (1-5): classe da familia do modelo +
    preco relativo + contexto. Sem benchmark uniforme da API, e a melhor
    aproximacao de sites de comparacao:
      5 = flagship/raciocinio top (opus, sonnet max, gpt-5, o3, gemini pro, m3...)
      4 = forte (pro/max/plus/thinking, claude sonnet, gpt-4.1...)
      3 = medio (chat, flash alto, 70B+, mistral large...)
      2 = basico (mini/lite/flash/small/8b...)
      1 = compacto/legado
    """
    n = (name or mid or "").lower()
    def has(*words):
        return any(w in n for w in words)
    base = 3
    if has("opus", "gpt-5", "o3", "o4", "gemini-3", "gemini-2.5-pro", "max-m3", "minimax-m3", "kimi-k2-thinking", "claude-sonnet-4", "claude-4", "grok-4"):
        base = 5
    elif has("pro", "max", "plus", "thinking", "sonnet", "gpt-4.1", "gpt-4o", "glm-4.6", "glm-5", "mistral-large", "llama-3.3", "nemotron-ultra", "qwen-3-235b", "qwen3.5-max"):
        base = 4
    elif has("mini", "lite", "flash", "small", "8b", "7b", "9b", "13b", "haiku", "fast", "m2.5", "m2.7", "gpt-oss-20b", "llama-3.1-8b"):
        base = 2
    elif has("1b", "3b", "4b", "nano", "tiny", "legacy", "old"):
        base = 1
    # ajuste fino por preco: modelos caros tendem a ser mais capazes
    price = (price_in or 0) + (price_out or 0)
    if price >= 10:
        base = min(5, base + 1)
    elif price >= 3:
        base = min(5, base)
    elif base >= 4 and price < 1:
        base = 3  # "pro" barato demais para ser top
    if context and context >= 500000:
        base = min(5, base + 1)
    return max(1, min(5, base))


def cost_from_api(p):
    f = lambda k: float(p.get(k, 0) or 0) * 1_000_000
    return {"input": f("prompt"), "output": f("completion"),
            "cacheRead": f("input_cache_read"), "cacheWrite": f("input_cache_write")}


def fmt_usd(v):
    """Formata dolar por 1M de tokens de forma curta."""
    if v <= 0:
        return "0"
    if v >= 1:
        return f"${v:.2f}".rstrip("0").rstrip(".")
    return f"${v:.3f}".rstrip("0").rstrip(".")


def description_for(price, latency_ms, tps, uptime, status, quantization=None, policy=None, label=None):
    parts = []
    if price and price.get("input") == 0 and price.get("output") == 0:
        parts.append("Grátis")
    elif price:
        parts.append(f"{fmt_usd(price['input'])}/{fmt_usd(price['output'])}/1M")
    if quantization and quantization not in ("unknown", "Unknown", "", "none"):
        parts.append(quantization)
    if latency_ms:
        parts.append(f"lat {round(latency_ms)}ms")
    if tps:
        parts.append(f"{round(tps)} tok/s")
    if uptime:
        parts.append(f"up {round(uptime, 1)}%")
    if status is not None and status != 0:
        parts.append("OFFLINE")
    if policy is not None:
        if policy.get("training"):
            parts.append("treina c/ dados")
        elif policy.get("retainsPrompts"):
            days = policy.get("retentionDays")
            parts.append(f"retém {days}d" if days else "retém prompts")
        else:
            parts.append("zero retenção")
    if label:
        parts.append(f"[{label}]")
    return " · ".join(parts)


def quality_score(meta, priced_metas):
    """Classifica a opcao entre as do MESMO modelo usando ESTRELAS (glifos
    universais, renderizam em qualquer fonte — inclusive Chrome no Linux sem
    fonte de emoji colorido):
      ★★★ = melhores (melhor preço+velocidade+latência)
      ★★  = intermediarios (padrao)
      ★   = evitar (só com problema claro: OFFLINE, uptime baixo, muito lento)
    Retorna (estrelas, rotulo)."""
    if not meta or not meta.get("price"):
        return "★★", "sem métricas"
    usable = [m for m in priced_metas if m and m.get("price")]
    if len(usable) < 2:
        return "★★★", "única opção"

    # problemas claros -> vermelho
    if meta.get("status") not in (None, 0):
        return "★", "evitar"
    up = meta.get("uptime")
    if up is not None and up < 90:
        return "★", "evitar"

    price = meta["price"]["input"] + meta["price"]["output"]

    def rel_of(value, key, reverse=False):
        vals = [m.get(key) for m in usable if m.get(key) is not None]
        if not vals or value is None:
            return None
        s = sorted(vals, reverse=reverse)
        if value not in s:
            return None
        n = len(s)
        return s.index(value) / max(n - 1, 1)

    prices = [m["price"]["input"] + m["price"]["output"] for m in usable if m.get("price")]
    rels = []
    if prices and price in prices:
        n = len(prices)
        rels.append(sorted(prices).index(price) / max(n - 1, 1))
    rels += [r for r in (rel_of(meta.get("latencyMs"), "latencyMs"), rel_of(meta.get("tps"), "tps", True), rel_of(meta.get("uptime"), "uptime", True)) if r is not None]
    if not rels:
        return "★★", "sem métricas"
    avg = sum(rels) / len(rels)
    # verde para os melhores (top ~35%); o resto fica neutro; vermelho só com problema
    if avg <= 0.35:
        return "★★★", "melhor"
    return "★★", "intermediário"


def base_model(mid, provider_id):
    if mid in CAT:
        m = dict(CAT[mid])
        m["provider"] = provider_id
        m["baseUrl"] = BASE_URL
        return m
    a = API_BY_ID.get(mid)
    if a is None:
        return None
    mods = (a.get("architecture") or {}).get("input_modalities", [])
    reas = a.get("reasoning") or {}
    efforts = reas.get("supported_efforts") or []
    top = a.get("top_provider") or {}
    pricing = a.get("pricing") or {}
    price_in = float(pricing.get("prompt", 0) or 0) * 1e6
    price_out = float(pricing.get("completion", 0) or 0) * 1e6
    return {
        "id": mid, "name": a.get("name") or mid, "api": "openai-completions",
        "provider": provider_id, "baseUrl": BASE_URL, "reasoning": bool(reas or efforts),
        **({"thinkingLevelMap": {"off": None, **{l: l for l in efforts if l != "off"}}} if efforts else {}),
        "input": mod_input(mods) or ["text"],
        "cost": cost_from_api(pricing),
        "contextWindow": a.get("context_length") or 262144,
        # MiniMax-M3 backend rejeita max_tokens > 524288 (erro 2013); cap global de seguranca
        "maxTokens": min(top.get("max_completion_tokens") or 8192, 524288),
        "intelligence": intelligence_of(mid, a.get("name"), price_in, price_out, a.get("context_length")),
        "compat": {"thinkingFormat": "openrouter"},
    }


def endpoint_meta(eps, policies=None):
    """provider_name -> {price, latencyMs, tps, uptime, status, tag, quantization, policy}"""
    out = {}
    policies = policies or {}
    for e in eps:
        name = e.get("provider_name")
        if not name or name in out:
            continue
        p = e.get("pricing") or {}
        lat = e.get("latency_last_30m") or {}
        tp = e.get("throughput_last_30m") or {}
        slug = e.get("tag") or slugify(name)
        out[name] = {
            "tag": slug,
            "price": {"input": float(p.get("prompt", 0) or 0) * 1e6,
                      "output": float(p.get("completion", 0) or 0) * 1e6},
            "latencyMs": lat.get("p50"),
            "tps": tp.get("p50"),
            "uptime": e.get("uptime_last_5m"),
            "status": e.get("status"),
            "quantization": e.get("quantization"),
            "policy": policies.get(slug),
        }
    return out


def with_routing(model, order):
    m = dict(model)
    m["compat"] = {**(model.get("compat") or {}), "openRouterRouting": {"order": order}}
    return m


# ---------------------------------------------------------------------------
print("carregando lista de modelos do OpenRouter...")
API_BY_ID = {m["id"]: m for m in get_json(f"{BASE_URL}/models")["data"]}

free_ids = [m["id"] for m in API_BY_ID.values()
            if float(m["pricing"].get("prompt", 1) or 1) == 0
            and float(m["pricing"].get("completion", 1) or 1) == 0]

picked = []
for pattern in CURATED:
    matches = [m for m in API_BY_ID if m == pattern or m.startswith(pattern + "-") or m.startswith(pattern + ":")]
    if matches:
        picked.append(matches[0])
picked = sorted(set(picked))

# --- grupo free ------------------------------------------------------------
free_models = []
for mid in sorted(free_ids):
    a = API_BY_ID.get(mid)
    if not a or "text" not in (a.get("architecture") or {}).get("input_modalities", []):
        continue
    bm = base_model(mid, "openrouter-free")
    if not bm:
        continue
    try:
        eps = get_json(f"{BASE_URL}/models/{mid}/endpoints").get("data", {}).get("endpoints", [])
    except Exception:
        eps = []
    policies = provider_policies(mid)
    metas = endpoint_meta(eps, policies)
    if metas:
        priced = [m for m in metas.values() if m and m.get("price")]
        best = min(priced, key=lambda m: m["price"]["input"] + m["price"]["output"]) if priced else None
        if best:
            _stars, label = quality_score(best, priced)
            bm["description"] = description_for(
                best["price"], best["latencyMs"], best["tps"], best["uptime"], best["status"],
                best.get("quantization"), best.get("policy"), label)
    free_models.append(bm)

# --- grupo pro --------------------------------------------------------------
variant_map = {}
pro_models = []
for real_id in picked:
    bm = base_model(real_id, "openrouter-pro")
    if bm is None:
        continue
    try:
        eps = get_json(f"{BASE_URL}/models/{real_id}/endpoints").get("data", {}).get("endpoints", [])
    except Exception:
        eps = []
    policies = provider_policies(real_id)
    metas = endpoint_meta(eps, policies)
    official = official_of(real_id)

    # entrada "auto" (roteamento padrao do OpenRouter)
    auto = dict(bm)
    auto["id"] = real_id
    pro_models.append(auto)

    # variantes por provedor
    candidates = []  # (name, meta, is_official)
    if official:
        candidates.append((official, metas.get(official), True))
    seen = set()
    for name, meta in metas.items():
        if name == official or name in seen:
            continue
        seen.add(name)
        candidates.append((name, meta, False))

    priced = [(name, meta) for name, meta, _ in candidates if meta and meta["price"]]
    priced_metas = [meta for _, meta in priced]
    cheapest = min(priced, key=lambda nm: nm[1]["price"]["input"] + nm[1]["price"]["output"])[0] if priced else None

    for name, meta, _is_official in candidates[: 1 + MAX_ENDPOINT_VARIANTS]:
        if name == official and meta is None:
            continue  # provedor oficial sem metrica na lista de endpoints: coberto pelo "auto"
        tag = meta["tag"] if meta else slugify(name)
        vid = f"{real_id}@{tag}"
        if vid in variant_map:
            continue
        v = with_routing(bm, [name])
        v["id"] = vid
        stars, label = quality_score(meta, priced_metas) if meta else ("★★", "sem métricas")
        vname = f"{bm['name']} — via {name}"
        if meta and name == cheapest:
            vname = "(barato) " + vname
        v["name"] = f"{stars} {vname}"
        if meta:
            v["description"] = description_for(
                meta["price"], meta["latencyMs"], meta["tps"], meta["uptime"], meta["status"],
                meta.get("quantization"), meta.get("policy"), label)
        pro_models.append(v)
        variant_map[vid] = {"realId": real_id, "name": vname, "routing": {"order": [name]}, "base": bm}

out = {
    "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "freeModels": free_models,
    "proModels": pro_models,
    "variantMap": variant_map,
}
with open(OUT, "w") as f:
    json.dump(out, f, indent=1)
print(f"OK: free={len(free_models)} pro={len(pro_models)} variantes={len(variant_map)} -> {OUT}")
