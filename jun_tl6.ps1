$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Sejarah sinv TL.203.0504 2026 (qty, nilai, hpp_avg = moving-avg per bulan)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,4)) hpp_avg
from sinv where stok_id='TL.203.0504' and periode>='2026-01-01' order by periode
"@

Qry "2. Pembelian (tstok 02) TL.203.0504 - biaya beli asli" @"
select cast(t1.tgl as date) tgl, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty, cast(t2.netto as numeric(18,2)) netto, cast(t2.hpp as numeric(18,4)) hpp_unit, left(t1.bukti_id,18) bukti
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='TL.203.0504' and t1.tipe_trans='02' and t1.tgl>='2026-01-01' order by t1.tgl
"@

Qry "3. Mutasi (09/19) TL.203.0504 Juni - HPP, gudang, netto" @"
select cast(t1.tgl as date) tgl, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty, cast(t2.hpp as numeric(18,4)) hpp_unit, cast(t2.netto as numeric(18,2)) netto, t2.gudang_id, left(t1.bukti_id,18) bukti
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='TL.203.0504' and t1.tipe_trans in ('09','19') and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' order by t1.tgl, t1.tipe_trans
"@

Qry "4. Deskripsi produk TL.203.0504" "select produk_id, produk_desc, group_product from im_produk where produk_id='TL.203.0504'"
$cn.Close()
