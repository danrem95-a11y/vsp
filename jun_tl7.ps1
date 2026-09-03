$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

$b6 = "('10126010200006','10126010200040','10126030200022','10126040200012','10126060200005','10126060200070')"

Qry "1. Header 6 pembelian (tstok1) + vendor + order_client/doc_reff" @"
select left(t1.bukti_id,18) bukti, cast(t1.tgl as date) tgl, t1.vendor_id, left(isnull(s.nama,''),22) vendor, t1.order_client, t1.doc_reff
from tstok1 t1 left join mcstsupp s on s.vendor_id=t1.vendor_id
where t1.bukti_id in $b6 order by t1.tgl
"@

Qry "2. Detail baris (tstok2): qty, satuan, netto, hpp, gudang" @"
select left(t2.bukti_id,18) bukti, cast(t2.qty as numeric(18,2)) qty, t2.satuan, cast(t2.netto as numeric(18,2)) netto, cast(t2.hpp as numeric(18,4)) hpp, t2.gudang_id
from tstok2 t2 where t2.bukti_id in $b6 order by t2.bukti_id
"@

Qry "3. Satuan & konversi item TL.203.0504 (im_produk)" @"
select produk_id, produk_desc, satuan, satuan_beli, isi from im_produk where produk_id='TL.203.0504'
"@

Qry "4. Faktur pembelian asal (ap_trans) utk order_client 6 pembelian" @"
select at.order_client, left(at.bukti_reff,16) faktur, cast(at.tgl as date) tgl, at.curr_id, cast(at.kurs as numeric(18,2)) kurs, cast(at.ttl_netto as numeric(18,2)) ttl_netto, at.tipe_trans
from ap_trans at where at.order_client in (select order_client from tstok1 where bukti_id in $b6) order by at.tgl
"@
$cn.Close()
