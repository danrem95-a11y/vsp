$ErrorActionPreference = 'Stop'

$conn = $null

function Write-Query {
    param(
        [string]$Label,
        [string]$Sql,
        [System.Collections.Generic.List[string]]$Lines
    )

    $Lines.Add("=== $Label ===") | Out-Null
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 600
    $reader = $cmd.ExecuteReader()
    try {
        $hasRows = $false
        while ($reader.Read()) {
            $hasRows = $true
            $parts = @()
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $parts += ($reader.GetName($i) + '=' + $reader[$i].ToString())
            }
            $Lines.Add(($parts -join ' | ')) | Out-Null
        }
        if (-not $hasRows) {
            $Lines.Add('(no rows)') | Out-Null
        }
    }
    finally {
        $reader.Close()
    }

    $Lines.Add('') | Out-Null
}

$lines = New-Object 'System.Collections.Generic.List[string]'

try {
  $conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
  $conn.Open()

Write-Query -Label 'ALL SAF VS GL ANCHORED SAF' -Lines $lines -Sql @"
SELECT
    CAST((SELECT SUM(CASE WHEN ISNULL(NEW_SALDO,0) <> 0 THEN NEW_SALDO
                          WHEN ISNULL(SALDO,0) <> 0 THEN SALDO
                          WHEN ISNULL(NEW_RATE,0) <> 0 THEN ISNULL(SALDO_KURS,0) * NEW_RATE
                          ELSE ISNULL(SALDO_KURS,0) * ISNULL(RATE,1)
                     END)
          FROM SALDO_AWAL_FAKTUR
          WHERE TIPE_TRANS = 1
            AND PERIODE >= '2026-01-01'
            AND PERIODE < '2026-02-01') AS DECIMAL(18,2)) AS ALL_SAF,
    CAST((SELECT SUM(CASE WHEN ISNULL(SAF.NEW_SALDO,0) <> 0 THEN SAF.NEW_SALDO
                          WHEN ISNULL(SAF.SALDO,0) <> 0 THEN SAF.SALDO
                          WHEN ISNULL(SAF.NEW_RATE,0) <> 0 THEN ISNULL(SAF.SALDO_KURS,0) * SAF.NEW_RATE
                          ELSE ISNULL(SAF.SALDO_KURS,0) * ISNULL(SAF.RATE,1)
                     END)
          FROM SALDO_AWAL_FAKTUR SAF
          WHERE SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= '2026-01-01'
            AND SAF.PERIODE < '2026-02-01'
            AND SAF.BUKTI_ID IN (
                SELECT DISTINCT GJ.voucher
                FROM gl_journal GJ
                WHERE GJ.account_id = '103-001'
                  AND GJ.debet > 0
            )) AS DECIMAL(18,2)) AS GL_ANCHORED,
    CAST(
        (SELECT SUM(CASE WHEN ISNULL(NEW_SALDO,0) <> 0 THEN NEW_SALDO
                         WHEN ISNULL(SALDO,0) <> 0 THEN SALDO
                         WHEN ISNULL(NEW_RATE,0) <> 0 THEN ISNULL(SALDO_KURS,0) * NEW_RATE
                         ELSE ISNULL(SALDO_KURS,0) * ISNULL(RATE,1)
                    END)
         FROM SALDO_AWAL_FAKTUR
         WHERE TIPE_TRANS = 1
           AND PERIODE >= '2026-01-01'
           AND PERIODE < '2026-02-01')
        -
        (SELECT SUM(CASE WHEN ISNULL(SAF.NEW_SALDO,0) <> 0 THEN SAF.NEW_SALDO
                         WHEN ISNULL(SAF.SALDO,0) <> 0 THEN SAF.SALDO
                         WHEN ISNULL(SAF.NEW_RATE,0) <> 0 THEN ISNULL(SAF.SALDO_KURS,0) * SAF.NEW_RATE
                         ELSE ISNULL(SAF.SALDO_KURS,0) * ISNULL(SAF.RATE,1)
                    END)
         FROM SALDO_AWAL_FAKTUR SAF
         WHERE SAF.TIPE_TRANS = 1
           AND SAF.PERIODE >= '2026-01-01'
           AND SAF.PERIODE < '2026-02-01'
           AND SAF.BUKTI_ID IN (
               SELECT DISTINCT GJ.voucher
               FROM gl_journal GJ
               WHERE GJ.account_id = '103-001'
                 AND GJ.debet > 0
           ))
    AS DECIMAL(18,2)) AS DIFF_IDR
"@

Write-Query -Label 'MISSING GL ANCHOR SAF ROWS' -Lines $lines -Sql @"
SELECT TOP 50
    SAF.BUKTI_ID,
    SAF.VENDOR_ID,
    SAF.CURR_ID,
    CAST(SUM(CASE WHEN ISNULL(SAF.NEW_SALDO,0) <> 0 THEN SAF.NEW_SALDO
                  WHEN ISNULL(SAF.SALDO,0) <> 0 THEN SAF.SALDO
                  WHEN ISNULL(SAF.NEW_RATE,0) <> 0 THEN ISNULL(SAF.SALDO_KURS,0) * SAF.NEW_RATE
                  ELSE ISNULL(SAF.SALDO_KURS,0) * ISNULL(SAF.RATE,1)
             END) AS DECIMAL(18,2)) AS OPENING_IDR,
    CAST(SUM(CASE WHEN ISNULL(SAF.NEW_SALDO_KURS,0) <> 0 THEN SAF.NEW_SALDO_KURS ELSE ISNULL(SAF.SALDO_KURS,0) END) AS DECIMAL(18,4)) AS OPENING_KURS,
    COUNT(*) AS ROWS
FROM SALDO_AWAL_FAKTUR SAF
WHERE SAF.TIPE_TRANS = 1
  AND SAF.PERIODE >= '2026-01-01'
  AND SAF.PERIODE < '2026-02-01'
  AND NOT EXISTS (
      SELECT 1
      FROM gl_journal GJ
      WHERE GJ.account_id = '103-001'
        AND GJ.debet > 0
        AND GJ.voucher = SAF.BUKTI_ID
  )
GROUP BY SAF.BUKTI_ID, SAF.VENDOR_ID, SAF.CURR_ID
ORDER BY ABS(OPENING_IDR) DESC, SAF.BUKTI_ID
"@

Write-Query -Label 'ROUNDING VARIANTS' -Lines $lines -Sql @"
SELECT
    CAST(SUM(ISNULL(NEW_SALDO, 0)) AS DECIMAL(18,2)) AS SUM_NEW_SALDO,
    CAST(SUM(ISNULL(SALDO, 0)) AS DECIMAL(18,2)) AS SUM_SALDO,
    CAST(SUM(ISNULL(SALDO_KURS, 0) * ISNULL(NEW_RATE, 0)) AS DECIMAL(18,2)) AS SUM_KURS_X_NEW_RATE,
    CAST(SUM(ROUND(ISNULL(SALDO_KURS, 0) * ISNULL(NEW_RATE, 0), 2)) AS DECIMAL(18,2)) AS SUM_ROUND_ROW_KURS_X_NEW_RATE,
    CAST(SUM(ROUND(ISNULL(NEW_SALDO, 0), 2)) AS DECIMAL(18,2)) AS SUM_ROUND_ROW_NEW_SALDO
FROM SALDO_AWAL_FAKTUR
WHERE TIPE_TRANS = 1
  AND PERIODE >= '2026-01-01'
  AND PERIODE < '2026-02-01'
"@

Write-Query -Label 'PER BUKTI ROUNDING DELTA' -Lines $lines -Sql @"
SELECT TOP 50
    SAF.BUKTI_ID,
    SAF.VENDOR_ID,
    SAF.CURR_ID,
    CAST(SUM(ISNULL(SAF.NEW_SALDO, 0)) AS DECIMAL(18,2)) AS SUM_NEW_SALDO,
    CAST(SUM(ISNULL(SAF.SALDO_KURS, 0) * ISNULL(SAF.NEW_RATE, 0)) AS DECIMAL(18,2)) AS SUM_KURS_NEW_RATE,
    CAST(SUM(ROUND(ISNULL(SAF.SALDO_KURS, 0) * ISNULL(SAF.NEW_RATE, 0), 2)) AS DECIMAL(18,2)) AS SUM_ROW_ROUND_KURS_NEW_RATE,
    CAST(SUM(ROUND(ISNULL(SAF.NEW_SALDO, 0), 2)) AS DECIMAL(18,2)) AS SUM_ROW_ROUND_NEW_SALDO,
    CAST(SUM(ISNULL(SAF.NEW_SALDO, 0)) - SUM(ISNULL(SAF.SALDO_KURS, 0) * ISNULL(SAF.NEW_RATE, 0)) AS DECIMAL(18,2)) AS DELTA_NEW_SALDO_VS_RATE
FROM SALDO_AWAL_FAKTUR SAF
WHERE SAF.TIPE_TRANS = 1
  AND SAF.PERIODE >= '2026-01-01'
  AND SAF.PERIODE < '2026-02-01'
GROUP BY SAF.BUKTI_ID, SAF.VENDOR_ID, SAF.CURR_ID
HAVING ABS(SUM(ISNULL(SAF.NEW_SALDO, 0)) - SUM(ISNULL(SAF.SALDO_KURS, 0) * ISNULL(SAF.NEW_RATE, 0))) <> 0
ORDER BY ABS(DELTA_NEW_SALDO_VS_RATE) DESC, SAF.BUKTI_ID
"@

  $lines | Out-File 'c:\BTV\debug\diag73_out.txt' -Encoding ascii
}
catch {
  @(
    'ERROR='
    $_.Exception.ToString()
  ) | Out-File 'c:\BTV\debug\diag73_err.txt' -Encoding ascii
  throw
}
finally {
  if ($conn -ne $null) {
    $conn.Close()
  }
}
