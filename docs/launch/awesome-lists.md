# Awesome lists e índices de plugins

Onde pedir inclusão, com o texto exato da entrada sugerida.

**Antes de qualquer PR: leia o `CONTRIBUTING.md` da lista.** Cada uma tem regra própria sobre
posição alfabética, uma entrada por PR, formato do link, se aceita ferramenta ou só recurso, e se
aceita autopromoção. Uma entrada fora do formato é fechada sem discussão.

## Candidatas (confirme owner/repo e regras antes de abrir o PR)

| Lista | Adequação | Observação |
|---|---|---|
| `awesome-deepseek-integration` (integrações do ecossistema DeepSeek) | alta | É o encaixe mais natural: somos uma camada de distribuição do harness. Verifique se a lista aceita overlay não oficial. |
| `awesome-deepseek` (listas comunitárias) | alta | Costuma ter seção de ferramentas/CLI. Cheque se existe seção para "harness" ou "agentes". |
| `awesome-ai-agents` | média | Encaixa se você descrever o FreeDSH como camada de roteamento para um agente de código, não como agente novo. |
| `awesome-llm-apps` | média | Muitas variantes da mesma ideia. Escolha uma, a mais ativa, e não abra PR em três ao mesmo tempo. |
| `awesome-llm` | média | Lista ampla e movimentada; costuma exigir projeto com alguma tração. |
| `awesome-free-llm-apis` / listas de APIs gratuitas | alta | Encaixe direto no tema "usar modelos gratuitos antes dos pagos" — mas descreva como agregador de chaves do usuário, nunca como fonte de acesso grátis. |
| Índices/registries de **plugins do DeepSeek Harness** | alta | O overlay **já é** um conjunto de plugins do harness. Se existir um índice de plugins (ou um comando tipo `dsh plugin`), esse é o caminho de distribuição mais correto de todos. |
| Listas "awesome" em pt-BR / de projetos brasileiros | média | Bom encaixe para o ângulo "ferramenta de IA em português". Confirme se a lista aceita projeto mantido por uma pessoa só e sem releases. |
| `awesome-windows` / listas de ferramentas para Windows | baixa | Só faz sentido se o instalador de 1 linha for o destaque da entrada, e se a lista aceitar aplicação que depende de outro projeto. |

Não invente URL. Antes de abrir o PR, procure o repositório no GitHub, confirme que ele existe,
que está ativo (último commit recente) e que a seção onde você vai inserir existe de fato.

## Texto exato da entrada sugerida

**Padrão (para listas em inglês, formato `- [Nome](url) — descrição.`):**

```
- [FreeDSH](https://github.com/marcosmmjr2023/dsh-h-v1) — Unofficial distribution layer for DeepSeek Harness: free-first model routing with automatic provider fallback, safe core updates and pt-BR localization.
```

**Versão curta (para listas de plugins do harness, que costumam ter entradas de uma linha só):**

```
- [FreeDSH](https://github.com/marcosmmjr2023/dsh-h-v1) — Harness plugin bundle: free-first model router, automatic fallback, integrated panel and pt-BR localization.
```

**Versão para listas de APIs/modelos gratuitos:**

```
- [FreeDSH](https://github.com/marcosmmjr2023/dsh-h-v1) — Free-first router for DeepSeek Harness that orders free providers before paid ones and falls back automatically, using only keys the user configures.
```

**Versão em português (para listas pt-BR):**

```
- [FreeDSH](https://github.com/marcosmmjr2023/dsh-h-v1) — Camada de distribuição não oficial do DeepSeek Harness: roteamento free-first com fallback automático, atualização segura do core e tradução pt-BR.
```

Regras de forma que essas listas costumam cobrar, e que as entradas acima já respeitam:

- uma linha só, sem quebra de linha, terminando com ponto;
- sem adjetivo de marketing ("powerful", "revolutionary", "blazing fast");
- sem emoji;
- nome do projeto como texto do link, URL do repositório como destino;
- descrição começando com o que é, não com "a tool that allows you to…";
- deixar claro que é não oficial — isso evita que a entrada seja tratada como representação do
  projeto upstream.

## Como pedir, na prática

1. Leia `CONTRIBUTING.md` e, se existir, `README` na seção "Contributing".
2. Verifique a seção correta e a **posição alfabética** — a maioria das listas ordena por nome.
3. Faça **um PR por lista**, com título simples (`Add FreeDSH to <seção>`), corpo curto: o que é,
   por que pertence àquela seção, e a confirmação de que é projeto não oficial.
4. Espere. Não comente cobrando review.
5. Se receber "não", agradeça e siga. Reabrir o mesmo PR é o jeito mais rápido de queimar a chance
   futura.

## O cuidado honesto sobre timing

Muitas listas sérias têm critério informal de tração: projeto com algum tempo de estrada, uso
comprovado, releases publicadas. O estado atual é **1 star, 0 forks, 125 tags e 0 releases
publicadas** — ou seja, boa parte delas vai recusar hoje, e com razão.

Por isso a recomendação é **esperar**: publique os posts de comunidade primeiro, colete relatos de
uso, publique pelo menos uma release, e só depois vá atrás das listas. Um "não" agora custa a chance
de um "sim" em dois meses. E não abra dez PRs de um mesmo perfil novo no mesmo dia — isso é lido como
spam e pode bloquear a conta.

> **Notas de publicação**: aqui não existe "horário de pico" — o que existe é leitura de regra e
> paciência. PRs dessas listas são revisados por mantenedores voluntários, então espere dias, não
> horas. Faça um PR por vez e aguarde o merge antes de abrir o seguinte: se uma lista recusar por
> formato, você corrige antes de repetir o erro nas outras. Nunca marque o mantenedor da lista no X
> cobrando review, e nunca edite a entrada de outro projeto no mesmo PR para "encaixar" a sua — PR
> com mudança não relacionada é fechado na hora. Quando houver release publicada, volte às listas que
> recusaram por falta de tração citando a release; é uma reabertura legítima, diferente de insistir.
