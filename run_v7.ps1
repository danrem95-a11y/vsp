$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

$aprsub = "(select t2.stok_id sid, sum(abs(t2.qty)) qty19 from TSTOK1 t1,TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-04-01' and '2026-04-30' group by t2.stok_id) a"
$ratioExpr = "(case when abs(sv.qty)<0.005 then 999999999 else isnull(a.qty19,0)/abs(sv.qty) end)"

Write-Host "===== QUERY 1 : semua hpp_avg negatif, silang ratio April ====="
Reader ("select sv.stok_id, sv.periode, cast(sv.hpp_avg as numeric(18,2)) hpp_avg, cast(sv.qty as numeric(18,2)) qty_periode, cast(isnull(a.qty19,0) as numeric(18,2)) qty19_apr, cast($ratioExpr as numeric(18,2)) ratio from SINV sv left outer join $aprsub on a.sid=sv.stok_id where sv.hpp_avg < 0 order by sv.periode, sv.stok_id")

Write-Host "===== QUERY 1b : uji necessity - berapa hpp_avg<0 yang ratio <= 1 ====="
Reader ("select count(*) n_total_neg, sum(case when $ratioExpr <= 1 then 1 else 0 end) n_ratio_le_1 from SINV sv left outer join $aprsub on a.sid=sv.stok_id where sv.hpp_avg < 0")

Write-Host "===== QUERY 2 : batas temporal - hpp_avg negatif per periode ====="
Reader ("select periode, count(*) n_neg, cast(min(hpp_avg) as numeric(18,2)) min_hpp, cast(max(hpp_avg) as numeric(18,2)) max_hpp from SINV where hpp_avg < 0 group by periode order by periode")
$cn.Close()
