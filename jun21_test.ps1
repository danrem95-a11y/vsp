$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

# Ekspresi 'hpp efektif' PERSIS seperti yang akan dipasang di f_insert_cons_in
# (uji sintaks + korektnes + regresi) atas SEMUA penjualan EVAP 2026.
Write-Host "=== REGRESI: jumlah baris berubah, dan apakah ada baris hpp_old>0 yg ikut berubah (harus 0) ==="
Reader @"
select
  count(*) total_evap_jual,
  sum(case when new_hpp <> old_hpp then 1 else 0 end) berubah,
  sum(case when new_hpp <> old_hpp and old_hpp > 0 then 1 else 0 end) regresi_hpp_positif_berubah
from (
  select isnull(b.hpp,0) old_hpp,
    (case when isnull(b.hpp,0)>0 then b.hpp
          else isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2
                        where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                          and c2.stok_id=b.stok_id and c2.evap=b.evap
                          and isnull(c2.hpp,0)>0 and c1.tgl<=a.tgl),0) end) new_hpp
  from tsales1 a, tsales2 b
  where a.bukti_id=b.bukti_id and a.tipe_trans in ('22','88') and isnull(b.evap,'')<>''
    and a.tgl>='2026-01-01' and a.tgl<'2027-01-01' and a.order_oke='Y'
) x
"@

Write-Host "`n=== Baris yang BERUBAH (harus semua old=0, new=cost WIP-out) ==="
Reader @"
select a.tgl, b.stok_id, b.evap, a.bukti_id,
  cast(isnull(b.hpp,0) as numeric(18,2)) old_hpp,
  cast((case when isnull(b.hpp,0)>0 then b.hpp
        else isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2
                      where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                        and c2.stok_id=b.stok_id and c2.evap=b.evap
                        and isnull(c2.hpp,0)>0 and c1.tgl<=a.tgl),0) end) as numeric(18,2)) new_hpp
from tsales1 a, tsales2 b
where a.bukti_id=b.bukti_id and a.tipe_trans in ('22','88') and isnull(b.evap,'')<>''
  and a.tgl>='2026-01-01' and a.tgl<'2027-01-01' and a.order_oke='Y'
  and isnull(b.hpp,0) <> (case when isnull(b.hpp,0)>0 then b.hpp
        else isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2
                      where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                        and c2.stok_id=b.stok_id and c2.evap=b.evap
                        and isnull(c2.hpp,0)>0 and c1.tgl<=a.tgl),0) end)
order by a.tgl
"@

$cn.Close()
