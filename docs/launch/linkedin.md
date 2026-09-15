# LinkedIn (pt-BR)

## Corpo

Nos últimos meses eu passei por uma situação que acho bem comum para quem usa ferramentas de IA
para programar: a ferramenta funcionava, mas o meu ambiente não.

Três problemas, na ordem em que me incomodaram.

O primeiro foi o idioma. A ferramenta era boa, mas tudo — interface, mensagens de erro, documentação
— estava em inglês. Isso cansa no dia a dia, e cansa mais ainda quando é uma mensagem de erro que
você precisa entender rápido.

O segundo foi o Windows. Quase todo projeto desse tipo chega com instruções pensadas para Linux e
Mac. No Windows, a instalação dependia de uma sequência de passos que eu refazia de cabeça e que
quebrava a cada atualização.

O terceiro, e o mais caro, foi a dependência de um provedor de modelo só. Quando a cota acabava, eu
só descobria no meio de uma tarefa. A escolha era pagar na hora ou parar o que estava fazendo.

Resolvi isso do jeito que quem programa resolve: escrevendo. Abri o código como **FreeDSH**.

O FreeDSH é uma camada de distribuição **não oficial** sobre o DeepSeek Harness, um projeto de
código aberto mantido pela comunidade. Não é um fork: é um conjunto de plugins do próprio harness,
mais instalador, tradutor e ferramentas de manutenção.

O que ele faz, sem promessa que eu não possa cumprir:

- **Roteamento free-first.** Ele tenta primeiro os provedores gratuitos que a pessoa configurou e só
  depois os pagos, com fallback automático quando um serviço cai. Em vez de prometer economia, eu
  digo o que é verdade: ele foi projetado para usar modelos gratuitos antes dos pagos.
- **Tradução do núcleo para português**, com 1078 frases traduzidas, incluindo as telas de conversa,
  de modelos, de arquivos e os visualizadores de HTML, imagem e PDF.
- **Instalação de um comando só no Windows**, em menos de um minuto, com suporte a Linux também. Para
  quem já tem o harness rodando, dá para instalar só os plugins, sem instalador nenhum (é o "bundle"
  do DSH: `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1`).
- **Atualização segura.** Em vez de sobrescrever a instalação que funciona, ele testa a versão nova
  em uma instância isolada, com snapshot e rollback de um clique.

Duas coisas que eu não quero esconder. A primeira é que o projeto é novo: o repositório está com
1 star, 0 forks e **uma release publicada** (a `v0.2.125`, com o ZIP e o `SHA256SUMS.txt`). A
descoberta real ainda é praticamente nenhuma — 90 visitas de **11 pessoas únicas** nos últimos 14
dias —, e é justamente isso que este post tenta mudar. A segunda é que a soma disso não é uma promessa
de IA gratuita para sempre — os planos gratuitos dos provedores mudam o tempo todo. O que o FreeDSH
faz é organizar e rotear as chaves que a própria pessoa configura, de forma que a queda de um provedor
não pare o trabalho.

O código está aberto sob licença MIT (o escopo — o que a licença cobre e o que é de terceiros — está
documentado no repositório) e o projeto é não oficial, sem vínculo com a DeepSeek.

Eu não estou buscando holofote. Estou buscando **as primeiras pessoas que instalem e contem o que
quebrou**. Se você usa IA para programar no Windows e já perdeu tempo com instalação ou com
interface em inglês, seu relato vale muito mais para mim do que uma curtida.

Se quiser testar: https://github.com/marcosmmjr2023/dsh-h-v1 — a página do projeto, com o comando de
instalação, está em https://marcosmmjr2023.github.io/dsh-h-v1/

E se preferir só conversar sobre o problema — roteamento entre modelos, custo de IA no dia a dia,
tradução de ferramentas de desenvolvimento — me chama. Essa parte é a que mais me interessa.

> **Notas de publicação**: publique de terça a quinta, entre 8h e 10h (BRT), quando o feed
> profissional está mais ativo. Evite segunda (feed cheio de conteúdo corporativo) e sexta à tarde
> (alcance despenca). O algoritmo do LinkedIn **reduz o alcance de posts com link externo**: coloque
> o link do repositório no **primeiro comentário** e ajuste a última linha do texto para "o link está
> no primeiro comentário". Use no máximo 3 a 5 hashtags, no fim, discretas (`#OpenSource` `#IA`
> `#DesenvolvimentoDeSoftware` `#Windows`); texto limpo performa melhor que texto cheio de hashtag.
> Nunca use emoji a cada parágrafo — o tom aqui é profissional e o texto acima já foi escrito para
> isso. Marque a tag "projeto não oficial" com clareza também nos comentários, porque a primeira
> pergunta costuma ser se existe vínculo com a DeepSeek. Responda cada comentário com uma pergunta
> técnica específica de volta ("qual versão do PowerShell você tem aí?") — isso mantém o thread vivo
> e é onde aparecem os primeiros testadores.
