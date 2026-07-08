$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== NETTO_HPP '19' per BULAN (April=ter-closing/rusak; bulan belum-closing = nilai POSTING) ==="
Reader "select datepart(month,a.tgl) bln, count(*) n, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.netto_hpp) as numeric(18,0)) netto_hpp, cast(sum(b.netto) as numeric(18,0)) netto, sum(case when isnull(b.netto_hpp,0)=0 then 1 else 0 end) hpp0 from tstok1 a, tstok2 b where a.bukti_id=b.bukti_id and a.tipe_trans='19' and a.tgl between '2026-01-01' and '2026-12-31' group by datepart(month,a.tgl) order by bln"
Write-Host "`n=== closing_sales & apakah Mei/Juni sudah pernah di-closing (SINV ada) ==="
Reader "select periode, cast(sum(nilai) as numeric(18,0)) tot from sinv where periode in ('2026-06-01','2026-07-01','2026-08-01') group by periode order by periode"
$cn.Close()
