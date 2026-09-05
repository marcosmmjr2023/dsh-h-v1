# Avisos de Terceiros / Third-Party Notices

Este repositório redistribui ou referencia componentes de terceiros, cada um
sob sua própria licença. Os arquivos **originais** deste repositório são
cobertos pela licença MIT na raiz (arquivo `LICENSE`).

---

## DeepSeek Harness (`@deepseek-ai/dsh`) — referenciado, não redistribuído

- Projeto: [github.com/deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
  · [npm: @deepseek-ai/dsh](https://www.npmjs.com/package/@deepseek-ai/dsh)
- Licença: **MIT**, Copyright (c) 2026 DeepSeek
- Papel neste repo: o core do harness **não é redistribuído aqui** — cada
  máquina o instala via npm (`npm install -g @deepseek-ai/dsh`). A versão
  "conhecida-boa" é pinada em `manifest.json`. Os perfis em `overlay/profiles/`
  declaram pacotes `@deepseek-ai/*` como dependências instaladas em tempo de
  execução (licenças próprias no registro npm).

## CodeMirror 5 (`overlay/editor-assets/`)

- Componentes: `codemirror.min.js` (v5.65.16), addons (`active-line`,
  `closebrackets`, `continuelist`, `matchbrackets`) e modos de linguagem
  (`clike`, `css`, `go`, `htmlmixed`, `javascript`, `json`, `markdown`,
  `php`, `python`, `ruby`, `rust`, `shell`, `sql`, `xml`, `yaml`)
- Projeto: [codemirror.net](https://codemirror.net) ·
  [github.com/codemirror/codemirror5](https://github.com/codemirror/codemirror5)
- Licença: **MIT**, Copyright (C) 2017 by Marijn Haverbeke
  `<marijnh@gmail.com>` and others

## CodeMirror temas (`theme-dracula.css`, `theme-monokai.css`)

- Componentes: temas Dracula e Monokai distribuídos com o CodeMirror 5
- Licença: **MIT**, de acordo com a licença do CodeMirror 5 (acima)

## marked (`overlay/editor-assets/marked.min.js`)

- Componente: `marked` v12.0.2 — parser de Markdown
- Projeto: [github.com/markedjs/marked](https://github.com/markedjs/marked)
- Licença: **MIT**, Copyright (c) 2011-2024, Christopher Jeffrey
  (banner de copyright presente no próprio arquivo)

## Dados de modelos OpenRouter (`overlay/openrouter-enhanced-data.json`)

- Componente: metadados factuais de modelos (identificadores, preços,
  contextos) compilados a partir da API pública do OpenRouter
- Projeto: [openrouter.ai](https://openrouter.ai)
- Natureza: dados factuais de catálogo; nenhum código de terceiros

---

## Texto da Licença MIT (aplica-se aos componentes MIT listados acima)

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
