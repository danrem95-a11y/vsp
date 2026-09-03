$cn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$cn.Open()
function Exec($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{$c.ExecuteNonQuery()|Out-Null; Write-Host "  OK: $sql"}catch{Write-Host ("  ERR: "+$_.Exception.Message)} }
Exec "call sa_server_option('RequestLogFile','C:/BTV/debug/reqlog.txt')"
Exec "call sa_server_option('RequestLogging','SQL')"
Write-Host "Merekam 25 detik..."
Start-Sleep -Seconds 25
Exec "call sa_server_option('RequestLogging','NONE')"
Exec "call sa_server_option('RequestLogFile','')"
$cn.Close()
Write-Host "Selesai. Log di C:\BTV\debug\reqlog.txt"
$fi = Get-Item "C:\BTV\debug\reqlog.txt"
Write-Host ("Ukuran log: {0} KB, baris: {1}" -f [int]($fi.Length/1KB), (Get-Content $fi -ReadCount 0).Count)
