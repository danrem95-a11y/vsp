Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    SUM(ISNULL(S.SALDO_KURS * S.RATE, 0)) AS TOTAL_RATE,
    SUM(ISNULL(S.SALDO, 0)) AS TOTAL_SALDO,
    SUM(ISNULL(S.NEW_SALDO, 0)) AS TOTAL_NEW_SALDO
FROM SALDO_AWAL_FAKTUR S
WHERE S.TIPE_TRANS IN (1, 2)
  AND MONTH(S.PERIODE) = 1
  AND YEAR(S.PERIODE) = 2026
  AND EXISTS (
      SELECT 1 FROM gl_journal GJ
      WHERE GJ.voucher = S.BUKTI_ID
        AND GJ.account_id = '226-001'
        AND GJ.kredit > 0)
'@

$sqlPk = @'
SELECT
    SUM(CASE WHEN A.TIPE_TRANS = '05'
                 THEN A.TTL_NETTO
             ELSE (CASE WHEN A.TIPE_TRANS IN ('02', '06', '16') THEN A.TTL_NETTO
                        WHEN A.TIPE_TRANS = '12' THEN -ABS(A.TTL_NETTO)
                        ELSE 0 END) * ISNULL(A.KURS, 1)
        END) AS TOTAL_PK
FROM AP_TRANS A
WHERE A.TGL >= '2025-01-01'
  AND A.TGL < '2026-01-01'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02', '05', '06', '12', '16')
  AND A.ORDER_CLIENT NOT LIKE '101BTB%'
  AND EXISTS (
      SELECT 1 FROM gl_journal GJ
      WHERE GJ.voucher = A.ORDER_CLIENT
        AND GJ.account_id = '226-001'
        AND (GJ.kredit > 0 OR GJ.debet > 0))
  AND NOT EXISTS (
      SELECT 1 FROM SALDO_AWAL_FAKTUR S
      WHERE S.BUKTI_ID = A.ORDER_CLIENT
        AND S.TIPE_TRANS IN (1, 2)
        AND MONTH(S.PERIODE) = 1
        AND YEAR(S.PERIODE) = 2026)
'@

try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    if ($r.Read()) {
        $rate = [decimal]$r['TOTAL_RATE']
        $saldo = [decimal]$r['TOTAL_SALDO']
        $newSaldo = [decimal]$r['TOTAL_NEW_SALDO']
    }
    $r.Close()

    $cmd.CommandText = $sqlPk
    $r = $cmd.ExecuteReader()
    if ($r.Read()) {
        $pk = [decimal]$r['TOTAL_PK']
    }
    $r.Close()

    $target = [decimal]14159923466.61
    $out = @()
    $out += "TARGET=$target"
    $out += "RATE=$rate|DIFF=$($target-$rate)"
    $out += "SALDO=$saldo|DIFF=$($target-$saldo)"
    $out += "NEW_SALDO=$newSaldo|DIFF=$($target-$newSaldo)"
    $out += "PK_NO_SAF=$pk"
    $out += "NEW_SALDO_MINUS_PK=$($newSaldo-$pk)|DIFF=$($target-($newSaldo-$pk))"
    $out | Out-File 'c:\BTV\debug\diag22_out.txt' -Encoding UTF8
}
finally {
    $con.Close()
}