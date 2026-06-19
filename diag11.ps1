$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Check gl_journal DOC_REFF for 226-001 DEBET entries in Jan 2026
$cmd.CommandText = @"
SELECT TOP 20 G.voucher, G.tgl, G.debet, G.ket, G.doc_reff, G.order_reff
FROM gl_journal G
WHERE G.account_id = '226-001'
  AND G.debet > 0
  AND G.tgl BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY G.debet DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL 226-001 DEBET JAN2026 DOC_REFF ==="
while($r.Read()){
    $lines += "V=$($r['voucher'])  D=$([string]::Format('{0:N0}',[double]$r['debet']))  KET=$($r['ket'])  DOC_REFF=$($r['doc_reff'])  ORDER_REFF=$($r['order_reff'])"
}
$r.Close()

# Check if DOC_REFF links to SAF BUKTI_ID (BTB vouchers)
$cmd.CommandText = @"
SELECT G.voucher, G.tgl, G.debet, G.doc_reff, S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO
FROM gl_journal G
JOIN SALDO_AWAL_FAKTUR S ON S.BUKTI_ID = G.doc_reff
WHERE G.account_id = '226-001'
  AND G.debet > 0
  AND G.tgl BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY G.debet DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL DEBET -> SAF via DOC_REFF ==="
$cnt=0
while($r.Read()){ $cnt++
    $lines += "V=$($r['voucher'])  D=$([string]::Format('{0:N0}',[double]$r['debet']))  DOC=$($r['doc_reff'])  BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SA=$([string]::Format('{0:N0}',[double]$r['NEW_SALDO']))"
}
$lines += "JOIN HITS: $cnt"
$r.Close()

# Check KURS for import AP_TRANS (TIPE=02 with large amounts after KURS conversion)
$cmd.CommandText = @"
SELECT TOP 15 A.ORDER_CLIENT, A.VENDOR_ID, A.TIPE_TRANS, A.TTL_NETTO, A.KURS,
       A.TTL_NETTO * ISNULL(A.KURS,1) AS IDR_EQUIV
FROM AP_TRANS A
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.VENDOR_ID LIKE '4SL.%'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
ORDER BY A.TTL_NETTO * ISNULL(A.KURS,1) DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS KURS CHECK ==="
$totalIdr=0.0
while($r.Read()){
    $idr=[double]$r["IDR_EQUIV"]; $totalIdr+=$idr
    $lines += "OC=$($r['ORDER_CLIENT'])  VID=$($r['VENDOR_ID'])  TIPE=$($r['TIPE_TRANS'])  NETTO=$($r['TTL_NETTO'])  KURS=$($r['KURS'])  IDR=$([string]::Format('{0:N0}',$idr))"
}
$lines += "TOTAL_IDR=$([string]::Format('{0:N0}',$totalIdr))"
$r.Close()

# Compute actual GL-based SALDO_AWAL per BTB using Kredit - historical Debet via DOC_REFF
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO AS SAF_SA,
       SUM(CASE WHEN G.kredit > 0 THEN G.kredit ELSE 0 END) AS GL_K,
       SUM(CASE WHEN G.debet > 0 THEN G.debet ELSE 0 END) AS GL_D_DIRECT,
       SUM(CASE WHEN G2.debet > 0 THEN G2.debet ELSE 0 END) AS GL_D_DOCREF
FROM SALDO_AWAL_FAKTUR S
JOIN gl_journal G ON G.voucher = S.BUKTI_ID AND G.account_id = '226-001'
LEFT JOIN gl_journal G2 ON G2.doc_reff = S.BUKTI_ID AND G2.account_id = '226-001' AND G2.debet > 0 AND G2.tgl < '2026-01-01'
WHERE S.TIPE_TRANS = 2 AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
GROUP BY S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO
ORDER BY S.NEW_SALDO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== GL-BASED SA PER BTB ==="
$tSAF=0.0; $tGLnet=0.0
while($r.Read()){
    $saf=[double]$r["SAF_SA"]; $glk=[double]$r["GL_K"]; $gld=[double]$r["GL_D_DIRECT"]; $gldr=[double]$r["GL_D_DOCREF"]
    $glNet=$glk-$gld-$gldr; $tSAF+=$saf; $tGLnet+=$glNet
    if([Math]::Abs($saf-$glNet) -gt 1000){
        $lines += "BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SAF=$([string]::Format('{0:N0}',$saf))  GL_K=$([string]::Format('{0:N0}',$glk))  GL_D=$([string]::Format('{0:N0}',$gld+$gldr))  GL_NET=$([string]::Format('{0:N0}',$glNet))  DIFF=$([string]::Format('{0:N0}',$saf-$glNet))"
    }
}
$lines += "TOTAL: SAF=$([string]::Format('{0:N2}',$tSAF))  GL_NET=$([string]::Format('{0:N2}',$tGLnet))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag11_out.txt" -Encoding UTF8
Write-Host "Done"
