$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function RunFile($label,$f){$s=Get-Content $f -Raw;$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s
 $sw=[Diagnostics.Stopwatch]::StartNew()
 try{$rd=$c.ExecuteReader();while($rd.Read()){Write-Host ("  "+$label+": n="+$rd["n_voucher"]+"  total_sisa_idr="+("{0:N2}" -f [double]$rd["total_sisa_idr"]))};$rd.Close();$sw.Stop();Write-Host ("    ("+$sw.ElapsedMilliseconds+" ms)")}
 catch{$sw.Stop();Write-Host ("  ERR "+$label+" ("+$sw.ElapsedMilliseconds+"ms): "+$_.Exception.Message)}}
Write-Host "===== GATE 1: SUM(SISA_IDR) report opname (per-voucher) April 2026 ====="
RunFile "AP report" "C:/BTV/debug/_g1_ap.sql"
RunFile "AR report" "C:/BTV/debug/_g1_ar.sql"
$cn.Close()
