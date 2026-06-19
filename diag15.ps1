# diag15.ps1 - Cek GL KREDIT dengan filter TGL < 2026-01-01 untuk 81 invoice
Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

# GL KREDIT with TGL filter - dan breakdown per BTB yang FCY
$sql = @'
SELECT
    SAF.BUKTI_ID,
    SAF.VENDOR_ID,
    SAF.CURR_ID,
    SAF.RATE,
    SAF.SALDO_KURS,
    SAF.SALDO_KURS * SAF.RATE            AS IDR_RATE_ASLI,
    SAF.SALDO                            AS IDR_SALDO,
    GL_PRE.GL_K_PRE,
    GL_PRE.GL_D_PRE,
    (GL_PRE.GL_K_PRE - GL_PRE.GL_D_PRE) AS GL_NET_PRE
FROM SALDO_AWAL_FAKTUR SAF
LEFT JOIN (
    SELECT GG.voucher,
           SUM(CASE WHEN GG.kredit > 0 THEN GG.kredit ELSE 0 END) AS GL_K_PRE,
           SUM(CASE WHEN GG.debet  > 0 THEN GG.debet  ELSE 0 END) AS GL_D_PRE
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.voucher
) GL_PRE ON GL_PRE.voucher = SAF.BUKTI_ID
WHERE SAF.TIPE_TRANS IN (1,2) AND MONTH(SAF.PERIODE) = 1 AND YEAR(SAF.PERIODE) = 2026
  AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
  AND SAF.CURR_ID <> 'IDR'
ORDER BY SAF.CURR_ID, SAF.BUKTI_ID
'@

$out = @()
$out += "=== INVOICE VALUTA ASING - GL NET vs SAF (TGL < 2026-01-01) ==="
$out += "BUKTI_ID|VENDOR|CURR|RATE|SALDO_KURS|IDR_RATE_ASLI|IDR_SALDO|GL_K_PRE|GL_D_PRE|GL_NET_PRE"
try {
    $cmd = $con.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $tK=0; $tD=0; $tNet=0; $tRate=0; $tSaldo=0
    while ($r.Read()) {
        $idr_rate  = [decimal]$r["IDR_RATE_ASLI"]
        $idr_saldo = [decimal]$r["IDR_SALDO"]
        $glK  = if ($r["GL_K_PRE"]   -is [DBNull]) { 0 } else { [decimal]$r["GL_K_PRE"] }
        $glD  = if ($r["GL_D_PRE"]   -is [DBNull]) { 0 } else { [decimal]$r["GL_D_PRE"] }
        $glN  = if ($r["GL_NET_PRE"] -is [DBNull]) { 0 } else { [decimal]$r["GL_NET_PRE"] }
        $tK += $glK; $tD += $glD; $tNet += $glN; $tRate += $idr_rate; $tSaldo += $idr_saldo
        $out += "$($r['BUKTI_ID'])|$($r['VENDOR_ID'])|$($r['CURR_ID'])|$($r['RATE'])|$($r['SALDO_KURS'])|$idr_rate|$idr_saldo|$glK|$glD|$glN"
    }
    $r.Close()
    $out += "--- TOTAL FCY ---"
    $out += "||||||$tRate|$tSaldo|$tK|$tD|$tNet"
    $out += ""
    $out += "SUM(SALDO_KURS*RATE) FCY = $tRate"
    $out += "SUM(SALDO) FCY           = $tSaldo"
    $out += "SUM(GL_K_PRE) FCY        = $tK"
    $out += "SUM(GL_D_PRE) FCY        = $tD"
    $out += "SUM(GL_NET_PRE) FCY      = $tNet"
} catch { $out += "ERROR: $_" }
finally { $con.Close() }

# Also sum total all 81 invoices using SALDO_KURS * RATE
$con2 = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con2.Open()
$sql2 = @'
SELECT
    SUM(SAF.SALDO_KURS * SAF.RATE)  AS TOTAL_IDR_RATE,
    SUM(SAF.SALDO)                  AS TOTAL_IDR_SALDO,
    SUM(SAF.NEW_SALDO)              AS TOTAL_IDR_NEWRATE,
    GL_ALL.GL_K_ALL,
    GL_ALL.GL_D_ALL,
    (GL_ALL.GL_K_ALL - GL_ALL.GL_D_ALL) AS GL_NET_ALL
FROM SALDO_AWAL_FAKTUR SAF,
(
    SELECT
        SUM(CASE WHEN GG.kredit > 0 THEN GG.kredit ELSE 0 END) AS GL_K_ALL,
        SUM(CASE WHEN GG.debet  > 0 THEN GG.debet  ELSE 0 END) AS GL_D_ALL
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.tgl < '2026-01-01'
) GL_ALL
WHERE SAF.TIPE_TRANS IN (1,2) AND MONTH(SAF.PERIODE) = 1 AND YEAR(SAF.PERIODE) = 2026
  AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
'@
try {
    $cmd2 = $con2.CreateCommand(); $cmd2.CommandText = $sql2; $cmd2.CommandTimeout = 120
    $r2 = $cmd2.ExecuteReader()
    if ($r2.Read()) {
        $out += ""
        $out += "=== TOTAL 81 INVOICE (semua mata uang) ==="
        $out += "SUM(SALDO_KURS*RATE)    = $([decimal]$r2['TOTAL_IDR_RATE'])"
        $out += "SUM(SALDO)              = $([decimal]$r2['TOTAL_IDR_SALDO'])"
        $out += "SUM(NEW_SALDO)          = $([decimal]$r2['TOTAL_IDR_NEWRATE'])"
        $out += "GL 226-001 K (TGL<2026) = $([decimal]$r2['GL_K_ALL'])"
        $out += "GL 226-001 D (TGL<2026) = $([decimal]$r2['GL_D_ALL'])"
        $out += "GL 226-001 NET (SA)     = $([decimal]$r2['GL_NET_ALL'])"
        $out += "Target ledger SA        = 14159923466.61"
    }
    $r2.Close()
} catch { $out += "ERROR sql2: $_" }
finally { $con2.Close() }

$out | Out-File "C:\BTV\debug\diag15_out.txt" -Encoding UTF8
Write-Host "Done. C:\BTV\debug\diag15_out.txt"
