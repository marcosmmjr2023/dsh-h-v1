# core-i18n-pt — Português (pt-BR) para o núcleo do DeepSeek Harness

Camada de tradução **pt-BR da interface do núcleo** (`@deepseek-ai/dsh`), mantida
como patch próprio aqui no repo dsh-h-v1. O núcleo oficial só nasce com
`zh`/`en` (`locale.preference` em `settings.yaml`; dicionários por pacote). Este
projeto adiciona **Português** como terceiro idioma — selecionável em
**Settings → Language**, como as outras.

> Por que "patch" e não edição normal: o núcleo é instalado via npm (root no
> Linux) e atualizado **manualmente** (política L1). Este diretório guarda os
> patches + ferramentas para aplicar/reaplicar em qualquer máquina depois de
> cada instalação/atualização do core. As traduções ficam aqui (versionadas e
> sincronizadas pelo git); os arquivos do core nunca são versionados.

## Arquitetura

| Camada | O quê | Onde |
|---|---|---|
| **Encanamento pt** (patch 01) | adiciona `pt` a `LOCALE_IDS`, ao schema `locale.preference` (host + browser) e ao seletor de idioma (`Português`), `<html lang="pt-BR">` e detecção do navegador | `patches/01-dsh-client-locale-pt-plumbing.patch` |
| **Dicionários pt-BR** (em andamento) | tradução dos catálogos `{zh,en}` de cada pacote de UI → `pt:{...}`, registrados por namespace; chave sem tradução cai no fallback `en` (nunca quebra) | futuros `patches/02-*` + `dictionaries/<pacote>/<ns>.json` |
| **Ferramentas** | aplicar/reaplicar/reverter/verificar o patch; inventário dos dicionários do core | `tools/` |
| **Publicação** | qualquer mudança aqui segue as regras do repo (commit + `tools/release.sh` → `vX.Y.Z`) | repo dsh-h-v1 |

Detalhe do runtime (núcleo 0.1.1-rc.2, pacote `dsh-client-locale`):
`LocaleRuntime.register(ns, {zh, en})` guarda dicionário por namespace×locale;
a cadeia de busca por chave é `ns[ativo] → ns[en] → common[ativo] → common[en] →
chave`. Logo, com `pt` ativo, chaves ainda não traduzidas aparecem em inglês até
a tradução do namespace chegar — degradação segura.

## Como aplicar numa máquina

```bash
# 1. (opcional) conferir antes de aplicar:
core-i18n-pt/tools/apply-pt-core.sh --check

# 2. aplicar (detecta a instalação do core em /opt/dsh-tui ou /usr/lib;
#    se o diretório for root, rode com sudo):
core-i18n-pt/tools/apply-pt-core.sh
sudo core-i18n-pt/tools/apply-pt-core.sh          # Linux, install global root

# 3. reiniciar a GUI do harness (pm2 restart dsh-web-v2 ou reabrir o .bat)
# 4. Settings → Language → Português
```

- A ferramenta é **idempotente**: marca a versão do core e o hash dos patches
  aplicados; se o core for atualizado (`npm update -g @deepseek-ai/dsh`),
  reaplique com `apply-pt-core.sh` (e re-teste antes de confiar).
- Reverter: `apply-pt-core.sh --revert`.
- Windows: o core npm global fica no diretório do usuário (`npm root -g`) —
  aplique sem sudo apontando a raiz, ex.:
  `DSH_CORE_PKGS="$(npm root -g)/@deepseek-ai/dsh/node_modules/@deepseek-ai" core-i18n-pt/tools/apply-pt-core.sh`

## Status / roteiro

- [x] **01 — Encanamento pt** (patch pronto, testado com `git apply`/`patch` em cópia
      limpa + `node --check`): `Português` aparece no seletor; preferência
      `locale.preference: pt` aceita no host e no browser; `<html lang=pt-BR>`.
- [x] **02/03 — `common` + `settings.locale` + `settings`/General** (31 chaves).
- [x] **04–18 — 15 pacotes de UI de médio porte** (≈160 frases novas em
      `dictionaries/en-phrases.json`, total 190): sidebar, theme, plan, reference,
      deliverables, input-trigger, jobs, message-feedback, model-selection,
      permission-presets, commands, user-questions, subagent, workflow-run, goal —
      todos com **cobertura total das chaves en** (0 no fallback). Validação:
      aplicação sequencial 01→18 numa árvore limpa completa (byte-a-byte) +
      `node --check`.
- [x] **19–27 — Pacotes restantes** (patches 19–27): conversation (170/170),
      trajectory, agent-preset, settings-plugins, settings-plugin-inventory,
      cordis, workspace, settings-models, skill — **dicionários de TODOS os
      26 arquivos de UI cobertos** (0 frases en sem tradução; tabela com 624
      frases). O parser (`ptlib.mjs`) passou a entender chaves sem aspas,
      valores-constante e caminhos (`WELCOME_NOTICE_COPY.en.title`).
      Validação: árvore limpa completa → **27/27 patches aplicam em ordem**,
      sintaxe OK, `apply --check` verde no core real.
- [ ] **Validação em instância de teste** (boot do núcleo patcheado em outra porta
      com home próprio) e em máquina real após aplicar.
- [ ] Regressão visual nas 3 línguas + paridade de chaves pt×en (textos inline
      fora dos dicionários — limitação conhecida do upstream — ficam en/zh).

> Observação honesta: traduzir TODA a UI do núcleo é um projeto grande
> (dezenas de pacotes `dsh-client-ui-*` com dicionários e textos inline). A
> ordem sugerida é: superfícies de maior uso (settings, sidebar, composer,
> conversa) → resto; cada pacote vira um patch numerado.
