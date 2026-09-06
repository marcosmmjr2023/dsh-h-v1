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
