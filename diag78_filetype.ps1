$ErrorActionPreference = 'Stop'
$path = 'c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls'
Format-Hex -Path $path | Select-Object -First 8 | Out-File 'c:\BTV\debug\diag78_filetype_out.txt' -Encoding utf8
Write-Output 'done'
