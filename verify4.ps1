$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== SINV per periode: baris, qty>0 tapi hpp_avg=0 (HPP hilang), nilai total ==="
Reader "select periode, count(*) baris, sum(case when qty<>0 and (hpp_avg=0 or hpp_avg is null) then 1 else 0 end) qty_tanpa_hpp, sum(case when qty<>0 and (nilai=0 or nilai is null) then 1 else 0 end) qty_nilai0, sum(nilai) total_nilai from sinv where periode in ('2026-04-01','2026-05-01','2026-06-01') group by periode order by periode"
Write-Host "`n=== contoh 5 produk: nilai & hpp_avg di SINV 04/01 vs 05/01 vs 06/01 ==="
Reader "select a.stok_id, a.qty q_apr, a.hpp_avg h_apr, m.qty q_mei, m.hpp_avg h_mei, j.qty q_jun, j.hpp_avg h_jun from (select * from sinv where periode='2026-05-01' and qty>1) m left join sinv a on a.stok_id=m.stok_id and a.periode='2026-04-01' left join sinv j on j.stok_id=m.stok_id and j.periode='2026-06-01' where (m.hpp_avg=0 or m.hpp_avg is null) and (j.hpp_avg>0) order by m.qty desc limit 8"
$cn.Close()
