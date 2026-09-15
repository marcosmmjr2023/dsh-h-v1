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
powershell -ExecutionPolicy Bypass -Command "$f=\"$env:TEMP\dsh-setup.ps1\"; irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 -Headers @{'Cache-Control'='no-cache'} -OutFile $f; & $f"
```

That long single line is deliberate: it downloads the script to a temp file with a no-cache header.
The short `irm ... | iex` form can serve a stale copy and trips over encoding/BOM in PowerShell 5.1.

The installer downloads the core, applies the overlay, applies the translation and creates
shortcuts. Linux has an equivalent script. A couple of real bugs got fixed along the way, notably
encoding/BOM handling and a `robocopy` hang when files were in use.

If you already run Harness and only want the plugins, the overlay also ships as a **DSH bundle**, with
no installer and no overlay copying:

```
dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1
```

Remove it with `dsh plugin --profile web remove freedsh`. The bundle registers six Harness plugins
(smart router, OpenRouter groups, model visibility, FreeLLMAPI shortcut, right-hand panel, version
badge) and nothing else — it never touches your keys, providers or settings. I installed and tested it
in a clean `DSH_HOME`: all six plugins load and their APIs answer 200.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1
Landing page (canonical install command): https://marcosmmjr2023.github.io/dsh-h-v1/

What's missing, honestly: the repo is brand new — 1 star, 0 forks, 1 published release (`v0.2.125`,
ZIP + SHA256SUMS) — and there is no macOS testing. Discovery is close to nothing: 90 views from **11
unique visitors** in the last 14 days. There is no benchmark publishable yet, so I have no latency or
cost numbers I'd stand behind. I'd rather say that than quote numbers I can't reproduce.

The FreeDSH code is MIT, like the Harness; what that grant covers (and what stays upstream) is in
`LICENSE-SCOPE.md`. Not affiliated with or endorsed by DeepSeek.

Feedback I'm looking for: whether the router's fallback behavior is right (retry vs. skip, when to
surface a failure to the user), how you'd want provider compatibility reports structured, and whether
the bundle route (`dsh plugin --profile web add ...`) should be the primary way to consume this
instead of the installer — it is already packaged and tested that way, so I'm mostly asking which one
you would reach for.

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
