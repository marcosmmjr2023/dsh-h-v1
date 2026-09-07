# clean-windows.ps1  desinstala TUDO do DeepSeek Harness local (Windows)
# Uso: irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/clean-windows.ps1 | iex
$ErrorActionPreference = "SilentlyContinue"
Write-Host "== Limpeza DeepSeek Harness (Windows) =="
# 1) para processos do core
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -like '*@deepseek-ai\dsh*' -or $_.CommandLine -like '*\dsh\lib\bin.js*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Seconds 2
# 2) remove repo + config + atalhos
Remove-Item -Recurse -Force "$env:USERPROFILE\projects\dsh" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\.dsh" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:USERPROFILE\Desktop\DeepSeek Harness.lnk" -ErrorAction SilentlyContinue
Remove-Item -Force "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\DeepSeek Harness.lnk" -ErrorAction SilentlyContinue
# 3) (opcional) core global
& npm uninstall -g "@deepseek-ai/dsh" 2>$null
Write-Host "[OK] limpeza concluida. Rode agora o instalador:"
Write-Host "  irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/install-windows.ps1 | iex"
