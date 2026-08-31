# 🚀 DeepSeek Harness GUI - Versão Windows (v1)

Esta é a versão do DeepSeek Harness GUI exportada do servidor Linux atual, com todas as configurações personalizadas, plugins e ajustes que foram feitos no ambiente. Funciona no Windows 10 e 11.

---

## 📋 Pré-requisitos

| Requisito         | Detalhe                                      |
|-------------------|----------------------------------------------|
| Sistema Operacional | Windows 10 ou Windows 11 (64-bit recomendado) |
| Node.js           | v20+ LTS (recomendado)                        |
| Gerenciador de pacotes | pnpm (instalado automaticamente) ou npm     |

---

## 🔧 Instalação (Passo a Passo)

### ✅ Opção 1: Instalador automático (`install.bat`)

1. Abra a pasta `dsh-h-v1`.
2. Clique duas vezes no arquivo `install.bat`.
3. Siga o assistente (ele verifica Node.js, instala pnpm se necessário, configura `.dsh`, e instala dependências).

### ✅ Opção 2: Instalador PowerShell avançado (`install.ps1`)

1. Clique com o botão direito no `install.ps1` → “Executar com PowerShell”.
2. Em caso de restrição de execução, execute primeiro:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```
3. As mesmas etapas ocorrem automaticamente.

### ✅ Opção 3: Instalação manual

1. Instale [Node.js v20+](https://nodejs.org).
2. Em uma janela de terminal (PowerShell ou CMD), execute:
   ```cmd
   cd source
   npm install
   ```
3. Copie a pasta `dsh_dot_dsh_config` para dentro de `%USERPROFILE%\.dsh`.

---

## ▶️ Como Executar

Depois da instalação:

- Clique duas vezes no `start-dsh-gui.bat` criado automaticamente.
- Ou manualmente, dentro da pasta `source`:
  ```cmd
  node lib/bin.js web --port 3080
  ```
- Abra o navegador e acesse: [http://127.0.0.1:3080](http://127.0.0.1:3080)

---

## 🗂️ Estrutura do Pacote

```
dsh-h-v1/
├── install.bat                    → Instalador CMD automático
├── install.ps1                    → Instalador PowerShell avançado
├── start-dsh-gui.bat              → Inicia a GUI
├── dsh_dot_dsh_config/            → Todas as configurações, plugins e credenciais locais
└── source/
    ├── node_modules/              → Dependências do Node.js
    ├── lib/                       → Binários do DeepSeek Harness
    ├── config/                    → Arquivos de configuração internos
    └── package.json               → Metadados do projeto
```

---

## 🧰 Solução de Problemas Comuns

| Erro                                    | Solução                                       |
|-----------------------------------------|-----------------------------------------------|
| `node is not recognized`                | Instale o Node.js e reinicie o CMD/PowerShell |
| Erro ao instalar pnpm globalmente       | Use `npm install` como alternativa            |
| Não abre a página no navegador          | Aguarde alguns segundos e recarregue a aba    |
| Porta 3080 já está em uso                | Execute `netstat -ano | findstr 3080` e mate o processo se necessário |

---

## 📝 Notas Finais

- Esta versão inclui todos os plugins e configurações customizadas do ambiente Linux original.
- Certifique-se de que as credenciais sensíveis em `.dsh/.credentials.yaml` sejam tratadas com cuidado, preferencialmente não compartilhadas.
