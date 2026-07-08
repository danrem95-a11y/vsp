$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== L2a: count header/detail '19' & '09' (April, semua site) ==="
Reader "select tipe_trans, count(distinct bukti_id) n_header from TSTOK1 where tipe_trans in('19','09') and tgl between '2026-04-01' and '2026-04-30' group by tipe_trans"

Write-Host "=== L3a: sampel 10 header '19' : referensi ==="
Reader "select top 10 bukti_id, bukti_reff, order_reff, voucher, from_site, destination_site from TSTOK1 where tipe_trans='19' and tgl between '2026-04-01' and '2026-04-30' order by bukti_id"

Write-Host "=== L3b: sampel 10 header '09' : referensi ==="
Reader "select top 10 bukti_id, bukti_reff, order_reff, voucher, from_site, destination_site from TSTOK1 where tipe_trans='09' and tgl between '2026-04-01' and '2026-04-30' order by bukti_id"
$cn.Close()
