# 🚀 DeepSeek Harness GUI - Instalação Windows (dsh-h-v1)

Instalação da camada personalizada do DeepSeek Harness no Windows 10/11,
**sincronizada por git** — esta máquina recebe sempre a última versão
publicada no repositório.

> ⚠️ Caminhos como `installer\install.bat` e `tools\...` são **relativos à raiz
> do repositório** (a pasta do clone), não a esta pasta de documentação.
>
> Leia também o manual de sincronização: [`SYNC.md`](SYNC.md)

---

## 📋 Pré-requisitos

| Requisito | Detalhe |
|---|---|
| Sistema Operacional | Windows 10 ou 11 (64-bit recomendado) |
| Node.js | v20+ LTS (recomendado) |
| Git | com autenticação GitHub (`gh auth login` ou credential helper) |

---

## 🔧 Instalação

### ✅ Opção 1: Instalador automático (`installer/install.bat`)

1. Clone o repositório:
   ```cmd
   git clone https://github.com/marcosmmjr2023/dsh-h-v1.git %USERPROFILE%\dsh-h-v1
   ```
2. Execute `installer\install.bat` (ele instala o core via npm, aplica o
   overlay em `%USERPROFILE%\.dsh` e cria o `start-dsh-gui.bat`).

### ✅ Opção 2: PowerShell (`installer/install.ps1`)

Clique com o botão direito → "Executar com PowerShell".
Em caso de restrição de execução:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### ✅ Opção 3: Manual

```cmd
npm install -g @deepseek-ai/dsh
powershell -ExecutionPolicy Bypass -File tools\sync-pull.ps1
```

---

## ▶️ Como Executar

- Dê dois cliques no `start-dsh-gui.bat` (gerado pelo instalador) — ele já
  roda o sync (`sync-pull.ps1`) antes de abrir a GUI.
- Ou manualmente, dentro da pasta de instalação do harness:
  ```cmd
  dsh web --port 3080
  ```
- Abra o navegador: [http://127.0.0.1:3080](http://127.0.0.1:3080)

---

## 🔄 Sincronizar

| Ação | Comando (PowerShell) |
|---|---|
| Receber a última versão | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-pull.ps1"` |
| Publicar edições locais | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\sync-push.ps1" "o que mudou"` |
| Ver versão do core | `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\check-core.ps1"` |

---

## 🗂️ Estrutura do Pacote

```
dsh-h-v1/
├── overlay/                → Config viva (%USERPROFILE%\.dsh)
├── tools/                  → Scripts de sync + guard
├── installer/              → install.bat, install.ps1, start-dsh-gui.bat
├── manifest.json           → Versão do core pinada
└── docs/SYNC.md            → Manual de sincronização
```

## 🧰 Solução de Problemas Comuns

| Erro | Solução |
|---|---|
| `node is not recognized` | Instale o Node.js e reinicie o CMD/PowerShell |
| `git` não reconhecido | Instale o Git for Windows |
| Não abre a página no navegador | Aguarde e recarregue a aba |
| Porta 3080 em uso | `netstat -ano \| findstr 3080` e encerre o processo |

---

## 📝 Notas Finais

- Credenciais vivem em `%USERPROFILE%\.dsh\.credentials.yaml` (nunca
  sincronizada nem commitada — variáveis de ambiente também funcionam).
- A versão do core do harness é instalada pelo npm e **não** vem deste repo.
