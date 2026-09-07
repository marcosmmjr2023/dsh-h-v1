# Atualizar o CORE do DeepSeek Harness com segurança (CORE-UPDATE)

O núcleo (L1, `@deepseek-ai/dsh`) é como um **kernel**: nunca é atualizado
sozinho — o sistema apenas **checa** se há versão nova e te avisa (chip `core`
no painel + `tools/check-core.sh`). Você atualiza **se quiser**, e se quebrar,
**volta** para a versão anterior que funcionava.

> Regra de ouro: atualize o core **por máquina**, nunca em todas de uma vez, e
> teste antes na instância que você usa. A nossa camada (overlay) é que
> sincroniza sozinha; o core é manual por desenho (plugins usam internals).

## Onde você vê o estado do core

- **Chip no painel** (abaixo do badge `v0.2.x` da camada): `core 0.1.1-rc.2 · nova
  0.1.2-rc.1` quando houver atualização. Clique para abrir o painel do núcleo:
  Instalado × Pinado × Disponível + estado do patch pt-BR + botões
  **Atualizar para X** e **↩ Voltar para a versão anterior**.
- **Terminal:** `tools/check-core.sh` (instalado × pinado × latest) e
  `core-i18n-pt/tools/core-update.sh --check|--history`.

## Antes de atualizar (uma vez por máquina) — permissão

O painel executa a atualização via `sudo` **sem senha**, restrito a um único
par de ferramentas (menor privilégio). Instale uma vez:

```bash
sudo core-i18n-pt/tools/install-sudoers.sh     # grava /etc/sudoers.d/dsh-core-tools
```

Sem isso, o painel mostra o comando para você rodar manualmente no terminal.

## Fluxo seguro de atualização (backup → preview → instalar → aplicar)

**Garantia nº 1 — backup completo antes de qualquer operação**
(`core-update.sh` chama `core-backup.sh` automaticamente): histórico de
SESSÕES (v1 e v2), settings.yaml, `.credentials.yaml` (700), plugins e
manifesto do core vão para `~/.dsh-core-backups/` (últimas 5; nunca sync).
Recupere com: `core-restore.sh list | latest`.

**Garantia nº 2 — preview isolado antes de instalar**
O `--install` roda (por padrão) um `--preview <versão>`: instala o candidato
num **prefixo isolado**, aplica os patches pt e sobe uma GUI de teste com os
plugins do overlay. Só passa se a GUI responder 200 (aceitando token, se o
core novo introduzir) **e** os plugins do overlay carregarem. Se falhar, nada
é alterado na máquina real e você vê qual plugin/erro precisa de adaptação.

1. **Cheque**: o chip avisa; ou `tools/check-core.sh`.
2. **Atualize pelo painel** (botão "Atualizar para …") — ou no terminal:
   ```bash
   sudo core-i18n-pt/tools/core-update.sh --install 0.1.2-rc.1
   ```
   Etapas por prefixo: backup → preview (falhou = aborta) → instala → grava a
   versão anterior no histórico → **reaplica os patches pt-BR** se aplicarem
   (senão avisa REGENERAR) — **sem reiniciar a GUI**.
3. **Aplique você**: clique em **"▶ Reiniciar agora"** no painel (ou
   `pm2 restart dsh-web-v2`) — só então o core novo entra em produção.
4. **Confira**: página 200, 3 línguas, `verify-pt` verde, seus plugins/badges.
5. **Se estabilizou**, atualize o `pinned` no `manifest.json` e publique com
   `tools/release.sh`.

## Se quebrar (rollback)

- **Pelo painel**: botão "↩ Voltar para …" (última versão que funcionava) →
  backup automático → instala a versão anterior → reaplica os patches — e só
  então você clica em "Reiniciar agora".
- **No terminal:**
  ```bash
  sudo core-i18n-pt/tools/core-update.sh --rollback <versão-anterior>
  # dados (sessões/config): sudo core-i18n-pt/tools/core-restore.sh latest
  # overlay/plugins: tools/rollback.sh list | --snapshot | <tag>
  ```
- Verifique o histórico de versões usadas:
  `sudo core-i18n-pt/tools/core-update.sh --live <config viva> --history`

## Regenerar os patches pt-BR quando o core mudar de contexto

Se, após instalar um core novo, os patches não aplicarem limpos
(`apply-pt-core.sh --check` falha), **não edite os .patch à mão**:

1. Espelhe o core novo num workspace temporário;
2. rode `core-i18n-pt/tools/build-pt-patches.mjs` de novo (as traduções em
   `en-phrases.json` são reaproveitadas; só o delta novo aparece em
   `dump-en-phrases --only-new` para traduzir);
3. gere os patches novos, valide com `verify-pt.mjs` e publique com release.

## O que NUNCA fazer

- Não atualizar o core automaticamente (mantenha `notify-and-manual`);
- não commitar arquivos do core/`node_modules`/cópias de instalação;
- não embutir senha do sudo em arquivos do repo (guard bloqueia);
- não "remendar" patches manualmente quando a regeneração resolve;
- não atualizar o core em todas as máquinas de uma vez.
