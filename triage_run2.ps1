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
$kelas = @"
  case
    when (select count(*) from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
            and t2.stok_id=s2.stok_id and isnull(t2.netto,0)>0 and month(t1.tgl)=month(s1.tgl) and year(t1.tgl)=year(s1.tgl))>0
      then 'A_RECOVERABLE_DIRECT'
    when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=s2.evap)>1
      then 'C_DUPLICATE_IDENTITY'
    when (select count(*) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
            and c2.stok_id=s2.stok_id and c2.evap<>s2.evap and isnull(c2.hpp,0)>0)>0
       or (select count(*) from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id and d2.stok_id=s2.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<s1.tgl)>0
      then 'D_NEED_ACCOUNTING'
    else 'B_DATA_MISSING'
  end
"@

Reader "RINGKASAN FINAL (precedence audit-jujur) + candidate cost model" @"
select kelas, count(*) jumlah, cast(sum(qty) as numeric(18,2)) qty,
   cast(sum(qty*candidate) as numeric(18,2)) potensi_cogs_jika_diterapkan
from (
 select s2.qty, $kelas as kelas,
   isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
      and c2.stok_id=s2.stok_id and isnull(c2.hpp,0)>0),0) as candidate
 $orphan
) x group by kelas order by kelas
"@

Reader "Contoh candidate model-cost per stok (max consout hpp same stok)" @"
select distinct s2.stok_id,
  cast(isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
     and c2.stok_id=s2.stok_id and isnull(c2.hpp,0)>0),0) as numeric(18,2)) candidate_model_hpp
$orphan
order by s2.stok_id
"@

$cn.Close()
