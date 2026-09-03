$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Payment voucher 100310126070108 - detail GL (voucher_manual, cust_id, doc_reff)" @"
select voucher, urut, voucher_manual, cust_id, doc_reff, order_reff, account_id,
  cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, left(isnull(ket,''),50) ket, modul_id
from gl_journal where voucher='100310126070108' order by urut
"@

Qry "TBYR pembayaran yg memuat 585016583766771 (faktur yg dibayar)" @"
select t1.voucher, t1.tgl, t1.flag_bayar, t2.bukti_id, cast(t2.nilai_bayar_idr as numeric(18,2)) nilai, t2.voucher voc2
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.voucher_manual like '%585016583766771%' or t2.bukti_id like '%585016583766771%'
   or t1.voucher='100310126070108'
"@

Qry "Cari 585016583766771 di ap_trans (faktur beli)" @"
select order_client, vendor_id, cast(tgl as date) tgl, bukti_reff, no_faktur
from ap_trans where order_client like '%585016%' or bukti_reff like '%585016583766771%' or no_faktur like '%585016583766771%'
"@

Qry "Cari 585016583766771 di tstok1 (penerimaan barang/BTB)" @"
select bukti_id, cast(tgl as date) tgl, tipe_trans, no_faktur, order_oke
from tstok1 where no_faktur like '%585016583766771%' or bukti_id like '%585016583766771%'
"@
$cn.Close()
