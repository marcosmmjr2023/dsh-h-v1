# flm-allow-frame.ps1 — permite o painel do FreeLLMAPI ser embutido DENTRO do DSH
#
# Por que existe: o painel do DSH abre o dashboard do FreeLLMAPI num <iframe>. O
# gateway usa helmet, cujo default manda X-Frame-Options: SAMEORIGIN e CSP
# frame-ancestors 'self' — e a GUI vive em OUTRA porta (3081/3110/3111), ou seja,
# outra origem para o navegador. Resultado: o frame nao carrega e o Chrome mostra
# "127.0.0.1 recusou a conexao" no lugar do painel.
#
# O FreeLLMAPI e um clone a parte (~/projects/freellmapi): este script aplica o
# ajuste de forma IDEMPOTENTE, em src/ (fonte) e dist/ (o que roda), e pode
# reiniciar o gateway. Rode de novo depois de qualquer atualizacao/rebuild dele.
#
# Uso:
#   tools/flm-allow-frame.ps1            # aplica (nao reinicia)
#   tools/flm-allow-frame.ps1 -Restart   # aplica e reinicia o gateway
#   tools/flm-allow-frame.ps1 -Check     # so informa o estado (nao altera)
#
# Seguranca: libera enquadramento SOMENTE para loopback (127.0.0.1/localhost, em
# qualquer porta). De fora continua impossivel embutir o dashboard.
# (param PRIMEIRO: o PowerShell nao aceita param depois de outra instrucao.)
param([switch]$Check, [switch]$Restart)
$ErrorActionPreference = "Stop"

$Proj = if ($env:FLM_PROJ) { $env:FLM_PROJ } else { Join-Path $env:USERPROFILE "projects\freellmapi" }
$Port = 3002
$Log  = Join-Path $env:USERPROFILE ".dsh\flm.log"
$Db   = Join-Path $env:USERPROFILE ".dsh\freeapi.db"

if (-not (Test-Path $Proj)) { Write-Host "[X] FreeLLMAPI nao encontrado em $Proj"; exit 1 }

$FRAME = 'frameAncestors: ["''self''", "http://127.0.0.1:*", "http://localhost:*"],'
$GUARD = 'frameguard: false,'
$Arquivos = @("server\src\app.ts", "server\dist\app.js")
$alterados = 0
$jaEstavam = 0

foreach ($rel in $Arquivos) {
  $f = Join-Path $Proj $rel
  if (-not (Test-Path $f)) { Write-Host "[i] ausente (pulado): $rel"; continue }
  $txt = [System.IO.File]::ReadAllText($f)
  $eol = "`n"
  if ($txt -match "`r`n") { $eol = "`r`n" }

  if ($txt.Contains($FRAME) -and $txt.Contains($GUARD)) {
    Write-Host "[OK] ja aplicado: $rel"
    $jaEstavam++
    continue
  }
  if ($Check) {
    Write-Host "[X] PRECISA aplicar: $rel"
    continue
  }

  $linhas = $txt -split "`r?`n"
  $novo = New-Object System.Collections.Generic.List[string]
  $porFrame = $false
  $porGuard = $false
  foreach ($l in $linhas) {
    if (-not $porGuard -and $l -match '^(\s*)hsts:\s*false,') {
      $novo.Add($matches[1] + $GUARD)
      $porGuard = $true
    }
    $novo.Add($l)
    if (-not $porFrame -and $l -match '^(\s*)upgradeInsecureRequests:\s*null,') {
      $novo.Add($matches[1] + $FRAME)
      $porFrame = $true
    }
  }
  if (-not $porFrame -or -not $porGuard) {
    Write-Host "[X] nao achei os pontos de insercao em $rel (formato mudou?) - frame=$porFrame guard=$porGuard"
    continue
  }
  [System.IO.File]::WriteAllText($f, ($novo -join $eol), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "[OK] ajustado: $rel"
  $alterados++
}

if ($Check) {
  if ($jaEstavam -eq $Arquivos.Count) { Write-Host "[OK] tudo aplicado" } else { Write-Host "[i] rode sem -Check para aplicar" }
  exit 0
}

if ($Restart) {
  $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
  if ($conn) {
    foreach ($c in $conn) { Write-Host "> parando gateway (PID $($c.OwningProcess))"; Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
  }
  if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
    Write-Host "[X] a porta $Port continua ocupada - nao subi um segundo gateway"
    exit 1
  }
  Write-Host "> subindo gateway na porta $Port (mesmo ambiente do flm-setup.ps1, SEM rodar o seed)"
  $env:PORT = "$Port"; $env:HOST = "127.0.0.1"; $env:FREEAPI_DB_PATH = $Db
  $env:DASHBOARD_ORIGINS = "http://localhost:5173,http://127.0.0.1:3081,http://127.0.0.1:$Port"
  Start-Process -FilePath "node" -ArgumentList @("dist\index.js") -WorkingDirectory (Join-Path $Proj "server") `
    -WindowStyle Hidden -RedirectStandardOutput $Log -RedirectStandardError ($Log + ".err")
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://127.0.0.1:$Port/" | Out-Null; break } catch { }
  }
}

Write-Host "== verificacao =="
try {
  $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri "http://127.0.0.1:$Port/"
  $xfo = $r.Headers["X-Frame-Options"]
  $csp = [string]$r.Headers["Content-Security-Policy"]
  $fa = ($csp -split ';' | Where-Object { $_ -match 'frame-ancestors' }) -join ''
  Write-Host ("  X-Frame-Options : " + $(if ($xfo) { "$xfo  <-- AINDA BLOQUEIA (o gateway nao foi reiniciado?)" } else { "(ausente - ok)" }))
  Write-Host ("  frame-ancestors : " + $(if ($fa) { $fa.Trim() } else { "(ausente - ok se nao houver CSP)" }))
} catch { Write-Host "  gateway nao respondeu na porta $Port" }
if ($alterados -gt 0 -and -not $Restart) { Write-Host "[i] reinicie o gateway para valer: tools/flm-allow-frame.ps1 -Restart" }
