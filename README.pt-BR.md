# dsh-h-v1 — Camada personalizada + auto-atualização + rollback para o DeepSeek Harness

Sistema baseado em git que mantém a **sua configuração personalizada do DeepSeek Harness**
(plugins customizados, roteador de modelos, presets, assets de editor) **idêntica em todas
as suas máquinas** — e permite **voltar com segurança** quando uma atualização automática
quebra algo.

Construído sobre o [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(*"Everything is a Plugin"*). **Distribuição não oficial** — customização pessoal, sem
vínculo com a DeepSeek.

---

## 🎯 Para que serve este repositório

1. **Uma fonte da verdade para a sua camada personalizada** — settings, plugins e
   presets como código versionado e revisável (histórico git, tags, diffs), em vez de
   ZIPs exportados na mão.
2. **Auto-atualização em todas as máquinas** — sync agendado/na inicialização puxa o
   overlay mais recente; nada é substituído **sem antes criar um snapshot local**.
3. **Rollback seguro** — se um PC parado há meses receber o update automático e quebrar,
   você volta ao estado exato que funcionava (snapshots locais, tags do git ou a versão
   anterior do core).
4. **Uso gratuito/barato de modelos, integrado** — roteamento inteligente sobre tiers
   gratuitos (gateway FreeLLM API, OpenRouter `:free`, OpenCode free/zen) com fallback
   automático, além do instalador Windows em um clique.

## ✨ Pilares de funcionalidade

### 1) Seu overlay versionado (`overlay/`)
`overlay/` espelha 1:1 o diretório de config vivo (`~/.dsh` no Linux,
`%USERPROFILE%\.dsh` no Windows): `settings.yaml`, o Smart Model Router, plugins de UI
(painel lateral, visibilidade de modelos, atalho FreeLLMAPI), presets e assets de editor
(CodeMirror/marked, MIT). Credenciais, sessões, logs e estado de runtime **nunca** entram
no repo.

### 2) Auto-atualização com rollback (`tools/`)
- `sync-pull` — puxa o repo e aplica o overlay **depois de snapshottar** o estado atual
  em `~/.dsh-snapshots/` (mantém as últimas 8).
- `sync-push` — publica as edições locais (`--tag vX.Y.Z` marca uma versão conhecida-boa).
- `auto-push` — **publicador rotineiro de mão dupla em TODA máquina onde você edita**:
  recebe o que as outras publicaram e sobe as suas edições da config viva sozinho — cada
  publicação fica **documentada sobre a última versão** (commit descritivo com os arquivos
  alterados, tag automática `vX.Y.Z` e entrada no `CHANGELOG.md`). Se duas máquinas
  editarem o mesmo arquivo antes de sincronizar, a última sincronização vira a versão
  atual e a outra fica preservada no histórico/tag — nunca força push, nada se perde.
  Guardrails: o interruptor `.dsh-autoupdate.off` (badge no painel) desliga a rotina e o
  guard de segredos bloqueia commit suspeito. Agende uma vez por máquina
  (`tools/auto-sync.sh` ou `tools\auto-sync.ps1` no Windows); ensaie com
  `tools/auto-push.sh --dry-run`. Manual: `docs/SYNC.md`.
- `rollback` — `--snapshot <nome>` restaura o estado exato pré-update da máquina;
  `<tag|commit>` reverte o overlay para uma versão publicada (removendo também arquivos
  que versões novas adicionaram); `--core <versão>` reinstala o core npm anterior.
- `check-core` — avisa quando o core oficial (`@deepseek-ai/dsh`) tem versão nova;
  aplicar update do core é **manual e testado** (plugins usam internals do DSH).
- `guard-secrets` — hook de pre-commit que **bloqueia** qualquer commit com chave/credencial.

### 3) Uso gratuito/barato de modelos, integrado
Plugins customizados do overlay ligam o harness a provedores gratuitos/de baixo custo:
- **Gateway FreeLLM API** (local, `http://127.0.0.1:3002`): adicione as chaves dos
  provedores gratuitos (Groq, Cerebras, Mistral, …) num só lugar; um badge no dashboard
  mostra a saúde do gateway e qual modelo REAL respondeu à última requisição (com
  indicador de failover).
- **Smart Model Router** (`smart-router/auto|eco|ultra`): a complexidade da tarefa
  escolhe um tier gratuito e o roteador faz fallback em runtime quando um provedor erra —
  cadeia gratuita: `freellmapi → openrouter → opencode free → opencode zen/deepseek →
  deepseek oficial`.
- As chaves são lidas de **variáveis de ambiente ou do `.credentials.yaml` local** —
  nunca commitadas. Veja os nomes das env vars em `manifest.json`.

### 4) Instalador Windows (`installer/`, `start-dsh-gui.bat`)
Instala o core oficial via npm (`npm install -g @deepseek-ai/dsh`), aplica o overlay e
cria um atalho na Área de Trabalho que roda o `sync-pull` antes de abrir a GUI em
`http://127.0.0.1:3080`.

## ⚠️ Nota honesta sobre "grátis"
Tiers gratuitos dependem dos termos e da disponibilidade de cada provedor e podem mudar
ou sumir. Este repo fornece o **roteamento e a integração**, não as chaves nem o serviço —
você usa suas próprias chaves por provedor. Nada aqui burla termos de uso de provedor.

## 🚀 Começo rápido

```bash
# receber atualizações nesta máquina (cria snapshot do estado atual primeiro)
tools/sync-pull.sh

# publicar edições locais (adicione --tag vX.Y.Z para marcar versão conhecida)
tools/sync-push.sh "o que mudou"

# ciclo completo automático em TODA máquina onde você edita (cron 30 min / Task Scheduler):
#   tools/auto-sync.sh            (Linux; ensaio: tools/auto-push.sh --dry-run)
#   tools\auto-sync.ps1           (Windows)
# cada publicação se documenta: commit descritivo + tag automática vX.Y.Z + CHANGELOG.md
# detalhes: docs/SYNC.md → "Sincronização automática via de mão dupla em TODAS as máquinas"

# algo quebrou depois de um update? volte
tools/rollback.sh list
tools/rollback.sh --snapshot <nome>    # estado exato pré-update da máquina
tools/rollback.sh v1.2.0               # uma versão publicada do overlay
tools/rollback.sh --core 0.1.1-rc.2    # core anterior (npm)
```

Manual completo: [`docs/SYNC.md`](docs/SYNC.md) (PT) · [`docs/SYNC.en.md`](docs/SYNC.en.md) (EN)
· Guia Windows: [`docs/WINDOWS-PT.md`](docs/WINDOWS-PT.md) · [`README.md`](README.md) (English)

## 🆚 Comparativo

| | DeepSeek Harness (origem) | [dsh-config-manager](https://github.com/xiajiajun516/dsh-config-manager) | [dsh-vibe-pack](https://github.com/LeemanCheung/dsh-vibe-pack) | **este repo** |
|---|---|---|---|---|
| Gerencia | runtime + plugins | backup/migração/sync de config (plugin com UI) | packs transacionais só-dados | **seus plugins JS customizados e settings como git** |
| Rollback | — | snapshot antes de restore | ledger atômico + uninstall | snapshots + histórico git + tags + **rollback do core** |
| Guard de segredos | assume | nunca exporta | rejeita | guard **bloqueia no commit** |
| Sync de plugins JS customizados | n/a | — | não (só dados) | **sim** |

## 🗄️ Linhagem arquivada (preservada, não canônica)

O `main` segue o modelo overlay + sync acima. A **linhagem legada de pacote Windows**
(`source/` antigo, launchers `bin.js`, ícones, `preload.cjs`, `start-parallel-dsh.bat`)
está preservada para referência, sem manutenção:
- branches `versao-pc1`, `versao-pc2` · tag `main-anterior-e553f9b`

Melhorias úteis dessa linhagem já foram migradas para o `main` (ex.: `layout-panel-plugin`
v1.1 multi-dir/junctions, badge FreeLLMAPI atualizado).

## 🛡️ Segurança

- Nenhuma credencial neste repo — chaves vêm de env vars ou do `.credentials.yaml`
  local (gitignored, excluído do sync e dos snapshots).
- `guard-secrets.sh` (hook de pre-commit + CI) bloqueia commits com chave/credencial.
- Repo auditado antes da publicação (sem segredos, histórico limpo).

## 📜 Licenças

- Arquivos originais (overlay, tools, installer, docs): **MIT** — [`LICENSE`](LICENSE)
- Assets de terceiros (`overlay/editor-assets/`): MIT — [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- Core do DeepSeek Harness: **MIT © DeepSeek**, instalado via npm, não redistribuído aqui
  ([github.com/deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness))
