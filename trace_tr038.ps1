$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. TR.038A cons-in '88' (tstok) sample 5 - serial(coa_id), vendor, order, GL?" @"
select top 5 left(t1.bukti_id,16) bukti, left(isnull(t1.order_client,''),16) order_client, t1.vendor_id, left(isnull(t2.coa_id,''),14) serial, cast(t2.netto as numeric(18,2)) netto, cast(t1.tgl as date) tgl,
 (select list(distinct g.account_id) from gl_journal g where g.posting='P' and (g.voucher=t1.bukti_id or g.doc_reff=t1.bukti_id or g.voucher=t1.order_client or g.doc_reff=t1.order_client)) gl_akun
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id='TR.038A' and t1.tipe_trans='88' and t1.tgl>='2025-01-01' order by t1.tgl desc
"@

Show "2. TR.038A JUAL '22' (tsales) sample 5 - serial(evap), cust, order, GL akun?" @"
select top 5 left(s1.bukti_id,16) bukti, left(isnull(s1.order_client,''),16) order_client, s1.cust_id, left(isnull(s2.evap,''),14) serial, cast(s2.hpp*s2.qty as numeric(18,2)) hpp, cast(s2.netto as numeric(18,2)) netto, cast(s1.tgl as date) tgl,
 (select list(distinct g.account_id) from gl_journal g where g.posting='P' and (g.voucher=s1.order_client or g.doc_reff=s1.order_client or g.voucher=s1.bukti_id or g.doc_reff=s1.bukti_id)) gl_akun
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id='TR.038A' and s1.tipe_trans='22' and s1.tgl>='2025-01-01' order by s1.tgl desc
"@

Show "3. TR.038A cons-out '88' (tsales) sample 5 - serial, cust, GL akun?" @"
select top 5 left(s1.bukti_id,16) bukti, left(isnull(s1.order_client,''),16) order_client, s1.cust_id, left(isnull(s2.evap,''),14) serial, cast(s2.netto as numeric(18,2)) netto, cast(s1.tgl as date) tgl,
 (select list(distinct g.account_id) from gl_journal g where g.posting='P' and (g.voucher=s1.order_client or g.doc_reff=s1.order_client or g.voucher=s1.bukti_id or g.doc_reff=s1.bukti_id)) gl_akun
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id='TR.038A' and s1.tipe_trans='88' and s1.tgl>='2025-01-01' order by s1.tgl desc
"@

Show "4. Satu serial ditelusuri: muncul di cons-in '88' DAN cons-out/jual?" @"
select 'tstok88' src, left(t2.coa_id,16) serial, cast(t1.tgl as date) tgl, t1.tipe_trans from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id='TR.038A' and t1.tipe_trans='88' and isnull(t2.coa_id,'')<>''
union all
select 'tsales', left(s2.evap,16), cast(s1.tgl as date), s1.tipe_trans from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id='TR.038A' and s1.tipe_trans in ('22','88') and isnull(s2.evap,'')<>''
order by serial, tgl
"@
$P.Close()
