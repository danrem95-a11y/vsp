$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
function T($label, $q) {
    $c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 600
    $t0 = Get-Date
    $n = 0
    $r = $c.ExecuteReader(); while ($r.Read()) { $n++ }; $r.Close()
    $sec = (New-TimeSpan $t0 (Get-Date)).TotalSeconds
    "{0,-22} rows={1,-6} sec={2:F2}" -f $label, $n, $sec
}
$t1 = "'2026-03-01'"; $t2 = "'2026-03-31'"
$ys = "DATEADD(day, 1 - DATEPART(dayofyear, $t1), $t1)"
$tend = "DATEADD(day, 1, $t2)"

T 'JANGKAR-AP-now' @"
SELECT AT.ORDER_CLIENT FROM AP_TRANS AT
WHERE AT.TIPE_TRANS IN ('02','05','06','12','16')
  AND AT.TGL >= $t1 AND AT.TGL < $tend
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=AT.ORDER_CLIENT AND GJ.account_id='226-001' AND GJ.kredit>0)
"@

T 'JANGKAR-SAF' @"
SELECT SAF2.BUKTI_ID FROM SALDO_AWAL_FAKTUR SAF2
WHERE SAF2.TIPE_TRANS IN (1,2)
  AND SAF2.PERIODE >= $ys AND SAF2.PERIODE < DATEADD(month,1,$ys)
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=SAF2.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)
"@

T 'JANGKAR-AP-prior' @"
SELECT AT2.ORDER_CLIENT FROM AP_TRANS AT2
WHERE AT2.TIPE_TRANS IN ('02','05','06','12','16')
  AND AT2.TGL >= $ys AND AT2.TGL < $t1
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=AT2.ORDER_CLIENT AND GJ.account_id='226-001' AND GJ.kredit>0)
"@

T 'OPN_HIST' @"
SELECT SAF_O.BUKTI_ID, SUM(ISNULL(SAF_O.SALDO,0))
FROM SALDO_AWAL_FAKTUR SAF_O
WHERE SAF_O.TIPE_TRANS IN (1,2)
  AND SAF_O.PERIODE >= $ys AND SAF_O.PERIODE < DATEADD(month,1,$ys)
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=SAF_O.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)
GROUP BY SAF_O.BUKTI_ID
"@

T 'MUT_ALL' @"
SELECT P.ORDER_CLIENT, SUM(P.TTL_NETTO)
FROM AP_TRANS P
WHERE P.TGL >= $ys AND P.TGL < $tend
  AND P.ORDER_OKE='Y'
  AND P.TIPE_TRANS IN ('02','05','12','06','16')
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=P.ORDER_CLIENT AND GJ.account_id='226-001' AND GJ.kredit>0)
GROUP BY P.ORDER_CLIENT
"@

T 'ADJ_ALL' @"
SELECT TP.BUKTI_ID, SUM(TP.NILAI_BAYAR)
FROM TBYR2_PUTIH TP
WHERE TP.TGL_BAYAR >= $ys AND TP.TGL_BAYAR < $tend
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=TP.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)
GROUP BY TP.BUKTI_ID
"@

T 'BYR_ALL' @"
SELECT T2.BUKTI_ID, SUM(T2.NILAI_BAYAR)
FROM TBYR1 T1
INNER JOIN TBYR2 T2 ON T2.VOUCHER=T1.VOUCHER
WHERE T1.FLAG_BAYAR IN (1,2)
  AND T1.TGL >= $ys AND T1.TGL < $tend
  AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=T2.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)
GROUP BY T2.BUKTI_ID
"@

$conn.Close()
