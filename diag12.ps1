$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Verify GL 226-001 total balance before Jan 1 2026 (the authoritative SA)
$cmd.CommandText = @"
SELECT SUM(kredit) AS TOTAL_K, SUM(debet) AS TOTAL_D,
       SUM(kredit) - SUM(debet) AS GL_SALDO_AWAL
FROM gl_journal
WHERE account_id = '226-001' AND tgl < '2026-01-01'
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL 226-001 SALDO AWAL VIA gl_journal ==="
while($r.Read()){ $lines += "GL_K=$([string]::Format('{0:N2}',[double]$r['TOTAL_K']))  GL_D=$([string]::Format('{0:N2}',[double]$r['TOTAL_D']))  GL_SA=$([string]::Format('{0:N2}',[double]$r['GL_SALDO_AWAL']))" }
$r.Close()

# Compute GL-based SA per BTB using ORDER_REFF for debets
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO AS SAF_SA,
       SUM(CASE WHEN GK.kredit > 0 THEN GK.kredit ELSE 0 END) AS GL_K,
       SUM(CASE WHEN GD.debet > 0 THEN GD.debet ELSE 0 END) AS GL_D_ORDERREF,
       SUM(CASE WHEN GK.kredit > 0 THEN GK.kredit ELSE 0 END)
         - SUM(CASE WHEN GD.debet > 0 THEN GD.debet ELSE 0 END) AS GL_NET
FROM SALDO_AWAL_FAKTUR S
JOIN gl_journal GK ON GK.voucher = S.BUKTI_ID 
                  AND GK.account_id = '226-001' 
                  AND GK.kredit > 0
                  AND GK.tgl < '2026-01-01'
LEFT JOIN gl_journal GD ON GD.order_reff = S.BUKTI_ID 
                       AND GD.account_id = '226-001' 
                       AND GD.debet > 0
                       AND GD.tgl < '2026-01-01'
WHERE S.TIPE_TRANS = 2 AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
GROUP BY S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO
ORDER BY S.NEW_SALDO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL-BASED SA PER BTB (ORDER_REFF) ==="
$tSAF=0.0; $tGL=0.0
while($r.Read()){
    $saf=[double]$r["SAF_SA"]; $glk=[double]$r["GL_K"]; $gld=[double]$r["GL_D_ORDERREF"]; $glNet=[double]$r["GL_NET"]
    $tSAF+=$saf; $tGL+=$glNet
    $diff=$saf-$glNet
    if([Math]::Abs($diff) -gt 500){
        $lines += "BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SAF=$([string]::Format('{0:N0}',$saf))  GL_K=$([string]::Format('{0:N0}',$glk))  GL_D=$([string]::Format('{0:N0}',$gld))  GL_NET=$([string]::Format('{0:N0}',$glNet))  DIFF=$([string]::Format('{0:N0}',$diff))"
    }
}
$lines += "TOTAL: SAF=$([string]::Format('{0:N2}',$tSAF))  GL_NET=$([string]::Format('{0:N2}',$tGL))  DIFF=$([string]::Format('{0:N2}',$tSAF-$tGL))"
$r.Close()

# Check if there are GL 226-001 Debet entries NOT linked to any SAF BTB (aggregate adjustments)
$cmd.CommandText = @"
SELECT SUM(G.debet) AS UNMATCHED_D, COUNT(*) AS CNT
FROM gl_journal G
WHERE G.account_id = '226-001' AND G.debet > 0 AND G.tgl < '2026-01-01'
  AND NOT EXISTS (SELECT 1 FROM SALDO_AWAL_FAKTUR S 
                  WHERE S.BUKTI_ID = G.order_reff 
                    AND S.TIPE_TRANS IN (1,2) 
                    AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026)
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL DEBET NOT LINKED TO SAF (unmatched) ==="
while($r.Read()){ $lines += "UNMATCHED_D=$([string]::Format('{0:N2}',[double]$r['UNMATCHED_D']))  CNT=$($r['CNT'])" }
$r.Close()

# Also check GL Kredit not linked to SAF (other accounts' Kredit entries that share a voucher?)
$cmd.CommandText = @"
SELECT SUM(G.kredit) AS UNMATCHED_K, COUNT(*) AS CNT
FROM gl_journal G
WHERE G.account_id = '226-001' AND G.kredit > 0 AND G.tgl < '2026-01-01'
  AND NOT EXISTS (SELECT 1 FROM SALDO_AWAL_FAKTUR S 
                  WHERE S.BUKTI_ID = G.voucher 
                    AND S.TIPE_TRANS IN (1,2) 
                    AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026)
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL KREDIT NOT LINKED TO SAF (other sources) ==="
while($r.Read()){ $lines += "UNMATCHED_K=$([string]::Format('{0:N2}',[double]$r['UNMATCHED_K']))  CNT=$($r['CNT'])" }
$r.Close()

# Check TIPE=1 (200.xxx) SAF entries for Jan 2026 and their GL accounts
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO,
       MAX(G.account_id) AS GL_ACC
FROM SALDO_AWAL_FAKTUR S
LEFT JOIN gl_journal G ON G.voucher = S.BUKTI_ID AND G.kredit > 0
WHERE S.TIPE_TRANS = 1 AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
GROUP BY S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO
ORDER BY S.NEW_SALDO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== SAF TIPE=1 (200.xxx) JAN 2026 ==="
$t1=0.0
while($r.Read()){
    $sa=[double]$r["NEW_SALDO"]; $t1+=$sa
    $lines += "BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SA=$([string]::Format('{0:N0}',$sa))  GL=$($r['GL_ACC'])"
}
$lines += "TIPE=1 TOTAL=$([string]::Format('{0:N2}',$t1))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag12_out.txt" -Encoding UTF8
Write-Host "Done"
