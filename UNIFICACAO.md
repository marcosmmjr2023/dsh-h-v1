# Unificação das versões dsh-h-v1 (PC1 + PC2)

Documento criado na unificação dos dois computadores que tinham o mesmo projeto
(`dsh-h-v1`, DeepSeek Harness GUI com config customizada) com melhorias
diferentes em cada um.

## Estrutura de ramos no GitHub (`marcosmmjr2023/dsh-h-v1`)

| Ramo | Origem | Conteúdo |
|------|--------|----------|
| `main` | Unificação (este doc) | **Versão mais completa**: tudo do PC1 + tudo de útil do PC2, com conflitos resolvidos. É o ramo vivo — melhorias futuras entram aqui. |
| `versao-pc1` | Este computador (Windows/OneDrive) | Snapshot do estado do PC1: commit inicial `59740d4` + snapshot `a5e9298` com as melhorias locais (01/set). Inclui launchers, ícones, `preload.cjs` e plugins melhorados. |
| `versao-pc2` | Outro computador (GitHub, commit `de4c569`) | Estado exportado no outro PC (05/set), **preservado intacto** (inclusive o lixo de runtime que ele commitou). |

## O que era diferente entre as duas versões

Cada lado tinha 80 arquivos. Comparação commit a commit:

| Categoria | Resultado |
|-----------|-----------|
| 72 arquivos | **Byte-idênticos** (bundle do DeepSeek Harness, plugins, settings) |
| 6 só no PC2 | Lixo de runtime que vazou pro commit: `settings.yaml.bak`, `settings.yaml.bak-*` (3), `profiles/tui/state.json`, `.anonymous-user-id` |
| 6 só no PC1 | `deepseek-whale.ico`, `dsh-v2-icon-256.png`, `dsh-v2-icon.svg`, `preload.cjs`, `start-dsh-h-v1-app.bat`, `start-parallel-dsh.bat` |
| 2 com conteúdo divergente | `.gitignore` e `dsh_dot_dsh_config/cordis.patch.yml` |
| Bônus só no PC1 (não commitado na época) | `layout-panel-plugin.js` v1.1 (multi-dir + junctions), cópia ativa `layout-panel-plugin-v7.js`, badge FreeLLMAPI reposicionado p/ o topo, `LAYOUT_PANEL_DIRS` multi-dir no `start-parallel-dsh.bat` |

### Diferença real de conteúdo no `cordis.patch.yml`

Os plugins são os MESMOS; só muda o caminho absoluto usado por cada máquina:

- **PC1 (estilo usado no `main`)**: `file:///C:/Users/marco/OneDrive/Documentos/projetos/dsh-h-v1/dsh_dot_dsh_config/<plugin>.js` — aponta para dentro do repo (config roda pela pasta, `DSH_HOME`).
- **PC2**: `/home/deploy/.dsh/<plugin>.js` — estilo do ambiente Linux/deploy.

> ⚠️ Caminhos absolutos são específicos de cada máquina. Se for rodar o `main`
> em outro PC, ajuste os caminhos do `cordis.patch.yml` para a pasta local
> (ou mantenha a versão do ramo daquela máquina).

## Decisões da resolução no `main`

1. **`.gitignore`** — união dos dois (regras de credenciais do PC2 em nível raiz +
   regras de runtime/estado do PC1). O lixo de runtime do PC2 fica ignorado.
2. **`cordis.patch.yml`** — versão do PC1 (referência ativa para
   `layout-panel-plugin-v7.js`), que é a config mais recente.
3. **Arquivos melhorados só no PC1** (`layout-panel-plugin.js` v1.1,
   `freellmapi-shortcut-plugin.js`, `profiles/web/cordis.patch.yml`,
   `start-parallel-dsh.bat`, `layout-panel-plugin-v7.js`, launchers/ícones/
   preload) — incluídos como versão final.
4. **`source/lib/bin.js`** — conteúdo idêntico nos dois; mantido o **modo
   executável (100755)** que veio do PC2.
5. **Lixo de runtime do PC2** (`settings.yaml.bak*`, `profiles/tui/state.json`,
   `.anonymous-user-id`) — **removido do `main`** (não é melhoria), mas continua
   preservado no ramo `versao-pc2`.

## Como foi feito o merge

```
git fetch <url-do-github> main:refs/heads/versao-pc2   # PC2 = commit original
git switch -c _merge versao-pc2                        # base = PC2 (main do GitHub)
git merge versao-pc1 --allow-unrelated-histories       # traz o PC1
# resolução: .gitignore = união; cordis/plugins = versão PC1;
# bin.js = modo executável do PC2; remoção do lixo runtime do PC2
git commit                                            # merge commit
git push origin main versao-pc1 versao-pc2
```

## Trabalhando daqui pra frente

- **PC1 (esta máquina)**: trabalha no ramo `main` e faz `git push origin main`.
- **PC2 (outro computador)**: `git clone` do repo e `git checkout main`
  (ajustando os caminhos do `cordis.patch.yml` para a máquina) — ou use
  `versao-pc2` se quiser exatamente o estado antigo dele.
- Os ramos `versao-pc1`/`versao-pc2` são **snapshots congelados**: servem de
  referência/backup das duas versões originais.
