# ps-host.ps1 - resolvedor do host do PowerShell do dsh-h-v1 (multi-versao)
#
# REQUISITO DO PROJETO: nao exigir uma versao especifica de PowerShell. Cada
# maquina Windows pode ter apenas o Windows PowerShell 5.1 (que acompanha o
# Windows), apenas o PowerShell 7.x (pwsh) ou os dois. Este helper devolve o
# executavel a usar, nesta ordem:
#   1) o host que esta rodando AGORA (mesmo runtime onde o script ja funcionou);
#   2) pwsh / pwsh.exe na PATH (PowerShell 7+);
#   3) powershell.exe / powershell na PATH (Windows PowerShell 5.1).
# Devolve $null quando nenhum existir - quem chama decide a mensagem de erro.
#
# Uso:
#   . (Join-Path $PSScriptRoot "ps-host.ps1")
#   $exe = Get-PsHostPath
#   if (-not $exe) { Write-Host "[X] PowerShell nao encontrado"; exit 1 }
#
# Observacao: os scripts do repo NAO usam construtos exclusivos de uma familia
# (ex.: "-Encoding Byte" do 5.1 x "-AsByteStream" do 7; "Set-Content -Encoding
# UTF8" grava BOM no 5.1 e nao no 7). Onde o resultado e lido por outro
# programa (JSON/YAML), a gravacao e feita com [System.IO.File]::WriteAllText +
# UTF8Encoding($false) e a leitura tolera BOM.

function Get-PsHostPath {
    # 1) o proprio processo atual (garante o mesmo runtime)
    try {
        $self = (Get-Process -Id $PID -ErrorAction Stop).Path
        if ($self -and (Test-Path $self)) { return $self }
    } catch { }
    # 2) e 3) procura na PATH, preferindo o 7+
    foreach ($name in @("pwsh.exe", "pwsh", "powershell.exe", "powershell")) {
        try {
            $cmd = Get-Command $name -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return $cmd.Source }
        } catch { }
    }
    return $null
}

function Get-PsHostPersistPath {
    # Para alvos PERSISTIDOS (atalho .lnk, tarefa agendada): devolve um caminho que
    # NAO muda quando o PowerShell e atualizado. O caminho da Store
    # (...\Microsoft.PowerShell_7.6.6.0_x64__8wekyb3d8bbwe\pwsh.exe) muda a cada
    # atualizacao e o atalho/tarefa quebraria - por isso aqui preferimos os estaveis.
    $cands = @(
        (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\pwsh.exe"),
        (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
    )
    foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
    return Get-PsHostPath
}
function Get-PsHostVersion {
    param([string]$Exe)
    if (-not $Exe) { $Exe = Get-PsHostPath }
    if (-not $Exe) { return "" }
    try {
        $out = & $Exe -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
        return (($out | Select-Object -First 1) -as [string])
    } catch { return "" }
}
