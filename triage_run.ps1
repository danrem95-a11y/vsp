$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host ("  ERR: "+$_.Exception.Message)} }

$orphan = @"
from tsales1 s1, tsales2 s2
where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
  and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
  and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
       and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
"@

Reader "1. RINGKASAN KLASIFIKASI 29 ORPHAN" @"
select kelas, count(*) jumlah, cast(sum(qty) as numeric(18,2)) qty from (
 select s2.qty,
  case
    when (select count(*) from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
            and t2.stok_id=s2.stok_id and isnull(t2.netto,0)>0 and month(t1.tgl)=month(s1.tgl) and year(t1.tgl)=year(s1.tgl))>0
      then 'A_RECOVERABLE_PURCHASE'
    when (select count(*) from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id
            and d2.stok_id=s2.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<s1.tgl)>0
      then 'A_RECOVERABLE_PRIORHPP'
    when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=s2.evap)>1
      then 'C_DUPLICATE_IDENTITY'
    when (select count(*) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
            and c2.stok_id=s2.stok_id and c2.evap<>s2.evap and isnull(c2.hpp,0)>0)>0
      then 'D_NEED_ACCOUNTING'
    else 'B_DATA_MISSING'
  end as kelas
 $orphan
) x group by kelas order by kelas
"@

Reader "2. DETAIL 29 ORPHAN + sinyal sumber cost" @"
select s1.tgl jual_tgl, s1.bukti_id, s2.stok_id, s2.evap, cast(s2.qty as numeric(18,2)) qty,
  (select count(*) from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
     and t2.stok_id=s2.stok_id and isnull(t2.netto,0)>0 and month(t1.tgl)=month(s1.tgl) and year(t1.tgl)=year(s1.tgl)) c_beli_sebulan,
  (select count(*) from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id and d2.stok_id=s2.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<s1.tgl) d_prior_hpp,
  (select count(*) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap<>s2.evap and isnull(c2.hpp,0)>0) b_consout_diffevap,
  (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=s2.evap) evap_n_stok
$orphan
order by s2.stok_id, s1.tgl
"@

$cn.Close()
