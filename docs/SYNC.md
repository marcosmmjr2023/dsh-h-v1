# Sincronização entre máquinas (SYNC)

Como manter **todas as suas máquinas** com a mesma camada personalizada do
DeepSeek Harness, sempre na última versão publicada.

## Modelo de camadas

| Camada | O quê | Onde vive | Como atualiza |
|---|---|---|---|
| **L1 — Core** | `@deepseek-ai/dsh` (o app) | npm (canal oficial DeepSeek) | `check-core` **notifica**; você aplica manualmente e testa |
| **L2 — Overlay** | `settings.yaml`, plugins, presets, `editor-assets/` | **este repo** (`overlay/`) | `sync-pull` (receber) / `sync-push` (publicar) |
| **L3 — Estado local** | `.credentials.yaml`, `sessions/`, `storages/`, logs | só na máquina | **nunca** sincroniza |

> Regra de ouro: **edite sempre na config viva** (`~/.dsh` no Linux,
> `%USERPROFILE%\.dsh` no Windows) e use `sync-push` para publicar. O
> `overlay/` dentro do clone é um espelho — não edite nele direto.

## Instalar numa máquina nova

### Linux (e WSL/macOS)

```bash
# 1. Clone (uma vez)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git ~/dsh-h-v1
cd ~/dsh-h-v1 && tools/install-hooks.sh

# 2. Receber a última versão (cria/atualiza ~/.dsh)
tools/sync-pull.sh
```

### Windows 10/11

```powershell
# 1. Clone (uma vez) — git instalado e autenticado (gh auth login)
git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "$env:USERPROFILE\dsh-h-v1"

# 2. Receber a última versão (cria/atualiza %USERPROFILE%\.dsh)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\dsh-h-v1\tools\sync-pull.ps1"
```

> O core (L1) é instalado à parte pelo instalador do harness:
> `npm install -g @deepseek-ai/dsh` (Windows precisa de Node.js 20+).

## Fluxo diário

| Ação | Comando |
|---|---|
| Atualizar esta máquina com o que há de novo | `tools/sync-pull.sh` |
| Publicar edições feitas nesta máquina | `tools/sync-push.sh "descrição do que mudou"` |
| Publicar e marcar como versão conhecida | `tools/sync-push.sh "descrição" --tag v1.2.0` |
| Ver versão do core vs npm | `tools/check-core.sh` |
| Ver o que mudaria (ensaio) | `git -C ~/dsh-h-v1 pull --ff-only --dry-run` |
| Listar versões anteriores disponíveis | `tools/rollback.sh list` |

### Push precisa de autenticação (uma vez por máquina)

```bash
gh auth login          # recomendado — guarda o login com segurança
# ou: git config --global credential.helper 'cache --timeout=3600'
```

## ↩️ Rollback — voltar para uma versão que funcionava

Cenário: uma máquina parada há tempo recebe atualizações automáticas e
**deixa de funcionar**. O sistema nunca substitui o que está rodando sem
antes guardá-lo — e mantém o histórico completo localmente.

```bash
# 1. Ver o que existe para voltar (snapshots locais + tags + commits)
tools/rollback.sh list

# 2a. Voltar para o estado EXATO que funcionava nesta máquina
#     (snapshot criado automaticamente antes da última atualização)
tools/rollback.sh --snapshot <nome-do-snapshot>

# 2b. Ou voltar para uma versão publicada do repo (tag/commit)
tools/rollback.sh v1.0.0

# 3. Se a quebra veio do CORE (L1), reinstale a versão anterior
tools/rollback.sh --core 0.1.1-rc.2
```

**Como funciona a proteção:**

- **Snapshots automáticos:** antes de **cada** atualização (`sync-pull`) o
  estado atual da config viva é copiado para `~/.dsh-snapshots/`
  (as últimas 8 são mantidas; credenciais/sessões nunca entram no snapshot).
  É o "estado que funcionava NESTA máquina", incluindo edições locais suas.
- **Histórico git no clone:** todo `sync-pull` só adiciona commits — as
  versões antigas do overlay continuam no clone local para sempre. Voltar a
  uma tag/commit remove também arquivos que versões novas tinham adicionado.
- **Tags = âncoras de versões conhecidas:** publique com
  `tools/sync-push.sh "msg" --tag vX.Y.Z` quando testar e aprovar um estado.
- **Todo rollback também cria snapshot do estado atual primeiro** — você
  sempre pode desfazer o rollback.
- Após o rollback, **reinicie o harness** para carregar a versão antiga.
- Windows: use `tools\rollback.ps1` com os mesmos argumentos.

## Agendar a atualização automática ("os dois" — ao iniciar + agendado)

### Linux — ao iniciar o harness
Adicione `tools/sync-pull.sh` ao comando que sobe o harness, ou crie um alias:

```bash
alias dsh-up="~/dsh-h-v1/tools/sync-pull.sh && dsh"
```

### Linux — agendado (cron, a cada 30 min)
```bash
crontab -e
# linha:
*/30 * * * * /home/deploy/projects/dsh-h-v1/tools/sync-pull.sh >> ~/.dsh-sync.log 2>&1
```
> O `sync-pull` aplica `overlay/` sobre `~/.dsh` sem `--delete`: nunca apaga
> arquivos que existam só na máquina. Seguro rodar com o harness aberto; a
> GUI só passa a usar o novo conteúdo ao reiniciar sessões.

### Windows — ao iniciar (start-dsh-gui.bat)
O `start-dsh-gui.bat` (raiz do clone) já chama `tools\sync-pull.ps1` antes
de abrir a GUI.

### Windows — agendado (Task Scheduler)
Crie uma tarefa diária (ou a cada hora):
`powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-pull.ps1"`

## Atualizar o CORE (L1) — manual e com teste

1. `tools/check-core.sh` mostra instalado × pinado × latest.
2. Quando quiser subir: `npm update -g @deepseek-ai/dsh`
3. **Teste** seus plugins/roteador (eles usam internals do core).
4. Se estabilizou, atualize o `pinned` em `manifest.json` e publique:
   `tools/sync-push.sh "core: pinado em X.Y.Z"`

## Segurança (o que o sistema garante)

- `.credentials.yaml`, sessões, storages, logs, backups e estado de runtime
  estão no `tools/sync-excludes.txt` **e** no `.gitignore` → nunca entram no
  repo nem nos snapshots.
- `tools/guard-secrets.sh` roda no `pre-commit` (instale com `install-hooks.sh`)
  e dentro do `sync-push` → bloqueia commit se detectar chave/credencial.
- Antes de cada atualização, um **snapshot local** do estado atual é criado
  (`~/.dsh-snapshots/`, últimas 8) — nada é substituído sem backup.
- Se um dia um segredo vazar num commit: **revogue a chave imediatamente** e
  reescreva o histórico antes de tornar o repo público.

## Solução de problemas

| Sintoma | Causa provável / solução |
|---|---|
| Máquina quebrou após update automático | `tools/rollback.sh list` → `tools/rollback.sh --snapshot <snapshot>` (ou `tools/rollback.sh <tag>`) |
| Quebra veio do core (L1) | `tools/rollback.sh --core <versão anterior>` |
| `sync-pull` falha no pull | Há alterações locais não commitadas no clone: `git -C ~/dsh-h-v1 status` e resolva |
| `sync-push` falha no push | Sem autenticação: `gh auth login` |
| Plugins quebram após update do core | Volte: `npm install -g @deepseek-ai/dsh@<versão anterior>` |
| Guard bloqueou algo | Revise `git diff --cached`, remova o arquivo do índice (`git reset HEAD <arquivo>`) e apague o segredo do disco |
