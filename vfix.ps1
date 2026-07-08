$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== April '19': mutasi_out RUSAK vs TERKOREKSI (avg awal SINV 04/01 x qty) ==="
Reader @"
select
  cast(sum(abs(b.netto_hpp)) as numeric(18,0)) as current_mutout_abs,
  cast(sum(b.qty * isnull(s.hpp_avg,0)) as numeric(18,0)) as corrected_nh_signed,
  cast(sum(abs(b.qty * isnull(s.hpp_avg,0))) as numeric(18,0)) as corrected_mutout_abs
from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id
left join sinv s on s.stok_id=b.stok_id and s.periode='2026-04-01'
where a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30'
"@
Write-Host "`n=== per produk rusak: netto_hpp current vs terkoreksi ==="
Reader @"
select b.stok_id, cast(sum(b.qty) as numeric(18,2)) qty, cast(max(s.hpp_avg) as numeric(18,2)) avg_awal,
  cast(sum(b.netto_hpp) as numeric(18,0)) current_nh, cast(sum(b.qty*isnull(s.hpp_avg,0)) as numeric(18,0)) corrected_nh
from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id
left join sinv s on s.stok_id=b.stok_id and s.periode='2026-04-01'
where a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30'
  and b.stok_id in ('LC.12.0012','LF.05.0002','TL.107-0334')
group by b.stok_id
"@
$cn.Close()
