# Changelog — camada personalizada do DeepSeek Harness (dsh-h-v1)

Gerado e versionado automaticamente pelo auto-push/release.
Ordem cronológica — a versão mais recente fica no FIM do arquivo.


## [v0.2.1] — 2026-09-06 23:12 (máquina v2202608297065493408)
Release manual/estrutural — 13 commit(s) desde v0.2.0.
  - a150136 fix(badge): exibe versão sem 'v' duplicado (vv→v) + tools/release.sh p/ versionar mudanças estruturais
  - 3728d20 feat(rollback): voltar de versão pelo PAINEL (badge ↩) quando uma atualização quebrar
  - 06fbd71 feat(sync): via de mão dupla em TODAS as máquinas — auto-push documentado com versão+CHANGELOG
  - 73b220d feat(sync): auto-push rotineiro publica a camada local no GitHub (máquina mestra)
  - 0881035 feat: chave ON/OFF da auto-atualização no painel (badge de versão)
  - 1e4b48b fix(version-badge): espera o webServer ficar disponível (retry como o LayoutPanel)
  - 0bf592a feat: badge de versão no painel + carimbo de versão + auto-update pronto
  - 234a042 fix(ci): guard ignora fixtures intencionais do tools/test.sh na varredura por arquivo
  - 6d2de51 fix(ci): shellcheck com severidade warning+ (infos SC2015/SC2317 do test.sh não falham)
  - 98d8c80 Polimento: template cordis, remoção de duplicata, testes funcionais, CI + PS syntax, manual EN
  - aba6efb fix(ci): SC2115 — protege rm -rf com ${SNAP_ROOT:?}
  - 4f29847 fix(ci): corrige shellcheck SC2045/SC2012 nos loops de snapshot/rollback
  - e8312d6 Migração PC1/PC2: layout-panel v1.1 + badge FreeLLMAPI atualizado

## [v0.2.2] — 2026-09-06 23:15 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.1.
  - 876d6a2 docs(i18n): paridade PT/EN dos manuais — SYNC.en.md atualizado (auto-sync/auto-push/release/rollback GUI) + guia Windows EN (docs/WINDOWS.md)

## [v0.2.3] — 2026-09-06 23:24 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.2.
  - b257f96 feat(i18n-pt): projeto pt-BR do núcleo — scaffold core-i18n-pt + patch 01 (liberar idioma 'pt')

## [v0.2.4] — 2026-09-06 23:30 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.3.
  - c72d1e6 feat(i18n-pt): dicionários pt-BR iniciais via gerador — common/settings.locale + settings General

## [v0.2.5] — 2026-09-06 23:33 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.4.
  - 56df237 feat(i18n-pt): +15 pacotes de UI em pt-BR (patches 04–18) — total 18 patches

## [v0.2.6] — 2026-09-06 23:40 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.5.
  - e444c3b feat(i18n-pt): dicionários pt-BR em TODOS os 26 arquivos de UI do núcleo (patches 19–27)

## [v0.2.7] — 2026-09-06 23:49 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.6.
  - ecbfcc2 docs(i18n-pt): validação de boot en/zh/pt do núcleo patcheado (instância de teste)

## [v0.2.8] — 2026-09-06 23:52 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.7.
  - c3ec2f3 feat(i18n-pt): aplicação nos núcleos reais (sudo) + verify-pt (paridade pt/en) verde

## [v0.2.9] — 2026-09-07 04:32 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.8.
  - 6e22685 feat(core-chip): chip do núcleo no painel — versão instalada + checagem automática de nova versão + atualização/rollback MANUAL

## [v0.2.10] — 2026-09-07 04:40 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.9.
  - f746770 docs(ui): painel do núcleo deixa claro que dados do usuário nunca são tocados (sessões/chaves/.dsh) e que há rollback (↩) se falhar

## [v0.2.11] — 2026-09-07 05:24 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.10.
  - 6f7e8da feat(core-safe): arquitetura segura de atualização do core — backup completo, preview isolado e aplicação em 2 passos

## [v0.2.12] — 2026-09-07 05:32 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.11.
  - 4539b66 feat(core-env): ambientes paralelos (A/B) para testar core novo sem tocar o sistema atual

## [v0.2.13] — 2026-09-07 05:36 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.12.
  - ddde144 feat(core-env): gera atalho no menu X11 (.desktop + wrapper launch-gui.sh) por ambiente

## [v0.2.14] — 2026-09-07 05:37 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.13.
  - 55f0ea8 fix(core-env): remove também apaga o atalho .desktop do menu X11

## [v0.2.15] — 2026-09-07 05:39 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.14.
  - 29e7c46 fix(core-env): launcher/create abrem a URL real do boot (inclui ?token quando o core novo exigir auth)

## [v0.2.16] — 2026-09-07 05:40 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.15.
  - cb44f8b fix(core-env): launcher gerado por template com placeholders — URL (?token) calculada a cada abertura; sem unbound var em set -u

## [v0.2.17] — 2026-09-07 12:40 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.16.
  - d77ae90 feat(pt-ride): pt-BR anda junto com QUALQUER core novo (sem depender de patches com contexto)

## [v0.2.18] — 2026-09-07 12:42 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.17.
  - fb30bb1 feat(i18n-pt): +296 frases do core 0.1.2 (total 920) — paridade pt/en OK em 28 arquivos no ambiente rc012

## [v0.2.19] — 2026-09-07 12:51 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.18.
  - ebed24f fix(pt-ride/core-env): nunca quebrar a UI ao aplicar pt em core novo

## [v0.2.20] — 2026-09-07 12:59 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.19.
  - 7b29af9 feat(core-safe): testes de sanidade na 1ª subida + FreeLLMAPI com CORS loopback

## [v0.2.21] — 2026-09-07 13:07 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.20.
  - 1655e94 fix(badge-core): chip do core reconhece pt aplicado por pt-ride em ambientes paralelos (DSH_ENV_NAME)

## [v0.2.22] — 2026-09-07 13:53 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.21.
  - 61c8eeb fix(rollback): reinicia a GUI automaticamente após restaurar + plugins estáveis no overlay

## [v0.2.23] — 2026-09-07 14:00 (máquina v2202608297065493408)
Publicação automática — última sincronização desta máquina.
- Arquivos alterados (5):
  - attachments/v1/objects/78/78a3d129cfdc38fd5a060177558464652744d75323295632f0d5c36ccd57e478
  - attachments/v1/objects/9c/9ceb9c3eec354a2a3dfe9ca80867632158fd86121774c84c59f66e10e0fcc53d
  - attachments/v1/request-images/42/428a7a7a42ab9ec0796a0e8fa8ee0c6a3a87a89840acf54fabc4bb7d64081d68
  - attachments/v1/request-images/97/97adc7ec5173d425de2bcc7730a7d6f687cbd2d441072de0e43354105345c470
  - llm-deepseek/files-v3.json

## [v0.2.24] — 2026-09-07 14:04 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.23.
  - de497f5 docs(map): SERVER-MAP PT/EN — organização do servidor e regras de uso

## [v0.2.25] — 2026-09-07 14:05 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.24.
  - a17fc66 docs(map): cron auto-update confirmado ativo; pm2 save

## [v0.2.26] — 2026-09-07 14:09 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.25.
  - c484e72 refactor(paths): remove symlink ~/dsh-v2 — caminho único ~/projects/dsh/dsh-h-v1

## [v0.2.27] — 2026-09-07 14:14 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.26.
  - 1b807ff docs(map): só a GUI principal (dsh-web-v2) + FreeLLMAPI

## [v0.2.28] — 2026-09-07 14:18 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.27.
  - 11229e8 feat(core-chip): Atualizar cria instância isolada (2ª versão) em vez de instalar no core vivo

## [v0.2.29] — 2026-09-07 14:35 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.28.
  - eebdce2 feat(core-env): alocador de portas por faixa com verificação de conflitos

## [v0.2.30] — 2026-09-07 14:41 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.29.
  - 22e5573 feat(freellmapi): gateway FreeLLMAPI POR INSTÂNCIA (limpo, porta+banco próprios)

## [v0.2.31] — 2026-09-07 14:42 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.30.
  - a96f42c fix(core-env): ports mostra harness + gateway de cada instância

## [v0.2.32] — 2026-09-07 14:44 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.31.
  - 7f8eba3 fix(core-env): remove limpa gateway flm-<nome> e perfil Chrome da instância

## [v0.2.33] — 2026-09-07 14:48 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.32.
  - 8321ef7 fix(freellmapi): reinicia a instância após provisionar o gateway próprio

## [v0.2.34] — 2026-09-07 14:54 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.33.
  - b11bb5f fix(freellmapi): gateway dinâmico por instância nos plugins (shared, via DSH_ENV_NAME)

## [v0.2.35] — 2026-09-07 15:02 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.34.
  - 1da0db2 fix(badge): chip detecta pt em instâncias (DSH_ENV_NAME/DSH_HOME) — falso 'sem pt'

## [v0.2.36] — 2026-09-07 15:11 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.35.
  - 985c6d4 feat(import): botão na instância nova p/ importar histórico/configs da instância anterior

## [v0.2.37] — 2026-09-07 15:21 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.36.
  - ac8b9b9 fix(badge-core): erro de sintaxe no script do chip (newline literal em string do botão import) sumia com o badge

## [v0.2.38] — 2026-09-07 15:31 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.37.
  - 700bf3c feat(panel): botão ✕ para fechar os painéis do núcleo e do rollback (sem precisar clicar de novo no badge)

## [v0.2.39] — 2026-09-07 15:34 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.38.
  - 25f31b6 feat(ui): pills Roteador e Modelos abrem em MODAL interno (iframe) em vez de sair do app

## [v0.2.40] — 2026-09-07 15:36 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.39.
  - c2466b5 fix(ci): padroes duplicados no case do rollback.sh quebravam o ShellCheck (SC2221/2222)

## [v0.2.41] — 2026-09-07 15:44 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.40.
  - 388165b feat(ui): indicador de PROGRESSO na criação de instância + botão desinstalar no menu lateral

## [v0.2.42] — 2026-09-07 15:50 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.41.
  - 85f249d fix(layout): botão desinstalar usa nome da instância INJETADO pelo servidor (determinístico)

## [v0.2.43] — 2026-09-07 15:55 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.42.
  - 8564ec2 fix(uninstall): botão de desinstalar garantido em instância — linha no menu lateral + FAB vermelho

## [v0.2.44] — 2026-09-07 15:59 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.43.
  - 5f003c9 fix(uninstall): passa res no json (erro 000/TypeError) + FAB pequeno ao lado do settings

## [v0.2.45] — 2026-09-07 16:00 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.44.
  - 8fe073d fix(uninstall): remove reordenado — limpa gateway/atalho/pasta/perfil PRIMEIRO e apaga a instância por último

## [v0.2.46] — 2026-09-07 16:04 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.45.
  - 0698fcd fix(uninstall): janela fecha sozinha (pkill perfil Chrome + window.close) e FAB fora do settings

## [v0.2.47] — 2026-09-07 16:24 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.46.
  - 5b5645a feat(uninstall): barra fina fixa no RODAPÉ do menu lateral — pequena, com o nome da instância

## [v0.2.48] — 2026-09-07 16:32 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.47.
  - 69400f8 feat(win): fluxo Windows do ambiente paralelo (core-env/core-update/apply em PowerShell) + roteamento por SO no painel

## [v0.2.49] — 2026-09-07 22:08 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.48.
  - cc191f1 fix(win): core-env.ps1 usa herança de env (Start-Process -Environment só existe no PS7) — compatível com PowerShell 5.1

## [v0.2.50] — 2026-09-07 22:12 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.49.
  - b476f58 feat(win-install): instalador de 1 linha + comando 'dsh' (estilo apt) para Windows

## [v0.2.51] — 2026-09-07 22:21 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.50.
  - c6f931f fix(win): .ps1 em ASCII puro (sem BOM o PowerShell 5.1 quebrava com acentos/emoji)

## [v0.2.52] — 2026-09-07 22:28 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.51.
  - e03eb12 fix(win): pt-ride multiplataforma (fileURLToPath), GUI com --profile web, atalhos Desktop/Menu Iniciar

## [v0.2.53] — 2026-09-07 22:37 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.52.
  - 7bbfa8e feat(win): launcher GUI robusto (run-gui.ps1) + instalador abre GUI automaticamente

## [v0.2.54] — 2026-09-07 22:40 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.53.
  - 81820a8 fix(win): dsh up resolvia repo errado (faltava dsh-h-v1) — Split-Path simples

## [v0.2.55] — 2026-09-07 22:45 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.54.
  - e1af6ff fix(pt-ride): dup-guard no locale.register — duplicata de locale mantém o primeiro (sem throw)

## [v0.2.56] — 2026-09-07 22:50 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.55.
  - 50f23a3 feat(win): sincroniza OVERLAY (nossa camada) para %USERPROFILE%\.dsh

## [v0.2.57] — 2026-09-07 22:59 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.56.
  - 2517cbf feat(win): gera cordis.patch.yml no home (ativa nossos plugins)

## [v0.2.58] — 2026-09-07 23:05 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.57.
  - 074475d feat(win): clean-windows.ps1 (desinstalacao total) + instalador grava log e verifica overlay

## [v0.2.59] — 2026-09-07 23:24 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.58.
  - 2875f0f fix(win): cordis.patch.yml usa file:/// p/ plugins (loader ESM do Windows exige URL)

## [v0.2.60] — 2026-09-07 23:25 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.59.
  - 447a951 fix(win): dsh-cli usa file:/// no cordis.patch.yml (plugins carregam no Windows)

## [v0.2.61] — 2026-09-07 23:31 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.60.
  - d79b885 fix(win): NODE_PATH p/ modulos do core (plugins resolvem schemastery/dsh-settings)

## [v0.2.62] — 2026-09-07 23:34 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.61.
  - 64e32c9 fix(win): plugins descobrem o caminho do core via require.main (sem /opt fixo)

## [v0.2.63] — 2026-09-07 23:38 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.62.
  - f649f93 fix(win): plugins calculam lib do core via 'npm root -g' (require.main era null no loader)

## [v0.2.64] — 2026-09-07 23:38 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.63.
  - 63149b2 fix(win): bloco CANDIDATE_LIBS reescrito (npm root -g + require.main) sem quebrar sintaxe

## [v0.2.65] — 2026-09-07 23:43 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.64.
  - 96177c1 fix(win): execSync npm root -g com shell:true (resolve .cmd no Windows)

## [v0.2.66] — 2026-09-07 23:49 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.65.
  - 4728ba4 fix(win): run-gui define DSH_CLI_LIB (lib do core) p/ plugins resolverem schemastery/dsh-settings

## [v0.2.67] — 2026-09-07 23:54 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.66.
  - d5b3ca2 fix(win): fallback absoluto p/ schemastery/dsh-settings dentro do grafo do core

## [v0.2.68] — 2026-09-08 04:01 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.67.
  - a4f5699 feat(win): cordis.patch.yml gerado no Windows SEM smart-router/openrouter/model-visibility

## [v0.2.69] — 2026-09-08 04:01 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.68.
  - 45d13b5 fix(win): dsh-cli com Remove-FailingPlugins no sync-overlay (funcao + uso)

## [v0.2.70] — 2026-09-08 04:07 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.69.
  - 74ce43d fix(win): cordis.patch.yml.win.tpl valido (remove 3 plugins por linhas) + geradores limpos

## [v0.2.71] — 2026-09-08 04:17 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.70.
  - deee339 feat(win): icone da baleia + janela de app (Edge/Chrome --app) + atalhos Desktop/Menu Iniciar com icone

## [v0.2.72] — 2026-09-08 04:23 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.71.
  - 17087d1 feat(win): FreeLLMAPI local (dsh flm-setup) + icone oficial DeepSeek (baleia 225px)

## [v0.2.73] — 2026-09-08 04:23 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.72.
  - 4c20186 fix(win): flm-setup.ps1 em ASCII puro (PS5.1)

## [v0.2.74] — 2026-09-08 04:26 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.73.
  - 9108659 feat(win): pt-BR via --lang na janela de app + FreeLLMAPI integrado ao instalador

## [v0.2.75] — 2026-09-08 04:29 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.74.
  - e4e5379 feat(win): instalador INTERATIVO completo (dsh-setup.ps1)

## [v0.2.76] — 2026-09-08 04:33 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.75.
  - a18f35f feat(win): instalador - opcao limpa MANTENDO chaves/configuracoes (-CleanKeep)

## [v0.2.77] — 2026-09-08 04:46 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.76.
  - d194a6e docs(landing): README/README.pt-BR com finalidade + como instalar e rodar (Linux e Windows)

## [v0.2.78] — 2026-09-08 04:55 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.77.
  - a43b3c5 feat(win): GUI segue idioma do sistema (pt-BR/zh-CN/en-US, padrao en)

## [v0.2.79] — 2026-09-08 04:57 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.78.
  - 4784d51 feat(linux): instalador interativo dsh-setup.sh (equiv. Windows)

## [v0.2.80] — 2026-09-08 05:04 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.79.
  - e9edc9a docs(landing): landing em estilo marketing (diferenciais + instalacao 1 linha) EN/pt-BR

## [v0.2.81] — 2026-09-08 05:04 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.80.
  - 480bbfd docs: frase hero EN polida

## [v0.2.82] — 2026-09-08 05:06 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.81.
  - 4e43437 docs: README.md (EN) hero em INGLES (nao misturar com pt-BR) — landing 100% en no arquivo EN

## [v0.2.83] — 2026-09-08 05:55 (máquina v2202608297065493408)
Release manual/estrutural — 2 commit(s) desde v0.2.82.
  - 5db56a4 assets: demo visual FreeDSH (28s) — FreeLLMAPI, roteador, modelos e core seguro
  - 759a34b community: launch FreeDSH public identity and contributor experience

## [v0.2.84] — 2026-09-08 05:58 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.83.
  - 80e92d5 docs: exibe demo animada FreeDSH no topo dos READMEs EN e pt-BR

## [v0.2.85] — 2026-09-08 06:00 (máquina v2202608297065493408)
Publicação automática — última sincronização desta máquina.
- Arquivos alterados (3):
  - attachments/v1/objects/57/57b49f2b9b3e82629a93cd5238ff43e6e1b73675349ea71ca76bbfac9c2999fa
  - attachments/v1/objects/65/652c94c21bdcb212172b621a37b525311d1bb95219992d2f119127fbdee4a071
  - attachments/v1/objects/b2/b2a60f11f365429b99ea11f2ec9bf883982dad765b1c5e4d5089372a0e3155fd

## [v0.2.86] — 2026-09-08 11:51 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.85.
  - af85435 fix(windows): abre o arquivo correto no painel com multiplos roots/junctions

## [v0.2.87] — 2026-09-08 12:00 (máquina v2202608297065493408)
Publicação automática — última sincronização desta máquina.
- Arquivos alterados (1):
  - attachments/v1/objects/33/3329a130e083ad115424d638849880e0d203d69a7ac62fda1112b356ab165394

## [v0.2.88] — 2026-09-08 12:12 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.87.
  - a092973 fix(editor): conteudo visivel mesmo sem CodeMirror (Windows)

## [v0.2.89] — 2026-09-08 12:44 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.88.
  - 7c38069 fix(windows): copia editor-assets p/ CodeMirror ativar + preview md/html

## [v0.2.90] — 2026-09-09 00:42 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.89.
  - 70a7e33 feat(providers): Meta como provider padrao do sistema

## [v0.2.91] — 2026-09-09 02:37 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.90.
  - e96b8e9 feat(providers): Meta como provider padrao no catalogo do pi-ai

## [v0.2.92] — 2026-09-09 03:41 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.91.
  - 0dc8e6f feat(providers): modelos novos do OpenCode Go (assinatura)

## [v0.2.93] — 2026-09-09 04:00 (máquina v2202608297065493408)
Publicação automática — última sincronização desta máquina.
- Arquivos alterados (1):
  - model-visibility-plugin.js

## [v0.2.94] — 2026-09-09 04:34 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.93.
  - 5f77dba feat(router): cadeia visual em passos com motivo e disponibilidade

## [v0.2.95] — 2026-09-09 11:42 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.94.
  - 2c3927a fix(win): reativa Roteador, Modelos e badge de consumo no Windows

## [v0.2.96] — 2026-09-09 12:58 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.95.
  - eddc5e0 feat(update): botao manual no badge + auto-update Windows funcional

## [v0.2.97] — 2026-09-10 11:30 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.96.
  - b235747 fix(win): npm.cmd em vez de npm + one-liner com Bypass

## [v0.2.98] — 2026-09-10 11:43 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.97.
  - ef15f92 fix(win): transcricao opcional no install-windows.ps1

## [v0.2.99] — 2026-09-10 11:43 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.98.
  - ea77e53 fix(win): ascii puro em comentario do install-windows.ps1

## [v0.2.100] — 2026-09-10 12:00 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.99.
  - 01aa96d fix(win): instalador sai ao concluir + diagnostico de badges/versao

## [v0.2.101] — 2026-09-10 12:29 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.100.
  - 3cbc7e9 fix(win): sem [OK] falso + sem pagina morta quando a GUI nao sobe

## [v0.2.102] — 2026-09-10 12:38 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.101.
  - 20b1974 fix(win): detecta colisao do comando dsh com shim do core

## [v0.2.103] — 2026-09-10 12:48 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.102.
  - e3d03d7 fix(win): oferece RemoteSigned + reinstala core com koffi duplicado

## [v0.2.104] — 2026-09-11 03:41 (máquina v2202608297065493408)
Release manual/estrutural — 1 commit(s) desde v0.2.103.
  - fcb22ef fix(win): allow-scripts do npm 11 + validacao funcional do koffi

## [v0.2.105] — 2026-09-10 23:09 (máquina DESKTOP-3DND3TP)
Release manual/estrutural — 1 commit(s) desde v0.2.104.
  - de520e8 fix(plugins): carga assincrona do nucleo no apply() — badges Roteador/Modelos/modelo-em-uso voltam no Windows
