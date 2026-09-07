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

## Fluxo seguro de atualização

1. **Cheque a novidade**: o chip avisa; ou `tools/check-core.sh`.
2. **Atualize pelo painel** (botão "Atualizar para …") — ou no terminal:
   ```bash
   sudo core-i18n-pt/tools/core-update.sh --install 0.1.2-rc.1
   ```
   A ferramenta, para **cada prefixo npm** do core (`/opt/dsh-tui/*` e o global):
   grava a versão anterior no histórico → instala a versão → **reaplica os
   patches pt-BR** se ainda aplicarem (senão avisa para REGENERAR, nunca
   remenda à força) → registra no histórico.
3. **A GUI reinicia** ao final (pelo painel) — confira: página 200, as 3
   línguas, `verify-pt` verde, seus plugins/badges aparecendo.
4. **Se estabilizou**, atualize o `pinned` no `manifest.json` e publique com
   `tools/release.sh` (nova sub-versão do repo).

## Se quebrar (rollback)

- **Pelo painel**: botão "↩ Voltar para …" (usa a última versão que funcionava,
  do histórico ou do `pinned`) — mesmo fluxo, instalando a versão anterior e
  reaplicando os patches dela.
- **No terminal:**
  ```bash
  sudo core-i18n-pt/tools/core-update.sh --rollback <versão-anterior>
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
