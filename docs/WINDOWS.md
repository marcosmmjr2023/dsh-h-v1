# 🚀 DeepSeek Harness GUI — Windows install (dsh-h-v1)

Install the personalized DeepSeek Harness layer on Windows 10/11,
**synced through git** — this machine always receives the latest version
published in the repository, and **also publishes** your local edits (two-way).

> ⚠️ Paths such as `installer\install.bat` and `tools\...` are **relative to the
> repository root** (the clone folder), not to this documentation folder.
>
> Read the sync manual too: [`SYNC.en.md`](SYNC.en.md) (EN) ·
> [`SYNC.md`](SYNC.md) (PT-BR)

---

## 📋 Prerequisites

| Requirement | Detail |
|---|---|
| Operating System | Windows 10 or 11 (64-bit recommended) |
| Node.js | v20+ LTS (recommended) |
| Git | with GitHub authentication (`gh auth login` or a credential helper) |

---

## 🔧 Installation

### ✅ Option 1: Automatic installer (`installer/install.bat`)

1. Clone the repository:
   ```cmd
   git clone https://github.com/marcosmmjr2023/dsh-h-v1.git %USERPROFILE%\dsh-h-v1
   ```
2. Run `installer\install.bat` (it installs the core via npm, applies the
   overlay to `%USERPROFILE%\.dsh` and creates `start-dsh-gui.bat`).

### ✅ Option 2: PowerShell (`installer/install.ps1`)

Right-click → "Run with PowerShell".
If execution is restricted:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### ✅ Option 3: Manual

```cmd
npm install -g @deepseek-ai/dsh
powershell -ExecutionPolicy Bypass -File tools\sync-pull.ps1
```

---

## ▶️ How to Run

- Double-click `start-dsh-gui.bat` (created by the installer) — it runs the
  two-way sync (`auto-sync.ps1`: receive + publish) before opening the GUI.
- Or, manually, from the harness install folder:
  ```cmd
  dsh web --port 3080
  ```
- Open the browser: [http://127.0.0.1:3080](http://127.0.0.1:3080)

---

## 🔄 Syncing (two-way)

| Action | Command (PowerShell) |
|---|---|
| Full cycle: receive + publish | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"` |
| Receive the latest version | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-pull.ps1"` |
| Publish local edits | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-push.ps1" "what changed"` |
| Check core version | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\check-core.ps1"` |
| List versions to go back to | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\rollback.ps1" list` |

> Every automatic publish bumps a `vX.Y.Z` version, appends a `CHANGELOG.md`
> entry and creates a rollback anchor (tag). Edits on your **live config**
> (`%USERPROFILE%\.dsh`) are what get published — never credentials/sessions/logs.
> If an update breaks something, click the **↩** button in the version badge
> (panel) or run `rollback.ps1` to go back; auto-update is switched OFF and the
> GUI restarts.

---

## 🗂️ Package Structure

```
dsh-h-v1/
├── overlay/                → Live config (%USERPROFILE%\.dsh)
├── tools/                  → Sync + guard scripts
├── installer/              → install.bat, install.ps1, start-dsh-gui.bat
├── manifest.json           → Pinned core version
└── docs/                   → SYNC.md / SYNC.en.md (sync manual)
```

## 🧰 Common Troubleshooting

| Error | Solution |
|---|---|
| `node is not recognized` | Install Node.js and restart CMD/PowerShell |
| `git` not recognized | Install Git for Windows |
| Page does not open in the browser | Wait and reload the tab |
| Port 3080 in use | `netstat -ano \| findstr 3080` and kill the process |

---

## 🧪 Manual test checklist (Windows)

After installing/cloning on a fresh Windows machine, check (manual validation —
CI covers syntax/static checks, but does not run real Windows):

1. `installer\install.bat` finishes without errors and creates the Desktop shortcut.
2. Opening the shortcut runs `auto-sync` and the GUI opens at http://127.0.0.1:3080.
3. `%USERPROFILE%\.dsh\cordis.patch.yml` exists and points to `C:\Users\...` (no
   `__DSH_HOME__` or `/home/deploy` in it).
4. FreeLLMAPI badges and the side panel (layout) appear on the dashboard.
5. Edit a plugin/setting → `tools\sync-push.ps1 "test"` publishes; another machine
   receives it with `sync-pull` (or the version badge shows the new version after
   the auto-sync).
6. `tools\rollback.ps1 list` shows snapshots/tags; a rollback restores a previous
   version.

## 📝 Final Notes

- Credentials live in `%USERPROFILE%\.dsh\.credentials.yaml` (never synced or
  committed — environment variables also work).
- The harness core version is installed via npm and **does not** come from this
  repo.
