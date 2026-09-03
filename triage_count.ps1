$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=300
$c.CommandText=@"
select kelas, count(*) jumlah from (
 select
  case
    when (select count(*) from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
            and t2.stok_id=s2.stok_id and isnull(t2.netto,0)>0 and month(t1.tgl)=month(s1.tgl) and year(t1.tgl)=year(s1.tgl))>0
      then 'A_RECOVERABLE_DIRECT'
    when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=s2.evap)>1
      then 'C_DUPLICATE_IDENTITY'
    when (select count(*) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
            and c2.stok_id=s2.stok_id and c2.evap<>s2.evap and isnull(c2.hpp,0)>0)>0
      then 'D_NEED_ACCOUNTING'
    else 'B_DATA_MISSING'
  end as kelas
 from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
   and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
   and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
        and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
) x group by kelas order by kelas
"@
$rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" = "+$rd[1]) }; $rd.Close()
$cn.Close()
