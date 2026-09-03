$exe = "C:\Bottas 2015\bottas.exe"
$p = Start-Process $exe -WorkingDirectory "C:\Bottas 2015" -PassThru
Write-Host ("Launched bottas.exe PID="+$p.Id)
$conn=$null
for($i=0;$i -lt 25;$i++){
  Start-Sleep -Milliseconds 800
  $c = Get-NetTCPConnection -OwningProcess $p.Id -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -eq '103.233.89.43' -and $_.RemotePort -eq 2638 }
  if($c){ $conn=$c; break }
}
Start-Sleep -Milliseconds 500
$alive = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
Write-Host ("Proses hidup : " + [bool]$alive)
if($alive){ Write-Host ("MainWindowTitle: '" + $alive.MainWindowTitle + "'") }
if($conn){
  Write-Host ("KONEKSI DB   : ESTABLISHED -> " + $conn.RemoteAddress + ":" + $conn.RemotePort + "  (Local " + $conn.LocalAddress + ":" + $conn.LocalPort + ")")
  Write-Host "=> bottas.exe BERHASIL connect ke prod (lolos dari kegagalan lama)."
} else {
  Write-Host "KONEKSI DB   : BELUM terlihat established ke 103.233.89.43:2638"
  Write-Host "   Semua koneksi milik bottas.exe:"
  Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue | Select-Object State,RemoteAddress,RemotePort | Format-Table -AutoSize
}