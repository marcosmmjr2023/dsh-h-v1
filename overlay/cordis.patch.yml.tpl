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