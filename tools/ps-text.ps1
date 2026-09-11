# ps-text.ps1 - leitura/escrita de texto portatil entre Windows PowerShell 5.1 e 7.x.
#
# Por que existe: as duas familias divergem em ENCODING.
#   - Get-Content/-Raw sem -Encoding le UTF-8-sem-BOM como ANSI no 5.1 (mojibake) e
#     como UTF-8 no 7;
#   - Set-Content/Add-Content -Encoding UTF8 grava BOM no 5.1 e nao no 7.
# Aqui as duas operacoes sao explicitas (sempre UTF-8) e o BOM e NUNCA gravado, que e
# o que arquivos lidos por outro programa (JSON/YAML) precisam.
#
# Uso:  . (Join-Path $PSScriptRoot "ps-text.ps1")

function Read-Utf8Text {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Out-Utf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(ValueFromPipeline=$true)][string[]]$Lines,
        [switch]$Append
    )
    begin { $buf = New-Object System.Collections.ArrayList }
    process { if ($null -ne $Lines) { foreach ($l in $Lines) { [void]$buf.Add([string]$l) } } }
    end {
        $text = (($buf | ForEach-Object { $_ }) -join "`r`n") + "`r`n"
        $enc = New-Object System.Text.UTF8Encoding($false)
        if ($Append) { [System.IO.File]::AppendAllText($Path, $text, $enc) }
        else { [System.IO.File]::WriteAllText($Path, $text, $enc) }
    }
}
