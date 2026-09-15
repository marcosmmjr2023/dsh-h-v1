# ═══════════════════════════════════════════════════════════════
# make-social-preview.ps1 — gera assets/social-preview.png (1200x630)
#
# Para que serve: é a imagem do cartão que aparece quando alguém
# compartilha o link do repositório/página (X, LinkedIn, Slack, Discord,
# WhatsApp, Facebook). Também é a imagem usada como og:image no site.
#
# Onde usar:
#   1) repositório → Settings → General → Social preview → Upload an image;
#   2) já referenciada como og:image no site (site/index.html).
#
# Só Windows: usa System.Drawing (GDI+) para compor o texto e usar um quadro
# do GIF de demonstração. Rode:  pwsh -File tools/make-social-preview.ps1
# ═══════════════════════════════════════════════════════════════
[CmdletBinding()]
param(
    [string]$Out,
    [string]$Gif
)

# $PSScriptRoot ainda pode estar vazio durante o binding de parâmetros no
# Windows PowerShell 5.1 — resolve a pasta do script com os fallbacks usuais.
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$raiz = Split-Path -Parent $scriptDir
if (-not $Out) { $Out = Join-Path $raiz "assets\social-preview.png" }
if (-not $Gif) { $Gif = Join-Path $raiz "assets\freedsh-demo.gif" }

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not ($IsWindows -or $env:OS -eq "Windows_NT")) {
    Write-Host "Este gerador usa System.Drawing (GDI+) e roda apenas no Windows."
    exit 1
}
Add-Type -AssemblyName System.Drawing

$W = 1200; $H = 630
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

function New-Brush([int]$r, [int]$gr, [int]$b) {
    New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($r, $gr, $b))
}

try {
    # ── fundo (gradiente escuro) + faixa de acento ──────────────
    $rect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect, [System.Drawing.Color]::FromArgb(11, 15, 25), [System.Drawing.Color]::FromArgb(20, 30, 54), 35.0)
    $g.FillRectangle($grad, $rect)
    $accent = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0, 0, $W, 8)),
        [System.Drawing.Color]::FromArgb(56, 130, 246), [System.Drawing.Color]::FromArgb(34, 197, 154), 0.0)
    $g.FillRectangle($accent, 0, 0, $W, 8)

    $branco = New-Brush 245 248 252
    $cinza = New-Brush 165 178 199
    $apagado = New-Brush 120 134 156
    $verde = New-Brush 52 199 123

    # ── quadro do GIF (lado direito) ────────────────────────────
    $targetX = 612; $targetY = 92; $targetW = 548; $targetH = 342
    if (Test-Path $Gif) {
        $img = [System.Drawing.Image]::FromFile($Gif)
        try {
            $dim = New-Object System.Drawing.Imaging.FrameDimension($img.FrameDimensionsList[0])
            $null = $img.SelectActiveFrame($dim, 0)
            # molduras: borda + fundo do "monitor"
            $frame = New-Object System.Drawing.Rectangle(($targetX - 10), ($targetY - 10), ($targetW + 20), ($targetH + 20))
            $g.FillRectangle((New-Brush 26 34 51), $frame)
            $g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(58, 70, 92), 2)), $frame)
            $g.DrawImage($img, (New-Object System.Drawing.Rectangle($targetX, $targetY, $targetW, $targetH)))
        } finally { $img.Dispose() }
    }

    # ── textos (lado esquerdo) ──────────────────────────────────
    $fTitulo = New-Object System.Drawing.Font("Segoe UI", 76, [System.Drawing.FontStyle]::Bold)
    $fSub = New-Object System.Drawing.Font("Segoe UI", 21, [System.Drawing.FontStyle]::Regular)
    $fItem = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Regular)
    $fPequena = New-Object System.Drawing.Font("Segoe UI", 17, [System.Drawing.FontStyle]::Regular)
    $fTag = New-Object System.Drawing.Font("Segoe UI", 17, [System.Drawing.FontStyle]::Bold)

    $x = 64
    $g.DrawString("FreeDSH", $fTitulo, $branco, $x, 66)
    $g.DrawString("Free-first routing for DeepSeek Harness", $fSub, $cinza, ($x + 4), 190)
    $fSub2 = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Regular)
    $g.DrawString("automatic fallback · safe core updates · Windows + Linux", $fSub2, $apagado, ($x + 5), 234)

    $itens = @(
        "Free and low-cost models, routed by task",
        "One-line installer, no Linux required",
        "pt-BR included out of the box",
        "Sync, snapshots and rollback built in"
    )
    $y = 292
    foreach ($item in $itens) {
        $g.FillEllipse($verde, $x + 4, ($y + 11), 10, 10)
        $g.DrawString($item, $fItem, $branco, ($x + 28), $y)
        $y += 44
    }

    # ── rodapé ──────────────────────────────────────────────────
    $g.FillRectangle((New-Brush 20 27 43), (New-Object System.Drawing.Rectangle(0, ($H - 66), $W, 66)))
    $g.DrawString("github.com/marcosmmjr2023/dsh-h-v1", $fPequena, $cinza, $x, ($H - 46))
    $textoNaoOficial = "unofficial project · not affiliated with DeepSeek"
    $larg = $g.MeasureString($textoNaoOficial, $fPequena).Width
    $g.DrawString($textoNaoOficial, $fPequena, $apagado, ($W - 64 - $larg), ($H - 46))

    $dir = Split-Path -Parent $Out
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

    $fTitulo.Dispose(); $fSub.Dispose(); $fSub2.Dispose(); $fItem.Dispose(); $fPequena.Dispose(); $fTag.Dispose()
    $grad.Dispose(); $accent.Dispose()
    Write-Host "ok: $Out ($((Get-Item $Out).Length) bytes, ${W}x${H})"
} finally {
    $g.Dispose(); $bmp.Dispose()
}
