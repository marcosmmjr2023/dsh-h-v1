# SERVER-MAP — Mapa do servidor / organização (2026-09-07)

Guia único para não confundir pastas, versões e sistemas. (English:
[SERVER-MAP.en.md](SERVER-MAP.en.md)).

## 1. Árvore principal

```
/home/deploy/projects/dsh/          ← TUDO do DeepSeek Harness fica AQUI
├── dsh-h-v1/                       ← REPO ATIVO (github.com/marcosmmjr2023/dsh-h-v1)
│     ├── overlay/                  ← plugins/badges do painel (fonte) — 7 arquivos .js
│     ├── tools/                    ← sync/rollback/stamp/check-core/release …
│     ├── core-i18n-pt/             ← pt-BR do núcleo (patches/tools/tabela)
│     ├── docs/                     ← manuais PT/EN + este mapa
│     └── manifest.json             ← versões pinadas (sistema + core)
└── _archive/2026-09-07/            ← antigos/redundantes (README explica)

~/projects/dsh/dsh-h-v1             ← caminho CANÔNICO (sem symlink em ~/dsh-v2 — removido em 2026-09-07)
```

Config viva (dados do usuário, NÃO versionados):
`~/.dsh` (GUI v1) · `~/.dsh-v2` (GUI principal) · `~/.dsh-envs/<env>` (ambientes A/B)

Cópias de segurança: `~/.dsh-snapshots` (overlay), `~/.dsh-core-backups` (pré-core), `~/backups` (geral).

## 2. Sistemas RODANDO neste servidor

| Serviço (pm2) | Porta | Home/config | Núcleo | Uso |
|---|---|---|---|---|
| dsh-web | 3080 | ~/.dsh | /opt/dsh-tui (0.1.1-rc.2) | GUI v1 (legado de produção) |
| dsh-web-v2 | 3081 | ~/.dsh-v2 | /opt/dsh-tui (0.1.1-rc.2) | **GUI principal** (esta sessão) |
| dsh-env-rc012 | 3111 | ~/.dsh-envs/rc012/home | ~/.dsh-envs/rc012/core (0.1.2-rc.1) | teste A/B do core novo (português ok) |
| freellmapi | 3002 | ~/projects/freellmapi | (upstream tashfeenahmed/freellmapi) | gateway FreeLLMAPI |

Núcleos instalados: `/opt/dsh-tui` (prefixo usado pelas GUIs) e `/usr` (npm
global do root). Ambientes têm o próprio core em `~/.dsh-envs/<nome>/core`.

## 3. Regras de uso (para nunca mais confundir)

1. **Desenvolver:** sempre em `~/projects/dsh/dsh-h-v1`. Commits → GitHub → as
   máquinas recebem por `sync-pull` (cron `*/30` ativo, wrapper `~/.local/bin/dsh-v2-autoupdate.sh`; o caminho `~/dsh-v2` foi removido —
   tudo usa `~/projects/dsh/dsh-h-v1`).
2. **Plugins do painel (overlay):** a fonte é `overlay/*.js`; os 7 plugins
   vivos (`version-badge`, `freellmapi-shortcut`, `layout-panel`,
   `model-visibility`, `openrouter-enhanced`, `router-settings-helper`,
   `smart-router`) estão versionados. **Não edite direto em `~/.dsh-v2/*.js`**
   sem espelhar p/ `overlay/` e publicar (foi a causa da confusão de 07/09).
3. **Config viva** (`~/.dsh*`): dados/sessões/chaves — não versiona, não apaga;
   backups em `~/.dsh-snapshots` e `~/.dsh-core-backups`.
4. **Atualizar core:** só via ambiente A/B
   (`core-i18n-pt/tools/core-env.sh create <nome> --core <ver>` → `test` →
   `promote`) com backup automático; nunca no sistema vivo sem teste.
5. **Rollback:** `tools/rollback.sh` (snapshot/tag/core) agora **reinicia a GUI
   sozinho**; botão ↩ no painel (desliga auto-update).
6. **Publicação:** cada mudança estrutural → `commit` + `tools/release.sh`
   (tag `vX.Y.Z`) + `tools/stamp-version.sh`.

## 4. Ferramentas que você usa todo dia

- `~/projects/dsh/dsh-h-v1/tools/` :
  `check-core.sh`, `sync-pull/push/auto-sync`, `rollback.sh`, `release.sh`,
  `snapshot.sh`, `stamp-version.sh`.
- `core-i18n-pt/tools/`: `apply-pt-core.sh`, `pt-ride.mjs`, `verify-pt.mjs`,
  `core-update.sh`, `core-env.sh`, `core-backup.sh/restore.sh`.
- Menus X11: `.desktop` em `~/.local/share/applications/` (v1, v2, env-rc012);
  wrappers `~/.local/bin/dsh-h-v1-gui.sh` e `dsh-h-v2-gui.sh`.

## 5. Outros projetos em ~/projects (documentados, não mexidos)

agentic · anrelia · backup-system · brazil-cnpj-api · doutordafamilia ·
freellmapi · microservices-architecture · pep · pep-offline ·
scripts-tributos — cada um com seu próprio propósito/README; crons próprios
continuam como estavam (ex.: brazil-cnpj-api, scripts de backup do usuário).

## 6. Pendências conhecidas

- Cron do auto-update do DSH: **ativo** — `*/30 * * * * ~/.local/bin/dsh-v2-autoupdate.sh`
  (confirmado em 2026-09-07; usa DSH_CLONE=~/dsh-v2 que é o symlink).
- `smart-router-plugin.js`, `openrouter-enhanced-plugin.js` etc. estão no
  overlay mas os arquivos vivos de `~/.dsh-v2` precisam ficar **em sincronia**
  (auto-push cobre; validar após próximos syncs).
