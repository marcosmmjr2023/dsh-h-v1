# dsh-h-v1 — Personal layer, auto-update & safe rollback for DeepSeek Harness

A git-based overlay and sync system that keeps your **personal DeepSeek Harness setup**
(custom plugins, model router, presets, editor assets) **identical on every machine** —
and lets you **roll back safely** when an automatic update breaks something.

Built on top of [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(*"Everything is a Plugin"*). **Unofficial** — a personal distribution, not affiliated with DeepSeek.

---

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
# details: docs/SYNC.md → "Sincronização automática via de mão dupla em TODAS as máquinas"

# something broke after an update? go back
tools/rollback.sh list
tools/rollback.sh --snapshot <name>    # exact pre-update machine state
tools/rollback.sh v1.2.0               # a published overlay version
tools/rollback.sh --core 0.1.1-rc.2    # previous core (npm)
```

Manuals: [`docs/SYNC.en.md`](docs/SYNC.en.md) (EN) · [`docs/SYNC.md`](docs/SYNC.md) (PT-BR)
· Windows guide: [`docs/WINDOWS-PT.md`](docs/WINDOWS-PT.md) · [`README.pt-BR.md`](README.pt-BR.md)

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
