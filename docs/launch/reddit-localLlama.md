# r/LocalLLaMA

## Título

```
I built a free-first model router for DeepSeek Harness: free providers tried first, automatic fallback, safe core updates (open source, unofficial)
```

## Corpo

**What it is**

FreeDSH is an unofficial distribution layer for DeepSeek Harness (MIT). It is not a fork — it is an
overlay of Harness plugins plus an installer and tooling. I am the author.

The part I actually care about is the routing. Instead of pinning my daily workflow to one
provider, FreeDSH tries the free routes first and only then the paid ones:

```
FreeLLMAPI (local gateway, :3002) -> OpenRouter :free -> OpenCode -> optional paid fallback
```

If a provider fails or becomes unavailable, the router moves on to the next configured option.
There are cost profiles (`auto`, `eco`, `balanced`, `ultra`) that pick different model tiers per
workload, so a quick rename doesn't burn the same route as a long refactor. There is a local
FreeLLMAPI gateway on port 3002 for keeping free-model keys in one place, and the UI shows the
current model and its cost.

Two things I want to be clear about, because this subreddit is exactly the right place to be
skeptical:

1. This is **not** a local inference runner, and I'm not claiming it is. No weights, no quantization,
   no llama.cpp. It is the layer around the providers you configure — including pointing at
   whatever OpenAI-compatible endpoint you control. If your reason to be here is running models
   locally, the interesting part for you is the fallback/ordering logic, not the inference.
2. FreeDSH does not create free access where none exists and does not work around provider terms.
   It aggregates and routes the keys you already have. Free tiers change constantly, so the honest
   claim is "free-first ordering", not a percentage saved.

**Other things in it**

- **Safe core updates**: the new Harness core is tested in an isolated, parallel instance before it
  replaces the working one — plus snapshots and one-click rollback. A core update should not
  destroy a working setup.
- **Auto-update**: 30-minute sync with GitHub (Task Scheduler on Windows, cron on Linux).
- **Integrated panel**: router/model badges, current model with cost, recent files, core status.
- **pt-BR localization** of the core (1078 strings) — irrelevant if you don't speak Portuguese, but
  it's why a chunk of the repo exists.

**Install (one line)**

```powershell
irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 | iex
```

Windows is the well-tested path, PowerShell 5.1 and 7.x both. Linux has an equivalent script. macOS
is untested — I don't have a machine for it. Real bugs fixed on the way: encoding/BOM handling and a
`robocopy` hang when files were in use.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1

**What's missing**

The repo is brand new: 1 star, 0 forks, 125 tags, 0 published releases. Working version is `main`.
And I have **no benchmark to show you** — no latency table, no per-provider failure rates, nothing I
would stand behind. That is the biggest gap, and I'd rather admit it than post numbers I can't
reproduce. Provider tier claims also rot fast, so anything I said about a free tier today could be
wrong next month.

**Feedback I'm after**

- Routing policy: do you want retry-then-fallback, or skip-straight-to-next? When should a failure
  be surfaced to the user instead of silently absorbed?
- Reproducible provider reports: what fields would make a report actually useful to you (date,
  provider, model, tier at test time, latency, error class)?
- Anyone here running an OpenAI-compatible endpoint locally and willing to test it as a route in the
  chain? Real reports beat my assumptions.
- If this is off-topic for this sub, say so and I'll take it elsewhere — no hard feelings.

Not affiliated with or endorsed by DeepSeek.

> **Notas de publicação**: poste em dia de semana pela manhã, entre 8h e 10h ET (terça a quinta
> funcionam melhor) — o sub é majoritariamente americano e o post tem que pegar o começo do dia.
> Use a flair de discussão (o r/LocalLLaMA usa `Discussion` / `Tutorial | Guide`; confirme as flairs
> disponíveis no dia). **Deixe explícito no post que você é o autor** — o sub remove autopromoção não
> declarada, e a linha "I am the author" já está no texto. O ponto mais delicado aqui é o encaixe
> temático: o sub é sobre modelos locais, e o FreeDSH não roda inferência local, então mantenha o
> parágrafo "this is not a local inference runner" e não tente disfarçar o projeto como algo que ele
> não é — a audiência detecta e o post morre. Não peça upvote. Não comente no seu próprio post
> pedindo visibilidade; use o thread só para responder dúvidas técnicas com dado. Se preferir, faça
> um post de "here's what I learned about free tier reliability" em vez de anúncio, e deixe o link no
> fim: costuma funcionar melhor nesse sub do que um lançamento.
