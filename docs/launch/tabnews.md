# TabNews

## Título

FreeDSH: uma camada não oficial para usar o DeepSeek Harness em português e no Windows

## Corpo

Eu uso o DeepSeek Harness no dia a dia e vivia tropeçando nas mesmas três coisas. Resolvi
transformar a gambiarra em projeto e abrir o código.

**Os problemas eram estes.**

O harness é muito bom, mas é em inglês. Instalar no Windows era uma caça ao tesouro. E a parte que
mais me incomodava: tudo ficava preso a um provedor de modelo só — quando a cota gratuita acabava,
eu só descobria quando a tarefa falhava no meio, e aí era pagar ou parar.

**O que eu fiz.**

Escrevi o **FreeDSH**, uma camada de distribuição *não oficial* sobre o harness. Ele não é um fork
nem uma reimplementação: é um overlay, ou seja, um conjunto de plugins do próprio harness, mais
instalador e ferramentas.

- **Roteamento free-first com fallback automático.** O roteador tenta primeiro os provedores
  gratuitos configurados (FreeLLMAPI local, OpenRouter `:free`, OpenCode) e só depois cai nos pagos,
  se eles estiverem na sua lista. Se um provedor falha ou fica indisponível, ele passa para o
  próximo. Há perfis de custo: `auto`, `eco`, `balanced` e `ultra`.
- **Gateway local do FreeLLMAPI na porta 3002**, para concentrar as chaves dos modelos gratuitos em
  um lugar só.
- **Painel integrado ao harness**: badges laterais (⚡ Roteador, ☑ Modelos, modelo em uso com custo),
  coluna com os últimos arquivos e o status do core.
- **Tradução pt-BR do núcleo**: 1078 frases traduzidas, mais os dicionários das telas de conversa,
  modelos, sidebar de arquivos e visualizador de HTML/imagem/PDF. Tem também `README.pt-BR.md`.
- **Instalação de 1 minuto no Windows** por um comando só, e suporte a Linux também. O instalador
  baixa o core, aplica o overlay, traduz e cria os atalhos.
- **Atualização segura do core**: em vez de sobrescrever o que funciona, ele testa a versão nova em
  uma instância isolada. Se der problema, você volta com um clique por causa dos snapshots.
- **Auto-update**: sincroniza com o GitHub a cada 30 minutos (Agendador de Tarefas no Windows,
  cron no Linux).

No Windows, instala assim (este é o comando do README, e ele é longo de propósito: baixa o script
para um arquivo temporário com `-Headers` de no-cache, o que evita o cache do GitHub e os problemas
de encoding/BOM do PowerShell 5.1):

```powershell
powershell -ExecutionPolicy Bypass -Command "$f=\"$env:TEMP\dsh-setup.ps1\"; irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 -Headers @{'Cache-Control'='no-cache'} -OutFile $f; & $f"
```

Se você já tem o harness instalado e só quer os plugins, ele também é instalável como **bundle do
DSH**, sem instalador nenhum: `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1` (para
remover: `dsh plugin --profile web remove freedsh`).

**A parte que eu corrigi na marra**, porque doeu: bugs reais de encoding/BOM e um travamento do
`robocopy` quando havia arquivo em uso. Hoje o instalador é testado com PowerShell 5.1 e 7.x, que é
onde a maior parte dos scripts de instalação por aí simplesmente quebra.

**Sendo honesto sobre o estado do projeto.** Essa é a parte chata de postar: o repo está com 1
star, 0 forks, 127 tags e **1 release publicada** — a `v0.2.125`, com os arquivos `freedsh-v0.2.125.zip`
e `SHA256SUMS.txt` em https://github.com/marcosmmjr2023/dsh-h-v1/releases/tag/v0.2.125. Ou seja, é
novo de verdade (a maioria das 127 tags é âncora automática de rollback do meu próprio sync, não
lançamento). A versão que funciona é a do `main`, e o que eu mais preciso agora é gente que instale e
me diga onde travou. Não estou prometendo inferência grátis para sempre — tiers gratuitos mudam toda
hora. A proposta é **rotear para modelos gratuitos antes dos pagos** e degradar com elegância quando um
provedor cai, usando as chaves que a própria pessoa configura.

**Um aviso que importa:** o FreeDSH é um projeto não oficial, sem vínculo nenhum com a DeepSeek. O
código do FreeDSH é MIT (o escopo — o que a licença cobre e o que é de terceiros — está no
`LICENSE-SCOPE.md`). O DeepSeek Harness é MIT, de outra gente, e é instalado separadamente.

**O que eu queria de você**, se o tema te interessar:

1. Instalar e me contar o resultado — sistema, versão do harness, provedores configurados.
2. Dizer se a tradução pt-BR tem frase estranha. Eu traduzi 1078 frases e certamente tem coisa
   truncada em algum canto que eu não passei.
3. Relatar comportamento de fallback com data. "O provedor X falhou hoje e caiu para Y" é ouro
   para mim; "não funcionou" eu não consigo reproduzir.
4. Discordar da arquitetura. Ainda dá tempo de mudar coisa.

Repositório: https://github.com/marcosmmjr2023/dsh-h-v1
Página do projeto (com o comando de instalação atualizado e o download): https://marcosmmjr2023.github.io/dsh-h-v1/

Não precisa de estrela. Se você instalar e disser o que quebrou, já ajudou mais do que a estrela.

> **Notas de publicação**: publique em dia útil pela manhã, entre 9h e 11h (BRT) — de terça a
> quinta o TabNews tem mais gente ativa e o post fica no topo por mais tempo. O TabNews **penaliza
> post que é só um link**: o conteúdo precisa estar no corpo, e o link do repo fica depois do texto
> (como está aqui). Não use hashtag nem emoji no título; títulos com "lançamento" ou "finalmente"
> soam a marketing e são mal recebidos. Responda **todos** os comentários nas primeiras 2 horas —
> as primeiras respostas definem o tom das seguintes. Se aparecer crítica dura, responda com o dado
> que você tem e agradeça; o público do TabNews respeita quem assume o que não sabe, e castiga quem
> se defende. Não reposte nada aqui dizendo "relembrando" depois de uma semana.
