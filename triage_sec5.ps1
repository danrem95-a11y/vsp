$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=300
$c.CommandText=@"
select x.kelas, count(*) as jumlah_unit, cast(sum(x.qty) as numeric(18,2)) as total_qty,
       cast(sum(x.qty*x.candidate_hpp) as numeric(18,2)) as potensi_cogs
from (
   select o.stok_id, o.qty,
     isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
            and c1.tipe_trans='88' and c2.stok_id=o.stok_id and isnull(c2.hpp,0)>0),0) as candidate_hpp,
     case
       when exists(select 1 from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
                    and t2.stok_id=o.stok_id and isnull(t2.netto,0)>0
                    and month(t1.tgl)=month(o.tgl_jual) and year(t1.tgl)=year(o.tgl_jual)) then 'A_RECOVERABLE'
       when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=o.evap) > 1 then 'C_DUPLICATE_IDENTITY'
       when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                    and c2.stok_id=o.stok_id and c2.evap<>o.evap and isnull(c2.hpp,0)>0)
         or exists(select 1 from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id
                    and d2.stok_id=o.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<o.tgl_jual) then 'D_NEED_ACCOUNTING_DECISION'
       else 'B_DATA_MISSING'
     end as kelas
   from (
      select s1.tgl tgl_jual, s1.bukti_id, s2.stok_id, isnull(s2.evap,'') evap, isnull(s2.qty,0) qty
      from tsales1 s1, tsales2 s2
      where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22'
        and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
        and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
        and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
             and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
   ) o
) x
group by x.kelas order by x.kelas
"@
try{ $rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" | unit="+$rd[1]+" | qty="+$rd[2]+" | potensi_cogs="+$rd[3]) }; $rd.Close() }catch{ Write-Host ("ERR: "+$_.Exception.Message) }
$cn.Close()
