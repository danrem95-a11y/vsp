$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function S($s){$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s;return [double]$c.ExecuteScalar()}
function Tbl($label,$s){Write-Host $label;$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("   "+($l -join " | "))};$rd.Close()}

Write-Host "===== (a) AR: TBYR bayar per flag_bayar (anchored) vs CI GL ====="
Tbl "  TBYR AR bayar per flag_bayar (Jan-Apr, anchored ke ar_trans):" "SELECT t1.flag_bayar, count(*) n, cast(sum(ISNULL(t2.nilai_bayar_idr,0)) as numeric(18,2)) bayar FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id) GROUP BY t1.flag_bayar ORDER BY t1.flag_bayar"
$ci = S "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE account_id='103-001' AND posting='P' AND modul_id='CI' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$tb12 = S "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id)"
Write-Host ("  CI GL total = {0:N2}   TBYR(1,2) = {1:N2}   gap = {2:N2}" -f $ci,$tb12,($tb12-$ci))
# apakah gap = TBYR yg voucher-pembayarannya TIDAK punya jurnal CI di GL?
$tb_noci = S "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id) AND NOT EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=t1.voucher AND gj.account_id='103-001' AND gj.kredit>0)"
Write-Host ("  TBYR tanpa jurnal CI (voucher bayar tak ada di GL 103-001) = {0:N2}" -f $tb_noci)

Write-Host ""
Write-Host "===== (b) AP: ukur GL 226-001 + 226-006 bersama + split flag ====="
$ap_open2 = S "SELECT ISNULL(SUM(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode IN ('226-001','226-006') AND YEAR(Period)=2026"
$ap_kre2  = S "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE account_id IN ('226-001','226-006') AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ap_deb2  = S "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE account_id IN ('226-001','226-006') AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ap_glbal2 = $ap_open2 + $ap_deb2 - $ap_kre2
Write-Host ("  GL 226-001+006: open={0:N2}  debet={1:N2}  kredit={2:N2}  bal_net={3:N2}  abs={4:N2}" -f $ap_open2,$ap_deb2,$ap_kre2,$ap_glbal2,[math]::Abs($ap_glbal2))
Write-Host ("  AP subledger(report) = 8,238,241,410.02   gap(sub - |GLbal|) = {0:N2}" -f (8238241410.02-[math]::Abs($ap_glbal2)))
Tbl "  TBYR AP bayar per flag_bayar (Jan-Apr, anchored ke ap_trans):" "SELECT t1.flag_bayar, count(*) n, cast(sum(ISNULL(t2.nilai_bayar_idr,0)) as numeric(18,2)) bayar FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id) GROUP BY t1.flag_bayar ORDER BY t1.flag_bayar"
$co2 = S "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE account_id IN ('226-001','226-006') AND posting='P' AND modul_id='CO' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$tbap = S "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id AND EXISTS(SELECT 1 FROM gl_journal g3 WHERE g3.voucher=p.order_client AND g3.kredit>0 AND g3.account_id IN ('226-001','226-006')))"
Write-Host ("  CO GL(226-001+006) = {0:N2}   TBYR AP(anchored) = {1:N2}   gap = {2:N2}" -f $co2,$tbap,($tbap-$co2))
$cn.Close()
