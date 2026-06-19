# diag13.ps1 - Validasi query_opname_hutang.sql setelah GL account filter
# Menggunakan literal values (bukan :arg_* variables) agar kompatibel dengan SA9 ODBC
# Target: MUTASI=1,444,491,792 | BAYAR=4,545,243,402 | SISA~11,159,666,484

Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

# Literal substitution:
#   :arg_tgl1   -> '2026-01-01'
#   :arg_tgl2   -> '2026-01-31'
#   :arg_account-> '226-001'
#   YEAR(:arg_tgl1) -> 2026
#   DATEADD(day,1,:arg_tgl2) -> '2026-02-01'
#   DATEADD(day,1-DATEPART(dayofyear,:arg_tgl1),:arg_tgl1) -> '2026-01-01'

$sql = @'
SELECT
    COUNT(*)                                                               AS JUMLAH_BARIS,
    SUM(SALDO_AWAL_IDR)                                                    AS TOTAL_SA,
    SUM(MUTASI_IDR)                                                        AS TOTAL_MUTASI,
    SUM(ADJ_IDR)                                                           AS TOTAL_ADJ,
    SUM(NILAI_BAYAR_IDR)                                                   AS TOTAL_BAYAR,
    SUM(SALDO_AWAL_IDR + MUTASI_IDR + ADJ_IDR - NILAI_BAYAR_IDR)          AS TOTAL_SISA
FROM (
SELECT
    MAIN.CUST_ID,
    MAIN.SALDO_AWAL_IDR,
    MAIN.MUTASI_IDR,
    MAIN.ADJ_IDR,
    MAIN.NILAI_BAYAR_IDR
FROM
(
    SELECT
        INV.VENDOR_ID AS CUST_ID,
        ISNULL(OPN_HIST.AWAL_IDR, 0) + ISNULL(HIST_MUT.PEMBELIAN_LALU_IDR, 0) + ISNULL(HIST_ADJ.ADJ_LALU_IDR, 0) - ISNULL(HIST_BYR.BAYAR_LALU_IDR, 0) AS SALDO_AWAL_IDR,
        ISNULL(ALL_MUT.PEMBELIAN_NOW_IDR, 0) AS MUTASI_IDR,
        ISNULL(ALL_ADJ.ADJ_NOW_IDR, 0) AS ADJ_IDR,
        ISNULL(ALL_BYR.BAYAR_NOW_IDR, 0) AS NILAI_BAYAR_IDR
    FROM
    (
        SELECT
            JANGKAR.ORDER_CLIENT,
            COALESCE(MAX(A_BASE.TGL), MAX(SAF.TGL_FAKTUR)) AS TGL,
            COALESCE(MAX(A_BASE.VENDOR_ID), MAX(SAF.VENDOR_ID)) AS VENDOR_ID,
            COALESCE(MAX(A_BASE.CURR_ID), MAX(SAF.CURR_ID)) AS CURR_ID,
            COALESCE(MAX(A_BASE.TIPE_TRANS), CAST(MAX(SAF.TIPE_TRANS) AS VARCHAR(2))) AS TIPE_TRANS,
            COALESCE(MAX(A_BASE.KURS), MAX(SAF.RATE)) AS KURS,
            MAX(A_BASE.NEW_RATE) AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL) AS NEW_RATE_TGL,
            COALESCE(MAX(A_BASE.BUKTI_REFF), MAX(SAF.NO_FAKTUR)) AS BUKTI_REFF
        FROM (
            SELECT AT.ORDER_CLIENT FROM AP_TRANS AT
            WHERE AT.TIPE_TRANS IN ('02','05','06','12','16')
              AND AT.TGL >= '2026-01-01' AND AT.TGL < '2026-02-01'
              AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = AT.ORDER_CLIENT AND GG.account_id = '226-001' AND GG.kredit > 0)
            UNION
            SELECT SAF2.BUKTI_ID AS ORDER_CLIENT FROM SALDO_AWAL_FAKTUR SAF2
            WHERE SAF2.TIPE_TRANS IN (1,2) AND MONTH(SAF2.PERIODE) = 1 AND YEAR(SAF2.PERIODE) = 2026
              AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF2.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        ) JANGKAR
        LEFT JOIN AP_TRANS A_BASE
            ON A_BASE.ORDER_CLIENT = JANGKAR.ORDER_CLIENT
           AND A_BASE.TIPE_TRANS IN ('02','05','06','12','16')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF
            ON SAF.BUKTI_ID = JANGKAR.ORDER_CLIENT
           AND MONTH(SAF.PERIODE) = 1
           AND YEAR(SAF.PERIODE) = 2026
        GROUP BY JANGKAR.ORDER_CLIENT
    ) INV
    LEFT JOIN MCSTSUPP SUPP ON SUPP.VENDOR_ID = INV.VENDOR_ID
    LEFT JOIN MCUST CUST ON CUST.cust_id = INV.VENDOR_ID
    LEFT JOIN (
        SELECT SAF_O.BUKTI_ID,
               AVG(ISNULL(SAF_O.RATE,0)) AS RATE,
               AVG(ISNULL(SAF_O.NEW_RATE,0)) AS NEW_RATE,
               SUM(ISNULL(SAF_O.SALDO_KURS * SAF_O.RATE, 0)) AS AWAL_IDR,
               SUM(ISNULL(SAF_O.SALDO_KURS, 0)) AS AWAL_KURS
        FROM SALDO_AWAL_FAKTUR SAF_O
        WHERE SAF_O.TIPE_TRANS IN (1,2) AND MONTH(SAF_O.PERIODE) = 1 AND YEAR(SAF_O.PERIODE) = 2026
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF_O.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY SAF_O.BUKTI_ID
    ) OPN_HIST ON OPN_HIST.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TGL < '2026-01-01' THEN
                CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO
                     ELSE CASE WHEN P.TIPE_TRANS IN ('02','06','16') THEN P.TTL_NETTO
                               WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO)
                               ELSE 0 END * ISNULL(P.KURS,1)
                END
            ELSE 0 END) AS PEMBELIAN_LALU_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= '2026-01-01' AND P.TGL < '2026-01-01'
          AND P.ORDER_OKE = 'Y' AND P.TIPE_TRANS IN ('02','05','12','06','16')
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = P.ORDER_CLIENT AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY P.ORDER_CLIENT
    ) HIST_MUT ON HIST_MUT.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT BUKTI_ID,
            SUM(CASE WHEN TGL_BAYAR < '2026-01-01' THEN
                CASE WHEN FLAG_ORDER NOT IN (2,22) THEN ABS(NILAI_BAYAR_IDR) ELSE -ABS(NILAI_BAYAR_IDR) END
            ELSE 0 END) AS ADJ_LALU_IDR
        FROM TBYR2_PUTIH
        WHERE TGL_BAYAR >= '2026-01-01' AND TGL_BAYAR < '2026-01-01'
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = TBYR2_PUTIH.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY BUKTI_ID
    ) HIST_ADJ ON HIST_ADJ.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT T2.BUKTI_ID, SUM(ISNULL(T2.NILAI_BAYAR_IDR,0)) AS BAYAR_LALU_IDR
        FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1,2)
          AND T1.TGL >= '2026-01-01' AND T1.TGL < '2026-01-01'
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = T2.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY T2.BUKTI_ID
    ) HIST_BYR ON HIST_BYR.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TGL >= '2026-01-01' THEN
                CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO
                     ELSE CASE WHEN P.TIPE_TRANS IN ('02','06','16') THEN P.TTL_NETTO
                               WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO)
                               ELSE 0 END * ISNULL(P.KURS,1)
                END
            ELSE 0 END) AS PEMBELIAN_NOW_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= '2026-01-01' AND P.TGL < '2026-02-01'
          AND P.ORDER_OKE = 'Y' AND P.TIPE_TRANS IN ('02','05','12','06','16')
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = P.ORDER_CLIENT AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY P.ORDER_CLIENT
    ) ALL_MUT ON ALL_MUT.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT BUKTI_ID,
            SUM(CASE WHEN TGL_BAYAR >= '2026-01-01' THEN
                CASE WHEN FLAG_ORDER NOT IN (2,22) THEN ABS(NILAI_BAYAR_IDR) ELSE -ABS(NILAI_BAYAR_IDR) END
            ELSE 0 END) AS ADJ_NOW_IDR
        FROM TBYR2_PUTIH
        WHERE TGL_BAYAR >= '2026-01-01' AND TGL_BAYAR < '2026-02-01'
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = TBYR2_PUTIH.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY BUKTI_ID
    ) ALL_ADJ ON ALL_ADJ.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT T2.BUKTI_ID, SUM(ISNULL(T2.NILAI_BAYAR_IDR,0)) AS BAYAR_NOW_IDR
        FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1,2)
          AND T1.TGL >= '2026-01-01' AND T1.TGL < '2026-02-01'
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = T2.BUKTI_ID AND GG.account_id = '226-001' AND GG.kredit > 0)
        GROUP BY T2.BUKTI_ID
    ) ALL_BYR ON ALL_BYR.BUKTI_ID = INV.ORDER_CLIENT
) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR - MAIN.NILAI_BAYAR_IDR), 2) <> 0
    OR ROUND(MAIN.MUTASI_IDR, 2) <> 0
    OR ROUND(MAIN.ADJ_IDR, 2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR_IDR, 2) <> 0
) X
'@

$out = @()
$out += "=== VALIDASI GL ACCOUNT FILTER (226-001) Jan 2026 ==="
$out += "Target GL: SA=14,159,923,466 | MUTASI=1,444,491,792 | ADJ=-1,398,500 | BAYAR=4,545,243,402 | SISA=11,057,773,355.95"
$out += ""

try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 300

    $reader = $cmd.ExecuteReader()
    if ($reader.Read()) {
        $rows   = $reader["JUMLAH_BARIS"]
        $sa     = $reader["TOTAL_SA"]
        $mutasi = $reader["TOTAL_MUTASI"]
        $adj    = $reader["TOTAL_ADJ"]
        $bayar  = $reader["TOTAL_BAYAR"]
        $sisa   = $reader["TOTAL_SISA"]

        $out += "JUMLAH BARIS : $rows"
        $out += "TOTAL_SA     : $([decimal]$sa)"
        $out += "TOTAL_MUTASI : $([decimal]$mutasi)  (Target: 1,444,491,792)"
        $out += "TOTAL_ADJ    : $([decimal]$adj)  (Target: -1,398,500)"
        $out += "TOTAL_BAYAR  : $([decimal]$bayar)  (Target: 4,545,243,402)"
        $out += "TOTAL_SISA   : $([decimal]$sisa)  (Target GL: 11,057,773,355.95)"
        $out += ""
        $out += "SELISIH MUTASI : $([decimal]$mutasi - 1444491792)"
        $out += "SELISIH BAYAR  : $([decimal]$bayar - 4545243402)"
    }
    $reader.Close()
} catch {
    $out += "ERROR: $_"
} finally {
    $con.Close()
}

$out | Out-File "C:\BTV\debug\diag13_out.txt" -Encoding UTF8
Write-Host "Done. See C:\BTV\debug\diag13_out.txt"
