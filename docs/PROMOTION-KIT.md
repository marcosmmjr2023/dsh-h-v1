# FreeDSH Promotion Kit

Ready-to-adapt copy for public launch. Keep posts factual and update any provider/free-tier claims with current test data before publishing.

## Reddit — technical launch

### Suggested title

**I built a free-first routing layer for DeepSeek Harness with automatic fallback — looking for testers and contributors**

### Suggested body

I’ve been using DeepSeek Harness and wanted a setup that was less dependent on a single paid provider. I ended up building **FreeDSH**, an unofficial open-source layer that adds free-first model routing, automatic provider fallback, a local FreeLLMAPI gateway, safer parallel core updates, rollback tooling and pt-BR support.

The goal is not to promise that AI inference is permanently “free” — free tiers change constantly. The goal is to make it practical to combine available free/low-cost providers and fall back gracefully when one is unavailable.

Current pieces include:

- FreeLLMAPI + provider routing;
- OpenRouter `:free` and OpenCode free/zen routes;
- task-aware `auto` / `eco` / `ultra` profiles;
- Windows and Linux one-line installers;
- parallel core instances so an update does not overwrite the working setup;
- local snapshots and rollback;
- English and Brazilian Portuguese docs/UI support.

I’m now trying to turn it from a personal setup into a community project. I’d especially value help testing provider compatibility, macOS, routing benchmarks, screenshots/demo media and additional translations.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1

If you test it, please include OS, DeepSeek Harness version, provider/model and sanitized error output when reporting problems. I’m particularly interested in real-world fallback behavior rather than just star counts.

## Hacker News

### Title

**Show HN: FreeDSH – Free-first model routing and safe updates for DeepSeek Harness**

### First comment / description

FreeDSH is an unofficial open-source layer around DeepSeek Harness focused on free/low-cost provider routing, automatic fallback, local provider aggregation, versioned config and rollback-safe core updates.

I built it because I wanted to use Harness daily without coupling the workflow to one provider or overwriting a working environment every time the core changed.

The repository now has one-line Windows/Linux installers, contribution docs and open issues for provider compatibility, routing benchmarks, macOS testing and observability.

Repo: https://github.com/marcosmmjr2023/dsh-h-v1

Feedback on architecture, provider handling and reproducibility is especially welcome.

## LinkedIn — English

I’m opening up a project I originally built for my own DeepSeek Harness workflow: **FreeDSH**.

It adds a free-first multi-model routing layer with automatic fallback, local provider aggregation, safer parallel core updates and rollback — while keeping provider credentials local.

The project now supports Windows and Linux onboarding, English/pt-BR documentation and has a public roadmap plus `good first issue` tasks for contributors.

I’m looking for people interested in testing provider compatibility, macOS support, routing benchmarks, observability and translations.

GitHub: https://github.com/marcosmmjr2023/dsh-h-v1

## LinkedIn — Português

Estou abrindo para a comunidade um projeto que nasceu para resolver um problema do meu próprio uso diário do DeepSeek Harness: o **FreeDSH**.

A proposta é combinar vários modelos/provedores gratuitos ou de baixo custo, fazer roteamento automático entre eles e usar fallback quando um serviço falha — sem depender de uma única API. O projeto também adiciona atualização segura do core em instância paralela, rollback, painel integrado e suporte em português.

Agora o repositório tem documentação para colaboradores, roadmap público e tarefas `good first issue` para quem quiser participar.

Procuro principalmente pessoas para testar provedores, macOS, benchmarks de roteamento, métricas de fallback e novas traduções.

GitHub: https://github.com/marcosmmjr2023/dsh-h-v1

## X / short post 1 — routing

Built a free-first model router for DeepSeek Harness.

Provider fails → FreeDSH falls back to another configured route automatically.

FreeLLMAPI + OpenRouter `:free` + OpenCode + optional paid fallback.

Open source: https://github.com/marcosmmjr2023/dsh-h-v1

## X / short post 2 — safe updates

A DeepSeek Harness update shouldn’t destroy a working setup.

FreeDSH can spin up a new core in a parallel instance so you can test it before replacing anything — with rollback if needed.

https://github.com/marcosmmjr2023/dsh-h-v1

## Brazilian developer-community post

### Title

**FreeDSH: DeepSeek Harness com roteamento entre modelos gratuitos, fallback automático e interface em português**

### Body

Criei uma camada open source para o DeepSeek Harness com foco em uso cotidiano e custo baixo: o FreeDSH.

Em vez de depender de um único provedor, ele pode encaminhar tarefas entre rotas configuradas no FreeLLMAPI, OpenRouter `:free`, OpenCode e outros provedores, com fallback automático quando uma rota falha.

Também inclui instalador para Windows/Linux, interface/documentação em português, atualização do core em instância paralela e rollback por snapshots/git.

O projeto está entrando agora numa fase comunitária. Há issues abertas para compatibilidade de provedores, macOS, benchmark, estatísticas de fallback, screenshots e tradução para espanhol.

GitHub: https://github.com/marcosmmjr2023/dsh-h-v1

Críticas técnicas e testes reproduzíveis são especialmente bem-vindos.

## Rules before publishing

- Verify current provider/free-tier claims on the day of posting.
- Read each community’s self-promotion rules.
- Do not cross-post identical copy everywhere at the same time.
- Prefer a real benchmark, screenshot or GIF over marketing adjectives.
- Never expose credentials, personal paths, prompts or account identifiers.
