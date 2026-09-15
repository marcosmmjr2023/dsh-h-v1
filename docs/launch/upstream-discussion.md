# Discussions do DeepSeek Harness

Minuta para a área de **Discussions** do repositório upstream (`github.com/deepseek-ai/deepseek-harness`).
Issues estão **desativadas**; Discussions estão ativas. Escolha a categoria de "Show and tell" /
"Showcase" se existir; caso contrário, use a categoria geral de discussão e não uma de bug report.

## Título sugerido

```
Unofficial pt-BR + Windows distribution layer for the Harness — feedback welcome
```

## Corpo

Hi everyone,

I've been using the Harness daily and built a small unofficial distribution layer around it, mostly
to solve two problems of my own: using it in Brazilian Portuguese, and installing/updating it
comfortably on Windows. I'm sharing it here in case it's useful to anyone else in the same
situation, and to ask for feedback — not to ask for anything else.

**To be explicit: this is unofficial.** It is not affiliated with or endorsed by DeepSeek, it isn't
a fork, and it isn't trying to be the upstream project. The Harness is installed separately and is
not redistributed as part of it. FreeDSH's own code is MIT, and what that grant covers — versus what
stays upstream or third-party — is written down in `LICENSE-SCOPE.md`, outside the `LICENSE` file so
the GitHub license detection reads a clean MIT text instead of "NOASSERTION".

**What it is, architecturally**

It's an overlay — a set of Harness plugins (`smart-router-plugin`, `openrouter-enhanced-plugin`,
`model-visibility-plugin`, `freellmapi-shortcut-plugin`, `layout-panel-plugin`,
`version-badge-plugin`), plus an installer and some maintenance tooling. Everything it does to the
Harness goes through the plugin surface, so it stays out of the way of the core.

**What it adds**

- **pt-BR localization**: 1078 core strings, plus the dictionaries for the chat view, model view,
  file sidebar and the HTML/image/PDF viewers.
- **Windows installation in one command**, tested on PowerShell 5.1 and 7.x. Linux has an
  equivalent script. Along the way I hit and fixed a couple of real Windows issues — encoding/BOM
  handling and a `robocopy` hang when files were in use — which may be useful information for other
  people doing Windows tooling around the Harness.
- **Free-first model routing with automatic fallback**: it tries the free providers the user
  configured (a local FreeLLMAPI gateway on port 3002, OpenRouter `:free`, OpenCode) before any paid
  route, and moves to the next configured option when one fails. Cost profiles: `auto`, `eco`,
  `balanced`, `ultra`. It doesn't create free access where none exists — it aggregates and routes
  keys the user already has.
- **Safer core updates**: a new core version is tested in an isolated parallel instance before it
  replaces the working one, with snapshots and rollback.
- **A panel inside the UI**: router/model badges, current model with cost, recent files, core status.

**How it's distributed, as of now**

There are two paths, and both work today. The **installer** gives you everything (core install or
update, overlay, translation, shortcuts). And the overlay itself is packaged as an **installable
bundle**, so it can be added to an existing Harness install with one command, without the installer
and without copying overlay files:

```
dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1
```

(removed with `dsh plugin --profile web remove freedsh`.) It registers the six plugins listed above
and nothing else — provider credentials, settings and models stay untouched. I installed and tested
that command in a clean `DSH_HOME`: all six plugins load and their APIs answer 200. This is the
distribution path I'd expect other Harness users to prefer, since it drops straight into a setup that
already works. If you have opinions on it — what a bundle like this should or shouldn't do to a
profile, or what would make it easier to consume from the Harness side — I'd genuinely like to hear
them.

**What I'm asking for**

Only feedback. Specifically:

- whether the plugin-based overlay approach is the appropriate way to extend the Harness;
- whether the bundle (`dsh plugin --profile web add ...`) is the right packaging target to make the
  primary one, or whether the installer should stay the main path;
- any guidance on how an unofficial distribution layer should describe its relationship to the
  upstream project so it's not mistaken for an official one;
- and, if you use the Harness in a non-English locale or on Windows, whether any of these problems
  match yours.

The project is new — the repository currently has 1 star, 0 forks and 1 published release (tag
`v0.2.125`, with a source ZIP and `SHA256SUMS.txt`) — so I expect the most valuable outcome of this
thread is criticism, not adoption. Real traffic is 90 views from 11 unique visitors over the last 14
days, so I'm not pretending there's adoption to speak of.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1
Landing page (install command): https://marcosmmjr2023.github.io/dsh-h-v1/

Thanks for the Harness itself; it's the reason any of this exists.

> **Notas de publicação**: publique em dia útil, no começo da manhã no horário de Brasília (por
> volta das 9h), para pegar o começo do dia útil na Ásia, que é quando o repositório costuma ter
> mais movimento — mas trate o horário como secundário: aqui o que decide é o tom. **Não marque
> mantenedores nem use @ em ninguém**: mensagem direta para mantenedor de projeto grande é mal
> recebida. Não peça estrela, não peça para o projeto ser listado no README oficial, não peça
> endosso, e não pergunte "por que issues estão desativadas" — está fora do escopo do post. Se
> alguém responder que prefere receber isso como PR na documentação ou que o lugar certo é outro,
> agradeça e siga a orientação. Enquanto a discussão estiver viva, responda em até um dia; depois,
> deixe o thread em paz e não faça "bump" para chamar atenção. Se ninguém responder, isso não é
> rejeição: trate como "ainda não é hora" e volte em alguns meses com relatos de uso de verdade (a
> release já existe: `v0.2.125`), em um novo thread e não no antigo.
