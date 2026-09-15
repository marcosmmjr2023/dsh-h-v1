# X / Twitter — thread

Duas versões da mesma thread, uma em português e uma em inglês. Publique **uma delas por vez** e
espaçe as duas (ou publique só a do idioma da sua audiência principal).

## Versão em português (5 posts)

**1/5**

Uso o DeepSeek Harness todo dia e cansei de três coisas:

interface em inglês, instalação sofrida no Windows, e tudo preso a um provedor de modelo.

Escrevi uma camada open source para resolver isso. Chama FreeDSH. 🧵

**2/5**

Não é fork. É um overlay: um conjunto de plugins do próprio harness, mais instalador e ferramentas.

O que ele faz de mais útil é rotear. Tenta primeiro os provedores gratuitos que você configurou —
FreeLLMAPI local, OpenRouter `:free`, OpenCode — e só depois os pagos. Se um cai, tem fallback
automático para o próximo.

**3/5**

No Windows é um comando só. A linha é longa, então copie da página do projeto — é lá que o comando
fica sempre atualizado:

https://marcosmmjr2023.github.io/dsh-h-v1/

Baixa o core, aplica o overlay, traduz e cria os atalhos. Testado em PowerShell 5.1 e 7.x.

E se você já tem o harness instalado, dá para instalar só os plugins — sem instalador (bundle do DSH).

**4/5**

A parte que eu queria ter feito antes: atualização segura do core.

Em vez de sobrescrever o que funciona, ele testa a versão nova numa instância isolada. Se der
problema, rollback de um clique. Auto-update a cada 30 minutos.

Tradução pt-BR do núcleo: 1078 frases.

**5/5**

Sendo honesto: o projeto é novo (1 star, 0 forks, 1 release: a v0.2.125) e é NÃO oficial, sem vínculo
com a DeepSeek. O código é MIT.

O que eu preciso não é estrela, é gente que instale e diga o que quebrou.

https://github.com/marcosmmjr2023/dsh-h-v1

## Versão em inglês (5 posts)

**1/5**

I use DeepSeek Harness daily and got tired of three things:

UI in English, painful Windows install, and my whole workflow pinned to one model provider.

So I wrote an open-source layer for it. It's called FreeDSH. 🧵

**2/5**

It's not a fork. It's an overlay — a set of Harness plugins plus an installer and tooling.

The useful part is routing: it tries the free providers you configured first (local FreeLLMAPI,
OpenRouter `:free`, OpenCode) and only then paid ones. If one goes down, it falls back
automatically.

**3/5**

On Windows it's one command. The line is long, so copy it from the project page — that's where it
stays current:

https://marcosmmjr2023.github.io/dsh-h-v1/

It pulls the core, applies the overlay, applies the translation and creates shortcuts. Tested on
PowerShell 5.1 and 7.x.

And if you already run Harness, you can install just the plugins — no installer (DSH bundle).

**4/5**

My favorite part: safe core updates.

Instead of overwriting a working install, it tests the new core in an isolated parallel instance.
One-click rollback if it breaks. Auto-update syncs every 30 minutes.

Also: full pt-BR localization of the core (1078 strings).

**5/5**

Being honest: this is new (1 star, 0 forks, 1 release: v0.2.125) and it's UNOFFICIAL — no affiliation
with DeepSeek. The code is MIT.

I'm not asking for stars. I'm asking for people who install it and tell me what broke.

https://github.com/marcosmmjr2023/dsh-h-v1

## Mídia sugerida

Um GIF ou vídeo curto de **20 a 30 segundos**, gravado como screencast simples, sem trilha e sem
corte seco. Roteiro, na ordem:

1. **0–5s** — terminal: cola o comando de instalação e roda até o instalador terminar. Deixe a
   velocidade real ou 2x; não acelere ao ponto de ficar ilegível.
2. **5–12s** — abre a GUI com `dsh up` e mostra o painel: os badges laterais (⚡ Roteador, ☑
   Modelos), o modelo em uso com o custo visível, a coluna de últimos arquivos e o status do core.
3. **12–20s** — a parte que convence: derrube um provedor (ou desligue o gateway 3002) e faça uma
   tarefa cair para a próxima rota. O valor do roteamento se explica em um único corte desses.
4. **20–26s** — mostra a atualização segura: a instância paralela testando a versão nova antes de
   trocar a que funciona.
5. **26–30s** — volta para o badge com o modelo em uso.

Coloque esse GIF no post 1/5 (é o que faz alguém parar de rolar) e use um frame dele como imagem do
post 3/5. Adicione **texto alternativo** descritivo em cada imagem — quem usa leitor de tela e quem
está com a imagem bloqueada agradece, e melhora o alcance.

Se for gravar vídeo em vez de GIF, prefira MP4 curto e legendado (muita gente assiste sem som).

> **Notas de publicação**: poste a thread de manhã, entre 9h e 11h no horário de Brasília — o
> primeiro post define tudo, então não publique junto com outra coisa sua no mesmo dia. **Não faça
> cross-post do mesmo texto em pt e en no mesmo dia**: escolha o idioma da sua audiência e guarde o
> outro para uma segunda onda, dias depois, mudando o gancho do post 1. Cada post precisa funcionar
> sozinho (quem vê só o 3/5 tem que entender), e o link do repo vai **só no último post** — thread com
> link no primeiro perde alcance. Fixe a thread no perfil por alguns dias. Use no máximo um hashtag
> por post, ou nenhum; em conteúdo técnico hashtag atrapalha mais do que ajuda. Responda as respostas
> na primeira hora. Não peça RT nem voto em concurso. Se alguém perguntar de custo, responda com o
> que é verdade — "projetado para usar modelos gratuitos antes dos pagos" — e nunca com percentual de
> economia que você não mediu.
