# SERVER-MAP (EN) — Server layout (2026-09-07)

Companion to the PT version ([SERVER-MAP.md](SERVER-MAP.md)). Short form.

## Single source of truth
- **Active repo:** `/home/deploy/projects/dsh/dsh-h-v1` → GitHub
  `marcosmmjr2023/dsh-h-v1`. Legacy path `/home/deploy/dsh-v2` is a **symlink**
  to it (keeps cron/wrappers/tools working).
- **Live config** (user data, not versioned): `~/.dsh` (v1 GUI), `~/.dsh-v2`
  (main GUI), `~/.dsh-envs/<env>` (A/B test homes+core).
- **Old/redundant copies** were archived under `~/projects/dsh/_archive/2026-09-07/`
  (stale v0.2.0 clone, pt translation scratch, dsh-turbo Windows adaptation,
  legacy loose files). Duplicate `.tar.gz`/`.zip` removed. `dsh-h-v1` git
  history on GitHub is authoritative.

## Running services (pm2)
| name | port | home | core | role |
|---|---|---|---|---|
| dsh-web | 3080 | ~/.dsh | /opt/dsh-tui 0.1.1-rc.2 | GUI v1 legacy |
| dsh-web-v2 | 3081 | ~/.dsh-v2 | /opt/dsh-tui 0.1.1-rc.2 | main GUI (this session) |
| dsh-env-rc012 | 3111 | ~/.dsh-envs/rc012/home | env core 0.1.2-rc.1 | core A/B test |
| freellmapi | 3002 | ~/projects/freellmapi | upstream tashfeenahmed/freellmapi | FreeLLMAPI gateway |

## Rules
1. Develop only in `~/projects/dsh/dsh-h-v1`; publish commits via release (`vX.Y.Z`).
2. Panel plugins live in `overlay/*.js` (all 7 active plugins are versioned).
   Never edit `~/.dsh-v2/*.js` directly without mirroring + publishing.
3. Never touch live config/sessions; backups in `~/.dsh-snapshots`,
   `~/.dsh-core-backups`, `~/backups`.
4. Core updates only through A/B env (`core-env.sh create→test→promote`) with
   automatic backup; never live without tests.
5. Rollback (`tools/rollback.sh` / ↩ button) now restarts the GUI itself.

## Known pending items
- DSH auto-sync cron (`*/30`, wrapper `~/.local/bin/dsh-v2-autoupdate.sh`)
  was NOT found in `crontab -l` — verify/restore scheduling if wanted.
- Keep live plugin files in `~/.dsh-v2` in sync with `overlay/` (auto-push covers it).
