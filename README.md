# 🐋 dsh-h-v1 — A camada que torna o DeepSeek Harness **grátis na prática**, flexível e ótimo de usar

**dsh-h-v1** vira o [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) em um assistente que você **realmente usa todos os dias, sem assinatura**: roda dezenas de **modelos gratuitos** (FreeLLMAPI, OpenRouter `:free`, OpenCode free/zen) com roteamento e fallback automáticos, traz uma **interface em pt-BR** (que acompanha o idioma do sistema: pt/zh/en), um **painel lateral com badges**, e **atualiza o core com segurança** (instância paralela com progresso ao vivo — o sistema em execução nunca é tocado).

> ⚙️ Construído sobre [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) ("*Everything is a Plugin*").
> **Não oficial** — uma distribuição pessoal, sem afiliação com a DeepSeek.

---

### ✨ Por que você vai querer usar

| | O que você ganha |
|---|---|
| 🎁 **Modelos gratuitos, de verdade** | Gateway **FreeLLMAPI** + roteador inteligente (**OpenRouter `:free`**, **OpenCode free/zen**) com fallback automático — explore a onda de modelos grátis sem criar planos pagos |
| 🖥️ **Painel próprio** | Menu lateral com arquivos recentes, status do core, FreeLLMAPI, Roteador e Modelos — tudo a um clique, sem abrir janelas soltas |
| 🌎 **Idioma que segue você** | Interface em **português (pt-BR)**, chinês ou inglês conforme o idioma do seu sistema (padrão: inglês) |
| 🛡️ **Core novo sem medo** | Clique em “Atualizar”: cria uma **instância paralela** com o core novo (com **progresso em tempo real**), você testa e **desinstala** com um botão — o que já está rodando continua intacto |
| 🧩 **Sua camada, versionada** | Settings, plugins e presets como **código**: git, tags `vX.Y.Z`, changelog e **rollback seguro**; sincronizado entre todas as suas máquinas |
| 💻 **Windows e Linux** | Instaladores **interativos em 1 linha** (detectam o que existe, idioma, chaves) — a mesma experiência nos dois sistemas |

**Comece em 1 minuto** 👉 [Instalar e rodar](#-install--run-end-user)

## 💻 Install & run (end user)

> This is the **landing page**. Detailed manuals: [Linux/server map](docs/SERVER-MAP.md) ·
> [core update / A/B instances](docs/CORE-UPDATE.md) · [Windows (PT)](docs/WINDOWS-PT.md) ·
> [Windows (EN)](docs/WINDOWS.md) · [two-way sync](docs/SYNC.md).

### Windows (one line — interactive installer)

```powershell
irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 | iex
```

It detects what is installed (repo, core, config, FreeLLMAPI, instances, `dsh` command), then lets you
choose: **1)** clean install from scratch · **2)** clean install **keeping your API keys/configs**
(`.credentials.yaml`, `settings.yaml`, `llm-*`, FreeLLMAPI db) · **3)** update existing · **4)** manage
instances (list/remove) · **5)** open the GUI.

Non-interactive: `installer/install-windows.ps1 | iex` (full install: core + pt-BR + overlay + FreeLLMAPI +
desktop/start-menu shortcuts + GUI). Afterwards, in a **new** PowerShell:

```powershell
dsh up            # open the GUI (own app window, port 3081)
dsh update        # pull repo + pinned core + pt-BR + overlay
dsh flm-setup     # FreeLLMAPI gateway (port 3002) + admin (admin@example.com / Freellmapi@2026)
dsh doctor        # diagnostics
dsh env list      # parallel instances and their ports
```

The GUI itself (chip in the core badge) can **create a parallel instance with a new core** (with live
progress) and **uninstall it** (footer of the side panel) — the running system is never touched.

### Linux (Debian/Ubuntu-like, pm2 or your own supervisor)

**Interactive installer (detects what exists + language):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.sh)
```
Or step by step:

```bash
mkdir -p ~/projects/dsh && cd ~/projects/dsh
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git dsh-h-v1 && cd dsh-h-v1

# pinned core + pt-BR dictionaries (writes into the npm-installed core)
./core-i18n-pt/tools/apply-pt-core.sh --force

# sync the overlay (plugins/settings) into the live config dir and run the GUI:
DSH_CLONE=~/projects/dsh/dsh-h-v1 DSH_LIVE=~/.dsh-v2 ./tools/sync-pull.sh
export DSH_HOME=~/.dsh-v2 DSH_WEB_URL=http://127.0.0.1:3081
node "$(npm root -g)/@deepseek-ai/dsh/lib/bin.js" --profile web --no-open --port 3081 --host 127.0.0.1
```

Open http://127.0.0.1:3081 — same overlay/plugins as Windows (side panel, badges, pt-BR interface,
FreeLLMAPI), and the same **parallel-instance** flow from the chip (see [CORE-UPDATE.md](docs/CORE-UPDATE.md)).

## 🎯 What this repo is for

1. **One source of truth for your custom layer** — settings, plugins and presets as
   versioned, reviewable code (git history, tags, diffs) instead of exported ZIPs.
2. **Auto-update on every machine** — a scheduled/startup sync pulls the latest overlay;
   nothing is ever replaced **without a local snapshot first**.
3. **Safe rollback** — if a machine that hasn't been touched in months auto-updates and
   breaks, you return to the exact state that was working (local snapshots, git tags,
   or a previous core version).
4. **Free/cheap model access, integrated** — smart routing over free tiers
   (FreeLLM API gateway, OpenRouter `:free`, OpenCode free/zen) with automatic
   fallback, plus a one-click Windows installer.

## ✨ Feature pillars

### 1) Your overlay, versioned (`overlay/`)
`overlay/` mirrors 1:1 the live config dir (`~/.dsh` on Linux, `%USERPROFILE%\.dsh` on
Windows): `settings.yaml`, the Smart Model Router, UI plugins (layout panel, model
visibility, FreeLLMAPI shortcut), presets and editor assets (CodeMirror/marked, MIT).
Credentials, sessions, logs and runtime state **never** enter the repo.

### 2) Auto-update with rollback safety (`tools/`)
- `sync-pull` — pulls the repo and applies the overlay **after snapshotting** the
  current working state into `~/.dsh-snapshots/` (last 8 kept).
- `sync-push` — publishes local edits back (`--tag vX.Y.Z` marks a known-good version).
- `auto-push` — **two-way routine publisher on every machine you edit**: pulls what the
  others published and pushes your local live-config changes by itself — each release is
  **documented over the last version** (descriptive commit with the changed files, an
  automatic `vX.Y.Z` tag, and a `CHANGELOG.md` entry). If two machines edit the same
  file before syncing, the machine that syncs last becomes the current version and the
  other stays preserved in history/tags — never force-pushed, never lost. Guardrails:
  the `.dsh-autoupdate.off` ON/OFF switch (panel badge) disables it, secret guard blocks
  bad commits. Schedule once per machine (`tools/auto-sync.sh` or Windows Task Scheduler
  with `tools\auto-sync.ps1`); preview with `tools/auto-push.sh --dry-run`.
  Manuals: `docs/SYNC.md`.
- `rollback` — `--snapshot <name>` restores the exact pre-update machine state,
  `<tag|commit>` reverts the overlay to a published version (removing files added by
  newer versions too), `--core <version>` reinstalls a previous npm core.
  **From the GUI:** click the version badge (or its ↩ button) to list versions/snapshots
  and go back if an update broke something — auto-update is switched OFF and the harness
  restarts itself (pm2).
- `check-core` — notifies when the official core (`@deepseek-ai/dsh`) has a new
  version; applying core updates is **manual and tested** (plugins hook DSH internals).
- `guard-secrets` — pre-commit hook that **blocks** any commit containing a key/credential.

### 3) Free/cheap model usage, integrated
Custom plugins in this overlay wire the harness to low-cost/free providers:
- **FreeLLM API gateway** (local, `http://127.0.0.1:3002`): add free-tier provider keys
  (Groq, Cerebras, Mistral, …) in one place; a dashboard badge shows gateway health and
  which model actually answered the last request (incl. failover indicator).
- **Smart Model Router** (`smart-router/auto|eco|ultra`): task complexity picks a free
  tier and the router falls back at runtime when a provider errors — free chain:
  `freellmapi → openrouter → opencode free → opencode zen/deepseek → deepseek official`.
- Provider keys are read from **environment variables or the local `.credentials.yaml`**
  — never committed. See `manifest.json` for the env var names.

### 4) Windows installer (`installer/`, `start-dsh-gui.bat`)
Installs the official core via npm (`npm install -g @deepseek-ai/dsh`), applies the
overlay and creates a desktop launcher that runs `sync-pull` before opening the GUI
on `http://127.0.0.1:3080`.

## ⚠️ Honest notes about "free"
Free tiers depend on each provider's terms and availability and can change or disappear.
This repo provides the **routing and integration**, not the keys or the service — you
bring your own keys per provider. Nothing here bypasses provider terms.

## 🚀 Quickstart

```bash
# receive updates on this machine (snapshots current state first)
tools/sync-pull.sh

# publish your local edits (add --tag vX.Y.Z for a known-good release)
tools/sync-push.sh "what changed"

# full auto cycle on EVERY machine you edit (cron 30 min / Task Scheduler):
#   tools/auto-sync.sh            (Linux; dry-run: tools/auto-push.sh --dry-run)
#   tools\auto-sync.ps1           (Windows)
# each publish documents itself: descriptive commit + automatic vX.Y.Z tag + CHANGELOG.md

# structural changes already pushed by git without a version? publish the sub-version:
#   tools/release.sh              (dry-run: tools/release.sh --dry-run)
# details: docs/SYNC.md → "Sincronização automática via de mão dupla em TODAS as máquinas"

# something broke after an update? go back
tools/rollback.sh list
tools/rollback.sh --snapshot <name>    # exact pre-update machine state
tools/rollback.sh v1.2.0               # a published overlay version
tools/rollback.sh --core 0.1.1-rc.2    # previous core (npm)
```

Manuals: [`docs/SYNC.en.md`](docs/SYNC.en.md) (EN) · [`docs/SYNC.md`](docs/SYNC.md) (PT-BR)
· Windows guide: [`docs/WINDOWS.md`](docs/WINDOWS.md) (EN) · [`docs/WINDOWS-PT.md`](docs/WINDOWS-PT.md) (PT-BR)
· [`README.pt-BR.md`](README.pt-BR.md)

## 🆚 How it compares

| | Upstream DeepSeek Harness | [dsh-config-manager](https://github.com/xiajiajun516/dsh-config-manager) | [dsh-vibe-pack](https://github.com/LeemanCheung/dsh-vibe-pack) | **this repo** |
|---|---|---|---|---|
| Manages | runtime + plugins | backup/migrate/sync config (UI plugin) | data-only transactional packs | **your custom JS plugins & settings as git** |
| Rollback | — | snapshot before restore | atomic ledger + uninstall | snapshots + git history/tags + **core** rollback |
| Secrets guard | assumes | never exports | rejects | guard **blocks at commit time** |
| Custom JS plugins sync | n/a | — | no (data-only) | **yes** |

## 🗄️ Archived lineage (preserved, not canonical)

`main` follows the overlay + sync model above. The earlier **Windows-bundle lineage**
(legacy `source/` bundle, `bin.js` launchers, icons, `preload.cjs`,
`start-parallel-dsh.bat`) is preserved for reference, not maintained:
- branches `versao-pc1`, `versao-pc2` · tag `main-anterior-e553f9b`

Useful improvements from that lineage were already migrated into `main` (e.g.
`layout-panel-plugin` v1.1 multi-dir/junctions, updated FreeLLMAPI badge).

## 🛡️ Security

- No credentials in this repo — keys come from env vars or the local `.credentials.yaml`
  (gitignored, excluded from sync and snapshots).
- `guard-secrets.sh` (pre-commit hook + CI) blocks key/credential commits.
- Sensitive/reproducible hygiene: repo is audited before going public.

## 📜 License

- Original files (overlay, tools, installer, docs): **MIT** — [`LICENSE`](LICENSE)
- Third-party assets (`overlay/editor-assets/`): MIT — [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- DeepSeek Harness core: **MIT © DeepSeek**, installed from npm, not redistributed here
  ([github.com/deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness))

> Núcleo em pt-BR (experimental): [`core-i18n-pt/README.md`](core-i18n-pt/README.md)
