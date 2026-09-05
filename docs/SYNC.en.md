# Multi-machine sync (SYNC)

How to keep **every machine** on the same personalized DeepSeek Harness layer,
always on the latest published version.

> English manual. The original/PT-BR version is [`SYNC.md`](SYNC.md).

## Layer model

| Layer | What | Where | How it updates |
|---|---|---|---|
| **L1 — Core** | `@deepseek-ai/dsh` (the app) | npm (official DeepSeek channel) | `check-core` **notifies**; you apply manually and test |
| **L2 — Overlay** | `settings.yaml`, plugins, presets, `editor-assets/` | **this repo** (`overlay/`) | `sync-pull` (receive) / `sync-push` (publish) |
| **L3 — Local state** | `.credentials.yaml`, `sessions/`, `storages/`, logs | machine only | **never** synced |

> Golden rule: **always edit the live config dir** (`~/.dsh` on Linux,
> `%USERPROFILE%\.dsh` on Windows) and use `sync-push` to publish. The
> `overlay/` folder inside the clone is a mirror — don't edit it directly.
>
> The global patch `cordis.patch.yml` is **generated per machine** from the
> template `overlay/cordis.patch.yml.tpl` (`sync-pull`/`rollback` replace
> `__DSH_HOME__` with that machine's live dir). To change the patch, edit the
> **.tpl** and publish — never edit the generated file.

## Install on a new machine

### Linux (also WSL/macOS)

```bash
# 1. Clone (once)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git ~/dsh-h-v1
cd ~/dsh-h-v1 && tools/install-hooks.sh

# 2. Receive the latest version (creates/updates ~/.dsh)
tools/sync-pull.sh
```

### Windows 10/11

```powershell
# 1. Clone (once) — git installed & authenticated (gh auth login)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "$env:USERPROFILE\dsh-h-v1"

# 2. Receive the latest version (creates/updates %USERPROFILE%\.dsh)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\dsh-h-v1\tools\sync-pull.ps1"
```

> The core (L1) is installed separately by the harness installer:
> `npm install -g @deepseek-ai/dsh` (Windows needs Node.js 20+).

## Daily flow

| Action | Command |
|---|---|
| Update this machine with what's new | `tools/sync-pull.sh` |
| Publish edits made on this machine | `tools/sync-push.sh "what changed"` |
| Publish and mark as known-good | `tools/sync-push.sh "what changed" --tag v1.2.0` |
| Check core version vs npm | `tools/check-core.sh` |
| Dry-run what would change | `git -C ~/dsh-h-v1 pull --ff-only --dry-run` |
| List available previous versions | `tools/rollback.sh list` |
| Run the functional tests | `tools/test.sh` (also runs in CI) |

### Push needs authentication (once per machine)

```bash
gh auth login          # recommended — stores the login safely
# or: git config --global credential.helper 'cache --timeout=3600'
```

## ↩️ Rollback — go back to a working version

Scenario: a machine that hasn't been touched in a while receives automatic
updates and **stops working**. The system never replaces what is running
without first saving it — and it keeps the full history locally.

```bash
# 1. See what you can go back to (local snapshots + tags + commits)
tools/rollback.sh list

# 2a. Go back to the EXACT state that worked on this machine
#     (snapshot taken automatically before the last update)
tools/rollback.sh --snapshot <snapshot-name>

# 2b. Or go back to a published repo version (tag/commit)
tools/rollback.sh v1.0.0

# 3. If the breakage came from the CORE (L1), reinstall the previous version
tools/rollback.sh --core 0.1.1-rc.2
```

**How the protection works:**

- **Automatic snapshots:** before **every** update (`sync-pull`) the current
  live config is copied to `~/.dsh-snapshots/` (last 8 kept; credentials and
  sessions never enter a snapshot). That is the "state that worked ON THIS
  machine", including your local edits.
- **Git history in the clone:** every `sync-pull` only adds commits — older
  overlay versions stay in the local clone forever. Going back to a tag/commit
  also removes files that newer versions had added.
- **Tags = known-good anchors:** publish with
  `tools/sync-push.sh "msg" --tag vX.Y.Z` once you've tested and approved a state.
- **Every rollback snapshots the current state first** — you can always undo a rollback.
- After the rollback, **restart the harness** to load the older version.
- Windows: use `tools\rollback.ps1` with the same arguments.

## Scheduling automatic updates ("both" — on start + scheduled)

### Linux — on harness start
Add `tools/sync-pull.sh` to the command that starts the harness, or make an alias:

```bash
alias dsh-up="~/dsh-h-v1/tools/sync-pull.sh && dsh"
```

### Linux — scheduled (cron, every 30 min)
```bash
crontab -e
# line:
*/30 * * * * /home/deploy/projects/dsh-h-v1/tools/sync-pull.sh >> ~/.dsh-sync.log 2>&1
```
> `sync-pull` applies `overlay/` onto `~/.dsh` without `--delete`: it never
> removes files that exist only on the machine. Safe to run while the harness
> is open; the GUI only picks up new content when sessions restart.

### Windows — on start (start-dsh-gui.bat)
`start-dsh-gui.bat` (repo root) already calls `tools\sync-pull.ps1` before
opening the GUI.

### Windows — scheduled (Task Scheduler)
Create a daily (or hourly) task:
`powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-pull.ps1"`

## Updating the CORE (L1) — manual and tested

1. `tools/check-core.sh` shows installed × pinned × latest.
2. When you want to upgrade: `npm update -g @deepseek-ai/dsh`
3. **Test** your plugins/router (they hook DSH internals).
4. Once stable, update `pinned` in `manifest.json` and publish:
   `tools/sync-push.sh "core: pinned to X.Y.Z"`

## Security (what the system guarantees)

- `.credentials.yaml`, sessions, storages, logs, backups and runtime state are
  in `tools/sync-excludes.txt` **and** in `.gitignore` → they never enter the
  repo or the snapshots.
- `tools/guard-secrets.sh` runs in the `pre-commit` hook (install with
  `install-hooks.sh`) and inside `sync-push` → blocks any commit that
  contains a key/credential.
- Before every update a **local snapshot** of the current state is created
  (`~/.dsh-snapshots/`, last 8) — nothing is replaced without a backup.
- If a secret ever leaks in a commit: **revoke the key immediately** and
  rewrite history before making the repo public.

## Troubleshooting

| Symptom | Likely cause / solution |
|---|---|
| Machine broke after an automatic update | `tools/rollback.sh list` → `tools/rollback.sh --snapshot <snapshot>` (or `tools/rollback.sh <tag>`) |
| Breakage came from the core (L1) | `tools/rollback.sh --core <previous version>` |
| `cordis.patch.yml` has another machine's paths | It is REGENERATED from the template `overlay/cordis.patch.yml.tpl` (`__DSH_HOME__`) on every `sync-pull`/`rollback` with the local path — to change the patch, edit the `.tpl` and publish |
| `sync-pull` fails on pull | There are uncommitted local changes in the clone: `git -C ~/dsh-h-v1 status` and resolve |
| `sync-push` fails on push | No authentication: `gh auth login` |
| Plugins break after a core update | Go back: `npm install -g @deepseek-ai/dsh@<previous version>` |
| Guard blocked something | Review `git diff --cached`, remove the file from the index (`git reset HEAD <file>`) and delete the secret from disk |
