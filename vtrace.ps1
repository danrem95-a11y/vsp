$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== LC.12.0012: transaksi tsales April (tipe_trans, qty, hpp, evap) ==="
Reader "select a.tipe_trans, count(*) baris, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.hpp*b.qty) as numeric(18,0)) hppxqty, cast(max(b.hpp) as numeric(18,2)) max_hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and b.stok_id='LC.12.0012' and a.tgl between '2026-04-01' and '2026-04-30' group by a.tipe_trans"
Write-Host "`n=== baris '88' April dgn HPP terbesar (biang consout raksasa) ==="
Reader "select top 10 b.stok_id, isnull(b.evap,'') evap, cast(b.qty as numeric(18,2)) qty, cast(b.hpp as numeric(18,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' and a.tgl between '2026-04-01' and '2026-04-30' order by abs(b.hpp) desc"
Write-Host "`n=== sumber HPP EVAP: AVG(hpp) per stok+evap utk '88' (dipakai closing 4b/4d) - yg ekstrem ==="
Reader "select top 8 b.stok_id, isnull(b.evap,'') evap, count(*) n, cast(avg(isnull(b.hpp,0)) as numeric(18,0)) avg_hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'') order by abs(avg(isnull(b.hpp,0))) desc"
$cn.Close()
