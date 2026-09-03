$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$b6 = "('10126010200006','10126010200040','10126030200022','10126040200012','10126060200005','10126060200070')"

Qry "1. Konfigurasi satuan TL.203.0504" @"
select produk_id, produk_desc, sat_kecil, sat_sedang, sat_besar, isi_sedang, isi_besar, group_unit from im_produk where produk_id='TL.203.0504'
"@

Qry "2. 6 pembelian: qty per satuan + harga + netto" @"
select left(t2.bukti_id,16) bukti, cast(t2.qty as numeric(18,2)) qty_stok,
 cast(t2.qty1 as numeric(18,2)) q1, cast(t2.qty2 as numeric(18,2)) q2, cast(t2.qty3 as numeric(18,2)) q3,
 t2.sat_kecil sk, t2.sat_sedang ss, t2.sat_besar sb,
 cast(t2.hrg_kecil as numeric(18,2)) hrg_kecil, cast(t2.hrg_besar as numeric(18,2)) hrg_besar,
 cast(t2.netto as numeric(18,2)) netto
from tstok2 t2 where t2.bukti_id in $b6 order by t2.bukti_id
"@

Qry "3. Isi konversi (isi_besar/isi_sedang) di baris pembelian" @"
select left(bukti_id,16) bukti, cast(isi_besar as numeric(18,2)) isi_besar, cast(isi_sedang as numeric(18,2)) isi_sedang, cast(qty as numeric(18,2)) qty
from tstok2 where bukti_id in $b6 order by bukti_id
"@
$cn.Close()
