# Hacker News (Show HN)

## Título

```
Show HN: FreeDSH – free-first model routing for DeepSeek Harness
```

## Corpo

FreeDSH is an unofficial distribution layer for DeepSeek Harness (MIT). It's not a fork — it's an
overlay of Harness plugins plus an installer and tooling.

The problem I was solving: I wanted to use Harness daily without coupling my workflow to one
provider and without paying for every task. FreeDSH routes across the providers you configure,
trying free ones first (a local FreeLLMAPI gateway on port 3002, OpenRouter `:free`, OpenCode) and
falling back to a paid route only if you added one. If a provider fails or goes unavailable, the
router moves to the next configured option. There are cost profiles (`auto`, `eco`, `balanced`,
`ultra`) for picking different model tiers per workload.

It doesn't create free access where none exists. It aggregates and routes the keys and providers
you already have, and free tiers change, so I don't claim anything about cost savings beyond
"free-first ordering".

Other things in it:

- safe core updates: the new core version is tested in an isolated parallel instance before it
  replaces the working one, with snapshots and one-click rollback;
- auto-update on a 30-minute sync (Task Scheduler on Windows, cron on Linux);
- an integrated panel inside the Harness UI (router/model badges, current model with cost, recent
  files, core status);
- a full pt-BR localization of the core: 1078 strings, plus the dictionaries for the chat, model,
  file sidebar and HTML/image/PDF viewers, and a `README.pt-BR.md`.

Install (Windows, PowerShell 5.1 and 7.x are both tested):

```powershell
irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 | iex
```

The installer downloads the core, applies the overlay, applies the translation and creates
shortcuts. Linux has an equivalent script. A couple of real bugs got fixed along the way, notably
encoding/BOM handling and a `robocopy` hang when files were in use.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1

What's missing, honestly: the repo is brand new — 1 star, 0 forks, 0 published releases, and no
macOS testing. There is no benchmark publishable yet, so I have no latency or cost numbers I'd
stand behind. I'd rather say that than quote numbers I can't reproduce.

Not affiliated with or endorsed by DeepSeek.

Feedback I'm looking for: whether the router's fallback behavior is right (retry vs. skip, when to
surface a failure to the user), how you'd want provider compatibility reports structured, and
whether packaging the overlay as a single installable bundle (`dsh plugin add`) is the right call
versus keeping the installer.

> **Notas de publicação**: poste de terça a quinta, entre 8h e 10h ET — o HN é majoritariamente
> americano e o post precisa pegar a manhã deles. O título **tem que começar exatamente com
> `Show HN:`**, é o único "flair" que existe aqui, e não mude o título depois de publicar (edição de
> título derruba o post). Sem emoji, sem hashtag, sem imagem obrigatória. **Nunca peça upvote ou
> comentário** — o HN detecta e penaliza voto combinado. Fique presente no thread nas primeiras
> 2 horas e responda tudo: nesse canal o autor na discussão vale mais que o post. Espere e não se
> ofenda com: "how is this different from just using OpenRouter?" (responda com o que é seu —
> roteador, fallback, updater, tradução), "why not just use X", e a crítica de que overlay não
> oficial é fragmentação (agradeça, é um risco real). Não use adjetivo de marketing nas respostas e
> não cite contagem de estrelas como evidência de qualidade. Se o post não decolar, **não reposte na
> mesma semana nem com o texto idêntico**: o HN tolera uma segunda tentativa apenas quando não houve
> discussão nenhuma, e ainda assim exige intervalo e ângulo novo (por exemplo, liderar pelo problema
> de atualização segura do core em vez do lançamento). Trate o resultado do HN como diagnóstico do
> onboarding, não como veredito do projeto.
