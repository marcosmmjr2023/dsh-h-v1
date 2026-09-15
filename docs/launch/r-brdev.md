# r/brdev

## Título

```
Fiz uma ferramenta de IA em português e para Windows: DeepSeek Harness com instalador de 1 linha (open source, não oficial)
```

## Corpo

Sou brasileiro, uso o DeepSeek Harness para programar e cansei de duas coisas: lidar com interface e
documentação em inglês, e brigar para instalar no Windows. Toda ferramenta de IA que eu queria
testar vinha com um `curl | sh` pensado para Linux e um README que assumia que eu já sabia o que era
um "harness".

Então eu escrevi o instalador e o resto veio atrás. O projeto se chama **FreeDSH**.

**O que ele é:** uma camada de distribuição não oficial em cima do DeepSeek Harness (que é MIT, de
outra gente). Não é fork. É um overlay — um conjunto de plugins do próprio harness — mais
instalador e ferramentas.

**Em português, de verdade:** traduzi o núcleo, são 1078 frases. Não é só a tela inicial: entram os
dicionários da conversa, da tela de modelos, da sidebar de arquivos e dos visualizadores de
HTML/imagem/PDF. Tem `README.pt-BR.md` e a documentação de Windows em português também.

**No Windows, com um comando:**

```powershell
irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 | iex
```

O instalador é interativo, detecta instalação existente e baixa o core, aplica o overlay, traduz e
cria os atalhos. Tem suporte a Linux também, no mesmo espírito. Antes de subir, testei em PowerShell
5.1 **e** 7.x, porque é justamente aí que script de instalação costuma quebrar no Windows — corrigi
bugs reais de encoding/BOM e um travamento do `robocopy` quando existia arquivo em uso. Se você já
sofreu com instalador que funciona no PC do autor e não no seu, esse aqui foi escrito para o seu PC.

**E o que me fez continuar:** o custo. O FreeDSH faz roteamento *free-first* — ele tenta primeiro os
provedores gratuitos que você mesmo configura (FreeLLMAPI local na porta 3002, OpenRouter `:free`,
OpenCode) e só depois cai nos pagos. Se um provedor falha, tem fallback automático para o próximo.
Tem perfis de custo (`auto`, `eco`, `balanced`, `ultra`) para escolher o nível de modelo conforme a
tarefa. Só para deixar claro: ele não cria acesso grátis que não existe, ele organiza e roteia as
chaves que você já tem — e tiers gratuitos mudam toda hora, então nada de promessa de "grátis para
sempre".

**O ponto que mais me interessou como dev:** em vez de sobrescrever o core numa atualização, ele
sobe a versão nova numa instância isolada, você testa, e só então troca. Tem snapshot e rollback de
um clique. Também tem auto-update sincronizando com o GitHub a cada 30 minutos (Agendador de Tarefas
no Windows, cron no Linux). Já perdi configuração que funcionava por causa de update, e não queria
repetir isso.

**Agora a parte honesta:** o repo tem **1 star, 0 forks, 125 tags e 0 releases publicadas**. É novo.
Versão que funciona é a do `main`. Não tenho base de usuários nenhuma, é exatamente por isso que
estou postando aqui. E reforçando: **projeto não oficial, sem vínculo com a DeepSeek**.

**O que eu peço:** instale e me diga o que quebrou, de preferência com sistema, versão do harness e
os provedores que você configurou. Se a tradução tiver frase truncada ou esquisita, me manda o print
— 1078 frases é muita coisa para acertar de primeira. Se você usa Mac, saiba desde já que não testei.
E se discordar de alguma decisão de arquitetura, fala: é melhor descobrir agora.

Repositório: https://github.com/marcosmmjr2023/dsh-h-v1

Se você instalar e funcionar, comenta aqui o que usou. Se não funcionar, comenta ainda mais rápido.

> **Notas de publicação**: publique em dia útil à noite, entre 19h e 22h (BRT) — é quando o r/brdev
> está mais ativo, e o post pega carona no horário de quem chega do trabalho. Use a flair de projeto
> pessoal/open source que o sub oferecer no momento (leia as regras do dia: as flairs do r/brdev
> mudam). O título já está no formato curto e sem clickbait de propósito — título sensacionalista
> toma downvote imediato ali. Não reposte o mesmo texto em r/brdev e em r/ProgramacaoBrasil (ou
> similar) no mesmo dia: escolha um, espere, e reescreva o ângulo antes do segundo. Não peça estrela
> no post. Evite responder quem só reclamou sem testar; responda quem trouxe ambiente e erro, e
> traga a correção de volta no mesmo thread quando ela existir — isso é o que gera boa reputação no
> sub. Cuidado com o clássico "isso não é só um wrapper?": responda tecnicamente, listando o que é
> seu (roteador, instalador, tradução, updater) e o que é upstream.
