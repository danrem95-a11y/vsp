$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Scalar($label,$s){$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{$v=$c.ExecuteScalar();$sw.Stop();Write-Host ("  "+$label+" = "+("{0:N2}" -f [double]$v)+"   ("+$sw.ElapsedMilliseconds+" ms)");return [double]$v}
  catch{$sw.Stop();Write-Host ("  ERR "+$label+": "+$_.Exception.Message);return [double]::NaN}}

$mapAR = "(SELECT m.account_id FROM rekon_account_map m WHERE m.domain='AR' AND m.is_active='Y')"
$mapAP = "(SELECT m.account_id FROM rekon_account_map m WHERE m.domain='AP' AND m.is_active='Y')"

Write-Host "===================== GATE 2 - AR (April 2026) ====================="
$ar_saf = Scalar "AR SAF opening 2026 (anchored)" "SELECT ISNULL(SUM(ROUND(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo WHEN ISNULL(f.new_rate,0) <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate ELSE ISNULL(f.saldo,0) END,2)),0) FROM saldo_awal_faktur f WHERE f.tipe_trans=1 AND YEAR(f.periode)=2026 AND MONTH(f.periode)=1 AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=f.bukti_id AND gj.debet > 0 AND gj.account_id IN $mapAR)"
$ar_inv = Scalar "AR mutasi GLdebet anchored JanApr" "SELECT ISNULL(SUM(gj.debet),0) FROM gl_journal gj WHERE gj.debet > 0 AND gj.account_id IN $mapAR AND gj.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=gj.voucher AND a.order_oke='Y' AND a.tipe_trans IN ('22','32','33','26','36'))"
$ar_adj = Scalar "AR adj PUTIH JanApr" "SELECT ISNULL(SUM(CASE WHEN tp.flag_order=11 THEN ABS(tp.nilai_bayar_idr) WHEN tp.flag_order=1 THEN -ABS(tp.nilai_bayar_idr) ELSE 0 END),0) FROM tbyr2_putih tp WHERE tp.flag_order IN (1,11) AND tp.tgl_bayar BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=tp.bukti_id)"
$ar_byr = Scalar "AR bayar TBYR JanApr" "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id)"
$ar_led = Scalar "AR ledger openingYTD Apr" "SELECT ISNULL((SELECT SUM(b.AmountDebet-b.AmountCredit) FROM gl_balance b WHERE b.AccountCode IN $mapAR AND YEAR(b.Period)=2026),0) + ISNULL((SELECT SUM(j.debet-j.kredit) FROM gl_journal j WHERE j.account_id IN $mapAR AND j.posting='P' AND j.tgl BETWEEN '2026-01-01' AND '2026-04-30'),0)"
$ar_sub = $ar_saf + $ar_inv + $ar_adj - $ar_byr
Write-Host ("  AR SUBLEDGER = {0:N2}" -f $ar_sub)
Write-Host ("  AR LEDGER    = {0:N2}" -f $ar_led)
$ar_st = "FAIL"; if([math]::Abs($ar_sub-$ar_led) -le 10){$ar_st="PASS"}
Write-Host ("  AR SELISIH   = {0:N2}  status={1}" -f ($ar_sub-$ar_led), $ar_st)

Write-Host "===================== GATE 2 - AP (April 2026) ====================="
$ap_saf = Scalar "AP SAF opening 2026 (anchored)" "SELECT ISNULL(SUM(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo WHEN ISNULL(f.new_rate,0) <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate ELSE ISNULL(f.saldo,0) END),0) FROM saldo_awal_faktur f WHERE f.tipe_trans IN (1,2) AND YEAR(f.periode)=2026 AND MONTH(f.periode)=1 AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=f.bukti_id AND gj.kredit > 0 AND gj.account_id IN $mapAP)"
$ap_inv = Scalar "AP mutasi AP_TRANS JanApr anchored" "SELECT ISNULL(SUM(CASE WHEN p.tipe_trans='05' THEN p.ttl_netto ELSE (CASE WHEN p.tipe_trans IN ('02','06','16') THEN p.ttl_netto WHEN p.tipe_trans='12' THEN -ABS(p.ttl_netto) ELSE 0 END)*ISNULL(p.kurs,1) END),0) FROM ap_trans p WHERE p.order_oke='Y' AND p.tipe_trans IN ('02','05','12','06','16') AND p.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=p.order_client AND gj.kredit > 0 AND gj.account_id IN $mapAP)"
$ap_adj = Scalar "AP adj PUTIH JanApr" "SELECT ISNULL(SUM(CASE WHEN tp.flag_order NOT IN (2,22) THEN ABS(tp.nilai_bayar_idr) ELSE -ABS(tp.nilai_bayar_idr) END),0) FROM tbyr2_putih tp WHERE tp.tgl_bayar BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=tp.bukti_id)"
$ap_byr = Scalar "AP bayar TBYR JanApr" "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id)"
$ap_led = Scalar "AP ledger openingYTD Apr" "SELECT ISNULL((SELECT SUM(b.AmountDebet-b.AmountCredit) FROM gl_balance b WHERE b.AccountCode IN $mapAP AND YEAR(b.Period)=2026),0) + ISNULL((SELECT SUM(j.debet-j.kredit) FROM gl_journal j WHERE j.account_id IN $mapAP AND j.posting='P' AND j.tgl BETWEEN '2026-01-01' AND '2026-04-30'),0)"
$ap_sub = $ap_saf + $ap_inv + $ap_adj - $ap_byr
Write-Host ("  AP SUBLEDGER    = {0:N2}" -f $ap_sub)
Write-Host ("  AP LEDGER (net) = {0:N2}  abs={1:N2}" -f $ap_led, [math]::Abs($ap_led))
$ap_st = "FAIL"; if([math]::Abs($ap_sub-[math]::Abs($ap_led)) -le 10){$ap_st="PASS"}
Write-Host ("  AP SELISIH (sub-absled) = {0:N2}  status={1}" -f ($ap_sub-[math]::Abs($ap_led)), $ap_st)
$cn.Close()
