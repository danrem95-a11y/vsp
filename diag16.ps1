# diag16.ps1 - GL NET per BTB = K(voucher=BTB) - D(order_reff=BTB), TGL < 2026-01-01
Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    SAF.BUKTI_ID,
    SAF.VENDOR_ID,
    SAF.CURR_ID,
    SAF.RATE,
    SAF.SALDO_KURS,
    SAF.SALDO_KURS * SAF.RATE   AS IDR_RATE,
    SAF.SALDO                   AS IDR_SALDO,
    ISNULL(GK.GL_K, 0)          AS GL_K,
    ISNULL(GD.GL_D, 0)          AS GL_D,
    ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)  AS GL_NET
FROM SALDO_AWAL_FAKTUR SAF
LEFT JOIN (
    SELECT GG.voucher, SUM(GG.kredit) AS GL_K
    FROM gl_journal GG
    WHERE GG.account_id = '226-001' AND GG.kredit > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.voucher
) GK ON GK.voucher = SAF.BUKTI_ID
LEFT JOIN (
    SELECT GG.order_reff, SUM(GG.debet) AS GL_D
    FROM gl_journal GG
    WHERE GG.account_id = '226-001' AND GG.debet > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.order_reff
) GD ON GD.order_reff = SAF.BUKTI_ID
WHERE SAF.TIPE_TRANS IN (1,2) AND MONTH(SAF.PERIODE) = 1 AND YEAR(SAF.PERIODE) = 2026
  AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
ORDER BY SAF.CURR_ID, SAF.BUKTI_ID
'@

$out = @()
$out += "BUKTI_ID|VENDOR|CURR|RATE|SALDO_KURS|IDR_RATE|IDR_SALDO|GL_K|GL_D|GL_NET|DIFF_vs_RATE|DIFF_vs_SALDO"
try {
    $cmd = $con.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 180
    $r = $cmd.ExecuteReader()
    $tRate=0; $tSaldo=0; $tK=0; $tD=0; $tNet=0
    while ($r.Read()) {
        $idrR  = [decimal]$r["IDR_RATE"]
        $idrS  = [decimal]$r["IDR_SALDO"]
        $glK   = [decimal]$r["GL_K"]
        $glD   = [decimal]$r["GL_D"]
        $glN   = [decimal]$r["GL_NET"]
        $tRate += $idrR; $tSaldo += $idrS; $tK += $glK; $tD += $glD; $tNet += $glN
        $dRate = $glN - $idrR
        $dSald = $glN - $idrS
        $out += "$($r['BUKTI_ID'])|$($r['VENDOR_ID'])|$($r['CURR_ID'])|$($r['RATE'])|$($r['SALDO_KURS'])|$idrR|$idrS|$glK|$glD|$glN|$dRate|$dSald"
    }
    $r.Close()
    $out += "--- TOTAL ---"
    $out += "||||||$tRate|$tSaldo|$tK|$tD|$tNet|$($tNet-$tRate)|$($tNet-$tSaldo)"
    $out += ""
    $out += "SUM(SALDO_KURS*RATE) = $tRate"
    $out += "SUM(SALDO)           = $tSaldo"
    $out += "SUM(GL_NET)          = $tNet"
    $out += "Target GL SA         = 14159923466.61"
    $out += "Selisih GL_NET vs target = $($tNet - 14159923466.61)"
} catch { $out += "ERROR: $_" }
finally { $con.Close() }

$out | Out-File "C:\BTV\debug\diag16_out.txt" -Encoding UTF8
Write-Host "Done. C:\BTV\debug\diag16_out.txt"
