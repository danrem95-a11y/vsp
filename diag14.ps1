# diag14.ps1 - Investigasi kolom SAF untuk 81 invoice 226-001 Jan 2026
Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

# Bandingkan semua formula SAF vs GL KREDIT per invoice
$sql = @'
SELECT
    SAF.BUKTI_ID,
    SAF.VENDOR_ID,
    SAF.CURR_ID,
    SAF.RATE,
    SAF.NEW_RATE,
    SAF.SALDO,
    SAF.SALDO_KURS,
    SAF.NEW_SALDO,
    SAF.NEW_SALDO_KURS,
    SAF.SALDO_KURS * SAF.RATE                  AS KURS_X_RATE,
    GL.GL_KREDIT
FROM SALDO_AWAL_FAKTUR SAF
LEFT JOIN (
    SELECT GG.voucher, SUM(GG.kredit) AS GL_KREDIT
    FROM gl_journal GG
    WHERE GG.account_id = '226-001' AND GG.kredit > 0
    GROUP BY GG.voucher
) GL ON GL.voucher = SAF.BUKTI_ID
WHERE SAF.TIPE_TRANS IN (1,2) AND MONTH(SAF.PERIODE) = 1 AND YEAR(SAF.PERIODE) = 2026
  AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
ORDER BY SAF.CURR_ID, SAF.BUKTI_ID
'@

$out = @()
$out += "BUKTI_ID|VENDOR|CURR|RATE|NEW_RATE|SALDO|SALDO_KURS|NEW_SALDO|NEW_SALDO_KURS|KURS_X_RATE|GL_KREDIT"
try {
    $cmd = $con.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $totSaldo=0; $totNew=0; $totKurs=0; $totGL=0; $totSaldoKurs=0; $totNewKurs=0
    while ($r.Read()) {
        $saldo     = [decimal]$r["SALDO"]
        $saldoKurs = [decimal]$r["SALDO_KURS"]
        $newSaldo  = [decimal]$r["NEW_SALDO"]
        $newKurs   = [decimal]$r["NEW_SALDO_KURS"]
        $kursRate  = [decimal]$r["KURS_X_RATE"]
        $gl        = if ($r["GL_KREDIT"] -is [DBNull]) { 0 } else { [decimal]$r["GL_KREDIT"] }
        $totSaldo += $saldo; $totNew += $newSaldo; $totKurs += $kursRate
        $totGL += $gl; $totSaldoKurs += $saldoKurs; $totNewKurs += $newKurs
        $out += "$($r['BUKTI_ID'])|$($r['VENDOR_ID'])|$($r['CURR_ID'])|$($r['RATE'])|$($r['NEW_RATE'])|$saldo|$saldoKurs|$newSaldo|$newKurs|$kursRate|$gl"
    }
    $r.Close()
    $out += "--- TOTAL ---"
    $out += "TOTAL|||||$totSaldo|$totSaldoKurs|$totNew|$totNewKurs|$totKurs|$totGL"
    $out += ""
    $out += "SUM(SALDO)         = $totSaldo"
    $out += "SUM(NEW_SALDO)     = $totNew"
    $out += "SUM(SALDO_KURS*RATE)= $totKurs"
    $out += "SUM(GL_KREDIT)     = $totGL"
    $out += "Target GL SA       = 14159923466.61"
} catch { $out += "ERROR: $_" }
finally { $con.Close() }

$out | Out-File "C:\BTV\debug\diag14_out.txt" -Encoding UTF8
Write-Host "Done. C:\BTV\debug\diag14_out.txt"
