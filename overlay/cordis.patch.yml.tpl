# ═══════════════════════════════════════════════════════════════════
# TEMPLATE do patch global do DeepSeek Harness.
# NÃO edite o arquivo gerado (~/.dsh/cordis.patch.yml / %USERPROFILE%\.dsh\
# cordis.patch.yml): ele é REGENERADO pelo sync em cada máquina a partir
# deste template, substituindo __DSH_HOME__ pelo diretório de config vivo
# daquela máquina. Para mudar o patch, edite ESTE arquivo e publique
# (tools/sync-push.sh); o sync-pull de cada máquina reaplica.
# ═══════════════════════════════════════════════════════════════════
# Patch global do DeepSeek Harness (aplicado a todos os perfis)
# 1) Ativa o provider opencode-go (pi-ai) usando a chave OPENCODE_API_KEY.
- id: llm-pi-ai
  config:
    providers:
      opencode-go:
        apiKeyEnv: OPENCODE_API_KEY
# 2) Smart Model Router: roteamento automatico entre provedores LLM
#    (hook agent/request, por-agente via agent/created).
- insert:
    - id: smart-router
      name: '__DSH_HOME__/smart-router-plugin.js'
      config:
        enabled: true
# 3) OpenRouter Enhanced: grupos "OpenRouter Free" (modelos gratuitos) e
#    "OpenRouter Pro" (escolha de provedor por modelo, provider.order).
- insert:
    - id: openrouter-enhanced
      name: '__DSH_HOME__/openrouter-enhanced-plugin.js'
      config:
        enabled: true
# 4) Model Visibility: filtro do catalogo no seletor de modelos
#    (settings model-visibility + pagina /models com checkboxes).
- insert:
    - id: model-visibility
      name: '__DSH_HOME__/model-visibility-plugin.js'
      config:
        enabled: true
# 5) Compaction: usa um modelo de CONTEXTO GRANDE para resumir a conversa,
#    independente do modelo pequeno selecionado na sessao. Assim, ao trocar
#    para um modelo de 256k com uma sessao de ~300k, a compactacao automatica
#    ainda cabe (mimo-v2.5 tem 1M de contexto).
- id: compaction-basic
  config:
    summarizationProvider: opencode-go
    summarizationModel: mimo-v2.5
    maxTokens: 8192
# 6) FreeLLMAPI Shortcut: badge acima do seletor de modelo que abre o painel
#    do FreeLLMAPI (chaves dos provedores gratuitos) numa nova aba.
- insert:
    - id: freellmapi-shortcut
      name: '__DSH_HOME__/freellmapi-shortcut-plugin.js'
      config:
        enabled: true
# 7) Layout Panel: coluna direita que desloca a sessao para a esquerda e
#    abriga os badges (FreeLLMAPI, Roteador, Modelos...) + ultimos arquivos
#    modificados + status do gateway. API /api/layout-info.
- insert:
    - id: layout-panel
      name: '__DSH_HOME__/layout-panel-plugin.js'
      config:
        enabled: true
# 8) Version Badge: mostra a versão instalada do overlay e quando foi
#    atualizado (lê .dsh-version.json, gerado pelo sync em cada máquina).
- insert:
    - id: dsh-version-badge
      name: '__DSH_HOME__/version-badge-plugin.js'
      config:
        enabled: true
# 9) Catalogo do provider DeepSeek OFICIAL (plugin llm-deepseek, rota
#    'deepseek-official'). Desde 2026-09-10 o endpoint renomeou o modelo para
#    'deepseek-flash' = DeepSeek-V4.1-Flash, com visao nativa; 'deepseek-v4-flash'
#    e 'deepseek-v4-flash-vision-exp' viraram ALIAS TEMPORARIOS roteados para o
#    V4.1 (verificado: GET /models devolve so 'deepseek-flash' e 'deepseek-v4-pro').
#
#    O catalogo padrao do core so declara inputModalities ["text"] para o flash,
#    entao o harness recusava imagem ANTES de chegar ao endpoint — mesmo o modelo
#    sendo multimodal (testado: o endpoint le a imagem corretamente). Aqui o
#    catalogo e declarado explicitamente, com 'deepseek-flash' PRIMEIRO (vira o
#    padrao) e os alias mantidos para nao quebrar referencias existentes
#    (smart-router/model-visibility/sessao).
#
#    'models' SUBSTITUI a lista inteira (nao faz merge com DEFAULT_MODELS), por
#    isso os quatro modelos sao declarados aqui. imagePixelBudget/imageMaxBytes
#    podem ser omitidos: o adapter aplica 640000 px / 1 MiB por padrao em quem
#    declara "image". Modelo text-only NAO pode declarar limites de imagem.
- id: llm-deepseek
  config:
    models:
      - id: deepseek-flash
        name: DeepSeek-Flash (V4.1)
        contextWindow: 1000000
        inputModalities:
          - text
          - image
      - id: deepseek-v4-pro
        name: DeepSeek-V4-Pro
        contextWindow: 1000000
      - id: deepseek-v4-flash
        name: DeepSeek-V4-Flash (alias do V4.1)
        contextWindow: 1000000
        inputModalities:
          - text
          - image
      - id: deepseek-v4-flash-vision-exp
        name: DeepSeek-V4-Flash-Vision-Exp (alias do V4.1)
        contextWindow: 1000000
        inputModalities:
          - text
          - image
