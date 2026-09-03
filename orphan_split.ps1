$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$cmd=$cn.CreateCommand(); $cmd.CommandTimeout=300
$cmd.CommandText=@"
select jenis, count(*) jumlah, cast(sum(qty) as numeric(18,2)) qty from (
 select isnull(s2.qty,0) qty,
  case
   when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
        and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)=0)
     then 'PUNYA_CONSOUT_HPP0 (sembuh saat refresh)'
   when exists(select 1 from tstok1 w1,tstok2 w2 where w1.bukti_id=w2.bukti_id and w1.tipe_trans='88'
        and w2.stok_id=s2.stok_id and w2.coa_id=s2.evap)
     then 'PUNYA_WIPIN_STOK (sembuh saat refresh)'
   else 'TRUE_ORPHAN (tak ada consout/wip sama sekali)'
  end jenis
 from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
   and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
   and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
        and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
) x group by jenis order by jenis
"@
$rd=$cmd.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" | unit="+$rd[1]+" | qty="+$rd[2]) }; $rd.Close()
$cn.Close()
