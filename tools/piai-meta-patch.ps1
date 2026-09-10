# ============================================================
# piai-meta-patch.ps1 - registra "meta" no catalogo nativo do pi-ai
#
# Igual ao piai-meta-patch.sh (Linux): insere a rota "meta" no
# models.generated.js do pacote @earendil-works/pi-ai para o Harness
# tratar a Meta como provider padrao (sem selo "Custom").
#
# Uso:
#   powershell -File piai-meta-patch.ps1            # aplica (UAC se preciso)
#   powershell -File piai-meta-patch.ps1 -Remove    # desfaz (restaura .dshbak)
#
# Idempotente. Precisa ser reaplicado apos qualquer reinstall do core
# (npm.cmd update -g @deepseek-ai/dsh). O dsh update roda isto automaticamente.
# ============================================================
param([switch]$Remove)

$ErrorActionPreference = 'Stop'

function Get-PiAiCatalogFile {
  $npmRoot = (& npm.cmd root -g 2>$null | Select-Object -First 1)
  if (-not $npmRoot) { return $null }
  $cand = Join-Path $npmRoot "@deepseek-ai\dsh\node_modules\@earendil-works\pi-ai\dist\models.generated.js"
  if (Test-Path $cand) {
    $resolved = (Resolve-Path $cand -ErrorAction SilentlyContinue).Path
    return $resolved
  }
  $found = Get-ChildItem -Path $npmRoot -Recurse -Filter "models.generated.js" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*@earendil-works\pi-ai\dist*" } | Select-Object -First 1
  if ($found) { return $found.FullName }
  return $null
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$file = Get-PiAiCatalogFile
if (-not $file) {
  Write-Host "[X] nao achei models.generated.js do pi-ai (npm.cmd root -g)"
  exit 1
}
Write-Host "pi-ai catalog: $file"

$canWrite = -not ((Get-Item $file).IsReadOnly)
try {
  $stream = [IO.File]::Open($file, 'Open', 'ReadWrite', 'None')
  $stream.Close()
  $canWrite = $true
} catch {
  $canWrite = $false
}

if (-not $canWrite -and -not (Test-Admin)) {
  # Re-executa elevado (UAC) para gravar no core instalado como admin
  $arg = if ($Remove) { "-Remove" } else { "" }
  Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",$arg
  )
  Write-Host "executado elevado (UAC). Verifique o resultado acima."
  exit 0
}

$js = @'
const fs = require("fs");
const f = process.argv[1];
const remove = process.argv[2] === "remove";
let s = fs.readFileSync(f, "utf8");
if (remove) {
  const bak = f + ".dshbak";
  if (fs.existsSync(bak)) {
    fs.copyFileSync(bak, f);
    console.log("ok: restaurado backup (" + bak + ")");
  } else {
    s = s.replace(/^    "meta": \{\},\r?\n/m, "");
    fs.writeFileSync(f, s);
    console.log("ok: rota \"meta\" removida do catalogo");
  }
} else {
  if (s.includes("\"meta\": {}")) {
    console.log("ok: catalogo ja contem \"meta\" (nada a fazer)");
  } else {
    if (!fs.existsSync(f + ".dshbak")) fs.copyFileSync(f, f + ".dshbak");
    const needle = "\"openrouter\": OPENROUTER_MODELS,";
    if (!s.includes(needle)) throw new Error("ponto de insercao nao encontrado no catalogo");
    const eol = s.includes("\r\n") ? "\r\n" : "\n";
    s = s.replace(needle, needle + eol + "    \"meta\": {},");
    fs.writeFileSync(f, s);
    console.log("ok: rota \"meta\" registrada no catalogo do pi-ai (reinicie o dsh para aplicar)");
  }
}
'@

if ($Remove) {
  & node -e $js $file "remove"
} else {
  & node -e $js $file "install"
}
