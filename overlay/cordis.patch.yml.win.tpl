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
