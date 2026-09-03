$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=800; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "TR.911A - WIP-Out '88' (tsales) Maret" @"
select s1.bukti_id, cast(s1.tgl as date) tgl, s1.tipe_trans, s2.evap serial, cast(s2.qty as numeric(18,2)) qty, cast(s2.hpp as numeric(18,2)) hpp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='88' and s2.stok_id='TR.911A' and s1.tgl between '2026-03-01' and '2026-03-31'
order by s1.tgl
"@

Qry "TR.911A - WIP-In '88' (tstok) semua (pasangan konsinyasi)" @"
select t1.bukti_id, cast(t1.tgl as date) tgl, t2.coa_id serial, cast(t2.qty as numeric(18,2)) qty, cast(t2.hpp as numeric(18,2)) hpp
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t1.tipe_trans='88' and t2.stok_id='TR.911A' order by t1.tgl
"@

Qry "TR.911A - sinv sekitar Feb-Apr (qty/nilai/hpp_avg)" @"
select cast(periode as date) periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,4)) hpp_avg
from sinv where stok_id='TR.911A' and periode in ('2026-02-01','2026-03-01','2026-04-01') order by periode
"@

Qry "TR.911A - apakah WIP-Out ini punya pasangan WIP-In? (outstanding?)" @"
select s2.evap serial, cast(s2.hpp as numeric(18,2)) hpp_out,
  (select count(*) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id='TR.911A' and isnull(t2.coa_id,'')=s2.evap) ada_wipin
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='88' and s2.stok_id='TR.911A' and s1.tgl between '2026-03-01' and '2026-03-31'
"@

Qry "INV-03 outstanding WIP-Out vs GL 102-020 @ 2026-03-31 (clean)" @"
select cast((select sum(isnull(s2.hpp,0)*isnull(s2.qty,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
        where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-03-31'
        and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-03-31')) as numeric(20,2)) outstanding_wipout,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode='102-020' and period='2026-01-01')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-020' and tgl between '2026-01-01' and '2026-03-31') as numeric(20,2)) gl_102020
"@
$cn.Close()
