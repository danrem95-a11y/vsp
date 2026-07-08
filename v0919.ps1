$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== 09 vs 19 April: apakah berpasangan (qty & netto_hpp)? ==="
Reader "select a.tipe_trans, count(*) n, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.netto_hpp) as numeric(18,0)) netto_hpp from tstok1 a, tstok2 b where a.bukti_id=b.bukti_id and a.tipe_trans in ('09','19') and a.tgl between '2026-04-01' and '2026-04-30' group by a.tipe_trans"
Write-Host "`n=== LC.12.0012: sisi 09 (masuk) vs 19 (keluar) April - netto_hpp per sisi ==="
Reader "select a.tipe_trans, cast(b.qty as numeric(18,2)) qty, cast(b.netto_hpp as numeric(18,0)) netto_hpp, cast(b.hpp as numeric(18,2)) hpp, a.bukti_id from tstok1 a, tstok2 b where a.bukti_id=b.bukti_id and b.stok_id='LC.12.0012' and a.tipe_trans in ('09','19') and a.tgl between '2026-04-01' and '2026-04-30' order by a.tipe_trans"
$cn.Close()
