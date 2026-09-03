$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== FULL gl_journal voucher 10203260600055 ==="
Reader @"
select account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, posting, tgl, left(ket,40) ket, doc_reff
from gl_journal where voucher='10203260600055' order by urut
"@

Write-Host "`n=== tstok (header+detail) utk bukti_id ATAU order_client = 10203260600055 (SEMUA tipe/status) ==="
Reader @"
select t1.bukti_id, t1.order_client, t1.tipe_trans, t1.order_oke, t1.tgl, t2.stok_id, cast(t2.netto as numeric(18,2)) netto, t2.qty
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t1.bukti_id='10203260600055' or t1.order_client='10203260600055'
order by t1.tgl
"@

Write-Host "`n=== Referensi 'PT SENTRAS BOX' consout tsales88 (101260600040?) ==="
Reader @"
select s1.bukti_id, s1.order_client, s1.tipe_trans, s1.order_oke, s1.tgl, s2.stok_id, cast(s2.qty as numeric(18,2)) qty, cast(s2.hpp as numeric(18,2)) hpp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.bukti_id='101260600040' or s1.order_client='101260600040'
order by s1.tgl
"@

Write-Host "`n=== Adakah tstok88 utk order_client 10203260600055 di BULAN LAIN (nyangkut)? ==="
Reader @"
select t1.bukti_id, t1.order_client, t1.tipe_trans, t1.order_oke, t1.tgl
from tstok1 t1 where t1.order_client='10203260600055' or t1.bukti_id like '%260600055'
order by t1.tgl
"@

$cn.Close()
