$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== 5 kasus: sumber PER-SERIAL (fix skrg) vs 'KALKULASI TERAKHIR produk' (ide Pak Wira) ==="
Reader @"
select s2.stok_id, s2.evap serial, s1.tgl,
  cast((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
          and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0 and c1.tgl<=s1.tgl) as numeric(18,2)) v_perserial,
  cast((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans in ('22','88')
          and c2.stok_id=s2.stok_id and isnull(c2.hpp,0)>0 and c1.tgl<s1.tgl) as numeric(18,2)) v_lastcalc_produk,
  (select max(c1.tgl) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans in ('22','88')
          and c2.stok_id=s2.stok_id and isnull(c2.hpp,0)>0 and c1.tgl<s1.tgl) tgl_kalk_terakhir
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','88') and s1.order_oke='Y' and isnull(s2.hpp,0)=0 and s2.qty>0 and isnull(s2.evap,'')<>''
  and s1.tgl>='2026-01-01' and s1.tgl<'2027-01-01'
  and exists (select 1 from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x1.tipe_trans='88' and x2.stok_id=s2.stok_id and x2.evap=s2.evap and isnull(x2.hpp,0)>0 and x1.tgl<s1.tgl)
order by s1.tgl
"@

$cn.Close()
