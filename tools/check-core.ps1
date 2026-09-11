# check-core.ps1 — versão do CORE do DeepSeek Harness (L1) — Windows
# Compara instalado × pinado no manifest.json × latest npm. Informativo.
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$ErrorActionPreference = "SilentlyContinue"

$SELF    = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE   = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }

$manifest = Join-Path $CLONE "manifest.json"
$PINNED = ""
if (Test-Path $manifest) {
    $json = Get-Content -Encoding UTF8 $manifest -Raw | ConvertFrom-Json
    $PINNED = $json.core.pinned
}

$INSTALLED = (npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null | Select-String -Pattern "@deepseek-ai/dsh@([^ ]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1)
if (-not $INSTALLED) { $INSTALLED = "(não encontrado via npm ls -g)" }

$LATEST = (npm.cmd view "@deepseek-ai/dsh" version 2>$null)
if (-not $LATEST) { $LATEST = "indisponível (sem rede?)" }

Write-Host "── Core do DeepSeek Harness ──────────────────────────────"
Write-Host "  instalado nesta máquina : $INSTALLED"
Write-Host "  pinado no manifest.json : $PINNED"
Write-Host "  latest no npm           : $LATEST"
Write-Host "──────────────────────────────────────────────────────────"
if ($LATEST -ne "indisponível (sem rede?)" -and $INSTALLED -ne $LATEST) {
    Write-Host "➜ Há versão NOVA do core ($LATEST). Política: notificar e aplicar manualmente."
    Write-Host "  Para atualizar (teste antes!):  npm.cmd update -g @deepseek-ai/dsh"
}
