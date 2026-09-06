# Machine-to-machine sync (SYNC)

How to keep **every machine you use** on the same personalized DeepSeek Harness
layer, always on the latest published version — with safe rollback and
documented, versioned releases.

> English manual. The original/PT-BR version is [`SYNC.md`](SYNC.md).

## Layer model

| Layer | What | Where it lives | How it updates |
|---|---|---|---|
| **L1 — Core** | `@deepseek-ai/dsh` (the app) | npm (official DeepSeek channel) | `check-core` **notifies**; you apply manually and test |
| **L2 — Overlay** | `settings.yaml`, plugins, presets, `editor-assets/` | **this repo** (`overlay/`) | `sync-pull` (receive) / `sync-push` (publish) |
| **L3 — Local state** | `.credentials.yaml`, `sessions/`, `storages/`, logs | machine only | **never** syncs |

> Golden rule: **always edit the live config** (`~/.dsh` on Linux,
> `%USERPROFILE%\.dsh` on Windows) and use `sync-push` to publish. The
> `overlay/` inside the clone is a mirror — do not edit it directly.
>
> The global `cordis.patch.yml` patch is **generated per machine** from the
> template `overlay/cordis.patch.yml.tpl` (`sync-pull`/`rollback` replaces
> `__DSH_HOME__` with that machine's live dir). To change the patch, edit the
> **.tpl** and publish — never edit the generated file.

## Install on a new machine

### Linux (and WSL/macOS)

```bash
# 1. Clone (once)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git ~/dsh-h-v1
cd ~/dsh-h-v1 && tools/install-hooks.sh

# 2. Receive the latest version (creates/updates ~/.dsh)
tools/sync-pull.sh
```

### Windows 10/11

```powershell
# 1. Clone (once) — git installed and authenticated (gh auth login)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "$env:USERPROFILE\dsh-h-v1"

# 2. Receive the latest version (creates/updates %USERPROFILE%\.dsh)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\dsh-h-v1\tools\sync-pull.ps1"
```

> The core (L1) is installed separately by the harness installer:
> `npm install -g @deepseek-ai/dsh` (Windows needs Node.js 20+).

## Daily flow

| Action | Command |
|---|---|
| Full automatic cycle (receive + publish) | `tools/auto-sync.sh` (preview: `tools/auto-push.sh --dry-run`) |
| Version STRUCTURAL changes already pushed (git/sync-push without a version) | `tools/release.sh` (preview: `tools/release.sh --dry-run`) |
| Update this machine with what's new | `tools/sync-pull.sh` |
| Publish edits made on this machine | `tools/sync-push.sh "what changed"` |
| Publish and mark as a known-good version | `tools/sync-push.sh "what changed" --tag v1.2.0` |
| Compare core version vs npm | `tools/check-core.sh` |
| Preview what an update would bring | `git -C ~/dsh-h-v1 pull --ff-only --dry-run` |
| List earlier versions available | `tools/rollback.sh list` |
| Run the functional tests | `tools/test.sh` (also runs in CI) |

### Pushing requires authentication (once per machine)

```bash
gh auth login          # recommended — stores the login securely
# or: git config --global credential.helper 'cache --timeout=3600'
```

## ↩️ Rollback — go back to a version that worked

Scenario: a machine that was idle for months receives automatic updates and
**stops working**. The system never replaces what is running without first
saving it — and keeps the full history locally.

```bash
# 1. See what you can go back to (local snapshots + tags + commits)
tools/rollback.sh list

# 2a. Go back to the EXACT state that worked on this machine
#     (snapshot created automatically before the last update)
tools/rollback.sh --snapshot <snapshot-name>

# 2b. Or go back to a published repo version (tag/commit)
tools/rollback.sh v1.0.0

# 3. If the breakage came from the CORE (L1), reinstall the previous version
tools/rollback.sh --core 0.1.1-rc.2
```

**How the protection works:**

- **From the panel (GUI):** in the version badge (bottom-right corner), click the
  version or the **↩** button → a list opens with the suggested previous version,
  the published `vX.Y.Z` tags and the local snapshots. Going back restores the
  target version, **switches auto-update OFF** (panel shows `🔄 auto: OFF` — the
  30-min sync no longer re-applies the version that broke) and **restarts the
  harness by itself** (when running under pm2).
- **Automatic snapshots:** before **every** update (`sync-pull`) the current live
  config state is copied to `~/.dsh-snapshots/` (last 8 kept; credentials/sessions
  never enter a snapshot). It is "the state that worked ON THIS MACHINE",
  including your local edits.
- **Git history in the clone:** every `sync-pull` only adds commits — old overlay
  versions stay in the local clone forever. Going back to a tag/commit also removes
  files that newer versions had added.
- **Tags = version anchors:** `auto-push` creates a `vX.Y.Z` tag on every automatic
  release; publish manually with `tools/sync-push.sh "msg" --tag vX.Y.Z` to mark a
  good state.
- **Every rollback also snapshots the current state first** — you can always undo
  the rollback.
- After a rollback, **restart the harness** (the panel restarts by itself under
  pm2; from the terminal, restart the GUI) to load the old version — the badge
  shows the version you went back to.
- To **return to the newest version** after testing: switch auto back on
  (`🔄 auto: OFF` → ON) — the next sync applies the latest published version.
- Windows: use `tools\rollback.ps1` with the same arguments.

## Schedule the automatic sync ("both" — on start + scheduled)

> Full cycle (receive **and** publish) in one line: **`tools/auto-sync.sh`**
> (Linux) / **`tools\auto-sync.ps1`** (Windows). auto-push details, versioning
> and conflict policy are in the "Two-way automatic sync on ALL machines"
> section below.

### Linux — when the harness starts
Add `tools/auto-sync.sh` to the command that starts the harness, or create an alias:

```bash
alias dsh-up="~/dsh-h-v1/tools/auto-sync.sh && dsh"
```

### Linux — scheduled (cron, every 30 min)
```bash
crontab -e
# line:
*/30 * * * * ~/dsh-h-v1/tools/auto-sync.sh >> ~/.dsh-sync.log 2>&1
```
> `sync-pull` applies `overlay/` over the live config **without `--delete`**: it
> never removes files that only exist on the machine. Safe to run with the harness
> open; the GUI only uses the new content after sessions restart.

### Windows — on start (start-dsh-gui.bat)
The `start-dsh-gui.bat` (repo root) already calls `tools\auto-sync.ps1` (receive +
publish) before opening the GUI.

### Windows — scheduled (Task Scheduler)
Create a task every 30 min (or daily):
`powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"`

## Turning automatic updates ON/OFF

- **From the panel:** the version badge (plugin `version-badge-plugin.js`) has the
  `🔄 auto: ON/OFF` button — it creates/removes `<live config>/.dsh-autoupdate.off`.
- **From the command line:**
  `touch ~/.dsh/.dsh-autoupdate.off`   → OFF
  `rm ~/.dsh/.dsh-autoupdate.off`      → ON
- While the flag exists, the local scheduler (cron/autoupdate) **does not sync nor
  restart**. The flag is local to the machine (never goes to the repo) and disables
  **both directions**: receiving (`sync-pull`) and publishing (`auto-push`).

## Two-way automatic sync on ALL machines

`auto-sync` (receive + publish) runs on **any machine where you edit** the harness.
So whether you edit the live config here **or** on another machine, the new version
goes up to GitHub by itself and **all** machines sync to the latest version.

Model (one routine per machine):

| Direction | Script | What it does |
|---|---|---|
| Receive | `sync-pull.sh` / `sync-pull.ps1` | pulls the repo, snapshots + applies `overlay/` to the live config |
| Publish | `auto-push.sh` / `auto-push.ps1` | publishes the local edits, **documented** (below) |
| Full cycle (1 line) | `auto-sync.sh` / `auto-sync.ps1` | `sync-pull` **followed by** `auto-push` |

### What each release ships (documentation over the last version)

1. **Descriptive commit** with the changed files — e.g.:
   `sync(auto): v0.2.3 — settings.yaml,smart-router-plugin.js`.
2. **Automatic version `vX.Y.Z`** (patch bumped over the highest tag; if no tag
   exists, it starts from the `version` in `manifest.json`) with an **anchor tag**
   on GitHub — the panel version badge shows the progress on every release.
3. **`CHANGELOG.md`** in the repo: each release appends its version entry (date,
   machine, changed files and incorporated local commits) — chronological order,
   the newest version is at the end of the file.

> Structural repo releases (tools/, docs/, this manual) stay manual with
> `sync-push.sh "message"` or `git push` — and to publish the matching
> **sub-version** (auto-push does not see structural changes), run
> **`tools/release.sh`** afterwards: it marks the state you already pushed with
> the next `vX.Y.Z` + a `CHANGELOG.md` entry summarizing the commits since the
> last tag.
> Rule: **every published change produces a new sub-version** — live-config edits
> go up by themselves (auto-push/cron); structural changes go up with
> `tools/release.sh`.

### When two machines edit the same file (conflict policy)

Two different system versions are never lost:

- The routine **first receives** (pull/rebase) what other machines published and
  only then publishes your edits.
- If the **same region of the same file** changed on both (conflict), the routine
  keeps the version of the machine that is syncing last — **the last sync becomes
  the latest system version** — and the other machine's version stays **preserved
  in the history and in the previous tag** (`git log`/`rollback` to recover it).
- There is never a forced push; nothing is deleted.

### Schedule on each machine (Linux/WSL)

```bash
crontab -e
# line (clone at ~/dsh-h-v1, live config ~/.dsh):
*/30 * * * * ~/dsh-h-v1/tools/auto-sync.sh >> ~/.dsh-sync.log 2>&1
# if your clone/config use other paths (e.g.: ~/dsh-v2 and ~/.dsh-v2):
*/30 * * * * DSH_CLONE=~/dsh-v2 DSH_LIVE=~/.dsh-v2 ~/dsh-v2/tools/auto-sync.sh >> ~/.dsh-sync-v2.log 2>&1
```

### Schedule on each machine (Windows — Task Scheduler)

1. Clone (once): `git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "%USERPROFILE%\dsh-h-v1"`
2. Create a task (or use `start-dsh-gui.bat`, which already calls `auto-sync` when
   opening the GUI):
   - Action: `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"`
   - Trigger: every 30 min (and/or "at log on") — run with the user's privileges.
3. The `tools\` clone is the same mirror: `sync-pull.ps1` applies to
   `%USERPROFILE%\.dsh` and `auto-push.ps1` publishes from there.

### Authentication to PUBLISH (once per machine)

Pulling works without login (public repo), but **publishing requires credentials**
on every machine that will run auto-push:

```bash
gh auth login                     # recommended (Linux/WSL/Git Bash)
# or a classic PAT in the credential helper:
git config --global credential.helper store   # then enter user/PAT once
```
Windows: `gh auth login` or the Git Credential Manager (which already handles HTTPS).

### Guardrails (always, on every machine)

- flag `<live config>/.dsh-autoupdate.off` disables the routine **in both
  directions** (same `🔄 auto: ON/OFF` panel button; the flag is machine-local);
- never uses `--force`; tags are never overwritten (rare race = the next version
  is used and reported in the log);
- the secret guard blocks suspicious commits (bash: `guard-secrets.sh`; Windows:
  a simple guard inside the `.ps1`) and restores the `overlay/` mirror;
- a concurrency lock (`flock` on Linux, file lock on Windows);
- only the `overlay/` mirror + `CHANGELOG.md` enter the automatic commit.

### Preview, log and the agent rule

- Preview first: `tools/auto-push.sh --dry-run` (or `auto-push.ps1 -DryRun`) —
  shows what would be published without changing anything.
- Log: auto-push writes to stdout — in cron/Task Scheduler, redirect it to the same
  log as the pull (e.g.: `>> ~/.dsh-sync.log 2>&1`).
- **Rule when working with an agent/harness:** after a requested change to the live
  config, publish right away (`tools/sync-push.sh "description"` or run
  `auto-sync`) so the other machines receive it immediately — the scheduled run is
  the safety net.

## Updating the CORE (L1) — manual and tested

1. `tools/check-core.sh` shows installed × pinned × latest.
2. To upgrade: `npm update -g @deepseek-ai/dsh`
3. **Test** your plugins/router (they use core internals).
4. Once stable, update `pinned` in `manifest.json` and publish:
   `tools/sync-push.sh "core: pinned at X.Y.Z"`

## Security (what the system guarantees)

- `.credentials.yaml`, sessions, storages, logs, backups and runtime state are in
  `tools/sync-excludes.txt` **and** `.gitignore` → they never enter the repo or
  snapshots.
- `tools/guard-secrets.sh` runs in the `pre-commit` (install with
  `install-hooks.sh`) and inside `sync-push` → blocks any commit that looks like a
  key/credential.
- Before every update, a **local snapshot** of the current state is created
  (`~/.dsh-snapshots/`, last 8) — nothing is replaced without a backup.
- If a secret ever leaks in a commit: **revoke the key immediately** and rewrite
  the history before making the repo public.

## Troubleshooting

| Symptom | Likely cause / solution |
|---|---|
| Machine broke after an automatic update | `tools/rollback.sh list` → `tools/rollback.sh --snapshot <snapshot>` (or `tools/rollback.sh <tag>`) |
| Breakage came from the core (L1) | `tools/rollback.sh --core <previous version>` |
| `sync-pull` fails on pull | There are uncommitted local changes in the clone: `git -C ~/dsh-h-v1 status` and resolve |
| `sync-push` fails on push | No authentication: `gh auth login` |
| Plugins break after a core update | Go back: `npm install -g @deepseek-ai/dsh@<previous version>` |
| `cordis.patch.yml` has another machine's paths | It is REGENERATED from the `overlay/cordis.patch.yml.tpl` template (placeholder `__DSH_HOME__`) on every `sync-pull`/`rollback` with the local path — to change the patch, edit the `.tpl` and publish |
| Guard blocked something | Review `git diff --cached`, remove the file from the index (`git reset HEAD <file>`) and delete the secret from disk |
