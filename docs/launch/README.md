# Material de lançamento do FreeDSH

Este diretório reúne os textos prontos para publicar, um por comunidade, cada um adaptado ao
público daquele lugar. O objetivo não é "viralizar": é conseguir os **primeiros usuários reais**
e os primeiros relatos reproduzíveis.

> **Lembrete obrigatório em todo post:** o FreeDSH é um projeto **não oficial**, sem vínculo com a
> DeepSeek. Ele é uma camada de distribuição sobre o DeepSeek Harness
> (`github.com/deepseek-ai/deepseek-harness`, MIT).

## Índice

| Arquivo | Canal | Idioma | Formato |
|---|---|---|---|
| [`tabnews.md`](tabnews.md) | TabNews | pt-BR | post de dev contando o que fez, 1 bloco de código |
| [`r-brdev.md`](r-brdev.md) | r/brdev | pt-BR | ferramenta em português + instalador de 1 linha no Windows |
| [`hackernews.md`](hackernews.md) | Hacker News | inglês | Show HN, curto e técnico, sem hype |
| [`reddit-localLlama.md`](reddit-localLlama.md) | r/LocalLLaMA | inglês | título direto, foco em custo e roteamento entre provedores |
| [`linkedin.md`](linkedin.md) | LinkedIn | pt-BR | tom profissional, problema → solução |
| [`x-thread.md`](x-thread.md) | X/Twitter | pt-BR + inglês | thread de 4–6 posts, com sugestão de GIF/vídeo |
| [`upstream-discussion.md`](upstream-discussion.md) | Discussions do DeepSeek Harness | inglês | aviso respeitoso de ecossistema, só pedindo feedback |
| [`awesome-lists.md`](awesome-lists.md) | Listas "awesome" e índices de plugins | inglês | texto exato da entrada sugerida + cuidados |

## Regra de ouro

**Um post por comunidade, escrito para aquela comunidade. Nunca copiar e colar em massa.**

Três consequências práticas:

1. Se dois canais têm a mesma audiência (ex.: r/brdev e LinkedIn BR), publique com pelo menos
   3 dias de diferença e mude o ângulo — não o texto.
2. Se um post foi mal recebido, **não repita a mesma coisa** no canal seguinte antes de entender o
   problema. A primeira resposta ruim costuma ser um problema de onboarding, não de marketing.
3. Entre um post e o próximo, conserte o que os comentários apontaram. Um post que gera 5 relatos
   de bug vale mais do que 5 posts que geram 0.

## Fase 0 — antes de qualquer post

Nada aqui é opcional se o objetivo é que alguém consiga instalar.

- [ ] Descrição e topics do repositório preenchidos (ver `docs/COMMUNITY-LAUNCH.md`). **Já feito**:
      20 topics, incluindo `pt-br`, `portuguese`, `localization`, `i18n`, `windows`,
      `windows-installer`, `dsh-bundle` e `freedsh`.
- [ ] Landing page no ar, com o comando canônico publicado nela
      (<https://marcosmmjr2023.github.io/dsh-h-v1/>). **Já está no ar**: ela é o canal de aterrissagem
      do projeto junto do `README.md`, e os dois precisam mudar juntos quando o comando mudar.
- [ ] Discussions ativas, com categorias e os primeiros tópicos semeados (`docs/DISCUSSIONS-SEED.md`).
- [ ] GIF de 20–30s no topo do README + 3–4 screenshots sem chaves, sem paths pessoais.
- [ ] Pelo menos **um teste real e datado** de provedor/fallback, para citar quando alguém perguntar.
- [ ] Testar a instalação de 1 linha em uma máquina limpa, em PowerShell 5.1 **e** 7.x.
- [ ] Confirmar que o instalador não quebrou nenhuma instalação existente.

Cuidado conhecido: existe **um** comando canônico de instalação no Windows — o mesmo do `README.md` e
da página do projeto. Ele baixa o script para um arquivo temporário com
`-Headers @{'Cache-Control'='no-cache'}` antes de executar, o que evita problemas de encoding/BOM no
PowerShell 5.1 **e** uma cópia velha vinda do cache do `raw.githubusercontent.com`.

**Não publique a forma curta `irm ... | iex` nem a variante sem `-Headers`** — se algum post ainda
tiver uma delas, troque pelo comando canônico. Se o formato do canal não couber o comando inteiro
(uma thread do X, por exemplo), aponte para a landing page
<https://marcosmmjr2023.github.io/dsh-h-v1/> como fonte do comando, em vez de encurtar o comando.

## Ordem de publicação

| # | Quando | Canal | Arquivo | Por que nesta posição |
|---:|---|---|---|---|
| 1 | Dia 0, manhã (BRT) | TabNews | `tabnews.md` | Menor barreira e feedback mais rápido. Serve de ensaio: os comentários revelam o que está confuso no onboarding. |
| 2 | Dia +2 ou +3 | r/brdev | `r-brdev.md` | Público pt-BR com dor explícita de Windows/idioma. Aproveita o texto já corrigido pelo feedback do TabNews. |
| 3 | Dia +3 ou +4, 8h–10h ET, ter–qui | Hacker News | `hackernews.md` | Janela curta e implacável. Só faça depois que a instalação estiver redonda. |
| 4 | Dia +5 a +7 | r/LocalLLaMA | `reddit-localLlama.md` | Audiência técnica em inglês, discussão de custo/roteamento. Melhor com o benchmark já publicado. |
| 5 | Dia +7 a +10 | LinkedIn | `linkedin.md` | Alcance profissional em pt-BR, ciclo mais lento e menos técnico. |
| 6 | Distribuído | X | `x-thread.md` | Fatiar: o primeiro post no Dia 0/1, o resto ao longo das duas semanas. |
| 7 | Dia +7 a +14 | Discussions do upstream | `upstream-discussion.md` | Só depois de ter algo concreto a mostrar (um relato de usuário, um bug corrigido). |
| 8 | Dia +14 em diante | Awesome lists | `awesome-lists.md` | Só quando houver uso real. Listas sérias rejeitam projeto sem tração, e um "não" cedo queima a chance futura. |

Regras de intervalo:

- **3 a 7 dias** entre canais com audiências parecidas.
- No máximo **dois canais por semana**, sem publicar nos dois no mesmo dia.
- Não publique dois textos em inglês técnico (HN e r/LocalLLaMA) na mesma semana: se o HN der
  certo, os comentários vão virar sua lista de tarefas.
- Se o post do HN morrer em silêncio, o problema quase sempre é o título, não o projeto. Deixe
  passar pelo menos um mês antes de tentar de novo, e com ângulo diferente.

## O que medir

O lugar certo é **GitHub → Insights → Traffic**:

- **Views** (visitas totais e visitantes únicos) — interesse bruto.
- **Clones** (total e únicos) — sinal muito mais honesto: significa que alguém baixou o repo.
- **Referring sites** — de onde a visita veio de fato. É assim que você descobre qual canal
  funcionou, inclusive quando o post "não teve comentário".

Como usar:

1. Tire uma fotografia **antes** do primeiro post (linha de base).
2. Tire outra **24h** e **72h** depois de cada post, e uma **7 dias** depois.
3. Anote em `docs/POST-LAUNCH-METRICS.md`, junto com data, canal e o que foi publicado.

Sinais que valem mais do que números grandes:

- alguém instalou e voltou para contar o que aconteceu;
- alguém abriu um relato de provedor reprodutível (data, provedor, modelo, erro);
- alguém perguntou algo que revelou falha na documentação;
- alguém abriu um PR ou pegou uma issue `good first issue`;
- visita + clone + silêncio: alguém tentou e desistiu — vá perguntar onde travou.

Cuidado com métrica de vaidade: impressão, curtida e estrela isolada sem uso não indicam adoção.
O `docs/POST-LAUNCH-METRICS.md` já separa sinal forte de sinal fraco; siga a mesma régua.

## O que não fazer

- Não publique o mesmo texto em várias comunidades no mesmo dia.
- Não peça estrela de forma insistente. Uma linha discreta no fim é aceitável; um post pedindo
  estrela não é.
- Não invente número nenhum. Nada de "usado por muita gente" ou "economiza X%". A frase correta é
  **"projetado para usar modelos gratuitos antes dos pagos"**.
- Não prometa "grátis para sempre": os tiers gratuitos mudam sem aviso.
- Não diga que o FreeDSH contorna limites ou termos de provedor. Ele integra e roteia as chaves que
  você mesmo configurou.
- Não responda crítica técnica na defensiva. Agradeça, pergunte o ambiente, corrija depois.
- Não poste print com chave de API, prompt privado, path pessoal ou nome de conta.

## Estado atual do repositório (para você ser honesto se for citar)

`dsh-h-v1`: **1 star, 0 forks, 127 tags, 1 release publicada.** A release é a tag `v0.2.125`,
título "FreeDSH v0.2.125", com os assets `freedsh-v0.2.125.zip` e `SHA256SUMS.txt`:
<https://github.com/marcosmmjr2023/dsh-h-v1/releases/tag/v0.2.125>. É um projeto novo, buscando os
primeiros usuários. Assuma isso nos posts — "acabei de abrir" é mais convincente do que fingir
tração que não existe, e abre espaço para pedir ajuda de verdade.

Cuidado com a leitura das 127 tags: a maioria é âncora automática de rollback criada pelo auto-push
(mensagem `sync(auto): ...`), **não** lançamento. Só as tags anotadas por `tools/release.sh`
(mensagem começando com `release:`) viram release.

O que **já existe** hoje e pode ser citado com segurança — isto é estado, não promessa:

- **Licença MIT**, e o GitHub já detecta o repositório como MIT (antes aparecia "NOASSERTION"). O
  escopo — o que a MIT deste repositório cobre e o que é de terceiros/upstream — fica em
  `LICENSE-SCOPE.md`, junto do aviso de não afiliação. Por isso aquele arquivo existe **fora** do
  `LICENSE`: um preâmbulo antes do texto MIT faz o GitHub classificar como "NOASSERTION".
- **Duas formas de instalar.** (1) O instalador do Windows, com o comando canônico acima. (2) O
  **bundle do DSH**, sem instalador, para quem já tem um harness funcionando:
  `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1` — remover com
  `dsh plugin --profile web remove freedsh`. O bundle registra **6 plugins** do harness (Smart Router,
  grupos do OpenRouter, visibilidade de modelos, atalho do FreeLLMAPI, painel lateral e badge de
  versão) e nada mais: não toca em chaves, provedores ou settings. Foi instalado e testado de verdade
  em um `DSH_HOME` limpo, com os 6 plugins carregando e as APIs respondendo 200.
- **Repositório apresentável**: descrição atualizada, homepage e **20 topics** (incluindo `pt-br`,
  `portuguese`, `localization`, `i18n`, `windows`, `windows-installer`, `dsh-bundle`, `freedsh`) e
  **GitHub Pages no ar** em <https://marcosmmjr2023.github.io/dsh-h-v1/> — a **landing page** do
  projeto, com o comando de instalação publicado nela (e o botão dela apontando para o repositório,
  que é onde ficam os arquivos e a release). Use-a como destino dos posts, ao lado do `README.md`.
- **Release automática por tag**: `.github/workflows/release.yml` publica a GitHub Release (notas do
  CHANGELOG + `freedsh-<tag>.zip` + `SHA256SUMS.txt`) quando uma tag anotada é criada por
  `tools/release.sh` (mensagem `release: ...`). As tags do auto-push (`sync(auto): ...`) são
  ignoradas de propósito, para não inundar a aba Releases.

**Tráfego real** (Insights → Traffic, últimos 14 dias): **90 views (11 visitantes únicos)**, **2136
clones (419 únicos)** e referrer `github.com` (54). Traduzindo: há pouquíssima descoberta real — isto
não é tração —, mas **não é literalmente zero**. Nunca escreva "zero procura": a frase honesta é "11
visitantes únicos em 14 dias".

## Verificação de fatos no dia do post

Antes de publicar qualquer coisa, confirme:

- [ ] o número de stars do DeepSeek Harness que você for citar (é volátil);
- [ ] quais tiers gratuitos ainda existem nos provedores citados;
- [ ] o estado do repositório (stars/forks/tags/releases) se você for mencionar. Fotografia de hoje:
      **1 star, 0 forks, 127 tags, 1 release** (a `v0.2.125`);
- [ ] qual é a **release mais recente**, se o post citar release ou download (aba Releases, ou
      `gh release list`), e se os assets (`freedsh-<tag>.zip`, `SHA256SUMS.txt`) continuam no ar;
- [ ] que o GitHub **continua detectando a licença como MIT** — a detecção depende de o `LICENSE`
      seguir sendo o texto MIT limpo, sem preâmbulo (o preâmbulo mora em `LICENSE-SCOPE.md`);
- [ ] que a **landing page** (<https://marcosmmjr2023.github.io/dsh-h-v1/>) está no ar e que o comando
      publicado nela é idêntico ao do `README.md`. Página e README andam juntos: um comando novo sem
      atualizar o outro é a forma mais rápida de publicar informação errada;
- [ ] a contagem de frases da tradução pt-BR, se for citar;
- [ ] que o comando de instalação daquele post ainda funciona, colando ele de verdade em um terminal —
      o **comando canônico**, com `-Headers @{'Cache-Control'='no-cache'}`, nunca a forma
      `irm ... | iex`;
- [ ] se o post citar o bundle do DSH, teste
      `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1` em um `DSH_HOME` limpo antes de
      publicar (a instalação e a remoção precisam continuar funcionando).

Um número errado em um post público custa mais credibilidade do que qualquer ganho de entusiasmo.

> **Notas de publicação**: este arquivo é o playbook interno, não um post — não publique ele em lugar
> nenhum. Ele fica no repositório justamente para que a ordem, os intervalos e a régua de métricas
> não dependam de memória. Cada arquivo de post traz, no fim, a sua própria nota de publicação com
> horário, flair/regra da comunidade e o que evitar naquele canal; leia a nota **antes** de publicar,
> não depois. Quando um post gerar aprendizado que mude este playbook (um horário que não funcionou,
> uma comunidade que recusou autopromoção), atualize o arquivo do canal e este índice no mesmo
> commit — o material envelhece rápido e um playbook desatualizado é pior do que nenhum.
