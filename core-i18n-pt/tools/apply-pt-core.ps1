# apply-pt-core.ps1 - aplica/verifica/reverte o pt-BR no core instalado (WINDOWS).
# Usa o pt-ride.mjs (node, multiplataforma) em vez de patch tooling bash.
#   apply-pt-core.ps1 -Cmd --check | -Cmd --force | -Cmd --revert
#   (sem args = --force)
# ATENCAO: em `powershell.exe -File` o "--flag" cru NAO casa com o parametro
# $Cmd (o PS trata como nome de parametro e falha o binding) - use "-Cmd --flag".
# Roda igual no Windows PowerShell 5.1 e no PowerShell 7.x (sem exigir versao).
param([Parameter(Position=0)][string]$Cmd="--force")
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ErrorActionPreference = "Stop"

# Raiz dos pacotes do nucleo (@deepseek-ai com dsh-client-*). Ordem: npm root -g
# (Windows e Linux), depois o prefixo global do npm no Windows e os caminhos
# fixos do Linux - a mesma logica do apply-pt-core.sh.
function Get-CorePkgsDir {
    $roots = @()
    foreach ($npmCmd in @("npm.cmd", "npm")) {
        try {
            $r = (& $npmCmd root -g 2>$null | Select-Object -First 1)
            if ($r) { $roots += ([string]$r).Trim() }
        } catch { }
        if ($roots.Count -gt 0) { break }
    }
    if ($env:APPDATA) { $roots += (Join-Path $env:APPDATA "npm\node_modules") }
    $roots += "/opt/dsh-tui/node/lib/node_modules"
    $roots += "/usr/lib/node_modules"
    foreach ($r in ($roots | Where-Object { $_ } | Select-Object -Unique)) {
        foreach ($cand in @((Join-Path $r "@deepseek-ai\dsh\node_modules\@deepseek-ai"), (Join-Path $r "@deepseek-ai"))) {
            if (Test-Path (Join-Path $cand "dsh-client-locale")) { return $cand }
        }
    }
    return $null
}

$deps = Get-CorePkgsDir
if (-not $deps) {
    Write-Host "[X] raiz dos pacotes do core nao encontrada (npm root -g nao respondeu e nenhum prefixo conhecido tem o nucleo)."
    exit 1
}
# Marcador igual ao do Linux: <core>\node_modules\.dsh-core-pt-applied
$Marker = Join-Path (Split-Path $deps -Parent) ".dsh-core-pt-applied"
$LocaleClient = Join-Path $deps "dsh-client-locale\lib\client.js"

function Test-PtBr {
    if (-not (Test-Path $LocaleClient)) { return $false }
    # Le como UTF-8: no 5.1 o Get-Content -Raw sem -Encoding interpreta arquivo
    # sem BOM como ANSI e o acento de "Portugues" vira mojibake (falso ausente).
    try { return ([System.IO.File]::ReadAllText($LocaleClient, [System.Text.Encoding]::UTF8)) -match 'Portugu[e\u00ea]s' } catch { return $false }
}

if ($Cmd -eq "--check") {
    if (Test-PtBr) { Write-Host "[OK] pt-BR presente ($deps)"; exit 0 }
    Write-Host "[X] pt-BR ausente - rode: apply-pt-core.ps1 -Cmd --force"; exit 1
}

if ($Cmd -eq "--revert") {
    # O pt-ride guarda o original de cada arquivo em <arquivo>.dshbak antes de
    # alterar; reverter = devolver os originais e apagar os backups/marcador.
    $n = 0
    Get-ChildItem -Path $deps -Recurse -File -Filter "*.dshbak" -ErrorAction SilentlyContinue | ForEach-Object {
        $orig = $_.FullName.Substring(0, $_.FullName.Length - ".dshbak".Length)
        try { Copy-Item $_.FullName $orig -Force; Remove-Item $_.FullName -Force; $n++ } catch { }
    }
    if (Test-Path $Marker) { Remove-Item $Marker -Force -ErrorAction SilentlyContinue }
    # Sobra traducao? (nucleo traduzido por uma versao anterior da ferramenta, sem backup)
    $restantes = 0
    Get-ChildItem -Path $deps -Recurse -File -Filter "client.js" -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) -match 'const pt(?:\$\d+)?\s*=\s*\{') { $restantes++ } } catch { }
    }
    if ($n -gt 0) { Write-Host "[OK] pt-BR revertido ($n arquivo(s) restaurados de *.dshbak). Reinicie a GUI." }
    else { Write-Host "[i] nada para reverter (sem backups *.dshbak)." }
    if ($restantes -gt 0) {
        Write-Host "[i] $restantes arquivo(s) ainda com dicionario pt (aplicados por uma versao anterior, sem backup)."
        Write-Host "    Para voltar tudo ao original: npm.cmd install -g @deepseek-ai/dsh@<versao> --force"
    }
    exit 0
}

if ($Cmd -eq "--force") {
    if (-not $env:DSH_PT_SKIP) { $env:DSH_PT_SKIP = "" }   # vazio = traduz tudo
# O pacote da conversa TAMBEM e traduzido (paridade com o Linux, que aplica o patch
# 19-...conversation-pt-dicts.patch): antes ele era pulado e a tela de chat ficava em ingles.
# Quem precisar pular algum pacote define $env:DSH_PT_SKIP="nome-do-pacote" antes de rodar.
    & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps
    if ($LASTEXITCODE -ne 0) { Write-Host "[X] pt-ride falhou (veja acima)"; exit 1 }
    $ver = "?"
    try { $ver = (([System.IO.File]::ReadAllText((Join-Path $deps "dsh-client-locale\package.json"), [System.Text.Encoding]::UTF8)) | ConvertFrom-Json).version } catch { }
    try {
        $txt = "core=$ver lang=pt-BR tool=pt-ride data=" + [DateTime]::UtcNow.ToString("o") + "`r`n"
        [System.IO.File]::WriteAllText($Marker, $txt, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
    if (Test-PtBr) { Write-Host "[OK] pt-BR garantido via pt-ride (core $ver)"; exit 0 }
    Write-Host "[!] pt-ride rodou mas o rotulo 'Portugues' nao apareceu no core - confira $LocaleClient"
    exit 1
}

Write-Host "[X] opcao desconhecida: $Cmd (use -Cmd --check | -Cmd --force | -Cmd --revert)"
exit 2
