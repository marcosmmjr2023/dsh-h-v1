# core-env.ps1 - AMBIENTES PARALELOS do DeepSeek Harness no WINDOWS
# (equivalente ao core-env.sh do Linux; sem pm2 - gerenciamento por registro
#  ~/.dsh-envs/.registry.json com PID/porta/url; Start-Process + launcher .bat)
#
# Uso:
#   core-env.ps1 create <nome> --core <versao> [--from <home>]
#   core-env.ps1 import <nome> [--from <home|env>]
#   core-env.ps1 remove <nome>
#   core-env.ps1 ports
#   core-env.ps1 freellmapi <nome>
#
# A deteccao de SO e feita pelo servidor do painel: no Windows ele chama este
# script (powershell.exe -File); no Linux continua o core-env.sh.
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Command = "ports",
  [Parameter(Position = 1)][string]$Name = "",
  [string]$Core = "",
  [string]$From = ""
)
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$ErrorActionPreference = "Stop"

# Host do PowerShell (5.1 ou 7+): os atalhos precisam de um caminho ESTAVEL para
# o pwsh.exe — o da Store (...\Microsoft.PowerShell_7.x\pwsh.exe) muda a cada
# atualizacao e o atalho deixaria de funcionar.
$psHostHelper = Join-Path $PSScriptRoot "ps-host.ps1"
if (Test-Path $psHostHelper) { . $psHostHelper }

$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # ...\dsh-h-v1
$Base = Join-Path $env:USERPROFILE ".dsh-envs"
$RegistryFile = Join-Path $Base ".registry.json"
if (-not (Test-Path $Base)) { New-Item -ItemType Directory -Force -Path $Base | Out-Null }
function Read-Registry {
  if (Test-Path $RegistryFile) {
    try {
      $r = (Get-Content -Raw -Encoding UTF8 $RegistryFile | ConvertFrom-Json)
      if ($null -eq $r) { return @() }
      # registro com UMA entrada e gravado como objeto (nao lista) pelo
      # ConvertTo-Json do pipeline: normaliza para array para o resto do script
      # poder sempre iterar/contar do mesmo jeito.
      if ($r -isnot [array]) { return @($r) }
      return $r
    } catch { }
  }
  return @()
}
function Write-Registry([array]$List) {
  # SEM BOM: Set-Content -Encoding UTF8 no PS 5.1 grava BOM e quebra JSON.parse.
  # -InputObject: no pipeline um array de 1 elemento vira escalar (o arquivo
  # deixaria de ser uma lista). $null e filtrado para nunca gravar [null].
  $clean = @($List | Where-Object { $null -ne $_ })
  $rj = ConvertTo-Json -InputObject $clean -Depth 6
  if (-not $rj) { $rj = "[]" }
  [System.IO.File]::WriteAllText($RegistryFile, ($rj + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}
function Remove-RegistryEntry([string]$n) {
  $rest = @(Read-Registry) | Where-Object { $_.Name -ne $n }
  Write-Registry @($rest)
}
# Lock do registro: serializa "ler registro -> escolher porta -> gravar reserva"
# entre criacoes concorrentes (dois cliques no badge, badge + atalho, etc.).
# O lock e um arquivo criado com FileMode::CreateNew; se o dono morrer no meio,
# o arquivo fica orfao e e derrubado por idade.
function Lock-Registry([int]$TimeoutMs = 20000) {
  $lock = Join-Path $Base ".registry.lock"
  $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
  while ($true) {
    try {
      return [System.IO.File]::Open($lock, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    } catch {
      try {
        if ((Get-Item $lock -ErrorAction Stop).LastWriteTime -lt (Get-Date).AddMinutes(-15)) {
          Remove-Item $lock -Force -ErrorAction SilentlyContinue
          continue
        }
      } catch { }
      if ((Get-Date) -gt $deadline) { throw "nao consegui o lock do registro ($lock) - outra criacao em andamento?" }
      Start-Sleep -Milliseconds 250
    }
  }
}
function Unlock-Registry($handle) {
  if ($handle) { try { $handle.Dispose() } catch { } }
  Remove-Item (Join-Path $Base ".registry.lock") -Force -ErrorAction SilentlyContinue
}

# ── Atalhos por instancia (Desktop + Menu Iniciar) ──────────────────────────
# Antes so existia o .bat dentro de ~/.dsh-envs\<nome>, que ninguem acha — a
# instancia ficava sem icone para clicar. O atalho chama 'core-env.ps1 up <nome>':
# sobe a instancia se preciso, captura a URL autenticada (o token muda a cada
# boot, por isso a URL nao pode ficar fixa no atalho) e abre o navegador.
# As funcoes abaixo NAO escrevem na saida (a saida deste script e lida pelo
# painel): devolvem contagens e quem chama imprime a mensagem.
function Shortcut-Nome([string]$n) { return "DeepSeek Harness - $n.lnk" }
function Shortcut-Caminhos([string]$n) {
  $arq = Shortcut-Nome $n
  # DOIS caminhos de Desktop de proposito. Nesta maquina o registro aponta o
  # Desktop do shell para '...\OneDrive\antigos-ate-out-2025\Desktop' — uma pasta
  # ARQUIVADA dentro do OneDrive (o proprio atalho da GUI principal caiu la e o
  # usuario nao o ve). O desktop realmente usado e %USERPROFILE%\Desktop. Como
  # nao da para saber qual o usuario olha, gravamos nos dois (dedup abaixo) mais
  # o Menu Iniciar, que e o lugar confiavel.
  $cands = @(
    (Join-Path ([Environment]::GetFolderPath("Desktop")) $arq),
    (Join-Path $env:USERPROFILE ("Desktop\" + $arq)),
    (Join-Path $env:APPDATA ("Microsoft\Windows\Start Menu\Programs\" + $arq))
  )
  $vistos = @{}
  $out = @()
  foreach ($c in $cands) {
    $k = $c.ToLowerInvariant()
    if (-not $vistos.ContainsKey($k)) { $vistos[$k] = $true; $out += $c }
  }
  return $out
}
function New-InstanceShortcut([string]$n) {
  $tgt = $null
  if (Get-Command Get-PsHostPersistPath -ErrorAction SilentlyContinue) { $tgt = Get-PsHostPersistPath }
  if (-not $tgt) { $tgt = "powershell.exe" }
  # nome proprio: $args e automatico no PowerShell e nao pode ser reusado aqui
  $argLnk = "-NoProfile -ExecutionPolicy Bypass -File `"" + (Join-Path $PSScriptRoot "core-env.ps1") + "`" up $n"
  $ico = Join-Path $Repo "assets\deepseek.ico"
  if (-not (Test-Path $ico)) { $ico = "" }
  $feitos = 0
  try {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($p in (Shortcut-Caminhos $n)) {
      try {
        $lnk = $ws.CreateShortcut($p)
        $lnk.TargetPath = $tgt
        $lnk.Arguments = $argLnk
        $lnk.WorkingDirectory = $Repo
        $lnk.Description = "DeepSeek Harness - instancia $n (core isolado)"
        if ($ico) { $lnk.IconLocation = "$ico,0" }
        $lnk.Save()
        $feitos = $feitos + 1
      } catch { }
    }
  } catch { }
  return $feitos
}
function Remove-InstanceShortcut([string]$n) {
  $feitos = 0
  foreach ($p in (Shortcut-Caminhos $n)) {
    if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue; $feitos = $feitos + 1 }
  }
  return $feitos
}

# ── Reserva de porta ────────────────────────────────────────────────────────
# Uma criacao passa por robocopy + npm install + pt-ride ANTES de subir e
# registrar a instancia: nessa janela (minutos!) a porta escolhida nao aparece
# em Get-NetTCPConnection nem no registro, e uma segunda criacao escolhia A
# MESMA porta. A instancia nova morria com "listen EADDRINUSE"; sem a linha
# "dsh web: …?token=" o meta.json saia com uma URL SEM token e a GUI respondia
# 401 ("dsh web authentication required; reopen the URL printed by dsh web").
# Agora a porta e RESERVADA no registro logo apos a escolha (dentro do lock).
$ReservationTtlHours = 3
function Reservation-Alive($r) {
  if (-not $r.Reserved) { return $false }
  try { return ([datetime]$r.Created) -ge (Get-Date).AddHours(-$ReservationTtlHours) } catch { return $true }
}
function New-Port([int]$Start = 3110, [int]$End = 3900) {
  $used = @()
  Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $used += $_.LocalPort }
  $reg = Read-Registry
  foreach ($r in $reg) {
    # reserva expirada (criacao que morreu) nao segura a porta para sempre
    if ($r.Port -and (-not $r.Reserved -or (Reservation-Alive $r))) { $used += [int]$r.Port }
    if ($r.FlmPort) { $used += [int]$r.FlmPort }
  }
  for ($p = $Start; $p -le $End; $p++) {
    if (($used -notcontains $p) -and @(3000,3001,3002,3003,3080,3081,8125) -notcontains $p) { return $p }
  }
  throw "Sem porta livre na faixa $Start-$End (aumente DSH_PORT_RANGE_END)"
}

function Env-Home([string]$n) { return (Join-Path $Base $n) }
function Entry([string]$n) {
  $reg = Read-Registry
  foreach ($r in $reg) { if ($r.Name -eq $n) { return $r } }
  return $null
}

# Sobe uma instancia e devolve a URL AUTENTICADA.
# O core 0.1.5+ imprime no boot:  dsh web: http://127.0.0.1:<porta>/?token=<token>
# Sem esse token a GUI responde 401 ("reopen the URL printed by dsh web"). Cores
# antigos imprimem a linha sem token: nesse caso a URL vale como esta.
# Le um arquivo que outro processo mantem ABERTO (o web.log da instancia em
# execucao): abre com FileShare.ReadWrite. ReadAllText usa FileShare.Read e
# falha com "being used by another process" - era o que impedia capturar a URL
# com token e fazia a GUI responder 401.
function Read-LogShared([string]$Path) {
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    } catch { return "" }
    try {
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
        return $sr.ReadToEnd()
    } catch { return "" }
    finally { try { $fs.Dispose() } catch { } }
}
function Start-CoreInstance {
    param([string]$Name, [string]$EnvDir, [string]$HomeDir, [string]$Bin, [int]$Port, [string]$Core)
    # Pre-checagem: se a porta ja esta escutando, o node novo morreria com
    # EADDRINUSE e a mensagem so apareceria no web.log.err. Melhor dizer na hora.
    $ocupada = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($ocupada.Count -gt 0) {
        $pids = (($ocupada | ForEach-Object { $_.OwningProcess } | Sort-Object -Unique) -join ", ")
        throw "a porta $Port ja esta em uso (PID $pids) - outra instancia subiu nela"
    }
    $log = Join-Path $EnvDir "web.log"
    $err = Join-Path $EnvDir "web.log.err"
    Remove-Item $log,$err -Force -ErrorAction SilentlyContinue
    $env:DSH_HOME=$HomeDir; $env:DSH_WEB_URL="http://127.0.0.1:$Port"; $env:DSH_ENV_NAME=$Name
    $env:DSH_CORE_VERSION=$Core; $env:HOME=$env:USERPROFILE
    $proc = Start-Process -FilePath "node" -ArgumentList @("$Bin","--profile","web","--no-open","--port","$Port","--host","127.0.0.1") `
      -WorkingDirectory $env:USERPROFILE -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $log -RedirectStandardError $err
    $url = ""
    # Janela GENEROSA de proposito: o boot normal leva ~20 s (medido), mas logo
    # apos o npm install — que escreve ~210 MB — o disco fica quente e o
    # carregamento dos modulos passa facil de 2 min. Com a janela antiga de 42 s
    # a criacao falhava no boot e o trap apagava um core JA instalado, obrigando
    # a repetir o npm install inteiro (~17 min). Enquanto o processo estiver VIVO
    # continuamos esperando; se ele morrer, paramos na hora.
    $primeiraSaidaEm = -1.0
    $swBoot = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 300; $i++) {          # 300 x 700 ms = 210 s
        Start-Sleep -Milliseconds 700
        if (Test-Path $log) {
            $txt = Read-LogShared $log
            if ($primeiraSaidaEm -lt 0 -and $txt.Trim().Length -gt 0) { $primeiraSaidaEm = $swBoot.Elapsed.TotalSeconds }
            $mm = [regex]::Match($txt, "dsh web:\s*(http://[^\s]+)")
            if ($mm.Success) { $url = $mm.Groups[1].Value; break }
        }
        if ($proc.HasExited) { break }
    }
    $swBoot.Stop()
    if (-not $url) {
        # Sem a linha "dsh web: http://…?token=…" NAO ha como autenticar: o core
        # 0.1.5+ responde 401 ("dsh web authentication required; reopen the URL
        # printed by dsh web") a qualquer acesso sem token. Antes isto virava
        # silenciosamente "http://127.0.0.1:<porta>" e a criacao era anunciada
        # como SUCESSO — foi assim que uma instancia morta por EADDRINUSE
        # entregou uma URL que dava 401 para sempre.
        $tail = ""
        foreach ($cand in @($err, $log)) {
            if ($tail) { break }
            try { if (Test-Path $cand) { $tail = Read-LogShared $cand } } catch { }
        }
        $tail = (($tail -split "`r?`n") | Where-Object { $_ -ne "" } | Select-Object -Last 12) -join "`n"
        $motivo = if ($proc -and $proc.HasExited) { "o processo terminou (exit $($proc.ExitCode))" } else { "o log nao trouxe a URL com token em 210s" }
        $motivo += if ($primeiraSaidaEm -lt 0) { " - o log ficou VAZIO o tempo todo (o core nem comecou a subir)" } else { (" - a primeira linha do log saiu em {0:N1}s" -f $primeiraSaidaEm) }
        throw "a instancia '$Name' nao subiu na porta $Port : $motivo`n$tail"
    }
    return [ordered]@{ Proc = $proc; Url = $url; Log = $log; PrimeiraSaidaEm = $primeiraSaidaEm }
}
switch ($Command) {
  "create" {
    # Em qualquer falha terminante sai com codigo != 0 para o painel mostrar a
    # falha em vez de anunciar sucesso. O que fazer com o diretorio depende de
    # ONDE falhou: se o core JA foi instalado (meta.json gravado, passo 4),
    # apagar seria criminoso — o npm install leva ~17 min (inclui os builds
    # nativos do koffi/node-pty). Foi exatamente o que aconteceu com a
    # 'nova-015rc1-3': o boot passou dos 42 s da janela antiga, o trap rodou e
    # apagou 210 MB de core instalado.
    trap {
      Write-Host "[X] falha ao criar a instancia: $($_.Exception.Message)"
      $temMeta = $envDir -and (Test-Path (Join-Path $envDir "meta.json"))
      if ($temMeta) {
        Write-Host "     O core FOI instalado e foi PRESERVADO em: $envDir"
        Write-Host "     Retome SEM reinstalar (so sobe a instancia):"
        Write-Host "       core-env.ps1 up $Name"
      } else {
        # Falhou antes do core existir: remove a reserva de porta e o parcial,
        # senao um novo "create" responderia "instancia ja existe".
        if ($Name) { try { Remove-RegistryEntry $Name } catch { } }
        if ($envDir -and (Test-Path $envDir)) {
          Remove-Item $envDir -Recurse -Force -ErrorAction SilentlyContinue
          Write-Host "     (diretorio parcial removido: $envDir)"
        }
      }
      exit 1
    }
    if (-not $Name) { throw "Informe o nome (create <nome> --core <versao>)" }
    if (-not $Core) { throw "Informe --core <versao>" }
    $envDir = Env-Home $Name
    if (Test-Path $envDir) {
      # Distingue "core instalado, so faltou subir" (retomavel com 'up') de
      # "diretorio parcial" (tem de remover antes de recriar).
      if (Test-Path (Join-Path $envDir "meta.json")) {
        throw "Instancia '$Name' ja existe e o core esta instalado. Para subir sem reinstalar: core-env.ps1 up $Name"
      }
      throw "Instancia '$Name' ja existe (diretorio parcial). Remova antes: core-env.ps1 remove $Name"
    }
    if (-not $From) { $From = Join-Path $env:USERPROFILE ".dsh-v2" }
    if (-not (Test-Path $From)) { $From = Join-Path $env:USERPROFILE ".dsh" }
    $homeDir = Join-Path $envDir "home"
    $coreDir = Join-Path $envDir "core"
    New-Item -ItemType Directory -Force -Path $homeDir,$coreDir | Out-Null
    # RESERVA da porta ANTES do trabalho longo (robocopy + npm install + pt-ride
    # levam minutos). Dentro do lock para que duas criacoes concorrentes nao
    # escolham a mesma porta; a entrada e substituida no fim (mesmo Name).
    $lock = Lock-Registry
    try {
      $port = New-Port
      $reg = @(Read-Registry) + [ordered]@{ Name=$Name; Port=$port; Pid=0; Home=$homeDir; Url=""; Reserved=$true; Created=(Get-Date -Format o) }
      Write-Registry @($reg)
    } finally { Unlock-Registry $lock }
    Write-Host "> criando '$Name' core c$Core porta $port (porta reservada)"
    # 1) copia a config do home de origem, SEM o que e runtime/esta travado:
    #    - app-profile: e o perfil do NAVEGADOR da janela do app (aberto com
    #      --user-data-dir) -> fica em uso e fazia a copia abortar no meio;
    #    - sessions/storages/node_modules/.git: como antes (entram depois pelo 'import');
    #    - logs/estado de execucao: nao fazem sentido numa instancia nova.
    # robocopy em vez de Copy-Item: continua em arquivo travado, e rapido e reporta.
    $xd = @("app-profile", "sessions", "storages", "node_modules", ".git")
    $xf = @("*.log", "*.log.err", "*.bak*", "state.json", ".dsh-autoupdate.off")
    robocopy $From $homeDir /E /XD @xd /XF @xf /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 8) {
      Write-Host "[AVISO] alguns arquivos do config nao puderam ser copiados (em uso) - a instancia segue sem eles."
    }
    # 2) core isolado (npm 11+: flag allow-scripts p/ koffi/node-pty)
    $npmMajor = 0
    try { $npmMajor = [int]((& npm.cmd -v 2>$null).Trim().Split(".")[0]) } catch { }
    $allowFlags = @()
    if ($npmMajor -ge 11) { $allowFlags = @("--allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs") }
    # SEM '2>&1': com $ErrorActionPreference="Stop", qualquer linha de stderr
    # (ex.: um simples 'npm warn') vira erro TERMINANTE e aborta a criacao.
    & npm.cmd install -g --prefix $coreDir "@deepseek-ai/dsh@$Core" @allowFlags | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "npm install falhou (exit $LASTEXITCODE) para @deepseek-ai/dsh@$Core" }
    $coreRoot = (& npm.cmd root -g --prefix $coreDir).Trim()
    # 3) pt-BR via pt-ride (node, multiplataforma)
    $deps = Join-Path $coreRoot "@deepseek-ai\dsh\node_modules\@deepseek-ai"
    if (Test-Path $deps) {
      if (-not $env:DSH_PT_SKIP) { $env:DSH_PT_SKIP = "" }   # vazio = traduz tudo (inclui a conversa)
      & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps | Write-Host
      if ($LASTEXITCODE -ne 0) {
        # pt-BR e opcional: avisa e segue (sem derrubar a criacao da instancia).
        Write-Host "[AVISO] pt-BR nao aplicado nesta instancia - rode depois: apply-pt-core.ps1 -Cmd --force"
      }
    }
    # 4) meta: gravado ANTES de subir a instancia. Este arquivo e o sinal de que
    #    "o core ja esta instalado" — o trap o consulta para NAO apagar o
    #    resultado do npm install quando a falha for no boot. Fica com url vazia
    #    ate o token ser capturado no passo 5.
    #    SEM BOM: este meta.json e lido por JSON.parse no layout-panel-plugin.js e
    #    no freellmapi-shortcut-plugin.js — com BOM a leitura falhava em silencio
    #    (o badge FreeLLMAPI caia no gateway global em vez da porta da instancia).
    $bin = Join-Path $coreRoot "@deepseek-ai\dsh\lib\bin.js"
    $metaPath = Join-Path $envDir "meta.json"
    $meta = [ordered]@{ name=$Name; core=$Core; port=$port; url="";
                       home=$homeDir; coreRoot=$coreRoot; created=(Get-Date -Format o); log=(Join-Path $envDir "web.log") }
    [System.IO.File]::WriteAllText($metaPath, (($meta | ConvertTo-Json -Depth 6) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    # substitui a RESERVA feita no inicio (mesmo Name): nao duplica a entrada.
    # Pid=0/Url="" = "instalado, ainda nao no ar" — exatamente o que o 'up' espera.
    $reg = @(Read-Registry) | Where-Object { $_.Name -ne $Name }
    $reg = @($reg) + [ordered]@{ Name=$Name; Port=$port; Pid=0; Home=$homeDir; Url="" }
    Write-Registry @($reg)
    # 5) sobe a instancia CAPTURANDO a saida: o core novo imprime a URL com o
    #    token de autenticacao e sem ela a GUI responde 401.
    $started = Start-CoreInstance -Name $Name -EnvDir $envDir -HomeDir $homeDir -Bin $bin -Port $port -Core $Core
    $meta.url = $started.Url
    [System.IO.File]::WriteAllText($metaPath, (($meta | ConvertTo-Json -Depth 6) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    $reg = @(Read-Registry) | Where-Object { $_.Name -ne $Name }
    $reg = @($reg) + [ordered]@{ Name=$Name; Port=$port; Pid=$started.Proc.Id; Home=$homeDir; Url=$started.Url }
    Write-Registry @($reg)
    # 6) launcher: chama "up" (sobe se preciso, captura o token e abre o navegador).
    #    O token muda a cada boot, entao gravar a URL fixa aqui quebraria no 2o uso.
    $bat = Join-Path $envDir "abrir-$Name.bat"
    $me = Join-Path $PSScriptRoot "core-env.ps1"
    @("@echo off",
      "REM Abre a instancia $Name (core c$Core) - porta $port",
      "REM Sobe a instancia se necessario, captura a URL autenticada e abre o navegador.",
      "set `"PSEXE=`"",
      "for %%P in (`"%ProgramFiles%\PowerShell\7\pwsh.exe`" `"%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe`" `"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`") do if not defined PSEXE if exist `"%%~P`" set `"PSEXE=%%~P`"",
      "if not defined PSEXE ( where pwsh >nul 2>nul && set `"PSEXE=pwsh`" )",
      "if not defined PSEXE ( where powershell >nul 2>nul && set `"PSEXE=powershell`" )",
      "`"%PSEXE%`" -NoProfile -ExecutionPolicy Bypass -File `"$me`" up $Name",
      "pause") | Set-Content -Encoding ASCII $bat
    # 7) atalho no Desktop + Menu Iniciar, para a instancia ser clicavel como a
    #    GUI principal (o .bat acima fica escondido em ~/.dsh-envs\<nome>)
    $nAtalhos = New-InstanceShortcut $Name
    if ($nAtalhos -gt 0) {
      Write-Host "[OK] atalho '$(Shortcut-Nome $Name)' criado no Desktop e no Menu Iniciar"
    } else {
      Write-Host "[i] nao consegui criar os atalhos - launcher: $bat"
    }
    Write-Host "[OK] instancia '$Name' criada: $($started.Url)"
  }
  "up" {
    if (-not $Name) { throw "Informe o nome (up <nome>)" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe (veja: core-env.ps1 ports)" }
    $envDir = Env-Home $Name
    $metaPath = Join-Path $envDir "meta.json"
    $mi = $null
    try { $mi = ([System.IO.File]::ReadAllText($metaPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json) } catch { }
    if (-not $mi) { throw "meta.json da instancia '$Name' nao encontrado (recrie a instancia)" }
    $bin = Join-Path $mi.coreRoot "@deepseek-ai\dsh\lib\bin.js"
    if (-not (Test-Path $bin)) { throw "core da instancia nao encontrado: $bin" }
    $vivo = $false
    if ($entry.Pid) { try { $vivo = -not (Get-Process -Id $entry.Pid -ErrorAction Stop).HasExited } catch { $vivo = $false } }
    # ja no ar E com token conhecido -> so abre
    if ($vivo -and ("$($mi.url)" -match "token=")) {
        Write-Host "[OK] instancia '$Name' ja esta no ar: $($mi.url)"
        if (-not $env:DSH_NO_BROWSER) { Start-Process $mi.url | Out-Null }
        break
    }
    # sem token (ou processo morto): reinicia capturando a URL autenticada
    if ($vivo) { try { Stop-Process -Id $entry.Pid -Force -ErrorAction Stop } catch { } ; Start-Sleep -Milliseconds 900 }
    $started = Start-CoreInstance -Name $Name -EnvDir $envDir -HomeDir $mi.home -Bin $bin -Port ([int]$mi.port) -Core $mi.core
    $mi.url = $started.Url
    [System.IO.File]::WriteAllText($metaPath, (($mi | ConvertTo-Json -Depth 6) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    $reg = @(Read-Registry)
    for ($i=0; $i -lt $reg.Count; $i++) { if ($reg[$i].Name -eq $Name) { $reg[$i].Pid=$started.Proc.Id; $reg[$i].Url=$started.Url } }
    Write-Registry @($reg)
    Write-Host "[OK] instancia '$Name' no ar: $($started.Url)"
    if (-not $env:DSH_NO_BROWSER) { Start-Process $started.Url | Out-Null }
  }
  "import" {
    if (-not $Name) { throw "Informe o nome (import <nome> [--from <origem>])" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    if (-not $From) { $From = Join-Path $env:USERPROFILE ".dsh-v2" }
    if (-not (Test-Path $From)) { $From = Join-Path $env:USERPROFILE ".dsh" }
    Write-Host "> importando de '$From' p/ '$Name' (mescla)"
    foreach ($sub in @("sessions","storages")) {
      $src = Join-Path $From $sub
      if (Test-Path $src) { Copy-Item -Recurse -Force $src (Join-Path $entry.Home $sub) }
    }
    foreach ($f in @("settings.yaml",".credentials.yaml","cordis.patch.yml")) {
      $src = Join-Path $From $f
      if (Test-Path $src) { Copy-Item -Force $src (Join-Path $entry.Home $f) }
    }
    Write-Host "[OK] importacao concluida - recarregue a pagina da instancia (F5)"
  }
  "freellmapi" {
    if (-not $Name) { throw "Informe o nome" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    $flp = New-Port
    $gw = Join-Path $env:USERPROFILE "projects\freellmapi\server"
    if (Test-Path (Join-Path $gw "dist\index.js")) {
      $flDir = Join-Path (Env-Home $Name) "freellmapi"
      New-Item -ItemType Directory -Force -Path $flDir | Out-Null
      $env:PORT="$flp"; $env:HOST="127.0.0.1"; $env:FREEAPI_DB_PATH=(Join-Path $flDir "freeapi.db")
      $env:DASHBOARD_ORIGINS="http://localhost:5173,http://127.0.0.1:5173,http://127.0.0.1:$($entry.Port)"
      $proc = Start-Process -FilePath "node" -ArgumentList @((Join-Path $gw "dist\index.js")) `
        -WorkingDirectory $gw -WindowStyle Hidden -PassThru
      $reg = @(Read-Registry)
      for ($i=0; $i -lt $reg.Count; $i++) { if ($reg[$i].Name -eq $Name) { $reg[$i].FlmPort=$flp; $reg[$i].FlmPid=$proc.Id } }
      Write-Registry @($reg)
      Write-Host "[OK] FreeLLMAPI da instancia na porta $flp"
    } else { Write-Host "i codigo FreeLLMAPI nao encontrado em $gw - use o gateway global" }
  }
  "remove" {
    if (-not $Name) { throw "Informe o nome (remove <nome>)" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    Write-Host "> removendo '$Name' (gateway + janela + pasta primeiro; processo por ultimo)"
    if ($entry.FlmPid) { Stop-Process -Id $entry.FlmPid -Force -ErrorAction SilentlyContinue }
    # fecha janela Chrome da instancia (perfil .dsh-envs\<nome> no comando)
    Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -like "*dsh-envs*$Name*" } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force (Env-Home $Name) -ErrorAction SilentlyContinue
    # a mensagem abaixo sempre prometeu "e atalhos", mas nada os removia: os
    # icones ficavam no Desktop/Menu Iniciar apontando para uma instancia morta
    $nAtalhos = Remove-InstanceShortcut $Name
    $reg = @(Read-Registry) | Where-Object { $_.Name -ne $Name }
    Write-Registry @($reg)
    if ($entry.Pid) { Stop-Process -Id $entry.Pid -Force -ErrorAction SilentlyContinue }
    Write-Host "[OK] instancia '$Name' removida (e $nAtalhos atalho(s)/pasta/perfil)"
  }
  "shortcut" {
    # (Re)cria o atalho de Desktop + Menu Iniciar. Sem nome: todas as instancias
    # do registro (util para as que foram criadas antes desta funcao existir).
    $alvos = @()
    if ($Name) {
      if (-not (Entry $Name)) { throw "Instancia '$Name' nao existe (veja: core-env.ps1 ports)" }
      $alvos = @($Name)
    } else {
      $alvos = @(Read-Registry | ForEach-Object { $_.Name })
    }
    if ($alvos.Count -eq 0) { Write-Host "i nenhuma instancia no registro"; break }
    foreach ($alvo in $alvos) {
      $n = New-InstanceShortcut $alvo
      if ($n -gt 0) { Write-Host "[OK] atalho de '$alvo': '$(Shortcut-Nome $alvo)' (Desktop + Menu Iniciar)" }
      else { Write-Host "[X] nao consegui criar o atalho de '$alvo'" }
    }
  }
  default { # ports
    Write-Host "== Instancias (registro) =="
    foreach ($r in (Read-Registry)) {
      Write-Host ("  {0,-20} harness {1}  flmapi {2}  {3}" -f $r.Name,$r.Port,$r.FlmPort,$r.Url)
    }
    if (-not (Read-Registry)) { Write-Host "  (nenhuma)" }
    Write-Host "proxima porta livre: $((New-Port))"
  }
}
