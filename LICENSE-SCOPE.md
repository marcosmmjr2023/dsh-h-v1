# Escopo da licença (License scope)

Este arquivo complementa o [LICENSE](LICENSE) (MIT) e o
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Ele existe **fora** do arquivo
`LICENSE` de propósito: o GitHub detecta automaticamente a licença a partir de um
texto padrão limpo, e um preâmbulo antes do texto MIT fazia o repositório aparecer
como "NOASSERTION" em vez de "MIT".

## O que a licença MIT deste repositório cobre

Os arquivos originais deste repositório criados pelo mantenedor:

- instaladores (`installer/`);
- scripts de sincronização, release e rollback (`tools/`);
- documentação e site (`docs/`, `site/`);
- o conteúdo customizado em `overlay/` criado por ele (`settings.yaml`, presets e
  plugins como `smart-router-plugin.js`, `layout-panel-plugin.js`,
  `model-visibility-plugin.js`, `freellmapi-shortcut-plugin.js`,
  `openrouter-enhanced-plugin.js`, `router-settings-helper.js`,
  `regenerate-openrouter-data.py`, entre outros);
- a camada de tradução pt-BR em `core-i18n-pt/` (dicionários, ferramentas e
  patches de tradução).

## O que NÃO é coberto por esta licença

Partes de terceiros mantêm suas próprias licenças:

- **Core do DeepSeek Harness** (`@deepseek-ai/dsh`): MIT © 2026 DeepSeek. **Não é
  redistribuído** neste repositório — é instalado à parte, via npm. Texto da
  licença em <https://github.com/deepseek-ai/deepseek-harness>.
- **Assets de editor e outros componentes de terceiros** em
  `overlay/editor-assets/`: MIT — veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Não afiliação

FreeDSH é um projeto **não oficial**, mantido pela comunidade. Não é afiliado,
patrocinado ou endossado pela DeepSeek. "DeepSeek" e "DeepSeek Harness" são marcas
de seus respectivos titulares e são usados aqui apenas para descrever de forma
factual a compatibilidade e a finalidade deste projeto.
