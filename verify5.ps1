$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== 12 produk dgn penurunan nilai terbesar Apr->Mei (qty stabil?) ==="
Reader "select top 12 m.stok_id, a.qty q_apr, cast(a.hpp_avg as numeric(18,2)) h_apr, cast(a.nilai as numeric(18,0)) n_apr, m.qty q_mei, cast(m.hpp_avg as numeric(18,2)) h_mei, cast(m.nilai as numeric(18,0)) n_mei, cast(j.hpp_avg as numeric(18,2)) h_jun from sinv m join sinv a on a.stok_id=m.stok_id and a.periode='2026-04-01' left join sinv j on j.stok_id=m.stok_id and j.periode='2026-06-01' where m.periode='2026-05-01' order by (a.nilai - m.nilai) desc"
Write-Host "`n=== total: SINV Apr vs Mei, selisih ==="
Reader "select cast(sum(a.nilai) as numeric(18,0)) apr, cast(sum(m.nilai) as numeric(18,0)) mei, cast(sum(a.nilai)-sum(m.nilai) as numeric(18,0)) turun from sinv m join sinv a on a.stok_id=m.stok_id and a.periode='2026-04-01' where m.periode='2026-05-01'"
$cn.Close()
