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
>
> O patch global `cordis.patch.yml` é **gerado por máquina** a partir do
> template `overlay/cordis.patch.yml.tpl` (o `sync-pull`/`rollback`
> substitui `__DSH_HOME__` pelo diretório vivo daquela máquina). Para mudar
> o patch, edite o **.tpl** e publique — nunca edite o arquivo gerado.

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
| Ciclo completo automático (recebe + publica) | `tools/auto-sync.sh` (ensaio: `tools/auto-push.sh --dry-run`) |
| Versionar mudanças ESTRUTURAIS já enviadas (git/sync-push sem versão) | `tools/release.sh` (ensaio: `tools/release.sh --dry-run`) |
| Atualizar esta máquina com o que há de novo | `tools/sync-pull.sh` |
| Publicar edições feitas nesta máquina | `tools/sync-push.sh "descrição do que mudou"` |
| Publicar e marcar como versão conhecida | `tools/sync-push.sh "descrição" --tag v1.2.0` |
| Ver versão do core vs npm | `tools/check-core.sh` |
| Ver o que mudaria (ensaio) | `git -C ~/dsh-h-v1 pull --ff-only --dry-run` |
| Listar versões anteriores disponíveis | `tools/rollback.sh list` |
| Rodar os testes funcionais | `tools/test.sh` (também roda no CI) |

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

- **Pelo painel (GUI):** no badge de versão (canto inferior direito), clique na
  versão ou no botão **↩** → abre a lista com a versão anterior sugerida, as tags
  `vX.Y.Z` publicadas e os snapshots locais. "Voltar" restaura, **desliga o
  auto-update** (painel mostra `🔄 auto: OFF` — o sync de 30 min não reaplica a
  versão que quebrou) e **reinicia o harness sozinho** (quando roda sob pm2).
- **Snapshots automáticos:** antes de **cada** atualização (`sync-pull`) o
  estado atual da config viva é copiado para `~/.dsh-snapshots/`
  (as últimas 8 são mantidas; credenciais/sessões nunca entram no snapshot).
  É o "estado que funcionava NESTA máquina", incluindo edições locais suas.
- **Histórico git no clone:** todo `sync-pull` só adiciona commits — as
  versões antigas do overlay continuam no clone local para sempre. Voltar a
  uma tag/commit remove também arquivos que versões novas tinham adicionado.
- **Tags = âncoras de versões:** o `auto-push` cria uma tag `vX.Y.Z` a cada
  publicação automática; publique manualmente com
  `tools/sync-push.sh "msg" --tag vX.Y.Z` quando quiser marcar um estado bom.
- **Todo rollback também cria snapshot do estado atual primeiro** — você
  sempre pode desfazer o rollback.
- Após o rollback, **reinicie o harness** (o painel reinicia sozinho sob pm2;
  no terminal, reinicie a GUI) para carregar a versão antiga — o badge mostra
  a versão para a qual você voltou.
- Para **voltar à versão mais nova** depois de testar: religue o auto
  (`🔄 auto: OFF` → ON) — o próximo sync aplica a versão publicada mais recente.
- Windows: use `tools\rollback.ps1` com os mesmos argumentos.

## Agendar o sync automático ("os dois" — ao iniciar + agendado)

> Ciclo completo (recebe **e** publica) numa linha: **`tools/auto-sync.sh`**
> (Linux) / **`tools\auto-sync.ps1`** (Windows). Detalhes do auto-push,
> versionamento e conflitos na seção "Sincronização automática via de mão
> dupla" mais abaixo.

### Linux — ao iniciar o harness
Adicione `tools/auto-sync.sh` ao comando que sobe o harness, ou crie um alias:

```bash
alias dsh-up="~/dsh-h-v1/tools/auto-sync.sh && dsh"
```

### Linux — agendado (cron, a cada 30 min)
```bash
crontab -e
# linha:
*/30 * * * * ~/dsh-h-v1/tools/auto-sync.sh >> ~/.dsh-sync.log 2>&1
```
> O `sync-pull` aplica `overlay/` sobre a config viva sem `--delete`: nunca apaga
> arquivos que existam só na máquina. Seguro rodar com o harness aberto; a
> GUI só passa a usar o novo conteúdo ao reiniciar sessões.

### Windows — ao iniciar (start-dsh-gui.bat)
O `start-dsh-gui.bat` (raiz do clone) já chama `tools\auto-sync.ps1` (recebe +
publica) antes de abrir a GUI.

### Windows — agendado (Task Scheduler)
Crie uma tarefa a cada 30 min (ou diária):
`powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"`

## Ligar/desligar a atualização automática

- **Pelo painel:** o badge de versão (plugin `version-badge-plugin.js`) tem o
  botão `🔄 auto: ON/OFF` — ele cria/remove `<config viva>/.dsh-autoupdate.off`.
- **Pela linha de comando:**
  `touch ~/.dsh/.dsh-autoupdate.off`   → desliga
  `rm ~/.dsh/.dsh-autoupdate.off`      → liga
- O agendador local (cron/autoupdate) **não sincroniza nem reinicia** enquanto
  o flag existir. O flag é local da máquina (nunca vai ao repo). O flag desliga
  **as duas direções**: receber (sync-pull) e publicar (auto-push).

## Sincronização automática VIA DE MÃO DUPLA em TODAS as máquinas

O `auto-sync` (receber + publicar) roda em **qualquer máquina onde você edita** o
harness. Assim, se você editar a config viva aqui **ou** em outra máquina, a versão
nova sobe sozinha para o GitHub e **todas** as máquinas sincronizam a última versão.

Modelo (uma rotina por máquina):

| Direção | Script | O que faz |
|---|---|---|
| Receber | `sync-pull.sh` / `sync-pull.ps1` | puxa o repo, snapshot + aplica `overlay/` na config viva |
| Publicar | `auto-push.sh` / `auto-push.ps1` | publica as edições locais, **documentadas** (abaixo) |
| Ciclo completo (1 linha) | `auto-sync.sh` / `auto-sync.ps1` | `sync-pull` **seguido de** `auto-push` |

### O que cada publicação sobe (documentação sobre a última versão)

1. **Commit descritivo** com os arquivos alterados — ex.:
   `sync(auto): v0.2.3 — settings.yaml,smart-router-plugin.js`.
2. **Versão automática `vX.Y.Z`** (patch incrementado sobre a maior tag; se não
   houver tag, parte do `version` no `manifest.json`) com **tag âncora** no GitHub —
   o badge de versão do painel mostra a evolução a cada publicação.
3. **`CHANGELOG.md`** no repo: cada publicação acrescenta a entrada da versão
   (data, máquina, arquivos alterados e commits locais incorporados) — ordem
   cronológica, a versão mais recente fica no fim do arquivo.

> Publicações estruturais do repo (tools/, docs/, este manual) continuam manuais
> com `sync-push.sh "mensagem"` ou `git push` — e, para subir a **sub-versão**
> correspondente (o auto-push não vê mudanças estruturais), rode
> **`tools/release.sh`** depois: ele marca o estado já enviado com a próxima
> `vX.Y.Z` + entrada no `CHANGELOG.md` resumindo os commits desde a última tag.
> Regra: **toda mudança publicada gera uma sub-versão nova** — edições na
> config viva sobem sozinhas (auto-push/cron); mudanças estruturais sobem com
> `tools/release.sh`.

### Quando duas máquinas editam o mesmo arquivo (política de conflito)

Duas versões diferentes do sistema nunca se perdem:

- A rotina **primeiro recebe** (pull/rebase) o que as outras máquinas publicaram e
  depois publica as suas edições.
- Se a **mesma região do mesmo arquivo** mudou nas duas (conflito), a rotina mantém
  a versão da máquina que está sincronizando por último — **a última sincronização
  vira a última versão do sistema** — e a versão da outra máquina fica **preservada
  no histórico e na tag anterior** (`git log`/`rollback` para recuperar).
- Nunca há push forçado; nada é apagado.

### Agendar em cada máquina (Linux/WSL)

```bash
crontab -e
# linha (clone em ~/dsh-h-v1, config viva ~/.dsh):
*/30 * * * * ~/dsh-h-v1/tools/auto-sync.sh >> ~/.dsh-sync.log 2>&1
# se o clone/config usam outro caminho (ex.: ~/dsh-v2 e ~/.dsh-v2):
*/30 * * * * DSH_CLONE=~/dsh-v2 DSH_LIVE=~/.dsh-v2 ~/dsh-v2/tools/auto-sync.sh >> ~/.dsh-sync-v2.log 2>&1
```

### Agendar em cada máquina (Windows — Task Scheduler)

1. Clone (uma vez): `git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "%USERPROFILE%\dsh-h-v1"`
2. Crie uma tarefa (ou use o `start-dsh-gui.bat`, que já chama o `auto-sync` ao abrir a GUI):
   - Ação: `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"`
   - Gatilho: a cada 30 min (e/ou "ao fazer logon") — rodar com privilégios do usuário.
3. O clone em `tools\` é o mesmo espelho: `sync-pull.ps1` aplica em
   `%USERPROFILE%\.dsh` e `auto-push.ps1` publica de lá.

### Autenticação para PUBLICAR (uma vez por máquina)

Puxar funciona sem login (repo público), mas **publicar exige credencial** em cada
máquina que for rodar o auto-push:

```bash
gh auth login                     # recomendado (Linux/WSL/Git Bash)
# ou um PAT clássico no credential helper:
git config --global credential.helper store   # e entre o usuário/PAT uma vez
```
Windows: `gh auth login` ou o Gerenciador de Credenciais do Git (que já cuida do HTTPS).

### Guardrails (sempre, em qualquer máquina)

- flag `<config viva>/.dsh-autoupdate.off` desliga a rotina **nas duas direções**
  (mesmo botão `🔄 auto: ON/OFF` do painel; o flag é local da máquina);
- nunca usa `--force`; tags nunca são sobrescritas (corrida rara = a próxima
  versão é usada e avisada no log);
- guard de segredos bloqueia o commit suspeito (bash: `guard-secrets.sh`; Windows:
  guard simples no próprio `.ps1`) e restaura o espelho `overlay/`;
- trava de concorrência (`flock` no Linux, lock de arquivo no Windows);
- só o espelho `overlay/` + `CHANGELOG.md` entram no commit automático.

### Ensaio, log e regra com o agente

- Ensaie antes: `tools/auto-push.sh --dry-run` (ou `auto-push.ps1 -DryRun`) —
  mostra o que subiria, não altera nada.
- Log: o auto-push fala no stdout — no cron/Task Scheduler, redirecione para o
  mesmo log do pull (ex.: `>> ~/.dsh-sync.log 2>&1`).
- **Regra ao trabalhar com um agente/harness:** depois de uma modificação pedida
  na config viva, publique na hora (`tools/sync-push.sh "descrição"` ou rode o
  `auto-sync`) para as outras máquinas receberem imediatamente — o agendado é a
  rede de segurança.

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
| `cordis.patch.yml` com caminhos de outra máquina | Ele é REGENERADO do template `overlay/cordis.patch.yml.tpl` (placeholder `__DSH_HOME__`) a cada `sync-pull`/`rollback` com o caminho local — para alterar o patch, edite o `.tpl` e publique |
| Guard bloqueou algo | Revise `git diff --cached`, remova o arquivo do índice (`git reset HEAD <arquivo>`) e apague o segredo do disco |
