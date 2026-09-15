# Instalar o FreeDSH como bundle do DeepSeek Harness

*Português · [English version below](#english)*

Este documento cobre o caminho mais curto para quem **já tem o DeepSeek Harness
funcionando** e quer só os recursos do FreeDSH no painel, sem rodar instalador e
sem copiar overlay nenhum.

> **Projeto não oficial.** O FreeDSH não é afiliado, patrocinado ou endossado pela
> DeepSeek. O núcleo do DeepSeek Harness é instalado à parte, pelo npm, e mantém a
> licença dele.

---

## O comando

```bash
dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1
```

Se o pacote já estiver publicado no npm, a forma curta também funciona:

```bash
dsh plugin --profile web add freedsh
```

Reinicie a GUI (`dsh up`, ou o atalho que você usa). Os plugins aparecem na coluna
direita do painel.

Para remover:

```bash
dsh plugin --profile web remove freedsh
```

> Instalação e remoção testadas de ponta a ponta em um `DSH_HOME` limpo: o `add`
> registra `freedsh` em `dsh.profile.bundles`, e o `remove` tira a dependência **e** a
> linha do bundle do perfil, sem deixar pasta no `node_modules`.

## O que entra

Seis plugins, registrados na camada do perfil (nada é sobrescrito no núcleo):

| Plugin | O que faz |
|---|---|
| Smart Model Router | roteamento free-first por tipo de tarefa, com cadeia de fallback |
| OpenRouter Enhanced | grupos "OpenRouter Free" e "OpenRouter Pro" no seletor de modelos |
| Model Visibility | filtro do catálogo e página de modelos |
| FreeLLMAPI Shortcut | atalho para o painel do gateway local |
| Layout Panel | coluna direita com badges, arquivos recentes e status |
| Version Badge | versão instalada, atualização segura do núcleo, snapshots e rollback |

## O que **não** entra

- **chaves, provedores e modelos**: continuam nos seus arquivos de configuração
  (`settings.yaml`, credenciais locais). O bundle não lê nem escreve neles;
- **o catálogo customizado do provedor DeepSeek oficial** e as regras de
  compactação: são específicos de cada máquina — veja
  `overlay/cordis.patch.yml.win.tpl` no pacote e copie só as linhas que quiser para
  o seu `$DSH_HOME/cordis.patch.yml`;
- **tradução pt-BR automática do núcleo**: as ferramentas vêm no pacote
  (`core-i18n-pt/`), mas aplicar a tradução é uma decisão explícita
  (`core-i18n-pt/README.md`).

## Como o estado é guardado

O pacote é instalado em `node_modules` **e é imutável**: nada é gravado dentro dele.
Tudo o que é do usuário — carimbo de versão, flags (`auto-update`), histórico de
núcleo, catálogo do OpenRouter — vai para a **config viva** (`$DSH_HOME`, ou
`~/.dsh` quando a variável não está definida). Se você apagar o pacote, seus dados
continuam lá.

## Requisitos

- **DeepSeek Harness** instalado (`npm i -g @deepseek-ai/dsh`);
- **pnpm** no PATH (o `dsh plugin` é um encaminhador para o pnpm — `npm i -g pnpm`);
- **git** para a forma `github:` (a forma pelo npm não precisa);
- Windows 10/11 ou Linux. No Windows, PowerShell 5.1 e 7.x são suportados.

## Problemas comuns

**`pnpm` não encontrado** — o `dsh plugin` avisa: `pnpm not found on PATH`.
Instale (`npm i -g pnpm`) e abra um terminal novo.

**Aviso sobre `allowBuilds`** — aparece quando a dependência tem script de build.
O FreeDSH **não tem** script de ciclo de vida (`prepare`/`install`), justamente
para não depender disso; se você vir esse aviso, é de outro pacote.

**Os plugins não aparecem depois de reiniciar** — confira se o perfil realmente
listou o bundle:

```bash
dsh plugin --profile web list
```

O `package.json` do perfil (`$DSH_HOME/profiles/web/package.json`) deve ter
`"freedsh"` dentro de `dsh.profile.bundles`.

**Quero o caminho completo (instalador, atalhos, auto-sync)** — o instalador de uma
linha continua sendo o caminho recomendado no
[README](../README.md#install-in-1-minute) e na
[página do projeto](https://marcosmmjr2023.github.io/dsh-h-v1/).

---

## English

The short path for people who **already run DeepSeek Harness** and only want the
FreeDSH features in the panel — no installer, no overlay copying:

```bash
dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1
# once published to npm:  dsh plugin --profile web add freedsh
# to remove:              dsh plugin --profile web remove freedsh
```

**What you get:** six plugins registered as a profile layer (Smart Router,
OpenRouter groups, model visibility, FreeLLMAPI shortcut, layout panel, version
badge with safe core updates and rollback).

**What is not touched:** your keys, providers and model settings; the custom
DeepSeek provider catalog; the pt-BR core translation (the tools ship in the
package, applying them is explicit).

**Where state lives:** the installed package is immutable — version stamp, flags,
core history and the OpenRouter catalog go to `$DSH_HOME` (or `~/.dsh`).

**Requirements:** DeepSeek Harness, pnpm on PATH, git (only for the `github:`
form), Windows 10/11 or Linux, PowerShell 5.1 or 7.x on Windows.

**Common issues:** `pnpm not found on PATH` → `npm i -g pnpm`; plugins not showing
up → check that `freedsh` is listed in `dsh.profile.bundles` inside
`$DSH_HOME/profiles/web/package.json`.

> **Unofficial project.** Not affiliated with, sponsored or endorsed by DeepSeek.
