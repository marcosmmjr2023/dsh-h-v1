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
