$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($cn,$lbl,$sql){ Write-Host "  -- $lbl --"; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("     "+($a -join " | "))}; if(-not $any){Write-Host "     (kosong)"}; $rd.Close()}catch{Write-Host("     ERR: "+$_.Exception.Message)} }

Write-Host "############ BINGSHAN - faktur 10105250700002 ############"
Show $P "AR_TRANS faktur (prod)" "select left(order_client,18) oc, cust_id, cast(tgl as date) tgl, tipe_trans, cast(ttl_netto as numeric(18,2)) ttl, left(isnull(bukti_reff,''),16) reff from ar_trans where order_client='10105250700002'"
Show $P "GL 103-001 faktur (prod) - debet=faktur kredit=bayar" "select left(voucher,18) voucher, cast(tgl as date) tgl, modul_id, cast(debet as numeric(18,2)) db, cast(kredit as numeric(18,2)) kr, left(ket,26) ket from gl_journal where posting='P' and account_id='103-001' and doc_reff='10105250700002' order by tgl"
Show $P "GL saldo faktur (prod)" "select cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo from gl_journal where posting='P' and account_id='103-001' and doc_reff='10105250700002'"
Show $P "TBYR faktur (PROD)" "select left(t1.voucher,16) voucher, cast(t1.tgl as date) tgl, cast(t2.nilai_bayar_idr as numeric(18,2)) nb from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='10105250700002' order by t1.tgl"
Show $L "TBYR faktur (LOKAL)" "select left(t1.voucher,16) voucher, cast(t1.tgl as date) tgl, cast(t2.nilai_bayar_idr as numeric(18,2)) nb from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='10105250700002' order by t1.tgl"
Show $P "SAF (prod)" "select bukti_id, cast(saldo as numeric(18,2)) saf from SALDO_AWAL_FAKTUR where bukti_id='10105250700002'"
Show $L "SAF (lokal)" "select bukti_id, cast(saldo as numeric(18,2)) saf from SALDO_AWAL_FAKTUR where bukti_id='10105250700002'"

Write-Host "`n############ SUTRISNO - 101RK241100001 ############"
Show $P "AR_TRANS (prod)" "select left(order_client,18) oc, cust_id, cast(tgl as date) tgl, tipe_trans, cast(ttl_netto as numeric(18,2)) ttl, left(isnull(bukti_reff,''),16) reff from ar_trans where order_client='101RK241100001'"
Show $P "GL semua akun voucher 101RK241100001 (prod)" "select account_id, cast(tgl as date) tgl, modul_id, cast(debet as numeric(18,2)) db, cast(kredit as numeric(18,2)) kr, left(ket,26) ket from gl_journal where posting='P' and voucher='101RK241100001' order by account_id"
Show $P "GL 103-001 doc_reff 101RK241100001 saldo (prod)" "select cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo, count(*) n from gl_journal where posting='P' and account_id='103-001' and doc_reff='101RK241100001'"
Show $P "TBYR bukti 101RK241100001 (PROD)" "select left(t1.voucher,16) voucher, cast(t1.tgl as date) tgl, cast(t2.nilai_bayar_idr as numeric(18,2)) nb from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='101RK241100001'"
Show $L "TBYR bukti 101RK241100001 (LOKAL)" "select left(t1.voucher,16) voucher, cast(t1.tgl as date) tgl, cast(t2.nilai_bayar_idr as numeric(18,2)) nb from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='101RK241100001'"
$L.Close(); $P.Close()
