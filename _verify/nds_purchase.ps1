$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "tstok2 (masuk) NDS.005010099 Mei 2026 - qty, harga, netto aktual" @"
select t1.bukti_id, cast(t1.tgl as date) tgl, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty,
  cast(t2.hrg as numeric(18,4)) hrg, cast(t2.netto as numeric(18,4)) netto
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='NDS.005010099' and t1.tgl between '2026-05-01' and '2026-05-31'
order by t1.tgl
"@

Qry "tsales2 (keluar) NDS.005010099 Mei 2026" @"
select s1.bukti_id, cast(s1.tgl as date) tgl, s1.tipe_trans, cast(s2.qty as numeric(18,2)) qty, cast(s2.hpp as numeric(18,4)) hpp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s2.stok_id='NDS.005010099' and s1.tgl between '2026-05-01' and '2026-05-31'
order by s1.tgl
"@

Qry "Rekonsiliasi: netto beli aktual vs delta sinv (16.684.200)" @"
select cast(sum(t2.netto) as numeric(18,2)) total_netto_beli,
  cast(16684200 as numeric(18,2)) delta_sinv_tercatat,
  cast(sum(t2.netto)-16684200 as numeric(18,2)) selisih_rounding
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='NDS.005010099' and t1.tgl between '2026-05-01' and '2026-05-31' and t2.qty>0
"@
$cn.Close()
