$lines = Get-Content 'c:\BTV\debug\dw_stok_gl_mutasi.srd' -Encoding Unicode
Write-Host 'Lines:' $lines.Count
$lines | ForEach-Object { $_ }
