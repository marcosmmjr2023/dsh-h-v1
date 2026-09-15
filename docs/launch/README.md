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

- [ ] Descrição e topics do repositório preenchidos (ver `docs/COMMUNITY-LAUNCH.md`).
- [ ] Discussions ativas, com categorias e os primeiros tópicos semeados (`docs/DISCUSSIONS-SEED.md`).
- [ ] GIF de 20–30s no topo do README + 3–4 screenshots sem chaves, sem paths pessoais.
- [ ] Pelo menos **um teste real e datado** de provedor/fallback, para citar quando alguém perguntar.
- [ ] Testar a instalação de 1 linha em uma máquina limpa, em PowerShell 5.1 **e** 7.x.
- [ ] Confirmar que o instalador não quebrou nenhuma instalação existente.

Cuidado conhecido: o `irm ... | iex` é o comando curto que as pessoas vão copiar, mas o README
traz a forma mais robusta (download para arquivo temporário + execução), que evita problemas de
encoding/BOM em PowerShell 5.1. Deixe as duas visíveis e diga qual usar se a primeira falhar.

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

`dsh-h-v1`: **1 star, 0 forks, 125 tags, 0 releases publicadas.** É um projeto novo, buscando os
primeiros usuários. Assuma isso nos posts — "acabei de abrir" é mais convincente do que fingir
tração que não existe, e abre espaço para pedir ajuda de verdade.

## Verificação de fatos no dia do post

Antes de publicar qualquer coisa, confirme:

- [ ] o número de stars do DeepSeek Harness que você for citar (é volátil);
- [ ] quais tiers gratuitos ainda existem nos provedores citados;
- [ ] o estado do repositório (stars/forks) se você for mencionar;
- [ ] a contagem de frases da tradução pt-BR, se for citar;
- [ ] que o comando de instalação daquele post ainda funciona, colando ele de verdade em um
      terminal.

Um número errado em um post público custa mais credibilidade do que qualquer ganho de entusiasmo.

> **Notas de publicação**: este arquivo é o playbook interno, não um post — não publique ele em lugar
> nenhum. Ele fica no repositório justamente para que a ordem, os intervalos e a régua de métricas
> não dependam de memória. Cada arquivo de post traz, no fim, a sua própria nota de publicação com
> horário, flair/regra da comunidade e o que evitar naquele canal; leia a nota **antes** de publicar,
> não depois. Quando um post gerar aprendizado que mude este playbook (um horário que não funcionou,
> uma comunidade que recusou autopromoção), atualize o arquivo do canal e este índice no mesmo
> commit — o material envelhece rápido e um playbook desatualizado é pior do que nenhum.
