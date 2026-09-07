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
